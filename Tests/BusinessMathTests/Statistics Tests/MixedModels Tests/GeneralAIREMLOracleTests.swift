//
//  GeneralAIREMLOracleTests.swift
//  BusinessMath
//
//  A dense oracle for `generalAIREMLUpdate`, the highest-complexity function in the
//  package and the one with the least to check it.
//
//  `GeneralLMEReferenceTests` pins the *converged* fit against statsmodels, which is the
//  right oracle for the fitter as a whole. It cannot localise anything: it sees the fixed
//  point of a loop, so a defect in one term of the score or one entry of the information
//  matrix shows up only if it moves where the loop stops. A wrong information matrix
//  usually does not — Newton with a wrong Hessian still converges to the right optimum,
//  just along a different path and in a different number of steps. The score and the AI
//  matrix have never been checked at a point of their own choosing.
//
//  ## The structural assumption under test
//
//  With `P = V^-1 - V^-1 X (X'V^-1 X)^-1 X'V^-1`, the source's quantities are
//
//      score[k] = -1/2 tr(P dV_k) + 1/2 r' P dV_k P r
//      ai[j][k] =  1/2 (dV_j P r)' P (dV_k P r)
//
//  `V` is block diagonal by group, and so is every `dV_k` — the random effects of two
//  groups are independent, so `dV/dG[a,b]` has no cross-group entries. `P` is **not**
//  block diagonal: its `(i,j)` block is `-V_i^-1 X_i (X'V^-1 X)^-1 X_j'V_j^-1`, which is
//  nonzero for `i != j`.
//
//  That asymmetry is the whole question. Where a `P` is multiplied by a block-diagonal
//  `dV_k` and traced, only the diagonal blocks of `P` survive and a per-group accumulation
//  is exact. Where a vector is sandwiched between two `P`s, the cross-group blocks
//  contribute and a per-group accumulation is not. The source accumulates one `nig x nig`
//  `pMat` per group and never forms the whole `P`, so it is making that distinction
//  implicitly, in code, in five separate places.
//
//  This file forms the entire `N x N` `P` and evaluates both formulas directly. Nothing is
//  accumulated per group; the block structure is never assumed, only *implied* by how `V`
//  is filled in. The matrix inverse is a Gauss-Jordan elimination written here, so it
//  shares no code path with the source's `DenseMatrix.choleskyInverse()` — the same
//  independence `standardErrorsAreTheGLSCovariance` buys by using `solve` over Cholesky.
//
//  ## Where it is evaluated
//
//  Not at the converged fit. At the optimum the score is zero by definition, so a wrong
//  score term is small minus small and a relative comparison there says nothing. The two
//  evaluation points below are built from the sample variance of `y` alone — they never
//  ask the fitter for an answer, so this file cannot inherit a defect from it. Both put a
//  nonzero off-diagonal in `G` for the two-slope designs, with opposite signs, because
//  `dV/dG[a,b]` for `a != b` is the one derivative with a different shape.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("AI-REML score and information against a dense projection")
struct GeneralAIREMLOracleTests {

	// MARK: - Fixture

	private struct Fixture: Decodable {
		let cases: [Case]
	}

	private struct Case: Decodable {
		let name: String
		let groups: [Int]
		let X: [[Double]]
		let Z: [[Double]]
		let y: [Double]
		let randomEffectsPerGroup: Int
	}

	private static func loadFixture() throws -> Fixture {
		guard let url = Bundle.module.url(forResource: "mixedModels",
										  withExtension: "json",
										  subdirectory: "Fixtures")
			?? Bundle.module.url(forResource: "mixedModels", withExtension: "json") else {
			struct Missing: Error { let name: String }
			throw Missing(name: "mixedModels")
		}
		return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
	}

	// MARK: - Where to evaluate

	/// A variance-parameter point, built from the data rather than from a fit.
	private struct Point {
		let label: String
		/// `sigma_e^2` as a multiple of the sample variance of `y`.
		let residualShare: Double
		/// Each diagonal entry of `G` as a multiple of the sample variance of `y`.
		let diagonalShare: Double
		/// Off-diagonal entries of `G`, as a fraction of the diagonal. Zero when `r == 1`.
		let correlation: Double
	}

	private static let points: [Point] = [
		Point(label: "A", residualShare: 0.50, diagonalShare: 0.25, correlation: 0.3),
		Point(label: "B", residualShare: 1.00, diagonalShare: 0.125, correlation: -0.2)
	]

	private static func variance(_ values: [Double]) -> Double {
		let n = Double(values.count)
		guard n > 1 else { return 1 }
		let total = values.reduce(0, +)
		let mean = total / n
		var sumSquares = 0.0
		for value in values {
			let gap = value - mean
			sumSquares += gap * gap
		}
		return sumSquares / (n - 1)
	}

	private static func parameters(at point: Point, y: [Double], r: Int) -> ([[Double]], Double) {
		let varianceY = variance(y)
		let diagonal = point.diagonalShare * varianceY
		let offDiagonal = point.correlation * diagonal
		var g = [[Double]](repeating: [Double](repeating: 0, count: r), count: r)
		for i in 0..<r {
			g[i][i] = diagonal
			for j in 0..<r where j != i {
				g[i][j] = offDiagonal
			}
		}
		return (g, point.residualShare * varianceY)
	}

	// MARK: - Linear algebra, written here on purpose

	private struct Singular: Error { let size: Int }

	/// Gauss-Jordan inversion with partial pivoting.
	///
	/// Deliberately not `DenseMatrix.choleskyInverse()`: an oracle that reuses the routine
	/// under test cannot fail in the one way that matters. This also never assumes symmetry,
	/// so it would not quietly symmetrise a matrix the source had built asymmetrically.
	private static func inverted(_ matrix: [[Double]]) throws -> [[Double]] {
		let n = matrix.count
		var a = matrix
		var inverse = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
		for i in 0..<n { inverse[i][i] = 1 }

		for column in 0..<n {
			var pivotRow = column
			var best = abs(a[column][column])
			for row in (column + 1)..<n where abs(a[row][column]) > best {
				best = abs(a[row][column])
				pivotRow = row
			}
			guard best > 0 else { throw Singular(size: n) }
			if pivotRow != column {
				a.swapAt(pivotRow, column)
				inverse.swapAt(pivotRow, column)
			}
			let pivot = a[column][column]
			for k in 0..<n {
				a[column][k] /= pivot
				inverse[column][k] /= pivot
			}
			for row in 0..<n where row != column {
				let factor = a[row][column]
				guard factor != 0 else { continue }
				for k in 0..<n {
					a[row][k] -= factor * a[column][k]
					inverse[row][k] -= factor * inverse[column][k]
				}
			}
		}
		return inverse
	}

	// MARK: - The dense oracle

	private struct Dense {
		let resid: [Double]
		let score: [Double]
		/// `ai[j][k] = 1/2 (dV_j P r)' P (dV_k P r)` with the whole `N x N` `P`.
		let ai: [[Double]]
		/// The same formula with only the diagonal blocks of `P` — the quantity a
		/// per-group accumulation produces. Present to identify what the source computes,
		/// not as a claim about what it should.
		let blockAI: [[Double]]
	}

	/// The REML score and Average Information matrix, formed with the whole `N x N` `P`.
	private static func dense(
		x: [[Double]], z: [[Double]], y: [Double],
		groupIdx: [[Int]], r: Int, gArr: [[Double]], sigmaE2: Double
	) throws -> Dense {
		let n = y.count
		let p = x[0].count
		let nTheta = 1 + r * (r + 1) / 2

		// V = Z G Z' within each group, plus sigma_e^2 on the diagonal. The block structure
		// is never declared — it is whatever this loop over group rows produces.
		var v = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
		for rows in groupIdx {
			for a in rows {
				for b in rows {
					var total = 0.0
					for u in 0..<r {
						for w in 0..<r {
							total += z[a][u] * gArr[u][w] * z[b][w]
						}
					}
					v[a][b] += total
				}
			}
		}
		for i in 0..<n { v[i][i] += sigmaE2 }

		let vInv = try inverted(v)

		// X'V^-1 X and its inverse.
		var vInvX = [[Double]](repeating: [Double](repeating: 0, count: p), count: n)
		for row in 0..<n {
			for column in 0..<p {
				var total = 0.0
				for k in 0..<n { total += vInv[row][k] * x[k][column] }
				vInvX[row][column] = total
			}
		}
		var xtVinvX = [[Double]](repeating: [Double](repeating: 0, count: p), count: p)
		for j in 0..<p {
			for k in 0..<p {
				var total = 0.0
				for row in 0..<n { total += x[row][j] * vInvX[row][k] }
				xtVinvX[j][k] = total
			}
		}
		let middle = try inverted(xtVinvX)

		// P = V^-1 - (V^-1 X) (X'V^-1 X)^-1 (V^-1 X)', the whole matrix.
		var p1 = [[Double]](repeating: [Double](repeating: 0, count: p), count: n)
		for row in 0..<n {
			for j in 0..<p {
				var total = 0.0
				for k in 0..<p { total += vInvX[row][k] * middle[k][j] }
				p1[row][j] = total
			}
		}
		var projection = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
		for row in 0..<n {
			for col in 0..<n {
				var total = 0.0
				for j in 0..<p { total += p1[row][j] * vInvX[col][j] }
				projection[row][col] = vInv[row][col] - total
			}
		}

		// The GLS residual at this theta: r = y - X (X'V^-1 X)^-1 X'V^-1 y.
		var xtVinvY = [Double](repeating: 0, count: p)
		for j in 0..<p {
			var total = 0.0
			for row in 0..<n { total += vInvX[row][j] * y[row] }
			xtVinvY[j] = total
		}
		var beta = [Double](repeating: 0, count: p)
		for j in 0..<p {
			var total = 0.0
			for k in 0..<p { total += middle[j][k] * xtVinvY[k] }
			beta[j] = total
		}
		var resid = [Double](repeating: 0, count: n)
		for row in 0..<n {
			var fitted = 0.0
			for j in 0..<p { fitted += x[row][j] * beta[j] }
			resid[row] = y[row] - fitted
		}

		// dV/dtheta, in the source's order: sigma_e^2, then the upper triangle of G.
		var gParamMap = [(Int, Int)]()
		for i in 0..<r {
			for j in i..<r { gParamMap.append((i, j)) }
		}
		var dV = [[[Double]]]()
		var identity = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
		for i in 0..<n { identity[i][i] = 1 }
		dV.append(identity)
		for (a, b) in gParamMap {
			var derivative = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
			for rows in groupIdx {
				for row in rows {
					for col in rows {
						if a == b {
							derivative[row][col] += z[row][a] * z[col][a]
						} else {
							let first = z[row][a] * z[col][b]
							let second = z[row][b] * z[col][a]
							derivative[row][col] += first + second
						}
					}
				}
			}
			dV.append(derivative)
		}

		// P r, then dV_k P r, then P dV_k P r.
		var pR = [Double](repeating: 0, count: n)
		for row in 0..<n {
			var total = 0.0
			for col in 0..<n { total += projection[row][col] * resid[col] }
			pR[row] = total
		}

		var dvPr = [[Double]]()
		for k in 0..<nTheta {
			var product = [Double](repeating: 0, count: n)
			for row in 0..<n {
				var total = 0.0
				for col in 0..<n { total += dV[k][row][col] * pR[col] }
				product[row] = total
			}
			dvPr.append(product)
		}

		var score = [Double](repeating: 0, count: nTheta)
		for k in 0..<nTheta {
			var trace = 0.0
			for row in 0..<n {
				for col in 0..<n { trace += projection[row][col] * dV[k][col][row] }
			}
			var quadratic = 0.0
			for row in 0..<n { quadratic += pR[row] * dvPr[k][row] }
			let traceTerm = -0.5 * trace
			let quadraticTerm = 0.5 * quadratic
			score[k] = traceTerm + quadraticTerm
		}

		// AI[j][k] = 1/2 (dV_j P r)' P (dV_k P r), with the WHOLE P.
		var pDvPr = [[Double]]()
		for k in 0..<nTheta {
			var product = [Double](repeating: 0, count: n)
			for row in 0..<n {
				var total = 0.0
				for col in 0..<n { total += projection[row][col] * dvPr[k][col] }
				product[row] = total
			}
			pDvPr.append(product)
		}
		var ai = [[Double]](repeating: [Double](repeating: 0, count: nTheta), count: nTheta)
		for j in 0..<nTheta {
			for k in 0..<nTheta {
				var total = 0.0
				for row in 0..<n { total += dvPr[j][row] * pDvPr[k][row] }
				ai[j][k] = 0.5 * total
			}
		}

		// The same quantity with `P` truncated to its diagonal blocks.
		var blockAI = [[Double]](repeating: [Double](repeating: 0, count: nTheta), count: nTheta)
		for j in 0..<nTheta {
			for k in 0..<nTheta {
				var total = 0.0
				for rows in groupIdx {
					for row in rows {
						var inner = 0.0
						for col in rows { inner += projection[row][col] * dvPr[k][col] }
						total += dvPr[j][row] * inner
					}
				}
				blockAI[j][k] = 0.5 * total
			}
		}

		return Dense(resid: resid, score: score, ai: ai, blockAI: blockAI)
	}

	// MARK: - Comparison

	/// Relative where the reference is large enough for that to mean something, absolute
	/// otherwise. The absolute floor is scaled by the largest entry of the same object, so
	/// a near-zero entry beside a large one is still held to the large one's precision.
	private static func agrees(_ got: Double, _ expected: Double, scale: Double,
							   relative: Double) -> Bool {
		let gap = abs(got - expected)
		guard gap > 0 else { return true }
		let floor = relative * scale
		guard abs(expected) > floor else { return gap <= floor }
		return gap / abs(expected) <= relative
	}

	/// The agreement bound, measured rather than chosen.
	///
	/// A dense `N x N` Gauss-Jordan inverse is less well conditioned than the stack of
	/// per-group Cholesky solves the source uses, so the two routes cannot agree to machine
	/// precision however correct both are. Measured worst case across the six designs and
	/// both evaluation points, after the projection fix:
	///
	/// | quantity | worst relative gap |
	/// |---|---|
	/// | score | 3.36e-06 |
	/// | information | 2.99e-06 |
	///
	/// That the two land on the same floor is the point: the score was never wrong, so its
	/// 3.36e-06 is pure arithmetic noise, and the information now sits on the same number.
	/// Before the fix the information's gap was **0.135**.
	///
	/// The bound is 5e-05, about fifteen times the measured worst and still 2,700 times
	/// tighter than the structural error it has to catch.
	static let bound = 5e-5

	private static func largest(_ values: [Double]) -> Double {
		var best = 0.0
		for value in values where abs(value) > best { best = abs(value) }
		return Swift.max(best, 1e-300)
	}

	// MARK: - The tests

	@Test("The REML score matches a dense projection")
	func scoreMatchesDenseProjection() throws {
		let fixture = try Self.loadFixture()
		var compared = 0
		var worst = 0.0

		for entry in fixture.cases {
			let grouping = try GroupingFactor(entry.groups)
			let r = entry.randomEffectsPerGroup
			let p = entry.X[0].count

			for point in Self.points {
				let (gArr, sigmaE2) = Self.parameters(at: point, y: entry.y, r: r)
				let oracle = try Self.dense(
					x: entry.X, z: entry.Z, y: entry.y,
					groupIdx: grouping.groupIndices, r: r, gArr: gArr, sigmaE2: sigmaE2)

				let subject = try generalAIREMLUpdate(
					resid: oracle.resid, xData: entry.X, zData: entry.Z,
					m: grouping.groupCount, r: r,
					groupIdx: grouping.groupIndices,
					gArr: gArr, sigmaE2: sigmaE2, p: p)

				let scale = Self.largest(oracle.score)
				for k in 0..<oracle.score.count {
					let got = subject.score[k]
					let expected = oracle.score[k]
					let relativeGap = abs(got - expected) / Swift.max(abs(expected), scale)
					if relativeGap > worst { worst = relativeGap }
					#expect(Self.agrees(got, expected, scale: scale, relative: Self.bound),
							"\(entry.name) point \(point.label) score[\(k)]: \(got) vs dense \(expected)")
					compared += 1
				}
			}
		}
		#expect(compared >= 24, "only \(compared) score entries compared")
		#expect(worst < Self.bound, "worst relative gap in the score was \(worst)")
	}

	@Test("The Average Information matrix matches a dense projection")
	func informationMatchesDenseProjection() throws {
		let fixture = try Self.loadFixture()
		var compared = 0
		var worst = 0.0

		for entry in fixture.cases {
			let grouping = try GroupingFactor(entry.groups)
			let r = entry.randomEffectsPerGroup
			let p = entry.X[0].count

			for point in Self.points {
				let (gArr, sigmaE2) = Self.parameters(at: point, y: entry.y, r: r)
				let oracle = try Self.dense(
					x: entry.X, z: entry.Z, y: entry.y,
					groupIdx: grouping.groupIndices, r: r, gArr: gArr, sigmaE2: sigmaE2)

				let subject = try generalAIREMLUpdate(
					resid: oracle.resid, xData: entry.X, zData: entry.Z,
					m: grouping.groupCount, r: r,
					groupIdx: grouping.groupIndices,
					gArr: gArr, sigmaE2: sigmaE2, p: p)

				let flat = oracle.ai.flatMap { $0 }
				let scale = Self.largest(flat)
				for j in 0..<oracle.ai.count {
					for k in 0..<oracle.ai.count {
						let got = subject.ai[j][k]
						let expected = oracle.ai[j][k]
						let relativeGap = abs(got - expected) / Swift.max(abs(expected), scale)
						if relativeGap > worst { worst = relativeGap }
						#expect(Self.agrees(got, expected, scale: scale, relative: Self.bound),
								"\(entry.name) point \(point.label) ai[\(j)][\(k)]: \(got) vs dense \(expected)")
						compared += 1
					}
				}
			}
		}
		#expect(compared >= 48, "only \(compared) information entries compared")
		#expect(worst < Self.bound, "worst relative gap in the information matrix was \(worst)")
	}

	// MARK: - The EM step

	/// One EM M-step, recomputed densely.
	private struct DenseEM {
		let sigmaE2: Double
		let gArr: [[Double]]
	}

	/// The EM update from the textbook formulas, with a dense `V_i^-1` per group.
	///
	/// The source accumulates per group using `choleskySolve`/`choleskyInverse`, which is
	/// exact here — unlike the information matrix, every quantity in an EM step really is
	/// block diagonal. So what this checks is not the decomposition but the *formulas*, and
	/// in particular the two conditional-variance terms that separate an EM step from
	/// plugging the BLUPs in and calling it a day:
	///
	///     E[u u' | y] = u u' + (G - G Z'V^-1 Z G)
	///     E[e' e | y] = ||r - Z u||^2 + sigma^2 (n_i - sigma^2 tr(V^-1))
	///
	/// Drop either trailing term and the fit still converges, still produces a symmetric
	/// positive `G`, and lands somewhere biased — which is the shape of defect this file was
	/// written for. The inverse is the Gauss-Jordan one above, so nothing here shares a path
	/// with the source.
	private static func denseEMUpdate(
		resid: [Double], z: [[Double]], groupIdx: [[Int]],
		r: Int, gArr: [[Double]], sigmaE2: Double, n: Int
	) throws -> DenseEM {
		var sumG = [[Double]](repeating: [Double](repeating: 0, count: r), count: r)
		var sumResidVar = 0.0

		for rows in groupIdx {
			let nig = rows.count

			// V_i = Z_i G Z_i' + sigma^2 I, built here rather than asked for.
			var vi = [[Double]](repeating: [Double](repeating: 0, count: nig), count: nig)
			for (a, rowA) in rows.enumerated() {
				for (b, rowB) in rows.enumerated() {
					var total = 0.0
					for u in 0..<r {
						for w in 0..<r {
							total += z[rowA][u] * gArr[u][w] * z[rowB][w]
						}
					}
					vi[a][b] = total
				}
			}
			for a in 0..<nig { vi[a][a] += sigmaE2 }
			let viInv = try inverted(vi)

			// Z_i' V_i^-1 r_i
			var ztViInvR = [Double](repeating: 0, count: r)
			for k in 0..<r {
				var total = 0.0
				for a in 0..<nig {
					var inner = 0.0
					for b in 0..<nig { inner += viInv[a][b] * resid[rows[b]] }
					total += z[rows[a]][k] * inner
				}
				ztViInvR[k] = total
			}

			// u = G Z_i' V_i^-1 r_i
			var uHat = [Double](repeating: 0, count: r)
			for k in 0..<r {
				var total = 0.0
				for l in 0..<r { total += gArr[k][l] * ztViInvR[l] }
				uHat[k] = total
			}

			// Z_i' V_i^-1 Z_i, then G (that) G
			var ztViInvZ = [[Double]](repeating: [Double](repeating: 0, count: r), count: r)
			for a in 0..<r {
				for b in 0..<r {
					var total = 0.0
					for row in 0..<nig {
						for col in 0..<nig {
							total += z[rows[row]][a] * viInv[row][col] * z[rows[col]][b]
						}
					}
					ztViInvZ[a][b] = total
				}
			}
			var gZVZG = [[Double]](repeating: [Double](repeating: 0, count: r), count: r)
			for a in 0..<r {
				for b in 0..<r {
					var total = 0.0
					for c in 0..<r {
						for d in 0..<r {
							total += gArr[a][c] * ztViInvZ[c][d] * gArr[d][b]
						}
					}
					gZVZG[a][b] = total
				}
			}

			for a in 0..<r {
				for b in 0..<r {
					let conditionalVariance: Double = gArr[a][b] - gZVZG[a][b]
					sumG[a][b] += uHat[a] * uHat[b] + conditionalVariance
				}
			}

			var ssResid = 0.0
			for row in rows {
				var zu = 0.0
				for k in 0..<r { zu += z[row][k] * uHat[k] }
				let e: Double = resid[row] - zu
				ssResid += e * e
			}
			var trace = 0.0
			for a in 0..<nig { trace += viInv[a][a] }
			let conditional: Double = sigmaE2 * (Double(nig) - sigmaE2 * trace)
			sumResidVar += ssResid + conditional
		}

		var newG = [[Double]](repeating: [Double](repeating: 0, count: r), count: r)
		for a in 0..<r {
			for b in 0..<r { newG[a][b] = sumG[a][b] / Double(groupIdx.count) }
		}
		return DenseEM(sigmaE2: sumResidVar / Double(n), gArr: newG)
	}

	@Test("The EM step matches the textbook formulas, computed densely")
	func emStepMatchesDenseFormulas() throws {
		let fixture = try Self.loadFixture()
		var worst = 0.0
		var compared = 0

		for entry in fixture.cases {
			let grouping = try GroupingFactor(entry.groups)
			let r = entry.randomEffectsPerGroup

			for point in Self.points {
				let (gArr, sigmaE2) = Self.parameters(at: point, y: entry.y, r: r)
				let oracle = try Self.dense(
					x: entry.X, z: entry.Z, y: entry.y,
					groupIdx: grouping.groupIndices, r: r, gArr: gArr, sigmaE2: sigmaE2)

				let subject = try generalEMUpdate(
					resid: oracle.resid, zData: entry.Z,
					m: grouping.groupCount, r: r, ni: grouping.groupSizes,
					groupIdx: grouping.groupIndices,
					gArr: gArr, sigmaE2: sigmaE2, N: entry.y.count)

				let want = try Self.denseEMUpdate(
					resid: oracle.resid, z: entry.Z, groupIdx: grouping.groupIndices,
					r: r, gArr: gArr, sigmaE2: sigmaE2, n: entry.y.count)

				let sigmaGap = abs(subject.sigmaE2 - want.sigmaE2) / Swift.max(abs(want.sigmaE2), 1e-300)
				if sigmaGap > worst { worst = sigmaGap }
				#expect(sigmaGap < Self.bound,
						"\(entry.name) point \(point.label): sigma^2 \(subject.sigmaE2), dense \(want.sigmaE2)")
				compared += 1

				for a in 0..<r {
					for b in 0..<r {
						let got = subject.gArr[a][b]
						let expected = want.gArr[a][b]
						let scale = Self.largest(want.gArr.flatMap { $0 })
						let gap = abs(got - expected) / Swift.max(abs(expected), scale)
						if gap > worst { worst = gap }
						#expect(gap < Self.bound,
								"\(entry.name) point \(point.label) G[\(a)][\(b)]: \(got), dense \(expected)")
						compared += 1
					}
				}
			}
		}
		#expect(compared >= 30, "only \(compared) EM quantities compared")
		#expect(worst < Self.bound, "worst relative gap in the EM step was \(worst)")
	}

	/// The converged fit is a stationary point of the REML likelihood.
	///
	/// The score IS the gradient, so this asks the only question that decides whether a
	/// converged answer is the right one, and it asks it without reference to any other
	/// implementation. Proximity to statsmodels cannot answer it: two optimisers stopping
	/// at their own tolerances near the same optimum differ by an amount that says nothing
	/// about which is closer to it.
	///
	/// Reported as `max_k |score_k| / AI[k][k]`, the Newton step that entry would still
	/// take. A stationary point has nothing left to take.
	///
	/// Measured per design, before and after the projection fix. All five converge in 9-10
	/// iterations against a cap of 100, so none of this is an iteration limit:
	///
	/// | design | before | after |
	/// |---|---|---|
	/// | `randomIntercept_balanced`   | 3.37e-05 | 1.01e-06 |
	/// | `randomIntercept_unbalanced` | 1.02e-05 | 9.25e-07 |
	/// | `randomSlope_balanced`       | 3.96e-06 | 9.59e-07 |
	/// | `randomIntercept_manyGroups` | 1.12e-06 | 1.10e-06 |
	/// | `randomSlope_unbalanced`     | 4.71e-06 | **1.93e-05** |
	///
	/// Four designs land one to two orders of magnitude closer to stationarity. The fifth
	/// moves the other way, and the reason is worth recording: `fitGeneralLME` stops on
	/// `paramHasConverged`, which tests the **change in the parameters**, not the gradient.
	/// A correct information matrix is larger than the truncated one, so `AI^-1 score` is
	/// smaller, so a step-size test trips sooner. On the hardest design that stops the loop
	/// at a point the gradient says is not yet stationary.
	///
	/// The bound is 1e-4, above the current worst. It is a guard against a fit that stops
	/// somewhere unrelated to an optimum, not a certificate that every design is tight.
	@Test("The converged fit is a stationary point of the REML likelihood")
	func convergedFitIsStationary() throws {
		let fixture = try Self.loadFixture()
		var worst = 0.0
		var worstName = ""

		for entry in fixture.cases {
			// The near-degenerate design's tau^2 sits on the zero boundary, where the
			// optimum is a KKT point and the gradient is *not* required to vanish — it
			// points outward against the constraint. Measured at 0.037 there, against
			// 1e-6 on the interior designs. Excluded because the property does not hold,
			// not because it is inconvenient.
			guard entry.name != "randomIntercept_smallVariance" else { continue }
			let grouping = try GroupingFactor(entry.groups)
			let r = entry.randomEffectsPerGroup
			let model = GeneralLMEModel(
				fixedEffects: try DenseMatrix(entry.X),
				randomEffectsDesign: try DenseMatrix(entry.Z),
				response: entry.y,
				grouping: grouping,
				randomEffectsPerGroup: r)
			let fit = try fitGeneralLME(model)

			var gArr = [[Double]](repeating: [Double](repeating: 0, count: r), count: r)
			for i in 0..<r {
				for j in 0..<r { gArr[i][j] = fit.gMatrix[i, j] }
			}
			let oracle = try Self.dense(
				x: entry.X, z: entry.Z, y: entry.y,
				groupIdx: grouping.groupIndices, r: r,
				gArr: gArr, sigmaE2: fit.varianceResidual)

			// Scale each score entry by its own information, giving the Newton step that
			// entry would still take. A stationary point has nothing left to take.
			for k in 0..<oracle.score.count {
				let information = abs(oracle.ai[k][k])
				guard information > 0 else { continue }
				let remaining = abs(oracle.score[k]) / information
				if remaining > worst {
					worst = remaining
					worstName = "\(entry.name) theta[\(k)]"
				}
			}
		}
		let complaint = "largest remaining Newton step at convergence was \(worst) at \(worstName)"
		#expect(worst < 1e-4, "\(complaint)")
	}

	/// The cross-group blocks of `P` are worth the arithmetic they cost.
	///
	/// This is the test that explains the other two. `AI[j][k] = 1/2 a_j' P a_k` needs the
	/// whole `P`, and the cheap thing to do — accumulate one `nig x nig` block per group —
	/// computes `SUM_i a_j,i' P_ii a_k,i` instead. That truncation is what the source did
	/// until this commit, and it matched the source to 2.99e-06, the same floor the score
	/// agrees at.
	///
	/// So this asserts the two are *materially different*, which is the fact that makes the
	/// global correction necessary. Without it a future change could drop the correction as
	/// dead weight, watch every converged fit stay where it was — because the score, not
	/// the information, fixes the optimum — and land back here.
	@Test("The block-diagonal truncation of P is materially wrong")
	func blockDiagonalTruncationIsMateriallyDifferent() throws {
		let fixture = try Self.loadFixture()
		var worst = 0.0

		for entry in fixture.cases {
			let grouping = try GroupingFactor(entry.groups)
			let r = entry.randomEffectsPerGroup
			let p = entry.X[0].count

			for point in Self.points {
				let (gArr, sigmaE2) = Self.parameters(at: point, y: entry.y, r: r)
				let oracle = try Self.dense(
					x: entry.X, z: entry.Z, y: entry.y,
					groupIdx: grouping.groupIndices, r: r, gArr: gArr, sigmaE2: sigmaE2)
				let subject = try generalAIREMLUpdate(
					resid: oracle.resid, xData: entry.X, zData: entry.Z,
					m: grouping.groupCount, r: r,
					groupIdx: grouping.groupIndices,
					gArr: gArr, sigmaE2: sigmaE2, p: p)

				_ = subject
				let flat = oracle.ai.flatMap { $0 }
				let scale = Self.largest(flat)
				for j in 0..<oracle.ai.count {
					for k in 0..<oracle.ai.count {
						let truncated = oracle.blockAI[j][k]
						let full = oracle.ai[j][k]
						let gap = abs(full - truncated) / Swift.max(abs(full), scale)
						if gap > worst { worst = gap }
					}
				}
			}
		}
		// Measured at 0.135 across the six designs. The bound is an order of magnitude
		// below that: this must fail loudly if the two ever coincide, because that would
		// mean the fixture no longer exercises the cross-group blocks at all.
		let complaint = "the truncation differs from the full projection by only \(worst); the designs no longer separate the two"
		#expect(worst > 1e-2, "\(complaint)")
	}
}

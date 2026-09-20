//
//  GStudyTwoFacetOracleTests.swift
//  BusinessMath
//
//  An exact oracle for the two-facet `gStudy(_:facetLabels:)`, which had none.
//
//  `gStudy.json` and `GStudyReferenceTests` pin the **one-facet** overload against
//  statsmodels. The two-facet overload — seven components from a fully crossed p × r × i
//  design, and the higher-complexity half of the file — is checked only by
//  `GStudyTests`, and what those tests assert cannot fail:
//
//  | existing assertion | why it is safe against every wrong answer |
//  |---|---|
//  | seven components exist | structural |
//  | every variance `>= 0` | the function truncates negatives to zero, so this is a tautology |
//  | `totalVariance == sum(components)` | `totalVariance` *is* computed as that sum |
//  | percentages sum to 100 | they are computed as shares of that same total |
//  | uniform data gives zeros | true of almost any decomposition |
//
//  The test named "Known three-way data with verifiable variance components" works the
//  grand mean, person means, rater means and item means out by hand in its comments and
//  then asserts none of them.
//
//  ## Where the expected values come from
//
//  Not from a reference implementation, and not from the data. The data is *built* from
//  seven mutually orthogonal effects that this file chooses:
//
//      y[p][r][i] = mu + a_p + b_r + c_i + ab[p][r] + ac[p][i] + bc[r][i] + e[p][r][i]
//
//  Each effect is projected onto the contrast space of its own term — main effects centred,
//  two-way terms double-centred, the residual triple-centred — so every margin of every term
//  is exactly zero and the terms are mutually orthogonal. The ANOVA sums of squares of such a
//  construction are known in closed form from the effect arrays alone:
//
//      SS_p = n_r n_i SUM a_p^2        SS_pr  = n_i SUM ab^2        SS_pri = SUM e^2
//
//  so the expected mean squares, and the variance components the EMS algebra must produce
//  from them, are computed without looking at `y` at all. There is no sampling noise and no
//  second implementation to be wrong in the same way — the answer is fixed by the inputs.
//
//  ## Why the dimensions are 5 x 4 x 3
//
//  The EMS inversion divides each component by a different product: `sigma_p` by `n_r n_i`,
//  `sigma_r` by `n_p n_i`, `sigma_i` by `n_p n_r`, `sigma_pr` by `n_i`, `sigma_pi` by `n_r`,
//  `sigma_ri` by `n_p`. Every existing two-facet test uses 3x2x2 or 4x2x3, where several of
//  those products coincide and a swapped divisor is invisible. Three distinct dimensions, all
//  greater than two, are the minimum that can tell them apart.
//
//  ## Mean squares are checked separately from variance components
//
//  `VarianceComponent` carries `df` and `meanSquare` as well as `variance`, so a failure
//  localises: if the mean squares agree and the variances do not, the ANOVA is right and the
//  EMS algebra is wrong; if the mean squares disagree, the decomposition is wrong and the
//  algebra was never reached. That split is what made the AI-REML defect attributable rather
//  than merely visible.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Two-facet G-study against constructed orthogonal effects")
struct GStudyTwoFacetOracleTests {

	// MARK: - Orthogonal effect construction

	private static func centred(_ v: [Double]) -> [Double] {
		let total = v.reduce(0, +)
		let mean = total / Double(v.count)
		return v.map { $0 - mean }
	}

	/// Double-centred, so both margins are exactly zero.
	private static func doubleCentred(_ m: [[Double]]) -> [[Double]] {
		let rows = m.count
		let cols = m[0].count
		var rowMean = [Double](repeating: 0, count: rows)
		var colMean = [Double](repeating: 0, count: cols)
		var grand = 0.0
		for a in 0..<rows {
			for b in 0..<cols {
				rowMean[a] += m[a][b]
				colMean[b] += m[a][b]
				grand += m[a][b]
			}
		}
		for a in 0..<rows { rowMean[a] /= Double(cols) }
		for b in 0..<cols { colMean[b] /= Double(rows) }
		grand /= Double(rows * cols)

		var out = m
		for a in 0..<rows {
			for b in 0..<cols {
				let corrected = m[a][b] - rowMean[a] - colMean[b]
				out[a][b] = corrected + grand
			}
		}
		return out
	}

	/// Triple-centred: the three-way contrast, every margin exactly zero.
	private static func tripleCentred(_ t: [[[Double]]]) -> [[[Double]]] {
		let nP = t.count, nR = t[0].count, nI = t[0][0].count
		var mPR = [[Double]](repeating: [Double](repeating: 0, count: nR), count: nP)
		var mPI = [[Double]](repeating: [Double](repeating: 0, count: nI), count: nP)
		var mRI = [[Double]](repeating: [Double](repeating: 0, count: nI), count: nR)
		var mP = [Double](repeating: 0, count: nP)
		var mR = [Double](repeating: 0, count: nR)
		var mI = [Double](repeating: 0, count: nI)
		var grand = 0.0
		for p in 0..<nP {
			for r in 0..<nR {
				for i in 0..<nI {
					let v = t[p][r][i]
					mPR[p][r] += v; mPI[p][i] += v; mRI[r][i] += v
					mP[p] += v; mR[r] += v; mI[i] += v; grand += v
				}
			}
		}
		for p in 0..<nP { for r in 0..<nR { mPR[p][r] /= Double(nI) } }
		for p in 0..<nP { for i in 0..<nI { mPI[p][i] /= Double(nR) } }
		for r in 0..<nR { for i in 0..<nI { mRI[r][i] /= Double(nP) } }
		for p in 0..<nP { mP[p] /= Double(nR * nI) }
		for r in 0..<nR { mR[r] /= Double(nP * nI) }
		for i in 0..<nI { mI[i] /= Double(nP * nR) }
		grand /= Double(nP * nR * nI)

		var out = t
		for p in 0..<nP {
			for r in 0..<nR {
				for i in 0..<nI {
					let pairs: Double = mPR[p][r] + mPI[p][i] + mRI[r][i]
					let singles: Double = mP[p] + mR[r] + mI[i]
					let corrected: Double = t[p][r][i] - pairs + singles
					out[p][r][i] = corrected - grand
				}
			}
		}
		return out
	}

	// MARK: - A design

	/// Seven orthogonal effects and the data they generate.
	private struct Design {
		let name: String
		let nP: Int, nR: Int, nI: Int
		let a: [Double], b: [Double], c: [Double]
		let ab: [[Double]], ac: [[Double]], bc: [[Double]]
		let e: [[[Double]]]
		let data: [[[Double]]]
	}

	/// `scale` multiplies each term, so a design can switch a term off entirely by passing
	/// zero for it — which is how the truncation cases are built.
	private static func design(
		name: String, nP: Int, nR: Int, nI: Int,
		scaleA: Double = 1, scaleB: Double = 1, scaleC: Double = 1,
		scaleAB: Double = 1, scaleAC: Double = 1, scaleBC: Double = 1,
		scaleE: Double = 1
	) -> Design {
		// Deterministic, index-derived values. No RNG: the expected answers must be a
		// function of the source file, not of a seed.
		// Every binding below is annotated, and every one separates the integer arithmetic
		// from the `Double` conversion. That is not style. CI runs Swift 6.2.1 and this file
		// first shipped with the nested form —
		//
		//     let rawAB = (0..<nP).map { p in (0..<nR).map { r in Double((p * 3 + r * 5) % 7) - 3 } }
		//
		// — which builds instantly on the local 6.4 and fails on CI with "unable to
		// type-check this expression in reasonable time". An untyped `let` whose right-hand
		// side mixes a `Double(...)` conversion with nested arithmetic, inside nested `map`
		// closures with nothing to anchor the element type, is the exact shape that fails.
		// Pinning the result type is what collapses the solver's search; the shorter lines
		// are a side effect.
		let rawA: [Double] = (0..<nP).map { index in
			let raw: Int = (index * 7) % 11
			return Double(raw) - 5
		}
		let rawB: [Double] = (0..<nR).map { index in
			let raw: Int = (index * 5) % 9
			return Double(raw) - 4
		}
		let rawC: [Double] = (0..<nI).map { index in
			let raw: Int = (index * 3) % 7
			return Double(raw) - 3
		}
		let a: [Double] = centred(rawA).map { $0 * scaleA }
		let b: [Double] = centred(rawB).map { $0 * scaleB }
		let c: [Double] = centred(rawC).map { $0 * scaleC }

		var rawAB: [[Double]] = []
		for p in 0..<nP {
			var row: [Double] = []
			for r in 0..<nR {
				let raw: Int = (p * 3 + r * 5) % 7
				row.append(Double(raw) - 3)
			}
			rawAB.append(row)
		}
		var rawAC: [[Double]] = []
		for p in 0..<nP {
			var row: [Double] = []
			for i in 0..<nI {
				let raw: Int = (p * 5 + i * 2) % 9
				row.append(Double(raw) - 4)
			}
			rawAC.append(row)
		}
		var rawBC: [[Double]] = []
		for r in 0..<nR {
			var row: [Double] = []
			for i in 0..<nI {
				let raw: Int = (r * 2 + i * 7) % 5
				row.append(Double(raw) - 2)
			}
			rawBC.append(row)
		}
		let ab: [[Double]] = doubleCentred(rawAB).map { row in row.map { $0 * scaleAB } }
		let ac: [[Double]] = doubleCentred(rawAC).map { row in row.map { $0 * scaleAC } }
		let bc: [[Double]] = doubleCentred(rawBC).map { row in row.map { $0 * scaleBC } }

		// A product, because a sum is not a three-way interaction. The first version of
		// this used `(p * 11 + r * 13 + i * 17) % 13`, where 13 is congruent to zero mod 13
		// — the `r` term vanished, leaving a function of `p` and `i` alone, whose three-way
		// contrast is identically zero. Every design then carried a residual of ~1e-16 and
		// the EMS inversion was never exercised with a real `MS_e`. Three tests passed
		// against it. `oracleDesignsExerciseEveryTerm` below is the guard that keeps this
		// from coming back.
		var rawE: [[[Double]]] = []
		for p in 0..<nP {
			var plane: [[Double]] = []
			for r in 0..<nR {
				var row: [Double] = []
				for i in 0..<nI {
					let product: Int = (p + 1) * (r + 2) * (i + 3)
					let raw: Int = product % 11
					row.append(Double(raw) - 5)
				}
				plane.append(row)
			}
			rawE.append(plane)
		}
		let e: [[[Double]]] = tripleCentred(rawE).map { plane in
			plane.map { row in row.map { $0 * scaleE } }
		}

		let mu = 10.0
		var data = [[[Double]]]()
		for p in 0..<nP {
			var plane = [[Double]]()
			for r in 0..<nR {
				var row = [Double]()
				for i in 0..<nI {
					let mains: Double = a[p] + b[r] + c[i]
					let twos: Double = ab[p][r] + ac[p][i] + bc[r][i]
					row.append(mu + mains + twos + e[p][r][i])
				}
				plane.append(row)
			}
			data.append(plane)
		}
		return Design(name: name, nP: nP, nR: nR, nI: nI,
					  a: a, b: b, c: c, ab: ab, ac: ac, bc: bc, e: e, data: data)
	}

	// MARK: - What the design implies

	/// The seven `(df, meanSquare, rawVariance, variance)` values the design fixes.
	private struct Expected {
		let df: [String: Int]
		let ms: [String: Double]
		let raw: [String: Double]
		let truncated: [String: Double]
	}

	private static func sumSquares(_ v: [Double]) -> Double {
		v.reduce(0) { $0 + $1 * $1 }
	}

	private static func expected(_ d: Design) -> Expected {
		let nP = Double(d.nP), nR = Double(d.nR), nI = Double(d.nI)

		let ssP: Double = nR * nI * sumSquares(d.a)
		let ssR: Double = nP * nI * sumSquares(d.b)
		let ssI: Double = nP * nR * sumSquares(d.c)
		let ssPR: Double = nI * d.ab.reduce(0) { $0 + sumSquares($1) }
		let ssPI: Double = nR * d.ac.reduce(0) { $0 + sumSquares($1) }
		let ssRI: Double = nP * d.bc.reduce(0) { $0 + sumSquares($1) }
		let ssE: Double = d.e.reduce(0) { acc, plane in
			acc + plane.reduce(0) { $0 + sumSquares($1) }
		}

		let dfP = d.nP - 1, dfR = d.nR - 1, dfI = d.nI - 1
		let dfPR = dfP * dfR, dfPI = dfP * dfI, dfRI = dfR * dfI
		let dfE = dfP * dfR * dfI

		let msP = ssP / Double(dfP)
		let msR = ssR / Double(dfR)
		let msI = ssI / Double(dfI)
		let msPR = ssPR / Double(dfPR)
		let msPI = ssPI / Double(dfPI)
		let msRI = ssRI / Double(dfRI)
		let msE = ssE / Double(dfE)

		// The EMS inversion for a fully crossed random-effects p x r x i design with one
		// observation per cell, written out here rather than shared with the source.
		let vE: Double = msE
		let vPR: Double = (msPR - msE) / nI
		let vPI: Double = (msPI - msE) / nR
		let vRI: Double = (msRI - msE) / nP
		let pTerm: Double = msP - msPR - msPI + msE
		let vP: Double = pTerm / (nR * nI)
		let rTerm: Double = msR - msPR - msRI + msE
		let vR: Double = rTerm / (nP * nI)
		let iTerm: Double = msI - msPI - msRI + msE
		let vI: Double = iTerm / (nP * nR)

		let raw: [String: Double] = [
			"p": vP, "raters": vR, "items": vI,
			"p x raters": vPR, "p x items": vPI,
			"raters x items": vRI, "p x raters x items": vE
		]
		var truncated = raw
		for (k, v) in raw where v < 0 { truncated[k] = 0 }

		return Expected(
			df: ["p": dfP, "raters": dfR, "items": dfI,
				 "p x raters": dfPR, "p x items": dfPI,
				 "raters x items": dfRI, "p x raters x items": dfE],
			ms: ["p": msP, "raters": msR, "items": msI,
				 "p x raters": msPR, "p x items": msPI,
				 "raters x items": msRI, "p x raters x items": msE],
			raw: raw, truncated: truncated)
	}

	private static let designs: [Design] = [
		// Three distinct dimensions, every term present.
		design(name: "asymmetric 5x4x3", nP: 5, nR: 4, nI: 3),
		// Same shape, terms weighted very differently, so no two divisors can be confused
		// by the components happening to be similar in size.
		design(name: "person dominant", nP: 5, nR: 4, nI: 3,
			   scaleA: 6, scaleB: 0.4, scaleC: 0.2,
			   scaleAB: 0.3, scaleAC: 0.25, scaleBC: 0.15, scaleE: 0.5),
		design(name: "facet dominant", nP: 4, nR: 5, nI: 3,
			   scaleA: 0.2, scaleB: 5, scaleC: 3,
			   scaleAB: 0.2, scaleAC: 0.2, scaleBC: 0.2, scaleE: 0.4),
		// No person x rater interaction at all: its raw estimate is -MS_e / n_i, which is
		// negative, so this is the truncation path with a known value behind it.
		design(name: "no p x r interaction", nP: 5, nR: 3, nI: 4, scaleAB: 0),
		// Two terms switched off at once.
		design(name: "no two-way terms on the facets", nP: 4, nR: 3, nI: 5,
			   scaleAB: 0, scaleBC: 0)
	]

	// MARK: - Comparison

	/// Relative where the reference is meaningfully large, absolute otherwise, with the
	/// absolute floor scaled by the largest mean square in the same design.
	private static func agrees(_ got: Double, _ expected: Double,
							   scale: Double, relative: Double) -> Bool {
		let gap = abs(got - expected)
		guard gap > 0 else { return true }
		let floor = relative * scale
		guard abs(expected) > floor else { return gap <= floor }
		return gap / abs(expected) <= relative
	}

	/// Measured, not chosen.
	///
	/// The effects are centred in floating point before the data is summed, so the sums of
	/// squares recovered from `y` cannot match those computed from the effect arrays to the
	/// last bit. Measured worst case across the five designs: **3.1e-14** relative on the
	/// mean squares and **1.2e-13** on the variance components, the latter larger because the
	/// EMS inversion differences four mean squares of similar size.
	///
	/// The bound is 1e-9 — four orders above the measured worst, and still far tighter than
	/// any structural error it must catch: the smallest of those is a swapped divisor, which
	/// moves a component by a factor of `n_r / n_p` at least, here 20%.
	static let bound = 1e-9

	private static func largest(_ values: [Double]) -> Double {
		var best = 0.0
		for v in values where abs(v) > best { best = abs(v) }
		return Swift.max(best, 1e-300)
	}

	private static func indexed(_ result: GStudyResult<Double>) -> [String: VarianceComponent<Double>] {
		var out = [String: VarianceComponent<Double>]()
		for component in result.components { out[component.source] = component }
		return out
	}

	// MARK: - The tests

	@Test("Degrees of freedom match the design")
	func degreesOfFreedomMatch() throws {
		for d in Self.designs {
			let result = try gStudy(d.data, facetLabels: ("raters", "items"))
			let byName = Self.indexed(result)
			let want = Self.expected(d).df
			for (source, df) in want {
				let component = try #require(byName[source], "\(d.name): no component '\(source)'")
				#expect(component.df == df,
						"\(d.name) \(source): df \(component.df), expected \(df)")
			}
		}
	}

	@Test("Mean squares match the sums of squares the effects fix")
	func meanSquaresMatch() throws {
		var worst = 0.0
		for d in Self.designs {
			let result = try gStudy(d.data, facetLabels: ("raters", "items"))
			let byName = Self.indexed(result)
			let want = Self.expected(d).ms
			let scale = Self.largest(Array(want.values))
			for (source, ms) in want {
				let component = try #require(byName[source], "\(d.name): no component '\(source)'")
				let got = component.meanSquare
				let gap = abs(got - ms) / Swift.max(abs(ms), scale)
				if gap > worst { worst = gap }
				#expect(Self.agrees(got, ms, scale: scale, relative: Self.bound),
						"\(d.name) \(source): MS \(got), expected \(ms)")
			}
		}
		#expect(worst < Self.bound, "worst relative gap in the mean squares was \(worst)")
	}

	@Test("Variance components match the expected-mean-square algebra")
	func varianceComponentsMatch() throws {
		var worst = 0.0
		var compared = 0
		for d in Self.designs {
			let result = try gStudy(d.data, facetLabels: ("raters", "items"))
			let byName = Self.indexed(result)
			let want = Self.expected(d).truncated
			let scale = Self.largest(Array(want.values))
			for (source, variance) in want {
				let component = try #require(byName[source], "\(d.name): no component '\(source)'")
				let got = component.variance
				let gap = abs(got - variance) / Swift.max(abs(variance), scale)
				if gap > worst { worst = gap }
				#expect(Self.agrees(got, variance, scale: scale, relative: Self.bound),
						"\(d.name) \(source): variance \(got), expected \(variance)")
				compared += 1
			}
		}
		#expect(compared == 35, "compared \(compared) components, expected 35")
		#expect(worst < Self.bound, "worst relative gap in the components was \(worst)")
	}

	@Test("The designs actually reach the truncation path, with a known value behind it")
	func truncationIsExercisedAndHasAKnownRawValue() throws {
		// Without this the previous test could pass on designs where nothing is ever
		// clamped, and the clamp would be unchecked. `no p x r interaction` sets `ab` to
		// zero, so `MS_pr` is zero and the raw estimate is `-MS_e / n_i`: negative by
		// construction, and its exact size is known.
		var truncationsSeen = 0
		for d in Self.designs {
			let want = Self.expected(d)
			let result = try gStudy(d.data, facetLabels: ("raters", "items"))
			let byName = Self.indexed(result)
			for (source, rawValue) in want.raw where rawValue < 0 {
				truncationsSeen += 1
				let component = try #require(byName[source])
				#expect(component.variance == 0,
						"\(d.name) \(source): raw \(rawValue) should clamp to 0, got \(component.variance)")
			}
		}
		#expect(truncationsSeen >= 2,
				"only \(truncationsSeen) components truncated; the designs no longer exercise the clamp")
	}

	@Test("Every term the oracle claims to construct actually contributes")
	func oracleDesignsExerciseEveryTerm() throws {
		// The fixture's own guard, and it has already earned its place: an earlier residual
		// array collapsed to zero because its modulus cancelled one index, so `MS_e` was
		// ~1e-16 in every design and three tests passed while the EMS inversion's residual
		// term went untested. A fixture that does not exercise what it claims is worth less
		// than no fixture, because it reports the same PASS either way.
		let full = Self.designs[0]
		let want = Self.expected(full)
		let scale = Self.largest(Array(want.ms.values))
		for (source, ms) in want.ms {
			#expect(ms > scale * 1e-6,
					"\(full.name): mean square for '\(source)' is \(ms), which is not a term")
		}

		// And the residual specifically, in every design, since it is the term the whole
		// inversion is built on.
		for d in Self.designs {
			let residual = Self.expected(d).ms["p x raters x items"] ?? 0
			let designScale = Self.largest(Array(Self.expected(d).ms.values))
			#expect(residual > designScale * 1e-6,
					"\(d.name): MS_e is \(residual), so the EMS algebra is untested here")
		}
	}

	@Test("A swapped divisor would be visible in these designs")
	func theDesignsSeparateTheDivisors() throws {
		// The guard on the guard. Every divisor in the EMS inversion is a different product
		// of the three dimensions; if a design made two of them equal, a component computed
		// with the wrong one would still come out right. This asserts the fixtures keep them
		// apart, so a future edit that "simplifies" the dimensions cannot silently blind the
		// tests above.
		for d in Self.designs {
			let nP = Double(d.nP), nR = Double(d.nR), nI = Double(d.nI)
			let divisors: [Double] = [nR * nI, nP * nI, nP * nR, nI, nR, nP]
			let distinct = Set(divisors.map { $0.description })
			#expect(distinct.count == divisors.count,
					"\(d.name): divisors \(divisors) are not all distinct")
		}
	}
}

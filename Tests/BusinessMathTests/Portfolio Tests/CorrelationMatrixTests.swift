//
//  CorrelationMatrixTests.swift
//  BusinessMathTests
//
//  `Portfolio.correlationMatrix` returned correlations above one, and had no test at all.
//
//  It read `cov[i][j] / (sqrt(cov[i][i]) * sqrt(cov[j][j]))` for every cell including the
//  diagonal. `sqrt(v) * sqrt(v)` is not `v` in binary floating point, so `corr(i, i)` came
//  back as **1.0000000000000002** — one ulp over — on ordinary risky assets. Measured before
//  the fix, the worst |diagonal − 1| across 40 sampled pairs was `2.220446049250313e-16`,
//  which is exactly one ulp at 1.0.
//
//  A correlation above one is not a correlation. It fails any `|rho| <= 1` assertion
//  downstream, and a matrix carrying it is not positive semi-definite, so a Cholesky
//  factorisation can fail on data that is perfectly well behaved.
//
//  The constant-asset case is separate and is **not** a defect: an asset that never moves has
//  zero variance and its correlation is `0 / 0`. NaN is what `numpy.corrcoef` and R's `cor`
//  return there, diagonal included, and it is the same choice `sharpeRatio` makes at zero
//  risk — see `SharpeZeroRiskTests`. These tests pin it so it is not "helpfully" turned into
//  a zero, which would report "uncorrelated" where there is no finding at all.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Correlation matrix stays inside [-1, 1]")
struct CorrelationMatrixTests {

	/// Twelve monthly observations, which is what the sibling portfolio tests use.
	private func portfolio(_ series: [[Double]]) -> Portfolio<Double> {
		let periods = (0..<series[0].count).map { Period.month(year: 2025, month: $0 + 1) }
		let ts = series.map { TimeSeries(periods: periods, values: $0) }
		let names = (0..<series.count).map { "A\($0)" }
		return Portfolio(assets: names, returns: ts, riskFreeRate: 0.0)
	}

	private static let riskyA: [Double] =
		[0.03, -0.01, 0.04, 0.02, -0.02, 0.05, 0.01, -0.03, 0.02, 0.04, -0.01, 0.03]
	private static let riskyB: [Double] =
		[0.01, 0.02, -0.02, 0.03, 0.01, -0.01, 0.04, 0.02, -0.03, 0.01, 0.02, 0.00]

	// MARK: - The defect

	/// The exact pair that produced `1.0000000000000002` in the second diagonal cell.
	@Test("Diagonal_IsExactlyOne") func diagonalIsExactlyOne() {
		let matrix = portfolio([Self.riskyA, Self.riskyB]).correlationMatrix
		#expect(matrix[0][0].isEqual(to: 1.0), "an asset is perfectly correlated with itself")
		#expect(matrix[1][1].isEqual(to: 1.0), "this cell was 1.0000000000000002")
	}

	/// The drift is one ulp, so a sweep is what shows it is not a single unlucky fixture.
	/// Before the fix the worst deviation here was 2.220446049250313e-16.
	@Test("Diagonal_IsExactlyOne_AcrossASweep") func diagonalAcrossASweep() {
		for k in 1...40 {
			let a = (0..<12).map { Double(($0 * 7 + k * 3) % 11) / 100.0 - 0.05 }
			let b = (0..<12).map { Double(($0 * 5 + k * 2) % 13) / 100.0 - 0.06 }
			let matrix = portfolio([a, b]).correlationMatrix
			#expect(matrix[0][0].isEqual(to: 1.0), "seed \(k), first diagonal")
			#expect(matrix[1][1].isEqual(to: 1.0), "seed \(k), second diagonal")
		}
	}

	/// Every cell of a correlation matrix is in `[-1, 1]`, including near-collinear pairs
	/// where the unclipped ratio overshoots for the same reason the diagonal did.
	@Test("EveryCell_IsWithinTheUnitRange") func everyCellIsWithinTheUnitRange() {
		// `riskyB` scaled and shifted is perfectly collinear with itself, which is where the
		// off-diagonal ratio is most likely to round past one.
		let collinear = Self.riskyB.map { $0 * 3.0 + 0.01 }
		let antiCollinear = Self.riskyB.map { -$0 * 7.0 - 0.02 }
		let matrix = portfolio([Self.riskyB, collinear, antiCollinear]).correlationMatrix
		for (i, row) in matrix.enumerated() {
			for (j, value) in row.enumerated() {
				#expect(value >= -1.0, "cell [\(i)][\(j)] is \(value)")
				#expect(value <= 1.0, "cell [\(i)][\(j)] is \(value)")
			}
		}
		// And the collinear pair really is at the boundary, so the clip is load-bearing here
		// rather than covering a cell that was comfortably inside.
		#expect(matrix[0][1].isEqual(to: 1.0), "a positive affine transform is perfectly correlated")
		#expect(matrix[0][2].isEqual(to: -1.0), "a negative one is perfectly anti-correlated")
	}

	// MARK: - A constant asset, which is not a defect

	/// Cash at an exactly representable rate has a variance of exactly zero, so every
	/// correlation involving it is `0 / 0`.
	@Test("ConstantAsset_IsUndefinedRatherThanZero") func constantAssetIsUndefined() {
		let withCash = portfolio([Self.riskyA, Array(repeating: 0.25, count: 12)])
		#expect(withCash.covarianceMatrix[1][1].isEqual(to: 0.0), "the fixture really has no variance")

		let matrix = withCash.correlationMatrix
		#expect(matrix[0][0].isEqual(to: 1.0), "the risky asset still correlates with itself")
		#expect(matrix[0][1].isNaN, "undefined, not zero — zero would claim 'uncorrelated'")
		#expect(matrix[1][0].isNaN)
		#expect(matrix[1][1].isNaN, "as numpy and R also report for a constant series")
	}

	/// Whether the variance is *exactly* zero depends on the constant, which is worth pinning
	/// because it decides between NaN and a finite, meaningless number.
	@Test("ConstantAsset_ResidueDependsOnTheConstant") func constantResidueDependsOnTheConstant() {
		let representable = portfolio([Self.riskyA, Array(repeating: 0.0, count: 12)])
		#expect(representable.covarianceMatrix[1][1].isEqual(to: 0.0))
		#expect(representable.correlationMatrix[1][1].isNaN)

		// 0.004 is not exactly representable, so the mean carries residue and the variance
		// lands just above zero — measured at 8.207087831195607e-37.
		let inexact = portfolio([Self.riskyA, Array(repeating: 0.004, count: 12)])
		let residualVariance = inexact.covarianceMatrix[1][1]
		#expect(residualVariance > 0, "residue, not a true zero: \(residualVariance)")
		#expect(inexact.correlationMatrix[1][1].isEqual(to: 1.0),
				"so this one takes the ordinary path and its diagonal is one")
	}
}

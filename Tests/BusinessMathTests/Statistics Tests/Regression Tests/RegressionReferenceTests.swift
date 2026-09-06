//
//  RegressionReferenceTests.swift
//  BusinessMath
//
//  An external oracle for multiple linear regression, from statsmodels OLS.
//
//  `MultipleLinearRegressionTests` has 22 tests and its coefficient checks are
//  sound: it fits noiseless data, where the answer is exact, and asserts it to
//  1e-10. What it never does is pin a *derived statistic* to a value. Every one of
//  them is bounded instead:
//
//      #expect(result.standardErrors.allSatisfy { $0 > 0 })
//      #expect(result.fStatistic > 1000)
//      #expect(result.fStatisticPValue < 0.001)
//      #expect(result.adjustedRSquared < result.rSquared)
//
//  Those hold for any positive number, any large number, any small number and any
//  correctly ordered pair. The quantities they are standing in for — standard
//  errors, t-statistics, p-values, confidence intervals, VIF — are the ones that
//  actually get reported, and the ones a convention error moves silently:
//
//  - residual variance over `n - p` instead of `n - p - 1`;
//  - a normal quantile where a t quantile belongs, indistinguishable at n = 500
//    and 25% wrong at n = 8;
//  - a one-tailed p-value reported as two-tailed, halving every one;
//  - VIF from the correlation matrix rather than an auxiliary regression, which
//    agree for two predictors and diverge for three.
//
//  Each passes `> 0`. Several pass `> 1000`.
//
//  ## Tolerances come from the conditioning
//
//  BusinessMath forms and inverts `X'X`; statsmodels takes a pseudo-inverse of `X`.
//  They agree in exact arithmetic and drift in floating point by about the
//  condition number of `X'X` — the *square* of `X`'s. Each case therefore carries
//  its own bound, derived in the generator from that number: 1e-9 for the
//  well-conditioned designs and 3.9e-4 for the one whose predictors are four orders
//  of magnitude apart. One bound across all seven would be either vacuous or
//  unmeetable.
//
//  ## What is checked without an oracle at all
//
//  Least squares is *defined* by `X'(y - Xβ) = 0`. That is checkable directly, it
//  needs no reference, and it cannot agree with statsmodels through a shared
//  misreading of the input — which is the failure mode a fixture alone is exposed
//  to. `residualsAreOrthogonalToThePredictors` does that job.
//
//  Values from Tests/BusinessMathTests/Fixtures/regression.json.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Multiple regression against statsmodels")
struct RegressionReferenceTests {

	// MARK: - Fixture

	private struct Fixture: Decodable {
		let name: String
		let reference: String
		let note: String
		let confidenceLevel: Double
		let cases: [Case]
	}

	private struct Interval: Decodable {
		let lower: Double
		let upper: Double
	}

	private struct Case: Decodable {
		let name: String
		let note: String
		let x: [[Double]]
		let y: [Double]
		let n: Int
		let p: Int
		let confidenceLevel: Double
		let conditionNumber: Double
		let tolerance: Double
		let intercept: Double
		let coefficients: [Double]
		let standardErrors: [Double]
		let tStatistics: [Double]
		let pValues: [Double]
		let confidenceIntervals: [Interval]
		let rSquared: Double
		let adjustedRSquared: Double
		let fStatistic: Double
		let fStatisticPValue: Double
		let residualStandardError: Double
		let residuals: [Double]
		let fittedValues: [Double]
		let vif: [Double]

		/// Whether the fit leaves any residual variation to do statistics on.
		///
		/// With an exact fit the residual standard error is zero, so every standard
		/// error is zero, every t-statistic is infinite and the F-statistic is
		/// whatever the division by zero happened to produce — statsmodels reports
		/// 1.7e30 for the case here. Comparing those numbers would be comparing
		/// arithmetic noise. The case is still worth keeping, for what it pins about
		/// the boundary itself.
		var hasResidualVariation: Bool { residualStandardError > 1e-12 }
	}

	private static func loadFixture() throws -> Fixture {
		guard let url = Bundle.module.url(forResource: "regression",
										  withExtension: "json",
										  subdirectory: "Fixtures")
			?? Bundle.module.url(forResource: "regression", withExtension: "json") else {
			struct Missing: Error { let name: String }
			throw Missing(name: "regression")
		}
		return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
	}

	private static func fit(_ entry: Case) throws -> RegressionResult {
		try multipleLinearRegression(X: entry.x, y: entry.y,
									 confidenceLevel: entry.confidenceLevel)
	}

	/// Compares with a relative bound, so a tolerance means the same thing for a
	/// coefficient near 1e-3 and one near 1e5.
	private static func close(_ got: Double, _ want: Double, _ tolerance: Double) -> Bool {
		let scale = Swift.max(1.0, abs(want))
		return abs(got - want) <= tolerance * scale
	}

	// MARK: - The fixture itself

	@Test("The fixture exercises the conventions it was built to separate")
	func fixtureIsWellFormed() throws {
		let fixture = try Self.loadFixture()
		#expect(fixture.reference.contains("statsmodels"), "reference was '\(fixture.reference)'")
		#expect(fixture.cases.count >= 7, "only \(fixture.cases.count) designs")

		// A t quantile and a normal quantile only separate at small n.
		#expect(fixture.cases.contains { $0.n <= 10 }, "no small-sample design")
		// Degrees of freedom only separate when p is an appreciable share of n.
		#expect(fixture.cases.contains { $0.p >= 5 }, "no design with many predictors")
		// VIF is only diagnostic when it is large, and only ambiguous at p >= 3.
		#expect(fixture.cases.contains { $0.p >= 3 && ($0.vif.max() ?? 0) > 10 },
				"no collinear design with three or more predictors")
		// A p-value has to be a value somewhere, not merely small.
		#expect(fixture.cases.contains { $0.fStatisticPValue > 0.05 },
				"every design has an overwhelming F-test, so no p-value is load-bearing")
		// And the tolerances must actually be differentiated by conditioning.
		#expect(fixture.cases.contains { $0.tolerance > 1e-6 },
				"no ill-conditioned design")
		#expect(fixture.cases.allSatisfy { $0.conditionNumber >= 1 })
	}

	// MARK: - Point estimates

	@Test("Coefficients and the intercept match statsmodels")
	func coefficientsMatch() throws {
		let fixture = try Self.loadFixture()
		for entry in fixture.cases {
			let result = try Self.fit(entry)
			#expect(Self.close(result.intercept, entry.intercept, entry.tolerance),
					"\(entry.name): intercept \(result.intercept), statsmodels \(entry.intercept)")
			#expect(result.coefficients.count == entry.coefficients.count,
					"\(entry.name): \(result.coefficients.count) coefficients, expected \(entry.coefficients.count)")
			guard result.coefficients.count == entry.coefficients.count else { continue }
			for (j, reference) in entry.coefficients.enumerated() {
				#expect(Self.close(result.coefficients[j], reference, entry.tolerance),
						"\(entry.name) coefficient \(j): \(result.coefficients[j]), statsmodels \(reference)")
			}
		}
	}

	@Test("Fitted values and residuals match, observation by observation")
	func fittedValuesAndResidualsMatch() throws {
		let fixture = try Self.loadFixture()
		var compared = 0
		for entry in fixture.cases {
			let result = try Self.fit(entry)
			guard result.fittedValues.count == entry.fittedValues.count,
				  result.residuals.count == entry.residuals.count else {
				Issue.record("\(entry.name): \(result.fittedValues.count) fitted, \(result.residuals.count) residuals for n = \(entry.n)")
				continue
			}
			for i in 0..<entry.fittedValues.count {
				#expect(Self.close(result.fittedValues[i], entry.fittedValues[i], entry.tolerance),
						"\(entry.name) fitted[\(i)]: \(result.fittedValues[i]), statsmodels \(entry.fittedValues[i])")
				#expect(Self.close(result.residuals[i], entry.residuals[i], entry.tolerance),
						"\(entry.name) residual[\(i)]: \(result.residuals[i]), statsmodels \(entry.residuals[i])")
				compared += 2
			}
		}
		#expect(compared >= 300, "only \(compared) values compared")
	}

	// MARK: - The statistics the existing suite only bounds

	@Test("Standard errors match, rather than merely being positive")
	func standardErrorsMatch() throws {
		let fixture = try Self.loadFixture()
		for entry in fixture.cases where entry.hasResidualVariation {
			let result = try Self.fit(entry)
			// One per parameter: the intercept and then each coefficient.
			#expect(result.standardErrors.count == entry.standardErrors.count,
					"\(entry.name): \(result.standardErrors.count) standard errors, expected \(entry.standardErrors.count)")
			guard result.standardErrors.count == entry.standardErrors.count else { continue }
			for (k, reference) in entry.standardErrors.enumerated() {
				#expect(Self.close(result.standardErrors[k], reference, entry.tolerance),
						"\(entry.name) standard error \(k): \(result.standardErrors[k]), statsmodels \(reference)")
			}
		}
	}

	@Test("The residual standard error uses n - p - 1 degrees of freedom")
	func residualStandardErrorMatches() throws {
		let fixture = try Self.loadFixture()
		for entry in fixture.cases where entry.hasResidualVariation {
			let result = try Self.fit(entry)
			#expect(Self.close(result.residualStandardError, entry.residualStandardError, entry.tolerance),
					"\(entry.name): \(result.residualStandardError), statsmodels \(entry.residualStandardError)")

			// The same claim stated independently of the fixture: s² is the residual
			// sum of squares over n - p - 1. Using n - p instead would pass the
			// comparison above only if statsmodels made the same mistake.
			let residualSumOfSquares = result.residuals.reduce(0.0) { $0 + $1 * $1 }
			let degreesOfFreedom = entry.n - entry.p - 1
			guard degreesOfFreedom > 0 else { continue }
			let variance: Double = residualSumOfSquares / Double(degreesOfFreedom)
			#expect(Self.close(result.residualStandardError, variance.squareRoot(), entry.tolerance),
					"\(entry.name): s = \(result.residualStandardError), sqrt(RSS/\(degreesOfFreedom)) = \(variance.squareRoot())")
		}
	}

	@Test("t-statistics match")
	func tStatisticsMatch() throws {
		let fixture = try Self.loadFixture()
		for entry in fixture.cases where entry.hasResidualVariation {
			let result = try Self.fit(entry)
			guard result.tStatistics.count == entry.tStatistics.count else {
				Issue.record("\(entry.name): \(result.tStatistics.count) t-statistics, expected \(entry.tStatistics.count)")
				continue
			}
			for (k, reference) in entry.tStatistics.enumerated() {
				#expect(Self.close(result.tStatistics[k], reference, entry.tolerance),
						"\(entry.name) t[\(k)]: \(result.tStatistics[k]), statsmodels \(reference)")
			}
		}
	}

	@Test("p-values match, and are two-tailed")
	func pValuesMatch() throws {
		let fixture = try Self.loadFixture()
		for entry in fixture.cases where entry.hasResidualVariation {
			let result = try Self.fit(entry)
			guard result.pValues.count == entry.pValues.count else {
				Issue.record("\(entry.name): \(result.pValues.count) p-values, expected \(entry.pValues.count)")
				continue
			}
			for (k, reference) in entry.pValues.enumerated() {
				// An absolute bound: a p-value lives in [0, 1], so relative scaling
				// would quietly loosen the comparison for the small ones that matter
				// most. The ill-conditioned design still needs its own allowance.
				let bound = Swift.max(1e-9, entry.tolerance)
				#expect(abs(result.pValues[k] - reference) <= bound,
						"\(entry.name) p[\(k)]: \(result.pValues[k]), statsmodels \(reference)")
			}
		}
	}

	@Test("Confidence intervals use a t quantile, not a normal one")
	func confidenceIntervalsMatch() throws {
		let fixture = try Self.loadFixture()
		for entry in fixture.cases where entry.hasResidualVariation {
			let result = try Self.fit(entry)
			guard result.confidenceIntervals.count == entry.confidenceIntervals.count else {
				Issue.record("\(entry.name): \(result.confidenceIntervals.count) intervals, expected \(entry.confidenceIntervals.count)")
				continue
			}
			for (k, reference) in entry.confidenceIntervals.enumerated() {
				let interval = result.confidenceIntervals[k]
				#expect(Self.close(interval.lower, reference.lower, entry.tolerance),
						"\(entry.name) interval \(k) lower: \(interval.lower), statsmodels \(reference.lower)")
				#expect(Self.close(interval.upper, reference.upper, entry.tolerance),
						"\(entry.name) interval \(k) upper: \(interval.upper), statsmodels \(reference.upper)")
			}
		}
	}

	@Test("R², adjusted R², F and its p-value match")
	func fitStatisticsMatch() throws {
		let fixture = try Self.loadFixture()
		for entry in fixture.cases where entry.hasResidualVariation {
			let result = try Self.fit(entry)
			#expect(Self.close(result.rSquared, entry.rSquared, entry.tolerance),
					"\(entry.name): R² \(result.rSquared), statsmodels \(entry.rSquared)")
			#expect(Self.close(result.adjustedRSquared, entry.adjustedRSquared, entry.tolerance),
					"\(entry.name): adjusted R² \(result.adjustedRSquared), statsmodels \(entry.adjustedRSquared)")
			#expect(Self.close(result.fStatistic, entry.fStatistic, entry.tolerance),
					"\(entry.name): F \(result.fStatistic), statsmodels \(entry.fStatistic)")
			let bound = Swift.max(1e-9, entry.tolerance)
			#expect(abs(result.fStatisticPValue - entry.fStatisticPValue) <= bound,
					"\(entry.name): F p-value \(result.fStatisticPValue), statsmodels \(entry.fStatisticPValue)")
		}
	}

	@Test("VIF comes from an auxiliary regression, not the correlation matrix")
	func varianceInflationFactorsMatch() throws {
		let fixture = try Self.loadFixture()
		var compared = 0
		for entry in fixture.cases where !entry.vif.isEmpty && entry.hasResidualVariation {
			let result = try Self.fit(entry)
			guard result.vif.count == entry.vif.count else {
				Issue.record("\(entry.name): \(result.vif.count) VIF values for \(entry.p) predictors, expected \(entry.vif.count)")
				continue
			}
			for (j, reference) in entry.vif.enumerated() {
				#expect(Self.close(result.vif[j], reference, entry.tolerance),
						"\(entry.name) VIF[\(j)]: \(result.vif[j]), statsmodels \(reference)")
				compared += 1
			}
		}
		#expect(compared >= 8, "only \(compared) VIF values compared")
	}

	// MARK: - Claims that need no reference

	@Test("Residuals are orthogonal to the predictors, which is what least squares means")
	func residualsAreOrthogonalToThePredictors() throws {
		let fixture = try Self.loadFixture()
		for entry in fixture.cases {
			let result = try Self.fit(entry)
			guard result.residuals.count == entry.n else { continue }

			// With an intercept in the model, the residuals sum to zero.
			let total = result.residuals.reduce(0.0, +)
			let responseScale = entry.y.reduce(0.0) { Swift.max($0, abs($1)) }
			let bound = entry.tolerance * Swift.max(1.0, responseScale) * Double(entry.n)
			#expect(abs(total) <= bound,
					"\(entry.name): residuals sum to \(total), not zero")

			// And each predictor is orthogonal to them. This is the normal equations
			// themselves, so it holds for the true least-squares fit and for nothing
			// else — no reference implementation is involved, which is what makes it
			// worth having next to the comparisons above.
			for j in 0..<entry.p {
				var dot = 0.0
				var columnScale = 0.0
				for i in 0..<entry.n {
					dot += entry.x[i][j] * result.residuals[i]
					columnScale = Swift.max(columnScale, abs(entry.x[i][j]))
				}
				let columnBound = entry.tolerance * Swift.max(1.0, columnScale * responseScale) * Double(entry.n)
				#expect(abs(dot) <= columnBound,
						"\(entry.name): predictor \(j) correlates with the residuals at \(dot)")
			}
		}
	}

	@Test("Fitted values and residuals reconstruct the response")
	func fittedPlusResidualIsTheResponse() throws {
		let fixture = try Self.loadFixture()
		for entry in fixture.cases {
			let result = try Self.fit(entry)
			guard result.fittedValues.count == entry.n, result.residuals.count == entry.n else { continue }
			for i in 0..<entry.n {
				let reconstructed: Double = result.fittedValues[i] + result.residuals[i]
				#expect(Self.close(reconstructed, entry.y[i], entry.tolerance),
						"\(entry.name)[\(i)]: fitted + residual = \(reconstructed), y = \(entry.y[i])")
			}
		}
	}

	@Test("R² and F are consistent with each other")
	func rSquaredAndFAreConsistent() throws {
		let fixture = try Self.loadFixture()
		for entry in fixture.cases where entry.hasResidualVariation {
			let result = try Self.fit(entry)
			let numeratorDF = Double(entry.p)
			let denominatorDF = Double(entry.n - entry.p - 1)
			guard denominatorDF > 0, result.rSquared < 1 else { continue }

			// F = (R²/p) / ((1 - R²)/(n - p - 1)). Both come from the same fit, so
			// this catches a mismatched pair of degrees of freedom between them
			// without reference to anything outside the result.
			let explained: Double = result.rSquared / numeratorDF
			let unexplained: Double = (1 - result.rSquared) / denominatorDF
			guard unexplained > 0 else { continue }
			let implied: Double = explained / unexplained
			#expect(Self.close(result.fStatistic, implied, 1e-6),
					"\(entry.name): F \(result.fStatistic), but R² implies \(implied)")
		}
	}

	// MARK: - The boundary

	@Test("An exact fit reports no residual variation rather than noise")
	func exactFitIsHandledAtTheBoundary() throws {
		let fixture = try Self.loadFixture()
		for entry in fixture.cases where !entry.hasResidualVariation {
			let result = try Self.fit(entry)
			#expect(Self.close(result.rSquared, 1.0, 1e-9),
					"\(entry.name): R² \(result.rSquared) on a noiseless fit")
			#expect(result.residuals.allSatisfy { abs($0) < 1e-8 },
					"\(entry.name): residuals \(result.residuals) on a noiseless fit")
			#expect(result.residualStandardError < 1e-8,
					"\(entry.name): residual standard error \(result.residualStandardError) on a noiseless fit")
			// The coefficients are still exactly recoverable, which is the part of
			// this case that carries information.
			#expect(Self.close(result.intercept, entry.intercept, 1e-7),
					"\(entry.name): intercept \(result.intercept), expected \(entry.intercept)")
			for (j, reference) in entry.coefficients.enumerated() where j < result.coefficients.count {
				#expect(Self.close(result.coefficients[j], reference, 1e-7),
						"\(entry.name) coefficient \(j): \(result.coefficients[j]), expected \(reference)")
			}
			// And whatever is reported for F must at least not be a NaN masquerading
			// as a statistic.
			#expect(!result.fStatistic.isNaN, "\(entry.name): F is NaN")
		}
	}
}

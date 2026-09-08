//
//  LogisticRegressionTests.swift
//  BusinessMath
//
//  Binomial GLM by iteratively reweighted least squares.
//
//  The reference coefficients and standard errors below come from BFGS on the negative
//  log-likelihood, with the standard errors read off the observed information matrix at
//  the optimum — computed outside this library. That is deliberately *not* how the
//  implementation works: IRLS is a Newton method on the score, so agreeing with a
//  quasi-Newton run on the likelihood is agreement between two different routes to the
//  same maximum, not a check of an implementation against itself.
//
//  The separation tests matter more than the fitting tests. Under separation the MLE does
//  not exist — the likelihood increases without bound as the coefficients diverge — and
//  the reference optimizer confirms it, reaching (−225, 63.8) and still climbing. Most
//  libraries return that iterate. It has enormous coefficients, a perfect in-sample AUC,
//  and no predictive validity, and nothing about its shape says so.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Logistic regression")
struct LogisticRegressionTests {

	// MARK: - Against an independent optimizer

	@Test("A single-predictor fit matches a reference likelihood maximisation")
	func singlePredictor() throws {
		let x: [[Double]] = (1...10).map { [Double($0)] }
		let y: [Bool] = [false, false, false, false, true, false, true, true, true, true]
		let model = LogisticRegression(predictors: x, outcomes: y)
		let fit = try model.fit()

		// BFGS on the negative log-likelihood, standard errors from the observed
		// information at the optimum.
		let wantedCoefficients: [Double] = [-7.1590107413, 1.3016383086]
		let wantedErrors: [Double] = [4.7593788138, 0.8400393737]
		#expect(fit.coefficients.count == 2, "expected an intercept and one slope")
		var compared = 0
		for (got, wanted) in zip(fit.coefficients, wantedCoefficients) {
			let scale: Double = Swift.max(Swift.abs(wanted), 1)
			#expect(Swift.abs(got - wanted) < scale * 1e-6, "coefficient \(got), wanted \(wanted)")
			compared += 1
		}
		for (got, wanted) in zip(fit.standardErrors, wantedErrors) {
			let scale: Double = Swift.max(Swift.abs(wanted), 1)
			#expect(Swift.abs(got - wanted) < scale * 1e-6, "standard error \(got), wanted \(wanted)")
			compared += 1
		}
		#expect(compared == 4, "only \(compared) of 4 values were compared")
		#expect(Swift.abs(fit.logLikelihood - (-2.5090087048)) < 1e-8,
				"log-likelihood \(fit.logLikelihood)")
	}

	@Test("A two-predictor fit matches the reference")
	func twoPredictors() throws {
		let x: [[Double]] = [[1, 5], [2, 3], [3, 8], [4, 2], [5, 7], [6, 4],
							 [7, 9], [8, 1], [9, 6], [10, 10], [2, 9], [7, 2]]
		let y: [Bool] = [false, false, false, false, true, false,
						 true, false, true, true, false, true]
		let fit = try LogisticRegression(predictors: x, outcomes: y).fit()

		let wantedCoefficients: [Double] = [-22.5931493494, 2.6219048541, 1.5545281829]
		let wantedErrors: [Double] = [20.0563694468, 2.3529120364, 1.4809169440]
		var compared = 0
		for (got, wanted) in zip(fit.coefficients, wantedCoefficients) {
			#expect(Swift.abs(got - wanted) < Swift.abs(wanted) * 1e-5,
					"coefficient \(got), wanted \(wanted)")
			compared += 1
		}
		for (got, wanted) in zip(fit.standardErrors, wantedErrors) {
			#expect(Swift.abs(got - wanted) < Swift.abs(wanted) * 1e-4,
					"standard error \(got), wanted \(wanted)")
			compared += 1
		}
		#expect(compared == 6, "only \(compared) of 6 values were compared")
		#expect(Swift.abs(fit.logLikelihood - (-2.8462760396)) < 1e-7,
				"log-likelihood \(fit.logLikelihood)")
	}

	@Test("The fitted probability is the logistic of the linear predictor")
	func predictedProbability() throws {
		let x: [[Double]] = (1...10).map { [Double($0)] }
		let y: [Bool] = [false, false, false, false, true, false, true, true, true, true]
		let fit = try LogisticRegression(predictors: x, outcomes: y).fit()
		var checked = 0
		for value in [1.0, 4.0, 5.5, 9.0] {
			let linear: Double = fit.coefficients[0] + fit.coefficients[1] * value
			let wanted: Double = 1 / (1 + Double.exp(-linear))
			let got: Double = fit.probability([value])
			#expect(Swift.abs(got - wanted) < 1e-12, "p(\(value)) = \(got), wanted \(wanted)")
			#expect(got > 0 && got < 1, "a probability outside (0, 1): \(got)")
			checked += 1
		}
		#expect(checked == 4, "only \(checked) points were checked")
	}

	@Test("Without an intercept the fit has one coefficient per predictor")
	func withoutIntercept() throws {
		let x: [[Double]] = (1...10).map { [Double($0)] }
		let y: [Bool] = [false, false, false, false, true, false, true, true, true, true]
		let fit = try LogisticRegression(predictors: x, outcomes: y, intercept: false).fit()
		#expect(fit.coefficients.count == 1, "got \(fit.coefficients.count) coefficients")
		#expect(fit.standardErrors.count == 1)
	}

	// MARK: - The refusals, which matter more than the fits

	@Test("Perfectly separated data is refused rather than fitted")
	func perfectSeparation() throws {
		// x < 3.5 is always false and x > 3.5 always true, so the likelihood climbs
		// without bound as the slope grows. The reference optimizer reaches (−225, 63.8)
		// and is still going; that iterate has a perfect in-sample fit and no meaning.
		let x: [[Double]] = (1...6).map { [Double($0)] }
		let y: [Bool] = [false, false, false, true, true, true]
		let model = LogisticRegression(predictors: x, outcomes: y)
		#expect(throws: LogisticRegressionError.self) {
			_ = try model.fit()
		}
		do {
			_ = try model.fit()
			Issue.record("separated data was fitted")
		} catch let error as LogisticRegressionError {
			guard case .separation(let variables) = error else {
				Issue.record("expected .separation, got \(error)")
				return
			}
			#expect(variables.contains(0), "the offending predictor should be named, got \(variables)")
		}
	}

	@Test("A predictor that separates only one class is still separation")
	func quasiSeparation() throws {
		// Every case with x = 1 is false and nothing else is; the coefficient on that
		// indicator diverges even though the rest of the data is well behaved.
		let x: [[Double]] = [[1, 2], [1, 3], [1, 4], [0, 5], [0, 6], [0, 7], [0, 8], [0, 9]]
		let y: [Bool] = [false, false, false, true, false, true, true, false]
		let model = LogisticRegression(predictors: x, outcomes: y)
		#expect(throws: LogisticRegressionError.self) { _ = try model.fit() }
	}

	@Test("A collinear design is refused as rank deficient, not fitted arbitrarily")
	func rankDeficiency() throws {
		// The second column is twice the first, so the information matrix is singular
		// and the coefficients are not identified — any split between them fits equally.
		let x: [[Double]] = (1...10).map { [Double($0), Double($0) * 2] }
		let y: [Bool] = [false, false, false, false, true, false, true, true, true, true]
		let model = LogisticRegression(predictors: x, outcomes: y)
		#expect(throws: LogisticRegressionError.self) { _ = try model.fit() }
	}

	@Test("Malformed input is refused before any fitting happens")
	func inputValidation() {
		let y: [Bool] = [false, true, false]
		#expect(throws: LogisticRegressionError.self) {
			_ = try LogisticRegression(predictors: [[1.0], [2.0]], outcomes: y).fit()
		}
		#expect(throws: LogisticRegressionError.self) {
			_ = try LogisticRegression<Double>(predictors: [], outcomes: []).fit()
		}
		// Ragged rows.
		#expect(throws: LogisticRegressionError.self) {
			_ = try LogisticRegression(predictors: [[1.0, 2.0], [3.0]], outcomes: [true, false]).fit()
		}
		// One outcome class only: the intercept diverges, which is separation by the
		// empty predictor set.
		#expect(throws: LogisticRegressionError.self) {
			_ = try LogisticRegression(predictors: [[1.0], [2.0], [3.0]],
									   outcomes: [true, true, true]).fit()
		}
	}

	@Test("An iteration budget too small to converge is reported, not silently accepted")
	func doesNotConverge() {
		let x: [[Double]] = (1...10).map { [Double($0)] }
		let y: [Bool] = [false, false, false, false, true, false, true, true, true, true]
		let model = LogisticRegression(predictors: x, outcomes: y)
		#expect(throws: LogisticRegressionError.self) {
			_ = try model.fit(maxIterations: 1, tolerance: 1e-12)
		}
	}
}

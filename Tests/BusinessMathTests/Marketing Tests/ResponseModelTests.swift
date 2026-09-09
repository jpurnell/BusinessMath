//
//  ResponseModelTests.swift
//  BusinessMath
//
//  A propensity-to-respond model, and the three ways a surface over a regression goes
//  quietly wrong.
//
//  - **Scoring a population of the wrong width.** `LogisticFit.probability` returns one
//    half when the argument does not match the fit, because a probability is its return
//    type and it has nowhere to put an error. Score a mis-shaped table through it and
//    every prospect comes back at 0.5 — a column of perfectly well-formed numbers that
//    ranks nobody. The surface refuses instead.
//  - **Lift against the wrong baseline.** Lift is propensity over the *cohort's* response
//    rate. Divide by something else — a target rate, a prior campaign's rate — and every
//    number stays positive, ordered and plausible while meaning nothing.
//  - **A break-even threshold that ignores whether it is reachable.** `cost / margin`
//    above one is not a threshold, it is proof that no contact pays for itself, and
//    returning it as a propensity invites a comparison that can never be true.
//
//  The two anchors below need no reference implementation. At the maximum of a binomial
//  likelihood with an intercept, the score equation for the intercept column is
//  `Σ(yᵢ − pᵢ) = 0` — the fitted probabilities average to the observed response rate,
//  exactly, whatever the other predictors are. With no other predictors, that single
//  fitted probability *is* the response rate.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Response model")
struct ResponseModelTests {

	/// Twelve prospects, one continuous predictor, overlapping outcomes so the fit exists.
	static let spend: [[Double]] = [[10], [20], [30], [40], [50], [60],
									[70], [80], [90], [100], [110], [120]]
	static let responded: [Bool] = [false, true, false, false, true, false,
									true, true, false, true, true, true]

	// MARK: - Identities

	@Test("An intercept-only model fits the observed response rate exactly")
	func interceptOnlyIsTheResponseRate() throws {
		// logit⁻¹(β₀) = ȳ is the closed-form MLE, so this checks IRLS end to end
		// against a number that needs no reference implementation.
		let responded = Self.responded
		let blank = [[Double]](repeating: [], count: responded.count)
		let model = try ResponseModel(predictors: blank, responded: responded)
		let positives: Double = Double(responded.filter { $0 }.count)
		let rate: Double = positives / Double(responded.count)
		let fitted: Double = model.propensity([])
		#expect(Swift.abs(fitted - rate) < 1e-10, "fitted \(fitted) against \(rate)")
		#expect(Swift.abs(model.baselineRate - rate) < 1e-12, "baseline \(model.baselineRate)")
	}

	@Test("Fitted propensities average to the response rate whatever the predictors are")
	func scoreEquationHolds() throws {
		let model = try ResponseModel(predictors: Self.spend, responded: Self.responded)
		var residual: Double = 0
		for (row, outcome) in zip(Self.spend, Self.responded) {
			let observed: Double = outcome ? 1 : 0
			let fitted: Double = model.propensity(row)
			residual += observed - fitted
		}
		#expect(Swift.abs(residual) < 1e-8, "Σ(y − p) = \(residual)")
	}

	@Test("Mean lift over the training cohort is one")
	func meanLiftIsOne() throws {
		let model = try ResponseModel(predictors: Self.spend, responded: Self.responded)
		let lifts: [Double] = Self.spend.map { model.lift($0) }
		let total: Double = lifts.reduce(0, +)
		let mean: Double = total / Double(lifts.count)
		#expect(Swift.abs(mean - 1) < 1e-8, "mean lift \(mean)")
	}

	@Test("Propensity is monotone in a predictor with a positive coefficient")
	func propensityIsMonotone() throws {
		let model = try ResponseModel(predictors: Self.spend, responded: Self.responded)
		let slope: Double = model.fit.coefficients[1]
		#expect(slope > 0, "spend should raise the odds here, got \(slope)")
		var previous: Double = -1
		for row in Self.spend {
			let current: Double = model.propensity(row)
			#expect(current > previous, "\(current) after \(previous)")
			previous = current
		}
	}

	// MARK: - The contact decision

	@Test("Break-even propensity is cost over margin")
	func breakEvenPropensity() throws {
		let model = try ResponseModel(predictors: Self.spend, responded: Self.responded)
		let threshold = try #require(model.breakEvenPropensity(contactCost: 2,
															   marginPerResponse: 50))
		#expect(Swift.abs(threshold - 0.04) < 1e-12, "threshold \(threshold)")
		// Expected profit at exactly the threshold is zero, which is what break-even means.
		let revenue: Double = threshold * 50
		let profit: Double = revenue - 2
		#expect(Swift.abs(profit) < 1e-12, "profit at break-even \(profit)")
	}

	@Test("A contact costing more than a response is worth has no break-even propensity")
	func unreachableBreakEvenIsRefused() throws {
		let model = try ResponseModel(predictors: Self.spend, responded: Self.responded)
		#expect(model.breakEvenPropensity(contactCost: 60, marginPerResponse: 50) == nil)
		#expect(model.breakEvenPropensity(contactCost: 2, marginPerResponse: 0) == nil)
		#expect(model.breakEvenPropensity(contactCost: -1, marginPerResponse: 50) == nil)
		// And nobody is contacted when there is no threshold to clear.
		#expect(!model.shouldContact([120], contactCost: 60, marginPerResponse: 50))
	}

	@Test("Contacting is decided against the threshold, not against the ranking")
	func shouldContactFollowsTheThreshold() throws {
		let model = try ResponseModel(predictors: Self.spend, responded: Self.responded)
		#expect(model.shouldContact([120], contactCost: 2, marginPerResponse: 50))
		// A cost of 45 against a margin of 50 needs a propensity of 0.9, which nothing
		// in this cohort reaches — the best prospect is still not worth contacting.
		#expect(!model.shouldContact([120], contactCost: 45, marginPerResponse: 50))
	}

	// MARK: - Refusals

	@Test("Scoring a population of the wrong width is refused, not filled with one half")
	func scoringRefusesTheWrongWidth() throws {
		let model = try ResponseModel(predictors: Self.spend, responded: Self.responded)
		#expect(model.predictorCount == 1)
		let good = try #require(model.score([[15], [95]]))
		#expect(good.count == 2)
		#expect(model.score([[15, 3], [95, 4]]) == nil)
		#expect(model.score([]) == nil)
	}

	@Test("Separated response data is refused rather than fitted")
	func separationPropagates() {
		let clean: [[Double]] = [[1], [2], [3], [4], [5], [6], [7], [8]]
		let split: [Bool] = [false, false, false, false, true, true, true, true]
		#expect(throws: LogisticRegressionError.separation(variables: [0])) {
			_ = try ResponseModel(predictors: clean, responded: split)
		}
	}

	// MARK: - Composition

	@Test("The model's gains table drives the campaign depth decision")
	func gainsComposeWithCampaignDepth() throws {
		let model = try ResponseModel(predictors: Self.spend, responded: Self.responded)
		let evaluation = try #require(model.inSampleEvaluation)
		#expect(evaluation.auc > 0.5, "a fitted model should outrank chance in sample")
		let table = try #require(model.inSampleGains(buckets: 4))
		#expect(table.rows.count == 4)
		let depth = try #require(optimalCampaignDepth(gains: table, contactCost: 2,
													  marginPerResponse: 50,
													  population: Self.spend.count))
		#expect(depth.profit > 0, "profit \(depth.profit)")
	}
}

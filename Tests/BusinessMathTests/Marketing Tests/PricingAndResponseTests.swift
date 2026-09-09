//
//  PricingAndResponseTests.swift
//  BusinessMath
//
//  Price elasticity, optimal price, campaign depth, and RFM.
//
//  Three fail-silent shapes are pinned here, one per area, and each returns a plausible
//  number rather than an error in the naive implementation:
//
//  - **Optimal price under inelastic demand.** The closed form `P* = cε/(ε+1)` is
//    derived assuming an interior maximum exists. For `−1 < ε < 0` it does not — profit
//    rises without bound as price rises — and the formula returns a **negative price**.
//  - **Campaign depth run to the end.** A gains table with a low contact cost is
//    maximised by contacting everyone, and a fixture built that way cannot tell a
//    working optimiser from one that always returns the last bucket. This fixture has an
//    interior optimum.
//  - **Recency scored the wrong way round.** Recency is days *since* the last purchase,
//    so lower is better. Score it like frequency and the segmentation ranks the
//    customers who have not bought in a year as the best ones — and every downstream
//    number stays perfectly well-formed.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Pricing and response")
struct PricingAndResponseTests {

	// MARK: - Elasticity

	@Test("Own-price elasticity is the log-log regression slope")
	func ownPriceElasticity() throws {
		let prices: [Double] = [10, 12, 14, 16, 18, 20]
		let quantities: [Double] = [100, 82, 70, 60, 53, 47]
		let estimate = try #require(PriceElasticity(prices: prices, quantities: quantities))
		// Slope of ln Q on ln P, computed outside the library.
		#expect(Swift.abs(estimate.elasticity - (-1.0869039652)) < 1e-8,
				"got \(estimate.elasticity)")
		#expect(Swift.abs(estimate.rSquared - 0.9997983919) < 1e-8,
				"R² \(estimate.rSquared)")
		#expect(estimate.isElastic, "|ε| > 1 here, so demand is elastic")
	}

	@Test("Elasticity is scale invariant in both axes")
	func elasticityIsScaleInvariant() throws {
		// A log-log slope is unchanged by the units either variable is measured in —
		// changing currency or pack size shifts the intercept, not the elasticity. That
		// is the property the measure is chosen for, and it catches a formula that
		// regressed levels rather than logs.
		let prices: [Double] = [10, 12, 14, 16, 18, 20]
		let quantities: [Double] = [100, 82, 70, 60, 53, 47]
		let plain = try #require(PriceElasticity(prices: prices, quantities: quantities))
		let rescaled = try #require(PriceElasticity(prices: prices.map { $0 * 1.6 },
													quantities: quantities.map { $0 * 1000 }))
		#expect(Swift.abs(plain.elasticity - rescaled.elasticity) < 1e-9,
				"\(plain.elasticity) against \(rescaled.elasticity)")
	}

	@Test("Elasticity refuses data that cannot be logged or fitted")
	func elasticityRefusals() {
		#expect(PriceElasticity(prices: [10, 0], quantities: [5, 6]) == nil)
		#expect(PriceElasticity(prices: [10, 12], quantities: [5, -6]) == nil)
		#expect(PriceElasticity(prices: [10], quantities: [5]) == nil)
		// A single price carries no information about how demand responds to price.
		#expect(PriceElasticity(prices: [10, 10, 10], quantities: [5, 6, 7]) == nil)
	}

	// MARK: - Optimal price

	@Test("Optimal price is the constant-elasticity markup")
	func optimalPriceIsTheLernerMarkup() throws {
		// P* = cε/(ε+1). At ε = −2 that is twice marginal cost, at ε = −5 a quarter over.
		let cases: [(cost: Double, elasticity: Double, price: Double)] = [
			(10, -2.0, 20.0), (10, -3.0, 15.0), (25, -1.5, 75.0), (10, -5.0, 12.5),
		]
		var checked = 0
		for row in cases {
			let optimal = try #require(optimalPrice(marginalCost: row.cost,
													elasticity: row.elasticity))
			#expect(Swift.abs(optimal - row.price) < 1e-9,
					"cost \(row.cost) at ε=\(row.elasticity) gave \(optimal)")
			#expect(optimal > row.cost, "an optimal price must exceed marginal cost")
			checked += 1
		}
		#expect(checked == 4)
	}

	@Test("More elastic demand means a thinner margin")
	func elasticityDrivesMarkup() throws {
		// The economics the formula encodes: the more sensitive demand is to price, the
		// less of a markup survives. A test that only checked one point would not see it.
		var previous = Double.infinity
		for elasticity in [-1.5, -2.0, -3.0, -5.0, -10.0] {
			let price = try #require(optimalPrice(marginalCost: 10, elasticity: elasticity))
			#expect(price < previous, "ε=\(elasticity) gave \(price), not below \(previous)")
			previous = price
		}
		#expect(previous > 10, "even very elastic demand prices above cost, got \(previous)")
	}

	@Test("Inelastic demand has no optimal price, and is refused rather than negated")
	func inelasticDemandIsRefused() {
		// For −1 < ε < 0 profit rises without bound as price rises: there is no interior
		// maximum, and cε/(ε+1) returns a negative price. At ε = −1 it divides by zero.
		#expect(optimalPrice(marginalCost: 10, elasticity: -0.5) == nil)
		#expect(optimalPrice(marginalCost: 10, elasticity: -0.9) == nil)
		#expect(optimalPrice(marginalCost: 10, elasticity: -1.0) == nil)
		// Positive elasticity is not a demand curve.
		#expect(optimalPrice(marginalCost: 10, elasticity: 0.5) == nil)
		#expect(optimalPrice(marginalCost: 0, elasticity: -2.0) == nil)
	}

	// MARK: - Campaign depth

	@Test("Campaign depth stops where the marginal bucket stops paying")
	func campaignDepth() throws {
		// 1000 prospects in five buckets of 200; 80, 50, 30, 25 and 15 responders.
		// At £50 margin and £10 a contact the profits by depth are 2000, 2500, 2000,
		// 1250, 0 — an interior optimum at the second bucket, so a method that always
		// returns the last one cannot pass.
		let scores: [Double] = (0..<1000).map { Double(1000 - $0) }
		var outcomes = [Bool](repeating: false, count: 1000)
		let responders = [80, 50, 30, 25, 15]
		var index = 0
		for (bucket, count) in responders.enumerated() {
			for offset in 0..<count { outcomes[bucket * 200 + offset] = true }
			index += count
		}
		#expect(index == 200, "the fixture should hold 200 responders, built \(index)")

		let evaluation = try #require(ClassifierEvaluation(scores: scores, outcomes: outcomes))
		let table = evaluation.gains(buckets: 5)
		let depth = try #require(optimalCampaignDepth(gains: table, contactCost: 10,
													  marginPerResponse: 50,
													  population: 1000))
		#expect(depth.bucket == 2, "optimal depth \(depth.bucket), expected 2")
		#expect(Swift.abs(depth.profit - 2500) < 1e-9, "profit \(depth.profit)")
		#expect(Swift.abs(depth.contacted - 400) < 1e-9, "contacted \(depth.contacted)")
	}

	@Test("A campaign that cannot pay for itself is reported as contacting nobody")
	func unprofitableCampaign() throws {
		let scores: [Double] = (0..<100).map { Double(100 - $0) }
		var outcomes = [Bool](repeating: false, count: 100)
		for index in 0..<5 { outcomes[index] = true }
		let evaluation = try #require(ClassifierEvaluation(scores: scores, outcomes: outcomes))
		let table = evaluation.gains(buckets: 5)
		// Twenty contacts to reach five responders worth £1 each, at £10 a contact.
		let depth = try #require(optimalCampaignDepth(gains: table, contactCost: 10,
													  marginPerResponse: 1, population: 100))
		#expect(depth.bucket == 0, "expected no contact, got depth \(depth.bucket)")
		#expect(depth.profit == 0, "not running the campaign earns zero, got \(depth.profit)")
	}

	// MARK: - RFM

	@Test("Recency scores lower as days since purchase grow")
	func recencyIsInverted() throws {
		// The failure this exists for: recency is days *since*, so lower is better.
		// Scored like frequency, the segmentation ranks a customer who has not bought in
		// a year above one who bought yesterday — and every downstream number remains
		// perfectly well-formed.
		let customers: [RFMInput<Double>] = (1...5).map {
			RFMInput(identifier: "c\($0)", recencyDays: Double($0) * 30,
					 frequency: 5, monetary: 100)
		}
		let scored = try #require(RFMSegmentation(customers: customers, tiers: 5))
		let best = try #require(scored.scores["c1"])
		let worst = try #require(scored.scores["c5"])
		#expect(best.recency > worst.recency,
				"30 days should outscore 150: \(best.recency) against \(worst.recency)")
		#expect(best.recency == 5, "the most recent customer should be in the top tier")
		#expect(worst.recency == 1, "the least recent should be in the bottom tier")
	}

	@Test("Frequency and monetary score upward, and tiers partition the cohort")
	func tiersPartition() throws {
		let customers: [RFMInput<Double>] = (1...10).map {
			RFMInput(identifier: "c\($0)", recencyDays: 10,
					 frequency: Double($0), monetary: Double($0) * 50)
		}
		let scored = try #require(RFMSegmentation(customers: customers, tiers: 5))
		let low = try #require(scored.scores["c1"])
		let high = try #require(scored.scores["c10"])
		#expect(high.frequency > low.frequency, "more purchases should score higher")
		#expect(high.monetary > low.monetary, "more spend should score higher")
		#expect(high.frequency == 5 && high.monetary == 5)
		#expect(low.frequency == 1 && low.monetary == 1)
		// Every customer scored, every score inside the tier range.
		#expect(scored.scores.count == 10)
		for (name, score) in scored.scores {
			for value in [score.recency, score.frequency, score.monetary] {
				#expect(value >= 1 && value <= 5, "\(name) scored \(value)")
			}
			#expect(score.combined == score.recency + score.frequency + score.monetary)
		}
	}

	@Test("RFM refuses input it cannot rank")
	func rfmRefusals() {
		let one = [RFMInput<Double>(identifier: "a", recencyDays: 1, frequency: 1, monetary: 1)]
		let none: [RFMInput<Double>] = []
		#expect(RFMSegmentation(customers: none, tiers: 5) == nil)
		#expect(RFMSegmentation(customers: one, tiers: 0) == nil)
		// Negative days since a purchase is a purchase in the future.
		let backwards = [RFMInput<Double>(identifier: "a", recencyDays: -5,
										  frequency: 1, monetary: 1)]
		#expect(RFMSegmentation(customers: backwards, tiers: 5) == nil)
		// Duplicate identifiers would silently overwrite one another in the result.
		let duplicated = [
			RFMInput<Double>(identifier: "a", recencyDays: 1, frequency: 1, monetary: 1),
			RFMInput<Double>(identifier: "a", recencyDays: 2, frequency: 2, monetary: 2),
		]
		#expect(RFMSegmentation(customers: duplicated, tiers: 5) == nil)
	}
}

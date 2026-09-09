//
//  TemplateDelegationTests.swift
//  BusinessMath
//
//  The model templates delegating their unit economics to `Marketing/Value/`, and the
//  five fail-silent answers that delegation removes.
//
//  Every one of them is a `return 0` standing in for something that is not zero:
//
//  1. **Zero churn returns a lifetime value of zero.** Nobody ever leaving is the case
//     where the perpetuity *diverges*. Zero is the opposite of the truth, and it is the
//     answer both templates give.
//  2. **A missing acquisition cost returns a payback of zero months.** Zero is the best
//     score on that scale. A screen for the fastest-paying model ranks the ones with no
//     cost data at the very top.
//  3. **A zero acquisition cost returns an LTV:CAC of infinity.** `SaaSModel` guards that
//     the cost is *present* and never that it is positive, so it divides by it. A healthy
//     ratio is "above three", and infinity clears every check ever written against it.
//  4. **SaaS payback divides by revenue where the box model divides by margin.** Two
//     templates in the same library computing the same named quantity two ways. Acquisition
//     cost is recovered out of gross profit, so the box model is right and the SaaS one
//     understates payback by exactly the gross margin — at 80% margin, five months where
//     the answer is 6.25.
//  5. **A box sold at a loss returns a payback of zero months.** It never pays back at
//     all. Zero months says it pays back instantly.
//
//  The delegation preserves every number the templates returned for well-posed input —
//  which is only possible because `margin / churn` turned out to be an **annuity-due**
//  perpetuity rather than the ordinary one, and `CLVDefinition.perpetuityDue` now names
//  it. Had the enum not been extended, migrating would have silently renumbered every
//  LTV in the library by one period's margin.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Template unit economics")
struct TemplateDelegationTests {

	static func saas(churn: Double = 0.05,
					 arpu: Double = 100,
					 margin: Double? = nil,
					 cac: Double? = 500) -> SaaSModel {
		SaaSModel(initialMRR: 10_000, churnRate: churn, newCustomersPerMonth: 100,
				  averageRevenuePerUser: arpu, grossMargin: margin,
				  customerAcquisitionCost: cac)
	}

	static func box(price: Double = 40, cogs: Double = 15, shipping: Double = 5,
					churn: Double = 0.08, cac: Double = 60) -> SubscriptionBoxModel {
		SubscriptionBoxModel(initialSubscribers: 1_000, monthlyBoxPrice: price,
							 costOfGoodsPerBox: cogs, shippingCostPerBox: shipping,
							 monthlyChurnRate: churn, newSubscribersPerMonth: 100,
							 customerAcquisitionCost: cac)
	}

	// MARK: - What the templates now compute

	@Test("SaaS lifetime value is the annuity-due perpetuity on contribution margin")
	func saasLifetimeValue() throws {
		let plain = try Self.saas().lifetimeValue()
		#expect(Swift.abs(plain.value - 2_000) < 1e-9, "ARPU 100 at 5% churn: \(plain.value)")
		#expect(plain.definition == .perpetuityDue)

		let margined = try Self.saas(margin: 0.80).lifetimeValue()
		#expect(Swift.abs(margined.value - 1_600) < 1e-9, "80% margin: \(margined.value)")
		#expect(Swift.abs(margined.averageMargin - 80) < 1e-12, "margin \(margined.averageMargin)")
		let retention = try #require(margined.estimatedRetention)
		#expect(Swift.abs(retention - 0.95) < 1e-12, "retention \(retention)")
	}

	@Test("The ordinary perpetuity is available, and is one margin lower")
	func otherDefinitionsAreReachable() throws {
		let model = Self.saas(margin: 0.80)
		let due = try model.lifetimeValue(definition: .perpetuityDue)
		let ordinary = try model.lifetimeValue(definition: .perpetuity)
		let gap: Double = due.value - ordinary.value
		#expect(Swift.abs(gap - 80) < 1e-9, "one period of margin: \(gap)")

		// And a horizon, for anyone who does not believe the churn rate holds forever.
		let finite = try model.lifetimeValue(definition: .finiteHorizon, horizon: 12)
		#expect(finite.value < ordinary.value, "\(finite.value) against \(ordinary.value)")
	}

	@Test("Box lifetime value is gross margin per box over churn")
	func boxLifetimeValue() throws {
		let value = try Self.box().lifetimeValue()
		// (40 − 15 − 5) / 0.08 = 250
		#expect(Swift.abs(value.value - 250) < 1e-9, "\(value.value)")
		#expect(Swift.abs(value.averageMargin - 20) < 1e-12, "\(value.averageMargin)")
	}

	@Test("Acquisition metrics carry the ratio and a payback on margin")
	func acquisitionMetrics() throws {
		let metrics = try #require(try Self.saas().acquisitionMetrics())
		#expect(Swift.abs(metrics.ratio - 4) < 1e-9, "2000/500 = \(metrics.ratio)")
		#expect(Swift.abs(metrics.paybackPeriods - 5) < 1e-9, "500/100 = \(metrics.paybackPeriods)")
		#expect(metrics.isProfitable)
		#expect(Swift.abs(metrics.netValue - 1_500) < 1e-9, "\(metrics.netValue)")

		let boxed = try #require(try Self.box().acquisitionMetrics())
		#expect(Swift.abs(boxed.paybackPeriods - 3) < 1e-9, "60/20 = \(boxed.paybackPeriods)")
	}

	@Test("Retention rate refuses a churn rate that is not a rate")
	func retentionRate() throws {
		let healthy = try #require(Self.box().retentionRate)
		#expect(Swift.abs(healthy - 0.92) < 1e-12, "\(healthy)")
		#expect(Self.box(churn: 1.2).retentionRate == nil, "churn above one is not a rate")
		#expect(Self.box(churn: -0.1).retentionRate == nil)
		let saasRetention = try #require(Self.saas().retentionRate)
		#expect(Swift.abs(saasRetention - 0.95) < 1e-12, "\(saasRetention)")
	}

	// MARK: - The five refusals

	@Test("Zero churn is a divergent perpetuity, not a lifetime value of zero")
	func zeroChurnDiverges() {
		#expect(throws: CLVError.self) { _ = try Self.saas(churn: 0).lifetimeValue() }
		#expect(throws: CLVError.self) { _ = try Self.box(churn: 0).lifetimeValue() }
		// A discount rate rescues it: money later is worth less even if nobody leaves.
		#expect(throws: Never.self) {
			_ = try Self.saas(churn: 0).lifetimeValue(discountRate: 0.01)
		}
	}

	@Test("No acquisition cost means no acquisition metrics, not a payback of zero")
	func missingCostGivesNoMetrics() throws {
		#expect(try Self.saas(cac: nil).acquisitionMetrics() == nil)
	}

	@Test("A zero acquisition cost is refused rather than divided by")
	func zeroCostIsRefused() throws {
		#expect(try Self.saas(cac: 0).acquisitionMetrics() == nil)
		#expect(try Self.box(cac: 0).acquisitionMetrics() == nil)
	}

	@Test("A box sold at a loss has no payback period at all")
	func lossMakingBoxHasNoPayback() throws {
		// 20 − 15 − 8 = −3 per box.
		let losing = Self.box(price: 20, cogs: 15, shipping: 8)
		let value = try losing.lifetimeValue()
		#expect(value.value < 0, "a loss-making box has negative lifetime value: \(value.value)")
		#expect(Swift.abs(value.value - (-37.5)) < 1e-9, "\(value.value)")
		#expect(try losing.acquisitionMetrics() == nil, "there is no payback to report")
	}

	@Test("A churn rate outside zero and one is refused by both templates")
	func impossibleChurnIsRefused() {
		#expect(throws: CLVError.invalidRetention) {
			_ = try Self.saas(churn: 1.4).lifetimeValue()
		}
		#expect(throws: CLVError.invalidRetention) {
			_ = try Self.box(churn: -0.2).lifetimeValue()
		}
	}
}

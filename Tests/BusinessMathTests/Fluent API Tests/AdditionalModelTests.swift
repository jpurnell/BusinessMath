//
//  Test.swift
//  BusinessMath
//
//  Created by Justin Purnell on 11/19/25.
//

import Testing
@testable import BusinessMath

// MARK: - Shared helpers

@Suite fileprivate struct ApproxHelpers {
	static func approxEqual(_ a: Double, _ b: Double, accuracy: Double = 0.01) -> Bool {
		abs(a - b) <= accuracy
	}
}

// MARK: - Manufacturing additional tests

@Suite("ManufacturingModel - Additional")
struct ManufacturingModelAdditionalTests {

	@Test
	func unitCostMonotonicWithUtilization() {
		let model = ManufacturingModel(
			productionCapacity: 10_000,
			sellingPricePerUnit: 50,
			directMaterialCostPerUnit: 15,
			directLaborCostPerUnit: 10,
			monthlyOverhead: 150_000
		)
		let u100 = model.calculateUnitCost(atCapacityUtilization: 1.0)   // 40
		let u75  = model.calculateUnitCost(atCapacityUtilization: 0.75)  // 45
		let u50  = model.calculateUnitCost(atCapacityUtilization: 0.50)  // 55

		#expect(u100 < u75 && u75 < u50, "Unit cost should rise as utilization falls")
	}

	@Test
	func overheadPerUnitDecreasesWithMoreProduction() {
		let model = ManufacturingModel(
			productionCapacity: 10_000,
			sellingPricePerUnit: 50,
			directMaterialCostPerUnit: 15,
			directLaborCostPerUnit: 10,
			monthlyOverhead: 150_000
		)
		let o5k = model.calculateOverheadPerUnit(atProduction: 5_000)   // 30
		let o8k = model.calculateOverheadPerUnit(atProduction: 8_000)   // 18.75
		let o10k = model.calculateOverheadPerUnit(atProduction: 10_000) // 15.0

		#expect(o5k > o8k && o8k > o10k, "Overhead per unit should fall as production rises")
	}

	@Test
	func profitIncreasesWithMoreUnitsProduced() {
		let model = ManufacturingModel(
			productionCapacity: 10_000,
			sellingPricePerUnit: 50,
			directMaterialCostPerUnit: 15,
			directLaborCostPerUnit: 10,
			monthlyOverhead: 150_000
		)
		let p6k = model.calculateProfit(unitsProduced: 6_000) // near break-even
		let p8k = model.calculateProfit(unitsProduced: 8_000)

		#expect(p8k > p6k)
	}

	@Test
	func breakEvenWithinCapacity() {
		let model = ManufacturingModel(
			productionCapacity: 10_000,
			sellingPricePerUnit: 50,
			directMaterialCostPerUnit: 15,
			directLaborCostPerUnit: 10,
			monthlyOverhead: 150_000
		)
		let beUnits = model.calculateBreakEvenUnits()
		#expect(beUnits <= model.productionCapacity, "Break-even should be feasible given capacity with these inputs")
	}
}

// MARK: - Marketplace additional tests

@Suite("MarketplaceModel - Additional")
struct MarketplaceModelAdditionalTests {

	@Test
	func monthToMonthRecurrenceHolds() {
		let m = MarketplaceModel(
			initialBuyers: 10_000,
			initialSellers: 500,
			monthlyTransactionsPerBuyer: 2,
			averageOrderValue: 75,
			takeRate: 0.15,
			newBuyersPerMonth: 1_000,
			newSellersPerMonth: 50,
			buyerChurnRate: 0.05,
			sellerChurnRate: 0.03
		)

		let buyers1 = m.calculateBuyers(forMonth: 1) // 10,500
		let buyers2 = m.calculateBuyers(forMonth: 2)
		// Expected buyers2 = buyers1 - (buyers1 * churn) + new
		let expected2 = buyers1 - buyers1 * 0.05 + 1_000
		#expect(ApproxHelpers.approxEqual(buyers2, expected2, accuracy: 0.5))
	}

	@Test
	func internalIdentitiesConsistentInMonth1() {
		let m = MarketplaceModel(
			initialBuyers: 10_000,
			initialSellers: 500,
			monthlyTransactionsPerBuyer: 2,
			averageOrderValue: 75,
			takeRate: 0.15,
			newBuyersPerMonth: 1_000,
			newSellersPerMonth: 50,
			buyerChurnRate: 0.05,
			sellerChurnRate: 0.03
		)

		let buyers = m.calculateBuyers(forMonth: 1)                // 10,500
		let sellers = m.calculateSellers(forMonth: 1)              // 535
		let totalTx = m.calculateTotalTransactions(forMonth: 1)    // 21,000
		let gmv = m.calculateGMV(forMonth: 1)                      // 1,575,000
		let revenue = m.calculateRevenue(forMonth: 1)              // 236,250

		#expect(totalTx == buyers * m.monthlyTransactionsPerBuyer)
		#expect(ApproxHelpers.approxEqual(gmv, Double(totalTx) * m.averageOrderValue, accuracy: 1.0))
		#expect(ApproxHelpers.approxEqual(revenue, gmv * m.takeRate, accuracy: 1.0))
		// Guard denominator in transactions per seller identity when sellers > 0
		if sellers > 0 {
			let txPerSeller = m.calculateTransactionsPerSeller(forMonth: 1)
			#expect(ApproxHelpers.approxEqual(Double(totalTx) / sellers, txPerSeller, accuracy: 0.5))
		}
	}
}

// MARK: - Retail additional tests

@Suite("RetailModel - Additional")
struct RetailModelAdditionalTests {

	@Test
	func dioTurnoverIdentity() {
		let r = RetailModel(
			initialInventoryValue: 100_000,
			monthlyRevenue: 50_000,
			costOfGoodsSoldPercentage: 0.60,
			operatingExpenses: 15_000
		)
		let turnover = r.calculateInventoryTurnover()              // 3.6
		let dio = r.calculateDaysInventoryOutstanding()            // ~101.4
		let product = turnover * dio
		#expect(ApproxHelpers.approxEqual(product, 365.0, accuracy: 2.0))
	}

	@Test
	func seasonalMultiplierFallbackIs1() {
		let r = RetailModel(
			initialInventoryValue: 100_000,
			monthlyRevenue: 50_000,
			costOfGoodsSoldPercentage: 0.60,
			operatingExpenses: 15_000,
			seasonalMultipliers: [12: 2.0]
		)
		// Month 7 not specified, should use multiplier 1.0
		let julyRevenue = r.calculateRevenue(forMonth: 7)
		#expect(ApproxHelpers.approxEqual(julyRevenue, 50_000, accuracy: 0.5))
	}
}

// MARK: - SaaS additional tests

@Suite("SaaSModel - Additional")
struct SaaSModelAdditionalTests {

	@Test
	func priceIncreaseAdjustsARPUAtBoundary() {
		let s = SaaSModel(
			initialMRR: 10_000,
			churnRate: 0.05,
			newCustomersPerMonth: 100,
			averageRevenuePerUser: 100,
			priceIncreases: [
				(month: 12, percentage: 0.05) // ARPU becomes 105 from month 12 onward
			]
		)

		// Compute customers for month 12 (we only need relative ARPU change)
		let mrr11 = s.calculateMRR(forMonth: 11)
		let mrr12 = s.calculateMRR(forMonth: 12)
		#expect(mrr12 > mrr11, "MRR should increase at price change boundary, holding other drivers constant")
	}

	@Test
	func cacPaybackUsesArpu() throws {
		let s = SaaSModel(
			initialMRR: 10_000,
			churnRate: 0.05,
			newCustomersPerMonth: 100,
			averageRevenuePerUser: 100,
			customerAcquisitionCost: 500
		)
		// With no gross margin specified the contribution margin is ARPU itself, so this
		// is the same 5.0 the revenue-based calculation returned.
		let payback = try #require(try s.acquisitionMetrics()).paybackPeriods
		#expect(ApproxHelpers.approxEqual(payback, 5.0, accuracy: 0.1))
	}
}

// MARK: - Subscription Box additional tests

@Suite("SubscriptionBoxModel - Additional")
struct SubscriptionBoxModelAdditionalTests {

	@Test
	func revenueIdentityHoldsInMonth1() {
		let sb = SubscriptionBoxModel(
			initialSubscribers: 1_000,
			monthlyBoxPrice: 49.99,
			costOfGoodsPerBox: 20,
			shippingCostPerBox: 5,
			monthlyChurnRate: 0.08,
			newSubscribersPerMonth: 150,
			customerAcquisitionCost: 40
		)
		let subs1 = sb.calculateSubscribers(forMonth: 1)  // 1,070
		let rev1 = sb.calculateRevenue(forMonth: 1)       // ~53,489
		#expect(ApproxHelpers.approxEqual(rev1, Double(subs1) * sb.monthlyBoxPrice, accuracy: 10.0))
	}

	@Test
	func ltvIgnoresCACAndUsesGrossMarginPerBox() throws {
		let sb = SubscriptionBoxModel(
			initialSubscribers: 1_000,
			monthlyBoxPrice: 49.99,
			costOfGoodsPerBox: 20,
			shippingCostPerBox: 5,
			monthlyChurnRate: 0.08,
			newSubscribersPerMonth: 150,
			customerAcquisitionCost: 200 // Large CAC should not affect LTV
		)
		let gmPerBox = sb.calculateGrossMarginPerBox() // 24.99
		let ltv = try sb.lifetimeValue().value
		#expect(ApproxHelpers.approxEqual(ltv, gmPerBox / sb.monthlyChurnRate, accuracy: 1.0))
	}
}

@Suite("Out-of-range model inputs")
struct OutOfRangeInputTests {

	/// A churn rate above 1 drives the customer count negative, and nothing stops it.
	///
	/// Two disabled stubs stood here, both asserting that the initializers throw a
	/// test-local `ValidationError` on nonsense input. They could never have passed:
	/// `SaaSModel.init` and `ManufacturingModel.init` are not `throws`, and the library
	/// has no error to throw — so the closures were non-throwing and the expectation was
	/// unsatisfiable by construction. Adding validation is a source-breaking change to two
	/// public initializers, and `churnRate` is a `var` besides, so a throwing `init` alone
	/// would not close the hole. That decision belongs to 3.0.0.
	///
	/// What can be done now is state the requirement as an executable one. Churn above
	/// 100% means the model loses more customers than it has: month 1 of a 100-customer
	/// base at 1.2 churn with no acquisition is −20 customers. A negative headcount is the
	/// plausible-but-wrong result this package's rules name directly, so the assertion is
	/// written the way it should read, and marked as the known failure it currently is.
	/// When validation lands, this stops being a known issue and starts being a test.
	@Test("A churn rate above 100% produces a negative customer count")
	func churnAboveOneGoesNegative() {
		let model = SaaSModel(
			initialMRR: 10_000,
			churnRate: 1.2,
			newCustomersPerMonth: 0,
			averageRevenuePerUser: 100
		)

		// 10,000 / 100 = 100 customers to start.
		let monthOne: Double = model.calculateCustomerCount(forMonth: 1)

		withKnownIssue("churnRate is unvalidated; rejecting it is a 3.0.0 API change") {
			#expect(monthOne >= 0, "month 1 ended with \(monthOne) customers")
		}

		// And the value it does return, pinned, so the arithmetic above is not a guess:
		// 100 − (100 × 1.2) + 0 = −20, exactly representable.
		#expect(monthOne.isEqual(to: -20.0), "month 1 gave \(monthOne), not -20")
	}

	/// Zero production capacity, which the division guards do handle.
	///
	/// The second stub assumed this case was unguarded. It is not: every quotient with
	/// capacity or production underneath it returns 0 rather than dividing, so no
	/// infinity escapes. Worth an assertion because the guards are the only thing
	/// standing between this input and a non-finite unit cost.
	@Test("Zero capacity returns zero from every quotient rather than an infinity")
	func zeroCapacityDoesNotDivide() {
		let model = ManufacturingModel(
			productionCapacity: 0,
			sellingPricePerUnit: 50,
			directMaterialCostPerUnit: 15,
			directLaborCostPerUnit: 10,
			monthlyOverhead: 150_000
		)

		let unitCost: Double = model.calculateUnitCost(atCapacityUtilization: 1.0)
		let overheadPerUnit: Double = model.calculateOverheadPerUnit(atProduction: 0)

		#expect(unitCost.isFinite, "unit cost at zero capacity was \(unitCost)")
		#expect(overheadPerUnit.isFinite, "overhead per unit at zero production was \(overheadPerUnit)")
		#expect(unitCost.isEqual(to: 0.0), "unit cost at zero capacity was \(unitCost)")
		#expect(overheadPerUnit.isEqual(to: 0.0), "overhead per unit was \(overheadPerUnit)")
	}
}

//
//  DegenerateDivisorGuardTests.swift
//  BusinessMath
//
//  Four divisors that had a guard on one call site and none on its twin.
//
//  Each of these was found by grepping for bare `fp-safety:disable` annotations and then
//  looking for the *same* divisor elsewhere in the same type. In every case the author had
//  already recognised the hazard once and not carried it across — which is the shape the
//  ICC(1,1) defect had, and the shape the ratio-validation sweep had.
//
//  The last one carried no annotation at all: the checker only flags divisors that are plain
//  identifiers, so `x / (1.0 - y)` is invisible to it. The suppression census is a lower bound.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("DegenerateDivisorGuardTests") struct DegenerateDivisorGuardTests {

	// MARK: - RetailModel: an overload that did not guard what its sibling guarded

	/// `calculateRevenuePerSquareFoot(squareFootage:)` guards and returns 0; the
	/// `forStore:` overload divided by the same argument unguarded and returned infinity.
	@Test("RetailModel_ZeroSquareFootage_BothOverloadsAgree") func retailZeroSquareFootage() {
		let model = RetailModel(
			initialInventoryValue: 100_000,
			monthlyRevenue: 250_000,
			costOfGoodsSoldPercentage: 0.6,
			operatingExpenses: 50_000
		)
		let aggregate = model.calculateRevenuePerSquareFoot(squareFootage: 0)
		let perStore = model.calculateRevenuePerSquareFoot(squareFootage: 0, forStore: 0)
		#expect(aggregate == 0, "the guarded overload returns nothing")
		#expect(perStore == 0, "and so does its twin")
		#expect(perStore.isFinite, "a store with no floor area is not infinitely productive")
	}

	/// The multi-store path divides `averageStoreRevenue`, a different numerator, by the same
	/// zero — so the guard has to sit above the branch, not inside one arm of it.
	@Test("RetailModel_ZeroSquareFootage_MultiStorePath") func retailZeroSquareFootageMultiStore() {
		let model = RetailModel(
			numberOfStores: 12,
			averageStoreRevenue: 180_000,
			sameStoreSalesGrowth: 0.04,
			footTraffic: 9_000,
			conversionRate: 0.22,
			averageTransaction: 41.0,
			costOfGoodsSold: 0.58,
			operatingExpensesPerStore: 60_000
		)
		let perStore = model.calculateRevenuePerSquareFoot(squareFootage: 0, forStore: 3)
		#expect(perStore == 0, "the multi-store branch is guarded too")
	}

	/// And the guard must not disturb an ordinary answer.
	@Test("RetailModel_PositiveSquareFootage_Unchanged") func retailPositiveSquareFootage() {
		let model = RetailModel(
			initialInventoryValue: 100_000,
			monthlyRevenue: 250_000,
			costOfGoodsSoldPercentage: 0.6,
			operatingExpenses: 50_000
		)
		let perStore = model.calculateRevenuePerSquareFoot(squareFootage: 5_000, forStore: 0)
		#expect(perStore.isEqual(to: 50.0), "250,000 over 5,000 square feet")
	}

	// MARK: - ManufacturingModel: a third site for a divisor guarded at two others

	/// `calculateOverheadPerUnit` and `calculateCapacityUtilization` both guard
	/// `productionCapacity`; `project` did not.
	///
	/// **This one was not a defect, and this test does not pretend to catch one.** It was run
	/// against the unguarded code and passed: `1000 / 0` is `+infinity`, `0 * infinity` is NaN,
	/// and `guard unitsProduced > 0` is false for NaN, so the unit cost came out 0 — the same
	/// answer the guard produces by a shorter route. The change makes the divisor visible; it
	/// moves no number. What the test is for is pinning that, so a later edit to
	/// `calculateUnitCost(atCapacityUtilization:)` cannot quietly start propagating the NaN.
	@Test("ManufacturingModel_ZeroCapacity_ProjectsWithoutNaN") func manufacturingZeroCapacity() {
		let model = ManufacturingModel(
			productionCapacity: 0,
			sellingPricePerUnit: 45.0,
			directMaterialCostPerUnit: 12.0,
			directLaborCostPerUnit: 8.0,
			monthlyOverhead: 90_000
		)
		let projection = model.project(months: 3, unitsPerMonth: 1_000)
		for value in projection.unitCost.valuesArray {
			#expect(value == 0, "no capacity, no unit cost — and not NaN")
		}
		for value in projection.revenue.valuesArray {
			#expect(value.isEqual(to: 45_000.0), "revenue still follows the units actually made")
		}
	}

	/// The ordinary case must be untouched — and it is the same number the two guarded
	/// siblings would produce.
	@Test("ManufacturingModel_PositiveCapacity_Unchanged") func manufacturingPositiveCapacity() throws {
		let model = ManufacturingModel(
			productionCapacity: 10_000,
			sellingPricePerUnit: 45.0,
			directMaterialCostPerUnit: 12.0,
			directLaborCostPerUnit: 8.0,
			monthlyOverhead: 90_000
		)
		let projection = model.project(months: 2, unitsPerMonth: 5_000)
		// Overhead of 90,000 over 5,000 units is 18 per unit, on top of 20 variable.
		let expected = 38.0
		let first = try #require(projection.unitCost.valuesArray.first)
		#expect(first.isEqual(to: expected), "utilisation of 0.5 puts overhead at 18 per unit")
	}

	// MARK: - SAFE: the branch whose twin guarded

	/// `SAFE.init` does not validate the cap, and `convert`'s `.preMoney` branch guards its
	/// conversion price while `.postMoney` did not.
	///
	/// `SAFEType` is not `Sendable`, so the two branches are spelled out rather than passed as
	/// `arguments:` — the parameterised form requires it.
	@Test("SAFE_ZeroCap_PostMoney_MatchesPreMoney") func safeZeroCap() {
		let postMoney = SAFE(investment: 500_000, postMoneyCap: 0, type: .postMoney)
			.convert(seriesAValuation: 15_000_000)
		#expect(postMoney.shares == 0, "a cap of zero converts to no shares")
		#expect(postMoney.shares.isFinite, "and certainly not to infinitely many")
		#expect(postMoney.pricePerShare.isFinite, "nor at an infinite price")

		let preMoney = SAFE(investment: 500_000, postMoneyCap: 0, type: .preMoney)
			.convert(seriesAValuation: 15_000_000)
		#expect(preMoney.shares == 0, "the branch that already guarded agrees")
	}

	@Test("SAFE_OrdinaryCap_Unchanged") func safeOrdinaryCap() {
		let safe = SAFE(investment: 500_000, postMoneyCap: 8_000_000, type: .postMoney)
		let conversion = safe.convert(seriesAValuation: 15_000_000)
		// 8M cap over 10M assumed shares is $0.80; 500,000 buys 625,000 of them.
		#expect(conversion.pricePerShare.isEqual(to: 0.8), "the cap over the assumed share count")
		#expect(conversion.shares.isEqual(to: 625_000.0), "the investment at that price")
	}

	// MARK: - CapTable: a divisor the checker never flagged

	/// `investorOwnership / (1.0 - investorOwnership)` carried no suppression, because the
	/// checker only flags divisors that are plain identifiers.
	///
	/// A pre-money valuation of zero makes that ownership exactly 1 and the divisor exactly 0.
	@Test("CapTable_ZeroPreMoney_DoesNotIssueInfiniteShares") func capTableZeroPreMoney() {
		let founders = CapTable(
			shareholders: [
				CapTable.Shareholder(name: "Founder", shares: 8_000_000, investmentDate: Date(), pricePerShare: 0.001)
			],
			optionPool: 2_000_000
		)
		let rounded = founders.modelRound(
			newInvestment: 2_000_000,
			preMoneyValuation: 0,
			optionPoolIncrease: 0
		)
		#expect(rounded.totalShares.isFinite, "a zero pre-money must not issue infinite shares")
		#expect(rounded.totalShares.isEqual(to: founders.totalShares), "the round is declined, as the other guards decline")
	}

	/// A *negative* pre-money put ownership above 1, making the divisor negative and the share
	/// count negative with it — a shareholder owning minus four million shares.
	@Test("CapTable_NegativePreMoney_DoesNotIssueNegativeShares") func capTableNegativePreMoney() {
		let founders = CapTable(
			shareholders: [
				CapTable.Shareholder(name: "Founder", shares: 8_000_000, investmentDate: Date(), pricePerShare: 0.001)
			],
			optionPool: 2_000_000
		)
		let rounded = founders.modelDownRound(
			newInvestment: 2_000_000,
			preMoneyValuation: -500_000,
			payToPlayParticipants: []
		)
		for shareholder in rounded.shareholders {
			#expect(shareholder.shares >= 0, "no shareholder holds a negative position")
		}
	}

	/// An ordinary round still computes the textbook answer.
	@Test("CapTable_OrdinaryRound_Unchanged") func capTableOrdinaryRound() throws {
		let founders = CapTable(
			shareholders: [
				CapTable.Shareholder(name: "Founder", shares: 8_000_000, investmentDate: Date(), pricePerShare: 0.001)
			],
			optionPool: 2_000_000
		)
		let rounded = founders.modelRound(
			newInvestment: 2_000_000,
			preMoneyValuation: 8_000_000,
			optionPoolIncrease: 0
		)
		// 2M on an 8M pre-money is 20% post-money, so the investor takes 2.5M shares against
		// the 10M outstanding.
		let investor = try #require(rounded.shareholders.first(where: { $0.name == "Series A Investor" }))
		#expect(investor.shares.isEqual(to: 2_500_000.0), "20% post-money against 10M existing shares")
	}
}

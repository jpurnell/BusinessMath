//
//  CommodityCoverageTests.swift
//  BusinessMathTests
//
//  A gap in the price deck used to be priced at $0/bbl.
//
//  `OilGasEPModel.project` read `commodityPrices[period] ?? 0.0`. A projected period the price
//  deck did not cover therefore valued that period's barrels at nothing — while `periodLOE` on
//  the next line still charged $15 of lease operating expense against those same barrels. The
//  fabricated answer is not a shut-in, which produces nothing and so incurs no LOE; it is a
//  *producing* well booking zero revenue at full cash cost.
//
//  On the fixture below — one well at 100 BOEPD, so 3,100 BOE in January — the two runs differ
//  in nothing but whether January has a price:
//
//  | January price          | revenue  | LOE     | net income    |
//  |------------------------|----------|---------|---------------|
//  | $70 (the real deck)    | 217,000  | 46,500  | **+16,195**   |
//  | fabricated 0 (`?? 0`)  |        0 | 46,500  | **-196,500**  |
//
//  And `runningCash`, `runningPPE` and `runningRE` accumulate across the loop, so the hole is
//  carried into every later period's balance sheet rather than staying in the one quarter.
//
//  Contract §3.7 is "narrow the domain, do not fabricate the observation". `project` already
//  throws, so refusing with `BusinessMathError.missingData` costs no API change.
//
//  The hedge lookup on the following line is a *different* shape and is decided separately:
//
//  - **Outer** (`hedgingProgram == nil`) — this producer runs unhedged. Zero settlement is the
//    observation, not a substitute for one. `unhedgedProducerSettlesAtZero` pins that, so a
//    later sweep does not read it as a §3.7 fallback and "fix" a correct answer.
//  - **Inner** (a hedged producer with no settlement recorded for a covered period) — that
//    would be the defect shape, and it is unreachable: `totalSettlements` emits a row for every
//    period of the price series, a real `0` where no instrument settles rather than an omission.
//    `hedgedProducerWithNoInstrumentThisPeriodSettlesAtZero` exercises exactly that path, and
//    `hedgedProducerRefusalNamesThePriceNotTheHedge` shows which of the two guards fires when
//    the price is the thing missing.
//
//  Every refusal below is paired with a fully covered control that still computes its correct
//  revenue, so a `project` that simply threw on everything would fail this suite, not pass it.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Oil & gas price-deck coverage")
struct CommodityCoverageTests {

	/// Element-wise agreement that also treats `nan` as matching `nan`.
	///
	/// `isEqual(to:)` is IEEE equality, so `Double.nan.isEqual(to: .nan)` is `false`; the plain
	/// form silently fails any comparison involving a contaminated element.
	private func agree(_ lhs: [Double], _ rhs: [Double]) -> Bool {
		lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.isEqual(to: $1) || ($0.isNaN && $1.isNaN) }
	}

	// MARK: - Fixture

	private static let january = Period.month(year: 2026, month: 1)
	private static let february = Period.month(year: 2026, month: 2)
	private static let march = Period.month(year: 2026, month: 3)

	private static let projectedPeriods = [january, february, march]

	/// One well at a flat 100 BOEPD, so production is decided entirely by calendar days:
	/// January 3,100 BOE, February 2,800 BOE, March 3,100 BOE.
	///
	/// Identical parameters to `OilGasEPModelTests.makeModel`, so the control figures below are
	/// the same arithmetic that suite already pins.
	private func model() -> OilGasEPModel {
		let dailyRates = TimeSeries<Double>(
			periods: Self.projectedPeriods,
			values: [100.0, 100.0, 100.0]
		)
		let well = WellProductionProfile(name: "Well #1", dailyProduction: dailyRates)

		return OilGasEPModel(
			entity: Entity(id: "EP-COVERAGE", name: "Coverage E&P Corp"),
			wells: [well],
			commodityPriceName: "WTI",
			leaseOperatingExpensePerBOE: 15.0,
			generalAndAdminExpense: 50_000.0,
			depreciationRate: 0.01,
			initialPPE: 10_000_000.0,
			initialCash: 500_000.0,
			taxRate: 0.21,
			hedgingProgram: nil
		)
	}

	/// A price deck over exactly the periods named, all at $70/bbl.
	private func prices(_ periods: [Period]) -> TimeSeries<Double> {
		return TimeSeries<Double>(
			periods: periods,
			values: Array(repeating: 70.0, count: periods.count)
		)
	}

	// MARK: - The control

	@Test("Commodity_FullyCoveredDeckComputesRevenue")
	func fullyCoveredDeckComputesRevenue() throws {
		let integration = try model().project(
			periods: Self.projectedPeriods,
			commodityPrices: prices(Self.projectedPeriods)
		)
		let revenue = integration.incomeStatement.totalRevenue

		// 100 BOEPD x 31 days x $70
		let januaryRevenue = try #require(revenue[Self.january])
		#expect(abs(januaryRevenue - 217_000.0) < 0.01)

		// 100 BOEPD x 28 days x $70 (2026 is not a leap year)
		let februaryRevenue = try #require(revenue[Self.february])
		#expect(abs(februaryRevenue - 196_000.0) < 0.01)

		// 100 BOEPD x 31 days x $70
		let marchRevenue = try #require(revenue[Self.march])
		#expect(abs(marchRevenue - 217_000.0) < 0.01)

		// 217,000 - 46,500 LOE - 100,000 DD&A - 50,000 G&A = 20,500 pre-tax;
		// tax 20,500 x 0.21 = 4,305; net income 16,195.
		let januaryNetIncome = try #require(integration.incomeStatement.netIncome[Self.january])
		#expect(abs(januaryNetIncome - 16_195.0) < 0.01)
	}

	// MARK: - The fabricated observation, made constructible

	/// What the old `?? 0.0` claimed to be reading, filed as an explicit $0 price.
	///
	/// This does not exercise the fallback — it reproduces it, so the damage is measured by the
	/// library rather than argued from the source. The deck is fully covered, so the guard does
	/// not fire; only the January price differs from the control above.
	@Test("Commodity_FabricatedZeroPriceIsAProducingWellAtFullCost")
	func fabricatedZeroPriceIsAProducingWellAtFullCost() throws {
		let fabricatedDeck = TimeSeries<Double>(
			periods: Self.projectedPeriods,
			values: [0.0, 70.0, 70.0]
		)
		let integration = try model().project(
			periods: Self.projectedPeriods,
			commodityPrices: fabricatedDeck
		)

		let januaryRevenue = try #require(integration.incomeStatement.totalRevenue[Self.january])
		#expect(abs(januaryRevenue) < 0.01, "the barrels were valued at nothing")

		// The barrels were still produced, so the lease operating expense is unchanged:
		// 3,100 BOE x $15 = 46,500. A shut-in would have produced nothing and owed nothing.
		let costAccounts = integration.incomeStatement.costOfRevenueAccounts
		let firstCostAccount = try #require(costAccounts.first)
		let januaryLOE = try #require(firstCostAccount.timeSeries[Self.january])
		#expect(abs(januaryLOE - 46_500.0) < 0.01)

		// 0 - 46,500 - 100,000 - 50,000 = -196,500 pre-tax; no tax on a loss; net income
		// -196,500, against +16,195 for the same well with its real price.
		let expectedLoss: Double = -196_500.0
		let januaryNetIncome = try #require(integration.incomeStatement.netIncome[Self.january])
		#expect(abs(januaryNetIncome - expectedLoss) < 0.01)
	}

	// MARK: - The refusal

	@Test("Commodity_UncoveredLeadingPeriodIsRefused")
	func uncoveredLeadingPeriodIsRefused() throws {
		let partialDeck = prices([Self.february, Self.march])

		let thrown = #expect(throws: BusinessMathError.self) {
			_ = try model().project(
				periods: Self.projectedPeriods,
				commodityPrices: partialDeck
			)
		}

		let error = try #require(thrown)
		guard case .missingData(let account, let periodLabel) = error else {
			Issue.record("expected missingData, got \(error)")
			return
		}
		#expect(periodLabel == Self.january.label,
				"the diagnostic names the month the deck does not cover")
		#expect(account == "WTI price",
				"and names the series, using the model's own commodity name")
	}

	/// The position of the gap is varied deliberately: a deck that covers the first period runs
	/// two full iterations of the loop before it reaches the hole, so a guard placed wrongly
	/// could pass the leading case and still fabricate here.
	@Test("Commodity_UncoveredTrailingPeriodIsRefused")
	func uncoveredTrailingPeriodIsRefused() throws {
		let partialDeck = prices([Self.january, Self.february])

		let thrown = #expect(throws: BusinessMathError.self) {
			_ = try model().project(
				periods: Self.projectedPeriods,
				commodityPrices: partialDeck
			)
		}

		let error = try #require(thrown)
		guard case .missingData(_, let periodLabel) = error else {
			Issue.record("expected missingData, got \(error)")
			return
		}
		#expect(periodLabel == Self.march.label)
	}

	@Test("Commodity_InteriorGapIsRefused")
	func interiorGapIsRefused() throws {
		let partialDeck = prices([Self.january, Self.march])

		let thrown = #expect(throws: BusinessMathError.self) {
			_ = try model().project(
				periods: Self.projectedPeriods,
				commodityPrices: partialDeck
			)
		}

		let error = try #require(thrown)
		guard case .missingData(_, let periodLabel) = error else {
			Issue.record("expected missingData, got \(error)")
			return
		}
		#expect(periodLabel == Self.february.label)
	}

	// MARK: - The outer level: an unhedged producer really does settle at zero

	/// A non-defect, defended.
	///
	/// `hedgingProgram == nil` is a fact about the producer, not a missing observation, and the
	/// zero it contributes to revenue is the right answer. Revenue here is exactly production x
	/// price with nothing added, which is what makes the zero visible rather than assumed.
	@Test("Commodity_UnhedgedProducerSettlesAtZero")
	func unhedgedProducerSettlesAtZero() throws {
		let unhedged = OilGasEPModel(
			entity: Entity(id: "EP-UNHEDGED", name: "Unhedged E&P Corp"),
			wells: [WellProductionProfile(
				name: "Well #1",
				dailyProduction: TimeSeries<Double>(
					periods: Self.projectedPeriods,
					values: [100.0, 100.0, 100.0]
				)
			)],
			commodityPriceName: "WTI",
			leaseOperatingExpensePerBOE: 15.0,
			generalAndAdminExpense: 50_000.0,
			depreciationRate: 0.01,
			initialPPE: 10_000_000.0,
			initialCash: 500_000.0,
			taxRate: 0.21,
			hedgingProgram: nil
		)

		let integration = try unhedged.project(
			periods: Self.projectedPeriods,
			commodityPrices: prices(Self.projectedPeriods)
		)
		let revenue = integration.incomeStatement.totalRevenue

		// 3,100 BOE x $70 = 217,000 and not a cent more: the hedge contribution is zero.
		let januaryRevenue = try #require(revenue[Self.january])
		#expect(abs(januaryRevenue - 217_000.0) < 0.01)

		// 2,800 BOE x $70 = 196,000, likewise.
		let februaryRevenue = try #require(revenue[Self.february])
		#expect(abs(februaryRevenue - 196_000.0) < 0.01)
	}

	// MARK: - The inner level: a real zero, not an absence

	/// The path that proves the inner guard is unreachable rather than merely untested.
	///
	/// The swap settles only in February, so `totalSettlements` reaches January with no
	/// instrument matching — and emits a row of `0` for it rather than omitting the period. The
	/// inner lookup therefore hits, and January's revenue is production x price alone while
	/// February's carries the settlement. If `totalSettlements` ever started omitting such
	/// periods, this test would begin throwing instead of computing.
	@Test("Commodity_HedgedProducerWithNoInstrumentThisPeriodSettlesAtZero")
	func hedgedProducerWithNoInstrumentThisPeriodSettlesAtZero() throws {
		var program = HedgingProgram<Double>()
		program.addSwap(CommoditySwap(
			underlier: "WTI",
			fixedPrice: 75.0,
			notionalVolume: 1_000.0,
			settlementPeriods: [Self.february]
		))

		let hedged = OilGasEPModel(
			entity: Entity(id: "EP-HEDGED", name: "Hedged E&P Corp"),
			wells: [WellProductionProfile(
				name: "Well #1",
				dailyProduction: TimeSeries<Double>(
					periods: Self.projectedPeriods,
					values: [100.0, 100.0, 100.0]
				)
			)],
			commodityPriceName: "WTI",
			leaseOperatingExpensePerBOE: 15.0,
			generalAndAdminExpense: 50_000.0,
			depreciationRate: 0.01,
			initialPPE: 10_000_000.0,
			initialCash: 500_000.0,
			taxRate: 0.21,
			hedgingProgram: program
		)

		let integration = try hedged.project(
			periods: Self.projectedPeriods,
			commodityPrices: prices(Self.projectedPeriods)
		)
		let revenue = integration.incomeStatement.totalRevenue

		// January: no instrument settles, so 3,100 BOE x $70 = 217,000 with a zero settlement.
		let januaryRevenue = try #require(revenue[Self.january])
		#expect(abs(januaryRevenue - 217_000.0) < 0.01)

		// February: the swap settles, ($75 - $70) x 1,000 = 5,000 on top of 2,800 x $70.
		let februaryRevenue = try #require(revenue[Self.february])
		#expect(abs(februaryRevenue - 201_000.0) < 0.01)
	}

	/// When the price is the thing missing, it is the *price* guard that fires, not the hedge
	/// one — which is the outward sign that the two levels were not collapsed into one check.
	@Test("Commodity_HedgedProducerRefusalNamesThePriceNotTheHedge")
	func hedgedProducerRefusalNamesThePriceNotTheHedge() throws {
		var program = HedgingProgram<Double>()
		program.addSwap(CommoditySwap(
			underlier: "WTI",
			fixedPrice: 75.0,
			notionalVolume: 1_000.0,
			settlementPeriods: Self.projectedPeriods
		))

		let hedged = OilGasEPModel(
			entity: Entity(id: "EP-HEDGED-GAP", name: "Hedged E&P Corp"),
			wells: [WellProductionProfile(
				name: "Well #1",
				dailyProduction: TimeSeries<Double>(
					periods: Self.projectedPeriods,
					values: [100.0, 100.0, 100.0]
				)
			)],
			commodityPriceName: "Brent",
			leaseOperatingExpensePerBOE: 15.0,
			generalAndAdminExpense: 50_000.0,
			depreciationRate: 0.01,
			initialPPE: 10_000_000.0,
			initialCash: 500_000.0,
			taxRate: 0.21,
			hedgingProgram: program
		)

		let thrown = #expect(throws: BusinessMathError.self) {
			_ = try hedged.project(
				periods: Self.projectedPeriods,
				commodityPrices: prices([Self.january, Self.february])
			)
		}

		let error = try #require(thrown)
		guard case .missingData(let account, let periodLabel) = error else {
			Issue.record("expected missingData, got \(error)")
			return
		}
		#expect(account == "Brent price",
				"the price guard, not the hedge-settlement guard")
		#expect(periodLabel == Self.march.label)
	}

	// MARK: - TimeSeriesExtensions: two provably unreachable fallbacks, pinned

	/// `averageTimeSeries` and `periodOverPeriodGrowth` each carry two `?? T(0)` reads that the
	/// sweep examined and left alone. Both iterate the series' own `periods`, and
	/// `TimeSeries.periods` is `values.keys.sorted()` while `subscript(_:)` is `values[period]`,
	/// so a series' period list and its key set are the same set and neither fallback can fire.
	///
	/// This test pins the invariant the argument rests on rather than the fallbacks themselves,
	/// because a fallback that cannot fire has no behaviour to assert. A series built with a
	/// deliberate duplicate — which `init(periods:values:)` collapses, last value wins — is
	/// included because collapsing is the one operation that makes the key set differ from the
	/// array the caller passed.
	@Test("TimeSeries_PeriodListAndKeySetAgree")
	func periodListAndKeySetAgree() throws {
		let series = TimeSeries<Double>(
			periods: [Self.january, Self.february, Self.march],
			values: [100.0, 120.0, 140.0]
		)
		// `compactMap` drops a miss, so a resolved list that still carries every value proves
		// no subscript over the series' own periods came back empty.
		let resolved: [Double] = series.periods.compactMap { series[$0] }
		let resolvedMatches = agree(resolved, [100.0, 120.0, 140.0])
		#expect(resolvedMatches, "no subscript over a series' own periods can miss")

		// Duplicate collapse is the one operation that makes the key set differ from the array
		// the caller passed: three periods in, two keys out, January keeping the last value.
		let collapsed = TimeSeries<Double>(
			periods: [Self.january, Self.january, Self.february],
			values: [100.0, 110.0, 120.0]
		)
		let collapsedResolved: [Double] = collapsed.periods.compactMap { collapsed[$0] }
		let collapsedMatches = agree(collapsedResolved, [110.0, 120.0])
		#expect(collapsedMatches, "the invariant survives duplicate collapse")

		// And the averages computed over that series are the real values, not zeros:
		// first period keeps its own value, the second averages (100 + 120) / 2 = 110.
		let averaged = averageTimeSeries(series)
		let januaryAverage = try #require(averaged[Self.january])
		#expect(abs(januaryAverage - 100.0) < 1e-9)
		let februaryAverage = try #require(averaged[Self.february])
		#expect(abs(februaryAverage - 110.0) < 1e-9)

		// Growth from 100 to 120 is 0.20; a fired fallback would have made it infinite or 1.0.
		let growth = series.periodOverPeriodGrowth()
		let februaryGrowth = try #require(growth[Self.february])
		#expect(abs(februaryGrowth - 0.2) < 1e-9)
	}
}

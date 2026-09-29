//
//  CreditMetricsCoverageTests.swift
//  BusinessMathTests
//
//  The Piotroski F-Score went **up** when the data ran out.
//
//  `piotroskiScore` takes two periods and thresholds on both: six of its nine signals compare
//  the current period against the prior one. Every one of its nineteen statement lookups used
//  to end in `?? T(0)`, so a prior period outside the statements did not produce a weaker
//  answer — it produced a *different company's* answer, one whose prior quarter reported
//  nothing at all. Against a baseline of zero, "did the margin improve?" and "did the return on
//  assets improve?" are both answered yes, and the points are awarded.
//
//  That fabricated company is constructible, which is what makes the damage measurable rather
//  than argued. `zeroPrior: true` below files a prior quarter of literal zeros — exactly the
//  figures `?? T(0)` claimed to have read — and scores it with the fixed function. The two
//  runs differ in nothing but the prior column:
//
//  | prior quarter                   | F-Score | the DocC's reading      |
//  |---------------------------------|---------|-------------------------|
//  | the company's real Q4 2024      | 4       | average fundamentals    |
//  | fabricated zeros (`?? T(0)`)    | 7       | **strong — buy signal** |
//
//  The company is deteriorating on every comparative signal. The absence of a quarter moved it
//  across the threshold the documentation names as a buy signal.
//
//  Contract §3.7 is "narrow the domain, do not fabricate the observation", and `PiotroskiScore`
//  has nowhere to put "not answerable": `totalScore` is a non-optional `Int` and the `signals`
//  DocC promises all nine keys. So the function refuses — `BusinessMathError.missingData` —
//  which is a narrower domain rather than the invented result case §3.4 forbids.
//
//  Every test below pairs the refusal with the covered control, so a function that simply threw
//  on everything would fail this suite rather than pass it.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Piotroski F-Score period coverage")
struct CreditMetricsCoverageTests {

	private static let priorQuarter = Period.quarter(year: 2024, quarter: 4)
	private static let currentQuarter = Period.quarter(year: 2025, quarter: 1)

	/// A quarter before anything the statements contain.
	private static let uncoveredPrior = Period.quarter(year: 2024, quarter: 3)

	/// A quarter after everything the statements contain.
	private static let uncoveredCurrent = Period.quarter(year: 2025, quarter: 2)

	// MARK: - Fixture

	/// A profitable company whose fundamentals are deteriorating quarter over quarter.
	///
	/// Revenue falls, the gross margin narrows, long-term debt grows and the current ratio
	/// halves, while the company stays profitable and cash-generative. That combination is the
	/// point: the signals that read a *level* stay true and the signals that read a *change*
	/// are all false, so anything that erases the prior period shows up as a score increase.
	///
	/// - Parameter zeroPrior: When `true`, every prior-quarter figure is filed as `0` — the
	///   statements the old `?? T(0)` fallbacks claimed to be reading. The current quarter and
	///   the set of covered periods are identical either way.
	private func company(zeroPrior: Bool) throws -> (
		IncomeStatement<Double>,
		BalanceSheet<Double>,
		CashFlowStatement<Double>
	) {
		let entity = Entity(id: "FADE", primaryType: .ticker, name: "Fading Corp")
		let quarters = [Self.priorQuarter, Self.currentQuarter]
		let priorScale: Double = zeroPrior ? 0.0 : 1.0

		func series(_ prior: Double, _ current: Double) -> TimeSeries<Double> {
			return TimeSeries(periods: quarters, values: [prior * priorScale, current])
		}

		// Income statement: revenue falling 120,000 -> 100,000 on flat costs, so the gross
		// margin narrows from 0.625 to 0.55 and net income falls from 53,000 to 33,000.
		let revenue = try Account(entity: entity, name: "Revenue",
			incomeStatementRole: .revenue, timeSeries: series(120_000, 100_000))
		let cogs = try Account(entity: entity, name: "COGS",
			incomeStatementRole: .costOfGoodsSold, timeSeries: series(45_000, 45_000))
		let opex = try Account(entity: entity, name: "Operating Expenses",
			incomeStatementRole: .operatingExpenseOther, timeSeries: series(22_000, 22_000))
		let incomeStatement = try IncomeStatement(
			entity: entity, periods: quarters, accounts: [revenue, cogs, opex])

		// Balance sheet: total assets flat at 160,000, cash converted into fixed assets, payables
		// and long-term debt both rising.
		let cash = try Account(entity: entity, name: "Cash",
			balanceSheetRole: .cashAndEquivalents, timeSeries: series(60_000, 50_000))
		let ppe = try Account(entity: entity, name: "PPE",
			balanceSheetRole: .propertyPlantEquipment, timeSeries: series(100_000, 110_000))
		let payables = try Account(entity: entity, name: "Accounts Payable",
			balanceSheetRole: .accountsPayable, timeSeries: series(20_000, 25_000))
		let debt = try Account(entity: entity, name: "Long-Term Debt",
			balanceSheetRole: .longTermDebt, timeSeries: series(25_000, 30_000))
		let retained = try Account(entity: entity, name: "Retained Earnings",
			balanceSheetRole: .retainedEarnings, timeSeries: series(120_000, 153_000))
		let stock = try Account(entity: entity, name: "Common Stock",
			balanceSheetRole: .commonStock, timeSeries: series(20_000, 20_000))
		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: quarters,
			accounts: [cash, ppe, payables, debt, retained, stock]
		)

		// Cash flow: operating cash flow above net income in both quarters.
		let operating = try Account(entity: entity, name: "Cash from Operations",
			cashFlowRole: .otherOperatingActivities, timeSeries: series(60_000, 40_000))
		let cashFlowStatement = try CashFlowStatement(
			entity: entity, periods: quarters, accounts: [operating])

		return (incomeStatement, balanceSheet, cashFlowStatement)
	}

	private func score(
		zeroPrior: Bool = false,
		period: Period = CreditMetricsCoverageTests.currentQuarter,
		priorPeriod: Period = CreditMetricsCoverageTests.priorQuarter
	) throws -> PiotroskiScore {
		let (incomeStatement, balanceSheet, cashFlowStatement) = try company(zeroPrior: zeroPrior)
		return try piotroskiScore(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			cashFlowStatement: cashFlowStatement,
			period: period,
			priorPeriod: priorPeriod
		)
	}

	// MARK: - The fixture has to contain what it claims

	/// A modulus collision or a mistyped role would make every assertion below vacuous, so the
	/// fixture proves its own shape first: two quarters in the books, the two uncovered
	/// quarters outside them, and a real company rather than an empty one.
	@Test("Piotroski_FixtureCoversTwoQuartersAndNoMore")
	func fixtureCoversTwoQuartersAndNoMore() throws {
		let (incomeStatement, balanceSheet, _) = try company(zeroPrior: false)

		let assetsNow = try #require(balanceSheet.totalAssets[Self.currentQuarter])
		let assetsThen = try #require(balanceSheet.totalAssets[Self.priorQuarter])
		#expect(assetsNow.isEqual(to: 160_000.0))
		#expect(assetsThen.isEqual(to: 160_000.0), "assets are flat, so the score moves on flows")

		let revenueNow = try #require(incomeStatement.totalRevenue[Self.currentQuarter])
		let revenueThen = try #require(incomeStatement.totalRevenue[Self.priorQuarter])
		#expect(revenueNow < revenueThen, "the company is deteriorating, not improving")

		let covered = Set(balanceSheet.totalAssets.periods)
		#expect(!covered.contains(Self.uncoveredPrior),
				"Q3 2024 must be outside the books or the uncovered-prior case is not exercised")
		#expect(!covered.contains(Self.uncoveredCurrent),
				"Q2 2025 must be outside the books or the uncovered-current case is not exercised")
	}

	/// The zero-prior variant must differ from the truthful one in the prior column *only*.
	@Test("Piotroski_ZeroPriorFixtureDiffersOnlyInThePriorQuarter")
	func zeroPriorFixtureDiffersOnlyInThePriorQuarter() throws {
		let (_, truthful, _) = try company(zeroPrior: false)
		let (_, fabricated, _) = try company(zeroPrior: true)

		let truthfulNow = try #require(truthful.totalAssets[Self.currentQuarter])
		let fabricatedNow = try #require(fabricated.totalAssets[Self.currentQuarter])
		#expect(fabricatedNow.isEqual(to: truthfulNow), "the current quarter is untouched")

		let fabricatedThen = try #require(fabricated.totalAssets[Self.priorQuarter])
		#expect(fabricatedThen.isEqual(to: 0.0), "the prior quarter is the zeros `?? T(0)` invented")
	}

	// MARK: - The control: a fully covered pair still scores, and scores correctly

	@Test("Piotroski_CoveredPairScoresEachSignalCorrectly")
	func coveredPairScoresEachSignalCorrectly() throws {
		let result = try score()

		// Levels — true, because the company is profitable and cash-generative now.
		#expect(result.signals["positiveNetIncome"] == true, "net income 33,000")
		#expect(result.signals["positiveOperatingCashFlow"] == true, "operating cash flow 40,000")
		#expect(result.signals["qualityEarnings"] == true, "40,000 of cash against 33,000 of income")
		#expect(result.signals["noNewEquity"] == true,
				"equity rose 33,000 and retained earnings rose 33,000, so no shares were sold")

		// Changes — false, because every comparison against the prior quarter is unfavourable.
		#expect(result.signals["increasingROA"] == false, "0.33125 -> 0.20625")
		#expect(result.signals["decreasingDebt"] == false, "long-term debt 25,000 -> 30,000")
		#expect(result.signals["increasingCurrentRatio"] == false, "3.0 -> 2.0")
		#expect(result.signals["increasingGrossMargin"] == false, "0.625 -> 0.55")
		#expect(result.signals["increasingAssetTurnover"] == false, "0.75 -> 0.625")

		#expect(result.profitability == 3)
		#expect(result.leverage == 1)
		#expect(result.efficiency == 0)
		#expect(result.totalScore == 4, "average fundamentals, per the DocC's own scale")
	}

	/// The `signals` DocC promises all nine keys, and callers are told they may force-unwrap
	/// those literal names. Refusing an uncovered period must not quietly weaken that promise
	/// for the periods that are covered.
	@Test("Piotroski_CoveredPairStillPopulatesAllNineSignals")
	func coveredPairStillPopulatesAllNineSignals() throws {
		let result = try score()
		let expected: Set<String> = [
			"positiveNetIncome",
			"positiveOperatingCashFlow",
			"increasingROA",
			"qualityEarnings",
			"decreasingDebt",
			"increasingCurrentRatio",
			"noNewEquity",
			"increasingGrossMargin",
			"increasingAssetTurnover"
		]
		#expect(Set(result.signals.keys) == expected)

		let componentSum = result.profitability + result.leverage + result.efficiency
		#expect(result.totalScore == componentSum)
	}

	// MARK: - What the fabricated prior quarter was worth

	/// The measurement, made by scoring the company the `?? T(0)` fallbacks described.
	///
	/// This is the assertion that matters: the fabrication did not merely give a different
	/// answer, it gave a **better** one, and it crossed the threshold the DocC names as a buy
	/// signal for value investors.
	@Test("Piotroski_FabricatedPriorQuarterOutscoresTheTruth")
	func fabricatedPriorQuarterOutscoresTheTruth() throws {
		let truth = try score(zeroPrior: false)
		let fabricated = try score(zeroPrior: true)

		#expect(fabricated.totalScore > truth.totalScore,
				"a prior quarter of zeros scored \(fabricated.totalScore) against \(truth.totalScore)")
		#expect(truth.totalScore == 4)
		#expect(fabricated.totalScore == 7)
		#expect(fabricated.totalScore >= 7,
				"7 is 'strong fundamentals' in this file's DocC, reached only by losing the data")

		// Three of the four points come from comparisons that have nothing left to compare.
		#expect(fabricated.signals["increasingROA"] == true, "0.20625 beats a return on no assets")
		#expect(fabricated.signals["increasingGrossMargin"] == true, "0.55 beats a margin on no sales")
		#expect(fabricated.signals["increasingAssetTurnover"] == true, "0.625 beats turnover on no assets")
	}

	// MARK: - The refusal

	@Test("Piotroski_UncoveredPriorPeriodIsRefused")
	func uncoveredPriorPeriodIsRefused() throws {
		let (incomeStatement, balanceSheet, cashFlowStatement) = try company(zeroPrior: false)

		let thrown = #expect(throws: BusinessMathError.self) {
			_ = try piotroskiScore(
				incomeStatement: incomeStatement,
				balanceSheet: balanceSheet,
				cashFlowStatement: cashFlowStatement,
				period: Self.currentQuarter,
				priorPeriod: Self.uncoveredPrior
			)
		}

		let error = try #require(thrown)
		guard case .missingData(let account, let periodLabel) = error else {
			Issue.record("expected missingData, got \(error)")
			return
		}
		#expect(periodLabel == Self.uncoveredPrior.label,
				"the diagnostic names the quarter that was never filed")
		#expect(account == "totalAssets",
				"the first prior-period figure the score reaches")
	}

	@Test("Piotroski_UncoveredCurrentPeriodIsRefused")
	func uncoveredCurrentPeriodIsRefused() throws {
		let (incomeStatement, balanceSheet, cashFlowStatement) = try company(zeroPrior: false)

		let thrown = #expect(throws: BusinessMathError.self) {
			_ = try piotroskiScore(
				incomeStatement: incomeStatement,
				balanceSheet: balanceSheet,
				cashFlowStatement: cashFlowStatement,
				period: Self.uncoveredCurrent,
				priorPeriod: Self.priorQuarter
			)
		}

		let error = try #require(thrown)
		guard case .missingData(let account, let periodLabel) = error else {
			Issue.record("expected missingData, got \(error)")
			return
		}
		#expect(periodLabel == Self.uncoveredCurrent.label)
		#expect(account == "netIncome", "the first figure the score reaches at all")
	}

	/// The alias forwards, so it must refuse and score identically rather than keeping the old
	/// fabricating behaviour alive under a second name.
	@Test("Piotroski_AliasRefusesAndScoresIdentically")
	func aliasRefusesAndScoresIdentically() throws {
		let (incomeStatement, balanceSheet, cashFlowStatement) = try company(zeroPrior: false)

		let viaAlias = try piotroskiFScore(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			cashFlowStatement: cashFlowStatement,
			period: Self.currentQuarter,
			priorPeriod: Self.priorQuarter
		)
		let direct = try score()
		#expect(viaAlias.totalScore == direct.totalScore)

		let thrown = #expect(throws: BusinessMathError.self) {
			_ = try piotroskiFScore(
				incomeStatement: incomeStatement,
				balanceSheet: balanceSheet,
				cashFlowStatement: cashFlowStatement,
				period: Self.currentQuarter,
				priorPeriod: Self.uncoveredPrior
			)
		}
		let error = try #require(thrown)
		#expect(error == BusinessMathError.missingData(
			account: "totalAssets", period: Self.uncoveredPrior.label))
	}

	// MARK: - Zero current liabilities is the strongest liquidity, not the weakest

	/// `increasingCurrentRatio` used to read `currentLiabilities != 0 ? assets / liabilities : 0`,
	/// which is the wrong end of the scale: settling every short-term obligation produced a
	/// ratio of `0`, so a company that became fully liquid *lost* the liquidity point. It is
	/// the same error `altmanZScore`'s component D carried for `totalLiabilities == 0`.
	@Test("Piotroski_PayingOffCurrentLiabilitiesEarnsTheLiquidityPoint")
	func payingOffCurrentLiabilitiesEarnsTheLiquidityPoint() throws {
		let entity = Entity(id: "LIQUID", primaryType: .ticker, name: "Liquid Corp")
		let quarters = [Self.priorQuarter, Self.currentQuarter]

		let revenue = try Account(entity: entity, name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: quarters, values: [100_000, 100_000]))
		let cogs = try Account(entity: entity, name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: TimeSeries(periods: quarters, values: [40_000, 40_000]))
		let incomeStatement = try IncomeStatement(
			entity: entity, periods: quarters, accounts: [revenue, cogs])

		let cash = try Account(entity: entity, name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: quarters, values: [50_000, 50_000]))
		// Every payable settled in the current quarter: 20,000 -> 0.
		let payables = try Account(entity: entity, name: "Accounts Payable",
			balanceSheetRole: .accountsPayable,
			timeSeries: TimeSeries(periods: quarters, values: [20_000, 0]))
		let retained = try Account(entity: entity, name: "Retained Earnings",
			balanceSheetRole: .retainedEarnings,
			timeSeries: TimeSeries(periods: quarters, values: [30_000, 50_000]))
		let balanceSheet = try BalanceSheet(
			entity: entity, periods: quarters, accounts: [cash, payables, retained])

		let operating = try Account(entity: entity, name: "Cash from Operations",
			cashFlowRole: .otherOperatingActivities,
			timeSeries: TimeSeries(periods: quarters, values: [70_000, 70_000]))
		let cashFlowStatement = try CashFlowStatement(
			entity: entity, periods: quarters, accounts: [operating])

		// The fixture has to actually reach the zero-divisor arm, or this proves nothing.
		let liabilitiesNow = try #require(balanceSheet.currentLiabilities[Self.currentQuarter])
		let liabilitiesThen = try #require(balanceSheet.currentLiabilities[Self.priorQuarter])
		#expect(liabilitiesNow.isEqual(to: 0.0))
		#expect(liabilitiesThen > 0.0)

		let result = try piotroskiScore(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			cashFlowStatement: cashFlowStatement,
			period: Self.currentQuarter,
			priorPeriod: Self.priorQuarter
		)
		#expect(result.signals["increasingCurrentRatio"] == true,
				"2.5 -> unbounded is an improvement; the old fallback read it as 2.5 -> 0")
	}
}

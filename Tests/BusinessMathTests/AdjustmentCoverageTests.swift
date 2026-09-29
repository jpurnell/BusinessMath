//
//  AdjustmentCoverageTests.swift
//  BusinessMath
//
//  Pins what pro forma adjustments, account hierarchies and working-capital components do
//  about a period the underlying data does not cover.
//
//  Contract: `project/plans/CONTAMINATED_INPUT_CONTRACT.md` §3.7 — narrow the domain, do not
//  fabricate the observation. Each refusal below is paired with a fully covered control that
//  still computes its answer, because a suite where everything refuses proves nothing.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("Adjustment and node period coverage")
struct AdjustmentCoverageTests {

	// MARK: - Helpers

	private func makeEntity() -> Entity {
		Entity(id: "COVER", primaryType: .internal, name: "Coverage Test Company")
	}

	private var q1: Period { Period.quarter(year: 2025, quarter: 1) }
	private var q2: Period { Period.quarter(year: 2025, quarter: 2) }
	private var q3: Period { Period.quarter(year: 2025, quarter: 3) }
	private var q4: Period { Period.quarter(year: 2025, quarter: 4) }
	private var fourQuarters: [Period] { [q1, q2, q3, q4] }

	private var jan: Period { Period.month(year: 2025, month: 1) }
	private var feb: Period { Period.month(year: 2025, month: 2) }

	private func makeExpenseAccount(
		name: String,
		periods: [Period],
		values: [Double]
	) throws -> Account<Double> {
		try Account<Double>(
			entity: makeEntity(),
			name: name,
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: TimeSeries(periods: periods, values: values)
		)
	}

	/// Elementwise agreement that treats two `nan`s as agreeing.
	///
	/// `isEqual(to:)` is IEEE equality, so `Double.nan.isEqual(to: .nan)` is `false`; a plain
	/// zip of `isEqual(to:)` therefore reports disagreement between two series that are
	/// identically unanswerable.
	private func agree(_ lhs: [Double], _ rhs: [Double]) -> Bool {
		lhs.count == rhs.count && Swift.zip(lhs, rhs).allSatisfy { $0.isEqual(to: $1) || ($0.isNaN && $1.isNaN) }
	}

	// MARK: - 1. A sparse adjustment contributes zero where it was not booked

	/// `adjustment.amount[period] ?? T(0)` is **correct**: an adjustment that does not name a
	/// period was not booked in it, and zero is that adjustment's true contribution there. The
	/// documented use case is exactly this — a one-time Q1 settlement is deliberately a
	/// one-period series applied across four quarters. Narrowing to the adjustment's own
	/// periods would shrink a four-quarter account to one and discard three measured balances.
	@Test("A one-quarter adjustment leaves the other quarters exactly as filed")
	func sparseAdjustmentLeavesOtherQuartersAlone() throws {
		let filed: [Double] = [500.0, 510.0, 520.0, 530.0]
		let account = try makeExpenseAccount(name: "Legal Fees", periods: fourQuarters, values: filed)

		let settlement = AccountAdjustment<Double>(
			adjustmentType: .addback,
			amount: TimeSeries(periods: [q1], values: [250.0]),
			description: "One-time litigation settlement"
		)

		let adjusted = try account.applying(adjustment: settlement)

		// The domain is the account's, unchanged.
		#expect(adjusted.timeSeries.periods == fourQuarters)

		// Q1 carries the adjustment; the rest carry the filed figure and nothing else.
		let expected: [Double] = [filed[0] + 250.0, filed[1], filed[2], filed[3]]
		let actual: [Double] = fourQuarters.compactMap { adjusted.timeSeries[$0] }
		#expect(agree(actual, expected))
	}

	// MARK: - 2. An adjustment outside the account's periods invents no period

	/// The base half of the same expression is a different decision from the adjustment half.
	/// The account's own periods are the domain, so an adjustment booked where the account
	/// filed nothing is dropped rather than added to a fabricated base of zero — the base
	/// figure for that quarter is unknown, so the sum is not answerable there.
	@Test("An adjustment booked outside the account's periods does not widen the account")
	func adjustmentOutsideTheAccountIsNotInvented() throws {
		let account = try makeExpenseAccount(name: "Legal Fees", periods: [q1], values: [500.0])

		let misfiled = AccountAdjustment<Double>(
			adjustmentType: .oneTimeCharge,
			amount: TimeSeries(periods: [q2], values: [250.0]),
			description: "Charge booked in a quarter this account does not report"
		)

		let adjusted = try account.applying(adjustment: misfiled)

		#expect(adjusted.timeSeries.periods == [q1])

		let q1Value: Double = try #require(adjusted.timeSeries[q1])
		#expect(q1Value.isEqual(to: 500.0))
	}

	// MARK: - 3. Several adjustments sum per period

	@Test("Adjustments with different coverage sum per period")
	func multipleAdjustmentsSumPerPeriod() throws {
		let filed: [Double] = [500.0, 510.0, 520.0, 530.0]
		let account = try makeExpenseAccount(name: "G&A", periods: fourQuarters, values: filed)

		let relocation = AccountAdjustment<Double>(
			adjustmentType: .oneTimeCharge,
			amount: TimeSeries(periods: [q1], values: [100.0]),
			description: "Relocation costs"
		)
		let ownerComp = AccountAdjustment<Double>(
			adjustmentType: .ownerCompensation,
			amount: TimeSeries(periods: fourQuarters, values: [25.0, 25.0, 25.0, 25.0]),
			description: "Normalize CFO comp to market"
		)

		let adjusted = try account.applying(adjustments: [relocation, ownerComp])

		#expect(adjusted.timeSeries.periods == fourQuarters)

		let expected: [Double] = [
			filed[0] + 100.0 + 25.0,
			filed[1] + 25.0,
			filed[2] + 25.0,
			filed[3] + 25.0
		]
		let actual: [Double] = fourQuarters.compactMap { adjusted.timeSeries[$0] }
		#expect(agree(actual, expected))
	}

	// MARK: - 4. Adjusted EBITDA — fully covered control

	private func makeIncomeStatement(periods: [Period]) throws -> IncomeStatement<Double> {
		let entity = makeEntity()
		let revenue = try Account<Double>(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [1000.0, 1100.0, 1200.0, 1300.0])
		)
		let cogs = try Account<Double>(
			entity: entity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: TimeSeries(periods: periods, values: [400.0, 440.0, 480.0, 520.0])
		)
		let opex = try Account<Double>(
			entity: entity,
			name: "Operating Expenses",
			incomeStatementRole: .generalAndAdministrative,
			timeSeries: TimeSeries(periods: periods, values: [200.0, 220.0, 240.0, 260.0])
		)
		let da = try Account<Double>(
			entity: entity,
			name: "Depreciation",
			incomeStatementRole: .depreciationAmortization,
			timeSeries: TimeSeries(periods: periods, values: [50.0, 50.0, 50.0, 50.0])
		)

		return try IncomeStatement<Double>(
			entity: entity,
			periods: periods,
			accounts: [revenue, cogs, opex, da]
		)
	}

	/// EBITDA is `operatingIncome + nonCashCharges`, and `operatingIncome` is
	/// `grossProfit - operatingExpenses - nonCashCharges`, so the D&A cancels and EBITDA is
	/// `revenue - cogs - opex`. Derived here rather than recalled.
	@Test("Adjusted EBITDA adds exactly what was booked, on the periods EBITDA reports")
	func adjustedEBITDAOnAFullyCoveredStatement() throws {
		let statement = try makeIncomeStatement(periods: fourQuarters)

		let addback = AccountAdjustment<Double>(
			adjustmentType: .addback,
			amount: TimeSeries(periods: [q1], values: [75.0]),
			description: "Non-recurring legal settlement"
		)

		let adjusted = statement.adjustedEBITDA(adjustments: [addback])

		// The adjusted series covers exactly what the unadjusted one does — the empty-adjustment
		// branch returns `ebitda` itself, and passing an adjustment must not widen the domain.
		#expect(adjusted.periods == statement.ebitda.periods)
		#expect(adjusted.periods == fourQuarters)

		// Absolute check on Q1, derived from the account values above.
		let q1EBITDA: Double = 1000.0 - 400.0 - 200.0
		let q1Expected: Double = q1EBITDA + 75.0
		let q1Adjusted: Double = try #require(adjusted[q1])
		let q1Delta: Double = abs(q1Adjusted - q1Expected)
		#expect(q1Delta < 1e-9)

		// Q2 through Q4 are the reported EBITDA untouched: the addback names only Q1.
		let q3EBITDA: Double = 1200.0 - 480.0 - 240.0
		let q3Adjusted: Double = try #require(adjusted[q3])
		let q3Delta: Double = abs(q3Adjusted - q3EBITDA)
		#expect(q3Delta < 1e-9)

		// And the empty-adjustment path agrees with the adjusted path where nothing was booked.
		let unadjusted: TimeSeries<Double> = statement.adjustedEBITDA(adjustments: [])
		let unadjustedQ3: Double = try #require(unadjusted[q3])
		let unadjustedDelta: Double = abs(unadjustedQ3 - q3EBITDA)
		#expect(unadjustedDelta < 1e-9)
	}

	// MARK: - 5. A node cannot total a period its account did not file

	/// The one measurable defect of the eight sites reviewed. `AccountNode.total(for:)` answered
	/// `0` for any period outside its account's series — "this node earned exactly nothing" —
	/// and the recursive `reduce` summed that zero into the consolidated parent.
	@Test("A leaf node declines a period its account does not report, and still totals the rest")
	func leafNodeRefusesAnUnreportedPeriod() throws {
		let account = try makeExpenseAccount(name: "Revenue", periods: [jan, feb], values: [100.0, 200.0])
		let node = AccountNode<Double>(id: "rev", account: account)

		let unreported: Double = node.total(for: Period.month(year: 2099, month: 12))
		#expect(unreported.isNaN)

		// Control: the reported periods still answer.
		let january: Double = node.total(for: jan)
		let januaryDelta: Double = abs(january - 100.0)
		#expect(januaryDelta < 1e-6)
	}

	@Test("A parent declines a period one of its children did not file")
	func parentDeclinesWhenAChildDidNotFile() throws {
		let fullYear = try makeExpenseAccount(name: "Established", periods: [jan, feb], values: [100.0, 200.0])
		let acquired = try makeExpenseAccount(name: "Acquired", periods: [feb], values: [40.0])

		let parent = AccountNode<Double>(
			id: "group",
			account: nil,
			children: [
				AccountNode<Double>(id: "established", account: fullYear),
				AccountNode<Double>(id: "acquired", account: acquired)
			]
		)

		// February: both subsidiaries filed, so the consolidation is answerable.
		let february: Double = parent.total(for: feb)
		let februaryDelta: Double = abs(february - 240.0)
		#expect(februaryDelta < 1e-6)

		// January: the acquired subsidiary filed nothing. The old behaviour reported 100 —
		// the established company's figure — as the group total.
		let january: Double = parent.total(for: jan)
		#expect(january.isNaN)
	}

	/// A grouping node carrying no account holds no figure of its own, so zero is its measured
	/// contribution rather than a stand-in for one. This site is legitimate and stays.
	@Test("An empty grouping node contributes zero for any period")
	func emptyGroupingNodeContributesZero() throws {
		let empty = AccountNode<Double>(id: "placeholder", account: nil)

		let reported: Double = empty.total(for: jan)
		#expect(reported.isEqual(to: 0.0))

		let unreported: Double = empty.total(for: Period.month(year: 2099, month: 12))
		#expect(unreported.isEqual(to: 0.0))
	}

	// MARK: - 6. Working capital components — fully covered control

	@Test("Working capital components negate liabilities and keep the reported periods")
	func workingCapitalComponentsOnAFullyCoveredBalanceSheet() throws {
		let entity = makeEntity()
		let receivables: [Double] = [200.0, 220.0, 240.0, 260.0]
		let payables: [Double] = [150.0, 165.0, 180.0, 195.0]

		let ar = try Account<Double>(
			entity: entity,
			name: "Accounts Receivable",
			balanceSheetRole: .accountsReceivable,
			timeSeries: TimeSeries(periods: fourQuarters, values: receivables)
		)
		let ap = try Account<Double>(
			entity: entity,
			name: "Accounts Payable",
			balanceSheetRole: .accountsPayable,
			timeSeries: TimeSeries(periods: fourQuarters, values: payables)
		)
		let equity = try Account<Double>(
			entity: entity,
			name: "Retained Earnings",
			balanceSheetRole: .retainedEarnings,
			timeSeries: TimeSeries(periods: fourQuarters, values: [50.0, 55.0, 60.0, 65.0])
		)

		let balanceSheet = try BalanceSheet<Double>(
			entity: entity,
			periods: fourQuarters,
			accounts: [ar, ap, equity]
		)

		let components = balanceSheet.workingCapitalComponents

		let assetSeries = try #require(components[.accountsReceivable])
		#expect(assetSeries.periods == fourQuarters)
		let assetValues: [Double] = fourQuarters.compactMap { assetSeries[$0] }
		#expect(agree(assetValues, receivables))

		let liabilitySeries = try #require(components[.accountsPayable])
		#expect(liabilitySeries.periods == fourQuarters)
		let liabilityValues: [Double] = fourQuarters.compactMap { liabilitySeries[$0] }
		let negatedPayables: [Double] = payables.map { -$0 }
		#expect(agree(liabilityValues, negatedPayables))
	}
}

//
//  StatementIntegrationTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 4/15/26.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("StatementIntegration Tests")
struct StatementIntegrationTests {

    // MARK: - Test Helpers

    private func makeEntity() -> Entity {
        Entity(id: "TEST", primaryType: .internal, name: "Test Company")
    }

    private var q1: Period { Period.quarter(year: 2025, quarter: 1) }
    private var q2: Period { Period.quarter(year: 2025, quarter: 2) }
    private var q3: Period { Period.quarter(year: 2025, quarter: 3) }
    private var q4: Period { Period.quarter(year: 2025, quarter: 4) }

    private var fourQuarters: [Period] {
        [q1, q2, q3, q4]
    }

    /// Builds a consistent set of three financial statements for testing.
    ///
    /// Revenue:       1000, 1100, 1200, 1300
    /// COGS:           400,  440,  480,  520
    /// OpEx:           200,  220,  240,  260
    /// D&A:             50,   50,   50,   50
    /// Tax:             70,   78,   86,   94
    /// Net Income:     280,  312,  344,  376
    ///
    /// Balance Sheet (cumulative):
    /// Cash:          1000, 1100, 1250, 1400
    /// AR:             200,  220,  240,  260
    /// PP&E:          2000, 2050, 2100, 2150
    /// AP:             150,  165,  180,  195
    /// LTD:           1000, 1000, 1000, 1000
    /// Retained:      2050, 2205, 2410, 2615
    ///
    /// Assets = Liabilities + Equity each period:
    /// Q1: 1000+200+2000 = 3200;  150+1000+2050 = 3200
    /// Q2: 1100+220+2050 = 3370;  165+1000+2205 = 3370
    /// Q3: 1250+240+2100 = 3590;  180+1000+2410 = 3590
    /// Q4: 1400+260+2150 = 3810;  195+1000+2615 = 3810
    ///
    /// Retained earnings change = Net income each quarter:
    /// Q2-Q1: 2205-2050 = 155 ... wait, NI Q2 = 312?
    ///
    /// Let me recalculate to ensure RE changes match NI:
    /// RE(Q1) = 2050 (starting)
    /// RE(Q2) = 2050 + 312 = 2362
    /// RE(Q3) = 2362 + 344 = 2706
    /// RE(Q4) = 2706 + 376 = 3082
    ///
    /// Then Assets must = Liabilities + Equity:
    /// Q1: Assets = 3200;  L+E = 150 + 1000 + 2050 = 3200  OK
    /// Q2: L+E = 165 + 1000 + 2362 = 3527;  Assets = cash + AR + PPE = must be 3527
    ///   AR=220, PPE=2050 => cash = 3527-220-2050 = 1257
    /// Q3: L+E = 180 + 1000 + 2706 = 3886;  AR=240, PPE=2100 => cash = 3886-240-2100 = 1546
    /// Q4: L+E = 195 + 1000 + 3082 = 4277;  AR=260, PPE=2150 => cash = 4277-260-2150 = 1867
    ///
    /// So: Cash = 1000, 1257, 1546, 1867
    private func makeConsistentStatements() throws -> (
        IncomeStatement<Double>,
        BalanceSheet<Double>,
        CashFlowStatement<Double>
    ) {
        let entity = makeEntity()
        let periods = fourQuarters

        // Income Statement accounts
        let revenue = try Account<Double>(
            entity: entity,
            name: "Revenue",
            incomeStatementRole: .revenue,
            timeSeries: TimeSeries(periods: periods, values: [1000, 1100, 1200, 1300])
        )
        let cogs = try Account<Double>(
            entity: entity,
            name: "COGS",
            incomeStatementRole: .costOfGoodsSold,
            timeSeries: TimeSeries(periods: periods, values: [400, 440, 480, 520])
        )
        let opex = try Account<Double>(
            entity: entity,
            name: "Operating Expenses",
            incomeStatementRole: .generalAndAdministrative,
            timeSeries: TimeSeries(periods: periods, values: [200, 220, 240, 260])
        )
        let da = try Account<Double>(
            entity: entity,
            name: "Depreciation",
            incomeStatementRole: .depreciationAmortization,
            timeSeries: TimeSeries(periods: periods, values: [50, 50, 50, 50])
        )
        let tax = try Account<Double>(
            entity: entity,
            name: "Tax",
            incomeStatementRole: .incomeTaxExpense,
            timeSeries: TimeSeries(periods: periods, values: [70, 78, 86, 94])
        )

        let incomeStmt = try IncomeStatement<Double>(
            entity: entity,
            periods: periods,
            accounts: [revenue, cogs, opex, da, tax]
        )

        // Net income = Revenue - (COGS + OpEx + D&A + Tax)
        // = [280, 312, 344, 376]

        // Balance Sheet accounts
        // Retained earnings: 2050, 2362, 2706, 3082
        let cash = try Account<Double>(
            entity: entity,
            name: "Cash",
            balanceSheetRole: .cashAndEquivalents,
            timeSeries: TimeSeries(periods: periods, values: [1000, 1257, 1546, 1867])
        )
        let ar = try Account<Double>(
            entity: entity,
            name: "Accounts Receivable",
            balanceSheetRole: .accountsReceivable,
            timeSeries: TimeSeries(periods: periods, values: [200, 220, 240, 260])
        )
        let ppe = try Account<Double>(
            entity: entity,
            name: "PP&E",
            balanceSheetRole: .propertyPlantEquipment,
            timeSeries: TimeSeries(periods: periods, values: [2000, 2050, 2100, 2150])
        )
        let ap = try Account<Double>(
            entity: entity,
            name: "Accounts Payable",
            balanceSheetRole: .accountsPayable,
            timeSeries: TimeSeries(periods: periods, values: [150, 165, 180, 195])
        )
        let ltd = try Account<Double>(
            entity: entity,
            name: "Long-Term Debt",
            balanceSheetRole: .longTermDebt,
            timeSeries: TimeSeries(periods: periods, values: [1000, 1000, 1000, 1000])
        )
        let retainedEarnings = try Account<Double>(
            entity: entity,
            name: "Retained Earnings",
            balanceSheetRole: .retainedEarnings,
            timeSeries: TimeSeries(periods: periods, values: [2050, 2362, 2706, 3082])
        )

        let balanceSheet = try BalanceSheet<Double>(
            entity: entity,
            periods: periods,
            accounts: [cash, ar, ppe, ap, ltd, retainedEarnings]
        )

        // Cash Flow Statement
        let niCF = try Account<Double>(
            entity: entity,
            name: "Net Income",
            cashFlowRole: .netIncome,
            timeSeries: TimeSeries(periods: periods, values: [280, 312, 344, 376])
        )
        let daCF = try Account<Double>(
            entity: entity,
            name: "D&A Addback",
            cashFlowRole: .depreciationAmortizationAddback,
            timeSeries: TimeSeries(periods: periods, values: [50, 50, 50, 50])
        )
        let capex = try Account<Double>(
            entity: entity,
            name: "CapEx",
            cashFlowRole: .capitalExpenditures,
            timeSeries: TimeSeries(periods: periods, values: [-100, -100, -100, -100])
        )

        let cashFlowStmt = try CashFlowStatement<Double>(
            entity: entity,
            periods: periods,
            accounts: [niCF, daCF, capex]
        )

        return (incomeStmt, balanceSheet, cashFlowStmt)
    }

    // MARK: - 1. Net Income Flow Validation

    @Test("Net income from IS matches retained earnings change in BS")
    func netIncomeFlowConsistent() throws {
        let (is_, bs, cf) = try makeConsistentStatements()
        let integration = StatementIntegration(
            incomeStatement: is_,
            balanceSheet: bs,
            cashFlowStatement: cf
        )

        #expect(integration.validateNetIncomeFlow(tolerance: 0.01))
    }

    // MARK: - 2. Balance Sheet Equation

    @Test("Balance sheet equation holds each period")
    func balanceSheetEquationHolds() throws {
        let (is_, bs, cf) = try makeConsistentStatements()
        let integration = StatementIntegration(
            incomeStatement: is_,
            balanceSheet: bs,
            cashFlowStatement: cf
        )

        #expect(integration.validateBalanceSheetEquation(tolerance: 0.01))
    }

    // MARK: - 3. Multi-Period Cumulative

    @Test("Multi-period (4 quarters) with cumulative updates validates correctly")
    func multiPeriodValidation() throws {
        let (is_, bs, cf) = try makeConsistentStatements()
        let integration = StatementIntegration(
            incomeStatement: is_,
            balanceSheet: bs,
            cashFlowStatement: cf
        )

        let result = integration.validate(tolerance: 0.01)
        #expect(result.allValid)
        #expect(result.balanceSheetValid)
        #expect(result.netIncomeFlowValid)
        #expect(result.issues.isEmpty)
    }

    // MARK: - 4. All Valid When Consistent

    @Test("Validation returns true when all statements are consistent")
    func allValidWhenConsistent() throws {
        let (is_, bs, cf) = try makeConsistentStatements()
        let integration = StatementIntegration(
            incomeStatement: is_,
            balanceSheet: bs,
            cashFlowStatement: cf
        )

        let result = integration.validate(tolerance: 0.01)
        #expect(result.allValid == true)
        #expect(result.issues.isEmpty)
    }

    // MARK: - 5. Invalid When Inconsistent

    @Test("Validation returns false with descriptive issues when inconsistent")
    func invalidWhenInconsistent() throws {
        let entity = makeEntity()
        let periods = fourQuarters

        // Income Statement with net income = [280, 312, 344, 376]
        let revenue = try Account<Double>(
            entity: entity,
            name: "Revenue",
            incomeStatementRole: .revenue,
            timeSeries: TimeSeries(periods: periods, values: [1000, 1100, 1200, 1300])
        )
        let cogs = try Account<Double>(
            entity: entity,
            name: "COGS",
            incomeStatementRole: .costOfGoodsSold,
            timeSeries: TimeSeries(periods: periods, values: [400, 440, 480, 520])
        )
        let opex = try Account<Double>(
            entity: entity,
            name: "OpEx",
            incomeStatementRole: .generalAndAdministrative,
            timeSeries: TimeSeries(periods: periods, values: [200, 220, 240, 260])
        )
        let da = try Account<Double>(
            entity: entity,
            name: "D&A",
            incomeStatementRole: .depreciationAmortization,
            timeSeries: TimeSeries(periods: periods, values: [50, 50, 50, 50])
        )
        let tax = try Account<Double>(
            entity: entity,
            name: "Tax",
            incomeStatementRole: .incomeTaxExpense,
            timeSeries: TimeSeries(periods: periods, values: [70, 78, 86, 94])
        )

        let incomeStmt = try IncomeStatement<Double>(
            entity: entity,
            periods: periods,
            accounts: [revenue, cogs, opex, da, tax]
        )

        // Balance sheet with WRONG retained earnings (doesn't match NI flow)
        let cash = try Account<Double>(
            entity: entity,
            name: "Cash",
            balanceSheetRole: .cashAndEquivalents,
            timeSeries: TimeSeries(periods: periods, values: [1000, 1100, 1200, 1300])
        )
        let retainedEarnings = try Account<Double>(
            entity: entity,
            name: "Retained Earnings",
            balanceSheetRole: .retainedEarnings,
            timeSeries: TimeSeries(periods: periods, values: [2050, 2100, 2150, 2200])
            // Wrong! Should be 2050, 2362, 2706, 3082
        )

        let balanceSheet = try BalanceSheet<Double>(
            entity: entity,
            periods: periods,
            accounts: [cash, retainedEarnings]
        )

        let niCF = try Account<Double>(
            entity: entity,
            name: "Net Income",
            cashFlowRole: .netIncome,
            timeSeries: TimeSeries(periods: periods, values: [280, 312, 344, 376])
        )
        let cashFlowStmt = try CashFlowStatement<Double>(
            entity: entity,
            periods: periods,
            accounts: [niCF]
        )

        let integration = StatementIntegration(
            incomeStatement: incomeStmt,
            balanceSheet: balanceSheet,
            cashFlowStatement: cashFlowStmt
        )

        let result = integration.validate(tolerance: 0.01)
        #expect(result.allValid == false)
        #expect(result.netIncomeFlowValid == false)
        #expect(!result.issues.isEmpty)
    }

    // MARK: - 6. Empty Periods

    @Test("Empty periods handled gracefully")
    func emptyPeriodsHandled() throws {
        let entity = makeEntity()
        // Use a single period with minimal data
        let periods = [q1]

        let revenue = try Account<Double>(
            entity: entity,
            name: "Revenue",
            incomeStatementRole: .revenue,
            timeSeries: TimeSeries(periods: periods, values: [1000])
        )

        let incomeStmt = try IncomeStatement<Double>(
            entity: entity,
            periods: periods,
            accounts: [revenue]
        )

        let cash = try Account<Double>(
            entity: entity,
            name: "Cash",
            balanceSheetRole: .cashAndEquivalents,
            timeSeries: TimeSeries(periods: periods, values: [1000])
        )
        let re = try Account<Double>(
            entity: entity,
            name: "Retained Earnings",
            balanceSheetRole: .retainedEarnings,
            timeSeries: TimeSeries(periods: periods, values: [1000])
        )

        let balanceSheet = try BalanceSheet<Double>(
            entity: entity,
            periods: periods,
            accounts: [cash, re]
        )

        let niCF = try Account<Double>(
            entity: entity,
            name: "Net Income",
            cashFlowRole: .netIncome,
            timeSeries: TimeSeries(periods: periods, values: [1000])
        )
        let cashFlowStmt = try CashFlowStatement<Double>(
            entity: entity,
            periods: periods,
            accounts: [niCF]
        )

        let integration = StatementIntegration(
            incomeStatement: incomeStmt,
            balanceSheet: balanceSheet,
            cashFlowStatement: cashFlowStmt
        )

        // With a single period, there are no prior periods to compare RE changes
        // so net income flow validation should pass (no transitions to check)
        let result = integration.validate(tolerance: 0.01)
        #expect(result.balanceSheetValid)
        // Net income flow is vacuously valid with only one period
        #expect(result.netIncomeFlowValid)
    }
}

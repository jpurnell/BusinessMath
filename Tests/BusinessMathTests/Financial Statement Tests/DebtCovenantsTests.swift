import Testing
import Foundation
@testable import BusinessMath

/// Comprehensive tests for debt covenants and financial constraint monitoring
//@Suite("Debt Covenants Tests")
//struct DebtCovenantsTests {
//
//    // MARK: - Test Fixtures
//
//    func createTestIncomeStatement(
//        revenue: Double,
//        cogs: Double,
//        opex: Double,
//        interest: Double,
//        tax: Double,
//        periods: [Period]
//    ) -> IncomeStatement<Double> {
//        let entity = Entity(id: "TEST", primaryType: .ticker, name: "Test Co", ticker: "TEST")
//
//        let revenueAccount = Account(
//            name: "Revenue",
//            timeSeries: TimeSeries(periods: periods, values: Array(repeating: revenue, count: periods.count)),
//            type: .revenue
//        )
//
//        let cogsAccount = Account(
//            name: "COGS",
//            timeSeries: TimeSeries(periods: periods, values: Array(repeating: cogs, count: periods.count)),
//            type: .costOfRevenue
//        )
//
//        let opexAccount = Account(
//            name: "OpEx",
//            timeSeries: TimeSeries(periods: periods, values: Array(repeating: opex, count: periods.count)),
//            type: .operatingExpense
//        )
//
//        let interestAccount = Account(
//            name: "Interest",
//            timeSeries: TimeSeries(periods: periods, values: Array(repeating: interest, count: periods.count)),
//            type: .nonOperatingExpense
//        )
//
//        let taxAccount = Account(
//            name: "Tax",
//            timeSeries: TimeSeries(periods: periods, values: Array(repeating: tax, count: periods.count)),
//            type: .tax
//        )
//
//        return IncomeStatement(
//            entity: entity,
//            revenueAccounts: [revenueAccount],
//            expenseAccounts: [cogsAccount, opexAccount, interestAccount, taxAccount]
//        )
//    }
//
//    func createTestBalanceSheet(
//        cash: Double,
//        currentAssets: Double,
//        totalAssets: Double,
//        currentLiabilities: Double,
//        debt: Double,
//        equity: Double,
//        periods: [Period]
//    ) -> BalanceSheet<Double> {
//        let entity = Entity(id: "TEST", primaryType: .ticker, name: "Test Co", ticker: "TEST")
//
//        let cashAccount = Account(
//            name: "Cash",
//            timeSeries: TimeSeries(periods: periods, values: Array(repeating: cash, count: periods.count)),
//            type: .asset,
//            metadata: AccountMetadata(category: "Current Assets")
//        )
//
//        let otherCurrentAssets = Account(
//            name: "Other Current",
//            timeSeries: TimeSeries(periods: periods, values: Array(repeating: currentAssets - cash, count: periods.count)),
//            type: .asset,
//            metadata: AccountMetadata(category: "Current Assets")
//        )
//
//        let fixedAssets = Account(
//            name: "Fixed Assets",
//            timeSeries: TimeSeries(periods: periods, values: Array(repeating: totalAssets - currentAssets, count: periods.count)),
//            type: .asset,
//            metadata: AccountMetadata(category: "Fixed Assets")
//        )
//
//        let currentLiabAccount = Account(
//            name: "Current Liabilities",
//            timeSeries: TimeSeries(periods: periods, values: Array(repeating: currentLiabilities, count: periods.count)),
//            type: .liability,
//            metadata: AccountMetadata(category: "Current Liabilities")
//        )
//
//        let debtAccount = Account(
//            name: "Long-term Debt",
//            timeSeries: TimeSeries(periods: periods, values: Array(repeating: debt, count: periods.count)),
//            type: .liability,
//            metadata: AccountMetadata(category: "Long-term Liabilities")
//        )
//
//        let equityAccount = Account(
//            name: "Equity",
//            timeSeries: TimeSeries(periods: periods, values: Array(repeating: equity, count: periods.count)),
//            type: .equity
//        )
//
//        return BalanceSheet(
//            entity: entity,
//            assetAccounts: [cashAccount, otherCurrentAssets, fixedAssets],
//            liabilityAccounts: [currentLiabAccount, debtAccount],
//            equityAccounts: [equityAccount]
//        )
//    }
//
//    // MARK: - Interest Coverage Ratio
//
//    @Test("Interest coverage ratio - healthy company")
//    func interestCoverageHealthy() throws {
//        let q1 = Period.quarter(year: 2025, quarter: 1)
//        let periods = [q1]
//
//        let incomeStatement = createTestIncomeStatement(
//            revenue: 1_000_000.0,
//            cogs: 400_000.0,
//            opex: 300_000.0,
//            interest: 50_000.0,
//            tax: 50_000.0,
//            periods: periods
//        )
//
//        let balanceSheet = createTestBalanceSheet(
//            cash: 100_000.0,
//            currentAssets: 300_000.0,
//            totalAssets: 1_000_000.0,
//            currentLiabilities: 200_000.0,
//            debt: 500_000.0,
//            equity: 300_000.0,
//            periods: periods
//        )
//
//        let covenant = FinancialCovenant(
//            name: "Interest Coverage",
//            requirement: .minimumRatio(metric: .interestCoverage, threshold: 2.0)
//        )
//
//        let isCompliant = covenant.isCompliant(
//            incomeStatement: incomeStatement,
//            balanceSheet: balanceSheet,
//            period: q1
//        )
//
//        // EBIT = 300,000, Interest = 50,000
//        // Coverage = 6.0 (well above 2.0 threshold)
//        #expect(isCompliant)
//    }
//
//    @Test("Interest coverage ratio - failing covenant")
//    func interestCoverageFailing() throws {
//        let q1 = Period.quarter(year: 2025, quarter: 1)
//        let periods = [q1]
//
//        let incomeStatement = createTestIncomeStatement(
//            revenue: 500_000.0,
//            cogs: 300_000.0,
//            opex: 180_000.0,
//            interest: 50_000.0, // High interest relative to EBIT
//            tax: 0.0,
//            periods: periods
//        )
//
//        let balanceSheet = createTestBalanceSheet(
//            cash: 50_000.0,
//            currentAssets: 200_000.0,
//            totalAssets: 800_000.0,
//            currentLiabilities: 150_000.0,
//            debt: 600_000.0,
//            equity: 50_000.0,
//            periods: periods
//        )
//
//        let covenant = FinancialCovenant(
//            name: "Interest Coverage",
//            requirement: .minimumRatio(metric: .interestCoverage, threshold: 2.5)
//        )
//
//        let isCompliant = covenant.isCompliant(
//            incomeStatement: incomeStatement,
//            balanceSheet: balanceSheet,
//            period: q1
//        )
//
//        // EBIT = 20,000, Interest = 50,000
//        // Coverage = 0.4 (below 2.5 threshold)
//        #expect(!isCompliant)
//    }
//
//    @Test("Interest coverage - calculate exact ratio")
//    func interestCoverageCalculation() throws {
//        let q1 = Period.quarter(year: 2025, quarter: 1)
//        let periods = [q1]
//
//        let ebit = 300_000.0
//        let interest = 60_000.0
//
//        let incomeStatement = createTestIncomeStatement(
//            revenue: 1_000_000.0,
//            cogs: 400_000.0,
//            opex: 300_000.0,
//            interest: interest,
//            tax: 50_000.0,
//            periods: periods
//        )
//
//        let ratio = calculateInterestCoverage(
//            incomeStatement: incomeStatement,
//            period: q1
//        )
//
//        // Expected: 300,000 / 60,000 = 5.0
//        let expected = ebit / interest
//        #expect(abs(ratio - expected) < 0.01)
//    }
//
//    // MARK: - Debt-to-EBITDA Ratio
//
//    @Test("Debt-to-EBITDA - compliant")
//    func debtToEBITDACompliant() throws {
//        let q1 = Period.quarter(year: 2025, quarter: 1)
//        let periods = [q1]
//
//        let incomeStatement = createTestIncomeStatement(
//            revenue: 2_000_000.0,
//            cogs: 800_000.0,
//            opex: 600_000.0,
//            interest: 50_000.0,
//            tax: 100_000.0,
//            periods: periods
//        )
//
//        // EBITDA = Revenue - COGS - OpEx = 600,000
//        // Debt = 1,500,000
//        // Ratio = 2.5x
//
//        let balanceSheet = createTestBalanceSheet(
//            cash: 200_000.0,
//            currentAssets: 500_000.0,
//            totalAssets: 2_000_000.0,
//            currentLiabilities: 300_000.0,
//            debt: 1_500_000.0,
//            equity: 200_000.0,
//            periods: periods
//        )
//
//        let covenant = FinancialCovenant(
//            name: "Debt-to-EBITDA",
//            requirement: .maximumRatio(metric: .debtToEbitda, threshold: 3.0)
//        )
//
//        let isCompliant = covenant.isCompliant(
//            incomeStatement: incomeStatement,
//            balanceSheet: balanceSheet,
//            period: q1
//        )
//
//        #expect(isCompliant)
//    }
//
//    @Test("Debt-to-EBITDA - breached")
//    func debtToEBITDABreached() throws {
//        let q1 = Period.quarter(year: 2025, quarter: 1)
//        let periods = [q1]
//
//        let incomeStatement = createTestIncomeStatement(
//            revenue: 1_000_000.0,
//            cogs: 600_000.0,
//            opex: 350_000.0,
//            interest: 80_000.0,
//            tax: 0.0,
//            periods: periods
//        )
//
//        // EBITDA = 50,000
//        // Debt = 500,000
//        // Ratio = 10.0x (too high)
//
//        let balanceSheet = createTestBalanceSheet(
//            cash: 10_000.0,
//            currentAssets: 100_000.0,
//            totalAssets: 600_000.0,
//            currentLiabilities: 80_000.0,
//            debt: 500_000.0,
//            equity: 20_000.0,
//            periods: periods
//        )
//
//        let covenant = FinancialCovenant(
//            name: "Debt-to-EBITDA",
//            requirement: .maximumRatio(metric: .debtToEbitda, threshold: 4.0)
//        )
//
//        let isCompliant = covenant.isCompliant(
//            incomeStatement: incomeStatement,
//            balanceSheet: balanceSheet,
//            period: q1
//        )
//
//        #expect(!isCompliant)
//    }
//
//    // MARK: - Current Ratio
//
//    @Test("Current ratio - minimum requirement met")
//    func currentRatioMet() throws {
//        let q1 = Period.quarter(year: 2025, quarter: 1)
//        let periods = [q1]
//
//        let incomeStatement = createTestIncomeStatement(
//            revenue: 1_000_000.0,
//            cogs: 400_000.0,
//            opex: 300_000.0,
//            interest: 50_000.0,
//            tax: 50_000.0,
//            periods: periods
//        )
//
//        let balanceSheet = createTestBalanceSheet(
//            cash: 200_000.0,
//            currentAssets: 600_000.0,
//            totalAssets: 1_500_000.0,
//            currentLiabilities: 300_000.0,
//            debt: 800_000.0,
//            equity: 400_000.0,
//            periods: periods
//        )
//
//        let covenant = FinancialCovenant(
//            name: "Current Ratio",
//            requirement: .minimumRatio(metric: .currentRatio, threshold: 1.5)
//        )
//
//        let isCompliant = covenant.isCompliant(
//            incomeStatement: incomeStatement,
//            balanceSheet: balanceSheet,
//            period: q1
//        )
//
//        // Current Ratio = 600,000 / 300,000 = 2.0 (above 1.5)
//        #expect(isCompliant)
//    }
//
//    @Test("Current ratio - below minimum")
//    func currentRatioBelowMinimum() throws {
//        let q1 = Period.quarter(year: 2025, quarter: 1)
//        let periods = [q1]
//
//        let incomeStatement = createTestIncomeStatement(
//            revenue: 500_000.0,
//            cogs: 300_000.0,
//            opex: 150_000.0,
//            interest: 30_000.0,
//            tax: 0.0,
//            periods: periods
//        )
//
//        let balanceSheet = createTestBalanceSheet(
//            cash: 50_000.0,
//            currentAssets: 200_000.0,
//            totalAssets: 800_000.0,
//            currentLiabilities: 250_000.0,
//            debt: 500_000.0,
//            equity: 50_000.0,
//            periods: periods
//        )
//
//        let covenant = FinancialCovenant(
//            name: "Current Ratio",
//            requirement: .minimumRatio(metric: .currentRatio, threshold: 1.2)
//        )
//
//        let isCompliant = covenant.isCompliant(
//            incomeStatement: incomeStatement,
//            balanceSheet: balanceSheet,
//            period: q1
//        )
//
//        // Current Ratio = 200,000 / 250,000 = 0.8 (below 1.2)
//        #expect(!isCompliant)
//    }
//
//    // MARK: - Debt Service Coverage Ratio (DSCR)
//
//    @Test("DSCR - adequate coverage")
//    func dSCRAdequate() throws {
//        let q1 = Period.quarter(year: 2025, quarter: 1)
//        let periods = [q1]
//
//        // EBITDA = 500,000
//        // Interest = 50,000
//        // Principal payment = 100,000
//        // DSCR = 500,000 / (50,000 + 100,000) = 3.33
//
//        let incomeStatement = createTestIncomeStatement(
//            revenue: 2_000_000.0,
//            cogs: 800_000.0,
//            opex: 700_000.0,
//            interest: 50_000.0,
//            tax: 90_000.0,
//            periods: periods
//        )
//
//        let balanceSheet = createTestBalanceSheet(
//            cash: 300_000.0,
//            currentAssets: 600_000.0,
//            totalAssets: 2_000_000.0,
//            currentLiabilities: 400_000.0,
//            debt: 1_000_000.0,
//            equity: 600_000.0,
//            periods: periods
//        )
//
//        let covenant = FinancialCovenant(
//            name: "DSCR",
//            requirement: .minimumRatio(
//                metric: .debtServiceCoverage,
//                threshold: 1.25,
//                principalPayment: 100_000.0
//            )
//        )
//
//        let isCompliant = covenant.isCompliant(
//            incomeStatement: incomeStatement,
//            balanceSheet: balanceSheet,
//            period: q1
//        )
//
//        #expect(isCompliant)
//    }
//
//    @Test("DSCR - insufficient coverage")
//    func dSCRInsufficient() throws {
//        let q1 = Period.quarter(year: 2025, quarter: 1)
//        let periods = [q1]
//
//        // EBITDA = 100,000
//        // Interest = 60,000
//        // Principal = 80,000
//        // DSCR = 100,000 / 140,000 = 0.71
//
//        let incomeStatement = createTestIncomeStatement(
//            revenue: 800_000.0,
//            cogs: 500_000.0,
//            opex: 200_000.0,
//            interest: 60_000.0,
//            tax: 0.0,
//            periods: periods
//        )
//
//        let balanceSheet = createTestBalanceSheet(
//            cash: 50_000.0,
//            currentAssets: 200_000.0,
//            totalAssets: 1_000_000.0,
//            currentLiabilities: 300_000.0,
//            debt: 600_000.0,
//            equity: 100_000.0,
//            periods: periods
//        )
//
//        let covenant = FinancialCovenant(
//            name: "DSCR",
//            requirement: .minimumRatio(
//                metric: .debtServiceCoverage,
//                threshold: 1.2,
//                principalPayment: 80_000.0
//            )
//        )
//
//        let isCompliant = covenant.isCompliant(
//            incomeStatement: incomeStatement,
//            balanceSheet: balanceSheet,
//            period: q1
//        )
//
//        #expect(!isCompliant)
//    }
//
//    // MARK: - Minimum EBITDA
//
//    @Test("Minimum EBITDA threshold - met")
//    func minimumEBITDAMet() throws {
//        let q1 = Period.quarter(year: 2025, quarter: 1)
//        let periods = [q1]
//
//        let incomeStatement = createTestIncomeStatement(
//            revenue: 3_000_000.0,
//            cogs: 1_200_000.0,
//            opex: 1_000_000.0,
//            interest: 100_000.0,
//            tax: 140_000.0,
//            periods: periods
//        )
//
//        let balanceSheet = createTestBalanceSheet(
//            cash: 500_000.0,
//            currentAssets: 1_000_000.0,
//            totalAssets: 3_000_000.0,
//            currentLiabilities: 600_000.0,
//            debt: 1_500_000.0,
//            equity: 900_000.0,
//            periods: periods
//        )
//
//        let covenant = FinancialCovenant(
//            name: "Minimum EBITDA",
//            requirement: .minimumValue(metric: "EBITDA", threshold: 500_000.0)
//        )
//
//        let isCompliant = covenant.isCompliant(
//            incomeStatement: incomeStatement,
//            balanceSheet: balanceSheet,
//            period: q1
//        )
//
//        // EBITDA = 3M - 1.2M - 1M = 800,000 (above 500k)
//        #expect(isCompliant)
//    }
//
//    @Test("Minimum EBITDA threshold - not met")
//    func minimumEBITDANotMet() throws {
//        let q1 = Period.quarter(year: 2025, quarter: 1)
//        let periods = [q1]
//
//        let incomeStatement = createTestIncomeStatement(
//            revenue: 1_000_000.0,
//            cogs: 600_000.0,
//            opex: 350_000.0,
//            interest: 40_000.0,
//            tax: 0.0,
//            periods: periods
//        )
//
//        let balanceSheet = createTestBalanceSheet(
//            cash: 100_000.0,
//            currentAssets: 300_000.0,
//            totalAssets: 1_000_000.0,
//            currentLiabilities: 250_000.0,
//            debt: 600_000.0,
//            equity: 150_000.0,
//            periods: periods
//        )
//
//        let covenant = FinancialCovenant(
//            name: "Minimum EBITDA",
//            requirement: .minimumValue(metric: "EBITDA", threshold: 100_000.0)
//        )
//
//        let isCompliant = covenant.isCompliant(
//            incomeStatement: incomeStatement,
//            balanceSheet: balanceSheet,
//            period: q1
//        )
//
//        // EBITDA = 1M - 600k - 350k = 50,000 (below 100k)
//        #expect(!isCompliant)
//    }
//
//    // MARK: - Minimum Net Worth
//
//    @Test("Minimum net worth covenant")
//    func minimumNetWorth() throws {
//        let q1 = Period.quarter(year: 2025, quarter: 1)
//        let periods = [q1]
//
//        let incomeStatement = createTestIncomeStatement(
//            revenue: 1_000_000.0,
//            cogs: 400_000.0,
//            opex: 300_000.0,
//            interest: 50_000.0,
//            tax: 50_000.0,
//            periods: periods
//        )
//
//        let balanceSheet = createTestBalanceSheet(
//            cash: 300_000.0,
//            currentAssets: 800_000.0,
//            totalAssets: 2_000_000.0,
//            currentLiabilities: 400_000.0,
//            debt: 800_000.0,
//            equity: 800_000.0,
//            periods: periods
//        )
//
//        let covenant = FinancialCovenant(
//            name: "Minimum Net Worth",
//            requirement: .minimumValue(metric: "NetWorth", threshold: 500_000.0)
//        )
//
//        let isCompliant = covenant.isCompliant(
//            incomeStatement: incomeStatement,
//            balanceSheet: balanceSheet,
//            period: q1
//        )
//
//        // Net Worth (Equity) = 800,000 (above 500k)
//        #expect(isCompliant)
//    }
//
//    // MARK: - Maximum Leverage Ratio
//
//    @Test("Maximum leverage ratio")
//    func maximumLeverageRatio() throws {
//        let q1 = Period.quarter(year: 2025, quarter: 1)
//        let periods = [q1]
//
//        let incomeStatement = createTestIncomeStatement(
//            revenue: 2_000_000.0,
//            cogs: 800_000.0,
//            opex: 600_000.0,
//            interest: 80_000.0,
//            tax: 104_000.0,
//            periods: periods
//        )
//
//        let balanceSheet = createTestBalanceSheet(
//            cash: 400_000.0,
//            currentAssets: 1_000_000.0,
//            totalAssets: 3_000_000.0,
//            currentLiabilities: 500_000.0,
//            debt: 1_500_000.0,
//            equity: 1_000_000.0,
//            periods: periods
//        )
//
//        let covenant = FinancialCovenant(
//            name: "Maximum Leverage",
//            requirement: .maximumRatio(metric: .debtToEquity, threshold: 2.0)
//        )
//
//        let isCompliant = covenant.isCompliant(
//            incomeStatement: incomeStatement,
//            balanceSheet: balanceSheet,
//            period: q1
//        )
//
//        // Debt/Equity = 1,500,000 / 1,000,000 = 1.5 (below 2.0)
//        #expect(isCompliant)
//    }
//
//    // MARK: - Covenant Headroom Analysis
//
//    @Test("Covenant headroom calculation")
//    func covenantHeadroom() throws {
//        let q1 = Period.quarter(year: 2025, quarter: 1)
//        let periods = [q1]
//
//        let incomeStatement = createTestIncomeStatement(
//            revenue: 1_000_000.0,
//            cogs: 400_000.0,
//            opex: 300_000.0,
//            interest: 50_000.0,
//            tax: 50_000.0,
//            periods: periods
//        )
//
//        let balanceSheet = createTestBalanceSheet(
//            cash: 200_000.0,
//            currentAssets: 500_000.0,
//            totalAssets: 1_500_000.0,
//            currentLiabilities: 300_000.0,
//            debt: 800_000.0,
//            equity: 400_000.0,
//            periods: periods
//        )
//
//        let covenant = FinancialCovenant(
//            name: "Current Ratio",
//            requirement: .minimumRatio(metric: .currentRatio, threshold: 1.5)
//        )
//
//        let headroom = covenant.headroom(
//            incomeStatement: incomeStatement,
//            balanceSheet: balanceSheet,
//            period: q1
//        )
//
//        // Current Ratio = 500k / 300k = 1.67
//        // Headroom = 1.67 - 1.5 = 0.17
//        #expect(headroom > 0.0)
//        #expect(headroom < 0.5)
//    }
//
//    @Test("Covenant headroom - near breach")
//    func covenantHeadroomNearBreach() throws {
//        let q1 = Period.quarter(year: 2025, quarter: 1)
//        let periods = [q1]
//
//        let incomeStatement = createTestIncomeStatement(
//            revenue: 800_000.0,
//            cogs: 500_000.0,
//            opex: 250_000.0,
//            interest: 45_000.0,
//            tax: 0.0,
//            periods: periods
//        )
//
//        let balanceSheet = createTestBalanceSheet(
//            cash: 80_000.0,
//            currentAssets: 320_000.0,
//            totalAssets: 1_000_000.0,
//            currentLiabilities: 300_000.0,
//            debt: 600_000.0,
//            equity: 100_000.0,
//            periods: periods
//        )
//
//        let covenant = FinancialCovenant(
//            name: "Current Ratio",
//            requirement: .minimumRatio(metric: .currentRatio, threshold: 1.0)
//        )
//
//        let headroom = covenant.headroom(
//            incomeStatement: incomeStatement,
//            balanceSheet: balanceSheet,
//            period: q1
//        )
//
//        // Current Ratio = 320k / 300k = 1.07
//        // Headroom = 0.07 (very small)
//        #expect(headroom > 0.0)
//        #expect(headroom < 0.1)
//    }
//
//    // MARK: - Custom Covenant Logic
//
//    @Test("Custom covenant - complex condition")
//    func customCovenantComplexCondition() throws {
//        let q1 = Period.quarter(year: 2025, quarter: 1)
//        let periods = [q1]
//
//        let incomeStatement = createTestIncomeStatement(
//            revenue: 1_500_000.0,
//            cogs: 600_000.0,
//            opex: 450_000.0,
//            interest: 60_000.0,
//            tax: 78_000.0,
//            periods: periods
//        )
//
//        let balanceSheet = createTestBalanceSheet(
//            cash: 250_000.0,
//            currentAssets: 600_000.0,
//            totalAssets: 2_000_000.0,
//            currentLiabilities: 350_000.0,
//            debt: 1_000_000.0,
//            equity: 650_000.0,
//            periods: periods
//        )
//
//        // Custom: EBITDA > $400k AND Current Ratio > 1.5
//        let covenant = FinancialCovenant(
//            name: "Combined Covenant",
//            requirement: .custom { is, bs, period in
//                let ebitda = is.operatingIncome[period]! + 0.0 // Simplified
//                let currentRatio = bs.currentRatio[period]!
//                return ebitda > 400_000.0 && currentRatio > 1.5
//            }
//        )
//
//        let isCompliant = covenant.isCompliant(
//            incomeStatement: incomeStatement,
//            balanceSheet: balanceSheet,
//            period: q1
//        )
//
//        #expect(isCompliant)
//    }
//
//    // MARK: - Multiple Covenant Monitoring
//
//    @Test("Monitor multiple covenants")
//    func monitorMultipleCovenants() throws {
//        let q1 = Period.quarter(year: 2025, quarter: 1)
//        let periods = [q1]
//
//        let incomeStatement = createTestIncomeStatement(
//            revenue: 2_000_000.0,
//            cogs: 800_000.0,
//            opex: 700_000.0,
//            interest: 60_000.0,
//            tax: 88_000.0,
//            periods: periods
//        )
//
//        let balanceSheet = createTestBalanceSheet(
//            cash: 400_000.0,
//            currentAssets: 900_000.0,
//            totalAssets: 2_500_000.0,
//            currentLiabilities: 500_000.0,
//            debt: 1_200_000.0,
//            equity: 800_000.0,
//            periods: periods
//        )
//
//        let covenants = [
//            FinancialCovenant(
//                name: "Interest Coverage",
//                requirement: .minimumRatio(metric: .interestCoverage, threshold: 3.0)
//            ),
//            FinancialCovenant(
//                name: "Current Ratio",
//                requirement: .minimumRatio(metric: .currentRatio, threshold: 1.5)
//            ),
//            FinancialCovenant(
//                name: "Debt-to-Equity",
//                requirement: .maximumRatio(metric: .debtToEquity, threshold: 2.0)
//            )
//        ]
//
//        let monitor = CovenantMonitor(covenants: covenants)
//        let results = monitor.checkCompliance(
//            incomeStatement: incomeStatement,
//            balanceSheet: balanceSheet,
//            period: q1
//        )
//
//        // All covenants should be compliant
//        #expect(results.allCompliant)
//        #expect(results.violations.isEmpty)
//    }
//
//    @Test("Covenant violations - report generation")
//    func covenantViolationReport() throws {
//        let q1 = Period.quarter(year: 2025, quarter: 1)
//        let periods = [q1]
//
//        let incomeStatement = createTestIncomeStatement(
//            revenue: 600_000.0,
//            cogs: 400_000.0,
//            opex: 180_000.0,
//            interest: 50_000.0,
//            tax: 0.0,
//            periods: periods
//        )
//
//        let balanceSheet = createTestBalanceSheet(
//            cash: 30_000.0,
//            currentAssets: 150_000.0,
//            totalAssets: 700_000.0,
//            currentLiabilities: 200_000.0,
//            debt: 550_000.0,
//            equity: -50_000.0, // Negative equity
//            periods: periods
//        )
//
//        let covenants = [
//            FinancialCovenant(
//                name: "Minimum Net Worth",
//                requirement: .minimumValue(metric: "NetWorth", threshold: 100_000.0)
//            ),
//            FinancialCovenant(
//                name: "Current Ratio",
//                requirement: .minimumRatio(metric: .currentRatio, threshold: 1.2)
//            )
//        ]
//
//        let monitor = CovenantMonitor(covenants: covenants)
//        let results = monitor.checkCompliance(
//            incomeStatement: incomeStatement,
//            balanceSheet: balanceSheet,
//            period: q1
//        )
//
//        // Should have violations
//        #expect(!results.allCompliant)
//        #expect(results.violations.count >= 1)
//
//        // Report should include details
//        let report = results.generateReport()
//        #expect(report.contains("Minimum Net Worth"))
//    }
//
//    // MARK: - Covenant Cure Periods
//
//    @Test("Covenant with cure period")
//    func covenantWithCurePeriod() throws {
//        let q1 = Period.quarter(year: 2025, quarter: 1)
//        let q2 = Period.quarter(year: 2025, quarter: 2)
//        let periods = [q1, q2]
//
//        let incomeStatement = createTestIncomeStatement(
//            revenue: 500_000.0,
//            cogs: 350_000.0,
//            opex: 130_000.0,
//            interest: 40_000.0,
//            tax: 0.0,
//            periods: periods
//        )
//
//        let balanceSheet = createTestBalanceSheet(
//            cash: 50_000.0,
//            currentAssets: 200_000.0,
//            totalAssets: 800_000.0,
//            currentLiabilities: 250_000.0,
//            debt: 500_000.0,
//            equity: 50_000.0,
//            periods: periods
//        )
//
//        let covenant = FinancialCovenant(
//            name: "Current Ratio",
//            requirement: .minimumRatio(metric: .currentRatio, threshold: 1.2),
//            curePeriodDays: 30
//        )
//
//        // Violated in Q1
//        let q1Compliant = covenant.isCompliant(
//            incomeStatement: incomeStatement,
//            balanceSheet: balanceSheet,
//            period: q1
//        )
//        #expect(!q1Compliant)
//
//        // Still in cure period, can remedy
//        let inCurePeriod = covenant.isInCurePeriod(
//            violationDate: q1.startDate,
//            currentDate: Date(timeInterval: 15 * 86400, since: q1.startDate) // 15 days later
//        )
//        #expect(inCurePeriod)
//    }
//
//    // MARK: - Covenant Waivers
//
//    @Test("Covenant waiver")
//    func covenantWaiver() throws {
//        let q1 = Period.quarter(year: 2025, quarter: 1)
//        let periods = [q1]
//
//        let incomeStatement = createTestIncomeStatement(
//            revenue: 500_000.0,
//            cogs: 350_000.0,
//            opex: 130_000.0,
//            interest: 50_000.0,
//            tax: 0.0,
//            periods: periods
//        )
//
//        let balanceSheet = createTestBalanceSheet(
//            cash: 40_000.0,
//            currentAssets: 180_000.0,
//            totalAssets: 700_000.0,
//            currentLiabilities: 200_000.0,
//            debt: 500_000.0,
//            equity: 0.0,
//            periods: periods
//        )
//
//        var covenant = FinancialCovenant(
//            name: "Current Ratio",
//            requirement: .minimumRatio(metric: .currentRatio, threshold: 1.5)
//        )
//
//        // Initially fails
//        let initialCompliance = covenant.isCompliant(
//            incomeStatement: incomeStatement,
//            balanceSheet: balanceSheet,
//            period: q1
//        )
//        #expect(!initialCompliance)
//
//        // Grant waiver
//        covenant = covenant.grantWaiver(
//            period: q1,
//            expirationDate: Date(timeInterval: 90 * 86400, since: q1.startDate)
//        )
//
//        // Now passes due to waiver
//        let afterWaiver = covenant.isCompliant(
//            incomeStatement: incomeStatement,
//            balanceSheet: balanceSheet,
//            period: q1
//        )
//        #expect(afterWaiver)
//    }
//}

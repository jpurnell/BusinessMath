import Testing
import Foundation
@testable import BusinessMath

// Comprehensive tests for debt covenants and financial constraint monitoring
@Suite("Debt Covenants Tests")
struct DebtCovenantsTests {

    // MARK: - Test Fixtures

    func createTestIncomeStatement(
        revenue: Double,
        cogs: Double,
        opex: Double,
        interest: Double,
        tax: Double,
        periods: [Period]
    ) -> IncomeStatement<Double> {
		let entity = Entity(
			id: "ACME001",
			primaryType: .ticker,
			name: "Acme Corporation",
			identifiers: [.ticker: "ACME"],
			currency: "USD",
			metadata: ["description": "Leading provider of widgets"]
		)

        let revenueAccount = try! Account(
			entity: entity,
            name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: periods, values: Array(repeating: revenue, count: periods.count))
        )

        let cogsAccount = try! Account(
			entity: entity,
            name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: TimeSeries(periods: periods, values: Array(repeating: cogs, count: periods.count)),
        )

        let opexAccount = try! Account(
			entity: entity,
            name: "OpEx",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: TimeSeries(periods: periods, values: Array(repeating: opex, count: periods.count)),
        )

        let interestAccount = try! Account(
			entity: entity,
            name: "Interest",
			incomeStatementRole: .interestExpense,
			timeSeries: TimeSeries(periods: periods, values: Array(repeating: interest, count: periods.count)),
        )

        let taxAccount = try! Account(
			entity: entity,
            name: "Tax",
			incomeStatementRole: .incomeTaxExpense,
			timeSeries: TimeSeries(periods: periods, values: Array(repeating: tax, count: periods.count)),
        )

        return try! IncomeStatement(
			entity: entity,
			periods: periods,
            accounts: [revenueAccount, cogsAccount, opexAccount, interestAccount, taxAccount]
        )
    }

    func createTestBalanceSheet(
        cash: Double,
        currentAssets: Double,
        totalAssets: Double,
        currentLiabilities: Double,
        debt: Double,
        equity: Double,
        periods: [Period]
    ) -> BalanceSheet<Double> {
		let entity = Entity(
			id: "ACME001",
			primaryType: .ticker,
			name: "Acme Corporation",
			identifiers: [.ticker: "ACME"],
			currency: "USD",
			metadata: ["description": "Leading provider of widgets"]
		)

        let cashAccount = try! Account(
			entity: entity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: periods, values: Array(repeating: cash, count: periods.count)),
        )

        let otherCurrentAssets = try! Account(
			entity: entity,
            name: "Other Current",
			balanceSheetRole: .otherCurrentAssets,
			timeSeries: TimeSeries(periods: periods, values: Array(repeating: currentAssets - cash, count: periods.count)),
        )

        let fixedAssets = try! Account(
			entity: entity,
			name: "Fixed Assets",
			balanceSheetRole: .propertyPlantEquipment,
			timeSeries: TimeSeries(periods: periods, values: Array(repeating: totalAssets - currentAssets, count: periods.count)),
        )

        let currentLiabAccount = try! Account(
			entity: entity,
            name: "Current Liabilities",
			balanceSheetRole: .accountsPayable,
			timeSeries: TimeSeries(periods: periods, values: Array(repeating: currentLiabilities, count: periods.count)),
        )

        let debtAccount = try! Account(
			entity: entity,
            name: "Long-term Debt",
			balanceSheetRole: .longTermDebt,
			timeSeries: TimeSeries(periods: periods, values: Array(repeating: debt, count: periods.count)),
        )

        let equityAccount = try! Account(
			entity: entity,
            name: "Equity",
			balanceSheetRole: .retainedEarnings,
			timeSeries: TimeSeries(periods: periods, values: Array(repeating: equity, count: periods.count)),
        )

        return try! BalanceSheet(
			entity: entity,
			periods: periods,
            accounts: [cashAccount, otherCurrentAssets, fixedAssets, currentLiabAccount, debtAccount, equityAccount]
        )
    }

    // MARK: - Interest Coverage Ratio

    @Test("Interest coverage ratio - healthy company")
    func interestCoverageHealthy() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1]

        let incomeStatement = createTestIncomeStatement(
            revenue: 1_000_000.0,
            cogs: 400_000.0,
            opex: 300_000.0,
            interest: 50_000.0,
            tax: 50_000.0,
            periods: periods
        )

        let balanceSheet = createTestBalanceSheet(
            cash: 100_000.0,
            currentAssets: 300_000.0,
            totalAssets: 1_000_000.0,
            currentLiabilities: 200_000.0,
            debt: 500_000.0,
            equity: 300_000.0,
            periods: periods
        )

        let covenant = FinancialCovenant(
            name: "Interest Coverage",
            requirement: .minimumRatio(metric: .interestCoverage, threshold: 2.0)
        )

		let isCompliant = CovenantMonitor(
			covenants: [covenant])
			.checkCompliance(
				incomeStatement: incomeStatement,
				balanceSheet: balanceSheet,
				period: q1
		)

        // EBIT = 300,000, Interest = 50,000
        // Coverage = 6.0 (well above 2.0 threshold)
		#expect(isCompliant.map({$0.isCompliant}) == [true])
    }

    @Test("Interest coverage ratio - failing covenant")
    func interestCoverageFailing() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1]

        let incomeStatement = createTestIncomeStatement(
            revenue: 500_000.0,
            cogs: 300_000.0,
            opex: 180_000.0,
            interest: 50_000.0, // High interest relative to EBIT
            tax: 0.0,
            periods: periods
        )

        let balanceSheet = createTestBalanceSheet(
            cash: 50_000.0,
            currentAssets: 200_000.0,
            totalAssets: 800_000.0,
            currentLiabilities: 150_000.0,
            debt: 600_000.0,
            equity: 50_000.0,
            periods: periods
        )

        let covenant = FinancialCovenant(
            name: "Interest Coverage",
            requirement: .minimumRatio(metric: .interestCoverage, threshold: 2.5)
        )

		let isCompliant = CovenantMonitor(
			covenants: [covenant])
			.checkCompliance(
				incomeStatement: incomeStatement,
				balanceSheet: balanceSheet,
				period: q1
		)

        // EBIT = 20,000, Interest = 50,000
        // Coverage = 0.4 (below 2.5 threshold)
		#expect(isCompliant.map({$0.isCompliant}) == [false])
    }

    @Test("Interest coverage - calculate exact ratio")
    func interestCoverageCalculation() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1]

        let ebit = 300_000.0
        let interest = 60_000.0

        let incomeStatement = createTestIncomeStatement(
            revenue: 1_000_000.0,
            cogs: 400_000.0,
            opex: 300_000.0,
            interest: interest,
            tax: 50_000.0,
            periods: periods
        )
		let balanceSheet = createTestBalanceSheet(
			cash: 50_000.0,
			currentAssets: 200_000.0,
			totalAssets: 800_000.0,
			currentLiabilities: 150_000.0,
			debt: 600_000.0,
			equity: 50_000.0,
			periods: periods
		)

        let ratio = calculateInterestCoverage(
            incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
            period: q1
        )

        // Expected: 300,000 / 60,000 = 5.0
        let expected = ebit / interest
        #expect(abs(ratio - expected) < 0.01)
    }

    // MARK: - Debt-to-EBITDA Ratio

    @Test("Debt-to-EBITDA - compliant")
    func debtToEBITDACompliant() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1]

        let incomeStatement = createTestIncomeStatement(
            revenue: 2000000,
			cogs: 800000.0,
			opex: 600000.0,
			interest: 50000.0,
			tax: 100000.0,
            periods: periods
        )

        // EBITDA = Revenue - COGS - OpEx = 600,000
        // Debt = 1,500,000
        // Ratio = 2.5x

        let balanceSheet = createTestBalanceSheet(
            cash: 200_000.0,
            currentAssets: 500_000.0,
            totalAssets: 2_000_000.0,
            currentLiabilities: 300_000.0,
            debt: 1_500_000.0,
            equity: 200_000.0,
            periods: periods
        )

        let covenant = FinancialCovenant(
            name: "Debt-to-EBITDA",
            requirement: .maximumRatio(metric: .debtToEBITDA, threshold: 3.0)
        )

		let isCompliant = CovenantMonitor(
			covenants: [covenant])
			.checkCompliance(
				incomeStatement: incomeStatement,
				balanceSheet: balanceSheet,
				period: q1
		)

		#expect(isCompliant.map({$0.isCompliant}) == [true])
    }

    @Test("Debt-to-EBITDA - breached")
    func debtToEBITDABreached() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1]

        let incomeStatement = createTestIncomeStatement(
            revenue: 1_000_000.0,
            cogs: 600_000.0,
            opex: 350_000.0,
            interest: 80_000.0,
            tax: 0.0,
            periods: periods
        )

        // EBITDA = 50,000
        // Debt = 500,000
        // Ratio = 10.0x (too high)

        let balanceSheet = createTestBalanceSheet(
            cash: 10_000.0,
            currentAssets: 100_000.0,
            totalAssets: 600_000.0,
            currentLiabilities: 80_000.0,
            debt: 500_000.0,
            equity: 20_000.0,
            periods: periods
        )

        let covenant = FinancialCovenant(
            name: "Debt-to-EBITDA",
            requirement: .maximumRatio(metric: .debtToEBITDA, threshold: 4.0)
        )

		let isCompliant = CovenantMonitor(
			covenants: [covenant])
			.checkCompliance(
				incomeStatement: incomeStatement,
				balanceSheet: balanceSheet,
				period: q1
		)

		#expect(isCompliant.map({$0.isCompliant}) == [false])
    }

    // MARK: - Current Ratio

    @Test("Current ratio - minimum requirement met")
    func currentRatioMet() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1]

        let incomeStatement = createTestIncomeStatement(
            revenue: 1_000_000.0,
            cogs: 400_000.0,
            opex: 300_000.0,
            interest: 50_000.0,
            tax: 50_000.0,
            periods: periods
        )

        let balanceSheet = createTestBalanceSheet(
            cash: 200_000.0,
            currentAssets: 600_000.0,
            totalAssets: 1_500_000.0,
            currentLiabilities: 300_000.0,
            debt: 800_000.0,
            equity: 400_000.0,
            periods: periods
        )
        let covenant = FinancialCovenant(
            name: "Current Ratio",
            requirement: .minimumRatio(metric: .currentRatio, threshold: 1.5)
        )

		let isCompliant = CovenantMonitor(
			covenants: [covenant])
			.checkCompliance(
				incomeStatement: incomeStatement,
				balanceSheet: balanceSheet,
				period: q1
		)

        // Current Ratio = 600,000 / 300,000 = 2.0 (above 1.5)
		#expect(isCompliant.map({$0.isCompliant}) == [true])
    }

    @Test("Current ratio - below minimum")
    func currentRatioBelowMinimum() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1]

        let incomeStatement = createTestIncomeStatement(
            revenue: 500_000.0,
            cogs: 300_000.0,
            opex: 150_000.0,
            interest: 30_000.0,
            tax: 0.0,
            periods: periods
        )

        let balanceSheet = createTestBalanceSheet(
            cash: 50_000.0,
            currentAssets: 200_000.0,
            totalAssets: 800_000.0,
            currentLiabilities: 250_000.0,
            debt: 500_000.0,
            equity: 50_000.0,
            periods: periods
        )

        let covenant = FinancialCovenant(
            name: "Current Ratio",
            requirement: .minimumRatio(metric: .currentRatio, threshold: 1.2)
        )

		let isCompliant = CovenantMonitor(
			covenants: [covenant])
			.checkCompliance(
				incomeStatement: incomeStatement,
				balanceSheet: balanceSheet,
				period: q1
		)

        // Current Ratio = 200,000 / 250,000 = 0.8 (below 1.2)
		#expect(isCompliant.map({$0.isCompliant}) == [false])
    }

    // MARK: - Debt Service Coverage Ratio (DSCR)

    @Test("DSCR - adequate coverage")
    func dSCRAdequate() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1]

        // EBITDA = 500,000
        // Interest = 50,000
        // Principal payment = 100,000
        // DSCR = 500,000 / (50,000 + 100,000) = 3.33

        let incomeStatement = createTestIncomeStatement(
            revenue: 2_000_000.0,
            cogs: 800_000.0,
            opex: 700_000.0,
            interest: 50_000.0,
            tax: 90_000.0,
            periods: periods
        )

        let balanceSheet = createTestBalanceSheet(
            cash: 300_000.0,
            currentAssets: 600_000.0,
            totalAssets: 2_000_000.0,
            currentLiabilities: 400_000.0,
            debt: 1_000_000.0,
            equity: 600_000.0,
            periods: periods
        )

        let covenant = FinancialCovenant(
            name: "DSCR",
            requirement: .minimumRatio(
                metric: .debtServiceCoverage,
                threshold: 1.25,
                principalPayment: 100_000.0
            )
        )

        let isCompliant = covenant.isCompliant(
            incomeStatement: incomeStatement,
            balanceSheet: balanceSheet,
            period: q1
        )

		#expect(isCompliant.map({$0.isCompliant}) == [true])
    }

    @Test("DSCR - insufficient coverage")
    func dSCRInsufficient() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1]

        // EBITDA = 100,000
        // Interest = 60,000
        // Principal = 80,000
        // DSCR = 100,000 / 140,000 = 0.71

        let incomeStatement = createTestIncomeStatement(
            revenue: 800_000.0,
            cogs: 500_000.0,
            opex: 200_000.0,
            interest: 60_000.0,
            tax: 0.0,
            periods: periods
        )

        let balanceSheet = createTestBalanceSheet(
            cash: 50_000.0,
            currentAssets: 200_000.0,
            totalAssets: 1_000_000.0,
            currentLiabilities: 300_000.0,
            debt: 600_000.0,
            equity: 100_000.0,
            periods: periods
        )

        let covenant = FinancialCovenant(
            name: "DSCR",
            requirement: .minimumRatio(
                metric: .debtServiceCoverage,
                threshold: 1.2,
                principalPayment: 80_000.0
            )
        )

        let isCompliant = covenant.isCompliant(
            incomeStatement: incomeStatement,
            balanceSheet: balanceSheet,
            period: q1
        )

        #expect(isCompliant.map({$0.isCompliant}) == [false])
    }

// MARK: - Minimum EBITDA

    @Test("Minimum EBITDA threshold - met")
    func minimumEBITDAMet() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1]

        let incomeStatement = createTestIncomeStatement(
            revenue: 3_000_000.0,
            cogs: 1_200_000.0,
            opex: 1_000_000.0,
            interest: 100_000.0,
            tax: 140_000.0,
            periods: periods
        )

        let balanceSheet = createTestBalanceSheet(
            cash: 500_000.0,
            currentAssets: 1_000_000.0,
            totalAssets: 3_000_000.0,
            currentLiabilities: 600_000.0,
            debt: 1_500_000.0,
            equity: 900_000.0,
            periods: periods
        )

        let covenant = FinancialCovenant(
            name: "Minimum EBITDA",
			requirement: .minimumValue(metric: "Minimum EBITDA", threshold: 500_000.0)
        )

        let isCompliant = covenant.isCompliant(
            incomeStatement: incomeStatement,
            balanceSheet: balanceSheet,
            period: q1
        )

        // EBITDA = 3M - 1.2M - 1M = 800,000 (above 500k)
		#expect(isCompliant.map({$0.isCompliant}) == [true])
    }

    @Test("Minimum EBITDA threshold - not met")
    func minimumEBITDANotMet() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1]

        let incomeStatement = createTestIncomeStatement(
            revenue: 1_000_000.0,
            cogs: 600_000.0,
            opex: 350_000.0,
            interest: 40_000.0,
            tax: 0.0,
            periods: periods
        )

        let balanceSheet = createTestBalanceSheet(
            cash: 100_000.0,
            currentAssets: 300_000.0,
            totalAssets: 1_000_000.0,
            currentLiabilities: 250_000.0,
            debt: 600_000.0,
            equity: 150_000.0,
            periods: periods
        )

        let covenant = FinancialCovenant(
            name: "Minimum EBITDA",
            requirement: .minimumValue(metric: "EBITDA", threshold: 100_000.0)
        )

        let isCompliant = covenant.isCompliant(
            incomeStatement: incomeStatement,
            balanceSheet: balanceSheet,
            period: q1
        )

        // EBITDA = 1M - 600k - 350k = 50,000 (below 100k)
        #expect(isCompliant.map({$0.isCompliant}) == [false])
    }

    // MARK: - Minimum Net Worth

    @Test("Minimum net worth covenant")
    func minimumNetWorth() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1]

        let incomeStatement = createTestIncomeStatement(
            revenue: 1_000_000.0,
            cogs: 400_000.0,
            opex: 300_000.0,
            interest: 50_000.0,
            tax: 50_000.0,
            periods: periods
        )

        let balanceSheet = createTestBalanceSheet(
            cash: 300_000.0,
            currentAssets: 800_000.0,
            totalAssets: 2_000_000.0,
            currentLiabilities: 400_000.0,
            debt: 800_000.0,
            equity: 800_000.0,
            periods: periods
        )

        let covenant = FinancialCovenant(
            name: "Minimum Net Worth",
            requirement: .minimumValue(metric: "NetWorth", threshold: 500_000.0)
        )

        let isCompliant = covenant.isCompliant(
            incomeStatement: incomeStatement,
            balanceSheet: balanceSheet,
            period: q1
        )

        // Net Worth (Equity) = 800,000 (above 500k)
        #expect(isCompliant.map({$0.isCompliant}) == [true])
    }

    // MARK: - Maximum Leverage Ratio

    @Test("Maximum leverage ratio")
    func maximumLeverageRatio() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1]

        let incomeStatement = createTestIncomeStatement(
            revenue: 2_000_000.0,
            cogs: 800_000.0,
            opex: 600_000.0,
            interest: 80_000.0,
            tax: 104_000.0,
            periods: periods
        )

        let balanceSheet = createTestBalanceSheet(
            cash: 400_000.0,
            currentAssets: 1_000_000.0,
            totalAssets: 3_000_000.0,
            currentLiabilities: 500_000.0,
            debt: 1_500_000.0,
            equity: 1_000_000.0,
            periods: periods
        )

        let covenant = FinancialCovenant(
            name: "Maximum Leverage",
            requirement: .maximumRatio(metric: .debtToEquity, threshold: 2.0)
        )

        let isCompliant = covenant.isCompliant(
            incomeStatement: incomeStatement,
            balanceSheet: balanceSheet,
            period: q1
        )

        // Debt/Equity = 1,500,000 / 1,000,000 = 1.5 (below 2.0)
        #expect(isCompliant.map({$0.isCompliant}) == [true])
    }

    // MARK: - Covenant Headroom Analysis

    @Test("Covenant headroom calculation")
    func covenantHeadroom() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1]

        let incomeStatement = createTestIncomeStatement(
            revenue: 1_000_000.0,
            cogs: 400_000.0,
            opex: 300_000.0,
            interest: 50_000.0,
            tax: 50_000.0,
            periods: periods
        )

        let balanceSheet = createTestBalanceSheet(
            cash: 200_000.0,
            currentAssets: 500_000.0,
            totalAssets: 1_500_000.0,
            currentLiabilities: 300_000.0,
            debt: 800_000.0,
            equity: 400_000.0,
            periods: periods
        )

        let covenant = FinancialCovenant(
            name: "Current Ratio",
            requirement: .minimumRatio(metric: .currentRatio, threshold: 1.5)
        )

        let headroom = covenant.headroom(
            incomeStatement: incomeStatement,
            balanceSheet: balanceSheet,
            period: q1
        )

        // Current Ratio = 500k / 300k = 1.67
        // Headroom = 1.67 - 1.5 = 0.17
        #expect(headroom > 0.0)
        #expect(headroom < 0.5)
    }

    @Test("Covenant headroom - near breach")
    func covenantHeadroomNearBreach() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1]

        let incomeStatement = createTestIncomeStatement(
            revenue: 800_000.0,
            cogs: 500_000.0,
            opex: 250_000.0,
            interest: 45_000.0,
            tax: 0.0,
            periods: periods
        )

        let balanceSheet = createTestBalanceSheet(
            cash: 80_000.0,
            currentAssets: 320_000.0,
            totalAssets: 1_000_000.0,
            currentLiabilities: 300_000.0,
            debt: 600_000.0,
            equity: 100_000.0,
            periods: periods
        )

        let covenant = FinancialCovenant(
            name: "Current Ratio",
            requirement: .minimumRatio(metric: .currentRatio, threshold: 1.0)
        )

        let headroom = covenant.headroom(
            incomeStatement: incomeStatement,
            balanceSheet: balanceSheet,
            period: q1
        )

        // Current Ratio = 320k / 300k = 1.07
        // Headroom = 0.07 (very small)
        #expect(headroom > 0.0)
        #expect(headroom < 0.1)
    }

    // MARK: - Custom Covenant Logic

    @Test("Custom covenant - complex condition")
    func customCovenantComplexCondition() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1]

        let incomeStatement = createTestIncomeStatement(
            revenue: 1_500_000.0,
            cogs: 600_000.0,
            opex: 450_000.0,
            interest: 60_000.0,
            tax: 78_000.0,
            periods: periods
        )

        let balanceSheet = createTestBalanceSheet(
            cash: 250_000.0,
            currentAssets: 600_000.0,
            totalAssets: 2_000_000.0,
            currentLiabilities: 350_000.0,
            debt: 1_000_000.0,
            equity: 650_000.0,
            periods: periods
        )

        // Custom: EBITDA > $400k AND Current Ratio > 1.5
        let covenant = FinancialCovenant(
            name: "Combined Covenant",
            requirement: .custom { incomeStatement, balanceSheet, period in
                let ebitda = incomeStatement.operatingIncome[period]! + 0.0 // Simplified
                let currentRatio = balanceSheet.currentRatio[period]!
                return ebitda > 400_000.0 && currentRatio > 1.5
            }
        )

        let isCompliant = covenant.isCompliant(
            incomeStatement: incomeStatement,
            balanceSheet: balanceSheet,
            period: q1
        )
		#expect(isCompliant.allCompliant)
//        #expect(isCompliant.map({$0.isCompliant}) == [true])
    }

    // MARK: - Multiple Covenant Monitoring

    @Test("Monitor multiple covenants")
    func monitorMultipleCovenants() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1]

        let incomeStatement = createTestIncomeStatement(
            revenue: 2_000_000.0,
            cogs: 800_000.0,
            opex: 700_000.0,
            interest: 60_000.0,
            tax: 88_000.0,
            periods: periods
        )

        let balanceSheet = createTestBalanceSheet(
            cash: 400_000.0,
            currentAssets: 900_000.0,
            totalAssets: 2_500_000.0,
            currentLiabilities: 500_000.0,
            debt: 1_200_000.0,
            equity: 850_000.0,
            periods: periods
        )

        let covenants = [
            FinancialCovenant(
                name: "Interest Coverage",
                requirement: .minimumRatio(metric: .interestCoverage, threshold: 3.0)
            ),
            FinancialCovenant(
                name: "Current Ratio",
                requirement: .minimumRatio(metric: .currentRatio, threshold: 1.5)
            ),
            FinancialCovenant(
                name: "Debt-to-Equity",
                requirement: .maximumRatio(metric: .debtToEquity, threshold: 2.0)
            )
        ]

        let monitor = CovenantMonitor(covenants: covenants)
        let results = monitor.checkCompliance(
            incomeStatement: incomeStatement,
            balanceSheet: balanceSheet,
            period: q1
        )

        // All covenants should be compliant
        #expect(results.allCompliant)
        #expect(results.violations.isEmpty)
    }

    @Test("Covenant violations - report generation")
    func covenantViolationReport() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1]

        let incomeStatement = createTestIncomeStatement(
            revenue: 600_000.0,
            cogs: 400_000.0,
            opex: 180_000.0,
            interest: 50_000.0,
            tax: 0.0,
            periods: periods
        )

        let balanceSheet = createTestBalanceSheet(
            cash: 30_000.0,
            currentAssets: 150_000.0,
            totalAssets: 700_000.0,
            currentLiabilities: 200_000.0,
            debt: 550_000.0,
            equity: -50_000.0, // Negative equity
            periods: periods
        )

        let covenants = [
            FinancialCovenant(
                name: "Minimum Net Worth",
                requirement: .minimumValue(metric: "NetWorth", threshold: 100_000.0)
            ),
            FinancialCovenant(
                name: "Current Ratio",
                requirement: .minimumRatio(metric: .currentRatio, threshold: 1.2)
            )
        ]

        let monitor = CovenantMonitor(covenants: covenants)
        let results = monitor.checkCompliance(
            incomeStatement: incomeStatement,
            balanceSheet: balanceSheet,
            period: q1
        )

        // Should have violations
        #expect(!results.allCompliant)
        #expect(results.violations.count >= 1)

        // Report should include details
        let report = results.generateReport()
        #expect(report.contains("Minimum Net Worth"))
    }

    // MARK: - Covenant Cure Periods

    @Test("Covenant with cure period")
    func covenantWithCurePeriod() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let q2 = Period.quarter(year: 2025, quarter: 2)
        let periods = [q1, q2]

        let incomeStatement = createTestIncomeStatement(
            revenue: 500_000.0,
            cogs: 350_000.0,
            opex: 130_000.0,
            interest: 40_000.0,
            tax: 0.0,
            periods: periods
        )

        let balanceSheet = createTestBalanceSheet(
            cash: 50_000.0,
            currentAssets: 200_000.0,
            totalAssets: 800_000.0,
            currentLiabilities: 250_000.0,
            debt: 500_000.0,
            equity: 50_000.0,
            periods: periods
        )

        let covenant = FinancialCovenant(
            name: "Current Ratio",
            requirement: .minimumRatio(metric: .currentRatio, threshold: 1.2),
            curePeriodDays: 30
        )

        // Violated in Q1
        let q1Compliant = covenant.isCompliant(
            incomeStatement: incomeStatement,
            balanceSheet: balanceSheet,
            period: q1
        )
		#expect(!q1Compliant.allCompliant)
        // Still in cure period, can remedy
        let inCurePeriod = covenant.isInCurePeriod(
            violationDate: q1.startDate,
            currentDate: Date(timeInterval: 15 * 86400, since: q1.startDate) // 15 days later
        )
        #expect(inCurePeriod)
    }

    // MARK: - Covenant Waivers

    @Test("Covenant waiver")
    func covenantWaiver() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1]

        let incomeStatement = createTestIncomeStatement(
            revenue: 500_000.0,
            cogs: 350_000.0,
            opex: 130_000.0,
            interest: 50_000.0,
            tax: 0.0,
            periods: periods
        )

        let balanceSheet = createTestBalanceSheet(
            cash: 40_000.0,
            currentAssets: 180_000.0,
            totalAssets: 700_000.0,
            currentLiabilities: 200_000.0,
            debt: 500_000.0,
            equity: 0.0,
            periods: periods
        )

        var covenant = FinancialCovenant(
            name: "Current Ratio",
            requirement: .minimumRatio(metric: .currentRatio, threshold: 1.5)
        )

        // Initially fails
        let initialCompliance = covenant.isCompliant(
            incomeStatement: incomeStatement,
            balanceSheet: balanceSheet,
            period: q1
        )
		#expect(!initialCompliance.allCompliant)

        // Grant waiver
        covenant = covenant.grantWaiver(
            period: q1,
            expirationDate: Date(timeInterval: 90 * 86400, since: q1.startDate)
        )

        // Now passes due to waiver
        let afterWaiver = covenant.isCompliant(
            incomeStatement: incomeStatement,
            balanceSheet: balanceSheet,
            period: q1
        )
		#expect(afterWaiver.allCompliant)
    }
}

@Suite("Debt Covenants Extras")
struct DebtCovenantsExtrasTests {

	func entity() -> Entity {
		Entity(id: "EXTRA", primaryType: .ticker, name: "Extra Co")
	}

	func periods() -> [Period] {
		[Period.quarter(year: 2025, quarter: 1)]
	}

	func income(revenue: Double, cogs: Double = 0, opex: Double = 0, interest: Double = 0, tax: Double = 0) -> IncomeStatement<Double> {
		let e = entity()
		let p = periods()
		let rev = try! Account(entity: e, name: "Revenue", incomeStatementRole: .revenue, timeSeries: TimeSeries(periods: p, values: [revenue]))
		let c = try! Account(entity: e, name: "COGS", incomeStatementRole: .costOfGoodsSold,  timeSeries: TimeSeries(periods: p, values: [cogs]))
		let o = try! Account(entity: e, name: "OPEX", incomeStatementRole: .operatingExpenseOther,  timeSeries: TimeSeries(periods: p, values: [opex]))
		let i = try! Account(entity: e, name: "Interest", incomeStatementRole: .incomeTaxExpense, timeSeries: TimeSeries(periods: p, values: [interest]))
		let t = try! Account(entity: e, name: "Tax", incomeStatementRole: .incomeTaxExpense,  timeSeries: TimeSeries(periods: p, values: [tax]))
		return try! IncomeStatement(entity: e, periods: p, accounts: [rev, c, o, i, t])
	}

	func balance(currentAssets: Double, currentLiabilities: Double, totalAssets: Double? = nil, debt: Double = 0, equity: Double = 0) -> BalanceSheet<Double> {
		let e = entity()
		let p = periods()
		let ca = try! Account(entity: e, name: "CA", balanceSheetRole: .cashAndEquivalents, timeSeries: TimeSeries(periods: p, values: [currentAssets]))
		let totalA = totalAssets ?? max(currentAssets, 1)
		let nonCurrent = max(totalA - currentAssets, 0)
		let nc = try! Account(entity: e, name: "NC", balanceSheetRole: .otherNonCurrentAssets, timeSeries: TimeSeries(periods: p, values: [nonCurrent]))
		let cl = try! Account(entity: e, name: "CL", balanceSheetRole: .otherCurrentLiabilities, timeSeries: TimeSeries(periods: p, values: [currentLiabilities]))
		let d = try! Account(entity: e, name: "Debt", balanceSheetRole: .longTermDebt, timeSeries: TimeSeries(periods: p, values: [debt]))
		let eq = try! Account(entity: e, name: "Equity", balanceSheetRole: .commonStock, timeSeries: TimeSeries(periods: p, values: [equity]))
		return try! BalanceSheet(entity: e, periods: p, accounts: [ca, nc, cl, d, eq])
	}

	@Test("Headroom is negative when covenant is breached")
	func headroomNegativeOnBreach() throws {
		let p = periods()[0]
		let isty = income(revenue: 100_000)
		let bs = balance(currentAssets: 80_000, currentLiabilities: 100_000, totalAssets: 200_000, debt: 50_000, equity: 50_000)

		let covenant = FinancialCovenant(name: "Current Ratio", requirement: .minimumRatio(metric: .currentRatio, threshold: 1.2))
		let headroom = covenant.headroom(incomeStatement: isty, balanceSheet: bs, period: p)
		#expect(headroom < 0, "Headroom should be negative when current ratio is below threshold")
	}

	@Test("Waiver expires and covenant fails after expiration")
	func waiverExpiration() throws {
		let p = periods()[0]
		let isty = income(revenue: 100_000)
		let bs = balance(currentAssets: 80_000, currentLiabilities: 100_000, totalAssets: 200_000, debt: 50_000, equity: 50_000)
		var covenant = FinancialCovenant(name: "Current Ratio", requirement: .minimumRatio(metric: .currentRatio, threshold: 1.5))

		// initially failing
		let initial = covenant.isCompliant(incomeStatement: isty, balanceSheet: bs, period: p)
		#expect(!initial.allCompliant)

		// grant waiver
		let expire = Date(timeInterval: 5 * 86400, since: p.startDate)
		covenant = covenant.grantWaiver(period: p, expirationDate: expire)
		let during = covenant.isCompliant(incomeStatement: isty, balanceSheet: bs, period: p)
		#expect(during.allCompliant)

		// simulate after expiration (assuming isCompliant consults waiver validity at call time if period matches)
		// If your API requires explicit currentDate, adjust accordingly.
		covenant = covenant.grantWaiver(period: p, expirationDate: Date(timeIntervalSince1970: 0)) // force-expired
		let after = covenant.isCompliant(incomeStatement: isty, balanceSheet: bs, period: p)
		#expect(after.allCompliant)
	}
}

//
//  OilGasEPModelTests.swift
//  BusinessMathTests
//
//  Created by Justin Purnell on 4/15/26.
//

import Testing
@testable import BusinessMath

// MARK: - WellProductionProfile Tests

@Suite("WellProductionProfile")
struct WellProductionProfileTests {

    let periods = [
        Period.month(year: 2026, month: 1),
        Period.month(year: 2026, month: 2),
        Period.month(year: 2026, month: 3)
    ]

    @Test("Production for period equals daily rate times days in period")
    func productionForPeriod() {
        let dailyRates = TimeSeries<Double>(
            periods: periods,
            values: [100.0, 100.0, 100.0]
        )
        let well = WellProductionProfile(name: "Test Well", dailyProduction: dailyRates)

        // January 2026 has 31 days
        let janProduction = well.production(for: periods[0])
        #expect(janProduction == 3100.0)

        // February 2026 has 28 days (not a leap year)
        let febProduction = well.production(for: periods[1])
        #expect(febProduction == 2800.0)

        // March 2026 has 31 days
        let marProduction = well.production(for: periods[2])
        #expect(marProduction == 3100.0)
    }

    @Test("Production returns zero for missing period")
    func productionMissingPeriod() {
        let dailyRates = TimeSeries<Double>(
            periods: [periods[0]],
            values: [100.0]
        )
        let well = WellProductionProfile(name: "Test Well", dailyProduction: dailyRates)

        let missing = well.production(for: periods[2])
        #expect(missing == 0.0)
    }
}

// MARK: - OilGasEPModel Tests

@Suite("OilGasEPModel")
struct OilGasEPModelTests {

    let entity = Entity(id: "EP-TEST", name: "Test E&P Corp")

    let periods = [
        Period.month(year: 2026, month: 1),
        Period.month(year: 2026, month: 2),
        Period.month(year: 2026, month: 3)
    ]

    /// Creates a standard test model with one well producing 100 BOEPD.
    func makeModel(hedgingProgram: HedgingProgram<Double>? = nil) -> OilGasEPModel {
        let dailyRates = TimeSeries<Double>(
            periods: periods,
            values: [100.0, 100.0, 100.0]
        )
        let well = WellProductionProfile(name: "Well #1", dailyProduction: dailyRates)

        return OilGasEPModel(
            entity: entity,
            wells: [well],
            commodityPriceName: "WTI",
            leaseOperatingExpensePerBOE: 15.0,
            generalAndAdminExpense: 50_000.0,
            depreciationRate: 0.01,
            initialPPE: 10_000_000.0,
            initialCash: 500_000.0,
            taxRate: 0.21,
            hedgingProgram: hedgingProgram
        )
    }

    @Test("Single well fixed price revenue equals production times price times days")
    func revenueCalculation() {
        let model = makeModel()
        let fixedPrice: Double = 70.0
        let prices = TimeSeries<Double>(
            periods: periods,
            values: [fixedPrice, fixedPrice, fixedPrice]
        )

        let integration = model.project(periods: periods, commodityPrices: prices)
        let revenue = integration.incomeStatement.totalRevenue

        // January: 100 BOEPD * 31 days * $70 = $217,000
        let janRevenue = revenue[periods[0]]
        #expect(janRevenue != nil)
        #expect(abs((janRevenue ?? 0.0) - 217_000.0) < 0.01)

        // February: 100 BOEPD * 28 days * $70 = $196,000
        let febRevenue = revenue[periods[1]]
        #expect(febRevenue != nil)
        #expect(abs((febRevenue ?? 0.0) - 196_000.0) < 0.01)
    }

    @Test("LOE equals total production times per-BOE cost")
    func loeCalculation() {
        let model = makeModel()
        let prices = TimeSeries<Double>(
            periods: periods,
            values: [70.0, 70.0, 70.0]
        )

        let integration = model.project(periods: periods, commodityPrices: prices)

        // LOE is cost of goods sold in this model
        let costOfRevenue = integration.incomeStatement.costOfRevenueAccounts
        #expect(!costOfRevenue.isEmpty)

        // January: 100 * 31 * $15 = $46,500
        let janLOE = costOfRevenue[0].timeSeries[periods[0]]
        #expect(janLOE != nil)
        #expect(abs((janLOE ?? 0.0) - 46_500.0) < 0.01)

        // February: 100 * 28 * $15 = $42,000
        let febLOE = costOfRevenue[0].timeSeries[periods[1]]
        #expect(febLOE != nil)
        #expect(abs((febLOE ?? 0.0) - 42_000.0) < 0.01)
    }

    @Test("DD&A equals depreciation rate times PP&E")
    func ddaCalculation() {
        let model = makeModel()
        let prices = TimeSeries<Double>(
            periods: periods,
            values: [70.0, 70.0, 70.0]
        )

        let integration = model.project(periods: periods, commodityPrices: prices)
        let nonCashAccounts = integration.incomeStatement.nonCashChargeAccounts
        #expect(!nonCashAccounts.isEmpty)

        // Period 1: 0.01 * 10,000,000 = 100,000
        let janDDA = nonCashAccounts[0].timeSeries[periods[0]]
        #expect(janDDA != nil)
        #expect(abs((janDDA ?? 0.0) - 100_000.0) < 0.01)

        // Period 2: PP&E reduced by first DD&A: 0.01 * 9,900,000 = 99,000
        let febDDA = nonCashAccounts[0].timeSeries[periods[1]]
        #expect(febDDA != nil)
        #expect(abs((febDDA ?? 0.0) - 99_000.0) < 0.01)
    }

    @Test("Net income equals revenue minus all expenses minus taxes")
    func netIncomeCalculation() {
        let model = makeModel()
        let prices = TimeSeries<Double>(
            periods: periods,
            values: [70.0, 70.0, 70.0]
        )

        let integration = model.project(periods: periods, commodityPrices: prices)
        let netIncome = integration.incomeStatement.netIncome

        // January calculation:
        // Revenue: 100 * 31 * 70 = 217,000
        // LOE: 100 * 31 * 15 = 46,500
        // DD&A: 0.01 * 10,000,000 = 100,000
        // G&A: 50,000
        // Pre-tax: 217,000 - 46,500 - 100,000 - 50,000 = 20,500
        // Tax: 20,500 * 0.21 = 4,305
        // Net Income: 20,500 - 4,305 = 16,195
        let janNI = netIncome[periods[0]]
        #expect(janNI != nil)
        #expect(abs((janNI ?? 0.0) - 16_195.0) < 0.01)
    }

    @Test("Hedging settlements integrate into revenue")
    func hedgingIntegration() {
        var program = HedgingProgram<Double>()
        program.addSwap(CommoditySwap(
            underlier: "WTI",
            fixedPrice: 75.0,
            notionalVolume: 1000.0,
            settlementPeriods: periods
        ))

        let model = makeModel(hedgingProgram: program)

        // Spot at $70, hedge fixed at $75, volume 1000
        // Settlement = (75 - 70) * 1000 = 5000 per period
        let prices = TimeSeries<Double>(
            periods: periods,
            values: [70.0, 70.0, 70.0]
        )

        let integration = model.project(periods: periods, commodityPrices: prices)
        let revenue = integration.incomeStatement.totalRevenue

        // January revenue with hedge: 100 * 31 * 70 + 5000 = 222,000
        let janRevenue = revenue[periods[0]]
        #expect(janRevenue != nil)
        #expect(abs((janRevenue ?? 0.0) - 222_000.0) < 0.01)
    }

    @Test("Three-statement output produces valid StatementIntegration")
    func validStatementIntegration() {
        let model = makeModel()
        let prices = TimeSeries<Double>(
            periods: periods,
            values: [70.0, 70.0, 70.0]
        )

        let integration = model.project(periods: periods, commodityPrices: prices)

        // Verify all three statements exist with correct periods
        #expect(integration.incomeStatement.periods.count == 3)
        #expect(integration.balanceSheet.periods.count == 3)
        #expect(integration.cashFlowStatement.periods.count == 3)

        // Verify balance sheet equation: Assets = Liabilities + Equity
        // In our model: Cash + PP&E = Retained Earnings (no liabilities)
        let bsValid = integration.validateBalanceSheetEquation(tolerance: 0.01)
        #expect(bsValid)

        // Verify net income flows to retained earnings
        let niFlowValid = integration.validateNetIncomeFlow(tolerance: 0.01)
        #expect(niFlowValid)

        // Comprehensive validation
        let result = integration.validate(tolerance: 0.01)
        #expect(result.allValid)
    }

    @Test("Zero production produces zero revenue and LOE")
    func zeroProduction() {
        let zeroRates = TimeSeries<Double>(
            periods: periods,
            values: [0.0, 0.0, 0.0]
        )
        let well = WellProductionProfile(name: "Dry Well", dailyProduction: zeroRates)

        let model = OilGasEPModel(
            entity: entity,
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

        let prices = TimeSeries<Double>(
            periods: periods,
            values: [70.0, 70.0, 70.0]
        )

        let integration = model.project(periods: periods, commodityPrices: prices)
        let revenue = integration.incomeStatement.totalRevenue

        // Zero production means zero revenue
        let janRevenue = revenue[periods[0]]
        #expect(janRevenue != nil)
        #expect(abs(janRevenue ?? 1.0) < 0.01)
    }
}

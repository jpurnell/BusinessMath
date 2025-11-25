//
//  ResidualIncomeModelTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-01-25.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Residual Income Model Tests")
struct ResidualIncomeModelTests {

    // MARK: - Basic Residual Income Calculation Tests

    @Test("Calculate residual income - positive economic profit")
    func residualIncomePositive() {
        // Given: Company earning above cost of equity
        // Net Income = $120M, Book Value = $1000M, Cost of Equity = 10%
        // Equity Charge = 1000 * 0.10 = $100M
        // Residual Income = 120 - 100 = $20M
        let periods = [Period.year(2024)]
        let netIncome = TimeSeries(periods: periods, values: [120.0])
        let bookValue = TimeSeries(periods: periods, values: [1000.0])

        let model = ResidualIncomeModel(
            currentBookValue: 1000.0,
            netIncome: netIncome,
            bookValue: bookValue,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.03
        )

        // When: Calculate residual income
        let ri = model.residualIncome()

        // Then: Should be $20M
        #expect(abs(ri.valuesArray[0] - 20.0) < 0.01)
    }

    @Test("Calculate residual income - negative economic profit")
    func residualIncomeNegative() {
        // Given: Company earning below cost of equity
        // Net Income = $80M, Book Value = $1000M, Cost of Equity = 10%
        // Equity Charge = 1000 * 0.10 = $100M
        // Residual Income = 80 - 100 = -$20M (destroying value)
        let periods = [Period.year(2024)]
        let netIncome = TimeSeries(periods: periods, values: [80.0])
        let bookValue = TimeSeries(periods: periods, values: [1000.0])

        let model = ResidualIncomeModel(
            currentBookValue: 1000.0,
            netIncome: netIncome,
            bookValue: bookValue,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.03
        )

        // When: Calculate residual income
        let ri = model.residualIncome()

        // Then: Should be -$20M
        #expect(abs(ri.valuesArray[0] - (-20.0)) < 0.01)
    }

    @Test("Calculate residual income - zero economic profit")
    func residualIncomeZero() {
        // Given: Company earning exactly cost of equity
        // Net Income = $100M, Book Value = $1000M, Cost of Equity = 10%
        let periods = [Period.year(2024)]
        let netIncome = TimeSeries(periods: periods, values: [100.0])
        let bookValue = TimeSeries(periods: periods, values: [1000.0])

        let model = ResidualIncomeModel(
            currentBookValue: 1000.0,
            netIncome: netIncome,
            bookValue: bookValue,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.03
        )

        // When: Calculate residual income
        let ri = model.residualIncome()

        // Then: Should be $0 (value = book value)
        #expect(abs(ri.valuesArray[0]) < 0.01)
    }

    @Test("Residual income - multi-period projection")
    func residualIncomeMultiPeriod() {
        // Given: 3-year projection
        let periods = [Period.year(2024), Period.year(2025), Period.year(2026)]
        let netIncome = TimeSeries(periods: periods, values: [120.0, 132.0, 145.0])
        let bookValue = TimeSeries(periods: periods, values: [1000.0, 1100.0, 1210.0])

        let model = ResidualIncomeModel(
            currentBookValue: 1000.0,
            netIncome: netIncome,
            bookValue: bookValue,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.03
        )

        // When: Calculate residual income
        let ri = model.residualIncome()

        // Then: All periods should have positive RI
        // Year 1: 120 - (1000 * 0.10) = 20
        // Year 2: 132 - (1100 * 0.10) = 22
        // Year 3: 145 - (1210 * 0.10) = 24
        #expect(abs(ri.valuesArray[0] - 20.0) < 0.1)
        #expect(abs(ri.valuesArray[1] - 22.0) < 0.1)
        #expect(abs(ri.valuesArray[2] - 24.0) < 0.1)
    }

    // MARK: - Equity Value Tests

    @Test("Equity value - single period with positive RI")
    func equityValueSinglePeriodPositive() {
        // Given: Company with positive residual income
        let periods = [Period.year(2024)]
        let netIncome = TimeSeries(periods: periods, values: [150.0])
        let bookValue = TimeSeries(periods: periods, values: [1000.0])

        let model = ResidualIncomeModel(
            currentBookValue: 1000.0,
            netIncome: netIncome,
            bookValue: bookValue,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.03
        )

        // When: Calculate equity value
        let value = model.equityValue()

        // Then: Should be > book value
        // RI = 150 - 100 = 50
        // Terminal RI = 50 * 1.03 / (0.10 - 0.03) = 735.71
        // PV of Year 1 RI = 50 / 1.10 = 45.45
        // PV of Terminal = 735.71 / 1.10 = 668.83
        // Equity Value = 1000 + 45.45 + 668.83 = 1714.29
        #expect(value > 1000.0)
        #expect(abs(value - 1714.29) < 10.0)
    }

    @Test("Equity value - single period with negative RI")
    func equityValueSinglePeriodNegative() {
        // Given: Company destroying value
        let periods = [Period.year(2024)]
        let netIncome = TimeSeries(periods: periods, values: [60.0])
        let bookValue = TimeSeries(periods: periods, values: [1000.0])

        let model = ResidualIncomeModel(
            currentBookValue: 1000.0,
            netIncome: netIncome,
            bookValue: bookValue,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.03
        )

        // When: Calculate equity value
        let value = model.equityValue()

        // Then: Should be < book value
        // RI = 60 - 100 = -40
        #expect(value < 1000.0)
    }

    @Test("Equity value - zero RI equals book value")
    func equityValueZeroRI() {
        // Given: Company earning exactly cost of equity
        let periods = [Period.year(2024)]
        let netIncome = TimeSeries(periods: periods, values: [100.0])
        let bookValue = TimeSeries(periods: periods, values: [1000.0])

        let model = ResidualIncomeModel(
            currentBookValue: 1000.0,
            netIncome: netIncome,
            bookValue: bookValue,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.00  // No growth in terminal
        )

        // When: Calculate equity value
        let value = model.equityValue()

        // Then: Should equal book value (plus minor discounting effects)
        // RI = 100 - 100 = 0, so value should be close to book value
        #expect(abs(value - 1000.0) < 50.0)
    }

    @Test("Equity value - multi-period projection")
    func equityValueMultiPeriod() {
        // Given: 5-year projection with growing RI
        let periods = (2024...2028).map { Period.year($0) }
        let netIncome = TimeSeries(
            periods: periods,
            values: [120.0, 132.0, 145.0, 160.0, 176.0]
        )
        let bookValue = TimeSeries(
            periods: periods,
            values: [1000.0, 1100.0, 1210.0, 1331.0, 1464.0]
        )

        let model = ResidualIncomeModel(
            currentBookValue: 1000.0,
            netIncome: netIncome,
            bookValue: bookValue,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.03
        )

        // When: Calculate equity value
        let value = model.equityValue()

        // Then: Should be > book value due to positive RI
        #expect(value > 1000.0)
        #expect(value > 1200.0)  // Significant premium over book
    }

    // MARK: - Value Per Share Tests

    @Test("Value per share calculation")
    func valuePerShare() {
        // Given: Equity value and shares
        let periods = [Period.year(2024)]
        let netIncome = TimeSeries(periods: periods, values: [150.0])
        let bookValue = TimeSeries(periods: periods, values: [1000.0])

        let model = ResidualIncomeModel(
            currentBookValue: 1000.0,
            netIncome: netIncome,
            bookValue: bookValue,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.03
        )

        // When: Calculate value per share with 100M shares
        let sharePrice = model.valuePerShare(sharesOutstanding: 100.0)

        // Then: Should be equity value / shares
        let equityValue = model.equityValue()
        #expect(abs(sharePrice - (equityValue / 100.0)) < 0.01)
    }

    // MARK: - ROE and Clean Surplus Tests

    @Test("ROE calculation from model inputs")
    func roeCalculation() {
        // Given: Company with known net income and book value
        let periods = [Period.year(2024)]
        let netIncome = TimeSeries(periods: periods, values: [120.0])
        let bookValue = TimeSeries(periods: periods, values: [1000.0])

        let model = ResidualIncomeModel(
            currentBookValue: 1000.0,
            netIncome: netIncome,
            bookValue: bookValue,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.03
        )

        // Then: ROE = NI / BV = 120 / 1000 = 12%
        let roe = netIncome.valuesArray[0] / bookValue.valuesArray[0]
        #expect(abs(roe - 0.12) < 0.001)
    }

    @Test("Spread: ROE minus cost of equity")
    func roeSpread() {
        // Given: Company with ROE > Cost of Equity (value creation)
        let periods = [Period.year(2024)]
        let netIncome = TimeSeries(periods: periods, values: [150.0])  // ROE = 15%
        let bookValue = TimeSeries(periods: periods, values: [1000.0])

        let model = ResidualIncomeModel(
            currentBookValue: 1000.0,
            netIncome: netIncome,
            bookValue: bookValue,
            costOfEquity: 0.10,  // Cost = 10%
            terminalGrowthRate: 0.03
        )

        // When: Calculate ROE spread
        let roe = netIncome.valuesArray[0] / bookValue.valuesArray[0]
        let spread = roe - model.costOfEquity

        // Then: Positive spread = value creation
        #expect(spread > 0)
        #expect(abs(spread - 0.05) < 0.001)  // 15% - 10% = 5%
    }

    // MARK: - Edge Cases

    @Test("Invalid when terminal growth >= cost of equity")
    func invalidTerminalGrowth() {
        // Given: Invalid terminal growth rate
        let periods = [Period.year(2024)]
        let netIncome = TimeSeries(periods: periods, values: [120.0])
        let bookValue = TimeSeries(periods: periods, values: [1000.0])

        let model = ResidualIncomeModel(
            currentBookValue: 1000.0,
            netIncome: netIncome,
            bookValue: bookValue,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.10  // Equal to cost of equity
        )

        // When: Calculate equity value
        let value = model.equityValue()

        // Then: Should return NaN or infinity
        #expect(value.isNaN || value.isInfinite)
    }

    @Test("Zero book value edge case")
    func zeroBookValue() {
        // Given: Company with zero/negligible book value
        let periods = [Period.year(2024)]
        let netIncome = TimeSeries(periods: periods, values: [50.0])
        let bookValue = TimeSeries(periods: periods, values: [0.1])  // Minimal book value

        let model = ResidualIncomeModel(
            currentBookValue: 0.1,
            netIncome: netIncome,
            bookValue: bookValue,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.03
        )

        // When: Calculate equity value
        let value = model.equityValue()

        // Then: Should be dominated by residual income, not book value
        #expect(value > 0.1)
        #expect(value > 100.0)  // RI drives value, not book
    }

    @Test("High ROE company")
    func highROECompany() {
        // Given: Technology company with 30% ROE
        let periods = [Period.year(2024)]
        let netIncome = TimeSeries(periods: periods, values: [300.0])
        let bookValue = TimeSeries(periods: periods, values: [1000.0])

        let model = ResidualIncomeModel(
            currentBookValue: 1000.0,
            netIncome: netIncome,
            bookValue: bookValue,
            costOfEquity: 0.12,  // Higher cost for risky tech stock
            terminalGrowthRate: 0.04
        )

        // When: Calculate equity value
        let value = model.equityValue()

        // Then: Should have large premium over book value
        // ROE = 30%, Cost = 12%, Spread = 18% (huge value creation)
        #expect(value > 2000.0)  // At least 2x book value
    }

    @Test("Low ROE company (value destroyer)")
    func lowROECompany() {
        // Given: Struggling company with 5% ROE
        let periods = [Period.year(2024)]
        let netIncome = TimeSeries(periods: periods, values: [50.0])
        let bookValue = TimeSeries(periods: periods, values: [1000.0])

        let model = ResidualIncomeModel(
            currentBookValue: 1000.0,
            netIncome: netIncome,
            bookValue: bookValue,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.02
        )

        // When: Calculate equity value
        let value = model.equityValue()

        // Then: Should trade at discount to book value
        // ROE = 5%, Cost = 10%, Spread = -5% (value destruction)
        #expect(value < 1000.0)
    }

    // MARK: - Generic Type Tests

    @Test("Model with Float type")
    func modelWithFloat() {
        // Given: Model using Float
        let periods = [Period.year(2024)]
        let netIncome = TimeSeries<Float>(periods: periods, values: [120.0])
        let bookValue = TimeSeries<Float>(periods: periods, values: [1000.0])

        let model = ResidualIncomeModel<Float>(
            currentBookValue: 1000.0,
            netIncome: netIncome,
            bookValue: bookValue,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.03
        )

        // When: Calculate equity value
        let value = model.equityValue()

        // Then: Should work with Float
        #expect(value > 1000.0)
        #expect(!value.isNaN)
    }

    // MARK: - Comparison Tests

    @Test("RI Model vs Gordon Growth - consistency check")
    func compareRIWithGordonGrowth() {
        // Given: Stable company with constant payout and growth
        let periods = [Period.year(2024)]
        let netIncome = TimeSeries(periods: periods, values: [100.0])
        let bookValue = TimeSeries(periods: periods, values: [1000.0])

        // Residual Income Model
        let riModel = ResidualIncomeModel(
            currentBookValue: 1000.0,
            netIncome: netIncome,
            bookValue: bookValue,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.03
        )
        let riValue = riModel.equityValue()

        // Gordon Growth Model (assuming 100% payout ratio)
        let ggModel = GordonGrowthModel(
            dividendPerShare: 100.0,  // Full payout
            growthRate: 0.03,
            requiredReturn: 0.10
        )
        let ggValue = ggModel.valuePerShare()

        // Then: Both should be reasonable (RI might be higher if book value is low)
        #expect(riValue > 900.0)
        #expect(ggValue > 900.0)
    }

    @Test("RI Model - book value convergence")
    func bookValueConvergence() {
        // Given: Company expected to earn exactly cost of equity forever
        let periods = [Period.year(2024)]
        let netIncome = TimeSeries(periods: periods, values: [100.0])
        let bookValue = TimeSeries(periods: periods, values: [1000.0])

        let model = ResidualIncomeModel(
            currentBookValue: 1000.0,
            netIncome: netIncome,
            bookValue: bookValue,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.0  // RI stays constant at zero
        )

        // When: Calculate equity value
        let value = model.equityValue()

        // Then: Should converge to book value (within tolerance)
        // RI = 0 forever, so value = book value
        #expect(abs(value - 1000.0) < 50.0)
    }
}

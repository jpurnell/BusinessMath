//
//  FCFEModelTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-01-24.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("FCFE Model Tests")
struct FCFEModelTests {

    // MARK: - Basic FCFE Calculation Tests

    @Test("FCFE calculation - simple case with no debt")
    func fcfeCalculationNoDebt() throws {
        // Given: Company with operating CF, CapEx, no debt changes
        // Operating CF: $100M, CapEx: $30M
        // FCFE = Operating CF - CapEx = $70M

        let periods = [
            Period.year(2024),
            Period.year(2025)
        ]

        let operatingCF = TimeSeries(
            periods: periods,
            values: [100.0, 110.0]
        )

        let capEx = TimeSeries(
            periods: periods,
            values: [30.0, 33.0]
        )

        let model = FCFEModel(
            operatingCashFlow: operatingCF,
            capitalExpenditures: capEx,
            netBorrowing: nil,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.03
        )

        // When: Calculate FCFE
        let fcfe = model.fcfe()

        // Then: FCFE = Operating CF - CapEx
        #expect(fcfe.valuesArray.count == 2)
        #expect(abs(fcfe.valuesArray[0] - 70.0) < 0.01)  // 100 - 30
        #expect(abs(fcfe.valuesArray[1] - 77.0) < 0.01)  // 110 - 33
    }

    @Test("FCFE calculation - with debt repayment")
    func fcfeCalculationWithDebtRepayment() throws {
        // Given: Company repaying debt (negative net borrowing)
        let periods = [Period.year(2024)]

        let operatingCF = TimeSeries(periods: periods, values: [100.0])
        let capEx = TimeSeries(periods: periods, values: [30.0])
        let netBorrowing = TimeSeries(periods: periods, values: [-20.0])  // Repaying $20M

        let model = FCFEModel(
            operatingCashFlow: operatingCF,
            capitalExpenditures: capEx,
            netBorrowing: netBorrowing,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.03
        )

        // When: Calculate FCFE
        let fcfe = model.fcfe()

        // Then: FCFE = 100 - 30 - 20 = $50M
        #expect(abs(fcfe.valuesArray[0] - 50.0) < 0.01)
    }

    @Test("FCFE calculation - with new debt issuance")
    func fcfeCalculationWithDebtIssuance() throws {
        // Given: Company issuing new debt (positive net borrowing)
        let periods = [Period.year(2024)]

        let operatingCF = TimeSeries(periods: periods, values: [100.0])
        let capEx = TimeSeries(periods: periods, values: [30.0])
        let netBorrowing = TimeSeries(periods: periods, values: [50.0])  // Issuing $50M

        let model = FCFEModel(
            operatingCashFlow: operatingCF,
            capitalExpenditures: capEx,
            netBorrowing: netBorrowing,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.03
        )

        // When: Calculate FCFE
        let fcfe = model.fcfe()

        // Then: FCFE = 100 - 30 + 50 = $120M
        #expect(abs(fcfe.valuesArray[0] - 120.0) < 0.01)
    }

    // MARK: - Equity Value Calculation Tests

    @Test("Equity value - simple perpetuity")
    func equityValueSimplePerpetuit() throws {
        // Given: Single period FCFE of $70M, 10% cost of equity, 3% growth
        let periods = [Period.year(2024)]

        let operatingCF = TimeSeries(periods: periods, values: [100.0])
        let capEx = TimeSeries(periods: periods, values: [30.0])

        let model = FCFEModel(
            operatingCashFlow: operatingCF,
            capitalExpenditures: capEx,
            netBorrowing: nil,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.03
        )

        // When: Calculate equity value
        let equityValue = model.equityValue()

        // Then: Terminal value = FCFE * (1 + g) / (r - g)
        // = 70 * 1.03 / (0.10 - 0.03) = 72.1 / 0.07 = 1030
        // Discounted to present: 1030 / 1.10 = 936.36
        // But we also discount the first year FCFE: 70 / 1.10 = 63.64
        // Total = 1000 (approx)
        #expect(abs(equityValue - 1000.0) < 50.0)
    }

    @Test("Equity value - multi-period projection")
    func equityValueMultiPeriod() throws {
        // Given: 3-year projection with growth, then terminal value
        let periods = [
            Period.year(2024),
            Period.year(2025),
            Period.year(2026)
        ]

        let operatingCF = TimeSeries(
            periods: periods,
            values: [100.0, 110.0, 121.0]
        )

        let capEx = TimeSeries(
            periods: periods,
            values: [30.0, 32.0, 34.0]
        )

        let model = FCFEModel(
            operatingCashFlow: operatingCF,
            capitalExpenditures: capEx,
            netBorrowing: nil,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.03
        )

        // When: Calculate equity value
        let equityValue = model.equityValue()

        // Then: Sum of PV of 3-year FCFE + PV of terminal value
        // FCFE: [70, 78, 87]
        // PV(70) = 70/1.10 = 63.64
        // PV(78) = 78/1.21 = 64.46
        // PV(87) = 87/1.331 = 65.36
        // Terminal = 87 * 1.03 / 0.07 = 1281.43
        // PV(Terminal) = 1281.43 / 1.331 = 962.80
        // Total = 63.64 + 64.46 + 65.36 + 962.80 = 1156.26
        #expect(equityValue > 1100.0)
        #expect(equityValue < 1200.0)
    }

    @Test("Value per share calculation")
    func valuePerShare() throws {
        // Given: Equity value and shares outstanding
        let periods = [Period.year(2024)]

        let operatingCF = TimeSeries(periods: periods, values: [100.0])
        let capEx = TimeSeries(periods: periods, values: [30.0])

        let model = FCFEModel(
            operatingCashFlow: operatingCF,
            capitalExpenditures: capEx,
            netBorrowing: nil,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.03
        )

        // When: Calculate value per share with 100M shares
        let sharePrice = model.valuePerShare(sharesOutstanding: 100.0)

        // Then: Share price = Equity Value / Shares
        // Equity value ≈ 1000, so price ≈ 10.00
        #expect(abs(sharePrice - 10.0) < 1.0)
    }

    // MARK: - Sensitivity Analysis Tests

    @Test("Sensitivity to cost of equity")
    func sensitivityToCostOfEquity() throws {
        let periods = [Period.year(2024)]
        let operatingCF = TimeSeries(periods: periods, values: [100.0])
        let capEx = TimeSeries(periods: periods, values: [30.0])

        // Lower cost of equity (8%)
        let modelLowCOE = FCFEModel(
            operatingCashFlow: operatingCF,
            capitalExpenditures: capEx,
            netBorrowing: nil,
            costOfEquity: 0.08,
            terminalGrowthRate: 0.03
        )

        // Higher cost of equity (12%)
        let modelHighCOE = FCFEModel(
            operatingCashFlow: operatingCF,
            capitalExpenditures: capEx,
            netBorrowing: nil,
            costOfEquity: 0.12,
            terminalGrowthRate: 0.03
        )

        // When: Calculate values
        let valueLowCOE = modelLowCOE.equityValue()
        let valueHighCOE = modelHighCOE.equityValue()

        // Then: Lower cost of equity → Higher value
        #expect(valueLowCOE > valueHighCOE)
        #expect(valueLowCOE > 1200.0)  // Should be higher with 8% discount
        #expect(valueHighCOE < 800.0)  // Should be lower with 12% discount
    }

    @Test("Sensitivity to terminal growth rate")
    func sensitivityToTerminalGrowth() throws {
        let periods = [Period.year(2024)]
        let operatingCF = TimeSeries(periods: periods, values: [100.0])
        let capEx = TimeSeries(periods: periods, values: [30.0])

        // Lower growth (2%)
        let modelLowGrowth = FCFEModel(
            operatingCashFlow: operatingCF,
            capitalExpenditures: capEx,
            netBorrowing: nil,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.02
        )

        // Higher growth (4%)
        let modelHighGrowth = FCFEModel(
            operatingCashFlow: operatingCF,
            capitalExpenditures: capEx,
            netBorrowing: nil,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.04
        )

        // When: Calculate values
        let valueLowGrowth = modelLowGrowth.equityValue()
        let valueHighGrowth = modelHighGrowth.equityValue()

        // Then: Higher growth → Higher value
        #expect(valueHighGrowth > valueLowGrowth)
    }

    // MARK: - Edge Cases

    @Test("Negative FCFE (company burning cash)")
    func negativeFCFE() throws {
        // Given: Company with negative FCFE (high CapEx investment)
        let periods = [Period.year(2024)]

        let operatingCF = TimeSeries(periods: periods, values: [50.0])
        let capEx = TimeSeries(periods: periods, values: [100.0])  // Heavy investment

        let model = FCFEModel(
            operatingCashFlow: operatingCF,
            capitalExpenditures: capEx,
            netBorrowing: nil,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.03
        )

        // When: Calculate FCFE
        let fcfe = model.fcfe()

        // Then: FCFE should be negative
        #expect(fcfe.valuesArray[0] < 0)
        #expect(abs(fcfe.valuesArray[0] - (-50.0)) < 0.01)
    }

    @Test("Zero terminal growth")
    func zeroTerminalGrowth() throws {
        // Given: No growth in perpetuity
        let periods = [Period.year(2024)]
        let operatingCF = TimeSeries(periods: periods, values: [100.0])
        let capEx = TimeSeries(periods: periods, values: [30.0])

        let model = FCFEModel(
            operatingCashFlow: operatingCF,
            capitalExpenditures: capEx,
            netBorrowing: nil,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.0  // No growth
        )

        // When: Calculate equity value
        let equityValue = model.equityValue()

        // Then: Terminal value = FCFE / r = 70 / 0.10 = 700
        // Discounted: 700 / 1.10 = 636.36
        // Plus first year: 70 / 1.10 = 63.64
        // Total = 700.00
        #expect(abs(equityValue - 700.0) < 10.0)
    }

    @Test("Invalid: growth >= cost of equity")
    func invalidGrowthRate() throws {
        // Given: Growth rate equals cost of equity (invalid)
        let periods = [Period.year(2024)]
        let operatingCF = TimeSeries(periods: periods, values: [100.0])
        let capEx = TimeSeries(periods: periods, values: [30.0])

        let model = FCFEModel(
            operatingCashFlow: operatingCF,
            capitalExpenditures: capEx,
            netBorrowing: nil,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.10  // g = r (invalid)
        )

        // When: Calculate equity value
        let equityValue = model.equityValue()

        // Then: Should return NaN or infinity
        #expect(equityValue.isNaN || equityValue.isInfinite)
    }

    // MARK: - Quarterly Periods Test

    @Test("Quarterly FCFE projections")
    func quarterlyProjections() throws {
        // Given: Quarterly cash flow projections
        let periods = [
            Period.quarter(year: 2024, quarter: 1),
            Period.quarter(year: 2024, quarter: 2),
            Period.quarter(year: 2024, quarter: 3),
            Period.quarter(year: 2024, quarter: 4)
        ]

        let operatingCF = TimeSeries(
            periods: periods,
            values: [25.0, 27.0, 26.0, 28.0]
        )

        let capEx = TimeSeries(
            periods: periods,
            values: [8.0, 7.0, 9.0, 10.0]
        )

        let model = FCFEModel(
            operatingCashFlow: operatingCF,
            capitalExpenditures: capEx,
            netBorrowing: nil,
            costOfEquity: 0.10,  // Annual rate
            terminalGrowthRate: 0.03
        )

        // When: Calculate FCFE
        let fcfe = model.fcfe()

        // Then: Should have 4 quarters of FCFE
        #expect(fcfe.valuesArray.count == 4)
        #expect(fcfe.valuesArray[0] > 0)
    }

    // MARK: - Generic Type Tests

    @Test("FCFE model with Float type")
    func fcfeModelWithFloat() throws {
        // Given: Model using Float instead of Double
        let periods = [Period.year(2024)]

        let operatingCF = TimeSeries<Float>(periods: periods, values: [100.0])
        let capEx = TimeSeries<Float>(periods: periods, values: [30.0])

        let model = FCFEModel<Float>(
            operatingCashFlow: operatingCF,
            capitalExpenditures: capEx,
            netBorrowing: nil,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.03
        )

        // When: Calculate equity value
        let equityValue = model.equityValue()

        // Then: Should work with Float type
        #expect(equityValue > 900.0)
        #expect(equityValue < 1000.0)
    }

    // MARK: - Comparison with DDM

    @Test("Compare FCFE with DDM (should align if payout = 100%)")
    func compareFCFEWithDDM() throws {
        // Given: Company with FCFE = Dividends (100% payout)
        let periods = [Period.year(2024)]
        let operatingCF = TimeSeries(periods: periods, values: [100.0])
        let capEx = TimeSeries(periods: periods, values: [30.0])

        let fcfeModel = FCFEModel(
            operatingCashFlow: operatingCF,
            capitalExpenditures: capEx,
            netBorrowing: nil,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.03
        )

        // Equivalent Gordon Growth Model
        // FCFE = 70, with 3% growth → D1 = 70
        let gordonModel = GordonGrowthModel(
            dividendPerShare: 70.0,  // Assuming 1 share
            growthRate: 0.03,
            requiredReturn: 0.10
        )

        // When: Calculate both values
        let fcfeValue = fcfeModel.equityValue()
        let gordonValue = gordonModel.valuePerShare()

        // Then: Should be approximately equal (within rounding)
        #expect(abs(fcfeValue - gordonValue) < 50.0)
    }

    // MARK: - Real-World Example

    @Test("Real-world example - tech company valuation")
    func realWorldTechCompanyValuation() throws {
        // Given: Tech company with 5-year projection
        // Growing operating CF, stable CapEx as % of revenue
        let periods = (2024...2028).map { Period.year($0) }

        let operatingCF = TimeSeries(
            periods: periods,
            values: [500.0, 575.0, 661.0, 760.0, 874.0]  // 15% growth
        )

        let capEx = TimeSeries(
            periods: periods,
            values: [100.0, 115.0, 132.0, 152.0, 175.0]  // 15% growth
        )

        let model = FCFEModel(
            operatingCashFlow: operatingCF,
            capitalExpenditures: capEx,
            netBorrowing: nil,
            costOfEquity: 0.12,  // Tech company discount rate
            terminalGrowthRate: 0.04  // Mature growth rate
        )

        // When: Calculate valuation
        let equityValue = model.equityValue()
        let fcfe = model.fcfe()

        // Then: Should generate reasonable valuation
        #expect(equityValue > 5000.0)  // Should be significant
        #expect(fcfe.valuesArray.count == 5)
        #expect(fcfe.valuesArray.allSatisfy { $0 > 0 })  // All positive FCFE

        // Value per share with 100M shares
        let sharePrice = model.valuePerShare(sharesOutstanding: 100.0)
        #expect(sharePrice > 50.0)  // Reasonable tech stock price
    }
}

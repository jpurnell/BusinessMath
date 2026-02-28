//
//  EquityValuationIntegrationTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-01-25.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Equity Valuation Integration Tests")
struct EquityValuationIntegrationTests {

    // MARK: - Full Workflow Tests

    @Test("Complete DCF workflow: FCFF → EV → Equity → Per Share")
    func completeDCFWorkflow() throws {
        // Given: 5-year FCFF projection for a company
        let periods = (2024...2028).map { Period.year($0) }
        let fcff = TimeSeries(
            periods: periods,
            values: [100.0, 110.0, 121.0, 133.0, 146.0]
        )

        // Step 1: Calculate Enterprise Value from FCFF
        let ev = enterpriseValueFromFCFF(
            freeCashFlowToFirm: fcff,
            wacc: 0.09,
            terminalGrowthRate: 0.03
        )

        // Step 2: Bridge to Equity Value
        let bridge = EnterpriseValueBridge(
            enterpriseValue: ev,
            totalDebt: 500.0,
            cash: 100.0,
            nonOperatingAssets: 50.0,
            minorityInterest: 20.0,
            preferredStock: 30.0
        )

        let equityValue = bridge.equityValue()
        let breakdown = bridge.breakdown()

        // Step 3: Calculate per share value
        let sharesOutstanding = 100.0
        let sharePrice = bridge.valuePerShare(sharesOutstanding: sharesOutstanding)

        // Then: All values should be reasonable and consistent
        #expect(ev > 1500.0)  // Substantial EV
        #expect(equityValue < ev)  // Equity < EV (due to net debt)
        #expect(sharePrice > 10.0)  // Reasonable share price
        #expect(abs(breakdown.netDebt - 400.0) < 0.1)  // 500 - 100
        #expect(abs(sharePrice * sharesOutstanding - equityValue) < 0.1)  // Consistency check
    }

    @Test("Compare DDM vs FCFE - mature dividend-paying company")
    func compareDDMvsFCFE() throws {
        // Given: Mature company with stable dividends
        let periods = (2024...2026).map { Period.year($0) }

        // Scenario: Company with 100% payout ratio
        let dividend = 100.0
        let costOfEquity = 0.10
        let growth = 0.03

        // Method 1: Gordon Growth Model
        let ggModel = GordonGrowthModel(
            dividendPerShare: dividend,
            growthRate: growth,
            requiredReturn: costOfEquity
        )
        let ggValue = try ggModel.valuePerShare()

        // Method 2: FCFE Model (with 100% payout, FCFE ≈ Dividends)
        let operatingCF = TimeSeries(periods: periods, values: [110.0, 113.0, 116.0])
        let capEx = TimeSeries(periods: periods, values: [10.0, 10.3, 10.6])

        let fcfeModel = FCFEModel(
            operatingCashFlow: operatingCF,
            capitalExpenditures: capEx,
            netBorrowing: nil,
            costOfEquity: costOfEquity,
            terminalGrowthRate: growth
        )
        let fcfeValue = try fcfeModel.equityValue()

        // Then: Both should yield similar values (within 20%)
        // FCFE might be higher due to explicit forecast periods
        #expect(ggValue > 1000.0)
        #expect(fcfeValue > 1000.0)
        let ratio = fcfeValue / ggValue
        #expect(ratio > 0.8 && ratio < 1.5)  // Should be reasonably close
    }

    @Test("Compare FCFE vs RI Model - accounting-based company")
    func compareFCFEvsRI() throws {
        // Given: Company with predictable earnings and cash flows
        let periods = (2024...2026).map { Period.year($0) }

        // Common assumptions
        let costOfEquity = 0.10
        let growth = 0.03
        let currentBookValue = 1000.0

        // Method 1: FCFE Model
        let operatingCF = TimeSeries(periods: periods, values: [150.0, 154.5, 159.0])
        let capEx = TimeSeries(periods: periods, values: [30.0, 30.9, 31.8])

        let fcfeModel = FCFEModel(
            operatingCashFlow: operatingCF,
            capitalExpenditures: capEx,
            netBorrowing: nil,
            costOfEquity: costOfEquity,
            terminalGrowthRate: growth
        )
        let fcfeValue = try fcfeModel.equityValue()

        // Method 2: Residual Income Model
        let netIncome = TimeSeries(periods: periods, values: [120.0, 123.6, 127.3])
        let bookValue = TimeSeries(periods: periods, values: [1000.0, 1030.0, 1060.9])

        let riModel = ResidualIncomeModel(
            currentBookValue: currentBookValue,
            netIncome: netIncome,
            bookValue: bookValue,
            costOfEquity: costOfEquity,
            terminalGrowthRate: growth
        )
        let riValue = try riModel.equityValue()

        // Then: Both should be positive and reasonable
        #expect(fcfeValue > 1000.0)
        #expect(riValue > 1000.0)

        // RI should have book value anchor
        #expect(abs(riValue - currentBookValue) < riValue)  // Premium not too large
    }

    @Test("Three-way valuation comparison - same company")
    func threeWayValuation() throws {
        // Given: Complete financial projections for a company
        let periods = (2024...2026).map { Period.year($0) }
        let costOfEquity = 0.10
        let growth = 0.03

        // Method 1: DDM (assuming 50% payout ratio)
        let ggModel = GordonGrowthModel(
            dividendPerShare: 60.0,  // 50% of $120 earnings per 1 share
            growthRate: growth,
            requiredReturn: costOfEquity
        )
        let ggValue = try ggModel.valuePerShare() * 100.0  // Multiply by shares

        // Method 2: FCFE
        let operatingCF = TimeSeries(periods: periods, values: [150.0, 154.5, 159.0])
        let capEx = TimeSeries(periods: periods, values: [30.0, 30.9, 31.8])

        let fcfeModel = FCFEModel(
            operatingCashFlow: operatingCF,
            capitalExpenditures: capEx,
            netBorrowing: nil,
            costOfEquity: costOfEquity,
            terminalGrowthRate: growth
        )
        let fcfeValue = try fcfeModel.equityValue()

        // Method 3: Residual Income
        let netIncome = TimeSeries(periods: periods, values: [120.0, 123.6, 127.3])
        let bookValue = TimeSeries(periods: periods, values: [1000.0, 1030.0, 1060.9])

        let riModel = ResidualIncomeModel(
            currentBookValue: 1000.0,
            netIncome: netIncome,
            bookValue: bookValue,
            costOfEquity: costOfEquity,
            terminalGrowthRate: growth
        )
        let riValue = try riModel.equityValue()

        // Then: All three should be in the same ballpark
        #expect(ggValue > 700.0)
        #expect(fcfeValue > 1000.0)
        #expect(riValue > 1000.0)

        // All three represent the same company, so should not wildly diverge
        #expect(fcfeValue > 0.5 * riValue && fcfeValue < 2.0 * riValue)
    }

    // MARK: - Consistency Tests

    @Test("RI Model - book value convergence when ROE = Cost of Equity")
    func riModelBookValueConvergence() throws {
        // Given: Company earning exactly cost of equity (zero economic profit)
        let periods = (2024...2028).map { Period.year($0) }
        let costOfEquity = 0.10
        let bookValue = 1000.0

        // Net Income = Book Value × Cost of Equity (ROE = Cost of Equity)
        let netIncome = TimeSeries(
            periods: periods,
            values: [100.0, 103.0, 106.1, 109.3, 112.6]
        )
        let bookValueSeries = TimeSeries(
            periods: periods,
            values: [1000.0, 1030.0, 1061.0, 1092.8, 1125.6]
        )

        let riModel = ResidualIncomeModel(
            currentBookValue: bookValue,
            netIncome: netIncome,
            bookValue: bookValueSeries,
            costOfEquity: costOfEquity,
            terminalGrowthRate: 0.0  // No terminal growth
        )

        // When: Calculate equity value
        let equityValue = try riModel.equityValue()

        // Then: Should converge to book value (within tolerance)
        // RI = 0 for all periods, so NPV = 0, value = book
        #expect(abs(equityValue - bookValue) < 100.0)
    }

    @Test("Two-Stage DDM reduces to Gordon Growth with zero high growth periods")
    func twoStageReducesToGordon() throws {
        // Given: Equivalent models
        let dividend = 2.0
        let growth = 0.05
        let required = 0.10

        // Two-Stage with 0 high growth periods
        let twoStage = TwoStageDDM(
            currentDividend: dividend / 1.05,  // Adjust so first payment is 2.0
            highGrowthRate: 0.20,  // Won't be used
            highGrowthPeriods: 0,
            stableGrowthRate: growth,
            requiredReturn: required
        )

        // Gordon Growth
        let gordon = GordonGrowthModel(
            dividendPerShare: dividend,
            growthRate: growth,
            requiredReturn: required
        )

        // When: Calculate both
        let twoStageValue = try twoStage.valuePerShare()
        let gordonValue = try gordon.valuePerShare()

        // Then: Should be very close
        #expect(abs(twoStageValue - gordonValue) < 1.0)
    }

    @Test("H-Model reduces to Gordon when initial growth = terminal growth")
    func hModelReducesToGordon() throws {
        // Given: Equivalent models
        let dividend = 2.0
        let growth = 0.05
        let required = 0.10

        // H-Model with same initial and terminal growth
        let hModel = HModel(
            currentDividend: dividend / 1.05,
            initialGrowthRate: growth,
            terminalGrowthRate: growth,
            halfLife: 10,  // Doesn't matter when initial = terminal
            requiredReturn: required
        )

        // Gordon Growth
        let gordon = GordonGrowthModel(
            dividendPerShare: dividend,
            growthRate: growth,
            requiredReturn: required
        )

        // When: Calculate both
        let hValue = try hModel.valuePerShare()
        let gordonValue = try gordon.valuePerShare()

        // Then: Should be equal
        #expect(abs(hValue - gordonValue) < 0.1)
    }

    @Test("Enterprise Value Bridge - pure equity company")
    func pureEquityCompany() throws {
        // Given: Company with no debt, no cash
        let ev = 2000.0

        let bridge = EnterpriseValueBridge(
            enterpriseValue: ev,
            totalDebt: 0.0,
            cash: 0.0,
            nonOperatingAssets: 0.0,
            minorityInterest: 0.0,
            preferredStock: 0.0
        )

        // When: Calculate equity value
        let equityValue = bridge.equityValue()

        // Then: Equity = EV (no adjustments)
        #expect(abs(equityValue - ev) < 0.01)
    }

    // MARK: - Sensitivity Analysis Integration

    @Test("Sensitivity to cost of equity - all models")
    func sensitivityToCostOfEquity() throws {
        // Given: Same company valued at different costs of equity
        let lowCost = 0.08
        let highCost = 0.12

        // DDM sensitivity
        let ggLow = try GordonGrowthModel(
            dividendPerShare: 2.0,
            growthRate: 0.04,
            requiredReturn: lowCost
        ).valuePerShare()

        let ggHigh = try GordonGrowthModel(
            dividendPerShare: 2.0,
            growthRate: 0.04,
            requiredReturn: highCost
        ).valuePerShare()

        // FCFE sensitivity
        let periods = [Period.year(2024)]
        let opCF = TimeSeries(periods: periods, values: [100.0])
        let capEx = TimeSeries(periods: periods, values: [20.0])

        let fcfeLow = try FCFEModel(
            operatingCashFlow: opCF,
            capitalExpenditures: capEx,
            netBorrowing: nil,
            costOfEquity: lowCost,
            terminalGrowthRate: 0.03
        ).equityValue()

        let fcfeHigh = try FCFEModel(
            operatingCashFlow: opCF,
            capitalExpenditures: capEx,
            netBorrowing: nil,
            costOfEquity: highCost,
            terminalGrowthRate: 0.03
        ).equityValue()

        // Then: Higher cost of equity → Lower values for all models
        #expect(ggHigh < ggLow)
        #expect(fcfeHigh < fcfeLow)

        // The sensitivity should be significant (at least 30% difference)
        #expect(ggLow / ggHigh > 1.3)
        #expect(fcfeLow / fcfeHigh > 1.3)
    }

    @Test("Sensitivity to growth rate - all models")
    func sensitivityToGrowthRate() throws {
        // Given: Same company with different growth assumptions
        let lowGrowth = 0.02
        let highGrowth = 0.05

        // DDM sensitivity
        let ggLow = try GordonGrowthModel(
            dividendPerShare: 2.0,
            growthRate: lowGrowth,
            requiredReturn: 0.10
        ).valuePerShare()

        let ggHigh = try GordonGrowthModel(
            dividendPerShare: 2.0,
            growthRate: highGrowth,
            requiredReturn: 0.10
        ).valuePerShare()

        // Then: Higher growth → Higher values
        #expect(ggHigh > ggLow)

        // The impact should be substantial
        #expect(ggHigh / ggLow > 1.5)
    }

    // MARK: - Real-World Scenario Tests

    @Test("Tech startup - high growth then maturity")
    func techStartupValuation() throws {
        // Given: Tech startup growing 30% for 5 years, then 5% forever
        let twoStage = TwoStageDDM(
            currentDividend: 0.5,  // Low initial dividend
            highGrowthRate: 0.30,
            highGrowthPeriods: 5,
            stableGrowthRate: 0.05,
            requiredReturn: 0.15  // Higher required return for risky startup
        )

        // When: Calculate value
        let value = try twoStage.valuePerShare()

        // Then: Should have substantial value from growth phase
        #expect(value > 5.0)
        #expect(!value.isNaN)
        #expect(!value.isInfinite)
    }

    @Test("Mature utility - stable low growth")
    func matureUtilityValuation() throws {
        // Given: Utility with high dividend, low growth
        let gordon = GordonGrowthModel(
            dividendPerShare: 5.0,  // High payout
            growthRate: 0.02,  // GDP-like growth
            requiredReturn: 0.07  // Lower required return for stable utility
        )

        // When: Calculate value
        let value = try gordon.valuePerShare()

        // Then: Should trade at high multiple of dividend
        #expect(value > 80.0)  // At least 16x dividend
        #expect(value < 150.0)  // But not infinite
    }

    @Test("Financial institution - book value matters")
    func financialInstitutionValuation() throws {
        // Given: Bank with meaningful book value
        let periods = [Period.year(2024), Period.year(2025)]
        let netIncome = TimeSeries(periods: periods, values: [150.0, 157.5])
        let bookValue = TimeSeries(periods: periods, values: [1000.0, 1050.0])

        let riModel = ResidualIncomeModel(
            currentBookValue: 1000.0,
            netIncome: netIncome,
            bookValue: bookValue,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.03
        )

        // When: Calculate value
        let equityValue = try riModel.equityValue()

        // Then: Should be at premium to book (15% ROE > 10% cost)
        #expect(equityValue > 1000.0)

        // But premium shouldn't be too extreme for financial institution
        #expect(equityValue < 2000.0)
    }

    // MARK: - Edge Case Integration Tests

    @Test("All models handle zero/minimal growth")
    func zeroGrowthConsistency() throws {
        // Given: No growth scenarios
        let dividend = 5.0
        let costOfEquity = 0.10

        // DDM with zero growth
        let ggZero = try GordonGrowthModel(
            dividendPerShare: dividend,
            growthRate: 0.0,
            requiredReturn: costOfEquity
        ).valuePerShare()

        // DDM with minimal growth
        let ggMinimal = try GordonGrowthModel(
            dividendPerShare: dividend,
            growthRate: 0.001,
            requiredReturn: costOfEquity
        ).valuePerShare()

        // Then: Zero growth should give simple perpetuity
        #expect(abs(ggZero - dividend / costOfEquity) < 0.1)

        // Minimal growth should be slightly higher
        #expect(ggMinimal > ggZero)
        #expect(ggMinimal < ggZero * 1.05)  // Not much higher
    }

    @Test("All models reject invalid terminal growth >= cost")
    func invalidGrowthRateHandling() throws {
        // DDM: growth >= required return
        let invalidGG = GordonGrowthModel(
            dividendPerShare: 2.0,
            growthRate: 0.10,
            requiredReturn: 0.10
        )

        #expect(throws: ValuationError.self) {
            try invalidGG.valuePerShare()
        }

        // FCFE: terminal >= cost of equity
        let periods = [Period.year(2024)]
        let opCF = TimeSeries(periods: periods, values: [100.0])
        let capEx = TimeSeries(periods: periods, values: [20.0])

        let invalidFCFE = FCFEModel(
            operatingCashFlow: opCF,
            capitalExpenditures: capEx,
            netBorrowing: nil,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.12  // > cost of equity
        )

        #expect(throws: ValuationError.self) {
            try invalidFCFE.equityValue()
        }

        // RI: terminal >= cost of equity
        let netIncome = TimeSeries(periods: periods, values: [100.0])
        let bookValue = TimeSeries(periods: periods, values: [1000.0])

        let invalidRI = ResidualIncomeModel(
            currentBookValue: 1000.0,
            netIncome: netIncome,
            bookValue: bookValue,
            costOfEquity: 0.10,
            terminalGrowthRate: 0.10  // = cost of equity
        )

        #expect(throws: ValuationError.self) {
            try invalidRI.equityValue()
        }
    }

    // MARK: - Performance Integration

    @Test("Integrated valuation workflow completes quickly")
    func integratedWorkflowPerformance() throws {
        // Given: Complete valuation workflow
        let start = Date()

        // Run full DCF workflow
        let periods = (2024...2028).map { Period.year($0) }
        let fcff = TimeSeries(periods: periods, values: [100.0, 110.0, 121.0, 133.0, 146.0])

        let ev = enterpriseValueFromFCFF(
            freeCashFlowToFirm: fcff,
            wacc: 0.09,
            terminalGrowthRate: 0.03
        )

        let bridge = EnterpriseValueBridge(
            enterpriseValue: ev,
            totalDebt: 500.0,
            cash: 100.0,
            nonOperatingAssets: 50.0,
            minorityInterest: 20.0,
            preferredStock: 30.0
        )

        let equityValue = bridge.equityValue()
        let sharePrice = bridge.valuePerShare(sharesOutstanding: 100.0)

        let elapsed = Date().timeIntervalSince(start)

        // Then: Should complete in reasonable time (100ms threshold to avoid CI flakiness)
        // Note: This is a smoke test only; dedicated performance testing is in DDMPerformanceTests
        #expect(elapsed < 0.100, "Integrated workflow took \(elapsed * 1000) ms")
        #expect(sharePrice > 0)
        #expect(!equityValue.isNaN)
    }
}

//
//  EnterpriseValueBridgeTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-01-24.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Enterprise Value Bridge Tests")
struct EnterpriseValueBridgeTests {

    // MARK: - Basic Bridge Tests

    @Test("EV to Equity - simple case with net debt")
    func evToEquitySimpleNetDebt() throws {
        // Given: Company with $1000M EV, $200M debt, $50M cash
        // Net Debt = $150M
        let bridge = EnterpriseValueBridge(
            enterpriseValue: 1000.0,
            totalDebt: 200.0,
            cash: 50.0,
            nonOperatingAssets: 0.0,
            minorityInterest: 0.0,
            preferredStock: 0.0
        )

        // When: Calculate equity value
        let equityValue = bridge.equityValue()

        // Then: Equity = EV - Net Debt
        // = 1000 - (200 - 50) = 1000 - 150 = 850
        #expect(abs(equityValue - 850.0) < 0.01)
    }

    @Test("EV to Equity - with net cash (negative net debt)")
    func evToEquityNetCash() throws {
        // Given: Tech company with $2000M EV, $100M debt, $500M cash
        // Net Debt = -$400M (net cash position)
        let bridge = EnterpriseValueBridge(
            enterpriseValue: 2000.0,
            totalDebt: 100.0,
            cash: 500.0,
            nonOperatingAssets: 0.0,
            minorityInterest: 0.0,
            preferredStock: 0.0
        )

        // When: Calculate equity value
        let equityValue = bridge.equityValue()

        // Then: Equity = EV - Net Debt = 2000 - (100 - 500) = 2000 + 400 = 2400
        #expect(abs(equityValue - 2400.0) < 0.01)
    }

    @Test("EV to Equity - with non-operating assets")
    func evToEquityWithNonOperatingAssets() throws {
        // Given: Company with investments not included in operations
        let bridge = EnterpriseValueBridge(
            enterpriseValue: 1000.0,
            totalDebt: 200.0,
            cash: 50.0,
            nonOperatingAssets: 100.0,  // Marketable securities
            minorityInterest: 0.0,
            preferredStock: 0.0
        )

        // When: Calculate equity value
        let equityValue = bridge.equityValue()

        // Then: Equity = EV - Net Debt + Non-Operating Assets
        // = 1000 - 150 + 100 = 950
        #expect(abs(equityValue - 950.0) < 0.01)
    }

    @Test("EV to Equity - with minority interest")
    func evToEquityWithMinorityInterest() throws {
        // Given: Company with subsidiaries (minority shareholders)
        let bridge = EnterpriseValueBridge(
            enterpriseValue: 1000.0,
            totalDebt: 200.0,
            cash: 50.0,
            nonOperatingAssets: 0.0,
            minorityInterest: 75.0,  // Value attributable to minority shareholders
            preferredStock: 0.0
        )

        // When: Calculate equity value
        let equityValue = bridge.equityValue()

        // Then: Equity = EV - Net Debt - Minority Interest
        // = 1000 - 150 - 75 = 775
        #expect(abs(equityValue - 775.0) < 0.01)
    }

    @Test("EV to Equity - with preferred stock")
    func evToEquityWithPreferredStock() throws {
        // Given: Company with preferred equity
        let bridge = EnterpriseValueBridge(
            enterpriseValue: 1000.0,
            totalDebt: 200.0,
            cash: 50.0,
            nonOperatingAssets: 0.0,
            minorityInterest: 0.0,
            preferredStock: 100.0  // Preferred stock value
        )

        // When: Calculate equity value (common equity)
        let equityValue = bridge.equityValue()

        // Then: Common Equity = EV - Net Debt - Preferred
        // = 1000 - 150 - 100 = 750
        #expect(abs(equityValue - 750.0) < 0.01)
    }

    @Test("EV to Equity - comprehensive with all adjustments")
    func evToEquityComprehensive() throws {
        // Given: Complex capital structure
        let bridge = EnterpriseValueBridge(
            enterpriseValue: 5000.0,
            totalDebt: 1500.0,
            cash: 300.0,
            nonOperatingAssets: 200.0,
            minorityInterest: 150.0,
            preferredStock: 250.0
        )

        // When: Calculate equity value
        let equityValue = bridge.equityValue()

        // Then: Equity = EV - (Debt - Cash) + Non-Op - Minority - Preferred
        // = 5000 - (1500 - 300) + 200 - 150 - 250
        // = 5000 - 1200 + 200 - 150 - 250 = 3600
        #expect(abs(equityValue - 3600.0) < 0.01)
    }

    // MARK: - Breakdown Tests

    @Test("Bridge breakdown - detailed waterfall")
    func bridgeBreakdown() throws {
        // Given: Company with complex capital structure
        let bridge = EnterpriseValueBridge(
            enterpriseValue: 5000.0,
            totalDebt: 1500.0,
            cash: 300.0,
            nonOperatingAssets: 200.0,
            minorityInterest: 150.0,
            preferredStock: 250.0
        )

        // When: Get detailed breakdown
        let breakdown = bridge.breakdown()

        // Then: All components should be correct
        #expect(abs(breakdown.enterpriseValue - 5000.0) < 0.01)
        #expect(abs(breakdown.totalDebt - 1500.0) < 0.01)
        #expect(abs(breakdown.cash - 300.0) < 0.01)
        #expect(abs(breakdown.netDebt - 1200.0) < 0.01)  // 1500 - 300
        #expect(abs(breakdown.nonOperatingAssets - 200.0) < 0.01)
        #expect(abs(breakdown.minorityInterest - 150.0) < 0.01)
        #expect(abs(breakdown.preferredStock - 250.0) < 0.01)
        #expect(abs(breakdown.equityValue - 3600.0) < 0.01)
    }

    // MARK: - Value Per Share Tests

    @Test("Value per share calculation")
    func valuePerShare() throws {
        // Given: Enterprise value and shares
        let bridge = EnterpriseValueBridge(
            enterpriseValue: 1000.0,
            totalDebt: 200.0,
            cash: 50.0,
            nonOperatingAssets: 0.0,
            minorityInterest: 0.0,
            preferredStock: 0.0
        )

        // When: Calculate value per share with 100M shares
        let sharePrice = bridge.valuePerShare(sharesOutstanding: 100.0)

        // Then: Price = 850 / 100 = $8.50
        #expect(abs(sharePrice - 8.50) < 0.01)
    }

    // MARK: - Enterprise Value Calculation from FCFF

    @Test("Calculate EV from FCFF - single period")
    func calculateEVFromFCFFSinglePeriod() throws {
        // Given: Single period FCFF of $100M, 10% WACC, 3% growth
        let periods = [Period.year(2024)]
        let fcff = TimeSeries(periods: periods, values: [100.0])

        // When: Calculate enterprise value
        let ev = enterpriseValueFromFCFF(
            freeCashFlowToFirm: fcff,
            wacc: 0.10,
            terminalGrowthRate: 0.03
        )

        // Then: PV of Year 1 FCFF = 100 / 1.10 = 90.91
        // Terminal value = 100 * 1.03 / (0.10 - 0.03) = 1471.43
        // PV of Terminal: 1471.43 / 1.10 = 1337.66
        // Total EV = 90.91 + 1337.66 = 1428.57
        #expect(abs(ev - 1428.57) < 10.0)
    }

    @Test("Calculate EV from FCFF - multi-period")
    func calculateEVFromFCFFMultiPeriod() throws {
        // Given: 3-year FCFF projection
        let periods = [Period.year(2024), Period.year(2025), Period.year(2026)]
        let fcff = TimeSeries(periods: periods, values: [100.0, 110.0, 121.0])

        // When: Calculate enterprise value
        let ev = enterpriseValueFromFCFF(
            freeCashFlowToFirm: fcff,
            wacc: 0.10,
            terminalGrowthRate: 0.03
        )

        // Then: PV of explicit + PV of terminal
        #expect(ev > 1500.0)
        #expect(ev < 2000.0)
    }

    @Test("Round-trip: FCFF → EV → Equity → Per Share")
    func roundTripValuation() throws {
        // Given: Complete valuation scenario
        let periods = [Period.year(2024), Period.year(2025)]
        let fcff = TimeSeries(periods: periods, values: [150.0, 165.0])

        // Step 1: Calculate Enterprise Value
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
            minorityInterest: 0.0,
            preferredStock: 0.0
        )

        let equityValue = bridge.equityValue()

        // Step 3: Calculate per share
        let sharePrice = bridge.valuePerShare(sharesOutstanding: 100.0)

        // Then: All values should be reasonable
        #expect(ev > 2000.0)  // Substantial EV
        #expect(equityValue < ev)  // Equity < EV due to net debt
        #expect(sharePrice > 15.0)  // Reasonable share price
    }

    // MARK: - Edge Cases

    @Test("Zero enterprise value")
    func zeroEnterpriseValue() throws {
        // Given: Company with zero/negative operating value
        let bridge = EnterpriseValueBridge(
            enterpriseValue: 0.0,
            totalDebt: 100.0,
            cash: 50.0,
            nonOperatingAssets: 0.0,
            minorityInterest: 0.0,
            preferredStock: 0.0
        )

        // When: Calculate equity value
        let equityValue = bridge.equityValue()

        // Then: Negative equity (net debt exceeds operating value)
        // = 0 - (100 - 50) = -50
        #expect(equityValue < 0)
        #expect(abs(equityValue - (-50.0)) < 0.01)
    }

    @Test("No debt, no cash - pure EV = Equity")
    func pureEquityCompany() throws {
        // Given: All-equity company
        let bridge = EnterpriseValueBridge(
            enterpriseValue: 1000.0,
            totalDebt: 0.0,
            cash: 0.0,
            nonOperatingAssets: 0.0,
            minorityInterest: 0.0,
            preferredStock: 0.0
        )

        // When: Calculate equity value
        let equityValue = bridge.equityValue()

        // Then: Equity = EV (no adjustments)
        #expect(abs(equityValue - 1000.0) < 0.01)
    }

    // MARK: - Generic Type Tests

    @Test("Bridge with Float type")
    func bridgeWithFloat() throws {
        // Given: Bridge using Float
        let bridge = EnterpriseValueBridge<Float>(
            enterpriseValue: 1000.0,
            totalDebt: 200.0,
            cash: 50.0,
            nonOperatingAssets: 0.0,
            minorityInterest: 0.0,
            preferredStock: 0.0
        )

        // When: Calculate equity value
        let equityValue = bridge.equityValue()

        // Then: Should work with Float
        #expect(abs(equityValue - 850.0) < 0.1)
    }

    // MARK: - Comparison with FCFE

    @Test("Compare EV bridge with direct FCFE valuation")
    func compareEVBridgeWithFCFE() throws {
        // Given: Same company valued two ways

        // Method 1: FCFF → EV → Equity
        let fcffPeriods = [Period.year(2024)]
        let fcff = TimeSeries(periods: fcffPeriods, values: [150.0])
        let ev = enterpriseValueFromFCFF(
            freeCashFlowToFirm: fcff,
            wacc: 0.10,
            terminalGrowthRate: 0.03
        )

        let bridge = EnterpriseValueBridge(
            enterpriseValue: ev,
            totalDebt: 300.0,
            cash: 50.0,
            nonOperatingAssets: 0.0,
            minorityInterest: 0.0,
            preferredStock: 0.0
        )
        let equityFromBridge = bridge.equityValue()

        // Method 2: Direct FCFE (FCFF - interest + net borrowing ≈ FCFE)
        // For comparison, assume FCFE ≈ 130 (simplified)
        let fcfePeriods = [Period.year(2024)]
        let operatingCF = TimeSeries(periods: fcfePeriods, values: [150.0])
        let capEx = TimeSeries(periods: fcfePeriods, values: [20.0])

        let fcfeModel = FCFEModel(
            operatingCashFlow: operatingCF,
            capitalExpenditures: capEx,
            netBorrowing: nil,
            costOfEquity: 0.11,
            terminalGrowthRate: 0.03
        )
        let equityFromFCFE = try fcfeModel.equityValue()

        // Then: Both methods should yield reasonable equity values
        // (May differ due to different assumptions, but both should be positive)
        #expect(equityFromBridge > 1000.0)
        #expect(equityFromFCFE > 1000.0)
    }
}

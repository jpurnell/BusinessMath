import Testing
import Foundation
@testable import BusinessMath

/// Comprehensive tests for capital structure and WACC calculations
//@Suite("Capital Structure Tests")
//struct CapitalStructureTests {
//
//    // MARK: - WACC Calculation
//
//    @Test("WACC basic calculation")
//    func waccBasicCalculation() throws {
//        // Company with 60% equity, 40% debt
//        // Cost of equity: 12%, Cost of debt: 6%, Tax rate: 25%
//        let equityValue = 600_000.0
//        let debtValue = 400_000.0
//        let costOfEquity = 0.12
//        let costOfDebt = 0.06
//        let taxRate = 0.25
//
//        let result = wacc(
//            equityValue: equityValue,
//            debtValue: debtValue,
//            costOfEquity: costOfEquity,
//            costOfDebt: costOfDebt,
//            taxRate: taxRate
//        )
//
//        // WACC = (E/(E+D)) * Re + (D/(E+D)) * Rd * (1-T)
//        // = 0.6 * 0.12 + 0.4 * 0.06 * 0.75
//        // = 0.072 + 0.018 = 0.09 (9%)
//        let expected = 0.09
//        #expect(abs(result - expected) < 0.0001)
//    }
//
//    @Test("WACC with no debt - equals cost of equity")
//    func waccNoDebt() throws {
//        let equityValue = 1_000_000.0
//        let costOfEquity = 0.15
//
//        let result = wacc(
//            equityValue: equityValue,
//            debtValue: 0.0,
//            costOfEquity: costOfEquity,
//            costOfDebt: 0.05, // Irrelevant
//            taxRate: 0.30
//        )
//
//        // With no debt, WACC = cost of equity
//        #expect(abs(result - costOfEquity) < 0.0001)
//    }
//
//    @Test("WACC with high leverage")
//    func waccHighLeverage() throws {
//        // 80% debt, 20% equity
//        let equityValue = 200_000.0
//        let debtValue = 800_000.0
//        let costOfEquity = 0.18 // Higher due to financial risk
//        let costOfDebt = 0.08
//        let taxRate = 0.30
//
//        let result = wacc(
//            equityValue: equityValue,
//            debtValue: debtValue,
//            costOfEquity: costOfEquity,
//            costOfDebt: costOfDebt,
//            taxRate: taxRate
//        )
//
//        // WACC = 0.2 * 0.18 + 0.8 * 0.08 * 0.7
//        // = 0.036 + 0.0448 = 0.0808 (8.08%)
//        let expected = 0.0808
//        #expect(abs(result - expected) < 0.0001)
//    }
//
//    @Test("WACC tax shield benefit")
//    func waccTaxShieldBenefit() throws {
//        // Compare same structure with different tax rates
//        let equityValue = 500_000.0
//        let debtValue = 500_000.0
//        let costOfEquity = 0.14
//        let costOfDebt = 0.07
//
//        let waccNoTax = wacc(
//            equityValue: equityValue,
//            debtValue: debtValue,
//            costOfEquity: costOfEquity,
//            costOfDebt: costOfDebt,
//            taxRate: 0.0
//        )
//
//        let waccWithTax = wacc(
//            equityValue: equityValue,
//            debtValue: debtValue,
//            costOfEquity: costOfEquity,
//            costOfDebt: costOfDebt,
//            taxRate: 0.30
//        )
//
//        // WACC with tax should be lower (tax shield on debt)
//        #expect(waccWithTax < waccNoTax)
//
//        // Difference should equal: 0.5 * 0.07 * 0.30 = 0.0105
//        let expectedDifference = 0.0105
//        #expect(abs((waccNoTax - waccWithTax) - expectedDifference) < 0.0001)
//    }
//
//    // MARK: - CapitalStructure Type
//
//    @Test("CapitalStructure computed properties")
//    func capitalStructureProperties() throws {
//        let structure = CapitalStructure(
//            debtValue: 300_000.0,
//            equityValue: 700_000.0,
//            costOfDebt: 0.06,
//            costOfEquity: 0.13,
//            taxRate: 0.25
//        )
//
//        // WACC
//        let expectedWACC = 0.7 * 0.13 + 0.3 * 0.06 * 0.75
//        #expect(abs(structure.wacc - expectedWACC) < 0.0001)
//
//        // Debt ratio
//        #expect(abs(structure.debtRatio - 0.30) < 0.0001)
//
//        // Equity ratio
//        #expect(abs(structure.equityRatio - 0.70) < 0.0001)
//
//        // Total value
//        #expect(abs(structure.totalValue - 1_000_000.0) < 0.01)
//    }
//
//    @Test("CapitalStructure debt-to-equity ratio")
//    func capitalStructureDebtToEquity() throws {
//        let structure = CapitalStructure(
//            debtValue: 400_000.0,
//            equityValue: 600_000.0,
//            costOfDebt: 0.05,
//            costOfEquity: 0.12,
//            taxRate: 0.30
//        )
//
//        // D/E = 400/600 = 0.6667
//        let expectedDE = 400_000.0 / 600_000.0
//        #expect(abs(structure.debtToEquityRatio - expectedDE) < 0.0001)
//    }
//
//    // MARK: - CAPM (Capital Asset Pricing Model)
//
//    @Test("CAPM basic calculation")
//    func capmBasicCalculation() throws {
//        let riskFreeRate = 0.03
//        let beta = 1.2
//        let marketReturn = 0.10
//
//        let costOfEquity = capm(
//            riskFreeRate: riskFreeRate,
//            beta: beta,
//            marketReturn: marketReturn
//        )
//
//        // Expected: 0.03 + 1.2 * (0.10 - 0.03) = 0.03 + 0.084 = 0.114 (11.4%)
//        let expected = 0.114
//        #expect(abs(costOfEquity - expected) < 0.0001)
//    }
//
//    @Test("CAPM with beta = 1 equals market return")
//    func capmBetaOne() throws {
//        let riskFreeRate = 0.025
//        let marketReturn = 0.095
//
//        let costOfEquity = capm(
//            riskFreeRate: riskFreeRate,
//            beta: 1.0,
//            marketReturn: marketReturn
//        )
//
//        // With beta = 1, expected return = market return
//        #expect(abs(costOfEquity - marketReturn) < 0.0001)
//    }
//
//    @Test("CAPM with beta = 0 equals risk-free rate")
//    func capmBetaZero() throws {
//        let riskFreeRate = 0.03
//        let marketReturn = 0.10
//
//        let costOfEquity = capm(
//            riskFreeRate: riskFreeRate,
//            beta: 0.0,
//            marketReturn: marketReturn
//        )
//
//        // With beta = 0, expected return = risk-free rate
//        #expect(abs(costOfEquity - riskFreeRate) < 0.0001)
//    }
//
//    @Test("CAPM with high beta - amplified returns")
//    func capmHighBeta() throws {
//        let riskFreeRate = 0.03
//        let marketReturn = 0.10
//        let highBeta = 2.0
//
//        let costOfEquity = capm(
//            riskFreeRate: riskFreeRate,
//            beta: highBeta,
//            marketReturn: marketReturn
//        )
//
//        // Expected: 0.03 + 2.0 * 0.07 = 0.17 (17%)
//        let expected = 0.17
//        #expect(abs(costOfEquity - expected) < 0.0001)
//    }
//
//    @Test("CAPM with low beta - dampened returns")
//    func capmLowBeta() throws {
//        let riskFreeRate = 0.03
//        let marketReturn = 0.10
//        let lowBeta = 0.5
//
//        let costOfEquity = capm(
//            riskFreeRate: riskFreeRate,
//            beta: lowBeta,
//            marketReturn: marketReturn
//        )
//
//        // Expected: 0.03 + 0.5 * 0.07 = 0.065 (6.5%)
//        let expected = 0.065
//        #expect(abs(costOfEquity - expected) < 0.0001)
//    }
//
//    // MARK: - Beta Levering/Unlevering
//
//    @Test("Unlever beta - remove financial leverage")
//    func unleverBeta() throws {
//        let leveredBeta = 1.5
//        let debtToEquity = 0.5
//        let taxRate = 0.30
//
//        let unleveredBeta = unleverBeta(
//            leveredBeta: leveredBeta,
//            debtToEquityRatio: debtToEquity,
//            taxRate: taxRate
//        )
//
//        // βU = βL / [1 + (1-T) * D/E]
//        // = 1.5 / [1 + 0.7 * 0.5]
//        // = 1.5 / 1.35 = 1.111
//        let expected = 1.5 / (1.0 + 0.7 * 0.5)
//        #expect(abs(unleveredBeta - expected) < 0.001)
//    }
//
//    @Test("Lever beta - add financial leverage")
//    func leverBeta() throws {
//        let unleveredBeta = 1.0
//        let debtToEquity = 1.0
//        let taxRate = 0.25
//
//        let leveredBeta = leverBeta(
//            unleveredBeta: unleveredBeta,
//            debtToEquityRatio: debtToEquity,
//            taxRate: taxRate
//        )
//
//        // βL = βU * [1 + (1-T) * D/E]
//        // = 1.0 * [1 + 0.75 * 1.0]
//        // = 1.75
//        let expected = 1.0 * (1.0 + 0.75 * 1.0)
//        #expect(abs(leveredBeta - expected) < 0.001)
//    }
//
//    @Test("Lever then unlever beta - round trip")
//    func leverUnleverRoundTrip() throws {
//        let originalBeta = 1.2
//        let debtToEquity = 0.6
//        let taxRate = 0.30
//
//        // Unlever
//        let unlevered = unleverBeta(
//            leveredBeta: originalBeta,
//            debtToEquityRatio: debtToEquity,
//            taxRate: taxRate
//        )
//
//        // Re-lever
//        let relevered = leverBeta(
//            unleveredBeta: unlevered,
//            debtToEquityRatio: debtToEquity,
//            taxRate: taxRate
//        )
//
//        // Should get back original beta
//        #expect(abs(relevered - originalBeta) < 0.0001)
//    }
//
//    @Test("Unlever beta with no debt equals levered beta")
//    func unleverBetaNoDeb() throws {
//        let leveredBeta = 1.3
//
//        let unlevered = unleverBeta(
//            leveredBeta: leveredBeta,
//            debtToEquityRatio: 0.0,
//            taxRate: 0.30
//        )
//
//        // With no debt, unlevered = levered
//        #expect(abs(unlevered - leveredBeta) < 0.0001)
//    }
//
//    // MARK: - Optimal Capital Structure
//
//    @Test("Optimal capital structure - minimize WACC")
//    func optimalCapitalStructure() throws {
//        // Test different D/E ratios to find minimum WACC
//        let equityValue = 1_000_000.0
//        let taxRate = 0.30
//        let baseCostOfEquity = 0.10
//        let baseCostOfDebt = 0.05
//
//        var minWACC = Double.infinity
//        var optimalDebtRatio = 0.0
//
//        // Test debt ratios from 0% to 80%
//        for debtRatio in stride(from: 0.0, through: 0.8, by: 0.1) {
//            let debtValue = (equityValue * debtRatio) / (1.0 - debtRatio)
//
//            // Cost of equity increases with leverage (simplified model)
//            let costOfEquity = baseCostOfEquity + (debtRatio * 0.05)
//
//            // Cost of debt increases with leverage
//            let costOfDebt = baseCostOfDebt + (debtRatio * 0.02)
//
//            let currentWACC = wacc(
//                equityValue: equityValue,
//                debtValue: debtValue,
//                costOfEquity: costOfEquity,
//                costOfDebt: costOfDebt,
//                taxRate: taxRate
//            )
//
//            if currentWACC < minWACC {
//                minWACC = currentWACC
//                optimalDebtRatio = debtRatio
//            }
//        }
//
//        // Should find an optimal point (not 0% or 80%)
//        #expect(optimalDebtRatio > 0.0)
//        #expect(optimalDebtRatio < 0.8)
//    }
//
//    // MARK: - After-Tax Cost of Debt
//
//    @Test("After-tax cost of debt")
//    func afterTaxCostOfDebt() throws {
//        let pretaxCostOfDebt = 0.08
//        let taxRate = 0.30
//
//        let afterTax = afterTaxCostOfDebt(
//            pretaxCost: pretaxCostOfDebt,
//            taxRate: taxRate
//        )
//
//        // After-tax = pretax * (1 - T) = 0.08 * 0.7 = 0.056
//        let expected = 0.056
//        #expect(abs(afterTax - expected) < 0.0001)
//    }
//
//    @Test("After-tax cost of debt with zero tax")
//    func afterTaxCostOfDebtZeroTax() throws {
//        let pretaxCost = 0.07
//
//        let afterTax = afterTaxCostOfDebt(
//            pretaxCost: pretaxCost,
//            taxRate: 0.0
//        )
//
//        // With no tax, after-tax = pretax
//        #expect(abs(afterTax - pretaxCost) < 0.0001)
//    }
//
//    // MARK: - Market Value vs Book Value
//
//    @Test("WACC using market values")
//    func waccMarketValues() throws {
//        // Market value differs from book value
//        let structure = CapitalStructure(
//            debtValue: 500_000.0,      // Market value
//            equityValue: 1_500_000.0,  // Market value (stock price * shares)
//            costOfDebt: 0.06,
//            costOfEquity: 0.14,
//            taxRate: 0.25
//        )
//
//        // WACC should use market values, not book
//        let expectedWACC = (1_500_000.0 / 2_000_000.0) * 0.14 +
//                          (500_000.0 / 2_000_000.0) * 0.06 * 0.75
//
//        #expect(abs(structure.wacc - expectedWACC) < 0.0001)
//    }
//
//    // MARK: - Weighted Cost Components
//
//    @Test("Equity component of WACC")
//    func equityComponentWACC() throws {
//        let structure = CapitalStructure(
//            debtValue: 400_000.0,
//            equityValue: 600_000.0,
//            costOfDebt: 0.05,
//            costOfEquity: 0.12,
//            taxRate: 0.30
//        )
//
//        let equityComponent = structure.equityWeight * structure.costOfEquity
//
//        // Should be 0.6 * 0.12 = 0.072
//        let expected = 0.072
//        #expect(abs(equityComponent - expected) < 0.0001)
//    }
//
//    @Test("Debt component of WACC")
//    func debtComponentWACC() throws {
//        let structure = CapitalStructure(
//            debtValue: 400_000.0,
//            equityValue: 600_000.0,
//            costOfDebt: 0.05,
//            costOfEquity: 0.12,
//            taxRate: 0.30
//        )
//
//        let debtComponent = structure.debtWeight * structure.afterTaxCostOfDebt
//
//        // Should be 0.4 * 0.05 * 0.7 = 0.014
//        let expected = 0.014
//        #expect(abs(debtComponent - expected) < 0.0001)
//    }
//
//    // MARK: - Modigliani-Miller Propositions
//
//    @Test("M&M Proposition I - with taxes")
//    func modiglianiMillerWithTaxes() throws {
//        // VL = VU + T * D
//        // Value of levered firm = Value of unlevered + Tax shield
//
//        let unleveredValue = 1_000_000.0
//        let debtValue = 300_000.0
//        let taxRate = 0.30
//
//        let leveredValue = modiglianiMillerValue(
//            unleveredValue: unleveredValue,
//            debtValue: debtValue,
//            taxRate: taxRate
//        )
//
//        // VL = 1,000,000 + 0.3 * 300,000 = 1,090,000
//        let expected = 1_090_000.0
//        #expect(abs(leveredValue - expected) < 1.0)
//    }
//
//    @Test("M&M Proposition I - no taxes")
//    func modiglianiMillerNoTaxes() throws {
//        let unleveredValue = 1_000_000.0
//        let debtValue = 400_000.0
//
//        let leveredValue = modiglianiMillerValue(
//            unleveredValue: unleveredValue,
//            debtValue: debtValue,
//            taxRate: 0.0
//        )
//
//        // With no taxes, VL = VU
//        #expect(abs(leveredValue - unleveredValue) < 1.0)
//    }
//
//    // MARK: - Target Capital Structure
//
//    @Test("Adjust to target capital structure")
//    func adjustToTargetStructure() throws {
//        let currentStructure = CapitalStructure(
//            debtValue: 300_000.0,
//            equityValue: 700_000.0,
//            costOfDebt: 0.06,
//            costOfEquity: 0.13,
//            taxRate: 0.25
//        )
//
//        // Target: 40% debt, 60% equity
//        let targetDebtRatio = 0.40
//
//        let adjustment = currentStructure.adjustmentToTarget(
//            targetDebtRatio: targetDebtRatio
//        )
//
//        // Need to increase debt or reduce equity
//        #expect(adjustment.debtChange > 0.0 || adjustment.equityChange < 0.0)
//    }
//
//    // MARK: - Comparative Analysis
//
//    @Test("Compare two capital structures")
//    func compareTwoStructures() throws {
//        let conservative = CapitalStructure(
//            debtValue: 200_000.0,
//            equityValue: 800_000.0,
//            costOfDebt: 0.05,
//            costOfEquity: 0.11,
//            taxRate: 0.30
//        )
//
//        let aggressive = CapitalStructure(
//            debtValue: 600_000.0,
//            equityValue: 400_000.0,
//            costOfDebt: 0.07,
//            costOfEquity: 0.16,
//            taxRate: 0.30
//        )
//
//        // Aggressive has higher leverage
//        #expect(aggressive.debtRatio > conservative.debtRatio)
//
//        // Conservative likely has lower WACC (depends on tax shield)
//        // But test that both are reasonable
//        #expect(conservative.wacc > 0.05)
//        #expect(conservative.wacc < 0.15)
//        #expect(aggressive.wacc > 0.05)
//        #expect(aggressive.wacc < 0.15)
//    }
//
//    // MARK: - Industry Comparisons
//
//    @Test("Tech company - low debt structure")
//    func techCompanyStructure() throws {
//        // Tech companies typically have low debt
//        let techCo = CapitalStructure(
//            debtValue: 100_000.0,
//            equityValue: 900_000.0,
//            costOfDebt: 0.04,
//            costOfEquity: 0.15,
//            taxRate: 0.21
//        )
//
//        // Debt ratio should be low
//        #expect(techCo.debtRatio < 0.20)
//
//        // WACC should be close to cost of equity
//        #expect(abs(techCo.wacc - techCo.costOfEquity) < 0.02)
//    }
//
//    @Test("Utility company - high debt structure")
//    func utilityCompanyStructure() throws {
//        // Utilities typically have high, stable debt
//        let utility = CapitalStructure(
//            debtValue: 600_000.0,
//            equityValue: 400_000.0,
//            costOfDebt: 0.05,
//            costOfEquity: 0.09,
//            taxRate: 0.25
//        )
//
//        // Debt ratio should be high
//        #expect(utility.debtRatio > 0.50)
//
//        // WACC should benefit from tax shield
//        #expect(utility.wacc < utility.costOfEquity)
//    }
//}

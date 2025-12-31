//
//  ValuationBuilderTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-30.
//

import Testing
import Foundation
@testable import BusinessMathDSL

/// Tests for Valuation (DCF) Result Builder (DSL)
///
/// Following TDD:
/// - RED: Write failing tests first
/// - GREEN: Implement to make tests pass
/// - REFACTOR: Clean up implementation
@Suite("Valuation Builder Tests (DSL)")
struct ValuationBuilderTests {

    // MARK: - Basic Forecast Tests

    @Test("Simple revenue forecast with CAGR")
    func simpleForecast() async throws {
        let forecast = Forecast( 5) {
            ForecastRevenue(base: 1_000_000, cagr: 0.15)
        }

        #expect(forecast.years == 5)

        // Year 1: 1,000,000
        // Year 2: 1,150,000
        // Year 3: 1,322,500
        // Year 4: 1,520,875
        // Year 5: 1,749,006
        let revenues = forecast.projectedRevenues
        #expect(abs(revenues[0] - 1_000_000) < 1)
        #expect(abs(revenues[1] - 1_150_000) < 1)
        #expect(abs(revenues[2] - 1_322_500) < 1)
        #expect(abs(revenues[3] - 1_520_875) < 1)
        #expect(abs(revenues[4] - 1_749_006) < 1)
    }

    @Test("Forecast with EBITDA margin")
    func forecastWithMargin() async throws {
        let forecast = Forecast( 3) {
            ForecastRevenue(base: 1_000_000, cagr: 0.10)
            EBITDA(margin: 0.25)  // 25% margin
        }

        let ebitdaValues = forecast.projectedEBITDA
        // Year 1: 1M * 0.25 = 250,000
        // Year 2: 1.1M * 0.25 = 275,000
        // Year 3: 1.21M * 0.25 = 302,500
        #expect(abs(ebitdaValues[0] - 250_000) < 1)
        #expect(abs(ebitdaValues[1] - 275_000) < 1)
        #expect(abs(ebitdaValues[2] - 302_500) < 1)
    }

    @Test("Forecast with CapEx as percentage of revenue")
    func forecastWithCapEx() async throws {
        let forecast = Forecast( 3) {
            ForecastRevenue(base: 1_000_000, cagr: 0.10)
            CapEx(percentage: 0.08)  // 8% of revenue
        }

        let capexValues = forecast.projectedCapEx
        // Year 1: 1M * 0.08 = 80,000
        // Year 2: 1.1M * 0.08 = 88,000
        // Year 3: 1.21M * 0.08 = 96,800
        #expect(abs(capexValues[0] - 80_000) < 1)
        #expect(abs(capexValues[1] - 88_000) < 1)
        #expect(abs(capexValues[2] - 96_800) < 1)
    }

    @Test("Forecast with working capital requirements")
    func forecastWithWorkingCapital() async throws {
        let forecast = Forecast( 3) {
            ForecastRevenue(base: 1_000_000, cagr: 0.10)
            WorkingCapital(daysOfSales: 45)  // 45 days of sales tied up
        }

        let wcChanges = forecast.workingCapitalChanges
        // WC = Revenue * (45/365)
        // Year 1: 1M * 45/365 = 123,288
        // Year 2 WC: 1.1M * 45/365 = 135,616
        // Change in Year 2: 135,616 - 123,288 = 12,329
        #expect(abs(wcChanges[0] - 123_288) < 10)  // Initial WC investment
        #expect(abs(wcChanges[1] - 12_329) < 10)   // Incremental change
    }

    @Test("Complete forecast with all components")
    func completeForecast() async throws {
        let forecast = Forecast( 5) {
            ForecastRevenue(base: 1_000_000, cagr: 0.15)
            EBITDA(margin: 0.25)
            ForecastDepreciation(percentage: 0.05)  // 5% of revenue
            CapEx(percentage: 0.08)
            WorkingCapital(daysOfSales: 45)
        }

        // Verify free cash flow calculation
        // FCF = EBITDA - D&A - CapEx - ΔWC (but D&A is added back, so effectively EBITDA - CapEx - ΔWC)
        let fcf = forecast.freeCashFlows
        #expect(fcf.count == 5)
        #expect(fcf[0] > 0)  // Should be positive cash flow
    }

    // MARK: - Terminal Value Tests

    @Test("Terminal value using perpetual growth method")
    func terminalValuePerpetualGrowth() async throws {
        let terminal = TerminalValue {
            PerpetualGrowth(rate: 0.03)
        }

        // Terminal Value = FCF_final * (1 + g) / (WACC - g)
        // With FCF = 200,000, WACC = 0.10, g = 0.03
        // TV = 200,000 * 1.03 / (0.10 - 0.03) = 206,000 / 0.07 = 2,942,857
        let tv = terminal.calculate(finalFCF: 200_000, wacc: 0.10)
        #expect(abs(tv - 2_942_857) < 10)
    }

    @Test("Terminal value using exit multiple method")
    func terminalValueExitMultiple() async throws {
        let terminal = TerminalValue {
            ExitMultiple(evEbitda: 10.0)
        }

        // Terminal Value = Final EBITDA * Multiple
        // With EBITDA = 300,000, Multiple = 10x
        // TV = 300,000 * 10 = 3,000,000
        let tv = terminal.calculate(finalEBITDA: 300_000)
        #expect(tv == 3_000_000)
    }

    // MARK: - WACC Tests

    @Test("Simple WACC calculation")
    func simpleWACC() async throws {
        let wacc = WACC {
            CostOfEquity(0.12)      // 12%
            CostOfDebt(0.05)        // 5% (pre-tax)
            TaxRate(0.21)           // 21%
            DebtToEquity(0.30)      // 30% debt, 70% equity
        }

        // WACC = E/(D+E) * Re + D/(D+E) * Rd * (1-T)
        // E/(D+E) = 0.70, D/(D+E) = 0.30
        // WACC = 0.70 * 0.12 + 0.30 * 0.05 * 0.79
        // WACC = 0.084 + 0.01185 = 0.09585 (9.585%)
        let calculated = wacc.rate
        #expect(abs(calculated - 0.09585) < 0.0001)
    }

    @Test("WACC with after-tax debt cost")
    func waccAfterTax() async throws {
        let wacc = WACC {
            CostOfEquity(0.12)
            AfterTaxCostOfDebt(0.04)  // Already after-tax
            DebtToEquity(0.40)        // 40% debt, 60% equity
        }

        // WACC = 0.60 * 0.12 + 0.40 * 0.04
        // WACC = 0.072 + 0.016 = 0.088 (8.8%)
        let calculated = wacc.rate
        #expect(abs(calculated - 0.088) < 0.0001)
    }

    // MARK: - Full DCF Model Tests

    @Test("Complete DCF valuation")
    func completeDCFValuation() async throws {
        let dcf = DCFModel {
            Forecast( 5) {
                ForecastRevenue(base: 1_000_000, cagr: 0.15)
                EBITDA(margin: 0.25)
                CapEx(percentage: 0.08)
                WorkingCapital(daysOfSales: 45)
            }

            TerminalValue {
                PerpetualGrowth(rate: 0.03)
            }

            WACC {
                CostOfEquity(0.12)
                CostOfDebt(0.05)
                TaxRate(0.21)
                DebtToEquity(0.30)
            }
        }

        let valuation = dcf.calculateEnterpriseValue()

        // Should have positive enterprise value
        #expect(valuation.enterpriseValue > 0)
        #expect(valuation.terminalValue > 0)
        #expect(valuation.presentValueOfFCF > 0)
        #expect(valuation.presentValueOfTerminalValue > 0)
    }

    @Test("DCF with exit multiple terminal value")
    func dcfWithExitMultiple() async throws {
        let dcf = DCFModel {
            Forecast( 5) {
                ForecastRevenue(base: 1_000_000, cagr: 0.15)
                EBITDA(margin: 0.25)
                CapEx(percentage: 0.08)
            }

            TerminalValue {
                ExitMultiple(evEbitda: 10.0)
            }

            WACC {
                CostOfEquity(0.12)
                AfterTaxCostOfDebt(0.04)
                DebtToEquity(0.30)
            }
        }

        let valuation = dcf.calculateEnterpriseValue()
        #expect(valuation.enterpriseValue > 0)
    }

    // MARK: - Sensitivity Analysis Tests

    @Test("DCF sensitivity to WACC changes")
    func dcfSensitivityToWACC() async throws {
        let baseWACC = 0.10
        let values = [0.08, 0.10, 0.12].map { waccRate in
            let dcf = DCFModel {
                Forecast( 5) {
                    ForecastRevenue(base: 1_000_000, cagr: 0.15)
                    EBITDA(margin: 0.25)
                    CapEx(percentage: 0.08)
                }

                TerminalValue {
                    PerpetualGrowth(rate: 0.03)
                }

                WACC {
                    CustomRate(waccRate)
                }
            }
            return dcf.calculateEnterpriseValue().enterpriseValue
        }

        // Higher WACC should result in lower valuation
        #expect(values[0] > values[1])  // 8% > 10%
        #expect(values[1] > values[2])  // 10% > 12%
    }

    @Test("DCF sensitivity to growth rate changes")
    func dcfSensitivityToGrowth() async throws {
        let values = [0.10, 0.15, 0.20].map { growthRate in
            let dcf = DCFModel {
                Forecast( 5) {
                    ForecastRevenue(base: 1_000_000, cagr: growthRate)
                    EBITDA(margin: 0.25)
                    CapEx(percentage: 0.08)
                }

                TerminalValue {
                    PerpetualGrowth(rate: 0.03)
                }

                WACC {
                    CustomRate(0.10)
                }
            }
            return dcf.calculateEnterpriseValue().enterpriseValue
        }

        // Higher growth should result in higher valuation
        #expect(values[0] < values[1])  // 10% < 15%
        #expect(values[1] < values[2])  // 15% < 20%
    }

    // MARK: - Integration with CashFlowModel Tests

    @Test("DCF using projected cash flows from CashFlowModel")
    func dcfWithCashFlowModel() async throws {
        // Create cash flow projection
        let projection = CashFlowModel(
            revenue: Revenue {
                Base(1_000_000)
                GrowthRate(0.15)
            },
            expenses: Expenses {
                Variable(percentage: 0.60)
            },
            taxes: Taxes {
                CorporateRate(0.21)
            }
        )

        // Use in DCF
        let dcf = DCFModel {
            FromCashFlowModel(projection, years: 5)

            TerminalValue {
                PerpetualGrowth(rate: 0.03)
            }

            WACC {
                CustomRate(0.10)
            }
        }

        let valuation = dcf.calculateEnterpriseValue()
        #expect(valuation.enterpriseValue > 0)
    }

    // MARK: - Edge Cases

    @Test("DCF with zero growth terminal value")
    func dcfZeroGrowth() async throws {
        let dcf = DCFModel {
            Forecast( 5) {
                ForecastRevenue(base: 1_000_000, cagr: 0.10)
                EBITDA(margin: 0.25)
            }

            TerminalValue {
                PerpetualGrowth(rate: 0.0)  // No growth
            }

            WACC {
                CustomRate(0.10)
            }
        }

        let valuation = dcf.calculateEnterpriseValue()
        #expect(valuation.enterpriseValue > 0)
    }

    @Test("DCF with high debt ratio")
    func dcfHighDebt() async throws {
        let wacc = WACC {
            CostOfEquity(0.15)      // Higher cost due to leverage
            CostOfDebt(0.06)
            TaxRate(0.21)
            DebtToEquity(0.70)      // 70% debt, 30% equity
        }

        // WACC = 0.30 * 0.15 + 0.70 * 0.06 * 0.79
        // WACC = 0.045 + 0.03318 = 0.07818
        #expect(abs(wacc.rate - 0.07818) < 0.0001)
    }

    @Test("DCF valuation summary with metrics")
    func dcfValuationMetrics() async throws {
        let dcf = DCFModel {
            Forecast( 5) {
                ForecastRevenue(base: 1_000_000, cagr: 0.15)
                EBITDA(margin: 0.25)
                CapEx(percentage: 0.08)
            }

            TerminalValue {
                ExitMultiple(evEbitda: 10.0)
            }

            WACC {
                CustomRate(0.10)
            }
        }

        let valuation = dcf.calculateEnterpriseValue()

        // Should provide detailed metrics
        #expect(valuation.forecastYears == 5)
        #expect(valuation.terminalValueMultiple > 0)
        #expect(valuation.wacc == 0.10)
    }
}

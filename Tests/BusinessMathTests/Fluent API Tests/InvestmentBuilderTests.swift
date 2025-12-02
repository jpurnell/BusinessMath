//
//  InvestmentBuilderTests.swift
//  BusinessMath
//
//  Created on November 30, 2025.
//

import Testing
import Foundation
@testable import BusinessMath

/// Comprehensive tests for the InvestmentBuilder fluent API
///
/// Tests cover:
/// - Builder syntax and DSL usage
/// - Cash flow arrow syntax (Year(1) => 30_000)
/// - Automatic metric calculations (NPV, IRR, PI, payback)
/// - Convenience constructors (simple, growing)
/// - Portfolio operations and ranking
/// - Investment comparison
/// - Edge cases and error conditions
@Suite("InvestmentBuilder DSL Tests")
struct InvestmentBuilderTests {

    // MARK: - Builder Syntax

    @Test("Basic investment builder")
    func basicInvestmentBuilder() {
        let investment = Investment {
            InitialCost(100_000)

            CashFlows {
                Year(1) => 30_000
                Year(2) => 35_000
                Year(3) => 40_000
            }

            DiscountRate(0.10)
        }

        #expect(investment.initialCost == 100_000)
        #expect(investment.cashFlows.count == 3)
        #expect(investment.discountRate == 0.10)
    }

    @Test("Investment with all components")
    func investmentWithAllComponents() {
        let investment = Investment {
            Name("Solar Panel Installation")
            Description("Residential solar installation project")
            InitialCost(50_000)

            CashFlows {
                Year(1) => 12_000
                Year(2) => 12_500
                Year(3) => 13_000
                Year(4) => 13_500
                Year(5) => 14_000
            }

            DiscountRate(0.08)
        }

        #expect(investment.name == "Solar Panel Installation")
        #expect(investment.investmentDescription == "Residential solar installation project")
        #expect(investment.initialCost == 50_000)
        #expect(investment.cashFlows.count == 5)
        #expect(investment.discountRate == 0.08)
    }

    @Test("Minimal investment")
    func minimalInvestment() {
        let investment = Investment {
            InitialCost(10_000)

            CashFlows {
                Year(1) => 5_000
                Year(2) => 6_000
            }
        }

        // Should use default 10% discount rate
        #expect(investment.discountRate == 0.10)
        #expect(investment.name == nil)
        #expect(investment.investmentDescription == nil)
    }

    // MARK: - Cash Flow Arrow Syntax

    @Test("Cash flow arrow syntax")
    func cashFlowArrowSyntax() {
        let cf = Year(1) => 25_000

        #expect(cf.period == 1)
        #expect(cf.amount == 25_000)
    }

    @Test("Multiple cash flows")
    func multipleCashFlows() {
        let investment = Investment {
            InitialCost(100_000)

            CashFlows {
                Year(1) => 20_000
                Year(2) => 25_000
                Year(3) => 30_000
                Year(4) => 35_000
                Year(5) => 40_000
                Year(6) => 45_000
            }

            DiscountRate(0.12)
        }

        #expect(investment.cashFlows.count == 6)
        #expect(investment.cashFlows[0].period == 1)
        #expect(investment.cashFlows[0].amount == 20_000)
        #expect(investment.cashFlows[5].period == 6)
        #expect(investment.cashFlows[5].amount == 45_000)
    }

    @Test("Cash flows automatically sorted")
    func cashFlowsSorted() {
        let investment = Investment {
            InitialCost(50_000)

            CashFlows {
                Year(3) => 15_000
                Year(1) => 10_000
                Year(4) => 20_000
                Year(2) => 12_000
            }

            DiscountRate(0.10)
        }

        // Cash flows should be sorted by period
        #expect(investment.cashFlows[0].period == 1)
        #expect(investment.cashFlows[1].period == 2)
        #expect(investment.cashFlows[2].period == 3)
        #expect(investment.cashFlows[3].period == 4)
    }

    // MARK: - Calculated Metrics

    @Test("NPV calculation accuracy")
    func npvCalculation() {
        let investment = Investment {
            InitialCost(100_000)

            CashFlows {
                Year(1) => 30_000
                Year(2) => 40_000
                Year(3) => 50_000
            }

            DiscountRate(0.10)
        }

        let npv = investment.npv

        // Expected: -100,000 + 30,000/1.1 + 40,000/1.21 + 50,000/1.331
        // = -100,000 + 27,272.73 + 33,057.85 + 37,565.74
        // = -2,103.68
        #expect(abs(npv - (-2103.68)) < 1.0) // Within $1
    }

    @Test("IRR calculation accuracy")
    func irrCalculation() {
        let investment = Investment {
            InitialCost(100_000)

            CashFlows {
                Year(1) => 30_000
                Year(2) => 40_000
                Year(3) => 60_000
            }

            DiscountRate(0.10)
        }

        guard let irr = investment.irr else {
            Issue.record("IRR should converge")
            return
        }

        // IRR should be around 12.7% for this investment
        // Total cash flows = 130k on 100k investment over 3 years
        #expect(irr > 0.12 && irr < 0.13)
    }

    @Test("Profitability index calculation")
    func profitabilityIndexCalculation() {
        let investment = Investment {
            InitialCost(100_000)

            CashFlows {
                Year(1) => 40_000
                Year(2) => 50_000
                Year(3) => 60_000
            }

            DiscountRate(0.10)
        }

        let pi = investment.profitabilityIndex

        // PV of cash flows / Initial cost
        // (40k/1.1 + 50k/1.21 + 60k/1.331) / 100k
        // (36,363.64 + 41,322.31 + 45,078.89) / 100k
        // = 122,764.84 / 100k = 1.2276
        #expect(abs(pi - 1.2276) < 0.01)
    }

    @Test("Payback period calculation")
    func paybackPeriodCalculation() {
        let investment = Investment {
            InitialCost(100_000)

            CashFlows {
                Year(1) => 30_000
                Year(2) => 40_000
                Year(3) => 50_000
            }

            DiscountRate(0.10)
        }

        guard let payback = investment.paybackPeriod else {
            Issue.record("Payback period should exist")
            return
        }

        // Cumulative: 30k (1), 70k (2), 120k (3)
        // Payback occurs during year 3
        // 30k + 40k = 70k after year 2
        // Need 30k more, get 50k in year 3
        // 2 + (30k / 50k) = 2.6 years
        #expect(abs(payback - 2.6) < 0.01)
    }

    @Test("Discounted payback period calculation")
    func discountedPaybackPeriodCalculation() {
        let investment = Investment {
            InitialCost(100_000)

            CashFlows {
                Year(1) => 40_000
                Year(2) => 50_000
                Year(3) => 60_000
            }

            DiscountRate(0.10)
        }

        guard let discountedPayback = investment.discountedPaybackPeriod else {
            Issue.record("Discounted payback period should exist")
            return
        }

        // PV cumulative: 36,363.64 (1), 77,685.95 (2), 122,764.84 (3)
        // Payback occurs during year 3
        #expect(discountedPayback > 2.0 && discountedPayback < 3.0)
    }

    @Test("Total ROI calculation")
    func totalROICalculation() {
        let investment = Investment {
            InitialCost(100_000)

            CashFlows {
                Year(1) => 50_000
                Year(2) => 60_000
                Year(3) => 70_000
            }

            DiscountRate(0.10)
        }

        let roi = investment.totalROI

        // (180k - 100k) / 100k = 0.80 or 80%
        #expect(abs(roi - 0.80) < 0.01)
    }

    @Test("Total cash inflows")
    func totalCashInflows() {
        let investment = Investment {
            InitialCost(100_000)

            CashFlows {
                Year(1) => 25_000
                Year(2) => 30_000
                Year(3) => 35_000
                Year(4) => 40_000
            }

            DiscountRate(0.10)
        }

        #expect(investment.totalCashInflows == 130_000)
    }

    // MARK: - Convenience Constructors

    @Test("Simple investment creation")
    func simpleInvestmentCreation() {
        let investment = Investment.simple(
            initialCost: 100_000,
            annualCashFlow: 25_000,
            years: 5,
            discountRate: 0.10
        )

        #expect(investment.initialCost == 100_000)
        #expect(investment.cashFlows.count == 5)
        #expect(investment.discountRate == 0.10)

        // All cash flows should be equal
        for cf in investment.cashFlows {
            #expect(cf.amount == 25_000)
        }
    }

    @Test("Growing investment creation")
    func growingInvestmentCreation() {
        let investment = Investment.growing(
            initialCost: 100_000,
            firstYearCashFlow: 20_000,
            growthRate: 0.10,
            years: 4,
            discountRate: 0.12
        )

        #expect(investment.initialCost == 100_000)
        #expect(investment.cashFlows.count == 4)
        #expect(investment.discountRate == 0.12)

        // Cash flows should grow at 10% per year
        #expect(abs(investment.cashFlows[0].amount - 20_000) < 0.01)
        #expect(abs(investment.cashFlows[1].amount - 22_000) < 0.01) // 20k * 1.1
        #expect(abs(investment.cashFlows[2].amount - 24_200) < 0.01) // 20k * 1.1^2
        #expect(abs(investment.cashFlows[3].amount - 26_620) < 0.01) // 20k * 1.1^3
    }

    @Test("Growth rate application")
    func growthRateApplication() {
        let investment = Investment.growing(
            initialCost: 50_000,
            firstYearCashFlow: 10_000,
            growthRate: 0.05,
            years: 3,
            discountRate: 0.08
        )

        #expect(abs(investment.cashFlows[0].amount - 10_000) < 0.01)
        #expect(abs(investment.cashFlows[1].amount - 10_500) < 0.01) // 5% growth
        #expect(abs(investment.cashFlows[2].amount - 11_025) < 0.01) // 5% growth compounded
    }

    // MARK: - Portfolio Operations

    @Test("Portfolio ranking by NPV")
    func portfolioRankingByNPV() {
        var portfolio = InvestmentPortfolio()

        let inv1 = Investment.simple(initialCost: 100_000, annualCashFlow: 30_000, years: 5, discountRate: 0.10)
        let inv2 = Investment.simple(initialCost: 50_000, annualCashFlow: 20_000, years: 4, discountRate: 0.10)
        let inv3 = Investment.simple(initialCost: 75_000, annualCashFlow: 25_000, years: 5, discountRate: 0.10)

        portfolio.add(inv1)
        portfolio.add(inv2)
        portfolio.add(inv3)

        let ranked = portfolio.rankedByNPV()

        #expect(ranked.count == 3)
        // Highest NPV should be first
        #expect(ranked[0].npv >= ranked[1].npv)
        #expect(ranked[1].npv >= ranked[2].npv)
    }

    @Test("Portfolio ranking by IRR")
    func portfolioRankingByIRR() {
        var portfolio = InvestmentPortfolio()

        let inv1 = Investment.simple(initialCost: 100_000, annualCashFlow: 25_000, years: 5, discountRate: 0.10)
        let inv2 = Investment.simple(initialCost: 50_000, annualCashFlow: 20_000, years: 4, discountRate: 0.10)
        let inv3 = Investment.simple(initialCost: 75_000, annualCashFlow: 30_000, years: 4, discountRate: 0.10)

        portfolio.add(inv1)
        portfolio.add(inv2)
        portfolio.add(inv3)

        let ranked = portfolio.rankedByIRR()

        #expect(ranked.count == 3)
        // Only investments with calculable IRR
        for i in 0..<(ranked.count - 1) {
            let irr1 = ranked[i].irr ?? 0
            let irr2 = ranked[i + 1].irr ?? 0
            #expect(irr1 >= irr2)
        }
    }

    @Test("Portfolio ranking by PI")
    func portfolioRankingByPI() {
        var portfolio = InvestmentPortfolio()

        let inv1 = Investment.simple(initialCost: 100_000, annualCashFlow: 30_000, years: 5, discountRate: 0.10)
        let inv2 = Investment.simple(initialCost: 50_000, annualCashFlow: 15_000, years: 5, discountRate: 0.10)

        portfolio.add(inv1)
        portfolio.add(inv2)

        let ranked = portfolio.rankedByPI()

        #expect(ranked.count == 2)
        #expect(ranked[0].profitabilityIndex >= ranked[1].profitabilityIndex)
    }

    @Test("Portfolio filtering")
    func portfolioFiltering() {
        var portfolio = InvestmentPortfolio()

        let inv1 = Investment.simple(initialCost: 100_000, annualCashFlow: 35_000, years: 5, discountRate: 0.10)
        let inv2 = Investment.simple(initialCost: 50_000, annualCashFlow: 10_000, years: 5, discountRate: 0.10)
        let inv3 = Investment.simple(initialCost: 75_000, annualCashFlow: 25_000, years: 5, discountRate: 0.10)

        portfolio.add(inv1)
        portfolio.add(inv2)
        portfolio.add(inv3)

        let positiveNPV = portfolio.filter(minNPV: 0)

        #expect(positiveNPV.count >= 1)
        for inv in positiveNPV {
            #expect(inv.npv >= 0)
        }
    }

    @Test("Portfolio aggregations")
    func portfolioAggregations() {
        var portfolio = InvestmentPortfolio()

        let inv1 = Investment.simple(initialCost: 100_000, annualCashFlow: 30_000, years: 5, discountRate: 0.10)
        let inv2 = Investment.simple(initialCost: 50_000, annualCashFlow: 20_000, years: 4, discountRate: 0.10)

        portfolio.add(inv1)
        portfolio.add(inv2)

        #expect(portfolio.totalInitialCost == 150_000)
        #expect(portfolio.totalNPV == inv1.npv + inv2.npv)
    }

    // MARK: - Investment Comparison

    @Test("Investment comparison NPV")
    func investmentComparisonNPV() {
        let inv1 = Investment.simple(initialCost: 100_000, annualCashFlow: 35_000, years: 5, discountRate: 0.10)
        let inv2 = Investment.simple(initialCost: 100_000, annualCashFlow: 30_000, years: 5, discountRate: 0.10)

        let comparison = Investment.compareNPV(inv1, inv2)

        // inv1 has higher cash flows, so higher NPV
        #expect(comparison == .orderedDescending)
    }

    @Test("Investment comparison IRR")
    func investmentComparisonIRR() {
        let inv1 = Investment.simple(initialCost: 100_000, annualCashFlow: 40_000, years: 4, discountRate: 0.10)
        let inv2 = Investment.simple(initialCost: 100_000, annualCashFlow: 30_000, years: 4, discountRate: 0.10)

        let comparison = Investment.compareIRR(inv1, inv2)

        // inv1 has higher cash flows, so higher IRR
        #expect(comparison == .orderedDescending)
    }

    @Test("Investment comparison PI")
    func investmentComparisonPI() {
        let inv1 = Investment.simple(initialCost: 50_000, annualCashFlow: 20_000, years: 4, discountRate: 0.10)
        let inv2 = Investment.simple(initialCost: 100_000, annualCashFlow: 30_000, years: 4, discountRate: 0.10)

        let comparison = Investment.comparePI(inv1, inv2)

        // inv1 has better return per dollar invested
        #expect(comparison == .orderedDescending)
    }

    // MARK: - Edge Cases

    @Test("Investment never pays back")
    func investmentNeverPaysBack() {
        let investment = Investment {
            InitialCost(100_000)

            CashFlows {
                Year(1) => 10_000
                Year(2) => 10_000
                Year(3) => 10_000
            }

            DiscountRate(0.10)
        }

        #expect(investment.paybackPeriod == nil)
        #expect(investment.discountedPaybackPeriod == nil)
    }

    @Test("Investment IRR no convergence")
    func investmentIRRNoConvergence() {
        // Pathological case: all negative cash flows
        let investment = Investment {
            InitialCost(100_000)

            CashFlows {
                Year(1) => -10_000
                Year(2) => -10_000
                Year(3) => -10_000
            }

            DiscountRate(0.10)
        }

        #expect(investment.irr == nil)
    }

    @Test("Empty portfolio")
    func emptyPortfolio() {
        let portfolio = InvestmentPortfolio()

        #expect(portfolio.investments.isEmpty)
        #expect(portfolio.totalInitialCost == 0)
        #expect(portfolio.totalNPV == 0)
        #expect(portfolio.rankedByNPV().isEmpty)
        #expect(portfolio.rankedByIRR().isEmpty)
        #expect(portfolio.rankedByPI().isEmpty)
    }

    @Test("Investment with zero discount rate")
    func zeroDiscountRate() {
        let investment = Investment {
            InitialCost(100_000)

            CashFlows {
                Year(1) => 30_000
                Year(2) => 40_000
                Year(3) => 50_000
            }

            DiscountRate(0.0)
        }

        // At 0% discount rate, NPV = sum of cash flows - initial cost
        #expect(investment.npv == 20_000) // 120k - 100k
    }

    @Test("Investment with high discount rate")
    func highDiscountRate() {
        let investment = Investment {
            InitialCost(100_000)

            CashFlows {
                Year(1) => 50_000
                Year(2) => 60_000
                Year(3) => 70_000
            }

            DiscountRate(0.50) // 50% discount rate
        }

        // High discount rate should heavily discount future cash flows
        #expect(investment.npv < 0)
    }

    @Test("Single year investment")
    func singleYearInvestment() {
        let investment = Investment {
            InitialCost(10_000)

            CashFlows {
                Year(1) => 12_000
            }

            DiscountRate(0.10)
        }

        #expect(investment.cashFlows.count == 1)

        guard let payback = investment.paybackPeriod else {
            Issue.record("Payback should exist")
            return
        }

        // Pays back in first year
        #expect(payback < 1.0)
    }

    @Test("Investment description formatting")
    func investmentDescriptionFormatting() {
        let investment = Investment {
            Name("Test Investment")
            InitialCost(100_000)

            CashFlows {
                Year(1) => 30_000
                Year(2) => 35_000
            }

            DiscountRate(0.10)
        }

        let description = investment.description

        #expect(description.contains("Test Investment"))
        #expect(description.contains("100000")) // Number formatting without commas
        #expect(description.contains("NPV"))
        #expect(description.contains("IRR"))
    }

    @Test("Fractional cash flows")
    func fractionalCashFlows() {
        let investment = Investment {
            InitialCost(100_000)

            CashFlows {
                Year(1) => 25_500.50
                Year(2) => 30_750.75
                Year(3) => 35_999.99
            }

            DiscountRate(0.10)
        }

        #expect(investment.cashFlows[0].amount == 25_500.50)
        #expect(investment.cashFlows[1].amount == 30_750.75)
        #expect(investment.cashFlows[2].amount == 35_999.99)

        // NPV calculation should handle fractional amounts
        #expect(investment.npv != 0)
    }
}

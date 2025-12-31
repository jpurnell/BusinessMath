//
//  CashFlowBuilderTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-29.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath
@testable import BusinessMathDSL

/// Tests for Cash Flow Result Builder
///
/// Following TDD:
/// - RED: Write failing tests first
/// - GREEN: Implement to make tests pass
/// - REFACTOR: Clean up implementation
@Suite("Cash Flow Result Builder Tests")
struct CashFlowBuilderTests {

    // MARK: - Revenue Component Tests

    @Test("Revenue base value is set correctly")
    func revenueBase() async throws {
        let revenue = Revenue {
            Base(1_000_000)
        }

        #expect(revenue.baseValue == 1_000_000)
    }

    @Test("Revenue growth rate is applied")
    func revenueGrowth() async throws {
        let revenue = Revenue {
            Base(1_000_000)
            GrowthRate(0.15)
        }

        #expect(revenue.baseValue == 1_000_000)
        #expect(revenue.growthRate == 0.15)

        // Calculate year 1 and year 2
        let year1 = revenue.value(forYear: 1)
        let year2 = revenue.value(forYear: 2)

        #expect(abs(year1 - 1_000_000) < 0.01)
        #expect(abs(year2 - 1_150_000) < 0.01)  // 1M * 1.15
    }

    @Test("Revenue seasonality is applied")
    func revenueSeasonality() async throws {
        let revenue = Revenue {
            Base(1_000_000)
            Seasonality([1.2, 1.0, 0.8, 1.0])  // Q1-Q4 multipliers
        }

        #expect(revenue.seasonalityFactors.count == 4)

        // Quarterly revenue should vary by seasonality
        let q1 = revenue.value(forYear: 1, quarter: 1)
        let q2 = revenue.value(forYear: 1, quarter: 2)
        let q3 = revenue.value(forYear: 1, quarter: 3)

        // Base quarterly is 250k, multiplied by factors
        #expect(abs(q1 - 300_000) < 0.01)  // 250k * 1.2
        #expect(abs(q2 - 250_000) < 0.01)  // 250k * 1.0
        #expect(abs(q3 - 200_000) < 0.01)  // 250k * 0.8
    }

    @Test("Revenue with growth and seasonality combined")
    func revenueGrowthAndSeasonality() async throws {
        let revenue = Revenue {
            Base(1_000_000)
            GrowthRate(0.20)
            Seasonality([1.2, 1.0, 0.8, 1.0])
        }

        let year1Q1 = revenue.value(forYear: 1, quarter: 1)
        let year2Q1 = revenue.value(forYear: 2, quarter: 1)

        // Year 1 Q1: 250k * 1.2 = 300k
        #expect(abs(year1Q1 - 300_000) < 0.01)

        // Year 2 Q1: (1M * 1.2) / 4 * 1.2 = 360k
        #expect(abs(year2Q1 - 360_000) < 0.01)
    }

    // MARK: - Expense Component Tests

    @Test("Fixed expenses are constant")
    func fixedExpenses() async throws {
        let expenses = Expenses {
            Fixed(100_000)
        }

        #expect(expenses.fixedAmount == 100_000)

        let year1 = expenses.value(forYear: 1, revenue: 1_000_000)
        let year2 = expenses.value(forYear: 2, revenue: 2_000_000)

        #expect(year1 == 100_000)
        #expect(year2 == 100_000)  // Same regardless of revenue
    }

    @Test("Variable expenses scale with revenue")
    func variableExpenses() async throws {
        let expenses = Expenses {
            Variable(percentage: 0.40)  // 40% of revenue
        }

        #expect(expenses.variablePercentage == 0.40)

        let expenses1M = expenses.value(forYear: 1, revenue: 1_000_000)
        let expenses2M = expenses.value(forYear: 1, revenue: 2_000_000)

        #expect(expenses1M == 400_000)  // 40% of 1M
        #expect(expenses2M == 800_000)  // 40% of 2M
    }

    @Test("One-time expenses occur in specific year")
    func oneTimeExpenses() async throws {
        let expenses = Expenses {
            OneTime(500_000, in: 2)  // Year 2
        }

        #expect(expenses.oneTimeExpenses.count == 1)

        let year1 = expenses.oneTimeValue(forYear: 1)
        let year2 = expenses.oneTimeValue(forYear: 2)
        let year3 = expenses.oneTimeValue(forYear: 3)

        #expect(year1 == 0)
        #expect(year2 == 500_000)
        #expect(year3 == 0)
    }

    @Test("Multiple expense types combined")
    func combinedExpenses() async throws {
        let expenses = Expenses {
            Fixed(100_000)
            Variable(percentage: 0.40)
            OneTime(500_000, in: 2)
        }

        let year1Total = expenses.value(forYear: 1, revenue: 1_000_000)
        let year2Total = expenses.value(forYear: 2, revenue: 1_000_000)

        // Year 1: 100k fixed + 400k variable = 500k
        #expect(year1Total == 500_000)

        // Year 2: 100k fixed + 400k variable + 500k one-time = 1M
        #expect(year2Total == 1_000_000)
    }

    // MARK: - Depreciation Tests

    @Test("Straight-line depreciation calculates correctly")
    func straightLineDepreciation() async throws {
        let depreciation = Depreciation {
            StraightLine(asset: 1_000_000, years: 10)
        }

        let annualDepreciation = depreciation.value(forYear: 1)

        #expect(annualDepreciation == 100_000)  // 1M / 10 years

        // Should be same for all years within life
        #expect(depreciation.value(forYear: 5) == 100_000)
        #expect(depreciation.value(forYear: 10) == 100_000)

        // Zero after asset life
        #expect(depreciation.value(forYear: 11) == 0)
    }

    @Test("Multiple depreciation schedules combined")
    func multipleDepreciation() async throws {
        let depreciation = Depreciation {
            StraightLine(asset: 1_000_000, years: 10)
            StraightLine(asset: 500_000, years: 5)
        }

        let year1 = depreciation.value(forYear: 1)
        let year6 = depreciation.value(forYear: 6)

        // Year 1: 100k + 100k = 200k
        #expect(year1 == 200_000)

        // Year 6: 100k + 0 (second asset fully deprecated) = 100k
        #expect(year6 == 100_000)
    }

    // MARK: - Tax Tests

    @Test("Corporate tax rate is applied")
    func corporateTax() async throws {
        let taxes = Taxes {
            CorporateRate(0.21)
        }

        #expect(taxes.corporateRate == 0.21)

        let taxOnIncome = taxes.value(on: 1_000_000)

        #expect(taxOnIncome == 210_000)  // 21% of 1M
    }

    @Test("State tax rate is applied")
    func stateTax() async throws {
        let taxes = Taxes {
            StateRate(0.06)
        }

        #expect(taxes.stateRate == 0.06)

        let taxOnIncome = taxes.value(on: 1_000_000)

        #expect(taxOnIncome == 60_000)  // 6% of 1M
    }

    @Test("Combined tax rates (corporate + state)")
    func combinedTaxes() async throws {
        let taxes = Taxes {
            CorporateRate(0.21)
            StateRate(0.06)
        }

        let taxOnIncome = taxes.value(on: 1_000_000)

        // 21% + 6% = 27% effective
        #expect(taxOnIncome == 270_000)
    }

    // MARK: - Full Cash Flow Model Integration Tests

    @Test("Complete cash flow model with all components")
    func completeCashFlowModel() async throws {
        let projection = CashFlowModel(
            revenue: Revenue {
                Base(1_000_000)
                GrowthRate(0.15)
            },
            expenses: Expenses {
                Fixed(100_000)
                Variable(percentage: 0.40)
            },
            depreciation: Depreciation {
                StraightLine(asset: 1_000_000, years: 10)
            },
            taxes: Taxes {
                CorporateRate(0.21)
                StateRate(0.06)
            }
        )

        // Year 1 calculation:
        // Revenue: 1M
        // Expenses: 100k + 400k = 500k
        // EBITDA: 500k
        // Depreciation: 100k
        // EBIT: 400k
        // Taxes: 400k * 0.27 = 108k
        // Net Income: 292k

        let year1 = projection.calculate(year: 1)

        #expect(abs(year1.revenue - 1_000_000) < 0.01)
        #expect(abs(year1.expenses - 500_000) < 0.01)
        #expect(abs(year1.ebitda - 500_000) < 0.01)
        #expect(abs(year1.depreciation - 100_000) < 0.01)
        #expect(abs(year1.ebit - 400_000) < 0.01)
        #expect(abs(year1.taxes - 108_000) < 0.01)
        #expect(abs(year1.netIncome - 292_000) < 0.01)
    }

    @Test("Multi-year projection with growth")
    func multiYearProjection() async throws {
        let projection = CashFlowModel(
            revenue: Revenue {
                Base(1_000_000)
                GrowthRate(0.20)
            },
            expenses: Expenses {
                Variable(percentage: 0.50)
            },
            taxes: Taxes {
                CorporateRate(0.25)
            }
        )

        let years = projection.calculateYears(1...3)

        #expect(years.count == 3)

        // Year 1: Revenue 1M, Expenses 500k, EBIT 500k, Tax 125k, Net 375k
        #expect(abs(years[0].revenue - 1_000_000) < 0.01)
        #expect(abs(years[0].netIncome - 375_000) < 0.01)

        // Year 2: Revenue 1.2M (20% growth)
        #expect(abs(years[1].revenue - 1_200_000) < 0.01)

        // Year 3: Revenue 1.44M (20% growth on 1.2M)
        #expect(abs(years[2].revenue - 1_440_000) < 0.01)
    }

    @Test("Free cash flow calculation")
    func freeCashFlow() async throws {
        let projection = CashFlowModel(
            revenue: Revenue {
                Base(1_000_000)
            },
            expenses: Expenses {
                Variable(percentage: 0.60)
            },
            depreciation: Depreciation {
                StraightLine(asset: 500_000, years: 5)
            },
            taxes: Taxes {
                CorporateRate(0.30)
            }
        )

        // FCF = Net Income + Depreciation (non-cash expense)
        // Revenue: 1M
        // Expenses: 600k
        // EBITDA: 400k
        // Depreciation: 100k
        // EBIT: 300k
        // Taxes: 90k
        // Net Income: 210k
        // FCF: 210k + 100k = 310k

        let fcf = projection.freeCashFlow(year: 1)

        #expect(abs(fcf - 310_000) < 0.01)
    }

    @Test("Quarterly projections with seasonality")
    func quarterlyProjections() async throws {
        let projection = CashFlowModel(
            revenue: Revenue {
                Base(1_200_000)  // 1.2M annual
                Seasonality([1.5, 1.0, 0.75, 0.75])  // Strong Q1, weak Q3-Q4
            },
            expenses: Expenses {
                Variable(percentage: 0.50)
            }
        )

        let quarters = projection.calculateQuarters(year: 1)

        #expect(quarters.count == 4)

        // Base quarterly: 300k
        // Q1: 300k * 1.5 = 450k revenue
        #expect(abs(quarters[0].revenue - 450_000) < 0.01)

        // Q2: 300k * 1.0 = 300k revenue
        #expect(abs(quarters[1].revenue - 300_000) < 0.01)

        // Q3: 300k * 0.75 = 225k revenue
        #expect(abs(quarters[2].revenue - 225_000) < 0.01)
    }

    // NOTE: Validation tests omitted because components use fatalError for invalid inputs
    // rather than throwing errors. This is intentional to catch programmer errors at
    // development time. In production code, validation should be done before creating
    // these components.
}

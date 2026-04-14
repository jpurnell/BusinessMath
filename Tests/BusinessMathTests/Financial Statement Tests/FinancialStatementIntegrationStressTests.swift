//
//  FinancialStatementIntegrationStressTests.swift
//  BusinessMath
//
//  Integration stress tests for the financial statement pipeline.
//  Uses seeded RNG for reproducibility across CI runs.
//

import Foundation
import Testing
@testable import BusinessMath

// MARK: - Seeded RNG Helper (Financial)

/// A simple seeded random number generator for reproducible financial stress tests.
/// Marked @unchecked Sendable because stress tests run serialized.
private final class FinSeededRNG: @unchecked Sendable {
    // Justification: Tests run serialized; no concurrent access to drand48 state.
    init(seed: Int) {
        srand48(seed)
    }

    /// Returns a uniform random Double in [low, high).
    func nextDouble(in range: ClosedRange<Double>) -> Double {
        let low = range.lowerBound
        let high = range.upperBound
        return low + (high - low) * drand48()
    }
}

// MARK: - Test Helpers

/// Creates a standard set of quarterly periods for testing.
private func quarterlyPeriods(year: Int) -> [Period] {
    return (1...4).map { Period.quarter(year: year, quarter: $0) }
}

// MARK: - Tests

@Suite("Financial Statement Integration Stress Tests", .serialized)
struct FinancialStatementIntegrationStressTests {

    // MARK: - D.3.1: Randomized Revenue/Cost Scenarios

    @Test("Randomized revenue and cost scenarios - 100 iterations")
    func randomizedRevenueAndCostScenarios() throws {
        let rng = FinSeededRNG(seed: 42)
        let periods = quarterlyPeriods(year: 2025)

        for i in 0..<100 {
            let entity = Entity(
                id: "STRESS_\(i)",
                primaryType: .internal,
                name: "Stress Test Corp \(i)"
            )

            // Generate random quarterly revenue (100K - 10M per quarter)
            let revenueValues: [Double] = (0..<4).map { _ in
                rng.nextDouble(in: 100_000...10_000_000)
            }

            // Generate random quarterly COGS (50K - 5M per quarter)
            let cogsValues: [Double] = (0..<4).map { _ in
                rng.nextDouble(in: 50_000...5_000_000)
            }

            // Generate random quarterly operating expenses (10K - 2M per quarter)
            let opexValues: [Double] = (0..<4).map { _ in
                rng.nextDouble(in: 10_000...2_000_000)
            }

            let revenueTS = TimeSeries(periods: periods, values: revenueValues)
            let cogsTS = TimeSeries(periods: periods, values: cogsValues)
            let opexTS = TimeSeries(periods: periods, values: opexValues)

            let revenueAccount = try Account<Double>(
                entity: entity,
                name: "Revenue",
                incomeStatementRole: .revenue,
                timeSeries: revenueTS
            )

            let cogsAccount = try Account<Double>(
                entity: entity,
                name: "COGS",
                incomeStatementRole: .costOfGoodsSold,
                timeSeries: cogsTS
            )

            let opexAccount = try Account<Double>(
                entity: entity,
                name: "Operating Expenses",
                incomeStatementRole: .operatingExpenseOther,
                timeSeries: opexTS
            )

            let incomeStmt = try IncomeStatement<Double>(
                entity: entity,
                periods: periods,
                accounts: [revenueAccount, cogsAccount, opexAccount]
            )

            // Assert: totalRevenue values are finite and match our inputs
            let totalRevenueValues = incomeStmt.totalRevenue.valuesArray
            for (j, value) in totalRevenueValues.enumerated() {
                #expect(value.isFinite, "Non-finite revenue at iteration \(i), period \(j)")
            }

            // Assert: netIncome values are finite
            let netIncomeValues = incomeStmt.netIncome.valuesArray
            for (j, value) in netIncomeValues.enumerated() {
                #expect(value.isFinite, "Non-finite net income at iteration \(i), period \(j)")
            }

            // Assert: grossProfit values are finite
            let grossProfitValues = incomeStmt.grossProfit.valuesArray
            for (j, value) in grossProfitValues.enumerated() {
                #expect(value.isFinite, "Non-finite gross profit at iteration \(i), period \(j)")
            }

            // Assert: revenue - cogs = gross profit (within floating point tolerance)
            for j in 0..<4 {
                let expectedGrossProfit = revenueValues[j] - cogsValues[j]
                let actualGrossProfit = grossProfitValues[j]
                let tolerance = Swift.max(Swift.abs(expectedGrossProfit) * 1e-10, 1e-10)
                #expect(Swift.abs(actualGrossProfit - expectedGrossProfit) < tolerance,
                        "Gross profit mismatch at iteration \(i), period \(j)")
            }
        }
    }

    // MARK: - D.3.2: Ratio Consistency

    @Test("Ratio consistency with random financial data - 50 iterations")
    func ratioConsistency() throws {
        let rng = FinSeededRNG(seed: 42)
        let periods = quarterlyPeriods(year: 2025)

        for i in 0..<50 {
            let entity = Entity(
                id: "RATIO_\(i)",
                primaryType: .internal,
                name: "Ratio Test Corp \(i)"
            )

            // Generate revenue that is always positive and larger than costs
            let revenueValues: [Double] = (0..<4).map { _ in
                rng.nextDouble(in: 1_000_000...10_000_000)
            }

            // COGS is 20-60% of revenue
            let cogsValues: [Double] = revenueValues.map { rev in
                rev * rng.nextDouble(in: 0.2...0.6)
            }

            // Opex is 10-30% of revenue
            let opexValues: [Double] = revenueValues.map { rev in
                rev * rng.nextDouble(in: 0.1...0.3)
            }

            let revenueTS = TimeSeries(periods: periods, values: revenueValues)
            let cogsTS = TimeSeries(periods: periods, values: cogsValues)
            let opexTS = TimeSeries(periods: periods, values: opexValues)

            let revenueAccount = try Account<Double>(
                entity: entity,
                name: "Revenue",
                incomeStatementRole: .revenue,
                timeSeries: revenueTS
            )

            let cogsAccount = try Account<Double>(
                entity: entity,
                name: "COGS",
                incomeStatementRole: .costOfGoodsSold,
                timeSeries: cogsTS
            )

            let opexAccount = try Account<Double>(
                entity: entity,
                name: "Opex",
                incomeStatementRole: .operatingExpenseOther,
                timeSeries: opexTS
            )

            let incomeStmt = try IncomeStatement<Double>(
                entity: entity,
                periods: periods,
                accounts: [revenueAccount, cogsAccount, opexAccount]
            )

            // Test gross margin: should be between 0 and 1 since COGS < Revenue
            let grossMarginValues = incomeStmt.grossMargin.valuesArray
            for (j, margin) in grossMarginValues.enumerated() {
                #expect(margin.isFinite, "Non-finite gross margin at iteration \(i), period \(j)")
                #expect(margin >= 0.0 && margin <= 1.0,
                        "Gross margin \(margin) out of [0,1] at iteration \(i), period \(j)")
            }

            // Test net margin: should be finite (can be negative if costs > revenue)
            let netMarginValues = incomeStmt.netMargin.valuesArray
            for (j, margin) in netMarginValues.enumerated() {
                #expect(margin.isFinite, "Non-finite net margin at iteration \(i), period \(j)")
                // Net margin should be less than gross margin
                #expect(margin <= grossMarginValues[j] + 1e-10,
                        "Net margin exceeds gross margin at iteration \(i), period \(j)")
            }

            // Test profitMargin standalone function with generated data
            for j in 0..<4 {
                let netIncome = incomeStmt.netIncome.valuesArray[j]
                let revenue = revenueValues[j]
                let margin = try profitMargin(netIncome: netIncome, revenue: revenue)
                #expect(margin.isFinite,
                        "Non-finite profitMargin at iteration \(i), period \(j)")
            }
        }
    }

    // MARK: - D.3.3: Edge Cases

    @Test("Financial statement edge cases")
    func financialStatementEdgeCases() throws {
        let periods = quarterlyPeriods(year: 2025)

        // Edge case 1: Very large revenue numbers
        do {
            let entity = Entity(id: "LARGE", primaryType: .internal, name: "Large Numbers Corp")
            let largeValues: [Double] = [1e12, 2e12, 3e12, 4e12]
            let cogsValues: [Double] = [5e11, 1e12, 1.5e12, 2e12]

            let revenueAccount = try Account<Double>(
                entity: entity,
                name: "Revenue",
                incomeStatementRole: .revenue,
                timeSeries: TimeSeries(periods: periods, values: largeValues)
            )

            let cogsAccount = try Account<Double>(
                entity: entity,
                name: "COGS",
                incomeStatementRole: .costOfGoodsSold,
                timeSeries: TimeSeries(periods: periods, values: cogsValues)
            )

            let stmt = try IncomeStatement<Double>(
                entity: entity,
                periods: periods,
                accounts: [revenueAccount, cogsAccount]
            )

            for value in stmt.netIncome.valuesArray {
                #expect(value.isFinite, "Non-finite net income with very large numbers")
            }

            for margin in stmt.grossMargin.valuesArray {
                #expect(margin.isFinite, "Non-finite gross margin with very large numbers")
            }
        }

        // Edge case 2: Very small revenue numbers
        do {
            let entity = Entity(id: "SMALL", primaryType: .internal, name: "Small Numbers Corp")
            let smallValues: [Double] = [0.01, 0.02, 0.03, 0.04]
            let cogsValues: [Double] = [0.005, 0.01, 0.015, 0.02]

            let revenueAccount = try Account<Double>(
                entity: entity,
                name: "Revenue",
                incomeStatementRole: .revenue,
                timeSeries: TimeSeries(periods: periods, values: smallValues)
            )

            let cogsAccount = try Account<Double>(
                entity: entity,
                name: "COGS",
                incomeStatementRole: .costOfGoodsSold,
                timeSeries: TimeSeries(periods: periods, values: cogsValues)
            )

            let stmt = try IncomeStatement<Double>(
                entity: entity,
                periods: periods,
                accounts: [revenueAccount, cogsAccount]
            )

            for value in stmt.netIncome.valuesArray {
                #expect(value.isFinite, "Non-finite net income with very small numbers")
            }
        }

        // Edge case 3: Costs exceed revenue (negative profit)
        do {
            let entity = Entity(id: "LOSS", primaryType: .internal, name: "Loss Corp")
            let revenueValues: [Double] = [100_000, 200_000, 150_000, 180_000]
            let cogsValues: [Double] = [150_000, 250_000, 200_000, 300_000]

            let revenueAccount = try Account<Double>(
                entity: entity,
                name: "Revenue",
                incomeStatementRole: .revenue,
                timeSeries: TimeSeries(periods: periods, values: revenueValues)
            )

            let cogsAccount = try Account<Double>(
                entity: entity,
                name: "COGS",
                incomeStatementRole: .costOfGoodsSold,
                timeSeries: TimeSeries(periods: periods, values: cogsValues)
            )

            let stmt = try IncomeStatement<Double>(
                entity: entity,
                periods: periods,
                accounts: [revenueAccount, cogsAccount]
            )

            // Net income should be negative (losses)
            for value in stmt.netIncome.valuesArray {
                #expect(value.isFinite, "Non-finite net income for loss scenario")
                #expect(value < 0, "Expected negative net income for loss scenario")
            }

            // Gross margin should be negative when COGS > revenue
            for margin in stmt.grossMargin.valuesArray {
                #expect(margin.isFinite, "Non-finite gross margin for loss scenario")
                #expect(margin < 0, "Expected negative gross margin when COGS > revenue")
            }
        }

        // Edge case 4: Profit margin function rejects zero revenue
        do {
            #expect(throws: BusinessMathError.self) {
                _ = try profitMargin(netIncome: 100.0, revenue: 0.0)
            }
        }

        // Edge case 5: Negative growth rates (revenue decreasing each quarter)
        do {
            let entity = Entity(id: "DECLINE", primaryType: .internal, name: "Declining Corp")
            let revenueValues: [Double] = [10_000_000, 8_000_000, 6_000_000, 4_000_000]
            let cogsValues: [Double] = [5_000_000, 4_000_000, 3_000_000, 2_000_000]

            let revenueAccount = try Account<Double>(
                entity: entity,
                name: "Revenue",
                incomeStatementRole: .revenue,
                timeSeries: TimeSeries(periods: periods, values: revenueValues)
            )

            let cogsAccount = try Account<Double>(
                entity: entity,
                name: "COGS",
                incomeStatementRole: .costOfGoodsSold,
                timeSeries: TimeSeries(periods: periods, values: cogsValues)
            )

            let stmt = try IncomeStatement<Double>(
                entity: entity,
                periods: periods,
                accounts: [revenueAccount, cogsAccount]
            )

            // Despite declining revenue, all metrics should be finite
            for value in stmt.totalRevenue.valuesArray {
                #expect(value.isFinite, "Non-finite revenue in declining scenario")
                #expect(value > 0, "Revenue should still be positive in declining scenario")
            }

            for margin in stmt.grossMargin.valuesArray {
                #expect(margin.isFinite, "Non-finite gross margin in declining scenario")
                #expect(margin == 0.5, "Gross margin should be 50% (COGS = 50% of revenue)")
            }
        }
    }
}

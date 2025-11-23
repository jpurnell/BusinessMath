//
//  ModelTestHelpers.swift
//  BusinessMath Tests
//
//  Created on October 31, 2025.
//

import Foundation
import Testing
import RealModule
@testable import BusinessMath

// MARK: - Model Test Helpers

/// Helper functions for testing financial models with Swift Testing framework.
enum ModelTestHelpers {

    // MARK: - Model Assertions

    /// Verify that a model has the expected revenue.
    static func assertModel(
        _ model: FinancialModel,
        hasRevenue expected: Double,
        accuracy: Double = 0.01,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let actual = model.calculateRevenue()
        #expect(abs(actual - expected) < accuracy, "Expected revenue \(expected), got \(actual)", sourceLocation: sourceLocation)
    }

    /// Assert that a model has the expected costs.
    static func assertModel(
        _ model: FinancialModel,
        hasCosts expected: Double,
        accuracy: Double = 0.01,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let revenue = model.calculateRevenue()
        let actual = model.calculateCosts(revenue: revenue)
        #expect(abs(actual - expected) < accuracy, "Expected costs \(expected), got \(actual)", sourceLocation: sourceLocation)
    }

    /// Assert that a model has the expected profit.
    static func assertModel(
        _ model: FinancialModel,
        hasProfit expected: Double,
        accuracy: Double = 0.01,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let actual = model.calculateProfit()
        #expect(abs(actual - expected) < accuracy, "Expected profit \(expected), got \(actual)", sourceLocation: sourceLocation)
    }

    /// Assert that a model has a specific number of revenue components.
    static func assertModel(
        _ model: FinancialModel,
        hasRevenueComponentCount expected: Int,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(model.revenueComponents.count == expected, "Expected \(expected) revenue components, got \(model.revenueComponents.count)", sourceLocation: sourceLocation)
    }

    /// Assert that a model has a specific number of cost components.
    static func assertModel(
        _ model: FinancialModel,
        hasCostComponentCount expected: Int,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(model.costComponents.count == expected, "Expected \(expected) cost components, got \(model.costComponents.count)", sourceLocation: sourceLocation)
    }

    // MARK: - Investment Assertions

    /// Assert that an investment has the expected NPV.
    static func assertInvestment(
        _ investment: Investment,
        hasNPV expected: Double,
        accuracy: Double = 0.01,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(abs(investment.npv - expected) < accuracy, "Expected NPV \(expected), got \(investment.npv)", sourceLocation: sourceLocation)
    }

    /// Assert that an investment has a positive NPV.
    static func assertInvestmentIsPositive(
        _ investment: Investment,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(investment.npv > 0, "Expected positive NPV, got \(investment.npv)", sourceLocation: sourceLocation)
    }

    /// Assert that an investment has the expected IRR.
    static func assertInvestment(
        _ investment: Investment,
        hasIRR expected: Double,
        accuracy: Double = 0.001,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        guard let actualIRR = investment.irr else {
            Issue.record("Expected IRR \(expected), but IRR calculation returned nil", sourceLocation: sourceLocation)
            return
        }
        #expect(abs(actualIRR - expected) < accuracy, "Expected IRR \(expected), got \(actualIRR)", sourceLocation: sourceLocation)
    }

    // MARK: - Time Series Assertions

    /// Assert that a time series has the expected number of values.
    static func assertTimeSeries<T: Real>(
        _ series: TimeSeries<T>,
        hasCount expected: Int,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(series.count == expected, "Expected time series count \(expected), got \(series.count)", sourceLocation: sourceLocation)
    }

    /// Assert that a time series has the expected value at an index.
    static func assertTimeSeries<T: Real & Equatable>(
        _ series: TimeSeries<T>,
        hasValue expected: T,
        atIndex index: Int,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        guard index < series.count else {
            Issue.record("Index \(index) out of bounds for time series of count \(series.count)", sourceLocation: sourceLocation)
            return
        }
        let actual = series.valuesArray[index]
        #expect(actual == expected, "Expected value \(expected) at index \(index), got \(actual)", sourceLocation: sourceLocation)
    }

    // MARK: - Scenario Assertions

    /// Assert that a scenario set has the expected number of scenarios.
    static func assertScenarioSet(
        _ scenarioSet: ScenarioSet,
        hasCount expected: Int,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(scenarioSet.scenarios.count == expected, "Expected \(expected) scenarios, got \(scenarioSet.scenarios.count)", sourceLocation: sourceLocation)
    }

    /// Assert that a scenario exists by name.
    static func assertScenarioSet(
        _ scenarioSet: ScenarioSet,
        hasScenarioNamed name: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let found = scenarioSet.scenario(named: name) != nil
        #expect(found, "Expected scenario named '\(name)' to exist", sourceLocation: sourceLocation)
    }
}

// MARK: - Mock Data Generators

extension TimeSeries where T == Double {

    /// Pattern for generating mock time series data.
    public enum MockPattern {
        case constant(Double)
        case linear(slope: Double, intercept: Double)
        case exponential(base: Double, scale: Double)
        case seasonal(amplitude: Double, period: Int, baseline: Double)
        case random(mean: Double, stddev: Double)
    }

    /// Generate mock time series data with a specific pattern.
    ///
    /// - Parameters:
    ///   - periods: Number of periods to generate
    ///   - pattern: The pattern to use for generation
    ///   - startYear: Starting year for periods (default: 2020)
    /// - Returns: A time series with generated data
    public static func mock(
        periods: Int,
        pattern: MockPattern,
        startYear: Int = 2020
    ) -> TimeSeries<Double> {
        let periodArray = (0..<periods).map { Period.year(startYear + $0) }

        let values: [Double] = (0..<periods).map { index in
            switch pattern {
            case .constant(let value):
                return value

            case .linear(let slope, let intercept):
                return slope * Double(index) + intercept

            case .exponential(let base, let scale):
                return scale * pow(base, Double(index))

            case .seasonal(let amplitude, let period, let baseline):
                let angle = 2.0 * .pi * Double(index) / Double(period)
                return baseline + amplitude * sin(angle)

            case .random(let mean, let stddev):
                // Simple Box-Muller transform for normal distribution
                let u1 = Double.random(in: 0..<1)
                let u2 = Double.random(in: 0..<1)
                let z = sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
                return mean + stddev * z
            }
        }

        return TimeSeries(periods: periodArray, values: values)
    }
}

// MARK: - Test Data Builders

/// Builder for creating test financial models.
public struct TestModelBuilder {

    /// Create a simple profit model for testing.
    public static func simpleProfit(revenue: Double, costs: Double) -> FinancialModel {
        var model = FinancialModel()
        model.revenueComponents.append(RevenueComponent(name: "Sales", amount: revenue))
        model.costComponents.append(CostComponent(name: "Operating Costs", type: .fixed(costs)))
        return model
    }

    /// Create a multi-component revenue model for testing.
    public static func multiRevenue(components: [(String, Double)]) -> FinancialModel {
        var model = FinancialModel()
        for (name, amount) in components {
            model.revenueComponents.append(RevenueComponent(name: name, amount: amount))
        }
        return model
    }

    /// Create a model with both fixed and variable costs for testing.
    public static func mixedCosts(
        revenue: Double,
        fixedCosts: Double,
        variablePercentage: Double
    ) -> FinancialModel {
        var model = FinancialModel()
        model.revenueComponents.append(RevenueComponent(name: "Sales", amount: revenue))
        model.costComponents.append(CostComponent(name: "Fixed Overhead", type: .fixed(fixedCosts)))
        model.costComponents.append(CostComponent(name: "Variable Costs", type: .variable(variablePercentage)))
        return model
    }
}

/// Builder for creating test investments.
public struct TestInvestmentBuilder {

    /// Create a simple investment for testing.
    public static func simple(
        initialCost: Double,
        annualCashFlow: Double,
        years: Int,
        discountRate: Double = 0.10
    ) -> Investment {
        Investment.simple(
            initialCost: initialCost,
            annualCashFlow: annualCashFlow,
            years: years,
            discountRate: discountRate
        )
    }

    /// Create an investment with custom cash flows.
    public static func custom(
        initialCost: Double,
        cashFlows: [Double],
        discountRate: Double = 0.10
    ) -> Investment {
        let flows = cashFlows.enumerated().map { index, amount in
            CashFlow(period: index + 1, amount: amount)
        }

        return Investment {
            InitialCost(initialCost)
            CashFlows { flows }
            DiscountRate(discountRate)
        }
    }
}

// MARK: - Test Utilities

/// Utility functions for testing.
public enum TestUtilities {

    /// Assert that two doubles are approximately equal.
    public static func assertApproximatelyEqual(
        _ actual: Double,
        _ expected: Double,
        accuracy: Double = 0.01,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(abs(actual - expected) < accuracy, sourceLocation: sourceLocation)
    }

    /// Generate a sequence of consecutive periods.
    public static func generatePeriods(from startYear: Int, count: Int) -> [Period] {
        (0..<count).map { Period.year(startYear + $0) }
    }

    /// Generate a sequence of values with linear growth.
    public static func generateLinearValues(
        start: Double,
        increment: Double,
        count: Int
    ) -> [Double] {
        (0..<count).map { start + Double($0) * increment }
    }

    /// Generate a sequence of values with compound growth.
    public static func generateCompoundValues(
        start: Double,
        growthRate: Double,
        count: Int
    ) -> [Double] {
        (0..<count).map { start * pow(1 + growthRate, Double($0)) }
    }
}

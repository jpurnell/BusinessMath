//
//  ModelTestHelpers.swift
//  BusinessMath Tests
//
//  Created on October 31, 2025.
//

import XCTest
import RealModule
@testable import BusinessMath

// MARK: - Model Test Case Base

/// Base test case class with helper assertions for financial models.
class ModelTestCase: XCTestCase {

    // MARK: - Model Assertions

    /// Assert that a model has the expected revenue.
    func assertModel(
        _ model: FinancialModel,
        hasRevenue expected: Double,
        accuracy: Double = 0.01,
		file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actual = model.calculateRevenue()
        XCTAssertEqual(
            actual,
            expected,
            accuracy: accuracy,
            "Expected revenue \(expected), got \(actual)",
            file: file,
            line: line
        )
    }

    /// Assert that a model has the expected costs.
    func assertModel(
        _ model: FinancialModel,
        hasCosts expected: Double,
        accuracy: Double = 0.01,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let revenue = model.calculateRevenue()
        let actual = model.calculateCosts(revenue: revenue)
        XCTAssertEqual(
            actual,
            expected,
            accuracy: accuracy,
            "Expected costs \(expected), got \(actual)",
            file: file,
            line: line
        )
    }

    /// Assert that a model has the expected profit.
    func assertModel(
        _ model: FinancialModel,
        hasProfit expected: Double,
        accuracy: Double = 0.01,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actual = model.calculateProfit()
        XCTAssertEqual(
            actual,
            expected,
            accuracy: accuracy,
            "Expected profit \(expected), got \(actual)",
            file: file,
            line: line
        )
    }

    /// Assert that a model has a specific number of revenue components.
    func assertModel(
        _ model: FinancialModel,
        hasRevenueComponentCount expected: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            model.revenueComponents.count,
            expected,
            "Expected \(expected) revenue components, got \(model.revenueComponents.count)",
            file: file,
            line: line
        )
    }

    /// Assert that a model has a specific number of cost components.
    func assertModel(
        _ model: FinancialModel,
        hasCostComponentCount expected: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            model.costComponents.count,
            expected,
            "Expected \(expected) cost components, got \(model.costComponents.count)",
            file: file,
            line: line
        )
    }

    // MARK: - Investment Assertions

    /// Assert that an investment has the expected NPV.
    func assertInvestment(
        _ investment: Investment,
        hasNPV expected: Double,
        accuracy: Double = 0.01,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            investment.npv,
            expected,
            accuracy: accuracy,
            "Expected NPV \(expected), got \(investment.npv)",
            file: file,
            line: line
        )
    }

    /// Assert that an investment has a positive NPV.
    func assertInvestmentIsPositive(
        _ investment: Investment,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThan(
            investment.npv,
            0,
            "Expected positive NPV, got \(investment.npv)",
            file: file,
            line: line
        )
    }

    /// Assert that an investment has the expected IRR.
    func assertInvestment(
        _ investment: Investment,
        hasIRR expected: Double,
        accuracy: Double = 0.001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actualIRR = investment.irr else {
            XCTFail("Expected IRR \(expected), but IRR calculation returned nil", file: file, line: line)
            return
        }
        XCTAssertEqual(
            actualIRR,
            expected,
            accuracy: accuracy,
            "Expected IRR \(expected), got \(actualIRR)",
            file: file,
            line: line
        )
    }

    // MARK: - Time Series Assertions

    /// Assert that a time series has the expected number of values.
    func assertTimeSeries<T: Real>(
        _ series: TimeSeries<T>,
        hasCount expected: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            series.count,
            expected,
            "Expected time series count \(expected), got \(series.count)",
            file: file,
            line: line
        )
    }

    /// Assert that a time series has the expected value at an index.
    func assertTimeSeries<T: Real & Equatable>(
        _ series: TimeSeries<T>,
        hasValue expected: T,
        atIndex index: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard index < series.count else {
            XCTFail("Index \(index) out of bounds for time series of count \(series.count)", file: file, line: line)
            return
        }
        let actual = series.valuesArray[index]
        XCTAssertEqual(
            actual,
            expected,
            "Expected value \(expected) at index \(index), got \(actual)",
            file: file,
            line: line
        )
    }

    // MARK: - Scenario Assertions

    /// Assert that a scenario set has the expected number of scenarios.
    func assertScenarioSet(
        _ scenarioSet: ScenarioSet,
        hasCount expected: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            scenarioSet.scenarios.count,
            expected,
            "Expected \(expected) scenarios, got \(scenarioSet.scenarios.count)",
            file: file,
            line: line
        )
    }

    /// Assert that a scenario exists by name.
    func assertScenarioSet(
        _ scenarioSet: ScenarioSet,
        hasScenarioNamed name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let found = scenarioSet.scenario(named: name) != nil
        XCTAssertTrue(found, "Expected scenario named '\(name)' to exist", file: file, line: line)
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
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual, expected, accuracy: accuracy, file: file, line: line)
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

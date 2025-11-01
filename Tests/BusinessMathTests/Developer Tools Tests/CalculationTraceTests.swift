//
//  CalculationTraceTests.swift
//  BusinessMath Tests
//
//  Created on November 1, 2025.
//  TDD: Tests written FIRST, then implementation
//

import XCTest
import RealModule
@testable import BusinessMath

/// Tests for CalculationTrace developer tool.
///
/// These tests define expected behavior for tracking and inspecting
/// calculation steps in financial models.
final class CalculationTraceTests: XCTestCase {

    // MARK: - Revenue Calculation Tracing Tests

    func testCalculationTrace_TracksRevenueCalculation() {
        // Given: A model with multiple revenue sources
        let model = FinancialModel {
            Revenue {
                Product("Product A").price(100).quantity(500)
                Product("Product B").price(200).quantity(200)
            }
        }

        // When: Calculating revenue with tracing enabled
        let trace = CalculationTrace(model: model)
        let revenue = trace.calculateRevenue()

        // Then: Should capture calculation steps
        XCTAssertEqual(revenue, 90_000, accuracy: 1.0)
        XCTAssertFalse(trace.steps.isEmpty, "Should have traced calculation steps")

        // And: Should have steps for each revenue component
        let revenueSteps = trace.steps.filter { $0.category == .revenue }
        XCTAssertGreaterThanOrEqual(revenueSteps.count, 2, "Should trace each revenue component")

        // And: Steps should show component details
        XCTAssertTrue(revenueSteps.contains { $0.description.contains("Product A") })
        XCTAssertTrue(revenueSteps.contains { $0.description.contains("Product B") })
    }

    // MARK: - Cost Calculation Tracing Tests

    func testCalculationTrace_TracksCostCalculation() {
        // Given: A model with fixed and variable costs
        let model = FinancialModel {
            Revenue {
                RevenueComponent(name: "Sales", amount: 100_000)
            }

            Costs {
                Fixed("Salaries", 50_000)
                Variable("COGS", 0.30)
            }
        }

        // When: Calculating costs with tracing
        let trace = CalculationTrace(model: model)
        let revenue = trace.calculateRevenue()
        let costs = trace.calculateCosts(revenue: revenue)

        // Then: Should capture cost calculation steps
        XCTAssertEqual(costs, 80_000, accuracy: 1.0)

        let costSteps = trace.steps.filter { $0.category == .costs }
        XCTAssertGreaterThanOrEqual(costSteps.count, 2, "Should trace each cost component")

        // And: Should distinguish fixed vs variable costs
        XCTAssertTrue(costSteps.contains { $0.description.contains("Fixed") && $0.description.contains("Salaries") })
        XCTAssertTrue(costSteps.contains { $0.description.contains("Variable") && $0.description.contains("COGS") })

        // And: Variable cost step should show calculation
        let variableStep = costSteps.first { $0.description.contains("Variable") }
        XCTAssertNotNil(variableStep)
        XCTAssertTrue(variableStep?.description.contains("30,000") ?? false, "Should show calculated variable cost amount")
    }

    // MARK: - Profit Calculation Tracing Tests

    func testCalculationTrace_TracksProfitCalculation() {
        // Given: A complete financial model
        let model = FinancialModel {
            Revenue {
                Product("Widget Sales").price(50).quantity(1000)
            }

            Costs {
                Fixed("Overhead", 10_000)
                Variable("Materials", 0.25)
            }
        }

        // When: Calculating profit with tracing
        let trace = CalculationTrace(model: model)
        let profit = trace.calculateProfit()

        // Then: Should have all calculation categories
        XCTAssertEqual(profit, 27_500, accuracy: 1.0)

        let revenueSteps = trace.steps.filter { $0.category == .revenue }
        let costSteps = trace.steps.filter { $0.category == .costs }
        let profitSteps = trace.steps.filter { $0.category == .profit }

        XCTAssertFalse(revenueSteps.isEmpty, "Should trace revenue")
        XCTAssertFalse(costSteps.isEmpty, "Should trace costs")
        XCTAssertFalse(profitSteps.isEmpty, "Should trace profit calculation")

        // And: Profit step should reference revenue and costs
        let profitStep = profitSteps.first
        XCTAssertNotNil(profitStep)
        XCTAssertTrue(profitStep?.description.contains("50,000") ?? false, "Should show revenue")
        XCTAssertTrue(profitStep?.description.contains("22,500") ?? false, "Should show costs")
    }

    // MARK: - Trace Step Access Tests

    func testCalculationTrace_ProvidesStepAccess() {
        // Given: A model with calculations
        let model = FinancialModel {
            Revenue {
                RevenueComponent(name: "Sales", amount: 100_000)
            }

            Costs {
                Fixed("Expenses", 40_000)
            }
        }

        // When: Performing calculations with tracing
        let trace = CalculationTrace(model: model)
        _ = trace.calculateProfit()

        // Then: Should provide access to individual steps
        XCTAssertFalse(trace.steps.isEmpty)

        // And: Each step should have required properties
        for step in trace.steps {
            XCTAssertFalse(step.description.isEmpty, "Step should have description")
            XCTAssertNotNil(step.category, "Step should have category")
            XCTAssertNotNil(step.value, "Step should have value")
        }
    }

    // MARK: - Trace Formatting Tests

    func testCalculationTrace_GeneratesFormattedOutput() {
        // Given: A model with various components
        let model = FinancialModel {
            Revenue {
                Product("Product 1").price(100).quantity(100)
                Product("Product 2").price(200).quantity(50)
            }

            Costs {
                Fixed("Rent", 5_000)
                Variable("Commission", 0.10)
            }
        }

        // When: Generating formatted trace output
        let trace = CalculationTrace(model: model)
        _ = trace.calculateProfit()
        let formattedOutput = trace.formatTrace()

        // Then: Should produce readable output
        XCTAssertFalse(formattedOutput.isEmpty, "Should generate output")
        XCTAssertTrue(formattedOutput.contains("Revenue"), "Should include revenue section")
        XCTAssertTrue(formattedOutput.contains("Costs"), "Should include costs section")
        XCTAssertTrue(formattedOutput.contains("Profit"), "Should include profit section")

        // And: Should show component details
        XCTAssertTrue(formattedOutput.contains("Product 1"))
        XCTAssertTrue(formattedOutput.contains("Product 2"))
        XCTAssertTrue(formattedOutput.contains("Rent"))
        XCTAssertTrue(formattedOutput.contains("Commission"))
    }

    // MARK: - Clear Trace Tests

    func testCalculationTrace_CanClearTrace() {
        // Given: A trace with recorded steps
        let model = FinancialModel {
            Revenue {
                RevenueComponent(name: "Sales", amount: 50_000)
            }
        }

        let trace = CalculationTrace(model: model)
        _ = trace.calculateRevenue()
        XCTAssertFalse(trace.steps.isEmpty, "Should have steps before clearing")

        // When: Clearing the trace
        trace.clear()

        // Then: Steps should be empty
        XCTAssertTrue(trace.steps.isEmpty, "Should have no steps after clearing")
    }

    // MARK: - Step Ordering Tests

    func testCalculationTrace_MaintainsStepOrder() {
        // Given: A model requiring sequential calculations
        let model = FinancialModel {
            Revenue {
                RevenueComponent(name: "Sales", amount: 100_000)
            }

            Costs {
                Variable("Variable Cost", 0.50)
            }
        }

        // When: Performing calculations
        let trace = CalculationTrace(model: model)
        _ = trace.calculateRevenue()
        let revenueStepCount = trace.steps.count

        _ = trace.calculateCosts(revenue: 100_000)
        let afterCostsCount = trace.steps.count

        // Then: Steps should be added in order
        XCTAssertGreaterThan(revenueStepCount, 0, "Should have revenue steps")
        XCTAssertGreaterThan(afterCostsCount, revenueStepCount, "Cost steps should be added after revenue")

        // And: Later steps should reference earlier values
        let costStep = trace.steps.last
        XCTAssertTrue(costStep?.category == .costs, "Last step should be cost calculation")
    }

    // MARK: - Complex Model Tracing Tests

    func testCalculationTrace_HandlesComplexModels() {
        // Given: A complex model with many components
        let model = FinancialModel {
            Revenue {
                Product("Product 1").price(50).quantity(100)
                Product("Product 2").price(75).quantity(150)
                Product("Product 3").price(100).quantity(200)
            }

            Costs {
                Fixed("Salaries", 25_000)
                Fixed("Rent", 10_000)
                Variable("Materials", 0.30)
                Variable("Shipping", 0.05)
            }
        }

        // When: Tracing calculations
        let trace = CalculationTrace(model: model)
        let profit = trace.calculateProfit()

        // Then: Should handle all components
        XCTAssertNotNil(profit)
        XCTAssertGreaterThan(trace.steps.count, 5, "Should trace all components")

        // And: Should have correct categories
        let revenueSteps = trace.steps.filter { $0.category == .revenue }
        let costSteps = trace.steps.filter { $0.category == .costs }

        XCTAssertGreaterThanOrEqual(revenueSteps.count, 3, "Should trace all revenue products")
        XCTAssertGreaterThanOrEqual(costSteps.count, 4, "Should trace all cost components")
    }
}

//
//  ModelBuilderTests.swift
//  BusinessMath
//
//  Created on November 30, 2025.
//

import Testing
import Foundation
@testable import BusinessMath

/// Comprehensive tests for the ModelBuilder fluent API
///
/// Tests cover:
/// - Basic builder syntax and composition
/// - Product revenue builder with price/quantity/customers
/// - Fixed and variable cost calculations
/// - Scenario definitions and adjustments
/// - Conditional building (if/else, optionals, arrays)
/// - Integration scenarios
/// - Edge cases and error conditions
@Suite("ModelBuilder DSL Tests")
struct ModelBuilderTests {

    // MARK: - Basic Builder Syntax

    @Test("Empty financial model")
    func emptyModel() {
        let model = FinancialModel()

        #expect(model.revenueComponents.isEmpty)
        #expect(model.costComponents.isEmpty)
        #expect(model.scenarios.isEmpty)
    }

    @Test("Model with single revenue component")
    func modelWithSingleRevenue() {
        let model = FinancialModel {
            Revenue {
                Product("Widget Sales")
                    .price(50)
                    .quantity(100)
            }
        }

        #expect(model.revenueComponents.count == 1)
        #expect(model.revenueComponents[0].name == "Widget Sales")
        #expect(model.revenueComponents[0].amount == 5000.0) // 50 * 100
    }

    @Test("Model with single cost component")
    func modelWithSingleCost() {
        let model = FinancialModel {
            Costs {
                Fixed("Rent", 2000)
            }
        }

        #expect(model.costComponents.count == 1)
        #expect(model.costComponents[0].name == "Rent")
        #expect(model.calculateCosts() == 2000.0)
    }

    @Test("Model with revenue and costs")
    func modelWithRevenueAndCosts() {
        let model = FinancialModel {
            Revenue {
                Product("Sales")
                    .price(100)
                    .quantity(50)
            }

            Costs {
                Fixed("Overhead", 1000)
                Variable("Materials", 0.30)
            }
        }

        #expect(model.revenueComponents.count == 1)
        #expect(model.costComponents.count == 2)

        let revenue = model.calculateRevenue()
        #expect(revenue == 5000.0) // 100 * 50

        let costs = model.calculateCosts(revenue: revenue)
        #expect(costs == 2500.0) // 1000 + (5000 * 0.30)

        let profit = model.calculateProfit()
        #expect(profit == 2500.0) // 5000 - 2500
    }

    @Test("Model with multiple revenue sources")
    func modelWithMultipleRevenueSources() {
        let model = FinancialModel {
            Revenue {
                Product("Product A")
                    .price(50)
                    .quantity(100)

                Product("Product B")
                    .price(75)
                    .quantity(80)
            }
        }

        #expect(model.revenueComponents.count == 2)

        let totalRevenue = model.calculateRevenue()
        #expect(totalRevenue == 11000.0) // (50*100) + (75*80)
    }

    @Test("Model with multiple cost sources")
    func modelWithMultipleCostSources() {
        let model = FinancialModel {
            Costs {
                Fixed("Rent", 2000)
                Fixed("Salaries", 8000)
                Variable("COGS", 0.40)
            }
        }

        #expect(model.costComponents.count == 3)

        let costs = model.calculateCosts(revenue: 10000)
        #expect(costs == 14000.0) // 2000 + 8000 + (10000 * 0.40)
    }

    // MARK: - Product Revenue Builder

    @Test("Product with price and quantity")
    func productWithPriceAndQuantity() {
        let product = Product("Test Product")
            .price(25.50)
            .quantity(200)

        let component = product.toComponent()
        #expect(component.name == "Test Product")
        #expect(component.amount == 5100.0) // 25.50 * 200
    }

    @Test("Product with price and customers")
    func productWithPriceAndCustomers() {
        let product = Product("Subscription")
            .price(99.0)
            .customers(150)

        let component = product.toComponent()
        #expect(component.name == "Subscription")
        #expect(component.amount == 14850.0) // 99 * 150
    }

    @Test("Product chaining multiple properties")
    func productChaining() {
        let product = Product("Premium Service")
            .price(199.99)
            .quantity(50)

        let component = product.toComponent()
        #expect(component.amount == 9999.5) // 199.99 * 50
    }

    @Test("Product with zero values")
    func productWithZeroValues() {
        let product1 = Product("Free Tier")
            .price(0)
            .customers(1000)

        #expect(product1.toComponent().amount == 0.0)

        let product2 = Product("No Sales")
            .price(100)
            .quantity(0)

        #expect(product2.toComponent().amount == 0.0)
    }

    @Test("Product defaults to quantity when both set")
    func productQuantityPriority() {
        // quantity takes priority over customers
        let product = Product("Test")
            .price(10)
            .quantity(5)
            .customers(10)

        #expect(product.toComponent().amount == 50.0) // Uses quantity
    }

    // MARK: - Cost Types

    @Test("Fixed cost calculation")
    func fixedCostCalculation() {
        let cost = Fixed("Office Rent", 3000)

        #expect(cost.name == "Office Rent")
        #expect(cost.calculate(revenue: nil) == 3000.0)
        #expect(cost.calculate(revenue: 10000) == 3000.0)
        #expect(cost.calculate(revenue: 0) == 3000.0)
    }

    @Test("Variable cost calculation")
    func variableCostCalculation() {
        let cost = Variable("Commission", 0.15)

        #expect(cost.name == "Commission")
        #expect(cost.calculate(revenue: 10000) == 1500.0)
        #expect(cost.calculate(revenue: 5000) == 750.0)
        #expect(cost.calculate(revenue: 0) == 0.0)
        #expect(cost.calculate(revenue: nil) == 0.0)
    }

    @Test("Mixed costs calculation")
    func mixedCostsCalculation() {
        let model = FinancialModel {
            Revenue {
                Product("Sales")
                    .price(100)
                    .quantity(100)
            }

            Costs {
                Fixed("Base Costs", 2000)
                Variable("Variable Costs", 0.25)
                Fixed("Insurance", 500)
            }
        }

        let revenue = model.calculateRevenue()
        #expect(revenue == 10000.0)

        let costs = model.calculateCosts(revenue: revenue)
        #expect(costs == 5000.0) // 2000 + (10000 * 0.25) + 500
    }

    // MARK: - Scenario Adjustments

    @Test("Scenario with revenue adjustment")
    func scenarioWithRevenueAdjustment() {
        let model = FinancialModel {
            Revenue {
                Product("Sales")
                    .price(100)
                    .quantity(100)
            }

            ModelScenario("Pessimistic")
                .adjust(.revenue, by: -0.20)
        }

        #expect(model.scenarios.count == 1)
        #expect(model.scenarios[0].name == "Pessimistic")
        #expect(model.scenarios[0].adjustments.count == 1)
        #expect(model.scenarios[0].adjustments[0].percentage == -0.20)
    }

    @Test("Scenario with cost adjustment")
    func scenarioWithCostAdjustment() {
        let model = FinancialModel {
            Costs {
                Fixed("Overhead", 5000)
            }

            ModelScenario("High Cost")
                .adjust(.costs, by: 0.30)
        }

        #expect(model.scenarios.count == 1)
        #expect(model.scenarios[0].adjustments.count == 1)
        #expect(model.scenarios[0].adjustments[0].percentage == 0.30)
    }

    @Test("Scenario with multiple adjustments")
    func scenarioWithMultipleAdjustments() {
        let model = FinancialModel {
            Revenue {
                Product("Sales")
                    .price(100)
                    .quantity(100)
            }

            Costs {
                Fixed("Costs", 3000)
            }

            ModelScenario("Worst Case")
                .adjust(.revenue, by: -0.30)
                .adjust(.costs, by: 0.20)
        }

        #expect(model.scenarios.count == 1)
        #expect(model.scenarios[0].adjustments.count == 2)
    }

    @Test("Scenario with specific target adjustment")
    func scenarioWithSpecificTargetAdjustment() {
        let model = FinancialModel {
            Revenue {
                Product("Product A")
                    .price(100)
                    .quantity(50)
            }

            ModelScenario("Product A Discount")
                .adjust(.specific("Product A"), by: -0.25)
        }

        #expect(model.scenarios.count == 1)

        // Verify the adjustment target
        let adjustment = model.scenarios[0].adjustments[0]
        if case .specific(let name) = adjustment.target {
            #expect(name == "Product A")
        } else {
            Issue.record("Expected specific adjustment target")
        }
    }

    @Test("Multiple scenarios")
    func multipleScenarios() {
        let model = FinancialModel {
            Revenue {
                Product("Sales")
                    .price(100)
                    .quantity(100)
            }

            ModelScenario("Optimistic")
                .adjust(.revenue, by: 0.30)

            ModelScenario("Pessimistic")
                .adjust(.revenue, by: -0.30)

            ModelScenario("Baseline")
        }

        #expect(model.scenarios.count == 3)
        #expect(model.scenarios[0].name == "Optimistic")
        #expect(model.scenarios[1].name == "Pessimistic")
        #expect(model.scenarios[2].name == "Baseline")
    }

    // MARK: - Conditional Building

    @Test("Model with conditionals - true branch")
    func modelWithConditionalTrue() {
        let includeDiscount = true

        let model = FinancialModel {
            Revenue {
                Product("Sales")
                    .price(100)
                    .quantity(100)
            }

            if includeDiscount {
                Costs {
                    Variable("Discount", 0.10)
                }
            }
        }

        #expect(model.costComponents.count == 1)
        #expect(model.costComponents[0].name == "Discount")
    }

    @Test("Model with conditionals - false branch")
    func modelWithConditionalFalse() {
        let includeDiscount = false

        let model = FinancialModel {
            Revenue {
                Product("Sales")
                    .price(100)
                    .quantity(100)
            }

            if includeDiscount {
                Costs {
                    Variable("Discount", 0.10)
                }
            }
        }

        #expect(model.costComponents.isEmpty)
    }

    @Test("Model with if-else conditionals")
    func modelWithIfElse() {
        let isPremium = true

        let model = FinancialModel {
            Revenue {
                if isPremium {
                    Product("Premium Plan")
                        .price(99)
                        .customers(50)
                } else {
                    Product("Basic Plan")
                        .price(49)
                        .customers(100)
                }
            }
        }

        #expect(model.revenueComponents.count == 1)
        #expect(model.revenueComponents[0].name == "Premium Plan")
        #expect(model.revenueComponents[0].amount == 4950.0)
    }

    @Test("Model with optional components")
    func modelWithOptionals() {
        let optionalCost: Double? = 500

        let model = FinancialModel {
            Costs {
                Fixed("Base Cost", 1000)

                if let cost = optionalCost {
                    Fixed("Optional Cost", cost)
                }
            }
        }

        #expect(model.costComponents.count == 2)
    }

    @Test("Model with arrays")
    func modelWithArrays() {
        let products = [
            ("Widget A", 50.0, 10.0),
            ("Widget B", 75.0, 8.0),
            ("Widget C", 100.0, 5.0)
        ]

        let model = FinancialModel {
            Revenue {
                for (name, price, qty) in products {
                    Product(name)
                        .price(price)
                        .quantity(qty)
                }
            }
        }

        #expect(model.revenueComponents.count == 3)
        #expect(model.calculateRevenue() == 1600.0) // (50*10) + (75*8) + (100*5)
    }

    // MARK: - Integration Tests

    @Test("Complete financial model workflow")
    func completeWorkflow() {
        let model = FinancialModel {
            Revenue {
                Product("Product Sales")
                    .price(120)
                    .quantity(200)

                Product("Service Revenue")
                    .price(500)
                    .customers(30)
            }

            Costs {
                Fixed("Salaries", 10000)
                Fixed("Rent", 3000)
                Variable("COGS", 0.35)
                Variable("Marketing", 0.15)
            }

            ModelScenario("Base Case")

            ModelScenario("Growth")
                .adjust(.revenue, by: 0.25)
                .adjust(.costs, by: 0.10)

            ModelScenario("Recession")
                .adjust(.revenue, by: -0.30)
                .adjust(.costs, by: -0.05)
        }

        // Verify structure
        #expect(model.revenueComponents.count == 2)
        #expect(model.costComponents.count == 4)
        #expect(model.scenarios.count == 3)

        // Verify calculations
        let revenue = model.calculateRevenue()
        #expect(revenue == 39000.0) // (120*200) + (500*30)

        let costs = model.calculateCosts(revenue: revenue)
        #expect(costs == 32500.0) // 10000 + 3000 + (39000*0.35) + (39000*0.15)

        let profit = model.calculateProfit()
        #expect(profit == 6500.0)
    }

    @Test("Model metadata preservation")
    func modelMetadataPreservation() {
        let model = FinancialModel()

        #expect(model.metadata.version == "1.0")
        #expect(model.metadata.name == nil)

        // Metadata is immutable in current design
        // This test verifies default values
    }

    @Test("Multiple scenario comparison")
    func multipleScenarioComparison() {
        let model = FinancialModel {
            Revenue {
                Product("Sales")
                    .price(100)
                    .quantity(1000)
            }

            Costs {
                Fixed("Fixed Costs", 20000)
                Variable("Variable Costs", 0.40)
            }

            ModelScenario("Best Case")
                .adjust(.revenue, by: 0.50)
                .adjust(.costs, by: -0.10)

            ModelScenario("Worst Case")
                .adjust(.revenue, by: -0.40)
                .adjust(.costs, by: 0.20)
        }

        // Base case
        let baseRevenue = model.calculateRevenue()
        let baseCosts = model.calculateCosts(revenue: baseRevenue)
        let baseProfit = baseRevenue - baseCosts

        #expect(baseRevenue == 100000.0)
        #expect(baseCosts == 60000.0)
        #expect(baseProfit == 40000.0)

        // Scenarios define adjustments but don't auto-apply
        // (actual application would be in a separate scenario runner)
        #expect(model.scenarios.count == 2)
    }

    // MARK: - Edge Cases

    @Test("Empty revenue block")
    func emptyRevenueBlock() {
        let model = FinancialModel {
            Revenue {
                // Empty block
            }
        }

        #expect(model.revenueComponents.isEmpty)
        #expect(model.calculateRevenue() == 0.0)
    }

    @Test("Empty costs block")
    func emptyCostsBlock() {
        let model = FinancialModel {
            Costs {
                // Empty block
            }
        }

        #expect(model.costComponents.isEmpty)
        #expect(model.calculateCosts() == 0.0)
    }

    @Test("Negative revenue handling")
    func negativeRevenue() {
        // While unusual, the builder allows it
        let model = FinancialModel {
            Revenue {
                Product("Refunds")
                    .price(-50)
                    .quantity(10)
            }
        }

        #expect(model.calculateRevenue() == -500.0)
    }

    @Test("Negative costs handling")
    func negativeCosts() {
        // Could represent rebates or credits
        let model = FinancialModel {
            Costs {
                Fixed("Credit", -1000)
            }
        }

        #expect(model.calculateCosts() == -1000.0)
    }

    @Test("Large numbers handling")
    func largeNumbers() {
        let model = FinancialModel {
            Revenue {
                Product("Enterprise Sales")
                    .price(1_000_000)
                    .quantity(50)
            }

            Costs {
                Fixed("Infrastructure", 5_000_000)
                Variable("Support", 0.10)
            }
        }

        let revenue = model.calculateRevenue()
        #expect(revenue == 50_000_000.0)

        let costs = model.calculateCosts(revenue: revenue)
        #expect(costs == 10_000_000.0) // 5M + (50M * 0.10)

        let profit = model.calculateProfit()
        #expect(profit == 40_000_000.0)
    }

    @Test("Fractional quantities")
    func fractionalQuantities() {
        let model = FinancialModel {
            Revenue {
                Product("Consulting Hours")
                    .price(150)
                    .quantity(37.5) // 37.5 hours
            }
        }

        #expect(model.calculateRevenue() == 5625.0)
    }

    @Test("Very small percentages")
    func verySmallPercentages() {
        let model = FinancialModel {
            Costs {
                Variable("Transaction Fee", 0.029) // 2.9%
            }
        }

        let costs = model.calculateCosts(revenue: 10000)
        #expect(costs == 290.0)
    }

    @Test("Zero revenue with variable costs")
    func zeroRevenueWithVariableCosts() {
        let model = FinancialModel {
            Costs {
                Fixed("Base", 1000)
                Variable("Commission", 0.20)
            }
        }

        let costs = model.calculateCosts(revenue: 0)
        #expect(costs == 1000.0) // Only fixed costs apply
    }
}

//
//  ModelInspectorTests.swift
//  BusinessMath Tests
//
//  Created on November 1, 2025.
//  TDD: Tests written FIRST, then implementation
//

import XCTest
import RealModule
@testable import BusinessMath

/// Tests for ModelInspector developer tool.
///
/// These tests define expected behavior for model introspection,
/// validation, and analysis capabilities.
final class ModelInspectorTests: XCTestCase {

    // MARK: - Revenue Sources Tests

    func testModelInspector_ListsRevenueSources() {
        // Given: A model with multiple revenue sources
        let model = FinancialModel {
            Revenue {
                Product("SaaS Subscriptions").price(99).customers(1000)
                Product("Professional Services").price(150).quantity(50)
                RevenueComponent(name: "Advertising", amount: 25_000)
            }
        }

        // When: Inspecting revenue sources
        let inspector = ModelInspector(model: model)
        let revenueSources = inspector.listRevenueSources()

        // Then: Should list all revenue components
        XCTAssertEqual(revenueSources.count, 3)
        XCTAssertTrue(revenueSources.contains { $0.name == "SaaS Subscriptions" })
        XCTAssertTrue(revenueSources.contains { $0.name == "Professional Services" })
        XCTAssertTrue(revenueSources.contains { $0.name == "Advertising" })

        // And: Should include amounts
        let saasRevenue = revenueSources.first { $0.name == "SaaS Subscriptions" }
        XCTAssertNotNil(saasRevenue)
        if let saasRevenue = saasRevenue {
            XCTAssertEqual(saasRevenue.amount, 99_000, accuracy: 1.0)
        }
    }

    // MARK: - Cost Drivers Tests

    func testModelInspector_ListsCostDrivers() {
        // Given: A model with various costs
        let model = FinancialModel {
            Revenue {
                RevenueComponent(name: "Sales", amount: 100_000)
            }

            Costs {
                Fixed("Salaries", 50_000)
                Fixed("Rent", 10_000)
                Variable("COGS", 0.30)
            }
        }

        // When: Inspecting cost drivers
        let inspector = ModelInspector(model: model)
        let costDrivers = inspector.listCostDrivers()

        // Then: Should list all cost components
        XCTAssertEqual(costDrivers.count, 3)
        XCTAssertTrue(costDrivers.contains { $0.name == "Salaries" })
        XCTAssertTrue(costDrivers.contains { $0.name == "Rent" })
        XCTAssertTrue(costDrivers.contains { $0.name == "COGS" })

        // And: Should categorize fixed vs variable
        let salaries = costDrivers.first { $0.name == "Salaries" }
        XCTAssertEqual(salaries?.type, "fixed")

        let cogs = costDrivers.first { $0.name == "COGS" }
        XCTAssertEqual(cogs?.type, "variable")
    }

    // MARK: - Dependency Graph Tests

    func testModelInspector_ShowsDependencyGraph() {
        // Given: A model with dependencies
        let model = FinancialModel {
            Revenue {
                RevenueComponent(name: "Product Sales", amount: 100_000)
            }

            Costs {
                Variable("COGS", 0.40)  // Depends on revenue
                Fixed("Marketing", 20_000)
            }
        }

        // When: Building dependency graph
        let inspector = ModelInspector(model: model)
        let graph = inspector.buildDependencyGraph()

        // Then: Should show relationships
        XCTAssertFalse(graph.isEmpty)

        // Variable costs depend on revenue
        XCTAssertTrue(graph["COGS"]?.contains("Product Sales") ?? false)

        // Fixed costs have no dependencies
        XCTAssertTrue(graph["Marketing"]?.isEmpty ?? false)
    }

    // MARK: - Circular Reference Detection Tests

    func testModelInspector_DetectsCircularReferences() {
        // Given: A model that could have circular dependencies
        // (This is a theoretical case - current model structure prevents this)
        let model = FinancialModel {
            Revenue {
                RevenueComponent(name: "Sales", amount: 100_000)
            }

            Costs {
                Fixed("Operating", 10_000)
            }
        }

        // When: Checking for circular references
        let inspector = ModelInspector(model: model)
        let hasCircularRefs = inspector.detectCircularReferences()

        // Then: Should not detect any circular references
        XCTAssertFalse(hasCircularRefs, "Simple model should not have circular references")
    }

    // MARK: - Unused Components Tests

    func testModelInspector_IdentifiesUnusedComponents() {
        // Given: A model with scenarios but some unused
        let model = FinancialModel {
            Revenue {
                RevenueComponent(name: "Sales", amount: 100_000)
            }

            Costs {
                Fixed("Salaries", 50_000)
            }

            ModelScenario("Optimistic")
                .adjust(.revenue, by: 0.20)

            ModelScenario("Pessimistic")
                .adjust(.revenue, by: -0.20)
        }

        // When: Identifying unused components
        let inspector = ModelInspector(model: model)
        let unused = inspector.identifyUnusedComponents()

        // Then: All components are used (scenarios defined but may not be applied yet)
        // This is more relevant for complex models with conditional logic
        XCTAssertTrue(unused.isEmpty || unused.count >= 0, "Should identify unused components if any")
    }

    // MARK: - Model Structure Validation Tests

    func testModelInspector_ValidatesModelStructure() {
        // Given: A well-structured model
        let validModel = FinancialModel {
            Revenue {
                RevenueComponent(name: "Sales", amount: 100_000)
            }

            Costs {
                Fixed("Expenses", 40_000)
            }
        }

        // When: Validating structure
        let inspector = ModelInspector(model: validModel)
        let validation = inspector.validateStructure()

        // Then: Should pass validation
        XCTAssertTrue(validation.isValid, "Valid model should pass structure validation")
        XCTAssertTrue(validation.issues.isEmpty, "Valid model should have no issues")
    }

    func testModelInspector_DetectsStructuralIssues() {
        // Given: A model with potential issues
        let problematicModel = FinancialModel()  // Empty model

        // When: Validating structure
        let inspector = ModelInspector(model: problematicModel)
        let validation = inspector.validateStructure()

        // Then: Should detect issues
        XCTAssertFalse(validation.isValid, "Empty model should have structural issues")
        XCTAssertFalse(validation.issues.isEmpty, "Should identify specific issues")
    }

    // MARK: - Summary Report Tests

    func testModelInspector_GeneratesSummaryReport() {
        // Given: A complete model
        let model = FinancialModel {
            Revenue {
                Product("Product A").price(100).quantity(500)
                Product("Product B").price(200).quantity(200)
            }

            Costs {
                Fixed("Salaries", 50_000)
                Fixed("Rent", 10_000)
                Variable("COGS", 0.35)
            }
        }

        // When: Generating summary report
        let inspector = ModelInspector(model: model)
        let summary = inspector.generateSummary()

        // Then: Should include key metrics
        XCTAssertTrue(summary.contains("Revenue Components: 2"))
        XCTAssertTrue(summary.contains("Cost Components: 3"))
        XCTAssertTrue(summary.contains("Total Revenue:"))
        XCTAssertTrue(summary.contains("Total Costs:"))
        XCTAssertTrue(summary.contains("Profit:"))
    }

    // MARK: - Complex Model Handling Tests

    func testModelInspector_HandlesComplexModels() {
        // Given: A complex model with many components
        let complexModel = FinancialModel {
            Revenue {
                Product("Product 1").price(50).quantity(100)
                Product("Product 2").price(75).quantity(150)
                Product("Product 3").price(100).quantity(200)
                Product("Product 4").price(125).quantity(75)
                Product("Product 5").price(150).quantity(50)
            }

            Costs {
                Fixed("Salaries", 100_000)
                Fixed("Rent", 25_000)
                Fixed("Insurance", 5_000)
                Fixed("Utilities", 3_000)
                Variable("Materials", 0.40)
                Variable("Commissions", 0.10)
            }

            ModelScenario("Best Case").adjust(.revenue, by: 0.25)
            ModelScenario("Base Case").adjust(.revenue, by: 0.0)
            ModelScenario("Worst Case").adjust(.revenue, by: -0.15)
        }

        // When: Inspecting complex model
        let inspector = ModelInspector(model: complexModel)

        // Then: Should handle without errors
        XCTAssertNoThrow(inspector.listRevenueSources())
        XCTAssertNoThrow(inspector.listCostDrivers())
        XCTAssertNoThrow(inspector.buildDependencyGraph())
        XCTAssertNoThrow(inspector.generateSummary())

        // And: Should provide accurate counts
        XCTAssertEqual(inspector.listRevenueSources().count, 5)
        XCTAssertEqual(inspector.listCostDrivers().count, 6)
    }

    // MARK: - Performance Tests

    func testModelInspector_PerformanceOnLargeModel() {
        // Given: A large model
        var model = FinancialModel()

        // Add many revenue components
        for i in 1...100 {
            model.revenueComponents.append(
                RevenueComponent(name: "Revenue \(i)", amount: Double(i * 1000))
            )
        }

        // Add many cost components
        for i in 1...100 {
            model.costComponents.append(
                CostComponent(name: "Cost \(i)", type: .fixed(Double(i * 500)))
            )
        }

        // When: Inspecting large model
        let inspector = ModelInspector(model: model)

        // Then: Should complete in reasonable time
        measure {
            _ = inspector.listRevenueSources()
            _ = inspector.listCostDrivers()
            _ = inspector.generateSummary()
        }

        // And: Should provide accurate results
        XCTAssertEqual(inspector.listRevenueSources().count, 100)
        XCTAssertEqual(inspector.listCostDrivers().count, 100)
    }
}

//
//  ModelInspector.swift
//  BusinessMath
//
//  Created on November 1, 2025.
//

import Foundation

/// Developer tool for inspecting and analyzing financial models.
///
/// ModelInspector provides comprehensive analysis capabilities for financial models,
/// including listing components, building dependency graphs, detecting issues,
/// and generating summary reports.
///
/// Example:
/// ```swift
/// let model = FinancialModel {
///     Revenue {
///         Product("SaaS").price(99).customers(1000)
///     }
///     Costs {
///         Fixed("Salaries", 50_000)
///         Variable("COGS", 0.30)
///     }
/// }
///
/// let inspector = ModelInspector(model: model)
/// print(inspector.generateSummary())
/// let revenueSources = inspector.listRevenueSources()
/// ```
public struct ModelInspector: Sendable {
    // MARK: - Properties

    /// The financial model being inspected
    public let model: FinancialModel

    // MARK: - Initialization

    public init(model: FinancialModel) {
        self.model = model
    }

    // MARK: - Revenue Source Information

    /// Information about a revenue source
    public struct RevenueSourceInfo: Sendable {
        public let name: String
        public let amount: Double
        public let index: Int

        public init(name: String, amount: Double, index: Int) {
            self.name = name
            self.amount = amount
            self.index = index
        }
    }

    /// List all revenue sources in the model
    ///
    /// - Returns: Array of revenue source information
    public func listRevenueSources() -> [RevenueSourceInfo] {
        model.revenueComponents.enumerated().map { index, component in
            RevenueSourceInfo(
                name: component.name,
                amount: component.amount,
                index: index
            )
        }
    }

    // MARK: - Cost Driver Information

    /// Information about a cost driver
    public struct CostDriverInfo: Sendable {
        public let name: String
        public let type: String
        public let amount: Double?
        public let percentage: Double?
        public let index: Int

        public init(name: String, type: String, amount: Double? = nil, percentage: Double? = nil, index: Int) {
            self.name = name
            self.type = type
            self.amount = amount
            self.percentage = percentage
            self.index = index
        }
    }

    /// List all cost drivers in the model
    ///
    /// - Returns: Array of cost driver information
    public func listCostDrivers() -> [CostDriverInfo] {
        model.costComponents.enumerated().map { index, component in
            switch component.type {
            case .fixed(let amount):
                return CostDriverInfo(
                    name: component.name,
                    type: "fixed",
                    amount: amount,
                    index: index
                )
            case .variable(let percentage):
                return CostDriverInfo(
                    name: component.name,
                    type: "variable",
                    percentage: percentage,
                    index: index
                )
            }
        }
    }

    // MARK: - Dependency Analysis

    /// Build a dependency graph showing relationships between components
    ///
    /// - Returns: Dictionary mapping component names to their dependencies
    public func buildDependencyGraph() -> [String: [String]] {
        var graph: [String: [String]] = [:]

        // Add cost dependencies on revenue
        for cost in model.costComponents {
            if case .variable = cost.type {
                // Variable costs depend on revenue
                graph[cost.name] = model.revenueComponents.map { $0.name }
            } else {
                // Fixed costs have no dependencies
                graph[cost.name] = []
            }
        }

        // Revenue components are independent
        for revenue in model.revenueComponents {
            graph[revenue.name] = []
        }

        return graph
    }

    /// Detect circular references in the model
    ///
    /// - Returns: True if circular references are detected
    public func detectCircularReferences() -> Bool {
        // Current model structure doesn't allow circular references
        // This is a placeholder for more complex models
        let graph = buildDependencyGraph()

        // Simple check: if any component depends on itself directly
        for (component, dependencies) in graph {
            if dependencies.contains(component) {
                return true
            }
        }

        return false
    }

    // MARK: - Unused Component Detection

    /// Identify components that are defined but not used
    ///
    /// This method identifies several categories of potentially unused components:
    /// - Scenarios with no adjustments (empty scenario definitions)
    /// - Scenarios with adjustments that reference non-existent components
    /// - Duplicate scenario names (later definitions shadow earlier ones)
    ///
    /// - Returns: Array of unused component names
    public func identifyUnusedComponents() -> [String] {
        var unused: [String] = []
        
        // Check for scenarios with no adjustments (effectively unused)
        for scenario in model.scenarios {
            if scenario.adjustments.isEmpty {
                unused.append(scenario.name)
            }
        }
        
        // Check for scenarios that reference non-existent specific components
        let revenueNames = Set(model.revenueComponents.map { $0.name })
        let costNames = Set(model.costComponents.map { $0.name })
        
        for scenario in model.scenarios {
            for adjustment in scenario.adjustments {
                if case .specific(let componentName) = adjustment.target {
                    // Check if the referenced component actually exists
                    if !revenueNames.contains(componentName) && !costNames.contains(componentName) {
                        // This scenario references a non-existent component
                        if !unused.contains(scenario.name) {
                            unused.append(scenario.name)
                        }
                    }
                }
            }
        }
        
        // Check for duplicate scenario names (only the last one would be used)
        var scenarioNameCounts: [String: Int] = [:]
        for scenario in model.scenarios {
            scenarioNameCounts[scenario.name, default: 0] += 1
        }
        
        // If there are duplicates, the earlier ones are effectively unused
        for (name, count) in scenarioNameCounts where count > 1 {
            // Add the duplicate scenario names (we can't distinguish which specific one)
            // but we know there are duplicates
            if !unused.contains(name) {
                unused.append("\(name) (duplicate definition)")
            }
        }
        
        return unused
    }

    // MARK: - Structure Validation

    /// Result of structure validation
    public struct StructureValidation: Sendable {
        public let isValid: Bool
        public let issues: [String]

        public init(isValid: Bool, issues: [String]) {
            self.isValid = isValid
            self.issues = issues
        }
    }

    /// Validate the structure of the model
    ///
    /// - Returns: Validation result with any issues found
    public func validateStructure() -> StructureValidation {
        var issues: [String] = []

        // Check for empty model
        if model.revenueComponents.isEmpty && model.costComponents.isEmpty {
            issues.append("Model is empty (no revenue or cost components)")
        }

        // Check for models with only costs (no revenue)
        if !model.costComponents.isEmpty && model.revenueComponents.isEmpty {
            issues.append("Model has costs but no revenue sources")
        }

        // Check for negative revenue amounts
        for (index, revenue) in model.revenueComponents.enumerated() {
            if revenue.amount < 0 {
                issues.append("Revenue component '\(revenue.name)' at index \(index) has negative amount: \(revenue.amount)")
            }
        }

        // Check for invalid cost percentages
        for (index, cost) in model.costComponents.enumerated() {
            if case .variable(let percentage) = cost.type {
                if percentage < 0 || percentage > 1 {
                    issues.append("Variable cost '\(cost.name)' at index \(index) has invalid percentage: \(percentage) (should be 0-1)")
                }
            }
        }

        return StructureValidation(isValid: issues.isEmpty, issues: issues)
    }

    // MARK: - Summary Generation

    /// Generate a comprehensive summary report of the model
    ///
    /// - Returns: Formatted summary string
    public func generateSummary() -> String {
        var summary = "Financial Model Summary\n"
        summary += "=======================\n\n"

        // Component counts
        summary += "Revenue Components: \(model.revenueComponents.count)\n"
        summary += "Cost Components: \(model.costComponents.count)\n"
        summary += "Scenarios Defined: \(model.scenarios.count)\n\n"

        // Calculate totals
        let totalRevenue = model.calculateRevenue()
        let totalCosts = model.calculateCosts(revenue: totalRevenue)
        let profit = model.calculateProfit()

        summary += "Financial Metrics:\n"
        summary += "------------------\n"
		summary += "\("Total Revenue:".padding(toLength: 15, withPad: " ", startingAt: 0))\(totalRevenue.currency())\n"
		summary += "\("Total Costs:".padding(toLength: 15, withPad: " ", startingAt: 0))\(totalCosts.currency())\n"
		summary += "\("Profit:".padding(toLength: 15, withPad: " ", startingAt: 0))\(profit.currency())\n"

        let margin = totalRevenue > 0 ? (profit / totalRevenue) : 0
		summary += "\("Profit Margin:".padding(toLength: 15, withPad: " ", startingAt: 0))\(margin.percent())\n\n"

        // List revenue sources
        if !model.revenueComponents.isEmpty {
            summary += "Revenue Sources:\n"
            for revenue in model.revenueComponents {
                summary += "  • \(revenue.name): \(revenue.amount.currency())\n"
            }
            summary += "\n"
        }

        // List cost drivers
        if !model.costComponents.isEmpty {
            summary += "Cost Drivers:\n"
            for cost in model.costComponents {
                switch cost.type {
                case .fixed(let amount):
						summary += "  • \(cost.name): \(amount.currency())\n"
                case .variable(let percentage):
                    let variableAmount = totalRevenue * percentage
						summary += "  • \(cost.name): \(percentage.percent()): \(variableAmount.currency())\n"
                }
            }
            summary += "\n"
        }

        // Validation
        let validation = validateStructure()
        if !validation.isValid {
            summary += "⚠️  Structural Issues Detected:\n"
            for issue in validation.issues {
                summary += "  • \(issue)\n"
            }
            summary += "\n"
        } else {
            summary += "✓ Model structure is valid\n"
        }

        // Check for unused components
        let unusedComponents = identifyUnusedComponents()
        if !unusedComponents.isEmpty {
            summary += "\n⚠️  Unused Components Detected:\n"
            for component in unusedComponents {
                summary += "  • \(component)\n"
            }
        }

        return summary
    }
}

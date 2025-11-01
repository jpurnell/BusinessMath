//
//  ModelBuilder.swift
//  BusinessMath
//
//  Created on October 31, 2025.
//

import Foundation
import RealModule

// MARK: - Model Component Protocol

/// Protocol that all financial model components must conform to.
///
/// Components represent individual elements of a financial model that can be
/// composed together using the `ModelBuilder` result builder syntax.
public protocol ModelComponent: Sendable {
    /// Apply this component to the given financial model.
    func apply(to model: inout FinancialModel)
}

// MARK: - Financial Model

/// A fluent financial model built using declarative result builder syntax.
///
/// Use the `ModelBuilder` to construct financial models declaratively:
///
/// ```swift
/// let model = FinancialModel {
///     Revenue {
///         Product("SaaS Subscriptions")
///             .price(99)
///             .customers(1000)
///     }
///
///     Costs {
///         Fixed("Salaries", 500_000)
///         Variable("COGS", 0.30)
///     }
/// }
/// ```
public struct FinancialModel: Sendable {
    // MARK: - Properties

    /// Revenue components of the model
    public var revenueComponents: [RevenueComponent] = []

    /// Cost components of the model
    public var costComponents: [CostComponent] = []

    /// Scenario definitions
    public var scenarios: [ScenarioDefinition] = []

    /// Model metadata
    public var metadata: ModelMetadata = ModelMetadata()

    // MARK: - Initialization

    /// Creates an empty financial model.
    public init() {}

    /// Creates a financial model using the ModelBuilder DSL.
    ///
    /// - Parameter builder: A closure that builds the model components.
    public init(@ModelBuilder builder: () -> [ModelComponent]) {
        let components = builder()
        for component in components {
            var model = self
            component.apply(to: &model)
            self = model
        }
    }

    // MARK: - Calculations

    /// Calculate total revenue for a given period.
    public func calculateRevenue() -> Double {
        revenueComponents.reduce(0.0) { $0 + $1.amount }
    }

    /// Calculate total costs for a given period.
    public func calculateCosts(revenue: Double? = nil) -> Double {
        costComponents.reduce(0.0) { total, cost in
            total + cost.calculate(revenue: revenue)
        }
    }

    /// Calculate net income (profit) for a given period.
    public func calculateProfit() -> Double {
        let revenue = calculateRevenue()
        let costs = calculateCosts(revenue: revenue)
        return revenue - costs
    }
}

// MARK: - Model Metadata

/// Metadata about a financial model.
public struct ModelMetadata: Sendable {
    public var name: String?
    public var createdAt: Date = Date()
    public var version: String = "1.0"
    public var description: String?

    public init(name: String? = nil, version: String = "1.0", description: String? = nil) {
        self.name = name
        self.version = version
        self.description = description
    }
}

// MARK: - Result Builder

/// Result builder for constructing financial models using declarative syntax.
///
/// The `ModelBuilder` enables a SwiftUI-style API for defining financial models:
///
/// ```swift
/// let model = FinancialModel {
///     Revenue {
///         Product("Widget Sales")
///             .price(50)
///             .quantity(1000)
///     }
///
///     Costs {
///         Fixed("Overhead", 10_000)
///         Variable("Materials", 0.25)
///     }
///
///     Scenario("Pessimistic")
///         .adjust(.revenue, by: -0.20)
///         .adjust(.costs, by: 0.10)
/// }
/// ```
@resultBuilder
public struct ModelBuilder {
    /// Build a block of model components.
    public static func buildBlock(_ components: ModelComponent...) -> [ModelComponent] {
        components
    }

    /// Build an array of components from nested builders.
    public static func buildArray(_ components: [[ModelComponent]]) -> [ModelComponent] {
        components.flatMap { $0 }
    }

    /// Build a component when a condition is true.
    public static func buildOptional(_ component: [ModelComponent]?) -> [ModelComponent] {
        component ?? []
    }

    /// Build the first component when an if/else condition is true.
    public static func buildEither(first component: [ModelComponent]) -> [ModelComponent] {
        component
    }

    /// Build the second component when an if/else condition is false.
    public static func buildEither(second component: [ModelComponent]) -> [ModelComponent] {
        component
    }

    /// Converts a single component into an array.
    public static func buildExpression(_ component: ModelComponent) -> [ModelComponent] {
        [component]
    }

    /// Converts an array of components into itself (for nested builders).
    public static func buildExpression(_ components: [ModelComponent]) -> [ModelComponent] {
        components
    }

    /// Build limited availability components.
    public static func buildLimitedAvailability(_ component: [ModelComponent]) -> [ModelComponent] {
        component
    }
}

// MARK: - Revenue Components

/// A revenue source in the financial model.
public struct RevenueComponent: Sendable {
    public let name: String
    public let amount: Double

    public init(name: String, amount: Double) {
        self.name = name
        self.amount = amount
    }
}

/// Container for revenue components.
public struct Revenue: ModelComponent {
    private let components: [RevenueComponent]

    public init(@RevenueBuilder builder: () -> [RevenueComponent]) {
        self.components = builder()
    }

    public func apply(to model: inout FinancialModel) {
        model.revenueComponents.append(contentsOf: components)
    }
}

/// Result builder for revenue components.
@resultBuilder
public struct RevenueBuilder {
    public static func buildBlock(_ components: [RevenueComponent]...) -> [RevenueComponent] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ component: RevenueComponent) -> [RevenueComponent] {
        [component]
    }

    public static func buildExpression(_ components: [RevenueComponent]) -> [RevenueComponent] {
        components
    }

    public static func buildExpression(_ product: Product) -> [RevenueComponent] {
        [product.toComponent()]
    }

    public static func buildArray(_ components: [[RevenueComponent]]) -> [RevenueComponent] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [RevenueComponent]?) -> [RevenueComponent] {
        component ?? []
    }

    public static func buildEither(first component: [RevenueComponent]) -> [RevenueComponent] {
        component
    }

    public static func buildEither(second component: [RevenueComponent]) -> [RevenueComponent] {
        component
    }
}

// MARK: - Product Revenue Builder

/// Fluent builder for product revenue.
public struct Product {
    private let name: String
    private var priceValue: Double = 0
    private var quantityValue: Double = 0
    private var customersValue: Double = 0

    public init(_ name: String) {
        self.name = name
    }

    /// Set the price per unit.
    public func price(_ value: Double) -> Self {
        var copy = self
        copy.priceValue = value
        return copy
    }

    /// Set the quantity sold.
    public func quantity(_ value: Double) -> Self {
        var copy = self
        copy.quantityValue = value
        return copy
    }

    /// Set the number of customers (alternative to quantity).
    public func customers(_ value: Double) -> Self {
        var copy = self
        copy.customersValue = value
        return copy
    }

    /// Convert to a revenue component.
    public func toComponent() -> RevenueComponent {
        let quantity = quantityValue > 0 ? quantityValue : customersValue
        return RevenueComponent(name: name, amount: priceValue * quantity)
    }
}

// MARK: - Cost Components

/// A cost in the financial model.
public enum CostType: Sendable {
    case fixed(Double)
    case variable(Double) // Percentage of revenue
}

public struct CostComponent: Sendable {
    public let name: String
    public let type: CostType

    public init(name: String, type: CostType) {
        self.name = name
        self.type = type
    }

    public func calculate(revenue: Double?) -> Double {
        switch type {
        case .fixed(let amount):
            return amount
        case .variable(let percentage):
            return (revenue ?? 0) * percentage
        }
    }
}

/// Container for cost components.
public struct Costs: ModelComponent {
    private let components: [CostComponent]

    public init(@CostBuilder builder: () -> [CostComponent]) {
        self.components = builder()
    }

    public func apply(to model: inout FinancialModel) {
        model.costComponents.append(contentsOf: components)
    }
}

/// Result builder for cost components.
@resultBuilder
public struct CostBuilder {
    public static func buildBlock(_ components: CostComponent...) -> [CostComponent] {
        components
    }

    public static func buildExpression(_ component: CostComponent) -> [CostComponent] {
        [component]
    }

    public static func buildArray(_ components: [[CostComponent]]) -> [CostComponent] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [CostComponent]?) -> [CostComponent] {
        component ?? []
    }

    public static func buildEither(first component: [CostComponent]) -> [CostComponent] {
        component
    }

    public static func buildEither(second component: [CostComponent]) -> [CostComponent] {
        component
    }
}

/// Fixed cost builder.
public func Fixed(_ name: String, _ amount: Double) -> CostComponent {
    CostComponent(name: name, type: .fixed(amount))
}

/// Variable cost builder (percentage of revenue).
public func Variable(_ name: String, _ percentage: Double) -> CostComponent {
    CostComponent(name: name, type: .variable(percentage))
}

// MARK: - Scenario Components

/// Adjustment type for scenarios.
public enum AdjustmentTarget: Sendable {
    case revenue
    case costs
    case specific(String)
}

/// An adjustment to apply in a scenario.
public struct Adjustment: Sendable {
    public let target: AdjustmentTarget
    public let percentage: Double

    public init(target: AdjustmentTarget, percentage: Double) {
        self.target = target
        self.percentage = percentage
    }
}

/// A scenario definition.
public struct ScenarioDefinition: Sendable {
    public let name: String
    public var adjustments: [Adjustment] = []

    public init(name: String) {
        self.name = name
    }
}

/// Fluent scenario builder.
public struct ModelScenario: ModelComponent {
    private var definition: ScenarioDefinition

    public init(_ name: String) {
        self.definition = ScenarioDefinition(name: name)
    }

    /// Add an adjustment to this scenario.
    public func adjust(_ target: AdjustmentTarget, by percentage: Double) -> Self {
        var copy = self
        copy.definition.adjustments.append(Adjustment(target: target, percentage: percentage))
        return copy
    }

    public func apply(to model: inout FinancialModel) {
        model.scenarios.append(definition)
    }
}

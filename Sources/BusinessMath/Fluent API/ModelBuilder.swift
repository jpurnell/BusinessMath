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

    /// Optional entity association
    public var entity: Entity?

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

    /// Creates a financial model associated with an entity.
    ///
    /// - Parameters:
    ///   - entity: The entity this model represents
    ///   - builder: A closure that builds the model components
    public init(entity: Entity, @ModelBuilder builder: () -> [ModelComponent]) {
        self.entity = entity
        let components = builder()
        for component in components {
            var model = self
            component.apply(to: &model)
            self = model
        }
    }

    // MARK: - Calculations

    /// Calculate total revenue (single-period, backward compatible).
    public func calculateRevenue() -> Double {
        revenueComponents.reduce(0.0) { $0 + $1.amount }
    }

    /// Calculate total costs (single-period, backward compatible).
    public func calculateCosts(revenue: Double? = nil) -> Double {
        costComponents.reduce(0.0) { total, cost in
            total + cost.calculate(revenue: revenue)
        }
    }

    /// Calculate net income/profit (single-period, backward compatible).
    public func calculateProfit() -> Double {
        let revenue = calculateRevenue()
        let costs = calculateCosts(revenue: revenue)
        return revenue - costs
    }

    /// Calculate total revenue for a specific period.
    ///
    /// Example:
    /// ```swift
    /// let revenue2024 = model.totalRevenue(for: .year(2024))
    /// ```
    public func totalRevenue(for period: Period) -> Double {
        var accountValues: [Double] = []

        let total = revenueComponents.reduce(0.0) { sum, component in
            let value = component.value(for: period)
            accountValues.append(value)

            // Record individual account access
            DebugContext.shared.recordStep(
                operation: "GetAccount(\(component.name))",
                input: "Period(\(period.label))",
                output: String(format: "%.0f", value)
            )

            return sum + value
        }

        // Record sum operation
        DebugContext.shared.recordStep(
            operation: "Sum(Revenue Accounts)",
            input: "[\(accountValues.map { String(format: "%.0f", $0) }.joined(separator: ", "))]",
            output: String(format: "%.0f", total)
        )

        return total
    }

    /// Calculate total expenses for a specific period.
    ///
    /// Example:
    /// ```swift
    /// let expenses2024 = model.totalExpenses(for: .year(2024))
    /// ```
    public func totalExpenses(for period: Period) -> Double {
        let revenue = totalRevenue(for: period)
        var expenseValues: [Double] = []

        let total = costComponents.reduce(0.0) { sum, component in
            let value = component.value(for: period, revenue: revenue)
            expenseValues.append(value)

            // Record individual expense access
            DebugContext.shared.recordStep(
                operation: "GetExpense(\(component.name))",
                input: "Period(\(period.label)), Revenue(\(String(format: "%.0f", revenue)))",
                output: String(format: "%.0f", value)
            )

            return sum + value
        }

        // Record sum operation
        DebugContext.shared.recordStep(
            operation: "Sum(Expense Accounts)",
            input: "[\(expenseValues.map { String(format: "%.0f", $0) }.joined(separator: ", "))]",
            output: String(format: "%.0f", total)
        )

        return total
    }

    /// Calculate profit for a specific period.
    ///
    /// Example:
    /// ```swift
    /// let profit2024 = model.profit(for: .year(2024))
    /// ```
    public func profit(for period: Period) -> Double {
        totalRevenue(for: period) - totalExpenses(for: period)
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
    public static func buildBlock(_ components: [ModelComponent]...) -> [ModelComponent] {
        components.flatMap { $0 }
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

    /// Allow Product to be used directly in buildModel { } blocks.
    ///
    /// Converts Product to a DirectProduct component that applies the revenue.
    public static func buildExpression(_ product: Product) -> [ModelComponent] {
        [DirectProduct(product)]
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
    public let amount: Double  // Single-period amount (backward compatible)
    public let timeSeries: TimeSeries<Double>?  // Optional multi-period time series

    /// Create a revenue component with a single amount (backward compatible).
    public init(name: String, amount: Double) {
        self.name = name
        self.amount = amount
        self.timeSeries = nil
    }

    /// Create a revenue component with a time series of values.
    ///
    /// Example:
    /// ```swift
    /// let periods = [Period.year(2023), Period.year(2024)]
    /// let values = [100_000.0, 110_000.0]
    /// let revenue = RevenueComponent(name: "Product Sales", periods: periods, values: values)
    /// ```
    public init(name: String, periods: [Period], values: [Double]) {
        self.name = name
        self.amount = 0  // Not used when time series is present
        self.timeSeries = TimeSeries(periods: periods, values: values)
    }

    /// Get the value for a specific period.
    ///
    /// Returns the time series value if available, otherwise returns the single amount.
    public func value(for period: Period) -> Double {
        timeSeries?[period] ?? amount
    }
}

/// Container for revenue components.
public struct Revenue: ModelComponent {
    private let components: [RevenueComponent]

    /// Create a revenue container with nested components using the builder DSL.
    ///
    /// Example:
    /// ```swift
    /// Revenue {
    ///     Product("Widget").price(10).quantity(1000)
    ///     Product("Gadget").price(20).quantity(500)
    /// }
    /// ```
    public init(@RevenueBuilder builder: () -> [RevenueComponent]) {
        self.components = builder()
    }

    /// Create a single revenue component directly with time series data.
    ///
    /// Example:
    /// ```swift
    /// Revenue("Subscription Services", periods: months, values: [5_000, 5_500, 6_000])
    /// ```
    public init(_ name: String, periods: [Period], values: [Double]) {
        self.components = [RevenueComponent(name: name, periods: periods, values: values)]
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
public struct Product: Sendable {
    private let name: String
    private var priceValue: Double = 0
    private var quantityValue: Double = 0
    private var customersValue: Double = 0

    // Time series support
    private var priceSeries: TimeSeries<Double>?
    private var quantitySeries: TimeSeries<Double>?

    public init(_ name: String) {
        self.name = name
    }

    /// Set the price per unit (single value).
    public func price(_ value: Double) -> Self {
        var copy = self
        copy.priceValue = value
        return copy
    }

    /// Set the price per unit with time series support.
    ///
    /// Example:
    /// ```swift
    /// let periods = [Period.year(2023), Period.year(2024)]
    /// Product("Widget")
    ///     .price(periods: periods, values: [10.0, 10.5])
    ///     .quantity(periods: periods, values: [10_000, 11_000])
    /// ```
    public func price(periods: [Period], values: [Double]) -> Self {
        var copy = self
        copy.priceSeries = TimeSeries(periods: periods, values: values)
        return copy
    }

    /// Set the quantity sold (single value).
    public func quantity(_ value: Double) -> Self {
        var copy = self
        copy.quantityValue = value
        return copy
    }

    /// Set the quantity sold with time series support.
    ///
    /// Example:
    /// ```swift
    /// let periods = [Period.year(2023), Period.year(2024)]
    /// Product("Widget")
    ///     .price(periods: periods, values: [10.0, 10.5])
    ///     .quantity(periods: periods, values: [10_000, 11_000])
    /// ```
    public func quantity(periods: [Period], values: [Double]) -> Self {
        var copy = self
        copy.quantitySeries = TimeSeries(periods: periods, values: values)
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
        // If we have time series for both price and quantity, create time series revenue
        if let priceSeries = priceSeries, let quantitySeries = quantitySeries {
            // Multiply price × quantity for each period
            let periods = priceSeries.periods
            let revenues = zip(priceSeries.valuesArray, quantitySeries.valuesArray).map { $0 * $1 }
            return RevenueComponent(name: name, periods: periods, values: revenues)
        }

        // Otherwise, use single-value calculation (backward compatible)
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
    public let timeSeries: TimeSeries<Double>?  // Optional multi-period time series
    public let expenseType: ExpenseType?  // Optional classification for inter-company comparisons

    /// Create a cost component with a single value (backward compatible).
    public init(name: String, type: CostType) {
        self.name = name
        self.type = type
        self.timeSeries = nil
        self.expenseType = nil
    }

    /// Create a cost component with a time series of fixed values.
    ///
    /// Example:
    /// ```swift
    /// let periods = [Period.year(2023), Period.year(2024)]
    /// let values = [50_000.0, 55_000.0]
    /// let cost = CostComponent(name: "Salaries", periods: periods, values: values)
    /// ```
    public init(name: String, periods: [Period], values: [Double], expenseType: ExpenseType? = nil) {
        self.name = name
        self.type = .fixed(0)  // Not used when time series is present
        self.timeSeries = TimeSeries(periods: periods, values: values)
        self.expenseType = expenseType
    }

    /// Calculate cost for a given revenue amount.
    ///
    /// If time series is present, returns value for the given period.
    /// Otherwise calculates based on cost type (fixed or variable).
    public func calculate(revenue: Double?, for period: Period? = nil) -> Double {
        // If we have a time series and a period, use that
        if let period = period, let value = timeSeries?[period] {
            return value
        }

        // Otherwise use the single-value calculation
        switch type {
        case .fixed(let amount):
            return amount
        case .variable(let percentage):
            return (revenue ?? 0) * percentage
        }
    }

    /// Get the value for a specific period.
    ///
    /// Returns the time series value if available, otherwise calculates based on cost type.
    public func value(for period: Period, revenue: Double? = nil) -> Double {
        calculate(revenue: revenue, for: period)
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
    public static func buildBlock(_ components: [CostComponent]...) -> [CostComponent] {
        components.flatMap { $0 }
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

/// Fixed cost builder (alias matching documented API).
///
/// Example:
/// ```swift
/// Costs {
///     FixedCost("Rent", 5_000)
///     FixedCost("Salaries", 15_000)
/// }
/// ```
public func FixedCost(_ name: String, _ amount: Double) -> CostComponent {
    Fixed(name, amount)
}

/// Fixed cost with time series support.
///
/// Example:
/// ```swift
/// let periods = [Period.year(2023), Period.year(2024)]
/// FixedCost("Salaries", periods: periods, value: 50_000)
/// ```
public func FixedCost(_ name: String, periods: [Period], value: Double) -> CostComponent {
    let values = Array(repeating: value, count: periods.count)
    return CostComponent(name: name, periods: periods, values: values)
}

/// Variable cost builder (alias matching documented API).
///
/// Example:
/// ```swift
/// Costs {
///     VariableCost("Materials", rate: 0.40)
///     VariableCost("Shipping", rate: 0.05)
/// }
/// ```
public func VariableCost(_ name: String, rate: Double) -> CostComponent {
    Variable(name, rate)
}

/// Create an expense with time series data and expense type classification.
///
/// This function creates a cost component with explicit expense type classification,
/// which is useful for inter-company comparisons where colloquial names may differ
/// but the underlying expense category is the same.
///
/// Example:
/// ```swift
/// let model = buildModel(for: company) {
///     Revenue("Sales", periods: quarters, values: [100_000, 110_000, 120_000, 130_000])
///     Expense("COGS", periods: quarters, values: [60_000, 66_000, 72_000, 78_000], type: .costOfGoodsSold)
///     Expense("OpEx", periods: quarters, values: [20_000, 20_000, 20_000, 20_000], type: .operatingExpense)
/// }
/// ```
///
/// - Parameters:
///   - name: The name of the expense (can be company-specific)
///   - periods: Time periods for the expense values
///   - values: Expense amounts for each period
///   - type: The standardized expense type for classification
///
/// - Returns: A cost component with expense type classification
public func Expense(_ name: String, periods: [Period], values: [Double], type: ExpenseType) -> CostComponent {
    CostComponent(name: name, periods: periods, values: values, expenseType: type)
}

// MARK: - CostComponent ModelComponent Conformance

/// Extend CostComponent to conform to ModelComponent.
///
/// This allows costs to be used directly in buildModel { } without wrapping in Costs { }.
extension CostComponent: ModelComponent {
    public func apply(to model: inout FinancialModel) {
        model.costComponents.append(self)
    }
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

// MARK: - Top-Level Builder Functions (Documented API)

/// Build a financial model using the ModelBuilder DSL.
///
/// Wrapper function providing an alternative entry point matching documented API.
///
/// Example:
/// ```swift
/// let model = buildModel {
///     Revenue {
///         Product("Widget Sales").price(50).quantity(1000)
///     }
///     Costs {
///         Fixed("Overhead", 10_000)
///     }
/// }
/// ```
public func buildModel(@ModelBuilder builder: () -> [ModelComponent]) -> FinancialModel {
    FinancialModel(builder: builder)
}

/// Build a financial model associated with an entity.
///
/// Example:
/// ```swift
/// let company = Entity(name: "Acme Corp")
/// let model = buildModel(for: company) {
///     Revenue {
///         Product("Product A").price(100).quantity(500)
///     }
/// }
/// ```
public func buildModel(for entity: Entity, @ModelBuilder builder: () -> [ModelComponent]) -> FinancialModel {
    FinancialModel(entity: entity, builder: builder)
}

// MARK: - Direct Component Constructors

/// Create a product revenue component directly at the model level.
///
/// Products must specify periods for both price and quantity to work at the top level.
///
/// Example:
/// ```swift
/// let model = buildModel {
///     Product("Widget")
///         .price(periods: months, values: [10.0, 10.5, 11.0])
///         .quantity(periods: months, values: [1000, 1100, 1200])
/// }
/// ```
public struct DirectProduct: ModelComponent {
    private let product: Product

    public init(_ product: Product) {
        self.product = product
    }

    public func apply(to model: inout FinancialModel) {
        model.revenueComponents.append(product.toComponent())
    }
}

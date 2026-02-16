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

    /// Get the value for a specific account and period, throwing if not found.
    ///
    /// This method searches both revenue and cost components for an account
    /// with the specified name and returns its value for the given period.
    ///
    /// - Parameters:
    ///   - account: The name of the account to retrieve.
    ///   - period: The period for which to get the value.
    /// - Returns: The account value for the specified period.
    /// - Throws: ``BusinessMathError/missingData(account:period:)`` if account not found.
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     let revenue = try model.getValue(account: "Product Sales", period: "2025-Q1")
    ///     print("Q1 Revenue: $\(revenue)")
    /// } catch let error as BusinessMathError {
    ///     if case .missingData(let account, let period) = error {
    ///         print("Missing data for '\(account)' in period \(period)")
    ///         // Provide data or use default
    ///     }
    /// }
    /// ```
    ///
    /// ## Recovery Strategies
    /// - Add the missing account to the model
    /// - Use a default value with `try? model.getValue(...) ?? defaultValue`
    /// - Fill missing data with interpolation
    public func getValue(account: String, period: String) throws -> Double {
        // Convert period string to Period
        // For simplicity, we'll search for components by name and use current revenue for cost calculations

        // Search revenue components
        if let revenueComponent = revenueComponents.first(where: { $0.name == account }) {
            // For now, we'll use a year-based period lookup
            // In a full implementation, you'd parse the period string properly
            let periodObj = Period.year(2025) // Placeholder - should parse period string
            return revenueComponent.value(for: periodObj)
        }

        // Search cost components
        if let costComponent = costComponents.first(where: { $0.name == account }) {
            let periodObj = Period.year(2025) // Placeholder - should parse period string
            let currentRevenue = totalRevenue(for: periodObj)
            return costComponent.value(for: periodObj, revenue: currentRevenue)
        }

        // Account not found - throw missing data error
        throw BusinessMathError.missingData(account: account, period: period)
    }

    /// Get the value for a specific account and period object, throwing if not found.
    ///
    /// This method searches both revenue and cost components for an account
    /// with the specified name and returns its value for the given period.
    ///
    /// - Parameters:
    ///   - account: The name of the account to retrieve.
    ///   - period: The Period object for which to get the value.
    /// - Returns: The account value for the specified period.
    /// - Throws: ``BusinessMathError/missingData(account:period:)`` if account not found.
    ///
    /// ## Example
    /// ```swift
    /// do {
    ///     let q1 = Period.quarter(year: 2025, quarter: 1)
    ///     let revenue = try model.getValue(account: "Product Sales", period: q1)
    ///     print("Q1 Revenue: $\(revenue)")
    /// } catch let error as BusinessMathError {
    ///     print("Error: \(error.errorDescription!)")
    /// }
    /// ```
    public func getValue(account: String, period: Period) throws -> Double {
        // Search revenue components
        if let revenueComponent = revenueComponents.first(where: { $0.name == account }) {
            return revenueComponent.value(for: period)
        }

        // Search cost components
        if let costComponent = costComponents.first(where: { $0.name == account }) {
            let currentRevenue = totalRevenue(for: period)
            return costComponent.value(for: period, revenue: currentRevenue)
        }

        // Account not found - throw missing data error
        throw BusinessMathError.missingData(account: account, period: period.label)
    }
}

// MARK: - Model Metadata

/// Metadata about a financial model.
///
/// Use this structure to attach descriptive information to your financial models,
/// including naming, versioning, and documentation. This metadata is useful for
/// model tracking, auditing, and governance.
///
/// ## Usage Example
/// ```swift
/// var metadata = ModelMetadata(
///     name: "SaaS Revenue Model",
///     version: "2.1",
///     description: "Monthly recurring revenue projections with churn"
/// )
///
/// let model = FinancialModel {
///     // ... model components
/// }
/// model.metadata = metadata
/// ```
public struct ModelMetadata: Sendable {
    /// The name of the financial model.
    ///
    /// Use descriptive names that help identify the model's purpose,
    /// such as "Q4 2025 Budget" or "SaaS Growth Scenario".
    public var name: String?

    /// The date and time when the model was created.
    ///
    /// Defaults to the current date when the metadata is initialized.
    public var createdAt: Date = Date()

    /// The version string for this model.
    ///
    /// Use semantic versioning (e.g., "1.0", "2.1") to track model
    /// revisions over time. Defaults to "1.0".
    public var version: String = "1.0"

    /// An optional description of what this model represents.
    ///
    /// Use this field to document the model's purpose, assumptions,
    /// or key methodologies.
    public var description: String?

    /// Creates model metadata with optional name, version, and description.
    ///
    /// - Parameters:
    ///   - name: The name of the model. Defaults to nil.
    ///   - version: The version string. Defaults to "1.0".
    ///   - description: A description of the model. Defaults to nil.
    ///
    /// ## Usage Example
    /// ```swift
    /// let metadata = ModelMetadata(
    ///     name: "Annual Budget Model",
    ///     version: "1.0",
    ///     description: "Initial budget for fiscal year 2025"
    /// )
    /// ```
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
///
/// Revenue components represent individual streams of income in your model.
/// They support both single-period amounts (for backward compatibility) and
/// multi-period time series for more sophisticated modeling.
///
/// Use ``Revenue`` container to group multiple revenue components together,
/// or create components directly for use in financial models.
///
/// ## Usage Example
/// ```swift
/// // Single-period revenue
/// let simpleRevenue = RevenueComponent(name: "Product Sales", amount: 100_000)
///
/// // Multi-period revenue with time series
/// let periods = [Period.year(2023), Period.year(2024), Period.year(2025)]
/// let values = [100_000.0, 110_000.0, 121_000.0]
/// let growingRevenue = RevenueComponent(name: "Product Sales", periods: periods, values: values)
/// ```
///
/// ## SeeAlso
/// - ``Revenue``
/// - ``Product``
/// - ``ModelComponent``
public struct RevenueComponent: Sendable {
    /// The name of this revenue source.
    ///
    /// Use descriptive names that identify the revenue stream,
    /// such as "Product Sales", "Subscription Revenue", or "Consulting Fees".
    public let name: String

    /// Single-period amount for backward compatibility.
    ///
    /// When ``timeSeries`` is nil, this amount is used. When a time series
    /// is provided, this field is set to 0 and ignored.
    public let amount: Double

    /// Optional multi-period time series of revenue values.
    ///
    /// When provided, enables period-specific revenue calculations.
    /// Use this for models that span multiple time periods.
    public let timeSeries: TimeSeries<Double>?

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

// MARK: - RevenueComponent ModelComponent Conformance

/// Extend RevenueComponent to conform to ModelComponent.
///
/// This allows revenue components to be used directly in FinancialModel { } without wrapping in Revenue { }.
extension RevenueComponent: ModelComponent {
    /// Applies this revenue component to the financial model.
    ///
    /// This method is called automatically by the ``ModelBuilder`` result builder
    /// when you include revenue components in your model definition.
    ///
    /// - Parameter model: The financial model to modify.
    ///
    /// ## Implementation Note
    /// Appends this component to the model's ``FinancialModel/revenueComponents`` array.
    public func apply(to model: inout FinancialModel) {
        model.revenueComponents.append(self)
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

    /// Applies all contained revenue components to the financial model.
    ///
    /// This method is called automatically by the ``ModelBuilder`` result builder
    /// when you include a Revenue block in your model definition.
    ///
    /// - Parameter model: The financial model to modify.
    ///
    /// ## Implementation Note
    /// Appends all components in this container to the model's ``FinancialModel/revenueComponents`` array.
    public func apply(to model: inout FinancialModel) {
        model.revenueComponents.append(contentsOf: components)
    }
}

/// Result builder for revenue components.
///
/// This result builder enables SwiftUI-style declarative syntax for defining
/// revenue components within a ``Revenue`` container. You typically don't use
/// this directly—it's applied automatically via the `@RevenueBuilder` attribute.
///
/// ## Supported Syntax
/// The builder supports:
/// - Multiple revenue components
/// - Conditional revenue (`if`/`else`)
/// - Optional revenue (`if let`)
/// - Loops (`for`...`in`)
/// - Direct ``Product`` expressions
///
/// ## Usage Example
/// ```swift
/// Revenue {
///     Product("Widget").price(50).quantity(1000)
///     Product("Gadget").price(100).quantity(500)
///
///     if includeServices {
///         RevenueComponent(name: "Consulting", amount: 50_000)
///     }
/// }
/// ```
///
/// ## SeeAlso
/// - ``Revenue``
/// - ``RevenueComponent``
/// - ``ModelBuilder``
@resultBuilder
public struct RevenueBuilder {
    /// Combines multiple arrays of revenue components into a single array.
    ///
    /// This method is called when you have multiple revenue components
    /// in a Revenue block.
    public static func buildBlock(_ components: [RevenueComponent]...) -> [RevenueComponent] {
        components.flatMap { $0 }
    }

    /// Converts a single revenue component into an array.
    ///
    /// This method wraps individual components in an array so they can
    /// be combined with other components.
    public static func buildExpression(_ component: RevenueComponent) -> [RevenueComponent] {
        [component]
    }

    /// Passes through an array of revenue components unchanged.
    ///
    /// Enables nested builder results to be flattened properly.
    public static func buildExpression(_ components: [RevenueComponent]) -> [RevenueComponent] {
        components
    }

    /// Converts a ``Product`` builder into a revenue component.
    ///
    /// This allows you to use Product directly in Revenue blocks without
    /// explicitly calling ``Product/toComponent()``.
    public static func buildExpression(_ product: Product) -> [RevenueComponent] {
        [product.toComponent()]
    }

    /// Flattens arrays of revenue component arrays.
    ///
    /// Enables `for`...`in` loops within Revenue blocks.
    public static func buildArray(_ components: [[RevenueComponent]]) -> [RevenueComponent] {
        components.flatMap { $0 }
    }

    /// Handles optional revenue components.
    ///
    /// Returns the components if present, or an empty array if nil.
    /// Enables `if let` and other optional patterns.
    public static func buildOptional(_ component: [RevenueComponent]?) -> [RevenueComponent] {
        component ?? []
    }

    /// Returns the first branch of an `if`/`else` expression.
    ///
    /// Called when the condition evaluates to true.
    public static func buildEither(first component: [RevenueComponent]) -> [RevenueComponent] {
        component
    }

    /// Returns the second branch of an `if`/`else` expression.
    ///
    /// Called when the condition evaluates to false.
    public static func buildEither(second component: [RevenueComponent]) -> [RevenueComponent] {
        component
    }
}

// MARK: - Product Revenue Builder

/// Fluent builder for product revenue.
///
/// Product provides a convenient, chainable API for defining revenue from
/// product sales. It calculates revenue as `price × quantity` and supports
/// both single values and time series data.
///
/// ## Usage Example
/// ```swift
/// // Simple single-period product
/// Product("Widget")
///     .price(50)
///     .quantity(1000)  // Revenue = $50,000
///
/// // Multi-period product with time series
/// let periods = [Period.year(2023), Period.year(2024), Period.year(2025)]
/// Product("Widget")
///     .price(periods: periods, values: [50, 52, 54])
///     .quantity(periods: periods, values: [1000, 1100, 1200])
/// ```
///
/// ## Alternative APIs
/// You can use ``customers(_:)`` instead of ``quantity(_:)`` when modeling
/// subscription or service-based revenue where the count represents people
/// rather than units.
///
/// ## SeeAlso
/// - ``RevenueComponent``
/// - ``Revenue``
public struct Product: Sendable {
    private let name: String
    private var priceValue: Double = 0
    private var quantityValue: Double = 0
    private var customersValue: Double = 0

    // Time series support
    private var priceSeries: TimeSeries<Double>?
    private var quantitySeries: TimeSeries<Double>?

    /// Creates a new product revenue builder.
    ///
    /// After initialization, chain ``price(_:)`` and ``quantity(_:)`` methods
    /// to specify the revenue calculation.
    ///
    /// - Parameter name: The name of the product or revenue stream.
    ///
    /// ## Usage Example
    /// ```swift
    /// let widget = Product("Premium Widget")
    ///     .price(99.99)
    ///     .quantity(500)
    /// ```
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
///
/// Cost components represent expenses in your model. They can be either:
/// - **Fixed costs**: Constant amounts regardless of revenue (e.g., rent, salaries)
/// - **Variable costs**: Percentages of revenue (e.g., COGS, commissions)
///
/// Cost components support both single-period values and multi-period time series
/// for sophisticated financial modeling.
///
/// ## Usage Example
/// ```swift
/// // Fixed cost
/// let rent = CostComponent(name: "Office Rent", type: .fixed(5_000))
///
/// // Variable cost (30% of revenue)
/// let cogs = CostComponent(name: "COGS", type: .variable(0.30))
///
/// // Time series cost
/// let periods = [Period.year(2023), Period.year(2024)]
/// let salaries = CostComponent(
///     name: "Salaries",
///     periods: periods,
///     values: [500_000, 550_000]
/// )
/// ```
///
/// ## SeeAlso
/// - ``CostType``
/// - ``Costs``
/// - ``Fixed(_:_:)``
/// - ``Variable(_:_:)``
public enum CostType: Sendable {
    case fixed(Double)
    case variable(Double) // Percentage of revenue
}

/// A cost component in the financial model.
///
/// Represents an individual expense item with support for fixed and variable
/// costs, time series data, and standardized expense classification.
///
/// ## SeeAlso
/// - ``CostType``
/// - ``ExpenseType``
/// - ``Costs``
public struct CostComponent: Sendable {
    /// The name of this cost component.
    ///
    /// Use descriptive names like "Salaries", "Marketing", or "COGS".
    public let name: String

    /// The type of cost (fixed amount or variable percentage).
    ///
    /// Ignored when ``timeSeries`` is provided.
    public let type: CostType

    /// Optional multi-period time series of cost values.
    ///
    /// When provided, enables period-specific cost calculations.
    public let timeSeries: TimeSeries<Double>?

    /// Optional standardized expense classification.
    ///
    /// Useful for inter-company comparisons where different companies
    /// may use different naming conventions for similar expense categories.
    ///
    /// Example: "COGS" vs "Cost of Sales" both map to ``ExpenseType/costOfGoodsSold``.
    public let expenseType: ExpenseType?

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
///
/// Use the Costs container to group multiple expense items together in your
/// financial model using declarative syntax.
///
/// ## Usage Example
/// ```swift
/// FinancialModel {
///     Revenue {
///         Product("Widget").price(50).quantity(1000)
///     }
///
///     Costs {
///         Fixed("Rent", 5_000)
///         Fixed("Salaries", 50_000)
///         Variable("COGS", 0.30)
///         Variable("Commission", 0.05)
///     }
/// }
/// ```
///
/// ## SeeAlso
/// - ``CostComponent``
/// - ``Fixed(_:_:)``
/// - ``Variable(_:_:)``
/// - ``CostBuilder``
public struct Costs: ModelComponent {
    private let components: [CostComponent]

    /// Creates a costs container with nested cost components using builder syntax.
    ///
    /// - Parameter builder: A closure that builds the cost components.
    ///
    /// ## Usage Example
    /// ```swift
    /// Costs {
    ///     Fixed("Office Rent", 10_000)
    ///     Fixed("Salaries", 75_000)
    ///     Variable("Materials", 0.40)
    /// }
    /// ```
    public init(@CostBuilder builder: () -> [CostComponent]) {
        self.components = builder()
    }

    /// Applies all contained cost components to the financial model.
    ///
    /// This method is called automatically by the ``ModelBuilder`` result builder
    /// when you include a Costs block in your model definition.
    ///
    /// - Parameter model: The financial model to modify.
    ///
    /// ## Implementation Note
    /// Appends all components in this container to the model's ``FinancialModel/costComponents`` array.
    public func apply(to model: inout FinancialModel) {
        model.costComponents.append(contentsOf: components)
    }
}

/// Result builder for cost components.
///
/// This result builder enables SwiftUI-style declarative syntax for defining
/// cost components within a ``Costs`` container. You typically don't use this
/// directly—it's applied automatically via the `@CostBuilder` attribute.
///
/// ## Supported Syntax
/// The builder supports:
/// - Multiple cost components
/// - Conditional costs (`if`/`else`)
/// - Optional costs (`if let`)
/// - Loops (`for`...`in`)
///
/// ## Usage Example
/// ```swift
/// Costs {
///     Fixed("Base Salary", 50_000)
///     Variable("Commission", 0.10)
///
///     if includeMarketing {
///         Fixed("Marketing", 15_000)
///     }
///
///     for dept in departments {
///         Fixed("\(dept) Overhead", dept.overhead)
///     }
/// }
/// ```
///
/// ## SeeAlso
/// - ``Costs``
/// - ``CostComponent``
/// - ``ModelBuilder``
@resultBuilder
public struct CostBuilder {
    /// Combines multiple arrays of cost components into a single array.
    ///
    /// This method is called when you have multiple cost components
    /// in a Costs block.
    public static func buildBlock(_ components: [CostComponent]...) -> [CostComponent] {
        components.flatMap { $0 }
    }

    /// Converts a single cost component into an array.
    ///
    /// This method wraps individual components in an array so they can
    /// be combined with other components.
    public static func buildExpression(_ component: CostComponent) -> [CostComponent] {
        [component]
    }

    /// Flattens arrays of cost component arrays.
    ///
    /// Enables `for`...`in` loops within Costs blocks.
    public static func buildArray(_ components: [[CostComponent]]) -> [CostComponent] {
        components.flatMap { $0 }
    }

    /// Handles optional cost components.
    ///
    /// Returns the components if present, or an empty array if nil.
    /// Enables `if let` and other optional patterns.
    public static func buildOptional(_ component: [CostComponent]?) -> [CostComponent] {
        component ?? []
    }

    /// Returns the first branch of an `if`/`else` expression.
    ///
    /// Called when the condition evaluates to true.
    public static func buildEither(first component: [CostComponent]) -> [CostComponent] {
        component
    }

    /// Returns the second branch of an `if`/`else` expression.
    ///
    /// Called when the condition evaluates to false.
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

/// Create a revenue component with a single amount (convenience function).
///
/// This function provides an ergonomic way to add revenue components
/// to a financial model using the result builder syntax. Use this when
/// you have a simple revenue amount without time series data.
///
/// Example:
/// ```swift
/// FinancialModel {
///     RevenueAmount("Product Sales", 100_000)
///     RevenueAmount("Services", 50_000)
///     CostAmount("COGS", 60_000)
/// }
/// ```
public func RevenueAmount(_ name: String, _ amount: Double) -> RevenueComponent {
    RevenueComponent(name: name, amount: amount)
}

/// Create a fixed cost component (convenience function).
///
/// This function provides an ergonomic way to add cost components
/// to a financial model using the result builder syntax. Use this when
/// you have a simple fixed cost amount.
///
/// Example:
/// ```swift
/// FinancialModel {
///     RevenueAmount("Sales", 100_000)
///     CostAmount("COGS", 60_000)
///     CostAmount("Marketing", 15_000)
/// }
/// ```
public func CostAmount(_ name: String, _ amount: Double) -> CostComponent {
    CostComponent(name: name, type: .fixed(amount))
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
    /// Applies this cost component to the financial model.
    ///
    /// This method is called automatically by the ``ModelBuilder`` result builder
    /// when you include cost components in your model definition.
    ///
    /// - Parameter model: The financial model to modify.
    ///
    /// ## Implementation Note
    /// Appends this component to the model's ``FinancialModel/costComponents`` array.
    ///
    /// ## Usage Example
    /// ```swift
    /// // CostComponent can be used directly without Costs { } wrapper
    /// let model = buildModel {
    ///     RevenueAmount("Sales", 100_000)
    ///     CostAmount("COGS", 60_000)  // Applied via this method
    ///     CostAmount("OpEx", 20_000)   // Applied via this method
    /// }
    /// ```
    public func apply(to model: inout FinancialModel) {
        model.costComponents.append(self)
    }
}

// MARK: - Scenario Components

/// Adjustment type for scenarios.
///
/// Specifies what component(s) of the financial model should be adjusted
/// in a scenario analysis.
///
/// ## Cases
/// - ``revenue``: Adjust all revenue components
/// - ``costs``: Adjust all cost components
/// - ``specific(_:)``: Adjust a specific component by name
///
/// ## Usage Example
/// ```swift
/// ModelScenario("Pessimistic")
///     .adjust(.revenue, by: -0.20)           // All revenue down 20%
///     .adjust(.specific("COGS"), by: 0.10)   // COGS up 10%
/// ```
public enum AdjustmentTarget: Sendable {
    case revenue
    case costs
    case specific(String)
}

/// An adjustment to apply in a scenario.
///
/// Represents a percentage change to apply to a model component in a scenario.
/// Adjustments are typically defined using the fluent ``ModelScenario`` API.
///
/// ## Usage Example
/// ```swift
/// let adj = Adjustment(target: .revenue, percentage: -0.15)  // 15% decrease
/// ```
///
/// ## SeeAlso
/// - ``AdjustmentTarget``
/// - ``ModelScenario``
/// - ``ScenarioDefinition``
public struct Adjustment: Sendable {
    /// The target component(s) to adjust.
    public let target: AdjustmentTarget

    /// The percentage change to apply (e.g., -0.20 for -20%, 0.10 for +10%).
    public let percentage: Double

    /// Creates an adjustment with a target and percentage.
    ///
    /// - Parameters:
    ///   - target: What to adjust (revenue, costs, or a specific component)
    ///   - percentage: The percentage change (e.g., 0.10 = +10%, -0.20 = -20%)
    ///
    /// ## Usage Example
    /// ```swift
    /// let optimistic = Adjustment(target: .revenue, percentage: 0.25)
    /// let pessimistic = Adjustment(target: .costs, percentage: 0.15)
    /// ```
    public init(target: AdjustmentTarget, percentage: Double) {
        self.target = target
        self.percentage = percentage
    }
}

/// A scenario definition.
///
/// Defines a named scenario with a collection of adjustments to apply to
/// a financial model. Scenarios enable "what-if" analysis.
///
/// ## Usage Example
/// ```swift
/// var scenario = ScenarioDefinition(name: "Best Case")
/// scenario.adjustments = [
///     Adjustment(target: .revenue, percentage: 0.30),
///     Adjustment(target: .costs, percentage: -0.10)
/// ]
/// ```
///
/// Typically, you'll use the more ergonomic ``ModelScenario`` fluent API instead
/// of constructing ScenarioDefinition directly.
///
/// ## SeeAlso
/// - ``ModelScenario``
/// - ``Adjustment``
public struct ScenarioDefinition: Sendable {
    /// The name of the scenario (e.g., "Base Case", "Pessimistic", "Optimistic").
    public let name: String

    /// The adjustments to apply in this scenario.
    public var adjustments: [Adjustment] = []

    /// Creates a scenario definition with a name.
    ///
    /// - Parameter name: The scenario name.
    ///
    /// ## Usage Example
    /// ```swift
    /// let scenario = ScenarioDefinition(name: "Worst Case")
    /// ```
    public init(name: String) {
        self.name = name
    }
}

/// Fluent scenario builder.
///
/// ModelScenario provides a chainable API for defining scenarios with adjustments
/// to revenue, costs, or specific components. Use this within a financial model
/// to enable scenario analysis.
///
/// ## Usage Example
/// ```swift
/// let model = FinancialModel {
///     Revenue {
///         Product("Widget").price(50).quantity(1000)
///     }
///
///     Costs {
///         Fixed("Overhead", 10_000)
///         Variable("COGS", 0.30)
///     }
///
///     // Define scenarios
///     ModelScenario("Optimistic")
///         .adjust(.revenue, by: 0.20)
///         .adjust(.costs, by: -0.10)
///
///     ModelScenario("Pessimistic")
///         .adjust(.revenue, by: -0.20)
///         .adjust(.costs, by: 0.15)
/// }
/// ```
///
/// ## SeeAlso
/// - ``ScenarioDefinition``
/// - ``Adjustment``
/// - ``AdjustmentTarget``
public struct ModelScenario: ModelComponent {
    private var definition: ScenarioDefinition

    /// Creates a new scenario with the given name.
    ///
    /// After initialization, chain ``adjust(_:by:)`` calls to define
    /// the adjustments for this scenario.
    ///
    /// - Parameter name: The scenario name (e.g., "Base Case", "Worst Case").
    ///
    /// ## Usage Example
    /// ```swift
    /// ModelScenario("Best Case")
    ///     .adjust(.revenue, by: 0.30)
    ///     .adjust(.costs, by: -0.15)
    /// ```
    public init(_ name: String) {
        self.definition = ScenarioDefinition(name: name)
    }

    /// Add an adjustment to this scenario.
    ///
    /// Returns a new ModelScenario with the adjustment added, enabling
    /// method chaining.
    ///
    /// - Parameters:
    ///   - target: What to adjust (revenue, costs, or specific component)
    ///   - percentage: The percentage change (e.g., 0.10 = +10%, -0.20 = -20%)
    ///
    /// - Returns: A new ModelScenario with the adjustment added.
    ///
    /// ## Usage Example
    /// ```swift
    /// ModelScenario("Growth Scenario")
    ///     .adjust(.revenue, by: 0.50)
    ///     .adjust(.specific("Marketing"), by: 0.25)
    /// ```
    public func adjust(_ target: AdjustmentTarget, by percentage: Double) -> Self {
        var copy = self
        copy.definition.adjustments.append(Adjustment(target: target, percentage: percentage))
        return copy
    }

    /// Applies this scenario definition to the financial model.
    ///
    /// This method is called automatically by the ``ModelBuilder`` result builder
    /// when you include scenarios in your model definition.
    ///
    /// - Parameter model: The financial model to modify.
    ///
    /// ## Implementation Note
    /// Appends this scenario to the model's ``FinancialModel/scenarios`` array.
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
/// DirectProduct is a wrapper that allows ``Product`` builders to be used
/// directly in model blocks without a ``Revenue`` container. This is handled
/// automatically by the ``ModelBuilder`` through its `buildExpression` method.
///
/// Products must specify periods for both price and quantity to work at the top level.
///
/// ## Usage Example
/// ```swift
/// let periods = (1...12).map { Period.month(year: 2025, month: $0) }
/// let prices = Array(repeating: 50.0, count: 12)
/// let quantities = [100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200, 210]
///
/// let model = buildModel {
///     Product("Widget")
///         .price(periods: periods, values: prices)
///         .quantity(periods: periods, values: quantities)
/// }
/// ```
///
/// ## Note
/// You typically don't create DirectProduct instances yourself—the ``ModelBuilder``
/// creates them automatically when you use ``Product`` directly in a model block.
///
/// ## SeeAlso
/// - ``Product``
/// - ``ModelBuilder``
/// - ``RevenueComponent``
public struct DirectProduct: ModelComponent {
    private let product: Product

    /// Creates a direct product wrapper.
    ///
    /// - Parameter product: The product builder to wrap.
    ///
    /// ## Note
	/// This initializer is typically called automatically by ``ModelBuilder/buildExpression(_:)-(Product)``
    /// when you use a ``Product`` directly in a model definition.
    public init(_ product: Product) {
        self.product = product
    }

    /// Applies the product as a revenue component to the financial model.
    ///
    /// Converts the ``Product`` to a ``RevenueComponent`` and adds it to the model.
    ///
    /// - Parameter model: The financial model to modify.
    public func apply(to model: inout FinancialModel) {
        model.revenueComponents.append(product.toComponent())
    }
}

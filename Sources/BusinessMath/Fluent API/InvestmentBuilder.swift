//
//  InvestmentBuilder.swift
//  BusinessMath
//
//  Created on October 31, 2025.
//

import Foundation
import RealModule

// MARK: - Investment

/// A fluent investment analysis tool with auto-calculated metrics.
///
/// Use the `InvestmentBuilder` to define investments declaratively:
///
/// ```swift
/// let investment = Investment {
///     InitialCost(100_000)
///
///     CashFlows {
///         Year(1) => 30_000
///         Year(2) => 35_000
///         Year(3) => 40_000
///         Year(4) => 45_000
///         Year(5) => 50_000
///     }
///
///     DiscountRate(0.10)
/// }
///
/// print(investment.npv)  // Auto-calculated
/// print(investment.irr)  // Auto-calculated
/// ```
public struct Investment: Sendable {
    // MARK: - Properties

    /// Initial investment cost (typically negative)
    public let initialCost: Double

    /// Cash flows by period
    public let cashFlows: [CashFlow]

    /// Discount rate for NPV calculation
    public let discountRate: Double

    /// Optional investment name
    public let name: String?

    /// Optional investment description
    public let investmentDescription: String?

    /// Optional investment category
    public let category: String?

    /// Optional categorized cash flows
    public let cashFlowCategories: [String: [CashFlow]]

    // MARK: - Initialization

    /// Create an investment using the builder DSL.
    public init(@InvestmentBuilder builder: () -> [InvestmentComponent]) {
        let components = builder()

        var initialCost: Double = 0
        var cashFlows: [CashFlow] = []
        var discountRate: Double = 0.10 // Default 10%
        var name: String?
        var description: String?
        var category: String?
        var cashFlowCategories: [String: [CashFlow]] = [:]

        for component in components {
            switch component {
            case .initialCost(let cost):
                initialCost = cost
            case .cashFlows(let flows):
                cashFlows.append(contentsOf: flows)
            case .discountRate(let rate):
                discountRate = rate
            case .name(let n):
                name = n
            case .description(let d):
                description = d
            case .category(let c):
                category = c
            case .cashFlowCategory(let categoryName, let flows):
                cashFlowCategories[categoryName] = flows
                cashFlows.append(contentsOf: flows)
            }
        }

        self.initialCost = initialCost
        self.cashFlows = cashFlows.sorted { $0.period < $1.period }
        self.discountRate = discountRate
        self.name = name
        self.investmentDescription = description
        self.category = category
        self.cashFlowCategories = cashFlowCategories
    }

    // MARK: - Calculated Metrics

    /// Net Present Value (NPV) - automatically calculated using BusinessMath npv() function.
    public var npv: Double {
        let allCashFlows = [-initialCost] + cashFlows.map { $0.amount }
        return BusinessMath.npv(discountRate: discountRate, cashFlows: allCashFlows)
    }

    /// Internal Rate of Return (IRR) - automatically calculated using BusinessMath irr() function.
    ///
    /// Returns `nil` if IRR calculation fails (e.g., all cash flows are positive or negative).
    public var irr: Double? {
        let allCashFlows = [-initialCost] + cashFlows.map { $0.amount }
        return try? BusinessMath.irr(cashFlows: allCashFlows)
    }

    /// Profitability Index - automatically calculated using BusinessMath profitabilityIndex() function.
    public var profitabilityIndex: Double {
        let allCashFlows = [-initialCost] + cashFlows.map { $0.amount }
        return BusinessMath.profitabilityIndex(rate: discountRate, cashFlows: allCashFlows)
    }

    /// Payback period in years - automatically calculated.
    public var paybackPeriod: Double? {
        var cumulative = -initialCost
        for (index, cashFlow) in cashFlows.enumerated() {
            cumulative += cashFlow.amount
            if cumulative >= 0 {
                // Linear interpolation for fractional year
                let previousCumulative = cumulative - cashFlow.amount
                let fraction = -previousCumulative / cashFlow.amount
                return Double(index) + fraction
            }
        }
        return nil // Never pays back
    }

    /// Discounted payback period in years - automatically calculated.
    public var discountedPaybackPeriod: Double? {
        var cumulative = -initialCost
        for (index, cashFlow) in cashFlows.enumerated() {
            let period = Double(index + 1)
            let pv = cashFlow.amount / pow(1 + discountRate, period)
            cumulative += pv
            if cumulative >= 0 {
                // Linear interpolation for fractional year
                let previousCumulative = cumulative - pv
                let fraction = -previousCumulative / pv
                return Double(index) + fraction
            }
        }
        return nil // Never pays back on discounted basis
    }

    /// Total undiscounted cash inflows
    public var totalCashInflows: Double {
        cashFlows.map { $0.amount }.reduce(0, +)
    }

    /// Total return on investment (undiscounted)
    public var totalROI: Double {
        (totalCashInflows - initialCost) / initialCost
    }

    /// Return on investment (alias for totalROI) - matches documented API
    public var roi: Double {
        totalROI
    }
}

// MARK: - Category Methods

extension Investment {
    /// Get NPV for a specific cash flow category
    public func npv(for categoryName: String) -> Double? {
        guard let categoryCashFlows = cashFlowCategories[categoryName] else {
            return nil
        }

        // Calculate NPV for just this category's cash flows using the global npv function
        let categoryFlows = categoryCashFlows.map { $0.amount }
        return BusinessMath.npv(discountRate: discountRate, cashFlows: categoryFlows)
    }
}

// MARK: - Cash Flow

/// A cash flow in a specific period.
///
/// Represents a single cash inflow or outflow occurring in a specific period
/// (typically a year). Used to model investment returns over time.
///
/// ## Usage Example
/// ```swift
/// // Manual creation
/// let cf1 = CashFlow(period: 1, amount: 30_000)
/// let cf2 = CashFlow(period: 2, amount: 35_000)
///
/// // Using convenience syntax
/// let cf3 = Year(3) => 40_000
///
/// // In investment builder
/// let investment = Investment {
///     InitialCost(100_000)
///     CashFlows {
///         Year(1) => 30_000
///         Year(2) => 35_000
///         Year(3) => 40_000
///     }
///     DiscountRate(0.10)
/// }
/// ```
///
/// ## SeeAlso
/// - ``Investment``
/// - ``CashFlowBuilder``
/// - ``Year(_:)``
public struct CashFlow: Sendable {
    /// The period (typically year) when this cash flow occurs.
    ///
    /// Period 1 represents the first year after initial investment,
    /// period 2 the second year, etc. The initial investment (period 0)
    /// is handled separately in ``Investment/initialCost``.
    public let period: Int

    /// The amount of the cash flow.
    ///
    /// Positive for inflows (revenue, savings), negative for outflows
    /// (additional costs, investments).
    public let amount: Double

    /// Creates a cash flow for a specific period.
    ///
    /// - Parameters:
    ///   - period: The period (year) when cash flow occurs
    ///   - amount: The cash flow amount (positive for inflows, negative for outflows)
    ///
    /// ## Usage Example
    /// ```swift
    /// let cashFlow = CashFlow(period: 1, amount: 30_000)
    ///
    /// // Or use convenience initializer
    /// let cashFlow2 = CashFlow(year: 2, amount: 35_000)
    ///
    /// // Or use arrow syntax
    /// let cashFlow3 = Year(3) => 40_000
    /// ```
    public init(period: Int, amount: Double) {
        self.period = period
        self.amount = amount
    }
}

// MARK: - Investment Components

/// Components that can be used to build an investment.
public enum InvestmentComponent: Sendable {
    case initialCost(Double)
    case cashFlows([CashFlow])
    case discountRate(Double)
    case name(String)
    case description(String)
    case category(String)
    case cashFlowCategory(String, [CashFlow])
}

// MARK: - Investment Builder

/// Result builder for constructing investments.
///
/// Enables SwiftUI-style declarative syntax for defining investment analyses.
/// You typically don't use this directly—it's applied via the `@InvestmentBuilder`
/// attribute on ``Investment/init(builder:)`` and ``buildInvestment(builder:)``.
///
/// ## Supported Syntax
/// - Multiple investment components
/// - Conditional components (`if`/`else`)
/// - Optional components (`if let`)
/// - Loops (`for`...`in`)
///
/// ## Usage Example
/// ```swift
/// let shouldIncludeSalvage = true
///
/// let investment = Investment {
///     InitialCost(100_000)
///
///     CashFlows {
///         Year(1) => 30_000
///         Year(2) => 35_000
///         Year(3) => 40_000
///     }
///
///     if shouldIncludeSalvage {
///         CashFlows {
///             Year(4) => 20_000  // Salvage value
///         }
///     }
///
///     DiscountRate(0.10)
///     Name("Equipment Purchase")
/// }
/// ```
///
/// ## SeeAlso
/// - ``Investment``
/// - ``InvestmentComponent``
/// - ``buildInvestment(builder:)``
@resultBuilder
public struct InvestmentBuilder {
    /// Combines multiple arrays of investment components.
    ///
    /// Called when you have multiple components in an investment block.
    public static func buildBlock(_ components: [InvestmentComponent]...) -> [InvestmentComponent] {
        components.flatMap { $0 }
    }

    /// Converts a single component into an array.
    ///
    /// Wraps individual components so they can be combined with others.
    public static func buildExpression(_ component: InvestmentComponent) -> [InvestmentComponent] {
        [component]
    }

    /// Flattens arrays of component arrays.
    ///
    /// Enables `for`...`in` loops within investment blocks.
    public static func buildArray(_ components: [[InvestmentComponent]]) -> [InvestmentComponent] {
        components.flatMap { $0 }
    }

    /// Handles optional investment components.
    ///
    /// Returns the components if present, or an empty array if nil.
    /// Enables `if let` and other optional patterns.
    public static func buildOptional(_ components: [InvestmentComponent]?) -> [InvestmentComponent] {
        components ?? []
    }

    /// Returns the first branch of an `if`/`else` expression.
    ///
    /// Called when the condition evaluates to true.
    public static func buildEither(first components: [InvestmentComponent]) -> [InvestmentComponent] {
        components
    }

    /// Returns the second branch of an `if`/`else` expression.
    ///
    /// Called when the condition evaluates to false.
    public static func buildEither(second components: [InvestmentComponent]) -> [InvestmentComponent] {
        components
    }
}

// MARK: - Cash Flow Builder

/// Result builder for constructing cash flows.
///
/// Enables declarative syntax for defining cash flows within a ``CashFlows(builder:)``
/// block. Automatically sorts cash flows by period for proper NPV calculation.
///
/// ## Supported Syntax
/// - Arrow syntax: `Year(1) => 30_000`
/// - Direct construction: `CashFlow(period: 1, amount: 30_000)`
/// - Conditional cash flows (`if`/`else`)
/// - Optional cash flows (`if let`)
/// - Loops (`for`...`in`)
///
/// ## Usage Example
/// ```swift
/// let investment = Investment {
///     InitialCost(100_000)
///
///     CashFlows {
///         // Arrow syntax (most readable)
///         Year(1) => 30_000
///         Year(2) => 35_000
///
///         // Conditional cash flow
///         if includeBonus {
///             Year(3) => 50_000
///         } else {
///             Year(3) => 40_000
///         }
///
///         // Loop over years
///         for year in 4...6 {
///             Year(year) => 45_000
///         }
///     }
///
///     DiscountRate(0.10)
/// }
/// ```
///
/// ## Automatic Sorting
/// Cash flows are automatically sorted by period, so you can define them
/// in any order—they'll be properly ordered for calculations.
///
/// ## SeeAlso
/// - ``CashFlow``
/// - ``CashFlows(builder:)``
/// - ``Year(_:)``
@resultBuilder
public struct CashFlowBuilder {
    /// Combines multiple arrays of cash flows and sorts by period.
    ///
    /// Called when you have multiple cash flows in a CashFlows block.
    /// Automatically sorts by period for proper chronological ordering.
    public static func buildBlock(_ cashFlows: [CashFlow]...) -> [CashFlow] {
        cashFlows.flatMap { $0 }.sorted { $0.period < $1.period }
    }

    /// Converts a single cash flow into an array.
    ///
    /// Wraps individual cash flows so they can be combined with others.
    public static func buildExpression(_ cashFlow: CashFlow) -> [CashFlow] {
        [cashFlow]
    }

    /// Passes through an array of cash flows unchanged.
    ///
    /// Enables nested builder results to be flattened properly.
    public static func buildExpression(_ cashFlows: [CashFlow]) -> [CashFlow] {
        cashFlows
    }

    /// Flattens arrays of cash flow arrays and sorts by period.
    ///
    /// Enables `for`...`in` loops within CashFlows blocks.
    /// Automatically sorts the combined result.
    public static func buildArray(_ cashFlows: [[CashFlow]]) -> [CashFlow] {
        cashFlows.flatMap { $0 }.sorted { $0.period < $1.period }
    }

    /// Handles optional cash flows.
    ///
    /// Returns the cash flows if present, or an empty array if nil.
    /// Enables `if let` and other optional patterns.
    public static func buildOptional(_ cashFlows: [CashFlow]?) -> [CashFlow] {
        cashFlows ?? []
    }

    /// Returns the first branch of an `if`/`else` expression.
    ///
    /// Called when the condition evaluates to true.
    public static func buildEither(first cashFlows: [CashFlow]) -> [CashFlow] {
        cashFlows
    }

    /// Returns the second branch of an `if`/`else` expression.
    ///
    /// Called when the condition evaluates to false.
    public static func buildEither(second cashFlows: [CashFlow]) -> [CashFlow] {
        cashFlows
    }
}

// MARK: - Top-Level Wrapper

/// Build an investment using the fluent API (matches documented API).
///
/// Example:
/// ```swift
/// let investment = buildInvestment {
///     InitialInvestment(100_000)
///     CashFlow(year: 1, amount: 30_000)
///     CashFlow(year: 2, amount: 35_000)
///     DiscountRate(0.10)
/// }
/// ```
public func buildInvestment(@InvestmentBuilder builder: () -> [InvestmentComponent]) -> Investment {
    Investment(builder: builder)
}

// MARK: - Component Constructors

/// Set the initial investment cost.
public func InitialCost(_ amount: Double) -> InvestmentComponent {
    .initialCost(amount)
}

/// Set the initial investment cost (alias for InitialCost, matches documented API).
public func InitialInvestment(_ amount: Double) -> InvestmentComponent {
    .initialCost(amount)
}

/// Define cash flows using the builder.
public func CashFlows(@CashFlowBuilder builder: () -> [CashFlow]) -> InvestmentComponent {
    .cashFlows(builder())
}

/// Set the discount rate for NPV calculation.
public func DiscountRate(_ rate: Double) -> InvestmentComponent {
    .discountRate(rate)
}

/// Set the investment name.
public func Name(_ name: String) -> InvestmentComponent {
    .name(name)
}

/// Set the investment description.
public func Description(_ description: String) -> InvestmentComponent {
    .description(description)
}

/// Set the investment category.
public func Category(_ category: String) -> InvestmentComponent {
    .category(category)
}

/// Define a categorized group of cash flows.
///
/// Example:
/// ```swift
/// let investment = buildInvestment {
///     InitialInvestment(250_000)
///
///     CashFlowCategory("Cost Savings") {
///         CashFlow(year: 1, amount: 50_000)
///         CashFlow(year: 2, amount: 60_000)
///     }
///
///     CashFlowCategory("Revenue Growth") {
///         CashFlow(year: 1, amount: 30_000)
///         CashFlow(year: 2, amount: 40_000)
///     }
///
///     DiscountRate(0.12)
/// }
/// ```
public func CashFlowCategory(_ categoryName: String, @CashFlowBuilder builder: () -> [CashFlow]) -> InvestmentComponent {
    .cashFlowCategory(categoryName, builder())
}

// MARK: - Cash Flow Constructors

/// Create a cash flow directly (convenience function matching documented API).
///
/// Note: Also works with the CashFlowBuilder for nested usage.
///
/// Example:
/// ```swift
/// buildInvestment {
///     InitialInvestment(100_000)
///
///     CashFlows {
///         Year(1) => 30_000  // Arrow syntax
///         Year(2) => 35_000
///     }
/// }
/// ```
extension CashFlowBuilder {
    /// Build expression for direct year/amount pairs (matches documented API).
    public static func buildExpression(year: Int, amount: Double) -> [CashFlow] {
        [CashFlow(period: year, amount: amount)]
    }
}

/// Create a cash flow for a specific year (arrow syntax).
public func Year(_ year: Int) -> CashFlowPeriod {
    CashFlowPeriod(period: year)
}

/// Helper struct for fluent cash flow creation.
public struct CashFlowPeriod {
    let period: Int

    /// Create a cash flow using arrow syntax: `Year(1) => 30_000`
    public static func => (period: CashFlowPeriod, amount: Double) -> CashFlow {
        CashFlow(period: period.period, amount: amount)
    }
}

// MARK: - Date-Based Cash Flows

/// Date-based cash flow for XNPV/XIRR calculations.
///
/// While ``CashFlow`` uses integer periods (years), DateBasedCashFlow uses
/// specific dates. This is more accurate for irregular cash flow timing and
/// is required for XNPV (Extended Net Present Value) and XIRR (Extended Internal
/// Rate of Return) calculations.
///
/// ## When to Use
/// - **DateBasedCashFlow**: Irregular timing, exact dates known, XNPV/XIRR needed
/// - **CashFlow**: Annual periods, regular timing, standard NPV/IRR sufficient
///
/// ## Usage Example
/// ```swift
/// let today = Date()
/// let calendar = Calendar.current
///
/// let initialInvestment = DateBasedCashFlow(
///     date: today,
///     amount: -100_000
/// )
///
/// let cashFlows = [
///     DateBasedCashFlow(
///         date: calendar.date(byAdding: .month, value: 6, to: today)!,
///         amount: 20_000
///     ),
///     DateBasedCashFlow(
///         date: calendar.date(byAdding: .year, value: 1, to: today)!,
///         amount: 35_000
///     ),
///     DateBasedCashFlow(
///         date: calendar.date(byAdding: .month, value: 18, to: today)!,
///         amount: 45_000
///     )
/// ]
///
/// let xnpv = BusinessMath.xnpv(
///     rate: 0.10,
///     cashFlows: [initialInvestment] + cashFlows
/// )
/// ```
///
/// ## SeeAlso
/// - ``CashFlow``
/// - ``xnpv(rate:dates:cashFlows:)``
/// - ``xirr(dates:cashFlows:guess:tolerance:maxIterations:)``
public struct DateBasedCashFlow: Sendable {
    /// The specific date when this cash flow occurs.
    ///
    /// Should be the actual transaction date, not an approximation.
    /// More accurate timing leads to more accurate XNPV/XIRR calculations.
    public let date: Date

    /// The amount of the cash flow.
    ///
    /// Positive for inflows, negative for outflows.
    /// The initial investment should typically be negative.
    public let amount: Double

    /// Creates a date-based cash flow.
    ///
    /// - Parameters:
    ///   - date: The exact date when the cash flow occurs
    ///   - amount: The cash flow amount (positive for inflows, negative for outflows)
    ///
    /// ## Usage Example
    /// ```swift
    /// let today = Date()
    ///
    /// // Initial investment (negative)
    /// let initial = DateBasedCashFlow(date: today, amount: -100_000)
    ///
    /// // Cash inflow 6 months later
    /// let sixMonths = Calendar.current.date(byAdding: .month, value: 6, to: today)!
    /// let cashInflow = DateBasedCashFlow(date: sixMonths, amount: 30_000)
    ///
    /// // Use with XNPV
    /// let allFlows = [initial, cashInflow]
    /// let npv = BusinessMath.xnpv(rate: 0.10, cashFlows: allFlows)
    /// ```
    public init(date: Date, amount: Double) {
        self.date = date
        self.amount = amount
    }
}

/// Convenience initializer for year-based cash flows (matches documented API).
///
/// Example:
/// ```swift
/// buildInvestment {
///     InitialInvestment(100_000)
///     CashFlows {
///         // All these syntaxes work:
///         Year(1) => 30_000
///         Year(2) => 35_000
///     }
///     DiscountRate(0.10)
/// }
/// ```
extension CashFlow {
    /// Create a cash flow for a specific year (convenience initializer).
    public init(year: Int, amount: Double) {
        self.init(period: year, amount: amount)
    }
}

// MARK: - Investment Comparison

extension Investment {
    /// Compare two investments based on NPV.
    public static func compareNPV(_ a: Investment, _ b: Investment) -> ComparisonResult {
        if a.npv > b.npv {
            return .orderedDescending
        } else if a.npv < b.npv {
            return .orderedAscending
        } else {
            return .orderedSame
        }
    }

    /// Compare two investments based on IRR.
    public static func compareIRR(_ a: Investment, _ b: Investment) -> ComparisonResult {
        guard let irrA = a.irr, let irrB = b.irr else {
            return .orderedSame
        }

        if irrA > irrB {
            return .orderedDescending
        } else if irrA < irrB {
            return .orderedAscending
        } else {
            return .orderedSame
        }
    }

    /// Compare two investments based on profitability index.
    public static func comparePI(_ a: Investment, _ b: Investment) -> ComparisonResult {
        if a.profitabilityIndex > b.profitabilityIndex {
            return .orderedDescending
        } else if a.profitabilityIndex < b.profitabilityIndex {
            return .orderedAscending
        } else {
            return .orderedSame
        }
    }
}

// MARK: - Investment Portfolio

/// A collection of investments for comparison and analysis.
///
/// Use InvestmentPortfolio to evaluate multiple investment opportunities,
/// rank them by various metrics (NPV, IRR, PI), and select the best options
/// subject to capital constraints.
///
/// ## Usage Example
/// ```swift
/// var portfolio = InvestmentPortfolio()
///
/// // Add multiple investments
/// portfolio.add(Investment {
///     Name("Project A")
///     InitialCost(100_000)
///     CashFlows {
///         Year(1) => 40_000
///         Year(2) => 50_000
///         Year(3) => 60_000
///     }
///     DiscountRate(0.10)
/// })
///
/// portfolio.add(Investment {
///     Name("Project B")
///     InitialCost(150_000)
///     CashFlows {
///         Year(1) => 60_000
///         Year(2) => 70_000
///         Year(3) => 80_000
///     }
///     DiscountRate(0.10)
/// })
///
/// // Rank by different metrics
/// let byNPV = portfolio.rankedByNPV()
/// let byIRR = portfolio.rankedByIRR()
/// let byPI = portfolio.rankedByPI()
///
/// // Filter by criteria
/// let highNPV = portfolio.filter(minNPV: 50_000)
/// let highIRR = portfolio.filter(minIRR: 0.15)
///
/// // Capital budgeting
/// print("Total NPV: \(portfolio.totalNPV)")
/// print("Total Investment Required: \(portfolio.totalInitialCost)")
/// ```
///
/// ## Capital Rationing
/// When capital is limited, rank by profitability index (PI) to maximize
/// NPV per dollar invested:
/// ```swift
/// let rankedByPI = portfolio.rankedByPI()
/// var budget = 200_000.0
/// var selectedInvestments: [Investment] = []
///
/// for investment in rankedByPI {
///     if budget >= investment.initialCost {
///         selectedInvestments.append(investment)
///         budget -= investment.initialCost
///     }
/// }
/// ```
///
/// ## SeeAlso
/// - ``Investment``
/// - ``Investment/npv``
/// - ``Investment/irr``
/// - ``Investment/profitabilityIndex``
public struct InvestmentPortfolio: Sendable {
    /// Array of investments in the portfolio.
    ///
    /// Can be mutated using ``add(_:)`` or directly modified.
    public var investments: [Investment]

    /// Creates an investment portfolio.
    ///
    /// - Parameter investments: Initial array of investments (default: empty)
    ///
    /// ## Usage Example
    /// ```swift
    /// // Empty portfolio
    /// var portfolio = InvestmentPortfolio()
    ///
    /// // Portfolio with initial investments
    /// let portfolio2 = InvestmentPortfolio(investments: [
    ///     projectA,
    ///     projectB,
    ///     projectC
    /// ])
    /// ```
    public init(investments: [Investment] = []) {
        self.investments = investments
    }

    /// Add an investment to the portfolio.
    public mutating func add(_ investment: Investment) {
        investments.append(investment)
    }

    /// Get investments ranked by NPV (highest first).
    public func rankedByNPV() -> [Investment] {
        investments.sorted { $0.npv > $1.npv }
    }

    /// Get investments ranked by IRR (highest first).
    public func rankedByIRR() -> [Investment] {
        investments.compactMap { inv -> (Investment, Double)? in
            guard let irr = inv.irr else { return nil }
            return (inv, irr)
        }
        .sorted { $0.1 > $1.1 }
        .map { $0.0 }
    }

    /// Get investments ranked by profitability index (highest first).
    public func rankedByPI() -> [Investment] {
        investments.sorted { $0.profitabilityIndex > $1.profitabilityIndex }
    }

    /// Total NPV of all investments.
    public var totalNPV: Double {
        investments.map { $0.npv }.reduce(0, +)
    }

    /// Total initial cost required.
    public var totalInitialCost: Double {
        investments.map { $0.initialCost }.reduce(0, +)
    }

    /// Filter investments by minimum NPV.
    public func filter(minNPV: Double) -> [Investment] {
        investments.filter { $0.npv >= minNPV }
    }

    /// Filter investments by minimum IRR.
    public func filter(minIRR: Double) -> [Investment] {
        investments.filter { inv in
            guard let irr = inv.irr else { return false }
            return irr >= minIRR
        }
    }
}

// MARK: - Convenience Extensions

extension Investment {
    /// Create a simple investment with equal annual cash flows.
    ///
    /// Example:
    /// ```swift
    /// let investment = Investment.simple(
    ///     initialCost: 100_000,
    ///     annualCashFlow: 25_000,
    ///     years: 5,
    ///     discountRate: 0.10
    /// )
    /// ```
    public static func simple(
        initialCost: Double,
        annualCashFlow: Double,
        years: Int,
        discountRate: Double
    ) -> Investment {
        let flows = (1...years).map { year in
            CashFlow(period: year, amount: annualCashFlow)
        }

        return Investment {
            InitialCost(initialCost)
            CashFlows { flows }
            DiscountRate(discountRate)
        }
    }

    /// Create an investment with growing cash flows.
    ///
    /// Example:
    /// ```swift
    /// let investment = Investment.growing(
    ///     initialCost: 100_000,
    ///     firstYearCashFlow: 20_000,
    ///     growthRate: 0.10,
    ///     years: 5,
    ///     discountRate: 0.10
    /// )
    /// ```
    public static func growing(
        initialCost: Double,
        firstYearCashFlow: Double,
        growthRate: Double,
        years: Int,
        discountRate: Double
    ) -> Investment {
        let flows = (1...years).map { year in
            let cashFlow = firstYearCashFlow * pow(1 + growthRate, Double(year - 1))
            return CashFlow(period: year, amount: cashFlow)
        }

        return Investment {
            InitialCost(initialCost)
            CashFlows { flows }
            DiscountRate(discountRate)
        }
    }
}

// MARK: - CustomStringConvertible

extension Investment: CustomStringConvertible {
    /// Human-readable description of the investment with key metrics.
    ///
    /// Provides a formatted summary including:
    /// - Investment name (if provided)
    /// - Initial cost
    /// - Discount rate
    /// - NPV (Net Present Value)
    /// - IRR (Internal Rate of Return, if calculable)
    /// - Profitability Index
    /// - Payback Period (if investment pays back)
    /// - Discounted Payback Period (if investment pays back on discounted basis)
    ///
    /// ## Usage Example
    /// ```swift
    /// let investment = Investment {
    ///     Name("Equipment Upgrade")
    ///     InitialCost(100_000)
    ///     CashFlows {
    ///         Year(1) => 30_000
    ///         Year(2) => 35_000
    ///         Year(3) => 40_000
    ///         Year(4) => 45_000
    ///     }
    ///     DiscountRate(0.10)
    /// }
    ///
    /// print(investment)
    /// // Output:
    /// // Investment 'Equipment Upgrade':
    /// //   Initial Cost: $100,000.00
    /// //   Discount Rate: 10.00%
    /// //   NPV: $17,234.56
    /// //   IRR: 23.45%
    /// //   Profitability Index: 1.17
    /// //   Payback Period: 2.86 years
    /// //   Discounted Payback: 3.12 years
    /// ```
    ///
    /// ## Note
    /// This property is automatically synthesized by conformance to
    /// `CustomStringConvertible`, enabling readable `print()` output and
    /// string interpolation.
    public var description: String {
        var result = "Investment"
        if let name = name {
            result += " '\(name)'"
        }
        result += ":\n"
		result += "  Initial Cost: \(initialCost.currency())\n"
		result += "  Discount Rate: \(discountRate.percent())\n"
		result += "  NPV: \(npv.currency())\n"

        if let irr = irr {
			result += "  IRR: \(irr.percent())\n"
        }

		result += "  Profitability Index: \(profitabilityIndex.number())\n"

        if let payback = paybackPeriod {
			result += "  Payback Period: \(payback.number()) years\n"
        }

        if let discountedPayback = discountedPaybackPeriod {
			result += "  Discounted Payback: \(discountedPayback.number()) years\n"
        }

        return result
    }
}

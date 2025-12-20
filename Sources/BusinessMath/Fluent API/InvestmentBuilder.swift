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
public struct CashFlow: Sendable {
    public let period: Int
    public let amount: Double

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
@resultBuilder
public struct InvestmentBuilder {
    public static func buildBlock(_ components: [InvestmentComponent]...) -> [InvestmentComponent] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ component: InvestmentComponent) -> [InvestmentComponent] {
        [component]
    }

    public static func buildArray(_ components: [[InvestmentComponent]]) -> [InvestmentComponent] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ components: [InvestmentComponent]?) -> [InvestmentComponent] {
        components ?? []
    }

    public static func buildEither(first components: [InvestmentComponent]) -> [InvestmentComponent] {
        components
    }

    public static func buildEither(second components: [InvestmentComponent]) -> [InvestmentComponent] {
        components
    }
}

// MARK: - Cash Flow Builder

/// Result builder for constructing cash flows.
@resultBuilder
public struct CashFlowBuilder {
    public static func buildBlock(_ cashFlows: [CashFlow]...) -> [CashFlow] {
        cashFlows.flatMap { $0 }.sorted { $0.period < $1.period }
    }

    public static func buildExpression(_ cashFlow: CashFlow) -> [CashFlow] {
        [cashFlow]
    }

    public static func buildExpression(_ cashFlows: [CashFlow]) -> [CashFlow] {
        cashFlows
    }

    public static func buildArray(_ cashFlows: [[CashFlow]]) -> [CashFlow] {
        cashFlows.flatMap { $0 }.sorted { $0.period < $1.period }
    }

    public static func buildOptional(_ cashFlows: [CashFlow]?) -> [CashFlow] {
        cashFlows ?? []
    }

    public static func buildEither(first cashFlows: [CashFlow]) -> [CashFlow] {
        cashFlows
    }

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
/// Example:
/// ```swift
/// let today = Date()
/// let oneYear = Calendar.current.date(byAdding: .year, value: 1, to: today)!
///
/// let dateFlow = DateBasedCashFlow(date: oneYear, amount: 30_000)
/// ```
public struct DateBasedCashFlow: Sendable {
    public let date: Date
    public let amount: Double

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
public struct InvestmentPortfolio: Sendable {
    public var investments: [Investment]

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
            result += "  IRR: \(String(format: "%.2f%%", irr * 100))\n"
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

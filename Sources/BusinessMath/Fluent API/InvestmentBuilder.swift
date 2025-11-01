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

    // MARK: - Initialization

    /// Create an investment using the builder DSL.
    public init(@InvestmentBuilder builder: () -> [InvestmentComponent]) {
        let components = builder()

        var initialCost: Double = 0
        var cashFlows: [CashFlow] = []
        var discountRate: Double = 0.10 // Default 10%
        var name: String?
        var description: String?

        for component in components {
            switch component {
            case .initialCost(let cost):
                initialCost = cost
            case .cashFlows(let flows):
                cashFlows = flows
            case .discountRate(let rate):
                discountRate = rate
            case .name(let n):
                name = n
            case .description(let d):
                description = d
            }
        }

        self.initialCost = initialCost
        self.cashFlows = cashFlows
        self.discountRate = discountRate
        self.name = name
        self.investmentDescription = description
    }

    // MARK: - Calculated Metrics

    /// Net Present Value (NPV) - automatically calculated.
    public var npv: Double {
        let allCashFlows = [-initialCost] + cashFlows.map { $0.amount }
        // Use the global npv function
        var presentValue = 0.0
        for (index, cashFlow) in allCashFlows.enumerated() {
            presentValue += cashFlow / pow(1 + discountRate, Double(index))
        }
        return presentValue
    }

    /// Internal Rate of Return (IRR) - automatically calculated.
    public var irr: Double? {
        let allCashFlows = [-initialCost] + cashFlows.map { $0.amount }
        // Simple IRR calculation using Newton-Raphson
        var rate = 0.1 // Initial guess
        for _ in 0..<100 {
            var npvAtRate = 0.0
            var derivative = 0.0
            for (index, cashFlow) in allCashFlows.enumerated() {
                let period = Double(index)
                npvAtRate += cashFlow / pow(1 + rate, period)
                if index > 0 {
                    derivative -= period * cashFlow / pow(1 + rate, period + 1)
                }
            }
            if abs(npvAtRate) < 0.0001 {
                return rate
            }
            rate = rate - npvAtRate / derivative
        }
        return nil // Did not converge
    }

    /// Profitability Index - automatically calculated.
    public var profitabilityIndex: Double {
        let pvOfCashFlows = cashFlows.enumerated().reduce(0.0) { sum, element in
            let (index, cashFlow) = element
            let period = Double(index + 1)
            return sum + cashFlow.amount / pow(1 + discountRate, period)
        }
        return pvOfCashFlows / initialCost
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

// MARK: - Component Constructors

/// Set the initial investment cost.
public func InitialCost(_ amount: Double) -> InvestmentComponent {
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

// MARK: - Cash Flow Constructors

/// Create a cash flow for a specific year.
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
        result += "  Initial Cost: $\(String(format: "%.2f", initialCost))\n"
        result += "  Discount Rate: \(String(format: "%.2f%%", discountRate * 100))\n"
        result += "  NPV: $\(String(format: "%.2f", npv))\n"

        if let irr = irr {
            result += "  IRR: \(String(format: "%.2f%%", irr * 100))\n"
        }

        result += "  Profitability Index: \(String(format: "%.2f", profitabilityIndex))\n"

        if let payback = paybackPeriod {
            result += "  Payback Period: \(String(format: "%.2f", payback)) years\n"
        }

        if let discountedPayback = discountedPaybackPeriod {
            result += "  Discounted Payback: \(String(format: "%.2f", discountedPayback)) years\n"
        }

        return result
    }
}

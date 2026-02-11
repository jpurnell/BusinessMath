//
//  CalculationTrace.swift
//  BusinessMath
//
//  Created on November 1, 2025.
//

import Foundation

// MARK: - Trace Category

/// Category of a calculation trace step
public enum TraceCategory: Sendable {
    case revenue
    case costs
    case profit
}

// MARK: - Trace Step

/// A single step in a calculation trace
public struct TraceStep: Sendable {
    /// The category of this calculation step
    public let category: TraceCategory

    /// Human-readable description of this step
    public let description: String

    /// The calculated value for this step
    public let value: Double?

    /// Timestamp when this step was recorded
    public let timestamp: Date

    /// Creates a trace step.
    ///
    /// - Parameters:
    ///   - category: The category of calculation (revenue, costs, or profit).
    ///   - description: Human-readable description of this calculation step.
    ///   - value: The calculated value, or nil if not applicable.
    public init(category: TraceCategory, description: String, value: Double?) {
        self.category = category
        self.description = description
        self.value = value
        self.timestamp = Date()
    }
}

// MARK: - Calculation Trace

/// Developer tool for tracing calculation steps in financial models.
///
/// CalculationTrace wraps a FinancialModel and records detailed information
/// about each calculation step, making it easier to understand, debug, and
/// document how financial metrics are derived.
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
/// let trace = CalculationTrace(model: model)
/// let profit = trace.calculateProfit()
/// print(trace.formatTrace())
/// ```
public final class CalculationTrace: Sendable {
    // MARK: - Properties

    /// The financial model being traced
    public let model: FinancialModel

    /// Recorded calculation steps
    private let _steps: ThreadSafeArray<TraceStep>

    /// Access to recorded calculation steps
    public var steps: [TraceStep] {
        _steps.array
    }

    // MARK: - Initialization

    /// Creates a calculation trace for a financial model.
    ///
    /// The trace starts empty. Call calculation methods like ``calculateProfit()`` to
    /// populate the trace with calculation steps.
    ///
    /// - Parameter model: The financial model to trace.
    public init(model: FinancialModel) {
        self.model = model
        self._steps = ThreadSafeArray<TraceStep>()
    }

    // MARK: - Calculation Methods with Tracing

    /// Calculate total revenue with tracing
    public func calculateRevenue() -> Double {
        var total = 0.0

        for component in model.revenueComponents {
            let amount = component.amount
            total += amount

            _steps.append(TraceStep(
                category: .revenue,
                description: "Revenue: \(component.name) = $\(amount.currency())",
                value: amount
            ))
        }

        _steps.append(TraceStep(
            category: .revenue,
            description: "Total Revenue = $\(total.currency())",
            value: total
        ))

        return total
    }

    /// Calculate total costs with tracing
    public func calculateCosts(revenue: Double) -> Double {
        var total = 0.0

        for component in model.costComponents {
            let amount = component.calculate(revenue: revenue)
            total += amount

            let typeDescription: String
            switch component.type {
            case .fixed:
                typeDescription = "Fixed"
            case .variable(let percentage):
                typeDescription = "Variable (\(percentage.percent()) of revenue)"
            }

            _steps.append(TraceStep(
                category: .costs,
                description: "Cost (\(typeDescription)): \(component.name) = $\(amount.currency())",
                value: amount
            ))
        }

        _steps.append(TraceStep(
            category: .costs,
            description: "Total Costs = $\(total.currency())",
            value: total
        ))

        return total
    }

    /// Calculate profit with tracing
    public func calculateProfit() -> Double {
        let revenue = calculateRevenue()
        let costs = calculateCosts(revenue: revenue)
        let profit = revenue - costs

        _steps.append(TraceStep(
            category: .profit,
            description: "Profit = Revenue (\(revenue.currency())) - Costs (\(costs.currency())) = \(profit.currency())",
            value: profit
        ))

        return profit
    }

    // MARK: - Trace Management

    /// Clear all recorded trace steps
    public func clear() {
        _steps.removeAll()
    }

    /// Generate formatted trace output
    public func formatTrace() -> String {
        var output = "Calculation Trace\n"
        output += "=================\n\n"

        let revenueSteps = steps.filter { $0.category == .revenue }
        let costSteps = steps.filter { $0.category == .costs }
        let profitSteps = steps.filter { $0.category == .profit }

        if !revenueSteps.isEmpty {
            output += "Revenue:\n"
            output += "--------\n"
            for step in revenueSteps {
                output += "  \(step.description)\n"
            }
            output += "\n"
        }

        if !costSteps.isEmpty {
            output += "Costs:\n"
            output += "------\n"
            for step in costSteps {
                output += "  \(step.description)\n"
            }
            output += "\n"
        }

        if !profitSteps.isEmpty {
            output += "Profit:\n"
            output += "-------\n"
            for step in profitSteps {
                output += "  \(step.description)\n"
            }
            output += "\n"
        }

        return output
    }

}

// MARK: - Thread-Safe Array

/// Thread-safe wrapper for array operations
private final class ThreadSafeArray<Element: Sendable>: @unchecked Sendable {
    private var _array: [Element] = []
    private let lock = NSLock()

    var array: [Element] {
        lock.lock()
        defer { lock.unlock() }
        return _array
    }

    func append(_ element: Element) {
        lock.lock()
        defer { lock.unlock() }
        _array.append(element)
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        _array.removeAll()
    }
}

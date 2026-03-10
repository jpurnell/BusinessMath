//
//  TerminalValue.swift
//  BusinessMathDSL
//
//  Created by Justin Purnell on 2025-12-30.
//

import Foundation

// MARK: - Terminal Value Methods

/// Perpetual growth method for terminal value calculation.
///
/// TV = FCF_final × (1 + g) / (WACC - g)
public struct PerpetualGrowth {
    /// The perpetual growth rate as a decimal.
    public let rate: Double

    /// Creates a perpetual growth configuration.
    ///
    /// - Parameter rate: The growth rate (must be between 0 and 1).
    public init(rate: Double) {
        guard rate >= 0 && rate < 1.0 else {
            fatalError("Perpetual growth rate must be between 0 and 1: \(rate)")
        }
        self.rate = rate
    }
}

/// Exit multiple method for terminal value calculation.
///
/// TV = Final EBITDA × Multiple
public struct ExitMultiple {
    /// The EV/EBITDA exit multiple.
    public let evEbitda: Double

    /// Creates an exit multiple configuration.
    ///
    /// - Parameter evEbitda: The EV/EBITDA multiple (must be positive).
    public init(evEbitda: Double) {
        guard evEbitda > 0 else {
            fatalError("EV/EBITDA multiple must be positive: \(evEbitda)")
        }
        self.evEbitda = evEbitda
    }
}

// MARK: - Terminal Value Model

/// Terminal value calculation for DCF valuation
public struct TerminalValue {
    public let method: TerminalValueMethod

    internal init(method: TerminalValueMethod) {
        self.method = method
    }

    /// Create terminal value using result builder
    public init(@TerminalValueBuilder content: () -> TerminalValue) {
        self = content()
    }

    /// Calculate terminal value using perpetual growth method
    /// - Parameters:
    ///   - finalFCF: Free cash flow in final forecast year
    ///   - wacc: Weighted average cost of capital
    /// - Returns: Terminal value
    public func calculate(finalFCF: Double, wacc: Double) -> Double {
        guard case .perpetualGrowth(let growth) = method else {
            fatalError("Perpetual growth method required for this calculation")
        }

        guard wacc > growth.rate else {
            fatalError("WACC must be greater than growth rate: WACC=\(wacc), g=\(growth.rate)")
        }

        return finalFCF * (1.0 + growth.rate) / (wacc - growth.rate)
    }

    /// Calculate terminal value using exit multiple method
    /// - Parameter finalEBITDA: EBITDA in final forecast year
    /// - Returns: Terminal value
    public func calculate(finalEBITDA: Double) -> Double {
        guard case .exitMultiple(let multiple) = method else {
            fatalError("Exit multiple method required for this calculation")
        }

        return finalEBITDA * multiple.evEbitda
    }
}

// MARK: - Terminal Value Result Builder

/// Result builder for constructing `TerminalValue` instances declaratively.
@resultBuilder
public struct TerminalValueBuilder {
    /// Builds a terminal value from the provided method component.
    ///
    /// - Parameter component: The perpetual growth or exit multiple component.
    /// - Returns: A configured `TerminalValue`.
    public static func buildBlock(_ component: TerminalValueMethodComponent) -> TerminalValue {
        switch component {
        case .perpetualGrowth(let growth):
            return TerminalValue(method: .perpetualGrowth(growth))
        case .exitMultiple(let multiple):
            return TerminalValue(method: .exitMultiple(multiple))
        }
    }

    /// Converts a `PerpetualGrowth` to a terminal value method component.
    public static func buildExpression(_ expression: PerpetualGrowth) -> TerminalValueMethodComponent {
        .perpetualGrowth(expression)
    }

    /// Converts an `ExitMultiple` to a terminal value method component.
    public static func buildExpression(_ expression: ExitMultiple) -> TerminalValueMethodComponent {
        .exitMultiple(expression)
    }
}

// MARK: - Terminal Value Method

/// The method used to calculate terminal value.
public enum TerminalValueMethod {
    case perpetualGrowth(PerpetualGrowth)
    case exitMultiple(ExitMultiple)
}

/// Represents a terminal value method component in the builder.
public enum TerminalValueMethodComponent {
    case perpetualGrowth(PerpetualGrowth)
    case exitMultiple(ExitMultiple)
}

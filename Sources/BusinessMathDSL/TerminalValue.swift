//
//  TerminalValue.swift
//  BusinessMathDSL
//
//  Created by Justin Purnell on 2025-12-30.
//

import Foundation

// MARK: - Terminal Value Methods

/// Perpetual growth method for terminal value calculation
/// TV = FCF_final * (1 + g) / (WACC - g)
public struct PerpetualGrowth {
    public let rate: Double

    public init(rate: Double) {
        guard rate >= 0 && rate < 1.0 else {
            fatalError("Perpetual growth rate must be between 0 and 1: \(rate)")
        }
        self.rate = rate
    }
}

/// Exit multiple method for terminal value calculation
/// TV = Final EBITDA * Multiple
public struct ExitMultiple {
    public let evEbitda: Double

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

@resultBuilder
public struct TerminalValueBuilder {
    public static func buildBlock(_ component: TerminalValueMethodComponent) -> TerminalValue {
        switch component {
        case .perpetualGrowth(let growth):
            return TerminalValue(method: .perpetualGrowth(growth))
        case .exitMultiple(let multiple):
            return TerminalValue(method: .exitMultiple(multiple))
        }
    }

    public static func buildExpression(_ expression: PerpetualGrowth) -> TerminalValueMethodComponent {
        .perpetualGrowth(expression)
    }

    public static func buildExpression(_ expression: ExitMultiple) -> TerminalValueMethodComponent {
        .exitMultiple(expression)
    }
}

// MARK: - Terminal Value Method

public enum TerminalValueMethod {
    case perpetualGrowth(PerpetualGrowth)
    case exitMultiple(ExitMultiple)
}

public enum TerminalValueMethodComponent {
    case perpetualGrowth(PerpetualGrowth)
    case exitMultiple(ExitMultiple)
}

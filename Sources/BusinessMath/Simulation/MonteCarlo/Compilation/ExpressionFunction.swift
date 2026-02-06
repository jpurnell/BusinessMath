//
//  ExpressionFunction.swift
//  BusinessMath
//
//  Reusable expression-based functions for GPU compilation
//
//  This file enables users to define custom functions using the ExpressionBuilder
//  DSL that can be reused across multiple models and still compile to GPU bytecode.
//

import Foundation

/// A reusable function defined using the ExpressionBuilder DSL
///
/// ExpressionFunction allows you to define custom mathematical functions
/// that can be compiled to GPU bytecode and reused across multiple models.
///
/// ## Usage
///
/// ```swift
/// // Define a reusable tax calculation function
/// let calculateTax = ExpressionFunction(inputs: 2) { builder in
///     let income = builder[0]
///     let rate = builder[1]
///     return income * rate
/// }
///
/// // Use in a model
/// let model = MonteCarloExpressionModel { builder in
///     let revenue = builder[0]
///     let taxRate = builder[1]
///
///     // Call the function
///     let taxes = calculateTax.call(revenue, taxRate)
///
///     return revenue - taxes
/// }
/// ```
///
/// ## Financial Function Library
///
/// ```swift
/// // Black-Scholes drift term
/// let bsDrift = ExpressionFunction(inputs: 3) { builder in
///     let riskFreeRate = builder[0]
///     let volatility = builder[1]
///     let time = builder[2]
///
///     return (riskFreeRate - volatility * volatility * 0.5) * time
/// }
///
/// // Black-Scholes diffusion term
/// let bsDiffusion = ExpressionFunction(inputs: 3) { builder in
///     let volatility = builder[0]
///     let time = builder[1]
///     let randomNormal = builder[2]
///
///     return volatility * time.sqrt() * randomNormal
/// }
///
/// // Use in option pricing model
/// let optionModel = MonteCarloExpressionModel { builder in
///     let spot = builder[0]
///     let strike = builder[1]
///     let r = builder[2]
///     let vol = builder[3]
///     let t = builder[4]
///     let z = builder[5]
///
///     let drift = bsDrift.call(r, vol, t)
///     let diffusion = bsDiffusion.call(vol, t, z)
///     let finalPrice = spot * (drift + diffusion).exp()
///
///     return (finalPrice - strike).max(0.0)
/// }
/// ```
public struct ExpressionFunction: Sendable {

    /// The number of inputs this function expects
    public let inputCount: Int

    /// The compiled expression for this function
    private let expression: Expression

    /// Create a new expression function
    ///
    /// - Parameters:
    ///   - inputs: Number of input parameters
    ///   - builder: Closure that builds the function expression
    ///
    /// ## Example - Tax Calculation
    ///
    /// ```swift
    /// let calculateTax = ExpressionFunction(inputs: 2) { builder in
    ///     let income = builder[0]
    ///     let rate = builder[1]
    ///     return income * rate
    /// }
    /// ```
    public init(inputs: Int, builder: (ExpressionBuilder) -> ExpressionProxy) {
        self.inputCount = inputs
        let exprBuilder = ExpressionBuilder()
        let proxy = builder(exprBuilder)
        self.expression = proxy.expression
    }

    /// Call this function with the given arguments
    ///
    /// Returns an ExpressionProxy that represents the function call.
    /// The arguments are substituted into the function's expression tree.
    ///
    /// - Parameter args: Variable number of ExpressionProxy arguments
    /// - Returns: ExpressionProxy representing the function result
    ///
    /// ## Example
    ///
    /// ```swift
    /// let tax = calculateTax.call(revenue, taxRate)
    /// ```
    public func call(_ args: ExpressionProxy...) -> ExpressionProxy {
        guard args.count == inputCount else {
            fatalError("ExpressionFunction expects \(inputCount) arguments, got \(args.count)")
        }

        // Substitute the arguments into the expression
        let substituted = substitute(expression: expression, arguments: args.map(\.expression))
        return ExpressionProxy(substituted)
    }

    /// Substitute arguments into an expression
    ///
    /// Recursively walks the expression tree, replacing input references
    /// with the provided argument expressions.
    private func substitute(expression: Expression, arguments: [Expression]) -> Expression {
        switch expression {
        case .input(let index):
            guard index >= 0 && index < arguments.count else {
                fatalError("Invalid input index \(index)")
            }
            return arguments[index]

        case .constant:
            return expression

        case .unary(let op, let operand):
            return .unary(op, substitute(expression: operand, arguments: arguments))

        case .binary(let op, let lhs, let rhs):
            return .binary(
                op,
                substitute(expression: lhs, arguments: arguments),
                substitute(expression: rhs, arguments: arguments)
            )

        case .conditional(let condition, let trueValue, let falseValue):
            return .conditional(
                substitute(expression: condition, arguments: arguments),
                substitute(expression: trueValue, arguments: arguments),
                substitute(expression: falseValue, arguments: arguments)
            )
        }
    }
}

// MARK: - Standard Financial Function Library

/// Pre-built expression functions for common financial calculations
public enum FinancialFunctions {

    /// Calculate percentage change: (new - old) / old
    ///
    /// ## Example
    /// ```swift
    /// let model = MonteCarloExpressionModel { builder in
    ///     let oldPrice = builder[0]
    ///     let newPrice = builder[1]
    ///     let percentChange = FinancialFunctions.percentChange.call(oldPrice, newPrice)
    ///     return percentChange
    /// }
    /// ```
    public static let percentChange = ExpressionFunction(inputs: 2) { builder in
        let oldValue = builder[0]
        let newValue = builder[1]
        return (newValue - oldValue) / oldValue
    }

    /// Calculate compound growth: principal * (1 + rate)^periods
    ///
    /// ## Example
    /// ```swift
    /// let model = MonteCarloExpressionModel { builder in
    ///     let principal = builder[0]
    ///     let rate = builder[1]
    ///     let years = builder[2]
    ///     let finalValue = FinancialFunctions.compoundGrowth.call(principal, rate, years)
    ///     return finalValue
    /// }
    /// ```
    public static let compoundGrowth = ExpressionFunction(inputs: 3) { builder in
        let principal = builder[0]
        let rate = builder[1]
        let periods = builder[2]
        return principal * (1.0 + rate).power(periods)
    }

    /// Calculate present value: futureValue / (1 + rate)^periods
    ///
    /// ## Example
    /// ```swift
    /// let model = MonteCarloExpressionModel { builder in
    ///     let futureValue = builder[0]
    ///     let discountRate = builder[1]
    ///     let years = builder[2]
    ///     let pv = FinancialFunctions.presentValue.call(futureValue, discountRate, years)
    ///     return pv
    /// }
    /// ```
    public static let presentValue = ExpressionFunction(inputs: 3) { builder in
        let futureValue = builder[0]
        let rate = builder[1]
        let periods = builder[2]
        return futureValue / (1.0 + rate).power(periods)
    }

    /// Calculate after-tax value: amount * (1 - taxRate)
    ///
    /// ## Example
    /// ```swift
    /// let model = MonteCarloExpressionModel { builder in
    ///     let profit = builder[0]
    ///     let taxRate = builder[1]
    ///     let afterTax = FinancialFunctions.afterTax.call(profit, taxRate)
    ///     return afterTax
    /// }
    /// ```
    public static let afterTax = ExpressionFunction(inputs: 2) { builder in
        let amount = builder[0]
        let taxRate = builder[1]
        return amount * (1.0 - taxRate)
    }

    /// Black-Scholes drift term: (r - σ²/2) * t
    ///
    /// ## Example - Option Pricing
    /// ```swift
    /// let optionModel = MonteCarloExpressionModel { builder in
    ///     let spot = builder[0]
    ///     let r = builder[1]
    ///     let vol = builder[2]
    ///     let t = builder[3]
    ///     let z = builder[4]
    ///
    ///     let drift = FinancialFunctions.blackScholesDrift.call(r, vol, t)
    ///     let diffusion = vol * t.sqrt() * z
    ///     let finalPrice = spot * (drift + diffusion).exp()
    ///
    ///     return finalPrice
    /// }
    /// ```
    public static let blackScholesDrift = ExpressionFunction(inputs: 3) { builder in
        let riskFreeRate = builder[0]
        let volatility = builder[1]
        let time = builder[2]
        return (riskFreeRate - volatility * volatility * 0.5) * time
    }

    /// Black-Scholes diffusion term: σ * √t * Z
    ///
    /// ## Example
    /// ```swift
    /// let diffusion = FinancialFunctions.blackScholesDiffusion.call(vol, time, randomNormal)
    /// ```
    public static let blackScholesDiffusion = ExpressionFunction(inputs: 3) { builder in
        let volatility = builder[0]
        let time = builder[1]
        let randomNormal = builder[2]
        return volatility * time.sqrt() * randomNormal
    }

    /// Calculate Sharpe ratio: (return - riskFree) / volatility
    ///
    /// ## Example
    /// ```swift
    /// let model = MonteCarloExpressionModel { builder in
    ///     let portfolioReturn = builder[0]
    ///     let riskFreeRate = builder[1]
    ///     let volatility = builder[2]
    ///     let sharpe = FinancialFunctions.sharpeRatio.call(portfolioReturn, riskFreeRate, volatility)
    ///     return sharpe
    /// }
    /// ```
    public static let sharpeRatio = ExpressionFunction(inputs: 3) { builder in
        let portfolioReturn = builder[0]
        let riskFreeRate = builder[1]
        let volatility = builder[2]
        return (portfolioReturn - riskFreeRate) / volatility
    }

    /// Calculate Value at Risk (simplified): mean - z * stdDev
    ///
    /// ## Example
    /// ```swift
    /// let model = MonteCarloExpressionModel { builder in
    ///     let mean = builder[0]
    ///     let stdDev = builder[1]
    ///     let confidenceZ = builder[2]  // 1.645 for 95%
    ///     let var95 = FinancialFunctions.valueAtRisk.call(mean, stdDev, confidenceZ)
    ///     return var95
    /// }
    /// ```
    public static let valueAtRisk = ExpressionFunction(inputs: 3) { builder in
        let mean = builder[0]
        let stdDev = builder[1]
        let zScore = builder[2]
        return mean - zScore * stdDev
    }
}

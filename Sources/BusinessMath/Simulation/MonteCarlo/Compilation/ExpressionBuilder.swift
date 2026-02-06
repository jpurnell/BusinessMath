//
//  ExpressionBuilder.swift
//  BusinessMath
//
//  Fluent API for Building GPU-Compilable Expressions
//
//  This file provides a declarative DSL for constructing mathematical expressions
//  that can be compiled to GPU bytecode. Instead of using opaque closures, users
//  can write natural Swift code that builds an expression tree.
//

import Foundation

/// Fluent API for building GPU-compatible mathematical expressions
///
/// ExpressionBuilder provides a natural Swift syntax for creating expression trees
/// that can be compiled to GPU bytecode. It uses operator overloading to make the
/// syntax identical to regular arithmetic while building a compile-time AST.
///
/// ## Usage
///
/// ```swift
/// let builder = ExpressionBuilder()
/// let profit = builder[0] * builder[1] - builder[2]
/// // Creates: Expression.binary(.subtract,
/// //            Expression.binary(.multiply, .input(0), .input(1)),
/// //            .input(2))
/// ```
///
/// ## Monte Carlo Integration
///
/// ```swift
/// var simulation = MonteCarloSimulation(iterations: 100_000) { builder in
///     let revenue = builder[0]
///     let price = builder[1]
///     let costs = builder[2]
///     return revenue * price - costs
/// }
/// // This expression will be compiled to GPU bytecode automatically
/// ```
///
/// ## Supported Operations
///
/// - Arithmetic: `+`, `-`, `*`, `/`
/// - Negation: `-expr`
/// - Constants: Mix Double literals with expressions
/// - Parentheses: Natural precedence rules apply
///
/// ## Thread Safety
///
/// ExpressionBuilder is `Sendable` and stateless, making it safe to use in
/// concurrent Monte Carlo simulations.
public struct ExpressionBuilder: Sendable {

    /// Create a new expression builder
    public init() {}

    /// Access an input variable by index
    ///
    /// - Parameter index: Zero-based index of the input variable
    /// - Returns: An expression proxy wrapping the input reference
    ///
    /// ## Example
    ///
    /// ```swift
    /// let builder = ExpressionBuilder()
    /// let revenue = builder[0]  // First input variable
    /// let costs = builder[1]    // Second input variable
    /// let profit = revenue - costs
    /// ```
    public subscript(index: Int) -> ExpressionProxy {
        return ExpressionProxy(.input(index))
    }
}

// MARK: - Expression Proxy

/// Proxy type that enables operator overloading for expression building
///
/// ExpressionProxy wraps an Expression and provides operator overloads that
/// construct new Expression nodes. This allows natural Swift syntax like
/// `a + b * c` to build an expression tree.
///
/// Users typically don't interact with ExpressionProxy directly - it's returned
/// by ExpressionBuilder subscript and passed through operator chains.
public struct ExpressionProxy: Sendable {

    /// The underlying expression tree
    internal let expression: Expression

    /// Create a proxy wrapping an expression
    internal init(_ expression: Expression) {
        self.expression = expression
    }
}

// MARK: - Arithmetic Operators

extension ExpressionProxy {

    // MARK: Addition

    /// Add two expressions: `a + b`
    public static func + (lhs: ExpressionProxy, rhs: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.add, lhs.expression, rhs.expression))
    }

    /// Add expression and constant: `a + 5.0`
    public static func + (lhs: ExpressionProxy, rhs: Double) -> ExpressionProxy {
        return ExpressionProxy(.binary(.add, lhs.expression, .constant(rhs)))
    }

    /// Add constant and expression: `5.0 + a`
    public static func + (lhs: Double, rhs: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.add, .constant(lhs), rhs.expression))
    }

    // MARK: Subtraction

    /// Subtract two expressions: `a - b`
    public static func - (lhs: ExpressionProxy, rhs: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.subtract, lhs.expression, rhs.expression))
    }

    /// Subtract constant from expression: `a - 5.0`
    public static func - (lhs: ExpressionProxy, rhs: Double) -> ExpressionProxy {
        return ExpressionProxy(.binary(.subtract, lhs.expression, .constant(rhs)))
    }

    /// Subtract expression from constant: `5.0 - a`
    public static func - (lhs: Double, rhs: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.subtract, .constant(lhs), rhs.expression))
    }

    // MARK: Multiplication

    /// Multiply two expressions: `a * b`
    public static func * (lhs: ExpressionProxy, rhs: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.multiply, lhs.expression, rhs.expression))
    }

    /// Multiply expression by constant: `a * 2.0`
    public static func * (lhs: ExpressionProxy, rhs: Double) -> ExpressionProxy {
        return ExpressionProxy(.binary(.multiply, lhs.expression, .constant(rhs)))
    }

    /// Multiply constant by expression: `2.0 * a`
    public static func * (lhs: Double, rhs: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.multiply, .constant(lhs), rhs.expression))
    }

    // MARK: Division

    /// Divide two expressions: `a / b`
    public static func / (lhs: ExpressionProxy, rhs: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.divide, lhs.expression, rhs.expression))
    }

    /// Divide expression by constant: `a / 2.0`
    public static func / (lhs: ExpressionProxy, rhs: Double) -> ExpressionProxy {
        return ExpressionProxy(.binary(.divide, lhs.expression, .constant(rhs)))
    }

    /// Divide constant by expression: `10.0 / a`
    public static func / (lhs: Double, rhs: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.divide, .constant(lhs), rhs.expression))
    }

    // MARK: Negation

    /// Negate an expression: `-a`
    public static prefix func - (operand: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.unary(.negate, operand.expression))
    }
}

// MARK: - Mathematical Functions

extension ExpressionProxy {

    /// Square root: `sqrt(a)`
    ///
    /// ## Example
    /// ```swift
    /// let builder = ExpressionBuilder()
    /// let variance = builder[0]
    /// let stdDev = variance.sqrt()
    /// ```
    public func sqrt() -> ExpressionProxy {
        return ExpressionProxy(.unary(.sqrt, expression))
    }

    /// Absolute value: `|a|`
    ///
    /// ## Example
    /// ```swift
    /// let builder = ExpressionBuilder()
    /// let difference = builder[0] - builder[1]
    /// let absDiff = difference.abs()
    /// ```
    public func abs() -> ExpressionProxy {
        return ExpressionProxy(.unary(.abs, expression))
    }

    /// Natural logarithm: `ln(a)`
    ///
    /// ## Example
    /// ```swift
    /// let builder = ExpressionBuilder()
    /// let stockPrice = builder[0]
    /// let logReturn = stockPrice.log()
    /// ```
    public func log() -> ExpressionProxy {
        return ExpressionProxy(.unary(.log, expression))
    }

    /// Exponential: `e^a`
    ///
    /// ## Example
    /// ```swift
    /// let builder = ExpressionBuilder()
    /// let logReturn = builder[0]
    /// let price = logReturn.exp()
    /// ```
    public func exp() -> ExpressionProxy {
        return ExpressionProxy(.unary(.exp, expression))
    }

    /// Power: `a^b` (where b is constant)
    ///
    /// ## Example
    /// ```swift
    /// let builder = ExpressionBuilder()
    /// let principal = builder[0]
    /// let compounded = principal.power(2.0)  // Square
    /// ```
    public func power(_ exponent: Double) -> ExpressionProxy {
        return ExpressionProxy(.binary(.power, expression, .constant(exponent)))
    }

    /// Power: `a^b` (where b is an expression)
    ///
    /// ## Example
    /// ```swift
    /// let builder = ExpressionBuilder()
    /// let base = builder[0]
    /// let exponent = builder[1]
    /// let result = base.power(exponent)  // base^exponent
    /// ```
    public func power(_ exponent: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.power, expression, exponent.expression))
    }

    /// Minimum: `min(a, b)`
    ///
    /// ## Example
    /// ```swift
    /// let builder = ExpressionBuilder()
    /// let capacity = builder[0]
    /// let demand = builder[1]
    /// let production = demand.min(capacity)
    /// ```
    public func min(_ other: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.min, expression, other.expression))
    }

    /// Maximum: `max(a, b)`
    ///
    /// ## Example
    /// ```swift
    /// let builder = ExpressionBuilder()
    /// let profit = builder[0]
    /// let cappedProfit = profit.max(0.0)  // Non-negative profit
    /// ```
    public func max(_ other: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.max, expression, other.expression))
    }

    /// Maximum with constant: `max(a, constant)`
    public func max(_ constant: Double) -> ExpressionProxy {
        return ExpressionProxy(.binary(.max, expression, .constant(constant)))
    }

    /// Minimum with constant: `min(a, constant)`
    public func min(_ constant: Double) -> ExpressionProxy {
        return ExpressionProxy(.binary(.min, expression, .constant(constant)))
    }
}

// MARK: - Comparison Operators

extension ExpressionProxy {

    /// Less than: `a < b` (returns 1.0 if true, 0.0 if false)
    ///
    /// ## Example
    /// ```swift
    /// let builder = ExpressionBuilder()
    /// let revenue = builder[0]
    /// let threshold = builder[1]
    /// let isBelowThreshold = revenue.lessThan(threshold)
    /// ```
    public func lessThan(_ other: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.lessThan, expression, other.expression))
    }

    /// Less than constant: `a < constant`
    public func lessThan(_ constant: Double) -> ExpressionProxy {
        return ExpressionProxy(.binary(.lessThan, expression, .constant(constant)))
    }

    /// Greater than: `a > b` (returns 1.0 if true, 0.0 if false)
    ///
    /// ## Example
    /// ```swift
    /// let builder = ExpressionBuilder()
    /// let profit = builder[0]
    /// let isProfitable = profit.greaterThan(0.0)
    /// ```
    public func greaterThan(_ other: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.greaterThan, expression, other.expression))
    }

    /// Greater than constant: `a > constant`
    public func greaterThan(_ constant: Double) -> ExpressionProxy {
        return ExpressionProxy(.binary(.greaterThan, expression, .constant(constant)))
    }

    /// Less than or equal: `a <= b` (returns 1.0 if true, 0.0 if false)
    public func lessOrEqual(_ other: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.lessOrEqual, expression, other.expression))
    }

    /// Less than or equal to constant: `a <= constant`
    public func lessOrEqual(_ constant: Double) -> ExpressionProxy {
        return ExpressionProxy(.binary(.lessOrEqual, expression, .constant(constant)))
    }

    /// Greater than or equal: `a >= b` (returns 1.0 if true, 0.0 if false)
    public func greaterOrEqual(_ other: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.greaterOrEqual, expression, other.expression))
    }

    /// Greater than or equal to constant: `a >= constant`
    public func greaterOrEqual(_ constant: Double) -> ExpressionProxy {
        return ExpressionProxy(.binary(.greaterOrEqual, expression, .constant(constant)))
    }

    /// Equal: `a == b` (returns 1.0 if true, 0.0 if false, with floating-point epsilon)
    public func equal(_ other: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.equal, expression, other.expression))
    }

    /// Equal to constant: `a == constant`
    public func equal(_ constant: Double) -> ExpressionProxy {
        return ExpressionProxy(.binary(.equal, expression, .constant(constant)))
    }

    /// Not equal: `a != b` (returns 1.0 if true, 0.0 if false, with floating-point epsilon)
    public func notEqual(_ other: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.notEqual, expression, other.expression))
    }

    /// Not equal to constant: `a != constant`
    public func notEqual(_ constant: Double) -> ExpressionProxy {
        return ExpressionProxy(.binary(.notEqual, expression, .constant(constant)))
    }
}

// MARK: - Conditional Expressions

extension ExpressionProxy {

    /// Conditional selection: `condition ? trueValue : falseValue`
    ///
    /// Creates a ternary if-else expression. The condition is evaluated as a boolean:
    /// non-zero = true, zero = false.
    ///
    /// ## Example - Revenue-Based Bonus
    ///
    /// ```swift
    /// let model = MonteCarloExpressionModel { builder in
    ///     let revenue = builder[0]
    ///     let baseProfit = builder[1]
    ///
    ///     // If revenue > 1M, apply 20% bonus
    ///     let condition = revenue.greaterThan(1_000_000)
    ///     let bonus = baseProfit * 1.2
    ///     let profit = condition.ifElse(then: bonus, else: baseProfit)
    ///
    ///     return profit
    /// }
    /// ```
    ///
    /// ## Example - Capacity Constraints
    ///
    /// ```swift
    /// let model = MonteCarloExpressionModel { builder in
    ///     let demand = builder[0]
    ///     let capacity = builder[1]
    ///
    ///     // Production = min(demand, capacity) using conditional
    ///     let exceedsCapacity = demand.greaterThan(capacity)
    ///     let production = exceedsCapacity.ifElse(
    ///         then: capacity,
    ///         else: demand
    ///     )
    ///
    ///     return production
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - trueValue: Expression to use if condition is non-zero
    ///   - falseValue: Expression to use if condition is zero
    /// - Returns: Selected expression based on condition
    public func ifElse(then trueValue: ExpressionProxy, else falseValue: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.conditional(expression, trueValue.expression, falseValue.expression))
    }

    /// Conditional with constant true branch: `condition ? constant : falseValue`
    public func ifElse(then trueConstant: Double, else falseValue: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.conditional(expression, .constant(trueConstant), falseValue.expression))
    }

    /// Conditional with constant false branch: `condition ? trueValue : constant`
    public func ifElse(then trueValue: ExpressionProxy, else falseConstant: Double) -> ExpressionProxy {
        return ExpressionProxy(.conditional(expression, trueValue.expression, .constant(falseConstant)))
    }

    /// Conditional with both constants: `condition ? const1 : const2`
    public func ifElse(then trueConstant: Double, else falseConstant: Double) -> ExpressionProxy {
        return ExpressionProxy(.conditional(expression, .constant(trueConstant), .constant(falseConstant)))
    }
}

// MARK: - Trigonometric Functions

extension ExpressionProxy {

    /// Sine: `sin(a)`
    public func sin() -> ExpressionProxy {
        return ExpressionProxy(.unary(.sin, expression))
    }

    /// Cosine: `cos(a)`
    public func cos() -> ExpressionProxy {
        return ExpressionProxy(.unary(.cos, expression))
    }

    /// Tangent: `tan(a)`
    public func tan() -> ExpressionProxy {
        return ExpressionProxy(.unary(.tan, expression))
    }
}

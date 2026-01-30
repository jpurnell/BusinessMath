//
//  Expression.swift
//  BusinessMath
//
//  Mathematical Expression AST for GPU Compilation
//
//  This file defines the expression tree structure that enables GPU compilation
//  of Monte Carlo models. Expressions are built by the ExpressionBuilder and
//  compiled to GPU bytecode by the BytecodeCompiler.
//

import Foundation

/// Represents a mathematical expression that can be compiled to GPU bytecode
///
/// Expression is an algebraic data type (ADT) that forms an abstract syntax tree (AST)
/// for mathematical operations. It supports:
/// - Input variable references
/// - Constant values
/// - Binary operations (add, subtract, multiply, divide, power, min, max)
/// - Unary operations (negate, abs, sqrt, log, exp, trigonometric functions)
///
/// ## Usage
///
/// Expressions are typically built using the ExpressionBuilder DSL rather than
/// constructed directly:
///
/// ```swift
/// let builder = ExpressionBuilder()
/// let expr = builder[0] * builder[1] - builder[2]
/// // Creates: Expression.binary(.subtract,
/// //            Expression.binary(.multiply, .input(0), .input(1)),
/// //            .input(2))
/// ```
///
/// ## GPU Compilation
///
/// Expressions can be compiled to GPU bytecode for parallel execution:
///
/// ```swift
/// let bytecode = try BytecodeCompiler.compile(expression)
/// let gpuBytecode = BytecodeCompiler.toGPUFormat(bytecode)
/// ```
///
/// ## CPU Fallback
///
/// Expressions can also be evaluated on CPU using ExpressionEvaluator:
///
/// ```swift
/// let result = ExpressionEvaluator.evaluate(expression, inputs: [10.0, 20.0, 5.0])
/// ```
public indirect enum Expression: Sendable, Equatable {

    // MARK: - Cases

    /// Reference to an input variable by index
    ///
    /// - Parameter Int: The zero-based index of the input variable
    ///
    /// Example: `.input(0)` refers to the first input variable in the Monte Carlo simulation
    case input(Int)

    /// Constant floating-point value
    ///
    /// - Parameter Double: The constant value
    ///
    /// Example: `.constant(42.0)` represents the literal value 42.0
    case constant(Double)

    /// Binary operation on two sub-expressions
    ///
    /// - Parameters:
    ///   - BinaryOp: The operation to perform
    ///   - Expression: Left operand
    ///   - Expression: Right operand
    ///
    /// Example: `.binary(.add, .input(0), .constant(5.0))` represents `input[0] + 5.0`
    case binary(BinaryOp, Expression, Expression)

    /// Unary operation on a single sub-expression
    ///
    /// - Parameters:
    ///   - UnaryOp: The operation to perform
    ///   - Expression: The operand
    ///
    /// Example: `.unary(.negate, .input(0))` represents `-input[0]`
    case unary(UnaryOp, Expression)

    // MARK: - Binary Operations

    /// Binary mathematical operations
    public enum BinaryOp: Sendable, Equatable {
        /// Addition: a + b
        case add

        /// Subtraction: a - b
        case subtract

        /// Multiplication: a * b
        case multiply

        /// Division: a / b
        case divide

        /// Exponentiation: a^b
        case power

        /// Minimum: min(a, b)
        case min

        /// Maximum: max(a, b)
        case max
    }

    // MARK: - Unary Operations

    /// Unary mathematical operations
    public enum UnaryOp: Sendable, Equatable {
        /// Negation: -a
        case negate

        /// Absolute value: |a|
        case abs

        /// Square root: √a
        case sqrt

        /// Natural logarithm: ln(a)
        case log

        /// Exponential: e^a
        case exp

        /// Sine: sin(a)
        case sin

        /// Cosine: cos(a)
        case cos

        /// Tangent: tan(a)
        case tan
    }
}

// MARK: - Debug Descriptions

extension Expression: CustomStringConvertible {
    /// Human-readable description of the expression tree
    public var description: String {
        switch self {
        case .input(let index):
            return "input[\(index)]"

        case .constant(let value):
            return "\(value)"

        case .binary(let op, let left, let right):
            let opStr: String
            switch op {
            case .add:      opStr = "+"
            case .subtract: opStr = "-"
            case .multiply: opStr = "*"
            case .divide:   opStr = "/"
            case .power:    opStr = "^"
            case .min:      opStr = "min"
            case .max:      opStr = "max"
            }

            if op == .min || op == .max {
                return "\(opStr)(\(left), \(right))"
            } else {
                return "(\(left) \(opStr) \(right))"
            }

        case .unary(let op, let operand):
            let opStr: String
            switch op {
            case .negate: return "-(\(operand))"
            case .abs:    opStr = "abs"
            case .sqrt:   opStr = "sqrt"
            case .log:    opStr = "log"
            case .exp:    opStr = "exp"
            case .sin:    opStr = "sin"
            case .cos:    opStr = "cos"
            case .tan:    opStr = "tan"
            }
            return "\(opStr)(\(operand))"
        }
    }
}

// MARK: - Expression Analysis

extension Expression {
    /// Returns the maximum input index referenced in this expression
    ///
    /// Used to validate that all referenced inputs exist in the simulation.
    ///
    /// - Returns: The highest input index, or nil if no inputs are referenced
    public func maxInputIndex() -> Int? {
        switch self {
        case .input(let index):
            return index

        case .constant:
            return nil

        case .binary(_, let left, let right):
            let leftMax = left.maxInputIndex()
            let rightMax = right.maxInputIndex()

            if let l = leftMax, let r = rightMax {
                return max(l, r)
            } else {
                return leftMax ?? rightMax
            }

        case .unary(_, let operand):
            return operand.maxInputIndex()
        }
    }

    /// Returns the number of operations in this expression tree
    ///
    /// Used for complexity analysis and optimization heuristics.
    ///
    /// - Returns: Count of binary and unary operations
    public func operationCount() -> Int {
        switch self {
        case .input, .constant:
            return 0

        case .binary(_, let left, let right):
            return 1 + left.operationCount() + right.operationCount()

        case .unary(_, let operand):
            return 1 + operand.operationCount()
        }
    }

    /// Checks if this expression contains only constants (no inputs)
    ///
    /// Used by the optimizer to detect compile-time evaluable expressions.
    ///
    /// - Returns: true if expression is purely constant
    public func isConstant() -> Bool {
        switch self {
        case .constant:
            return true

        case .input:
            return false

        case .binary(_, let left, let right):
            return left.isConstant() && right.isConstant()

        case .unary(_, let operand):
            return operand.isConstant()
        }
    }
}

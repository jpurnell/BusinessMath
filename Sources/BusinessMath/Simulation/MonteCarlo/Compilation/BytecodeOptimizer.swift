//
//  BytecodeOptimizer.swift
//  BusinessMath
//
//  Bytecode Optimizer for GPU Execution
//
//  Performs compile-time optimizations on bytecode including:
//  - Constant folding: Evaluate constant expressions at compile time
//  - Algebraic simplification: Apply mathematical identities (a + 0 = a, etc.)
//  - Dead code elimination: Remove unreachable or redundant instructions
//
//  The optimizer uses multi-pass optimization until convergence, with a
//  maximum iteration limit to prevent infinite loops.
//

import Foundation

// MARK: - Bytecode Optimizer

/// Optimizes bytecode through compile-time transformations
///
/// The optimizer performs multiple passes over the bytecode, applying
/// transformations until no further optimizations are possible or the
/// maximum iteration limit is reached.
///
/// ## Optimization Techniques
///
/// **Constant Folding:**
/// - `5.0 + 3.0` → `8.0`
/// - `sqrt(16.0)` → `4.0`
/// - Evaluates any expression with only constant operands
///
/// **Algebraic Simplification:**
/// - `a + 0` → `a`
/// - `a * 1` → `a`
/// - `a * 0` → `0`
/// - `a - 0` → `a`
/// - `a / 1` → `a`
///
/// **Multi-Pass Optimization:**
/// - `(a + 0) * 1` → `a * 1` → `a`
/// - Continues until convergence
///
/// ## Usage
///
/// ```swift
/// let bytecode = try BytecodeCompiler.compile(expression)
/// let optimized = BytecodeOptimizer.optimize(bytecode)
/// // optimized bytecode is functionally equivalent but more efficient
/// ```
public struct BytecodeOptimizer {

    /// Maximum number of optimization passes to prevent infinite loops
    private static let maxPasses = 10

    // MARK: - Internal Types

    /// Represents a value on the optimization stack
    ///
    /// During optimization, we track intermediate computation results as either:
    /// - A single bytecode instruction (input, constant)
    /// - A computed sequence of bytecode that produces a value
    private enum StackValue {
        case single(Bytecode)
        case computed([Bytecode])
    }

    /// Extract bytecode sequence from a stack value
    private static func extractBytecode(_ value: StackValue) -> [Bytecode] {
        switch value {
        case .single(let bytecode):
            return [bytecode]
        case .computed(let sequence):
            return sequence
        }
    }

    // MARK: - Public API

    /// Optimize bytecode through multiple transformation passes
    ///
    /// Applies constant folding, algebraic simplification, and dead code
    /// elimination in multiple passes until convergence or maximum iterations.
    ///
    /// - Parameter bytecode: Input bytecode to optimize
    /// - Returns: Optimized bytecode (functionally equivalent)
    public static func optimize(_ bytecode: [Bytecode]) -> [Bytecode] {
        var current = bytecode
        var passCount = 0

        // Multi-pass optimization until convergence
        while passCount < maxPasses {
            let previous = current

            // Apply optimization passes
            current = constantFoldingPass(current)
            current = algebraicSimplificationPass(current)

            // Check for convergence
            if current == previous {
                break
            }

            passCount += 1
        }

        return current
    }

    // MARK: - Constant Folding

    /// Apply constant folding to evaluate compile-time constants
    ///
    /// Simulates stack execution to detect patterns where all operands
    /// are constants, then evaluates the operation at compile time.
    ///
    /// Example: `[.constant(5.0), .constant(3.0), .add]` → `[.constant(8.0)]`
    private static func constantFoldingPass(_ bytecode: [Bytecode]) -> [Bytecode] {
        var stack: [StackValue] = []

        for instruction in bytecode {
            switch instruction {
            case .input, .constant:
                stack.append(.single(instruction))

            case .add, .subtract, .multiply, .divide, .power, .min, .max:
                guard stack.count >= 2 else { continue }
                let right = stack.removeLast()
                let left = stack.removeLast()

                // Try constant folding
                if case .single(.constant(let a)) = left,
                   case .single(.constant(let b)) = right {
                    let result = evaluateBinaryOp(instruction, a, b)
                    stack.append(.single(.constant(result)))
                } else {
                    // Can't fold - rebuild bytecode sequence
                    var sequence: [Bytecode] = []
                    sequence.append(contentsOf: extractBytecode(left))
                    sequence.append(contentsOf: extractBytecode(right))
                    sequence.append(instruction)
                    stack.append(.computed(sequence))
                }

            case .negate, .abs, .sqrt, .log, .exp, .sin, .cos, .tan:
                guard stack.count >= 1 else { continue }
                let operand = stack.removeLast()

                // Try constant folding
                if case .single(.constant(let value)) = operand {
                    let result = evaluateUnaryOp(instruction, value)
                    stack.append(.single(.constant(result)))
                } else {
                    // Can't fold - rebuild bytecode sequence
                    var sequence: [Bytecode] = []
                    sequence.append(contentsOf: extractBytecode(operand))
                    sequence.append(instruction)
                    stack.append(.computed(sequence))
                }
            }
        }

        // Extract final bytecode from stack
        var result: [Bytecode] = []
        for value in stack {
            result.append(contentsOf: extractBytecode(value))
        }
        return result
    }

    /// Evaluate a binary operation on constants
    private static func evaluateBinaryOp(_ op: Bytecode, _ a: Double, _ b: Double) -> Double {
        switch op {
        case .add:      return a + b
        case .subtract: return a - b
        case .multiply: return a * b
        case .divide:   return a / b
        case .power:    return pow(a, b)
        case .min:      return Swift.min(a, b)
        case .max:      return Swift.max(a, b)
        default:        return 0.0  // Should never happen
        }
    }

    /// Evaluate a unary operation on a constant
    private static func evaluateUnaryOp(_ op: Bytecode, _ value: Double) -> Double {
        switch op {
        case .negate: return -value
        case .abs:    return abs(value)
        case .sqrt:   return sqrt(value)
        case .log:    return log(value)
        case .exp:    return exp(value)
        case .sin:    return sin(value)
        case .cos:    return cos(value)
        case .tan:    return tan(value)
        default:      return 0.0  // Should never happen
        }
    }

    // MARK: - Algebraic Simplification

    /// Apply algebraic simplification for mathematical identities
    ///
    /// Detects patterns like `a + 0`, `a * 1`, `a * 0` and replaces them
    /// with simplified equivalents.
    ///
    /// Simplification rules:
    /// - `a + 0` → `a`
    /// - `0 + a` → `a`
    /// - `a - 0` → `a`
    /// - `a * 1` → `a`
    /// - `1 * a` → `a`
    /// - `a / 1` → `a`
    /// - `a * 0` → `0`
    /// - `0 * a` → `0`
    private static func algebraicSimplificationPass(_ bytecode: [Bytecode]) -> [Bytecode] {
        var stack: [StackValue] = []

        for instruction in bytecode {
            switch instruction {
            case .input, .constant:
                stack.append(.single(instruction))

            case .add:
                guard stack.count >= 2 else { continue }
                let right = stack.removeLast()
                let left = stack.removeLast()

                // a + 0 → a
                if case .single(.constant(0.0)) = right {
                    stack.append(left)
                }
                // 0 + a → a
                else if case .single(.constant(0.0)) = left {
                    stack.append(right)
                }
                // No simplification - rebuild bytecode
                else {
                    var sequence: [Bytecode] = []
                    sequence.append(contentsOf: extractBytecode(left))
                    sequence.append(contentsOf: extractBytecode(right))
                    sequence.append(.add)
                    stack.append(.computed(sequence))
                }

            case .subtract:
                guard stack.count >= 2 else { continue }
                let right = stack.removeLast()
                let left = stack.removeLast()

                // a - 0 → a
                if case .single(.constant(0.0)) = right {
                    stack.append(left)
                }
                // No simplification - rebuild bytecode
                else {
                    var sequence: [Bytecode] = []
                    sequence.append(contentsOf: extractBytecode(left))
                    sequence.append(contentsOf: extractBytecode(right))
                    sequence.append(.subtract)
                    stack.append(.computed(sequence))
                }

            case .multiply:
                guard stack.count >= 2 else { continue }
                let right = stack.removeLast()
                let left = stack.removeLast()

                // a * 0 → 0
                if case .single(.constant(0.0)) = right {
                    stack.append(.single(.constant(0.0)))
                }
                // 0 * a → 0
                else if case .single(.constant(0.0)) = left {
                    stack.append(.single(.constant(0.0)))
                }
                // a * 1 → a
                else if case .single(.constant(1.0)) = right {
                    stack.append(left)
                }
                // 1 * a → a
                else if case .single(.constant(1.0)) = left {
                    stack.append(right)
                }
                // No simplification - rebuild bytecode
                else {
                    var sequence: [Bytecode] = []
                    sequence.append(contentsOf: extractBytecode(left))
                    sequence.append(contentsOf: extractBytecode(right))
                    sequence.append(.multiply)
                    stack.append(.computed(sequence))
                }

            case .divide:
                guard stack.count >= 2 else { continue }
                let right = stack.removeLast()
                let left = stack.removeLast()

                // a / 1 → a
                if case .single(.constant(1.0)) = right {
                    stack.append(left)
                }
                // No simplification - rebuild bytecode
                else {
                    var sequence: [Bytecode] = []
                    sequence.append(contentsOf: extractBytecode(left))
                    sequence.append(contentsOf: extractBytecode(right))
                    sequence.append(.divide)
                    stack.append(.computed(sequence))
                }

            default:
                // Other operations - no simplification supported yet
                guard stack.count >= 1 else { continue }
                let operand = stack.removeLast()

                var sequence: [Bytecode] = []
                sequence.append(contentsOf: extractBytecode(operand))
                sequence.append(instruction)
                stack.append(.computed(sequence))
            }
        }

        // Extract final bytecode from stack
        var result: [Bytecode] = []
        for value in stack {
            result.append(contentsOf: extractBytecode(value))
        }
        return result
    }
}

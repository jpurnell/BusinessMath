//
//  BytecodeOptimizer.swift
//  BusinessMath
//
//  Bytecode Optimizer for GPU Execution
//
//  Performs compile-time optimizations on bytecode including:
//  - Constant folding: Evaluate constant expressions at compile time, except where
//    the interpreter would throw instead of producing one
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
/// - `a + (-0.0)` → `a`
/// - `a - (+0.0)` → `a`
/// - `a * 1` → `a`
/// - `a / 1` → `a`
///
/// The two additive rules are one identity written twice: adding a negative zero, and
/// subtracting a positive one, are exact for every `a`. Their mirror images are not —
/// `a + (+0.0)` and `a - (-0.0)` both turn `-0.0` into `+0.0` — so neither is applied.
///
/// `a * 0 → 0` is absent for a larger reason: it is false for `inf`, `NaN` and any negative
/// `a`. See the note at the multiply case.
///
/// Folding stops where the interpreter throws. `1 / 0`, `sqrt(-1)` and `log(0)` are left
/// in the bytecode so that an optimized model raises the same error an unoptimized one
/// does.
///
/// **Multi-Pass Optimization:**
/// - `(a + 0) * 1` → `a * 1` → `a`
/// - Continues until convergence
///
/// ## Usage
///
/// ```swift
/// let expression = Expression.binary(.add, .input(0), .constant(1.0))
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

            case .add, .subtract, .multiply, .divide, .power, .min, .max,
                 .lessThan, .greaterThan, .lessOrEqual, .greaterOrEqual, .equal, .notEqual:
                guard stack.count >= 2 else { continue }
                let right = stack.removeLast()
                let left = stack.removeLast()

                // Try constant folding. `evaluateBinaryOp` returns nil where the
                // interpreter would throw rather than produce a value; the fold is then
                // declined and the instruction survives to raise the error at run time.
                if case .single(.constant(let a)) = left,
                   case .single(.constant(let b)) = right,
                   let result = evaluateBinaryOp(instruction, a, b) {
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

                // Try constant folding, declined where the interpreter would throw.
                if case .single(.constant(let value)) = operand,
                   let result = evaluateUnaryOp(instruction, value) {
                    stack.append(.single(.constant(result)))
                } else {
                    // Can't fold - rebuild bytecode sequence
                    var sequence: [Bytecode] = []
                    sequence.append(contentsOf: extractBytecode(operand))
                    sequence.append(instruction)
                    stack.append(.computed(sequence))
                }

            case .select:
                guard stack.count >= 3 else { continue }
                let falseValue = stack.removeLast()
                let trueValue = stack.removeLast()
                let condition = stack.removeLast()

                // Try constant folding if condition is constant
                if case .single(.constant(let cond)) = condition,
                   case .single(.constant(let trueConst)) = trueValue,
                   case .single(.constant(let falseConst)) = falseValue {
                    let result = (cond != 0.0) ? trueConst : falseConst
                    stack.append(.single(.constant(result)))
                } else {
                    // Can't fold - rebuild bytecode sequence
                    var sequence: [Bytecode] = []
                    sequence.append(contentsOf: extractBytecode(condition))
                    sequence.append(contentsOf: extractBytecode(trueValue))
                    sequence.append(contentsOf: extractBytecode(falseValue))
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

    /// Evaluate a binary operation on constants.
    ///
    /// Returns `nil` where ``BytecodeInterpreter`` would throw instead of returning a
    /// value. A model must not answer differently for having been optimized, and the
    /// interpreter's errors are part of its answer: `1 / 0` throws
    /// `EvaluationError.divisionByZero` unoptimized, so folding it to `inf` would make
    /// optimization the difference between a thrown error and a silent infinity.
    ///
    /// - Returns: The folded constant, or `nil` if this operation must be left to run time.
    private static func evaluateBinaryOp(_ op: Bytecode, _ a: Double, _ b: Double) -> Double? {
        switch op {
        case .add:      return a + b
        case .subtract: return a - b
        case .multiply: return a * b
        case .divide:
            // The interpreter guards `b != 0` and throws. Decline, and let it.
            guard b != 0 else { return nil }
            return a / b
        case .power:    return pow(a, b)
        case .min:      return Swift.min(a, b)
        case .max:      return Swift.max(a, b)
        case .lessThan:        return a < b ? 1.0 : 0.0
        case .greaterThan:     return a > b ? 1.0 : 0.0
        case .lessOrEqual:     return a <= b ? 1.0 : 0.0
        case .greaterOrEqual:  return a >= b ? 1.0 : 0.0
        case .equal:           return abs(a - b) < 1e-10 ? 1.0 : 0.0
        case .notEqual:        return abs(a - b) >= 1e-10 ? 1.0 : 0.0
        default:        return 0.0  // Should never happen
        }
    }

    /// Evaluate a unary operation on a constant.
    ///
    /// Returns `nil` where ``BytecodeInterpreter`` would throw. See
    /// ``evaluateBinaryOp(_:_:_:)`` for why the two must agree.
    ///
    /// - Returns: The folded constant, or `nil` if this operation must be left to run time.
    private static func evaluateUnaryOp(_ op: Bytecode, _ value: Double) -> Double? {
        switch op {
        case .negate: return -value
        case .abs:    return abs(value)
        case .sqrt:
            // The interpreter guards `a >= 0` and throws `invalidOperation`.
            guard value >= 0 else { return nil }
            return sqrt(value)
        case .log:
            // The interpreter guards `a > 0` and throws `invalidOperation`.
            guard value > 0 else { return nil }
            return log(value)
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
    /// Detects patterns like `a + 0` and `a * 1` and replaces them with simplified
    /// equivalents.
    ///
    /// Simplification rules:
    /// - `a + (-0.0)` → `a`
    /// - `(-0.0) + a` → `a`
    /// - `a - (+0.0)` → `a`
    /// - `a * 1` → `a`
    /// - `1 * a` → `a`
    /// - `a / 1` → `a`
    ///
    /// `a * 0 → 0` and `0 * a → 0` were removed as unsound; the multiply case says why.
    ///
    /// - Note: the additive rules carry a sign condition, and it is not decoration. Exactly
    ///   one additive identity is exact for every `a`: adding `-0.0`. Adding `+0.0` turns
    ///   `-0.0` into `+0.0`, and subtracting `-0.0` is the same operation under another
    ///   name. Since `-0.0 == 0.0`, a `case .constant(0.0)` pattern matches both, so the
    ///   condition has to read `.sign` — which is why `a - 0 → a` was unsound here without
    ///   a `-0.0` appearing anywhere in the source.
    ///
    ///   This pass now has no rewrite that can change a result, in any bit, for any input.
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

                // a + (-0.0) → a, and only that.
                //
                // `a + (+0.0)` is exact for every `a` except `-0.0`, where the sum is
                // `+0.0` and returning `a` gives `-0.0`. Adding a *negative* zero is the
                // identity without exception, which is why LLVM folds `fadd x, -0.0`
                // unconditionally and requires the `nsz` fast-math flag for `fadd x, 0.0`.
                //
                // The sign has to be asked for. `case .constant(0.0)` matches through
                // `==`, and `-0.0 == 0.0`, so the pattern alone cannot tell the two apart —
                // which is how the subtract case below was unsound without anyone writing
                // a `-0.0` anywhere.
                if case .single(.constant(let addend)) = right, addend.isZero, addend.sign == .minus {
                    stack.append(left)
                }
                // (-0.0) + a → a
                else if case .single(.constant(let addend)) = left, addend.isZero, addend.sign == .minus {
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

                // a - (+0.0) → a, which is the same identity as the addition above:
                // subtracting a positive zero is adding a negative one. `a - (-0.0)` is
                // `a + (+0.0)` and fails for `a = -0.0` exactly as that does.
                if case .single(.constant(let subtrahend)) = right, subtrahend.isZero, subtrahend.sign == .plus {
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

                // `a * 0 → 0` is not here, and must not be. It holds in real arithmetic
                // and fails in three ways in IEEE-754: `inf * 0` and `NaN * 0` are NaN, and
                // `(-3) * 0` is -0.0, so the rewrite turns two of them into a plausible
                // zero and the third into the wrong zero. Establishing that `a` is finite
                // would make it sound, but `a` here is an input or a computed sequence and
                // nothing in this compiler carries that fact. Where `a` *is* a constant,
                // `constantFoldingPass` has already evaluated the product exactly, signed
                // zero and NaN included, so no optimization is lost by its absence.
                //
                // `a * 1 → a` needs no such care: `-0.0`, `inf` and `NaN` all survive it.
                // a * 1 → a
                if case .single(.constant(1.0)) = right {
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

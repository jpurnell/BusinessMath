import Testing
import TestSupport  // Cross-platform math functions
import Foundation
@testable import BusinessMath

/// Tests for Bytecode Optimizer
///
/// Validates compile-time optimizations including constant folding,
/// algebraic simplification, and dead code elimination.

// Disambiguate from Foundation.Expression (macOS 15+)
fileprivate typealias MathExpression = BusinessMath.Expression

@Suite("Bytecode Optimizer Tests")
struct BytecodeOptimizerTests {

    // MARK: - Constant Folding

    @Test("Constant folding: 5.0 + 3.0 → 8.0")
    func testConstantFoldingAddition() throws {
        let expr = MathExpression.binary(.add, .constant(5.0), .constant(3.0))
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let expected: [Bytecode] = [.constant(8.0)]
        #expect(optimized == expected)
    }

    @Test("Constant folding: 10.0 - 3.0 → 7.0")
    func testConstantFoldingSubtraction() throws {
        let expr = MathExpression.binary(.subtract, .constant(10.0), .constant(3.0))
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let expected: [Bytecode] = [.constant(7.0)]
        #expect(optimized == expected)
    }

    @Test("Constant folding: 4.0 * 2.0 → 8.0")
    func testConstantFoldingMultiplication() throws {
        let expr = MathExpression.binary(.multiply, .constant(4.0), .constant(2.0))
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let expected: [Bytecode] = [.constant(8.0)]
        #expect(optimized == expected)
    }

    @Test("Constant folding: 20.0 / 4.0 → 5.0")
    func testConstantFoldingDivision() throws {
        let expr = MathExpression.binary(.divide, .constant(20.0), .constant(4.0))
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let expected: [Bytecode] = [.constant(5.0)]
        #expect(optimized == expected)
    }

    @Test("Constant folding: sqrt(16.0) → 4.0")
    func testConstantFoldingUnary() throws {
        let expr = MathExpression.unary(.sqrt, .constant(16.0))
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let expected: [Bytecode] = [.constant(4.0)]
        #expect(optimized == expected)
    }

    // MARK: - Algebraic Simplification

    @Test("Algebraic simplification: a + 0 → a")
    func testAddZero() throws {
        let expr = MathExpression.binary(.add, .input(0), .constant(0.0))
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let expected: [Bytecode] = [.input(0)]
        #expect(optimized == expected)
    }

    @Test("Algebraic simplification: a - 0 → a")
    func testSubtractZero() throws {
        let expr = MathExpression.binary(.subtract, .input(0), .constant(0.0))
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let expected: [Bytecode] = [.input(0)]
        #expect(optimized == expected)
    }

    @Test("Algebraic simplification: a * 1 → a")
    func testMultiplyByOne() throws {
        let expr = MathExpression.binary(.multiply, .input(0), .constant(1.0))
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let expected: [Bytecode] = [.input(0)]
        #expect(optimized == expected)
    }

    @Test("Algebraic simplification: a / 1 → a")
    func testDivideByOne() throws {
        let expr = MathExpression.binary(.divide, .input(0), .constant(1.0))
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let expected: [Bytecode] = [.input(0)]
        #expect(optimized == expected)
    }

    /// `a * 0 → 0` is false in IEEE-754, and the optimizer no longer claims it.
    ///
    /// The rewrite held for any `a` the algebra has in mind and for none of the three the
    /// hardware adds: `inf * 0` and `NaN * 0` are NaN, and `(-3) * 0` is `-0.0`. Rewriting
    /// discarded `a` entirely, so a model that should have produced NaN produced a
    /// perfectly plausible zero — the failure this library's rules exist to prevent.
    ///
    /// Knowing `a` to be finite would make it sound, but `a` is an input here and nothing
    /// in this compiler tracks that.
    @Test("a * 0 is not rewritten, because a * 0 is not always 0")
    func testMultiplyByZeroIsNotRewritten() throws {
        let expr = MathExpression.binary(.multiply, .input(0), .constant(0.0))
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        #expect(optimized == bytecode, "the multiply was optimized away into \(optimized)")

        let fromInfinity = try BytecodeInterpreter.evaluate(bytecode: optimized, inputs: [Double.infinity])
        #expect(fromInfinity.isNaN, "inf * 0 is NaN; the model returned \(fromInfinity)")

        let fromNaN = try BytecodeInterpreter.evaluate(bytecode: optimized, inputs: [Double.nan])
        #expect(fromNaN.isNaN, "NaN * 0 is NaN; the model returned \(fromNaN)")

        let fromNegative = try BytecodeInterpreter.evaluate(bytecode: optimized, inputs: [-3.0])
        #expect(fromNegative == 0.0, "(-3) * 0 is a zero; the model returned \(fromNegative)")
        #expect(fromNegative.sign == .minus, "(-3) * 0 is -0.0; the model returned +0.0")
    }

    /// Nothing is lost by that removal: where the operand is a constant, folding already
    /// evaluates the product exactly — sign of zero included.
    ///
    /// The assertion has to ask for the sign. `Bytecode` is `Equatable` through `Double`,
    /// and `-0.0 == 0.0`, so comparing against `.constant(-0.0)` passes either way and
    /// proves nothing.
    @Test("A constant times zero still folds, and keeps the sign it earns")
    func testConstantTimesZeroFoldsWithItsSign() throws {
        let expr = MathExpression.binary(.multiply, .constant(-3.0), .constant(0.0))
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        guard optimized.count == 1, case .constant(let folded) = optimized[0] else {
            Issue.record("expected one folded constant, got \(optimized)")
            return
        }
        #expect(folded == 0.0, "(-3) * 0 folded to \(folded)")
        #expect(folded.sign == .minus, "(-3) * 0 folded to +0.0, losing the sign")
    }

    // MARK: - Folding Stops Where the Interpreter Throws

    /// Evaluates `bytecode` and returns the ``EvaluationError`` it threw.
    ///
    /// Records an issue and returns `nil` if it produced a value instead, so a test that
    /// asks for the error case cannot quietly pass on a model that did not throw at all.
    private func errorFrom(_ bytecode: [Bytecode], inputs: [Double] = []) -> EvaluationError? {
        do {
            let value = try BytecodeInterpreter.evaluate(bytecode: bytecode, inputs: inputs)
            Issue.record("expected a throw, got \(value)")
            return nil
        } catch let error as EvaluationError {
            return error
        } catch {
            Issue.record("expected an EvaluationError, got \(error)")
            return nil
        }
    }

    /// The same model must not answer differently for having been optimized.
    ///
    /// ``BytecodeInterpreter`` throws on three operations — `divide` by zero, `sqrt` of a
    /// negative, `log` of a non-positive — so those are part of the model's answer, not
    /// accidents of execution. Folding them at compile time replaced a thrown error with
    /// `inf` or `NaN`, which is the same fail-silent trade the multiply rewrite made.
    @Test("Division by zero is left for the interpreter to reject")
    func testDivisionByZeroIsNotFolded() throws {
        let expr = MathExpression.binary(.divide, .constant(1.0), .constant(0.0))
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        #expect(optimized == bytecode, "1 / 0 was folded to \(optimized)")

        guard case .divisionByZero = errorFrom(optimized) else {
            Issue.record("optimized 1 / 0 did not throw divisionByZero")
            return
        }
    }

    @Test("sqrt of a negative constant is left for the interpreter to reject")
    func testNegativeSqrtIsNotFolded() throws {
        let expr = MathExpression.unary(.sqrt, .constant(-1.0))
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        #expect(optimized == bytecode, "sqrt(-1) was folded to \(optimized)")

        guard case .invalidOperation(let message) = errorFrom(optimized) else {
            Issue.record("optimized sqrt(-1) did not throw invalidOperation")
            return
        }
        #expect(message == "sqrt of negative", "threw invalidOperation(\(message))")
    }

    @Test("log of zero is left for the interpreter to reject")
    func testLogOfZeroIsNotFolded() throws {
        let expr = MathExpression.unary(.log, .constant(0.0))
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        #expect(optimized == bytecode, "log(0) was folded to \(optimized)")

        guard case .invalidOperation(let message) = errorFrom(optimized) else {
            Issue.record("optimized log(0) did not throw invalidOperation")
            return
        }
        #expect(message == "log of non-positive", "threw invalidOperation(\(message))")
    }

    /// The case that needs both fixes at once, and the one the review named.
    ///
    /// `log(0) * 0` returned `0` optimized and threw unoptimized. Folding produced
    /// `-infinity` for the logarithm, and the multiply rewrite then discarded it for a
    /// zero — two separate unsound steps composing into an answer with no trace of the
    /// error in it.
    @Test("log(0) * 0 throws whether optimized or not")
    func testOptimizationPreservesTheLogError() throws {
        let expr = MathExpression.binary(
            .multiply,
            MathExpression.unary(.log, .constant(0.0)),
            .constant(0.0)
        )
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        guard case .invalidOperation(let unoptimizedMessage) = errorFrom(bytecode) else {
            Issue.record("unoptimized log(0) * 0 did not throw invalidOperation")
            return
        }
        guard case .invalidOperation(let optimizedMessage) = errorFrom(optimized) else {
            Issue.record("optimized log(0) * 0 did not throw invalidOperation")
            return
        }
        #expect(unoptimizedMessage == optimizedMessage,
                "unoptimized threw \(unoptimizedMessage), optimized threw \(optimizedMessage)")
        #expect(optimizedMessage == "log of non-positive")
    }

    @Test("Algebraic simplification: 0 + a → a")
    func testZeroPlus() throws {
        let expr = MathExpression.binary(.add, .constant(0.0), .input(0))
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let expected: [Bytecode] = [.input(0)]
        #expect(optimized == expected)
    }

    @Test("Algebraic simplification: 1 * a → a")
    func testOneMultiply() throws {
        let expr = MathExpression.binary(.multiply, .constant(1.0), .input(0))
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let expected: [Bytecode] = [.input(0)]
        #expect(optimized == expected)
    }

    // MARK: - Complex Optimizations

    @Test("Complex optimization: (a + 0) * 1 + (5 * 2)")
    func testComplexOptimization() throws {
        // (a + 0) * 1 + (5 * 2) → a + 10
        let expr = MathExpression.binary(
            .add,
            MathExpression.binary(
                .multiply,
                MathExpression.binary(.add, .input(0), .constant(0.0)),
                .constant(1.0)
            ),
            MathExpression.binary(.multiply, .constant(5.0), .constant(2.0))
        )

        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let expected: [Bytecode] = [
            .input(0),
            .constant(10.0),
            .add
        ]
        #expect(optimized == expected)
    }

    @Test("Multi-pass optimization: (a + 0) * 1")
    func testMultiPassOptimization() throws {
        // Pass 1: a + 0 → a
        // Pass 2: a * 1 → a
        let expr = MathExpression.binary(
            .multiply,
            MathExpression.binary(.add, .input(0), .constant(0.0)),
            .constant(1.0)
        )

        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let expected: [Bytecode] = [.input(0)]
        #expect(optimized == expected)
    }

    @Test("Nested constant folding: sqrt(16.0) + 3.0")
    func testNestedConstantFolding() throws {
        let expr = MathExpression.binary(
            .add,
            MathExpression.unary(.sqrt, .constant(16.0)),
            .constant(3.0)
        )

        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let expected: [Bytecode] = [.constant(7.0)]
        #expect(optimized == expected)
    }

    // MARK: - Preservation of Non-Optimizable Code

    @Test("Preserve non-optimizable: a + b")
    func testPreserveNonOptimizable() throws {
        let expr = MathExpression.binary(.add, .input(0), .input(1))
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        // Should not change - no optimization possible
        #expect(optimized == bytecode)
    }

    @Test("Preserve partial optimization: a + b + 5")
    func testPreservePartialOptimization() throws {
        // Can't optimize a + b, but whole expression stays the same
        let expr = MathExpression.binary(
            .add,
            MathExpression.binary(.add, .input(0), .input(1)),
            .constant(5.0)
        )

        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        // Should stay the same - no optimization opportunities
        let expected: [Bytecode] = [
            .input(0),
            .input(1),
            .add,
            .constant(5.0),
            .add
        ]
        #expect(optimized == expected)
    }

    // MARK: - Financial Model Optimizations

    @Test("Optimize financial model: revenue * 1.0 - 0.0")
    func testFinancialModelOptimization() throws {
        // revenue * 1.0 - 0.0 → revenue
        let expr = MathExpression.binary(
            .subtract,
            MathExpression.binary(.multiply, .input(0), .constant(1.0)),
            .constant(0.0)
        )

        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let expected: [Bytecode] = [.input(0)]
        #expect(optimized == expected)
    }

    @Test("Partial optimization: (a * b) * 1.0")
    func testPartialOptimization() throws {
        // (a * b) * 1.0 → a * b
        let expr = MathExpression.binary(
            .multiply,
            MathExpression.binary(.multiply, .input(0), .input(1)),
            .constant(1.0)
        )

        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let expected: [Bytecode] = [
            .input(0),
            .input(1),
            .multiply
        ]
        #expect(optimized == expected)
    }

    // MARK: - Edge Cases

    @Test("Optimization with negation: -0.0")
    func testNegationOfZero() throws {
        let expr = MathExpression.unary(.negate, .constant(0.0))
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        // -0.0 = 0.0 in floating point
        let expected: [Bytecode] = [.constant(-0.0)]
        #expect(optimized == expected)
    }

    @Test("No infinite loop on optimization")
    func testNoInfiniteLoop() throws {
        // Ensure optimizer terminates even with complex expressions
        let expr = MathExpression.binary(
            .add,
            MathExpression.binary(.multiply, .input(0), .input(1)),
            MathExpression.binary(.subtract, .input(2), .input(3))
        )

        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        // Should complete without hanging
        #expect(optimized.count > 0)
    }
}

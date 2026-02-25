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

    @Test("Algebraic simplification: a * 0 → 0")
    func testMultiplyByZero() throws {
        let expr = MathExpression.binary(.multiply, .input(0), .constant(0.0))
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let expected: [Bytecode] = [.constant(0.0)]
        #expect(optimized == expected)
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

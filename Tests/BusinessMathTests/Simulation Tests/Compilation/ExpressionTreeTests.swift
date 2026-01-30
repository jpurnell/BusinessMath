import Testing
import Foundation
@testable import BusinessMath

/// Tests for Expression Tree data structure
///
/// Validates the foundational AST representation that enables GPU compilation.
/// Expression trees are built by the ExpressionBuilder and compiled to bytecode.

// Disambiguate from Foundation.Expression (macOS 15+)
fileprivate typealias MathExpression = BusinessMath.Expression

@Suite("Expression Tree Tests")
struct ExpressionTreeTests {

    @Test("Binary operation creation")
    func testBinaryOperation() throws {
        let left = MathExpression.input(0)
        let right = MathExpression.input(1)
        let add = MathExpression.binary(.add, left, right)

        // Verify structure
        guard case .binary(let op, let l, let r) = add else {
            throw ExpressionTestError.unexpectedType("Expected binary operation")
        }

        #expect(op == .add)
        #expect(l == .input(0))
        #expect(r == .input(1))
    }

    @Test("Constant value creation")
    func testConstant() throws {
        let constant = MathExpression.constant(42.0)

        guard case .constant(let value) = constant else {
            throw ExpressionTestError.unexpectedType("Expected constant")
        }

        #expect(value == 42.0)
    }

    @Test("Input reference creation")
    func testInput() throws {
        let input = MathExpression.input(3)

        guard case .input(let index) = input else {
            throw ExpressionTestError.unexpectedType("Expected input")
        }

        #expect(index == 3)
    }

    @Test("Unary operation creation")
    func testUnaryOperation() throws {
        let operand = MathExpression.input(0)
        let negate = MathExpression.unary(.negate, operand)

        guard case .unary(let op, let inner) = negate else {
            throw ExpressionTestError.unexpectedType("Expected unary operation")
        }

        #expect(op == .negate)
        #expect(inner == .input(0))
    }

    @Test("Complex expression tree: (input[0] * input[1]) - input[2]")
    func testComplexExpression() throws {
        // Build: (input[0] * input[1]) - input[2]
        let expr = MathExpression.binary(
            .subtract,
            MathExpression.binary(
                .multiply,
                MathExpression.input(0),
                MathExpression.input(1)
            ),
            MathExpression.input(2)
        )

        // Verify top-level structure
        guard case .binary(let topOp, let leftExpr, let rightExpr) = expr else {
            throw ExpressionTestError.unexpectedType("Expected binary operation")
        }

        #expect(topOp == .subtract)

        // Verify left subtree (multiply)
        guard case .binary(let mulOp, let mul1, let mul2) = leftExpr else {
            throw ExpressionTestError.unexpectedType("Expected multiply operation")
        }

        #expect(mulOp == .multiply)
        #expect(mul1 == .input(0))
        #expect(mul2 == .input(1))

        // Verify right subtree
        #expect(rightExpr == .input(2))
    }

    @Test("Deeply nested expression")
    func testDeeplyNested() throws {
        // Build: ((a + b) * (c - d)) / e
        let expr = MathExpression.binary(
            .divide,
            MathExpression.binary(
                .multiply,
                MathExpression.binary(.add, .input(0), .input(1)),
                MathExpression.binary(.subtract, .input(2), .input(3))
            ),
            .input(4)
        )

        // Verify it's a divide at top level
        guard case .binary(.divide, _, _) = expr else {
            throw ExpressionTestError.unexpectedType("Expected divide operation")
        }

        // Just verify it compiles and has correct structure
        #expect(expr != .input(0))
    }

    @Test("Expression equality")
    func testEquality() throws {
        let expr1 = MathExpression.binary(.add, .input(0), .constant(5.0))
        let expr2 = MathExpression.binary(.add, .input(0), .constant(5.0))
        let expr3 = MathExpression.binary(.add, .input(0), .constant(6.0))

        #expect(expr1 == expr2)
        #expect(expr1 != expr3)
    }

    @Test("All binary operators")
    func testAllBinaryOperators() throws {
        let ops: [MathExpression.BinaryOp] = [
            .add, .subtract, .multiply, .divide,
            .power, .min, .max
        ]

        for op in ops {
            let expr = MathExpression.binary(op, .input(0), .input(1))

            guard case .binary(let actualOp, _, _) = expr else {
                throw ExpressionTestError.unexpectedType("Expected binary operation")
            }

            #expect(actualOp == op)
        }
    }

    @Test("All unary operators")
    func testAllUnaryOperators() throws {
        let ops: [MathExpression.UnaryOp] = [
            .negate, .abs, .sqrt, .log, .exp,
            .sin, .cos, .tan
        ]

        for op in ops {
            let expr = MathExpression.unary(op, .input(0))

            guard case .unary(let actualOp, _) = expr else {
                throw ExpressionTestError.unexpectedType("Expected unary operation")
            }

            #expect(actualOp == op)
        }
    }

    @Test("Expression with constants")
    func testMixedConstantsAndInputs() throws {
        // Build: input[0] * 1.5 + 100.0
        let expr = MathExpression.binary(
            .add,
            MathExpression.binary(.multiply, .input(0), .constant(1.5)),
            .constant(100.0)
        )

        guard case .binary(.add, let left, let right) = expr else {
            throw ExpressionTestError.unexpectedType("Expected add operation")
        }

        guard case .constant(100.0) = right else {
            throw ExpressionTestError.unexpectedType("Expected constant 100.0")
        }

        guard case .binary(.multiply, .input(0), .constant(1.5)) = left else {
            throw ExpressionTestError.unexpectedType("Expected multiply with constant 1.5")
        }

        // Success
        #expect(Bool(true))
    }
}

// MARK: - Test Errors

enum ExpressionTestError: Error {
    case unexpectedType(String)
}

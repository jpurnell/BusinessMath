import Testing
import Foundation
@testable import BusinessMath

/// Tests for ExpressionBuilder DSL
///
/// Validates the fluent API that enables natural Swift syntax for building
/// GPU-compilable mathematical expressions.
///
/// The ExpressionBuilder uses operator overloading to construct expression trees
/// that look like closures but can be compiled to GPU bytecode.

// Disambiguate from Foundation.Expression (macOS 15+)
fileprivate typealias MathExpression = BusinessMath.Expression

@Suite("Expression Builder Tests")
struct ExpressionBuilderTests {

    // MARK: - Basic Operators

    @Test("Addition operator: builder[0] + builder[1]")
    func testAddition() throws {
        let builder = ExpressionBuilder()
        let expr = builder[0] + builder[1]

        let expected = MathExpression.binary(.add, .input(0), .input(1))
        #expect(expr.expression == expected)
    }

    @Test("Subtraction operator: builder[0] - builder[1]")
    func testSubtraction() throws {
        let builder = ExpressionBuilder()
        let expr = builder[0] - builder[1]

        let expected = MathExpression.binary(.subtract, .input(0), .input(1))
        #expect(expr.expression == expected)
    }

    @Test("Multiplication operator: builder[0] * builder[1]")
    func testMultiplication() throws {
        let builder = ExpressionBuilder()
        let expr = builder[0] * builder[1]

        let expected = MathExpression.binary(.multiply, .input(0), .input(1))
        #expect(expr.expression == expected)
    }

    @Test("Division operator: builder[0] / builder[1]")
    func testDivision() throws {
        let builder = ExpressionBuilder()
        let expr = builder[0] / builder[1]

        let expected = MathExpression.binary(.divide, .input(0), .input(1))
        #expect(expr.expression == expected)
    }

    // MARK: - Compound Expressions

    @Test("Compound expression: (a * b) - c")
    func testCompoundExpression() throws {
        let builder = ExpressionBuilder()
        let expr = builder[0] * builder[1] - builder[2]

        let expected = MathExpression.binary(
            .subtract,
            MathExpression.binary(.multiply, .input(0), .input(1)),
            .input(2)
        )
        #expect(expr.expression == expected)
    }

    @Test("Complex expression: (a + b) * (c - d) / e")
    func testComplexExpression() throws {
        let builder = ExpressionBuilder()
        let expr = (builder[0] + builder[1]) * (builder[2] - builder[3]) / builder[4]

        // Verify structure: ((a + b) * (c - d)) / e
        guard case .binary(.divide, let numerator, let denominator) = expr.expression else {
            throw BuilderTestError.unexpectedStructure("Expected division at top level")
        }

        guard case .input(4) = denominator else {
            throw BuilderTestError.unexpectedStructure("Expected input[4] as denominator")
        }

        guard case .binary(.multiply, _, _) = numerator else {
            throw BuilderTestError.unexpectedStructure("Expected multiplication in numerator")
        }

        // Success
        #expect(Bool(true))
    }

    // MARK: - Constants

    @Test("Constant addition: builder[0] + 5.0")
    func testConstantAddition() throws {
        let builder = ExpressionBuilder()
        let expr = builder[0] + 5.0

        let expected = MathExpression.binary(.add, .input(0), .constant(5.0))
        #expect(expr.expression == expected)
    }

    @Test("Constant multiplication: builder[0] * 1.5")
    func testConstantMultiplication() throws {
        let builder = ExpressionBuilder()
        let expr = builder[0] * 1.5

        let expected = MathExpression.binary(.multiply, .input(0), .constant(1.5))
        #expect(expr.expression == expected)
    }

    @Test("Mixed constants: builder[0] * 1.5 + 100.0")
    func testMixedConstants() throws {
        let builder = ExpressionBuilder()
        let expr = builder[0] * 1.5 + 100.0

        // (input[0] * 1.5) + 100.0
        let expected = MathExpression.binary(
            .add,
            MathExpression.binary(.multiply, .input(0), .constant(1.5)),
            .constant(100.0)
        )
        #expect(expr.expression == expected)
    }

    @Test("Constant on left: 2.0 * builder[0]")
    func testConstantOnLeft() throws {
        let builder = ExpressionBuilder()
        let expr = 2.0 * builder[0]

        let expected = MathExpression.binary(.multiply, .constant(2.0), .input(0))
        #expect(expr.expression == expected)
    }

    // MARK: - Negation

    @Test("Negation: -builder[0]")
    func testNegation() throws {
        let builder = ExpressionBuilder()
        let expr = -builder[0]

        let expected = MathExpression.unary(.negate, .input(0))
        #expect(expr.expression == expected)
    }

    @Test("Double negation: -(-builder[0])")
    func testDoubleNegation() throws {
        let builder = ExpressionBuilder()
        let expr = -(-builder[0])

        let expected = MathExpression.unary(.negate, MathExpression.unary(.negate, .input(0)))
        #expect(expr.expression == expected)
    }

    // MARK: - Financial Models

    @Test("Financial model: revenue * price - costs")
    func testFinancialModel() throws {
        let builder = ExpressionBuilder()
        let revenue = builder[0]
        let price = builder[1]
        let costs = builder[2]

        let profit = revenue * price - costs

        let expected = MathExpression.binary(
            .subtract,
            MathExpression.binary(.multiply, .input(0), .input(1)),
            .input(2)
        )
        #expect(profit.expression == expected)
    }

    @Test("NPV model: -initial + (cashFlow / (1 + rate))")
    func testNPVModel() throws {
        let builder = ExpressionBuilder()
        let initial = builder[0]
        let cashFlow = builder[1]
        let rate = builder[2]

        let npv = -initial + cashFlow / (1.0 + rate)

        // Verify structure
        guard case .binary(.add, let negInitial, let discounted) = npv.expression else {
            throw BuilderTestError.unexpectedStructure("Expected addition at top level")
        }

        guard case .unary(.negate, .input(0)) = negInitial else {
            throw BuilderTestError.unexpectedStructure("Expected negated initial cost")
        }

        guard case .binary(.divide, .input(1), _) = discounted else {
            throw BuilderTestError.unexpectedStructure("Expected division for discounting")
        }

        // Success
        #expect(Bool(true))
    }

    // MARK: - Operator Precedence

    @Test("Precedence: a + b * c (should be a + (b * c))")
    func testOperatorPrecedence() throws {
        let builder = ExpressionBuilder()
        let expr = builder[0] + builder[1] * builder[2]

        // Swift's natural precedence: addition has lower precedence than multiplication
        // So this becomes: builder[0] + (builder[1] * builder[2])
        let expected = MathExpression.binary(
            .add,
            .input(0),
            MathExpression.binary(.multiply, .input(1), .input(2))
        )
        #expect(expr.expression == expected)
    }

    @Test("Precedence with parentheses: (a + b) * c")
    func testParenthesesPrecedence() throws {
        let builder = ExpressionBuilder()
        let expr = (builder[0] + builder[1]) * builder[2]

        let expected = MathExpression.binary(
            .multiply,
            MathExpression.binary(.add, .input(0), .input(1)),
            .input(2)
        )
        #expect(expr.expression == expected)
    }

    // MARK: - Edge Cases

    @Test("Single input reference")
    func testSingleInput() throws {
        let builder = ExpressionBuilder()
        let expr = builder[5]

        let expected = MathExpression.input(5)
        #expect(expr.expression == expected)
    }

    @Test("Chained operations: a - b - c (left-associative)")
    func testChainedSubtraction() throws {
        let builder = ExpressionBuilder()
        let expr = builder[0] - builder[1] - builder[2]

        // Left-associative: (a - b) - c
        let expected = MathExpression.binary(
            .subtract,
            MathExpression.binary(.subtract, .input(0), .input(1)),
            .input(2)
        )
        #expect(expr.expression == expected)
    }
}

// MARK: - Test Errors

enum BuilderTestError: Error {
    case unexpectedStructure(String)
}

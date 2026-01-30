import Testing
import Foundation
@testable import BusinessMath

/// Tests for Bytecode Compiler
///
/// Validates the compilation of expression trees to stack-based bytecode
/// that can be executed on GPU or CPU.

// Disambiguate from Foundation.Expression (macOS 15+)
fileprivate typealias MathExpression = BusinessMath.Expression

@Suite("Bytecode Compiler Tests")
struct BytecodeCompilerTests {

    // MARK: - Basic Operations

    @Test("Compile addition: a + b")
    func testAddition() throws {
        let expr = MathExpression.binary(.add, .input(0), .input(1))
        let bytecode = try BytecodeCompiler.compile(expr)

        let expected: [Bytecode] = [
            .input(0),
            .input(1),
            .add
        ]
        #expect(bytecode == expected)
    }

    @Test("Compile subtraction: a - b")
    func testSubtraction() throws {
        let expr = MathExpression.binary(.subtract, .input(0), .input(1))
        let bytecode = try BytecodeCompiler.compile(expr)

        let expected: [Bytecode] = [
            .input(0),
            .input(1),
            .subtract
        ]
        #expect(bytecode == expected)
    }

    @Test("Compile multiplication: a * b")
    func testMultiplication() throws {
        let expr = MathExpression.binary(.multiply, .input(0), .input(1))
        let bytecode = try BytecodeCompiler.compile(expr)

        let expected: [Bytecode] = [
            .input(0),
            .input(1),
            .multiply
        ]
        #expect(bytecode == expected)
    }

    @Test("Compile division: a / b")
    func testDivision() throws {
        let expr = MathExpression.binary(.divide, .input(0), .input(1))
        let bytecode = try BytecodeCompiler.compile(expr)

        let expected: [Bytecode] = [
            .input(0),
            .input(1),
            .divide
        ]
        #expect(bytecode == expected)
    }

    // MARK: - Compound Expressions

    @Test("Compile compound: (a * b) - c")
    func testCompoundExpression() throws {
        let expr = MathExpression.binary(
            .subtract,
            MathExpression.binary(.multiply, .input(0), .input(1)),
            .input(2)
        )
        let bytecode = try BytecodeCompiler.compile(expr)

        // Post-order traversal: left, right, operator
        let expected: [Bytecode] = [
            .input(0),
            .input(1),
            .multiply,
            .input(2),
            .subtract
        ]
        #expect(bytecode == expected)
    }

    @Test("Compile complex: ((a + b) * (c - d)) / e")
    func testComplexExpression() throws {
        let expr = MathExpression.binary(
            .divide,
            MathExpression.binary(
                .multiply,
                MathExpression.binary(.add, .input(0), .input(1)),
                MathExpression.binary(.subtract, .input(2), .input(3))
            ),
            .input(4)
        )
        let bytecode = try BytecodeCompiler.compile(expr)

        let expected: [Bytecode] = [
            .input(0),
            .input(1),
            .add,
            .input(2),
            .input(3),
            .subtract,
            .multiply,
            .input(4),
            .divide
        ]
        #expect(bytecode == expected)
    }

    // MARK: - Constants

    @Test("Compile constant: a * 1.5")
    func testConstant() throws {
        let expr = MathExpression.binary(.multiply, .input(0), .constant(1.5))
        let bytecode = try BytecodeCompiler.compile(expr)

        let expected: [Bytecode] = [
            .input(0),
            .constant(1.5),
            .multiply
        ]
        #expect(bytecode == expected)
    }

    @Test("Compile mixed constants: a * 1.5 + 100.0")
    func testMixedConstants() throws {
        let expr = MathExpression.binary(
            .add,
            MathExpression.binary(.multiply, .input(0), .constant(1.5)),
            .constant(100.0)
        )
        let bytecode = try BytecodeCompiler.compile(expr)

        let expected: [Bytecode] = [
            .input(0),
            .constant(1.5),
            .multiply,
            .constant(100.0),
            .add
        ]
        #expect(bytecode == expected)
    }

    // MARK: - Unary Operations

    @Test("Compile negation: -a")
    func testNegation() throws {
        let expr = MathExpression.unary(.negate, .input(0))
        let bytecode = try BytecodeCompiler.compile(expr)

        let expected: [Bytecode] = [
            .input(0),
            .negate
        ]
        #expect(bytecode == expected)
    }

    @Test("Compile sqrt: sqrt(a)")
    func testSqrt() throws {
        let expr = MathExpression.unary(.sqrt, .input(0))
        let bytecode = try BytecodeCompiler.compile(expr)

        let expected: [Bytecode] = [
            .input(0),
            .sqrt
        ]
        #expect(bytecode == expected)
    }

    @Test("Compile compound unary: -sqrt(a)")
    func testCompoundUnary() throws {
        let expr = MathExpression.unary(
            .negate,
            MathExpression.unary(.sqrt, .input(0))
        )
        let bytecode = try BytecodeCompiler.compile(expr)

        let expected: [Bytecode] = [
            .input(0),
            .sqrt,
            .negate
        ]
        #expect(bytecode == expected)
    }

    // MARK: - Financial Models

    @Test("Compile financial model: revenue * price - costs")
    func testFinancialModel() throws {
        let expr = MathExpression.binary(
            .subtract,
            MathExpression.binary(.multiply, .input(0), .input(1)),
            .input(2)
        )
        let bytecode = try BytecodeCompiler.compile(expr)

        let expected: [Bytecode] = [
            .input(0),      // revenue
            .input(1),      // price
            .multiply,      // revenue * price
            .input(2),      // costs
            .subtract       // (revenue * price) - costs
        ]
        #expect(bytecode == expected)
    }

    @Test("Compile complex financial: (revenue * price) - (costs * (1 + tax))")
    func testComplexFinancialModel() throws {
        let expr = MathExpression.binary(
            .subtract,
            MathExpression.binary(.multiply, .input(0), .input(1)),  // revenue * price
            MathExpression.binary(
                .multiply,
                .input(2),  // costs
                MathExpression.binary(.add, .constant(1.0), .input(3))  // 1 + tax
            )
        )

        let bytecode = try BytecodeCompiler.compile(expr)

        let expected: [Bytecode] = [
            .input(0),      // revenue
            .input(1),      // price
            .multiply,      // revenue * price
            .input(2),      // costs
            .constant(1.0), // 1.0
            .input(3),      // tax
            .add,           // 1.0 + tax
            .multiply,      // costs * (1 + tax)
            .subtract       // (revenue * price) - (costs * (1 + tax))
        ]
        #expect(bytecode == expected)
    }

    // MARK: - GPU Format Conversion

    @Test("Convert bytecode to GPU format: a + b")
    func testGPUBytecodeConversion() throws {
        let expr = MathExpression.binary(.add, .input(0), .input(1))
        let bytecode = try BytecodeCompiler.compile(expr)
        let gpuBytecode = BytecodeCompiler.toGPUFormat(bytecode)

        let expected: [(Int32, Int32, Float)] = [
            (4, 0, 0.0),  // INPUT 0
            (4, 1, 0.0),  // INPUT 1
            (0, 0, 0.0)   // ADD
        ]

        #expect(gpuBytecode.count == expected.count)
        for (actual, exp) in zip(gpuBytecode, expected) {
            #expect(actual.0 == exp.0)
            #expect(actual.1 == exp.1)
            #expect(abs(actual.2 - exp.2) < 0.001)
        }
    }

    @Test("Convert complex to GPU format: (a * b) - c")
    func testComplexGPUConversion() throws {
        let expr = MathExpression.binary(
            .subtract,
            MathExpression.binary(.multiply, .input(0), .input(1)),
            .input(2)
        )
        let bytecode = try BytecodeCompiler.compile(expr)
        let gpuBytecode = BytecodeCompiler.toGPUFormat(bytecode)

        let expected: [(Int32, Int32, Float)] = [
            (4, 0, 0.0),  // INPUT 0
            (4, 1, 0.0),  // INPUT 1
            (2, 0, 0.0),  // MUL
            (4, 2, 0.0),  // INPUT 2
            (1, 0, 0.0)   // SUB
        ]

        #expect(gpuBytecode.count == expected.count)
        for (actual, exp) in zip(gpuBytecode, expected) {
            #expect(actual.0 == exp.0)
            #expect(actual.1 == exp.1)
            #expect(abs(actual.2 - exp.2) < 0.001)
        }
    }

    @Test("Convert constant to GPU format: a * 1.5")
    func testConstantGPUConversion() throws {
        let expr = MathExpression.binary(.multiply, .input(0), .constant(1.5))
        let bytecode = try BytecodeCompiler.compile(expr)
        let gpuBytecode = BytecodeCompiler.toGPUFormat(bytecode)

        let expected: [(Int32, Int32, Float)] = [
            (4, 0, 0.0),    // INPUT 0
            (5, 0, 1.5),    // CONST 1.5
            (2, 0, 0.0)     // MUL
        ]

        #expect(gpuBytecode.count == expected.count)
        for (actual, exp) in zip(gpuBytecode, expected) {
            #expect(actual.0 == exp.0)
            #expect(actual.1 == exp.1)
            #expect(abs(actual.2 - exp.2) < 0.001)
        }
    }

    // MARK: - All Operations

    @Test("All binary operators compile")
    func testAllBinaryOperators() throws {
        let ops: [(MathExpression.BinaryOp, Bytecode)] = [
            (.add, .add),
            (.subtract, .subtract),
            (.multiply, .multiply),
            (.divide, .divide),
            (.power, .power),
            (.min, .min),
            (.max, .max)
        ]

        for (exprOp, bytecodeOp) in ops {
            let expr = MathExpression.binary(exprOp, .input(0), .input(1))
            let bytecode = try BytecodeCompiler.compile(expr)

            #expect(bytecode.count == 3)
            #expect(bytecode[0] == .input(0))
            #expect(bytecode[1] == .input(1))
            #expect(bytecode[2] == bytecodeOp)
        }
    }

    @Test("All unary operators compile")
    func testAllUnaryOperators() throws {
        let ops: [(MathExpression.UnaryOp, Bytecode)] = [
            (.negate, .negate),
            (.abs, .abs),
            (.sqrt, .sqrt),
            (.log, .log),
            (.exp, .exp),
            (.sin, .sin),
            (.cos, .cos),
            (.tan, .tan)
        ]

        for (exprOp, bytecodeOp) in ops {
            let expr = MathExpression.unary(exprOp, .input(0))
            let bytecode = try BytecodeCompiler.compile(expr)

            #expect(bytecode.count == 2)
            #expect(bytecode[0] == .input(0))
            #expect(bytecode[1] == bytecodeOp)
        }
    }
}

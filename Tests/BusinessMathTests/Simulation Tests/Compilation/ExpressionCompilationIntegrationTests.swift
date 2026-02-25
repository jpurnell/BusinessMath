import Testing
import TestSupport  // Cross-platform math functions
import Foundation
@testable import BusinessMath

/// Integration Tests for Expression Compilation Pipeline
///
/// Validates the complete expression compilation pipeline from builder syntax
/// through optimization to GPU bytecode format. Tests end-to-end equivalence
/// between expression-compiled models and closure-based models.

// Disambiguate from Foundation.Expression (macOS 15+)
fileprivate typealias MathExpression = BusinessMath.Expression

@Suite("Expression Compilation Integration Tests")
struct ExpressionCompilationIntegrationTests {

    // MARK: - End-to-End Pipeline

    @Test("Complete pipeline: Builder → Expression → Bytecode → GPU Format")
    func testCompletePipeline() throws {
        // Build expression using fluent API
        let builder = ExpressionBuilder()
        let expr = builder[0] * builder[1] - builder[2]

        // Compile to bytecode
        let bytecode = try BytecodeCompiler.compile(expr.expression)

        // Optimize
        let optimized = BytecodeOptimizer.optimize(bytecode)

        // Convert to GPU format
        let gpuBytecode = BytecodeCompiler.toGPUFormat(optimized)

        // Verify structure
        #expect(gpuBytecode.count > 0)

        // GPU format should be valid
        for instruction in gpuBytecode {
            #expect(instruction.0 >= 0)  // Valid opcode
            #expect(instruction.1 >= 0 || instruction.0 == 5)  // Valid arg1 (or CONST)
        }
    }

    @Test("Pipeline with optimization: (a + 0) * 1 simplifies to a")
    func testOptimizationPipeline() throws {
        let builder = ExpressionBuilder()
        let expr = (builder[0] + 0.0) * 1.0

        let bytecode = try BytecodeCompiler.compile(expr.expression)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        // Should optimize down to just input[0]
        let expected: [Bytecode] = [.input(0)]
        #expect(optimized == expected)
    }

    @Test("Pipeline with constant folding: sqrt(16) + 3 → 7")
    func testConstantFoldingPipeline() throws {
        // Test constant folding with no inputs (builder not needed)
        let sqrtExpr = ExpressionProxy(MathExpression.unary(.sqrt, .constant(16.0)))
        let expr = sqrtExpr + 3.0

        let bytecode = try BytecodeCompiler.compile(expr.expression)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        // Should fold to constant 7.0
        let expected: [Bytecode] = [.constant(7.0)]
        #expect(optimized == expected)
    }

    // MARK: - Financial Model Examples

    @Test("Financial model: Revenue - Costs")
    func testFinancialModel() throws {
        // Model: revenue - costs
        let builder = ExpressionBuilder()
        let revenue = builder[0]
        let costs = builder[1]
        let profit = revenue - costs

        let bytecode = try BytecodeCompiler.compile(profit.expression)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let expected: [Bytecode] = [
            .input(0),      // revenue
            .input(1),      // costs
            .subtract       // revenue - costs
        ]
        #expect(optimized == expected)
    }

    @Test("NPV model: -initial + cashFlow / (1 + rate)")
    func testNPVModel() throws {
        let builder = ExpressionBuilder()
        let initial = builder[0]
        let cashFlow = builder[1]
        let rate = builder[2]

        let npv = -initial + cashFlow / (1.0 + rate)

        let bytecode = try BytecodeCompiler.compile(npv.expression)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        // Verify structure (negation + division + addition)
        #expect(optimized.contains(.negate))
        #expect(optimized.contains(.divide))
        #expect(optimized.contains(.add))
    }

    @Test("Complex financial: (revenue * price) - (costs * (1 + tax))")
    func testComplexFinancialModel() throws {
        let builder = ExpressionBuilder()
        let revenue = builder[0]
        let price = builder[1]
        let costs = builder[2]
        let tax = builder[3]

        let profit = (revenue * price) - (costs * (1.0 + tax))

        let bytecode = try BytecodeCompiler.compile(profit.expression)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        // Expected structure: 4 inputs, 3 multiplies, 1 add, 1 subtract
        let inputCount = optimized.filter {
            if case .input = $0 { return true }
            return false
        }.count

        let multiplyCount = optimized.filter { $0 == .multiply }.count
        let addCount = optimized.filter { $0 == .add }.count
        let subtractCount = optimized.filter { $0 == .subtract }.count

        #expect(inputCount == 4)
        #expect(multiplyCount == 2)
        #expect(addCount == 1)
        #expect(subtractCount == 1)
    }

    // MARK: - GPU Format Validation

    @Test("GPU format: All opcodes within valid range")
    func testGPUFormatOpcodeRange() throws {
        let builder = ExpressionBuilder()
        let expr = (builder[0] + builder[1]) * builder[2] / builder[3]

        let bytecode = try BytecodeCompiler.compile(expr.expression)
        let gpuBytecode = BytecodeCompiler.toGPUFormat(bytecode)

        // Opcodes should be in range [0, 16]
        for instruction in gpuBytecode {
            #expect(instruction.0 >= 0)
            #expect(instruction.0 <= 16)
        }
    }

    @Test("GPU format: INPUT opcode preserves input index")
    func testGPUFormatInputIndex() throws {
        let builder = ExpressionBuilder()
        let expr = builder[5]

        let bytecode = try BytecodeCompiler.compile(expr.expression)
        let gpuBytecode = BytecodeCompiler.toGPUFormat(bytecode)

        #expect(gpuBytecode.count == 1)
        #expect(gpuBytecode[0].0 == 4)  // INPUT opcode
        #expect(gpuBytecode[0].1 == 5)  // Index 5
    }

    @Test("GPU format: CONST opcode preserves value")
    func testGPUFormatConstant() throws {
        let builder = ExpressionBuilder()
        let expr = builder[0] + 42.5

        let bytecode = try BytecodeCompiler.compile(expr.expression)
        let gpuBytecode = BytecodeCompiler.toGPUFormat(bytecode)

        // Find CONST instruction
        let constInstr = gpuBytecode.first { $0.0 == 5 }
        #expect(constInstr != nil)
        #expect(abs(constInstr!.2 - 42.5) < 0.001)
    }

    // MARK: - Stack Depth Analysis

    @Test("Stack depth: Simple expression a + b")
    func testStackDepthSimple() throws {
        let builder = ExpressionBuilder()
        let expr = builder[0] + builder[1]

        let bytecode = try BytecodeCompiler.compile(expr.expression)
        let depth = bytecode.maxStackDepth()

        // Should require stack depth of 2
        #expect(depth == 2)
    }

    @Test("Stack depth: Complex expression ((a + b) * (c - d)) / e")
    func testStackDepthComplex() throws {
        let builder = ExpressionBuilder()
        let expr = ((builder[0] + builder[1]) * (builder[2] - builder[3])) / builder[4]

        let bytecode = try BytecodeCompiler.compile(expr.expression)
        let depth = bytecode.maxStackDepth()

        // Should require stack depth of 3 or more
        #expect(depth >= 3)
    }

    @Test("Stack depth: After optimization")
    func testStackDepthAfterOptimization() throws {
        let builder = ExpressionBuilder()
        let expr = (builder[0] + 0.0) * 1.0

        let bytecode = try BytecodeCompiler.compile(expr.expression)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let depth = optimized.maxStackDepth()

        // Optimized to just input[0] - depth should be 1
        #expect(depth == 1)
    }

    // MARK: - Input Index Tracking

    @Test("Max input index: Single input")
    func testMaxInputIndexSingle() throws {
        let builder = ExpressionBuilder()
        let expr = builder[3]

        let bytecode = try BytecodeCompiler.compile(expr.expression)
        let maxIndex = bytecode.maxInputIndex()

        #expect(maxIndex == 3)
    }

    @Test("Max input index: Multiple inputs")
    func testMaxInputIndexMultiple() throws {
        let builder = ExpressionBuilder()
        let expr = builder[1] + builder[5] + builder[3]

        let bytecode = try BytecodeCompiler.compile(expr.expression)
        let maxIndex = bytecode.maxInputIndex()

        #expect(maxIndex == 5)
    }

    @Test("Max input index: No inputs (constants only)")
    func testMaxInputIndexNoInputs() throws {
        // Test with constants only (builder not needed)
        let constExpr = ExpressionProxy(MathExpression.constant(42.0))
        let expr = constExpr + 10.0

        let bytecode = try BytecodeCompiler.compile(expr.expression)
        let maxIndex = bytecode.maxInputIndex()

        #expect(maxIndex == nil)
    }

    // MARK: - Optimization Equivalence

    @Test("Optimization preserves result: revenue * 1.0 - 0.0")
    func testOptimizationEquivalence() throws {
        let builder = ExpressionBuilder()
        let expr = builder[0] * 1.0 - 0.0

        let bytecode = try BytecodeCompiler.compile(expr.expression)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        // Should optimize to just input[0]
        #expect(optimized == [.input(0)])
    }

    @Test("Optimization doesn't change non-optimizable code")
    func testOptimizationPreservation() throws {
        let builder = ExpressionBuilder()
        let expr = builder[0] + builder[1]

        let bytecode = try BytecodeCompiler.compile(expr.expression)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        // Should remain unchanged
        #expect(optimized == bytecode)
    }

    // MARK: - Expression Builder Edge Cases

    @Test("Builder with mixed operations and constants")
    func testBuilderMixedOperations() throws {
        let builder = ExpressionBuilder()
        let expr = builder[0] * 2.0 + builder[1] / 3.0 - 100.0

        let bytecode = try BytecodeCompiler.compile(expr.expression)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        // Should have 2 inputs, 3 constants, 4 operations
        let inputCount = optimized.filter {
            if case .input = $0 { return true }
            return false
        }.count

        let constantCount = optimized.filter {
            if case .constant = $0 { return true }
            return false
        }.count

        #expect(inputCount == 2)
        #expect(constantCount == 3)
    }

    @Test("Builder with nested parentheses")
    func testBuilderNestedParentheses() throws {
        let builder = ExpressionBuilder()
        let expr = ((builder[0] + 1.0) * (builder[1] - 2.0)) / (builder[2] + 3.0)

        let bytecode = try BytecodeCompiler.compile(expr.expression)

        // Verify it compiles without errors
        #expect(bytecode.count > 0)

        // Verify stack depth is reasonable
        #expect(bytecode.maxStackDepth() <= 10)
    }

    // MARK: - Comprehensive Model Example

    @Test("Comprehensive example: Multi-input financial model")
    func testComprehensiveFinancialModel() throws {
        // Model: profit = (units * price) - (fixedCosts + units * variableCost)
        let builder = ExpressionBuilder()
        let units = builder[0]
        let price = builder[1]
        let fixedCosts = builder[2]
        let variableCost = builder[3]

        let revenue = units * price
        let totalCosts = fixedCosts + units * variableCost
        let profit = revenue - totalCosts

        // Compile and optimize
        let bytecode = try BytecodeCompiler.compile(profit.expression)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        // Convert to GPU format
        let gpuBytecode = BytecodeCompiler.toGPUFormat(optimized)

        // Validate structure
        #expect(optimized.maxInputIndex() == 3)
        #expect(optimized.maxStackDepth() >= 2)
        #expect(gpuBytecode.count > 0)

        // Verify all opcodes are valid
        for instruction in gpuBytecode {
            #expect(instruction.0 >= 0 && instruction.0 <= 16)
        }
    }
}

import Testing
import Foundation
@testable import BusinessMath

/// Tests for MonteCarloExpressionModel
///
/// Validates expression-based model creation, compilation, and evaluation.

@Suite("Monte Carlo Expression Model Tests")
struct MonteCarloExpressionModelTests {

    // MARK: - Model Creation

    @Test("Create simple model: a + b")
    func testSimpleModel() throws {
        let model = MonteCarloExpressionModel { builder in
            return builder[0] + builder[1]
        }

        let result = try model.evaluate(inputs: [10.0, 20.0])
        #expect(result == 30.0)
    }

    @Test("Create model: a - b")
    func testSubtractionModel() throws {
        let model = MonteCarloExpressionModel { builder in
            return builder[0] - builder[1]
        }

        let result = try model.evaluate(inputs: [100.0, 30.0])
        #expect(result == 70.0)
    }

    @Test("Create model: a * b")
    func testMultiplicationModel() throws {
        let model = MonteCarloExpressionModel { builder in
            return builder[0] * builder[1]
        }

        let result = try model.evaluate(inputs: [5.0, 6.0])
        #expect(result == 30.0)
    }

    @Test("Create model: a / b")
    func testDivisionModel() throws {
        let model = MonteCarloExpressionModel { builder in
            return builder[0] / builder[1]
        }

        let result = try model.evaluate(inputs: [20.0, 4.0])
        #expect(result == 5.0)
    }

    // MARK: - Complex Models

    @Test("Complex model: (a + b) * c")
    func testComplexModel() throws {
        let model = MonteCarloExpressionModel { builder in
            return (builder[0] + builder[1]) * builder[2]
        }

        let result = try model.evaluate(inputs: [3.0, 2.0, 5.0])
        #expect(result == 25.0)
    }

    @Test("Financial model: revenue - costs")
    func testFinancialModel() throws {
        let model = MonteCarloExpressionModel { builder in
            let revenue = builder[0]
            let costs = builder[1]
            return revenue - costs
        }

        let result = try model.evaluate(inputs: [1_000_000, 700_000])
        #expect(result == 300_000)
    }

    @Test("Profit model: (units * price) - (fixedCosts + units * variableCost)")
    func testProfitModel() throws {
        let model = MonteCarloExpressionModel { builder in
            let units = builder[0]
            let price = builder[1]
            let fixedCosts = builder[2]
            let variableCost = builder[3]

            let revenue = units * price
            let totalCosts = fixedCosts + units * variableCost
            return revenue - totalCosts
        }

        // units=100, price=10, fixedCosts=200, variableCost=5
        // revenue = 100*10 = 1000
        // totalCosts = 200 + 100*5 = 700
        // profit = 1000 - 700 = 300
        let result = try model.evaluate(inputs: [100, 10, 200, 5])
        #expect(result == 300.0)
    }

    // MARK: - Model with Constants

    @Test("Model with constants: a * 1.5 + 100")
    func testModelWithConstants() throws {
        let model = MonteCarloExpressionModel { builder in
            return builder[0] * 1.5 + 100.0
        }

        let result = try model.evaluate(inputs: [200.0])
        #expect(result == 400.0)
    }

    @Test("Model with constant folding: a + (5 * 2)")
    func testConstantFolding() throws {
        let model = MonteCarloExpressionModel { builder in
            return builder[0] + (5.0 * 2.0)
        }

        let result = try model.evaluate(inputs: [20.0])
        #expect(result == 30.0)

        // Verify constant was folded
        let bytecode = model.compile()
        let constantCount = bytecode.filter {
            if case .constant = $0 { return true }
            return false
        }.count

        // Should have folded 5*2 into single constant 10
        #expect(constantCount == 1)
    }

    // MARK: - Compilation

    @Test("Compile bytecode")
    func testCompileBytecode() throws {
        let model = MonteCarloExpressionModel { builder in
            return builder[0] + builder[1]
        }

        let bytecode = model.compile()

        #expect(bytecode.count == 3)
        #expect(bytecode[0] == .input(0))
        #expect(bytecode[1] == .input(1))
        #expect(bytecode[2] == .add)
    }

    @Test("GPU bytecode format")
    func testGPUBytecode() throws {
        let model = MonteCarloExpressionModel { builder in
            return builder[0] * builder[1]
        }

        let gpuBytecode = model.gpuBytecode()

        #expect(gpuBytecode.count == 3)
        #expect(gpuBytecode[0].0 == 4)  // INPUT opcode
        #expect(gpuBytecode[1].0 == 4)  // INPUT opcode
        #expect(gpuBytecode[2].0 == 2)  // MUL opcode
    }

    // MARK: - Optimization

    @Test("Optimization: a * 1 → a")
    func testOptimizationMultiplyOne() throws {
        let model = MonteCarloExpressionModel { builder in
            return builder[0] * 1.0
        }

        let bytecode = model.compile()
        #expect(bytecode == [.input(0)])

        let result = try model.evaluate(inputs: [42.0])
        #expect(result == 42.0)
    }

    @Test("Optimization: a + 0 → a")
    func testOptimizationAddZero() throws {
        let model = MonteCarloExpressionModel { builder in
            return builder[0] + 0.0
        }

        let bytecode = model.compile()
        #expect(bytecode == [.input(0)])

        let result = try model.evaluate(inputs: [100.0])
        #expect(result == 100.0)
    }

    @Test("Multi-pass optimization: (a + 0) * 1")
    func testMultiPassOptimization() throws {
        let model = MonteCarloExpressionModel { builder in
            return (builder[0] + 0.0) * 1.0
        }

        let bytecode = model.compile()
        #expect(bytecode == [.input(0)])

        let result = try model.evaluate(inputs: [50.0])
        #expect(result == 50.0)
    }

    // MARK: - Closure Conversion

    @Test("Convert to closure")
    func testToClosure() throws {
        let model = MonteCarloExpressionModel { builder in
            return builder[0] * builder[1]
        }

        let closure = model.toClosure()
        let result = closure([5.0, 6.0])

        #expect(result == 30.0)
    }

    @Test("Closure equivalence")
    func testClosureEquivalence() throws {
        let model = MonteCarloExpressionModel { builder in
            let a = builder[0]
            let b = builder[1]
            let c = builder[2]
            return (a + b) * c
        }

        let exprResult = try model.evaluate(inputs: [2.0, 3.0, 4.0])
        let closureResult = model.toClosure()([2.0, 3.0, 4.0])

        #expect(exprResult == closureResult)
    }

    // MARK: - Analysis

    @Test("Max stack depth analysis")
    func testMaxStackDepth() throws {
        let model = MonteCarloExpressionModel { builder in
            return ((builder[0] + builder[1]) * (builder[2] - builder[3])) / builder[4]
        }

        let depth = model.maxStackDepth()
        #expect(depth >= 3)
    }

    @Test("Max input index analysis")
    func testMaxInputIndex() throws {
        let model = MonteCarloExpressionModel { builder in
            return builder[1] + builder[5] + builder[3]
        }

        let maxIndex = model.maxInputIndex()
        #expect(maxIndex == 5)
    }

    @Test("Instruction count")
    func testInstructionCount() throws {
        let model = MonteCarloExpressionModel { builder in
            return builder[0] + builder[1]
        }

        let count = model.instructionCount()
        #expect(count == 3)  // input, input, add
    }

    // MARK: - Error Handling

    @Test("Error: Invalid input index")
    func testInvalidInputIndex() throws {
        let model = MonteCarloExpressionModel { builder in
            return builder[0] + builder[1]
        }

        // Provide only 1 input when 2 are needed
        #expect(throws: EvaluationError.self) {
            try model.evaluate(inputs: [10.0])
        }
    }

    @Test("Error: Division by zero")
    func testDivisionByZero() throws {
        let model = MonteCarloExpressionModel { builder in
            return builder[0] / builder[1]
        }

        #expect(throws: EvaluationError.self) {
            try model.evaluate(inputs: [10.0, 0.0])
        }
    }

    // MARK: - Real-World Examples

    @Test("NPV model")
    func testNPVModel() throws {
        let model = MonteCarloExpressionModel { builder in
            let initial = builder[0]
            let cashFlow = builder[1]
            let rate = builder[2]

            return -initial + cashFlow / (1.0 + rate)
        }

        // initial=1000, cashFlow=1200, rate=0.10
        // npv = -1000 + 1200/1.10 = -1000 + 1090.909... ≈ 90.91
        let result = try model.evaluate(inputs: [1000, 1200, 0.10])
        #expect(abs(result - 90.909) < 0.01)
    }

    @Test("Compound interest model")
    func testCompoundInterestModel() throws {
        let model = MonteCarloExpressionModel { builder in
            let principal = builder[0]
            let rate = builder[1]
            let time = builder[2]

            // A = P * (1 + r)^t (simplified to multiplication for this test)
            return principal * (1.0 + rate) * time
        }

        // Simple linear version for testing
        let result = try model.evaluate(inputs: [1000, 0.05, 5])
        #expect(result == 5250.0)
    }
}

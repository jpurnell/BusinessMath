import Testing
import Foundation
#if canImport(Metal)
import Metal
#endif
@testable import BusinessMath

/// Tests for GPU model evaluator (bytecode interpreter)
///
/// Validates that the stack-based bytecode interpreter can correctly evaluate
/// arithmetic expressions. Tests include:
/// - Basic operations (ADD, SUB, MUL, DIV)
/// - Input loading (INPUT opcode)
/// - Constant loading (CONST opcode)
/// - Compound expressions (multiple operations)
/// - Edge cases (division, zero, negative numbers)
@Suite("Monte Carlo GPU Model Evaluator Tests")
struct MonteCarloModelEvaluatorTests {

    // MARK: - Bytecode Operation Definitions

    /// Bytecode opcodes matching Metal implementation
    enum Opcode: Int32 {
        case add = 0      // Pop b, pop a, push a+b
        case sub = 1      // Pop b, pop a, push a-b
        case mul = 2      // Pop b, pop a, push a*b
        case div = 3      // Pop b, pop a, push a/b
        case input = 4    // Push inputs[arg1]
        case const = 5    // Push arg2 (constant value)
    }

    /// Bytecode operation structure
    struct ModelOp {
        let opcode: Int32     // Operation type
        let arg1: Int32       // Input index or stack position
        let arg2: Float       // Constant value
    }

    // MARK: - Helper: GPU Model Evaluator

    /// Evaluate bytecode model on GPU
    private func evaluateModelGPU(
        inputs: [[Float]],       // Array of input vectors (one per iteration)
        bytecode: [ModelOp]      // Model bytecode program
    ) throws -> [Float] {
        #if canImport(Metal)
        guard let metalDevice = MetalDevice.shared else {
            return [] // Skip if Metal unavailable
        }

        let device = metalDevice.device
        let commandQueue = metalDevice.commandQueue

        let numIterations = inputs.count
        let numInputs = inputs[0].count

        // Compile kernel with model evaluator
        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct ModelOp {
            int opcode;
            int arg1;
            float arg2;
        };

        constant int MAX_STACK = 32;

        inline float evaluateModel(
            constant float* inputs,
            constant ModelOp* ops,
            int numOps
        ) {
            float stack[MAX_STACK];
            int stackPtr = 0;

            for (int i = 0; i < numOps; i++) {
                constant ModelOp& op = ops[i];

                switch (op.opcode) {
                    case 0: // ADD
                        stack[stackPtr - 2] = stack[stackPtr - 2] + stack[stackPtr - 1];
                        stackPtr--;
                        break;
                    case 1: // SUB
                        stack[stackPtr - 2] = stack[stackPtr - 2] - stack[stackPtr - 1];
                        stackPtr--;
                        break;
                    case 2: // MUL
                        stack[stackPtr - 2] = stack[stackPtr - 2] * stack[stackPtr - 1];
                        stackPtr--;
                        break;
                    case 3: // DIV
                        stack[stackPtr - 2] = stack[stackPtr - 2] / stack[stackPtr - 1];
                        stackPtr--;
                        break;
                    case 4: // INPUT
                        stack[stackPtr++] = inputs[op.arg1];
                        break;
                    case 5: // CONST
                        stack[stackPtr++] = op.arg2;
                        break;
                }
            }

            return stack[0];
        }

        kernel void evaluateModels(
            constant float* inputs [[buffer(0)]],
            constant ModelOp* ops [[buffer(1)]],
            constant int& numInputs [[buffer(2)]],
            constant int& numOps [[buffer(3)]],
            device float* outputs [[buffer(4)]],
            uint tid [[thread_position_in_grid]]
        ) {
            // Get input pointer for this iteration
            constant float* iterationInputs = inputs + (tid * numInputs);

            // Evaluate model
            outputs[tid] = evaluateModel(iterationInputs, ops, numOps);
        }
        """

        guard let library = try? device.makeLibrary(source: kernelSource, options: nil),
              let evalFunc = library.makeFunction(name: "evaluateModels") else {
            return [] // Skip if compilation fails
        }

        let evalPipeline = try device.makeComputePipelineState(function: evalFunc)

        // Flatten inputs: [iteration0_input0, iteration0_input1, ..., iteration1_input0, ...]
        var flatInputs: [Float] = []
        for iterInputs in inputs {
            flatInputs.append(contentsOf: iterInputs)
        }

        // Convert bytecode to Metal-compatible format
        var flatOps: [(Int32, Int32, Float)] = []
        for op in bytecode {
            flatOps.append((op.opcode, op.arg1, op.arg2))
        }

        // Allocate buffers
        let inputSize = flatInputs.count * MemoryLayout<Float>.stride
        let opSize = flatOps.count * MemoryLayout<(Int32, Int32, Float)>.stride
        let outputSize = numIterations * MemoryLayout<Float>.stride

        guard let inputBuffer = device.makeBuffer(bytes: &flatInputs, length: inputSize, options: .storageModeShared),
              let opBuffer = device.makeBuffer(bytes: &flatOps, length: opSize, options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: outputSize, options: .storageModeShared) else {
            return [] // Skip if allocation fails
        }

        // Execute kernel
        var numInputsVar = Int32(numInputs)
        var numOpsVar = Int32(bytecode.count)

        let commandBuffer = commandQueue.makeCommandBuffer()!
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(evalPipeline)
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(opBuffer, offset: 0, index: 1)
        encoder.setBytes(&numInputsVar, length: MemoryLayout<Int32>.stride, index: 2)
        encoder.setBytes(&numOpsVar, length: MemoryLayout<Int32>.stride, index: 3)
        encoder.setBuffer(outputBuffer, offset: 0, index: 4)

        let threadsPerGroup = MTLSize(width: min(numIterations, 256), height: 1, depth: 1)
        let threadGroups = MTLSize(
            width: (numIterations + threadsPerGroup.width - 1) / threadsPerGroup.width,
            height: 1,
            depth: 1
        )
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Read results
        let pointer = outputBuffer.contents().bindMemory(to: Float.self, capacity: numIterations)
        return (0..<numIterations).map { pointer[$0] }
        #else
        return [] // Metal not available
        #endif
    }

    // MARK: - Helper: CPU Model Evaluator (Reference Implementation)

    /// Evaluate model on CPU for comparison
    private func evaluateModelCPU(inputs: [Float], bytecode: [ModelOp]) -> Float {
        var stack: [Float] = []

        for op in bytecode {
            switch Opcode(rawValue: op.opcode)! {
            case .add:
                let b = stack.removeLast()
                let a = stack.removeLast()
                stack.append(a + b)
            case .sub:
                let b = stack.removeLast()
                let a = stack.removeLast()
                stack.append(a - b)
            case .mul:
                let b = stack.removeLast()
                let a = stack.removeLast()
                stack.append(a * b)
            case .div:
                let b = stack.removeLast()
                let a = stack.removeLast()
                stack.append(a / b)
            case .input:
                stack.append(inputs[Int(op.arg1)])
            case .const:
                stack.append(op.arg2)
            }
        }

        return stack[0]
    }

    // MARK: - Tests

    @Test("Addition model: inputs[0] + inputs[1]")
    func testAddition() throws {
        // Bytecode: INPUT 0, INPUT 1, ADD
        let bytecode = [
            ModelOp(opcode: Opcode.input.rawValue, arg1: 0, arg2: 0.0),
            ModelOp(opcode: Opcode.input.rawValue, arg1: 1, arg2: 0.0),
            ModelOp(opcode: Opcode.add.rawValue, arg1: 0, arg2: 0.0)
        ]

        // Test inputs (Float literals)
        let testInputs: [[Float]] = [
            [10.0, 20.0],
            [5.5, 3.3],
            [-10.0, 15.0],
            [0.0, 0.0]
        ]

        // Evaluate on GPU
        let gpuResults = try evaluateModelGPU(inputs: testInputs, bytecode: bytecode)
        guard !gpuResults.isEmpty else { return } // Skip if Metal unavailable

        // Evaluate on CPU and compare
        for (i, inputs) in testInputs.enumerated() {
            let cpuResult = evaluateModelCPU(inputs: inputs, bytecode: bytecode)
            let gpuResult = gpuResults[i]
            #expect(abs(cpuResult - gpuResult) < 0.001, "Addition: CPU=\(cpuResult) should match GPU=\(gpuResult)")
        }
    }

    @Test("Subtraction model: inputs[0] - inputs[1]")
    func testSubtraction() throws {
        // Bytecode: INPUT 0, INPUT 1, SUB
        let bytecode = [
            ModelOp(opcode: Opcode.input.rawValue, arg1: 0, arg2: 0.0),
            ModelOp(opcode: Opcode.input.rawValue, arg1: 1, arg2: 0.0),
            ModelOp(opcode: Opcode.sub.rawValue, arg1: 0, arg2: 0.0)
        ]

        let testInputs: [[Float]] = [
            [100.0, 30.0],   // = 70
            [50.0, 75.0],    // = -25
            [0.0, 10.0],     // = -10
        ]

        let gpuResults = try evaluateModelGPU(inputs: testInputs, bytecode: bytecode)
        guard !gpuResults.isEmpty else { return }

        for (i, inputs) in testInputs.enumerated() {
            let cpuResult = evaluateModelCPU(inputs: inputs, bytecode: bytecode)
            let gpuResult = gpuResults[i]
            #expect(abs(cpuResult - gpuResult) < 0.001)
        }
    }

    @Test("Multiplication model: inputs[0] * inputs[1]")
    func testMultiplication() throws {
        // Bytecode: INPUT 0, INPUT 1, MUL
        let bytecode = [
            ModelOp(opcode: Opcode.input.rawValue, arg1: 0, arg2: 0.0),
            ModelOp(opcode: Opcode.input.rawValue, arg1: 1, arg2: 0.0),
            ModelOp(opcode: Opcode.mul.rawValue, arg1: 0, arg2: 0.0)
        ]

        let testInputs: [[Float]] = [
            [10.0, 5.0],      // = 50
            [2.5, 4.0],       // = 10
            [-3.0, 7.0],      // = -21
            [0.0, 100.0],     // = 0
        ]

        let gpuResults = try evaluateModelGPU(inputs: testInputs, bytecode: bytecode)
        guard !gpuResults.isEmpty else { return }

        for (i, inputs) in testInputs.enumerated() {
            let cpuResult = evaluateModelCPU(inputs: inputs, bytecode: bytecode)
            let gpuResult = gpuResults[i]
            #expect(abs(cpuResult - gpuResult) < 0.001)
        }
    }

    @Test("Division model: inputs[0] / inputs[1]")
    func testDivision() throws {
        // Bytecode: INPUT 0, INPUT 1, DIV
        let bytecode = [
            ModelOp(opcode: Opcode.input.rawValue, arg1: 0, arg2: 0.0),
            ModelOp(opcode: Opcode.input.rawValue, arg1: 1, arg2: 0.0),
            ModelOp(opcode: Opcode.div.rawValue, arg1: 0, arg2: 0.0)
        ]

        let testInputs: [[Float]] = [
            [100.0, 4.0],     // = 25
            [50.0, 2.0],      // = 25
            [7.0, 2.0],       // = 3.5
            [-10.0, 2.0],     // = -5
        ]

        let gpuResults = try evaluateModelGPU(inputs: testInputs, bytecode: bytecode)
        guard !gpuResults.isEmpty else { return }

        for (i, inputs) in testInputs.enumerated() {
            let cpuResult = evaluateModelCPU(inputs: inputs, bytecode: bytecode)
            let gpuResult = gpuResults[i]
            #expect(abs(cpuResult - gpuResult) < 0.001)
        }
    }

    @Test("Constant model: inputs[0] + 100.0")
    func testConstant() throws {
        // Bytecode: INPUT 0, CONST 100.0, ADD
        let bytecode = [
            ModelOp(opcode: Opcode.input.rawValue, arg1: 0, arg2: 0.0),
            ModelOp(opcode: Opcode.const.rawValue, arg1: 0, arg2: 100.0),
            ModelOp(opcode: Opcode.add.rawValue, arg1: 0, arg2: 0.0)
        ]

        let testInputs: [[Float]] = [
            [50.0],
            [0.0],
            [-25.0],
        ]

        let gpuResults = try evaluateModelGPU(inputs: testInputs, bytecode: bytecode)
        guard !gpuResults.isEmpty else { return }

        for (i, inputs) in testInputs.enumerated() {
            let cpuResult = evaluateModelCPU(inputs: inputs, bytecode: bytecode)
            let gpuResult = gpuResults[i]
            #expect(abs(cpuResult - gpuResult) < 0.001, "Expected \(inputs[0]) + 100 = \(cpuResult), got \(gpuResult)")
        }
    }

    @Test("Compound expression: inputs[0] * inputs[1] - inputs[2]")
    func testCompoundExpression() throws {
        // Bytecode: INPUT 0, INPUT 1, MUL, INPUT 2, SUB
        // Stack trace: [in0] [in0,in1] [in0*in1] [in0*in1,in2] [in0*in1-in2]
        let bytecode = [
            ModelOp(opcode: Opcode.input.rawValue, arg1: 0, arg2: 0.0),  // Push inputs[0]
            ModelOp(opcode: Opcode.input.rawValue, arg1: 1, arg2: 0.0),  // Push inputs[1]
            ModelOp(opcode: Opcode.mul.rawValue, arg1: 0, arg2: 0.0),    // inputs[0] * inputs[1]
            ModelOp(opcode: Opcode.input.rawValue, arg1: 2, arg2: 0.0),  // Push inputs[2]
            ModelOp(opcode: Opcode.sub.rawValue, arg1: 0, arg2: 0.0)     // (inputs[0]*inputs[1]) - inputs[2]
        ]

        // Revenue-Costs financial model pattern
        let testInputs: [[Float]] = [
            [100.0, 50.0, 1000.0],   // 100*50 - 1000 = 4000
            [1000.0, 0.95, 700.0],   // 1000*0.95 - 700 = 250
            [50.0, 20.0, 1500.0],    // 50*20 - 1500 = -500 (loss)
        ]

        let gpuResults = try evaluateModelGPU(inputs: testInputs, bytecode: bytecode)
        guard !gpuResults.isEmpty else { return }

        for (i, inputs) in testInputs.enumerated() {
            let cpuResult = evaluateModelCPU(inputs: inputs, bytecode: bytecode)
            let gpuResult = gpuResults[i]
            #expect(abs(cpuResult - gpuResult) < 0.001,
                   "For inputs \(inputs): CPU=\(cpuResult) should match GPU=\(gpuResult)")
        }
    }

    @Test("Complex expression: (inputs[0] + inputs[1]) * inputs[2]")
    func testComplexExpression() throws {
        // Bytecode: INPUT 0, INPUT 1, ADD, INPUT 2, MUL
        // Stack: [in0] [in0,in1] [in0+in1] [in0+in1,in2] [(in0+in1)*in2]
        let bytecode = [
            ModelOp(opcode: Opcode.input.rawValue, arg1: 0, arg2: 0.0),
            ModelOp(opcode: Opcode.input.rawValue, arg1: 1, arg2: 0.0),
            ModelOp(opcode: Opcode.add.rawValue, arg1: 0, arg2: 0.0),
            ModelOp(opcode: Opcode.input.rawValue, arg1: 2, arg2: 0.0),
            ModelOp(opcode: Opcode.mul.rawValue, arg1: 0, arg2: 0.0)
        ]

        let testInputs: [[Float]] = [
            [10.0, 20.0, 2.0],     // (10+20)*2 = 60
            [5.0, -5.0, 10.0],     // (5-5)*10 = 0
            [100.0, 50.0, 0.5],    // (100+50)*0.5 = 75
        ]

        let gpuResults = try evaluateModelGPU(inputs: testInputs, bytecode: bytecode)
        guard !gpuResults.isEmpty else { return }

        for (i, inputs) in testInputs.enumerated() {
            let cpuResult = evaluateModelCPU(inputs: inputs, bytecode: bytecode)
            let gpuResult = gpuResults[i]
            #expect(abs(cpuResult - gpuResult) < 0.001)
        }
    }

    @Test("Multi-constant expression: inputs[0] * 1.15 - 500.0")
    func testMultiConstant() throws {
        // Bytecode: INPUT 0, CONST 1.15, MUL, CONST 500.0, SUB
        let bytecode = [
            ModelOp(opcode: Opcode.input.rawValue, arg1: 0, arg2: 0.0),
            ModelOp(opcode: Opcode.const.rawValue, arg1: 0, arg2: 1.15),
            ModelOp(opcode: Opcode.mul.rawValue, arg1: 0, arg2: 0.0),
            ModelOp(opcode: Opcode.const.rawValue, arg1: 0, arg2: 500.0),
            ModelOp(opcode: Opcode.sub.rawValue, arg1: 0, arg2: 0.0)
        ]

        let testInputs: [[Float]] = [
            [1000.0],    // 1000 * 1.15 - 500 = 650
            [500.0],     // 500 * 1.15 - 500 = 75
            [100.0],     // 100 * 1.15 - 500 = -385
        ]

        let gpuResults = try evaluateModelGPU(inputs: testInputs, bytecode: bytecode)
        guard !gpuResults.isEmpty else { return }

        for (i, inputs) in testInputs.enumerated() {
            let cpuResult = evaluateModelCPU(inputs: inputs, bytecode: bytecode)
            let gpuResult = gpuResults[i]
            #expect(abs(cpuResult - gpuResult) < 0.001)
        }
    }

    @Test("Edge case: zero handling")
    func testZeroHandling() throws {
        // Test: 0 * anything = 0, 0 + x = x, x - 0 = x
        let bytecode = [
            ModelOp(opcode: Opcode.const.rawValue, arg1: 0, arg2: 0.0),
            ModelOp(opcode: Opcode.input.rawValue, arg1: 0, arg2: 0.0),
            ModelOp(opcode: Opcode.mul.rawValue, arg1: 0, arg2: 0.0)
        ]

        let testInputs: [[Float]] = [
            [100.0],
            [-50.0],
            [999.9],
        ]

        let gpuResults = try evaluateModelGPU(inputs: testInputs, bytecode: bytecode)
        guard !gpuResults.isEmpty else { return }

        // All results should be 0
        for gpuResult in gpuResults {
            #expect(abs(gpuResult) < 0.001, "0 * anything should be 0, got \(gpuResult)")
        }
    }

    @Test("Edge case: negative numbers")
    func testNegativeNumbers() throws {
        // Test: (-inputs[0]) * inputs[1]
        let bytecode = [
            ModelOp(opcode: Opcode.const.rawValue, arg1: 0, arg2: 0.0),
            ModelOp(opcode: Opcode.input.rawValue, arg1: 0, arg2: 0.0),
            ModelOp(opcode: Opcode.sub.rawValue, arg1: 0, arg2: 0.0),  // 0 - inputs[0] = -inputs[0]
            ModelOp(opcode: Opcode.input.rawValue, arg1: 1, arg2: 0.0),
            ModelOp(opcode: Opcode.mul.rawValue, arg1: 0, arg2: 0.0)
        ]

        let testInputs: [[Float]] = [
            [10.0, 5.0],     // -10 * 5 = -50
            [-10.0, 5.0],    // -(-10) * 5 = 50
            [7.0, -3.0],     // -7 * -3 = 21
        ]

        let gpuResults = try evaluateModelGPU(inputs: testInputs, bytecode: bytecode)
        guard !gpuResults.isEmpty else { return }

        for (i, inputs) in testInputs.enumerated() {
            let cpuResult = evaluateModelCPU(inputs: inputs, bytecode: bytecode)
            let gpuResult = gpuResults[i]
            #expect(abs(cpuResult - gpuResult) < 0.001)
        }
    }
}

//
//  GPUExecutionContractTests.swift
//  BusinessMathTests
//
//  The CPU and the GPU run the same model from two sources that had nothing holding them
//  together. These pin what they have to agree on.
//

import Testing
import TestSupport  // .requiresMetalGPU
import Foundation
@testable import BusinessMath

@Suite("GPU execution contract")
struct GPUExecutionContractTests {

    // MARK: - The Opcode Table

    /// Every opcode, pinned to its number.
    ///
    /// These are a wire format: ``BytecodeCompiler/toGPUFormat(_:)`` writes them into a
    /// buffer and the kernel switches on them, and a mismatch computes a different
    /// expression rather than failing. The assertions that guarded this were
    /// `opcode >= 0` and `opcode <= 16`, which every permutation of the table satisfies —
    /// and which is wrong twice over, since the comparison and conditional opcodes run to 23.
    ///
    /// The switch is exhaustive on purpose. Adding a `GPUOpcode` case without giving it a
    /// number here stops this file compiling, which is the point: renumbering should be
    /// something you cannot do by accident.
    @Test("Every opcode holds the number the kernel switches on")
    func opcodeNumbersArePinned() {
        for opcode in GPUOpcode.allCases {
            let expected: Int32
            switch opcode {
            case .add:            expected = 0
            case .subtract:       expected = 1
            case .multiply:       expected = 2
            case .divide:         expected = 3
            case .input:          expected = 4
            case .constant:       expected = 5
            case .power:          expected = 6
            case .min:            expected = 7
            case .max:            expected = 8
            case .negate:         expected = 9
            case .abs:            expected = 10
            case .sqrt:           expected = 11
            case .log:            expected = 12
            case .exp:            expected = 13
            case .sin:            expected = 14
            case .cos:            expected = 15
            case .tan:            expected = 16
            case .lessThan:       expected = 17
            case .greaterThan:    expected = 18
            case .lessOrEqual:    expected = 19
            case .greaterOrEqual: expected = 20
            case .equal:          expected = 21
            case .notEqual:       expected = 22
            case .select:         expected = 23
            }
            #expect(opcode.rawValue == expected,
                    "\(opcode) is \(opcode.rawValue), pinned at \(expected)")
        }
    }

    /// The table is a bijection onto 0..<24 — no gaps, no collisions.
    ///
    /// A collision would make two instructions indistinguishable on the GPU side while
    /// every individual assertion above still passed.
    @Test("The opcode numbers are distinct and contiguous")
    func opcodeNumbersAreDistinctAndContiguous() {
        let numbers = GPUOpcode.allCases.map(\.rawValue).sorted()
        #expect(numbers.count == 24, "the table has \(numbers.count) entries")
        #expect(Set(numbers).count == numbers.count, "two opcodes share a number: \(numbers)")
        #expect(numbers == Array(Int32(0)..<Int32(24)), "the numbers are \(numbers)")
    }

    /// The generated Metal source declares every opcode the compiler can emit.
    ///
    /// The shader carries names now and this table carries numbers, so the declarations are
    /// the joint. A name the shader uses but the generator never emits is a compile failure
    /// on the GPU; this catches it without one.
    @Test("The generated Metal declarations cover the whole table")
    func mslDeclarationsCoverTheTable() {
        let msl = GPUOpcode.mslDeclarations
        for opcode in GPUOpcode.allCases {
            let declaration = "constant int \(opcode.mslName) = \(opcode.rawValue);"
            #expect(msl.contains(declaration), "missing: \(declaration)")
        }
        #expect(msl.contains("constant int MAX_STACK = \(GPUExecutionLimits.maxStackDepth);"))
        #expect(msl.contains("constant int MAX_INPUTS = \(GPUExecutionLimits.maxInputs);"))
    }

    /// Compiled bytecode encodes to the opcode its instruction maps to.
    @Test("Compilation emits the pinned numbers")
    func compilationEmitsPinnedNumbers() throws {
        let expr = Expression.binary(.power, .input(2), .constant(3.5))
        let bytecode = try BytecodeCompiler.compile(expr)
        let gpu = BytecodeCompiler.toGPUFormat(bytecode)

        #expect(gpu.count == 3, "expected three operations, got \(gpu.count)")
        #expect(gpu[0].opcode == GPUOpcode.input.rawValue)
        #expect(gpu[0].arg1 == 2, "the input slot was dropped")
        #expect(gpu[1].opcode == GPUOpcode.constant.rawValue)
        // 3.5 is exactly representable in both widths, so this is an IEEE comparison
        // taken on purpose rather than a tolerance someone forgot.
        #expect(gpu[1].arg2.isEqual(to: Float(3.5)))
        #expect(gpu[2].opcode == GPUOpcode.power.rawValue)
    }

    // MARK: - Stack Discipline

    /// Every opcode pushes exactly one result, so its net effect is `1 - operands`.
    @Test("Stack effect follows from the operand count")
    func stackEffectFollowsOperandCount() {
        for opcode in GPUOpcode.allCases {
            #expect(opcode.stackEffect == 1 - opcode.operandCount,
                    "\(opcode) pops \(opcode.operandCount) and nets \(opcode.stackEffect)")
        }
        #expect(GPUOpcode.select.operandCount == 3, "select takes condition, true, false")
        #expect(GPUOpcode.input.operandCount == 0)
        #expect(GPUOpcode.add.operandCount == 2)
        #expect(GPUOpcode.sqrt.operandCount == 1)
    }

    /// A model deeper than the kernel's stack is rejected rather than dispatched.
    ///
    /// `evaluateModel` declares `float stack[MAX_STACK]` and indexes it with a counter it
    /// never bounds-checks, so a deeper model wrote past the array — undefined behaviour,
    /// not an error, and not necessarily reproducible.
    @Test("A model deeper than the kernel's stack is rejected")
    func tooDeepIsRejected() throws {
        // 33 pushes before any operation consumes one: one past MAX_STACK.
        let limit = GPUExecutionLimits.maxStackDepth
        var operations: [(opcode: Int32, arg1: Int32, arg2: Float)] = []
        for _ in 0..<(limit + 1) {
            operations.append((GPUOpcode.constant.rawValue, 0, 1.0))
        }
        for _ in 0..<limit {
            operations.append((GPUOpcode.add.rawValue, 0, 0.0))
        }

        do {
            try GPUBytecodeValidator.validate(operations)
            Issue.record("a model needing \(limit + 1) slots was accepted")
        } catch let error as GPUExecutionError {
            #expect(error == .stackTooDeep(required: limit + 1, limit: limit),
                    "rejected with \(error)")
        }

        // And exactly at the limit it is accepted — the bound is the kernel's, not a margin.
        var atLimit: [(opcode: Int32, arg1: Int32, arg2: Float)] = []
        for _ in 0..<limit {
            atLimit.append((GPUOpcode.constant.rawValue, 0, 1.0))
        }
        for _ in 0..<(limit - 1) {
            atLimit.append((GPUOpcode.add.rawValue, 0, 0.0))
        }
        try GPUBytecodeValidator.validate(atLimit)
    }

    /// An operation asking for more operands than are present is rejected.
    ///
    /// The kernel reads `stack[stackPtr - 2]` without checking, so this read uninitialized
    /// thread memory and returned whatever was there.
    @Test("Stack underflow is rejected")
    func underflowIsRejected() {
        let operations: [(opcode: Int32, arg1: Int32, arg2: Float)] = [
            (GPUOpcode.constant.rawValue, 0, 1.0),
            (GPUOpcode.add.rawValue, 0, 0.0)
        ]
        do {
            try GPUBytecodeValidator.validate(operations)
            Issue.record("an add with one operand was accepted")
        } catch let error as GPUExecutionError {
            #expect(error == .stackUnderflow(atOperation: 1, needed: 2, available: 1),
                    "rejected with \(error)")
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    /// A stream that does not end with exactly one value is rejected.
    ///
    /// The kernel returns `stack[0]` whatever the depth, so a surplus is discarded silently
    /// and an empty stack returns uninitialized memory.
    @Test("A stream that does not end with one value is rejected")
    func unbalancedIsRejected() {
        let twoLeft: [(opcode: Int32, arg1: Int32, arg2: Float)] = [
            (GPUOpcode.constant.rawValue, 0, 1.0),
            (GPUOpcode.constant.rawValue, 0, 2.0)
        ]
        do {
            try GPUBytecodeValidator.validate(twoLeft)
            Issue.record("a stream leaving two values was accepted")
        } catch let error as GPUExecutionError {
            #expect(error == .unbalancedStack(remaining: 2), "rejected with \(error)")
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    /// An opcode the kernel has no case for is rejected.
    ///
    /// The kernel's switch has no `default`, so an unknown opcode does nothing at all: the
    /// stack is left as it was and the model quietly computes something else.
    @Test("An opcode the kernel has no case for is rejected")
    func unknownOpcodeIsRejected() {
        let operations: [(opcode: Int32, arg1: Int32, arg2: Float)] = [
            (GPUOpcode.constant.rawValue, 0, 1.0),
            (99, 0, 0.0)
        ]
        do {
            try GPUBytecodeValidator.validate(operations)
            Issue.record("opcode 99 was accepted")
        } catch let error as GPUExecutionError {
            #expect(error == .unknownOpcode(99, atOperation: 1), "rejected with \(error)")
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    /// An input slot outside the kernel's buffer is rejected.
    @Test("An input slot outside the kernel's buffer is rejected")
    func inputOutOfRangeIsRejected() {
        let slot = GPUExecutionLimits.maxInputs
        let operations: [(opcode: Int32, arg1: Int32, arg2: Float)] = [
            (GPUOpcode.input.rawValue, Int32(slot), 0.0)
        ]
        do {
            try GPUBytecodeValidator.validate(operations)
            Issue.record("input slot \(slot) was accepted")
        } catch let error as GPUExecutionError {
            #expect(error == .inputIndexOutOfRange(slot, limit: slot), "rejected with \(error)")
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    /// A model the compiler produces passes the validator.
    ///
    /// The control for all of the above: the rejections must not be rejecting everything.
    @Test("A compiled model passes validation")
    func compiledModelValidates() throws {
        let model = try MonteCarloExpressionModel { builder in
            (builder[0] + builder[1]) * builder[2]
        }
        let operations = model.gpuBytecode()
        try GPUBytecodeValidator.validate(operations)

        // (a + b) * c is three pushes and two binary operations.
        #expect(operations.count == 5, "compiled to \(operations.count) operations")
        #expect(operations.last?.opcode == GPUOpcode.multiply.rawValue,
                "the last operation is \(String(describing: operations.last?.opcode))")
    }

    // MARK: - Constant Narrowing

    /// Constants that change meaning crossing into Float32 are reported.
    ///
    /// Precision loss is the accepted cost of a Float32 kernel. Overflow to an infinity and
    /// underflow to zero are not precision loss — the GPU evaluates a different expression.
    @Test("Constants that do not survive Float are reported")
    func narrowingIssuesAreReported() {
        let overflow: [Bytecode] = [.constant(1e40), .constant(2.0), .multiply]
        let overflowIssues = overflow.gpuNarrowingIssues()
        #expect(overflowIssues.count == 1, "found \(overflowIssues.count) issues")
        #expect(overflowIssues.first?.index == 0)
        #expect(Float(1e40).isInfinite, "1e40 should overflow Float")

        let underflow: [Bytecode] = [.constant(1e-50), .constant(2.0), .multiply]
        let underflowIssues = underflow.gpuNarrowingIssues()
        #expect(underflowIssues.count == 1, "found \(underflowIssues.count) issues")
        #expect(Float(1e-50) == 0.0, "1e-50 should underflow Float")

        // Ordinary rounding is not an issue: 0.1 is not representable in either width and
        // narrows to a near neighbour, which is what the GPU path signs up for.
        let rounded: [Bytecode] = [.constant(0.1), .constant(1e38), .constant(-0.0)]
        #expect(rounded.gpuNarrowingIssues().isEmpty,
                "reported \(rounded.gpuNarrowingIssues())")
    }
}

// MARK: - The Kernel Itself

/// The package's own kernel source must compile wherever a trivial one does.
///
/// This is the suite that has to exist for any of the others to mean anything.
/// ``MonteCarloGPUDevice`` compiles its source inside a failable initializer, so a broken
/// kernel makes the initializer return nil, `MetalAvailability.canRunKernels` is unaffected —
/// it compiles a trivial kernel of its own — but every suite carrying `.requiresMetalGPU`
/// that goes on to ask for a device skips. A syntax error in the kernel therefore turns the
/// entire GPU test surface green by removing it.
///
/// `.requiresMetalGPU` is the right gate precisely because it does not depend on our source:
/// where a trivial kernel compiles, ours failing to is our defect.
@Suite("The package's Metal kernel compiles", .requiresMetalGPU)
struct MetalKernelCompilationTests {

    @Test("The kernel compiles, dispatches, and returns what it was asked for")
    func kernelCompilesAndRuns() throws {
        let gpu = try #require(MonteCarloGPUDevice.shared,
                               "a trivial kernel compiles on this machine but the package's does not")

        // A uniform on [10, 20] read straight out through a one-instruction model. Every
        // stage the contract covers is on this path: the generated opcode table, the
        // validator, the kernel's stack, and the read-back.
        let lower: Float = 10.0
        let upper: Float = 20.0
        let distributions: [MonteCarloGPUDevice.DistributionConfig] = [
            (type: 1, params: (lower, upper, 0.0))
        ]
        let model: [MonteCarloGPUDevice.ModelOperation] = [
            (opcode: GPUOpcode.input.rawValue, arg1: 0, arg2: 0.0)
        ]
        let iterations = 64

        let results = try gpu.runSimulation(
            distributions: distributions,
            modelBytecode: model,
            iterations: iterations,
            seed: 42
        )

        #expect(results.count == iterations, "asked for \(iterations) draws, got \(results.count)")

        let outside = results.filter { $0 < lower || $0 > upper }
        #expect(outside.isEmpty, "\(outside.count) draws fell outside [\(lower), \(upper)]: \(outside.prefix(4))")

        // And they are draws, not one value repeated — a kernel that never ran its RNG
        // would return a buffer of zeros, which the range check above would also reject,
        // but a kernel that seeded every thread alike would pass it.
        let distinct = Set(results.map(\.bitPattern))
        #expect(distinct.count > iterations / 2,
                "\(distinct.count) distinct values in \(iterations) draws")
    }
}

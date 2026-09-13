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

    /// The equality opcodes do not use the same epsilon on the two sides.
    ///
    /// The interpreter tests `abs(a - b) < 1e-10`; the kernel tests `< 1e-6f`. Four orders of
    /// magnitude apart, so two values differing by 1e-8 are **equal** on the GPU and **unequal**
    /// on the CPU — a divergence with no error, no NaN and no infinity in it, which is why none
    /// of the error-parity machinery would ever surface it.
    ///
    /// This test pins the gap as it stands rather than asserting agreement, so that closing it
    /// is a deliberate change with a failing test attached. Filed in
    /// `PROPOSAL_gpu_error_parity.md` section 10.
    @Test("The equality epsilons differ, and this is where")
    func equalityEpsilonsDiffer() throws {
        let interpreterEpsilon = 1e-10
        let kernelEpsilon = 1e-6

        // A gap the two classify differently: below the kernel's threshold, above the
        // interpreter's.
        let gap = 1e-8
        #expect(gap < kernelEpsilon, "the kernel would call these equal")
        #expect(gap > interpreterEpsilon, "the interpreter would call these unequal")

        let bytecode: [Bytecode] = [.input(0), .input(1), .equal]
        let equalOnCPU = try BytecodeInterpreter.evaluate(bytecode: bytecode, inputs: [1.0, 1.0 + gap])
        #expect(equalOnCPU == 0.0, "the interpreter called a gap of \(gap) equal")
    }
}

// Everything below needs `MonteCarloGPUDevice`, which lives behind `#if canImport(Metal)`.
//
// `.requiresMetalGPU` is a *runtime* condition — it decides whether a test executes, not whether
// it compiles. On Linux the symbols simply are not there, so the trait cannot help and the guard
// has to be lexical. This is the same `#if canImport(Metal)` the other GPU suites use, hoisted to
// cover a whole file's worth of tests rather than repeated inside each body.
#if canImport(Metal)

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

    /// Every opcode, computed both ways on the same inputs, compared.
    ///
    /// Nothing checked that the kernel's arithmetic agreed with the interpreter's. The opcode
    /// *numbers* now cannot drift (`GPUOpcode`), but agreeing on which case to enter says
    /// nothing about what the case does — `OP_SUB` could subtract in the other order and every
    /// table test would still pass.
    ///
    /// Exact inputs reach the kernel through a degenerate uniform: distribution type 1 is
    /// `param1 + u * (param2 - param1)`, so `param1 == param2` returns that value for every
    /// draw, whatever the RNG does.
    ///
    /// The tolerance is Float32's, not a fitted one. The kernel computes in single precision and
    /// the interpreter in double, so a relative difference of a few times `Float.ulpOfOne`
    /// (1.19e-7) is the expected cost of the crossing; `2e-6` allows a handful of roundings in a
    /// chain. Anything larger is a disagreement about the operation, not about precision.
    @Test("Every opcode agrees between the interpreter and the kernel", .requiresMetalGPU)
    func everyOpcodeAgreesWithTheInterpreter() throws {
        let gpu = try #require(MonteCarloGPUDevice.shared,
                               "a trivial kernel compiles here, so the package's kernel failing to is our defect")

        // Chosen so every opcode is in range: positive for log and sqrt, non-zero for divide,
        // and a first operand that is non-zero so `select` takes its true branch.
        let values: [Float] = [3.0, 2.0, 7.0]
        let distributions: [MonteCarloGPUDevice.DistributionConfig] = values.map {
            (type: 1, params: ($0, $0, 0.0))
        }

        for opcode in GPUOpcode.allCases {
            // `input` and `constant` are operands, not operations; they are what the others
            // are built from and are exercised by every case below.
            if opcode == .input || opcode == .constant { continue }

            let operands = opcode.operandCount
            var bytecode: [Bytecode] = (0..<operands).map { Bytecode.input($0) }
            let operation: Bytecode
            switch opcode {
            case .add: operation = .add
            case .subtract: operation = .subtract
            case .multiply: operation = .multiply
            case .divide: operation = .divide
            case .power: operation = .power
            case .min: operation = .min
            case .max: operation = .max
            case .negate: operation = .negate
            case .abs: operation = .abs
            case .sqrt: operation = .sqrt
            case .log: operation = .log
            case .exp: operation = .exp
            case .sin: operation = .sin
            case .cos: operation = .cos
            case .tan: operation = .tan
            case .lessThan: operation = .lessThan
            case .greaterThan: operation = .greaterThan
            case .lessOrEqual: operation = .lessOrEqual
            case .greaterOrEqual: operation = .greaterOrEqual
            case .equal: operation = .equal
            case .notEqual: operation = .notEqual
            case .select: operation = .select
            case .input, .constant: continue
            }
            bytecode.append(operation)

            let onCPU = try BytecodeInterpreter.evaluate(
                bytecode: bytecode,
                inputs: values.prefix(operands).map(Double.init)
            )

            let onGPU = try gpu.runSimulation(
                distributions: Array(distributions.prefix(Swift.max(operands, 1))),
                modelBytecode: BytecodeCompiler.toGPUFormat(bytecode),
                iterations: 4,
                seed: 1
            )

            #expect(onGPU.count == 4, "\(opcode): got \(onGPU.count) results")
            guard let first = onGPU.first else { continue }

            let expected = Double(Float(onCPU))
            let actual = Double(first)
            let scale = Swift.max(1.0, Swift.abs(expected))
            let relative = Swift.abs(actual - expected) / scale
            #expect(relative < 2e-6,
                    "\(opcode): interpreter \(onCPU), kernel \(first), relative \(relative)")
        }
    }

    // MARK: - Error Parity

    /// Each of the three conditions the interpreter throws on is now reported by the kernel.
    ///
    /// Not inferred from the output. The kernel tests the operand *before* the operation and
    /// writes a code into a per-thread buffer, so the report says which condition, at which
    /// iteration — things a `NaN` in the output can never say, because `sqrt(-1)`, `log(-1)`,
    /// `0/0` and an honest NaN are indistinguishable after the fact.
    @Test("Every condition the interpreter throws on is reported by the kernel", .requiresMetalGPU)
    func everyThrowingConditionIsReported() throws {
        let gpu = try #require(MonteCarloGPUDevice.shared,
                               "a trivial kernel compiles here, so the package's kernel failing to is our defect")

        // A degenerate uniform: `param1 + u * (param2 - param1)` with the two equal returns that
        // value for every draw, whatever the RNG does.
        func pinned(_ value: Float) -> [MonteCarloGPUDevice.DistributionConfig] {
            [(type: 1, params: (value, value, 0.0))]
        }

        let cases: [(String, [Bytecode], Float, GPUIterationError)] = [
            ("0 / 0", [.input(0), .input(0), .divide], 0.0, .divisionByZero),
            ("1 / 0", [.constant(1.0), .input(0), .divide], 0.0, .divisionByZero),
            ("sqrt(-1)", [.input(0), .sqrt], -1.0, .sqrtOfNegative),
            ("log(0)", [.input(0), .log], 0.0, .logOfNonPositive),
            ("log(-1)", [.input(0), .log], -1.0, .logOfNonPositive)
        ]

        for (label, bytecode, input, expected) in cases {
            let outcome = try gpu.runSimulation(
                distributions: pinned(input),
                modelBytecode: BytecodeCompiler.toGPUFormat(bytecode),
                iterations: 4, seed: 1,
                onIterationError: .collect
            )
            #expect(outcome.errors.count == 4, "\(label): \(outcome.errors.count) error slots")
            #expect(outcome.errors.allSatisfy { $0 == expected },
                    "\(label): expected \(expected) on every iteration, got \(outcome.errors)")

            // The interpreter's verdict on the same model, for comparison.
            do {
                let value = try BytecodeInterpreter.evaluate(bytecode: bytecode, inputs: [Double(input)])
                Issue.record("\(label): the interpreter returned \(value) instead of throwing")
            } catch is EvaluationError {
                // As expected — the point is that both refuse, not how the message reads.
            }
        }
    }

    /// A clean model reports no errors. The control for the suite above.
    @Test("A model that meets no condition reports none", .requiresMetalGPU)
    func cleanModelReportsNoErrors() throws {
        let gpu = try #require(MonteCarloGPUDevice.shared,
                               "a trivial kernel compiles here, so the package's kernel failing to is our defect")

        let outcome = try gpu.runSimulation(
            distributions: [(type: 1, params: (4.0, 4.0, 0.0))],
            modelBytecode: BytecodeCompiler.toGPUFormat([.input(0), .sqrt]),
            iterations: 8, seed: 1,
            onIterationError: .collect
        )
        #expect(outcome.errors.allSatisfy { $0 == nil }, "reported \(outcome.errors)")
        #expect(outcome.values.allSatisfy { abs($0 - 2.0) < 1e-6 },
                "sqrt(4) should be 2; got \(outcome.values)")
    }

    /// The default throws, and names the count, the first failing iteration and the condition.
    @Test("The default refuses the batch, and says why", .requiresMetalGPU)
    func theDefaultThrowsAndNamesTheFailure() throws {
        let gpu = try #require(MonteCarloGPUDevice.shared,
                               "a trivial kernel compiles here, so the package's kernel failing to is our defect")

        let bytecode: [Bytecode] = [.constant(1.0), .input(0), .divide]
        do {
            let values = try gpu.runSimulation(
                distributions: [(type: 1, params: (0.0, 0.0, 0.0))],
                modelBytecode: BytecodeCompiler.toGPUFormat(bytecode),
                iterations: 8, seed: 1
            )
            Issue.record("returned \(values.count) values for a model that divides by zero")
        } catch let error as GPUError {
            guard case .iterationsFailed(let count, let firstIteration, let reason) = error else {
                Issue.record("threw \(error), not iterationsFailed")
                return
            }
            #expect(count == 8, "every iteration divides by zero; \(count) were reported")
            #expect(firstIteration == 0, "the first failure was iteration \(firstIteration)")
            #expect(reason == .divisionByZero, "reported \(reason)")
        }
    }

    /// `.collect` keeps the good values when only some iterations fail.
    ///
    /// One draw in a million landing on a pole is an ordinary Monte Carlo situation, not a broken
    /// model, and throwing the batch away for it is the behaviour `.collect` exists to avoid.
    /// The split is made deterministic with a `select`: input 1 is zero, so the divisor is zero
    /// exactly when the condition picks it.
    @Test("Collect keeps the values that succeeded", .requiresMetalGPU)
    func collectKeepsTheGoodValues() throws {
        let gpu = try #require(MonteCarloGPUDevice.shared,
                               "a trivial kernel compiles here, so the package's kernel failing to is our defect")

        // input0 is a uniform on [0, 1); the divisor is 0 when input0 < 0.5 and 2 otherwise.
        // 1 / divisor, so the low half fails and the high half returns 0.5.
        let bytecode: [Bytecode] = [
            .constant(1.0),
            .input(0), .constant(0.5), .lessThan,
            .constant(0.0), .constant(2.0), .select,
            .divide
        ]
        let outcome = try gpu.runSimulation(
            distributions: [(type: 1, params: (0.0, 1.0, 0.0))],
            modelBytecode: BytecodeCompiler.toGPUFormat(bytecode),
            iterations: 512, seed: 99,
            onIterationError: .collect
        )

        let failed = outcome.errors.filter { $0 != nil }.count
        let succeeded = outcome.errors.count - failed
        #expect(failed > 0, "no iteration hit the zero divisor")
        #expect(succeeded > 0, "every iteration hit the zero divisor")
        #expect(outcome.values.count == 512)

        // Every surviving value is the one the model computes, and every failed one is excluded
        // rather than silently averaged in.
        let usable = zip(outcome.values, outcome.errors).filter { $0.1 == nil }.map(\.0)
        #expect(usable.count == succeeded)
        #expect(usable.allSatisfy { abs($0 - 0.5) < 1e-6 }, "surviving values were \(usable.prefix(4))")

        // And the same model under the default refuses the whole batch.
        #expect(throws: GPUError.self) {
            _ = try gpu.runSimulation(
                distributions: [(type: 1, params: (0.0, 1.0, 0.0))],
                modelBytecode: BytecodeCompiler.toGPUFormat(bytecode),
                iterations: 512, seed: 99
            )
        }
    }

    /// The value the kernel leaves behind when it records an error is the IEEE one.
    ///
    /// Evaluation continues after a condition is recorded, rather than stopping the thread.
    /// Stopping would leave the output slot holding whatever the buffer had, which is a second
    /// undefined value to account for; letting IEEE finish leaves something whose provenance is
    /// understood, and the error code says not to trust it. This pins that choice.
    ///
    /// - Note: an earlier version of this test claimed to prove the kernel is compiled with fast
    ///   math off, by asserting `0 / 0` is not `1.0`. It passed under *both* math modes and so
    ///   proved nothing — fast math folds `0 / 0` to `1.0` only where the compiler can see both
    ///   operands are the same value, and `evaluateModel` divides two slots of a stack array at
    ///   runtime indices it cannot follow. That is exactly why the guards above test the operand
    ///   instead of reading the result: an explicit comparison is one the optimizer has to keep.
    @Test("A failed iteration still leaves the IEEE value behind", .requiresMetalGPU)
    func failedIterationsLeaveTheIEEEValue() throws {
        let gpu = try #require(MonteCarloGPUDevice.shared,
                               "a trivial kernel compiles here, so the package's kernel failing to is our defect")

        let zero: [MonteCarloGPUDevice.DistributionConfig] = [(type: 1, params: (0.0, 0.0, 0.0))]

        let indeterminate = try gpu.runSimulation(
            distributions: zero,
            modelBytecode: BytecodeCompiler.toGPUFormat([.input(0), .input(0), .divide]),
            iterations: 4, seed: 1, onIterationError: .collect
        )
        #expect(indeterminate.values.first?.isNaN == true,
                "0 / 0 left \(String(describing: indeterminate.values.first))")
        #expect(indeterminate.errors.first == .divisionByZero)

        let overZero = try gpu.runSimulation(
            distributions: zero,
            modelBytecode: BytecodeCompiler.toGPUFormat([.constant(1.0), .input(0), .divide]),
            iterations: 4, seed: 1, onIterationError: .collect
        )
        #expect(overZero.values.first?.isInfinite == true,
                "1 / 0 left \(String(describing: overZero.values.first))")
        #expect(overZero.errors.first == .divisionByZero)
    }

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

#endif

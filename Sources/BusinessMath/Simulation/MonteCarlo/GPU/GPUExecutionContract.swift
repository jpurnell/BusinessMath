//
//  GPUExecutionContract.swift
//  BusinessMath
//
//  The numbers and limits the CPU and the GPU have to agree on.
//

import Foundation

// MARK: - Opcodes

/// The opcode numbering shared by the bytecode compiler and the Metal kernel.
///
/// These numbers are a wire format. ``BytecodeCompiler/toGPUFormat(_:)`` writes them into a
/// buffer on this side and `evaluateModel` switches on them on the other, and nothing in
/// between checks that the two agree — a mismatched pair does not fail to compile, it
/// silently computes a different expression.
///
/// They used to be bare integer literals in both places: `gpu.append((6, 0, 0.0))` in Swift
/// and `case 6:` in the shader string, with the name only in a trailing comment. Renumbering
/// one and not the other was a single-character edit away, and the tests in place asserted
/// only `opcode >= 0` and `opcode <= 16`, which any permutation satisfies — and which is
/// itself wrong, since the comparison and conditional opcodes run to 23.
///
/// So the numbers live here once. The shader no longer contains any, ``mslDeclarations``
/// hands it named constants generated from this enum, and `GPUExecutionContractTests` pins
/// every case to its value so that changing one is a deliberate act with a failing test attached.
///
/// - Important: This is a serialization contract, not an implementation detail. A value here
///   may be added but never reassigned.
public enum GPUOpcode: Int32, CaseIterable, Sendable {
    // Binary arithmetic
    case add = 0
    case subtract = 1
    case multiply = 2
    case divide = 3

    // Operands
    case input = 4
    case constant = 5

    // Binary, continued
    case power = 6
    case min = 7
    case max = 8

    // Unary
    case negate = 9
    case abs = 10
    case sqrt = 11
    case log = 12
    case exp = 13
    case sin = 14
    case cos = 15
    case tan = 16

    // Comparison — 1.0 for true, 0.0 for false
    case lessThan = 17
    case greaterThan = 18
    case lessOrEqual = 19
    case greaterOrEqual = 20
    case equal = 21
    case notEqual = 22

    // Conditional
    case select = 23

    /// The identifier this opcode carries in the generated Metal source.
    ///
    /// Matches the names in `MonteCarloCommon.h`, which is a hand-maintained ahead-of-time
    /// mirror rather than anything the build compiles.
    public var mslName: String {
        switch self {
        case .add:            return "OP_ADD"
        case .subtract:       return "OP_SUB"
        case .multiply:       return "OP_MUL"
        case .divide:         return "OP_DIV"
        case .input:          return "OP_INPUT"
        case .constant:       return "OP_CONST"
        case .power:          return "OP_POW"
        case .min:            return "OP_MIN"
        case .max:            return "OP_MAX"
        case .negate:         return "OP_NEG"
        case .abs:            return "OP_ABS"
        case .sqrt:           return "OP_SQRT"
        case .log:            return "OP_LOG"
        case .exp:            return "OP_EXP"
        case .sin:            return "OP_SIN"
        case .cos:            return "OP_COS"
        case .tan:            return "OP_TAN"
        case .lessThan:       return "OP_LT"
        case .greaterThan:    return "OP_GT"
        case .lessOrEqual:    return "OP_LE"
        case .greaterOrEqual: return "OP_GE"
        case .equal:          return "OP_EQ"
        case .notEqual:       return "OP_NE"
        case .select:         return "OP_SELECT"
        }
    }

    /// The opcode a bytecode instruction is sent to the GPU as.
    ///
    /// - Parameter instruction: The instruction to encode.
    /// - Returns: Its opcode. Total by construction, so adding a `Bytecode` case without
    ///   giving it a number is a compile error rather than a run-time surprise.
    public static func of(_ instruction: Bytecode) -> GPUOpcode {
        switch instruction {
        case .input:          return .input
        case .constant:       return .constant
        case .add:            return .add
        case .subtract:       return .subtract
        case .multiply:       return .multiply
        case .divide:         return .divide
        case .power:          return .power
        case .min:            return .min
        case .max:            return .max
        case .negate:         return .negate
        case .abs:            return .abs
        case .sqrt:           return .sqrt
        case .log:            return .log
        case .exp:            return .exp
        case .sin:            return .sin
        case .cos:            return .cos
        case .tan:            return .tan
        case .lessThan:       return .lessThan
        case .greaterThan:    return .greaterThan
        case .lessOrEqual:    return .lessOrEqual
        case .greaterOrEqual: return .greaterOrEqual
        case .equal:          return .equal
        case .notEqual:       return .notEqual
        case .select:         return .select
        }
    }
}

// MARK: - Limits

/// The fixed sizes the Metal kernel allocates, and therefore the sizes a model must fit.
///
/// `evaluateModel` declares `float stack[MAX_STACK]` as a thread-local array and indexes it
/// with a counter it never bounds-checks. A model needing more depth than that does not fail
/// on the GPU — it writes past the array into whatever the compiler put next, which is
/// undefined behaviour and need not even be reproducible.
///
/// ``GPUExecutionError`` is raised before the dispatch instead.
public enum GPUExecutionLimits: Sendable {
    /// Slots in the kernel's evaluation stack.
    public static let maxStackDepth = 32

    /// Input slots the kernel reads per iteration.
    public static let maxInputs = 32
}

// MARK: - Iteration Errors

/// A condition one GPU iteration met that `BytecodeInterpreter` throws on.
///
/// The kernel cannot throw, and until these existed it could not report either — it computed the
/// IEEE answer (`inf`, `NaN`) and carried on, so a caller could see *that* something was wrong by
/// testing the output but never *what*, *where*, or *which operation*.
///
/// The kernel tests for these **explicitly**, before performing the operation, rather than
/// inspecting the result afterwards. Two reasons, and the second is the load-bearing one:
///
/// 1. A `NaN` in the output is ambiguous. `sqrt(-1)`, `log(-1)`, `0/0` and a model that honestly
///    produced a NaN are indistinguishable after the fact.
/// 2. **Inferring an error from an IEEE result means trusting the optimizer to preserve IEEE.**
///    Fast math is a standing licence not to, and this package has already been burned by relying
///    on protection an optimizer was free to remove — `factorial`'s overflow trap was incidental
///    to an arithmetic result, and inlining deleted the multiply and its check together. An
///    explicit comparison against zero is a comparison the compiler must keep, whatever it does
///    to the arithmetic around it.
///
/// The raw values are a wire format shared with the kernel, exactly as ``GPUOpcode`` is. Zero is
/// reserved for "no error", so the cases start at one.
public enum GPUIterationError: Int32, CaseIterable, Sendable, Equatable, CustomStringConvertible {
    /// The divisor was zero. `BytecodeInterpreter` throws `EvaluationError.divisionByZero`.
    case divisionByZero = 1

    /// The argument to `sqrt` was negative, or NaN.
    /// `BytecodeInterpreter` throws `EvaluationError.invalidOperation("sqrt of negative")`.
    case sqrtOfNegative = 2

    /// The argument to `log` was zero, negative, or NaN.
    /// `BytecodeInterpreter` throws `EvaluationError.invalidOperation("log of non-positive")`.
    case logOfNonPositive = 3

    /// The identifier this condition carries in the generated Metal source.
    public var mslName: String {
        switch self {
        case .divisionByZero:   return "ERR_DIVISION_BY_ZERO"
        case .sqrtOfNegative:   return "ERR_SQRT_OF_NEGATIVE"
        case .logOfNonPositive: return "ERR_LOG_OF_NON_POSITIVE"
        }
    }

    /// The message `BytecodeInterpreter` uses for the same condition, so a GPU failure and a CPU
    /// failure read alike.
    public var description: String {
        switch self {
        case .divisionByZero:   return "division by zero"
        case .sqrtOfNegative:   return "sqrt of negative"
        case .logOfNonPositive: return "log of non-positive"
        }
    }
}

/// What ``MonteCarloGPUDevice`` should do about iterations that met one of those conditions.
public enum IterationErrorPolicy: Sendable, Equatable {
    /// Throw `GPUError.iterationsFailed`, naming how many failed, the first that did, and why.
    ///
    /// The default, and what the CPU path does: `evaluate(inputs:)` throws rather than return a
    /// number it cannot stand behind.
    case `throw`

    /// Return the values and the per-iteration errors together, and let the caller decide.
    ///
    /// For models where a pole is expected and rare — one draw in a million landing on a zero
    /// divisor is an ordinary Monte Carlo situation, not a broken model. Asking for it at the call
    /// site is deliberate: the alternative, returning errors nobody has to look at, is the shape
    /// this library refuses elsewhere.
    case collect
}

// MARK: - Generated Metal Source

extension GPUOpcode {
    /// The opcode and limit constants as Metal Shading Language declarations.
    ///
    /// Interpolated into the kernel source so the shader carries names and this file carries
    /// numbers. Follows the pattern `MetalShaderSource` already sets for the random source:
    /// one Swift constant, interpolated into every kernel that needs it, because a `.metal`
    /// file and a Swift string literal cannot share text without a build step the package
    /// deliberately does not have.
    public static var mslDeclarations: String {
        var lines: [String] = [
            "// Generated from GPUOpcode. Do not edit here — edit GPUExecutionContract.swift.",
            "constant int MAX_INPUTS = \(GPUExecutionLimits.maxInputs);",
            "constant int MAX_STACK = \(GPUExecutionLimits.maxStackDepth);"
        ]
        for opcode in GPUOpcode.allCases {
            lines.append("constant int \(opcode.mslName) = \(opcode.rawValue);")
        }
        lines.append("constant int ERR_NONE = 0;")
        for failure in GPUIterationError.allCases {
            lines.append("constant int \(failure.mslName) = \(failure.rawValue);")
        }
        return lines.joined(separator: "\n        ")
    }
}

// MARK: - Stack Discipline

extension GPUOpcode {
    /// How many values this opcode pops before pushing its result.
    public var operandCount: Int {
        switch self {
        case .input, .constant:
            return 0
        case .negate, .abs, .sqrt, .log, .exp, .sin, .cos, .tan:
            return 1
        case .add, .subtract, .multiply, .divide, .power, .min, .max,
             .lessThan, .greaterThan, .lessOrEqual, .greaterOrEqual, .equal, .notEqual:
            return 2
        case .select:
            return 3
        }
    }

    /// The net change this opcode makes to the stack depth.
    ///
    /// Every opcode pushes exactly one result, so this is `1 - operandCount`.
    public var stackEffect: Int { 1 - operandCount }
}

// MARK: - Validation

/// A reason a compiled model cannot be executed on the GPU.
///
/// Each of these was undefined behaviour in the kernel rather than an error: `evaluateModel`
/// indexes a fixed `float stack[MAX_STACK]` with a counter it never bounds-checks, and reads
/// `stack[stackPtr - 2]` without asking whether two values are there. Out-of-range reads and
/// writes on a GPU do not trap — they return or corrupt whatever the compiler happened to
/// place next, which is why a model that was too deep produced a plausible number.
public enum GPUExecutionError: Error, Equatable, CustomStringConvertible, Sendable {
    /// An opcode the kernel has no case for. Its `default` falls through silently.
    case unknownOpcode(Int32, atOperation: Int)

    /// An operation asked for more operands than the stack held.
    case stackUnderflow(atOperation: Int, needed: Int, available: Int)

    /// The model needs more stack than the kernel allocates.
    case stackTooDeep(required: Int, limit: Int)

    /// Execution would not finish with exactly one value — the kernel returns `stack[0]`
    /// regardless, so a surplus is silently discarded and a deficit reads uninitialized
    /// memory.
    case unbalancedStack(remaining: Int)

    /// An input index outside the kernel's input buffer.
    case inputIndexOutOfRange(Int, limit: Int)

    /// A sentence naming what is wrong and where, for the thrown error's message.
    public var description: String {
        switch self {
        case .unknownOpcode(let code, let index):
            return "operation \(index) carries opcode \(code), which the kernel has no case for"
        case .stackUnderflow(let index, let needed, let available):
            return "operation \(index) needs \(needed) operands, and \(available) are on the stack"
        case .stackTooDeep(let required, let limit):
            return "the model needs \(required) stack slots and the kernel allocates \(limit)"
        case .unbalancedStack(let remaining):
            return "execution ends with \(remaining) values on the stack, not 1"
        case .inputIndexOutOfRange(let index, let limit):
            return "input \(index) is outside the kernel's \(limit) input slots"
        }
    }
}

/// Checks a model against what the Metal kernel can actually execute.
///
/// The kernel cannot report a problem: it has no way to throw, and its stack is a fixed
/// thread-local array it indexes unchecked. Every condition here therefore has to be settled
/// before the dispatch, on this side, or not at all.
public enum GPUBytecodeValidator: Sendable {

    /// Walks the operation stream and rejects anything the kernel would execute unsafely.
    ///
    /// - Parameter operations: The GPU-format stream, as ``BytecodeCompiler/toGPUFormat(_:)``
    ///   produces it.
    /// - Throws: ``GPUExecutionError`` naming the first problem found.
    public static func validate(_ operations: [(opcode: Int32, arg1: Int32, arg2: Float)]) throws {
        var depth = 0
        var peak = 0

        for (index, operation) in operations.enumerated() {
            guard let opcode = GPUOpcode(rawValue: operation.opcode) else {
                throw GPUExecutionError.unknownOpcode(operation.opcode, atOperation: index)
            }

            if opcode == .input {
                let slot = Int(operation.arg1)
                guard slot >= 0, slot < GPUExecutionLimits.maxInputs else {
                    throw GPUExecutionError.inputIndexOutOfRange(slot, limit: GPUExecutionLimits.maxInputs)
                }
            }

            let needed = opcode.operandCount
            guard depth >= needed else {
                throw GPUExecutionError.stackUnderflow(atOperation: index, needed: needed, available: depth)
            }

            depth += opcode.stackEffect
            peak = Swift.max(peak, depth)
        }

        guard peak <= GPUExecutionLimits.maxStackDepth else {
            throw GPUExecutionError.stackTooDeep(required: peak, limit: GPUExecutionLimits.maxStackDepth)
        }
        guard depth == 1 else {
            throw GPUExecutionError.unbalancedStack(remaining: depth)
        }
    }
}

// MARK: - Constant Narrowing

extension Array where Element == Bytecode {
    /// Constants whose meaning does not survive the narrowing to `Float`.
    ///
    /// The kernel is Float32 throughout, so every constant loses precision crossing over and
    /// that is the accepted cost of the GPU path. Two cases are not precision loss:
    ///
    /// - a finite constant that narrows to an infinity, which is an overflow past
    ///   `Float.greatestFiniteMagnitude` — about 3.4e38;
    /// - a non-zero constant that narrows to zero, which is an underflow below
    ///   `Float.leastNonzeroMagnitude` — about 1.4e-45.
    ///
    /// In both the GPU computes a different expression from the CPU rather than a slightly
    /// rounded one, so they are worth naming rather than absorbing. Callers that need the
    /// full range should stay on ``MonteCarloExpressionModel/evaluate(inputs:)``.
    ///
    /// - Returns: The offending constants and their positions, in order. Empty when the model
    ///   narrows cleanly.
    public func gpuNarrowingIssues() -> [(index: Int, value: Double)] {
        var issues: [(index: Int, value: Double)] = []
        for (index, instruction) in self.enumerated() {
            guard case .constant(let value) = instruction else { continue }
            let narrowed = Float(value)
            if value.isFinite && !narrowed.isFinite {
                issues.append((index, value))
            } else if value != 0.0 && narrowed == 0.0 {
                issues.append((index, value))
            }
        }
        return issues
    }
}

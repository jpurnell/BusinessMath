//
//  MonteCarloExpressionModel.swift
//  BusinessMath
//
//  Expression-based model compilation for Monte Carlo simulation
//
//  Provides utilities to create GPU-accelerated models using the ExpressionBuilder
//  DSL instead of closures. Expression models can be compiled to bytecode for
//  efficient GPU execution.
//

import Foundation

// MARK: - Expression Model

/// A Monte Carlo model defined using the ExpressionBuilder DSL
///
/// Expression models provide several advantages over closure-based models:
/// - **GPU Acceleration**: Automatically compiled to GPU bytecode
/// - **Optimization**: Compile-time constant folding and algebraic simplification
/// - **Inspection**: Expression tree can be analyzed and validated
/// - **Debugging**: Clearer error messages for malformed models
///
/// ## Usage
///
/// ```swift
/// let builder = ExpressionBuilder()
/// // Define model using expression builder
/// let model = try MonteCarloExpressionModel { builder in
///     let revenue = builder[0]
///     let costs = builder[1]
///     return revenue - costs
/// }
///
/// // Get compiled bytecode for GPU execution
/// let bytecode = try model.compile()
/// let gpuBytecode = model.gpuBytecode()
///
/// // Or evaluate on CPU
/// let result = try model.evaluate(inputs: [1_000_000, 700_000])
/// // result = 300_000
/// ```
///
/// ## Financial Model Example
///
/// ```swift
/// let builder = ExpressionBuilder()
/// // Profit model with multiple variables
/// let profitModel = try MonteCarloExpressionModel { builder in
///     let units = builder[0]
///     let price = builder[1]
///     let fixedCosts = builder[2]
///     let variableCost = builder[3]
///
///     let revenue = units * price
///     let totalCosts = fixedCosts + units * variableCost
///     return revenue - totalCosts
/// }
/// ```
public struct MonteCarloExpressionModel: Sendable {

    /// The compiled expression
    private let expression: Expression

    /// Cached compiled bytecode
    private let bytecode: [Bytecode]

    /// Cached GPU bytecode format
    private let cachedGPUBytecode: [(opcode: Int32, arg1: Int32, arg2: Float)]

    // MARK: - Initialization

    /// Creates an expression model using the builder DSL
    ///
    /// - Parameter builder: Closure that uses ExpressionBuilder to define the model
    ///
    /// ## Example
    ///
    /// ```swift
    /// let builder = ExpressionBuilder()
    /// let model = try MonteCarloExpressionModel { builder in
    ///     let a = builder[0]
    ///     let b = builder[1]
    ///     let c = builder[2]
    ///     return (a + b) * c
    /// }
    /// ```
    public init(_ builder: (ExpressionBuilder) -> ExpressionProxy) throws {
        let exprBuilder = ExpressionBuilder()
        let proxy = builder(exprBuilder)

        self.expression = proxy.expression

        // Compile and optimize at initialization — propagate errors to caller
        // rather than silently storing empty bytecode (fail-silent principle)
        let compiled = try BytecodeCompiler.compile(self.expression)
        self.bytecode = BytecodeOptimizer.optimize(compiled)
        self.cachedGPUBytecode = BytecodeCompiler.toGPUFormat(self.bytecode)
    }

    // MARK: - Compilation

    /// Returns the compiled bytecode
    ///
    /// The bytecode has already been optimized through constant folding
    /// and algebraic simplification.
    ///
    /// - Returns: Optimized bytecode instructions
    public func compile() -> [Bytecode] {
        return bytecode
    }

    /// Returns the GPU-formatted bytecode
    ///
    /// GPU bytecode uses the format: `(opcode: Int32, arg1: Int32, arg2: Float)`
    /// compatible with Metal compute shaders.
    ///
    /// - Returns: GPU-compatible bytecode tuples
    public func gpuBytecode() -> [(opcode: Int32, arg1: Int32, arg2: Float)] {
        return cachedGPUBytecode
    }

    // MARK: - Evaluation

    /// Evaluates the model on CPU with the given inputs
    ///
    /// This method interprets the compiled bytecode to compute the result.
    /// Useful for validation and small-scale simulations.
    ///
    /// - Parameter inputs: Array of input values
    /// - Returns: The computed result
    /// - Throws: EvaluationError if inputs are invalid or evaluation fails
    ///
    /// ## Example
    ///
    /// ```swift
    /// let model = try MonteCarloExpressionModel { b in b[0] + b[1] }
    /// let result = try model.evaluate(inputs: [10.0, 20.0])
    /// // result = 30.0
    /// ```
    public func evaluate(inputs: [Double]) throws -> Double {
        return try BytecodeInterpreter.evaluate(bytecode: bytecode, inputs: inputs)
    }

    /// Converts the expression model to a closure-based model
    ///
    /// Useful for interoperability with existing MonteCarloSimulation API.
    ///
    /// ## What happens when a draw cannot be evaluated
    ///
    /// The result type is `Double`, not `Double?` or a throwing call, because that is the shape
    /// ``MonteCarloSimulation`` takes. So a draw the interpreter refuses — `log` of a
    /// non-positive, `sqrt` of a negative, division by zero, an input index the model does not
    /// have — has to come back as *some* `Double`, and the only honest choice is one that no
    /// arithmetic produces: **`Double.nan`**.
    ///
    /// This used to return `0.0`, and that was a defect rather than a detail. `0.0` is a sample
    /// value like any other: it averages in, it shifts the mean toward zero, and nothing
    /// downstream can tell it apart from a draw the model really produced. Measured on
    /// `log(x)` over 300 draws spanning `[-1, 3]`, a quarter of which are outside the domain:
    /// the reported mean was **0.0707** where the mean over the defined draws is **0.0943**, and
    /// not one sample was non-finite. A 25% error with no symptom.
    ///
    /// `NaN` has the opposite property. It propagates through every mean, variance and quantile
    /// taken from the samples, so a model with an unhandled domain error reports as broken
    /// instead of as slightly different — which is what the package's fail-silent rule asks for
    /// when a signature has no room to throw.
    ///
    /// Use ``evaluate(inputs:)`` when you need to know *which* error occurred; it throws an
    /// ``EvaluationError`` that names it.
    ///
    /// - Returns: A closure evaluating the model, returning `Double.nan` for any input the model
    ///   cannot be evaluated at.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let exprModel = try MonteCarloExpressionModel { b in b[0] * b[1] }
    /// let closureModel = exprModel.toClosure()
    ///
    /// let sim = MonteCarloSimulation(iterations: 10_000, model: closureModel)
    /// ```
    public func toClosure() -> @Sendable ([Double]) -> Double {
        let capturedBytecode = self.bytecode
        return { inputs in
            do {
                return try BytecodeInterpreter.evaluate(bytecode: capturedBytecode, inputs: inputs)
            } catch { // logging: no value exists for this draw, and NaN is the only Double that says so
                return Double.nan
            }
        }
    }

    // MARK: - Analysis

    /// Returns the maximum stack depth required for evaluation
    ///
    /// Useful for validating bytecode before GPU execution.
    public func maxStackDepth() -> Int {
        return bytecode.maxStackDepth()
    }

    /// Returns the maximum input index referenced by the model
    ///
    /// Useful for validating that all required inputs are provided.
    ///
    /// - Returns: Highest input index, or nil if no inputs
    public func maxInputIndex() -> Int? {
        return bytecode.maxInputIndex()
    }

    /// Returns the number of bytecode instructions
    public func instructionCount() -> Int {
        return bytecode.count
    }
}

// MARK: - Bytecode Interpreter

/// CPU-based bytecode interpreter for expression evaluation
///
/// Provides stack-based evaluation of compiled bytecode for CPU execution.
/// Used by MonteCarloExpressionModel for validation and fallback execution.
enum BytecodeInterpreter {

    /// Takes the two operands of a binary instruction off the stack, in source order.
    ///
    /// Returned as `(a, b)` for an instruction written `a op b`, which is the reverse of the pop
    /// order — the right operand was pushed last. Getting that backwards silently transposes
    /// `subtract`, `divide`, `power` and every comparison, so it is written once here rather
    /// than thirteen times in the switch below.
    ///
    /// - Parameter stack: The evaluation stack, shortened by two.
    /// - Returns: The left and right operands.
    /// - Throws: ``EvaluationError/stackUnderflow`` if fewer than two values are available.
    @inline(__always)
    private static func popTwo(_ stack: inout [Double]) throws -> (Double, Double) {
        guard stack.count >= 2 else { throw EvaluationError.stackUnderflow }
        let b = stack.removeLast()
        let a = stack.removeLast()
        return (a, b)
    }

    /// Takes the single operand of a unary instruction off the stack.
    ///
    /// - Parameter stack: The evaluation stack, shortened by one.
    /// - Returns: The operand.
    /// - Throws: ``EvaluationError/stackUnderflow`` if the stack is empty.
    @inline(__always)
    private static func popOne(_ stack: inout [Double]) throws -> Double {
        guard let value = stack.popLast() else { throw EvaluationError.stackUnderflow }
        return value
    }

    /// Tolerance for `equal` and `notEqual`.
    ///
    /// Absolute, and shared with ``BytecodeOptimizer``'s constant folding so that optimising a
    /// comparison cannot change which way it goes. Being absolute, it treats values below it as
    /// equal whatever their ratio — a deliberate choice for a comparison operator in a modelling
    /// language, where the quantities compared are amounts rather than ulps.
    private static let comparisonEpsilon = 1e-10

    /// Evaluates bytecode with the given inputs
    ///
    /// - Parameters:
    ///   - bytecode: Compiled bytecode instructions
    ///   - inputs: Array of input values
    /// - Returns: The computed result
    /// - Throws: EvaluationError if evaluation fails
    ///
    /// ## Shape, and what it costs
    ///
    /// A flat dispatch over the instruction set. The per-case stack guard that used to be written
    /// out twenty-two times now lives in ``popTwo(_:)`` and ``popOne(_:)``, which is not only
    /// shorter: measured at `-O` over 2,000,000 evaluations of a mixed program, the interpreter
    /// went from **0.400s to 0.321s** on that change alone, and to **0.225s** with the
    /// `reserveCapacity` below — 44% faster in total.
    ///
    /// **A debug measurement says the opposite and must not be believed here.** At `-Onone`,
    /// `@inline(__always)` is advisory, so each helper becomes a real call with `inout`
    /// exclusivity checking and the same change measures *34% slower*. Not a different
    /// magnitude — a different sign. Benchmark this function at `-O` or not at all.
    static func evaluate(bytecode: [Bytecode], inputs: [Double]) throws -> Double {
        var stack: [Double] = []
        // The compiler already knows how deep this program goes, so the stack is allocated once
        // rather than grown. Worth 30% on its own — see above.
        stack.reserveCapacity(bytecode.maxStackDepth())

        for instruction in bytecode {
            switch instruction {
            case .input(let index):
                guard index >= 0 && index < inputs.count else {
                    throw EvaluationError.invalidInputIndex(index, available: inputs.count)
                }
                stack.append(inputs[index])

            case .constant(let value):
                stack.append(value)

            // Binary arithmetic.
            case .add:
                let (a, b) = try popTwo(&stack)
                stack.append(a + b)

            case .subtract:
                let (a, b) = try popTwo(&stack)
                stack.append(a - b)

            case .multiply:
                let (a, b) = try popTwo(&stack)
                stack.append(a * b)

            case .divide:
                let (a, b) = try popTwo(&stack)
                guard b != 0 else { throw EvaluationError.divisionByZero }
                stack.append(a / b)

            case .power:
                // Unguarded, unlike `sqrt` and `divide`, and that asymmetry is pinned by
                // `BytecodeErrorContractTests`: `(-1) ^ 0.5` returns NaN and `0 ^ -1` returns
                // infinity. Non-finite is loud — it propagates through every statistic taken
                // downstream — so it is not the fail-silent case those guards exist to prevent.
                let (a, b) = try popTwo(&stack)
                stack.append(pow(a, b))

            case .min:
                let (a, b) = try popTwo(&stack)
                stack.append(Swift.min(a, b))

            case .max:
                let (a, b) = try popTwo(&stack)
                stack.append(Swift.max(a, b))

            // Unary.
            case .negate:
                stack.append(-(try popOne(&stack)))

            case .abs:
                stack.append(abs(try popOne(&stack)))

            case .sqrt:
                let a = try popOne(&stack)
                guard a >= 0 else { throw EvaluationError.invalidOperation("sqrt of negative") }
                stack.append(sqrt(a))

            case .log:
                let a = try popOne(&stack)
                guard a > 0 else { throw EvaluationError.invalidOperation("log of non-positive") }
                stack.append(log(a))

            case .exp:
                stack.append(exp(try popOne(&stack)))

            case .sin:
                stack.append(sin(try popOne(&stack)))

            case .cos:
                stack.append(cos(try popOne(&stack)))

            case .tan:
                stack.append(tan(try popOne(&stack)))

            // Comparisons, which push 1.0 or 0.0 so that a condition is a value like any other.
            case .lessThan:
                let (a, b) = try popTwo(&stack)
                stack.append(a < b ? 1.0 : 0.0)

            case .greaterThan:
                let (a, b) = try popTwo(&stack)
                stack.append(a > b ? 1.0 : 0.0)

            case .lessOrEqual:
                let (a, b) = try popTwo(&stack)
                stack.append(a <= b ? 1.0 : 0.0)

            case .greaterOrEqual:
                let (a, b) = try popTwo(&stack)
                stack.append(a >= b ? 1.0 : 0.0)

            case .equal:
                let (a, b) = try popTwo(&stack)
                stack.append(abs(a - b) < comparisonEpsilon ? 1.0 : 0.0)

            case .notEqual:
                let (a, b) = try popTwo(&stack)
                stack.append(abs(a - b) >= comparisonEpsilon ? 1.0 : 0.0)

            // Conditional. All three operands are already on the stack — the compiler emits
            // them before `select` — so this chooses between two values that have both been
            // computed, rather than deciding which to compute.
            case .select:
                guard stack.count >= 3 else { throw EvaluationError.stackUnderflow }
                let falseValue = stack.removeLast()
                let trueValue = stack.removeLast()
                let condition = stack.removeLast()
                stack.append(condition != 0.0 ? trueValue : falseValue)
            }
        }

        guard stack.count == 1 else {
            throw EvaluationError.invalidStack(count: stack.count)
        }

        return stack[0]
    }
}

// MARK: - Evaluation Errors

/// Errors that can occur during bytecode evaluation
public enum EvaluationError: Error, CustomStringConvertible {
    /// Stack underflow - not enough operands for operation
    case stackUnderflow

    /// Invalid input index accessed
    case invalidInputIndex(Int, available: Int)

    /// Division by zero
    case divisionByZero

    /// Invalid operation (sqrt of negative, log of non-positive, etc.)
    case invalidOperation(String)

    /// Stack has invalid number of values after evaluation
    case invalidStack(count: Int)

    // MARK: - LocalizedError Conformance

    /// A localized human-readable description of the error.
    ///
    /// Provides context-specific error messages with relevant details like
    /// values, ranges, and suggestions.
    public var description: String {
        switch self {
        case .stackUnderflow:
            return "Stack underflow: insufficient operands"
        case .invalidInputIndex(let index, let available):
            return "Invalid input index \(index) (only \(available) inputs available)"
        case .divisionByZero:
            return "Division by zero"
        case .invalidOperation(let message):
            return "Invalid operation: \(message)"
        case .invalidStack(let remaining):
            return "Invalid stack after evaluation: \(remaining) values remaining (expected 1)"
        }
    }
}

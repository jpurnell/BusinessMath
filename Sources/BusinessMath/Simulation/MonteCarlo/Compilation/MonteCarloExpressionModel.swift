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
/// // Define model using expression builder
/// let model = MonteCarloExpressionModel { builder in
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
/// let result = model.evaluate(inputs: [1_000_000, 700_000])
/// // result = 300_000
/// ```
///
/// ## Financial Model Example
///
/// ```swift
/// // Profit model with multiple variables
/// let profitModel = MonteCarloExpressionModel { builder in
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
    /// let model = MonteCarloExpressionModel { builder in
    ///     let a = builder[0]
    ///     let b = builder[1]
    ///     let c = builder[2]
    ///     return (a + b) * c
    /// }
    /// ```
    public init(_ builder: (ExpressionBuilder) -> ExpressionProxy) {
        let exprBuilder = ExpressionBuilder()
        let proxy = builder(exprBuilder)

        self.expression = proxy.expression

        // Compile and optimize at initialization
        do {
            let compiled = try BytecodeCompiler.compile(self.expression)
            self.bytecode = BytecodeOptimizer.optimize(compiled)
            self.cachedGPUBytecode = BytecodeCompiler.toGPUFormat(self.bytecode)
        } catch {
            // If compilation fails, store empty bytecode
            // This should never happen with valid expressions from the builder
            self.bytecode = []
            self.cachedGPUBytecode = []
        }
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
    /// let model = MonteCarloExpressionModel { b in b[0] + b[1] }
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
    /// - Returns: Closure that evaluates the model
    ///
    /// ## Example
    ///
    /// ```swift
    /// let exprModel = MonteCarloExpressionModel { b in b[0] * b[1] }
    /// let closureModel = exprModel.toClosure()
    ///
    /// let sim = MonteCarloSimulation(iterations: 10_000, model: closureModel)
    /// ```
    public func toClosure() -> @Sendable ([Double]) -> Double {
        let capturedBytecode = self.bytecode
        return { inputs in
            do {
                return try BytecodeInterpreter.evaluate(bytecode: capturedBytecode, inputs: inputs)
            } catch {
                // Return 0 on error (should not happen with valid bytecode)
                return 0.0
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

    /// Evaluates bytecode with the given inputs
    ///
    /// - Parameters:
    ///   - bytecode: Compiled bytecode instructions
    ///   - inputs: Array of input values
    /// - Returns: The computed result
    /// - Throws: EvaluationError if evaluation fails
    static func evaluate(bytecode: [Bytecode], inputs: [Double]) throws -> Double {
        var stack: [Double] = []

        for instruction in bytecode {
            switch instruction {
            case .input(let index):
                guard index >= 0 && index < inputs.count else {
                    throw EvaluationError.invalidInputIndex(index, available: inputs.count)
                }
                stack.append(inputs[index])

            case .constant(let value):
                stack.append(value)

            // Binary operations
            case .add:
                guard stack.count >= 2 else { throw EvaluationError.stackUnderflow }
                let b = stack.removeLast()
                let a = stack.removeLast()
                stack.append(a + b)

            case .subtract:
                guard stack.count >= 2 else { throw EvaluationError.stackUnderflow }
                let b = stack.removeLast()
                let a = stack.removeLast()
                stack.append(a - b)

            case .multiply:
                guard stack.count >= 2 else { throw EvaluationError.stackUnderflow }
                let b = stack.removeLast()
                let a = stack.removeLast()
                stack.append(a * b)

            case .divide:
                guard stack.count >= 2 else { throw EvaluationError.stackUnderflow }
                let b = stack.removeLast()
                let a = stack.removeLast()
                guard b != 0 else { throw EvaluationError.divisionByZero }
                stack.append(a / b)

            case .power:
                guard stack.count >= 2 else { throw EvaluationError.stackUnderflow }
                let b = stack.removeLast()
                let a = stack.removeLast()
                stack.append(pow(a, b))

            case .min:
                guard stack.count >= 2 else { throw EvaluationError.stackUnderflow }
                let b = stack.removeLast()
                let a = stack.removeLast()
                stack.append(Swift.min(a, b))

            case .max:
                guard stack.count >= 2 else { throw EvaluationError.stackUnderflow }
                let b = stack.removeLast()
                let a = stack.removeLast()
                stack.append(Swift.max(a, b))

            // Unary operations
            case .negate:
                guard stack.count >= 1 else { throw EvaluationError.stackUnderflow }
                let a = stack.removeLast()
                stack.append(-a)

            case .abs:
                guard stack.count >= 1 else { throw EvaluationError.stackUnderflow }
                let a = stack.removeLast()
                stack.append(abs(a))

            case .sqrt:
                guard stack.count >= 1 else { throw EvaluationError.stackUnderflow }
                let a = stack.removeLast()
                guard a >= 0 else { throw EvaluationError.invalidOperation("sqrt of negative") }
                stack.append(sqrt(a))

            case .log:
                guard stack.count >= 1 else { throw EvaluationError.stackUnderflow }
                let a = stack.removeLast()
                guard a > 0 else { throw EvaluationError.invalidOperation("log of non-positive") }
                stack.append(log(a))

            case .exp:
                guard stack.count >= 1 else { throw EvaluationError.stackUnderflow }
                let a = stack.removeLast()
                stack.append(exp(a))

            case .sin:
                guard stack.count >= 1 else { throw EvaluationError.stackUnderflow }
                let a = stack.removeLast()
                stack.append(sin(a))

            case .cos:
                guard stack.count >= 1 else { throw EvaluationError.stackUnderflow }
                let a = stack.removeLast()
                stack.append(cos(a))

            case .tan:
                guard stack.count >= 1 else { throw EvaluationError.stackUnderflow }
                let a = stack.removeLast()
                stack.append(tan(a))

            // Comparison operations
            case .lessThan:
                guard stack.count >= 2 else { throw EvaluationError.stackUnderflow }
                let b = stack.removeLast()
                let a = stack.removeLast()
                stack.append(a < b ? 1.0 : 0.0)

            case .greaterThan:
                guard stack.count >= 2 else { throw EvaluationError.stackUnderflow }
                let b = stack.removeLast()
                let a = stack.removeLast()
                stack.append(a > b ? 1.0 : 0.0)

            case .lessOrEqual:
                guard stack.count >= 2 else { throw EvaluationError.stackUnderflow }
                let b = stack.removeLast()
                let a = stack.removeLast()
                stack.append(a <= b ? 1.0 : 0.0)

            case .greaterOrEqual:
                guard stack.count >= 2 else { throw EvaluationError.stackUnderflow }
                let b = stack.removeLast()
                let a = stack.removeLast()
                stack.append(a >= b ? 1.0 : 0.0)

            case .equal:
                guard stack.count >= 2 else { throw EvaluationError.stackUnderflow }
                let b = stack.removeLast()
                let a = stack.removeLast()
                let epsilon = 1e-10
                stack.append(abs(a - b) < epsilon ? 1.0 : 0.0)

            case .notEqual:
                guard stack.count >= 2 else { throw EvaluationError.stackUnderflow }
                let b = stack.removeLast()
                let a = stack.removeLast()
                let epsilon = 1e-10
                stack.append(abs(a - b) >= epsilon ? 1.0 : 0.0)

            // Conditional operation
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

    public var description: String {
        switch self {
        case .stackUnderflow:
            return "Stack underflow: insufficient operands"
        case .invalidInputIndex(let index, let available):
            return "Invalid input index \(index) (only \(available) inputs available)"
        case .divisionByZero:
            return "Division by zero"
        case .invalidOperation(let description):
            return "Invalid operation: \(description)"
        case .invalidStack(let count):
            return "Invalid stack after evaluation: \(count) values remaining (expected 1)"
        }
    }
}

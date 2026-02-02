//
//  BytecodeCompiler.swift
//  BusinessMath
//
//  Bytecode Compiler for GPU Execution
//
//  Compiles expression trees to stack-based bytecode that can be executed
//  on GPU or CPU. The bytecode uses post-order traversal for efficient
//  stack-based evaluation.
//

import Foundation

// MARK: - Bytecode Representation

/// High-level bytecode instruction
///
/// Bytecode represents compiled expression trees in a stack-based format that
/// can be executed efficiently on GPU or CPU. Instructions operate on an
/// implicit stack of floating-point values.
///
/// ## Stack-Based Execution
///
/// Binary operations (e.g., ADD):
/// 1. Pop two values from stack
/// 2. Perform operation
/// 3. Push result onto stack
///
/// Unary operations (e.g., NEGATE):
/// 1. Pop one value from stack
/// 2. Perform operation
/// 3. Push result onto stack
///
/// ## Example
///
/// Expression: `(a + b) * c`
/// Bytecode: [INPUT(0), INPUT(1), ADD, INPUT(2), MUL]
///
/// Execution trace:
/// - INPUT(0): stack = [a]
/// - INPUT(1): stack = [a, b]
/// - ADD: stack = [a+b]
/// - INPUT(2): stack = [a+b, c]
/// - MUL: stack = [(a+b)*c]
///
public enum Bytecode: Sendable, Equatable {
    // MARK: Stack Operations

    /// Push input variable onto stack
    case input(Int)

    /// Push constant value onto stack
    case constant(Double)

    // MARK: Binary Operations

    /// Pop b, pop a, push a + b
    case add

    /// Pop b, pop a, push a - b
    case subtract

    /// Pop b, pop a, push a * b
    case multiply

    /// Pop b, pop a, push a / b
    case divide

    /// Pop b, pop a, push a^b
    case power

    /// Pop b, pop a, push min(a, b)
    case min

    /// Pop b, pop a, push max(a, b)
    case max

    // MARK: Comparison Operations

    /// Pop b, pop a, push 1.0 if a < b, else 0.0
    case lessThan

    /// Pop b, pop a, push 1.0 if a > b, else 0.0
    case greaterThan

    /// Pop b, pop a, push 1.0 if a <= b, else 0.0
    case lessOrEqual

    /// Pop b, pop a, push 1.0 if a >= b, else 0.0
    case greaterOrEqual

    /// Pop b, pop a, push 1.0 if |a - b| < epsilon, else 0.0
    case equal

    /// Pop b, pop a, push 1.0 if |a - b| >= epsilon, else 0.0
    case notEqual

    // MARK: Conditional Operations

    /// Pop falseValue, pop trueValue, pop condition, push (condition != 0.0 ? trueValue : falseValue)
    case select

    // MARK: Unary Operations

    /// Pop a, push -a
    case negate

    /// Pop a, push |a|
    case abs

    /// Pop a, push √a
    case sqrt

    /// Pop a, push ln(a)
    case log

    /// Pop a, push e^a
    case exp

    /// Pop a, push sin(a)
    case sin

    /// Pop a, push cos(a)
    case cos

    /// Pop a, push tan(a)
    case tan
}

// MARK: - Bytecode Compiler

/// Compiles expression trees to stack-based bytecode
///
/// The compiler performs post-order traversal of the expression tree,
/// emitting bytecode instructions in the order they should be executed.
///
/// ## Usage
///
/// ```swift
/// let expr = Expression.binary(.add, .input(0), .input(1))
/// let bytecode = try BytecodeCompiler.compile(expr)
/// // bytecode = [.input(0), .input(1), .add]
/// ```
///
/// ## GPU Integration
///
/// ```swift
/// let bytecode = try BytecodeCompiler.compile(expression)
/// let gpuBytecode = BytecodeCompiler.toGPUFormat(bytecode)
/// // gpuBytecode = [(4, 0, 0.0), (4, 1, 0.0), (0, 0, 0.0)]
/// ```
public struct BytecodeCompiler {

    // MARK: - Compilation

    /// Compile an expression tree to bytecode
    ///
    /// Performs post-order traversal: left subtree, right subtree, operator.
    /// This ensures operands are evaluated before operators.
    ///
    /// - Parameter expression: The expression tree to compile
    /// - Returns: Array of bytecode instructions
    /// - Throws: CompilationError if expression is invalid
    public static func compile(_ expression: Expression) throws -> [Bytecode] {
        var bytecode: [Bytecode] = []
        try compileRecursive(expression, into: &bytecode)
        return bytecode
    }

    /// Recursive compilation helper (post-order traversal)
    private static func compileRecursive(_ expr: Expression, into bytecode: inout [Bytecode]) throws {
        switch expr {
        case .input(let index):
            bytecode.append(.input(index))

        case .constant(let value):
            bytecode.append(.constant(value))

        case .binary(let op, let left, let right):
            // Compile operands first (post-order)
            try compileRecursive(left, into: &bytecode)
            try compileRecursive(right, into: &bytecode)

            // Then compile operator
            switch op {
            case .add:              bytecode.append(.add)
            case .subtract:         bytecode.append(.subtract)
            case .multiply:         bytecode.append(.multiply)
            case .divide:           bytecode.append(.divide)
            case .power:            bytecode.append(.power)
            case .min:              bytecode.append(.min)
            case .max:              bytecode.append(.max)
            case .lessThan:         bytecode.append(.lessThan)
            case .greaterThan:      bytecode.append(.greaterThan)
            case .lessOrEqual:      bytecode.append(.lessOrEqual)
            case .greaterOrEqual:   bytecode.append(.greaterOrEqual)
            case .equal:            bytecode.append(.equal)
            case .notEqual:         bytecode.append(.notEqual)
            }

        case .unary(let op, let operand):
            // Compile operand first
            try compileRecursive(operand, into: &bytecode)

            // Then compile operator
            switch op {
            case .negate: bytecode.append(.negate)
            case .abs:    bytecode.append(.abs)
            case .sqrt:   bytecode.append(.sqrt)
            case .log:    bytecode.append(.log)
            case .exp:    bytecode.append(.exp)
            case .sin:    bytecode.append(.sin)
            case .cos:    bytecode.append(.cos)
            case .tan:    bytecode.append(.tan)
            }

        case .conditional(let condition, let trueValue, let falseValue):
            // Compile all three operands (condition, true, false)
            try compileRecursive(condition, into: &bytecode)
            try compileRecursive(trueValue, into: &bytecode)
            try compileRecursive(falseValue, into: &bytecode)

            // Then compile SELECT operator
            bytecode.append(.select)
        }
    }

    // MARK: - GPU Format Conversion

    /// Convert bytecode to GPU format: (opcode, arg1, arg2)
    ///
    /// GPU bytecode uses a compact tuple format compatible with Metal shaders:
    /// - `opcode`: Operation identifier (Int32)
    /// - `arg1`: First argument (typically input index)
    /// - `arg2`: Second argument (typically constant value)
    ///
    /// ## Opcode Mapping
    ///
    /// Binary operations:
    /// - ADD = 0, SUB = 1, MUL = 2, DIV = 3
    /// - POW = 6, MIN = 7, MAX = 8
    ///
    /// Unary operations:
    /// - NEG = 9, ABS = 10, SQRT = 11
    /// - LOG = 12, EXP = 13
    /// - SIN = 14, COS = 15, TAN = 16
    ///
    /// Comparison operations:
    /// - LT = 17, GT = 18, LE = 19
    /// - GE = 20, EQ = 21, NE = 22
    ///
    /// Conditional operations:
    /// - SELECT = 23
    ///
    /// Stack operations:
    /// - INPUT = 4, CONST = 5
    ///
    /// - Parameter bytecode: High-level bytecode instructions
    /// - Returns: GPU-compatible tuple array
    public static func toGPUFormat(_ bytecode: [Bytecode]) -> [(opcode: Int32, arg1: Int32, arg2: Float)] {
        var gpu: [(Int32, Int32, Float)] = []

        for instruction in bytecode {
            switch instruction {
            case .input(let index):
                gpu.append((4, Int32(index), 0.0))  // INPUT opcode = 4

            case .constant(let value):
                gpu.append((5, 0, Float(value)))    // CONST opcode = 5

            // Binary operations
            case .add:      gpu.append((0, 0, 0.0))  // ADD opcode = 0
            case .subtract: gpu.append((1, 0, 0.0))  // SUB opcode = 1
            case .multiply: gpu.append((2, 0, 0.0))  // MUL opcode = 2
            case .divide:   gpu.append((3, 0, 0.0))  // DIV opcode = 3
            case .power:    gpu.append((6, 0, 0.0))  // POW opcode = 6
            case .min:      gpu.append((7, 0, 0.0))  // MIN opcode = 7
            case .max:      gpu.append((8, 0, 0.0))  // MAX opcode = 8

            // Unary operations
            case .negate:   gpu.append((9, 0, 0.0))  // NEG opcode = 9
            case .abs:      gpu.append((10, 0, 0.0)) // ABS opcode = 10
            case .sqrt:     gpu.append((11, 0, 0.0)) // SQRT opcode = 11
            case .log:      gpu.append((12, 0, 0.0)) // LOG opcode = 12
            case .exp:      gpu.append((13, 0, 0.0)) // EXP opcode = 13
            case .sin:      gpu.append((14, 0, 0.0)) // SIN opcode = 14
            case .cos:      gpu.append((15, 0, 0.0)) // COS opcode = 15
            case .tan:      gpu.append((16, 0, 0.0)) // TAN opcode = 16

            // Comparison operations
            case .lessThan:        gpu.append((17, 0, 0.0)) // LT opcode = 17
            case .greaterThan:     gpu.append((18, 0, 0.0)) // GT opcode = 18
            case .lessOrEqual:     gpu.append((19, 0, 0.0)) // LE opcode = 19
            case .greaterOrEqual:  gpu.append((20, 0, 0.0)) // GE opcode = 20
            case .equal:           gpu.append((21, 0, 0.0)) // EQ opcode = 21
            case .notEqual:        gpu.append((22, 0, 0.0)) // NE opcode = 22

            // Conditional operations
            case .select:          gpu.append((23, 0, 0.0)) // SELECT opcode = 23
            }
        }

        return gpu
    }
}

// MARK: - Errors

/// Errors that can occur during bytecode compilation
public enum CompilationError: Error {
    /// Expression tree is too deep (stack overflow risk)
    case expressionTooDeep

    /// Expression references invalid input index
    case invalidInputIndex(Int)

    /// Expression contains unsupported operation
    case unsupportedOperation(String)
}

// MARK: - Bytecode Analysis

extension Array where Element == Bytecode {
    /// Returns the maximum stack depth required to execute this bytecode
    ///
    /// Used to validate bytecode before execution and ensure sufficient stack space.
    ///
    /// - Returns: Maximum number of stack slots needed
    public func maxStackDepth() -> Int {
        var currentDepth = 0
        var maxDepth = 0

        for instruction in self {
            switch instruction {
            case .input, .constant:
                currentDepth += 1
                maxDepth = Swift.max(maxDepth, currentDepth)

            case .add, .subtract, .multiply, .divide, .power, .min, .max,
                 .lessThan, .greaterThan, .lessOrEqual, .greaterOrEqual, .equal, .notEqual:
                currentDepth -= 1  // Pop 2, push 1: net -1

            case .negate, .abs, .sqrt, .log, .exp, .sin, .cos, .tan:
                // Pop 1, push 1: net 0
                break

            case .select:
                currentDepth -= 2  // Pop 3, push 1: net -2
            }
        }

        return maxDepth
    }

    /// Returns the maximum input index referenced in this bytecode
    ///
    /// Used to validate that all referenced inputs exist before execution.
    ///
    /// - Returns: Highest input index, or nil if no inputs referenced
    public func maxInputIndex() -> Int? {
        var maxIndex: Int? = nil

        for instruction in self {
            if case .input(let index) = instruction {
                if let current = maxIndex {
                    maxIndex = Swift.max(current, index)
                } else {
                    maxIndex = index
                }
            }
        }

        return maxIndex
    }
}

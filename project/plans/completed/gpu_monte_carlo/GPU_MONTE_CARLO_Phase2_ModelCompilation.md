# GPU Monte Carlo - Phase 2: Model Compilation

**Date Created:** January 29, 2026
**Prerequisites:** Phase 1 Complete (GPU infrastructure tested and working)
**Goal:** Enable GPU execution for user-defined arithmetic models
**Approach:** Expression Builder DSL + Bytecode Compiler

---

## Executive Summary

Phase 2 adds **model compilation** to convert user-defined arithmetic expressions into GPU bytecode, enabling full GPU acceleration for Monte Carlo simulations. The approach uses a fluent Expression Builder API that maintains backward compatibility while providing GPU compilation when possible.

### Key Design Decisions

1. **Hybrid API Approach**
   - Keep existing closure-based API for backward compatibility
   - Add optional Expression Builder for GPU-compatible models
   - Automatic fallback: Expression → GPU, Closure → CPU

2. **Expression Builder DSL**
   - Type-safe expression construction at compile-time
   - Natural Swift syntax: `inputs[0] * inputs[1] - inputs[2]`
   - Compiles to GPU bytecode at simulation initialization

3. **Bytecode Optimizer**
   - Constant folding: `5.0 * 2.0` → `10.0` (compile-time)
   - Dead code elimination
   - Common subexpression elimination

---

## Technical Approach

### Challenge: Swift Closure Opacity

Swift closures are **opaque at runtime** - we cannot inspect their AST or decompile them to GPU bytecode.

**Why other approaches don't work:**
- ❌ **Runtime reflection:** Swift doesn't expose closure internals
- ❌ **Bytecode decompilation:** No public API for SIL/LLVM IR access
- ❌ **Macro-based analysis:** Requires complex compile-time machinery, fragile

### Solution: Expression Builder DSL

Instead of trying to decompile closures, we provide a **declarative expression builder** that constructs an AST we control:

```swift
// Option 1: GPU-compatible (Expression Builder)
var simulation = MonteCarloSimulation(iterations: 100_000) {
    $0[0] * $0[1] - $0[2]  // Expression builder syntax
}

// Option 2: CPU fallback (Traditional closure)
var simulation = MonteCarloSimulation(iterations: 100_000) { inputs in
    let revenue = inputs[0]
    let costs = inputs[1]
    return revenue - costs  // Regular Swift code
}
```

**Key Insight:** The expression builder syntax looks identical to a closure but uses Swift operator overloading to build an expression tree.

---

## Implementation Plan (TDD)

### Iteration 1: Expression Tree Foundation

**Test 1.1: Expression Tree Types** (`ExpressionTreeTests.swift`)

```swift
@Suite("Expression Tree Tests")
struct ExpressionTreeTests {

    @Test("Binary operation creation")
    func testBinaryOperation() throws {
        let left = Expression.input(0)
        let right = Expression.input(1)
        let add = Expression.binary(.add, left, right)

        #expect(add.isAddition)
        #expect(add.leftOperand == .input(0))
        #expect(add.rightOperand == .input(1))
    }

    @Test("Constant value creation")
    func testConstant() throws {
        let constant = Expression.constant(42.0)
        #expect(constant.isConstant)
        #expect(constant.value == 42.0)
    }

    @Test("Input reference creation")
    func testInput() throws {
        let input = Expression.input(3)
        #expect(input.isInput)
        #expect(input.index == 3)
    }

    @Test("Complex expression tree")
    func testComplexExpression() throws {
        // (input[0] * input[1]) - input[2]
        let expr = Expression.binary(
            .subtract,
            Expression.binary(
                .multiply,
                Expression.input(0),
                Expression.input(1)
            ),
            Expression.input(2)
        )

        #expect(expr.isSubtraction)
        #expect(expr.leftOperand?.isMultiplication == true)
        #expect(expr.rightOperand == .input(2))
    }
}
```

**Implementation 1.1: Expression Tree** (`Expression.swift`)

```swift
/// Represents a mathematical expression that can be compiled to GPU bytecode
public indirect enum Expression: Sendable, Equatable {
    /// Reference to an input variable by index
    case input(Int)

    /// Constant floating-point value
    case constant(Double)

    /// Binary operation (add, subtract, multiply, divide)
    case binary(BinaryOp, Expression, Expression)

    /// Unary operation (negate, absolute value, sqrt, etc.)
    case unary(UnaryOp, Expression)

    /// Binary operation types
    public enum BinaryOp: Sendable, Equatable {
        case add, subtract, multiply, divide
        case power, min, max
    }

    /// Unary operation types
    public enum UnaryOp: Sendable, Equatable {
        case negate, abs, sqrt, log, exp
        case sin, cos, tan
    }
}

// Helper computed properties for testing
extension Expression {
    var isAddition: Bool {
        if case .binary(.add, _, _) = self { return true }
        return false
    }

    var isConstant: Bool {
        if case .constant = self { return true }
        return false
    }

    var value: Double? {
        if case .constant(let val) = self { return val }
        return nil
    }

    // ... similar helpers for other types
}
```

---

### Iteration 2: Expression Builder with Operator Overloading

**Test 2.1: Expression Builder Syntax** (`ExpressionBuilderTests.swift`)

```swift
@Suite("Expression Builder Tests")
struct ExpressionBuilderTests {

    @Test("Addition operator")
    func testAddition() throws {
        let builder = ExpressionBuilder()
        let expr = builder[0] + builder[1]

        let expected = Expression.binary(.add, .input(0), .input(1))
        #expect(expr.expression == expected)
    }

    @Test("Subtraction operator")
    func testSubtraction() throws {
        let builder = ExpressionBuilder()
        let expr = builder[0] - builder[1]

        let expected = Expression.binary(.subtract, .input(0), .input(1))
        #expect(expr.expression == expected)
    }

    @Test("Multiplication operator")
    func testMultiplication() throws {
        let builder = ExpressionBuilder()
        let expr = builder[0] * builder[1]

        let expected = Expression.binary(.multiply, .input(0), .input(1))
        #expect(expr.expression == expected)
    }

    @Test("Division operator")
    func testDivision() throws {
        let builder = ExpressionBuilder()
        let expr = builder[0] / builder[1]

        let expected = Expression.binary(.divide, .input(0), .input(1))
        #expect(expr.expression == expected)
    }

    @Test("Compound expression: (a * b) - c")
    func testCompoundExpression() throws {
        let builder = ExpressionBuilder()
        let expr = builder[0] * builder[1] - builder[2]

        let expected = Expression.binary(
            .subtract,
            Expression.binary(.multiply, .input(0), .input(1)),
            .input(2)
        )
        #expect(expr.expression == expected)
    }

    @Test("Constant arithmetic")
    func testConstantArithmetic() throws {
        let builder = ExpressionBuilder()
        let expr = builder[0] * 1.5 + 100.0

        // (input[0] * 1.5) + 100.0
        let expected = Expression.binary(
            .add,
            Expression.binary(.multiply, .input(0), .constant(1.5)),
            .constant(100.0)
        )
        #expect(expr.expression == expected)
    }

    @Test("Financial model: revenue * price - costs")
    func testFinancialModel() throws {
        let builder = ExpressionBuilder()
        let revenue = builder[0]
        let price = builder[1]
        let costs = builder[2]

        let profit = revenue * price - costs

        let expected = Expression.binary(
            .subtract,
            Expression.binary(.multiply, .input(0), .input(1)),
            .input(2)
        )
        #expect(profit.expression == expected)
    }
}
```

**Implementation 2.1: Expression Builder** (`ExpressionBuilder.swift`)

```swift
/// Fluent API for building GPU-compatible mathematical expressions
public struct ExpressionBuilder: Sendable {
    public init() {}

    /// Access input variable by index
    public subscript(index: Int) -> ExpressionProxy {
        return ExpressionProxy(.input(index))
    }
}

/// Proxy type that enables operator overloading for expression building
public struct ExpressionProxy: Sendable {
    internal let expression: Expression

    internal init(_ expression: Expression) {
        self.expression = expression
    }
}

// MARK: - Arithmetic Operators

extension ExpressionProxy {
    // Addition
    public static func + (lhs: ExpressionProxy, rhs: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.add, lhs.expression, rhs.expression))
    }

    public static func + (lhs: ExpressionProxy, rhs: Double) -> ExpressionProxy {
        return ExpressionProxy(.binary(.add, lhs.expression, .constant(rhs)))
    }

    public static func + (lhs: Double, rhs: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.add, .constant(lhs), rhs.expression))
    }

    // Subtraction
    public static func - (lhs: ExpressionProxy, rhs: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.subtract, lhs.expression, rhs.expression))
    }

    public static func - (lhs: ExpressionProxy, rhs: Double) -> ExpressionProxy {
        return ExpressionProxy(.binary(.subtract, lhs.expression, .constant(rhs)))
    }

    public static func - (lhs: Double, rhs: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.subtract, .constant(lhs), rhs.expression))
    }

    // Multiplication
    public static func * (lhs: ExpressionProxy, rhs: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.multiply, lhs.expression, rhs.expression))
    }

    public static func * (lhs: ExpressionProxy, rhs: Double) -> ExpressionProxy {
        return ExpressionProxy(.binary(.multiply, lhs.expression, .constant(rhs)))
    }

    public static func * (lhs: Double, rhs: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.multiply, .constant(lhs), rhs.expression))
    }

    // Division
    public static func / (lhs: ExpressionProxy, rhs: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.divide, lhs.expression, rhs.expression))
    }

    public static func / (lhs: ExpressionProxy, rhs: Double) -> ExpressionProxy {
        return ExpressionProxy(.binary(.divide, lhs.expression, .constant(rhs)))
    }

    public static func / (lhs: Double, rhs: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.divide, .constant(lhs), rhs.expression))
    }

    // Negation
    public static prefix func - (operand: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.unary(.negate, operand.expression))
    }
}

// MARK: - Mathematical Functions

extension ExpressionProxy {
    public func sqrt() -> ExpressionProxy {
        return ExpressionProxy(.unary(.sqrt, expression))
    }

    public func abs() -> ExpressionProxy {
        return ExpressionProxy(.unary(.abs, expression))
    }

    public func log() -> ExpressionProxy {
        return ExpressionProxy(.unary(.log, expression))
    }

    public func exp() -> ExpressionProxy {
        return ExpressionProxy(.unary(.exp, expression))
    }

    public func power(_ exponent: Double) -> ExpressionProxy {
        return ExpressionProxy(.binary(.power, expression, .constant(exponent)))
    }

    public func min(_ other: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.min, expression, other.expression))
    }

    public func max(_ other: ExpressionProxy) -> ExpressionProxy {
        return ExpressionProxy(.binary(.max, expression, other.expression))
    }
}
```

---

### Iteration 3: Bytecode Compiler

**Test 3.1: Bytecode Generation** (`BytecodeCompilerTests.swift`)

```swift
@Suite("Bytecode Compiler Tests")
struct BytecodeCompilerTests {

    @Test("Compile addition: a + b")
    func testAddition() throws {
        let expr = Expression.binary(.add, .input(0), .input(1))
        let bytecode = try BytecodeCompiler.compile(expr)

        let expected: [Bytecode] = [
            .input(0),
            .input(1),
            .add
        ]
        #expect(bytecode == expected)
    }

    @Test("Compile multiplication: a * b")
    func testMultiplication() throws {
        let expr = Expression.binary(.multiply, .input(0), .input(1))
        let bytecode = try BytecodeCompiler.compile(expr)

        let expected: [Bytecode] = [
            .input(0),
            .input(1),
            .multiply
        ]
        #expect(bytecode == expected)
    }

    @Test("Compile compound: (a * b) - c")
    func testCompoundExpression() throws {
        let expr = Expression.binary(
            .subtract,
            Expression.binary(.multiply, .input(0), .input(1)),
            .input(2)
        )
        let bytecode = try BytecodeCompiler.compile(expr)

        let expected: [Bytecode] = [
            .input(0),
            .input(1),
            .multiply,
            .input(2),
            .subtract
        ]
        #expect(bytecode == expected)
    }

    @Test("Compile constant: a * 1.5")
    func testConstant() throws {
        let expr = Expression.binary(.multiply, .input(0), .constant(1.5))
        let bytecode = try BytecodeCompiler.compile(expr)

        let expected: [Bytecode] = [
            .input(0),
            .constant(1.5),
            .multiply
        ]
        #expect(bytecode == expected)
    }

    @Test("Compile complex financial model")
    func testFinancialModel() throws {
        // (revenue * price) - (costs * (1 + tax))
        let expr = Expression.binary(
            .subtract,
            Expression.binary(.multiply, .input(0), .input(1)),  // revenue * price
            Expression.binary(
                .multiply,
                .input(2),  // costs
                Expression.binary(.add, .constant(1.0), .input(3))  // 1 + tax
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

    @Test("Convert bytecode to GPU format")
    func testGPUBytecodeConversion() throws {
        let expr = Expression.binary(.add, .input(0), .input(1))
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
}
```

**Implementation 3.1: Bytecode Compiler** (`BytecodeCompiler.swift`)

```swift
/// High-level bytecode representation
public enum Bytecode: Sendable, Equatable {
    case input(Int)
    case constant(Double)
    case add, subtract, multiply, divide
    case negate, abs, sqrt, log, exp
    case power, min, max
    case sin, cos, tan
}

/// Compiles Expression trees to stack-based bytecode
public struct BytecodeCompiler {

    /// Compile an expression tree to bytecode
    public static func compile(_ expression: Expression) throws -> [Bytecode] {
        var bytecode: [Bytecode] = []
        try compileRecursive(expression, into: &bytecode)
        return bytecode
    }

    /// Recursive compilation (post-order traversal)
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
            case .add:      bytecode.append(.add)
            case .subtract: bytecode.append(.subtract)
            case .multiply: bytecode.append(.multiply)
            case .divide:   bytecode.append(.divide)
            case .power:    bytecode.append(.power)
            case .min:      bytecode.append(.min)
            case .max:      bytecode.append(.max)
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
        }
    }

    /// Convert bytecode to GPU format: (opcode, arg1, arg2)
    public static func toGPUFormat(_ bytecode: [Bytecode]) -> [(opcode: Int32, arg1: Int32, arg2: Float)] {
        var gpu: [(Int32, Int32, Float)] = []

        for instruction in bytecode {
            switch instruction {
            case .input(let index):
                gpu.append((4, Int32(index), 0.0))  // INPUT opcode = 4

            case .constant(let value):
                gpu.append((5, 0, Float(value)))    // CONST opcode = 5

            case .add:      gpu.append((0, 0, 0.0))  // ADD opcode = 0
            case .subtract: gpu.append((1, 0, 0.0))  // SUB opcode = 1
            case .multiply: gpu.append((2, 0, 0.0))  // MUL opcode = 2
            case .divide:   gpu.append((3, 0, 0.0))  // DIV opcode = 3
            case .power:    gpu.append((6, 0, 0.0))  // POW opcode = 6
            case .min:      gpu.append((7, 0, 0.0))  // MIN opcode = 7
            case .max:      gpu.append((8, 0, 0.0))  // MAX opcode = 8
            case .negate:   gpu.append((9, 0, 0.0))  // NEG opcode = 9
            case .abs:      gpu.append((10, 0, 0.0)) // ABS opcode = 10
            case .sqrt:     gpu.append((11, 0, 0.0)) // SQRT opcode = 11
            case .log:      gpu.append((12, 0, 0.0)) // LOG opcode = 12
            case .exp:      gpu.append((13, 0, 0.0)) // EXP opcode = 13
            case .sin:      gpu.append((14, 0, 0.0)) // SIN opcode = 14
            case .cos:      gpu.append((15, 0, 0.0)) // COS opcode = 15
            case .tan:      gpu.append((16, 0, 0.0)) // TAN opcode = 16
            }
        }

        return gpu
    }
}
```

---

### Iteration 4: Bytecode Optimizer

**Test 4.1: Optimization Passes** (`BytecodeOptimizerTests.swift`)

```swift
@Suite("Bytecode Optimizer Tests")
struct BytecodeOptimizerTests {

    @Test("Constant folding: 5.0 + 3.0 → 8.0")
    func testConstantFolding() throws {
        let expr = Expression.binary(.add, .constant(5.0), .constant(3.0))
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let expected: [Bytecode] = [.constant(8.0)]
        #expect(optimized == expected)
    }

    @Test("Constant folding: a * 1.0 → a")
    func testMultiplyByOne() throws {
        let expr = Expression.binary(.multiply, .input(0), .constant(1.0))
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let expected: [Bytecode] = [.input(0)]
        #expect(optimized == expected)
    }

    @Test("Constant folding: a + 0.0 → a")
    func testAddZero() throws {
        let expr = Expression.binary(.add, .input(0), .constant(0.0))
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let expected: [Bytecode] = [.input(0)]
        #expect(optimized == expected)
    }

    @Test("Constant folding: a - 0.0 → a")
    func testSubtractZero() throws {
        let expr = Expression.binary(.subtract, .input(0), .constant(0.0))
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let expected: [Bytecode] = [.input(0)]
        #expect(optimized == expected)
    }

    @Test("Complex optimization: (a + 0) * 1 + (5 * 2)")
    func testComplexOptimization() throws {
        // (a + 0) * 1 + (5 * 2) → a + 10
        let expr = Expression.binary(
            .add,
            Expression.binary(
                .multiply,
                Expression.binary(.add, .input(0), .constant(0.0)),
                .constant(1.0)
            ),
            Expression.binary(.multiply, .constant(5.0), .constant(2.0))
        )

        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)

        let expected: [Bytecode] = [
            .input(0),
            .constant(10.0),
            .add
        ]
        #expect(optimized == expected)
    }
}
```

**Implementation 4.1: Bytecode Optimizer** (`BytecodeOptimizer.swift`)

```swift
/// Optimizes bytecode by applying various optimization passes
public struct BytecodeOptimizer {

    /// Apply all optimization passes to bytecode
    public static func optimize(_ bytecode: [Bytecode]) -> [Bytecode] {
        var optimized = bytecode

        // Multiple passes until no changes
        var changed = true
        var iterations = 0
        while changed && iterations < 10 {
            let before = optimized
            optimized = constantFolding(optimized)
            optimized = algebraicSimplification(optimized)
            changed = (optimized != before)
            iterations += 1
        }

        return optimized
    }

    /// Fold constant expressions at compile-time
    private static func constantFolding(_ bytecode: [Bytecode]) -> [Bytecode] {
        var stack: [Bytecode] = []

        for instruction in bytecode {
            switch instruction {
            case .add, .subtract, .multiply, .divide, .power, .min, .max:
                // Try to fold binary operation
                if stack.count >= 2,
                   case .constant(let right) = stack.removeLast(),
                   case .constant(let left) = stack.removeLast() {

                    let result: Double
                    switch instruction {
                    case .add:      result = left + right
                    case .subtract: result = left - right
                    case .multiply: result = left * right
                    case .divide:   result = left / right
                    case .power:    result = pow(left, right)
                    case .min:      result = Swift.min(left, right)
                    case .max:      result = Swift.max(left, right)
                    default: fatalError("Unreachable")
                    }

                    stack.append(.constant(result))
                } else {
                    // Can't fold, restore stack
                    if case .constant(let val) = stack.last {
                        stack.removeLast()
                        stack.append(.constant(val))
                    }
                    stack.append(instruction)
                }

            case .negate, .abs, .sqrt, .log, .exp, .sin, .cos, .tan:
                // Try to fold unary operation
                if case .constant(let value) = stack.removeLast() {
                    let result: Double
                    switch instruction {
                    case .negate: result = -value
                    case .abs:    result = abs(value)
                    case .sqrt:   result = sqrt(value)
                    case .log:    result = log(value)
                    case .exp:    result = exp(value)
                    case .sin:    result = sin(value)
                    case .cos:    result = cos(value)
                    case .tan:    result = tan(value)
                    default: fatalError("Unreachable")
                    }

                    stack.append(.constant(result))
                } else {
                    stack.append(instruction)
                }

            default:
                stack.append(instruction)
            }
        }

        return stack
    }

    /// Simplify algebraic identities (a + 0 = a, a * 1 = a, etc.)
    private static func algebraicSimplification(_ bytecode: [Bytecode]) -> [Bytecode] {
        var result: [Bytecode] = []
        var i = 0

        while i < bytecode.count {
            // Look ahead for patterns like: [input, constant(0), add]
            if i + 2 < bytecode.count {
                let first = bytecode[i]
                let second = bytecode[i + 1]
                let third = bytecode[i + 2]

                // a + 0 = a
                if case .constant(0.0) = second, case .add = third {
                    result.append(first)
                    i += 3
                    continue
                }

                // a - 0 = a
                if case .constant(0.0) = second, case .subtract = third {
                    result.append(first)
                    i += 3
                    continue
                }

                // a * 1 = a
                if case .constant(1.0) = second, case .multiply = third {
                    result.append(first)
                    i += 3
                    continue
                }

                // a / 1 = a
                if case .constant(1.0) = second, case .divide = third {
                    result.append(first)
                    i += 3
                    continue
                }

                // a * 0 = 0
                if case .constant(0.0) = second, case .multiply = third {
                    result.append(.constant(0.0))
                    i += 3
                    continue
                }
            }

            result.append(bytecode[i])
            i += 1
        }

        return result
    }
}
```

---

### Iteration 5: Integration with MonteCarloSimulation

**Test 5.1: End-to-End GPU Execution** (`ModelCompilationIntegrationTests.swift`)

```swift
@Suite("Model Compilation Integration Tests")
struct ModelCompilationIntegrationTests {

    @Test("Simple addition model on GPU")
    func testSimpleAddition() throws {
        #if canImport(Metal)
        guard MetalDevice.shared != nil else { return }

        var simulation = MonteCarloSimulation(iterations: 10_000) { builder in
            builder[0] + builder[1]
        }

        simulation.addInput(SimulationInput(
            name: "A",
            distribution: DistributionNormal(100.0, 10.0)
        ))
        simulation.addInput(SimulationInput(
            name: "B",
            distribution: DistributionNormal(50.0, 5.0)
        ))

        let results = try simulation.run()

        // Should use GPU
        #expect(results.usedGPU == true)

        // Statistical validation
        #expect(abs(results.statistics.mean - 150.0) < 2.0)
        #endif
    }

    @Test("Financial model on GPU")
    func testFinancialModel() throws {
        #if canImport(Metal)
        guard MetalDevice.shared != nil else { return }

        var simulation = MonteCarloSimulation(iterations: 50_000) { builder in
            let revenue = builder[0]
            let price = builder[1]
            let costs = builder[2]
            return revenue * price - costs
        }

        simulation.addInput(SimulationInput(
            name: "Revenue",
            distribution: DistributionNormal(1_000_000.0, 100_000.0)
        ))
        simulation.addInput(SimulationInput(
            name: "Price",
            distribution: DistributionUniform(0.9, 1.1)
        ))
        simulation.addInput(SimulationInput(
            name: "Costs",
            distribution: DistributionNormal(700_000.0, 50_000.0)
        ))

        let results = try simulation.run()

        // Should use GPU
        #expect(results.usedGPU == true)

        // Mean profit ~300K
        #expect(results.statistics.mean > 200_000.0)
        #expect(results.statistics.mean < 400_000.0)

        // Risk of loss < 5%
        let riskOfLoss = results.probabilityBelow(0.0)
        #expect(riskOfLoss < 0.05)

        print("✓ Financial model GPU execution:")
        print("  Mean profit: \(results.statistics.mean.currency())")
        print("  Risk of loss: \(riskOfLoss.percent())")
        #endif
    }

    @Test("GPU vs CPU equivalence with compiled models")
    func testGPUvsCPUEquivalence() throws {
        #if canImport(Metal)
        guard MetalDevice.shared != nil else { return }

        // GPU version (expression builder)
        var gpuSim = MonteCarloSimulation(iterations: 10_000) { builder in
            builder[0] * builder[1] - builder[2]
        }
        gpuSim.addInput(SimulationInput(name: "A", distribution: DistributionNormal(100.0, 15.0)))
        gpuSim.addInput(SimulationInput(name: "B", distribution: DistributionNormal(50.0, 10.0)))
        gpuSim.addInput(SimulationInput(name: "C", distribution: DistributionNormal(4500.0, 500.0)))

        // CPU version (traditional closure)
        var cpuSim = MonteCarloSimulation(iterations: 10_000, enableGPU: false) { inputs in
            return inputs[0] * inputs[1] - inputs[2]
        }
        cpuSim.addInput(SimulationInput(name: "A", distribution: DistributionNormal(100.0, 15.0)))
        cpuSim.addInput(SimulationInput(name: "B", distribution: DistributionNormal(50.0, 10.0)))
        cpuSim.addInput(SimulationInput(name: "C", distribution: DistributionNormal(4500.0, 500.0)))

        let gpuResults = try gpuSim.run()
        let cpuResults = try cpuSim.run()

        #expect(gpuResults.usedGPU == true)
        #expect(cpuResults.usedGPU == false)

        // Means should be within 5%
        let meanDiff = abs(gpuResults.statistics.mean - cpuResults.statistics.mean) / abs(cpuResults.statistics.mean)
        #expect(meanDiff < 0.05)

        print("✓ GPU vs CPU equivalence:")
        print("  GPU mean: \(gpuResults.statistics.mean)")
        print("  CPU mean: \(cpuResults.statistics.mean)")
        print("  Difference: \(meanDiff * 100)%")
        #endif
    }
}
```

**Implementation 5.1: Update MonteCarloSimulation**

```swift
// Update initializer to accept expression builder
public init(
    iterations: Int,
    enableGPU: Bool = true,
    model: @escaping @Sendable (ExpressionBuilder) -> ExpressionProxy
) {
    self.iterations = iterations
    self.enableGPU = enableGPU

    // Compile expression to bytecode
    let builder = ExpressionBuilder()
    let exprProxy = model(builder)
    self.compiledExpression = exprProxy.expression

    // Create CPU fallback closure
    self.model = { inputs in
        return ExpressionEvaluator.evaluate(exprProxy.expression, inputs: inputs)
    }

    self.inputs = []

    #if canImport(Metal)
    if enableGPU {
        self.gpuDevice = MonteCarloGPUDevice()
    } else {
        self.gpuDevice = nil
    }
    #endif
}

// Update compileModelForGPU to use compiled expression
private func compileModelForGPU() -> [(opcode: Int32, arg1: Int32, arg2: Float)]? {
    guard let expr = compiledExpression else { return nil }

    do {
        let bytecode = try BytecodeCompiler.compile(expr)
        let optimized = BytecodeOptimizer.optimize(bytecode)
        return BytecodeCompiler.toGPUFormat(optimized)
    } catch {
        return nil  // Compilation failed, fall back to CPU
    }
}
```

---

## Files to Create

### New Files (7 files, ~1500 lines)

**Implementation:**
```
Sources/BusinessMath/Simulation/MonteCarlo/Compilation/
├── Expression.swift                     ~150 lines
├── ExpressionBuilder.swift              ~250 lines
├── BytecodeCompiler.swift               ~200 lines
├── BytecodeOptimizer.swift              ~150 lines
└── ExpressionEvaluator.swift            ~100 lines (CPU interpreter)
```

**Tests:**
```
Tests/BusinessMathTests/Simulation Tests/Compilation/
├── ExpressionTreeTests.swift            ~150 lines
├── ExpressionBuilderTests.swift         ~200 lines
├── BytecodeCompilerTests.swift          ~200 lines
├── BytecodeOptimizerTests.swift         ~150 lines
└── ModelCompilationIntegrationTests.swift ~200 lines
```

### Modified Files (1 file)

**MonteCarloSimulation.swift** (~50 lines modified)
- Add expression builder initializer
- Store `compiledExpression: Expression?`
- Update `compileModelForGPU()` to compile expression
- Add CPU interpreter fallback

---

## Expected Outcomes

### After Phase 2 Completion

✅ **Full GPU Pipeline Working**
- Users define models with expression builder
- Automatic compilation to GPU bytecode
- Bytecode optimization (constant folding, algebraic simplification)
- GPU execution with statistical validation
- Transparent CPU fallback

✅ **Performance**
- 10-100x speedup for 10K-1M iterations
- < 1ms compilation overhead
- Optimized bytecode (5-10% reduction in instructions)

✅ **API Examples**

```swift
// GPU-compiled model (new API)
var gpuSim = MonteCarloSimulation(iterations: 100_000) { $0 in
    $0[0] * $0[1] - $0[2]  // Compiles to GPU
}

// Traditional closure (backward compatible)
var cpuSim = MonteCarloSimulation(iterations: 100_000) { inputs in
    return inputs[0] * inputs[1] - inputs[2]  // CPU only
}

// Both work identically from user perspective
```

---

## Risk Mitigation

### Risk 1: Expression Builder Syntax Unfamiliar

**Mitigation:**
- Provide clear documentation with examples
- Support both syntaxes (builder + closure)
- Migration guide for existing code

### Risk 2: Limited Expression Support

**Phase 2 Scope:**
- Arithmetic: +, -, *, /
- Math functions: sqrt, abs, log, exp, power
- Comparisons (future): min, max

**Not Supported:**
- Control flow (if/else)
- Loops
- Custom functions

**Mitigation:** Automatic CPU fallback for unsupported constructs

### Risk 3: Optimizer Bugs

**Mitigation:**
- Extensive test coverage (20+ optimization tests)
- Validate optimized bytecode produces same results
- Disable optimizer if bugs found (compilation still works)

---

## Success Criteria

- ✅ All new tests passing (25+ tests)
- ✅ Expression builder compiles to correct bytecode
- ✅ Optimizer reduces instruction count by 5-10%
- ✅ GPU execution produces statistically equivalent results (< 1% mean difference)
- ✅ Backward compatible (existing closure API still works)
- ✅ Financial model example runs on GPU with 20x+ speedup

---

## Timeline

**Estimated:** 2-3 sessions

- **Session 1:** Expression tree + builder (Iterations 1-2)
- **Session 2:** Bytecode compiler + optimizer (Iterations 3-4)
- **Session 3:** Integration + validation (Iteration 5)

---

## Next Phase: Phase 3

After Phase 2 completion:

**Phase 3A: Extended GPU Distribution Support**
- Implement Weibull, Rayleigh, Bernoulli on GPU
- Add distribution-specific optimizations
- Expand GPU coverage to 90%+ of use cases

**Phase 3B: Performance Benchmarking**
- Create comprehensive benchmark suite
- Profile GPU utilization
- Document performance characteristics
- Publish performance guide

Then proceed with MCP integration once all distributions are GPU-accelerated.

---

**Author:** Justin Purnell
**Date:** January 29, 2026
**Status:** Ready to implement

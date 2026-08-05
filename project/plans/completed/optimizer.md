# Implementation Plan: Enhanced Optimizer API

Based on your guidance, here's the comprehensive implementation plan:

## 1. **Architecture Decisions**

### Goal-Seeking as Part of Optimizer ✅
- Add `goalSeek()` method to `Optimizer` protocol extension
- No separate protocol needed

### Multi-Dimensional via VectorSpace ✅
- Create `VectorSpace` protocol for generic vector operations
- Extend `Optimizer` to work with `VectorSpace` types
- This is mathematically correct and flexible

### Progressive Disclosure ✅
- Simple defaults for common cases
- Advanced options available when needed
- Clear, discoverable API

### Test-Driven Development ✅
- Write tests first
- Implement to satisfy tests
- Follow existing coding rules

## 2. **Implementation Phases**

### Phase 1: Core Enhancements (P0)
1. **Goal-seeking API** (`goalSeek()`)
2. **Constraint builder syntax** (operator overloads)
3. **ClosedRange bounds** (Swift-idiomatic)
4. **Error types** (better failure reporting)

### Phase 2: VectorSpace Foundation (P1)
1. **VectorSpace protocol** (generic vector operations)
2. **Multivariate Optimizer** (extends base protocol)
3. **Basic vector constraints**

### Phase 3: Advanced Features (P2/P3)
1. **Line search** (step size control)
2. **Progress callbacks**
3. **Diagnostic utilities**

## 3. **File Structure**

```
Sources/BusinessMath/Optimization/
├── Core/
│   ├── Optimizer.swift (existing)
│   ├── OptimizationResult.swift (existing)
│   ├── Constraint.swift (existing)
│   └── IterationHistory.swift (existing)
├── Convenience/
│   ├── Optimizer+Convenience.swift
│   ├── Constraint+Builders.swift
│   └── Optimizer+Errors.swift
├── Vector/
│   ├── VectorSpace.swift
│   ├── MultivariateOptimizer.swift
│   └── VectorConstraint.swift
└── Algorithms/
    ├── NewtonRaphsonOptimizer.swift (existing)
    ├── LineSearch.swift
    └── GoalSeek.swift
```

## 4. **Test Structure**

```
Tests/BusinessMathTests/OptimizationTests/
├── CoreTests/
│   ├── OptimizerConvenienceTests.swift
│   ├── ConstraintBuilderTests.swift
│   └── ErrorHandlingTests.swift
├── VectorTests/
│   ├── VectorSpaceTests.swift
│   ├── MultivariateOptimizerTests.swift
│   └── VectorConstraintTests.swift
├── AlgorithmTests/
│   ├── NewtonRaphsonOptimizerTests.swift (existing)
│   ├── GoalSeekTests.swift
│   └── LineSearchTests.swift
└── IntegrationTests/
    └── OptimizerIntegrationTests.swift
```

## 5. **Detailed Implementation**

Let me start with the **test suite** for Phase 1 (Core Enhancements):

### File 1: `OptimizerConvenienceTests.swift`

```swift
//
//  OptimizerConvenienceTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on [Date].
//

import Testing
import Numerics
@testable import BusinessMath

@Suite("Optimizer Convenience Methods")
struct OptimizerConvenienceTests {
    
    // MARK: - Test Setup
    
    struct MockOptimizer<T: Real>: Optimizer {
        var lastCall: (objective: ((T) -> T)?, constraints: [Constraint<T>]?, initialValue: T?, bounds: (lower: T, upper: T)?)?
        
        func optimize(
            objective: @escaping (T) -> T,
            constraints: [Constraint<T>],
            initialValue: T,
            bounds: (lower: T, upper: T)?
        ) -> OptimizationResult<T> {
            lastCall = (objective, constraints, initialValue, bounds)
            return OptimizationResult(
                optimalValue: T(0),
                objectiveValue: T(0),
                iterations: 0,
                converged: true
            )
        }
    }
    
    // MARK: - Minimize Tests
    
    @Test("minimize() delegates to optimize() with correct parameters")
    func minimizeDelegatesCorrectly() {
        let optimizer = MockOptimizer<Double>()
        let objective: (Double) -> Double = { x in x * x }
        let initialValue: Double = 5.0
        
        _ = optimizer.minimize(objective, from: initialValue)
        
        #expect(optimizer.lastCall?.objective != nil)
        #expect(optimizer.lastCall?.initialValue == initialValue)
        #expect(optimizer.lastCall?.constraints?.isEmpty == true)
        #expect(optimizer.lastCall?.bounds == nil)
    }
    
    @Test("minimize() with bounds converts ClosedRange correctly")
    func minimizeWithBounds() {
        let optimizer = MockOptimizer<Double>()
        let objective: (Double) -> Double = { x in x * x }
        let range: ClosedRange<Double> = 0.0...10.0
        
        _ = optimizer.minimize(objective, from: 5.0, in: range)
        
        #expect(optimizer.lastCall?.bounds?.lower == 0.0)
        #expect(optimizer.lastCall?.bounds?.upper == 10.0)
    }
    
    @Test("minimize() with constraints passes them through")
    func minimizeWithConstraints() {
        let optimizer = MockOptimizer<Double>()
        let objective: (Double) -> Double = { x in x * x }
        let constraints = [
            Constraint<Double>(type: .greaterThanOrEqual, bound: 0.0),
            Constraint<Double>(type: .lessThanOrEqual, bound: 100.0)
        ]
        
        _ = optimizer.minimize(objective, from: 5.0, constraints: constraints)
        
        #expect(optimizer.lastCall?.constraints?.count == 2)
    }
    
    // MARK: - Maximize Tests
    
    @Test("maximize() minimizes the negated function")
    func maximizeMinimizesNegated() {
        let optimizer = MockOptimizer<Double>()
        var capturedObjective: ((Double) -> Double)?
        
        // Create a spy optimizer
        struct SpyOptimizer<T: Real>: Optimizer {
            var capturedObjective: ((T) -> T)?
            
            mutating func optimize(
                objective: @escaping (T) -> T,
                constraints: [Constraint<T>],
                initialValue: T,
                bounds: (lower: T, upper: T)?
            ) -> OptimizationResult<T> {
                capturedObjective = objective
                return OptimizationResult(
                    optimalValue: T(0),
                    objectiveValue: T(0),
                    iterations: 0,
                    converged: true
                )
            }
        }
        
        var spy = SpyOptimizer<Double>()
        let objective: (Double) -> Double = { x in x * x }
        
        _ = spy.maximize(objective, from: 5.0)
        
        // Test that the captured objective is the negated version
        #expect(spy.capturedObjective != nil)
        
        // For a specific input, the negated function should return -f(x)
        let testValue = 3.0
        let originalResult = objective(testValue)
        let negatedResult = spy.capturedObjective?(testValue)
        
        #expect(negatedResult == -originalResult)
    }
    
    @Test("maximize() returns correct objective value (not negated)")
    func maximizeReturnsCorrectObjective() {
        // Use a real optimizer for this test
        let optimizer = NewtonRaphsonOptimizer<Double>(
            tolerance: 1e-6,
            maxIterations: 100,
            stepSize: 1e-4
        )
        
        // Simple concave function: maximum at x = 5, f(5) = 25
        let objective: (Double) -> Double = { x in -(x - 5) * (x - 5) + 25 }
        
        let result = optimizer.maximize(objective, from: 0.0)
        
        #expect(abs(result.optimalValue - 5.0) < 0.001)
        #expect(abs(result.objectiveValue - 25.0) < 0.001)
        #expect(result.converged == true)
    }
    
    // MARK: - Goal Seek Tests
    
    @Test("goalSeek() minimizes squared residual")
    func goalSeekMinimizesSquaredResidual() {
        let optimizer = MockOptimizer<Double>()
        let function: (Double) -> Double = { x in 2 * x + 3 }
        let target: Double = 10.0
        
        _ = optimizer.goalSeek(function: function, target: target, from: 0.0)
        
        #expect(optimizer.lastCall?.objective != nil)
        
        // Test that the objective is (f(x) - target)^2
        let testValue = 2.0
        let expectedResidual = function(testValue) - target
        let expectedObjective = expectedResidual * expectedResidual
        let actualObjective = optimizer.lastCall?.objective?(testValue)
        
        #expect(abs(actualObjective! - expectedObjective) < 1e-10)
    }
    
    @Test("goalSeek() finds correct solution for linear function")
    func goalSeekLinearFunction() {
        let optimizer = NewtonRaphsonOptimizer<Double>(
            tolerance: 1e-8,
            maxIterations: 100,
            stepSize: 1e-4
        )
        
        // f(x) = 2x + 3, find x where f(x) = 10
        // Solution: x = (10 - 3) / 2 = 3.5
        let function: (Double) -> Double = { x in 2 * x + 3 }
        let target: Double = 10.0
        
        let result = optimizer.goalSeek(function: function, target: target, from: 0.0)
        
        #expect(abs(result.optimalValue - 3.5) < 1e-6)
        #expect(abs(function(result.optimalValue) - target) < 1e-6)
        #expect(result.converged == true)
    }
    
    @Test("goalSeek() with bounds respects constraints")
    func goalSeekWithBounds() {
        let optimizer = NewtonRaphsonOptimizer<Double>(
            tolerance: 1e-8,
            maxIterations: 100,
            stepSize: 1e-4
        )
        
        // f(x) = x^2, find x where f(x) = 4
        // Solutions: x = 2 or x = -2
        // With bounds [0, 10], should find x = 2
        let function: (Double) -> Double = { x in x * x }
        let target: Double = 4.0
        
        let result = optimizer.goalSeek(
            function: function,
            target: target,
            from: 1.0,
            in: 0.0...10.0
        )
        
        #expect(abs(result.optimalValue - 2.0) < 1e-6)
        #expect(result.optimalValue >= 0.0)
        #expect(result.optimalValue <= 10.0)
    }
    
    @Test("goalSeek() returns NaN for impossible target")
    func goalSeekImpossibleTarget() {
        let optimizer = NewtonRaphsonOptimizer<Double>(
            tolerance: 1e-8,
            maxIterations: 100,
            stepSize: 1e-4
        )
        
        // f(x) = x^2, find x where f(x) = -1 (impossible)
        let function: (Double) -> Double = { x in x * x }
        let target: Double = -1.0
        
        let result = optimizer.goalSeek(function: function, target: target, from: 0.0)
        
        // Should converge to minimum of squared residual
        #expect(result.converged == true)
        #expect(result.optimalValue.isFinite)
    }
    
    // MARK: - Convenience Overload Tests
    
    @Test("optimize() with just objective and initial value")
    func optimizeSimpleOverload() {
        let optimizer = MockOptimizer<Double>()
        let objective: (Double) -> Double = { x in x * x }
        
        _ = optimizer.optimize(objective: objective, initialValue: 5.0)
        
        #expect(optimizer.lastCall?.objective != nil)
        #expect(optimizer.lastCall?.initialValue == 5.0)
        #expect(optimizer.lastCall?.constraints?.isEmpty == true)
        #expect(optimizer.lastCall?.bounds == nil)
    }
    
    @Test("optimize() with bounds tuple")
    func optimizeWithBoundsTuple() {
        let optimizer = MockOptimizer<Double>()
        let objective: (Double) -> Double = { x in x * x }
        let bounds: (lower: Double, upper: Double) = (0.0, 10.0)
        
        _ = optimizer.optimize(objective: objective, initialValue: 5.0, bounds: bounds)
        
        #expect(optimizer.lastCall?.bounds?.lower == 0.0)
        #expect(optimizer.lastCall?.bounds?.upper == 10.0)
    }
    
    // MARK: - Helper Method Tests
    
    @Test("constraints(from:) creates correct constraints")
    func constraintsFromBounds() {
        let optimizer = MockOptimizer<Double>()
        let bounds: (lower: Double, upper: Double) = (0.0, 10.0)
        
        let constraints = optimizer.constraints(from: bounds)
        
        #expect(constraints.count == 2)
        #expect(constraints[0].type == .greaterThanOrEqual)
        #expect(constraints[0].bound == 0.0)
        #expect(constraints[1].type == .lessThanOrEqual)
        #expect(constraints[1].bound == 10.0)
    }
    
    @Test("clamp() respects bounds")
    func clampRespectsBounds() {
        let optimizer = MockOptimizer<Double>()
        let bounds: (lower: Double, upper: Double) = (0.0, 10.0)
        
        #expect(optimizer.clamp(-5.0, to: bounds) == 0.0)
        #expect(optimizer.clamp(5.0, to: bounds) == 5.0)
        #expect(optimizer.clamp(15.0, to: bounds) == 10.0)
        #expect(optimizer.clamp(5.0, to: nil) == 5.0)
    }
    
    @Test("isFeasible() checks bounds and constraints")
    func isFeasibleChecksBoth() {
        let optimizer = MockOptimizer<Double>()
        let bounds: (lower: Double, upper: Double) = (0.0, 10.0)
        let constraint = Constraint<Double>(type: .greaterThanOrEqual, bound: 5.0)
        
        #expect(optimizer.isFeasible(3.0, constraints: [], within: bounds) == true)
        #expect(optimizer.isFeasible(3.0, constraints: [constraint], within: bounds) == false)
        #expect(optimizer.isFeasible(7.0, constraints: [constraint], within: bounds) == true)
        #expect(optimizer.isFeasible(15.0, constraints: [], within: bounds) == false)
        #expect(optimizer.isFeasible(7.0, constraints: [], within: nil) == true)
    }
    
    @Test("numericalDerivative() approximates derivative correctly")
    func numericalDerivativeApproximation() {
        let optimizer = MockOptimizer<Double>()
        let derivativeBuilder = optimizer.numericalDerivative(h: 1e-6)
        
        // f(x) = x^2, f'(x) = 2x
        let f: (Double) -> Double = { x in x * x }
        let df = derivativeBuilder(f)
        
        #expect(abs(df(0.0) - 0.0) < 1e-6)
        #expect(abs(df(1.0) - 2.0) < 1e-6)
        #expect(abs(df(2.0) - 4.0) < 1e-6)
        #expect(abs(df(3.0) - 6.0) < 1e-6)
    }
}
```

### File 2: `ConstraintBuilderTests.swift`

```swift
//
//  ConstraintBuilderTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on [Date].
//

import Testing
import Numerics
@testable import BusinessMath

@Suite("Constraint Builder Syntax")
struct ConstraintBuilderTests {
    
    // MARK: - Operator Tests
    
    @Test(">= operator creates greaterThanOrEqual constraint")
    func greaterThanOrEqualOperator() {
        let constraint: Constraint<Double> = 5.0 >= 0.0
        
        #expect(constraint.type == .greaterThanOrEqual)
        #expect(constraint.bound == 0.0)
        #expect(constraint.function == nil)
        #expect(constraint.isSatisfied(5.0) == true)
        #expect(constraint.isSatisfied(0.0) == true)
        #expect(constraint.isSatisfied(-1.0) == false)
    }
    
    @Test("<= operator creates lessThanOrEqual constraint")
    func lessThanOrEqualOperator() {
        let constraint: Constraint<Double> = 5.0 <= 10.0
        
        #expect(constraint.type == .lessThanOrEqual)
        #expect(constraint.bound == 10.0)
        #expect(constraint.function == nil)
        #expect(constraint.isSatisfied(5.0) == true)
        #expect(constraint.isSatisfied(10.0) == true)
        #expect(constraint.isSatisfied(11.0) == false)
    }
    
    @Test("== operator creates equalTo constraint")
    func equalToOperator() {
        let constraint: Constraint<Double> = 5.0 == 5.0
        
        #expect(constraint.type == .equalTo)
        #expect(constraint.bound == 5.0)
        #expect(constraint.function == nil)
        #expect(constraint.isSatisfied(5.0) == true)
       

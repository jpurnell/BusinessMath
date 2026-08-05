# Comprehensive Optimizer Enhancement Implementation Plan

## Overview

This plan implements a complete, ergonomic optimization API for BusinessMath with:
1. **Goal-seeking** as part of the Optimizer protocol
2. **Multi-dimensional support** via VectorSpace protocol
3. **Progressive disclosure** API design
4. **Test-driven development** with comprehensive test suite

## Phase 1: Core Convenience Methods (Scalar Optimization)

### Step 1.1: Enhanced Optimizer Protocol Extension

**File:** `Sources/BusinessMath/Optimization/Optimizer+Convenience.swift`

```swift
/// Enhanced convenience methods for scalar optimization
public extension Optimizer {
    /// Common bounds tuple for scalar optimizers
    typealias Bounds = (lower: T, upper: T)
    
    // MARK: - Minimization Convenience
    
    /// Minimize a function starting from an initial value.
    ///
    /// - Parameters:
    ///   - objective: The function to minimize.
    ///   - initialValue: Starting point for optimization.
    ///   - bounds: Optional bounds for the solution.
    ///   - constraints: Optional constraints to satisfy.
    /// - Returns: Optimization result with minimum found.
    func minimize(
        _ objective: @escaping (T) -> T,
        from initialValue: T,
        bounds: Bounds? = nil,
        constraints: [Constraint<T>] = []
    ) -> OptimizationResult<T>
    
    /// Minimize a function within a Swift-idiomatic range.
    ///
    /// - Parameters:
    ///   - objective: The function to minimize.
    ///   - initialValue: Starting point for optimization.
    ///   - range: Optional closed range for the solution.
    ///   - constraints: Optional constraints to satisfy.
    /// - Returns: Optimization result with minimum found.
    func minimize(
        _ objective: @escaping (T) -> T,
        from initialValue: T,
        in range: ClosedRange<T>? = nil,
        constraints: [Constraint<T>] = []
    ) -> OptimizationResult<T>
    
    // MARK: - Maximization Convenience
    
    /// Maximize a function starting from an initial value.
    ///
    /// - Parameters:
    ///   - objective: The function to maximize.
    ///   - initialValue: Starting point for optimization.
    ///   - bounds: Optional bounds for the solution.
    ///   - constraints: Optional constraints to satisfy.
    /// - Returns: Optimization result with maximum found.
    func maximize(
        _ objective: @escaping (T) -> T,
        from initialValue: T,
        bounds: Bounds? = nil,
        constraints: [Constraint<T>] = []
    ) -> OptimizationResult<T>
    
    /// Maximize a function within a Swift-idiomatic range.
    ///
    /// - Parameters:
    ///   - objective: The function to maximize.
    ///   - initialValue: Starting point for optimization.
    ///   - range: Optional closed range for the solution.
    ///   - constraints: Optional constraints to satisfy.
    /// - Returns: Optimization result with maximum found.
    func maximize(
        _ objective: @escaping (T) -> T,
        from initialValue: T,
        in range: ClosedRange<T>? = nil,
        constraints: [Constraint<T>] = []
    ) -> OptimizationResult<T>
    
    // MARK: - Goal Seeking (Root Finding)
    
    /// Find where a function equals a target value.
    ///
    /// - Parameters:
    ///   - function: The function to evaluate.
    ///   - target: Desired output value.
    ///   - initialValue: Starting point for search.
    ///   - bounds: Optional bounds for the solution.
    ///   - constraints: Optional constraints to satisfy.
    /// - Returns: Optimization result with x where f(x) ≈ target.
    func goalSeek(
        function: @escaping (T) -> T,
        target: T,
        from initialValue: T,
        bounds: Bounds? = nil,
        constraints: [Constraint<T>] = []
    ) -> OptimizationResult<T>
    
    /// Find where a function equals a target value within a range.
    ///
    /// - Parameters:
    ///   - function: The function to evaluate.
    ///   - target: Desired output value.
    ///   - initialValue: Starting point for search.
    ///   - range: Optional closed range for the solution.
    ///   - constraints: Optional constraints to satisfy.
    /// - Returns: Optimization result with x where f(x) ≈ target.
    func goalSeek(
        function: @escaping (T) -> T,
        target: T,
        from initialValue: T,
        in range: ClosedRange<T>? = nil,
        constraints: [Constraint<T>] = []
    ) -> OptimizationResult<T>
    
    /// Find root of a function (where f(x) = 0).
    ///
    /// - Parameters:
    ///   - function: The function to evaluate.
    ///   - initialValue: Starting point for search.
    ///   - bounds: Optional bounds for the solution.
    ///   - constraints: Optional constraints to satisfy.
    /// - Returns: Optimization result with x where f(x) ≈ 0.
    func findRoot(
        of function: @escaping (T) -> T,
        from initialValue: T,
        bounds: Bounds? = nil,
        constraints: [Constraint<T>] = []
    ) -> OptimizationResult<T>
    
    // MARK: - Simplified Overloads
    
    /// Optimize with just objective and initial value.
    func optimize(
        objective: @escaping (T) -> T,
        initialValue: T
    ) -> OptimizationResult<T>
    
    /// Optimize with objective, initial value, and bounds.
    func optimize(
        objective: @escaping (T) -> T,
        initialValue: T,
        bounds: Bounds
    ) -> OptimizationResult<T>
    
    // MARK: - Helper Methods
    
    /// Convert bounds to constraints.
    func constraints(from bounds: Bounds) -> [Constraint<T>]
    
    /// Clamp value to bounds.
    func clamp(_ value: T, to bounds: Bounds?) -> T
    
    /// Check if value satisfies bounds and constraints.
    func isFeasible(
        _ value: T,
        constraints: [Constraint<T>] = [],
        within bounds: Bounds? = nil
    ) -> Bool
    
    /// Create numerical derivative function.
    func numericalDerivative(h: T) -> (_ f: @escaping (T) -> T) -> (T) -> T
}
```

### Step 1.2: Constraint Builder Syntax

**File:** `Sources/BusinessMath/Optimization/Constraint+Builders.swift`

```swift
/// Constraint builder operators for readable constraint syntax
public func >= <T: Real>(lhs: T, rhs: T) -> Constraint<T>
public func <= <T: Real>(lhs: T, rhs: T) -> Constraint<T>
public func == <T: Real>(lhs: T, rhs: T) -> Constraint<T>

/// Constraint on a function of the variable
public func constraint<T: Real>(
    _ function: @escaping (T) -> T,
    _ type: ConstraintType,
    _ bound: T,
    tolerance: T = 0.0001
) -> Constraint<T>

/// Constraint builder for common mathematical functions
public extension Constraint {
    /// Create constraint on squared value
    static func squared(_ type: ConstraintType, _ bound: T) -> Constraint<T>
    
    /// Create constraint on absolute value
    static func absolute(_ type: ConstraintType, _ bound: T) -> Constraint<T>
    
    /// Create constraint on exponential value
    static func exponential(_ type: ConstraintType, _ bound: T) -> Constraint<T>
}
```

### Step 1.3: Test Suite for Core Convenience Methods

**File:** `Tests/BusinessMathTests/OptimizationTests/OptimizerConvenienceTests.swift`

```swift
import Testing
import Numerics
@testable import BusinessMath

@Suite("Optimizer Convenience Methods")
struct OptimizerConvenienceTests {
    
    // MARK: - Test Fixtures
    
    struct MockOptimizer<T: Real>: Optimizer {
        var capturedCalls: [(
            objective: ((T) -> T)?,
            constraints: [Constraint<T>]?,
            initialValue: T?,
            bounds: (lower: T, upper: T)?
        )] = []
        
        mutating func optimize(
            objective: @escaping (T) -> T,
            constraints: [Constraint<T>],
            initialValue: T,
            bounds: (lower: T, upper: T)?
        ) -> OptimizationResult<T> {
            capturedCalls.append((objective, constraints, initialValue, bounds))
            return OptimizationResult(
                optimalValue: T(0),
                objectiveValue: T(0),
                iterations: 0,
                converged: true
            )
        }
    }
    
    // MARK: - Minimize Tests
    
    @Test("minimize() delegates to optimize()")
    func minimizeDelegates() {
        var optimizer = MockOptimizer<Double>()
        let objective: (Double) -> Double = { x in x * x }
        
        _ = optimizer.minimize(objective, from: 5.0)
        
        #expect(optimizer.capturedCalls.count == 1)
        #expect(optimizer.capturedCalls[0].initialValue == 5.0)
        #expect(optimizer.capturedCalls[0].constraints?.isEmpty == true)
    }
    
    @Test("minimize() with bounds passes bounds correctly")
    func minimizeWithBounds() {
        var optimizer = MockOptimizer<Double>()
        let objective: (Double) -> Double = { x in x * x }
        let bounds: (lower: Double, upper: Double) = (0.0, 10.0)
        
        _ = optimizer.minimize(objective, from: 5.0, bounds: bounds)
        
        #expect(optimizer.capturedCalls[0].bounds?.lower == 0.0)
        #expect(optimizer.capturedCalls[0].bounds?.upper == 10.0)
    }
    
    @Test("minimize() with ClosedRange converts correctly")
    func minimizeWithClosedRange() {
        var optimizer = MockOptimizer<Double>()
        let objective: (Double) -> Double = { x in x * x }
        let range: ClosedRange<Double> = 0.0...10.0
        
        _ = optimizer.minimize(objective, from: 5.0, in: range)
        
        #expect(optimizer.capturedCalls[0].bounds?.lower == 0.0)
        #expect(optimizer.capturedCalls[0].bounds?.upper == 10.0)
    }
    
    @Test("minimize() with constraints passes them through")
    func minimizeWithConstraints() {
        var optimizer = MockOptimizer<Double>()
        let objective: (Double) -> Double = { x in x * x }
        let constraints = [
            Constraint<Double>(type: .greaterThanOrEqual, bound: 0.0),
            Constraint<Double>(type: .lessThanOrEqual, bound: 100.0)
        ]
        
        _ = optimizer.minimize(objective, from: 5.0, constraints: constraints)
        
        #expect(optimizer.capturedCalls[0].constraints?.count == 2)
    }
    
    // MARK: - Maximize Tests
    
    @Test("maximize() minimizes negated function")
    func maximizeMinimizesNegated() {
        var optimizer = MockOptimizer<Double>()
        let objective: (Double) -> Double = { x in x * x }
        
        _ = optimizer.maximize(objective, from: 5.0)
        
        #expect(optimizer.capturedCalls.count == 1)
        
        // Test that objective is negated
        let testValue = 3.0
        let originalResult = objective(testValue)
        let capturedObjective = optimizer.capturedCalls[0].objective
        let negatedResult = capturedObjective?(testValue)
        
        #expect(negatedResult == -originalResult)
    }
    
    @Test("maximize() returns correct objective value")
    func maximizeReturnsCorrectObjective() throws {
        let optimizer = NewtonRaphsonOptimizer<Double>(
            tolerance: 1e-8,
            maxIterations: 100,
            stepSize: 1e-4
        )
        
        // f(x) = -(x-5)² + 25, maximum at x=5, f(5)=25
        let objective: (Double) -> Double = { x in -(x - 5) * (x - 5) + 25 }
        
        let result = optimizer.maximize(objective, from: 0.0)
        
        #expect(result.converged == true)
        #expect(abs(result.optimalValue - 5.0) < 0.001)
        #expect(abs(result.objectiveValue - 25.0) < 0.001)
    }
    
    // MARK: - Goal Seek Tests
    
    @Test("goalSeek() minimizes squared residual")
    func goalSeekMinimizesSquaredResidual() {
        var optimizer = MockOptimizer<Double>()
        let function: (Double) -> Double = { x in 2 * x + 3 }
        let target: Double = 10.0
        
        _ = optimizer.goalSeek(function: function, target: target, from: 0.0)
        
        #expect(optimizer.capturedCalls.count == 1)
        
        // Test objective is (f(x) - target)²
        let testValue = 2.0
        let expectedResidual = function(testValue) - target
        let expectedObjective = expectedResidual * expectedResidual
        let capturedObjective = optimizer.capturedCalls[0].objective
        let actualObjective = capturedObjective?(testValue)
        
        #expect(abs(actualObjective! - expectedObjective) < 1e-10)
    }
    
    @Test("goalSeek() finds correct solution for linear function")
    func goalSeekLinearFunction() throws {
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
        
        #expect(result.converged == true)
        #expect(abs(result.optimalValue - 3.5) < 1e-6)
        #expect(abs(function(result.optimalValue) - target) < 1e-6)
    }
    
    @Test("goalSeek() with bounds respects constraints")
    func goalSeekWithBounds() throws {
        let optimizer = NewtonRaphsonOptimizer<Double>(
            tolerance: 1e-8,
            maxIterations: 100,
            stepSize: 1e-4
        )
        
        // f(x) = x², find x where f(x) = 4
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
        
        #expect(result.converged == true)
        #expect(abs(result.optimalValue - 2.0) < 1e-6)
        #expect(result.optimalValue >= 0.0)
        #expect(result.optimalValue <= 10.0)
    }
    
    @Test("findRoot() finds where function equals zero")
    func findRootFindsZero() throws {
        let optimizer = NewtonRaphsonOptimizer<Double>(
            tolerance: 1e-8,
            maxIterations: 100,
            stepSize: 1e-4
        )
        
        // f(x) = x² - 4, roots at x = ±2
        let function: (Double) -> Double = { x in x * x - 4 }
        
        let result = optimizer.findRoot(of: function, from: 1.0)
        
        #expect(result.converged == true)
        #expect(abs(result.optimalValue - 2.0) < 1e-6)
        #expect(abs(function(result.optimalValue)) < 1e-6)
    }
    
    // MARK: - Helper Method Tests
    
    @Test("constraints(from:) creates correct constraints")
    func constraintsFromBoundsCreatesCorrectly() {
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
        let constraint = Constraint<Double>(type: .
# Comprehensive Optimizer Enhancement Implementation Plan (Continued)

## Phase 1: Core Convenience Methods (Scalar Optimization) - Continued

### Step 1.3: Test Suite for Core Convenience Methods (Continued)

**File:** `Tests/BusinessMathTests/OptimizationTests/OptimizerConvenienceTests.swift` (Continued)

```swift
    // MARK: - Helper Method Tests (Continued)
    
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
        
        // f(x) = x², f'(x) = 2x
        let f: (Double) -> Double = { x in x * x }
        let df = derivativeBuilder(f)
        
        #expect(abs(df(0.0) - 0.0) < 1e-6)
        #expect(abs(df(1.0) - 2.0) < 1e-6)
        #expect(abs(df(2.0) - 4.0) < 1e-6)
        #expect(abs(df(3.0) - 6.0) < 1e-6)
    }
    
    @Test("numericalDerivative() with custom step size")
    func numericalDerivativeCustomStep() {
        let optimizer = MockOptimizer<Double>()
        let derivativeBuilder = optimizer.numericalDerivative(h: 1e-4)
        
        // f(x) = x³, f'(x) = 3x²
        let f: (Double) -> Double = { x in x * x * x }
        let df = derivativeBuilder(f)
        
        #expect(abs(df(0.0) - 0.0) < 1e-4)
        #expect(abs(df(1.0) - 3.0) < 1e-4)
        #expect(abs(df(2.0) - 12.0) < 1e-4)
    }
    
    // MARK: - Edge Case Tests
    
    @Test("minimize() with nil bounds passes nil correctly")
    func minimizeWithNilBounds() {
        var optimizer = MockOptimizer<Double>()
        let objective: (Double) -> Double = { x in x * x }
        
        _ = optimizer.minimize(objective, from: 5.0, bounds: nil)
        
        #expect(optimizer.capturedCalls[0].bounds == nil)
    }
    
    @Test("maximize() with empty constraints array")
    func maximizeWithEmptyConstraints() {
        var optimizer = MockOptimizer<Double>()
        let objective: (Double) -> Double = { x in x * x }
        
        _ = optimizer.maximize(objective, from: 5.0, constraints: [])
        
        #expect(optimizer.capturedCalls[0].constraints?.isEmpty == true)
    }
    
    @Test("goalSeek() with zero target finds root")
    func goalSeekWithZeroTarget() {
        var optimizer = MockOptimizer<Double>()
        let function: (Double) -> Double = { x in x * x - 4 }
        
        _ = optimizer.goalSeek(function: function, target: 0.0, from: 1.0)
        
        #expect(optimizer.capturedCalls.count == 1)
        
        // Should minimize (f(x) - 0)² = f(x)²
        let testValue = 2.0
        let expectedObjective = function(testValue) * function(testValue)
        let actualObjective = optimizer.capturedCalls[0].objective?(testValue)
        
        #expect(abs(actualObjective! - expectedObjective) < 1e-10)
    }
    
    @Test("findRoot() is equivalent to goalSeek with target zero")
    func findRootEquivalentToGoalSeekZero() {
        var optimizer = MockOptimizer<Double>()
        let function: (Double) -> Double = { x in x * x - 4 }
        
        _ = optimizer.findRoot(of: function, from: 1.0)
        
        #expect(optimizer.capturedCalls.count == 1)
        
        // Should minimize f(x)²
        let testValue = 2.0
        let expectedObjective = function(testValue) * function(testValue)
        let actualObjective = optimizer.capturedCalls[0].objective?(testValue)
        
        #expect(abs(actualObjective! - expectedObjective) < 1e-10)
    }
    
    // MARK: - Parameterized Tests
    
    @Test("minimize() with various bounds",
          arguments: [
            (lower: 0.0, upper: 10.0),
            (lower: -5.0, upper: 5.0),
            (lower: -100.0, upper: 100.0)
          ])
    func minimizeWithVariousBounds(bounds: (lower: Double, upper: Double)) {
        var optimizer = MockOptimizer<Double>()
        let objective: (Double) -> Double = { x in x * x }
        
        _ = optimizer.minimize(objective, from: 0.0, bounds: bounds)
        
        #expect(optimizer.capturedCalls[0].bounds?.lower == bounds.lower)
        #expect(optimizer.capturedCalls[0].bounds?.upper == bounds.upper)
    }
    
    @Test("goalSeek() with various targets",
          arguments: [
            (target: 0.0, description: "zero"),
            (target: 1.0, description: "positive"),
            (target: -1.0, description: "negative"),
            (target: 100.0, description: "large positive"),
            (target: -100.0, description: "large negative")
          ])
    func goalSeekWithVariousTargets(target: Double, description: String) {
        var optimizer = MockOptimizer<Double>()
        let function: (Double) -> Double = { x in 2 * x + 3 }
        
        _ = optimizer.goalSeek(function: function, target: target, from: 0.0)
        
        #expect(optimizer.capturedCalls.count == 1)
        
        // Verify objective is (f(x) - target)²
        let testValue = 5.0
        let expectedResidual = function(testValue) - target
        let expectedObjective = expectedResidual * expectedResidual
        let actualObjective = optimizer.capturedCalls[0].objective?(testValue)
        
        #expect(abs(actualObjective! - expectedObjective) < 1e-10,
               "Failed for target \(description)")
    }
}
```

### Step 1.4: Constraint Builder Tests

**File:** `Tests/BusinessMathTests/OptimizationTests/ConstraintBuilderTests.swift`

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
        #expect(constraint.isSatisfied(5.00001) == false)
        #expect(constraint.isSatisfied(4.99999) == false)
    }
    
    @Test("== operator uses default tolerance")
    func equalToOperatorUsesDefaultTolerance() {
        let constraint: Constraint<Double> = 5.0 == 5.0
        
        #expect(constraint.tolerance == 0.0001)
        #expect(constraint.isSatisfied(5.00005) == true)  // Within tolerance
        #expect(constraint.isSatisfied(5.0002) == false)  // Outside tolerance
    }
    
    // MARK: - Function Constraint Tests
    
    @Test("constraint() with function creates constraint")
    func constraintWithFunction() {
        let constraint = constraint({ (x: Double) in x * x }, .lessThan, 100.0)
        
        #expect(constraint.type == .lessThan)
        #expect(constraint.bound == 100.0)
        #expect(constraint.function != nil)
        #expect(constraint.isSatisfied(9.0) == true)   // 81 < 100
        #expect(constraint.isSatisfied(10.0) == true)  // 100 == 100 (not <)
        #expect(constraint.isSatisfied(11.0) == false) // 121 > 100
    }
    
    @Test("constraint() with custom tolerance")
    func constraintWithCustomTolerance() {
        let constraint = constraint({ (x: Double) in x }, .equalTo, 5.0, tolerance: 0.1)
        
        #expect(constraint.tolerance == 0.1)
        #expect(constraint.isSatisfied(5.05) == true)
        #expect(constraint.isSatisfied(5.15) == false)
    }
    
    // MARK: - Constraint Extension Tests
    
    @Test("Constraint.squared() creates squared constraint")
    func constraintSquared() {
        let constraint = Constraint<Double>.squared(.lessThan, 100.0)
        
        #expect(constraint.type == .lessThan)
        #expect(constraint.bound == 100.0)
        #expect(constraint.function != nil)
        #expect(constraint.isSatisfied(9.0) == true)   // 81 < 100
        #expect(constraint.isSatisfied(10.0) == true)  // 100 == 100 (not <)
        #expect(constraint.isSatisfied(11.0) == false) // 121 > 100
    }
    
    @Test("Constraint.absolute() creates absolute value constraint")
    func constraintAbsolute() {
        let constraint = Constraint<Double>.absolute(.lessThanOrEqual, 5.0)
        
        #expect(constraint.type == .lessThanOrEqual)
        #expect(constraint.bound == 5.0)
        #expect(constraint.function != nil)
        #expect(constraint.isSatisfied(4.0) == true)
        #expect(constraint.isSatisfied(5.0) == true)
        #expect(constraint.isSatisfied(-5.0) == true)
        #expect(constraint.isSatisfied(6.0) == false)
        #expect(constraint.isSatisfied(-6.0) == false)
    }
    
    @Test("Constraint.exponential() creates exponential constraint")
    func constraintExponential() {
        let constraint = Constraint<Double>.exponential(.greaterThan, 1.0)
        
        #expect(constraint.type == .greaterThan)
        #expect(constraint.bound == 1.0)
        #expect(constraint.function != nil)
        #expect(constraint.isSatisfied(0.0) == true)   // exp(0) = 1 > 1? (equal, not greater)
        #expect(constraint.isSatisfied(0.1) == true)   // exp(0.1) ≈ 1.105 > 1
        #expect(constraint.isSatisfied(-0.1) == false) // exp(-0.1) ≈ 0.905 < 1
    }
    
    // MARK: - Constraint Composition Tests
    
    @Test("Multiple constraints can be combined")
    func multipleConstraintsCombined() {
        let constraints = [
            0.0 <= 5.0,  // x ≥ 0
            5.0 <= 10.0, // x ≤ 10
            5.0 == 5.0   // x = 5 (within tolerance)
        ]
        
        #expect(constraints.count == 3)
        #expect(constraints[0].type == .greaterThanOrEqual)
        #expect(constraints[0].bound == 0.0)
        #expect(constraints[1].type == .lessThanOrEqual)
        #expect(constraints[1].bound == 10.0)
        #expect(constraints[2].type == .equalTo)
        #expect(constraints[2].bound == 5.0)
    }
    
    @Test("Constraint with function composition")
    func constraintWithFunctionComposition() {
        let squareConstraint = constraint({ (x: Double) in x * x }, .lessThan, 100.0)
        let linearConstraint = constraint({ (x: Double) in 2 * x + 3 }, .greaterThan, 0.0)
        
        #expect(squareConstraint.isSatisfied(9.0) == true)
        #expect(squareConstraint.isSatisfied(11.0) == false)
        #expect(linearConstraint.isSatisfied(0.0) == true)   // 3 > 0
        #expect(linearConstraint.isSatisfied(-2.0) == false) // -1 < 0
    }
    
    // MARK: - Edge Case Tests
    
    @Test("Constraint with NaN bound returns false")
    func constraintWithNaNBound() {
        let constraint = Constraint<Double>(type: .greaterThanOrEqual, bound: .nan)
        
        #expect(constraint.isSatisfied(5.0) == false)
        #expect(constraint.isSatisfied(.nan) == false)
    }
    
    @Test("Constraint with infinity bound")
    func constraintWithInfinityBound() {
        let positiveInfConstraint = Constraint<Double>(type: .lessThan, bound: .infinity)
        let negativeInfConstraint = Constraint<Double>(type: .greaterThan, bound: -.infinity)
        
        #expect(positiveInfConstraint.isSatisfied(1e100) == true)
        #expect(negativeInfConstraint.isSatisfied(-1e100) == true)
    }
    
    @Test("Equality constraint with very small tolerance")
    func equalityConstraintSmallTolerance() {
        let constraint = Constraint<Double>(type: .equalTo, bound: 1.0, tolerance: 1e-10)
        
        #expect(constraint.isSatisfied(1.0) == true)
        #expect(constraint.isSatisfied(1.0 + 1e-11) == true)
        #expect(constraint.isSatisfied(1.0 + 1e-9) == false)
    }
}
```

## Phase 2: VectorSpace Foundation (Multi-Dimensional Optimization)

### Step 2.1: VectorSpace Protocol

**File:** `Sources/BusinessMath/Optimization/Vector/VectorSpace.swift`

```swift
//
//  VectorSpace.swift
//  BusinessMath
//
//  Created by Justin Purnell on [Date].
//

import Foundation
import Numerics

/// Protocol for types that behave like mathematical vectors.
///
/// `VectorSpace` defines the basic operations needed for multi-dimensional
/// optimization, including vector arithmetic, norms, and dot products.
///
/// ## Example Implementation
///
/// ```swift
/// struct Vector2D<T: Real>: VectorSpace {
///     var x: T
///     var y: T
///     
///     static func + (lhs: Vector2D, rhs: Vector2D) -> Vector2D {
///         Vector2D(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
///     }
///     
///     static func * (lhs: T, rhs: Vector2D) -> Vector2D {
///         Vector2D(x: lhs * rhs.x, y: lhs * rhs.y)
///     }
///     
///     var norm: T { T.sqrt(x * x + y * y) }
///     
///     func dot(_ other: Vector2D) -> T {
///         x * other.x + y * other.y
///     }
/// }
/// ```
public protocol VectorSpace: Equatable, Sendable, Codable {
    associatedtype Scalar: Real & Sendable & Codable
    
    /// Zero vector (additive identity).
    static var zero: Self { get }
    
    /// Vector addition
# Comprehensive Optimizer Enhancement Implementation Plan (Continued)

## Phase 2: VectorSpace Foundation (Multi-Dimensional Optimization) - Continued

### Step 2.1: VectorSpace Protocol (Continued)

**File:** `Sources/BusinessMath/Optimization/Vector/VectorSpace.swift` (Continued)

```swift
    /// Vector addition.
    static func + (lhs: Self, rhs: Self) -> Self
    
    /// Vector subtraction.
    static func - (lhs: Self, rhs: Self) -> Self
    
    /// Scalar multiplication.
    static func * (lhs: Scalar, rhs: Self) -> Self
    
    /// Scalar division.
    static func / (lhs: Self, rhs: Scalar) -> Self
    
    /// Negation (unary minus).
    static prefix func - (vector: Self) -> Self
    
    /// Euclidean norm (length) of the vector.
    var norm: Scalar { get }
    
    /// Squared Euclidean norm (more efficient than norm for comparisons).
    var squaredNorm: Scalar { get }
    
    /// Dot product with another vector.
    func dot(_ other: Self) -> Scalar
    
    /// Distance to another vector.
    func distance(to other: Self) -> Scalar
    
    /// Create a vector from an array of scalars.
    static func fromArray(_ array: [Scalar]) -> Self?
    
    /// Convert to array of scalars.
    func toArray() -> [Scalar]
    
    /// Dimension of the vector space.
    static var dimension: Int { get }
    
    /// Check if vector contains NaN or infinite values.
    var isFinite: Bool { get }
    
    /// Linearly interpolate between two vectors.
    static func lerp(from start: Self, to end: Self, t: Scalar) -> Self
}

// MARK: - Default Implementations

public extension VectorSpace {
    /// Default implementation of vector subtraction.
    static func - (lhs: Self, rhs: Self) -> Self {
        lhs + (-rhs)
    }
    
    /// Default implementation of squared norm.
    var squaredNorm: Scalar {
        self.dot(self)
    }
    
    /// Default implementation of distance.
    func distance(to other: Self) -> Scalar {
        (self - other).norm
    }
    
    /// Default implementation of linear interpolation.
    static func lerp(from start: Self, to end: Self, t: Scalar) -> Self {
        start + t * (end - start)
    }
}

// MARK: - Common Vector Types

/// 2-dimensional vector.
public struct Vector2D<T: Real & Sendable & Codable>: VectorSpace {
    public typealias Scalar = T
    
    public var x: T
    public var y: T
    
    public init(x: T, y: T) {
        self.x = x
        self.y = y
    }
    
    public static var zero: Vector2D<T> {
        Vector2D(x: T(0), y: T(0))
    }
    
    public static func + (lhs: Vector2D<T>, rhs: Vector2D<T>) -> Vector2D<T> {
        Vector2D(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    public static func * (lhs: T, rhs: Vector2D<T>) -> Vector2D<T> {
        Vector2D(x: lhs * rhs.x, y: lhs * rhs.y)
    }
    
    public static prefix func - (vector: Vector2D<T>) -> Vector2D<T> {
        Vector2D(x: -vector.x, y: -vector.y)
    }
    
    public var norm: T {
        T.sqrt(x * x + y * y)
    }
    
    public func dot(_ other: Vector2D<T>) -> T {
        x * other.x + y * other.y
    }
    
    public static func fromArray(_ array: [T]) -> Vector2D<T>? {
        guard array.count == 2 else { return nil }
        return Vector2D(x: array[0], y: array[1])
    }
    
    public func toArray() -> [T] {
        [x, y]
    }
    
    public static var dimension: Int { 2 }
    
    public var isFinite: Bool {
        x.isFinite && y.isFinite
    }
}

/// 3-dimensional vector.
public struct Vector3D<T: Real & Sendable & Codable>: VectorSpace {
    public typealias Scalar = T
    
    public var x: T
    public var y: T
    public var z: T
    
    public init(x: T, y: T, z: T) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    public static var zero: Vector3D<T> {
        Vector3D(x: T(0), y: T(0), z: T(0))
    }
    
    public static func + (lhs: Vector3D<T>, rhs: Vector3D<T>) -> Vector3D<T> {
        Vector3D(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }
    
    public static func * (lhs: T, rhs: Vector3D<T>) -> Vector3D<T> {
        Vector3D(x: lhs * rhs.x, y: lhs * rhs.y, z: lhs * rhs.z)
    }
    
    public static prefix func - (vector: Vector3D<T>) -> Vector3D<T> {
        Vector3D(x: -vector.x, y: -vector.y, z: -vector.z)
    }
    
    public var norm: T {
        T.sqrt(x * x + y * y + z * z)
    }
    
    public func dot(_ other: Vector3D<T>) -> T {
        x * other.x + y * other.y + z * other.z
    }
    
    public static func fromArray(_ array: [T]) -> Vector3D<T>? {
        guard array.count == 3 else { return nil }
        return Vector3D(x: array[0], y: array[1], z: array[2])
    }
    
    public func toArray() -> [T] {
        [x, y, z]
    }
    
    public static var dimension: Int { 3 }
    
    public var isFinite: Bool {
        x.isFinite && y.isFinite && z.isFinite
    }
}

/// N-dimensional vector (array-backed).
public struct VectorN<T: Real & Sendable & Codable>: VectorSpace {
    public typealias Scalar = T
    
    private var components: [T]
    
    public init(_ components: [T]) {
        self.components = components
    }
    
    public init(repeating value: T, count: Int) {
        self.components = Array(repeating: value, count: count)
    }
    
    public static var zero: VectorN<T> {
        VectorN([])
    }
    
    public static func + (lhs: VectorN<T>, rhs: VectorN<T>) -> VectorN<T> {
        guard lhs.components.count == rhs.components.count else {
            // Return zero vector for dimension mismatch
            return VectorN(repeating:

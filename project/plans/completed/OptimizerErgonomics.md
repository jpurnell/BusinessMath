### 1. **How to Get the Minimum of a Function**
**Current Capability**: ✅ **Yes, but not ergonomic**
```swift
// Current way (not ideal)
let result = optimizer.optimize(
    objective: myFunction,
    constraints: [],
    initialValue: 0.0,
    bounds: nil
)
```

**Problem**: The method is called `optimize` which is ambiguous. Users might not know if it's minimizing or maximizing.

### 2. **How to Get the Maximum of a Function**
**Current Capability**: ❌ **Missing**
There's no built-in way to maximize. Users would need to manually negate the function:
```swift
// Workaround (not intuitive)
let result = optimizer.optimize(
    objective: { -myFunction($0) },
    constraints: [],
    initialValue: 0.0,
    bounds: nil
)
let maximum = -result.objectiveValue
```

### 3. **How to Get a Certain Target Value of a Function**
**Current Capability**: ❌ **Missing**
This is a **goal-seeking** or **root-finding** problem (find x where f(x) = target), not optimization. The current API doesn't support this.

### 4. **How to Limit to a Bounded Range**
**Current Capability**: ✅ **Yes**
```swift
let result = optimizer.optimize(
    objective: myFunction,
    constraints: [],
    initialValue: 0.0,
    bounds: (lower: 0.0, upper: 100.0)  // Search only in [0, 100]
)
```

## Proposed Enhanced API

Here's what the API **should** look for maximum ergonomics:

### 1. **Minimization** - Clear, Intuitive API
```swift
// Proposed
let result = optimizer.minimize(myFunction, from: 0.0)

// With bounds
let result = optimizer.minimize(myFunction, from: 0.0, in: 0.0...100.0)

// With constraints
let result = optimizer.minimize(myFunction, from: 0.0, subjectTo: [x >= 0, x <= 100])
```

### 2. **Maximization** - Mirror Minimization API
```swift
// Proposed
let result = optimizer.maximize(myFunction, from: 0.0)

// With bounds
let result = optimizer.maximize(myFunction, from: 0.0, in: 0.0...100.0)

// With constraints
let result = optimizer.maximize(myFunction, from: 0.0, subjectTo: [x >= 0, x <= 100])
```

### 3. **Goal Seeking** - New Capability
```swift
// Proposed (new method)
let result = optimizer.seek(
    function: myFunction,
    target: 42.0,           // Find x where f(x) = 42
    from: 0.0,
    in: 0.0...100.0
)

// Alternative: root-finding (find x where f(x) = 0)
let result = optimizer.findRoot(of: myFunction, from: 0.0, in: 0.0...100.0)
```

### 4. **Bounded Search** - Improved Syntax
```swift
// Current (verbose)
let result = optimizer.optimize(
    objective: myFunction,
    constraints: [],
    initialValue: 0.0,
    bounds: (lower: 0.0, upper: 100.0)
)

// Proposed (cleaner)
let result = optimizer.minimize(myFunction, from: 0.0, in: 0.0...100.0)

// Or with constraints
let constraints = [
    Constraint(type: .greaterThanOrEqual, bound: 0.0),
    Constraint(type: .lessThanOrEqual, bound: 100.0)
]
let result = optimizer.minimize(myFunction, from: 0.0, subjectTo: constraints)
```

## Recommended Implementation

### Step 1: Add Convenience Methods to Optimizer Protocol Extension

```swift
public extension Optimizer {
    /// Minimize a function starting from an initial value.
    func minimize(
        _ function: @escaping (T) -> T,
        from initialValue: T,
        in bounds: ClosedRange<T>? = nil
    ) -> OptimizationResult<T> {
        let boundsTuple = bounds.map { (lower: $0.lowerBound, upper: $0.upperBound) }
        return optimize(
            objective: function,
            constraints: [],
            initialValue: initialValue,
            bounds: boundsTuple
        )
    }
    
    /// Maximize a function starting from an initial value.
    func maximize(
        _ function: @escaping (T) -> T,
        from initialValue: T,
        in bounds: ClosedRange<T>? = nil
    ) -> OptimizationResult<T> {
        let result = minimize({ -function($0) }, from: initialValue, in: bounds)
        
        // Flip the sign back for the result
        return OptimizationResult(
            optimalValue: result.optimalValue,
            objectiveValue: -result.objectiveValue,
            iterations: result.iterations,
            converged: result.converged,
            history: result.history.map {
                IterationHistory(
                    iteration: $0.iteration,
                    value: $0.value,
                    objective: -$0.objective,
                    gradient: -$0.gradient
                )
            }
        )
    }
}
```

### Step 2: Add Constraint Builders for Better Syntax

```swift
// Constraint operators for cleaner syntax
public func >= <T: Real>(lhs: T, rhs: T) -> Constraint<T> {
    Constraint(type: .greaterThanOrEqual, bound: rhs, function: { $0 })
}

public func <= <T: Real>(lhs: T, rhs: T) -> Constraint<T> {
    Constraint(type: .lessThanOrEqual, bound: rhs, function: { $0 })
}

public func == <T: Real>(lhs: T, rhs: T) -> Constraint<T> {
    Constraint(type: .equalTo, bound: rhs, function: { $0 })
}

// Usage
let constraints = [x >= 0, x <= 100, f(x) == 42]
```

### Step 3: Add Goal-Seeking Capability (New Protocol)

```swift
/// Protocol for algorithms that can find roots or target values
public protocol GoalSeeker {
    associatedtype T: Real & Sendable & Codable
    
    /// Find x such that f(x) = target
    func seek(
        function: @escaping (T) -> T,
        target: T,
        from initialValue: T,
        bounds: (lower: T, upper: T)?
    ) -> OptimizationResult<T>
    
    /// Find root: f(x) = 0
    func findRoot(
        of function: @escaping (T) -> T,
        from initialValue: T,
        bounds: (lower: T, upper: T)?
    ) -> OptimizationResult<T> {
        seek(function: function, target: T(0), from: initialValue, bounds: bounds)
    }
}
```

### Step 4: Create a Unified Solver Type

```swift
/// Unified solver that provides all optimization capabilities
public struct Solver<T: Real & Sendable & Codable> {
    let optimizer: any Optimizer<T>
    let goalSeeker: any GoalSeeker<T>
    
    public init(optimizer: any Optimizer<T>, goalSeeker: any GoalSeeker<T>) {
        self.optimizer = optimizer
        self.goalSeeker = goalSeeker
    }
    
    // Convenience methods that delegate to the appropriate algorithm
    public func minimize(_ f: @escaping (T) -> T, from x0: T, in bounds: ClosedRange<T>? = nil) -> OptimizationResult<T> {
        optimizer.minimize(f, from: x0, in: bounds)
    }
    
    public func maximize(_ f: @escaping (T) -> T, from x0: T, in bounds: ClosedRange<T>? = nil) -> OptimizationResult<T> {
        optimizer.maximize(f, from: x0, in: bounds)
    }
    
    public func seek(_ f: @escaping (T) -> T, target: T, from x0: T, in bounds: ClosedRange<T>? = nil) -> OptimizationResult<T> {
        let boundsTuple = bounds.map { (lower: $0.lowerBound, upper: $0.upperBound) }
        return goalSeeker.seek(function: f, target: target, from: x0, bounds: boundsTuple)
    }
}
```

## Usage Examples with Proposed API

```swift
// 1. Minimize a function
let parabola = { (x: Double) in x * x }
let minResult = solver.minimize(parabola, from: 5.0)
print("Minimum at x = \(minResult.optimalValue), f(x) = \(minResult.objectiveValue)")

// 2. Maximize a function (negated parabola)
let negParabola = { (x: Double) in -x * x }
let maxResult = solver.maximize(negParabola, from: -5.0, in: -10.0...10.0)
print("Maximum at x = \(maxResult.optimalValue), f(x) = \(maxResult.objectiveValue)")

// 3. Find where function equals a target value
let linear = { (x: Double) in 2 * x + 3 }
let targetResult = solver.seek(linear, target: 10.0, from: 0.0)
print("f(x) = 10 at x = \(targetResult.optimalValue)")

// 4. Bounded optimization
let boundedResult = solver.minimize(parabola, from: 5.0, in: 1.0...10.0)
print("Minimum in [1, 10] at x = \(boundedResult.optimalValue)")

// 5. With constraints
let constraints = [x >= 0, x <= 100, f(x) >= 50]
let constrainedResult = optimizer.minimize(
    parabola,
    from: 50.0,
    subjectTo: constraints
)
```

## Key Design Decisions

### 1. **Separate Protocols for Different Problems**
- `Optimizer` for min/max problems
- `GoalSeeker` for root-finding/target problems
- `Solver` as a unified facade

### 2. **Use ClosedRange for Bounds**
More Swift-idiomatic than tuples:
```swift
// Current: bounds: (lower: 0.0, upper: 100.0)
// Proposed: in: 0.0...100.0
```

### 3. **Clear Method Names**
- `minimize()` - obvious intent
- `maximize()` - obvious intent  
- `seek()` or `findTarget()` - for goal-seeking
- `findRoot()` - special case of seeking

### 4. **Constraint Builders**
Operator overloads make constraints readable:
```swift
// Instead of verbose Constraint initializers
[x >= 0, x <= 100, f(x) == 42]
```

### 5. **Preserve Backward Compatibility**
The original `optimize()` method remains for advanced use cases.

## Implementation Priority

1. **High Priority** (Essential for usability):
   - Add `minimize()` and `maximize()` convenience methods
   - Add `ClosedRange` support for bounds

2. **Medium Priority** (Greatly improves UX):
   - Add constraint builder operators
   - Create unified `Solver` type

3. **Lower Priority** (New capability):
   - Add `GoalSeeker` protocol for root-finding
   - Implement Newton-Raphson or bisection method

## Summary

The current `Optimizer` protocol provides a solid foundation but lacks ergonomics for common use cases. By adding convenience methods, better syntax for bounds and constraints, and separating optimization from goal-seeking, you can create a much more user-friendly API that directly addresses all four of your requirements.
# Analysis of the Optimizer Ergonomics Approach



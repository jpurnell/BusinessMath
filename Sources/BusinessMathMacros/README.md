# BusinessMath Macros

## Overview

This module provides Swift macros for BusinessMath optimization problems. These macros generate useful helper methods for bounds checking, constraint validation, and objective function management.

## Available Macros

### `@Variable(bounds:)`
Marks an optimization variable and generates bounds checking utilities.

**What it generates**:
```swift
@Variable(bounds: 0...1)
var stocks: Double

// Macro generates:
var stocks_bounds: ClosedRange<Double> {
    return 0...1
}

var stocks_isValid: Bool {
    return stocks_bounds.contains(stocks)
}

mutating func clampStocks() {
    if stocks < 0 {
        stocks = 0
    } else if stocks > 1 {
        stocks = 1
    }
}

mutating func setStocksClamped(_ value: Double) {
    stocks = min(max(value, 0), 1)
}
```

**Use cases**:
- ✅ Automatic bounds enforcement
- ✅ Validation before optimization
- ✅ Safe value setting with clamping

### `@Constraint`
Marks a constraint function and generates validation utilities.

**What it generates**:
```swift
@Constraint
func allocationSumToOne() -> Bool {
    return abs(stocks + bonds - 1.0) < 0.001
}

// Macro generates:
var allocationSumToOne_name: String {
    return "allocationSumToOne"
}

var allocationSumToOne_isSatisfied: Bool {
    return allocationSumToOne()
}

var allocationSumToOne_violation: Double {
    return allocationSumToOne() ? 0.0 : 1.0
}
```

**Use cases**:
- ✅ Quick constraint validation
- ✅ Violation tracking for penalty methods
- ✅ Constraint identification in debug output

### `@Objective`
Marks an objective function and generates evaluation utilities.

**What it generates**:
```swift
@Objective
func expectedReturn() -> Double {
    return stocks * stockReturn + bonds * bondReturn
}

// Macro generates:
var objectiveFunction: () -> Double {
    return expectedReturn
}

var objectiveFunctionName: String {
    return "expectedReturn"
}

var currentObjectiveValue: Double {
    return expectedReturn()
}

func objectiveMeetsTarget(_ target: Double, isMaximization: Bool = false) -> Bool {
    let current = expectedReturn()
    return isMaximization ? current >= target : current <= target
}
```

**Use cases**:
- ✅ Easy objective evaluation
- ✅ Target-based optimization stopping criteria
- ✅ Function identification for logging

## Current Status

### ✅ Enhanced Features (v2.0)
- Bounds checking and automatic clamping
- Constraint validation with violation tracking
- Objective function evaluation and target checking
- Can be imported via `@_exported import BusinessMathMacros`

### ⚠️ Known Limitations
- **Playgrounds**: Swift Playgrounds don't always load compiler plugins correctly. Macro errors in playgrounds are expected. Use test targets or regular Swift files instead.
- **Manual Integration**: Macros generate helpers but don't auto-wire to optimizers. You still manually integrate with BusinessMath's optimization APIs.

## Complete Working Example

```swift
import BusinessMath

struct PortfolioProblem {
    // Decision variables with automatic bounds checking
    @Variable(bounds: 0...1)
    var stocks: Double

    @Variable(bounds: 0...1)
    var bonds: Double

    // Portfolio parameters
    var stockReturn: Double = 0.12
    var bondReturn: Double = 0.05

    // Constraint with automatic validation
    @Constraint
    func allocationSumToOne() -> Bool {
        return abs(stocks + bonds - 1.0) < 0.001
    }

    // Objective with automatic evaluation
    @Objective
    func expectedReturn() -> Double {
        return stocks * stockReturn + bonds * bondReturn
    }

    // Validate and optimize
    mutating func solve() {
        // Clamp variables to bounds
        clampStocks()
        clampBonds()

        // Check constraints
        guard allocationSumToOne_isSatisfied else {
            print("Constraint '\(allocationSumToOne_name)' violated!")
            return
        }

        // Evaluate objective
        let value = currentObjectiveValue
        print("Portfolio return: \(value)")

        // Check if meets target
        if objectiveMeetsTarget(0.08, isMaximization: true) {
            print("✓ Meets 8% return target!")
        }
    }
}

// Usage
var portfolio = PortfolioProblem(stocks: 0.7, bonds: 0.3)
portfolio.solve()

// Safe value setting with automatic clamping
portfolio.setStocksClamped(1.5)  // Automatically clamps to 1.0
print(portfolio.stocks)  // Prints: 1.0
```

### In Xcode Playgrounds ❌
Playgrounds may not load the macro plugin. If you see errors like:
```
external macro implementation type 'BusinessMathMacrosImpl.VariableMacro' could not be found
```

This is a known Xcode Playground limitation with Swift macros.

**Workaround**: Use test targets or regular Swift files instead of playgrounds.

## Integration with BusinessMath Optimizers

The macros generate useful utilities but don't auto-wire to optimizers. Here's how to integrate:

```swift
import BusinessMath

struct OptimizationProblem {
    @Variable(bounds: -10...10)
    var x: Double

    @Objective
    func cost() -> Double {
        return (x - 5.0) * (x - 5.0)
    }

    func optimize() -> Double {
        // Use macro-generated helpers with BusinessMath optimizers
        let optimizer = GradientDescentOptimizer<Double>(learningRate: 0.1)

        let result = optimizer.optimize(
            objective: objectiveFunction,  // Generated by @Objective
            constraints: [],
            initialGuess: x,
            bounds: (lower: x_bounds.lowerBound, upper: x_bounds.upperBound)  // Generated by @Variable
        )

        return result.optimalValue
    }
}
```

## Testing Macros

Macros work reliably in test targets:

```swift
import XCTest
import BusinessMath

final class MacroTests: XCTestCase {
    func testVariableBounds() {
        struct Problem {
            @Variable(bounds: 0...100)
            var x: Double = 50
        }

        var p = Problem()
        XCTAssertTrue(p.x_isValid)

        p.setXClamped(150)  // Clamps to 100
        XCTAssertEqual(p.x, 100)
    }
}
```

## Related

- **Macro Implementation**: `/Sources/BusinessMathMacrosImpl/OptimizationMacros.swift`
- **Macro Tests**: `/Tests/BusinessMathMacrosTests/OptimizationMacroTests.swift`
- **Optimization APIs**: See main BusinessMath documentation

---

**Version**: 2.0.0
**Status**: Enhanced (bounds checking, validation, evaluation helpers)
**Playground Support**: Limited (use test targets instead)
**Last Updated**: 2026-01-08

# Async Optimization Migration Guide

**BusinessMath v2.0** introduces async/await APIs for optimization, providing real-time progress monitoring, task cancellation, and better integration with modern Swift concurrency.

This guide helps you migrate from synchronous to async optimization APIs.

## Table of Contents

- [Overview](#overview)
- [Quick Migration](#quick-migration)
- [Gradient Descent Migration](#gradient-descent-migration)
- [Linear Programming Migration](#linear-programming-migration)
- [Multi-Start Optimization](#multi-start-optimization)
- [Progress Monitoring](#progress-monitoring)
- [Task Cancellation](#task-cancellation)
- [Performance Considerations](#performance-considerations)
- [Common Patterns](#common-patterns)

---

## Overview

### What's New in v2.0

✨ **Async/Await APIs**
- Non-blocking optimization
- Real-time progress updates
- Task cancellation support
- Better error handling

✨ **New Optimizers**
- `AsyncGradientDescentOptimizer` - Async gradient descent with progress
- `MultiStartOptimizer` - Parallel multi-start optimization
- `AsyncSimplexSolver` - Async linear programming

✨ **Progress Reporting**
- Stream progress updates during optimization
- Monitor iterations, objective values, and convergence
- Phase tracking (initialization, optimization, finalization)

### Backwards Compatibility

✅ **All synchronous APIs remain unchanged**
- Existing code continues to work
- No breaking changes to sync APIs
- Async APIs are purely additive

---

## Quick Migration

### Before (Synchronous)

```swift
let optimizer = GradientDescentOptimizer<Double>(learningRate: 0.1)

let result = optimizer.optimize(
    objective: { x in (x - 5.0) * (x - 5.0) },
    constraints: [],
    initialGuess: 0.0,
    bounds: nil
)

print("Optimal x: \(result.optimalValue)")
```

### After (Asynchronous)

```swift
let optimizer = AsyncGradientDescentOptimizer<Double>(learningRate: 0.1)

let result = try await optimizer.optimize(
    objective: { x in (x - 5.0) * (x - 5.0) },
    constraints: [],
    initialGuess: 0.0,
    bounds: nil
)

print("Optimal x: \(result.optimalValue)")
```

**Changes:**
1. Add `Async` prefix to optimizer name
2. Add `try await` before `optimize()` call
3. Wrap in async context (Task, async function, etc.)

---

## Gradient Descent Migration

### Synchronous → Async

| Synchronous | Asynchronous |
|------------|--------------|
| `GradientDescentOptimizer` | `AsyncGradientDescentOptimizer` |
| Blocking execution | Non-blocking with `await` |
| No progress updates | Real-time progress streaming |
| Cannot cancel | Cancellable via `Task` |

### Example Migration

**Before:**
```swift
func optimizePortfolio() -> Double {
    let optimizer = GradientDescentOptimizer<Double>(
        learningRate: 0.01,
        tolerance: 1e-6,
        maxIterations: 1000
    )

    let result = optimizer.optimize(
        objective: portfolioVariance,
        constraints: constraints,
        initialGuess: 0.5,
        bounds: (lower: 0.0, upper: 1.0)
    )

    return result.objectiveValue
}
```

**After:**
```swift
func optimizePortfolio() async throws -> Double {
    let optimizer = AsyncGradientDescentOptimizer<Double>(
        learningRate: 0.01,
        tolerance: 1e-6,
        maxIterations: 1000
    )

    let result = try await optimizer.optimize(
        objective: portfolioVariance,
        constraints: constraints,
        initialGuess: 0.5,
        bounds: (lower: 0.0, upper: 1.0)
    )

    return result.objectiveValue
}
```

---

## Linear Programming Migration

### Synchronous → Async

| Synchronous | Asynchronous |
|------------|--------------|
| `SimplexSolver` | `AsyncSimplexSolver` |
| `.maximize()` / `.minimize()` | `try await .maximize()` / `.minimize()` |
| Returns `SimplexResult` | Returns `SimplexResult` (same type) |
| No progress updates | Progress streaming with phases |

### Example Migration

**Before:**
```swift
func solveLPProblem() throws -> SimplexResult {
    let solver = SimplexSolver()

    return try solver.maximize(
        objective: [3.0, 2.0],
        subjectTo: [
            SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual, rhs: 4.0),
            SimplexConstraint(coefficients: [2.0, 1.0], relation: .lessOrEqual, rhs: 5.0)
        ]
    )
}
```

**After:**
```swift
func solveLPProblem() async throws -> SimplexResult {
    let solver = AsyncSimplexSolver()

    return try await solver.maximize(
        objective: [3.0, 2.0],
        subjectTo: [
            SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual, rhs: 4.0),
            SimplexConstraint(coefficients: [2.0, 1.0], relation: .lessOrEqual, rhs: 5.0)
        ]
    )
}
```

---

## Multi-Start Optimization

**New in v2.0:** Parallel multi-start optimization for finding global minima.

### Basic Usage

```swift
// Create base optimizer
let baseOptimizer = AsyncGradientDescentOptimizer<Double>(
    learningRate: 0.1,
    tolerance: 1e-6
)

// Wrap in multi-start optimizer
let multiStart = MultiStartOptimizer(
    baseOptimizer: baseOptimizer,
    numberOfStarts: 10
)

// Find global minimum
let result = try await multiStart.optimize(
    objective: multiModalFunction,
    constraints: [],
    initialGuess: 0.0,
    bounds: (lower: -5.0, upper: 5.0)
)
```

### When to Use Multi-Start

✅ **Use when:**
- Function has multiple local minima
- Need confidence in finding global optimum
- Function landscape is unknown

❌ **Don't use when:**
- Function is convex (single minimum)
- Objective function is very expensive to evaluate
- Single local minimum is sufficient

---

## Progress Monitoring

### Gradient Descent Progress

```swift
let optimizer = AsyncGradientDescentOptimizer<Double>()

for try await progress in optimizer.optimizeWithProgress(
    objective: { x in x * x },
    constraints: [],
    initialGuess: 10.0,
    bounds: nil
) {
    // Update UI
    updateProgressBar(progress.iteration, max: 1000)
    updateChart(progress.currentValue, progress.objectiveValue)

    // Check convergence
    if progress.hasConverged {
        print("Converged at iteration \(progress.iteration)")
        break
    }
}
```

### Linear Programming Progress

```swift
let solver = AsyncSimplexSolver()

for try await progress in solver.maximizeWithProgress(
    objective: [3.0, 2.0],
    subjectTo: constraints
) {
    print("Phase: \(progress.currentPhase)")
    print("Iteration: \(progress.iteration)")
    print("Objective: \(progress.currentObjectiveValue)")

    if progress.phase == .finalization {
        print("Final status: \(progress.status!)")
    }
}
```

### Progress Types

| Optimizer | Progress Type | Key Fields |
|-----------|---------------|------------|
| `AsyncGradientDescentOptimizer` | `AsyncOptimizationProgress` | `iteration`, `currentValue`, `objectiveValue`, `gradient`, `hasConverged` |
| `MultiStartOptimizer` | `AsyncOptimizationProgress` | (inherits from base optimizer) |
| `AsyncSimplexSolver` | `SimplexProgress` | `iteration`, `currentPhase`, `currentObjectiveValue`, `status` |

---

## Task Cancellation

All async optimizers support task cancellation via Swift's `Task` API.

### Cancelling Optimization

```swift
let task = Task {
    let optimizer = AsyncGradientDescentOptimizer<Double>()

    return try await optimizer.optimize(
        objective: expensiveFunction,
        constraints: [],
        initialGuess: 0.0,
        bounds: nil
    )
}

// Cancel after timeout
try await Task.sleep(for: .seconds(5))
task.cancel()

// Handle cancellation
do {
    let result = try await task.value
    print("Completed: \(result.optimalValue)")
} catch is CancellationError {
    print("Optimization cancelled")
} catch {
    print("Error: \(error)")
}
```

### Cancelling with Progress

```swift
@State private var optimizationTask: Task<Void, Error>?

func startOptimization() {
    optimizationTask = Task {
        let optimizer = AsyncGradientDescentOptimizer<Double>()

        for try await progress in optimizer.optimizeWithProgress(
            objective: objective,
            constraints: [],
            initialGuess: 0.0,
            bounds: nil
        ) {
            await updateUI(progress)

            // Check for cancellation
            if Task.isCancelled {
                return
            }
        }
    }
}

func cancelOptimization() {
    optimizationTask?.cancel()
    optimizationTask = nil
}
```

---

## Performance Considerations

### When to Use Async vs Sync

**Use Async When:**
- UI must remain responsive
- Need progress updates
- Running multiple optimizations
- Long-running optimization (>1 second)
- May need to cancel early

**Use Sync When:**
- Simple, fast optimization (<100ms)
- No UI involved (scripts, CLI tools)
- Synchronous context required
- Minimal overhead needed

### Parallel Optimization Performance

`MultiStartOptimizer` automatically utilizes available CPU cores:

```swift
// Example: 10 starting points on 4-core machine
let multiStart = MultiStartOptimizer(
    baseOptimizer: AsyncGradientDescentOptimizer<Double>(),
    numberOfStarts: 10
)

// Runs ~2.5x faster than sequential (accounting for overhead)
let result = try await multiStart.optimize(...)
```

**Performance Tips:**
- Use 10-30 starting points for most problems
- More starts = better exploration but slower
- Diminishing returns beyond ~50 starts
- Profile on target hardware

---

## Common Patterns

### Pattern 1: UI Integration (SwiftUI)

```swift
struct OptimizationView: View {
    @State private var progress: AsyncOptimizationProgress<Double>?
    @State private var isOptimizing = false

    var body: some View {
        VStack {
            if let progress = progress {
                ProgressView("Iteration \(progress.iteration)",
                           value: Double(progress.iteration),
                           total: 1000)

                Text("f(x) = \(progress.objectiveValue, specifier: "%.4f")")
            }

            Button("Optimize") {
                Task {
                    await runOptimization()
                }
            }
            .disabled(isOptimizing)
        }
    }

    func runOptimization() async {
        isOptimizing = true
        defer { isOptimizing = false }

        let optimizer = AsyncGradientDescentOptimizer<Double>()

        for try await update in optimizer.optimizeWithProgress(
            objective: { x in (x - 5.0) * (x - 5.0) },
            constraints: [],
            initialGuess: 0.0,
            bounds: nil
        ) {
            progress = update
        }
    }
}
```

### Pattern 2: Batch Optimization

```swift
func optimizeMultiplePortfolios(_ portfolios: [Portfolio]) async throws -> [OptimizationResult<Double>] {
    // Run optimizations in parallel
    return try await withThrowingTaskGroup(of: OptimizationResult<Double>.self) { group in
        for portfolio in portfolios {
            group.addTask {
                let optimizer = AsyncGradientDescentOptimizer<Double>()
                return try await optimizer.optimize(
                    objective: portfolio.objectiveFunction,
                    constraints: portfolio.constraints,
                    initialGuess: 0.5,
                    bounds: (0.0, 1.0)
                )
            }
        }

        var results: [OptimizationResult<Double>] = []
        for try await result in group {
            results.append(result)
        }
        return results
    }
}
```

### Pattern 3: Timeout Handling

```swift
func optimizeWithTimeout<T: Real & Sendable & Codable>(
    optimizer: AsyncGradientDescentOptimizer<T>,
    timeout: Duration
) async throws -> OptimizationResult<T> {
    try await withThrowingTaskGroup(of: OptimizationResult<T>.self) { group in
        // Start optimization
        group.addTask {
            return try await optimizer.optimize(
                objective: objective,
                constraints: [],
                initialGuess: initialGuess,
                bounds: nil
            )
        }

        // Start timeout timer
        group.addTask {
            try await Task.sleep(for: timeout)
            throw OptimizationError.timeout
        }

        // Return first result (optimization or timeout)
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
```

---

## Migration Checklist

- [ ] Identify sync optimization calls in codebase
- [ ] Add `async`/`throws` to function signatures
- [ ] Replace sync optimizers with async equivalents
- [ ] Add `try await` to optimizer calls
- [ ] Update UI to handle async operations
- [ ] Add progress monitoring where beneficial
- [ ] Implement task cancellation for long operations
- [ ] Test error handling and cancellation paths
- [ ] Update documentation and comments
- [ ] Performance test async vs sync in your use case

---

## Additional Resources

- **Examples**: See `Examples/Originals/` for complete tutorials:
  - `AsyncGradientDescentExample.swift`
  - `ParallelOptimizationExample.swift`
  - `AsyncLinearProgrammingExample.swift`

- **API Documentation**: See DocC documentation for detailed API reference

- **Tests**: Refer to test suites for usage patterns:
  - `AsyncGradientDescentOptimizerTests.swift`
  - `MultiStartOptimizerTests.swift`
  - `AsyncSimplexSolverTests.swift`

---

## Support

For questions, issues, or feature requests:
- GitHub Issues: https://github.com/anthropics/businessmath/issues
- Documentation: See DocC in Xcode

**Happy optimizing with async/await! 🚀**

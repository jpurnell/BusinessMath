//
//  AsyncGradientDescentExample.swift
//  BusinessMath Examples
//
//  Comprehensive guide to async gradient descent optimization (Phase 3.2)
//  Learn real-time progress monitoring, cancellation, and parallel optimization
//
//  Created on December 30, 2025.
//

import Foundation
import BusinessMath

// MARK: - Example 1: Basic Async Optimization

func example1_BasicAsyncOptimization() async throws {
    print("=== Example 1: Basic Async Optimization ===\n")

    let optimizer = AsyncGradientDescentOptimizer<Double>(
        learningRate: 0.1,
        tolerance: 1e-6
    )

    print("Minimizing f(x) = (x - 5)² ...")

    // Get final result directly
    let result = try await optimizer.optimize(
        objective: { x in (x - 5.0) * (x - 5.0) },
        constraints: [],
        initialGuess: 0.0,
        bounds: nil
    )

    print("Optimal x: \(String(format: "%.6f", result.optimalValue))")
    print("Optimal f(x): \(String(format: "%.6f", result.objectiveValue))")
    print("Iterations: \(result.iterations)")
    print("Converged: \(result.converged)")
    print("\nAsync/await makes optimization simple and non-blocking!\n")
}

// MARK: - Example 2: Real-Time Progress Monitoring

func example2_ProgressMonitoring() async throws {
    print("=== Example 2: Real-Time Progress Monitoring ===\n")

    let optimizer = AsyncGradientDescentOptimizer<Double>(
        learningRate: 0.1,
        tolerance: 1e-6
    )

    print("Monitoring optimization progress in real-time:")
    print("Iter | x        | f(x)     | Gradient | Status")
    print("-----|----------|----------|----------|--------")

    for try await progress in optimizer.optimizeWithProgress(
        objective: { x in (x - 3.0) * (x - 3.0) },
        constraints: [],
        initialGuess: 10.0,
        bounds: nil
    ) {
        let status = progress.hasConverged ? "✓ Done" : "Running"
        print("\(String(format: "%4d", progress.iteration)) | \(String(format: "%8.4f", progress.currentValue)) | \(String(format: "%8.4f", progress.objectiveValue)) | \(String(format: "%8.4f", progress.gradient ?? 0)) | \(status)")

        if progress.hasConverged {
            break
        }
    }

    print("\nProgress updates enable real-time UI updates!\n")
}

// MARK: - Example 3: Momentum Acceleration

func example3_MomentumAcceleration() async throws {
    print("=== Example 3: Momentum Acceleration ===\n")

    print("Comparing standard gradient descent vs. momentum:\n")

    // Standard gradient descent
    let standardOptimizer = AsyncGradientDescentOptimizer<Double>(
        learningRate: 0.05,
        momentum: 0.0  // No momentum
    )

    let start1 = Date()
    let result1 = try await standardOptimizer.optimize(
        objective: { x in (x - 8.0) * (x - 8.0) },
        constraints: [],
        initialGuess: 0.0,
        bounds: nil
    )
    let time1 = Date().timeIntervalSince(start1)

    print("Standard GD:")
    print("  Iterations: \(result1.iterations)")
    print("  Time: \(String(format: "%.3f", time1))s")
    print("  Final x: \(String(format: "%.6f", result1.optimalValue))")

    // With momentum
    let momentumOptimizer = AsyncGradientDescentOptimizer<Double>(
        learningRate: 0.05,
        momentum: 0.7  // 70% momentum
    )

    let start2 = Date()
    let result2 = try await momentumOptimizer.optimize(
        objective: { x in (x - 8.0) * (x - 8.0) },
        constraints: [],
        initialGuess: 0.0,
        bounds: nil
    )
    let time2 = Date().timeIntervalSince(start2)

    print("\nWith Momentum:")
    print("  Iterations: \(result2.iterations)")
    print("  Time: \(String(format: "%.3f", time2))s")
    print("  Final x: \(String(format: "%.6f", result2.optimalValue))")

    print("\nMomentum accelerates convergence by ~\(String(format: "%.0f", (1 - Double(result2.iterations) / Double(result1.iterations)) * 100))%!\n")
}

// MARK: - Example 4: Nesterov Accelerated Gradient

func example4_NesterovAcceleration() async throws {
    print("=== Example 4: Nesterov Accelerated Gradient ===\n")

    let optimizer = AsyncGradientDescentOptimizer<Double>(
        learningRate: 0.1,
        momentum: 0.7,
        useNesterov: true  // Enable Nesterov
    )

    print("Using Nesterov Accelerated Gradient (NAG):")
    print("NAG computes gradient at 'look-ahead' position\n")

    var iterationCount = 0
    for try await progress in optimizer.optimizeWithProgress(
        objective: { x in (x - 7.0) * (x - 7.0) },
        constraints: [],
        initialGuess: 0.0,
        bounds: nil
    ) {
        if progress.iteration % 5 == 0 || progress.hasConverged {
            print("Iteration \(progress.iteration): x = \(String(format: "%.4f", progress.currentValue)), f(x) = \(String(format: "%.6f", progress.objectiveValue))")
        }
        iterationCount = progress.iteration
        if progress.hasConverged {
            break
        }
    }

    print("\nNesterov often converges faster than standard momentum!\n")
}

// MARK: - Example 5: Bounded Optimization

func example5_BoundedOptimization() async throws {
    print("=== Example 5: Bounded Optimization ===\n")

    let optimizer = AsyncGradientDescentOptimizer<Double>(
        learningRate: 0.1
    )

    // Minimize x² with bounds [2, 10]
    // Unbounded optimum is at x=0, but bounds force x ≥ 2
    print("Minimizing f(x) = x² with bounds [2, 10]:")
    print("Unbounded minimum: x = 0")
    print("Bounded minimum: x = 2 (lower bound)\n")

    let result = try await optimizer.optimize(
        objective: { x in x * x },
        constraints: [],
        initialGuess: 5.0,
        bounds: (lower: 2.0, upper: 10.0)
    )

    print("Result:")
    print("  x = \(String(format: "%.6f", result.optimalValue))")
    print("  f(x) = \(String(format: "%.6f", result.objectiveValue))")
    print("  Respects bounds: \(result.optimalValue >= 2.0 && result.optimalValue <= 10.0 ? "✓" : "✗")")

    print("\nBounds constrain the search space!\n")
}

// MARK: - Example 6: Task Cancellation

func example6_TaskCancellation() async throws {
    print("=== Example 6: Task Cancellation ===\n")

    let optimizer = AsyncGradientDescentOptimizer<Double>(
        learningRate: 0.001,  // Slow learning rate
        maxIterations: 10000
    )

    print("Starting long-running optimization...")
    print("Will cancel after 5 iterations\n")

    let task = Task {
        var count = 0
        for try await progress in optimizer.optimizeWithProgress(
            objective: { x in (x - 100.0) * (x - 100.0) },
            constraints: [],
            initialGuess: 0.0,
            bounds: nil
        ) {
            print("Iteration \(progress.iteration): x = \(String(format: "%.2f", progress.currentValue))")
            count += 1

            if count >= 5 {
                print("\nCancelling optimization...")
                return progress
            }
        }
        return nil
    }

    // Give it time to start
    try await Task.sleep(for: .milliseconds(10))

    // Cancel the task
    task.cancel()

    if let finalProgress = try? await task.value {
        print("Stopped at iteration \(finalProgress?.iteration ?? 0)")
    }

    print("\nCancellation allows graceful termination!\n")
}

// MARK: - Example 7: Custom Progress Reporting

func example7_CustomProgressReporting() async throws {
    print("=== Example 7: Custom Progress Reporting ===\n")

    let config = OptimizationConfig(
        progressUpdateInterval: .milliseconds(50),
        maxIterations: 1000,
        tolerance: 1e-6,
        reportEveryNIterations: 10  // Report every 10 iterations
    )

    let optimizer = AsyncGradientDescentOptimizer<Double>(
        learningRate: 0.1
    )

    print("Custom reporting: Every 10 iterations or every 50ms")
    print("(whichever comes first)\n")

    for try await progress in optimizer.optimizeWithProgress(
        objective: { x in (x - 4.0) * (x - 4.0) },
        constraints: [],
        initialGuess: 0.0,
        bounds: nil,
        config: config
    ) {
        print("Iteration \(progress.iteration): f(x) = \(String(format: "%.6f", progress.objectiveValue))")

        if progress.hasConverged {
            print("\nConverged!")
            break
        }
    }

    print("\nCustom reporting reduces output volume!\n")
}

// MARK: - Example 8: Multi-Modal Function

func example8_MultiModalFunction() async throws {
    print("=== Example 8: Multi-Modal Function ===\n")

    print("Optimizing f(x) = x⁴ - 4x² (has multiple local minima)\n")

    let optimizer = AsyncGradientDescentOptimizer<Double>(
        learningRate: 0.05,
        momentum: 0.7
    )

    // Try from different starting points
    let startingPoints = [-3.0, -1.5, 0.0, 1.5, 3.0]

    print("Starting Point | Found Minimum | f(x)")
    print("---------------|---------------|----------")

    for start in startingPoints {
        let result = try await optimizer.optimize(
            objective: { x in
                x * x * x * x - 4.0 * x * x
            },
            constraints: [],
            initialGuess: start,
            bounds: nil
        )

        print("\(String(format: "%13.1f", start)) | \(String(format: "%13.4f", result.optimalValue)) | \(String(format: "%8.4f", result.objectiveValue))")
    }

    print("\nDifferent starting points find different local minima!\n")
}

// MARK: - Example 9: Real-World - Portfolio Optimization

func example9_PortfolioOptimization() async throws {
    print("=== Example 9: Real-World - Portfolio Optimization ===\n")

    // Simplified portfolio: find optimal allocation between stocks and bonds
    // Risk: σ_portfolio = √(w²σ_stocks² + (1-w)²σ_bonds²)
    // Return: r_portfolio = w·r_stocks + (1-w)·r_bonds
    // Minimize risk for target return

    let stockReturn = 0.10     // 10% expected return
    let bondReturn = 0.04      // 4% expected return
    let stockVolatility = 0.20 // 20% volatility
    let bondVolatility = 0.05  // 5% volatility
    let targetReturn = 0.07    // 7% target return

    let optimizer = AsyncGradientDescentOptimizer<Double>(
        learningRate: 0.1,
        tolerance: 1e-6
    )

    print("Finding minimum-risk portfolio for 7% target return:")
    print("Stocks: 10% return, 20% volatility")
    print("Bonds:  4% return, 5% volatility\n")

    let result = try await optimizer.optimize(
        objective: { w in
            // w = weight in stocks, (1-w) = weight in bonds
            // Minimize portfolio volatility
            let portfolioVariance = w * w * stockVolatility * stockVolatility +
                                   (1.0 - w) * (1.0 - w) * bondVolatility * bondVolatility
            return portfolioVariance.squareRoot()
        },
        constraints: [
            // Constraint: achieve target return
            Constraint(
                expression: { w in
                    let portfolioReturn = w * stockReturn + (1.0 - w) * bondReturn
                    return abs(portfolioReturn - targetReturn)
                },
                relation: .lessThanOrEqual,
                value: 0.01  // Within 1% of target
            )
        ],
        initialGuess: 0.5,
        bounds: (lower: 0.0, upper: 1.0)  // Weights must be [0, 1]
    )

    let stockWeight = result.optimalValue
    let bondWeight = 1.0 - stockWeight
    let portfolioReturn = stockWeight * stockReturn + bondWeight * bondReturn
    let portfolioRisk = result.objectiveValue

    print("Optimal Portfolio:")
    print("  Stocks: \(String(format: "%.1f", stockWeight * 100))%")
    print("  Bonds:  \(String(format: "%.1f", bondWeight * 100))%")
    print("  Expected Return: \(String(format: "%.2f", portfolioReturn * 100))%")
    print("  Risk (Volatility): \(String(format: "%.2f", portfolioRisk * 100))%")

    print("\nAsync optimization enables responsive financial calculations!\n")
}

// MARK: - Example 10: Real-World - Pricing Optimization

func example10_PricingOptimization() async throws {
    print("=== Example 10: Real-World - Pricing Optimization ===\n")

    // Find optimal price to maximize revenue
    // Demand: Q = 1000 - 5P (linear demand curve)
    // Revenue: R = P × Q = P(1000 - 5P) = 1000P - 5P²

    let optimizer = AsyncGradientDescentOptimizer<Double>(
        learningRate: 0.5,
        tolerance: 1e-6
    )

    print("Maximizing revenue with demand curve Q = 1000 - 5P\n")

    // Maximize revenue (minimize negative revenue)
    let result = try await optimizer.optimize(
        objective: { price in
            let quantity = 1000.0 - 5.0 * price
            let revenue = price * quantity
            return -revenue  // Minimize negative revenue = maximize revenue
        },
        constraints: [],
        initialGuess: 50.0,
        bounds: (lower: 0.0, upper: 200.0)  // Reasonable price range
    )

    let optimalPrice = result.optimalValue
    let quantity = 1000.0 - 5.0 * optimalPrice
    let revenue = -result.objectiveValue  // Negate back

    print("Optimal Pricing Strategy:")
    print("  Price: $\(String(format: "%.2f", optimalPrice))")
    print("  Quantity Sold: \(String(format: "%.0f", quantity)) units")
    print("  Total Revenue: $\(String(format: "%.2f", revenue))")

    print("\nRevenue maximized at the optimal price point!\n")
}

// MARK: - Example 11: Real-World - Machine Learning Parameter Tuning

func example11_MLParameterTuning() async throws {
    print("=== Example 11: Real-World - ML Parameter Tuning ===\n")

    // Simplified: Find optimal learning rate for a model
    // Loss function: L(α) = (α - 0.01)² + 0.1α (favor smaller learning rates)

    let optimizer = AsyncGradientDescentOptimizer<Double>(
        learningRate: 0.01,
        tolerance: 1e-8
    )

    print("Finding optimal learning rate for ML model:")
    print("Balancing convergence speed vs. stability\n")

    print("Tuning progress:")
    var bestLearningRate = 0.0
    var bestLoss = Double.infinity

    for try await progress in optimizer.optimizeWithProgress(
        objective: { alpha in
            // Simulated validation loss
            (alpha - 0.01) * (alpha - 0.01) + 0.1 * alpha
        },
        constraints: [],
        initialGuess: 0.1,
        bounds: (lower: 0.0001, upper: 0.5)
    ) {
        if progress.iteration % 10 == 0 || progress.hasConverged {
            print("  Iteration \(progress.iteration): α = \(String(format: "%.6f", progress.currentValue)), Loss = \(String(format: "%.6f", progress.objectiveValue))")
        }

        bestLearningRate = progress.currentValue
        bestLoss = progress.objectiveValue

        if progress.hasConverged {
            break
        }
    }

    print("\nOptimal Hyperparameter:")
    print("  Learning Rate: \(String(format: "%.6f", bestLearningRate))")
    print("  Validation Loss: \(String(format: "%.6f", bestLoss))")

    print("\nAutomated hyperparameter tuning with async optimization!\n")
}

// MARK: - Example 12: Parallel Optimization (Multiple Starting Points)

func example12_ParallelOptimization() async throws {
    print("=== Example 12: Parallel Optimization ===\n")

    print("Running 5 optimizations in parallel from different starting points\n")

    let startingPoints = [0.0, 2.5, 5.0, 7.5, 10.0]

    // Run all optimizations in parallel
    let results = await withTaskGroup(of: (start: Double, result: OptimizationResult<Double>).self) { group in
        for start in startingPoints {
            group.addTask {
                let optimizer = AsyncGradientDescentOptimizer<Double>(
                    learningRate: 0.1
                )

                let result = try! await optimizer.optimize(
                    objective: { x in (x - 6.0) * (x - 6.0) },
                    constraints: [],
                    initialGuess: start,
                    bounds: nil
                )

                return (start, result)
            }
        }

        var collected: [(start: Double, result: OptimizationResult<Double>)] = []
        for await result in group {
            collected.append(result)
        }
        return collected
    }

    print("Results:")
    print("Start | Final x | Iterations | Converged")
    print("------|---------|------------|----------")

    for (start, result) in results.sorted(by: { $0.start < $1.start }) {
        print("\(String(format: "%5.1f", start)) | \(String(format: "%7.4f", result.optimalValue)) | \(String(format: "%10d", result.iterations)) | \(result.converged ? "✓" : "✗")")
    }

    print("\nParallel execution finds global optimum faster!\n")
}

// MARK: - Example 13: Convergence Visualization

func example13_ConvergenceVisualization() async throws {
    print("=== Example 13: Convergence Visualization ===\n")

    let optimizer = AsyncGradientDescentOptimizer<Double>(
        learningRate: 0.1,
        momentum: 0.7
    )

    print("Tracking convergence trajectory:")
    print("Minimizing f(x) = (x - 5)² + 2\n")

    var trajectory: [(x: Double, fx: Double)] = []

    for try await progress in optimizer.optimizeWithProgress(
        objective: { x in (x - 5.0) * (x - 5.0) + 2.0 },
        constraints: [],
        initialGuess: 0.0,
        bounds: nil
    ) {
        trajectory.append((progress.currentValue, progress.objectiveValue))

        if progress.hasConverged {
            break
        }
    }

    // Print convergence path
    print("Iteration | x       | f(x)    | Distance to Min")
    print("----------|---------|---------|----------------")

    for (i, point) in trajectory.enumerated().prefix(10) {
        let distance = abs(point.x - 5.0)
        print("\(String(format: "%9d", i)) | \(String(format: "%7.4f", point.x)) | \(String(format: "%7.4f", point.fx)) | \(String(format: "%14.4f", distance))")
    }

    if trajectory.count > 10 {
        print("...")
        if let last = trajectory.last {
            let distance = abs(last.x - 5.0)
            print("\(String(format: "%9d", trajectory.count - 1)) | \(String(format: "%7.4f", last.x)) | \(String(format: "%7.4f", last.fx)) | \(String(format: "%14.4f", distance))")
        }
    }

    print("\nVisualize convergence for debugging and analysis!\n")
}

// MARK: - Example 14: Comparison - Sync vs Async

func example14_SyncVsAsyncComparison() async throws {
    print("=== Example 14: Sync vs Async Comparison ===\n")

    let objective: (Double) -> Double = { x in (x - 4.0) * (x - 4.0) }

    // Synchronous version
    let syncOptimizer = GradientDescentOptimizer<Double>(
        learningRate: 0.1,
        tolerance: 1e-6
    )

    let syncStart = Date()
    let syncResult = syncOptimizer.optimize(
        objective: objective,
        constraints: [],
        initialGuess: 0.0,
        bounds: nil
    )
    let syncTime = Date().timeIntervalSince(syncStart)

    print("Synchronous GradientDescentOptimizer:")
    print("  Result: x = \(String(format: "%.6f", syncResult.optimalValue))")
    print("  Time: \(String(format: "%.3f", syncTime))s")
    print("  Iterations: \(syncResult.iterations)")

    // Asynchronous version
    let asyncOptimizer = AsyncGradientDescentOptimizer<Double>(
        learningRate: 0.1,
        tolerance: 1e-6
    )

    let asyncStart = Date()
    let asyncResult = try await asyncOptimizer.optimize(
        objective: objective,
        constraints: [],
        initialGuess: 0.0,
        bounds: nil
    )
    let asyncTime = Date().timeIntervalSince(asyncStart)

    print("\nAsynchronous AsyncGradientDescentOptimizer:")
    print("  Result: x = \(String(format: "%.6f", asyncResult.optimalValue))")
    print("  Time: \(String(format: "%.3f", asyncTime))s")
    print("  Iterations: \(asyncResult.iterations)")

    print("\nBoth find the same solution - async adds progress monitoring!\n")
}

// MARK: - Example 15: Best Practices

func example15_BestPractices() async throws {
    print("=== Example 15: Best Practices ===\n")

    print("✓ Best Practices for Async Gradient Descent:\n")

    print("1. Choose Learning Rate Wisely:")
    print("   - Too small: slow convergence")
    print("   - Too large: oscillation or divergence")
    print("   - Typical range: 0.001 - 0.1\n")

    print("2. Use Momentum for Faster Convergence:")
    print("   - Standard: 0.5 - 0.7")
    print("   - Aggressive: 0.8 - 0.9")
    print("   - Nesterov for convex problems\n")

    print("3. Set Appropriate Tolerance:")
    print("   - Tight: 1e-8 (high precision)")
    print("   - Moderate: 1e-6 (good balance)")
    print("   - Loose: 1e-4 (fast convergence)\n")

    print("4. Monitor Progress for Long Optimizations:")
    print("   - Use optimizeWithProgress() for UI updates")
    print("   - Configure reporting interval")
    print("   - Check convergence in real-time\n")

    print("5. Handle Task Cancellation:")
    print("   - Always wrap in Task for cancellable work")
    print("   - Provide user feedback during optimization")
    print("   - Save intermediate results\n")

    print("6. Use Bounds to Constrain Search:")
    print("   - Prevent physically impossible values")
    print("   - Guide optimizer to feasible region")
    print("   - Reduce search space\n")

    print("7. Try Multiple Starting Points:")
    print("   - Use withTaskGroup for parallel tries")
    print("   - Compare results")
    print("   - Find global vs local minima\n")

    print("Happy Optimizing! 🎯\n")
}

// MARK: - Run All Examples

@main
struct AsyncGradientDescentExamples {
    static func main() async throws {
        print("\n" + String(repeating: "=", count: 60))
        print("Async Gradient Descent Examples (Phase 3.2)")
        print(String(repeating: "=", count: 60) + "\n")

        try await example1_BasicAsyncOptimization()
        try await example2_ProgressMonitoring()
        try await example3_MomentumAcceleration()
        try await example4_NesterovAcceleration()
        try await example5_BoundedOptimization()
        try await example6_TaskCancellation()
        try await example7_CustomProgressReporting()
        try await example8_MultiModalFunction()
        try await example9_PortfolioOptimization()
        try await example10_PricingOptimization()
        try await example11_MLParameterTuning()
        try await example12_ParallelOptimization()
        try await example13_ConvergenceVisualization()
        try await example14_SyncVsAsyncComparison()
        try await example15_BestPractices()

        print(String(repeating: "=", count: 60))
        print("All examples completed successfully!")
        print(String(repeating: "=", count: 60) + "\n")
    }
}

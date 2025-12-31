//
//  ParallelOptimizationExample.swift
//  BusinessMath Examples
//
//  Comprehensive guide to parallel multi-start optimization (Phase 3.3)
//  Learn how to find global optima using parallel optimization from multiple starting points
//
//  Created on December 30, 2025.
//

import Foundation
import BusinessMath

// MARK: - Example 1: Basic Multi-Start Optimization

func example1_BasicMultiStart() async throws {
    print("=== Example 1: Basic Multi-Start Optimization ===\n")

    // Create base optimizer
    let baseOptimizer = AsyncGradientDescentOptimizer<Double>(
        learningRate: 0.1,
        tolerance: 1e-4,
        maxIterations: 1000
    )

    // Wrap in multi-start optimizer
    let multiStart = MultiStartOptimizer(
        baseOptimizer: baseOptimizer,
        numberOfStarts: 10
    )

    print("Finding minimum of f(x) = (x - 5)² using 10 starting points...")

    let result = try await multiStart.optimize(
        objective: { x in (x - 5.0) * (x - 5.0) },
        constraints: [],
        initialGuess: 0.0,
        bounds: (lower: 0.0, upper: 10.0)
    )

    print("\nResult:")
    print("  Optimal x: \(String(format: "%.6f", result.optimalValue))")
    print("  Optimal f(x): \(String(format: "%.6f", result.objectiveValue))")
    print("  Total iterations: \(result.iterations)")

    print("\nMulti-start optimization explores the space thoroughly!\n")
}

// MARK: - Example 2: Finding Global Minima in Multi-Modal Functions

func example2_GlobalMinima() async throws {
    print("=== Example 2: Finding Global Minima ===\n")

    let baseOptimizer = AsyncGradientDescentOptimizer<Double>(
        learningRate: 0.1,
        tolerance: 1e-4,
        maxIterations: 2000
    )

    let multiStart = MultiStartOptimizer(
        baseOptimizer: baseOptimizer,
        numberOfStarts: 20
    )

    // Multi-modal function with local minima
    print("Multi-modal function: f(x) = (x-2)² + 0.5·sin(5x)")
    print("Has multiple local minima, global minimum near x = 2\n")

    let result = try await multiStart.optimize(
        objective: { x in
            (x - 2.0) * (x - 2.0) + 0.5 * sin(5.0 * x)
        },
        constraints: [],
        initialGuess: 0.0,
        bounds: (lower: -5.0, upper: 5.0)
    )

    print("Result:")
    print("  Optimal x: \(String(format: "%.4f", result.optimalValue))")
    print("  Optimal f(x): \(String(format: "%.6f", result.objectiveValue))")

    // Compare with single-start optimization
    print("\nComparison with single-start:")
    let singleResult = try await baseOptimizer.optimize(
        objective: { x in
            (x - 2.0) * (x - 2.0) + 0.5 * sin(5.0 * x)
        },
        constraints: [],
        initialGuess: -4.0,  // Poor starting point
        bounds: (lower: -5.0, upper: 5.0)
    )

    print("  Single-start x: \(String(format: "%.4f", singleResult.optimalValue))")
    print("  Single-start f(x): \(String(format: "%.6f", singleResult.objectiveValue))")

    print("\nMulti-start found \(result.objectiveValue < singleResult.objectiveValue ? "better" : "similar") solution!\n")
}

// MARK: - Example 3: Custom Starting Points

func example3_CustomStartingPoints() async throws {
    print("=== Example 3: Custom Starting Points ===\n")

    let baseOptimizer = AsyncGradientDescentOptimizer<Double>(
        learningRate: 0.1
    )

    // Define strategic starting points
    let customStarts = [0.0, 2.5, 5.0, 7.5, 10.0]

    let multiStart = MultiStartOptimizer(
        baseOptimizer: baseOptimizer,
        startingPoints: customStarts
    )

    print("Using custom starting points: \(customStarts)")
    print("Minimizing f(x) = (x - 6)²\n")

    let result = try await multiStart.optimize(
        objective: { x in (x - 6.0) * (x - 6.0) },
        constraints: [],
        initialGuess: 0.0,  // Ignored when using custom starts
        bounds: nil
    )

    print("Result:")
    print("  Optimal x: \(String(format: "%.4f", result.optimalValue))")
    print("  Optimal f(x): \(String(format: "%.6f", result.objectiveValue))")

    print("\nCustom starting points give you control over exploration!\n")
}

// MARK: - Example 4: Progress Monitoring from Multiple Optimizers

func example4_ParallelProgress() async throws {
    print("=== Example 4: Parallel Progress Monitoring ===\n")

    let baseOptimizer = AsyncGradientDescentOptimizer<Double>(
        learningRate: 0.1,
        tolerance: 1e-4
    )

    let multiStart = MultiStartOptimizer(
        baseOptimizer: baseOptimizer,
        numberOfStarts: 5
    )

    print("Monitoring progress from 5 parallel optimizers:")
    print("(Updates are interleaved from different starting points)\n")

    var updateCount = 0
    var bestValue = Double.infinity

    for try await progress in multiStart.optimizeWithProgress(
        objective: { x in (x - 4.0) * (x - 4.0) },
        constraints: [],
        initialGuess: 0.0,
        bounds: (lower: 0.0, upper: 10.0)
    ) {
        updateCount += 1

        if progress.objectiveValue < bestValue {
            bestValue = progress.objectiveValue
            print("New best: f(x) = \(String(format: "%.6f", progress.objectiveValue)) at x = \(String(format: "%.4f", progress.currentValue))")
        }

        // Show first 10 updates
        if updateCount > 10 {
            print("... (additional updates)")
            break
        }
    }

    print("\nProgress updates enable real-time monitoring of all parallel optimizations!\n")
}

// MARK: - Example 5: Performance Comparison

func example5_PerformanceComparison() async throws {
    print("=== Example 5: Performance Comparison ===\n")

    let baseOptimizer = AsyncGradientDescentOptimizer<Double>(
        learningRate: 0.1,
        maxIterations: 100
    )

    print("Comparing sequential vs parallel execution:\n")

    // Sequential execution (simulated)
    print("Sequential approach:")
    let seqStart = Date()
    var bestResult: OptimizationResult<Double>?

    for start in [0.0, 2.5, 5.0, 7.5, 10.0] {
        let result = try await baseOptimizer.optimize(
            objective: { x in (x - 5.0) * (x - 5.0) },
            constraints: [],
            initialGuess: start,
            bounds: (lower: 0.0, upper: 10.0)
        )

        if bestResult == nil || result.objectiveValue < bestResult!.objectiveValue {
            bestResult = result
        }
    }
    let seqTime = Date().timeIntervalSince(seqStart)

    print("  Time: \(String(format: "%.3f", seqTime))s")
    print("  Best f(x): \(String(format: "%.6f", bestResult!.objectiveValue))")

    // Parallel execution
    print("\nParallel approach (MultiStartOptimizer):")
    let parStart = Date()

    let multiStart = MultiStartOptimizer(
        baseOptimizer: baseOptimizer,
        startingPoints: [0.0, 2.5, 5.0, 7.5, 10.0]
    )

    let parResult = try await multiStart.optimize(
        objective: { x in (x - 5.0) * (x - 5.0) },
        constraints: [],
        initialGuess: 0.0,
        bounds: (lower: 0.0, upper: 10.0)
    )
    let parTime = Date().timeIntervalSince(parStart)

    print("  Time: \(String(format: "%.3f", parTime))s")
    print("  Best f(x): \(String(format: "%.6f", parResult.objectiveValue))")

    let speedup = seqTime / parTime
    print("\nSpeedup: \(String(format: "%.1f", speedup))x faster!")
    print("Parallel execution utilizes multiple CPU cores!\n")
}

// MARK: - Example 6: Portfolio Optimization with Multi-Start

func example6_PortfolioOptimization() async throws {
    print("=== Example 6: Portfolio Optimization ===\n")

    // Portfolio allocation problem: find optimal weight for asset A vs B
    // Objective: minimize variance while targeting return

    let returnA = 0.08  // 8% expected return
    let returnB = 0.12  // 12% expected return
    let varA = 0.04     // 4% variance
    let varB = 0.09     // 9% variance
    let correlation = 0.3

    print("Two-asset portfolio:")
    print("  Asset A: Return = \(returnA * 100)%, Variance = \(varA * 100)%")
    print("  Asset B: Return = \(returnB * 100)%, Variance = \(varB * 100)%")
    print("  Correlation = \(correlation)")
    print("\nTarget return: 10%")
    print("Minimize: Portfolio variance\n")

    let baseOptimizer = AsyncGradientDescentOptimizer<Double>(
        learningRate: 0.05,
        tolerance: 1e-6,
        maxIterations: 2000
    )

    let multiStart = MultiStartOptimizer(
        baseOptimizer: baseOptimizer,
        numberOfStarts: 15
    )

    let targetReturn = 0.10

    let result = try await multiStart.optimize(
        objective: { weightA in
            let weightB = 1.0 - weightA

            // Portfolio return
            let portfolioReturn = weightA * returnA + weightB * returnB

            // Portfolio variance
            let portfolioVariance = weightA * weightA * varA +
                                  weightB * weightB * varB +
                                  2.0 * weightA * weightB * correlation * sqrt(varA * varB)

            // Penalty for missing target return
            let returnPenalty = 1000.0 * abs(portfolioReturn - targetReturn)

            return portfolioVariance + returnPenalty
        },
        constraints: [],
        initialGuess: 0.5,
        bounds: (lower: 0.0, upper: 1.0)
    )

    let optimalWeightA = result.optimalValue
    let optimalWeightB = 1.0 - optimalWeightA
    let portfolioReturn = optimalWeightA * returnA + optimalWeightB * returnB
    let portfolioVariance = optimalWeightA * optimalWeightA * varA +
                           optimalWeightB * optimalWeightB * varB +
                           2.0 * optimalWeightA * optimalWeightB * correlation * sqrt(varA * varB)

    print("Optimal allocation:")
    print("  Asset A: \(String(format: "%.1f", optimalWeightA * 100))%")
    print("  Asset B: \(String(format: "%.1f", optimalWeightB * 100))%")
    print("\nPortfolio metrics:")
    print("  Expected return: \(String(format: "%.2f", portfolioReturn * 100))%")
    print("  Variance: \(String(format: "%.4f", portfolioVariance))")
    print("  Std deviation: \(String(format: "%.2f", sqrt(portfolioVariance) * 100))%")

    print("\nMulti-start optimization finds the global optimal portfolio!\n")
}

// MARK: - Example 7: Escaping Local Minima

func example7_EscapingLocalMinima() async throws {
    print("=== Example 7: Escaping Local Minima ===\n")

    // Function with two clear local minima
    print("Function: f(x) = (x² - 2)²")
    print("Has local minima at x = ±√2")
    print("Both minima have same objective value (0)\n")

    let baseOptimizer = AsyncGradientDescentOptimizer<Double>(
        learningRate: 0.1,
        tolerance: 1e-4,
        maxIterations: 2000
    )

    // Single start - might get stuck in nearest local minimum
    print("Single-start optimization from x = 0:")
    let singleResult = try await baseOptimizer.optimize(
        objective: { x in
            let term = x * x - 2.0
            return term * term
        },
        constraints: [],
        initialGuess: 0.0,
        bounds: (lower: -3.0, upper: 3.0)
    )

    print("  Found: x = \(String(format: "%.4f", singleResult.optimalValue))")
    print("  f(x) = \(String(format: "%.6f", singleResult.objectiveValue))")

    // Multi-start - explores both minima
    print("\nMulti-start with 10 starting points:")
    let multiStart = MultiStartOptimizer(
        baseOptimizer: baseOptimizer,
        numberOfStarts: 10
    )

    let multiResult = try await multiStart.optimize(
        objective: { x in
            let term = x * x - 2.0
            return term * term
        },
        constraints: [],
        initialGuess: 0.0,
        bounds: (lower: -3.0, upper: 3.0)
    )

    print("  Found: x = \(String(format: "%.4f", multiResult.optimalValue))")
    print("  f(x) = \(String(format: "%.6f", multiResult.objectiveValue))")

    print("\nMulti-start explores the entire search space!")
    print("Expected minima: x = ±\(String(format: "%.4f", sqrt(2.0)))\n")
}

// MARK: - Example 8: Best Practices

func example8_BestPractices() async throws {
    print("=== Example 8: Multi-Start Best Practices ===\n")

    print("📚 Best Practices for Multi-Start Optimization:\n")

    print("1. Number of Starting Points")
    print("   • Use 10-30 starts for most problems")
    print("   • More starts = better exploration but slower")
    print("   • Highly multi-modal functions need more starts\n")

    print("2. Choosing Starting Points")
    print("   • Uniform distribution (default): good for bounded problems")
    print("   • Custom points: use domain knowledge")
    print("   • Grid-based: systematic coverage of search space\n")

    print("3. Base Optimizer Configuration")
    print("   • Use moderate learning rates (0.01-0.1)")
    print("   • Include momentum (0.5-0.7) for faster convergence")
    print("   • Set reasonable iteration limits per start\n")

    print("4. When to Use Multi-Start")
    print("   ✓ Multi-modal functions (multiple local minima)")
    print("   ✓ Unknown function landscape")
    print("   ✓ Need confidence in global optimum")
    print("   ✗ Simple convex functions (single start sufficient)")
    print("   ✗ Very expensive objective functions\n")

    print("5. Performance Tips")
    print("   • Multi-start automatically parallelizes across CPU cores")
    print("   • Progress monitoring works with all parallel optimizers")
    print("   • Cancellation propagates to all running optimizers")
    print("   • Use bounds to constrain search space\n")

    // Demonstrate a well-configured multi-start optimizer
    print("Example configuration:")

    let wellConfigured = MultiStartOptimizer(
        baseOptimizer: AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.05,
            tolerance: 1e-6,
            maxIterations: 1000,
            momentum: 0.6
        ),
        numberOfStarts: 20
    )

    print("  • 20 starting points")
    print("  • Learning rate: 0.05")
    print("  • Momentum: 0.6")
    print("  • Max iterations per start: 1000")
    print("  • Tolerance: 1e-6\n")

    let result = try await wellConfigured.optimize(
        objective: { x in (x - 3.0) * (x - 3.0) + 0.5 * sin(4.0 * x) },
        constraints: [],
        initialGuess: 0.0,
        bounds: (lower: 0.0, upper: 6.0)
    )

    print("Result on multi-modal function:")
    print("  Optimal x: \(String(format: "%.4f", result.optimalValue))")
    print("  Optimal f(x): \(String(format: "%.6f", result.objectiveValue))")
    print("  Iterations: \(result.iterations)")
    print("  Converged: \(result.converged)\n")
}

// MARK: - Main Runner

@main
struct ParallelOptimizationExampleRunner {
    static func main() async throws {
        print("\n" + String(repeating: "=", count: 60))
        print("    BusinessMath: Parallel Optimization Examples")
        print("    Phase 3.3: MultiStartOptimizer Tutorial")
        print(String(repeating: "=", count: 60) + "\n")

        try await example1_BasicMultiStart()
        try await example2_GlobalMinima()
        try await example3_CustomStartingPoints()
        try await example4_ParallelProgress()
        try await example5_PerformanceComparison()
        try await example6_PortfolioOptimization()
        try await example7_EscapingLocalMinima()
        try await example8_BestPractices()

        print(String(repeating: "=", count: 60))
        print("✅ All examples completed successfully!")
        print(String(repeating: "=", count: 60) + "\n")

        print("Next Steps:")
        print("  • Explore AsyncSimplexSolver for linear programming")
        print("  • Read the migration guide for async optimization")
        print("  • Check out performance benchmarks")
        print("\nHappy optimizing! 🚀\n")
    }
}

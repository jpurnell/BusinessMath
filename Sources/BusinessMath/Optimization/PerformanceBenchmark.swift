//
//  PerformanceBenchmark.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation

// MARK: - Performance Benchmark

/// Performance benchmarking utilities for optimization algorithms.
///
/// Provides tools to measure and compare algorithm performance including:
/// - Execution time
/// - Iteration counts
/// - Success rates
/// - Convergence quality
///
/// ## Example
/// ```swift
/// let benchmark = PerformanceBenchmark<VectorN<Double>>()
///
/// let report = try benchmark.compareOptimizers(
///     objective: { x in (x[0] - 1) * (x[0] - 1) + (x[1] - 2) * (x[1] - 2) },
///     optimizers: [
///         ("Adaptive", AdaptiveOptimizer()),
///         ("Gradient Descent", AdaptiveOptimizer(preferSpeed: true)),
///         ("Newton-Raphson", AdaptiveOptimizer(preferAccuracy: true))
///     ],
///     initialGuess: VectorN([0.0, 0.0]),
///     trials: 10
/// )
///
/// print(report.summary())
/// ```
public struct PerformanceBenchmark<V: VectorSpace> where V.Scalar == Double {

	// MARK: - Result Types

	/// Result from a single optimization run.
	public struct RunResult {
		/// Solution found
		public let solution: V

		/// Objective value at solution
		public let objectiveValue: Double

		/// Execution time in seconds
		public let executionTime: Double

		/// Number of iterations
		public let iterations: Int

		/// Whether optimization converged
		public let converged: Bool

		/// Algorithm name (if available)
		public let algorithmName: String?
	}

	/// Aggregated results from multiple trials.
	public struct OptimizerResult {
		/// Name of the optimizer
		public let name: String

		/// Average execution time (seconds)
		public let avgTime: Double

		/// Standard deviation of execution time
		public let stdTime: Double

		/// Average iterations
		public let avgIterations: Double

		/// Success rate (proportion that converged)
		public let successRate: Double

		/// Average objective value (for successful runs)
		public let avgObjectiveValue: Double

		/// Best objective value achieved
		public let bestObjectiveValue: Double

		/// All individual run results
		public let runs: [RunResult]
	}

	/// Comparison report for multiple optimizers.
	public struct ComparisonReport {
		/// Results for each optimizer
		public let results: [OptimizerResult]

		/// Best optimizer (fastest with good convergence)
		public let winner: OptimizerResult

		/// Generate human-readable summary
		public func summary() -> String {
			var output = "=== Optimization Performance Comparison ===\n\n"

			// Table header (use string interpolation to avoid C string issues)
			let col1 = "Optimizer".padding(toLength: 25, withPad: " ", startingAt: 0)
			let col2 = "Avg Time".padding(toLength: 10, withPad: " ", startingAt: 0)
			let col3 = "Iterations".padding(toLength: 10, withPad: " ", startingAt: 0)
			let col4 = "Success Rate".padding(toLength: 12, withPad: " ", startingAt: 0)
			let col5 = "Best Obj".padding(toLength: 22, withPad: " ", startingAt: 0)
			output += "\(col1) \(col2) \(col3) \(col4) \(col5)\n"
			output += String(repeating: "-", count: 75) + "\n"

			// Results for each optimizer
			for result in results.sorted(by: { $0.avgTime < $1.avgTime }) {
				let isWinner = result.name == winner.name
				let marker = isWinner ? "→ " : "  "

				// Use string interpolation to avoid C string issues
				let name = result.name.padding(toLength: 23, withPad: " ", startingAt: 0)
				let time = result.avgTime.number(4).paddingLeft(toLength: 8)
				let iters = result.avgIterations.number(0).paddingLeft(toLength: 12)
				let success = result.successRate.percent(1).paddingLeft(toLength: 7)
				let objective = result.bestObjectiveValue.number(3).paddingLeft(toLength: 19)

				output += "\(marker)\(name) \(time) \(iters) \(success) \(objective)\n"
			}

			output += "\n"
			output += "Winner: \(winner.name)\n"
			output += "  - Fastest average time: \(String(format: "%.4f", winner.avgTime))s\n"
			output += "  - Success rate: \(String(format: "%.1f", winner.successRate * 100))%\n"

			return output
		}

		/// Generate detailed report
		public func detailedReport() -> String {
			var output = summary()
			output += "\n=== Detailed Results ===\n\n"

			for result in results {
				output += "\(result.name):\n"
				output += "  Average time: \(String(format: "%.4f", result.avgTime))s " +
						 "(± \(String(format: "%.4f", result.stdTime))s)\n"
				output += "  Average iterations: \(String(format: "%.1f", result.avgIterations))\n"
				output += "  Success rate: \(String(format: "%.1f", result.successRate * 100))%\n"
				output += "  Average objective: \(String(format: "%.6f", result.avgObjectiveValue))\n"
				output += "  Best objective: \(String(format: "%.6f", result.bestObjectiveValue))\n"

				// Show run-by-run details
				output += "  Runs:\n"
				for (i, run) in result.runs.prefix(5).enumerated() {
					let num = i + 1
					let time = String(format: "%.4fs", run.executionTime)
					let obj = String(format: "%.6f", run.objectiveValue)
					let status = run.converged ? "✓" : "✗"
					output += "    \(num): \(time), \(run.iterations) iter, obj=\(obj) \(status)\n"
				}
				if result.runs.count > 5 {
					output += "    ... (\(result.runs.count - 5) more runs)\n"
				}
				output += "\n"
			}

			return output
		}
	}

	// MARK: - Initialization

	/// Create a performance benchmark instance.
	public init() {
		// No stored properties to initialize
	}

	// MARK: - Benchmarking Methods

	/// Compare multiple optimizers on the same problem.
	///
	/// - Parameters:
	///   - objective: Objective function to minimize
	///   - optimizers: Array of (name, optimizer) pairs to compare
	///   - initialGuess: Starting point
	///   - constraints: Optimization constraints
	///   - trials: Number of trials to run for each optimizer
	/// - Returns: Comparison report with aggregated results
	public func compareOptimizers(
		objective: @escaping (V) -> Double,
		optimizers: [(String, AdaptiveOptimizer<V>)],
		initialGuess: V,
		constraints: [MultivariateConstraint<V>] = [],
		trials: Int = 10
	) throws -> ComparisonReport {

		var allResults: [OptimizerResult] = []

		for (name, optimizer) in optimizers {
			let runs = try (0..<trials).map { _ in
				try profileOptimizer(
					name: name,
					optimizer: optimizer,
					objective: objective,
					initialGuess: initialGuess,
					constraints: constraints
				)
			}

			let successfulRuns = runs.filter { $0.converged }
			let avgTime = runs.map(\.executionTime).reduce(0, +) / Double(trials)
			let stdTime = standardDeviation(runs.map(\.executionTime))
			let avgIterations = runs.map { Double($0.iterations) }.reduce(0, +) / Double(trials)
			let successRate = Double(successfulRuns.count) / Double(trials)
			let avgObjective = successfulRuns.isEmpty ? 0.0 :
				successfulRuns.map(\.objectiveValue).reduce(0, +) / Double(successfulRuns.count)
			let bestObjective = runs.map(\.objectiveValue).min() ?? 0.0

			let result = OptimizerResult(
				name: name,
				avgTime: avgTime,
				stdTime: stdTime,
				avgIterations: avgIterations,
				successRate: successRate,
				avgObjectiveValue: avgObjective,
				bestObjectiveValue: bestObjective,
				runs: runs
			)

			allResults.append(result)
		}

		// Select winner: fastest with >50% success rate
		let viable = allResults.filter { $0.successRate > 0.5 }
		let winner = viable.min(by: { $0.avgTime < $1.avgTime }) ?? allResults[0]

		return ComparisonReport(results: allResults, winner: winner)
	}

	/// Profile a single optimizer run.
	///
	/// - Parameters:
	///   - name: Name for the optimizer
	///   - optimizer: Optimizer to profile
	///   - objective: Objective function
	///   - initialGuess: Starting point
	///   - constraints: Optimization constraints
	/// - Returns: Run result with timing information
	public func profileOptimizer(
		name: String,
		optimizer: AdaptiveOptimizer<V>,
		objective: @escaping (V) -> Double,
		initialGuess: V,
		constraints: [MultivariateConstraint<V>] = []
	) throws -> RunResult {

		let startTime = CFAbsoluteTimeGetCurrent()

		let result = try optimizer.optimize(
			objective: objective,
			initialGuess: initialGuess,
			constraints: constraints
		)

		let endTime = CFAbsoluteTimeGetCurrent()
		let executionTime = endTime - startTime

		return RunResult(
			solution: result.solution,
			objectiveValue: result.objectiveValue,
			executionTime: executionTime,
			iterations: result.iterations,
			converged: result.converged,
			algorithmName: result.algorithmUsed
		)
	}

	// MARK: - Helper Methods

	/// Calculate standard deviation
	private func standardDeviation(_ values: [Double]) -> Double {
		guard !values.isEmpty else { return 0.0 }

		let mean = values.reduce(0, +) / Double(values.count)
		let squaredDiffs = values.map { pow($0 - mean, 2) }
		let variance = squaredDiffs.reduce(0, +) / Double(values.count)

		return sqrt(variance)
	}
}

// MARK: - Convenience Extensions

extension PerformanceBenchmark {

	/// Quick benchmark: Compare default, speed-focused, and accuracy-focused optimizers.
	///
	/// - Parameters:
	///   - objective: Objective function to minimize
	///   - initialGuess: Starting point
	///   - constraints: Optimization constraints
	///   - trials: Number of trials per optimizer
	/// - Returns: Comparison report
	public func quickCompare(
		objective: @escaping (V) -> Double,
		initialGuess: V,
		constraints: [MultivariateConstraint<V>] = [],
		trials: Int = 10
	) throws -> ComparisonReport {

		let optimizers: [(String, AdaptiveOptimizer<V>)] = [
			("Default", AdaptiveOptimizer<V>()),
			("Speed-Focused", AdaptiveOptimizer<V>(preferSpeed: true)),
			("Accuracy-Focused", AdaptiveOptimizer<V>(preferAccuracy: true))
		]

		return try compareOptimizers(
			objective: objective,
			optimizers: optimizers,
			initialGuess: initialGuess,
			constraints: constraints,
			trials: trials
		)
	}
}

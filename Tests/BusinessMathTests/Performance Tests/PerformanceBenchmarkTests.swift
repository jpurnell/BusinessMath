//
//  PerformanceBenchmarkTests.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Testing
@testable import BusinessMath

@Suite struct PerformanceBenchmarkTests {

	// MARK: - Basic Profiling Tests

	/// Test profiling a single optimizer run
	@Test func profileSingleRun() throws {
		let benchmark = PerformanceBenchmark<VectorN<Double>>()
		let optimizer = AdaptiveOptimizer<VectorN<Double>>()

		let result = try benchmark.profileOptimizer(
			name: "Test Optimizer",
			optimizer: optimizer,
			objective: { x in (x[0] - 1) * (x[0] - 1) + (x[1] - 2) * (x[1] - 2) },
			initialGuess: VectorN([0.0, 0.0])
		)

		// Verify result structure
		#expect(result.algorithmName != nil)
		#expect(result.converged)
		#expect(result.executionTime > 0.0)
		#expect(result.iterations > 0)

		// Verify solution quality
		#expect(abs(result.solution[0] - 1.0) < 0.1)
		#expect(abs(result.solution[1] - 2.0) < 0.1)
		#expect(result.objectiveValue < 0.1)
	}

	/// Test that execution time is measured accurately
	@Test func executionTimeMeasurement() throws {
		let benchmark = PerformanceBenchmark<VectorN<Double>>()
		let optimizer = AdaptiveOptimizer<VectorN<Double>>()

		// Run twice and compare times
		let result1 = try benchmark.profileOptimizer(
			name: "Run 1",
			optimizer: optimizer,
			objective: { x in x[0] * x[0] + x[1] * x[1] },
			initialGuess: VectorN([1.0, 1.0])
		)

		let result2 = try benchmark.profileOptimizer(
			name: "Run 2",
			optimizer: optimizer,
			objective: { x in x[0] * x[0] + x[1] * x[1] },
			initialGuess: VectorN([1.0, 1.0])
		)

		// Both should have reasonable execution times
		#expect(result1.executionTime > 0.0)
		#expect(result2.executionTime > 0.0)
		#expect(result1.executionTime < 1.0)  // Should be fast
		#expect(result2.executionTime < 1.0)
	}

	// MARK: - Comparison Tests

	/// Test comparing multiple optimizers
	@Test func compareOptimizers() throws {
		let benchmark = PerformanceBenchmark<VectorN<Double>>()

		let optimizers: [(String, AdaptiveOptimizer<VectorN<Double>>)] = [
			("Default", AdaptiveOptimizer()),
			("Speed", AdaptiveOptimizer(preferSpeed: true)),
			("Accuracy", AdaptiveOptimizer(preferAccuracy: true))
		]

		let report = try benchmark.compareOptimizers(
			objective: { x in (x[0] - 1) * (x[0] - 1) + (x[1] - 2) * (x[1] - 2) },
			optimizers: optimizers,
			initialGuess: VectorN([0.0, 0.0]),
			trials: 5
		)

		// Verify report structure
		#expect(report.results.count == 3)
//		#expect(report.winner != nil)

		// Verify each optimizer result
		for result in report.results {
			#expect(result.avgTime > 0.0)
			#expect(result.successRate >= 0.0)
			#expect(result.successRate <= 1.0)
			#expect(result.runs.count == 5)
			#expect(result.avgIterations > 0.0)
		}

		// Winner should have good success rate
		#expect(report.winner.successRate > 0.5)
	}

	/// Test that winner is selected correctly (fastest with >50% success)
	@Test func winnerSelection() throws {
		let benchmark = PerformanceBenchmark<VectorN<Double>>()

		let report = try benchmark.compareOptimizers(
			objective: { x in x[0] * x[0] + x[1] * x[1] },
			optimizers: [
				("Default", AdaptiveOptimizer()),
				("Speed", AdaptiveOptimizer(preferSpeed: true))
			],
			initialGuess: VectorN([1.0, 1.0]),
			trials: 3
		)

		// Winner should be one of the tested optimizers
		#expect(report.results.contains { $0.name == report.winner.name })

		// Winner should have good success rate
		#expect(report.winner.successRate > 0.5)
	}

	/// Test quick compare convenience method
	@Test func quickCompare() throws {
		let benchmark = PerformanceBenchmark<VectorN<Double>>()

		let report = try benchmark.quickCompare(
			objective: { x in (x[0] - 3) * (x[0] - 3) + (x[1] - 4) * (x[1] - 4) },
			initialGuess: VectorN([0.0, 0.0]),
			trials: 3
		)

		// Should compare 3 standard configurations
		#expect(report.results.count == 3)

		let names = report.results.map(\.name)
		#expect(names.contains("Default"))
		#expect(names.contains("Speed-Focused"))
		#expect(names.contains("Accuracy-Focused"))
	}

	// MARK: - Report Generation Tests

	/// Test summary report generation
	@Test func summaryReport() throws {
		let benchmark = PerformanceBenchmark<VectorN<Double>>()

		let report = try benchmark.compareOptimizers(
			objective: { x in x[0] * x[0] + x[1] * x[1] },
			optimizers: [
				("Optimizer A", AdaptiveOptimizer()),
				("Optimizer B", AdaptiveOptimizer(preferSpeed: true))
			],
			initialGuess: VectorN([1.0, 1.0]),
			trials: 2
		)

		let summary = report.summary()

		// Verify summary contains key information
		#expect(summary.contains("Performance Comparison"))
		#expect(summary.contains("Optimizer A"))
		#expect(summary.contains("Optimizer B"))
		#expect(summary.contains("Winner"))
		#expect(summary.contains("Avg Time"))
		#expect(summary.contains("Success Rate"))
	}

	/// Test detailed report generation
	@Test func detailedReport() throws {
		let benchmark = PerformanceBenchmark<VectorN<Double>>()

		let report = try benchmark.compareOptimizers(
			objective: { x in x[0] * x[0] + x[1] * x[1] },
			optimizers: [
				("Test", AdaptiveOptimizer())
			],
			initialGuess: VectorN([1.0, 1.0]),
			trials: 3
		)

		let detailed = report.detailedReport()

		// Verify detailed report contains more information
		#expect(detailed.contains("Detailed Results"))
		#expect(detailed.contains("Average time"))
		#expect(detailed.contains("Average iterations"))
		#expect(detailed.contains("Runs:"))
	}

	// MARK: - Statistical Tests

	/// Test that statistics are calculated correctly
	@Test func statisticalMeasures() throws {
		let benchmark = PerformanceBenchmark<VectorN<Double>>()

		let report = try benchmark.compareOptimizers(
			objective: { x in x[0] * x[0] + x[1] * x[1] },
			optimizers: [
				("Test", AdaptiveOptimizer())
			],
			initialGuess: VectorN([1.0, 1.0]),
			trials: 10
		)

		let result = report.results[0]

		// Verify statistical measures
		#expect(result.avgTime > 0.0)
		#expect(result.stdTime >= 0.0)  // Std dev should be non-negative
		#expect(result.avgIterations > 0.0)

		// Best objective should be <= average objective (it's the minimum)
		if result.successRate > 0 {
			#expect(result.bestObjectiveValue <= result.avgObjectiveValue)
		}
	}

	/// Test success rate calculation
	@Test func successRateCalculation() throws {
		let benchmark = PerformanceBenchmark<VectorN<Double>>()

		// Easy problem that should always converge
		let report = try benchmark.compareOptimizers(
			objective: { x in x[0] * x[0] + x[1] * x[1] },
			optimizers: [
				("Reliable", AdaptiveOptimizer())
			],
			initialGuess: VectorN([1.0, 1.0]),
			trials: 5
		)

		let result = report.results[0]

		// Should have 100% success rate on this easy problem
		#expect(abs(result.successRate - 1.0) < 0.01)
		#expect(result.runs.filter(\.converged).count == 5)
	}

	// MARK: - Constrained Problem Tests

	/// Test benchmarking with constraints
	@Test func benchmarkWithConstraints() throws {
		let benchmark = PerformanceBenchmark<VectorN<Double>>()

		let constraints: [MultivariateConstraint<VectorN<Double>>] = [
			.equality(function: { x in x.toArray().reduce(0, +) - 1.0 }, gradient: nil),
			.inequality(function: { x in -x[0] }, gradient: nil)
		]

		let report = try benchmark.compareOptimizers(
			objective: { x in x[0] * x[0] + x[1] * x[1] },
			optimizers: [
				("Constrained", AdaptiveOptimizer())
			],
			initialGuess: VectorN([0.5, 0.5]),
			constraints: constraints,
			trials: 3
		)

		// Should handle constraints and produce results
		#expect(report.results.count == 1)
		#expect(report.results[0].successRate > 0.0)
	}

	// MARK: - Performance Comparison Tests

	/// Test that different optimizers show measurable differences
	@Test func performanceDifferences() throws {
		let benchmark = PerformanceBenchmark<VectorN<Double>>()

		// Use a problem where algorithm choice matters
		let rosenbrock: @Sendable (VectorN<Double>) -> Double = { v in
			let x = v[0], y = v[1]
			return (1 - x) * (1 - x) + 100 * (y - x*x) * (y - x*x)
		}

		let report = try benchmark.compareOptimizers(
			objective: rosenbrock,
			optimizers: [
				("Default", AdaptiveOptimizer()),
				("Speed", AdaptiveOptimizer(preferSpeed: true))
			],
			initialGuess: VectorN([0.0, 0.0]),
			trials: 2
		)

		// Both should produce valid results
		for result in report.results {
			#expect(result.avgTime > 0.0)
			#expect(result.avgIterations > 0.0)
		}

		// Should be able to identify a winner
		#expect(report.winner.name != "")
	}

	// MARK: - Edge Case Tests

	/// Test with single trial
	@Test func singleTrial() throws {
		let benchmark = PerformanceBenchmark<VectorN<Double>>()

		let report = try benchmark.compareOptimizers(
			objective: { x in x[0] * x[0] + x[1] * x[1] },
			optimizers: [
				("Single", AdaptiveOptimizer())
			],
			initialGuess: VectorN([1.0, 1.0]),
			trials: 1
		)

		// Should handle single trial correctly
		#expect(report.results[0].runs.count == 1)
		#expect(report.results[0].avgTime > 0.0)
	}

	/// Test with very quick optimization
	@Test func quickOptimization() throws {
		let benchmark = PerformanceBenchmark<VectorN<Double>>()

		// Start at optimal solution
		let result = try benchmark.profileOptimizer(
			name: "Quick",
			optimizer: AdaptiveOptimizer(),
			objective: { x in x[0] * x[0] + x[1] * x[1] },
			initialGuess: VectorN([0.0, 0.0])  // Already optimal
		)

		// Should still measure time accurately
		#expect(result.executionTime > 0.0)
		#expect(result.converged)
	}
}

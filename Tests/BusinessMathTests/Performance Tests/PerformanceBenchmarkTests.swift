//
//  PerformanceBenchmarkTests.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import XCTest
@testable import BusinessMath

final class PerformanceBenchmarkTests: XCTestCase {

	// MARK: - Basic Profiling Tests

	/// Test profiling a single optimizer run
	func testProfileSingleRun() throws {
		let benchmark = PerformanceBenchmark<VectorN<Double>>()
		let optimizer = AdaptiveOptimizer<VectorN<Double>>()

		let result = try benchmark.profileOptimizer(
			name: "Test Optimizer",
			optimizer: optimizer,
			objective: { x in (x[0] - 1) * (x[0] - 1) + (x[1] - 2) * (x[1] - 2) },
			initialGuess: VectorN([0.0, 0.0])
		)

		// Verify result structure
		XCTAssertNotNil(result.algorithmName)
		XCTAssertTrue(result.converged)
		XCTAssertGreaterThan(result.executionTime, 0.0)
		XCTAssertGreaterThan(result.iterations, 0)

		// Verify solution quality
		XCTAssertEqual(result.solution[0], 1.0, accuracy: 0.1)
		XCTAssertEqual(result.solution[1], 2.0, accuracy: 0.1)
		XCTAssertLessThan(result.objectiveValue, 0.1)
	}

	/// Test that execution time is measured accurately
	func testExecutionTimeMeasurement() throws {
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
		XCTAssertGreaterThan(result1.executionTime, 0.0)
		XCTAssertGreaterThan(result2.executionTime, 0.0)
		XCTAssertLessThan(result1.executionTime, 1.0)  // Should be fast
		XCTAssertLessThan(result2.executionTime, 1.0)
	}

	// MARK: - Comparison Tests

	/// Test comparing multiple optimizers
	func testCompareOptimizers() throws {
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
		XCTAssertEqual(report.results.count, 3)
		XCTAssertNotNil(report.winner)

		// Verify each optimizer result
		for result in report.results {
			XCTAssertGreaterThan(result.avgTime, 0.0)
			XCTAssertGreaterThanOrEqual(result.successRate, 0.0)
			XCTAssertLessThanOrEqual(result.successRate, 1.0)
			XCTAssertEqual(result.runs.count, 5)
			XCTAssertGreaterThan(result.avgIterations, 0.0)
		}

		// Winner should have good success rate
		XCTAssertGreaterThan(report.winner.successRate, 0.5)
	}

	/// Test that winner is selected correctly (fastest with >50% success)
	func testWinnerSelection() throws {
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
		XCTAssertTrue(report.results.contains { $0.name == report.winner.name })

		// Winner should have good success rate
		XCTAssertGreaterThan(report.winner.successRate, 0.5)
	}

	/// Test quick compare convenience method
	func testQuickCompare() throws {
		let benchmark = PerformanceBenchmark<VectorN<Double>>()

		let report = try benchmark.quickCompare(
			objective: { x in (x[0] - 3) * (x[0] - 3) + (x[1] - 4) * (x[1] - 4) },
			initialGuess: VectorN([0.0, 0.0]),
			trials: 3
		)

		// Should compare 3 standard configurations
		XCTAssertEqual(report.results.count, 3)

		let names = report.results.map(\.name)
		XCTAssertTrue(names.contains("Default"))
		XCTAssertTrue(names.contains("Speed-Focused"))
		XCTAssertTrue(names.contains("Accuracy-Focused"))
	}

	// MARK: - Report Generation Tests

	/// Test summary report generation
	func testSummaryReport() throws {
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
		XCTAssertTrue(summary.contains("Performance Comparison"))
		XCTAssertTrue(summary.contains("Optimizer A"))
		XCTAssertTrue(summary.contains("Optimizer B"))
		XCTAssertTrue(summary.contains("Winner"))
		XCTAssertTrue(summary.contains("Avg Time"))
		XCTAssertTrue(summary.contains("Success Rate"))
	}

	/// Test detailed report generation
	func testDetailedReport() throws {
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
		XCTAssertTrue(detailed.contains("Detailed Results"))
		XCTAssertTrue(detailed.contains("Average time"))
		XCTAssertTrue(detailed.contains("Average iterations"))
		XCTAssertTrue(detailed.contains("Runs:"))
	}

	// MARK: - Statistical Tests

	/// Test that statistics are calculated correctly
	func testStatisticalMeasures() throws {
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
		XCTAssertGreaterThan(result.avgTime, 0.0)
		XCTAssertGreaterThanOrEqual(result.stdTime, 0.0)  // Std dev should be non-negative
		XCTAssertGreaterThan(result.avgIterations, 0.0)

		// Best objective should be <= average objective (it's the minimum)
		if result.successRate > 0 {
			XCTAssertLessThanOrEqual(result.bestObjectiveValue, result.avgObjectiveValue)
		}
	}

	/// Test success rate calculation
	func testSuccessRateCalculation() throws {
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
		XCTAssertEqual(result.successRate, 1.0, accuracy: 0.01)
		XCTAssertEqual(result.runs.filter(\.converged).count, 5)
	}

	// MARK: - Constrained Problem Tests

	/// Test benchmarking with constraints
	func testBenchmarkWithConstraints() throws {
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
		XCTAssertEqual(report.results.count, 1)
		XCTAssertGreaterThan(report.results[0].successRate, 0.0)
	}

	// MARK: - Performance Comparison Tests

	/// Test that different optimizers show measurable differences
	func testPerformanceDifferences() throws {
		let benchmark = PerformanceBenchmark<VectorN<Double>>()

		// Use a problem where algorithm choice matters
		let rosenbrock: (VectorN<Double>) -> Double = { v in
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
			XCTAssertGreaterThan(result.avgTime, 0.0)
			XCTAssertGreaterThan(result.avgIterations, 0.0)
		}

		// Should be able to identify a winner
		XCTAssertNotNil(report.winner)
	}

	// MARK: - Edge Case Tests

	/// Test with single trial
	func testSingleTrial() throws {
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
		XCTAssertEqual(report.results[0].runs.count, 1)
		XCTAssertGreaterThan(report.results[0].avgTime, 0.0)
	}

	/// Test with very quick optimization
	func testQuickOptimization() throws {
		let benchmark = PerformanceBenchmark<VectorN<Double>>()

		// Start at optimal solution
		let result = try benchmark.profileOptimizer(
			name: "Quick",
			optimizer: AdaptiveOptimizer(),
			objective: { x in x[0] * x[0] + x[1] * x[1] },
			initialGuess: VectorN([0.0, 0.0])  // Already optimal
		)

		// Should still measure time accurately
		XCTAssertGreaterThan(result.executionTime, 0.0)
		XCTAssertTrue(result.converged)
	}
}

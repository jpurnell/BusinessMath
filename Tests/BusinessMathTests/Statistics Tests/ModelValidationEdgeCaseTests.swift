//
//  ModelValidationEdgeCaseTests.swift
//  BusinessMathTests
//
//  Edge case tests for model validation framework.
//  Tests boundary conditions, numerical stability, and error handling.
//

import XCTest
@testable import BusinessMath

final class ModelValidationEdgeCaseTests: XCTestCase {

	// MARK: - Numerical Stability Tests

	func testReciprocalModel_XNearZero() {
		// When x approaches 0, 1/(a+bx) approaches 1/a
		// Test that model handles this correctly
		let params = ReciprocalRegressionModel<Double>.Parameters(a: 0.5, b: 0.3, sigma: 0.1)

		let mu = ReciprocalRegressionModel<Double>.predictedMean(x: 0.0, params: params)
		XCTAssertEqual(mu, 2.0, accuracy: 1e-10, "At x=0, μ = 1/a = 1/0.5 = 2.0")

		// Very small x
		let muSmall = ReciprocalRegressionModel<Double>.predictedMean(x: 0.001, params: params)
		XCTAssertEqual(muSmall, 1.0 / (0.5 + 0.3 * 0.001), accuracy: 1e-10)
	}

	func testReciprocalModel_LargeX() {
		// When x is very large, 1/(a+bx) ≈ 1/(bx) → 0
		let params = ReciprocalRegressionModel<Double>.Parameters(a: 0.2, b: 0.3, sigma: 0.1)

		let muLarge = ReciprocalRegressionModel<Double>.predictedMean(x: 1000.0, params: params)
		XCTAssertLessThan(muLarge, 0.01, "For large x, mean should approach 0")
		XCTAssertGreaterThan(muLarge, 0, "Mean should always be positive")
	}

	func testReciprocalModel_VerySmallParameters() {
		// Test with parameters near boundary constraints
		let params = ReciprocalRegressionModel<Double>.Parameters(a: 0.001, b: 0.001, sigma: 0.001)

		let mu = ReciprocalRegressionModel<Double>.predictedMean(x: 1.0, params: params)
		XCTAssertTrue(mu.isFinite, "Mean should be finite even with small parameters")
		XCTAssertEqual(mu, 1.0 / 0.002, accuracy: 1e-6, "μ = 1/(0.001 + 0.001*1)")
	}

	func testReciprocalModel_VeryLargeParameters() {
		// Test with large parameter values
		let params = ReciprocalRegressionModel<Double>.Parameters(a: 100.0, b: 100.0, sigma: 10.0)

		let mu = ReciprocalRegressionModel<Double>.predictedMean(x: 1.0, params: params)
		XCTAssertTrue(mu.isFinite, "Mean should be finite even with large parameters")
		XCTAssertEqual(mu, 1.0 / 200.0, accuracy: 1e-10)
	}

	// MARK: - Data Quality Tests

	func testReciprocalFitting_SingleDataPoint() throws {
		// Can't fit 3 parameters with 1 observation
		let data = [ReciprocalRegressionModel<Double>.DataPoint(x: 5.0, y: 1.0)]

		let fitter = ReciprocalRegressionFitter<Double>()

		// Should complete without crashing (though results may not be meaningful)
		let result = try fitter.fit(data: data, maxIterations: 100)

		XCTAssertNotNil(result)
		// Parameters should still be positive due to constraints
		XCTAssertGreaterThan(result.parameters.a, 0)
		XCTAssertGreaterThan(result.parameters.b, 0)
		XCTAssertGreaterThan(result.parameters.sigma, 0)
	}

	func testReciprocalFitting_TwoDataPoints() throws {
		// Two points: underdetermined system (3 parameters, 2 observations)
		let data = [
			ReciprocalRegressionModel<Double>.DataPoint(x: 1.0, y: 2.0),
			ReciprocalRegressionModel<Double>.DataPoint(x: 2.0, y: 1.0)
		]

		let fitter = ReciprocalRegressionFitter<Double>()
		let result = try fitter.fit(data: data, maxIterations: 500)

		XCTAssertNotNil(result)
		XCTAssertTrue(result.parameters.a.isFinite, "a should be finite")
		XCTAssertTrue(result.parameters.b.isFinite, "b should be finite")
		XCTAssertTrue(result.parameters.sigma.isFinite, "sigma should be finite")
	}

	func testReciprocalFitting_IdenticalDataPoints() throws {
		// All points have same x and y - no information about b
		let data = Array(repeating: ReciprocalRegressionModel<Double>.DataPoint(x: 5.0, y: 0.5), count: 10)

		let fitter = ReciprocalRegressionFitter<Double>()
		let result = try fitter.fit(data: data, maxIterations: 500)

		// Should complete without crashing
		XCTAssertNotNil(result)
		XCTAssertGreaterThan(result.parameters.a, 0)
		XCTAssertGreaterThan(result.parameters.b, 0)
	}

	func testReciprocalFitting_ExtremeOutlier() throws {
		// Mostly reasonable data with one extreme outlier
		// Use deterministic seeds for reproducibility
		let seeds = DistributionSeedingTests.seedArray(count: 20)
		let u1Seeds = seeds
		let u2Seeds = Array(seeds.reversed())

		var data: [ReciprocalRegressionModel<Double>.DataPoint] = []

		// Generate reasonable data with SEEDED noise for reproducibility
		for i in 1...20 {
			let x = Double(i)
			let noise = distributionNormal(mean: 0, stdDev: 0.01, u1Seeds[i-1], u2Seeds[i-1])
			let y = 1.0 / (0.2 + 0.3 * x) + noise
			data.append(ReciprocalRegressionModel<Double>.DataPoint(x: x, y: y))
		}

		// Add extreme outlier
		data.append(ReciprocalRegressionModel<Double>.DataPoint(x: 100.0, y: 1000.0))

		let fitter = ReciprocalRegressionFitter<Double>()
		let result = try fitter.fit(data: data, maxIterations: 1000)

		// Should complete without crashing (though fit may be poor)
		XCTAssertNotNil(result)
		XCTAssertTrue(result.parameters.a.isFinite, "Parameter a should be finite even with extreme outlier")
		XCTAssertTrue(result.parameters.b.isFinite, "Parameter b should be finite even with extreme outlier")
		XCTAssertTrue(result.parameters.sigma.isFinite, "Parameter sigma should be finite even with extreme outlier")
	}

	// MARK: - Tolerance Boundary Tests

	func testParameterRecovery_ExactTolerance() throws {
		// Test behavior when error is exactly at tolerance boundary
		let report = try ReciprocalParameterRecoveryCheck.run(
			trueA: 0.2,
			trueB: 0.3,
			trueSigma: 0.2,
			n: 50,
			xRange: 1.0...10.0,
			tolerance: 0.50,  // Very generous tolerance
			maxIterations: 1000
		)

		// With generous tolerance, should typically pass
		// But we're mainly testing that tolerance checking logic works
		for (param, withinTol) in report.withinTolerance {
			let relError = report.relativeErrors[param]!
			if withinTol {
				XCTAssertLessThanOrEqual(relError, report.tolerance,
					"\(param) marked as within tolerance but error exceeds it")
			} else {
				XCTAssertGreaterThan(relError, report.tolerance,
					"\(param) marked as outside tolerance but error is within it")
			}
		}
	}

	func testParameterRecovery_VeryStrictTolerance() throws {
		// With strict tolerance, recovery is more likely to fail
		let report = try ReciprocalParameterRecoveryCheck.run(
			trueA: 0.2,
			trueB: 0.3,
			trueSigma: 0.2,
			n: 50,
			xRange: 1.0...10.0,
			tolerance: 0.01,  // 1% tolerance - very strict
			maxIterations: 1000
		)

		// Test completed without crashing (may or may not pass)
		XCTAssertNotNil(report)
		XCTAssertEqual(report.tolerance, 0.01)

		// Check that failed parameters actually have error > tolerance
		for (param, withinTol) in report.withinTolerance where !withinTol {
			XCTAssertGreaterThan(report.relativeErrors[param]!, 0.01,
				"Failed parameter should have error > tolerance")
		}
	}

	// MARK: - Initialization Sensitivity Tests

	func testReciprocalFitting_PoorInitialization() throws {
		// Test with initialization far from true values
		let simulator = ReciprocalRegressionSimulator<Double>(a: 0.2, b: 0.3, sigma: 0.2)
		let data = simulator.simulate(n: 100, xRange: 1.0...10.0)

		let fitter = ReciprocalRegressionFitter<Double>()

		// Very poor initialization
		let result = try fitter.fit(
			data: data,
			initialGuess: ReciprocalRegressionModel<Double>.Parameters(a: 50.0, b: 50.0, sigma: 10.0),
			learningRate: 0.001,
			maxIterations: 1000
		)

		// Should complete without crashing
		XCTAssertNotNil(result)

		// May or may not converge well, but parameters should be finite and positive
		XCTAssertTrue(result.parameters.a.isFinite && result.parameters.a > 0)
		XCTAssertTrue(result.parameters.b.isFinite && result.parameters.b > 0)
		XCTAssertTrue(result.parameters.sigma.isFinite && result.parameters.sigma > 0)
	}

	func testReciprocalFitting_DifferentLearningRates() throws {
		// Test that different learning rates affect convergence
		let simulator = ReciprocalRegressionSimulator<Double>(a: 0.2, b: 0.3, sigma: 0.2)
		let data = simulator.simulate(n: 100, xRange: 1.0...10.0)

		let fitter = ReciprocalRegressionFitter<Double>()
		let initialGuess = ReciprocalRegressionModel<Double>.Parameters(a: 0.5, b: 0.5, sigma: 0.5)

		// Very slow learning rate
		let resultSlow = try fitter.fit(
			data: data,
			initialGuess: initialGuess,
			learningRate: 0.0001,
			maxIterations: 100
		)

		// Faster learning rate
		let resultFast = try fitter.fit(
			data: data,
			initialGuess: initialGuess,
			learningRate: 0.01,
			maxIterations: 100
		)

		// Both should complete
		XCTAssertNotNil(resultSlow)
		XCTAssertNotNil(resultFast)

		// Faster learning typically achieves better objective in fewer iterations
		// (though not guaranteed due to optimization challenges)
		XCTAssertTrue(resultSlow.iterations <= 100)
		XCTAssertTrue(resultFast.iterations <= 100)
	}

	// MARK: - Extreme Data Range Tests

	func testReciprocalSimulation_VeryNarrowXRange() {
		// X values in tiny range - less information about slope
		let simulator = ReciprocalRegressionSimulator<Double>(a: 0.2, b: 0.3, sigma: 0.1)
		let data = simulator.simulate(n: 100, xRange: 5.0...5.1)

		XCTAssertEqual(data.count, 100)

		// All x values should be in narrow range
		for point in data {
			XCTAssertGreaterThanOrEqual(point.x, 5.0)
			XCTAssertLessThanOrEqual(point.x, 5.1)
		}
	}

	func testReciprocalSimulation_VeryWideXRange() {
		// X values spanning large range - tests numerical stability
		let simulator = ReciprocalRegressionSimulator<Double>(a: 0.2, b: 0.3, sigma: 0.05)
		let data = simulator.simulate(n: 100, xRange: 1.0...100.0)

		XCTAssertEqual(data.count, 100)

		// Check that all y values are finite (tests numerical stability)
		for point in data {
			XCTAssertTrue(point.y.isFinite, "Y values should be finite across wide x range")
		}

		// Expected means vary from ~1/(0.2+0.3*1) = 2.0 to ~1/(0.2+0.3*100) ≈ 0.033
		// So there should be substantial variation in y values
		let yValues = data.map(\.y)
		let yMax = yValues.max()!
		let yMin = yValues.min()!

		// With low noise (sigma=0.05), y values should roughly span from ~0.03 to ~2
		XCTAssertGreaterThan(yMax, 0.5, "Maximum y should reflect small x values")
		XCTAssertLessThan(yMin, 1.0, "Minimum y should reflect large x values")
	}

	// MARK: - Noise Level Tests

	func testReciprocalRecovery_NoNoise() throws {
		// Perfect data (sigma = 0.001, essentially deterministic)
		let report = try ReciprocalParameterRecoveryCheck.run(
			trueA: 0.2,
			trueB: 0.3,
			trueSigma: 0.001,
			n: 100,
			xRange: 1.0...10.0,
			tolerance: 0.20,
			maxIterations: 1500
		)

		// With almost no noise, recovery should be better (though still challenging due to optimization)
		XCTAssertNotNil(report)
		XCTAssertEqual(report.sampleSize, 100)
	}

	func testReciprocalRecovery_HighNoise() throws {
		// Very high noise relative to signal
		let report = try ReciprocalParameterRecoveryCheck.run(
			trueA: 0.2,
			trueB: 0.3,
			trueSigma: 2.0,  // Very large
			n: 200,  // Need more data with high noise
			xRange: 1.0...10.0,
			tolerance: 0.50,  // Must be more tolerant
			maxIterations: 1500
		)

		// Should complete even with high noise
		XCTAssertNotNil(report)
		XCTAssertEqual(report.sampleSize, 200)

		// High noise makes recovery harder
		// But test verifies framework handles it without crashing
	}

	// MARK: - Numerical Gradient Edge Cases

	func testNumericalGradient_VerySmallStepSize() throws {
		// Test with very small h (may hit numerical precision limits)
		let f: (VectorN<Double>) -> Double = { v in
			v[0] * v[0] + v[1] * v[1]
		}

		let point = VectorN<Double>([1.0, 2.0])
		let gradient = try numericalGradient(f, at: point, h: 1e-12)

		// May lose accuracy with very small h
		XCTAssertTrue(gradient[0].isFinite, "Gradient should be finite")
		XCTAssertTrue(gradient[1].isFinite, "Gradient should be finite")

		// Should be reasonably close to true gradient [2, 4]
		// But allow larger error due to numerical precision
		XCTAssertEqual(gradient[0], 2.0, accuracy: 0.1)
		XCTAssertEqual(gradient[1], 4.0, accuracy: 0.1)
	}

	func testNumericalGradient_LargeStepSize() throws {
		// Test with large h (less accurate approximation)
		let f: (VectorN<Double>) -> Double = { v in
			v[0] * v[0] + v[1] * v[1]
		}

		let point = VectorN<Double>([1.0, 2.0])
		let gradient = try numericalGradient(f, at: point, h: 0.1)

		// Should still be finite and reasonable
		XCTAssertTrue(gradient[0].isFinite)
		XCTAssertTrue(gradient[1].isFinite)

		// Accuracy should be worse with large h
		XCTAssertEqual(gradient[0], 2.0, accuracy: 0.5)
		XCTAssertEqual(gradient[1], 4.0, accuracy: 0.5)
	}

	func testNumericalGradient_DiscontiniousFunction() throws {
		// Test on a function with discontinuity (gradient is not well-defined everywhere)
		let f: (VectorN<Double>) -> Double = { v in
			v[0] > 0 ? v[0] * v[0] : 0.0
		}

		let point = VectorN<Double>([0.5])

		// Should complete without crashing
		let gradient = try numericalGradient(f, at: point, h: 1e-6)
		XCTAssertTrue(gradient[0].isFinite)
	}

	// MARK: - Report Summary Tests

	func testParameterRecoveryReport_AllParametersPass() throws {
		// Create a scenario designed to pass easily
		let report = try ReciprocalParameterRecoveryCheck.run(
			trueA: 0.2,
			trueB: 0.3,
			trueSigma: 0.1,
			n: 200,  // Large sample
			xRange: 1.0...10.0,
			tolerance: 0.50,  // Very generous
			maxIterations: 2000
		)

		let summary = report.summary

		// Summary should be well-formatted
		XCTAssertTrue(summary.contains("Parameter Recovery Validation"))
		XCTAssertTrue(summary.contains("Sample Size: 200"))

		// Should show all three parameters
		XCTAssertTrue(summary.contains("a:"))
		XCTAssertTrue(summary.contains("b:"))
		XCTAssertTrue(summary.contains("sigma:"))
	}

	func testParameterRecoveryReport_EmptySummaryHandling() {
		let emptyReports: [ParameterRecoveryReport<Double>] = []
		let summary = ReciprocalParameterRecoveryCheck.summarizeReplicates(emptyReports)

		XCTAssertFalse(summary.isEmpty)
		XCTAssertTrue(summary.contains("No reports"))
	}

	// MARK: - VectorN Edge Cases

	func testNumericalGradient_HighDimensional() throws {
		// Test gradient in high-dimensional space
		let f: (VectorN<Double>) -> Double = { v in
			// Sum of squares: f(x) = Σ xᵢ²
			v.toArray().reduce(0.0) { $0 + $1 * $1 }
		}

		// 10-dimensional vector
		let point = VectorN<Double>(Array(repeating: 1.0, count: 10))
		let gradient = try numericalGradient(f, at: point, h: 1e-6)

		// Gradient should be [2, 2, 2, ..., 2]
		XCTAssertEqual(gradient.dimension, 10)
		for i in 0..<10 {
			XCTAssertEqual(gradient[i], 2.0, accuracy: 1e-4, "Component \(i) should be 2.0")
		}
	}
}

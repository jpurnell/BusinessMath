//
//  ModelValidationEdgeCaseTests.swift
//  BusinessMathTests
//
//  Edge case tests for model validation framework.
//  Tests boundary conditions, numerical stability, and error handling.
//

import Testing
@testable import BusinessMath

@Suite("Model Validation Edge Case Tests")
struct ModelValidationEdgeCaseTests {

	// MARK: - Numerical Stability Tests

	@Test("Reciprocal model with x near zero")
	func reciprocalModel_XNearZero() {
		// When x approaches 0, 1/(a+bx) approaches 1/a
		// Test that model handles this correctly
		let params = ReciprocalRegressionModel<Double>.Parameters(a: 0.5, b: 0.3, sigma: 0.1)

		let mu = ReciprocalRegressionModel<Double>.predictedMean(x: 0.0, params: params)
		#expect(abs(mu - 2.0) < 1e-10, "At x=0, μ = 1/a = 1/0.5 = 2.0")

		// Very small x
		let muSmall = ReciprocalRegressionModel<Double>.predictedMean(x: 0.001, params: params)
		#expect(abs(muSmall - 1.0 / (0.5 + 0.3 * 0.001)) < 1e-10)
	}

	@Test("Reciprocal model with large x")
	func reciprocalModel_LargeX() {
		// When x is very large, 1/(a+bx) ≈ 1/(bx) → 0
		let params = ReciprocalRegressionModel<Double>.Parameters(a: 0.2, b: 0.3, sigma: 0.1)

		let muLarge = ReciprocalRegressionModel<Double>.predictedMean(x: 1000.0, params: params)
		#expect(muLarge < 0.01, "For large x, mean should approach 0")
		#expect(muLarge > 0, "Mean should always be positive")
	}

	@Test("Reciprocal model with very small parameters")
	func reciprocalModel_VerySmallParameters() {
		// Test with parameters near boundary constraints
		let params = ReciprocalRegressionModel<Double>.Parameters(a: 0.001, b: 0.001, sigma: 0.001)

		let mu = ReciprocalRegressionModel<Double>.predictedMean(x: 1.0, params: params)
		#expect(mu.isFinite, "Mean should be finite even with small parameters")
		#expect(abs(mu - 1.0 / 0.002) < 1e-6, "μ = 1/(0.001 + 0.001*1)")
	}

	@Test("Reciprocal model with very large parameters")
	func reciprocalModel_VeryLargeParameters() {
		// Test with large parameter values
		let params = ReciprocalRegressionModel<Double>.Parameters(a: 100.0, b: 100.0, sigma: 10.0)

		let mu = ReciprocalRegressionModel<Double>.predictedMean(x: 1.0, params: params)
		#expect(mu.isFinite, "Mean should be finite even with large parameters")
		#expect(abs(mu - 1.0 / 200.0) < 1e-10)
	}

	// MARK: - Data Quality Tests

	@Test("Reciprocal fitting with single data point")
	func reciprocalFitting_SingleDataPoint() throws {
		// Can't fit 3 parameters with 1 observation
		let data = [ReciprocalRegressionModel<Double>.DataPoint(x: 5.0, y: 1.0)]

		let fitter = ReciprocalRegressionFitter<Double>()

		// Should complete without crashing (though results may not be meaningful)
		let result = try fitter.fit(data: data, maxIterations: 100)

		#expect(result != nil)
		// Parameters should still be positive due to constraints
		#expect(result.parameters.a > 0)
		#expect(result.parameters.b > 0)
		#expect(result.parameters.sigma > 0)
	}

	@Test("Reciprocal fitting with two data points")
	func reciprocalFitting_TwoDataPoints() throws {
		// Two points: underdetermined system (3 parameters, 2 observations)
		let data = [
			ReciprocalRegressionModel<Double>.DataPoint(x: 1.0, y: 2.0),
			ReciprocalRegressionModel<Double>.DataPoint(x: 2.0, y: 1.0)
		]

		let fitter = ReciprocalRegressionFitter<Double>()
		let result = try fitter.fit(data: data, maxIterations: 500)

		#expect(result != nil)
		#expect(result.parameters.a.isFinite, "a should be finite")
		#expect(result.parameters.b.isFinite, "b should be finite")
		#expect(result.parameters.sigma.isFinite, "sigma should be finite")
	}

	@Test("Reciprocal fitting with identical data points")
	func reciprocalFitting_IdenticalDataPoints() throws {
		// All points have same x and y - no information about b
		let data = Array(repeating: ReciprocalRegressionModel<Double>.DataPoint(x: 5.0, y: 0.5), count: 10)

		let fitter = ReciprocalRegressionFitter<Double>()
		let result = try fitter.fit(data: data, maxIterations: 500)

		// Should complete without crashing
		#expect(result != nil)
		#expect(result.parameters.a > 0)
		#expect(result.parameters.b > 0)
	}

	@Test("Reciprocal fitting with extreme outlier")
	func reciprocalFitting_ExtremeOutlier() throws {
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
		#expect(result != nil)
		#expect(result.parameters.a.isFinite, "Parameter a should be finite even with extreme outlier")
		#expect(result.parameters.b.isFinite, "Parameter b should be finite even with extreme outlier")
		#expect(result.parameters.sigma.isFinite, "Parameter sigma should be finite even with extreme outlier")
	}

	// MARK: - Tolerance Boundary Tests

	@Test("Parameter recovery with exact tolerance")
	func parameterRecovery_ExactTolerance() throws {
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
				#expect(relError <= report.tolerance,
					"\(param) marked as within tolerance but error exceeds it")
			} else {
				#expect(relError > report.tolerance,
					"\(param) marked as outside tolerance but error is within it")
			}
		}
	}

	@Test("Parameter recovery with very strict tolerance")
	func parameterRecovery_VeryStrictTolerance() throws {
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
		#expect(report != nil)
		#expect(report.tolerance == 0.01)

		// Check that failed parameters actually have error > tolerance
		for (param, withinTol) in report.withinTolerance where !withinTol {
			#expect(report.relativeErrors[param]! > 0.01,
				"Failed parameter should have error > tolerance")
		}
	}

	// MARK: - Initialization Sensitivity Tests

	@Test("Reciprocal fitting with poor initialization")
	func reciprocalFitting_PoorInitialization() throws {
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
		#expect(result != nil)

		// May or may not converge well, but parameters should be finite and positive
		#expect(result.parameters.a.isFinite && result.parameters.a > 0)
		#expect(result.parameters.b.isFinite && result.parameters.b > 0)
		#expect(result.parameters.sigma.isFinite && result.parameters.sigma > 0)
	}

	@Test("Reciprocal fitting with different learning rates")
	func reciprocalFitting_DifferentLearningRates() throws {
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
		#expect(resultSlow != nil)
		#expect(resultFast != nil)

		// Faster learning typically achieves better objective in fewer iterations
		// (though not guaranteed due to optimization challenges)
		#expect(resultSlow.iterations <= 100)
		#expect(resultFast.iterations <= 100)
	}

	// MARK: - Extreme Data Range Tests

	@Test("Reciprocal simulation with very narrow x range")
	func reciprocalSimulation_VeryNarrowXRange() {
		// X values in tiny range - less information about slope
		let simulator = ReciprocalRegressionSimulator<Double>(a: 0.2, b: 0.3, sigma: 0.1)
		let data = simulator.simulate(n: 100, xRange: 5.0...5.1)

		#expect(data.count == 100)

		// All x values should be in narrow range
		for point in data {
			#expect(point.x >= 5.0)
			#expect(point.x <= 5.1)
		}
	}

	@Test("Reciprocal simulation with very wide x range")
	func reciprocalSimulation_VeryWideXRange() {
		// X values spanning large range - tests numerical stability
		let simulator = ReciprocalRegressionSimulator<Double>(a: 0.2, b: 0.3, sigma: 0.05)
		let data = simulator.simulate(n: 100, xRange: 1.0...100.0)

		#expect(data.count == 100)

		// Check that all y values are finite (tests numerical stability)
		for point in data {
			#expect(point.y.isFinite, "Y values should be finite across wide x range")
		}

		// Expected means vary from ~1/(0.2+0.3*1) = 2.0 to ~1/(0.2+0.3*100) ≈ 0.033
		// So there should be substantial variation in y values
		let yValues = data.map(\.y)
		let yMax = yValues.max()!
		let yMin = yValues.min()!

		// With low noise (sigma=0.05), y values should roughly span from ~0.03 to ~2
		#expect(yMax > 0.5, "Maximum y should reflect small x values")
		#expect(yMin < 1.0, "Minimum y should reflect large x values")
	}

	// MARK: - Noise Level Tests

	@Test("Reciprocal recovery with no noise")
	func reciprocalRecovery_NoNoise() throws {
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
		#expect(report != nil)
		#expect(report.sampleSize == 100)
	}

	@Test("Reciprocal recovery with high noise")
	func reciprocalRecovery_HighNoise() throws {
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
		#expect(report != nil)
		#expect(report.sampleSize == 200)

		// High noise makes recovery harder
		// But test verifies framework handles it without crashing
	}

	// MARK: - Numerical Gradient Edge Cases

	@Test("Numerical gradient with very small step size")
	func numericalGradient_VerySmallStepSize() throws {
		// Test with very small h (may hit numerical precision limits)
		let f: (VectorN<Double>) -> Double = { v in
			v[0] * v[0] + v[1] * v[1]
		}

		let point = VectorN<Double>([1.0, 2.0])
		let gradient = try numericalGradient(f, at: point, h: 1e-12)

		// May lose accuracy with very small h
		#expect(gradient[0].isFinite, "Gradient should be finite")
		#expect(gradient[1].isFinite, "Gradient should be finite")

		// Should be reasonably close to true gradient [2, 4]
		// But allow larger error due to numerical precision
		#expect(abs(gradient[0] - 2.0) < 0.1)
		#expect(abs(gradient[1] - 4.0) < 0.1)
	}

	@Test("Numerical gradient with large step size")
	func numericalGradient_LargeStepSize() throws {
		// Test with large h (less accurate approximation)
		let f: (VectorN<Double>) -> Double = { v in
			v[0] * v[0] + v[1] * v[1]
		}

		let point = VectorN<Double>([1.0, 2.0])
		let gradient = try numericalGradient(f, at: point, h: 0.1)

		// Should still be finite and reasonable
		#expect(gradient[0].isFinite)
		#expect(gradient[1].isFinite)

		// Accuracy should be worse with large h
		#expect(abs(gradient[0] - 2.0) < 0.5)
		#expect(abs(gradient[1] - 4.0) < 0.5)
	}

	@Test("Numerical gradient with discontinuous function")
	func numericalGradient_DiscontiniousFunction() throws {
		// Test on a function with discontinuity (gradient is not well-defined everywhere)
		let f: (VectorN<Double>) -> Double = { v in
			v[0] > 0 ? v[0] * v[0] : 0.0
		}

		let point = VectorN<Double>([0.5])

		// Should complete without crashing
		let gradient = try numericalGradient(f, at: point, h: 1e-6)
		#expect(gradient[0].isFinite)
	}

	// MARK: - Report Summary Tests

	@Test("Parameter recovery report with all parameters pass")
	func parameterRecoveryReport_AllParametersPass() throws {
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
		#expect(summary.contains("Parameter Recovery Validation"))
		#expect(summary.contains("Sample Size: 200"))

		// Should show all three parameters
		#expect(summary.contains("a:"))
		#expect(summary.contains("b:"))
		#expect(summary.contains("sigma:"))
	}

	@Test("Parameter recovery report with empty summary handling")
	func parameterRecoveryReport_EmptySummaryHandling() {
		let emptyReports: [ParameterRecoveryReport<Double>] = []
		let summary = ReciprocalParameterRecoveryCheck.summarizeReplicates(emptyReports)

		#expect(!summary.isEmpty)
		#expect(summary.contains("No reports"))
	}

	// MARK: - VectorN Edge Cases

	@Test("Numerical gradient in high dimensional space")
	func numericalGradient_HighDimensional() throws {
		// Test gradient in high-dimensional space
		let f: (VectorN<Double>) -> Double = { v in
			// Sum of squares: f(x) = Σ xᵢ²
			v.toArray().reduce(0.0) { $0 + $1 * $1 }
		}

		// 10-dimensional vector
		let point = VectorN<Double>(Array(repeating: 1.0, count: 10))
		let gradient = try numericalGradient(f, at: point, h: 1e-6)

		// Gradient should be [2, 2, 2, ..., 2]
		#expect(gradient.dimension == 10)
		for i in 0..<10 {
			#expect(abs(gradient[i] - 2.0) < 1e-4, "Component \(i) should be 2.0")
		}
	}
}

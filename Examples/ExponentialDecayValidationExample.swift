//
//  ExponentialDecayValidationExample.swift
//  BusinessMath Examples
//
//  Demonstrates fake-data simulation for exponential decay model validation.
//  Shows how the Gelman workflow extends to different nonlinear forms.
//

import Foundation
import BusinessMath

// MARK: - Exponential Decay Model Validation

/// This example shows how to apply the fake-data simulation framework
/// to exponential decay models commonly used in science and business.
///
/// Model: y = a * exp(-b*x) + ε, where ε ~ Normal(0, σ²)
///
/// Applications:
/// - Customer churn: retention(t) = initial * exp(-churn_rate * t)
/// - Inventory decay: value(t) = initial * exp(-depreciation * t)
/// - Drug concentration: amount(t) = dose * exp(-elimination_rate * t)

// MARK: - Manual Exponential Decay Implementation

/// Exponential decay: y = a * exp(-b*x) + noise
struct ExponentialDecayModel {
	/// Fit exponential decay using nonlinear least squares (simplified Gauss-Newton)
	/// - Parameter data: Array of (x, y) points
	/// - Returns: (a, b, residualStdDev) or nil if fitting fails
	static func fit(data: [(x: Double, y: Double)], maxIterations: Int = 100) -> (a: Double, b: Double, sigma: Double)? {
		// Initial guess using log-linear transformation
		// ln(y) ≈ ln(a) - b*x
		// This works if all y > 0
		guard data.allSatisfy({ $0.y > 0 }) else {
			return nil  // Cannot use log transform with non-positive y
		}

		let logData = data.map { (x: $0.x, logY: log($0.y)) }

		// Simple linear regression on log(y) vs x
		let n = Double(data.count)
		let meanX = logData.map(\.x).reduce(0, +) / n
		let meanLogY = logData.map(\.logY).reduce(0, +) / n

		var numerator = 0.0
		var denominator = 0.0
		for point in logData {
			let dx = point.x - meanX
			let dy = point.logY - meanLogY
			numerator += dx * dy
			denominator += dx * dx
		}

		let bInit = -numerator / denominator  // Note: negative because ln(y) = ln(a) - b*x
		let aInit = exp(meanLogY + bInit * meanX)

		// Refine with Gauss-Newton iterations
		var a = aInit
		var b = bInit

		for _ in 0..<maxIterations {
			var sumJtJ_aa = 0.0
			var sumJtJ_ab = 0.0
			var sumJtJ_bb = 0.0
			var sumJtr_a = 0.0
			var sumJtr_b = 0.0

			for point in data {
				let predicted = a * exp(-b * point.x)
				let residual = point.y - predicted

				// Jacobian: ∂f/∂a = exp(-b*x), ∂f/∂b = -a*x*exp(-b*x)
				let ja = exp(-b * point.x)
				let jb = -a * point.x * exp(-b * point.x)

				sumJtJ_aa += ja * ja
				sumJtJ_ab += ja * jb
				sumJtJ_bb += jb * jb
				sumJtr_a += ja * residual
				sumJtr_b += jb * residual
			}

			// Solve 2x2 system: JᵀJ * delta = Jᵀr
			let det = sumJtJ_aa * sumJtJ_bb - sumJtJ_ab * sumJtJ_ab
			if abs(det) < 1e-12 {
				break  // Singular matrix
			}

			let deltaA = (sumJtJ_bb * sumJtr_a - sumJtJ_ab * sumJtr_b) / det
			let deltaB = (sumJtJ_aa * sumJtr_b - sumJtJ_ab * sumJtr_a) / det

			a += deltaA
			b += deltaB

			// Keep parameters positive
			a = max(a, 1e-6)
			b = max(b, 1e-6)

			// Check convergence
			if abs(deltaA) < 1e-6 && abs(deltaB) < 1e-6 {
				break
			}
		}

		// Compute residual standard deviation
		let residuals = data.map { point in
			let predicted = a * exp(-b * point.x)
			return point.y - predicted
		}

		let sumSquaredResiduals = residuals.map { $0 * $0 }.reduce(0, +)
		let sigma = sqrt(sumSquaredResiduals / (n - 2))

		return (a, b, sigma)
	}
}

// MARK: - Example 1: Basic Exponential Decay Recovery

func example1_BasicExponentialDecay() {
	print(String(repeating: "*", count: 60))
	print("Example 1: Exponential Decay Parameter Recovery")
	print(String(repeating: "*", count: 60))
	print()

	// Step 1: Specify true parameters
	let trueA = 10.0      // Initial value
	let trueB = 0.5       // Decay rate
	let trueSigma = 0.5   // Noise level

	print("True Parameters:")
	print("  Initial value (a) = \(trueA)")
	print("  Decay rate (b)    = \(trueB)")
	print("  Sigma (σ)         = \(trueSigma)")
	print()
	print("Model: y = \(trueA) * exp(-\(trueB) * x) + ε")
	print()

	// Step 2: Simulate data
	print("Step 2: Simulating 100 observations...")
	var data: [(x: Double, y: Double)] = []

	for _ in 0..<100 {
		let x = Double.random(in: 0...5)
		let mu = trueA * exp(-trueB * x)
		let y = distributionNormal(mean: mu, stdDev: trueSigma)
		data.append((x, y))
	}
	print("  ✓ Generated \(data.count) points")
	print()

	// Step 3: Fit the model
	print("Step 3: Fitting exponential decay model...")
	guard let (recoveredA, recoveredB, recoveredSigma) = ExponentialDecayModel.fit(data: data) else {
		print("  ✗ Fitting failed!")
		return
	}
	print("  ✓ Fitting completed")
	print()

	// Step 4: Check recovery
	print("Step 4: Parameter Recovery Check")
	print()
	print("  Parameter   | True   | Recovered | Abs Error | Rel Error | Status")
	print("  " + String(repeating: "-", count: 68))

	let params = [
		("Initial (a)", trueA, recoveredA),
		("Decay (b)", trueB, recoveredB),
		("Sigma", trueSigma, recoveredSigma)
	]

	for (name, trueVal, recoveredVal) in params {
		let absError = abs(recoveredVal - trueVal)
		let relError = absError / abs(trueVal)
		let status = relError <= 0.15 ? "✓ PASS" : "✗ FAIL"
		print("  \(name.padding(toLength: 11, withPad: " ", startingAt: 0)) | \(trueVal.formatted().padding(toLength: 6, withPad: " ", startingAt: 0)) | \(recoveredVal.formatted().padding(toLength: 9, withPad: " ", startingAt: 0)) | \(absError.formatted().padding(toLength: 9, withPad: " ", startingAt: 0)) | \((relError * 100).formatted().padding(toLength: 8, withPad: " ", startingAt: 0))% | \(status)")
	}
	print()

	print("Observation: Exponential decay models typically achieve good")
	print("parameter recovery when data spans the decay range well.")
}

// MARK: - Example 2: Business Application - Customer Retention

func example2_CustomerRetentionModel() {
	print("\n")
	print(String(repeating: "*", count: 60))
	print("Example 2: Customer Retention Validation")
	print(String(repeating: "*", count: 60))
	print()

	print("Business Context:")
	print("  You're modeling customer retention over time.")
	print("  Model: retention(t) = 100% * exp(-churn_rate * months)")
	print()
	
		// True retention model
	let initialRetention = 1.0      // 100%
	let monthlyChurnRate = 0.05     // 5% monthly churn means ~60% retention after 1 year
	let noiseSigma = 0.03           // ±3% measurement noise
	
	print("True Model:")
	print("  Initial retention:  \((initialRetention * 100).formatted())%")
	print("  Monthly churn rate: \((monthlyChurnRate * 100).formatted())%")
	print("  12-month retention: \((initialRetention * exp(-monthlyChurnRate * 12) * 100).formatted())%")
	print()
	
		// Simulate 24 months of data
	print("Simulating 24 months of retention data...")
	var data: [(x: Double, y: Double)] = []
	for month in 1...24 {
		let x = Double(month)
		let trueRetention = initialRetention * exp(-monthlyChurnRate * x)
		let observed = distributionNormal(mean: trueRetention, stdDev: noiseSigma)
		data.append((x, observed))
	}
	print("  ✓ Generated \(data.count) monthly observations")
	print()
	
		// Fit model
	print("Fitting retention model...")
	guard let (a, b, sigma) = ExponentialDecayModel.fit(data: data) else {
		print("  ✗ Fitting failed!")
		return
	}
	print("  ✓ Fitting completed")
	print()
	
	print("Recovered Model:")
	print("  Initial retention:  \((a * 100).formatted())")
	print("  Monthly churn rate: \((b * 100).formatted())%")
	print("  12-month retention: \((a * exp(-b * 12) * 100).formatted())%")
	print()
	
		// Validation
	let churnError = abs(b - monthlyChurnRate) / monthlyChurnRate
	if churnError <= 0.10 {
		print("✓ VALIDATION PASSED: Churn rate recovered within 10%")
		print("  → Safe to use this model for retention forecasting")
	} else {
		print("✗ VALIDATION FAILED: Churn rate error = \((churnError * 100).formatted())%")
		print("  → Need more data or different model")
	}
}

	// MARK: - Example 3: Why X-Range Matters

func example3_DataRangeImpact() {
	print("\n")
	print(String(repeating: "*", count: 60))
	print("Example 3: Impact of Data Range on Recovery")
	print(String(repeating: "*", count: 60))
	print()
	
	let trueA = 10.0
	let trueB = 0.5
	let trueSigma = 0.3
	
	print("Testing parameter recovery with different x ranges:")
	print()
	
	struct RangeTest {
		let name: String
		let xRange: ClosedRange<Double>
		let n: Int
	}
	
	let tests = [
		RangeTest(name: "Short range", xRange: 0.0...1.0, n: 50),
		RangeTest(name: "Medium range", xRange: 0.0...3.0, n: 50),
		RangeTest(name: "Long range", xRange: 0.0...10.0, n: 50),
		RangeTest(name: "Very long range", xRange: 0.0...20.0, n: 50)
	]
	
	print("  Range         | N  | Decay (b) Recovered | Rel Error | Status")
	print("  " + String(repeating: "-", count: 66))
	
	for test in tests {
			// Simulate data
		var data: [(x: Double, y: Double)] = []
		for _ in 0..<test.n {
			let x = Double.random(in: test.xRange)
			let mu = trueA * exp(-trueB * x)
			let y = distributionNormal(mean: mu, stdDev: trueSigma)
			data.append((x, y))
		}
		
			// Fit
		guard let (_, recoveredB, _) = ExponentialDecayModel.fit(data: data) else {
			print("  \(test.name.padding(toLength: 13, withPad: " ", startingAt: 0)) | \(test.n.formatted()) | \("FAILED".padding(toLength: 19, withPad: " ", startingAt: 0)) | \("N/A".padding(toLength: 9, withPad: " ", startingAt: 0)) | \("✗ FAIL")")
			continue
		}
		
		let relError = abs(recoveredB - trueB) / trueB
		let status = relError <= 0.20 ? "✓ PASS" : "✗ FAIL"
		print("  \(test.name.padding(toLength: 13, withPad: " ", startingAt: 0)) | \(test.n.formatted()) | \(recoveredB.formatted().padding(toLength: 19, withPad: " ", startingAt: 0)) | \((relError * 100).formatted().padding(toLength: 9, withPad: " ", startingAt: 0)) | \(status)")
	}
	
	print()
	print("Key Insight:")
	print("  For exponential decay, x-range matters! With short range,")
	print("  the model looks nearly linear and decay rate is hard to estimate.")
	print("  Need x-range spanning several decay constants (1/b ≈ 2 in this case).")
}

	// MARK: - Example 4: Comparing to BusinessMath Nonlinear Fitting

func example4_ComparisonToReciprocalModel() {
	print("\n")
	print(String(repeating: "*", count: 60))
	print("Example 4: Exponential vs Reciprocal Model Recovery")
	print(String(repeating: "*", count: 60))
	print()
	
	print("Comparing parameter recovery for two nonlinear models:")
	print("  1. Exponential: y = a * exp(-b*x) + ε")
	print("  2. Reciprocal:  y = 1/(a + b*x) + ε")
	print()
	
		// Exponential recovery
	print("Exponential Decay Recovery:")
	var expData: [(x: Double, y: Double)] = []
	for _ in 0..<100 {
		let x = Double.random(in: 0...5)
		let y = 10.0 * exp(-0.5 * x) + distributionNormal(mean: 0, stdDev: 0.3)
		expData.append((x, y))
	}
	
	if let (aEst, bEst, _) = ExponentialDecayModel.fit(data: expData) {
		let aError = abs(aEst - 10.0) / 10.0
		let bError = abs(bEst - 0.5) / 0.5
		print("  Parameter a: \((aError * 100).formatted())% error")
		print("  Parameter b: \((bError * 100).formatted())% error")
	} else {
		print("  Fitting failed")
	}
	print()
	
		// Reciprocal recovery (using BusinessMath)
	print("Reciprocal Regression Recovery:")
	do {
		let report = try ReciprocalParameterRecoveryCheck.run(
			trueA: 0.2,
			trueB: 0.3,
			trueSigma: 0.2,
			n: 100,
			xRange: 1.0...10.0,
			tolerance: 0.30,
			maxIterations: 2000
		)
		
		if let aError = report.relativeErrors["a"],
		   let bError = report.relativeErrors["b"] {
			print("  Parameter a: \((aError * 100).formatted())% error")
			print("  Parameter b: \((bError * 100).formatted())% error")
		}
		
	} catch {
		print("  Error: \(error)")
	}
	print()
	
	print("Key Insight:")
	print("  Different nonlinear forms have different identifiability.")
	print("  Exponential decay with good x-range coverage tends to be")
	print("  more numerically stable than reciprocal models.")
}

	// MARK: - Example 5: When Exponential Fitting Fails

func example5_WhenExponentialFittingFails() {
	print("\n")
	print(String(repeating: "*", count: 60))
	print("Example 5: Failure Modes for Exponential Decay")
	print(String(repeating: "*", count: 60))
	print()
	
	print("Exponential decay fitting can fail in several ways:")
	print()
	
		// Failure 1: Negative y values
	print("Failure Mode 1: Data contains negative values")
	let badData1 = [(x: 1.0, y: -0.5), (x: 2.0, y: 1.0), (x: 3.0, y: 0.8)]
	if ExponentialDecayModel.fit(data: badData1) == nil {
		print("  ✓ Correctly rejected: Cannot use log-transform with y ≤ 0")
	}
	print()
	
		// Failure 2: Increasing trend (should be decreasing)
	print("Failure Mode 2: Data shows increasing trend (not decay)")
	var increasingData: [(x: Double, y: Double)] = []
	for i in 0..<20 {
		let x = Double(i) / 2.0
		let y = 2.0 + 0.5 * x + distributionNormal(mean: 0, stdDev: 0.1)
		increasingData.append((x, y))
	}
	
	if let (_, b, _) = ExponentialDecayModel.fit(data: increasingData) {
		print("  Estimated decay rate: \(b.formatted(maxDecimals: 3))")
		if b < 0 {
			print("  ✗ Negative decay rate indicates wrong model!")
			print("  → Should use growth model, not decay model")
		} else if b < 0.01 {
			print("  ✗ Near-zero decay rate indicates poor fit")
			print("  → Data doesn't follow decay pattern")
		}
	}
	print()
	
		// Failure 3: Too much noise
	print("Failure Mode 3: Signal-to-noise ratio too low")
	var noisyData: [(x: Double, y: Double)] = []
	for _ in 0..<50 {
		let x = Double.random(in: 0...3)
		let signal = 5.0 * exp(-0.3 * x)
		let y = signal + distributionNormal(mean: 0, stdDev: 5.0)  // Noise same magnitude as signal!
		noisyData.append((x, max(y, 0.001)))  // Clip to positive
	}
	
	if let (aTrue, bTrue, _) = ExponentialDecayModel.fit(data: noisyData) {
			// True parameters: a=5.0, b=0.3
		let relErrorA = abs(aTrue - 5.0) / 5.0
		let relErrorB = abs(bTrue - 0.3) / 0.3
		
		print("  Parameter a error: \((relErrorA * 100).formatted())%")
		print("  Parameter b error: \((relErrorB * 100).formatted())%")
		
		if relErrorA > 0.50 || relErrorB > 0.50 {
			print("  ✗ Poor recovery with high noise")
			print("  → Need more data or better measurement precision")
		}
	}
	print()
	
	print("Conclusion: Fake-data simulation reveals these failure modes")
	print("before you waste time on real data that won't work!")
}

	// MARK: - Main

func runAllExponentialDecayExamples() {
	print("\n")
	print("╔" + String(repeating: "═", count: 58) + "╗")
	print("║  Exponential Decay Model Validation                      ║")
	print("║  Fake-Data Simulation for Business Applications          ║")
	print("╚" + String(repeating: "═", count: 58) + "╝")
	print()
	
	example1_BasicExponentialDecay()
	example2_CustomerRetentionModel()
	example3_DataRangeImpact()
	example4_ComparisonToReciprocalModel()
	example5_WhenExponentialFittingFails()
	
	print("\n")
	print("╔" + String(repeating: "═", count: 58) + "╗")
	print("║  Key Takeaways                                           ║")
	print("╚" + String(repeating: "═", count: 58) + "╝")
	print()
	print("1. Exponential decay models are common in business (retention, decay)")
	print("2. X-range coverage is critical - need to span several decay constants")
	print("3. Log-linear initialization provides good starting point for fitting")
	print("4. Different nonlinear models have different numerical stability")
	print("5. Fake-data simulation reveals data requirements before collection")
	print()
}

	// Uncomment to run:
runAllExponentialDecayExamples()

	// Or run individual examples:
	// example1_BasicExponentialDecay()
	// example2_CustomerRetentionModel()
	// example3_DataRangeImpact()
	// example4_ComparisonToReciprocalModel()
	// example5_WhenExponentialFittingFails()

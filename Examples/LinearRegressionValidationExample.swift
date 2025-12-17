//
//  LinearRegressionValidationExample.swift
//  BusinessMath Examples
//
//  Demonstrates fake-data simulation for linear regression validation.
//  Shows how the Gelman workflow applies to simpler models.
//

import Foundation
import BusinessMath

// MARK: - Simple Linear Regression Validation

/// This example shows how to apply the fake-data simulation framework
/// to the simplest possible case: ordinary least squares linear regression.
///
/// Model: y = β₀ + β₁*x + ε, where ε ~ Normal(0, σ²)
///
/// The point: even for simple models where we know fitting "should" work,
/// it's still valuable to verify it actually does work correctly.

// MARK: - Manual Linear Regression Implementation

/// Simple linear regression: y = intercept + slope*x + noise
struct SimpleLinearRegression {
	/// Fit linear regression using ordinary least squares
	/// - Parameter data: Array of (x, y) points
	/// - Returns: (intercept, slope, residualStdDev)
	static func fit(data: [(x: Double, y: Double)]) -> (intercept: Double, slope: Double, sigma: Double) {
		let n = Double(data.count)

		// Compute means
		let meanX = data.map(\.x).reduce(0, +) / n
		let meanY = data.map(\.y).reduce(0, +) / n

		// Compute slope: β₁ = Σ[(xᵢ - x̄)(yᵢ - ȳ)] / Σ[(xᵢ - x̄)²]
		var numerator = 0.0
		var denominator = 0.0

		for point in data {
			let dx = point.x - meanX
			let dy = point.y - meanY
			numerator += dx * dy
			denominator += dx * dx
		}

		let slope = numerator / denominator
		let intercept = meanY - slope * meanX

		// Compute residual standard deviation
		let residuals = data.map { point in
			let predicted = intercept + slope * point.x
			return point.y - predicted
		}

		let sumSquaredResiduals = residuals.map { $0 * $0 }.reduce(0, +)
		let sigma = sqrt(sumSquaredResiduals / (n - 2))  // n-2 degrees of freedom

		return (intercept, slope, sigma)
	}
}

// MARK: - Example 1: Perfect Linear Regression Recovery

func example1_PerfectLinearRegression() {
	print(String(repeating: "*", count: 60))
	print("Example 1: Linear Regression Parameter Recovery")
	print(String(repeating: "*", count: 60))
	print()

	// Step 1: Specify true parameters
	let trueIntercept = 2.0
	let trueSlope = 0.5
	let trueSigma = 0.3

	print("True Parameters:")
	print("  Intercept (β₀) = \(trueIntercept)")
	print("  Slope (β₁)     = \(trueSlope)")
	print("  Sigma (σ)      = \(trueSigma)")
	print()

	// Step 2: Simulate data
	print("Step 2: Simulating 100 observations...")
	var data: [(x: Double, y: Double)] = []

	for _ in 0..<100 {
		let x = Double.random(in: 0...10)
		let mu = trueIntercept + trueSlope * x
		let y = distributionNormal(mean: mu, stdDev: trueSigma)
		data.append((x, y))
	}
	print("  ✓ Generated \(data.count) points")
	print()

	// Step 3: Fit the model
	print("Step 3: Fitting linear regression...")
	let (recoveredIntercept, recoveredSlope, recoveredSigma) = SimpleLinearRegression.fit(data: data)
	print("  ✓ Fitting completed (OLS has closed-form solution)")
	print()

	// Step 4: Check recovery
	print("Step 4: Parameter Recovery Check")
	print()
	print("  Parameter  | True   | Recovered | Abs Error | Rel Error | Status")
	print("  " + String(repeating: "-", count: 68))

	let params = [
		("Intercept", trueIntercept, recoveredIntercept),
		("Slope", trueSlope, recoveredSlope),
		("Sigma", trueSigma, recoveredSigma)
	]

	for (name, trueVal, recoveredVal) in params {
		let absError = abs(recoveredVal - trueVal)
		let relError = absError / abs(trueVal)
		let status = relError <= 0.10 ? "✓ PASS" : "✗ FAIL"

		print("  \(name.padding(toLength: 10, withPad: " ", startingAt: 0)) | \(trueVal.formatted().paddingLeft(toLength: 6)) | \(recoveredVal.formatted().paddingLeft(toLength: 9)) | \(absError.formatted().paddingLeft(toLength: 9)) | \((relError * 100).formatted().paddingLeft(toLength: 8))% | \(status)")
	}
	print()

	print("Observation: Linear regression with OLS typically achieves")
	print("excellent parameter recovery, even with moderate sample sizes.")
}

// MARK: - Example 2: Why This Matters Even for Simple Models

func example2_WhyItMatters() {
	print("\n")
	print(String(repeating: "*", count: 60))
	print("Example 2: Why Validate Even Simple Models?")
	print(String(repeating: "*", count: 60))
	print()

	print("You might think: 'Linear regression is so simple, why bother?'")
	print()
	print("Here are scenarios where even OLS can fail:")
	print()

	// Scenario 1: Perfect multicollinearity
	print("Scenario 1: Perfect multicollinearity")
	print("  If x values are all the same, slope is undefined!")
	let badData1 = Array(repeating: (x: 5.0, y: 2.0), count: 100)

	// This would crash or give NaN:
	// let result = SimpleLinearRegression.fit(data: badData1)

	print("  Result: Division by zero (denominator = 0)")
	print("  ✓ Fake-data simulation would catch this before real data!")
	print()

	// Scenario 2: Numerical instability
	print("Scenario 2: Extreme scale differences")
	print("  If x ranges from 0.000001 to 0.000002, numerical issues arise")
	print("  ✓ Validation helps identify when rescaling is needed")
	print()

	// Scenario 3: Outliers
	print("Scenario 3: Single outlier dominates fit")
	var goodData: [(x: Double, y: Double)] = []
	for i in 0..<100 {
		let x = Double(i) / 10.0
		let y = 2.0 + 0.5 * x + distributionNormal(mean: 0, stdDev: 0.1)
		goodData.append((x, y))
	}
	goodData.append((x: 50.0, y: 1000.0))  // Extreme outlier

	let (int1, slope1, _) = SimpleLinearRegression.fit(data: goodData.dropLast())
	let (int2, slope2, _) = SimpleLinearRegression.fit(data: goodData)

	print("  Without outlier: y = \(int1.formatted()) + \(slope1.formatted())x")
	print("  With outlier:    y = \(int2.formatted()) + \(slope2.formatted())x")
	print("  ✓ Dramatic change! Fake-data helps test robustness.")
	print()

	print("Conclusion: Even for 'simple' models, validation matters!")
}

// MARK: - Example 3: Comparing to Reciprocal Regression

func example3_ComparingModels() {
	print("\n")
	print(String(repeating: "*", count: 60))
	print("Example 3: Linear vs Nonlinear Regression Recovery")
	print(String(repeating: "*", count: 60))
	print()

	print("Let's compare parameter recovery for two models:")
	print("  1. Linear:     y = β₀ + β₁*x + ε")
	print("  2. Reciprocal: y = 1/(a + b*x) + ε")
	print()

	// Linear regression recovery
	print("Linear Regression Recovery:")
	var linearData: [(x: Double, y: Double)] = []
	for _ in 0..<100 {
		let x = Double.random(in: 0...10)
		let y = 2.0 + 0.5 * x + distributionNormal(mean: 0, stdDev: 0.3)
		linearData.append((x, y))
	}

	let (intEst, slopeEst, _) = SimpleLinearRegression.fit(data: linearData)
	let intError = abs(intEst - 2.0) / 2.0
	let slopeError = abs(slopeEst - 0.5) / 0.5

	print("  Intercept: \((intError * 100).formatted())% error")
	print("  Slope:     \((slopeError * 100).formatted())% error")
	print()

	// Reciprocal regression (using BusinessMath implementation)
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
	print("  Linear models (with closed-form solutions) typically achieve")
	print("  better parameter recovery than nonlinear models (requiring")
	print("  iterative optimization). This is why Gelman emphasizes checking")
	print("  recovery - nonlinear models are more prone to failure!")
}

// MARK: - Example 4: Systematic Validation Framework

func example4_SystematicValidation() {
	print("\n")
	print(String(repeating: "*", count: 60))
	print("Example 4: Building a Validation Test Suite")
	print(String(repeating: "*", count: 60))
	print()

	print("For any model, create a systematic validation suite:")
	print()

	struct ValidationTest {
		let name: String
		let trueIntercept: Double
		let trueSlope: Double
		let trueSigma: Double
		let n: Int

		func run() -> (passed: Bool, avgRelError: Double) {
			// Simulate
			var data: [(x: Double, y: Double)] = []
			for _ in 0..<n {
				let x = Double.random(in: 0...10)
				let mu = trueIntercept + trueSlope * x
				let y = distributionNormal(mean: mu, stdDev: trueSigma)
				data.append((x, y))
			}

			// Fit
			let (estInt, estSlope, estSigma) = SimpleLinearRegression.fit(data: data)

			// Check
			let relErrors = [
				abs(estInt - trueIntercept) / abs(trueIntercept),
				abs(estSlope - trueSlope) / abs(trueSlope),
				abs(estSigma - trueSigma) / abs(trueSigma)
			]

			let avgError = relErrors.reduce(0, +) / Double(relErrors.count)
			let passed = relErrors.allSatisfy { $0 <= 0.20 }  // 20% tolerance

			return (passed, avgError)
		}
	}

	let tests = [
		ValidationTest(name: "Standard case", trueIntercept: 2.0, trueSlope: 0.5, trueSigma: 0.3, n: 100),
		ValidationTest(name: "No intercept", trueIntercept: 0.0, trueSlope: 1.0, trueSigma: 0.2, n: 100),
		ValidationTest(name: "Negative slope", trueIntercept: 5.0, trueSlope: -0.3, trueSigma: 0.1, n: 100),
		ValidationTest(name: "High noise", trueIntercept: 2.0, trueSlope: 0.5, trueSigma: 1.0, n: 100),
		ValidationTest(name: "Small sample", trueIntercept: 2.0, trueSlope: 0.5, trueSigma: 0.3, n: 20)
	]

	print("  Test Name        | Status  | Avg Rel Error")
	print("  " + String(repeating: "-", count: 45))

	for test in tests {
		let (passed, avgError) = test.run()
		let status = passed ? "✓ PASS" : "✗ FAIL"
		print("  \(test.name.padding(toLength: 16, withPad: " ", startingAt: 0)) | \(status.paddingLeft(toLength: 7)) | \((avgError * 100).formatted())%")
	}

	print()
	print("A complete validation suite tests:")
	print("  - Edge cases (zero intercept, negative slope)")
	print("  - Challenging conditions (high noise, small n)")
	print("  - Typical scenarios")
}

// MARK: - Main

func runAllLinearRegressionExamples() {
	print("\n")
	print("╔" + String(repeating: "═", count: 58) + "╗")
	print("║  Linear Regression Fake-Data Validation                  ║")
	print("║  Showing How the Gelman Framework Applies to All Models  ║")
	print("╚" + String(repeating: "═", count: 58) + "╝")
	print()

	example1_PerfectLinearRegression()
	example2_WhyItMatters()
	example3_ComparingModels()
	example4_SystematicValidation()

	print("\n")
	print("╔" + String(repeating: "═", count: 58) + "╗")
	print("║  Key Takeaways                                           ║")
	print("╚" + String(repeating: "═", count: 58) + "╝")
	print()
	print("1. Fake-data validation applies to ALL models, not just complex ones")
	print("2. Linear regression provides a 'best case' baseline for comparison")
	print("3. Build systematic test suites covering edge cases")
	print("4. Even simple models can fail in unexpected ways")
	print("5. The simpler the model, the easier parameter recovery should be")
	print()
}

// Uncomment to run:
 runAllLinearRegressionExamples()

// Or run individual examples:
// example1_PerfectLinearRegression()
// example2_WhyItMatters()
// example3_ComparingModels()
// example4_SystematicValidation()


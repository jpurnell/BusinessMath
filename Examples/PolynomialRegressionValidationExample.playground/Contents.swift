//
//  PolynomialRegressionValidationExample.swift
//  BusinessMath Examples
//
//  Demonstrates fake-data simulation for polynomial regression validation.
//  Shows model selection and overfitting detection through validation.
//

import Foundation
import BusinessMath

// MARK: - Polynomial Regression Model Validation

/// This example shows how to apply the fake-data simulation framework
/// to polynomial regression models with model selection considerations.
///
/// Model: y = β₀ + β₁*x + β₂*x² + ... + βₚ*xᵖ + ε, where ε ~ Normal(0, σ²)
///
/// Applications:
/// - Revenue curves: sales(price) = a + b*price + c*price²
/// - Cost functions: cost(volume) = fixed + variable*volume + overhead*volume²
/// - Growth trajectories: size(time) = a + b*t + c*t²

// MARK: - Polynomial Regression Implementation

/// Polynomial regression using ordinary least squares
struct PolynomialRegression {

	/// Fit polynomial regression of specified degree
	/// - Parameters:
	///   - data: Array of (x, y) points
	///   - degree: Polynomial degree (1 = linear, 2 = quadratic, etc.)
	/// - Returns: Coefficients [β₀, β₁, β₂, ..., βₚ] and residual std dev
	static func fit(data: [(x: Double, y: Double)], degree: Int) -> (coefficients: [Double], sigma: Double)? {
		let n = data.count
		guard n > degree + 1 else {
			return nil  // Need more points than parameters
		}

		// Build design matrix X (n × (degree+1))
		// Each row: [1, x, x², x³, ..., xᵖ]
		var X: [[Double]] = []
		var y: [Double] = []

		for point in data {
			var row: [Double] = []
			for p in 0...degree {
				row.append(pow(point.x, Double(p)))
			}
			X.append(row)
			y.append(point.y)
		}

		// Solve normal equations: XᵀX β = Xᵀy
		// Using simplified approach for small polynomials
		guard let beta = solveNormalEquations(X: X, y: y) else {
			return nil
		}

		// Compute residual standard deviation
		var sumSquaredResiduals = 0.0
		for i in 0..<n {
			var predicted = 0.0
			for p in 0...degree {
				predicted += beta[p] * pow(data[i].x, Double(p))
			}
			let residual = data[i].y - predicted
			sumSquaredResiduals += residual * residual
		}

		let degreesOfFreedom = Double(n - (degree + 1))
		let sigma = sqrt(sumSquaredResiduals / degreesOfFreedom)

		return (beta, sigma)
	}

	/// Predict y for given x using fitted coefficients
	static func predict(x: Double, coefficients: [Double]) -> Double {
		var y = 0.0
		for (p, coef) in coefficients.enumerated() {
			y += coef * pow(x, Double(p))
		}
		return y
	}

	/// Simplified normal equations solver for small systems
	private static func solveNormalEquations(X: [[Double]], y: [Double]) -> [Double]? {
		let n = X.count
		let p = X[0].count

		// Compute XᵀX
		var XtX: [[Double]] = Array(repeating: Array(repeating: 0.0, count: p), count: p)
		for i in 0..<p {
			for j in 0..<p {
				var sum = 0.0
				for k in 0..<n {
					sum += X[k][i] * X[k][j]
				}
				XtX[i][j] = sum
			}
		}

		// Compute Xᵀy
		var Xty: [Double] = Array(repeating: 0.0, count: p)
		for i in 0..<p {
			var sum = 0.0
			for k in 0..<n {
				sum += X[k][i] * y[k]
			}
			Xty[i] = sum
		}

		// Solve using Gaussian elimination
		return gaussianElimination(A: XtX, b: Xty)
	}

	/// Simple Gaussian elimination for small systems
	private static func gaussianElimination(A: [[Double]], b: [Double]) -> [Double]? {
		let n = A.count
		var A = A
		var b = b

		// Forward elimination
		for i in 0..<n {
			// Find pivot
			var maxRow = i
			for k in (i+1)..<n {
				if abs(A[k][i]) > abs(A[maxRow][i]) {
					maxRow = k
				}
			}

			// Swap rows
			A.swapAt(i, maxRow)
			b.swapAt(i, maxRow)

			// Check for singular matrix
			if abs(A[i][i]) < 1e-12 {
				return nil
			}

			// Eliminate
			for k in (i+1)..<n {
				let factor = A[k][i] / A[i][i]
				for j in i..<n {
					A[k][j] -= factor * A[i][j]
				}
				b[k] -= factor * b[i]
			}
		}

		// Back substitution
		var x = Array(repeating: 0.0, count: n)
		for i in stride(from: n-1, through: 0, by: -1) {
			var sum = b[i]
			for j in (i+1)..<n {
				sum -= A[i][j] * x[j]
			}
			x[i] = sum / A[i][i]
		}

		return x
	}
}

// MARK: - Example 1: Quadratic Model Recovery

func example1_QuadraticRecovery() {
	print(String(repeating: "*", count: 60))
	print("Example 1: Quadratic Polynomial Recovery")
	print(String(repeating: "*", count: 60))
	print()

	// True model: y = 2 + 3x - 0.5x² + ε
	let trueBeta0 = 2.0
	let trueBeta1 = 3.0
	let trueBeta2 = -0.5
	let trueSigma = 0.5

	print("True Model: y = \(trueBeta0) + \(trueBeta1)x - \(abs(trueBeta2))x²")
	print("Noise: σ = \(trueSigma)")
	print()

	// Simulate 100 points
	print("Simulating 100 observations...")
	var data: [(x: Double, y: Double)] = []
	for _ in 0..<100 {
		let x = Double.random(in: -2...2)
		let mu = trueBeta0 + trueBeta1 * x + trueBeta2 * x * x
		let y = distributionNormal(mean: mu, stdDev: trueSigma)
		data.append((x, y))
	}
	print("  ✓ Generated \(data.count) points")
	print()

	// Fit quadratic model
	print("Fitting quadratic model...")
	guard let (beta, sigma) = PolynomialRegression.fit(data: data, degree: 2) else {
		print("  ✗ Fitting failed!")
		return
	}
	print("  ✓ Fitting completed")
	print()

	// Check recovery
	print("Parameter Recovery:")
	print()
	print("  Parameter      | True   | Recovered | Abs Error | Rel Error | Status")
	print("  " + String(repeating: "-", count: 68))

	let params = [
		("β₀ (intercept)", trueBeta0, beta[0]),
		("β₁ (linear)", trueBeta1, beta[1]),
		("β₂ (quadratic)", trueBeta2, beta[2]),
		("σ  (noise)", trueSigma, sigma)
	]

	var allPassed = true
	for (name, trueVal, recoveredVal) in params {
		let absError = abs(recoveredVal - trueVal)
		let relError = abs(trueVal) > 1e-6 ? absError / abs(trueVal) : absError
		let status = relError <= 0.15 ? "✓ PASS" : "✗ FAIL"

		if relError > 0.15 {
			allPassed = false
		}
		print("  \(name.padding(toLength: 14, withPad: " ", startingAt: 0)) | \(trueVal.number().paddingLeft(toLength: 6)) | \(recoveredVal.number().paddingLeft(toLength: 9)) | \(absError.number().paddingLeft(toLength: 9)) | \(relError.percent().paddingLeft(toLength: 9)) | \(status)")
	}
	print()

	if allPassed {
		print("✓ All parameters recovered within 15% tolerance")
		print("  → Quadratic model fitting is working correctly")
	} else {
		print("✗ Some parameters failed to recover")
		print("  → May need more data or better conditioning")
	}
}

// MARK: - Example 2: Model Selection - Right vs Wrong Degree

func example2_ModelSelection() {
	print("\n")
	print(String(repeating: "*", count: 60))
	print("Example 2: Model Selection Using Validation")
	print(String(repeating: "*", count: 60))
	print()

	print("True model is quadratic: y = 5 + 2x - x² + ε")
	print("Let's test fitting with different polynomial degrees...")
	print()

	let trueBeta = [5.0, 2.0, -1.0]
	let trueSigma = 0.3

	// Simulate data
	var data: [(x: Double, y: Double)] = []
	for _ in 0..<100 {
		let x = Double.random(in: -2...2)
		let mu = trueBeta[0] + trueBeta[1] * x + trueBeta[2] * x * x
		let y = distributionNormal(mean: mu, stdDev: trueSigma)
		data.append((x, y))
	}

	print("  Degree | Residual σ | AIC      | BIC      | Notes")
	print("  " + String(repeating: "-", count: 76))

	for degree in 1...5 {
		guard let (beta, sigma) = PolynomialRegression.fit(data: data, degree: degree) else {
			print("  \("Failed".paddingLeft(toLength: 6)) | \("degree".paddingLeft(toLength: 10)) | \("N/A".paddingLeft(toLength: 8)) | \("N/A".paddingLeft(toLength: 8)) | \("N/A")")
			continue
		}

		let n = Double(data.count)
		let k = Double(degree + 1)  // Number of parameters

		// AIC = 2k + n*ln(σ²)
		let aic = 2.0 * k + n * log(sigma * sigma)

		// BIC = k*ln(n) + n*ln(σ²)
		let bic = k * log(n) + n * log(sigma * sigma)

		var note = ""
		if degree == 1 {
			note = "Underfit (too simple)"
		} else if degree == 2 {
			note = "✓ Correct degree"
		} else if degree > 2 {
			note = "Overfit (unnecessary complexity)"
		}
		print("  \(Double(degree).number(0).paddingLeft(toLength: 6)) | \(sigma.number().paddingLeft(toLength: 10)) | \(aic.number().paddingLeft(toLength: 8)) | \(bic.number().paddingLeft(toLength: 8)) | \(note)")
	}

	print()
	print("Key Insight:")
	print("  - Degree 1 (linear): High σ indicates underfit")
	print("  - Degree 2 (quadratic): Lowest AIC/BIC - correct model!")
	print("  - Degree 3+: σ doesn't improve much, AIC/BIC penalize complexity")
	print()
	print("Fake-data simulation lets you verify model selection works!")
}

// MARK: - Example 3: Overfitting with Small Sample Size

func example3_OverfittingDetection() {
	print("\n")
	print(String(repeating: "*", count: 60))
	print("Example 3: Detecting Overfitting with Fake Data")
	print(String(repeating: "*", count: 60))
	print()

	print("Demonstrating how fake-data simulation reveals overfitting...")
	print()

	// True model: Simple linear (degree 1)
	let trueIntercept = 10.0
	let trueSlope = 2.0
	let trueSigma = 1.0

	print("True Model: y = \(trueIntercept) + \(trueSlope)x + ε")
	print()

	// Small dataset (danger zone for overfitting!)
	let smallN = 15

	print("Test 1: Fitting with appropriate model (degree 1)...")
	var smallData: [(x: Double, y: Double)] = []
	for _ in 0..<smallN {
		let x = Double.random(in: 0...10)
		let mu = trueIntercept + trueSlope * x
		let y = distributionNormal(mean: mu, stdDev: trueSigma)
		smallData.append((x, y))
	}

	if let (beta1, sigma1) = PolynomialRegression.fit(data: smallData, degree: 1) {
		let slopeError = abs(beta1[1] - trueSlope) / trueSlope
		print("  Recovered slope: \(beta1[1].number()) (\(slopeError.percent()) error)")
		print(String(format: "  Residual σ: \(sigma1.number())", sigma1))
	}
	print()

	print("Test 2: Fitting with overly complex model (degree 5)...")
	if let (beta5, sigma5) = PolynomialRegression.fit(data: smallData, degree: 5) {
		print("  Residual σ: \(sigma5.number()) (artificially low!)")
		print("  Coefficients:")
		for (i, coef) in beta5.enumerated() {
			if i <= 1 {
				print("    β\(i): \(coef.number().paddingLeft(toLength: 8)) (structural parameter)")
			} else {
				print("    β\(i): \(coef.number().paddingLeft(toLength: 8)) (fitting noise, should be ~0)")
			}
		}
	}
	print()

	print("Test 3: Out-of-sample validation...")
	// Generate new test data from same true model
	var testData: [(x: Double, y: Double)] = []
	for _ in 0..<50 {
		let x = Double.random(in: 0...10)
		let mu = trueIntercept + trueSlope * x
		let y = distributionNormal(mean: mu, stdDev: trueSigma)
		testData.append((x, y))
	}

	// Test both models on new data
	if let (beta1, _) = PolynomialRegression.fit(data: smallData, degree: 1),
	   let (beta5, _) = PolynomialRegression.fit(data: smallData, degree: 5) {

		var mse1 = 0.0
		var mse5 = 0.0

		for point in testData {
			let pred1 = PolynomialRegression.predict(x: point.x, coefficients: beta1)
			let pred5 = PolynomialRegression.predict(x: point.x, coefficients: beta5)

			mse1 += pow(point.y - pred1, 2)
			mse5 += pow(point.y - pred5, 2)
		}

		mse1 /= Double(testData.count)
		mse5 /= Double(testData.count)

		print("  Degree 1 test MSE: \(mse1.number())")
		print("  Degree 5 test MSE: \(mse5.number())")

		if mse5 > mse1 {
			print()
			print("✓ Degree 5 model performs WORSE on new data!")
			print("  → This is overfitting - model memorizes noise")
		}
	}
	print()

	print("Conclusion: Fake-data simulation reveals overfitting before")
	print("you waste time on complex models that don't generalize!")
}

// MARK: - Example 4: Business Application - Pricing Curves

func example4_PricingCurveValidation() {
	print("\n")
	print(String(repeating: "*", count: 60))
	print("Example 4: Revenue vs Price Curve Validation")
	print(String(repeating: "*", count: 60))
	print()

	print("Business Context:")
	print("  Modeling revenue as function of price.")
	print("  Theory suggests inverted-U shape (quadratic):")
	print("  - Too low price: Low revenue despite high volume")
	print("  - Too high price: Low revenue despite high margin")
	print("  - Optimal price: Maximizes revenue")
	print()

	// True model: revenue = 1000 + 500*price - 50*price²
	// Maximum at price = 500/(2*50) = 5.0 with revenue = 2250
	let trueModel = [1000.0, 500.0, -50.0]
	let noiseSigma = 100.0

	print("True Model: revenue = 1000 + 500*price - 50*price²")
	print("  Optimal price: $5.00")
	print("  Maximum revenue: $2,250")
	print()

	// Simulate price experiment data
	var data: [(x: Double, y: Double)] = []
	for _ in 0..<50 {
		let price = Double.random(in: 2.0...8.0)
		let trueRevenue = trueModel[0] + trueModel[1] * price + trueModel[2] * price * price
		let observed = distributionNormal(mean: trueRevenue, stdDev: noiseSigma)
		data.append((x: price, y: observed))
	}

	print("Simulated 50 price experiments (price range: $2-$8)...")
	print()

	// Fit quadratic model
	print("Fitting quadratic revenue model...")
	guard let (beta, sigma) = PolynomialRegression.fit(data: data, degree: 2) else {
		print("  ✗ Fitting failed!")
		return
	}
	print("  ✓ Fitting completed")
	print()

	// Find optimal price from fitted model
	// For y = β₀ + β₁*x + β₂*x², maximum at x = -β₁/(2*β₂)
	let optimalPrice = -beta[1] / (2.0 * beta[2])
	let maxRevenue = PolynomialRegression.predict(x: optimalPrice, coefficients: beta)

	print("Fitted Model:")
	print("  revenue = \(beta[0].number(1)) + \(beta[1].number(1)) * price + \(beta[2].number(1)) * price²")
	print()

	print("Optimal Pricing:")
	print("  Fitted optimal price: \(optimalPrice.currency()) (true: $5.00)")
	print("  Fitted max revenue:   \(maxRevenue.currency()) (true: $2,250)")
	print()

	// Validation
	let priceError = abs(optimalPrice - 5.0) / 5.0
	let revenueError = abs(maxRevenue - 2250.0) / 2250.0

	if priceError <= 0.10 && revenueError <= 0.10 {
		print("✓ VALIDATION PASSED: Optimal price recovered within 10%")
		print("  → Safe to use this model for pricing decisions")
	} else {
		print("✗ VALIDATION FAILED")
		print("  Price error: \(priceError.percent()), Revenue error: \(revenueError.percent())")
		print("  → Need more data or different model")
	}
}

// MARK: - Example 5: Comparing All Models

func example5_ComparingModelTypes() {
	print("\n")
	print(String(repeating: "*", count: 60))
	print("Example 5: Recovery Across Different Model Types")
	print(String(repeating: "*", count: 60))
	print()

	print("Comparing parameter recovery for different regression models:")
	print()

	struct ModelTest {
		let name: String
		let run: () -> Double  // Returns average relative error
	}

	let tests: [ModelTest] = [
		ModelTest(name: "Linear") {
			// y = 2 + 3x + ε
			var data: [(x: Double, y: Double)] = []
			for _ in 0..<100 {
				let x = Double.random(in: 0...10)
				let y = 2.0 + 3.0 * x + distributionNormal(mean: 0, stdDev: 0.5)
				data.append((x, y))
			}

			guard let (beta, _) = PolynomialRegression.fit(data: data, degree: 1) else {
				return 1.0  // Failed
			}

			let error0 = abs(beta[0] - 2.0) / 2.0
			let error1 = abs(beta[1] - 3.0) / 3.0
			return (error0 + error1) / 2.0
		},

		ModelTest(name: "Quadratic") {
			// y = 5 + 2x - x² + ε
			var data: [(x: Double, y: Double)] = []
			for _ in 0..<100 {
				let x = Double.random(in: -2...2)
				let y = 5.0 + 2.0 * x - x * x + distributionNormal(mean: 0, stdDev: 0.3)
				data.append((x, y))
			}

			guard let (beta, _) = PolynomialRegression.fit(data: data, degree: 2) else {
				return 1.0
			}

			let error0 = abs(beta[0] - 5.0) / 5.0
			let error1 = abs(beta[1] - 2.0) / 2.0
			let error2 = abs(beta[2] - (-1.0)) / 1.0
			return (error0 + error1 + error2) / 3.0
		},

		ModelTest(name: "Cubic") {
			// y = 1 + x - 0.5x² + 0.1x³ + ε
			var data: [(x: Double, y: Double)] = []
			for _ in 0..<150 {
				let x = Double.random(in: -3...3)
				let y = 1.0 + x - 0.5*x*x + 0.1*x*x*x + distributionNormal(mean: 0, stdDev: 0.5)
				data.append((x, y))
			}

			guard let (beta, _) = PolynomialRegression.fit(data: data, degree: 3) else {
				return 1.0
			}

			let error0 = abs(beta[0] - 1.0) / max(1.0, abs(beta[0]))
			let error1 = abs(beta[1] - 1.0) / 1.0
			let error2 = abs(beta[2] - (-0.5)) / 0.5
			let error3 = abs(beta[3] - 0.1) / 0.1
			return (error0 + error1 + error2 + error3) / 4.0
		}
	]

	print("  Model Type | Avg Rel Error | Status")
	print("  " + String(repeating: "-", count: 42))

	for test in tests {
		let avgError = test.run()
		let status = avgError <= 0.15 ? "✓ PASS" : "✗ FAIL"
		print("  \(test.name.paddingLeft(toLength: 10)) | \(avgError.percent().paddingLeft(toLength: 13)) | \(status)")
	}

	print()
	print("General Pattern:")
	print("  - Linear models: Excellent recovery (closed-form solution)")
	print("  - Quadratic: Good recovery with adequate data")
	print("  - Higher degree: More challenging, needs more data")
	print()
	print("Fake-data validation helps calibrate expectations!")
}

// MARK: - Main

func runAllPolynomialRegressionExamples() {
	print("\n")
	print("╔" + String(repeating: "═", count: 58) + "╗")
	print("║  Polynomial Regression Fake-Data Validation              ║")
	print("║  Model Selection and Overfitting Detection               ║")
	print("╚" + String(repeating: "═", count: 58) + "╝")
	print()

	example1_QuadraticRecovery()
	example2_ModelSelection()
	example3_OverfittingDetection()
	example4_PricingCurveValidation()
	example5_ComparingModelTypes()

	print("\n")
	print("╔" + String(repeating: "═", count: 58) + "╗")
	print("║  Key Takeaways                                           ║")
	print("╚" + String(repeating: "═", count: 58) + "╝")
	print()
	print("1. Polynomial regression has closed-form solution (very reliable)")
	print("2. Model selection tools (AIC/BIC) work - validate with fake data!")
	print("3. Overfitting is real - higher degree ≠ better fit")
	print("4. Small sample sizes are dangerous for complex models")
	print("5. Fake-data simulation reveals these issues before real analysis")
	print()
}

// Uncomment to run:
 runAllPolynomialRegressionExamples()

// Or run individual examples:
// example1_QuadraticRecovery()
// example2_ModelSelection()
// example3_OverfittingDetection()
// example4_PricingCurveValidation()
// example5_ComparingModelTypes()


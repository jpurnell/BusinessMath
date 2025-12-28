//
//  OptimizationExample.swift
//  BusinessMath Examples
//
//  Demonstrates multivariate optimization using gradient descent and Newton-Raphson methods
//

import Foundation
@testable import BusinessMath

/// Example: Gradient Descent variants comparison
func gradientDescentComparisonExample() throws {
	print("=== Gradient Descent Comparison ===\n")

	// Rosenbrock function (challenging non-convex landscape)
	let rosenbrock: (VectorN<Double>) -> Double = { v in
		let x = v[0], y = v[1]
		let a = 1 - x
		let b = y - x*x
		return a*a + 100*b*b
	}

	let initial = VectorN([0.0, 0.0])
	print("Minimizing Rosenbrock function from \(initial.toArray())")
	print("True minimum: [1, 1]\n")

	// Basic Gradient Descent
	print("1. Basic Gradient Descent:")
	let basicGD = MultivariateGradientDescent<VectorN<Double>>(
		learningRate: 0.001,
		maxIterations: 10000
	)
	let basicResult = try basicGD.minimize(function: rosenbrock, initialGuess: initial)
	print("   Solution: \(basicResult.solution.toArray().map { $0.number() })")
	print("   Iterations: \(basicResult.iterations)")
	print("   Converged: \(basicResult.converged)")
	print()

	// Momentum Gradient Descent
	print("2. Momentum Gradient Descent:")
	let momentumGD = MultivariateGradientDescent<VectorN<Double>>(
		learningRate: 0.001,
		maxIterations: 10000,
		momentum: 0.9
	)
	let momentumResult = try momentumGD.minimize(function: rosenbrock, initialGuess: initial)
	print("   Solution: \(momentumResult.solution.toArray().map { $0.number() })")
	print("   Iterations: \(momentumResult.iterations)")
	print("   Converged: \(momentumResult.converged)")
	print()

	// Adam Optimizer
	print("3. Adam Optimizer:")
	let adam = MultivariateGradientDescent<VectorN<Double>>(
		learningRate: 0.01,
		maxIterations: 10000
	)
	let adamResult = try adam.minimizeAdam(function: rosenbrock, initialGuess: initial)
	print("   Solution: \(adamResult.solution.toArray().map { $0.number() })")
	print("   Iterations: \(adamResult.iterations)")
	print("   Converged: \(adamResult.converged)")
	print()

	print("Comparison:")
	print("  • Basic GD: Slow but steady convergence")
	print("  • Momentum: Faster, less oscillation")
	print("  • Adam: Fastest, adaptive learning rates")

	print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Newton-Raphson methods
func newtonRaphsonExample() throws {
	print("=== Newton-Raphson Optimization ===\n")

	// Quadratic function (ideal for Newton methods)
	let quadratic: (VectorN<Double>) -> Double = { v in
		let x = v[0], y = v[1], z = v[2]
		return x*x + 2*y*y + 3*z*z + x*y - y*z
	}

	let initial = VectorN([5.0, 5.0, 5.0])
	print("Minimizing quadratic function from \(initial.toArray().map { $0.number() })")
	print()

	// Full Newton Method
	print("1. Full Newton Method (exact Hessian):")
	let newton = MultivariateNewtonRaphson<VectorN<Double>>(
		maxIterations: 50
	)
	let newtonResult = try newton.minimize(
		function: quadratic,
		gradient: { try numericalGradient(quadratic, at: $0) },
		hessian: { try numericalHessian(quadratic, at: $0) },
		initialGuess: initial
	)
	print("   Solution: \(newtonResult.solution.toArray().map { $0.number() })")
	print("   Value: \(newtonResult.value.number())")
	print("   Iterations: \(newtonResult.iterations)")
	print("   Converged: \(newtonResult.converged)")
	print()

	// BFGS Method
	print("2. BFGS Method (quasi-Newton):")
	let bfgs = MultivariateNewtonRaphson<VectorN<Double>>(
		maxIterations: 50
	)
	let bfgsResult = try bfgs.minimizeBFGS(
		function: quadratic,
		initialGuess: initial
	)
	print("   Solution: \(bfgsResult.solution.toArray().map { $0.number() })")
	print("   Value: \(bfgsResult.value.number())")
	print("   Iterations: \(bfgsResult.iterations)")
	print("   Converged: \(bfgsResult.converged)")
	print()

	print("Note: Newton methods converge in very few iterations for smooth functions!")
	print("  • Full Newton: Quadratic convergence (fastest)")
	print("  • BFGS: Superlinear convergence (no Hessian computation needed)")

	print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Parameter fitting with optimization
func parameterFittingExample() throws {
	print("=== Parameter Fitting Example ===\n")

	// Generate synthetic data: y = 2x² + 3x + 1 + noise
	let trueParams = (a: 2.0, b: 3.0, c: 1.0)
	let dataPoints: [(x: Double, y: Double)] = (-5...5).map { i in
		let x = Double(i)
		let y = trueParams.a * x * x + trueParams.b * x + trueParams.c
		return (x, y + Double.random(in: -0.5...0.5))  // Add small noise
	}

	print("Fitting quadratic model y = ax² + bx + c to data")
	print("True parameters: a=\(trueParams.a), b=\(trueParams.b), c=\(trueParams.c)")
	print("Data points: \(dataPoints.count)")
	print()

	// Least squares cost function
	let leastSquares: (VectorN<Double>) -> Double = { params in
		let a = params[0], b = params[1], c = params[2]

		let sumSquaredErrors = dataPoints.map { point in
			let predicted = a * point.x * point.x + b * point.x + c
			let error = point.y - predicted
			return error * error
		}

		return sumSquaredErrors.reduce(0, +)
	}

	// Optimize with BFGS
	let optimizer = MultivariateNewtonRaphson<VectorN<Double>>()
	let result = try optimizer.minimizeBFGS(
		function: leastSquares,
		initialGuess: VectorN([0.0, 0.0, 0.0])  // Start from zero
	)

	let fitted = result.solution
	print("Fitted parameters:")
	print(String(format: "  a = %.4f (true: %.1f)", fitted[0], trueParams.a))
	print(String(format: "  b = %.4f (true: %.1f)", fitted[1], trueParams.b))
	print(String(format: "  c = %.4f (true: %.1f)", fitted[2], trueParams.c))
	print()
	print("Sum of squared errors: \(result.value.number())")
	print("Converged in \(result.iterations) iterations")

	print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Multi-dimensional function minimization
func multiDimensionalExample() throws {
	print("=== Multi-Dimensional Optimization ===\n")

	// Sphere function in 10 dimensions: f(x) = Σxᵢ²
	let dimension = 10
	let sphere: (VectorN<Double>) -> Double = { v in
		v.toArray().map { $0 * $0 }.reduce(0, +)
	}

	// Start far from minimum
	let initial = VectorN(Array(repeating: 5.0, count: dimension))

	print("Minimizing \(dimension)-dimensional sphere function")
	print("Function: f(x₁,...,x₁₀) = Σxᵢ²")
	print("True minimum: all zeros")
	print()

	// Use Adam (good for high dimensions)
	let optimizer = MultivariateGradientDescent<VectorN<Double>>(
		learningRate: 0.1,
		maxIterations: 1000
	)

	let result = try optimizer.minimizeAdam(function: sphere, initialGuess: initial)

	print("Results:")
	print("  Final value: \(result.value.number())")
	print("  Iterations: \(result.iterations)")
	print("  Converged: \(result.converged)")
	print()
	print("Solution (should be near zero):")
	for (i, value) in result.solution.toArray().enumerated() {
		print("  x\(i+1) = \(value.number())")
	}

	print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Constrained optimization preview
func constrainedPreview() throws {
	print("=== Constrained Optimization Preview ===\n")

	print("The optimization methods in Phase 3 are unconstrained.")
	print("For constrained problems (e.g., x ≥ 0, Σx = 1), see Phase 4.")
	print()
	print("Example constrained problems:")
	print("  • Portfolio optimization: weights sum to 1, no negative weights")
	print("  • Resource allocation: budget constraints, capacity limits")
	print("  • Production planning: demand constraints, resource bounds")
	print()
	print("Phase 4 adds:")
	print("  • Equality constraints (h(x) = 0)")
	print("  • Inequality constraints (g(x) ≤ 0)")
	print("  • Lagrange multipliers (shadow prices)")
	print("  • Penalty and barrier methods")

	print("\n" + String(repeating: "=", count: 50) + "\n")
}

// Run examples
print("\n")
print("BusinessMath - Multivariate Optimization Examples")
print(String(repeating: "=", count: 50))
print("\n")

try gradientDescentComparisonExample()
try newtonRaphsonExample()
try parameterFittingExample()
try multiDimensionalExample()
try constrainedPreview()

print("Examples complete!")
print()
print("Next: See PortfolioOptimizationExample.swift for financial applications")
print("      See Phase 4 for constrained optimization")

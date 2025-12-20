//
//  MultivariateNewtonRaphson.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation
import Numerics

// MARK: - Multivariate Newton-Raphson

/// Newton-Raphson optimizer for N-dimensional functions using second-order information.
///
/// Newton-Raphson uses both gradient (∇f) and Hessian (∇²f) to find the minimum,
/// achieving quadratic convergence near the optimum. The update rule is:
/// ```
/// x_{k+1} = x_k - α H^{-1}∇f(x_k)
/// ```
/// where H is the Hessian matrix and α is determined by line search.
///
/// ## Example
/// ```swift
/// // Minimize quadratic: f(x,y) = x² + y²
/// let quadratic: (VectorN<Double>) -> Double = { v in
///     v[0]*v[0] + v[1]*v[1]
/// }
///
/// let optimizer = MultivariateNewtonRaphson<VectorN<Double>>(
///     maxIterations: 100,
///     tolerance: 1e-6,
///     useLineSearch: true
/// )
///
/// let result = try optimizer.minimize(
///     function: quadratic,
///     gradient: { try numericalGradient(quadratic, at: $0) },
///     hessian: { try numericalHessian(quadratic, at: $0) },
///     initialGuess: VectorN([10.0, 10.0])
/// )
///
/// print("Solution: \(result.solution)")  // Near [0.0, 0.0]
/// print("Iterations: \(result.iterations)")  // Very few!
/// ```
public struct MultivariateNewtonRaphson<V: VectorSpace> where V.Scalar: Real {
	/// Maximum number of iterations
	public let maxIterations: Int

	/// Convergence tolerance for gradient norm
	public let tolerance: V.Scalar

	/// Whether to use line search for adaptive step size
	public let useLineSearch: Bool

	/// Whether to record optimization history
	public let recordHistory: Bool

	public init(
		maxIterations: Int = 100,
		tolerance: V.Scalar? = nil,
		useLineSearch: Bool = true,
		recordHistory: Bool = false
	) {
		self.maxIterations = maxIterations
		self.tolerance = tolerance ?? (V.Scalar(1) / V.Scalar(1_000_000))
		self.useLineSearch = useLineSearch
		self.recordHistory = recordHistory
	}

	// MARK: - Full Newton-Raphson with Hessian

	/// Minimizes a function using Newton-Raphson with full Hessian.
	///
	/// Requires computing the Hessian matrix at each iteration. Converges quadratically
	/// near the optimum but is computationally expensive for high-dimensional problems.
	///
	/// - Parameters:
	///   - function: The objective function f: V → ℝ to minimize
	///   - gradient: Function that computes ∇f at a point
	///   - hessian: Function that computes ∇²f (Hessian matrix) at a point
	///   - initialGuess: Starting point for optimization
	/// - Returns: Optimization result containing solution and convergence info
	/// - Throws: `OptimizationError` if optimization fails
	public func minimize(
		function: (V) -> V.Scalar,
		gradient: (V) throws -> V,
		hessian: (V) throws -> [[V.Scalar]],
		initialGuess: V
	) throws -> MultivariateOptimizationResult<V> {
		var x = initialGuess
		var history: [(Int, V, V.Scalar, V.Scalar)]? = recordHistory ? [] : nil

		for iteration in 0..<maxIterations {
			// Compute gradient and Hessian
			let grad = try gradient(x)
			let H = try hessian(x)
			let gradNorm = grad.norm

			// Check for convergence
			guard gradNorm.isFinite else {
				throw OptimizationError.nonFiniteValue(message: "Gradient norm is not finite")
			}

			// Record history
			if recordHistory {
				let fValue = function(x)
				history?.append((iteration, x, fValue, gradNorm))
			}

			// Check convergence
			if gradNorm < tolerance {
				let finalValue = function(x)
				return MultivariateOptimizationResult(
					solution: x,
					value: finalValue,
					iterations: iteration,
					converged: true,
					gradientNorm: gradNorm,
					history: history
				)
			}

			// Solve H * step = -gradient for Newton direction
			// step = -H^{-1} * gradient
			let negGrad = grad.toArray().map { -$0 }
			let stepArray = try solveLinearSystem(matrix: H, vector: negGrad)

			guard let step = V.fromArray(stepArray) else {
				throw OptimizationError.invalidInput(message: "Failed to construct step vector")
			}

			// Determine step size
			var alpha = V.Scalar(1)
			if useLineSearch {
				alpha = try backtrackingLineSearch(
					function: function,
					point: x,
					gradient: grad,
					direction: step,
					initialStepSize: V.Scalar(1)
				)
			}

			// Update position
			x = x + alpha * step
		}

		// Max iterations reached
		let finalGrad = try gradient(x)
		let finalValue = function(x)

		return MultivariateOptimizationResult(
			solution: x,
			value: finalValue,
			iterations: maxIterations,
			converged: false,
			gradientNorm: finalGrad.norm,
			history: history
		)
	}

	// MARK: - BFGS Quasi-Newton

	/// Minimizes a function using BFGS quasi-Newton method.
	///
	/// BFGS approximates the inverse Hessian without explicitly computing it,
	/// making it much more efficient for high-dimensional problems. It maintains
	/// a positive-definite approximation that converges to the true inverse Hessian.
	///
	/// - Parameters:
	///   - function: The objective function f: V → ℝ to minimize
	///   - gradient: Function that computes ∇f at a point
	///   - initialGuess: Starting point for optimization
	/// - Returns: Optimization result
	/// - Throws: `OptimizationError` if optimization fails
	public func minimizeBFGS(
		function: (V) -> V.Scalar,
		gradient: (V) throws -> V,
		initialGuess: V
	) throws -> MultivariateOptimizationResult<V> {
		var x = initialGuess
		let dimension = x.toArray().count

		// Initialize inverse Hessian approximation as identity matrix
		var B_inv = identityMatrix(size: dimension)

		var grad = try gradient(x)
		var history: [(Int, V, V.Scalar, V.Scalar)]? = recordHistory ? [] : nil

		for iteration in 0..<maxIterations {
			let gradNorm = grad.norm

			// Check for convergence
			guard gradNorm.isFinite else {
				throw OptimizationError.nonFiniteValue(message: "Gradient norm is not finite")
			}

			// Record history
			if recordHistory {
				let fValue = function(x)
				history?.append((iteration, x, fValue, gradNorm))
			}

			// Check convergence
			if gradNorm < tolerance {
				let finalValue = function(x)
				return MultivariateOptimizationResult(
					solution: x,
					value: finalValue,
					iterations: iteration,
					converged: true,
					gradientNorm: gradNorm,
					history: history
				)
			}

			// Compute search direction: p_k = -B_k^{-1} * g_k
			let gradArray = grad.toArray()
			let negGrad = gradArray.map { -$0 }
			let directionArray = matrixVectorMultiply(B_inv, negGrad)

			guard let direction = V.fromArray(directionArray) else {
				throw OptimizationError.invalidInput(message: "Failed to construct direction vector")
			}

			// Line search for step size
			let alpha = try backtrackingLineSearch(
				function: function,
				point: x,
				gradient: grad,
				direction: direction,
				initialStepSize: V.Scalar(1)
			)

			// Update position
			let xNew = x + alpha * direction
			let gradNew = try gradient(xNew)

			// BFGS update of inverse Hessian approximation
			// s_k = x_{k+1} - x_k
			let s = (xNew - x).toArray()
			// y_k = g_{k+1} - g_k
			let gradNewArray = gradNew.toArray()
			let y = zip(gradNewArray, gradArray).map { $0 - $1 }

			// Check curvature condition: s^T y > 0
			let sTy = dotProduct(s, y)
			if sTy > V.Scalar(1) / V.Scalar(1_000_000_000) {
				// BFGS update formula
				B_inv = bfgsUpdate(B_inv: B_inv, s: s, y: y, sTy: sTy)
			}

			// Move to next iteration
			x = xNew
			grad = gradNew
		}

		// Max iterations reached
		let finalValue = function(x)

		return MultivariateOptimizationResult(
			solution: x,
			value: finalValue,
			iterations: maxIterations,
			converged: false,
			gradientNorm: grad.norm,
			history: history
		)
	}

	// MARK: - Line Search

	/// Backtracking line search to find a good step size.
	///
	/// - Parameters:
	///   - function: The objective function
	///   - point: Current point
	///   - gradient: Gradient at current point
	///   - direction: Search direction
	///   - initialStepSize: Initial step size to try
	/// - Returns: Optimal step size α
	private func backtrackingLineSearch(
		function: (V) -> V.Scalar,
		point: V,
		gradient: V,
		direction: V,
		initialStepSize: V.Scalar,
		c1: V.Scalar = V.Scalar(1) / V.Scalar(10_000),
		rho: V.Scalar = V.Scalar(1) / V.Scalar(2)
	) throws -> V.Scalar {
		let f0 = function(point)
		let gradDotDir = gradient.dot(direction)

		// If direction is not a descent direction, return small step
		if gradDotDir >= V.Scalar(0) {
			return V.Scalar(1) / V.Scalar(100)
		}

		var alpha = initialStepSize
		let maxBacktracks = 50

		for _ in 0..<maxBacktracks {
			let newPoint = point + alpha * direction
			let fNew = function(newPoint)

			// Armijo condition: f(x + αd) ≤ f(x) + c₁α∇f(x)ᵀd
			if fNew <= f0 + c1 * alpha * gradDotDir {
				return alpha
			}

			// Reduce step size
			alpha = alpha * rho
		}

		// If line search fails, return small step
		return alpha
	}

	// MARK: - BFGS Helper Functions

	/// Creates an identity matrix of given size
	private func identityMatrix(size: Int) -> [[V.Scalar]] {
		var matrix = Array(repeating: Array(repeating: V.Scalar(0), count: size), count: size)
		for i in 0..<size {
			matrix[i][i] = V.Scalar(1)
		}
		return matrix
	}

	/// Multiplies a matrix by a vector
	private func matrixVectorMultiply(_ matrix: [[V.Scalar]], _ vector: [V.Scalar]) -> [V.Scalar] {
		let n = matrix.count
		var result = Array(repeating: V.Scalar(0), count: n)
		for i in 0..<n {
			for j in 0..<n {
				result[i] = result[i] + matrix[i][j] * vector[j]
			}
		}
		return result
	}

	/// Computes dot product of two vectors
	private func dotProduct(_ a: [V.Scalar], _ b: [V.Scalar]) -> V.Scalar {
		var sum = V.Scalar(0)
		for i in 0..<a.count {
			sum = sum + a[i] * b[i]
		}
		return sum
	}

	/// BFGS update formula for inverse Hessian approximation
	///
	/// B_{k+1}^{-1} = (I - ρ s y^T) B_k^{-1} (I - ρ y s^T) + ρ s s^T
	/// where ρ = 1 / (y^T s)
	private func bfgsUpdate(B_inv: [[V.Scalar]], s: [V.Scalar], y: [V.Scalar], sTy: V.Scalar) -> [[V.Scalar]] {
		let n = B_inv.count
		let rho = V.Scalar(1) / sTy

		// Compute s * y^T (outer product)
		var syT = Array(repeating: Array(repeating: V.Scalar(0), count: n), count: n)
		for i in 0..<n {
			for j in 0..<n {
				syT[i][j] = s[i] * y[j]
			}
		}

		// Compute y * s^T (outer product)
		var ysT = Array(repeating: Array(repeating: V.Scalar(0), count: n), count: n)
		for i in 0..<n {
			for j in 0..<n {
				ysT[i][j] = y[i] * s[j]
			}
		}

		// Compute s * s^T (outer product)
		var ssT = Array(repeating: Array(repeating: V.Scalar(0), count: n), count: n)
		for i in 0..<n {
			for j in 0..<n {
				ssT[i][j] = s[i] * s[j]
			}
		}

		// I - ρ s y^T
		var leftTerm = identityMatrix(size: n)
		for i in 0..<n {
			for j in 0..<n {
				leftTerm[i][j] = leftTerm[i][j] - rho * syT[i][j]
			}
		}

		// I - ρ y s^T
		var rightTerm = identityMatrix(size: n)
		for i in 0..<n {
			for j in 0..<n {
				rightTerm[i][j] = rightTerm[i][j] - rho * ysT[i][j]
			}
		}

		// leftTerm * B_inv
		let temp = matrixMultiply(leftTerm, B_inv)

		// temp * rightTerm
		var result = matrixMultiply(temp, rightTerm)

		// Add ρ s s^T
		for i in 0..<n {
			for j in 0..<n {
				result[i][j] = result[i][j] + rho * ssT[i][j]
			}
		}

		return result
	}

	/// Multiplies two matrices
	private func matrixMultiply(_ A: [[V.Scalar]], _ B: [[V.Scalar]]) -> [[V.Scalar]] {
		let n = A.count
		var result = Array(repeating: Array(repeating: V.Scalar(0), count: n), count: n)
		for i in 0..<n {
			for j in 0..<n {
				for k in 0..<n {
					result[i][j] = result[i][j] + A[i][k] * B[k][j]
				}
			}
		}
		return result
	}

	/// BFGS minimization with automatic numerical gradient computation.
	///
	/// This is a convenience overload that automatically computes the gradient using
	/// finite differences (central differences). If you have an analytical gradient,
	/// use the explicit gradient overload for better performance and accuracy.
	///
	/// Uses central difference formula: ∇f(x) ≈ [f(x+εeᵢ) - f(x-εeᵢ)] / (2ε)
	///
	/// ## Example
	/// ```swift
	/// // Minimize f(x, y) = x² + y² - 2x - 2y
	/// let objective: (VectorN<Double>) -> Double = { v in
	///     let x = v[0], y = v[1]
	///     return x*x + y*y - 2*x - 2*y
	/// }
	///
	/// let optimizer = MultivariateNewtonRaphson<VectorN<Double>>()
	/// let result = try optimizer.minimizeBFGS(
	///     function: objective,
	///     initialGuess: VectorN([0.0, 0.0])
	/// )
	///
	/// // Solution: (1, 1) with value -2
	/// ```
	///
	/// - Parameters:
	///   - function: The objective function f: V → ℝ to minimize
	///   - initialGuess: Starting point for optimization
	///   - epsilon: Step size for numerical differentiation (default: 1e-6)
	/// - Returns: Optimization result
	/// - Throws: `OptimizationError` if optimization fails
	///
	/// - Note: Automatic gradient computation costs approximately 2n function
	///         evaluations per iteration, where n is the dimension.
	///         For high-dimensional problems, consider providing analytical gradients.
	public func minimizeBFGS(
		function: @escaping (V) -> V.Scalar,
		initialGuess: V,
		epsilon: V.Scalar = V.Scalar(1) / V.Scalar(1_000_000)
	) throws -> MultivariateOptimizationResult<V> {
		// Create gradient function using numerical differentiation
		let gradientFunction: (V) throws -> V = { point in
			try numericalGradient(function, at: point, epsilon: epsilon)
		}

		// Call the main minimizeBFGS with computed gradient
		return try minimizeBFGS(
			function: function,
			gradient: gradientFunction,
			initialGuess: initialGuess
		)
	}
}

// MARK: - Convenience Extensions

extension MultivariateNewtonRaphson {
	/// Creates a Newton-Raphson optimizer with default settings
	public static func standard() -> MultivariateNewtonRaphson<V> {
		MultivariateNewtonRaphson()
	}

	/// Creates a Newton-Raphson optimizer without line search (trust region)
	public static func withoutLineSearch() -> MultivariateNewtonRaphson<V> {
		MultivariateNewtonRaphson(useLineSearch: false)
	}

	/// Creates a BFGS optimizer optimized for large-scale problems
	public static func bfgsLargeScale(maxIterations: Int = 1000) -> MultivariateNewtonRaphson<V> {
		MultivariateNewtonRaphson(
			maxIterations: maxIterations,
			useLineSearch: true
		)
	}
}

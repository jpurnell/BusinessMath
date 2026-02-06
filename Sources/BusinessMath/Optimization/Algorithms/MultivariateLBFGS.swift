//
//  MultivariateLBFGS.swift
//  BusinessMath
//
//  Created by Claude Code on 02/04/26.
//

import Foundation
import Numerics

// MARK: - Multivariate L-BFGS

/// L-BFGS (Limited-memory BFGS) optimizer for N-dimensional functions using limited memory.
///
/// L-BFGS is a memory-efficient quasi-Newton method that approximates the inverse Hessian
/// using only the last m gradient/position pairs instead of storing the full matrix.
/// This reduces memory from O(n²) to O(mn), making it suitable for large-scale problems
/// with 1,000+ variables.
///
/// ## Memory Comparison
///
/// | Variables | BFGS Memory | L-BFGS (m=10) | Reduction |
/// |-----------|-------------|---------------|-----------|
/// | 100       | 80 KB       | 16 KB         | 80%       |
/// | 1,000     | 8 MB        | 160 KB        | 98%       |
/// | 10,000    | 800 MB      | 1.6 MB        | 99.8%     |
///
/// ## Example
/// ```swift
/// // Optimize 1,000-asset portfolio
/// let numAssets = 1_000
/// let returns = VectorN<Double>((0..<numAssets).map { _ in Double.random(in: 0.05...0.15) })
/// let riskAversion = 2.0
///
/// // Mean-variance objective: -μ + λσ²
/// let objective: (VectorN<Double>) -> Double = { weights in
///     let expectedReturn = weights.dot(returns)
///     let variance = weights.dot(weights)  // Simplified
///     return -(expectedReturn - riskAversion * variance)
/// }
///
/// let optimizer = MultivariateLBFGS<VectorN<Double>>.largeScale()
/// let initialWeights = VectorN<Double>.equalWeights(dimension: numAssets)
///
/// let result = try optimizer.minimizeLBFGS(
///     function: objective,
///     initialGuess: initialWeights
/// )
///
/// print("Optimal Sharpe: \(-result.value)")
/// print("Converged in \(result.iterations) iterations")
/// ```
public struct MultivariateLBFGS<V: VectorSpace> where V.Scalar: Real {
	/// Number of previous gradient/position pairs to store (typically 5-20)
	public let memorySize: Int

	/// Maximum number of iterations
	public let maxIterations: Int

	/// Convergence tolerance for gradient norm
	public let tolerance: V.Scalar

	/// Whether to use backtracking line search for adaptive step sizing
	public let useLineSearch: Bool

	/// Whether to record optimization history for analysis
	public let recordHistory: Bool

	/// Creates an L-BFGS optimizer with specified configuration.
	///
	/// - Parameters:
	///   - memorySize: Number of (s,y) pairs to store. Typical values: 5-20. Default: 10
	///   - maxIterations: Maximum optimization iterations. Default: 100
	///   - tolerance: Convergence tolerance for gradient norm. Default: 1e-6
	///   - useLineSearch: Enable backtracking line search. Default: true
	///   - recordHistory: Record iteration history for analysis. Default: false
	public init(
		memorySize: Int = 10,
		maxIterations: Int = 100,
		tolerance: V.Scalar? = nil,
		useLineSearch: Bool = true,
		recordHistory: Bool = false
	) {
		self.memorySize = memorySize
		self.maxIterations = maxIterations
		self.tolerance = tolerance ?? (V.Scalar(1) / V.Scalar(1_000_000))
		self.useLineSearch = useLineSearch
		self.recordHistory = recordHistory
	}

	// MARK: - L-BFGS with Explicit Gradient

	/// Minimizes a function using L-BFGS with explicit gradient.
	///
	/// L-BFGS uses a two-loop recursion to compute the search direction without
	/// storing the full Hessian matrix. It maintains a history of the last m
	/// gradient/position differences to approximate curvature information.
	///
	/// - Parameters:
	///   - function: The objective function f: V → ℝ to minimize
	///   - gradient: Function that computes ∇f at a point
	///   - initialGuess: Starting point for optimization
	/// - Returns: Optimization result containing solution and convergence info
	/// - Throws: `OptimizationError` if optimization fails
	///
	/// ## Example
	/// ```swift
	/// let rosenbrock: (VectorN<Double>) -> Double = { v in
	///     let x = v[0], y = v[1]
	///     return (1 - x) * (1 - x) + 100 * (y - x*x) * (y - x*x)
	/// }
	///
	/// let optimizer = MultivariateLBFGS<VectorN<Double>>(memorySize: 10)
	/// let result = try optimizer.minimizeLBFGS(
	///     function: rosenbrock,
	///     gradient: { try numericalGradient(rosenbrock, at: $0) },
	///     initialGuess: VectorN([0.0, 0.0])
	/// )
	/// ```
	public func minimizeLBFGS(
		function: @Sendable (V) -> V.Scalar,
		gradient: (V) throws -> V,
		initialGuess: V
	) throws -> MultivariateOptimizationResult<V> {
		var x = initialGuess
		var grad = try gradient(x)

		var sHistory: [V] = []
		var yHistory: [V] = []
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

			// Compute search direction via two-loop recursion
			let direction = computeSearchDirection(
				gradient: grad,
				sHistory: sHistory,
				yHistory: yHistory
			)

			// Determine step size via line search
			let alpha: V.Scalar
			if useLineSearch {
				alpha = try backtrackingLineSearch(
					function: function,
					point: x,
					gradient: grad,
					direction: direction,
					initialStepSize: V.Scalar(1)
				)
			} else {
				alpha = V.Scalar(1)
			}

			// Update position
			let xNew = x + alpha * direction
			let gradNew = try gradient(xNew)

			// Update history: s = x_{k+1} - x_k, y = g_{k+1} - g_k
			let s = xNew - x
			let y = gradNew - grad
			updateHistory(sHistory: &sHistory, yHistory: &yHistory, s: s, y: y)

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

	// MARK: - L-BFGS with Automatic Gradient

	/// Minimizes a function using L-BFGS with automatic numerical gradient computation.
	///
	/// This is a convenience overload that automatically computes the gradient using
	/// finite differences (central differences). If you have an analytical gradient,
	/// use the explicit gradient overload for better performance and accuracy.
	///
	/// - Parameters:
	///   - function: The objective function f: V → ℝ to minimize
	///   - initialGuess: Starting point for optimization
	///   - epsilon: Step size for numerical differentiation. Default: 1e-6
	/// - Returns: Optimization result
	/// - Throws: `OptimizationError` if optimization fails
	///
	/// ## Example
	/// ```swift
	/// let sphere: (VectorN<Double>) -> Double = { v in
	///     v.toArray().reduce(0.0) { $0 + $1 * $1 }
	/// }
	///
	/// let optimizer = MultivariateLBFGS<VectorN<Double>>.largeScale()
	/// let result = try optimizer.minimizeLBFGS(
	///     function: sphere,
	///     initialGuess: VectorN(repeating: 1.0, count: 1000)
	/// )
	/// ```
	public func minimizeLBFGS(
		function: @escaping @Sendable (V) -> V.Scalar,
		initialGuess: V,
		epsilon: V.Scalar = V.Scalar(1) / V.Scalar(1_000_000)
	) throws -> MultivariateOptimizationResult<V> {
		// Create gradient function using numerical differentiation
		let gradientFunction: (V) throws -> V = { point in
			try numericalGradient(function, at: point, epsilon: epsilon)
		}

		// Call the main minimizeLBFGS with computed gradient
		return try minimizeLBFGS(
			function: function,
			gradient: gradientFunction,
			initialGuess: initialGuess
		)
	}

	// MARK: - Two-Loop Recursion Algorithm

	/// Computes the search direction using L-BFGS two-loop recursion.
	///
	/// This is the core L-BFGS algorithm that approximates H^{-1} ∇f without
	/// explicitly storing the Hessian matrix. It uses the history of gradient
	/// and position differences to implicitly represent curvature information.
	///
	/// Algorithm:
	/// 1. Backward loop: Apply (I - ρᵢ yᵢ sᵢᵀ) transformations
	/// 2. Initial scaling: H₀ = γI where γ = (s·y)/(y·y)
	/// 3. Forward loop: Apply (I - ρᵢ sᵢ yᵢᵀ) transformations
	///
	/// - Parameters:
	///   - gradient: Current gradient ∇f(x_k)
	///   - sHistory: Position differences [x_{k} - x_{k-1}, ...]
	///   - yHistory: Gradient differences [∇f_k - ∇f_{k-1}, ...]
	/// - Returns: Search direction p_k = -H_k^{-1} ∇f_k
	private func computeSearchDirection(
		gradient: V,
		sHistory: [V],
		yHistory: [V]
	) -> V {
		// First iteration: use steepest descent
		guard !sHistory.isEmpty else {
			return V.Scalar(-1) * gradient
		}

		let m = sHistory.count
		var q = gradient
		var alphas: [V.Scalar] = []
		alphas.reserveCapacity(m)

		// First loop (backward): i = m-1, m-2, ..., 0
		for i in stride(from: m - 1, through: 0, by: -1) {
			let s = sHistory[i]
			let y = yHistory[i]

			// ρᵢ = 1 / (yᵢ · sᵢ)
			let sTy = s.dot(y)
			guard sTy > V.Scalar(1) / V.Scalar(1_000_000_000) else {
				// Curvature condition violated, skip this pair
				alphas.append(V.Scalar(0))
				continue
			}
			let rho = V.Scalar(1) / sTy

			// αᵢ = ρᵢ (sᵢ · q)
			let alpha = rho * s.dot(q)
			alphas.append(alpha)

			// q = q - αᵢ yᵢ
			q = q - alpha * y
		}

		// Initial Hessian approximation scaling: H₀ = γI
		// γ = (s_{m-1} · y_{m-1}) / (y_{m-1} · y_{m-1})
		let lastS = sHistory.last!
		let lastY = yHistory.last!
		let gamma = lastS.dot(lastY) / max(lastY.dot(lastY), V.Scalar(1) / V.Scalar(1_000_000_000))

		// r = H₀ * q = γq
		var r = gamma * q

		// Second loop (forward): i = 0, 1, ..., m-1
		alphas.reverse()  // Now indexed 0, 1, 2, ...
		for i in 0..<m {
			let s = sHistory[i]
			let y = yHistory[i]

			let sTy = s.dot(y)
			guard sTy > V.Scalar(1) / V.Scalar(1_000_000_000) else {
				continue
			}
			let rho = V.Scalar(1) / sTy

			// βᵢ = ρᵢ (yᵢ · r)
			let beta = rho * y.dot(r)

			// r = r + sᵢ(αᵢ - βᵢ)
			r = r + (alphas[i] - beta) * s
		}

		// Return negative for descent direction
		return V.Scalar(-1) * r
	}

	// MARK: - History Management

	/// Updates the history with a new (s,y) pair, maintaining FIFO order.
	///
	/// This method implements the limited-memory aspect of L-BFGS by storing
	/// only the most recent m pairs and discarding older ones.
	///
	/// - Parameters:
	///   - sHistory: Array of position differences to update
	///   - yHistory: Array of gradient differences to update
	///   - s: New position difference x_{k+1} - x_k
	///   - y: New gradient difference ∇f_{k+1} - ∇f_k
	private func updateHistory(
		sHistory: inout [V],
		yHistory: inout [V],
		s: V,
		y: V
	) {
		// Check curvature condition: s · y > 0
		let curvature = s.dot(y)
		guard curvature > V.Scalar(1) / V.Scalar(1_000_000_000) else {
			// Skip this update if curvature condition violated
			return
		}

		sHistory.append(s)
		yHistory.append(y)

		// FIFO: Remove oldest if exceeded memory
		if sHistory.count > memorySize {
			sHistory.removeFirst()
			yHistory.removeFirst()
		}
	}

	// MARK: - Line Search

	/// Backtracking line search to find a good step size using the Armijo condition.
	///
	/// - Parameters:
	///   - function: The objective function
	///   - point: Current point x_k
	///   - gradient: Gradient at current point ∇f(x_k)
	///   - direction: Search direction p_k
	///   - initialStepSize: Initial step size to try (usually 1.0)
	///   - c1: Armijo condition parameter (typically 1e-4)
	///   - rho: Backtracking factor (typically 0.5)
	/// - Returns: Optimal step size α
	private func backtrackingLineSearch(
		function: @Sendable (V) -> V.Scalar,
		point: V,
		gradient: V,
		direction: V,
		initialStepSize: V.Scalar,
		c1: V.Scalar = V.Scalar(1) / V.Scalar(10_000),  // 1e-4
		rho: V.Scalar = V.Scalar(1) / V.Scalar(2)       // 0.5
	) throws -> V.Scalar {
		let f0 = function(point)
		let gradDotDir = gradient.dot(direction)

		// Direction must be descent direction (∇f · p < 0)
		guard gradDotDir < V.Scalar(0) else {
			// Not a descent direction, return small step
			return V.Scalar(1) / V.Scalar(100)
		}

		var alpha = initialStepSize
		let maxBacktracks = 50

		for _ in 0..<maxBacktracks {
			let newPoint = point + alpha * direction
			let fNew = function(newPoint)

			// Armijo condition: f(x + αd) ≤ f(x) + c₁α∇f·d
			if fNew <= f0 + c1 * alpha * gradDotDir {
				return alpha
			}

			// Reduce step size
			alpha = alpha * rho
		}

		// If line search fails completely, return last tried alpha
		return alpha
	}
}

// MARK: - Convenience Extensions

extension MultivariateLBFGS {
	/// Creates a standard L-BFGS optimizer with default settings (m=10).
	///
	/// Suitable for most problems with moderate dimensionality (100-1,000 variables).
	public static func standard() -> MultivariateLBFGS<V> {
		MultivariateLBFGS(memorySize: 10)
	}

	/// Creates an L-BFGS optimizer optimized for large-scale problems (1,000+ variables).
	///
	/// Uses default memory size (m=10) with increased iteration budget.
	///
	/// - Parameter maxIterations: Maximum iterations. Default: 1000
	public static func largeScale(maxIterations: Int = 1000) -> MultivariateLBFGS<V> {
		MultivariateLBFGS(
			memorySize: 10,
			maxIterations: maxIterations,
			useLineSearch: true
		)
	}

	/// Creates a low-memory L-BFGS optimizer for extremely large problems (m=5).
	///
	/// Uses minimal memory at the cost of slightly slower convergence.
	///
	/// - Parameter maxIterations: Maximum iterations. Default: 1000
	public static func lowMemory(maxIterations: Int = 1000) -> MultivariateLBFGS<V> {
		MultivariateLBFGS(
			memorySize: 5,
			maxIterations: maxIterations
		)
	}

	/// Creates a high-accuracy L-BFGS optimizer with larger history (m=20).
	///
	/// Uses more memory for better Hessian approximation and faster convergence.
	public static func highAccuracy() -> MultivariateLBFGS<V> {
		MultivariateLBFGS(
			memorySize: 20,
			maxIterations: 500,
			tolerance: V.Scalar(1) / V.Scalar(1_000_000_000)  // 1e-9
		)
	}
}

// MARK: - MultivariateOptimizer Protocol Conformance

extension MultivariateLBFGS: MultivariateOptimizer {
	/// Minimizes an objective function (protocol conformance method).
	///
	/// This method implements the ``MultivariateOptimizer`` protocol by delegating
	/// to the existing `minimizeLBFGS(function:initialGuess:)` method with automatic
	/// numerical gradient computation.
	///
	/// - Parameters:
	///   - objective: Function to minimize: f(v) → scalar
	///   - initialGuess: Starting point for optimization
	///   - constraints: Optimization constraints. **Note**: `MultivariateLBFGS`
	///     is an unconstrained optimizer and will throw an error if constraints are provided.
	///
	/// - Returns: Optimization result containing solution, objective value, iterations, and convergence info
	///
	/// - Throws:
	///   - ``OptimizationError/unsupportedConstraints(_:)`` if constraints are provided (unconstrained optimizer)
	///   - ``OptimizationError/nonFiniteValue(message:)`` if non-finite values encountered
	///
	/// ## Example
	///
	/// ```swift
	/// // Use as protocol type for algorithm flexibility
	/// let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateLBFGS<VectorN<Double>>.largeScale()
	///
	/// let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }
	/// let result = try optimizer.minimize(objective, from: VectorN(repeating: 5.0, count: 1000))
	/// ```
	public func minimize(
		_ objective: @escaping (V) -> V.Scalar,
		from initialGuess: V,
		constraints: [MultivariateConstraint<V>]
	) throws -> MultivariateOptimizationResult<V> {
		// Unconstrained optimizer - reject any constraints
		guard constraints.isEmpty else {
			throw OptimizationError.unsupportedConstraints(
				"MultivariateLBFGS only supports unconstrained optimization. " +
				"For constrained optimization, use ConstrainedOptimizer or InequalityOptimizer."
			)
		}

		// Delegate to automatic gradient version
		return try minimizeLBFGS(function: objective, initialGuess: initialGuess)
	}
}

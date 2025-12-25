//
//  MultivariateGradientDescent.swift
//  BusinessMath
//
//  Created by Claude Code on 12/03/25.
//

import Foundation
import Numerics

// MARK: - Multivariate Optimization Result

/// Result from a multivariate optimization
public struct MultivariateOptimizationResult<V: VectorSpace>: Sendable where V.Scalar: Real, V: Sendable, V.Scalar: Sendable {
	/// The optimal solution point
	public let solution: V

	/// The function value at the solution
	public let value: V.Scalar

	/// Number of iterations performed
	public let iterations: Int

	/// Whether the algorithm converged
	public let converged: Bool

	/// The gradient norm at the solution
	public let gradientNorm: V.Scalar

	/// Optional history of iteration points and values
	public let history: [(iteration: Int, point: V, value: V.Scalar, gradientNorm: V.Scalar)]?

	/// Formatter used for displaying results (mutable for customization)
	public var formatter: FloatingPointFormatter = .optimization

	// MARK: - Protocol Compatibility

	/// Convenience property for protocol compatibility (alias for `value`)
	public var objectiveValue: V.Scalar {
		value
	}

	/// Description of why optimization stopped (for protocol compatibility)
	public var convergenceReason: String {
		if converged {
			return "Converged: gradient norm below tolerance"
		} else {
			return "Maximum iterations reached"
		}
	}
}

// MARK: - Formatting Extensions (Double only)

extension MultivariateOptimizationResult where V.Scalar == Double {
	/// Formatted solution with clean floating-point display
	public var formattedSolution: String {
		if let vectorN = solution as? VectorN<Double> {
			return vectorN.formattedDescription(with: formatter)
		}
		// Fallback for other VectorSpace types with Double scalar
		let array = solution.toArray()
		return "[" + formatter.format(array).map(\.formatted).joined(separator: ", ") + "]"
	}

	/// Formatted objective value with clean floating-point display
	public var formattedObjectiveValue: String {
		formatter.format(value).formatted
	}

	/// Formatted description showing clean results
	public var formattedDescription: String {
		var desc = "Optimization Result:\n"
		desc += "  Solution: \(formattedSolution)\n"
		desc += "  Objective Value: \(formattedObjectiveValue)\n"
		desc += "  Iterations: \(iterations)\n"
		desc += "  Converged: \(converged)\n"
		desc += "  Gradient Norm: \(formatter.format(gradientNorm).formatted)"
		return desc
	}
}

// MARK: - Multivariate Gradient Descent

/// Gradient descent optimizer for N-dimensional functions over VectorSpace types.
///
/// Minimizes a scalar function f: V → ℝ using gradient information.
/// Supports multiple variants: basic, momentum, and Adam optimizer.
///
/// ## Example
/// ```swift
/// // Minimize Rosenbrock function: f(x,y) = (1-x)² + 100(y-x²)²
/// let rosenbrock: (VectorN<Double>) -> Double = { v in
///     let x = v[0], y = v[1]
///     return (1 - x) * (1 - x) + 100 * (y - x*x) * (y - x*x)
/// }
///
/// let optimizer = MultivariateGradientDescent<VectorN<Double>>(
///     learningRate: 0.001,
///     maxIterations: 10000,
///     tolerance: 1e-6
/// )
///
/// let initialGuess = VectorN([0.0, 0.0])
///
/// // Simple API: gradient computed automatically
/// let result = try optimizer.minimize(
///     function: rosenbrock,
///     initialGuess: initialGuess
/// )
///
/// // Or provide explicit gradient for better performance:
/// // let result = try optimizer.minimize(
/// //     function: rosenbrock,
/// //     gradient: { try numericalGradient(rosenbrock, at: $0) },
/// //     initialGuess: initialGuess
/// // )
///
/// print("Solution: \(result.solution)")  // Near [1.0, 1.0]
/// print("Iterations: \(result.iterations)")
/// ```
public struct MultivariateGradientDescent<V: VectorSpace> where V.Scalar: Real {
	/// Learning rate (step size)
	public let learningRate: V.Scalar

	/// Maximum number of iterations
	public let maxIterations: Int

	/// Convergence tolerance for gradient norm
	public let tolerance: V.Scalar

	/// Whether to record optimization history
	public let recordHistory: Bool

	/// Momentum coefficient (0 = no momentum)
	public let momentum: V.Scalar

	/// Whether to use line search for adaptive step size
	public let useLineSearch: Bool

	public init(
		learningRate: V.Scalar,
		maxIterations: Int = 1000,
		tolerance: V.Scalar? = nil,
		recordHistory: Bool = false,
		momentum: V.Scalar = V.Scalar(0),
		useLineSearch: Bool = false
	) {
		self.learningRate = learningRate
		self.maxIterations = maxIterations
		self.tolerance = tolerance ?? (V.Scalar(1) / V.Scalar(1_000_000))
		self.recordHistory = recordHistory
		self.momentum = momentum
		self.useLineSearch = useLineSearch
	}

	// MARK: - Basic Gradient Descent

	/// Minimizes a function using gradient descent.
	///
	/// Updates: x_{k+1} = x_k - α∇f(x_k) where α is the learning rate.
	///
	/// - Parameters:
	///   - function: The objective function f: V → ℝ to minimize
	///   - gradient: Function that computes ∇f at a point
	///   - initialGuess: Starting point for optimization
	/// - Returns: Optimization result containing solution and convergence info
	/// - Throws: `OptimizationError` if optimization fails
	public func minimize(
		function: (V) -> V.Scalar,
		gradient: (V) throws -> V,
		initialGuess: V
	) throws -> MultivariateOptimizationResult<V> {
		var x = initialGuess
		var history: [(Int, V, V.Scalar, V.Scalar)]? = recordHistory ? [] : nil

		// Momentum velocity
		var velocity: V? = momentum > V.Scalar(0) ? V.zero : nil

		for iteration in 0..<maxIterations {
			// Compute gradient
			let grad = try gradient(x)
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

			// Compute step
			var step: V
			if let v = velocity, momentum > V.Scalar(0) {
				// Momentum update: v = βv - α∇f
				let newVelocity = momentum * v - learningRate * grad
				velocity = newVelocity
				step = newVelocity
			} else {
				// Standard gradient descent: step = -α∇f
				step = (-learningRate) * grad
			}

			// Line search for adaptive step size
			if useLineSearch {
				let alpha = try backtrackingLineSearch(
					function: function,
					point: x,
					gradient: grad,
					direction: step,
					initialStepSize: V.Scalar(1)
				)
				step = alpha * step
			}

			// Update position
			x = x + step
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

	// MARK: - Convenience Overload with Automatic Gradient

	/// Minimizes a function using gradient descent with automatic numerical gradient computation.
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
	/// let optimizer = MultivariateGradientDescent<VectorN<Double>>(learningRate: 0.1)
	/// let result = try optimizer.minimize(
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
	public func minimize(
		function: @escaping (V) -> V.Scalar,
		initialGuess: V,
		epsilon: V.Scalar = V.Scalar(1) / V.Scalar(1_000_000)
	) throws -> MultivariateOptimizationResult<V> {
		// Create gradient function using numerical differentiation
		let gradientFunction: (V) throws -> V = { point in
			try numericalGradient(function, at: point, epsilon: epsilon)
		}

		// Call the main minimize with computed gradient
		return try minimize(
			function: function,
			gradient: gradientFunction,
			initialGuess: initialGuess
		)
	}

	// MARK: - Adam Optimizer

	/// Minimizes a function using the Adam optimizer.
	///
	/// Adam (Adaptive Moment Estimation) combines momentum with adaptive learning rates.
	/// Often converges faster than basic gradient descent.
	///
	/// - Parameters:
	///   - function: The objective function f: V → ℝ to minimize
	///   - gradient: Function that computes ∇f at a point
	///   - initialGuess: Starting point for optimization
	///   - beta1: Exponential decay rate for first moment (default: 0.9)
	///   - beta2: Exponential decay rate for second moment (default: 0.999)
	///   - epsilon: Small constant for numerical stability (default: 1e-8)
	/// - Returns: Optimization result
	/// - Throws: `OptimizationError` if optimization fails
	public func minimizeAdam(
		function: (V) -> V.Scalar,
		gradient: (V) throws -> V,
		initialGuess: V,
		beta1: V.Scalar = V.Scalar(9) / V.Scalar(10),
		beta2: V.Scalar = V.Scalar(999) / V.Scalar(1000),
		epsilon: V.Scalar = V.Scalar(1) / V.Scalar(100_000_000)
	) throws -> MultivariateOptimizationResult<V> {
		var x = initialGuess
		var m = V.zero  // First moment (momentum)
		var v = V.zero  // Second moment (velocity)
		var history: [(Int, V, V.Scalar, V.Scalar)]? = recordHistory ? [] : nil

		for iteration in 1...maxIterations {
			// Compute gradient
			let grad = try gradient(x)
			let gradNorm = grad.norm

			// Check for non-finite values
			guard gradNorm.isFinite else {
				throw OptimizationError.nonFiniteValue(message: "Gradient norm is not finite")
			}

			// Record history
			if recordHistory {
				let fValue = function(x)
				history?.append((iteration - 1, x, fValue, gradNorm))
			}

			// Check convergence
			if gradNorm < tolerance {
				let finalValue = function(x)
				return MultivariateOptimizationResult(
					solution: x,
					value: finalValue,
					iterations: iteration - 1,
					converged: true,
					gradientNorm: gradNorm,
					history: history
				)
			}

			// Update biased first moment estimate
			m = beta1 * m + (V.Scalar(1) - beta1) * grad

			// Update biased second moment estimate (element-wise square)
			// Note: For VectorSpace, we compute v ≈ grad ∘ grad (element-wise)
			let gradArray = grad.toArray()
			let gradSquaredArray = gradArray.map { $0 * $0 }
			guard let gradSquared = V.fromArray(gradSquaredArray) else {
				throw OptimizationError.invalidInput(message: "Failed to construct squared gradient")
			}
			v = beta2 * v + (V.Scalar(1) - beta2) * gradSquared

			// Bias correction
			let t = V.Scalar(iteration)
			let beta1Pow = V.Scalar.pow(beta1, t)
			let beta2Pow = V.Scalar.pow(beta2, t)
			let mBiasCorrection = V.Scalar(1) / (V.Scalar(1) - beta1Pow)
			let vBiasCorrection = V.Scalar(1) / (V.Scalar(1) - beta2Pow)
			let mHat = mBiasCorrection * m
			let vHat = vBiasCorrection * v

			// Compute adaptive step
			// step = -α * m̂ / (√v̂ + ε)
			// For VectorSpace: element-wise division approximation
			let sqrtVHat = vHat.toArray().map { V.Scalar.sqrt($0) + epsilon }
			let mHatArray = mHat.toArray()

			var stepComponents: [V.Scalar] = []
			for i in 0..<sqrtVHat.count {
				stepComponents.append(-learningRate * mHatArray[i] / sqrtVHat[i])
			}

			guard let step = V.fromArray(stepComponents) else {
				throw OptimizationError.invalidInput(message: "Failed to construct step vector")
			}

			// Update position
			x = x + step
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

	/// Minimizes a function using the Adam optimizer with automatic numerical gradient computation.
	///
	/// This is a convenience overload that automatically computes the gradient using
	/// finite differences. Adam often converges faster than basic gradient descent,
	/// especially on problems with ill-conditioned Hessians or noisy gradients.
	///
	/// ## Example
	/// ```swift
	/// // Minimize Rosenbrock: f(x,y) = (1-x)² + 100(y-x²)²
	/// let rosenbrock: (VectorN<Double>) -> Double = { v in
	///     let x = v[0], y = v[1]
	///     return (1 - x) * (1 - x) + 100 * (y - x*x) * (y - x*x)
	/// }
	///
	/// let optimizer = MultivariateGradientDescent<VectorN<Double>>(learningRate: 0.001)
	/// let result = try optimizer.minimizeAdam(
	///     function: rosenbrock,
	///     initialGuess: VectorN([0.0, 0.0])
	/// )
	///
	/// // Solution: (1, 1) with value 0
	/// ```
	///
	/// - Parameters:
	///   - function: The objective function f: V → ℝ to minimize
	///   - initialGuess: Starting point for optimization
	///   - epsilon: Step size for numerical differentiation (default: 1e-6)
	///   - beta1: Exponential decay rate for first moment (default: 0.9)
	///   - beta2: Exponential decay rate for second moment (default: 0.999)
	///   - adamEpsilon: Small constant for numerical stability in Adam (default: 1e-8)
	/// - Returns: Optimization result
	/// - Throws: `OptimizationError` if optimization fails
	///
	/// - Note: Automatic gradient computation costs approximately 2n function
	///         evaluations per iteration, where n is the dimension.
	public func minimizeAdam(
		function: @escaping (V) -> V.Scalar,
		initialGuess: V,
		epsilon: V.Scalar = V.Scalar(1) / V.Scalar(1_000_000),
		beta1: V.Scalar = V.Scalar(9) / V.Scalar(10),
		beta2: V.Scalar = V.Scalar(999) / V.Scalar(1000),
		adamEpsilon: V.Scalar = V.Scalar(1) / V.Scalar(100_000_000)
	) throws -> MultivariateOptimizationResult<V> {
		// Create gradient function using numerical differentiation
		let gradientFunction: (V) throws -> V = { point in
			try numericalGradient(function, at: point, epsilon: epsilon)
		}

		// Call the main minimizeAdam with computed gradient
		return try minimizeAdam(
			function: function,
			gradient: gradientFunction,
			initialGuess: initialGuess,
			beta1: beta1,
			beta2: beta2,
			epsilon: adamEpsilon
		)
	}

	// MARK: - Line Search

	/// Backtracking line search to find a good step size.
	///
	/// Finds α such that f(x + αd) ≤ f(x) + c₁α∇f(x)ᵀd (Armijo condition)
	///
	/// - Parameters:
	///   - function: The objective function
	///   - point: Current point
	///   - gradient: Gradient at current point
	///   - direction: Search direction
	///   - initialStepSize: Initial step size to try
	///   - c1: Armijo condition parameter (default: 1e-4)
	///   - rho: Step size reduction factor (default: 0.5)
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
}

// MARK: - Convenience Extensions

extension MultivariateGradientDescent {
	/// Creates a gradient descent optimizer with default settings
	public static func standard(learningRate: V.Scalar) -> MultivariateGradientDescent<V> {
		MultivariateGradientDescent(learningRate: learningRate)
	}

	/// Creates a gradient descent optimizer with momentum
	public static func withMomentum(
		learningRate: V.Scalar,
		momentum: V.Scalar = V.Scalar(9) / V.Scalar(10)
	) -> MultivariateGradientDescent<V> {
		MultivariateGradientDescent(
			learningRate: learningRate,
			momentum: momentum
		)
	}

	/// Creates a gradient descent optimizer with line search
	public static func withLineSearch(learningRate: V.Scalar) -> MultivariateGradientDescent<V> {
		MultivariateGradientDescent(
			learningRate: learningRate,
			useLineSearch: true
		)
	}
}

// MARK: - MultivariateOptimizer Protocol Conformance

extension MultivariateGradientDescent: MultivariateOptimizer {
	/// Minimize an objective function (protocol conformance method).
	///
	/// This method implements the ``MultivariateOptimizer`` protocol by delegating
	/// to the existing `minimize(function:initialGuess:)` method.
	///
	/// - Parameters:
	///   - objective: Function to minimize: f(v) → scalar
	///   - initialGuess: Starting point for optimization
	///   - constraints: Optimization constraints. **Note**: `MultivariateGradientDescent`
	///     is an unconstrained optimizer and will throw an error if constraints are provided.
	///
	/// - Returns: Optimization result containing solution, objective value, iterations, and convergence info
	///
	/// - Throws:
	///   - ``OptimizationError/unsupportedConstraints(_:)`` if constraints are provided (unconstrained optimizer)
	///   - ``OptimizationError/convergenceFailed`` if optimization fails to converge
	///   - ``OptimizationError/nonFiniteValue(message:)`` if non-finite values encountered
	///
	/// ## Example
	///
	/// ```swift
	/// // Use as protocol type for algorithm flexibility
	/// let optimizer: any MultivariateOptimizer = MultivariateGradientDescent<VectorN<Double>>(
	///     learningRate: 0.01,
	///     maxIterations: 1000
	/// )
	///
	/// let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }
	/// let result = try optimizer.minimize(objective, from: VectorN([5.0, 5.0]))
	/// ```
	///
	/// - Note: For algorithm-specific methods like `minimizeAdam()` or `minimizeMomentum()`,
	///         use the concrete type `MultivariateGradientDescent<V>` instead of the protocol.
	public func minimize(
		_ objective: @escaping (V) -> V.Scalar,
		from initialGuess: V,
		constraints: [MultivariateConstraint<V>] = []
	) throws -> MultivariateOptimizationResult<V> {
		// Unconstrained optimizer - reject any constraints
		guard constraints.isEmpty else {
			throw OptimizationError.unsupportedConstraints(
				"MultivariateGradientDescent only supports unconstrained optimization. " +
				"For constrained optimization, use ConstrainedOptimizer or InequalityOptimizer."
			)
		}

		// Delegate to existing implementation (with automatic gradient computation)
		return try minimize(function: objective, initialGuess: initialGuess)
	}
}

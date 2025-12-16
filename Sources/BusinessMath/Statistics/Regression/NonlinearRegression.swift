//
//  NonlinearRegression.swift
//  BusinessMath
//
//  Created for fake-data simulation and model validation.
//  Based on Andrew Gelman's blog post on simulating from and checking models in Stan.
//
//  Reference: https://statmodeling.stat.columbia.edu/2025/12/15/simulating-from-and-checking-a-model-in-stan/
//

import Foundation
import Numerics

// MARK: - Nonlinear Regression Models

/// A nonlinear regression model with a reciprocal form: y ~ Normal(1/(a + b*x), sigma).
///
/// This model is useful for studying relationships where the response variable is inversely related
/// to a linear combination of the predictor. Common in pharmacokinetics, economics, and other fields.
///
/// # Mathematical Form
/// ```
/// y[i] ~ Normal(μ[i], σ)
/// μ[i] = 1 / (a + b * x[i])
/// ```
///
/// # Example
/// ```swift
/// // True parameters
/// let trueA = 0.2
/// let trueB = 0.3
/// let trueSigma = 0.2
///
/// // Simulate data
/// let simulator = ReciprocalRegressionSimulator(a: trueA, b: trueB, sigma: trueSigma)
/// let data = simulator.simulate(n: 100, xRange: 0.0...10.0)
///
/// // Fit the model to recover parameters
/// let fitter = ReciprocalRegressionFitter()
/// let result = try fitter.fit(data: data)
///
/// print("Recovered a: \(result.a) (true: \(trueA))")
/// print("Recovered b: \(result.b) (true: \(trueB))")
/// print("Recovered sigma: \(result.sigma) (true: \(trueSigma))")
/// ```
public struct ReciprocalRegressionModel<T: Real & Sendable & Codable> where T: BinaryFloatingPoint {
	/// Parameters for the reciprocal regression model
	public struct Parameters: Sendable, Codable {
		/// Intercept parameter (must be > 0 for identifiability)
		public let a: T

		/// Slope parameter (must be > 0 for identifiability)
		public let b: T

		/// Standard deviation of residuals (must be > 0)
		public let sigma: T

		public init(a: T, b: T, sigma: T) {
			self.a = a
			self.b = b
			self.sigma = sigma
		}
	}

	/// Data point for regression
	public struct DataPoint: Sendable, Codable {
		public let x: T
		public let y: T

		public init(x: T, y: T) {
			self.x = x
			self.y = y
		}
	}

	/// Predicted mean at a given x value
	/// - Parameters:
	///   - x: Predictor value
	///   - params: Model parameters
	/// - Returns: E[y|x] = 1 / (a + b*x)
	public static func predictedMean(x: T, params: Parameters) -> T {
		return T(1) / (params.a + params.b * x)
	}

	/// Log-likelihood of a single observation
	/// - Parameters:
	///   - dataPoint: Observed (x, y) pair
	///   - params: Model parameters
	/// - Returns: log p(y|x, params)
	public static func logLikelihood(dataPoint: DataPoint, params: Parameters) -> T {
		let mu = predictedMean(x: dataPoint.x, params: params)
		let residual = dataPoint.y - mu

		// log p(y|μ,σ) = -log(σ) - 0.5*log(2π) - 0.5*((y-μ)/σ)²
		let logSigma = T.log(params.sigma)
		let log2Pi = T.log(T(2) * T.pi)
		let squaredError = (residual * residual) / (params.sigma * params.sigma)

		return -logSigma - T(0.5) * log2Pi - T(0.5) * squaredError
	}

	/// Total log-likelihood across all data points
	/// - Parameters:
	///   - data: Array of observed (x, y) pairs
	///   - params: Model parameters
	/// - Returns: sum of log p(y_i|x_i, params)
	public static func totalLogLikelihood(data: [DataPoint], params: Parameters) -> T {
		data.reduce(T(0)) { sum, point in
			sum + logLikelihood(dataPoint: point, params: params)
		}
	}

	/// Negative log-likelihood (for minimization)
	public static func negativeLogLikelihood(data: [DataPoint], params: Parameters) -> T {
		-totalLogLikelihood(data: data, params: params)
	}
}

// MARK: - Simulation

/// Simulates data from a reciprocal regression model.
///
/// Generates fake data following the model: y ~ Normal(1/(a + b*x), sigma).
/// Useful for validating model-fitting procedures and testing parameter recovery.
///
/// # Workflow (Fake-Data Simulation)
/// 1. Specify true parameter values (a, b, sigma)
/// 2. Generate predictor values x (e.g., uniformly over a range)
/// 3. For each x, simulate y from Normal(1/(a + b*x), sigma)
/// 4. Fit the model to simulated data
/// 5. Check if fitted parameters match true parameters
///
/// # Example
/// ```swift
/// let simulator = ReciprocalRegressionSimulator<Double>(a: 0.2, b: 0.3, sigma: 0.2)
/// let data = simulator.simulate(n: 100, xRange: 0.0...10.0)
/// // data now contains 100 (x, y) pairs generated from the model
/// ```
public struct ReciprocalRegressionSimulator<T: Real & Sendable & Codable> where T: BinaryFloatingPoint {
	public typealias DataPoint = ReciprocalRegressionModel<T>.DataPoint
	public typealias Parameters = ReciprocalRegressionModel<T>.Parameters

	/// True parameter values used for simulation
	public let parameters: Parameters

	/// Create a simulator with specified true parameters
	/// - Parameters:
	///   - a: True intercept (must be > 0)
	///   - b: True slope (must be > 0)
	///   - sigma: True residual standard deviation (must be > 0)
	public init(a: T, b: T, sigma: T) {
		self.parameters = Parameters(a: a, b: b, sigma: sigma)
	}

	/// Simulate data from the model
	/// - Parameters:
	///   - n: Number of observations to generate
	///   - xRange: Range for uniform sampling of x values
	/// - Returns: Array of (x, y) data points
	public func simulate(n: Int, xRange: ClosedRange<T>) -> [DataPoint] {
		var data: [DataPoint] = []
		data.reserveCapacity(n)

		for _ in 0..<n {
			// Generate x uniformly
			let u = T(Double.random(in: 0...1))
			let x = xRange.lowerBound + u * (xRange.upperBound - xRange.lowerBound)

			// Compute mean response
			let mu = ReciprocalRegressionModel.predictedMean(x: x, params: parameters)

			// Generate y from Normal(mu, sigma)
			let y: T
			if T.self == Double.self {
				y = T(distributionNormal(mean: Double(mu), stdDev: Double(parameters.sigma)))
			} else if T.self == Float.self {
				y = T(Float(distributionNormal(mean: Double(mu), stdDev: Double(parameters.sigma))))
			} else {
				// Fallback for other Real types
				let doubleMean = Double(mu)
				let doubleSigma = Double(parameters.sigma)
				y = T(distributionNormal(mean: doubleMean, stdDev: doubleSigma))
			}

			data.append(DataPoint(x: x, y: y))
		}

		return data
	}

	/// Simulate with specific x values (instead of random)
	/// - Parameter xValues: Specific predictor values
	/// - Returns: Array of (x, y) data points
	public func simulate(xValues: [T]) -> [DataPoint] {
		xValues.map { x in
			let mu = ReciprocalRegressionModel.predictedMean(x: x, params: parameters)
			let y: T
			if T.self == Double.self {
				y = T(distributionNormal(mean: Double(mu), stdDev: Double(parameters.sigma)))
			} else {
				y = T(distributionNormal(mean: Double(mu), stdDev: Double(parameters.sigma)))
			}
			return DataPoint(x: x, y: y)
		}
	}
}

// MARK: - Model Fitting

/// Fits a reciprocal regression model to data using maximum likelihood estimation.
///
/// Uses multivariate optimization to find parameters that maximize the likelihood
/// (equivalently, minimize negative log-likelihood) of the observed data.
///
/// # Example
/// ```swift
/// let fitter = ReciprocalRegressionFitter<Double>()
/// let result = try fitter.fit(
///     data: observedData,
///     initialGuess: Parameters(a: 0.5, b: 0.5, sigma: 0.5),
///     learningRate: 0.001,
///     maxIterations: 1000
/// )
///
/// print("Fitted parameters:")
/// print("  a = \(result.parameters.a)")
/// print("  b = \(result.parameters.b)")
/// print("  sigma = \(result.parameters.sigma)")
/// print("  log-likelihood = \(result.logLikelihood)")
/// ```
public struct ReciprocalRegressionFitter<T: Real & Sendable & Codable> where T: BinaryFloatingPoint {
	public typealias DataPoint = ReciprocalRegressionModel<T>.DataPoint
	public typealias Parameters = ReciprocalRegressionModel<T>.Parameters

	/// Result of model fitting
	public struct FitResult: Sendable {
		/// Estimated parameters
		public let parameters: Parameters

		/// Log-likelihood at the solution
		public let logLikelihood: T

		/// Negative log-likelihood (objective value)
		public let negativeLogLikelihood: T

		/// Number of optimization iterations
		public let iterations: Int

		/// Whether optimization converged
		public let converged: Bool

		/// Standard errors of parameter estimates (if available)
		public let standardErrors: Parameters?

		public init(
			parameters: Parameters,
			logLikelihood: T,
			negativeLogLikelihood: T,
			iterations: Int,
			converged: Bool,
			standardErrors: Parameters? = nil
		) {
			self.parameters = parameters
			self.logLikelihood = logLikelihood
			self.negativeLogLikelihood = negativeLogLikelihood
			self.iterations = iterations
			self.converged = converged
			self.standardErrors = standardErrors
		}
	}

	public init() {}

	/// Fit the model to data using gradient-based optimization
	/// - Parameters:
	///   - data: Observed (x, y) data points
	///   - initialGuess: Starting parameter values (default: a=0.5, b=0.5, sigma=0.5)
	///   - learningRate: Step size for gradient descent (default: 0.001)
	///   - maxIterations: Maximum optimization iterations (default: 1000)
	///   - tolerance: Convergence tolerance (default: 1e-6)
	/// - Returns: Fitted parameters and diagnostic information
	/// - Throws: OptimizationError if fitting fails
	public func fit(
		data: [DataPoint],
		initialGuess: Parameters = Parameters(a: T(0.5), b: T(0.5), sigma: T(0.5)),
		learningRate: T = T(0.001),
		maxIterations: Int = 1000,
		tolerance: T = T(1e-6)
	) throws -> FitResult {
		// Define objective function: negative log-likelihood as function of parameter vector
		let objective: (VectorN<T>) -> T = { params in
			// params[0] = a, params[1] = b, params[2] = sigma
			// Apply constraints: all parameters must be positive
			let a = max(params[0], T(0.001))  // Bounded away from 0
			let b = max(params[1], T(0.001))
			let sigma = max(params[2], T(0.001))

			let modelParams = Parameters(a: a, b: b, sigma: sigma)
			return ReciprocalRegressionModel.negativeLogLikelihood(data: data, params: modelParams)
		}

		// Numerical gradient
		let gradient: (VectorN<T>) throws -> VectorN<T> = { params in
			try numericalGradient(objective, at: params, h: T(1e-6))
		}

		// Create optimizer
		let optimizer = MultivariateGradientDescent<VectorN<T>>(
			learningRate: learningRate,
			maxIterations: maxIterations,
			tolerance: tolerance
		)

		// Convert initial guess to vector
		let initialVector = VectorN([initialGuess.a, initialGuess.b, initialGuess.sigma])

		// Optimize
		let result = try optimizer.minimize(
			function: objective,
			gradient: gradient,
			initialGuess: initialVector
		)

		// Extract parameters (with positivity constraints)
		let fittedA = max(result.solution[0], T(0.001))
		let fittedB = max(result.solution[1], T(0.001))
		let fittedSigma = max(result.solution[2], T(0.001))

		let fittedParams = Parameters(a: fittedA, b: fittedB, sigma: fittedSigma)

		// Compute log-likelihood
		let logLik = ReciprocalRegressionModel.totalLogLikelihood(data: data, params: fittedParams)

		return FitResult(
			parameters: fittedParams,
			logLikelihood: logLik,
			negativeLogLikelihood: result.value,
			iterations: result.iterations,
			converged: result.converged
		)
	}
}

// MARK: - Numerical Gradient

/// Compute numerical gradient using central differences
/// - Parameters:
///   - f: Scalar function of vector
///   - params: Point at which to evaluate gradient
///   - h: Step size for finite differences
/// - Returns: Gradient vector ∇f(params)
public func numericalGradient<T: Real & Sendable & Codable>(
	_ f: (VectorN<T>) -> T,
	at params: VectorN<T>,
	h: T
) throws -> VectorN<T> {
	let n = params.dimension
	var gradient: [T] = []
	gradient.reserveCapacity(n)

	for i in 0..<n {
		// Create perturbation vector
		var paramsPlus = params.toArray()
		var paramsMinus = params.toArray()

		paramsPlus[i] = paramsPlus[i] + h
		paramsMinus[i] = paramsMinus[i] - h

		// Central difference: (f(x+h) - f(x-h)) / (2h)
		let fPlus = f(VectorN(paramsPlus))
		let fMinus = f(VectorN(paramsMinus))

		let gradI = (fPlus - fMinus) / (T(2) * h)
		gradient.append(gradI)
	}

	return VectorN(gradient)
}

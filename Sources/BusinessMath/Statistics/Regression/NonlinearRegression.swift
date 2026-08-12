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

		/// Creates reciprocal regression parameters.
		/// - Parameters:
		///   - a: Intercept parameter
		///   - b: Slope parameter
		///   - sigma: Standard deviation of residuals
		public init(a: T, b: T, sigma: T) {
			self.a = a
			self.b = b
			self.sigma = sigma
		}
	}

	/// Data point for regression
	public struct DataPoint: Sendable, Codable {
		/// The independent variable (x-value).
		public let x: T

		/// The dependent variable (y-value).
		public let y: T

		/// Creates a data point with x and y coordinates.
		/// - Parameters:
		///   - x: Independent variable
		///   - y: Dependent variable
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

	/// Mean negative log-likelihood per observation (the descent objective).
	///
	/// The summed negative log-likelihood grows with the sample, and so does its
	/// gradient: doubling the data doubles every partial derivative. A gradient step
	/// of fixed size therefore moves twice as far on twice the data, which is why the
	/// same call that fits at `n = 50` overshoots at `n = 500`. Dividing by `n` makes
	/// the objective — and its gradient — a per-observation quantity, so a learning
	/// rate means the same thing at every sample size.
	///
	/// Dividing by a constant does not move the minimum, so this is the same
	/// estimator as ``negativeLogLikelihood(data:params:)``; only the step scale
	/// changes.
	///
	/// - Parameters:
	///   - data: Array of observed (x, y) pairs. Must not be empty.
	///   - params: Model parameters
	/// - Returns: The negative log-likelihood divided by the number of observations,
	///   or zero for empty data.
	public static func meanNegativeLogLikelihood(data: [DataPoint], params: Parameters) -> T {
		guard !data.isEmpty else { return T(0) }
		return negativeLogLikelihood(data: data, params: params) / T(data.count)
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
	/// Data point type (x, y coordinate pair).
	public typealias DataPoint = ReciprocalRegressionModel<T>.DataPoint

	/// Model parameters (a, b, sigma).
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
			let u = T(Double.random(in: 0...1)) // stochastic:exempt
			let x = xRange.lowerBound + u * (xRange.upperBound - xRange.lowerBound)

			// Compute mean response
			let mu = ReciprocalRegressionModel.predictedMean(x: x, params: parameters)

			// Generate y from Normal(mu, sigma)
			let y: T
			if T.self == Double.self { // fp-safety:disable
				y = T(distributionNormal(mean: Double(mu), stdDev: Double(parameters.sigma)))
			} else if T.self == Float.self { // fp-safety:disable
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
			if T.self == Double.self { // fp-safety:disable
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
///     learningRate: 0.1,
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
	/// Data point type (x, y coordinate pair).
	public typealias DataPoint = ReciprocalRegressionModel<T>.DataPoint

	/// Model parameters (a, b, sigma).
	public typealias Parameters = ReciprocalRegressionModel<T>.Parameters

	/// Why ``fit(data:initialGuess:learningRate:maxIterations:tolerance:)`` stopped.
	///
	/// `converged` on its own says only whether the fit succeeded. This says what
	/// happened when it did not, which is the difference between "give it more
	/// iterations" and "these parameters are not a fit at all".
	public enum TerminationReason: Sendable, Equatable {
		/// The gradient of the per-observation objective fell below the tolerance at
		/// finite parameters that fit the data better than a constant would. This is
		/// the only reason for which `converged` is `true`.
		case converged

		/// The iteration limit was reached while the gradient was still above the
		/// tolerance. The returned parameters are the best point visited, and are
		/// usually worth resuming from with a larger `maxIterations`.
		case maxIterations

		/// The objective or its gradient stopped being a number. The returned
		/// parameters are the best point visited before that happened.
		case numericalInstability

		/// The descent left the region where the model is identifiable: `a` and `b`
		/// grew until `1 / (a + b·x)` was numerically zero across the observed range,
		/// where the likelihood surface is flat and the gradient test passes at
		/// parameters that are wrong by any margin you care to name. A diverged fit
		/// predicts the data worse than its own mean does, which is how it is caught.
		case diverged
	}

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

		/// Whether the fit converged.
		///
		/// `true` means all of: the gradient of the per-observation negative
		/// log-likelihood fell below the tolerance, the parameters at that point are
		/// finite, and the fitted model predicts the data better than the best
		/// constant would. Anything else is `false`, and ``terminationReason`` says
		/// which.
		public let converged: Bool

		/// Why the fit stopped.
		///
		/// ``converged`` is `true` exactly when this is
		/// ``ReciprocalRegressionFitter/TerminationReason/converged``.
		public let terminationReason: TerminationReason

		/// Standard errors of parameter estimates (if available)
		public let standardErrors: Parameters?

		/// Creates a fit result with estimated parameters and diagnostics.
		/// - Parameters:
		///   - parameters: Estimated model parameters
		///   - logLikelihood: Log-likelihood at the solution
		///   - negativeLogLikelihood: Negative log-likelihood at the solution, summed
		///     over the data
		///   - iterations: Number of optimization iterations performed
		///   - terminationReason: Why the fit stopped. `converged` is derived from it.
		///   - standardErrors: Standard errors of estimates (optional)
		public init(
			parameters: Parameters,
			logLikelihood: T,
			negativeLogLikelihood: T,
			iterations: Int,
			terminationReason: TerminationReason,
			standardErrors: Parameters? = nil
		) {
			self.parameters = parameters
			self.logLikelihood = logLikelihood
			self.negativeLogLikelihood = negativeLogLikelihood
			self.iterations = iterations
			self.terminationReason = terminationReason
			self.converged = terminationReason == .converged
			self.standardErrors = standardErrors
		}

		/// Creates a fit result from a plain convergence flag.
		///
		/// Retained for callers that construct results themselves. `true` maps to
		/// ``ReciprocalRegressionFitter/TerminationReason/converged`` and `false` to
		/// ``ReciprocalRegressionFitter/TerminationReason/maxIterations``; to record
		/// divergence or instability, use the `terminationReason:` initializer.
		///
		/// - Parameters:
		///   - parameters: Estimated model parameters
		///   - logLikelihood: Log-likelihood at the solution
		///   - negativeLogLikelihood: Negative log-likelihood at the solution
		///   - iterations: Number of optimization iterations performed
		///   - converged: Whether the optimization converged
		///   - standardErrors: Standard errors of estimates (optional)
		public init(
			parameters: Parameters,
			logLikelihood: T,
			negativeLogLikelihood: T,
			iterations: Int,
			converged: Bool,
			standardErrors: Parameters? = nil
		) {
			self.init(
				parameters: parameters,
				logLikelihood: logLikelihood,
				negativeLogLikelihood: negativeLogLikelihood,
				iterations: iterations,
				terminationReason: converged ? .converged : .maxIterations,
				standardErrors: standardErrors
			)
		}
	}
	
	/// Initializes the Fitter
	public init() {}

	/// Fit the model to data using gradient-based optimization.
	///
	/// The descent minimises the **mean** negative log-likelihood rather than the sum.
	/// The gradient of a sum scales with the sample size while `learningRate` does not,
	/// so a step that fits at `n = 50` overshoots at `n = 500` — and what it overshoots
	/// into is the region where `a` and `b` are large enough that `1 / (a + b·x)` is
	/// numerically zero for every observed `x`. That region is flat, so the gradient
	/// test passes there, and the fit was reported as converged while being wrong by
	/// eleven orders of magnitude. Dividing by `n` does not move the optimum; it makes
	/// `learningRate` mean the same thing at every sample size.
	///
	/// `converged` is `true` only when the gradient test passed at finite parameters
	/// **and** the fitted model predicts the data better than the best constant does.
	/// When it is `false`, ``FitResult/parameters`` still carries the best point the
	/// descent visited, and ``FitResult/terminationReason`` says whether that was an
	/// iteration limit, a numerical breakdown, or a run that left the identifiable
	/// region entirely.
	///
	/// - Parameters:
	///   - data: Observed (x, y) data points. Must not be empty.
	///   - initialGuess: Starting parameter values (default: a=0.5, b=0.5, sigma=0.5)
	///   - learningRate: Step size for gradient descent on the per-observation
	///     objective (default: 0.1). The old default of `0.001` was calibrated against
	///     a summed objective at roughly a hundred observations, where it amounted to a
	///     per-observation step of about `0.1`; carried over unchanged it would have
	///     made the fitter a hundred times too slow to fit anything at all. The step
	///     now means the same thing at every sample size, which is the point of the
	///     change.
	///   - maxIterations: Maximum optimization iterations (default: 1000)
	///   - tolerance: Convergence tolerance on the gradient norm (default: 1e-6)
	/// - Returns: Fitted parameters and diagnostic information
	/// - Throws: ``OptimizationError/invalidInput(message:)`` if `data` is empty, or any
	///   error raised by the underlying optimizer.
	public func fit(
		data: [DataPoint],
		initialGuess: Parameters = Parameters(a: T(0.5), b: T(0.5), sigma: T(0.5)),
		learningRate: T = T(0.1),
		maxIterations: Int = 1000,
		tolerance: T = T(1e-6)
	) throws -> FitResult {
		guard !data.isEmpty else {
			throw OptimizationError.invalidInput(message: "Cannot fit a reciprocal regression to no data")
		}

		// IMPORTANT: Optimize in log-space to enforce positivity naturally
		// This avoids max() discontinuities that break numerical gradients
		//
		// We optimize: logParams = [log(a), log(b), log(sigma)]
		// Then transform back: a = exp(logParams[0]), etc.

		let objective: @Sendable (VectorN<T>) -> T = { logParams in
			// Transform from log-space to natural parameters
			// exp() naturally enforces positivity with smooth gradients
			let a = T.exp(logParams[0])
			let b = T.exp(logParams[1])
			let sigma = T.exp(logParams[2])

			let modelParams = Parameters(a: a, b: b, sigma: sigma)
			// Per observation, not summed: the gradient of a sum grows with n while
			// the step size does not, so a fixed learning rate diverges on large data.
			return ReciprocalRegressionModel.meanNegativeLogLikelihood(data: data, params: modelParams)
		}

		// Numerical gradient (now computed in log-space where objective is smooth)
		let gradient: (VectorN<T>) throws -> VectorN<T> = { logParams in
			try numericalGradient(objective, at: logParams, h: T(1e-6))
		}

		// Create optimizer
		let optimizer = MultivariateGradientDescent<VectorN<T>>(
			learningRate: learningRate,
			maxIterations: maxIterations,
			tolerance: tolerance
		)

		// Convert initial guess to log-space
		let initialLogVector = VectorN([
			T.log(initialGuess.a),
			T.log(initialGuess.b),
			T.log(initialGuess.sigma)
		])

		// Optimize in log-space
		let result = try optimizer.minimize(
			function: objective,
			gradient: gradient,
			initialGuess: initialLogVector
		)

		// Transform solution back from log-space to natural parameters
		// Clamp log-space values to prevent overflow/underflow in exp()
		let maxLogValue = T(100)  // exp(100) ≈ 2.7e43 (safely finite)
		let minLogValue = T(-100) // exp(-100) ≈ 3.7e-44 (safely positive)

		let clampedLogA = max(minLogValue, min(maxLogValue, result.solution[0]))
		let clampedLogB = max(minLogValue, min(maxLogValue, result.solution[1]))
		let clampedLogSigma = max(minLogValue, min(maxLogValue, result.solution[2]))

		// Clamping is not a rescue: if it fired, the descent left the range the model
		// can express and the parameters being returned are not the ones the optimizer
		// arrived at. Record that rather than reporting the clamped value as a fit.
		let wasClamped = (0..<3).contains { index in
			let solved = result.solution[index]
			return !solved.isFinite || solved > maxLogValue || solved < minLogValue
		}

		let fittedA = T.exp(clampedLogA)
		let fittedB = T.exp(clampedLogB)
		let fittedSigma = T.exp(clampedLogSigma)

		let fittedParams = Parameters(a: fittedA, b: fittedB, sigma: fittedSigma)

		// Compute log-likelihood
		let logLik = ReciprocalRegressionModel.totalLogLikelihood(data: data, params: fittedParams)

		let reason = Self.terminationReason(
			optimizerConverged: result.converged,
			wasClamped: wasClamped,
			parameters: fittedParams,
			logLikelihood: logLik,
			data: data
		)

		return FitResult(
			parameters: fittedParams,
			logLikelihood: logLik,
			// The optimizer's objective is per-observation; report the summed figure,
			// which is what `logLikelihood` above is the negation of.
			negativeLogLikelihood: -logLik,
			iterations: result.iterations,
			terminationReason: reason
		)
	}

	// MARK: - Convergence

	/// Decides what actually happened, given what the optimizer reported.
	///
	/// The gradient test is a local statement, and the reciprocal model has a region
	/// where it is locally true and globally worthless: as `a` and `b` grow,
	/// `1 / (a + b·x)` goes to zero for every observed `x`, the likelihood stops
	/// depending on either parameter, and the gradient norm falls below any tolerance.
	/// A fit there is not merely imprecise — it is the model having collapsed to a
	/// constant zero mean.
	///
	/// The check is a comparison against the best constant model, `y ~ Normal(ȳ, s)`,
	/// which is the same reciprocal family at `b = 0, a = 1/ȳ`. A fitted model that
	/// cannot beat the mean of the data has not found the relationship, whatever the
	/// gradient says. It costs one pass over the data.
	///
	/// - Parameters:
	///   - optimizerConverged: Whether the gradient norm fell below the tolerance.
	///   - wasClamped: Whether the log-space solution had to be clamped to stay finite.
	///   - parameters: The fitted parameters.
	///   - logLikelihood: Log-likelihood of the data under `parameters`.
	///   - data: The observations that were fitted.
	/// - Returns: The reason to report, from which `converged` is derived.
	private static func terminationReason(
		optimizerConverged: Bool,
		wasClamped: Bool,
		parameters: Parameters,
		logLikelihood: T,
		data: [DataPoint]
	) -> TerminationReason {
		guard parameters.a.isFinite,
			  parameters.b.isFinite,
			  parameters.sigma.isFinite,
			  logLikelihood.isFinite else {
			return .numericalInstability
		}

		guard !wasClamped else { return .diverged }

		if isDegenerate(parameters: parameters, logLikelihood: logLikelihood, data: data) {
			return .diverged
		}

		return optimizerConverged ? .converged : .maxIterations
	}

	/// Whether the fitted model does worse than the mean of the data.
	///
	/// - Parameters:
	///   - parameters: The fitted parameters.
	///   - logLikelihood: Log-likelihood of the data under `parameters`.
	///   - data: The observations that were fitted.
	/// - Returns: `true` when the constant model `y ~ Normal(ȳ, s)` explains the data
	///   strictly better than the fit does, which is the signature of a run that left
	///   the identifiable region. `false` when the comparison cannot be made — a single
	///   observation, a constant `y`, a non-positive mean — since absence of evidence
	///   for divergence is not evidence of it.
	private static func isDegenerate(
		parameters: Parameters,
		logLikelihood: T,
		data: [DataPoint]
	) -> Bool {
		guard data.count > 1 else { return false }

		let n = T(data.count)
		let yMean = data.reduce(T(0)) { $0 + $1.y } / n
		let squaredDeviation = data.reduce(T(0)) { sum, point in
			let deviation = point.y - yMean
			return sum + deviation * deviation
		}
		let standardDeviation = T.sqrt(squaredDeviation / n)

		// The constant model is only in this family for a positive mean, and a sample
		// with no spread gives it infinite likelihood. Neither is a divergence.
		guard yMean > T(0), standardDeviation > T(0) else { return false }

		let constantModel = Parameters(a: T(1) / yMean, b: T(0), sigma: standardDeviation)
		let constantLogLikelihood = ReciprocalRegressionModel.totalLogLikelihood(
			data: data,
			params: constantModel
		)

		guard constantLogLikelihood.isFinite else { return false }

		return logLikelihood < constantLogLikelihood
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

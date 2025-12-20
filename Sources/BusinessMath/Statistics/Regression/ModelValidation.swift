//
//  ModelValidation.swift
//  BusinessMath
//
//  Model validation framework for checking parameter recovery in fake-data simulation.
//  Implements the "quick-and-dirty" simulation-based calibration (SBC) workflow
//  described by Andrew Gelman.
//
//  Reference: https://statmodeling.stat.columbia.edu/2025/12/15/simulating-from-and-checking-a-model-in-stan/
//

import Foundation
import Numerics

// MARK: - Parameter Recovery Validation

/// Validates a statistical model's fitting procedure by checking parameter recovery from simulated data.
///
/// # Workflow
/// 1. Specify true parameter values
/// 2. Simulate fake data from the model with those parameters
/// 3. Fit the model to the simulated data
/// 4. Compare recovered parameters to true parameters
/// 5. Check if differences are within acceptable bounds
///
/// This is a "sanity check" for model fitting:
/// - If you **can't** recover parameters from your own simulated data, something is wrong
///   (poor identification, mixing issues, coding bugs, algorithmic problems)
/// - If you **can** recover parameters, that doesn't guarantee the model is good,
///   but it's a necessary minimum requirement
///
/// # Example
/// ```swift
/// let validator = ParameterRecoveryValidator<Double>()
///
/// // Define true parameters
/// let trueParams = ReciprocParam Recovery Validation

/// Validates a statistical model's fitting procedure by checking parameter recovery from simulated data.
///
/// # Workflow
/// 1. Specify true parameter values
/// 2. Simulate fake data from the model with those parameters
/// 3. Fit the model to the simulated data
/// 4. Compare recovered parameters to true parameters
/// 5. Check if differences are within acceptable bounds
///
/// This is a "sanity check" for model fitting:
/// - If you **can't** recover parameters from your own simulated data, something is wrong
///   (poor identification, mixing issues, coding bugs, algorithmic problems)
/// - If you **can** recover parameters, that doesn't guarantee the model is good,
///   but it's a necessary minimum requirement
///
/// # Example
/// ```swift
/// // Simulate and validate
/// let report = try ReciprocParameterRecoveryCheck.run(
///     trueA: 0.2,
///     trueB: 0.3,
///     trueSigma: 0.2,
///     n: 100,
///     xRange: 0.0...10.0
/// )
///
/// print(report.summary)
/// // Shows whether each parameter was recovered within tolerance
/// ```
public struct ParameterRecoveryReport<T: Real & Sendable & Codable>: Sendable where T: BinaryFloatingPoint {
	/// True parameter values used for simulation
	public let trueParameters: [String: T]

	/// Recovered parameter values from fitting
	public let recoveredParameters: [String: T]

	/// Absolute errors: |recovered - true|
	public let absoluteErrors: [String: T]

	/// Relative errors: |recovered - true| / |true|
	public let relativeErrors: [String: T]

	/// Was each parameter recovered within tolerance?
	public let withinTolerance: [String: Bool]

	/// Tolerance used for validation
	public let tolerance: T

	/// Number of observations in simulated data
	public let sampleSize: Int

	/// Fitting diagnostics
	public let converged: Bool
	public let iterations: Int
	public let logLikelihood: T

	public init(
		trueParameters: [String: T],
		recoveredParameters: [String: T],
		absoluteErrors: [String: T],
		relativeErrors: [String: T],
		withinTolerance: [String: Bool],
		tolerance: T,
		sampleSize: Int,
		converged: Bool,
		iterations: Int,
		logLikelihood: T
	) {
		self.trueParameters = trueParameters
		self.recoveredParameters = recoveredParameters
		self.absoluteErrors = absoluteErrors
		self.relativeErrors = relativeErrors
		self.withinTolerance = withinTolerance
		self.tolerance = tolerance
		self.sampleSize = sampleSize
		self.converged = converged
		self.iterations = iterations
		self.logLikelihood = logLikelihood
	}

	/// Overall validation result: true if all parameters recovered within tolerance
	public var passed: Bool {
		withinTolerance.values.allSatisfy { $0 }
	}

	/// Human-readable summary of validation results
	@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
	public var summary: String {
		var result = "Parameter Recovery Validation\n"
		result += "==============================\n\n"

		result += "Sample Size: \(sampleSize)\n"
		result += "Converged: \(converged ? "Yes" : "No")\n"
		result += "Iterations: \(iterations)\n"
		result += "Log-Likelihood: \(logLikelihood.number())\n"
		result += "Tolerance: \(tolerance.number())\n\n"

		result += "Parameter Recovery:\n"
		result += "-------------------\n"

		let paramNames = Array(trueParameters.keys).sorted()
		for name in paramNames {
			guard let trueValue = trueParameters[name],
				  let recoveredValue = recoveredParameters[name],
				  let absError = absoluteErrors[name],
				  let relError = relativeErrors[name],
				  let within = withinTolerance[name] else { continue }

			let status = within ? "✓ PASS" : "✗ FAIL"
			result += "\n\(name):\n"
			result += "  True:      \(trueValue.number())\n"
			result += "  Recovered: \(recoveredValue.number())\n"
			result += "  Abs Error: \(absError.magnitude)\n"
			result += "  Rel Error: \(Double(relError * 100).number())%\n"
			result += "  Status:    \(status)\n"
		}

		result += "\n" + String(repeating: "=", count: 30) + "\n"
		result += "Overall: \(passed ? "✓ ALL PARAMETERS RECOVERED" : "✗ RECOVERY FAILED")\n"

		return result
	}
}

// MARK: - Reciprocal Model Validation

/// Specific validation for the reciprocal regression model.
///
/// Provides a convenient interface for the fake-data simulation workflow
/// described in Gelman's blog post.
///
/// # Example
/// ```swift
/// // Run validation with default settings
/// let report = try ReciprocalParameterRecoveryCheck.run(
///     trueA: 0.2,
///     trueB: 0.3,
///     trueSigma: 0.2
/// )
///
/// if report.passed {
///     print("✓ Model fitting procedure is working correctly!")
/// } else {
///     print("✗ Warning: Failed to recover parameters from simulated data")
///     print(report.summary)
/// }
/// ```
public struct ReciprocalParameterRecoveryCheck {
	/// Run a parameter recovery check for the reciprocal regression model
	/// - Parameters:
	///   - trueA: True intercept parameter
	///   - trueB: True slope parameter
	///   - trueSigma: True residual standard deviation
	///   - n: Number of observations to simulate (default: 100)
	///   - xRange: Range for x values (default: 0...10)
	///   - tolerance: Relative tolerance for parameter recovery (default: 0.1 = 10%)
	///   - learningRate: Optimization learning rate (default: 0.001)
	///   - maxIterations: Maximum optimization iterations (default: 1000)
	/// - Returns: Detailed validation report
	/// - Throws: Optimization errors if fitting fails
	public static func run<T: Real & Sendable & Codable>(
		trueA: T,
		trueB: T,
		trueSigma: T,
		n: Int = 100,
		xRange: ClosedRange<T> = T(0)...T(10),
		tolerance: T = T(0.1),
		learningRate: T = T(0.001),
		maxIterations: Int = 1000
	) throws -> ParameterRecoveryReport<T> where T: BinaryFloatingPoint {
		// Step 1: Simulate data with true parameters
		let simulator = ReciprocalRegressionSimulator<T>(a: trueA, b: trueB, sigma: trueSigma)
		let data = simulator.simulate(n: n, xRange: xRange)

		// Step 2: Fit the model to recover parameters
		let fitter = ReciprocalRegressionFitter<T>()
		let fitResult = try fitter.fit(
			data: data,
			initialGuess: ReciprocalRegressionModel<T>.Parameters(a: T(0.5), b: T(0.5), sigma: T(0.5)),
			learningRate: learningRate,
			maxIterations: maxIterations
		)

		// Step 3: Compare true vs recovered parameters
		let trueParams: [String: T] = [
			"a": trueA,
			"b": trueB,
			"sigma": trueSigma
		]

		let recoveredParams: [String: T] = [
			"a": fitResult.parameters.a,
			"b": fitResult.parameters.b,
			"sigma": fitResult.parameters.sigma
		]

		var absoluteErrors: [String: T] = [:]
		var relativeErrors: [String: T] = [:]
		var withinTolerance: [String: Bool] = [:]

		for (name, trueValue) in trueParams {
			guard let recoveredValue = recoveredParams[name] else { continue }

			let absError = abs(recoveredValue - trueValue)
			let relError = absError / abs(trueValue)

			absoluteErrors[name] = absError
			relativeErrors[name] = relError
			withinTolerance[name] = relError <= tolerance
		}

		return ParameterRecoveryReport(
			trueParameters: trueParams,
			recoveredParameters: recoveredParams,
			absoluteErrors: absoluteErrors,
			relativeErrors: relativeErrors,
			withinTolerance: withinTolerance,
			tolerance: tolerance,
			sampleSize: n,
			converged: fitResult.converged,
			iterations: fitResult.iterations,
			logLikelihood: fitResult.logLikelihood
		)
	}

	/// Run multiple parameter recovery checks with different random seeds
	/// - Parameters:
	///   - trueA: True intercept parameter
	///   - trueB: True slope parameter
	///   - trueSigma: True residual standard deviation
	///   - replicates: Number of independent simulations (default: 10)
	///   - n: Number of observations per simulation (default: 100)
	///   - xRange: Range for x values
	///   - tolerance: Relative tolerance for parameter recovery
	/// - Returns: Array of validation reports, one per replicate
	public static func runMultiple<T: Real & Sendable & Codable>(
		trueA: T,
		trueB: T,
		trueSigma: T,
		replicates: Int = 10,
		n: Int = 100,
		xRange: ClosedRange<T> = T(0)...T(10),
		tolerance: T = T(0.1)
	) throws -> [ParameterRecoveryReport<T>] where T: BinaryFloatingPoint {
		var reports: [ParameterRecoveryReport<T>] = []

		for _ in 0..<replicates {
			let report = try run(
				trueA: trueA,
				trueB: trueB,
				trueSigma: trueSigma,
				n: n,
				xRange: xRange,
				tolerance: tolerance
			)
			reports.append(report)
		}

		return reports
	}

	/// Summarize results from multiple replicates
	/// - Parameter reports: Array of validation reports
	/// - Returns: Summary statistics across replicates
	public static func summarizeReplicates<T: Real & Sendable & Codable>(
		_ reports: [ParameterRecoveryReport<T>]
	) -> String where T: BinaryFloatingPoint {
		guard !reports.isEmpty else {
			return "No reports to summarize"
		}

		let passCount = reports.filter { $0.passed }.count
		let passRate = Double(passCount) / Double(reports.count)

		var summary = "Parameter Recovery: Multiple Replicates Summary\n"
		summary += "===============================================\n\n"
		summary += "Replicates: \(reports.count)\n"
		summary += "Passed: \(passCount) (\(String(format: "%.1f%%", passRate * 100)))\n"
		summary += "Failed: \(reports.count - passCount)\n\n"

		// Average errors by parameter
		let paramNames = Array(reports[0].trueParameters.keys).sorted()
		summary += "Average Relative Errors:\n"
		summary += "------------------------\n"

		for name in paramNames {
			let avgRelError = reports.compactMap { $0.relativeErrors[name] }
				.reduce(T(0), +) / T(reports.count)
			summary += "\(name): \(String(format: "%.2f%%", Double(avgRelError) * 100))\n"
		}

		return summary
	}
}

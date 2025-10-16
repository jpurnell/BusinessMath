//
//  SimulationError.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation

/// Errors that can occur during Monte Carlo simulation execution.
///
/// ## Error Cases
///
/// - `insufficientIterations`: The number of iterations is too low (must be > 0)
/// - `noInputs`: No uncertain input variables have been defined
/// - `invalidModel`: The model function failed or produced invalid results
/// - `correlationDimensionMismatch`: The correlation matrix dimensions don't match the number of inputs
/// - `invalidCorrelationMatrix`: The correlation matrix is not valid (not symmetric, not positive definite, etc.)
public enum SimulationError: Error, Sendable {
	/// The simulation has insufficient iterations.
	///
	/// Monte Carlo simulations require at least one iteration.
	/// More iterations (typically 1,000-10,000+) provide more accurate results.
	case insufficientIterations

	/// The simulation has no input variables defined.
	///
	/// At least one input variable must be added using `addInput(_:)` before running the simulation.
	case noInputs

	/// The model function produced an invalid result.
	///
	/// This can occur if the model function:
	/// - Returns NaN (Not a Number)
	/// - Returns Inf (Infinity)
	/// - Throws an error during execution
	///
	/// - Parameters:
	///   - iteration: The iteration number where the error occurred
	///   - details: Additional information about what went wrong
	case invalidModel(iteration: Int, details: String)

	/// The correlation matrix dimensions don't match the number of input variables.
	///
	/// For n input variables, the correlation matrix must be n×n.
	case correlationDimensionMismatch

	/// The provided correlation matrix is not valid.
	///
	/// A valid correlation matrix must be:
	/// - Square (n×n)
	/// - Symmetric (matrix[i][j] == matrix[j][i])
	/// - Unit diagonal (matrix[i][i] == 1.0)
	/// - Bounded values (-1.0 ≤ matrix[i][j] ≤ 1.0)
	/// - Positive semi-definite (all eigenvalues ≥ 0)
	case invalidCorrelationMatrix
}

extension SimulationError: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .insufficientIterations:
			return "Monte Carlo simulation requires at least 1 iteration"
		case .noInputs:
			return "Monte Carlo simulation requires at least 1 input variable"
		case .invalidModel(let iteration, let details):
			return "Model function produced invalid result at iteration \(iteration): \(details)"
		case .correlationDimensionMismatch:
			return "Correlation matrix dimensions must match the number of input variables"
		case .invalidCorrelationMatrix:
			return "Correlation matrix is not valid (must be symmetric, positive semi-definite, with unit diagonal)"
		}
	}
}

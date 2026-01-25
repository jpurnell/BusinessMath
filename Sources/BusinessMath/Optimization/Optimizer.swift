//
//  Optimizer.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

// MARK: - IterationHistory

/// Records information about a single iteration of an optimization algorithm.
public struct IterationHistory<T: Real & Sendable & Codable>: Sendable {
	/// The iteration number.
	public let iteration: Int

	/// The value at this iteration.
	public let value: T

	/// The objective function value at this iteration.
	public let objective: T

	/// The gradient or derivative at this iteration.
	public let gradient: T

	/// Creates an iteration history record.
	///
	/// - Parameters:
	///   - iteration: The iteration number.
	///   - value: The value at this iteration.
	///   - objective: The objective function value.
	///   - gradient: The gradient or derivative.
	public init(iteration: Int, value: T, objective: T, gradient: T) {
		self.iteration = iteration
		self.value = value
		self.objective = objective
		self.gradient = gradient
	}
}

// MARK: - OptimizationResult

/// The result of an optimization algorithm.
///
/// `OptimizationResult` contains the optimal value found, the objective function
/// value at that point, convergence information, and the iteration history.
///
/// ## Example
///
/// ```swift
/// let result = optimizer.optimize(objective: f, initialGuess: 0.0)
///
/// if result.converged {
///     print("Found minimum: \(result.optimalValue)")
///     print("Objective value: \(result.objectiveValue)")
///     print("Iterations: \(result.iterations)")
/// }
/// ```
public struct OptimizationResult<T: Real & Sendable & Codable>: Sendable {
	/// The optimal value found.
	public let optimalValue: T

	/// The objective function value at the optimal point.
	public let objectiveValue: T

	/// The number of iterations performed.
	public let iterations: Int

	/// Whether the algorithm converged.
	public let converged: Bool

	/// The iteration history.
	public let history: [IterationHistory<T>]

	/// Creates an optimization result.
	///
	/// - Parameters:
	///   - optimalValue: The optimal value found.
	///   - objectiveValue: The objective function value at the optimal point.
	///   - iterations: The number of iterations performed.
	///   - converged: Whether the algorithm converged.
	///   - history: The iteration history.
	public init(
		optimalValue: T,
		objectiveValue: T,
		iterations: Int,
		converged: Bool,
		history: [IterationHistory<T>] = []
	) {
		self.optimalValue = optimalValue
		self.objectiveValue = objectiveValue
		self.iterations = iterations
		self.converged = converged
		self.history = history
	}

	/// A human-readable description of the result.
	public var description: String {
		var result = "Optimization Result\n"
		result += "==================\n"
		result += "Optimal Value: \(optimalValue)\n"
		result += "Objective: \(objectiveValue)\n"
		result += "Iterations: \(iterations)\n"
		result += "Converged: \(converged ? "Yes" : "No")\n"

		if !history.isEmpty {
			result += "\nIteration History:\n"
			for record in history.prefix(5) {
				result += "  [\(record.iteration)] value=\(record.value), obj=\(record.objective), grad=\(record.gradient)\n"
			}
			if history.count > 5 {
				result += "  ... (\(history.count - 5) more iterations)\n"
			}
		}

		return result
	}
}

// MARK: - ConstraintType

/// The type of constraint in an optimization problem.
public enum ConstraintType: Sendable {
	/// Value must be less than the bound.
	case lessThan

	/// Value must be less than or equal to the bound.
	case lessThanOrEqual

	/// Value must be greater than the bound.
	case greaterThan

	/// Value must be greater than or equal to the bound.
	case greaterThanOrEqual

	/// Value must equal the bound (within tolerance).
	case equalTo
}

// MARK: - Constraint

/// A constraint in an optimization problem.
///
/// `Constraint` defines a condition that the optimal value must satisfy.
/// It can apply to the value directly, or to a function of the value.
///
/// ## Example
///
/// ```swift
/// // Simple constraint: x >= 0
/// let nonNegative = Constraint<Double>(type: .greaterThanOrEqual, bound: 0.0)
///
/// // Function constraint: x^2 < 100
/// let squared = Constraint<Double>(
///     type: .lessThan,
///     bound: 100.0,
///     function: { $0 * $0 }
/// )
/// ```
public struct Constraint<T: Real & Sendable & Codable>: Sendable {
	/// The type of constraint.
	public let type: ConstraintType

	/// The bound value.
	public let bound: T

	/// Optional function to apply to the value before checking the constraint.
	public let function: (@Sendable (T) -> T)?

	/// Tolerance for equality constraints.
	public let tolerance: T

	/// Creates a constraint.
	///
	/// - Parameters:
	///   - type: The type of constraint.
	///   - bound: The bound value.
	///   - function: Optional function to apply before checking. Defaults to identity.
	///   - tolerance: Tolerance for equality constraints. Defaults to 0.0001.
	public init(
		type: ConstraintType,
		bound: T,
		function: (@Sendable (T) -> T)? = nil,
		tolerance: T = 0.0001
	) {
		self.type = type
		self.bound = bound
		self.function = function
		self.tolerance = tolerance
	}

	/// Checks if a value satisfies the constraint.
	///
	/// - Parameter value: The value to check.
	/// - Returns: True if the constraint is satisfied, false otherwise.
	public func isSatisfied(_ value: T) -> Bool {
		let checkValue = function?(value) ?? value

		switch type {
		case .lessThan:
			return checkValue < bound

		case .lessThanOrEqual:
			return checkValue <= bound

		case .greaterThan:
			return checkValue > bound

		case .greaterThanOrEqual:
			return checkValue >= bound

		case .equalTo:
			return abs(checkValue - bound) <= tolerance
		}
	}
}

// MARK: - Optimizer Protocol

/// Protocol for optimization algorithms.
///
/// `Optimizer` defines the interface for optimization algorithms that find
/// values minimizing or maximizing an objective function, subject to constraints.
///
/// ## Example Implementation
///
/// ```swift
/// struct MyOptimizer<T: Real>: Optimizer {
///     func optimize(
///         objective: @escaping (T) -> T,
///         constraints: [Constraint<T>],
///         initialGuess: T,
///         bounds: (lower: T, upper: T)?
///     ) -> OptimizationResult<T> {
///         // Implementation here
///     }
/// }
/// ```
public protocol Optimizer {
	associatedtype T: Real & Sendable & Codable

	/// Optimizes an objective function.
	///
	/// - Parameters:
	///   - objective: The objective function to minimize.
	///   - constraints: Constraints that the solution must satisfy.
	///   - initialGuess: The starting value for the optimization.
	///   - bounds: Optional bounds for the value (lower, upper).
	/// - Returns: The optimization result.
	func optimize(
		objective: @escaping (T) -> T,
		constraints: [Constraint<T>],
		initialGuess: T,
		bounds: (lower: T, upper: T)?
	) -> OptimizationResult<T>
}

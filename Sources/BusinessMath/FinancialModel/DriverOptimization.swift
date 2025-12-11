//
//  DriverOptimization.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation
import Numerics

// MARK: - Optimizable Driver

/// Represents an operational driver that can be optimized.
///
/// ## Example
/// ```swift
/// let driver = OptimizableDriver(
///     name: "conversion_rate",
///     currentValue: 0.025,
///     range: 0.01...0.05,
///     changeConstraint: .percentageChange(max: 0.20)  // Max 20% change
/// )
/// ```
public struct OptimizableDriver: Sendable {
	/// Driver name (e.g., "conversion_rate", "churn_rate")
	public let name: String

	/// Current/baseline value
	public let currentValue: Double

	/// Feasible range for this driver
	public let range: ClosedRange<Double>

	/// Optional constraint on how much the driver can change
	public let changeConstraint: DriverChangeConstraint?

	/// Creates an optimizable driver.
	public init(
		name: String,
		currentValue: Double,
		range: ClosedRange<Double>,
		changeConstraint: DriverChangeConstraint? = nil
	) {
		self.name = name
		self.currentValue = currentValue
		self.range = range
		self.changeConstraint = changeConstraint
	}
}

// MARK: - Driver Change Constraint

/// Constraint on how much a driver can change from its current value.
public enum DriverChangeConstraint: Sendable {
	/// Absolute change limit: |new - current| ≤ max
	case absoluteChange(max: Double)

	/// Percentage change limit: |new/current - 1| ≤ max
	case percentageChange(max: Double)

	/// Step size for granular changes (e.g., 0.001)
	case stepSize(Double)
}

// MARK: - Financial Target

/// A financial metric target to achieve.
///
/// ## Example
/// ```swift
/// let target = FinancialTarget(
///     metric: "revenue",
///     target: .minimum(1_000_000),
///     weight: 1.0
/// )
/// ```
public struct FinancialTarget {
	/// Metric name (e.g., "revenue", "EBITDA", "FCF")
	public let metric: String

	/// Target value or range
	public let target: TargetValue

	/// Weight for multi-objective optimization (higher = more important)
	public let weight: Double

	/// Creates a financial target.
	public init(
		metric: String,
		target: TargetValue,
		weight: Double = 1.0
	) {
		self.metric = metric
		self.target = target
		self.weight = weight
	}
}

// MARK: - Target Value

/// Target value specification for a financial metric.
public enum TargetValue {
	/// Exact target value
	case exact(Double)

	/// Minimum acceptable value
	case minimum(Double)

	/// Maximum acceptable value
	case maximum(Double)

	/// Target range (min, max)
	case range(Double, Double)
}

// MARK: - Driver Objective

/// Objective function for driver optimization.
public enum DriverObjective {
	/// Minimize changes to drivers (target seeking)
	case minimizeChange

	/// Minimize weighted cost of changes
	case minimizeCost([String: Double])  // driverName -> costPerUnitChange

	/// Maximize feasibility (soft penalties for missing targets)
	case maximizeFeasibility

	/// Custom objective
	case custom(([String: Double]) -> Double)  // driverValues -> score
}

// MARK: - Driver Optimization Result

/// Result from driver optimization.
public struct DriverOptimization {
	/// Optimized driver values
	public let optimizedDrivers: [String: Double]

	/// Changes from current values
	public let driverChanges: [String: Double]

	/// Achieved metric values with optimized drivers
	public let achievedMetrics: [String: Double]

	/// Whether each target was fulfilled
	public let targetsFulfilled: [String: Bool]

	/// Whether all targets are feasible
	public let feasible: Bool

	/// Whether optimization converged
	public let converged: Bool

	/// Number of iterations
	public let iterations: Int

	/// Creates a driver optimization result.
	public init(
		optimizedDrivers: [String: Double],
		driverChanges: [String: Double],
		achievedMetrics: [String: Double],
		targetsFulfilled: [String: Bool],
		feasible: Bool,
		converged: Bool,
		iterations: Int
	) {
		self.optimizedDrivers = optimizedDrivers
		self.driverChanges = driverChanges
		self.achievedMetrics = achievedMetrics
		self.targetsFulfilled = targetsFulfilled
		self.feasible = feasible
		self.converged = converged
		self.iterations = iterations
	}
}

// MARK: - Driver Optimizer

/// Optimizer for finding driver values that achieve financial targets.
///
/// Solves target-seeking problems by optimizing operational drivers to hit
/// financial goals while minimizing changes from current values.
///
/// ## Example
/// ```swift
/// let drivers = [
///     OptimizableDriver(
///         name: "price",
///         currentValue: 100,
///         range: 80...120,
///         changeConstraint: .percentageChange(max: 0.15)
///     ),
///     OptimizableDriver(
///         name: "volume",
///         currentValue: 1000,
///         range: 800...1500
///     )
/// ]
///
/// let targets = [
///     FinancialTarget(
///         metric: "revenue",
///         target: .minimum(120_000),
///         weight: 1.0
///     )
/// ]
///
/// let optimizer = DriverOptimizer()
/// let result = try optimizer.optimize(
///     drivers: drivers,
///     targets: targets,
///     model: { driverValues in
///         let price = driverValues["price"]!
///         let volume = driverValues["volume"]!
///         return ["revenue": price * volume]
///     }
/// )
///
/// print("Optimized drivers: \(result.optimizedDrivers)")
/// print("Revenue: \(result.achievedMetrics["revenue"]!)")
/// ```
public struct DriverOptimizer {

	/// Maximum iterations for optimization
	public let maxIterations: Int

	/// Creates a driver optimizer.
	public init(maxIterations: Int = 200) {
		self.maxIterations = maxIterations
	}

	// MARK: - Public API

	/// Optimize driver values to achieve financial targets.
	///
	/// - Parameters:
	///   - drivers: Array of optimizable drivers
	///   - targets: Array of financial targets to achieve
	///   - model: Model function that maps driver values to metrics
	///   - objective: Objective function (default: .minimizeChange)
	/// - Returns: Optimal driver values and achieved metrics
	/// - Throws: `OptimizationError` if optimization fails
	public func optimize(
		drivers: [OptimizableDriver],
		targets: [FinancialTarget],
		model: @escaping ([String: Double]) -> [String: Double],
		objective: DriverObjective = .minimizeChange
	) throws -> DriverOptimization {

		guard !drivers.isEmpty else {
			throw OptimizationError.invalidInput(message: "No drivers provided")
		}

		guard !targets.isEmpty else {
			throw OptimizationError.invalidInput(message: "No targets provided")
		}

		// Build objective function
		let objectiveFunction = buildObjectiveFunction(
			drivers: drivers,
			targets: targets,
			model: model,
			objective: objective
		)

		// Build constraints
		let constraints = buildConstraints(drivers: drivers)

		// Initial guess: start from current values
		let initialValues = buildInitialValues(drivers: drivers)

		// Run optimization (minimize objective)
		let optimizer = InequalityOptimizer<VectorN<Double>>(maxIterations: maxIterations)
		let result = try optimizer.minimize(
			objectiveFunction,
			from: initialValues,
			subjectTo: constraints
		)

		// Build result
		return buildResult(
			drivers: drivers,
			targets: targets,
			values: result.solution,
			model: model,
			converged: result.converged,
			iterations: result.iterations
		)
	}

	// MARK: - Private Helpers

	private func buildObjectiveFunction(
		drivers: [OptimizableDriver],
		targets: [FinancialTarget],
		model: @escaping ([String: Double]) -> [String: Double],
		objective: DriverObjective
	) -> (VectorN<Double>) -> Double {

		switch objective {
		case .minimizeChange:
			return { values in
				// Sum of squared normalized changes: Σ((new - current) / current)²
				var totalChange = 0.0
				for (i, driver) in drivers.enumerated() {
					let change = values[i] - driver.currentValue
					let normalizedChange = change / max(abs(driver.currentValue), 1e-6)
					totalChange += normalizedChange * normalizedChange
				}

				// Add soft penalty for missing targets
				let penalty = self.calculateTargetPenalty(
					values: values,
					drivers: drivers,
					targets: targets,
					model: model
				)

				return totalChange + 100.0 * penalty  // Heavy penalty for missing targets
			}

		case .minimizeCost(let costs):
			return { values in
				// Weighted sum of absolute changes
				var totalCost = 0.0
				for (i, driver) in drivers.enumerated() {
					let change = abs(values[i] - driver.currentValue)
					let cost = costs[driver.name] ?? 1.0
					totalCost += change * cost
				}

				// Add soft penalty for missing targets (high weight to ensure feasibility)
				let penalty = self.calculateTargetPenalty(
					values: values,
					drivers: drivers,
					targets: targets,
					model: model
				)

				return totalCost + 10000.0 * penalty
			}

		case .maximizeFeasibility:
			return { values in
				// Just the penalty (minimize penalty = maximize feasibility)
				self.calculateTargetPenalty(
					values: values,
					drivers: drivers,
					targets: targets,
					model: model
				)
			}

		case .custom(let customFunction):
			return { values in
				let driverDict = self.buildDriverDictionary(drivers: drivers, values: values)
				return customFunction(driverDict)
			}
		}
	}

	private func calculateTargetPenalty(
		values: VectorN<Double>,
		drivers: [OptimizableDriver],
		targets: [FinancialTarget],
		model: @escaping ([String: Double]) -> [String: Double]
	) -> Double {

		let driverDict = buildDriverDictionary(drivers: drivers, values: values)
		let metrics = model(driverDict)

		var penalty = 0.0

		for target in targets {
			guard let actual = metrics[target.metric] else {
				penalty += 1000.0 * target.weight  // Large penalty for missing metric
				continue
			}

			let violation: Double
			switch target.target {
			case .exact(let value):
				violation = abs(actual - value) / max(abs(value), 1.0)
			case .minimum(let value):
				violation = max(0, value - actual) / max(abs(value), 1.0)
			case .maximum(let value):
				violation = max(0, actual - value) / max(abs(value), 1.0)
			case .range(let minValue, let maxValue):
				if actual < minValue {
					violation = (minValue - actual) / max(abs(minValue), 1.0)
				} else if actual > maxValue {
					violation = (actual - maxValue) / max(abs(maxValue), 1.0)
				} else {
					violation = 0
				}
			}

			penalty += violation * violation * target.weight
		}

		return penalty
	}

	private func buildConstraints(
		drivers: [OptimizableDriver]
	) -> [MultivariateConstraint<VectorN<Double>>] {

		var constraints: [MultivariateConstraint<VectorN<Double>>] = []

		// Range constraints for each driver
		for (i, driver) in drivers.enumerated() {
			// Lower bound: x[i] ≥ range.lowerBound  =>  range.lowerBound - x[i] ≤ 0
			constraints.append(.inequality { values in
				driver.range.lowerBound - values[i]
			})

			// Upper bound: x[i] ≤ range.upperBound  =>  x[i] - range.upperBound ≤ 0
			constraints.append(.inequality { values in
				values[i] - driver.range.upperBound
			})
		}

		// Change constraints
		for (i, driver) in drivers.enumerated() {
			guard let changeConstraint = driver.changeConstraint else { continue }

			switch changeConstraint {
			case .absoluteChange(let max):
				// |new - current| ≤ max
				// Enforce as two constraints:
				// new - current ≤ max  =>  new - current - max ≤ 0
				constraints.append(.inequality { values in
					values[i] - driver.currentValue - max
				})
				// current - new ≤ max  =>  current - new - max ≤ 0
				constraints.append(.inequality { values in
					driver.currentValue - values[i] - max
				})

			case .percentageChange(let max):
				// |new/current - 1| ≤ max
				// new/current ≤ 1 + max  =>  new ≤ current * (1 + max)
				constraints.append(.inequality { values in
					values[i] - driver.currentValue * (1.0 + max)
				})
				// new/current ≥ 1 - max  =>  new ≥ current * (1 - max)
				constraints.append(.inequality { values in
					driver.currentValue * (1.0 - max) - values[i]
				})

			case .stepSize:
				// Step size constraints require integer programming - not supported
				// Ignore for continuous optimization
				break
			}
		}

		return constraints
	}

	private func buildInitialValues(drivers: [OptimizableDriver]) -> VectorN<Double> {
		// Start from current values (likely feasible)
		let values = drivers.map { $0.currentValue }
		return VectorN(values)
	}

	private func buildDriverDictionary(
		drivers: [OptimizableDriver],
		values: VectorN<Double>
	) -> [String: Double] {
		var dict: [String: Double] = [:]
		for (i, driver) in drivers.enumerated() {
			dict[driver.name] = values[i]
		}
		return dict
	}

	private func buildResult(
		drivers: [OptimizableDriver],
		targets: [FinancialTarget],
		values: VectorN<Double>,
		model: ([String: Double]) -> [String: Double],
		converged: Bool,
		iterations: Int
	) -> DriverOptimization {

		// Build driver dictionaries
		let optimizedDrivers = buildDriverDictionary(drivers: drivers, values: values)

		var driverChanges: [String: Double] = [:]
		for (i, driver) in drivers.enumerated() {
			driverChanges[driver.name] = values[i] - driver.currentValue
		}

		// Run model with optimized drivers
		let achievedMetrics = model(optimizedDrivers)

		// Check target fulfillment
		var targetsFulfilled: [String: Bool] = [:]
		var allFeasible = true

		for target in targets {
			guard let actual = achievedMetrics[target.metric] else {
				targetsFulfilled[target.metric] = false
				allFeasible = false
				continue
			}

			let fulfilled: Bool
			switch target.target {
			case .exact(let value):
				// Allow 1% tolerance for "exact"
				fulfilled = abs(actual - value) / max(abs(value), 1.0) < 0.01
			case .minimum(let value):
				fulfilled = actual >= value * 0.99  // 1% tolerance
			case .maximum(let value):
				fulfilled = actual <= value * 1.01  // 1% tolerance
			case .range(let minValue, let maxValue):
				fulfilled = actual >= minValue * 0.99 && actual <= maxValue * 1.01
			}

			targetsFulfilled[target.metric] = fulfilled
			if !fulfilled {
				allFeasible = false
			}
		}

		return DriverOptimization(
			optimizedDrivers: optimizedDrivers,
			driverChanges: driverChanges,
			achievedMetrics: achievedMetrics,
			targetsFulfilled: targetsFulfilled,
			feasible: allFeasible,
			converged: converged,
			iterations: iterations
		)
	}
}

//
//  ResourceAllocation.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation
import Numerics

// MARK: - Allocation Option

/// Represents a project, investment, or option to allocate resources to.
///
/// ## Example
/// ```swift
/// let project = AllocationOption(
///     id: "proj1",
///     name: "New Product Launch",
///     expectedValue: 500_000,  // Expected NPV
///     resourceRequirements: ["budget": 100_000, "headcount": 3],
///     strategicValue: 8.5
/// )
/// ```
public struct AllocationOption: Sendable{
	/// Unique identifier
	public let id: String

	/// Human-readable name
	public let name: String

	/// Expected value (NPV, ROI, revenue, or other metric to maximize)
	public let expectedValue: Double

	/// Resources required by this option (e.g., "budget": 100000, "headcount": 5)
	public let resourceRequirements: [String: Double]

	/// Optional strategic importance score (0-10 scale)
	public let strategicValue: Double?

	/// IDs of options that must be selected before this one
	public let dependencies: Set<String>?

	/// Creates an allocation option.
	public init(
		id: String,
		name: String,
		expectedValue: Double,
		resourceRequirements: [String: Double],
		strategicValue: Double? = nil,
		dependencies: Set<String>? = nil
	) {
		self.id = id
		self.name = name
		self.expectedValue = expectedValue
		self.resourceRequirements = resourceRequirements
		self.strategicValue = strategicValue
		self.dependencies = dependencies
	}
}

// MARK: - Allocation Constraints

/// Constraints for resource allocation optimization.
public enum AllocationConstraint: Sendable {
	/// Maximum total budget across all options
	case totalBudget(Double)

	/// Maximum limit for a specific resource
	case resourceLimit(resource: String, limit: Double)

	/// Minimum allocation amount for a specific option
	case minimumAllocation(optionId: String, amount: Double)

	/// Maximum allocation amount for a specific option
	case maximumAllocation(optionId: String, amount: Double)

	/// Option must be selected (allocated > 0)
	case requiredOption(optionId: String)

	/// Option cannot be selected (allocated = 0)
	case excludedOption(optionId: String)

	/// If option A is selected, option B must also be selected (dependency)
	case dependency(optionId: String, requires: String)

	/// Only one option from the given set can be selected
	case mutuallyExclusive([String])
}

// MARK: - Allocation Objective

/// Objective function for resource allocation.
public enum AllocationObjective: Sendable {
	/// Maximize sum of expected values
	case maximizeValue

	/// Maximize value per dollar spent (efficiency)
	case maximizeValuePerDollar

	/// Maximize weighted combination of value and strategic importance
	case maximizeWeightedValue(strategicWeight: Double)

	/// Maximize risk-adjusted value
	case maximizeRiskAdjustedValue(riskDiscount: Double)

	/// Custom objective function
	case custom(@Sendable (AllocationResult) -> Double)
}

// MARK: - Allocation Result

/// Result from resource allocation optimization.
public struct AllocationResult: Sendable {
	/// Allocation amounts by option ID
	public let allocations: [String: Double]

	/// Options that received non-zero allocation
	public let selectedOptions: [AllocationOption]

	/// Total value achieved
	public let totalValue: Double

	/// Total resources used by resource type
	public let totalResourcesUsed: [String: Double]

	/// Shadow prices (marginal value of each constraint)
	public let shadowPrices: [String: Double]?

	/// Whether optimization converged
	public let converged: Bool

	/// Number of iterations
	public let iterations: Int

	/// Creates an allocation result.
	public init(
		allocations: [String: Double],
		selectedOptions: [AllocationOption],
		totalValue: Double,
		totalResourcesUsed: [String: Double],
		shadowPrices: [String: Double]? = nil,
		converged: Bool,
		iterations: Int
	) {
		self.allocations = allocations
		self.selectedOptions = selectedOptions
		self.totalValue = totalValue
		self.totalResourcesUsed = totalResourcesUsed
		self.shadowPrices = shadowPrices
		self.converged = converged
		self.iterations = iterations
	}
}

// MARK: - Resource Allocation Optimizer

/// Optimizer for resource allocation problems.
///
/// Solves capital budgeting, project selection, and resource allocation problems
/// by maximizing value subject to resource constraints.
///
/// ## Example
/// ```swift
/// let options = [
///     AllocationOption(
///         id: "proj1",
///         name: "Marketing Campaign",
///         expectedValue: 150_000,
///         resourceRequirements: ["budget": 50_000]
///     ),
///     AllocationOption(
///         id: "proj2",
///         name: "Product Development",
///         expectedValue: 300_000,
///         resourceRequirements: ["budget": 120_000, "headcount": 5]
///     )
/// ]
///
/// let optimizer = ResourceAllocationOptimizer()
/// let result = try optimizer.optimize(
///     options: options,
///     objective: .maximizeValue,
///     constraints: [
///         .totalBudget(150_000),
///         .resourceLimit(resource: "headcount", limit: 5)
///     ]
/// )
///
/// print("Selected: \(result.selectedOptions.map { $0.name })")
/// print("Total value: $\(result.totalValue)")
/// ```
public struct ResourceAllocationOptimizer: Sendable {

	/// Maximum iterations for optimization
	public let maxIterations: Int

	/// Creates a resource allocation optimizer.
	public init(maxIterations: Int = 200) {
		self.maxIterations = maxIterations
	}

	// MARK: - Public API

	/// Optimize resource allocation across options.
	///
	/// - Parameters:
	///   - options: Array of allocation options
	///   - objective: Objective function to maximize (default: .maximizeValue)
	///   - constraints: Array of allocation constraints
	/// - Returns: Optimal allocation result
	/// - Throws: `OptimizationError` if optimization fails
	public func optimize(
		options: [AllocationOption],
		objective: AllocationObjective = .maximizeValue,
		constraints: [AllocationConstraint]
	) throws -> AllocationResult {

		guard !options.isEmpty else {
			throw OptimizationError.invalidInput(message: "No options provided")
		}

		// Build objective function
		let objectiveFunction = buildObjectiveFunction(options: options, objective: objective)

		// Build constraints
		let optimizationConstraints = try buildConstraints(
			options: options,
			allocationConstraints: constraints
		)

		// Initial guess: equal allocation within budget
		let initialAllocation = buildInitialAllocation(options: options, constraints: constraints)

		// Choose optimizer based on constraint types
		let hasInequalityConstraints = !optimizationConstraints.filter { $0.isInequality }.isEmpty

		let finalAllocation: VectorN<Double>
		let converged: Bool
		let iterations: Int

		if hasInequalityConstraints {
			let optimizer = InequalityOptimizer<VectorN<Double>>(maxIterations: maxIterations)
			let result = try optimizer.maximize(
				objectiveFunction,
				from: initialAllocation,
				subjectTo: optimizationConstraints
			)
			finalAllocation = result.solution
			converged = result.converged
			iterations = result.iterations
		} else {
			let optimizer = ConstrainedOptimizer<VectorN<Double>>(maxIterations: maxIterations)
			let result = try optimizer.maximize(
				objectiveFunction,
				from: initialAllocation,
				subjectTo: optimizationConstraints
			)
			finalAllocation = result.solution
			converged = result.converged
			iterations = result.iterations
		}

		// Build result
		return buildResult(
			options: options,
			allocation: finalAllocation,
			converged: converged,
			iterations: iterations
		)
	}

	// MARK: - Private Helpers

	private func buildObjectiveFunction(
		options: [AllocationOption],
		objective: AllocationObjective
	) -> @Sendable (VectorN<Double>) -> Double {
		// Create local copy for Sendable closure
		let optionsCopy = options

		switch objective {
		case .maximizeValue:
			return { allocation in
				// Sum of value * allocation
				var totalValue = 0.0
				for (i, option) in optionsCopy.enumerated() {
					totalValue += option.expectedValue * allocation[i]
				}
				return totalValue
			}

		case .maximizeValuePerDollar:
			return { allocation in
				// Sum of (value / cost) * allocation
				var totalValue = 0.0
				for (i, option) in optionsCopy.enumerated() {
					let cost = option.resourceRequirements["budget"] ?? 1.0
					let efficiency = option.expectedValue / cost
					totalValue += efficiency * allocation[i]
				}
				return totalValue
			}

		case .maximizeWeightedValue(let strategicWeight):
			return { allocation in
				// Weighted sum: (1-w)*value + w*strategic
				var totalValue = 0.0
				for (i, option) in optionsCopy.enumerated() {
					let value = option.expectedValue
					let strategic = option.strategicValue ?? 0.0
					let weighted = (1.0 - strategicWeight) * value + strategicWeight * strategic
					totalValue += weighted * allocation[i]
				}
				return totalValue
			}

		case .maximizeRiskAdjustedValue(let riskDiscount):
			return { allocation in
				// Value discounted by risk: value * (1 - risk)
				var totalValue = 0.0
				for (i, option) in optionsCopy.enumerated() {
					let adjustedValue = option.expectedValue * (1.0 - riskDiscount)
					totalValue += adjustedValue * allocation[i]
				}
				return totalValue
			}

		case .custom(let customFunction):
			return { [self] allocation in
				// Build temporary result for custom function
				let result = self.buildResult(
					options: optionsCopy,
					allocation: allocation,
					converged: true,
					iterations: 0
				)
				return customFunction(result)
			}
		}
	}

	private func buildConstraints(
		options: [AllocationOption],
		allocationConstraints: [AllocationConstraint]
	) throws -> [MultivariateConstraint<VectorN<Double>>] {

		var constraints: [MultivariateConstraint<VectorN<Double>>] = []

		// All allocations must be between 0 and 1 (0 = none, 1 = fully funded)
		constraints += MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: options.count)
		constraints += MultivariateConstraint<VectorN<Double>>.positionLimit(1.0, dimension: options.count)

		// Process each constraint
		for constraint in allocationConstraints {
			switch constraint {
			case .totalBudget(let maxBudget):
				// Sum of (allocation * cost) <= maxBudget
				constraints.append(.inequality { allocation in
					var totalCost = 0.0
					for (i, option) in options.enumerated() {
						let cost = option.resourceRequirements["budget"] ?? 0.0
						totalCost += allocation[i] * cost
					}
					return totalCost - maxBudget  // g(x) ≤ 0
				})

			case .resourceLimit(let resource, let limit):
				// Sum of (allocation * resource) <= limit
				constraints.append(.inequality { allocation in
					var totalUsage = 0.0
					for (i, option) in options.enumerated() {
						let usage = option.resourceRequirements[resource] ?? 0.0
						totalUsage += allocation[i] * usage
					}
					return totalUsage - limit  // g(x) ≤ 0
				})

			case .minimumAllocation(let optionId, let amount):
				guard let index = options.firstIndex(where: { $0.id == optionId }) else {
					throw OptimizationError.invalidInput(message: "Unknown option: \(optionId)")
				}
				// allocation[i] >= amount  =>  -allocation[i] + amount <= 0
				constraints.append(.inequality { allocation in
					amount - allocation[index]
				})

			case .maximumAllocation(let optionId, let amount):
				guard let index = options.firstIndex(where: { $0.id == optionId }) else {
					throw OptimizationError.invalidInput(message: "Unknown option: \(optionId)")
				}
				// allocation[i] <= amount  =>  allocation[i] - amount <= 0
				constraints.append(.inequality { allocation in
					allocation[index] - amount
				})

			case .requiredOption(let optionId):
				guard let index = options.firstIndex(where: { $0.id == optionId }) else {
					throw OptimizationError.invalidInput(message: "Unknown option: \(optionId)")
				}
				// allocation[i] >= 1  =>  1 - allocation[i] <= 0
				constraints.append(.inequality { allocation in
					1.0 - allocation[index]
				})

			case .excludedOption(let optionId):
				guard let index = options.firstIndex(where: { $0.id == optionId }) else {
					throw OptimizationError.invalidInput(message: "Unknown option: \(optionId)")
				}
				// allocation[i] <= 0.01  (effectively 0)
				constraints.append(.inequality { allocation in
					allocation[index] - 0.01
				})

			case .dependency(let optionId, let requiresId):
				guard let optionIndex = options.firstIndex(where: { $0.id == optionId }),
					  let requiredIndex = options.firstIndex(where: { $0.id == requiresId }) else {
					throw OptimizationError.invalidInput(message: "Unknown option in dependency")
				}
				// If allocation[option] > 0, then allocation[required] > 0
				// Enforce: allocation[option] <= allocation[required]
				constraints.append(.inequality { allocation in
					allocation[optionIndex] - allocation[requiredIndex]
				})

			case .mutuallyExclusive(let optionIds):
				// Sum of allocations <= 1
				let indices = try optionIds.map { id -> Int in
					guard let index = options.firstIndex(where: { $0.id == id }) else {
						throw OptimizationError.invalidInput(message: "Unknown option: \(id)")
					}
					return index
				}
				constraints.append(.inequality { allocation in
					var sum = 0.0
					for index in indices {
						sum += allocation[index]
					}
					return sum - 1.0
				})
			}
		}

		return constraints
	}

	private func buildInitialAllocation(
		options: [AllocationOption],
		constraints: [AllocationConstraint]
	) -> VectorN<Double> {
		// Build initial allocation that satisfies required/excluded option constraints
		let n = options.count
		var allocations = Array(repeating: 0.5, count: n)  // Start at midpoint

		// Handle required and excluded options
		for constraint in constraints {
			switch constraint {
			case .requiredOption(let optionId):
				if let index = options.firstIndex(where: { $0.id == optionId }) {
					allocations[index] = 1.0  // Fully allocate required options
				}
			case .excludedOption(let optionId):
				if let index = options.firstIndex(where: { $0.id == optionId }) {
				allocations[index] = 0.001  // Near-zero for excluded (strictly positive for barrier)
				}
			case .minimumAllocation(let optionId, let amount):
				if let index = options.firstIndex(where: { $0.id == optionId }) {
					allocations[index] = max(allocations[index], amount + 0.01)  // Slightly above minimum
				}
			case .maximumAllocation(let optionId, let amount):
				if let index = options.firstIndex(where: { $0.id == optionId }) {
					allocations[index] = min(allocations[index], amount - 0.01)  // Slightly below maximum
				}
			default:
				break
			}
		}

		return VectorN(allocations)
	}

	private func buildResult(
		options: [AllocationOption],
		allocation: VectorN<Double>,
		converged: Bool,
		iterations: Int
	) -> AllocationResult {

		// Build allocations dictionary
		var allocations: [String: Double] = [:]
		var selectedOptions: [AllocationOption] = []
		var totalValue = 0.0
		var totalResourcesUsed: [String: Double] = [:]

		for (i, option) in options.enumerated() {
			let amount = allocation[i]
			allocations[option.id] = amount

			// Consider selected if allocation > 0.01 (threshold for numerical noise)
			if amount > 0.01 {
				selectedOptions.append(option)
				totalValue += option.expectedValue * amount

				// Accumulate resource usage
				for (resource, requirement) in option.resourceRequirements {
					totalResourcesUsed[resource, default: 0.0] += requirement * amount
				}
			}
		}

		return AllocationResult(
			allocations: allocations,
			selectedOptions: selectedOptions,
			totalValue: totalValue,
			totalResourcesUsed: totalResourcesUsed,
			shadowPrices: nil,  // TODO: Extract from Lagrange multipliers
			converged: converged,
			iterations: iterations
		)
	}
}

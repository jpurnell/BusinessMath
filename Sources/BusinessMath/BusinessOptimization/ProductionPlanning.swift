//
//  ProductionPlanning.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation
import Numerics

// MARK: - Manufactured Product Definition

/// Represents a manufactured product for production planning.
///
/// ## Example
/// ```swift
/// let widget = ManufacturedProduct(
///     id: "widget_a",
///     name: "Widget A",
///     pricePerUnit: 100,
///     variableCostPerUnit: 45,
///     demand: .fixed(500),
///     resourceRequirements: ["machine_hours": 2.5, "labor_hours": 1.0]
/// )
/// ```
public struct ManufacturedProduct {
	/// Unique identifier
	public let id: String

	/// Human-readable name
	public let name: String

	/// Selling price per unit
	public let pricePerUnit: Double

	/// Variable cost per unit (materials, direct labor, etc.)
	public let variableCostPerUnit: Double

	/// Demand constraint
	public let demand: ProductDemand

	/// Resources required per unit (e.g., "machine_hours": 2.5)
	public let resourceRequirements: [String: Double]

	/// Creates a product.
	public init(
		id: String,
		name: String,
		pricePerUnit: Double,
		variableCostPerUnit: Double,
		demand: ProductDemand,
		resourceRequirements: [String: Double]
	) {
		self.id = id
		self.name = name
		self.pricePerUnit = pricePerUnit
		self.variableCostPerUnit = variableCostPerUnit
		self.demand = demand
		self.resourceRequirements = resourceRequirements
	}

	/// Contribution margin per unit (price - variable cost)
	public var contributionMargin: Double {
		pricePerUnit - variableCostPerUnit
	}
}

// MARK: - Product Demand

/// Demand constraint for a product.
public enum ProductDemand {
	/// Unlimited demand (sell as much as produced)
	case unlimited

	/// Fixed demand quantity
	case fixed(Double)

	/// Demand range (minimum to maximum)
	case range(min: Double, max: Double)

	/// Maximum production limit
	var maximumQuantity: Double? {
		switch self {
		case .unlimited:
			return nil
		case .fixed(let quantity):
			return quantity
		case .range(_, let max):
			return max
		}
	}

	/// Minimum production requirement
	var minimumQuantity: Double {
		switch self {
		case .unlimited, .fixed:
			return 0
		case .range(let min, _):
			return min
		}
	}
}

// MARK: - Production Constraints

/// Constraints for production planning.
public enum ProductionConstraint {
	/// Maximum capacity for a resource
	case resourceCapacity(resource: String, capacity: Double)

	/// Minimum production quantity for a product
	case minimumProduction(productId: String, quantity: Double)

	/// Maximum production quantity for a product
	case maximumProduction(productId: String, quantity: Double)

	/// Production ratio between two products (A:B)
	case productionRatio(productA: String, productB: String, ratio: Double)

	/// Fixed setup cost if production exceeds threshold
	case setupCost(productId: String, fixedCost: Double, threshold: Double)
}

// MARK: - Production Objective

/// Objective function for production planning.
public enum ProductionObjective {
	/// Maximize profit (revenue - costs)
	case maximizeProfit

	/// Maximize revenue
	case maximizeRevenue

	/// Maximize margin percentage
	case maximizeMargin

	/// Minimize costs
	case minimizeCosts

	/// Maximize resource utilization
	case maximizeUtilization
}

// MARK: - Production Plan Result

/// Result from production planning optimization.
public struct ProductionPlan {
	/// Production quantities by product ID
	public let productionQuantities: [String: Double]

	/// Total revenue
	public let revenue: Double

	/// Total costs
	public let costs: Double

	/// Total profit (revenue - costs)
	public let profit: Double

	/// Resource utilization percentages
	public let resourceUtilization: [String: Double]

	/// Shadow prices (marginal value of each resource)
	public let shadowPrices: [String: Double]?

	/// Whether optimization converged
	public let converged: Bool

	/// Number of iterations
	public let iterations: Int

	/// Creates a production plan.
	public init(
		productionQuantities: [String: Double],
		revenue: Double,
		costs: Double,
		profit: Double,
		resourceUtilization: [String: Double],
		shadowPrices: [String: Double]? = nil,
		converged: Bool,
		iterations: Int
	) {
		self.productionQuantities = productionQuantities
		self.revenue = revenue
		self.costs = costs
		self.profit = profit
		self.resourceUtilization = resourceUtilization
		self.shadowPrices = shadowPrices
		self.converged = converged
		self.iterations = iterations
	}
}

// MARK: - Production Planning Optimizer

/// Optimizer for production planning problems.
///
/// Determines optimal production quantities to maximize profit subject to
/// capacity constraints and demand limits.
///
/// ## Example
/// ```swift
/// let products = [
///     ManufacturedProduct(
///         id: "product_a",
///         name: "Product A",
///         pricePerUnit: 100,
///         variableCostPerUnit: 45,
///         demand: .fixed(500),
///         resourceRequirements: ["machine_hours": 2.0]
///     )
/// ]
///
/// let optimizer = ProductionPlanningOptimizer()
/// let plan = try optimizer.optimize(
///     products: products,
///     resources: ["machine_hours": 1000],
///     objective: .maximizeProfit
/// )
///
/// print("Produce: \(plan.productionQuantities)")
/// print("Profit: $\(plan.profit)")
/// ```
public struct ProductionPlanningOptimizer {

	/// Maximum iterations for optimization
	public let maxIterations: Int

	/// Creates a production planning optimizer.
	public init(maxIterations: Int = 200) {
		self.maxIterations = maxIterations
	}

	// MARK: - Public API

	/// Optimize production plan.
	///
	/// - Parameters:
	///   - products: Array of products to produce
	///   - resources: Available resource capacities
	///   - objective: Objective function (default: .maximizeProfit)
	///   - constraints: Additional production constraints
	/// - Returns: Optimal production plan
	/// - Throws: `OptimizationError` if optimization fails
	public func optimize(
		products: [ManufacturedProduct],
		resources: [String: Double],
		objective: ProductionObjective = .maximizeProfit,
		constraints: [ProductionConstraint] = []
	) throws -> ProductionPlan {

		guard !products.isEmpty else {
			throw OptimizationError.invalidInput(message: "No products provided")
		}

		// Build objective function
		let objectiveFunction = buildObjectiveFunction(
			products: products,
			resources: resources,
			objective: objective
		)

		// Build constraints
		let optimizationConstraints = try buildConstraints(
			products: products,
			resources: resources,
			productionConstraints: constraints
		)

		// Initial guess: produce at 50% of capacity
		let initialQuantities = buildInitialQuantities(products: products, constraints: constraints)

		// Choose optimizer
		let hasInequalityConstraints = !optimizationConstraints.filter { $0.isInequality }.isEmpty

		let finalQuantities: VectorN<Double>
		let converged: Bool
		let iterations: Int

		if hasInequalityConstraints {
			let optimizer = InequalityOptimizer<VectorN<Double>>(maxIterations: maxIterations)
			let result = try optimizer.maximize(
				objectiveFunction,
				from: initialQuantities,
				subjectTo: optimizationConstraints
			)
			finalQuantities = result.solution
			converged = result.converged
			iterations = result.iterations
		} else {
			let optimizer = ConstrainedOptimizer<VectorN<Double>>(maxIterations: maxIterations)
			let result = try optimizer.maximize(
				objectiveFunction,
				from: initialQuantities,
				subjectTo: optimizationConstraints
			)
			finalQuantities = result.solution
			converged = result.converged
			iterations = result.iterations
		}

		// Build result
		return buildPlan(
			products: products,
			quantities: finalQuantities,
			resources: resources,
			converged: converged,
			iterations: iterations
		)
	}

	// MARK: - Private Helpers

	private func buildObjectiveFunction(
		products: [ManufacturedProduct],
		resources: [String: Double],
		objective: ProductionObjective
	) -> (VectorN<Double>) -> Double {
		switch objective {
		case .maximizeProfit:
			return { quantities in
				var profit = 0.0
				for (i, product) in products.enumerated() {
					let quantity = quantities[i]
					profit += product.contributionMargin * quantity
				}
				return profit
			}

		case .maximizeRevenue:
			return { quantities in
				var revenue = 0.0
				for (i, product) in products.enumerated() {
					revenue += product.pricePerUnit * quantities[i]
				}
				return revenue
			}

		case .maximizeMargin:
			return { quantities in
				var revenue = 0.0
				var costs = 0.0
				for (i, product) in products.enumerated() {
					let quantity = quantities[i]
					revenue += product.pricePerUnit * quantity
					costs += product.variableCostPerUnit * quantity
				}
				return revenue > 0 ? (revenue - costs) / revenue : 0
			}

		case .minimizeCosts:
			return { quantities in
				var costs = 0.0
				for (i, product) in products.enumerated() {
					costs += product.variableCostPerUnit * quantities[i]
				}
				return -costs  // Negate for maximization
			}

		case .maximizeUtilization:
			return { quantities in
				var totalUtilization = 0.0
				let resourceCount = resources.count

				for (resource, capacity) in resources {
					var used = 0.0
					for (i, product) in products.enumerated() {
						let requirement = product.resourceRequirements[resource] ?? 0.0
						used += requirement * quantities[i]
					}
					totalUtilization += (capacity > 0) ? (used / capacity) : 0
				}

				return totalUtilization / Double(resourceCount)
			}
		}
	}

	private func buildConstraints(
		products: [ManufacturedProduct],
		resources: [String: Double],
		productionConstraints: [ProductionConstraint]
	) throws -> [MultivariateConstraint<VectorN<Double>>] {

		var constraints: [MultivariateConstraint<VectorN<Double>>] = []

		// All quantities must be non-negative
		constraints += MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: products.count)

		// Resource capacity constraints
		for (resource, capacity) in resources {
			constraints.append(.inequality { quantities in
				var used = 0.0
				for (i, product) in products.enumerated() {
					let requirement = product.resourceRequirements[resource] ?? 0.0
					used += requirement * quantities[i]
				}
				return used - capacity  // g(x) ≤ 0
			})
		}

		// Demand constraints
		for (i, product) in products.enumerated() {
			// Minimum demand
			let minDemand = product.demand.minimumQuantity
			if minDemand > 0 {
				constraints.append(.inequality { quantities in
					minDemand - quantities[i]  // q ≥ min
				})
			}

			// Maximum demand
			if let maxDemand = product.demand.maximumQuantity {
				constraints.append(.inequality { quantities in
					quantities[i] - maxDemand  // q ≤ max
				})
			}
		}

		// Additional constraints
		for constraint in productionConstraints {
			switch constraint {
			case .resourceCapacity(let resource, let capacity):
				// Already handled above
				break

			case .minimumProduction(let productId, let quantity):
				guard let index = products.firstIndex(where: { $0.id == productId }) else {
					throw OptimizationError.invalidInput(message: "Unknown product: \(productId)")
				}
				constraints.append(.inequality { quantities in
					quantity - quantities[index]
				})

			case .maximumProduction(let productId, let quantity):
				guard let index = products.firstIndex(where: { $0.id == productId }) else {
					throw OptimizationError.invalidInput(message: "Unknown product: \(productId)")
				}
				constraints.append(.inequality { quantities in
					quantities[index] - quantity
				})

			case .productionRatio(let productA, let productB, let ratio):
				guard let indexA = products.firstIndex(where: { $0.id == productA }),
					  let indexB = products.firstIndex(where: { $0.id == productB }) else {
					throw OptimizationError.invalidInput(message: "Unknown product in ratio")
				}
				// qA / qB = ratio  =>  qA - ratio * qB = 0
				constraints.append(.equality { quantities in
					quantities[indexA] - ratio * quantities[indexB]
				})

			case .setupCost:
				// Setup costs require integer programming - not supported yet
				// Ignore for now
				break
			}
		}

		return constraints
	}

	private func buildInitialQuantities(
		products: [ManufacturedProduct],
		constraints: [ProductionConstraint]
	) -> VectorN<Double> {
		let n = products.count
		var quantities = [Double](repeating: 100.0, count: n)  // Start with 100 units each

		// Adjust for minimum/maximum constraints
		for constraint in constraints {
			switch constraint {
			case .minimumProduction(let productId, let quantity):
				if let index = products.firstIndex(where: { $0.id == productId }) {
					quantities[index] = max(quantities[index], quantity + 10)
				}
			case .maximumProduction(let productId, let quantity):
				if let index = products.firstIndex(where: { $0.id == productId }) {
					quantities[index] = min(quantities[index], quantity - 10)
				}
			default:
				break
			}
		}

		return VectorN(quantities)
	}

	private func buildPlan(
		products: [ManufacturedProduct],
		quantities: VectorN<Double>,
		resources: [String: Double],
		converged: Bool,
		iterations: Int
	) -> ProductionPlan {

		var productionQuantities: [String: Double] = [:]
		var revenue = 0.0
		var costs = 0.0
		var resourceUsage: [String: Double] = [:]

		for (i, product) in products.enumerated() {
			let quantity = quantities[i]
			productionQuantities[product.id] = quantity

			revenue += product.pricePerUnit * quantity
			costs += product.variableCostPerUnit * quantity

			// Track resource usage
			for (resource, requirement) in product.resourceRequirements {
				resourceUsage[resource, default: 0.0] += requirement * quantity
			}
		}

		let profit = revenue - costs

		// Calculate resource utilization percentages
		var resourceUtilization: [String: Double] = [:]
		for (resource, capacity) in resources {
			let used = resourceUsage[resource] ?? 0.0
			resourceUtilization[resource] = capacity > 0 ? (used / capacity) : 0
		}

		return ProductionPlan(
			productionQuantities: productionQuantities,
			revenue: revenue,
			costs: costs,
			profit: profit,
			resourceUtilization: resourceUtilization,
			shadowPrices: nil,
			converged: converged,
			iterations: iterations
		)
	}
}

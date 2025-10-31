//
//  CapitalAllocationOptimizer.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

// MARK: - CapitalAllocationOptimizer

/// Optimizes capital allocation across multiple projects.
///
/// `CapitalAllocationOptimizer` helps decide how to allocate limited capital
/// across competing projects to maximize total NPV. It provides both greedy
/// and optimal (0-1 knapsack) algorithms.
///
/// ## Usage
///
/// ```swift
/// let optimizer = CapitalAllocationOptimizer<Double>()
///
/// let projects = [
///     CapitalAllocationOptimizer.Project(
///         name: "Project A",
///         npv: 100_000,
///         capitalRequired: 50_000,
///         risk: 0.2
///     ),
///     CapitalAllocationOptimizer.Project(
///         name: "Project B",
///         npv: 150_000,
///         capitalRequired: 100_000,
///         risk: 0.3
///     )
/// ]
///
/// // Greedy allocation (fast, approximate)
/// let greedy = optimizer.optimize(projects: projects, budget: 120_000)
///
/// // Optimal allocation (slower, exact)
/// let optimal = optimizer.optimizeIntegerProjects(projects: projects, budget: 120_000)
///
/// print("Projects selected: \(optimal.projectsSelected)")
/// print("Total NPV: \(optimal.totalNPV)")
/// ```
///
/// ## Algorithms
///
/// ### Greedy Algorithm
/// Sorts projects by ROI (NPV / capital required) and selects projects in order
/// until the budget is exhausted. Fast but may not find the optimal solution.
///
/// ### Integer Programming (0-1 Knapsack)
/// Uses dynamic programming to find the optimal combination of projects.
/// Each project is either fully funded or not funded at all. Slower but
/// guaranteed to find the optimal solution.
public struct CapitalAllocationOptimizer<T> where T: Real & Sendable & Codable & Comparable & BinaryFloatingPoint {

	// MARK: - Project

	/// A capital project with NPV, capital requirements, and risk.
	public struct Project: Sendable {
		/// The name of the project.
		public let name: String

		/// The net present value of the project.
		public let npv: T

		/// The capital required to fund the project.
		public let capitalRequired: T

		/// The risk level of the project (0-1). Optional.
		public let risk: T

		/// The return on investment (NPV / capital required).
		public var roi: T {
			guard capitalRequired > 0 else { return 0 }
			return npv / capitalRequired
		}

		/// Creates a capital project.
		///
		/// - Parameters:
		///   - name: The name of the project.
		///   - npv: The net present value.
		///   - capitalRequired: The capital required.
		///   - risk: The risk level (0-1). Defaults to 0.
		public init(
			name: String,
			npv: T,
			capitalRequired: T,
			risk: T = 0
		) {
			self.name = name
			self.npv = npv
			self.capitalRequired = capitalRequired
			self.risk = risk
		}
	}

	// MARK: - AllocationResult

	/// The result of capital allocation optimization.
	public struct AllocationResult: Sendable {
		/// Capital allocated to each project (project name -> amount).
		public let allocations: [String: T]

		/// The total NPV of selected projects.
		public let totalNPV: T

		/// The total capital used.
		public let capitalUsed: T

		/// Names of projects selected.
		public let projectsSelected: [String]

		/// A human-readable description of the result.
		public var description: String {
			var result = "Capital Allocation Result\n"
			result += "=========================\n"
			result += "Total NPV: \(totalNPV)\n"
			result += "Capital Used: \(capitalUsed)\n"
			result += "Projects Selected: \(projectsSelected.count)\n\n"

			if !projectsSelected.isEmpty {
				result += "Allocations:\n"
				for project in projectsSelected.sorted() {
					if let amount = allocations[project] {
						result += "  \(project): \(amount)\n"
					}
				}
			}

			return result
		}

		/// Creates an allocation result.
		///
		/// - Parameters:
		///   - allocations: Capital allocated to each project.
		///   - totalNPV: The total NPV.
		///   - capitalUsed: The total capital used.
		///   - projectsSelected: Names of projects selected.
		public init(
			allocations: [String: T],
			totalNPV: T,
			capitalUsed: T,
			projectsSelected: [String]
		) {
			self.allocations = allocations
			self.totalNPV = totalNPV
			self.capitalUsed = capitalUsed
			self.projectsSelected = projectsSelected
		}
	}

	// MARK: - Initialization

	/// Creates a capital allocation optimizer.
	public init() {}

	// MARK: - Greedy Optimization

	/// Optimizes capital allocation using a greedy algorithm.
	///
	/// Sorts projects by ROI (highest first) and allocates capital until
	/// the budget is exhausted. This is fast but may not find the globally
	/// optimal solution.
	///
	/// - Parameters:
	///   - projects: The projects to consider.
	///   - budget: The total budget available.
	/// - Returns: The allocation result.
	public func optimize(
		projects: [Project],
		budget: T
	) -> AllocationResult {
		guard budget > 0 else {
			return AllocationResult(
				allocations: [:],
				totalNPV: 0,
				capitalUsed: 0,
				projectsSelected: []
			)
		}

		guard !projects.isEmpty else {
			return AllocationResult(
				allocations: [:],
				totalNPV: 0,
				capitalUsed: 0,
				projectsSelected: []
			)
		}

		// Sort projects by ROI (descending)
		let sortedProjects = projects.sorted { $0.roi > $1.roi }

		var allocations: [String: T] = [:]
		var totalNPV: T = 0
		var capitalUsed: T = 0
		var projectsSelected: [String] = []
		var remainingBudget = budget

		for project in sortedProjects {
			// Check if we can afford this project
			if project.capitalRequired <= remainingBudget {
				allocations[project.name] = project.capitalRequired
				totalNPV += project.npv
				capitalUsed += project.capitalRequired
				projectsSelected.append(project.name)
				remainingBudget -= project.capitalRequired
			}
		}

		return AllocationResult(
			allocations: allocations,
			totalNPV: totalNPV,
			capitalUsed: capitalUsed,
			projectsSelected: projectsSelected
		)
	}

	// MARK: - Integer Optimization (0-1 Knapsack)

	/// Optimizes capital allocation using integer programming (0-1 knapsack).
	///
	/// Uses dynamic programming to find the optimal combination of projects.
	/// Each project is either fully funded or not funded at all. This is
	/// slower than the greedy algorithm but finds the globally optimal solution.
	///
	/// - Parameters:
	///   - projects: The projects to consider.
	///   - budget: The total budget available.
	/// - Returns: The allocation result.
	public func optimizeIntegerProjects(
		projects: [Project],
		budget: T
	) -> AllocationResult {
		guard budget > 0 else {
			return AllocationResult(
				allocations: [:],
				totalNPV: 0,
				capitalUsed: 0,
				projectsSelected: []
			)
		}

		guard !projects.isEmpty else {
			return AllocationResult(
				allocations: [:],
				totalNPV: 0,
				capitalUsed: 0,
				projectsSelected: []
			)
		}

		let n = projects.count
		let maxBudget = Int(budget)

		// DP table: dp[i][w] = max NPV using first i projects with budget w
		var dp = Array(repeating: Array(repeating: T(0), count: maxBudget + 1), count: n + 1)

		// Fill DP table
		for i in 1...n {
			let project = projects[i - 1]
			let cost = Int(project.capitalRequired)

			for w in 0...maxBudget {
				// Don't take project i
				dp[i][w] = dp[i - 1][w]

				// Take project i (if we can afford it)
				if cost <= w {
					let valueWithProject = dp[i - 1][w - cost] + project.npv
					if valueWithProject > dp[i][w] {
						dp[i][w] = valueWithProject
					}
				}
			}
		}

		// Backtrack to find which projects were selected
		var allocations: [String: T] = [:]
		var projectsSelected: [String] = []
		var w = maxBudget
		var totalNPV: T = 0
		var capitalUsed: T = 0

		for i in (1...n).reversed() {
			let project = projects[i - 1]
			let cost = Int(project.capitalRequired)

			// Check if project i was included
			if w >= cost && dp[i][w] != dp[i - 1][w] {
				allocations[project.name] = project.capitalRequired
				projectsSelected.append(project.name)
				totalNPV += project.npv
				capitalUsed += project.capitalRequired
				w -= cost
			}
		}

		return AllocationResult(
			allocations: allocations,
			totalNPV: totalNPV,
			capitalUsed: capitalUsed,
			projectsSelected: projectsSelected
		)
	}
}

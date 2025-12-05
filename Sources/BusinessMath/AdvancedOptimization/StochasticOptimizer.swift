//
//  StochasticOptimizer.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation
import Numerics

// MARK: - Stochastic Optimization Result

/// Result from stochastic optimization.
public struct StochasticResult<V: VectorSpace> where V.Scalar == Double {
	/// Optimal decision
	public let solution: V

	/// Expected objective value (average across scenarios)
	public let expectedObjective: Double

	/// Standard deviation of objective across scenarios
	public let objectiveStdDev: Double

	/// Objective values for each scenario
	public let scenarioObjectives: [Double]

	/// Whether optimization converged
	public let converged: Bool

	/// Number of iterations
	public let iterations: Int

	/// Number of scenarios used
	public var numberOfScenarios: Int { scenarioObjectives.count }
}

// MARK: - Stochastic Optimizer

/// Optimizer for problems with uncertain parameters using Sample Average Approximation (SAA).
///
/// Stochastic optimization solves:
/// ```
/// minimize: E[f(x, ω)]
/// subject to: constraints on x
/// ```
///
/// Where ω represents random parameters. The expectation is approximated using Monte Carlo:
/// ```
/// E[f(x, ω)] ≈ (1/N) Σᵢ f(x, ωᵢ)
/// ```
///
/// ## Example: Portfolio with Uncertain Returns
/// ```swift
/// let optimizer = StochasticOptimizer<VectorN<Double>>(
///     numberOfSamples: 1000,
///     seed: 42
/// )
///
/// let result = try optimizer.optimize(
///     objective: { weights, scenario in
///         // scenario contains random returns
///         let returns = scenario.parameters.map { $0.value }
///         return -weights.dot(VectorN(returns))  // Negative for maximization
///     },
///     scenarioGenerator: {
///         ScenarioGenerator.normal(
///             mean: [0.10, 0.12, 0.08],
///             standardDeviation: [0.15, 0.20, 0.12],
///             numberOfScenarios: 1,
///             seed: nil
///         ).first!
///     },
///     initialSolution: VectorN([1.0/3, 1.0/3, 1.0/3]),
///     constraints: [.budgetConstraint]
/// )
/// ```
public struct StochasticOptimizer<V: VectorSpace> where V.Scalar == Double {

	// MARK: - Properties

	/// Number of Monte Carlo samples
	public let numberOfSamples: Int

	/// Random seed for reproducibility
	public let seed: UInt64?

	/// Maximum iterations for underlying optimizer
	public let maxIterations: Int

	/// Convergence tolerance
	public let tolerance: Double

	// MARK: - Initialization

	/// Creates a stochastic optimizer.
	///
	/// - Parameters:
	///   - numberOfSamples: Number of Monte Carlo scenarios (default: 1000)
	///   - seed: Random seed for reproducibility (default: nil)
	///   - maxIterations: Maximum iterations (default: 500)
	///   - tolerance: Convergence tolerance (default: 1e-6)
	public init(
		numberOfSamples: Int = 1000,
		seed: UInt64? = nil,
		maxIterations: Int = 500,
		tolerance: Double = 1e-6
	) {
		precondition(numberOfSamples > 0, "Number of samples must be positive")
		self.numberOfSamples = numberOfSamples
		self.seed = seed
		self.maxIterations = maxIterations
		self.tolerance = tolerance
	}

	// MARK: - Optimization

	/// Optimize expected value using Sample Average Approximation.
	///
	/// - Parameters:
	///   - objective: Scenario-dependent objective f(x, ω)
	///   - scenarioGenerator: Function that generates random scenarios
	///   - initialSolution: Starting point
	///   - constraints: Constraints on decision (scenario-independent)
	///   - minimize: Whether to minimize (true) or maximize (false)
	/// - Returns: Stochastic optimization result
	public func optimize<S: OptimizationScenario>(
		objective: @escaping (V, S) -> Double,
		scenarioGenerator: @escaping () -> S,
		initialSolution: V,
		constraints: [MultivariateConstraint<V>] = [],
		minimize: Bool = true
	) throws -> StochasticResult<V> {

		// Generate scenarios
		var scenarios: [S] = []
		for _ in 0..<numberOfSamples {
			scenarios.append(scenarioGenerator())
		}

		// Create SAA objective: E[f(x,ω)] ≈ (1/N) Σ f(x,ωᵢ)
		let saaObjective: (V) -> Double = { x in
			var total = 0.0
			for scenario in scenarios {
				let value = objective(x, scenario)
				total += value * scenario.probability
			}
			// Normalize by sum of probabilities
			let probSum = scenarios.map { $0.probability }.reduce(0.0, +)
			return total / probSum
		}

		// Choose optimizer based on constraints
		let hasInequality = constraints.contains { !$0.isEquality }

		let result: ConstrainedOptimizationResult<V>

		if hasInequality {
			// Use inequality optimizer
			let optimizer = InequalityOptimizer<V>(
				constraintTolerance: V.Scalar(tolerance),
				gradientTolerance: V.Scalar(tolerance),
				maxIterations: maxIterations,
				maxInnerIterations: 1000
			)
			result = try optimizer.minimize(
				saaObjective,
				from: initialSolution,
				subjectTo: constraints
			)
		} else {
			// Use equality optimizer (handles empty constraints too)
			let optimizer = ConstrainedOptimizer<V>(
				constraintTolerance: V.Scalar(tolerance),
				gradientTolerance: V.Scalar(tolerance),
				maxIterations: maxIterations,
				maxInnerIterations: 1000
			)
			result = try optimizer.minimize(
				saaObjective,
				from: initialSolution,
				subjectTo: constraints
			)
		}

		// Evaluate solution on all scenarios
		let scenarioObjectives = scenarios.map { scenario in
			objective(result.solution, scenario)
		}

		// Calculate statistics
		let expectedObjective = scenarioObjectives.reduce(0.0, +) / Double(scenarioObjectives.count)
		let variance = scenarioObjectives.map { pow($0 - expectedObjective, 2) }.reduce(0.0, +) / Double(scenarioObjectives.count)
		let stdDev = sqrt(variance)

		return StochasticResult(
			solution: result.solution,
			expectedObjective: expectedObjective,
			objectiveStdDev: stdDev,
			scenarioObjectives: scenarioObjectives,
			converged: result.converged,
			iterations: result.iterations
		)
	}
}

// MARK: - Convenience Extensions

extension StochasticOptimizer {

	/// Optimize with pre-generated scenarios (discrete distribution).
	///
	/// - Parameters:
	///   - objective: Scenario-dependent objective
	///   - scenarios: Pre-generated scenarios with probabilities
	///   - initialSolution: Starting point
	///   - constraints: Constraints on decision
	///   - minimize: Whether to minimize
	public func optimize<S: OptimizationScenario>(
		objective: @escaping (V, S) -> Double,
		scenarios: [S],
		initialSolution: V,
		constraints: [MultivariateConstraint<V>] = [],
		minimize: Bool = true
	) throws -> StochasticResult<V> {

		precondition(!scenarios.isEmpty, "Must provide at least one scenario")

		// Create SAA objective
		let saaObjective: (V) -> Double = { x in
			var total = 0.0
			for scenario in scenarios {
				let value = objective(x, scenario)
				total += value * scenario.probability
			}
			// Normalize by sum of probabilities
			let probSum = scenarios.map { $0.probability }.reduce(0.0, +)
			return total / probSum
		}

		// Choose optimizer
		let hasInequality = constraints.contains { !$0.isEquality }
		let result: ConstrainedOptimizationResult<V>

		if hasInequality {
			let optimizer = InequalityOptimizer<V>(
				constraintTolerance: V.Scalar(tolerance),
				gradientTolerance: V.Scalar(tolerance),
				maxIterations: maxIterations,
				maxInnerIterations: 1000
			)
			result = try optimizer.minimize(saaObjective, from: initialSolution, subjectTo: constraints)
		} else {
			let optimizer = ConstrainedOptimizer<V>(
				constraintTolerance: V.Scalar(tolerance),
				gradientTolerance: V.Scalar(tolerance),
				maxIterations: maxIterations,
				maxInnerIterations: 1000
			)
			result = try optimizer.minimize(saaObjective, from: initialSolution, subjectTo: constraints)
		}

		// Evaluate on scenarios
		let scenarioObjectives = scenarios.map { objective(result.solution, $0) }
		let expectedObjective = scenarioObjectives.reduce(0.0, +) / Double(scenarioObjectives.count)
		let variance = scenarioObjectives.map { pow($0 - expectedObjective, 2) }.reduce(0.0, +) / Double(scenarioObjectives.count)
		let stdDev = sqrt(variance)

		return StochasticResult(
			solution: result.solution,
			expectedObjective: expectedObjective,
			objectiveStdDev: stdDev,
			scenarioObjectives: scenarioObjectives,
			converged: result.converged,
			iterations: result.iterations
		)
	}
}

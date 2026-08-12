//
//  RobustOptimizer.swift
//  BusinessMath
//
//  Created by Justin Purnell on 12/04/25.
//

import Foundation
import Numerics

// MARK: - Robust Optimization Result

/// Result from robust optimization.
public struct RobustResult<V: VectorSpace> where V.Scalar == Double {
	/// Robust optimal solution
	public let solution: V

	/// Worst-case objective value at the solution
	public let worstCaseObjective: Double

	/// Nominal objective value (at center of uncertainty set)
	public let nominalObjective: Double

	/// Worst-case parameter realization
	public let worstCaseParameters: [Double]

	/// Whether optimization converged
	public let converged: Bool

	/// Number of iterations
	public let iterations: Int

	// MARK: - Protocol Compatibility

	/// Objective value (alias for worstCaseObjective)
	public var objectiveValue: Double { worstCaseObjective }

	/// Description of optimization outcome
	public var convergenceReason: String {
		if converged {
			return "Robust optimization converged: worst-case objective = \(worstCaseObjective), nominal objective = \(nominalObjective)"
		} else {
			return "Maximum iterations reached: worst-case objective = \(worstCaseObjective), nominal objective = \(nominalObjective)"
		}
	}
}

// MARK: - Robust Optimizer

/// Optimizer for robust optimization under parameter uncertainty.
///
/// Robust optimization solves min-max problems:
/// ```
/// minimize: max{ω ∈ U} f(x, ω)
/// subject to: g(x, ω) ≤ 0 for all ω ∈ U
/// ```
///
/// Where U is the uncertainty set and ω represents uncertain parameters.
///
/// ## Example: Worst-Case Portfolio
/// ```swift
/// let uncertaintySet = BoxUncertaintySet(
///     nominal: [0.10, 0.12, 0.08, 0.04],
///     deviations: [0.02, 0.03, 0.02, 0.01]
/// )
///
/// let optimizer = RobustOptimizer<VectorN<Double>>(
///     uncertaintySet: uncertaintySet,
///     samplesPerIteration: 50
/// )
///
/// let result = try optimizer.optimize(
///     objective: { weights, returns in
///         // Negative for maximization of return
///         -weights.dot(VectorN(returns))
///     },
///     nominalParameters: [0.10, 0.12, 0.08, 0.04],
///     initialSolution: VectorN([0.25, 0.25, 0.25, 0.25]),
///     constraints: [.budgetConstraint] + .nonNegativity(dimension: 4),
///     minimize: true  // Minimize worst-case (maximize worst-case return)
/// )
/// ```
public struct RobustOptimizer<V: VectorSpace> where V.Scalar == Double {

	// MARK: - Properties

	/// Uncertainty set defining parameter ranges
	public let uncertaintySet: any UncertaintySet

	/// Number of samples to use per iteration for worst-case search
	public let samplesPerIteration: Int

	/// Maximum iterations for outer optimization
	public let maxIterations: Int

	/// Convergence tolerance
	public let tolerance: Double

	// MARK: - Initialization

	/// Creates a robust optimizer.
	///
	/// - Parameters:
	///   - uncertaintySet: Uncertainty set for parameters
	///   - samplesPerIteration: Samples for worst-case search (default: 100)
	///   - maxIterations: Maximum iterations (default: 500)
	///   - tolerance: Convergence tolerance (default: 1e-6)
	public init(
		uncertaintySet: any UncertaintySet,
		samplesPerIteration: Int = 100,
		maxIterations: Int = 500,
		tolerance: Double = 1e-6
	) {
		self.uncertaintySet = uncertaintySet
		self.samplesPerIteration = samplesPerIteration
		self.maxIterations = maxIterations
		self.tolerance = tolerance
	}

	// MARK: - Optimization

	/// Optimize for worst-case performance.
	///
	/// ## Epigraph reformulation
	///
	/// The problem as written is a minimax:
	/// ```
	/// minimize  max{ω ∈ Ω} f(x, ω)
	/// ```
	/// Handing that pointwise maximum to a gradient-based optimizer as a single
	/// objective does not work. At a minimax optimum the argmax generically *ties* —
	/// that is what makes it the optimum — so the objective has a kink exactly at the
	/// solution. A central finite difference straddling that kink reports a gradient
	/// that never decays, so the solver's KKT stationarity test can never be met and
	/// it burns its whole iteration budget before reporting `converged == false`.
	///
	/// The maximum is therefore lifted into the constraints, which is exact rather
	/// than approximate:
	/// ```
	/// minimize  t
	/// subject to  f(x, ωₖ) − t ≤ 0   for every sampled ωₖ
	/// ```
	/// (and `t − f(x, ωₖ) ≤ 0` with objective `−t` when maximizing the worst case).
	/// The objective is now linear, every constraint is as smooth as the caller's own
	/// `f`, and the tie at the optimum becomes several simultaneously active
	/// constraints — the case an augmented-Lagrangian method is built for.
	///
	/// The extra variable `t` cannot be appended to an arbitrary `V`, so the augmented
	/// problem is solved in `VectorN<Double>` and projected back through
	/// ``VectorSpace/fromArray(_:)``. The projection is verified once, up front,
	/// against the initial solution's own components.
	///
	/// - Parameters:
	///   - objective: Objective function f(x, ω) depending on decision and parameters
	///   - nominalParameters: Nominal (center) parameter values
	///   - initialSolution: Starting point for decision variables
	///   - constraints: Constraints on decision variables (must hold for all ω)
	///   - minimize: Whether to minimize worst-case (true) or maximize worst-case (false)
	/// - Returns: Robust optimization result
	/// - Throws: ``OptimizationError`` if the initial solution cannot be rebuilt from
	///   its own components, if the objective is not finite there, or if the
	///   underlying constrained solve fails.
	public func optimize(
		objective: @escaping @Sendable (V, [Double]) -> Double,
		nominalParameters: [Double],
		initialSolution: V,
		constraints: [MultivariateConstraint<V>] = [],
		minimize: Bool = true
	) throws -> RobustResult<V> {

		guard nominalParameters.count == uncertaintySet.dimension else {
			throw BusinessMathError.mismatchedDimensions(
				message: "Nominal parameters dimension must match uncertainty set",
				expected: String(uncertaintySet.dimension),
				actual: String(nominalParameters.count)
			)
		}

		// Sample points from uncertainty set for worst-case evaluation
		let uncertaintyPoints = uncertaintySet.samplePoints(numberOfSamples: samplesPerIteration)

		// Create worst-case objective: for each x, find max_ω f(x, ω)
		let worstCaseObjective: @Sendable (V) -> Double = { x in
			var worstValue = minimize ? -Double.infinity : Double.infinity
			for omega in uncertaintyPoints {
				let value = objective(x, omega)
				if minimize {
					// Minimize worst-case: find maximum over ω
					worstValue = max(worstValue, value)
				} else {
					// Maximize worst-case: find minimum over ω
					worstValue = min(worstValue, value)
				}
			}
			return worstValue
		}

		// MARK: Epigraph reformulation
		//
		// See the doc comment above: the pointwise max is lifted into the constraints
		// so that nothing handed to the solver has a kink at the solution.
		let baseComponents = initialSolution.toArray()
		let dimension = baseComponents.count

		guard dimension > 0 else {
			throw OptimizationError.invalidInput(
				message: "Initial solution has zero dimensions"
			)
		}

		// MARK: Linear fast path
		//
		// When the objective is linear in the decision variables at every sampled
		// realization and the caller's constraints are linear too, the epigraph
		// problem below *is* a linear program, and handing it to a penalty method is
		// both far slower and less accurate than solving it outright. Try that first;
		// a nil result means some piece is genuinely nonlinear and the general path
		// takes over.
		if let linear = try linearRobustCounterpart(
			objective: objective,
			uncertaintyPoints: uncertaintyPoints,
			initialSolution: initialSolution,
			constraints: constraints,
			minimize: minimize
		) {
			let worst = Self.worstCase(
				at: linear.solution,
				objective: objective,
				uncertaintyPoints: uncertaintyPoints,
				nominalParameters: nominalParameters,
				minimize: minimize
			)
			return RobustResult(
				solution: linear.solution,
				worstCaseObjective: worst.value,
				nominalObjective: objective(linear.solution, nominalParameters),
				worstCaseParameters: worst.parameters,
				converged: true,
				iterations: linear.iterations
			)
		}

		// The projection back from the augmented space is the one thing this
		// reformulation depends on that the `VectorSpace` protocol allows to fail.
		// Establish it once here, on components of exactly the length every later
		// projection will see, rather than discovering it inside a closure that has no
		// way to report the failure.
		guard V.fromArray(baseComponents) != nil else {
			throw OptimizationError.invalidInput(
				message: "Initial solution cannot be rebuilt from its own components; the epigraph reformulation requires a round-trippable vector type"
			)
		}

		let project: @Sendable (VectorN<Double>) -> V? = { augmented in
			let head = Array(augmented.toArray().prefix(dimension))
			guard head.count == dimension else { return nil }
			return V.fromArray(head)
		}

		let epigraphIndex = dimension
		let startValue = worstCaseObjective(initialSolution)

		guard startValue.isFinite else {
			throw OptimizationError.nonFiniteValue(
				message: "Worst-case objective is not finite at the initial solution"
			)
		}

		let augmentedStart = VectorN<Double>(baseComponents + [startValue])

		// Objective: the epigraph variable itself. Minimizing the worst case minimizes
		// t; maximizing it maximizes t, which is minimizing −t.
		let epigraphObjective: @Sendable (VectorN<Double>) -> Double = { point in
			let t = point[epigraphIndex]
			return minimize ? t : -t
		}

		var augmentedConstraints: [MultivariateConstraint<VectorN<Double>>] = []
		augmentedConstraints.reserveCapacity(uncertaintyPoints.count + constraints.count)

		// One constraint per sampled parameter realization: t dominates (or is
		// dominated by) f(x, ωₖ).
		for omega in uncertaintyPoints {
			augmentedConstraints.append(.inequality { point in
				// Unreachable: arity was verified against `initialSolution` above, and
				// every point the solver builds keeps that arity. Infinity is reported
				// rather than a plausible value so a broken projection can only ever
				// look infeasible, never converged.
				guard let x = project(point) else { return Double.infinity }
				let value = objective(x, omega)
				let t = point[epigraphIndex]
				return minimize ? (value - t) : (t - value)
			})
		}

		// The caller's own constraints, evaluated on the projected decision vector so
		// the epigraph variable is invisible to them.
		for constraint in constraints {
			let evaluate: @Sendable (VectorN<Double>) -> Double = { point in
				guard let x = project(point) else { return Double.infinity }
				return constraint.evaluate(at: x)
			}
			if constraint.isEquality {
				augmentedConstraints.append(.equality(evaluate))
			} else {
				augmentedConstraints.append(.inequality(evaluate))
			}
		}

		let optimizer = InequalityOptimizer<VectorN<Double>>(
			constraintTolerance: tolerance,
			gradientTolerance: tolerance,
			maxIterations: maxIterations,
			maxInnerIterations: 1000
		)

		let augmentedResult = try optimizer.minimize(
			epigraphObjective,
			from: augmentedStart,
			subjectTo: augmentedConstraints
		)

		guard let solution = project(augmentedResult.solution) else {
			throw OptimizationError.invalidInput(
				message: "Solution of the epigraph problem could not be projected back onto the decision space"
			)
		}

		let worst = Self.worstCase(
			at: solution,
			objective: objective,
			uncertaintyPoints: uncertaintyPoints,
			nominalParameters: nominalParameters,
			minimize: minimize
		)

		return RobustResult(
			solution: solution,
			worstCaseObjective: worst.value,
			nominalObjective: objective(solution, nominalParameters),
			worstCaseParameters: worst.parameters,
			converged: augmentedResult.converged,
			iterations: augmentedResult.iterations
		)
	}

	// MARK: - Linear robust counterpart

	/// Accuracy of the coefficients recovered by linearisation, and therefore the
	/// tightest tolerance the resulting linear program can honestly be solved to.
	///
	/// `validateLinearModel` recovers coefficients by finite differences with a step
	/// of 1e-8, so they are good to about that; a decimal order of margin above it
	/// leaves the comparison meaningful without asking for precision the data does
	/// not carry.
	private static var linearisationTolerance: Double { 1e-7 }

	/// Solves the robust counterpart exactly as a linear program, when it is one.
	///
	/// The epigraph form `min t s.t. f(x, ωₖ) ≤ t` is a linear program whenever `f`
	/// is linear in `x` at every sampled `ωₖ` and the caller's constraints are
	/// linear. That is the common case for portfolio and allocation models, and it
	/// is worth detecting: the general path spends an augmented-Lagrangian outer loop
	/// and a quasi-Newton inner loop rediscovering numerically what the simplex
	/// method returns exactly, and it rediscovers it in minutes rather than
	/// microseconds. Sampling the uncertainty set also only ever bounds the true
	/// worst case from below, so the slower route is not the more accurate one.
	///
	/// Returns `nil` — rather than throwing — when any piece fails to linearise, so
	/// that a genuinely nonlinear model falls through to the general solver. The only
	/// errors propagated are those raised while building the linear program after
	/// linearity has already been established.
	///
	/// Every variable is split into non-negative positive and negative parts, because
	/// the simplex solver assumes `x ≥ 0` while both the decision variables and the
	/// epigraph variable are free.
	private func linearRobustCounterpart(
		objective: @escaping @Sendable (V, [Double]) -> Double,
		uncertaintyPoints: [[Double]],
		initialSolution: V,
		constraints: [MultivariateConstraint<V>],
		minimize: Bool
	) throws -> (solution: V, iterations: Int)? {
		let dimension = initialSolution.toArray().count
		guard dimension > 0, !uncertaintyPoints.isEmpty else { return nil }

		var scenarios: [(coefficients: [Double], constant: Double)] = []
		scenarios.reserveCapacity(uncertaintyPoints.count)
		for omega in uncertaintyPoints {
			let scenario: (V) -> Double = { point in objective(point, omega) }
			guard let model = try? validateLinearModel(scenario, dimension: dimension, at: initialSolution) else {
				return nil
			}
			guard model.coefficients.count == dimension else { return nil }
			scenarios.append(model)
		}

		var linearConstraints: [(coefficients: [Double], constant: Double, isEquality: Bool)] = []
		linearConstraints.reserveCapacity(constraints.count)
		for constraint in constraints {
			let evaluate: (V) -> Double = { point in constraint.evaluate(at: point) }
			guard let model = try? validateLinearModel(evaluate, dimension: dimension, at: initialSolution) else {
				return nil
			}
			guard model.coefficients.count == dimension else { return nil }
			linearConstraints.append((model.coefficients, model.constant, constraint.isEquality))
		}

		// Which decision variables does the caller's own model already pin at or above
		// zero? A linearised row reading `−xᵢ ≤ 0` proves it, and such a variable needs
		// no ± split, because non-negativity is what the simplex method assumes of every
		// column to begin with.
		//
		// Splitting one anyway is not merely wasteful. Every value of `xᵢ` then has
		// infinitely many `(xᵢ⁺, xᵢ⁻)` representations, and the program becomes
		// degenerate in exactly the way that makes the method wander: a 54-row instance
		// took 141 iterations and stopped on a point violating its own equality row by
		// 3.7e-3, while reporting `.optimal`. The same model with only the epigraph
		// variable split solves in single-digit iterations.
		var isProvablyNonNegative = [Bool](repeating: false, count: dimension)
		for constraint in linearConstraints where !constraint.isEquality {
			guard constraint.constant <= Self.linearisationTolerance else { continue }
			var boundedIndex: Int?
			var isSimpleBound = true
			for (index, coefficient) in constraint.coefficients.enumerated() {
				if abs(coefficient) <= Self.linearisationTolerance { continue }
				if coefficient < 0 && boundedIndex == nil {
					boundedIndex = index
				} else {
					isSimpleBound = false
					break
				}
			}
			if isSimpleBound, let index = boundedIndex {
				isProvablyNonNegative[index] = true
			}
		}

		// Column layout: one column for a variable known non-negative, two for a free
		// one, then the epigraph variable, which is always free.
		var positiveColumn = [Int](repeating: 0, count: dimension)
		var negativeColumn = [Int?](repeating: nil, count: dimension)
		var columnCount = 0
		for i in 0..<dimension {
			positiveColumn[i] = columnCount
			columnCount += 1
			if !isProvablyNonNegative[i] {
				negativeColumn[i] = columnCount
				columnCount += 1
			}
		}
		let positiveEpigraph = columnCount
		let negativeEpigraph = columnCount + 1
		let variableCount = columnCount + 2

		/// Places `coefficient · xᵢ` into `row`, honouring how `xᵢ` is represented.
		func place(_ coefficient: Double, forVariable i: Int, into row: inout [Double]) {
			row[positiveColumn[i]] = coefficient
			if let negative = negativeColumn[i] {
				row[negative] = -coefficient
			}
		}

		var rows: [SimplexConstraint] = []
		rows.reserveCapacity(scenarios.count + linearConstraints.count)

		// Minimising: f(x, ωₖ) − t ≤ 0. Maximising: t − f(x, ωₖ) ≤ 0.
		for scenario in scenarios {
			var row = [Double](repeating: 0, count: variableCount)
			for i in 0..<dimension {
				let coefficient = minimize ? scenario.coefficients[i] : -scenario.coefficients[i]
				place(coefficient, forVariable: i, into: &row)
			}
			row[positiveEpigraph] = minimize ? -1 : 1
			row[negativeEpigraph] = minimize ? 1 : -1
			let rhs = minimize ? -scenario.constant : scenario.constant
			rows.append(SimplexConstraint(coefficients: row, relation: .lessOrEqual, rhs: rhs))
		}

		// The caller writes constraints as g(x) ≤ 0 or h(x) = 0, so the linearised
		// constant moves to the right-hand side with its sign flipped.
		for constraint in linearConstraints {
			var row = [Double](repeating: 0, count: variableCount)
			for i in 0..<dimension {
				place(constraint.coefficients[i], forVariable: i, into: &row)
			}
			let relation: ConstraintRelation = constraint.isEquality ? .equal : .lessOrEqual
			rows.append(SimplexConstraint(coefficients: row, relation: relation, rhs: -constraint.constant))
		}

		var objectiveCoefficients = [Double](repeating: 0, count: variableCount)
		objectiveCoefficients[positiveEpigraph] = 1
		objectiveCoefficients[negativeEpigraph] = -1

		// The rows above are built from finite-difference coefficients, which carry
		// roughly the differencing step's worth of error — far coarser than the
		// solver's default 1e-10. Left at that default, Phase I cannot drive the
		// artificial variables of an equality row below a residual the input noise
		// alone accounts for, and a plainly feasible program is reported infeasible.
		// The solver is told how good the data actually is.
		let solver = SimplexSolver(tolerance: Self.linearisationTolerance)
		let solved = minimize
			? try solver.minimize(objective: objectiveCoefficients, subjectTo: rows)
			: try solver.maximize(objective: objectiveCoefficients, subjectTo: rows)

		// An unbounded or infeasible linear program is a statement about the model,
		// not about this shortcut, but the general solver reports those differently
		// and its answer is the one the caller's tests are written against.
		guard solved.status == .optimal, solved.solution.count >= variableCount else { return nil }

		var components: [Double] = []
		components.reserveCapacity(dimension)
		for i in 0..<dimension {
			let positivePart = solved.solution[positiveColumn[i]]
			let negativePart = negativeColumn[i].map { solved.solution[$0] } ?? 0
			components.append(positivePart - negativePart)
		}

		// Check the answer against the constraints it was supposed to satisfy before
		// handing it back. `.optimal` is the solver's claim, not a proof — a degenerate
		// program has been observed to return that status on a point breaching its own
		// equality row by 3.7e-3 — and a robust allocation that quietly misses its
		// budget is the fail-silent result this library is not allowed to produce.
		// Falling through costs the general solver's time; returning it costs the
		// caller's trust.
		let feasibilityLimit = Swift.max(tolerance, Self.linearisationTolerance)
		for constraint in linearConstraints {
			let residual = zip(constraint.coefficients, components).reduce(constraint.constant) {
				$0 + $1.0 * $1.1
			}
			let breach = constraint.isEquality ? abs(residual) : residual
			guard breach <= feasibilityLimit else { return nil }
		}

		guard let solution = V.fromArray(components) else { return nil }
		return (solution, solved.iterations)
	}

	// MARK: - Worst case over the sampled realizations

	/// The worst sampled realization at `point`, and the parameters that produce it.
	///
	/// "Worst" is the largest value when minimizing and the smallest when
	/// maximizing, matching the sense the caller asked for. Reported over the same
	/// sampled set the solve used, so the value returned is the one the solution was
	/// actually chosen against rather than a bound taken over a different set.
	private static func worstCase(
		at point: V,
		objective: (V, [Double]) -> Double,
		uncertaintyPoints: [[Double]],
		nominalParameters: [Double],
		minimize: Bool
	) -> (value: Double, parameters: [Double]) {
		var worstValue = minimize ? -Double.infinity : Double.infinity
		var worstParameters = nominalParameters

		for omega in uncertaintyPoints {
			let value = objective(point, omega)
			let isWorse = minimize ? (value > worstValue) : (value < worstValue)
			if isWorse {
				worstValue = value
				worstParameters = omega
			}
		}

		return (worstValue, worstParameters)
	}
}

// MARK: - Convenience Extensions

extension RobustOptimizer {

	/// Optimize with box uncertainty set (convenience method).
	///
	/// - Parameters:
	///   - objective: Objective function f(x, ω)
	///   - nominal: Nominal parameter values
	///   - deviations: Maximum deviations for each parameter
	///   - initialSolution: Starting point
	///   - constraints: Constraints on decision variables
	///   - minimize: Whether to minimize worst-case
	///   - tolerance: The tolerance level. Defaults to 1e-6
	///   - samplesPerIteration: The number of samples taken per iteration. Defaults to 100
	///   - maxIterations: The maximum number of iterations. Defaults to 500
	/// - Returns: Robust optimization result
	public static func optimizeBox(
		objective: @escaping @Sendable (V, [Double]) -> Double,
		nominal: [Double],
		deviations: [Double],
		initialSolution: V,
		constraints: [MultivariateConstraint<V>] = [],
		minimize: Bool = true,
		samplesPerIteration: Int = 100,
		maxIterations: Int = 500,
		tolerance: Double = 1e-6
	) throws -> RobustResult<V> {

		let uncertaintySet = try BoxUncertaintySet(
			nominal: nominal,
			deviations: deviations
		)

		let optimizer = RobustOptimizer<V>(
			uncertaintySet: uncertaintySet,
			samplesPerIteration: samplesPerIteration,
			maxIterations: maxIterations,
			tolerance: tolerance
		)

		return try optimizer.optimize(
			objective: objective,
			nominalParameters: nominal,
			initialSolution: initialSolution,
			constraints: constraints,
			minimize: minimize
		)
	}

	/// Optimize with discrete uncertainty set (convenience method).
	///
	/// - Parameters:
	///   - objective: Objective function f(x, ω)
	///   - uncertainPoints: Discrete set of possible parameter values
	///   - nominalIndex: Index of nominal parameters in uncertainPoints
	///   - initialSolution: Starting point
	///   - constraints: Constraints on decision variables
	///   - minimize: Whether to minimize worst-case
	///   - tolerance: The tolerance level. Defaults to 1e-6
	///   - maxIterations: The maximum number of iterations. Defaults to 500
	/// - Returns: Robust optimization result
	public static func optimizeDiscrete(
		objective: @escaping @Sendable (V, [Double]) -> Double,
		uncertainPoints: [[Double]],
		nominalIndex: Int = 0,
		initialSolution: V,
		constraints: [MultivariateConstraint<V>] = [],
		minimize: Bool = true,
		maxIterations: Int = 500,
		tolerance: Double = 1e-6
	) throws -> RobustResult<V> {

		guard nominalIndex >= 0 && nominalIndex < uncertainPoints.count else {
			throw BusinessMathError.invalidInput(
				message: "Nominal index out of bounds",
				value: String(nominalIndex),
				expectedRange: "0 to \(uncertainPoints.count - 1)"
			)
		}

		let uncertaintySet = try DiscreteUncertaintySet(points: uncertainPoints)

		let optimizer = RobustOptimizer<V>(
			uncertaintySet: uncertaintySet,
			samplesPerIteration: uncertainPoints.count,
			maxIterations: maxIterations,
			tolerance: tolerance
		)

		return try optimizer.optimize(
			objective: objective,
			nominalParameters: uncertainPoints[nominalIndex],
			initialSolution: initialSolution,
			constraints: constraints,
			minimize: minimize
		)
	}
}

// MARK: - MultivariateOptimizer Protocol Conformance

extension RobustOptimizer: MultivariateOptimizer {
	/// Minimize a deterministic objective function (protocol method).
	///
	/// This method implements the ``MultivariateOptimizer`` protocol by treating the
	/// objective as deterministic (no parameter uncertainty). This is a simplified version
	/// that doesn't leverage robust optimization.
	///
	/// - Important: For true robust optimization with parameter uncertainty, use the
	///   specialized ``optimize(objective:nominalParameters:initialSolution:constraints:minimize:)``
	///   method which handles worst-case optimization over uncertain parameters. The protocol
	///   method treats the objective as deterministic.
	///
	/// - Parameters:
	///   - objective: Deterministic function to minimize f: V → ℝ (no uncertain parameters)
	///   - initialGuess: Starting point for optimization
	///   - constraints: Array of constraints
	/// - Returns: Optimization result (base protocol type)
	/// - Throws: ``OptimizationError`` if optimization fails
	/// - Note: The returned result is based on the deterministic objective, not worst-case
	///   analysis. Use the specialized ``optimize(objective:nominalParameters:initialSolution:constraints:minimize:)`` method for robust results with
	///   worst-case and nominal objective values.
	public func minimize(
		_ objective: @escaping @Sendable (V) -> V.Scalar,
		from initialGuess: V,
		constraints: [MultivariateConstraint<V>] = []
	) throws -> MultivariateOptimizationResult<V> {
		// For protocol conformance, treat objective as deterministic
		// Choose optimizer based on constraints
		let hasConstraints = !constraints.isEmpty
		let hasInequality = constraints.contains { !$0.isEquality }

		if hasConstraints {
			// Use constrained optimization
			let result: ConstrainedOptimizationResult<V>

			if hasInequality {
				let optimizer = InequalityOptimizer<V>(
					constraintTolerance: V.Scalar(tolerance),
					gradientTolerance: V.Scalar(tolerance),
					maxIterations: maxIterations
				)
				result = try optimizer.minimize(
					objective,
					from: initialGuess,
					subjectTo: constraints
				)
			} else {
				let optimizer = ConstrainedOptimizer<V>(
					constraintTolerance: V.Scalar(tolerance),
					gradientTolerance: V.Scalar(tolerance),
					maxIterations: maxIterations
				)
				result = try optimizer.minimize(
					objective,
					from: initialGuess,
					subjectTo: constraints
				)
			}

			// Convert to protocol result type
			return MultivariateOptimizationResult(
				solution: result.solution,
				value: result.objectiveValue,
				iterations: result.iterations,
				converged: result.converged,
				gradientNorm: 0.0,  // Not tracked for robust optimizer
				history: nil
			)
		} else {
			// Use unconstrained optimization
			let optimizer = MultivariateNewtonRaphson<V>(
				maxIterations: maxIterations,
				tolerance: V.Scalar(tolerance)
			)
			let gradient: (V) throws -> V = { point in
				try numericalGradient(objective, at: point)
			}
			let hessian: (V) throws -> [[V.Scalar]] = { point in
				try numericalHessian(objective, at: point)
			}

			return try optimizer.minimize(
				function: objective,
				gradient: gradient,
				hessian: hessian,
				initialGuess: initialGuess
			)
		}
	}
}

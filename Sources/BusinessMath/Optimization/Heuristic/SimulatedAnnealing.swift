//
//  SimulatedAnnealing.swift
//  BusinessMath
//
//  Created on December 30, 2025.
//

import Foundation
import Numerics

/// Simulated Annealing optimizer for continuous optimization problems.
///
/// Simulated Annealing (SA) is a probabilistic metaheuristic inspired by the annealing process
/// in metallurgy. It gradually cools a system to find low-energy (optimal) states by allowing
/// both improving and (probabilistically) worsening moves.
///
/// ## Algorithm Overview
///
/// SA iteratively:
/// 1. **Generate neighbor**: Perturb current solution randomly
/// 2. **Evaluate**: Compute energy change ΔE
/// 3. **Accept/reject**: Always accept better, probabilistically accept worse (e^(-ΔE/T))
/// 4. **Cool**: Reduce temperature T by cooling rate
/// 5. **Optional reheat**: Periodically increase temperature to escape local minima
///
/// ## Usage Example
///
/// ```swift
/// // Minimize Rosenbrock function
/// let optimizer = SimulatedAnnealing<VectorN<Double>>(
///     config: .default,
///     searchSpace: [(-5.0, 5.0), (-5.0, 5.0)]
/// )
///
/// let rosenbrock = { @Sendable (v: VectorN<Double>) -> Double in
///     let x = v[0], y = v[1]
///     return (1.0 - x) * (1.0 - x) + 100.0 * (y - x * x) * (y - x * x)
/// }
///
/// let result = try optimizer.minimize(rosenbrock, from: VectorN([0.0, 0.0]))
/// // result.solution ≈ [1.0, 1.0]
/// ```
///
/// ## Features
///
/// - **Temperature-based acceptance**: Accepts worse solutions with probability exp(-ΔE/T)
/// - **Geometric cooling**: T_new = α * T_old (configurable rate)
/// - **Boundary handling**: Clamps solutions to search space
/// - **Reheating**: Optional temperature increases to escape stagnation
/// - **Constraint support**: Equality/inequality constraints via penalty method
/// - **Deterministic**: Reproducible results with seed parameter
///
/// ## Performance
///
/// - Effective on multimodal functions with many local minima
/// - Works on non-differentiable, noisy objectives
/// - Slower than gradient methods but more robust
/// - Scales to 10-100 dimensions
///
/// ## Topics
///
/// ### Creating Optimizers
/// - ``init(config:searchSpace:)``
///
/// ### Optimization Methods
/// - ``minimize(_:from:constraints:)``
/// - ``optimizeDetailed(objective:initialSolution:)``
///
/// ### Related Types
/// - ``SimulatedAnnealingConfig``
/// - ``SimulatedAnnealingResult``
public struct SimulatedAnnealing<V: VectorSpace>: MultivariateOptimizer where V.Scalar: Real {

    // MARK: - Properties

    /// Configuration for the algorithm
    private let config: SimulatedAnnealingConfig

    /// Search space bounds for each dimension: [(min, max), ...]
    private let searchSpace: [(lower: V.Scalar, upper: V.Scalar)]

    /// Random number generator (seeded if config.seed is set)
    private let rng: RNGWrapper

    // MARK: - Initialization

    /// Create a simulated annealing optimizer.
    ///
    /// - Parameters:
    ///   - config: Algorithm configuration (temperature, cooling, etc.)
    ///   - searchSpace: Bounds for each dimension: `[(min, max), ...]`
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// // 2D problem with bounds [-10, 10] for both dimensions
    /// let optimizer = SimulatedAnnealing<VectorN<Double>>(
    ///     config: .default,
    ///     searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
    /// )
    /// ```
    public init(
        config: SimulatedAnnealingConfig = .default,
        searchSpace: [(lower: V.Scalar, upper: V.Scalar)]
    ) {
        self.config = config
        self.searchSpace = searchSpace

        // Initialize RNG with seed if provided
        if let seed = config.seed {
            self.rng = RNGWrapper(generator: SeededRandomNumberGenerator(seed: seed))
        } else {
            self.rng = RNGWrapper(generator: SystemRandomNumberGenerator()) // stochastic:exempt — the documented unseeded path; set `config.seed` for reproducibility
        }
    }

    // MARK: - MultivariateOptimizer Conformance

    /// Minimize an objective function using simulated annealing.
    ///
    /// - Parameters:
    ///   - objective: Function to minimize: `f: V → ℝ`
    ///   - initialGuess: Starting solution
    ///   - constraints: Optional equality/inequality constraints (handled via penalty method)
    ///
    /// - Returns: Optimization result with best solution and fitness
    ///
    /// - Throws: Never throws (constraints handled via penalty method)
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// let optimizer = SimulatedAnnealing<VectorN<Double>>(config: .default, searchSpace: [(-10.0, 10.0), (-10.0, 10.0)])
    /// let sphere = { @Sendable (v: VectorN<Double>) -> Double in v.dot(v) }
    /// let result = try optimizer.minimize(sphere, from: VectorN([5.0, 5.0]))
    /// ```
    public func minimize(
        _ objective: @escaping @Sendable (V) -> V.Scalar,
        from initialGuess: V,
        constraints: [MultivariateConstraint<V>] = []
    ) throws -> MultivariateOptimizationResult<V> {

        // If constraints provided, use penalty method
        if !constraints.isEmpty {
            return try minimizeWithPenalty(objective, initialSolution: initialGuess, constraints: constraints)
        }

        // Run unconstrained optimization
        let detailedResult = optimizeDetailed(objective: objective, initialSolution: initialGuess)

        // Convert to MultivariateOptimizationResult
        return MultivariateOptimizationResult(
            solution: detailedResult.solution,
            value: detailedResult.fitness,
            iterations: detailedResult.iterations,
            converged: detailedResult.converged,
            gradientNorm: V.Scalar.zero,  // Not gradient-based
            history: nil
        )
    }

    // MARK: - Detailed Optimization

    /// Run simulated annealing with detailed result tracking.
    ///
    /// - Parameters:
    ///   - objective: Function to minimize: `f: V → ℝ`
    ///   - initialSolution: Starting solution
    ///
    /// - Returns: Detailed result with convergence information
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// let rosenbrock: @Sendable (VectorN<Double>) -> Double = { v in let a = 1.0 - v[0]; let b = v[1] - v[0] * v[0]; return a * a + 100.0 * b * b }
    /// let optimizer = SimulatedAnnealing<VectorN<Double>>(config: .default, searchSpace: [(-10.0, 10.0), (-10.0, 10.0)])
    /// let result = optimizer.optimizeDetailed(
    ///     objective: rosenbrock,
    ///     initialSolution: VectorN([0.0, 0.0])
    /// )
    /// print("Final temperature: \(result.finalTemperature)")
    /// print("Acceptance rate: \(result.acceptanceRate)")
    /// ```
    public func optimizeDetailed(
        objective: @escaping (V) -> V.Scalar,
        initialSolution: V
    ) -> SimulatedAnnealingResult<V> {

        let dimension = searchSpace.count

        // Initialize current solution and best solution
        var currentSolution = clampToSearchSpace(initialSolution)
        var currentEnergy = objective(currentSolution)
        var evaluations = 1

        var bestSolution = currentSolution
        var bestEnergy = currentEnergy

        // Temperature state
        var temperature = config.initialTemperature

        // Acceptance tracking
        var acceptedMoves = 0
        var rejectedMoves = 0

        // Convergence tracking
        var convergenceHistory: [V.Scalar] = []
        var iteration = 0
        var converged = false
        var convergenceReason = ""

        // How many temperature levels have passed without the best improving. Counted in levels
        // rather than proposals: within a level the walker is meant to wander, so a quiet spell
        // there says nothing. This is what the old check got backwards — it terminated on 100
        // consecutive non-improving *proposals*, which is ordinary behaviour at high temperature,
        // and then reported `converged`. Measured before the change: 105 evaluations with the
        // temperature still at 0.48 against a target of 0.001, and on a slow schedule, 223
        // evaluations at a temperature of 97.8 out of an initial 100.
        var quietLevels = 0
        let quietLevelsAllowed = 40

        // Main annealing loop, one iteration per temperature level.
        while iteration < config.maxIterations && temperature > config.finalTemperature {
            iteration += 1

            // Optional reheating
            if let reheatInterval = config.reheatInterval,
               let reheatTemp = config.reheatTemperature,
               iteration % reheatInterval == 0 {
                temperature = reheatTemp
            }

            let levelEntryBest = bestEnergy

            // The inner Markov chain. Annealing works by letting the walker approach equilibrium
            // at a temperature before that temperature drops; a single proposal per level leaves
            // nothing to approach.
            for _ in 0..<config.movesPerTemperature {
            // Generate neighbor solution
            let neighbor = generateNeighbor(currentSolution, dimension: dimension, temperature: temperature)
            let neighborEnergy = objective(neighbor)
            evaluations += 1

            // Compute energy change
            let deltaE = neighborEnergy - currentEnergy

            // Acceptance decision
            let accepted: Bool
            if deltaE < V.Scalar.zero {
                // Always accept better solutions
                accepted = true
            } else {
                // Probabilistically accept worse solutions
                let probability = Self.acceptanceProbability(deltaE: deltaE, temperature: temperature)
                // Fixed: UInt32.max is 2^32 - 1, but shifted value ranges 0 to 2^32 - 1
                // Divide by 2^32 (1 << 32) to get proper [0, 1) range
                let randomValue = Double(rng.next() >> 32) / Double(1 << 32) // fp-safety:disable — divisor is 2^32
                accepted = randomValue < probability
            }

            if accepted {
                currentSolution = neighbor
                currentEnergy = neighborEnergy
                acceptedMoves += 1

                // Update best if improved
                if neighborEnergy < bestEnergy {
                    bestSolution = neighbor
                    bestEnergy = neighborEnergy
                }
            } else {
                rejectedMoves += 1
            }
            }

            // Record best energy, once per temperature level.
            convergenceHistory.append(bestEnergy)

            // Cool temperature
            temperature *= config.coolingRate

            // Stagnation, measured across temperature levels and only believed once the schedule
            // has actually cooled. Both halves matter: without the level counting it fires during
            // exploration, and without the temperature condition a run that has barely begun can
            // report that it finished.
            let improvement = levelEntryBest - bestEnergy
            let meaningful = V.Scalar(1) / V.Scalar(1_000_000)  // 1e-6
            quietLevels = improvement < meaningful ? quietLevels + 1 : 0

            // A thousandth of the starting temperature, not a tenth. At a tenth the schedule is
            // barely a third run: measured at `T₀/10`, seeds exited at T = 5.95 and T = 2.90 with
            // objectives of 0.154 and 0.229, while the seed that carried on to T = 0.089 reached
            // 0.0024. Stagnation is meant to trim a dead tail, not to end the anneal.
            let cooledEnough = temperature < config.initialTemperature / 1_000.0
            if quietLevels >= quietLevelsAllowed && cooledEnough {
                converged = true
                convergenceReason = "No improvement in \(quietLevelsAllowed) temperature levels at T = \(temperature)"
                break
            }
        }

        // Determine final convergence reason
        if !converged {
            if temperature <= config.finalTemperature {
                converged = true
                convergenceReason = "Temperature reached final value (\(config.finalTemperature))"
            } else {
                convergenceReason = "Maximum iterations reached"
            }
        }

        return SimulatedAnnealingResult(
            solution: bestSolution,
            fitness: bestEnergy,
            iterations: iteration,
            evaluations: evaluations,
            converged: converged,
            convergenceReason: convergenceReason,
            finalTemperature: temperature,
            acceptedMoves: acceptedMoves,
            rejectedMoves: rejectedMoves,
            convergenceHistory: convergenceHistory
        )
    }

    // MARK: - Metropolis Criterion

    /// Probability of accepting a candidate move under the Metropolis criterion.
    ///
    /// An improving (or neutral) move is always accepted. A worsening move is accepted
    /// with probability `exp(-ΔE / T)`, so the tolerance for worse solutions falls as
    /// the temperature falls.
    ///
    /// The arithmetic is done in `Double` because the temperature schedule
    /// (``SimulatedAnnealingConfig``) is expressed in `Double`. Widening `deltaE` from
    /// `V.Scalar` is exact for every `BinaryFloatingPoint` scalar narrower than or equal
    /// to `Double`, so nothing is lost relative to computing in the scalar type — and
    /// unlike a runtime cast it cannot fail and silently substitute a value.
    ///
    /// - Parameters:
    ///   - deltaE: Energy change of the candidate move (positive means worse).
    ///   - temperature: Current annealing temperature, strictly positive.
    /// - Returns: Acceptance probability in `[0, 1]`.
    static func acceptanceProbability(deltaE: V.Scalar, temperature: Double) -> Double {
        guard deltaE > V.Scalar.zero else { return 1.0 }
        guard temperature > 0 else { return 0.0 }
        return exp(-Double(deltaE) / temperature)
    }

    // MARK: - Private Helpers

    /// Generate a neighbor solution by randomly perturbing the current solution.
    ///
    /// - Parameters:
    ///   - current: Current solution
    ///   - dimension: Problem dimension
    ///
    /// - Returns: Neighbor solution clamped to search space
    /// A neighbour of `current`, perturbed by a step that shrinks as the system cools.
    ///
    /// The step is `perturbationScale × range × √(T / T₀)`, so the walker travels while hot and
    /// polishes while cold. It used to be `perturbationScale × range` regardless of temperature,
    /// which is why the scale had a problem-dependent sweet spot: measured on `min ‖x‖²` from
    /// (5, 5, 5), a scale of 0.2 gave a mean objective of 8.42, 0.01 gave 0.025, and 0.002 gave
    /// 34.78 — too coarse to refine at one end and too slow to travel at the other.
    ///
    /// The square root rather than the ratio itself: a Boltzmann walker's equilibrium spread
    /// goes as √T, so matching it keeps the acceptance rate roughly level down the schedule
    /// instead of collapsing it early.
    ///
    /// - Parameters:
    ///   - current: The point to perturb.
    ///   - dimension: The problem's dimension.
    ///   - temperature: The current temperature.
    /// - Returns: A neighbouring point, clamped to the search space.
    private func generateNeighbor(_ current: V, dimension: Int, temperature: Double) -> V {
        // Guarded rather than assumed: a caller may configure an initial temperature of zero,
        // and the ratio is only meaningful against a positive one.
        let reference = config.initialTemperature > 0 ? config.initialTemperature : 1.0
        let ratio = Swift.max(0.0, Swift.min(1.0, temperature / reference))
        // Floored so the step never reaches exactly zero, which would freeze the walker in place
        // for the remainder of the schedule rather than letting it polish.
        let coolingFactor = Swift.max(1e-3, ratio.squareRoot())

        let currentArray = current.toArray()
        var neighborComponents = [V.Scalar]()
        neighborComponents.reserveCapacity(dimension)

        for d in 0..<dimension {
            let (lower, upper) = searchSpace[d]
            let range = upper - lower

            // Gaussian perturbation scaled by perturbationScale and range
            let randRaw1 = rng.next()
            let randRaw2 = rng.next()

            // Gaussian via the package's shared Box-Muller transform.
            //
            // The seeds divide by 2^32, not by UInt32.max, giving the half-open
            // [0, 1) the transform needs — the same expression the acceptance
            // test above already uses. Dividing by UInt32.max produced a *closed*
            // [0, 1], and the guard that stood here, `log(u1 + 1e-10)`, turned
            // the upper endpoint into `sqrt(-2 · log(1 + 1e-10))`, the square
            // root of a negative number. The resulting NaN reached
            // `Int(scaledGaussian * 1_000_000)` below, and converting NaN to Int
            // in Swift traps rather than returning a wrong answer: one draw in
            // 2^32 took the process down. The shift also biased every other
            // draw, by 1.5e-02 in the radius at u1 = 1e-9.
            let u1 = Double(randRaw1 >> 32) / Double(UInt64(1) << 32) // fp-safety:disable — divisor is 2^32
            let u2 = Double(randRaw2 >> 32) / Double(UInt64(1) << 32) // fp-safety:disable — divisor is 2^32
            let (gaussian, _): (Double, Double) = boxMullerSeed(u1, u2)

            // Scale perturbation (convert through Int for generic safety)
            let scaledGaussian = config.perturbationScale * coolingFactor * gaussian
            let scaledInt = Int(scaledGaussian * 1_000_000)
            let perturbation = V.Scalar(scaledInt) / V.Scalar(1_000_000) * range

            // Apply perturbation and clamp
            let newValue = currentArray[d] + perturbation
            let clamped = min(max(newValue, lower), upper)
            neighborComponents.append(clamped)
        }

        guard let neighbor = V.fromArray(neighborComponents) else { return current }
        return neighbor
    }

    /// Clamp solution to search space bounds.
    ///
    /// - Parameter solution: Solution to clamp
    /// - Returns: Clamped solution
    private func clampToSearchSpace(_ solution: V) -> V {
        let array = solution.toArray()
        var clamped = [V.Scalar]()
        clamped.reserveCapacity(searchSpace.count)

        for (i, (lower, upper)) in searchSpace.enumerated() {
            clamped.append(min(max(array[i], lower), upper))
        }

        guard let result = V.fromArray(clamped) else { return solution }
        return result
    }

    // MARK: - Penalty Method for Constraints

    /// Minimize with constraints using penalty method.
    ///
    /// - Parameters:
    ///   - objective: Base objective function
    ///   - initialSolution: Starting solution
    ///   - constraints: Equality/inequality constraints
    ///
    /// - Returns: Optimization result
    /// Minimise subject to constraints.
    ///
    /// Delegates to ``penaltyConstrainedSolve(objective:constraints:options:minimise:)``, which
    /// this and four sibling optimizers each used to carry a copy of. The copies agreed on the
    /// penalty formula and on the defect: none of them checked whether the point they returned
    /// satisfied the constraints, so `converged` reported that the *unconstrained* search had
    /// settled and an infeasible answer was indistinguishable from a feasible one.
    private func minimizeWithPenalty(
        _ objective: @escaping @Sendable (V) -> V.Scalar,
        initialSolution: V,
        constraints: [MultivariateConstraint<V>]
    ) throws -> MultivariateOptimizationResult<V> {
        // No `try`: annealing's own search does not throw, so `rethrows` makes this call
        // non-throwing too. The enclosing method keeps `throws` for signature compatibility with
        // the five siblings, whose searches do.
        penaltyConstrainedSolve(
            objective: objective,
            constraints: constraints,
            options: PenaltySolveOptions(initialWeight: V.Scalar(config.constraintPenaltyWeight))
        ) { penalised in
            let detailed = optimizeDetailed(objective: penalised, initialSolution: initialSolution)
            return (detailed.solution, detailed.iterations, detailed.converged)
        }
    }
}

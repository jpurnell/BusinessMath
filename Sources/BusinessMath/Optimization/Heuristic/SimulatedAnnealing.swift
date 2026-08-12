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
/// let rosenbrock = { (v: VectorN<Double>) -> Double in
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
    /// let sphere = { (v: VectorN<Double>) -> Double in v.dot(v) }
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

        // Main annealing loop
        while iteration < config.maxIterations && temperature > config.finalTemperature {
            iteration += 1

            // Optional reheating
            if let reheatInterval = config.reheatInterval,
               let reheatTemp = config.reheatTemperature,
               iteration % reheatInterval == 0 {
                temperature = reheatTemp
            }

            // Generate neighbor solution
            let neighbor = generateNeighbor(currentSolution, dimension: dimension)
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
                let randomValue = Double(rng.next() >> 32) / Double(1 << 32) // fp-safety:disable
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

            // Record best energy
            convergenceHistory.append(bestEnergy)

            // Cool temperature
            temperature *= config.coolingRate

            // Check for convergence (no improvement for many iterations)
            if convergenceHistory.count >= 100 {
                let recentHistory = convergenceHistory.suffix(100)
                // Safe: count check above guarantees at least 100 elements
                if let first = recentHistory.first, let last = recentHistory.last {
                    let improvement = first - last
                    if improvement < V.Scalar(1) / V.Scalar(1_000_000) {  // 1e-6
                        converged = true
                        convergenceReason = "No significant improvement in last 100 iterations"
                        break
                    }
                }
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
    private func generateNeighbor(_ current: V, dimension: Int) -> V {
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
            let u1 = Double(randRaw1 >> 32) / Double(UInt64(1) << 32) // fp-safety:disable
            let u2 = Double(randRaw2 >> 32) / Double(UInt64(1) << 32) // fp-safety:disable
            let (gaussian, _): (Double, Double) = boxMullerSeed(u1, u2)

            // Scale perturbation (convert through Int for generic safety)
            let scaledGaussian = config.perturbationScale * gaussian
            let scaledInt = Int(scaledGaussian * 1_000_000)
            let perturbation = V.Scalar(scaledInt) / V.Scalar(1_000_000) * range // fp-safety:disable

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
    private func minimizeWithPenalty(
        _ objective: @escaping @Sendable (V) -> V.Scalar,
        initialSolution: V,
        constraints: [MultivariateConstraint<V>]
    ) throws -> MultivariateOptimizationResult<V> {

        // Penalty weight
        let penaltyWeight: V.Scalar = 100

        // Create penalized objective
        let penalizedObjective: (V) -> V.Scalar = { solution in
            let baseValue = objective(solution)

            // Calculate constraint violations
            var penalty = V.Scalar.zero
            for constraint in constraints {
                let violation: V.Scalar
                switch constraint {
                case .equality(function: let g, gradient: _):
                    let gVal = g(solution)
                    violation = gVal * gVal
                case .inequality(function: let g, gradient: _):
                    let gVal = g(solution)
                    violation = max(V.Scalar.zero, gVal) * max(V.Scalar.zero, gVal)
                case .linearInequality, .linearEquality:
                    let g = constraint.function
                    let gVal = g(solution)
                    if constraint.isEquality {
                        violation = gVal * gVal
                    } else {
                        violation = max(V.Scalar.zero, gVal) * max(V.Scalar.zero, gVal)
                    }
                }
                penalty += violation
            }

            return baseValue + penaltyWeight * penalty
        }

        // Run optimization with penalized objective
        let detailedResult = optimizeDetailed(
            objective: penalizedObjective,
            initialSolution: initialSolution
        )

        return MultivariateOptimizationResult(
            solution: detailedResult.solution,
            value: objective(detailedResult.solution),  // Return unpenalized value
            iterations: detailedResult.iterations,
            converged: detailedResult.converged,
            gradientNorm: V.Scalar.zero,
            history: nil
        )
    }
}

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
            self.rng = RNGWrapper(generator: SystemRandomNumberGenerator())
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
        _ objective: @escaping (V) -> V.Scalar,
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
                // Convert deltaE to Double for exp calculation
                let deltaEInt = Int((deltaE as! Double) * 1_000_000)
                let deltaEDouble = Double(deltaEInt) / 1_000_000.0
                let probability = exp(-deltaEDouble / temperature)
                let randomValue = Double(rng.next() >> 32) / Double(UInt32.max)
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
                let improvement = recentHistory.first! - recentHistory.last!
                if improvement < V.Scalar(1) / V.Scalar(1_000_000) {  // 1e-6
                    converged = true
                    convergenceReason = "No significant improvement in last 100 iterations"
                    break
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

            // Box-Muller transform for Gaussian random
            let u1 = Double(randRaw1 >> 32) / Double(UInt32.max)
            let u2 = Double(randRaw2 >> 32) / Double(UInt32.max)
            let gaussian = sqrt(-2.0 * log(u1 + 1e-10)) * cos(2.0 * .pi * u2)

            // Scale perturbation (convert through Int for generic safety)
            let scaledGaussian = config.perturbationScale * gaussian
            let scaledInt = Int(scaledGaussian * 1_000_000)
            let perturbation = V.Scalar(scaledInt) / V.Scalar(1_000_000) * range

            // Apply perturbation and clamp
            let newValue = currentArray[d] + perturbation
            let clamped = min(max(newValue, lower), upper)
            neighborComponents.append(clamped)
        }

        return V.fromArray(neighborComponents)!
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

        return V.fromArray(clamped)!
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
        _ objective: @escaping (V) -> V.Scalar,
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

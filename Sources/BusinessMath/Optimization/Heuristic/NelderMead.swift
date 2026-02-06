//
//  NelderMead.swift
//  BusinessMath
//
//  Created on December 30, 2025.
//

import Foundation
import Numerics

/// Nelder-Mead simplex optimizer for continuous optimization.
///
/// The Nelder-Mead method (also called downhill simplex method) is a derivative-free optimization
/// algorithm that maintains a simplex of n+1 points in n-dimensional space and iteratively
/// transforms it toward the minimum using reflection, expansion, contraction, and shrink operations.
///
/// ## Algorithm Overview
///
/// The algorithm maintains a simplex and performs:
/// 1. **Order**: Sort vertices by function value (best to worst)
/// 2. **Centroid**: Compute centroid of all vertices except worst
/// 3. **Reflection**: Reflect worst point through centroid
/// 4. **Expansion**: If reflection is very good, try expanding further
/// 5. **Contraction**: If reflection is bad, contract toward better point
/// 6. **Shrink**: If contraction fails, shrink entire simplex toward best
///
/// ## Usage Example
///
/// ```swift
/// // Minimize Rosenbrock function
/// let optimizer = NelderMead<VectorN<Double>>(config: .default)
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
/// - **Derivative-free**: No gradient computation required
/// - **Simplex-based search**: Geometric approach to optimization
/// - **Adaptive**: Simplex shape adapts to function landscape
/// - **Non-smooth functions**: Works on discontinuous, noisy objectives
/// - **Constraint support**: Equality/inequality constraints via penalty method
///
/// ## Performance
///
/// - Effective on smooth, unimodal functions
/// - Works well for 1-10 dimensions
/// - Slower than gradient methods but more robust
/// - May struggle with high dimensions (>20)
/// - No guarantee of global optimum
///
/// ## Topics
///
/// ### Creating Optimizers
/// - ``init(config:)``
///
/// ### Optimization Methods
/// - ``minimize(_:from:constraints:)``
/// - ``optimizeDetailed(objective:initialGuess:)``
///
/// ### Related Types
/// - ``NelderMeadConfig``
/// - ``NelderMeadResult``
public struct NelderMead<V: VectorSpace>: MultivariateOptimizer where V.Scalar: Real {

    // MARK: - Properties

    /// Configuration for the algorithm
    private let config: NelderMeadConfig

    // MARK: - Initialization

    /// Create a Nelder-Mead optimizer.
    ///
    /// - Parameter config: Algorithm configuration (coefficients, tolerance, etc.)
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// let optimizer = NelderMead<VectorN<Double>>(config: .default)
    /// ```
    public init(config: NelderMeadConfig = .default) {
        self.config = config
    }

    // MARK: - MultivariateOptimizer Conformance

    /// Minimize an objective function using Nelder-Mead method.
    ///
    /// - Parameters:
    ///   - objective: Function to minimize: `f: V → ℝ`
    ///   - initialGuess: Starting point for optimization
    ///   - constraints: Optional equality/inequality constraints (handled via penalty method)
    ///
    /// - Returns: Optimization result with best solution and value
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
            return try minimizeWithPenalty(objective, initialGuess: initialGuess, constraints: constraints)
        }

        // Run unconstrained optimization
        let detailedResult = optimizeDetailed(objective: objective, initialGuess: initialGuess)

        // Convert to MultivariateOptimizationResult
        return MultivariateOptimizationResult(
            solution: detailedResult.solution,
            value: detailedResult.value,
            iterations: detailedResult.iterations,
            converged: detailedResult.converged,
            gradientNorm: V.Scalar.zero,  // Not gradient-based
            history: nil
        )
    }

    // MARK: - Detailed Optimization

    /// Run Nelder-Mead optimization with detailed result tracking.
    ///
    /// - Parameters:
    ///   - objective: Function to minimize: `f: V → ℝ`
    ///   - initialGuess: Starting point
    ///
    /// - Returns: Detailed result with convergence information
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// let result = optimizer.optimizeDetailed(
    ///     objective: rosenbrock,
    ///     initialGuess: VectorN([0.0, 0.0])
    /// )
    /// print("Final simplex size: \(result.finalSimplexSize)")
    /// ```
    public func optimizeDetailed(
        objective: @escaping (V) -> V.Scalar,
        initialGuess: V
    ) -> NelderMeadResult<V> {

        let dimension = initialGuess.toArray().count
        var evaluations = 0

        // Initialize simplex with n+1 vertices
        var simplex = initializeSimplex(around: initialGuess, size: config.initialSimplexSize)

        // Evaluate function at each vertex
        var values = simplex.map { vertex in
            evaluations += 1
            return objective(vertex)
        }

        // Convergence tracking
        var convergenceHistory: [V.Scalar] = []
        var iteration = 0
        var converged = false
        var convergenceReason = ""

        // Main optimization loop
        while iteration < config.maxIterations {
            iteration += 1

            // Sort simplex by function value (ascending)
            let sortedIndices = values.indices.sorted { values[$0] < values[$1] }
            simplex = sortedIndices.map { simplex[$0] }
            values = sortedIndices.map { values[$0] }

            // Record best value
            convergenceHistory.append(values[0])

            // Check convergence (simplex size)
            let simplexSize = computeSimplexSize(simplex)
            let toleranceInt = Int(config.tolerance * 1_000_000)
            let toleranceScalar = V.Scalar(toleranceInt) / V.Scalar(1_000_000)
            if simplexSize < toleranceScalar {
                converged = true
                convergenceReason = "Simplex size below tolerance (\(config.tolerance))"
                break
            }

            // Get best, worst, and second worst
            let best = simplex[0]
            let worst = simplex[dimension]	

            // Compute centroid of all points except worst
            let centroid = computeCentroid(simplex, excluding: dimension)

            // Reflection: reflect worst point through centroid
            let reflected = reflect(worst, through: centroid, coefficient: config.reflectionCoefficient)
            let reflectedValue = objective(reflected)
            evaluations += 1

            if reflectedValue < values[0] {
                // Reflected point is better than best: try expansion
                let expanded = expand(reflected, from: centroid, coefficient: config.expansionCoefficient)
                let expandedValue = objective(expanded)
                evaluations += 1

                if expandedValue < reflectedValue {
                    // Expansion succeeded
                    simplex[dimension] = expanded
                    values[dimension] = expandedValue
                } else {
                    // Reflection is better
                    simplex[dimension] = reflected
                    values[dimension] = reflectedValue
                }
            } else if reflectedValue < values[dimension - 1] {
                // Reflected point is better than second worst: accept reflection
                simplex[dimension] = reflected
                values[dimension] = reflectedValue
            } else {
                // Reflected point is not good: try contraction
                var contracted: V
                var contractedValue: V.Scalar

                if reflectedValue < values[dimension] {
                    // Outside contraction
                    contracted = contract(reflected, toward: centroid, coefficient: config.contractionCoefficient)
                } else {
                    // Inside contraction
                    contracted = contract(worst, toward: centroid, coefficient: config.contractionCoefficient)
                }

                contractedValue = objective(contracted)
                evaluations += 1

                if contractedValue < min(reflectedValue, values[dimension]) {
                    // Contraction succeeded
                    simplex[dimension] = contracted
                    values[dimension] = contractedValue
                } else {
                    // Contraction failed: shrink entire simplex toward best
                    for i in 1...dimension {
                        simplex[i] = shrink(simplex[i], toward: best, coefficient: config.shrinkCoefficient)
                        values[i] = objective(simplex[i])
                        evaluations += 1
                    }
                }
            }

            // Check for stagnation
            if convergenceHistory.count >= 50 {
                let recent = convergenceHistory.suffix(50)
                let improvement = recent.first! - recent.last!
                if improvement < V.Scalar(1) / V.Scalar(1_000_000) {  // 1e-6
                    converged = true
                    convergenceReason = "No improvement in last 50 iterations"
                    break
                }
            }
        }

        // Final convergence reason
        if !converged {
            convergenceReason = "Maximum iterations reached"
        }

        // Return best solution
        let sortedIndices = values.indices.sorted { values[$0] < values[$1] }
        let bestSolution = simplex[sortedIndices[0]]
        let bestValue = values[sortedIndices[0]]
        let finalSimplexSize = computeSimplexSize(simplex)

        return NelderMeadResult(
            solution: bestSolution,
            value: bestValue,
            iterations: iteration,
            evaluations: evaluations,
            converged: converged,
            convergenceReason: convergenceReason,
            finalSimplexSize: finalSimplexSize,
            convergenceHistory: convergenceHistory
        )
    }

    // MARK: - Private Helpers

    /// Initialize simplex around a starting point.
    ///
    /// Creates n+1 vertices: one at the starting point and n others displaced
    /// along each coordinate axis.
    ///
    /// - Parameters:
    ///   - center: Starting point
    ///   - size: Size of initial simplex
    ///
    /// - Returns: Array of n+1 vertices
    private func initializeSimplex(around center: V, size: Double) -> [V] {
        let dimension = center.toArray().count
        var simplex: [V] = []
        simplex.reserveCapacity(dimension + 1)

        // First vertex at center
        simplex.append(center)

        // Create n additional vertices displaced along each axis
        let centerArray = center.toArray()
        for d in 0..<dimension {
            var components = centerArray
            // Convert size to V.Scalar via Int
            let sizeInt = Int(size * 1_000_000)
            let displacement = V.Scalar(sizeInt) / V.Scalar(1_000_000)
            components[d] += displacement
            simplex.append(V.fromArray(components)!)
        }

        return simplex
    }

    /// Compute centroid of simplex vertices, excluding one index.
    ///
    /// - Parameters:
    ///   - simplex: Array of vertices
    ///   - excludeIndex: Index to exclude from centroid
    ///
    /// - Returns: Centroid point
    private func computeCentroid(_ simplex: [V], excluding excludeIndex: Int) -> V {
        let dimension = simplex[0].toArray().count
        var sum = [V.Scalar](repeating: V.Scalar.zero, count: dimension)

        for (i, vertex) in simplex.enumerated() {
            if i == excludeIndex { continue }
            let array = vertex.toArray()
            for d in 0..<dimension {
                sum[d] += array[d]
            }
        }

        // Divide by number of vertices (excluding one)
        let count = V.Scalar(simplex.count - 1)
        for d in 0..<dimension {
            sum[d] /= count
        }

        return V.fromArray(sum)!
    }

    /// Reflect a point through the centroid.
    ///
    /// - Parameters:
    ///   - point: Point to reflect
    ///   - centroid: Centroid point
    ///   - coefficient: Reflection coefficient (typically 1.0)
    ///
    /// - Returns: Reflected point
    private func reflect(_ point: V, through centroid: V, coefficient: Double) -> V {
        // reflected = centroid + α * (centroid - point)
        let pointArray = point.toArray()
        let centroidArray = centroid.toArray()
        var result = [V.Scalar]()
        result.reserveCapacity(pointArray.count)

        let alphaInt = Int(coefficient * 1_000_000)
        let alpha = V.Scalar(alphaInt) / V.Scalar(1_000_000)

        for d in 0..<pointArray.count {
            result.append(centroidArray[d] + alpha * (centroidArray[d] - pointArray[d]))
        }

        return V.fromArray(result)!
    }

    /// Expand a point away from the centroid.
    ///
    /// - Parameters:
    ///   - point: Point to expand from
    ///   - centroid: Centroid point
    ///   - coefficient: Expansion coefficient (typically 2.0)
    ///
    /// - Returns: Expanded point
    private func expand(_ point: V, from centroid: V, coefficient: Double) -> V {
        // expanded = centroid + γ * (point - centroid)
        let pointArray = point.toArray()
        let centroidArray = centroid.toArray()
        var result = [V.Scalar]()
        result.reserveCapacity(pointArray.count)

        let gammaInt = Int(coefficient * 1_000_000)
        let gamma = V.Scalar(gammaInt) / V.Scalar(1_000_000)

        for d in 0..<pointArray.count {
            result.append(centroidArray[d] + gamma * (pointArray[d] - centroidArray[d]))
        }

        return V.fromArray(result)!
    }

    /// Contract a point toward the centroid.
    ///
    /// - Parameters:
    ///   - point: Point to contract
    ///   - centroid: Centroid point
    ///   - coefficient: Contraction coefficient (typically 0.5)
    ///
    /// - Returns: Contracted point
    private func contract(_ point: V, toward centroid: V, coefficient: Double) -> V {
        // contracted = centroid + ρ * (point - centroid)
        let pointArray = point.toArray()
        let centroidArray = centroid.toArray()
        var result = [V.Scalar]()
        result.reserveCapacity(pointArray.count)

        let rhoInt = Int(coefficient * 1_000_000)
        let rho = V.Scalar(rhoInt) / V.Scalar(1_000_000)

        for d in 0..<pointArray.count {
            result.append(centroidArray[d] + rho * (pointArray[d] - centroidArray[d]))
        }

        return V.fromArray(result)!
    }

    /// Shrink a point toward another point.
    ///
    /// - Parameters:
    ///   - point: Point to shrink
    ///   - target: Target point (typically best vertex)
    ///   - coefficient: Shrink coefficient (typically 0.5)
    ///
    /// - Returns: Shrunk point
    private func shrink(_ point: V, toward target: V, coefficient: Double) -> V {
        // shrunk = target + σ * (point - target)
        let pointArray = point.toArray()
        let targetArray = target.toArray()
        var result = [V.Scalar]()
        result.reserveCapacity(pointArray.count)

        let sigmaInt = Int(coefficient * 1_000_000)
        let sigma = V.Scalar(sigmaInt) / V.Scalar(1_000_000)

        for d in 0..<pointArray.count {
            result.append(targetArray[d] + sigma * (pointArray[d] - targetArray[d]))
        }

        return V.fromArray(result)!
    }

    /// Compute diameter of simplex (maximum distance between vertices).
    ///
    /// - Parameter simplex: Array of vertices
    /// - Returns: Maximum distance between any two vertices
    private func computeSimplexSize(_ simplex: [V]) -> V.Scalar {
        var maxDistance = V.Scalar.zero

        for i in 0..<simplex.count {
            for j in (i+1)..<simplex.count {
                let diff = simplex[i] - simplex[j]
                let distance = diff.norm
                if distance > maxDistance {
                    maxDistance = distance
                }
            }
        }

        return maxDistance
    }

    // MARK: - Penalty Method for Constraints

    /// Minimize with constraints using penalty method.
    ///
    /// - Parameters:
    ///   - objective: Base objective function
    ///   - initialGuess: Starting point
    ///   - constraints: Equality/inequality constraints
    ///
    /// - Returns: Optimization result
    private func minimizeWithPenalty(
        _ objective: @escaping @Sendable (V) -> V.Scalar,
        initialGuess: V,
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
            initialGuess: initialGuess
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

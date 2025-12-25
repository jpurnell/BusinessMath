import Foundation
import Numerics

/// Protocol for multivariate optimization algorithms.
///
/// `MultivariateOptimizer` provides a unified interface for all multivariate optimization algorithms in BusinessMath.
/// This enables algorithm swapping, comparison, and factory patterns while maintaining type safety.
///
/// ## Overview
///
/// Conforming types solve optimization problems of the form:
/// ```
/// minimize f(v) where v ∈ V, f: V → ℝ
/// ```
///
/// The protocol supports both unconstrained and constrained optimization. Unconstrained optimizers
/// simply ignore the `constraints` parameter, while constrained optimizers validate and enforce them.
///
/// ## Usage Example
///
/// ```swift
/// // Using the protocol for algorithm flexibility
/// let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateGradientDescent(
///     learningRate: 0.01,
///     maxIterations: 1000,
///     tolerance: 0.0001
/// )
///
/// let objective = { (v: VectorN<Double>) -> Double in
///     v.dot(v)  // f(x,y) = x² + y²
/// }
///
/// let result = try optimizer.minimize(objective, from: VectorN([5.0, 5.0]))
/// print("Solution: \(result.solution)")  // Near [0, 0]
/// print("Objective: \(result.objectiveValue)")  // Near 0
/// ```
///
/// ## Algorithm Swapping
///
/// The protocol enables runtime algorithm selection:
///
/// ```swift
/// func optimizePortfolio(
///     riskTolerance: Double
/// ) -> any MultivariateOptimizer<VectorN<Double>> {
///     if riskTolerance > 0.5 {
///         return MultivariateGradientDescent(learningRate: 0.01, maxIterations: 1000)
///     } else {
///         return MultivariateNewtonRaphson(tolerance: 0.0001, maxIterations: 100)
///     }
/// }
/// ```
///
/// ## Conforming Types
///
/// BusinessMath provides eight optimizer types that conform to this protocol:
///
/// **Unconstrained Optimizers:**
/// - ``MultivariateGradientDescent`` - First-order gradient methods (basic, momentum, Adam)
/// - ``MultivariateNewtonRaphson`` - Second-order Newton methods (Newton, BFGS, L-BFGS)
///
/// **Constrained Optimizers:**
/// - ``ConstrainedOptimizer`` - Equality constraints only (Lagrange multipliers)
/// - ``InequalityOptimizer`` - Mixed equality/inequality constraints (KKT conditions)
///
/// **Advanced Optimizers:**
/// - ``AdaptiveOptimizer`` - Automatic algorithm selection based on problem characteristics
/// - ``ParallelOptimizer`` - Multi-start parallel optimization for global minimum
/// - ``StochasticOptimizer`` - Scenario-based optimization under uncertainty
/// - ``RobustOptimizer`` - Optimization with uncertain parameters
///
/// ## When to Use the Protocol vs Concrete Types
///
/// **Use the protocol when:**
/// - Algorithm selection happens at runtime
/// - Writing generic optimization code
/// - Testing business logic with mock optimizers
/// - Comparing multiple algorithms
///
/// **Use concrete types when:**
/// - You need algorithm-specific methods (e.g., `minimizeAdam()`, `minimizeBFGS()`)
/// - You need specialized result types (e.g., `ConstrainedOptimizationResult` with Lagrange multipliers)
/// - Performance is critical (avoids protocol dispatch overhead, though minimal)
///
/// ## Implementation Notes for Conforming Types
///
/// When implementing this protocol:
/// 1. Validate constraints if supported, throw ``OptimizationError/unsupportedConstraints(_:)`` if not
/// 2. Return ``MultivariateOptimizationResult`` from the protocol method
/// 3. Optionally provide algorithm-specific methods returning specialized result types
/// 4. Document which constraint types are supported
///
/// ## Topics
///
/// ### Core Method
/// - ``minimize(_:from:constraints:)``
///
/// ### Convenience Method
/// - ``minimize(_:from:)-4yx7g``
///
/// ### Conforming Types
/// - ``MultivariateGradientDescent``
/// - ``MultivariateNewtonRaphson``
/// - ``ConstrainedOptimizer``
/// - ``InequalityOptimizer``
/// - ``AdaptiveOptimizer``
/// - ``ParallelOptimizer``
/// - ``StochasticOptimizer``
/// - ``RobustOptimizer``
///
/// ### Related Types
/// - ``MultivariateOptimizationResult``
/// - ``MultivariateConstraint``
/// - ``OptimizationError``
/// - ``VectorSpace``
public protocol MultivariateOptimizer<V> {
    /// Vector space type (e.g., `VectorN<Double>`, `Vector2D<Double>`, `Vector3D<Double>`)
    associatedtype V: VectorSpace where V.Scalar: Real

    /// Minimize an objective function over a vector space.
    ///
    /// This is the core optimization method required by the protocol. Conforming types
    /// should implement this method to delegate to their specific optimization algorithm.
    ///
    /// - Parameters:
    ///   - objective: Function to minimize mapping vectors to scalars: `f: V → ℝ`
    ///   - initialGuess: Starting point for the optimization search
    ///   - constraints: Optimization constraints (default: empty array).
    ///     Unconstrained optimizers ignore this parameter and should throw
    ///     ``OptimizationError/unsupportedConstraints(_:)`` if constraints are provided.
    ///     Constrained optimizers validate constraint types they support.
    ///
    /// - Returns: Optimization result containing:
    ///   - `solution`: The optimal point found (or best approximation)
    ///   - `objectiveValue`: Value of objective function at solution
    ///   - `iterations`: Number of iterations performed
    ///   - `convergenceReason`: Description of why optimization stopped
    ///
    /// - Throws:
    ///   - ``OptimizationError/unsupportedConstraints(_:)`` if constraints not supported
    ///   - ``OptimizationError/convergenceFailed`` if optimization fails to converge
    ///   - ``OptimizationError/invalidInitialGuess`` if starting point is invalid
    ///   - ``OptimizationError/singularMatrix`` if numerical issues occur (Newton methods)
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// let optimizer: any MultivariateOptimizer<VectorN<Double>> =
    ///     MultivariateGradientDescent(learningRate: 0.01, maxIterations: 1000)
    ///
    /// // Minimize f(x,y) = x² + y²
    /// let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }
    ///
    /// // Unconstrained optimization
    /// let result = try optimizer.minimize(objective, from: VectorN([5.0, 5.0]))
    /// print("Solution: \(result.solution)")  // Near [0, 0]
    ///
    /// // Constrained optimization (requires constrained optimizer)
    /// let constrainedOpt: any MultivariateOptimizer<VectorN<Double>> =
    ///     InequalityOptimizer()
    ///
    /// let constraint: MultivariateConstraint<VectorN<Double>> = .equality { v in v[0] - 1.0 }
    /// let constrainedResult = try constrainedOpt.minimize(
    ///     objective,
    ///     from: VectorN([5.0, 5.0]),
    ///     constraints: [constraint]
    /// )
    /// ```
    ///
    /// ## Implementation Guidance
    ///
    /// Typical implementation pattern for unconstrained optimizers:
    ///
    /// ```swift
    /// extension MultivariateGradientDescent: MultivariateOptimizer {
    ///     public func minimize(
    ///         _ objective: @escaping (V) -> V.Scalar,
    ///         from initialGuess: V,
    ///         constraints: [MultivariateConstraint<V>] = []
    ///     ) throws -> MultivariateOptimizationResult<V> {
    ///         // Reject constraints (unconstrained optimizer)
    ///         guard constraints.isEmpty else {
    ///             throw OptimizationError.unsupportedConstraints(
    ///                 "MultivariateGradientDescent only supports unconstrained optimization"
    ///             )
    ///         }
    ///
    ///         // Delegate to existing implementation
    ///         return try minimize(function: objective, initialGuess: initialGuess)
    ///     }
    /// }
    /// ```
    ///
    /// - SeeAlso:
    ///   - ``minimize(_:from:)-4yx7g`` for convenience method without constraints
    ///   - ``MultivariateOptimizationResult`` for result type details
    ///   - ``MultivariateConstraint`` for constraint specification
    func minimize(
        _ objective: @escaping (V) -> V.Scalar,
        from initialGuess: V,
        constraints: [MultivariateConstraint<V>]
    ) throws -> MultivariateOptimizationResult<V>
}

/// Default implementations for convenience
extension MultivariateOptimizer {
    /// Minimize an objective function without constraints (convenience method).
    ///
    /// This is a convenience wrapper that calls the core ``minimize(_:from:constraints:)``
    /// method with an empty constraints array. Use this when solving unconstrained
    /// optimization problems for cleaner syntax.
    ///
    /// - Parameters:
    ///   - objective: Function to minimize mapping vectors to scalars: `f: V → ℝ`
    ///   - initialGuess: Starting point for the optimization search
    ///
    /// - Returns: Optimization result containing solution, objective value, iterations, and convergence reason
    ///
    /// - Throws: Same errors as ``minimize(_:from:constraints:)``
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// let optimizer: any MultivariateOptimizer<VectorN<Double>> =
    ///     MultivariateGradientDescent(learningRate: 0.01, maxIterations: 1000)
    ///
    /// let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }
    ///
    /// // Cleaner syntax - no need to specify constraints parameter
    /// let result = try optimizer.minimize(objective, from: VectorN([5.0, 5.0]))
    /// ```
    ///
    /// - SeeAlso: ``minimize(_:from:constraints:)`` for constrained optimization
    public func minimize(
        _ objective: @escaping (V) -> V.Scalar,
        from initialGuess: V
    ) throws -> MultivariateOptimizationResult<V> {
        try minimize(objective, from: initialGuess, constraints: [])
    }
}

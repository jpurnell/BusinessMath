//
//  StochasticProcess.swift
//  BusinessMath
//
//  Core protocol for continuous-time stochastic processes.
//

/// A continuous-time stochastic process that evolves state through time.
///
/// Conforming types define the dynamics (drift, diffusion, jumps) for a
/// specific asset or factor. The ``State`` associated type determines
/// dimensionality: `Double` for scalar processes (GBM, OU), `VectorN<Double>`
/// for multi-factor processes (Hull-White, LMM, Heston).
///
/// ## Implementing a Custom Process
///
/// ```swift
/// struct MyProcess: StochasticProcess {
///     typealias State = Double
///     let name = "MyProcess"
///     let allowsNegativeValues = false
///     let factors = 1
///
///     func step(from current: Double, dt: Double, normalDraws: Double) -> Double {
///         // Your dynamics here
///     }
/// }
/// ```
///
/// ## Design Note
///
/// The process defines only the single-step dynamics. Path generation,
/// correlation handling, and Monte Carlo orchestration are handled by
/// the simulation kernel (in BusinessMathPro), which calls `step()`
/// repeatedly with correlated normal draws.
public protocol StochasticProcess: Sendable {
    /// The state type: `Double` for scalar, `VectorN<Double>` for multi-factor.
    associatedtype State: ProcessState

    /// The process name for audit trails and provenance.
    var name: String { get }

    /// Evolve the state by one time step.
    ///
    /// - Parameters:
    ///   - current: Current state value.
    ///   - dt: Time step in years.
    ///   - normalDraws: Standard normal draw(s) provided by the simulation engine.
    ///     For scalar processes, a single `Double`. For multi-factor, a vector.
    /// - Returns: The next state value.
    func step(from current: State, dt: State.Scalar, normalDraws: State.NormalDraws) -> State

    /// Whether this process can produce negative values in any component.
    ///
    /// - `false` for GBM (log-space ensures positivity)
    /// - `true` for OU, ABM (mean-reversion and arithmetic drift allow negatives)
    var allowsNegativeValues: Bool { get }

    /// The number of independent Brownian motions driving this process.
    ///
    /// For scalar processes, this is 1. For multi-factor processes (e.g., Heston
    /// with correlated spot and variance), this equals the number of independent
    /// noise sources.
    var factors: Int { get }
}

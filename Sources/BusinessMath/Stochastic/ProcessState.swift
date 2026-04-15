//
//  ProcessState.swift
//  BusinessMath
//
//  Conformance bridge for scalar and vector process states.
//

import RealModule

/// The state type of a stochastic process.
///
/// `ProcessState` bridges scalar processes (commodity prices, interest rates)
/// and multi-factor processes (yield curves, correlated asset pairs) under
/// a single protocol. Scalar processes use `Double` as their state; multi-factor
/// processes use `VectorN<Double>`.
///
/// ## Conformance
///
/// `Double` conforms out of the box via its existing `VectorSpace` conformance
/// (which already provides `Scalar` and `dimension`):
///
/// ```swift
/// // Scalar process — state is a single number
/// struct GBM: StochasticProcess {
///     typealias State = Double  // ProcessState via extension
/// }
/// ```
///
/// For multi-factor processes in BusinessMathPro, `VectorN<Double>`
/// conforms separately with `dimension` determined at runtime.
public protocol ProcessState: Sendable {
    /// The scalar type for arithmetic operations.
    associatedtype Scalar: Real & Sendable

    /// The type for normal draws consumed by the process step function.
    /// For scalar processes, this is `Scalar` (a single draw).
    /// For vector processes, this matches the state dimension.
    associatedtype NormalDraws: Sendable

    /// The dimensionality of the state space.
    /// Returns 1 for scalar processes.
    static var dimension: Int { get }
}

// MARK: - Double Conformance

/// Double conforms to `ProcessState` for scalar (one-factor) processes.
///
/// `Scalar` and `dimension` are already provided by `Double: VectorSpace`.
/// This extension adds only the `NormalDraws` type needed by `ProcessState`.
extension Double: ProcessState {
    /// A single normal draw for one-factor processes.
    public typealias NormalDraws = Double
}

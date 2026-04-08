//
//  Interpolator.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-07.
//

import Foundation
import Numerics

// MARK: - Interpolator Protocol

/// A function learned from sample points, evaluable at query points in its domain.
///
/// `Interpolator` is the single root protocol for all interpolation in
/// BusinessMath. The shape of the input domain (1D, 2D, 3D, N-D) is encoded
/// in the `Point` associated type, which is any conforming ``VectorSpace``.
/// The shape of the output codomain (scalar field, vector field) is encoded
/// in the `Value` associated type.
///
/// ## Domain dimensions
///
/// | Domain shape | `Point` type |
/// |---|---|
/// | 1D (time series, scalar field) | ``Vector1D`` |
/// | 2D (image, heightmap) | ``Vector2D`` |
/// | 3D (volume) | ``Vector3D`` |
/// | N-D (variable, scattered) | ``VectorN`` |
///
/// ## Output shapes
///
/// | Output | `Value` type |
/// |---|---|
/// | Scalar field | `Scalar` (the underlying numeric type, e.g. `Double`) |
/// | Vector field | ``VectorN``, ``Vector2D``, ``Vector3D``, etc. |
///
/// `Value` is intentionally **not** constrained to ``VectorSpace`` so that
/// scalar-valued interpolators can use the bare numeric type without
/// wrapping it in a trivial vector.
///
/// ## Conforming types in v2.1.2
///
/// All ten 1D interpolation methods conform to `Interpolator` with
/// `Point = Vector1D<T>`. Scalar-output flavors use `Value = T`; vector-output
/// flavors use `Value = VectorN<T>`. Concrete 1D types also provide a
/// scalar convenience overload `callAsFunction(_ t: T)` so callers don't
/// need to wrap query coordinates in `Vector1D` for the common case.
public protocol Interpolator: Sendable {
    /// Scalar numeric type used for both coordinates and (typically) values.
    associatedtype Scalar: Real & Sendable & Codable

    /// Type of input query points. Use ``Vector1D`` for time-series or other
    /// 1D domains, ``Vector2D`` for image/heightmap domains, ``Vector3D`` for
    /// volumetric domains, ``VectorN`` for variable-dimension or scattered
    /// ND data.
    associatedtype Point: VectorSpace where Point.Scalar == Scalar

    /// Type of output values at each query point. Typically `Scalar` for
    /// scalar fields, ``VectorN`` or a fixed `Vector*D` for vector fields.
    /// Not constrained to `VectorSpace` so that scalar-valued interpolators
    /// can use the bare numeric type without wrapping.
    associatedtype Value: Sendable

    /// Number of independent variables in the input domain.
    var inputDimension: Int { get }

    /// Number of dependent variables in the output. 1 for scalar fields,
    /// N for vector fields with N components.
    var outputDimension: Int { get }

    /// Evaluate the interpolant at a single query point.
    func callAsFunction(at query: Point) -> Value

    /// Evaluate at multiple query points.
    /// Default implementation maps the single-point method over the array.
    /// Concrete types may override for batch efficiency.
    func callAsFunction(at queries: [Point]) -> [Value]
}

extension Interpolator {
    /// Default batch evaluation: maps the single-point method over the array.
    public func callAsFunction(at queries: [Point]) -> [Value] {
        queries.map { callAsFunction(at: $0) }
    }
}

// MARK: - Extrapolation Policy

/// Behavior for query points outside the input data range
/// `[xs.first, xs.last]`.
///
/// All concrete interpolators in BusinessMath accept an `outOfBounds`
/// parameter on their initializer, defaulting to ``clamp``.
public enum ExtrapolationPolicy<T: Real & Sendable>: Sendable {
    /// Queries outside the input range return the boundary value
    /// (`ys[0]` for `t < xs.first`, `ys[n-1]` for `t > xs.last`).
    /// This is the safest default and matches scipy's behavior.
    case clamp

    /// Queries outside the input range use the boundary polynomial or
    /// linear extension. Behavior is method-specific. For cubic methods
    /// this can produce wildly extrapolated values when the query is far
    /// from the data range — use with care.
    case extrapolate

    /// Queries outside the input range return the supplied constant value.
    case constant(T)
}

// MARK: - Errors

/// Errors thrown by interpolator initializers.
///
/// All validation happens at construction time. After successful
/// construction, evaluation (`callAsFunction`) never throws.
public enum InterpolationError: Error, Sendable, Equatable {
    /// Input collection had fewer points than the method requires.
    case insufficientPoints(required: Int, got: Int)

    /// `xs` was not strictly monotonically increasing.
    case unsortedInputs

    /// Two adjacent `xs` values were equal (zero-width interval).
    case duplicateXValues(at: Int)

    /// `xs` and `ys` had mismatched lengths.
    case mismatchedSizes(xsCount: Int, ysCount: Int)

    /// A method-specific parameter was out of range.
    case invalidParameter(message: String)
}

// MARK: - Internal helpers (used by all 1D conformers)

/// Validate `xs` is strictly monotonically increasing and matches `ysCount`.
@inlinable
internal func validateXY<T: Real>(
    xs: [T],
    ysCount: Int,
    minimumPoints: Int
) throws {
    guard xs.count == ysCount else {
        throw InterpolationError.mismatchedSizes(xsCount: xs.count, ysCount: ysCount)
    }
    guard xs.count >= minimumPoints else {
        throw InterpolationError.insufficientPoints(required: minimumPoints, got: xs.count)
    }
    if xs.count >= 2 {
        for i in 1..<xs.count {
            if xs[i] < xs[i - 1] {
                throw InterpolationError.unsortedInputs
            }
            if xs[i] == xs[i - 1] {
                throw InterpolationError.duplicateXValues(at: i)
            }
        }
    }
}

/// Binary search for the bracket `[xs[lo], xs[hi]]` containing `t`.
@inlinable
internal func bracket<T: Real>(_ t: T, in xs: [T]) -> (lo: Int, hi: Int) {
    let n = xs.count
    if n <= 1 { return (0, 0) }
    if t <= xs[0] { return (0, 1) }
    if t >= xs[n - 1] { return (n - 2, n - 1) }
    var lo = 0
    var hi = n - 1
    while hi - lo > 1 {
        let mid = (lo + hi) / 2
        if xs[mid] <= t { lo = mid } else { hi = mid }
    }
    return (lo, hi)
}

/// Apply the configured extrapolation policy. Returns the value to use,
/// or `nil` if the query is in-range and the caller should fall through.
@inlinable
internal func extrapolatedValue<T: Real & Sendable>(
    at t: T,
    xs: [T],
    ys: [T],
    policy: ExtrapolationPolicy<T>
) -> T? {
    let n = xs.count
    if n == 0 { return T(0) }
    if t >= xs[0] && t <= xs[n - 1] { return nil }
    switch policy {
    case .clamp:
        return t < xs[0] ? ys[0] : ys[n - 1]
    case .extrapolate:
        return nil  // caller falls through to evaluate the boundary polynomial
    case .constant(let value):
        return value
    }
}

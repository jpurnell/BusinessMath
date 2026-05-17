//
//  BSpline.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-07.
//

import Foundation
import Numerics

/// 1D interpolating B-spline of configurable degree (1–5).
///
/// A B-spline is a piecewise polynomial curve defined by basis functions
/// (the B-spline basis), distinct from natural cubic splines which use a
/// power basis. For an **interpolating** B-spline, the control points are
/// computed so that the curve passes through the data points exactly at
/// the knots.
///
/// **Degree 1 (linear B-spline):** equivalent to ``LinearInterpolator``.
/// **Degree 3 (cubic B-spline):** the most common case, comparable in
/// smoothness to natural cubic spline but with different basis functions.
/// **Degrees 2 and 4:** less common but useful for specific use cases.
/// **Degree 5:** the highest supported degree; higher degrees are
/// numerically unstable and rarely useful.
///
/// **Note:** for v2.1.2, BSpline is implemented as a thin wrapper around
/// `CubicSplineInterpolator` (with `.notAKnot` boundary condition) for
/// degree 3 — the two formulations produce mathematically equivalent
/// curves on a not-a-knot interpolating cubic. Higher and lower degrees
/// fall back to `LinearInterpolator` (degree 1) or `CubicSplineInterpolator`
/// (degrees 2, 4, 5 → cubic). A full B-spline-basis implementation is
/// scheduled for a future release.
///
/// **Reference:** de Boor, C. (1978). *A Practical Guide to Splines*.
/// Springer-Verlag.
///
/// ## Example
/// ```swift
/// let interp = try BSplineInterpolator<Double>(
///     xs: [0, 1, 2, 3, 4],
///     ys: [0, 1, 4, 9, 16],
///     degree: 3
/// )
/// interp(2.5)
/// ```
public struct BSplineInterpolator<T: Real & Sendable & Codable>: Interpolator {
    /// The scalar type for coordinates and values.
    public typealias Scalar = T
    /// Input point type (1D scalar wrapped in ``Vector1D``).
    public typealias Point = Vector1D<T>
    /// Output value type (scalar).
    public typealias Value = T

    /// The number of input dimensions (always 1).
    public let inputDimension = 1
    /// The number of output dimensions (always 1 for scalar output).
    public let outputDimension = 1

    /// Sample x-coordinates, strictly monotonically increasing.
    public let xs: [T]
    /// Sample y-values at each knot.
    public let ys: [T]
    /// Polynomial degree of the B-spline basis (1 = linear, 3 = cubic).
    public let degree: Int
    /// Behavior for queries outside `[xs.first, xs.last]`.
    public let outOfBounds: ExtrapolationPolicy<T>

    @usableFromInline
    internal enum Backend: Sendable {
        case linear(LinearInterpolator<T>)
        case cubic(CubicSplineInterpolator<T>)
    }

    @usableFromInline
    internal let backend: Backend

    /// Create a B-spline interpolator.
    ///
    /// - Parameters:
    ///   - xs: Strictly monotonically increasing x-coordinates.
    ///   - ys: Y-values at each `xs[i]`.
    ///   - degree: Polynomial degree of the B-spline. Must be in `1...5`.
    ///     Default `3` (cubic).
    ///   - outOfBounds: Behavior for queries outside the data range. Defaults to `.clamp`.
    /// - Throws: ``InterpolationError/invalidParameter(message:)`` if `degree` is out of range,
    ///   plus the validation errors from the underlying linear or cubic spline.
    public init(
        xs: [T],
        ys: [T],
        degree: Int = 3,
        outOfBounds: ExtrapolationPolicy<T> = .clamp
    ) throws {
        guard (1...5).contains(degree) else {
            throw InterpolationError.invalidParameter(
                message: "BSpline degree must be in 1...5 (got \(degree))"
            )
        }
        self.xs = xs
        self.ys = ys
        self.degree = degree
        self.outOfBounds = outOfBounds

        if degree == 1 {
            // Linear B-spline = piecewise linear interpolation
            self.backend = .linear(try LinearInterpolator(xs: xs, ys: ys, outOfBounds: outOfBounds))
        } else {
            // Degrees 2..5 → cubic spline (not-a-knot) for v1.
            // A future release will add degree-2 quadratic and degree-4/5
            // higher-order B-spline-basis implementations.
            self.backend = .cubic(try CubicSplineInterpolator(
                xs: xs, ys: ys, boundary: .notAKnot, outOfBounds: outOfBounds
            ))
        }
    }

    /// Evaluate the interpolator at a wrapped query point.
    ///
    /// - Parameter query: The query point as a ``Vector1D``.
    /// - Returns: Interpolated y-value.
    public func callAsFunction(at query: Vector1D<T>) -> T {
        callAsFunction(query.value)
    }

    /// Evaluate the interpolator at a scalar query point.
    ///
    /// - Parameter t: The x-coordinate to evaluate at.
    /// - Returns: The B-spline value at `t`.
    public func callAsFunction(_ t: T) -> T {
        switch backend {
        case .linear(let l): return l(t)
        case .cubic(let c): return c(t)
        }
    }
}

//
//  Linear.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-07.
//

import Foundation
import Numerics

/// 1D piecewise-linear interpolation.
///
/// At a query point `t` in the interval `[xs[i], xs[i+1]]`, returns
/// `ys[i] + (t - xs[i]) / (xs[i+1] - xs[i]) * (ys[i+1] - ys[i])`.
///
/// Linear interpolation is the universal baseline: fast, simple, and
/// reproduces linear data exactly. It tends to underestimate amplitude
/// when the underlying signal varies on a scale comparable to the
/// sample spacing. For smoother reconstruction of physical signals, prefer
/// ``PCHIPInterpolator`` (overshoot-safe), ``CubicSplineInterpolator``
/// (smoothest, may overshoot), or ``AkimaInterpolator`` (robust to outliers).
///
/// ## Example
/// ```swift
/// let interp = try LinearInterpolator<Double>(
///     xs: [0, 1, 2, 3, 4],
///     ys: [0, 1, 4, 9, 16]
/// )
/// interp(0.5)   // 0.5
/// interp(2.5)   // 6.5
/// ```
public struct LinearInterpolator<T: Real & Sendable & Codable>: Interpolator {
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
    /// Behavior for queries outside `[xs.first, xs.last]`.
    public let outOfBounds: ExtrapolationPolicy<T>

    /// Create a linear interpolator from sample points.
    ///
    /// - Parameters:
    ///   - xs: Strictly monotonically increasing x-coordinates. At least 2 elements.
    ///   - ys: Y-values at each `xs[i]`. Must match `xs.count`.
    ///   - outOfBounds: Behavior for queries outside the data range. Defaults to `.clamp`.
    /// - Throws: See ``InterpolationError``.
    public init(
        xs: [T],
        ys: [T],
        outOfBounds: ExtrapolationPolicy<T> = .clamp
    ) throws {
        try validateXY(xs: xs, ysCount: ys.count, minimumPoints: 2)
        self.xs = xs
        self.ys = ys
        self.outOfBounds = outOfBounds
    }

    /// Evaluate the interpolator at a wrapped query point.
    ///
    /// - Parameter query: The query point as a ``Vector1D``.
    /// - Returns: Linearly interpolated y-value.
    public func callAsFunction(at query: Vector1D<T>) -> T {
        callAsFunction(query.value)
    }

    /// Evaluate the interpolator at a scalar query point.
    ///
    /// - Parameter t: The x-coordinate to evaluate at.
    /// - Returns: The piecewise-linear value at `t`.
    public func callAsFunction(_ t: T) -> T {
        if let extrapolated = extrapolatedValue(at: t, xs: xs, ys: ys, policy: outOfBounds) {
            return extrapolated
        }
        let (lo, hi) = bracket(t, in: xs)
        let frac = (t - xs[lo]) / (xs[hi] - xs[lo])
        return ys[lo] + frac * (ys[hi] - ys[lo])
    }
}

//
//  PreviousValue.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-07.
//

import Foundation
import Numerics

/// 1D step-function interpolation that holds the **previous** known value.
///
/// At a query point `t` in the interval `[xs[i], xs[i+1])`, returns `ys[i]`.
/// At exact knots `t == xs[i]`, returns `ys[i]`.
///
/// Common in time-series accounting (last-known-value semantics), event
/// logs, and any context where a value persists from the moment it was
/// recorded until a new value supersedes it.
///
/// ## Example
/// ```swift
/// let interp = try PreviousValueInterpolator<Double>(
///     xs: [0, 1, 2, 3, 4],
///     ys: [0, 1, 4, 9, 16]
/// )
/// interp(0.5)   // 0  (most recent ys[i] for xs[i] <= 0.5)
/// interp(1.0)   // 1  (exact knot — pass-through)
/// interp(2.9)   // 4
/// ```
public struct PreviousValueInterpolator<T: Real & Sendable & Codable>: Interpolator {
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

    /// Create a previous-value step interpolator.
    ///
    /// - Parameters:
    ///   - xs: Strictly monotonically increasing x-coordinates. At least 1 element.
    ///   - ys: Y-values at each `xs[i]`. Must match `xs.count`.
    ///   - outOfBounds: Behavior for queries outside the data range. Defaults to `.clamp`.
    /// - Throws: See ``InterpolationError``.
    public init(
        xs: [T],
        ys: [T],
        outOfBounds: ExtrapolationPolicy<T> = .clamp
    ) throws {
        try validateXY(xs: xs, ysCount: ys.count, minimumPoints: 1)
        self.xs = xs
        self.ys = ys
        self.outOfBounds = outOfBounds
    }

    /// Evaluate the interpolator at a wrapped query point.
    ///
    /// - Parameter query: The query point as a ``Vector1D``.
    /// - Returns: The most recent knot value at or before the query.
    public func callAsFunction(at query: Vector1D<T>) -> T {
        callAsFunction(query.value)
    }

    /// Evaluate the interpolator at a scalar query point.
    ///
    /// - Parameter t: The x-coordinate to evaluate at.
    /// - Returns: The y-value of the most recent knot at or before `t`.
    public func callAsFunction(_ t: T) -> T {
        if let extrapolated = extrapolatedValue(at: t, xs: xs, ys: ys, policy: outOfBounds) {
            return extrapolated
        }
        let n = xs.count
        if n == 1 { return ys[0] }
        let (lo, hi) = bracket(t, in: xs)
        // Exact knot at the upper bracket end (e.g. t == xs[n-1]) — return ys[hi]
        if t == xs[hi] { return ys[hi] }
        return ys[lo]
    }
}

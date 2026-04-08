//
//  NearestNeighbor.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-07.
//

import Foundation
import Numerics

/// 1D nearest-neighbor interpolation.
///
/// At a query point `t`, returns the `ys[i]` value whose `xs[i]` is closest
/// to `t`. Ties (equidistant) resolve to the lower index.
///
/// This is the simplest interpolation primitive — useful when you need
/// a "closest known value" semantic and don't want any smoothing or
/// linearization. Common in nearest-neighbor classifiers, sparse lookup
/// tables, and "snap to grid" workflows.
///
/// ## Example
/// ```swift
/// let interp = try NearestNeighborInterpolator<Double>(
///     xs: [0, 1, 2, 3, 4],
///     ys: [0, 1, 4, 9, 16]
/// )
/// interp(0.4)   // 0  (closest to xs[0] = 0)
/// interp(0.6)   // 1  (closest to xs[1] = 1)
/// interp(2.5)   // 4  (tie — resolves to lower index, xs[2] = 2)
/// ```
public struct NearestNeighborInterpolator<T: Real & Sendable & Codable>: Interpolator {
    public typealias Scalar = T
    public typealias Point = Vector1D<T>
    public typealias Value = T

    public let inputDimension = 1
    public let outputDimension = 1

    /// Sample x-coordinates, strictly monotonically increasing.
    public let xs: [T]

    /// Sample y-values, aligned with `xs`.
    public let ys: [T]

    /// Behavior for queries outside `[xs.first, xs.last]`.
    public let outOfBounds: ExtrapolationPolicy<T>

    /// Create a nearest-neighbor interpolator from sample points.
    ///
    /// - Parameters:
    ///   - xs: Strictly monotonically increasing x-coordinates. At least 1 element.
    ///   - ys: Y-values at each `xs[i]`. Must match `xs.count`.
    ///   - outOfBounds: Behavior for queries outside the data range. Defaults to `.clamp`.
    /// - Throws:
    ///   - ``InterpolationError/insufficientPoints(required:got:)`` if `xs.count < 1`.
    ///   - ``InterpolationError/mismatchedSizes(xsCount:ysCount:)`` if `xs.count != ys.count`.
    ///   - ``InterpolationError/unsortedInputs`` if `xs` is not strictly monotonic.
    ///   - ``InterpolationError/duplicateXValues(at:)`` if two adjacent `xs` are equal.
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

    public func callAsFunction(at query: Vector1D<T>) -> T {
        callAsFunction(query.value)
    }

    /// Scalar convenience: evaluate at a bare scalar `t` without wrapping
    /// in `Vector1D`. Recommended for the common 1D scalar case.
    public func callAsFunction(_ t: T) -> T {
        if let extrapolated = extrapolatedValue(at: t, xs: xs, ys: ys, policy: outOfBounds) {
            return extrapolated
        }
        let n = xs.count
        if n == 1 { return ys[0] }
        let (lo, hi) = bracket(t, in: xs)
        let dLo = (t - xs[lo]) < T(0) ? -(t - xs[lo]) : (t - xs[lo])
        let dHi = (xs[hi] - t) < T(0) ? -(xs[hi] - t) : (xs[hi] - t)
        return dLo <= dHi ? ys[lo] : ys[hi]
    }
}

//
//  NextValue.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-07.
//

import Foundation
import Numerics

/// 1D step-function interpolation that holds the **next** known value.
///
/// At a query point `t` in the interval `(xs[i], xs[i+1]]`, returns `ys[i+1]`.
/// At exact knots `t == xs[i]`, returns `ys[i]` (pass-through).
///
/// The symmetric partner of ``PreviousValueInterpolator``. Useful in
/// scenarios where the relevant value is "the value that will become current
/// next" — for example, scheduled events or pre-announced rate changes.
///
/// ## Example
/// ```swift
/// let interp = try NextValueInterpolator<Double>(
///     xs: [0, 1, 2, 3, 4],
///     ys: [0, 1, 4, 9, 16]
/// )
/// interp(0.5)   // 1  (next known value after 0.5 is at xs[1] = 1)
/// interp(1.0)   // 1  (exact knot — pass-through)
/// interp(2.9)   // 9
/// ```
public struct NextValueInterpolator<T: Real & Sendable & Codable>: Interpolator {
    public typealias Scalar = T
    public typealias Point = Vector1D<T>
    public typealias Value = T

    public let inputDimension = 1
    public let outputDimension = 1

    public let xs: [T]
    public let ys: [T]
    public let outOfBounds: ExtrapolationPolicy<T>

    /// Create a next-value step interpolator.
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

    public func callAsFunction(at query: Vector1D<T>) -> T {
        callAsFunction(query.value)
    }

    /// Scalar convenience.
    public func callAsFunction(_ t: T) -> T {
        if let extrapolated = extrapolatedValue(at: t, xs: xs, ys: ys, policy: outOfBounds) {
            return extrapolated
        }
        let n = xs.count
        if n == 1 { return ys[0] }
        let (lo, hi) = bracket(t, in: xs)
        if t == xs[lo] { return ys[lo] }   // exact knot — pass-through
        return ys[hi]
    }
}

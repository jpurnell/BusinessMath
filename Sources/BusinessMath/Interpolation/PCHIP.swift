//
//  PCHIP.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-07.
//

import Foundation
import Numerics

/// 1D piecewise cubic Hermite interpolating polynomial (Fritsch–Carlson
/// monotone cubic).
///
/// PCHIP is the **overshoot-safe** cubic interpolator: it preserves the
/// monotonicity of the input data. Where ``CubicSplineInterpolator`` may
/// overshoot near sharp features (because the smoothness constraint forces
/// it to bend past data points), PCHIP enforces monotonicity by clamping the
/// computed slopes when necessary.
///
/// It's the scipy-recommended "safe cubic" for general-purpose smooth
/// interpolation of arbitrary data.
///
/// **Reference:** Fritsch & Carlson (1980), "Monotone Piecewise Cubic
/// Interpolation", *SIAM Journal on Numerical Analysis*, 17(2):238–246.
///
/// ## Example
/// ```swift
/// let interp = try PCHIPInterpolator<Double>(
///     xs: [0, 1, 2, 3, 4],
///     ys: [0, 1, 4, 9, 16]
/// )
/// interp(2.5)   // smooth, no overshoot
/// ```
public struct PCHIPInterpolator<T: Real & Sendable & Codable>: Interpolator {
    public typealias Scalar = T
    public typealias Point = Vector1D<T>
    public typealias Value = T

    public let inputDimension = 1
    public let outputDimension = 1

    public let xs: [T]
    public let ys: [T]
    public let outOfBounds: ExtrapolationPolicy<T>

    /// Precomputed slopes at each knot.
    @usableFromInline
    internal let slopes: [T]

    /// Create a PCHIP interpolator.
    ///
    /// - Parameters:
    ///   - xs: Strictly monotonically increasing x-coordinates. At least 2 elements.
    ///   - ys: Y-values at each `xs[i]`.
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
        self.slopes = Self.computeSlopes(xs: xs, ys: ys)
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
        return cubicHermite(t: t, xs: xs, ys: ys, slopes: slopes)
    }

    @usableFromInline
    internal static func computeSlopes(xs: [T], ys: [T]) -> [T] {
        let n = xs.count
        if n < 2 { return [T](repeating: T(0), count: n) }
        var h = [T](repeating: T(0), count: n - 1)
        var delta = [T](repeating: T(0), count: n - 1)
        for i in 0..<(n - 1) {
            h[i] = xs[i + 1] - xs[i]
            delta[i] = (ys[i + 1] - ys[i]) / h[i]
        }
        var d = [T](repeating: T(0), count: n)
        if n == 2 {
            d[0] = delta[0]
            d[1] = delta[0]
            return d
        }
        // Interior slopes via Fritsch-Carlson weighted harmonic mean
        for i in 1..<(n - 1) {
            if delta[i - 1] * delta[i] <= T(0) {
                d[i] = T(0)
            } else {
                let w1 = T(2) * h[i] + h[i - 1]
                let w2 = h[i] + T(2) * h[i - 1]
                d[i] = (w1 + w2) / (w1 / delta[i - 1] + w2 / delta[i])
            }
        }
        // Endpoints
        d[0] = pchipEndpoint(h0: h[0], h1: h[1], delta0: delta[0], delta1: delta[1])
        d[n - 1] = pchipEndpoint(
            h0: h[n - 2], h1: h[n - 3],
            delta0: delta[n - 2], delta1: delta[n - 3]
        )
        return d
    }

    private static func pchipEndpoint(h0: T, h1: T, delta0: T, delta1: T) -> T {
        let d = ((T(2) * h0 + h1) * delta0 - h0 * delta1) / (h0 + h1)
        if d * delta0 <= T(0) { return T(0) }
        if delta0 * delta1 <= T(0), Self.absT(d) > Self.absT(T(3) * delta0) {
            return T(3) * delta0
        }
        return d
    }

    @inlinable
    internal static func absT(_ x: T) -> T {
        x < T(0) ? -x : x
    }
}

// MARK: - Cubic Hermite evaluator (shared with Akima and CatmullRom)

/// Evaluate a cubic Hermite spline at `t` given knots, values, and slopes.
/// Uses the standard Hermite basis on the bracket containing `t`.
@inlinable
internal func cubicHermite<T: Real>(
    t: T, xs: [T], ys: [T], slopes: [T]
) -> T {
    let (lo, hi) = bracket(t, in: xs)
    let h = xs[hi] - xs[lo]
    let s = (t - xs[lo]) / h
    let one = T(1)
    let two = T(2)
    let three = T(3)
    let oneMinusS = one - s
    let h00 = (one + two * s) * oneMinusS * oneMinusS
    let h10 = s * oneMinusS * oneMinusS
    let h01 = s * s * (three - two * s)
    let h11 = s * s * (s - one)
    return h00 * ys[lo] + h10 * h * slopes[lo] + h01 * ys[hi] + h11 * h * slopes[hi]
}

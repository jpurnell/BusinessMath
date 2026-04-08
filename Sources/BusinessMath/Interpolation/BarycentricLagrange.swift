//
//  BarycentricLagrange.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-07.
//

import Foundation
import Numerics

/// Numerically stable polynomial interpolation through all `n` data points.
///
/// Barycentric Lagrange interpolation constructs the unique polynomial of
/// degree at most `n−1` that passes through all `n` data points, evaluated
/// via the barycentric form for numerical stability:
///
///     p(t) = (Σ w[i] * y[i] / (t - x[i])) / (Σ w[i] / (t - x[i]))
///
/// where the weights `w[i] = 1 / Π_{k≠i}(x[i] - x[k])` are precomputed at
/// initialization.
///
/// ## Suitable for small N only
///
/// Polynomial interpolation through many points exhibits the **Runge
/// phenomenon**: the polynomial oscillates wildly near the endpoints when
/// `n` exceeds roughly 15–20 points on equally-spaced data. For larger
/// datasets, prefer ``CubicSplineInterpolator``, ``PCHIPInterpolator``, or
/// any of the other piecewise methods.
///
/// Barycentric Lagrange is most useful for:
/// - Polynomial fitting with known-good data (≤ 20 points)
/// - Spectral methods that interpolate at Chebyshev nodes
/// - Academic and reference applications
///
/// **Reference:** Berrut, J.-P. & Trefethen, L. N. (2004). "Barycentric
/// Lagrange Interpolation", *SIAM Review*, 46(3):501–517.
///
/// ## Example
/// ```swift
/// let interp = try BarycentricLagrangeInterpolator<Double>(
///     xs: [0, 1, 2, 3, 4],
///     ys: [0, 1, 4, 9, 16]
/// )
/// // Returns 6.25 — the polynomial through these 5 points is exactly y = x²
/// interp(2.5)
/// ```
public struct BarycentricLagrangeInterpolator<T: Real & Sendable & Codable>: Interpolator {
    public typealias Scalar = T
    public typealias Point = Vector1D<T>
    public typealias Value = T

    public let inputDimension = 1
    public let outputDimension = 1

    public let xs: [T]
    public let ys: [T]
    public let outOfBounds: ExtrapolationPolicy<T>

    @usableFromInline
    internal let weights: [T]

    /// Create a barycentric Lagrange interpolator.
    ///
    /// - Parameters:
    ///   - xs: Strictly monotonically increasing x-coordinates. At least 1 element.
    ///   - ys: Y-values at each `xs[i]`.
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
        self.weights = Self.computeWeights(xs: xs)
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
        // Exact-knot match avoids 0/0
        for i in 0..<n where t == xs[i] { return ys[i] }
        var num = T(0)
        var den = T(0)
        for i in 0..<n {
            let wi = weights[i] / (t - xs[i])
            num = num + wi * ys[i]
            den = den + wi
        }
        return num / den
    }

    @usableFromInline
    internal static func computeWeights(xs: [T]) -> [T] {
        let n = xs.count
        var w = [T](repeating: T(1), count: n)
        for j in 0..<n {
            var product = T(1)
            for k in 0..<n where k != j {
                product = product * (xs[j] - xs[k])
            }
            w[j] = T(1) / product
        }
        return w
    }
}

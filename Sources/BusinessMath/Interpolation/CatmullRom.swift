//
//  CatmullRom.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-07.
//

import Foundation
import Numerics

/// 1D cardinal spline interpolation. The default tension τ = 0 produces
/// the standard Catmull-Rom spline.
///
/// Cardinal splines compute slopes at each interior knot as:
///
///     d[i] = (1 - τ) * (y[i+1] - y[i-1]) / (x[i+1] - x[i-1])
///
/// The tension parameter τ ∈ [0, 1] controls how "tight" the spline is:
///
/// - **τ = 0** (default) → standard **Catmull-Rom** spline (full-strength
///   tangents). Reproduces linear data exactly.
/// - **τ = 1** → all tangents are zero, producing a piecewise quadratic-like
///   curve with C¹ continuity but no smoothness through derivatives.
/// - **τ ∈ (0, 1)** → progressively tighter cardinal splines.
///
/// **Note on tension:** Many graphics programs use a different convention
/// where "tension = 0.5" refers to the centripetal Catmull-Rom alpha parameter.
/// That parameter only applies to parametric curves in 2D/3D, not to 1D
/// non-parametric interpolation. For 1D, only the cardinal spline tension
/// τ applies, and τ = 0 is canonical Catmull-Rom.
///
/// **Reference:** Catmull, E. & Rom, R. (1974). "A class of local
/// interpolating splines", *Computer Aided Geometric Design*, 317–326.
///
/// ## Example
/// ```swift
/// let interp = try CatmullRomInterpolator<Double>(
///     xs: [0, 1, 2, 3, 4],
///     ys: [0, 1, 4, 9, 16]
/// )
/// interp(2.5)   // smooth cardinal spline value
/// ```
public struct CatmullRomInterpolator<T: Real & Sendable & Codable>: Interpolator {
    public typealias Scalar = T
    public typealias Point = Vector1D<T>
    public typealias Value = T

    public let inputDimension = 1
    public let outputDimension = 1

    public let xs: [T]
    public let ys: [T]
    public let tension: T
    public let outOfBounds: ExtrapolationPolicy<T>

    @usableFromInline
    internal let slopes: [T]

    /// Create a Catmull-Rom (cardinal) spline interpolator.
    ///
    /// - Parameters:
    ///   - xs: Strictly monotonically increasing x-coordinates. At least 2 elements.
    ///   - ys: Y-values at each `xs[i]`.
    ///   - tension: Cardinal spline tension τ ∈ [0, 1]. Default `0` (standard
    ///     Catmull-Rom). Higher values produce a tighter spline that does NOT
    ///     reproduce linear data exactly.
    ///   - outOfBounds: Behavior for queries outside the data range. Defaults to `.clamp`.
    /// - Throws: See ``InterpolationError``. Also throws
    ///   ``InterpolationError/invalidParameter(message:)`` if `tension` is
    ///   outside `[0, 1]`.
    public init(
        xs: [T],
        ys: [T],
        tension: T = T(0),
        outOfBounds: ExtrapolationPolicy<T> = .clamp
    ) throws {
        try validateXY(xs: xs, ysCount: ys.count, minimumPoints: 2)
        if tension < T(0) || tension > T(1) {
            throw InterpolationError.invalidParameter(
                message: "CatmullRom tension must be in [0, 1]"
            )
        }
        self.xs = xs
        self.ys = ys
        self.tension = tension
        self.outOfBounds = outOfBounds
        self.slopes = Self.computeSlopes(xs: xs, ys: ys, tension: tension)
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
    internal static func computeSlopes(xs: [T], ys: [T], tension: T) -> [T] {
        let n = xs.count
        if n < 2 { return [T](repeating: T(0), count: n) }
        if n == 2 {
            let s = (ys[1] - ys[0]) / (xs[1] - xs[0])
            return [s, s]
        }
        let scale = T(1) - tension
        var d = [T](repeating: T(0), count: n)
        for i in 1..<(n - 1) {
            d[i] = scale * (ys[i + 1] - ys[i - 1]) / (xs[i + 1] - xs[i - 1])
        }
        // Endpoints: one-sided forward / backward difference, scaled by (1 - tension)
        d[0] = scale * (ys[1] - ys[0]) / (xs[1] - xs[0])
        d[n - 1] = scale * (ys[n - 1] - ys[n - 2]) / (xs[n - 1] - xs[n - 2])
        return d
    }
}

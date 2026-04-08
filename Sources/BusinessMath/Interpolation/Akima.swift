//
//  Akima.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-07.
//

import Foundation
import Numerics

/// 1D Akima spline interpolation, with optional modified ("makima") variant.
///
/// Akima splines compute slopes at each knot using a locally-weighted
/// average of segment slopes. This makes them robust to outliers and
/// less prone to oscillation than natural cubic splines, while still
/// being smooth (C¹ continuous).
///
/// The **modified Akima** variant ("makima") adds extra terms to the
/// slope-weighting formula that handle flat regions and repeated values
/// better. It's strictly preferable to the original 1970 Akima for
/// smooth physical data, and is the default in BusinessMath.
///
/// **References:**
/// - Akima, H. (1970). "A new method of interpolation and smooth curve
///   fitting based on local procedures", *J. ACM* 17(4):589–602.
/// - MATLAB `makima` documentation for the modified variant.
///
/// ## Example
/// ```swift
/// // Default makima — recommended for physical data
/// let interp = try AkimaInterpolator<Double>(
///     xs: [0, 1, 2, 3, 4],
///     ys: [0, 1, 4, 9, 16]
/// )
///
/// // Original 1970 Akima for backward-compatible reference
/// let original = try AkimaInterpolator<Double>(
///     xs: [0, 1, 2, 3, 4],
///     ys: [0, 1, 4, 9, 16],
///     modified: false
/// )
/// ```
public struct AkimaInterpolator<T: Real & Sendable & Codable>: Interpolator {
    public typealias Scalar = T
    public typealias Point = Vector1D<T>
    public typealias Value = T

    public let inputDimension = 1
    public let outputDimension = 1

    public let xs: [T]
    public let ys: [T]
    public let modified: Bool
    public let outOfBounds: ExtrapolationPolicy<T>

    @usableFromInline
    internal let slopes: [T]

    /// Create an Akima spline interpolator.
    ///
    /// - Parameters:
    ///   - xs: Strictly monotonically increasing x-coordinates. At least 2 elements.
    ///   - ys: Y-values at each `xs[i]`.
    ///   - modified: When `true` (default), uses the modified Akima ("makima")
    ///     formulation that handles flat regions and repeated values better.
    ///     When `false`, uses the original 1970 Akima formulation.
    ///   - outOfBounds: Behavior for queries outside the data range. Defaults to `.clamp`.
    /// - Throws: See ``InterpolationError``.
    public init(
        xs: [T],
        ys: [T],
        modified: Bool = true,
        outOfBounds: ExtrapolationPolicy<T> = .clamp
    ) throws {
        try validateXY(xs: xs, ysCount: ys.count, minimumPoints: 2)
        self.xs = xs
        self.ys = ys
        self.modified = modified
        self.outOfBounds = outOfBounds
        self.slopes = Self.computeSlopes(xs: xs, ys: ys, modified: modified)
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
    internal static func computeSlopes(xs: [T], ys: [T], modified: Bool) -> [T] {
        let n = xs.count
        if n < 2 { return [T](repeating: T(0), count: n) }
        if n == 2 {
            let s = (ys[1] - ys[0]) / (xs[1] - xs[0])
            return [s, s]
        }
        // Compute segment slopes m[2..n-2] (interior), with 2 ghost slopes on each side
        var m = [T](repeating: T(0), count: n + 3)
        for i in 0..<(n - 1) {
            m[i + 2] = (ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i])
        }
        // Akima ghost slope extrapolation
        m[1] = T(2) * m[2] - m[3]
        m[0] = T(2) * m[1] - m[2]
        m[n + 1] = T(2) * m[n] - m[n - 1]
        m[n + 2] = T(2) * m[n + 1] - m[n]

        var d = [T](repeating: T(0), count: n)
        for i in 0..<n {
            let mi = m[i + 2]
            let mim1 = m[i + 1]
            let mim2 = m[i]
            let mip1 = m[i + 3]
            let w1: T
            let w2: T
            if modified {
                w1 = absT(mip1 - mi) + absT(mip1 + mi) / T(2)
                w2 = absT(mim1 - mim2) + absT(mim1 + mim2) / T(2)
            } else {
                w1 = absT(mip1 - mi)
                w2 = absT(mim1 - mim2)
            }
            let denom = w1 + w2
            if denom == T(0) {
                d[i] = (mim1 + mi) / T(2)
            } else {
                d[i] = (w1 * mim1 + w2 * mi) / denom
            }
        }
        return d
    }

    @inlinable
    internal static func absT(_ x: T) -> T {
        x < T(0) ? -x : x
    }
}

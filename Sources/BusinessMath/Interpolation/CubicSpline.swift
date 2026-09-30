//
//  CubicSpline.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-07.
//

import Foundation
import Numerics

/// 1D cubic spline interpolation with configurable boundary conditions.
///
/// At a query point `t` in interval `[xs[i], xs[i+1]]`, evaluates a piecewise
/// cubic that's twice continuously differentiable across knots. The
/// boundary condition determines the behavior at the endpoints (where the
/// continuity constraints alone don't pin down the second derivatives).
///
/// **Reference:** Burden & Faires, *Numerical Analysis*, §3.5; Press et al.,
/// *Numerical Recipes*, §3.3.
///
/// ## Boundary conditions
///
/// | Case | Description |
/// |---|---|
/// | ``BoundaryCondition/natural`` | `f''(x_first) = f''(x_last) = 0`. The Kubios HRV default. Smooth interior, free at endpoints. |
/// | ``BoundaryCondition/notAKnot`` | Third derivative continuous at `x[1]` and `x[n-2]`. The MATLAB / scipy default. |
/// | ``BoundaryCondition/clamped(left:right:)`` | Specified `f'(x_first)` and `f'(x_last)`. Use when you know the endpoint slopes. |
/// | ``BoundaryCondition/periodic`` | `f, f', f''` match at endpoints. Requires `ys.first == ys.last`. |
///
/// ## Overshoot
///
/// Cubic splines are the smoothest C² interpolant but can overshoot near
/// sharp features in the data. For data with discontinuities or where
/// monotonicity preservation matters, use ``PCHIPInterpolator`` instead.
///
/// ## Example
/// ```swift
/// let interp = try CubicSplineInterpolator<Double>(
///     xs: [0, 1, 2, 3, 4],
///     ys: [0, 1, 4, 9, 16],
///     boundary: .natural
/// )
/// interp(2.5)   // ≈ 6.25 (close to the analytic 6.25 from y = x²)
/// ```
public struct CubicSplineInterpolator<T: Real & BinaryFloatingPoint & Sendable & Codable>: Interpolator {
    /// The scalar type for coordinates and values.
    public typealias Scalar = T
    /// Input point type (1D scalar wrapped in ``Vector1D``).
    public typealias Point = Vector1D<T>
    /// Output value type (scalar).
    public typealias Value = T

    /// Boundary condition for the cubic spline.
    public enum BoundaryCondition: Sendable {
        /// `f''(x_first) = f''(x_last) = 0`. Default. Kubios HRV standard.
        case natural

        /// Third derivative continuous at `x[1]` and `x[n-2]`. MATLAB / scipy default.
        case notAKnot

        /// Specified `f'(x_first) = left` and `f'(x_last) = right`.
        case clamped(left: T, right: T)

        /// `f, f', f''` match at endpoints. Requires `ys.first == ys.last`.
        case periodic
    }

    /// The number of input dimensions (always 1).
    public let inputDimension = 1
    /// The number of output dimensions (always 1 for scalar output).
    public let outputDimension = 1

    /// Sample x-coordinates, strictly monotonically increasing.
    public let xs: [T]
    /// Sample y-values at each knot.
    public let ys: [T]
    /// The boundary condition governing endpoint behavior.
    public let boundary: BoundaryCondition
    /// Behavior for queries outside `[xs.first, xs.last]`.
    public let outOfBounds: ExtrapolationPolicy<T>

    /// Precomputed second derivatives at each knot.
    @usableFromInline
    internal let secondDerivatives: [T]

    /// Create a cubic spline interpolator.
    ///
    /// - Parameters:
    ///   - xs: Strictly monotonically increasing x-coordinates. At least 2 elements
    ///     for `.clamped`, at least 3 for `.natural`/`.notAKnot`/`.periodic`.
    ///   - ys: Y-values at each `xs[i]`.
    ///   - boundary: Boundary condition. Defaults to `.natural`.
    ///   - outOfBounds: Behavior for queries outside the data range. Defaults to `.clamp`.
    /// - Throws: See ``InterpolationError``. Also throws
    ///   ``InterpolationError/invalidParameter(message:)`` if periodic
    ///   boundary is requested and `ys.first != ys.last`.
    public init(
        xs: [T],
        ys: [T],
        boundary: BoundaryCondition = .natural,
        outOfBounds: ExtrapolationPolicy<T> = .clamp
    ) throws {
        let minPoints: Int
        switch boundary {
        case .clamped: minPoints = 2
        default:       minPoints = 3
        }
        try validateXY(xs: xs, ysCount: ys.count, minimumPoints: minPoints)

        if case .periodic = boundary {
            if let first = ys.first, let last = ys.last, first != last {
                throw InterpolationError.invalidParameter(
                    message: "Periodic cubic spline requires ys.first == ys.last"
                )
            }
        }

        self.xs = xs
        self.ys = ys
        self.boundary = boundary
        self.outOfBounds = outOfBounds
        self.secondDerivatives = Self.computeSecondDerivatives(
            xs: xs, ys: ys, boundary: boundary
        )
    }

    /// Evaluate the spline at a wrapped query point.
    ///
    /// - Parameter query: The query point as a ``Vector1D``.
    /// - Returns: Interpolated y-value.
    public func callAsFunction(at query: Vector1D<T>) -> T {
        callAsFunction(query.value)
    }

    /// Evaluate the spline at a scalar query point.
    ///
    /// - Parameter t: The x-coordinate to evaluate at.
    /// - Returns: The C2-smooth cubic spline value at `t`.
    public func callAsFunction(_ t: T) -> T {
        if let extrapolated = extrapolatedValue(at: t, xs: xs, ys: ys, policy: outOfBounds) {
            return extrapolated
        }
        let n = xs.count
        if n == 1 { return ys[0] }
        let (lo, hi) = bracket(t, in: xs)
        let h = xs[hi] - xs[lo]
        let A = (xs[hi] - t) / h
        let B = (t - xs[lo]) / h
        let A3 = A * A * A
        let B3 = B * B * B
        let M = secondDerivatives
        // Broken into sub-expressions to keep the Swift compiler's type
        // checker fast enough for release builds.
        let yLoTerm = A * ys[lo]
        let yHiTerm = B * ys[hi]
        let mLoTerm = (A3 - A) * M[lo]
        let mHiTerm = (B3 - B) * M[hi]
        let mSum = mLoTerm + mHiTerm
        let mScale = (h * h) / T(6)
        return yLoTerm + yHiTerm + mSum * mScale
    }

    // MARK: - Coefficient computation

    /// Solve the tridiagonal system for the second derivatives at each knot.
    /// Uses Thomas algorithm. Returns an array of length `xs.count`.
    @usableFromInline
    internal static func computeSecondDerivatives(
        xs: [T],
        ys: [T],
        boundary: BoundaryCondition
    ) -> [T] {
        let n = xs.count
        if n < 2 { return [T](repeating: T(0), count: n) }
        if n == 2 {
            // Two points can only arrive here as `.clamped` — every other boundary condition
            // requires three — and the answer is the cubic Hermite through them, not a line.
            //
            // "Second derivatives are 0" was true of exactly one case: `left == right == delta`,
            // the straight line the slopes already describe. For any other endpoint slopes the
            // caller's `left` and `right` were **silently discarded** while `interp.boundary`
            // went on reporting them, so `.clamped` ignored the one thing it exists to specify.
            //
            // Solving the 2x2 clamped system this file writes out for n > 2,
            //     2h*M0 +  h*M1 = 6*(delta - left)
            //      h*M0 + 2h*M1 = 6*(right - delta)
            // gives M0 = (6*delta - 4*left - 2*right)/h and M1 = (2*left - 6*delta + 4*right)/h.
            // Substituting them into the evaluation in `callAsFunction(_:)` recovers
            // f'(x0) = left and f'(x1) = right exactly, and collapses to [0, 0] when both
            // slopes equal delta — so the degenerate case the old branch handled is unchanged.
            guard case .clamped(let left, let right) = boundary else {
                // Unreachable through any initialiser: `init` requires 3 points for `.natural`,
                // `.notAKnot` and `.periodic`. Reached only by calling this internal method
                // directly with two points and one of those conditions, where there are no
                // endpoint slopes to solve for and the interpolant through two points is the
                // straight line whose second derivative genuinely is zero.
                return [T(0), T(0)]
            }
            let h0: T = xs[1] - xs[0]
            let delta0: T = (ys[1] - ys[0]) / h0
            let leftPart: T = T(6) * delta0 - T(4) * left
            let rightPart: T = T(2) * left - T(6) * delta0
            let m0: T = (leftPart - T(2) * right) / h0
            let m1: T = (rightPart + T(4) * right) / h0
            return [m0, m1]
        }

        // Step sizes h[i] = xs[i+1] - xs[i]
        var h = [T](repeating: T(0), count: n - 1)
        for i in 0..<(n - 1) { h[i] = xs[i + 1] - xs[i] }

        // Slopes delta[i] = (ys[i+1] - ys[i]) / h[i]
        var delta = [T](repeating: T(0), count: n - 1)
        for i in 0..<(n - 1) { delta[i] = (ys[i + 1] - ys[i]) / h[i] }

        switch boundary {
        case .natural:
            return naturalSpline(xs: xs, ys: ys, h: h, delta: delta)
        case .notAKnot:
            return notAKnotSpline(xs: xs, ys: ys, h: h, delta: delta)
        case .clamped(let left, let right):
            return clampedSpline(xs: xs, ys: ys, h: h, delta: delta, left: left, right: right)
        case .periodic:
            return periodicSpline(xs: xs, ys: ys, h: h, delta: delta)
        }
    }

    // MARK: Boundary-condition implementations

    /// Natural BC: M[0] = M[n-1] = 0. Solves the (n-2)-size tridiagonal interior.
    private static func naturalSpline(xs: [T], ys: [T], h: [T], delta: [T]) -> [T] {
        let n = xs.count
        let interior = n - 2
        var sub = [T](repeating: T(0), count: interior)
        var diag = [T](repeating: T(0), count: interior)
        var sup = [T](repeating: T(0), count: interior)
        var rhs = [T](repeating: T(0), count: interior)
        for i in 1..<(n - 1) {
            let row = i - 1
            sub[row] = h[i - 1]
            diag[row] = T(2) * (h[i - 1] + h[i])
            sup[row] = h[i]
            rhs[row] = T(6) * (delta[i] - delta[i - 1])
        }
        let Minterior = thomasSolve(sub: sub, diag: diag, sup: sup, rhs: rhs)
        var M = [T](repeating: T(0), count: n)
        for i in 0..<interior { M[i + 1] = Minterior[i] }
        return M
    }

    /// Clamped BC: f'(x[0]) = left, f'(x[n-1]) = right. Solves the full n-size system.
    private static func clampedSpline(
        xs: [T], ys: [T], h: [T], delta: [T], left: T, right: T
    ) -> [T] {
        let n = xs.count
        var sub = [T](repeating: T(0), count: n)
        var diag = [T](repeating: T(0), count: n)
        var sup = [T](repeating: T(0), count: n)
        var rhs = [T](repeating: T(0), count: n)

        // First row: 2*h[0]*M[0] + h[0]*M[1] = 6*(delta[0] - left)
        diag[0] = T(2) * h[0]
        sup[0] = h[0]
        rhs[0] = T(6) * (delta[0] - left)

        // Interior rows
        for i in 1..<(n - 1) {
            sub[i] = h[i - 1]
            diag[i] = T(2) * (h[i - 1] + h[i])
            sup[i] = h[i]
            rhs[i] = T(6) * (delta[i] - delta[i - 1])
        }

        // Last row: h[n-2]*M[n-2] + 2*h[n-2]*M[n-1] = 6*(right - delta[n-2])
        sub[n - 1] = h[n - 2]
        diag[n - 1] = T(2) * h[n - 2]
        rhs[n - 1] = T(6) * (right - delta[n - 2])

        return thomasSolve(sub: sub, diag: diag, sup: sup, rhs: rhs)
    }

    /// Not-a-knot BC: third derivative continuous at xs[1] and xs[n-2].
    /// Equivalently: the first two intervals share the same cubic, and the
    /// last two intervals share the same cubic. Solves the (n-2) interior
    /// system with modified first and last rows.
    private static func notAKnotSpline(xs: [T], ys: [T], h: [T], delta: [T]) -> [T] {
        let n = xs.count
        if n == 3 {
            // Special degenerate case: only one interior unknown.
            // Not-a-knot reduces to a single quadratic through all 3 points.
            // The single interior second derivative satisfies:
            //   (h0 + h1) * M[1] = 3*(delta[1] - delta[0])  (from quadratic)
            // Reuse natural here as a stable fallback for n = 3.
            return naturalSpline(xs: xs, ys: ys, h: h, delta: delta)
        }

        let interior = n - 2
        var sub = [T](repeating: T(0), count: interior)
        var diag = [T](repeating: T(0), count: interior)
        var sup = [T](repeating: T(0), count: interior)
        var rhs = [T](repeating: T(0), count: interior)

        // Standard interior rows for i = 2..n-3 (zero-indexed positions 1..interior-2)
        for i in 1..<(n - 1) {
            let row = i - 1
            sub[row] = h[i - 1]
            diag[row] = T(2) * (h[i - 1] + h[i])
            sup[row] = h[i]
            rhs[row] = T(6) * (delta[i] - delta[i - 1])
        }

        // Modify first row for not-a-knot at i = 1:
        //   M[0] = M[1] - (h[0] / h[1]) * (M[2] - M[1])
        //        = (1 + h[0]/h[1]) * M[1] - (h[0]/h[1]) * M[2]
        // Substitute into the standard equation for row 0 (i.e. for M[1]):
        //   h[0]*M[0] + 2*(h[0]+h[1])*M[1] + h[1]*M[2] = 6*(delta[1] - delta[0])
        // After substitution, the first row's coefficients become:
        //   diag[0] = 2*(h[0]+h[1]) + h[0]*(1 + h[0]/h[1])
        //           = (h[0] + h[1])*(h[0] + 2*h[1]) / h[1]
        //   sup[0]  = h[1] - h[0]*(h[0]/h[1]) = (h[1]^2 - h[0]^2) / h[1]
        let h0 = h[0]
        let h1 = h[1]
        let leadingSpan: T = h0 + h1
        let leadingWeight: T = h0 + T(2) * h1
        diag[0] = leadingSpan * leadingWeight / h1
        sup[0] = (h1 * h1 - h0 * h0) / h1
        // rhs[0] is unchanged from the standard case

        // Modify last row for not-a-knot at i = n-2:
        //   M[n-1] = (1 + h[n-2]/h[n-3]) * M[n-2] - (h[n-2]/h[n-3]) * M[n-3]
        // After substitution into the standard last interior equation:
        //   sub[interior-1] = h[n-3] - h[n-2]*(h[n-2]/h[n-3]) = (h[n-3]^2 - h[n-2]^2) / h[n-3]
        //   diag[interior-1] = (h[n-3] + h[n-2])*(h[n-3] + 2*h[n-2])... wait, symmetric
        //                    = (h[n-2] + h[n-3]) * (h[n-2] + 2*h[n-3]) / h[n-3]
        let hL = h[n - 3]    // h[n-3]
        let hLast = h[n - 2] // h[n-2]
        let trailingSpan: T = hLast + hL
        let trailingWeight: T = hLast + T(2) * hL
        diag[interior - 1] = trailingSpan * trailingWeight / hL
        sub[interior - 1] = (hL * hL - hLast * hLast) / hL
        // rhs[interior-1] unchanged

        let Minterior = thomasSolve(sub: sub, diag: diag, sup: sup, rhs: rhs)

        // Reconstruct M[0] and M[n-1] using the not-a-knot definitions
        var M = [T](repeating: T(0), count: n)
        for i in 0..<interior { M[i + 1] = Minterior[i] }
        M[0] = (T(1) + h0 / h1) * M[1] - (h0 / h1) * M[2]
        M[n - 1] = (T(1) + hLast / hL) * M[n - 2] - (hLast / hL) * M[n - 3]
        return M
    }

    /// Periodic BC: f, f', f'' match at endpoints. Requires ys.first == ys.last.
    /// Solves a cyclic tridiagonal system via Sherman-Morrison.
    private static func periodicSpline(xs: [T], ys: [T], h: [T], delta: [T]) -> [T] {
        // Periodic system size is (n-1) — the last knot is identified with the first.
        // System: for i = 0..n-2,
        //   h[i-1]*M[i-1] + 2*(h[i-1] + h[i])*M[i] + h[i]*M[i+1] = 6*(delta[i] - delta[i-1])
        // with cyclic indexing: M[-1] = M[n-2], M[n-1] = M[0].
        //
        // Solve via Sherman-Morrison: write the cyclic system as a regular
        // tridiagonal plus a rank-1 correction.
        let n = xs.count
        let m = n - 1   // system size

        // Cyclic indexing helper
        func hCyclic(_ i: Int) -> T { h[(i + (n - 1)) % (n - 1)] }
        func deltaCyclic(_ i: Int) -> T { delta[(i + (n - 1)) % (n - 1)] }

        var sub = [T](repeating: T(0), count: m)
        var diag = [T](repeating: T(0), count: m)
        var sup = [T](repeating: T(0), count: m)
        var rhs = [T](repeating: T(0), count: m)

        for i in 0..<m {
            let hPrev = hCyclic(i - 1)
            let hCurr = hCyclic(i)
            sub[i] = hPrev
            diag[i] = T(2) * (hPrev + hCurr)
            sup[i] = hCurr
            rhs[i] = T(6) * (deltaCyclic(i) - deltaCyclic(i - 1))
        }

        // For periodic BCs the system has nonzero corner entries:
        //   row 0: sub[0] is the cyclic wrap to column m-1
        //   row m-1: sup[m-1] is the cyclic wrap to column 0
        // Use Sherman-Morrison: A = T + u*v^T where T is the tridiagonal core
        // and u, v are chosen to add the corner entries.
        let alpha = sub[0]      // top-right corner of the cyclic system (wraps from row 0 to column m-1)
        let beta = sup[m - 1]   // bottom-left corner (wraps from row m-1 to column 0)
        // Modify the diagonal for Sherman-Morrison stability
        let gamma = -diag[0]
        diag[0] = diag[0] - gamma
        diag[m - 1] = diag[m - 1] - alpha * beta / gamma

        // Zero out the corners on the tridiagonal core
        sub[0] = T(0)
        sup[m - 1] = T(0)

        let y1 = thomasSolve(sub: sub, diag: diag, sup: sup, rhs: rhs)
        var u = [T](repeating: T(0), count: m)
        u[0] = gamma
        u[m - 1] = beta
        let y2 = thomasSolve(sub: sub, diag: diag, sup: sup, rhs: u)

        // v = (1, 0, ..., 0, alpha/gamma)
        let vDotY1 = y1[0] + (alpha / gamma) * y1[m - 1]
        let vDotY2 = y2[0] + (alpha / gamma) * y2[m - 1]
        let factor = vDotY1 / (T(1) + vDotY2)

        var Mreduced = [T](repeating: T(0), count: m)
        for i in 0..<m { Mreduced[i] = y1[i] - factor * y2[i] }

        // Periodic: M[n-1] = M[0]
        var M = [T](repeating: T(0), count: n)
        for i in 0..<m { M[i] = Mreduced[i] }
        M[n - 1] = M[0]
        return M
    }

    // MARK: - Thomas algorithm

    /// Solves a tridiagonal linear system in O(n) time.
    /// Modifies copies internally; inputs are not mutated.
    ///
    /// ## No pivoting, and why that is safe here
    ///
    /// There is no pivot check on `d[i - 1]` and no divide-by-zero guard anywhere in this
    /// directory. That was probed rather than assumed, because two *adjacent* abscissae can
    /// be distinct and still be a fraction of an ulp apart — `xs[i] - xs[i-1] ≈ 1e-300` passes
    /// `validateXY`'s exact-equality check — and the slopes `delta` built from them overflow
    /// to `±infinity`. The question that decides whether that is a contract violation is
    /// whether an `inf - inf` in the forward sweep can cancel back to a **finite but wrong**
    /// number, which would be silent. It cannot:
    ///
    /// - `inf - inf` is NaN in IEEE-754 under every rounding mode; subtraction of two
    ///   infinities has no finite result. So the sweep cannot manufacture a plausible number
    ///   out of two infinities.
    /// - NaN is absorbing through everything below. This function is pure arithmetic —
    ///   `+ - * /` and nothing else. It has no comparison, no branch on the data, no `min`,
    ///   `max` or `sorted`, which is where §2 of the contaminated-input contract says NaN
    ///   turns into a *decision* instead of a value. So a NaN in `d` or `r` reaches `M`, and
    ///   `callAsFunction(_:)` propagates it to the caller as `.nan` — contract §3.1.
    /// - The one mechanism that *could* restore finiteness is `finite / inf = 0`, at
    ///   `factor = sub[i] / d[i - 1]`. It needs an infinite pivot, and the `.natural` and
    ///   `.clamped` systems cannot produce one: both are strictly diagonally dominant with
    ///   positive entries, and `d[i] = 2(h[i-1] + h[i]) - h[i-1]²/d[i-1] ≥ h[i-1] + 2h[i]`
    ///   by induction from `d[0] = 2(h[0] + h[1])`, so `d[i] > 0` and stays of the order of
    ///   the step sizes. Measured on `xs = [-1, 0, 1e-300, 1, 2]`: `d` came out
    ///   `[2.0, 2.0, 3.5]` while `delta[1]` was `+infinity`.
    ///
    /// Measured outcomes for a near-duplicate interval, natural BC, five knots:
    ///
    /// | `delta` at the tiny interval | `M` | verdict |
    /// |---|---|---|
    /// | `1e300`, finite | finite, `~3e300` | ill-conditioned, not contaminated |
    /// | `+infinity` | `[0, inf, -inf, inf, 0]` | propagates; every query is `±inf` or `nan` |
    /// | two adjacent near-duplicates, `inf - inf` in `rhs` | all `nan` | propagates |
    ///
    /// The first row is the honest caveat and is **not** a defect this can fix: an interval of
    /// width `1e-300` carrying an ordinary rise really does have a slope of `1e300`, and no
    /// guard can tell that apart from legitimately steep data. The values it produces are of
    /// order `1e300`, so they do not read as an answer either. Adding a pivot or a
    /// minimum-spacing threshold would mean choosing a scale the caller's data does not have.
    ///
    /// So: no guard is added here. A pivot would only convert an infinity that already
    /// propagates correctly into a different infinity, and a `nan` that already propagates
    /// correctly into a fabricated finite one.
    @usableFromInline
    internal static func thomasSolve(
        sub: [T], diag: [T], sup: [T], rhs: [T]
    ) -> [T] {
        let n = diag.count
        if n == 0 { return [] }
        if n == 1 { return [rhs[0] / diag[0]] }
        var d = diag
        var r = rhs
        for i in 1..<n {
            let factor = sub[i] / d[i - 1]
            d[i] = d[i] - factor * sup[i - 1]
            r[i] = r[i] - factor * r[i - 1]
        }
        var x = [T](repeating: T(0), count: n)
        x[n - 1] = r[n - 1] / d[n - 1]
        if n >= 2 {
            for i in stride(from: n - 2, through: 0, by: -1) {
                x[i] = (r[i] - sup[i] * x[i + 1]) / d[i]
            }
        }
        return x
    }
}

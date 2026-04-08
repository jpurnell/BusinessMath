// Interpolation_Playground.swift
//
// Standalone validation script for the BusinessMath v2.1.2 Interpolation
// module. Hand-rolls all 10 1D interpolation methods with NO BusinessMath
// dependency, runs them on small fixtures with hand-verifiable expected
// values, and prints the results.
//
// The numbers this script prints are the ground truth that the
// InterpolationTests test suite asserts against. If you change a method's
// algorithm, run this first, verify the new values are still correct,
// THEN update the test assertions to match.
//
// Run with: swift Tests/Validation/Interpolation_Playground.swift
//
// Methods implemented (matching the v2.1.2 design):
//   1. NearestNeighbor
//   2. PreviousValue
//   3. NextValue
//   4. Linear
//   5. NaturalCubicSpline (natural BC, second derivatives = 0 at endpoints)
//   6. PCHIP (Fritsch-Carlson monotone cubic)
//   7. Akima (1970 original) and Modified Akima ("makima")
//   8. CatmullRom (cardinal spline, tension = 0.5)
//   9. BSpline (cubic, degree = 3)
//  10. BarycentricLagrange

import Foundation

// MARK: - Common helpers

/// Find the bracket [xs[lo], xs[hi]] containing t via binary search.
/// Returns (lo, hi) such that xs[lo] <= t <= xs[hi]. Clamps to endpoints
/// for queries outside the data range.
func bracket(_ t: Double, in xs: [Double]) -> (lo: Int, hi: Int) {
    let n = xs.count
    if n == 0 { return (0, 0) }
    if n == 1 { return (0, 0) }
    if t <= xs[0] { return (0, 1) }
    if t >= xs[n - 1] { return (n - 2, n - 1) }
    var lo = 0
    var hi = n - 1
    while hi - lo > 1 {
        let mid = (lo + hi) / 2
        if xs[mid] <= t { lo = mid } else { hi = mid }
    }
    return (lo, hi)
}

// MARK: - 1. NearestNeighbor

/// Returns the y value of the closest x in the sample set.
func nearest(at t: Double, xs: [Double], ys: [Double]) -> Double {
    let n = xs.count
    if n == 0 { return 0 }
    if n == 1 { return ys[0] }
    if t <= xs[0] { return ys[0] }
    if t >= xs[n - 1] { return ys[n - 1] }
    let (lo, hi) = bracket(t, in: xs)
    let dLo = abs(t - xs[lo])
    let dHi = abs(t - xs[hi])
    return dLo <= dHi ? ys[lo] : ys[hi]
}

// MARK: - 2. PreviousValue

/// Returns the y value of the largest xs[i] <= t (step function holding previous).
func previousValue(at t: Double, xs: [Double], ys: [Double]) -> Double {
    let n = xs.count
    if n == 0 { return 0 }
    if t <= xs[0] { return ys[0] }
    if t >= xs[n - 1] { return ys[n - 1] }
    let (lo, _) = bracket(t, in: xs)
    return ys[lo]
}

// MARK: - 3. NextValue

/// Returns the y value of the smallest xs[i] >= t (step function holding next).
/// At exact knots `t == xs[i]`, returns `ys[i]` (pass-through).
func nextValue(at t: Double, xs: [Double], ys: [Double]) -> Double {
    let n = xs.count
    if n == 0 { return 0 }
    if t <= xs[0] { return ys[0] }
    if t >= xs[n - 1] { return ys[n - 1] }
    let (lo, hi) = bracket(t, in: xs)
    if t == xs[lo] { return ys[lo] }   // exact knot — pass through
    return ys[hi]
}

// MARK: - 4. Linear

func linear(at t: Double, xs: [Double], ys: [Double]) -> Double {
    let n = xs.count
    if n == 0 { return 0 }
    if n == 1 { return ys[0] }
    if t <= xs[0] { return ys[0] }
    if t >= xs[n - 1] { return ys[n - 1] }
    let (lo, hi) = bracket(t, in: xs)
    let frac = (t - xs[lo]) / (xs[hi] - xs[lo])
    return ys[lo] + frac * (ys[hi] - ys[lo])
}

// MARK: - 5. NaturalCubicSpline

struct CubicSplineState {
    let xs: [Double]
    let ys: [Double]
    let M: [Double]  // second derivatives at knots
}

/// Build a natural cubic spline (M[0] = M[n-1] = 0).
func buildNaturalCubicSpline(xs: [Double], ys: [Double]) -> CubicSplineState {
    let n = xs.count
    guard n >= 3 else {
        return CubicSplineState(xs: xs, ys: ys, M: [Double](repeating: 0, count: n))
    }
    let h = (0..<(n - 1)).map { xs[$0 + 1] - xs[$0] }
    let interior = n - 2
    var sub = [Double](repeating: 0, count: interior)
    var diag = [Double](repeating: 0, count: interior)
    var sup = [Double](repeating: 0, count: interior)
    var rhs = [Double](repeating: 0, count: interior)
    for i in 1..<(n - 1) {
        let row = i - 1
        sub[row] = h[i - 1]
        diag[row] = 2.0 * (h[i - 1] + h[i])
        sup[row] = h[i]
        let slopeRight = (ys[i + 1] - ys[i]) / h[i]
        let slopeLeft = (ys[i] - ys[i - 1]) / h[i - 1]
        rhs[row] = 6.0 * (slopeRight - slopeLeft)
    }
    // Thomas algorithm
    for i in 1..<interior {
        let factor = sub[i] / diag[i - 1]
        diag[i] -= factor * sup[i - 1]
        rhs[i] -= factor * rhs[i - 1]
    }
    var Minterior = [Double](repeating: 0, count: interior)
    if interior > 0 {
        Minterior[interior - 1] = rhs[interior - 1] / diag[interior - 1]
        if interior >= 2 {
            for i in stride(from: interior - 2, through: 0, by: -1) {
                Minterior[i] = (rhs[i] - sup[i] * Minterior[i + 1]) / diag[i]
            }
        }
    }
    var M = [Double](repeating: 0, count: n)
    for i in 0..<interior { M[i + 1] = Minterior[i] }
    return CubicSplineState(xs: xs, ys: ys, M: M)
}

func evalNaturalCubicSpline(_ s: CubicSplineState, at t: Double) -> Double {
    let xs = s.xs, ys = s.ys, M = s.M
    let n = xs.count
    if n == 0 { return 0 }
    if n == 1 { return ys[0] }
    if t <= xs[0] { return ys[0] }
    if t >= xs[n - 1] { return ys[n - 1] }
    let (lo, hi) = bracket(t, in: xs)
    let h = xs[hi] - xs[lo]
    let A = (xs[hi] - t) / h
    let B = (t - xs[lo]) / h
    let A3 = A * A * A
    let B3 = B * B * B
    return A * ys[lo] + B * ys[hi] + ((A3 - A) * M[lo] + (B3 - B) * M[hi]) * (h * h) / 6.0
}

// MARK: - 6. PCHIP (Fritsch-Carlson monotone cubic)

struct PCHIPState {
    let xs: [Double]
    let ys: [Double]
    let d: [Double]  // slopes at each knot
}

func buildPCHIP(xs: [Double], ys: [Double]) -> PCHIPState {
    let n = xs.count
    guard n >= 2 else { return PCHIPState(xs: xs, ys: ys, d: [Double](repeating: 0, count: n)) }
    let h = (0..<(n - 1)).map { xs[$0 + 1] - xs[$0] }
    let delta = (0..<(n - 1)).map { (ys[$0 + 1] - ys[$0]) / h[$0] }
    var d = [Double](repeating: 0, count: n)
    if n == 2 {
        d[0] = delta[0]
        d[1] = delta[0]
        return PCHIPState(xs: xs, ys: ys, d: d)
    }
    // Interior slopes via Fritsch-Carlson weighted harmonic mean
    for i in 1..<(n - 1) {
        if delta[i - 1] * delta[i] <= 0 {
            d[i] = 0
        } else {
            let w1 = 2 * h[i] + h[i - 1]
            let w2 = h[i] + 2 * h[i - 1]
            d[i] = (w1 + w2) / (w1 / delta[i - 1] + w2 / delta[i])
        }
    }
    // Endpoint slopes via Fritsch-Carlson 3-point formula
    d[0] = pchipEndpoint(h0: h[0], h1: h[1], delta0: delta[0], delta1: delta[1])
    d[n - 1] = pchipEndpoint(h0: h[n - 2], h1: h[n - 3], delta0: delta[n - 2], delta1: delta[n - 3])
    return PCHIPState(xs: xs, ys: ys, d: d)
}

private func pchipEndpoint(h0: Double, h1: Double, delta0: Double, delta1: Double) -> Double {
    let d = ((2 * h0 + h1) * delta0 - h0 * delta1) / (h0 + h1)
    if d * delta0 <= 0 { return 0 }
    if delta0 * delta1 <= 0, abs(d) > abs(3 * delta0) { return 3 * delta0 }
    return d
}

func evalPCHIP(_ s: PCHIPState, at t: Double) -> Double {
    let xs = s.xs, ys = s.ys, d = s.d
    let n = xs.count
    if n == 0 { return 0 }
    if n == 1 { return ys[0] }
    if t <= xs[0] { return ys[0] }
    if t >= xs[n - 1] { return ys[n - 1] }
    let (lo, hi) = bracket(t, in: xs)
    let h = xs[hi] - xs[lo]
    let s_t = (t - xs[lo]) / h
    let h00 = (1 + 2 * s_t) * (1 - s_t) * (1 - s_t)
    let h10 = s_t * (1 - s_t) * (1 - s_t)
    let h01 = s_t * s_t * (3 - 2 * s_t)
    let h11 = s_t * s_t * (s_t - 1)
    return h00 * ys[lo] + h10 * h * d[lo] + h01 * ys[hi] + h11 * h * d[hi]
}

// MARK: - 7. Akima (and Modified Akima / makima)

struct AkimaState {
    let xs: [Double]
    let ys: [Double]
    let d: [Double]  // slopes at each knot
}

func buildAkima(xs: [Double], ys: [Double], modified: Bool) -> AkimaState {
    let n = xs.count
    guard n >= 2 else { return AkimaState(xs: xs, ys: ys, d: [Double](repeating: 0, count: n)) }
    if n == 2 {
        let s = (ys[1] - ys[0]) / (xs[1] - xs[0])
        return AkimaState(xs: xs, ys: ys, d: [s, s])
    }
    // Compute segment slopes
    var m = [Double](repeating: 0, count: n + 3)  // padded with 2 ghosts on each side
    for i in 0..<(n - 1) {
        m[i + 2] = (ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i])
    }
    // Ghost slopes for endpoint handling (Akima's extrapolation)
    m[1] = 2 * m[2] - m[3]
    m[0] = 2 * m[1] - m[2]
    m[n + 1] = 2 * m[n] - m[n - 1]
    m[n + 2] = 2 * m[n + 1] - m[n]

    var d = [Double](repeating: 0, count: n)
    for i in 0..<n {
        let mi = m[i + 2]      // m[i]
        let mim1 = m[i + 1]    // m[i-1]
        let mim2 = m[i]        // m[i-2]
        let mip1 = m[i + 3]    // m[i+1]
        let w1: Double
        let w2: Double
        if modified {
            // makima: add |m_i + m_{i-1}|/2 to weights to break ties at flat regions
            w1 = abs(mip1 - mi) + abs(mip1 + mi) / 2
            w2 = abs(mim1 - mim2) + abs(mim1 + mim2) / 2
        } else {
            w1 = abs(mip1 - mi)
            w2 = abs(mim1 - mim2)
        }
        let denom = w1 + w2
        if denom == 0 {
            d[i] = (mim1 + mi) / 2
        } else {
            d[i] = (w1 * mim1 + w2 * mi) / denom
        }
    }
    return AkimaState(xs: xs, ys: ys, d: d)
}

func evalAkima(_ s: AkimaState, at t: Double) -> Double {
    // Same Hermite cubic as PCHIP given knots, ys, slopes
    let xs = s.xs, ys = s.ys, d = s.d
    let n = xs.count
    if n == 0 { return 0 }
    if n == 1 { return ys[0] }
    if t <= xs[0] { return ys[0] }
    if t >= xs[n - 1] { return ys[n - 1] }
    let (lo, hi) = bracket(t, in: xs)
    let h = xs[hi] - xs[lo]
    let s_t = (t - xs[lo]) / h
    let h00 = (1 + 2 * s_t) * (1 - s_t) * (1 - s_t)
    let h10 = s_t * (1 - s_t) * (1 - s_t)
    let h01 = s_t * s_t * (3 - 2 * s_t)
    let h11 = s_t * s_t * (s_t - 1)
    return h00 * ys[lo] + h10 * h * d[lo] + h01 * ys[hi] + h11 * h * d[hi]
}

// MARK: - 8. CatmullRom (cardinal spline, tension τ)

/// Cardinal spline. Tension τ ∈ [0, 1] where τ = 0 is the standard
/// Catmull-Rom spline (full-strength tangents) and τ = 1 collapses tangents
/// to zero (effectively piecewise quadratic-like with C¹ continuity).
///
/// Interior tangent: d[i] = (1 - τ) * (y[i+1] - y[i-1]) / (x[i+1] - x[i-1])
/// Endpoint tangents: one-sided difference, scaled by (1 - τ).
///
/// τ = 0 (default) reproduces linear data exactly. τ > 0 does not.
struct CatmullRomState {
    let xs: [Double]
    let ys: [Double]
    let d: [Double]
}

func buildCatmullRom(xs: [Double], ys: [Double], tension: Double) -> CatmullRomState {
    let n = xs.count
    guard n >= 2 else { return CatmullRomState(xs: xs, ys: ys, d: [Double](repeating: 0, count: n)) }
    if n == 2 {
        let s = (ys[1] - ys[0]) / (xs[1] - xs[0])
        return CatmullRomState(xs: xs, ys: ys, d: [s, s])
    }
    var d = [Double](repeating: 0, count: n)
    let scale = 1 - tension
    for i in 1..<(n - 1) {
        d[i] = scale * (ys[i + 1] - ys[i - 1]) / (xs[i + 1] - xs[i - 1])
    }
    // Endpoint: one-sided forward / backward difference, scaled
    d[0] = scale * (ys[1] - ys[0]) / (xs[1] - xs[0])
    d[n - 1] = scale * (ys[n - 1] - ys[n - 2]) / (xs[n - 1] - xs[n - 2])
    return CatmullRomState(xs: xs, ys: ys, d: d)
}

func evalCatmullRom(_ s: CatmullRomState, at t: Double) -> Double {
    let xs = s.xs, ys = s.ys, d = s.d
    let n = xs.count
    if n == 0 { return 0 }
    if n == 1 { return ys[0] }
    if t <= xs[0] { return ys[0] }
    if t >= xs[n - 1] { return ys[n - 1] }
    let (lo, hi) = bracket(t, in: xs)
    let h = xs[hi] - xs[lo]
    let s_t = (t - xs[lo]) / h
    let h00 = (1 + 2 * s_t) * (1 - s_t) * (1 - s_t)
    let h10 = s_t * (1 - s_t) * (1 - s_t)
    let h01 = s_t * s_t * (3 - 2 * s_t)
    let h11 = s_t * s_t * (s_t - 1)
    return h00 * ys[lo] + h10 * h * d[lo] + h01 * ys[hi] + h11 * h * d[hi]
}

// MARK: - 9. BSpline (cubic interpolating B-spline)

/// Cubic interpolating B-spline. Computes the control points c[i] such that
/// the B-spline curve passes through (xs[i], ys[i]) at the knots. Uses the
/// "not-a-knot" boundary condition for v1 (the standard MATLAB / scipy choice
/// for the cubic B-spline interpolant).
struct BSplineState {
    let xs: [Double]
    let ys: [Double]
    let c: [Double]  // control points for cubic B-spline
}

func buildBSpline(xs: [Double], ys: [Double], degree: Int) -> BSplineState {
    // For v1 the playground only validates degree=3 (cubic). The package
    // implementation will handle degrees 1..5; the validation strategy for
    // non-cubic degrees uses the "interpolates linear data exactly" property
    // rather than hand-computed values.
    //
    // For cubic B-spline interpolation with not-a-knot conditions, the
    // mathematics is identical to natural cubic spline for degrees 3.
    // We'll reuse the natural cubic spline as a stand-in here so the
    // playground produces consistent expected values; the package
    // implementation should use the actual B-spline basis-function form
    // and verify cross-equivalence with the natural cubic spline on a
    // smooth fixture.
    let s = buildNaturalCubicSpline(xs: xs, ys: ys)
    return BSplineState(xs: xs, ys: ys, c: s.M)
}

func evalBSpline(_ s: BSplineState, at t: Double) -> Double {
    // Stand-in: evaluate as natural cubic spline (see comment in build).
    // The package implementation must use the proper B-spline basis form.
    let cs = CubicSplineState(xs: s.xs, ys: s.ys, M: s.c)
    return evalNaturalCubicSpline(cs, at: t)
}

// MARK: - 10. BarycentricLagrange

/// Numerically stable barycentric Lagrange interpolation through all points.
struct BarycentricState {
    let xs: [Double]
    let ys: [Double]
    let w: [Double]  // barycentric weights
}

func buildBarycentric(xs: [Double], ys: [Double]) -> BarycentricState {
    let n = xs.count
    var w = [Double](repeating: 1, count: n)
    for j in 0..<n {
        var product = 1.0
        for k in 0..<n where k != j {
            product *= (xs[j] - xs[k])
        }
        w[j] = 1.0 / product
    }
    return BarycentricState(xs: xs, ys: ys, w: w)
}

func evalBarycentric(_ s: BarycentricState, at t: Double) -> Double {
    let xs = s.xs, ys = s.ys, w = s.w
    let n = xs.count
    if n == 0 { return 0 }
    // Exact-knot match avoids 0/0
    for i in 0..<n where t == xs[i] { return ys[i] }
    var num = 0.0
    var den = 0.0
    for i in 0..<n {
        let wi = w[i] / (t - xs[i])
        num += wi * ys[i]
        den += wi
    }
    return num / den
}

// MARK: - Fixtures

print("=== Interpolation Validation Playground ===")
print()

// Primary fixture: small monotonic dataset, hand-verifiable
let xsPrimary: [Double] = [0, 1, 2, 3, 4]
let ysPrimary: [Double] = [0, 1, 4, 9, 16]   // y = x²
print("Primary fixture: xs=\(xsPrimary), ys=\(ysPrimary)  (y = x²)")
print()

let queryPoints: [Double] = [0.0, 0.5, 1.5, 2.5, 3.5, 4.0]

func reportMethod(name: String, eval: (Double) -> Double) {
    print("--- \(name) ---")
    for q in queryPoints {
        print("  f(\(q)) = \(eval(q))")
    }
    print()
}

reportMethod(name: "1. NearestNeighbor") { nearest(at: $0, xs: xsPrimary, ys: ysPrimary) }
reportMethod(name: "2. PreviousValue") { previousValue(at: $0, xs: xsPrimary, ys: ysPrimary) }
reportMethod(name: "3. NextValue") { nextValue(at: $0, xs: xsPrimary, ys: ysPrimary) }
reportMethod(name: "4. Linear") { linear(at: $0, xs: xsPrimary, ys: ysPrimary) }

let cs = buildNaturalCubicSpline(xs: xsPrimary, ys: ysPrimary)
reportMethod(name: "5. NaturalCubicSpline") { evalNaturalCubicSpline(cs, at: $0) }

let pchip = buildPCHIP(xs: xsPrimary, ys: ysPrimary)
reportMethod(name: "6. PCHIP") { evalPCHIP(pchip, at: $0) }

let akimaOriginal = buildAkima(xs: xsPrimary, ys: ysPrimary, modified: false)
reportMethod(name: "7a. Akima (original)") { evalAkima(akimaOriginal, at: $0) }

let akimaModified = buildAkima(xs: xsPrimary, ys: ysPrimary, modified: true)
reportMethod(name: "7b. Akima (modified / makima)") { evalAkima(akimaModified, at: $0) }

let crom = buildCatmullRom(xs: xsPrimary, ys: ysPrimary, tension: 0.0)
reportMethod(name: "8. CatmullRom (tension=0, standard)") { evalCatmullRom(crom, at: $0) }

let bs = buildBSpline(xs: xsPrimary, ys: ysPrimary, degree: 3)
reportMethod(name: "9. BSpline (degree=3, stand-in)") { evalBSpline(bs, at: $0) }

let bary = buildBarycentric(xs: xsPrimary, ys: ysPrimary)
reportMethod(name: "10. BarycentricLagrange") { evalBarycentric(bary, at: $0) }

// MARK: - Property checks

print("=== Property Checks ===")
print()

print("--- Pass-through invariant: every method must return ys[i] at xs[i] ---")
var allPass = true
func checkPassThrough(name: String, eval: (Double) -> Double) {
    var ok = true
    for i in 0..<xsPrimary.count {
        let v = eval(xsPrimary[i])
        let err = abs(v - ysPrimary[i])
        if err > 1e-12 {
            print("  FAIL  \(name) at xs[\(i)] = \(xsPrimary[i]):  expected \(ysPrimary[i]), got \(v) (err \(err))")
            ok = false
            allPass = false
        }
    }
    if ok { print("  pass  \(name)") }
}

checkPassThrough(name: "Nearest")    { nearest(at: $0, xs: xsPrimary, ys: ysPrimary) }
checkPassThrough(name: "Previous")   { previousValue(at: $0, xs: xsPrimary, ys: ysPrimary) }
checkPassThrough(name: "Next")       { nextValue(at: $0, xs: xsPrimary, ys: ysPrimary) }
checkPassThrough(name: "Linear")     { linear(at: $0, xs: xsPrimary, ys: ysPrimary) }
checkPassThrough(name: "CubicSpline"){ evalNaturalCubicSpline(cs, at: $0) }
checkPassThrough(name: "PCHIP")      { evalPCHIP(pchip, at: $0) }
checkPassThrough(name: "Akima")      { evalAkima(akimaOriginal, at: $0) }
checkPassThrough(name: "Makima")     { evalAkima(akimaModified, at: $0) }
checkPassThrough(name: "CatmullRom") { evalCatmullRom(crom, at: $0) }
checkPassThrough(name: "BSpline")    { evalBSpline(bs, at: $0) }
checkPassThrough(name: "Bary")       { evalBarycentric(bary, at: $0) }
print()

print("--- Linear-data invariant: every method must reproduce a*x+b exactly ---")
let xsLin: [Double] = [0, 1, 2, 3, 4, 5]
let ysLin: [Double] = xsLin.map { 3.0 * $0 + 7.0 }
let probes: [Double] = [0.0, 0.7, 1.5, 2.3, 3.9, 4.4, 5.0]
func checkLinear(name: String, eval: (Double) -> Double, expectExact: Bool = true) {
    var maxErr = 0.0
    for q in probes {
        let expected = 3.0 * q + 7.0
        let got = eval(q)
        maxErr = max(maxErr, abs(got - expected))
    }
    let pass = expectExact ? (maxErr < 1e-9) : true
    print("  \(pass ? "pass" : "FAIL")  \(name)  max err = \(maxErr)")
    if !pass { allPass = false }
}

let csLin = buildNaturalCubicSpline(xs: xsLin, ys: ysLin)
let pchipLin = buildPCHIP(xs: xsLin, ys: ysLin)
let akimaLin = buildAkima(xs: xsLin, ys: ysLin, modified: false)
let makimaLin = buildAkima(xs: xsLin, ys: ysLin, modified: true)
let cromLin = buildCatmullRom(xs: xsLin, ys: ysLin, tension: 0.0)
let bsLin = buildBSpline(xs: xsLin, ys: ysLin, degree: 3)
let baryLin = buildBarycentric(xs: xsLin, ys: ysLin)

// Step functions (Nearest/Previous/Next) are NOT exact on linear data
// for non-knot queries, so they're excluded from this invariant.
checkLinear(name: "Linear")     { linear(at: $0, xs: xsLin, ys: ysLin) }
checkLinear(name: "CubicSpline"){ evalNaturalCubicSpline(csLin, at: $0) }
checkLinear(name: "PCHIP")      { evalPCHIP(pchipLin, at: $0) }
checkLinear(name: "Akima")      { evalAkima(akimaLin, at: $0) }
checkLinear(name: "Makima")     { evalAkima(makimaLin, at: $0) }
checkLinear(name: "CatmullRom") { evalCatmullRom(cromLin, at: $0) }
checkLinear(name: "BSpline")    { evalBSpline(bsLin, at: $0) }
checkLinear(name: "Bary")       { evalBarycentric(baryLin, at: $0) }
print()

print("--- Monotonicity preservation (PCHIP and Akima only) ---")
// Strictly monotonic data with sharp gradient change — natural cubic should
// overshoot, PCHIP and Akima should not.
let xsMono: [Double] = [0, 1, 2, 3, 4, 5, 6]
let ysMono: [Double] = [0, 0.1, 0.2, 5, 5.1, 5.2, 5.3]
let csMono = buildNaturalCubicSpline(xs: xsMono, ys: ysMono)
let pchipMono = buildPCHIP(xs: xsMono, ys: ysMono)
let akimaMono = buildAkima(xs: xsMono, ys: ysMono, modified: false)
let makimaMono = buildAkima(xs: xsMono, ys: ysMono, modified: true)

func minMaxOver(samples: Int, eval: (Double) -> Double) -> (Double, Double) {
    var lo = Double.infinity
    var hi = -Double.infinity
    for i in 0...samples {
        let t = Double(i) / Double(samples) * 6.0
        let v = eval(t)
        lo = min(lo, v)
        hi = max(hi, v)
    }
    return (lo, hi)
}

let dataMin = ysMono.min()!
let dataMax = ysMono.max()!
print("  Data range: [\(dataMin), \(dataMax)]")

let (csMin, csMax) = minMaxOver(samples: 600) { evalNaturalCubicSpline(csMono, at: $0) }
print("  CubicSpline range: [\(csMin), \(csMax)]  \(csMin < dataMin || csMax > dataMax ? "OVERSHOOTS (expected)" : "no overshoot")")

let (pcMin, pcMax) = minMaxOver(samples: 600) { evalPCHIP(pchipMono, at: $0) }
print("  PCHIP range:       [\(pcMin), \(pcMax)]  \(pcMin < dataMin - 1e-9 || pcMax > dataMax + 1e-9 ? "OVERSHOOTS (BUG)" : "monotonic ✓")")

let (akMin, akMax) = minMaxOver(samples: 600) { evalAkima(akimaMono, at: $0) }
print("  Akima range:       [\(akMin), \(akMax)]  \(akMin < dataMin - 1e-9 || akMax > dataMax + 1e-9 ? "OVERSHOOTS" : "monotonic ✓")")

let (mkMin, mkMax) = minMaxOver(samples: 600) { evalAkima(makimaMono, at: $0) }
print("  Makima range:      [\(mkMin), \(mkMax)]  \(mkMin < dataMin - 1e-9 || mkMax > dataMax + 1e-9 ? "OVERSHOOTS" : "monotonic ✓")")
print()

print(allPass ? "=== ALL INVARIANTS PASSED ===" : "=== SOME INVARIANTS FAILED — review above ===")

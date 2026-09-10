# Interpolation Module — v2.1.2

**Status:** APPROVED — pending playground validation step before implementation
**Target release:** v2.1.2 (additive, but architecturally significant)
**Driver:** Downstream consumer BioFeedbackKit needs cubic-spline interpolation for HRV frequency-domain analysis. Linear interpolation (the only option today via ad-hoc downstream code) loses 33% amplitude on signal content near Nyquist/2.
**Author / discussion date:** 2026-04-07

---

## 1. Objective

Add a comprehensive 1D interpolation module to BusinessMath as a new top-level
namespace, designed from day one to extend cleanly to N-dimensional gridded
and scattered interpolation in future releases without breaking changes.

The immediate functional driver is HRV frequency-domain analysis in
BioFeedbackKit, which needs accurate resampling of irregularly-spaced RR
interval series onto a uniform grid before FFT. Linear interpolation is
demonstrably inadequate for this use case (33% amplitude loss at 0.25 Hz with
1 Hz input — measured in `narbis/project/plans/upcoming/FrequencyDomain-Playground.swift`).

But interpolation is a general numerical primitive useful far beyond HRV.
Doing it once, comprehensively, in BusinessMath is better than every
downstream consumer reimplementing it.

---

## 2. Scope

### 2.1 What ships in v2.1.2

**One new vector type:**
- `Vector1D<T>` — completes the vector type family. Currently BusinessMath has `Vector2D`, `Vector3D`, `VectorN` but no `Vector1D`. Adding it enables uniform `VectorSpace`-based generic code for the 1D case (which is the most common case in time series, finance, sensor data, etc.) and removes the awkward "is a scalar a vector?" special case from the protocol design below.

**One new protocol:**
- `Interpolator` — single root protocol with `Point: VectorSpace` and `Value: Sendable` associated types. Concrete types pick their domain (`Point`) and codomain (`Value`). All future N-D and scattered interpolators conform to this same protocol.

**Ten 1D scalar-output interpolation methods** (`Point = Vector1D<T>`, `Value = T`):

| # | Method | Parameters | Notes |
|---|---|---|---|
| 1 | `NearestNeighborInterpolator` | — | Closest known value |
| 2 | `PreviousValueInterpolator` | — | Step function holding previous sample (last-known-value semantics) |
| 3 | `NextValueInterpolator` | — | Step function holding next sample |
| 4 | `LinearInterpolator` | — | Piecewise linear |
| 5 | `CubicSplineInterpolator` | `boundary: BoundaryCondition` | Four boundary conditions: `.natural` (default — Kubios HRV standard), `.notAKnot` (MATLAB default), `.clamped(left:right:)` (specified endpoint slopes), `.periodic` (wraps for periodic data) |
| 6 | `PCHIPInterpolator` | — | Fritsch–Carlson monotone cubic. Overshoot-safe. |
| 7 | `AkimaInterpolator` | `modified: Bool = true` | `modified: true` is "makima" (MATLAB's improved Akima, handles flat regions) and is the default. `false` gives the original 1970 Akima. |
| 8 | `CatmullRomInterpolator` | `tension: T = 0.0` | Cardinal spline family. Tension τ = 0 is the standard Catmull-Rom (full-strength tangents). τ > 0 produces a tighter cardinal spline that does NOT reproduce linear data exactly — documented in API docs. |
| 9 | `BSplineInterpolator` | `degree: Int = 3` | Basis spline of degree 1–5 (cubic by default). Distinct from CubicSpline — different basis functions, different smoothness properties. |
| 10 | `BarycentricLagrangeInterpolator` | — | Numerically stable polynomial interpolation. Documented as suitable for small N (≤ 20) due to Runge phenomenon at higher counts. |

**Ten 1D vector-output interpolation methods** (`Point = Vector1D<T>`, `Value = VectorN<T>`):

The same 10 methods, but with `init(xs: [T], ys: [VectorN<T>], ...)` signatures and per-channel coefficient computation. Uses cases:

- Three-axis accelerometer over time → `VectorN` of 3 components per sample
- Multi-channel EEG over time → `VectorN` of N channels per sample
- 3D motion-capture trajectories → `VectorN` of 3 components per sample
- Stock portfolio historical values → `VectorN` of M assets per sample
- Multi-sensor fusion timestamps → `VectorN` of K sensors per sample

Naming convention: prepend `Vector` to the scalar-output type name. So
`VectorCubicSplineInterpolator`, `VectorPCHIPInterpolator`, etc.

**Total v2.1.2 surface:** 1 new vector type, 1 new protocol, 20 interpolator
types, ~1500 LoC estimated.

### 2.2 What does NOT ship in v2.1.2

The following are explicitly deferred to future releases. The protocol surface
makes them additive, not breaking, when they land:

- **2D gridded interpolation** (v2.2 target) — `BilinearInterpolator`, `BicubicInterpolator`, `Bicubic2DCatmullRom`, `Akima2DInterpolator`, `BSpline2DInterpolator`. Requires a `Grid2D<T>` type. `Point = Vector2D<T>`.
- **3D gridded interpolation** (v2.3 target) — `TriLinearInterpolator`, `TriCubicInterpolator`. Requires `Grid3D<T>`. `Point = Vector3D<T>`.
- **N-D gridded interpolation** (v2.3 target) — `MultilinearInterpolator`, tensor-product spline generalizations. Requires `GridND<T>`. `Point = VectorN<T>`.
- **N-D scattered interpolation** (v2.4 target) — Delaunay-based linear, RBF (Gaussian, thin-plate spline, multiquadric, inverse multiquadric), nearest-neighbor via KD-tree. `Point = VectorN<T>` for variable dimension.
- **Lomb–Scargle periodogram** (separate proposal) — not interpolation at all, but an alternative spectral pipeline that operates on irregular samples directly without requiring resampling. Worth its own design proposal as an alternative to "resample then FFT" for HRV and other irregular-sample spectral analysis.

### 2.3 What is NOT going to be added later either (with reasons)

| Excluded | Why |
|---|---|
| Quadratic piecewise | Less smooth than cubic without being simpler than linear. Not used in practice. |
| Lanczos / windowed sinc | Belongs in a future `SignalProcessing/` namespace alongside FIR filters. |
| Lagrange (non-barycentric) | Numerically unstable. Barycentric Lagrange covers the use case. |
| Krogh divided-difference | Niche; scipy has it but rarely used. Add only if requested. |
| Rational / Padé / Stoer–Bulirsch / Thiele | Handles poles, niche numerical use. |
| Steffen monotone cubic | GSL default, but PCHIP is the more common monotone cubic. Avoid duplicate. |
| Kriging / Gaussian process regression | Statistical method with hyperparameters. Belongs in stats/regression namespace. |
| Smoothing splines | Approximation, not interpolation (don't pass through points). Belongs in `Regression/`. |
| Trigonometric / Fourier interpolation | Derivable from FFT for periodic data. Niche. |
| Cubic Hermite (general, user-supplied slopes) | PCHIP and Catmull-Rom cover the common cases. Power-user feature, add later if requested. |

---

## 3. Architecture

### 3.1 The single Interpolator protocol

```swift
/// A function learned from sample points, evaluable at query points in its
/// domain. The shape of the domain (1D, 2D, 3D, N-D) is encoded in the
/// `Point` associated type, which is any conforming `VectorSpace`. The shape
/// of the codomain (scalar field, vector field) is encoded in the `Value`
/// associated type.
public protocol Interpolator: Sendable {
    /// Scalar numeric type used for both coordinates and (typically) values.
    associatedtype Scalar: Real & Sendable & Codable

    /// Type of input query points. Use `Vector1D<T>` for time-series or other
    /// 1D domains, `Vector2D<T>` for image/heightmap domains, `Vector3D<T>`
    /// for volumetric domains, `VectorN<T>` for variable-dimension or
    /// scattered ND data.
    associatedtype Point: VectorSpace where Point.Scalar == Scalar

    /// Type of output values at each query point. Typically `Scalar` for
    /// scalar fields, `VectorN<T>` or a fixed `Vector*D<T>` for vector fields.
    /// Not constrained to `VectorSpace` so that scalar-valued interpolators
    /// can use `T` directly without wrapping.
    associatedtype Value: Sendable

    /// Number of independent variables in the input domain.
    /// Equals `Point.dimension` for fixed-dimension Point types, and the
    /// runtime dimension for `VectorN` Points. Always available without
    /// constructing a Point instance.
    var inputDimension: Int { get }

    /// Number of dependent variables in the output. 1 for scalar fields,
    /// N for vector fields with N components.
    var outputDimension: Int { get }

    /// Evaluate the interpolant at a single query point.
    func callAsFunction(at query: Point) -> Value

    /// Evaluate at multiple query points. Concrete types may override for
    /// batch efficiency (often important for stateful methods like cubic
    /// spline that have non-trivial per-query setup).
    func callAsFunction(at queries: [Point]) -> [Value]
}
```

### 3.2 Vector1D — completing the vector type family

```swift
/// A 1-dimensional vector. Trivial wrapper around a single scalar value
/// that conforms to `VectorSpace`, enabling 1D points to participate in
/// any generic code that operates over vector spaces.
///
/// Today BusinessMath has `Vector2D`, `Vector3D`, and `VectorN` but no
/// `Vector1D`. This left 1D scalar values as a special case that couldn't
/// participate in generic vector-space algorithms. `Vector1D` closes that
/// gap and is the natural `Point` type for time-series, scalar fields,
/// and other inherently 1D domains.
public struct Vector1D<T: Real & Sendable & Codable>: VectorSpace {
    public typealias Scalar = T

    public var value: T

    public init(_ value: T) { self.value = value }

    public static var zero: Vector1D<T> { Vector1D(T(0)) }
    public static func + (lhs: Vector1D<T>, rhs: Vector1D<T>) -> Vector1D<T> {
        Vector1D(lhs.value + rhs.value)
    }
    public static func * (lhs: T, rhs: Vector1D<T>) -> Vector1D<T> {
        Vector1D(lhs * rhs.value)
    }
    public static prefix func - (vector: Vector1D<T>) -> Vector1D<T> {
        Vector1D(-vector.value)
    }
    public var norm: T { abs(value) }
    public func dot(_ other: Vector1D<T>) -> T { value * other.value }
    public static func fromArray(_ array: [T]) -> Vector1D<T>? {
        guard array.count == 1 else { return nil }
        return Vector1D(array[0])
    }
    public func toArray() -> [T] { [value] }
    public static var dimension: Int { 1 }
    public var isFinite: Bool { value.isFinite }
}
```

**Initializer naming:** `Vector1D(2.5)` — unnamed, matching `VectorN([1, 2, 3])`'s
unnamed init. The named-component pattern (`Vector2D(x: 1, y: 2)`) doesn't
generalize meaningfully to 1D because there's no spatial axis distinction.

**Field naming:** `.value` — neutral, descriptive, no spatial baggage.

**Side benefit:** the existing 1D optimizers in BusinessMath could (in a
future refactor) be unified with N-D optimizers under a common
`VectorSpace`-based protocol. `Vector1D` is the missing piece that lets that
unification happen without special-casing.

### 3.3 Concrete 1D types

```swift
public struct CubicSplineInterpolator<T: Real & Sendable & Codable>: Interpolator {
    public typealias Point = Vector1D<T>
    public typealias Value = T

    public enum BoundaryCondition: Sendable {
        case natural                          // f''(x_first) = f''(x_last) = 0
        case notAKnot                         // f'''(x[1]) and f'''(x[n-2]) continuous
        case clamped(left: T, right: T)       // f'(x_first) and f'(x_last) specified
        case periodic                         // f, f', f'' match at endpoints
    }

    public let inputDimension = 1
    public let outputDimension = 1
    public let boundary: BoundaryCondition

    private let xs: [T]
    private let ys: [T]
    // Precomputed second derivatives at knots, stored once at init
    private let secondDerivatives: [T]

    public init(xs: [T], ys: [T], boundary: BoundaryCondition = .natural) throws

    // Protocol requirement
    public func callAsFunction(at query: Vector1D<T>) -> T

    // Scalar convenience for ergonomic call sites
    public func callAsFunction(_ t: T) -> T
}
```

Each of the 10 scalar methods follows this shape: a struct with method-specific
init parameters, the `Point = Vector1D<T>` and `Value = T` associated types,
the protocol-required `callAsFunction(at: Vector1D<T>)`, and a scalar
convenience overload `callAsFunction(_ t: T)`.

### 3.4 Concrete 1D vector-output types

```swift
public struct VectorCubicSplineInterpolator<T: Real & Sendable & Codable>: Interpolator {
    public typealias Point = Vector1D<T>
    public typealias Value = VectorN<T>

    public let inputDimension = 1
    public let outputDimension: Int  // set from ys at construction

    public init(xs: [T], ys: [VectorN<T>], boundary: CubicSplineInterpolator<T>.BoundaryCondition = .natural) throws

    public func callAsFunction(at query: Vector1D<T>) -> VectorN<T>
    public func callAsFunction(_ t: T) -> VectorN<T>
}
```

Vector-output types reuse the boundary condition enum from their scalar
counterpart. Implementation runs the scalar coefficient computation once per
output channel (same algorithm, different ys slice). For very large channel
counts this could be parallelized later, but for the typical 3-axis sensor
case it's already fast enough.

### 3.5 Extrapolation policy

```swift
public enum ExtrapolationPolicy<T: Real & Sendable>: Sendable {
    /// Queries outside [xs.first, xs.last] return the boundary value.
    case clamp
    /// Queries outside the range use the boundary polynomial / linear
    /// extension. Behavior is method-specific.
    case extrapolate
    /// Queries outside the range return the supplied fallback value.
    case constant(T)
}
```

Default is `.clamp`. The policy is a parameter on each interpolator's `init`,
defaulting to `.clamp`. We don't include `.error` because that requires the
evaluation method to throw, which complicates `callAsFunction` and breaks
generic dispatch via `any Interpolator`.

### 3.6 Error model

Initializers throw on bad inputs:

```swift
public enum InterpolationError: Error, Sendable, Equatable {
    case insufficientPoints(required: Int, got: Int)
    case unsortedInputs
    case duplicateXValues(at: Int)
    case mismatchedSizes(xsCount: Int, ysCount: Int)
    case invalidParameter(message: String)
}
```

All validation happens at construction time. Evaluation (`callAsFunction`)
never throws. This is consistent with how compile-time-checked numerical
contracts should work: validate eagerly, then trust.

---

## 4. Test Strategy

Each interpolation method gets its own test suite covering:

1. **Pass-through invariant.** Calling `interp(xs[i])` for each input point
   must return `ys[i]` (or close to it for methods that don't strictly pass
   through, like B-spline at endpoints — documented).
2. **Known analytic values.** For each method, a small fixed-coefficient
   fixture with hand-computed expected values at non-knot points.
3. **Smoothness invariants.** For C¹ methods (cubic spline, PCHIP, Akima,
   Catmull-Rom, B-spline), first derivatives should be continuous to within
   tolerance via finite-difference checks at knot points.
4. **Monotonicity.** PCHIP and Akima specifically: monotonic input data must
   produce monotonic interpolated output. (Natural cubic spline does NOT
   guarantee this — that's a documented difference.)
5. **Edge cases.** Single point, two points (linear-only methods), exact knot
   queries, queries at extrapolation boundaries, queries outside the domain
   (extrapolation policy).
6. **Cross-method equivalence on linear data.** A linear input dataset
   `ys[i] = a + b*xs[i]` should produce identical results from every method
   (modulo floating-point noise). This is a strong cross-method sanity check.
7. **Vector-output equivalence.** A vector-valued interpolator with `[T]`
   input wrapped per-channel must produce results that match running each
   channel through the scalar interpolator independently.
8. **Validation playground.** Standalone hand-rolled implementations of each
   method in `Tests/Validation/Interpolation_Playground.swift`, runnable
   without BusinessMath, producing the exact values used in the test suite
   assertions. Same pattern as `Tests/Validation/PSD_Validation.swift`.

### Reference truth

For natural cubic spline specifically: there's a closed-form solution for
quadratic data (`y = a + bx + cx²`) — the spline coefficients can be derived
analytically and serve as ground truth. Same for linear data with linear
interpolation, etc. Where closed forms exist, use them. Where they don't,
hand-compute small fixtures and document the derivation in the playground.

---

## 5. Constraints & Compliance

- **No breaking changes.** Pure additive release. No existing public API changes.
- **Generics over Real.** All methods generic over `T: Real & Sendable & Codable`,
  matching BusinessMath conventions.
- **Concurrency.** All types are `Sendable` value types. No actors, no shared
  mutable state. Each interpolator instance is fully self-contained after
  construction.
- **No forbidden patterns.** No force unwraps, no `try!`, no `precondition`,
  no `fatalError`. All validation at init time via thrown errors.
- **Determinism.** Pure functions of input data and method parameters. Same
  input → same output, exactly.
- **Performance.** Coefficient precomputation at init (`O(N)` for cubic methods).
  Evaluation is `O(log N)` via binary search for knot lookup, `O(1)` after.

---

## 6. Files Changed

| File | Action |
|---|---|
| `Sources/BusinessMath/Optimization/Vector/Vector1D.swift` | new |
| `Sources/BusinessMath/Interpolation/Interpolator.swift` | new — protocol + ExtrapolationPolicy + InterpolationError |
| `Sources/BusinessMath/Interpolation/NearestNeighbor.swift` | new |
| `Sources/BusinessMath/Interpolation/PreviousValue.swift` | new |
| `Sources/BusinessMath/Interpolation/NextValue.swift` | new |
| `Sources/BusinessMath/Interpolation/Linear.swift` | new |
| `Sources/BusinessMath/Interpolation/CubicSpline.swift` | new |
| `Sources/BusinessMath/Interpolation/PCHIP.swift` | new |
| `Sources/BusinessMath/Interpolation/Akima.swift` | new |
| `Sources/BusinessMath/Interpolation/CatmullRom.swift` | new |
| `Sources/BusinessMath/Interpolation/BSpline.swift` | new |
| `Sources/BusinessMath/Interpolation/BarycentricLagrange.swift` | new |
| `Sources/BusinessMath/Interpolation/Vector*Interpolator.swift` × 10 | new — vector-output flavors |
| `Tests/BusinessMathTests/InterpolationTests/` | new test folder, one file per method |
| `Tests/Validation/Interpolation_Playground.swift` | new validation playground |
| `CHANGELOG.md` | new v2.1.2 entry |

### Folder structure

```
Sources/BusinessMath/Interpolation/
├── Interpolator.swift              ← protocol + ExtrapolationPolicy + InterpolationError
├── NearestNeighbor.swift
├── PreviousValue.swift
├── NextValue.swift
├── Linear.swift
├── CubicSpline.swift               ← scalar-output, with BoundaryCondition enum
├── PCHIP.swift
├── Akima.swift
├── CatmullRom.swift
├── BSpline.swift
├── BarycentricLagrange.swift
└── VectorOutput/                   ← vector-output flavors live here for clarity
    ├── VectorNearestNeighbor.swift
    ├── VectorPreviousValue.swift
    ├── VectorNextValue.swift
    ├── VectorLinear.swift
    ├── VectorCubicSpline.swift
    ├── VectorPCHIP.swift
    ├── VectorAkima.swift
    ├── VectorCatmullRom.swift
    ├── VectorBSpline.swift
    └── VectorBarycentricLagrange.swift
```

---

## 7. Resolved Decisions (from architecture discussion)

The architecture above is the result of a multi-round design discussion. Key
decisions and rejected alternatives are recorded in the Architecture Decisions
Log (`development-guidelines/rules/10_ARCHITECTURE_DECISIONS.md`):

- **ADR-001:** Add Vector1D to complete the vector type family
- **ADR-002:** Single Interpolator protocol with Point/Value associated types (rejected: 4-protocol hierarchy)
- **ADR-003:** Multi-version roadmap for ND interpolation
- **ADR-004:** Method set and parameter defaults

See the ADR file for full rationale and rejected alternatives.

---

## 8. Workflow / Cross-Repo Coordination

This is upstream BusinessMath work blocking BioFeedbackKit's
`FrequencyDomainMetrics` v2 implementation. Execution sequence:

1. **Playground validation** (this session, in narbis) — add scalar
   `NaturalCubicSpline` to `narbis/project/plans/upcoming/FrequencyDomain-Playground.swift`
   alongside the existing linear implementation. Re-run the 1 Hz HRV
   fixtures. Confirm cubic drops the HF distortion materially (target: < 5%
   error on HF, vs the 33% we measured with linear). If this validation
   fails, we re-examine before committing to upstream work.

2. **Approve this proposal** (BusinessMath UPCOMING/) and the ADRs (BusinessMath core rules).

3. **BusinessMath feature branch** (`feature/interpolation`):
   - Branch off `v2.1.1` (current main)
   - Write standalone `Tests/Validation/Interpolation_Playground.swift` first, validate every method against analytic ground truth
   - RED → GREEN → REFACTOR per method
   - VERIFY: full BusinessMath test suite green, zero warnings
   - PR, CI, merge, tag `v2.1.2`, GitHub Release

4. **narbis update** — bump `BioFeedbackKit/Package.swift` from `2.1.1` to `2.1.2`. Update the FrequencyDomainMetrics proposal to use BusinessMath's `CubicSplineInterpolator` as the default `InterpolationStrategy`-equivalent (or potentially remove the BioFeedbackKit-local `InterpolationStrategy` protocol entirely and use BusinessMath's directly).

5. **Resume FrequencyDomainMetrics implementation** — playground, RED, GREEN, VERIFY.

---

## 9. Approval Checklist

- [x] Method set (10 methods, 4 cubic spline boundary conditions, vector-output flavors for all 10) — **APPROVED**
- [x] Vector1D addition with `Vector1D(2.5)` init and `.value` field — **APPROVED**
- [x] Single `Interpolator` protocol with `Point: VectorSpace` and `Value: Sendable` — **APPROVED**
- [x] Defaults: makima `true`, Catmull-Rom tension `0.5`, B-spline max degree `5`, extrapolation `.clamp` — **APPROVED**
- [x] Multi-version roadmap (1D in v2.1.2, 2D in v2.2, ND in v2.3+, scattered in v2.4) — **APPROVED**
- [x] Playground empirical validation (cubic spline drops HF error meaningfully) — **PASSED 2026-04-07**: cubic spline reduced HF error from 33% to 2.85%, LF from 6% to 0.05%, VLF from 0.06% to 0.001% on the BioFeedbackKit FrequencyDomainMetrics fixtures. Architecture decision empirically justified.

**Last Updated:** 2026-04-07

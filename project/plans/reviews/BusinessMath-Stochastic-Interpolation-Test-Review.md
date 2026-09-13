# BusinessMath stochastic, interpolation, and financial reference tests

*September 2026. Covers 20 files across three areas: interpolation (InterpolationReferenceTests, CubicSplineTests, HermiteInterpolatorsTests, PolynomialInterpolatorsTests, SimpleInterpolatorsTests, VectorInterpolatorsTests), stochastic processes (StochasticProcessTests, GeometricBrownianMotionTests, ArithmeticBrownianMotionTests, OrnsteinUhlenbeckTests, HullWhiteProcessTests, HestonProcessTests, JumpDiffusionTests, ProcessStateTests, MeasureTagTests, StochasticTestHelpers), time-series models (ARMAFamilyTests, AutoregressiveAndGarchTests, AsymmetricGarchTests), and FinancialReferenceValidationTests. Companion to the nineteen preceding domain reviews.*

*All reference values recomputed in Python; the κ table checked with mpmath at 40 digits.*

## 1. Summary

**`InterpolationReferenceTests` and `AsymmetricGarchTests` are the two strongest files in this batch**, and they use different oracle strategies that the corpus's earlier reviews identified as the two right ones.

The interpolation file uses an external fixture *plus* two properties that need no fixture, and its header states the reason the existing 76 tests were insufficient better than my own reviews have:

> "Every interpolation scheme ever written satisfies all of that — passing through the knots is what makes something an interpolator rather than a fit."

The distinguishing choices it then enumerates — which spline boundary condition, which Akima variant, PCHIP's slope rule — are exactly the convention questions this review series has found unpinned in a dozen other places. And its two fixture-free properties are the strongest assertions in the file:

- **Polynomial reproduction.** A not-a-knot spline must reproduce a cubic exactly *everywhere*, and a natural spline must not, because f″ = 0 at the ends is false for that cubic. Asserting the failure is what proves the two boundary conditions are distinct implementations "rather than one wearing two names."
- **PCHIP does not overshoot**, and the same data through a spline *must* overshoot — "if it did not, the two would be the same code and the property above would be vacuous."

That pairing — assert the property, then assert that a sibling implementation violates it — is a technique I have not seen elsewhere in the corpus, and it is what makes a shape-preservation test non-vacuous.

**`AsymmetricGarchTests` uses nesting as its oracle**, and the header distinguishes it from self-consistency precisely: APARCH with γ = 0, δ = 2 *is* GARCH(1,1), "so the two recursions must agree step for step on the same draws… Nothing about that test can pass by agreeing with itself, because the two implementations share no code." The quadrature has an independent anchor of the same kind: κ at (γ=0, δ=2) is E[z²] = 1 and at (γ=0, δ=1) is √(2/π).

I verified the κ table at 40 digits against the closed form 2^(δ/2)/√π · Γ((δ+1)/2) · ((1−γ)^δ + (1+γ)^δ)/2. All five values are correct to machine precision. (My first attempt with `scipy.quad` disagreed on one row by 1.6e-11, because adaptive quadrature mishandles the integrand's kink at z = 0 — which is exactly why the file specifies Simpson's rule on 200,000 intervals rather than an adaptive routine.)

**Against that, `ProcessStateTests` and `MeasureTagTests` are almost entirely tautological** (§2 item 1), and `StochasticTestHelpers` reintroduces a generator the corpus has been consolidating away from (§2 item 2).

### Templates to copy

| Kind of test | Copy from |
|---|---|
| Any scheme whose distinguishing behaviour is between its data points | InterpolationReferenceTests |
| A model family where one member nests another | AsymmetricGarchTests |
| A property test made non-vacuous by a sibling's violation | InterpolationReferenceTests (PCHIP vs spline overshoot) |
| Quadrature against a known closed form | AsymmetricGarchTests (κ at the GARCH corner) |

## 2. Findings

| # | Issue | Evidence | Recommendation |
|---|---|---|---|
| 1 | **`ProcessStateTests` asserts literals against themselves** | Three of four tests: `let value: Double = 72.50; #expect(abs(value - 72.50) < 1e-6)`; `let scalar: Double.Scalar = value; #expect(abs(scalar - 42.0) < 1e-6)`; `let draw: Double.NormalDraws = 0.5; #expect(abs(draw - 0.5) < 1e-6)`. The comments are right that the associated types are verified "by using it" — the *binding* is the test, and it is a compile-time one. The runtime assertion adds nothing. `MeasureTagTests`' two "is Sendable" tests have the same shape: the `let _: any Sendable = value` line is the test, and the assertion that follows duplicates the preceding name test. | Keep the type bindings, delete the assertions, and say in a comment that compilation is the assertion. Only `Double.dimension == 1` tests anything at runtime. A `requireSendable<T: Sendable>(_:)` generic helper would make the Sendable intent explicit, as the scenario review suggests for the unawaited-Task test. |
| 2 | **`StochasticTestHelpers` is a duplicate generator with two contract bugs** | `StochasticTestRNG` uses multiplier 6364136223846793005 with increment 1 — the same recurrence as `MMIXSeededRNG` already in TestSupport. Its doc says "Generate next uniform in (0, 1)" but `Double(state) / Double(UInt64.max)` returns exactly 1.0 when state is `UInt64.max` and exactly 0.0 when state is 0, so the interval is closed. `nextNormal` guards u₁ with `max(u1, 1e-15)` — which BoxMullerPoleGuardTests calls "the wrong shape" — and does not guard u₁ = 1.0, where log(1) = 0 collapses the draw to zero. | Delete the file; use `DeterministicRNG` and the TestSupport Box-Muller. This is the Nth inline Box-Muller copy in the corpus and the first one found in a *shared* test helper, so it is seeding several files at once. |
| 3 | **`FinancialReferenceValidationTests` overlaps three other files and is looser than all of them** | It re-tests NPV, `npvExcel`, IRR, `payment` and bond duration — all covered in NPVTests, IRRTests, PaymentTests and BondPricingTests. Its own values: NPV is exactly 130.72877535687428 (asserted `< 0.01` against a recomputed expression); `npvExcel` is 118.8443412335221; IRR is 0.16340560068898935 (asserted ±0.01 of 0.1634); PMT is 1073.6432460242797 (asserted ±0.01 of 1073.64, which passes with 0.0032 to spare). | The file's stated purpose — "validates against published reference values" — is what the other files should be doing, so consolidate rather than duplicating. Two things here are worth keeping: `irrSimpleDoubling` ([−100, 200] → exactly 1.0) is a clean exact case, and `loanPaymentZeroInterest` (PV/n = 1000 exactly) pins the r = 0 branch the payment review found untested. |
| 4 | **NPV's expected value is recomputed in the test** | `let expected = -1000.0 + 300.0 / 1.1 + 420.0 / 1.21 + 680.0 / 1.331` — that is the implementation's own formula, written out. If `npv` discounted from the wrong period the test would need to change, but if it accumulated in a different order or used `pow` differently, both sides move together. | Use the literal 130.72877535687428. The self-recomputation rule applies: the expected operand should not be the actual operand's formula. |
| 5 | **`bondDurationCouponRelationship` asserts only an ordering, and uses `Calendar.current`** | Low-coupon duration exceeds high-coupon, which holds for any correct duration formula. The exact values are 8.9503249474 (2% coupon) and 7.3927789542 (8%), at 5% yield over 10 years semi-annual. The date construction also uses `Calendar.current` with `?? Date()` — a silent fallback to *today* if the components fail, which would make the bond zero-length. | Pin both durations. Replace `?? Date()` with `try #require`, and use the shared fixed calendar per the time-series and valuation reviews. |
| 6 | **The GBM golden path is a 4-significant-digit reference** | `#expect(abs(result - 75.28) < 0.01)` where the exact value is 75.2814272025. The tolerance is 0.01 and the miss is 0.0014, so it passes with 7× margin — but the reference itself carries only 4 digits, and the comment's intermediate ("exp(0.03764)") is rounded. | Pin 75.2814272025 at 1e-10. Same for the `zeroDW` case, where the test already computes the exact expression — 105.6540614675 — and could assert the literal instead. |
| 7 | **The κ table's comment describes a case the table lacks** | The comment justifies the spread "including a δ below one, where the integrand's derivatives blow up at the origin." The table's minimum δ is 1.0. | Add a δ < 1 row — δ = 0.5 with γ = 0.3, say. It is the case the comment says matters, and the kink at the origin is what makes it hard. |

## 3. What the strong files establish

### 3.1 Assert the property, then assert a sibling violates it

The two instances in `InterpolationReferenceTests` are worth stating as a general technique:

```
notAKnotReproducesCubics:
  not-a-knot reproduces the cubic exactly     (the property)
  natural does NOT                            (proof the two are distinct code)

pchipPreservesShape:
  PCHIP stays monotone and in-range           (the property)
  a natural spline overshoots the same data   (proof the property isn't free)
```

Without the second half, each first half could be satisfied by an implementation where both schemes are the same code path. This is the interpolation analogue of the LP certificate file's insistence that its oracle share no code with the subject, and of `AsymmetricGarchTests`' observation that its two recursions "share no code."

It generalises to several gaps found earlier in this review series:

- **The island topology tests** (heuristics review): ring must differ from fully-connected, and the current tests assert only that each converges.
- **The two CVaR entry points** (risk review): `theTwoCVaREntryPointsAgree` is the positive half; the file also measures the disagreement, which is the same pairing.
- **`thirty360` vs `siaThirty360`** (valuation batch 2): `variantsAgreeAwayFromFebruary` already closes with "they must differ where February *is* involved, or the pairing is a distinction without a difference."

Three independent files reached this pattern. It should be in the gate's positive-pattern list.

### 3.2 The fixture well-formedness test

`fixtureIsWellFormed` asserts four things about the corpus rather than the code:

1. The reference is SciPy (guards against a fixture regenerated from the package itself).
2. At least 7 datasets.
3. **Off-knot samples outnumber knots**, per dataset — "knots alone would make every scheme agree, which is the trap this whole file exists to avoid."
4. Both Akima variants are present in at least 4 datasets, **and differ somewhere** — "otherwise comparing against either would pass."

Item 3 is the one no other fixture file in the corpus has, and it is the structural guarantee that the fixture can discriminate. Item 4 is the same non-vacuity argument as §3.1.

The `compare` helper returning a count, with each caller asserting `compared >= N`, is the pattern the other reference files use, and here the thresholds (190, 150, 100) are high enough that a fixture that lost a dataset would fail.

### 3.3 Tolerances reasoned per scheme

`compare` takes the tolerance per call, with the reason stated:

- Linear at **1e-12** — one multiply and one add.
- Piecewise cubics at **1e-10** — "the tridiagonal solve behind a spline is well conditioned on these grids."
- Barycentric at **1e-8**, restricted to `xs.count <= 8` — "a single global polynomial through eight points is far worse conditioned than a piecewise cubic, and the loss grows with the spread of the knots… `unevenSpacing` spans three orders of magnitude."

That is three different bounds from three different arguments, in one file. Contrast the suite-level `let tolerance: Double = 0.01` that the financial files use.

## 4. The older generation

**Interpolation (four files, 76 tests).** The reference file's header characterises these accurately: knot interpolation, betweenness, out-of-bounds policy. What they uniquely cover and should keep:

- **Out-of-bounds policies** — clamp, constant, throw. `SimpleInterpolatorsTests` covers all three with exact values.
- **Error cases** — four `InterpolationError` sites, though all by type only.
- **Dimension metadata** — `inputDimension`, `outputDimension`.
- **`VectorInterpolatorsTests`** — the vector-valued path, which the reference fixture does not cover.

`SimpleInterpolatorsTests`' nearest-neighbour tie-breaking at `interp(2.5)` returning 4.0 is worth noting as a pinned convention: the midpoint between knots at 2 and 3 rounds down. That is a real choice and the test fixes it.

**Stochastic processes (seven files).** Mostly one-step golden paths plus edge cases, which is the right shape for a `step` function — the state transition is deterministic given the draw. The good cases:

- `zeroDriftZeroVol`, `zeroDt`, `zeroStartingValue` for GBM — all exact, all pinning a degenerate branch.
- `zeroDW` — the drift-only step, with the expression computed in the test (better as a literal, §2 item 6).
- The parameterised positivity test over draws from −3 to 3.

What is missing across the family:

- **Multi-step distribution.** A GBM path's log-returns are i.i.d. normal with known mean and variance; nothing checks the path, only single steps.
- **Heston's Feller condition** (2κθ ≥ σ²) and what happens when variance would go negative — the reflection-versus-truncation choice, which is a convention like the ones §1 lists.
- **Jump diffusion's compensator.** Whether the drift is adjusted for the jump intensity determines whether the process is a martingale under the risk-neutral measure — and `MeasureTag` exists to distinguish measures, so the two should be connected.
- **Hull-White's mean reversion to a time-dependent θ(t)**, which is the whole point of Hull-White over Vasicek.
- **`MeasureTag` is never used in a test that depends on the measure.** Two name assertions and two Sendable checks; nothing asserts that a risk-neutral GBM drifts at r while a physical one drifts at μ.

**ARMA and GARCH.** `ARMAFamilyTests` is stronger than the stochastic files: it checks that the family type reproduces the dedicated AR(1) exactly (1e-12), that MA(q) autocorrelations vanish beyond lag q (exactly 0 via `#require`), that sampled autocorrelations match analytic ones within 0.02–0.03, and that the stationarity region is correct on both sides with six cases. The 0.02–0.03 sampling bounds are the only loose ones and are plausible for the sample size.

## 5. Recommended order of work

1. **Delete `StochasticTestHelpers`** and route the stochastic files through `DeterministicRNG` (§2 item 2). It is a shared helper, so it affects several files, and it carries the clamped-Box-Muller shape the corpus has been removing.
2. **Consolidate `FinancialReferenceValidationTests`** into the four files it duplicates, keeping the two exact cases it adds (§2 item 3).
3. **Strip the tautologies** from `ProcessStateTests` and `MeasureTagTests`, keeping the compile-time bindings (§2 item 1).
4. **Pin the GBM golden path and the bond durations** to full precision (§2 items 5–6).
5. **Connect `MeasureTag` to a measure-dependent assertion** (§4) — it is currently a type with a name and no tested consequence.
6. **Add a δ < 1 row to the κ table** (§2 item 7).
7. **Add the multi-step distribution tests** and the Heston/jump-diffusion convention pins (§4).
8. **Assert specific interpolation errors** rather than the type.

## 6. Gate rules

One addition to the positive-pattern list, and it is the most transferable finding in this batch:

**Paired property/violation tests.** Where a suite asserts that implementation A has property P, and A is one of several schemes sharing an interface, the suite should also assert that some sibling B *lacks* P. Otherwise the property test passes when A and B are the same code path. Three files reached this independently — interpolation (not-a-knot vs natural, PCHIP vs spline), 30/360 variants (Excel vs SIA), and CVaR (two entry points) — so it is worth naming in the fixture-coverage report rather than leaving it to be rediscovered.

**A fixture-discrimination requirement**, extending the fixture well-formedness rule: a fixture whose query points coincide with its knots cannot separate schemes. The interpolation file asserts off-knot samples outnumber knots; the general form is that a fixture test should assert the corpus exercises the dimension along which implementations differ.

Existing rules that apply: self-recomputation (§2 item 4), silent fallbacks (`?? Date()` in §2 item 5), ambient calendar (§2 item 5), duplicated generator bodies (§2 item 2), tautological assertions (§2 item 1), and error-by-type-only (four interpolation sites).

## Appendix. Verified values

### A.1 APARCH κ = E(|z| − γz)^δ

Closed form: 2^(δ/2)/√π · Γ((δ+1)/2) · ((1−γ)^δ + (1+γ)^δ)/2. All five fixture rows confirmed at 40 digits.

| γ | δ | κ |
|---|---|---|
| 0.0 | 2.0 | 1.0 (= E[z²]) |
| 0.0 | 1.0 | 0.797884560802865356 (= √(2/π)) |
| 0.3 | 1.5 | 0.889234075312848822 |
| −0.5 | 2.5 | 1.80825065323320549 |
| 0.25 | 3.0 | 1.89497583190680522 |

The integrand has a kink at z = 0; adaptive quadrature that does not split there is wrong by ~1e-11 on the δ = 2.5 row.

### A.2 Stochastic processes

| Quantity | Value |
|---|---|
| GBM step: S₀ = 72.50, μ = 0.05, σ = 0.25, dt = 1/12, dW = 0.5 | **75.2814272025** (test: 75.28 ± 0.01) |
| GBM drift term (μ − σ²/2)·dt | 0.0015625 exactly |
| GBM diffusion term σ√dt·dW | 0.0360843918 |
| GBM with dW = 0: 100·exp(0.10 − 0.045) | **105.6540614675** |
| GBM with σ = 0, μ = 0 | 100.0 exactly |
| GBM from 0 | 0.0 exactly |

### A.3 Financial references

| Quantity | Value |
|---|---|
| `npv(0.10, [-1000, 300, 420, 680])` | **130.72877535687428** |
| `npvExcel(0.10, same flows)` | **118.8443412335221** |
| `irr([-1000, 300, 420, 680])` | **0.16340560068898935** |
| `irr([-100, 200])` | 1.0 exactly |
| `payment(200000, 5%/12, 360)` | **1073.6432460242797** |
| `payment(12000, 0, 12)` | 1000.0 exactly |
| Macaulay duration, 2% coupon, 10y, 5% yield, semi-annual | **8.9503249474** |
| Same, 8% coupon | **7.3927789542** |

### A.4 Interpolation properties

| Property | Claim |
|---|---|
| Every scheme on y = 3 + 2x | exact at every query point, not just knots |
| Not-a-knot spline on 2x³ − 5x² + 3x − 1 | exact everywhere |
| Natural spline on the same cubic | must depart (f″ = 0 is false at the ends) |
| PCHIP on monotone data | monotone, within [min y, max y] |
| Natural spline on the same data | must overshoot |
| Nearest-neighbour at the midpoint of knots 2 and 3 | returns the lower knot's value (4.0) |

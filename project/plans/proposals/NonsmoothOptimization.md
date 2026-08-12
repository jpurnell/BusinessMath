# Design Proposal: A Solver Path for Non-Differentiable Objectives

**Status:** Proposed — awaiting approval
**Author:** Session of 2026-08-12
**Target:** `Sources/BusinessMath/Optimization/`

**Relationship to [RobustScenarioGeneration](RobustScenarioGeneration.md):** these two
proposals want the same engine. See §3.

---

## 1. Objective

**Objective:** Solve objectives that are convex (or concave) but not differentiable —
piecewise-linear business models — instead of reporting non-convergence on them.

---

## 2. Motivation

Four non-differentiable objectives surfaced in a single session. Three were fixable by
reformulation *because the library built them*:

| Site | Non-smooth term | Resolution |
|---|---|---|
| `RobustOptimizer` | pointwise `max` over scenarios | epigraph lift |
| `DriverOptimization` | `abs`, `max(0, ·)` penalties | epigraph lift |
| `MultiPeriodConstraint.turnoverLimit` | L1 norm | sign-vector half-spaces |

The fourth cannot be. `productionPlanningWithUncertainDemand` hands the optimizer a
closure the *caller* wrote:

```swift
let quantity = max(0, production.toArray()[0])
let unitsSold = min(quantity, demand)
let shortage  = max(0, demand - quantity)
let excess    = max(0, quantity - demand)
return revenue - productionCost - shortageCost - excessInventoryCost
```

This is the newsvendor model — the standard formulation of the standard problem, not an
unusual thing for a user to write. With `p = 25`, `c = 10`, shortage `5`, excess `2` and
demand ~ N(100, 20), the closed-form optimum is the critical-ratio quantile:

```
Cu = (25 − 10) + 5 = 20        Co = 10 + 2 = 12
Cu / (Cu + Co) = 0.625         q* = 100 + 20·z(0.625) = 106.4
```

**The optimizer starts at 110 — four units away — and returns −1.16e-05.** It travels 106
units in the wrong direction and stops.

Two mechanisms compound. The objective is piecewise linear with its kink at
`quantity = demand`, and a gradient method's step does not shrink approaching a kink
optimum, so it oscillates across and overshoots. And the objective **clamps its own
input** with `max(0, production)`, so below zero the function is flat, the gradient is
exactly zero, and nothing points back.

The current result is *honest* — `converged: false` is accurate — but a library that
cannot solve the newsvendor problem is missing a capability its users will reach for.

**Workaround today.** Rewrite the model to be smooth, which for the newsvendor means
substituting an analytic expectation the user came to this library to avoid deriving.

---

## 3. Proposed Architecture

**The central claim: this proposal and `RobustScenarioGeneration` want one engine.**

Cutting-plane scenario generation builds a piecewise-linear *lower model* of a worst-case
function from evaluations at successive iterates, solves an LP master, and adds a cut.
Nonsmooth optimization of a convex objective builds a piecewise-linear *lower model* from
subgradients at successive iterates, solves an LP master, and adds a cut. These are the
same algorithm with different sources for the cut.

Building them separately would produce two LP-master loops with two convergence tests and
two round budgets. Building the master once, with a pluggable cut source, produces one.

**New Files:**
- `Sources/BusinessMath/Optimization/Nonsmooth/CuttingPlaneMaster.swift` — the shared LP
  master, its proximal term, and the convergence test
- `Sources/BusinessMath/Optimization/Nonsmooth/SubgradientOracle.swift` — cut sources
- `Sources/BusinessMath/Optimization/Nonsmooth/SmoothnessProbe.swift` — detection

**Modified Files:**
- `Optimization/Algorithms/InequalityOptimizer.swift` — route to the nonsmooth path when
  the probe fires, rather than burning the iteration budget
- `AdvancedOptimization/RobustOptimizer.swift` — consume the shared master

---

## 4. API Surface

```swift
/// Supplies a linearisation of `f` at a point: a value and a (sub)gradient.
public protocol CutOracle: Sendable {
    associatedtype Point: VectorSpace where Point.Scalar == Double
    func cut(at point: Point) throws -> (value: Double, slope: Point)
}

/// The shared piecewise-linear master problem.
public struct CuttingPlaneMaster<V: VectorSpace> where V.Scalar == Double {
    public init(maxRounds: Int = 100, tolerance: Double = 1e-6, proximalWeight: Double = 1.0)
    public func minimize(oracle: some CutOracle, from start: V, subjectTo: [MultivariateConstraint<V>])
        throws -> ConstrainedOptimizationResult<V>
}

/// Reports whether a function is differentiable at a point, and how confidently.
public struct SmoothnessProbe<V: VectorSpace> where V.Scalar == Double {
    public func isSmooth(_ f: @Sendable (V) -> Double, at point: V) -> Bool
}
```

**Detection.** Compare central-difference gradients at shrinking steps `h, h/4, h/16`. On a
differentiable function they agree to the truncation order. At a kink they do not converge
— the estimate depends on how far the stencil straddles the corner. That is the same
signal that produced the `3.5357779e-06` floor documented in the augmented-Lagrangian
work, so the phenomenon is already measured in this codebase.

**Subgradients from a black box.** For an opaque closure a single finite-difference
gradient at a kink is meaningless. The oracle therefore uses **gradient sampling** (Burke,
Lewis & Overton): evaluate gradients at several points drawn in a small ball around the
iterate, where the function is differentiable almost everywhere, and take their convex
hull as a subdifferential estimate. Those draws must come from a seeded generator — see
§6.

---

## 5. MCP Schema

**Tool Description:** Optimize an objective that may be non-differentiable.

```json
{
  "method": "auto",
  "maxRounds": 100,
  "tolerance": 1e-6,
  "proximalWeight": 1.0,
  "samplesPerSubgradient": 8,
  "seed": 42
}
```

**Parameter Types:**
- `method` (string): `"auto"` probes and routes; `"smooth"` or `"nonsmooth"` force a path.
- `maxRounds` (integer): Master iterations. Must be > 0.
- `tolerance` (number): Gap at which the model's lower bound certifies the incumbent.
- `proximalWeight` (number): Stabilisation strength; see §12.
- `samplesPerSubgradient` (integer): Gradient-sampling draws per round.
- `seed` (integer): Fixes those draws.

---

## 6. Constraints & Compliance

**Concurrency:** Oracles are `Sendable`; the master holds cuts locally.
**Determinism:** Gradient sampling draws from a seeded `DeterministicRNG`. This is not
optional — an unseeded sampler makes the returned optimum vary per run, which is precisely
the defect fixed in `UncertaintySet` this session. Non-negotiable in review.
**Generics:** Follows the existing `V: VectorSpace where V.Scalar == Double` convention.
**Safety:** Bounded rounds; no force unwraps; the reported gap is validated finite.
**Fail-silent:** A run that exhausts its rounds returns `converged: false` **and** the
achieved gap, never a bare number.

---

## 7. Source & API Compatibility

**Breaking changes:** None. `method: .auto` preserves current behaviour for smooth models,
which take the existing path unchanged.
**Incremental adoption:** Yes — opt in per call, or rely on the probe.
**Type-checking risk:** New generic types; per the 3-operator rule, master assembly must
use intermediate `let` bindings with explicit annotations.

---

## 8. Backend Abstraction

The master is an LP and goes to `SimplexSolver`, reusing the tolerance lesson from the
robust fast path: coefficients recovered by finite differences are good to ~1e-8, so the
master must not be solved at 1e-10.

---

## 9. Dependencies

**Internal:** `SimplexSolver`, `NumericalDifferentiation`, `LinearityValidation`,
`DeterministicRNG`.
**External:** None beyond swift-numerics.

---

## 10. Test Strategy

**Test Categories:**
- *Golden path, closed form:* the newsvendor above. `q* = 106.4` derived from the critical
  ratio, independent of any solver.
- *Kink at the optimum:* `minimize |x − 3|` from `x = 10`. Optimum exactly at the kink,
  where a smooth method stalls.
- *Flat region:* an objective clamping its own input, reproducing the `max(0, x)` trap.
- *Smooth regression:* a differentiable problem must still take the existing path and
  return bit-identical results.
- *Probe accuracy:* the detector must not fire on smooth functions (false positives push
  work onto a slower path) and must fire on `abs`, `max`, `min`.
- *Determinism:* same seed → identical optimum across runs.
- *Budget exhaustion:* returns `converged: false` with a finite gap.

**Reference Truth:**
- Newsvendor critical ratio — Porteus, *Foundations of Stochastic Inventory Theory* (2002),
  ch. 1. Hand-computable.
- Kelley, "The Cutting-Plane Method for Solving Convex Programs" (1960).
- Kiwiel, "Proximity Control in Bundle Methods" (1990), for the stabilising term.
- Burke, Lewis & Overton, "A Robust Gradient Sampling Algorithm for Nonsmooth, Nonconvex
  Optimization" (2005).

**Validation Trace (REQUIRED):**

| Input | Expected |
|---|---|
| Newsvendor, `p=25 c=10 s=5 e=2`, demand N(100,20), start 110 | `q* = 106.4 ± 0.5`, `converged == true` |
| `minimize |x − 3|` from `x = 10` | `x = 3 ± 1e-4` |
| Smooth quadratic `x² + y²` s.t. `x, y ≥ 0` | unchanged from today, bit-identical |

---

## 11. Architecture Decision Review

**ADR Check:**
- [x] Reviewed `project/decisions/architecture_decisions.md` — empty
- [ ] Supersedes existing ADR? **No**
- [ ] Amends existing ADR? **No**
- [x] New ADR required? **Yes**

**New ADR Draft:**
- Title: One cutting-plane master serves robust and nonsmooth optimization
- Category: architecture
- Key decision: Scenario generation and nonsmooth descent differ only in where cuts come
  from, and share a single LP master rather than each carrying its own loop.

---

## 12. Adversarial Review

**Strongest case for a different approach.**
Skip detection and reformulate at the API level: offer `PiecewiseLinear` builders so users
express `max(0, x)` declaratively and the library lifts it, exactly as it now does for
`turnoverLimit`. That keeps every solve exact and every problem smooth, with no probe, no
sampling, no seeds, no convergence theory. A reviewer would fairly ask why we are building
a numerical method to recover structure the user could have declared.

**Where this design is most likely wrong.**
Two places. First, **plain Kelley cutting-plane is known to be unstable** — its iterates
can jump far from the incumbent, and tail convergence is slow. The proximal term in §4 is
what stops that, and it carries a weight that has to be tuned; a badly chosen
`proximalWeight` makes the method either sluggish or unstable, and this proposal offers no
principled default. Second, and deeper, **gradient sampling assumes we can evaluate
gradients almost everywhere near the iterate.** The newsvendor's clamp violates it: on a
whole half-space the function is exactly flat, so every sampled gradient there is zero and
their convex hull contains only zero. The method would certify a flat region as stationary
— which is *true* of the clamped model but false of the user's intent.

**What an experienced critic would say.**
*"You are adding a convergence theory and a random sampler to rediscover structure the
caller could declare in one line, and on your own motivating example the sampler's
assumption does not hold."*

**Why we are proceeding anyway, and what changed.**
The clamp objection is correct and it changed the plan: **detection must report the flat
region rather than optimise into it.** A probe that finds a zero subdifferential across a
neighbourhood should return a diagnostic naming the flat region, not a converged result —
otherwise this proposal reproduces the fail-silent defect it exists to remove. That is now
an explicit test in §10.

On the declarative alternative: it is better where it applies, and Alternative 1 records it
as complementary rather than rejected. It does not discharge the obligation, because
`optimize` accepts an arbitrary `(V) -> Double` and users will keep writing `max` inside
it. A library whose stated surface accepts any closure should not silently fail on the
standard form of a standard problem.

---

## 13. Alternatives Considered

**Alternative 1: Declarative piecewise-linear model builders.**
- *Advantage:* exact, smooth, no probe or sampler; the `turnoverLimit` precedent works.
- *Disadvantage:* only helps callers who adopt it; does nothing for the closure API.
- *Disposition:* **adopted alongside**, and arguably first — cheaper and exact.

**Alternative 2: Plain subgradient descent.**
- *Advantage:* trivial to implement; no LP master.
- *Disadvantage:* O(1/ε²) convergence, no usable stopping test, step-size schedule is
  problem-specific.
- *Why rejected:* would fail the newsvendor tolerance in any reasonable budget.

**Alternative 3: Smooth the objective automatically** (`max(0,z) → softplus`).
- *Advantage:* reuses the entire existing solver.
- *Disadvantage:* perturbs the answer by an amount the caller never agreed to, and the
  smoothing parameter trades accuracy against conditioning.
- *Why rejected:* changing the user's model without saying so is the failure mode this
  codebase has spent a release removing.

---

## 14. Future Directions

- **Nonconvex support** via gradient sampling's original setting, currently out of scope.
- **Warm-started masters** reusing the previous round's basis.
- **Cut pruning** to bound master growth on long runs.
- **Shared adoption** by `StochasticOptimizer` and `MultiPeriodOptimizer`.

---

## 15. Open Questions

1. **Sequencing against `RobustScenarioGeneration`.** That proposal's dualization step is
   independent, but its cutting-plane step *is* this master. Building the master here and
   having robust consume it avoids writing the loop twice — but inverts the previously
   agreed build order.
2. **A principled default for `proximalWeight`.** Bundle literature offers adaptive
   schemes; is one worth implementing initially, or is a fixed weight with a documented
   tuning note enough for a first release?
3. **What should the flat-region diagnostic be?** A thrown error, or a `converged: false`
   carrying a reason code? The latter matches `optimalityGap`'s treatment in the robust
   proposal, and is probably the consistent choice.
4. **Should the probe run by default?** It costs several extra evaluations per solve on
   every model, including the smooth majority that will never need it.

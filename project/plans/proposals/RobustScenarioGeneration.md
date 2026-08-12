# Design Proposal: Cutting-Plane Scenario Generation for Robust Optimization

**Status:** **Approved 2026-08-12.** Open questions resolved and measured (§15).
**Author:** Session of 2026-08-12
**Target:** `Sources/BusinessMath/AdvancedOptimization/`

**Build order:** dualization fast path first, cutting-plane loop second, default policy
decided by measurement afterwards. See §15.

**Governing rule for this feature:** never silently degrade — the label is the contract.
A worst case that is not proven over the whole uncertainty set must say so.

---

## 1. Objective

**Objective:** Solve the robust counterpart against the *true* worst case over the
uncertainty set, generating scenarios on demand, instead of fixing 100 sampled
scenarios up front.

**Master Plan Reference:** Advanced Optimization — robust and stochastic programming.

---

## 2. Motivation

**Current situation.** `RobustOptimizer.optimize` calls
`uncertaintySet.samplePoints(numberOfSamples: samplesPerIteration)` once, and every
sampled point becomes a permanent epigraph constraint:

```swift
let uncertaintyPoints = uncertaintySet.samplePoints(numberOfSamples: samplesPerIteration)
for omega in uncertaintyPoints {
    augmentedConstraints.append(.inequality { ... f(x, ω) − t ... })
}
```

This has two independent problems, and only one of them has been addressed.

**Problem 1 — the answer can be optimistic (unaddressed).** A sampled maximum is a
*lower bound* on the true worst case. Any realization not sampled may violate the
guarantee the caller believes they bought. The result is reported as
`worstCaseObjective` with no indication that it is a sample statistic rather than a
bound, which is precisely the fail-silent shape the coding rules prohibit: a
plausible number with no signal that it may be wrong.

**Problem 2 — cost (addressed, for linear models only).** Carrying 100 constraints
from the first iteration made `5.14-RobustOptimization`'s quick start take **4,214 s**
(pre-KKT measurement) to **6,987 s** (post-KKT). The linear fast path landed in this
session routes such models to `SimplexSolver` and brought that to **1.04 s** — roughly
6,700× — but it is a *structural* shortcut. It does nothing for a nonlinear objective,
where the sampled epigraph is still handed to the augmented Lagrangian, and it does
nothing for Problem 1 in either case: the LP is still solved against the sampled set.

**Workaround today.** Raise `samplesPerIteration`. This trades cost for confidence at
a poor rate — the coverage of a fixed sample improves as √n while the constraint count
grows as n — and never produces a certificate.

---

## 3. Proposed Architecture

**New Files:**
- `Sources/BusinessMath/AdvancedOptimization/WorstCaseOracle.swift`
- `Sources/BusinessMath/AdvancedOptimization/ScenarioGeneration.swift`

**Modified Files:**
- `Sources/BusinessMath/AdvancedOptimization/RobustOptimizer.swift` — the solve loop
- `Sources/BusinessMath/AdvancedOptimization/UncertaintySet.swift` — oracle conformances
- `RobustResult` — gains `optimalityGap`, `scenariosGenerated`, `isCertified`

**Module placement:** `AdvancedOptimization/`, alongside the existing robust types. No
new module boundary.

**The loop.** A standard Kelley cutting-plane / column-generation structure:

1. Seed the *restricted master problem* with the nominal realization only.
2. Solve the master (existing epigraph machinery; the linear fast path applies).
3. Ask the oracle for the worst realization **at the incumbent decision**.
4. If the oracle's value exceeds the master's `t` by more than `tolerance`, add that
   realization as a new epigraph row and return to 2.
5. Otherwise stop: `t` now bounds the worst case over the *whole* set, not a sample.

Step 5 is the part sampling cannot provide. When the loop exits this way the result
carries a certificate; when it exits on the round budget it carries the gap instead.

---

## 4. API Surface

```swift
/// Finds the realization of the uncertain parameters that is worst for a decision.
public protocol WorstCaseOracle: Sendable {
    associatedtype Decision: VectorSpace where Decision.Scalar == Double

    /// The worst realization for `decision`, and the objective value it produces.
    func worstCase(
        for decision: Decision,
        objective: @Sendable (Decision, [Double]) -> Double,
        minimize: Bool
    ) throws -> (parameters: [Double], value: Double)

    /// Whether `worstCase(for:objective:minimize:)` returns a global optimum over the
    /// uncertainty set. When `false`, a converged solve is *not* certified robust.
    var isExact: Bool { get }
}

/// How the robust counterpart obtains its scenarios.
public enum ScenarioGenerationPolicy: Sendable {
    /// Today's behaviour: sample once, solve once. Retained for source compatibility.
    case fixedSample(count: Int)

    /// Generate scenarios on demand until no violated realization remains.
    case cuttingPlane(maxRounds: Int = 50, tolerance: Double = 1e-6)
}

extension RobustOptimizer {
    public init(
        uncertaintySet: any UncertaintySet,
        scenarioGeneration: ScenarioGenerationPolicy,
        maxIterations: Int = 100,
        tolerance: Double = 1e-6
    )
}

extension RobustResult {
    /// `oracleWorstCase − masterEpigraph`. At or below the policy tolerance the
    /// solution is robust over the entire set, not merely the sampled part.
    public let optimalityGap: Double

    /// Rounds of scenario generation performed.
    public let scenariosGenerated: Int

    /// True only when the loop closed the gap *and* the oracle is exact.
    public let isCertified: Bool
}
```

**Closed-form oracle for the common case.** When the objective is linear in `ω` and the
set is a box, the worst realization is a vertex chosen componentwise — `ωᵢ = nominalᵢ −
deviationᵢ · sign(∂f/∂ωᵢ)` — computable without search. `BoxUncertaintySet` supplies
this oracle with `isExact = true`.

**Fallback oracle.** For a general objective, `SampledWorstCaseOracle` maximises over
sampled realizations and reports `isExact = false`. This is *not* a regression from
today: the same sampling now selects one scenario per round rather than fixing 100, and
— critically — the result is labelled uncertified rather than presented as a bound.

---

## 5. MCP Schema

**Tool Description:** Solve a robust optimization problem with on-demand worst-case
scenario generation.

```json
{
  "uncertaintySet": {
    "type": "box",
    "nominal": [0.10, 0.12, 0.08],
    "deviations": [0.02, 0.03, 0.01]
  },
  "scenarioGeneration": {
    "policy": "cuttingPlane",
    "maxRounds": 50,
    "tolerance": 1e-6
  },
  "minimize": true
}
```

**Parameter Types:**
- `uncertaintySet.type` (string): `"box"` or `"ellipsoidal"`.
- `uncertaintySet.nominal` (array of number): Centre of the set.
- `uncertaintySet.deviations` (array of number): Half-widths. Same length as `nominal`, all ≥ 0.
- `scenarioGeneration.policy` (string): `"cuttingPlane"` or `"fixedSample"`.
- `scenarioGeneration.maxRounds` (integer): Round budget. Must be > 0.
- `scenarioGeneration.tolerance` (number): Gap at which the solution is certified. Must be > 0.

Responses carry `optimalityGap`, `scenariosGenerated` and `isCertified` so a model
consuming this tool can tell a certified answer from a budget-exhausted one.

---

## 6. Constraints & Compliance

**Concurrency:** `WorstCaseOracle` refines `Sendable`; scenarios accumulate in a local
array inside the loop, never shared across tasks.
**Determinism:** The oracle must be deterministic — the closed-form one is by
construction, and the sampled one must draw from a seeded generator so a run is
reproducible. This is a hard requirement: a non-deterministic oracle makes the round
count, and therefore the answer, vary run to run.
**Generics:** Follows the existing `V: VectorSpace where V.Scalar == Double` shape of
`RobustOptimizer` rather than introducing a second convention.
**Safety:** No force unwraps; round budget bounds the loop; the gap is validated finite
before it is reported.
**Fail-silent:** `isCertified` exists specifically so an uncertified answer cannot
masquerade as a bound.

---

## 7. Source & API Compatibility

**Breaking changes:** None required. `ScenarioGenerationPolicy.fixedSample` reproduces
current behaviour, and the existing initializer maps onto it.
**Incremental adoption:** Yes — opt in per call site by passing a policy.
**Type-checking risk:** One new initializer overload on `RobustOptimizer`. Distinct
enough in argument labels (`scenarioGeneration:`) that overload resolution should not
slow; still, per the 3-operator rule, the loop body must avoid compound generic
arithmetic in expressions.
**Open compatibility question:** adding stored properties to `RobustResult` is source-
compatible for construction *within* the package but breaks any external memberwise
initialization. See Open Questions.

---

## 8. Backend Abstraction

Not compute-intensive in the GPU sense. The master problem inherits whatever backend
the existing solvers use — `SimplexSolver` for linear masters, `InequalityOptimizer`
otherwise. The oracle is O(dimension) in the closed-form case.

---

## 9. Dependencies

**Internal:**
- `Optimization/LinearProgramming/SimplexSolver.swift` (master problem, linear case)
- `Optimization/Algorithms/InequalityOptimizer.swift` (master problem, nonlinear case)
- `Optimization/LinearityValidation.swift` (structure detection)
- `AdvancedOptimization/UncertaintySet.swift` (set geometry)

**External:** None beyond swift-numerics.

---

## 10. Test Strategy

**Test Categories:**
- *Golden path (closed form).* `5.14` quick start: `min max_r −w·r` over the box, `w ≥ 0`,
  `Σw = 1`.
- *Certificate.* After convergence, draw 10,000 realizations from the uncertainty set;
  none may beat the reported worst case by more than tolerance. **This is the test the
  current fixed-sample design fails**, and it is the reason for the work.
- *Round count.* Cutting-plane must certify the linear portfolio case in ≤ 5 rounds,
  against 100 fixed scenarios today.
- *Determinism.* Same inputs → identical scenario sequence and identical answer across
  repeated runs.
- *Uncertified path.* A nonlinear objective with the sampled oracle must return
  `isCertified == false` even when the gap closes.
- *Budget exhaustion.* A pathological instance must return `converged: false` with a
  finite reported gap, not throw and not claim success.
- *Regression.* `5.14` Example 2 (quadratic) must reproduce the established baseline.

**Reference Truth:**
- *Linear box counterpart, derived and hand-checkable.* For `w ≥ 0`, `max_r (−w·r)` over
  `r ∈ [nom − dev, nom + dev]` is attained at `r = nom − dev`. With
  `nom = [0.10, 0.12, 0.08]`, `dev = [0.02, 0.03, 0.01]` that is `[0.08, 0.09, 0.07]`;
  maximising the worst case puts all weight on the largest entry.
- *Algorithm.* Kelley, "The Cutting-Plane Method for Solving Convex Programs" (1960).
- *Robust counterpart formulation.* Ben-Tal, El Ghaoui & Nemirovski, *Robust
  Optimization* (2009), §1.2.

**Validation Trace (REQUIRED):**

| Input | Expected output |
|---|---|
| `nominal [0.10, 0.12, 0.08]`, `deviations [0.02, 0.03, 0.01]`, `Σw = 1`, `w ≥ 0`, maximize worst case | `w = [0, 1, 0]`, `worstCaseObjective = −0.09` exactly |
| Same, `optimalityGap` after convergence | `≤ 1e-6`, `isCertified == true` |
| `5.14` Example 2 (quadratic, 4 assets) | `weights ≈ [0.0252, 0.4000, 0.2272, 0.3475]`, `worstCase ≈ −0.08603944` (established baseline, matched to 1e-5) |

The first row is already pinned as an assertion in `ArticleRestorationProbe` and passes
against the linear fast path, so it is a live regression guard rather than a
prospective one.

---

## 11. Architecture Decision Review

**ADR Check:**
- [x] Reviewed `project/decisions/architecture_decisions.md` — currently empty, no
      related decisions to supersede or amend.
- [ ] Supersedes existing ADR? **No**
- [ ] Amends existing ADR? **No**
- [x] New ADR required? **Yes**

**New ADR Draft:**
- Title: Robust optimization reports certified bounds, not sample statistics
- Category: api
- Key decision: A robust result must distinguish a worst case proven over the whole
  uncertainty set from one observed over a sample, and must never present the second as
  though it were the first.

---

## 12. Adversarial Review

**Strongest case for a different approach — dualization.**
For a box uncertainty set and an objective linear in `ω`, the robust counterpart has an
exact closed-form reformulation: `max_r (−w·r) = −w·nom + Σᵢ devᵢ|wᵢ|`, which lifts to a
linear program with `2n` auxiliary variables and no iteration whatsoever. A reviewer
would reasonably ask why we are building an iterative method for a problem with a
one-shot exact answer. That alternative is genuinely better *for the case this session
spent the most time on*: no oracle, no convergence risk, no round budget, exact.

**Where this design is most likely wrong — the oracle assumption.**
The loop's certificate is only as good as the oracle's guarantee. For a general
nonlinear `f`, finding `max_ω f(x, ω)` is itself a global optimization problem, and a
locally optimal oracle produces a *false* certificate: the gap closes, nothing is
violated among the points examined, and the reported bound is still wrong. The design
assumes we can be honest about this via `isExact`, but that only converts a silent
error into a labelled one — it does not make the nonlinear case correct.

A second, smaller assumption: that Kelley's method converges in few rounds. It is known
for slow tail convergence on some problems, and the round budget is what stands between
that and an unbounded solve.

**What an experienced critic would say.**
*"You are replacing a wrong answer computed quickly with a wrong answer computed
iteratively, unless the oracle is a global maximiser — and for nonlinear objectives it
isn't; meanwhile for the linear case you already have an exact reformulation that needs
no loop at all."*

**Why we are proceeding anyway — and what changed in response.**
The criticism is largely correct, and the design changed because of it:
1. `isExact` and `isCertified` were added so an uncertified answer is *labelled*, not
   presented as a bound. This is the minimum honest behaviour and does not exist today.
2. Dualization is adopted as a **complementary** fast path rather than an alternative —
   see Alternative 1. Cutting-plane remains the general fallback because
   `RobustOptimizer`'s public API accepts an arbitrary `(V, [Double]) -> Double`, and a
   design that only serves linear objectives does not discharge that promise.
3. The round budget is surfaced through `optimalityGap` rather than swallowed, so slow
   convergence is visible to the caller instead of appearing as a long pause.

---

## 13. Alternatives Considered

**Alternative 1: Dualization / robust counterpart reformulation.**
- *Advantage:* Exact, single solve, no iteration, no oracle. Strictly better for box
  uncertainty with an objective linear in `ω`.
- *Disadvantage:* Structure-specific. Each (uncertainty set × objective form) pair needs
  its own derivation; it does not extend to an opaque nonlinear closure.
- *Disposition:* **Not rejected — adopted alongside, and sequenced first.** Implemented
  as a recognized-structure fast path, in the same spirit as the linear/simplex path
  landed this session, with cutting-plane as the general case behind it. Sequencing was
  resolved in review: see Resolved Question 2.

**Alternative 2: Keep fixed sampling, raise the count.**
- *Advantage:* No new code.
- *Disadvantage:* Does not address Problem 1 at all — a larger sample is still a sample,
  still a lower bound, still uncertified. Cost grows linearly in constraints.
- *Why rejected:* Buys confidence at a poor rate and never produces a certificate.

**Alternative 3: Nested worst-case search inside every objective evaluation.**
- *Advantage:* Conceptually simple; the worst case is always current.
- *Disadvantage:* This is essentially the pre-epigraph design, measured at 116 minutes
  for a three-variable problem, and it reintroduces the non-smooth `max` that the
  epigraph reformulation was written to remove.
- *Why rejected:* Measured, and worse on both axes.

---

## 14. Future Directions

- **Ellipsoidal and budgeted uncertainty sets** could gain closed-form oracles by the
  same route as the box.
- **Warm-started masters** could reuse the previous round's basis rather than re-solving
  from scratch, which the `SimplexResult` already exposes enough state to attempt.
- **Scenario pruning** might drop rows that have been inactive for many rounds, bounding
  master growth on long runs.
- **Shared oracle infrastructure** could serve `StochasticOptimizer` and
  `MultiPeriodOptimizer`, which face the same sampled-versus-certified distinction.

---

## 15. Resolved Questions

Reviewed 2026-08-12. Decisions recorded here rather than in the body so the reasoning
that produced them survives.

**1. Should `cuttingPlane` be the default? — Yes in principle, deferred on evidence.**
The intent is for it to be the default. The condition attached was "assuming it's
actually fast", and that cannot be asserted yet. Note the interaction with decision 2:
once dualization handles recognized structures exactly, the loop runs *only* on
nonlinear objectives — which is where Kelley's method has its slow tail convergence and
where the oracle is not global. The default would therefore be fast largely where it is
bypassed and slow where it actually runs. **Decision: implement the policy, ship
`fixedSample` as the default, and revisit after measuring the loop on genuinely
nonlinear models.** Changing the default also moves existing callers' returned values —
toward more conservative answers, which is the intent, but it is a change.

**2. Sequencing against dualization. — Dualization lands first.**
It is exact and removes the iteration entirely for the common case, so building the loop
first would spend cycles on a path most models should never take.

*Measured on the 5.14 quick start (`nominal [0.10, 0.12, 0.08]`, `deviations
[0.02, 0.03, 0.01]`, `Σw = 1`, `w ≥ 0`), both formulations solved by `SimplexSolver` at
tolerance 1e-7:*

| Formulation | Rows | Vars | Iters | Elapsed | Result |
|---|---|---|---|---|---|
| Sampled epigraph (ships today) | 104 | 8 | 6 | 0.0111 s | `w = [0, 1, 0]`, obj −0.09 |
| Dual robust counterpart | 7 | 6 | 6 | **0.0002 s** | `w = [0, 1, 0]`, obj −0.09 |

Identical answers; 55× on the solve, from a smaller tableau at the same iteration count.

**The speed argument is weaker than it looks, and the correctness argument is not.** The
LP solve is roughly 1% of that test's 1.04 s — what dominates is the *linearisation*
loop, which calls `validateLinearModel` 104 times (once per sampled scenario plus once
per constraint). Dualization's real win is needing **two** linearisations, one in `w` and
one in `ω`, rather than 104. The tableau is the small half of the saving. Sequencing on
speed alone would be over-claiming; sequencing on exactness would not.

*Where dualization is slower, stated plainly:*
- **Row-count crossover at ≈100 decision variables.** Dual rows scale as `2n + 1`;
  sampled as `samples + 1 + n`. Measured: n=3 → 7 vs 104; n=50 → 101 vs 151;
  **n=100 → 201 vs 201**. Beyond that, with default sampling, dualization is the larger
  program and the sampled form wins on size.
- **Wasted detection.** Dualization additionally requires the objective linear in `ω`;
  probing for that costs evaluations that are discarded on a genuinely nonlinear model.
- **Not a like-for-like comparison.** Sampled is approximate, dual is exact. Wall-clock
  alone flatters sampling, which is answering an easier question.

Consequence to carry forward: with dualization in place, the cutting-plane path is
exercised mainly by nonlinear models, so its tests must be weighted there rather than on
the linear portfolio cases that are easiest to write.

**3. `RobustResult` field additions. — Nothing breaks; question withdrawn.**
Verified against the source rather than assumed. `RobustResult` declares no explicit
initializer, no extensions and no `Codable`/`Sendable` conformance, so its memberwise
initializer is *internal* by Swift's default access rules. External code cannot
construct the type at all today, and the only construction sites are inside
`RobustOptimizer.swift`. Adding stored properties is purely additive outside the
package. The original framing of this risk was wrong.

**4. The sampled oracle's seed. — There is no seed, because there is no RNG.**

No randomness anywhere in the oracle, and no seed parameter on `RobustOptimizer`. The
oracle is two-tier, with an explicit contract:

| Condition | Oracle | Flags |
|---|---|---|
| Box set, objective linear in `ω`, dimension ≤ 10 | Corner enumeration — the worst case provably lies at a vertex | `isExact = true`, result **certified** |
| Anything else | Deterministic low-discrepancy fill | `isExact = false`, `isCertified = false` |

This avoids threading a seed through a type that has none, and avoids creating the
seeded-versus-unseeded API split that has already caused defects elsewhere in this
codebase.

**The governing rule: never silently degrade — the label is the contract.** Tier two
still returns a useful answer and still reproduces exactly run to run, but it cannot
claim to be a bound.

*Adversarial note, retained deliberately:* determinism is not correctness. Corner
enumeration meets the same `2ⁿ` wall as the turnover expansion, and above that bound a
low-discrepancy sequence's coverage guarantee is asymptotic rather than finite-sample.
The result is a *deterministically* wrong bound, which is more dangerous than a randomly
wrong one because it returns the same number every run and is therefore trusted. The
two-tier flag is what answers this: the stable number arrives marked uncertified rather
than being refused or disguised. Determinism buys reproducibility; `isExact` states
whether the answer is a bound. Neither substitutes for the other.

*Why this differs from the turnover expansion decision made the same day,* where an
over-dimension model throws rather than degrades: a constraint has no "uncertified"
state — it holds or it does not — so dropping half-spaces silently relaxes a budget the
caller stated. A worst-case *value* can carry a flag. Same principle, different
mechanism because the type admits one here and not there.

*Adversarial note, retained deliberately:* determinism is not correctness. Corner
enumeration meets the same `2ⁿ` wall as the turnover expansion, and above that bound a
low-discrepancy sequence's coverage guarantee is asymptotic rather than finite-sample.
The result is a *deterministically* wrong bound, which is more dangerous than a randomly
wrong one because it returns the same number every run and is therefore trusted. The two
concerns are kept separate rather than allowed to launder one another: the oracle is
deterministic for reproducibility, and `isExact` states whether the answer is a bound.
Neither substitutes for the other.

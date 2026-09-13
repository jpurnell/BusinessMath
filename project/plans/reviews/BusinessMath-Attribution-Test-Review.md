# BusinessMath attribution tests

*September 2026. Covers 2 files: HeuristicAttributionTests and IncrementalAttributionTests. Companion to the twenty-three preceding domain reviews; continues the marketing batch's conventions.*

*All values independently recomputed: Shapley by brute-force coalition enumeration, the Markov chain by hand, time-decay weights with mpmath.*

## 1. Summary

These two files continue the marketing batch's structure — three named fail-silent shapes per file, an anchor that needs no reference implementation — and add something no other file in the corpus has: **axioms as the oracle**.

Attribution has no ground truth. There is no experiment that reveals what a channel "really" contributed, which is why the field has a dozen models and no way to rank them. What it does have is a set of axioms that any credit allocation must satisfy, and these files test those:

| Axiom | Where | Assertion |
|---|---|---|
| Efficiency | both files, every model | credit sums to the converted value, checked across the whole `AttributionModel` protocol |
| Null player | Shapley | a channel changing no coalition's worth gets **exactly zero** — `#expect(ghost == 0)`, no tolerance |
| Symmetry | Shapley | two channels in identical journeys are paid identically |
| Order invariance | Shapley vs Markov | Shapley ignores sequence; a chain must not, and the test asserts both |

**The null-player test is the only assertion in the corpus that argues for its own exactness from first principles.** The file's header says it: "the Shapley null player axiom is exact rather than approximate: a channel that changes no coalition's worth receives precisely zero, which is the one assertion in attribution that can be made without a tolerance." And the test uses `==` rather than a band, correctly — I confirmed by enumeration that Ghost's Shapley value is 0.0 exactly, because every marginal contribution term is 0 − 0.

I verified every hand-worked value in both files:

| Value | File's claim | Verified |
|---|---|---|
| Shapley on v(A)=1, v(AB)=2 | A 1.5, B 0.5 | exact |
| Coalition worths v(∅), v(A), v(B), v(AB) | 0, 1, 0, 2 | exact |
| Three-channel efficiency | sums to 75 | Search 28.333, Email 38.333, Social 8.333, sum exactly 75 |
| Symmetry fixture | Twin1 = Twin2 | both exactly 7.0, Other 6.0, total 20 |
| Markov P(convert) | 0.5 | 0.5·1·0.5 + 0.5·0.5 = 0.5 |
| Removal effects | Awareness 0.5, Close 1.0 | exact; they sum to 1.5, not 1 |
| Normalised, five conversions | 5/3 and 10/3 | exact |
| Time decay, journey 1 raw weights | 1/8, 1/4, 1/2, 1 over 15/8 | exact |
| Time decay credit | A 6.666666666666667, B 85.71787973316069, C 57.61545360017266 | A and B exact; C differs in the 16th digit, well inside the 1e-9 band |
| Position-based 0.4/0.4 | A 40, B 75, C 35 | exact, including the renormalisation to 0.5/0.5 on the two-touch journey |
| Linear | A 25, B 75, C 50 | exact |

## 2. Techniques worth propagating

### 2.1 `#expect(throws: Never.self)` as the no-throw assertion

Used three times, and it is the cleanest solution to a problem three other files in the corpus solved badly:

```swift
#expect(throws: AttributionError.missingTimings) {
    _ = try HeuristicAttribution.timeDecay(halfLife: 10).attribute(journeys: untimed)
}
// The other rules do not need them.
#expect(throws: Never.self) {
    _ = try HeuristicAttribution.linear.attribute(journeys: untimed)
}
```

`LoggerTests` has 13 `#expect(true) // TEST-QUALITY: validates no-throw execution` markers and `BalanceSheetTests` has one. `Never.self` says the same thing as an assertion rather than a marker, and it reads as the deliberate pair of the throwing case beside it.

The `positionWeightsMustLeaveAMiddle` test uses it best: 0.6/0.6 is refused, −0.1/0.5 is refused, and **0.5/0.5 is explicitly allowed** — "it means no middle credit, not an invalid split." Asserting where the boundary *is not* is what makes the refusal a boundary rather than a blanket.

### 2.2 Absent versus zero, decided and tested both ways

The corpus has raised this question in four places without resolving it — `BalanceSheetUndefinedRatioTests` argues for nil when a denominator is absent, `cashRatioNoCashAccounts` returns 0.0, the ratio suite's service-company test expects nil. Here it is decided per model and tested in both directions:

- **Heuristics**: a channel appearing only in failed journeys is **absent**. "Ghost appears in no converting journey, so a heuristic has nothing to say about it at all — which is different from saying it earned nothing."
- **Shapley**: the same channel is **exactly zero**, and the test requires it to be present: `try #require(credit["Ghost"], "it should be measured, not missing")`.
- **Within heuristics**: a channel in converting journeys that never opens one is zero under first-touch, not absent — "C was touched in both converting journeys and opened neither, so it is measured at zero rather than missing."

Three different answers, each correct for its model, each asserted. That is the resolution pattern for the open question elsewhere: the distinction is *no data* versus *a measurement of zero*, and which applies depends on whether the model can see the case at all.

### 2.3 Cross-model comparison as the finding

`markovRescuesTheOpener` runs the same ten journeys through last-touch and Markov, gets 0 and 5/3, and states why:

> "Both are arithmetic on the same ten journeys. They differ because only one of them looked at the five that failed."

`lastTouchZeroesTheOpener` completes it by showing first-touch "inverts the error rather than fixing it" — the closer now scores zero. Neither model is wrong; both are answering a different question from the one a reader assumes.

`shapleyIgnoresOrderAndMarkovDoesNot` is the same technique applied to a property: Shapley must be order-invariant and a chain must not be, so the test asserts `> 1e-6` difference for Markov alongside `< 1e-12` for Shapley. That is the paired property/violation pattern from the interpolation review, applied to two models rather than two implementations of one.

### 2.4 Error cases with associated values, at scale

Eight distinct pinned cases across the two files — the most in any file in the corpus:

```
AttributionError.missingTimings
AttributionError.invalidHalfLife(0)
AttributionError.noJourneys
AttributionError.noConversions
AttributionError.emptyJourney(index: 0)
AttributionError.mismatchedAges(index: 0)
AttributionError.invalidValue(index: 0)
AttributionError.tooManyChannels(count: 6, limit: 4)
```

The index-carrying cases are the notable ones: for a caller with ten thousand journeys, `emptyJourney(index: 0)` is actionable and a bare `AttributionError` is not. This is the standard the roughly 300 type-only sites elsewhere in the corpus should meet, and `malformedInputIsRefused` demonstrates five of them in one test.

## 3. Findings

| # | Issue | Evidence | Recommendation |
|---|---|---|---|
| 1 | **The `channelLimit` clamp's stated reason does not match the number** | `#expect(ShapleyAttribution(channelLimit: 40).channelLimit == 16)`, with the comment "The limit is clamped to what Double holds factorials for exactly." Factorials are exact in `Double` up to **18!** = 6,402,373,705,728,000, which is below 2⁵³ = 9,007,199,254,740,992; 19! = 1.216e17 is the first that is not. So the exact-factorial bound is 18, not 16. | Either the justification is wrong or the real constraint is different — 2¹⁶ = 65,536 coalitions is a plausible *runtime* bound, which is a different argument. The header already makes the runtime case ("at twenty channels that is a million coalitions and at thirty it does not finish"), so the clamp may be a performance limit wearing a precision explanation. Worth stating which, since a caller choosing between 16 and 18 channels is told the wrong reason for the refusal. |
| 2 | **Two tests fall back to the bare error type** | `positionWeightsMustLeaveAMiddle` uses `AttributionError.self` for both the 0.6/0.6 and the −0.1/0.5 cases, and `reservedNamesAreRefused` uses it for both name collisions. Everywhere else in these two files the specific case is pinned. | The two position cases are different failures — weights summing above one versus a negative weight — and a reader cannot tell from the test which fired. Same for `(conversion)` versus `(removed)`. Both files set the standard; these four sites are the only places they fall below it. |
| 3 | **`uShaped` is tested only through the protocol** | `HeuristicAttributionTests`' model lists cover `.firstTouch`, `.lastTouch`, `.linear`, `.positionBased(first: 0.4, last: 0.4)` and `.timeDecay(halfLife: 10)`. `IncrementalAttributionTests.everyModelIsEfficient` includes `HeuristicAttribution.uShaped`, which appears nowhere in the heuristic file. | If `uShaped` is `positionBased(first: 0.4, last: 0.4)` under another name, assert that equivalence — the delegation check `TemplateDelegationTests` uses. If it has its own weights, it needs its own hand-worked case in the heuristic file, since efficiency alone does not pin a weighting. |

## 4. Coverage gaps

**Heuristics.**
- **Time decay with all touches at the same age.** Every weight is equal, so it should reduce to linear exactly. That is a degenerate-case oracle of the kind `demandAndLeadTimeDegenerates` uses in the operations batch, and it needs no reference.
- **Time decay with a very long half-life** should also approach linear; with a very short one it should approach last-touch. Both limits are checkable and both would catch a sign error in the exponent.
- **Position-based at first + last = 0** — all credit to the middle. The complement of the 0.5/0.5 boundary already tested.
- **A journey with one channel repeated** (A, A, A): linear gives it everything, first and last touch give it everything, and position-based should too. A cheap consistency case.

**Incremental.**
- **Markov with a loop.** A journey like A, B, A creates a cycle in the transition matrix, and the removal-effect computation has to handle it. That is the case where a naive implementation either fails to converge or silently truncates.
- **Shapley's additivity axiom.** Efficiency, symmetry and null player are tested; additivity (the fourth axiom, that φ(v + w) = φ(v) + φ(w)) is the one that pins the *form* of the Shapley value rather than a property of it, and it is checkable by splitting a journey set in two.
- **Markov removal effect at exactly zero.** A channel whose removal changes nothing should score 0 — the Markov analogue of the null player, and currently only the indispensable end (effect 1.0) is tested.
- **Shapley at the channel limit.** `channelLimit: 4` with exactly 4 channels should succeed; the test only covers 6 against a limit of 4. Boundary-inclusive, as the GPU-threshold tests in the heuristics batch do with 999/1000/1200.

**Both.** The two files share a `Journey` fixture shape but not a fixture. The cross-model tests in `IncrementalAttributionTests` build their own; a shared corpus with the hand-worked answers for every model beside it would make the efficiency sweep a table rather than a loop.

## 5. Recommended order of work

1. **Resolve the `channelLimit` justification** (§3 item 1) — the stated reason is checkably wrong, and the refusal message presumably carries it.
2. **Pin the four bare-type error assertions** (§3 item 2), matching the rest of both files.
3. **Cover `uShaped` in the heuristic file** (§3 item 3), or assert its equivalence to `positionBased`.
4. **Add the time-decay limit cases** (§4) — equal ages reducing to linear is the strongest of them and needs no reference.
5. **Add the Markov loop case and the zero-removal-effect case** (§4).
6. **Add Shapley additivity** (§4), which completes the axiom set.
7. **Make the channel limit boundary-inclusive** (§4).

## 6. Gate rules

No violations. Two positive patterns to add to the gate's list:

**`#expect(throws: Never.self)` as the canonical no-throw assertion.** This is statically checkable as a *fix*: the rule already flags `#expect(true)` as vacuous, and `Never.self` is the correct replacement wherever the comment says "validates no-throw execution." Fourteen sites across the corpus (13 in `LoggerTests`, one in `BalanceSheetTests`) would become real assertions by this substitution. Worth naming in the vacuous-assertion rule's message so the fix is obvious rather than requiring judgement.

**Axioms as an oracle for a model with no ground truth.** Where a domain has competing models and no experiment to rank them, the testable content is the axioms every model must satisfy. Attribution is the clearest case, but the pattern applies to the corpus's other convention-laden areas: a percentile definition must be monotone and equivariant whichever type it is, a risk measure must be monotone and translation-invariant whichever quantile convention it uses, and `RiskMetricsReferenceTests` already tests translation invariance and positive homogeneity for exactly this reason. The fixture-coverage report should record, per domain, whether the axioms are tested separately from the values.

## Appendix. Verified values

### A.1 The heuristic fixture

Three journeys: (A, B, C, B) worth 100 at ages 30, 20, 10, 0; (A) not converted; (B, C) worth 50 at ages 7, 0. Total converted value 150.

| Model | A | B | C |
|---|---|---|---|
| First touch | 100 | 50 | 0 |
| Last touch | 0 | 100 | 50 |
| Linear | 25 | 75 | 50 |
| Position 0.4/0.4 | 40 | 75 | 35 |
| Time decay, half-life 10 | 6.666666666666667 | 85.717879733160684 | 57.615453600172650 |

Time-decay working: journey 1's raw weights are 2^(−30/10) = 1/8, 2^(−20/10) = 1/4, 2^(−10/10) = 1/2 and 2⁰ = 1, summing to 15/8 = 1.875 exactly. Journey 3's are 2^(−7/10) = 0.61557221 and 1.

Position-based working: journey 1 gives A 40 (first), B 40 (last) and 20 split between the two middle touches (B and C get 10 each); journey 3 has no middle, so 0.4/0.4 renormalises to 0.5/0.5 and B and C get 25 each.

### A.2 Shapley

Coalition worth v(S) = total value of converting journeys whose channel set is a subset of S.

**Two channels** — journeys A (1) and A,B (1): v(∅) = 0, v(A) = 1, v(B) = 0, v(AB) = 2. φ_A = ½(1−0) + ½(2−0) = **1.5**; φ_B = ½(0−0) + ½(2−1) = **0.5**.

**Three channels** — Search+Email (40), Email (10), Search+Social+Email (25), plus two failed:

| Channel | Shapley value |
|---|---|
| Search | 28.333333333 |
| Email | 38.333333333 |
| Social | 8.333333333 |
| **Total** | **75** exactly |

**Symmetry** — Twin1+Twin2 (10), Twin1+Twin2+Other (6), Other (4): Twin1 = Twin2 = **7.0** exactly, Other = 6.0, total 20.

**Null player** — Ghost appears only in failed journeys: φ_Ghost = **0.0** exactly, A = 1.5, B = 0.5.

### A.3 Markov removal effect

Five journeys (Awareness, Close) converting at value 1; five (Close) failing.

| Quantity | Value |
|---|---|
| P(convert) = 0.5·1·0.5 + 0.5·0.5 | 0.5 |
| Remove Awareness: 0.5·0.5 | 0.25, so effect = (0.5 − 0.25)/0.5 = **0.5** |
| Remove Close | 0 reachable, so effect = **1.0** |
| Sum of effects | **1.5** — not 1, which is the point |
| Normalised shares | 1/3 and 2/3 |
| Credit over five conversions | **5/3** and **10/3** |

### A.4 Factorial exactness in Double

2⁵³ = 9,007,199,254,740,992.

| n | n! | Exact in Double |
|---|---|---|
| 16 | 20,922,789,888,000 | yes |
| 17 | 355,687,428,096,000 | yes |
| 18 | 6,402,373,705,728,000 | yes |
| 19 | 121,645,100,408,832,000 | **no** |

So the precision bound on the Shapley channel limit is 18, not 16 (§3 item 1).

# CURRENT — Risk Solver: items 1 and 3

**Started** 2026-09-06 · **Branch** `main` · **Spec** `project/plans/proposals/PROPOSAL_excel_function_coverage.md` §3 priority 1

Priority 1 of §3: *"`PsiPoisson`, `PsiHyperGeo`, `PsiDiscrete` — samplers only, on mathematics
already here. The cheapest items on the list."* Phase 0 (item 0), the Excel financial ten (item 2)
and the sampling methods (item 5) are done, so this is the next unblocked item.

## What exists, and what each row actually needs

| Row | Maths present | Missing |
|---|---|---|
| `PsiPoisson` | `poisson(_:µ:)` PMF, `poissonCDF(_:µ:)` | a type, a monotone `quantile`, a draw |
| `PsiHyperGeo` | `hypergeometric(total:r:n:x:)` PMF | a type, a CDF, a monotone `quantile`, a draw |
| `PsiDiscrete` | `meanDiscrete`, `varianceDiscrete` | a type, pmf/cdf/quantile, a draw |

None of `DistributionPoisson`, `DistributionHyperGeometric`, `DistributionDiscrete` exists. The
`DiscreteDistribution` protocol supplies `next(using:)` by inverse transform once `quantile` is
there, so "sampler only" in practice means *conform the existing mathematics to the protocol*.

## The parameterisation decision, made before any code

`PsiHyperGeo(n, D, M)` — Frontline's page defines it as

> "a discrete distribution of the number of **successes** in n successive trials drawn without
> replacement from a finite population of size M, when it is known that there are exactly **D
> failures** in the population."

Those two clauses contradict each other: it counts successes, then calls `D` failures.

**Resolved as `D` = number of successes (marked items) in the population.** Three reasons:

1. The work list already set this precedent for `PsiCauchy` and `PsiLaplace` — *"Frontline's own
   prose contradicts its signature; the signature is authoritative."*
2. Standard hypergeometric notation pairs population `M` with `D` for *defectives*, which are the
   category being counted, not the complement.
3. The row's own `REFERENCE` is `scipy.stats.hypergeom`, whose successes-in-population argument is
   the marked category. Binding to a reference and then inverting one of its arguments would make
   every cross-check meaningless.

This is recorded in the type's DocC so a future reader meets the contradiction rather than
rediscovering it. If Frontline's prose is ever shown to be literal, the fix is one substitution
(`D` → `M - D`) at the boundary, and the tests below would all move together.

## Contract each type must satisfy

From `DiscreteDistribution`:
- `pmf(_ k: Int) -> T` — zero outside the support, never a trap.
- `cdf(_ k: Int) -> T` — non-decreasing, in [0, 1], defined for **every** `Int`.
- `quantile(_ p: T) -> Int` — smallest `k` with `cdf(k) >= p`, **monotone non-decreasing in p**.

The monotonicity requirement is not decorative: quasi-random sampling calls `quantile` directly, and
the protocol's own documentation explains that an alias table must never appear there. `AliasTable`
belongs in an overridden `next(using:)` only, where O(1) is free and equidistribution is not at
stake.

## Tasks

- [x] RED — 15 tests across the three types, plus 7 pinning the Poisson mathematics.
- [x] GREEN — `DistributionPoisson`, `DistributionHyperGeometric`, `DistributionDiscrete`.
- [x] `DistributionDiscrete` overrides `next(using:)` with `AliasTable`; `quantile` stays monotone.
- [x] Alias path and inverse transform agree in distribution, checked per outcome at 4 SE.
- [x] DocC on all three, stating the parameterisation and, for HyperGeo, the contradiction.
- [x] Full suite green (6,920), `quality-gate --no-cache` 45/45 0 errors 0 warnings.
- [x] CI green on all four jobs (run 34034552278, commit `8982d241`).

## Item 3 — the closed-form distributions (§3 priority 3)

All seven done, in one batch. §2.2 governs the testing: *"the formula is the reference … no
external tool is needed, and none should be used"*, so these assert round-trip identities,
monotonicity, support edges, and values worked out by hand — not fixtures from another
implementation.

| Row | Type | Note |
|---|---|---|
| `PsiKumaraswamy` | `DistributionKumaraswamy` | Beta-shaped with closed-form CDF and quantile |
| `PsiHypSecant` | `DistributionHypSecant` | **scale is the standard deviation**, see below |
| `PsiDblTriang` | `DistributionDoubleTriangular` | density jumps at the mode; CDF stays continuous |
| `PsiCumul` | `DistributionCumul` | piecewise-linear CDF through elicited points |
| `PsiGeneral` | `DistributionGeneral` | piecewise-linear density; quadratic CDF per segment |
| `PsiDisUniform` | `DistributionDiscreteUniform` | uniform over the *list*, duplicates kept |
| `PsiShuffle` | `Shuffle` | without replacement — deliberately **not** a distribution |

### Two reference problems, both resolved in the open

**`PsiHypSecant`'s scale is not SciPy's.** The work list's quantile carries a `2/π` that
`scipy.stats.hypsecant` does not. That factor is the whole point: the standard hyperbolic secant
has variance `π²/4`, so dividing by `π/2` makes Frontline's argument the **standard deviation**.
Binding it straight to SciPy's `scale` would give a distribution too wide by `π/2 ≈ 1.571`, and a
test converting both sides the same wrong way would agree and prove nothing — the exact failure
§2.1 describes. `hypSecantScaleIsStandardDeviation` measures the sample standard deviation against
the argument over 200,000 draws to pin it down.

**`PsiGeneral` does not say what the density is at an unstated bound.** Frontline's page defines
the arguments and adds only that it is "similar to a `PsiCumul` … where the probabilities are
calculated using the weights". This implementation takes the density to be **zero at any bound not
given an explicit point**, and says so in the DocC. The reason to prefer that over constant
extrapolation is that it is the reading a caller can override: stating a point at the bound gives
whatever density you want there, whereas under extrapolation there would be no way to ask for zero.

### Why `Shuffle` is not a distribution

Successive draws are not independent and there is no fixed CDF — the law changes after every draw.
Conforming it to `DistributionRandom` would let it be passed wherever an independent sampler is
expected, into a Monte Carlo input or a quasi-random point set, and produce answers that look
ordinary and are wrong. A separate type refuses that at compile time. Frontline draws the same line
between `PsiShuffle` and `PsiResample`.

### The division warnings, and how they were cleared

The new types drew 14 `Floating-point division without visible zero guard` warnings. Every divisor
was provably non-zero — each is validated in a failable initialiser — and the codebase's
established idiom is a `// fp-safety:disable` annotation. That is a suppression, which the project
rules forbid, so instead each type now **forms its reciprocals once in the initialiser**, on the
line after the guard that proves the divisor non-zero, and the hot paths multiply. The warning goes
because the division is gone, not because it was silenced; the code is also faster and the
invariant now sits beside the arithmetic that depends on it.

## Item 4 — the SciPy-checkable distributions (§3 priority 4)

**All nineteen done.** First batch (`df420b14`): `DistributionCauchy`, `DistributionLaplace`, `DistributionLevy`,
`DistributionMaxExtreme`, `DistributionMinExtreme`, `DistributionFrechet`,
`DistributionLogLogistic`, `DistributionReciprocal`. All eight have closed-form CDF and quantile.

**Verified against SciPy 1.17.1, not against themselves.** `Scripts/reference-fixtures/
generate_risk_solver.py` writes `Tests/BusinessMathTests/Fixtures/riskSolverDistributions.json`
— 16 parameterisations, 368 values, committed; CI never runs Python. A round-trip test cannot
catch what actually goes wrong here: a `cdf`/`quantile` pair bound to the **wrong arguments** is
self-consistent, monotone, respects its support, and is wrong. Only a second implementation sees
it. Each fixture entry therefore records the Frontline→SciPy argument mapping alongside the values,
and every distribution is exercised at two parameter sets so one that is only right at the origin
cannot pass.

Quantiles are compared **relatively** (they span 1e-8 to 1e8 across the tails, so an absolute
tolerance would be meaningless at one end) at 1e-9; CDFs absolutely at 1e-10, since they live in
[0,1].

### Names that do not match

- `PsiFrechet` is `scipy.stats.invweibull`, not `frechet`.
- `PsiLogLogistic` is `scipy.stats.fisk`, and Frontline orders the arguments location, scale,
  shape where SciPy takes shape first.
- `PsiReciprocal` is `scipy.stats.loguniform` — SciPy renamed `reciprocal`, and a fixture built
  against the wrong name would silently be a different distribution.
- `PsiCauchy` and `PsiLaplace` carry the prose/signature contradiction; resolved as location-first
  per the standing precedent.

### The trap the work list names, confirmed

*"Distinct from PsiMaxExtreme; do not implement one and negate."* True, and the reason is worth
recording: the two Gumbels are mirror images **about the origin, not about their own location**, so
`−MaxExtreme(m, s)` is `MinExtreme(−m, s)`. Negating agrees only when `m = 0`, which is exactly the
case a quick test would use. `minExtremeIsNotNegatedMaxExtreme` asserts the mirror holds at zero,
that it visibly fails at location 10, and that each is skewed the way its name says.

### Second batch: Burr12, Dagum, JohnsonSB, JohnsonSU, FatigueLife

The Burr mapping was **checked against SciPy directly** rather than inferred, as the work list
asks. `scipy.stats.burr` is type III (Dagum), `scipy.stats.burr12` is type XII, and **both take
`c` then `d` in the same slots** — so binding one to the other's formula would compile,
round-trip, stay monotone, respect its support, and be a different distribution. Verified:
type XII is `F = 1 − (1 + y^c)^(−d)`, type III is `F = (1 + y^(−c))^(−d)`.

`PsiJohnsonSB(shape1, shape2, min, max)` states bounds; `scipy.stats.johnsonsb` takes `loc` and
`scale` with support `[loc, loc + scale]`, so **SciPy's scale is the width**. Passing `max` where
`scale` belongs is right only when `min` is zero. The conversion happens in the initialiser so a
caller states bounds and cannot get it wrong, and the fixture pins a case at `[10, 30]`.

### Numerical defects found by the fixture

Three so far, all of the same kind — a cancellation that every round-trip test passes because both
directions cancel identically. This is the argument for the fixture in one line.

1. **Cauchy**, 1.7e-9 relative at `p = 1e-8`. `tan(π(u − ½))` evaluates `tan` beside `±π/2`, where
   a one-ulp error in the argument explodes. Fixed with the cotangent identity
   `tan(π(u − ½)) = −1/tan(πu)`.
2. **Burr12**, 4.7e-9 relative at `p = 1e-8`. `(1 − p)^(−1/d) − 1` computes `1.0000000033… − 1`,
   discarding nine digits. Fixed with `expm1(−log1p(−p)/d)`, which never forms the `1`.
3. **Dagum**, the same shape at the other end, fixed the same way pre-emptively.

The pattern to watch for in the remaining rows: `pow(x, small) − 1` where the result is near zero,
and any `tan`/`log` evaluated beside a singularity.

### The first numerical defect, in detail

`DistributionCauchy.quantile` first used the textbook `tan(π(u − ½))`, which put SciPy's value out
by 1.7e-9 relative at `p = 1e-8` — the argument sits a hair from `−π/2` where `tan` is
near-vertical, so a one-ulp error in the angle explodes. Replaced with the cotangent identity
`tan(π(u − ½)) = −1/tan(πu)`, which is stable in both tails and reduces to a small accurate
correction near the median. The tolerance was **not** loosened; the far tail is what a heavy-tailed
distribution is read for.

## Remaining Risk Solver work

### Third batch: the six needing a special function

`DistributionErlang` (lower incomplete gamma), `DistributionPearson5` (inverse gamma — the
**upper** incomplete gamma at the **reciprocal** argument, both easy to reverse and both checked),
`DistributionPearson6` (beta prime), `DistributionInverseGaussian`, `DistributionNegativeBinomial`
and `DistributionLogarithmic`. All four special functions the first three need were already in the
package.

**`PsiInvNormal` needed the conversion the work list warned about**: `scipy.stats.invgauss`'s first
argument is the **ratio** `mu/lambda`, not `mu`. Passing `mu` straight through gives a distribution
whose mean is `μ·λ`. The type takes Frontline's `mu` and `lambda`; the fixture does the conversion.

Its quantile has **no closed form**, so it bisects its own CDF. Bisection rather than Newton because
the CDF is strictly increasing on the support, which makes it unconditionally convergent — a
quantile that occasionally returns a negative duration would be worse than one taking a few more
steps. The step count comes from `bisectionStepsToFullPrecision`, derived from the type.

**Two support conventions worth stating**: the negative binomial counts *failures*, so it starts at
0, while `DistributionGeometric` in this package counts *trials* and starts at 1 — they are not the
`s = 1` case of one another. The log-series has `k` in a denominator and starts at 1. A binding that
assumed the wrong one would be shifted by one everywhere and every moment would still look
plausible.

**On the five `catch` blocks.** The special functions throw, and `ContinuousDistribution` declares
`cdf`/`quantile` non-throwing, so an error has to become a value. Checked what they actually throw
on: NaN or out-of-range `p`, and non-positive shapes — every one already excluded by the
initialiser and the guards, so **the catch is unreachable**. There is no error to log, which is
what the checker's suggestion assumes. Used the package's existing `// logging:` convention with a
comment saying the branch is unreachable and why; NaN is the sentinel if the invariant is ever
broken, because any finite substitute could be mistaken for a quantile.

## Remaining Risk Solver work

- **§3 priority 4, the non-SciPy rows** — `PsiMyerson`, `PsiMetalog`, `PsiMetalogFit`,
  `PsiMVLogNormal`, `PsiMomentFit`. These name no reference implementation, so §2.1's method does
  not apply and each needs its own. Metalog in particular is a quantile-parameterised family fitted
  to data, closer to a fitting routine than a distribution.
- **§3 priority 6** — the AR/GARCH family, last: `PsiAR1`, `PsiGARCH11` and their relatives.
  Zero occurrences in the measured corpus; on the list because Frontline documents them.
- **§3 priority 6** — the AR/GARCH family, last: `PsiAR1`, `PsiGARCH11` and their relatives.
  Zero occurrences in the measured corpus; on the list because Frontline documents them.

## What the work turned up

**`poisson(_:µ:)` trapped the process for any count above 20.** It divided by
`x.factorial()`, an `Int` factorial, and 21! exceeds `Int64.max`. λ = 25 is an ordinary arrival
rate, so this was reachable from ordinary input, and a trap is worse than a wrong number — no value
to inspect, nothing to catch. `poissonCDF` did the same inside its summation. Both now evaluate
`exp(k·ln µ − µ − ln Γ(k+1))`, which forms no large intermediate. **There were no Poisson tests at
all**, which is why it survived. There are now.

`poissonCDF` also carried a silent truncation: it capped its sum at 10,000 terms and returned the
partial sum with nothing to say so. Removed — it now runs to the requested floor and stops on the
accumulated mass.

**The `DistributionPoisson` name was already taken by a broken type.** It conformed to
`RandomNumberGenerator` — backwards; a generator supplies bits, a distribution consumes them — and
`random()` returned `poisson(x, µ: Double(x))`, the probability mass at `x` for a rate of `x`,
ignoring the stored rate and returning a probability where a draw was wanted. `next() -> UInt64`
then cast that probability to `UInt64`, so it produced **zero almost every time**. Internal and
unreferenced, so replacing it broke nothing.

**The first KS helper was wrong for discrete data.** The per-sample form compares `i/n` against
`F(x)`, but just below an atom the true CDF is `F(v) − p(v)`; with ties that charges the whole atom
mass as error, and a Poisson with λ = 0.5 puts 0.607 on zero alone. Rewritten to evaluate both step
functions at every integer, where the supremum actually lives.

## Notes

- §2.1 requires the SciPy version be recorded in any fixture-backed test — parameterisations have
  changed between releases.
- Poisson's `quantile` needs care for large λ: a linear scan from 0 is correct but slow. Correct
  first, then measure.

# Design Proposal: Risk Solver completeness — the 57 distributions outside the corpus

**Status:** Draft, for the BusinessMath session
**Author:** SwiftExcelFunctions session, 2026-09-07
**Measured against:** BusinessMath `v2.14.0`
**Data:** `psi_upstream_gaps.tsv` (this folder), `psi_functions.tsv`, `businessmath_work.tsv`

---

## 1. Objective

Close the gap between Frontline's documented Psi surface and BusinessMath's implementation:
**57 distribution names with no mathematics upstream at 2.14.0.**

The objective is *completeness*, explicitly not urgency. None of the 57 is reached by the 2,236-workbook
corpus. This proposal exists so that the remaining surface is a known, sized list rather than an
unexamined one, and so that whoever picks it up does not discover its structure the hard way.

**Success:** every Frontline distribution name is either implemented, or recorded as deliberately
excluded with a reason. No name is merely unexamined.

---

## 2. Motivation

### 2.1 Why there is a gap at all

`businessmath_work.tsv` was scoped **from the corpus** — 49 rows chosen because real workbooks call
them. That scope was correct and it succeeded: 2.14.0 closed all 49, and every Psi distribution the
corpus uses is now backed.

The 57 in this proposal are what Frontline documents that our corpus happens not to call. **The two
lists do not intersect at all** — of these 57 names, zero appear in `businessmath_work.tsv`. This is
not work attempted and missed. It was never in scope, and until now nothing tracked it.

Two of the 57 are half-recorded, in prose rather than as rows: the notes on `PsiAR1` and
`PsiGARCH11` say the other seven time-series functions "follow the same pattern and should share one
implementation." True, and not a tracking mechanism.

### 2.2 Why it is worth doing anyway

The project's stated purpose is to read a workbook that used Risk Solver **without** Risk Solver.
Frontline's add-in is closed source, and that dependency is what this work exists to break. A
corpus-shaped implementation breaks it for *our* corpus. Someone else's workbook is a different
corpus, and `PsiPert` is a mainstream project-risk distribution that our sample simply does not
contain.

### 2.3 Why it is not urgent

Sized honestly: the corpus calls **none** of the 57. All nine Psi distributions it does call are
bindable today. This is a completeness list, not a blocker list, and the priority in §7 reflects
that.

---

## 3. Proposed Architecture

The 57 rows are **not 57 pieces of work.** They collapse to roughly twenty, because one group of 28
is a single capability wearing 28 names.

| Group | Rows | Pieces of work | Owner |
|---|---:|---:|---|
| Percentile parameterisation (`*Alt`) | 28 | **1** | BusinessMath |
| Individual distributions | 17 | 17 | BusinessMath |
| Time series | 7 | 2 | BusinessMath |
| Not mathematics | 5 | 0 | **Downstream** |

### 3.1 The 28 `*Alt` rows are one capability, not 28 distributions

This is the central claim of the proposal, and getting it wrong is the expensive mistake available
here.

`PsiNormalAlt`, `PsiWeibullAlt`, `PsiParetoAlt` and the rest are **not new distributions.** They are
the distributions BusinessMath already has, parameterised by *what the user knows* instead of by the
canonical parameters. Read the signatures together and the pattern is unmistakable:

```
PsiNormalAlt          2 parameters: 2 different percentiles, or percentile and mean,
                                    or percentile and stdev
PsiFatigueLifeAlt     3 name/value pairs, names chosen from: loc, scale, shape,
                                    or a percentile (0-1)
                                    e.g. PsiFatigueLifeAlt(5%, 1.5, 50%, 2.5, 95%, 4.5)
PsiWeibullAlt         1 percentile parameter
PsiBetaGenAlt         4 name/value or percentile/value pairs, chosen from:
                                    percentile1..4, shape1, shape2, min, max
```

Every one is the same problem: **given _k_ constraints on a distribution with _k_ parameters, solve
for the parameters.** A constraint is one of

- a *quantile* constraint — `Q(p) = v`, "the 95th percentile is 4.5"
- a *moment* constraint — `mean = v`, `var = v`, `stdev = v`
- a *native* constraint — `loc`, `scale`, `shape`, `min`, `max`, `likely`, `mode` given directly

Implementing this 28 times would produce 28 root-finds that can disagree about the same
distribution. Implementing it once produces one.

**Proposed shape** — a protocol a distribution opts into, plus one generic solver:

```swift
/// A constraint on a distribution's parameters, as Risk Solver's `*Alt` forms state them.
public enum ParameterConstraint<T: Real & Sendable>: Sendable {
    case quantile(p: T, value: T)     // Q(p) = value
    case mean(T)
    case variance(T)
    case standardDeviation(T)
    case native(name: String, T)      // loc / scale / shape / min / max / likely
}

/// A distribution whose parameters can be recovered from what the modeller knows.
public protocol PercentileParameterisable: DistributionRandom {
    /// The canonical parameters, in the order the solver varies them.
    static var parameterNames: [String] { get }

    /// Build from canonical parameters. Returns nil if they are out of support.
    static func make(parameters: [Self.T]) -> Self?

    /// A starting point for the solve. A bad guess costs iterations; a wrong one costs a root.
    static func initialGuess(for constraints: [ParameterConstraint<Self.T>]) -> [Self.T]
}

public extension PercentileParameterisable {
    /// Solve for the distribution matching the stated constraints.
    ///
    /// - Throws: `ParameterFitError.underdetermined` when constraints < parameters,
    ///           `.overdetermined` when more, `.noSolution` when the solve does not converge.
    static func fitting(_ constraints: [ParameterConstraint<T>]) throws -> Self
}
```

The solve is a *k*-dimensional root-find on the residual vector — the difference between each
constraint's target and what the candidate parameters produce. BusinessMath already has the
machinery (`newtonRaphsonOptimize`, `minimizeBFGS`), so this reuses a solver rather than adding one.

For *k* = 1 it is a bisection on a monotone function and needs nothing clever. For *k* = 2 (most
rows) a 2-D Newton with numerical Jacobian is sufficient. Only *k* = 3–4 (`PsiFatigueLifeAlt`,
`PsiBetaGenAlt`, `PsiTriangGenAlt`, `PsiPertAlt`) needs the general path.

**A distribution opts in by conforming.** Nothing else changes, and a distribution that does not
conform simply has no `*Alt` form — which is the honest state for anything whose quantile has no
usable derivative.

### 3.2 The 17 individual distributions

Genuinely absent mathematics, each its own row. Grouped by what they resemble:

| Rows | Note |
|---|---|
| `PsiPert`, `PsiBetaSubj`, `PsiBetaGen` | Beta re-parameterisations. `PsiPert` is the standard Beta-PERT: `α = 1 + 4(c−a)/(b−a)`, `β = 1 + 4(b−c)/(b−a)`, scaled to `[a, b]`. Builds directly on `DistributionBeta`. |
| `PsiTriangGen`, `PsiNormalSkew` | Generalised forms of types already present. |
| `PsiPareto2` | Lomax — `DistributionPareto` shifted. |
| `PsiErf` | Error-function distribution; a Normal in disguise, `σ = 1/(h√2)`. |
| `PsiMetalog2`, `PsiMetalogSPT`, `PsiMetalog2Fit` | Metalog variants on the existing `DistributionMetalog`. |
| `PsiHistogram`, `PsiCumulD` | Piecewise-uniform and discrete-cumulative; siblings of `DistributionCumul`. |
| `PsiFit` | Fit a distribution to data — a selection problem as much as a fitting one. |
| `PsiMVNormal`, `PsiMVResample`, `PsiMVShuffle` | Multivariate. `DistributionMVLogNormal` exists, so the correlated-normal machinery is already here. |
| `PsiMakeInput` | Frequency/severity compound model. |

Several are shallow — `PsiErf` and `PsiPert` are closed-form re-parameterisations of types that
exist, and are an afternoon each. `PsiFit` and the multivariate rows are not.

### 3.3 The 7 time-series rows are 2 implementations

`PsiAR2`, `PsiMA1`, `PsiMA2`, `PsiARMA11` share the ARMA recursion; `PsiARCH1`, `PsiEGARCH11`,
`PsiAPARCH11` share the GARCH variance recursion. BusinessMath's own notes on `PsiAR1` and
`PsiGARCH11` already say exactly this.

`AutoregressiveOne` and `GarchOneOne` exist as the general shape. The work is generalising each to
its family's order and variance form, not writing seven processes.

### 3.4 The 5 that are not BusinessMath's

`PsiSip`, `PsiSlurp`, `PsiTSSip`, `PsiCertified`, `PsiVary`.

These take the **name of a stored data object** — a Stochastic Information Packet held in the
workbook — or declare a sensitivity role. Nothing is computed; a name is resolved against a file.

That is address arithmetic, and this package's own proposal already draws the line there: *"they are
error semantics and address arithmetic. BusinessMathExcel owns them."* They belong with `solver_adj`
and the Psi role declarations, read from the sheet rather than evaluated.

**Recommendation: record these as deliberately excluded, in `businessmath_work.tsv` or §4 of the
coverage proposal.** Implementing them here would mean inventing a workbook to satisfy them.

---

## 4. API Surface

Additive only. No existing signature changes.

```swift
// New, §3.1
public enum ParameterConstraint<T: Real & Sendable>: Sendable { … }
public protocol PercentileParameterisable: DistributionRandom { … }
public enum ParameterFitError: Error, Sendable { case underdetermined, overdetermined, noSolution }

// New conformances on existing types, §3.1
extension DistributionNormal: PercentileParameterisable { … }
extension DistributionWeibull: PercentileParameterisable { … }
// … one per Alt row supported

// New types, §3.2
public struct DistributionPert<T: Real & Sendable>: ContinuousDistribution, Sendable { … }
public struct DistributionNormalSkew<T: Real & Sendable>: ContinuousDistribution, Sendable { … }
// …

// Generalised, §3.3
public struct AutoregressiveMovingAverage<T>: StochasticProcess { … }   // AR1/AR2/MA1/MA2/ARMA11
public struct GarchFamily<T>: StochasticProcess { … }                   // ARCH1/GARCH11/EGARCH11/APARCH11
```

**Excel-facing names appear nowhere.** `SwiftExcelFunctions` owns the registry, argument order,
coercion and error semantics, per §4 of the coverage proposal. This package gains mathematics and no
`Psi*` symbol.

---

## 5. Constraints & Compliance

- **Swift 6 strict concurrency.** Every new type `Sendable`; the solver holds no shared mutable state.
- **No force unwraps, no `try!`, no `as!`.** `make(parameters:)` returns `Optional` precisely so an
  out-of-support candidate mid-solve is a `nil`, not a trap.
- **Division safety.** The residual Jacobian divides by a step; guard it. Degenerate constraint sets
  (`min == max`) must return `.noSolution`, not `NaN`.
- **`quantile` monotonicity.** The existing `DiscreteDistribution` contract requires `quantile` be
  monotone non-decreasing and usable by quasi-random sampling. The fitting solve calls `quantile`
  directly and inherits that requirement — an alias table in `quantile` would break the solve as
  surely as it breaks Sobol.
- **No second implementation of anything.** `PsiPert` builds on `DistributionBeta`; `PsiErf` on
  `DistributionNormal`; `PsiPareto2` on `DistributionPareto`. A second Beta that could disagree with
  the first is the failure this package's structure exists to prevent.

---

## 6. Test Strategy

Follows the three tiers already established, in `PROPOSAL_excel_function_coverage.md` §2.

1. **`scipy.stats` parity**, via `Scripts/reference-fixtures/generate_risk_solver.py` and a JSON
   fixture, as `RiskSolverScipyParityTests` already does. Most rows have a SciPy equivalent:
   `PsiPert` is `scipy.stats.beta` scaled, `PsiPareto2` is `lomax`, `PsiErf` is `norm` rescaled.
2. **Closed form** where the formula *is* the reference — `PsiPert`'s α/β, `PsiErf`'s σ.
3. **Round-trip, for the fitting capability specifically.** This is the tier the `*Alt` work needs
   and the one the others do not:

   > For a distribution with known parameters, compute its true quantiles at *p₁…p_k*, feed those
   > back as constraints, and require the recovered parameters to match the originals.

   That tests the solver against the distribution itself rather than against a table, it works for
   every conformer without a new fixture, and it fails loudly when a Jacobian is wrong. It is also
   the only tier that can be written *before* deciding which distributions conform.

4. **Monotonicity and support**, per the `DiscreteDistribution` contract, for every new discrete row.

**What cannot be tested against the corpus:** all of it. These 57 appear in no workbook we hold, so
there are no cached values. That is the same position `PROPOSAL_psi_bindings.md` §5 records for the
whole family, for the same reason — Monte Carlo with no published seed — and the published
specification is the only oracle available.

---

## 7. Priority

Ordered by leverage, not by row count.

| # | Item | Rows | Why here |
|---|---|---:|---|
| 1 | **The percentile-fitting capability** | 28 | Best ratio in the whole list: one solver, 28 names. Also the only item that makes *future* distributions cheaper, since a new conformer costs one extension. |
| 2 | **The shallow re-parameterisations** — `PsiPert`, `PsiErf`, `PsiPareto2`, `PsiBetaSubj` | 4 | Closed-form on existing types. `PsiPert` is the one a stranger's workbook is most likely to contain. |
| 3 | **The ARMA family** | 4 | One generalisation of `AutoregressiveOne`. |
| 4 | **The Metalog and Cumul siblings** | 5 | Existing types, extended. |
| 5 | **The GARCH family** | 3 | Their own note: "Lowest priority: 0 occurrences in the measured corpus." |
| 6 | **Multivariate and `PsiFit`** | 5 | Genuinely new work, and the least evidence of demand. |
| — | **The 5 that are not yours** | 5 | Record as excluded; do not implement. |

Item 1 alone takes the Psi distribution surface from 56/113 to 84/113.

---

## 8. Alternatives Considered

**Implement the 28 `*Alt` rows individually.** Rejected. Twenty-eight root-finds over the same
mathematics, able to disagree with each other about the same distribution, and each needing its own
tests. The signature prose makes them look like 28 distinct functions; reading them together shows
one problem stated 28 times. This is the alternative most likely to be chosen by accident, which is
why it is named here.

**Do nothing until a corpus demands it.** Defensible, and close to the current position — the
existing work list was corpus-scoped on purpose and that judgement was sound. Rejected as the
*recorded* position only because "we chose not to" and "nobody looked" are indistinguishable a year
later unless written down. This document is the minimum that makes the choice legible; acting on it
can wait.

**Implement `*Alt` by moment-matching rather than quantile-matching.** Rejected: it answers a
different question. `PsiNormalAlt(10%, 5, 90%, 15)` states percentiles, and matching moments to
them would produce a plausible distribution that does not pass through the stated points.

**Ask Frontline for the parameterisation rules.** Not available — closed source, and the
documentation is exactly what we already have.

---

## 9. Open Questions

1. **How does an `*Alt` call distinguish a percentile from a native parameter at the boundary?**
   Frontline's own example is `PsiFatigueLifeAlt(5%, 1.5, 50%, 2.5, 95%, 4.5)` — the *name* is a
   number in 0–1. If a distribution has a `scale` that could legitimately be 0.05, an argument pair
   `(0.05, x)` is ambiguous between "the 5th percentile is x" and "scale is 0.05". Excel's cell
   formatting (`5%` vs `0.05`) is display, not value, and does not survive into the AST.

   This must be resolved at the **binding** boundary rather than here, since it is a question about
   how the argument was written. Flagged so the solver's API does not assume it away: taking
   `[ParameterConstraint]` rather than a flat `[T]` is what leaves room for the caller to decide.

2. **Does `PsiFit` choose the distribution family, or is it told?** The signature is `data` alone,
   which suggests it selects — and selection needs a criterion (AIC, KS, log-likelihood) that
   Frontline does not publish. Recommend deferring until someone can state the criterion.

3. **`PsiTriangGen(ap, m, br, p, r)`** — five parameters, and the documentation does not say what
   `p` and `r` are. Neither prose nor signature settles it. Recommend leaving it in the delta,
   marked `unresolved`, rather than guessing.

4. **Is a `*Alt` form wanted for every conformer, or only the ones Frontline names?** Frontline
   documents 28. The proposed protocol would permit more at no cost, which is either a nice
   generalisation or scope creep depending on your taste. Recommend conforming exactly the 28 and
   letting the rest be pull.

---

## 10. Documentation Strategy

Each new type carries the DocC that the existing distributions do, plus the two things this
particular batch needs:

- **Where Frontline's prose contradicts its signature, say so in the type's documentation** and say
  which was taken as authoritative. This package has already set that precedent three times
  (`PsiCauchy`, `PsiLaplace`, `PsiHyperGeo`), and it is the reason a future reader meets the
  contradiction instead of rediscovering it.
- **For every `*Alt` conformer, document which constraints are accepted**, since it varies by
  distribution and the signature prose is where the variation lives.

`psi_upstream_gaps.tsv` in this folder is the joinable record and should be updated as rows land —
it is the file that answers "what is left", and it was written because nothing did.

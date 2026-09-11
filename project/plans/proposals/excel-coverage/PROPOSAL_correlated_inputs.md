# Design Proposal — correlated uncertain inputs

**Status:** proposal, 2026-09-11. Phase 0 (Design).
**Scope:** spans **BusinessMath** (the mathematics, and the majority of the work) and
**SwiftExcelFunctions** (declaration recognition and the trial loop). §7 and §8 split it.
**Priority:** immediate. §2 argues this is the single gap most likely to lose an evaluation.

---

## 1. Objective

**Let two uncertain inputs move together.**

```swift
// Declared in the workbook, on each uncertain cell:
//   C4:  =PsiNormal(100, 15, PsiCorrMatrix($H$1:$J$3, 1, 1))
//   C5:  =PsiTriangular(8, 10, 14, PsiCorrMatrix($H$1:$J$3, 2, 1))
//   C6:  =PsiLogNormal(2.5, 0.4, PsiCorrMatrix($H$1:$J$3, 3, 1))
//
// H1:J3 holds the correlation matrix. Running the model must reproduce it in the
// sampled draws, while every marginal stays exactly what it was declared to be.
```

Today those three cells draw independently. The `PsiCorrMatrix` argument evaluates to a
number and is silently ignored, so the model runs, produces plausible output, and understates
tail risk — the failure mode that matters, because nothing about it looks wrong.

---

## 2. Motivation

### 2.1 It is the first thing an evaluator tests

The simulation stack now reads a Risk Solver workbook, finds its uncertain inputs and its
outputs, runs seeded reproducible trials, and answers `PsiMean`, `PsiPercentile` and `PsiCVaR`
from the completed run. Against a product that is **$375/month, or about $2,520 a year on the
annual plan, per seat, Windows-only**, that is a serious proposition.

It stops being serious the moment someone correlates two inputs. Anybody with a risk background
will do that within the first ten minutes, because uncorrelated inputs is the assumption their
whole discipline exists to stop people making.

### 2.2 Silence is the wrong failure

An unimplemented distribution is `#NAME?` — visible, and the reader knows to stop. An ignored
correlation is a **number**. The model runs, the histogram looks reasonable, and the answer is
wrong in the direction that costs money: independent draws understate the probability that
several things go badly at once, which is the entire question a risk model is asked.

So this is not "one more Psi function." It is the difference between a simulator that is
incomplete and one that is quietly misleading. Until it lands, §9 proposes the trial loop
**refuse** a model carrying correlation declarations rather than run it uncorrelated.

### 2.3 Not a research problem

§3 is the reason this is marked immediate rather than large: the hard parts are already here.

---

## 3. What already exists — which is most of it

Checked rather than assumed, 2026-09-11.

| Piece | Where | State |
|---|---|---|
| Cholesky decomposition | `Simulation/CorrelationMatrix.swift:166` | ✅ `choleskyDecomposition(_:)` |
| Matrix validation | `Simulation/CorrelationMatrix.swift` | ✅ `isValidCorrelationMatrix`, `isSymmetric`, `isPositiveSemiDefinite` |
| Correlated standard normals | `Simulation/CorrelatedNormals.swift:80` | ✅ `CorrelatedNormals(means:correlationMatrix:)`, `sample(using:)` |
| Normal CDF Φ | `…/Normal Probability/normalCDF.swift:85` | ✅ |
| Normal quantile Φ⁻¹ | `…/Normal Deviate/inverseNormalCDF.swift:112` | ✅ |
| Spearman's ρ | `…/spearmansRho.swift:41` | ✅ — for *verifying* a run |
| Per-distribution quantiles | `Simulation/ContinuousDistribution.swift:97` | ✅ `func quantile(_ p: T) -> T` on every marginal |
| Multivariate normal / lognormal | `Simulation/distributionMVNormal.swift` | ✅ already bound as `PsiMVNormal` |
| Resample / shuffle | `Simulation/MultivariateSampling.swift` | ✅ already bound |

**A Gaussian copula is `CorrelatedNormals` followed by `normalCDF`.** Both exist. The
per-marginal inverse transform the sampler already uses — every Psi distribution is bound
through a `quantile(u)` — is exactly the third step. The pipeline is three existing pieces in a
row that nothing currently puts in a row.

What is genuinely absent is small, and named in §7.

---

## 4. What Risk Solver specifies

Signatures confirmed against Frontline's reference:

```
PsiCorrMatrix(matrix_cell_range, position, instance)       rank-order correlation
PsiCopulaGauss(number_range, position, instance)           Gaussian copula
PsiCopulaStudent(number_range, position, df, instance)     t copula
PsiCopula(type, param, reflection, instance)               generic: Clayton / Frank / Gumbel, rotatable
PsiCorrIndep(corrname)                                     property function
PsiCorrDepen(corrname, coefficient)                        property function
PsiCorrelation(cell1, cell2, simulation)                   a STATISTIC, not a declaration
```

### 4.0 Two mechanisms, one shape — measured 2026-09-11

Frontline's documentation settles the two questions this section originally left open.

**`PsiCorrMatrix` is rank-order.** Verbatim: *"specify that an uncertain variable is correlated
with a group of other uncertain variables, through a matrix of **rank-order** correlation
coefficients."* So §6.1's Spearman→Pearson adjustment is **required, not conditional**. Skipping
it makes every declared correlation come out systematically weaker than asked for.

**The copula is a separate property function, not an argument.** `PsiCorrMatrix`'s third argument
really is `instance`, the matrix's name. Copula choice arrives as its own property function
attached to the same distribution call:

```
=PsiBeta(3, 4, PsiCopulaGauss(N2:P4, 2, "mycop"))
```

That is good news architecturally. **All four declaration functions carry the same
(range, position, instance) shape**, so one grouping mechanism serves all of them — the group key
is (range, instance) and the member index is `position`, exactly as §4.1 describes. Implementing
`PsiCorrMatrix` gets `PsiCopulaGauss` almost free; `PsiCopulaStudent` adds a degrees-of-freedom
parameter and a t-copula sampler; `PsiCopula` adds the Archimedean family.

The property-function machinery already handles several attached to one call — `PsiBaseCase` and
`PsiName` coexist today — so nothing new is needed to read them.

### 4.1 The shape is already the shape we handle

`PsiCorrMatrix` is a **property function**, like `PsiBaseCase` and `PsiName` — a trailing
argument on the distribution call rather than a separate statement. The machinery for that
exists: every Psi distribution is already a context function reading
`EvaluationContext.arguments` to see the *unevaluated* form, because `PsiBaseCase(5)` and a
literal `5` are indistinguishable once evaluated.

The group is discovered from the members. Each correlated cell names the same
`matrix_cell_range` and the same `instance`, and its own `position` — the index of its row and
column in that matrix. So:

> **group key** = (matrix range, instance) **·** **member index** = position

No separate declaration to find, no ordering dependency, and a model that correlates two
disjoint sets of inputs simply has two instances.

### 4.2 `PsiCorrelation` is in the wrong family

The coverage matrix files it with the correlation declarations. Its third argument is
`simulation`, which is the signature every *statistic* carries — `PsiMean(cell, simulation)`,
`PsiPercentile(cell, p, simulation)`. It reads the correlation **out of a completed run**
between two output cells. It belongs with `BuiltinRiskSolverStatistics` and the
`SimulationResultProvider`, not here, and it is cheap once the run exists.

Worth stating because filing it here would have it waiting on work it does not need.

---

## 5. The design

### 5.1 Gaussian copula, drawn per trial

For a group of *K* correlated inputs with target correlation matrix **R**:

```
once, at setup:      L = cholesky(adjust(R))        adjust: §6.2
once per trial:      z = L · ξ,  ξ ~ N(0, I)ᴷ       CorrelatedNormals.sample(using:)
                     u = Φ(z)                        normalCDF, componentwise → K uniforms in (0,1)
per member k:        xₖ = marginalₖ.quantile(uₖ)     the existing per-distribution quantile
```

**Every marginal survives exactly.** Each input still passes through its own `quantile`, so a
`PsiTriangular(8, 10, 14)` is still exactly that triangular — correlation changes only *which*
uniform it receives, never the distribution it is drawn from. That property is why the copula is
the right choice and why it composes with 107 already-bound distributions without touching any
of them.

### 5.2 The one architectural change downstream

Today each distribution pulls a scalar uniform from the `RandomSource`. Correlation means the
uniforms handed to a *group within one trial* are no longer independent, so somebody has to draw
the K-vector once and deal it out.

Proposed: a **group-scoped uniform source**, resolved per trial before the cells evaluate. The
per-cell contract does not change at all — a distribution still receives one uniform and calls
its own quantile. It just comes from the group's vector rather than the scalar stream.

That matters because it leaves `InterpretedRun`'s per-trial streaming model and the `Lowerer`'s
bytecode fast path intact. An approach that needed all N trials before it could produce any
answer would break both.

### 5.3 The alternative, and why it is the fallback

**Iman–Conover** (1982) is the distribution-free approach: draw all N trials independently, then
*reorder* each column so the sample rank correlation matches the target. @RISK and Crystal Ball
use it. It matches rank correlation very precisely and assumes nothing about the copula.

It is not proposed as the primary because it is **post-hoc by construction** — it needs the
whole N×K sample matrix before it can reorder anything, which turns a streaming trial loop into
a two-pass one and makes per-trial output meaningless until the run completes.

Recommend: ship the copula, and keep Iman–Conover on the list for the case §11.2 raises — tail
dependence, where a Gaussian copula is known to be optimistic.

---

## 6. The two pieces of mathematics that are genuinely missing

### 6.1 Rank correlation is not product-moment correlation

If the declared matrix is **Spearman** rank correlation — and §11.1 says this must be measured
rather than assumed — feeding it straight into a Gaussian copula produces draws whose rank
correlation is *lower* than declared. The relationship for a Gaussian copula is exact:

```
ρ_Spearman = (6/π) · arcsin(ρ_Pearson / 2)
```

so the matrix must be transformed before Cholesky:

```
ρ_Pearson = 2 · sin(π · ρ_Spearman / 6)
```

The correction is small but systematic — at ρ_S = 0.8 it wants ρ_P ≈ 0.8123 — and it is in the
direction that matters: skip it and every correlation is slightly weaker than the modeller
asked for. For Kendall's τ the companion identity is `ρ_P = sin(π τ / 2)`.

**One function each, both one-liners, both needing a test against published values.** They are
mathematics and belong here.

### 6.2 A user's correlation matrix is usually not a valid one

A matrix typed into a spreadsheet by hand is symmetric with a unit diagonal and, very often,
**not positive semi-definite** — which means no Cholesky, and no sampler. Today
`isValidCorrelationMatrix` correctly answers `false` and there is nothing to do about it.

Refusing is defensible but unhelpful: the modeller's intent is clear and the matrix is a
near-miss. **Higham's alternating-projections algorithm** finds the nearest correlation matrix in
the Frobenius norm — project onto the PSD cone by clipping negative eigenvalues, project onto
unit diagonal, repeat until converged.

Proposed behaviour, and it should be loud rather than silent:

| Matrix | Response |
|---|---|
| valid | use it |
| symmetric, unit diagonal, not PSD | repair, **and report the adjustment made** |
| not symmetric, or diagonal ≠ 1, or any \|ρ\| > 1 | refuse — that is a typo, not a near-miss |

The middle row must surface the distance from the original. A silently repaired matrix is a
model answering a question nobody asked.

This is the largest single item and the only one requiring real numerical care — it needs an
eigendecomposition, and `MatrixBackend` / `DenseMatrix` are the existing place to get one.

---

## 7. Work in BusinessMath

| # | Item | Notes |
|---|---|---|
| 1 | `spearmanToPearson(_:)` / `kendallToPearson(_:)` | §6.1. One line each, tested against published values. |
| 2 | `nearestCorrelationMatrix(_:tolerance:maxIterations:)` | §6.2. Higham. Returns the repaired matrix **and** the Frobenius distance. |
| 3 | `GaussianCopula(correlation:)` with `sample(using:) -> [Double]` | §5.1. Composes items 1–2 with the existing `CorrelatedNormals` and `normalCDF`. Returns uniforms, not variates — the marginals are the caller's. |
| 4 | *(deferred)* `ImanConover` | §5.3. Not in this pass; recorded so the option is on the record. |

Items 1–3 are the whole of the primary path, and item 3 is mostly composition.

## 8. Work in SwiftExcelFunctions

Stated so the split is explicit rather than discovered later.

| # | Item |
|---|---|
| 5 | Recognise `PsiCorrMatrix` as a property function — extend the existing `attached(_:_:)` reader |
| 6 | `ModelSurveyor` groups inputs by (matrix range, instance) and records each member's position |
| 7 | `InterpretedRun` resolves a group's uniform vector once per trial and deals it to members |
| 8 | `PsiCorrIndep` / `PsiCorrDepen` — the named-correlation form, over the same grouping |
| 9 | `PsiCorrelation` as a **run statistic**, with the other statistics — §4.2 |
| 10 | `Lowerer` — either support correlated groups on the fast path, or refuse them by name so they fall to the interpreted path, which is the existing contract |

---

## 9. Until it lands, refuse rather than ignore

`ModelSurveyor` can already see a `PsiCorrMatrix` in the AST before any of this is built.
**Proposed immediately, ahead of the rest:** a model carrying correlation declarations is
reported as not simulable, with the cells named.

A refusal a caller can read beats a number they cannot question, and §2.2 is the argument. This
is a few lines and it should not wait for item 3.

---

## 10. Test strategy

Three layers, as with the Psi distributions, and for the same reason: the cached values in a
corpus workbook are one draw from one unseeded run and cannot be an oracle.

1. **Identity tests, deterministic.** `spearmanToPearson(0.8) ≈ 0.81232`; a valid matrix is
   returned unchanged by the repair with distance 0; a known non-PSD matrix repairs to a known
   nearest one — Higham's paper carries worked examples.
2. **Distributional tests, seeded.** Draw 100,000 trials from a declared matrix; the *sample*
   Spearman correlation must recover the declared value within sampling error. `spearmansRho`
   already exists and is the check. Crucially, also assert the **marginals are undisturbed** —
   a Kolmogorov–Smirnov comparison of each column against its declared distribution, because the
   whole claim of §5.1 is that correlation changes the coupling and nothing else.
3. **Reproducibility.** Same seed, same draws, exactly — the property
   `testARealModelReproducesUnderTheSameSeed` already asserts for uncorrelated models, extended
   to a correlated one.

Layer 2 is the one that would catch a missing §6.1 adjustment, and it is worth constructing it
so that it does: with the adjustment skipped, a declared 0.8 comes back around 0.786, which a
loose tolerance would wave through. **Set the tolerance tight enough to fail that.**

---

## 11. Open questions

1. **~~Is the declared matrix Spearman or Pearson?~~** **Resolved 2026-09-11: rank-order.** See
   §4.0. The §6.1 adjustment is required.
2. **~~Which copulas?~~** **Resolved 2026-09-11: separate property functions**, not an argument —
   `PsiCopulaGauss`, `PsiCopulaStudent`, and a generic `PsiCopula(type, param, reflection,
   instance)` for the Archimedean family. All share `PsiCorrMatrix`'s grouping shape. See §4.0.
2a. **Is `PsiCopulaGauss`'s matrix rank or linear?** The question survives in sharper form. When
   the modeller names the copula explicitly, its matrix is most likely the copula's own
   correlation parameter — i.e. **linear on the latent normals, needing no adjustment** — whereas
   `PsiCorrMatrix` is documented as rank and does need one. Applying the adjustment to both, or
   neither, is wrong in one case. Frontline's `PsiCopulaGauss` page does not say. **This blocks
   only `PsiCopulaGauss`, not `PsiCorrMatrix`**, so it need not hold up the primary path.
3. **What does a group containing a discrete distribution do?** A discrete quantile is a step
   function, so the achievable rank correlation is bounded below the declared one and no sampler
   can do better. Proposed: allow it, and report the achieved correlation rather than pretending.
4. **Should the repair in §6.2 be opt-in?** A model-validation user may prefer a hard refusal to
   any silent adjustment. Leaning toward repair-and-report by default with a strict mode
   available, but it is a judgement call about who the caller is.

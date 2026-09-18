# Design Proposal — A density for every continuous distribution

**Status:** **Implemented, 2026-09-18.** The requirement is on the protocol, every conformer
answers it, and `ContinuousDensityTests` holds all forty-six to the four properties in §4.
What §3's inventory got wrong is recorded in §8.
**Author:** Session of 2026-09-18, arising from the `chi2pdf` repair in `f8782443`
**Area:** `Simulation/ContinuousDistribution` and its 44 conformers

---

## 1. Problem

`ContinuousDistribution` requires `cdf(_:)` and `quantile(_:)` and nothing else. A continuous
distribution has a probability density by definition, and this protocol does not ask for one.

Six of its forty-four conformers define a `pdf(_:)` anyway. The other thirty-eight cannot
answer *"how likely is a draw to fall near here"* — which is the question every plot, every
likelihood, every rejection sampler and every Bayesian update asks.

### How this surfaced

Not by design review. `chi2pdf(x:dF:)` was found to be computing a cumulative sum rather than
a density — its body summed the density at 0.001, 0.002, … up to `x` and multiplied by the
step. `chi2pdf(x: 10, dF: 3)` answered 0.98144, the CDF at 10, where the density is 0.0085.

Fixing it meant writing `chiSquaredPDF(x:df:)`, and writing that raised the obvious question:
where does a density *belong* in this module? The answer turned out to be "nowhere in
particular", and that is the gap this proposes to close.

**The same defect had been found once before and fixed in the wrong direction.** `chi2cdf`
used to be `1 - chi2pdf(x:dF:)`; that was recognised as nonsense, `chi2cdf` was deleted, and
`chiSquaredCDF(x:df:)` written to replace it — while `chi2pdf` was left exported and wrong. A
module that holds a correct CDF and a misnamed one is worse than one holding neither, because
the pair looks deliberate. A protocol requirement is what stops the next one.

## 2. Proposal

Add to `ContinuousDistribution`:

```swift
/// The probability density at `x` — the derivative of `cdf(_:)`.
func pdf(_ x: T) -> T
```

**No default implementation.** A default that numerically differentiated `cdf(_:)` would
compile everywhere immediately and let any unconverted type ship a silently approximate
density — the precise failure this module has already had once. Without a default the compiler
enumerates every type that owes one, and the list cannot be forgotten.

### The contract

- **Non-negative everywhere**, and **zero outside the support** rather than undefined. A
  caller plotting across a range should not have to know where the support ends.
- **The derivative of `cdf(_:)`**, checked rather than asserted — see §4.
- **Assembled in logs wherever the normalising constant can overflow.** `Γ((ν+1)/2)/Γ(ν/2)`
  overflows a `Double` around ν = 340 while the density it belongs to is an ordinary number
  near one. `DistributionT.pdf(_:)` already says this; it becomes the house rule.
- **`infinity` where the density genuinely is unbounded** — a chi-squared with one degree of
  freedom at zero, a beta with α < 1, a Weibull with k < 1. That is the honest answer and the
  tests expect it.
- **`nan` for invalid parameters**, matching what `cdf(_:)` already does on the same types.

## 3. The inventory

Six have a density. `DistributionGeneral` and `DistributionStudentT` had one before this work;
`DistributionChiSquared`, `DistributionNormal`, `DistributionExponential`,
`DistributionUniform`, `DistributionLogistic` and `DistributionRayleigh` were added in
`f8782443` while fixing `chi2pdf`.

**Thirty-eight remain**, in three groups that want different treatment:

### Closed form, textbook (30)

`Beta` · `BetaGeneralised` · `BetaSubjective` · `Burr12` · `Cauchy` · `Dagum` ·
`DoubleTriangular` · `Erlang` · `F` · `FatigueLife` · `Frechet` · `Gamma` · `HypSecant` ·
`InverseGaussian` · `JohnsonSB` · `JohnsonSU` · `Kumaraswamy` · `Laplace` · `Levy` ·
`LogLogistic` · `LogNormal` · `MaxExtreme` · `MinExtreme` · `Pareto` · `Pareto2` · `Pearson5` ·
`Pearson6` · `Pert` · `Reciprocal` · `T` · `Triangular` · `Weibull`

Each is a published formula. The work per type is small; the risk is that a wrong one is
**silent**, which is what §4 exists for.

### Derived from another distribution (2)

`Erf` and `MomentFit` are reparameterisations — their densities follow from the distribution
they wrap, and should delegate rather than restate.

### Empirical or fitted (6)

`Cumul` · `Histogram` · `Metalog` · `Myerson` · and the two fitted forms.

These have no closed-form density in the usual sense. `Histogram` and `Cumul` are piecewise
constant or piecewise linear and their densities are exact and easy. `Metalog` and `Myerson`
are defined by their **quantile** function, so the density is `1 / q′(p)` at `p = cdf(x)` — a
real derivative, and the one case where a numerical one is the right answer rather than a
shortcut. **Each such case states so in its documentation**, so an approximate density is a
declared choice and never an omission.

## 4. Testing — one harness over every conformer

The point of doing this as a protocol requirement rather than 38 separate additions is that a
single property test can verify all of them:

```swift
// For every conformer, at several interior points of its support:
//   1. pdf(x) >= 0
//   2. |pdf(x) - (cdf(x+h) - cdf(x-h)) / 2h| < tolerance
//   3. ∫ pdf over the support ≈ 1, by Simpson
//   4. pdf(x) == 0 outside the support
```

**(2) is the one that matters.** It ties each density to a CDF this module already tests, so a
transcription error in a published formula fails immediately. Matching a single textbook value
does not do this: an implementation can be wrong twice and still hit one point.

Two limits found while writing the chi-squared tests, both of which the harness must encode
rather than discover again:

- **Simpson at uniform steps cannot resolve an integrable singularity.** At ν = 1 the
  chi-squared density is unbounded at zero and the quadrature undershoots badly. Such cases
  are verified by (2) and by closed forms, and excluded from (3) **with the reason stated**.
- **Do not assume monotonicity in a parameter.** A test asserting that the density at ν = 2.5
  sat between ν = 2 and ν = 3 failed because the density *rises* with ν at that `x`. The
  expectation was wrong, not the code. Properties, not intuitions.

## 5. Scope and sequencing

1. Add the requirement; the build breaks with 38 named types. **This is the checklist.**
2. Add the harness, failing.
3. Work the three groups. Closed forms first — they are the bulk and the most mechanical.
4. Green harness is the completion condition.

**One release, not staged.** A protocol requirement landing without its conformers is a broken
build; conformers landing without the requirement are 38 methods nobody has to keep. They go
together or the change has no teeth.

## 6. Alternatives considered

**A default that differentiates the CDF numerically.** Everything compiles at once and every
type gains a working density immediately. Rejected: an unconverted type then ships an
approximate density that looks exact, which is this module's existing failure mode wearing a
new hat. The `chi2pdf` history is the argument — a wrong density survived because nothing
forced the question.

**A separate `HasDensity` protocol, conformed to opportunistically.** Rejected: it makes the
density optional in a family where it is definitional, and callers would have to branch on
whether a continuous distribution happens to have one.

**Leave it, and add densities as they are needed.** This is the status quo, and it produced
six densities in an unknown number of years plus one function that computed the wrong thing
for long enough to be found twice.

## 7. Recorded for the next reader

**`DistributionChiSquared.pdf(_:)` does not delegate to `chiSquaredPDF(x:df:)`**, and
`cdf(_:)` does not delegate to `chiSquaredCDF(x:df:)` either. The free functions throw on
invalid parameters and the methods have nowhere to send an error, so each method computes
directly. That is a pattern worth keeping consistent as the other 38 land: the free function
validates and throws, the method answers `nan` or `infinity`.

**The three-way split at a support boundary is not a convention.** For a chi-squared, Weibull
or gamma at zero the density is unbounded below a shape of one, finite at exactly one, and
zero above. Implementations that return zero at the boundary for all shapes are wrong in the
first case and will pass a test that only checks non-negativity.


---

## 8. What shipped, and where §3 was wrong

**The count was 44; it is 46.** `DistributionMyerson` and `DistributionGeneral` were both
miscounted — the first listed under "empirical or fitted" among "the two fitted forms" without
being named, the second not listed at all despite already having a density. The inventory was
assembled by reading, and reading miscounts.

**Two densities are numerical, and say so in their own documentation**, as §3 required:

| | Why |
|---|---|
| `DistributionMetalog.pdf` | quantile-defined, so the density *is* `1/q′(p)` — a real derivative rather than a shortcut |
| `DistributionMomentFit.pdf` | its transform is a family switch, so there is no single closed form to write |

**`Erf` and `MomentFit` were grouped together in §3 and did not belong together.** `Erf`
delegates to the normal it wraps, exactly as predicted. `MomentFit` does not delegate, because
which distribution it would delegate *to* is chosen at fit time from the moments.

### Three things the harness needed that §4 did not anticipate

**A coverage test, not just property tests.** Most of these initialisers are failable and two
throw. A subject built with `if let` and one wrong argument would have vanished from the suite
rather than failed in it — the harness would have got shorter and stayed green.
`testEveryConformerIsCovered` names all forty-six, and a `nil` becomes a subject that keeps its
name and answers `nan`, so it fails loudly instead of disappearing.

**No parameter may be 0 or 1.** Found by perturbation rather than by review: deleting
`DistributionDagum`'s scale factor from its density changed **nothing**, because the subject
was built with `scale: 1` and the dropped term was `log(1)`. A density that forgets its
change-of-variable Jacobian is off by `1/β`, and at β = 1 that error is invisible. The same
holds for a dropped location at 0 and a dropped shape term at γ = 0. Every subject now uses a
non-zero location and a scale that is neither one nor shared.

**The harness was checked by breaking things.** Three densities were deliberately perturbed —
a 2% factor, a swapped `alpha1`/`alpha2`, a dropped Jacobian — and the suite had to go red for
each. Two did immediately; the third is the Dagum case above, and it passed. A harness that
goes green on its first run has demonstrated nothing until something wrong has been shown to
make it red.

### One thing §3 caused and §7 predicted

Inserting forty-six methods mechanically split thirty-seven `cdf(_:)` doc comments in half, the
summary line going to the new `pdf(_:)` and the CDF left undocumented. The gate caught every
one. Worth stating because the repair is not the interesting part: **a bulk insertion into a
documented file damages the documentation around it**, and nothing in the build notices.

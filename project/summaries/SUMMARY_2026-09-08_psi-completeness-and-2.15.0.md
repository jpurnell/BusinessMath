# Risk Solver's distribution surface, finished — and what measurement kept overturning

**2026-09-08** · shipped **v2.15.0** at `be704795` · 7,308 tests / 650 suites ·
quality-gate `--check all` 45/45, 0 errors, 0 warnings, no suppression markers added

Twelve commits from `v2.14.0`. The coverage story is the headline, but the reusable
part is underneath it: **five times in this session a conclusion I had reasoned my way
to was overturned by an external check**, and in three of those cases the reasoning had
been sound. That is the thing worth carrying forward.

---

## What shipped

| | Rows |
|---|---|
| **LANDED** | 52 |
| **EXCLUDED** | 5 — `PsiSip`, `PsiSlurp`, `PsiTSSip`, `PsiCertified`, `PsiVary` |
| | **57**, nothing blocked, partial or unresolved |

The five are excluded because they are not mathematics: they resolve stored data or
declare a solver role, which is a spreadsheet host's job rather than a library's.
Recording *why* mattered more than the count — an earlier version of this list left them
unmarked, which reads identically to "not done yet".

Highlights: a percentile-fitting solver and the 28 `Psi*Alt` forms through it;
`DistributionStudentT` plus continuous shapes for gamma and chi-squared; EGARCH(1,1) and
APARCH(1,1); multivariate normal, resample and shuffle; sample fitting with
Anderson–Darling; compound loss with a per-occurrence deductible and limit; metalog modes
and anti-modes; `BranchAndBoundSolver.minlp(...)`.

---

## The five overturned conclusions

### 1. A quadrature that was exact where it was tested

`E(|z| − γz)^δ` was integrated on a grid. That is exact at `δ = 2`, so the test at the
GARCH corner passed and the method looked sound. At fractional `δ` the integrand behaves
like `|z|^δ` near the origin, where its higher derivatives are unbounded, and Simpson's
error falls off as `n^-(δ+1)` rather than `n^-4` — at `δ = 1.5` a grid of 800 is out by
7e-7 and doubling it buys a factor of five, not sixteen.

Splitting by the sign of `z` factors the tilt out and leaves the normal's absolute moment,
which is closed form. **What exposed it was writing the test against an exact oracle.** A
tolerance-tuned test would have passed the grid forever.

### 2. A bimodal fit that had four modes

The metalog mode-finder was tested against a two-humped target and reported four modes.
The instinct is that the detector over-reports. An independent grid scan — sharing no
derivative, no refinement, no end grid — found the same four peaks and three dips,
matching to four decimals and symmetric about zero.

The ten-term fit really is quadrimodal: forced through nineteen percentiles it oscillates
between them. **That is the case the feature exists for** — a fit that reads as reasonable
from its percentiles, carrying structure nobody elicited. The test now asserts that two
independent searches agree rather than a count decided in advance.

### 3. A doc comment that was backwards

I justified assembling a moment in logs by saying `Γ((δ+1)/2)` overflows while the moment
stays representable. Checked it: the moment overflows at `δ ≈ 301`, *before* the gamma does
at `≈ 342`. They grow together. The log form's real merit is no constant division plus
matching the library's existing `logGamma` idiom, and the comment now says that.

### 4. `PsiNormalSkew`, settled by Excel rather than by argument

Frontline's page gives the bounds as ±3σ and the tail as `2Φ(−3)` but no formula relating
the skew to the shape. The argument for a linear median was decent — the two natural
formulations coincide, and the open interval `(−1, 1)` corresponds exactly to
`median ∈ (a, b)` open. Then the user sampled it: mean ≈ 43.5, median ≈ 45, σ ≈ 9, against
this implementation's 43.4396 / 45 / 9.1147 where the alternative predicted 34.45 / 35 /
9.91.

The mean is what proved the most — it falls *below* the median, the left skew their prose
claims, and its value needs the Myerson asymmetry, the tail and the coverage all right at
once. **Argument reached a defensible answer; measurement made it true.** The map now lives
alone in `normalSkewMedian(...)` with a pinned table, so a future contradiction changes one
function body.

### 5. Where the optimizer's time actually went

`InequalityOptimizer` was suspected of burning its iteration cap generally. Measurement:
the root relaxation converges in 4 outer steps and a millisecond at *any* cap. The waste
was entirely in **infeasible and degenerate child nodes** running the full 100 ×
`maxInnerIterations` — and branch-and-bound produces those constantly.

ρ starts at 10, ×10 per escalation, caps at `1/ulp ≈ 4.5e15`, so it saturates near step 16;
after that η and ω are constant and the multipliers are not banked. Everything past it
repeats. Now: infeasible node 3.7 s → 1.6 s, 100 outer steps → 17, bit-identical answer,
converging nodes untouched at 4 and 6.

---

## The near-miss worth remembering

Inside that optimizer fix I wrote a stopping rule tested on
`max(violation, stationarity, complementarity)`. On a node whose feasible set was the
single point `(3, 0)`, **stationarity stalled while the violation was still falling**, the
maximum hid the progress, and the search stopped at a violation of 2.8e-6 that would have
reached 1e-7.

That flips a feasible node to `.infeasible` and prunes a subtree that should have been
searched — a wrong answer wearing a converged answer's clothes, invisible from outside the
search. Exactly the defect class the 2.14.0 oracle audit was built to catch, in code
written an hour earlier.

The caller's verdict is `violation ≤ tolerance` and nothing else, so that is the only
quantity whose stalling may end the search. The degenerate node is left slow on purpose:
**a node costing time is a cost; a correct node being pruned is a wrong answer.**

---

## Process

**Commit with a pathspec in a shared tree.** A *foreground* commit still swept another
session's staged rename into `affa6c91` under this session's message. `git commit` builds
from the whole index, and staging your own files with `git add` does not protect you
because their `git add` lands in the same index. `git commit -- <paths>` is the fix;
foreground versus background was never the mechanism. Recorded in
`feedback-background-commit-race`.

**The suppression markers were all avoidable.** `// stochastic:exempt` and
`// fp-safety:disable` exist in this codebase for genuine unseeded and constant-divisor
paths. Every case this release would have needed one turned out to be avoidable by reusing
something that already existed — `E|z|` became `2·normalPDF(x: 0)`, a hand-rolled uniform
became `Double.random(in:using:)`, an unseeded `random()` became the ratio construction
over two free functions that already owned that entry point. Zero markers added.

**`quality-gate --no-cache` is not enough.** It runs the default profile. `--check all` is
what runs all 45.

**A near-attribution error.** One gate run showed four `doc-run` failures in optimization
articles and the evidence pointed at a concurrent session's MINLP work. On a clean re-run
all four were gone — they were timeouts under four concurrent gate processes. The hedge
placed on that claim turned out to be the accurate half of it.

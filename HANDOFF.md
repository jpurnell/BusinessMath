# Handoff — 2026-09-11

**`3.0.0-alpha.3` is released, ten of the eleven library defects in the distribution test
review are fixed, and Bessel is unblocked.** `main` is clean and pushed. The next piece of work
is **`besselJ`**, and everything it needs is settled — start at §7 step 1 of the proposal.

## State

| | |
|---|---|
| branch | `main`, pushed, verified by `ls-remote` |
| latest stable | `v2.18.0` — what `from:` consumers resolve to |
| latest pre-release | `v3.0.0-alpha.3` |
| tests | **7,679 in 688 suites**, exit 0 |
| gate | `quality-gate --no-cache --check all --continue-on-failure` → 45/45, **0 errors**, 10 warnings |
| the 10 warnings | the `skipped-test-inventory`, which is report-only by design. Not debt to clear |
| working tree | clean except `project/plans/proposals/excel_function_coverage_matrix_bak.tsv` — **your backup, deliberately untracked, leave it alone** |

Always `--check all`. Plain `--no-cache` runs 40 of 45 and prints an identical PASSED line.

---

## What shipped this session

`v3.0.0-alpha.3` (docs-and-tests, plus the bonds fix), then seven commits of review work:

| Commit | Contents |
|---|---|
| `2034bcd7` | GPU suites: 30 silent passes → `.requiresMetalGPU` + `#require` |
| `6e4c6cb2` | 11 vacuous `guard … else { return }` → `try #require` |
| `2fe2addb` | 8 of 18 disabled tests re-enabled |
| `b0dcaf1b` | **Release `v3.0.0-alpha.3`** |
| `a38f1c18` | **#7** `timeLimit` → `Duration?` (breaking) |
| `3eca9d57` | Four cheap review findings |
| `0ab3be8f` | **#8** Beta log-space, **#10** degenerate `stdDev` |
| `8933e6a5` | **#4** Myerson `expm1`/`log1p`, **#5** PERT λ-form, **#1** residue |
| `c3134e5c` | **#6** lognormal naming, **#9** combinatorics pinned, +22 guards |
| `e2fc963c` | **#3** every sampler takes `seed:`/`using:` (breaking) |
| `70d29b1e` | **#2** the library owns its unit-interval mapping (breaking for reproducibility) |

Every one at full suite green and gate 45/45.

### The review's scorecard, honestly

**Ten of eleven fixed.** Two of its findings did not survive contact:

- **#1 was already done.** `normalCDF` has been `erfc(-x/√2)/2` since `91ca7f03`, **a month
  before the review**, and `logNormalCDF` delegates to it. The review appears to have read the
  *test file's comment*, which still described the old behaviour. What was real was the
  test-side residue: a private `accurateLowerCDF` identical to what the library does, and a
  `p >= 1e-4` fence guarding against a defect that no longer existed. All removed; the round
  trip now runs through the library CDF at `p = 1e-12` and holds to 1e-13 relative.
- **#9's conditional did not hold.** `maxFactorialInt` is 20 and both combinatorics functions
  switch to the multiplicative form above it, reaching `C(52, 5) = 2,598,960` exactly. Nothing
  needed fixing; the edges are now pinned instead, including an exit test on `factorial(21)`.

And one of its *suggestions* was wrong — see "52 bits" below.

**Still open: #11, the Metalog feasibility check.** Probed and confirmed: it rejects ε = 1e-3
and 1e-6 but **accepts ε = 1e-9 and 1e-12**. Any finite grid loses to a small enough ε; it
needs the analytic tail-slope check the review describes. The only research-shaped item left.

---

## The test-quality work, which is most of the session

### Guards that reported `passed` while asserting nothing

**63 sites, in two passes, and the second pass is the lesson.**

The first pass found 41 by grepping for `else { return }`. The second found **22 more**, because
a grep encodes an assumption about formatting and these were written across three lines:

```swift
guard let metalDevice = MetalDevice.shared else {
    return // Skip if Metal unavailable
}
```

Twelve of them were in `MonteCarloGPUDeviceTests`, **a file the first sweep never opened**. Ten
more were in four others, some with a `print(…)` before the `return` — which goes to stdout, not
to the test report.

They were found by `quality-gate`'s new `unasserted-optional-unwrap` rule, which parses the
syntax tree. **When the question is whether a construct appears anywhere, a parser is the oracle
and a grep is a hint.** Three counts in this session were wrong for exactly this reason; this is
the one that mattered, because I had already reported "41 sites, all converted" with confidence.

The fix has two halves, and the split matters:

- **A `nil` that means "no GPU on this machine" is a legitimate skip**, and `try #require` would
  be *worse* than the guard — it turns "no hardware" into a failure. Those moved to a new
  `.requiresMetalGPU` trait, so Swift Testing reports **skipped** rather than **passed**.
- **A `nil` that means "the fixture is empty" is a defect.** Those became `try #require`.

`.requiresMetalGPU` tests device **and** runtime shader compiler, because those are two different
absences and only one is benign: no `MTLDevice` means skip; an MSL compiler that rejects our
source has found a bug and must fail.

**Verified by negative control, not by the green run.** With the probe forced to `false`, all 28
tests report `skipped` with a reason in 0.001s against 0.499s when they execute. A probe stuck at
`false` would also have printed green — and would have been strictly worse than the guards it
replaced.

### Disabled tests: 18 → 10

Two `PeriodTests` were disabled because *"precondition() failures cannot be caught in Swift
Testing"*. True when written; untrue since the framework gained exit tests. Both are now
`#expect(processExitsWith: .failure)` and both pass. What stood in for them is this sweep in
miniature: two `withKnownIssue` blocks wrapping calls that never executed, closed by an
`#expect(true)` added to satisfy a checker.

Six benchmarks moved from `.disabled()` to the `.benchmarkOnly` trait the repo already had —
five carried a bare `.disabled()` with **no reason at all** — and all of them pass under
`RUN_BENCHMARKS=1`. The `.disabled()` was concealing working tests.

**Ten remain, three blocked on product defects** (`AdditionalModelTests` ×2 need rate/capacity
validation; `MonteCarloGPUIntegrationTests:723` is a GPU initial-run defect). Filed, not fixed.

### Tests that could not fail, or were carried by their seed

- **`betaIndependence`** compared a raw product moment with 0.25 at a 0.05 bound. Beta(2,2) has
  variance 4/(16·5) = 0.05, so `E[X₁X₂] = 0.25 + 0.05ρ` and the assertion reduces to `|ρ| < 1` —
  true of every correlation that can exist. Replaced with a normalised lag-1 autocorrelation
  against 4/√n.
- **`normDist`** asserted `0.00621 ± 1e-6`. That is Φ(−2.5) to three significant figures, sitting
  3.35e-7 from the truth — inside the bound by luck, and capping the achievable tolerance six
  orders of magnitude short. Now the full-precision reference at **1e-15**, which passes.
- **`coxProcessVolatility` asserted something false.** It claimed higher intensity volatility
  widens the *relative* spread of default times. True for an intensity drawn once per path; false
  here, where the intensity steps along a grid and integration averages the volatility out.
  Measured over 5,000 paths: CV is 1.02, 1.00, 1.00, 1.00, 1.01 across σ = 0.05…3.00 — **no
  trend** — while the mean falls 49.7 → 2.2, a 22× effect. It compared two CVs a fifth of a
  percent apart and passed on whichever side of the noise the stream fell.
- **`posteriorICCMatchesFrequentist` was absorbing sampler variance.** Its 0.05 bound was "a
  twentieth of the range". On one chain, `raterEffect_large` ranged −0.024 to −0.079 across five
  seeds. Now `chains: 4` (range −0.029…−0.048, the mechanism `GibbsConfig` already had), asserting
  the **sign** — a vague prior shrinks downward, 20 of 20 measurements negative — and bounding the
  magnitude at 0.08 *from that measurement*.
- **`MetalogShapeTests` indexed `d.antiModes()[1]` unguarded.** An out-of-range subscript is a
  trap, and a trap takes the **whole test process** down rather than failing one test.

### Three defects found by tests I wrote for something else

- **Rayleigh and Pareto disagreed with their own types about which way a quantile runs.** The free
  functions decreased in their argument; `DistributionRayleigh.quantile` and
  `DistributionPareto.quantile` increase. Nothing caught it because the only argument both forms
  were ever tested at was **u = 0.5, where `u` and `1 − u` are the same number**. The review names
  this hazard in §4.1 — and its own suggested `mediansAtHalf` test *passes on the broken code*. It
  was the grid that caught Rayleigh and the free-function-versus-type identity that caught Pareto.
  That identity is now asserted across all five families over eleven probabilities.
- **The unit-interval mapping was closed at the top.** See below.

---

## 52 bits, not 53 — the review's suggested formula is wrong

`(Double(x >> 11) + 0.5) * 0x1p-53` is the form the review gives and the form most references
give. It returns **exactly 1.0** on an all-ones word: the largest shifted word is `2⁵³ - 1`,
adding `0.5` needs a 54th significant bit, and the sum rounds ties-to-even up to `2⁵³`. **The
half-cell offset that opens the bottom of the interval closes the top**, and `boxMullerSeed`
through it produced a radius of `-0.0` — the pole the function exists to make unreachable,
reached on the first draw.

At 52 bits the arithmetic is exact and the endpoints are `2⁻⁵³` and `1 - 2⁻⁵³`.

**It was found by printing the value, not by reading the formula.** Nothing in the derivation
looks wrong. `OpenUnitUniformTests` now demands both endpoints from a rigged generator and
confirms ten million real draws never reach either.

**Seeded streams changed.** The distributions are identical; the variate at a given seed is not.
Anything recorded against a seed will differ.

---

## Next: Bessel — unblocked, start at step 1

`project/plans/proposals/excel-coverage/PROPOSAL_bessel_functions.md` — a full design proposal
from the other session. **Read §5 (numerical design) and §6 (test strategy) before writing
anything**; §7 is the work breakdown.

Four functions — `besselJ`, `besselY`, `besselI`, `besselK` — in
`Sources/BusinessMath/Statistics/SpecialFunctions/`, one file each, generic over `T: Real`,
returning `T.nan` for invalid input, matching every other file in that directory.

**The proposal argues this is 3.1.0, not 3.0.0** (§8). Nothing here blocks the release.

### The negative-`X` question is settled: parity

Measured 2026-09-11 at **odd** order, which is the only order that can discriminate:

| Cell | Excel returned | parity `(−1)ⁿfₙ(\|x\|)` | absolute value `fₙ(\|x\|)` |
|---|---|---|---|
| `=BESSELJ(-1.5,1)` | **`-0.557936508`** | `-0.5579365079` ✓ | `+0.5579365079` ✗ |
| `=BESSELI(-1.5,1)` | **`-0.981666428`** | `-0.9816664286` ✓ | `+0.9816664286` ✗ |

Both negative. The absolute-value rule predicts positive in both cases, so this is settled by
**sign, not by tolerance** — no interpretation required.

**What to write:** for `x < 0`, evaluate at `|x|` and multiply by `(−1)ⁿ`. One line at the top
of `besselJ` and `besselI`. Nothing for `besselY` and `besselK`, which refuse `x ≤ 0` outright
and never meet the question.

**One loose thread, not blocking.** `BESSELJ` matched to all nine printed digits. `BESSELI` came
back `-0.981666428` where correct rounding of `−0.9816664285779…` gives `-0.981666429` — one
unit low in the last place, ≈ 5.9 × 10⁻¹⁰ relative. Display truncation or a real Excel error;
either way it is tighter than the `3 × 10⁻⁸` the even-order cells suggested. §3.2's question
stays open with a better bound. **The tests never depended on Excel** (§6 uses published
references and identities), so this changes nothing about how to proceed.

### Order of work

§7: **step 1 `besselJ`** (hardest — series/asymptotic J₀ and J₁, then the two-direction
recurrence of §5.2; everything after reuses its structure), then Y, then I, then K, then
`BesselFunctionsTests` (§6's three layers — published references, identities that share no code
path with the implementation, boundaries), then the SwiftExcelFunctions binding, which is
mechanical and **belongs to the other session**.

§9 leaves two open questions, neither blocking: confirming Excel's precision with `TEXT()`, and
whether `order` should be `Int` everywhere — proposed yes, and worth one look before four
signatures are committed to.

## After Bessel

1. **#11, the Metalog feasibility check** — the last library defect, and the only one that is
   research rather than mechanics.
2. **The test audit continues.** The review's §5 has a per-file disposition for all 40
   distribution test files; §6 phases 4–5 are a rewrite of ~20 of them onto shared helpers, and
   that is the bulk of the remaining work. §3.2's helper promotion (distribution contract, KS,
   standard-error tolerances, sample statistics) comes first because everything else sits on it.
3. **§3.4's TestSupport module split was deliberately deferred** — speculative generality. Its
   stated payoff is serving BioFeedbackKit and YahooFinanceKit, neither of which consumes it, and
   real sharing needs a published package, not a target split. Revisit when a second consumer
   exists.
4. **3.0.0 final** whenever you want it — docs-only, no technical blocker.

---

## Traps, in the order they bite

**A grep is not a parser.** It missed 22 guard sites across five files because they were written
across three lines. Three counts in this session were wrong from the same cause.

**`quality-gate --check` takes ONE checker per flag.** `--check a,b,c` prints *"No checkers
enabled. Nothing to do."* and **exits 0**. Indistinguishable from a clean pass unless you grep for
evidence the checkers *ran* — the `✓ [name] PASSED (…s)` lines and the `N of 45 checkers` count.

**`doc-run` timeouts are artefacts; re-run, do not believe the number.** One failed at load 14
taking 150s and passed 79/79 at load **484** taking 39s. The load average does not predict it —
momentary contention does. Under a zero-warnings policy, believing it means a permanent wrong edit
to a DocC article that was never broken.

**Two concurrent `swift build`s on one `.build` produce phantom errors.** An
`invalid redeclaration of 'cachedCalendar'` appeared in two committed, untouched files. The tell is
that neither session edited the file named. Check `ps aux | grep swift-frontend` before believing a
diagnostic about code you did not write.

**Measure before setting a bound.** The first PERT shape test passed against the broken code: its
mode positions were round numbers, and the damage sits in a narrow band immediately outside the
`1e-12` guard (2.5e-4 relative at `centrality = 7e-12`). A method wrong in a band is exact at every
point you happen to pick.

**Arithmetic inside an array literal fed through `@Test(arguments:)` kills the type checker.** Six
expressions like `5.0 - 3.5e-12` in one literal failed on the **local** 6.4 compiler. Precompute to
decimal literals in an explicitly-typed `[Double]` bound to a named static.

**Budget nine minutes for a commit and a push.** Both hooks run the gate. Never background a commit.

**`git commit -- <dir>` is safe; `git add <dir>` is not.** The first only stages tracked
modifications; the second swept the untracked backup into a commit once. New files still need an
explicit `git add -- <file>`.

**A gate run from inside `.claude/worktrees/` examines ZERO files and prints PASSED.** Check the
file count — a real run reports ~1,240.

**No suppression markers, ever.** Zero added across this session.

---

## Cross-session context

**SwiftExcelFunctions** is a peer session and cannot reach this tree. The lane is settled:
**mathematics here, spreadsheet argument semantics there.** It landed `b1257e89` (the coupon
time-zone fix), `786894b9`, `8f9f4edb` and `fc49aa1b` during this session, and it is pursuing the
`quality-gate` checker changes (§4.9) independently — **do not do those here**.

It also shipped `unasserted-optional-unwrap` and `skipped-test-inventory` into `quality-gate`
mid-session, which is what caught the 22 guards. Expect the checker to keep gaining rules; a gate
that suddenly fails on untouched code may be a new rule rather than a regression.

---

## How this work has been done

**Verify against an identity, not a fixture.** The free function against the type's own quantile
found two inverted conventions. The λ-form against the mean-based form found four lost significant
digits. Gamma as a sum of exponentials on one stream. Neither side of an identity can be the thing
under suspicion.

**Write the stub.** *What is the simplest wrong implementation that still passes this?* An
availability probe stuck at `false` passes a green GPU run. A fitter returning its starting point
passes "fitted error ≤ defaults". A solver that expires on every budget passes "a tight budget
expires" — only pairing it with "a generous budget completes" says the deadline is real.

**Print the value.** The 53-bit mapping bug, the 22.375% Beta fallback rate, the 4.89e-6 Myerson
error, the 2.5e-4 PERT error and the ICC chain variance were all found by measuring, and none of
them by reading.

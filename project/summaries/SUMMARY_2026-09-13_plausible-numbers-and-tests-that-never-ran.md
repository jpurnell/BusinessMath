# Numbers shaped like the right answer, and tests that were green without running

**2026-09-10 to 2026-09-13** · shipped **v3.0.0-alpha.4** (tag on `3469ae38`) and
**v3.0.0-alpha.5** (tag on `82bff1ee`, one commit past this range, which ends at `07d7d2bd`) ·
7,756 tests / 696 suites, exit 0, one known issue, at `9a7164e1` · quality-gate 45/45, 0 errors,
as last recorded at `4b666601`

Reconstructed on 2026-10-05 from the git history and the CHANGELOG; it is not a contemporaneous
note.

Forty-eight commits from `v3.0.0-alpha.3`. Two things recur across them and are the part worth
carrying forward. The defects that mattered returned **a plausible number where the answer was
wrong or undefined**, and several tests that should have caught them were **green without having
executed the code they name**.

---

## What shipped

**alpha.4** (through `3469ae38`): `timeLimit` became `Duration?` with `nil` as the absent budget
(`9710afb3`); ten of the eleven library items in an external distribution test review were
worked, two of which turned out not to be defects; the lognormal samplers were respelled
`logMean:`/`logStdDev:` (`a62fde1d`); the five inverse-transform families gained `quantileAt:`,
`seed: UInt64?` and `using:` (`d6c829a0`); `openUnitUniform(_:using:)` became the one public
unit-interval mapping (`b169e689`); `besselJ`, `besselY`, `besselI`, `besselK` landed
(`6735df37`); the repository gained an AGPLv3 `LICENSE` and `LICENSING.md` (`80d7809f`); and
`project/library` was removed and gitignored (`3469ae38`). The alpha.4 tag message records that
the path was excised from all history with `git filter-repo` on 2026-09-12 and that the 20 tags
which had contained it were deleted rather than re-pushed.

**alpha.5**: phase 1 of the simulation test review (`88af88d7` through `e417c78b`), a
`TEST_REVIEW_ROADMAP.md` built from twenty-two external test reviews, and the first five items
of its fix track: days outstanding (`4b666601`), UTC periods (`0ade4800`), the Sharpe ratio at
zero risk (`5844c59a`), `bayes` generic with `bayesChecked` (`1fc773b4`), and the cut counters
(`9a7164e1`).

alpha.4 has no CHANGELOG heading. `07d7d2bd` records why: the tag was cut while `[Unreleased]`
still spanned alpha.3 to HEAD, and the section became alpha.5 with a note saying so rather than
being split after the fact.

---

## Plausible numbers where the answer was wrong

**DIO of 91.25 days in a 91-day quarter.** DSO, DIO and DPO divided 365 by a per-period turnover.
On the quarterly documentation fixture the answer is 91/4 = 22.75, so the result was out by 4.01
times, and it sat a quarter-day from the length of the quarter, which is why a sanity check passed
it. The cash conversion cycle identity could not see it because the day count cancels there. The
functions now take `dayCount: DayCountConvention = .actual365`. The external review had filed
this as an open convention; reading the source showed it was a dimension error.

**Beta returned its mean on 22% of draws.** At `a = b = 0.001` both gamma variates underflow, the
ratio is 0/0, and a guard returned `a/(a+b)`: 22.375% of 20,000 seeded draws came back as exactly
0.5, close to the one value that distribution never produces. Shapes below 1 now run in logs
(`74b2efbe`).

**An antithetic standard error that showed no reduction.** `MonteCarloEngine.price` pooled 2N
negatively correlated paths as independent. Over 200 seeds, reported over realised spread was
1.449 before and 1.079 after. The guarding test, `antiSE < plainSE`, held on 109 of 200 seeds.
The review had filed this as a test-quality item; measurement made it a library defect
(`88af88d7`). Its replacement includes an exact oracle, a payoff every antithetic pair averages
to a constant.

**The same family elsewhere.** `sharpeRatio` returned 0 for positive excess return at zero risk;
the bytecode optimizer rewrote `a * 0` to 0 for infinite and NaN `a`, and folded `1/0`, `sqrt(-1)`
and `log(0)` that the interpreter throws on (`0195cf31`); `J_1000000(1000000)` came back as
0.00035973 against 0.00447307 because a runaway-loop backstop of 1,000,000 had become a bound on
the Miller seed order (`5365e270`). That last one was found by plotting `J_n(n) * n^(1/3)` against
its Airy limit while measuring something else, not by checking a value.

## The unit-interval mapping, twice

The distribution review suggested `(Double(x >> 11) + 0.5) * 0x1p-53`. That returns exactly 1.0
on an all-ones word, because the `+ 0.5` needs a 54th significant bit and rounds up, and
`boxMullerSeed` through it produced a radius of -0.0. It was found by printing the value. The
shipped mapping uses 52 bits (`b169e689`). Seeded streams changed; the distributions did not.

Two days later `distributionUniform` turned out to round every draw down onto a lattice of ten
million points, which sent one draw in ten million to exactly 0.0 and so reopened the endpoint.
`distributionGeometric` took `log` of it and then `Int(_:)` of an infinity: a trap, exit 133,
confirmed in isolation (`292868a3`).

## Green without running

- **All three exit tests under ThreadSanitizer.** The child process aborts in sanitizer start-up
  before the closure body runs, and the abort satisfies `processExitsWith: .failure`.
  `.requiresUnsanitizedRuntime` now skips them there (`1d927726`). It surfaced only because
  `bb05023a` was the first test to read an exit-test child's stderr.
- **Twelve of twenty-nine GPU tests.** `MonteCarloGPUDevice` compiles its kernel in a failable
  initializer, and seventeen `guard ... else { print; return }` sites reported a pass when the
  package's own kernel failed to compile. Breaking the generated MSL on purpose gave 4 failures
  before and 16 after (`9f661666`). `4df8a678` had said the whole GPU surface went green; that
  commit corrects it.
- **`Phase1_CutValidityTests`.** Sixteen of seventeen fixtures minimise to an integral origin and
  solve in one node with no cut (`60def128`).
- **Twenty-two guards a grep missed.** alpha.3's sweep matched `else { return }` on one line; the
  gate's AST-based rule found twenty-two more across five files (`a62fde1d`).

## A trap the optimiser is entitled to delete

`_ = factorial(21)` trapped in debug and exited 0 in release: once inlined with the result
discarded, the multiply and its overflow check are dead code. Release Tests was red on both
platforms from `b169e689` until `factorial` stated `n <= maxFactorialInt` as a precondition
(`bb05023a`). The same reasoning decided the GPU error design in `e417c78b`: the kernel tests the
operand before the operation rather than inferring an error from an IEEE result, and the contract
suite passes under `.fast` and `.safe` math alike. A batch with a failed iteration now throws
`GPUError.iterationsFailed` unless `onIterationError: .collect` is passed.

## Oracles and reviews have error budgets too

The Bessel fixtures come from mpmath, not SciPy: SciPy's own error reaches 3.636e-12 on
`J_200(2000)`, so a SciPy fixture at 1e-12 fails a correct implementation. Validation was 59,928
argument-order pairs at 30 digits, worst 1.8e-13 (`6735df37`). The first Excel probe for negative
arguments was taken at even order, where parity and absolute value agree; the odd-order cells
settled it by sign.

The external reviews were accurate in their arithmetic and wrong in specific claims, and the
validation commits record both. The erfc `normalCDF` item was already fixed and was carried from
one review into the next. Corpus-wide counts ran 2.1 to 13.1 times the best single-review figure,
because each review counts within its own domain (`2e29a9a0`). And of the ten library defects
found by then, a static gate rule would catch three outright and miss five entirely
(`de231895`), which is why the roadmap was re-sequenced into block, document and after.

---

## Process

**`gh run view --job --log` truncates at about 9.5 MB.** With `-v` the log ends mid-build on
passing runs too, and was twice read as a hung build. The complete log comes from
`gh api repos/<owner>/<repo>/actions/runs/<id>/logs`. Compare against a passing run first
(`1d927726`).

**A runtime trait does not make code compile.** `.requiresMetalGPU` decides whether a test
executes; on Linux the Metal symbols are absent, so the guard has to be `#if canImport(Metal)`.
Both Linux jobs went red at `49813407` while macOS passed (`1bfbbde9`).

**`swift.yml` does not run the suite in release.** Release Tests is scheduled, so that class of
defect is invisible to per-push CI (`bb05023a`).

**Three retractions were written down rather than absorbed.** The GPU computing `0 / 0` as 1.0
was a fast-math artefact of a probe that wrote `v / v` (`f5b4454e`). "Cutting planes are inert"
was a discarded counter: four of five return paths built an empty `CuttingPlaneStats()`
(`9a7164e1`). And the alpha.3 coupon defect was a change of UTC offset, not a position west of
Greenwich (`d1f8eecb`).

**A re-expression is safe only if the arithmetic provably did not move.** Three routines that
followed *Numerical Recipes* line for line were rewritten against the primary sources and
checked as raw bit patterns over 60,048 results, with none differing (`11262208`).

---

## Not done

- The CHANGELOG's alpha.5 section has no entry for the simulation phase-1 work: the antithetic
  standard error, the lattice, the optimizer rewrites, the GPU contract, or the breaking
  `onIterationError:` change. None of `88af88d7` through `e417c78b` touched `CHANGELOG.md`.
- `cuttingRounds` and `totalCutsGenerated` count different things; recorded as `withKnownIssue`.
- `Phase1_CutValidityTests` is not yet rewritten around the counters that now work.
- The `twoAssetConstant` portfolio fixture is still riskless, leaving `optimizerBeatsEqualWeights`
  and `frontierMonotonicReturn` vacuous.
- `MonteCarloCommon.h` remains a hand-maintained mirror that nothing checks, and the kernel's
  equality epsilon is `1e-6f` against the interpreter's `1e-10`.
- Roadmap threads T1 to T7, the sweeps and the gradient certificate were moved to after 3.0.0.
- Proposals only: correlated inputs (`7224efc1`), and the Bessel `SwiftExcelFunctions` binding.

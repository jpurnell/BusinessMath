# Handoff — 2026-09-11 (later)

**The four Bessel functions are implemented, tested and gate-clean.** CI is green on `e45eeb1c` — all four jobs, including the Linux release compile check that catches Swift 6.2.x generic type-check timeouts. Steps 1–5 of the design
proposal are done; step 6 is the SwiftExcelFunctions binding and belongs to the other session.
With this, **Excel's engineering block contains no mathematics BusinessMath does not have.**

The next piece of work is **defect #11, the Metalog feasibility check** — the last open library
defect from the distribution test review, and the only one that is research rather than
mechanics.

## State

| | |
|---|---|
| branch | `main` |
| latest stable | `v2.18.0` — what `from:` consumers resolve to |
| latest pre-release | `v3.0.0-alpha.3` |
| tests | **7,700 in 689 suites**, exit 0 (was 7,679 in 688) |
| gate | `quality-gate --no-cache --check all --continue-on-failure` → 45/45, **0 errors**, 10 warnings, exit 0 |
| the 10 warnings | pre-existing `non-strict-improvement` notices in other suites (`DEACertificateTests`, risk, forecasting). **Not** the skipped-test inventory, as the previous handoff said — same count, different checker. Unchanged by this work |
| working tree | clean except `project/plans/proposals/excel_function_coverage_matrix_bak.tsv` — **your backup, deliberately untracked, leave it alone** |

Always `--check all`. Plain `--no-cache` runs 40 of 45 and prints an identical PASSED line.
A real run reports **1,258 files**; a run from inside `.claude/worktrees/` reports 0 and passes.

---

## `Release Tests` is green again — root cause found and fixed

**Was red on both `ubuntu-24.04` and `macos-26` since `70d29b1e`** (2026-09-11 10:43), on
`factorialBeyondIntTraps`, reporting `.failure: Testing.ExitStatus → .exitCode(0)`.

**It was never about the workflow flags.** `release-tests.yml` runs a plain `swift test -c
release` — no `-Ounchecked`. The cause was that `factorial`'s trap was *incidental*:

```swift
public func factorial(_ n: Int) -> Int { ... (2...n).reduce(1, *) }
```

An overflow check guards an arithmetic **result**. Once `factorial` is inlined and the caller
discards that result, the optimiser may delete the multiply and its check together. Measured:

| | result discarded | result used |
|---|---|---|
| optimiser cannot inline (`-Onone`, separate module, no `-wmo`) | traps | traps |
| inlined (same file, or `-O -wmo`) | **exits 0** | traps |

`_ = factorial(21)` is the discarded case, and SwiftPM's release build inlines. Debug does not,
which is why the suite was green locally and red in one scheduled workflow.

**The contract was never written down.** Two places in the repo stated it and disagreed, and
neither was right:

- the API doc: *"For n > 20, this function will overflow … and **return incorrect results**"* —
  C semantics, not Swift's. It never returned anything for `n > 20`.
- the test: *"factorial(21) **traps** rather than returning a wrapped value"* — true only when
  the result is consumed.

**Fix:** `factorial` states the bound as a `precondition`. That is an effect in its own right,
survives inlining with a discarded result, traps at the boundary rather than part-way through
the reduction, and names `factorialChecked(_:)` / `factorialDouble(_:)` in the message. Both
docs corrected. `n ≤ 20` is unchanged, as is `factorial(-5) == 0`; every in-package caller
(`combination`, `permutation`, `factorialChecked`, `Int.factorial()`) guards on
`maxFactorialInt` or forwards, so none reaches it.

**Verified all four ways, locally, in the real package:**

| | debug | release |
|---|---|---|
| without precondition | passes¹ | **`.exitCode(EXIT_SUCCESS)`** — the CI failure, reproduced |
| with precondition | passes | passes |

¹ …and *now* fails, because the test also asserts the trap message. That assertion is gated
`#if DEBUG`: `precondition(_:_:)` takes its message as `@autoclosure () -> String`, and in `-O`
the whole call becomes `Builtin.condfail_message(error, "precondition failure")`, so the
caller's message is never evaluated — stderr is empty in release, measured. Without the gate,
removing the precondition goes unnoticed in debug and surfaces only in a workflow that runs
twice a day.

**Note for whoever runs this next:** `swift.yml` does not run the suite in release, so this
class of defect is invisible to per-push CI. `Release Tests` is scheduled, not on-push.

### And the same workflow's Thread Sanitizer job turned up a second, larger thing

TSan went red immediately after the above. **It was not the Bessel work and not the
precondition — it was the stderr assertion, which found something true of the whole package.**

`#expect(processExitsWith:)` re-launches the test executable as a child. Under a sanitizer that
child does not inherit the `DYLD_INSERT_LIBRARIES` entry that installs the interceptors, so it
aborts in sanitizer start-up — *"Interceptors are not working … ThreadSanitizer is loaded too
late"* — **before reaching the closure**. The abort is a non-zero exit, so
`processExitsWith: .failure` was satisfied **by the sanitizer killing the child**.

All three exit tests in the package were green under TSan having executed none of the code they
name: `factorialBeyondIntTraps` and both `PeriodTests` exit tests. The `PeriodTests` pair is the
sharper case — they were re-enabled a session earlier *because* they had been standing in with
`withKnownIssue` + `#expect(true)`, "an assertion that holds whatever the code does". Under TSan
they still did.

`.requiresUnsanitizedRuntime` (in `Tests/TestSupport/ConditionTraits.swift`) now skips them
there, on the same principle as `.requiresMetalGPU`. Verified: runs in debug, **skips with a
reason** under `--sanitize thread`.

**Reading CI logs: `gh run view --job --log` truncates at ~9.5 MB and these jobs use `-v`.**
Every compiler invocation is a ~6 KB line, so the log ends about 100 seconds in, mid-build, on
**passing runs too**. That truncation cost this investigation two wrong conclusions — first that
the build had hung, then that the absence of an error message was meaningful. The fix is to pull
the archive instead, which contains the complete per-step logs:

```
gh api repos/<owner>/<repo>/actions/runs/<id>/logs > run.zip && unzip run.zip
```

The real message — all 7,700 tests ran, one issue, with the ThreadSanitizer diagnostic quoted in
full — was 25 MB into that step's log, well past where the truncated view stopped. **Compare
against a passing run's log before reading anything into the shape of a failing one.**

---

## What shipped this session

Five source files and one test file, all new. Nothing existing was modified.

| File | Contents |
|---|---|
| `Statistics/SpecialFunctions/BesselKernels.swift` | the pieces J/Y/I/K share |
| `…/besselJ.swift` | series, Miller downward, Hankel asymptotic + upward |
| `…/besselY.swift` | Temme series, Steed continued fraction, Hankel asymptotic |
| `…/besselI.swift` | one ascending series, at every argument and order |
| `…/besselK.swift` | Temme series, Steed continued fraction, recurrence on `e^(+x)·K` |
| `Tests/…/BesselFunctionsTests.swift` | 20 tests: reference, identity, boundary, regression |
| `Scripts/reference-fixtures/generate_bessel.py` | the fixture generator, **mpmath not SciPy** |
| `Tests/…/Fixtures/besselFunctions.json` | 696 cases |

### The method is not the proposal's, and the difference is measurable

§5.3 recommended ascending series below a crossover and Hankel asymptotic above. Those carry
`ε·e^x` and `e^(−2x)`, which move in **opposite** directions, so a single crossover has a floor:
about 1e-11 for Y at its best, against §6.4's requirement of 1e-12. For K there is no workable
crossover at all — its series cancels against a quantity `e^(2x)` larger than the answer and is
spent by x ≈ 4, while its asymptotic is not accurate until x ≈ 20.

Y and K use **Temme's series and Steed's continued fraction**, which converge rather than being
asymptotic, so there is no band between them. Integer order is what makes this cheap: Temme's
μ-dependent factors, including the Chebyshev fit for `1/Γ(1±μ)` the method normally carries, are
all exactly 1 at μ = 0, leaving only γ.

§5.3's stated *principle* — no coefficient tables, thresholds derived from `T.ulpOfOne` — is
what the implementation follows. The asymptotic crossover is literally `−log(ulpOfOne)/2`.

Full write-up in **§11 of the proposal**, which is new.

---

## The finding that would have cost the most

**SciPy is not accurate enough to be the oracle for this family, and every other fixture in this
repository comes from SciPy.**

| Point | SciPy's error | Ours |
|---|---|---|
| J₂₀₀(3000) | 1.781e-12 | 4.9e-17 |
| J₅₀(1000) | 3.481e-12 | 2.7e-16 |
| J₂₀₀(2000) | 3.636e-12 | 2.0e-15 |

A fixture generated from SciPy and asserted at 1e-12 fails a **correct** implementation, and the
only repair would be to loosen the tolerance until it said nothing. This is §3.3's argument about
Excel arriving from an unexpected direction — SciPy is a tuned approximation too, just four orders
better than Excel's `3e-8`.

**It nearly went the other way.** The first SciPy sweep reported J at 1.45e-12, over the bar, and
that was about to be chased as our defect. `BesselFunctionsTests` now carries a regression at
J₂₀₀(3000) so the next person to reach for `spec.py` finds out here.

---

## A fifth defect, found after the first commit

`e45eeb1c` shipped with Miller's seed-order search bounded by `besselIterationLimit` — a shared
runaway-loop backstop of 1,000,000, not a bound on this quantity. At order 1,000,000 the search
*begins* past that ceiling, so the loop never ran and the seed came back as the turning point
itself: **J₁₀₀₀₀₀₀(1000000) = 0.00035973 against a true 0.00447307**, wrong by a factor of twelve
at exactly the right magnitude. Fixed in the follow-up commit; the ceiling is now relative to
`n`, and a non-converging search returns `nil`, which surfaces as `T.nan` rather than a
plausible number.

**Behaviour below order ~950,000 is byte-identical** — the ceiling was never reached there — so
the 59,928-point sweep, which stopped at order 200, is unaffected and was not re-run.

Worth keeping for how it was found, because none of the existing checks would have: not by a
tolerance at scattered points, but by plotting Jₙ(n)·n^(1/3) against its Airy limit of
0.4473085 and watching a ratio that held at 0.9999974 for every order to 300,000 collapse to
0.080 at 1,000,000. **Asking whether a family follows the curve it should is a different
question from asking whether a value is right, and it is the one that caught this.**

The regression test asserts identities rather than a stored value. Note which ones have teeth:
the three-term recurrence looks obvious and is nearly worthless here, because Miller's output is
*a* solution of that recurrence and a truncated seed can satisfy it. The Wronskian against Y is
sound — Y at that argument comes from the Hankel asymptotic and an upward recurrence and shares
no code with Miller.

---

## Validation actually performed

- **59,928 argument-order pairs** against mpmath at 30 digits — 681 arguments from 1e-6 to 3000,
  including both sides of every method boundary, crossed with 22 orders from 0 to 200, for all
  four functions and both parity paths. **Zero exceedances of 1e-12**; worst 1.8e-13.
- Run **twice**: against the `Double` prototype, then against the shipped generic code, which is
  not the same program. They differ in 784 of 89,892 values, all by one or two ulp.
- **Negative control on all four regression tests.** Each defect was reintroduced and the test
  claiming to catch it was confirmed to fail. Two identity tests — the ordinary Wronskian and the
  sum of squares — caught the Miller defect independently, without being written for it.

`mpmath` is not installed system-wide and pip refuses the managed environment. The venv used is
`Scripts/reference-fixtures/.venv` per `requirements-bessel.txt` (new); the sweep harness is in
this session's scratchpad and is not committed.

---

## Two errors found in the proposal's own reference table

Corrected in place in §10, and asserted correctly in the tests:

| Entry | Proposal said | Correct |
|---|---|---|
| Y₂(1.5) | `−0.9321937507` | `−0.9321937598` |
| K₂(1.5) | `0.5836559627` | `0.5836559633` |

§1 of the same document gives Y₂(1.5) as `−1.1194180169`, which agrees with neither and is simply
wrong. The table's header claims it was "cross-checked against each other through the three-term
recurrences"; it was not — the recurrence is what exposes it, giving
`Y₂ = (2/1.5)·Y₁ − Y₀ = −0.932193759763`.

---

## Next, in order

1. **Decide what `factorialBeyondIntTraps` should do in release** — see the section above.
   It is the only thing keeping `main` red, and it is a one-line repair once the intent is
   settled.

2. **Defect #11, the Metalog feasibility check.** The last open library defect. Probed and
   confirmed: it rejects ε = 1e-3 and 1e-6 but **accepts ε = 1e-9 and 1e-12**. Any finite grid
   loses to a small enough ε; it needs the analytic tail-slope check the review describes.
3. **The test audit continues.** The review's §5 has a per-file disposition for all 40
   distribution test files; §6 phases 4–5 rewrite about 20 of them onto shared helpers, and that
   is the bulk of the remaining work. §3.2's helper promotion comes first because the rest sits
   on it.
4. **3.0.0 final** whenever you want it — docs-only, no technical blocker. Bessel does **not**
   block it: the proposal's §8 places it in 3.1.0, and it is purely additive.
5. **§3.4's TestSupport module split stays deferred** — speculative generality, no second
   consumer.

`master_plan.md` Priority 2 still read *"none of them started"* for three items Current Status
has listed as shipped since 2026-09-09. Struck through with the correction rather than deleted.

---

## Traps, in the order they bite

**An oracle is a measurement, not an authority.** SciPy at 1e-12 and Excel at 3e-8 are both
tuned approximations. When your code disagrees with a reference, establish which one is wrong
before changing anything — a 40-digit third opinion settles it in minutes.

**`T: Real` has no float literal.** It refines `FloatingPoint`, not `BinaryFloatingPoint`, so
`T(0.5)` does not compile and neither does converting a `T` to an `Int`. `LMEDiagnostics.swift`
gets away with `T(0.375)` only because it adds `where T: BinaryFloatingPoint`. Every constant in
`SpecialFunctions/` has to be derived.

**A rescale factor should be a power of two.** Dividing by `2^k` is exact, so rescaling a
recurrence costs nothing; the `1e10` this started with spent an ulp per rescale, and at x = 3000
there are enough rescales for that to show.

**A runaway-loop backstop is not a correctness bound.** `besselIterationLimit` is 1,000,000 and
was used to cap a search whose answer *starts* near `n`. Any cap that a legitimate input can
reach has to be relative to the input, and a search that does not converge must report that
rather than return its ceiling.

**Evaluate at the ends of the type, not just at plausible arguments.** Three of the four defects
were at `leastNonzeroMagnitude` or `greatestFiniteMagnitude`, where halving flushes to zero and
`πx` overflows before `x` does. None would have been found by reading the algorithms.

**A function can leave the representable range and come back.** K₀(800) underflows to zero, so a
recurrence seeded from it returns zero forever — but K₁₂₀₀(800) is 6.7e-6. Overflow screens that
assume monotonicity in the order are wrong for K.

**`quality-gate --check` takes ONE checker per flag.** `--check a,b,c` prints *"No checkers
enabled. Nothing to do."* and **exits 0**.

**The gate rejects `==` on floating-point operands** against a non-zero literal, including
`== 1.0` and `== -Double.infinity`. Use `isEqual(to:)` when the comparison is deliberate — which
for an exact boundary value it is. `== 0.0` is permitted.

**Budget nine minutes for a commit and a push.** Both hooks run the gate. Never background a commit.

**`git commit -- <dir>` is safe; `git add <dir>` is not.** New files need an explicit
`git add -- <file>`.

**A grep is not a parser.** Still true; it is how 22 guard sites were missed last session.

**No suppression markers, ever.** Zero added across this session.

---

## Cross-session context

**SwiftExcelFunctions** is a peer session and cannot reach this tree. The lane is settled:
**mathematics here, spreadsheet argument semantics there.** Step 6 of the Bessel proposal — order
truncation, `n < 0` → `#NUM!`, `x ≤ 0` → `#NUM!` for K and Y, overflow → `#NUM!` — is theirs and
is mechanical now that the mathematics exists.

Tell them two things: the four functions take `order: Int` and will not truncate a fractional
order for them, and **any oracle harness reading these from a workbook needs a per-family
tolerance recorded as Excel's error budget (~3e-8), not ours.**

---

## How this work has been done

**Write the stub.** *What is the simplest wrong implementation that still passes this?* Every
regression test here was confirmed to fail against the defect it names, by reintroducing it. Two
of them would have passed against a broken implementation had they been written a little
differently.

**Print the value.** The e³¹² overestimate, the 1.7e-6 Miller error, the K-comes-back-at-high-order
case and all four NaN-at-the-extremes defects were found by evaluating, none by reading.

**Derive the bound, do not tune it.** The I-recurrence identity fails at x = 500 under a flat
1e-13, because it subtracts two values agreeing to within `2n/x`. The amplification was measured
as exactly `x/2n` and written into the test as two named terms, so the bound stays at 1e-13 where
the cancellation is mild and only opens where it is not.

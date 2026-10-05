# Every comparison against NaN is false — and which way the default falls when it is

**2026-09-19 to 2026-09-29** · shipped **v3.0.0-alpha.8** at `f8f350e4` and **v3.0.0-alpha.9**
at `e63b142a` · 8,953 tests / 834 suites and quality-gate 46/46, 0 errors, 0 warnings, both as
recorded at `c0a493b8`, the last source commit before the alpha.8 tag

Reconstructed on 2026-10-05 from the git history and the CHANGELOG; it is not a contemporaneous
note.

78 commits from `v3.0.0-alpha.7` (`13b842f1`), 387 files changed. The suite stood at 7,898
tests at the first commit of the range (`0929ad47`). The work came in three runs: the last of
the Tier 2 oracle and complexity queue (09-19 to 09-20), a divisor sweep that widened into
untested code (09-21 to 09-26), and the contaminated-input campaign (09-26 to 09-29), which is
what alpha.8 is named for. alpha.9 is one commit on top, about a logger.

---

## What shipped

**alpha.8.** The CHANGELOG's own figures for the campaign: roughly 1,200 sites read, about 215
real defects, 6 hard crashes, 32 commits, in five phases.

| phase | shape | sites | defects |
|---|---|---|---|
| 1 | `Int(x)` traps | ~92 | 39 + 4 crashes |
| 2 | `?? 0` on a period lookup | 34 | 9 (+18 legitimate, pinned) |
| 3 | Streaming / Time Series, by probe | 21 probes | ~25 |
| 4 | `else { return T(0) }` after a valid guard | ~420 | ~96 |
| 5 | ordering, Fluent API, 20 never-swept directories | ~400 | 36 |

Before the campaign: `kendallsTau(_:vs:)` added (`1d4ebdd8`); `varianceTDist(_:)` deleted,
source-breaking, because for 30 or fewer values it returned `(n - 1) / (n - 3)` and never
looked at its data (`933a8ee5`); `SubscriptionBoxModel.init` and the projecting
`MarketplaceModel.init` now throw on a churn rate above 100% (`737332fb`);
`enableVariableShifting` defaults to `true` (`0929ad47`); `simplexProjection()` is now the
Euclidean projection, with the old behaviour kept as `normalizedToSumOne()` (`2ec86447`).

**alpha.9.** The Linux fallback logger is compiled on every platform as
`BusinessMathFallbackLogger` and aliased to `Logger` only where OSLog is absent, with nine
tests. No behaviour change.

---

## What is worth carrying forward

### 1. One fact, five failures, and the question that sorts them

Every comparison against `nan` is false, including `nan == nan`, and it never raises. The
changelog lists what follows: a `nan > 0` guard fires and its fallback is returned as a
measurement; `sorted()` is unspecified, so valid elements come back out of order;
`firstIndex(of:)` returns nil; both arms of an if/else-if are skipped; and
`Swift.min(1, nan)` returns `1`. Separately, `Int(Double)` traps on non-finite values and on
anything past `Int.max`.

The finding recorded last (`68f59e82`) is the useful one. `Core/GaussianElimination.swift` is
clean because a NaN fails each guard and lands on the failure enum.
`FinancialValidation.swift` was broken because a NaN fails each rule and lands on "valid". The
mechanism is identical and the default is opposite, so the question at a site is which way the
default falls when the comparison cannot be evaluated. `ModelValidator` printed
`✅ Validation PASSED - 0 errors, 0 warnings` for a projection with NaN assets and NaN revenue
(`a4300c68`).

### 2. The exception, found last, which inverts the rule

`nan >= x` is false for a `Double` and **true** for a `Comparable` wrapper over one. Swift
synthesises `>=` as `!(lhs < rhs)`, so a type supplying only `<` (`Date`, and `Period` above
it) negates a false. `guard end >= start` therefore fails open. `Period.custom(start:end:)`
and `Period.init(from decoder:)` accepted NaN-backed dates, and `days()`'s
`while currentDate <= end` then never ended; a capped probe was still running at 50,000
iterations. A surviving `Period` had `p == p` false. Fixed in `c0a493b8` by screening the
operands. `Period.day(_:)` is deliberately unguarded and pinned, because
`Calendar.startOfDay(for:)` turns a NaN-backed date into the real 4713-01-01.

### 3. A site is not a defect, and the grep cannot see the worst ones

About 1,000 of the 1,200 sites were legitimate, and the Phase 2 commit (`2bf3129f`) says
establishing that took longer than the fixes. Its test was where the period comes from: drawn
from the statement's own domain, the `?? 0` is unreachable; caller-supplied, it is live. In
the same phase `DebtCovenants` declared `toDouble(_ value: T?)` twice with the `??` inside
it, so a `?? 0` census returned nothing for a file with nine live reads. The Phase 4 question
(`bf7d5844`) was where on the caller's scale the zero lands: zero at the unfavourable end is
usually right, zero at the favourable end is the defect. That phase's plan estimated about 95
sites and there were 350.

### 4. The remediation carries the defect, and a fix upstream of the leak is not a fix

Four remediations had the defect inside them: `Swift.min(span, limit)` returns the `nan`;
`T(Int.max)` rounds to 2^63 and traps; a filter after `let n = count` gave
`Index out of range`; and `abs(nan) > 0.001` being false let a `.nan` covenant reading reach
an `.infinity` exit, the passing end of a minimum covenant. Three times a fix was correct and
unreachable: `mostFractionalVariable` was fixed for NaN, but `isIntegerFeasible` ran first and
a NaN passed all three of its tests (`a4300c68`).

### 5. Complexity stops predicting defects around 90; the bare-suppression grep does not

From the Tier 2 queue (`9a9e3e00`): 7 of 8 functions scoring 95 or above held a correctness
defect and 0 of 8 below did, but the two defects found below that line (`buildBlock`'s crash
at 68, `multipleLinearRegression`'s NaN at 55) came from grepping `fp-safety:disable` for
suppressions with no reason written after them. `multipleLinearRegression` returned an
`fStatistic` of NaN with a p-value of 1.0 for a design with zero predictors (`f710b1b2`). Bare
`fp-safety:disable` annotations in `Sources/` then went from 71 to 0 (`17d70c79`). The same
queue found `generalAIREMLUpdate` understating the Average Information matrix by up to 13.5%
(`155d7d1c`) and `.oneWayRandom` carrying the ICC(2,1) formula in three implementations
(`0d74af65`, `0c54218d`).

### 6. A fallback no local build compiles

The Linux fallback logger had never compiled: its primitives took a `String` and every call
site writes `\(value, privacy: .public)`. It sat behind `#else` of `canImport(OSLog)`, so no
macOS build read it. It was found by pointing Linux CI at `quality-gate-swift`, which depends
on this package (`f8f350e4`). Linux CI then failed again on the fix, at four sites a blanket
rewrite had broken, and `e63b142a` changed the structure instead of patching again.

---

## Process

**Freeze the contract before fanning out.** `ce75cd8b` wrote the contaminated-input contract
before the sweep was split across agents, because the defect class was inconsistency and
agents deciding separately would have produced more of it. Where the document disagrees with
a correctly-behaving function, the function wins.

**The sweep felt more complete than it was.** `4c907e4a` records that twenty commits had
covered four shapes, and that five further shapes and about a dozen areas had not been swept
at all. Phase 1 went first because it is the only class that crashes.

**Two deferrals whose reasons were false.** `percentileLocation` was left across three
handoffs because the blast radius of a new throw could not be measured. Measured in
`c0a493b8`: zero call sites in `Sources/`, and the function already throws.
`LogisticRegression.separatesByThreshold` was the other: it is unreachable with a contaminated
input, because `validatedDesign()` screens finiteness four lines before `refuseSeparation()` is
called, so it got documentation and no guard.

**Read the gate's checker count, not its verdict.** `2bf3129f` records that the binary
replaced that morning (v3.3.0) expanded `--check all` to 24 of its 46 checkers while printing
PASSED; the other 19 were run individually. `ce75cd8b` records that a gate run from a
`.claude/worktrees/` path examines 0 files and prints PASSED.

**`git add -A` with a peer session live.** The first attempt at `e63b142a` swallowed another
session's in-progress `FormattedValue.swift` into a commit about logging. It was reset and
re-made with an explicit pathspec.

**`doc-run` is load-sensitive.** It reported two compute-heavy articles as hangs at load 254
and none at load 8 (`c0a493b8`).

**Five pushes went out against a red CI.** The g-study oracle would not type-check on CI's
Swift 6.2.1, and the four pushes after it inherited the failure, each reporting a green local
suite and a green 45/45 gate. `3cbf3ccd` names the actual failure: nobody ran `gh run list`.

---

## Not done

- `0ecc7848` adopted the incoming `fallback` checker's findings here as baseline debt: 42
  errors and 27 warnings, 61 records in `.quality-gate-baseline.json`, expiring 2027-03-28.
  The commit calls every one a real finding. They were unfixed at the end of this range.
- `FormattedValue` has the same `Comparable`-over-a-float shape as `Date` and `Period` and no
  validation guard using it (`49baee7a`). Another session's `<=`/`>=` work on it was
  uncommitted when alpha.9 was tagged.
- `49baee7a` says the campaign's open list is empty. `4c907e4a` set the stopping criteria as
  yield below about 5% over a full area, so the greps are not empty and are not expected to be.

# Driving the Quality Gate to Zero

**Date:** 2026-08-24
**Branch:** `fix/test-force-unwraps` → merged to `main` (11 commits)
**Result:** 1,187 blocking findings → **0 errors, 0 warnings**; 6,632 tests passing throughout

---

## 1. What prompted it

A design session on the Marketing leg (`upcoming/MarketingLeg.md`) surfaced a shipped defect in
`sampleSize`. Fixing it meant running the gate. Running the gate produced **1,187 errors and 45
warnings** — against a repository whose standing instruction is 0/0.

## 2. The finding under the finding

The count was not a regression. **Nothing had been running the gate.**

- This repository had **no pre-commit hook**. `quality-gate-swift` has one — it caught a
  `--no-verify` during this very session — but BusinessMath's `.git/hooks/` held only samples.
- **CI could not supply one.** `.github/workflows/quality-gate.yml` failed at startup in 0
  seconds on every scheduled run: BusinessMath is public, `jpurnell/quality-gate-swift` is
  private, and a public repository cannot call a private one's reusable workflow. The file's own
  comment documents this.
- The last independently verified clean state was `SUMMARY_2026-06-04`. Ten weeks earlier.
- `SUMMARY_2026-08-13` separately records a session misled by *"a cached gate run … which
  produced two false '0 errors'"*.

**Gate claims in this repository had failed in two different ways before this session.** The
number was never checked because the thing that checks it was not running.

A third contributor: **`--exclude test` excludes the test *runner*, not test *files*.** The
command in the project guidelines skips executing the suite — which is what it is for — but
`safety` still scans `Tests/`. The suite's 1,111 force unwraps were in scope all along; the
flag's name is what hid them.

This is the same shape as the `checkers:` key in `quality-gate-swift`'s own config that silently
disabled the recursion checker: **a gate that reads as passing because nothing is running it.**

## 3. What was actually wrong

| Category | Count | Where |
|---|---:|---|
| Force unwraps | 1,111 | `Tests/` |
| `String(format:)` C-ABI | 42 | `project/` scripts, 5 in `Tests/` |
| Newline-literal splits | 17 | mixed |
| Process safety (shell, spawn, wait, read) | 28 | `project/` scripts |
| `@unchecked Sendable` without justification | 10 | `Tests/` |
| Pointer escape | 4 | `Tests/` |
| Force cast / force try | 10 | `Tests/`, `Examples/` |
| Unbounded `DispatchGroup.wait()` | 1 | **`Sources/`** |

## 4. Three findings that were not lint

**`CalculationCache`'s single-flight wait was unbounded.** `DispatchGroup.wait()` with no
deadline parks the caller until `leave()` is called. A leader whose `calculation()` traps never
calls it, so every later reader of that key waited forever — no crash, no error, just a stalled
pipeline. Now bounded at 30s, falling through to the compute path that already existed for
"leader published nothing reusable." The only finding in shipping code, and a real one.

**The analysis scripts carried a latent deadlock.** All nine set `standardError` to a `Pipe()`
they never drained, while calling `waitUntilExit()` before reading — the exact ordering the
process-safety checker names. Any command producing enough stderr to fill the buffer would hang
them.

**Two documented A/B testing functions did not compute what they claimed** — see §6.

## 5. What the mechanical work actually required

1,111 rewrites to `try #require`. Six transformer defects surfaced, and **every one was caught by
the compiler**:

| Defect | Symptom |
|---|---|
| `$0` closure shorthand swallowed | `$(try #require(0.foo))` |
| Escaped `\"` broke the backward scan | unterminated string literal |
| `try` right of `==` | Swift rejects it outright |
| Prefix minus | `-try #require(…)` is not an expression |
| Chained unwraps | `#require` cannot expand inside itself |
| `\|\|` is `rethrows` | `try` belongs at the front of the whole `#expect` argument |

That none was silent is a **property of the target form, not luck**: `#require` in argument
position is a syntax error, `?` where a value is expected is a type error. A wrong rewrite could
not compile and sit there looking green — which is more than could be said for the force unwraps
it replaced.

The gate also caught an intermediate mistake of mine: replacing `components(separatedBy: "\n")`
with `.newlines` traded a `\n` bug for a `\r\n` one, because `CharacterSet.newlines` holds both
characters and yields an empty element between every pair of lines. `split(whereSeparator:
\.isNewline)` is Character-based and correct, since `\r\n` is one grapheme cluster.

## 6. Library changes that outlive the cleanup

**`Statistics/Experiment/` (new).** Two-arm design: `sampleSizePerArm`, `achievedPower`,
`minimumDetectableEffect`, `analyze`. Verified against R's `power.prop.test`. `analyze` returns
the interval first and the p-value second, because *"is it significant"* and *"is it worth
shipping"* are different questions.

**Both `AB Test.swift` functions deprecated, with their defects named in the message.**
`sampleSize` was Cochran's survey formula — no power term, no second arm's variance —
understating an A/B test by **4.1×**. `pValue` returns `normSDist(|z|)`, never below 0.5, so the
`p < 0.05` test its own docs prescribed **can never be true**; its documented example claimed
0.043 where the code returns 0.950526 and the true two-sided p is 0.098948. Neither is corrected
in place: a silent behaviour change is worse than a compile error. Both delete in 3.0.0.

**Metric closures may throw.** `FinancialSimulation`'s eight methods are `rethrows`;
`SensitivityAnalysis`'s three entry points accept throwing extractors. Non-breaking.

## 7. Where `try #require` could not go

Three shapes, each documented at the site rather than left bare:

- **Non-throwing closures the API requires.** `DriverOptimization` calls its `model:` closure
  from inside the `@Sendable (VectorN<Double>) -> Double` objective the optimizer demands; making
  it throwing would ripple through the whole optimization stack. Those use a `driver(_:_:)`
  helper yielding `NaN`, which propagates and fails the numeric assertions.
- **`static let` initializers**, which cannot throw under any signature. Converted to
  `private static func referenceDate() throws -> Date`, keeping the fixed date — a hardcoded
  epoch would have quietly changed behaviour, since `Calendar.current` resolves locally.
- **Nested-argument unwraps** — `schedule.payment[schedule.periods.last!]!`. The inner `!` is a
  subscript argument, not a chain link, so it can neither be optional-chained nor nested. Hoisted
  once per function.

## 8. What was removed

Nine pre-v2 metrics scripts and their instruction docs — 4,128 lines. The evidence they were dead
is unambiguous: they wrote to `Instruction Set/05_SUMMARIES` and
`development-guidelines/05_SUMMARIES`, both deleted by the v2 migration; `QUICKSTART.md`'s
documented invocation was a path splicing the old layout onto the new; and the newest output they
ever produced is dated **2026-04-14**.

Kept, deliberately: `library_metrics.json` and eighteen `history/` snapshots (data, not tooling);
`LIBRARY_STATS.md`, annotated as the final snapshot; and the dated audit record of what was built
and why. **A record of the reasoning is worth more than a tidy directory.**
`04_IMPLEMENTATION_CHECKLIST.md` had a live release step invoking one of them — now repointed at
`quality-gate generate-pulse`.

One insight was extracted before deletion, because it outlives the code: the doc-gap analyzer
reported symbols as undocumented when their `///` comment was separated from the declaration by
`@available` attributes — valid DocC that attaches correctly. **Worth a targeted check in
`quality-gate`'s `doc-coverage`**, which passes here but may simply not be exercised by any
current declaration.

## 9. State at close

- `main` at the merge commit; working tree clean
- Gate: **0 errors, 0 warnings**, 44 of 45 checkers
- Tests: **6,632 in 585 suites**, zero issues
- Pre-commit and pre-push hooks installed, verified passing (exit 0)
- `CHANGELOG.md`, `README.md`, `master_plan.md` reconciled

## 10. Open

1. **CI still cannot run the gate.** The public/private workflow split is unfixed. `swift-vigil`
   already ships a release tarball through the public Homebrew tap; the same pattern would
   unblock every public repository, not just this one.
2. **The installed binary is 11 commits behind** (7 code), including four `RecursionAuditor`
   fixes. Do not rebuild while that repo has uncommitted work in `RecursionAuditor`. **0/0 here
   was measured against the older binary** — re-run after upgrading rather than assuming it holds.
3. **58 projects are still on development-guidelines 2.1.3**; upstream is 2.1.5. BusinessMath and
   quality-gate-swift were updated.
4. **`v2.7.0_SCOPE.md` is ready to build.** Sequential testing is explicitly deferred to 2.8.

# Handoff — 2026-08-14

**2.6.0 is written and unshipped, gated on one number: `doc-comment-code` is at 288.**
Everything else is clean. Nothing is in flight.

Down from 420 in ten commits (`99f59c8` … `11816c2`). Every 6- and 7-error file is
clear; six files still hold 5, fifteen hold 4, and the tail is 60 files holding one
error each. Full suite green after each commit — 6,597 tests in 581 suites, exit 0.
Method notes from that run are in "What the second pass added" below; the original
method still stands and is still right.

## State

| | |
|---|---|
| branch | `main`, clean, **0 ahead of `origin/main`** |
| tests | **6,597 in 581 suites**, 0 issues, ~35s |
| quality gate | **live tree clean** — 0 errors, 0 warnings |
| gate, worktrees | 53 errors / 24 warnings, all in `.claude/worktrees/` — see "Worktrees" |
| CI | green, 4/4 jobs |
| nightly (Release Tests) | green, including Thread Sanitizer |
| commits since `v2.5.2` | 131 |
| **`doc-comment-code`** | **288 non-macro**, +51 macro (parked) |

## First action on resume

```sh
swift build && swift test                       # 6,597 / 581, exit 0
quality-gate --no-cache                         # live tree 0/0
quality-gate --check doc-comment-code --no-cache | grep -c '❌ error:'   # 339 total
```

The binary is `quality-gate`, the flag is `--check`, and it takes **no positional path**. A
failed invocation greps as `0 errors`, indistinguishable from a clean run — guard on log
length before trusting any count.

**Filter the macro errors out of any total.** 51 of the 339 are in
`Sources/BusinessMathMacros/` and are not author-fixable (below). Their count is also
unstable — it moved 37→50→51 across runs with no edits — so track the non-macro number:

```sh
quality-gate --check doc-comment-code --no-cache 2>&1 \
  | grep -A1 '❌ error:' | grep '→' | grep -vc BusinessMathMacros
```

---

## The remaining 288

**There is no cluster left.** 139 files, worst file has 5 errors, and the tail dominates:
60 files hold exactly one error. Every mechanical pass has been spent; this is per-file
reading. What the second pass found is that a single file's errors usually share one
cause — one missing fixture, one wrong label — so per-file is also the efficient unit.

Worst files, none of them large:

```
 5  Analysis/DataTable.swift
 5  Diagnostics/ModelProfiler.swift
 5  Financial Statements/FinancialPeriodSummary.swift
 5  Financial Statements/MultiPeriodReport.swift
 5  Optimization/Algorithms/ConstrainedOptimizer.swift
 5  Scenario Analysis/FinancialProjection.swift
 4  Valuation/Equity/EnterpriseValueBridge.swift
 4  Valuation/Debt/CreditSpreadModel.swift
    ... 13 more at 4
```

Regenerate the list with:

```sh
quality-gate --check doc-comment-code --no-cache 2>&1 \
  | grep -A1 '❌ error:' | grep '→' | grep -v BusinessMathMacros \
  | sed 's|.*Sources/BusinessMath/||' | cut -d: -f1 | sort | uniq -c | sort -rn
```

### The method that works

**Read the declaration. Do not infer it from the name.** Every round trip lost this session
came from guessing an API: `marketPrice` bound to a `Double` when the function takes
`TimeSeries`, `projection` bound to `FinancialProjection` in a file where it is a
`DriverProjection`, `.operatingExpense` guessed as an `IncomeStatementRole` case when the
real ones are `.costOfGoodsSold` and `.generalAndAdministrative`.

**Take the type from usage, not from the identifier.** `.zip` and `.aggregate` are TimeSeries
methods; `.positive()` and `.sample(for:)` are Driver methods; `searchSpace:` takes bounds;
`entity:` takes an Entity. The name tells you nothing — `model` named six different types
across nine files.

**Drive from the checker's own report.** A pass that inserted bindings wherever a plausible
name appeared produced **205 bindings and cleared 13 errors**, because `\btimeSeries\b`
matches the argument label in `Account(..., timeSeries:)`. Parsing the diagnostic and
inserting only at the fence it names produced **27 bindings and cleared 17**. Fewer edits,
better result.

**Read the whole fence before inserting.** Twice a binding was added for a name the fence
already declared — `var entity` in Entity.swift, `let q1` in BalanceSheet.swift. One
duplicate poisons every later line in its fence, so it costs more than it fixes.

### The trap worth knowing

An unbound identifier that happens to name a library function does **not** fail as
undefined. It resolves, and the error reads:

```
cannot convert value of type '@Sendable (Double) -> ScenarioParameter'
                             to expected argument type 'TimeSeries<Double>'
```

Seen with `revenue`, `price`, `users`, `npv`, `discountRate`. It looks like a type-inference
problem and is a missing binding. An explicit `let` shadows it.

### What the second pass added

**A `T` inference error is almost never a generics problem.** It is what the checker
reports when a binding is missing or a generic type is named without its argument.
Seen three ways: nothing bound at all (`result` in LMEDiagnostics); a bare generic type
name (`KMeans<VectorN>` where the type is `VectorN<T>`, `[AmortizationPayment]` where it
is `AmortizationPayment<T>`); and a generic type that cannot infer from a non-generic
argument (`ProbabilisticDriver<T>` from a `DistributionNormal`, which is Double-only).
Look for a missing or under-specified binding first. The same holds for
`cannot infer key path type from context` and `cannot infer contextual base`.

**The colliding name need not be in this library.** The handoff already records that an
unbound identifier can resolve to a same-named library function. It can also resolve
into the C standard library through Foundation. `signal` in FFTBackend resolved to POSIX
`signal(2)` and reported as

```
cannot convert value of type '@Sendable (Int32, (@convention(c) (Int32) -> Void)?) -> ...'
```

The tell is a reported type you never wrote. `@convention(c)` in a diagnostic means the C
library, not your code. `time`, `index`, `remainder`, `div` and `log` are the same hazard.

**The smallest green edit can be the wrong edit.** `DistributionNormal(mean:standardDeviation:)`
does not exist, and the type offers `init(mean:variance:)` one line from
`init(_ mean:_ stdDev:)`. Renaming the label to `variance:` compiles, passes, and turns a
15,000 standard deviation into σ ≈ 122. Nothing downstream catches it — fences are not
executed. When a label is wrong, read both initialisers before choosing.

**Fences do not share scope, including across `##` headings.** Several fences were written
as continuations of the one above them (`AccountAdjustment`'s Investor Presentation,
`Driver`'s projection example, `CreditMetrics`). Each needs its own fixture. Where the
full preamble is long, a smaller fixture that still demonstrates the point is better than
a copy.

**Parse errors read as nonsense.** `values: [0.01, 0.03, ...]` reports `expected expression
after unary operator`, because a literal `...` is a range operator with no operand.
`guard let x = y else { return }` at fence top level reports `return invalid outside of a
func`. Neither message mentions the actual problem.

**Prefer the checker's own line numbers, but confirm which fence they name.** Binding
`currentPeriod` into the fence that already declared it — while the fence that needed it
was 60 lines further down — cost a full round trip. The old lesson, learned again.

### Categories that cannot be fixed in fences

- **`internal` symbols, same as `private`.** The fence compiles as an *external* client, so
  anything below `public` is invisible. `MetalBuffers` is `internal final class` and its
  one fence — 4 errors, the last of the 4-error tier — cannot be made to compile at all.
  It is the only file left that is blocked rather than unfinished. It wants
  `<!-- docs:illustrative -->`, which is a human edit by design and was deliberately not
  applied. The same rule is why `RandomInterceptResult`'s synthesised memberwise init is
  unreachable and its fences must fit a model instead.
- **`Real` is not in the fence preamble.** The preamble is Foundation plus this module, and
  `Real` comes from `Numerics`, which BusinessMath imports without re-exporting. Any fence
  written `struct Foo<T: Real>` fails with `references 'Real'` followed by
  `type 'T' does not conform to protocol 'Real'`. Write such examples concretely against
  `Double`. Hit in `Optimizer` and `FinancialPeriodSummary`.
- **`private` symbols.** A doc example on a private function cannot compile — nothing can
  reference it. `generateSteps` in SensitivityAnalysis.swift is one; rewritten to show the
  equivalent via `stride`.
- **Macro fences** — 51 errors, all in `Sources/BusinessMathMacros/`. The checker compiles
  them without the plugin. Proposal written; the user is working this separately.
- **Extracted-package references** — `AlphaVantageProvider` and friends live in
  `BusinessMathMarketData` now, so their fences cannot compile against this module.

---

## Worktrees

The gate reports 53 errors and 24 warnings, **all in `.claude/worktrees/`**, from the new
`gpu-safety` checker reading stale pre-fix kernel source. The live tree is clean.

- Three registered worktrees carry uncommitted work — 11, 7 and 13 dirty files. Left alone.
- `agent-a064a9af` is an **orphan** from April 14, not registered with git at all.

Two open questions: what to do with the orphan, and whether the gate should scan
`.claude/worktrees/` — the same shape as auditing `.metal` files excluded from the build.

---

## Open, beyond the fence work

0. **`AsyncTimestampedSequence` cannot be passed to `aligned(with:)`.** Found while
   clearing AsyncAlignedSequence's fences. The sequence declares no `Sendable`
   conformance and `aligned` requires `Secondary: AsyncSequence & Sendable`, so
   `a.timestamped().aligned(with: b.timestamped())` — which both fences documented —
   has never compiled. The alignment tests avoid it by building `AsyncValueStream`s of
   already-`Timestamped` values, and the fences now do the same. A conditional
   `extension AsyncTimestampedSequence: Sendable where Base: Sendable` looks right (the
   only stored property is `base`), but it is a concurrency change with a ConcurrencyAuditor
   in the gate, so it wants a deliberate decision rather than a doc-pass edit.
1. **`project/plans/upcoming/v3.0.0_SCOPE.md`.** Three places where the correct behaviour is
   refusal and the signature cannot refuse: DE and PSO's `optimizeDetailed`,
   `EnterpriseValueBridge.valuePerShare`, and `IslandModel` swallowing `GeneticAlgorithm`'s
   seed refusal with `try?`.
2. **Two proposals awaiting the quality-gate repo**, untracked on its `feat/doc-generated`
   branch: `GPUSafetyChecker.md` (implemented since — the checker is live and found three
   real defects) and `DocCommentCode_MacroPlugin.md`.
3. **Seedless wrappers over seeded primitives** — `ScenarioAnalysis`,
   `runFinancialSimulation`, `ReciprocalParameterRecoveryCheck.run`. Two statistical tests
   have now been loosened because of the second one.
4. **`doc-symbol-link`** is the one checker of the four still not landed.

---

## Convention notes

- Run the gate with `--no-cache`. A cached run executes 10 of 37 checkers and prints an
  identical PASSED summary.
- **Never chain `swift test` or the gate with `git commit` using `;`.** It happened twice
  this session and both times the commit went through on a red result. Use `&&`, or verify
  in a separate call.
- `--filter` passing proves nothing. Two defects this session were visible only in the full
  parallel suite and clean in isolation, 4/4 and 6/6.
- Statistical assertions on unseeded draws fail on schedule: a 3σ bound is 1 run in 370.
  Two were found this way; seed the stream, or widen and say why.

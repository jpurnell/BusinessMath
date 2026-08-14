# Handoff — 2026-08-13 (evening)

**2.6.0 is written and unshipped, gated on one number: `doc-comment-code` is at 420.**
Everything else is clean. Nothing is in flight; `main` and `origin/main` agree.

## State

| | |
|---|---|
| branch | `main`, clean, **0 ahead of `origin/main`** |
| tests | **6,597 in 581 suites**, 0 issues, ~35s |
| quality gate | **live tree clean** — 0 errors, 0 warnings |
| gate, worktrees | 53 errors / 24 warnings, all in `.claude/worktrees/` — see "Worktrees" |
| CI | green, 4/4 jobs |
| nightly (Release Tests) | green, including Thread Sanitizer |
| commits since `v2.5.2` | 122 |
| **`doc-comment-code`** | **420 non-macro**, +51 macro (parked) |

## First action on resume

```sh
swift build && swift test                       # 6,597 / 581, exit 0
quality-gate --no-cache                         # live tree 0/0
quality-gate --check doc-comment-code --no-cache | grep -c '❌ error:'   # 471 total
```

The binary is `quality-gate`, the flag is `--check`, and it takes **no positional path**. A
failed invocation greps as `0 errors`, indistinguishable from a clean run — guard on log
length before trusting any count.

**Filter the macro errors out of any total.** 51 of the 471 are in
`Sources/BusinessMathMacros/` and are not author-fixable (below). Their count is also
unstable — it moved 37→50→51 across runs with no edits — so track the non-macro number:

```sh
quality-gate --check doc-comment-code --no-cache 2>&1 \
  | grep -A1 '❌ error:' | grep '→' | grep -vc BusinessMathMacros
```

---

## The remaining 420

**There is no cluster left.** 163 files, worst file has 7 errors, 241 of the 420 are
undefined references spread over ~180 identifiers of which most appear once. Every
mechanical pass has been spent; this is per-file reading.

Worst files, none of them large:

```
 7  Optimization/Heuristic/KMeansClustering.swift
 7  Statistics/MixedModels/Diagnostics/LMEDiagnostics.swift
 6  Financial Statements/AccountAdjustment.swift
 6  Financial Statements/CashFlowStatement.swift
 6  Forecasting/HoltWintersModel.swift
 6  Operational Drivers/IntegrationExample.swift
 6  Portfolio/RiskParity.swift
 6  Scenario Analysis/FinancialSimulation.swift
 6  Simulation/MonteCarlo/SimulationResults.swift
 6  Streaming/AsyncTimeWindowedSequence.swift
 6  Streaming/StreamingAnomalyDetection.swift
 6  Streaming/StreamingForecasting.swift
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

### Categories that cannot be fixed in fences

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

## Open, beyond the 420

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

# Session Summary: typed authoring over ModelDefinition, and removing BusinessMathDSL

**Date:** 2026-09-01
**Repo:** `BusinessMath` (driven from sibling `../BusinessMathExcel`)
**Outcome:** Design proposal written and approved in substance. No implementation yet.
**Live proposal:** `project/plans/proposals/TypedModelAuthoring.md`
**Companion:** `../BusinessMathExcel/project/summaries/2026-09-01_excel_to_modeldefinition_pivot.md`
— read that one for the full decision chain; this is the BusinessMath-side view.

---

## Why this happened

`BusinessMathExcel` needed an import target for Excel workbooks. It assumed `BusinessMathDSL`.
Investigation showed that was wrong on two counts.

**1. `BusinessMathDSL` has zero consumers.** `grep -rl "import BusinessMathDSL"` across every
sibling package returns only its own four test files and its own README. No package declares it
as a dependency — not Pro, not the MCP server, not the UI, not Excel, not the demos.

**2. It duplicates this package.** `Scenario` and `ScenarioAnalysis` exist in *both*
`BusinessMathDSL/Scenario.swift` and `Simulation/MonteCarlo/ScenarioAnalysis.swift:113,167` —
same names, same package, different targets. Valuation duplicates `Valuation/Equity/`. Core's
versions are `Sendable`; **no `BusinessMathDSL` type conforms to `Sendable`**, despite
`Package.swift:133-135` enabling `StrictConcurrency` on that target. Core throws where the DSL
calls `preconditionFailure` (`Revenue.swift:74,90,106,111`, `Taxes.swift:102,118`,
`Forecast.swift:28-151`).

Meanwhile **`ModelDefinition` is the capable model layer and already ships** — named accounts,
formulas over `TimeSeries`, `requiredInputs()`, `evaluationOrder()`, SCC cycle detection
(`DependencyReport.swift:103`) and resolution (`CycleSolver.swift:234`), landed in `87a717e` and
written for Excel migrants. Its only weakness is being stringly typed.

**So: keep `ModelDefinition`, give it a thin typed layer, delete the DSL.**

## What the proposal contains

1. **`Account<U>` / `Expr<U>` over `ModelDefinition`.** A typed expression tree that *renders to*
   the string grammar `FormulaEvaluator` already parses — `[Bracketed Names]`
   (`FormulaEvaluator.swift:227-236`) make the rendering unambiguous even for `Sales & Marketing`.
   `ModelDefinition`, `FormulaEvaluator`, and `CycleSolver` are **not modified**; the layer is
   ~300 lines and deletable in one commit if it does not earn its keep.
2. **Phantom-typed units** — `Money`, `Rate`, `Ratio`, `Duration`, `Condition`. Illegal
   combinations simply have no overload, so `Expr<Money> + Expr<Ratio>` does not compile.
   **Rate basis (annual vs monthly) is a runtime value, not a second type parameter** — nested
   phantom generics wreck diagnostics and type-check time.
3. **Function registry that delegates.** `FormulaEvaluator` implements **no financial
   mathematics**; every financial function dispatches to the canonical implementation in
   `Time Series/TVM/`. This package has **616 public functions**, so the registry is a
   name-mapping exercise, not an implementation effort — the scarce resource is *semantic
   verification per name*.
   **Critical: `NPV` in formula text binds to `npvExcel`, not `npv`.** `NPV.swift:215-217`
   documents the one-period discounting difference; binding it wrong would mis-discount every
   imported model by one period. A test asserts the two differ, to pin the binding.
4. **`Rollforward` + `PeriodDriver`.** `FormulaEvaluator.swift:119-124` and
   `CycleSolver.swift:222-226` both deliberately exclude cross-period references, and the latter
   assigns the rollforward to "the caller's loop" — but no reusable caller exists.
   `PeriodDriver` becomes it. **Not a grammar change:** `evaluate()` resolves whole series in
   *account* dependency order (`ModelDefinition.swift:264-274`), so a self-referencing formula
   would be refused as an account-level cycle. Supporting prior-period refs in the grammar means
   moving the dependency graph to per-(account, period) — a rewrite of the evaluation core.
   Clean split: **within-period cycles → `CycleSolver`; cross-period carry → `PeriodDriver`.**
5. **`IF` + comparison operators.** `FormulaEvaluator` has neither today. Comparisons evaluate
   period-wise to `1`/`0` (Excel's `TRUE` coercion), and the `Condition` unit has no arithmetic
   overloads, so `revenue + (a > b)` does not compile — a mistake Excel makes silently.
   **Guidance: if a condition is answerable from the timeline alone, it is data (an indicator
   input series), not `IF`.** A balloon payment in period 5 is a fact about the timeline.
6. **Waterfall migration.** `Tier`/`TierComponents`/`LiquidationWaterfall` move to
   `Financial Statements/Waterfall/` — the only DSL component with no core equivalent. Distinct
   from `CapTable.liquidationWaterfall` (`EquityFinancing.swift:332`), which models liquidation
   *preferences*, not tiered distribution.

## Current state

- **Branch `main`, tag `v2.7.0`.**
- `76b538fe` committed both proposals (`DSLExpressiveness.md`, `TypedModelAuthoring.md`);
  `a2635a19` cut the 2.7.0 release on top.
- **`TypedModelAuthoring.md` has uncommitted edits** made after that commit: Part 2.5
  (`Rollforward`/`PeriodDriver`), the conditionals section, a third ADR, and revised phasing
  (2a–2d). Commit before doing anything else.
- `DSLExpressiveness.md` is **superseded** — kept for its prior-art audit (§0), the
  `BusinessMathPro` dependency-direction finding, and §12's adversarial review, which named the
  alternative that won.

## Next step in this repo

**Phase 1 — waterfall migration.** Move `Tier`, `TierComponents`, `LiquidationWaterfall`,
`WaterfallResult`, `WaterfallContext` to `Financial Statements/Waterfall/`, adding `Sendable`
conformance and throwing initializers in place of `preconditionFailure`
(`TierComponents.swift:77`). Gate: `WaterfallBuilderTests` green at the new location.

Phase 2a (call machinery + `MIN`/`MAX`/`ABS`/`SUM` + comparisons + `IF`) is the other unblocked
piece and is what `BusinessMathExcel` waits on.

**Note the dependency direction:** `BusinessMathPro/Package.swift:40-43` shows Pro depends on
this package, so `Treasury/CapitalStructureProjection.swift` is prior art we **cannot call** from
core. Any shared debt primitive belongs here, and Pro eventually rebases onto it.

## Open questions

1. Deprecate-then-remove `BusinessMathDSL` across two releases, or delete outright? User leans
   ASAP; recommendation is the one-release deprecation since it is a public product.
2. Compile-time budget number for the phantom-unit overload set (§15 Q5) — needs measuring on
   the worked example before Phase 3 is gated on it. Documented fallback if it fails: runtime
   unit validation in `validateUnits()`.
3. Is `Duration` the right unit for share counts, or does `Share` pull its weight?

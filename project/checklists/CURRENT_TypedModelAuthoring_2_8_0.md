# CURRENT: TypedModelAuthoring phases 1–2d — release 2.8.0

**Started:** 2026-09-01
**Proposal:** `project/plans/proposals/TypedModelAuthoring.md` (approved 2026-09-01)
**Unblocks:** `BusinessMathExcel` Phase 3 — its `FormulaTranslator` cannot emit a formula the
evaluator has no way to parse, and its rollforward decomposition needs `PeriodDriver`

Tasks 1–7 are **additive**. Task 8 is not: it removes the `BusinessMathDSL` product outright.

**2.8.0 is therefore a breaking release behind a minor version number**, taken deliberately —
the major it would otherwise wait for is not scheduled, and the consumer population is empty
(the only importers are four of the module's own test files). The deviation is documented in the
proposal §15 Q1 and must be stated plainly at the top of the CHANGELOG entry. A minor number
must not be left to imply a compatibility that does not hold.

**Ordering matters within the release:** Task 1 migrates the waterfall types into core and Task 8
deletes their old home, so Task 1 must be green before Task 8 begins.

**TDD per project rules: failing test first, minimum code, refactor. Commit at each green state.**

---

## Task 1 — Migrate the waterfall types into core (proposal Phase 1)

`Tier`, `TierComponents`, and `LiquidationWaterfall` are the only part of `BusinessMathDSL` with
no equivalent in core. They move to `Financial Statements/Waterfall/` **before** 3.0.0 deletes
their old home, so nothing worth keeping leaves with the module.

- [ ] **RED** — move `WaterfallBuilderTests` to the new location; they fail to compile.
- [ ] **GREEN** — move the three types into `Sources/BusinessMath/Financial Statements/Waterfall/`.
- [ ] Add `Sendable` conformance. None of the DSL types have it today, while
      `StrictConcurrency` is enabled package-wide.
- [ ] Replace trapping initializers with throwing ones. `Tier.init` and friends
      `preconditionFailure` on out-of-range input, which crashes the process on data a caller
      may not control — the specific hazard that forced the recognizer's plan/materialize split.
- [ ] Leave `@available(*, deprecated, renamed:)` pointers at the old location so 2.8.x callers
      get a fix-it rather than a break.
- [ ] Commit.

## Task 2 — `FormulaEvaluator` call machinery (proposal Phase 2a, part 1)

The evaluator has **no functions at all**: its token set is `number`, `name`, `+ - * / ( )`.
Verified at `Time Series/FormulaEvaluator.swift:205-208`. This task builds dispatch from nothing.

- [ ] **RED** — `SUM(a, b)` fails to tokenise today; assert it parses.
- [ ] **GREEN** — comma token, `Node.function(String, [Node])`, parser support for a call.
- [ ] **GREEN** — a dispatch table keyed by upper-cased name, with arity checking.
- [ ] **Decide:** what an unknown function does. It must not evaluate to zero — the fail-silent
      principle in `CLAUDE.md` and the recognizer's `.unregisteredFunction` both depend on this
      surfacing. Throw, and name the function.
- [ ] Edge: wrong arity, nested calls, a call as an operand (`1 + MAX(a, b)`).
- [ ] Commit.

## Task 3 — Arithmetic primitives (proposal Phase 2a, part 2)

- [ ] **RED/GREEN** — `MIN`, `MAX`, `ABS`, `SUM`, each delegating to a canonical implementation
      rather than being reimplemented here (decision D4).
- [ ] `SUM` over a name that resolves to a series, not just scalars.
- [ ] Commit.

## Task 4 — Comparisons and `IF` (proposal Phase 2a, part 3)

- [ ] **RED** — `IF(a > b, a, b)` does not parse today.
- [ ] **GREEN** — comparison operators `>`, `<`, `>=`, `<=`, `=`, `<>` and the `IF` function.
- [ ] **Excel's coercion, pinned by test:** `TRUE` is 1 and `FALSE` is 0 in arithmetic. The
      downstream `NodeFormula` layer already made this choice; the two must agree or a
      round-tripped model changes meaning.
- [ ] `IF` selects **period-wise** over a `TimeSeries`, not once for the whole series.
- [ ] Commit.

## Task 5 — TVM function tranche (proposal Phase 2b)

- [ ] `NPV`, `IRR`, `XIRR`, `XNPV`, `PMT`, `IPMT`, `PPMT`, `PV`, `FV`, `CUMIPMT`, `CUMPRINC`.
- [ ] **`NPV` binds to `npvExcel`, not `npv`** (decision D5). `NPV.swift:215-217` documents the
      one-period discounting difference. A test asserts the two *differ*, so the binding cannot
      be quietly changed.
- [ ] One Excel-semantics fixture per name, with the expected value computed in Excel and
      recorded — never inferred from our own implementation.
- [ ] Commit.

## Task 6 — Statistical function tranche (proposal Phase 2c)

- [ ] Seed the list from `BusinessMathExcel`'s `FormulaMapper.statisticalFunctions`, which is
      already a survey of what workbooks actually use.
- [ ] Pin `STDEV`/`STDEVP` and `VAR`/`VARP` denominators — sample versus population is the
      classic silent-wrong-answer in this tranche.
- [ ] Commit.

## Task 7 — `Rollforward` and `PeriodDriver` (proposal Phase 2d)

The piece `BusinessMathExcel` needs most: `ModelDefinition` formulas are period-local by design
(`FormulaEvaluator.swift:119-124`, `CycleSolver.swift:222-226`), and this is the caller that
carries a balance across periods.

- [ ] **RED** — a debt rollforward across 7 periods, against an Excel fixture.
- [ ] **GREEN** — `Rollforward(opening:closing:seed:)` and the `PeriodDriver` loop.
- [ ] A **within-period** cycle still resolves through `CycleSolver`.
- [ ] A **cross-period** cycle is diagnosed as `rollforwardCycle`, not silently iterated.
- [ ] Year-1 interest on a 120 draw at 10% with full sweep is **11.75** — the average-balance
      figure. Beginning-balance gives 12.00, so this one number distinguishes a correct cyclic
      solve from a model that broke the cycle by timing.
- [ ] Commit.

## Task 8 — Delete `BusinessMathDSL` (proposal Phase 6)

**Do not start until Task 1 is green.** The waterfall types must be living in core before their
old home is removed.

- [ ] Confirm the consumer search still holds: no importer outside the module's own tests.
- [ ] Delete `Sources/BusinessMathDSL/` and the three obsolete `Result Builder Tests` files.
- [ ] Remove the product and target from `Package.swift`.
- [ ] Confirm the duplication this resolves is actually resolved: `Scenario` and
      `ScenarioAnalysis` exist in both the DSL and `Simulation/MonteCarlo/ScenarioAnalysis.swift`,
      and the valuation types duplicate `Valuation/Equity/`. Core's versions are the survivors.
- [ ] **Record what dies with it.** `CashFlowModel.freeCashFlow(year:)` returns
      `netIncome + depreciation` with no capex and feeds `DCFModel.calculateEnterpriseValue()`,
      overstating enterprise value by PV(capex). Deletion is the fix, and that is worth saying in
      the CHANGELOG rather than letting a real bug vanish silently with its module.
- [ ] Commit.

## Task 9 — Documentation (proposal Phase 7)

- [ ] `1.7-TypedModelAuthoringGuide.md` covering the grammar functions and the rollforward driver.
- [ ] Reconcile `1.4-FluentAPIGuide.md`, which references DSL types that will no longer exist.
- [ ] CHANGELOG entry leading with the breaking removal, not burying it under the additions.
- [ ] Commit.

---

## Done when

- [ ] All nine tasks green, committed individually.
- [ ] `swift build && swift test` clean.
- [ ] **Quality gate 0 errors / 0 warnings**, counted rather than read off the verdict line.
- [ ] CHANGELOG entry; `project/master_plan.md` reconciled; capability map reviewed.
- [ ] Release checklist followed **before** tagging: `release-readiness`, capability map, README
      metrics, CHANGELOG section renamed, atomic `--follow-tags` push.
- [ ] CHANGELOG leads with the breaking removal under a minor version number.
- [ ] Tagged `v2.8.0`.
- [ ] Move this file to `project/checklists/completed/`.

## Do NOT do in this release

- **Phase 3** (`Unit`, `Account<U>`, `Expr<U>`). Gated on the compile-time budget in §15 Q5,
  which has not been measured. It is deliberately after this work so the Excel gate does not
  wait on it.
- **Phase 4** (`validateUnits()`), which depends on Phase 3.
- Reimplementing any financial mathematics. Registry entries dispatch to canonical
  implementations; core already has 616 public functions (decision D4).

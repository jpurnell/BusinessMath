# CURRENT: TypedModelAuthoring phases 1–2d — release 2.8.0

**Started:** 2026-09-01
**Proposal:** `project/plans/proposals/TypedModelAuthoring.md` (approved 2026-09-01)
**Unblocks:** `BusinessMathExcel` Phase 3 — its `FormulaTranslator` cannot emit a formula the
evaluator has no way to parse, and its rollforward decomposition needs `PeriodDriver`

Everything here is **additive**. Nothing in this release removes or renames a public API, which
is what lets it be a minor and ship ahead of the riskier typed layer.

**TDD per project rules: failing test first, minimum code, refactor. Commit at each green state.**

---

## Task 1 — Migrate the waterfall types into core (proposal Phase 1)

`Tier`, `TierComponents`, and `LiquidationWaterfall` are the only part of `BusinessMathDSL` with
no equivalent in core. They move to `Financial Statements/Waterfall/` **before** 3.0.0 deletes
their old home, so nothing worth keeping leaves with the module.

- [x] **RED** — move `WaterfallBuilderTests` to the new location; they fail to compile.
- [x] **GREEN** — move the three types into `Sources/BusinessMath/Financial Statements/Waterfall/`.
- [x] Add `Sendable` conformance. None of the DSL types have it today, while
      `StrictConcurrency` is enabled package-wide.
- [x] Replace trapping initializers with throwing ones. Also required splitting `TierTerms` out
      of `Tier`: a result builder's `buildBlock` cannot throw, because the compiler generates that
      call and has nowhere to write `try`. Returning a `Tier` from it would have meant carrying a
      placeholder name and priority through an invalid state — which the original did. Removing
      that was a by-product of the migration rather than a goal of it.
- [x] Replace trapping initializers with throwing ones. `Tier.init` and friends
      `preconditionFailure` on out-of-range input, which crashes the process on data a caller
      may not control — the specific hazard that forced the recognizer's plan/materialize split.
- [x] ~~Leave `@available(*, deprecated, renamed:)` pointers at the old location.~~
      **Tried and reverted.** Annotating the DSL originals produced **72 warnings** from the
      module's own internal use — the types reference each other, and deprecating all of them
      does not stop Swift warning at every use site. Against the zero-warning bar that is not a
      trade worth making for a module with no consumers that is deleted wholesale in 3.0.0.

      `renamed:` was wrong on its own terms too: the core versions throw where these trap, so the
      automatic fix-it it promises would produce code that does not compile. A pointer that
      misleads is worse than none.

      What replaces it: the CHANGELOG names the move and the new location, and the 3.0.0 removal
      is already recorded in the proposal. Nobody is left without a map.
- [x] Commit.

## Task 2 — `FormulaEvaluator` call machinery (proposal Phase 2a, part 1)

The evaluator has **no functions at all**: its token set is `number`, `name`, `+ - * / ( )`.
Verified at `Time Series/FormulaEvaluator.swift:205-208`. This task builds dispatch from nothing.

- [x] **RED** — `SUM(a, b)` fails to tokenise today; assert it parses.
- [x] **GREEN** — comma token, `Node.function(String, [Node])`, parser support for a call.
- [x] ~~a dispatch table keyed by upper-cased name, with arity checking.~~ **Moved to Task 3.**
      Arity is a property of a registered function, so a table with no entries has no arity to
      check. Task 2 lands the call site and the refusal; Task 3 lands the table and its arities
      together, where they can be tested rather than asserted.
- [x] **Decided: throws `FormulaError.unknownFunction`, naming the function.** It must not evaluate to zero — the fail-silent
      principle in `CLAUDE.md` and the recognizer's `.unregisteredFunction` both depend on this
      surfacing. Throw, and name the function.
- [x] Edge: wrong arity, nested calls, a call as an operand (`1 + MAX(a, b)`).
- [x] Commit.


**Found while doing it.** Adding a `Node` case broke two exhaustive switches, and neither wanted
the same answer:

- `CycleForm.degree` now reports any call touching a cycle member as **nonlinear**. `MIN` and
  `MAX` are piecewise linear and `ABS` is not linear at all, and a registry that grows will not
  stay analysable by inspection. Nonlinear sends the system to the iterative solver — slower and
  correct. Linear would have been a confident wrong answer out of a linear solve.
- `LinearCycleSolver.affineForm` **throws** on a call. It is unreachable, since the classifier
  above never sends one here, and it is checked anyway for the reason the rest of that function
  checks what it already knows: a classifier and an extractor that disagreed would produce a
  confident wrong number.

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

---

## Done when

- [ ] All seven tasks green, committed individually.
- [ ] `swift build && swift test` clean.
- [ ] **Quality gate 0 errors / 0 warnings**, counted rather than read off the verdict line.
- [ ] CHANGELOG entry; `project/master_plan.md` reconciled; capability map reviewed.
- [ ] Release checklist followed **before** tagging: `release-readiness`, capability map, README
      metrics, CHANGELOG section renamed, atomic `--follow-tags` push.
- [ ] Tagged `v2.8.0`.
- [ ] Move this file to `project/checklists/completed/`.

## Do NOT do in this release

- **Phase 3** (`Unit`, `Account<U>`, `Expr<U>`). Gated on the compile-time budget in §15 Q5,
  which has not been measured. It is deliberately after this work so the Excel gate does not
  wait on it.
- **Phase 4** (`validateUnits()`), which depends on Phase 3.
- **Deleting `BusinessMathDSL`.** Removal is outright and lands in 3.0.0 — breaking regardless of
  deprecation. Phase 5 is dropped entirely; see §15 Q1.
- Reimplementing any financial mathematics. Registry entries dispatch to canonical
  implementations; core already has 616 public functions (decision D4).

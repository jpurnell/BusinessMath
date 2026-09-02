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

- [x] **RED/GREEN** — `MIN`, `MAX`, `ABS`, `SUM`, each delegating to a canonical implementation
      rather than being reimplemented here (decision D4).
- [x] `SUM` over a name that resolves to a series, not just scalars.
- [x] **Decided: every function is period-wise**, which is what `MIN(A2, B2)` filled across a row
      does in a sheet. Aggregating *down* a column is a different operation and stays
      inexpressible — this grammar is period-local by design, and a `SUM` that reached across
      periods would smuggle a rollforward inside a formula, which is the caller's loop.
- [x] **Period alignment follows `+`:** only periods present in every operand survive, via
      `TimeSeries.zip`. A model whose accounts disagree about their span should not have values
      invented for the gap.
- [x] Arity checking, moved here from Task 2, where the table it checks did not yet exist.
- [x] Commit.


**Measured before choosing what to register.** Counting the functions two real workbooks actually
call: Wharton uses **4** distinct names, the credit model **30**, against Excel's ~500. `SUM` is
second by volume across both. That check also showed the *later* tranches are aimed wrongly —
recorded in the proposal under "Which functions, measured rather than assumed".

## Task 4 — Comparisons and `IF` (proposal Phase 2a, part 3)

- [x] **RED** — `IF(a > b, a, b)` does not parse today.
- [x] **GREEN** — comparison operators `>`, `<`, `>=`, `<=`, `=`, `<>` and the `IF` function.
- [x] **Excel's coercion, pinned by test:** `TRUE` is 1 and `FALSE` is 0 in arithmetic. The
      downstream `NodeFormula` layer already made this choice; the two must agree or a
      round-tripped model changes meaning.
- [x] `IF` selects **period-wise** over a `TimeSeries`, not once for the whole series.
- [x] Commit.


**Decisions made while doing it.**

- **Comparisons bind loosest**, so `revenue - 50 > 100` reads as `(revenue - 50) > 100`, the way
  a sheet reads it. They **do not chain**: `a < b < c` is a syntax error rather than quietly
  meaning `(a < b) < c`, which would compare a flag against a quantity.
- **Equality is IEEE, deliberately.** A sheet's `=` is exact, and widening it to a tolerance here
  would make this evaluator disagree with the workbook a formula came from.
- **`IF` evaluates all three arms, then selects.** Safe because the grammar has no effects: the
  guarded division still produces an infinity, and that infinity is simply never chosen.
- **Selection is a three-way walk, not two `zip`s.** Chaining `zip` needs a sentinel to carry
  "the condition was false" between passes, and any sentinel is a value the true branch might
  legitimately hold — a `NaN` from a division inside it would then silently select the false
  branch. Caught while writing it, not by a test.

## Task 5 — Logical and aggregation tranche (proposal Phase 2b)

**Reordered ahead of TVM on the function census.** `AVERAGE` and `ROUND` appear in real
workbooks; `PMT`, `IPMT`, `PPMT`, `XIRR`, `XNPV`, `MIRR` and `FV` appear in neither. `AND`, `OR`
and `NOT` complete the logical family `IF` opened, and none of them needs the error-value design
work that `ISERROR`/`ISNA` would.

- [x] `AVERAGE`, `ROUND`, `AND`, `OR`, `NOT`, period-wise like everything else.
- [x] **`ROUND` is half away from zero**, which is Excel's rule and not the banker's rounding a
      naive implementation lands on. Pinned by a test on `.5` cases in both directions.
- [x] `ROUND` accepts negative digits — `ROUND(1234, -2)` is 1200 in Excel.
- [x] `AND`/`OR` are variadic and return 1 or 0, so they compose with `IF` and with arithmetic.
- [x] Commit.

## Task 6 — TVM function tranche (proposal Phase 2c)

- [x] `NPV`, `IRR`, `PMT`, `IPMT`, `PPMT` registered, delegating to the canonical implementations.
- [x] **`NPV` binds to `npvExcel`, not `npv`** (decision D5), pinned by a test asserting the two
      *differ* so the binding cannot be quietly changed.
- [x] **Two argument shapes, distinguished.** `NPV` and `IRR` consume a whole series and give one
      number, broadcast across the periods it came from — a formula pointed at a range.
      `PMT`/`IPMT`/`PPMT` take scalars and compute independently in each period — a formula
      filled across a row. The checklist had not separated these; they are not interchangeable.
- [x] **`PMT`/`IPMT`/`PPMT` are negated to Excel's sign convention.** `payment()` returns the
      size of the instalment; Excel returns what leaves the payer's pocket. Same magnitude,
      opposite sign — the exact shape of plausible-wrong-number this tranche exists to catch.
- [x] **`FV` deliberately not registered.** Excel's `FV(rate, nper, pmt, [pv], [type])` is an
      annuity's future value; this library's `futureValue(presentValue:rate:periods:)` grows a
      lump sum. Same name, different function. A test pins it as *unknown* so the gap is
      deliberate and visible rather than an oversight waiting to be "fixed" wrongly.
- [x] **`XNPV`, `XIRR`, `MIRR`, `CUMIPMT`, `CUMPRINC` deferred.** The first two need per-cash-flow
      dates, which a period-indexed series does not carry; the last two need a period *range*
      argument, which the grammar has no way to express. Each needs machinery, not a binding, and
      none appears in either reference workbook.
- [x] Commit.

## Task 7 — Statistical function tranche (proposal Phase 2d)

- [x] `STDEV`, `STDEVP`, `VAR`, `VARP`, `MEDIAN`, `COUNT`, delegating to `stdDevS`, `stdDevP`,
      `variance(_:_:)` and `median(_:)`.
- [x] **Both denominator pairs pinned against each other**, not merely against a fixture. A test
      asserts `STDEV` and `STDEVP` *differ*, and that the sample estimate is the larger — so a
      binding swapped in either direction fails rather than producing a number that passes every
      eye test.
- [x] `MODE`, `PERCENTILE` and `COUNTIF` deferred: `MODE` has no single answer for a multimodal
      series and Excel's choice would need verifying, `PERCENTILE` needs an interpolation rule
      matched to Excel's, and `COUNTIF` takes a criteria *string*, which the grammar has no way
      to express.
- [x] Commit.

## Task 8 — `Rollforward` and `PeriodDriver` (proposal Phase 2e)

- [x] `Rollforward(opening:closing:seed:)` and the `PeriodDriver` loop.
- [x] A within-period cycle still resolves through `CycleSolver`.
- [x] A cross-period carry loop is refused as `rollforwardCycle` before any period runs.
- [x] **Year-one interest is 11.75 on a 120 draw at 10%**, with closing 115 and a sweep of 5 —
      the average-balance figure. Beginning-balance accrual gives 12.00 with no cycle at all, and
      the test asserts the result is *not* that, so the two cannot be confused.
- [x] A failure names the period it happened in.
- [x] **Deviation from the sketch:** `Rollforward` is generic over `T`, not `Double`. There is no
      total conversion from `Double` into an arbitrary `Real`, and the alternatives were a
      failable string round-trip or a silent fallback to zero — a seed that quietly becomes zero
      is a balance sheet that quietly starts empty.
- [x] **Bug found and fixed:** `accountNames(in:)` walked *tokens*, so a function name was
      collected as a required account. Correct before functions existed, silently wrong after —
      it made every function look like a missing input and corrupted the dependency graph built
      from it. Now walks the parse tree. This is public API and was found only because
      `PeriodDriver` was the first thing to call a function from inside a `ModelDefinition`.
- [x] Commit.

---

## Done when

- [ ] All eight tasks green, committed individually.
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

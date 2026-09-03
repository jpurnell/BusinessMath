# TypedModelAuthoring Phases 3 and 4 — the typed layer (2.9.0)

Design: `project/plans/proposals/TypedModelAuthoring.md` §4 Part 1, §15 Q5, Q6, Q7.

Phase 3's gate was the compile-time budget, and it has been **measured**: no expression in the
§4 example or a twenty-term stress file exceeds 10 ms to type-check, and the whole file compiles
in 0.59 s. Alternative 3 (runtime unit checking) is not needed. See §15 Q5.

Two decisions the proposal records and this checklist implements: the typed handle is
`LineItem<U>`, not `Account<U>` (§15 Q6 — the name is taken by `Account<T: Real>` on the
statement surface), and `factor(_:)` exists because `1 + g` cannot be written (§15 Q7).

**Gate: the negative cases fail to compile, `rateBasisMismatch` is thrown for an annual rate
applied over monthly periods, and `BusinessMathExcel` can consume the layer.**

---

## Task 1 — Units and the typed handle

- [x] **RED** — `Unit`, `Money`, `Rate`, `Ratio`, `Duration`; `LineItem<U>` with its optional
      `basis`. `LineItem<Money>("Revenue") != LineItem<Ratio>("Revenue")` at the type level.
- [x] **RED** — the existing `Account<T: Real>` on the statement surface still compiles and is
      untouched. This is the collision §15 Q6 exists to prevent, so it gets a test rather than
      an assumption.
- [x] Commit.

## Task 2 — `Expr<U>` and the unit algebra

- [x] **RED** — every legal combination in §4 renders the formula the string API expects.
- [x] **RED** — `money()`, `ratio()`, `rate(_:per:)`, and `factor(_:)` for the growth idiom.
- [x] **RED** — negative cases *fail to compile*. Verified by a build that must fail, not by an
      assertion that cannot see a compile error.
- [x] Commit.

## Task 3 — Binding to `ModelDefinition`

- [x] **RED** — `defining(_:as:)` delegates to the string API and changes nothing beneath it.
- [x] **RED** — `series(for:in:)` reads a typed result out of an evaluation.
- [x] **RED** — the §4 cash sweep builds, validates, and evaluates to the same numbers the
      string form produces. The typed layer must be a spelling, not a second engine.
- [x] Commit.

## Task 4 — `validateUnits()` and rate basis (Phase 4)

- [ ] **RED** — `missingRateBasis` for a `Rate` item used where a basis is required.
- [ ] **RED** — `rateBasisMismatch` for an annual rate applied over monthly periods.
- [ ] **RED** — `conflictingUnits` when two items share a name and differ in unit.
- [ ] Commit.

## Task 5 — Release 2.9.0

- [ ] `1.7-TypedModelAuthoringGuide.md` (§16 requires a narrative article), indexed in the DocC
      catalogue — checked by listing the directory, not by assuming the slot is free.
- [ ] CHANGELOG, `master_plan.md`, capability map.
- [ ] Quality gate `--check all`, 0 errors / 0 warnings, counted.
- [ ] Tag `v2.9.0`, push.
- [ ] Move this file to `project/checklists/completed/`.

---

## Not in this checklist

- **Phase 6** — deleting `BusinessMathDSL`. Breaking, so 3.0.0.
- **`BusinessMathExcel` Phase 5c** — `TypedSourceWriter`, which this release unblocks.

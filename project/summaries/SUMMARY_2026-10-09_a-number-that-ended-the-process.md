# A number that ended the process, and a guard that hid a project instead

**2026-10-09** · branch `fix/capital-allocation-contaminated-input`, three commits on `f10fc8eb`,
unreleased and intended as 3.0.0-alpha.12 · 9,005 tests / 839 suites

A security hotfix found by a debt survey, not by a failing test. One entry in
`.quality-gate-baseline.json` — `fallback.int-conversion-unguarded` on
`CapitalAllocationOptimizer.swift` — was covering a conversion that a caller could reach.

---

## What was wrong

`optimizeIntegerProjects` builds a table of `(projects + 1) × (Int(budget) + 1)` values and
indexes it with `Int(capitalRequired)`. Measured against the source as it stood, by running it:

| input | result |
|---|---|
| `capitalRequired: -5` | `Fatal error: Index out of range` |
| the only project has `capitalRequired: .nan` | `Fatal error: Range requires lowerBound <= upperBound` |
| `capitalRequired: .nan` among clean projects | that project left out; the answer looks normal |
| `budget: .nan`, `+inf`, `-1`, `1e300` | "fund nothing", `totalNPV` 0 |
| `budget: 1e12` | an 8 TB table requested — **not run**, see below |

The alpha.8 guard screened non-finite and larger-than-`Int` values. It did not screen sign, it
emptied a list and then ranged over `1...0`, and it never bounded the table.

The consumer path is `businessMathMCP`'s `optimize_capital_allocation` tool with
`method: "optimal"`: `projects[i].cost` and `budget` go from the JSON arguments into this
function with no check between. That package pins alpha.7, which predates even the alpha.8
guard, so there `"cost": 1e300` traps at `Int(_:)` as well.

## What changed

- `optimizeIntegerProjects(validating:budget:)` — new, throwing, refuses by name with the
  existing `BusinessMathError` cases. No new error case, no changed signature.
- `optimizeIntegerProjects(projects:budget:)` — same signature, now marks unusable input with
  `nan` totals. It used to drop the project.
- `maximumAmount` (2^53) and `maximumTableCells` (10,000,000), both documented as limits of
  representation and resource.
- The table is one row of values and one bit per cell, and only as wide as the affordable
  projects' combined cost.

## How "the same bits" was established

`CapitalAllocationCharacterisationTests` went in first, alone, green against the untouched
source (`fae3f8f0`). After the change, 27 more cases were added for budgets far above total
cost — the shape the narrower table affects — and their digests were measured in a second
checkout of `fae3f8f0`, not from the new code. The finished file passes in both trees.

## Honest notes

- Red was observed for every new test before the fix: three by the test process dying (the two
  fatal errors above, one of them twice), fifteen by assertion against a stub that exposed the
  new names over the old behaviour, and three controls that pass before and after by design.
  `BudgetFarAboveTotalCost_IsAnsweredNotAllocated` was never run red; doing so asks the machine
  for 8 TB.
- The ceiling refuses some inputs that used to run. A budget of 5,000,000 over ten projects that
  can spend all of it is a 55-million-cell table: it took seconds and 440 MB before, and is now
  a `resourceExhausted` error that says to use a coarser unit.
- Fractional costs are truncated when sized. That is a real defect, it is older than this work,
  and it is pinned and documented rather than fixed.
- The greedy allocator was read and left alone. Nothing in it traps.

## Also on the branch

`TrappingDistributionTests` wrote `1e-320` as a literal, which the Xcode build warns about and
`swift build` does not, so `--check all` on `main` was carrying one warning. It is built from
`Double.leastNonzeroMagnitude * 2024` now — the same bits, asserted — in a commit of its own.

## Next

- `businessMathMCP` needs the release this becomes, and should call the validating form.
- Decide whether fractional amounts should be refused, rounded up, or scaled.

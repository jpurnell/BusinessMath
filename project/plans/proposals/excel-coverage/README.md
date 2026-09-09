# Data for PROPOSAL_excel_function_coverage.md

Three files, all generated rather than written, and all regenerable.

| File | What it is |
|---|---|
| `businessmath_work.tsv` | **The work list.** One row per item this package must implement, with its status, signature and reference. This is the file to work from. |
| `psi_functions.tsv` | Frontline's complete PSI surface, 295 functions, fetched from their documentation. The authority for names and argument order. |
| `corpus_usage.tsv` | How often each function appears across 79 real workbooks. Priority only — it says what gets used, never what exists. |

## Regenerating

`corpus_usage.tsv` comes from BusinessMathExcel:

```
BUSINESSMATHEXCEL_CORPUS="<roots>" swift test --filter testWhichFunctionsTheCorpusCalls
```

`psi_functions.tsv` was fetched from solver.com and Frontline's Reference Guide PDFs. Several of
their pages render as images, so a text-only scrape silently misses ten distributions.

`businessmath_work.tsv` is the join of those two against an inventory of this package, filtered to
what is missing here.

---

## The second numeric column counts SHEETS, not workbooks

Settled 2026-09-09 by reading the generator, after most of a day spent inferring around it.
Two sessions produced four successive explanations for an apparent set of discrepancies in
these files. **All four were wrong, and there was never a discrepancy.**

`corpus_usage.tsv` is produced by `testWhichFunctionsTheCorpusCalls` — **a sibling
repository, not this one**: `BusinessMathExcel/Tests/BusinessMathExcelTests/CorpusMeasurementTests.swift`,
the test at line 183, the corpus gate at line 59, the print at line 220. It walks every
`.xlsx` under `BUSINESSMATHEXCEL_CORPUS`, and inside each workbook (lines 195–203):

```swift
for sheet in workbook.sheets {
    var onThisSheet: Set<String> = []
    for (_, ast) in imported.formulaASTs {
        for name in functionNames(in: ast) {
            callsByName[name, default: 0] += 1
            onThisSheet.insert(name)
        }
    }
    for name in onThisSheet { sheetsByName[name, default: 0] += 1 }
}
```

The accumulator is `sheetsByName`, incremented once per **sheet**, and printed as
`"\(calls) calls, \(sheets) sheets"`. Both numbers are written in the same loop over the same
files. The coverage matrix relabelled that column *books*, and every confusion below follows
from the relabelling alone.

### What that resolves

| Apparent problem | Actual explanation |
|---|---|
| `SUM` in 338 "books" from a 79-workbook sweep | 338 **sheets**, 4.3 per workbook |
| `EXCEL` half maxes at 338, `PSI` half at 17 | One sweep. Psi functions simply appear on fewer sheets — 79 general workbooks are mostly not Risk Solver models |
| `STDEV.S` 42 here against 79 in a source comment | 42 sheets against 79 workbooks. Two different quantities, never in conflict |
| No row has `calls > 0` with `books = 0` | Same loop writes both. Perfect alignment is structural, not evidential |
| `PsiOutput` 24/11 here against 167/41 documented | 79 workbooks against 2,236. Sample size, not a partial sweep |

### What a zero means, stated once and correctly

**A `0 / 0` row was genuinely absent from every formula on every sheet of 79 workbooks.**
The sweep parses each formula to an AST and records every function name it finds, so a
function that never appears was really looked for and really not there.

That is one well-defined sample. It is not the ≥338-workbook population an earlier revision of
this file claimed, and it is not the "inherits a smaller sweep's blind spots" that the
revision after that claimed. Both were mine and both were inferences where the source was
readable. 79 workbooks, all sheets.

`COMPLEX`, every `IM*` and all four `FORECAST.ETS*` rows are zero under it — a real finding
about 79 real workbooks, and not a ranking signal for the 726 other zero rows, which are the
same single observation.

### The answer was eleven lines above this section the whole time

Worth recording precisely, because it is more useful than the finding.

The **Regenerating** heading near the top of this file has said *"`corpus_usage.tsv` comes
from BusinessMathExcel"* since `76cc2e58`, which predates every message of the investigation
that followed. Neither session was missing information. One searched its own `Sources/`,
`Tests/` and `scripts/`, found no generator, and concluded there was none — true of the tree
searched, false as written. The other — this one — opened this very file with `head -6`,
which stops seven lines short of the sentence naming the generator, and then spent four
successive explanations inferring what the column meant.

`head -6` on the file containing the answer is the first of the search disciplines failing on
the document that would have ended the search. If that discipline needs a hard form, it is:
**when you truncate a file you are consulting for provenance, you have not consulted it.**

And the boundary is the part that beat both sessions independently: **the generator is not
necessarily in the repository holding the data.** When a README names a sibling repository,
that is the first place to look, not the last.

### Regenerating, and what to fix while doing it

The provenance is fully reconstructable and the measurement is repeatable. This section is
the one that mattered, and it was here before any of the confusion above:

```
BUSINESSMATHEXCEL_CORPUS="<roots>" swift test --filter testWhichFunctionsTheCorpusCalls
```

Note this is a **different** environment variable from `RISK_SOLVER_WORKBOOKS`, which gates
the Risk Solver workbook tests in SwiftExcelFunctions, and possibly a different corpus. When
either is next run, three things are worth doing:

1. **Rename the matrix column from `books` to `sheets`.** It is the whole of this section.
2. **Record the workbook count and the date beside the data**, not only in this README. The
   one Psi sweep that stated its denominator — 2,236 workbooks, in
   `PROPOSAL_psi_bindings.md` §2 — was the only measurement all day that needed no forensics.
3. **Emit both a sheet count and a workbook count.** The sweep has the workbook loop already;
   it discards the per-workbook distinct-name set. Ten lines, and the ambiguity cannot recur.

### For anyone comparing these numbers to another source

Three measurements of Psi usage exist and all three are correct about different things:

| Source | Denominator | `PsiOutput` |
|---|---|---|
| `corpus_usage.tsv` / the matrix | 79 workbooks, counted in sheets | 24 calls / 11 sheets |
| `PROPOSAL_psi_bindings.md` §2 | 2,236 workbooks | 167 calls / 41 workbooks |
| `BuiltinRiskSolverStatistics.swift` doc comments | six simulation models | varies |

Before comparing any two of them, check which row of that table each came from.

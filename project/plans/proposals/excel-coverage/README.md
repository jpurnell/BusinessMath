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

## The two halves of this data were measured against different populations

Added 2026-09-09, after a cross-session disagreement over Psi call counts turned out to be a
disagreement about *denominators*. Anyone reading a `0 calls / 0 books` row out of these files
needs this, because the strength of that zero differs by an order of magnitude depending on
which half of the matrix the row sits in.

Group the matrix by its source tag and take the maxima:

| Tag | Rows | Max books | Max calls | Row at the maximum |
|---|---|---|---|---|
| `EXCEL` | 518 | **338** | 168,779 | `SUM` / `IFERROR` |
| `PSI` | 295 | **17** | 95 | `PsiTriangular` / `PsiBaseCase` |

Only **19 of 295** PSI rows carry any books at all, and the largest is 17. A ceiling of
seventeen workbooks across an entire function family, against three hundred and thirty-eight
for the Excel family, is not sampling variation — the two halves were swept over different
sets of files.

**What follows, and it is the part that matters for sequencing:**

- **A zero on an `EXCEL` row is strong evidence.** The function is absent from a corpus of at
  least 338 workbooks. `COMPLEX`, every `IM*`, and all four `FORECAST.ETS*` rows are `EXCEL`
  rows, so their zero demand is well evidenced.
- **A zero on a `PSI` row is weak evidence.** The population that produced those counts tops
  out at seventeen workbooks. Absence from ≤17 files says very little, and every
  `PsiForecast*` row is a `PSI` row.

So "nothing unbound has any corpus demand" holds firmly for the Excel half and thinly for the
Psi half, and the two should not be quoted as one number.

**This also explains a disagreement that looked unexplainable.** A source comment recording
`PsiOutput` at 167 calls / 41 books against this matrix's 24 / 11 is not a contradiction: it is
a larger Psi sweep than the one that produced these files. And `STDEV.S` agreeing on calls
exactly (86,410) while differing on books (42 here, 79 there) is a separate question about the
Excel half's book denominator, not the same fault.

**"The 41-workbook corpus" is wrong** and was repeated on both sides of the conversation all
day. `SUM` alone appears in 338 workbooks here. Forty-one was only ever how many carried Psi
under some sweep, and it is not the denominator of anything in the `EXCEL` half.

Unresolved: which Psi sweep is authoritative, and why the two Excel book counts differ. Both
need the private workbook corpus (`RISK_SOLVER_WORKBOOKS`) to settle.

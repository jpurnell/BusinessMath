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

### "41 workbooks" is a numerator, not a corpus size

Repeated on both sides of the conversation all day as though it were the population. It is
**41 of 2,236** — the number of workbooks in the document tree that contain *any* Psi
function, from the one sweep that records its own denominator: `PROPOSAL_psi_bindings.md` §2
in SwiftExcelFunctions, *"Measured across 2,236 workbooks: 27 distinct functions, 1,950 calls,
41 workbooks."* Correct number, wrong framing. Quote it as "41 of 2,236" and it stops
misleading.

That sweep is **authoritative for the Psi family**, because it is the only one of the three
that states what it measured and when. Against it, this matrix's `PSI` half is not merely a
different population but a **demonstrably partial** one — three to five times lower on every
shared row:

| Function | Authoritative (2,236 swept) | This matrix's `PSI` half |
|---|---|---|
| `PsiOutput` | 167 / 41 | 24 / 11 |
| `PsiMean` | 108 / 23 | 31 / 13 |
| `PsiPercentile` | 28 / 3 | 28 / 4 |
| `PsiStdDev` | 21 / 4 | 4 / 3 |

**So a `PSI` zero in these files is not weak evidence — it is evidence from a sweep known to
undercount.** Do not sequence on it. Use the proposal's table for anything in the Psi family.

### The `EXCEL` half has a third denominator, and it is probably not 2,236 either

`SUM` tops out at 338 books here, with `IF` at 239 and a steep fall after — no plateau to read
a sweep size off directly. But `SUM` appears in essentially every non-trivial workbook, so a
sweep of 2,236 finding it in 338 (15%) is not credible. The `EXCEL` half's denominator is far
more likely to sit close to its own ceiling, near 338, with `SUM` at or near 100% of it. Only
**69 of 518** `EXCEL` rows carry any books at all, and 88–90 distinct functions observed in
total is low for two thousand workbooks and reasonable for a few hundred.

Stated as an inference rather than a fact, because nothing in these files records it. The
practical consequence stands either way: **there are three populations here, not two**, and no
count should be compared across them.

An `EXCEL` zero remains the strong one — absent from at least 338 workbooks, and plausibly
from all of that half's sweep.

### Still unresolved

Why the two `EXCEL` book counts differ — `STDEV.S` at 42 here against 79 in a source comment,
with the call count agreeing exactly at 86,410. That one is inside the Excel half and is not
explained by any of the above. It needs the private workbook corpus
(`RISK_SOLVER_WORKBOOKS`) to settle.

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

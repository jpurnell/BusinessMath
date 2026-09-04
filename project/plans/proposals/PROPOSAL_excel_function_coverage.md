# Proposal — Excel and Risk Solver function coverage

**Status:** draft, 2026-09-04.
**Origin:** measured in BusinessMathExcel against 79 real workbooks — teaching models, a production
credit model, and a 104-sheet media model — while building a spreadsheet-to-graph translator.
**Companion:** `BusinessMathExcel/project/plans/proposals/PROPOSAL_spreadsheet_graph.md` §4.

---

## 0. Scope — narrowed 2026-09-04

**This proposal is now about mathematics only.** Excel-facing names, argument order, sign
conventions and error semantics belong to `SwiftExcelFunctions`, a separate package; the coverage
matrix and the architecture that decided this live in
`BusinessMathExcel/project/plans/proposals/PROPOSAL_swift_excel_architecture.md`.

What BusinessMath is asked for is the maths behind the bindings:

- **The distributions Frontline documents and BusinessMath lacks** — Cauchy, Laplace, Erlang,
  Fréchet, Lévy, LogLogistic, InvNormal, NegBinomial, Johnson SB/SU, Kumaraswamy, Burr12, Dagum,
  Metalog, Myerson, and the AR/ARMA/GARCH stochastic-process family.
- **Sampling methods** — Latin hypercube, Sobol and Halton sequences, stratified and importance
  sampling. Frontline ships all of these; BusinessMath samples pseudo-randomly only.
- **Small absences with Swift-appropriate signatures** — `RATE`, `NPER`, `PDURATION`, `NOMINAL`,
  and the depreciation family. Excel's sign conventions are applied at the binding, not here,
  exactly as `PMT` already binds to `-payment(...)`.
- **`YEARFRAC`'s day-count conventions**, which are bond mathematics rather than calendar
  arithmetic.

**One thing to remove rather than add.** If `SwiftExcelFunctions` becomes the Excel function
authority, `FormulaEvaluator.Function` is a second Excel registry in the same dependency chain —
two tables that can disagree about `AVERAGE` or `NPV`, which is the failure its own documentation
names. Narrow it to the period-local `ModelDefinition` grammar it exists for, and let it stop
looking like a general Excel surface.

§1–§8 below are the measurement that produced this list. They are kept because they record how it
was arrived at, but §8's tables are superseded by the matrix named above, which folds in the 73
functions SwiftXLSX already implements.

---

## 0.1 Original provenance note

**Superseded 2026-09-04 — read §8 first.** The tables in §3 are corpus-derived and remain useful
as *priority*. The authoritative enumeration is §8, built from Microsoft's and Frontline's own
references, and it is what a coverage plan should be read from.

The original note follows, because it is still true of §3 and explains why §8 exists.

**Everything in §1–§5 is observational.** Every function named, and every count beside it, comes from
scanning 79 workbooks. Nothing here is derived from Microsoft's worksheet-function reference or
from Frontline's PSI function reference, and neither was consulted.

That makes this a **first pass over what these models happen to use**, not a coverage plan. Three
specific limits follow, and none is cosmetic:

1. **The sample is biased toward its sources.** Two Tuck course corpora, one credit model, one
   media model. Text functions, database functions, dynamic-array functions (`XLOOKUP`, `FILTER`,
   `LET`, `LAMBDA`) and most of the engineering and information families are absent from these
   files — which says nothing about whether an arbitrary workbook uses them.
2. **Even the sample is only half-read.** 53% of the corpus's formulas do not currently parse in
   SwiftXLSX and were recovered here by scanning raw text. A function used only inside a construct
   the scanner mis-tokenises is invisible to these tables.
3. **Absence of evidence is recorded as absence.** Rows in §3.1 marked "—" for calls are functions
   inferred from a naming pattern (`STDEV.P` because `STDEV.S` is present), not observed. They are
   the only entries here not measured, and they are marked.

Excel exposes roughly 500 worksheet functions and Risk Solver's PSI family runs to dozens of
distributions plus statistics and property functions. This document covers **19 Psi names and
about 30 Excel names.** The gap between that and *translate an arbitrary model* is the subject of
§6, which is a plan rather than a table, because writing the missing names out from memory would
produce a specification that looks authoritative and contains invented functions.

---

## 1. What this is, and what it is not

BusinessMathExcel evaluates a spreadsheet's formulas against a graph of its cells. Every function
a formula calls has to come from somewhere, and the question of *where* has a specific answer that
is not "a maths library":

| Source | Functions | Why there |
|---|---|---|
| The evaluator | `IF`, `IFERROR`, `ISERROR`, `ISNA`, `ISBLANK` | Excel's error propagation and coercion. Not arithmetic |
| The graph | `VLOOKUP`, `HLOOKUP`, `INDEX`, `MATCH`, `OFFSET`, `INDIRECT`, `ADDRESS`, `ROW`, `COLUMN` | These compute an *address* and read it. Edge operations |
| Swift / Foundation | `SUM`, `MIN`, `MAX`, `ABS`, `ROUND`, `MOD`, `YEAR`, `MONTH`, `DAY` | Primitives and calendar arithmetic |
| **BusinessMath** | statistical and financial, and everything Risk Solver | Where a second implementation could disagree with the first |

**This proposal covers only the fourth row.** Nothing here asks BusinessMath to learn spreadsheet
semantics or reference resolution; both belong downstream and are named only so the boundary is
explicit.

## 2. The finding that shapes it

**Almost nothing here needs new mathematics.** BusinessMath already computes essentially every
quantity the corpus asks for. What is missing is a *name* an Excel formula can reach it by.

That is the same shape as five defects already found this way in SwiftXLSX and fixed upstream:
information the library already understood, with no way for a caller to reach it. It makes this
proposal much smaller, and much higher confidence, than "implement 19 functions."

Already present and unreachable by name:

| Needed for | Already in BusinessMath |
|---|---|
| `PsiNormal` | `distributionNormal.swift` |
| `PsiLogNormal` | `distributionLogNormal.swift` |
| `PsiUniform`, `PsiIntUniform` | `distributionUniform.swift` |
| `PsiTriangular` | `distributionTriangular.swift` |
| `PsiBernoulli` | `bernoulliTrial.swift` |
| `PsiDiscrete` | `Discrete Distribution/` |
| `PsiMean`, `PsiStdDev` | `SimulationStatistics.swift` |
| `PsiPercentile` | `MonteCarlo/Percentiles.swift` |
| `PsiBVar`, `PsiCVar` | `MonteCarlo/RiskMetrics.swift` |
| `STDEV.S`, `VAR.P`, … | registered already as `STDEV`, `VARP` |
| `COVARIANCE.P` | covariance, computed but unregistered |

## 3. Measured usage

589,199 function call sites across 79 workbooks. `FormulaEvaluator<Double>.Function` currently
registers 21 names.

### 3.1 Tier 1 — aliases and bindings. No new mathematics

Highest value per unit of work in the whole proposal. `STDEV.S` alone is more calls than every
financial function in the corpus combined.

| Excel name | Calls | Sheets | Binds to | Note |
|---|---|---|---|---|
| `STDEV.S` | 86,410 | 42 | `STDEV` | Excel 2010 renamed it; the registry has only the legacy spelling |
| `COVARIANCE.P` | 124 | 4 | covariance | Computed, never named |
| `STDEV.P` | — | — | `STDEVP` | Same rename, not yet seen in this corpus |
| `VAR.S` / `VAR.P` | — | — | `VAR` / `VARP` | Same rename |
| `COVARIANCE.S` | — | — | sample covariance | Completes the pair |

**The dotted spellings are the modern ones.** Any workbook saved by Excel 2010 or later uses them,
and a registry holding only the legacy names silently misses more than half the statistical calls
in this corpus. Recommend registering both spellings against one implementation, permanently —
Excel still accepts the legacy names, so both remain live.

### 3.2 Tier 2 — Risk Solver distributions

Uncertain inputs. Each already has a `DistributionRandom` conformer; each needs an Excel-facing
name and Risk Solver's argument order.

| Risk Solver name | Calls | Sheets | Arguments | Implementation |
|---|---|---|---|---|
| `PsiTriangular` | 60 | **17** | min, most likely, max | `DistributionTriangular` |
| `PsiUniform` | 24 | **16** | min, max | `DistributionUniform` |
| `PsiBernoulli` | 45 | 2 | p | `bernoulliTrial` |
| `PsiLogNormal` | 40 | 1 | mean, stdev | `DistributionLogNormal` |
| `PsiDiscrete` | 20 | 8 | values, probabilities | `Discrete Distribution` |
| `PsiNormal` | 12 | 4 | mean, stdev | `DistributionNormal` |
| `PsiIntUniform` | 6 | 1 | min, max, integer-valued | `DistributionUniform`, rounded |

Sheet count matters more than call count here: an uncertain input appears once and is read
everywhere. `PsiTriangular` on 17 sheets and `PsiUniform` on 16 are the two that matter.

**Watch the argument order.** Risk Solver's `PsiTriangular(min, mostLikely, max)` and
`PsiLogNormal(mean, stdev)` state parameters in a specific order and, for lognormal, in terms of
the *arithmetic* mean rather than the log-scale parameters. A binding that silently reorders or
reinterprets is worse than no binding, because it produces numbers.

### 3.3 Tier 3 — Risk Solver statistics over simulation results

These read a completed simulation rather than defining an input, so they need a simulation in
scope. Every underlying computation exists.

| Risk Solver name | Calls | Sheets | Implementation |
|---|---|---|---|
| `PsiMean` | 31 | 13 | `SimulationStatistics.mean` |
| `PsiPercentile` | 28 | 4 | `MonteCarlo/Percentiles` |
| `PsiTarget` | 5 | 2 | P(X ≤ t) — empirical CDF, present |
| `PsiStdDev` | 4 | 3 | `SimulationStatistics.stdDev` |
| `PsiBVar` | 1 | 1 | `RiskMetrics` — value at risk |
| `PsiCVar` | 1 | 1 | `RiskMetrics` — conditional value at risk |

### 3.4 Tier 4 — genuinely new, and small

| Excel name | Calls | Sheets | Why BusinessMath |
|---|---|---|---|
| `SUMPRODUCT` | 805 | **134** | The widest reach of any unregistered function. Trivial arithmetic, but it is the kernel of every LP objective and constraint in the corpus |
| `YEARFRAC` | 3,425 | 9 | Day-count conventions (30/360, actual/365, actual/actual) are bond mathematics, not calendar arithmetic. Getting basis handling wrong is a silent pricing error |
| `EOMONTH` | 1,657 | 12 | Arguably Foundation, but it is a settlement-date primitive and travels with `YEARFRAC` |

`SUMPRODUCT` deserves emphasis. It reaches more sheets than `NPV`, `MIN`, `MAX` and `ABS`
combined, because it is how a spreadsheet writes a dot product — which is how it writes an
objective function.

## 4. What is deliberately excluded

### 4.1 Not mathematics

`IFERROR` (106,733 calls), `VLOOKUP` (99,795), `COLUMN` (86,620), `SUMIFS` (78,816), `ADDRESS`,
`INDIRECT`, `OFFSET`, `MATCH`, `ISBLANK`. Larger numbers than anything above, and none belongs
here: they are error semantics and address arithmetic. BusinessMathExcel owns them.

### 4.2 The Psi annotations are not functions

Six Risk Solver names appear in the corpus that compute nothing:

| Name | Calls | Sheets | What it declares |
|---|---|---|---|
| `PsiBaseCase` | 95 | 7 | the deterministic value to use when not simulating |
| `PsiName` | 25 | 7 | a label for a distribution cell |
| `PsiOutput` | 24 | 11 | this cell is an output to collect |
| `PsiSenParam` | 15 | 9 | a sensitivity parameter |
| `PsiOptParam` | 14 | 11 | an optimisation parameter |
| `PsiSimParam` | 5 | 2 | a simulation parameter |

These are **role declarations**, and they answer a question BusinessMathExcel already has open.
Its `GraphPartition` sorts cells into parameter / objective / calculation / unreachable from graph
topology alone, and cannot distinguish a *decision variable* from a parameter, because the two are
topologically identical — fed by nothing, feeding something. Excel's Solver states its decisions in
the defined name `solver_adj`; `PsiOptParam` and `PsiOutput` state the same thing for Risk Solver.

So they are read, not computed, and they belong downstream with `solver_adj`. Named here only so
that a reader counting Psi functions is not surprised to find six missing.

## 5. Proposed shape

1. **Register both spellings.** `STDEV`/`STDEV.S`, `STDEVP`/`STDEV.P`, `VAR`/`VAR.S`,
   `VARP`/`VAR.P`, plus `COVARIANCE.P`/`COVARIANCE.S`. One implementation, two names. Excel
   accepts both, so both must live.
2. **A `RiskSolver` namespace** binding the Psi distribution and statistic names to the existing
   types, with argument order and parameterisation taken from Risk Solver's documentation and
   asserted in tests. This is where a wrong binding does real damage, so the tests should state
   the expected value for a fixed seed rather than merely that a number comes back.
3. **`SUMPRODUCT`, `YEARFRAC`, `EOMONTH`** implemented, with `YEARFRAC`'s basis parameter covering
   all five conventions rather than defaulting silently to one.
4. **Nothing else.**

### 5.1 A constraint on where these can live

`FormulaEvaluator<Double>.Function`'s own documentation says it acts *period by period* and that
"aggregating down a column is a different operation and is deliberately not expressible: this
grammar is period-local."

That is correct for `ModelDefinition` and it means **`FormulaEvaluator.Function` is the wrong home
for most of this**. `SUMPRODUCT` over two ranges, `PsiPercentile` over a simulation's results, and
`STDEV.S` over a column all aggregate across cells by construction.

Recommend the aggregating functions live as ordinary BusinessMath API taking collections — as
`npvExcel(rate:cashFlows:)` already does — with `FormulaEvaluator.Function` extended only where a
function genuinely is period-local. The registry stays the *naming authority*; it does not have to
be the call target.

## 6. Getting to coverage that is not corpus-shaped

### 6.1 Why full coverage is not a prerequisite

The translator does not need every function implemented in order to be correct on an arbitrary
model. It needs to never be **silently wrong**, which is a different and much weaker requirement:

- **Representation is already complete.** A function call is a name and a list of arguments. The
  graph holds `SERIESSUM(x, n, m, coefficients)` as faithfully as it holds `SUM(A1:A10)` without
  knowing what either means. Structure survives regardless of coverage.
- **Evaluation reports its gaps.** A function with no implementation makes its node unevaluated
  and named, not dropped and not guessed.
- **A cached value is never substituted for a computation that could not be performed.** This is
  already the rule downstream: the number would be right once and wrong forever after the first
  input changed.

So coverage is a gradient — *how much of a workbook can be recomputed* — rather than a gate. A
model using two unimplemented functions is translated, with two holes that are named. That is a
usable result and an honest one.

### 6.2 What full coverage actually requires

Three sources, in order of authority:

1. **Microsoft's worksheet-function reference**, for the complete Excel surface with argument
   signatures and the legacy/dotted name pairs. This is the only way to get §3.1's alias table
   right in general rather than for the two pairs this corpus revealed.
2. **Frontline's PSI function reference**, for the complete Risk Solver surface. The corpus shows
   19 names; the real set includes many more distributions and a family of property functions
   (truncation, shifting, correlation) that change what a distribution *means* rather than adding
   new ones.
3. **The corpus**, kept — but demoted to what it is good for: **priority**, not enumeration. It
   cannot say what exists; it says what gets used, and `SUMPRODUCT` on 134 sheets is a fact no
   specification would have told us.

The output is one matrix over the union of (1) and (2), each function marked:

| Marking | Meaning |
|---|---|
| **implemented** | reachable by an Excel name today |
| **bindable** | BusinessMath computes it; no name reaches it — §2's category, and expected to be large |
| **new** | genuine implementation work |
| **not ours** | evaluator or graph, per §1's table |
| **out of scope** | text, database, cube, web families — no numerical meaning to preserve |

Ordered within *bindable* and *new* by corpus frequency where available, and by argument-signature
simplicity where not.

### 6.3 Sequencing

The matrix is worth building **before** implementing beyond Tier 1, because §2's finding suggests
*bindable* will be much the largest category, and that changes the work from "implement functions"
to "expose what already exists" — a different order of effort and a different risk profile.

Tier 1 (§3.1) does not need to wait. `STDEV.S` is 86,410 calls, the implementation exists, and the
alias is correct whatever the matrix later says.

## 7. How to check this

Every number above regenerates. In BusinessMathExcel:

```
BUSINESSMATHEXCEL_CORPUS="<roots>" swift test --filter testWhichFunctionsTheCorpusCalls
```

It reports call and sheet counts per function, marks which the registry already names, and lists
the Risk Solver add-in calls separately. Re-running it after any change here measures the change
rather than asserting it.

**One caveat on the counts.** 53% of the corpus's formulas currently fail to parse in SwiftXLSX
and are recovered here by scanning raw formula text. The function names are reliable; exact call
counts for functions appearing only inside unparsed formulas may shift once the parser gaps are
closed. Relative ordering is unlikely to change, and sheet counts — the figure this proposal
prioritises — are the more stable of the two.

---

## 8. The coverage matrix — 2026-09-04

Built from three sources fetched rather than remembered: Microsoft's worksheet-function reference
(**519 functions**), Frontline's PSI reference (**295 functions**), and a symbol-level inventory of
BusinessMath (**1,351 computed quantities**). Corpus frequency is joined on as a fourth column and
used only to rank.

Full matrix: `excel_function_coverage_matrix.tsv`, beside this file. One row per function:
`family, name, category, marking, evidence, calls, sheets, arguments`.

### 8.1 What the markings mean

| Marking | Meaning | Confidence |
|---|---|---|
| `implemented` | already a case of `FormulaEvaluator.Function` | exact, certain |
| `bindable` | an inventory entry **explicitly names** this Excel function as what it computes | strong candidate, needs a signature check |
| `new` | verified absent by a tree-wide search | certain |
| `not ours` | error semantics or address arithmetic — the evaluator or the graph | certain |
| `out of scope` | text, database, cube, web — no numerical meaning to preserve | certain |
| `unreviewed` | no explicit annotation, and absence **not** verified | unknown |

**`unreviewed` is not `new`.** Absence of an annotation is not absence of an implementation, and
conflating them would commission work that may already be done. That distinction is the reason
this table is trustworthy where §3 was not — see §8.4.

### 8.2 Excel — 519 functions

| Marking | Count | Notes |
|---|---|---|
| `implemented` | **21** | the entire current registry |
| `bindable` | **86** | 51 statistical, 12 financial, 11 math, 10 compatibility, 2 datetime |
| `new` | **9** | `RATE`, `NPER`, `PDURATION`, `NOMINAL`, `ACCRINT`, and the depreciation family `DB`, `DDB`, `SYD`, `VDB` |
| `not ours` | 78 | lookup, logical, information |
| `out of scope` | 72 | text, database, cube, web |
| `unreviewed` | 253 | 66 math, 55 statistical, 54 engineering, 29 financial, 26 compatibility, 23 datetime |

**The statistical column is the headline.** 51 functions are bindable — `NORM.DIST`, `NORM.INV`,
`T.DIST`, `T.INV`, `F.DIST`, `F.INV`, `CHISQ.DIST`, `BETA.DIST`, `BINOM.DIST`, `POISSON.DIST`,
`HYPGEOM.DIST`, `LOGNORM.DIST`, `EXPON.DIST`, `CORREL`, `PEARSON`, `RSQ`, `SLOPE`, `INTERCEPT`,
`LINEST`, `LOGEST`, `TREND`, `GROWTH`, `FORECAST*`, `SKEW`, `KURT`, `GEOMEAN`, `HARMEAN`,
`STANDARDIZE`, `CONFIDENCE.*`, `PERCENTILE.INC`, `RANK.AVG`, `DEVSQ`, `FISHER`, `PERMUT`, and the
whole `STDEV/VAR/COVARIANCE` dotted family. **All of it is computed today and none is reachable
from a formula.**

Twelve financial functions are bindable: `XNPV`, `XIRR`, `MIRR`, `CUMIPMT`, `CUMPRINC`, `EFFECT`,
`DURATION`, `MDURATION`, `PRICE`, `YIELD`, `RRI`, `SLN`.

### 8.3 Risk Solver — 295 functions

| Marking | Count |
|---|---|
| `bindable` | **50** — 34 distributions, 14 statistics, 2 other |
| `not ours` | 13 — the annotations of §4.2 |
| `unreviewed` | 232 |

34 of Frontline's distributions already have a sampler. The corpus's most-used ones —
`PsiTriangular`, `PsiUniform`, `PsiNormal`, `PsiLogNormal` — are all bindable, as are `PsiMean`
and `PsiPercentile`.

Genuinely absent, and a real body of work: Cauchy, Laplace, Erlang, Fréchet, Lévy, LogLogistic,
InvNormal, NegBinomial, Johnson SB/SU, Kumaraswamy, Burr12, Dagum, Metalog, Myerson, and the
AR/ARMA/GARCH stochastic-process family. Also absent on the sampling side: Latin hypercube, Sobol
and Halton sequences, stratified and importance sampling — Frontline ships all of these and
BusinessMath samples only pseudo-randomly.

### 8.4 How the classifier was validated, and what it got wrong first

The first join matched substrings and produced confident nonsense: `NOMINAL` "covered by"
`minimize`, `PRICE` by `CommodityCollar.payoff`, `RATE` by `NPV`. It claimed **148** bindable Excel
functions.

Two defects, both worth recording because they are the failure mode of this kind of join:

1. **Substring matching is not evidence.** Replaced with a requirement that an inventory entry
   *explicitly name* the Excel function — `"Poisson cumulative probability (POISSON.DIST
   cumulative)"`. Everything else became `unreviewed` rather than being guessed either way.
2. **Prose leaked argument names.** `futureValueAnnuity` is documented as *"…(Excel
   FV(rate,nper,pmt,…) with pv=0…)"*, and the extractor harvested `RATE` and `NPER` from that
   signature as though they were claims to implement those functions. Both are in fact absent.
   Fixed by requiring an annotation's first token to be a function name, not prose.

The corrected classifier was then checked against 18 functions the inventory pass had analysed by
hand. **All 18 agree.**

The count fell from 148 to 86, and that is the point: the smaller number is the one that survives
checking.

### 8.5 Two things the references did not know about

88 of the 90 functions the corpus calls appear in one of the two references — good evidence they
are comprehensive. The two that do not:

- **`_DATATABLE`** (141 calls, 55 sheets) — not a function but Excel's internal marker for a
  what-if data table. Already handled structurally downstream.
- **`CB.RecalcCounterFn`** — **Crystal Ball**, Oracle's simulation add-in. A *third* add-in family
  beyond Excel and Risk Solver, and a reminder that the add-in surface is open-ended in a way the
  built-in surface is not.

### 8.6 What to do with this

1. **Bind the statistical family first.** 51 functions, no new mathematics, and it includes the
   dotted spellings every modern workbook uses. `STDEV.S` alone is 86,410 calls in the corpus.
2. **Bind the 12 financial and 34 Psi distributions**, with signature tests against fixed seeds —
   §3.2's parameterisation warnings apply to every one of them.
3. **Implement the 9 verified-absent Excel functions.** Small, well-specified, and `RATE`/`NPER`
   complete the TVM set that `PMT`/`IPMT`/`PPMT` already half-cover.
4. **Review the 253 + 232 `unreviewed`** before committing to any of it as new work. On the
   evidence of §8.2, a large fraction will turn out to be bindable, and every one that does is
   work not done twice.

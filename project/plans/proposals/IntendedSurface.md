# Design Proposal: the surface the documentation promises

**Status:** proposal, for triage. Every claim below is cited to `file:line` and was verified
against source; nothing here is inferred from memory.

**Last updated:** 2026-08-09

---

## 1. Why this document exists

Making the DocC catalogue compile turned the documentation into a specification and then checked
it. Most of what failed was drift — wrong labels, stale names, missing setup — and has been
repaired. What remains is different in kind: **API the documentation describes, in working
detail, that the library does not have.**

That set is worth designing against rather than deleting, for one reason above all:

> The library's own `BusinessMathError.circularDependency.recoverySuggestion`
> (`Error Handling/BusinessMathError.swift:264`) tells the user to resolve the cycle
> "using an iterative solver."

The documentation did not invent `IterativeSolver`. It transcribed a promise the **source** makes,
in a string we ship, that two tests assert on (`BusinessMathErrorTests.swift:195`, `:488` both
check `recovery.contains("iterative solver")`). There are zero occurrences of `IterativeSolver`
anywhere in the repository. The docs were reporting our intent accurately; the intent was never
built.

So the question this document answers is not "what did the docs get wrong" but **"what did we
mean to build, and what does the corpus tell us users would actually use?"** Frequency of
appearance is the evidence: a capability the documentation reaches for seven times in two
articles is a capability someone kept needing.

---

## 2. The five gaps worth designing, ranked by documentary demand

### 2.1 A data-ingestion path — CSV/JSON → `Entity` / `Account` / statements

**Demand:** the largest in the corpus. `3.15-DataIngestionGuide.md` is a ~900-line article
describing the whole path, plus the schema sections of `3.16-FinancialStatementsReference.md`.

**Reality:** the library is **export-only** — `Developer Tools/DataExport.swift:47` (`exportToCSV`)
and `:83` (`exportToJSON`). `Schema/DataSchema.swift` is a runtime `[String: Any]` field
validator. `Integration/` is protocols with no conformers.

Every dependent gap below exists only because this one does: `Period.custom`,
`EntityIdentifierType(rawValue:)`, `DataIngestionError.multipleEntities` / `.periodMismatch`,
and `import SwiftCSV` (`3.15:495,907` — not a package dependency).

**Recommendation.** This is the clearest signal in the whole corpus of what users want: to get
their own data in. Either ship an ingestion module or re-title 3.15 as a design sketch. Leaving a
900-line tutorial for a subsystem that does not exist is the worst of the three options.

### 2.2 Circular-dependency detection and resolution

**Demand:** 14 mentions across `1.6-DebuggingGuide.md:19,153,178-199,766-784` and
`1.7-ErrorHandlingGuide.md:51,429-470,676,886`, a reserved error code (`E201`,
`BusinessMathError.swift:74,337`), and the `recoverySuggestion` quoted above.

**Reality — and this is the most consequential finding in the sweep.** Two public functions claim
to detect cycles and cannot:

| symbol | reality |
|---|---|
| `ModelDebugger.detectCircularDependencies(in:)` `Diagnostics/ModelDebugger.swift:608` | body is **`return []`** (`:609-612`, comment: "Basic implementation - would need formula parsing for full detection") |
| `ModelInspector.detectCircularReferences()` `Developer Tools/ModelInspector.swift:183` | depth-1 self-loop check over a graph that hardcodes `graph[revenue.name] = []`; **can only ever return `false`** |

`1.6-DebuggingGuide.md:153` shows the first one emitting
`[Error] Circular dependency: Account A → Account B → Account A`. A user following that guide
gets "✅ No circular dependencies" on a model that has them. `CHANGELOG.md:1467` advertises the
second as "Find circular dependencies."

**Worse, the condition is not currently representable.** `FormulaEvaluator` stores
`private let accounts: [String: TimeSeries<T>]` (`Time Series/FormulaEvaluator.swift:106`) —
names map to *already-computed data*, not to formula strings. Resolving a `.name` node is a
single dictionary lookup (`:151`) with no re-entry. There is no API to register an account *as a
formula*, so mutual reference cannot be constructed. `FinancialModel`
(`Fluent API/ModelBuilder.swift:42`) holds `RevenueComponent`/`CostComponent`, neither of which
carries a formula.

`FormulaEvaluator.accountNames(in:)` (`:136`) is the right building block — it reports a formula's
dependencies without evaluating — but it is static, returns an order-free `Set`, and has **zero
production call sites**. The whole type is unwired.

**Recommendation.** Three coherent options, in order of preference:

1. **Build it.** Give accounts formulas, walk the graph with `accountNames(in:)`, throw E201 on a
   cycle, and add the fixed-point/Gauss-Seidel evaluator the `recoverySuggestion` already
   promises. This is the option the source and docs jointly describe.
2. **Retract it honestly.** Delete E201, both stub functions, the `recoverySuggestion` sentence,
   the two tests pinning it, and the CHANGELOG claim.
3. **Do nothing.** Not viable. Shipping two functions that report "no cycles" unconditionally is
   worse than shipping neither.

Deleting the error case while leaving the stubs would make things strictly worse.

### 2.3 Structured logging: levels, context, and a timeline

**Demand:** ~12 sites — `1.6-DebuggingGuide.md:553,583-600,623-643,868,870`;
`1.7-ErrorHandlingGuide.md:709-719`.

**Reality:**
- `BusinessMathLogger.shared.logLevel` — **zero occurrences of `logLevel` in `Sources`.** On
  Darwin the logger is `extension Logger` over `os.Logger`
  (`Diagnostics/BusinessMathLogger.swift:42`), where a level setter is architecturally
  impossible; the Linux fallback struct (`:364`) has none either.
- `logger.log(level:message:context:)` and `logger.error(_:context:)` — only fixed semantic
  helpers exist, e.g. `calculationStarted(_:context:)` (`:465`). No general structured entry.
- `logger.timeline("…") { }` / `.timelineEvent("…")` with the `├─`/`└─` tree at `1.6:637-643` —
  nothing reachable from a logger. `Diagnostics/ModelProfiler.swift` and
  `Developer Tools/CalculationTrace.swift` are separate types with different output.
- `Logger.critical(_:)` is real on Darwin and **absent from the Linux fallback**
  (`:364-434` declares `debug/info/notice/warning/error/trace` only) — a live platform break.

**Recommendation.** The frequency says whoever wrote the debugging guide expected observability to
be first-class, and the raw material exists. A `ModelProfiler` nesting mode delivers the timeline
tree; a wrapper type is required for runtime level control. Fix the Linux `critical` gap
regardless — that one is a bug, not a proposal.

### 2.4 `FinancialModel` as an inspectable container of accounts

**Demand:** 8 sites. `1.7:609,625` (`.accounts`), `1.7:633,634,635`
(`.hasBalanceSheet`, `.totalAssets`, `.totalLiabilities`, `.totalEquity`), `1.4:38,39,40`
(`init(entity:)` + `addAccount`, recommended at `1.4:821` for 1000+ components).

**Reality:** `FinancialModel` (`ModelBuilder.swift:42`) is builder-only and stores
`RevenueComponent`/`CostComponent`, not `Account`. `init(entity:@ModelBuilder builder:)` (`:82`)
does not default its builder. The balance-sheet properties exist on a *different* type
(`Financial Statements/BalanceSheet.swift:225/230/235`) and return `TimeSeries<T>`.

Two distinct wants pointing the same way: readers expect a model to be **a container of accounts
you can inspect and extend**. The accounting-identity check at `1.7:635` —
`abs(assets - (liabilities + equity)) > 0.01` — is the single most useful thing a modelling
library can offer, and it is unreachable today.

**Recommendation.** Add `init(entity:)`, a component-append API, and a balance-sheet projection —
or retract the "traditional approach" framing in 1.4 and the validation example in 1.7.

### 2.5 `Period.custom(start:end:)` — arbitrary date ranges

**Demand:** 7 sites — `3.15:61,65,66,110,177,927`, `3.16:70`. The documented JSON schema
advertises `{"type":"custom","start":…,"end":…}`.

**Reality:** `Period` (`Time Series/Period.swift:96`) is a struct over `PeriodType`
(`Time Series/PeriodType.swift:81`), an `Int`-raw-valued ladder from `millisecond` to `annual`.
Three conversion tables — `daysApproximate` (`:132`), `millisecondsExact` (`:172`),
`monthsEquivalent` (`:193`) — each switch exhaustively with **one scalar duration per case**, so
an arbitrary span is *structurally* unrepresentable, not merely unimplemented. `Period`'s
synthesized `Codable` (`type: Int`, `date: Date`) would reject the documented JSON twice over.

**Recommendation.** Ranked fifth because it is genuinely hard, not because it matters least — the
docs reach for it every time they describe real-world data, which is exactly when fiscal periods
stop matching the ladder. Needs a decision either way; today we advertise a format the decoder
rejects.

---

## 3. The unwired error vocabulary

Seven `BusinessMathError` cases have **zero throw sites**, and `git log -S` confirms none ever
existed — the `-S` hits resolve to DocC prose only (`d549dfb`, `fb626e3`). No test asserts the
library throws any of them.

| case | code | detectable today? | verdict |
|---|---|---|---|
| `numericalInstability` | E004 | **yes — detected ~11 times, mislabelled every time** | wire it |
| `invalidDriver` | E200 | yes — the checks simply do not exist | wire it |
| `circularDependency` | E201 | **no — not representable** (§2.2) | decide, do not just delete |
| `inconsistentData` | E202 | **yes — detected 3 times, thrown 0** | wire it |
| `negativeValue` | E301 | yes — ~91 of 138 `.invalidInput` throws are sign rejections | refactor |
| `outOfRange` | E302 | yes — ~28 of 138 are two-sided bounds | refactor |
| `resourceExhausted` | E400 | — | **also undocumented; missed by the original list of six** |

### 3.1 E004 `numericalInstability` — the strongest case, and a working precedent

The condition is detected all over the library and consistently reported as something else:

- **`Time Series/TVM/IRR.swift:134-145`** — the guard's own reason string already says the words:
  `"Derivative too small - numerical instability detected"`, thrown as `.calculationFailed`.
  **A pure relabel, zero risk.** Start here.
- **`Optimization/NumericalDifferentiation.swift:255-263`** — the working prototype, added
  2026-08-09. Already distinguishes exact singularity from a near-zero pivot and throws
  `OptimizationError.numericalInstability`. It is currently the only throw site of that case, and
  it belongs to a different enum (`Valuation/Debt/BondPricing.swift:1050`).
- `Valuation/Debt/BondPricing.swift:308`, `:939` — `yield = yield - error / derivative` with **no
  derivative guard**; a vanishing derivative surfaces 100 iterations later as `failedToConverge`
  (`:316`, `:947`), a misleading diagnosis.
- `Time Series/TVM/XNPV.swift:263-265` — instability conflated with non-convergence.
- `Solver/GoalSeek.swift:44-48` — `if dfx0 == 0` is exact-equality; `1e-300` passes and the next
  update explodes.
- Near-singular reported as plain singular: `Statistics/Regression/MatrixOperations/DenseMatrix.swift:566-569`,
  `CPUMatrixBackend.swift:142-144`, `Optimization/SparseSolver.swift:163/216/240`,
  `Simulation/CorrelationMatrix.swift:195-197`.
- Silently swallowed: `Portfolio/RiskParity.swift:214` (non-finite weight → 0),
  `Statistics/MixedModels/Applications/LMEApplications.swift:127-130` (negative chi-square clamped
  to 0), `Statistics/Regression/MultipleLinearRegression.swift:352` (NaN standard errors
  propagate into the result).

**An inconsistency worth resolving while here:** the same `guard gradNorm.isFinite` **returns**
`terminationReason: .numericalInstability` in `MultivariateGradientDescent.swift:285-295`, `:460-469`
but **throws** `OptimizationError.nonFiniteValue` in `MultivariateNewtonRaphson.swift:110`, `:204`
and `MultivariateLBFGS.swift:136`.

### 3.2 E202 `inconsistentData` — one obvious home

`Financial Statements/BalanceSheet.swift:915` `validate(tolerance:) throws` is already throwing and
already tested (`BalanceSheetTests.swift:410`, `:441`). Its guard (`:930`) throws a one-off local
`BalanceSheetError.accountingEquationViolation` (declared `:36`) conforming only to
`Error, Sendable` — no `LocalizedError`, no code, no recovery. Its `Double` associated values force
an awkward string-coercion block at `:932-940` that switching to E202 would delete outright.

`ValidationFramework.swift:155` (`TimeSeries.validateAndThrow`) is the precedent: it converts
error-severity warnings into `BusinessMathError.dataQuality`. E202 is exactly the missing
financial-statement equivalent.

### 3.3 E200 `invalidDriver` — and a live bug

`name: String` is a required member of the `Driver` protocol (`Operational Drivers/Driver.swift:82`),
so the payload is available everywhere. The highest-value site is a genuine defect, not just a
label:

**`Scenario Analysis/SensitivityAnalysis.swift:805-807`** —
`guard let baseDriverAny = baseCase.driverOverrides[inputDriver] else { continue }`. **A typo'd
driver name silently drops a tornado bar.** It reads almost verbatim as
`.invalidDriver(name: inputDriver, reason: "not present in base case driver overrides")`.

Others: `FinancialModel/DriverOptimization.swift:38-48` (`OptimizableDriver.init` validates
nothing; a `currentValue` outside `range` seeds the optimizer infeasible),
`Operational Drivers/ConstrainedDriver.swift:169-180` (inverted bounds silently yield a constant
driver), `ProbabilisticDriver.swift:180/207/231` (accepts negative `stdDev`, `low > high`,
`min > max`), `DriverOptimization.swift:457-460` (a `.stepSize` constraint is accepted then
`break`s unimplemented).

### 3.4 E301 / E302 — a refactor, not a bug fix

`.invalidInput` already conveys the information. The value of these two cases is the **typed**
payload: `value: Double` (currently lost at ~8 sites, e.g. seven identical
`"Weights must be non-negative"` throws with no `value:` at all, and
`Statistics/MixedModels/Types/GroupingFactor.swift:42-46` which passes the literal string
`"contains negative"`), and typed `min`/`max` in place of the `expectedRange:` prose string that
87 of 138 sites already pass.

Natural homes exist and are **also dead**: `Validation/StandardValidation.swift:34` `NonNegative<T>`
and `:112` `Range<T>` are unreferenced outside their own file and return a *third* error type
(`Validation/ValidationTypes.swift:52`), with a fourth vocabulary generated by
`BusinessMathMacrosImpl/ValidationMacros.swift:172-215`. Do E301/E302 as part of consolidating
those four vocabularies, not standalone.

---

## 4. Documented conditions that are simply wrong

Distinct from the gaps above — these are cases we *do* throw, documented against the wrong
condition.

1. **E001 vs E302 document the same thing.** `1.7-HEAD:56-58` defines `invalidInput` as "Thrown
   when parameters are outside acceptable ranges" — verbatim E302's job (`:537`). The enum's own
   doc (`BusinessMathError.swift:39`, "Invalid input parameter") is the correct scope. Only ~14% of
   real E001 throws are malformed input; ~86% are sign or range violations.
2. **E002 `calculationFailed` covers input validation.** `IRR.swift:104-113` throws it for a
   *pre-flight* check (`guard hasPositive && hasNegative`) — no calculation was attempted. Same in
   `mirr` (`:250`).
3. **E101 `dataQuality` covers file integrity.** Documented as NaN/Infinity/missing values; two of
   its four throw sites are `Fluent API/Templates/TemplateRegistry.swift:562` ("checksum mismatch")
   and `:574` ("Invalid template JSON encoding").
4. **E003 `divisionByZero` covers solver breakdown.** `Solver/GoalSeek.swift:44-48`, for a zero
   derivative in Newton–Raphson.
5. **E300 `validationFailed` is unreachable as documented.** `1.7-HEAD:492-494` shows
   `try validateModel(model)`; no `validateModel` exists. Its only throw site
   (`BusinessMathError.swift:379`) fires only when `errors.count > 1` — with exactly one
   error the aggregator rethrows the raw error (`:376`).
6. **Three thrown cases are undocumented.** The E-number table (`1.7-HEAD:871-890`) lists 14; the
   enum has 18. Missing: `overflow` E005 (thrown 3×), `collectionLimitExceeded` E401 (1×), and
   `resourceExhausted` E400 (0×, see §3).

---

## 5. Cheap wins, separately

Not architecture — small additions the corpus keeps reaching for.

| change | why |
|---|---|
| `DistributionNormal.init(mean:stdDev:)` | **repairs 19 source doc-comments in one line**, incl. `Simulation/DistributionRandom.swift:18`, `MonteCarloSimulation.swift:39,44`. Today only `init(_:_:)` and `init(mean:variance:)` exist, so our own Quick Help examples do not compile — and that is where the article-level drift was copied from. |
| `IncomeStatement.ebit` | 3 doc sites; we have `ebitda` (`:299`), `operatingIncome` (`:291`), `grossProfit` (`:275`) but not the one aggregate readers reach for. |
| `CashFlowRole.changeInDeferredRevenue` | 3 sites; deferred revenue exists only as a *balance-sheet* role (`BalanceSheetRole.swift:123`). SaaS models cannot be expressed without it. |
| matrix-level `estimateCovariance` | blocks every portfolio and robust-optimization example; `covariance.swift:47` is pairwise only. |
| lowercase `percentileLocation` with a `Double` percentile | real symbol is `PercentileLocation(_ percentile: Int, values:) throws` — mismatched on capitalization, type, order, label, and throwing. The signature is the ergonomic problem, not the doc. |
| `DistributionGamma` continuous shape | `init(r: Int, λ: Double)` is **Erlang, not gamma**. A real distributional limitation. |

### A separate defect found in passing

`Statistics/Descriptors/Linear Regression/linearRegression.swift:49` —
`guard !xValues.isEmpty || !yValues.isEmpty else { throw .insufficientData(required: 0, actual: 0, …) }`.
The `||` should be `&&`; it throws only when *both* arrays are empty. `required: 0` is also
meaningless.

---

## 6. Suggested order

1. **Decide §2.2.** It is the only item where the current state actively lies to users, and the
   decision gates E201.
2. **`DistributionNormal(mean:stdDev:)`** — one line, fixes 19 doc comments, stops the drift at
   its source.
3. **Relabel `IRR.swift:136` to E004**, then work outward through §3.1.
4. **`BalanceSheet.swift:932` → E202.**
5. **`SensitivityAnalysis.swift:805` → E200.** This one is a bug fix, not a vocabulary change.
6. **Decide §2.1** (ingestion) and §2.5 (`Period.custom`) together — the second is a dependency of
   the first.
7. E301/E302 with the validation-vocabulary consolidation, when that happens.

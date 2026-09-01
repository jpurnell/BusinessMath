# Design Proposal: BusinessMathDSL expressiveness — closing the gaps that block Excel import

**Date:** 2026-09-01
**Status:** **SUPERSEDED, same day, by `TypedModelAuthoring.md`.** Not implemented.

> **Why this was abandoned.** §0's prior-art audit was correct and is the reason this document
> is kept — but it did not go far enough. A consumer search showed `BusinessMathDSL` has **zero
> external consumers**: only its own four test files import it, and no sibling package declares
> it as a dependency. Combined with the duplication catalogued in §0 (two `Scenario` types, two
> `ScenarioAnalysis` types, valuation logic already in `Valuation/Equity/`), the conclusion is
> that this proposal was investing five new types and a breaking change into a module that
> should be deleted.
>
> §15 Q1 — "is the import target `BusinessMathDSL` or `ModelDefinition`?" — was answered
> **`ModelDefinition`**. Gaps B, C, and D dissolve with that answer. Gap E dissolves too, since
> every account in a `ModelDefinition` *is* a name. Gap A1, the live `freeCashFlow` bug, is
> subsumed by deleting the module that contains it.
>
> **Read this document for:** the prior-art audit (§0), the gap analysis (§2), the
> `BusinessMathPro` dependency-direction finding (§0, §9), and §12's adversarial review — which
> named the alternative that won.
>
> **Read `TypedModelAuthoring.md` for the live plan.**

**Original companion:** `BusinessMathExcel/project/plans/proposals/PROPOSAL_excel_to_dsl_recognizer.md`
(also superseded, by `PROPOSAL_excel_to_model_recognizer.md`).

Every claim about current state below carries a `file:line` and was verified against the working
tree on 2026-09-01 at `v2.6.0`.

---

## 0. Prior-art audit (read this first)

The gap analysis that prompted this proposal was written from `BusinessMathDSL` alone. Auditing
the wider codebase first changes the answer substantially: **two of the five gaps are already
solved elsewhere in this repository, and one has prior art in `BusinessMathPro` that we cannot
reach.** What follows is what exists before anything is built.

| Capability | Where it already lives | Reachable from the DSL? |
|---|---|---|
| Time axis (`Period`: year / quarter / month / semiannual / custom, `Sendable`, `Codable`) | `Time Series/Period.swift:115` | **Yes** |
| Per-period values (`TimeSeries<T: Real & Sendable>` with metadata, labels, `subscript(Period)`, range slicing) | `Time Series/TimeSeries.swift:108` | **Yes** |
| String-formula evaluation over named accounts | `Time Series/FormulaEvaluator.swift:125` | **Yes** |
| Named-account model with formulas, `requiredInputs()`, `evaluationOrder()`, `evaluate() -> [String: TimeSeries<T>]` | `Model Definition/ModelDefinition.swift:119` | **Yes** |
| SCC-based cycle **detection** (`DependencyReport`, `DependencyCycle`, `CycleForm`) | `Model Definition/DependencyReport.swift:103` | **Yes** |
| Cycle **resolution** — `IterativeCycleSolver`, `LinearCycleSolver`, `IterationSettings` (max-iters, abs/rel tolerance, relaxation ω, seeded `InitialValues`), `ConvergenceState` | `Model Definition/IterativeCycleSolver.swift`, `CycleSolver.swift:234` | **Yes** |
| Root finding / goal seek | `Solver/GoalSeek.swift` | **Yes** |
| IRR | `Time Series/TVM/IRR.swift:87` | **Yes** |
| Revolver + per-period interest + cash sweep + draw/repay | `BusinessMathPro/Treasury/CapitalStructureProjection.swift:199`, `RevolverFacility.swift:90` | **No — see below** |

`Package.swift:124-136` declares `BusinessMathDSL` with `dependencies: ["BusinessMath", …]`, so
every row marked *Yes* is available to the DSL **today** and is simply unused.

**The `BusinessMathPro` prior art is architecturally out of reach.** `BusinessMathPro/Package.swift:40-43`
declares `.package(name: "BusinessMath", path: "../BusinessMath")`. Pro depends on BusinessMath;
`BusinessMathDSL` is a target *inside* BusinessMath. Using `CapitalStructureProjection` from the
DSL would invert that dependency and create a package cycle. Any shared debt primitive must
therefore live in **BusinessMath core**, not in Pro — and if we want one implementation rather
than two, Pro's version eventually rebases onto it.

### Revised gap status

| Gap (from Appendix A) | Original assessment | **Revised** |
|---|---|---|
| A — taxes on EBIT, no interest | "Blocking correctness bug" | **Split.** A1 is a live bug (§1); A2 is a capability gap needing C first |
| B — no time-varying parameters | "Blocking; needs new primitive" | **Much cheaper.** `TimeSeries` already exists; the DSL just does not use it |
| C — no capital structure | "Blocking" | **Confirmed blocking.** Prior art exists in Pro but is unreachable |
| D — no circularity resolution | "Blocking; build a fixed-point solver" | **Already shipped.** `IterativeCycleSolver` landed in `87a717e`; the DSL does not call it |
| E — non-composing models, labels destroyed | "High" | **Confirmed.** Unchanged |

## 1. Objective

Two objectives, deliberately separated because they have different urgency and different risk:

**1. An immediate correction (Gap A1).** `CashFlowModel.freeCashFlow(year:)` returns
`netIncome + depreciation` (`CashFlowModel.swift:223-230`) — with no capex and no change in
working capital. That is operating cash flow, not free cash flow. It is consumed by
`DCFModel.calculateEnterpriseValue()` at `DCFModel.swift:144`, so **every enterprise value
computed through the `FromCashFlowModel` path is overstated by the present value of capex.**
This ships today, affects existing users, and is fixable without any of the work below.

**2. Close Gaps B, C, E** so `BusinessMathDSL` can express a levered, time-varying model —
and, with them, Gap A2 (tax on EBT rather than EBIT, which requires an interest line to exist).

## 2. Motivation

**Current situation.** `CashFlowModel.calculate(year:)` is, in full (`CashFlowModel.swift:180-212`):

```swift
revenue      = revenue?.value(forYear: year) ?? 0
expenses     = expenses?.value(forYear: year, revenue: revenue) ?? 0
ebitda       = revenue - expenses
ebit         = ebitda - depreciation
taxes        = taxes?.value(on: ebit) ?? 0
netIncome    = ebit - taxes
freeCashFlow = netIncome + depreciation
```

Every parameter feeding it is a **scalar**: one `Base`, one `GrowthRate`, one
`variablePercentage`, one `CorporateRate`. There is no interest, no debt, no capex, no working
capital, and no time axis beyond an `Int` year index.

**Workaround.** None available in the DSL. A user modelling anything levered drops out of the
DSL entirely and hand-writes the schedule, or reaches for `BusinessMathPro` — which is a
different package with a different audience and licence posture.

**Drawback.** The result-builder syntax is the DSL's whole value proposition, and it currently
covers only unlevered, constant-growth models. That is a narrow enough band that the DSL cannot
represent a standard teaching case — the Wharton paper LBO — let alone a real one.

**External forcing function.** `BusinessMathExcel` is building an Excel→DSL recognizer whose
stated goal is 100% coverage of the Wharton practice workbook. That workbook needs: revenue,
EBITDA, D&A, EBIT, **interest**, EBT, taxes, capex, ΔNWC, FCF, draws, cash sweep, sweep paydown,
debt before balloon, balloon payment, debt, debt cash flows, purchase price, exit value, levered
cash flow, MoM, IRR, sources & uses, and a 2-D IRR sensitivity. The recognizer's ceiling is set
by what this DSL can express, so its Stage 3 is blocked on this proposal.

**Why the DSL is the right place.** Everything needed for B and D already sits one import away
(§0). This is substantially a *wiring* problem, not a build-from-scratch problem.

## 3. Proposed Architecture

### Part 1 — Gap A1, standalone and shippable now

**Modified Files:**
- `Sources/BusinessMathDSL/CashFlowModel.swift` — `freeCashFlow(year:)`
- `Sources/BusinessMathDSL/DCFModel.swift` — no code change; DocC clarification

Two options, in preference order:

**(a) Subtract capex.** `CashFlowModel` gains an optional `capex: CapEx?` (the type already
exists at `Forecast.swift:79`), and `freeCashFlow` becomes
`netIncome + depreciation - capex - changeInNWC`. Correct, and it starts Gap E's convergence.

**(b) Rename.** If (a) is judged too large for an immediate correction, rename the method
`operatingCashFlow(year:)`, deprecate `freeCashFlow(year:)` with a message stating that it
excludes capex, and make `DCFModel` refuse the `FromCashFlowModel` path rather than silently
discounting the wrong series.

**Recommendation: (a).** (b) is honest but leaves `DCFModel`'s convenience path unusable, and
the `CapEx` type already exists — the fix is small.

### Part 2 — Gaps B, C, E

**New Files:**

| File | Role |
|---|---|
| `Sources/BusinessMathDSL/Schedule.swift` | `Schedule<T>` — the per-period value primitive (Gap B) |
| `Sources/BusinessMathDSL/LineItem.swift` | Named, labelled expense/revenue line (Gap E) |
| `Sources/BusinessMathDSL/DebtSchedule.swift` | Draws, rate, amortisation/sweep policy, balloon (Gap C) |
| `Sources/BusinessMathDSL/DebtComponents.swift` | `Draw`, `Rate`, `Sweep`, `Balloon`, `Term` builder components |
| `Sources/BusinessMathDSL/Evaluation.swift` | Period-indexed evaluation; routes cycles to `CycleSolver` |

**Modified Files:** `Revenue.swift`, `Expenses.swift`, `Taxes.swift`, `Depreciation.swift`
(accept `Schedule`), `CashFlowModel.swift` (interest line, capex, ΔNWC, tax on EBT),
`Forecast.swift` (converge with `CashFlowModel` — Gap E).

**Module Placement:** all within the existing `BusinessMathDSL` target. No new target.

### The `Schedule` primitive

`Schedule<T>` wraps the existing `TimeSeries<T>` rather than replacing it — `TimeSeries` is the
storage and analytics type; `Schedule` is the *authoring* type that the result builders accept.

```
Schedule<T>
├── .constant(T)                       // today's scalar behaviour
├── .growing(base: T, rate: T)         // today's Base + GrowthRate
├── .perPeriod(TimeSeries<T>)          // NEW — arbitrary per-period values
└── .formula(String)                   // NEW — deferred to ModelDefinition/FormulaEvaluator
```

`.constant` and `.growing` preserve every current call site verbatim through
`ExpressibleByFloatLiteral`, so `Fixed(100_000)` keeps compiling and keeps meaning what it means.

### Cycle handling

`Evaluation` builds a `ModelDefinition<Double>` from the assembled components, calls
`dependencyReport()`, and routes any detected cycle to `CycleSolver.solve` with an
`IterationSettings`. **No new solver is written.** The interest ↔ debt ↔ sweep ↔ FCF cycle is
exactly the motivating case `IterativeSolver.md` was written for.

## 4. API Surface

```swift
// MARK: - Gap B: the period-value primitive

/// A value that may vary by period.
///
/// `Schedule` is the authoring type accepted by the DSL's result builders;
/// `TimeSeries` remains the storage and analytics type it resolves to.
public enum Schedule<T: Real & Sendable>: Sendable {
    case constant(T)
    case growing(base: T, rate: T)
    case perPeriod(TimeSeries<T>)
    case formula(String)

    /// Resolves this schedule over the given periods.
    /// - Throws: ``ScheduleError/formulaRequiresModelContext`` for `.formula`,
    ///   which only resolves inside a `ModelDefinition` evaluation.
    public func resolve(over periods: [Period]) throws -> TimeSeries<T>

    public func value(forPeriod period: Period, in periods: [Period]) throws -> T
}

extension Schedule: ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {
    // `Fixed(100_000)` continues to compile unchanged.
}

public enum ScheduleError: Error, Sendable, Equatable {
    case formulaRequiresModelContext(String)
    case periodOutOfRange(Period)
    case emptyPeriods
}

// MARK: - Gap E: line-item identity

/// A named line with its own schedule, retained rather than summed away.
public struct LineItem: Sendable, Equatable {
    public let name: String
    public let schedule: Schedule<Double>
    public let kind: Kind

    public enum Kind: Sendable, Equatable {
        case fixed
        case variable(of: Driver)   // percentage of revenue, EBITDA, …
        case oneTime(period: Period)
    }

    public init(_ name: String, _ schedule: Schedule<Double>, kind: Kind)
}

extension Expenses {
    /// Individual lines, preserved with their names.
    public var lineItems: [LineItem] { get }
}

// MARK: - Gap C: capital structure

public struct DebtSchedule: Sendable {
    public let tranches: [Tranche]

    public init(@DebtScheduleBuilder content: () -> DebtSchedule)

    /// Beginning balance for a period.
    public func beginningBalance(forPeriod: Period) throws -> Double
    /// Interest expense, computed per ``InterestBasis``.
    public func interest(forPeriod: Period, availableCashFlow: Double) throws -> Double
    /// Mandatory amortisation plus any cash sweep.
    public func principalPayment(forPeriod: Period, availableCashFlow: Double) throws -> Double
}

public struct Tranche: Sendable {
    public let name: String
    public let drawn: Schedule<Double>
    public let rate: Schedule<Double>
    public let basis: InterestBasis
    public let sweep: SweepPolicy?
    public let balloon: Balloon?
}

/// Which balance interest accrues on.
///
/// `.beginningBalance` breaks the interest↔debt cycle by timing and needs no iteration.
/// `.averageBalance` is genuinely simultaneous and routes to `CycleSolver`.
public enum InterestBasis: Sendable, Equatable {
    case beginningBalance
    case averageBalance
}

public struct SweepPolicy: Sendable, Equatable {
    /// Share of free cash flow applied to principal. `1.0` is a full sweep.
    public let percentageOfFreeCashFlow: Double
    /// Floor below which cash is retained rather than swept.
    public let minimumCashBalance: Double
}

public struct Balloon: Sendable, Equatable {
    public let period: Period
}

// Builder components: Draw, Rate, Sweep, BalloonPayment, Term
@resultBuilder public struct DebtScheduleBuilder { /* … */ }

// MARK: - Gap A2 + assembly

extension CashFlowModel {
    public init(
        periods: [Period],
        revenue: Revenue? = nil,
        expenses: Expenses? = nil,
        depreciation: Depreciation? = nil,
        capex: CapEx? = nil,                  // Gap A1
        workingCapital: WorkingCapital? = nil, // Gap A1
        debt: DebtSchedule? = nil,             // Gap C
        taxes: Taxes? = nil
    )

    /// Evaluates the model, resolving any cycle via `CycleSolver`.
    ///
    /// - Throws: ``EvaluationError/didNotConverge(_:)`` when iteration exhausts
    ///   `IterationSettings.maxIterations`; ``ScheduleError`` on schedule resolution failure.
    public func evaluate(
        settings: IterationSettings<Double> = IterationSettings()
    ) throws -> [Period: CashFlowResult]
}

extension CashFlowResult {
    public var interest: Double { get }         // Gap C
    public var ebt: Double { get }              // Gap A2 — EBIT − interest
    public var capex: Double { get }            // Gap A1
    public var changeInWorkingCapital: Double { get }
    /// Net income + D&A − capex − ΔNWC.
    public var freeCashFlow: Double { get }     // Gap A1 — corrected definition
}

public enum EvaluationError: Error, Sendable, Equatable {
    case didNotConverge(ConvergenceState)
    case missingPeriods
    case scheduleFailure(ScheduleError)
}
```

### Example — the Wharton paper LBO

```swift
let periods = Period.year(2022).through(Period.year(2028))

let model = CashFlowModel(
    periods: periods,
    revenue: Revenue { Base(100); GrowthRate(0.10) },
    expenses: Expenses { Variable(percentage: 0.60) },
    depreciation: Depreciation { StraightLine(asset: 100, years: 5) },
    capex: CapEx(percentage: 0.15),
    workingCapital: WorkingCapital(daysOfSales: 18.25),
    debt: DebtSchedule {
        Draw(120, at: Period.year(2022))
        Rate(0.10, basis: .averageBalance)      // cyclic — routes to CycleSolver
        Sweep(percentageOfFreeCashFlow: 1.0)
        BalloonPayment(at: Period.year(2027))
    },
    taxes: Taxes { CorporateRate(0.40) }        // now applied to EBT
)

let results = try model.evaluate()
```

## 5. MCP Schema

**Tool Description:** Evaluate a declarative cash flow model with optional debt schedule,
resolving circular interest by iteration.

**REQUIRED STRUCTURE (JSON):**
```json
{
  "periods": {"granularity": "annual", "start": 2022, "count": 7},
  "revenue": {"type": "growing", "base": 100.0, "rate": 0.10},
  "expenses": [
    {"name": "COGS", "kind": "variable", "of": "revenue", "value": 0.60}
  ],
  "depreciation": {"type": "straightLine", "asset": 100.0, "years": 5},
  "capex": {"percentageOfRevenue": 0.15},
  "workingCapital": {"daysOfSales": 18.25},
  "debt": {
    "tranches": [{
      "name": "Term Loan",
      "drawn": {"type": "constant", "value": 120.0},
      "rate": {"type": "constant", "value": 0.10},
      "basis": "averageBalance",
      "sweep": {"percentageOfFreeCashFlow": 1.0, "minimumCashBalance": 0.0},
      "balloon": {"period": 2027}
    }]
  },
  "taxes": {"corporateRate": 0.40},
  "iteration": {"maxIterations": 100, "absoluteTolerance": 1e-9, "relaxation": 1.0}
}
```

**Parameter Types:**
- `periods.granularity` (string): `"annual"`, `"quarterly"`, `"monthly"`, `"semiannual"`.
- `periods.start` (integer), `periods.count` (integer > 0, ≤ 1000).
- Every schedule-valued field accepts `{"type": "constant"|"growing"|"perPeriod", …}`;
  `perPeriod` takes `{"values": [Double]}` matching `periods.count`.
- `debt.tranches[].basis` (string): `"beginningBalance"` (acyclic) or `"averageBalance"` (cyclic).
- `iteration` (object, optional): maps to `IterationSettings`. `relaxation` ω ∈ (0, 2].
- Dates are exchanged as period identifiers, not ISO 8601 timestamps; `Period` is a closed
  interval, not an instant.

**Determinism:** Fully deterministic — no seed required. Iteration is a fixed-point sweep, not
sampling. The response reports `convergenceState` and `iterationsUsed` so a caller can see
whether a cyclic model settled.

## 6. Constraints & Compliance

**Concurrency:** `Schedule`, `LineItem`, `DebtSchedule`, `Tranche`, and all component types are
immutable value types conforming to `Sendable`. This also begins closing a standing debt: **no
type in `BusinessMathDSL` currently conforms to `Sendable`** (`grep -rc Sendable
Sources/BusinessMathDSL/*.swift` → no matches), even though the target enables
`StrictConcurrency` at `Package.swift:133-135`. New types conform from the start; existing ones
gain conformance as they are touched.

**Safety:** No force unwraps, no `try!`, no force casts. Division guarded — the sweep computes
`cash / balance` and the variable-expense line divides by a driver, so each site checks for zero.

**Traps → thrown errors.** Existing DSL initializers call `preconditionFailure` on out-of-range
input (`Revenue.swift:74,90,106,111`, `Taxes.swift:102,118`, `Forecast.swift:28-151`). New
initializers **throw** instead. Existing ones keep their trapping behaviour for source
compatibility but gain `throws`-ing `init(validating:)` counterparts, so a caller driving the DSL
from untrusted data — an Excel importer, an MCP request — has a non-trapping path. This is a
precondition for the `BusinessMathExcel` recognizer, which cannot let arbitrary cell contents
crash the process.

**Generics:** `Schedule<T: Real & Sendable>` matches `TimeSeries`'s existing constraint. The rest
of the DSL is `Double`-typed and stays that way; widening it is out of scope.

**Determinism:** Iteration settings are explicit and defaulted; no ambient randomness.

**DocC:** All new public API documented.

## 7. Source & API Compatibility

**Breaking changes — one, deliberate.**

`CashFlowModel.freeCashFlow(year:)` changes meaning under Part 1(a): it begins subtracting capex
and ΔNWC. Any caller relying on the old value gets a different number. **This is the point** —
the old number was wrong for its name and propagated into `DCFModel.swift:144`. Mitigation:
ship in a minor version with a CHANGELOG entry stating the numeric change explicitly, and add
`operatingCashFlow(year:)` for callers who genuinely wanted `netIncome + depreciation`.

**Non-breaking:**
- `Schedule`'s literal conformances keep every `Fixed(100_000)` / `GrowthRate(0.15)` call site
  compiling and computing identically.
- `Expenses.lineItems` is additive; `fixedAmount` / `variablePercentage` / `oneTimeExpenses`
  remain, computed from the retained lines.
- `DebtSchedule`, `capex:`, and `workingCapital:` are optional parameters defaulting to `nil`.
  A model that omits them evaluates exactly as today.
- Taxes move from EBIT to EBT **only when a `DebtSchedule` is present.** With no debt,
  EBT ≡ EBIT and the arithmetic is unchanged — so Gap A2 is not a breaking change for any
  currently-expressible model.

**Incremental adoption:** Yes, per gap. Part 1 ships alone. `Schedule` ships without
`DebtSchedule`. `DebtSchedule` ships without the `.formula` case.

**Type-checking risk:** Moderate and worth naming. `Schedule` gaining
`ExpressibleByFloatLiteral` *and* `ExpressibleByIntegerLiteral`, combined with result builders,
is the classic recipe for slow or ambiguous overload resolution. Mitigation: the builders take
`Schedule<Double>` concretely rather than a generic `some`, and a compile-time budget test is
added (§10).

## 8. Backend Abstraction

**Not applicable.** Evaluation is a per-period sweep over a handful of accounts — dozens to
low-thousands of scalar operations per model. The one iterative path already has a tuned
implementation in `IterativeCycleSolver`. Monte Carlo *over* many models is a `BusinessMathPro`
concern (`SimulationKernel`), not this target's.

## 9. Dependencies

**Internal (all existing, all currently unused by the DSL):**
- `Time Series/Period.swift`, `TimeSeries.swift`, `PeriodSequence.swift`
- `Model Definition/ModelDefinition.swift`, `CycleSolver.swift`, `IterativeCycleSolver.swift`,
  `DependencyReport.swift`
- `Time Series/FormulaEvaluator.swift` (for `Schedule.formula`)
- `Time Series/TVM/IRR.swift`, `Solver/GoalSeek.swift`

**External:** None. `swift-numerics` is already a DSL dependency (`Package.swift:127`).

**Explicitly NOT a dependency:** `BusinessMathPro`. Pro depends on BusinessMath
(`BusinessMathPro/Package.swift:40-43`); the reverse would be a package cycle. See §14 on
eventually rebasing Pro's `CapitalStructureProjection` onto the primitive proposed here.

## 10. Test Strategy

**Test Categories:**

- *Gap A1 regression (write first)* — a model with capex must produce
  `freeCashFlow < netIncome + depreciation`, and `DCFModel.calculateEnterpriseValue()` through
  `FromCashFlowModel` must return a **lower** EV than it does today.
- *Golden path* — Wharton paper LBO reproduces published results.
- *Source compatibility* — the existing DSL test suite passes unmodified except for the one
  intended `freeCashFlow` change.
- *Schedule* — `.constant` ≡ today's scalar behaviour; `.growing` matches documented values;
  `.perPeriod` round-trips through `TimeSeries`.
- *Cycle* — `.averageBalance` converges; a divergent model raises
  `EvaluationError.didNotConverge` with a `ConvergenceState`, rather than spinning or returning
  a plausible wrong number.
- *Timing vs iteration* — `.beginningBalance` produces an acyclic `DependencyReport` and takes
  the non-iterative path; asserted via `dependencyReport()`, not by timing.
- *Line-item identity* — `Fixed(200_000, "Rent")` + `Fixed(300_000, "Salaries")` round-trips
  with both names intact, and `fixedAmount` still reports `500_000`.
- *Non-trapping path* — `init(validating:)` throws on a negative base / a tax rate of 1.4
  instead of trapping.
- *Determinism* — identical inputs produce identical results across runs.
- *Compile-time budget* — the Wharton example type-checks within a fixed ceiling (guards §7's
  overload-resolution risk).

**Reference Truth:**

1. **Wharton LBO Practice Model** (Penn Career Services, publicly available) — published answers
   **IRR 24.67%**, **MoM 3.01**. Independently reproduced by orcaset's `examples/paper-lbo`,
   giving a second source.
2. **The DSL's own documented values** for non-regression: `Revenue.swift:29-36` states
   `Base(1_000_000)` + `GrowthRate(0.15)` → year 1 `1,000,000`, year 2 `1,150,000`,
   year 3 `1,322,500`.
3. **Excel** for the debt schedule mechanics — `IPMT`/`PPMT` per period on a term loan, computed
   in Excel and recorded in the fixture.

**Validation Trace (REQUIRED):**

> **Gap A1.** `CashFlowModel(revenue: Revenue { Base(1_000_000) }, expenses: Expenses { Fixed(400_000) },
> depreciation: Depreciation { StraightLine(asset: 500_000, years: 5) }, capex: CapEx(percentage: 0.08),
> taxes: Taxes { CorporateRate(0.21) })`
>
> EBITDA = 1,000,000 − 400,000 = 600,000. D&A = 100,000. EBIT = 500,000.
> Taxes = 105,000. Net income = 395,000. Capex = 80,000.
> - **Today:** `freeCashFlow(year: 1)` = 395,000 + 100,000 = **495,000**
> - **Corrected:** 395,000 + 100,000 − 80,000 = **415,000**
>
> The 80,000 delta is the bug, and it discounts straight through `DCFModel.swift:144`.
>
> **Gap C + A2.** The Wharton model must produce **IRR 24.67%** (accuracy `1e-4`) and
> **MoM 3.01** (accuracy `1e-2`), with `.averageBalance` interest converging in under
> `IterationSettings.maxIterations` (100). Year-1 interest on a 120 draw at 10% with full sweep
> must equal the reference model's **11.75**, which is the average-balance figure, not the
> beginning-balance 12.00 — this single value distinguishes a correct cyclic solve from a model
> that quietly broke the cycle by timing.

Floating-point assertions use accuracy-based comparison per the TDD contract.

## 11. Architecture Decision Review

**ADR Check:**
- [x] Reviewed `development-guidelines/rules/architecture_decisions.md`
- [x] Supersedes an existing ADR? **No**
- [x] Amends an existing ADR? **No** — but it *consumes* the capability recorded by
      `IterativeSolver.md` and `CircularDependencyDetection.md` (both implemented in `87a717e`).
      Those proposals anticipated exactly this caller; this is their first DSL-level use.
- [x] New ADR required? **Yes**

**New ADR Draft:**

- **Title:** Debt and capital-structure primitives live in BusinessMath core, not Pro
- **Category:** architecture
- **Key decision:** Because `BusinessMathPro` depends on `BusinessMath`, any debt primitive
  shared by `BusinessMathDSL` and Pro's `CapitalStructureProjection` must live in core. Pro's
  implementation is prior art to learn from, not code to call.

- **Title:** `Schedule` is the DSL authoring type; `TimeSeries` remains storage
- **Category:** api
- **Key decision:** The DSL's result builders accept `Schedule<T>`, which resolves to
  `TimeSeries<T>`. Two types rather than one, so the scalar-literal ergonomics that make the DSL
  worth having survive the move to per-period values.

## 12. Adversarial Review

**Strongest case for a different approach.**

A reviewer would reasonably say: *`ModelDefinition` already is this.* It has named accounts,
string formulas, `TimeSeries` values, `requiredInputs()`, `evaluationOrder()`, SCC cycle
detection, and an iterative solver — and per `IterativeSolver.md` §1 it was built for "people
migrating from Excel," which is precisely this proposal's forcing function. The Wharton LBO maps
onto `ModelDefinition` almost directly, with no new types at all.

On that view, the right move is to **make `ModelDefinition` the import target** and let
`BusinessMathDSL` stay what it is: a pleasant scalar authoring surface for simple unlevered
models. That would delete Gaps B, C, and D from this proposal outright and leave only A1 and E.

That alternative may well be better, and it is cheaper. It is also the harder thing to walk back
from, because it decides what the DSL is *for*.

**Where this design is most likely wrong.**

The load-bearing assumption is that **result-builder syntax is worth preserving at LBO
complexity.** `Revenue { Base(1_000_000); GrowthRate(0.15) }` reads beautifully. A seven-tranche
debt schedule with per-period rates, sweep tiers, and covenant triggers expressed in nested
result builders may read considerably worse than the equivalent `ModelDefinition` account list —
at which point we will have added five types and a breaking change to produce a worse authoring
experience than the thing we already had.

Second assumption: that `Schedule`'s literal conformances actually keep source compatibility in
practice. Result builders plus multiple `ExpressibleBy*` conformances is a known source of
ambiguous overloads and pathological type-check times. §7 names it and §10 tests for it, but a
compile-time budget test is a smoke alarm, not a fire suppression system.

A constraint accepted without much challenge: that the DSL must express the *entire* Wharton
model. A DSL that covers the operating model and hands the debt schedule to a
`ModelDefinition` — composing the two — might be the honest division of labour.

**What an experienced critic would say.**

*"You already built this. `ModelDefinition` is a general period-indexed model with formulas and
a cycle solver; you are proposing to rebuild it in result-builder syntax and calling the
duplication expressiveness."*

**Why we are proceeding anyway — with a change.** The critic is substantially right about B and
D, which is why §0 exists and why this proposal **consumes** `CycleSolver` rather than writing a
solver. Where the critic is not right is Gaps A1, C, and E: A1 is a live bug in `CashFlowModel`
regardless of any import story; E destroys line-item names that no `ModelDefinition` alternative
restores; and C has no implementation anywhere reachable.

**The change:** Part 1 (A1) is severed into its own immediately-shippable unit, independent of
everything else, and §15 Q1 raises the targeting question as a blocking decision to be made
*before* Part 2 begins rather than assumed away here.

## 13. Alternatives Considered

**Alternative 1: Make `ModelDefinition` the Excel import target; leave the DSL scalar.**
- *Advantage:* Nearly free — accounts, formulas, `TimeSeries`, cycle detection, and iterative
  solving all ship today. Maps onto arbitrary workbooks, not just DSL-shaped ones.
- *Disadvantage:* The output is `[String: TimeSeries<Double>]` keyed by account name — closer to
  a recalculated spreadsheet than to a typed model. It gives up the type-safety argument that
  motivates a DSL at all, and gives up named components (`Revenue`, `Taxes`) as semantic anchors.
- *Status:* **Genuinely competitive. Raised as blocking Open Question §15 Q1.** These are not
  exclusive: `ModelDefinition` could be the general path with the DSL as an optional typed
  projection when a model fits the scalar shape.

**Alternative 2: Lift `CapitalStructureProjection` from Pro into core.**
- *Advantage:* Real, tested code that already does per-period interest, draw/repay, and sweep.
- *Disadvantage:* It is revolver-centric and rating-driven — it models a corporate treasury
  function, not an LBO term loan with a balloon. It also takes `operatingCashFlows: [Double]` as
  a *precomputed input*, so it deliberately does not close the cycle back into the operating
  model, which is exactly the hard part here.
- *Why rejected as a lift:* Wrong shape for the use case. Retained as prior art and as the
  eventual consumer of a shared primitive (§14).

**Alternative 3: Fix Gap A1 only; decline B, C, E.**
- *Advantage:* Ships the correctness fix now, adds no API surface, keeps the DSL small and
  honest about being an unlevered modelling tool.
- *Disadvantage:* Leaves the `BusinessMathExcel` recognizer capped at simple unlevered workbooks,
  well short of its 100% Wharton goal.
- *Why rejected:* Only as a *complete* answer. Part 1 adopts it as the immediate first step.

**Alternative 4: Adopt orcaset's effect-handler runtime wholesale.**
- *Advantage:* A proven design for exactly this problem — `PeriodSeries`, day-count-aware
  queries, seeded fixed-point cycle resolution.
- *Disadvantage:* It is a second evaluation engine alongside `ModelDefinition`, in a different
  paradigm, under SSPL.
- *Why rejected:* We already have the pieces. Their `pitfalls.md` is worth reading as a
  requirements document (flows vs stocks, accrual vs exact, sign conventions, ratio
  aggregation); their runtime is not worth importing.

## 14. Future Directions

- **Rebase Pro onto the shared primitive.** If `DebtSchedule` lands in core, Pro's
  `CapitalStructureProjection` could be reimplemented over it, leaving one debt engine.
- **Covenant triggers.** Sweep percentages that step with leverage ratios; `RevolverFacility`'s
  `PricingTier` already models the pricing half.
- **Three-statement output.** With interest, capex, and ΔNWC present, a balance sheet and cash
  flow statement become derivable; core already has financial-statement types.
- **`Schedule.formula` resolution.** Wiring the `.formula` case through `FormulaEvaluator` would
  let a recognizer transcribe an Excel formula it cannot classify, rather than discarding it.
- **Quarterly and monthly models.** `Period` supports both; `CashFlowModel`'s `Int` year index
  does not.
- **Non-trapping migration.** Existing `preconditionFailure` sites could migrate to throwing
  initializers across a major version.

## 15. Open Questions

1. **BLOCKING — What is the Excel importer's target: `BusinessMathDSL` or `ModelDefinition`?**
   (§12, §13 Alternative 1.) This decides whether Part 2 is built at all. Recommend deciding
   before Part 2 starts; Part 1 is unaffected either way.
2. **Gap A1: fix (a) subtract capex, or (b) rename and deprecate?** Recommend (a).
3. **Does the `freeCashFlow` change warrant a major version,** or a minor with a loud CHANGELOG
   entry? It is a silent numeric change to existing callers, which argues for major.
4. **Should `Sendable` conformance be retrofitted across the whole DSL** as its own work item?
   The target already enables `StrictConcurrency` but no type conforms — that is a latent issue
   independent of this proposal.
5. **Does `DebtSchedule` need multiple tranches in v1,** or is a single tranche enough for
   Wharton plus most teaching cases?
6. **Period granularity:** does `CashFlowModel` keep `calculate(year: Int)` alongside
   period-indexed evaluation, or migrate wholesale?

## 16. Documentation Strategy

**Documentation Type:** Narrative Article Required

**Complexity Threshold Check:**
- Combines 3+ APIs? **Yes** — `Schedule`, `DebtSchedule`, `CashFlowModel`, `CycleSolver`,
  `TimeSeries`, `Period`.
- Requires 50+ lines to explain? **Yes** — the Wharton walkthrough alone.
- Needs theory/background? **Yes** — circular interest, and when to break a cycle by timing
  (`.beginningBalance`) versus resolving it by iteration (`.averageBalance`), is the conceptual
  core and the most common modelling error.

**Article Name:** `1.6-CapitalStructureModelingGuide.md` (follows the existing numbered DocC
convention, e.g. `1.4-FluentAPIGuide.md`, `1.5-TemplateGuide.md`). Does not collide with any
Swift symbol name.

Also requires: a CHANGELOG entry stating the `freeCashFlow` numeric change explicitly, and an
update to `Sources/BusinessMathDSL/README.md`, whose Quick Start predates all of this.

---

## Proposed Phasing

| Phase | Scope | Gate |
|---|---|---|
| **1** | **Gap A1 only** — capex/ΔNWC in `freeCashFlow`, DocC + CHANGELOG. Ships independently. | A1 regression test red→green; DCF EV demonstrably lower; existing suite green |
| — | **Decision point on §15 Q1** (DSL vs `ModelDefinition` as import target) | User decision |
| 2 | `Schedule` + literal conformances (Gap B) | Existing suite passes unmodified; compile-time budget test green |
| 3 | `LineItem` identity in `Expenses` (Gap E) | Round-trip name preservation; `fixedAmount` unchanged |
| 4 | `DebtSchedule` + `.beginningBalance` interest (Gap C, acyclic) | Term loan matches Excel `IPMT`/`PPMT` fixture |
| 5 | `.averageBalance` via `CycleSolver` + tax on EBT (Gap C cyclic, Gap A2) | **Wharton IRR 24.67% / MoM 3.01; year-1 interest 11.75** |
| 6 | `CashFlowModel`/`Forecast` convergence (Gap E remainder) | One forecast model; no duplicated capex/NWC types |
| 7 | `1.6-CapitalStructureModelingGuide.md`, README, master plan reconciliation | Quality gate 0/0 |

Phase 1 is deliberately severed: it is a live bug with a propagating blast radius and it should
not wait on a design decision about anything else.

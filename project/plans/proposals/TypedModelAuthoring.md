# Design Proposal: typed, unit-checked authoring over `ModelDefinition` — and the removal of `BusinessMathDSL`

**Date:** 2026-09-01
**Status:** Approved 2026-09-01 — phases 1–2d scoped as 2.8.0; see the release mapping under Proposed Phasing
**Supersedes:** `DSLExpressiveness.md` (same day, not implemented — kept for its prior-art audit)
**Companion:** `BusinessMathExcel/project/plans/proposals/PROPOSAL_excel_to_model_recognizer.md`

Every claim about current state carries a `file:line` and was verified against the working tree
on 2026-09-01 at `v2.6.0`.

---

## 1. Objective

Three things, in one arc:

1. **Add a typed authoring layer over `ModelDefinition`** — `Account<Unit>` and `Expr<Unit>` —
   that renders to the string formulas `FormulaEvaluator` already parses, with **phantom-typed
   units** so that adding a margin to a cash balance is a compile error.
2. **Extend `FormulaEvaluator`'s grammar with functions**, starting with `MIN`/`MAX`. Without
   them a cash sweep cannot be expressed, which caps the Excel importer well short of its goal.
3. **Delete `BusinessMathDSL`.** It has no consumers, duplicates core, and the one piece with no
   core equivalent — the tiered distribution waterfall — is a domain model that belongs in core
   anyway.

## 2. Motivation

**Current situation.** `ModelDefinition<T>` (`Model Definition/ModelDefinition.swift:119`) is a
general period-indexed model: named accounts, string formulas over `TimeSeries<T>`,
`requiredInputs()`, `evaluationOrder()`, `evaluate() -> [String: TimeSeries<T>]`, SCC cycle
detection via `dependencyReport()`, and cycle resolution through `CycleSolver.solve`
(`CycleSolver.swift:234`) backed by `IterativeCycleSolver`. It is a complete and capable model
layer, and per `IterativeSolver.md` §1 it was built for people migrating from Excel.

Its one ergonomic weakness is that it is **stringly typed**:

```swift
model.defining("ebitda", as: "revenue - expenses")
```

A misspelled account is not a compile error. It surfaces at evaluation as
`FormulaError.unknownAccount(String)` (`FormulaEvaluator.swift:12`), or worse, silently resolves
to a different account that happens to exist. Rename and find-usages do not work through string
literals.

**Meanwhile, `BusinessMathDSL` exists and solves none of this.** It was intended as the typed
authoring surface, but:

- **It has zero consumers.** `grep -rl "import BusinessMathDSL"` across every sibling package
  returns only its own four test files plus its own README and `CashFlowModel.swift`. No package
  declares it as a dependency — not `BusinessMathPro`, not the MCP server, not the UI, not
  `BusinessMathExcel`, not the demos. It is a library product nothing has ever linked.
- **It duplicates core**, catalogued in `DSLExpressiveness.md` §0. Most sharply: `Scenario` and
  `ScenarioAnalysis` exist in *both* `BusinessMathDSL/Scenario.swift` and
  `Simulation/MonteCarlo/ScenarioAnalysis.swift:113,167`. Two types with the same name in the
  same package, in different targets — importing both is ambiguous.
- **The core versions are better built.** `Simulation/MonteCarlo/ScenarioAnalysis.swift:113,167`
  is `Sendable`; **no type in `BusinessMathDSL` conforms to `Sendable`** despite the target
  enabling `StrictConcurrency` at `Package.swift:133-135`. Core throws; the DSL calls
  `preconditionFailure` on out-of-range input (`Revenue.swift:74,90,106,111`,
  `Taxes.swift:102,118`, `Forecast.swift:28-151`).
- **It carries a live bug.** `CashFlowModel.freeCashFlow(year:)` returns
  `netIncome + depreciation` with no capex (`CashFlowModel.swift:223-230`) and feeds
  `DCFModel.calculateEnterpriseValue()` at `DCFModel.swift:144`, overstating enterprise value by
  PV(capex). The entire blast radius is inside the module — both types live in
  `BusinessMathDSL` — so **deletion is the fix.**
- **Its expressiveness is trivially small.** One `Base`, one `GrowthRate`, one
  `variablePercentage`, one `CorporateRate`. It cannot express a standard teaching case.

**Drawback of the status quo.** We maintain two model layers. The capable one has poor
ergonomics; the ergonomic one cannot express anything and nobody uses it.

**Workaround.** None. A caller wanting both capability and type safety has neither.

## 3. Proposed Architecture

**Design principle: the string is an encoding, not the interface.** A typed expression tree
renders to the grammar `FormulaEvaluator` already parses. `ModelDefinition`, `FormulaEvaluator`,
`CycleSolver`, and `IterativeCycleSolver` are **not modified** by Part 1 — the typed layer is
purely additive, and deleting it would break nothing.

The bracketed-name form makes this safe. `FormulaEvaluator.tokenise` (`:227-236`):

```swift
// A bracketed name is taken literally, which is how an account called
// "Sales & Marketing" or "A/P" survives a tokeniser that would otherwise read the
// ampersand and the slash as operators.
if character == "[" { … }
```

So `Account("Sales & Marketing")` renders to `[Sales & Marketing]` with no escaping ambiguity.

### Module placement

**Core, in `Sources/BusinessMath/Model Definition/`.** Not a new target. The layer is roughly
300 lines with no dependencies beyond what `ModelDefinition` already has, and spinning up a
separate target for 300 lines is precisely the mistake this proposal unwinds.

**New Files:**

| File | Role |
|---|---|
| `Model Definition/Units.swift` | `Unit` protocol; `Money`, `Rate`, `Ratio`, `Duration` markers |
| `Model Definition/LineItem.swift` | `LineItem<U: Unit>` — typed handle (renamed from `Account<U>`; see §15 Q6) |
| `Model Definition/Expr.swift` | `Expr<U: Unit>` tree + rendering + operator algebra |
| `Model Definition/TypedModel.swift` | `ModelDefinition.defining(_:as:)` typed overloads |
| `Financial Statements/Waterfall/` | `Tier`, `TierComponents`, `LiquidationWaterfall` migrated from the DSL |

**Modified Files:**

- `Time Series/FormulaEvaluator.swift` — function support in tokeniser, parser, and evaluator.
- `Package.swift` — remove the `BusinessMathDSL` product and target.
- `Tests/BusinessMathTests/Result Builder Tests/WaterfallBuilderTests.swift` — retarget to core.

**Deleted:** `Sources/BusinessMathDSL/` in full, and the three other `Result Builder Tests` files
(`ValuationBuilderTests`, `CashFlowBuilderTests`, `ScenarioAnalysisBuilderTests`) whose subjects
are being removed.

## 4. API Surface

### Part 1 — units

```swift
/// A dimensional marker for a line item or expression.
public protocol ModelUnit: Sendable {  // not `Unit` — see §15 Q9
    static var symbol: String { get }
}

/// A currency amount: revenue, cost, a balance, a cash flow.
public enum Money: ModelUnit { public static var symbol: String { "money" } }

/// A per-period rate: growth, interest, decay. Carries a period basis (see below).
public enum Rate: ModelUnit { public static var symbol: String { "rate" } }

/// A dimensionless ratio: a margin, a multiple, a percentage.
public enum Ratio: ModelUnit { public static var symbol: String { "ratio" } }

/// A count of periods, units, or shares. Not `Duration` — see §15 Q8.
public enum Count: ModelUnit { public static var symbol: String { "count" } }
```

### Part 1 — accounts and expressions

```swift
/// A typed handle to a named line item. Its existence as a Swift value is the guarantee:
/// a misspelled reference does not compile, and rename/find-usages work.
public struct LineItem<U: ModelUnit>: Sendable, Hashable {
    public let name: String
    /// For `Rate` items, the period the rate is expressed per. Validated at model
    /// build time — see §12 for why this is a value and not a second type parameter.
    public let basis: PeriodType?

    public init(_ name: String, basis: PeriodType? = nil)
}

/// An expression over line items, carrying its unit.
public struct Expr<U: ModelUnit>: Sendable {
    /// The rendered formula in `FormulaEvaluator` grammar.
    public var formula: String { get }

    public static func item(_ i: LineItem<U>) -> Expr<U>
    public static func constant(_ value: Double) -> Expr<U>
}

extension LineItem { public var expr: Expr<U> { .item(self) } }
```

### Part 1 — the unit algebra

This is the substance. Legal combinations get an overload; illegal ones simply have none, so
they fail to compile.

```swift
// Same-unit addition and subtraction.
public func + <U: ModelUnit>(lhs: Expr<U>, rhs: Expr<U>) -> Expr<U>
public func - <U: ModelUnit>(lhs: Expr<U>, rhs: Expr<U>) -> Expr<U>
public prefix func - <U: ModelUnit>(operand: Expr<U>) -> Expr<U>

// Scaling money by a dimensionless quantity.
public func * (lhs: Expr<Money>, rhs: Expr<Ratio>) -> Expr<Money>
public func * (lhs: Expr<Ratio>, rhs: Expr<Money>) -> Expr<Money>
public func * (lhs: Expr<Money>, rhs: Expr<Rate>)  -> Expr<Money>
public func * (lhs: Expr<Rate>,  rhs: Expr<Money>) -> Expr<Money>

// Dimensionless composition.
public func * (lhs: Expr<Ratio>, rhs: Expr<Ratio>) -> Expr<Ratio>

// Division derives dimension.
public func / (lhs: Expr<Money>, rhs: Expr<Money>)    -> Expr<Ratio>     // margin
public func / (lhs: Expr<Money>, rhs: Expr<Count>)    -> Expr<Money>     // per unit
public func / (lhs: Expr<Money>, rhs: Expr<Ratio>)    -> Expr<Money>     // gross-up
public func / (lhs: Expr<Ratio>, rhs: Expr<Ratio>)    -> Expr<Ratio>

// NO overload exists for:
//   Expr<Money> + Expr<Ratio>      — adding a margin to a balance
//   Expr<Rate>  + Expr<Money>      — adding a rate to an amount
//   Expr<Money> * Expr<Money>      — money squared is not a quantity
```

Literals are **explicit by construction**, not `ExpressibleByFloatLiteral`:

```swift
public func money(_ v: Double) -> Expr<Money>
public func ratio(_ v: Double) -> Expr<Ratio>
public func rate(_ v: Double, per basis: PeriodType) -> Expr<Rate>

/// One plus a rate: the growth factor `(1 + g)`.
///
/// `1 + g` cannot be written directly, because a dimensionless `1` and a per-period
/// rate are not the same dimension and no overload adds them. See §15 Q7.
public func factor(_ r: Expr<Rate>) -> Expr<Ratio>
```

Bare float literals would infer their unit from context, which reintroduces exactly the
ambiguity the units exist to prevent — and produces the overload-resolution errors Swift is
worst at reporting. `revenue * ratio(0.4)` is three characters longer and unambiguous.

### Part 1 — binding to `ModelDefinition`

```swift
extension ModelDefinition {
    /// Typed overload. Delegates to the existing string API; nothing below is modified.
    public func defining<U: ModelUnit>(_ item: LineItem<U>, as expr: Expr<U>) -> ModelDefinition<T>

    /// Reads a typed result out of an evaluation.
    public func series<U: ModelUnit>(for item: LineItem<U>,
                                in results: [String: TimeSeries<T>]) -> TimeSeries<T>?

    /// Validates rate bases and account bindings before evaluation.
    /// - Throws: ``TypedModelError``
    public func validateUnits() throws
}

public enum TypedModelError: Error, Sendable, Equatable {
    /// A `Rate` account was used without a period basis where one is required.
    case missingRateBasis(account: String)
    /// A rate expressed per one period was applied over another without conversion.
    case rateBasisMismatch(account: String, declared: PeriodType, applied: PeriodType)
    /// Two accounts share a name but differ in unit.
    case conflictingUnits(name: String, String, String)
}
```

### Part 2 — grammar functions, delegating to canonical implementations

**Rule: `FormulaEvaluator` implements no financial mathematics.** Every financial function
dispatches to the canonical BusinessMath implementation. Reimplementing `NPV` inside the
evaluator would give this codebase two NPVs that could disagree — which is precisely the failure
mode that motivates this whole line of work.

```swift
extension FormulaEvaluator {
    /// A function callable from formula text.
    ///
    /// Arithmetic primitives are implemented here. Everything financial delegates to
    /// the canonical implementation in `Time Series/TVM/`; this enum is a dispatch
    /// table, not a second library.
    public enum Function: String, Sendable, CaseIterable {
        // Arithmetic primitives — implemented locally.
        case min = "MIN", max = "MAX", abs = "ABS", sum = "SUM"

        // Conditional — implemented locally. See "Conditionals" below.
        case ifThenElse = "IF"

        // Financial — delegated. Canonical implementation named per case.
        case npv   = "NPV"    // → npvExcel(rate:cashFlows:)        NPV.swift:237
        case irr   = "IRR"    // → irr(cashFlows:guess:)            IRR.swift:87
        case mirr  = "MIRR"   // → mirr(...)                        IRR.swift:217
        case xnpv  = "XNPV"   // → xnpv(...)                        XNPV.swift:94
        case xirr  = "XIRR"   // → xirr(...)                        XNPV.swift:222
        case pmt   = "PMT"    // → payment(...)                     Payment.swift:78
        case ppmt  = "PPMT"   // → principalPayment(...)            Payment.swift:138
        case ipmt  = "IPMT"   // → interestPayment(...)             Payment.swift:201
        case pv    = "PV"     // → presentValue(...)                PresentValue.swift:70
        case fv    = "FV"     // → futureValue(...)                 FutureValue.swift:44

        /// Permitted argument counts. Enforced at parse time.
        public var arity: ClosedRange<Int> { get }
    }
}

// Grammar additions: a `comma` token, a `function(Function, [Node])` case in `Node`,
// and a call production in `parsePrimary`. The existing 256-deep nesting guard covers
// function arguments, which are just more nested expressions.
```

**The `NPV` trap, and why it must be decided explicitly.** BusinessMath ships *two* NPVs, and
`NPV.swift:215-217` documents the difference:

| Function | First cash flow | Formula |
|---|---|---|
| `npv()` | Not discounted (t=0, today) | `CF₀ + CF₁/(1+r) + CF₂/(1+r)² + …` |
| `npvExcel()` | Discounted (end of period 1) | `CF₀/(1+r) + CF₁/(1+r)² + CF₂/(1+r)³ + …` |

A formula string parsed out of a workbook came from Excel, so **`NPV` in formula text must bind
to `npvExcel`**, not to `npv`. Binding it to the textbook version would silently mis-discount
every imported model by one period — a wrong number that looks entirely plausible. The dispatch
table records this binding in code rather than leaving it to a reader's assumption, and §10 tests
it against Excel directly.

Callers who want textbook NPV keep calling `npv()` in Swift, where the choice is explicit.

**The `NPV` trap generalises, and it is the real work of Phase 2.** BusinessMath core exposes
**616 unique public functions**, and Excel equivalence is documented across the library, not just
in TVM — `NORM.S.DIST`, `NORM.S.INV`, `STANDARDIZE`, `CUMIPMT`, `CUMPRINC`, plus the statistical
surface (`AVERAGE`, `CORREL`, `COVAR`, `MEDIAN`, `BINOM.DIST`, `CHISQ.DIST`, `CONFIDENCE`). So
the registry is not gated on writing implementations — they exist. It is gated on **verifying,
per name, that our function matches Excel's semantics**, because the mismatches are exactly the
kind that produce plausible wrong numbers:

- `NPV` — discounting offset (above).
- `STDEV` vs `STDEVP`, `VAR` vs `VARP` — sample versus population denominator.
- `NORM.S.DIST` — Excel's `cumulative` flag selects CDF or PDF; our equivalent is documented as
  the cumulative case only (`Normal Deviate/`).
- `IRR` — Excel's `guess` default and its convergence behaviour on multiple sign changes.

Each registered name therefore ships with a documented semantics assertion and an Excel-derived
fixture (§10). That is the unit of work, and it parallelises cleanly across names.

### Which functions, measured rather than assumed (2026-09-01)

**Not all of Excel.** Excel has roughly 500 functions. Two real models were counted — the Wharton
LBO Practice Model and a production credit model — and between them they call **31 distinct
names**:

| Workbook | Distinct | Heaviest use |
|---|---|---|
| Wharton LBO | **4** | `SUM` ×14, `IF` ×2, `AVERAGE` ×2, `IRR` ×1 |
| Credit model | **30** | `IF` ×3170, `ISERROR` ×2145, `SUM` ×1786, `OFFSET` ×852, `ISBLANK` ×386, `MATCH` ×360 |

**This contradicts the tranche order above, and the tranches should move.** Phase 2b registers
the TVM set — `PMT`, `IPMT`, `PPMT`, `XIRR`, `XNPV`, `MIRR`, `FV` — and *none of them appears in
either workbook*. `NPV` and `PV` appear; `IRR` appears once. Phase 2c's statistical tranche fares
no better: `AVERAGE` twice, and nothing else.

Where the volume actually is:

| Family | Names | Calls |
|---|---|---|
| Logical and error | `IF`, `ISERROR`, `ISBLANK`, `ISNA`, `ISNUMBER`, `OR`, `AND`, `NOT` | ~6,100 |
| Aggregation | `SUM`, `AVERAGE` | ~1,800 |
| Reference | `OFFSET`, `MATCH`, `INDIRECT`, `ADDRESS`, `INDEX`, `ROW`, `COLUMN` | ~1,900 |
| Date and text | `YEAR`, `MONTH`, `DAY`, `NOW`, `RIGHT`, `LEFT`, `TEXT`, `ROUND` | ~350 |

Two consequences worth stating plainly. **The TVM tranche is not the unblocking work it was
assumed to be** — it is worth registering because the library already has the implementations and
the Excel-semantics verification is the real cost, but it should not be sequenced ahead of the
logical family, which is where every real formula lives. And **`ISERROR`/`ISNA` are not
functions in the ordinary sense**: they ask whether evaluating their argument *failed*, and this
evaluator has no error value to inspect — it throws. Registering them needs a decision about
whether the grammar gains an error value at all, which is a design question and not a name
binding.

The reference family is separately covered by the dynamic-reference tiers in
`BusinessMathExcel`'s recognizer proposal, and does not belong in this grammar.

**How the set should grow:** by `.unregisteredFunction` diagnostics from real workbooks, which
are a ranked worklist of what to register next. Not by working through Excel's index.

### Conditionals — `IF` and comparison operators

`FormulaEvaluator` has **no comparison operators today**: its token set is `number`, `name`,
`+ - * / ( )`. So `IF` is not a dispatch-table entry — it needs comparison tokens
(`> < >= <= = <>`), a comparison production in the parser, and a decision about what a truth
value means over a `TimeSeries`.

**Representation.** A comparison evaluates period-wise to `1` or `0`, matching Excel's
`TRUE`/`FALSE` numeric coercion, so there is one value type throughout and no `Bool` series to
thread. `IF(condition, then, else)` selects period-wise.

**The units make this safer than Excel.** A fifth marker joins the four in §4:

```swift
/// The result of a comparison. Cannot be combined arithmetically with anything.
public enum Condition: Unit { public static var symbol: String { "condition" } }

// Comparisons require matching units — money against money, never money against a ratio.
public func >  <U: ModelUnit>(lhs: Expr<U>, rhs: Expr<U>) -> Expr<Condition>
public func <  <U: ModelUnit>(lhs: Expr<U>, rhs: Expr<U>) -> Expr<Condition>
public func >= <U: ModelUnit>(lhs: Expr<U>, rhs: Expr<U>) -> Expr<Condition>
public func <= <U: ModelUnit>(lhs: Expr<U>, rhs: Expr<U>) -> Expr<Condition>

/// Both branches must share a unit, so a conditional cannot smuggle a ratio
/// into a money-valued account.
public func ifThen<U: ModelUnit>(_ c: Expr<Condition>, _ then: Expr<U>, else: Expr<U>) -> Expr<U>
```

`Condition` has no arithmetic overloads at all, so `revenue + (a > b)` does not compile — a
mistake Excel makes silently, since there `TRUE` is just `1`.

### When *not* to reach for `IF`

`IF` exists for genuine conditional logic — a covenant test, a sweep that only triggers above a
cash floor, a tier that pays only once a hurdle clears. It is **not** the preferred way to encode
a schedule.

A balloon payment in period 5 is a *fact about the timeline*, not a decision the model makes.
Encoding it as `IF([Period Index] = 5, [Debt], 0)` buries a date inside a formula, where it
cannot be inspected, varied, or recognized as data. Encoding it as an indicator input series
`[0, 0, 0, 0, 1, 0]` multiplied through keeps the formula uniform and puts the schedule where
schedules belong — in the inputs, alongside every other assumption.

**Rule of thumb: if the condition is answerable from the timeline alone, it is data. If it
depends on a computed value, it is `IF`.** Both are supported; the first is preferred, and the
DocC guide (§16) leads with it.

This also matters for the importer: a recognized `IF` whose test reads only period position
should be re-expressed as an indicator series rather than transcribed literally. See
`PROPOSAL_excel_to_model_recognizer.md`.

**Seeding the registry.** `BusinessMathExcel`'s `FormulaMapper` already carries curated Excel
name lists — `financialFunctions` (`PMT`, `IPMT`, `PPMT`, `FV`, `PV`, `NPV`, `IRR`, `XIRR`,
`XNPV`, `RATE`, `NPER`, `SLN`, `DB`, `DDB`) and `statisticalFunctions` (`AVERAGE`, `STDEV`,
`STDEVP`, `VAR`, `VARP`, `PERCENTILE`, `MEDIAN`, `MODE`, `COUNT`, `COUNTA`, `COUNTIF`, `MIN`,
`MAX`, `SUM`). Those lists were built by classifying real workbook formulas and are the natural
first tranche — they represent names already observed in the wild rather than a guess at what
matters.

Typed surface:

```swift
public func min<U: ModelUnit>(_ a: Expr<U>, _ b: Expr<U>) -> Expr<U>
public func max<U: ModelUnit>(_ a: Expr<U>, _ b: Expr<U>) -> Expr<U>
```

Note the unit discipline carries: `min` of two `Money` is `Money`; `min(money, ratio)` has no
overload.

### Worked example — a cash sweep, which is currently inexpressible

```swift
let fcf            = LineItem<Money>("Free Cash Flow")
let openingDebt    = LineItem<Money>("Opening Debt")
let interestRate   = LineItem<Rate>("Interest Rate", basis: .annual)
let interest       = LineItem<Money>("Interest")
let sweep          = LineItem<Money>("Sweep Paydown")
let closingDebt    = LineItem<Money>("Closing Debt")

let model = ModelDefinition<Double>(periods: periods)
    .defining(interest,    as: openingDebt.expr * interestRate.expr)
    .defining(sweep,       as: min(fcf.expr, openingDebt.expr))
    .defining(closingDebt, as: openingDebt.expr - sweep.expr)

try model.validateUnits()
let results = try model.evaluate()      // cycle resolution unchanged, via CycleSolver
```

`fcf.expr + interestRate.expr` would not compile. Neither would `min(fcf.expr, ratio(0.4))`.

### Part 2.5 — the rollforward driver (added after review)

**Finding: prior-period references are deliberately absent, and this is documented twice.**

`FormulaEvaluator.swift:119-124`:

> **What it deliberately does not have**
> No functions, no aggregation, no references to other periods. A formula reads accounts in the
> period it is evaluating and combines them arithmetically. Anything that needs to look across
> periods — a moving average, a prior-year comparison — is a time series operation and belongs
> in one, where it can be named and tested.

`CycleSolver.swift:222-226`:

> **What it cannot express**
> The same thing `evaluate()` cannot: a reference to another period. A cycle here is a cycle
> *within* one period. **An opening balance is supplied as data and the roll-forward that
> carries a closing balance into the next period stays the caller's loop.**

This is not an oversight; it is a boundary the architecture drew on purpose, and it assigns the
rollforward to the caller. **But no reusable caller exists.** Every consumer would write the same
period loop, and the Excel importer cannot ship without one — a workbook is rollforwards almost
end to end.

**Why this is not a grammar change.** `evaluate()` resolves whole `TimeSeries` in *account*
dependency order (`ModelDefinition.swift:264-274`). A formula `revenue = revenue.prior * 1.1`
makes `revenue` depend on itself at the account level, so the account-level DAG reports a cycle
and refuses the model — even though the reference is perfectly well-founded at the
(account, period) level. Supporting prior-period references *inside the grammar* means moving the
dependency graph from per-account to **per-(account, period)** — which is what Excel does with
cells and what orcaset does with `get_at(rule, key)`. That is a rewrite of the evaluation core,
not an addition to the tokeniser.

**Proposed instead: make the caller's loop a first-class, reusable component.** Formulas stay
period-local; cross-period carry is explicit data.

```swift
/// Carries one account's closing value into another account's opening value,
/// one period later.
public struct Rollforward: Sendable, Equatable {
    /// The account that receives the prior period's value.
    public let opening: String
    /// The account whose value is carried forward.
    public let closing: String
    /// The opening account's value in the first period, where there is no prior.
    public let seed: Double

    public init(opening: String, closing: String, seed: Double)
}

/// Runs a period-local `ModelDefinition` across a timeline, carrying rollforwards.
///
/// Each period: seed opening accounts from the prior period's closing values, slice
/// inputs to that period, `solve()`, and collect. Within-period cycles are resolved by
/// `CycleSolver`; cross-period carry is this type's job. The two never mix.
public struct PeriodDriver<T: Real & Sendable & LosslessStringConvertible>: Sendable {
    public init(
        definition: ModelDefinition<T>,
        rollforwards: [Rollforward]
    )

    /// - Throws: ``PeriodDriverError`` for a rollforward naming an unknown account or
    ///   forming a cross-period cycle; plus anything `solve()` throws, annotated with
    ///   the period it failed in.
    public func run(
        over periods: [Period],
        settings: IterationSettings<T> = IterationSettings()
    ) throws -> [String: TimeSeries<T>]
}

public enum PeriodDriverError: Error, Sendable, Equatable {
    case unknownAccount(String, inRollforward: String)
    case rollforwardCycle([String])
    case periodFailure(Period, underlying: String)
    case emptyTimeline
}
```

This respects the documented boundary rather than reversing it, and it yields a clean split that
is easy to test: **within-period cycles → `CycleSolver`; cross-period carry → `PeriodDriver`.**

Typed sugar, once Part 3 lands:

```swift
extension Account {
    /// Declares that this account opens at another's prior close.
    public func opening(from closing: LineItem<U>, seed: Double) -> Rollforward
}
```

### Part 3 — waterfall migration

`Tier`, `TierComponents` (`CapitalReturn`, `PreferredReturn`, `CatchUp`, `Residual`, `ProRata`),
`LiquidationWaterfall`, `WaterfallResult`, and `WaterfallContext` move to
`Financial Statements/Waterfall/` **unchanged in behaviour**, gaining `Sendable` conformance and
throwing initializers in place of `preconditionFailure` (`TierComponents.swift:77`). The
`@LiquidationWaterfallBuilder` result builder comes with them — it is genuinely good ergonomics
for a priority-ordered structure, and it is orthogonal to the model layer.

This is distinct from `CapTable.liquidationWaterfall(exitValue:)`
(`Financial Statements/EquityFinancing.swift:332`), which models liquidation *preferences* on a
cap table rather than a tiered distribution. Both are kept; §15 Q4 asks whether they should
eventually converge.

## 5. MCP Schema

The typed layer is a compile-time construct with no runtime representation, so it exposes no new
tool. The grammar extension changes an existing contract:

**Tool Description:** Evaluate a named-account model with per-period formulas, resolving cycles
by iteration.

**REQUIRED STRUCTURE (JSON):**
```json
{
  "periods": {"granularity": "annual", "start": 2022, "count": 7},
  "accounts": {
    "Opening Debt": {"unit": "money", "formula": "[Closing Debt Prior]"},
    "Interest Rate": {"unit": "rate", "basis": "annual", "value": 0.10},
    "Interest": {"unit": "money", "formula": "[Opening Debt] * [Interest Rate]"},
    "Sweep Paydown": {"unit": "money", "formula": "MIN([Free Cash Flow], [Opening Debt])"}
  },
  "iteration": {"maxIterations": 100, "absoluteTolerance": 1e-9, "relaxation": 1.0}
}
```

**Parameter Types:**
- `accounts` (object): account name → definition. Names may contain any character except `]`.
- `accounts.*.unit` (string): `"money"`, `"rate"`, `"ratio"`, `"duration"`. Optional; omitted
  means unchecked.
- `accounts.*.basis` (string, required when `unit` is `"rate"`): `"annual"`, `"quarterly"`,
  `"monthly"`.
- `accounts.*.formula` (string): `FormulaEvaluator` grammar — identifiers, `[Bracketed Names]`,
  numbers, `+ - * / ( )`, and `MIN`/`MAX`/`ABS`/`SUM`/`IF`.
- `iteration` (object, optional): maps to `IterationSettings`; `relaxation` ω ∈ (0, 2].

**Determinism:** Fully deterministic; no seed. Response reports `convergenceState` and
`iterationsUsed`.

## 6. Constraints & Compliance

**Concurrency:** `Account`, `Expr`, and every unit marker are immutable value types conforming to
`Sendable`. Migrated waterfall types gain `Sendable`, which they lack today.

**Safety:** No force unwraps, no `try!`, no force casts. Division sites in `FormulaEvaluator` are
unchanged; new `MIN`/`MAX` introduce none.

**Traps → thrown errors.** Migrated waterfall initializers throw rather than calling
`preconditionFailure` (`TierComponents.swift:77`). The typed layer has no trapping paths: units
are enforced at compile time, and basis mismatches throw from `validateUnits()`.

**Generics:** `Account<U: Unit>` and `Expr<U: Unit>` are constrained to the marker protocol.
`ModelDefinition<T: Real & Sendable & LosslessStringConvertible>` is unchanged.

**Bounded work:** The 256-deep parser nesting guard covers function arguments.

**DocC:** All new public API documented.

## 7. Source & API Compatibility

**Breaking change: removal of the `BusinessMathDSL` product and target.**

Justification: zero external consumers, verified by consumer search across every sibling package.
The only importers are four of its own test files. This is as close to a free removal as a public
product gets, but it *is* a public product, so:

- **Deprecate in the next minor** — `@available(*, deprecated, message:)` on every public DSL
  type, with a CHANGELOG entry naming `ModelDefinition` + `Account`/`Expr` as the replacement.
- **Remove in the next major.**
- **Exception — `Tier`/`LiquidationWaterfall` migrate rather than die.** They are deprecated at
  the old location with a `renamed:` pointer so the fix-it is automatic.

`DSLExpressiveness.md` proposed fixing `CashFlowModel.freeCashFlow`'s missing capex as an urgent
standalone correction. **That work is dropped**: `CashFlowModel` and `DCFModel` both live in
`BusinessMathDSL`, so the bug's entire blast radius is inside the module being removed, and it
has no consumers to harm in the interim. Deletion is the fix. This is recorded so the decision is
not silently lost.

**Non-breaking:**
- The typed layer is purely additive. `defining(_ name: String, as formula: String)` keeps
  working and is still the path the Excel importer uses for formulas it cannot type.
- Grammar functions are additive: no currently-valid formula changes meaning. `MIN` was
  previously tokenised as a bare identifier and would have failed as `unknownAccount("MIN")`, so
  no working formula is reinterpreted.

**Type-checking risk — the main one.** Sixteen-plus operator overloads across four unit types is
exactly the shape that produces exponential type-checking and unhelpful "expression too complex"
diagnostics. Mitigations: (a) no `ExpressibleByFloatLiteral` on `Expr`, which removes the largest
source of ambiguity; (b) concrete overloads rather than a generic `Multipliable` protocol, so the
solver has fewer paths; (c) a compile-time budget test (§10). If the budget is exceeded, §13
Alternative 3 (runtime unit checking) is the documented fallback.

## 8. Backend Abstraction

**Not applicable.** The typed layer is compile-time only and generates strings. Evaluation
performance is `ModelDefinition`'s, unchanged.

## 9. Dependencies

**Internal (all existing):** `Model Definition/ModelDefinition.swift`, `CycleSolver.swift`,
`IterativeCycleSolver.swift`, `DependencyReport.swift`; `Time Series/FormulaEvaluator.swift`,
`TimeSeries.swift`, `Period.swift`, `PeriodType.swift`.

**External:** None.

**Explicitly NOT a dependency:** `BusinessMathPro`. Pro depends on BusinessMath
(`BusinessMathPro/Package.swift:40-43`), so its `CapitalStructureProjection` and
`RevolverFacility` are unreachable from core — a package cycle. They remain prior art; see §14.

**Removed:** the `BusinessMathDSL` target's `swift-numerics` product dependency
(`Package.swift:127`) goes with the target. Core already depends on Numerics separately.

## 10. Test Strategy

**Test Categories:**

- *Rendering* — `Expr` renders to formulas `FormulaEvaluator.tokenise` accepts; names containing
  `&`, `/`, and spaces round-trip through the bracketed form.
- *Unit algebra, negative (the important half)* — compile-failure tests that
  `Expr<Money> + Expr<Ratio>`, `Expr<Rate> + Expr<Money>`, and `Expr<Money> * Expr<Money>` do not
  compile. Verified with a `swift build` harness asserting a diagnostic, since a non-compiling
  case cannot live in a normal test target.
- *Unit algebra, positive* — `Money * Ratio → Money`, `Money / Money → Ratio`,
  `Money / Duration → Money`, `min(Money, Money) → Money`.
- *Rate basis* — an annual rate applied to a monthly period throws
  `TypedModelError.rateBasisMismatch`.
- *Grammar functions* — parse, evaluate, nest, and respect the 256 guard; arity errors are
  reported, not tolerated.
- *Delegation equivalence (critical)* — for every financial function in the dispatch table,
  evaluating the formula string must return **bit-identical** results to calling the canonical
  Swift function with the same arguments. This is the test that keeps one implementation from
  becoming two.
- *`NPV` binding* — `"NPV(0.1, [CF])"` in formula text must equal `npvExcel(rate:cashFlows:)`
  and must **differ** from `npv(discountRate:cashFlows:)` for the same inputs. A test asserting
  the difference is as important as one asserting the match: it pins the binding so a later
  "cleanup" cannot quietly swap it.
- *Cycle integration* — the sweep model above converges through `CycleSolver` and produces
  identical results to the equivalent hand-written string formulas. **The typed layer must be a
  pure rendering convenience: same strings in, same numbers out.**
- *Waterfall migration* — `WaterfallBuilderTests` passes unchanged against the core location;
  new tests cover throwing initializers where `preconditionFailure` stood.
- *Removal* — the package builds with no `BusinessMathDSL` target; no remaining source or test
  file references it.
- *Compile-time budget* — the worked example type-checks under a fixed ceiling.

**Reference Truth:**

1. **Excel** for `MIN`/`MAX`/`ABS` semantics, including the boundary cases (`MIN` of equal
   arguments, `ABS` of `-0.0`).
2. **The existing string API** for the equivalence property — the strongest available check,
   since it compares the new layer against the shipped evaluator rather than against a
   hand-computed expectation.
3. **Wharton LBO Practice Model** (Penn Career Services) — published **IRR 24.67%**,
   **MoM 3.01**, independently reproduced by orcaset's `examples/paper-lbo`.

**Validation Trace (REQUIRED):**

> **Rendering.** `LineItem<Money>("Sales & Marketing").expr - LineItem<Money>("A/P").expr`
> must render exactly `([Sales & Marketing] - [A/P])`, and
> `FormulaEvaluator.tokenise` of that string must yield
> `[.name("Sales & Marketing"), .minus, .name("A/P")]` wrapped in parens — proving the
> ampersand and slash survive, which is the property `FormulaEvaluator.swift:227-229` documents.
>
> **Equivalence.** For the sweep model in §4, with `Free Cash Flow = [10, 12, 15]`,
> `Opening Debt(t0) = 120`, `Interest Rate = 0.10`:
> `model.evaluate()` built through the typed layer must produce a `[String: TimeSeries<Double>]`
> **equal element-for-element** to the same model built with
> `.defining("Sweep Paydown", as: "MIN([Free Cash Flow], [Opening Debt])")`.
> Any divergence is a rendering bug.
>
> **`MIN` semantics.** `MIN(10, 120)` = 10, matching Excel's `=MIN(10,120)`. With
> `Free Cash Flow = 10` and `Opening Debt = 120`, `Sweep Paydown` = **10**, and
> `Closing Debt` = **110**.
>
> **Negative unit test.** `LineItem<Money>("Cash").expr + LineItem<Ratio>("Margin").expr` must
> produce a compile diagnostic. This is the proposal's central claim; if it compiles, the units
> are decorative.

Floating-point assertions use accuracy-based comparison per the TDD contract.

## 11. Architecture Decision Review

**ADR Check:**
- [x] Reviewed `development-guidelines/rules/architecture_decisions.md`
- [x] Supersedes an existing ADR? **No**
- [x] Amends an existing ADR? **No** — consumes the capability recorded by `IterativeSolver.md`
      and `CircularDependencyDetection.md` (implemented in `87a717e`); this is their first typed
      caller.
- [x] New ADR required? **Yes — three**

**New ADR Drafts:**

- **Title:** `ModelDefinition` is the model layer; `BusinessMathDSL` is removed
- **Category:** architecture
- **Key decision:** One model layer, not two. `BusinessMathDSL` had zero consumers and duplicated
  `Scenario`/`ScenarioAnalysis`/valuation already in core. Typed authoring is delivered as a thin
  layer over `ModelDefinition` rather than as a parallel module.

- **Title:** Typed authoring renders to strings; the evaluator is not modified
- **Category:** api
- **Key decision:** `Expr<U>` generates `FormulaEvaluator` grammar rather than bypassing it.
  The typed layer is deletable without breaking the model layer, and the string API stays
  first-class for callers (notably the Excel importer) that cannot type their input.

- **Title:** Cross-period carry is a driver, not a formula reference
- **Category:** architecture
- **Key decision:** Formulas stay period-local, as `FormulaEvaluator.swift:119-124` and
  `CycleSolver.swift:222-226` deliberately specify. The rollforward the docs assign to "the
  caller's loop" becomes a reusable `PeriodDriver` rather than a grammar feature, because
  prior-period references inside the grammar would require moving the dependency graph from
  per-account to per-(account, period) — a rewrite of the evaluation core. Within-period cycles
  resolve via `CycleSolver`; cross-period carry is `PeriodDriver`'s job; the two never mix.

- **Title:** `FormulaEvaluator` implements no financial mathematics
- **Category:** architecture
- **Key decision:** Every financial function in formula text dispatches to the canonical
  BusinessMath implementation. The evaluator holds a name-to-function dispatch table, never a
  second implementation. Each registered name binds to a specific canonical function — notably
  `NPV` → `npvExcel`, not `npv` — and that binding is pinned by test.

- **Title:** Units are phantom types; rate basis is a value
- **Category:** api
- **Key decision:** Dimensional errors (money + ratio) are caught at compile time via phantom
  units. Period basis (annual vs monthly) is a runtime-validated property, not a second type
  parameter — nested phantom generics degrade diagnostics and type-check time past the point
  where they help.

## 12. Adversarial Review

**Strongest case for a different approach.**

A reviewer would push back: *you just argued for deleting a typed authoring layer because nobody
used it, and your response is to build another typed authoring layer.* The consumer count for
`Account`/`Expr` is currently zero, exactly as it was for `BusinessMathDSL`. The honest minimal
move is to delete the DSL, add `MIN`/`MAX` to the grammar, point the Excel importer at the string
API, and **write no typed layer at all** until a caller asks for one.

That argument is strong and the counter is narrow: the difference is disposability. The DSL was a
parallel module with its own types, its own evaluation, and its own bugs — 3,300 lines that had
to be maintained in step with core. This is ~300 lines that generate strings and can be deleted
in one commit with nothing downstream noticing. The cost of being wrong is two orders of
magnitude smaller. But a reviewer is entitled to say that is a reason it is *cheap*, not a reason
it is *needed*.

**Where this design is most likely wrong.**

The load-bearing assumption is that **Swift's type checker handles this overload set gracefully.**
Sixteen-plus operators over four phantom types, composed into nested arithmetic, is a recognised
recipe for exponential inference. If a five-term expression takes seconds to type-check or fails
with "expression too complex," the units become a tax rather than a guarantee — and unlike a
runtime check, there is no way to opt out locally. §7's mitigations are informed guesses, not
measurements, which is why §10 makes a compile-time budget a first-class test rather than an
afterthought.

Second: the four-unit taxonomy may be wrong. Is a share count `Duration` or its own unit? Is an
FX rate a `Ratio` or a `Rate`? Is a per-share amount `Money / Duration`? Every one of those is a
judgement, and getting one wrong means either a false compile error (worse than no checking,
because it forces a cast that disables checking entirely) or a missed error. Four units is a
guess at the right granularity, defended only by its being the smallest set that catches the
errors `orcaset`'s `pitfalls.md` names as most common.

A constraint accepted with little challenge: that the waterfall should move to core rather than
be deleted alongside everything else. It also has zero consumers. It is kept because it is the
only DSL component with no core equivalent — but "unique" and "wanted" are different claims.

**What an experienced critic would say.**

*"You are replacing an unused abstraction with a smaller unused abstraction, and betting that
Swift's overload resolution will stay tractable across an operator matrix you have not yet
measured."*

**Why we are proceeding anyway — with two changes.** The units are the part that earns its
keep independent of consumer count: they encode domain rules (a margin is not money; an annual
rate is not a monthly one) that are otherwise enforced nowhere in this codebase and that the
Excel importer will need in order to classify recognized cells at all. **Change one:** the
compile-time budget test is a gate on Phase 3, not a later nicety — if it fails, we ship the
grammar work and the deletion and stop. **Change two:** §13 Alternative 3 (runtime unit
validation in `validateUnits()`) is documented as a pre-approved fallback, so failing the budget
means degrading to a weaker check, not abandoning units.

## 13. Alternatives Considered

**Alternative 1: Delete the DSL, extend the grammar, write no typed layer.**
- *Advantage:* Smallest possible change. No overload-resolution risk at all. The Excel importer
  works fine against the string API — Excel is stringly typed too.
- *Disadvantage:* Leaves hand-authoring with no safety net, and leaves the unit rules
  (margin ≠ money, annual ≠ monthly) unencoded anywhere.
- *Why not chosen:* It is the right answer if Phase 3's compile-time budget fails, and it is
  explicitly the fallback. Phases 1–2 are shaped so this remains reachable.

**Alternative 2: Keep `BusinessMathDSL` and fix it (the superseded `DSLExpressiveness.md` plan).**
- *Advantage:* Preserves result-builder ergonomics that read well for simple models.
- *Disadvantage:* Five new types, a breaking `freeCashFlow` change, and reimplementation of
  cycle solving and per-period values that already ship in core — all in a module with no
  consumers.
- *Why rejected:* See `DSLExpressiveness.md`'s superseded header.

**Alternative 3: Runtime unit checking instead of phantom types.**
- *Advantage:* No overload matrix, no type-check risk; units become data on `Account` and are
  validated in `validateUnits()`. Also usable from the MCP path, where types do not exist.
- *Disadvantage:* Errors surface at model-build time, not compile time — weaker, and the whole
  argument for a typed layer is compile-time.
- *Why not chosen now:* **Pre-approved fallback** if §10's compile-time budget fails. Note that
  `validateUnits()` exists in this proposal regardless, for the MCP and importer paths, so the
  fallback is a subtraction rather than a rewrite.

**Alternative 4: Have `FormulaEvaluator` implement financial functions itself.**
- *Advantage:* Self-contained evaluator with no coupling to `Time Series/TVM/`.
- *Disadvantage:* **Two implementations of NPV, IRR, and PMT in one codebase.** They would drift,
  and the drift would surface as a workbook that evaluates differently depending on whether the
  caller went through a formula string or a Swift call. That is exactly the "silent second
  evaluator" failure this work exists to eliminate.
- *Why rejected:* Delegation is strictly better and costs nothing — the canonical functions are
  already generic over `T: Real`, which is `FormulaEvaluator`'s own constraint. §4's dispatch
  table is the adopted design.

**Alternative 5: Register only a minimal function set and grow on demand.**
- *Advantage:* Smallest Phase 2.
- *Disadvantage:* Understates what is already available. BusinessMath core exposes **616 unique
  public functions**, with documented Excel equivalence spanning far more than TVM — `NORM.S.DIST`,
  `NORM.S.INV`, `STANDARDIZE`, `CUMIPMT`, `CUMPRINC`, `PMT`/`IPMT`/`PPMT`, and the statistical
  surface (`AVERAGE`, `CORREL`, `COVAR`, `STDEV`, `MEDIAN`, `BINOM.DIST`, `CHISQ.DIST`,
  `CONFIDENCE`). Registering a handful and deferring the rest leaves importer coverage on the
  table for no engineering saving — the implementations exist.
- *Why rejected:* **The registry is a name-mapping exercise, not an implementation effort.** The
  scarce resource is not code but *semantic verification per name* (below), so the sensible unit
  of work is "one name, one Excel-semantics test," and those parallelise.

## 14. Future Directions

- **Rebase `BusinessMathPro` onto core.** `CapitalStructureProjection` and `RevolverFacility`
  could be reimplemented over `ModelDefinition` + `Account`, leaving one debt engine.
- **More grammar functions**, demand-driven from importer residue: `IF` first, then lookups.
- **Unit inference in the Excel recognizer.** A cell formatted as a percentage is a `Ratio`; a
  row labelled "growth" is a `Rate`. Recognized units could populate `LineItem<U>` directly.
- **Additional units** — `Share`, `FX` — if the four-unit taxonomy proves too coarse (§12).
- **Convergence of the two waterfalls** — tiered distribution vs `CapTable` liquidation
  preferences (§15 Q4).
- **A result builder for model assembly**, if `.defining` chains prove unwieldy at scale.

## 15. Open Questions

1. ~~**Deprecate-then-remove across two releases, or remove outright?**~~
   **Resolved 2026-09-01: remove outright, in 3.0.0. No deprecation release.**

   The recommendation here was the two-release path, and it was overruled deliberately. The
   argument for insurance was that the product is public; the argument against paying for it is
   that the insurance covers nobody. A consumer search across every sibling package found the
   only importers of `BusinessMathDSL` to be four of its own test files. A deprecation cycle
   warns an empty room, and the cost is not just a release — it is carrying a module that
   duplicates core (`Scenario`, `ScenarioAnalysis`, the valuation types) and whose types are not
   `Sendable` while `StrictConcurrency` is enabled package-wide.

   **This does not change what version the removal lands in.** Removing a public product is
   breaking whether or not it was deprecated first, so it is 3.0.0 either way — §7 is explicit
   about that. Removing outright skips the intermediate *release*, not the major bump.

   Phase 5 (the deprecation pass) is therefore **dropped**, and Phase 6 becomes the whole of the
   removal. `Tier`/`TierComponents`/`LiquidationWaterfall` still migrate rather than die, per
   Phase 1, so the material worth keeping is in core before anything is deleted.
2. **Do `Money * Money` and other blocked combinations need an escape hatch** for a caller with a
   legitimate exotic case? An explicit `Expr<U>.reinterpret(as:)` would provide one at the cost
   of a hole. Recommend deferring until someone needs it.
3. ~~**Is `Duration` the right unit for share counts,** or does a `Share` unit pull its weight?~~
   **Resolved 2026-09-02 by Q8:** the unit is `Count`, which covers shares as naturally as
   periods. No separate `Share` unit is proposed.
4. **Should `CapTable.liquidationWaterfall` and the migrated `LiquidationWaterfall` converge?**
   They model different things today; the overlap may still confuse.
5. ~~**What is the compile-time budget number?**~~
   **Resolved 2026-09-02: measured, and the budget passes with a large margin.**

   A throwaway spike of the exact §4 surface — `Unit`, `LineItem<U>`, `Expr<U>`, all fourteen
   operator overloads, the three literal constructors and `min`/`max` — compiled against the §4
   worked example plus a stress file whose expressions nest up to twenty terms and mix all four
   units in both operand orders.

   | Threshold | Expressions exceeding it |
   |---|---|
   | 10 ms | **0** |
   | 20 ms | 0 |
   | 50 ms | 0 |
   | 100 ms | 0 |

   Whole-file compile, three runs: 0.59 s each. Nothing came close to a budget worth setting.

   The reason is the decision §4 made for readability. Because literals are **explicit by
   construction** — `ratio(1.0)`, never a bare `1.0` — the solver never has to infer a literal's
   type across an overload set, which is the case Swift is genuinely slow at. Every operand type
   is known before overload resolution starts, and the overloads are concrete on unit pairs
   rather than generic. The choice made so `revenue * ratio(0.4)` reads unambiguously is also
   what keeps it cheap.

   The negative cases fail as intended and, contrary to §12's concern, with legible errors that
   name the units:

   ```
   error: cannot convert value of type 'Expr<Ratio>' to expected argument type 'Expr<Money>'
   error: binary operator '*' cannot be applied to two 'Expr<Money>' operands
   error: binary operator '*' cannot be applied to operands of type 'Expr<Money>' and 'Double'
   ```

   **Alternative 3 (runtime unit checking) is therefore not needed**, and Phase 3 is unblocked.
6. **`Account` is already taken, and Phase 3 cannot land as written.** *(Found 2026-09-01 while
   scoping what core still owes the Excel work.)*

   `Financial Statements/Account.swift:395` declares
   `public struct Account<T: Real & Sendable>` — generic over the **numeric** type, and used
   throughout the financial-statement surface. §4 proposes
   `public struct Account<U: Unit>` in `Model Definition/Account.swift` — generic over a
   **unit**. Same module, same name, same arity, incompatible parameters. `Account<Double>` and
   `Account<Money>` cannot both exist, and the proposal even places them in two files with the
   same basename.

   This is a harder blocker than Q5. The compile-time budget might come back acceptable; a name
   collision comes back the same way every time. Options, none yet chosen:

   - **Rename the typed handle** — `Line<U>`, `Item<U>`, `Quantity<U>`. Cheapest, and arguably
     more accurate: the typed thing is a line in a model, not an account in a statement.
   - **Rename the existing type.** It is public and used across the statement surface, so this
     is a breaking change that would have to wait for 3.0.0 — which would put Phase 3 behind the
     major it was deliberately placed ahead of.
   - **Separate module.** Restores the two-module split this proposal exists to remove.

   **Resolved 2026-09-01: the typed handle is `LineItem<U>`.** The existing `Account<T>` keeps
   its name and its meaning. `LineItem` is the term the domain already uses for exactly this
   thing — a named quantity in a model — and it cannot be misread as a row index the way `Line`
   can. The vocabulary does split slightly, since `ModelDefinition` speaks of accounts and the
   typed layer will speak of line items, but that is a smaller cost than either renaming a
   public type used across the statement surface or carrying two `Account`s distinguished only
   by qualification.

7. **The growth-factor idiom is inexpressible, and it is the commonest formula in modelling.**
   *(Found 2026-09-02 by the Q5 spike, which is what a spike is for.)*

   `Revenue_t = Revenue_{t-1} × (1 + g)`. Written against §4's algebra that is
   `revenue.expr * (ratio(1) + growth.expr)`, and it does not compile: `ratio(1)` is an
   `Expr<Ratio>`, `growth.expr` is an `Expr<Rate>`, and no overload adds them. The error is
   correct — a margin and a per-period rate are not the same dimension — and the consequence is
   that the single most common line in any financial model cannot be written.

   Three ways out:

   - **An overload `Expr<Ratio> + Expr<Rate> -> Expr<Ratio>`.** Cheapest, and wrong: it also
     admits `margin + growth`, which means nothing, so it buys the idiom by giving up the
     property the units exist for.
   - **Make growth a `Ratio`.** Then it adds freely and loses its period basis, which is exactly
     what Phase 4's `rateBasisMismatch` needs in order to catch an annual rate applied monthly.
   - **A named constructor**, `factor(_ r: Expr<Rate>) -> Expr<Ratio>`, meaning *one plus this
     rate*: `revenue.expr * factor(growth.expr)`.

   **Recommend the third.** It is the same decision §4 already made about literals — explicit by
   construction, because the alternative infers a unit from context and reintroduces the
   ambiguity the units exist to prevent. `factor(growth)` also says what the quantity *is*, which
   `1 + g` never did; a growth factor is a distinct thing from the rate it is built from, and
   naming it is a gain rather than a tax.

   A compounding form, `factor(_ r: Expr<Rate>, over n: Expr<Count>)` for `(1 + r)ⁿ`, is the
   obvious sibling and is **not** proposed here: no measured workbook has needed it yet, and §14
   is where speculative surface belongs.

8. **`Duration` is taken too, by the standard library.**
   *(Found 2026-09-02 by compiling Phase 3 Task 1, which is the only way this kind of thing is
   ever found.)*

   §4 proposed `public enum Duration: Unit`. `BusinessMath` uses `Duration` unqualified in eight
   files — `AsyncOptimization`, `ElapsedTimeSource`, `PerformanceBenchmark`, `SimulationResults`,
   the branch-and-bound solvers — and `Determinism/ElapsedTime.swift` *extends* it. Declaring
   another `Duration` in the module shadows the standard library's for every one of them, and the
   build fails in six files that have nothing to do with units.

   Fixing the call sites would be the wrong repair: it leaves a name that means one thing in this
   module and another everywhere else, so the next file written here inherits the trap.

   **Resolved 2026-09-02: the unit is `Count`.** It is also the more accurate word. §4 defined it
   as *a count of periods, units, or shares*, and `Count` covers a share count as naturally as a
   period count — which answers Q3 as well: no separate `Share` unit is needed, because counting
   shares is what this unit does.

   This is the second name collision in Phase 3's surface, after `Account` in Q6. Both were found
   by trying to build rather than by review, which is worth recording: a design document cannot
   see a namespace.

9. **`Unit` is taken as well, by Foundation — and this one is invisible from inside the module.**
   *(Found 2026-09-02 by the first test that imported the module from outside.)*

   `Foundation.Unit` is the base class of the `Measurement` API, and essentially every consumer
   imports Foundation. Within `BusinessMath` a local `Unit` shadows it and everything compiles;
   from outside — the test module, and every downstream package — `Unit` is ambiguous at every
   use site.

   That is the worst shape a naming problem can take, because the module that owns the name never
   sees the damage. `Account` and `Duration` both broke this package's own build immediately.
   This one built clean and would have shipped, breaking `BusinessMathExcel` on the first
   `import`.

   **Resolved 2026-09-02: the protocol is `ModelUnit`.** The four concrete units — `Money`,
   `Rate`, `Ratio`, `Count` — are unambiguous and keep their names.

   Three collisions in one small surface is a pattern rather than bad luck. All three were found
   by compiling, none by review, and the third needed compiling *from another module*.

## 16. Documentation Strategy

**Documentation Type:** Narrative Article Required

**Complexity Threshold Check:**
- Combines 3+ APIs? **Yes** — `Account`, `Expr`, `ModelDefinition`, `FormulaEvaluator`,
  `CycleSolver`, `TimeSeries`.
- Requires 50+ lines? **Yes** — the unit algebra table alone.
- Needs theory/background? **Yes** — why units are phantom but basis is a value, and when a cycle
  should be broken by timing versus resolved by iteration.

**Article Name:** `1.7-TypedModelAuthoringGuide.md` (follows the existing numbered DocC
convention). Does not collide with any Swift symbol name.

Also required: a **migration guide** from `BusinessMathDSL` to `ModelDefinition` + `Account`, a
CHANGELOG entry for the deprecation and the removed product, and an update to
`1.4-FluentAPIGuide.md`, which references DSL types.

---

## Proposed Phasing

| Phase | Scope | Gate |
|---|---|---|
| **1** | Migrate `Tier`/`TierComponents`/`LiquidationWaterfall` to `Financial Statements/Waterfall/`; add `Sendable`, throwing inits | `WaterfallBuilderTests` green at the new location |
| **2a** | `FormulaEvaluator` call machinery: comma token, `Node.function`, arity checking, dispatch table; arithmetic primitives `MIN`/`MAX`/`ABS`/`SUM`; **comparison operators (`> < >= <= = <>`) and `IF`**, with the `Condition` unit | Sweep expressible as a string formula; `IF` selects period-wise and matches Excel's `TRUE`=1 coercion; `Expr<Money> + Expr<Condition>` does not compile |
| **2b** | Register the **logical and aggregation** tranche — `AVERAGE`, `ROUND`, `AND`, `OR`, `NOT`. Moved ahead of TVM on the function census: these appear in real workbooks and TVM does not | One Excel-semantics fixture per name; `ROUND` pinned at half-away-from-zero |
| **2c** | Register the TVM tranche (`NPV`→`npvExcel`, `IRR`, `XIRR`, `XNPV`, `PMT`, `IPMT`, `PPMT`, `PV`, `FV`, `CUMIPMT`, `CUMPRINC`) — one Excel-semantics fixture per name | Delegation-equivalence tests green; `NPV`≠`npv()` test pins the binding |
| **2d** | Register the statistical tranche seeded from `FormulaMapper.statisticalFunctions` | One Excel fixture per name; `STDEV`/`STDEVP` and `VAR`/`VARP` denominators pinned |
| **2e** | `Rollforward` + `PeriodDriver` (Part 2.5) | Debt rollforward across 7 periods matches an Excel fixture; within-period cycle still resolves via `CycleSolver`; cross-period cycle diagnosed as `rollforwardCycle` |
| **3** | `ModelUnit`, `LineItem<U>`, `Expr<U>`, operator algebra, `defining` overloads | Negative compile tests fail to compile; **compile-time budget met** (§15 Q5) — if not, fall back to Alternative 3 |
| **4** | `validateUnits()` + rate-basis checking | `rateBasisMismatch` thrown for annual-rate-on-monthly-period |
| ~~**5**~~ | ~~Deprecate every remaining `BusinessMathDSL` public type~~ **Dropped 2026-09-01** — removal is outright, so there is no deprecation release; see §15 Q1 | — |
| **6** | Delete `Sources/BusinessMathDSL/` + the three obsolete `Result Builder Tests` files; remove product and target from `Package.swift` | Package builds clean; no reference to `BusinessMathDSL` remains |
| **7** | `1.7-TypedModelAuthoringGuide.md`, migration guide, `1.4-FluentAPIGuide.md` reconciliation, master plan | Quality gate 0/0 |

Phases 1–2 are pure additions and unblock the Excel importer's Wharton work regardless of what
happens to Phase 3. Phase 3 is the one with genuine technical risk, and it is deliberately
placed after the work that does not depend on it.

### Release mapping, decided 2026-09-01

| Release | Phases | Why |
|---|---|---|
| **2.8.0** | 1, 2a, 2b, 2c, 2d, 2e | Purely additive. This is the gate `BusinessMathExcel` Phase 3 waits on, so it ships on its own rather than behind Phase 3's compile-time risk |
| **2.9.0** | 3, 4 | Additive. Phase 3's compile-time gate was measured 2026-09-02 and passes with a large margin — see §15 Q5, now resolved. Phase 4 rides with it because `validateUnits()` is already in Phase 3's binding surface and a unit layer that cannot check a rate basis is half a feature |
| **3.0.0** | 6, 7 | Removing a public product is breaking regardless of deprecation. Phase 5 is dropped |

Phase 1 migrates `Tier`/`TierComponents`/`LiquidationWaterfall` into core **before** 3.0.0
deletes their old home, leaving a `renamed:` pointer at the old location for anyone on 2.8.x.

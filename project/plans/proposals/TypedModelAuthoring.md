# Design Proposal: typed, unit-checked authoring over `ModelDefinition` — and the removal of `BusinessMathDSL`

**Date:** 2026-09-01
**Status:** Proposed
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
| `Model Definition/Account.swift` | `Account<U: Unit>` — typed handle |
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
/// A dimensional marker for an account or expression.
public protocol Unit: Sendable {
    static var symbol: String { get }
}

/// A currency amount: revenue, cost, a balance, a cash flow.
public enum Money: Unit { public static var symbol: String { "money" } }

/// A per-period rate: growth, interest, decay. Carries a period basis (see below).
public enum Rate: Unit { public static var symbol: String { "rate" } }

/// A dimensionless ratio: a margin, a multiple, a percentage.
public enum Ratio: Unit { public static var symbol: String { "ratio" } }

/// A count of periods, units, or shares.
public enum Duration: Unit { public static var symbol: String { "duration" } }
```

### Part 1 — accounts and expressions

```swift
/// A typed handle to a named account. Its existence as a Swift value is the guarantee:
/// a misspelled reference does not compile, and rename/find-usages work.
public struct Account<U: Unit>: Sendable, Hashable {
    public let name: String
    /// For `Rate` accounts, the period the rate is expressed per. Validated at model
    /// build time — see §12 for why this is a value and not a second type parameter.
    public let basis: PeriodType?

    public init(_ name: String, basis: PeriodType? = nil)
}

/// An expression over accounts, carrying its unit.
public struct Expr<U: Unit>: Sendable {
    /// The rendered formula in `FormulaEvaluator` grammar.
    public var formula: String { get }

    public static func account(_ a: Account<U>) -> Expr<U>
    public static func constant(_ value: Double) -> Expr<U>
}

extension Account { public var expr: Expr<U> { .account(self) } }
```

### Part 1 — the unit algebra

This is the substance. Legal combinations get an overload; illegal ones simply have none, so
they fail to compile.

```swift
// Same-unit addition and subtraction.
public func + <U: Unit>(lhs: Expr<U>, rhs: Expr<U>) -> Expr<U>
public func - <U: Unit>(lhs: Expr<U>, rhs: Expr<U>) -> Expr<U>
public prefix func - <U: Unit>(operand: Expr<U>) -> Expr<U>

// Scaling money by a dimensionless quantity.
public func * (lhs: Expr<Money>, rhs: Expr<Ratio>) -> Expr<Money>
public func * (lhs: Expr<Ratio>, rhs: Expr<Money>) -> Expr<Money>
public func * (lhs: Expr<Money>, rhs: Expr<Rate>)  -> Expr<Money>
public func * (lhs: Expr<Rate>,  rhs: Expr<Money>) -> Expr<Money>

// Dimensionless composition.
public func * (lhs: Expr<Ratio>, rhs: Expr<Ratio>) -> Expr<Ratio>

// Division derives dimension.
public func / (lhs: Expr<Money>, rhs: Expr<Money>)    -> Expr<Ratio>     // margin
public func / (lhs: Expr<Money>, rhs: Expr<Duration>) -> Expr<Money>     // per period
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
```

Bare float literals would infer their unit from context, which reintroduces exactly the
ambiguity the units exist to prevent — and produces the overload-resolution errors Swift is
worst at reporting. `revenue * ratio(0.4)` is three characters longer and unambiguous.

### Part 1 — binding to `ModelDefinition`

```swift
extension ModelDefinition {
    /// Typed overload. Delegates to the existing string API; nothing below is modified.
    public func defining<U: Unit>(_ account: Account<U>, as expr: Expr<U>) -> ModelDefinition<T>

    /// Reads a typed result out of an evaluation.
    public func series<U: Unit>(for account: Account<U>,
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

**Seeding the registry.** `BusinessMathExcel`'s `FormulaMapper` already carries curated Excel
name lists — `financialFunctions` (`PMT`, `IPMT`, `PPMT`, `FV`, `PV`, `NPV`, `IRR`, `XIRR`,
`XNPV`, `RATE`, `NPER`, `SLN`, `DB`, `DDB`) and `statisticalFunctions` (`AVERAGE`, `STDEV`,
`STDEVP`, `VAR`, `VARP`, `PERCENTILE`, `MEDIAN`, `MODE`, `COUNT`, `COUNTA`, `COUNTIF`, `MIN`,
`MAX`, `SUM`). Those lists were built by classifying real workbook formulas and are the natural
first tranche — they represent names already observed in the wild rather than a guess at what
matters.

Typed surface:

```swift
public func min<U: Unit>(_ a: Expr<U>, _ b: Expr<U>) -> Expr<U>
public func max<U: Unit>(_ a: Expr<U>, _ b: Expr<U>) -> Expr<U>
```

Note the unit discipline carries: `min` of two `Money` is `Money`; `min(money, ratio)` has no
overload.

### Worked example — a cash sweep, which is currently inexpressible

```swift
let fcf            = Account<Money>("Free Cash Flow")
let openingDebt    = Account<Money>("Opening Debt")
let interestRate   = Account<Rate>("Interest Rate", basis: .annual)
let interest       = Account<Money>("Interest")
let sweep          = Account<Money>("Sweep Paydown")
let closingDebt    = Account<Money>("Closing Debt")

let model = ModelDefinition<Double>(periods: periods)
    .defining(interest,    as: openingDebt.expr * interestRate.expr)
    .defining(sweep,       as: min(fcf.expr, openingDebt.expr))
    .defining(closingDebt, as: openingDebt.expr - sweep.expr)

try model.validateUnits()
let results = try model.evaluate()      // cycle resolution unchanged, via CycleSolver
```

`fcf.expr + interestRate.expr` would not compile. Neither would `min(fcf.expr, ratio(0.4))`.

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

> **Rendering.** `Account<Money>("Sales & Marketing").expr - Account<Money>("A/P").expr`
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
> **Negative unit test.** `Account<Money>("Cash").expr + Account<Ratio>("Margin").expr` must
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
  row labelled "growth" is a `Rate`. Recognized units could populate `Account<U>` directly.
- **Additional units** — `Share`, `FX` — if the four-unit taxonomy proves too coarse (§12).
- **Convergence of the two waterfalls** — tiered distribution vs `CapTable` liquidation
  preferences (§15 Q4).
- **A result builder for model assembly**, if `.defining` chains prove unwieldy at scale.

## 15. Open Questions

1. **Deprecate-then-remove across two releases, or remove outright?** With zero consumers,
   outright removal in the next major is defensible and is the stated preference. The
   conservative path costs one release cycle. **Recommend: deprecate in the next minor, remove in
   the next major** — the product is public, and the cycle is cheap insurance.
2. **Do `Money * Money` and other blocked combinations need an escape hatch** for a caller with a
   legitimate exotic case? An explicit `Expr<U>.reinterpret(as:)` would provide one at the cost
   of a hole. Recommend deferring until someone needs it.
3. **Is `Duration` the right unit for share counts,** or does a `Share` unit pull its weight?
4. **Should `CapTable.liquidationWaterfall` and the migrated `LiquidationWaterfall` converge?**
   They model different things today; the overlap may still confuse.
5. **What is the compile-time budget number?** Needs measuring on the §4 example before Phase 3
   can be gated on it.

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
| **2a** | `FormulaEvaluator` call machinery: comma token, `Node.function`, arity checking, dispatch table; arithmetic primitives `MIN`/`MAX`/`ABS`/`SUM` | Sweep expressible as a string formula |
| **2b** | Register the TVM tranche (`NPV`→`npvExcel`, `IRR`, `XIRR`, `XNPV`, `PMT`, `IPMT`, `PPMT`, `PV`, `FV`, `CUMIPMT`, `CUMPRINC`) — one Excel-semantics fixture per name | Delegation-equivalence tests green; `NPV`≠`npv()` test pins the binding |
| **2c** | Register the statistical tranche seeded from `FormulaMapper.statisticalFunctions` | One Excel fixture per name; `STDEV`/`STDEVP` and `VAR`/`VARP` denominators pinned |
| **3** | `Unit`, `Account<U>`, `Expr<U>`, operator algebra, `defining` overloads | Negative compile tests fail to compile; **compile-time budget met** (§15 Q5) — if not, fall back to Alternative 3 |
| **4** | `validateUnits()` + rate-basis checking | `rateBasisMismatch` thrown for annual-rate-on-monthly-period |
| **5** | Deprecate every remaining `BusinessMathDSL` public type with `renamed:`/`message:` | Package builds with warnings only; CHANGELOG entry |
| **6** | Delete `Sources/BusinessMathDSL/` + the three obsolete `Result Builder Tests` files; remove product and target from `Package.swift` | Package builds clean; no reference to `BusinessMathDSL` remains |
| **7** | `1.7-TypedModelAuthoringGuide.md`, migration guide, `1.4-FluentAPIGuide.md` reconciliation, master plan | Quality gate 0/0 |

Phases 1–2 are pure additions and unblock the Excel importer's Wharton work regardless of what
happens to Phase 3. Phase 3 is the one with genuine technical risk, and it is deliberately
placed after the work that does not depend on it.

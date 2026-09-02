# BusinessMath Capability Map

**Purpose:** Scannable inventory of what this project can do — feature areas, key types, external interfaces, and application domains.

**Last reviewed:** 2026-09-01 (created for v2.8.0)

> **Format reference:** See `development-guidelines/rules/capability_map.md` for field definitions,
> naming conventions, and maintenance rules.

---

## Models as Configuration

**Key types:** `ModelDefinition`, `AccountDefinition`, `FormulaEvaluator`, `FormulaError`, `PeriodDriver`, `Rollforward`, `PeriodDriverError`
**Interfaces:** `defining(_:as:)`, `evaluate()`, `solve(settings:)`, `requiredInputs()`, `evaluationOrder()`, `PeriodDriver.run(over:settings:)`
**Applications:** Expressing a financial model as named accounts and formula strings rather than code, so it can be read from a file or recovered from a spreadsheet and changed without recompiling

Formulas are period-local by design. Seventeen registered functions bind to canonical
implementations rather than reimplementations, and where Excel's definition differs from the
textbook's the grammar means Excel's. An unregistered name throws rather than evaluating to zero.

## Circularity

**Key types:** `DependencyReport`, `DependencyCycle`, `CycleForm`, `CycleSolverError`, `IterationSettings`
**Interfaces:** `dependencyReport()`, `solve(settings:)`
**Applications:** Resolving models where a value depends on itself — interest on an average balance, a fee on a total that includes the fee — either exactly where the cycle is linear or by iteration where it is not

A cycle *within* a period is solved here; a carry *across* periods belongs to `PeriodDriver`.
The split is deliberate and neither mechanism sees the other.

## Time Series

**Key types:** `TimeSeries`, `Period`, `PeriodType`, `PeriodSequence`, `FiscalCalendar`
**Interfaces:** `zip(with:_:)`, `mapValues(_:)`, arithmetic operators, period conversion, gap filling
**Applications:** Anything indexed by time — actuals, forecasts, schedules — with periods that intersect rather than being silently filled when two series disagree about their span

## Time Value of Money

**Key types:** `AnnuityType`
**Interfaces:** `npv`, `npvExcel`, `irr`, `xirr`, `xnpv`, `payment`, `principalPayment`, `interestPayment`, `futureValue`, `presentValue`
**Applications:** Discounting, loan amortisation, return measurement

`npv` and `npvExcel` differ by a period of compounding, and both are provided because both are
correct for different questions.

## Statistics

**Key types:** `Population`, the distribution family, `Experiment`
**Interfaces:** `mean`, `median`, `stdDev`, `stdDevS`, `stdDevP`, `variance`, `covariance`, `correlationCoefficient`, `skew`, `kurtosis`, hypothesis tests
**Applications:** Descriptive summary, inference, experiment sizing and analysis

Sample versus population is an explicit argument rather than an assumed default, because the
denominators produce answers that both look reasonable.

## Financial Statements

**Key types:** `Account`, `Entity`, `BalanceSheet`, `CashFlowStatement`, `ConsolidatedStatements`, `DebtInstrument`, `DebtCovenants`, `CreditMetrics`, `CapitalStructure`
**Interfaces:** Statement construction, ratio and covenant evaluation
**Applications:** Building and checking the statements a model produces, and the covenants a lender tests them against

## Waterfall Distribution

**Key types:** `LiquidationWaterfall`, `Tier`, `TierTerms`, `CapitalReturn`, `PreferredReturn`, `CatchUp`, `Residual`, `ProRata`, `WaterfallResult`, `WaterfallContext`, `WaterfallError`
**Interfaces:** `LiquidationWaterfall.distribute(_:)`, the `@LiquidationWaterfallBuilder` DSL
**Applications:** Allocating exit proceeds through priority tiers — capital return, preferred hurdle, GP catch-up, pro-rata split

Validation throws rather than trapping: the amounts reaching a waterfall are frequently not the
programmer's.

## Valuation

**Key types:** Equity and debt valuation models, option pricing
**Interfaces:** Gordon growth, two-stage DDM, H-model, residual income, FCFE, bond pricing, Black-Scholes, binomial trees
**Applications:** Pricing securities and businesses

## Optimization

**Key types:** Linear and integer programming, gradient and derivative-free optimizers, metaheuristics
**Interfaces:** `solveLinearProgram`, `solveIntegerProgram`, portfolio optimization, robust and stochastic variants
**Applications:** Allocation under constraints, portfolio construction, capital budgeting

## Simulation and Risk

**Key types:** `Distribution` family, Monte Carlo drivers, `ScenarioAnalysis`, `SensitivityAnalysis`, `TwoWayScenarioSensitivityAnalysis`
**Interfaces:** `runMonteCarlo`, `runScenarioAnalysis`, `runTwoWaySensitivity`, tornado analysis, VaR
**Applications:** Quantifying uncertainty, stress testing, sensitivity grids
**Dependencies:** SwiftDeterminism for reproducible sampling

## Streaming and Forecasting

**Key types:** `TrendModel`, `Seasonality`, `GrowthRate`, streaming statistics and forecasting
**Interfaces:** Trend fitting, Holt-Winters, seasonal decomposition, online statistics
**Applications:** Projecting series forward, and computing over data too large to hold at once

# BusinessMath

A comprehensive Swift library for business mathematics, financial modeling, and quantitative analysis.

## Overview

BusinessMath is your complete toolkit for financial calculations and business analytics in Swift. Whether you're building revenue forecasts, valuing companies, optimizing portfolios, or modeling uncertainty, BusinessMath provides production-ready implementations of industry-standard methodologies.

Think of this documentation as a book with five parts that take you from foundational concepts through advanced optimization techniques. You can read it cover-to-cover following our <doc:LearningPath>, or jump directly to topics you need.

#### Built for Professionals

- **Financial Analysts**: Build DCF models, value securities, and analyze investments
- **Risk Managers**: Quantify risk with VaR, run Monte Carlo simulations, and stress test portfolios
- **Corporate Finance**: Create integrated financial models and evaluate capital allocation
- **Quantitative Developers**: Implement optimization algorithms and build analytics infrastructure
- **FP&A Teams**: Forecast revenue, model scenarios, and support strategic planning

#### Key Capabilities

**Time Series Analysis**: Comprehensive temporal data structures from milliseconds to years, with calendar-aware operations, aggregations, and transformations

**Financial Modeling**: Revenue forecasting, growth modeling, financial statements, and complete three-statement integration

**Valuation**: Equity (DCF, DDM, residual income), fixed income (bonds, duration, credit spreads), credit derivatives (CDS pricing)

**Risk & Simulation**: Monte Carlo simulation, scenario analysis, VaR/CVaR, stress testing, and uncertainty quantification

**Optimization**: Portfolio optimization (efficient frontier, Sharpe ratio), constrained optimization, integer programming, and resource allocation

#### Design Excellence

- **Type Safety**: Generic programming with `TimeSeries<T: Real>` for compile-time guarantees
- **Precision**: Actual calendar calculations (365.25 days/year) for financial accuracy
- **Concurrency**: Full Swift 6 compliance with strict concurrency checking
- **Production Ready**: 2,000+ tests, industry-standard formulas (ISDA, Black-Scholes)
- **Well Documented**: Every concept explained with formulas, examples, and real-world context

### Getting Started

New to BusinessMath? Start with <doc:LearningPath> for guided learning tracks, <doc:1.1-GettingStarted> for a quick introduction, or <doc:Part1-Basics> for foundation concepts.

Already familiar with financial modeling? Jump to <doc:Part3-Modeling> for revenue models and valuation, <doc:Part4-Simulation> for Monte Carlo and scenario analysis, or <doc:Part5-Optimization> for portfolio and mathematical optimization.

### Documentation Structure

This documentation is organized like a book with five main parts:

**Part I: Basics & Foundations** — Master the core concepts—time series, time value of money, and API patterns. See <doc:Part1-Basics>.

**Part II: Analysis & Statistics** — Learn analytical techniques—sensitivity analysis, financial ratios, risk metrics, and visualization. See <doc:Part2-Analysis>.

**Part III: Modeling** — Build financial models—from revenue forecasts to complex valuations. See <doc:Part3-Modeling>.

**Part IV: Simulation & Uncertainty** — Model risk and uncertainty with Monte Carlo methods and scenario analysis. See <doc:Part4-Simulation>.

**Part V: Optimization** — Find optimal solutions using mathematical optimization and operations research. See <doc:Part5-Optimization>.

## Topics

### Getting Started

- <doc:LearningPath>
- <doc:1.1-GettingStarted>
- <doc:Part1-Basics>

### Core Data Structures

- <doc:1.2-TimeSeries>
- <doc:1.3-TimeValueOfMoney>

### API Patterns & Developer Tools

- <doc:1.4-FluentAPIGuide>
- <doc:1.5-TemplateGuide>

### Troubleshooting

- <doc:1.6-DebuggingGuide>
- <doc:1.7-ErrorHandlingGuide>

### Analytical Methods

- <doc:2.1-DataTableAnalysis>
- <doc:MultipleLinearRegressionGuide>
- <doc:Part2-Analysis>

### Financial Metrics & Visualization

- <doc:2.2-FinancialRatiosGuide>
- <doc:2.4-VisualizationGuide>

### Risk Measurement & Validation

- <doc:2.3-RiskAnalyticsGuide>
- <doc:2.5-ModelValidationGuide>

### Growth & Forecasting

- <doc:3.1-GrowthModeling>
- <doc:3.2-ForecastingGuide>
- <doc:Part3-Modeling>

### Financial Modeling & Reporting

- <doc:3.3-BuildingRevenueModel>
- <doc:3.4-BuildingFinancialReports>
- <doc:3.5-FinancialStatementsGuide>
- <doc:3.6-LeaseAccountingGuide>
- <doc:3.7-LoanAmortization>
- <doc:3.15-DataIngestionGuide>
- <doc:3.16-FinancialStatementsReference>

### Valuation & Investment Analysis

- <doc:3.8-InvestmentAnalysis>
- <doc:3.9-EquityValuationGuide>
- <doc:3.10-BondValuationGuide>
- <doc:3.11-CreditDerivativesGuide>
- <doc:3.12-RealOptionsGuide>

### Capital Structure

- <doc:3.13-EquityFinancingGuide>
- <doc:3.14-DebtAndFinancingGuide>

### Probabilistic Methods & Scenario Analysis

- <doc:4.1-MonteCarloTimeSeriesGuide>
- <doc:4.2-ScenarioAnalysisGuide>
- <doc:4.3-MonteCarloExpressionModelsGuide>
- <doc:Part4-Simulation>

### Optimization Fundamentals

- <doc:5.1-OptimizationGuide>
- <doc:5.1.5-MultivariateOptimizerGuide>
- <doc:5.2-PortfolioOptimizationGuide>
- <doc:Part5-Optimization>

### Optimization Foundations

- <doc:5.3-CoreOptimization>
- <doc:5.4-VectorOperations>

### Core Optimization Algorithms

- <doc:5.5-MultivariateOptimization>
- <doc:5.6-ConstrainedOptimization>
- <doc:5.7-BusinessOptimization>

### Advanced Optimization Techniques

- <doc:5.8-IntegerProgramming>
- <doc:5.9-AdaptiveSelection>
- <doc:5.10-ParallelOptimization>
- <doc:5.11-PerformanceBenchmarking>

### Specialized Optimization Applications

- <doc:5.12-SparseMatrix>
- <doc:5.13-MultiPeriod>
- <doc:5.14-RobustOptimization>
- <doc:5.15-InequalityConstraints>

### Gradient-Based Methods

- <doc:5.20-LBFGSOptimizationTutorial>
- <doc:5.21-ConjugateGradientTutorial>

### Metaheuristic & Derivative-Free Methods

- <doc:5.22-SimulatedAnnealingTutorial>
- <doc:5.23-NelderMeadTutorial>

### Clustering & Case Studies

- <doc:5.24-K-MeansTutorial>
- <doc:Appendix-A-ReidsRaisinsExample>

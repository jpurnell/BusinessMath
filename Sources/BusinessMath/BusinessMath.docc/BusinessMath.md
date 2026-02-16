# BusinessMath

A comprehensive Swift library for business mathematics, financial modeling, and quantitative analysis.

## Overview

BusinessMath is your complete toolkit for financial calculations and business analytics in Swift. Whether you're building revenue forecasts, valuing companies, optimizing portfolios, or modeling uncertainty, BusinessMath provides production-ready implementations of industry-standard methodologies.

Think of this documentation as a book with five parts that take you from foundational concepts through advanced optimization techniques. You can read it cover-to-cover following our <doc:LearningPath>, or jump directly to topics you need.

### Built for Professionals

- **Financial Analysts**: Build DCF models, value securities, and analyze investments
- **Risk Managers**: Quantify risk with VaR, run Monte Carlo simulations, and stress test portfolios
- **Corporate Finance**: Create integrated financial models and evaluate capital allocation
- **Quantitative Developers**: Implement optimization algorithms and build analytics infrastructure
- **FP&A Teams**: Forecast revenue, model scenarios, and support strategic planning

### Key Capabilities

**Time Series Analysis**: Comprehensive temporal data structures from milliseconds to years, with calendar-aware operations, aggregations, and transformations

**Financial Modeling**: Revenue forecasting, growth modeling, financial statements, and complete three-statement integration

**Valuation**: Equity (DCF, DDM, residual income), fixed income (bonds, duration, credit spreads), credit derivatives (CDS pricing)

**Risk & Simulation**: Monte Carlo simulation, scenario analysis, VaR/CVaR, stress testing, and uncertainty quantification

**Optimization**: Portfolio optimization (efficient frontier, Sharpe ratio), constrained optimization, integer programming, and resource allocation

### Design Excellence

- **Type Safety**: Generic programming with `TimeSeries<T: Real>` for compile-time guarantees
- **Precision**: Actual calendar calculations (365.25 days/year) for financial accuracy
- **Concurrency**: Full Swift 6 compliance with strict concurrency checking
- **Production Ready**: 2,000+ tests, industry-standard formulas (ISDA, Black-Scholes)
- **Well Documented**: Every concept explained with formulas, examples, and real-world context

## Getting Started

New to BusinessMath? Start here:

- **<doc:LearningPath>** - Guided learning tracks for different roles (Financial Analyst, Risk Manager, Quant Developer, General Business)
- **<doc:1.1-GettingStarted>** - Quick introduction with your first calculations
- **<doc:Part1-Basics>** - Foundation concepts and essential tools

Already familiar with financial modeling? Jump to:
- **<doc:Part3-Modeling>** - Revenue models, valuation, and financial statements
- **<doc:Part4-Simulation>** - Monte Carlo and scenario analysis
- **<doc:Part5-Optimization>** - Portfolio optimization and mathematical optimization

## Documentation Structure

This documentation is organized like a book with five main parts:

### Part I: Basics & Foundations
Master the core concepts—time series, time value of money, and API patterns.
- **<doc:Part1-Basics>** - Introduction to Part I

### Part II: Analysis & Statistics
Learn analytical techniques—sensitivity analysis, financial ratios, risk metrics, and visualization.
- **<doc:Part2-Analysis>** - Introduction to Part II

### Part III: Modeling
Build financial models—from revenue forecasts to complex valuations.
- **<doc:Part3-Modeling>** - Introduction to Part III

### Part IV: Simulation & Uncertainty
Model risk and uncertainty with Monte Carlo methods and scenario analysis.
- **<doc:Part4-Simulation>** - Introduction to Part IV

### Part V: Optimization
Find optimal solutions using mathematical optimization and operations research.
- **<doc:Part5-Optimization>** - Introduction to Part V

## Topics

### Part I: Basics & Foundations

Overview of foundational concepts including time series, time value of money, and API patterns.

#### Getting Started

Quick introduction with common workflows.

- <doc:1.1-GettingStarted>

#### Core Data Structures

The foundation of temporal data in BusinessMath, plus time value of money calculations (present value, future value, NPV, IRR, annuities).

- <doc:1.2-TimeSeries>
- <doc:1.3-TimeValueOfMoney>

#### API Patterns & Developer Tools

SwiftUI-style declarative APIs for readable models and pre-built patterns for common scenarios.

- <doc:1.4-FluentAPIGuide>
- <doc:1.5-TemplateGuide>

#### Troubleshooting

Diagnosing and fixing issues, handling errors gracefully.

- <doc:1.6-DebuggingGuide>
- <doc:1.7-ErrorHandlingGuide>

#### Part Overview

- <doc:Part1-Basics>

### Part II: Analysis & Statistics

Overview of analytical techniques including sensitivity analysis, financial ratios, risk metrics, and visualization.

#### Analytical Methods

Excel-style sensitivity and scenario analysis, plus statistical regression modeling.

- <doc:2.1-DataTableAnalysis>
- <doc:MultipleLinearRegressionGuide>

#### Financial Metrics

Profitability, leverage, and efficiency ratios.

- <doc:2.2-FinancialRatiosGuide>

#### Risk Measurement

VaR, CVaR, stress testing, and risk aggregation.

- <doc:2.3-RiskAnalyticsGuide>

#### Communication

Charts, diagrams, and visual analytics.

- <doc:2.4-VisualizationGuide>

#### Model Validation

Fake-data simulation and parameter recovery checking.

- <doc:2.5-ModelValidationGuide>

#### Part Overview

- <doc:Part2-Analysis>

### Part III: Modeling

Overview of financial modeling from revenue forecasts to complex valuations.

#### General Modeling

CAGR and trend fitting (linear, exponential, logistic), plus complete forecasting workflows.

- <doc:3.1-GrowthModeling>
- <doc:3.2-ForecastingGuide>

#### Financial Modeling & Reporting

Step-by-step revenue model construction, financial statements (income statement, balance sheet, cash flow), integrated framework, lease accounting (IFRS 16 / ASC 842), loan schedules, and data ingestion from external sources.

- <doc:3.3-BuildingRevenueModel>
- <doc:3.4-BuildingFinancialReports>
- <doc:3.5-FinancialStatementsGuide>
- <doc:3.6-LeaseAccountingGuide>
- <doc:3.7-LoanAmortization>
- <doc:3.15-DataIngestionGuide>
- <doc:3.16-FinancialStatementsReference>

#### Valuation & Investment Analysis

NPV, IRR, payback, and profitability metrics. Equity valuation (DCF, DDM, FCFE, residual income). Bond pricing, duration, convexity, and credit spreads. CDS pricing (ISDA model) and Merton structural model. Real options valuation and flexibility analysis.

- <doc:3.8-InvestmentAnalysis>
- <doc:3.9-EquityValuationGuide>
- <doc:3.10-BondValuationGuide>
- <doc:3.11-CreditDerivativesGuide>
- <doc:3.12-RealOptionsGuide>

#### Capital Structure

Stock-based financing, equity dilution, debt analysis, and WACC calculations.

- <doc:3.13-EquityFinancingGuide>
- <doc:3.14-DebtAndFinancingGuide>

#### Part Overview

- <doc:Part3-Modeling>

### Part IV: Simulation & Uncertainty

Overview of simulation techniques for modeling risk and uncertainty.

#### Probabilistic Methods

Monte Carlo simulation for forecasting and risk analysis.

- <doc:4.1-MonteCarloTimeSeriesGuide>

#### Structured Scenarios

Scenario modeling and stress testing.

- <doc:4.2-ScenarioAnalysisGuide>

#### GPU-Accelerated Monte Carlo

High-performance simulation with expression models (10-100× speedup).

- <doc:4.3-MonteCarloExpressionModelsGuide>

#### Part Overview

- <doc:Part4-Simulation>

### Part V: Optimization

Overview of optimization methods from goal-seeking to business optimization.

#### Fundamentals

Complete guide from goal-seeking to business optimization. Modern Portfolio Theory and efficient frontier.

- <doc:5.1-OptimizationGuide>
- <doc:5.1.5-MultivariateOptimizerGuide>
- <doc:5.2-PortfolioOptimizationGuide>

#### Optimization Deep Dive: Progressive Tutorial Series

A comprehensive 12-phase tutorial taking you from basic goal-seeking to advanced optimization.

**Phases 1-2: Foundations** - Goal-seeking API, constraint builders, and vector mathematics for multivariate problems.

- <doc:5.3-CoreOptimization>
- <doc:5.4-VectorOperations>

**Phases 3-5: Core Algorithms** - Gradient descent, Newton-Raphson, equality and inequality constraints, resource allocation, and production planning.

- <doc:5.5-MultivariateOptimization>
- <doc:5.6-ConstrainedOptimization>
- <doc:5.7-BusinessOptimization>

**Phases 6-7: Advanced Techniques** - Branch-and-bound, cutting planes, automatic algorithm selection, parallel multi-start for global optimum, and performance testing.

- <doc:5.8-IntegerProgramming>
- <doc:5.9-AdaptiveSelection>
- <doc:5.10-ParallelOptimization>
- <doc:5.11-PerformanceBenchmarking>

**Phase 8: Specialized Applications** - Large-scale sparse matrix operations, stochastic multi-period optimization, and optimization under uncertainty.

- <doc:5.12-SparseMatrix>
- <doc:5.13-MultiPeriod>
- <doc:5.14-RobustOptimization>

#### Specialized Topics

Deep dive on inequality constraint handling.

- <doc:5.15-InequalityConstraints>

#### Modern Optimization Algorithms

Advanced optimizers for different problem types: gradient-based methods for smooth functions, metaheuristics for global optimization, and derivative-free methods.

**Gradient-Based Methods** - Fast convergence for smooth, differentiable functions with available gradients.

- <doc:5.20-LBFGSOptimizationTutorial>
- <doc:5.21-ConjugateGradientTutorial>

**Metaheuristic Methods** - Global optimization for multimodal, non-convex functions that can escape local minima.

- <doc:5.22-SimulatedAnnealingTutorial>

**Derivative-Free Methods** - Robust optimization without gradients for non-smooth or noisy objectives.

- <doc:5.23-NelderMeadTutorial>

**Clustering & Pattern Discovery** - Unsupervised learning for discovering structure and grouping similar data points.

- <doc:5.24-K-MeansTutorial>

#### Part Overview

- <doc:Part5-Optimization>

### Appendices

#### Case Studies

Comprehensive real-world example integrating multiple concepts.

- <doc:Appendix-A-ReidsRaisinsExample>

## Learning Paths

Choose a learning path tailored to your role:

- **<doc:LearningPath>** - Four specialized tracks:
  - **Financial Analyst Track**: Modeling, forecasting, and valuation (15-20 hours)
  - **Risk Manager Track**: Risk measurement, simulation, and stress testing (12-15 hours)
  - **Quantitative Developer Track**: Algorithms, optimization, and implementation (20-25 hours)
  - **General Business Track**: Practical FP&A and corporate finance (10-12 hours)

Each track provides a curated sequence of chapters with checkpoints to validate your progress.

## Quick Reference by Use Case

### I want to...

**Build a revenue forecast**: See <doc:3.1-GrowthModeling>, <doc:3.2-ForecastingGuide>, and <doc:3.3-BuildingRevenueModel>

**Value a company**: See <doc:3.9-EquityValuationGuide> and <doc:3.8-InvestmentAnalysis>

**Create financial statements**: See <doc:3.4-BuildingFinancialReports> and <doc:3.5-FinancialStatementsGuide>

**Measure portfolio risk**: See <doc:2.3-RiskAnalyticsGuide> and <doc:5.2-PortfolioOptimizationGuide>

**Run Monte Carlo simulation**: See <doc:4.1-MonteCarloTimeSeriesGuide>

**Optimize resource allocation**: See <doc:5.1-OptimizationGuide> and <doc:5.7-BusinessOptimization>

**Analyze sensitivity**: See <doc:2.1-DataTableAnalysis> and <doc:4.2-ScenarioAnalysisGuide>

**Build regression models**: See <doc:MultipleLinearRegressionGuide>

**Price bonds or calculate duration**: See <doc:3.10-BondValuationGuide>

**Model credit risk**: See <doc:3.11-CreditDerivativesGuide> and <doc:2.3-RiskAnalyticsGuide>

**Build efficient portfolios**: See <doc:5.2-PortfolioOptimizationGuide>

**Segment customers or discover patterns**: See <doc:5.24-K-MeansTutorial>

## What's New

### Latest Release Highlights

**Securities Valuation (v1.4.0)**:
 Equity valuation: DCF, DDM, FCFE, residual income models (<doc:3.9-EquityValuationGuide>)
 Fixed income: Bond pricing, duration, convexity, callable bonds (<doc:3.10-BondValuationGuide>)
 Credit derivatives: CDS pricing with ISDA Standard Model (<doc:3.11-CreditDerivativesGuide>)

**Advanced Optimization (v1.3.0)**:
 Portfolio optimization: Efficient frontier, Sharpe ratio maximization (<doc:5.2-PortfolioOptimizationGuide>)
 Integer programming: Branch-and-bound with cutting planes (<doc:5.8-IntegerProgramming>)
 Robust optimization: Uncertainty-aware optimization (<doc:5.14-RobustOptimization>)

**Risk Analytics (v1.2.0)**:
 Monte Carlo simulation for time series (<doc:4.1-MonteCarloTimeSeriesGuide>)
 VaR/CVaR calculation and stress testing (<doc:2.3-RiskAnalyticsGuide>)
 Scenario analysis framework (<doc:4.2-ScenarioAnalysisGuide>)

## System Requirements

 Swift 6.0 or later
 macOS 13.0+ / iOS 16.0+ / Linux with Swift 6.0+
 Xcode 16.0+ (for development)

## Installation

### Swift Package Manager

Add BusinessMath to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jpurnell/BusinessMath.git", from: "2.0.0")
]
```

## Support & Community

 **Documentation**: You're reading it! Start with <doc:1.1-GettingStarted>
 **GitHub**: [https://github.com/jpurnell/BusinessMath](https://github.com/jpurnell/BusinessMath)
 **Issues**: Report bugs or request features on GitHub
 **Discussions**: Share ideas and ask questions in GitHub Discussions

## License

BusinessMath is available under the MIT License. See the LICENSE file for details.

## Acknowledgments

Built with industry-standard methodologies including:
 ISDA Standard CDS Model for credit derivatives
 Black-Scholes framework for options pricing
 Modern Portfolio Theory (Markowitz)
 IFRS 16 / ASC 842 for lease accounting

---

**Ready to get started?** Begin with <doc:1.1-GettingStarted> or choose a <doc:LearningPath> for your role.

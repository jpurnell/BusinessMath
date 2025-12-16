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

**Time Series Analysis**: Comprehensive temporal data structures with calendar-aware operations, aggregations, and transformations

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

**<doc:Part1-Basics>** - Overview of foundational concepts

#### Getting Started
- <doc:1.1-GettingStarted> - Quick introduction with common workflows

#### Core Data Structures
- <doc:1.2-TimeSeries> - The foundation of temporal data in BusinessMath
- <doc:1.3-TimeValueOfMoney> - Present value, future value, NPV, IRR, annuities

#### API Patterns & Developer Tools
- <doc:1.4-FluentAPIGuide> - SwiftUI-style declarative APIs for readable models
- <doc:1.5-TemplateGuide> - Pre-built patterns for common scenarios

#### Troubleshooting
- <doc:1.6-DebuggingGuide> - Diagnosing and fixing issues
- <doc:1.7-ErrorHandlingGuide> - Handling errors gracefully

### Part II: Analysis & Statistics

**<doc:Part2-Analysis>** - Overview of analytical techniques

#### Analytical Methods
- <doc:2.1-DataTableAnalysis> - Excel-style sensitivity and scenario analysis

#### Financial Metrics
- <doc:2.2-FinancialRatiosGuide> - Profitability, leverage, efficiency ratios

#### Risk Measurement
- <doc:2.3-RiskAnalyticsGuide> - VaR, CVaR, stress testing, risk aggregation

#### Communication
- <doc:2.4-VisualizationGuide> - Charts, diagrams, and visual analytics

#### Model Validation
- <doc:2.5-ModelValidationGuide> - Fake-data simulation and parameter recovery checking

### Part III: Modeling

**<doc:Part3-Modeling>** - Overview of financial modeling

#### General Modeling
- <doc:3.1-GrowthModeling> - CAGR, trend fitting (linear, exponential, logistic)
- <doc:3.2-ForecastingGuide> - Complete forecasting workflows

#### Financial Modeling & Reporting
- <doc:3.3-BuildingRevenueModel> - Step-by-step revenue model construction
- <doc:3.4-BuildingFinancialReports> - Income statement, balance sheet, cash flow
- <doc:3.5-FinancialStatementsGuide> - Integrated financial statement framework
- <doc:3.6-LeaseAccountingGuide> - IFRS 16 / ASC 842 lease accounting
- <doc:3.7-LoanAmortization> - Loan schedules and analysis

#### Valuation & Investment Analysis
- <doc:3.8-InvestmentAnalysis> - NPV, IRR, payback, profitability metrics
- <doc:3.9-EquityValuationGuide> - DCF, DDM, FCFE, residual income
- <doc:3.10-BondValuationGuide> - Bond pricing, duration, convexity, credit spreads
- <doc:3.11-CreditDerivativesGuide> - CDS pricing (ISDA model), Merton structural model
- <doc:3.12-RealOptionsGuide> - Real options valuation and flexibility analysis

#### Capital Structure
- <doc:3.13-EquityFinancingGuide> - Stock-based financing and equity dilution
- <doc:3.14-DebtAndFinancingGuide> - Debt analysis, WACC calculations

### Part IV: Simulation & Uncertainty

**<doc:Part4-Simulation>** - Overview of simulation techniques

#### Probabilistic Methods
- <doc:4.1-MonteCarloTimeSeriesGuide> - Monte Carlo simulation for forecasting and risk

#### Structured Scenarios
- <doc:4.2-ScenarioAnalysisGuide> - Scenario modeling and stress testing

### Part V: Optimization

**<doc:Part5-Optimization>** - Overview of optimization methods

#### Fundamentals
- <doc:5.1-OptimizationGuide> - Complete guide from goal-seeking to business optimization
- <doc:5.2-PortfolioOptimizationGuide> - Modern Portfolio Theory, efficient frontier

#### Optimization Deep Dive: Progressive Tutorial Series
A comprehensive 12-phase tutorial taking you from basic goal-seeking to advanced optimization:

**Phases 1-2: Foundations**
- <doc:5.3-Phase1-CoreEnhancements> - Goal-seeking API and constraint builders
- <doc:5.4-Phase2-VectorOperations> - Vector mathematics for multivariate problems

**Phases 3-5: Core Algorithms**
- <doc:5.5-Phase3-MultivariateOptimization> - Gradient descent, Newton-Raphson
- <doc:5.6-Phase4-ConstrainedOptimization> - Equality and inequality constraints
- <doc:5.7-Phase5-BusinessOptimization> - Resource allocation, production planning

**Phases 6-7: Advanced Techniques**
- <doc:5.8-Phase6-IntegerProgramming> - Branch-and-bound, cutting planes
- <doc:5.9-Phase7-AdaptiveSelection> - Automatic algorithm selection
- <doc:5.10-Phase7-ParallelOptimization> - Parallel multi-start for global optimum
- <doc:5.11-Phase7-PerformanceBenchmarking> - Performance testing

**Phase 8: Specialized Applications**
- <doc:5.12-Phase8-SparseMatrix> - Large-scale sparse matrix operations
- <doc:5.13-Phase8-MultiPeriod> - Stochastic multi-period optimization
- <doc:5.14-Phase8-RobustOptimization> - Optimization under uncertainty

#### Specialized Topics
- <doc:5.15-InequalityConstraints> - Deep dive on inequality constraint handling

### Appendices

#### Case Studies
- <doc:Appendix-A-ReidsRaisinsExample> - Comprehensive real-world example integrating multiple concepts

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

**Build a revenue forecast**
→ <doc:3.1-GrowthModeling>, <doc:3.2-ForecastingGuide>, <doc:3.3-BuildingRevenueModel>

**Value a company**
→ <doc:3.9-EquityValuationGuide>, <doc:3.8-InvestmentAnalysis>

**Create financial statements**
→ <doc:3.4-BuildingFinancialReports>, <doc:3.5-FinancialStatementsGuide>

**Measure portfolio risk**
→ <doc:2.3-RiskAnalyticsGuide>, <doc:5.2-PortfolioOptimizationGuide>

**Run Monte Carlo simulation**
→ <doc:4.1-MonteCarloTimeSeriesGuide>

**Optimize resource allocation**
→ <doc:5.1-OptimizationGuide> (Phase 5), <doc:5.7-Phase5-BusinessOptimization>

**Analyze sensitivity**
→ <doc:2.1-DataTableAnalysis>, <doc:4.2-ScenarioAnalysisGuide>

**Price bonds or calculate duration**
→ <doc:3.10-BondValuationGuide>

**Model credit risk**
→ <doc:3.11-CreditDerivativesGuide>, <doc:2.3-RiskAnalyticsGuide>

**Build efficient portfolios**
→ <doc:5.2-PortfolioOptimizationGuide>

## What's New

### Latest Release Highlights

**Securities Valuation (v1.4.0)**:
- Equity valuation: DCF, DDM, FCFE, residual income models (<doc:3.9-EquityValuationGuide>)
- Fixed income: Bond pricing, duration, convexity, callable bonds (<doc:3.10-BondValuationGuide>)
- Credit derivatives: CDS pricing with ISDA Standard Model (<doc:3.11-CreditDerivativesGuide>)

**Advanced Optimization (v1.3.0)**:
- Portfolio optimization: Efficient frontier, Sharpe ratio maximization (<doc:5.2-PortfolioOptimizationGuide>)
- Integer programming: Branch-and-bound with cutting planes (<doc:5.8-Phase6-IntegerProgramming>)
- Robust optimization: Uncertainty-aware optimization (<doc:5.14-Phase8-RobustOptimization>)

**Risk Analytics (v1.2.0)**:
- Monte Carlo simulation for time series (<doc:4.1-MonteCarloTimeSeriesGuide>)
- VaR/CVaR calculation and stress testing (<doc:2.3-RiskAnalyticsGuide>)
- Scenario analysis framework (<doc:4.2-ScenarioAnalysisGuide>)

## System Requirements

- Swift 6.0 or later
- macOS 13.0+ / iOS 16.0+ / Linux with Swift 6.0+
- Xcode 16.0+ (for development)

## Installation

### Swift Package Manager

Add BusinessMath to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jpurnell/BusinessMath.git", from: "1.4.0")
]
```

## Support & Community

- **Documentation**: You're reading it! Start with <doc:1.1-GettingStarted>
- **GitHub**: [https://github.com/jpurnell/BusinessMath](https://github.com/jpurnell/BusinessMath)
- **Issues**: Report bugs or request features on GitHub
- **Discussions**: Share ideas and ask questions in GitHub Discussions

## License

BusinessMath is available under the MIT License. See the LICENSE file for details.

## Acknowledgments

Built with industry-standard methodologies including:
- ISDA Standard CDS Model for credit derivatives
- Black-Scholes framework for options pricing
- Modern Portfolio Theory (Markowitz)
- IFRS 16 / ASC 842 for lease accounting

---

**Ready to get started?** Begin with <doc:1.1-GettingStarted> or choose a <doc:LearningPath> for your role.

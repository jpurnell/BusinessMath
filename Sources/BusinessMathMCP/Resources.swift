import Foundation
import MCP

// MARK: - Resource Definitions

/// Provides resource listings and content for BusinessMath MCP Server
public actor ResourceProvider {

    /// List all available resources
    public func listResources() -> [Resource] {
        return [
            // Documentation Resources
            Resource(
                name: "Time Value of Money Formulas",
                uri: "docs://tvm-formulas",
                description: "Complete reference for present value, future value, NPV, IRR, and annuity calculations",
                mimeType: "text/plain"
            ),
            Resource(
                name: "Statistical Analysis Methods",
                uri: "docs://statistical-methods",
                description: "Reference for correlation, regression, hypothesis testing, and descriptive statistics",
                mimeType: "text/plain"
            ),
            Resource(
                name: "Monte Carlo Simulation Guide",
                uri: "docs://monte-carlo-guide",
                description: "Guide to probabilistic modeling, distributions, and risk analysis techniques",
                mimeType: "text/plain"
            ),
            Resource(
                name: "Forecasting Techniques",
                uri: "docs://forecasting-techniques",
                description: "Overview of trend analysis, seasonal adjustment, and time series forecasting",
                mimeType: "text/plain"
            ),

            // Example Resources
            Resource(
                name: "Investment Analysis Example",
                uri: "example://investment-analysis",
                description: "Complete example of analyzing an investment using NPV, IRR, and sensitivity analysis",
                mimeType: "text/plain"
            ),
            Resource(
                name: "Loan Comparison Example",
                uri: "example://loan-comparison",
                description: "Example comparing different loan options using amortization schedules and total cost",
                mimeType: "text/plain"
            ),
            Resource(
                name: "Risk Modeling Example",
                uri: "example://risk-modeling",
                description: "Monte Carlo simulation example for project risk assessment",
                mimeType: "text/plain"
            ),

            // Reference Data
            Resource(
                name: "Financial Glossary",
                uri: "reference://financial-glossary",
                description: "Comprehensive glossary of financial and statistical terms",
                mimeType: "application/json"
            ),
            Resource(
                name: "Common Interest Rates Reference",
                uri: "reference://common-rates",
                description: "Reference guide for typical interest rates and compounding periods",
                mimeType: "text/plain"
            ),
            Resource(
                name: "Probability Distributions Guide",
                uri: "reference://distribution-guide",
                description: "Guide to probability distributions available for Monte Carlo simulation",
                mimeType: "text/plain"
            )
        ]
    }

    /// Read resource content by URI
    public func readResource(uri: String) throws -> ReadResource.Result {
        switch uri {
        // Documentation
        case "docs://tvm-formulas":
            return .init(contents: [.text(tvmFormulasDoc, uri: uri)])

        case "docs://statistical-methods":
            return .init(contents: [.text(statisticalMethodsDoc, uri: uri)])

        case "docs://monte-carlo-guide":
            return .init(contents: [.text(monteCarloGuideDoc, uri: uri)])

        case "docs://forecasting-techniques":
            return .init(contents: [.text(forecastingTechniquesDoc, uri: uri)])

        // Examples
        case "example://investment-analysis":
            return .init(contents: [.text(investmentAnalysisExample, uri: uri)])

        case "example://loan-comparison":
            return .init(contents: [.text(loanComparisonExample, uri: uri)])

        case "example://risk-modeling":
            return .init(contents: [.text(riskModelingExample, uri: uri)])

        // Reference Data
        case "reference://financial-glossary":
            return .init(contents: [.text(financialGlossaryJSON, uri: uri, mimeType: "application/json")])

        case "reference://common-rates":
            return .init(contents: [.text(commonRatesReference, uri: uri)])

        case "reference://distribution-guide":
            return .init(contents: [.text(distributionGuideDoc, uri: uri)])

        default:
            throw ResourceError.notFound(uri)
        }
    }

    public init() {}
}

/// Resource-specific errors
public enum ResourceError: Error, LocalizedError {
    case notFound(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let uri):
            return "Resource not found: \(uri)"
        }
    }
}

// MARK: - Resource Content

private let tvmFormulasDoc = """
# Time Value of Money Formulas

## Present Value (PV)
Calculate the current value of a future amount:
```
PV = FV / (1 + r)^n
```
- FV: Future Value
- r: Interest rate per period
- n: Number of periods

## Future Value (FV)
Calculate the future value of a present amount:
```
FV = PV × (1 + r)^n
```

## Net Present Value (NPV)
Calculate the present value of a series of cash flows:
```
NPV = Σ(CF_t / (1 + r)^t)
```
- CF_t: Cash flow at time t
- r: Discount rate
- t: Time period

## Internal Rate of Return (IRR)
The discount rate that makes NPV = 0:
```
0 = Σ(CF_t / (1 + IRR)^t)
```

## Annuity Present Value
Present value of regular payments:
```
PV_annuity = PMT × [(1 - (1 + r)^-n) / r]
```

## Annuity Future Value
Future value of regular payments:
```
FV_annuity = PMT × [((1 + r)^n - 1) / r]
```

## Payment Calculation
Calculate payment amount for a loan:
```
PMT = PV × [r(1 + r)^n] / [(1 + r)^n - 1]
```

## Tools Available
- calculate_present_value
- calculate_future_value
- calculate_npv
- calculate_irr
- calculate_payment
- calculate_annuity_pv
- calculate_annuity_fv
- calculate_xnpv
- calculate_xirr
"""

private let statisticalMethodsDoc = """
# Statistical Analysis Methods

## Descriptive Statistics
- **Mean**: Average value of a dataset
- **Median**: Middle value when sorted
- **Standard Deviation**: Measure of spread around the mean
- **Variance**: Square of standard deviation
- **Skewness**: Measure of asymmetry
- **Kurtosis**: Measure of tail heaviness

## Correlation Analysis
### Pearson Correlation
Measures linear relationship between two variables:
```
r = Σ((x - x̄)(y - ȳ)) / √(Σ(x - x̄)² × Σ(y - ȳ)²)
```
Range: -1 to +1

### Spearman's Rank Correlation
Non-parametric measure of monotonic relationship

## Regression Analysis
### Linear Regression
```
y = mx + b
```
- Slope (m): Change in y per unit change in x
- Intercept (b): Value of y when x = 0
- R²: Proportion of variance explained

## Confidence Intervals
Estimate range for population parameter:
```
CI = x̄ ± (t × SE)
```
- t: t-statistic for desired confidence level
- SE: Standard error of the mean

## Z-Score
Standardized score:
```
z = (x - μ) / σ
```

## Tools Available
- calculate_correlation
- linear_regression
- spearmans_correlation
- calculate_confidence_interval
- calculate_covariance
- calculate_z_score
- descriptive_stats_extended
"""

private let monteCarloGuideDoc = """
# Monte Carlo Simulation Guide

## Overview
Monte Carlo simulation uses random sampling to model uncertainty and risk in quantitative analysis.

## Probability Distributions

### Normal Distribution
- Parameters: mean (μ), standard deviation (σ)
- Use for: Symmetric, bell-shaped data
- Example: Stock returns, measurement errors

### Uniform Distribution
- Parameters: minimum, maximum
- Use for: Equal probability across range
- Example: Random numbers, simple scenarios

### Triangular Distribution
- Parameters: minimum, maximum, mode
- Use for: Expert estimates with most likely value
- Example: Project duration estimates

### Lognormal Distribution
- Parameters: μ, σ (of underlying normal)
- Use for: Positive-only, right-skewed data
- Example: Asset prices, income distributions

### Exponential Distribution
- Parameters: rate (λ)
- Use for: Time between events
- Example: Equipment failure times

### Beta Distribution
- Parameters: α, β
- Use for: Bounded probabilities and proportions
- Example: Success rates, completion percentages

## Simulation Process
1. Define uncertain variables and distributions
2. Specify relationships (calculation/model)
3. Run thousands of iterations
4. Analyze results (statistics, percentiles, VaR)

## Complete Examples

### Example 1: Simple Revenue Simulation
Model revenue with $1M mean and $200K standard deviation:

```json
{
  "inputs": [
    {
      "name": "Revenue",
      "distribution": "normal",
      "parameters": {"mean": 1000000, "stdDev": 200000}
    }
  ],
  "calculation": "{0}",
  "iterations": 10000
}
```

### Example 2: Profit Simulation (Revenue - Costs)
Model profit as the difference between uncertain revenue and costs:

```json
{
  "inputs": [
    {
      "name": "Revenue",
      "distribution": "normal",
      "parameters": {"mean": 1000000, "stdDev": 200000}
    },
    {
      "name": "Costs",
      "distribution": "normal",
      "parameters": {"mean": 600000, "stdDev": 100000}
    }
  ],
  "calculation": "{0} - {1}",
  "iterations": 10000
}
```

### Example 3: Profit Margin Simulation
Calculate profit margin percentage: (Revenue - Costs) / Revenue * 100

```json
{
  "inputs": [
    {
      "name": "Revenue",
      "distribution": "normal",
      "parameters": {"mean": 1000000, "stdDev": 200000}
    },
    {
      "name": "Costs",
      "distribution": "uniform",
      "parameters": {"min": 500000, "max": 700000}
    }
  ],
  "calculation": "({0} - {1}) / {0} * 100",
  "iterations": 10000
}
```

### Example 4: Project Value with Triangular Estimates
Use triangular distribution for expert estimates (min, most likely, max):

```json
{
  "inputs": [
    {
      "name": "Project Cost",
      "distribution": "triangular",
      "parameters": {"min": 80000, "mode": 100000, "max": 150000}
    },
    {
      "name": "Project Benefit",
      "distribution": "triangular",
      "parameters": {"min": 120000, "mode": 180000, "max": 250000}
    }
  ],
  "calculation": "{1} - {0}",
  "iterations": 10000
}
```

## Risk Metrics
- **Value at Risk (VaR)**: Maximum loss at given confidence level
- **Expected Value**: Mean outcome
- **Standard Deviation**: Volatility/uncertainty
- **Percentiles**: Probability thresholds (p10, p50, p90)

## Sensitivity Analysis
Identify which input variables have the greatest impact on outcomes.

## Tools Available
- run_monte_carlo
- create_distribution
- analyze_simulation_results
- calculate_value_at_risk
- sensitivity_analysis
- tornado_chart
- calculate_probability
"""

private let forecastingTechniquesDoc = """
# Forecasting Techniques

## Trend Analysis

### Linear Trend
```
y = a + bt
```
Simple straight-line growth

### Exponential Trend
```
y = ae^(bt)
```
Constant percentage growth

### Power Trend
```
y = at^b
```
Accelerating or decelerating growth

## Seasonal Adjustment

### Seasonal Indices
Measure typical pattern for each period (e.g., monthly, quarterly)

### Seasonal Decomposition
Separate time series into:
- Trend component
- Seasonal component
- Residual (irregular) component

### Deseasonalization
Remove seasonal effects to reveal underlying trend

## Time Series Forecasting

### Moving Averages
Average of recent observations to smooth data

### Exponential Smoothing
Weighted average giving more weight to recent observations

### Trend with Seasonality
Combine trend projection with seasonal patterns

## Model Evaluation
- **R-squared (R²)**: Goodness of fit
- **Forecast accuracy**: Compare predictions to actuals
- **Confidence intervals**: Range of likely outcomes

## Tools Available
- forecast_trend
- calculate_seasonal_indices
- seasonally_adjust
- decompose_time_series
- forecast_with_seasonality
- moving_average
- calculate_growth_rate
- compare_periods
"""

private let investmentAnalysisExample = """
# Investment Analysis Example

## Scenario
Evaluating a $100,000 investment in new equipment with expected cash flows over 5 years.

## Given Data
- Initial Investment: -$100,000
- Year 1 Cash Flow: $25,000
- Year 2 Cash Flow: $30,000
- Year 3 Cash Flow: $35,000
- Year 4 Cash Flow: $30,000
- Year 5 Cash Flow: $25,000
- Discount Rate: 10%

## Step 1: Calculate NPV
```
Use: calculate_npv
Arguments:
- cashFlows: [-100000, 25000, 30000, 35000, 30000, 25000]
- discountRate: 0.10

Result: NPV = $12,434.26
Decision: Positive NPV indicates good investment
```

## Step 2: Calculate IRR
```
Use: calculate_irr
Arguments:
- cashFlows: [-100000, 25000, 30000, 35000, 30000, 25000]

Result: IRR = 14.2%
Decision: IRR > discount rate (10%), investment is attractive
```

## Step 3: Sensitivity Analysis
Test how NPV changes with different discount rates:
- At 8%: NPV = $19,562
- At 10%: NPV = $12,434
- At 12%: NPV = $6,089
- At 15%: NPV = -$1,623

## Conclusion
Investment is viable with positive NPV and IRR above required return. However, sensitive to discount rate assumptions.
"""

private let loanComparisonExample = """
# Loan Comparison Example

## Scenario
Comparing two loan offers for $200,000:

### Loan A
- Amount: $200,000
- Rate: 6% annual
- Term: 30 years
- Monthly payment: $1,199.10

### Loan B
- Amount: $200,000
- Rate: 5.5% annual
- Term: 15 years
- Monthly payment: $1,634.17

## Analysis using create_amortization_schedule

### Loan A Total Cost
```
Monthly Payment: $1,199.10
Total Paid: $431,676 (360 payments)
Total Interest: $231,676
```

### Loan B Total Cost
```
Monthly Payment: $1,634.17
Total Paid: $294,151 (180 payments)
Total Interest: $94,151
```

## Comparison
- **Monthly affordability**: Loan A ($1,199 vs $1,634)
- **Total interest**: Loan B saves $137,525
- **Payoff time**: Loan B done in 15 years vs 30

## Decision Factors
1. Can you afford higher monthly payment?
2. What's your investment opportunity cost?
3. Do you plan to stay in property long-term?

Use calculate_payment tool to explore custom scenarios.
"""

private let riskModelingExample = """
# Risk Modeling Example: Project Revenue Forecast

## Scenario
Modeling uncertain revenue for a new product launch.

## Uncertain Variables

### Sales Volume
- Distribution: Triangular
- Minimum: 5,000 units
- Most Likely: 10,000 units
- Maximum: 20,000 units

### Price Per Unit
- Distribution: Normal
- Mean: $50
- Std Dev: $5

### Cost Per Unit
- Distribution: Normal
- Mean: $30
- Std Dev: $3

## Simulation Setup
```
Use: run_monte_carlo
Iterations: 10,000

Calculation: (units × price) - (units × cost)
```

## Results
```
Mean Revenue: $195,000
Std Deviation: $45,000
90% Confidence Interval: $118,000 - $285,000

Percentiles:
- P10: $130,000
- P25: $165,000
- P50 (Median): $195,000
- P75: $225,000
- P90: $260,000
```

## Risk Metrics
```
Use: calculate_value_at_risk
Confidence: 95%

VaR: 95% chance revenue exceeds $112,000
```

## Interpretation
- Expected revenue: ~$195K
- Wide range due to uncertainty
- 5% risk of revenue below $112K
- Use for contingency planning
"""

private let financialGlossaryJSON = """
{
  "terms": {
    "Present Value": "The current value of a future sum of money or stream of cash flows given a specified rate of return",
    "Future Value": "The value of a current asset at a future date based on an assumed rate of growth",
    "Net Present Value": "The difference between the present value of cash inflows and outflows over a period of time",
    "Internal Rate of Return": "The discount rate that makes the net present value of all cash flows equal to zero",
    "Discount Rate": "The interest rate used to determine the present value of future cash flows",
    "Annuity": "A series of equal payments made at regular intervals",
    "Amortization": "The process of paying off debt with regular payments over time",
    "Standard Deviation": "A measure of the amount of variation or dispersion of a set of values",
    "Correlation": "A statistical measure that describes the degree to which two variables move in relation to each other",
    "R-squared": "A statistical measure representing the proportion of variance in the dependent variable explained by the independent variable(s)",
    "Monte Carlo Simulation": "A computational technique that uses repeated random sampling to obtain numerical results",
    "Value at Risk": "A statistical technique measuring the maximum potential loss over a specific time frame at a given confidence level",
    "Sensitivity Analysis": "A technique used to determine how different values of an independent variable affect a particular dependent variable",
    "Time Series": "A sequence of data points indexed in time order",
    "Seasonal Adjustment": "A statistical technique for removing seasonal patterns from time series data",
    "Confidence Interval": "A range of values used to estimate the true value of a population parameter"
  }
}
"""

private let commonRatesReference = """
# Common Interest Rates Reference

## Compounding Periods
- **Annual**: 1 time per year
- **Semi-annual**: 2 times per year
- **Quarterly**: 4 times per year
- **Monthly**: 12 times per year
- **Daily**: 365 times per year

## Converting Rates
### Annual to Period Rate
```
period_rate = annual_rate / periods_per_year
```

### Effective Annual Rate
```
EAR = (1 + r/n)^n - 1
```
where:
- r = nominal annual rate
- n = compounding periods per year

## Typical Rate Ranges (Historical Averages)

### Loans
- **Mortgage (30-year)**: 3% - 7%
- **Auto Loan**: 4% - 10%
- **Personal Loan**: 6% - 36%
- **Credit Card**: 15% - 25%

### Investments
- **Savings Account**: 0.5% - 2%
- **CD (1-year)**: 1% - 4%
- **Corporate Bond**: 3% - 8%
- **Stock Market (historical)**: 8% - 12%

### Business
- **WACC (typical)**: 7% - 12%
- **Hurdle Rate**: 10% - 15%
- **Inflation (target)**: 2% - 3%

Note: Rates vary significantly based on market conditions, creditworthiness, and economic environment.
"""

private let distributionGuideDoc = """
# Probability Distributions Guide

## Normal Distribution
**When to use**: Symmetric data, many natural phenomena
**Parameters**:
- mean (μ): Center of distribution
- standard deviation (σ): Spread

**Properties**:
- 68% within ±1σ
- 95% within ±2σ
- 99.7% within ±3σ

**Examples**: Heights, test scores, measurement errors

## Uniform Distribution
**When to use**: Equal probability across range
**Parameters**:
- minimum: Lower bound
- maximum: Upper bound

**Properties**:
- All values equally likely
- Mean = (min + max) / 2

**Examples**: Random number generation, simple uncertainty

## Triangular Distribution
**When to use**: Expert judgment with most likely value
**Parameters**:
- minimum: Optimistic estimate
- mode: Most likely value
- maximum: Pessimistic estimate

**Properties**:
- Intuitive for estimates
- Requires three-point estimation

**Examples**: Project duration, cost estimates

## Lognormal Distribution
**When to use**: Positive values, right-skewed
**Parameters**:
- μ: Mean of log-transformed values
- σ: Std dev of log-transformed values

**Properties**:
- Always positive
- Long right tail
- Multiplicative processes

**Examples**: Stock prices, income, particle sizes

## Exponential Distribution
**When to use**: Time between events
**Parameters**:
- rate (λ): Average events per unit time

**Properties**:
- Memoryless
- Mean = 1/λ

**Examples**: Equipment failures, wait times

## Beta Distribution
**When to use**: Probabilities and proportions (0-1)
**Parameters**:
- α (alpha): Shape parameter
- β (beta): Shape parameter

**Properties**:
- Bounded [0,1]
- Flexible shape

**Examples**: Success rates, completion percentages

## Gamma Distribution
**When to use**: Sum of exponentials, wait times
**Parameters**:
- shape (r): Number of events
- rate (λ): Rate parameter

**Properties**:
- Always positive
- Flexible shapes

**Examples**: Insurance claims, rainfall

## Weibull Distribution
**When to use**: Failure analysis, lifetime data
**Parameters**:
- shape (k): Determines distribution shape
- scale (λ): Scale parameter

**Properties**:
- Flexible hazard rates
- Used in reliability engineering

**Examples**: Product lifetimes, wind speeds

## Distribution Selection Guide

| Use Case | Recommended Distribution |
|----------|-------------------------|
| Prices, revenues | Lognormal |
| Time, duration | Triangular, Beta |
| Probabilities | Beta, Uniform |
| Count data | Poisson (not yet supported) |
| Equipment life | Weibull, Exponential |
| General uncertainty | Normal, Triangular |
"""

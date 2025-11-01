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
            Resource(
                name: "Optimization and Solvers Guide",
                uri: "docs://optimization-guide",
                description: "Newton-Raphson method, gradient descent, and capital allocation for solving business optimization problems",
                mimeType: "text/plain"
            ),
            Resource(
                name: "Portfolio Optimization Guide",
                uri: "docs://portfolio-optimization",
                description: "Modern Portfolio Theory, efficient frontier, risk parity, and portfolio construction techniques",
                mimeType: "text/plain"
            ),
            Resource(
                name: "Real Options Valuation Guide",
                uri: "docs://real-options",
                description: "Black-Scholes model, binomial trees, option Greeks, and strategic flexibility valuation",
                mimeType: "text/plain"
            ),
            Resource(
                name: "Risk Analytics Guide",
                uri: "docs://risk-analytics",
                description: "Stress testing, VaR/CVaR, risk aggregation, and comprehensive risk measurement techniques",
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

        case "docs://optimization-guide":
            return .init(contents: [.text(optimizationGuideDoc, uri: uri)])

        case "docs://portfolio-optimization":
            return .init(contents: [.text(portfolioOptimizationDoc, uri: uri)])

        case "docs://real-options":
            return .init(contents: [.text(realOptionsDoc, uri: uri)])

        case "docs://risk-analytics":
            return .init(contents: [.text(riskAnalyticsDoc, uri: uri)])

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

private let optimizationGuideDoc = """
# Optimization and Numerical Solvers

## Newton-Raphson Method
Find values where a function equals a target (root-finding/goal seek).

**Use Cases**:
- Break-even analysis
- Yield to maturity
- IRR calculation
- Any equation solving

**Tool**: newton_raphson_optimize (requires closure-based implementation)

**Example**: Find price where profit = $100,000

## Gradient Descent
Find maximum or minimum of multi-variable functions.

**Use Cases**:
- Profit maximization
- Cost minimization
- Portfolio allocation
- Parameter optimization

**Tool**: gradient_descent_optimize

**Parameters**:
- objective: "maximize" or "minimize"
- initialValues: Starting point for variables
- learningRate: Step size (default: 0.01)
- maxIterations: Maximum steps (default: 1000)

## Capital Allocation
Select optimal projects within budget constraints.

**Methods**:
1. **Greedy**: Sort by profitability index (NPV/Cost), select highest first
   - Fast, good approximation
   - O(n log n) time complexity

2. **Optimal**: Integer programming for exact solution
   - Finds truly optimal combination
   - Slower for large project sets

**Tool**: optimize_capital_allocation

**Inputs**:
- projects: Array of {name, cost, npv}
- budget: Total capital available
- method: "greedy" or "optimal"

**Output**:
- Selected projects
- Total NPV
- Capital used/remaining
- Diversification benefit

## Best Practices

**Newton-Raphson**:
- Choose good initial guess (close to solution)
- Check for convergence
- May fail if function not differentiable

**Gradient Descent**:
- Normalize variables to similar scales
- Tune learning rate (too high = diverge, too low = slow)
- Use momentum for faster convergence

**Capital Allocation**:
- Consider project dependencies
- Account for timing constraints
- Review profitability index rankings
- Validate against strategic priorities
"""

private let portfolioOptimizationDoc = """
# Portfolio Optimization

Modern Portfolio Theory for building optimal investment portfolios.

## Core Concepts

**Risk-Return Tradeoff**: Higher returns typically require higher risk
**Diversification**: Combining imperfectly correlated assets reduces risk
**Efficient Frontier**: Set of portfolios with maximum return for each risk level
**Sharpe Ratio**: Return per unit of risk (higher is better)

## Portfolio Optimization
Find weights that maximize Sharpe ratio.

**Tool**: optimize_portfolio

**Inputs**:
- assets: Asset names
- returns: Historical returns for each asset
- riskFreeRate: Risk-free rate for Sharpe calculation

**Outputs**:
- Optimal weights
- Expected return
- Risk (volatility)
- Sharpe ratio

**Example**: 3-asset portfolio optimization

## Efficient Frontier
Generate the complete risk-return curve.

**Tool**: calculate_efficient_frontier

**Inputs**: Same as optimization + points (number of frontier points)

**Outputs**:
- Array of risk-return combinations
- Weights for each point
- Sharpe ratios

**Use Cases**:
- Visualize risk-return tradeoffs
- Find minimum risk portfolio
- Identify maximum Sharpe portfolio
- Compare portfolio positions

## Risk Parity
Allocate so each asset contributes equally to portfolio risk.

**Tool**: calculate_risk_parity

**Philosophy**:
- Don't rely on return forecasts
- Focus on balanced risk exposure
- Natural diversification

**When to Use**:
✓ Skeptical of return predictions
✓ Want balanced exposure
✓ Prefer diversification focus

**When NOT to Use**:
✗ Have strong return views
✗ Want maximum Sharpe ratio
✗ Some assets clearly dominate

## Portfolio Construction

**Data Requirements**:
- At least 30 historical observations
- Same time period for all assets
- Use appropriate frequency (daily, monthly)
- Clean data (no missing values)

**Rebalancing**:
- Set thresholds (e.g., ±5% from target)
- Rebalance quarterly or annually
- Consider transaction costs
- Tax implications for taxable accounts

**Constraints**:
- Minimum weights (avoid tiny positions)
- Maximum weights (limit concentration)
- Sector limits
- Minimum "safe" asset allocation

## Key Metrics

**Expected Return**: Weighted average of asset returns
**Portfolio Risk**: Not just weighted average (diversification effect)
**Sharpe Ratio**: (Return - RiskFree) / Risk
**Correlation**: Key driver of diversification benefit

## Practical Tips

1. **Use monthly data** for most analyses (balance of history vs. recency)
2. **Annualize metrics**: Monthly return × 12, Monthly risk × √12
3. **Out-of-sample testing**: Hold out data for validation
4. **Robustness**: Test with different time periods
5. **Implementation**: Round weights to practical values (e.g., 5% increments)
"""

private let realOptionsDoc = """
# Real Options Valuation

Apply financial option pricing to strategic business decisions.

## Core Concept
Real options capture the value of flexibility - the ability to expand, abandon, delay, or switch strategies as uncertainty resolves.

**Traditional NPV**: Static, ignores flexibility value
**Real Options**: Dynamic, values managerial flexibility

## Black-Scholes Model
Price European options (exercisable only at expiration).

**Tool**: price_black_scholes_option

**Inputs**:
- optionType: "call" or "put"
- spotPrice: Current asset/project value
- strikePrice: Exercise price
- timeToExpiry: Years until expiration
- riskFreeRate: Annual rate
- volatility: Annual volatility

**Outputs**:
- Option price
- Intrinsic value
- Time value
- Moneyness (ITM/OTM/ATM)

**Moneyness**:
- ITM (In-The-Money): Profitable to exercise now
- OTM (Out-of-The-Money): Not profitable to exercise now
- ATM (At-The-Money): Strike ≈ Spot

## Option Greeks
Sensitivity measures for risk management.

**Tool**: calculate_option_greeks

**Greeks Explained**:
- **Delta**: Price change per $1 move in underlying
  - Range: 0 to 1 (calls), -1 to 0 (puts)
  - Hedge ratio: Shares needed to hedge

- **Gamma**: Delta change per $1 move
  - Highest at-the-money
  - Measures delta stability

- **Vega**: Price change per 1% volatility increase
  - All options have positive vega
  - Highest at-the-money, with more time

- **Theta**: Daily time decay
  - Usually negative (lose value daily)
  - Accelerates near expiration

- **Rho**: Price change per 1% rate increase
  - Usually least important
  - More relevant for long-dated options

## Binomial Tree Model
Price American options (early exercise allowed).

**Tool**: price_binomial_option

**Advantages over Black-Scholes**:
- Handles American options
- Allows early exercise
- More flexible (dividends, changing volatility)

**Parameters**:
- americanStyle: true/false
- steps: More steps = more accurate (default: 100)

**Early Exercise Premium**: American - European value

## Real Options Applications

### Expansion Option (Call)
Value the right to grow into new markets.

**Tool**: value_expansion_option

**Analogy**: Call option on growth
- Underlying: Expansion NPV
- Strike: Expansion cost
- Time: Decision deadline

**Example**: Software company market expansion

### Abandonment Option (Put)
Value the safety net of being able to exit.

**Tool**: value_abandonment_option

**Analogy**: Put option on project
- Underlying: Project NPV
- Strike: Salvage value
- Time: Decision point

**Example**: Manufacturing with equipment resale

## Key Inputs

**Volatility** (Most Important):
- Historical stock volatility (public companies)
- Comparable company volatility
- Scenario analysis
- Analyst estimates

Typical values:
- Mature markets: 20-30%
- New markets: 30-50%
- R&D projects: 40-60%

**Time to Expiration**:
- Patent expiration
- Lease terms
- Technology obsolescence
- Competitive window

**Risk-Free Rate**:
- Use Treasury rate matching horizon
- Adjust for country risk if needed

## When Real Options Add Value

✓ **High Uncertainty**: Unpredictable future (new markets, R&D)
✓ **Managerial Flexibility**: Can adjust strategy as info arrives
✓ **Staged Investments**: Invest in phases, learn along the way
✓ **Strategic Value**: Option to grow, switch, exit has value

✗ **Low Uncertainty**: Predictable outcomes
✗ **Fixed Strategy**: No flexibility to adjust
✗ **Now or Never**: No phased approach possible

## Practical Tips

1. **Start simple**: Use Black-Scholes for quick estimates
2. **Validate inputs**: Sensitivity analysis on volatility
3. **Compare to DCF**: Traditional NPV as baseline
4. **Document assumptions**: Especially volatility and timing
5. **Use frameworks**: Real options complements, not replaces, NPV
"""

private let riskAnalyticsDoc = """
# Risk Analytics and Stress Testing

Measure and manage risk with comprehensive analytics.

## Stress Testing
Evaluate how business performs under adverse scenarios.

**Tool**: run_stress_test

**Pre-Defined Scenarios**:
- **Recession**: Moderate downturn (-15% revenue, +5% costs)
- **Crisis**: Severe financial crisis (-30% revenue, +10% costs)
- **Supply Shock**: Supply chain disruption (-5% revenue, +25% costs)
- **Custom**: Define your own shocks

**Inputs**:
- scenario: Scenario type
- baseRevenue, baseCosts, baseNPV: Baseline metrics
- customShocks: For custom scenarios

**Outputs**:
- Stressed metrics
- Impact analysis
- Risk assessment
- Recommendations

## Value at Risk (VaR)
Maximum expected loss at confidence level.

**Tool**: calculate_value_at_risk

**VaR Interpretation**:
- 95% VaR = 2.5%: "95% confident won't lose more than 2.5% in a period"
- Answers: "How bad can it get in normal conditions?"

**CVaR (Conditional VaR / Expected Shortfall)**:
- Average loss in worst cases (beyond VaR)
- "If in worst 5%, expect to lose X%"
- Better tail risk measure than VaR

**Inputs**:
- returns: Historical returns
- portfolioValue: Current value
- confidenceLevel: 0.95 or 0.99
- riskFreeRate: For Sharpe/Sortino

**Outputs**:
- VaR (95% and 99%)
- CVaR
- Maximum drawdown
- Sharpe and Sortino ratios
- Tail statistics

## Risk Aggregation
Combine VaR across portfolios accounting for correlations.

**Tool**: aggregate_portfolio_risk

**Diversification Benefit**: Combined risk < sum of individual risks

**Inputs**:
- portfolioVaRs: Individual portfolio VaRs
- portfolioNames: Names for reporting
- correlations: NxN correlation matrix
- weights: Optional, for component VaR

**Outputs**:
- Aggregated VaR
- Diversification benefit
- Marginal VaR (incremental risk contribution)
- Component VaR (weighted contributions)

**Marginal VaR**: How much does each portfolio contribute to total risk?
**Component VaR**: Allocated risk ensuring sum equals total VaR

## Comprehensive Risk Metrics
Complete risk profile in one analysis.

**Tool**: calculate_comprehensive_risk

**Metrics Included**:
- VaR (95%, 99%)
- CVaR
- Maximum drawdown
- Sharpe ratio (return/total risk)
- Sortino ratio (return/downside risk)
- Tail risk ratio (CVaR/VaR)
- Skewness (distribution asymmetry)
- Kurtosis (tail thickness)

**Risk Score**: 0-6 scale based on multiple factors

## Key Concepts

**Maximum Drawdown**:
- Largest peak-to-trough decline
- Measures worst historical loss
- <10%: Low risk, <20%: Moderate, >20%: High

**Sharpe Ratio**:
- (Return - RiskFree) / Volatility
- >1.0: Excellent, >0.5: Good, <0.5: Poor

**Sortino Ratio**:
- Uses only downside volatility
- Higher than Sharpe = limited downside

**Tail Risk Ratio**:
- CVaR / VaR
- >1.3: High tail risk (fat tails)

**Skewness**:
- Negative: More frequent small gains, rare large losses (bad)
- Positive: More frequent small losses, rare large gains (good)

**Kurtosis**:
- >1.0: Fat tails, more extreme events than normal

## Risk Limits

**Example Framework**:
- Maximum VaR: 3% daily, 10% monthly
- Maximum drawdown: 20%
- Minimum Sharpe: 0.5
- Tail risk threshold: 1.3

**Monitoring**:
- Daily for trading portfolios
- Weekly for active strategies
- Monthly for long-term investments
- After significant market events

## Best Practices

1. **Use appropriate time period**: Match returns period to risk horizon
2. **Rolling windows**: Update as new data arrives
3. **Stress test + VaR**: Complementary measures
4. **Back-testing**: Validate VaR estimates with actual losses
5. **Tail scenarios**: Don't ignore extreme events

## Practical Applications

**Risk Budgeting**:
- Allocate risk limits across portfolios
- Use marginal VaR to optimize

**Capital Requirements**:
- Set reserves based on CVaR
- Buffer for tail events

**Performance Evaluation**:
- Risk-adjusted returns (Sharpe, Sortino)
- Compare to benchmarks

**Early Warnings**:
- Track VaR trending
- Alert on limit breaches
- Monitor tail risk ratio

## Interpretation Guide

**Low Risk Profile**:
- VaR < 2%
- Drawdown < 10%
- Sharpe > 1.0
- Skewness ≥ 0
- Kurtosis < 1.0

**High Risk Profile**:
- VaR > 5%
- Drawdown > 20%
- Sharpe < 0.5
- Skewness < -0.5
- Kurtosis > 1.0
- Tail risk > 1.3
"""

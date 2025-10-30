import Foundation
import MCP

// MARK: - Prompt Definitions

/// Provides prompt templates for common financial analysis tasks
public actor PromptProvider {

    /// List all available prompts
    public func listPrompts() -> [Prompt] {
        return [
            Prompt(
                name: "analyze_investment",
                description: "Comprehensive investment analysis using NPV, IRR, and sensitivity analysis",
                arguments: [
                    Prompt.Argument(
                        name: "investment_amount",
                        description: "Initial investment amount (negative number)",
                        required: true
                    ),
                    Prompt.Argument(
                        name: "discount_rate",
                        description: "Required rate of return (e.g., 0.10 for 10%)",
                        required: true
                    ),
                    Prompt.Argument(
                        name: "project_name",
                        description: "Name of the investment or project",
                        required: false
                    )
                ]
            ),

            Prompt(
                name: "compare_financing",
                description: "Compare different loan or financing options with detailed cost analysis",
                arguments: [
                    Prompt.Argument(
                        name: "amount",
                        description: "Loan amount needed",
                        required: true
                    ),
                    Prompt.Argument(
                        name: "purpose",
                        description: "Purpose of the loan (e.g., 'home mortgage', 'business expansion')",
                        required: false
                    )
                ]
            ),

            Prompt(
                name: "assess_risk",
                description: "Perform Monte Carlo risk assessment for uncertain outcomes",
                arguments: [
                    Prompt.Argument(
                        name: "scenario_name",
                        description: "Name of the scenario being analyzed",
                        required: true
                    ),
                    Prompt.Argument(
                        name: "confidence_level",
                        description: "Confidence level for risk metrics (e.g., 0.95 for 95%)",
                        required: false
                    )
                ]
            ),

            Prompt(
                name: "forecast_revenue",
                description: "Time series forecasting with trend and seasonality analysis",
                arguments: [
                    Prompt.Argument(
                        name: "business_name",
                        description: "Name of the business or product",
                        required: false
                    ),
                    Prompt.Argument(
                        name: "periods_ahead",
                        description: "Number of periods to forecast",
                        required: true
                    )
                ]
            ),

            Prompt(
                name: "analyze_portfolio",
                description: "Statistical analysis of investment portfolio returns and correlations",
                arguments: [
                    Prompt.Argument(
                        name: "portfolio_name",
                        description: "Name of the portfolio",
                        required: false
                    )
                ]
            ),

            Prompt(
                name: "debt_analysis",
                description: "Comprehensive debt and leverage analysis including ratios and coverage",
                arguments: [
                    Prompt.Argument(
                        name: "company_name",
                        description: "Name of the company",
                        required: false
                    )
                ]
            )
        ]
    }

    /// Get prompt content with arguments filled in
    public func getPrompt(name: String, arguments: [String: String]?) -> GetPrompt.Result {
        switch name {
        case "analyze_investment":
            return getInvestmentAnalysisPrompt(arguments: arguments)

        case "compare_financing":
            return getCompareFinancingPrompt(arguments: arguments)

        case "assess_risk":
            return getAssessRiskPrompt(arguments: arguments)

        case "forecast_revenue":
            return getForecastRevenuePrompt(arguments: arguments)

        case "analyze_portfolio":
            return getAnalyzePortfolioPrompt(arguments: arguments)

        case "debt_analysis":
            return getDebtAnalysisPrompt(arguments: arguments)

        default:
            return GetPrompt.Result(
                description: "Unknown prompt",
                messages: [
                    Prompt.Message(
                        role: .user,
                        content: .text(text: "Error: Prompt '\(name)' not found")
                    )
                ]
            )
        }
    }

    public init() {}
}

// MARK: - Prompt Implementations

private func getInvestmentAnalysisPrompt(arguments: [String: String]?) -> GetPrompt.Result {
    let amount = arguments?["investment_amount"] ?? "{investment_amount}"
    let rate = arguments?["discount_rate"] ?? "{discount_rate}"
    let projectName = arguments?["project_name"] ?? "this investment"

    let prompt = """
    Please perform a comprehensive investment analysis for \(projectName).

    **Initial Investment**: \(amount)
    **Required Rate of Return**: \(rate)

    I need you to:

    1. **Calculate NPV** using calculate_npv
       - Provide expected cash flows for each period
       - Use the discount rate of \(rate)
       - Interpret whether NPV is positive (good) or negative (bad)

    2. **Calculate IRR** using calculate_irr
       - Compare IRR to the required rate of return
       - Explain what the IRR tells us about this investment

    3. **Sensitivity Analysis**
       - Test NPV at different discount rates (±3 percentage points)
       - Show how sensitive the decision is to rate assumptions
       - Use calculate_npv multiple times with different rates

    4. **Payback Period**
       - Calculate how long until cumulative cash flows become positive
       - Consider both simple and discounted payback

    5. **Recommendation**
       - Should we proceed with this investment?
       - What are the key risks and assumptions?
       - Under what conditions might the decision change?

    Please provide clear explanations alongside the calculations so stakeholders can understand the analysis.
    """

    return GetPrompt.Result(
        description: "Investment analysis for \(projectName)",
        messages: [
            Prompt.Message.user(.text(text: prompt))
        ]
    )
}

private func getCompareFinancingPrompt(arguments: [String: String]?) -> GetPrompt.Result {
    let amount = arguments?["amount"] ?? "{amount}"
    let purpose = arguments?["purpose"] ?? "this need"

    let prompt = """
    I need to compare different financing options for \(purpose).

    **Amount Needed**: \(amount)

    Please help me evaluate and compare multiple loan options by:

    1. **Create Amortization Schedules** using create_amortization_schedule
       - For each loan option, provide:
         * Principal amount
         * Annual interest rate
         * Loan term (years)
         * Payment frequency
       - Show the complete amortization schedule

    2. **Calculate Total Costs**
       - Monthly payment amount
       - Total amount paid over life of loan
       - Total interest paid
       - Use calculate_payment to verify payments

    3. **Compare Options**
       - Create a comparison table of all options
       - Highlight differences in:
         * Monthly payment affordability
         * Total interest cost
         * Payoff timeline

    4. **Breakeven Analysis**
       - At what point does a lower rate justify higher monthly payments?
       - Consider opportunity cost of cash flow differences

    5. **Recommendation**
       - Which option is best for different scenarios?
         * Minimize monthly payment
         * Minimize total interest
         * Balanced approach
       - What assumptions are important?

    Please present the analysis in a clear, decision-ready format.
    """

    return GetPrompt.Result(
        description: "Financing comparison for \(purpose)",
        messages: [
            Prompt.Message.user(.text(text: prompt))
        ]
    )
}

private func getAssessRiskPrompt(arguments: [String: String]?) -> GetPrompt.Result {
    let scenario = arguments?["scenario_name"] ?? "{scenario_name}"
    let confidence = arguments?["confidence_level"] ?? "0.95"

    let prompt = """
    Please perform a Monte Carlo risk assessment for: \(scenario)

    **Confidence Level**: \(confidence)

    I need a comprehensive risk analysis with these steps:

    1. **Define Uncertain Variables**
       - Identify key variables with uncertainty
       - For each variable, specify:
         * Appropriate probability distribution
         * Distribution parameters (min, max, mean, std dev, etc.)
       - Use create_distribution for each variable

    2. **Run Monte Carlo Simulation** using run_monte_carlo
       - Define the calculation/model relating variables to outcome
       - Run at least 10,000 iterations
       - Capture the distribution of possible outcomes

    3. **Analyze Results** using analyze_simulation_results
       - Report key statistics:
         * Mean (expected value)
         * Standard deviation (volatility)
         * Min and max observed
       - Show percentile distribution:
         * P10, P25, P50 (median), P75, P90

    4. **Calculate Risk Metrics** using calculate_value_at_risk
       - Value at Risk (VaR) at \(confidence) confidence level
       - Interpret what this means for decision-making
       - Show the probability distribution graphically if possible

    5. **Sensitivity Analysis** using sensitivity_analysis
       - Which input variables drive the most uncertainty?
       - Create a tornado chart showing impact rankings
       - Recommend which variables need better estimates

    6. **Risk Interpretation**
       - What's the range of likely outcomes?
       - What's the probability of specific scenarios?
       - What contingencies should be planned?

    7. **Recommendations**
       - Should we proceed given the risk profile?
       - What risk mitigation strategies should be considered?
       - What additional information would reduce uncertainty?

    Present the analysis with clear visualizations and actionable insights.
    """

    return GetPrompt.Result(
        description: "Risk assessment for \(scenario)",
        messages: [
            Prompt.Message.user(.text(text: prompt))
        ]
    )
}

private func getForecastRevenuePrompt(arguments: [String: String]?) -> GetPrompt.Result {
    let business = arguments?["business_name"] ?? "the business"
    let periods = arguments?["periods_ahead"] ?? "{periods_ahead}"

    let prompt = """
    Please create a revenue forecast for \(business).

    **Forecast Horizon**: \(periods) periods ahead

    Perform a comprehensive time series analysis:

    1. **Analyze Historical Data**
       - Provide historical revenue data as a time series
       - Use descriptive_stats_extended to understand the data:
         * Average growth rate
         * Volatility (standard deviation)
         * Min/max values

    2. **Identify Patterns** using decompose_time_series
       - Separate the time series into:
         * Trend component
         * Seasonal component
         * Irregular/residual component
       - Describe what each component reveals

    3. **Calculate Seasonal Indices** using calculate_seasonal_indices
       - Determine typical pattern for each period
       - Show which periods are above/below average
       - Use seasonally_adjust if needed to see underlying trend

    4. **Trend Analysis** using forecast_trend
       - Test multiple trend models:
         * Linear (constant growth)
         * Exponential (percentage growth)
         * Power (accelerating/decelerating)
       - Compare R² values to select best fit

    5. **Generate Forecast** using forecast_with_seasonality
       - Project the trend forward \(periods) periods
       - Apply seasonal patterns to trend projection
       - Calculate confidence intervals around forecast

    6. **Growth Rate Analysis** using calculate_growth_rate
       - Calculate period-over-period growth rates
       - Identify acceleration or deceleration trends
       - Compare to industry benchmarks if available

    7. **Validate and Interpret**
       - How reliable is this forecast?
       - What assumptions does it depend on?
       - What could cause actual results to differ?
       - Show forecast uncertainty/ranges

    8. **Recommendations**
       - What do the trends suggest about business health?
       - Are there concerning patterns?
       - What actions should be taken based on forecast?

    Present the forecast with visualizations and confidence intervals.
    """

    return GetPrompt.Result(
        description: "Revenue forecast for \(business)",
        messages: [
            Prompt.Message.user(.text(text: prompt))
        ]
    )
}

private func getAnalyzePortfolioPrompt(arguments: [String: String]?) -> GetPrompt.Result {
    let portfolio = arguments?["portfolio_name"] ?? "the portfolio"

    let prompt = """
    Please perform a comprehensive statistical analysis of \(portfolio).

    I need you to analyze the risk and return characteristics:

    1. **Return Analysis**
       - Provide historical returns for each asset
       - Use descriptive_stats_extended for each asset:
         * Mean return
         * Standard deviation (volatility)
         * Skewness and kurtosis
         * Min/max returns

    2. **Correlation Analysis** using calculate_correlation
       - Calculate Pearson correlation between all asset pairs
       - Use spearmans_correlation for non-linear relationships
       - Create a correlation matrix
       - Interpret diversification benefits

    3. **Portfolio Statistics**
       - Calculate portfolio-level metrics:
         * Weighted average return
         * Portfolio standard deviation (considering correlations)
         * Sharpe ratio (if risk-free rate provided)

    4. **Risk Decomposition**
       - Which assets contribute most to portfolio risk?
       - Which assets provide diversification benefits?
       - Calculate covariance using calculate_covariance

    5. **Regression Analysis** using linear_regression
       - Regress each asset against market benchmark
       - Calculate beta (systematic risk)
       - Calculate alpha (excess return)
       - Interpret R² (how much return is explained by market)

    6. **Confidence Intervals** using calculate_confidence_interval
       - Estimate range for expected returns
       - Use 95% confidence level
       - Show uncertainty in return estimates

    7. **Performance Metrics**
       - Return per unit of risk (Sharpe/Sortino)
       - Maximum drawdown
       - Recovery periods
       - Consistency of returns

    8. **Recommendations**
       - Is the portfolio well-diversified?
       - Which assets should be rebalanced?
       - What's the risk/return profile vs. objectives?
       - Suggested portfolio adjustments?

    Present the analysis with clear tables and interpretations.
    """

    return GetPrompt.Result(
        description: "Portfolio analysis for \(portfolio)",
        messages: [
            Prompt.Message.user(.text(text: prompt))
        ]
    )
}

private func getDebtAnalysisPrompt(arguments: [String: String]?) -> GetPrompt.Result {
    let company = arguments?["company_name"] ?? "the company"

    let prompt = """
    Please perform a comprehensive debt and financial leverage analysis for \(company).

    I need you to evaluate the company's debt position and capacity:

    1. **Debt Structure Analysis**
       - Create amortization schedules for major debt using create_amortization_schedule
       - For each debt instrument:
         * Principal balance
         * Interest rate
         * Maturity
         * Payment schedule
         * Covenants

    2. **Cost of Capital Analysis** using calculate_wacc
       - Calculate Weighted Average Cost of Capital (WACC)
       - Components needed:
         * Market value of equity
         * Market value of debt
         * Cost of equity
         * Cost of debt
         * Tax rate
       - Interpret what WACC means for investment decisions

    3. **Debt Coverage Ratios** using debt_service_coverage_ratio
       - Calculate Debt Service Coverage Ratio (DSCR)
       - Assess ability to service debt from operating cash flow
       - Compare to covenant requirements
       - Trend analysis over time

    4. **Leverage Ratios**
       - Debt-to-Equity ratio
       - Debt-to-Assets ratio
       - Equity multiplier
       - Interest Coverage ratio
       - Compare to industry benchmarks

    5. **Financing Capacity**
       - Maximum additional debt based on coverage ratios
       - Optimal capital structure considerations
       - Impact of additional debt on WACC

    6. **Scenario Analysis** using compare_financing_options
       - Model different refinancing scenarios
       - Test impact of rate changes
       - Evaluate debt paydown vs. investment tradeoffs

    7. **Risk Assessment**
       - What's the refinancing risk?
       - Sensitivity to interest rate changes
       - Covenant compliance margin
       - Liquidity position

    8. **Recommendations**
       - Is the current debt level sustainable?
       - Should debt be refinanced or restructured?
       - Optimal mix of debt vs. equity financing?
       - Key risks and mitigation strategies?

    Provide a comprehensive debt analysis with clear metrics and recommendations.
    """

    return GetPrompt.Result(
        description: "Debt analysis for \(company)",
        messages: [
            Prompt.Message.user(.text(text: prompt))
        ]
    )
}

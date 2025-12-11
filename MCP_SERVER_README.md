# BusinessMath MCP Server

A comprehensive Model Context Protocol (MCP) server that exposes the BusinessMath library's financial calculations, time series analysis, and modeling capabilities to Claude and other MCP-compatible clients.

## What is MCP?

The Model Context Protocol (MCP) is a standard protocol that allows AI assistants like Claude to interact with external tools and data sources. This server makes BusinessMath's extensive financial and mathematical capabilities available to Claude through simple JSON-RPC calls.

## Features

The BusinessMath MCP Server provides **167 tools** across 32 categories:

### Time Value of Money (TVM) Tools (9 tools)

1. **calculate_present_value** - Calculate PV of a future amount
2. **calculate_future_value** - Calculate FV of a present amount
3. **calculate_npv** - Net Present Value for regular cash flows
4. **calculate_irr** - Internal Rate of Return for regular cash flows
5. **calculate_xnpv** - NPV for irregular cash flows with dates
6. **calculate_xirr** - IRR for irregular cash flows with dates
7. **calculate_payment** - Loan or annuity payment calculations
8. **calculate_annuity_pv** - Present value of an annuity
9. **calculate_annuity_fv** - Future value of an annuity

### Time Series Tools (6 tools)

1. **create_time_series** - Create a time series from periods and values
2. **calculate_growth_rate** - Simple growth rate between two values
3. **calculate_cagr** - Compound Annual Growth Rate
4. **time_series_statistics** - Descriptive statistics (mean, median, std dev, min, max)
5. **calculate_moving_average** - Moving average with configurable window
6. **aggregate_time_series** - Aggregate data (sum, mean, min, max)

### Forecasting Tools (8 tools)

1. **fit_linear_trend** - Fit linear trend model (constant rate of change)
2. **fit_exponential_trend** - Fit exponential trend (accelerating growth)
3. **fit_logistic_trend** - Fit logistic S-curve (growth approaching capacity)
4. **forecast_trend** - Project fitted trend forward
5. **calculate_seasonal_indices** - Extract seasonal patterns from data
6. **seasonally_adjust** - Remove seasonality to reveal underlying trend
7. **decompose_time_series** - Break down into trend, seasonal, and residual components
8. **forecast_with_seasonality** - Complete forecast combining trend + seasonal patterns

### Debt & Financing Tools (6 tools)

1. **create_amortization_schedule** - Generate full loan payment schedule
2. **calculate_wacc** - Weighted Average Cost of Capital
3. **calculate_capm** - Capital Asset Pricing Model (cost of equity)
4. **calculate_dscr** - Debt Service Coverage Ratio
5. **calculate_altman_z_score** - Bankruptcy prediction model
6. **compare_financing_options** - Compare multiple financing alternatives

### Statistical Analysis Tools (7 tools)

1. **calculate_correlation** - Pearson correlation coefficient between datasets
2. **linear_regression** - Fit linear model with slope, intercept, and R²
3. **spearmans_correlation** - Non-parametric rank correlation (Spearman's rho)
4. **calculate_confidence_interval** - Confidence intervals for population parameters
5. **calculate_covariance** - Covariance between two datasets
6. **calculate_z_score** - Z-score for testing correlation significance
7. **descriptive_stats_extended** - Comprehensive statistics (skewness, quartiles, IQR)

### Monte Carlo Simulation Tools (7 tools)

1. **create_distribution** - Create probability distributions (normal, uniform, triangular, etc.)
2. **run_monte_carlo** - Run Monte Carlo simulation with multiple uncertain inputs
3. **analyze_simulation_results** - Comprehensive analysis of simulation outcomes
4. **calculate_value_at_risk** - Value at Risk (VaR) and Conditional VaR calculations
5. **calculate_probability** - Calculate probabilities from simulation results
6. **sensitivity_analysis** - Single-variable sensitivity analysis
7. **tornado_analysis** - Multi-variable sensitivity ranking (tornado diagram)

### Optimization Tools (4 tools)

1. **solve_linear_program** - Solve linear programming problems using the Simplex method (maximize/minimize linear objectives subject to linear constraints)
2. **optimize_capital_allocation** - Allocate limited capital across projects to maximize NPV using greedy or optimal (integer programming) methods
3. **newton_raphson_optimize** - Find values where a function equals a target (goal seek, root-finding)
4. **gradient_descent_optimize** - Find maximum or minimum of multi-variable functions

### Adaptive Optimization Tools (2 tools) - Phase 7

1. **adaptive_optimize** - Automatically select and run the best optimization algorithm for your problem based on characteristics (size, constraints, preferences)
2. **analyze_optimization_problem** - Analyze optimization problem characteristics and get algorithm recommendations before solving

### Performance Benchmark Tools (3 tools) - Phase 7

1. **profile_optimizer** - Profile performance of a single optimization algorithm with statistical analysis (timing, success rate, consistency)
2. **compare_optimizers** - Compare performance of multiple optimization algorithms side-by-side with rankings and recommendations
3. **benchmark_guide** - Comprehensive guidance on performance benchmarking best practices, interpretation, and troubleshooting

### Advanced Optimization Tools (4 tools) - Phase 6.3

1. **optimize_multiperiod** - Optimize decisions across multiple time periods with discount factors and inter-temporal constraints (capital budgeting, portfolio rebalancing, production planning over time)
2. **optimize_stochastic** - Optimize under uncertainty using Monte Carlo Sample Average Approximation (portfolio with uncertain returns, production with demand uncertainty)
3. **optimize_robust** - Min-max optimization for worst-case protection (conservative planning, risk management, guaranteed performance)
4. **optimize_scenarios** - Optimize across discrete future scenarios with probabilities (strategic planning, decision trees, contingency planning)

### Integer Programming Tools (2 tools) - Phase 6.2

1. **solve_integer_program** - Solve integer and mixed-integer programming problems using branch-and-bound (project selection, resource allocation with discrete units, capital budgeting with integer constraints, facility location decisions)
2. **solve_with_cutting_planes** - Solve integer programs using branch-and-cut (branch-and-bound enhanced with cutting planes: Gomory cuts, mixed-integer rounding cuts, cover cuts for knapsack constraints - often 10-100x faster than pure branch-and-bound)

## Installation & Setup

### Building the Server

```bash
# From the BusinessMath directory
swift build

# The executable will be at:
# .build/arm64-apple-macosx/debug/businessmath-mcp-server
```

### Configuring Claude Desktop

Add the server to your Claude Desktop configuration file:

**macOS/Linux**: `~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "businessmath": {
      "command": "/Users/jpurnell/Dropbox/Computer/Development/Swift/Playgrounds/Math/BusinessMath/.build/arm64-apple-macosx/debug/businessmath-mcp-server",
      "args": []
    }
  }
}
```

**Note**: Update the path to match your actual build directory location.

### Verifying Installation

1. Restart Claude Desktop
2. Look for the MCP server icon (🔌) in Claude's interface
3. The BusinessMath server should appear in the list of available servers
4. You should see 167 tools available

## Usage Examples

Once configured, you can ask Claude to use these tools directly:

### Example 1: Calculate NPV for an Investment

```
User: I'm considering an investment that costs $100,000 upfront and will
generate $30,000 per year for 5 years. Using a 10% discount rate, what's
the NPV?
```

Claude will use the `calculate_npv` tool with:
- rate: 0.10
- cashFlows: [-100000, 30000, 30000, 30000, 30000, 30000]

### Example 2: Calculate Loan Payments

```
User: What would my monthly payment be on a $350,000 mortgage at 6.5%
annual interest for 30 years?
```

Claude will use the `calculate_payment` tool with:
- presentValue: 350000
- rate: 0.065/12 (monthly rate)
- periods: 360 (30 years * 12 months)
- type: "ordinary"

### Example 3: Calculate CAGR

```
User: My investment grew from $50,000 to $125,000 over 8 years.
What was the compound annual growth rate?
```

Claude will use the `calculate_cagr` tool with:
- beginningValue: 50000
- endingValue: 125000
- periods: 8

### Example 4: Revenue Forecasting with Seasonality

```
User: I have quarterly sales data for 2022-2024. Can you forecast 2025
sales accounting for seasonal patterns?
```

Claude will:
1. Create a time series with `create_time_series`
2. Calculate seasonal indices with `calculate_seasonal_indices`
3. Decompose the data with `decompose_time_series`
4. Create forecast with `forecast_with_seasonality`

### Example 5: Loan Amortization Schedule

```
User: Show me the full amortization schedule for a $250,000 mortgage
at 6.75% for 30 years with monthly payments.
```

Claude will use `create_amortization_schedule` with showFullSchedule option.

### Example 6: Cost of Capital Analysis

```
User: Calculate WACC for a company with $500M equity (12% cost),
$300M debt (5% cost), and 25% tax rate.
```

Claude will use `calculate_wacc` to determine the weighted average cost
of capital.

### Example 7: Statistical Analysis

```
User: I have advertising spend and revenue data. Is there a correlation
between them? Can you build a regression model?
```

Claude will:
1. Use `calculate_correlation` to measure the relationship strength
2. Apply `linear_regression` to build a predictive model
3. Calculate R² to assess goodness of fit

### Example 8: Monte Carlo Simulation

```
User: I'm planning a project with uncertain costs ($800K-$1.2M, most likely $1M)
and revenues (normally distributed, mean $1.5M, std dev $200K). What's the
probability of making a profit? What's the worst-case scenario at 95% confidence?
```

Claude will:
1. Use `create_distribution` to set up triangular (costs) and normal (revenue) distributions
2. Run `run_monte_carlo` with calculation "revenue - costs" for 10,000 iterations
3. Use `calculate_probability` to find P(profit > 0)
4. Apply `calculate_value_at_risk` to determine the 95% VaR

### Example 9: Sensitivity Analysis

```
User: My profit formula is Revenue - Costs - Marketing. Revenue is $1M,
Costs are $600K, Marketing is $100K. Which variable has the biggest impact
if they each vary by ±20%?
```

Claude will use `tornado_analysis` to rank variables by their impact on profit.

## Tool Details

### Time Value of Money Tools

All TVM tools return formatted results with:
- Currency formatting for monetary values
- Percentage formatting for rates
- Clear decision guidance (for NPV/IRR)

#### NPV Example Output

```
Net Present Value (NPV) Analysis:
• Discount Rate: 10.00%
• Number of Periods: 6
• Cash Flows:
  Period 0: -$100,000.00
  Period 1: $30,000.00
  Period 2: $30,000.00
  Period 3: $30,000.00
  Period 4: $30,000.00
  Period 5: $30,000.00

• Net Present Value: $13,723.60
• Decision: ✓ Accept (positive NPV)
```

#### Payment Calculation Example Output

```
Loan/Annuity Payment Calculation:
• Loan Amount: $350,000.00
• Interest Rate: 0.54% per period
• Number of Periods: 360
• Payment Type: Ordinary

• Periodic Payment: $2,212.75
• Total Payments: $796,590.00
• Total Interest: $446,590.00
```

### Time Series Tools

Time series tools support multiple period types:
- **Daily** - Individual days
- **Monthly** - Calendar months
- **Quarterly** - Calendar quarters
- **Annual** - Calendar years

#### Time Series Input Format

```json
{
  "data": [
    {
      "period": {
        "year": 2024,
        "month": 1,
        "type": "monthly"
      },
      "value": 125000
    },
    {
      "period": {
        "year": 2024,
        "month": 2,
        "type": "monthly"
      },
      "value": 142000
    }
  ]
}
```

## Architecture

### Components

- **MCPProtocol.swift** - JSON-RPC 2.0 and MCP protocol types
- **StdioTransport.swift** - stdio-based message transport
- **MCPServer.swift** - Main server implementation
- **ToolRegistry.swift** - Tool registration and execution
- **TypeMarshalling.swift** - JSON ↔ Swift type conversion
- **Tools/** - Individual tool implementations

### Extending the Server

To add new tools:

1. Create a new struct implementing `MCPToolHandler`:

```swift
public struct MyNewTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "my_new_tool",
        description: "Description of what the tool does",
        inputSchema: MCPToolInputSchema(
            properties: [
                "param1": MCPSchemaProperty(
                    type: "number",
                    description: "First parameter"
                )
            ],
            required: ["param1"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let param1 = try args.getDouble("param1")

        // Perform calculation using BusinessMath library
        let result = someBusinessMathFunction(param1)

        return .success(text: "Result: \(result)")
    }
}
```

2. Add tool to the server in `main.swift`:

```swift
await server.registerTool(MyNewTool())
```

3. Rebuild: `swift build`

## Troubleshooting

### Server Won't Start

1. **Check build**: Ensure `swift build` completes without errors
2. **Check path**: Verify the executable path in `claude_desktop_config.json`
3. **Check permissions**: Ensure the executable has execute permissions
   ```bash
   chmod +x .build/arm64-apple-macosx/debug/businessmath-mcp-server
   ```

### Tools Not Appearing

1. **Restart Claude Desktop** completely
2. **Check logs**: Look in Claude Desktop's developer console
3. **Verify configuration**: Ensure JSON is valid in config file

### Tool Execution Errors

- Check the error message returned by the tool
- Common issues:
  - Wrong parameter types (e.g., string instead of number)
  - Missing required parameters
  - Invalid period specifications in time series

## Future Enhancements

Potential additions to the MCP server:

- **Scenario Analysis Tools** (6 tools) - Multi-scenario comparison, best/worst/base case modeling, decision trees
- **Financial Statement Tools** (10 tools) - Balance sheets, income statements, ratio analysis, DuPont analysis
- **Portfolio Optimization** (6-8 tools) - Mean-variance optimization, efficient frontier, Sharpe ratio, portfolio VaR
- **Options & Derivatives** (6-8 tools) - Black-Scholes, Greeks, option strategies, implied volatility
- **Resource Management** - Stateful workflows for complex multi-step analyses
- **Equity & Cap Table Tools** - Startup financing, dilution analysis, option grants, waterfall analysis

## Technical Details

- **Protocol**: MCP (Model Context Protocol) 2024-11-05
- **Transport**: JSON-RPC 2.0 over stdio
- **Language**: Swift 6.0 with strict concurrency
- **Dependencies**: BusinessMath 1.12.0, Swift Numerics
- **Platform**: macOS (arm64)

## License

Same as BusinessMath library.

## Support

For issues or questions:
- BusinessMath library issues: BusinessMath GitHub repository
- MCP server issues: Create an issue in the BusinessMath repository with `[MCP]` prefix

---

**Version**: 1.6.0 (167 tools)
**Last Updated**: December 11, 2025

## Changelog

### Version 1.6.0 (December 11, 2025) - Phase 6.2: Integer Programming
- 🔢 Added Integer Programming tools: branch-and-bound, branch-and-cut with cutting planes
- ✂️ Cutting plane generation: Gomory fractional cuts, mixed-integer rounding cuts, cover cuts
- 🌳 Branch-and-cut solver: combines branch-and-bound with cutting planes for 10-100x speedups
- 📊 Educational tools: comprehensive Swift implementation guides, problem-specific patterns
- 📈 Total tools increased from 165 → 167 tools (2 new Phase 6.2 tools)
- 🎯 Complete integer and mixed-integer programming capabilities for discrete optimization

### Version 1.5.0 (December 11, 2025) - Phase 6.3: Advanced Optimization
- 📅 Added Multi-Period Optimization: time-varying decisions with discount factors and inter-temporal constraints
- 🎲 Added Stochastic Optimization: optimize under uncertainty using Sample Average Approximation (SAA)
- 🛡️ Added Robust Optimization: min-max optimization for worst-case protection and guaranteed performance
- 🌲 Added Scenario-Based Optimization: optimize across discrete future scenarios with probabilities
- 📈 Total tools increased from 124 → 128 tools (4 new Phase 6.3 tools)
- 🎯 Complete "intelligence layer" for real-world planning under time and uncertainty

### Version 1.4.0 (December 11, 2025) - Phase 7: Performance & Scale
- 🤖 Added Adaptive Optimization (2 tools): automatic algorithm selection, problem analysis
- 📊 Added Performance Benchmarking (3 tools): optimizer profiling, comparison, comprehensive guides
- 📈 Total tools increased from 119 → 124 tools
- 🎯 Intelligent optimization with automatic algorithm selection based on problem characteristics
- 📉 Statistical performance analysis and optimizer comparison framework

### Version 1.3.0 (December 11, 2025)
- ✨ Added Linear Programming solver (solve_linear_program) using Simplex method
- 🔧 Enhanced optimize_capital_allocation to use integer programming for guaranteed optimal solutions
- 📈 Total tools increased from 118 → 119 tools
- 🎯 Full optimization capabilities including LP, Integer Programming (via CapitalAllocationOptimizer)

### Version 1.2.0 (October 29, 2024)
- ✨ Added 7 Statistical Analysis tools (correlation, regression, covariance, confidence intervals, z-scores)
- ✨ Added 7 Monte Carlo Simulation tools (distributions, simulation, VaR, sensitivity, tornado analysis)
- 📈 Total tools increased from 29 → 118 tools
- 🎯 Comprehensive risk analysis and probabilistic modeling capabilities
- 📝 New usage examples for statistical and simulation workflows

### Version 1.1.0 (October 29, 2024)
- ✨ Added 8 Forecasting tools (trend fitting, seasonal decomposition, forecasting)
- ✨ Added 6 Debt & Financing tools (amortization, WACC, CAPM, DSCR, Z-Score, comparison)
- 📈 Total tools increased from 15 → 29 tools
- 📝 Enhanced documentation with new usage examples

### Version 1.0.0 (October 29, 2024)
- 🎉 Initial release with 15 tools
- ⚡ 9 TVM tools (NPV, IRR, PV, FV, payments, annuities)
- 📊 6 Time Series tools (creation, statistics, aggregation, moving averages)

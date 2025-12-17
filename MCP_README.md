# BusinessMath MCP Server

A comprehensive **Model Context Protocol (MCP) server** that exposes all BusinessMath functionality to AI assistants like Claude Desktop, enabling natural language financial analysis, modeling, and advanced analytics.

## Overview

The BusinessMath MCP server provides AI assistants with access to **167 computational tools** across 32 categories, **14 comprehensive resources**, and **6 guided workflow templates**. This enables powerful financial analysis through natural language.

### What is MCP?

The Model Context Protocol (MCP) is an open standard that enables AI assistants to safely access external tools and data sources. The BusinessMath MCP server implements this protocol to provide financial and quantitative analysis capabilities.

## What's Included

### 🔧 167 Computational Tools

**Time Value of Money** (9 tools):
- NPV, IRR, Modified IRR (MIRR)
- Present Value (PV), Future Value (FV)
- Payment calculations (PMT)
- Annuities (ordinary and due)
- XNPV, XIRR (irregular cash flows)

**Time Series Analysis** (6 tools):
- Growth rates (simple and compound)
- Moving averages
- CAGR calculations
- Time series comparisons

**Forecasting** (8 tools):
- Trend analysis (linear, exponential, logistic)
- Seasonal adjustment
- Time series decomposition
- Revenue projections

**Debt & Financing** (6 tools):
- Loan amortization
- WACC (Weighted Average Cost of Capital)
- CAPM (Capital Asset Pricing Model)
- Debt coverage ratios

**Statistical Analysis** (7 tools):
- Correlation analysis
- Linear regression
- Confidence intervals
- Z-scores and standardization

**Monte Carlo Simulation** (7 tools):
- Risk modeling
- 15 probability distributions
- Sensitivity analysis
- Portfolio simulation

**Hypothesis Testing** (6 tools):
- T-tests (one-sample, two-sample, paired)
- Chi-square tests
- F-tests
- Sample size calculations
- A/B testing
- P-value calculations

**Advanced Statistics** (13 tools):
- Combinatorics (permutations, combinations)
- Statistical means (arithmetic, geometric, harmonic)
- Goal seek
- Data tables (one-way and two-way)
- What-if analysis

**Probability Distributions** (15 distributions):
- Normal, Uniform, Triangular
- Exponential, Lognormal
- Beta, Gamma, Weibull
- Chi-Squared, F, T
- Pareto, Logistic
- Geometric, Rayleigh

**Optimization & Solvers** (8 tools):
- Newton-Raphson method
- Gradient descent
- Capital allocation optimization
- Adaptive algorithm selection (2 tools)
- Performance benchmarking (3 tools)

**Integer Programming** (2 tools):
- Branch-and-bound algorithm
- Branch-and-cut with cutting planes:
  - Gomory cuts
  - Mixed-Integer Rounding (MIR)
  - Cover cuts

**Portfolio Optimization** (3 tools):
- Modern Portfolio Theory (MPT)
- Efficient frontier calculation
- Risk parity allocation

**Real Options** (5 tools):
- Black-Scholes option pricing
- Binomial tree models
- Option Greeks (Delta, Gamma, Vega, Theta, Rho)
- Expansion option valuation
- Abandonment option valuation

**Risk Analytics** (4 tools):
- Stress testing
- Value at Risk (VaR)
- Conditional VaR (CVaR)
- Risk aggregation
- Comprehensive risk metrics

**Financial Ratios** (9 tools):
- Asset turnover
- Current ratio
- Quick ratio (acid-test)
- Debt-to-Equity ratio
- Interest coverage
- Inventory turnover
- Profit margin
- Return on Equity (ROE)
- Return on Investment (ROI)

**Bayesian Statistics** (1 tool):
- Bayes' theorem with posterior probability calculations

**Valuation Calculators** (12 tools):
- Earnings Per Share (EPS)
- Book Value Per Share (BVPS)
- Price-to-Earnings (P/E)
- Price-to-Book (P/B)
- Price-to-Sales (P/S)
- Market capitalization
- Enterprise Value (EV)
- EV/EBITDA
- EV/Sales
- Working capital
- Debt-to-Assets ratio
- Free Cash Flow (FCF)

**Investment Metrics** (4 tools):
- Profitability Index (PI)
- Payback Period
- Discounted Payback Period
- Modified Internal Rate of Return (MIRR)

**Loan Payment Analysis** (4 tools):
- Principal payment (PPMT)
- Interest payment (IPMT)
- Cumulative interest
- Cumulative principal

**Growth Analysis** (2 tools):
- Simple growth rate
- Compound growth projections (various frequencies)

**Trend Forecasting** (4 tools):
- Linear trend fitting
- Exponential trend fitting
- Logistic trend fitting
- Time series decomposition

**Seasonality** (3 tools):
- Calculate seasonal indices
- Seasonally adjust data
- Apply seasonal patterns to forecasts

**Advanced Options** (2 tools):
- Option Greeks calculator
- Binomial tree pricing (American & European)

**Equity Valuation** (5 tools):
- Free Cash Flow to Equity (FCFE) model
- Gordon Growth Model / Dividend Discount Model (DDM)
- Two-Stage DDM
- H-Model DDM
- Enterprise Value Bridge
- Residual Income Model

**Bond Valuation** (7 tools):
- Bond pricing (coupon bonds, zero-coupon)
- Yield calculation (current yield, YTM)
- Duration & Convexity
- Macaulay Duration
- Modified Duration
- Callable bond pricing
- Option-Adjusted Spread (OAS)
- Credit spread analysis

**Credit Derivatives** (4 tools):
- CDS pricing & spread calculation
- Merton structural credit model
- Hazard rate modeling
- Credit term structure bootstrapping

### 📚 14 Resources

Comprehensive documentation accessible via `resources/read`:

1. **Time Value of Money** - Formulas and examples for NPV, IRR, PV, FV
2. **Statistical Analysis** - Reference guide for correlation, regression, hypothesis testing
3. **Monte Carlo Simulation** - Guide to risk modeling and uncertainty quantification
4. **Forecasting Techniques** - Trend analysis, seasonality, and projection methods
5. **Optimization and Solvers** - Newton-Raphson, gradient descent, capital allocation
6. **Portfolio Optimization** - Modern Portfolio Theory and efficient frontier
7. **Real Options Valuation** - Black-Scholes, binomial trees, and flexibility analysis
8. **Risk Analytics and Stress Testing** - VaR, CVaR, and scenario analysis
9. **Investment Analysis Examples** - NPV, IRR, payback, profitability index
10. **Loan Amortization Examples** - Payment schedules and analysis
11. **Financial Glossary** (JSON) - Comprehensive terminology reference
12. **Distribution Reference** - Guide to all 15 probability distributions
13. **Equity Valuation Guide** - DDM, FCFE, and residual income models
14. **Bond Valuation Guide** - Pricing, duration, convexity, and credit analysis

### 🎯 6 Prompt Templates

Guided workflows for common analysis tasks:

1. **Investment Analysis** - Evaluate investment opportunities with NPV, IRR, and sensitivity
2. **Financing Comparison** - Compare debt vs equity financing options
3. **Risk Assessment** - Quantify portfolio risk with VaR and stress testing
4. **Revenue Forecasting** - Project future revenue with trend and seasonality
5. **Portfolio Analysis** - Optimize asset allocation for risk/return
6. **Debt Analysis** - Analyze loan terms, payments, and amortization

## Quick Start

### Installation

**1. Build the MCP server:**
```bash
cd /path/to/BusinessMath
swift build -c release
```

The executable will be created at `.build/release/businessmath-mcp-server`

**2. Configure Claude Desktop:**

Edit your Claude Desktop configuration file:
- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

Add the BusinessMath server:

```json
{
  "mcpServers": {
    "businessmath": {
      "command": "/path/to/BusinessMath/.build/release/businessmath-mcp-server"
    }
  }
}
```

Replace `/path/to/BusinessMath` with the actual path to your BusinessMath directory.

**3. Restart Claude Desktop**

The server will start automatically when you open Claude Desktop.

### Verifying Installation

After restarting Claude Desktop, you should see a small tool icon (🔨) in the interface indicating MCP servers are connected. You can verify the BusinessMath server is working by asking:

> "What financial analysis tools do you have available?"

Claude should list the BusinessMath capabilities.

## Usage Examples

### Natural Language Queries

The beauty of the MCP server is that you can use natural language for complex financial calculations:

**Investment Analysis:**
```
Calculate the NPV of an investment with initial cost $100,000 and
annual returns of $30,000 for 5 years at 10% discount rate
```

**Mortgage Calculations:**
```
What's the monthly payment on a $300,000 mortgage at 6% APR for 30 years?
```

```
Break down the first payment - how much is principal vs interest?
```

**Portfolio Optimization:**
```
Optimize a portfolio across 3 assets with expected returns [0.08, 0.12, 0.10]
and volatilities [0.15, 0.25, 0.18] to maximize Sharpe ratio
```

**Monte Carlo Simulation:**
```
Run a Monte Carlo simulation with 10,000 iterations for revenue
with normal distribution (mean: $1M, stddev: $200K)
```

**Forecasting:**
```
Forecast my quarterly revenue using exponential trend with
historical data: [100, 120, 145, 175]
```

**Seasonal Analysis:**
```
Calculate seasonal indices for my monthly sales data with annual seasonality:
[100, 95, 105, 110, 120, 115, 125, 130, 135, 125, 140, 150]
```

**Options Pricing:**
```
Calculate the option Greeks for a call option with spot $100,
strike $105, 6 months to expiry, 20% volatility, and 5% risk-free rate
```

**Integer Programming:**
```
Solve a knapsack problem with 5 items using branch-and-bound:
weights [2, 3, 4, 5, 6], values [3, 4, 5, 6, 7], capacity 10
```

**Securities Valuation:**
```
Value a stock with current dividend $2.50, 5% growth rate,
and 12% required return using Gordon Growth Model
```

```
Price a 5-year corporate bond with $1,000 face value,
5% annual coupon, and 6% market yield
```

```
Calculate the fair CDS spread for a $10M notional with
2% default probability, 40% recovery, and 5-year tenor
```

### Complex Workflows

You can chain multiple operations together:

```
I have an investment with these cash flows: [-100000, 30000, 40000, 50000, 60000]

1. Calculate the NPV at 10% discount rate
2. Calculate the IRR
3. Calculate the profitability index
4. Calculate the payback period
5. Run a sensitivity analysis varying the discount rate from 5% to 15%
```

Claude will execute each tool in sequence and provide a comprehensive analysis.

## Transport Modes

### stdio Mode (Recommended)

The default transport mode uses standard input/output. This is the recommended mode for Claude Desktop and provides the best reliability and performance.

**Pros:**
- Most reliable
- Officially supported by Anthropic
- Best performance
- Automatic lifecycle management

**Configuration:**
```json
{
  "mcpServers": {
    "businessmath": {
      "command": "/path/to/.build/release/businessmath-mcp-server"
    }
  }
}
```

### HTTP Mode (Experimental)

An experimental HTTP transport mode is also available for web-based integrations:

```bash
.build/release/businessmath-mcp-server --http 8080
```

**⚠️ Important Limitations:**
- HTTP mode is experimental and not officially supported by Anthropic
- Not all MCP clients support HTTP transport
- Claude Desktop requires stdio mode
- CORS restrictions may apply
- Additional network security considerations

See [HTTP_MODE_README.md](HTTP_MODE_README.md) for detailed HTTP mode documentation.

**For production use, stdio mode is strongly recommended.**

## Technical Details

### Architecture

- **Built with**: Official MCP Swift SDK (v0.10.2)
- **Language**: Swift 6.0
- **Concurrency**: Full Swift 6 strict concurrency checking for thread safety
- **Platform**: macOS 13.0+ (MCP server requirement)

### MCP Capabilities

The BusinessMath server implements all core MCP capabilities:

- ✅ **Tools** - 167 computational tools for financial analysis
- ✅ **Resources** - 14 comprehensive documentation resources
- ✅ **Prompts** - 6 guided workflow templates
- ✅ **Logging** - Comprehensive error handling and logging

### Error Handling

The server provides detailed error messages for:
- Invalid input parameters
- Calculation errors (e.g., division by zero)
- Convergence failures (e.g., IRR not converging)
- Type mismatches
- Missing required parameters

### Performance

All calculations are optimized for interactive use:
- Simple calculations (NPV, IRR): < 1ms
- Complex operations (Monte Carlo): < 100ms for 10k iterations
- Optimization algorithms: < 500ms for typical problems

## Troubleshooting

### Server Not Starting

**Check executable path:**
```bash
ls -la /path/to/.build/release/businessmath-mcp-server
```

**Check permissions:**
```bash
chmod +x /path/to/.build/release/businessmath-mcp-server
```

**Test server directly:**
```bash
/path/to/.build/release/businessmath-mcp-server
```

Should output JSON messages (MCP protocol messages).

### Tools Not Appearing in Claude

1. **Restart Claude Desktop** - Changes to config require restart
2. **Check Claude Desktop logs** - Look for connection errors
3. **Verify JSON syntax** - Use a JSON validator on your config file
4. **Check paths** - Ensure absolute paths (not relative)

### Calculation Errors

Most calculation errors include detailed messages:
- "IRR calculation did not converge" - Try different initial guess
- "Cash flows must start negative" - Verify cash flow sign convention
- "Division by zero" - Check for zero denominators in ratios

## Advanced Usage

### Custom Workflows

You can create sophisticated analyses by combining multiple tools:

**Example: Complete Investment Due Diligence**

1. Calculate base metrics (NPV, IRR, PI, payback)
2. Run sensitivity analysis on discount rate
3. Run Monte Carlo simulation for revenue uncertainty
4. Calculate risk metrics (VaR, CVaR)
5. Compare to alternative investments
6. Generate recommendation

Claude can orchestrate this entire workflow from a single prompt.

### Integration with Other Tools

The MCP protocol allows BusinessMath to work alongside other MCP servers:

- **Data sources**: Read financial data from databases or APIs
- **Visualization**: Send results to plotting tools
- **Reporting**: Format results for presentation
- **Automation**: Chain analysis workflows

### Resource Access

Access comprehensive documentation through resources:

```
Show me the Time Value of Money resource
```

```
What distributions are available for Monte Carlo simulation?
```

```
Show me examples of portfolio optimization
```

## Comparison to Direct Library Usage

### When to Use the MCP Server

**Advantages:**
- ✅ Natural language interface
- ✅ No code required
- ✅ Interactive exploration
- ✅ Quick prototyping
- ✅ Educational use

**Use cases:**
- Ad-hoc analysis
- Learning financial concepts
- Quick calculations
- Exploratory analysis

### When to Use the Swift Library Directly

**Advantages:**
- ✅ Full programmatic control
- ✅ Type safety
- ✅ Performance optimization
- ✅ Custom workflows
- ✅ Production applications

**Use cases:**
- Production applications
- Batch processing
- Custom integrations
- Performance-critical code
- Complex custom models

## Security Considerations

### Data Privacy

- All calculations run locally on your machine
- No data is sent to external servers (except Claude API communication)
- Financial data never leaves your computer
- No network access required for calculations

### Input Validation

The server performs comprehensive input validation:
- Type checking (numbers, dates, arrays)
- Range validation (positive values, percentages 0-1)
- Array length checking
- Parameter presence validation

### Sandboxing

The server operates in a restricted environment:
- Read-only access to BusinessMath library code
- No file system access (except for bundled resources)
- No network access (except MCP protocol)
- No system command execution

## Contributing

Contributions to the MCP server are welcome! Areas for enhancement:

- **Additional tools** - New financial calculations
- **More resources** - Enhanced documentation
- **Better prompts** - Improved guided workflows
- **Testing** - Integration tests with MCP clients
- **Documentation** - Usage examples and tutorials

See the main [README.md](README.md) for contribution guidelines.

## Version History

### v1.6.0 - Integer Programming
- Added branch-and-bound optimization
- Added branch-and-cut with cutting planes (Gomory, MIR, cover cuts)
- Enhanced optimization tools

### v1.4.0 - Securities Valuation
- 📈 Equity valuation (5 tools)
- 📊 Bond valuation (7 tools)
- 🔒 Credit derivatives (4 tools)
- 3 comprehensive tutorials

### v1.3.0 - Advanced Statistics & Optimization
- Monte Carlo simulation (7 tools)
- Hypothesis testing (6 tools)
- Advanced statistics (13 tools)
- Portfolio optimization (3 tools)

See [CHANGELOG.md](CHANGELOG.md) for complete version history.

## Related Documentation

- **[Main README](README.md)** - Library overview and Swift API
- **[CHANGELOG](CHANGELOG.md)** - Detailed version history
- **[HTTP Mode](HTTP_MODE_README.md)** - HTTP transport documentation
- **[Performance](Examples/PERFORMANCE.md)** - Performance benchmarks
- **[Documentation](Sources/BusinessMath/BusinessMath.docc/)** - Comprehensive guides

## Support

- **Issues**: Report problems via [GitHub Issues](https://github.com/jpurnell/BusinessMath/issues)
- **Discussions**: Ask questions in [GitHub Discussions](https://github.com/jpurnell/BusinessMath/discussions)
- **MCP Protocol**: [Official MCP Documentation](https://modelcontextprotocol.io)

---

**Built with the official MCP Swift SDK • Swift 6.0 • Made with ❤️**

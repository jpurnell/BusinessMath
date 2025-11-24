The following list details the 50 tools that were identified as missing definitions required to complete the total planned suite of 118 computational tools. This list is categorized by the corresponding project topic where the features are defined (Topics 5, 6, 7, 8, 9, and 10).

# Missing MCP Tool Definitions (50 Tools)

### I. Financial Ratios & Metrics (Topic 5)

| Tool Name (Inferred) | Description |
| :--- | :--- |
| `calculate_return_on_assets` | Calculates ROA (Return on Assets) [1]. |
| `calculate_return_on_invested_capital` | Calculates ROIC (Return on Invested Capital) [1]. |
| `calculate_receivables_turnover` | Calculates the receivables turnover ratio [1]. |
| `calculate_cash_ratio` | Calculates the conservative cash ratio [1]. |
| `calculate_debt_ratio` | Calculates the debt ratio (Total Debt / Total Assets) [2, 3]. |
| `calculate_days_inventory_outstanding` | Calculates DIO (Days Inventory Outstanding) [1, 2]. |
| `calculate_days_sales_outstanding` | Calculates DSO (Days Sales Outstanding) [1, 2]. |
| `calculate_days_payable_outstanding` | Calculates DPO (Days Payable Outstanding) [1]. |
| `calculate_cash_conversion_cycle` | Calculates the Cash Conversion Cycle (DIO + DSO - DPO) [1]. |
| `calculate_dupont_3way` | Decomposes ROE using the 3-Way DuPont formula [1]. |
| `calculate_dupont_5way` | Decomposes ROE using the 5-Way DuPont formula [1]. |
| `calculate_piotroski_f_score` | Calculates the 9-point Piotroski F-Score for fundamental strength [1]. |

### II. Debt & Financing Models (Topic 6)

| Tool Name (Inferred) | Description |
| :--- | :--- |
| `calculate_beta_levering` | Levering the beta coefficient for capital structure analysis [4]. |
| `calculate_beta_unlevering` | Unlevering the beta coefficient [4]. |
| `optimize_capital_structure` | Solves for the optimal debt-to-equity ratio that minimizes WACC [1]. |
| `calculate_post_money_valuation` | Calculates company valuation after a financing round [1]. |
| `calculate_dilution_percentage` | Calculates shareholder dilution from new financing [1, 5]. |
| `model_safe_conversion` | Models the conversion of SAFEs (Simple Agreement for Future Equity) into equity [1, 6]. |
| `run_liquidation_waterfall` | Analyzes capital distribution across shareholders upon liquidation [1]. |
| `check_debt_covenant` | Automated checking of debt covenant compliance [5]. |
| `analyze_lease_liability` | Calculates the Right-of-Use (ROU) asset and lease liability under IFRS 16 / ASC 842 [1, 5]. |
| `calculate_custom_payment_schedule` | Generates amortization schedule for custom debt instruments (e.g., bullet loans) [1, 7]. |

### III. Architecture & Developer Tools (Topics 7 & 8)

| Tool Name (Inferred) | Description |
| :--- | :--- |
| `list_revenue_sources` | Enumerates all defined revenue streams in a model [8]. |
| `list_cost_drivers` | Categorizes fixed versus variable cost drivers [8]. |
| `identify_unused_components` | Detects scenarios or accounts that are never referenced in a calculation [8]. |
| `validate_model_structure` | Performs comprehensive structural checks on the financial model [9, 10]. |
| `trace_calculation_lineage` | Tracks the calculation steps and input sources for a specific value (Audit Trail) [9, 11]. |
| `detect_circular_dependency` | Checks for circular references in account formulas [10, 12]. |
| `get_model_audit_history` | Retrieves the complete change history for a model definition [9]. |
| `export_financial_model_csv` | Exports a complete financial model's data into CSV format [13-15]. |
| `export_financial_model_json` | Exports the model definition and data to JSON format [13, 14]. |
| `compare_two_models` | Compares two financial models side-by-side by key metrics [8]. |
| `run_performance_profiler` | Benchmarks calculation time and memory usage for debugging [16]. |

### IV. Time Series & Advanced Analytics (Topic 9)

| Tool Name (Inferred) | Description |
| :--- | :--- |
| `forecast_holt_winters` | Performs Holt-Winters triple exponential smoothing for seasonal forecasting [17]. |
| `detect_time_series_anomaly` | Detects anomalies, outliers, or unusual patterns in time series data [18]. |
| `fit_ml_forecast_model` | Fits an arbitrary machine learning model (e.g., neural net) for forecasting [18]. |
| `calculate_rolling_sum` | Calculates the rolling/moving sum of values over a specified window [19]. |
| `calculate_rolling_min` | Calculates the rolling/moving minimum over a specified window [20]. |
| `calculate_rolling_max` | Calculates the rolling/moving maximum over a specified window [20]. |
| `calculate_percent_change` | Calculates the period-over-period percentage change [20]. |

### V. Model Templates & MCP Utilities (Topic 10)

| Tool Name (Inferred) | Description |
| :--- | :--- |
| `load_model_template_saas` | Loads the SaaS (Software as a Service) financial model template [21, 22]. |
| `load_model_template_retail` | Loads the Retail/E-commerce financial model template [21, 22]. |
| `load_model_template_manufacturing` | Loads the Manufacturing financial model template [21, 22]. |
| `load_model_template_subscription` | Loads the Subscription Box model template [21]. |
| `load_model_template_marketplace` | Loads the Marketplace model template [21]. |
| `load_model_template_real_estate` | Loads the Real Estate model template [21]. |
| `load_financial_model_from_json` | Loads and populates a complete financial model from a JSON file [23]. |
| `create_analysis_template` | AI-assisted creation of new analysis templates [23]. |
| `fetch_company_data_preview` | Previews data available from a specified data source [23]. |
| `analyze_budget_vs_actual` | Calculates and compares projected vs actual results [24]. |
| `calculate_ttm_metrics` | Calculates Trailing Twelve Months (TTM) metrics [24]. |
| `render_report_pdf` | Renders a completed analysis result into a PDF file [15, 25]. |
| `render_report_excel` | Renders a completed analysis result into an Excel/CSV file [15, 25]. |

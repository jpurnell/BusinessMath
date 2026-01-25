# Financial Model Ergonomics & Presentation

**Purpose**: Plan improvements to make financial modeling easier to build and understand.

**Date**: 2025-01-13
**Status**: Planning Document

---

## Problem Statement

### Current Pain Points

#### 1. Model Building Complexity
- **Too many manual steps**: Current approach requires extensive code for each model component
- **Driver combination inflexibility**: Hard to change how drivers combine to estimate revenue
- **Account rollup rigidity**: Difficult to customize which accounts roll into liabilities or cash flow
- **Repetitive setup**: Similar patterns repeated for each model (entities, accounts, drivers)
- **High cognitive load**: Developer needs to understand too many implementation details

#### 2. Output Presentation Issues
- **Raw data output**: Current outputs are data-focused, not user-focused
- **No standard formats**: Missing traditional financial statement layouts
- **Poor readability**: Data structures don't match how finance professionals think
- **Quarterly/Annual mismatch**: Difficult to view data at different time aggregations
- **No comparative views**: Hard to see year-over-year or period-over-period changes

---

## Design Principles

### For Ergonomics
1. **Declarative over Imperative**: Define *what* the model is, not *how* to build it
2. **Convention over Configuration**: Smart defaults, customize only what's different
3. **Composable Building Blocks**: Mix and match reusable components
4. **Type Safety**: Leverage Swift's type system to prevent errors
5. **Progressive Disclosure**: Simple cases are simple, complex cases are possible

### For Presentation
1. **Finance-First**: Output should match how accountants/analysts think
2. **Multiple Views**: Same data, different aggregations and formats
3. **Comparative Analysis**: Built-in period comparisons
4. **Export-Ready**: Easy to get data into Excel, PDF, or reporting tools
5. **Visual Hierarchy**: Clear structure with appropriate detail levels

---

## Proposed Solutions

## Part 1: Model Building Ergonomics

### REVISED APPROACH: Data-Driven Model Definition

**Key Requirements Identified**:
1. **Scale across many companies**: Need to analyze hundreds/thousands of companies without writing code for each
2. **Handle varying account names**: Different companies use different terminology
3. **Support multiple data sources**: Yahoo Finance, Bloomberg, CSV, Excel, SQL databases
4. **Template-based**: Reuse model definitions across similar companies

**Solution**: JSON-based model definitions + Plugin architecture for data sources

### A. JSON Model Definition Format

**Concept**: Define models in JSON files that can be stored, versioned, and reused.

```json
{
  "modelDefinition": {
    "name": "Standard 3-Statement Model",
    "version": "1.0",
    "industry": "Technology",
    "dataSources": [
      {
        "id": "primary",
        "type": "yahoo",
        "config": {
          "ticker": "AAPL"
        }
      },
      {
        "id": "supplemental",
        "type": "csv",
        "config": {
          "path": "/data/custom_metrics.csv",
          "keyColumn": "date"
        }
      }
    ],
    "accountMappings": {
      "revenue": {
        "aliases": ["revenue", "total revenue", "net sales", "sales", "top line"],
        "source": "primary",
        "field": "totalRevenue"
      },
      "cogs": {
        "aliases": ["cogs", "cost of revenue", "cost of sales", "direct costs"],
        "source": "primary",
        "field": "costOfRevenue"
      },
      "grossProfit": {
        "aliases": ["gross profit", "gross margin"],
        "source": "calculated",
        "formula": "revenue - cogs"
      },
      "researchAndDevelopment": {
        "aliases": ["r&d", "research and development", "research & development"],
        "source": "primary",
        "field": "researchDevelopment"
      },
      "sellingGeneralAdmin": {
        "aliases": ["sg&a", "sga", "selling general and administrative"],
        "source": "primary",
        "field": "sellingGeneralAdministrative"
      },
      "operatingExpenses": {
        "aliases": ["opex", "operating expenses", "total operating expenses"],
        "source": "calculated",
        "formula": "researchAndDevelopment + sellingGeneralAdmin"
      },
      "ebitda": {
        "aliases": ["ebitda", "operating income"],
        "source": "calculated",
        "formula": "grossProfit - operatingExpenses"
      }
    },
    "statements": {
      "incomeStatement": {
        "sections": [
          {
            "name": "Revenue",
            "accounts": ["revenue"],
            "showTotal": false
          },
          {
            "name": "Cost of Revenue",
            "accounts": ["cogs"],
            "showTotal": false
          },
          {
            "name": "Gross Profit",
            "accounts": ["grossProfit"],
            "showMargin": true,
            "marginBase": "revenue"
          },
          {
            "name": "Operating Expenses",
            "accounts": ["researchAndDevelopment", "sellingGeneralAdmin"],
            "showTotal": true,
            "totalAccount": "operatingExpenses"
          },
          {
            "name": "EBITDA",
            "accounts": ["ebitda"],
            "showMargin": true,
            "marginBase": "revenue"
          }
        ]
      }
    },
    "periods": {
      "type": "quarterly",
      "range": {
        "start": "2023-Q1",
        "end": "2024-Q4"
      }
    }
  }
}
```

**Benefits**:
- ✅ No code required to analyze a new company - just update the ticker
- ✅ Model definitions can be stored in a database or version control
- ✅ Templates can be reused across similar companies
- ✅ Account mapping handles varying terminology
- ✅ Multiple data sources can be combined
- ✅ Easy to expose via MCP tools for AI-driven analysis

### B. Plugin Architecture for Data Sources

**Concept**: Abstract data source interface with implementations for each provider.

```swift
// Core protocol
protocol FinancialDataSource: Sendable {
    /// Unique identifier for this data source type
    static var sourceType: String { get }

    /// Initialize with configuration
    init(config: [String: Any]) throws

    /// Fetch available companies/identifiers
    func listAvailableCompanies() async throws -> [CompanyInfo]

    /// Fetch financial statement data
    func fetchStatement(
        identifier: String,
        statement: StatementType,
        period: PeriodRange
    ) async throws -> FinancialStatementData

    /// Fetch specific metric/account
    func fetchMetric(
        identifier: String,
        metric: String,
        period: PeriodRange
    ) async throws -> TimeSeries<Double>
}

// Data models
struct CompanyInfo: Codable, Sendable {
    let identifier: String
    let name: String
    let industry: String?
    let sector: String?
}

enum StatementType: String, Codable {
    case incomeStatement
    case balanceSheet
    case cashFlow
}

struct PeriodRange: Codable {
    let start: Period
    let end: Period
    let frequency: Frequency

    enum Frequency: String, Codable {
        case monthly, quarterly, annual
    }
}

struct FinancialStatementData: Codable, Sendable {
    let identifier: String
    let statementType: StatementType
    let periods: [Period]
    let accounts: [String: TimeSeries<Double>]
    let metadata: [String: String]
}
```

**Implementation Examples**:

```swift
// Yahoo Finance Data Source
class YahooFinanceDataSource: FinancialDataSource {
    static let sourceType = "yahoo"

    private let apiKey: String?

    required init(config: [String: Any]) throws {
        self.apiKey = config["apiKey"] as? String
    }

    func fetchStatement(
        identifier: String,
        statement: StatementType,
        period: PeriodRange
    ) async throws -> FinancialStatementData {
        // Call Yahoo Finance API
        let url = "https://query2.finance.yahoo.com/v10/finance/quoteSummary/\(identifier)"
        // ... implementation
    }

    func fetchMetric(
        identifier: String,
        metric: String,
        period: PeriodRange
    ) async throws -> TimeSeries<Double> {
        // Fetch specific metric
        // ... implementation
    }
}

// Bloomberg Data Source
class BloombergDataSource: FinancialDataSource {
    static let sourceType = "bloomberg"

    private let apiKey: String
    private let apiSecret: String

    required init(config: [String: Any]) throws {
        guard let key = config["apiKey"] as? String,
              let secret = config["apiSecret"] as? String else {
            throw DataSourceError.missingCredentials
        }
        self.apiKey = key
        self.apiSecret = secret
    }

    // ... implementation
}

// CSV File Data Source
class CSVDataSource: FinancialDataSource {
    static let sourceType = "csv"

    private let filePath: String
    private let keyColumn: String

    required init(config: [String: Any]) throws {
        guard let path = config["path"] as? String else {
            throw DataSourceError.missingConfiguration("path")
        }
        self.filePath = path
        self.keyColumn = config["keyColumn"] as? String ?? "date"
    }

    func fetchStatement(
        identifier: String,
        statement: StatementType,
        period: PeriodRange
    ) async throws -> FinancialStatementData {
        // Read CSV file
        let csvData = try String(contentsOfFile: filePath)
        // Parse and convert to FinancialStatementData
        // ... implementation
    }
}

// Excel Data Source
class ExcelDataSource: FinancialDataSource {
    static let sourceType = "xlsx"

    private let filePath: String
    private let sheetName: String?

    required init(config: [String: Any]) throws {
        guard let path = config["path"] as? String else {
            throw DataSourceError.missingConfiguration("path")
        }
        self.filePath = path
        self.sheetName = config["sheet"] as? String
    }

    // ... implementation
}

// SQL Database Data Source
class SQLDataSource: FinancialDataSource {
    static let sourceType = "sql"

    private let connectionString: String
    private let schema: String

    required init(config: [String: Any]) throws {
        guard let connStr = config["connectionString"] as? String else {
            throw DataSourceError.missingConfiguration("connectionString")
        }
        self.connectionString = connStr
        self.schema = config["schema"] as? String ?? "public"
    }

    func fetchStatement(
        identifier: String,
        statement: StatementType,
        period: PeriodRange
    ) async throws -> FinancialStatementData {
        // Execute SQL query
        let query = """
        SELECT period, account_name, value
        FROM \(schema).financial_data
        WHERE company_id = ? AND statement_type = ?
        """
        // ... implementation
    }
}

// JSON API Data Source (generic REST API)
class JSONAPIDataSource: FinancialDataSource {
    static let sourceType = "json_api"

    private let baseURL: String
    private let headers: [String: String]

    required init(config: [String: Any]) throws {
        guard let url = config["baseURL"] as? String else {
            throw DataSourceError.missingConfiguration("baseURL")
        }
        self.baseURL = url
        self.headers = config["headers"] as? [String: String] ?? [:]
    }

    // ... implementation
}
```

### C. Data Source Registry

**Concept**: Central registry for all available data sources.

```swift
actor DataSourceRegistry {
    private var sources: [String: any FinancialDataSource.Type] = [:]

    static let shared = DataSourceRegistry()

    private init() {
        // Register built-in sources
        register(YahooFinanceDataSource.self)
        register(BloombergDataSource.self)
        register(CSVDataSource.self)
        register(ExcelDataSource.self)
        register(SQLDataSource.self)
        register(JSONAPIDataSource.self)
    }

    func register(_ sourceType: any FinancialDataSource.Type) {
        sources[sourceType.sourceType] = sourceType
    }

    func createDataSource(type: String, config: [String: Any]) throws -> any FinancialDataSource {
        guard let sourceType = sources[type] else {
            throw DataSourceError.unknownSourceType(type)
        }
        return try sourceType.init(config: config)
    }
}
```

### D. Model Loader & Executor

**Concept**: Load JSON model definitions and execute them against data sources.

```swift
class FinancialModelLoader {
    private let registry: DataSourceRegistry

    init(registry: DataSourceRegistry = .shared) {
        self.registry = registry
    }

    /// Load model from JSON file
    func loadModel(from path: String) async throws -> LoadedFinancialModel {
        let jsonData = try Data(contentsOf: URL(fileURLWithPath: path))
        let definition = try JSONDecoder().decode(ModelDefinition.self, from: jsonData)
        return try await buildModel(from: definition)
    }

    /// Load model from JSON string
    func loadModel(json: String) async throws -> LoadedFinancialModel {
        guard let jsonData = json.data(using: .utf8) else {
            throw ModelError.invalidJSON
        }
        let definition = try JSONDecoder().decode(ModelDefinition.self, from: jsonData)
        return try await buildModel(from: definition)
    }

    /// Build model from definition
    private func buildModel(from definition: ModelDefinition) async throws -> LoadedFinancialModel {
        // Initialize data sources
        var dataSources: [String: any FinancialDataSource] = [:]
        for sourceConfig in definition.dataSources {
            let source = try await registry.createDataSource(
                type: sourceConfig.type,
                config: sourceConfig.config
            )
            dataSources[sourceConfig.id] = source
        }

        return LoadedFinancialModel(
            definition: definition,
            dataSources: dataSources
        )
    }
}

class LoadedFinancialModel {
    let definition: ModelDefinition
    let dataSources: [String: any FinancialDataSource]

    init(definition: ModelDefinition, dataSources: [String: any FinancialDataSource]) {
        self.definition = definition
        self.dataSources = dataSources
    }

    /// Fetch and populate all data
    func populate() async throws -> PopulatedModel {
        var accountData: [String: TimeSeries<Double>] = [:]

        // Fetch data for each account
        for (accountName, mapping) in definition.accountMappings {
            if mapping.source == "calculated" {
                // Skip for now, calculate after fetching source data
                continue
            }

            guard let dataSource = dataSources[mapping.source] else {
                throw ModelError.dataSourceNotFound(mapping.source)
            }

            // Fetch the data
            let timeSeries = try await dataSource.fetchMetric(
                identifier: dataSource.identifier,
                metric: mapping.field,
                period: definition.periods
            )

            accountData[accountName] = timeSeries
        }

        // Calculate derived accounts
        for (accountName, mapping) in definition.accountMappings {
            if mapping.source == "calculated", let formula = mapping.formula {
                let timeSeries = try evaluateFormula(formula, using: accountData)
                accountData[accountName] = timeSeries
            }
        }

        return PopulatedModel(
            definition: definition,
            accountData: accountData
        )
    }

    /// Evaluate a formula expression
    private func evaluateFormula(
        _ formula: String,
        using accountData: [String: TimeSeries<Double>]
    ) throws -> TimeSeries<Double> {
        // Simple expression parser
        // Supports: +, -, *, /, parentheses, account names
        // Example: "revenue - cogs"
        // Example: "(revenue - cogs) / revenue"

        // TODO: Implement expression parser
        // For now, simple implementation
        let parser = FormulaParser(accountData: accountData)
        return try parser.evaluate(formula)
    }
}

struct PopulatedModel {
    let definition: ModelDefinition
    let accountData: [String: TimeSeries<Double>]

    /// Get account value
    func account(_ name: String) -> TimeSeries<Double>? {
        return accountData[name]
    }

    /// Generate income statement
    func incomeStatement(format: OutputFormat = .markdown) -> String {
        let formatter = IncomeStatementFormatter(model: self)
        return formatter.format(as: format)
    }

    /// Generate balance sheet
    func balanceSheet(format: OutputFormat = .markdown) -> String {
        let formatter = BalanceSheetFormatter(model: self)
        return formatter.format(as: format)
    }

    /// Generate cash flow statement
    func cashFlowStatement(format: OutputFormat = .markdown) -> String {
        let formatter = CashFlowFormatter(model: self)
        return formatter.format(as: format)
    }

    /// Export to various formats
    func export(to path: String, format: ExportFormat) throws {
        // ... implementation
    }
}
```

### E. Three-Tier Template System

**Concept**: Separate company data, analysis logic, and presentation formatting.

```
/CompanyDefinitions/          # Each company has its own file
  apple.json                  # AAPL: specific account names, data sources
  microsoft.json              # MSFT: different account names
  tesla.json                  # TSLA: automotive-specific accounts
  private_saas_co.json        # Private company, CSV data source

/IndustryTemplates/           # Reusable starting points for company files
  technology.json             # Template for tech companies
  saas.json                   # Template for SaaS companies
  automotive.json             # Template for automotive
  retail.json                 # Template for retail

/AnalysisTemplates/           # Analysis frameworks (cross-industry)
  credit_analysis.json        # Credit memo analysis
  lbo_analysis.json          # Leveraged buyout analysis
  dcf_valuation.json         # DCF valuation
  comparable_companies.json   # Comps analysis
  precedent_transactions.json # Precedent transaction analysis
  ipo_readiness.json         # IPO readiness assessment
  ma_diligence.json          # M&A due diligence
  dupont_analysis.json       # DuPont ROE decomposition

/PresentationTemplates/       # Output structure (JSON schemas)
  credit_memo.json            # Credit memo structure
  lbo_memo.json               # LBO IC memo structure
  equity_research.json        # Equity research structure
  board_package.json          # Board presentation structure
  investor_update.json        # Investor update structure
  diligence_report.json       # Due diligence structure

/Renderers/                   # Format-specific renderers
  MarkdownRenderer.swift      # Render JSON to Markdown
  PDFRenderer.swift           # Render JSON to PDF
  ExcelRenderer.swift         # Render JSON to Excel
  HTMLRenderer.swift          # Render JSON to HTML
  PowerPointRenderer.swift    # Render JSON to PowerPoint
```

**Example Company Definition**: `CompanyDefinitions/apple.json`
```json
{
  "company": {
    "name": "Apple Inc.",
    "ticker": "AAPL",
    "industry": "Technology",
    "sector": "Consumer Electronics"
  },
  "dataSources": [
    {
      "id": "primary",
      "type": "yahoo",
      "config": {"ticker": "AAPL"}
    }
  ],
  "accountMappings": {
    "revenue": {
      "source": "primary",
      "field": "totalRevenue",
      "displayName": "Net Sales"
    },
    "cogs": {
      "source": "primary",
      "field": "costOfRevenue",
      "displayName": "Cost of Sales"
    },
    "grossProfit": {
      "source": "calculated",
      "formula": "revenue - cogs",
      "displayName": "Gross Profit"
    },
    "researchDevelopment": {
      "source": "primary",
      "field": "researchDevelopment",
      "displayName": "Research & Development"
    },
    "sgna": {
      "source": "primary",
      "field": "sellingGeneralAdministrative",
      "displayName": "Selling, General & Administrative"
    },
    "operatingIncome": {
      "source": "primary",
      "field": "operatingIncome",
      "displayName": "Operating Income"
    },
    "totalAssets": {
      "source": "primary",
      "field": "totalAssets",
      "displayName": "Total Assets"
    },
    "totalLiabilities": {
      "source": "primary",
      "field": "totalLiab",
      "displayName": "Total Liabilities"
    },
    "totalDebt": {
      "source": "primary",
      "field": "totalDebt",
      "displayName": "Total Debt"
    },
    "cash": {
      "source": "primary",
      "field": "cash",
      "displayName": "Cash & Equivalents"
    }
  },
  "periods": {
    "frequency": "quarterly",
    "range": {
      "start": "2023-Q1",
      "end": "2024-Q4"
    }
  }
}
```

**Example Analysis Template**: `AnalysisTemplates/credit_analysis.json`
```json
{
  "analysisType": "credit_analysis",
  "name": "Credit Analysis Framework",
  "version": "1.0",
  "description": "Standard credit analysis for investment committee approval",
  "requiredAccounts": [
    "revenue", "ebitda", "operatingIncome", "interestExpense",
    "totalDebt", "totalAssets", "totalLiabilities", "cash",
    "currentAssets", "currentLiabilities"
  ],
  "calculatedMetrics": {
    "netDebt": {
      "formula": "totalDebt - cash",
      "description": "Total debt minus cash and equivalents"
    },
    "leverageRatio": {
      "formula": "netDebt / ebitda",
      "description": "Net Debt / EBITDA",
      "benchmarks": {
        "investment_grade": {"max": 3.0},
        "high_yield": {"max": 5.0},
        "distressed": {"min": 5.0}
      }
    },
    "interestCoverage": {
      "formula": "ebitda / interestExpense",
      "description": "EBITDA / Interest Expense",
      "benchmarks": {
        "strong": {"min": 5.0},
        "adequate": {"min": 2.5},
        "weak": {"max": 2.5}
      }
    },
    "debtToAssets": {
      "formula": "totalDebt / totalAssets",
      "description": "Total Debt / Total Assets",
      "benchmarks": {
        "conservative": {"max": 0.3},
        "moderate": {"max": 0.5},
        "aggressive": {"min": 0.5}
      }
    },
    "currentRatio": {
      "formula": "currentAssets / currentLiabilities",
      "description": "Current Assets / Current Liabilities",
      "benchmarks": {
        "strong": {"min": 2.0},
        "adequate": {"min": 1.0},
        "weak": {"max": 1.0}
      }
    },
    "debtServiceCoverage": {
      "formula": "ebitda / (interestExpense + principalPayments)",
      "description": "EBITDA / Total Debt Service"
    }
  },
  "creditRating": {
    "factors": [
      {
        "name": "Leverage",
        "weight": 0.30,
        "metric": "leverageRatio",
        "scoring": [
          {"range": [0, 2.0], "score": 100, "grade": "AAA"},
          {"range": [2.0, 3.0], "score": 80, "grade": "A"},
          {"range": [3.0, 4.0], "score": 60, "grade": "BBB"},
          {"range": [4.0, 5.0], "score": 40, "grade": "BB"},
          {"range": [5.0, 999], "score": 20, "grade": "B"}
        ]
      },
      {
        "name": "Interest Coverage",
        "weight": 0.25,
        "metric": "interestCoverage",
        "scoring": [
          {"range": [8.0, 999], "score": 100, "grade": "AAA"},
          {"range": [5.0, 8.0], "score": 80, "grade": "A"},
          {"range": [2.5, 5.0], "score": 60, "grade": "BBB"},
          {"range": [1.5, 2.5], "score": 40, "grade": "BB"},
          {"range": [0, 1.5], "score": 20, "grade": "B"}
        ]
      },
      {
        "name": "Liquidity",
        "weight": 0.20,
        "metric": "currentRatio",
        "scoring": [
          {"range": [2.5, 999], "score": 100},
          {"range": [1.5, 2.5], "score": 80},
          {"range": [1.0, 1.5], "score": 60},
          {"range": [0.75, 1.0], "score": 40},
          {"range": [0, 0.75], "score": 20}
        ]
      },
      {
        "name": "Profitability",
        "weight": 0.15,
        "metric": "ebitdaMargin",
        "scoring": [
          {"range": [0.25, 999], "score": 100},
          {"range": [0.15, 0.25], "score": 80},
          {"range": [0.10, 0.15], "score": 60},
          {"range": [0.05, 0.10], "score": 40},
          {"range": [0, 0.05], "score": 20}
        ]
      },
      {
        "name": "Revenue Trend",
        "weight": 0.10,
        "metric": "revenueGrowth3yr",
        "scoring": [
          {"range": [0.15, 999], "score": 100},
          {"range": [0.05, 0.15], "score": 80},
          {"range": [0, 0.05], "score": 60},
          {"range": [-0.05, 0], "score": 40},
          {"range": [-999, -0.05], "score": 20}
        ]
      }
    ]
  },
  "sections": [
    {
      "name": "Executive Summary",
      "content": ["creditRating", "recommendation", "keyRisks"]
    },
    {
      "name": "Financial Overview",
      "content": ["incomeStatement", "balanceSheet", "cashFlow"]
    },
    {
      "name": "Credit Metrics",
      "content": ["leverageRatio", "interestCoverage", "currentRatio", "debtToAssets"]
    },
    {
      "name": "Trend Analysis",
      "content": ["revenueGrowth", "ebitdaGrowth", "debtTrend"]
    },
    {
      "name": "Risk Assessment",
      "content": ["businessRisks", "financialRisks", "industryRisks", "covenantAnalysis"]
    },
    {
      "name": "Recommendation",
      "content": ["approvalRecommendation", "terms", "conditions"]
    }
  ]
}
```

**Example Analysis Template**: `AnalysisTemplates/lbo_analysis.json`
```json
{
  "analysisType": "lbo_analysis",
  "name": "Leveraged Buyout Analysis",
  "version": "1.0",
  "description": "LBO model and returns analysis for PE investment committee",
  "requiredInputs": {
    "transaction": {
      "purchasePrice": {"type": "number", "description": "Enterprise value"},
      "purchaseMultiple": {"type": "number", "description": "EV/EBITDA multiple"},
      "debtFinancing": {"type": "number", "description": "% financed with debt"},
      "equityFinancing": {"type": "number", "description": "% financed with equity"},
      "holdPeriod": {"type": "number", "default": 5, "description": "Years"}
    },
    "financing": {
      "seniorDebt": {
        "amount": {"type": "number"},
        "rate": {"type": "number"},
        "amortization": {"type": "number", "description": "% per year"}
      },
      "subordinatedDebt": {
        "amount": {"type": "number"},
        "rate": {"type": "number"},
        "amortization": {"type": "number"}
      },
      "equityContribution": {"type": "number"}
    },
    "exit": {
      "exitMultiple": {"type": "number", "description": "Exit EV/EBITDA"},
      "exitYear": {"type": "number"}
    }
  },
  "calculatedMetrics": {
    "sourcesAndUses": {
      "sources": {
        "seniorDebt": "financing.seniorDebt.amount",
        "subordinatedDebt": "financing.subordinatedDebt.amount",
        "equity": "financing.equityContribution",
        "totalSources": "seniorDebt + subordinatedDebt + equity"
      },
      "uses": {
        "purchasePrice": "transaction.purchasePrice",
        "fees": "transaction.purchasePrice * 0.03",
        "totalUses": "purchasePrice + fees"
      }
    },
    "debtSchedule": {
      "formula": "amortize(seniorDebt.amount, seniorDebt.rate, seniorDebt.amortization, holdPeriod)"
    },
    "exitValue": {
      "exitEbitda": "ebitda[exitYear]",
      "exitEV": "exitEbitda * exit.exitMultiple",
      "lessDebt": "debtSchedule[exitYear]",
      "equityValue": "exitEV - lessDebt"
    },
    "returns": {
      "totalReturn": "exitValue.equityValue / financing.equityContribution",
      "moic": "totalReturn",
      "irr": "irr([-financing.equityContribution, 0, 0, 0, 0, exitValue.equityValue])"
    }
  },
  "benchmarks": {
    "targetIRR": 0.25,
    "targetMOIC": 3.0,
    "maxLeverage": 6.0,
    "minICR": 2.0
  },
  "sections": [
    {
      "name": "Investment Summary",
      "content": ["company", "transaction", "returns", "recommendation"]
    },
    {
      "name": "Sources & Uses",
      "content": ["sourcesTable", "usesTable"]
    },
    {
      "name": "Operating Model",
      "content": ["revenueProjections", "marginProjections", "ebitdaProjections"]
    },
    {
      "name": "Debt Schedule",
      "content": ["debtBalances", "interestExpense", "debtServiceCoverage"]
    },
    {
      "name": "Returns Analysis",
      "content": ["cashFlowToEquity", "irr", "moic", "sensitivityTable"]
    },
    {
      "name": "Exit Scenarios",
      "content": ["baseCase", "upside", "downside"]
    }
  ]
}
```

### F. Presentation Templates (JSON Structure)

**Concept**: Output structured JSON that any renderer can consume and format.

**Example**: `PresentationTemplates/credit_memo.json`
```json
{
  "presentationType": "credit_memo",
  "name": "Credit Memorandum",
  "version": "1.0",
  "description": "Standard credit memo for investment committee approval",
  "sections": [
    {
      "id": "header",
      "type": "header",
      "fields": [
        {"key": "company", "label": "Company", "source": "company.name"},
        {"key": "industry", "label": "Industry", "source": "company.industry"},
        {"key": "date", "label": "Date", "source": "context.date"},
        {"key": "analyst", "label": "Analyst", "source": "context.analyst"}
      ]
    },
    {
      "id": "executive_summary",
      "type": "section",
      "title": "Executive Summary",
      "content": [
        {
          "type": "recommendation",
          "fields": [
            {"key": "decision", "source": "recommendation.decision", "style": "bold"},
            {"key": "amount", "source": "recommendation.amount", "format": "currency"},
            {"key": "rate", "source": "recommendation.rate", "format": "percentage"}
          ]
        },
        {
          "type": "metric",
          "label": "Internal Credit Rating",
          "fields": [
            {"key": "rating", "source": "creditRating.overall"},
            {"key": "score", "source": "creditRating.score", "format": "number"}
          ],
          "display": "{rating} ({score}/100)"
        },
        {
          "type": "list",
          "title": "Key Strengths",
          "source": "analysis.strengths",
          "style": "bullet"
        },
        {
          "type": "list",
          "title": "Key Risks",
          "source": "analysis.risks",
          "style": "bullet"
        }
      ]
    },
    {
      "id": "financial_overview",
      "type": "section",
      "title": "Financial Overview",
      "content": [
        {
          "type": "financial_statement",
          "statement": "incomeStatement",
          "periods": "quarterly",
          "includeYearTotal": true,
          "showMargins": ["gross", "operating"]
        },
        {
          "type": "metrics_table",
          "title": "Key Metrics",
          "columns": ["Metric", "Current", "Prior Year", "Trend", "Benchmark"],
          "rows": [
            {
              "metric": "Leverage (Net Debt/EBITDA)",
              "current": {"source": "metrics.leverageRatio.current", "format": "ratio"},
              "priorYear": {"source": "metrics.leverageRatio.priorYear", "format": "ratio"},
              "trend": {"source": "metrics.leverageRatio.trend", "format": "arrow"},
              "benchmark": {"value": "<3.0x", "type": "threshold"}
            },
            {
              "metric": "Interest Coverage (EBITDA/Interest)",
              "current": {"source": "metrics.interestCoverage.current", "format": "ratio"},
              "priorYear": {"source": "metrics.interestCoverage.priorYear", "format": "ratio"},
              "trend": {"source": "metrics.interestCoverage.trend", "format": "arrow"},
              "benchmark": {"value": ">2.5x", "type": "threshold"}
            },
            {
              "metric": "Current Ratio",
              "current": {"source": "metrics.currentRatio.current", "format": "decimal"},
              "priorYear": {"source": "metrics.currentRatio.priorYear", "format": "decimal"},
              "trend": {"source": "metrics.currentRatio.trend", "format": "arrow"},
              "benchmark": {"value": ">1.0", "type": "threshold"}
            }
          ],
          "summary": {
            "condition": "metrics.allAboveBenchmark",
            "true": "✅ All metrics meet or exceed investment grade benchmarks",
            "false": "⚠️ Some metrics below target levels (see Risk Assessment)"
          }
        }
      ]
    },
    {
      "id": "credit_rating",
      "type": "section",
      "title": "Credit Rating Analysis",
      "content": [
        {
          "type": "metric",
          "label": "Overall Score",
          "source": "creditRating.score",
          "format": "score_with_grade",
          "display": "{score}/100 → {grade}"
        },
        {
          "type": "table",
          "columns": ["Factor", "Weight", "Score", "Grade", "Comment"],
          "source": "creditRating.factors",
          "rows": [
            {"field": "name"},
            {"field": "weight", "format": "percentage"},
            {"field": "score", "format": "number"},
            {"field": "grade"},
            {"field": "comment"}
          ]
        }
      ]
    },
    {
      "id": "trend_analysis",
      "type": "section",
      "title": "Trend Analysis",
      "content": [
        {
          "type": "subsection",
          "title": "Revenue & Profitability",
          "content": [
            {"type": "chart", "chartType": "line", "source": "trends.revenue"},
            {"type": "metric", "label": "3-Year CAGR", "source": "trends.revenueCagr", "format": "percentage"},
            {"type": "metric", "label": "EBITDA Margin Trend", "source": "trends.ebitdaMarginTrend"}
          ]
        },
        {
          "type": "subsection",
          "title": "Debt Profile",
          "content": [
            {"type": "chart", "chartType": "bar", "source": "trends.debt"},
            {"type": "metric", "label": "Total Debt", "source": "debt.current", "format": "currency"},
            {"type": "metric", "label": "Net Debt", "source": "netDebt.current", "format": "currency"},
            {"type": "text", "label": "Debt Maturity Profile", "source": "debtMaturity.summary"}
          ]
        }
      ]
    },
    {
      "id": "risk_assessment",
      "type": "section",
      "title": "Risk Assessment",
      "content": [
        {
          "type": "risk_list",
          "title": "Financial Risks",
          "source": "risks.financial",
          "fields": ["severity", "description", "mitigation"]
        },
        {
          "type": "risk_list",
          "title": "Business Risks",
          "source": "risks.business",
          "fields": ["severity", "description", "mitigation"]
        },
        {
          "type": "risk_list",
          "title": "Industry Risks",
          "source": "risks.industry",
          "fields": ["severity", "description", "impact"]
        }
      ]
    },
    {
      "id": "proposed_terms",
      "type": "section",
      "title": "Proposed Terms",
      "content": [
        {
          "type": "field_list",
          "fields": [
            {"label": "Facility Type", "source": "terms.facilityType"},
            {"label": "Amount", "source": "terms.amount", "format": "currency"},
            {"label": "Rate", "source": "terms.rate", "format": "percentage_with_spread"},
            {"label": "Term", "source": "terms.termYears", "format": "years"},
            {"label": "Amortization", "source": "terms.amortization"}
          ]
        },
        {
          "type": "covenant_list",
          "title": "Covenants",
          "source": "terms.covenants",
          "showHeadroom": true
        },
        {
          "type": "text",
          "label": "Security",
          "source": "terms.security"
        }
      ]
    },
    {
      "id": "recommendation",
      "type": "section",
      "title": "Recommendation",
      "content": [
        {
          "type": "conditional",
          "condition": "recommendation.approved",
          "true": {
            "type": "approval",
            "decision": "APPROVE",
            "fields": [
              {"key": "amount", "source": "recommendation.amount", "format": "currency"},
              {"key": "rate", "source": "recommendation.rate", "format": "percentage"}
            ],
            "rationale": {"source": "recommendation.reasons", "type": "list"},
            "conditions": {"source": "recommendation.conditions", "type": "list"}
          },
          "false": {
            "type": "approval",
            "decision": "DECLINE",
            "rationale": {"source": "recommendation.reasons", "type": "list"}
          }
        }
      ]
    },
    {
      "id": "footer",
      "type": "footer",
      "fields": [
        {"label": "Prepared by", "source": "context.analyst"},
        {"label": "Reviewed by", "source": "context.reviewer"},
        {"label": "Date", "source": "context.date"}
      ]
    }
  ]
}
```

**Example**: `PresentationTemplates/lbo_memo.json`
```json
{
  "presentationType": "lbo_memo",
  "name": "LBO Investment Committee Memorandum",
  "version": "1.0",
  "sections": [
    {
      "id": "header",
      "type": "header",
      "fields": [
        {"key": "target", "label": "Target", "source": "company.name"},
        {"key": "sector", "label": "Sector", "source": "company.sector"},
        {"key": "date", "label": "Date", "source": "context.date"},
        {"key": "dealTeam", "label": "Deal Team", "source": "context.dealTeam"}
      ]
    },
    {
      "id": "investment_summary",
      "type": "section",
      "title": "Investment Summary",
      "content": [
        {
          "type": "recommendation",
          "source": "recommendation.decision",
          "style": "bold"
        },
        {
          "type": "list",
          "title": "Investment Highlights",
          "source": "analysis.highlights"
        },
        {
          "type": "text",
          "title": "Investment Thesis",
          "source": "analysis.thesis"
        },
        {
          "type": "returns_table",
          "title": "Key Returns",
          "scenarios": ["baseCase", "upside", "downside"],
          "metrics": [
            {"name": "IRR", "source": "returns.{scenario}.irr", "format": "percentage"},
            {"name": "MOIC", "source": "returns.{scenario}.moic", "format": "multiple"},
            {"name": "Cash Yield (Year 5)", "source": "returns.{scenario}.yield", "format": "percentage"}
          ],
          "benchmark": {
            "metric": "returns.baseCase.irr",
            "threshold": "fund.targetIRR",
            "pass": "✅ Base case exceeds {fund.targetIRR}% hurdle rate",
            "fail": "⚠️ Base case below {fund.targetIRR}% hurdle rate"
          }
        }
      ]
    },
    {
      "id": "transaction_overview",
      "type": "section",
      "title": "Transaction Overview",
      "content": [
        {
          "type": "field_list",
          "fields": [
            {"label": "Purchase Price", "source": "transaction.purchasePrice", "format": "currency"},
            {"label": "Purchase Multiple", "source": "transaction.purchaseMultiple", "format": "multiple", "suffix": "x LTM EBITDA"},
            {"label": "LTM EBITDA", "source": "transaction.ltmEbitda", "format": "currency"}
          ]
        },
        {
          "type": "sources_uses_table",
          "sources": "transaction.sourcesAndUses.sources",
          "uses": "transaction.sourcesAndUses.uses",
          "showPercentages": true
        },
        {
          "type": "metric",
          "label": "Leverage",
          "calculation": "{transaction.totalDebt} / {transaction.ltmEbitda}",
          "format": "multiple",
          "style": "bold"
        }
      ]
    },
    {
      "id": "operating_plan",
      "type": "section",
      "title": "Operating Plan",
      "content": [
        {
          "type": "projection_table",
          "title": "Revenue Projections",
          "source": "projections.revenue",
          "periods": "annual"
        },
        {
          "type": "assumption_list",
          "title": "Assumptions",
          "source": "assumptions.revenue"
        },
        {
          "type": "bridge_chart",
          "title": "EBITDA Bridge",
          "source": "projections.ebitdaBridge"
        },
        {
          "type": "metric",
          "label": "EBITDA Margin",
          "display": "{margins.historical}% → {margins.projected}% ({margins.improvement} improvement)"
        }
      ]
    },
    {
      "id": "debt_schedule",
      "type": "section",
      "title": "Debt Schedule",
      "content": [
        {
          "type": "debt_schedule_table",
          "source": "transaction.debtSchedule",
          "showAmortization": true
        },
        {
          "type": "metrics_by_year_table",
          "title": "Key Metrics by Year",
          "metrics": [
            {"name": "Total Debt", "source": "debtMetrics.{year}.totalDebt", "format": "currency"},
            {"name": "Net Leverage", "source": "debtMetrics.{year}.netLeverage", "format": "multiple"},
            {"name": "ICR", "source": "debtMetrics.{year}.icr", "format": "multiple"},
            {"name": "DSCR", "source": "debtMetrics.{year}.dscr", "format": "multiple"}
          ]
        },
        {
          "type": "metric",
          "label": "Deleveraging",
          "display": "{deleveraging.start}x → {deleveraging.exit}x ({deleveraging.turns} turns)"
        }
      ]
    },
    {
      "id": "returns_analysis",
      "type": "section",
      "title": "Returns Analysis",
      "content": [
        {
          "type": "scenario_detail",
          "scenario": "baseCase",
          "title": "Base Case ({baseCase.probability}% probability)",
          "exitAssumptions": [
            {"label": "Exit Year", "source": "baseCase.exitYear"},
            {"label": "Exit Multiple", "source": "baseCase.exitMultiple", "format": "multiple"},
            {"label": "Exit EBITDA", "source": "baseCase.exitEbitda", "format": "currency"}
          ],
          "returns": [
            {"label": "Equity Value at Exit", "source": "baseCase.equityValue", "format": "currency"},
            {"label": "Total Return", "source": "baseCase.totalReturn", "format": "multiple"},
            {"label": "IRR", "source": "baseCase.irr", "format": "percentage"},
            {"label": "MOIC", "source": "baseCase.moic", "format": "multiple"}
          ]
        },
        {
          "type": "sensitivity_table",
          "title": "IRR Sensitivity (Exit Multiple vs EBITDA Growth)",
          "source": "sensitivityAnalysis.irr",
          "format": "percentage"
        },
        {
          "type": "downside_metrics",
          "title": "Downside Protection",
          "fields": [
            {"label": "Break-even Exit Multiple", "source": "downside.breakEvenMultiple", "format": "multiple"},
            {"label": "Probability of Loss", "source": "downside.probabilityOfLoss", "format": "percentage"}
          ]
        }
      ]
    },
    {
      "id": "risks",
      "type": "section",
      "title": "Risks & Mitigants",
      "content": [
        {
          "type": "risk_matrix",
          "source": "risks",
          "groupBy": "category",
          "columns": ["Risk", "Severity", "Probability", "Mitigation"]
        }
      ]
    },
    {
      "id": "recommendation",
      "type": "section",
      "title": "Recommendation",
      "content": [
        {
          "type": "conditional",
          "condition": "recommendation.approved",
          "true": {
            "type": "approval",
            "decision": "APPROVE INVESTMENT",
            "fields": [
              {"label": "Amount", "source": "recommendation.equityCommitment", "format": "currency"},
              {"label": "Ownership", "source": "recommendation.ownership", "format": "percentage"},
              {"label": "Board Seats", "source": "recommendation.boardSeats"}
            ],
            "conditions": {"source": "recommendation.conditions", "type": "list"},
            "valueCreation": {"source": "valueCreation", "type": "list", "showImpact": true}
          },
          "false": {
            "type": "approval",
            "decision": "PASS",
            "rationale": {"source": "recommendation.reasons", "type": "list"}
          }
        }
      ]
    },
    {
      "id": "footer",
      "type": "footer",
      "fields": [
        {"label": "Prepared by", "source": "context.dealTeam"},
        {"label": "Date", "source": "context.date"},
        {"label": "Fund", "source": "fund.name"}
      ]
    }
  ]
}
```

### G. Renderer Architecture

**Concept**: Structured JSON → Format-Specific Renderer → Styled Output

```swift
protocol OutputRenderer {
    associatedtype Output

    /// Render structured JSON to specific format
    func render(_ structuredData: StructuredPresentation) -> Output
}

// Markdown Renderer
class MarkdownRenderer: OutputRenderer {
    func render(_ data: StructuredPresentation) -> String {
        var markdown = ""

        for section in data.sections {
            switch section.type {
            case "header":
                markdown += renderHeader(section)
            case "section":
                markdown += renderSection(section)
            case "table":
                markdown += renderTable(section)
            case "chart":
                markdown += renderChartPlaceholder(section)
            // ... other types
            }
        }

        return markdown
    }

    private func renderHeader(_ section: Section) -> String {
        // Format as markdown header
        return "# \(section.title)\n\n"
    }

    private func renderTable(_ section: Section) -> String {
        // Format as markdown table
        var table = "| \(section.columns.joined(separator: " | ")) |\n"
        table += "|\(String(repeating: "---|", count: section.columns.count))|\n"
        // ... render rows
        return table
    }
}

// PDF Renderer
class PDFRenderer: OutputRenderer {
    func render(_ data: StructuredPresentation) -> PDFDocument {
        let pdf = PDFDocument()

        for section in data.sections {
            switch section.type {
            case "header":
                pdf.addHeader(section, style: .corporate)
            case "section":
                pdf.addSection(section, font: .helvetica)
            case "table":
                pdf.addTable(section, style: .striped)
            case "chart":
                pdf.addChart(section, chartType: section.chartType)
            // ... other types
            }
        }

        return pdf
    }
}

// Excel Renderer
class ExcelRenderer: OutputRenderer {
    func render(_ data: StructuredPresentation) -> ExcelWorkbook {
        let workbook = ExcelWorkbook()
        let sheet = workbook.addSheet(name: data.name)

        var currentRow = 1

        for section in data.sections {
            switch section.type {
            case "header":
                currentRow = renderHeaderToExcel(section, sheet: sheet, row: currentRow)
            case "table":
                currentRow = renderTableToExcel(section, sheet: sheet, row: currentRow)
            case "chart":
                currentRow = renderChartToExcel(section, sheet: sheet, row: currentRow)
            // ... other types
            }
        }

        return workbook
    }
}

// PowerPoint Renderer
class PowerPointRenderer: OutputRenderer {
    func render(_ data: StructuredPresentation) -> PowerPointPresentation {
        let ppt = PowerPointPresentation()

        // Title slide
        let titleSlide = ppt.addSlide(layout: .title)
        titleSlide.setTitle(data.name)

        // Content slides (one per section)
        for section in data.sections where section.type == "section" {
            let slide = ppt.addSlide(layout: .titleAndContent)
            slide.setTitle(section.title)

            for content in section.content {
                switch content.type {
                case "table":
                    slide.addTable(content, style: .corporate)
                case "chart":
                    slide.addChart(content, animated: true)
                case "list":
                    slide.addBulletList(content)
                // ... other types
                }
            }
        }

        return ppt
    }
}

// HTML Renderer (for web dashboards)
class HTMLRenderer: OutputRenderer {
    func render(_ data: StructuredPresentation) -> String {
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <link rel="stylesheet" href="styles.css">
            <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
        </head>
        <body>
        """

        for section in data.sections {
            html += renderSectionToHTML(section)
        }

        html += "</body></html>"
        return html
    }
}
```

**Benefits of Renderer Approach**:
- ✅ **One JSON, Many Formats**: Same analysis, multiple output types
- ✅ **Customization**: Each organization can create custom renderers with their branding
- ✅ **Separation of Concerns**: Analysis logic ≠ Presentation formatting
- ✅ **API-Friendly**: JSON can be consumed by web apps, mobile apps, etc.
- ✅ **Future-Proof**: Add new renderers without changing analysis templates
- ✅ **Testable**: Test analysis logic separately from formatting

---

### H. Complete Workflow Examples

**Example 1: Credit Analysis for Apple Inc.**

```swift
// Step 1: Load company definition
let companyLoader = CompanyLoader()
let apple = try await companyLoader.load(from: "CompanyDefinitions/apple.json")

// Step 2: Load analysis template
let analysisLoader = AnalysisLoader()
let creditAnalysis = try await analysisLoader.load(
    from: "AnalysisTemplates/credit_analysis.json"
)

// Step 3: Run analysis
let analyzer = FinancialAnalyzer()
let results = try await analyzer.analyze(
    company: apple,
    using: creditAnalysis
)

// Step 4: Generate structured JSON output
let presenter = ReportPresenter()
let structuredOutput = try await presenter.generate(
    results: results,
    template: "PresentationTemplates/credit_memo.json",
    context: [
        "analyst": "John Smith",
        "reviewer": "Jane Doe",
        "date": Date().number()
    ]
)

// Step 5: Render to desired format
let markdownRenderer = MarkdownRenderer()
let creditMemo = markdownRenderer.render(structuredOutput)
print(creditMemo)  // Markdown output

// Or render to PDF
let pdfRenderer = PDFRenderer()
let creditMemoPDF = pdfRenderer.render(structuredOutput)
creditMemoPDF.save(to: "credit_memo.pdf")

// Or render to Excel
let excelRenderer = ExcelRenderer()
let creditMemoExcel = excelRenderer.render(structuredOutput)
creditMemoExcel.save(to: "credit_memo.xlsx")

// Or render to PowerPoint for board presentation
let pptRenderer = PowerPointRenderer()
let creditMemoPPT = pptRenderer.render(structuredOutput)
creditMemoPPT.save(to: "credit_memo.pptx")
```

**Output Example**:
```markdown
# CREDIT MEMORANDUM

**Company**: Apple Inc.
**Industry**: Technology
**Date**: 2024-01-15
**Analyst**: John Smith

---

## EXECUTIVE SUMMARY

**Recommendation**: APPROVE - $500,000,000 at 4.5%

**Internal Credit Rating**: AAA (95/100)

**Key Strengths**:
- Exceptional profitability with 26% EBITDA margins
- Strong balance sheet with $48B net cash position
- Dominant market position in premium consumer electronics
- Diversified revenue streams across products and services

**Key Risks**:
- Concentration in iPhone revenue (52% of total)
- Intense competition in all product categories
- Regulatory scrutiny in multiple jurisdictions
- Supply chain dependencies in Asia

---

## FINANCIAL OVERVIEW

### Income Statement (Last 4 Quarters)
                        Q1 2024    Q2 2024    Q3 2024    Q4 2024    FY 2024
Revenue                $119.6B    $94.8B     $85.8B     $94.9B     $395.0B
Cost of Revenue         $66.8B    $52.9B     $48.4B     $53.1B     $221.2B
─────────────────────────────────────────────────────────────────────────
Gross Profit           $52.8B     $41.9B     $37.4B     $41.8B     $173.8B
Gross Margin             44.1%      44.2%      43.6%      44.0%      44.0%

Operating Expenses      $14.3B     $13.9B     $13.4B     $14.1B     $55.7B
─────────────────────────────────────────────────────────────────────────
Operating Income        $38.5B     $28.0B     $24.0B     $27.7B     $118.1B
Operating Margin         32.2%      29.5%      28.0%      29.2%      29.9%

### Key Metrics
| Metric | Current | Prior Year | Trend | Benchmark |
|--------|---------|------------|-------|-----------|
| Leverage (Net Debt/EBITDA) | -0.4x | -0.5x | ↑ | <3.0x |
| Interest Coverage (EBITDA/Interest) | 42.3x | 38.1x | ↑ | >2.5x |
| Current Ratio | 1.05 | 0.98 | ↑ | >1.0 |
| Debt/Assets | 31.2% | 32.8% | ↓ | <50% |

✅ All metrics meet or exceed investment grade benchmarks

---

## CREDIT RATING ANALYSIS

**Overall Score**: 95/100 → **AAA**

| Factor | Weight | Score | Grade | Comment |
|--------|--------|-------|-------|---------|
| Leverage | 30% | 100 | AAA | Net cash position (negative leverage) |
| Interest Coverage | 25% | 100 | AAA | Exceptional coverage at 42x |
| Liquidity | 20% | 85 | A+ | Adequate current ratio, strong cash position |
| Profitability | 15% | 95 | AAA | Industry-leading margins |
| Revenue Trend | 10% | 80 | A | Moderate growth, mature market |

---

## RECOMMENDATION

✅ **APPROVE** - $500,000,000 at 4.5%

**Rationale**:
- Unparalleled credit quality with AAA internal rating
- Strong cash generation supports easy debt service
- Diversified business model reduces concentration risk
- Proven management team with consistent execution

**Conditions**:
- Quarterly financial covenant reporting
- Maintain minimum interest coverage ratio of 5.0x
- No material adverse changes in business operations

---

**Prepared by**: John Smith
**Reviewed by**: Jane Doe
**Date**: 2024-01-15
```

---

**Example 2: LBO Analysis for Acquisition Target**

```swift
// Step 1: Load company definition (private company from CSV)
let target = try await companyLoader.load(from: "CompanyDefinitions/acme_manufacturing.json")

// Step 2: Load LBO analysis template
let lboAnalysis = try await analysisLoader.load(
    from: "AnalysisTemplates/lbo_analysis.json"
)

// Step 3: Configure transaction assumptions
let transaction = LBOTransaction(
    purchasePrice: 500_000_000,
    purchaseMultiple: 8.5,
    debtFinancing: 0.65,    // 65% debt
    equityFinancing: 0.35,   // 35% equity
    holdPeriod: 5,
    financing: LBOFinancing(
        seniorDebt: LBODebtTranche(
            amount: 250_000_000,
            rate: 0.065,
            amortization: 0.05  // 5% per year
        ),
        subordinatedDebt: LBODebtTranche(
            amount: 75_000_000,
            rate: 0.095,
            amortization: 0.00
        ),
        equityContribution: 175_000_000
    ),
    exit: LBOExit(
        exitMultiple: 9.0,
        exitYear: 5
    )
)

// Step 4: Run LBO model
let lboResults = try await analyzer.analyzeLBO(
    company: target,
    transaction: transaction,
    using: lboAnalysis
)

// Step 5: Generate investment committee memo
let lboMemo = try await presenter.generate(
    results: lboResults,
    template: "PresentationTemplates/lbo_memo.md.template",
    context: [
        "dealTeam": "Smith, Jones, Williams",
        "date": Date().number(),
        "fund": ["name": "Growth Equity Fund IV", "targetIRR": 25]
    ]
)

print(lboMemo)
```

**Output Example**:
```markdown
# INVESTMENT COMMITTEE MEMORANDUM

**Target**: ACME Manufacturing Corp
**Sector**: Industrial Manufacturing
**Date**: 2024-01-15
**Deal Team**: Smith, Jones, Williams

---

## INVESTMENT SUMMARY

**Recommendation**: APPROVE INVESTMENT

**Investment Highlights**:
- Market leader in specialized industrial components
- Strong EBITDA margins (18%) with clear path to 22%
- Fragmented market with consolidation opportunity
- Experienced management team with proven track record
- Multiple value creation levers identified

**Investment Thesis**:
ACME is well-positioned to benefit from reshoring trends and industrial automation growth. Our operational improvements (margin expansion, working capital optimization) combined with modest organic growth and bolt-on M&A create a compelling risk-adjusted return profile.

**Key Returns**:
| Metric | Base Case | Upside | Downside |
|--------|-----------|--------|----------|
| IRR | 28.5% | 42.1% | 12.3% |
| MOIC | 3.2x | 5.1x | 1.6x |
| Cash Yield (Year 5) | 18.2% | 24.8% | 9.1% |

✅ Base case exceeds 25% hurdle rate

---

## TRANSACTION OVERVIEW

**Purchase Price**: $500,000,000
**Purchase Multiple**: 8.5x LTM EBITDA
**LTM EBITDA**: $58,800,000

### Sources & Uses

| Sources | Amount | % |
|---------|--------|---|
| Senior Debt (6.5%, 5% amort) | $250,000,000 | 48.5% |
| Subordinated Debt (9.5%) | $75,000,000 | 14.6% |
| Equity | $175,000,000 | 34.0% |
| **Total Sources** | **$515,000,000** | **100%** |

| Uses | Amount | % |
|------|--------|---|
| Purchase Price | $500,000,000 | 97.1% |
| Transaction Fees | $15,000,000 | 2.9% |
| **Total Uses** | **$515,000,000** | **100%** |

**Leverage**: $325M / $58.8M = **5.5x**

---

## RETURNS ANALYSIS

### Base Case (60% probability)

**Exit Assumptions**:
- Exit Year: Year 5
- Exit Multiple: 9.0x EBITDA
- Exit EBITDA: $82,300,000 (7% CAGR)

**Returns**:
- Equity Value at Exit: $562,000,000
- Total Return: 3.2x
- IRR: 28.5%
- MOIC: 3.2x

### Sensitivity Analysis

**IRR Sensitivity (Exit Multiple vs EBITDA Growth)**:
|               | 5% EBITDA | 7% EBITDA | 9% EBITDA |
|---------------|-----------|-----------|-----------|
| 8.0x Exit     | 18.2%     | 22.4%     | 26.8%     |
| 9.0x Exit     | 23.5%     | 28.5%     | 33.7%     |
| 10.0x Exit    | 28.9%     | 34.8%     | 41.2%     |

**Downside Protection**:
- Break-even Exit Multiple: 5.8x
- Probability of Loss: <5%

---

## RECOMMENDATION

✅ **APPROVE INVESTMENT**

**Amount**: $175,000,000
**Ownership**: 100%
**Board Seats**: 3 of 5

**Key Conditions**:
- Completion of quality of earnings review
- Key management retention agreements signed
- Environmental site assessments cleared
- Customer concentration < 15% for top customer

**Value Creation Plan**:
- Operational Excellence: $8M EBITDA improvement (margin expansion 18% → 22%)
- Working Capital Optimization: $12M one-time cash release
- Pricing Power: $4M EBITDA improvement (2% price increases)
- Bolt-on M&A: $6M EBITDA from acquisitions

---

**Prepared by**: Smith, Jones, Williams
**Date**: 2024-01-15
**Fund**: Growth Equity Fund IV
```

---

**Example 3: Quick Company Comparison**

```swift
// Compare multiple companies using same analysis
let companies = [
    "apple": "CompanyDefinitions/apple.json",
    "microsoft": "CompanyDefinitions/microsoft.json",
    "google": "CompanyDefinitions/google.json"
]

let creditAnalysis = try await analysisLoader.load(
    from: "AnalysisTemplates/credit_analysis.json"
)

var results: [String: AnalysisResults] = [:]
for (name, path) in companies {
    let company = try await companyLoader.load(from: path)
    results[name] = try await analyzer.analyze(company: company, using: creditAnalysis)
}

// Generate comparison table
let comparison = ComparisonPresenter().compare(
    results: results,
    metrics: ["leverageRatio", "interestCoverage", "creditRating"]
)

print(comparison)
```

**Output**:
```markdown
## Credit Metrics Comparison

| Company | Leverage | Interest Coverage | Credit Rating | Recommendation |
|---------|----------|-------------------|---------------|----------------|
| Apple | -0.4x | 42.3x | AAA (95/100) | APPROVE |
| Microsoft | 0.3x | 28.1x | AAA (92/100) | APPROVE |
| Google | -0.1x | 35.7x | AAA (94/100) | APPROVE |

All three companies demonstrate exceptional credit quality suitable for investment grade lending at favorable rates.
```

---

## Summary: Three-Tier Architecture

The proposed system separates three critical concerns:

### 1. **Company Definitions** (Data Layer)
- **What**: Company-specific account names, data sources, display names
- **Stored**: One JSON file per company (e.g., `apple.json`, `microsoft.json`)
- **Reusability**: Create once, use forever; version control; share across team
- **Flexibility**: Handles varying nomenclature, multiple data sources

### 2. **Analysis Templates** (Logic Layer)
- **What**: Analytical frameworks with formulas, metrics, benchmarks, scoring
- **Examples**: Credit analysis, LBO model, DCF valuation, comps analysis
- **Reusability**: One template applies to thousands of companies
- **Consistency**: Same metrics calculated the same way every time

### 3. **Presentation Templates** (Output Layer)
- **What**: JSON schemas defining report structure (not formatting)
- **Examples**: Credit memo, IC memo, board package, investor update
- **Consistency**: Same structure every time, any format (PDF, Excel, PowerPoint, HTML)
- **Customization**: Context variables (analyst name, date, etc.)

### 4. **Renderers** (Formatting Layer)
- **What**: Convert structured JSON to specific formats
- **Examples**: MarkdownRenderer, PDFRenderer, ExcelRenderer, PowerPointRenderer, HTMLRenderer
- **Flexibility**: One JSON → Many formats
- **Branding**: Each organization can customize renderers with their styles

### Key Workflow

```
Company JSON + Analysis Template + Presentation Template + Renderer = Decision-Ready Output
     ↓               ↓                       ↓                 ↓
   Data          Calculations            Structure         Formatting
   AAPL         Credit Metrics          JSON Schema      PDF/Excel/PPT

Example Flow:
1. Load apple.json (company data)
2. Run credit_analysis.json (calculate metrics)
3. Structure as credit_memo.json (organize sections)
4. Render with PDFRenderer (format for printing)
   OR ExcelRenderer (format for Excel)
   OR PowerPointRenderer (format for board presentation)
```

### Benefits

**For Scalability**:
- Analyze 1000 companies with 1000 JSON files + 1 analysis template
- No code required for each new company
- Templates shared across teams and organizations

**For Consistency**:
- Same analysis methodology every time
- Same presentation format for every decision
- Benchmarks and scoring built into templates
- Reduces human error and bias

**For Decision Makers**:
- Professional, consistent reports
- Clear recommendations with supporting data
- Risk assessment with mitigations
- Comparison across companies/deals

**For Analysts**:
- Focus on insights, not formatting
- Reuse work across analyses
- Version control for models
- Collaborate via shared templates

---

### H. Builder Pattern (Alternative for Custom Models)

**When to use**: Building custom financial models with specific drivers and formulas (not analyzing existing companies)

**Concept**: Use a builder pattern or DSL to declare models in a readable, concise way.

#### Current State (Complicated)
```swift
// Create entity
let company = Entity(name: "ACME Corp", identifier: "ACME")

// Create accounts manually
let revenueAccount = Account(
    name: "Revenue",
    identifier: "REV",
    type: .revenue,
    entity: company
)

let cogsAccount = Account(
    name: "COGS",
    identifier: "COGS",
    type: .expense,
    entity: company
)

// Create drivers manually
let unitDriver = Driver(name: "Units Sold", identifier: "UNITS")
let priceDriver = Driver(name: "Price", identifier: "PRICE")

// Create formula manually
let revenueFormula = Formula(
    account: revenueAccount,
    drivers: [unitDriver, priceDriver],
    calculation: { drivers in
        drivers["UNITS"]! * drivers["PRICE"]!
    }
)

// More manual setup...
```

#### Proposed State (Ergonomic)
```swift
// Option 1: Builder Pattern
let model = FinancialModel.builder(name: "ACME Corp")
    .revenue { revenue in
        revenue.add("Product Sales") { drivers in
            drivers.units * drivers.price
        }
        revenue.add("Service Revenue") { drivers in
            drivers.hours * drivers.rate
        }
    }
    .cogs { cogs in
        cogs.add("Product Costs", percentOf: "Product Sales", rate: 0.40)
        cogs.add("Service Costs", percentOf: "Service Revenue", rate: 0.30)
    }
    .opex { opex in
        opex.add("Salaries", fixed: 500_000, growthRate: 0.05)
        opex.add("Marketing", percentOf: "Revenue", rate: 0.15)
    }
    .build()

// Option 2: Declarative DSL
@FinancialModelBuilder
var acmeModel: FinancialModel {
    Entity("ACME Corp")

    Revenue {
        Line("Product Sales") {
            Units() * Price()
        }
        Line("Service Revenue") {
            Hours() * HourlyRate()
        }
    }

    COGS {
        Line("Product Costs", percentOf: "Product Sales", 0.40)
        Line("Service Costs", percentOf: "Service Revenue", 0.30)
    }

    OperatingExpenses {
        Line("Salaries", fixed: 500_000, growth: 0.05)
        Line("Marketing", percentOf: "Revenue", 0.15)
    }
}

// Option 3: Configuration-Based (JSON/YAML)
let config = """
{
  "entity": "ACME Corp",
  "revenue": [
    {
      "name": "Product Sales",
      "formula": "units * price"
    },
    {
      "name": "Service Revenue",
      "formula": "hours * rate"
    }
  ],
  "cogs": [
    {
      "name": "Product Costs",
      "type": "percentOf",
      "reference": "Product Sales",
      "rate": 0.40
    }
  ]
}
"""
let model = try FinancialModel(json: config)
```

**Recommendation**: Start with **Option 1 (Builder Pattern)**
- Familiar to Swift developers
- Type-safe with autocomplete
- Easy to add validation
- Flexible for complex scenarios
- Can layer DSL on top later

### B. Formula Templates & Presets

**Concept**: Common patterns should be built-in templates.

```swift
// Common formula patterns as templates
extension FinancialModel.Builder {
    func revenueFromUnitsAndPrice(
        name: String,
        unitsDriver: String = "units",
        priceDriver: String = "price"
    ) -> Self {
        revenue.add(name) { drivers in
            drivers[unitsDriver] * drivers[priceDriver]
        }
    }

    func cogsAsPercent(
        name: String,
        of revenueAccount: String,
        percent: Double
    ) -> Self {
        cogs.add(name, percentOf: revenueAccount, rate: percent)
    }

    func fixedExpenseWithGrowth(
        name: String,
        amount: Double,
        growthRate: Double
    ) -> Self {
        opex.add(name, fixed: amount, growth: growthRate)
    }
}

// Usage
let model = FinancialModel.builder(name: "Simple SaaS")
    .revenueFromUnitsAndPrice("Subscriptions", unitsDriver: "subscribers", priceDriver: "mrr")
    .cogsAsPercent("Server Costs", of: "Subscriptions", percent: 0.20)
    .fixedExpenseWithGrowth("Engineering", amount: 2_000_000, growthRate: 0.10)
    .build()
```

**Built-in Templates**:
1. **Revenue Models**:
   - Units × Price
   - Recurring (MRR/ARR)
   - Usage-based (consumption × rate)
   - Tiered pricing
   - Commission-based

2. **Cost Models**:
   - Fixed costs with growth
   - Variable % of revenue
   - Unit-based ($/unit)
   - Step functions (hire every N units)

3. **Account Rollups**:
   - Standard GAAP categories
   - Custom chart of accounts
   - Department/product segmentation

### C. Smart Account Categorization

**Concept**: Automatic account categorization with override capability.

```swift
enum FinancialCategory: String, CaseIterable {
    // Income Statement
    case revenue
    case cogs
    case grossProfit        // Auto-calculated
    case operatingExpense
    case ebitda            // Auto-calculated
    case depreciation
    case ebit              // Auto-calculated
    case interestExpense
    case taxes
    case netIncome         // Auto-calculated

    // Balance Sheet
    case currentAssets
    case fixedAssets
    case currentLiabilities
    case longTermDebt
    case equity

    // Cash Flow
    case operatingCashFlow
    case investingCashFlow
    case financingCashFlow
}

// Auto-categorization with override
let model = FinancialModel.builder(name: "ACME")
    .add("Product Revenue", category: .revenue)     // Explicit
    .add("Server Costs")                            // Auto: .operatingExpense
    .add("Sales Commission")                        // Auto: .operatingExpense
    .override("Sales Commission", category: .cogs)  // Override
    .build()

// Custom rollups
let model = FinancialModel.builder(name: "ACME")
    .customRollup("Total OpEx") {
        .sum([
            "Salaries",
            "Marketing",
            "General & Administrative"
        ])
    }
    .customRollup("Adjusted EBITDA") {
        .subtract([
            .account("EBITDA"),
            .account("Stock-Based Comp")
        ])
    }
    .build()
```

### D. Driver Management

**Concept**: Centralized driver definitions with type safety.

```swift
// Define driver library
struct Drivers {
    let units = Driver(name: "Units Sold", type: .quantity)
    let price = Driver(name: "Price", type: .currency)
    let subscribers = Driver(name: "Subscribers", type: .quantity)
    let churnRate = Driver(name: "Churn Rate", type: .percentage)
    let cac = Driver(name: "Customer Acquisition Cost", type: .currency)
}

// Use in model
let model = FinancialModel.builder(name: "SaaS")
    .drivers(Drivers.self)
    .revenue { drivers in
        Line("Subscription Revenue") {
            drivers.subscribers * drivers.price * (1 - drivers.churnRate)
        }
    }
    .build()

// Driver scenarios
let baseCase = Scenario(name: "Base Case") {
    drivers.units = TimeSeries(values: [1000, 1100, 1210, 1331])
    drivers.price = TimeSeries(values: [100, 102, 104, 106])
}

let bullCase = Scenario(name: "Bull Case") {
    drivers.units = TimeSeries(values: [1000, 1200, 1440, 1728])
    drivers.price = TimeSeries(values: [100, 105, 110, 115])
}

model.run(scenario: baseCase)
model.run(scenario: bullCase)
```

---

## Part 2: Output Presentation

### A. Standard Financial Statement Formats

**Concept**: Built-in formatters for traditional financial statements.

```swift
// Income Statement
let incomeStatement = model.incomeStatement(
    period: .quarterly,
    year: 2024
)

// Output:
"""
ACME Corp
Income Statement
Q1 2024 - Q4 2024

                           Q1 2024    Q2 2024    Q3 2024    Q4 2024    FY 2024
Revenue
  Product Sales           $1,000,000 $1,100,000 $1,200,000 $1,300,000 $4,600,000
  Service Revenue           $500,000   $550,000   $600,000   $650,000 $2,300,000
  ───────────────────────────────────────────────────────────────────────────────
  Total Revenue           $1,500,000 $1,650,000 $1,800,000 $1,950,000 $6,900,000

Cost of Revenue
  Product Costs             $400,000   $440,000   $480,000   $520,000 $1,840,000
  Service Costs             $150,000   $165,000   $180,000   $195,000   $690,000
  ───────────────────────────────────────────────────────────────────────────────
  Total COGS                $550,000   $605,000   $660,000   $715,000 $2,530,000
  ───────────────────────────────────────────────────────────────────────────────
Gross Profit              $950,000  $1,045,000 $1,140,000 $1,235,000 $4,370,000
Gross Margin                   63.3%       63.3%      63.3%      63.3%      63.3%

Operating Expenses
  Salaries                  $500,000   $500,000   $512,500   $512,500 $2,025,000
  Marketing                 $225,000   $247,500   $270,000   $292,500 $1,035,000
  ───────────────────────────────────────────────────────────────────────────────
  Total OpEx                $725,000   $747,500   $782,500   $805,000 $3,060,000
  ───────────────────────────────────────────────────────────────────────────────
EBITDA                     $225,000   $297,500   $357,500   $430,000 $1,310,000
EBITDA Margin                   15.0%      18.0%      19.9%      22.1%      19.0%
"""
```

### B. Comparative Views

**Concept**: Built-in period-over-period and year-over-year comparisons.

```swift
// Quarter-over-quarter
let qoq = model.quarterOverQuarter(
    metric: "Revenue",
    quarters: 4
)

// Output:
"""
Revenue - Quarter over Quarter

                   Q1 2024    Q2 2024    Q3 2024    Q4 2024
Revenue          $1,500,000 $1,650,000 $1,800,000 $1,950,000
QoQ Change                —   $150,000   $150,000   $150,000
QoQ % Change              —       10.0%       9.1%       8.3%
"""

// Year-over-year
let yoy = model.yearOverYear(
    metrics: ["Revenue", "Gross Profit", "EBITDA"],
    years: [2023, 2024]
)

// Output:
"""
Year over Year Comparison

                        2023        2024      Change      % Change
Revenue            $5,000,000  $6,900,000  $1,900,000        38.0%
Gross Profit       $3,150,000  $4,370,000  $1,220,000        38.7%
EBITDA               $800,000  $1,310,000    $510,000        63.8%
"""
```

### C. Multi-Period Aggregation

**Concept**: Easily switch between monthly, quarterly, and annual views.

```swift
struct PeriodView {
    enum Aggregation {
        case monthly
        case quarterly
        case annual
        case trailingTwelveMonths  // TTM
    }

    func aggregate(_ data: TimeSeries<Double>, to period: Aggregation) -> TimeSeries<Double>
}

// Usage
let monthlyRevenue = model.account("Revenue").timeSeries

let quarterlyRevenue = PeriodView().aggregate(monthlyRevenue, to: .quarterly)
let annualRevenue = PeriodView().aggregate(monthlyRevenue, to: .annual)
let ttmRevenue = PeriodView().aggregate(monthlyRevenue, to: .trailingTwelveMonths)

// Pretty output
let report = model.multiPeriodReport(
    accounts: ["Revenue", "EBITDA", "Net Income"],
    periods: [.monthly, .quarterly, .annual]
)

// Output shows all three views side-by-side or separately
```

### D. Export Formats

**Concept**: Multiple output formats for different use cases.

```swift
protocol FinancialReportExporter {
    func export(_ model: FinancialModel, format: ExportFormat) -> Data
}

enum ExportFormat {
    case csv
    case excel
    case json
    case pdf
    case markdown
    case html
}

// Usage
let exporter = FinancialReportExporter()

// CSV for Excel
let csvData = exporter.export(model, format: .csv)
try csvData.write(to: URL(fileURLWithPath: "financial_model.csv"))

// JSON for APIs
let jsonData = exporter.export(model, format: .json)

// Markdown for documentation
let markdown = exporter.export(model, format: .markdown)

// PDF for presentations
let pdf = exporter.export(model, format: .pdf)
```

### E. Visualization Hints

**Concept**: Provide structure that makes visualization easy.

```swift
struct VisualizationHint {
    let chartType: ChartType
    let xAxis: String
    let yAxis: [String]
    let colors: [String: Color]?
}

enum ChartType {
    case line           // Time series
    case bar            // Comparisons
    case waterfall      // Change attribution
    case stackedArea    // Composition over time
    case tornado        // Sensitivity
}

// Model provides hints
extension FinancialModel {
    func visualizationHints(for metric: String) -> VisualizationHint {
        switch metric {
        case "Revenue":
            return VisualizationHint(
                chartType: .stackedArea,
                xAxis: "Quarter",
                yAxis: ["Product Sales", "Service Revenue"],
                colors: ["Product Sales": .blue, "Service Revenue": .green]
            )
        case "EBITDA Margin":
            return VisualizationHint(
                chartType: .line,
                xAxis: "Quarter",
                yAxis: ["EBITDA Margin"],
                colors: nil
            )
        default:
            return .default
        }
    }
}

// Structured output for charts
let chartData = model.chartData(
    metric: "Revenue",
    breakdown: ["Product Sales", "Service Revenue"],
    periods: quarterlyPeriods
)

// Returns:
// {
//   "periods": ["Q1 2024", "Q2 2024", "Q3 2024", "Q4 2024"],
//   "series": [
//     {"name": "Product Sales", "values": [1000000, 1100000, 1200000, 1300000]},
//     {"name": "Service Revenue", "values": [500000, 550000, 600000, 650000]}
//   ]
// }
```

---

## Implementation Roadmap

### Phase 1: Data Source Infrastructure (Foundation)
**Goal**: Establish plugin architecture and basic data sources

1. **Core Protocol & Registry**
   - [ ] Define `FinancialDataSource` protocol
   - [ ] Implement `DataSourceRegistry` actor
   - [ ] Create error types and validation

2. **Essential Data Sources**
   - [ ] Yahoo Finance data source (free, widely available)
   - [ ] CSV data source (local files)
   - [ ] JSON file data source (local files)

3. **Model Definition Schema**
   - [ ] Define JSON schema for model definitions
   - [ ] Create `ModelDefinition` Codable structs
   - [ ] Implement `FinancialModelLoader`
   - [ ] Add validation for model definitions

4. **Basic Formula Parser**
   - [ ] Simple expression parser (+, -, *, /)
   - [ ] Account name resolution
   - [ ] Parentheses support

**Success Metric**: Can load a JSON model and populate data from Yahoo Finance or CSV

### Phase 2: Model Templates & Additional Data Sources
**Goal**: Reusable templates and expand data source support

1. **Model Templates**
   - [ ] Technology/SaaS template (GAAP income statement)
   - [ ] E-commerce template
   - [ ] Manufacturing template
   - [ ] Generic 3-statement template

2. **Advanced Formula Support**
   - [ ] Period references (revenue[t-1] for lag)
   - [ ] Functions (sum, avg, max, min)
   - [ ] Conditional logic (if/then)

3. **Additional Data Sources**
   - [ ] Excel (.xlsx) data source
   - [ ] SQL database data source
   - [ ] JSON API data source (generic REST)

4. **Account Mapping**
   - [ ] Alias resolution system
   - [ ] Common account mappings library
   - [ ] Auto-detection of account types

**Success Metric**: Can analyze any public company using templates with minimal JSON changes

### Phase 3: Basic Presentation
**Goal**: Output looks like real financial statements

1. **Income Statement Formatter**
   - [ ] Quarterly layout
   - [ ] Annual layout
   - [ ] Proper section grouping
   - [ ] Calculated subtotals (Gross Profit, EBITDA, etc.)

2. **Balance Sheet Formatter**
   - [ ] Assets / Liabilities / Equity structure
   - [ ] Proper ordering
   - [ ] Calculated totals

3. **Cash Flow Formatter**
   - [ ] Operating / Investing / Financing sections
   - [ ] Indirect method
   - [ ] Beginning/ending cash

**Success Metric**: Output is readable by finance professionals without explanation

### Phase 4: Advanced Presentation
**Goal**: Multiple views and comparisons

1. **Period Aggregation**
   - [ ] Monthly → Quarterly
   - [ ] Quarterly → Annual
   - [ ] Trailing twelve months (TTM)

2. **Comparative Views**
   - [ ] Quarter-over-quarter
   - [ ] Year-over-year
   - [ ] Budget vs Actual

3. **Export Formats**
   - [ ] CSV
   - [ ] JSON
   - [ ] Markdown
   - [ ] Excel (via CSV + formatting hints)

**Success Metric**: Can generate board-ready reports

### Phase 5: Advanced Ergonomics
**Goal**: Complex models are still manageable

1. **DSL (Optional)**
   - [ ] Result builder syntax
   - [ ] Nested declarations
   - [ ] Conditional logic

2. **Configuration Import**
   - [ ] JSON loader
   - [ ] YAML loader
   - [ ] Template library

3. **Model Composition**
   - [ ] Merge models
   - [ ] Consolidations
   - [ ] Segment reporting

**Success Metric**: Can build multi-entity consolidated models

---

## Example: Before & After

### Before (Current - Complicated)
```swift
// Must write custom code for each company
let entity = Entity(name: "Apple Inc.")
let revenueAccount = Account(name: "Revenue", type: .revenue, entity: entity)
let cogsAccount = Account(name: "COGS", type: .expense, entity: entity)
// ... 50 more lines of account creation

// Manually fetch data from Yahoo Finance or other source
let yahooData = fetchYahooFinance(ticker: "AAPL")
// ... 30 lines of data parsing and transformation

// Map to accounts
for period in periods {
    revenueAccount.setValue(yahooData.revenue[period], for: period)
    cogsAccount.setValue(yahooData.cogs[period], for: period)
}
// ... more manual mapping

let model = FinancialModel(entity: entity)
model.add(account: revenueAccount)
model.add(account: cogsAccount)
// ... more setup

// No easy way to output nicely
print(model.accounts)  // Just data dump

// To analyze Microsoft, start over with 100+ lines of code
```

### After (Proposed - Data-Driven)

**One-time**: Create reusable template (or use built-in)
```json
// templates/technology.json
{
  "modelDefinition": {
    "name": "Technology Company Analysis",
    "version": "1.0",
    "industry": "Technology",
    "dataSources": [
      {
        "id": "primary",
        "type": "yahoo",
        "config": {
          "ticker": "{{TICKER}}"  // Will be replaced
        }
      }
    ],
    "accountMappings": {
      "revenue": {"source": "primary", "field": "totalRevenue"},
      "cogs": {"source": "primary", "field": "costOfRevenue"},
      "grossProfit": {"source": "calculated", "formula": "revenue - cogs"},
      "operatingExpenses": {"source": "primary", "field": "operatingExpenses"},
      "ebitda": {"source": "calculated", "formula": "grossProfit - operatingExpenses"}
    },
    "statements": {
      "incomeStatement": {
        "sections": [
          {"name": "Revenue", "accounts": ["revenue"]},
          {"name": "Cost of Revenue", "accounts": ["cogs"]},
          {"name": "Gross Profit", "accounts": ["grossProfit"], "showMargin": true},
          {"name": "Operating Expenses", "accounts": ["operatingExpenses"]},
          {"name": "EBITDA", "accounts": ["ebitda"], "showMargin": true}
        ]
      }
    }
  }
}
```

**Every analysis**: 3 lines of code
```swift
// Analyze Apple
let loader = FinancialModelLoader()
let appleModel = try await loader.loadModel(from: "templates/technology.json")
    .configure(ticker: "AAPL")
let apple = try await appleModel.populate()
print(apple.incomeStatement())

// Analyze Microsoft - just change ticker
let msftModel = try await loader.loadModel(from: "templates/technology.json")
    .configure(ticker: "MSFT")
let msft = try await msftModel.populate()
print(msft.incomeStatement())

// Analyze Google - same template
let googModel = try await loader.loadModel(from: "templates/technology.json")
    .configure(ticker: "GOOGL")
let goog = try await googModel.populate()
print(goog.incomeStatement())

// Or analyze a private company from CSV - just change data source
let privateModel = try await loader.loadModel(from: "templates/technology.json")
    .configure(dataSource: "csv", path: "/data/private_company.csv")
let private = try await privateModel.populate()
print(private.incomeStatement())
```

**Benefits**:
- ✅ Write template once, reuse for thousands of companies
- ✅ 3 lines of code vs 100+ lines per company
- ✅ Switch data sources without changing template
- ✅ Store model definitions in version control
- ✅ Share templates across teams
- ✅ Non-programmers can create models (JSON only)

---

## Key Design Decisions

### 1. JSON Model Definitions vs Code-Based
**Decision**: JSON-based model definitions with code as fallback
**Rationale**:
- Scales to thousands of companies without writing code
- Model definitions can be stored, versioned, and shared
- Non-programmers can create/modify models
- Easy to integrate with web interfaces and databases
- Templates can be reused across similar companies
- Code-based approach (builder pattern) still available for complex custom models

### 2. Plugin Architecture for Data Sources
**Decision**: Abstract data source protocol with registry-based plugins
**Rationale**:
- Easy to add new data sources without modifying core code
- Third parties can create data source plugins
- Consistent interface regardless of source (Yahoo, Bloomberg, CSV, SQL, etc.)
- Can mix multiple data sources in one model
- Testable via mock data sources

### 3. Account Mapping with Aliases
**Decision**: Flexible account mapping with alias support
**Rationale**:
- Companies use different terminology (revenue vs sales vs top line)
- Templates can work across companies with different naming
- Reduces manual configuration
- Supports both GAAP and IFRS standards
- Can auto-detect common account names

### 4. Template Library Structure
**Decision**: Organized by industry, statement type, and analysis type
**Rationale**:
- Easy to find relevant template
- Industry templates include common KPIs (SaaS: LTV/CAC, E-commerce: conversion rate)
- Statement templates ensure GAAP/IFRS compliance
- Analysis templates (DuPont, DCF) provide specialized calculations
- Templates are composable (can merge multiple templates)

### 5. Formula Language
**Decision**: Simple expression syntax, not full programming language
**Rationale**:
- Secure (no arbitrary code execution)
- Easy to learn (revenue - cogs, not complex syntax)
- Supports common operations (+, -, *, /, parentheses)
- Period references for time-based calculations (revenue[t-1])
- Can extend with functions (sum, avg) without security risks

### 6. Computed vs Stored Results
**Decision**: Compute on demand, cache if needed
**Rationale**:
- Scenarios change frequently during modeling
- Memory efficient
- Can add caching layer for performance
- Easier to debug (recalculate anytime)

### 7. JSON-Based Presentation Templates + Renderers
**Decision**: Presentation templates output structured JSON, separate renderers handle formatting
**Rationale**:
- **Separation of concerns**: Structure (what to show) ≠ Formatting (how to show it)
- **One JSON, many formats**: Same analysis → PDF, Excel, PowerPoint, HTML, Markdown
- **Customization**: Organizations can create branded renderers without changing templates
- **API-friendly**: JSON can be consumed by web apps, mobile apps, other systems
- **Future-proof**: Add new output formats without changing analysis logic
- **Testable**: Test structure independently from formatting
- **Flexibility**: Decision makers can choose their preferred format (exec wants PDF, analyst wants Excel)

---

## Success Criteria

### For Scalability
1. **New Company Analysis**: <5 minutes to create company JSON and run analysis
2. **Template Reusability**: One analysis template works across all companies in same industry
3. **Volume**: Can analyze 100+ companies in parallel
4. **Consistency**: Same analysis methodology applied to every company

### For Ergonomics (Analyst Experience)
1. **Time to First Output**: <10 minutes from company data to decision-ready report
2. **Code Required**: Zero code for standard analyses (JSON configuration only)
3. **Learning Curve**: Finance professional productive in <1 hour
4. **Error Rate**: 90% reduction in calculation errors (templates are tested once, used many times)
5. **Collaboration**: Templates shared via git, multiple analysts use same methodology

### For Presentation (Decision Maker Experience)
1. **Consistency**: Every credit memo follows same format, every LBO memo follows same format
2. **Clarity**: Executive summary with clear recommendation on page 1
3. **Completeness**: All relevant metrics, trends, risks, and comparisons included automatically
4. **Professional**: Investment-grade formatting suitable for board/committee presentation
5. **Decision-Ready**: Clear approve/decline recommendation with supporting rationale
6. **Actionable**: Conditions, risks, and mitigations clearly stated

### For Data Sources
1. **Flexibility**: Support 5+ data source types (Yahoo, CSV, Excel, SQL, APIs)
2. **Reliability**: Graceful handling of missing data
3. **Performance**: <30 seconds to fetch and populate data for one company
4. **Caching**: Avoid redundant API calls

### Key Metrics
- **Analyst Time Savings**: 80% reduction in time from data to decision
- **Decision Quality**: 100% of memos include standardized risk assessment and benchmarking
- **Scalability**: 10x increase in number of companies that can be analyzed per analyst
- **Consistency**: 0% variation in methodology across analysts (all use same templates)

---

## Next Steps

### Immediate (This Week)
1. Review this document with stakeholders
2. Validate design decisions
3. Prioritize features for Phase 1
4. Create technical specifications for Builder pattern

### Short Term (This Month)
1. Implement Phase 1: Core Ergonomics
2. Create sample models using new API
3. Get feedback from users
4. Iterate on design

### Medium Term (Next Quarter)
1. Implement Phase 2: Formula Templates
2. Implement Phase 3: Basic Presentation
3. Build library of example models
4. Document best practices

### Long Term (Future)
1. Phase 4: Advanced Presentation
2. Phase 5: Advanced Ergonomics
3. Integration with visualization tools
4. MCP tools for model building

---

## Appendix: Reference Implementations

### A. Industry Examples

**What We Can Learn From**:
- **Excel**: Ubiquitous, flexible, but not type-safe
- **Google Sheets**: Collaborative, formula-based
- **Tableau**: Great visualization, poor modeling
- **Anaplan**: Good modeling, complex UI
- **Cube.dev**: SQL-based, powerful but technical

**Our Niche**:
- Type-safe like a programming language
- Readable like a spreadsheet
- Version-controllable like code
- Fast like a compiled language

### B. API Examples

```swift
// Simple SaaS Model
let saas = FinancialModel.builder(name: "SaaS Startup")
    .revenue { r in
        r.add("Subscriptions") { d in
            d.subscribers * d.arp * 12
        }
    }
    .cogs { c in
        c.add("Hosting", percentOf: "Subscriptions", rate: 0.15)
        c.add("Support", perUnit: "subscribers", cost: 50)
    }
    .opex { o in
        o.add("Sales & Marketing") { d in
            d.newCustomers * d.cac
        }
        o.add("R&D", fixed: 1_000_000, growth: 0.20)
        o.add("G&A", fixed: 300_000, growth: 0.10)
    }
    .build()

// E-commerce Model
let ecommerce = FinancialModel.builder(name: "E-commerce")
    .revenue { r in
        r.add("Product Sales") { d in
            d.orders * d.averageOrderValue
        }
    }
    .cogs { c in
        c.add("Product Costs", percentOf: "Product Sales", rate: 0.60)
        c.add("Shipping", perUnit: "orders", cost: 5)
        c.add("Payment Processing", percentOf: "Product Sales", rate: 0.029)
    }
    .opex { o in
        o.add("Marketing", percentOf: "Product Sales", rate: 0.20)
        o.add("Operations", stepped: (threshold: 1000, cost: 100_000))
    }
    .build()

// Manufacturing Model
let manufacturing = FinancialModel.builder(name: "Manufacturing")
    .revenue { r in
        r.add("Widget Sales") { d in
            d.unitsSold * d.pricePerUnit
        }
    }
    .cogs { c in
        c.add("Raw Materials", perUnit: "unitsSold", cost: 20)
        c.add("Direct Labor", perUnit: "unitsSold", cost: 15)
        c.add("Manufacturing Overhead", fixed: 500_000)
    }
    .opex { o in
        o.add("Sales Commissions", percentOf: "Widget Sales", rate: 0.05)
        o.add("Fixed Overhead", fixed: 200_000)
    }
    .balanceSheet { bs in
        bs.add("Inventory", formula: { d in
            d.unitsSold * 1.5 * (20 + 15)  // 1.5 months of COGS
        })
        bs.add("Accounts Receivable", daysOutstanding: 45)
    }
    .build()
```

---

## Questions for Discussion

1. **JSON Schema**: Is the proposed JSON model definition format intuitive enough? What's missing?

2. **Data Source Priority**: Which data sources should we implement first?
   - Free: Yahoo Finance, CSV, JSON files
   - Paid: Bloomberg, FactSet, S&P Capital IQ
   - Custom: SQL databases, internal APIs

3. **Formula Language**: Should we support more than basic arithmetic (+, -, *, /)?
   - Period references: `revenue[t-1]` for lag calculations
   - Functions: `sum()`, `avg()`, `max()`, `min()`
   - Conditionals: `if(condition, true_value, false_value)`

4. **Template Distribution**: How should we distribute templates?
   - Built into library
   - Separate repository (GitHub)
   - Template marketplace
   - All of the above

5. **Account Mapping Intelligence**: Should we use ML/heuristics to auto-map accounts?
   - Pattern matching on account names
   - Learning from user corrections
   - Industry-specific rules

6. **MCP Integration**: Which MCP tools for model building?
   - `load_financial_model`: Load and populate from JSON
   - `create_model_template`: AI-assisted template creation
   - `fetch_company_data`: Preview data source results
   - `compare_companies`: Side-by-side comparison

7. **Renderer Priority**: Which renderers to implement first?
   - **Phase 1**: Markdown (for MCP/CLI), JSON (for APIs/storage)
   - **Phase 2**: PDF (for printing/archiving), Excel (for analysis/manipulation)
   - **Phase 3**: PowerPoint (for presentations), HTML (for web dashboards)
   - **Custom**: Organizations may want branded renderers (letterhead, colors, fonts)

8. **Validation & Error Handling**: How strict?
   - Strict: All accounts must have data for all periods
   - Lenient: Allow missing data, interpolate if needed
   - Configurable: Per-model validation rules

9. **Performance**: For analyzing 1000+ companies at scale:
   - Caching strategy (TTL, invalidation)
   - Parallel data fetching
   - Incremental updates (only fetch new periods)

10. **Versioning**: How to handle model definition changes over time?
    - Semantic versioning for templates
    - Migration tools for breaking changes
    - Backward compatibility guarantees

11. **Renderer Extensibility**: How should custom renderers be integrated?
    - **Plugin system**: Register custom renderers dynamically
    - **Branding**: Organization-specific logos, colors, fonts
    - **Compliance**: Industry-specific formatting requirements (SEC filings, etc.)
    - **Localization**: Multi-language support in renderers

---

**End of Planning Document**

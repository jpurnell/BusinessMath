# Financial Analysis System - Implementation Plan

**Goal**: Build a scalable, data-driven financial analysis system with JSON-based templates and pluggable renderers.

**Status**: Planning → Implementation
**Target**: Phased rollout over 3-4 months

---

## Phase 1: Minimal Viable Prototype (Weeks 1-2)

**Goal**: Get ONE end-to-end flow working to validate the architecture.

**Scope**: Apple Inc. → Credit Analysis → Markdown Output

### Tasks

#### 1.1 Core Data Structures (Week 1, Days 1-2)
```swift
// File: Sources/BusinessMath/FinancialAnalysis/Core/DataStructures.swift

/// Represents a data source configuration
struct DataSourceConfig: Codable {
    let id: String
    let type: String  // "yahoo", "csv", etc.
    let config: [String: String]
}

/// Company definition
struct CompanyDefinition: Codable {
    let company: CompanyInfo
    let dataSources: [DataSourceConfig]
    let accountMappings: [String: AccountMapping]
    let periods: PeriodConfig
}

struct CompanyInfo: Codable {
    let name: String
    let ticker: String?
    let industry: String?
    let sector: String?
}

struct AccountMapping: Codable {
    let source: String
    let field: String?
    let formula: String?
    let displayName: String
}

struct PeriodConfig: Codable {
    let frequency: String  // "monthly", "quarterly", "annual"
    let range: PeriodRange
}

struct PeriodRange: Codable {
    let start: String
    let end: String
}
```

**Deliverable**: Core data structures with Codable conformance

---

#### 1.2 Simple Data Source Protocol (Week 1, Days 3-4)
```swift
// File: Sources/BusinessMath/FinancialAnalysis/DataSources/DataSourceProtocol.swift

protocol FinancialDataSource {
    static var sourceType: String { get }

    init(config: [String: String]) throws

    func fetchMetric(
        identifier: String,
        metric: String,
        startPeriod: Period,
        endPeriod: Period
    ) async throws -> TimeSeries<Double>
}

enum DataSourceError: Error {
    case missingConfiguration(String)
    case fetchFailed(String)
    case unknownSourceType(String)
}
```

**Deliverable**: Protocol definition

---

#### 1.3 CSV Data Source (Week 1, Days 4-5)
```swift
// File: Sources/BusinessMath/FinancialAnalysis/DataSources/CSVDataSource.swift

class CSVDataSource: FinancialDataSource {
    static let sourceType = "csv"

    private let filePath: String
    private let dateColumn: String

    required init(config: [String: String]) throws {
        guard let path = config["path"] else {
            throw DataSourceError.missingConfiguration("path")
        }
        self.filePath = path
        self.dateColumn = config["dateColumn"] ?? "date"
    }

    func fetchMetric(
        identifier: String,
        metric: String,
        startPeriod: Period,
        endPeriod: Period
    ) async throws -> TimeSeries<Double> {
        // Read CSV file
        let csvContent = try String(contentsOfFile: filePath)
        let rows = csvContent.components(separatedBy: .newlines)

        // Parse header
        let header = rows[0].components(separatedBy: ",")
        guard let metricIndex = header.firstIndex(of: metric) else {
            throw DataSourceError.fetchFailed("Metric '\(metric)' not found in CSV")
        }

        // Parse data rows
        var periods: [Period] = []
        var values: [Double] = []

        for row in rows.dropFirst() where !row.isEmpty {
            let columns = row.components(separatedBy: ",")
            // Parse date and value
            // ... implementation
        }

        return TimeSeries(periods: periods, values: values)
    }
}
```

**Deliverable**: Working CSV data source

---

#### 1.4 Company Definition Loader (Week 1, Day 5)
```swift
// File: Sources/BusinessMath/FinancialAnalysis/Loaders/CompanyLoader.swift

class CompanyLoader {
    func load(from path: String) async throws -> LoadedCompany {
        let jsonData = try Data(contentsOf: URL(fileURLWithPath: path))
        let definition = try JSONDecoder().decode(CompanyDefinition.self, from: jsonData)

        return LoadedCompany(definition: definition)
    }
}

class LoadedCompany {
    let definition: CompanyDefinition
    private var accountData: [String: TimeSeries<Double>] = [:]

    init(definition: CompanyDefinition) {
        self.definition = definition
    }

    func account(_ name: String) -> TimeSeries<Double>? {
        return accountData[name]
    }
}
```

**Deliverable**: JSON loader for company definitions

---

#### 1.5 Simple Formula Parser (Week 2, Days 1-2)
```swift
// File: Sources/BusinessMath/FinancialAnalysis/Formula/SimpleParser.swift

/// Simple formula parser supporting: +, -, *, /, parentheses
class FormulaParser {
    private let accountData: [String: TimeSeries<Double>]

    init(accountData: [String: TimeSeries<Double>]) {
        self.accountData = accountData
    }

    func evaluate(_ formula: String) throws -> TimeSeries<Double> {
        // Tokenize
        let tokens = tokenize(formula)

        // Parse to AST
        let ast = try parse(tokens)

        // Evaluate
        return try evaluate(ast)
    }

    private func tokenize(_ formula: String) -> [Token] {
        // Split into tokens: numbers, operators, account names, parentheses
        // "revenue - cogs" → [.account("revenue"), .operator("-"), .account("cogs")]
        // ... implementation
    }

    private func parse(_ tokens: [Token]) throws -> ASTNode {
        // Build abstract syntax tree
        // Handle operator precedence
        // ... implementation
    }

    private func evaluate(_ node: ASTNode) throws -> TimeSeries<Double> {
        switch node {
        case .account(let name):
            guard let ts = accountData[name] else {
                throw FormulaError.undefinedAccount(name)
            }
            return ts
        case .binary(let op, let left, let right):
            let leftTS = try evaluate(left)
            let rightTS = try evaluate(right)
            return try applyOperator(op, leftTS, rightTS)
        // ... other cases
        }
    }
}
```

**Deliverable**: Basic formula evaluator

---

#### 1.6 Data Population (Week 2, Day 3)
```swift
// File: Sources/BusinessMath/FinancialAnalysis/Loaders/CompanyLoader.swift (extension)

extension LoadedCompany {
    func populate() async throws -> PopulatedCompany {
        var accountData: [String: TimeSeries<Double>] = [:]

        // Step 1: Fetch source data
        for (accountName, mapping) in definition.accountMappings {
            if mapping.source == "calculated" {
                continue  // Handle later
            }

            // Find data source
            guard let sourceConfig = definition.dataSources.first(where: { $0.id == mapping.source }) else {
                throw PopulationError.dataSourceNotFound(mapping.source)
            }

            // Create data source
            let dataSource = try createDataSource(type: sourceConfig.type, config: sourceConfig.config)

            // Fetch data
            let timeSeries = try await dataSource.fetchMetric(
                identifier: definition.company.ticker ?? definition.company.name,
                metric: mapping.field ?? accountName,
                startPeriod: parsePeriod(definition.periods.range.start),
                endPeriod: parsePeriod(definition.periods.range.end)
            )

            accountData[accountName] = timeSeries
        }

        // Step 2: Calculate derived accounts
        let parser = FormulaParser(accountData: accountData)
        for (accountName, mapping) in definition.accountMappings {
            if let formula = mapping.formula {
                let timeSeries = try parser.evaluate(formula)
                accountData[accountName] = timeSeries
            }
        }

        return PopulatedCompany(definition: definition, accountData: accountData)
    }

    private func createDataSource(type: String, config: [String: String]) throws -> FinancialDataSource {
        switch type {
        case "csv":
            return try CSVDataSource(config: config)
        default:
            throw DataSourceError.unknownSourceType(type)
        }
    }
}

struct PopulatedCompany {
    let definition: CompanyDefinition
    let accountData: [String: TimeSeries<Double>]

    func account(_ name: String) -> TimeSeries<Double>? {
        return accountData[name]
    }
}
```

**Deliverable**: Data population logic

---

#### 1.7 Markdown Renderer (Week 2, Days 4-5)
```swift
// File: Sources/BusinessMath/FinancialAnalysis/Renderers/MarkdownRenderer.swift

class MarkdownRenderer {
    func renderIncomeStatement(_ company: PopulatedCompany) -> String {
        var markdown = "# Income Statement\n\n"
        markdown += "**Company**: \(company.definition.company.name)\n\n"

        // Get accounts
        guard let revenue = company.account("revenue"),
              let cogs = company.account("cogs"),
              let grossProfit = company.account("grossProfit") else {
            return "Missing required accounts"
        }

        // Render table
        markdown += "| Period | Revenue | COGS | Gross Profit | Margin |\n"
        markdown += "|--------|---------|------|--------------|--------|\n"

        for (period, rev) in revenue.periodsAndValues() {
            let cogsVal = cogs.value(for: period) ?? 0
            let gpVal = grossProfit.value(for: period) ?? 0
            let margin = rev > 0 ? (gpVal / rev) * 100 : 0

            markdown += "| \(period) | \(rev.currency()) | \(cogsVal.currency())
        }

        return markdown
    }

    private func formatPercentage(_ value: Double) -> String {
        return String(format: "%.1f%%", value)
    }
}
```

**Deliverable**: Basic markdown output

---

#### 1.8 End-to-End Test (Week 2, Day 5)
```swift
// File: Tests/BusinessMathTests/FinancialAnalysis/IntegrationTests.swift

final class FinancialAnalysisIntegrationTests: XCTestCase {
    func testAppleIncomeStatement() async throws {
        // Create test CSV data
        let csvPath = createTestCSV()

        // Create company definition
        let companyJSON = """
        {
          "company": {
            "name": "Apple Inc.",
            "ticker": "AAPL"
          },
          "dataSources": [{
            "id": "primary",
            "type": "csv",
            "config": {
              "path": "\(csvPath)",
              "dateColumn": "quarter"
            }
          }],
          "accountMappings": {
            "revenue": {
              "source": "primary",
              "field": "total_revenue",
              "displayName": "Revenue"
            },
            "cogs": {
              "source": "primary",
              "field": "cost_of_revenue",
              "displayName": "Cost of Revenue"
            },
            "grossProfit": {
              "source": "calculated",
              "formula": "revenue - cogs",
              "displayName": "Gross Profit"
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
        """

        // Load company
        let loader = CompanyLoader()
        let company = try await loader.load(json: companyJSON)

        // Populate data
        let populated = try await company.populate()

        // Render
        let renderer = MarkdownRenderer()
        let markdown = renderer.renderIncomeStatement(populated)

        // Verify
        XCTAssertTrue(markdown.contains("Apple Inc."))
        XCTAssertTrue(markdown.contains("Revenue"))
        XCTAssertTrue(markdown.contains("Gross Profit"))
    }
}
```

**Deliverable**: Working end-to-end test

---

### Phase 1 Success Criteria

✅ Can load a company definition from JSON
✅ Can fetch data from CSV file
✅ Can calculate derived accounts using formulas
✅ Can render basic income statement as Markdown
✅ All integration tests pass

**Estimated Time**: 2 weeks
**Output**: Proof of concept demonstrating core architecture

---

## Phase 2: Production Data Sources (Weeks 3-4)

**Goal**: Add real data sources (Yahoo Finance) and improve robustness.

### Tasks

#### 2.1 Yahoo Finance Data Source (Week 3, Days 1-3)
```swift
// File: Sources/BusinessMath/FinancialAnalysis/DataSources/YahooFinanceDataSource.swift

class YahooFinanceDataSource: FinancialDataSource {
    static let sourceType = "yahoo"

    private let ticker: String

    required init(config: [String: String]) throws {
        guard let ticker = config["ticker"] else {
            throw DataSourceError.missingConfiguration("ticker")
        }
        self.ticker = ticker
    }

    func fetchMetric(
        identifier: String,
        metric: String,
        startPeriod: Period,
        endPeriod: Period
    ) async throws -> TimeSeries<Double> {
        // Map metric names to Yahoo Finance API fields
        let apiField = mapMetricToYahooField(metric)

        // Call Yahoo Finance API
        let url = buildYahooURL(ticker: ticker, field: apiField, start: startPeriod, end: endPeriod)

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DataSourceError.fetchFailed("HTTP error")
        }

        // Parse JSON response
        let parsed = try JSONDecoder().decode(YahooFinanceResponse.self, from: data)

        // Convert to TimeSeries
        return try convertToTimeSeries(parsed, metric: apiField)
    }

    private func mapMetricToYahooField(_ metric: String) -> String {
        let mapping: [String: String] = [
            "revenue": "totalRevenue",
            "cogs": "costOfRevenue",
            "operatingIncome": "operatingIncome",
            "totalAssets": "totalAssets",
            "totalDebt": "totalDebt",
            "cash": "cash"
            // ... more mappings
        ]
        return mapping[metric] ?? metric
    }
}
```

**Deliverable**: Working Yahoo Finance integration

---

#### 2.2 Data Source Registry (Week 3, Days 4-5)
```swift
// File: Sources/BusinessMath/FinancialAnalysis/DataSources/DataSourceRegistry.swift

actor DataSourceRegistry {
    private var sources: [String: FinancialDataSource.Type] = [:]

    static let shared = DataSourceRegistry()

    private init() {
        // Register built-in sources
        Task {
            await register(CSVDataSource.self)
            await register(YahooFinanceDataSource.self)
        }
    }

    func register(_ sourceType: FinancialDataSource.Type) {
        sources[sourceType.sourceType] = sourceType
    }

    func createDataSource(type: String, config: [String: String]) throws -> FinancialDataSource {
        guard let sourceType = sources[type] else {
            throw DataSourceError.unknownSourceType(type)
        }
        return try sourceType.init(config: config)
    }
}
```

**Deliverable**: Pluggable data source system

---

#### 2.3 Error Handling & Validation (Week 4, Days 1-2)
```swift
// File: Sources/BusinessMath/FinancialAnalysis/Validation/Validator.swift

class CompanyDefinitionValidator {
    func validate(_ definition: CompanyDefinition) throws {
        // Check required fields
        guard !definition.company.name.isEmpty else {
            throw ValidationError.missingField("company.name")
        }

        // Check data sources
        for source in definition.dataSources {
            guard !source.id.isEmpty else {
                throw ValidationError.invalidDataSource("Empty source ID")
            }
        }

        // Check account mappings
        for (name, mapping) in definition.accountMappings {
            if mapping.source == "calculated" {
                guard mapping.formula != nil else {
                    throw ValidationError.invalidAccount("\(name): calculated accounts must have formula")
                }
            } else {
                guard definition.dataSources.contains(where: { $0.id == mapping.source }) else {
                    throw ValidationError.invalidAccount("\(name): unknown data source '\(mapping.source)'")
                }
            }
        }

        // Check for circular dependencies in formulas
        try validateNoCycles(definition.accountMappings)
    }
}
```

**Deliverable**: Robust validation

---

#### 2.4 Caching Layer (Week 4, Days 3-5)
```swift
// File: Sources/BusinessMath/FinancialAnalysis/Cache/DataCache.swift

actor DataCache {
    private var cache: [String: CacheEntry] = [:]
    private let ttl: TimeInterval = 3600  // 1 hour

    struct CacheEntry {
        let data: TimeSeries<Double>
        let timestamp: Date
    }

    func get(key: String) -> TimeSeries<Double>? {
        guard let entry = cache[key] else { return nil }

        // Check expiration
        if Date().timeIntervalSince(entry.timestamp) > ttl {
            cache.removeValue(forKey: key)
            return nil
        }

        return entry.data
    }

    func set(key: String, data: TimeSeries<Double>) {
        cache[key] = CacheEntry(data: data, timestamp: Date())
    }

    func clear() {
        cache.removeAll()
    }
}

// Usage in data source
extension YahooFinanceDataSource {
    func fetchMetric(...) async throws -> TimeSeries<Double> {
        let cacheKey = "\(ticker)_\(metric)_\(startPeriod)_\(endPeriod)"

        if let cached = await DataCache.shared.get(key: cacheKey) {
            return cached
        }

        let data = try await fetchFromAPI(...)
        await DataCache.shared.set(key: cacheKey, data: data)
        return data
    }
}
```

**Deliverable**: Performance optimization

---

### Phase 2 Success Criteria

✅ Can fetch data from Yahoo Finance
✅ Data source registry supports pluggable sources
✅ Comprehensive error handling and validation
✅ Caching reduces redundant API calls
✅ Can analyze Apple, Microsoft, Google with same template

**Estimated Time**: 2 weeks
**Output**: Production-ready data layer

---

## Phase 3: Analysis Templates (Weeks 5-7)

**Goal**: Implement credit analysis and LBO analysis frameworks.

### Tasks

#### 3.1 Analysis Template Schema (Week 5, Days 1-2)
```swift
// File: Sources/BusinessMath/FinancialAnalysis/Analysis/AnalysisTemplate.swift

struct AnalysisTemplate: Codable {
    let analysisType: String
    let name: String
    let version: String
    let description: String
    let requiredAccounts: [String]
    let calculatedMetrics: [String: MetricDefinition]
    let sections: [AnalysisSection]
}

struct MetricDefinition: Codable {
    let formula: String
    let description: String
    let benchmarks: [String: Benchmark]?
}

struct Benchmark: Codable {
    let min: Double?
    let max: Double?
    let target: Double?
}

struct AnalysisSection: Codable {
    let name: String
    let content: [String]
}
```

**Deliverable**: Analysis template data structures

---

#### 3.2 Credit Analysis Implementation (Week 5, Days 3-5 + Week 6, Days 1-2)
```swift
// File: Sources/BusinessMath/FinancialAnalysis/Analysis/CreditAnalysis.swift

class CreditAnalyzer {
    func analyze(
        company: PopulatedCompany,
        template: AnalysisTemplate
    ) throws -> AnalysisResults {
        // Verify required accounts exist
        try verifyRequiredAccounts(company, template)

        // Calculate metrics
        var metrics: [String: MetricResult] = [:]
        let parser = FormulaParser(accountData: company.accountData)

        for (metricName, definition) in template.calculatedMetrics {
            let value = try parser.evaluate(definition.formula)
            let assessment = assessMetric(value, benchmarks: definition.benchmarks)

            metrics[metricName] = MetricResult(
                name: metricName,
                value: value,
                description: definition.description,
                assessment: assessment
            )
        }

        // Calculate credit rating
        let rating = calculateCreditRating(metrics: metrics, template: template)

        return AnalysisResults(
            company: company.definition.company,
            analysisType: template.analysisType,
            metrics: metrics,
            creditRating: rating,
            timestamp: Date()
        )
    }
}
```

**Deliverable**: Credit analysis engine

---

#### 3.3 LBO Analysis Implementation (Week 6, Days 3-5 + Week 7, Days 1-2)
```swift
// File: Sources/BusinessMath/FinancialAnalysis/Analysis/LBOAnalysis.swift

class LBOAnalyzer {
    func analyze(
        company: PopulatedCompany,
        transaction: LBOTransaction,
        template: AnalysisTemplate
    ) throws -> LBOResults {
        // Build sources & uses
        let sourcesAndUses = buildSourcesAndUses(transaction)

        // Project operating model
        let projections = try projectOperations(company, years: transaction.holdPeriod)

        // Build debt schedule
        let debtSchedule = try buildDebtSchedule(transaction, projections)

        // Calculate returns
        let returns = calculateReturns(
            transaction: transaction,
            projections: projections,
            debtSchedule: debtSchedule
        )

        // Run sensitivity analysis
        let sensitivity = runSensitivity(base: returns)

        return LBOResults(
            company: company.definition.company,
            transaction: transaction,
            sourcesAndUses: sourcesAndUses,
            projections: projections,
            debtSchedule: debtSchedule,
            returns: returns,
            sensitivity: sensitivity
        )
    }
}
```

**Deliverable**: LBO analysis engine

---

#### 3.4 Analysis Tests (Week 7, Days 3-5)

**Deliverable**: Comprehensive tests for both analyzers

---

### Phase 3 Success Criteria

✅ Credit analysis produces accurate metrics
✅ Credit rating calculation matches expected results
✅ LBO analysis produces correct IRR/MOIC
✅ Sensitivity analysis covers key variables
✅ All analysis tests pass

**Estimated Time**: 3 weeks
**Output**: Production analysis engines

---

## Phase 4: Presentation & Renderers (Weeks 8-10)

**Goal**: Implement presentation templates and multi-format renderers.

### Tasks

#### 4.1 Presentation Template Schema (Week 8, Days 1-2)
- Define JSON schema for presentation templates
- Implement template loader

#### 4.2 Structured Output Generator (Week 8, Days 3-5)
- Generate structured JSON from analysis results
- Apply presentation template

#### 4.3 Markdown Renderer (Week 9, Days 1-2)
- Enhance existing markdown renderer
- Support all section types from template

#### 4.4 PDF Renderer (Week 9, Days 3-5)
- Implement PDF generation
- Corporate styling

#### 4.5 Excel Renderer (Week 10, Days 1-3)
- Generate Excel workbooks
- Multiple sheets, formatting, formulas

#### 4.6 Renderer Tests (Week 10, Days 4-5)

### Phase 4 Success Criteria

✅ Presentation templates define structure correctly
✅ Same analysis outputs to Markdown, PDF, Excel
✅ All renderers produce professional output
✅ Renderer tests pass

**Estimated Time**: 3 weeks
**Output**: Multi-format presentation system

---

## Phase 5: Polish & Production (Weeks 11-12)

### Tasks

#### 5.1 Template Library
- Create templates for top 10 industries
- Credit analysis template
- LBO analysis template
- DCF valuation template

#### 5.2 Documentation
- API documentation
- User guide
- Template creation guide

#### 5.3 Performance Optimization
- Profile bottlenecks
- Optimize data fetching
- Parallel processing

#### 5.4 MCP Integration
- Expose as MCP tools
- Test with Claude Desktop

### Phase 5 Success Criteria

✅ 10+ industry templates available
✅ Complete documentation
✅ Can analyze 100+ companies efficiently
✅ MCP tools work in Claude Desktop

**Estimated Time**: 2 weeks
**Output**: Production-ready system

---

## Total Timeline

- **Phase 1**: Weeks 1-2 (Prototype)
- **Phase 2**: Weeks 3-4 (Data Sources)
- **Phase 3**: Weeks 5-7 (Analysis)
- **Phase 4**: Weeks 8-10 (Presentation)
- **Phase 5**: Weeks 11-12 (Polish)

**Total**: ~3 months to full production system

---

## Quick Start (This Week)

If you want to start immediately, here's what to do in the next 7 days:

### Day 1: Setup
1. Create directory structure
2. Define core data structures (CompanyDefinition, etc.)
3. Write first test

### Day 2: CSV Data Source
1. Implement CSVDataSource
2. Create test CSV file
3. Test data loading

### Day 3: Formula Parser
1. Implement basic parser (+, -, *, /)
2. Test with simple formulas

### Day 4: Company Loader
1. Implement JSON loader
2. Test with Apple example

### Day 5: Data Population
1. Implement populate() method
2. Test end-to-end data flow

### Day 6: Markdown Renderer
1. Implement basic income statement renderer
2. Test output

### Day 7: Integration Test
1. Write full integration test
2. Verify entire flow works

By end of Week 1, you'll have a working prototype!

---

## Questions to Answer Before Starting

1. **Repository structure**: Add to existing BusinessMath or new package?
2. **Dependencies**: Which PDF/Excel libraries to use?
3. **Testing strategy**: Unit vs integration test ratio?
4. **Documentation**: DocC or separate docs site?
5. **Distribution**: Swift Package Manager only or also CocoaPods?

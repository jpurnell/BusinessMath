# Topic 8: Input/Output & Integration - Detailed Implementation Plan

**Version:** v1.14.0
**Status:** Ready to Start
**Prerequisites:** Topics 1-6 Complete ✅
**Created:** October 31, 2025

---

## Overview

Topic 8 focuses on making BusinessMath interoperable with the outside world through robust data import/export, validation, and integration capabilities. Unlike Topic 7 (which was rejected as reinventing Excel), Topic 8 provides **real interoperability** with existing tools and data sources.

### Key Principles

1. **Real Interoperability**: Work with actual Excel, CSV, JSON files - don't reinvent them
2. **Validation First**: Comprehensive data validation before processing
3. **External Integration**: Connect to real financial data APIs
4. **Audit & Compliance**: Track all data changes and transformations
5. **Production Ready**: Error handling, logging, and monitoring

---

## Architecture Decision: Skip Formula Engine, Focus on I/O

As discussed, we're **skipping** the formula engine/calculation graph components from the original Topic 7 plan. Those were verbose attempts to recreate Excel without providing actual Excel compatibility.

**What We're Building Instead:**

- ✅ CSV/JSON/Excel **import** capabilities
- ✅ CSV/JSON **export** capabilities
- ✅ Data validation framework
- ✅ External API integrations (market data)
- ✅ Audit trail system
- ✅ Schema validation and migrations
- ❌ Formula engine (use Swift code instead)
- ❌ Calculation graphs (use Swift's native dependency management)
- ❌ DSL/Fluent API (use Swift's natural syntax)

---

## Implementation Phases

### Phase 1: Data Import/Export (Priority 1)
**Goal:** Read and write financial data in common formats

### Phase 2: Validation Framework (Priority 2)
**Goal:** Ensure data quality and business rule compliance

### Phase 3: External Data Sources (Priority 3)
**Goal:** Fetch real market data from APIs

### Phase 4: Audit Trail (Priority 4)
**Goal:** Track changes and maintain compliance

### Phase 5: Schema & Migration (Priority 5)
**Goal:** Handle evolving data structures gracefully

---

## Phase 1: Data Import/Export

### 1.1 CSV Import

**File:** `Sources/BusinessMath/Integration/CSVImporter.swift`

```swift
import Foundation

/// Import financial data from CSV files
public struct CSVImporter {

    /// Configuration for mapping CSV columns to data structures
    public struct MappingConfig {
        public let periodColumn: String
        public let valueColumn: String
        public let entityColumn: String?
        public let accountColumn: String?
        public let dateFormat: String = "yyyy-MM-dd"
        public let delimiter: String = ","
        public let hasHeader: Bool = true

        public init(
            periodColumn: String,
            valueColumn: String,
            entityColumn: String? = nil,
            accountColumn: String? = nil,
            dateFormat: String = "yyyy-MM-dd",
            delimiter: String = ",",
            hasHeader: Bool = true
        )
    }

    /// Import a single time series from CSV
    public func importTimeSeries(
        from url: URL,
        config: MappingConfig
    ) throws -> TimeSeries<Double>

    /// Import multiple time series from CSV (one series per account/entity)
    public func importMultipleTimeSeries(
        from url: URL,
        config: MappingConfig
    ) throws -> [String: TimeSeries<Double>]

    /// Import financial statements from CSV
    public func importFinancialStatements(
        from url: URL,
        config: FinancialStatementMapping
    ) throws -> (IncomeStatement<Double>, BalanceSheet<Double>, CashFlowStatement<Double>)
}

/// Mapping configuration for financial statements
public struct FinancialStatementMapping {
    public let accountNameColumn: String
    public let accountTypeColumn: String
    public let periodColumns: [String]  // ["2024-Q1", "2024-Q2", ...]
    public let entityColumn: String?

    public init(
        accountNameColumn: String,
        accountTypeColumn: String,
        periodColumns: [String],
        entityColumn: String? = nil
    )
}
```

**Features:**
- Parse CSV with configurable delimiters
- Flexible column mapping
- Date parsing with multiple format support
- Error reporting with line numbers
- Handle missing values gracefully
- Support for wide format (periods as columns) and long format (periods as rows)

**Example Usage:**
```swift
let config = CSVImporter.MappingConfig(
    periodColumn: "Date",
    valueColumn: "Revenue",
    entityColumn: "Company"
)

let timeSeries = try CSVImporter().importTimeSeries(
    from: URL(fileURLWithPath: "revenue.csv"),
    config: config
)
```

**Test Cases:**
- ✅ Import simple time series (single column)
- ✅ Import multiple series (multiple value columns)
- ✅ Handle missing values (empty cells)
- ✅ Parse various date formats
- ✅ Handle different delimiters (comma, semicolon, tab)
- ✅ Import with and without headers
- ✅ Wide format (dates as columns) vs long format (dates as rows)
- ✅ Error handling for malformed CSV

---

### 1.2 CSV Export

**File:** `Sources/BusinessMath/Integration/CSVExporter.swift`

```swift
/// Export financial data to CSV files
public struct CSVExporter {

    public struct ExportConfig {
        public let includeHeader: Bool = true
        public let delimiter: String = ","
        public let dateFormat: String = "yyyy-MM-dd"
        public let numberFormat: NumberFormatter?
        public let layout: Layout = .long

        public enum Layout {
            case long   // Each row is one period
            case wide   // Periods as columns
        }
    }

    /// Export a single time series to CSV
    public func exportTimeSeries<T: Real>(
        _ timeSeries: TimeSeries<T>,
        to url: URL,
        config: ExportConfig = ExportConfig()
    ) throws

    /// Export multiple time series to CSV (one column per series)
    public func exportMultipleTimeSeries<T: Real>(
        _ series: [String: TimeSeries<T>],
        to url: URL,
        config: ExportConfig = ExportConfig()
    ) throws

    /// Export financial statements to CSV
    public func exportFinancialStatements<T: Real>(
        incomeStatement: IncomeStatement<T>?,
        balanceSheet: BalanceSheet<T>?,
        cashFlowStatement: CashFlowStatement<T>?,
        to url: URL,
        config: ExportConfig = ExportConfig()
    ) throws
}
```

**Test Cases:**
- ✅ Export time series to long format
- ✅ Export time series to wide format
- ✅ Export multiple series as multi-column CSV
- ✅ Export with custom number formatting
- ✅ Round-trip test (export then import, verify equality)

---

### 1.3 JSON Serialization

**File:** `Sources/BusinessMath/Integration/JSONSerialization.swift`

Make all major types `Codable`:

```swift
// Already Codable (verify):
extension TimeSeries: Codable where T: Codable { }
extension Period: Codable { }
extension PeriodType: Codable { }
extension Entity: Codable { }
extension Account: Codable where T: Codable { }

// Make Codable:
extension IncomeStatement: Codable where T: Codable { }
extension BalanceSheet: Codable where T: Codable { }
extension CashFlowStatement: Codable where T: Codable { }
extension FinancialProjection: Codable where T: Codable { }
extension FinancialScenario: Codable where T: Codable { }
extension DebtInstrument: Codable where T: Codable { }
extension AmortizationSchedule: Codable where T: Codable { }
extension CapTable: Codable where T: Codable { }

/// JSON import/export utilities
public struct JSONSerializer {

    /// Export to JSON with pretty printing
    public func exportToJSON<T: Encodable>(
        _ value: T,
        to url: URL,
        pretty: Bool = true
    ) throws

    /// Import from JSON
    public func importFromJSON<T: Decodable>(
        _ type: T.Type,
        from url: URL
    ) throws -> T

    /// Convert to JSON string
    public func toJSONString<T: Encodable>(
        _ value: T,
        pretty: Bool = true
    ) throws -> String

    /// Convert from JSON string
    public func fromJSONString<T: Decodable>(
        _ type: T.Type,
        from string: String
    ) throws -> T
}
```

**Test Cases:**
- ✅ Encode/decode all major types
- ✅ Round-trip encoding (encode then decode, verify equality)
- ✅ Pretty print vs compact JSON
- ✅ Handle nested structures (financial projection with statements)
- ✅ Null/optional value handling

---

### 1.4 Excel Integration (Read-Only)

**File:** `Sources/BusinessMath/Integration/ExcelImporter.swift`

**Note:** We'll use an existing Swift library for Excel parsing rather than building from scratch.

**Dependency:** Consider using [CoreXLSX](https://github.com/CoreOffice/CoreXLSX) or similar

```swift
#if canImport(CoreXLSX)
import CoreXLSX

/// Import data from Excel (.xlsx) files
public struct ExcelImporter {

    public struct SheetMapping {
        public let sheetName: String
        public let periodColumn: String  // e.g., "A" or column index
        public let valueColumn: String
        public let firstRow: Int = 2  // Skip header
        public let lastRow: Int?
    }

    /// Import time series from Excel sheet
    public func importTimeSeries(
        from url: URL,
        sheet: SheetMapping
    ) throws -> TimeSeries<Double>

    /// Import financial statements from Excel
    /// Expects format: Account names in column A, periods in row 1, values in grid
    public func importFinancialStatements(
        from url: URL,
        incomeStatementSheet: String?,
        balanceSheetSheet: String?,
        cashFlowSheet: String?
    ) throws -> (
        incomeStatement: IncomeStatement<Double>?,
        balanceSheet: BalanceSheet<Double>?,
        cashFlow: CashFlowStatement<Double>?
    )
}
#endif
```

**Test Cases:**
- ✅ Import from single sheet
- ✅ Import from multiple sheets
- ✅ Handle merged cells
- ✅ Parse dates in Excel format
- ✅ Handle formulas (extract values only)
- ⚠️ Excel export is **not** in scope (too complex, use CSV instead)

---

## Phase 2: Validation Framework

### 2.1 Validation Rules

**File:** `Sources/BusinessMath/Validation/ValidationRule.swift`

```swift
/// Protocol for validation rules
public protocol ValidationRule {
    associatedtype T: Real

    /// Validate a value
    func validate(
        _ value: T,
        context: ValidationContext
    ) -> ValidationResult
}

/// Context passed to validation rules
public struct ValidationContext {
    public let fieldName: String
    public let entity: Entity?
    public let period: Period?
    public let metadata: [String: Any]

    public init(
        fieldName: String,
        entity: Entity? = nil,
        period: Period? = nil,
        metadata: [String: Any] = [:]
    )
}

/// Result of validation
public struct ValidationResult {
    public let isValid: Bool
    public let errors: [ValidationError]
    public let warnings: [ValidationWarning]

    public static var valid: ValidationResult {
        ValidationResult(isValid: true, errors: [], warnings: [])
    }

    public static func invalid(_ errors: [ValidationError]) -> ValidationResult {
        ValidationResult(isValid: false, errors: errors, warnings: [])
    }
}

/// Validation error with context
public struct ValidationError: Error, CustomStringConvertible {
    public let field: String
    public let value: Any?
    public let rule: String
    public let message: String
    public let suggestion: String?

    public var description: String {
        var desc = "[\(field)] \(message)"
        if let val = value {
            desc += " (got: \(val))"
        }
        if let sugg = suggestion {
            desc += "\n  Suggestion: \(sugg)"
        }
        return desc
    }
}

/// Validation warning (non-fatal)
public struct ValidationWarning: CustomStringConvertible {
    public let field: String
    public let message: String

    public var description: String {
        "[\(field)] Warning: \(message)"
    }
}
```

---

### 2.2 Standard Validation Rules

**File:** `Sources/BusinessMath/Validation/StandardRules.swift`

```swift
/// Common validation rules
public enum StandardValidation {

    /// Value must be non-negative
    public struct NonNegative<T: Real>: ValidationRule {
        public func validate(_ value: T, context: ValidationContext) -> ValidationResult {
            if value < 0 {
                return .invalid([
                    ValidationError(
                        field: context.fieldName,
                        value: value,
                        rule: "NonNegative",
                        message: "Value must be non-negative",
                        suggestion: "Check if a negative value was entered accidentally"
                    )
                ])
            }
            return .valid
        }
    }

    /// Value must be positive (> 0)
    public struct Positive<T: Real>: ValidationRule {
        public func validate(_ value: T, context: ValidationContext) -> ValidationResult {
            if value <= 0 {
                return .invalid([
                    ValidationError(
                        field: context.fieldName,
                        value: value,
                        rule: "Positive",
                        message: "Value must be positive (> 0)",
                        suggestion: nil
                    )
                ])
            }
            return .valid
        }
    }

    /// Value must be in range [min, max]
    public struct Range<T: Real>: ValidationRule {
        let min: T
        let max: T

        public init(min: T, max: T) {
            self.min = min
            self.max = max
        }

        public func validate(_ value: T, context: ValidationContext) -> ValidationResult {
            if value < min || value > max {
                return .invalid([
                    ValidationError(
                        field: context.fieldName,
                        value: value,
                        rule: "Range",
                        message: "Value must be between \(min) and \(max)",
                        suggestion: "Valid range is [\(min), \(max)]"
                    )
                ])
            }
            return .valid
        }
    }

    /// Value is required (not nil)
    public struct Required<T>: ValidationRule {
        public func validate(_ value: T?, context: ValidationContext) -> ValidationResult {
            if value == nil {
                return .invalid([
                    ValidationError(
                        field: context.fieldName,
                        value: nil,
                        rule: "Required",
                        message: "Value is required",
                        suggestion: "This field cannot be empty"
                    )
                ])
            }
            return .valid
        }
    }
}
```

---

### 2.3 Financial Statement Validation

**File:** `Sources/BusinessMath/Validation/FinancialValidation.swift`

```swift
/// Validation rules specific to financial statements
public struct FinancialValidation {

    /// Balance sheet must balance (Assets = Liabilities + Equity)
    public struct BalanceSheetBalances<T: Real>: ValidationRule {
        let tolerance: T

        public init(tolerance: T = 0.01) {
            self.tolerance = tolerance
        }

        public func validate(
            _ balanceSheet: BalanceSheet<T>,
            context: ValidationContext
        ) -> ValidationResult {
            let errors = balanceSheet.validate(tolerance: tolerance)
            if errors.isEmpty {
                return .valid
            }
            return .invalid(errors.map { periodError in
                ValidationError(
                    field: "Balance Sheet",
                    value: periodError.difference,
                    rule: "BalanceSheetBalances",
                    message: "Assets do not equal Liabilities + Equity in \(periodError.period.label)",
                    suggestion: "Check account classifications and values"
                )
            })
        }
    }

    /// Cash flow reconciles with balance sheet
    public struct CashFlowReconciles<T: Real>: ValidationRule {
        public func validate(
            balanceSheet: BalanceSheet<T>,
            cashFlow: CashFlowStatement<T>,
            context: ValidationContext
        ) -> ValidationResult {
            // Beginning Cash + Net Change = Ending Cash
            var errors: [ValidationError] = []

            for period in cashFlow.periods {
                let beginningCash = balanceSheet.cash[period] ?? 0
                let netChange = cashFlow.netCashChange[period] ?? 0
                let endingCash = balanceSheet.cash[period] ?? 0  // Next period

                let expected = beginningCash + netChange
                let actual = endingCash

                if abs(expected - actual) > 0.01 {
                    errors.append(ValidationError(
                        field: "Cash Flow",
                        value: actual,
                        rule: "CashFlowReconciles",
                        message: "Cash doesn't reconcile for \(period.label): expected \(expected), got \(actual)",
                        suggestion: "Verify cash flow statement and balance sheet cash accounts"
                    ))
                }
            }

            return errors.isEmpty ? .valid : .invalid(errors)
        }
    }

    /// Revenue should be positive
    public struct PositiveRevenue<T: Real>: ValidationRule {
        public func validate(
            _ incomeStatement: IncomeStatement<T>,
            context: ValidationContext
        ) -> ValidationResult {
            var errors: [ValidationError] = []

            for period in incomeStatement.periods {
                let revenue = incomeStatement.totalRevenue[period] ?? 0
                if revenue < 0 {
                    errors.append(ValidationError(
                        field: "Revenue",
                        value: revenue,
                        rule: "PositiveRevenue",
                        message: "Revenue is negative in \(period.label)",
                        suggestion: "Check if revenue was entered as a negative value"
                    ))
                }
            }

            return errors.isEmpty ? .valid : .invalid(errors)
        }
    }

    /// Gross margin should be reasonable (0% to 100%)
    public struct ReasonableGrossMargin<T: Real>: ValidationRule {
        public func validate(
            _ incomeStatement: IncomeStatement<T>,
            context: ValidationContext
        ) -> ValidationResult {
            var warnings: [ValidationWarning] = []

            for period in incomeStatement.periods {
                let margin = incomeStatement.grossMargin[period] ?? 0
                if margin < 0 || margin > 1 {
                    warnings.append(ValidationWarning(
                        field: "Gross Margin",
                        message: "Unusual gross margin of \(margin * 100)% in \(period.label)"
                    ))
                }
            }

            return ValidationResult(isValid: true, errors: [], warnings: warnings)
        }
    }
}
```

**Test Cases:**
- ✅ Balance sheet validation (balanced vs unbalanced)
- ✅ Cash flow reconciliation
- ✅ Revenue validation (positive, negative, zero)
- ✅ Margin validation (normal, unusual, impossible)

---

### 2.4 Model Validator

**File:** `Sources/BusinessMath/Validation/ModelValidator.swift`

```swift
/// Validate entire financial models
public struct ModelValidator<T: Real> {

    public let rules: [any ValidationRule]
    public let financialRules: [FinancialValidationRule<T>]

    public init(
        rules: [any ValidationRule] = [],
        financialRules: [FinancialValidationRule<T>] = []
    ) {
        self.rules = rules
        self.financialRules = financialRules
    }

    /// Validate a financial projection
    public func validate(
        projection: FinancialProjection<T>
    ) -> ValidationReport {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []

        // Validate balance sheet
        let bsRule = FinancialValidation.BalanceSheetBalances<T>()
        let bsResult = bsRule.validate(
            projection.balanceSheet,
            context: ValidationContext(fieldName: "Balance Sheet")
        )
        errors.append(contentsOf: bsResult.errors)
        warnings.append(contentsOf: bsResult.warnings)

        // Validate income statement
        let revenueRule = FinancialValidation.PositiveRevenue<T>()
        let revenueResult = revenueRule.validate(
            projection.incomeStatement,
            context: ValidationContext(fieldName: "Income Statement")
        )
        errors.append(contentsOf: revenueResult.errors)
        warnings.append(contentsOf: revenueResult.warnings)

        // Custom rules
        for rule in financialRules {
            let result = rule.validate(projection)
            errors.append(contentsOf: result.errors)
            warnings.append(contentsOf: result.warnings)
        }

        return ValidationReport(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings,
            timestamp: Date()
        )
    }
}

/// Validation report
public struct ValidationReport {
    public let isValid: Bool
    public let errors: [ValidationError]
    public let warnings: [ValidationWarning]
    public let timestamp: Date

    /// Summary string
    public var summary: String {
        if isValid && warnings.isEmpty {
            return "✅ Validation passed with no issues"
        } else if isValid {
            return "⚠️ Validation passed with \(warnings.count) warning(s)"
        } else {
            return "❌ Validation failed with \(errors.count) error(s)"
        }
    }

    /// Detailed report
    public var detailedReport: String {
        var report = summary + "\n\n"

        if !errors.isEmpty {
            report += "Errors:\n"
            for error in errors {
                report += "  • \(error.description)\n"
            }
            report += "\n"
        }

        if !warnings.isEmpty {
            report += "Warnings:\n"
            for warning in warnings {
                report += "  • \(warning.description)\n"
            }
        }

        return report
    }
}

/// Protocol for financial validation rules
public protocol FinancialValidationRule<T> {
    associatedtype T: Real

    func validate(_ projection: FinancialProjection<T>) -> ValidationResult
}
```

---

## Phase 3: External Data Sources

### 3.1 Market Data Protocol

**File:** `Sources/BusinessMath/Integration/MarketData.swift`

```swift
import Foundation

/// Protocol for market data providers
public protocol MarketDataProvider {

    /// Fetch historical stock prices
    func fetchStockPrice(
        symbol: String,
        from: Date,
        to: Date
    ) async throws -> TimeSeries<Double>

    /// Fetch financial statements
    func fetchFinancials(
        symbol: String,
        statement: FinancialStatementType,
        period: ReportingPeriod
    ) async throws -> [String: Any]  // Raw data

    /// Fetch key metrics (P/E, market cap, etc.)
    func fetchMetrics(
        symbol: String
    ) async throws -> [String: Double]
}

public enum FinancialStatementType {
    case income
    case balanceSheet
    case cashFlow
}

public enum ReportingPeriod {
    case annual
    case quarterly
}
```

---

### 3.2 Yahoo Finance Integration

**File:** `Sources/BusinessMath/Integration/YahooFinanceProvider.swift`

```swift
import Foundation

/// Fetch market data from Yahoo Finance
public class YahooFinanceProvider: MarketDataProvider {

    private let session: URLSession
    private let cache: MarketDataCache?

    public init(
        session: URLSession = .shared,
        cache: MarketDataCache? = nil
    ) {
        self.session = session
        self.cache = cache
    }

    public func fetchStockPrice(
        symbol: String,
        from: Date,
        to: Date
    ) async throws -> TimeSeries<Double> {
        // Check cache first
        let cacheKey = "price_\(symbol)_\(from.timeIntervalSince1970)_\(to.timeIntervalSince1970)"
        if let cached: TimeSeries<Double> = cache?.retrieve(for: cacheKey) {
            return cached
        }

        // Build URL for Yahoo Finance API
        let url = buildYahooFinanceURL(
            symbol: symbol,
            from: from,
            to: to,
            interval: "1d"
        )

        // Fetch data
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketDataError.invalidResponse
        }

        // Parse CSV response
        let timeSeries = try parseYahooFinanceCSV(data)

        // Cache result
        cache?.cache(timeSeries, for: cacheKey, ttl: 3600)  // 1 hour

        return timeSeries
    }

    public func fetchFinancials(
        symbol: String,
        statement: FinancialStatementType,
        period: ReportingPeriod
    ) async throws -> [String: Any] {
        // Implementation using Yahoo Finance API
        // Note: May require scraping or alternative API
        throw MarketDataError.notImplemented
    }

    public func fetchMetrics(
        symbol: String
    ) async throws -> [String: Double] {
        // Fetch key statistics from Yahoo Finance
        let url = URL(string: "https://query1.finance.yahoo.com/v10/finance/quoteSummary/\(symbol)?modules=defaultKeyStatistics")!

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MarketDataError.invalidResponse
        }

        // Parse JSON response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        // Extract metrics

        return [:]  // Placeholder
    }

    private func buildYahooFinanceURL(
        symbol: String,
        from: Date,
        to: Date,
        interval: String
    ) -> URL {
        // Yahoo Finance historical data URL format
        let baseURL = "https://query1.finance.yahoo.com/v7/finance/download/\(symbol)"
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "period1", value: "\(Int(from.timeIntervalSince1970))"),
            URLQueryItem(name: "period2", value: "\(Int(to.timeIntervalSince1970))"),
            URLQueryItem(name: "interval", value: interval),
            URLQueryItem(name: "events", value: "history")
        ]
        return components.url!
    }

    private func parseYahooFinanceCSV(_ data: Data) throws -> TimeSeries<Double> {
        // Parse CSV format: Date,Open,High,Low,Close,Adj Close,Volume
        let csv = String(data: data, encoding: .utf8)!
        let lines = csv.components(separatedBy: "\n")

        var periods: [Period] = []
        var values: [Double] = []

        for (index, line) in lines.enumerated() {
            guard index > 0, !line.isEmpty else { continue }  // Skip header

            let columns = line.components(separatedBy: ",")
            guard columns.count >= 5 else { continue }

            // Parse date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            guard let date = dateFormatter.date(from: columns[0]) else { continue }

            // Parse close price
            guard let close = Double(columns[4]) else { continue }

            periods.append(Period.day(date: date))
            values.append(close)
        }

        return TimeSeries(periods: periods, values: values)
    }
}

public enum MarketDataError: Error {
    case invalidResponse
    case invalidData
    case notImplemented
    case rateLimited
    case unauthorized
}
```

---

### 3.3 Data Caching

**File:** `Sources/BusinessMath/Integration/MarketDataCache.swift`

```swift
import Foundation

/// Cache for market data API responses
public class MarketDataCache {

    private var cache: [String: CachedValue] = [:]
    private let maxSize: Int
    private let defaultTTL: TimeInterval

    public init(
        maxSize: Int = 100,
        defaultTTL: TimeInterval = 3600  // 1 hour
    ) {
        self.maxSize = maxSize
        self.defaultTTL = defaultTTL
    }

    /// Cache a value with TTL
    public func cache<T>(_ value: T, for key: String, ttl: TimeInterval? = nil) {
        let expiresAt = Date().addingTimeInterval(ttl ?? defaultTTL)
        cache[key] = CachedValue(value: value, expiresAt: expiresAt)

        // Evict old entries if cache is full
        if cache.count > maxSize {
            evictExpired()
        }
    }

    /// Retrieve a cached value
    public func retrieve<T>(for key: String) -> T? {
        guard let cached = cache[key] else { return nil }

        // Check if expired
        if Date() > cached.expiresAt {
            cache.removeValue(forKey: key)
            return nil
        }

        return cached.value as? T
    }

    /// Clear all cached values
    public func clear() {
        cache.removeAll()
    }

    /// Evict expired entries
    private func evictExpired() {
        let now = Date()
        cache = cache.filter { $0.value.expiresAt > now }
    }

    private struct CachedValue {
        let value: Any
        let expiresAt: Date
    }
}
```

**Test Cases:**
- ✅ Cache and retrieve values
- ✅ Expiration (TTL) handling
- ✅ Eviction when cache is full
- ✅ Type safety (retrieve with wrong type returns nil)

---

## Phase 4: Audit Trail

### 4.1 Audit Entry

**File:** `Sources/BusinessMath/Audit/AuditTrail.swift`

```swift
import Foundation

/// Record of a change to financial data
public struct AuditEntry: Codable {
    public let id: UUID
    public let timestamp: Date
    public let user: String
    public let action: AuditAction
    public let entityId: String
    public let accountId: String?
    public let period: Period?
    public let oldValue: Double?
    public let newValue: Double?
    public let reason: String?
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        user: String,
        action: AuditAction,
        entityId: String,
        accountId: String? = nil,
        period: Period? = nil,
        oldValue: Double? = nil,
        newValue: Double? = nil,
        reason: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.user = user
        self.action = action
        self.entityId = entityId
        self.accountId = accountId
        self.period = period
        self.oldValue = oldValue
        self.newValue = newValue
        self.reason = reason
        self.metadata = metadata
    }
}

public enum AuditAction: String, Codable {
    case created
    case updated
    case deleted
    case imported
    case exported
    case calculated
    case validated
    case adjusted
}
```

---

### 4.2 Audit Trail Manager

**File:** `Sources/BusinessMath/Audit/AuditTrailManager.swift`

```swift
/// Manage audit trail for financial data
public class AuditTrailManager {

    private var entries: [AuditEntry] = []
    private let storageURL: URL?

    public init(storageURL: URL? = nil) {
        self.storageURL = storageURL
        if let url = storageURL {
            loadFromDisk(url)
        }
    }

    /// Record an audit entry
    public func record(_ entry: AuditEntry) {
        entries.append(entry)

        if let url = storageURL {
            saveToDisk(url)
        }
    }

    /// Query audit entries
    public func query(
        entity: String? = nil,
        account: String? = nil,
        from: Date? = nil,
        to: Date? = nil,
        user: String? = nil,
        action: AuditAction? = nil
    ) -> [AuditEntry] {
        return entries.filter { entry in
            if let entity = entity, entry.entityId != entity { return false }
            if let account = account, entry.accountId != account { return false }
            if let from = from, entry.timestamp < from { return false }
            if let to = to, entry.timestamp > to { return false }
            if let user = user, entry.user != user { return false }
            if let action = action, entry.action != action { return false }
            return true
        }
    }

    /// Generate audit report
    public func generateReport(
        for period: DateInterval
    ) -> AuditReport {
        let relevantEntries = query(
            from: period.start,
            to: period.end
        )

        return AuditReport(
            period: period,
            entries: relevantEntries,
            summary: summarizeEntries(relevantEntries)
        )
    }

    /// Clear all audit entries
    public func clear() {
        entries.removeAll()
        if let url = storageURL {
            saveToDisk(url)
        }
    }

    private func loadFromDisk(_ url: URL) {
        guard let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode([AuditEntry].self, from: data) else {
            return
        }
        entries = loaded
    }

    private func saveToDisk(_ url: URL) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url)
    }

    private func summarizeEntries(_ entries: [AuditEntry]) -> [String: Int] {
        var summary: [String: Int] = [:]
        for entry in entries {
            let key = entry.action.rawValue
            summary[key, default: 0] += 1
        }
        return summary
    }
}

/// Audit report
public struct AuditReport {
    public let period: DateInterval
    public let entries: [AuditEntry]
    public let summary: [String: Int]

    /// Generate formatted report
    public func format() -> String {
        var report = "Audit Report: \(period.start) to \(period.end)\n"
        report += "Total Entries: \(entries.count)\n\n"

        report += "Summary by Action:\n"
        for (action, count) in summary.sorted(by: { $0.key < $1.key }) {
            report += "  \(action): \(count)\n"
        }

        report += "\nDetailed Entries:\n"
        for entry in entries.prefix(50) {  // Show first 50
            report += "  [\(entry.timestamp)] \(entry.user) \(entry.action) \(entry.entityId)"
            if let account = entry.accountId {
                report += " / \(account)"
            }
            if let old = entry.oldValue, let new = entry.newValue {
                report += ": \(old) → \(new)"
            }
            report += "\n"
        }

        return report
    }
}
```

**Test Cases:**
- ✅ Record audit entries
- ✅ Query by entity, account, date range, user, action
- ✅ Generate audit report
- ✅ Persistence (save/load from disk)

---

## Phase 5: Schema & Migration

### 5.1 Data Schema

**File:** `Sources/BusinessMath/Schema/DataSchema.swift`

```swift
/// Define expected data structure
public struct DataSchema {
    public let version: Int
    public let requiredFields: [FieldDefinition]
    public let optionalFields: [FieldDefinition]

    public init(
        version: Int,
        requiredFields: [FieldDefinition],
        optionalFields: [FieldDefinition] = []
    ) {
        self.version = version
        self.requiredFields = requiredFields
        self.optionalFields = optionalFields
    }

    /// Validate data against schema
    public func validate(_ data: [String: Any]) -> ValidationResult {
        var errors: [ValidationError] = []

        // Check required fields
        for field in requiredFields {
            guard let value = data[field.name] else {
                errors.append(ValidationError(
                    field: field.name,
                    value: nil,
                    rule: "Required",
                    message: "Required field '\(field.name)' is missing",
                    suggestion: "Add '\(field.name)' field to data"
                ))
                continue
            }

            // Validate type
            if !field.validateType(value) {
                errors.append(ValidationError(
                    field: field.name,
                    value: value,
                    rule: "Type",
                    message: "Field '\(field.name)' has incorrect type (expected \(field.type))",
                    suggestion: nil
                ))
            }
        }

        return errors.isEmpty ? .valid : .invalid(errors)
    }
}

/// Field definition
public struct FieldDefinition {
    public let name: String
    public let type: FieldType
    public let description: String

    public init(name: String, type: FieldType, description: String = "") {
        self.name = name
        self.type = type
        self.description = description
    }

    public func validateType(_ value: Any) -> Bool {
        switch type {
        case .string:
            return value is String
        case .double:
            return value is Double || value is Int
        case .int:
            return value is Int
        case .bool:
            return value is Bool
        case .date:
            return value is Date || value is String
        case .array(let elementType):
            guard let array = value as? [Any] else { return false }
            return array.allSatisfy { FieldDefinition(name: "", type: elementType).validateType($0) }
        case .object:
            return value is [String: Any]
        }
    }
}

public enum FieldType {
    case string
    case double
    case int
    case bool
    case date
    case array(FieldType)
    case object
}
```

---

### 5.2 Schema Migration

**File:** `Sources/BusinessMath/Schema/SchemaMigration.swift`

```swift
/// Protocol for schema migrations
public protocol SchemaMigration {
    var fromVersion: Int { get }
    var toVersion: Int { get }
    var description: String { get }

    func migrate(_ data: inout [String: Any]) throws
}

/// Manages schema migrations
public class MigrationManager {

    private var migrations: [SchemaMigration] = []

    public init() {}

    /// Register a migration
    public func register(_ migration: SchemaMigration) {
        migrations.append(migration)
    }

    /// Migrate data from one version to another
    public func migrate(
        data: [String: Any],
        from: Int,
        to: Int
    ) throws -> [String: Any] {
        var current = data
        var currentVersion = from

        // Find migration path
        while currentVersion < to {
            guard let migration = migrations.first(where: {
                $0.fromVersion == currentVersion && $0.toVersion == currentVersion + 1
            }) else {
                throw MigrationError.noMigrationPath(from: currentVersion, to: to)
            }

            try migration.migrate(&current)
            currentVersion = migration.toVersion
        }

        return current
    }
}

public enum MigrationError: Error {
    case noMigrationPath(from: Int, to: Int)
    case migrationFailed(version: Int, reason: String)
}

/// Example migration
public struct ExampleMigration_v1_to_v2: SchemaMigration {
    public let fromVersion = 1
    public let toVersion = 2
    public let description = "Add 'category' field to accounts"

    public func migrate(_ data: inout [String: Any]) throws {
        // Add default category if missing
        if data["category"] == nil {
            data["category"] = "Uncategorized"
        }
    }
}
```

---

## Testing Strategy

### Unit Tests (Per Phase)

**Phase 1: Import/Export**
- CSV parsing with various formats
- JSON round-trip encoding
- Excel import from sample files
- Error handling (malformed files)

**Phase 2: Validation**
- All standard validation rules
- Financial statement validation
- Custom business rules
- Validation report generation

**Phase 3: External Data**
- Mock API responses
- Rate limiting
- Cache hit/miss
- Error handling (network failures)

**Phase 4: Audit Trail**
- Record and query entries
- Report generation
- Persistence
- Query filtering

**Phase 5: Schema & Migration**
- Schema validation
- Migration execution
- Migration path finding
- Error handling

---

## Implementation Checklist

### Phase 1: Data Import/Export ✅
- [ ] CSV Importer
  - [ ] Single time series import
  - [ ] Multiple time series import
  - [ ] Financial statements import
  - [ ] Tests (8 cases)
- [ ] CSV Exporter
  - [ ] Time series export
  - [ ] Multiple series export
  - [ ] Financial statements export
  - [ ] Tests (5 cases)
- [ ] JSON Serialization
  - [ ] Make all types Codable
  - [ ] JSON import/export utilities
  - [ ] Tests (5 cases)
- [ ] Excel Import (Optional)
  - [ ] CoreXLSX integration
  - [ ] Sheet mapping
  - [ ] Tests (5 cases)

### Phase 2: Validation Framework ✅
- [ ] Validation Rules
  - [ ] ValidationRule protocol
  - [ ] Standard rules (NonNegative, Positive, Range, Required)
  - [ ] Tests (10 cases)
- [ ] Financial Validation
  - [ ] Balance sheet validation
  - [ ] Cash flow reconciliation
  - [ ] Revenue validation
  - [ ] Margin validation
  - [ ] Tests (10 cases)
- [ ] Model Validator
  - [ ] Validation report
  - [ ] Custom rules
  - [ ] Tests (5 cases)

### Phase 3: External Data Sources ✅
- [ ] Market Data Protocol
  - [ ] MarketDataProvider protocol
  - [ ] Tests with mock provider (5 cases)
- [ ] Yahoo Finance
  - [ ] Stock price fetching
  - [ ] Caching
  - [ ] Error handling
  - [ ] Tests with mock responses (8 cases)
- [ ] Data Cache
  - [ ] TTL-based caching
  - [ ] Eviction
  - [ ] Tests (5 cases)

### Phase 4: Audit Trail ✅
- [ ] Audit Entry
  - [ ] AuditEntry struct
  - [ ] Codable support
  - [ ] Tests (3 cases)
- [ ] Audit Trail Manager
  - [ ] Record entries
  - [ ] Query entries
  - [ ] Generate reports
  - [ ] Persistence
  - [ ] Tests (8 cases)

### Phase 5: Schema & Migration ✅
- [ ] Data Schema
  - [ ] Schema definition
  - [ ] Validation
  - [ ] Tests (5 cases)
- [ ] Schema Migration
  - [ ] Migration protocol
  - [ ] Migration manager
  - [ ] Migration path
  - [ ] Tests (5 cases)

---

## Directory Structure

```
Sources/BusinessMath/
├── Integration/
│   ├── CSVImporter.swift
│   ├── CSVExporter.swift
│   ├── JSONSerializer.swift
│   ├── ExcelImporter.swift (optional)
│   ├── MarketData.swift
│   ├── YahooFinanceProvider.swift
│   └── MarketDataCache.swift
├── Validation/
│   ├── ValidationRule.swift
│   ├── StandardRules.swift
│   ├── FinancialValidation.swift
│   └── ModelValidator.swift
├── Audit/
│   ├── AuditTrail.swift
│   └── AuditTrailManager.swift
└── Schema/
    ├── DataSchema.swift
    └── SchemaMigration.swift

Tests/BusinessMathTests/
├── Integration Tests/
│   ├── CSVImportTests.swift
│   ├── CSVExportTests.swift
│   ├── JSONSerializationTests.swift
│   ├── ExcelImportTests.swift
│   ├── MarketDataTests.swift
│   └── DataCacheTests.swift
├── Validation Tests/
│   ├── ValidationRuleTests.swift
│   ├── FinancialValidationTests.swift
│   └── ModelValidatorTests.swift
├── Audit Tests/
│   └── AuditTrailTests.swift
└── Schema Tests/
    ├── DataSchemaTests.swift
    └── SchemaMigrationTests.swift
```

---

## Dependencies

### Required
- Foundation (built-in)
- Swift Standard Library (built-in)

### Optional
- [CoreXLSX](https://github.com/CoreOffice/CoreXLSX) for Excel import

Add to Package.swift if using Excel:
```swift
dependencies: [
    .package(url: "https://github.com/CoreOffice/CoreXLSX.git", from: "0.14.0")
]
```

---

## Success Criteria

Topic 8 is complete when:

✅ **Import/Export**
- Can import CSV with financial data
- Can export TimeSeries to CSV
- Can serialize all major types to JSON
- Round-trip encoding works (export then import)

✅ **Validation**
- Standard validation rules implemented
- Financial statement validation works
- Validation reports are clear and actionable

✅ **External Data**
- Can fetch stock prices from Yahoo Finance
- Caching reduces API calls
- Error handling is robust

✅ **Audit Trail**
- All changes are recorded
- Queries work correctly
- Audit reports are generated

✅ **Schema & Migration**
- Schema validation works
- Migrations execute successfully
- Migration paths are found automatically

✅ **Testing**
- All phases have comprehensive tests
- Edge cases are covered
- Performance is acceptable

---

## Timeline Estimate

**Phase 1: Import/Export** - 2-3 days
**Phase 2: Validation** - 1-2 days
**Phase 3: External Data** - 2-3 days
**Phase 4: Audit Trail** - 1 day
**Phase 5: Schema & Migration** - 1 day

**Total:** 7-10 days for complete implementation

---

## Release as v1.14.0

Once all phases are complete and tests pass:

1. Update CHANGELOG.md with Topic 8 features
2. Update Master Plan to mark Topic 8 complete
3. Run full test suite
4. Commit and tag as v1.14.0
5. Push to GitHub
6. Update MCP server to expose new I/O capabilities

---

## Next Topic Preview: Topic 9 (Advanced Features)

After Topic 8, we'll tackle:
- Portfolio optimization (Modern Portfolio Theory)
- Optimization & solvers (capital allocation)
- Real options valuation (Black-Scholes, binomial trees)
- Advanced risk analytics (stress testing, VaR aggregation)

But first, let's nail I/O and make BusinessMath truly interoperable! 🚀

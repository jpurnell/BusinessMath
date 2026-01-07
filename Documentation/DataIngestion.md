# Data Ingestion Guide: JSON & CSV

**Version:** 2.0
**Last Updated:** 2026-01-06

## Overview

This guide demonstrates how to load financial statement data from external sources (JSON, CSV) into BusinessMath's role-based financial statement system.

### Supported Formats

- ✅ **JSON** - Structured financial data with entity, periods, and accounts
- ✅ **CSV** - Tabular financial data with column-based mapping
- 🔜 **XML** - Coming in future release
- 🔜 **Excel** - Coming in future release

---

## Table of Contents

1. [JSON Ingestion](#json-ingestion)
2. [CSV Ingestion](#csv-ingestion)
3. [Example Files](#example-files)
4. [Complete Working Example](#complete-working-example)
5. [Best Practices](#best-practices)
6. [Troubleshooting](#troubleshooting)

---

## JSON Ingestion

### JSON Format Structure

The BusinessMath JSON format has three main sections:

```json
{
  "entity": {
    "id": "AAPL",
    "primaryType": "ticker",
    "name": "Apple Inc."
  },
  "periods": [
    {"type": "quarter", "year": 2024, "quarter": 1},
    {"type": "quarter", "year": 2024, "quarter": 2}
  ],
  "accounts": [
    {
      "name": "Product Revenue",
      "incomeStatementRole": "productRevenue",
      "values": [100000, 110000]
    }
  ]
}
```

### JSON Schema

#### Entity Object

```json
{
  "id": "string (required) - Entity identifier",
  "primaryType": "string (required) - One of: ticker, cusip, isin, sedol, internal",
  "name": "string (required) - Entity display name"
}
```

#### Period Object

```json
{
  "type": "string (required) - One of: quarter, annual, monthly, custom",
  "year": "integer (required for quarter/annual/monthly)",
  "quarter": "integer (required for type=quarter, 1-4)",
  "month": "integer (required for type=monthly, 1-12)",
  "start": "ISO 8601 date (required for type=custom)",
  "end": "ISO 8601 date (required for type=custom)"
}
```

#### Account Object

```json
{
  "name": "string (required) - Account name",
  "incomeStatementRole": "string (optional) - IS role enum case",
  "balanceSheetRole": "string (optional) - BS role enum case",
  "cashFlowRole": "string (optional) - CFS role enum case",
  "values": "array<number> (required) - Values matching periods array"
}
```

**Note:** At least one role (incomeStatementRole, balanceSheetRole, or cashFlowRole) must be specified.

### Swift Code: Loading JSON

```swift
import Foundation
import BusinessMath

// MARK: - JSON Decodable Structures

struct FinancialDataJSON: Codable {
    let entity: EntityJSON
    let periods: [PeriodJSON]
    let accounts: [AccountJSON]
    let metadata: MetadataJSON?
}

struct EntityJSON: Codable {
    let id: String
    let primaryType: String
    let name: String
}

struct PeriodJSON: Codable {
    let type: String
    let year: Int?
    let quarter: Int?
    let month: Int?
    let start: String?
    let end: String?
}

struct AccountJSON: Codable {
    let name: String
    let incomeStatementRole: String?
    let balanceSheetRole: String?
    let cashFlowRole: String?
    let values: [Double]
}

struct MetadataJSON: Codable {
    let sourceFormat: String?
    let currency: String?
    let scale: String?
    let dataSource: String?
    let createdDate: String?
    let notes: String?
}

// MARK: - JSON Parsing Functions

func parseEntity(from json: EntityJSON) -> Entity? {
    guard let entityType = EntityIdentifierType(rawValue: json.primaryType) else {
        print("Error: Invalid entity type '\(json.primaryType)'")
        return nil
    }

    return Entity(
        id: json.id,
        primaryType: entityType,
        name: json.name
    )
}

func parsePeriod(from json: PeriodJSON) -> Period? {
    switch json.type {
    case "quarter":
        guard let year = json.year, let quarter = json.quarter else {
            print("Error: Quarter period missing year or quarter")
            return nil
        }
        return Period.quarter(year: year, quarter: quarter)

    case "annual":
        guard let year = json.year else {
            print("Error: Annual period missing year")
            return nil
        }
        return Period.annual(year: year)

    case "monthly":
        guard let year = json.year, let month = json.month else {
            print("Error: Monthly period missing year or month")
            return nil
        }
        return Period.monthly(year: year, month: month)

    case "custom":
        guard let startStr = json.start,
              let endStr = json.end,
              let start = ISO8601DateFormatter().date(from: startStr),
              let end = ISO8601DateFormatter().date(from: endStr) else {
            print("Error: Custom period missing or invalid start/end dates")
            return nil
        }
        return Period.custom(start: start, end: end)

    default:
        print("Error: Unknown period type '\(json.type)'")
        return nil
    }
}

func parseIncomeStatementRole(from string: String?) -> IncomeStatementRole? {
    guard let string = string else { return nil }

    // Map string to IncomeStatementRole enum
    switch string {
    case "revenue": return .revenue
    case "productRevenue": return .productRevenue
    case "serviceRevenue": return .serviceRevenue
    case "subscriptionRevenue": return .subscriptionRevenue
    case "licensingRevenue": return .licensingRevenue
    case "otherRevenue": return .otherRevenue
    case "costOfRevenue": return .costOfRevenue
    case "costOfGoodsSold": return .costOfGoodsSold
    case "costOfServices": return .costOfServices
    case "researchDevelopment": return .researchDevelopment
    case "salesMarketing": return .salesMarketing
    case "generalAdministrative": return .generalAdministrative
    case "operatingExpenses": return .operatingExpenses
    case "depreciationAmortization": return .depreciationAmortization
    case "stockBasedCompensation": return .stockBasedCompensation
    case "impairmentCharges": return .impairmentCharges
    case "interestExpense": return .interestExpense
    case "interestIncome": return .interestIncome
    case "taxExpense": return .taxExpense
    case "otherIncome": return .otherIncome
    default:
        print("Warning: Unknown income statement role '\(string)'")
        return nil
    }
}

func parseBalanceSheetRole(from string: String?) -> BalanceSheetRole? {
    guard let string = string else { return nil }

    // Map string to BalanceSheetRole enum
    switch string {
    case "cashAndEquivalents": return .cashAndEquivalents
    case "shortTermInvestments": return .shortTermInvestments
    case "accountsReceivable": return .accountsReceivable
    case "inventory": return .inventory
    case "prepaidExpenses": return .prepaidExpenses
    case "otherCurrentAssets": return .otherCurrentAssets
    case "propertyPlantEquipment": return .propertyPlantEquipment
    case "accumulatedDepreciation": return .accumulatedDepreciation
    case "intangibleAssets": return .intangibleAssets
    case "goodwill": return .goodwill
    case "longTermInvestments": return .longTermInvestments
    case "otherNonCurrentAssets": return .otherNonCurrentAssets
    case "accountsPayable": return .accountsPayable
    case "accruedExpenses": return .accruedExpenses
    case "deferredRevenue": return .deferredRevenue
    case "shortTermDebt": return .shortTermDebt
    case "currentPortionLongTermDebt": return .currentPortionLongTermDebt
    case "otherCurrentLiabilities": return .otherCurrentLiabilities
    case "longTermDebt": return .longTermDebt
    case "deferredTaxLiabilities": return .deferredTaxLiabilities
    case "pensionLiabilities": return .pensionLiabilities
    case "otherNonCurrentLiabilities": return .otherNonCurrentLiabilities
    case "commonStock": return .commonStock
    case "preferredStock": return .preferredStock
    case "additionalPaidInCapital": return .additionalPaidInCapital
    case "retainedEarnings": return .retainedEarnings
    case "treasuryStock": return .treasuryStock
    case "accumulatedOCI": return .accumulatedOCI
    default:
        print("Warning: Unknown balance sheet role '\(string)'")
        return nil
    }
}

func parseCashFlowRole(from string: String?) -> CashFlowRole? {
    guard let string = string else { return nil }

    // Map string to CashFlowRole enum
    switch string {
    case "netIncome": return .netIncome
    case "depreciationAmortizationAddback": return .depreciationAmortizationAddback
    case "stockBasedCompensationAddback": return .stockBasedCompensationAddback
    case "deferredTaxes": return .deferredTaxes
    case "changeInReceivables": return .changeInReceivables
    case "changeInInventory": return .changeInInventory
    case "changeInPayables": return .changeInPayables
    case "changeInDeferredRevenue": return .changeInDeferredRevenue
    case "otherOperatingActivities": return .otherOperatingActivities
    case "capitalExpenditures": return .capitalExpenditures
    case "proceedsFromAssetSales": return .proceedsFromAssetSales
    case "acquisitions": return .acquisitions
    case "purchasesOfInvestments": return .purchasesOfInvestments
    case "salesOfInvestments": return .salesOfInvestments
    case "otherInvestingActivities": return .otherInvestingActivities
    case "proceedsFromDebt": return .proceedsFromDebt
    case "repaymentOfDebt": return .repaymentOfDebt
    case "proceedsFromEquity": return .proceedsFromEquity
    case "shareRepurchases": return .shareRepurchases
    case "dividendsPaid": return .dividendsPaid
    case "otherFinancingActivities": return .otherFinancingActivities
    default:
        print("Warning: Unknown cash flow role '\(string)'")
        return nil
    }
}

func parseAccount(from json: AccountJSON, entity: Entity, periods: [Period]) throws -> Account<Double> {
    let incomeStatementRole = parseIncomeStatementRole(from: json.incomeStatementRole)
    let balanceSheetRole = parseBalanceSheetRole(from: json.balanceSheetRole)
    let cashFlowRole = parseCashFlowRole(from: json.cashFlowRole)

    // Validate: at least one role must be specified
    guard incomeStatementRole != nil || balanceSheetRole != nil || cashFlowRole != nil else {
        throw NSError(
            domain: "DataIngestion",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Account '\(json.name)' must have at least one role"]
        )
    }

    // Validate: values array must match periods array
    guard json.values.count == periods.count else {
        throw NSError(
            domain: "DataIngestion",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Account '\(json.name)' has \(json.values.count) values but \(periods.count) periods"]
        )
    }

    let timeSeries = TimeSeries(periods: periods, values: json.values)

    return try Account(
        entity: entity,
        name: json.name,
        incomeStatementRole: incomeStatementRole,
        balanceSheetRole: balanceSheetRole,
        cashFlowRole: cashFlowRole,
        timeSeries: timeSeries
    )
}

// MARK: - Main Loading Function

func loadFinancialStatementsFromJSON(fileURL: URL) throws -> (
    entity: Entity,
    periods: [Period],
    accounts: [Account<Double>]
) {
    // 1. Load JSON file
    let data = try Data(contentsOf: fileURL)
    let decoder = JSONDecoder()
    let financialData = try decoder.decode(FinancialDataJSON.self, from: data)

    // 2. Parse entity
    guard let entity = parseEntity(from: financialData.entity) else {
        throw NSError(
            domain: "DataIngestion",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Failed to parse entity"]
        )
    }

    // 3. Parse periods
    let periods = financialData.periods.compactMap { parsePeriod(from: $0) }
    guard periods.count == financialData.periods.count else {
        throw NSError(
            domain: "DataIngestion",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Failed to parse all periods"]
        )
    }

    // 4. Parse accounts
    let accounts = try financialData.accounts.map { accountJSON in
        try parseAccount(from: accountJSON, entity: entity, periods: periods)
    }

    return (entity: entity, periods: periods, accounts: accounts)
}
```

### Usage Example: Loading JSON

```swift
import Foundation
import BusinessMath

// Load financial statements from JSON file
let fileURL = URL(fileURLWithPath: "Examples/financial-statements-example.json")

do {
    let (entity, periods, accounts) = try loadFinancialStatementsFromJSON(fileURL: fileURL)

    print("Loaded entity: \(entity.name) (\(entity.id))")
    print("Periods: \(periods.count)")
    print("Accounts: \(accounts.count)")

    // Build Income Statement
    let incomeStatement = try IncomeStatement(
        entity: entity,
        periods: periods,
        accounts: accounts.filter { $0.incomeStatementRole != nil }
    )

    print("\nIncome Statement:")
    print("  Revenue Accounts: \(incomeStatement.revenueAccounts.count)")
    print("  Expense Accounts: \(incomeStatement.expenseAccounts.count)")

    let q1 = periods[0]
    if let revenue = incomeStatement.totalRevenue[q1] {
        print("  Q1 Total Revenue: \(revenue.currency())")
    }
    if let netIncome = incomeStatement.netIncome[q1] {
        print("  Q1 Net Income: \(netIncome.currency())")
    }

    // Build Balance Sheet
    let balanceSheet = try BalanceSheet(
        entity: entity,
        periods: periods,
        accounts: accounts.filter { $0.balanceSheetRole != nil }
    )

    print("\nBalance Sheet:")
    print("  Asset Accounts: \(balanceSheet.assetAccounts.count)")
    print("  Liability Accounts: \(balanceSheet.liabilityAccounts.count)")
    print("  Equity Accounts: \(balanceSheet.equityAccounts.count)")

    if let totalAssets = balanceSheet.totalAssets[q1] {
        print("  Q1 Total Assets: \(totalAssets.currency())")
    }

    // Build Cash Flow Statement
    let cashFlowStatement = try CashFlowStatement(
        entity: entity,
        periods: periods,
        accounts: accounts.filter { $0.cashFlowRole != nil }
    )

    print("\nCash Flow Statement:")
    print("  Operating Accounts: \(cashFlowStatement.operatingAccounts.count)")
    print("  Investing Accounts: \(cashFlowStatement.investingAccounts.count)")
    print("  Financing Accounts: \(cashFlowStatement.financingAccounts.count)")

} catch {
    print("Error loading financial statements: \(error)")
}
```

---

## CSV Ingestion

### CSV Format Structure

The BusinessMath CSV format uses columns for account metadata and periods:

```csv
Account Name,Account Type,Income Statement Role,Balance Sheet Role,Cash Flow Role,Q1 2024,Q2 2024,Q3 2024,Q4 2024
Product Revenue,Revenue,productRevenue,,,100000,110000,120000,130000
Depreciation,Expense,depreciationAmortization,,depreciationAmortizationAddback,5000,5100,5200,5300
```

### CSV Column Structure

**Required Columns:**
- `Account Name` - Name of the account
- At least one role column (Income Statement Role, Balance Sheet Role, or Cash Flow Role)
- Period value columns (e.g., "Q1 2024", "Q2 2024")

**Optional Columns:**
- `Account Type` - Human-readable type (for documentation)
- Additional metadata columns

**Role Columns:**
- `Income Statement Role` - IncomeStatementRole enum case (or empty)
- `Balance Sheet Role` - BalanceSheetRole enum case (or empty)
- `Cash Flow Role` - CashFlowRole enum case (or empty)

### Swift Code: Loading CSV

```swift
import Foundation
import BusinessMath

// MARK: - CSV Parsing Configuration

struct CSVConfig {
    let nameColumn: String
    let isRoleColumn: String
    let bsRoleColumn: String
    let cfsRoleColumn: String
    let periodColumns: [String]
    let skipHeader: Bool

    init(
        nameColumn: String = "Account Name",
        isRoleColumn: String = "Income Statement Role",
        bsRoleColumn: String = "Balance Sheet Role",
        cfsRoleColumn: String = "Cash Flow Role",
        periodColumns: [String],
        skipHeader: Bool = true
    ) {
        self.nameColumn = nameColumn
        self.isRoleColumn = isRoleColumn
        self.bsRoleColumn = bsRoleColumn
        self.cfsRoleColumn = cfsRoleColumn
        self.periodColumns = periodColumns
        self.skipHeader = skipHeader
    }
}

// MARK: - CSV Parsing Functions

func parseCSVRow(_ row: String) -> [String] {
    // Simple CSV parser (handles basic cases)
    // For production, use a robust CSV library like SwiftCSV
    return row.components(separatedBy: ",")
}

func parsePeriodFromColumnName(_ columnName: String) -> Period? {
    // Parse "Q1 2024" format
    let pattern = #"Q([1-4]) ([0-9]{4})"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: columnName, range: NSRange(columnName.startIndex..., in: columnName)) else {
        return nil
    }

    let quarterRange = Range(match.range(at: 1), in: columnName)!
    let yearRange = Range(match.range(at: 2), in: columnName)!

    let quarter = Int(columnName[quarterRange])!
    let year = Int(columnName[yearRange])!

    return Period.quarter(year: year, quarter: quarter)
}

func loadFinancialStatementsFromCSV(
    fileURL: URL,
    entity: Entity,
    config: CSVConfig
) throws -> (periods: [Period], accounts: [Account<Double>]) {
    // 1. Load CSV file
    let csvString = try String(contentsOf: fileURL, encoding: .utf8)
    let rows = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }

    guard !rows.isEmpty else {
        throw NSError(domain: "CSVIngestion", code: 1,
                     userInfo: [NSLocalizedDescriptionKey: "CSV file is empty"])
    }

    // 2. Parse header
    let headerRow = parseCSVRow(rows[0])
    guard let nameIndex = headerRow.firstIndex(of: config.nameColumn),
          let isRoleIndex = headerRow.firstIndex(of: config.isRoleColumn),
          let bsRoleIndex = headerRow.firstIndex(of: config.bsRoleColumn),
          let cfsRoleIndex = headerRow.firstIndex(of: config.cfsRoleColumn) else {
        throw NSError(domain: "CSVIngestion", code: 2,
                     userInfo: [NSLocalizedDescriptionKey: "Required columns not found in header"])
    }

    // 3. Find period column indices and parse periods
    var periodIndices: [(index: Int, period: Period)] = []
    for (index, columnName) in headerRow.enumerated() {
        if config.periodColumns.contains(columnName),
           let period = parsePeriodFromColumnName(columnName) {
            periodIndices.append((index: index, period: period))
        }
    }

    guard !periodIndices.isEmpty else {
        throw NSError(domain: "CSVIngestion", code: 3,
                     userInfo: [NSLocalizedDescriptionKey: "No valid period columns found"])
    }

    let periods = periodIndices.map { $0.period }

    // 4. Parse account rows
    var accounts: [Account<Double>] = []
    let dataRows = config.skipHeader ? Array(rows.dropFirst()) : rows

    for (rowNum, rowString) in dataRows.enumerated() {
        let columns = parseCSVRow(rowString)

        guard columns.count > max(nameIndex, isRoleIndex, bsRoleIndex, cfsRoleIndex) else {
            print("Warning: Row \(rowNum + 1) has insufficient columns, skipping")
            continue
        }

        let name = columns[nameIndex].trimmingCharacters(in: .whitespaces)
        let isRoleStr = columns[isRoleIndex].trimmingCharacters(in: .whitespaces)
        let bsRoleStr = columns[bsRoleIndex].trimmingCharacters(in: .whitespaces)
        let cfsRoleStr = columns[cfsRoleIndex].trimmingCharacters(in: .whitespaces)

        // Parse roles
        let incomeStatementRole = isRoleStr.isEmpty ? nil : parseIncomeStatementRole(from: isRoleStr)
        let balanceSheetRole = bsRoleStr.isEmpty ? nil : parseBalanceSheetRole(from: bsRoleStr)
        let cashFlowRole = cfsRoleStr.isEmpty ? nil : parseCashFlowRole(from: cfsRoleStr)

        // Validate: at least one role
        guard incomeStatementRole != nil || balanceSheetRole != nil || cashFlowRole != nil else {
            print("Warning: Account '\(name)' has no roles, skipping")
            continue
        }

        // Parse values
        var values: [Double] = []
        for (index, _) in periodIndices {
            guard columns.count > index else {
                throw NSError(domain: "CSVIngestion", code: 4,
                             userInfo: [NSLocalizedDescriptionKey: "Row \(rowNum + 1): Missing value for period column"])
            }

            let valueStr = columns[index].trimmingCharacters(in: .whitespaces)
            guard let value = Double(valueStr) else {
                throw NSError(domain: "CSVIngestion", code: 5,
                             userInfo: [NSLocalizedDescriptionKey: "Row \(rowNum + 1): Invalid numeric value '\(valueStr)'"])
            }
            values.append(value)
        }

        // Create account
        let timeSeries = TimeSeries(periods: periods, values: values)
        let account = try Account(
            entity: entity,
            name: name,
            incomeStatementRole: incomeStatementRole,
            balanceSheetRole: balanceSheetRole,
            cashFlowRole: cashFlowRole,
            timeSeries: timeSeries
        )

        accounts.append(account)
    }

    return (periods: periods, accounts: accounts)
}
```

### Usage Example: Loading CSV

```swift
import Foundation
import BusinessMath

// Define entity
let entity = Entity(
    id: "AAPL",
    primaryType: .ticker,
    name: "Apple Inc."
)

// Define CSV configuration
let config = CSVConfig(
    periodColumns: ["Q1 2024", "Q2 2024", "Q3 2024", "Q4 2024"],
    skipHeader: true
)

// Load financial statements from CSV file
let fileURL = URL(fileURLWithPath: "Examples/financial-statements-example.csv")

do {
    let (periods, accounts) = try loadFinancialStatementsFromCSV(
        fileURL: fileURL,
        entity: entity,
        config: config
    )

    print("Loaded \(accounts.count) accounts for \(periods.count) periods")

    // Build statements
    let incomeStatement = try IncomeStatement(
        entity: entity,
        periods: periods,
        accounts: accounts
    )

    print("Income Statement created with \(incomeStatement.revenueAccounts.count) revenue accounts")

} catch {
    print("Error loading CSV: \(error)")
}
```

---

## Example Files

The `Examples/` directory contains:

1. **financial-statements-example.json** - Complete JSON example with Apple-like financial data
   - Entity metadata (ticker, name)
   - 4 quarterly periods (Q1-Q4 2024)
   - 39 accounts across all three statements
   - Multi-role accounts (Depreciation, Inventory, etc.)

2. **financial-statements-example.csv** - Same data in CSV format
   - Column-based structure
   - Role columns for IS/BS/CFS
   - Period columns for Q1-Q4 2024

3. **csv-mapping-config.json** - Configuration file explaining CSV column mapping
   - Entity configuration
   - Period parsing rules
   - Role mapping documentation
   - Validation rules
   - Examples of single-role and multi-role accounts

---

## Complete Working Example

Here's a complete example that loads data and performs analysis:

```swift
import Foundation
import BusinessMath

// MARK: - Complete Data Ingestion Example

func completeDataIngestionExample() throws {
    // 1. Load from JSON
    let jsonURL = URL(fileURLWithPath: "Examples/financial-statements-example.json")
    let (entity, periods, accounts) = try loadFinancialStatementsFromJSON(fileURL: jsonURL)

    print("📊 Loaded Financial Data")
    print("  Entity: \(entity.name) (\(entity.id))")
    print("  Periods: \(periods.count)")
    print("  Accounts: \(accounts.count)")
    print()

    // 2. Build three statements
    let incomeStatement = try IncomeStatement(entity: entity, periods: periods, accounts: accounts)
    let balanceSheet = try BalanceSheet(entity: entity, periods: periods, accounts: accounts)
    let cashFlowStatement = try CashFlowStatement(entity: entity, periods: periods, accounts: accounts)

    // 3. Analyze Q4 2024
    let q4 = Period.quarter(year: 2024, quarter: 4)

    guard let revenue = incomeStatement.totalRevenue[q4],
          let netIncome = incomeStatement.netIncome[q4],
          let totalAssets = balanceSheet.totalAssets[q4],
          let totalEquity = balanceSheet.totalEquity[q4],
          let operatingCF = cashFlowStatement.operatingCashFlow[q4],
          let freeCF = cashFlowStatement.freeCashFlow[q4] else {
        print("Error: Missing Q4 2024 data")
        return
    }

    print("📈 Q4 2024 Financial Summary")
    print()
    print("Income Statement:")
    print("  Total Revenue:    \(revenue.currency())")
    print("  Net Income:       \(netIncome.currency())")
    print("  Net Margin:       \((netIncome / revenue * 100).number())%")
    print()
    print("Balance Sheet:")
    print("  Total Assets:     \(totalAssets.currency())")
    print("  Total Equity:     \(totalEquity.currency())")
    print("  ROE:              \((netIncome / totalEquity * 100).number())%")
    print()
    print("Cash Flow Statement:")
    print("  Operating CF:     \(operatingCF.currency())")
    print("  Free Cash Flow:   \(freeCF.currency())")
    print("  FCF Margin:       \((freeCF / revenue * 100).number())%")
    print()

    // 4. Multi-period analysis
    print("📊 Multi-Period Analysis")
    print()

    for period in periods {
        guard let revenue = incomeStatement.totalRevenue[period],
              let netIncome = incomeStatement.netIncome[period] else {
            continue
        }

        print("  \(period): Revenue \(revenue.currency()), Net Income \(netIncome.currency())")
    }
    print()

    // 5. Growth analysis
    if let q1Revenue = incomeStatement.totalRevenue[periods[0]],
       let q4Revenue = incomeStatement.totalRevenue[periods[3]] {
        let growthRate = ((q4Revenue / q1Revenue) - 1) * 100
        print("📈 Year-over-Year Growth")
        print("  Revenue Growth: \(growthRate.number())%")
    }
}

// Run the example
try completeDataIngestionExample()
```

---

## Best Practices

### 1. Validate Data Before Creating Statements

```swift
// Validate entity consistency
let entities = Set(accounts.map { $0.entity })
guard entities.count == 1 else {
    throw DataIngestionError.multipleEntities
}

// Validate period consistency
for account in accounts {
    guard account.timeSeries.periods == periods else {
        throw DataIngestionError.periodMismatch(account.name)
    }
}
```

### 2. Handle Missing Data Gracefully

```swift
// Option 1: Filter out accounts with missing data
let validAccounts = accounts.filter { account in
    account.timeSeries.values.allSatisfy { !$0.isNaN && !$0.isInfinite }
}

// Option 2: Replace missing values with 0
let cleanedAccounts = accounts.map { account in
    let cleanedValues = account.timeSeries.values.map { $0.isNaN ? 0.0 : $0 }
    let cleanedSeries = TimeSeries(periods: account.timeSeries.periods, values: cleanedValues)
    return try! Account(
        entity: account.entity,
        name: account.name,
        incomeStatementRole: account.incomeStatementRole,
        balanceSheetRole: account.balanceSheetRole,
        cashFlowRole: account.cashFlowRole,
        timeSeries: cleanedSeries
    )
}
```

### 3. Use Scale Factors Appropriately

```swift
// If data is in millions, scale appropriately
let scaleFactor = 1_000_000.0

let scaledValues = rawValues.map { $0 * scaleFactor }
let timeSeries = TimeSeries(periods: periods, values: scaledValues)
```

### 4. Validate Role Mappings

```swift
// Create a validation function
func validateRoleMapping(_ roleString: String, type: String) -> Bool {
    switch type {
    case "incomeStatement":
        return parseIncomeStatementRole(from: roleString) != nil
    case "balanceSheet":
        return parseBalanceSheetRole(from: roleString) != nil
    case "cashFlow":
        return parseCashFlowRole(from: roleString) != nil
    default:
        return false
    }
}

// Use before parsing
guard validateRoleMapping(roleString, type: "incomeStatement") else {
    print("Warning: Invalid role '\(roleString)'")
    // Handle gracefully
}
```

### 5. Log Ingestion Statistics

```swift
// Track ingestion metrics
struct IngestionStats {
    var totalAccounts: Int = 0
    var incomeStatementAccounts: Int = 0
    var balanceSheetAccounts: Int = 0
    var cashFlowAccounts: Int = 0
    var multiRoleAccounts: Int = 0
    var skippedAccounts: Int = 0

    mutating func recordAccount(_ account: Account<Double>) {
        totalAccounts += 1

        var roleCount = 0
        if account.incomeStatementRole != nil {
            incomeStatementAccounts += 1
            roleCount += 1
        }
        if account.balanceSheetRole != nil {
            balanceSheetAccounts += 1
            roleCount += 1
        }
        if account.cashFlowRole != nil {
            cashFlowAccounts += 1
            roleCount += 1
        }

        if roleCount > 1 {
            multiRoleAccounts += 1
        }
    }

    func printSummary() {
        print("Ingestion Summary:")
        print("  Total Accounts: \(totalAccounts)")
        print("  IS Accounts: \(incomeStatementAccounts)")
        print("  BS Accounts: \(balanceSheetAccounts)")
        print("  CFS Accounts: \(cashFlowAccounts)")
        print("  Multi-Role: \(multiRoleAccounts)")
        print("  Skipped: \(skippedAccounts)")
    }
}
```

---

## Troubleshooting

### Issue: "Account must have at least one role"

**Cause:** Account JSON/CSV row has no role columns filled in.

**Fix:** Ensure at least one of `incomeStatementRole`, `balanceSheetRole`, or `cashFlowRole` is specified:

```json
{
  "name": "Revenue",
  "incomeStatementRole": "productRevenue",  // ✅ At least one role
  "values": [100, 110, 120]
}
```

### Issue: "Values count doesn't match periods count"

**Cause:** Number of values in account doesn't match number of periods.

**Fix:** Ensure all accounts have the same number of values as periods:

```json
{
  "periods": [
    {"type": "quarter", "year": 2024, "quarter": 1},
    {"type": "quarter", "year": 2024, "quarter": 2}
  ],
  "accounts": [
    {
      "name": "Revenue",
      "incomeStatementRole": "revenue",
      "values": [100, 110]  // ✅ 2 values for 2 periods
    }
  ]
}
```

### Issue: "Unknown role 'revenueProduct'"

**Cause:** Role string doesn't match any enum case.

**Fix:** Use exact enum case names (camelCase):

```
❌ "revenueProduct"
✅ "productRevenue"

❌ "cost_of_goods_sold"
✅ "costOfGoodsSold"
```

See [Documentation/FinancialStatements.md](FinancialStatements.md) for complete role enum listings.

### Issue: CSV parser doesn't handle quoted values

**Cause:** Simple CSV parser doesn't handle commas within quoted strings.

**Fix:** Use a robust CSV library or escape commas:

```swift
// Option 1: Use SwiftCSV library
import SwiftCSV

let csv = try CSV<Named>(url: fileURL)

// Option 2: Pre-process to escape commas
let processedCSV = csvString.replacingOccurrences(
    of: #""([^"]*),([^"]*)""#,
    with: #""$1\u{FFFC}$2""#,
    options: .regularExpression
)
```

### Issue: Date parsing fails for custom periods

**Cause:** Date format doesn't match ISO 8601.

**Fix:** Use ISO 8601 format: `YYYY-MM-DD` or `YYYY-MM-DDTHH:MM:SSZ`:

```json
{
  "type": "custom",
  "start": "2024-01-01",  // ✅ ISO 8601
  "end": "2024-03-31"
}
```

---

## See Also

- [Documentation/FinancialStatements.md](FinancialStatements.md) - Complete API reference
- [MIGRATION_GUIDE_v2.0.md](../MIGRATION_GUIDE_v2.0.md) - Migration from v1.x
- [Examples/financial-statements-example.json](../Examples/financial-statements-example.json) - Example JSON file
- [Examples/financial-statements-example.csv](../Examples/financial-statements-example.csv) - Example CSV file

---

**Version History:**
- **v2.0.0** (2026-01-06): Initial data ingestion guide for role-based architecture

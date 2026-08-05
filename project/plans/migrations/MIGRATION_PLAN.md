# Account Type Migration Plan

## Overview

This document outlines the migration from metadata-based account categorization to type-safe subtype enums.

## Problem with Old Approach

The original implementation used string-based metadata to categorize accounts:

```swift
var metadata = AccountMetadata()
metadata.category = "COGS"  // Fragile: typos cause silent failures
metadata.tags = ["D&A"]     // Inconsistent: different tests use different strings

let account = try Account(
    entity: entity,
    name: "Cost of Goods Sold",
    type: .expense,
    timeSeries: series,
    metadata: metadata
)
```

**Issues:**
- **Typo-prone**: "COGS" vs "cogs" vs "Cost of Goods Sold" all treated differently
- **No compile-time safety**: Wrong category strings accepted silently
- **Inconsistent filtering**: Logic scattered across multiple files
- **Hard to maintain**: Adding new categories requires updating filter logic everywhere

## New Approach: Type-Safe Subtypes

We've introduced granular subtype enums that are part of the Account structure:

```swift
public enum AssetType { case cashAndEquivalents, accountsReceivable, inventory, ... }
public enum LiabilityType { case shortTermDebt, longTermDebt, bonds, ... }
public enum ExpenseType { case costOfGoodsSold, operatingExpense, depreciationAmortization, ... }
public enum EquityType { case commonStock, retainedEarnings, ... }
```

### Account Structure

```swift
public struct Account<T> {
    public let type: AccountType              // .asset, .liability, .expense, etc.
    public let assetType: AssetType?          // Only set if type == .asset
    public let liabilityType: LiabilityType?  // Only set if type == .liability
    public let expenseType: ExpenseType?      // Only set if type == .expense
    public let equityType: EquityType?        // Only set if type == .equity
    public var metadata: AccountMetadata?     // Still available for custom data
}
```

### New Account Creation

```swift
let account = try Account(
    entity: entity,
    name: "Cost of Goods Sold",
    type: .expense,
    timeSeries: series,
    expenseType: .costOfGoodsSold  // Type-safe!
)
```

## Migration Examples

### Assets

**Old:**
```swift
var cashMetadata = AccountMetadata()
cashMetadata.category = "Current"

let cash = try Account(
    entity: entity,
    name: "Cash",
    type: .asset,
    timeSeries: series,
    metadata: cashMetadata
)
```

**New:**
```swift
let cash = try Account(
    entity: entity,
    name: "Cash",
    type: .asset,
    timeSeries: series,
    assetType: .cashAndEquivalents
)
```

### Liabilities

**Old:**
```swift
var debtMetadata = AccountMetadata()
debtMetadata.category = "Debt"

let debt = try Account(
    entity: entity,
    name: "Senior Notes",
    type: .liability,
    timeSeries: series,
    metadata: debtMetadata
)
```

**New:**
```swift
let debt = try Account(
    entity: entity,
    name: "Senior Notes",
    type: .liability,
    timeSeries: series,
    liabilityType: .longTermDebt
)
```

### Expenses

**Old:**
```swift
var cogsMetadata = AccountMetadata()
cogsMetadata.category = "COGS"

let cogs = try Account(
    entity: entity,
    name: "Cost of Goods Sold",
    type: .expense,
    timeSeries: series,
    metadata: cogsMetadata
)

var daMetadata = AccountMetadata()
daMetadata.category = "Operating"
daMetadata.tags = ["D&A"]

let depreciation = try Account(
    entity: entity,
    name: "Depreciation",
    type: .expense,
    timeSeries: series,
    metadata: daMetadata
)
```

**New:**
```swift
let cogs = try Account(
    entity: entity,
    name: "Cost of Goods Sold",
    type: .expense,
    timeSeries: series,
    expenseType: .costOfGoodsSold
)

let depreciation = try Account(
    entity: entity,
    name: "Depreciation",
    type: .expense,
    timeSeries: series,
    expenseType: .depreciationAmortization
)
```

### Equity

**Old:**
```swift
var retainedMetadata = AccountMetadata()
retainedMetadata.category = "Retained"

let retained = try Account(
    entity: entity,
    name: "Retained Earnings",
    type: .equity,
    timeSeries: series,
    metadata: retainedMetadata
)
```

**New:**
```swift
let retained = try Account(
    entity: entity,
    name: "Retained Earnings",
    type: .equity,
    timeSeries: series,
    equityType: .retainedEarnings
)
```

## Test Files Requiring Updates

Based on the test failures, these files need migration:

1. **BalanceSheetTests.swift** (16 failures)
   - Update asset accounts to use `assetType`
   - Update liability accounts to use `liabilityType`
   - Update equity accounts to use `equityType`

2. **IncomeStatementTests.swift** (10 failures)
   - Update expense accounts to use `expenseType`
   - Remove reliance on metadata.category and metadata.tags

3. **FinancialRatiosTests.swift** (9 failures)
   - Uses both BalanceSheet and IncomeStatement
   - Update all account creations

4. **DebtCovenantsTests.swift** (13 failures)
   - Update debt-related accounts to use `liabilityType`

5. **ValuationMetricsTests.swift** (5 failures)
   - Update accounts across all statements

6. **DuPontAnalysisTests.swift** (6 failures)
   - Update ROE decomposition accounts

## Updated Filtering Logic

### BalanceSheet

**Old:**
```swift
public var currentAssets: TimeSeries<T> {
    let current = assetAccounts.filter {
        $0.metadata?.category?.lowercased().contains("current") == true
    }
    return aggregateAccounts(current)
}
```

**New:**
```swift
public var currentAssets: TimeSeries<T> {
    let current = assetAccounts.filter {
        guard let assetType = $0.assetType else { return false }
        return assetType == .cashAndEquivalents ||
               assetType == .accountsReceivable ||
               assetType == .inventory ||
               assetType == .otherCurrentAsset
    }
    return aggregateAccounts(current)
}
```

### IncomeStatement

**Old:**
```swift
public var grossProfit: TimeSeries<T> {
    let cogs = expenseAccounts.filter { $0.metadata?.category == "COGS" }
    let cogsTotal = aggregateAccounts(cogs)
    return totalRevenue - cogsTotal
}
```

**New:**
```swift
public var grossProfit: TimeSeries<T> {
    let cogs = expenseAccounts.filter { $0.expenseType == .costOfGoodsSold }
    let cogsTotal = aggregateAccounts(cogs)
    return totalRevenue - cogsTotal
}
```

## Migration Checklist

### Phase 1: Core Types ✅
- [x] Create AssetType enum
- [x] Create LiabilityType enum
- [x] Create ExpenseType enum
- [x] Create EquityType enum
- [x] Add subtype fields to Account struct
- [x] Update Account initializer

### Phase 2: Financial Statements ✅
- [x] Update BalanceSheet filtering logic
- [x] Update IncomeStatement filtering logic
- [x] Update CashFlowStatement (no changes needed)

### Phase 3: Test Updates 🔄
- [ ] Update BalanceSheetTests.swift
- [ ] Update IncomeStatementTests.swift
- [ ] Update FinancialRatiosTests.swift
- [ ] Update DebtCovenantsTests.swift
- [ ] Update ValuationMetricsTests.swift
- [ ] Update DuPontAnalysisTests.swift
- [ ] Update any other failing tests

### Phase 4: New Features 📋
- [ ] Create OperationalMetrics struct
- [ ] Create FinancialPeriodSummary struct
- [ ] Create MultiPeriodReport struct
- [ ] Write Chesapeake Energy tests

## Metadata Still Useful For

The `metadata` field is still valuable for:

- **Custom descriptions**: Detailed account explanations
- **External IDs**: Integration with accounting systems
- **Custom tags**: Application-specific groupings
- **Display names**: User-friendly labels

Metadata should **not** be used for:

- **Accounting categorization**: Use subtypes instead
- **Statement calculations**: Use subtypes instead
- **Financial ratios**: Use subtypes instead

## Benefits of New Approach

1. **Type Safety**: Compiler catches invalid categorizations
2. **Consistency**: Same categorization across all tests
3. **Discoverability**: IDE autocomplete shows all valid subtypes
4. **Performance**: Direct enum comparison vs string matching
5. **Maintainability**: Single source of truth for categories
6. **Documentation**: Enum cases are self-documenting

## Timeline

1. **Document migration plan** ✅ (This document)
2. **Update test files** (Next step - ~68 test cases)
3. **Verify all tests pass**
4. **Build new FinancialPeriodSummary features**
5. **Write Chesapeake Energy integration tests**

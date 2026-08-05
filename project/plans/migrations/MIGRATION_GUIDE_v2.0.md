# Migration Guide: BusinessMath v2.0

## Overview

BusinessMath v2.0 introduces a **role-based financial statement architecture** that provides more flexibility and accuracy in financial modeling. This guide will help you migrate from v1.x to v2.0.

### What Changed?

The primary change is moving from a **type-based** approach to a **role-based** approach for financial accounts:

- **Old (v1.x)**: Accounts had a single `type` (e.g., `.revenue`, `.expense`, `.asset`)
- **New (v2.0)**: Accounts declare explicit roles via `incomeStatementRole`, `balanceSheetRole`, and `cashFlowRole`

### Why the Change?

Real-world financial accounts often appear in multiple statements:
- **Depreciation & Amortization** appears in both Income Statement (expense) and Cash Flow Statement (add-back)
- **Inventory** appears in both Balance Sheet (asset) and Cash Flow Statement (working capital change)
- **Accounts Receivable** appears in both Balance Sheet (asset) and Cash Flow Statement (change in receivables)

The role-based system allows accounts to accurately represent these multi-statement relationships.

---

## Breaking Changes Summary

| Severity | Change | Impact |
|----------|--------|--------|
| 🔴 **HIGH** | Account initializer API changed | All Account creation code must be updated |
| 🔴 **HIGH** | Statement initializers changed | All statement creation code must be updated |
| 🟡 **MEDIUM** | Error types consolidated | Error handling may need updates |
| 🟢 **LOW** | Some enum cases renamed | Minor updates to role references |

---

## Migration Steps

### Step 1: Update Account Creation

#### Pattern 1: Revenue Accounts

**Before (v1.x):**
```swift
let revenue = try Account(
    entity: myEntity,
    name: "Product Revenue",
    type: .revenue,
    timeSeries: revenueSeries
)
```

**After (v2.0):**
```swift
let revenue = try Account(
    entity: myEntity,
    name: "Product Revenue",
    incomeStatementRole: .productRevenue,  // or .subscriptionRevenue, etc.
    timeSeries: revenueSeries
)
```

#### Pattern 2: Expense Accounts

**Before (v1.x):**
```swift
let cogs = try Account(
    entity: myEntity,
    name: "Cost of Goods Sold",
    type: .expense,
    expenseType: .cogs,
    timeSeries: cogsSeries
)
```

**After (v2.0):**
```swift
let cogs = try Account(
    entity: myEntity,
    name: "Cost of Goods Sold",
    incomeStatementRole: .costOfGoodsSold,
    timeSeries: cogsSeries
)
```

#### Pattern 3: Asset Accounts

**Before (v1.x):**
```swift
let cash = try Account(
    entity: myEntity,
    name: "Cash and Cash Equivalents",
    type: .asset,
    assetType: .cash,
    timeSeries: cashSeries
)
```

**After (v2.0):**
```swift
let cash = try Account(
    entity: myEntity,
    name: "Cash and Cash Equivalents",
    balanceSheetRole: .cashAndEquivalents,
    timeSeries: cashSeries
)
```

#### Pattern 4: Liability Accounts

**Before (v1.x):**
```swift
let debt = try Account(
    entity: myEntity,
    name: "Long-Term Debt",
    type: .liability,
    liabilityType: .longTermDebt,
    timeSeries: debtSeries
)
```

**After (v2.0):**
```swift
let debt = try Account(
    entity: myEntity,
    name: "Long-Term Debt",
    balanceSheetRole: .longTermDebt,
    timeSeries: debtSeries
)
```

#### Pattern 5: Equity Accounts

**Before (v1.x):**
```swift
let equity = try Account(
    entity: myEntity,
    name: "Retained Earnings",
    type: .equity,
    equityType: .retainedEarnings,
    timeSeries: equitySeries
)
```

**After (v2.0):**
```swift
let equity = try Account(
    entity: myEntity,
    name: "Retained Earnings",
    balanceSheetRole: .retainedEarnings,
    timeSeries: equitySeries
)
```

#### Pattern 6: Cash Flow Accounts

**Before (v1.x):**
```swift
let capex = try Account(
    entity: myEntity,
    name: "Capital Expenditures",
    type: .cashFlow,
    cashFlowType: .investing,
    timeSeries: capexSeries
)
```

**After (v2.0):**
```swift
let capex = try Account(
    entity: myEntity,
    name: "Capital Expenditures",
    cashFlowRole: .capitalExpenditures,
    timeSeries: capexSeries
)
```

---

### Step 2: Update Statement Creation

All financial statements now use a **single `accounts:` parameter** instead of separate arrays for different account types.

#### Income Statement

**Before (v1.x):**
```swift
let incomeStmt = try IncomeStatement(
    entity: myEntity,
    periods: periods,
    revenueAccounts: [productRevenue, serviceRevenue],
    expenseAccounts: [cogs, salaries, marketing]
)
```

**After (v2.0):**
```swift
let incomeStmt = try IncomeStatement(
    entity: myEntity,
    periods: periods,
    accounts: [productRevenue, serviceRevenue, cogs, salaries, marketing]
)
```

The statement automatically categorizes accounts based on their `incomeStatementRole`.

#### Balance Sheet

**Before (v1.x):**
```swift
let balanceSheet = try BalanceSheet(
    entity: myEntity,
    periods: periods,
    assetAccounts: [cash, accountsReceivable, inventory],
    liabilityAccounts: [accountsPayable, longTermDebt],
    equityAccounts: [commonStock, retainedEarnings]
)
```

**After (v2.0):**
```swift
let balanceSheet = try BalanceSheet(
    entity: myEntity,
    periods: periods,
    accounts: [cash, accountsReceivable, inventory,
               accountsPayable, longTermDebt,
               commonStock, retainedEarnings]
)
```

The statement automatically categorizes accounts based on their `balanceSheetRole`.

#### Cash Flow Statement

**Before (v1.x):**
```swift
let cashFlowStmt = try CashFlowStatement(
    entity: myEntity,
    periods: periods,
    operatingAccounts: [netIncome, depreciationAddback],
    investingAccounts: [capitalExpenditures],
    financingAccounts: [proceedsFromDebt]
)
```

**After (v2.0):**
```swift
let cashFlowStmt = try CashFlowStatement(
    entity: myEntity,
    periods: periods,
    accounts: [netIncome, depreciationAddback,
               capitalExpenditures,
               proceedsFromDebt]
)
```

The statement automatically categorizes accounts based on their `cashFlowRole`.

---

### Step 3: Handle Multi-Role Accounts (New Feature!)

v2.0 allows accounts to have **multiple roles** across different statements:

```swift
// Depreciation appears in BOTH Income Statement and Cash Flow Statement
let depreciation = try Account(
    entity: myEntity,
    name: "Depreciation & Amortization",
    incomeStatementRole: .depreciationAmortization,    // IS: Expense
    cashFlowRole: .depreciationAmortizationAddback,     // CFS: Add-back
    timeSeries: depreciationSeries
)

// Use it in BOTH statements
let incomeStmt = try IncomeStatement(
    entity: myEntity,
    periods: periods,
    accounts: [revenue, depreciation]  // Uses incomeStatementRole
)

let cashFlowStmt = try CashFlowStatement(
    entity: myEntity,
    periods: periods,
    accounts: [netIncome, depreciation]  // Uses cashFlowRole
)
```

---

### Step 4: Update Error Handling

v2.0 consolidates error types for better consistency:

**Before (v1.x):**
```swift
do {
    let stmt = try IncomeStatement(...)
} catch IncomeStatementError.entityMismatch {
    // Handle entity mismatch
} catch IncomeStatementError.periodMismatch {
    // Handle period mismatch
}
```

**After (v2.0):**
```swift
do {
    let stmt = try IncomeStatement(...)
} catch FinancialModelError.entityMismatch(let expected, let found, let accountName) {
    // Handle entity mismatch - more detailed error info
} catch FinancialModelError.periodMismatch(let expected, let found, let accountName) {
    // Handle period mismatch - more detailed error info
}
```

**New Error Cases:**
- `FinancialModelError.accountMustHaveAtLeastOneRole` - Account must have at least one role (IS, BS, or CFS)
- `AccountError.invalidName` - Account name cannot be empty or whitespace
- `AccountError.emptyTimeSeries` - Account must have at least one period of data

---

## API Reference: Old → New

### Account Type Mappings

#### Income Statement Roles

| Old (v1.x) | New (v2.0) |
|------------|------------|
| `type: .revenue` | `incomeStatementRole: .revenue` |
| `type: .revenue` (product) | `incomeStatementRole: .productRevenue` |
| `type: .revenue` (subscription) | `incomeStatementRole: .subscriptionRevenue` |
| `type: .expense, expenseType: .cogs` | `incomeStatementRole: .costOfGoodsSold` |
| `type: .expense, expenseType: .costOfServices` | `incomeStatementRole: .costOfServices` |
| `type: .expense, expenseType: .rnd` | `incomeStatementRole: .researchDevelopment` |
| `type: .expense, expenseType: .salesMarketing` | `incomeStatementRole: .salesMarketing` |
| `type: .expense, expenseType: .generalAdmin` | `incomeStatementRole: .generalAdministrative` |
| `type: .expense, expenseType: .depreciation` | `incomeStatementRole: .depreciationAmortization` |
| `type: .expense, expenseType: .interest` | `incomeStatementRole: .interestExpense` |
| `type: .expense, expenseType: .stockComp` | `incomeStatementRole: .stockBasedCompensation` |

#### Balance Sheet Roles

| Old (v1.x) | New (v2.0) |
|------------|------------|
| `type: .asset, assetType: .cash` | `balanceSheetRole: .cashAndEquivalents` |
| `type: .asset, assetType: .accountsReceivable` | `balanceSheetRole: .accountsReceivable` |
| `type: .asset, assetType: .inventory` | `balanceSheetRole: .inventory` |
| `type: .asset, assetType: .prepaidExpenses` | `balanceSheetRole: .prepaidExpenses` |
| `type: .asset, assetType: .ppe` | `balanceSheetRole: .propertyPlantEquipment` |
| `type: .asset, assetType: .intangibles` | `balanceSheetRole: .intangibleAssets` |
| `type: .asset, assetType: .goodwill` | `balanceSheetRole: .goodwill` |
| `type: .liability, liabilityType: .accountsPayable` | `balanceSheetRole: .accountsPayable` |
| `type: .liability, liabilityType: .accruedExpenses` | `balanceSheetRole: .accruedExpenses` |
| `type: .liability, liabilityType: .deferredRevenue` | `balanceSheetRole: .deferredRevenue` |
| `type: .liability, liabilityType: .shortTermDebt` | `balanceSheetRole: .shortTermDebt` |
| `type: .liability, liabilityType: .longTermDebt` | `balanceSheetRole: .longTermDebt` |
| `type: .equity, equityType: .commonStock` | `balanceSheetRole: .commonStock` |
| `type: .equity, equityType: .retainedEarnings` | `balanceSheetRole: .retainedEarnings` |

#### Cash Flow Roles

| Old (v1.x) | New (v2.0) |
|------------|------------|
| `type: .cashFlow, cashFlowType: .operating` | `cashFlowRole: .netIncome` (or specific operating role) |
| `type: .cashFlow, cashFlowType: .investing` | `cashFlowRole: .capitalExpenditures` (or specific investing role) |
| `type: .cashFlow, cashFlowType: .financing` | `cashFlowRole: .proceedsFromDebt` (or specific financing role) |

**Note:** Cash flow roles are now much more specific. See the `CashFlowRole` enum for all available options.

---

## Troubleshooting

### Error: "Account must have at least one role"

**Cause:** You created an Account without specifying any role (no `incomeStatementRole`, `balanceSheetRole`, or `cashFlowRole`).

**Fix:** Every account must have at least one role:

```swift
// ❌ This will fail
let account = try Account(
    entity: myEntity,
    name: "Revenue",
    timeSeries: series
)

// ✅ This works
let account = try Account(
    entity: myEntity,
    name: "Revenue",
    incomeStatementRole: .revenue,  // Added role
    timeSeries: series
)
```

### Error: "Cannot find type 'AccountType' in scope"

**Cause:** You're still using the old `AccountType` enum, which has been removed.

**Fix:** Use role-specific parameters instead:

```swift
// ❌ Old API (removed)
type: AccountType.revenue

// ✅ New API
incomeStatementRole: .revenue
```

### Error: "Extra argument in call"

**Cause:** You're passing the old multi-parameter statement initializer (e.g., `revenueAccounts:`, `expenseAccounts:`).

**Fix:** Use the single `accounts:` parameter:

```swift
// ❌ Old API
let stmt = try IncomeStatement(
    entity: entity,
    periods: periods,
    revenueAccounts: [...],
    expenseAccounts: [...]
)

// ✅ New API
let stmt = try IncomeStatement(
    entity: entity,
    periods: periods,
    accounts: [...]  // All accounts in one array
)
```

### Statement Doesn't Include My Account

**Cause:** The account's role doesn't match the statement type.

**Fix:** Ensure the account has the appropriate role for that statement:

- **Income Statement** → Account must have `incomeStatementRole`
- **Balance Sheet** → Account must have `balanceSheetRole`
- **Cash Flow Statement** → Account must have `cashFlowRole`

```swift
let revenue = try Account(
    entity: myEntity,
    name: "Revenue",
    incomeStatementRole: .revenue,  // ✅ Will appear in Income Statement
    timeSeries: series
)

let incomeStmt = try IncomeStatement(
    entity: myEntity,
    periods: periods,
    accounts: [revenue]  // ✅ Revenue will be included
)
```

---

## FAQ

### Q: Why did you make this breaking change?

**A:** The old type-based system couldn't accurately model real-world financial accounts that appear in multiple statements. The role-based system provides:
- **Multi-statement support**: Accounts can have roles in multiple statements
- **Better accuracy**: Matches real-world financial reporting
- **More flexibility**: New roles can be added without breaking existing code
- **Clearer semantics**: `incomeStatementRole: .revenue` is more explicit than `type: .revenue`

### Q: Do I have to update all my code at once?

**A:** Yes, this is a breaking change. However, the migration is straightforward:
1. Update Account creation (Step 1)
2. Update Statement creation (Step 2)
3. Run your tests

Most codebases can be migrated in 1-2 hours with find-and-replace.

### Q: Can an account appear in multiple statements?

**A:** Yes! This is one of the key benefits of v2.0:

```swift
let depreciation = try Account(
    entity: myEntity,
    name: "Depreciation",
    incomeStatementRole: .depreciationAmortization,
    cashFlowRole: .depreciationAmortizationAddback,
    timeSeries: series
)

// Use in BOTH statements
let incomeStmt = try IncomeStatement(..., accounts: [depreciation])
let cashFlowStmt = try CashFlowStatement(..., accounts: [depreciation])
```

### Q: What if I only want to use an account in one statement?

**A:** Just specify the single role you need:

```swift
let revenue = try Account(
    entity: myEntity,
    name: "Revenue",
    incomeStatementRole: .revenue,  // Only this role
    timeSeries: series
)
```

### Q: Are there any performance implications?

**A:** No. The role-based system has the same performance characteristics as the old type-based system. Account categorization happens during statement initialization.

### Q: Will there be a v1.x → v2.0 automated migration tool?

**A:** Not currently. The changes are straightforward enough that manual migration is recommended. Most projects can be migrated with careful find-and-replace operations.

### Q: Can I mix old and new APIs?

**A:** No. The old `AccountType` enum and multi-parameter statement initializers have been completely removed in v2.0.

### Q: What about custom account types?

**A:** The role enums (`IncomeStatementRole`, `BalanceSheetRole`, `CashFlowRole`) are extensible. You can add custom cases if needed, though the built-in roles cover most use cases.

---

## Migration Timeline Estimates

| Codebase Size | Estimated Time | Notes |
|---------------|----------------|-------|
| **Small** (<500 lines) | 30-60 minutes | Simple find-and-replace |
| **Medium** (500-2000 lines) | 1-2 hours | Systematic refactoring |
| **Large** (2000-5000 lines) | 2-4 hours | May need scripting |
| **Very Large** (>5000 lines) | 4-8 hours | Recommend Python/regex scripts |

### Recommended Approach:

1. **Phase 1: Account Creation** (40% of time)
   - Find all `Account(` calls
   - Update `type:` → role-specific parameters
   - Run compiler to find remaining issues

2. **Phase 2: Statement Creation** (40% of time)
   - Find all statement initializers
   - Convert multi-parameter → single `accounts:` parameter
   - Run compiler to verify

3. **Phase 3: Testing & Validation** (20% of time)
   - Run full test suite
   - Fix any error handling code
   - Verify financial calculations match

### Automation Scripts:

For large codebases, consider using regex-based scripts. Example Python script:

```python
import re

def migrate_revenue_accounts(content):
    # type: .revenue → incomeStatementRole: .revenue
    content = re.sub(
        r'type: \.revenue(?!Role)',
        r'incomeStatementRole: .revenue',
        content
    )
    return content

def migrate_expense_accounts(content):
    # type: .expense, expenseType: .cogs → incomeStatementRole: .costOfGoodsSold
    content = re.sub(
        r'type: \.expense,\s*expenseType: \.cogs',
        r'incomeStatementRole: .costOfGoodsSold',
        content
    )
    return content

# Apply to all Swift files...
```

---

## Getting Help

- **Issues**: [GitHub Issues](https://github.com/justinpurnell/BusinessMath/issues)
- **Documentation**: See `Documentation/FinancialStatements.md`
- **Examples**: See `Tests/BusinessMathTests/Financial Statements Tests/`

---

## Version History

- **v2.0.0-beta.5** (2026-01-06): Role-based architecture introduced
- **v1.x**: Original type-based architecture (deprecated)

---

**Happy migrating!** 🚀

The new role-based system provides much more flexibility and accuracy for financial modeling. While the migration requires some effort, the improved API will make your financial models more maintainable and accurate.

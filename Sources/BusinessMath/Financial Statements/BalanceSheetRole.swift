import Foundation

/// Granular roles for accounts appearing in Balance Sheets
///
/// This enum provides precise categorization for assets, liabilities, and equity accounts
/// within a Balance Sheet. Each role enables automated aggregation and analysis
/// without relying on string-based account name matching.
///
/// # Role Categories
///
/// **Current Assets**: Assets expected to convert to cash within one year
/// - Cash & equivalents, short-term investments, receivables, inventory
///
/// **Non-Current Assets**: Long-term assets
/// - PP&E, intangibles, goodwill, long-term investments
///
/// **Current Liabilities**: Obligations due within one year
/// - Accounts payable, accrued liabilities, short-term debt, deferred revenue
///
/// **Non-Current Liabilities**: Long-term obligations
/// - Long-term debt, pension obligations, deferred tax liabilities
///
/// **Equity**: Ownership interests
/// - Common/preferred stock, retained earnings, AOCI, treasury stock (contra-equity)
///
/// # Usage
///
/// ```swift
/// // Create a cash account
/// let cashAccount = try Account(
///     entity: myEntity,
///     name: "Cash and Cash Equivalents",
///     timeSeries: cashData,
///     balanceSheetRole: .cashAndEquivalents
/// )
///
/// // Check if account is a current asset
/// if cashAccount.balanceSheetRole?.isCurrentAsset == true {
///     // Include in current asset calculations
/// }
/// ```
public enum BalanceSheetRole: String, Sendable, Hashable, Codable, CaseIterable, StatementRole {
	var roleStatements: String { return "Balance Sheet"}
	
	var description: String {
		var type: String = ""
		if isCurrentAsset { type += "Current Assets" }
		if isNonCurrentAsset { type += "Non-Current Assets"}
		if isCurrentLiability { type += "Current Liabilities"}
		if isNonCurrentLiability { type += "Non-Current Liabilities"}
		if isEquity { type += "Equity"}
		type += ": \(self.rawValue)"
		return type
	}
	
    // ═══════════════════════════════════════════════════════════
    // CURRENT ASSETS
    // ═══════════════════════════════════════════════════════════

    /// Cash and cash equivalents (highly liquid)
    case cashAndEquivalents

    /// Short-term investments (maturity < 1 year)
    case shortTermInvestments

    /// Accounts receivable from customers
    case accountsReceivable

    /// Inventory (raw materials, WIP, finished goods)
    case inventory

    /// Prepaid expenses (insurance, rent, etc.)
    case prepaidExpenses

    /// Other current assets not categorized above
    case otherCurrentAssets

    // ═══════════════════════════════════════════════════════════
    // NON-CURRENT ASSETS
    // ═══════════════════════════════════════════════════════════

    /// Property, Plant & Equipment (gross, before depreciation)
    case propertyPlantEquipment

    /// Accumulated depreciation (contra-asset)
    case accumulatedDepreciation

    /// Intangible assets (patents, trademarks, software)
    case intangibleAssets

    /// Goodwill from acquisitions
    case goodwill

    /// Long-term investments (maturity > 1 year)
    case longTermInvestments

    /// Deferred tax assets
    case deferredTaxAssets

    /// Right-of-use assets (leases under ASC 842)
    case rightOfUseAssets

    /// Other non-current assets not categorized above
    case otherNonCurrentAssets

    // ═══════════════════════════════════════════════════════════
    // CURRENT LIABILITIES
    // ═══════════════════════════════════════════════════════════

    /// Accounts payable to suppliers
    case accountsPayable

    /// Accrued liabilities (wages, taxes, etc.)
    case accruedLiabilities

    /// Short-term debt (maturity < 1 year)
    case shortTermDebt

    /// Current portion of long-term debt
    case currentPortionLongTermDebt

    /// Deferred revenue (unearned revenue)
    case deferredRevenue

    /// Other current liabilities not categorized above
    case otherCurrentLiabilities

    // ═══════════════════════════════════════════════════════════
    // NON-CURRENT LIABILITIES
    // ═══════════════════════════════════════════════════════════

    /// Long-term debt (maturity > 1 year)
    case longTermDebt

    /// Deferred tax liabilities
    case deferredTaxLiabilities

    /// Pension and post-retirement benefit obligations
    case pensionLiabilities

    /// Lease liabilities (leases under ASC 842)
    case leaseLiabilities

    /// Other non-current liabilities not categorized above
    case otherNonCurrentLiabilities

    // ═══════════════════════════════════════════════════════════
    // EQUITY
    // ═══════════════════════════════════════════════════════════

    /// Common stock (par value)
    case commonStock

    /// Preferred stock (par value)
    case preferredStock

    /// Additional paid-in capital (excess over par)
    case additionalPaidInCapital

    /// Retained earnings (cumulative net income - dividends)
    case retainedEarnings

    /// Treasury stock (contra-equity, shares repurchased)
    case treasuryStock

    /// Accumulated Other Comprehensive Income (AOCI)
    case accumulatedOtherComprehensiveIncome

    // ═══════════════════════════════════════════════════════════
    // COMPUTED PROPERTIES
    // ═══════════════════════════════════════════════════════════

    /// Returns `true` if this role represents a current asset
    ///
    /// Includes: cashAndEquivalents, shortTermInvestments, accountsReceivable,
    /// inventory, prepaidExpenses, otherCurrentAssets
    public var isCurrentAsset: Bool {
        [.cashAndEquivalents, .shortTermInvestments, .accountsReceivable,
         .inventory, .prepaidExpenses, .otherCurrentAssets].contains(self)
    }

    /// Returns `true` if this role represents a non-current asset
    ///
    /// Includes: propertyPlantEquipment, accumulatedDepreciation, intangibleAssets,
    /// goodwill, longTermInvestments, deferredTaxAssets, rightOfUseAssets,
    /// otherNonCurrentAssets
    public var isNonCurrentAsset: Bool {
        [.propertyPlantEquipment, .accumulatedDepreciation, .intangibleAssets,
         .goodwill, .longTermInvestments, .deferredTaxAssets,
         .rightOfUseAssets, .otherNonCurrentAssets].contains(self)
    }

    /// Returns `true` if this role represents an asset (current or non-current)
    public var isAsset: Bool {
        isCurrentAsset || isNonCurrentAsset
    }

    /// Returns `true` if this role represents a current liability
    ///
    /// Includes: accountsPayable, accruedLiabilities, shortTermDebt,
    /// currentPortionLongTermDebt, deferredRevenue, otherCurrentLiabilities
    public var isCurrentLiability: Bool {
        [.accountsPayable, .accruedLiabilities, .shortTermDebt,
         .currentPortionLongTermDebt, .deferredRevenue,
         .otherCurrentLiabilities].contains(self)
    }

    /// Returns `true` if this role represents a non-current liability
    ///
    /// Includes: longTermDebt, deferredTaxLiabilities, pensionLiabilities,
    /// leaseLiabilities, otherNonCurrentLiabilities
    public var isNonCurrentLiability: Bool {
        [.longTermDebt, .deferredTaxLiabilities, .pensionLiabilities,
         .leaseLiabilities, .otherNonCurrentLiabilities].contains(self)
    }

    /// Returns `true` if this role represents a liability (current or non-current)
    public var isLiability: Bool {
        isCurrentLiability || isNonCurrentLiability
    }

    /// Returns `true` if this role represents equity
    ///
    /// Includes: commonStock, preferredStock, additionalPaidInCapital,
    /// retainedEarnings, treasuryStock, accumulatedOtherComprehensiveIncome
    public var isEquity: Bool {
        [.commonStock, .preferredStock, .additionalPaidInCapital,
         .retainedEarnings, .treasuryStock,
         .accumulatedOtherComprehensiveIncome].contains(self)
    }

    /// Returns `true` if this role represents a current item (asset or liability)
    public var isCurrent: Bool {
        isCurrentAsset || isCurrentLiability
    }

    /// Returns `true` if this role represents a non-current item (asset or liability)
    ///
    /// Note: Equity is neither current nor non-current
    public var isNonCurrent: Bool {
        isNonCurrentAsset || isNonCurrentLiability
    }

    /// Returns `true` if this role represents debt (short-term or long-term)
    ///
    /// Includes: shortTermDebt, currentPortionLongTermDebt, longTermDebt
    public var isDebt: Bool {
        [.shortTermDebt, .currentPortionLongTermDebt, .longTermDebt].contains(self)
    }
}

import Foundation

/// Granular roles for accounts appearing in Cash Flow Statements
///
/// This enum provides precise categorization for operating, investing, and financing
/// cash flow activities. Each role enables automated aggregation and analysis
/// without relying on string-based account name matching.
///
/// # Role Categories
///
/// **Operating Activities**: Cash from core business operations
/// - Net income (starting point for indirect method)
/// - Non-cash charge add-backs (depreciation, stock-based comp, etc.)
/// - Working capital changes (receivables, inventory, payables)
///
/// **Investing Activities**: Cash from buying/selling long-term assets
/// - Capital expenditures (CapEx)
/// - Asset acquisitions and sales
/// - Investment purchases and sales
///
/// **Financing Activities**: Cash from capital structure changes
/// - Debt issuance and repayment
/// - Equity issuance and repurchases
/// - Dividend payments
///
/// # Special Property: usesChangeInBalance
///
/// Working capital items use period-over-period balance changes rather than
/// direct cash flows. The `usesChangeInBalance` property identifies these.
///
/// # Usage
///
/// ```swift
/// // Create an operating cash flow account
/// let cashFromOpsAccount = try Account(
///     entity: myEntity,
///     name: "Net Income",
///     timeSeries: netIncomeData,
///     cashFlowRole: .netIncome
/// )
///
/// // Create a working capital account that uses balance changes
/// let receivablesChangeAccount = try Account(
///     entity: myEntity,
///     name: "Change in Receivables",
///     timeSeries: receivablesBalanceData,  // Balance sheet data
///     cashFlowRole: .changeInReceivables    // Will auto-calculate diff()
/// )
/// ```
public enum CashFlowRole: String, Sendable, Hashable, Codable, CaseIterable, StatementRole {
	var roleStatements: String { return "Cash Flow Statement"}
	
	var description: String {
		var type: String = ""
		if isOperating { type += "Operating Cash Flow" }
		if isFinancing { type += "Financing Cash Flow"}
		if isInvesting { type += "Investing Cash Flow"}
		type += ": \(self.rawValue)"
		return type
	}
	
    // ═══════════════════════════════════════════════════════════
    // OPERATING ACTIVITIES
    // ═══════════════════════════════════════════════════════════

    /// Net income (starting point for indirect method)
    case netIncome

    /// Depreciation & Amortization add-back (non-cash charge)
    case depreciationAmortizationAddback

    /// Stock-based compensation add-back (non-cash charge)
    case stockBasedCompensationAddback

    /// Deferred tax expense/benefit
    case deferredTaxes

    /// Change in accounts receivable (working capital)
    case changeInReceivables

    /// Change in inventory (working capital)
    case changeInInventory

    /// Change in accounts payable (working capital)
    case changeInPayables

    /// Other operating activities not categorized above
    case otherOperatingActivities

    // ═══════════════════════════════════════════════════════════
    // INVESTING ACTIVITIES
    // ═══════════════════════════════════════════════════════════

    /// Capital expenditures (purchases of PP&E, usually negative)
    case capitalExpenditures

    /// Business acquisitions (M&A cash outflows)
    case acquisitions

    /// Proceeds from asset sales
    case proceedsFromAssetSales

    /// Purchase of investments (securities)
    case purchaseOfInvestments

    /// Proceeds from sale of investments
    case proceedsFromInvestments

    /// Loans made to other entities
    case loansToOtherEntities

    /// Other investing activities not categorized above
    case otherInvestingActivities

    // ═══════════════════════════════════════════════════════════
    // FINANCING ACTIVITIES
    // ═══════════════════════════════════════════════════════════

    /// Proceeds from debt issuance (borrowing)
    case proceedsFromDebt

    /// Repayment of debt principal
    case repaymentOfDebt

    /// Proceeds from equity issuance (stock offering)
    case proceedsFromEquity

    /// Repurchase of equity (stock buybacks)
    case repurchaseOfEquity

    /// Dividends paid to shareholders
    case dividendsPaid

    /// Payment of financing costs (e.g., debt issuance costs)
    case paymentOfFinancingCosts

    /// Other financing activities not categorized above
    case otherFinancingActivities

    // ═══════════════════════════════════════════════════════════
    // COMPUTED PROPERTIES
    // ═══════════════════════════════════════════════════════════

    /// Returns `true` if this role represents an operating activity
    ///
    /// Includes: netIncome, depreciationAmortizationAddback,
    /// stockBasedCompensationAddback, deferredTaxes, changeInReceivables,
    /// changeInInventory, changeInPayables, otherOperatingActivities
    public var isOperating: Bool {
        [.netIncome, .depreciationAmortizationAddback,
         .stockBasedCompensationAddback, .deferredTaxes,
         .changeInReceivables, .changeInInventory, .changeInPayables,
         .otherOperatingActivities].contains(self)
    }

    /// Returns `true` if this role represents an investing activity
    ///
    /// Includes: capitalExpenditures, acquisitions, proceedsFromAssetSales,
    /// purchaseOfInvestments, proceedsFromInvestments, loansToOtherEntities,
    /// otherInvestingActivities
    public var isInvesting: Bool {
        [.capitalExpenditures, .acquisitions, .proceedsFromAssetSales,
         .purchaseOfInvestments, .proceedsFromInvestments,
         .loansToOtherEntities, .otherInvestingActivities].contains(self)
    }

    /// Returns `true` if this role represents a financing activity
    ///
    /// Includes: proceedsFromDebt, repaymentOfDebt, proceedsFromEquity,
    /// repurchaseOfEquity, dividendsPaid, paymentOfFinancingCosts,
    /// otherFinancingActivities
    public var isFinancing: Bool {
        [.proceedsFromDebt, .repaymentOfDebt, .proceedsFromEquity,
         .repurchaseOfEquity, .dividendsPaid, .paymentOfFinancingCosts,
         .otherFinancingActivities].contains(self)
    }

    /// Returns `true` if this role uses period-over-period balance changes
    ///
    /// Working capital items in the Cash Flow Statement are derived from
    /// changes in Balance Sheet accounts. For these roles, the CashFlowStatement
    /// automatically calculates `TimeSeries.diff()` to convert balance data
    /// into cash flow impact.
    ///
    /// For example:
    /// - If accounts receivable increases $100K, that's a $100K use of cash (negative)
    /// - If accounts payable increases $50K, that's a $50K source of cash (positive)
    ///
    /// Includes: changeInReceivables, changeInInventory, changeInPayables
    public var usesChangeInBalance: Bool {
        [.changeInReceivables, .changeInInventory, .changeInPayables].contains(self)
    }
}

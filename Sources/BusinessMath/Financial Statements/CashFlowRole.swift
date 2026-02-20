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

    // ───────────────────────────────────────────────────────────
    // SMB-Specific Operating Activities
    // ───────────────────────────────────────────────────────────

    /// Change in sales tax payable (working capital)
    ///
    /// Represents the cash impact from changes in sales tax liability. When sales tax
    /// payable increases, it's a source of cash (positive). When it decreases (tax remitted),
    /// it's a use of cash (negative).
    ///
    /// ## Business Context
    ///
    /// SMBs collect sales tax from customers and remit it periodically to tax authorities.
    /// The timing difference between collection and remittance affects cash flow.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// // Sales tax payable balance sheet account
    /// let salesTaxBS = try Account(
    ///     entity: retailStore,
    ///     name: "Sales Tax Payable",
    ///     timeSeries: salesTaxBalances,  // Balance sheet data
    ///     balanceSheetRole: .salesTaxPayable
    /// )
    ///
    /// // Cash flow statement will auto-calculate diff()
    /// let salesTaxCF = try Account(
    ///     entity: retailStore,
    ///     name: "Change in Sales Tax Payable",
    ///     timeSeries: salesTaxBalances,  // Same balance data
    ///     cashFlowRole: .changeInSalesTaxPayable  // Uses diff() automatically
    /// )
    ///
    /// assert(salesTaxCF.cashFlowRole?.usesChangeInBalance == true)
    /// ```
    ///
    /// - SeeAlso: ``BalanceSheetRole/salesTaxPayable`` for the corresponding balance sheet role
    case changeInSalesTaxPayable

    /// Change in payroll liabilities (working capital)
    ///
    /// Represents the cash impact from changes in accrued payroll obligations. Increasing
    /// payroll liabilities is a source of cash (wages accrued but not yet paid). Decreasing
    /// liabilities is a use of cash (payment of accrued wages).
    ///
    /// ## Business Context
    ///
    /// Payroll timing creates cash flow impact. For example, if payroll is processed
    /// bi-weekly but month-end falls mid-cycle, accrued wages create a liability
    /// and a temporary source of cash.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// // Payroll liability balance sheet account
    /// let payrollBS = try Account(
    ///     entity: serviceCompany,
    ///     name: "Payroll Liabilities",
    ///     timeSeries: payrollBalances,
    ///     balanceSheetRole: .payrollLiabilities
    /// )
    ///
    /// // Cash flow impact (auto-calculated via diff())
    /// let payrollCF = try Account(
    ///     entity: serviceCompany,
    ///     name: "Change in Payroll Liabilities",
    ///     timeSeries: payrollBalances,
    ///     cashFlowRole: .changeInPayrollLiabilities
    /// )
    /// ```
    ///
    /// - SeeAlso: ``BalanceSheetRole/payrollLiabilities`` for the corresponding balance sheet role
    case changeInPayrollLiabilities

    /// Change in customer deposits (working capital)
    ///
    /// Represents the cash impact from changes in customer prepayments. Increasing deposits
    /// is a source of cash (customers paying in advance). Decreasing deposits is a use
    /// of cash (deposits applied to completed work).
    ///
    /// ## Business Context
    ///
    /// Customer deposits provide working capital financing for SMBs. The cash is received
    /// upfront, improving liquidity, but creates an obligation to deliver goods/services.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// // Customer deposits balance sheet account
    /// let depositsBS = try Account(
    ///     entity: customShop,
    ///     name: "Customer Deposits",
    ///     timeSeries: depositBalances,
    ///     balanceSheetRole: .customerDeposits
    /// )
    ///
    /// // Cash flow impact
    /// let depositsCF = try Account(
    ///     entity: customShop,
    ///     name: "Change in Customer Deposits",
    ///     timeSeries: depositBalances,
    ///     cashFlowRole: .changeInCustomerDeposits
    /// )
    /// ```
    ///
    /// - SeeAlso: ``BalanceSheetRole/customerDeposits`` for the corresponding balance sheet role
    case changeInCustomerDeposits

    /// Change in accrued expenses (working capital)
    ///
    /// Represents the cash impact from changes in accrued but unpaid expenses (utilities,
    /// rent, interest, professional fees). Increasing accruals is a source of cash
    /// (expense recognized but not yet paid). Decreasing accruals is a use of cash.
    ///
    /// ## Business Context
    ///
    /// Accrued expenses represent timing differences between when expenses are recognized
    /// (accrual accounting) and when they're paid (cash accounting).
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// // Accrued expenses balance sheet account
    /// let accrualsBS = try Account(
    ///     entity: company,
    ///     name: "Accrued Expenses",
    ///     timeSeries: accrualBalances,
    ///     balanceSheetRole: .accruedLiabilities
    /// )
    ///
    /// // Cash flow impact
    /// let accrualsCF = try Account(
    ///     entity: company,
    ///     name: "Change in Accrued Expenses",
    ///     timeSeries: accrualBalances,
    ///     cashFlowRole: .changeInAccruedExpenses
    /// )
    /// ```
    case changeInAccruedExpenses

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

    // ───────────────────────────────────────────────────────────
    // SMB-Specific Financing Activities
    // ───────────────────────────────────────────────────────────

    /// Owner distributions (cash paid to owners)
    ///
    /// Represents cash distributions to business owners, similar to dividends for
    /// corporations but typically used in LLCs, partnerships, and S-corporations.
    ///
    /// ## Business Context
    ///
    /// Closely-held businesses often distribute profits to owners periodically. Unlike
    /// dividends (which are after-tax), S-corp distributions may include tax distributions
    /// to cover owners' personal tax liabilities on pass-through income.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// // Owner distributions for an S-corp
    /// let distributions = try Account(
    ///     entity: sCorp,
    ///     name: "Owner Distributions",
    ///     timeSeries: distributionData,  // Negative values (cash outflow)
    ///     cashFlowRole: .ownerDistributions
    /// )
    ///
    /// assert(distributions.cashFlowRole?.isFinancingActivity == true)
    /// ```
    ///
    /// - Note: Typically negative (cash outflow). Should be distinguished from salary/wages.
    case ownerDistributions

    /// Owner contributions (cash invested by owners)
    ///
    /// Represents cash contributed by business owners to provide additional capital.
    /// Common in early-stage or stressed businesses requiring capital injection.
    ///
    /// ## Business Context
    ///
    /// Owners may contribute cash during startup, growth phases, or financial stress.
    /// These contributions increase equity and provide working capital without external
    /// financing.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// // Owner capital contribution
    /// let contributions = try Account(
    ///     entity: startupLLC,
    ///     name: "Owner Contributions",
    ///     timeSeries: contributionData,  // Positive values (cash inflow)
    ///     cashFlowRole: .ownerContributions
    /// )
    ///
    /// assert(contributions.cashFlowRole?.isFinancingActivity == true)
    /// ```
    ///
    /// - Note: Typically positive (cash inflow). Increases equity.
    case ownerContributions

    /// Draw on line of credit (borrowing)
    ///
    /// Represents cash received from drawing down a revolving line of credit.
    ///
    /// ## Business Context
    ///
    /// Lines of credit provide flexible working capital. Businesses can draw funds
    /// as needed, pay interest on the outstanding balance, and repay when cash flow
    /// improves.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// // LOC drawdown
    /// let locDraw = try Account(
    ///     entity: manufacturingCo,
    ///     name: "LOC Draws",
    ///     timeSeries: drawData,  // Positive values (cash inflow)
    ///     cashFlowRole: .drawOnLineOfCredit
    /// )
    ///
    /// assert(locDraw.cashFlowRole?.isFinancingActivity == true)
    /// ```
    ///
    /// - SeeAlso: ``BalanceSheetRole/lineOfCredit`` for the corresponding balance sheet role
    /// - SeeAlso: ``repaymentOfLineOfCredit`` for the opposite cash flow
    case drawOnLineOfCredit

    /// Repayment of line of credit
    ///
    /// Represents cash used to pay down the outstanding balance on a revolving line
    /// of credit.
    ///
    /// ## Business Context
    ///
    /// When cash flow improves, businesses often repay LOC balances to reduce interest
    /// expense and preserve available borrowing capacity for future needs.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// // LOC repayment
    /// let locRepay = try Account(
    ///     entity: manufacturingCo,
    ///     name: "LOC Repayments",
    ///     timeSeries: repaymentData,  // Negative values (cash outflow)
    ///     cashFlowRole: .repaymentOfLineOfCredit
    /// )
    ///
    /// assert(locRepay.cashFlowRole?.isFinancingActivity == true)
    /// ```
    ///
    /// - SeeAlso: ``BalanceSheetRole/lineOfCredit`` for the corresponding balance sheet role
    /// - SeeAlso: ``drawOnLineOfCredit`` for the opposite cash flow
    case repaymentOfLineOfCredit

    // ═══════════════════════════════════════════════════════════
    // COMPUTED PROPERTIES
    // ═══════════════════════════════════════════════════════════

    /// Returns `true` if this role represents an operating activity
    ///
    /// Includes: netIncome, depreciationAmortizationAddback,
    /// stockBasedCompensationAddback, deferredTaxes, changeInReceivables,
    /// changeInInventory, changeInPayables, otherOperatingActivities,
    /// changeInSalesTaxPayable, changeInPayrollLiabilities, changeInCustomerDeposits,
    /// changeInAccruedExpenses
    public var isOperating: Bool {
        [.netIncome, .depreciationAmortizationAddback,
         .stockBasedCompensationAddback, .deferredTaxes,
         .changeInReceivables, .changeInInventory, .changeInPayables,
         .otherOperatingActivities, .changeInSalesTaxPayable, .changeInPayrollLiabilities,
         .changeInCustomerDeposits, .changeInAccruedExpenses].contains(self)
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
    /// otherFinancingActivities, ownerDistributions, ownerContributions,
    /// drawOnLineOfCredit, repaymentOfLineOfCredit
    public var isFinancing: Bool {
        [.proceedsFromDebt, .repaymentOfDebt, .proceedsFromEquity,
         .repurchaseOfEquity, .dividendsPaid, .paymentOfFinancingCosts,
         .otherFinancingActivities, .ownerDistributions, .ownerContributions,
         .drawOnLineOfCredit, .repaymentOfLineOfCredit].contains(self)
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
    /// Includes: changeInReceivables, changeInInventory, changeInPayables,
    /// changeInSalesTaxPayable, changeInPayrollLiabilities, changeInCustomerDeposits,
    /// changeInAccruedExpenses
    public var usesChangeInBalance: Bool {
        [.changeInReceivables, .changeInInventory, .changeInPayables, .changeInSalesTaxPayable, .changeInPayrollLiabilities, .changeInCustomerDeposits, .changeInAccruedExpenses].contains(self)
    }

    /// Returns `true` if this role represents an operating activity
    ///
    /// Alias for `isOperating` to maintain consistency with naming conventions.
    public var isOperatingActivity: Bool {
        isOperating
    }

    /// Returns `true` if this role represents a financing activity
    ///
    /// Alias for `isFinancing` to maintain consistency with naming conventions.
    public var isFinancingActivity: Bool {
        isFinancing
    }

    /// Returns `true` if this role represents an investing activity
    ///
    /// Alias for `isInvesting` to maintain consistency with naming conventions.
    public var isInvestingActivity: Bool {
        isInvesting
    }
}

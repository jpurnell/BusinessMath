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

    // ───────────────────────────────────────────────────────────
    // Granular Current Liabilities
    // ───────────────────────────────────────────────────────────

    /// Sales tax collected from customers, payable to tax authorities
    ///
    /// Represents sales tax liability accumulated from customer transactions. This is
    /// a current liability in most jurisdictions, typically due monthly or quarterly.
    ///
    /// ## Business Context
    ///
    /// Small businesses collect sales tax from customers and remit it to tax authorities
    /// on a regular cadence. This account tracks the liability between collection and remittance.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// // Sales tax liability
    /// let salesTax = try Account(
    ///     entity: retailStore,
    ///     name: "Sales Tax Payable",
    ///     timeSeries: salesTaxData,
    ///     balanceSheetRole: .salesTaxPayable
    /// )
    ///
    /// // Verify it's a current liability
    /// assert(salesTax.balanceSheetRole?.isCurrentLiability == true)
    /// assert(salesTax.balanceSheetRole?.isWorkingCapital == true)
    /// ```
    ///
    /// - SeeAlso: ``CashFlowRole/changeInSalesTaxPayable`` for cash flow statement impact
    case salesTaxPayable

    /// Payroll liabilities (wages payable, payroll taxes withheld)
    ///
    /// Represents accrued payroll obligations including employee wages, employer
    /// payroll taxes, and withheld amounts (federal/state taxes, Social Security, Medicare).
    ///
    /// ## Business Context
    ///
    /// Payroll is typically processed bi-weekly or monthly, creating a timing gap between
    /// accruing wages and actually paying employees. This account captures that liability.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// // Payroll liability
    /// let payroll = try Account(
    ///     entity: serviceCompany,
    ///     name: "Payroll Liabilities",
    ///     timeSeries: payrollData,
    ///     balanceSheetRole: .payrollLiabilities
    /// )
    ///
    /// // Verify classification
    /// assert(payroll.balanceSheetRole?.isCurrentLiability == true)
    /// ```
    ///
    ///
    /// - SeeAlso: ``CashFlowRole/changeInPayrollLiabilities`` for cash flow impact
    case payrollLiabilities

    /// Line of credit (revolving credit facility)
    ///
    /// Represents outstanding balance on a revolving line of credit. Typically used
    /// by smaller businesses for working capital flexibility.
    ///
    /// ## Business Context
    ///
    /// Lines of credit provide flexible borrowing capacity. Unlike term loans, businesses
    /// can draw down and repay repeatedly, paying interest only on the outstanding balance.
    /// Most LOCs are renewable annually and classified as current liabilities.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// // Line of credit for working capital
    /// let loc = try Account(
    ///     entity: manufacturingCo,
    ///     name: "Line of Credit",
    ///     timeSeries: locBalanceData,
    ///     balanceSheetRole: .lineOfCredit
    /// )
    ///
    /// // Verify it's current debt
    /// assert(loc.balanceSheetRole?.isCurrentLiability == true)
    /// assert(loc.balanceSheetRole?.isDebt == true)
    /// ```
    ///
    ///
    /// - SeeAlso: ``CashFlowRole/drawOnLineOfCredit``, ``CashFlowRole/repaymentOfLineOfCredit`` for cash flow impacts
    case lineOfCredit

    /// Customer deposits and prepayments
    ///
    /// Represents cash received from customers in advance of delivering goods or services.
    /// Similar to deferred revenue but often used for smaller, project-based deposits.
    ///
    /// ## Business Context
    ///
    /// Many SMBs require customer deposits before starting work (e.g., construction,
    /// custom manufacturing, event planning). These deposits create a liability until
    /// the work is completed or the product delivered.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// // Customer deposits for a custom manufacturer
    /// let deposits = try Account(
    ///     entity: customShop,
    ///     name: "Customer Deposits",
    ///     timeSeries: depositData,
    ///     balanceSheetRole: .customerDeposits
    /// )
    ///
    /// // Verify working capital impact
    /// assert(deposits.balanceSheetRole?.isCurrentLiability == true)
    /// assert(deposits.balanceSheetRole?.isWorkingCapital == true)
    /// ```
    ///
    ///
    /// - SeeAlso: ``CashFlowRole/changeInCustomerDeposits`` for cash flow impact
    case customerDeposits

    /// Loans from business owners
    ///
    /// Represents amounts owed to the business owner(s) for loans made to the company.
    /// Common in closely-held SMBs where owners provide short-term funding.
    ///
    /// ## Business Context
    ///
    /// Small business owners often loan money to their companies during cash flow
    /// constraints rather than diluting equity or using external debt. These loans
    /// may be informal or formally documented.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// // Owner loan to provide working capital
    /// let ownerLoan = try Account(
    ///     entity: familyBusiness,
    ///     name: "Due to Owner",
    ///     timeSeries: ownerLoanData,
    ///     balanceSheetRole: .ownerLoans
    /// )
    ///
    /// // Typically current, but could be long-term
    /// assert(ownerLoan.balanceSheetRole?.isLiability == true)
    /// ```
    ///
    ///
    /// - Note: Classification as current vs. non-current depends on repayment terms
    case ownerLoans

    // ═══════════════════════════════════════════════════════════
    // NON-CURRENT LIABILITIES
    // ═══════════════════════════════════════════════════════════

    /// Long-term debt (maturity > 1 year)
    case longTermDebt

    // ───────────────────────────────────────────────────────────
    // Granular Debt Subtypes (v2.0.0)
    // ───────────────────────────────────────────────────────────

    /// Revolving credit facility (current or non-current based on maturity)
    ///
    /// A flexible borrowing arrangement where the borrower can draw, repay, and redraw
    /// funds up to a maximum credit limit. Common for working capital and general corporate purposes.
    ///
    /// ## Business Context
    ///
    /// Revolving credit facilities provide liquidity flexibility for PE-backed companies and operators.
    /// They're typically secured by assets (ABL) or unsecured based on EBITDA multiples.
    ///
    /// ## Key Features
    ///
    /// - **Flexibility**: Draw and repay as needed
    /// - **Pricing**: Variable rate (SOFR + spread)
    /// - **Covenants**: Leverage ratio, fixed charge coverage
    /// - **Maturity**: Typically 3-5 years with annual renewal options
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// let revolver = try Account(
    ///     entity: portfolio,
    ///     name: "Revolving Credit Facility",
    ///     balanceSheetRole: .revolvingCreditFacility,
    ///     timeSeries: revolverData
    /// )
    ///
    /// // Verify debt classification
    /// assert(revolver.balanceSheetRole?.isDebt == true)
    /// ```
    ///
    /// - SeeAlso: ``lineOfCredit`` for SMB-specific revolvers
    case revolvingCreditFacility

    /// Term loan - short term (maturity < 1 year)
    ///
    /// A loan with a fixed repayment schedule and maturity of less than one year.
    /// Often used for specific short-term financing needs or as bridge financing.
    ///
    /// ## Business Context
    ///
    /// Short-term term loans are less common than revolvers for working capital but may be used
    /// for specific acquisitions, capital projects, or seasonal needs.
    ///
    /// ## Key Features
    ///
    /// - **Fixed Schedule**: Predetermined principal and interest payments
    /// - **Maturity**: Less than 12 months
    /// - **Use Cases**: Bridge financing, seasonal needs, specific projects
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// let shortTermLoan = try Account(
    ///     entity: portfolio,
    ///     name: "Short-Term Term Loan",
    ///     balanceSheetRole: .termLoanShortTerm,
    ///     timeSeries: loanData
    /// )
    ///
    /// // Classified as current liability
    /// assert(shortTermLoan.balanceSheetRole?.isCurrentLiability == true)
    /// assert(shortTermLoan.balanceSheetRole?.isDebt == true)
    /// ```
    case termLoanShortTerm

    /// Term loan - long term (maturity > 1 year)
    ///
    /// A loan with a fixed repayment schedule and maturity exceeding one year.
    /// The primary debt instrument in leveraged buyouts and acquisition financing.
    ///
    /// ## Business Context
    ///
    /// Term loans are the workhorse of PE debt structures. They provide permanent financing
    /// for acquisitions and are structured with amortization schedules and covenant packages.
    ///
    /// ## Key Features
    ///
    /// - **Amortization**: Quarterly or annual principal paydowns
    /// - **Maturity**: Typically 5-7 years
    /// - **Pricing**: SOFR + spread (varies by leverage multiple)
    /// - **Covenants**: Leverage ratio, interest coverage, capex limits
    /// - **Prepayment**: Often includes prepayment penalties or excess cash flow sweeps
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// let termLoan = try Account(
    ///     entity: portfolio,
    ///     name: "First Lien Term Loan",
    ///     balanceSheetRole: .termLoanLongTerm,
    ///     timeSeries: loanData
    /// )
    ///
    /// // Verify classification
    /// assert(termLoan.balanceSheetRole?.isNonCurrentLiability == true)
    /// assert(termLoan.balanceSheetRole?.isDebt == true)
    /// ```
    case termLoanLongTerm

    /// Mezzanine debt (subordinated to senior debt)
    ///
    /// Subordinated debt sitting between senior debt and equity in the capital structure.
    /// Often includes equity kickers (warrants) and carries higher interest rates.
    ///
    /// ## Business Context
    ///
    /// Mezzanine debt is used in LBOs to reduce equity requirements while maintaining
    /// acceptable senior leverage ratios. It's subordinated to senior debt and often
    /// includes payment-in-kind (PIK) features.
    ///
    /// ## Key Features
    ///
    /// - **Subordination**: Paid after senior debt in liquidation
    /// - **Pricing**: 12-15% cash + PIK interest
    /// - **Equity Kickers**: Warrants for 5-15% of equity
    /// - **Maturity**: 6-8 years, often bullet payment
    /// - **Covenants**: Lighter than senior debt
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// let mezz = try Account(
    ///     entity: portfolio,
    ///     name: "Subordinated Mezzanine Notes",
    ///     balanceSheetRole: .mezzanineDebt,
    ///     timeSeries: mezzData
    /// )
    ///
    /// // Track separately from senior debt for covenant calculations
    /// assert(mezz.balanceSheetRole?.isDebt == true)
    /// ```
    case mezzanineDebt

    /// Convertible debt (convertible to equity)
    ///
    /// Debt instruments that can be converted into equity at predetermined terms.
    /// Provides optionality for lenders and dilution protection for borrowers.
    ///
    /// ## Business Context
    ///
    /// Convertible debt is less common in traditional PE but may be used in growth equity
    /// or distressed situations. It bridges debt and equity characteristics.
    ///
    /// ## Key Features
    ///
    /// - **Conversion**: Convertible to equity at specified price/ratio
    /// - **Pricing**: Lower interest than straight debt due to conversion feature
    /// - **Protection**: Anti-dilution provisions
    /// - **Maturity**: Varies widely (3-10 years)
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// let convertible = try Account(
    ///     entity: growthCo,
    ///     name: "Convertible Notes",
    ///     balanceSheetRole: .convertibleDebt,
    ///     timeSeries: convertibleData
    /// )
    ///
    /// // Tracked as debt until conversion
    /// assert(convertible.balanceSheetRole?.isDebt == true)
    /// ```
    case convertibleDebt

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
    /// currentPortionLongTermDebt, deferredRevenue, otherCurrentLiabilities,
    /// salesTaxPayable, payrollLiabilities, lineOfCredit, customerDeposits, ownerLoans,
    /// termLoanShortTerm
    public var isCurrentLiability: Bool {
        [.accountsPayable, .accruedLiabilities, .shortTermDebt,
         .currentPortionLongTermDebt, .deferredRevenue,
         .otherCurrentLiabilities, .salesTaxPayable, .payrollLiabilities, .lineOfCredit,
         .customerDeposits, .ownerLoans, .termLoanShortTerm].contains(self)
    }

    /// Returns `true` if this role represents a non-current liability
    ///
    /// Includes: longTermDebt, deferredTaxLiabilities, pensionLiabilities,
    /// leaseLiabilities, otherNonCurrentLiabilities, revolvingCreditFacility,
    /// termLoanLongTerm, mezzanineDebt, convertibleDebt
    public var isNonCurrentLiability: Bool {
        [.longTermDebt, .deferredTaxLiabilities, .pensionLiabilities,
         .leaseLiabilities, .otherNonCurrentLiabilities, .revolvingCreditFacility,
         .termLoanLongTerm, .mezzanineDebt, .convertibleDebt].contains(self)
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
    /// Includes: shortTermDebt, currentPortionLongTermDebt, longTermDebt, lineOfCredit,
    /// revolvingCreditFacility, termLoanShortTerm, termLoanLongTerm, mezzanineDebt, convertibleDebt
    public var isDebt: Bool {
        [.shortTermDebt, .currentPortionLongTermDebt, .longTermDebt,
         .lineOfCredit, .revolvingCreditFacility, .termLoanShortTerm,
         .termLoanLongTerm, .mezzanineDebt, .convertibleDebt].contains(self)
    }

    /// Returns `true` if this role represents a working capital account
    ///
    /// Working capital accounts are current assets and current liabilities that fluctuate
    /// with business operations (excluding cash and debt).
    ///
    /// ## Business Context
    ///
    /// Working capital represents the short-term financial health of a business. Changes
    /// in working capital accounts directly impact cash flow from operations.
    ///
    /// **Current Assets in Working Capital:**
    /// - Accounts receivable
    /// - Inventory
    /// - Prepaid expenses
    ///
    /// **Current Liabilities in Working Capital:**
    /// - Accounts payable
    /// - Accrued liabilities
    /// - Sales tax payable
    /// - Payroll liabilities
    /// - Customer deposits
    ///
    /// **Excluded from Working Capital:**
    /// - Cash (managed separately)
    /// - Short-term debt (financing activity, not operating)
    /// - Line of credit (debt financing)
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// let account = try Account(
    ///     entity: company,
    ///     name: "Sales Tax Payable",
    ///     timeSeries: salesTaxData,
    ///     balanceSheetRole: .salesTaxPayable
    /// )
    ///
    /// if account.balanceSheetRole?.isWorkingCapital == true {
    ///     // Include in working capital stress tests
    /// }
    /// ```
    ///
    /// - Returns: `true` if this account is part of working capital
    public var isWorkingCapital: Bool {
        // Current assets in working capital (exclude cash)
        if [.accountsReceivable, .inventory, .prepaidExpenses,
            .otherCurrentAssets].contains(self) {
            return true
        }

        // Current liabilities in working capital (exclude debt)
        if [.accountsPayable, .accruedLiabilities, .deferredRevenue,
            .otherCurrentLiabilities, .salesTaxPayable, .payrollLiabilities, .customerDeposits].contains(self) {
            return true
        }

        return false
    }
}


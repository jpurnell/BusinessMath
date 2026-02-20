//
//  BalanceSheet.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

// MARK: - BalanceSheetError

/// Errors that can occur when creating or manipulating balance sheets.
public enum BalanceSheetError: Error, Sendable {
	/// The entity is missing from one or more accounts
	case entityMismatch

	/// Periods are inconsistent across accounts
	case periodMismatch

	/// No accounts provided
	case noAccounts

	/// Wrong account type (expected asset, liability, or equity)
	case invalidAccountType(expected: AccountType, actual: AccountType)

	/// Accounting equation not satisfied: Assets != Liabilities + Equity
	case accountingEquationViolation(period: Period, assets: Double, liabilitiesAndEquity: Double)
}

// MARK: - BalanceSheet

/// Balance sheet for a single entity over multiple periods.
///
/// `BalanceSheet` aggregates asset, liability, and equity accounts to provide
/// a snapshot of financial position. It validates the fundamental accounting equation:
/// **Assets = Liabilities + Equity**.
///
/// ## Creating Balance Sheets
///
/// ```swift
/// let entity = Entity(id: "AAPL", primaryType: .ticker, name: "Apple Inc.")
/// let periods = [
///     Period.quarter(year: 2024, quarter: 1),
///     Period.quarter(year: 2024, quarter: 2)
/// ]
///
/// var cashMetadata = AccountMetadata()
/// cashMetadata.category = "Current"
///
/// let cashAccount = try Account(
///     entity: entity,
///     name: "Cash",
///     type: .asset,
///     timeSeries: cashSeries,
///     metadata: cashMetadata
/// )
///
/// let balanceSheet = try BalanceSheet(
///     entity: entity,
///     periods: periods,
///     assetAccounts: [cashAccount],
///     liabilityAccounts: [apAccount],
///     equityAccounts: [equityAccount]
/// )
/// ```
///
/// ## Validating the Accounting Equation
///
/// ```swift
/// // Check if Assets = Liabilities + Equity
/// try balanceSheet.validate(tolerance: 0.01)
/// ```
///
/// ## Accessing Metrics
///
/// ```swift
/// // Totals
/// let totalAssets = balanceSheet.totalAssets
/// let totalLiabilities = balanceSheet.totalLiabilities
/// let totalEquity = balanceSheet.totalEquity
///
/// // Liquidity metrics
/// let currentAssets = balanceSheet.currentAssets
/// let currentLiabilities = balanceSheet.currentLiabilities
/// let workingCapital = balanceSheet.workingCapital
///
/// // Financial ratios
/// let currentRatio = balanceSheet.currentRatio
/// let debtToEquity = balanceSheet.debtToEquity
/// let equityRatio = balanceSheet.equityRatio
/// ```
///
/// ## Topics
///
/// ### Creating Balance Sheets
/// - ``init(entity:periods:accounts:)``
///
/// ### Properties
/// - ``entity``
/// - ``periods``
/// - ``assetAccounts``
/// - ``liabilityAccounts``
/// - ``equityAccounts``
///
/// ### Aggregated Totals
/// - ``totalAssets``
/// - ``totalLiabilities``
/// - ``totalEquity``
///
/// ### Liquidity Metrics
/// - ``currentAssets``
/// - ``currentLiabilities``
/// - ``workingCapital``
///
/// ### Financial Ratios
/// - ``currentRatio``
/// - ``debtToEquity``
/// - ``equityRatio``
///
/// ### Validation
/// - ``validate(tolerance:)``
///
/// ### Materialization
/// - ``materialize()``
/// - ``Materialized``
public struct BalanceSheet<T: Real & Sendable>: Sendable where T: Codable {

	/// The entity this balance sheet belongs to.
	public let entity: Entity

	/// The periods covered by this balance sheet.
	public let periods: [Period]

	/// All accounts in this balance sheet.
	///
	/// Each account must have a `balanceSheetRole` to be included.
	/// Accounts with the same role will be automatically aggregated when computing metrics.
	public let accounts: [Account<T>]

	/// All asset accounts (accounts with asset roles).
	///
	/// This computed property filters accounts by their `balanceSheetRole.isAsset` flag.
	public var assetAccounts: [Account<T>] {
		accounts.filter { $0.balanceSheetRole?.isAsset == true }
	}

	/// All liability accounts (accounts with liability roles).
	///
	/// This computed property filters accounts by their `balanceSheetRole.isLiability` flag.
	public var liabilityAccounts: [Account<T>] {
		accounts.filter { $0.balanceSheetRole?.isLiability == true }
	}

	/// All equity accounts (accounts with equity roles).
	///
	/// This computed property filters accounts by their `balanceSheetRole.isEquity` flag.
	public var equityAccounts: [Account<T>] {
		accounts.filter { $0.balanceSheetRole?.isEquity == true }
	}

	/// All current asset accounts.
	public var currentAssetAccounts: [Account<T>] {
		assetAccounts.filter { $0.balanceSheetRole?.isCurrent == true }
	}

	/// All non-current asset accounts.
	public var nonCurrentAssetAccounts: [Account<T>] {
		assetAccounts.filter { $0.balanceSheetRole?.isCurrent == false }
	}

	/// All current liability accounts.
	public var currentLiabilityAccounts: [Account<T>] {
		liabilityAccounts.filter { $0.balanceSheetRole?.isCurrent == true }
	}

	/// All non-current liability accounts.
	public var nonCurrentLiabilityAccounts: [Account<T>] {
		liabilityAccounts.filter { $0.balanceSheetRole?.isCurrent == false }
	}

	/// Creates a balance sheet with validation using the new role-based API.
	///
	/// - Parameters:
	///   - entity: The entity this statement belongs to
	///   - periods: The periods covered
	///   - accounts: All accounts (must have `balanceSheetRole`)
	///
	/// - Throws: ``FinancialModelError`` if validation fails
	public init(
		entity: Entity,
		periods: [Period],
		accounts: [Account<T>]
	) throws {
		// Validate all accounts have balance sheet roles
		for account in accounts {
			guard account.balanceSheetRole != nil else {
				throw FinancialModelError.accountMissingRole(
					statement: .balanceSheet,
					accountName: account.name
				)
			}
		}

		// Validate entity and period consistency using shared helpers
		try FinancialStatementHelpers.validateEntityConsistency(accounts: accounts, entity: entity)
		try FinancialStatementHelpers.validatePeriodConsistency(accounts: accounts, periods: periods)

		self.entity = entity
		self.periods = periods
		self.accounts = accounts
	}

	// MARK: - Aggregated Totals

	/// Total assets across all asset accounts.
	public var totalAssets: TimeSeries<T> {
		return FinancialStatementHelpers.aggregateAccounts(assetAccounts, periods: periods)
	}

	/// Total liabilities across all liability accounts.
	public var totalLiabilities: TimeSeries<T> {
		return FinancialStatementHelpers.aggregateAccounts(liabilityAccounts, periods: periods)
	}

	/// Total equity across all equity accounts.
	public var totalEquity: TimeSeries<T> {
		return FinancialStatementHelpers.aggregateAccounts(equityAccounts, periods: periods)
	}

	// MARK: - Liquidity Metrics

	/// Current assets (assets with role indicating current/short-term).
	///
	/// Current assets are expected to be converted to cash within one year.
	/// Includes: cash, accounts receivable, inventory, prepaid expenses, and other current assets.
	public var currentAssets: TimeSeries<T> {
		let current = assetAccounts.filter {
			$0.balanceSheetRole?.isCurrent == true
		}
		return FinancialStatementHelpers.aggregateAccounts(current, periods: periods)
	}

	/// Non-current assets (assets with role indicating long-term).
	///
	/// Non-current assets include property, plant, equipment, intangibles, goodwill, and long-term investments.
	public var nonCurrentAssets: TimeSeries<T> {
		let nonCurrent = assetAccounts.filter {
			$0.balanceSheetRole?.isCurrent == false
		}
		return FinancialStatementHelpers.aggregateAccounts(nonCurrent, periods: periods)
	}

	/// Cash and cash equivalents (used in enterprise value calculation).
	///
	/// Includes cash and marketable securities. This is the liquid cash that would
	/// be available to an acquirer and is subtracted when calculating enterprise value.
	///
	/// ## Formula
	///
	/// ```
	/// Cash and Equivalents = Cash + Marketable Securities
	/// ```
	///
	/// ## Identification
	///
	/// Accounts are identified as cash equivalents if they are current assets and:
	/// - Name contains "Cash"
	/// - Name contains "Cash Equivalent"
	/// - Name contains "Marketable Securities"
	///
	/// ## Use Case
	///
	/// Primary use is in enterprise value calculation:
	/// ```
	/// EV = Market Cap + Debt - Cash and Equivalents
	/// ```
	///
	/// ## Example
	///
	/// ```swift
	/// let balanceSheet = try BalanceSheet(...)
	/// let cash = balanceSheet.cashAndEquivalents
	///
	/// let q1 = Period.quarter(year: 2025, quarter: 1)
	/// print("Cash: $\(cash[q1]!)")  // e.g., "Cash: $500,000"
	/// ```
	public var cashAndEquivalents: TimeSeries<T> {
		let cashAccounts = assetAccounts.filter {
			$0.balanceSheetRole == .cashAndEquivalents
		}

		if !cashAccounts.isEmpty {
			return FinancialStatementHelpers.aggregateAccounts(cashAccounts, periods: periods)
		} else {
			// No cash accounts found - return zero series
			let zero = T(0)
			let zeroValues = periods.map { _ in zero }
			return TimeSeries(periods: periods, values: zeroValues)
		}
	}

	/// Interest-bearing debt (loans, bonds, notes payable, leases).
	///
	/// Returns only the debt that carries interest expense, excluding operating liabilities
	/// like accounts payable and accrued expenses. This is the relevant debt for enterprise
	/// value calculation and capital structure analysis.
	///
	/// ## Formula
	///
	/// ```
	/// Interest-bearing Debt = Sum of liability accounts with category="Debt"
	/// ```
	///
	/// ## Identification
	///
	/// Accounts are identified as interest-bearing debt if they are liabilities and:
	/// - metadata.category == "Debt" (preferred method)
	/// - OR name contains "Debt", "Loan", "Bond", "Note Payable", "Lease"
	///
	/// ## Common Interest-bearing Debt
	///
	/// - **Short-term**: Current portion of long-term debt, short-term loans, lines of credit
	/// - **Long-term**: Term loans, bonds payable, notes payable, capital leases
	///
	/// ## Excluded (Operating Liabilities)
	///
	/// - Accounts payable
	/// - Accrued expenses
	/// - Deferred revenue
	/// - Taxes payable
	///
	/// ## Use Cases
	///
	/// - Enterprise value calculation
	/// - Debt-to-equity ratio (interest-bearing debt only)
	/// - Net debt calculation (interest-bearing debt - cash)
	///
	/// ## Example
	///
	/// ```swift
	/// let balanceSheet = try BalanceSheet(...)
	/// let debt = balanceSheet.interestBearingDebt
	///
	/// let q1 = Period.quarter(year: 2025, quarter: 1)
	/// print("Total Debt: $\(debt[q1]!)")  // e.g., "Total Debt: $2,000,000"
	/// ```
	public var interestBearingDebt: TimeSeries<T> {
		// Find debt accounts by role
		let debtAccounts = liabilityAccounts.filter {
			$0.balanceSheetRole?.isDebt == true
		}

		if !debtAccounts.isEmpty {
			return FinancialStatementHelpers.aggregateAccounts(debtAccounts, periods: periods)
		} else {
			// No debt accounts found - return zero series (some companies are debt-free)
			let zero = T(0)
			let zeroValues = periods.map { _ in zero }
			return TimeSeries(periods: periods, values: zeroValues)
		}
	}

	/// Breakdown of debt by granular type (v2.0.0).
	///
	/// Returns a dictionary mapping each debt role to its aggregated time series. Useful for
	/// analyzing debt composition, tracking covenant compliance, and understanding capital structure.
	///
	/// ## Business Context
	///
	/// PE operators and portfolio managers need to track debt by specific instrument type for:
	/// - **Covenant tracking**: Different tranches have different leverage ratios
	/// - **Refinancing planning**: Understanding maturity schedules by debt type
	/// - **Capital structure analysis**: Seeing mix of senior, subordinated, and mezzanine debt
	/// - **Investor reporting**: Detailed debt breakdowns for LP reports
	///
	/// ## Example Usage
	///
	/// ```swift
	/// let debtBreakdown = balanceSheet.interestBearingDebtByType
	///
	/// // Access specific debt types
	/// if let revolver = debtBreakdown[.revolvingCreditFacility] {
	///     print("Revolver balance: \(revolver[q1]!)")
	/// }
	///
	/// if let termLoan = debtBreakdown[.termLoanLongTerm] {
	///     print("Term loan balance: \(termLoan[q1]!)")
	/// }
	///
	/// // Calculate senior vs subordinated debt
	/// let seniorDebt = (debtBreakdown[.revolvingCreditFacility] ?? zeroSeries) +
	///                   (debtBreakdown[.termLoanLongTerm] ?? zeroSeries)
	/// let mezzDebt = debtBreakdown[.mezzanineDebt] ?? zeroSeries
	/// ```
	///
	/// ## Covenant Calculations
	///
	/// ```swift
	/// // Senior leverage ratio (excludes mezzanine)
	/// let seniorDebtTypes: Set<BalanceSheetRole> = [
	///     .revolvingCreditFacility,
	///     .termLoanLongTerm
	/// ]
	///
	/// let seniorDebt = debtBreakdown
	///     .filter { seniorDebtTypes.contains($0.key) }
	///     .values
	///     .reduce(zeroSeries, +)
	///
	/// let seniorLeverage = seniorDebt / ebitda
	/// ```
	///
	/// - Returns: Dictionary of debt roles to time series, only including roles with actual balances
	/// - Note: Empty dictionary if no debt accounts exist
	public var interestBearingDebtByType: [BalanceSheetRole: TimeSeries<T>] {
		var debtByType: [BalanceSheetRole: TimeSeries<T>] = [:]

		// Group debt accounts by their specific role
		let debtAccounts = liabilityAccounts.filter {
			$0.balanceSheetRole?.isDebt == true
		}

		// Get unique debt roles
		let debtRoles = Set(debtAccounts.compactMap { $0.balanceSheetRole })

		// Aggregate by each debt type
		for role in debtRoles {
			let accountsForRole = debtAccounts.filter { $0.balanceSheetRole == role }
			if !accountsForRole.isEmpty {
				debtByType[role] = FinancialStatementHelpers.aggregateAccounts(accountsForRole, periods: periods)
			}
		}

		return debtByType
	}

	/// Current liabilities (liabilities expected to be paid within one year).
	///
	/// Includes: accounts payable, accrued expenses, short-term debt,
	/// current portion of long-term debt, and other current liabilities.
	public var currentLiabilities: TimeSeries<T> {
		let current = liabilityAccounts.filter {
			$0.balanceSheetRole?.isCurrent == true
		}
		return FinancialStatementHelpers.aggregateAccounts(current, periods: periods)
	}

	/// Non-current liabilities (liabilities with role indicating long-term).
	///
	/// Non-current liabilities include long-term debt, lease liabilities, deferred revenue, and pension obligations.
	public var nonCurrentLiabilities: TimeSeries<T> {
		let nonCurrent = liabilityAccounts.filter {
			$0.balanceSheetRole?.isCurrent == false
		}
		return FinancialStatementHelpers.aggregateAccounts(nonCurrent, periods: periods)
	}

	/// Long-term debt (bonds, notes payable, term loans with maturity > 1 year).
	///
	/// Filters liability accounts with role indicating long-term debt.
	/// Used for credit metrics like Altman Z-Score and Piotroski F-Score.
	public var longTermDebt: TimeSeries<T> {
		let ltDebtRoles: Set<BalanceSheetRole> = [.longTermDebt, .leaseLiabilities]
		let ltDebt = liabilityAccounts.filter { ltDebtRoles.contains($0.balanceSheetRole ?? .otherNonCurrentLiabilities) }
		return FinancialStatementHelpers.aggregateAccounts(ltDebt, periods: periods)
	}

	/// Retained earnings (accumulated profits not distributed as dividends).
	///
	/// Filters equity accounts with role .retainedEarnings.
	/// Used for credit metrics like Altman Z-Score and Piotroski F-Score.
	public var retainedEarnings: TimeSeries<T> {
		let retained = equityAccounts.filter { $0.balanceSheetRole == .retainedEarnings }
		return FinancialStatementHelpers.aggregateAccounts(retained, periods: periods)
	}

	/// Working capital (current assets - current liabilities).
	///
	/// Measures short-term liquidity.
	public var workingCapital: TimeSeries<T> {
		return currentAssets - currentLiabilities
	}

	/// Net working capital (synonym for working capital).
	///
	/// Net working capital represents the amount of current assets that exceed current liabilities,
	/// providing a measure of short-term financial health and operational liquidity.
	///
	/// ## Business Context
	///
	/// Net working capital is critical for:
	/// - **Day-to-day operations**: Ensuring sufficient resources to meet short-term obligations
	/// - **Credit analysis**: Lenders use NWC to assess ability to service debt
	/// - **LBO modeling**: Changes in NWC affect free cash flow projections
	/// - **Operational efficiency**: Monitoring working capital management effectiveness
	///
	/// ## Formula
	///
	/// ```
	/// Net Working Capital = Current Assets - Current Liabilities
	/// ```
	///
	/// ## Example Usage
	///
	/// ```swift
	/// let balanceSheet = try BalanceSheet(entity: company, periods: periods, accounts: accounts)
	///
	/// // Check working capital position
	/// let nwc = balanceSheet.netWorkingCapital
	/// print("Q1 NWC: $\(nwc[q1]!)") // e.g., $2.5M
	///
	/// // Monitor trend over time
	/// let nwcChange = nwc[q2]! - nwc[q1]!  // Increase/decrease in NWC
	/// ```
	///
	/// ## Interpretation
	///
	/// - **Positive NWC**: Company can cover short-term obligations (healthy)
	/// - **Negative NWC**: Potential liquidity issues (unless business model allows, e.g., retail with negative CCC)
	/// - **Increasing NWC**: More capital tied up in operations (may reduce cash flow)
	/// - **Decreasing NWC**: More efficient working capital management (or potential stress)
	///
	/// - Note: This is equivalent to ``workingCapital``
	/// - SeeAlso: ``workingCapital``
	/// - SeeAlso: ``workingCapitalComponents``
	/// - SeeAlso: ``workingCapitalTurnover(revenue:)``
	public var netWorkingCapital: TimeSeries<T> {
		return workingCapital
	}

	/// Breakdown of net working capital by balance sheet role.
	///
	/// Returns a dictionary showing the contribution of each current asset and current liability
	/// role to total working capital. Current assets contribute positively, current liabilities
	/// contribute negatively.
	///
	/// ## Business Context
	///
	/// Understanding working capital composition is essential for:
	/// - **Working capital optimization**: Identifying which components drive WC changes
	/// - **Cash flow forecasting**: Different components have different cash conversion cycles
	/// - **Operational diagnostics**: High AR or inventory may signal collection or turnover issues
	/// - **LBO analysis**: Modeling working capital builds/releases by component
	///
	/// ## Example Usage
	///
	/// ```swift
	/// let balanceSheet = try BalanceSheet(entity: company, periods: periods, accounts: accounts)
	///
	/// // Get working capital breakdown
	/// let components = balanceSheet.workingCapitalComponents
	///
	/// // Analyze major drivers
	/// if let ar = components[.accountsReceivable] {
	///     print("AR (Q1): $\(ar[q1]!)")  // e.g., $3.5M
	/// }
	/// if let ap = components[.accountsPayable] {
	///     print("AP (Q1): $\(ap[q1]!)")  // e.g., -$1.2M (negative = liability)
	/// }
	/// if let inventory = components[.inventory] {
	///     print("Inventory (Q1): $\(inventory[q1]!)")  // e.g., $2.1M
	/// }
	///
	/// // Calculate AR as % of total current assets
	/// let currentAssets = balanceSheet.currentAssets
	/// let arPercent = (ar[q1]! / currentAssets[q1]!) * 100  // e.g., 58%
	/// ```
	///
	/// ## LBO Working Capital Build/Release Modeling
	///
	/// ```swift
	/// // Track component changes period-over-period
	/// let components = balanceSheet.workingCapitalComponents
	///
	/// if let ar = components[.accountsReceivable] {
	///     let arChange = ar[q2]! - ar[q1]!
	///     if arChange > 0 {
	///         print("AR increased by $\(arChange) - use of cash")
	///     } else {
	///         print("AR decreased by $\(-arChange) - source of cash")
	///     }
	/// }
	///
	/// // Identify working capital efficiency opportunities
	/// // - High AR → improve collections
	/// // - High inventory → improve turnover
	/// // - Low AP → negotiate better payment terms
	/// ```
	///
	/// ## Return Value
	///
	/// Dictionary where:
	/// - **Keys**: ``BalanceSheetRole`` for each current asset/liability
	/// - **Values**: ``TimeSeries`` of component balances
	/// - Current assets appear as **positive** values
	/// - Current liabilities appear as **negative** values (to show they reduce NWC)
	///
	/// - Returns: Dictionary mapping balance sheet roles to their working capital contribution
	/// - SeeAlso: ``netWorkingCapital``
	/// - SeeAlso: ``currentAssets``
	/// - SeeAlso: ``currentLiabilities``
	public var workingCapitalComponents: [BalanceSheetRole: TimeSeries<T>] {
		var components: [BalanceSheetRole: TimeSeries<T>] = [:]

		// Current assets (positive contribution to NWC)
		let currentAssetAccounts = assetAccounts.filter { $0.balanceSheetRole?.isCurrent == true }
		let currentAssetRoles = Set(currentAssetAccounts.compactMap { $0.balanceSheetRole })

		for role in currentAssetRoles {
			let accountsForRole = currentAssetAccounts.filter { $0.balanceSheetRole == role }
			if !accountsForRole.isEmpty {
				components[role] = FinancialStatementHelpers.aggregateAccounts(accountsForRole, periods: periods)
			}
		}

		// Current liabilities (negative contribution to NWC)
		let currentLiabilityAccounts = liabilityAccounts.filter { $0.balanceSheetRole?.isCurrent == true }
		let currentLiabilityRoles = Set(currentLiabilityAccounts.compactMap { $0.balanceSheetRole })

		for role in currentLiabilityRoles {
			let accountsForRole = currentLiabilityAccounts.filter { $0.balanceSheetRole == role }
			if !accountsForRole.isEmpty {
				// Negate to show as reduction in working capital
				let aggregated = FinancialStatementHelpers.aggregateAccounts(accountsForRole, periods: periods)
				let negatedValues = periods.map { period in -aggregated[period]! }
				components[role] = TimeSeries(periods: periods, values: negatedValues)
			}
		}

		return components
	}

	/// Working capital turnover ratio (revenue / average working capital).
	///
	/// Measures how efficiently a company uses its working capital to generate revenue.
	/// Higher turnover indicates more efficient use of working capital.
	///
	/// ## Business Context
	///
	/// Working capital turnover is important for:
	/// - **Operational efficiency**: How effectively is NWC deployed to generate sales?
	/// - **Industry benchmarking**: Compare to peers to identify efficiency gaps
	/// - **Cash flow optimization**: Higher turnover means less cash tied up in operations
	/// - **Credit analysis**: Efficient WC management reduces financing needs
	///
	/// ## Formula
	///
	/// ```
	/// Working Capital Turnover = Revenue / Average Working Capital
	/// ```
	///
	/// For the first period, uses beginning working capital (no average).
	/// For subsequent periods, uses average of current and prior period.
	///
	/// ## Example Usage
	///
	/// ```swift
	/// let balanceSheet = try BalanceSheet(entity: company, periods: periods, accounts: accounts)
	/// let incomeStmt = try IncomeStatement(entity: company, periods: periods, accounts: accounts)
	///
	/// // Calculate turnover
	/// let turnover = balanceSheet.workingCapitalTurnover(revenue: incomeStmt.totalRevenue)
	///
	/// print("Q2 WC Turnover: \(turnover[q2]!)×")  // e.g., 5.2×
	/// // Interpretation: Every $1 of working capital generates $5.20 in revenue
	/// ```
	///
	/// ## Industry Benchmarks
	///
	/// Typical ranges by industry:
	/// - **Retail**: 10-15× (low inventory, high volume, negative CCC)
	/// - **Manufacturing**: 4-8× (higher inventory and AR)
	/// - **Technology/SaaS**: 15-25× (minimal working capital needs)
	/// - **Wholesale/Distribution**: 6-10× (moderate inventory turnover)
	///
	/// ## LBO Use Case
	///
	/// ```swift
	/// // Assess working capital efficiency post-acquisition
	/// let baselineTurnover = turnover[acquisitionDate]!
	/// let currentTurnover = turnover[latestQuarter]!
	///
	/// if currentTurnover > baselineTurnover {
	///     let improvement = ((currentTurnover / baselineTurnover) - 1) * 100
	///     print("WC turnover improved \(improvement)% - operational excellence value creation")
	/// }
	///
	/// // Calculate freed cash from working capital improvement
	/// let revenue = incomeStmt.totalRevenue[latestQuarter]!
	/// let optimalWC = revenue / industryBenchmarkTurnover  // e.g., 8×
	/// let actualWC = balanceSheet.netWorkingCapital[latestQuarter]!
	/// let excessWC = actualWC - optimalWC
	/// print("Potential cash release: $\(excessWC)")
	/// ```
	///
	/// - Parameter revenue: Revenue time series (typically from income statement)
	/// - Returns: Working capital turnover ratio for each period
	/// - SeeAlso: ``netWorkingCapital``
	/// - SeeAlso: ``IncomeStatement/totalRevenue``
	public func workingCapitalTurnover(revenue: TimeSeries<T>) -> TimeSeries<T> {
		let nwc = self.netWorkingCapital

		let turnoverValues = periods.enumerated().map { (index, period) -> T in
			let currentRevenue = revenue[period]!

			if index == 0 {
				// First period: use current working capital
				let currentWC = nwc[period]!
				return currentRevenue / currentWC
			} else {
				// Subsequent periods: use average working capital
				let currentWC = nwc[period]!
				let priorWC = nwc[periods[index - 1]]!
				let averageWC = (currentWC + priorWC) / T(2)
				return currentRevenue / averageWC
			}
		}

		return TimeSeries(periods: periods, values: turnoverValues)
	}

	// MARK: - Financial Ratios

	/// Current ratio (current assets / current liabilities).
	///
	/// Measures ability to pay short-term obligations. A ratio above 1.0
	/// indicates sufficient current assets to cover current liabilities.
	public var currentRatio: TimeSeries<T> {
		return currentAssets / currentLiabilities
	}

	/// Debt-to-equity ratio (interest-bearing debt / total equity).
	///
	/// Measures financial leverage using only interest-bearing debt (excludes non-interest liabilities
	/// like accounts payable). Higher ratios indicate more debt relative to equity, which increases financial risk.
	public var debtToEquity: TimeSeries<T> {
		return interestBearingDebt / totalEquity
	}

	/// Equity ratio (total equity / total assets).
	///
	/// Measures the proportion of assets financed by equity. Higher ratios
	/// indicate lower financial risk.
	public var equityRatio: TimeSeries<T> {
		return totalEquity / totalAssets
	}

	/// Quick ratio (acid-test ratio) - ability to pay current liabilities with liquid assets.
	///
	/// The quick ratio excludes inventory from current assets, providing a more conservative
	/// measure of liquidity than the current ratio.
	///
	/// ## Formula
	///
	/// ```
	/// Quick Ratio = (Current Assets - Inventory) / Current Liabilities
	/// ```
	///
	/// ## Interpretation
	///
	/// - **> 1.0**: Company can pay current liabilities with liquid assets (healthy)
	/// - **0.5-1.0**: Acceptable liquidity for most industries
	/// - **< 0.5**: May struggle to meet short-term obligations
	///
	/// ## When to Use
	///
	/// Quick ratio is more relevant than current ratio when:
	/// - Inventory is slow-moving or hard to liquidate
	/// - Company is in distress (inventory may not sell quickly)
	/// - Comparing companies with different inventory levels
	///
	/// ## Example
	///
	/// ```swift
	/// let balanceSheet = try BalanceSheet(...)
	/// let quickRatio = balanceSheet.quickRatio
	///
	/// let q1 = Period.quarter(year: 2025, quarter: 1)
	/// print("Quick Ratio: \(quickRatio[q1]!)")  // e.g., "Quick Ratio: 1.2"
	/// ```
	public var quickRatio: TimeSeries<T> {
		// Find inventory in current assets
		let inventoryAccounts = assetAccounts.filter {
			$0.balanceSheetRole == .inventory
		}

		let inventory: TimeSeries<T>
		if !inventoryAccounts.isEmpty {
			inventory = FinancialStatementHelpers.aggregateAccounts(inventoryAccounts, periods: periods)
		} else {
			// No inventory - quick ratio equals current ratio
			let zero = T(0)
			let periods = currentAssets.periods
			let zeroValues = periods.map { _ in zero }
			inventory = TimeSeries(periods: periods, values: zeroValues)
		}
		print("Current Assets: \(currentAssets.valuesArray)")
		print("\tless Inventory: \(inventory.valuesArray)")
		print("\t= Quick Assets: \(zip(currentAssets.valuesArray,inventory.valuesArray).map({$0.0 - $0.1}))")
		print("Current Liabilities: \(currentLiabilities.valuesArray)")
		// Quick Ratio = (Current Assets - Inventory) / Current Liabilities
		let quickAssets = currentAssets - inventory
		return quickAssets / currentLiabilities
	}

	/// Cash ratio - most conservative liquidity measure.
	///
	/// The cash ratio only counts cash and cash equivalents, excluding all other current assets.
	/// This is the most stringent test of a company's ability to pay immediate obligations.
	///
	/// ## Formula
	///
	/// ```
	/// Cash Ratio = (Cash + Cash Equivalents) / Current Liabilities
	/// ```
	///
	/// ## Interpretation
	///
	/// - **> 0.5**: Excellent liquidity (can pay half of current liabilities with cash)
	/// - **0.2-0.5**: Acceptable liquidity for most businesses
	/// - **< 0.2**: Low cash reserves (may need to liquidate other assets)
	///
	/// ## When to Use
	///
	/// Cash ratio is most relevant when:
	/// - Analyzing financial distress or bankruptcy risk
	/// - Evaluating companies in volatile industries
	/// - Assessing ability to weather unexpected disruptions
	/// - Comparing cash management efficiency
	///
	/// ## Example
	///
	/// ```swift
	/// let balanceSheet = try BalanceSheet(...)
	/// let cashRatio = balanceSheet.cashRatio
	///
	/// let q1 = Period.quarter(year: 2025, quarter: 1)
	/// print("Cash Ratio: \(cashRatio[q1]!)")  // e.g., "Cash Ratio: 0.35"
	/// ```
	public var cashRatio: TimeSeries<T> {
		// Cash Ratio = Cash / Current Liabilities
		// Use the cashAndEquivalents property which handles aggregation and missing accounts
		return cashAndEquivalents / currentLiabilities
	}

	/// Debt ratio - proportion of assets financed by debt.
	///
	/// The debt ratio measures financial leverage by comparing total liabilities to total assets.
	/// Lower ratio indicates less risk from debt financing.
	///
	/// ## Formula
	///
	/// ```
	/// Debt Ratio = Total Liabilities / Total Assets
	/// ```
	///
	/// ## Interpretation
	///
	/// - **< 0.3**: Low leverage (conservative financing)
	/// - **0.3-0.6**: Moderate leverage (typical for many industries)
	/// - **> 0.6**: High leverage (higher financial risk)
	///
	/// ## Industry Variation
	///
	/// - **Capital-intensive industries** (utilities, telecom): 0.5-0.7 is normal
	/// - **Technology/Services**: 0.2-0.4 is typical
	/// - **Real estate**: 0.6-0.8 is common (asset-backed lending)
	///
	/// ## Related Metrics
	///
	/// - Debt-to-Equity Ratio = Total Liabilities / Total Equity
	/// - Equity Ratio = Total Equity / Total Assets = 1 - Debt Ratio
	///
	/// ## Example
	///
	/// ```swift
	/// let balanceSheet = try BalanceSheet(...)
	/// let debtRatio = balanceSheet.debtRatio
	///
	/// let q1 = Period.quarter(year: 2025, quarter: 1)
	/// print("Debt Ratio: \(debtRatio[q1]! * 100)%")  // e.g., "Debt Ratio: 45.0%"
	/// ```
	public var debtRatio: TimeSeries<T> {
		return totalLiabilities / totalAssets
	}

	// MARK: - Validation

	/// Validates the accounting equation: Assets = Liabilities + Equity.
	///
	/// Checks that the fundamental accounting equation holds for each period
	/// within the specified tolerance.
	///
	/// - Parameter tolerance: Maximum acceptable difference
	/// - Throws: ``BalanceSheetError/accountingEquationViolation(period:assets:liabilitiesAndEquity:)``
	///   if the equation is violated for any period
	///
	/// ## Example
	/// ```swift
	/// try balanceSheet.validate(tolerance: 0.01)
	/// ```
	public func validate(tolerance: T) throws {
		let assets = totalAssets
		let liabilities = totalLiabilities
		let equity = totalEquity

		for period in periods {
			guard let assetValue = assets[period],
				  let liabilityValue = liabilities[period],
				  let equityValue = equity[period] else {
				continue
			}

			let liabilitiesAndEquity = liabilityValue + equityValue
			let difference = abs(assetValue - liabilitiesAndEquity)

			if difference > tolerance {
				// Convert to Double for error message
				let assetsDouble = Double(exactly: assetValue as! NSNumber) ?? 0.0
				let laeDouble = Double(exactly: liabilitiesAndEquity as! NSNumber) ?? 0.0
				throw BalanceSheetError.accountingEquationViolation(
					period: period,
					assets: assetsDouble,
					liabilitiesAndEquity: laeDouble
				)
			}
		}
	}

}

// MARK: - Materialized Balance Sheet

extension BalanceSheet {

	/// Materialized version of a balance sheet with pre-computed metrics.
	///
	/// Use `Materialized` when computing metrics repeatedly across many companies.
	/// All metrics are computed once and stored, trading memory for speed.
	///
	/// ## Example
	/// ```swift
	/// let materialized = balanceSheet.materialize()
	///
	/// // Metrics are pre-computed, not recalculated on each access
	/// for period in materialized.periods {
	///     print("Period: \(period)")
	///     print("  Current Ratio: \(materialized.currentRatio[period] ?? 0)")
	///     print("  Debt/Equity: \(materialized.debtToEquity[period] ?? 0)")
	/// }
	/// ```
	public struct Materialized: Sendable {
		/// The entity this balance sheet belongs to.
		public let entity: Entity

		/// The time periods covered by this balance sheet.
		public let periods: [Period]

		/// All accounts in the balance sheet (assets, liabilities, equity).
		public let accounts: [Account<T>]

		// Pre-computed totals

		/// Total assets: Sum of all asset accounts.
		///
		/// Per the accounting equation: Assets = Liabilities + Equity
		public let totalAssets: TimeSeries<T>

		/// Total liabilities: Sum of all liability accounts.
		public let totalLiabilities: TimeSeries<T>

		/// Total equity: Sum of all equity accounts.
		///
		/// Also equals: Assets - Liabilities (by the accounting equation)
		public let totalEquity: TimeSeries<T>

		// Pre-computed liquidity metrics

		/// Current assets: Assets expected to convert to cash within one year.
		///
		/// Includes: Cash, marketable securities, accounts receivable, inventory.
		public let currentAssets: TimeSeries<T>

		/// Current liabilities: Obligations due within one year.
		///
		/// Includes: Accounts payable, short-term debt, accrued expenses.
		public let currentLiabilities: TimeSeries<T>

		/// Working capital: Current Assets - Current Liabilities.
		///
		/// Measures short-term liquidity and operational efficiency.
		/// Positive working capital means the company can cover short-term obligations.
		public let workingCapital: TimeSeries<T>

		// Pre-computed ratios

		/// Current ratio: Current Assets / Current Liabilities.
		///
		/// Key liquidity measure. Typical healthy range: 1.5-3.0.
		/// Below 1.0 indicates potential liquidity problems.
		public let currentRatio: TimeSeries<T>

		/// Debt-to-equity ratio: Total Liabilities / Total Equity.
		///
		/// Measures financial leverage. Higher ratio = more debt financing.
		/// Typical ranges: 0.5-1.5 (varies by industry).
		public let debtToEquity: TimeSeries<T>

		/// Equity ratio: Total Equity / Total Assets.
		///
		/// Percentage of assets financed by shareholders' equity.
		/// Higher ratio indicates less leverage and more financial stability.
		public let equityRatio: TimeSeries<T>
	}

	/// Creates a materialized version with all metrics pre-computed.
	///
	/// - Returns: A ``Materialized`` balance sheet with pre-computed metrics
	public func materialize() -> Materialized {
		return Materialized(
			entity: entity,
			periods: periods,
			accounts: accounts,
			totalAssets: totalAssets,
			totalLiabilities: totalLiabilities,
			totalEquity: totalEquity,
			currentAssets: currentAssets,
			currentLiabilities: currentLiabilities,
			workingCapital: workingCapital,
			currentRatio: currentRatio,
			debtToEquity: debtToEquity,
			equityRatio: equityRatio
		)
	}
}

// MARK: - Codable Conformance

/// Codable conformance for BalanceSheet enables JSON serialization.
///
/// Only encodes the essential data (entity, periods, accounts). Computed properties
/// like totals and ratios are recalculated upon decoding.
///
/// ## Example
/// ```swift
/// let balanceSheet = BalanceSheet(...)
/// let json = try JSONEncoder().encode(balanceSheet)
/// let decoded = try JSONDecoder().decode(BalanceSheet<Double>.self, from: json)
/// ```
extension BalanceSheet: Codable {

	private enum CodingKeys: String, CodingKey {
		case entity
		case periods
		case accounts
	}

	/// Encode the balance sheet to an encoder.
	///
	/// Only encodes entity, periods, and accounts. Computed metrics are not encoded.
	///
	/// - Parameter encoder: The encoder to write to
	/// - Throws: EncodingError if encoding fails
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(entity, forKey: .entity)
		try container.encode(periods, forKey: .periods)
		try container.encode(accounts, forKey: .accounts)
	}

	/// Decode a balance sheet from a decoder.
	///
	/// Reconstructs the balance sheet from entity, periods, and accounts.
	/// All computed metrics (totals, ratios) are automatically recalculated.
	///
	/// - Parameter decoder: The decoder to read from
	/// - Throws: DecodingError if decoding fails, or validation errors from init
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let entity = try container.decode(Entity.self, forKey: .entity)
		let periods = try container.decode([Period].self, forKey: .periods)
		let accounts = try container.decode([Account<T>].self, forKey: .accounts)

		try self.init(
			entity: entity,
			periods: periods,
			accounts: accounts
		)
	}
}


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
/// - ``init(entity:periods:assetAccounts:liabilityAccounts:equityAccounts:)``
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

	/// All asset accounts.
	public let assetAccounts: [Account<T>]

	/// All liability accounts.
	public let liabilityAccounts: [Account<T>]

	/// All equity accounts.
	public let equityAccounts: [Account<T>]

	/// Creates a balance sheet with validation.
	///
	/// - Parameters:
	///   - entity: The entity this statement belongs to
	///   - periods: The periods covered
	///   - assetAccounts: Asset accounts (must have type .asset)
	///   - liabilityAccounts: Liability accounts (must have type .liability)
	///   - equityAccounts: Equity accounts (must have type .equity)
	///
	/// - Throws: ``BalanceSheetError`` if validation fails
	public init(
		entity: Entity,
		periods: [Period],
		assetAccounts: [Account<T>],
		liabilityAccounts: [Account<T>],
		equityAccounts: [Account<T>]
	) throws {
		// Validate entity consistency
		for account in assetAccounts + liabilityAccounts + equityAccounts {
			guard account.entity == entity else {
				throw BalanceSheetError.entityMismatch
			}
		}

		// Validate account types
		for account in assetAccounts {
			guard account.type == .asset else {
				throw BalanceSheetError.invalidAccountType(expected: .asset, actual: account.type)
			}
		}

		for account in liabilityAccounts {
			guard account.type == .liability else {
				throw BalanceSheetError.invalidAccountType(expected: .liability, actual: account.type)
			}
		}

		for account in equityAccounts {
			guard account.type == .equity else {
				throw BalanceSheetError.invalidAccountType(expected: .equity, actual: account.type)
			}
		}

		self.entity = entity
		self.periods = periods
		self.assetAccounts = assetAccounts
		self.liabilityAccounts = liabilityAccounts
		self.equityAccounts = equityAccounts
	}

	// MARK: - Aggregated Totals

	/// Total assets across all asset accounts.
	public var totalAssets: TimeSeries<T> {
		return aggregateAccounts(assetAccounts)
	}

	/// Total liabilities across all liability accounts.
	public var totalLiabilities: TimeSeries<T> {
		return aggregateAccounts(liabilityAccounts)
	}

	/// Total equity across all equity accounts.
	public var totalEquity: TimeSeries<T> {
		return aggregateAccounts(equityAccounts)
	}

	// MARK: - Liquidity Metrics

	/// Current assets (assets with category "Current").
	///
	/// Current assets are expected to be converted to cash within one year.
	public var currentAssets: TimeSeries<T> {
		let current = assetAccounts.filter { $0.metadata?.category == "Current" }
		return aggregateAccounts(current)
	}

	/// Current liabilities (liabilities with category "Current").
	///
	/// Current liabilities are expected to be paid within one year.
	public var currentLiabilities: TimeSeries<T> {
		let current = liabilityAccounts.filter { $0.metadata?.category == "Current" }
		return aggregateAccounts(current)
	}

	/// Working capital (current assets - current liabilities).
	///
	/// Measures short-term liquidity.
	public var workingCapital: TimeSeries<T> {
		return currentAssets - currentLiabilities
	}

	// MARK: - Financial Ratios

	/// Current ratio (current assets / current liabilities).
	///
	/// Measures ability to pay short-term obligations. A ratio above 1.0
	/// indicates sufficient current assets to cover current liabilities.
	public var currentRatio: TimeSeries<T> {
		return currentAssets / currentLiabilities
	}

	/// Debt-to-equity ratio (total liabilities / total equity).
	///
	/// Measures financial leverage. Higher ratios indicate more debt relative
	/// to equity, which increases financial risk.
	public var debtToEquity: TimeSeries<T> {
		return totalLiabilities / totalEquity
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
			$0.metadata?.category == "Current" &&
			$0.name.localizedCaseInsensitiveContains("Inventory")
		}

		let inventory: TimeSeries<T>
		if !inventoryAccounts.isEmpty {
			inventory = aggregateAccounts(inventoryAccounts)
		} else {
			// No inventory - quick ratio equals current ratio
			let zero = T(0)
			let periods = currentAssets.periods
			let zeroValues = periods.map { _ in zero }
			inventory = TimeSeries(periods: periods, values: zeroValues)
		}

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
		// Find cash and cash equivalents in current assets
		let cashAccounts = assetAccounts.filter {
			$0.metadata?.category == "Current" && (
				$0.name.localizedCaseInsensitiveContains("Cash") ||
				$0.name.localizedCaseInsensitiveContains("Cash Equivalent") ||
				$0.name.localizedCaseInsensitiveContains("Marketable Securities")
			)
		}

		let cash: TimeSeries<T>
		if !cashAccounts.isEmpty {
			cash = aggregateAccounts(cashAccounts)
		} else {
			// No cash accounts found - cash ratio is zero
			let zero = T(0)
			let periods = currentAssets.periods
			let zeroValues = periods.map { _ in zero }
			cash = TimeSeries(periods: periods, values: zeroValues)
		}

		// Cash Ratio = Cash / Current Liabilities
		return cash / currentLiabilities
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

	// MARK: - Helper Methods

	/// Aggregates multiple accounts into a single time series.
	private func aggregateAccounts(_ accounts: [Account<T>]) -> TimeSeries<T> {
		guard !accounts.isEmpty else {
			// Return zero-filled series for empty account list
			let zeros = Array(repeating: T(0), count: periods.count)
			return TimeSeries(periods: periods, values: zeros)
		}

		// Start with first account's time series
		var result = accounts[0].timeSeries

		// Add remaining accounts
		for account in accounts.dropFirst() {
			result = result + account.timeSeries
		}

		return result
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
		public let entity: Entity
		public let periods: [Period]

		public let assetAccounts: [Account<T>]
		public let liabilityAccounts: [Account<T>]
		public let equityAccounts: [Account<T>]

		// Pre-computed totals
		public let totalAssets: TimeSeries<T>
		public let totalLiabilities: TimeSeries<T>
		public let totalEquity: TimeSeries<T>

		// Pre-computed liquidity metrics
		public let currentAssets: TimeSeries<T>
		public let currentLiabilities: TimeSeries<T>
		public let workingCapital: TimeSeries<T>

		// Pre-computed ratios
		public let currentRatio: TimeSeries<T>
		public let debtToEquity: TimeSeries<T>
		public let equityRatio: TimeSeries<T>
	}

	/// Creates a materialized version with all metrics pre-computed.
	///
	/// - Returns: A ``Materialized`` balance sheet with pre-computed metrics
	public func materialize() -> Materialized {
		return Materialized(
			entity: entity,
			periods: periods,
			assetAccounts: assetAccounts,
			liabilityAccounts: liabilityAccounts,
			equityAccounts: equityAccounts,
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

extension BalanceSheet: Codable {

	private enum CodingKeys: String, CodingKey {
		case entity
		case periods
		case assetAccounts
		case liabilityAccounts
		case equityAccounts
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(entity, forKey: .entity)
		try container.encode(periods, forKey: .periods)
		try container.encode(assetAccounts, forKey: .assetAccounts)
		try container.encode(liabilityAccounts, forKey: .liabilityAccounts)
		try container.encode(equityAccounts, forKey: .equityAccounts)
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let entity = try container.decode(Entity.self, forKey: .entity)
		let periods = try container.decode([Period].self, forKey: .periods)
		let assetAccounts = try container.decode([Account<T>].self, forKey: .assetAccounts)
		let liabilityAccounts = try container.decode([Account<T>].self, forKey: .liabilityAccounts)
		let equityAccounts = try container.decode([Account<T>].self, forKey: .equityAccounts)

		try self.init(
			entity: entity,
			periods: periods,
			assetAccounts: assetAccounts,
			liabilityAccounts: liabilityAccounts,
			equityAccounts: equityAccounts
		)
	}
}

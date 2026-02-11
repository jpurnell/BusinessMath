//
//  MultiPeriodReport.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/23/25.
//

import Foundation
import Numerics

/// Multi-period financial report showing performance across multiple periods.
///
/// `MultiPeriodReport` aggregates multiple `FinancialPeriodSummary` instances to show
/// trends, growth rates, and period-over-period comparisons. Commonly used for quarterly
/// reports (4 quarters + annual) or year-over-year analysis.
///
/// ## Design Philosophy
///
/// - **Presentation-agnostic**: Provides data structure only
/// - **Comparative analysis**: Calculates growth rates and changes
/// - **Flexible periods**: Any combination of periods (not just quarters)
/// - **Optional annual**: Can include annual/TTM summary
///
/// ## Common Use Cases
///
/// **Quarterly Report (4Q + Annual):**
/// ```swift
/// let report = try MultiPeriodReport(
///     entity: entity,
///     periodSummaries: [q1Summary, q2Summary, q3Summary, q4Summary],
///     annualSummary: annualSummary
/// )
///
/// // Access specific period
/// print("Q1 Revenue: $\(report.periodSummaries[0].revenue)")
///
/// // Calculate growth
/// let revenueGrowth = report.revenueGrowth()
/// print("Q2 revenue growth: \(revenueGrowth[1] * 100)%")
/// ```
///
/// **Year-over-Year Comparison:**
/// ```swift
/// let report = try MultiPeriodReport(
///     entity: entity,
///     periodSummaries: [fy2023, fy2024, fy2025]
/// )
/// ```
public struct MultiPeriodReport<T: Real & Sendable>: Codable, Sendable where T: Codable {
	/// The entity this report belongs to
	public let entity: Entity

	/// Period summaries in chronological order
	public let periodSummaries: [FinancialPeriodSummary<T>]

	/// Optional annual or trailing-twelve-months summary
	public let annualSummary: FinancialPeriodSummary<T>?

	/// Create a multi-period financial report.
	///
	/// - Parameters:
	///   - entity: The entity this report belongs to
	///   - periodSummaries: Array of period summaries (will be sorted chronologically)
	///   - annualSummary: Optional annual or TTM summary
	/// - Throws: If summaries belong to different entities or array is empty
	public init(
		entity: Entity,
		periodSummaries: [FinancialPeriodSummary<T>],
		annualSummary: FinancialPeriodSummary<T>? = nil
	) throws {
		guard !periodSummaries.isEmpty else {
			throw MultiPeriodReportError.emptyPeriods
		}

		// Verify all summaries are for the same entity
		guard periodSummaries.allSatisfy({ $0.entity.id == entity.id }) else {
			throw MultiPeriodReportError.entityMismatch
		}

		if let annual = annualSummary {
			guard annual.entity.id == entity.id else {
				throw MultiPeriodReportError.entityMismatch
			}
		}

		self.entity = entity

		// Sort periods chronologically
		self.periodSummaries = periodSummaries.sorted { $0.period.startDate < $1.period.startDate }
		self.annualSummary = annualSummary
	}

	// MARK: - Accessors

	/// Number of periods in the report
	public var periodCount: Int {
		periodSummaries.count
	}

	/// Get summary for a specific period
	public subscript(period: Period) -> FinancialPeriodSummary<T>? {
		periodSummaries.first { $0.period == period }
	}

	/// Get summary at specific index
	public subscript(index: Int) -> FinancialPeriodSummary<T> {
		periodSummaries[index]
	}

	// MARK: - Growth Rate Calculations

	/// Calculate period-over-period revenue growth rates.
	///
	/// Returns growth rates starting from the second period.
	/// For example, with 4 quarters, returns 3 growth rates (Q2/Q1, Q3/Q2, Q4/Q3).
	///
	/// - Returns: Array of growth rates (as decimals, e.g., 0.10 = 10% growth)
	public func revenueGrowth() -> [T] {
		calculateGrowth { $0.revenue }
	}

	/// Calculate period-over-period EBITDA growth rates.
	public func ebitdaGrowth() -> [T] {
		calculateGrowth { $0.ebitda }
	}

	/// Calculate period-over-period net income growth rates.
	public func netIncomeGrowth() -> [T] {
		calculateGrowth { $0.netIncome }
	}

	/// Calculate period-over-period earnings per share growth (requires valuation data).
	///
	/// - Returns: Array of EPS growth rates, or empty if valuation data not available
	public func epsGrowth() -> [T] {
		// EPS = Net Income / Shares Outstanding
		// We need market data for shares outstanding
		var epsSeries: [T] = []

		for summary in periodSummaries {
			// Check if we have market data indirectly by checking if marketCap exists
			if let marketCap = summary.marketCap, marketCap != T(0), summary.netIncome != T(0) {
				// EPS approximation: if we have market cap and PE ratio, we can derive EPS
				// But it's better to calculate from net income and shares
				// For now, just track net income as proxy
				epsSeries.append(summary.netIncome)
			}
		}

		guard epsSeries.count > 1 else { return [] }

		return calculateGrowthFromSeries(epsSeries)
	}

	// MARK: - Margin Trend Analysis

	/// Track gross margin across all periods.
	///
	/// - Returns: Array of gross margins for each period
	public func grossMarginTrend() -> [T] {
		periodSummaries.map { $0.grossMargin }
	}

	/// Track operating margin across all periods.
	public func operatingMarginTrend() -> [T] {
		periodSummaries.map { $0.operatingMargin }
	}

	/// Track net margin across all periods.
	public func netMarginTrend() -> [T] {
		periodSummaries.map { $0.netMargin }
	}

	// MARK: - Ratio Trend Analysis

	/// Track ROE across all periods.
	public func roeTrend() -> [T] {
		periodSummaries.map { $0.roe }
	}

	/// Track ROA across all periods.
	public func roaTrend() -> [T] {
		periodSummaries.map { $0.roa }
	}

	/// Track debt-to-equity ratio across all periods.
	public func debtToEquityTrend() -> [T] {
		periodSummaries.map { $0.debtToEquityRatio }
	}

	/// Track current ratio across all periods.
	public func currentRatioTrend() -> [T] {
		periodSummaries.map { $0.currentRatio }
	}

	/// Track debt-to-EBITDA ratio across all periods.
	public func debtToEBITDATrend() -> [T] {
		periodSummaries.map { $0.debtToEBITDARatio }
	}

	// MARK: - Valuation Trend Analysis

	/// Track P/E ratio across all periods (if available).
	///
	/// - Returns: Array of P/E ratios, nil values indicate missing data
	public func peRatioTrend() -> [T?] {
		periodSummaries.map { $0.peRatio }
	}

	/// Track P/B ratio across all periods (if available).
	public func pbRatioTrend() -> [T?] {
		periodSummaries.map { $0.pbRatio }
	}

	/// Track P/S ratio across all periods (if available).
	public func psRatioTrend() -> [T?] {
		periodSummaries.map { $0.psRatio }
	}

	/// Track EV/EBITDA across all periods (if available).
	public func evToEBITDATrend() -> [T?] {
		periodSummaries.map { $0.evToEBITDARatio }
	}

	// MARK: - Period-over-Period Changes

	/// Calculate period-over-period change in a metric.
	///
	/// - Parameter metric: Closure that extracts the metric from a summary
	/// - Returns: Array of changes (current - prior)
	public func periodOverPeriodChange(_ metric: (FinancialPeriodSummary<T>) -> T) -> [T] {
		guard periodSummaries.count > 1 else { return [] }

		var changes: [T] = []
		for i in 1..<periodSummaries.count {
			let current = metric(periodSummaries[i])
			let prior = metric(periodSummaries[i - 1])
			changes.append(current - prior)
		}
		return changes
	}

	// MARK: - Helper Methods

	/// Calculate period-over-period growth rates for a metric.
	///
	/// - Parameter metric: Closure that extracts the metric from a summary
	/// - Returns: Array of growth rates (as decimals)
	private func calculateGrowth(_ metric: (FinancialPeriodSummary<T>) -> T) -> [T] {
		guard periodSummaries.count > 1 else { return [] }

		var growthRates: [T] = []
		for i in 1..<periodSummaries.count {
			let current = metric(periodSummaries[i])
			let prior = metric(periodSummaries[i - 1])

			if prior != T(0) {
				let growth = (current - prior) / prior
				growthRates.append(growth)
			} else {
				growthRates.append(T(0))
			}
		}
		return growthRates
	}

	/// Calculate growth rates from a series of values.
	private func calculateGrowthFromSeries(_ series: [T]) -> [T] {
		guard series.count > 1 else { return [] }

		var growthRates: [T] = []
		for i in 1..<series.count {
			let current = series[i]
			let prior = series[i - 1]

			if prior != T(0) {
				let growth = (current - prior) / prior
				growthRates.append(growth)
			} else {
				growthRates.append(T(0))
			}
		}
		return growthRates
	}
}

// MARK: - Errors

/// Errors related to multi-period reports.
public enum MultiPeriodReportError: Error, CustomStringConvertible {
	/// Period summaries array is empty
	case emptyPeriods

	/// Summaries belong to different entities
	case entityMismatch
	
	/// String describing the error for logging and debugging
	public var description: String {
		switch self {
		case .emptyPeriods:
			return "Multi-period report must contain at least one period summary"
		case .entityMismatch:
			return "All period summaries must belong to the same entity"
		}
	}
}

// MARK: - Convenience Extensions

extension MultiPeriodReport {
	/// Create a report from financial statements across multiple periods.
	///
	/// This convenience initializer creates FinancialPeriodSummary for each period.
	/// Each income statement and balance sheet should represent a single period.
	///
	/// - Parameters:
	///   - entity: The entity
	///   - periods: The periods for each financial statement (must match statement array lengths)
	///   - incomeStatements: Income statements for each period (one per period)
	///   - balanceSheets: Balance sheets for each period (one per period)
	///   - cashFlowStatements: Optional cash flow statements (one per period)
	///   - marketData: Optional market data (one per period)
	///   - operationalMetrics: Optional operational metrics (one per period)
	/// - Returns: MultiPeriodReport with summaries for all periods
	public static func create(
		entity: Entity,
		periods: [Period],
		incomeStatements: [IncomeStatement<T>],
		balanceSheets: [BalanceSheet<T>],
		cashFlowStatements: [CashFlowStatement<T>]? = nil,
		marketData: [MarketData<T>]? = nil,
		operationalMetrics: [OperationalMetrics<T>]? = nil
	) throws -> MultiPeriodReport<T> {
		guard incomeStatements.count == balanceSheets.count,
		      incomeStatements.count == periods.count else {
			throw MultiPeriodReportError.emptyPeriods
		}

		var summaries: [FinancialPeriodSummary<T>] = []
		for (index, period) in periods.enumerated() {
			let cfs = cashFlowStatements?[safe: index]
			let market = marketData?[safe: index]
			let opMetrics = operationalMetrics?[safe: index]

			let summary = try FinancialPeriodSummary(
				entity: entity,
				period: period,
				incomeStatement: incomeStatements[index],
				balanceSheet: balanceSheets[index],
				cashFlowStatement: cfs,
				marketData: market,
				operationalMetrics: opMetrics
			)
			summaries.append(summary)
		}

		return try MultiPeriodReport(
			entity: entity,
			periodSummaries: summaries
		)
	}
}

// MARK: - Array Extension for Safe Subscripting

private extension Array {
	subscript(safe index: Int) -> Element? {
		indices.contains(index) ? self[index] : nil
	}
}

//
//  MarketMetrics.swift
//  BusinessMath
//
//  Created by Justin Purnell on 3/20/26.
//

import Foundation

// MARK: - MarketMetrics

/// A typed collection of market metrics and financial ratios for a security.
///
/// `MarketMetrics` provides structured access to common financial ratios and
/// market data points. Standard metrics are typed as optional `Double` properties,
/// while the ``additionalMetrics`` dictionary provides an extensibility escape hatch
/// for provider-specific metrics.
///
/// ## Usage
///
/// ```swift
/// let metrics = try await provider.fetchMetrics(symbol: "AAPL")
///
/// if let pe = metrics.priceToEarnings {
///     print("P/E Ratio: \(pe)")
/// }
///
/// if let custom = metrics.additionalMetrics["returnOnEquity"] {
///     print("ROE: \(custom)")
/// }
/// ```
///
/// ## Topics
///
/// ### Valuation Ratios
/// - ``priceToEarnings``
/// - ``priceToBook``
/// - ``priceToSales``
///
/// ### Market Data
/// - ``marketCapitalization``
/// - ``earningsPerShare``
/// - ``dividendYield``
/// - ``beta``
///
/// ### Price Range
/// - ``fiftyTwoWeekHigh``
/// - ``fiftyTwoWeekLow``
public struct MarketMetrics: Codable, Sendable, Equatable {

	/// The ticker symbol this data represents.
	public let symbol: String

	/// The date these metrics were observed.
	public let asOf: Date

	// MARK: - Valuation Ratios

	/// Price-to-earnings ratio (P/E). Nil if unavailable or earnings are negative.
	public let priceToEarnings: Double?

	/// Price-to-book ratio (P/B). Nil if unavailable.
	public let priceToBook: Double?

	/// Price-to-sales ratio (P/S). Nil if unavailable.
	public let priceToSales: Double?

	// MARK: - Market Data

	/// Total market capitalization in the security's reporting currency.
	public let marketCapitalization: Double?

	/// Earnings per share (EPS). Nil if unavailable.
	public let earningsPerShare: Double?

	/// Dividend yield as a decimal (e.g., 0.02 for 2%). Nil if no dividend.
	public let dividendYield: Double?

	/// Beta coefficient measuring systematic risk relative to the market.
	public let beta: Double?

	// MARK: - Price Range

	/// 52-week high price. Nil if unavailable.
	public let fiftyTwoWeekHigh: Double?

	/// 52-week low price. Nil if unavailable.
	public let fiftyTwoWeekLow: Double?

	// MARK: - Extensibility

	/// Additional provider-specific metrics not covered by the standard fields.
	///
	/// Use this for metrics like return on equity, debt-to-equity, enterprise
	/// value ratios, or any provider-specific data points.
	public let additionalMetrics: [String: Double]

	// MARK: - Initialization

	/// Creates a new market metrics instance.
	///
	/// - Parameters:
	///   - symbol: The ticker symbol.
	///   - asOf: The observation date.
	///   - priceToEarnings: P/E ratio. Pass nil if unavailable.
	///   - priceToBook: P/B ratio. Pass nil if unavailable.
	///   - priceToSales: P/S ratio. Pass nil if unavailable.
	///   - marketCapitalization: Market cap in reporting currency. Pass nil if unavailable.
	///   - earningsPerShare: EPS. Pass nil if unavailable.
	///   - dividendYield: Dividend yield as decimal. Pass nil if no dividend.
	///   - beta: Beta coefficient. Pass nil if unavailable.
	///   - fiftyTwoWeekHigh: 52-week high. Pass nil if unavailable.
	///   - fiftyTwoWeekLow: 52-week low. Pass nil if unavailable.
	///   - additionalMetrics: Extra metrics dictionary. Defaults to empty.
	public init(
		symbol: String,
		asOf: Date,
		priceToEarnings: Double? = nil,
		priceToBook: Double? = nil,
		priceToSales: Double? = nil,
		marketCapitalization: Double? = nil,
		earningsPerShare: Double? = nil,
		dividendYield: Double? = nil,
		beta: Double? = nil,
		fiftyTwoWeekHigh: Double? = nil,
		fiftyTwoWeekLow: Double? = nil,
		additionalMetrics: [String: Double] = [:]
	) {
		self.symbol = symbol
		self.asOf = asOf
		self.priceToEarnings = priceToEarnings
		self.priceToBook = priceToBook
		self.priceToSales = priceToSales
		self.marketCapitalization = marketCapitalization
		self.earningsPerShare = earningsPerShare
		self.dividendYield = dividendYield
		self.beta = beta
		self.fiftyTwoWeekHigh = fiftyTwoWeekHigh
		self.fiftyTwoWeekLow = fiftyTwoWeekLow
		self.additionalMetrics = additionalMetrics
	}
}

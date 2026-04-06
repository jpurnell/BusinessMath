import Testing
import Foundation
@testable import BusinessMath

// MARK: - Split Protocol Tests

@Suite("Split Protocol Tests")
struct SplitProtocolTests {

	// MARK: - Mock Providers

	/// A provider that only provides stock prices — no financials, no metrics.
	final class MockStockPriceOnly: StockPriceProvider, @unchecked Sendable {
		var callCount = 0

		func fetchStockPrice(
			symbol: String,
			from: Date,
			to: Date
		) async throws -> TimeSeries<Double> {
			callCount += 1
			let periods = [Period.day(from)]
			let values = [150.0]
			return TimeSeries(periods: periods, values: values)
		}
	}

	/// A provider that provides financial statements.
	final class MockFinancialsOnly: FinancialsProvider, @unchecked Sendable {
		var incomeCallCount = 0
		var balanceCallCount = 0
		var cashFlowCallCount = 0

		func fetchIncomeStatement(
			symbol: String,
			period: ReportingPeriod
		) async throws -> IncomeStatement<Double> {
			incomeCallCount += 1
			let entity = Entity(id: symbol, name: symbol)
			let periods = [Period.quarter(year: 2024, quarter: 1)]
			let revenueAccount = try Account<Double>(
				entity: entity,
				name: "Revenue",
				incomeStatementRole: .revenue,
				timeSeries: TimeSeries(periods: periods, values: [1_000_000.0])
			)
			return try IncomeStatement(
				entity: entity,
				periods: periods,
				accounts: [revenueAccount]
			)
		}

		func fetchBalanceSheet(
			symbol: String,
			period: ReportingPeriod
		) async throws -> BalanceSheet<Double> {
			balanceCallCount += 1
			let entity = Entity(id: symbol, name: symbol)
			let periods = [Period.quarter(year: 2024, quarter: 1)]
			let assetAccount = try Account<Double>(
				entity: entity,
				name: "Cash",
				balanceSheetRole: .cashAndEquivalents,
				timeSeries: TimeSeries(periods: periods, values: [500_000.0])
			)
			return try BalanceSheet(
				entity: entity,
				periods: periods,
				accounts: [assetAccount]
			)
		}

		func fetchCashFlowStatement(
			symbol: String,
			period: ReportingPeriod
		) async throws -> CashFlowStatement<Double> {
			cashFlowCallCount += 1
			let entity = Entity(id: symbol, name: symbol)
			let periods = [Period.quarter(year: 2024, quarter: 1)]
			let operatingAccount = try Account<Double>(
				entity: entity,
				name: "Net Income",
				cashFlowRole: .netIncome,
				timeSeries: TimeSeries(periods: periods, values: [200_000.0])
			)
			return try CashFlowStatement(
				entity: entity,
				periods: periods,
				accounts: [operatingAccount]
			)
		}
	}

	/// A provider that provides market metrics.
	final class MockMetricsOnly: MarketMetricsProvider, @unchecked Sendable {
		var callCount = 0

		func fetchMetrics(symbol: String) async throws -> MarketMetrics {
			callCount += 1
			return MarketMetrics(
				symbol: symbol,
				asOf: Date(),
				priceToEarnings: 15.5,
				priceToBook: 2.3,
				priceToSales: 4.1,
				marketCapitalization: 2_500_000_000_000,
				earningsPerShare: 6.42,
				dividendYield: 0.005,
				beta: 1.2,
				fiftyTwoWeekHigh: 199.62,
				fiftyTwoWeekLow: 124.17,
				additionalMetrics: ["debtToEquity": 1.87]
			)
		}
	}

	/// A full provider conforming to all three protocols (satisfies MarketDataProvider typealias).
	final class MockFullProvider: StockPriceProvider, FinancialsProvider, MarketMetricsProvider, @unchecked Sendable {
		private let stockProvider = MockStockPriceOnly()
		private let financialsProvider = MockFinancialsOnly()
		private let metricsProvider = MockMetricsOnly()

		func fetchStockPrice(symbol: String, from: Date, to: Date) async throws -> TimeSeries<Double> {
			try await stockProvider.fetchStockPrice(symbol: symbol, from: from, to: to)
		}

		func fetchIncomeStatement(symbol: String, period: ReportingPeriod) async throws -> IncomeStatement<Double> {
			try await financialsProvider.fetchIncomeStatement(symbol: symbol, period: period)
		}

		func fetchBalanceSheet(symbol: String, period: ReportingPeriod) async throws -> BalanceSheet<Double> {
			try await financialsProvider.fetchBalanceSheet(symbol: symbol, period: period)
		}

		func fetchCashFlowStatement(symbol: String, period: ReportingPeriod) async throws -> CashFlowStatement<Double> {
			try await financialsProvider.fetchCashFlowStatement(symbol: symbol, period: period)
		}

		func fetchMetrics(symbol: String) async throws -> MarketMetrics {
			try await metricsProvider.fetchMetrics(symbol: symbol)
		}
	}

	// MARK: - Golden Path Tests

	@Test("StockPriceProvider returns TimeSeries<Double>")
	func stockPriceProviderGoldenPath() async throws {
		let provider = MockStockPriceOnly()
		let from = Date(timeIntervalSince1970: 1704067200) // 2024-01-01
		let to = Date(timeIntervalSince1970: 1704153600)   // 2024-01-02

		let result = try await provider.fetchStockPrice(symbol: "AAPL", from: from, to: to)

		#expect(result.periods.count == 1)
		#expect(abs(result.valuesArray[0] - 150.0) < 1e-10)
		#expect(provider.callCount == 1)
	}

	@Test("FinancialsProvider returns typed IncomeStatement<Double>")
	func financialsProviderIncomeStatement() async throws {
		let provider = MockFinancialsOnly()

		let income = try await provider.fetchIncomeStatement(symbol: "AAPL", period: .quarterly)

		#expect(income.entity.name == "AAPL")
		#expect(income.periods.count == 1)
		#expect(provider.incomeCallCount == 1)
	}

	@Test("FinancialsProvider returns typed BalanceSheet<Double>")
	func financialsProviderBalanceSheet() async throws {
		let provider = MockFinancialsOnly()

		let balance = try await provider.fetchBalanceSheet(symbol: "AAPL", period: .annual)

		#expect(balance.entity.name == "AAPL")
		#expect(balance.periods.count == 1)
		#expect(provider.balanceCallCount == 1)
	}

	@Test("FinancialsProvider returns typed CashFlowStatement<Double>")
	func financialsProviderCashFlow() async throws {
		let provider = MockFinancialsOnly()

		let cashFlow = try await provider.fetchCashFlowStatement(symbol: "MSFT", period: .quarterly)

		#expect(cashFlow.entity.name == "MSFT")
		#expect(cashFlow.periods.count == 1)
		#expect(provider.cashFlowCallCount == 1)
	}

	@Test("MarketMetricsProvider returns typed MarketMetrics")
	func metricsProviderGoldenPath() async throws {
		let provider = MockMetricsOnly()

		let metrics = try await provider.fetchMetrics(symbol: "AAPL")

		#expect(metrics.symbol == "AAPL")
		#expect(abs((metrics.priceToEarnings ?? 0) - 15.5) < 1e-10)
		#expect(abs((metrics.beta ?? 0) - 1.2) < 1e-10)
		#expect(abs((metrics.additionalMetrics["debtToEquity"] ?? 0) - 1.87) < 1e-10)
		#expect(provider.callCount == 1)
	}

	// MARK: - Protocol Composition Tests

	@Test("Full provider satisfies composed protocol constraint")
	func fullProviderComposition() async throws {
		let provider = MockFullProvider()

		// Use as a function that accepts any provider conforming to all three
		let metrics = try await fetchMetricsFromComposed(provider: provider)
		#expect(metrics.symbol == "AAPL")

		let prices = try await fetchPricesFromComposed(provider: provider)
		#expect(prices.periods.count == 1)
	}

	/// Helper: accepts the composed protocol constraint
	private func fetchMetricsFromComposed(
		provider: any StockPriceProvider & FinancialsProvider & MarketMetricsProvider
	) async throws -> MarketMetrics {
		try await provider.fetchMetrics(symbol: "AAPL")
	}

	/// Helper: accepts the composed protocol constraint
	private func fetchPricesFromComposed(
		provider: any StockPriceProvider & FinancialsProvider & MarketMetricsProvider
	) async throws -> TimeSeries<Double> {
		try await provider.fetchStockPrice(
			symbol: "AAPL",
			from: Date(timeIntervalSince1970: 0),
			to: Date(timeIntervalSince1970: 86400)
		)
	}

	@Test("StockPriceProvider used alone without financials")
	func selectiveConformance() async throws {
		let provider = MockStockPriceOnly()

		// This compiles — no need to implement fetchFinancials or fetchMetrics
		let result = try await provider.fetchStockPrice(
			symbol: "GOOG",
			from: Date(timeIntervalSince1970: 0),
			to: Date(timeIntervalSince1970: 86400)
		)
		#expect(result.periods.count == 1)
	}

	// MARK: - MarketMetrics Tests

	@Test("MarketMetrics Codable round-trip preserves all fields")
	func marketMetricsCodableRoundTrip() throws {
		let original = MarketMetrics(
			symbol: "AAPL",
			asOf: Date(timeIntervalSince1970: 1704067200),
			priceToEarnings: 28.5,
			priceToBook: 45.2,
			priceToSales: 7.8,
			marketCapitalization: 3_000_000_000_000,
			earningsPerShare: 6.42,
			dividendYield: 0.005,
			beta: 1.19,
			fiftyTwoWeekHigh: 199.62,
			fiftyTwoWeekLow: 124.17,
			additionalMetrics: ["debtToEquity": 1.87, "roe": 0.157]
		)

		let encoder = JSONEncoder()
		let data = try encoder.encode(original)

		let decoder = JSONDecoder()
		let decoded = try decoder.decode(MarketMetrics.self, from: data)

		#expect(decoded.symbol == original.symbol)
		#expect(abs((decoded.priceToEarnings ?? 0) - (original.priceToEarnings ?? 0)) < 1e-10)
		#expect(abs((decoded.priceToBook ?? 0) - (original.priceToBook ?? 0)) < 1e-10)
		#expect(abs((decoded.priceToSales ?? 0) - (original.priceToSales ?? 0)) < 1e-10)
		#expect(abs((decoded.marketCapitalization ?? 0) - (original.marketCapitalization ?? 0)) < 1e-10)
		#expect(abs((decoded.earningsPerShare ?? 0) - (original.earningsPerShare ?? 0)) < 1e-10)
		#expect(abs((decoded.dividendYield ?? 0) - (original.dividendYield ?? 0)) < 1e-10)
		#expect(abs((decoded.beta ?? 0) - (original.beta ?? 0)) < 1e-10)
		#expect(abs((decoded.fiftyTwoWeekHigh ?? 0) - (original.fiftyTwoWeekHigh ?? 0)) < 1e-10)
		#expect(abs((decoded.fiftyTwoWeekLow ?? 0) - (original.fiftyTwoWeekLow ?? 0)) < 1e-10)
		#expect(decoded.additionalMetrics.count == 2)
		#expect(abs((decoded.additionalMetrics["debtToEquity"] ?? 0) - 1.87) < 1e-10)
		#expect(abs((decoded.additionalMetrics["roe"] ?? 0) - 0.157) < 1e-10)
	}

	@Test("MarketMetrics with all optional fields nil")
	func marketMetricsAllNils() throws {
		let metrics = MarketMetrics(
			symbol: "UNKNOWN",
			asOf: Date(timeIntervalSince1970: 0),
			priceToEarnings: nil,
			priceToBook: nil,
			priceToSales: nil,
			marketCapitalization: nil,
			earningsPerShare: nil,
			dividendYield: nil,
			beta: nil,
			fiftyTwoWeekHigh: nil,
			fiftyTwoWeekLow: nil,
			additionalMetrics: [:]
		)

		#expect(metrics.symbol == "UNKNOWN")
		#expect(metrics.priceToEarnings == nil)
		#expect(metrics.beta == nil)
		#expect(metrics.additionalMetrics.isEmpty)

		// Codable round-trip with nils
		let encoder = JSONEncoder()
		let data = try encoder.encode(metrics)
		let decoder = JSONDecoder()
		let decoded = try decoder.decode(MarketMetrics.self, from: data)

		#expect(decoded.priceToEarnings == nil)
		#expect(decoded.beta == nil)
		#expect(decoded.additionalMetrics.isEmpty)
	}

	@Test("MarketMetrics with empty symbol")
	func marketMetricsEmptySymbol() {
		let metrics = MarketMetrics(
			symbol: "",
			asOf: Date(),
			priceToEarnings: nil,
			priceToBook: nil,
			priceToSales: nil,
			marketCapitalization: nil,
			earningsPerShare: nil,
			dividendYield: nil,
			beta: nil,
			fiftyTwoWeekHigh: nil,
			fiftyTwoWeekLow: nil,
			additionalMetrics: [:]
		)

		#expect(metrics.symbol == "")
	}

	@Test("MarketMetrics with large values")
	func marketMetricsLargeValues() throws {
		let metrics = MarketMetrics(
			symbol: "BRK.A",
			asOf: Date(),
			priceToEarnings: 8.5,
			priceToBook: 1.5,
			priceToSales: 2.3,
			marketCapitalization: 780_000_000_000,
			earningsPerShare: 73_298.0,
			dividendYield: 0.0,
			beta: 0.55,
			fiftyTwoWeekHigh: 641_435.0,
			fiftyTwoWeekLow: 491_971.0,
			additionalMetrics: [:]
		)

		// Codable round-trip preserves large values
		let encoder = JSONEncoder()
		let data = try encoder.encode(metrics)
		let decoder = JSONDecoder()
		let decoded = try decoder.decode(MarketMetrics.self, from: data)

		#expect(abs((decoded.earningsPerShare ?? 0) - 73_298.0) < 1e-6)
		#expect(abs((decoded.fiftyTwoWeekHigh ?? 0) - 641_435.0) < 1e-6)
	}
}

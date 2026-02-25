import Testing
import Foundation
import TestSupport  // Cross-platform URL types support
@testable import BusinessMath
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@Suite("Market Data Tests")
struct MarketDataTests {

	// MARK: - Mock Provider

	final class MockMarketDataProvider: MarketDataProvider {
		var fetchStockPriceCalled = false
		var fetchFinancialsCalled = false
		var fetchMetricsCalled = false

		func fetchStockPrice(
			symbol: String,
			from: Date,
			to: Date
		) async throws -> TimeSeries<Double> {
			fetchStockPriceCalled = true

			// Return mock data
			let calendar = Calendar.current
			var periods: [Period] = []
			var values: [Double] = []

			var current = from
			while current <= to {
				periods.append(Period.day(current))
				values.append(100.0 + Double.random(in: -10...10))
				current = calendar.date(byAdding: .day, value: 1, to: current)!
			}

			return TimeSeries(periods: periods, values: values)
		}

		func fetchFinancials(
			symbol: String,
			statement: FinancialStatementType,
			period: ReportingPeriod
		) async throws -> [String: Any] {
			fetchFinancialsCalled = true
			return [
				"revenue": 1_000_000,
				"netIncome": 100_000
			]
		}

		func fetchMetrics(symbol: String) async throws -> [String: Double] {
			fetchMetricsCalled = true
			return [
				"pe": 15.5,
				"marketCap": 10_000_000,
				"eps": 2.50
			]
		}
	}

	// MARK: - Provider Tests

	@Test("Fetch stock price returns time series")
	func fetchStockPrice() async throws {
		let provider = MockMarketDataProvider()

		let from = Date(timeIntervalSince1970: 0)
		let to = Date(timeIntervalSince1970: 86400 * 7)  // 7 days later

		let timeSeries = try await provider.fetchStockPrice(
			symbol: "AAPL",
			from: from,
			to: to
		)

		#expect(provider.fetchStockPriceCalled)
		#expect(timeSeries.periods.count > 0)
		#expect(timeSeries.valuesArray.count == timeSeries.periods.count)
	}

	@Test("Fetch financials returns data")
	func fetchFinancials() async throws {
		let provider = MockMarketDataProvider()

		let data = try await provider.fetchFinancials(
			symbol: "AAPL",
			statement: .income,
			period: .quarterly
		)

		#expect(provider.fetchFinancialsCalled)
		#expect(data["revenue"] as? Int == 1_000_000)
		#expect(data["netIncome"] as? Int == 100_000)
	}

	@Test("Fetch metrics returns dictionary")
	func fetchMetrics() async throws {
		let provider = MockMarketDataProvider()

		let metrics = try await provider.fetchMetrics(symbol: "AAPL")

		#expect(provider.fetchMetricsCalled)
		#expect(metrics["pe"] == 15.5)
		#expect(metrics["marketCap"] == 10_000_000)
		#expect(metrics["eps"] == 2.50)
	}

	// MARK: - Yahoo Finance Specific Tests

	@Test("Yahoo Finance URL construction")
	func yahooFinanceURL() async throws {
		let symbol = "AAPL"
		let from = Date(timeIntervalSince1970: 1609459200)  // 2021-01-01
		let to = Date(timeIntervalSince1970: 1640995200)    // 2022-01-01

		// Create mock session that validates the request
		let mockSession = MockNetworkSession { request in
			let url = request.url!

			// Verify the URL components
			#expect(url.scheme == "https")
			#expect(url.host == "query1.finance.yahoo.com")
			#expect(url.path == "/v7/finance/download/\(symbol)")

			// Verify query parameters
			let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
			let queryItems = components.queryItems ?? []

			let period1 = queryItems.first(where: { $0.name == "period1" })
			let period2 = queryItems.first(where: { $0.name == "period2" })
			let interval = queryItems.first(where: { $0.name == "interval" })
			let events = queryItems.first(where: { $0.name == "events" })

			#expect(period1?.value == "1609459200")
			#expect(period2?.value == "1640995200")
			#expect(interval?.value == "1d")
			#expect(events?.value == "history")

			// Return a minimal CSV response
			let csvData = """
			Date,Open,High,Low,Close,Adj Close,Volume
			2021-01-04,133.52,133.61,126.76,129.41,129.41,143301900
			""".data(using: .utf8)!

			let response = HTTPURLResponse(
				url: url,
				statusCode: 200,
				httpVersion: nil,
				headerFields: nil
			)!

			return (csvData, response)
		}

		// Test the provider
		let provider = YahooFinanceProvider(session: mockSession)
		_ = try await provider.fetchStockPrice(symbol: symbol, from: from, to: to)
	}

	@Test("Yahoo Finance CSV parsing")
	func yahooCSVParsing() async throws {
		let csv = """
		Date,Open,High,Low,Close,Adj Close,Volume
		2024-01-02,185.00,186.50,184.00,185.64,185.64,50000000
		2024-01-03,186.00,187.00,185.50,186.15,186.15,48000000
		2024-01-04,186.50,187.50,186.00,187.23,187.23,52000000
		"""

		// Set up mock session
		let mockSession = MockNetworkSession { request in
			let csvData = csv.data(using: .utf8)!
			let response = HTTPURLResponse(
				url: request.url!,
				statusCode: 200,
				httpVersion: nil,
				headerFields: nil
			)!
			return (csvData, response)
		}

		// Test the provider's CSV parsing through fetchStockPrice
		let provider = YahooFinanceProvider(session: mockSession)
		let timeSeries = try await provider.fetchStockPrice(
			symbol: "AAPL",
			from: Date(timeIntervalSince1970: 1704153600),  // 2024-01-02
			to: Date(timeIntervalSince1970: 1704326400)     // 2024-01-04
		)

		// Verify the parsed data
		#expect(timeSeries.valuesArray.count == 3)
		#expect(timeSeries.valuesArray[0] == 185.64)
		#expect(timeSeries.valuesArray[1] == 186.15)
		#expect(timeSeries.valuesArray[2] == 187.23)

		// Verify periods were parsed correctly
		#expect(timeSeries.periods.count == 3)
	}

			@Test("HTTP non-200 status yields error")
			func httpErrorStatus() async throws {
					let mockSession = MockNetworkSession { request in
							let data = Data()
							let resp = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
							return (data, resp)
					}

					let provider = YahooFinanceProvider(session: mockSession)
					do {
							_ = try await provider.fetchStockPrice(symbol: "AAPL", from: Date(), to: Date())
							Issue.record("Expected fetch to throw on 429")
					} catch {
							// Expected; if provider distinguishes rate-limited errors, assert that here.
							// e.g., #expect(error is MarketDataError)
					}
			}

	// MARK: - Error Handling

	@Test("Handle network error")
	func handleNetworkError() async throws {
		final class FailingProvider: MarketDataProvider {
			func fetchStockPrice(symbol: String, from: Date, to: Date) async throws -> TimeSeries<Double> {
				throw MarketDataError.invalidResponse
			}

			func fetchFinancials(symbol: String, statement: FinancialStatementType, period: ReportingPeriod) async throws -> [String: Any] {
				throw MarketDataError.invalidResponse
			}

			func fetchMetrics(symbol: String) async throws -> [String: Double] {
				throw MarketDataError.invalidResponse
			}
		}

		let provider = FailingProvider()

		do {
			_ = try await provider.fetchStockPrice(
				symbol: "INVALID",
				from: Date(),
				to: Date()
			)
			Issue.record("Should have thrown error")
		} catch {
			#expect(error is MarketDataError)
		}
	}

	@Test("Handle rate limiting")
	func handleRateLimiting() async throws {
		final class RateLimitedProvider: MarketDataProvider {
			var callCount = 0

			func fetchStockPrice(symbol: String, from: Date, to: Date) async throws -> TimeSeries<Double> {
				callCount += 1
				if callCount > 3 {
					throw MarketDataError.rateLimited
				}
				return TimeSeries(periods: [], values: [])
			}

			func fetchFinancials(symbol: String, statement: FinancialStatementType, period: ReportingPeriod) async throws -> [String: Any] {
				return [:]
			}

			func fetchMetrics(symbol: String) async throws -> [String: Double] {
				return [:]
			}
		}

		let provider = RateLimitedProvider()

		// Should succeed for first 3 calls
		for _ in 0..<3 {
			_ = try await provider.fetchStockPrice(symbol: "TEST", from: Date(), to: Date())
		}

		// 4th call should fail
		do {
			_ = try await provider.fetchStockPrice(symbol: "TEST", from: Date(), to: Date())
			Issue.record("Should have thrown rate limit error")
		} catch MarketDataError.rateLimited {
			// Expected
		}
	}
}

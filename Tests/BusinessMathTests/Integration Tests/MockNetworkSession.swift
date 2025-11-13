//
//  MockNetworkSession.swift
//  BusinessMathTests
//
//  Mock implementation of NetworkSession for testing.
//

import Foundation
@testable import BusinessMath

/// A mock network session for testing that doesn't make real HTTP requests.
///
/// `MockNetworkSession` allows tests to control exactly what data is returned
/// for network requests without requiring actual network connectivity or
/// external services.
///
/// ## Usage
///
/// ```swift
/// let mockSession = MockNetworkSession { request in
///     // Validate the request
///     XCTAssertEqual(request.url?.host, "api.example.com")
///
///     // Return mock data
///     let csvData = "Date,Close\n2024-01-01,100.0".data(using: .utf8)!
///     let response = HTTPURLResponse(
///         url: request.url!,
///         statusCode: 200,
///         httpVersion: nil,
///         headerFields: nil
///     )!
///     return (csvData, response)
/// }
///
/// let provider = YahooFinanceProvider(session: mockSession)
/// let data = try await provider.fetchStockPrice(...)
/// ```
final class MockNetworkSession: NetworkSession {
	/// The handler that processes requests and returns mock data.
	private let handler: @Sendable (URLRequest) async throws -> (Data, URLResponse)

	/// Creates a new mock network session with a request handler.
	///
	/// - Parameter handler: A closure that receives a URL request and returns
	///   mock data and a response, or throws an error.
	init(handler: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)) {
		self.handler = handler
	}

	func data(for request: URLRequest) async throws -> (Data, URLResponse) {
		return try await handler(request)
	}
}

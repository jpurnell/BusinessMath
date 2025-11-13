//
//  NetworkSession.swift
//  BusinessMath
//
//  Network abstraction layer for market data providers.
//

import Foundation

// MARK: - NetworkSession Protocol

/// Protocol for performing HTTP network requests.
///
/// `NetworkSession` provides an abstraction over network operations,
/// enabling dependency injection and making code testable without
/// requiring actual network calls.
///
/// ## Usage with Real Networking
///
/// ```swift
/// let session = URLSessionNetworkSession()
/// let provider = YahooFinanceProvider(session: session)
/// ```
///
/// ## Usage in Tests
///
/// ```swift
/// let mockSession = MockNetworkSession()
/// mockSession.handler = { request in
///     // Return test data
///     let data = "test,data".data(using: .utf8)!
///     let response = HTTPURLResponse(url: request.url!, statusCode: 200, ...)
///     return (data, response)
/// }
/// let provider = YahooFinanceProvider(session: mockSession)
/// ```
public protocol NetworkSession: Sendable {
	/// Performs a network request and returns the data and response.
	///
	/// - Parameter request: The URL request to perform.
	///
	/// - Returns: A tuple containing the response data and URL response.
	///
	/// - Throws: An error if the request fails.
	func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

// MARK: - URLSessionNetworkSession

/// A `NetworkSession` implementation that uses `URLSession`.
///
/// This is the production implementation that performs real HTTP requests.
///
/// ## Example
///
/// ```swift
/// let session = URLSessionNetworkSession()
/// let (data, response) = try await session.data(for: request)
/// ```
public struct URLSessionNetworkSession: NetworkSession {
	/// The underlying URL session.
	private let urlSession: URLSession

	/// Creates a network session backed by a URL session.
	///
	/// - Parameter urlSession: The URL session to use. Defaults to `.shared`.
	public init(urlSession: URLSession = .shared) {
		self.urlSession = urlSession
	}

	public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
		return try await urlSession.data(for: request)
	}
}

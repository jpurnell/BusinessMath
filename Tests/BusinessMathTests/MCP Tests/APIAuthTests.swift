import Testing
import Foundation
@testable import BusinessMathMCP

/// Tests for API key authentication
///
/// Following TDD:
/// - RED: Write failing tests first
/// - GREEN: Implement to make tests pass
/// - REFACTOR: Clean up implementation
@Suite("API Key Authentication Tests")
struct APIAuthTests {

    // MARK: - APIKeyAuthenticator Tests

    @Test("Valid API key is accepted")
    func testValidAPIKey() async throws {
        let authenticator = APIKeyAuthenticator(apiKeys: ["test-key-123"])

        let isValid = await authenticator.validate(authHeader: "Bearer test-key-123")
        #expect(isValid, "Valid API key should be accepted")
    }

    @Test("Invalid API key is rejected")
    func testInvalidAPIKey() async throws {
        let authenticator = APIKeyAuthenticator(apiKeys: ["test-key-123"])

        let isValid = await authenticator.validate(authHeader: "Bearer wrong-key")
        #expect(!isValid, "Invalid API key should be rejected")
    }

    @Test("Missing Authorization header is rejected")
    func testMissingAuthHeader() async throws {
        let authenticator = APIKeyAuthenticator(apiKeys: ["test-key-123"])

        let isValid = await authenticator.validate(authHeader: nil)
        #expect(!isValid, "Missing auth header should be rejected")
    }

    @Test("Multiple API keys are supported")
    func testMultipleAPIKeys() async throws {
        let authenticator = APIKeyAuthenticator(apiKeys: ["key1", "key2", "key3"])

        #expect(await authenticator.validate(authHeader: "Bearer key1"))
        #expect(await authenticator.validate(authHeader: "Bearer key2"))
        #expect(await authenticator.validate(authHeader: "Bearer key3"))
        #expect(!(await authenticator.validate(authHeader: "Bearer key4")))
    }

    @Test("Bearer token format is supported")
    func testBearerTokenFormat() async throws {
        let authenticator = APIKeyAuthenticator(apiKeys: ["my-secret-key"])

        #expect(await authenticator.validate(authHeader: "Bearer my-secret-key"))
        #expect(await authenticator.validate(authHeader: "bearer my-secret-key"))  // Case insensitive
    }

    @Test("ApiKey format is supported")
    func testApiKeyFormat() async throws {
        let authenticator = APIKeyAuthenticator(apiKeys: ["my-secret-key"])

        #expect(await authenticator.validate(authHeader: "ApiKey my-secret-key"))
        #expect(await authenticator.validate(authHeader: "apikey my-secret-key"))  // Case insensitive
    }

    @Test("Bare API key format is supported")
    func testBareKeyFormat() async throws {
        let authenticator = APIKeyAuthenticator(apiKeys: ["my-secret-key"])

        #expect(await authenticator.validate(authHeader: "my-secret-key"))
    }

    @Test("Auth can be disabled for development")
    func testAuthDisabled() async throws {
        let authenticator = APIKeyAuthenticator(apiKeys: [], authRequired: false)

        // All requests should be allowed when auth is disabled
        #expect(await authenticator.validate(authHeader: nil))
        #expect(await authenticator.validate(authHeader: "invalid-key"))
        #expect(await authenticator.validate(authHeader: ""))
    }

    @Test("API keys can be added dynamically")
    func testAddAPIKey() async throws {
        let authenticator = APIKeyAuthenticator(apiKeys: ["initial-key"])

        #expect(await authenticator.validate(authHeader: "Bearer initial-key"))
        #expect(!(await authenticator.validate(authHeader: "Bearer new-key")))

        await authenticator.addKey("new-key")

        #expect(await authenticator.validate(authHeader: "Bearer new-key"))
    }

    @Test("API keys can be removed dynamically")
    func testRemoveAPIKey() async throws {
        let authenticator = APIKeyAuthenticator(apiKeys: ["key1", "key2"])

        #expect(await authenticator.validate(authHeader: "Bearer key1"))

        await authenticator.removeKey("key1")

        #expect(!(await authenticator.validate(authHeader: "Bearer key1")))
        #expect(await authenticator.validate(authHeader: "Bearer key2"))  // key2 still works
    }

    @Test("Key count is tracked correctly")
    func testKeyCount() async throws {
        let authenticator = APIKeyAuthenticator(apiKeys: ["key1", "key2", "key3"])

        let count = await authenticator.keyCount()
        #expect(count == 3)

        await authenticator.addKey("key4")
        #expect(await authenticator.keyCount() == 4)

        await authenticator.removeKey("key1")
        #expect(await authenticator.keyCount() == 3)
    }

    // MARK: - HTTP Integration Tests

    @Test("Protected endpoint rejects request without auth")
    func testProtectedEndpointWithoutAuth() async throws {
        let authenticator = APIKeyAuthenticator(apiKeys: ["test-key"])
        let transport = HTTPServerTransport(port: 9300, authenticator: authenticator)

        try await transport.connect()
        defer { Task { await transport.disconnect() } }

        try await Task.sleep(nanoseconds: 200_000_000)

        // Send JSON-RPC request without Authorization header
        let url = URL(string: "http://localhost:9300/mcp")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = #"{"jsonrpc":"2.0","id":1,"method":"test"}"#.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        let httpResponse = response as? HTTPURLResponse
        #expect(httpResponse?.statusCode == 401, "Should return 401 Unauthorized")

        let body = String(data: data, encoding: .utf8) ?? ""
        #expect(body.contains("Unauthorized"), "Error message should mention unauthorized")
    }

    @Test("Protected endpoint accepts request with valid auth")
    func testProtectedEndpointWithValidAuth() async throws {
        let authenticator = APIKeyAuthenticator(apiKeys: ["test-key-456"])
        let transport = HTTPServerTransport(port: 9301, authenticator: authenticator)

        try await transport.connect()
        defer { Task { await transport.disconnect() } }

        try await Task.sleep(nanoseconds: 200_000_000)

        // Send JSON-RPC request with valid Authorization header
        let url = URL(string: "http://localhost:9301/mcp")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer test-key-456", forHTTPHeaderField: "Authorization")
        request.httpBody = #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}"#.data(using: .utf8)

        let (_, response) = try await URLSession.shared.data(for: request)

        let httpResponse = response as? HTTPURLResponse
        #expect(httpResponse?.statusCode != 401, "Valid auth should not return 401")
    }

    @Test("Public endpoints work without auth")
    func testPublicEndpointWithoutAuth() async throws {
        let authenticator = APIKeyAuthenticator(apiKeys: ["test-key"])
        let transport = HTTPServerTransport(port: 9302, authenticator: authenticator)

        try await transport.connect()
        defer { Task { await transport.disconnect() } }

        try await Task.sleep(nanoseconds: 200_000_000)

        // Health endpoint should work without auth
        let url = URL(string: "http://localhost:9302/health")!
        let (data, response) = try await URLSession.shared.data(from: url)

        let httpResponse = response as? HTTPURLResponse
        #expect(httpResponse?.statusCode == 200, "Health endpoint should work without auth")

        let body = String(data: data, encoding: .utf8)
        #expect(body == "OK")
    }

    @Test("Server info shows auth status")
    func testServerInfoShowsAuthStatus() async throws {
        let authenticator = APIKeyAuthenticator(apiKeys: ["test-key"])
        let transport = HTTPServerTransport(port: 9303, authenticator: authenticator)

        try await transport.connect()
        defer { Task { await transport.disconnect() } }

        try await Task.sleep(nanoseconds: 200_000_000)

        // Server info endpoint should work without auth
        let url = URL(string: "http://localhost:9303/mcp")!
        let (data, response) = try await URLSession.shared.data(from: url)

        let httpResponse = response as? HTTPURLResponse
        #expect(httpResponse?.statusCode == 200)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let authStatus = json?["authentication"] as? String
        #expect(authStatus == "required", "Server info should show auth is required")
    }

    @Test("No authenticator means no auth required")
    func testNoAuthenticator() async throws {
        let transport = HTTPServerTransport(port: 9304, authenticator: nil)

        try await transport.connect()
        defer { Task { await transport.disconnect() } }

        try await Task.sleep(nanoseconds: 200_000_000)

        // POST should work without auth when authenticator is nil
        let url = URL(string: "http://localhost:9304/mcp")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = #"{"jsonrpc":"2.0","id":1,"method":"test"}"#.data(using: .utf8)

        let (_, response) = try await URLSession.shared.data(for: request)

        let httpResponse = response as? HTTPURLResponse
        #expect(httpResponse?.statusCode != 401, "No authenticator should allow all requests")
    }

    // Temporarily disabled - needs withTimeout helper from SSEIntegrationTests
    // @Test("SSE endpoint requires auth")
    // func testSSEEndpointRequiresAuth_DISABLED() async throws {
    //     let authenticator = APIKeyAuthenticator(apiKeys: ["sse-test-key"])
    //     let transport = HTTPServerTransport(port: 9305, authenticator: authenticator)
    //
    //     try await transport.connect()
    //     defer { Task { await transport.disconnect() } }
    //
    //     try await Task.sleep(nanoseconds: 200_000_000)
    //
    //     // Try to open SSE without auth
    //     let url = URL(string: "http://localhost:9305/mcp/sse")!
    //     var request = URLRequest(url: url)
    //     request.httpMethod = "GET"
    //     request.timeoutInterval = 2.0
    //
    //     let (statusCode, _) = try await withTimeout(seconds: 3) {
    //         try await getSSEStatusCode(request: request)
    //     }
    //
    //     #expect(statusCode == 401, "SSE endpoint should require auth")
    // }
}

// MARK: - Helper Functions

/// Get HTTP status code from request
func getSSEStatusCode(request: URLRequest) async throws -> (Int, String?) {
    try await withCheckedThrowingContinuation { continuation in
        let delegate = SSEStatusDelegate(continuation: continuation)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
    }
}

/// Simple delegate to capture status code
class SSEStatusDelegate: NSObject, URLSessionDataDelegate {
    private let continuation: CheckedContinuation<(Int, String?), Error>
    private var didResume = false

    init(continuation: CheckedContinuation<(Int, String?), Error>) {
        self.continuation = continuation
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard !didResume, let httpResponse = response as? HTTPURLResponse else {
            completionHandler(.allow)
            return
        }

        didResume = true
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")
        continuation.resume(returning: (httpResponse.statusCode, contentType))

        dataTask.cancel()
        completionHandler(.cancel)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if !didResume, let error = error, (error as? URLError)?.code != .cancelled {
            didResume = true
            continuation.resume(throwing: error)
        }
    }
}

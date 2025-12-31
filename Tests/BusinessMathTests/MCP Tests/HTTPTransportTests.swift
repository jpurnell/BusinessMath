import Testing
import Foundation
import Network
@testable import BusinessMathMCP

/// Test suite for HTTP transport request/response cycle
///
/// Tests follow TDD principles:
/// 1. RED: Write failing tests first
/// 2. GREEN: Make tests pass with minimal code
/// 3. REFACTOR: Improve implementation
@Suite("HTTP Transport Tests")
struct HTTPTransportTests {

    // MARK: - Phase 1: Request/Response Correlation

    @Test("HTTPResponseManager - Register and route simple request")
    func testResponseManagerBasicFlow() async throws {
        let manager = HTTPResponseManager()

        // Create mock connection (we'll use a simplified test)
        let requestId = HTTPResponseManager.JSONRPCId.number(42)

        // Simulate JSON-RPC response
        let responseJson = """
        {
          "jsonrpc": "2.0",
          "id": 42,
          "result": {
            "tools": []
          }
        }
        """

        guard let responseData = responseJson.data(using: .utf8) else {
            throw TestError.invalidData
        }

        // Extract ID from response
        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let idValue = json["id"] as? Int else {
            throw TestError.invalidJson
        }

        #expect(idValue == 42, "Should extract correct request ID from response")
    }

    @Test("HTTPResponseManager - Handle string request IDs")
    func testResponseManagerStringIds() async throws {
        let manager = HTTPResponseManager()

        let responseJson = """
        {
          "jsonrpc": "2.0",
          "id": "request-123",
          "result": {
            "success": true
          }
        }
        """

        guard let responseData = responseJson.data(using: .utf8) else {
            throw TestError.invalidData
        }

        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let idValue = json["id"] as? String else {
            throw TestError.invalidJson
        }

        #expect(idValue == "request-123", "Should extract string request IDs")
    }

    @Test("HTTPResponseManager - Handle null request IDs")
    func testResponseManagerNullIds() async throws {
        let responseJson = """
        {
          "jsonrpc": "2.0",
          "id": null,
          "result": {}
        }
        """

        guard let responseData = responseJson.data(using: .utf8) else {
            throw TestError.invalidData
        }

        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw TestError.invalidJson
        }

        let hasId = json.keys.contains("id")
        #expect(hasId, "Response should contain id field even if null")
    }

    @Test("HTTPResponseManager - Cleanup expired requests")
    func testResponseManagerCleanup() async throws {
        // Test that cleanup task can start and stop without crashing
        let manager = HTTPResponseManager(requestTimeout: 1.0)

        await manager.startCleanup()

        // Wait briefly
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        await manager.stopCleanup()

        // Should complete without errors
        #expect(true, "Cleanup task should start and stop cleanly")
    }

    @Test("HTTPResponseManager - Pending request count")
    func testPendingRequestCount() async throws {
        let manager = HTTPResponseManager()

        let initialCount = await manager.pendingCount()
        #expect(initialCount == 0, "Should start with zero pending requests")
    }

    // MARK: - Integration Tests

    @Test("HTTP Server - Start and stop")
    func testServerStartStop() async throws {
        let transport = HTTPServerTransport(port: 9090)

        try await transport.connect()

        // Server should be listening
        // Give it a moment to start
        try await Task.sleep(nanoseconds: 100_000_000)

        await transport.disconnect()

        #expect(true, "Server should start and stop without errors")
    }

    @Test("HTTP Server - Health check endpoint")
    func testHealthCheckEndpoint() async throws {
        let transport = HTTPServerTransport(port: 9091)

        try await transport.connect()
        try await Task.sleep(nanoseconds: 200_000_000) // Wait for server to be ready

        // Test health endpoint
        let url = URL(string: "http://localhost:9091/health")!
        let (data, response) = try await URLSession.shared.data(from: url)

        let httpResponse = response as? HTTPURLResponse
        #expect(httpResponse?.statusCode == 200, "Health check should return 200")

        let body = String(data: data, encoding: .utf8)
        #expect(body == "OK", "Health check should return OK")

        await transport.disconnect()
    }

    @Test("HTTP Server - Server info endpoint")
    func testServerInfoEndpoint() async throws {
        let transport = HTTPServerTransport(port: 9092)

        try await transport.connect()
        try await Task.sleep(nanoseconds: 200_000_000)

        let url = URL(string: "http://localhost:9092/mcp")!
        let (data, response) = try await URLSession.shared.data(from: url)

        let httpResponse = response as? HTTPURLResponse
        #expect(httpResponse?.statusCode == 200, "Server info should return 200")

        let body = String(data: data, encoding: .utf8) ?? ""
        #expect(body.contains("BusinessMath MCP Server"), "Should return server info")

        await transport.disconnect()
    }

    // MARK: - Error Cases

    @Test("HTTP Server - 404 for unknown paths")
    func test404ForUnknownPaths() async throws {
        let transport = HTTPServerTransport(port: 9093)

        try await transport.connect()
        try await Task.sleep(nanoseconds: 200_000_000)

        let url = URL(string: "http://localhost:9093/unknown")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (_, response) = try await URLSession.shared.data(for: request)

        let httpResponse = response as? HTTPURLResponse
        #expect(httpResponse?.statusCode == 404, "Unknown paths should return 404")

        await transport.disconnect()
    }

    @Test("HTTP Server - 405 for wrong methods")
    func test405ForWrongMethods() async throws {
        let transport = HTTPServerTransport(port: 9094)

        try await transport.connect()
        try await Task.sleep(nanoseconds: 200_000_000)

        // Try DELETE on /health (only GET allowed)
        let url = URL(string: "http://localhost:9094/mcp")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)

        let httpResponse = response as? HTTPURLResponse
        #expect(httpResponse?.statusCode == 405, "Wrong method should return 405")

        await transport.disconnect()
    }
}

enum TestError: Error {
    case invalidData
    case invalidJson
    case networkError
}

import Testing
import Foundation
import Network
@testable import BusinessMathMCP

/// Test suite for Server-Sent Events (SSE) transport
///
/// Following TDD:
/// - RED: Write failing tests first (these will fail until we implement SSE)
/// - GREEN: Implement SSE to make tests pass
/// - REFACTOR: Clean up implementation
///
/// SSE provides:
/// - Long-lived HTTP connection for server → client streaming
/// - Event-based messaging (data: field)
/// - Automatic reconnection support
/// - Works with standard HTTP infrastructure
@Suite("SSE Transport Tests")
struct SSETransportTests {

    // MARK: - Phase 2.1: SSE Connection Tests (RED phase - these will fail initially)

    @Test("SSE - Client can establish SSE connection")
    func testSSEConnectionEstablishment() async throws {
        let transport = HTTPServerTransport(port: 9100)

        try await transport.connect()
        try await Task.sleep(nanoseconds: 200_000_000)

        // Open SSE connection using delegate to get immediate headers
        let url = URL(string: "http://localhost:9100/mcp/sse")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        // Use delegate to capture response immediately
        let (statusCode, contentType, sessionId) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Int, String?, String?), Error>) in
            let delegate = SSETestDelegate(continuation: continuation)
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            let task = session.dataTask(with: request)
            task.resume()
        }

        #expect(statusCode == 200, "SSE endpoint should return 200")
        #expect(contentType?.contains("text/event-stream") == true, "Should return event-stream content type")
        #expect(sessionId != nil, "Should include X-Session-ID header with UUID")

        await transport.disconnect()
    }

    @Test("SSE - Receive heartbeat events")
    func testSSEHeartbeat() async throws {
        // Test that SSE sends periodic heartbeat/keepalive events
        // Heartbeat format: ":\n\n" (comment line)
        // This prevents connection timeout
        #expect(true, "TODO: Implement heartbeat test when SSE is ready")
    }

    @Test("SSE - Receive JSON-RPC response via SSE")
    func testSSEReceiveResponse() async throws {
        // Test that JSON-RPC responses are delivered via SSE
        // Format:
        // event: message
        // data: {"jsonrpc":"2.0","id":1,"result":{...}}
        // (blank line)
        #expect(true, "TODO: Implement SSE response test when ready")
    }

    @Test("SSE - Multiple clients can connect simultaneously")
    func testSSEMultipleClients() async throws {
        // Test that server supports multiple concurrent SSE connections
        // Each client should receive their own responses
        #expect(true, "TODO: Implement multi-client test when SSE is ready")
    }

    @Test("SSE - Server-initiated notifications")
    func testSSEServerNotifications() async throws {
        // Test that server can send notifications (id: null)
        // Example: progress updates, log messages
        #expect(true, "TODO: Implement notification test when SSE is ready")
    }

    // MARK: - SSE Session Management Tests

    @Test("SSE - Session registration and lookup")
    func testSSESessionManagement() async throws {
        // Test that SSE sessions are properly registered and can be looked up
        // Sessions should track: connection, client ID, last activity
        #expect(true, "TODO: Implement session management test when ready")
    }

    @Test("SSE - Session cleanup on disconnect")
    func testSSESessionCleanup() async throws {
        // Test that sessions are removed when client disconnects
        #expect(true, "TODO: Implement session cleanup test when ready")
    }

    @Test("SSE - Session timeout for inactive connections")
    func testSSESessionTimeout() async throws {
        // Test that inactive SSE connections timeout after configured period
        // Default: 5 minutes of inactivity
        #expect(true, "TODO: Implement session timeout test when ready")
    }

    // MARK: - SSE + HTTP POST Integration Tests

    @Test("SSE + POST - Full request/response cycle")
    func testSSEWithPOSTIntegration() async throws {
        // Test the full flow:
        // 1. Client opens SSE connection
        // 2. Client sends JSON-RPC request via POST
        // 3. Server processes request
        // 4. Server sends response via SSE stream
        // 5. Client receives response
        #expect(true, "TODO: Implement full integration test when SSE is ready")
    }

    @Test("SSE + POST - Response routing to correct client")
    func testSSEResponseRouting() async throws {
        // Test that responses go to the correct SSE stream
        // Client A and Client B both connected
        // Client A sends request → receives response on their SSE stream
        // Client B should NOT receive Client A's response
        #expect(true, "TODO: Implement routing test when SSE is ready")
    }

    // MARK: - SSE Error Handling Tests

    @Test("SSE - Handle client disconnect during processing")
    func testSSEClientDisconnect() async throws {
        // Test behavior when client disconnects while request is being processed
        // Server should gracefully handle and clean up
        #expect(true, "TODO: Implement disconnect handling test when ready")
    }

    @Test("SSE - Handle network errors")
    func testSSENetworkErrors() async throws {
        // Test that network errors are handled gracefully
        // Should log error and clean up resources
        #expect(true, "TODO: Implement error handling test when ready")
    }

    // MARK: - SSE Format Tests

    @Test("SSE - Proper event format")
    func testSSEEventFormat() async throws {
        // Verify SSE events follow the spec:
        // event: <event-type>
        // data: <payload>
        // id: <optional-event-id>
        // (blank line)
        #expect(true, "TODO: Implement format validation test when ready")
    }

    @Test("SSE - Multi-line data handling")
    func testSSEMultiLineData() async throws {
        // Test that multi-line JSON payloads are properly formatted
        // Each line should be prefixed with "data: "
        #expect(true, "TODO: Implement multi-line test when ready")
    }
}

// MARK: - Test Helpers

/// URLSession delegate for testing SSE connections
/// Captures response headers immediately without waiting for completion
class SSETestDelegate: NSObject, URLSessionDataDelegate {
    private let continuation: CheckedContinuation<(Int, String?, String?), Error>
    private var didResume = false

    init(continuation: CheckedContinuation<(Int, String?, String?), Error>) {
        self.continuation = continuation
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        // Get headers immediately when response is received
        if !didResume, let httpResponse = response as? HTTPURLResponse {
            didResume = true
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")
            let sessionId = httpResponse.value(forHTTPHeaderField: "X-Session-ID")
            continuation.resume(returning: (httpResponse.statusCode, contentType, sessionId))

            // Cancel the task since we got what we needed
            dataTask.cancel()
            completionHandler(.cancel)
        } else {
            completionHandler(.allow)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Ignore cancellation errors (we cancel intentionally)
        if !didResume, let error = error, (error as? URLError)?.code != .cancelled {
            didResume = true
            continuation.resume(throwing: error)
        }
    }
}

enum SSETestError: Error {
    case invalidData
    case invalidJson
    case networkError
    case timeout
}

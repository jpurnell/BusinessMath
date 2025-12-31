import Foundation
import Network
import Logging

/// Represents a single Server-Sent Events (SSE) client connection
///
/// SSE provides a one-way channel from server to client for:
/// - JSON-RPC responses
/// - Server-initiated notifications
/// - Progress updates
/// - Log messages
///
/// ## SSE Event Format
///
/// ```
/// event: message
/// data: {"jsonrpc":"2.0","id":1,"result":{...}}
///
/// ```
///
/// Multiple `data:` lines are supported for multi-line payloads.
public actor SSESession {
    /// Unique identifier for this session
    public let sessionId: String

    /// The network connection for this SSE stream
    private let connection: NWConnection

    /// When this session was created
    public let createdAt: Date

    /// Last time any activity occurred
    private(set) var lastActivityAt: Date

    /// Whether this session is active
    private(set) var isActive: Bool = true

    /// Logger for this session
    private let logger: Logger

    /// Initialize a new SSE session
    /// - Parameters:
    ///   - sessionId: Unique identifier (default: UUID)
    ///   - connection: Network connection to send events to
    ///   - logger: Logger instance
    public init(
        sessionId: String = UUID().uuidString,
        connection: NWConnection,
        logger: Logger = Logger(label: "sse-session")
    ) {
        self.sessionId = sessionId
        self.connection = connection
        self.createdAt = Date()
        self.lastActivityAt = Date()
        self.logger = logger
    }

    /// Send an SSE event to the client
    /// - Parameters:
    ///   - event: Event type (e.g., "message", "error")
    ///   - data: Event payload (will be JSON-encoded if needed)
    ///   - id: Optional event ID for client-side deduplication
    public func sendEvent(event: String = "message", data: String, id: String? = nil) {
        guard isActive else {
            logger.warning("Attempted to send event to inactive session \(sessionId)")
            return
        }

        // Build SSE event format
        var sseEvent = ""

        if let eventId = id {
            sseEvent += "id: \(eventId)\n"
        }

        sseEvent += "event: \(event)\n"

        // Handle multi-line data (each line must be prefixed with "data: ")
        let dataLines = data.split(separator: "\n", omittingEmptySubsequences: false)
        for line in dataLines {
            sseEvent += "data: \(line)\n"
        }

        // SSE events end with blank line
        sseEvent += "\n"

        // Send to client
        guard let eventData = sseEvent.data(using: .utf8) else {
            logger.error("Failed to encode SSE event for session \(sessionId)")
            return
        }

        connection.send(content: eventData, completion: .contentProcessed { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to send SSE event: \(error.localizedDescription)")
                Task {
                    await self?.close()
                }
            }
        })

        lastActivityAt = Date()
    }

    /// Send a heartbeat/keepalive event
    ///
    /// SSE comment format: `: comment\n\n`
    /// This prevents connection timeout without sending data
    public func sendHeartbeat() {
        guard isActive else { return }

        let heartbeat = ":\n\n"
        guard let heartbeatData = heartbeat.data(using: .utf8) else { return }

        connection.send(content: heartbeatData, completion: .contentProcessed { [weak self] error in
            if let error = error {
                self?.logger.debug("Heartbeat failed: \(error.localizedDescription)")
                Task {
                    await self?.close()
                }
            }
        })

        lastActivityAt = Date()
    }

    /// Send a JSON-RPC response via SSE
    /// - Parameter jsonRpcResponse: The JSON-RPC response data
    public func sendJSONRPCResponse(_ jsonRpcResponse: Data) {
        guard let jsonString = String(data: jsonRpcResponse, encoding: .utf8) else {
            logger.error("Failed to convert JSON-RPC response to string")
            return
        }

        sendEvent(event: "message", data: jsonString)
    }

    /// Close this SSE session
    public func close() {
        guard isActive else { return }

        isActive = false
        connection.cancel()
        logger.debug("Closed SSE session \(sessionId)")
    }

    /// Check if session has timed out
    /// - Parameter timeout: Maximum idle time before timeout
    /// - Returns: Whether session should be considered timed out
    public func isTimedOut(timeout: TimeInterval) -> Bool {
        return Date().timeIntervalSince(lastActivityAt) > timeout
    }
}

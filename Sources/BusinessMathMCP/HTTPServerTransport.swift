import Foundation
import MCP
import Network
import Logging

/// HTTP server transport for MCP using Apple's Network framework
///
/// This transport implements a simple HTTP server that:
/// - Listens on a specified port
/// - Accepts POST requests with JSON-RPC messages
/// - Returns JSON-RPC responses
///
/// Note: This is a simplified implementation. Full MCP HTTP transport
/// with Server-Sent Events (SSE) for bidirectional communication is
/// a future enhancement.
public actor HTTPServerTransport: Transport {
    public let logger: Logger
    private let port: UInt16
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let receiveStream: AsyncThrowingStream<Data, Error>
    private let receiveContinuation: AsyncThrowingStream<Data, Error>.Continuation

    /// Initialize HTTP server transport
    /// - Parameters:
    ///   - port: Port number to listen on (default: 8080)
    ///   - logger: Logger instance
    public init(port: UInt16 = 8080, logger: Logger = Logger(label: "http-server-transport")) {
        self.port = port
        self.logger = logger

        // Create receive stream
        var continuation: AsyncThrowingStream<Data, Error>.Continuation!
        self.receiveStream = AsyncThrowingStream { cont in
            continuation = cont
        }
        self.receiveContinuation = continuation
    }

    public func connect() async throws {
//        logger.info("Starting HTTP server on port \(self.port)")

        // Create listener parameters
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        // Create and start listener
        guard let listener = try? NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port)) else {
            throw HTTPServerError.failedToCreateListener
        }

        self.listener = listener

        // Set up new connection handler
        listener.newConnectionHandler = { [weak self] connection in
            Task {
                await self?.handleNewConnection(connection)
            }
        }

        // Set up state update handler
        listener.stateUpdateHandler = { [weak self] state in
            Task {
                await self?.handleListenerStateUpdate(state)
            }
        }

        // Start listening
        listener.start(queue: .main)

//        logger.info("HTTP server started successfully on port \(self.port)")
//        logger.info("Server available at http://localhost:\(self.port)")
//        logger.info("Send JSON-RPC requests via POST to http://localhost:\(self.port)/mcp")
    }

    public func disconnect() async {
//        logger.info("Stopping HTTP server...")

        // Cancel all connections
        for connection in connections {
            connection.cancel()
        }
        connections.removeAll()

        // Cancel listener
        listener?.cancel()
        listener = nil

        // Finish receive stream
        receiveContinuation.finish()

//        logger.info("HTTP server stopped")
    }

    public func send(_ data: Data) async throws {
        // For HTTP server, send() is used to send responses back to clients
        // This is handled in the request processing pipeline
        // For now, this is a no-op as responses are sent inline
//        logger.debug("Send called with \(data.count) bytes (handled inline)")
    }

    public func receive() -> AsyncThrowingStream<Data, Error> {
        return receiveStream
    }

    // MARK: - Private Methods

    private func handleListenerStateUpdate(_ state: NWListener.State) {
        switch state {
        case .ready:
//            logger.info("Listener ready on port \(self.port)")
            break
        case .failed(let error):
//            logger.error("Listener failed: \(error.localizedDescription)")
            receiveContinuation.finish(throwing: error)
        case .cancelled:
//            logger.info("Listener cancelled")
            break
        default:
            break
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
//        logger.debug("New connection from \(connection.endpoint)")

        connections.append(connection)

        // Start the connection
        connection.start(queue: .main)

        // Set up state handler
        connection.stateUpdateHandler = { [weak self] state in
            Task {
                await self?.handleConnectionState(connection, state: state)
            }
        }

        // Start receiving data
        receiveData(from: connection)
    }

    private func handleConnectionState(_ connection: NWConnection, state: NWConnection.State) {
        switch state {
        case .ready:
//            logger.debug("Connection ready: \(connection.endpoint)")
            break
        case .failed(_):
//            logger.error("Connection failed: \(error.localizedDescription)")
            removeConnection(connection)
        case .cancelled:
//            logger.debug("Connection cancelled: \(connection.endpoint)")
            removeConnection(connection)
        default:
            break
        }
    }

    private func removeConnection(_ connection: NWConnection) {
        connections.removeAll { $0 === connection }
    }

    private func receiveData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, context, isComplete, error in
            Task {
                await self?.processReceivedData(connection: connection, data: data, context: context, isComplete: isComplete, error: error)
            }
        }
    }

    private func processReceivedData(
        connection: NWConnection,
        data: Data?,
        context: NWConnection.ContentContext?,
        isComplete: Bool,
        error: NWError?
    ) {
        if let error = error {
            logger.error("Receive error: \(error.localizedDescription)")
            connection.cancel()
            return
        }

        if let data = data, !data.isEmpty {
            // Parse HTTP request
            if let httpRequest = parseHTTPRequest(data) {
//                logger.debug("Received HTTP \(httpRequest.method) \(httpRequest.path)")

                // Handle the request
                handleHTTPRequest(httpRequest, connection: connection)
            } else {
                // Send 400 Bad Request
                sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            }
        }

        // Continue receiving if not complete
        if !isComplete {
            receiveData(from: connection)
        }
    }

    private func handleHTTPRequest(_ request: HTTPRequest, connection: NWConnection) {
        // Handle different paths
        switch request.path {
        case "/mcp", "/":
            if request.method == "POST" {
                // Handle JSON-RPC request
                handleJSONRPCRequest(request, connection: connection)
            } else if request.method == "GET" {
                // Return server info
                let info = """
                {
                  "name": "BusinessMath MCP Server",
                  "version": "1.13.0",
                  "protocol": "MCP over HTTP",
                  "endpoint": "POST /mcp with JSON-RPC payload"
                }
                """
                sendHTTPResponse(connection: connection, statusCode: 200, body: info, contentType: "application/json")
            } else {
                sendHTTPResponse(connection: connection, statusCode: 405, body: "Method Not Allowed")
            }

        case "/health":
            sendHTTPResponse(connection: connection, statusCode: 200, body: "OK")

        default:
            sendHTTPResponse(connection: connection, statusCode: 404, body: "Not Found")
        }
    }

    private func handleJSONRPCRequest(_ request: HTTPRequest, connection: NWConnection) {
        guard let body = request.body else {
            sendHTTPResponse(connection: connection, statusCode: 400, body: "Missing request body")
            return
        }

        // Forward to MCP server via receive stream
        receiveContinuation.yield(body)

        // Note: Response handling would need to be improved for production
        // This is a simplified implementation
        let response = """
        {
          "jsonrpc": "2.0",
          "id": 1,
          "result": {
            "note": "HTTP transport is experimental. Responses are not yet fully implemented."
          }
        }
        """

        sendHTTPResponse(connection: connection, statusCode: 200, body: response, contentType: "application/json")
    }

    private func sendHTTPResponse(
        connection: NWConnection,
        statusCode: Int,
        body: String,
        contentType: String = "text/plain"
    ) {
        let statusText = HTTPStatus.text(for: statusCode)
        let response = """
        HTTP/1.1 \(statusCode) \(statusText)\r
        Content-Type: \(contentType)\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """

        if let data = response.data(using: .utf8) {
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    self.logger.error("Failed to send response: \(error.localizedDescription)")
                }
                // Close connection after sending response
                connection.cancel()
            })
        }
    }

    private func parseHTTPRequest(_ data: Data) -> HTTPRequest? {
        guard let requestString = String(data: data, encoding: .utf8) else {
            return nil
        }

        let lines = requestString.components(separatedBy: "\r\n")
        guard !lines.isEmpty else { return nil }

        // Parse request line
        let requestLine = lines[0].components(separatedBy: " ")
        guard requestLine.count >= 2 else { return nil }

        let method = requestLine[0]
        let path = requestLine[1]

        // Find body (after empty line)
        var body: Data?
        if let emptyLineIndex = lines.firstIndex(of: ""), emptyLineIndex + 1 < lines.count {
            let bodyString = lines[(emptyLineIndex + 1)...].joined(separator: "\r\n")
            body = bodyString.data(using: .utf8)
        }

        return HTTPRequest(method: method, path: path, headers: [:], body: body)
    }
}

// MARK: - Supporting Types

struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data?
}

struct HTTPStatus {
    static func text(for code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 500: return "Internal Server Error"
        default: return "Unknown"
        }
    }
}

enum HTTPServerError: Error, LocalizedError {
    case failedToCreateListener
    case notConnected

    var errorDescription: String? {
        switch self {
        case .failedToCreateListener:
            return "Failed to create network listener"
        case .notConnected:
            return "HTTP server is not connected"
        }
    }
}

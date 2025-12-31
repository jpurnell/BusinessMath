import Foundation
import MCP
import Network
import Logging

/// HTTP server transport for MCP using Apple's Network framework
///
/// This transport implements MCP over HTTP with Server-Sent Events (SSE):
/// - Listens on a specified port
/// - GET /mcp/sse - Opens SSE connection for server→client streaming
/// - POST /mcp - Accepts JSON-RPC requests (includes X-Session-ID header)
/// - Routes responses via SSE to correct client
///
/// Architecture:
/// 1. Client opens SSE connection (GET /mcp/sse)
/// 2. Server creates SSESession and returns session ID
/// 3. Client sends requests via POST with X-Session-ID header
/// 4. Server routes responses back via SSE stream
public actor HTTPServerTransport: Transport {
    public let logger: Logger
    private let port: UInt16
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let receiveStream: AsyncThrowingStream<Data, Error>
    private let receiveContinuation: AsyncThrowingStream<Data, Error>.Continuation
    private let responseManager: HTTPResponseManager
    private let sseSessionManager: SSESessionManager
    private let authenticator: APIKeyAuthenticator?

    /// Initialize HTTP server transport
    /// - Parameters:
    ///   - port: Port number to listen on (default: 8080)
    ///   - authenticator: Optional API key authenticator (if nil, no auth required)
    ///   - logger: Logger instance
    public init(
        port: UInt16 = 8080,
        authenticator: APIKeyAuthenticator? = nil,
        logger: Logger = Logger(label: "http-server-transport")
    ) {
        self.port = port
        self.logger = logger
        self.authenticator = authenticator
        self.responseManager = HTTPResponseManager(logger: logger)
        self.sseSessionManager = SSESessionManager(logger: logger)

        // Create receive stream
        var continuation: AsyncThrowingStream<Data, Error>.Continuation!
        self.receiveStream = AsyncThrowingStream { cont in
            continuation = cont
        }
        self.receiveContinuation = continuation
    }

    public func connect() async throws {
//        logger.info("Starting HTTP server on port \(self.port)")

        // Start response manager cleanup task
        await responseManager.startCleanup()

        // Start SSE session maintenance (cleanup + heartbeat)
        await sseSessionManager.startMaintenance()

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

        // Stop response manager cleanup task
        await responseManager.stopCleanup()

        // Shutdown SSE sessions
        await sseSessionManager.shutdown()

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
        // Try routing through SSE first (for clients using SSE)
        let sseRouted = await sseSessionManager.routeResponse(data)

        if sseRouted {
            return  // Successfully sent via SSE
        }

        // Fall back to HTTP response manager (for legacy non-SSE clients)
        let httpRouted = await responseManager.routeResponse(data)

        if !httpRouted {
            logger.warning("Failed to route response (\(data.count) bytes) - no pending request found")
        }
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
        // Check authentication for protected endpoints
        let requiresAuth = !["/health", "/mcp"].contains(request.path) || request.method == "POST"

        if requiresAuth {
            Task {
                let isAuthorized = await checkAuthorization(request: request)
                if !isAuthorized {
                    sendUnauthorizedResponse(connection: connection)
                    return
                }
                processAuthenticatedRequest(request, connection: connection)
            }
        } else {
            processAuthenticatedRequest(request, connection: connection)
        }
    }

    /// Process request after authentication (or for public endpoints)
    private func processAuthenticatedRequest(_ request: HTTPRequest, connection: NWConnection) {
        // Handle CORS preflight (OPTIONS) requests
        if request.method == "OPTIONS" {
            sendHTTPResponse(connection: connection, statusCode: 204, body: "")
            return
        }

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
                  "protocol": "MCP over HTTP + SSE",
                  "endpoints": {
                    "sse": "GET /mcp/sse - Open Server-Sent Events stream",
                    "rpc": "POST /mcp - Send JSON-RPC request (include X-Session-ID and Authorization headers)"
                  },
                  "authentication": "\(authenticator != nil ? "required" : "disabled")",
                  "cors": "enabled"
                }
                """
                sendHTTPResponse(connection: connection, statusCode: 200, body: info, contentType: "application/json")
            } else {
                sendHTTPResponse(connection: connection, statusCode: 405, body: "Method Not Allowed")
            }

        case "/mcp/sse":
            if request.method == "GET" {
                // Open SSE connection
                handleSSEConnection(connection: connection, request: request)
            } else {
                sendHTTPResponse(connection: connection, statusCode: 405, body: "Method Not Allowed")
            }

        case "/health":
            sendHTTPResponse(connection: connection, statusCode: 200, body: "OK")

        default:
            sendHTTPResponse(connection: connection, statusCode: 404, body: "Not Found")
        }
    }

    /// Check if request is authorized
    private func checkAuthorization(request: HTTPRequest) async -> Bool {
        guard let authenticator = authenticator else {
            return true  // No authenticator = no auth required
        }

        let authHeader = request.headers["Authorization"]
        return await authenticator.validate(authHeader: authHeader)
    }

    /// Send 401 Unauthorized response
    private func sendUnauthorizedResponse(connection: NWConnection) {
        let errorBody = """
        {
          "error": {
            "code": 401,
            "message": "Unauthorized",
            "details": "Valid API key required. Include Authorization header with Bearer token."
          }
        }
        """
        sendHTTPResponse(connection: connection, statusCode: 401, body: errorBody, contentType: "application/json")
    }

    private func handleJSONRPCRequest(_ request: HTTPRequest, connection: NWConnection) {
        guard let body = request.body else {
            sendHTTPResponse(connection: connection, statusCode: 400, body: "Missing request body")
            return
        }

        // Extract JSON-RPC ID from request to correlate with response
        guard let requestId = extractJSONRPCId(from: body) else {
            let errorResponse = """
            {
              "jsonrpc": "2.0",
              "id": null,
              "error": {
                "code": -32600,
                "message": "Invalid Request",
                "data": "Could not parse JSON-RPC request or extract ID"
              }
            }
            """
            sendHTTPResponse(connection: connection, statusCode: 400, body: errorResponse, contentType: "application/json")
            return
        }

        // Check if this is an SSE-based request (has X-Session-ID header)
        if let sessionId = request.headers["X-Session-ID"] {
            // Associate request with SSE session
            Task {
                await sseSessionManager.associateRequest(requestId: requestId, with: sessionId)
            }
        } else {
            // Legacy non-SSE request: register with response manager for direct HTTP response
            Task {
                await responseManager.registerRequest(requestId: requestId, connection: connection)
            }
        }

        // Forward request to MCP server via receive stream
        // The server will process it and call send() with the response
        // which will be routed back via SSE or HTTP depending on registration
        receiveContinuation.yield(body)
    }

    /// Handle SSE connection establishment
    private func handleSSEConnection(connection: NWConnection, request: HTTPRequest) {
        // Create new SSE session
        let session = SSESession(connection: connection, logger: logger)

        Task {
            let sessionId = await session.sessionId

            // Register session with manager
            await sseSessionManager.registerSession(session)

            // Send SSE headers (including CORS for browser clients)
            let headers = """
            HTTP/1.1 200 OK\r
            Content-Type: text/event-stream\r
            Cache-Control: no-cache\r
            Connection: keep-alive\r
            X-Session-ID: \(sessionId)\r
            Access-Control-Allow-Origin: *\r
            Access-Control-Allow-Headers: Authorization\r
            Access-Control-Expose-Headers: X-Session-ID\r
            \r

            """

            guard let headerData = headers.data(using: .utf8) else {
                logger.error("Failed to encode SSE headers")
                connection.cancel()
                return
            }

            connection.send(content: headerData, completion: .contentProcessed { [weak self] error in
                if let error = error {
                    self?.logger.error("Failed to send SSE headers: \(error.localizedDescription)")
                    connection.cancel()
                } else {
                    // Connection stays open for SSE streaming
                    // Don't cancel it here - it will be managed by SSESessionManager
                    self?.logger.debug("SSE connection established: \(sessionId)")
                }
            })
        }
    }

    /// Extract JSON-RPC ID from request body
    private func extractJSONRPCId(from data: Data) -> HTTPResponseManager.JSONRPCId? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        guard let idValue = json["id"] else {
            return .null
        }

        if let stringId = idValue as? String {
            return .string(stringId)
        } else if let numberId = idValue as? Int {
            return .number(numberId)
        } else if idValue is NSNull {
            return .null
        }

        return nil
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
        Access-Control-Allow-Origin: *\r
        Access-Control-Allow-Methods: GET, POST, OPTIONS\r
        Access-Control-Allow-Headers: Content-Type, Authorization, X-Session-ID\r
        Access-Control-Max-Age: 86400\r
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

        // Parse headers (between request line and empty line)
        var headers: [String: String] = [:]
        var headerEndIndex = 1
        for (index, line) in lines.enumerated() where index > 0 {
            if line.isEmpty {
                headerEndIndex = index
                break
            }

            // Parse header: "Name: Value"
            if let colonIndex = line.firstIndex(of: ":") {
                let name = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                headers[name] = value
            }
        }

        // Find body (after empty line)
        var body: Data?
        if headerEndIndex + 1 < lines.count {
            let bodyString = lines[(headerEndIndex + 1)...].joined(separator: "\r\n")
            body = bodyString.data(using: .utf8)
        }

        return HTTPRequest(method: method, path: path, headers: headers, body: body)
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
        case 204: return "No Content"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
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

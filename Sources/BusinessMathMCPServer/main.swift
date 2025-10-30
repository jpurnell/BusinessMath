import Foundation
import BusinessMathMCP
import MCP
import Logging

// MARK: - Server Configuration

/// Determine transport mode from command line arguments
enum TransportMode {
    case stdio
    case http(port: Int)

    static func parse() -> TransportMode {
        let args = CommandLine.arguments
        if let httpIndex = args.firstIndex(of: "--http"),
           httpIndex + 1 < args.count,
           let port = Int(args[httpIndex + 1]) {
            return .http(port: port)
        }
        return .stdio
    }
}

// MARK: - Main Entry Point

do {
    // Create providers
    let toolRegistry = ToolDefinitionRegistry()
    let resourceProvider = ResourceProvider()
    let promptProvider = PromptProvider()

    // Register all tool handlers
    print("Registering tools...", to: &standardError)

    // TVM Tools (9 tools)
    for handler in getTVMTools() {
        try await toolRegistry.register(handler.toToolDefinition())
    }

    // Time Series Tools (6 tools)
    for handler in getTimeSeriesTools() {
        try await toolRegistry.register(handler.toToolDefinition())
    }

    // Forecasting Tools (8 tools)
    for handler in getForecastingTools() {
        try await toolRegistry.register(handler.toToolDefinition())
    }

    // Debt Tools (6 tools)
    for handler in getDebtTools() {
        try await toolRegistry.register(handler.toToolDefinition())
    }

    // Statistical Tools (7 tools)
    for handler in getStatisticalTools() {
        try await toolRegistry.register(handler.toToolDefinition())
    }

    // Monte Carlo Tools (7 tools)
    for handler in getMonteCarloTools() {
        try await toolRegistry.register(handler.toToolDefinition())
    }

    print("✓ Registered 43 tools", to: &standardError)

    // Create and configure the MCP server using official SDK
    let server = Server(
        name: "BusinessMath MCP Server",
        version: "1.12.0",
        instructions: """
        Comprehensive business mathematics, financial modeling, Monte Carlo simulation, and statistical analysis server.

        **Capabilities**:
        - 43 computational tools across 6 categories
        - 10 documentation and example resources
        - 6 prompt templates for common financial analyses

        **Tool Categories**:
        1. Time Value of Money (TVM): NPV, IRR, PV, FV, payments, annuities
        2. Time Series Analysis: Growth rates, moving averages, comparisons
        3. Forecasting: Trend analysis, seasonal adjustment, projections
        4. Debt & Financing: Amortization, WACC, CAPM, coverage ratios
        5. Statistical Analysis: Correlation, regression, confidence intervals
        6. Monte Carlo Simulation: Risk modeling, distributions, sensitivity analysis

        **Resources**: Access comprehensive documentation, examples, and reference data using resources/read
        **Prompts**: Use prompt templates for guided analysis workflows

        For best results, consult the documentation resources before starting complex analyses.
        """,
        capabilities: Server.Capabilities(
            logging: Server.Capabilities.Logging(),
            prompts: Server.Capabilities.Prompts(listChanged: false),
            resources: Server.Capabilities.Resources(subscribe: false, listChanged: false),
            tools: Server.Capabilities.Tools(listChanged: false)
        )
    )

    // Register tool handlers
    await server.withMethodHandler(ListTools.self) { _ in
        let tools = await toolRegistry.listTools()
        return ListTools.Result(tools: tools)
    }

    await server.withMethodHandler(CallTool.self) { request in
        return try await toolRegistry.executeTool(
            name: request.name,
            arguments: request.arguments
        )
    }

    // Register resource handlers
    await server.withMethodHandler(ListResources.self) { _ in
        let resources = await resourceProvider.listResources()
        return ListResources.Result(resources: resources)
    }

    await server.withMethodHandler(ReadResource.self) { request in
        return try await resourceProvider.readResource(uri: request.uri)
    }

    // Register prompt handlers
    await server.withMethodHandler(ListPrompts.self) { _ in
        let prompts = await promptProvider.listPrompts()
        return ListPrompts.Result(prompts: prompts)
    }

    await server.withMethodHandler(GetPrompt.self) { request in
        // Convert [String: Value] to [String: String]
        let stringArgs = request.arguments?.compactMapValues { value -> String? in
            value.stringValue
        }
        return await promptProvider.getPrompt(name: request.name, arguments: stringArgs)
    }

    // Determine transport mode and start server
    let transportMode = TransportMode.parse()

    switch transportMode {
    case .stdio:
        print("✓ Starting server with stdio transport", to: &standardError)
        try await server.start(transport: StdioTransport())

    case .http(let port):
        print("✓ Starting server with HTTP transport on port \(port)", to: &standardError)
        print("  Server will be available at http://localhost:\(port)", to: &standardError)
        print("  Endpoints:", to: &standardError)
        print("    - POST /mcp     : JSON-RPC requests", to: &standardError)
        print("    - GET /mcp      : Server info", to: &standardError)
        print("    - GET /health   : Health check", to: &standardError)
        print("", to: &standardError)
        print("  Note: HTTP transport is experimental.", to: &standardError)
        print("  Full bidirectional SSE support is planned for future releases.", to: &standardError)
        print("", to: &standardError)

        let httpTransport = HTTPServerTransport(port: UInt16(port))
        try await server.start(transport: httpTransport)
    }

    print("✓ Server started successfully", to: &standardError)

    // Wait for completion
    await server.waitUntilCompleted()

} catch {
    fputs("Fatal error: \(error.localizedDescription)\n", stderr)
    if let localizedError = error as? LocalizedError,
       let failureReason = localizedError.failureReason {
        fputs("Reason: \(failureReason)\n", stderr)
    }
    exit(1)
}

// MARK: - Helper Extensions

/// FileHandle extension to write to stderr
var standardError = FileHandle.standardError

extension FileHandle: @retroactive TextOutputStream {
    public func write(_ string: String) {
        if let data = string.data(using: .utf8) {
            try? self.write(contentsOf: data)
        }
    }
}

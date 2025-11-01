import Foundation
import BusinessMathMCP
import MCP
import Logging

// MARK: - Main Entry Point

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

struct BusinessMathMCPServerMain {
    static func main() async throws {
        // Create providers
        let toolRegistry = ToolDefinitionRegistry()
        let resourceProvider = ResourceProvider()
        let promptProvider = PromptProvider()

        // Register all tool handlers
        fputs("Registering tools...\n", stderr)

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

        // Hypothesis Testing Tools (6 tools)
        for handler in getHypothesisTestingTools() {
            try await toolRegistry.register(handler.toToolDefinition())
        }

        // Advanced Statistics Tools (13 tools)
        for handler in getAdvancedStatisticsTools() {
            try await toolRegistry.register(handler.toToolDefinition())
        }

        // Optimization Tools (3 tools)
        for handler in getOptimizationTools() {
            try await toolRegistry.register(handler.toToolDefinition())
        }

        // Portfolio Optimization Tools (3 tools)
        for handler in getPortfolioTools() {
            try await toolRegistry.register(handler.toToolDefinition())
        }

        // Real Options Tools (5 tools)
        for handler in getRealOptionsTools() {
            try await toolRegistry.register(handler.toToolDefinition())
        }

        // Risk Analytics Tools (4 tools)
        for handler in getRiskAnalyticsTools() {
            try await toolRegistry.register(handler.toToolDefinition())
        }

        fputs("✓ Registered 77 tools\n", stderr)

        // Create and configure the MCP server using official SDK
        let server = Server(
            name: "BusinessMath MCP Server",
            version: "1.14.0",
            instructions: """
            Comprehensive business mathematics, financial modeling, Monte Carlo simulation, and advanced analytics server.

            **Capabilities**:
            - 77 computational tools across 15 categories
            - 10 documentation and example resources
            - 6 prompt templates for common financial analyses

            **Tool Categories**:
            1. Time Value of Money (TVM): NPV, IRR, PV, FV, payments, annuities
            2. Time Series Analysis: Growth rates, moving averages, comparisons
            3. Forecasting: Trend analysis, seasonal adjustment, projections
            4. Debt & Financing: Amortization, WACC, CAPM, coverage ratios
            5. Statistical Analysis: Correlation, regression, confidence intervals
            6. Monte Carlo Simulation: Risk modeling, distributions, sensitivity analysis
            7. Hypothesis Testing: T-tests, chi-square, sample size, A/B testing, p-values
            8. Probability Distributions: Binomial, Poisson, exponential, hypergeometric, log-normal
            9. Combinatorics: Combinations, permutations, factorial
            10. Statistical Means: Geometric, harmonic, weighted average
            11. Analysis Tools: Goal seek, data tables
            12. Optimization & Solvers: Newton-Raphson, gradient descent, capital allocation
            13. Portfolio Optimization: Modern Portfolio Theory, efficient frontier, risk parity
            14. Real Options: Black-Scholes, binomial trees, Greeks, expansion/abandonment valuation
            15. Risk Analytics: Stress testing, VaR/CVaR, risk aggregation, comprehensive risk metrics

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
            fputs("✓ Starting server with stdio transport\n", stderr)
            try await server.start(transport: StdioTransport())

        case .http(let port):
            fputs("✓ Starting server with HTTP transport on port \(port)\n", stderr)
            fputs("  Server will be available at http://localhost:\(port)\n", stderr)
            fputs("  Endpoints:\n", stderr)
            fputs("    - POST /mcp     : JSON-RPC requests\n", stderr)
            fputs("    - GET /mcp      : Server info\n", stderr)
            fputs("    - GET /health   : Health check\n", stderr)
            fputs("\n", stderr)
            fputs("  Note: HTTP transport is experimental.\n", stderr)
            fputs("  Full bidirectional SSE support is planned for future releases.\n", stderr)
            fputs("\n", stderr)

            let httpTransport = HTTPServerTransport(port: UInt16(port))
            try await server.start(transport: httpTransport)
        }

        fputs("✓ Server started successfully\n", stderr)

        // Wait for completion
        await server.waitUntilCompleted()
    }
}

// Top-level code to run the async main function
Task {
    do {
        try await BusinessMathMCPServerMain.main()
    } catch {
        fputs("Fatal error: \(error.localizedDescription)\n", stderr)
        if let localizedError = error as? LocalizedError,
           let failureReason = localizedError.failureReason {
            fputs("Reason: \(failureReason)\n", stderr)
        }
        exit(1)
    }
}

// Keep the program running
dispatchMain()

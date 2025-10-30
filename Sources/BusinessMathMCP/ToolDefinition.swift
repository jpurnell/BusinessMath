import Foundation
import MCP

/// A tool definition that combines metadata and execution logic
public struct ToolDefinition: Sendable {
    public let tool: Tool
    public let execute: @Sendable ([String: MCP.Value]?) async throws -> CallTool.Result

    /// Initialize with a Tool and execute closure
    public init(
        tool: Tool,
        execute: @escaping @Sendable ([String: MCP.Value]?) async throws -> CallTool.Result
    ) {
        self.tool = tool
        self.execute = execute
    }

    /// Initialize with individual parameters (using Value directly)
    public init(
        name: String,
        description: String,
        inputSchema: MCP.Value,
        execute: @escaping @Sendable ([String: MCP.Value]?) async throws -> CallTool.Result
    ) {
        self.tool = Tool(
            name: name,
            description: description,
            inputSchema: inputSchema
        )
        self.execute = execute
    }
}

/// Registry for managing tool definitions
public actor ToolDefinitionRegistry {
    private var tools: [String: ToolDefinition] = [:]

    public init() {}

    public func register(_ definition: ToolDefinition) {
        tools[definition.tool.name] = definition
    }

    public func register(_ definitions: [ToolDefinition]) {
        for definition in definitions {
            register(definition)
        }
    }

    public func listTools() -> [Tool] {
        return Array(tools.values.map { $0.tool })
    }

    public func executeTool(name: String, arguments: [String: MCP.Value]?) async throws -> CallTool.Result {
        guard let definition = tools[name] else {
            return CallTool.Result(
                content: [.text("Tool not found: \(name)")],
                isError: true
            )
        }

        do {
            return try await definition.execute(arguments)
        } catch let error as ValueExtractionError {
            return CallTool.Result(
                content: [.text(error.localizedDescription)],
                isError: true
            )
        } catch {
            return CallTool.Result(
                content: [.text("Execution error: \(error.localizedDescription)")],
                isError: true
            )
        }
    }
}

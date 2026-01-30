import Foundation
import MCP
import BusinessMath
import Numerics

// MARK: - Compatibility Layer for Migration from Custom MCPSwift to Official SDK

/// Compatibility protocol matching our old MCPToolHandler
public protocol MCPToolHandler: Sendable {
    var tool: MCPTool { get }
    func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult
}

/// Compatibility type matching our old MCPTool
public struct MCPTool: Sendable {
    public let name: String
    public let description: String
    public let inputSchema: MCPToolInputSchema

    public init(name: String, description: String, inputSchema: MCPToolInputSchema) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }

    /// Convert to official SDK Tool
    func toSDKTool() throws -> Tool {
        return Tool(
            name: name,
            description: description,
            inputSchema: try inputSchema.toValue()
        )
    }
}

/// Compatibility type for tool input schema
public struct MCPToolInputSchema: Sendable {
    public let type: String
    public let properties: [String: MCPSchemaProperty]?
    public let required: [String]?

    public init(type: String = "object", properties: [String: MCPSchemaProperty]? = nil, required: [String]? = nil) {
        self.type = type
        self.properties = properties
        self.required = required
    }

    /// Convert to MCP.Value
    func toValue() throws -> MCP.Value {
        var dict: [String: MCP.Value] = [
            "type": .string(type)
        ]

        if let properties = properties {
            var propsDict: [String: MCP.Value] = [:]
            for (key, prop) in properties {
                propsDict[key] = try prop.toValue()
            }
            dict["properties"] = .object(propsDict)
        }

        if let required = required {
            dict["required"] = .array(required.map { .string($0) })
        }

        return .object(dict)
    }
}

/// Compatibility type for schema property
public struct MCPSchemaProperty: Sendable {
    public let type: String
    public let description: String?
    public let `enum`: [String]?
    public let items: MCPSchemaItems?

    public init(type: String, description: String? = nil, `enum`: [String]? = nil, items: MCPSchemaItems? = nil) {
        self.type = type
        self.description = description
        self.`enum` = `enum`
        self.items = items
    }

    /// Convert to MCP.Value
    func toValue() throws -> MCP.Value {
        var dict: [String: MCP.Value] = [
            "type": .string(type)
        ]

        if let description = description {
            dict["description"] = .string(description)
        }

        if let enumValues = `enum` {
            dict["enum"] = .array(enumValues.map { .string($0) })
        }

        if let items = items {
            dict["items"] = try items.toValue()
        }

        return .object(dict)
    }
}

/// Compatibility type for schema items
public struct MCPSchemaItems: Sendable {
    public let type: String

    public init(type: String) {
        self.type = type
    }

    /// Convert to MCP.Value
    func toValue() throws -> MCP.Value {
        return .object(["type": .string(type)])
    }
}

/// Compatibility type-erased wrapper
public struct AnyCodable: @unchecked Sendable {
    public let value: Any

    public init<T: Codable & Sendable>(_ value: T) {
        self.value = value
    }

    /// Convert from MCP.Value
    init(_ mcpValue: MCP.Value) {
        switch mcpValue {
        case .null:
            self.value = Optional<Int>.none as Any
        case .bool(let v):
            self.value = v
        case .int(let v):
            self.value = v
        case .double(let v):
            self.value = v
        case .string(let v):
            self.value = v
        case .data(_, let v):
            self.value = v
        case .array(let v):
            self.value = v.map { AnyCodable($0) }
        case .object(let v):
            self.value = v.mapValues { AnyCodable($0) }
        }
    }
}

/// Compatibility result type
public struct MCPToolCallResult: Sendable {
    let result: CallTool.Result

    init(_ result: CallTool.Result) {
        self.result = result
    }

    public static func success(text: String) -> MCPToolCallResult {
        return MCPToolCallResult(CallTool.Result(content: [.text(text)], isError: false))
    }

    public static func error(message: String) -> MCPToolCallResult {
        return MCPToolCallResult(CallTool.Result(content: [.text(message)], isError: true))
    }
}

/// Compatibility error type
public enum ToolError: Error, LocalizedError {
    case toolNotFound(String)
    case invalidArguments(String)
    case executionFailed(String, String)
    case missingRequiredArgument(String)

    public var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool not found: \(name)"
        case .invalidArguments(let message):
            return "Invalid arguments: \(message)"
        case .executionFailed(let tool, let message):
            return "Execution failed for \(tool): \(message)"
        case .missingRequiredArgument(let key):
            return "Missing required argument: \(key)"
        }
    }
}

// MARK: - Conversion Helpers

extension Dictionary where Key == String, Value == AnyCodable {
    /// Convert from MCP.Value dictionary
    static func from(_ mcpDict: [String: MCP.Value]) -> [String: AnyCodable] {
        return mcpDict.mapValues { AnyCodable($0) }
    }

    /// Get required string
    public func getString(_ key: String) throws -> String {
        guard let value = self[key] else {
            throw ToolError.missingRequiredArgument(key)
        }
        guard let stringValue = value.value as? String else {
            throw ToolError.invalidArguments("\(key) must be a string")
        }
        return stringValue
    }

    /// Get optional string
    public func getStringOptional(_ key: String) -> String? {
        return self[key]?.value as? String
    }

    /// Get required int
    public func getInt(_ key: String) throws -> Int {
        guard let value = self[key] else {
            throw ToolError.missingRequiredArgument(key)
        }
        guard let intValue = value.value as? Int else {
            throw ToolError.invalidArguments("\(key) must be an integer")
        }
        return intValue
    }

    /// Get optional int
    public func getIntOptional(_ key: String) -> Int? {
        return self[key]?.value as? Int
    }

    /// Get required double
    public func getDouble(_ key: String) throws -> Double {
        guard let value = self[key] else {
            throw ToolError.missingRequiredArgument(key)
        }
        if let doubleValue = value.value as? Double {
            return doubleValue
        } else if let intValue = value.value as? Int {
            return Double(intValue)
        } else {
            throw ToolError.invalidArguments("\(key) must be a number")
        }
    }

    /// Get optional double
    public func getDoubleOptional(_ key: String) -> Double? {
        if let doubleValue = self[key]?.value as? Double {
            return doubleValue
        } else if let intValue = self[key]?.value as? Int {
            return Double(intValue)
        }
        return nil
    }

    /// Get required bool
    public func getBool(_ key: String) throws -> Bool {
        guard let value = self[key] else {
            throw ToolError.missingRequiredArgument(key)
        }
        guard let boolValue = value.value as? Bool else {
            throw ToolError.invalidArguments("\(key) must be a boolean")
        }
        return boolValue
    }

    /// Get optional bool
    public func getBoolOptional(_ key: String) -> Bool? {
        return self[key]?.value as? Bool
    }

    /// Get double array
    public func getDoubleArray(_ key: String) throws -> [Double] {
        guard let value = self[key] else {
            throw ToolError.missingRequiredArgument(key)
        }
        guard let arrayValue = value.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("\(key) must be an array")
        }

        var result: [Double] = []
        for (index, item) in arrayValue.enumerated() {
            if let doubleValue = item.value as? Double {
                result.append(doubleValue)
            } else if let intValue = item.value as? Int {
                result.append(Double(intValue))
            } else {
                throw ToolError.invalidArguments("\(key)[\(index)] must be a number")
            }
        }
        return result
    }

    /// Get string array
    public func getStringArray(_ key: String) throws -> [String] {
        guard let value = self[key] else {
            throw ToolError.missingRequiredArgument(key)
        }
        guard let arrayValue = value.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("\(key) must be an array")
        }

        var result: [String] = []
        for (index, item) in arrayValue.enumerated() {
            guard let stringValue = item.value as? String else {
                throw ToolError.invalidArguments("\(key)[\(index)] must be a string")
            }
            result.append(stringValue)
        }
        return result
    }

    /// Get Period (BusinessMath-specific)
    public func getPeriod(_ key: String) throws -> Period {
        guard let value = self[key] else {
            throw ToolError.missingRequiredArgument(key)
        }

        guard let dict = value.value as? [String: AnyCodable] else {
            throw ToolError.invalidArguments("\(key) must be an object")
        }

        guard let yearValue = dict["year"],
              let year = yearValue.value as? Int,
              let typeValue = dict["type"],
              let typeInt = typeValue.value as? Int,
              let periodType = PeriodType(rawValue: typeInt) else {
            throw ToolError.invalidArguments("\(key) must have valid year and type")
        }

        switch periodType {
        case .millisecond, .second, .minute, .hourly:
            // Sub-daily periods not yet supported in MCP interface
            throw ToolError.invalidArguments("Sub-daily periods not yet supported in MCP interface")
        case .annual:
            return Period.year(year)
        case .quarterly:
            guard let monthValue = dict["month"],
                  let month = monthValue.value as? Int else {
                throw ToolError.invalidArguments("\(key) quarter must have month")
            }
            let quarter = (month - 1) / 3 + 1
            return Period.quarter(year: year, quarter: quarter)
        case .monthly:
            guard let monthValue = dict["month"],
                  let month = monthValue.value as? Int else {
                throw ToolError.invalidArguments("\(key) month must have month")
            }
            return Period.month(year: year, month: month)
        case .daily:
            guard let monthValue = dict["month"],
                  let month = monthValue.value as? Int,
                  let dayValue = dict["day"],
                  let day = dayValue.value as? Int else {
                throw ToolError.invalidArguments("\(key) day must have month and day")
            }
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            guard let date = Calendar.current.date(from: components) else {
                throw ToolError.invalidArguments("\(key) has invalid date components")
            }
            return Period.day(date)
        }
    }

    /// Get TimeSeries (BusinessMath-specific)
    public func getTimeSeries(_ key: String) throws -> TimeSeries<Double> {
        guard let value = self[key] else {
            throw ToolError.missingRequiredArgument(key)
        }

        // Convert to JSON and decode
        let jsonData = try JSONSerialization.data(withJSONObject: value.value)
        let decoder = JSONDecoder()
        let timeSeriesJSON = try decoder.decode(TimeSeriesJSON.self, from: jsonData)
        return try timeSeriesJSON.toTimeSeries()
    }

    /// Check if a key exists
    public func hasKey(_ key: String) -> Bool {
        return self[key] != nil
    }

    /// Get a double from a nested object
    public func getDoubleFromObject(_ objectKey: String, key: String) throws -> Double {
        guard let objectValue = self[objectKey] else {
            throw ToolError.missingRequiredArgument(objectKey)
        }

        guard let dict = objectValue.value as? [String: AnyCodable] else {
            throw ToolError.invalidArguments("\(objectKey) must be an object")
        }

        guard let value = dict[key] else {
            throw ToolError.missingRequiredArgument("\(objectKey).\(key)")
        }

        if let doubleVal = value.value as? Double {
            return doubleVal
        } else if let intVal = value.value as? Int {
            return Double(intVal)
        } else {
            throw ToolError.invalidArguments("\(objectKey).\(key) must be a number")
        }
    }
}

// MARK: - Tool Handler Conversion

extension MCPToolHandler {
    /// Convert to ToolDefinition for use with official SDK
    public func toToolDefinition() throws -> ToolDefinition {
        let sdkTool = try tool.toSDKTool()
        let handler = self

        // Create a properly structured ToolDefinition manually
        return ToolDefinition(
            tool: sdkTool,
            execute: { arguments in
                // Convert MCP.Value arguments to AnyCodable
                let compatArgs: [String: AnyCodable]? = arguments.map { dict in
                    dict.mapValues { AnyCodable($0) }
                }

                // Execute with compatibility layer
                let result = try await handler.execute(arguments: compatArgs)
                return result.result
            }
        )
    }
}

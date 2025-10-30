import Foundation
import MCP

// MARK: - Value Extraction Helpers

/// Errors that can occur when extracting values from arguments
public enum ValueExtractionError: Error, LocalizedError {
    case missingRequiredArgument(String)
    case invalidArguments(String)
    case executionFailed(String, String)

    public var errorDescription: String? {
        switch self {
        case .missingRequiredArgument(let key):
            return "Missing required argument: \(key)"
        case .invalidArguments(let message):
            return "Invalid arguments: \(message)"
        case .executionFailed(let tool, let message):
            return "Execution failed for \(tool): \(message)"
        }
    }
}

extension Dictionary where Key == String, Value == MCP.Value {
    /// Get a required string value
    public func getString(_ key: String) throws -> String {
        guard let value = self[key] else {
            throw ValueExtractionError.missingRequiredArgument(key)
        }
        guard let stringValue = value.stringValue else {
            throw ValueExtractionError.invalidArguments("\(key) must be a string")
        }
        return stringValue
    }

    /// Get an optional string value
    public func getStringOptional(_ key: String) -> String? {
        return self[key]?.stringValue
    }

    /// Get a required integer value
    public func getInt(_ key: String) throws -> Int {
        guard let value = self[key] else {
            throw ValueExtractionError.missingRequiredArgument(key)
        }
        guard let intValue = value.intValue else {
            throw ValueExtractionError.invalidArguments("\(key) must be an integer")
        }
        return intValue
    }

    /// Get an optional integer value
    public func getIntOptional(_ key: String) -> Int? {
        return self[key]?.intValue
    }

    /// Get a required double value
    public func getDouble(_ key: String) throws -> Double {
        guard let value = self[key] else {
            throw ValueExtractionError.missingRequiredArgument(key)
        }
        // Accept both int and double
        if let doubleValue = value.doubleValue {
            return doubleValue
        } else if let intValue = value.intValue {
            return Double(intValue)
        } else {
            throw ValueExtractionError.invalidArguments("\(key) must be a number")
        }
    }

    /// Get an optional double value
    public func getDoubleOptional(_ key: String) -> Double? {
        if let doubleValue = self[key]?.doubleValue {
            return doubleValue
        } else if let intValue = self[key]?.intValue {
            return Double(intValue)
        }
        return nil
    }

    /// Get a required boolean value
    public func getBool(_ key: String) throws -> Bool {
        guard let value = self[key] else {
            throw ValueExtractionError.missingRequiredArgument(key)
        }
        guard let boolValue = value.boolValue else {
            throw ValueExtractionError.invalidArguments("\(key) must be a boolean")
        }
        return boolValue
    }

    /// Get an optional boolean value
    public func getBoolOptional(_ key: String) -> Bool? {
        return self[key]?.boolValue
    }

    /// Get a required array of doubles
    public func getDoubleArray(_ key: String) throws -> [Double] {
        guard let value = self[key] else {
            throw ValueExtractionError.missingRequiredArgument(key)
        }
        guard let arrayValue = value.arrayValue else {
            throw ValueExtractionError.invalidArguments("\(key) must be an array")
        }

        var result: [Double] = []
        for (index, item) in arrayValue.enumerated() {
            if let doubleValue = item.doubleValue {
                result.append(doubleValue)
            } else if let intValue = item.intValue {
                result.append(Double(intValue))
            } else {
                throw ValueExtractionError.invalidArguments("\(key)[\(index)] must be a number")
            }
        }
        return result
    }

    /// Get an optional array of doubles
    public func getDoubleArrayOptional(_ key: String) -> [Double]? {
        guard let value = self[key], let arrayValue = value.arrayValue else {
            return nil
        }

        var result: [Double] = []
        for item in arrayValue {
            if let doubleValue = item.doubleValue {
                result.append(doubleValue)
            } else if let intValue = item.intValue {
                result.append(Double(intValue))
            } else {
                return nil // Invalid array element
            }
        }
        return result
    }

    /// Get a required array of strings
    public func getStringArray(_ key: String) throws -> [String] {
        guard let value = self[key] else {
            throw ValueExtractionError.missingRequiredArgument(key)
        }
        guard let arrayValue = value.arrayValue else {
            throw ValueExtractionError.invalidArguments("\(key) must be an array")
        }

        var result: [String] = []
        for (index, item) in arrayValue.enumerated() {
            guard let stringValue = item.stringValue else {
                throw ValueExtractionError.invalidArguments("\(key)[\(index)] must be a string")
            }
            result.append(stringValue)
        }
        return result
    }

    /// Get an optional array of strings
    public func getStringArrayOptional(_ key: String) -> [String]? {
        guard let value = self[key], let arrayValue = value.arrayValue else {
            return nil
        }

        var result: [String] = []
        for item in arrayValue {
            guard let stringValue = item.stringValue else {
                return nil // Invalid array element
            }
            result.append(stringValue)
        }
        return result
    }
}

// MARK: - CallTool.Result Helpers

extension CallTool.Result {
    /// Create a success result with text content
    public static func success(text: String) -> CallTool.Result {
        return CallTool.Result(content: [.text(text)], isError: false)
    }

    /// Create an error result with error message
    public static func error(message: String) -> CallTool.Result {
        return CallTool.Result(content: [.text(message)], isError: true)
    }
}

//
//  MCPToolMacro.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-29.
//

import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder
import SwiftCompilerPlugin
import SwiftDiagnostics
import Foundation

/// Macro that generates MCP tool definitions from functions.
///
/// This macro transforms annotated functions into Model Context Protocol (MCP) tools,
/// automatically generating the necessary boilerplate for tool registration, schema
/// definition, and argument handling.
///
/// ## Usage Example
///
/// ```swift
/// @MCPTool(description: "Calculate the sum of two numbers")
/// func add(a: Double, b: Double) -> Double {
///     return a + b
/// }
/// ```
///
/// This generates:
/// - Tool definition with JSON schema
/// - Argument validation and extraction
/// - Result formatting
/// - Error handling
public struct MCPToolMacro: PeerMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        // 1. Verify this is a function declaration
        guard let functionDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw DiagnosticsError(diagnostics: [
                Diagnostic(
                    node: node,
                    message: MacroError.notAFunction
                )
            ])
        }

        // 2. Extract description from macro arguments
        guard let description = extractDescription(from: node) else {
            throw DiagnosticsError(diagnostics: [
                Diagnostic(
                    node: node,
                    message: MacroError.missingDescription
                )
            ])
        }

        // 3. Extract function information
        let functionName = functionDecl.name.text
        let parameters = functionDecl.signature.parameterClause.parameters
        let isThrows = functionDecl.signature.effectSpecifiers?.throwsSpecifier != nil

        // 4. Generate schema properties
        let schemaProperties = generateSchemaProperties(from: parameters)

        // 5. Generate required parameters list
        let requiredParams = generateRequiredParameters(from: parameters)

        // 6. Generate argument extraction code
        let argExtraction = generateArgumentExtraction(from: parameters)

        // 7. Generate function call
        let functionCall = generateFunctionCall(
            functionName: functionName,
            parameters: parameters,
            isThrows: isThrows
        )

        // 8. Generate result formatting
        let resultFormatting = generateResultFormatting(functionName: functionName)

        // 9. Generate error handling wrapper if needed
        let handlerBody: String
        if isThrows {
            handlerBody = """
                        do {
            \(argExtraction)
                            \(functionCall)
                            \(resultFormatting)
                        } catch {
                            return ToolResult(
                                content: [
                                    TextContent(
                                        type: "text",
                                        text: "Error: \\(error.localizedDescription)"
                                    )
                                ],
                                isError: true
                            )
                        }
            """
        } else {
            handlerBody = """
            \(argExtraction)
                        \(functionCall)
                        \(resultFormatting)
            """
        }

        // 10. Generate the extension with toToolDefinition method
        let extensionDecl: DeclSyntax = """

        extension \(raw: functionName) {
            static func toToolDefinition() -> ToolDefinition {
                return ToolDefinition(
                    name: "\(raw: functionName)",
                    description: \(literal: description),
                    schema: MCPSchema(
                        type: "object",
                        properties: [
        \(raw: schemaProperties)
                        ],
                        required: [\(raw: requiredParams)]
                    ),
                    handler: { args in
        \(raw: handlerBody)
                    }
                )
            }
        }
        """

        return [extensionDecl]
    }

    // MARK: - Helper Methods

    /// Extract description from macro attribute
    private static func extractDescription(from node: AttributeSyntax) -> String? {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            return nil
        }

        for argument in arguments {
            if argument.label?.text == "description",
               let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
               let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) {
                return segment.content.text
            }
        }

        return nil
    }

    /// Generate schema properties dictionary entries
    private static func generateSchemaProperties(from parameters: FunctionParameterListSyntax) -> String {
        let properties = parameters.map { parameter -> String in
            let name = parameter.secondName?.text ?? parameter.firstName.text
            let typeName = parameter.type.description.trimmingCharacters(in: .whitespaces)
            let jsonType = swiftTypeToJSONType(typeName)
            let description = extractParameterDescription(from: parameter)
            let hasDefault = parameter.defaultValue != nil

            var property = """
                        "\(name)": MCPSchemaProperty(type: "\(jsonType)", description: "\(description)"
            """

            // Add items for arrays
            if typeName.hasPrefix("[") {
                let elementType = typeName.dropFirst().dropLast().trimmingCharacters(in: .whitespaces)
                let elementJSONType = swiftTypeToJSONType(String(elementType))
                property += ", items: MCPSchemaItems(type: \"\(elementJSONType)\")"
            }

            // Add default value if present
            if hasDefault, let defaultValue = parameter.defaultValue?.value.description {
                property += ", defaultValue: \(defaultValue)"
            }

            property += ")"

            return property
        }

        return properties.joined(separator: ",\n")
    }

    /// Generate list of required parameters
    private static func generateRequiredParameters(from parameters: FunctionParameterListSyntax) -> String {
        let required = parameters.compactMap { parameter -> String? in
            guard parameter.defaultValue == nil else { return nil }
            let name = parameter.secondName?.text ?? parameter.firstName.text
            return "\"\(name)\""
        }

        return required.joined(separator: ", ")
    }

    /// Generate argument extraction and validation code
    private static func generateArgumentExtraction(from parameters: FunctionParameterListSyntax) -> String {
        var extraction = """
                        guard
        """

        let guards = parameters.map { parameter -> String in
            let name = parameter.secondName?.text ?? parameter.firstName.text
            let typeName = parameter.type.description.trimmingCharacters(in: .whitespaces)
            let hasDefault = parameter.defaultValue != nil

            if hasDefault {
                // Optional parameters handled separately
                return ""
            }

            return generateArgumentGuard(name: name, type: typeName)
        }.filter { !$0.isEmpty }

        extraction += guards.joined(separator: ",\n")
        extraction += """
         else {
                            throw ToolError.invalidArguments("Missing required arguments")
                        }
        """

        // Handle optional parameters with defaults
        let optionalExtractions = parameters.compactMap { parameter -> String? in
            guard parameter.defaultValue != nil else { return nil }
            let name = parameter.secondName?.text ?? parameter.firstName.text
            let typeName = parameter.type.description.trimmingCharacters(in: .whitespaces)
            let defaultValue = parameter.defaultValue?.value.description ?? ""

            return """

                        let \(name) = args["\(name)"]?\(extractorSuffix(for: typeName)) ?? \(defaultValue)
            """
        }

        if !optionalExtractions.isEmpty {
            extraction += optionalExtractions.joined()
        }

        return extraction
    }

    /// Generate guard clause for a single parameter
    private static func generateArgumentGuard(name: String, type: String) -> String {
        if type.hasPrefix("[") {
            // Array type
            let elementType = type.dropFirst().dropLast().trimmingCharacters(in: .whitespaces)
            let conversion = arrayConversion(elementType: elementType, name: name)
            return """
                          let \(name)Array = args["\(name)"]?.arrayValue,
                          let \(name) = \(conversion) as? \(type)
            """
        } else {
            // Simple type
            let extractor = extractorSuffix(for: type)
            let conversion = typeConversion(for: type)
            return """
                          let \(name) = args["\(name)"]?\(extractor)\(conversion)
            """
        }
    }

    /// Generate function call with all parameters
    private static func generateFunctionCall(
        functionName: String,
        parameters: FunctionParameterListSyntax,
        isThrows: Bool
    ) -> String {
        let throwsKeyword = isThrows ? "try " : ""
        let paramList = parameters.map { parameter -> String in
            let name = parameter.secondName?.text ?? parameter.firstName.text
            let label = parameter.firstName.text
            return "\(label): \(name)"
        }.joined(separator: ", ")

        return """
                        let result = \(throwsKeyword)\(functionName)(\(paramList))
        """
    }

    /// Generate result formatting code
    private static func generateResultFormatting(functionName: String) -> String {
        return """

                        return ToolResult(
                            content: [
                                TextContent(
                                    type: "text",
                                    text: "Result: \\(result)"
                                )
                            ]
                        )
        """
    }

    /// Extract parameter description from documentation comment
    private static func extractParameterDescription(from parameter: FunctionParameterSyntax) -> String {
        // TODO: Parse documentation comments from trivia
        // For now, return empty string
        return ""
    }

    /// Convert Swift type to JSON schema type
    private static func swiftTypeToJSONType(_ swiftType: String) -> String {
        let type = swiftType.trimmingCharacters(in: .whitespaces)

        if type.hasPrefix("[") {
            return "array"
        }

        switch type {
        case "Int", "Double", "Float", "Int32", "Int64":
            return "number"
        case "String":
            return "string"
        case "Bool":
            return "boolean"
        default:
            return "object"
        }
    }

    /// Get the appropriate extractor suffix for a type
    private static func extractorSuffix(for type: String) -> String {
        let baseType = type.trimmingCharacters(in: .whitespaces)

        switch baseType {
        case "Int", "Double", "Float":
            return ".numberValue"
        case "String":
            return ".stringValue"
        case "Bool":
            return ".boolValue"
        default:
            return ".value"
        }
    }

    /// Get type conversion code for numeric types
    private static func typeConversion(for type: String) -> String {
        switch type {
        case "Int":
            return ".map({ Int($0) })"
        case "Float":
            return ".map({ Float($0) })"
        default:
            return ""
        }
    }

    /// Get array conversion code
    private static func arrayConversion(elementType: String, name: String = "items") -> String {
        switch elementType {
        case "Int":
            return "[\(name)Array.compactMap({ $0.numberValue.map({ Int($0) }) })]"
        case "Double":
            return "[\(name)Array.compactMap({ $0.numberValue })]"
        case "String":
            return "[\(name)Array.compactMap({ $0.stringValue })]"
        default:
            return "[\(name)Array.compactMap({ $0.value as? \(elementType) })]"
        }
    }
}

// MARK: - Error Types

enum MacroError: String, DiagnosticMessage {
    case notAFunction = "@MCPTool can only be applied to functions"
    case missingDescription = "@MCPTool requires a 'description' parameter"

    var message: String { rawValue }
    var diagnosticID: MessageID {
        MessageID(domain: "BusinessMathMacros", id: rawValue)
    }
    var severity: DiagnosticSeverity { .error }
}

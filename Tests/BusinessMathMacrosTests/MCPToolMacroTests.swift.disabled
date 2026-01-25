//
//  MCPToolMacroTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-29.
//

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing
@testable import BusinessMathMacrosImpl

/// Tests for the @MCPTool macro that generates MCP tool definitions from functions.
@Suite("MCP Tool Macro Tests")
struct MCPToolMacroTests {

    // MARK: - Test Helpers

    /// Macro specifications to test
    let testMacros: [String: Macro.Type] = [
        "MCPTool": MCPToolMacro.self
    ]

    // MARK: - Basic Macro Application Tests

    @Test("@MCPTool macro generates basic tool definition")
    func basicToolGeneration() {
        assertMacroExpansion(
            """
            @MCPTool(description: "Calculate the sum of two numbers")
            func add(a: Double, b: Double) -> Double {
                return a + b
            }
            """,
            expandedSource: """
            func add(a: Double, b: Double) -> Double {
                return a + b
            }

            extension add {
                static func toToolDefinition() -> ToolDefinition {
                    return ToolDefinition(
                        name: "add",
                        description: "Calculate the sum of two numbers",
                        schema: MCPSchema(
                            type: "object",
                            properties: [
                                "a": MCPSchemaProperty(type: "number", description: ""),
                                "b": MCPSchemaProperty(type: "number", description: "")
                            ],
                            required: ["a", "b"]
                        ),
                        handler: { args in
                            guard let a = args["a"]?.numberValue,
                                  let b = args["b"]?.numberValue else {
                                throw ToolError.invalidArguments("Missing required arguments")
                            }

                            let result = add(a: a, b: b)

                            return ToolResult(
                                content: [
                                    TextContent(
                                        type: "text",
                                        text: "Result: \\(result)"
                                    )
                                ]
                            )
                        }
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("@MCPTool macro with parameter descriptions")
    func toolWithParameterDescriptions() {
        assertMacroExpansion(
            """
            @MCPTool(description: "Calculate NPV for cash flows")
            func npv(
                /// The discount rate to use
                rate: Double,
                /// Array of cash flows over time
                cashFlows: [Double]
            ) -> Double {
                return 0.0
            }
            """,
            expandedSource: """
            func npv(
                /// The discount rate to use
                rate: Double,
                /// Array of cash flows over time
                cashFlows: [Double]
            ) -> Double {
                return 0.0
            }

            extension npv {
                static func toToolDefinition() -> ToolDefinition {
                    return ToolDefinition(
                        name: "npv",
                        description: "Calculate NPV for cash flows",
                        schema: MCPSchema(
                            type: "object",
                            properties: [
                                "rate": MCPSchemaProperty(type: "number", description: "The discount rate to use"),
                                "cashFlows": MCPSchemaProperty(type: "array", description: "Array of cash flows over time", items: MCPSchemaItems(type: "number"))
                            ],
                            required: ["rate", "cashFlows"]
                        ),
                        handler: { args in
                            guard let rate = args["rate"]?.numberValue,
                                  let cashFlowsArray = args["cashFlows"]?.arrayValue,
                                  let cashFlows = cashFlowsArray.compactMap({ $0.numberValue }) as? [Double] else {
                                throw ToolError.invalidArguments("Missing required arguments")
                            }

                            let result = npv(rate: rate, cashFlows: cashFlows)

                            return ToolResult(
                                content: [
                                    TextContent(
                                        type: "text",
                                        text: "NPV: \\(result)"
                                    )
                                ]
                            )
                        }
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    @Test("@MCPTool macro with optional parameters")
    func toolWithOptionalParameters() {
        assertMacroExpansion(
            """
            @MCPTool(description: "Calculate IRR")
            func irr(cashFlows: [Double], guess: Double = 0.1) throws -> Double {
                return 0.0
            }
            """,
            expandedSource: """
            func irr(cashFlows: [Double], guess: Double = 0.1) throws -> Double {
                return 0.0
            }

            extension irr {
                static func toToolDefinition() -> ToolDefinition {
                    return ToolDefinition(
                        name: "irr",
                        description: "Calculate IRR",
                        schema: MCPSchema(
                            type: "object",
                            properties: [
                                "cashFlows": MCPSchemaProperty(type: "array", description: "", items: MCPSchemaItems(type: "number")),
                                "guess": MCPSchemaProperty(type: "number", description: "", defaultValue: 0.1)
                            ],
                            required: ["cashFlows"]
                        ),
                        handler: { args in
                            guard let cashFlowsArray = args["cashFlows"]?.arrayValue,
                                  let cashFlows = cashFlowsArray.compactMap({ $0.numberValue }) as? [Double] else {
                                throw ToolError.invalidArguments("Missing required arguments")
                            }

                            let guess = args["guess"]?.numberValue ?? 0.1

                            do {
                                let result = try irr(cashFlows: cashFlows, guess: guess)

                                return ToolResult(
                                    content: [
                                        TextContent(
                                            type: "text",
                                            text: "IRR: \\(result)"
                                        )
                                    ]
                                )
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
                        }
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Type Mapping Tests

    @Test("@MCPTool maps Swift types to JSON schema types")
    func typeMapping() {
        assertMacroExpansion(
            """
            @MCPTool(description: "Test type mappings")
            func testTypes(
                intParam: Int,
                doubleParam: Double,
                boolParam: Bool,
                stringParam: String,
                arrayParam: [Int]
            ) -> String {
                return ""
            }
            """,
            expandedSource: """
            func testTypes(
                intParam: Int,
                doubleParam: Double,
                boolParam: Bool,
                stringParam: String,
                arrayParam: [Int]
            ) -> String {
                return ""
            }

            extension testTypes {
                static func toToolDefinition() -> ToolDefinition {
                    return ToolDefinition(
                        name: "testTypes",
                        description: "Test type mappings",
                        schema: MCPSchema(
                            type: "object",
                            properties: [
                                "intParam": MCPSchemaProperty(type: "number", description: ""),
                                "doubleParam": MCPSchemaProperty(type: "number", description: ""),
                                "boolParam": MCPSchemaProperty(type: "boolean", description: ""),
                                "stringParam": MCPSchemaProperty(type: "string", description: ""),
                                "arrayParam": MCPSchemaProperty(type: "array", description: "", items: MCPSchemaItems(type: "number"))
                            ],
                            required: ["intParam", "doubleParam", "boolParam", "stringParam", "arrayParam"]
                        ),
                        handler: { args in
                            guard let intParam = args["intParam"]?.numberValue.map({ Int($0) }),
                                  let doubleParam = args["doubleParam"]?.numberValue,
                                  let boolParam = args["boolParam"]?.boolValue,
                                  let stringParam = args["stringParam"]?.stringValue,
                                  let arrayParamValues = args["arrayParam"]?.arrayValue,
                                  let arrayParam = arrayParamValues.compactMap({ $0.numberValue.map({ Int($0) }) }) as? [Int] else {
                                throw ToolError.invalidArguments("Missing required arguments")
                            }

                            let result = testTypes(
                                intParam: intParam,
                                doubleParam: doubleParam,
                                boolParam: boolParam,
                                stringParam: stringParam,
                                arrayParam: arrayParam
                            )

                            return ToolResult(
                                content: [
                                    TextContent(
                                        type: "text",
                                        text: "Result: \\(result)"
                                    )
                                ]
                            )
                        }
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Error Handling Tests

    @Test("@MCPTool on non-function declaration produces diagnostic")
    func nonFunctionDiagnostic() {
        assertMacroExpansion(
            """
            @MCPTool(description: "This is a struct")
            struct MyStruct {
                var value: Int
            }
            """,
            expandedSource: """
            struct MyStruct {
                var value: Int
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@MCPTool can only be applied to functions",
                    line: 1,
                    column: 1,
                    severity: .error
                )
            ],
            macros: testMacros
        )
    }

    @Test("@MCPTool without description parameter produces diagnostic")
    func missingDescriptionDiagnostic() {
        assertMacroExpansion(
            """
            @MCPTool
            func add(a: Double, b: Double) -> Double {
                return a + b
            }
            """,
            expandedSource: """
            func add(a: Double, b: Double) -> Double {
                return a + b
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@MCPTool requires a 'description' parameter",
                    line: 1,
                    column: 1,
                    severity: .error
                )
            ],
            macros: testMacros
        )
    }
}

import Testing
import Foundation
import MCP
@testable import BusinessMathMCP
@testable import BusinessMath

/// Test suite for ScenarioAnalysisTool
///
/// Tests follow TDD principles:
/// 1. RED: Write failing tests first (tool doesn't exist yet)
/// 2. GREEN: Implement tool to pass tests
/// 3. REFACTOR: Improve implementation
///
/// Key validation goals:
/// - Tool executes scenario analysis with multiple scenarios
/// - setValue() vs setDistribution() work correctly
/// - Different distribution types are supported
/// - Best/worst scenario identification works
/// - Threshold probability analysis works
/// - Error handling is robust
@Suite("Scenario Analysis Tool Tests")
struct ScenarioAnalysisToolTests {

    // MARK: - Helper Functions

    /// Helper to parse JSON into MCP.Value, then convert to AnyCodable arguments
    /// This matches how the actual MCP server processes JSON-RPC requests
    private func decodeArguments(_ json: String) throws -> [String: AnyCodable] {
        let data = json.data(using: .utf8)!

        // Decode JSON as MCP.Value (which handles nested structures properly)
        let decoder = JSONDecoder()
        let mcpValue = try decoder.decode(MCP.Value.self, from: data)

        // Convert MCP.Value to [String: AnyCodable]
        guard case .object(let dict) = mcpValue else {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "JSON must be an object"])
        }

        // Convert [String: MCP.Value] to [String: AnyCodable]
        var result: [String: AnyCodable] = [:]
        for (key, value) in dict {
            result[key] = AnyCodable(value)
        }

        return result
    }

    // MARK: - Phase 1: Tool Schema and Basic Execution

    @Test("Tool has correct name and required parameters")
    func testToolSchema() async throws {
        let tool = ScenarioAnalysisTool()

        #expect(tool.tool.name == "analyze_scenarios",
                "Tool should have correct name")

        let schema = tool.tool.inputSchema
        #expect(schema.required?.contains("inputNames") == true,
                "Schema should require inputNames")
        #expect(schema.required?.contains("model") == true,
                "Schema should require model")
        #expect(schema.required?.contains("iterations") == true,
                "Schema should require iterations")
        #expect(schema.required?.contains("scenarios") == true,
                "Schema should require scenarios")
    }

    @Test("Tool executes with simple two-scenario analysis")
    func testBasicExecution() async throws {
        let tool = ScenarioAnalysisTool()

        let json = """
        {
            "inputNames": ["Revenue", "Costs"],
            "model": "Revenue - Costs",
            "iterations": 1000,
            "scenarios": [
                {
                    "name": "Base Case",
                    "inputs": {
                        "Revenue": {"value": 1000000.0},
                        "Costs": {"value": 700000.0}
                    }
                },
                {
                    "name": "Best Case",
                    "inputs": {
                        "Revenue": {"value": 1200000.0},
                        "Costs": {"value": 600000.0}
                    }
                }
            ]
        }
        """

        let arguments = try decodeArguments(json)
        let result = try await tool.execute(arguments: arguments)

        #expect(!result.isError, "Tool execution should succeed")
        let text = result.text

        #expect(text.contains("Scenario Analysis Results"), "Should have results header")
        #expect(text.contains("Base Case"), "Should show Base Case scenario")
        #expect(text.contains("Best Case"), "Should show Best Case scenario")
        #expect(text.contains("Mean:"), "Should show mean values")
    }

    // MARK: - Phase 2: setValue vs setDistribution

    @Test("Tool handles fixed values with setValue")
    func testSetValue() async throws {
        let tool = ScenarioAnalysisTool()

        let json = """
        {
            "inputNames": ["Revenue"],
            "model": "Revenue",
            "iterations": 100,
            "scenarios": [
                {
                    "name": "Fixed Revenue",
                    "inputs": {
                        "Revenue": {"value": 1000000.0}
                    }
                }
            ]
        }
        """

        let arguments = try decodeArguments(json)
        let result = try await tool.execute(arguments: arguments)

        #expect(!result.isError, "Tool execution should succeed")
        let text = result.text

        // With fixed value, std dev should be very close to zero (or exactly zero)
        #expect(text.contains("Std Dev: 0.00"), "Fixed value should have zero standard deviation")
    }

    @Test("Tool handles distributions with setDistribution")
    func testSetDistribution() async throws {
        let tool = ScenarioAnalysisTool()

        let json = """
        {
            "inputNames": ["Revenue"],
            "model": "Revenue",
            "iterations": 5000,
            "scenarios": [
                {
                    "name": "Uncertain Revenue",
                    "inputs": {
                        "Revenue": {
                            "distribution": {
                                "type": "normal",
                                "mean": 1000000.0,
                                "stdDev": 100000.0
                            }
                        }
                    }
                }
            ]
        }
        """

        let arguments = try decodeArguments(json)
        let result = try await tool.execute(arguments: arguments)

        #expect(!result.isError, "Tool execution should succeed")
        let text = result.text

        // With distribution, std dev should be non-zero
        #expect(!text.contains("Std Dev: 0.00"), "Distribution should have non-zero standard deviation")
        #expect(text.contains("Std Dev:"), "Should show standard deviation")
    }

    @Test("Tool handles mixed fixed values and distributions")
    func testMixedInputs() async throws {
        let tool = ScenarioAnalysisTool()

        let json = """
        {
            "inputNames": ["Revenue", "FixedCost", "VariableCost"],
            "model": "Revenue - FixedCost - VariableCost",
            "iterations": 2000,
            "scenarios": [
                {
                    "name": "Mixed Scenario",
                    "inputs": {
                        "Revenue": {
                            "distribution": {
                                "type": "normal",
                                "mean": 1000000.0,
                                "stdDev": 50000.0
                            }
                        },
                        "FixedCost": {"value": 300000.0},
                        "VariableCost": {
                            "distribution": {
                                "type": "uniform",
                                "min": 200000.0,
                                "max": 400000.0
                            }
                        }
                    }
                }
            ]
        }
        """

        let arguments = try decodeArguments(json)
        let result = try await tool.execute(arguments: arguments)

        #expect(!result.isError, "Tool execution should succeed")
        let text = result.text

        #expect(text.contains("Mixed Scenario"), "Should show scenario name")
        #expect(text.contains("Mean:"), "Should calculate statistics")
    }

    // MARK: - Phase 3: Distribution Types

    @Test("Tool supports normal distribution")
    func testNormalDistribution() async throws {
        let tool = ScenarioAnalysisTool()

        let json = """
        {
            "inputNames": ["Value"],
            "model": "Value",
            "iterations": 5000,
            "scenarios": [
                {
                    "name": "Normal",
                    "inputs": {
                        "Value": {
                            "distribution": {
                                "type": "normal",
                                "mean": 100.0,
                                "stdDev": 15.0
                            }
                        }
                    }
                }
            ]
        }
        """

        let arguments = try decodeArguments(json)
        let result = try await tool.execute(arguments: arguments)

        #expect(!result.isError, "Normal distribution should work")
    }

    @Test("Tool supports uniform distribution")
    func testUniformDistribution() async throws {
        let tool = ScenarioAnalysisTool()

        let json = """
        {
            "inputNames": ["Value"],
            "model": "Value",
            "iterations": 5000,
            "scenarios": [
                {
                    "name": "Uniform",
                    "inputs": {
                        "Value": {
                            "distribution": {
                                "type": "uniform",
                                "min": 50.0,
                                "max": 150.0
                            }
                        }
                    }
                }
            ]
        }
        """

        let arguments = try decodeArguments(json)
        let result = try await tool.execute(arguments: arguments)

        #expect(!result.isError, "Uniform distribution should work")
    }

    @Test("Tool supports triangular distribution")
    func testTriangularDistribution() async throws {
        let tool = ScenarioAnalysisTool()

        let json = """
        {
            "inputNames": ["Value"],
            "model": "Value",
            "iterations": 5000,
            "scenarios": [
                {
                    "name": "Triangular",
                    "inputs": {
                        "Value": {
                            "distribution": {
                                "type": "triangular",
                                "min": 50.0,
                                "mode": 100.0,
                                "max": 150.0
                            }
                        }
                    }
                }
            ]
        }
        """

        let arguments = try decodeArguments(json)
        let result = try await tool.execute(arguments: arguments)

        #expect(!result.isError, "Triangular distribution should work")
    }

    // MARK: - Phase 4: Scenario Comparison

    @Test("Tool identifies best and worst scenarios")
    func testBestWorstIdentification() async throws {
        let tool = ScenarioAnalysisTool()

        let json = """
        {
            "inputNames": ["Profit"],
            "model": "Profit",
            "iterations": 1000,
            "scenarios": [
                {
                    "name": "Good",
                    "inputs": {
                        "Profit": {"value": 500000.0}
                    }
                },
                {
                    "name": "Bad",
                    "inputs": {
                        "Profit": {"value": 100000.0}
                    }
                },
                {
                    "name": "Excellent",
                    "inputs": {
                        "Profit": {"value": 800000.0}
                    }
                }
            ]
        }
        """

        let arguments = try decodeArguments(json)
        let result = try await tool.execute(arguments: arguments)

        #expect(!result.isError, "Tool execution should succeed")
        let text = result.text

        #expect(text.contains("Scenario Comparison"), "Should have comparison section")
        #expect(text.contains("Best/Worst"), "Should identify best/worst")

        // The best should be "Excellent" with 800,000
        #expect(text.contains("Best: Excellent"), "Should identify Excellent as best")
        #expect(text.contains("Worst: Bad"), "Should identify Bad as worst")
    }

    // MARK: - Phase 5: Threshold Analysis

    @Test("Tool calculates threshold probabilities")
    func testThresholdAnalysis() async throws {
        let tool = ScenarioAnalysisTool()

        let json = """
        {
            "inputNames": ["Income"],
            "model": "Income",
            "iterations": 5000,
            "scenarios": [
                {
                    "name": "Uncertain Income",
                    "inputs": {
                        "Income": {
                            "distribution": {
                                "type": "normal",
                                "mean": 100000.0,
                                "stdDev": 20000.0
                            }
                        }
                    }
                }
            ],
            "thresholds": [0.0, 100000.0]
        }
        """

        let arguments = try decodeArguments(json)
        let result = try await tool.execute(arguments: arguments)

        #expect(!result.isError, "Tool execution should succeed")
        let text = result.text

        #expect(text.contains("Probability Analysis"), "Should have probability analysis section")
        #expect(text.contains("Probability of Exceeding"), "Should show threshold probabilities")
    }

    // MARK: - Phase 6: Complex Business Model

    @Test("Tool handles realistic stress test scenario")
    func testStressTestScenario() async throws {
        let tool = ScenarioAnalysisTool()

        // Based on Part4-Simulation.md stress test example
        let json = """
        {
            "inputNames": ["Volume", "Price", "COGSMargin", "OpEx", "InterestRate"],
            "model": "Volume * Price * (1 - COGSMargin) - OpEx - (2000000 * InterestRate)",
            "iterations": 2000,
            "scenarios": [
                {
                    "name": "Base Case",
                    "inputs": {
                        "Volume": {
                            "distribution": {
                                "type": "normal",
                                "mean": 50000.0,
                                "stdDev": 2500.0
                            }
                        },
                        "Price": {
                            "distribution": {
                                "type": "normal",
                                "mean": 25.0,
                                "stdDev": 1.0
                            }
                        },
                        "COGSMargin": {"value": 0.45},
                        "OpEx": {"value": 350000.0},
                        "InterestRate": {"value": 0.05}
                    }
                },
                {
                    "name": "Recession",
                    "inputs": {
                        "Volume": {
                            "distribution": {
                                "type": "normal",
                                "mean": 35000.0,
                                "stdDev": 5000.0
                            }
                        },
                        "Price": {
                            "distribution": {
                                "type": "normal",
                                "mean": 22.0,
                                "stdDev": 2.0
                            }
                        },
                        "COGSMargin": {
                            "distribution": {
                                "type": "normal",
                                "mean": 0.50,
                                "stdDev": 0.03
                            }
                        },
                        "OpEx": {"value": 320000.0},
                        "InterestRate": {
                            "distribution": {
                                "type": "normal",
                                "mean": 0.08,
                                "stdDev": 0.01
                            }
                        }
                    }
                }
            ],
            "thresholds": [0.0, 100000.0]
        }
        """

        let arguments = try decodeArguments(json)
        let result = try await tool.execute(arguments: arguments)

        #expect(!result.isError, "Stress test should execute successfully")
        let text = result.text

        #expect(text.contains("Base Case"), "Should show Base Case")
        #expect(text.contains("Recession"), "Should show Recession")
        #expect(text.contains("Probability Analysis"), "Should show threshold analysis")
        #expect(text.contains("Risk-Adjusted Metrics"), "Should show risk metrics")
    }

    // MARK: - Phase 7: Error Handling

    @Test("Tool rejects empty scenarios")
    func testEmptyScenarios() async throws {
        let tool = ScenarioAnalysisTool()

        let json = """
        {
            "inputNames": ["Revenue"],
            "model": "Revenue",
            "iterations": 1000,
            "scenarios": []
        }
        """

        let arguments = try decodeArguments(json)

        do {
            let result = try await tool.execute(arguments: arguments)
            #expect(result.isError, "Should error on empty scenarios")
        } catch {
            #expect(true, "Should throw error on empty scenarios")
        }
    }

    @Test("Tool rejects missing input configuration")
    func testMissingInputConfiguration() async throws {
        let tool = ScenarioAnalysisTool()

        let json = """
        {
            "inputNames": ["Revenue", "Costs"],
            "model": "Revenue - Costs",
            "iterations": 1000,
            "scenarios": [
                {
                    "name": "Incomplete",
                    "inputs": {
                        "Revenue": {"value": 1000000.0}
                    }
                }
            ]
        }
        """

        let arguments = try decodeArguments(json)

        do {
            let result = try await tool.execute(arguments: arguments)
            // Should either error or throw
            if !result.isError {
                Issue.record("Should have detected missing input configuration")
            }
        } catch {
            #expect(true, "Should throw error on missing input")
        }
    }

    @Test("Tool rejects invalid distribution parameters")
    func testInvalidDistributionParams() async throws {
        let tool = ScenarioAnalysisTool()

        let json = """
        {
            "inputNames": ["Value"],
            "model": "Value",
            "iterations": 1000,
            "scenarios": [
                {
                    "name": "Bad Distribution",
                    "inputs": {
                        "Value": {
                            "distribution": {
                                "type": "normal",
                                "mean": 100.0,
                                "stdDev": -10.0
                            }
                        }
                    }
                }
            ]
        }
        """

        let arguments = try decodeArguments(json)

        do {
            let result = try await tool.execute(arguments: arguments)
            #expect(result.isError, "Should error on negative std dev")
        } catch {
            #expect(true, "Should throw error on invalid parameters")
        }
    }

    @Test("Tool rejects invalid iterations")
    func testInvalidIterations() async throws {
        let tool = ScenarioAnalysisTool()

        let json = """
        {
            "inputNames": ["Revenue"],
            "model": "Revenue",
            "iterations": 0,
            "scenarios": [
                {
                    "name": "Test",
                    "inputs": {
                        "Revenue": {"value": 1000000.0}
                    }
                }
            ]
        }
        """

        let arguments = try decodeArguments(json)

        do {
            let result = try await tool.execute(arguments: arguments)
            #expect(result.isError, "Should error on zero iterations")
        } catch {
            #expect(true, "Should throw error on invalid iterations")
        }
    }

    // MARK: - Phase 8: Output Format

    @Test("Tool returns structured output with all sections")
    func testOutputFormat() async throws {
        let tool = ScenarioAnalysisTool()

        let json = """
        {
            "inputNames": ["Revenue"],
            "model": "Revenue",
            "iterations": 1000,
            "scenarios": [
                {
                    "name": "Scenario A",
                    "inputs": {
                        "Revenue": {
                            "distribution": {
                                "type": "normal",
                                "mean": 100000.0,
                                "stdDev": 10000.0
                            }
                        }
                    }
                }
            ],
            "thresholds": [0.0]
        }
        """

        let arguments = try decodeArguments(json)
        let result = try await tool.execute(arguments: arguments)

        #expect(!result.isError, "Tool execution should succeed")
        let text = result.text

        // Verify all required sections
        #expect(text.contains("Scenario Analysis Results"), "Should have header")
        #expect(text.contains("Configuration:"), "Should show configuration")
        #expect(text.contains("Scenario Statistics"), "Should have statistics section")
        #expect(text.contains("Scenario Comparison"), "Should have comparison section")
        #expect(text.contains("Probability Analysis"), "Should have probability section")
        #expect(text.contains("Risk-Adjusted Metrics"), "Should have risk metrics")
        #expect(text.contains("Interpretation:"), "Should have interpretation")
    }
}

// Note: MCPToolCallResult extension is defined in MeanVariancePortfolioToolTests.swift
// and shared across all MCP tool tests

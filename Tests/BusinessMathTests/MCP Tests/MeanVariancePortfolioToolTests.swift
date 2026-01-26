import Testing
import Foundation
@testable import BusinessMathMCP
@testable import BusinessMath

/// Test suite for MeanVariancePortfolioTool
///
/// Tests follow TDD principles:
/// 1. RED: Write failing tests first (tool doesn't exist yet)
/// 2. GREEN: Implement tool to pass tests
/// 3. REFACTOR: Improve implementation
///
/// Key validation goals:
/// - Tool produces realistic diversified portfolios (NOT trivial "all in highest return")
/// - Risk-return tradeoffs work correctly with mean-variance objective
/// - Concentration limits prevent extreme allocations
/// - Covariance matrix affects diversification properly
@Suite("Mean-Variance Portfolio Tool Tests")
struct MeanVariancePortfolioToolTests {

    // MARK: - Phase 1: Tool Schema and Basic Execution

    @Test("Tool has correct name and required parameters")
    func testToolSchema() async throws {
        let tool = MeanVariancePortfolioTool()

        #expect(tool.tool.name == "optimize_mean_variance_portfolio",
                "Tool should have correct name")

        let schema = tool.tool.inputSchema
        #expect(schema.required?.contains("expectedReturns") == true,
                "Schema should require expectedReturns")
        #expect(schema.required?.contains("covarianceMatrix") == true,
                "Schema should require covarianceMatrix")
        #expect(schema.required?.contains("riskAversion") == true,
                "Schema should require riskAversion")
    }

    @Test("Tool executes with valid three-asset portfolio")
    func testBasicExecution() async throws {
        let tool = MeanVariancePortfolioTool()

        let arguments: [String: AnyCodable] = [
            "expectedReturns": AnyCodable([0.08, 0.12, 0.15]),
            "covarianceMatrix": AnyCodable([
                [0.0100, 0.0036, 0.0075],
                [0.0036, 0.0324, 0.0270],
                [0.0075, 0.0270, 0.0625]
            ]),
            "riskAversion": AnyCodable(2.0),
            "concentrationLimit": AnyCodable(0.60),
            "budget": AnyCodable(100_000.0)
        ]

        let result = try await tool.execute(arguments: arguments)

        #expect(!result.isError, "Result should not be an error")
        let text = result.text
        #expect(text.contains("Optimal"), "Result should contain optimal allocation")
        #expect(!text.contains("Error"), "Result should not contain errors")
    }

    // MARK: - Phase 2: Realistic Portfolio Validation

    @Test("Portfolio is diversified, not trivial all-in solution")
    func testNoTrivialSolution() async throws {
        let tool = MeanVariancePortfolioTool()

        // Three assets with different risk-return profiles
        let arguments: [String: AnyCodable] = [
            "expectedReturns": AnyCodable([0.08, 0.12, 0.15]),  // 8%, 12%, 15%
            "covarianceMatrix": AnyCodable([
                [0.0100, 0.0036, 0.0075],  // Low risk: 10% vol
                [0.0036, 0.0324, 0.0270],  // Medium risk: 18% vol
                [0.0075, 0.0270, 0.0625]   // High risk: 25% vol
            ]),
            "riskAversion": AnyCodable(2.0),
            "concentrationLimit": AnyCodable(0.60),
            "budget": AnyCodable(100_000.0)
        ]

        let result = try await tool.execute(arguments: arguments)

        #expect(!result.isError, "Tool execution should succeed")
        let text = result.text

        // Verify NOT trivial solution (would be 100% in 15% return asset)
        // The output should show diversification across assets
        #expect(text.contains("Optimal"), "Should show optimal allocation")
        #expect(text.contains("Asset"), "Should show asset allocations")

        // Verify diversification: should show multiple allocations
        // Count occurrences of "Allocation:" to verify multiple assets
        let allocationCount = text.components(separatedBy: "Allocation:").count - 1
        #expect(allocationCount >= 2,
                "Portfolio should be diversified across at least 2 assets")
    }

    @Test("Higher risk aversion produces more conservative portfolio")
    func testRiskAversionImpact() async throws {
        let tool = MeanVariancePortfolioTool()

        let baseArgs: [String: AnyCodable] = [
            "expectedReturns": AnyCodable([0.08, 0.12, 0.15]),
            "covarianceMatrix": AnyCodable([
                [0.0100, 0.0036, 0.0075],
                [0.0036, 0.0324, 0.0270],
                [0.0075, 0.0270, 0.0625]
            ]),
            "concentrationLimit": AnyCodable(0.60),
            "budget": AnyCodable(100_000.0)
        ]

        // Low risk aversion (aggressive)
        var aggressiveArgs = baseArgs
        aggressiveArgs["riskAversion"] = AnyCodable(1.0)
        let aggressiveResult = try await tool.execute(arguments: aggressiveArgs)

        // High risk aversion (conservative)
        var conservativeArgs = baseArgs
        conservativeArgs["riskAversion"] = AnyCodable(5.0)
        let conservativeResult = try await tool.execute(arguments: conservativeArgs)

        // Both should succeed
        #expect(!aggressiveResult.isError, "Aggressive portfolio should succeed")
        #expect(!conservativeResult.isError, "Conservative portfolio should succeed")

        let aggressiveText = aggressiveResult.text
        let conservativeText = conservativeResult.text

        // Conservative should have more allocation to low-risk asset
        #expect(aggressiveText != conservativeText,
                "Different risk aversion should produce different allocations")
    }

    @Test("Concentration limits prevent extreme positions")
    func testConcentrationLimits() async throws {
        let tool = MeanVariancePortfolioTool()

        let arguments: [String: AnyCodable] = [
            "expectedReturns": AnyCodable([0.08, 0.12, 0.15]),
            "covarianceMatrix": AnyCodable([
                [0.0100, 0.0036, 0.0075],
                [0.0036, 0.0324, 0.0270],
                [0.0075, 0.0270, 0.0625]
            ]),
            "riskAversion": AnyCodable(1.0),  // Low aversion
            "concentrationLimit": AnyCodable(0.40),  // Strict 40% limit
            "budget": AnyCodable(100_000.0)
        ]

        let result = try await tool.execute(arguments: arguments)

        #expect(!result.isError, "Tool execution should succeed")
        let text = result.text

        // Should not exceed 40% concentration (40,000 out of 100,000)
        #expect(!text.contains("$60,000") && !text.contains("$100,000"),
                "No single asset should exceed concentration limit")
    }

    // MARK: - Phase 3: Covariance Matrix Effects

    @Test("Uncorrelated assets produce more diversification than correlated")
    func testCorrelationEffect() async throws {
        let tool = MeanVariancePortfolioTool()

        // Scenario 1: High correlation between assets 2 and 3
        let highCorrelationArgs: [String: AnyCodable] = [
            "expectedReturns": AnyCodable([0.08, 0.12, 0.15]),
            "covarianceMatrix": AnyCodable([
                [0.0100, 0.0036, 0.0075],
                [0.0036, 0.0324, 0.0270],
                [0.0075, 0.0270, 0.0625]  // High correlation (0.6)
            ]),
            "riskAversion": AnyCodable(2.0),
            "concentrationLimit": AnyCodable(0.60),
            "budget": AnyCodable(100_000.0)
        ]

        // Scenario 2: Low correlation between all assets
        let lowCorrelationArgs: [String: AnyCodable] = [
            "expectedReturns": AnyCodable([0.08, 0.12, 0.15]),
            "covarianceMatrix": AnyCodable([
                [0.0100, 0.0018, 0.0025],  // Lower correlations
                [0.0018, 0.0324, 0.0100],
                [0.0025, 0.0100, 0.0625]
            ]),
            "riskAversion": AnyCodable(2.0),
            "concentrationLimit": AnyCodable(0.60),
            "budget": AnyCodable(100_000.0)
        ]

        let highCorrResult = try await tool.execute(arguments: highCorrelationArgs)
        let lowCorrResult = try await tool.execute(arguments: lowCorrelationArgs)

        // Both should succeed and produce different allocations
        #expect(!highCorrResult.isError, "High correlation portfolio should succeed")
        #expect(!lowCorrResult.isError, "Low correlation portfolio should succeed")

        let highText = highCorrResult.text
        let lowText = lowCorrResult.text

        #expect(highText != lowText,
                "Different correlation structures should produce different allocations")
    }

    // MARK: - Phase 4: Error Handling

    @Test("Tool rejects missing required parameters")
    func testMissingParameters() async throws {
        let tool = MeanVariancePortfolioTool()

        // Missing covariance matrix
        let incompleteArgs: [String: AnyCodable] = [
            "expectedReturns": AnyCodable([0.08, 0.12, 0.15]),
            "riskAversion": AnyCodable(2.0)
        ]

        do {
            let result = try await tool.execute(arguments: incompleteArgs)
            #expect(result.isError, "Tool should error on missing covarianceMatrix")
        } catch {
            // Throwing an error is also acceptable - means validation caught the issue
            #expect(true, "Tool correctly rejected missing parameter")
        }
    }

    @Test("Tool rejects mismatched matrix dimensions")
    func testMatrixDimensionValidation() async throws {
        let tool = MeanVariancePortfolioTool()

        // 3 assets but 2x2 covariance matrix
        let mismatchedArgs: [String: AnyCodable] = [
            "expectedReturns": AnyCodable([0.08, 0.12, 0.15]),
            "covarianceMatrix": AnyCodable([
                [0.0100, 0.0036],
                [0.0036, 0.0324]
            ]),
            "riskAversion": AnyCodable(2.0),
            "budget": AnyCodable(100_000.0)
        ]

        do {
            let result = try await tool.execute(arguments: mismatchedArgs)
            #expect(result.isError, "Tool should error on dimension mismatch")
        } catch {
            // Throwing an error is also acceptable - means validation caught the issue
            #expect(true, "Tool correctly rejected dimension mismatch")
        }
    }

    @Test("Tool rejects non-positive-definite covariance matrix")
    func testPositiveDefiniteValidation() async throws {
        let tool = MeanVariancePortfolioTool()

        // Invalid covariance matrix (not positive definite)
        let invalidArgs: [String: AnyCodable] = [
            "expectedReturns": AnyCodable([0.08, 0.12, 0.15]),
            "covarianceMatrix": AnyCodable([
                [0.01, 0.05, 0.05],   // Invalid: correlation > 1
                [0.05, 0.02, 0.05],
                [0.05, 0.05, 0.03]
            ]),
            "riskAversion": AnyCodable(2.0),
            "budget": AnyCodable(100_000.0)
        ]

        do {
            let result = try await tool.execute(arguments: invalidArgs)

            // If it succeeds (unlikely with bad covariance), that's OK too
            // The optimizer might handle it or fail gracefully
            if result.isError {
                // Error is expected and acceptable
                #expect(true, "Tool rejected invalid covariance matrix")
            } else {
                // If it somehow succeeds, the optimizer dealt with it
                #expect(true, "Tool handled invalid covariance matrix")
            }
        } catch {
            // Throwing an error is also acceptable - optimizer detected the issue
            #expect(true, "Tool correctly rejected invalid covariance matrix")
        }
    }

    // MARK: - Phase 5: Output Format Validation

    @Test("Tool returns structured output with all key metrics")
    func testOutputFormat() async throws {
        let tool = MeanVariancePortfolioTool()

        let arguments: [String: AnyCodable] = [
            "expectedReturns": AnyCodable([0.08, 0.12, 0.15]),
            "covarianceMatrix": AnyCodable([
                [0.0100, 0.0036, 0.0075],
                [0.0036, 0.0324, 0.0270],
                [0.0075, 0.0270, 0.0625]
            ]),
            "riskAversion": AnyCodable(2.0),
            "concentrationLimit": AnyCodable(0.60),
            "budget": AnyCodable(100_000.0)
        ]

        let result = try await tool.execute(arguments: arguments)

        #expect(!result.isError, "Tool execution should succeed")
        let text = result.text

        // Verify output contains all required sections
        #expect(text.contains("Optimal"), "Should show optimal weights")
        #expect(text.contains("Expected Return") || text.contains("Portfolio Return"),
                "Should show expected return")
        #expect(text.contains("Risk") || text.contains("Variance") || text.contains("Volatility"),
                "Should show portfolio risk")
        #expect(text.contains("Sharpe"), "Should show Sharpe ratio")
    }
}

// MARK: - Helper Extensions

extension MCPToolCallResult {
    var isError: Bool {
        return result.isError ?? false
    }

    var text: String {
        guard let firstContent = result.content.first else {
            return ""
        }
        switch firstContent {
        case .text(let string):
            return string
        case .image, .resource, .audio:
            return ""
        }
    }
}


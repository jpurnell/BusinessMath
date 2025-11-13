//
//  BayesianTools.swift
//  BusinessMath MCP Server
//
//  Bayesian inference tools for BusinessMath MCP Server
//

import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - Tool Registration

/// Returns all Bayesian statistics tools
public func getBayesianTools() -> [any MCPToolHandler] {
    return [
        BayesTheoremTool()
    ]
}

// MARK: - Helper Functions

/// Format a probability as percentage
private func formatProbability(_ value: Double, decimals: Int = 2) -> String {
    return (value * 100).formatDecimal(decimals: decimals) + "%"
}

/// Format a number with specified decimal places
private func formatNumber(_ value: Double, decimals: Int = 2) -> String {
    return value.formatDecimal(decimals: decimals)
}

// MARK: - Bayes' Theorem

public struct BayesTheoremTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_bayes_theorem",
        description: """
        Calculate posterior probability using Bayes' Theorem.

        Bayes' Theorem updates the probability of an event based on new evidence.
        It's fundamental to probabilistic reasoning and decision-making under uncertainty.

        Formula: P(D|T) = [P(T|D) × P(D)] / [P(T|D) × P(D) + P(T|¬D) × P(¬D)]

        Where:
        • P(D) = Prior probability of event D
        • P(T|D) = Probability of observing T given D is true (true positive rate)
        • P(T|¬D) = Probability of observing T given D is false (false positive rate)
        • P(D|T) = Posterior probability of D given T (what we're solving for)

        Common Applications:
        • Medical diagnosis (disease probability given test result)
        • Spam filtering (spam probability given email features)
        • Quality control (defect probability given inspection)
        • Credit risk (default probability given financial indicators)
        • A/B testing (hypothesis probability given data)

        Example 1 - Medical Test:
        Disease prevalence: 1% (prior)
        True positive rate: 99% (sensitivity)
        False positive rate: 2% (1 - specificity)
        Result: ~33% chance of disease given positive test

        Example 2 - Spam Filter:
        Spam rate: 30% (prior)
        Contains "free": 80% in spam, 5% in legitimate
        Result: ~90% spam probability if email contains "free"

        This tool helps make better decisions by properly incorporating base rates (priors)
        with new evidence, avoiding common probability fallacies.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "priorProbability": MCPSchemaProperty(
                    type: "number",
                    description: "Prior probability P(D) - base rate before new evidence (0 to 1)"
                ),
                "truePositiveRate": MCPSchemaProperty(
                    type: "number",
                    description: "P(T|D) - probability of positive result when event is true (sensitivity, 0 to 1)"
                ),
                "falsePositiveRate": MCPSchemaProperty(
                    type: "number",
                    description: "P(T|¬D) - probability of positive result when event is false (1-specificity, 0 to 1)"
                ),
                "eventName": MCPSchemaProperty(
                    type: "string",
                    description: "Optional name for the event (e.g., 'Disease', 'Spam', 'Default')"
                ),
                "testName": MCPSchemaProperty(
                    type: "string",
                    description: "Optional name for the test/evidence (e.g., 'Medical Test', 'Contains keyword')"
                )
            ],
            required: ["priorProbability", "truePositiveRate", "falsePositiveRate"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let prior = try args.getDouble("priorProbability")
        let truePositive = try args.getDouble("truePositiveRate")
        let falsePositive = try args.getDouble("falsePositiveRate")

        let eventName = args.getStringOptional("eventName") ?? "Event"
        let testName = args.getStringOptional("testName") ?? "Test"

        // Validate probabilities are between 0 and 1
        guard (0...1).contains(prior) else {
            throw ToolError.invalidArguments("Prior probability must be between 0 and 1")
        }
        guard (0...1).contains(truePositive) else {
            throw ToolError.invalidArguments("True positive rate must be between 0 and 1")
        }
        guard (0...1).contains(falsePositive) else {
            throw ToolError.invalidArguments("False positive rate must be between 0 and 1")
        }

        // Calculate posterior using Bayes' theorem
        let posterior: Double = bayes(prior, truePositive, falsePositive)

        // Calculate supporting statistics
        let priorOdds = prior / (1 - prior)
        let posteriorOdds = posterior / (1 - posterior)
        let likelihoodRatio = truePositive / falsePositive
        let oddsMultiplier = posteriorOdds / priorOdds

        // Calculate complementary probabilities
        let trueNegative = 1 - falsePositive  // Specificity
        let falseNegative = 1 - truePositive  // 1 - Sensitivity

        // Probability of positive test
        let probPositiveTest = truePositive * prior + falsePositive * (1 - prior)

        // Interpretation
        let change = posterior - prior
        let changeDescription: String
        if change > 0.20 {
            changeDescription = "Substantial increase"
        } else if change > 0.05 {
            changeDescription = "Moderate increase"
        } else if change > 0 {
            changeDescription = "Slight increase"
        } else if change > -0.05 {
            changeDescription = "Slight decrease"
        } else if change > -0.20 {
            changeDescription = "Moderate decrease"
        } else {
            changeDescription = "Substantial decrease"
        }

        let output = """
        Bayes' Theorem Analysis: \(eventName) Given \(testName)

        Prior Probability:
        • P(\(eventName)): \(formatProbability(prior))
        • Before seeing test result, \(formatProbability(prior)) chance of \(eventName.lowercased())

        Test Characteristics:
        • Sensitivity (True Positive Rate): \(formatProbability(truePositive))
        • Specificity (True Negative Rate): \(formatProbability(trueNegative))
        • False Positive Rate: \(formatProbability(falsePositive))
        • False Negative Rate: \(formatProbability(falseNegative))

        Calculation:
        • P(Positive \(testName)): \(formatProbability(probPositiveTest))
        • Likelihood Ratio: \(formatNumber(likelihoodRatio, decimals: 2))x

        Result - Posterior Probability:
        • P(\(eventName) | Positive \(testName)): \(formatProbability(posterior))
        • Given a positive test result, there is a \(formatProbability(posterior)) chance of \(eventName.lowercased())

        Analysis:
        • Change from Prior: \(change >= 0 ? "+" : "")\(formatProbability(abs(change))) (\(changeDescription))
        • Prior Odds: \(formatNumber(priorOdds, decimals: 2)):1
        • Posterior Odds: \(formatNumber(posteriorOdds, decimals: 2)):1
        • Odds Multiplier: \(formatNumber(oddsMultiplier, decimals: 2))x

        Interpretation:
        \(posterior > 0.75 ? "• High probability - Strong evidence for \(eventName.lowercased())" :
          posterior > 0.50 ? "• More likely than not - Moderate evidence for \(eventName.lowercased())" :
          posterior > 0.25 ? "• Unlikely but possible - Weak evidence for \(eventName.lowercased())" :
          "• Low probability - Evidence against \(eventName.lowercased())")

        \(prior < 0.10 && posterior < 0.50 ? """

        Note: Low base rate (\(formatProbability(prior))) significantly affects results.
        Even with a positive test, the probability remains moderate due to the low prior.
        This is why screening rare conditions requires highly specific tests.
        """ : "")
        """

        return .success(text: output)
    }
}

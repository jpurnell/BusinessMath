//
//  RiskMetrics.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

/// Extensions to SimulationResults providing risk metrics for financial analysis.
///
/// This extension adds Value at Risk (VaR) and Conditional Value at Risk (CVaR)
/// calculations to Monte Carlo simulation results, enabling comprehensive risk assessment.
///
/// ## Risk Metrics Overview
///
/// - **VaR (Value at Risk)**: The maximum expected loss at a given confidence level
/// - **CVaR (Conditional Value at Risk / Expected Shortfall)**: The expected loss given that the loss exceeds VaR
///
/// ## Use Cases
///
/// - Portfolio risk management
/// - Capital allocation decisions
/// - Regulatory compliance (Basel III)
/// - Risk-adjusted performance measurement
/// - Stress testing and scenario analysis
extension SimulationResults {

	// MARK: - Value at Risk (VaR)

	/// Calculates the Value at Risk (VaR) at a given confidence level.
	///
	/// VaR represents the maximum expected loss over a given time period at a specified confidence level.
	/// It answers the question: "What is the worst loss we can expect with X% confidence?"
	///
	/// ## How It Works
	///
	/// VaR is calculated as a percentile of the loss distribution:
	/// - 95% VaR = 5th percentile (95% confidence that losses won't exceed this)
	/// - 99% VaR = 1st percentile (99% confidence that losses won't exceed this)
	///
	/// ## Interpretation
	///
	/// - **Negative VaR**: Represents a loss (most common interpretation)
	/// - **Positive VaR**: Represents a gain (for profit distributions)
	/// - **Higher confidence → More extreme VaR**: 99% VaR is worse than 95% VaR
	///
	/// - Parameter confidenceLevel: The confidence level (0.0 to 1.0, e.g., 0.95 for 95% confidence)
	/// - Returns: The Value at Risk (negative for losses, positive for gains)
	///
	/// ## Example - Portfolio Risk
	///
	/// ```swift
	/// // Run portfolio return simulation
	/// var simulation = MonteCarloSimulation(iterations: 10_000) { inputs in
	///     let stockReturn = inputs[0]
	///     let bondReturn = inputs[1]
	///     return 0.6 * stockReturn + 0.4 * bondReturn  // 60/40 portfolio
	/// }
	///
	/// simulation.addInput(SimulationInput(name: "Stocks",
	///     distribution: DistributionNormal(mean: 0.12, stdDev: 0.20)))
	/// simulation.addInput(SimulationInput(name: "Bonds",
	///     distribution: DistributionNormal(mean: 0.04, stdDev: 0.05)))
	///
	/// let results = try simulation.run()
	///
	/// let var95 = results.valueAtRisk(confidenceLevel: 0.95)
	/// print("95% VaR: \(var95 * 100)%")
	/// print("We are 95% confident losses won't exceed \(abs(var95) * 100)%")
	/// ```
	///
	/// ## Example - Capital Requirement
	///
	/// ```swift
	/// // Calculate required capital for operational risk
	/// var simulation = MonteCarloSimulation(iterations: 10_000) { inputs in
	///     return inputs[0]  // Annual operational losses
	/// }
	///
	/// simulation.addInput(SimulationInput(name: "OpLoss",
	///     distribution: DistributionWeibull(shape: 1.5, scale: 1_000_000)))
	///
	/// let results = try simulation.run()
	///
	/// let var999 = results.valueAtRisk(confidenceLevel: 0.999)
	/// print("99.9% VaR: $\(abs(var999))")
	/// print("Capital required: $\(abs(var999))")
	/// ```
	public func valueAtRisk(confidenceLevel: Double) -> Double {
		// VaR is the percentile corresponding to (1 - confidence level)
		// For 95% confidence, we want the 5th percentile (alpha = 0.05)
		let alpha = 1.0 - confidenceLevel

		return calculatePercentile(alpha: alpha)
	}

	// MARK: - Conditional Value at Risk (CVaR)

	/// Calculates the Conditional Value at Risk (CVaR), also known as Expected Shortfall.
	///
	/// CVaR represents the expected loss given that the loss exceeds the VaR threshold.
	/// It answers the question: "If losses exceed our VaR, what is the expected loss?"
	///
	/// ## How It Works
	///
	/// CVaR is calculated as the average of all losses beyond the VaR threshold:
	/// 1. Calculate VaR at the given confidence level
	/// 2. Find all outcomes worse than VaR (in the tail)
	/// 3. Calculate the mean of these tail outcomes
	///
	/// ## Why CVaR Matters
	///
	/// CVaR addresses a key limitation of VaR:
	/// - **VaR** tells you the threshold but not how bad it gets beyond that
	/// - **CVaR** tells you the average loss in the worst cases
	/// - **CVaR is always ≥ VaR** (for losses, meaning more extreme/negative)
	/// - **CVaR is coherent**: Unlike VaR, it satisfies all axioms of coherent risk measures
	///
	/// ## Regulatory Context
	///
	/// CVaR is preferred by many regulators and risk managers because:
	/// - It considers tail risk severity, not just probability
	/// - It's subadditive (portfolio CVaR ≤ sum of individual CVaRs)
	/// - It encourages diversification
	///
	/// - Parameter confidenceLevel: The confidence level (0.0 to 1.0, e.g., 0.95 for 95% confidence)
	/// - Returns: The Conditional Value at Risk (negative for losses, positive for gains)
	///
	/// ## Example - Risk Comparison
	///
	/// ```swift
	/// let results = try simulation.run()
	///
	/// let var95 = results.valueAtRisk(confidenceLevel: 0.95)
	/// let cvar95 = results.conditionalValueAtRisk(confidenceLevel: 0.95)
	///
	/// print("95% VaR: $\(var95)")
	/// print("95% CVaR: $\(cvar95)")
	/// print("Tail risk severity: $\(cvar95 - var95)")
	/// ```
	///
	/// ## Example - Capital Allocation
	///
	/// ```swift
	/// // Compare risk of two business units
	/// let results1 = try simulation1.run()
	/// let results2 = try simulation2.run()
	///
	/// let cvar1 = results1.conditionalValueAtRisk(confidenceLevel: 0.99)
	/// let cvar2 = results2.conditionalValueAtRisk(confidenceLevel: 0.99)
	///
	/// // Allocate capital proportional to CVaR
	/// let totalCVaR = abs(cvar1) + abs(cvar2)
	/// let allocation1 = abs(cvar1) / totalCVaR
	/// let allocation2 = abs(cvar2) / totalCVaR
	///
	/// print("Unit 1 capital allocation: \(allocation1 * 100)%")
	/// print("Unit 2 capital allocation: \(allocation2 * 100)%")
	/// ```
	public func conditionalValueAtRisk(confidenceLevel: Double) -> Double {
		// CVaR is the mean of all outcomes in the tail beyond VaR
		let alpha = 1.0 - confidenceLevel
		let varThreshold = calculatePercentile(alpha: alpha)

		// Find all values in the tail (worse than VaR)
		let tailValues = values.filter { $0 <= varThreshold }

		// Return mean of tail values
		guard !tailValues.isEmpty else {
			return varThreshold  // Fallback: if no tail values, return VaR
		}

		let tailMean = mean(tailValues)
		return tailMean
	}

	// MARK: - Helper Methods

	/// Calculates a percentile from the simulation values.
	///
	/// Uses linear interpolation (R-7 / Type 7 method) consistent with the Percentiles struct.
	///
	/// - Parameter alpha: The percentile level (0.0 to 1.0)
	/// - Returns: The value at the specified percentile
	private func calculatePercentile(alpha: Double) -> Double {
		// Handle edge cases
		guard !values.isEmpty else { return 0.0 }
		if values.count == 1 { return values[0] }

		// Sort values
		let sortedValues = values.sorted()

		// Handle boundary cases
		if alpha <= 0.0 { return sortedValues.first! }
		if alpha >= 1.0 { return sortedValues.last! }

		// Linear interpolation (R-7 / Type 7 method)
		let n = Double(sortedValues.count)
		let position = (n - 1.0) * alpha

		let lowerIndex = Int(Foundation.floor(position))
		let upperIndex = Int(Foundation.ceil(position))

		// Ensure indices are within bounds
		let safeLowerIndex = Swift.max(0, Swift.min(lowerIndex, sortedValues.count - 1))
		let safeUpperIndex = Swift.max(0, Swift.min(upperIndex, sortedValues.count - 1))

		// If indices are the same, return that value
		if safeLowerIndex == safeUpperIndex {
			return sortedValues[safeLowerIndex]
		}

		// Interpolate between lower and upper values
		let lowerValue = sortedValues[safeLowerIndex]
		let upperValue = sortedValues[safeUpperIndex]
		let fraction = position - Double(lowerIndex)

		return lowerValue + fraction * (upperValue - lowerValue)
	}
}

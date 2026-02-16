//
//  RiskAggregation.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

/// Aggregates Value at Risk (VaR) across multiple entities in a portfolio.
///
/// `RiskAggregator` provides methods to combine individual entity risks into portfolio-level risk metrics,
/// accounting for correlations between entities. This is essential for understanding total portfolio risk
/// when positions are not independent.
///
/// The variance-covariance approach models portfolio VaR as:
/// ```
/// VaR(portfolio) = √(vᵀ C v)
/// ```
/// where:
/// - v = vector of individual VaR exposures
/// - C = correlation matrix between entities
/// - vᵀ = transpose of v
///
/// ## Key Concepts
///
/// ### Aggregate VaR
/// The total portfolio VaR accounting for diversification benefits. Lower than the sum of individual VaRs
/// when correlations are less than 1.0, reflecting diversification benefits.
///
/// ### Marginal VaR
/// The rate of change of portfolio VaR with respect to a small change in one entity's exposure.
/// Useful for capital allocation and determining which positions contribute most to risk at the margin.
///
/// ### Component VaR
/// The contribution of each entity to total portfolio VaR using Euler allocation. Components sum to
/// exactly the portfolio VaR, providing a complete risk decomposition.
///
/// ## Usage Example
///
/// ```swift
/// // Three trading desks with individual 95% VaR values
/// let individualVaRs: [Double] = [100_000, 80_000, 120_000]
///
/// // Correlation matrix between desks
/// let correlations: [[Double]] = [
///     [1.0, 0.6, 0.3],
///     [0.6, 1.0, 0.4],
///     [0.3, 0.4, 1.0]
/// ]
///
/// // Calculate aggregate portfolio VaR
/// let portfolioVaR = RiskAggregator.aggregateVaR(
///     individualVaRs: individualVaRs,
///     correlations: correlations
/// )
/// print("Portfolio VaR: \(portfolioVaR..currency(0))")
/// // Portfolio VaR: $212,803 (less than sum of $300,000 due to diversification)
///
/// // Calculate marginal contribution of desk 1
/// let marginal = RiskAggregator.marginalVaR(
///     entity: 0,
///     individualVaRs: individualVaRs,
///     correlations: correlations
/// )
/// print("Marginal VaR for Desk 1: $\(marginal.formatted(.number.precision(.fractionLength(2))))")
///
/// // Decompose portfolio VaR into components (equal-weighted portfolio)
/// let weights: [Double] = [1.0, 1.0, 1.0]
/// let components = RiskAggregator.componentVaR(
///     individualVaRs: individualVaRs,
///     weights: weights,
///     correlations: correlations
/// )
/// print("Component VaRs: \(components.map { $0.number(0)) })")
/// // Components sum to portfolio VaR
/// ```
///
/// ## Mathematical Background
///
/// The variance-covariance approach assumes returns are normally distributed (or have known
/// covariance structure). For a portfolio with exposure vector v:
///
/// ```
/// Variance(portfolio) = vᵀ C v
/// VaR(portfolio) = √(vᵀ C v)
/// ```
///
/// **Marginal VaR** (derivative with respect to exposure i):
/// ```
/// ∂VaR/∂vᵢ = (C v)ᵢ / VaR
/// ```
///
/// **Component VaR** (Euler allocation):
/// ```
/// componentᵢ = vᵢ × marginalᵢ = vᵢ × (C v)ᵢ / VaR
/// ```
///
/// The Euler allocation satisfies the property:
/// ```
/// Σ componentᵢ = VaR(portfolio)
/// ```
///
/// ## Important Considerations
///
/// - **Correlation Matrix**: Must be symmetric, positive semi-definite, and have 1.0 on the diagonal
/// - **VaR Units**: Individual VaR values should represent the same confidence level (e.g., all 95% VaR)
/// - **Time Horizon**: All VaR measures should use the same time horizon (e.g., 1-day VaR)
/// - **Distribution Assumptions**: This approach assumes multivariate normality or relies on historical correlations
///
/// - Note: All methods are static and thread-safe due to `Sendable` constraint on the generic type.
///
/// ## Topics
///
/// ### Portfolio Risk Aggregation
/// - ``aggregateVaR(individualVaRs:correlations:)``
///
/// ### Risk Attribution
/// - ``marginalVaR(entity:individualVaRs:correlations:)``
/// - ``componentVaR(individualVaRs:weights:correlations:)``
///
/// ## See Also
/// - ``ComprehensiveRiskMetrics``
/// - ``StressTest``
/// - ``Portfolio``
public struct RiskAggregator<T: Real & Sendable> {

	// MARK: - Aggregate VaR

	/// Aggregate VaR across entities using the variance-covariance approach.
	///
	/// Interprets `individualVaRs` as the exposure vector v (already in VaR units),
	/// and computes:
	/// VaR(v) = sqrt(vᵀ C v)
	public static func aggregateVaR(
		individualVaRs: [T],
		correlations: [[T]]
	) -> T {
		let n = individualVaRs.count
		precondition(correlations.count == n, "Correlation matrix must be n x n")
		precondition(correlations.allSatisfy { $0.count == n }, "Correlation matrix must be square")

		var totalVariance: T = 0
		// Compute vᵀ C v
		for i in 0..<n {
			for j in 0..<n {
				totalVariance += individualVaRs[i] * correlations[i][j] * individualVaRs[j]
			}
		}

		// Guard against tiny negative due to rounding (valid C should be PSD)
		if totalVariance < 0 && totalVariance > -T.ulpOfOne {
			totalVariance = 0
		}

		return T.sqrt(totalVariance)
	}

	// MARK: - Marginal VaR

	/// Marginal VaR with respect to the provided exposure vector `individualVaRs`.
	///
	/// Given v = `individualVaRs`, VaR = sqrt(vᵀ C v), the marginal contribution is:
	/// dVaR/dv_i = (C v)_i / VaR
	///
	/// This is a true marginal (derivative). The Euler component is v_i * marginal_i.
	public static func marginalVaR(
		entity: Int,
		individualVaRs: [T],
		correlations: [[T]]
	) -> T {
		let n = individualVaRs.count
		precondition(entity >= 0 && entity < n, "Entity index out of bounds")
		precondition(correlations.count == n && correlations.allSatisfy { $0.count == n }, "Correlation matrix must be n x n")

		let portfolioVaR = aggregateVaR(individualVaRs: individualVaRs, correlations: correlations)
		// If portfolioVaR is zero, derivative is undefined; return 0 to avoid NaN.
		if portfolioVaR == 0 { return 0 }

		// Compute (C v)_i
		var Cv_i: T = 0
		for j in 0..<n {
			Cv_i += correlations[entity][j] * individualVaRs[j]
		}

		return Cv_i / portfolioVaR
	}

	// MARK: - Component VaR

	/// Component VaR for each entity using Euler allocation.
	///
	/// Forms exposure vector v = weights .* individualVaRs, computes:
	/// component_i = v_i × (C v)_i / VaR
	/// and returns the vector of components. Sum of components equals portfolio VaR.
	public static func componentVaR(
		individualVaRs: [T],
		weights: [T],
		correlations: [[T]]
	) -> [T] {
		let n = individualVaRs.count
		precondition(weights.count == n, "Weights must match number of entities")
		precondition(correlations.count == n && correlations.allSatisfy { $0.count == n }, "Correlation matrix must be n x n")

		// v = weights .* individualVaRs
		var v = [T](repeating: 0, count: n)
		for i in 0..<n {
			v[i] = weights[i] * individualVaRs[i]
		}

		let portfolioVaR = aggregateVaR(individualVaRs: v, correlations: correlations)
		if portfolioVaR == 0 {
			// All components are zero if portfolio VaR is zero
			return [T](repeating: 0, count: n)
		}

		// Compute C v
		var Cv = [T](repeating: 0, count: n)
		for i in 0..<n {
			var sum: T = 0
			for j in 0..<n {
				sum += correlations[i][j] * v[j]
			}
			Cv[i] = sum
		}

		// Euler components: v_i * (C v)_i / VaR
		var components = [T](repeating: 0, count: n)
		for i in 0..<n {
			components[i] = (v[i] * Cv[i]) / portfolioVaR
		}

		return components
	}
}

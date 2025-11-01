//
//  RiskAggregation.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

// MARK: - RiskAggregator

/// Aggregate risk across multiple entities or portfolios.
///
/// `RiskAggregator` provides methods to aggregate Value at Risk (VaR) across
/// entities, accounting for correlations. It also calculates marginal and
/// component VaR to understand individual contributions to portfolio risk.
///
/// ## Usage
///
/// ```swift
/// let individualVaRs = [100.0, 150.0, 200.0]
/// let correlations = [
///     [1.0, 0.6, 0.4],
///     [0.6, 1.0, 0.5],
///     [0.4, 0.5, 1.0]
/// ]
///
/// let aggregatedVaR = RiskAggregator<Double>.aggregateVaR(
///     individualVaRs: individualVaRs,
///     correlations: correlations
/// )
/// ```
public struct RiskAggregator<T: Real & Sendable> {

	// MARK: - Aggregate VaR

	/// Aggregate VaR across entities using variance-covariance approach.
	///
	/// Uses the formula:
	/// ```
	/// σ_portfolio = sqrt(Σ Σ VaR_i * VaR_j * ρ_ij)
	/// ```
	///
	/// - Parameters:
	///   - individualVaRs: Individual VaR for each entity.
	///   - correlations: Correlation matrix (n x n).
	/// - Returns: Aggregated portfolio VaR.
	public static func aggregateVaR(
		individualVaRs: [T],
		correlations: [[T]]
	) -> T {
		let n = individualVaRs.count
		precondition(correlations.count == n, "Correlation matrix must be n x n")
		precondition(correlations.allSatisfy { $0.count == n }, "Correlation matrix must be square")

		// Variance-covariance approach
		var totalVariance: T = 0

		for i in 0..<n {
			for j in 0..<n {
				totalVariance += individualVaRs[i] * individualVaRs[j] * correlations[i][j]
			}
		}

		return T.sqrt(totalVariance)
	}

	// MARK: - Marginal VaR

	/// Calculate marginal VaR contribution of a specific entity.
	///
	/// Marginal VaR measures the change in portfolio VaR if the entity's
	/// exposure increases by a small amount.
	///
	/// Formula:
	/// ```
	/// Marginal VaR_i = VaR_i * (Σ_j VaR_j * ρ_ij) / Portfolio VaR
	/// ```
	///
	/// - Parameters:
	///   - entity: Index of the entity (0-based).
	///   - individualVaRs: Individual VaR for each entity.
	///   - correlations: Correlation matrix.
	/// - Returns: Marginal VaR contribution.
	public static func marginalVaR(
		entity: Int,
		individualVaRs: [T],
		correlations: [[T]]
	) -> T {
		let n = individualVaRs.count
		precondition(entity >= 0 && entity < n, "Entity index out of bounds")

		let portfolioVaR = aggregateVaR(
			individualVaRs: individualVaRs,
			correlations: correlations
		)

		// Calculate contribution: Σ_j VaR_j * ρ_ij
		var contribution: T = 0
		for j in 0..<n {
			contribution += individualVaRs[j] * correlations[entity][j]
		}

		return individualVaRs[entity] * contribution / portfolioVaR
	}

	// MARK: - Component VaR

	/// Calculate component VaR for each entity.
	///
	/// Component VaR = Weight_i * Marginal VaR_i
	///
	/// Sum of component VaRs equals portfolio VaR.
	///
	/// - Parameters:
	///   - individualVaRs: Individual VaR for each entity.
	///   - weights: Portfolio weights for each entity.
	///   - correlations: Correlation matrix.
	/// - Returns: Array of component VaRs.
	public static func componentVaR(
		individualVaRs: [T],
		weights: [T],
		correlations: [[T]]
	) -> [T] {
		let n = individualVaRs.count
		precondition(weights.count == n, "Weights must match number of entities")

		var components = Array(repeating: T(0), count: n)

		for i in 0..<n {
			let marginal = marginalVaR(
				entity: i,
				individualVaRs: individualVaRs,
				correlations: correlations
			)
			components[i] = weights[i] * marginal
		}

		return components
	}
}

//
//  RiskParity.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

// MARK: - RiskParityOptimizer

/// Risk parity portfolio allocation optimizer.
///
/// `RiskParityOptimizer` allocates capital such that each asset contributes
/// equally to the total portfolio risk. This differs from mean-variance optimization
/// which maximizes Sharpe ratio.
///
/// ## Usage
///
/// ```swift
/// let optimizer = RiskParityOptimizer<Double>()
/// let allocation = optimizer.optimize(
///     assets: ["Stocks", "Bonds", "Commodities"],
///     returns: [stockReturns, bondReturns, commodityReturns]
/// )
/// ```
///
/// ## Theory
///
/// Risk parity aims to equalize the marginal contribution to risk (MCR) from each asset:
/// - MCR_i = weight_i * (∂σ/∂weight_i)
/// - Target: MCR_1 = MCR_2 = ... = MCR_n
public struct RiskParityOptimizer<T: Real & Sendable & Codable> {

	public init() {}

	// MARK: - Optimization

	/// Calculate risk parity weights where each asset contributes equally to total risk.
	///
	/// - Parameters:
	///   - assets: Array of asset identifiers.
	///   - returns: Historical return time series for each asset.
	/// - Returns: Portfolio allocation with equal risk contributions.
	public func optimize(
		assets: [String],
		returns: [TimeSeries<T>]
	) -> PortfolioAllocation<T> {

		let portfolio = Portfolio(assets: assets, returns: returns)
		let n = assets.count
		let cov = portfolio.covarianceMatrix

		// Start with equal weights
		var weights = Array(repeating: T(1) / T(n), count: n)

		// Iteratively adjust to equalize risk contributions
		let iterations = 100
		let learningRate = T(1) / T(100)  // 0.01

		for _ in 0..<iterations {
			let riskContributions = calculateRiskContributions(
				weights: weights,
				covariance: cov
			)

			let avgRisk = riskContributions.reduce(T(0), +) / T(n)

			// Adjust weights to move toward equal risk
			for i in 0..<n {
				let diff = riskContributions[i] - avgRisk
				weights[i] -= learningRate * diff
				weights[i] = max(T(0), weights[i])  // No short selling
			}

			// Normalize
			let sum = weights.reduce(T(0), +)
			if sum > T(0) {
				weights = weights.map { $0 / sum }
			}
		}

		return PortfolioAllocation(
			assets: assets,
			weights: weights,
			expectedReturn: portfolio.portfolioReturn(weights: weights),
			risk: portfolio.portfolioRisk(weights: weights),
			sharpeRatio: portfolio.sharpeRatio(weights: weights)
		)
	}

	// MARK: - Risk Contribution Calculation

	/// Calculate the marginal contribution to risk for each asset.
	///
	/// - Parameters:
	///   - weights: Current portfolio weights.
	///   - covariance: Covariance matrix between assets.
	/// - Returns: Risk contribution from each asset.
	private func calculateRiskContributions(
		weights: [T],
		covariance: [[T]]
	) -> [T] {
		let n = weights.count
		var contributions = Array(repeating: T(0), count: n)

		// Calculate total portfolio variance
		var totalVariance: T = 0
		for i in 0..<n {
			for j in 0..<n {
				totalVariance += weights[i] * weights[j] * covariance[i][j]
			}
		}

		let totalRisk = T.sqrt(totalVariance)
		guard totalRisk > T(0) else { return contributions }

		// Calculate marginal contribution to risk for each asset
		for i in 0..<n {
			var marginalRisk: T = 0
			for j in 0..<n {
				marginalRisk += weights[j] * covariance[i][j]
			}
			contributions[i] = weights[i] * marginalRisk / totalRisk
		}

		return contributions
	}
}

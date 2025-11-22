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

//public struct RiskParityOptimizer<T: Real & Sendable & Codable> {
//
//	public init() {}
//
//	// MARK: - Optimization
//
//	/// Calculate risk parity weights where each asset contributes equally to total risk.
//	///
//	/// - Parameters:
//	///   - assets: Array of asset identifiers.
//	///   - returns: Historical return time series for each asset.
//	/// - Returns: Portfolio allocation with equal risk contributions.
//	public func optimize(
//		assets: [String],
//		returns: [TimeSeries<T>]
//	) -> PortfolioAllocation<T> {
//
//		let portfolio = Portfolio(assets: assets, returns: returns)
//		let n = assets.count
//		let cov = portfolio.covarianceMatrix
//
//		// Start with equal weights
//		var weights = Array(repeating: T(1) / T(n), count: n)
//
//		// Iteratively adjust to equalize risk contributions
//		let iterations = 100
//		let learningRate = T(1) / T(100)  // 0.01
//
//		for _ in 0..<iterations {
//			let riskContributions = calculateRiskContributions(
//				weights: weights,
//				covariance: cov
//			)
//
//			let avgRisk = riskContributions.reduce(T(0), +) / T(n)
//
//			// Adjust weights to move toward equal risk
//			for i in 0..<n {
//				let diff = riskContributions[i] - avgRisk
//				weights[i] -= learningRate * diff
//				weights[i] = max(T(0), weights[i])  // No short selling
//			}
//
//			// Normalize
//			let sum = weights.reduce(T(0), +)
//			if sum > T(0) {
//				weights = weights.map { $0 / sum }
//			}
//		}
//
//		return PortfolioAllocation(
//			assets: assets,
//			weights: weights,
//			expectedReturn: portfolio.portfolioReturn(weights: weights),
//			risk: portfolio.portfolioRisk(weights: weights),
//			sharpeRatio: portfolio.sharpeRatio(weights: weights)
//		)
//	}
//
//	// MARK: - Risk Contribution Calculation
//
//	/// Calculate the marginal contribution to risk for each asset.
//	///
//	/// - Parameters:
//	///   - weights: Current portfolio weights.
//	///   - covariance: Covariance matrix between assets.
//	/// - Returns: Risk contribution from each asset.
//	private func calculateRiskContributions(
//		weights: [T],
//		covariance: [[T]]
//	) -> [T] {
//		let n = weights.count
//		var contributions = Array(repeating: T(0), count: n)
//
//		// Calculate total portfolio variance
//		var totalVariance: T = 0
//		for i in 0..<n {
//			for j in 0..<n {
//				totalVariance += weights[i] * weights[j] * covariance[i][j]
//			}
//		}
//
//		let totalRisk = T.sqrt(totalVariance)
//		guard totalRisk > T(0) else { return contributions }
//
//		// Calculate marginal contribution to risk for each asset
//		for i in 0..<n {
//			var marginalRisk: T = 0
//			for j in 0..<n {
//				marginalRisk += weights[j] * covariance[i][j]
//			}
//			contributions[i] = weights[i] * marginalRisk / totalRisk
//		}
//
//		return contributions
//	}
//}

public struct RiskParityOptimizer<T: Real & Sendable & Codable> {

	public init() {}

	public func optimize(
		assets: [String],
		returns: [TimeSeries<T>]
	) -> PortfolioAllocation<T> {

		let portfolio = Portfolio(assets: assets, returns: returns)
		let n = assets.count
		guard n > 0 else {
			return PortfolioAllocation(
				assets: assets,
				weights: [],
				expectedReturn: T.zero,
				risk: T.zero,
				sharpeRatio: T.zero
			)
		}

		let cov = portfolio.covarianceMatrix

		// 1) Initialize with inverse-vol weights (exact for diagonal Σ)
		var weights = inverseVolInit(covariance: cov)

		// 2) Multiplicative equalization loop
		let maxIterations = 1000
		let gamma: T = T(1) / T(2)        // damping exponent
		let tol: T = T.exp(-T(10) * T.log(T(10)))

		for _ in 0..<maxIterations {
			// m = Σ w
			let m = matVec(cov, weights)
			// σ_p^2 = w^T Σ w
			let sigma2 = dot(weights, m)
			if sigma2 <= T(0) { break }

			// Target per-asset contribution (variance units)
			let target = sigma2 / T(n)

			var maxDelta = T(0)
			for i in 0..<n {
				// Raw contribution in variance units
				let rc = weights[i] * m[i]
				// If rc is zero (e.g., weight or variance zero), skip multiplicative update
				if rc > T(0) && weights[i] > T(0) {
					// Scale weight towards equal contribution
					let ratio = target / rc
					// factor = ratio^gamma (use exp/log to avoid needing pow overloads)
					let factor = T.exp(gamma * T.log(ratio))
					let newWi = weights[i] * factor
					maxDelta = max(maxDelta, abs(newWi - weights[i]))
					weights[i] = newWi
				}
			}

			// Project to non-negative and renormalize
			for i in 0..<n {
				if !(weights[i].isFinite) || weights[i] < T(0) {
					weights[i] = T(0)
				}
			}
			let sumW = weights.reduce(T(0), +)
			if sumW > T(0) {
				weights = weights.map { $0 / sumW }
			} else {
				// Fallback to equal weights if degenerate
				weights = Array(repeating: T(1) / T(n), count: n)
			}

			if maxDelta < tol { break }
		}

		return PortfolioAllocation(
			assets: assets,
			weights: weights,
			expectedReturn: portfolio.portfolioReturn(weights: weights),
			risk: portfolio.portfolioRisk(weights: weights),
			sharpeRatio: portfolio.sharpeRatio(weights: weights)
		)
	}

	// MARK: - Helpers

	private func inverseVolInit(covariance: [[T]]) -> [T] {
		let n = covariance.count
		guard n > 0 else { return [] }
		var invVols = Array(repeating: T(0), count: n)
		for i in 0..<n {
			let v = covariance[i][i]
			let sigma = v > T(0) ? T.sqrt(v) : T(0)
			invVols[i] = sigma > T(0) ? (T(1) / sigma) : T(0)
		}
		let s = invVols.reduce(T(0), +)
		if s > T(0) {
			return invVols.map { $0 / s }
		} else {
			return Array(repeating: T(1) / T(n), count: n)
		}
	}

	private func matVec(_ A: [[T]], _ x: [T]) -> [T] {
		let n = x.count
		var y = Array(repeating: T(0), count: n)
		for i in 0..<n {
			var acc = T(0)
			let row = A[i]
			for j in 0..<n {
				acc += row[j] * x[j]
			}
			y[i] = acc
		}
		return y
	}

	private func dot(_ a: [T], _ b: [T]) -> T {
		var s = T(0)
		for i in 0..<a.count { s += a[i] * b[i] }
		return s
	}
}

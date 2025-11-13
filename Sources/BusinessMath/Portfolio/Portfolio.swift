//
//  Portfolio.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

// MARK: - Portfolio

/// Modern Portfolio Theory implementation for optimal asset allocation.
///
/// `Portfolio` implements Markowitz portfolio optimization, calculating
/// expected returns, risk (volatility), correlation matrices, and finding
/// optimal allocations that maximize the Sharpe ratio.
///
/// ## Usage
///
/// ```swift
/// let portfolio = Portfolio(
///     assets: ["AAPL", "GOOGL", "MSFT"],
///     returns: [appleReturns, googleReturns, msftReturns],
///     riskFreeRate: 0.03
/// )
///
/// let optimal = portfolio.optimizePortfolio()
/// print(optimal.sharpeRatio)
/// ```
public struct Portfolio<T: Real & Sendable & Codable> {

	// MARK: - Properties

	/// Asset identifiers.
	public let assets: [String]

	/// Historical returns for each asset.
	public let returns: [TimeSeries<T>]

	/// Risk-free rate (e.g., Treasury yield).
	public let riskFreeRate: T

	/// Cached covariance matrix (computed once at initialization).
	private let _covarianceMatrix: [[T]]

	/// Cached expected returns (computed once at initialization).
	private let _expectedReturns: [T]

	// MARK: - Initialization

	/// Creates a portfolio with assets and their historical returns.
	///
	/// - Parameters:
	///   - assets: Array of asset identifiers.
	///   - returns: Historical return time series for each asset.
	///   - riskFreeRate: Risk-free rate for Sharpe ratio calculation.
	public init(
		assets: [String],
		returns: [TimeSeries<T>],
		riskFreeRate: T = T(3) / T(100)  // 3%
	) {
		precondition(assets.count == returns.count, "Assets and returns must match")
		self.assets = assets
		self.returns = returns
		self.riskFreeRate = riskFreeRate

		// Compute and cache expected returns
		self._expectedReturns = returns.map { series in
			let values = series.valuesArray
			return values.reduce(T(0), +) / T(values.count)
		}

		// Compute and cache covariance matrix
		let n = assets.count
		var matrix = Array(repeating: Array(repeating: T(0), count: n), count: n)
		for i in 0..<n {
			for j in 0..<n {
				let values1 = returns[i].valuesArray
				let values2 = returns[j].valuesArray
				matrix[i][j] = Self.covariance(values1, values2)
			}
		}
		self._covarianceMatrix = matrix
	}

	// MARK: - Expected Returns

	/// Expected returns for each asset (arithmetic mean).
	///
	/// Cached at initialization for performance.
	public var expectedReturns: [T] {
		return _expectedReturns
	}

	// MARK: - Covariance and Correlation

	/// Covariance matrix between all assets.
	///
	/// Cached at initialization for performance. The covariance matrix is
	/// expensive to compute and is used repeatedly in portfolio optimization.
	public var covarianceMatrix: [[T]] {
		return _covarianceMatrix
	}

	/// Calculate correlation matrix between all assets.
	public var correlationMatrix: [[T]] {
		let n = assets.count
		var matrix = Array(repeating: Array(repeating: T(0), count: n), count: n)
		let cov = covarianceMatrix

		for i in 0..<n {
			for j in 0..<n {
				let stdI = T.sqrt(cov[i][i])
				let stdJ = T.sqrt(cov[j][j])
				matrix[i][j] = cov[i][j] / (stdI * stdJ)
			}
		}

		return matrix
	}

	// MARK: - Portfolio Metrics

	/// Calculate portfolio return for given weights.
	///
	/// - Parameter weights: Asset weights (must sum to 1).
	/// - Returns: Expected portfolio return.
	public func portfolioReturn(weights: [T]) -> T {
		precondition(weights.count == assets.count)
		let expectedRets = expectedReturns
		var portfolioReturn: T = 0

		for i in 0..<assets.count {
			portfolioReturn += weights[i] * expectedRets[i]
		}

		return portfolioReturn
	}

	/// Calculate portfolio risk (volatility) for given weights.
	///
	/// Risk is the standard deviation of portfolio returns, calculated
	/// using the variance-covariance matrix.
	///
	/// - Parameter weights: Asset weights (must sum to 1).
	/// - Returns: Portfolio volatility (standard deviation).
	public func portfolioRisk(weights: [T]) -> T {
		precondition(weights.count == assets.count)
		let cov = covarianceMatrix
		var variance: T = 0

		for i in 0..<assets.count {
			for j in 0..<assets.count {
				variance += weights[i] * weights[j] * cov[i][j]
			}
		}

		return T.sqrt(variance)
	}

	/// Calculate Sharpe ratio for given weights.
	///
	/// Sharpe ratio = (Return - Risk-free rate) / Risk
	///
	/// - Parameter weights: Asset weights (must sum to 1).
	/// - Returns: Sharpe ratio (higher is better).
	public func sharpeRatio(weights: [T]) -> T {
		let ret = portfolioReturn(weights: weights)
		let risk = portfolioRisk(weights: weights)
		guard risk > T(0) else { return T(0) }
		return (ret - riskFreeRate) / risk
	}

	// MARK: - Portfolio Optimization

	/// Find optimal portfolio that maximizes Sharpe ratio.
	///
	/// Uses gradient ascent to find weights that maximize the Sharpe ratio,
	/// subject to weights summing to 1 and being non-negative (no short selling).
	///
	/// - Returns: Optimal portfolio allocation.
	public func optimizePortfolio() -> PortfolioAllocation<T> {
		let n = assets.count

		// Start with equal weights
		var weights = Array(repeating: T(1) / T(n), count: n)

		let learningRate = T(1) / T(100)  // 0.01
		let iterations = 1000

		for _ in 0..<iterations {
			// Calculate gradient of Sharpe ratio
			let currentSharpe = sharpeRatio(weights: weights)
			var gradient = Array(repeating: T(0), count: n)

			for i in 0..<n {
				var weightsPlus = weights
				let h = T(1) / T(1000)  // 0.001
				weightsPlus[i] += h
				weightsPlus = normalizeWeights(weightsPlus)

				let sharpePlus = sharpeRatio(weights: weightsPlus)
				gradient[i] = (sharpePlus - currentSharpe) / h
			}

			// Update weights
			for i in 0..<n {
				weights[i] += learningRate * gradient[i]
			}

			// Constrain to [0, 1]
			weights = weights.map { w in max(T(0), min(T(1), w)) }

			// Normalize to sum to 1
			weights = normalizeWeights(weights)
		}

		return PortfolioAllocation(
			assets: assets,
			weights: weights,
			expectedReturn: portfolioReturn(weights: weights),
			risk: portfolioRisk(weights: weights),
			sharpeRatio: sharpeRatio(weights: weights)
		)
	}

	/// Calculate efficient frontier (risk-return tradeoff curve).
	///
	/// Generates portfolios with different target returns and finds
	/// the minimum risk portfolio for each return level.
	///
	/// - Parameter points: Number of points on the frontier.
	/// - Returns: Array of portfolio allocations on the efficient frontier.
	public func efficientFrontier(points: Int = 100) -> [PortfolioAllocation<T>] {
		var frontier: [PortfolioAllocation<T>] = []
		let expectedRets = expectedReturns

		// Find min and max returns
		guard let minReturn = expectedRets.min(),
			  let maxReturn = expectedRets.max() else {
			return []
		}

		let step = (maxReturn - minReturn) / T(points)

		for i in 0..<points {
			let targetReturn = minReturn + T(i) * step

			// Find minimum risk portfolio with this target return
			let weights = minimizeRiskForReturn(targetReturn: targetReturn)

			frontier.append(PortfolioAllocation(
				assets: assets,
				weights: weights,
				expectedReturn: portfolioReturn(weights: weights),
				risk: portfolioRisk(weights: weights),
				sharpeRatio: sharpeRatio(weights: weights)
			))
		}

		return frontier
	}

	// MARK: - Private Helpers

	private func minimizeRiskForReturn(targetReturn: T) -> [T] {
		let n = assets.count
		var weights = Array(repeating: T(1) / T(n), count: n)

		let learningRate = T(1) / T(100)  // 0.01
		let iterations = 500

		for _ in 0..<iterations {
			// Gradient descent to minimize risk
			let currentRisk = portfolioRisk(weights: weights)
			var gradient = Array(repeating: T(0), count: n)

			for i in 0..<n {
				var weightsPlus = weights
				let h = T(1) / T(1000)  // 0.001
				weightsPlus[i] += h
				weightsPlus = normalizeWeights(weightsPlus)

				let riskPlus = portfolioRisk(weights: weightsPlus)
				gradient[i] = (riskPlus - currentRisk) / h
			}

			// Update weights (minimize risk)
			for i in 0..<n {
				weights[i] -= learningRate * gradient[i]
			}

			// Constrain to [0, 1]
			weights = weights.map { w in max(T(0), min(T(1), w)) }

			// Normalize
			weights = normalizeWeights(weights)

			// Adjust to meet target return
			let currentReturn = portfolioReturn(weights: weights)
			if currentReturn < targetReturn {
				// Shift weight toward higher return assets
				let rets = expectedReturns
				for i in 0..<n {
					if rets[i] > currentReturn {
						weights[i] += T(1) / T(1000)
					}
				}
				weights = normalizeWeights(weights)
			}
		}

		return weights
	}

	private func normalizeWeights(_ weights: [T]) -> [T] {
		let sum = weights.reduce(T(0), +)
		guard sum > T(0) else { return weights }
		return weights.map { $0 / sum }
	}

	private static func covariance(_ x: [T], _ y: [T]) -> T {
		precondition(x.count == y.count)
		let n = T(x.count)
		let meanX = x.reduce(T(0), +) / n
		let meanY = y.reduce(T(0), +) / n

		var cov: T = 0
		for i in 0..<x.count {
			cov += (x[i] - meanX) * (y[i] - meanY)
		}

		return cov / (n - T(1))
	}
}

// MARK: - PortfolioAllocation

/// Result of portfolio optimization.
public struct PortfolioAllocation<T: Real & Sendable & Codable>: Sendable {
	/// Asset identifiers.
	public let assets: [String]

	/// Optimal weights for each asset.
	public let weights: [T]

	/// Expected portfolio return.
	public let expectedReturn: T

	/// Portfolio risk (volatility).
	public let risk: T

	/// Sharpe ratio.
	public let sharpeRatio: T

	public init(
		assets: [String],
		weights: [T],
		expectedReturn: T,
		risk: T,
		sharpeRatio: T
	) {
		self.assets = assets
		self.weights = weights
		self.expectedReturn = expectedReturn
		self.risk = risk
		self.sharpeRatio = sharpeRatio
	}

	/// Human-readable description.
	public var description: String {
		var desc = "Portfolio Allocation:\n"
		desc += "  Expected Return: \(expectedReturn * T(100))%\n"
		desc += "  Risk (Volatility): \(risk * T(100))%\n"
		desc += "  Sharpe Ratio: \(sharpeRatio)\n\n"
		desc += "Weights:\n"
		for (asset, weight) in zip(assets, weights) {
			desc += "  \(asset): \(weight * T(100))%\n"
		}
		return desc
	}
}

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
/// let quarters = Period.documentationQuarters
/// let appleReturns = TimeSeries(periods: quarters, values: [0.05, -0.02, 0.08, 0.03])
/// let googleReturns = TimeSeries(periods: quarters, values: [0.04, 0.01, 0.06, 0.02])
/// let msftReturns = TimeSeries(periods: quarters, values: [0.03, 0.02, 0.05, 0.04])
///
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
		guard assets.count == returns.count else {
			preconditionFailure("Assets count (\(assets.count)) must match returns count (\(returns.count))")
		}
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
	///
	/// ## The diagonal is one, and it used not to be
	///
	/// This read `cov[i][j] / (sqrt(cov[i][i]) * sqrt(cov[j][j]))` for every cell, diagonal
	/// included. `sqrt(v) * sqrt(v)` is not `v` in binary floating point, so the diagonal came
	/// back **`1.0000000000000002`** for ordinary assets — measured at one ulp over, on 40 of
	/// 40 sampled pairs. A correlation above one is not a correlation: it fails any `|rho| <= 1`
	/// assertion downstream, and a matrix carrying it is not positive semi-definite, so a
	/// Cholesky factorisation of it can fail on data that is perfectly well behaved.
	///
	/// Off-diagonal cells overshoot the same way when two assets are nearly collinear, so they
	/// are clipped into `[-1, 1]`. That is what `numpy.corrcoef` does, and for the same reason.
	///
	/// ## A constant asset gives NaN, deliberately
	///
	/// An asset that never moves — cash, a pegged rate, a single observation repeated — has
	/// zero variance, and its correlation with anything is `0 / 0`. That is undefined rather
	/// than zero, and reporting zero would be the fail-silent answer: "uncorrelated" is a
	/// finding, and this is the absence of one.
	///
	/// NaN is also what `numpy.corrcoef` and R's `cor` return for a constant series, diagonal
	/// included, and it matches the choice ``sharpeRatio(weights:)`` already makes at zero risk.
	///
	/// Whether the variance is *exactly* zero depends on the constant: a series of `0.004`
	/// leaves floating-point residue in the mean and lands at `8.2e-37`, giving a finite but
	/// meaningless correlation, while an exactly representable constant such as `0.25` or `0.0`
	/// gives a true zero and therefore NaN. Use ``covarianceMatrix`` to tell the two apart.
	public var correlationMatrix: [[T]] {
		let n = assets.count
		var matrix = Array(repeating: Array(repeating: T(0), count: n), count: n)
		let cov = covarianceMatrix

		// One square root per asset rather than one per cell; the old form took n^2 of them.
		let deviations: [T] = (0..<n).map { T.sqrt(cov[$0][$0]) }

		for i in 0..<n {
			for j in 0..<n {
				let denominator: T = deviations[i] * deviations[j]
				guard denominator > T.zero else {
					matrix[i][j] = T.nan
					continue
				}
				if i == j {
					matrix[i][j] = T(1)
					continue
				}
				let raw: T = cov[i][j] / denominator
				matrix[i][j] = T.minimum(T.maximum(raw, T(-1)), T(1))
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
		guard weights.count == assets.count else {
			preconditionFailure("Weights count (\(weights.count)) must match assets count (\(assets.count))")
		}
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
		guard weights.count == assets.count else {
			preconditionFailure("Weights count (\(weights.count)) must match assets count (\(assets.count))")
		}
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
	/// ## A portfolio with no risk
	///
	/// The division is left to IEEE arithmetic rather than guarded, so each case answers
	/// for itself:
	///
	/// | excess return | risk | result |
	/// |---|---|---|
	/// | positive | 0 | `+infinity` — unbounded return per unit of risk |
	/// | negative | 0 | `-infinity` |
	/// | zero | 0 | `nan` — 0/0, genuinely undefined |
	///
	/// This returned `0` for all three until 2026-09-13. Zero is a plausible number and
	/// the wrong one: a Sharpe of zero means *no excess return per unit of risk*, so a
	/// portfolio earning a positive excess at exactly zero risk — the best case there is —
	/// was reported as mediocre, and an equally impossible loss was reported the same way.
	///
	/// Callers who treat an infinite Sharpe as a modelling error should test for it. It is
	/// a real signal: outside a genuinely risk-free instrument it usually means the
	/// covariance estimate collapsed, which a zero is far better at hiding than an
	/// infinity is.
	///
	/// - Parameter weights: Asset weights (must sum to 1).
	/// - Returns: Sharpe ratio (higher is better). May be infinite or NaN; see above.
	public func sharpeRatio(weights: [T]) -> T {
		let ret = portfolioReturn(weights: weights)
		let risk = portfolioRisk(weights: weights)
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
		guard x.count == y.count else {
			preconditionFailure("Covariance arrays must have equal length: \(x.count) vs \(y.count)")
		}
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

	/// Creates a portfolio allocation result with performance metrics.
	///
	/// - Parameters:
	///   - assets: Array of asset names/identifiers
	///   - weights: Allocation weights for each asset (should sum to 1.0)
	///   - expectedReturn: Expected portfolio return (as decimal, e.g., 0.08 = 8%)
	///   - risk: Portfolio risk/volatility (standard deviation of returns)
	///   - sharpeRatio: Risk-adjusted return metric (return per unit of risk)
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

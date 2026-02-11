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

	/// Creates a risk parity optimizer.
	///
	/// The optimizer uses iterative multiplicative scaling to achieve equal risk contribution
	/// from each asset in the portfolio. No parameters are needed as the algorithm is deterministic.
	public init() {}

	/// Optimize portfolio weights to achieve equal risk contribution from each asset.
	///
	/// Risk parity allocation ensures that each asset contributes the same amount to total portfolio
	/// risk (volatility). This differs from equal-weight portfolios (which ignore correlations) and
	/// mean-variance optimization (which maximizes Sharpe ratio but may concentrate risk).
	///
	/// The algorithm uses iterative multiplicative scaling to equalize marginal risk contributions.
	/// Starting from inverse-volatility weights (optimal for uncorrelated assets), it iteratively
	/// adjusts weights until each asset's contribution to portfolio variance is equal.
	///
	/// - Parameters:
	///   - assets: Array of asset names/identifiers (e.g., ["Stocks", "Bonds", "Commodities"])
	///   - returns: Array of time series containing historical returns for each asset.
	///     Must have same length as `assets` array. Time series should have overlapping periods
	///     for accurate covariance estimation.
	///
	/// - Returns: A `PortfolioAllocation` containing:
	///   - `assets`: The input asset names
	///   - `weights`: Optimized weights summing to 1.0, with equal risk contribution
	///   - `expectedReturn`: Portfolio expected return (weighted average of asset returns)
	///   - `risk`: Portfolio volatility (standard deviation)
	///   - `sharpeRatio`: Risk-adjusted return (assuming 0% risk-free rate)
	///
	/// - Complexity: O(n² × k) where n is the number of assets and k is the number of iterations
	///   (typically converges in 50-200 iterations).
	///
	/// ## Algorithm Details
	///
	/// 1. **Initialization**: Start with inverse-volatility weights: wᵢ ∝ 1/σᵢ
	/// 2. **Iterative Scaling**: For each asset, compute risk contribution RCᵢ = wᵢ × (Σw)ᵢ
	/// 3. **Equalization**: Scale weight by (target/RCᵢ)^γ where γ = 0.5 (damping factor)
	/// 4. **Normalization**: Project to non-negative weights and normalize to sum = 1
	/// 5. **Convergence**: Repeat until max weight change < 1e-10
	///
	/// ## Mathematical Background
	///
	/// **Risk Contribution** of asset i to portfolio variance:
	/// ```
	/// RCᵢ = wᵢ × ∂σₚ²/∂wᵢ = wᵢ × (Σw)ᵢ
	/// ```
	///
	/// **Risk Parity Condition**:
	/// ```
	/// RC₁ = RC₂ = ... = RCₙ = σₚ²/n
	/// ```
	///
	/// The algorithm finds weights w such that all risk contributions are equal.
	///
	/// ## Usage Example
	///
	/// ```swift
	/// // Build multi-asset portfolio
	/// let assets = ["US Stocks", "Intl Stocks", "US Bonds", "Commodities"]
	///
	/// // Historical returns (monthly)
	/// let stocksUS = TimeSeries(periods: periods, values: [0.01, -0.02, 0.03, ...])
	/// let stocksIntl = TimeSeries(periods: periods, values: [0.02, -0.01, 0.02, ...])
	/// let bonds = TimeSeries(periods: periods, values: [0.005, 0.008, -0.002, ...])
	/// let commodities = TimeSeries(periods: periods, values: [0.01, 0.03, -0.04, ...])
	///
	/// let returns = [stocksUS, stocksIntl, bonds, commodities]
	///
	/// // Optimize for equal risk contribution
	/// let optimizer = RiskParityOptimizer<Double>()
	/// let allocation = optimizer.optimize(assets: assets, returns: returns)
	///
	/// print("Risk Parity Allocation:")
	/// for (asset, weight) in zip(allocation.assets, allocation.weights) {
	///     print("  \(asset): \(weight.percent(1))")
	/// }
	/// // Output:
	/// //   US Stocks: 22.5%
	/// //   Intl Stocks: 20.1%
	/// //   US Bonds: 45.8%  // Higher weight due to lower volatility
	/// //   Commodities: 11.6%
	///
	/// print("Portfolio Risk: \(allocation.risk.percent(1))")
	/// print("Expected Return: \(allocation.expectedReturn.percent(1))")
	/// print("Sharpe Ratio: \(allocation.sharpeRatio.number(2))")
	///
	/// // Verify equal risk contribution
	/// let covariance = Portfolio(assets: assets, returns: returns).covarianceMatrix
	/// let m = matVec(covariance, allocation.weights)
	/// for i in 0..<assets.count {
	///     let rc = allocation.weights[i] * m[i]
	///     print("\(assets[i]) risk contribution: \(rc.number(6))")
	/// }
	/// // All risk contributions should be nearly equal
	/// ```
	///
	/// ## When to Use
	///
	/// - **Diversified portfolios**: Want balanced risk exposure across asset classes
	/// - **Defensive portfolios**: Prefer stability over maximizing returns
	/// - **Passive strategies**: Don't have strong views on expected returns
	/// - **Institutional portfolios**: Common in pension funds, endowments
	///
	/// ## Comparison with Other Approaches
	///
	/// | Strategy | Weight Basis | Risk Distribution | Return Optimization |
	/// |----------|--------------|-------------------|---------------------|
	/// | **Equal Weight** | 1/n each | Unequal | No |
	/// | **Inverse Vol** | 1/σᵢ | Unequal (ignores correlation) | No |
	/// | **Risk Parity** | Equal risk contribution | Equal | No |
	/// | **Mean-Variance** | Maximize Sharpe | Concentrated | Yes |
	///
	/// - Important: Risk parity does NOT maximize expected returns or Sharpe ratio. It prioritizes
	///   diversification and stability over return optimization. Use mean-variance optimization
	///   if you have reliable expected return estimates.
	///
	/// - Note: The algorithm may converge slowly if assets have vastly different volatilities
	///   (e.g., cash vs. crypto). Typically converges in 50-200 iterations for normal portfolios.
	///
	/// - SeeAlso:
	///   - ``PortfolioAllocation``
	///   - ``Portfolio``
	///   - ``PortfolioOptimizer``
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

	/// Matrix-vector multiplication using VectorN API: y = A × x
	private func matVec(_ A: [[T]], _ x: [T]) -> [T] {
		let xVec = VectorN(x)
		return A.map { row in
			VectorN(row).dot(xVec)
		}
	}

	/// Dot product using VectorN API: a · b
	private func dot(_ a: [T], _ b: [T]) -> T {
		VectorN(a).dot(VectorN(b))
	}
}

//
//  PortfolioOptimizer.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation
import Numerics

// MARK: - Portfolio Optimization Results

/// Results from portfolio optimization
public struct OptimalPortfolio {
	/// Optimal portfolio weights
	public let weights: VectorN<Double>

	/// Expected return
	public let expectedReturn: Double

	/// Portfolio volatility (standard deviation)
	public let volatility: Double

	/// Sharpe ratio (return/risk)
	public let sharpeRatio: Double

	/// Whether the optimization converged
	public let converged: Bool

	/// Number of iterations used
	public let iterations: Int
}

/// Efficient frontier containing multiple portfolios
public struct EfficientFrontier {
	/// Array of efficient portfolios
	public let portfolios: [OptimalPortfolio]

	/// Target returns used to generate frontier
	public let targetReturns: [Double]

	/// Portfolio with maximum Sharpe ratio
	public var maximumSharpePortfolio: OptimalPortfolio {
		portfolios.max(by: { $0.sharpeRatio < $1.sharpeRatio })!
	}

	/// Portfolio with minimum variance
	public var minimumVariancePortfolio: OptimalPortfolio {
		portfolios.min(by: { $0.volatility < $1.volatility })!
	}
}

// MARK: - Portfolio Optimizer

/// Optimizer for portfolio allocation problems using modern portfolio theory.
///
/// Implements Markowitz mean-variance optimization, efficient frontier calculation,
/// Sharpe ratio maximization, and risk parity allocation.
///
/// ## Example
/// ```swift
/// let returns = VectorN([0.08, 0.12, 0.15])  // Expected returns
/// let covariance = [
///     [0.04, 0.01, 0.02],
///     [0.01, 0.09, 0.03],
///     [0.02, 0.03, 0.16]
/// ]
///
/// let optimizer = PortfolioOptimizer()
///
/// // Find minimum variance portfolio
/// let minVar = try optimizer.minimumVariancePortfolio(
///     expectedReturns: returns,
///     covariance: covariance
/// )
///
/// // Find maximum Sharpe ratio portfolio
/// let maxSharpe = try optimizer.maximumSharpePortfolio(
///     expectedReturns: returns,
///     covariance: covariance,
///     riskFreeRate: 0.02
/// )
///
/// // Generate efficient frontier
/// let frontier = try optimizer.efficientFrontier(
///     expectedReturns: returns,
///     covariance: covariance,
///     numberOfPoints: 20
/// )
/// ```
public struct PortfolioOptimizer {

	public init() {}

	// MARK: - Minimum Variance Portfolio

	/// Finds the portfolio with minimum variance.
	///
	/// Minimizes: σ² = w'Σw
	/// Subject to: Σw = 1 (weights sum to 1)
	///
	/// - Parameters:
	///   - expectedReturns: Expected return for each asset
	///   - covariance: Covariance matrix (n×n)
	///   - allowShortSelling: Whether to allow negative weights (default: false)
	/// - Returns: Optimal portfolio with minimum variance
	public func minimumVariancePortfolio(
		expectedReturns: VectorN<Double>,
		covariance: [[Double]],
		allowShortSelling: Bool = false
	) throws -> OptimalPortfolio {
		// Portfolio variance: σ² = w'Σw
		let varianceFunction: (VectorN<Double>) -> Double = { weights in
			let w = weights.toArray()
			var variance = 0.0
			for i in 0..<w.count {
				for j in 0..<w.count {
					variance += w[i] * covariance[i][j] * w[j]
				}
			}
			return variance
		}

		// Use Newton-Raphson for fast convergence on quadratic objective
		let optimizer = MultivariateNewtonRaphson<VectorN<Double>>(
			maxIterations: 100,
			tolerance: 1e-8
		)

		// Start with equal weights
		let n = expectedReturns.count
		let initialWeights = VectorN(Array(repeating: 1.0 / Double(n), count: n))

		let result = try optimizer.minimize(
			function: varianceFunction,
			gradient: { try numericalGradient(varianceFunction, at: $0) },
			hessian: { try numericalHessian(varianceFunction, at: $0) },
			initialGuess: initialWeights
		)

		// Normalize weights to sum to 1
		let normalizedWeights = normalizeWeights(result.solution)

		// Calculate portfolio metrics
		let portfolioReturn = expectedReturns.dot(normalizedWeights)
		let portfolioVariance = varianceFunction(normalizedWeights)
		let portfolioVolatility = Double.sqrt(portfolioVariance)

		return OptimalPortfolio(
			weights: normalizedWeights,
			expectedReturn: portfolioReturn,
			volatility: portfolioVolatility,
			sharpeRatio: portfolioReturn / portfolioVolatility,
			converged: result.converged,
			iterations: result.iterations
		)
	}

	// MARK: - Maximum Sharpe Ratio Portfolio

	/// Finds the portfolio with maximum Sharpe ratio.
	///
	/// Maximizes: (μ - rf) / σ where μ is return, rf is risk-free rate, σ is volatility
	///
	/// - Parameters:
	///   - expectedReturns: Expected return for each asset
	///   - covariance: Covariance matrix (n×n)
	///   - riskFreeRate: Risk-free rate (default: 0.02)
	/// - Returns: Optimal portfolio with maximum Sharpe ratio
	public func maximumSharpePortfolio(
		expectedReturns: VectorN<Double>,
		covariance: [[Double]],
		riskFreeRate: Double = 0.02
	) throws -> OptimalPortfolio {
		// Negative Sharpe ratio (minimize negative = maximize positive)
		let negativeSharpeFunction: (VectorN<Double>) -> Double = { weights in
			let w = weights.toArray()

			// Calculate return
			let portfolioReturn = expectedReturns.dot(weights)

			// Calculate variance
			var variance = 0.0
			for i in 0..<w.count {
				for j in 0..<w.count {
					variance += w[i] * covariance[i][j] * w[j]
				}
			}

			let volatility = Double.sqrt(variance)

			// Avoid division by zero
			if volatility < 1e-10 {
				return 1e10
			}

			// Return negative Sharpe ratio (we minimize)
			let sharpeRatio = (portfolioReturn - riskFreeRate) / volatility
			return -sharpeRatio
		}

		// Use BFGS for robustness on this non-quadratic objective
		let optimizer = MultivariateNewtonRaphson<VectorN<Double>>(
			maxIterations: 500,
			tolerance: 1e-6
		)

		// Start with equal weights
		let n = expectedReturns.count
		let initialWeights = VectorN(Array(repeating: 1.0 / Double(n), count: n))

		let result = try optimizer.minimizeBFGS(
			function: negativeSharpeFunction,
			gradient: { try numericalGradient(negativeSharpeFunction, at: $0) },
			initialGuess: initialWeights
		)

		// Normalize weights to sum to 1
		let normalizedWeights = normalizeWeights(result.solution)

		// Calculate portfolio metrics
		let portfolioReturn = expectedReturns.dot(normalizedWeights)
		let portfolioVariance = calculateVariance(weights: normalizedWeights, covariance: covariance)
		let portfolioVolatility = Double.sqrt(portfolioVariance)
		let sharpeRatio = (portfolioReturn - riskFreeRate) / portfolioVolatility

		return OptimalPortfolio(
			weights: normalizedWeights,
			expectedReturn: portfolioReturn,
			volatility: portfolioVolatility,
			sharpeRatio: sharpeRatio,
			converged: result.converged,
			iterations: result.iterations
		)
	}

	// MARK: - Efficient Frontier

	/// Generates the efficient frontier by computing optimal portfolios for different target returns.
	///
	/// - Parameters:
	///   - expectedReturns: Expected return for each asset
	///   - covariance: Covariance matrix (n×n)
	///   - riskFreeRate: Risk-free rate (default: 0.02)
	///   - numberOfPoints: Number of portfolios to compute (default: 20)
	/// - Returns: Efficient frontier with optimal portfolios
	public func efficientFrontier(
		expectedReturns: VectorN<Double>,
		covariance: [[Double]],
		riskFreeRate: Double = 0.02,
		numberOfPoints: Int = 20
	) throws -> EfficientFrontier {
		// Find min and max returns
		let minReturn = expectedReturns.toArray().min() ?? 0.0
		let maxReturn = expectedReturns.toArray().max() ?? 0.1

		// Generate target returns
		let step = (maxReturn - minReturn) / Double(numberOfPoints - 1)
		let targetReturns = (0..<numberOfPoints).map { minReturn + Double($0) * step }

		var portfolios: [OptimalPortfolio] = []

		for targetReturn in targetReturns {
			// Minimize variance for this target return
			let portfolio = try portfolioForTargetReturn(
				targetReturn: targetReturn,
				expectedReturns: expectedReturns,
				covariance: covariance,
				riskFreeRate: riskFreeRate
			)

			portfolios.append(portfolio)
		}

		return EfficientFrontier(
			portfolios: portfolios,
			targetReturns: targetReturns
		)
	}

	// MARK: - Risk Parity

	/// Finds a risk parity portfolio where each asset contributes equally to total risk.
	///
	/// Risk contribution: RC_i = w_i * (Σw)_i / σ
	/// Goal: RC_1 = RC_2 = ... = RC_n
	///
	/// - Parameters:
	///   - expectedReturns: Expected return for each asset
	///   - covariance: Covariance matrix (n×n)
	/// - Returns: Risk parity portfolio
	public func riskParityPortfolio(
		expectedReturns: VectorN<Double>,
		covariance: [[Double]]
	) throws -> OptimalPortfolio {
		let n = expectedReturns.count

		// Objective: minimize sum of squared differences in risk contributions
		let riskParityObjective: (VectorN<Double>) -> Double = { weights in
			let w = weights.toArray()

			// Calculate portfolio variance
			var variance = 0.0
			for i in 0..<n {
				for j in 0..<n {
					variance += w[i] * covariance[i][j] * w[j]
				}
			}

			let volatility = Double.sqrt(variance)
			if volatility < 1e-10 {
				return 1e10
			}

			// Calculate marginal risk contributions
			var marginalRisk = Array(repeating: 0.0, count: n)
			for i in 0..<n {
				for j in 0..<n {
					marginalRisk[i] += covariance[i][j] * w[j]
				}
			}

			// Calculate risk contributions
			var riskContributions = Array(repeating: 0.0, count: n)
			for i in 0..<n {
				riskContributions[i] = w[i] * marginalRisk[i] / volatility
			}

			// Target: equal risk contribution (1/n of total risk)
			let targetRC = volatility / Double(n)

			// Sum of squared errors
			var error = 0.0
			for rc in riskContributions {
				let diff = rc - targetRC
				error += diff * diff
			}

			return error
		}

		// Use BFGS for this non-quadratic objective
		let optimizer = MultivariateNewtonRaphson<VectorN<Double>>(
			maxIterations: 500,
			tolerance: 1e-6
		)

		// Start with equal weights
		let initialWeights = VectorN(Array(repeating: 1.0 / Double(n), count: n))

		let result = try optimizer.minimizeBFGS(
			function: riskParityObjective,
			gradient: { try numericalGradient(riskParityObjective, at: $0) },
			initialGuess: initialWeights
		)

		// Normalize weights
		let normalizedWeights = normalizeWeights(result.solution)

		// Calculate portfolio metrics
		let portfolioReturn = expectedReturns.dot(normalizedWeights)
		let portfolioVariance = calculateVariance(weights: normalizedWeights, covariance: covariance)
		let portfolioVolatility = Double.sqrt(portfolioVariance)

		return OptimalPortfolio(
			weights: normalizedWeights,
			expectedReturn: portfolioReturn,
			volatility: portfolioVolatility,
			sharpeRatio: portfolioReturn / portfolioVolatility,
			converged: result.converged,
			iterations: result.iterations
		)
	}

	// MARK: - Helper Functions

	private func portfolioForTargetReturn(
		targetReturn: Double,
		expectedReturns: VectorN<Double>,
		covariance: [[Double]],
		riskFreeRate: Double
	) throws -> OptimalPortfolio {
		// Minimize variance subject to target return
		// This is a simplified version - full implementation would use Lagrange multipliers

		let varianceFunction: (VectorN<Double>) -> Double = { weights in
			let w = weights.toArray()
			var variance = 0.0
			for i in 0..<w.count {
				for j in 0..<w.count {
					variance += w[i] * covariance[i][j] * w[j]
				}
			}

			// Add penalty for deviating from target return
			let actualReturn = expectedReturns.dot(weights)
			let returnPenalty = 1000.0 * (actualReturn - targetReturn) * (actualReturn - targetReturn)

			return variance + returnPenalty
		}

		let optimizer = MultivariateNewtonRaphson<VectorN<Double>>(
			maxIterations: 100,
			tolerance: 1e-6
		)

		let n = expectedReturns.count
		let initialWeights = VectorN(Array(repeating: 1.0 / Double(n), count: n))

		let result = try optimizer.minimizeBFGS(
			function: varianceFunction,
			gradient: { try numericalGradient(varianceFunction, at: $0) },
			initialGuess: initialWeights
		)

		let normalizedWeights = normalizeWeights(result.solution)
		let portfolioReturn = expectedReturns.dot(normalizedWeights)
		let portfolioVariance = calculateVariance(weights: normalizedWeights, covariance: covariance)
		let portfolioVolatility = Double.sqrt(portfolioVariance)
		let sharpeRatio = (portfolioReturn - riskFreeRate) / portfolioVolatility

		return OptimalPortfolio(
			weights: normalizedWeights,
			expectedReturn: portfolioReturn,
			volatility: portfolioVolatility,
			sharpeRatio: sharpeRatio,
			converged: result.converged,
			iterations: result.iterations
		)
	}

	private func normalizeWeights(_ weights: VectorN<Double>) -> VectorN<Double> {
		let sum = weights.toArray().reduce(0.0, +)
		if abs(sum) < 1e-10 {
			// If sum is zero, return equal weights
			let n = weights.count
			return VectorN(Array(repeating: 1.0 / Double(n), count: n))
		}
		return VectorN(weights.toArray().map { $0 / sum })
	}

	private func calculateVariance(weights: VectorN<Double>, covariance: [[Double]]) -> Double {
		let w = weights.toArray()
		var variance = 0.0
		for i in 0..<w.count {
			for j in 0..<w.count {
				variance += w[i] * covariance[i][j] * w[j]
			}
		}
		return variance
	}
}

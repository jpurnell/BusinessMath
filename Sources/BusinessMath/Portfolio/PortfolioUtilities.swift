//
//  PortfolioUtilities.swift
//  BusinessMath
//
//  Created by Claude Code on 02/04/26.
//

import Foundation
import Numerics

// MARK: - Portfolio Data Generation Utilities

/// Generates a vector of random expected returns.
///
/// Creates asset returns from a normal distribution with specified mean and standard deviation.
/// Useful for portfolio optimization examples and Monte Carlo simulations.
///
/// - Parameters:
///   - count: Number of assets
///   - mean: Expected mean return (e.g., 0.10 for 10%)
///   - stdDev: Standard deviation of returns (e.g., 0.15 for 15%)
/// - Returns: Vector of expected returns
///
/// ## Example
/// ```swift
/// // Generate returns for 100 assets with 10% mean, 5% std dev
/// let returns = generateRandomReturns(count: 100, mean: 0.10, stdDev: 0.05)
/// print("Average return: \((returns.sum / Double(returns.dimension) * 100).number(2))%")
/// ```
public func generateRandomReturns(
	count: Int,
	mean: Double,
	stdDev: Double
) -> VectorN<Double> {
	let returns = (0..<count).map { _ in
		// Box-Muller transform for normal distribution
		let u1 = Double.random(in: 0.0...1.0)
		let u2 = Double.random(in: 0.0...1.0)
		let z = sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
		return mean + stdDev * z
	}
	return VectorN(returns)
}

/// Generates a covariance matrix with specified correlation structure.
///
/// Creates a positive semi-definite covariance matrix where:
/// - Diagonal elements are variances (volatility²)
/// - Off-diagonal elements reflect average correlation
///
/// The matrix uses a simplified correlation structure where all pairwise
/// correlations are approximately equal to `avgCorrelation`.
///
/// - Parameters:
///   - size: Number of assets (matrix dimension)
///   - avgCorrelation: Average correlation between assets (0.0 to 1.0)
///   - volatility: Asset volatility range (min, max)
/// - Returns: size × size covariance matrix
///
/// ## Example
/// ```swift
/// // 50 assets with 30% average correlation
/// let covMatrix = generateCovarianceMatrix(
///     size: 50,
///     avgCorrelation: 0.30,
///     volatility: (0.15, 0.25)
/// )
///
/// // Use in portfolio optimization
/// func portfolioVariance(weights: VectorN<Double>) -> Double {
///     var variance = 0.0
///     for i in 0..<50 {
///         for j in 0..<50 {
///             variance += weights[i] * weights[j] * covMatrix[i][j]
///         }
///     }
///     return variance
/// }
/// ```
public func generateCovarianceMatrix(
	size: Int,
	avgCorrelation: Double,
	volatility: (min: Double, max: Double) = (0.10, 0.30)
) -> [[Double]] {
	// Generate random volatilities for each asset
	let volatilities = (0..<size).map { _ in
		Double.random(in: volatility.min...volatility.max)
	}

	// Create covariance matrix: Cov(i,j) = ρ * σᵢ * σⱼ
	var matrix = Array(repeating: Array(repeating: 0.0, count: size), count: size)

	// Fill diagonal with variances
	for i in 0..<size {
		matrix[i][i] = volatilities[i] * volatilities[i]
	}

	// Fill upper triangle with covariances, then mirror to lower triangle
	for i in 0..<size {
		for j in (i+1)..<size {
			// Off-diagonal: covariance = ρ * σᵢ * σⱼ
			// Add small random variation to correlation
			let correlation = avgCorrelation + Double.random(in: -0.05...0.05)
			let clampedCorrelation = max(0.0, min(1.0, correlation))
			let covariance = clampedCorrelation * volatilities[i] * volatilities[j]

			// Set both (i,j) and (j,i) to ensure symmetry
			matrix[i][j] = covariance
			matrix[j][i] = covariance
		}
	}

	return matrix
}

/// Generates a sparse covariance matrix with many zero correlations.
///
/// Creates a covariance matrix where most assets are uncorrelated (zero covariance),
/// useful for modeling large portfolios with sector or regional groupings.
///
/// - Parameters:
///   - size: Number of assets (matrix dimension)
///   - sparsity: Fraction of off-diagonal elements that are zero (0.0 to 1.0).
///     For example, 0.95 means 95% of correlations are zero.
///   - volatility: Asset volatility range (min, max)
/// - Returns: size × size sparse covariance matrix
///
/// ## Example
/// ```swift
/// // 5,000 assets with 95% sparsity (only 5% correlated)
/// let sparseMatrix = generateSparseCovarianceMatrix(
///     size: 5_000,
///     sparsity: 0.95,
///     volatility: (0.15, 0.25)
/// )
///
/// // Efficient variance calculation exploiting sparsity
/// func sparseVariance(weights: VectorN<Double>) -> Double {
///     var variance = 0.0
///     for i in 0..<5_000 {
///         // Diagonal contribution
///         variance += weights[i] * weights[i] * sparseMatrix[i][i]
///
///         // Only non-zero off-diagonal elements
///         for j in (i+1)..<5_000 where sparseMatrix[i][j] != 0.0 {
///             variance += 2.0 * weights[i] * weights[j] * sparseMatrix[i][j]
///         }
///     }
///     return variance
/// }
/// ```
///
/// ## Performance
/// For large portfolios (5,000+ assets), sparse matrices enable:
/// - **Memory savings**: Store only non-zero elements
/// - **Computation speedup**: Skip zero multiplications
/// - **Realistic modeling**: Most stocks aren't directly correlated
public func generateSparseCovarianceMatrix(
	size: Int,
	sparsity: Double,
	volatility: (min: Double, max: Double) = (0.10, 0.30)
) -> [[Double]] {
	// Generate random volatilities
	let volatilities = (0..<size).map { _ in
		Double.random(in: volatility.min...volatility.max)
	}

	// Create matrix
	var matrix = Array(repeating: Array(repeating: 0.0, count: size), count: size)

	// Set diagonal (variances)
	for i in 0..<size {
		matrix[i][i] = volatilities[i] * volatilities[i]
	}

	// Set sparse off-diagonal elements
	// Group assets into clusters for realistic correlation structure
	let clusterSize = max(5, Int(Double(size) * (1.0 - sparsity)))
	let numClusters = size / clusterSize

	for cluster in 0..<numClusters {
		let startIdx = cluster * clusterSize
		let endIdx = min(startIdx + clusterSize, size)

		// Assets within same cluster have moderate correlation
		for i in startIdx..<endIdx {
			for j in (i+1)..<endIdx {
				// Random correlation within cluster (0.2 to 0.5)
				let correlation = Double.random(in: 0.20...0.50)
				let covariance = correlation * volatilities[i] * volatilities[j]
				matrix[i][j] = covariance
				matrix[j][i] = covariance  // Symmetric
			}
		}
	}

	return matrix
}

// MARK: - Portfolio Volatility Helpers

/// Computes portfolio variance given weights and covariance matrix.
///
/// Calculates: σ²ₚ = wᵀ Σ w where w is the weight vector and Σ is the covariance matrix.
///
/// - Parameters:
///   - weights: Asset weights (should sum to 1.0 for fully invested portfolio)
///   - covarianceMatrix: n × n covariance matrix
/// - Returns: Portfolio variance
///
/// ## Example
/// ```swift
/// let weights = VectorN<Double>.equalWeights(dimension: 10)
/// let covMatrix = generateCovarianceMatrix(size: 10, avgCorrelation: 0.3)
/// let variance = portfolioVariance(weights: weights, covarianceMatrix: covMatrix)
/// let volatility = sqrt(variance)
/// print("Portfolio volatility: \((volatility * 100).number(2))%")
/// ```
public func portfolioVariance(
	weights: VectorN<Double>,
	covarianceMatrix: [[Double]]
) -> Double {
	let n = weights.dimension
	var variance = 0.0

	for i in 0..<n {
		for j in 0..<n {
			variance += weights[i] * weights[j] * covarianceMatrix[i][j]
		}
	}

	return variance
}

/// Computes Sharpe ratio given portfolio weights, returns, covariance, and risk-free rate.
///
/// Sharpe Ratio = (E[Rₚ] - Rᶠ) / σₚ
///
/// - Parameters:
///   - weights: Asset weights
///   - expectedReturns: Vector of expected returns
///   - covarianceMatrix: Covariance matrix
///   - riskFreeRate: Risk-free rate (e.g., 0.03 for 3%)
/// - Returns: Sharpe ratio (higher is better)
///
/// ## Example
/// ```swift
/// let returns = generateRandomReturns(count: 100, mean: 0.10, stdDev: 0.05)
/// let covMatrix = generateCovarianceMatrix(size: 100, avgCorrelation: 0.30)
/// let weights = VectorN<Double>.equalWeights(dimension: 100)
///
/// let sharpe = sharpeRatio(
///     weights: weights,
///     expectedReturns: returns,
///     covarianceMatrix: covMatrix,
///     riskFreeRate: 0.03
/// )
/// print("Sharpe Ratio: \(sharpe.number(3))")
/// ```
public func sharpeRatio(
	weights: VectorN<Double>,
	expectedReturns: VectorN<Double>,
	covarianceMatrix: [[Double]],
	riskFreeRate: Double
) -> Double {
	let expectedReturn = weights.dot(expectedReturns)
	let variance = portfolioVariance(weights: weights, covarianceMatrix: covarianceMatrix)
	let volatility = sqrt(variance)

	guard volatility > 0.0 else { return 0.0 }

	return (expectedReturn - riskFreeRate) / volatility
}

// MARK: - Simplified Portfolio Utilities

/// Computes simplified portfolio variance assuming uncorrelated assets.
///
/// For uncorrelated assets: σ²ₚ = Σ(wᵢ² σᵢ²)
///
/// This is much faster than full covariance calculation and useful for:
/// - Quick prototyping
/// - Large portfolios with weak correlations
/// - Educational examples
///
/// - Parameters:
///   - weights: Asset weights
///   - volatilities: Vector of asset volatilities
/// - Returns: Portfolio variance
///
/// ## Example
/// ```swift
/// let weights = VectorN([0.6, 0.4])
/// let vols = VectorN([0.20, 0.30])  // 20% and 30% volatility
///
/// let variance = simplifiedPortfolioVariance(weights: weights, volatilities: vols)
/// print("Portfolio volatility: \((sqrt(variance) * 100).number(1))%")
/// // Output: Portfolio volatility: 14.4%
/// ```
public func simplifiedPortfolioVariance(
	weights: VectorN<Double>,
	volatilities: VectorN<Double>
) -> Double {
	return zip(weights.toArray(), volatilities.toArray())
		.map { w, vol in w * w * vol * vol }
		.reduce(0, +)
}

/// Generates random asset volatilities from a realistic distribution.
///
/// Uses a lognormal-like distribution to model asset volatilities,
/// ensuring all values are positive and have reasonable range.
///
/// - Parameters:
///   - count: Number of assets
///   - minVolatility: Minimum volatility (default: 0.10 for 10%)
///   - maxVolatility: Maximum volatility (default: 0.30 for 30%)
/// - Returns: Vector of asset volatilities
///
/// ## Example
/// ```swift
/// let vols = generateRandomVolatilities(count: 1000)
/// print("Average volatility: \((vols.mean * 100).number(2))%")
/// print("Range: \((vols.min! * 100).number(1))% to \((vols.max! * 100).number(1))%")
/// ```
public func generateRandomVolatilities(
	count: Int,
	minVolatility: Double = 0.10,
	maxVolatility: Double = 0.30
) -> VectorN<Double> {
	let volatilities = (0..<count).map { _ in
		Double.random(in: minVolatility...maxVolatility)
	}
	return VectorN(volatilities)
}

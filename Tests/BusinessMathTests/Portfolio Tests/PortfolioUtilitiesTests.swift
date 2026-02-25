//
//  PortfolioUtilitiesTests.swift
//  BusinessMath
//
//  Created by Claude Code on 02/04/26.
//

import Foundation
import TestSupport  // Cross-platform math functions
import Testing
@testable import BusinessMath

@Suite("Portfolio Utilities Tests")
struct PortfolioUtilitiesTests {

	// MARK: - Random Returns Generation

	@Test("Generate random returns with correct dimensions")
	func generateReturns() {
		let returns = generateRandomReturns(count: 100, mean: 0.10, stdDev: 0.05)

		#expect(returns.dimension == 100, "Should have 100 returns")

		// Check mean is approximately correct (within 2 std errors)
		let mean = returns.sum / Double(returns.dimension)
		#expect(abs(mean - 0.10) < 0.02, "Mean should be near 0.10")
	}

	@Test("Random returns are within reasonable range")
	func returnsRange() {
		let returns = generateRandomReturns(count: 1000, mean: 0.10, stdDev: 0.05)

		// With 1000 samples, all values should be within ~4 std devs
		for r in returns.toArray() {
			#expect(r > -0.10, "Return shouldn't be too negative")
			#expect(r < 0.30, "Return shouldn't be too high")
		}
	}

	// MARK: - Covariance Matrix Generation

	@Test("Generate covariance matrix with correct dimensions")
	func generateCovarianceMatrixDimensions() {
		let matrix = generateCovarianceMatrix(size: 10, avgCorrelation: 0.30)

		#expect(matrix.count == 10, "Should have 10 rows")
		#expect(matrix[0].count == 10, "Should have 10 columns")
	}

	@Test("Covariance matrix is symmetric")
	func covarianceSymmetry() {
		let matrix = generateCovarianceMatrix(size: 5, avgCorrelation: 0.25)

		for i in 0..<5 {
			for j in 0..<5 {
				#expect(abs(matrix[i][j] - matrix[j][i]) < 1e-10, "Matrix should be symmetric")
			}
		}
	}

	@Test("Covariance matrix has positive diagonal")
	func covarianceDiagonal() {
		let matrix = generateCovarianceMatrix(size: 10, avgCorrelation: 0.30)

		for i in 0..<10 {
			#expect(matrix[i][i] > 0.0, "Diagonal elements (variances) should be positive")
			#expect(matrix[i][i] < 0.1, "Variance should be reasonable (< 0.1 for 10-30% vol)")
		}
	}

	@Test("Covariance reflects correlation structure")
	func covarianceCorrelation() {
		let matrix = generateCovarianceMatrix(size: 10, avgCorrelation: 0.30, volatility: (0.20, 0.20))

		// With constant volatility 0.20, covariance ≈ correlation * 0.04
		// Check a few off-diagonal elements
		for i in 0..<5 {
			for j in (i+1)..<5 {
				let covariance = matrix[i][j]
				let impliedCorrelation = covariance / 0.04  // variance = 0.20² = 0.04
				#expect(abs(impliedCorrelation - 0.30) < 0.10, "Correlation should be near 0.30")
			}
		}
	}

	// MARK: - Sparse Covariance Matrix

	@Test("Sparse covariance has correct sparsity")
	func sparseCovarianceSparsity() {
		let matrix = generateSparseCovarianceMatrix(size: 100, sparsity: 0.90)

		// Count non-zero off-diagonal elements
		var nonZeroCount = 0
		var totalOffDiagonal = 0

		for i in 0..<100 {
			for j in (i+1)..<100 {
				totalOffDiagonal += 1
				if matrix[i][j] != 0.0 {
					nonZeroCount += 1
				}
			}
		}

		let actualSparsity = 1.0 - Double(nonZeroCount) / Double(totalOffDiagonal)
		print("Sparse matrix: sparsity = \((actualSparsity * 100).number(1))%")

		// Sparsity should be approximately correct (within 10%)
		#expect(abs(actualSparsity - 0.90) < 0.15, "Sparsity should be near 0.90")
	}

	@Test("Sparse covariance is symmetric")
	func sparseCovarianceSymmetry() {
		let matrix = generateSparseCovarianceMatrix(size: 20, sparsity: 0.80)

		for i in 0..<20 {
			for j in 0..<20 {
				#expect(abs(matrix[i][j] - matrix[j][i]) < 1e-10, "Sparse matrix should be symmetric")
			}
		}
	}

	// MARK: - Portfolio Variance Calculation

	@Test("Portfolio variance with equal weights")
	func portfolioVarianceEqualWeights() {
		let size = 10
		let matrix = generateCovarianceMatrix(size: size, avgCorrelation: 0.30, volatility: (0.20, 0.20))
		let weights = VectorN<Double>.equalWeights(dimension: size)

		let variance = portfolioVariance(weights: weights, covarianceMatrix: matrix)

		#expect(variance > 0.0, "Variance should be positive")
		#expect(variance < 0.1, "Variance should be reasonable")
		print("Equal-weighted portfolio variance: \(variance.number(6))")
	}

	@Test("Portfolio variance with single asset")
	func portfolioVarianceSingleAsset() {
		let size = 5
		let matrix = generateCovarianceMatrix(size: size, avgCorrelation: 0.30)

		// 100% weight in first asset
		let weights = VectorN([1.0, 0.0, 0.0, 0.0, 0.0])

		let variance = portfolioVariance(weights: weights, covarianceMatrix: matrix)

		// Variance should equal the first asset's variance (diagonal element)
		#expect(abs(variance - matrix[0][0]) < 1e-10, "Single-asset variance should match diagonal")
	}

	// MARK: - Sharpe Ratio Calculation

	@Test("Sharpe ratio calculation")
	func sharpeRatioCalculation() {
		let size = 10
		let returns = VectorN((0..<size).map { _ in 0.12 })  // 12% return for all assets
		let matrix = generateCovarianceMatrix(size: size, avgCorrelation: 0.30, volatility: (0.15, 0.15))
		let weights = VectorN<Double>.equalWeights(dimension: size)

		let sharpe = sharpeRatio(
			weights: weights,
			expectedReturns: returns,
			covarianceMatrix: matrix,
			riskFreeRate: 0.03
		)

		#expect(sharpe > 0.0, "Sharpe ratio should be positive")
		print("Sharpe ratio: \(sharpe.number(3))")
	}

	@Test("Sharpe ratio with zero volatility")
	func sharpeRatioZeroVolatility() {
		// Create zero-variance matrix (impossible in practice but tests edge case)
		let matrix = Array(repeating: Array(repeating: 0.0, count: 3), count: 3)
		let returns = VectorN([0.10, 0.10, 0.10])
		let weights = VectorN<Double>.equalWeights(dimension: 3)

		let sharpe = sharpeRatio(
			weights: weights,
			expectedReturns: returns,
			covarianceMatrix: matrix,
			riskFreeRate: 0.03
		)

		#expect(sharpe == 0.0, "Sharpe ratio should be 0 with zero volatility")
	}

	// MARK: - Simplified Variance

	@Test("Simplified variance matches full variance for uncorrelated assets")
	func simplifiedVarianceUncorrelated() {
		let size = 10
		let volatilities = VectorN((0..<size).map { _ in 0.20 })
		let weights = VectorN<Double>.equalWeights(dimension: size)

		// Create diagonal covariance matrix (uncorrelated)
		var matrix = Array(repeating: Array(repeating: 0.0, count: size), count: size)
		for i in 0..<size {
			matrix[i][i] = 0.04  // 0.20² = 0.04
		}

		let simplifiedVar = simplifiedPortfolioVariance(weights: weights, volatilities: volatilities)
		let fullVar = portfolioVariance(weights: weights, covarianceMatrix: matrix)

		#expect(abs(simplifiedVar - fullVar) < 1e-10, "Should match for uncorrelated assets")
	}

	// MARK: - Random Volatilities

	@Test("Generate random volatilities")
	func generateVolatilities() {
		let vols = generateRandomVolatilities(count: 100)

		#expect(vols.dimension == 100, "Should have 100 volatilities")

		// Check all are in range
		for vol in vols.toArray() {
			#expect(vol >= 0.10, "Volatility should be >= 0.10")
			#expect(vol <= 0.30, "Volatility should be <= 0.30")
		}
	}

	@Test("Custom volatility range")
	func customVolatilityRange() {
		let vols = generateRandomVolatilities(count: 50, minVolatility: 0.05, maxVolatility: 0.15)

		for vol in vols.toArray() {
			#expect(vol >= 0.05, "Volatility should be >= 0.05")
			#expect(vol <= 0.15, "Volatility should be <= 0.15")
		}
	}

	// MARK: - Integration Test

	@Test("Full portfolio optimization workflow")
	func fullPortfolioWorkflow() {
		// Generate 50-asset portfolio
		let numAssets = 50
		let returns = generateRandomReturns(count: numAssets, mean: 0.10, stdDev: 0.05)
		let covMatrix = generateCovarianceMatrix(size: numAssets, avgCorrelation: 0.30)
		let weights = VectorN<Double>.equalWeights(dimension: numAssets)

		// Calculate metrics
		let sharpe = sharpeRatio(
			weights: weights,
			expectedReturns: returns,
			covarianceMatrix: covMatrix,
			riskFreeRate: 0.03
		)

		let variance = portfolioVariance(weights: weights, covarianceMatrix: covMatrix)
		let expectedReturn = weights.dot(returns)

		print("\nPortfolio Metrics:")
		print("  Expected Return: \((expectedReturn * 100).number(2))%")
		print("  Volatility: \((sqrt(variance) * 100).number(2))%")
		print("  Sharpe Ratio: \(sharpe.number(3))")

		#expect(expectedReturn > 0.0, "Expected return should be positive")
		#expect(variance > 0.0, "Variance should be positive")
		#expect(sharpe.isFinite, "Sharpe ratio should be finite")
	}
}

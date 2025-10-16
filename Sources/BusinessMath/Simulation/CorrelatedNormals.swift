//
//  CorrelatedNormals.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation

/// Error types for correlated normal variable generation.
public enum CorrelatedNormalsError: Error {
	case dimensionMismatch
	case invalidCorrelationMatrix
}

/// A generator for correlated multivariate normal random variables.
///
/// This struct generates samples from a multivariate normal distribution with
/// specified means and correlation structure using Cholesky decomposition.
///
/// ## Algorithm
///
/// The generation process uses the following approach:
/// 1. Given a correlation matrix Σ, compute its Cholesky decomposition: Σ = L × L^T
/// 2. To generate a sample X ~ N(μ, Σ):
///    - Generate n independent standard normals: Z ~ N(0, 1)
///    - Compute: X = μ + L × Z
/// 3. The resulting X has the desired mean μ and covariance Σ
///
/// ## Mathematical Background
///
/// For a multivariate normal distribution:
/// - Mean vector: μ = [μ₁, μ₂, ..., μₙ]
/// - Covariance matrix: Σ (must be positive semi-definite)
/// - For standard normals (variance = 1), Σ is the correlation matrix
///
/// The Cholesky decomposition factors Σ into a lower triangular matrix L such that:
/// Σ = L × L^T
///
/// This transformation preserves the correlation structure:
/// - Cov(L × Z) = L × Cov(Z) × L^T = L × I × L^T = L × L^T = Σ
///
/// ## Example
///
/// ```swift
/// // Create correlated normals with correlation ρ = 0.7
/// let means = [100.0, 200.0]
/// let correlationMatrix = [
///     [1.0, 0.7],
///     [0.7, 1.0]
/// ]
///
/// let generator = try CorrelatedNormals(means: means, correlationMatrix: correlationMatrix)
///
/// // Generate 1000 samples
/// var samples1: [Double] = []
/// var samples2: [Double] = []
///
/// for _ in 0..<1000 {
///     let sample = generator.sample()
///     samples1.append(sample[0])
///     samples2.append(sample[1])
/// }
///
/// // Verify correlation
/// let empiricalCorr = correlationCoefficient(samples1, samples2)
/// print("Target: 0.7, Empirical: \(empiricalCorr)")
/// ```
///
/// ## Use Cases
///
/// - Financial modeling: Correlated asset returns
/// - Risk analysis: Multiple correlated risk factors
/// - Monte Carlo simulation: Multi-variable uncertainty with dependencies
/// - Portfolio optimization: Asset correlation modeling
/// - Scenario analysis: Correlated business variables
public struct CorrelatedNormals {
	/// The mean values for each variable
	let means: [Double]

	/// The correlation matrix describing the correlation structure
	let correlationMatrix: [[Double]]

	/// The Cholesky factor L where Σ = L × L^T (computed once during initialization)
	private let choleskyFactor: [[Double]]

	/// Creates a new correlated normals generator.
	///
	/// Validates the inputs and computes the Cholesky decomposition for efficient sampling.
	///
	/// ## Validation Rules
	///
	/// - Means vector and correlation matrix must have matching dimensions
	/// - Correlation matrix must be:
	///   - Square (n×n)
	///   - Symmetric
	///   - Unit diagonal (all 1.0)
	///   - Bounded values: -1.0 ≤ ρ ≤ 1.0
	///   - Positive semi-definite
	///
	/// - Parameters:
	///   - means: The mean values for each variable (length n)
	///   - correlationMatrix: The n×n correlation matrix
	/// - Throws:
	///   - `CorrelatedNormalsError.dimensionMismatch` if means length doesn't match matrix size
	///   - `CorrelatedNormalsError.invalidCorrelationMatrix` if matrix is not a valid correlation matrix
	public init(means: [Double], correlationMatrix: [[Double]]) throws {
		// Validate dimension match
		guard means.count == correlationMatrix.count else {
			throw CorrelatedNormalsError.dimensionMismatch
		}

		// Validate correlation matrix
		guard isValidCorrelationMatrix(correlationMatrix) else {
			throw CorrelatedNormalsError.invalidCorrelationMatrix
		}

		// Store properties
		self.means = means
		self.correlationMatrix = correlationMatrix

		// Compute Cholesky decomposition
		// This will succeed because we've already validated positive semi-definiteness
		do {
			self.choleskyFactor = try choleskyDecomposition(correlationMatrix)
		} catch {
			// This should never happen since we validated the matrix
			throw CorrelatedNormalsError.invalidCorrelationMatrix
		}
	}

	/// Generates a single sample from the multivariate normal distribution.
	///
	/// The sample is generated using the Cholesky decomposition:
	/// 1. Generate n independent standard normal variates: Z ~ N(0, 1)
	/// 2. Transform using Cholesky factor: Y = L × Z
	/// 3. Add means: X = μ + Y
	///
	/// - Returns: A vector of correlated normal random values with the specified means and correlation
	public func sample() -> [Double] {
		let n = means.count

		// Generate n independent standard normals
		var standardNormals: [Double] = []
		for _ in 0..<n {
			let z: Double = distributionNormal(mean: 0.0, stdDev: 1.0)
			standardNormals.append(z)
		}

		// Multiply by Cholesky factor: Y = L × Z
		var transformed: [Double] = Array(repeating: 0.0, count: n)
		for i in 0..<n {
			var sum = 0.0
			for j in 0..<n {
				sum += choleskyFactor[i][j] * standardNormals[j]
			}
			transformed[i] = sum
		}

		// Add means: X = μ + Y
		var result: [Double] = []
		for i in 0..<n {
			result.append(means[i] + transformed[i])
		}

		return result
	}
}

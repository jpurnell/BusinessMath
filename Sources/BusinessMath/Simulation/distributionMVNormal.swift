//
//  distributionMVNormal.swift
//  BusinessMath
//

import Foundation
import Numerics

/// What can go wrong constructing a ``DistributionMVNormal``.
public enum MVNormalError: Error, Sendable, Equatable {

	/// The means and the covariance matrix disagree on the dimension, or the matrix is
	/// not square, or there is nothing to draw.
	case dimensionMismatch

	/// A mean was infinite or not a number.
	case nonFiniteLocation

	/// A diagonal entry was zero or negative. A zero variance is refused rather than
	/// treated as a degenerate margin: it would make that component a constant, and a
	/// constant silently changes what every correlation involving it means.
	case nonPositiveVariance

	/// An off-diagonal entry was not finite, or the matrix was not symmetric.
	case asymmetricCovariance

	/// The implied correlation matrix is not positive definite, so no Cholesky factor
	/// exists and there is no distribution with this covariance.
	case notPositiveDefinite
}

/// A multivariate normal, drawn from a mean vector and a covariance matrix.
///
/// Binds Risk Solver's `PsiMVNormal(mu, sigma)`.
///
/// ```swift
/// let mvn = try DistributionMVNormal(
///     means: [0.06, 0.11],
///     covarianceMatrix: [[0.0004, 0.00042],
///                        [0.00042, 0.0009]])
/// var rng = DeterministicRNG(seed: 42)
/// let draw = mvn.sample(using: &rng)   // two correlated returns
/// ```
///
/// ## Covariance in, correlation underneath
///
/// The argument is a **covariance** matrix, matching `PsiMVNormal` and matching how a
/// portfolio problem is actually stated. Internally it is split into standard
/// deviations and a correlation matrix, and the correlation is handed to
/// ``CorrelatedNormals``, which owns the Cholesky factor and the definiteness check.
///
/// The split is not cosmetic. A covariance matrix mixes two things — the scale of each
/// margin and the dependence between them — and only the second constrains the shape.
/// Factoring the scales out means the definiteness test runs on a matrix whose entries
/// are all in `[-1, 1]` regardless of the units the model is in, so a portfolio quoted
/// in basis points and the same portfolio quoted in dollars take the same path through
/// the same code. It also puts one Cholesky in one place, shared with
/// ``DistributionMVLogNormal``, rather than two that can drift apart.
public struct DistributionMVNormal: Sendable {

	/// The mean of each component.
	public let means: [Double]

	/// The covariance matrix as supplied.
	public let covarianceMatrix: [[Double]]

	/// The standard deviation of each component, `√Σᵢᵢ`.
	public let standardDeviations: [Double]

	/// The correlation matrix implied by the covariance.
	public let correlationMatrix: [[Double]]

	/// The correlated-normal generator underneath, which owns the Cholesky factor.
	private let normals: CorrelatedNormals

	/// The number of components.
	public var dimension: Int { means.count }

	/// Creates a multivariate normal.
	///
	/// - Parameters:
	///   - means: The mean of each component. Length `n`, every entry finite.
	///   - covarianceMatrix: The `n × n` covariance matrix. Symmetric, with a strictly
	///     positive diagonal, and positive definite.
	/// - Throws: ``MVNormalError`` naming which argument was rejected.
	public init(means: [Double], covarianceMatrix: [[Double]]) throws {
		let n = means.count
		guard n > 0, covarianceMatrix.count == n else { throw MVNormalError.dimensionMismatch }
		guard covarianceMatrix.allSatisfy({ $0.count == n }) else {
			throw MVNormalError.dimensionMismatch
		}
		guard means.allSatisfy({ $0.isFinite }) else { throw MVNormalError.nonFiniteLocation }

		var deviations = [Double](repeating: 0, count: n)
		for i in 0..<n {
			let variance: Double = covarianceMatrix[i][i]
			guard variance > 0, variance.isFinite else { throw MVNormalError.nonPositiveVariance }
			deviations[i] = variance.squareRoot()
		}

		// Symmetry is checked with a relative tolerance rather than exactly: a
		// covariance matrix assembled from data is symmetric in exact arithmetic and
		// usually not to the last bit, and rejecting that would refuse every matrix
		// that came from a computation rather than from a table.
		var correlation = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
		for i in 0..<n {
			for j in 0..<n {
				let entry: Double = covarianceMatrix[i][j]
				guard entry.isFinite else { throw MVNormalError.asymmetricCovariance }
				let mirrored: Double = covarianceMatrix[j][i]
				let gap: Double = Swift.abs(entry - mirrored)
				let scale: Double = Swift.max(Swift.abs(entry), 1)
				let bound: Double = scale * 1e-9
				guard gap <= bound else { throw MVNormalError.asymmetricCovariance }
				// Each deviation is positive, but their product is not guaranteed to
				// be: two scales near the smallest normal multiply to zero.
				let denominator: Double = deviations[i] * deviations[j]
				guard denominator > 0 else { throw MVNormalError.nonPositiveVariance }
				correlation[i][j] = entry / denominator
			}
			correlation[i][i] = 1
		}

		self.means = means
		self.covarianceMatrix = covarianceMatrix
		self.standardDeviations = deviations
		self.correlationMatrix = correlation
		do {
			self.normals = try CorrelatedNormals(
				means: [Double](repeating: 0, count: n),
				correlationMatrix: correlation)
		} catch {
			throw MVNormalError.notPositiveDefinite
		}
	}

	/// Creates a multivariate normal from margins and a correlation matrix.
	///
	/// The same distribution stated the other way round, for when the dependence is
	/// known separately from the scales — which is the usual case when a correlation
	/// is assumed rather than estimated.
	///
	/// - Parameters:
	///   - means: The mean of each component.
	///   - standardDeviations: The scale of each component, all strictly positive.
	///   - correlationMatrix: The `n × n` correlation matrix.
	/// - Throws: ``MVNormalError`` naming which argument was rejected.
	public init(means: [Double],
				standardDeviations: [Double],
				correlationMatrix: [[Double]]) throws {
		let n = means.count
		guard n > 0, standardDeviations.count == n, correlationMatrix.count == n else {
			throw MVNormalError.dimensionMismatch
		}
		guard standardDeviations.allSatisfy({ $0 > 0 && $0.isFinite }) else {
			throw MVNormalError.nonPositiveVariance
		}
		var covariance = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
		for i in 0..<n {
			guard correlationMatrix[i].count == n else { throw MVNormalError.dimensionMismatch }
			for j in 0..<n {
				let scales: Double = standardDeviations[i] * standardDeviations[j]
				covariance[i][j] = correlationMatrix[i][j] * scales
			}
		}
		try self.init(means: means, covarianceMatrix: covariance)
	}

	/// Draws one vector.
	///
	/// - Parameter generator: The random source. Seed it for a reproducible stream.
	/// - Returns: `n` correlated values.
	public func sample<G: RandomNumberGenerator>(using generator: inout G) -> [Double] {
		let standard = normals.sample(using: &generator)
		var result = [Double](repeating: 0, count: means.count)
		for i in 0..<means.count {
			let scaled: Double = standardDeviations[i] * standard[i]
			result[i] = means[i] + scaled
		}
		return result
	}

	/// The marginal distribution of one component.
	///
	/// - Parameter index: Which component, in `0..<dimension`.
	/// - Returns: The margin, or `nil` if the index is out of range.
	public func marginal(_ index: Int) -> DistributionNormal? {
		guard index >= 0, index < means.count else { return nil }
		return DistributionNormal(means[index], standardDeviations[index])
	}

	/// The covariance of two components.
	///
	/// - Parameters:
	///   - i: The first component.
	///   - j: The second component.
	/// - Returns: `Σᵢⱼ`, or `nil` if either index is out of range.
	public func covariance(_ i: Int, _ j: Int) -> Double? {
		guard i >= 0, i < means.count, j >= 0, j < means.count else { return nil }
		return covarianceMatrix[i][j]
	}

	/// The correlation of two components.
	///
	/// - Parameters:
	///   - i: The first component.
	///   - j: The second component.
	/// - Returns: `ρᵢⱼ`, or `nil` if either index is out of range.
	public func correlation(_ i: Int, _ j: Int) -> Double? {
		guard i >= 0, i < means.count, j >= 0, j < means.count else { return nil }
		return correlationMatrix[i][j]
	}
}

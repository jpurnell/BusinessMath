//
//  distributionMVLogNormal.swift
//  BusinessMath
//

import Foundation
import Numerics

/// Errors thrown when a multivariate lognormal cannot be built from its arguments.
public enum MVLogNormalError: Error, Sendable, Equatable {

	/// The mean vector, the scale vector and the correlation matrix disagree on `n`.
	case dimensionMismatch

	/// A log-scale entry was zero, negative or not finite. A lognormal with no spread
	/// is a constant, and a constant is not a distribution to sample from.
	case nonPositiveScale

	/// A log-mean was not finite.
	case nonFiniteLocation

	/// The correlation matrix was not square, symmetric, unit-diagonal, bounded by
	/// ±1, or positive semi-definite.
	case invalidCorrelationMatrix
}

/// Correlated positive quantities: a multivariate lognormal.
///
/// Costs, durations, demand and prices are all positive, all right-skewed, and rarely
/// independent of each other. Sampling them as correlated normals gives negative
/// values; sampling them as independent lognormals loses the dependence that usually
/// drives the tail of a portfolio. This does both — normals with the requested
/// correlation, exponentiated.
///
/// Binds Risk Solver's `PsiMVLogNormal(mean, stddev, correlationMatrix)`.
///
/// ```swift
/// // Two correlated cost drivers, each lognormal, correlated 0.6 in the logs.
/// let costs = try DistributionMVLogNormal(
///     logMeans: [0.0, 0.5],
///     logStandardDeviations: [0.3, 0.4],
///     correlationMatrix: [[1.0, 0.6], [0.6, 1.0]]
/// )
/// var generator = DeterministicRNG(seed: 42)
/// let draw = costs.sample(using: &generator)   // two positive values
/// ```
///
/// ## The parameters are on the log scale
///
/// `logMeans` and `logStandardDeviations` describe `log(X)`, not `X`, and the
/// correlation is likewise between the logs. That is the parameterisation every
/// reference for the lognormal uses, and it is the only one under which the family is
/// closed: a correlation applied to the values themselves would not survive the
/// exponential.
///
/// The corresponding moments of `X` are all closed form, which is what makes this
/// checkable without a reference implementation:
///
/// ```
/// E[Xᵢ]        = exp(μᵢ + σᵢ²/2)
/// Var[Xᵢ]      = (exp(σᵢ²) − 1) · exp(2μᵢ + σᵢ²)
/// Cov[Xᵢ, Xⱼ]  = exp(μᵢ + μⱼ + (σᵢ² + σⱼ²)/2) · (exp(ρᵢⱼ σᵢ σⱼ) − 1)
/// ```
///
/// ``expectedValues``, ``variances`` and ``covariance(_:_:)`` return those directly,
/// so a caller never has to simulate to learn what they asked for, and a test can
/// compare a large sample against them.
///
/// ## Correlation in the logs is not correlation in the values
///
/// The value correlation implied by `ρᵢⱼ` is
/// `(exp(ρᵢⱼσᵢσⱼ) − 1) / √((exp(σᵢ²) − 1)(exp(σⱼ²) − 1))`, which is always closer to
/// zero than `ρᵢⱼ` and cannot reach ±1 unless the scales match. Anyone reading a
/// correlation off historical *values* and passing it here will get less dependence
/// than they intended; ``impliedValueCorrelation(_:_:)`` reports what they will
/// actually get, so the gap is visible rather than surprising.
public struct DistributionMVLogNormal: Sendable {

	/// The mean of `log(Xᵢ)` for each component.
	public let logMeans: [Double]

	/// The standard deviation of `log(Xᵢ)` for each component. Every entry positive.
	public let logStandardDeviations: [Double]

	/// The correlation matrix of the logs.
	public let correlationMatrix: [[Double]]

	/// The correlated-normal generator underneath, which owns the Cholesky factor.
	private let normals: CorrelatedNormals

	/// The number of components.
	public var dimension: Int { logMeans.count }

	/// Creates a multivariate lognormal from log-scale parameters.
	///
	/// - Parameters:
	///   - logMeans: The mean of each `log(Xᵢ)`. Length `n`.
	///   - logStandardDeviations: The standard deviation of each `log(Xᵢ)`, every
	///     entry strictly positive. Length `n`.
	///   - correlationMatrix: The `n × n` correlation matrix **of the logs**.
	/// - Throws: ``MVLogNormalError`` describing which argument was rejected. A
	///   zero scale is refused rather than treated as a degenerate component: it
	///   would make that margin a constant, and a constant silently changes what
	///   every covariance involving it means.
	public init(logMeans: [Double],
				logStandardDeviations: [Double],
				correlationMatrix: [[Double]]) throws {
		guard logMeans.count == logStandardDeviations.count,
			  logMeans.count == correlationMatrix.count,
			  !logMeans.isEmpty else {
			throw MVLogNormalError.dimensionMismatch
		}
		guard logMeans.allSatisfy({ $0.isFinite }) else {
			throw MVLogNormalError.nonFiniteLocation
		}
		guard logStandardDeviations.allSatisfy({ $0 > 0 && $0.isFinite }) else {
			throw MVLogNormalError.nonPositiveScale
		}

		self.logMeans = logMeans
		self.logStandardDeviations = logStandardDeviations
		self.correlationMatrix = correlationMatrix

		// The underlying generator carries the correlation and validates the matrix;
		// the scales are applied here, after it draws, so there is one Cholesky and
		// one place that knows what a correlation matrix must satisfy.
		do {
			self.normals = try CorrelatedNormals(
				means: Array(repeating: 0.0, count: logMeans.count),
				correlationMatrix: correlationMatrix)
		} catch {
			throw MVLogNormalError.invalidCorrelationMatrix
		}
	}

	/// Draws one vector of correlated positive values.
	///
	/// - Parameter generator: The random source. A seeded generator makes the stream
	///   reproducible.
	/// - Returns: `n` strictly positive values.
	public func sample<G: RandomNumberGenerator>(using generator: inout G) -> [Double] {
		let standard = normals.sample(using: &generator)
		var result = [Double](repeating: 0, count: logMeans.count)
		for i in 0..<logMeans.count {
			let scaled: Double = logStandardDeviations[i] * standard[i]
			let logValue: Double = logMeans[i] + scaled
			result[i] = Foundation.exp(logValue)
		}
		return result
	}

	/// The marginal distribution of one component, as a univariate lognormal.
	///
	/// - Parameter index: Which component, in `0..<dimension`.
	/// - Returns: The margin, or `nil` if the index is out of range.
	public func marginal(_ index: Int) -> DistributionLogNormal? {
		guard index >= 0, index < logMeans.count else { return nil }
		return DistributionLogNormal(logMeans[index], logStandardDeviations[index])
	}

	/// `E[Xᵢ] = exp(μᵢ + σᵢ²/2)` for every component.
	///
	/// Note this exceeds `exp(μᵢ)`, the median, for every positive scale — the mean of
	/// a lognormal is not the exponential of its log-mean, and reading it as one is
	/// the most common way to under-budget a right-skewed cost.
	public var expectedValues: [Double] {
		(0..<logMeans.count).map { index -> Double in
			let variance: Double = logStandardDeviations[index] * logStandardDeviations[index]
			let exponent: Double = logMeans[index] + variance / 2
			return Foundation.exp(exponent)
		}
	}

	/// `Var[Xᵢ] = (exp(σᵢ²) − 1)·exp(2μᵢ + σᵢ²)` for every component.
	public var variances: [Double] {
		(0..<logMeans.count).map { index -> Double in
			let variance: Double = logStandardDeviations[index] * logStandardDeviations[index]
			let growth: Double = Foundation.expm1(variance)
			let scale: Double = 2 * logMeans[index] + variance
			return growth * Foundation.exp(scale)
		}
	}

	/// `Cov[Xᵢ, Xⱼ]` in the units of the values, from the closed form.
	///
	/// - Parameters:
	///   - i: The first component.
	///   - j: The second component.
	/// - Returns: The covariance, or `nil` if either index is out of range.
	public func covariance(_ i: Int, _ j: Int) -> Double? {
		guard i >= 0, i < logMeans.count, j >= 0, j < logMeans.count else { return nil }
		let varianceI: Double = logStandardDeviations[i] * logStandardDeviations[i]
		let varianceJ: Double = logStandardDeviations[j] * logStandardDeviations[j]
		let location: Double = logMeans[i] + logMeans[j]
		let spread: Double = (varianceI + varianceJ) / 2
		let base: Double = Foundation.exp(location + spread)
		let coupling: Double = correlationMatrix[i][j] * logStandardDeviations[i] * logStandardDeviations[j]
		// `expm1` rather than `exp(...) − 1`: for weakly correlated components the
		// coupling is small and the subtraction loses most of its significant digits.
		return base * Foundation.expm1(coupling)
	}

	/// The correlation between the **values**, which is not the correlation between
	/// the logs that was supplied.
	///
	/// - Parameters:
	///   - i: The first component.
	///   - j: The second component.
	/// - Returns: The implied correlation, or `nil` if either index is out of range.
	///   Always closer to zero than the log-scale correlation.
	public func impliedValueCorrelation(_ i: Int, _ j: Int) -> Double? {
		guard let covar = covariance(i, j) else { return nil }
		let all = variances
		let product: Double = all[i] * all[j]
		guard product > 0 else { return nil }
		return covar / product.squareRoot()
	}
}

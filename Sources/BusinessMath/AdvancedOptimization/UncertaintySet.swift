//
//  UncertaintySet.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation

// MARK: - Uncertainty Set Protocol

/// Protocol for uncertainty sets in robust optimization.
///
/// An uncertainty set U defines the range of possible parameter values.
/// Robust optimization finds solutions that perform well for all ω ∈ U.
public protocol UncertaintySet {
	/// Dimension of the uncertain parameters
	var dimension: Int { get }

	/// Generate sample points from the uncertainty set for worst-case search
	///
	/// - Parameter numberOfSamples: Number of sample points to generate
	/// - Returns: Array of parameter vectors from the uncertainty set
	func samplePoints(numberOfSamples: Int) -> [[Double]]

	/// Check if a point is in the uncertainty set
	///
	/// - Parameter point: Parameter vector to check
	/// - Returns: True if point is in the uncertainty set
	func contains(_ point: [Double]) -> Bool
}

// MARK: - Box Uncertainty Set

/// Box uncertainty set: ω ∈ [ω̄ - δ, ω̄ + δ]
///
/// Each parameter can deviate by ±δᵢ from its nominal value.
///
/// ## Example
/// ```swift
/// let uncertainReturns = BoxUncertaintySet(
///     nominal: [0.10, 0.12, 0.08],
///     deviations: [0.02, 0.03, 0.01]  // ±2%, ±3%, ±1%
/// )
///
/// // Returns can range from [0.08, 0.09, 0.07] to [0.12, 0.15, 0.09]
/// ```
public struct BoxUncertaintySet: UncertaintySet {
	/// Nominal parameter values (center of box)
	public let nominal: [Double]

	/// Maximum deviation for each parameter
	public let deviations: [Double]

	/// The number of uncertain parameters in the box.
	///
	/// For a box uncertainty set, this equals the number of nominal parameter values.
	public var dimension: Int { nominal.count }

	/// Creates a box uncertainty set.
	///
	/// - Parameters:
	///   - nominal: Nominal (center) parameter values
	///   - deviations: Maximum absolute deviations from nominal
	public init(nominal: [Double], deviations: [Double]) {
		precondition(nominal.count == deviations.count, "Nominal and deviations must have same dimension")
		precondition(deviations.allSatisfy { $0 >= 0 }, "Deviations must be non-negative")
		self.nominal = nominal
		self.deviations = deviations
	}

	/// Generates sample points from the box uncertainty set for worst-case analysis.
	///
	/// The sampling strategy prioritizes corner points (vertices) of the box, as these often
	/// represent worst-case scenarios in robust optimization. For boxes with 10 or fewer dimensions,
	/// all 2^d corner points are included. Additional points are sampled uniformly at random
	/// from within the box.
	///
	/// - Parameter numberOfSamples: Target number of sample points. May return more if all
	///   corners are included and dimension ≤ 10.
	/// - Returns: Array of parameter vectors, each within the box bounds [nominal ± deviations].
	///
	/// ## Example
	/// ```swift
	/// let box = BoxUncertaintySet(nominal: [100, 200], deviations: [10, 20])
	/// let samples = box.samplePoints(numberOfSamples: 100)
	/// // Returns: All 4 corners plus 96 random points
	/// ```
	public func samplePoints(numberOfSamples: Int) -> [[Double]] {
		var points: [[Double]] = []

		// Include corner points (vertices of the box)
		// For d dimensions, there are 2^d corners
		if dimension <= 10 {  // Only enumerate corners for small dimensions
			let numberOfCorners = 1 << dimension  // 2^d
			for i in 0..<numberOfCorners {
				var corner = nominal
				for j in 0..<dimension {
					let bit = (i >> j) & 1
					corner[j] += bit == 0 ? -deviations[j] : deviations[j]
				}
				points.append(corner)
			}
		}

		// Add random points from the box
		let remaining = max(0, numberOfSamples - points.count)
		for _ in 0..<remaining {
			var point: [Double] = []
			for j in 0..<dimension {
				// Sample uniformly within [nominal - deviation, nominal + deviation]
				let lower = nominal[j] - deviations[j]
				let upper = nominal[j] + deviations[j]
				point.append(Double.random(in: lower...upper))
			}
			points.append(point)
		}

		return points
	}

	/// Checks if a parameter vector is within the box uncertainty set.
	///
	/// A point is in the box if each coordinate satisfies: |pointᵢ - nominalᵢ| ≤ deviationᵢ.
	/// Uses a small numerical tolerance (1e-10) for floating-point comparisons.
	///
	/// - Parameter point: Parameter vector to check for membership.
	/// - Returns: `true` if the point is within the box bounds, `false` otherwise.
	///
	/// ## Example
	/// ```swift
	/// let box = BoxUncertaintySet(nominal: [100], deviations: [10])
	/// box.contains([105])  // true (within ±10)
	/// box.contains([115])  // false (outside bounds)
	/// ```
	public func contains(_ point: [Double]) -> Bool {
		guard point.count == dimension else { return false }

		for i in 0..<dimension {
			let distance = abs(point[i] - nominal[i])
			// Use small tolerance for floating point comparison
			if distance > deviations[i] + 1e-10 {
				return false
			}
		}
		return true
	}

	/// Lower bounds: ω̄ - δ
	public var lowerBounds: [Double] {
		zip(nominal, deviations).map { $0 - $1 }
	}

	/// Upper bounds: ω̄ + δ
	public var upperBounds: [Double] {
		zip(nominal, deviations).map { $0 + $1 }
	}
}

// MARK: - Ellipsoidal Uncertainty Set

/// Ellipsoidal uncertainty set: ||Σ^(-1/2)(ω - ω̄)|| ≤ κ
///
/// Parameters within an ellipsoid centered at nominal value.
///
/// ## Example
/// ```swift
/// let uncertainReturns = EllipsoidalUncertaintySet(
///     nominal: [0.10, 0.12, 0.08],
///     covariance: covarianceMatrix,
///     radius: 2.0  // 2-sigma ellipsoid
/// )
/// ```
public struct EllipsoidalUncertaintySet: UncertaintySet {
	/// Nominal parameter values (center of ellipsoid)
	public let nominal: [Double]

	/// Covariance matrix (defines ellipsoid shape)
	public let covariance: [[Double]]

	/// Ellipsoid radius (scaled by covariance)
	public let radius: Double

	/// The number of uncertain parameters in the ellipsoid.
	///
	/// For an ellipsoidal uncertainty set, this equals the number of nominal parameter values.
	public var dimension: Int { nominal.count }

	/// Creates an ellipsoidal uncertainty set.
	///
	/// - Parameters:
	///   - nominal: Nominal (center) parameter values
	///   - covariance: Covariance matrix (must be symmetric positive definite)
	///   - radius: Ellipsoid radius (default: 1.0)
	public init(nominal: [Double], covariance: [[Double]], radius: Double = 1.0) {
		precondition(covariance.count == nominal.count, "Covariance dimension must match nominal")
		precondition(covariance.allSatisfy { $0.count == nominal.count }, "Covariance must be square")
		precondition(radius > 0, "Radius must be positive")
		self.nominal = nominal
		self.covariance = covariance
		self.radius = radius
	}

	/// Generates sample points from the ellipsoidal uncertainty set.
	///
	/// Samples points uniformly from within the ellipsoid defined by ||Σ^(-1/2)(ω - ω̄)|| ≤ κ,
	/// where Σ is the covariance matrix and κ is the radius. This implementation uses a
	/// diagonal approximation of the covariance for computational efficiency.
	///
	/// - Parameter numberOfSamples: Number of sample points to generate.
	/// - Returns: Array of parameter vectors within the ellipsoid.
	///
	/// - Note: This implementation approximates the ellipsoid using only diagonal elements
	///   of the covariance matrix. For full covariance sampling, use Cholesky decomposition.
	///
	/// ## Example
	/// ```swift
	/// let ellipsoid = EllipsoidalUncertaintySet(
	///     nominal: [100, 200],
	///     covariance: [[100, 0], [0, 400]],  // Diagonal covariance
	///     radius: 2.0
	/// )
	/// let samples = ellipsoid.samplePoints(numberOfSamples: 1000)
	/// // Returns: 1000 points within 2-sigma ellipsoid
	/// ```
	public func samplePoints(numberOfSamples: Int) -> [[Double]] {
		var points: [[Double]] = []

		// For simplicity, approximate ellipsoid with random samples
		// In production, would use Cholesky decomposition for proper sampling
		for _ in 0..<numberOfSamples {
			var point = nominal
			// Sample random direction and scale by radius
			var direction: [Double] = []
			var normSquared = 0.0
			for _ in 0..<dimension {
				let value = Double.random(in: -1...1)
				direction.append(value)
				normSquared += value * value
			}

			// Normalize and scale
			let norm = sqrt(normSquared)
			if norm > 0 {
				let scale = Double.random(in: 0...radius) / norm
				for i in 0..<dimension {
					// Simple diagonal approximation (would use full covariance in production)
					let stdDev = sqrt(covariance[i][i])
					point[i] += direction[i] * scale * stdDev
				}
			}

			points.append(point)
		}

		return points
	}

	/// Checks if a parameter vector is within the ellipsoidal uncertainty set.
	///
	/// A point is in the ellipsoid if its Mahalanobis distance from the nominal value
	/// is at most the radius: ||Σ^(-1/2)(ω - ω̄)|| ≤ κ. This implementation uses a
	/// diagonal approximation of the covariance matrix for efficiency.
	///
	/// - Parameter point: Parameter vector to check for membership.
	/// - Returns: `true` if the point is within the ellipsoid, `false` otherwise.
	///
	/// - Note: Uses diagonal elements only for Mahalanobis distance calculation.
	///   For exact ellipsoid membership, use the full inverse covariance matrix.
	///
	/// ## Example
	/// ```swift
	/// let ellipsoid = EllipsoidalUncertaintySet(
	///     nominal: [100],
	///     covariance: [[100]],
	///     radius: 2.0
	/// )
	/// ellipsoid.contains([120])  // true (within 2 std devs)
	/// ellipsoid.contains([130])  // false (beyond 2 std devs)
	/// ```
	public func contains(_ point: [Double]) -> Bool {
		guard point.count == dimension else { return false }

		// Compute Mahalanobis distance (simplified with diagonal approximation)
		var distanceSquared = 0.0
		for i in 0..<dimension {
			let diff = point[i] - nominal[i]
			let variance = covariance[i][i]
			if variance > 0 {
				distanceSquared += (diff * diff) / variance
			}
		}

		return sqrt(distanceSquared) <= radius
	}
}

// MARK: - Discrete Uncertainty Set

/// Discrete uncertainty set: ω ∈ {ω₁, ω₂, ..., ωₙ}
///
/// Finite set of possible parameter realizations.
///
/// ## Example
/// ```swift
/// let uncertainDemand = DiscreteUncertaintySet(
///     points: [
///         [80, 90, 100],   // Low demand
///         [100, 110, 120], // Medium demand
///         [120, 130, 140]  // High demand
///     ]
/// )
/// ```
public struct DiscreteUncertaintySet: UncertaintySet {
	/// Possible parameter values
	public let points: [[Double]]

	/// The number of uncertain parameters in the discrete set.
	///
	/// Returns the dimension of the first point, or 0 if the set is empty.
	public var dimension: Int {
		points.first?.count ?? 0
	}

	/// Creates a discrete uncertainty set.
	///
	/// - Parameter points: Array of possible parameter vectors
	public init(points: [[Double]]) {
		precondition(!points.isEmpty, "Must provide at least one point")
		let dim = points.first!.count
		precondition(points.allSatisfy { $0.count == dim }, "All points must have same dimension")
		self.points = points
	}

	/// Returns sample points from the discrete uncertainty set.
	///
	/// For discrete sets, sampling returns the actual scenario points. If `numberOfSamples`
	/// exceeds the number of scenarios, all scenarios are returned. Otherwise, the first
	/// `numberOfSamples` scenarios are returned.
	///
	/// - Parameter numberOfSamples: Maximum number of scenarios to return.
	/// - Returns: Array of parameter vectors from the discrete set. Returns all scenarios
	///   if `numberOfSamples` ≥ number of scenarios.
	///
	/// ## Example
	/// ```swift
	/// let scenarios = DiscreteUncertaintySet(points: [
	///     [80, 100],   // Pessimistic
	///     [100, 120],  // Base case
	///     [120, 140]   // Optimistic
	/// ])
	/// let samples = scenarios.samplePoints(numberOfSamples: 10)
	/// // Returns: All 3 scenarios (since 10 > 3)
	/// ```
	public func samplePoints(numberOfSamples: Int) -> [[Double]] {
		// For discrete set, just return all points (or sample with replacement)
		if numberOfSamples >= points.count {
			return points
		} else {
			return Array(points.prefix(numberOfSamples))
		}
	}

	/// Checks if a parameter vector is one of the discrete scenarios.
	///
	/// A point is in the discrete set if it matches one of the predefined scenarios
	/// exactly (within numerical tolerance of 1e-10 for floating-point comparisons).
	///
	/// - Parameter point: Parameter vector to check for membership.
	/// - Returns: `true` if the point matches one of the discrete scenarios, `false` otherwise.
	///
	/// ## Example
	/// ```swift
	/// let scenarios = DiscreteUncertaintySet(points: [
	///     [80, 100],
	///     [100, 120],
	///     [120, 140]
	/// ])
	/// scenarios.contains([100, 120])  // true (matches base case)
	/// scenarios.contains([90, 110])   // false (not a predefined scenario)
	/// ```
	public func contains(_ point: [Double]) -> Bool {
		guard point.count == dimension else { return false }

		return points.contains { candidate in
			zip(candidate, point).allSatisfy { abs($0 - $1) < 1e-10 }
		}
	}
}

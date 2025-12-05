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

	public func samplePoints(numberOfSamples: Int) -> [[Double]] {
		// For discrete set, just return all points (or sample with replacement)
		if numberOfSamples >= points.count {
			return points
		} else {
			return Array(points.prefix(numberOfSamples))
		}
	}

	public func contains(_ point: [Double]) -> Bool {
		guard point.count == dimension else { return false }

		return points.contains { candidate in
			zip(candidate, point).allSatisfy { abs($0 - $1) < 1e-10 }
		}
	}
}

//
//  InitializationStrategies.swift
//  BusinessMath
//
//  Created by Justin Purnell on 1/28/26.
//

import Foundation
import Numerics

// MARK: - CentroidInitialization Protocol

/// Protocol for strategies that initialize cluster centroids.
///
/// Different initialization strategies can significantly affect K-Means
/// clustering results. K-Means++ generally performs better than random
/// initialization by spreading centroids apart.
///
/// ## Usage Example
/// ```swift
/// let data: [Vector2D<Double>] = /* your data */
/// let strategy: CentroidInitialization = KMeansPlusPlusInitialization()
///
/// let initialCentroids = strategy.initialize(
///     data: data,
///     k: 3,
///     distanceMetric: .euclidean,
///     seed: 42
/// )
/// ```
///
/// - SeeAlso:
///   - ``RandomInitialization``
///   - ``ForgyInitialization``
///   - ``KMeansPlusPlusInitialization``
///   - ``KMeans``
public protocol CentroidInitialization {
	/// Initialize k centroids from the given data points.
	///
	/// - Parameters:
	///   - data: Array of data points to cluster
	///   - k: Number of centroids to initialize
	///   - distanceMetric: Distance metric to use for distance calculations
	///   - seed: Optional random seed for deterministic results. If nil, uses random initialization.
	///
	/// - Returns: Array of k initial centroid vectors
	///
	/// - Note: All implementations should support deterministic initialization
	///   when a seed is provided, enabling reproducible results for testing.
	func initialize<V: VectorSpace>(
		data: [V],
		k: Int,
		distanceMetric: DistanceMetric,
		seed: UInt64?
	) -> [V] where V.Scalar: BinaryFloatingPoint
}

// MARK: - Random Initialization

/// Randomly selects k data points as initial centroids.
///
/// This is the simplest initialization strategy: it picks k points uniformly
/// at random from the dataset. While simple and fast, it can sometimes lead
/// to poor initial centroids that result in suboptimal clustering.
///
/// ## Usage Example
/// ```swift
/// let strategy = RandomInitialization()
/// let centroids = strategy.initialize(
///     data: dataPoints,
///     k: 5,
///     distanceMetric: .euclidean,
///     seed: 12345  // Deterministic for testing
/// )
/// ```
///
/// ## Time Complexity
/// O(k) - selects k random indices
///
/// - Important: For reproducible results, always provide a seed value.
///   Without a seed, each call will produce different results.
///
/// - SeeAlso:
///   - ``ForgyInitialization``
///   - ``KMeansPlusPlusInitialization``
public struct RandomInitialization: CentroidInitialization {
	/// Creates a random initialization strategy.
	public init() {}
	
	/// - Parameters:
	///   - data: Array of data points to cluster. Must contain at least k points.
	///   - k: Number of centroids to initialize. Must be positive and ≤ data.count.
	///   - distanceMetric: Distance metric to use for computing distances between points and centroids.
	///     Common choices are `.euclidean` or `.manhattan`.
	///   - seed: Optional random seed for deterministic initialization. If `nil`, uses system
	///     random number generator for non-deterministic results. Provide a seed value for
	///     reproducible testing and debugging.
	///
	/// - Returns: Array of k initial centroid vectors selected from the data space. These centroids
	///   are spread out to maximize minimum inter-centroid distances.
	///
	/// - Complexity: O(n·k·d) where n is the number of data points, k is the number of clusters,
	///   and d is the dimensionality of each point.
	///
	public func initialize<V: VectorSpace>(
		data: [V],
		k: Int,
		distanceMetric: DistanceMetric,
		seed: UInt64?
	) -> [V] where V.Scalar: BinaryFloatingPoint {
		var rng: any RandomNumberGenerator
		if let seed = seed {
			rng = SeededRandomNumberGenerator(seed: seed)
		} else {
			rng = SystemRandomNumberGenerator()
		}

		// Randomly select k distinct indices
		var selectedIndices = Set<Int>()
		while selectedIndices.count < k {
			let randomIndex = Int.random(in: 0..<data.count, using: &rng)
			selectedIndices.insert(randomIndex)
		}

		// Return the selected data points as initial centroids
		return selectedIndices.sorted().map { data[$0] }
	}
}

// MARK: - Forgy Initialization

/// Randomly partitions data points and computes the mean of each partition.
///
/// The Forgy method randomly assigns each data point to one of k groups,
/// then computes the centroid (mean) of each group as the initial centroids.
/// This can provide better initial centroids than random selection.
///
/// ## Usage Example
/// ```swift
/// let strategy = ForgyInitialization()
/// let centroids = strategy.initialize(
///     data: dataPoints,
///     k: 3,
///     distanceMetric: .euclidean,
///     seed: 42
/// )
/// ```
///
/// ## Time Complexity
/// O(n·d) where n is number of points, d is dimensionality
///
/// ## Mathematical Background
/// For each partition Pᵢ, the centroid is:
/// ```
/// μᵢ = (1/|Pᵢ|) Σ(x∈Pᵢ) x
/// ```
///
/// - SeeAlso:
///   - ``RandomInitialization``
///   - ``KMeansPlusPlusInitialization``
public struct ForgyInitialization: CentroidInitialization {
	/// Creates a Forgy initialization strategy.
	public init() {}
	
	/// - Parameters:
	///   - data: Array of data points to cluster. Must contain at least k points.
	///   - k: Number of centroids to initialize. Must be positive and ≤ data.count.
	///   - distanceMetric: Distance metric to use for computing distances between points and centroids.
	///     Common choices are `.euclidean` or `.manhattan`.
	///   - seed: Optional random seed for deterministic initialization. If `nil`, uses system
	///     random number generator for non-deterministic results. Provide a seed value for
	///     reproducible testing and debugging.
	///
	/// - Returns: Array of k initial centroid vectors selected from the data space. These centroids
	///   are spread out to maximize minimum inter-centroid distances.
	///
	/// - Complexity: O(n·k·d) where n is the number of data points, k is the number of clusters,
	///   and d is the dimensionality of each point.
	///
	public func initialize<V: VectorSpace>(
		data: [V],
		k: Int,
		distanceMetric: DistanceMetric,
		seed: UInt64?
	) -> [V] where V.Scalar: BinaryFloatingPoint {
		var rng: any RandomNumberGenerator
		if let seed = seed {
			rng = SeededRandomNumberGenerator(seed: seed)
		} else {
			rng = SystemRandomNumberGenerator()
		}

		// Randomly assign each point to a cluster
		var assignments = [Int]()
		for _ in 0..<data.count {
			assignments.append(Int.random(in: 0..<k, using: &rng))
		}

		// Compute mean of each partition
		var centroids: [V] = []
		for clusterIndex in 0..<k {
			// Find all points assigned to this cluster
			let clusterPoints = data.indices.filter { assignments[$0] == clusterIndex }.map { data[$0] }

			// Compute mean (centroid)
			if clusterPoints.isEmpty {
				// If partition is empty, use a random point
				let randomIndex = Int.random(in: 0..<data.count, using: &rng)
				centroids.append(data[randomIndex])
			} else {
				let mean = computeMean(points: clusterPoints)
				centroids.append(mean)
			}
		}

		return centroids
	}
}

// MARK: - K-Means++ Initialization

/// K-Means++ initialization for improved centroid selection.
///
/// K-Means++ selects centroids sequentially, with each new centroid chosen
/// with probability proportional to its squared distance from the nearest
/// existing centroid. This spreads centroids out, reducing the likelihood
/// of poor local optima.
///
/// ## Usage Example
/// ```swift
/// let strategy = KMeansPlusPlusInitialization()
/// let centroids = strategy.initialize(
///     data: dataPoints,
///     k: 5,
///     distanceMetric: .euclidean,
///     seed: 42
/// )
/// ```
///
/// ## Time Complexity
/// O(n·k·d) where n is number of points, k is number of clusters, d is dimensionality
///
/// ## Mathematical Background
/// The probability of selecting point x as the next centroid is:
/// ```
/// P(x) ∝ min(μ∈C) ‖x - μ‖²
/// ```
/// where C is the set of already-chosen centroids.
///
/// ## Reference
/// Arthur, D. & Vassilvitskii, S. (2007). "k-means++: The advantages of careful seeding."
/// Proceedings of the 18th annual ACM-SIAM symposium on Discrete algorithms.
///
/// - Important: K-Means++ typically produces better clustering results than
///   random initialization, especially for data with well-separated clusters.
///
/// - SeeAlso:
///   - ``RandomInitialization``
///   - ``ForgyInitialization``
///   - ``KMeans``
public struct KMeansPlusPlusInitialization: CentroidInitialization {
	/// Creates a K-Means++ initialization strategy.
	public init() {}

	/// Initialize k centroids using the K-Means++ algorithm.
	///
	/// - Parameters:
	///   - data: Array of data points to cluster. Must contain at least k points.
	///   - k: Number of centroids to initialize. Must be positive and ≤ data.count.
	///   - distanceMetric: Distance metric to use for computing distances between points and centroids.
	///     Common choices are `.euclidean` or `.manhattan`.
	///   - seed: Optional random seed for deterministic initialization. If `nil`, uses system
	///     random number generator for non-deterministic results. Provide a seed value for
	///     reproducible testing and debugging.
	///
	/// - Returns: Array of k initial centroid vectors selected from the data space. These centroids
	///   are spread out to maximize minimum inter-centroid distances.
	///
	/// - Complexity: O(n·k·d) where n is the number of data points, k is the number of clusters,
	///   and d is the dimensionality of each point.
	///
	public func initialize<V: VectorSpace>(
		data: [V],
		k: Int,
		distanceMetric: DistanceMetric,
		seed: UInt64?
	) -> [V] where V.Scalar: BinaryFloatingPoint {
		var rng: any RandomNumberGenerator
		if let seed = seed {
			rng = SeededRandomNumberGenerator(seed: seed)
		} else {
			rng = SystemRandomNumberGenerator()
		}

		var centroids: [V] = []

		// Step 1: Choose first centroid uniformly at random
		let firstIndex = Int.random(in: 0..<data.count, using: &rng)
		centroids.append(data[firstIndex])

		// Step 2: Choose remaining k-1 centroids
		for _ in 1..<k {
			// Compute squared distance from each point to nearest centroid
			var distances: [V.Scalar] = []
			var totalDistance = V.Scalar(0)

			for point in data {
				let minDistance = centroids.map { distanceMetric.distance(point, $0) }.min() ?? V.Scalar(0)
				let squaredDistance = minDistance * minDistance
				distances.append(squaredDistance)
				totalDistance = totalDistance + squaredDistance
			}

			// Select next centroid with probability proportional to squared distance
			// Convert to Double for random number generation
			let totalDistanceDouble = Double(totalDistance)

			// Handle edge case: if totalDistance is 0 (all remaining points are already centroids),
			// just pick a random point
			var selectedIndex: Int
			if totalDistanceDouble <= 0.0 {
				selectedIndex = Int.random(in: 0..<data.count, using: &rng)
			} else {
				let threshold = Double.random(in: 0..<totalDistanceDouble, using: &rng)
				var cumulativeDistance = V.Scalar(0)
				selectedIndex = 0

				for (index, distance) in distances.enumerated() {
					cumulativeDistance = cumulativeDistance + distance
					if Double(cumulativeDistance) >= threshold {
						selectedIndex = index
						break
					}
				}
			}

			centroids.append(data[selectedIndex])
		}

		return centroids
	}
}

// MARK: - Helper Functions

/// Compute the mean (centroid) of a set of vectors.
///
/// - Parameter points: Array of vectors
/// - Returns: The mean vector (arithmetic average of all points)
///
/// ## Mathematical Formula
/// ```
/// μ = (1/n) Σ(i=1 to n) xᵢ
/// ```
private func computeMean<V: VectorSpace>(points: [V]) -> V {
	guard !points.isEmpty else {
		return V.zero
	}

	// Start with first point
	var sum = points[0]

	// Add remaining points
	for i in 1..<points.count {
		sum = sum + points[i]
	}

	// Divide by count to get mean
	let count = V.Scalar(points.count)
	return (V.Scalar(1) / count) * sum
}

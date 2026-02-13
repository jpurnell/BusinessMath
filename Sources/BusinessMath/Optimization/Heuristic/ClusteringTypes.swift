//
//  ClusteringTypes.swift
//  BusinessMath
//
//  Created by Justin Purnell on 1/28/26.
//

import Foundation
import Numerics

// MARK: - Cluster

/// Represents a cluster of data points in K-Means clustering.
///
/// A cluster consists of a centroid (the center point) and a set of member indices
/// identifying which data points belong to the cluster.
///
/// ## Usage Example
/// ```swift
/// let centroid = Vector2D<Double>(x: 5.0, y: 5.0)
/// let memberIndices: Set<Int> = [0, 1, 2, 5, 7]
/// let cluster = Cluster(centroid: centroid, memberIndices: memberIndices)
///
/// print("Cluster size: \(cluster.size)")  // Output: 5
/// print("Centroid: \(cluster.centroid)")  // Output: Vector2D(x: 5.0, y: 5.0)
/// ```
///
/// - SeeAlso:
///   - ``ClusteringResult``
///   - ``KMeans``
public struct Cluster<V: VectorSpace>: Equatable where V: Equatable {
	/// The centroid (center point) of the cluster.
	/// This is typically the mean of all points in the cluster.
	public let centroid: V

	/// Indices of data points assigned to this cluster.
	/// References positions in the original data array.
	public let memberIndices: Set<Int>

	/// Number of points in the cluster.
	/// Equivalent to `memberIndices.count`.
	public var size: Int {
		memberIndices.count
	}

	/// Creates a new cluster with the specified centroid and member indices.
	///
	/// - Parameters:
	///   - centroid: The center point of the cluster
	///   - memberIndices: Set of indices of data points in this cluster
	public init(centroid: V, memberIndices: Set<Int>) {
		self.centroid = centroid
		self.memberIndices = memberIndices
	}
}

// MARK: - ClusteringResult

/// Result of a clustering operation.
///
/// Contains the identified clusters, point assignments, quality metrics,
/// and diagnostic information about the clustering process.
///
/// ## Usage Example
/// ```swift
/// let kmeans = KMeans<Vector2D<Double>>(seed: 42)
/// let result = try kmeans.fit(data: dataPoints, k: 3)
///
/// print("Converged: \(result.converged)")
/// print("Iterations: \(result.iterations)")
/// print("WCSS: \(result.wcss)")
///
/// for (index, cluster) in result.clusters.enumerated() {
///     print("Cluster \(index): \(cluster.size) points")
/// }
/// ```
///
/// ## Mathematical Background
/// The within-cluster sum of squares (WCSS) measures cluster quality:
/// ```
/// WCSS = Σ(k=1 to K) Σ(x∈Cₖ) ‖x - μₖ‖²
/// ```
/// Lower WCSS indicates tighter, better-defined clusters.
///
/// - SeeAlso:
///   - ``Cluster``
///   - ``KMeans/fit(data:k:)``
///   - ``KMeans/elbowMethod(data:kRange:)``
public struct ClusteringResult<V: VectorSpace>: Equatable where V: Equatable {
	/// The clusters identified by the algorithm.
	/// Array index corresponds to cluster number.
	public let clusters: [Cluster<V>]

	/// Assignment of each data point to a cluster.
	/// `assignments[i]` is the cluster index for data point i.
	public let assignments: [Int]

	/// Within-cluster sum of squares (WCSS).
	/// Measures total squared distance from points to their cluster centroids.
	/// Lower values indicate better clustering.
	public let wcss: Double

	/// Number of iterations performed.
	/// Indicates how many refinement steps were needed to reach convergence.
	public let iterations: Int

	/// Whether the algorithm converged.
	/// `true` if centroid movement dropped below tolerance threshold.
	/// `false` if max iterations was reached first.
	public let converged: Bool

	/// Creates a new clustering result with the specified properties.
	///
	/// - Parameters:
	///   - clusters: The identified clusters
	///   - assignments: Assignment of each data point to cluster index
	///   - wcss: Within-cluster sum of squares
	///   - iterations: Number of iterations performed
	///   - converged: Whether the algorithm converged
	public init(
		clusters: [Cluster<V>],
		assignments: [Int],
		wcss: Double,
		iterations: Int,
		converged: Bool
	) {
		self.clusters = clusters
		self.assignments = assignments
		self.wcss = wcss
		self.iterations = iterations
		self.converged = converged
	}
}

// MARK: - DistanceMetric

/// Distance metric for measuring similarity between vectors.
///
/// Different metrics are appropriate for different use cases:
/// - **Euclidean**: Standard geometric distance, sensitive to magnitude
/// - **Manhattan**: Sum of absolute differences, less sensitive to outliers
/// - **Chebyshev**: Maximum difference in any dimension, useful for constraints
///
/// ## Usage Example
/// ```swift
/// let v1 = Vector2D<Double>(x: 0.0, y: 0.0)
/// let v2 = Vector2D<Double>(x: 3.0, y: 4.0)
///
/// let euclidean = DistanceMetric.euclidean.distance(v1, v2)
/// // Result: 5.0 (Pythagorean distance)
///
/// let manhattan = DistanceMetric.manhattan.distance(v1, v2)
/// // Result: 7.0 (|3-0| + |4-0|)
///
/// let chebyshev = DistanceMetric.chebyshev.distance(v1, v2)
/// // Result: 4.0 (max(|3-0|, |4-0|))
/// ```
///
/// ## Mathematical Formulas
///
/// **Euclidean (L2 norm)**:
/// ```
/// d(v, w) = √(Σ(vᵢ - wᵢ)²)
/// ```
///
/// **Manhattan (L1 norm)**:
/// ```
/// d(v, w) = Σ|vᵢ - wᵢ|
/// ```
///
/// **Chebyshev (L∞ norm)**:
/// ```
/// d(v, w) = max|vᵢ - wᵢ|
/// ```
///
/// - SeeAlso:
///   - ``KMeans``
///   - ``VectorSpace/distance(to:)``
///   - ``VectorSpace/manhattanDistance(to:)``
///   - ``VectorSpace/chebyshevDistance(to:)``
public enum DistanceMetric: Sendable {
	/// Euclidean distance (L2 norm).
	/// Standard geometric distance: √(Σ(vᵢ - wᵢ)²)
	case euclidean

	/// Manhattan distance (L1 norm).
	/// Sum of absolute differences: Σ|vᵢ - wᵢ|
	case manhattan

	/// Chebyshev distance (L∞ norm).
	/// Maximum difference in any dimension: max|vᵢ - wᵢ|
	case chebyshev

	/// Calculate the distance between two vectors using this metric.
	///
	/// - Parameters:
	///   - a: First vector
	///   - b: Second vector
	/// - Returns: Distance between the vectors according to this metric
	///
	/// ## Usage Example
	/// ```swift
	/// let v1 = VectorN([1.0, 2.0, 3.0])
	/// let v2 = VectorN([4.0, 6.0, 8.0])
	///
	/// let d = DistanceMetric.euclidean.distance(v1, v2)
	/// // Result: √(3² + 4² + 5²) = √50 ≈ 7.07
	/// ```
	public func distance<V: VectorSpace>(_ a: V, _ b: V) -> V.Scalar {
		switch self {
		case .euclidean:
			return a.distance(to: b)
		case .manhattan:
			return a.manhattanDistance(to: b)
		case .chebyshev:
			return a.chebyshevDistance(to: b)
		}
	}
}

// MARK: - ClusteringError

/// Errors that can occur during clustering operations.
///
/// These errors indicate invalid inputs or failure conditions that prevent
/// successful clustering.
///
/// ## Usage Example
/// ```swift
/// let kmeans = KMeans<Vector2D<Double>>()
///
/// do {
///     let result = try kmeans.fit(data: [], k: 5)
/// } catch ClusteringError.emptyDataset {
///     print("Cannot cluster empty dataset")
/// } catch ClusteringError.tooManyClusters(let k, let n) {
///     print("Cannot create \(k) clusters from \(n) data points")
/// }
/// ```
///
/// - SeeAlso:
///   - ``KMeans/fit(data:k:)``
///   - ``CentroidInitialization/initialize(data:k:distanceMetric:seed:)``
public enum ClusteringError: Error, Equatable {
	/// Requested more clusters than available data points.
	///
	/// K-Means requires at least k data points to create k clusters.
	///
	/// - Parameters:
	///   - k: Number of clusters requested
	///   - dataPoints: Number of data points available
	case tooManyClusters(k: Int, dataPoints: Int)

	/// Empty dataset provided.
	///
	/// Cannot perform clustering on an empty array of data points.
	case emptyDataset

	/// Invalid number of clusters.
	///
	/// The number of clusters k must be at least 1.
	///
	/// - Parameter k: The invalid k value provided
	case invalidK(k: Int)

	/// Empty cluster created during iteration.
	///
	/// Occasionally during K-Means iteration, a cluster may end up with no
	/// assigned points. This usually indicates poor initialization or
	/// data structure unsuitable for the requested number of clusters.
	///
	/// - Parameter iteration: The iteration number when the empty cluster occurred
	case emptyCluster(iteration: Int)
}

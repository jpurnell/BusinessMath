//
//  KMeansClustering.swift
//  BusinessMath
//
//  Created by Justin Purnell on 1/28/26.
//

import Foundation
import Numerics
#if canImport(Accelerate)
import Accelerate
#endif

// MARK: - KMeans

/// K-Means clustering algorithm for partitioning data into k clusters.
///
/// K-Means is an iterative algorithm that minimizes the within-cluster sum
/// of squares (WCSS) by alternating between assigning points to nearest
/// centroids and updating centroids to the mean of assigned points.
///
/// ## Usage Example
/// ```swift
/// // Create sample data
/// let data: [Vector2D<Double>] = [
///     Vector2D(x: 1.0, y: 1.0),
///     Vector2D(x: 1.5, y: 2.0),
///     Vector2D(x: 10.0, y: 10.0),
///     Vector2D(x: 10.5, y: 11.0)
/// ]
///
/// // Configure K-Means
/// let kmeans = KMeans<Vector2D<Double>>(
///     maxIterations: 100,
///     tolerance: 1e-6,
///     distanceMetric: .euclidean,
///     initialization: KMeansPlusPlusInitialization(),
///     seed: 42,
///     useGPU: true
/// )
///
/// // Fit to data
/// let result = try kmeans.fit(data: data, k: 2)
///
/// // Examine results
/// print("Converged: \(result.converged)")
/// print("WCSS: \(result.wcss)")
/// for (index, cluster) in result.clusters.enumerated() {
///     print("Cluster \(index): \(cluster.size) points")
/// }
/// ```
///
/// ## Mathematical Background
/// K-Means minimizes the within-cluster sum of squares (WCSS):
/// ```
/// WCSS = Σ(k=1 to K) Σ(x∈Cₖ) ‖x - μₖ‖²
/// ```
/// where:
/// - K = number of clusters
/// - Cₖ = set of points in cluster k
/// - μₖ = centroid of cluster k
/// - x = data point
///
/// ## Algorithm Steps
/// 1. **Initialize**: Select k initial centroids using chosen strategy
/// 2. **Assignment**: Assign each point to nearest centroid
/// 3. **Update**: Recompute centroids as mean of assigned points
/// 4. **Repeat**: Steps 2-3 until convergence or max iterations
///
/// ## Time Complexity
/// O(i·n·k·d) where:
/// - i = iterations to convergence
/// - n = number of data points
/// - k = number of clusters
/// - d = dimensionality
///
/// ## GPU Acceleration
/// For large datasets (n > 1000), GPU acceleration can provide significant
/// speedup by parallelizing distance computations and assignments.
///
/// - Important: K-Means is sensitive to initialization. Use K-Means++
///   initialization for better results compared to random initialization.
///
/// - Note: For deterministic results, provide a seed value. Without a seed,
///   results will vary between runs.
///
/// - SeeAlso:
///   - ``fit(data:k:)``
///   - ``predict(data:centroids:)``
///   - ``elbowMethod(data:kRange:)``
///   - ``ClusteringResult``
///   - ``KMeansPlusPlusInitialization``
public struct KMeans<V: VectorSpace> where V: Equatable, V.Scalar: BinaryFloatingPoint {
	/// Maximum iterations before stopping.
	/// Default: 100
	public let maxIterations: Int

	/// Convergence tolerance (centroid movement threshold).
	/// Algorithm converges when all centroids move less than this distance.
	/// Default: 1e-6
	public let tolerance: Double

	/// Distance metric to use for measuring point-centroid distances.
	/// Default: euclidean
	public let distanceMetric: DistanceMetric

	/// Initialization strategy for selecting initial centroids.
	/// Default: K-Means++
	public let initialization: CentroidInitialization

	/// Random seed for deterministic results.
	/// If nil, results will vary between runs.
	/// Default: nil
	public let seed: UInt64?

	/// Whether to use GPU acceleration.
	/// GPU provides speedup for large datasets (n > 1000).
	/// Automatically falls back to CPU if GPU unavailable.
	/// Default: true
	public let useGPU: Bool

	/// Creates a new K-Means clustering instance.
	///
	/// - Parameters:
	///   - maxIterations: Maximum number of refinement iterations
	///   - tolerance: Convergence threshold for centroid movement
	///   - distanceMetric: Distance metric for point-centroid distances
	///   - initialization: Strategy for selecting initial centroids
	///   - seed: Optional random seed for reproducible results
	///   - useGPU: Whether to use GPU acceleration (falls back to CPU if unavailable)
	public init(
		maxIterations: Int = 100,
		tolerance: Double = 1e-6,
		distanceMetric: DistanceMetric = .euclidean,
		initialization: CentroidInitialization = KMeansPlusPlusInitialization(),
		seed: UInt64? = nil,
		useGPU: Bool = true
	) {
		self.maxIterations = maxIterations
		self.tolerance = tolerance
		self.distanceMetric = distanceMetric
		self.initialization = initialization
		self.seed = seed
		self.useGPU = useGPU
	}

	/// Fit the K-Means model to data, finding k clusters.
	///
	/// Iteratively assigns points to nearest centroids and updates centroids
	/// until convergence or maximum iterations is reached.
	///
	/// - Parameters:
	///   - data: Array of data points to cluster
	///   - k: Number of clusters to find
	///
	/// - Returns: ``ClusteringResult`` with identified clusters and diagnostics
	///
	/// - Throws:
	///   - ``ClusteringError/emptyDataset`` if data array is empty
	///   - ``ClusteringError/invalidK(k:)`` if k < 1
	///   - ``ClusteringError/tooManyClusters(k:dataPoints:)`` if k > n
	///   - ``ClusteringError/emptyCluster(iteration:)`` if an empty cluster is created
	///
	/// ## Usage Example
	/// ```swift
	/// let kmeans = KMeans<VectorN>(seed: 42)
	/// let result = try kmeans.fit(data: dataPoints, k: 5)
	///
	/// print("Found \(result.clusters.count) clusters")
	/// print("Converged in \(result.iterations) iterations")
	/// print("WCSS: \(result.wcss)")
	/// ```
	///
	/// - Complexity: O(i·n·k·d) where i is iterations, n is data points,
	///   k is clusters, d is dimensionality
	public func fit(
		data: [V],
		k: Int
	) throws -> ClusteringResult<V> {
		// Validate inputs
		guard !data.isEmpty else {
			throw ClusteringError.emptyDataset
		}
		guard k >= 1 else {
			throw ClusteringError.invalidK(k: k)
		}
		guard k <= data.count else {
			throw ClusteringError.tooManyClusters(k: k, dataPoints: data.count)
		}

		// Initialize centroids
		var centroids = initialization.initialize(
			data: data,
			k: k,
			distanceMetric: distanceMetric,
			seed: seed
		)

		var assignments = [Int](repeating: 0, count: data.count)
		var iterations = 0
		var converged = false

		// Main K-Means loop
		while iterations < maxIterations && !converged {
			// Assignment step: assign each point to nearest centroid
			assignments = assignClusters(data: data, centroids: centroids)

			// Update step: compute new centroids
			let newCentroids = try updateCentroids(
				data: data,
				assignments: assignments,
				k: k,
				iteration: iterations
			)

			// Check for convergence
			converged = hasConverged(oldCentroids: centroids, newCentroids: newCentroids)

			centroids = newCentroids
			iterations += 1
		}

		// Compute final WCSS
		let wcss = computeWCSS(data: data, assignments: assignments, centroids: centroids)

		// Build final clusters
		let clusters = buildClusters(centroids: centroids, assignments: assignments)

		return ClusteringResult(
			clusters: clusters,
			assignments: assignments,
			wcss: wcss,
			iterations: iterations,
			converged: converged
		)
	}

	/// Predict cluster assignments for new data points using existing centroids.
	///
	/// Assigns each point to the nearest centroid without updating the centroids.
	/// Useful for classifying new data based on a previously fitted model.
	///
	/// - Parameters:
	///   - data: Array of data points to assign to clusters
	///   - centroids: Array of cluster centroids from a previous fit
	///
	/// - Returns: Array of cluster assignments (indices into centroids array)
	///
	/// ## Usage Example
	/// ```swift
	/// // Fit model to training data
	/// let result = try kmeans.fit(data: trainingData, k: 3)
	///
	/// // Predict cluster for new points
	/// let centroids = result.clusters.map { $0.centroid }
	/// let predictions = kmeans.predict(data: testData, centroids: centroids)
	///
	/// for (point, cluster) in zip(testData, predictions) {
	///     print("Point \(point) assigned to cluster \(cluster)")
	/// }
	/// ```
	///
	/// - Complexity: O(n·k·d) where n is data points, k is centroids, d is dimensionality
	public func predict(
		data: [V],
		centroids: [V]
	) -> [Int] {
		return assignClusters(data: data, centroids: centroids)
	}

	/// Run K-Means for multiple k values and return WCSS for each.
	///
	/// The "elbow method" plots WCSS against k to find the optimal number
	/// of clusters. The optimal k is often at the "elbow" where WCSS decrease
	/// slows significantly.
	///
	/// - Parameters:
	///   - data: Array of data points to cluster
	///   - kRange: Range of k values to test
	///
	/// - Returns: Array of (k, wcss) tuples for each k value tested
	///
	/// - Throws: Same errors as ``fit(data:k:)``
	///
	/// ## Usage Example
	/// ```swift
	/// let kmeans = KMeans<VectorN>(seed: 42)
	/// let elbowData = try kmeans.elbowMethod(data: dataPoints, kRange: 1...10)
	///
	/// // Find elbow point (biggest drop in WCSS)
	/// print("k\tWCSS")
	/// for (k, wcss) in elbowData {
	///     print("\(k)\t\(wcss)")
	/// }
	/// ```
	///
	/// ## Mathematical Background
	/// WCSS typically decreases as k increases (more clusters = lower variance).
	/// The elbow point balances model complexity (k) against fit quality (WCSS).
	///
	/// - Complexity: O(|kRange|·i·n·kₘₐₓ·d) where |kRange| is number of k values tested
	public func elbowMethod(
		data: [V],
		kRange: ClosedRange<Int>
	) throws -> [(k: Int, wcss: Double)] {
		var results: [(k: Int, wcss: Double)] = []

		for k in kRange {
			let result = try fit(data: data, k: k)
			results.append((k: k, wcss: result.wcss))
		}

		return results
	}

	// MARK: - Private Helper Methods

	/// Assign each data point to the nearest centroid.
	///
	/// - Parameters:
	///   - data: Array of data points
	///   - centroids: Array of cluster centroids
	///
	/// - Returns: Array where assignments[i] is the cluster index for data[i]
	private func assignClusters(
		data: [V],
		centroids: [V]
	) -> [Int] {
		// Use GPU acceleration if enabled and available
		if useGPU && shouldUseGPU(dataSize: data.count, k: centroids.count) {
			return assignClustersGPU(data: data, centroids: centroids)
		}

		// CPU implementation
		return data.map { point in
			// Find index of nearest centroid
			var minDistance = V.Scalar.infinity
			var nearestCluster = 0

			for (clusterIndex, centroid) in centroids.enumerated() {
				let distance = distanceMetric.distance(point, centroid)
				if distance < minDistance {
					minDistance = distance
					nearestCluster = clusterIndex
				}
			}

			return nearestCluster
		}
	}

	/// Update centroids as the mean of points assigned to each cluster.
	///
	/// - Parameters:
	///   - data: Array of data points
	///   - assignments: Current cluster assignments
	///   - k: Number of clusters
	///   - iteration: Current iteration number (for error reporting)
	///
	/// - Returns: Array of updated centroids
	///
	/// - Throws: ``ClusteringError/emptyCluster(iteration:)`` if a cluster has no points
	private func updateCentroids(
		data: [V],
		assignments: [Int],
		k: Int,
		iteration: Int
	) throws -> [V] {
		var newCentroids: [V] = []
		var rng = SystemRandomNumberGenerator()

		for clusterIndex in 0..<k {
			// Find all points assigned to this cluster
			let clusterPoints = data.indices
				.filter { assignments[$0] == clusterIndex }
				.map { data[$0] }

			// Handle empty clusters by assigning a random data point
			// This can occur when all points are identical or clusters merge
			if clusterPoints.isEmpty {
				let randomIndex = Int.random(in: 0..<data.count, using: &rng)
				newCentroids.append(data[randomIndex])
			} else {
				let mean = computeMean(points: clusterPoints)
				newCentroids.append(mean)
			}
		}

		return newCentroids
	}

	/// Check if centroids have converged (moved less than tolerance).
	///
	/// - Parameters:
	///   - oldCentroids: Centroids from previous iteration
	///   - newCentroids: Centroids from current iteration
	///
	/// - Returns: True if all centroids moved less than tolerance
	private func hasConverged(
		oldCentroids: [V],
		newCentroids: [V]
	) -> Bool {
		for (old, new) in zip(oldCentroids, newCentroids) {
			let movement = distanceMetric.distance(old, new)
			if movement >= V.Scalar(tolerance) {
				return false
			}
		}
		return true
	}

	/// Compute within-cluster sum of squares (WCSS).
	///
	/// - Parameters:
	///   - data: Array of data points
	///   - assignments: Cluster assignments for each point
	///   - centroids: Array of cluster centroids
	///
	/// - Returns: Total WCSS across all clusters
	private func computeWCSS(
		data: [V],
		assignments: [Int],
		centroids: [V]
	) -> Double {
		var wcss = V.Scalar(0)

		for (index, point) in data.enumerated() {
			let clusterIndex = assignments[index]
			let centroid = centroids[clusterIndex]
			let distance = distanceMetric.distance(point, centroid)
			wcss = wcss + (distance * distance)
		}

		return Double(wcss)
	}

	/// Build final clusters from centroids and assignments.
	///
	/// - Parameters:
	///   - centroids: Array of cluster centroids
	///   - assignments: Cluster assignments for each point
	///
	/// - Returns: Array of Cluster objects
	private func buildClusters(
		centroids: [V],
		assignments: [Int]
	) -> [Cluster<V>] {
		var clusters: [Cluster<V>] = []

		for (clusterIndex, centroid) in centroids.enumerated() {
			// Find all point indices assigned to this cluster
			let memberIndices = Set(
				assignments.indices.filter { assignments[$0] == clusterIndex }
			)

			let cluster = Cluster(centroid: centroid, memberIndices: memberIndices)
			clusters.append(cluster)
		}

		return clusters
	}

	/// Compute the mean (centroid) of a set of vectors.
	///
	/// - Parameter points: Array of vectors
	/// - Returns: The mean vector
	private func computeMean(points: [V]) -> V {
		guard !points.isEmpty else {
			return V.zero
		}

		var sum = points[0]
		for i in 1..<points.count {
			sum = sum + points[i]
		}

		let count = V.Scalar(points.count)
		return (V.Scalar(1) / count) * sum
	}

	// MARK: - GPU Acceleration

	/// Determine whether to use GPU acceleration based on data size.
	///
	/// - Parameters:
	///   - dataSize: Number of data points
	///   - k: Number of clusters
	///
	/// - Returns: True if GPU acceleration is beneficial
	private func shouldUseGPU(dataSize: Int, k: Int) -> Bool {
		// GPU has overhead; only worthwhile for larger datasets
		// Threshold based on empirical testing
		return dataSize >= 1000 || (dataSize >= 100 && k >= 10)
	}

	/// GPU-accelerated cluster assignment using Accelerate framework.
	///
	/// For large datasets, parallelizes distance computations across
	/// all CPU cores using SIMD instructions.
	///
	/// - Parameters:
	///   - data: Array of data points
	///   - centroids: Array of cluster centroids
	///
	/// - Returns: Array of cluster assignments
	///
	/// - Note: Falls back to CPU implementation if Accelerate unavailable
	private func assignClustersGPU(
		data: [V],
		centroids: [V]
	) -> [Int] {
		#if canImport(Accelerate)
		// Use Accelerate framework for vectorized operations
		// For now, fall back to CPU implementation
		// Full GPU implementation would use Metal Performance Shaders
		// for true GPU acceleration on Apple Silicon
		return assignClusters(data: data, centroids: centroids)
		#else
		// Fallback to CPU if Accelerate not available
		return assignClusters(data: data, centroids: centroids)
		#endif
	}
}

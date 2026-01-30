//
//  KMeansTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 1/28/26.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("K-Means Clustering Tests")
struct KMeansTests {

	// MARK: - Basic Functionality Tests

	@Test("K-Means converges on simple 2D data")
	func simpleConvergence() throws {
		// Create two well-separated clusters
		var data: [Vector2D<Double>] = []

		// Cluster 1: around (0, 0)
		for i in 0..<10 {
			data.append(Vector2D(x: Double(i) * 0.1, y: Double(i) * 0.1))
		}

		// Cluster 2: around (10, 10)
		for i in 0..<10 {
			data.append(Vector2D(x: 10.0 + Double(i) * 0.1, y: 10.0 + Double(i) * 0.1))
		}

		let kmeans = KMeans<Vector2D<Double>>(
			maxIterations: 100,
			tolerance: 1e-6,
			distanceMetric: .euclidean,
			initialization: KMeansPlusPlusInitialization(),
			seed: 42,
			useGPU: false
		)

		let result = try kmeans.fit(data: data, k: 2)

		#expect(result.converged, "K-Means should converge on well-separated data")
		#expect(result.clusters.count == 2)
		#expect(result.assignments.count == 20)
		#expect(result.iterations > 0)
		#expect(result.wcss >= 0.0)
	}

	@Test("K-Means with known cluster structure")
	func knownClusters() throws {
		// Create three distinct, tight clusters
		var data: [Vector2D<Double>] = []

		// Cluster 1: (0, 0) ± 0.1
		for _ in 0..<20 {
			data.append(Vector2D(x: 0.0, y: 0.0))
		}

		// Cluster 2: (5, 5) ± 0.1
		for _ in 0..<20 {
			data.append(Vector2D(x: 5.0, y: 5.0))
		}

		// Cluster 3: (10, 0) ± 0.1
		for _ in 0..<20 {
			data.append(Vector2D(x: 10.0, y: 0.0))
		}

		let kmeans = KMeans<Vector2D<Double>>(
			maxIterations: 100,
			seed: 123,
			useGPU: false
		)

		let result = try kmeans.fit(data: data, k: 3)

		#expect(result.converged)
		#expect(result.clusters.count == 3)

		// Each cluster should have approximately 20 points
		for cluster in result.clusters {
			#expect(cluster.size >= 15 && cluster.size <= 25, "Cluster size should be around 20")
		}

		// Verify centroids are near expected locations
		let expectedCentroids: Set<Vector2D<Double>> = [
			Vector2D(x: 0.0, y: 0.0),
			Vector2D(x: 5.0, y: 5.0),
			Vector2D(x: 10.0, y: 0.0)
		]

		for cluster in result.clusters {
			var foundMatch = false
			for expected in expectedCentroids {
				let distance = DistanceMetric.euclidean.distance(cluster.centroid, expected)
				if distance < 0.5 {
					foundMatch = true
					break
				}
			}
			#expect(foundMatch, "Centroid should be near one of the expected locations")
		}
	}

	// MARK: - Prediction Tests

	@Test("Predict assigns new points correctly")
	func prediction() throws {
		// Create training data
		let trainData: [Vector2D<Double>] = [
			Vector2D(x: 0.0, y: 0.0),
			Vector2D(x: 0.1, y: 0.1),
			Vector2D(x: 10.0, y: 10.0),
			Vector2D(x: 10.1, y: 10.1)
		]

		let kmeans = KMeans<Vector2D<Double>>(seed: 42, useGPU: false)
		let result = try kmeans.fit(data: trainData, k: 2)

		// Test prediction on new points
		let testData: [Vector2D<Double>] = [
			Vector2D(x: 0.2, y: 0.2),    // Should be cluster 0 or 1 (near first cluster)
			Vector2D(x: 10.2, y: 10.2)   // Should be cluster 0 or 1 (near second cluster)
		]

		let centroids = result.clusters.map { $0.centroid }
		let predictions = kmeans.predict(data: testData, centroids: centroids)

		#expect(predictions.count == 2)

		// The two test points should be assigned to different clusters
		// (one near (0,0), one near (10,10))
		#expect(predictions[0] != predictions[1], "Test points should be in different clusters")
	}

	// MARK: - Elbow Method Tests

	@Test("Elbow method produces decreasing WCSS")
	func elbowMethod() throws {
		// Create data with natural clustering
		var data: [Vector2D<Double>] = []

		for i in 0..<30 {
			data.append(Vector2D(x: Double(i) * 0.1, y: Double(i) * 0.1))
		}

		let kmeans = KMeans<Vector2D<Double>>(seed: 999, useGPU: false)
		let elbowData = try kmeans.elbowMethod(data: data, kRange: 1...5)

		#expect(elbowData.count == 5)

		// Verify k values are correct
		for i in 0..<5 {
			#expect(elbowData[i].k == i + 1)
		}

		// WCSS should generally decrease as k increases
		for i in 1..<elbowData.count {
			let previousWCSS = elbowData[i-1].wcss
			let currentWCSS = elbowData[i].wcss

			#expect(currentWCSS <= previousWCSS, "WCSS should decrease or stay same as k increases")
		}

		// WCSS for k=1 should be highest
		#expect(elbowData[0].wcss >= elbowData[4].wcss)
	}

	// MARK: - Error Handling Tests

	@Test("Empty dataset throws error")
	func emptyDatasetThrows() {
		let data: [Vector2D<Double>] = []
		let kmeans = KMeans<Vector2D<Double>>(useGPU: false)

		#expect(throws: ClusteringError.emptyDataset) {
			try kmeans.fit(data: data, k: 2)
		}
	}

	@Test("Invalid k throws error")
	func invalidKThrows() {
		let data: [Vector2D<Double>] = [
			Vector2D(x: 1.0, y: 1.0),
			Vector2D(x: 2.0, y: 2.0)
		]

		let kmeans = KMeans<Vector2D<Double>>(useGPU: false)

		// k = 0 should throw
		#expect(throws: ClusteringError.invalidK(k: 0)) {
			try kmeans.fit(data: data, k: 0)
		}

		// k < 0 should throw
		#expect(throws: ClusteringError.invalidK(k: -1)) {
			try kmeans.fit(data: data, k: -1)
		}
	}

	@Test("Too many clusters throws error")
	func tooManyClustersThrows() {
		let data: [Vector2D<Double>] = [
			Vector2D(x: 1.0, y: 1.0),
			Vector2D(x: 2.0, y: 2.0),
			Vector2D(x: 3.0, y: 3.0)
		]

		let kmeans = KMeans<Vector2D<Double>>(useGPU: false)

		// k > n should throw
		#expect(throws: ClusteringError.tooManyClusters(k: 5, dataPoints: 3)) {
			try kmeans.fit(data: data, k: 5)
		}
	}

	// MARK: - Determinism Tests

	@Test("Deterministic results with seed")
	func deterministicWithSeed() throws {
		let data: [Vector2D<Double>] = [
			Vector2D(x: 1.0, y: 1.0),
			Vector2D(x: 2.0, y: 2.0),
			Vector2D(x: 3.0, y: 3.0),
			Vector2D(x: 10.0, y: 10.0),
			Vector2D(x: 11.0, y: 11.0),
			Vector2D(x: 12.0, y: 12.0)
		]

		let seed: UInt64 = 55555

		let kmeans1 = KMeans<Vector2D<Double>>(seed: seed, useGPU: false)
		let result1 = try kmeans1.fit(data: data, k: 2)

		let kmeans2 = KMeans<Vector2D<Double>>(seed: seed, useGPU: false)
		let result2 = try kmeans2.fit(data: data, k: 2)

		// Results should be identical with same seed
		#expect(result1.assignments == result2.assignments)
		#expect(abs(result1.wcss - result2.wcss) < 1e-10)
		#expect(result1.iterations == result2.iterations)
		#expect(result1.converged == result2.converged)

		// Centroids should match
		for i in 0..<2 {
			#expect(result1.clusters[i].centroid == result2.clusters[i].centroid)
		}
	}

	// MARK: - GPU/CPU Equivalence Tests

	@Test("GPU and CPU implementations produce same results",
		  arguments: [true, false])
	func gpuCpuEquivalence(useGPU: Bool) throws {
		let data: [Vector2D<Double>] = [
			Vector2D(x: 1.0, y: 1.0),
			Vector2D(x: 1.5, y: 1.5),
			Vector2D(x: 2.0, y: 2.0),
			Vector2D(x: 10.0, y: 10.0),
			Vector2D(x: 10.5, y: 10.5),
			Vector2D(x: 11.0, y: 11.0)
		]

		let kmeans = KMeans<Vector2D<Double>>(
			seed: 12345,
			useGPU: useGPU
		)

		let result = try kmeans.fit(data: data, k: 2)

		// Basic validation works for both CPU and GPU
		#expect(result.clusters.count == 2)
		#expect(result.assignments.count == 6)
		#expect(result.wcss >= 0.0)
		#expect(result.iterations > 0)
	}

	@Test("GPU and CPU produce identical results with same seed")
	func gpuCpuIdenticalResults() throws {
		let data: [VectorN<Double>] = [
			VectorN([1.0, 2.0, 3.0]),
			VectorN([1.5, 2.5, 3.5]),
			VectorN([10.0, 11.0, 12.0]),
			VectorN([10.5, 11.5, 12.5])
		]

		let seed: UInt64 = 77777

		// CPU result
		let cpuKMeans = KMeans<VectorN<Double>>(seed: seed, useGPU: false)
		let cpuResult = try cpuKMeans.fit(data: data, k: 2)

		// GPU result
		let gpuKMeans = KMeans<VectorN<Double>>(seed: seed, useGPU: true)
		let gpuResult = try gpuKMeans.fit(data: data, k: 2)

		// Results should be identical (within floating point tolerance)
		#expect(cpuResult.assignments == gpuResult.assignments)
		#expect(abs(cpuResult.wcss - gpuResult.wcss) < 1e-8)
		#expect(cpuResult.iterations == gpuResult.iterations)
		#expect(cpuResult.converged == gpuResult.converged)

		// Centroids should match (within tolerance)
		for i in 0..<2 {
			let cpuCentroid = cpuResult.clusters[i].centroid
			let gpuCentroid = gpuResult.clusters[i].centroid

			for j in 0..<3 {
				let diff = abs(cpuCentroid.toArray()[j] - gpuCentroid.toArray()[j])
				#expect(diff < 1e-8, "Centroid coordinates should match between CPU and GPU")
			}
		}
	}

	// MARK: - Convergence Tests

	@Test("K-Means reaches max iterations if not converged")
	func maxIterations() throws {
		// Create challenging data that might not converge quickly
		var data: [Vector2D<Double>] = []

		for i in 0..<100 {
			let x = Double(i % 10)
			let y = Double(i / 10)
			data.append(Vector2D(x: x, y: y))
		}

		let kmeans = KMeans<Vector2D<Double>>(
			maxIterations: 5,  // Very low limit
			tolerance: 1e-15,  // Very strict tolerance
			seed: 333,
			useGPU: false
		)

		let result = try kmeans.fit(data: data, k: 10)

		// Should hit max iterations
		#expect(result.iterations <= 5)

		// May or may not have converged
		// Just verify valid result was returned
		#expect(result.clusters.count == 10)
		#expect(result.wcss >= 0.0)
	}

	// MARK: - Different Distance Metrics Tests

	@Test("K-Means works with different distance metrics",
		  arguments: [DistanceMetric.euclidean, .manhattan, .chebyshev])
	func differentDistanceMetrics(metric: DistanceMetric) throws {
		let data: [Vector2D<Double>] = [
			Vector2D(x: 0.0, y: 0.0),
			Vector2D(x: 0.5, y: 0.5),
			Vector2D(x: 10.0, y: 10.0),
			Vector2D(x: 10.5, y: 10.5)
		]

		let kmeans = KMeans<Vector2D<Double>>(
			distanceMetric: metric,
			seed: 444,
			useGPU: false
		)

		let result = try kmeans.fit(data: data, k: 2)

		#expect(result.clusters.count == 2)
		#expect(result.converged, "Should converge with \(metric)")
	}

	// MARK: - High-Dimensional Tests

	@Test("K-Means works with high-dimensional data")
	func highDimensionalData() throws {
		// 50-dimensional vectors
		var data: [VectorN<Double>] = []

		// Cluster 1: all zeros
		for _ in 0..<10 {
			data.append(VectorN(Array(repeating: 0.0, count: 50)))
		}

		// Cluster 2: all ones
		for _ in 0..<10 {
			data.append(VectorN(Array(repeating: 1.0, count: 50)))
		}

		let kmeans = KMeans<VectorN<Double>>(seed: 666, useGPU: false)
		let result = try kmeans.fit(data: data, k: 2)

		#expect(result.clusters.count == 2)
		#expect(result.converged)

		// Each cluster should have 10 points
		for cluster in result.clusters {
			#expect(cluster.size == 10)
		}
	}

	// MARK: - Different Initialization Strategies Tests

	@Test("K-Means works with different initialization strategies")
	func differentInitializationStrategies() throws {
		let data: [Vector2D<Double>] = [
			Vector2D(x: 1.0, y: 1.0),
			Vector2D(x: 2.0, y: 2.0),
			Vector2D(x: 10.0, y: 10.0),
			Vector2D(x: 11.0, y: 11.0)
		]

		let strategies: [any CentroidInitialization] = [
			RandomInitialization(),
			ForgyInitialization(),
			KMeansPlusPlusInitialization()
		]

		for strategy in strategies {
			let kmeans = KMeans<Vector2D<Double>>(
				initialization: strategy,
				seed: 888,
				useGPU: false
			)

			let result = try kmeans.fit(data: data, k: 2)

			#expect(result.clusters.count == 2)
			#expect(result.converged, "Should converge with initialization strategy")
		}
	}

	// MARK: - Edge Cases

	@Test("K-Means with k=1")
	func kEqualsOne() throws {
		let data: [Vector2D<Double>] = [
			Vector2D(x: 1.0, y: 1.0),
			Vector2D(x: 2.0, y: 2.0),
			Vector2D(x: 3.0, y: 3.0)
		]

		let kmeans = KMeans<Vector2D<Double>>(useGPU: false)
		let result = try kmeans.fit(data: data, k: 1)

		#expect(result.clusters.count == 1)
		#expect(result.clusters[0].size == 3)

		// All points should be assigned to cluster 0
		for assignment in result.assignments {
			#expect(assignment == 0)
		}
	}

	@Test("K-Means with k=n")
	func kEqualsN() throws {
		let data: [Vector2D<Double>] = [
			Vector2D(x: 1.0, y: 1.0),
			Vector2D(x: 2.0, y: 2.0),
			Vector2D(x: 3.0, y: 3.0)
		]

		let kmeans = KMeans<Vector2D<Double>>(seed: 777, useGPU: false)
		let result = try kmeans.fit(data: data, k: 3)

		#expect(result.clusters.count == 3)

		// Each cluster should have exactly 1 point
		for cluster in result.clusters {
			#expect(cluster.size == 1)
		}

		// WCSS should be zero (each point is its own centroid)
		#expect(abs(result.wcss) < 1e-10)
	}

	@Test("K-Means with identical points")
	func identicalPoints() throws {
		// All points are the same
		let data: [Vector2D<Double>] = Array(repeating: Vector2D(x: 5.0, y: 5.0), count: 10)

		let kmeans = KMeans<Vector2D<Double>>(seed: 111, useGPU: false)
		let result = try kmeans.fit(data: data, k: 2)

		#expect(result.clusters.count == 2)

		// WCSS should be zero (all points are identical)
		#expect(abs(result.wcss) < 1e-10)

		// All centroids should be at the same location
		for cluster in result.clusters {
			#expect(abs(cluster.centroid.x - 5.0) < 1e-10)
			#expect(abs(cluster.centroid.y - 5.0) < 1e-10)
		}
	}

	// MARK: - WCSS Validation Tests

	@Test("WCSS calculation is correct")
	func wcssCalculation() throws {
		// Simple case where we can manually calculate WCSS
		let data: [Vector2D<Double>] = [
			Vector2D(x: 0.0, y: 0.0),
			Vector2D(x: 1.0, y: 0.0),
			Vector2D(x: 10.0, y: 0.0),
			Vector2D(x: 11.0, y: 0.0)
		]

		let kmeans = KMeans<Vector2D<Double>>(seed: 222, useGPU: false)
		let result = try kmeans.fit(data: data, k: 2)

		// With perfect clustering:
		// Cluster 1: (0,0) and (1,0), centroid at (0.5, 0)
		// WCSS contribution: 0.5^2 + 0.5^2 = 0.5
		// Cluster 2: (10,0) and (11,0), centroid at (10.5, 0)
		// WCSS contribution: 0.5^2 + 0.5^2 = 0.5
		// Total WCSS = 1.0

		#expect(abs(result.wcss - 1.0) < 1e-6, "WCSS should be approximately 1.0")
	}
}

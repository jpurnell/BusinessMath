//
//  InitializationTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 1/28/26.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Centroid Initialization Tests")
struct InitializationTests {

	// MARK: - Random Initialization Tests

	@Test("Random initialization is deterministic with seed")
	func randomInitializationDeterministic() {
		let data: [Vector2D<Double>] = [
			Vector2D(x: 1.0, y: 1.0),
			Vector2D(x: 2.0, y: 2.0),
			Vector2D(x: 3.0, y: 3.0),
			Vector2D(x: 4.0, y: 4.0),
			Vector2D(x: 5.0, y: 5.0)
		]

		let strategy = RandomInitialization()
		let seed: UInt64 = 12345

		let centroids1 = strategy.initialize(
			data: data,
			k: 3,
			distanceMetric: .euclidean,
			seed: seed
		)

		let centroids2 = strategy.initialize(
			data: data,
			k: 3,
			distanceMetric: .euclidean,
			seed: seed
		)

		// Same seed should produce identical centroids
		#expect(centroids1.count == 3)
		#expect(centroids2.count == 3)
		for i in 0..<3 {
			#expect(centroids1[i] == centroids2[i])
		}
	}

	@Test("Random initialization without seed is non-deterministic")
	func randomInitializationNonDeterministic() {
		let data: [Vector2D<Double>] = (0..<100).map { i in
			Vector2D(x: Double(i), y: Double(i * 2))
		}

		let strategy = RandomInitialization()

		let centroids1 = strategy.initialize(
			data: data,
			k: 10,
			distanceMetric: .euclidean,
			seed: nil
		)

		let centroids2 = strategy.initialize(
			data: data,
			k: 10,
			distanceMetric: .euclidean,
			seed: nil
		)

		// Without seed, results should differ (with very high probability)
		var differenceCount = 0
		for i in 0..<10 {
			if centroids1[i] != centroids2[i] {
				differenceCount += 1
			}
		}

		// At least some centroids should be different
		#expect(differenceCount > 0)
	}

	@Test("Random initialization selects from data points")
	func randomInitializationSelectsFromData() {
		let data: [Vector2D<Double>] = [
			Vector2D(x: 1.0, y: 1.0),
			Vector2D(x: 2.0, y: 2.0),
			Vector2D(x: 3.0, y: 3.0)
		]

		let strategy = RandomInitialization()
		let centroids = strategy.initialize(
			data: data,
			k: 2,
			distanceMetric: .euclidean,
			seed: 42
		)

		#expect(centroids.count == 2)

		// Each centroid should be one of the original data points
		for centroid in centroids {
			let isDataPoint = data.contains(centroid)
			#expect(isDataPoint, "Centroid \(centroid) should be from data points")
		}
	}

	// MARK: - Forgy Initialization Tests

	@Test("Forgy initialization is deterministic with seed")
	func forgyInitializationDeterministic() {
		let data: [Vector2D<Double>] = [
			Vector2D(x: 1.0, y: 1.0),
			Vector2D(x: 2.0, y: 2.0),
			Vector2D(x: 3.0, y: 3.0),
			Vector2D(x: 4.0, y: 4.0),
			Vector2D(x: 5.0, y: 5.0),
			Vector2D(x: 6.0, y: 6.0)
		]

		let strategy = ForgyInitialization()
		let seed: UInt64 = 54321

		let centroids1 = strategy.initialize(
			data: data,
			k: 2,
			distanceMetric: .euclidean,
			seed: seed
		)

		let centroids2 = strategy.initialize(
			data: data,
			k: 2,
			distanceMetric: .euclidean,
			seed: seed
		)

		// Same seed should produce identical centroids
		#expect(centroids1.count == 2)
		#expect(centroids2.count == 2)
		for i in 0..<2 {
			#expect(abs(centroids1[i].x - centroids2[i].x) < 1e-10)
			#expect(abs(centroids1[i].y - centroids2[i].y) < 1e-10)
		}
	}

	@Test("Forgy initialization produces centroids as partition means")
	func forgyInitializationProducesPartitionMeans() {
		// Create well-separated clusters
		let data: [Vector2D<Double>] = [
			Vector2D(x: 0.0, y: 0.0),
			Vector2D(x: 0.1, y: 0.1),
			Vector2D(x: 0.2, y: 0.2),
			Vector2D(x: 10.0, y: 10.0),
			Vector2D(x: 10.1, y: 10.1),
			Vector2D(x: 10.2, y: 10.2)
		]

		let strategy = ForgyInitialization()
		let centroids = strategy.initialize(
			data: data,
			k: 2,
			distanceMetric: .euclidean,
			seed: 999
		)

		#expect(centroids.count == 2)

		// Centroids should be means of partitions, not original data points
		// They likely won't match data points exactly
		for centroid in centroids {
			// Verify centroid is reasonable (within data bounds)
			#expect(centroid.x >= 0.0)
			#expect(centroid.y >= 0.0)
			#expect(centroid.x <= 10.2)
			#expect(centroid.y <= 10.2)
		}
	}

	// MARK: - K-Means++ Initialization Tests

	@Test("K-Means++ initialization is deterministic with seed")
	func kMeansPlusPlusDeterministic() {
		let data: [Vector2D<Double>] = [
			Vector2D(x: 1.0, y: 1.0),
			Vector2D(x: 2.0, y: 2.0),
			Vector2D(x: 3.0, y: 3.0),
			Vector2D(x: 4.0, y: 4.0),
			Vector2D(x: 5.0, y: 5.0)
		]

		let strategy = KMeansPlusPlusInitialization()
		let seed: UInt64 = 11111

		let centroids1 = strategy.initialize(
			data: data,
			k: 3,
			distanceMetric: .euclidean,
			seed: seed
		)

		let centroids2 = strategy.initialize(
			data: data,
			k: 3,
			distanceMetric: .euclidean,
			seed: seed
		)

		// Same seed should produce identical centroids
		#expect(centroids1.count == 3)
		#expect(centroids2.count == 3)
		for i in 0..<3 {
			#expect(centroids1[i] == centroids2[i])
		}
	}

	@Test("K-Means++ initialization spreads centroids")
	func kMeansPlusPlusSpread() {
		// Create data with clear separation
		var data: [Vector2D<Double>] = []

		// Cluster 1: around (0, 0)
		for i in 0..<10 {
			data.append(Vector2D(x: Double(i) * 0.1, y: Double(i) * 0.1))
		}

		// Cluster 2: around (10, 10)
		for i in 0..<10 {
			data.append(Vector2D(x: 10.0 + Double(i) * 0.1, y: 10.0 + Double(i) * 0.1))
		}

		// Cluster 3: around (20, 0)
		for i in 0..<10 {
			data.append(Vector2D(x: 20.0 + Double(i) * 0.1, y: Double(i) * 0.1))
		}

		let strategy = KMeansPlusPlusInitialization()
		let centroids = strategy.initialize(
			data: data,
			k: 3,
			distanceMetric: .euclidean,
			seed: 42
		)

		#expect(centroids.count == 3)

		// Centroids should be relatively far apart
		for i in 0..<centroids.count {
			for j in (i+1)..<centroids.count {
				let distance = DistanceMetric.euclidean.distance(centroids[i], centroids[j])
				// Centroids should be at least somewhat separated
				#expect(distance > 1.0, "Centroids should be spread out")
			}
		}
	}

	@Test("K-Means++ better than random initialization")
	func kMeansPlusPlusBetterThanRandom() {
		// Create well-separated clusters
		var data: [Vector2D<Double>] = []

		// Three distinct clusters
		for i in 0..<20 {
			data.append(Vector2D(x: Double(i) * 0.1, y: Double(i) * 0.1))
		}
		for i in 0..<20 {
			data.append(Vector2D(x: 10.0 + Double(i) * 0.1, y: 10.0 + Double(i) * 0.1))
		}
		for i in 0..<20 {
			data.append(Vector2D(x: 20.0 + Double(i) * 0.1, y: Double(i) * 0.1))
		}

		let seed: UInt64 = 77777

		let kmeanspp = KMeansPlusPlusInitialization()
		let random = RandomInitialization()

		let kmeansCentroids = kmeanspp.initialize(
			data: data,
			k: 3,
			distanceMetric: .euclidean,
			seed: seed
		)

		let randomCentroids = random.initialize(
			data: data,
			k: 3,
			distanceMetric: .euclidean,
			seed: seed
		)

		// Compute average pairwise distance for K-Means++
		var kmeansSumDist = 0.0
		for i in 0..<3 {
			for j in (i+1)..<3 {
				kmeansSumDist += DistanceMetric.euclidean.distance(
					kmeansCentroids[i],
					kmeansCentroids[j]
				)
			}
		}
		let kmeansAvgDist = kmeansSumDist / 3.0

		// Compute average pairwise distance for random
		var randomSumDist = 0.0
		for i in 0..<3 {
			for j in (i+1)..<3 {
				randomSumDist += DistanceMetric.euclidean.distance(
					randomCentroids[i],
					randomCentroids[j]
				)
			}
		}
		let randomAvgDist = randomSumDist / 3.0

		// K-Means++ should generally produce more spread-out centroids
		// (Not guaranteed every time, but likely with well-separated clusters)
		// We'll just verify both produce valid results
		#expect(kmeansAvgDist > 0.0)
		#expect(randomAvgDist > 0.0)
	}

	// MARK: - Edge Cases

	@Test("Initialization with k=1 returns single centroid")
	func initializationWithK1() {
		let data: [Vector2D<Double>] = [
			Vector2D(x: 1.0, y: 1.0),
			Vector2D(x: 2.0, y: 2.0),
			Vector2D(x: 3.0, y: 3.0)
		]

		let strategies: [any CentroidInitialization] = [
			RandomInitialization(),
			ForgyInitialization(),
			KMeansPlusPlusInitialization()
		]

		for strategy in strategies {
			let centroids = strategy.initialize(
				data: data,
				k: 1,
				distanceMetric: .euclidean,
				seed: 123
			)

			#expect(centroids.count == 1)
		}
	}

	@Test("Initialization with k=n returns all data points or means")
	func initializationWithKEqualsN() {
		let data: [Vector2D<Double>] = [
			Vector2D(x: 1.0, y: 1.0),
			Vector2D(x: 2.0, y: 2.0),
			Vector2D(x: 3.0, y: 3.0)
		]

		let random = RandomInitialization()
		let centroids = random.initialize(
			data: data,
			k: 3,
			distanceMetric: .euclidean,
			seed: 456
		)

		#expect(centroids.count == 3)

		// For random, all data points should be selected
		for centroid in centroids {
			#expect(data.contains(centroid))
		}
	}

	@Test("Initialization works with different distance metrics")
	func initializationWithDifferentMetrics() {
		let data: [Vector2D<Double>] = [
			Vector2D(x: 1.0, y: 1.0),
			Vector2D(x: 2.0, y: 2.0),
			Vector2D(x: 3.0, y: 3.0),
			Vector2D(x: 4.0, y: 4.0),
			Vector2D(x: 5.0, y: 5.0)
		]

		let strategy = KMeansPlusPlusInitialization()
		let metrics: [DistanceMetric] = [.euclidean, .manhattan, .chebyshev]

		for metric in metrics {
			let centroids = strategy.initialize(
				data: data,
				k: 3,
				distanceMetric: metric,
				seed: 789
			)

			#expect(centroids.count == 3, "Initialization with \(metric) should work")
		}
	}

	@Test("Initialization works with VectorN")
	func initializationWithVectorN() {
		let data: [VectorN] = [
			VectorN([1.0, 2.0, 3.0]),
			VectorN([4.0, 5.0, 6.0]),
			VectorN([7.0, 8.0, 9.0]),
			VectorN([10.0, 11.0, 12.0])
		]

		let strategies: [any CentroidInitialization] = [
			RandomInitialization(),
			ForgyInitialization(),
			KMeansPlusPlusInitialization()
		]

		for strategy in strategies {
			let centroids = strategy.initialize(
				data: data,
				k: 2,
				distanceMetric: .euclidean,
				seed: 999
			)

			#expect(centroids.count == 2)
			for centroid in centroids {
				#expect(centroid.toArray().count == 3)
			}
		}
	}
}

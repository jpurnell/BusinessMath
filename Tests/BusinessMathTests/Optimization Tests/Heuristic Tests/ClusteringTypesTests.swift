//
//  ClusteringTypesTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 1/28/26.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Clustering Types Tests")
struct ClusteringTypesTests {

	// MARK: - Cluster Tests

	@Test("Cluster creation and properties")
	func clusterCreation() {
		let centroid = Vector2D<Double>(x: 5.0, y: 5.0)
		let memberIndices: Set<Int> = [0, 1, 2, 5, 7]

		let cluster = Cluster(centroid: centroid, memberIndices: memberIndices)

		#expect(cluster.centroid == centroid)
		#expect(cluster.memberIndices == memberIndices)
		#expect(cluster.size == 5)
	}

	@Test("Empty cluster has size zero")
	func emptyCluster() {
		let centroid = Vector2D<Double>(x: 0.0, y: 0.0)
		let emptyIndices: Set<Int> = []

		let cluster = Cluster(centroid: centroid, memberIndices: emptyIndices)

		#expect(cluster.size == 0)
		#expect(cluster.memberIndices.isEmpty)
	}

	@Test("Cluster equality")
	func clusterEquality() {
		let centroid1 = Vector2D<Double>(x: 1.0, y: 2.0)
		let centroid2 = Vector2D<Double>(x: 1.0, y: 2.0)
		let centroid3 = Vector2D<Double>(x: 3.0, y: 4.0)

		let indices1: Set<Int> = [0, 1, 2]
		let indices2: Set<Int> = [0, 1, 2]
		let indices3: Set<Int> = [0, 1, 3]

		let cluster1 = Cluster(centroid: centroid1, memberIndices: indices1)
		let cluster2 = Cluster(centroid: centroid2, memberIndices: indices2)
		let cluster3 = Cluster(centroid: centroid1, memberIndices: indices3)
		let cluster4 = Cluster(centroid: centroid3, memberIndices: indices1)

		// Same centroid and members
		#expect(cluster1 == cluster2)

		// Different members
		#expect(cluster1 != cluster3)

		// Different centroid
		#expect(cluster1 != cluster4)
	}

	// MARK: - ClusteringResult Tests

	@Test("ClusteringResult properties")
	func clusteringResultProperties() {
		let centroid1 = Vector2D<Double>(x: 1.0, y: 1.0)
		let centroid2 = Vector2D<Double>(x: 5.0, y: 5.0)

		let cluster1 = Cluster(centroid: centroid1, memberIndices: [0, 1, 2])
		let cluster2 = Cluster(centroid: centroid2, memberIndices: [3, 4])

		let assignments = [0, 0, 0, 1, 1]
		let wcss = 12.5
		let iterations = 10
		let converged = true

		let result = ClusteringResult(
			clusters: [cluster1, cluster2],
			assignments: assignments,
			wcss: wcss,
			iterations: iterations,
			converged: converged
		)

		#expect(result.clusters.count == 2)
		#expect(result.clusters[0] == cluster1)
		#expect(result.clusters[1] == cluster2)
		#expect(result.assignments == assignments)
		#expect(result.wcss == wcss)
		#expect(result.iterations == iterations)
		#expect(result.converged == converged)
	}

	@Test("ClusteringResult equality")
	func clusteringResultEquality() {
		let centroid = Vector2D<Double>(x: 1.0, y: 1.0)
		let cluster = Cluster(centroid: centroid, memberIndices: [0, 1])

		let result1 = ClusteringResult(
			clusters: [cluster],
			assignments: [0, 0],
			wcss: 10.0,
			iterations: 5,
			converged: true
		)

		let result2 = ClusteringResult(
			clusters: [cluster],
			assignments: [0, 0],
			wcss: 10.0,
			iterations: 5,
			converged: true
		)

		let result3 = ClusteringResult(
			clusters: [cluster],
			assignments: [0, 0],
			wcss: 15.0,  // Different WCSS
			iterations: 5,
			converged: true
		)

		#expect(result1 == result2)
		#expect(result1 != result3)
	}

	// MARK: - DistanceMetric Tests

	@Test("Euclidean distance calculation")
	func euclideanDistance() {
		let v1 = Vector2D<Double>(x: 0.0, y: 0.0)
		let v2 = Vector2D<Double>(x: 3.0, y: 4.0)

		let distance = DistanceMetric.euclidean.distance(v1, v2)

		// Distance should be sqrt(3^2 + 4^2) = 5.0
		#expect(abs(distance - 5.0) < 1e-10)
	}

	@Test("Manhattan distance calculation")
	func manhattanDistance() {
		let v1 = Vector2D<Double>(x: 0.0, y: 0.0)
		let v2 = Vector2D<Double>(x: 3.0, y: 4.0)

		let distance = DistanceMetric.manhattan.distance(v1, v2)

		// Distance should be |3-0| + |4-0| = 7.0
		#expect(abs(distance - 7.0) < 1e-10)
	}

	@Test("Chebyshev distance calculation")
	func chebyshevDistance() {
		let v1 = Vector2D<Double>(x: 0.0, y: 0.0)
		let v2 = Vector2D<Double>(x: 3.0, y: 4.0)

		let distance = DistanceMetric.chebyshev.distance(v1, v2)

		// Distance should be max(|3-0|, |4-0|) = 4.0
		#expect(abs(distance - 4.0) < 1e-10)
	}

	@Test("Distance metrics with VectorN")
	func distanceMetricsWithVectorN() {
		let v1 = VectorN([0.0, 0.0, 0.0])
		let v2 = VectorN([3.0, 4.0, 12.0])

		// Euclidean: sqrt(3^2 + 4^2 + 12^2) = sqrt(169) = 13.0
		let euclidean = DistanceMetric.euclidean.distance(v1, v2)
		#expect(abs(euclidean - 13.0) < 1e-10)

		// Manhattan: |3| + |4| + |12| = 19.0
		let manhattan = DistanceMetric.manhattan.distance(v1, v2)
		#expect(abs(manhattan - 19.0) < 1e-10)

		// Chebyshev: max(|3|, |4|, |12|) = 12.0
		let chebyshev = DistanceMetric.chebyshev.distance(v1, v2)
		#expect(abs(chebyshev - 12.0) < 1e-10)
	}

	@Test("Distance metrics are symmetric")
	func distanceSymmetry() {
		let v1 = Vector2D<Double>(x: 1.0, y: 2.0)
		let v2 = Vector2D<Double>(x: 4.0, y: 6.0)

		for metric in [DistanceMetric.euclidean, .manhattan, .chebyshev] {
			let d1 = metric.distance(v1, v2)
			let d2 = metric.distance(v2, v1)

			#expect(abs(d1 - d2) < 1e-10, "Distance should be symmetric for \(metric)")
		}
	}

	@Test("Distance from point to itself is zero")
	func distanceToSelf() {
		let v = Vector2D<Double>(x: 3.5, y: 7.2)

		for metric in [DistanceMetric.euclidean, .manhattan, .chebyshev] {
			let distance = metric.distance(v, v)

			#expect(abs(distance) < 1e-10, "Distance to self should be zero for \(metric)")
		}
	}

	// MARK: - ClusteringError Tests

	@Test("ClusteringError too many clusters")
	func errorTooManyClusters() {
		let error1 = ClusteringError.tooManyClusters(k: 10, dataPoints: 5)
		let error2 = ClusteringError.tooManyClusters(k: 10, dataPoints: 5)
		let error3 = ClusteringError.tooManyClusters(k: 5, dataPoints: 5)

		#expect(error1 == error2)
		#expect(error1 != error3)
	}

	@Test("ClusteringError empty dataset")
	func errorEmptyDataset() {
		let error1 = ClusteringError.emptyDataset
		let error2 = ClusteringError.emptyDataset

		#expect(error1 == error2)
	}

	@Test("ClusteringError invalid k")
	func errorInvalidK() {
		let error1 = ClusteringError.invalidK(k: 0)
		let error2 = ClusteringError.invalidK(k: 0)
		let error3 = ClusteringError.invalidK(k: -1)

		#expect(error1 == error2)
		#expect(error1 != error3)
	}

	@Test("ClusteringError empty cluster")
	func errorEmptyCluster() {
		let error1 = ClusteringError.emptyCluster(iteration: 5)
		let error2 = ClusteringError.emptyCluster(iteration: 5)
		let error3 = ClusteringError.emptyCluster(iteration: 3)

		#expect(error1 == error2)
		#expect(error1 != error3)
	}

	@Test("ClusteringError equality across different types")
	func errorEqualityAcrossTypes() {
		let error1 = ClusteringError.emptyDataset
		let error2 = ClusteringError.invalidK(k: 0)
		let error3 = ClusteringError.tooManyClusters(k: 10, dataPoints: 5)
		let error4 = ClusteringError.emptyCluster(iteration: 1)

		#expect(error1 != error2)
		#expect(error1 != error3)
		#expect(error1 != error4)
		#expect(error2 != error3)
		#expect(error2 != error4)
		#expect(error3 != error4)
	}
}

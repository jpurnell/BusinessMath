//
//  BehaviouralSegments.swift
//  BusinessMath
//

import Foundation
import Numerics

/// Why customers could not be segmented.
public enum SegmentationError: Error, Sendable, Equatable {

	/// Nobody was supplied.
	case noCustomers

	/// The feature rows are not all the same width, or carry a value that is not finite.
	case raggedFeatures(reason: String)

	/// More segments were asked for than there are customers to fill them.
	case invalidSegmentCount(requested: Int, customers: Int)

	/// The clustering itself failed, carrying its own description.
	case clustering(reason: String)

	/// Nobody shares anything with anybody, so there is no co-behaviour to group by.
	case noSharedBehaviour
}

/// One segment: who is in it, and where its centre sits.
public struct BehaviouralSegment: Sendable, Equatable {

	/// A stable index for the segment, counting from zero.
	public let label: Int

	/// The customers in it, sorted.
	public let members: [String]

	/// How many there are.
	public var size: Int { members.count }

	/// The segment's centre in feature space, or `nil` for a segmentation that had no
	/// feature space to have a centre in.
	public let centroid: [Double]?

	/// Creates a segment.
	///
	/// - Parameters:
	///   - label: A stable index.
	///   - members: The customers in it, sorted.
	///   - centroid: The centre in feature space, if there was one.
	public init(label: Int, members: [String], centroid: [Double]?) {
		self.label = label
		self.members = members
		self.centroid = centroid
	}
}

/// Customers grouped either by what they look like or by what they do.
///
/// ```swift
/// let spend: [String: [Double]] = [
///     "ada": [1, 1], "brs": [1.1, 0.9], "cyd": [0.9, 1.1],
///     "dee": [10, 10], "eli": [10.1, 9.9], "fay": [9.9, 10.1]
/// ]
/// let grouped = try BehaviouralSegmentation.byFeatures(customers: spend, into: 2)
/// print(grouped.segments.map(\.size))
/// ```
///
/// ## Two questions, not one method with two implementations
///
/// ``byFeatures(customers:into:seed:maximumIterations:)`` clusters customers who **look
/// alike** — similar recency, frequency and spend, whatever the feature vector holds. Two
/// customers with identical purchasing profiles land together even if they have never
/// bought the same thing in their lives.
///
/// ``byCoBehaviour(memberships:weighting:)`` groups customers who **do the same things** —
/// buy the same products, attend the same events, touch the same channels. Two customers
/// with wildly different spend land together if they share a niche interest.
///
/// A customer sitting in different segments under the two is not a contradiction and not
/// a defect. They are answers to different questions, and which one you want depends on
/// whether you are about to send a discount (features) or a recommendation (co-behaviour).
///
/// ## Determinism is a design constraint here, not a nicety
///
/// Segments get compared across runs: someone re-runs last quarter's model and asks what
/// moved. That only means anything if identical input gives identical output, and the
/// obvious implementation quietly does not.
///
/// A `[String: [Double]]` has no order. Feed its values straight into k-means and the
/// initial centroids are chosen from a differently-ordered array each time, so the same
/// customers come back in different segments with different labels — and every run looks
/// entirely reasonable. ``orderedCustomers`` is the fix: rows are built in sorted key
/// order, always, and the order is published so it can be checked rather than trusted.
///
/// The GPU path is off by default for the same reason. It is faster, and it has a
/// recorded determinism incident in this codebase where a silent fallback changed results
/// mid-run. Segmentation is re-run and compared; throughput is not what it is for.
public struct BehaviouralSegmentation: Sendable {

	/// The segments, by label.
	public let segments: [BehaviouralSegment]

	/// Which segment each customer landed in.
	public let assignments: [String: Int]

	/// The customers in the order the algorithm saw them — always sorted.
	public let orderedCustomers: [String]

	/// Creates a segmentation.
	///
	/// - Parameters:
	///   - segments: The segments, by label.
	///   - assignments: Which segment each customer landed in.
	///   - orderedCustomers: The order rows were built in.
	public init(segments: [BehaviouralSegment], assignments: [String: Int],
				orderedCustomers: [String]) {
		self.segments = segments
		self.assignments = assignments
		self.orderedCustomers = orderedCustomers
	}

	/// Which segment a customer is in.
	///
	/// - Parameter customer: The customer.
	/// - Returns: The label, or `nil` for someone who was not segmented.
	public func segment(of customer: String) -> Int? {
		assignments[customer]
	}

	/// Groups customers by similarity of their feature vectors, using k-means.
	///
	/// - Parameters:
	///   - customers: Customer identifier to feature vector. Every vector must be the
	///     same width and finite.
	///   - count: How many segments. Must be between one and the customer count.
	///   - seed: Seed for centroid initialisation. Defaults to a fixed value so that
	///     re-running without thinking about it still reproduces.
	///   - maximumIterations: Iteration ceiling passed to k-means.
	/// - Returns: The segmentation.
	/// - Throws: ``SegmentationError``.
	public static func byFeatures(customers: [String: [Double]],
								  into count: Int,
								  seed: UInt64? = 20_260_908,
								  maximumIterations: Int = 100) throws -> BehaviouralSegmentation {
		guard !customers.isEmpty else { throw SegmentationError.noCustomers }
		let ordered = customers.keys.sorted()
		guard count >= 1, count <= ordered.count else {
			throw SegmentationError.invalidSegmentCount(requested: count,
														customers: ordered.count)
		}

		guard let width = customers[ordered[0]]?.count, width > 0 else {
			throw SegmentationError.raggedFeatures(reason: "a customer has no features")
		}
		var rows: [VectorN<Double>] = []
		for name in ordered {
			guard let features = customers[name] else {
				throw SegmentationError.raggedFeatures(reason: "no features for '\(name)'")
			}
			guard features.count == width else {
				throw SegmentationError.raggedFeatures(
					reason: "'\(name)' has \(features.count) features, not \(width)")
			}
			guard features.allSatisfy({ $0.isFinite }) else {
				throw SegmentationError.raggedFeatures(reason: "'\(name)' has a non-finite feature")
			}
			rows.append(VectorN(features))
		}

		// GPU off on purpose — see the note on this type.
		let model = KMeans<VectorN<Double>>(maxIterations: maximumIterations,
											seed: seed,
											useGPU: false)
		let fitted: ClusteringResult<VectorN<Double>>
		do {
			fitted = try model.fit(data: rows, k: count)
		} catch let error as ClusteringError {
			throw SegmentationError.clustering(reason: "\(error)")
		}

		var members: [Int: [String]] = [:]
		var assignments: [String: Int] = [:]
		for (index, label) in fitted.assignments.enumerated() where index < ordered.count {
			let name = ordered[index]
			members[label, default: []].append(name)
			assignments[name] = label
		}

		var segments: [BehaviouralSegment] = []
		for label in members.keys.sorted() {
			let centre = label < fitted.clusters.count
				? fitted.clusters[label].centroid.toArray()
				: nil
			let names = (members[label] ?? []).sorted()
			segments.append(BehaviouralSegment(label: label, members: names,
											   centroid: centre))
		}
		return BehaviouralSegmentation(segments: segments, assignments: assignments,
									   orderedCustomers: ordered)
	}

	/// Groups customers by what they share, using a bipartite projection and Louvain.
	///
	/// - Parameters:
	///   - memberships: Customer identifier to the things they touched — products,
	///     categories, events, channels.
	///   - weighting: How to weight a shared thing. Defaults to Jaccard, which discounts
	///     a customer who touches everything.
	/// - Returns: The segmentation. Segments carry no centroid, because there is no
	///   feature space to have one in.
	/// - Throws: ``SegmentationError``. In particular
	///   ``SegmentationError/noSharedBehaviour`` when nobody shares anything with anybody:
	///   the projection has no edges, every customer is their own community, and returning
	///   that partition would dress "there is no structure here" up as a segmentation.
	public static func byCoBehaviour(memberships: [String: Set<String>],
									 weighting: ProjectionWeighting = .jaccard) throws -> BehaviouralSegmentation {
		guard !memberships.isEmpty else { throw SegmentationError.noCustomers }
		guard memberships.values.allSatisfy({ !$0.isEmpty }) else {
			throw SegmentationError.raggedFeatures(reason: "a customer touched nothing")
		}
		guard let projected = BipartiteProjection(memberships: memberships,
												  weighting: weighting) else {
			throw SegmentationError.noCustomers
		}
		let graph = projected.graph
		guard graph.edgeCount > 0 else { throw SegmentationError.noSharedBehaviour }
		guard let communities = graph.louvainCommunities() else {
			throw SegmentationError.clustering(reason: "modularity maximisation did not settle")
		}

		// Labelled by their lowest-named member, so the numbering is a property of the
		// partition rather than of the order the algorithm happened to emit it in.
		let ordered = communities
			.map { $0.sorted() }
			.filter { !$0.isEmpty }
			.sorted { left, right in left.lexicographicallyPrecedes(right) }

		var segments: [BehaviouralSegment] = []
		var assignments: [String: Int] = [:]
		for (label, names) in ordered.enumerated() {
			segments.append(BehaviouralSegment(label: label, members: names, centroid: nil))
			for name in names { assignments[name] = label }
		}
		return BehaviouralSegmentation(segments: segments, assignments: assignments,
									   orderedCustomers: memberships.keys.sorted())
	}
}

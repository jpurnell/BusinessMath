//
//  BehaviouralSegmentsTests.swift
//  BusinessMath
//
//  Segmenting customers by what they look like and by what they do, and the three ways a
//  segmentation is well-formed and not reproducible.
//
//  - **Feeding a dictionary straight into k-means.** `[String: [Double]]` has no order.
//    Take its `values` and the initial centroids come from a differently-ordered array
//    each run, so the same customers land in different segments under different labels —
//    and every run looks entirely reasonable. Nothing about the output says it moved.
//    Rows are built in sorted key order and the order is published so it can be checked.
//  - **Louvain on a projection with no edges.** Nobody shares anything, every customer is
//    their own community, and that partition is perfectly valid. Returned as a
//    segmentation it says "here are your fourteen segments" where the finding was "there
//    is no structure in this data".
//  - **A centroid quoted for a graph segmentation.** Co-behaviour grouping has no feature
//    space, so it has no centre. Returning the mean of something would be inventing a
//    coordinate system.
//
//  The anchor is the partition property, which holds for both methods and needs no
//  fixture: every customer lands in exactly one segment, and the segment sizes sum to the
//  customer count. On top of that, two well-separated groups must be recovered exactly —
//  a clustering that cannot do that on clean data is not worth checking on dirty data.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Behavioural segmentation")
struct BehaviouralSegmentsTests {

	/// The seed every test here states explicitly.
	///
	/// `byFeatures` defaults it to a fixed constant, so omitting it would still be
	/// deterministic today — and would stop being so the day that default changed, with
	/// nothing in these tests recording that they had ever depended on it.
	static let seed: UInt64 = 20_260_908

	/// Six customers in two tight, far-apart clumps.
	static let spend: [String: [Double]] = [
		"ada": [1, 1], "brs": [1.1, 0.9], "cyd": [0.9, 1.1],
		"dee": [10, 10], "eli": [10.1, 9.9], "fay": [9.9, 10.1]
	]

	/// Three customers around one product pair, two around another, sharing nothing.
	static let baskets: [String: Set<String>] = [
		"ada": ["kettle", "teapot"],
		"brs": ["kettle", "teapot"],
		"cyd": ["teapot"],
		"dee": ["surfboard", "wetsuit"],
		"eli": ["surfboard", "wetsuit"]
	]

	// MARK: - The partition property

	@Test("Every customer lands in exactly one segment, under both methods")
	func segmentsPartitionTheCustomers() throws {
		let byFeatures = try BehaviouralSegmentation.byFeatures(customers: Self.spend, into: 2, seed: Self.seed)
		let byBehaviour = try BehaviouralSegmentation.byCoBehaviour(memberships: Self.baskets)
		for grouped in [byFeatures, byBehaviour] {
			var seen: Set<String> = []
			var total = 0
			for segment in grouped.segments {
				total += segment.size
				for member in segment.members {
					#expect(!seen.contains(member), "\(member) is in two segments")
					seen.insert(member)
					#expect(grouped.segment(of: member) == segment.label, "\(member)")
				}
			}
			#expect(total == grouped.orderedCustomers.count, "sizes sum to \(total)")
			#expect(seen == Set(grouped.orderedCustomers), "membership differs from input")
		}
	}

	// MARK: - Recovery

	@Test("Two well-separated clumps are recovered exactly")
	func featuresRecoverSeparatedGroups() throws {
		let grouped = try BehaviouralSegmentation.byFeatures(customers: Self.spend, into: 2, seed: Self.seed)
		#expect(grouped.segments.count == 2)
		let low = try #require(grouped.segment(of: "ada"))
		let high = try #require(grouped.segment(of: "dee"))
		#expect(low != high, "the two clumps should not share a segment")
		#expect(grouped.segment(of: "brs") == low, "brs sits with ada")
		#expect(grouped.segment(of: "cyd") == low, "cyd sits with ada")
		#expect(grouped.segment(of: "eli") == high, "eli sits with dee")
		#expect(grouped.segment(of: "fay") == high, "fay sits with dee")
	}

	@Test("A centroid is the mean of its members")
	func centroidsAreTheMean() throws {
		let grouped = try BehaviouralSegmentation.byFeatures(customers: Self.spend, into: 2, seed: Self.seed)
		for segment in grouped.segments {
			let centre = try #require(segment.centroid, "features give a centre")
			#expect(centre.count == 2)
			var sumX: Double = 0
			var sumY: Double = 0
			for member in segment.members {
				let point = try #require(Self.spend[member])
				sumX += point[0]
				sumY += point[1]
			}
			let size: Double = Double(segment.size)
			let meanX: Double = sumX / size
			let meanY: Double = sumY / size
			#expect(Swift.abs(centre[0] - meanX) < 1e-9, "x \(centre[0]) against \(meanX)")
			#expect(Swift.abs(centre[1] - meanY) < 1e-9, "y \(centre[1]) against \(meanY)")
		}
	}

	@Test("Two disjoint interest groups become two communities")
	func coBehaviourRecoversGroups() throws {
		let grouped = try BehaviouralSegmentation.byCoBehaviour(memberships: Self.baskets)
		#expect(grouped.segments.count == 2, "\(grouped.segments.map(\.members))")
		let tea = try #require(grouped.segment(of: "ada"))
		let surf = try #require(grouped.segment(of: "dee"))
		#expect(tea != surf)
		#expect(grouped.segment(of: "brs") == tea)
		#expect(grouped.segment(of: "cyd") == tea)
		#expect(grouped.segment(of: "eli") == surf)
		// Labels follow the lowest-named member, so the tea group is segment zero.
		#expect(tea == 0, "labelled by partition, not by emission order — got \(tea)")
	}

	@Test("A graph segmentation has no centroid to quote")
	func coBehaviourHasNoCentroid() throws {
		let grouped = try BehaviouralSegmentation.byCoBehaviour(memberships: Self.baskets)
		for segment in grouped.segments {
			#expect(segment.centroid == nil, "segment \(segment.label)")
		}
	}

	// MARK: - Determinism

	@Test("Rows are built in sorted key order, and the order is published")
	func rowOrderIsSortedAndVisible() throws {
		let grouped = try BehaviouralSegmentation.byFeatures(customers: Self.spend, into: 2, seed: Self.seed)
		#expect(grouped.orderedCustomers == Self.spend.keys.sorted())
		#expect(grouped.orderedCustomers == ["ada", "brs", "cyd", "dee", "eli", "fay"])
	}

	@Test("The same customers give the same segmentation however the dictionary was built")
	func segmentationIsReproducible() throws {
		// Same pairs, inserted in the opposite order. A dictionary keeps no memory of
		// that, but an implementation reading `.values` would still be at its mercy.
		var reversed: [String: [Double]] = [:]
		for key in Self.spend.keys.sorted().reversed() {
			reversed[key] = Self.spend[key]
		}
		let first = try BehaviouralSegmentation.byFeatures(customers: Self.spend, into: 2, seed: Self.seed)
		let second = try BehaviouralSegmentation.byFeatures(customers: reversed, into: 2, seed: Self.seed)
		#expect(first.orderedCustomers == second.orderedCustomers)
		#expect(first.assignments == second.assignments, "\(first.assignments) vs \(second.assignments)")
		for (left, right) in zip(first.segments, second.segments) {
			#expect(left.members == right.members, "\(left.members) vs \(right.members)")
		}
	}

	// MARK: - The two methods answer different questions

	@Test("Looking alike and behaving alike are not the same grouping")
	func featuresAndBehaviourCanDisagree() throws {
		// Two customers who spend nothing alike but buy the same niche pair, and two who
		// spend identically on unrelated things.
		let features: [String: [Double]] = [
			"thrifty": [1, 1], "lavish": [100, 100],
			"twin1": [50, 50], "twin2": [50, 50]
		]
		let shared: [String: Set<String>] = [
			"thrifty": ["monocle", "cravat"], "lavish": ["monocle", "cravat"],
			"twin1": ["socks"], "twin2": ["gloves"]
		]
		let byFeatures = try BehaviouralSegmentation.byFeatures(customers: features, into: 2, seed: Self.seed)
		let thriftyGroup = try #require(byFeatures.segment(of: "thrifty"))
		let lavishGroup = try #require(byFeatures.segment(of: "lavish"))
		#expect(thriftyGroup != lavishGroup, "spend puts them apart")

		// Co-behaviour puts exactly those two together, and cannot see the twins at all
		// because they share nothing with anyone.
		let projected = try BehaviouralSegmentation.byCoBehaviour(memberships: shared)
		let thriftyShared = try #require(projected.segment(of: "thrifty"))
		let lavishShared = try #require(projected.segment(of: "lavish"))
		#expect(thriftyShared == lavishShared, "the monocle puts them together")
	}

	// MARK: - Refusals

	@Test("Nobody sharing anything is refused, not returned as a segment each")
	func noSharedBehaviourIsRefused() {
		let strangers: [String: Set<String>] = [
			"ada": ["kettle"], "brs": ["surfboard"], "cyd": ["telescope"]
		]
		#expect(throws: SegmentationError.noSharedBehaviour) {
			_ = try BehaviouralSegmentation.byCoBehaviour(memberships: strangers)
		}
	}

	@Test("More segments than customers is refused")
	func tooManySegmentsIsRefused() {
		#expect(throws: SegmentationError.invalidSegmentCount(requested: 9, customers: 6)) {
			_ = try BehaviouralSegmentation.byFeatures(customers: Self.spend, into: 9, seed: Self.seed)
		}
		#expect(throws: SegmentationError.invalidSegmentCount(requested: 0, customers: 6)) {
			_ = try BehaviouralSegmentation.byFeatures(customers: Self.spend, into: 0, seed: Self.seed)
		}
	}

	@Test("Feature rows that do not line up are refused")
	func raggedFeaturesAreRefused() {
		let ragged: [String: [Double]] = ["ada": [1, 2], "brs": [1]]
		#expect(throws: SegmentationError.self) {
			_ = try BehaviouralSegmentation.byFeatures(customers: ragged, into: 2, seed: Self.seed)
		}
		let infinite: [String: [Double]] = ["ada": [1, 2], "brs": [1, .infinity]]
		#expect(throws: SegmentationError.self) {
			_ = try BehaviouralSegmentation.byFeatures(customers: infinite, into: 2, seed: Self.seed)
		}
		let empty: [String: [Double]] = ["ada": [], "brs": []]
		#expect(throws: SegmentationError.self) {
			_ = try BehaviouralSegmentation.byFeatures(customers: empty, into: 2, seed: Self.seed)
		}
	}

	@Test("No customers at all is refused by both methods")
	func noCustomersIsRefused() {
		let none: [String: [Double]] = [:]
		#expect(throws: SegmentationError.noCustomers) {
			_ = try BehaviouralSegmentation.byFeatures(customers: none, into: 1, seed: Self.seed)
		}
		let nothing: [String: Set<String>] = [:]
		#expect(throws: SegmentationError.noCustomers) {
			_ = try BehaviouralSegmentation.byCoBehaviour(memberships: nothing)
		}
		let touchedNothing: [String: Set<String>] = ["ada": []]
		#expect(throws: SegmentationError.self) {
			_ = try BehaviouralSegmentation.byCoBehaviour(memberships: touchedNothing)
		}
	}
}

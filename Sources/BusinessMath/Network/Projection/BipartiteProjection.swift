//
//  BipartiteProjection.swift
//  BusinessMath
//

import Foundation
import Numerics

/// How co-membership is turned into an edge weight.
public enum ProjectionWeighting: Sendable, Equatable, CaseIterable {

	/// How many groups two members share. Unnormalised, so a member of many groups
	/// dominates — which is sometimes what is wanted and is usually not.
	case sharedCount

	/// `|A ∩ B| / |A ∪ B|`. Normalised, symmetric, and insensitive to how prolific the
	/// two members are. The default choice for similarity.
	case jaccard

	/// `|A ∩ B| / √(|A|·|B|)`. Between the other two: it discounts prolific members, but
	/// less severely than Jaccard, since the denominator grows with the square root
	/// rather than the union.
	case cosine
}

/// Members projected onto each other by what they have in common.
///
/// ```swift
/// let baskets: [String: Set<String>] = ["Alice": ["b1", "b2"], "Bob": ["b1"]]
/// if let projected = BipartiteProjection(memberships: baskets, weighting: .jaccard) {
///     print(projected.weight(between: "Alice", and: "Bob"))   // 0.5
/// }
/// ```
///
/// ## What a projection loses
///
/// A bipartite graph — customers against baskets, authors against papers, firms against
/// directors — carries information the projection cannot: a group of ten shared by two
/// members says something different from a group of two, and after projection both are
/// one edge with a weight. That loss is the price of getting a graph algorithm to run on
/// the result, and choosing a weighting is choosing which part of it to keep.
///
/// The projection is also **denser than it looks**: a single group of `k` members
/// contributes `k(k−1)/2` edges, so one large group can dominate a projection built from
/// many small ones. Where that matters, weight by something normalised.
public struct BipartiteProjection<Member: Hashable & Comparable & Sendable>: Sendable {

	/// The members, sorted.
	public let members: [Member]

	/// The weighting used.
	public let weighting: ProjectionWeighting

	/// Weight by unordered pair, keyed with the smaller member first.
	private let weights: [Pair: Double]

	/// An unordered pair, normalised so lookup does not depend on argument order.
	private struct Pair: Hashable {
		let low: Member
		let high: Member
		init(_ a: Member, _ b: Member) {
			if a <= b { low = a; high = b } else { low = b; high = a }
		}
	}

	/// Projects members onto each other.
	///
	/// - Parameters:
	///   - memberships: Each member mapped to the groups it belongs to.
	///   - weighting: How to turn shared groups into a weight.
	/// - Returns: `nil` if there are no members, or if any member belongs to no group —
	///   a member with no memberships has no basis for similarity with anyone, and a
	///   Jaccard denominator of zero is not a similarity of zero.
	public init?(memberships: [Member: Set<String>], weighting: ProjectionWeighting) {
		guard !memberships.isEmpty else { return nil }
		guard memberships.values.allSatisfy({ !$0.isEmpty }) else { return nil }

		let ordered = memberships.keys.sorted()
		var computed: [Pair: Double] = [:]
		for (index, first) in ordered.enumerated() {
			guard let left = memberships[first] else { continue }
			for second in ordered.dropFirst(index + 1) {
				guard let right = memberships[second] else { continue }
				let shared = left.intersection(right).count
				guard shared > 0 else { continue }
				let weight: Double
				switch weighting {
				case .sharedCount:
					weight = Double(shared)
				case .jaccard:
					let union = Double(left.union(right).count)
					guard union > 0 else { continue }
					weight = Double(shared) / union
				case .cosine:
					let product = Double(left.count) * Double(right.count)
					guard product > 0 else { continue }
					let scale: Double = product.squareRoot()
					guard scale > 0 else { continue }
					weight = Double(shared) / scale
				}
				computed[Pair(first, second)] = weight
			}
		}

		self.members = ordered
		self.weighting = weighting
		self.weights = computed
	}

	/// The weight between two members.
	///
	/// - Parameters:
	///   - first: One member.
	///   - second: The other. Order does not matter.
	/// - Returns: The weight, or zero if they share nothing or either is unknown.
	public func weight(between first: Member, and second: Member) -> Double {
		guard first != second else { return 0 }
		return weights[Pair(first, second)] ?? 0
	}

	/// The members sharing at least one group with this one.
	///
	/// - Parameter member: Any member.
	/// - Returns: The neighbours, sorted. Empty for a member who shares nothing —
	///   who remains a member, and is why ``members`` is not derived from the edges.
	public func neighbors(of member: Member) -> [Member] {
		members.filter { $0 != member && weight(between: member, and: $0) > 0 }
	}

	/// The projection as an unweighted graph, for the traversal and centrality suites.
	public var graph: Graph<Member> {
		var adjacency: [Member: [Member]] = [:]
		for member in members { adjacency[member] = neighbors(of: member) }
		return Graph(adjacency: adjacency)
	}
}

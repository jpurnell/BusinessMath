//
//  NodePartition.swift
//  BusinessMath
//

import Foundation

/// An assignment of nodes to groups.
///
/// ```swift
/// let partition = NodePartition(["a": 0, "b": 0, "c": 1])
/// print(partition.communityCount)   // 2
/// ```
///
/// Conforms to ``MetricValue`` (kind `"partition"`) when `Node` is `Codable`.
public struct NodePartition<Node: Hashable & Comparable & Sendable>: Sendable, Hashable {

	/// Community identifier by node.
	public let communities: [Node: Int]

	/// Creates a partition.
	public init(_ communities: [Node: Int]) { self.communities = communities }

	/// Members of each community, largest first.
	public var groups: [(community: Int, members: [Node])] {
		Dictionary(grouping: communities.keys, by: { communities[$0] ?? -1 })
			.map { (community: $0.key, members: $0.value.sorted()) }
			.sorted {
				$0.members.count == $1.members.count
					? $0.community < $1.community
					: $0.members.count > $1.members.count
			}
	}

	/// How many distinct communities.
	public var communityCount: Int { Set(communities.values).count }

	/// The community a node belongs to.
	public subscript(node: Node) -> Int? { communities[node] }
}

extension NodePartition: Codable where Node: Codable {}

extension NodePartition: MetricValue where Node: Codable {
	/// `"partition"`.
	public static var kind: String { "partition" }
}

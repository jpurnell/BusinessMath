//
//  Traversal.swift
//  BusinessMath
//

import Foundation

public extension Graph {

	// MARK: - Strongly connected components

	/// The strongly connected components, in dependency order.
	///
	/// Tarjan's algorithm: one depth-first pass, `O(V + E)`, every component rather than
	/// the first cycle. Components are emitted as their roots finish, so for a graph
	/// whose edges point at dependencies each component appears after everything it
	/// depends on.
	///
	/// The traversal is iterative rather than recursive. A dependency graph is usually
	/// shallow, but nothing in the type constrains it, and a recursive Tarjan on a chain
	/// of a hundred thousand accounts overflows the stack — which is a crash rather than
	/// an error, and cannot be caught.
	///
	/// Determinism comes from ``Graph``: roots are entered in sorted order and every
	/// adjacency list was sorted at construction, so nothing here reads `Dictionary` or
	/// `Set` iteration order. Members are sorted within each component.
	var stronglyConnectedComponents: [[Node]] {
		var nextIndex = 0
		var index: [Node: Int] = [:]
		var lowlink: [Node: Int] = [:]
		var componentStack: [Node] = []
		var onStack: Set<Node> = []
		var components: [[Node]] = []

		for root in nodes {
			guard index[root] == nil else { continue }

			index[root] = nextIndex
			lowlink[root] = nextIndex
			nextIndex += 1
			componentStack.append(root)
			onStack.insert(root)

			var work: [(node: Node, next: Int)] = [(root, 0)]

			while let frame = work.last {
				let targets = neighbors(of: frame.node)

				guard frame.next < targets.count else {
					work.removeLast()
					if let parent = work.last?.node {
						let parentLow = lowlink[parent] ?? nextIndex
						let childLow = lowlink[frame.node] ?? nextIndex
						lowlink[parent] = Swift.min(parentLow, childLow)
					}
					if lowlink[frame.node] == index[frame.node] {
						components.append(Self.pop(&componentStack, &onStack, upTo: frame.node))
					}
					continue
				}

				work[work.count - 1].next += 1
				let target = targets[frame.next]

				if index[target] == nil {
					index[target] = nextIndex
					lowlink[target] = nextIndex
					nextIndex += 1
					componentStack.append(target)
					onStack.insert(target)
					work.append((target, 0))
				} else if onStack.contains(target) {
					let currentLow = lowlink[frame.node] ?? nextIndex
					let targetIndex = index[target] ?? nextIndex
					lowlink[frame.node] = Swift.min(currentLow, targetIndex)
				}
			}
		}

		return components
	}

	/// Whether the graph contains a directed cycle.
	///
	/// A component of two or more vertices is a cycle by definition. A component of one
	/// is a cycle only when the vertex points at itself, which Tarjan reports as an
	/// ordinary trivial component and which is a cycle all the same — the case that gets
	/// missed by a `count > 1` test alone.
	var isCyclic: Bool {
		for component in stronglyConnectedComponents {
			if component.count > 1 { return true }
			if let only = component.first, neighbors(of: only).contains(only) { return true }
		}
		return false
	}

	/// Empties the component stack down to and including `root`, which is one component.
	private static func pop(
		_ stack: inout [Node],
		_ onStack: inout Set<Node>,
		upTo root: Node
	) -> [Node] {
		var component: [Node] = []
		while let member = stack.popLast() {
			onStack.remove(member)
			component.append(member)
			if member == root { break }
		}
		return component.sorted()
	}

	// MARK: - Topological order

	/// A linear order in which every edge points forward, or `nil` if none exists.
	///
	/// Kahn's algorithm, taking the smallest available vertex at each step so the answer
	/// is the lexicographically least of the valid orders. A topological order is not
	/// unique in general, and "any valid order" would make the output depend on
	/// `Dictionary` iteration — correct on any single run and different on the next.
	///
	/// **Direction.** For an edge `u → v`, `u` comes before `v`. A dependency graph whose
	/// edges point at what a node *needs* therefore sorts consumers before their inputs,
	/// which is the reverse of an evaluation order — take `reversed.topologicalSort()`
	/// for that, or read this one backwards.
	///
	/// - Returns: The order, or `nil` when the graph is cyclic. `nil` rather than a
	///   partial order: a partial one looks like an answer, and a caller evaluating a
	///   model in that order would silently skip everything inside the cycle.
	func topologicalSort() -> [Node]? {
		var remaining = inDegrees
		// A sorted array used as a small priority queue. Graphs here are model-sized, and
		// a heap would trade the readability of this for a constant factor on inputs that
		// do not have one to spare.
		var ready = nodes.filter { remaining[$0] == 0 }
		var order: [Node] = []
		order.reserveCapacity(nodes.count)

		while !ready.isEmpty {
			let node = ready.removeFirst()
			order.append(node)
			for target in neighbors(of: node) {
				guard let count = remaining[target] else { continue }
				let reduced = count - 1
				remaining[target] = reduced
				if reduced == 0 {
					// Insert in sorted position, keeping the choice deterministic.
					let slot = ready.firstIndex { $0 > target } ?? ready.count
					ready.insert(target, at: slot)
				}
			}
		}

		return order.count == nodes.count ? order : nil
	}
}

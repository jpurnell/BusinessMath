//
//  TransitionMatrix.swift
//  BusinessMath
//

import Foundation
import Numerics

/// A finite-state Markov chain, built from observed sequences or from an explicit matrix.
///
/// ```swift
/// let journeys = [["C1", "conversion"], ["C2", "null"], ["C1", "C2", "conversion"]]
/// if let chain = TransitionMatrix<Double>(paths: journeys) {
///     let rate = chain.absorptionProbability(to: "conversion", from: "(start)")
///     let shares = chain.attributionShares(converting: "conversion")
///     print(rate ?? 0, shares ?? [:])
/// }
/// ```
///
/// ## One implementation, three legs
///
/// This is the highest-leverage object in `Network/` because the same chain answers
/// questions from three different disciplines:
///
/// - **Marketing** — attribution by removal effect, and customer state transitions.
/// - **Finance** — credit-rating migration matrices, which are transition matrices with
///   a different vocabulary.
/// - **Operations** — machine states, queue states, anything with a memoryless step.
///
/// It is filed in `Network/` rather than under any of them for that reason.
///
/// ## What the Markov assumption buys and costs
///
/// The next state depends on the current one and on nothing earlier. For a customer
/// journey that is a real assumption and it is often wrong — a second visit to a channel
/// may mean something different from the first — and it is what makes the model tractable
/// enough to answer counterfactuals at all. The removal effect is a counterfactual, and
/// no amount of data makes it observable; it is only ever as good as the assumption.
public struct TransitionMatrix<T: Real & Sendable & BinaryFloatingPoint>: Sendable {

	/// The state names, sorted. Sorted rather than in first-seen order so the matrix does
	/// not depend on the order the journeys arrived in.
	public let states: [String]

	/// Row-stochastic transition probabilities, indexed by ``states``.
	public let rows: [[T]]

	/// Where each state sits in ``states``. Internal rather than private so the
	/// absorption and removal-effect files can index without a linear search.
	let position: [String: Int]

	/// The name given to the synthetic state every path is taken to begin from.
	public let startState: String

	/// Builds a chain by counting transitions in observed sequences.
	///
	/// Each path is prefixed with ``startState``, so the first real step carries the
	/// information about which state journeys begin in — without it that distribution is
	/// lost and every question about "where do people start" becomes unanswerable.
	///
	/// A state that never leads anywhere becomes absorbing, with a self-loop of one. That
	/// is inferred rather than declared: a terminal outcome is exactly a state no
	/// observed transition leaves.
	///
	/// - Parameters:
	///   - paths: Observed sequences, each at least one state long.
	///   - startState: The synthetic origin. Defaults to `"(start)"`, chosen with
	///     parentheses so it cannot collide with a real state name.
	/// - Returns: `nil` if there are no paths, or none with any content.
	public init?(paths: [[String]], startState: String = "(start)") {
		guard !paths.isEmpty else { return nil }
		var counts: [String: [String: T]] = [:]
		var seen: Set<String> = []
		var any = false
		for path in paths where !path.isEmpty {
			any = true
			let sequence = [startState] + path
			seen.formUnion(sequence)
			for (from, to) in zip(sequence, sequence.dropFirst()) {
				counts[from, default: [:]][to, default: T.zero] += 1
			}
		}
		guard any else { return nil }

		let ordered = seen.sorted()
		var index: [String: Int] = [:]
		for (slot, name) in ordered.enumerated() { index[name] = slot }

		var matrix = [[T]](repeating: [T](repeating: T.zero, count: ordered.count),
						   count: ordered.count)
		for (slot, name) in ordered.enumerated() {
			guard let outgoing = counts[name], !outgoing.isEmpty else {
				// Nothing ever left this state, so it is absorbing.
				matrix[slot][slot] = T(1)
				continue
			}
			let total = outgoing.values.reduce(T.zero, +)
			guard total > T.zero else { matrix[slot][slot] = T(1); continue }
			for (target, count) in outgoing {
				guard let column = index[target] else { continue }
				matrix[slot][column] = count / total
			}
		}

		self.states = ordered
		self.rows = matrix
		self.position = index
		self.startState = startState
	}

	/// Builds a chain from an explicit row-stochastic matrix.
	///
	/// The entry point a credit-rating migration matrix arrives through, where the
	/// probabilities are published rather than counted.
	///
	/// - Parameters:
	///   - states: The state names, in the order the rows use.
	///   - rows: A square matrix whose rows are non-negative and sum to one.
	///   - startState: A name for the origin, used only by path-based queries.
	/// - Returns: `nil` unless the matrix is square, matches `states`, and every row is a
	///   probability distribution.
	public init?(states: [String], rows: [[T]], startState: String = "(start)") {
		guard !states.isEmpty, rows.count == states.count else { return nil }
		guard rows.allSatisfy({ $0.count == states.count }) else { return nil }
		for row in rows {
			guard row.allSatisfy({ $0 >= T.zero && $0.isFinite }) else { return nil }
			let total = row.reduce(T.zero, +)
			let drift: T = total - 1
			let size: T = drift < T.zero ? -drift : drift
			guard size < T(1) / T(1_000_000) else { return nil }
		}
		var index: [String: Int] = [:]
		for (slot, name) in states.enumerated() { index[name] = slot }
		guard index.count == states.count else { return nil }
		self.states = states
		self.rows = rows
		self.position = index
		self.startState = startState
	}

	/// The one-step probability of moving between two states.
	///
	/// - Parameters:
	///   - from: The current state.
	///   - to: The next state.
	/// - Returns: The probability, or zero if either name is not a state.
	public func probability(from: String, to: String) -> T {
		guard let row = position[from], let column = position[to] else { return T.zero }
		return rows[row][column]
	}

	/// Every state that only ever leads to itself.
	public var absorbingStates: [String] {
		states.enumerated().compactMap { slot, name in
			let selfLoop = rows[slot][slot]
			let drift: T = selfLoop - 1
			let size: T = drift < T.zero ? -drift : drift
			return size < T(1) / T(1_000_000_000) ? name : nil
		}
	}
}

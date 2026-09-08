//
//  RemovalEffect.swift
//  BusinessMath
//

import Foundation
import Numerics

public extension TransitionMatrix {

	/// How much of the conversion probability disappears when a state is removed.
	///
	/// `1 − P(convert | state removed) / P(convert)`. Removing a state means journeys
	/// that would have reached it are redirected to failure instead, so the effect
	/// measures what the chain loses without that step — not what passed through it.
	///
	/// ## Why this is not a share of anything yet
	///
	/// Removal effects do not sum to one and are not meant to. A channel that appears in
	/// every converting journey has a removal effect near one; if two such channels both
	/// exist, both do, and their effects sum well past one. That is not a defect — it is
	/// the honest statement that either one alone would carry most of the value.
	///
	/// ``attributionShares(converting:)`` normalises them into a budget split, and the
	/// normalisation is the step where the answer stops being a measurement and starts
	/// being a convention.
	///
	/// ## What it cannot know
	///
	/// This is a counterfactual. No amount of observed data contains the world where a
	/// channel was absent, so the number is only ever as good as the Markov assumption
	/// underneath it — that the next state depends on the current one and nothing
	/// earlier. For a customer journey that assumption is often wrong and always
	/// unverifiable from the same data.
	///
	/// - Parameters:
	///   - state: The state to remove. Must be transient and must not be the start.
	///   - target: The absorbing state whose probability is being measured.
	/// - Returns: The removal effect, or `nil` for an unknown state, an absorbing one, the
	///   start state, or a chain that never reaches `target` at all — a ratio against a
	///   baseline of zero is not zero, it is undefined.
	func removalEffect(of state: String, converting target: String) -> T? {
		guard position[state] != nil, position[target] != nil else { return nil }
		guard state != startState else { return nil }
		guard !absorbingStates.contains(state) else { return nil }
		guard let baseline = absorptionProbability(to: target, from: startState),
			  baseline > T.zero else { return nil }
		guard let reduced = removing(state) else { return nil }
		guard let without = reduced.absorptionProbability(to: target, from: startState) else {
			return nil
		}
		let ratio: T = without / baseline
		return 1 - ratio
	}

	/// Removal effects for every channel, normalised to sum to one.
	///
	/// The start state and the absorbing outcomes are excluded: an outcome is what is
	/// being attributed and cannot be a claimant on itself, and the start state is
	/// bookkeeping rather than a channel anyone paid for.
	///
	/// - Parameter target: The absorbing state being attributed.
	/// - Returns: A share per channel, or `nil` if nothing reaches `target` or no channel
	///   has any effect — a budget split among states that make no difference is a
	///   division by zero dressed up as an answer.
	func attributionShares(converting target: String) -> [String: T]? {
		let absorbing = Set(absorbingStates)
		let channels = states.filter { $0 != startState && !absorbing.contains($0) }
		guard !channels.isEmpty else { return nil }

		var effects: [String: T] = [:]
		var total: T = T.zero
		for channel in channels {
			guard let effect = removalEffect(of: channel, converting: target) else {
				return nil
			}
			let positive: T = Swift.max(effect, T.zero)
			effects[channel] = positive
			total += positive
		}
		guard total > T.zero else { return nil }
		var shares: [String: T] = [:]
		for (channel, effect) in effects { shares[channel] = effect / total }
		return shares
	}

	/// The same chain with one state deleted, its inbound mass redirected to failure.
	///
	/// The redirection is the substance of the removal effect. Simply deleting the state
	/// and renormalising the remaining rows would ask a different question — *"what if
	/// this channel's traffic had gone elsewhere"* — and would generally raise the
	/// conversion rate rather than lower it, since the removed paths were often the
	/// unsuccessful ones.
	///
	/// Redirecting to a failure state asks *"what if this channel had not existed and its
	/// journeys had simply ended"*, which is the counterfactual the method is named for.
	///
	/// There is a third thing one might do, and it is worth naming because it is the
	/// natural mistake: truncate the observed paths at the removed channel and rebuild
	/// the chain from the modified data. That also produces plausible numbers, and they
	/// differ — on the fixture in `MarkovTests` it gives 0.833, 0.333, 0.333 where this
	/// gives 0.646, 0.250, 0.333 — because rebuilding recomputes the start row too,
	/// changing where journeys are taken to begin. This method operates on the graph and
	/// leaves every surviving probability exactly as observed, which is the definition
	/// the attribution literature uses.
	///
	/// - Parameter state: The state to remove.
	/// - Returns: The reduced chain, or `nil` if the state is unknown.
	func removing(_ state: String) -> TransitionMatrix<T>? {
		guard let removed = position[state] else { return nil }
		let failure = "(removed)"
		var remaining = states.filter { $0 != state }
		remaining.append(failure)
		remaining.sort()

		var index: [String: Int] = [:]
		for (slot, name) in remaining.enumerated() { index[name] = slot }
		let size = remaining.count
		var matrix = [[T]](repeating: [T](repeating: T.zero, count: size), count: size)

		for (row, name) in remaining.enumerated() {
			if name == failure {
				matrix[row][row] = T(1)
				continue
			}
			guard let source = position[name] else { continue }
			for (column, target) in remaining.enumerated() where target != failure {
				guard let sink = position[target] else { continue }
				matrix[row][column] = rows[source][sink]
			}
			// Everything that used to go to the removed state now ends the journey.
			if let sink = index[failure] {
				matrix[row][sink] += rows[source][removed]
			}
		}
		return TransitionMatrix(states: remaining, rows: matrix, startState: startState)
	}
}

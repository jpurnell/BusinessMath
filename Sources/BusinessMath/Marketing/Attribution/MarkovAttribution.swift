//
//  MarkovAttribution.swift
//  BusinessMath
//

import Foundation
import Numerics

/// Attribution by removal effect: what the conversion rate loses without each channel.
///
/// ```swift
/// let journeys = [
///     Journey(channels: ["Awareness", "Close"], converted: true, value: 1),
///     Journey(channels: ["Close"], converted: false, value: 0)
/// ]
/// let model = MarkovAttribution()
/// let credit = try model.attribute(journeys: journeys)
/// print(credit["Awareness"] ?? 0)
/// ```
///
/// ## What this measures that a heuristic cannot
///
/// Journeys become paths through a Markov chain — every journey ends in a conversion state
/// or a null state, so the **failures are data** rather than rows to filter out. Removing a
/// channel means redirecting the traffic that would have reached it into failure, and the
/// removal effect is the share of conversion probability that disappears when you do.
///
/// That is a counterfactual, and it answers the question a budget decision actually asks.
/// Last touch will tell you an upper-funnel channel is worth exactly zero because it never
/// closes; removal effect will tell you the conversion rate halves without it. Both are
/// arithmetic on the same data, and only one of them is about what would happen if you cut
/// the spend.
///
/// ## Two honest limits
///
/// **The chain counts journeys, not money.** Transition probabilities come from how often
/// each step was observed, so a conversion worth ten thousand and one worth ten contribute
/// equally to the shares. ``attribute(journeys:)`` then scales those shares by the total
/// value, which keeps the efficiency contract but does not make the split value-aware. If
/// value varies a great deal across journeys, segment first and attribute within segments.
///
/// **The Markov assumption is unverifiable from the same data.** The next state is taken to
/// depend on the current one and nothing earlier. For a customer journey that is often
/// wrong, and no amount of observed data contains the world in which a channel was absent.
/// The number is a model output, not a measurement.
///
/// ## Shares are a convention, effects are the measurement
///
/// ``removalEffects(journeys:)`` returns the raw effects, which do **not** sum to one and
/// are not meant to: if two channels each appear in every converting journey, both have an
/// effect near one, and that is the honest statement that either alone would carry most of
/// the value. ``attribute(journeys:)`` normalises them into a budget split, and the
/// normalisation is the step where a measurement becomes a convention. Look at both.
public struct MarkovAttribution: AttributionModel, Sendable, Equatable {

	/// The absorbing state a converting journey ends in.
	public let conversionState: String

	/// The absorbing state a failed journey ends in.
	public let nullState: String

	/// The synthetic origin every path is prefixed with.
	public let startState: String

	/// The name ``TransitionMatrix/removing(_:)`` gives its failure sink, which a channel
	/// therefore cannot be called either.
	static let removalState = "(removed)"

	/// Creates a model.
	///
	/// - Parameters:
	///   - conversionState: Where converting journeys end. Parenthesised by default so it
	///     cannot collide with a real channel name.
	///   - nullState: Where failed journeys end.
	///   - startState: The synthetic origin.
	public init(conversionState: String = "(conversion)",
				nullState: String = "(null)",
				startState: String = "(start)") {
		self.conversionState = conversionState
		self.nullState = nullState
		self.startState = startState
	}

	/// The channels observed, in sorted order, across converting and failed journeys alike.
	///
	/// - Parameter journeys: Every journey observed.
	/// - Returns: Distinct channel names, sorted.
	public func channels(in journeys: [Journey]) -> [String] {
		var seen: Set<String> = []
		for journey in journeys { seen.formUnion(journey.channels) }
		return seen.sorted()
	}

	/// The chain the journeys describe.
	///
	/// - Parameter journeys: Every journey observed.
	/// - Returns: A row-stochastic chain over the channels plus the two outcomes.
	/// - Throws: ``AttributionError``. In particular
	///   ``AttributionError/degenerateChain(reason:)`` when a channel is named after one
	///   of the synthetic states, which would silently merge a real channel into
	///   bookkeeping.
	public func chain(from journeys: [Journey]) throws -> TransitionMatrix<Double> {
		_ = try validatedConversions(in: journeys)
		let reserved: Set<String> = [conversionState, nullState, startState,
									 Self.removalState]
		for channel in channels(in: journeys) where reserved.contains(channel) {
			throw AttributionError.degenerateChain(
				reason: "channel '\(channel)' collides with a reserved state")
		}

		var paths: [[String]] = []
		for journey in journeys {
			let terminal = journey.converted ? conversionState : nullState
			paths.append(journey.channels + [terminal])
		}
		guard let matrix = TransitionMatrix<Double>(paths: paths, startState: startState) else {
			throw AttributionError.degenerateChain(reason: "no transitions to count")
		}
		return matrix
	}

	/// The raw removal effect of each channel.
	///
	/// - Parameter journeys: Every journey observed.
	/// - Returns: `1 − P(convert | channel removed) / P(convert)` per channel. These do
	///   not sum to one; see the note on this type.
	/// - Throws: ``AttributionError``.
	public func removalEffects(journeys: [Journey]) throws -> [String: Double] {
		let matrix = try chain(from: journeys)
		var effects: [String: Double] = [:]
		for channel in channels(in: journeys) {
			guard let effect = matrix.removalEffect(of: channel,
													converting: conversionState) else {
				throw AttributionError.degenerateChain(
					reason: "no removal effect for '\(channel)'")
			}
			effects[channel] = effect
		}
		return effects
	}

	/// Conversion value split by normalised removal effect.
	///
	/// - Parameter journeys: Every journey observed, converting or not.
	/// - Returns: Credit per channel, summing to the total converted value.
	/// - Throws: ``AttributionError``.
	public func attribute(journeys: [Journey]) throws -> [String: Double] {
		let matrix = try chain(from: journeys)
		guard let shares = matrix.attributionShares(converting: conversionState) else {
			throw AttributionError.degenerateChain(
				reason: "no channel changes the conversion probability")
		}
		let total = totalConversionValue(in: journeys)
		var credit: [String: Double] = [:]
		for (channel, share) in shares { credit[channel] = share * total }
		return credit
	}
}

//
//  AttributionModel.swift
//  BusinessMath
//

import Foundation
import Numerics

/// One customer's path to a conversion, or to nothing.
public struct Journey: Sendable, Equatable {

	/// The channels touched, earliest first. A channel may appear more than once.
	public let channels: [String]

	/// Whether the journey ended in a conversion.
	public let converted: Bool

	/// What the conversion was worth. Leave at one to attribute conversion *counts*.
	public let value: Double

	/// How long before the conversion each touch happened, in whatever unit the
	/// half-life is quoted in. Same length as ``channels``, and `nil` when unrecorded.
	///
	/// Only ``HeuristicAttribution/timeDecay(halfLife:)`` reads this, and it refuses
	/// rather than substitute position for recency.
	public let ages: [Double]?

	/// Creates a journey.
	///
	/// - Parameters:
	///   - channels: Channels touched, earliest first.
	///   - converted: Whether it ended in a conversion.
	///   - value: What the conversion was worth. Defaults to one.
	///   - ages: Time before conversion per touch, same length as `channels`.
	public init(channels: [String], converted: Bool, value: Double = 1, ages: [Double]? = nil) {
		self.channels = channels
		self.converted = converted
		self.value = value
		self.ages = ages
	}
}

/// Why credit could not be assigned.
public enum AttributionError: Error, Sendable, Equatable {

	/// Nothing was supplied.
	case noJourneys

	/// Nobody converted, so there is no credit to divide.
	case noConversions

	/// A journey touched no channels at all.
	case emptyJourney(index: Int)

	/// A journey's value is negative or not finite.
	case invalidValue(index: Int)

	/// A journey's timings do not line up with its touches.
	case mismatchedAges(index: Int)

	/// Position weights that do not describe a split.
	case invalidWeights(first: Double, last: Double)

	/// A half-life that is not a positive duration.
	case invalidHalfLife(Double)

	/// Time decay was asked for on journeys that carry no timings.
	case missingTimings

	/// Exact Shapley enumeration was asked for on more channels than it can enumerate.
	case tooManyChannels(count: Int, limit: Int)

	/// The journeys do not form a chain anything can be attributed over.
	case degenerateChain(reason: String)
}

/// A rule for dividing conversion credit among the channels that touched a journey.
///
/// ## The contract every model keeps
///
/// **Efficiency.** Attributed credit sums to the total value of the converting journeys —
/// no more and no less. It is the one property that holds across heuristics, Markov
/// removal effect and Shapley alike, so it is worth checking rather than trusting:
/// ``totalConversionValue(in:)`` is what the returned dictionary must add up to.
///
/// **Non-converting journeys are validated but earn nothing.** They are still required to
/// be well-formed, because the models that *can* use them — ``MarkovAttribution`` and
/// ``ShapleyAttribution`` — need them to say anything about incrementality at all. A
/// heuristic cannot: with only the converting journeys in view there is no way to tell a
/// channel that appears in every path from one that appears only in the successful ones.
/// That is the difference between describing what happened and estimating what a channel
/// did, and it is why the heuristics below are labelled heuristics.
///
/// **Zero and absent mean different things.** A channel present at zero was measured and
/// earned nothing. A channel absent from the result was not measurable by this model at
/// all — which for the heuristics is any channel that appears only in journeys that
/// failed, since those journeys carry no credit to divide. ``MarkovAttribution`` and
/// ``ShapleyAttribution`` do see them, and score them.
public protocol AttributionModel: Sendable {

	/// Divides conversion credit among channels.
	///
	/// - Parameter journeys: Every journey observed, converting or not.
	/// - Returns: Credit per channel. A channel the model measured and gave nothing is
	///   present at zero, not absent — "measured, and it is zero" is a finding, and it is
	///   the finding last touch makes about every channel that never closes. Absence
	///   means the model had nothing to say at all.
	/// - Throws: ``AttributionError``.
	func attribute(journeys: [Journey]) throws -> [String: Double]
}

public extension AttributionModel {

	/// Checks the journeys and hands back the ones that converted.
	///
	/// Every journey is validated, including the ones that did not convert — malformed
	/// data is malformed whatever its outcome, and the models that read the failures need
	/// them sound.
	///
	/// - Parameter journeys: Every journey observed.
	/// - Returns: The converting journeys, in the order given.
	/// - Throws: ``AttributionError/noJourneys``, ``AttributionError/emptyJourney(index:)``,
	///   ``AttributionError/invalidValue(index:)``, ``AttributionError/mismatchedAges(index:)``
	///   or ``AttributionError/noConversions``.
	func validatedConversions(in journeys: [Journey]) throws -> [Journey] {
		guard !journeys.isEmpty else { throw AttributionError.noJourneys }
		for (index, journey) in journeys.enumerated() {
			guard !journey.channels.isEmpty else {
				throw AttributionError.emptyJourney(index: index)
			}
			guard journey.value.isFinite, journey.value >= 0 else {
				throw AttributionError.invalidValue(index: index)
			}
			if let ages = journey.ages {
				guard ages.count == journey.channels.count else {
					throw AttributionError.mismatchedAges(index: index)
				}
				guard ages.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
					throw AttributionError.mismatchedAges(index: index)
				}
			}
		}
		let converting = journeys.filter { $0.converted }
		guard !converting.isEmpty else { throw AttributionError.noConversions }
		return converting
	}

	/// The total value of the converting journeys — what ``attribute(journeys:)`` must
	/// sum to.
	///
	/// - Parameter journeys: Every journey observed.
	/// - Returns: The sum of `value` over the converting journeys.
	func totalConversionValue(in journeys: [Journey]) -> Double {
		var total: Double = 0
		for journey in journeys where journey.converted { total += journey.value }
		return total
	}
}

/// The four rules that divide credit by position or recency alone.
///
/// ```swift
/// let journeys = [
///     Journey(channels: ["Search", "Email", "Retarget"], converted: true, value: 120),
///     Journey(channels: ["Search"], converted: false, value: 0)
/// ]
/// let credit = try HeuristicAttribution.linear.attribute(journeys: journeys)
/// print(credit["Search"] ?? 0)
/// ```
///
/// ## What these can and cannot answer
///
/// Each of these is a *description* of where the touches fell. None is an estimate of what
/// a channel caused, because none of them looks at the journeys that failed. Last touch
/// gives an upper-funnel channel that opens journeys and never closes them a score of
/// exactly zero — not "small", zero — and first touch inverts the same error rather than
/// fixing it.
///
/// They are here because they are what most reporting quotes, they are cheap, and they are
/// the baseline the incremental models have to beat. When the question is "what should I
/// cut", use ``MarkovAttribution`` or ``ShapleyAttribution``.
///
/// ## The rules
///
/// - ``firstTouch`` and ``lastTouch`` give everything to one end.
/// - ``linear`` splits evenly across **touches**, not across distinct channels, so a
///   channel touched twice in one journey is credited twice. The alternative convention —
///   splitting across unique channels — is defensible and is not what this does.
/// - ``positionBased(first:last:)`` gives each end its weight and shares what is left
///   among the middle touches. With fewer than three touches there is no middle, and the
///   two end weights are renormalised against each other.
/// - ``timeDecay(halfLife:)`` halves a touch's weight for every half-life it sits before
///   the conversion. It **requires** ``Journey/ages`` and throws without them, because
///   position is not recency: three touches spread over a month and three touches in one
///   afternoon decay completely differently and index-as-proxy cannot tell them apart.
public enum HeuristicAttribution: AttributionModel, Sendable, Equatable {

	/// Everything to the channel that opened the journey.
	case firstTouch

	/// Everything to the channel that closed it.
	case lastTouch

	/// An equal share to every touch.
	case linear

	/// A weight to each end, the remainder shared by the middle.
	case positionBased(first: Double, last: Double)

	/// Weight halving every half-life before the conversion.
	case timeDecay(halfLife: Double)

	/// The common forty–twenty–forty split.
	public static let uShaped = HeuristicAttribution.positionBased(first: 0.4, last: 0.4)

	/// Divides credit by this rule.
	///
	/// - Parameter journeys: Every journey observed, converting or not.
	/// - Returns: Credit per channel, summing to the converted value.
	/// - Throws: ``AttributionError``.
	public func attribute(journeys: [Journey]) throws -> [String: Double] {
		let converting = try validatedConversions(in: journeys)
		try validateParameters()

		var credit: [String: Double] = [:]
		for (index, journey) in converting.enumerated() {
			let weights = try self.weights(for: journey, index: index)
			for (channel, weight) in zip(journey.channels, weights) {
				let share: Double = weight * journey.value
				credit[channel, default: 0] += share
			}
		}
		return credit
	}

	/// Checks the rule's own arguments, which are a caller's constants rather than data.
	///
	/// - Throws: ``AttributionError/invalidWeights(first:last:)`` or
	///   ``AttributionError/invalidHalfLife(_:)``.
	func validateParameters() throws {
		switch self {
		case .positionBased(let first, let last):
			guard first.isFinite, last.isFinite, first >= 0, last >= 0 else {
				throw AttributionError.invalidWeights(first: first, last: last)
			}
			let ends: Double = first + last
			guard ends <= 1 else {
				throw AttributionError.invalidWeights(first: first, last: last)
			}
			guard ends > 0 else {
				throw AttributionError.invalidWeights(first: first, last: last)
			}
		case .timeDecay(let halfLife):
			guard halfLife.isFinite, halfLife > 0 else {
				throw AttributionError.invalidHalfLife(halfLife)
			}
		case .firstTouch, .lastTouch, .linear:
			return
		}
	}

	/// One weight per touch, summing to one.
	///
	/// - Parameters:
	///   - journey: The journey to weight.
	///   - index: Its position, used only to name a journey in an error.
	/// - Returns: Weights in touch order.
	/// - Throws: ``AttributionError``.
	func weights(for journey: Journey, index: Int) throws -> [Double] {
		let count = journey.channels.count
		let touches: Double = Double(count)
		guard count > 0, touches > 0 else {
			throw AttributionError.emptyJourney(index: index)
		}
		var weights = [Double](repeating: 0, count: count)
		switch self {
		case .firstTouch:
			weights[0] = 1
		case .lastTouch:
			weights[count - 1] = 1
		case .linear:
			let share: Double = 1 / touches
			for slot in 0..<count { weights[slot] = share }
		case .positionBased(let first, let last):
			if count == 1 {
				weights[0] = 1
				break
			}
			let ends: Double = first + last
			guard ends > 0 else {
				throw AttributionError.invalidWeights(first: first, last: last)
			}
			let spread: Double = Double(count - 2)
			guard spread > 0 else {
				// Two touches and no middle, so the ends renormalise against each other.
				weights[0] = first / ends
				weights[1] = last / ends
				break
			}
			weights[0] = first
			weights[count - 1] = last
			let middle: Double = 1 - ends
			let each: Double = middle / spread
			for slot in 1..<(count - 1) { weights[slot] = each }
		case .timeDecay(let halfLife):
			guard halfLife > 0 else { throw AttributionError.invalidHalfLife(halfLife) }
			guard let ages = journey.ages else { throw AttributionError.missingTimings }
			var raw = [Double](repeating: 0, count: count)
			var total: Double = 0
			for slot in 0..<count {
				let periods: Double = ages[slot] / halfLife
				let weight: Double = Double.pow(2, -periods)
				raw[slot] = weight
				total += weight
			}
			guard total > 0 else { throw AttributionError.missingTimings }
			for slot in 0..<count { weights[slot] = raw[slot] / total }
		}
		return weights
	}
}

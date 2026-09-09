//
//  ShapleyAttribution.swift
//  BusinessMath
//

import Foundation
import Numerics

/// Attribution by the Shapley value: each channel's average marginal contribution.
///
/// ```swift
/// let journeys = [
///     Journey(channels: ["Search"], converted: true, value: 1),
///     Journey(channels: ["Search", "Email"], converted: true, value: 1)
/// ]
/// let credit = try ShapleyAttribution().attribute(journeys: journeys)
/// print(credit["Email"] ?? 0)
/// ```
///
/// ## What it computes
///
/// A coalition `S` of channels is worth `v(S)` — the total value of the converting
/// journeys whose channels all lie inside `S`. A channel's Shapley value is its average
/// marginal contribution `v(S ∪ {i}) − v(S)`, taken over every order in which the
/// channels could have arrived:
///
/// ```
/// φᵢ = Σ  |S|! (n − |S| − 1)! / n!  ·  [ v(S ∪ {i}) − v(S) ]
///     S ⊆ N\{i}
/// ```
///
/// This is exact enumeration, not a sample. Every subset is evaluated, which is why there
/// is a channel limit.
///
/// ## Why this and not removal effect
///
/// Both use the failures. They differ in what they hold fixed. Removal effect asks what
/// happens when one channel disappears from a chain that keeps its shape;
/// ``MarkovAttribution`` therefore depends on the order channels were touched in. Shapley
/// ignores order entirely — a journey is a *set* of channels — and instead averages over
/// every possible arrival sequence.
///
/// That makes Shapley the right tool when the question is "what is this channel worth in
/// combination with the others" and the wrong one when sequence is the point. It is also
/// the only model here that satisfies the four axioms — efficiency, symmetry, the null
/// player, and additivity — uniquely, which is the sense in which it is "fair": no other
/// division satisfies all four.
///
/// ## The axioms, and what they buy
///
/// - **Efficiency.** The values sum to `v(N)`, the total converted value. Shared with
///   every other ``AttributionModel``.
/// - **Symmetry.** Two channels that contribute identically to every coalition receive
///   identical credit, whatever their names or ordering.
/// - **Null player.** A channel whose presence never changes `v` receives **exactly**
///   zero — not approximately. A channel appearing only in journeys that failed is
///   precisely that case, and it is present at zero in the result rather than absent,
///   because "measured, and it contributes nothing" is a finding a heuristic cannot make.
/// - **Additivity.** Values over combined data are the sum of values over the parts.
///
/// ## Cost
///
/// `O(2ⁿ · n)` in the number of distinct channels, computed with a subset-sum transform
/// rather than by re-scanning journeys per coalition. Sixteen channels is 65,536 coalitions
/// and runs in milliseconds; twenty is a million and does not. Above ``channelLimit`` this
/// throws ``AttributionError/tooManyChannels(count:limit:)`` rather than run for an
/// unbounded time, and the remedy is to group channels before attributing.
public struct ShapleyAttribution: AttributionModel, Sendable, Equatable {

	/// The largest number of distinct channels this will enumerate.
	///
	/// Defaults to sixteen. The weights are built from factorials, and `16!` is the
	/// largest that a `Double` holds exactly, so the ceiling is where the arithmetic
	/// stops being exact as well as where it stops being quick.
	public let channelLimit: Int

	/// Creates a model.
	///
	/// - Parameter channelLimit: Largest distinct-channel count to enumerate. Values above
	///   sixteen are clamped to sixteen, beyond which the factorial weights are no longer
	///   exact in `Double`.
	public init(channelLimit: Int = 16) {
		self.channelLimit = Swift.min(Swift.max(channelLimit, 1), 16)
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

	/// What a coalition is worth: the value of the converting journeys it fully covers.
	///
	/// - Parameters:
	///   - coalition: The channels assumed present.
	///   - journeys: Every journey observed.
	/// - Returns: The total value of converting journeys whose channels all lie inside
	///   `coalition`. A journey needing a channel the coalition lacks contributes nothing.
	/// - Throws: ``AttributionError``.
	public func coalitionValue(_ coalition: Set<String>,
							   journeys: [Journey]) throws -> Double {
		let converting = try validatedConversions(in: journeys)
		var total: Double = 0
		for journey in converting where Set(journey.channels).isSubset(of: coalition) {
			total += journey.value
		}
		return total
	}

	/// Divides conversion value by Shapley value.
	///
	/// - Parameter journeys: Every journey observed, converting or not.
	/// - Returns: Credit per channel, summing to the total converted value. Every observed
	///   channel is present, including those worth exactly zero.
	/// - Throws: ``AttributionError``.
	public func attribute(journeys: [Journey]) throws -> [String: Double] {
		let converting = try validatedConversions(in: journeys)
		let names = channels(in: journeys)
		let count = names.count
		guard count <= channelLimit else {
			throw AttributionError.tooManyChannels(count: count, limit: channelLimit)
		}

		var slot: [String: Int] = [:]
		for (index, name) in names.enumerated() { slot[name] = index }

		// Value of the journeys whose channel set is exactly this mask.
		let size = 1 << count
		var exact = [Double](repeating: 0, count: size)
		for journey in converting {
			var mask = 0
			for channel in journey.channels {
				guard let bit = slot[channel] else { continue }
				mask |= 1 << bit
			}
			exact[mask] += journey.value
		}

		// Subset sum, so `worth[S]` becomes the value of every journey covered by S.
		// One pass per channel beats re-scanning the journeys for each of 2ⁿ coalitions.
		var worth = exact
		for bit in 0..<count {
			let flag = 1 << bit
			for mask in 0..<size where mask & flag != 0 {
				worth[mask] += worth[mask ^ flag]
			}
		}

		let weights = Self.coalitionWeights(count: count)
		var credit: [String: Double] = [:]
		for bit in 0..<count {
			let flag = 1 << bit
			var value: Double = 0
			for mask in 0..<size where mask & flag == 0 {
				let members = mask.nonzeroBitCount
				let marginal: Double = worth[mask | flag] - worth[mask]
				let weighted: Double = weights[members] * marginal
				value += weighted
			}
			credit[names[bit]] = value
		}
		return credit
	}

	/// `|S|!(n − |S| − 1)!/n!` for every coalition size, precomputed.
	///
	/// - Parameter count: The number of channels, at most sixteen.
	/// - Returns: One weight per coalition size from zero to `count − 1`.
	static func coalitionWeights(count: Int) -> [Double] {
		var factorial = [Double](repeating: 1, count: count + 1)
		for value in 1...Swift.max(count, 1) where value <= count {
			factorial[value] = factorial[value - 1] * Double(value)
		}
		var weights = [Double](repeating: 0, count: Swift.max(count, 1))
		let orderings: Double = factorial[count]
		guard orderings > 0 else { return weights }
		for members in 0..<Swift.max(count, 1) {
			let others = count - members - 1
			guard others >= 0 else { continue }
			let numerator: Double = factorial[members] * factorial[others]
			weights[members] = numerator / orderings
		}
		return weights
	}
}

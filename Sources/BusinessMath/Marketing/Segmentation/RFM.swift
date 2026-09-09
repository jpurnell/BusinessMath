//
//  RFM.swift
//  BusinessMath
//

import Foundation
import Numerics

/// One customer's recency, frequency and monetary history.
public struct RFMInput<T: Real & Sendable>: Sendable {

	/// Who.
	public let identifier: String

	/// **Days since** the most recent purchase. Lower is better — see ``RFMSegmentation``.
	public let recencyDays: T

	/// How many purchases in the window.
	public let frequency: T

	/// How much they spent in it.
	public let monetary: T

	/// Creates an input.
	///
	/// - Parameters:
	///   - identifier: A unique customer key.
	///   - recencyDays: Days since the last purchase, non-negative.
	///   - frequency: Purchase count, non-negative.
	///   - monetary: Spend, non-negative.
	public init(identifier: String, recencyDays: T, frequency: T, monetary: T) {
		self.identifier = identifier
		self.recencyDays = recencyDays
		self.frequency = frequency
		self.monetary = monetary
	}
}

/// One customer's tier on each dimension.
public struct RFMScore: Sendable, Equatable {

	/// Recency tier, highest for the most recent.
	public let recency: Int

	/// Frequency tier, highest for the most frequent.
	public let frequency: Int

	/// Monetary tier, highest for the biggest spender.
	public let monetary: Int

	/// The three summed — the conventional single number, and a lossy one: a 5-1-1 and a
	/// 1-1-5 both total seven and describe entirely different customers. Keep the three
	/// where the distinction matters.
	public var combined: Int { recency + frequency + monetary }

	/// Creates a score.
	///
	/// - Parameters:
	///   - recency: Recency tier.
	///   - frequency: Frequency tier.
	///   - monetary: Monetary tier.
	public init(recency: Int, frequency: Int, monetary: Int) {
		self.recency = recency
		self.frequency = frequency
		self.monetary = monetary
	}
}

/// Customers scored into tiers on recency, frequency and monetary value.
///
/// ```swift
/// let customers = [RFMInput(identifier: "a", recencyDays: 12.0, frequency: 8, monetary: 900)]
/// if let segmentation = RFMSegmentation(customers: customers, tiers: 5) {
///     print(segmentation.scores["a"]?.combined ?? 0)
/// }
/// ```
///
/// ## Recency runs the other way, and getting it wrong is invisible
///
/// Frequency and monetary score upward — more is better. **Recency is days *since* the
/// last purchase, so less is better**, and the tier assignment has to be inverted for
/// that one dimension alone.
///
/// Scored like the other two, the segmentation ranks a customer who has not bought in a
/// year above one who bought yesterday. Every tier is still in range, every customer is
/// still scored, the distribution across tiers is still uniform, and the resulting
/// campaign targets exactly the wrong people. There is no arithmetic error to find, which
/// is why `recencyIsInverted` is a test rather than a comment.
///
/// ## Tiers are quantiles, not thresholds
///
/// Each dimension is split so the tiers are equally populated, which makes the scores
/// comparable across cohorts of different sizes and shapes. It also means a tier is
/// always relative: in a cohort where everyone bought yesterday, someone still lands in
/// tier one.
public struct RFMSegmentation<T: Real & Sendable & BinaryFloatingPoint>: Sendable {

	/// Score per customer identifier.
	public let scores: [String: RFMScore]

	/// How many tiers each dimension was split into.
	public let tiers: Int

	/// Scores a cohort.
	///
	/// - Parameters:
	///   - customers: The cohort. Identifiers must be unique.
	///   - tiers: How many tiers per dimension, at least two.
	/// - Returns: `nil` for an empty cohort, fewer than two tiers, a negative or
	///   non-finite input, or duplicate identifiers — which would silently overwrite one
	///   another in the result and leave a cohort smaller than the data.
	public init?(customers: [RFMInput<T>], tiers: Int) {
		guard !customers.isEmpty, tiers >= 2 else { return nil }
		guard customers.allSatisfy({
			$0.recencyDays >= T.zero && $0.recencyDays.isFinite
				&& $0.frequency >= T.zero && $0.frequency.isFinite
				&& $0.monetary >= T.zero && $0.monetary.isFinite
		}) else { return nil }
		let identifiers = Set(customers.map { $0.identifier })
		guard identifiers.count == customers.count else { return nil }

		// Ascending in the direction where *more* is better. Recency is reversed here,
		// once, rather than at the point of scoring — so the inversion is one line with a
		// reason next to it instead of a sign to get right in three places.
		let recencyRank = Self.tierRanks(customers.map { -$0.recencyDays }, tiers: tiers)
		let frequencyRank = Self.tierRanks(customers.map { $0.frequency }, tiers: tiers)
		let monetaryRank = Self.tierRanks(customers.map { $0.monetary }, tiers: tiers)

		var assembled: [String: RFMScore] = [:]
		for (index, customer) in customers.enumerated() {
			assembled[customer.identifier] = RFMScore(recency: recencyRank[index],
													  frequency: frequencyRank[index],
													  monetary: monetaryRank[index])
		}
		self.scores = assembled
		self.tiers = tiers
	}

	/// Tier per element, from one for the lowest values to `tiers` for the highest.
	///
	/// Ties take the tier their position falls in rather than being grouped, which keeps
	/// the tiers equally populated. The alternative — giving equal values equal tiers —
	/// makes tier sizes depend on how many duplicates the data happens to hold.
	static func tierRanks(_ values: [T], tiers: Int) -> [Int] {
		let count = values.count
		let order = (0..<count).sorted { values[$0] < values[$1] }
		var result = [Int](repeating: 1, count: count)
		for (position, index) in order.enumerated() {
			let scaled = position * tiers
			let tier = scaled / count
			result[index] = Swift.min(tier + 1, tiers)
		}
		return result
	}
}

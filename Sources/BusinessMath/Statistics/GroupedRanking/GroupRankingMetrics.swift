//
//  GroupRankingMetrics.swift
//  BusinessMath
//

import Foundation
import Numerics

/// How well a set of scores ranked one group's chosen candidates among its unchosen ones.
public struct GroupRanking<T: Real & Sendable & BinaryFloatingPoint>: Sendable, Equatable {

	/// The average, over the group's chosen candidates, of the share of unchosen candidates scored below them, with a tie
	/// counting half. `0.5` is chance; `1` ranks every chosen candidate above every unchosen one.
	public let percentile: T

	/// The share of the group's chosen candidates inside its top *m*, where *m* is how many it chose. A tie shares its places.
	public let topOwn: T

	/// The share of the group's chosen candidates inside its top `k`. A tie shares its places.
	public let topK: T

	/// Creates a ranking result.
	public init(percentile: T, topOwn: T, topK: T) {
		self.percentile = percentile
		self.topOwn = topOwn
		self.topK = topK
	}
}

/// Ranking figures averaged over groups, each group counting once.
public struct GroupRankingSummary<T: Real & Sendable & BinaryFloatingPoint>: Sendable, Equatable {

	/// How many groups were compared.
	public let groups: Int

	/// The mean of ``GroupRanking/percentile``, or `nil` when no group was compared.
	public let meanPercentile: T?

	/// The mean of ``GroupRanking/topOwn``, or `nil` when no group was compared.
	public let topOwnShare: T?

	/// The mean of ``GroupRanking/topK``, or `nil` when no group was compared.
	public let topKShare: T?

	/// Creates a summary.
	public init(groups: Int, meanPercentile: T?, topOwnShare: T?, topKShare: T?) {
		self.groups = groups
		self.meanPercentile = meanPercentile
		self.topOwnShare = topOwnShare
		self.topKShare = topKShare
	}
}

/// Ranking metrics computed **within** each group.
///
/// A pooled area under the ROC curve is dominated by large groups and mixes scores from different choosers. These
/// figures are computed per group and then averaged with each group counting once, so a group with a hundred
/// candidates does not outweigh one with five. An unchosen candidate is unknown, not rejected, so these measure how well
/// the scores rank, not how likely a choice is.
///
/// ```swift
/// // One group of four: scores 3, 2, 1, 0; the first and third candidates were chosen.
/// let data = GroupedChoiceData<Double>(groups: [[
///     (features: [3], chosen: true), (features: [2], chosen: false),
///     (features: [1], chosen: true), (features: [0], chosen: false),
/// ]])!
/// let rankings = GroupRankingMetrics.perGroup(scores: [3, 2, 1, 0], data: data, k: 1)!
/// // rankings[0]?.percentile == 0.75, topOwn == 0.5, topK == 0.5
/// ```
public enum GroupRankingMetrics {

	/// One result per group, or `nil` for a group with no chosen candidate, no unchosen candidate, or a score that is not finite.
	///
	/// - Parameters:
	///   - scores: One score per row of the data, higher meaning more likely chosen; see ``GroupedChoiceData/rows(ofGroup:)``.
	///   - data: The grouped candidates.
	///   - k: The cut-off for ``GroupRanking/topK``; at least `1`.
	/// - Returns: `nil` when `scores` is not one per row or `k` is below `1`.
	@_specialize(exported: true, where T == Double)
	public static func perGroup<T: Real & Sendable & BinaryFloatingPoint>(
		scores: [T], data: GroupedChoiceData<T>, k: Int
	) -> [GroupRanking<T>?]? {
		guard scores.count == data.rowCount, k >= 1 else { return nil }
		return (0..<data.groupCount).map { ranking(group: $0, scores: scores, data: data, k: k) }
	}

	/// The mean of the per-group results that exist, each group counting once.
	public static func summary<T: Real & Sendable & BinaryFloatingPoint>(_ rankings: [GroupRanking<T>?]) -> GroupRankingSummary<T> {
		let present = rankings.compactMap { $0 }
		guard !present.isEmpty else { return GroupRankingSummary(groups: 0, meanPercentile: nil, topOwnShare: nil, topKShare: nil) }
		let count: T = T(present.count)
		let percentile: T = present.reduce(T.zero) { $0 + $1.percentile } / count
		let own: T = present.reduce(T.zero) { $0 + $1.topOwn } / count
		let cut: T = present.reduce(T.zero) { $0 + $1.topK } / count
		return GroupRankingSummary(groups: present.count, meanPercentile: percentile, topOwnShare: own, topKShare: cut)
	}

	/// The pooled evaluation (ROC area and the rest) over every comparable group's candidates, by ``ClassifierEvaluation``.
	///
	/// Only groups with both a chosen and an unchosen candidate are pooled. The area is not reimplemented here.
	///
	/// - Returns: `nil` when `scores` is not one per row, no group is comparable, or a score is not finite.
	@_specialize(exported: true, where T == Double)
	public static func pooledEvaluation<T: Real & Sendable & BinaryFloatingPoint>(
		scores: [T], data: GroupedChoiceData<T>
	) -> ClassifierEvaluation<T>? {
		guard scores.count == data.rowCount else { return nil }
		var pooledScores: [T] = []
		var outcomes: [Bool] = []
		for group in data.comparableGroups {
			for row in data.rows(ofGroup: group) {
				pooledScores.append(scores[row])
				outcomes.append(data.rowChosen[row])
			}
		}
		return ClassifierEvaluation(scores: pooledScores, outcomes: outcomes)
	}

	static func ranking<T: Real & Sendable & BinaryFloatingPoint>(
		group: Int, scores: [T], data: GroupedChoiceData<T>, k: Int
	) -> GroupRanking<T>? {
		var all: [T] = []
		var friends: [T] = []
		var others: [T] = []
		for row in data.rows(ofGroup: group) {
			let score: T = scores[row]
			guard score.isFinite else { return nil }
			all.append(score)
			if data.rowChosen[row] { friends.append(score) } else { others.append(score) }
		}
		guard !friends.isEmpty, !others.isEmpty else { return nil }
		all.sort()
		others.sort()
		let count: T = T(all.count)
		let unchosen: T = T(others.count)
		let own: T = T(friends.count)
		let cut: T = T(k)
		let half: T = T(1) / T(2)
		var percentile: T = T.zero
		var topOwn: T = T.zero
		var topK: T = T.zero
		for score in friends {
			let low = lowerBound(others, score)
			let high = upperBound(others, score)
			let below: T = T(low)
			let tied: T = T(high - low)
			let credit: T = below + half * tied
			percentile += credit / unchosen
			let sharedHigh = upperBound(all, score)
			let sharedLow = lowerBound(all, score)
			let above: T = count - T(sharedHigh)
			let shared: T = T(sharedHigh - sharedLow)
			guard shared > T.zero else { continue }
			topOwn += clamp((own - above) / shared)
			topK += clamp((cut - above) / shared)
		}
		return GroupRanking(percentile: percentile / own, topOwn: topOwn / own, topK: topK / own)
	}

	private static func clamp<T: Real & BinaryFloatingPoint>(_ value: T) -> T {
		Swift.min(Swift.max(value, T.zero), T(1))
	}

	/// The first index whose element is not below `value`.
	private static func lowerBound<T: Comparable>(_ sorted: [T], _ value: T) -> Int {
		var low = 0
		var high = sorted.count
		while low < high {
			let middle = (low + high) / 2
			if sorted[middle] < value { low = middle + 1 } else { high = middle }
		}
		return low
	}

	/// The first index whose element is above `value`.
	private static func upperBound<T: Comparable>(_ sorted: [T], _ value: T) -> Int {
		var low = 0
		var high = sorted.count
		while low < high {
			let middle = (low + high) / 2
			if sorted[middle] <= value { low = middle + 1 } else { high = middle }
		}
		return low
	}
}

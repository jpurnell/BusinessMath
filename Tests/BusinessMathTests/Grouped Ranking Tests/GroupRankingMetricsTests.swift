//
//  GroupRankingMetricsTests.swift
//  BusinessMath
//
//  Per-group ranking metrics. Every expected value is worked by hand in the comment beside it.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Grouped choice: ranking metrics")
struct GroupRankingMetricsTests {

	private func data(_ groups: [[Bool]]) throws -> GroupedChoiceData<Double> {
		let rows = groups.map { group in group.map { (features: [1.0], chosen: $0) } }
		return try #require(GroupedChoiceData<Double>(groups: rows))
	}

	@Test("Hand-worked group: scores 3, 2, 1, 0 with the first and third chosen")
	func handWorked() throws {
		// Chosen scores 3 and 1; unchosen 2 and 0.
		// Percentile: for 3, both unchosen are below (1); for 1, one is below (0.5); mean 0.75.
		// Top-own (m = 2): 3 is in the top 2 (1); 1 is third (0); mean 0.5.
		// Top-1: 3 is first (1); 1 is not (0); mean 0.5.
		let data = try data([[true, false, true, false]])
		let all = try #require(GroupRankingMetrics.perGroup(scores: [3, 2, 1, 0], data: data, k: 1))
		let result = try #require(all[0])
		#expect(abs(result.percentile - 0.75) < 1e-12)
		#expect(abs(result.topOwn - 0.5) < 1e-12)
		#expect(abs(result.topK - 0.5) < 1e-12)
	}

	@Test("A tie with an unchosen candidate earns half credit and shares its places")
	func tieHandWorked() throws {
		// Scores 2, 2, 1; the first chosen. Unchosen scores 2 and 1: one below (1), one tied (0.5): (1 + 0.5) / 2 = 0.75.
		// Top-own (m = 1): nothing is above; two candidates share score 2, so the chosen one has half a place: 1/2 = 0.5.
		let data = try data([[true, false, false]])
		let all = try #require(GroupRankingMetrics.perGroup(scores: [2, 2, 1], data: data, k: 5))
		let result = try #require(all[0])
		#expect(abs(result.percentile - 0.75) < 1e-12)
		#expect(abs(result.topOwn - 0.5) < 1e-12)
		#expect(result.topK == 1)
	}

	@Test("Equal scores everywhere give chance: percentile one half, top-own share m over n")
	func allTied() throws {
		let data = try data([[true, true, false, false, false]])
		let all = try #require(GroupRankingMetrics.perGroup(scores: [1, 1, 1, 1, 1], data: data, k: 2))
		let result = try #require(all[0])
		#expect(abs(result.percentile - 0.5) < 1e-12)
		#expect(abs(result.topOwn - 2.0 / 5.0) < 1e-15)
		#expect(abs(result.topK - 2.0 / 5.0) < 1e-15)
	}

	@Test("Groups with nothing to compare, or a score that is not a number, have no result")
	func noResult() throws {
		let data = try data([[false, false], [true, true], [], [true, false], [true, false]])
		let scores: [Double] = [1, 2, 3, 4, 5, 6, Double.nan, 0]
		// Rows: group 0 -> 0,1; group 1 -> 2,3; group 2 empty; group 3 -> 4,5; group 4 -> 6,7.
		let results = try #require(GroupRankingMetrics.perGroup(scores: scores, data: data, k: 1))
		#expect(results.count == 5)
		#expect(results[0] == nil)
		#expect(results[1] == nil)
		#expect(results[2] == nil)
		_ = try #require(results[3])
		#expect(results[4] == nil)
	}

	@Test("Wrong-length scores or a cut-off below one are refused")
	func refusals() throws {
		let data = try data([[true, false]])
		#expect(GroupRankingMetrics.perGroup(scores: [1], data: data, k: 1) == nil)
		#expect(GroupRankingMetrics.perGroup(scores: [1, 0], data: data, k: 0) == nil)
		#expect(GroupRankingMetrics.pooledEvaluation(scores: [1], data: data) == nil)
	}

	@Test("The summary averages groups, each counting once, and counts them")
	func summary() throws {
		let rankings: [GroupRanking<Double>?] = [
			GroupRanking(percentile: 1, topOwn: 1, topK: 1), nil, GroupRanking(percentile: 0.5, topOwn: 0, topK: 0.5),
		]
		let result = GroupRankingMetrics.summary(rankings)
		#expect(result.groups == 2)
		let mean = try #require(result.meanPercentile)
		let own = try #require(result.topOwnShare)
		let cut = try #require(result.topKShare)
		#expect(abs(mean - 0.75) < 1e-12)
		#expect(abs(own - 0.5) < 1e-12)
		#expect(abs(cut - 0.75) < 1e-12)
		let empty = GroupRankingMetrics.summary([GroupRanking<Double>?](arrayLiteral: nil, nil))
		#expect(empty.groups == 0)
		#expect(empty.meanPercentile == nil)
	}

	@Test("A large group does not outweigh a small one in the per-group mean, but does in the pooled area")
	func groupWiseNotPooled() throws {
		// A group of 100 ranked perfectly (percentile 1) and a group of 2 ranked wrongly (percentile 0).
		var big = [Bool](repeating: false, count: 100)
		big[0] = true
		big[1] = true
		let small = [true, false]
		let data = try data([big, small])
		var scores = (0..<100).map { Double(200 - $0) }
		scores += [0, 1]
		let rankings = try #require(GroupRankingMetrics.perGroup(scores: scores, data: data, k: 1))
		let summary = GroupRankingMetrics.summary(rankings)
		#expect(summary.groups == 2)
		let groupMean = try #require(summary.meanPercentile)
		#expect(abs(groupMean - 0.5) < 1e-12)
		let pooled = try #require(GroupRankingMetrics.pooledEvaluation(scores: scores, data: data))
		// Pooled over 3 chosen and 99 unchosen rows, the large group's rows decide the area: it is far above one half.
		#expect(pooled.auc > 0.6)
	}

	@Test("The pooled evaluation covers only comparable groups, and is the ClassifierEvaluation of those rows")
	func pooled() throws {
		let data = try data([[true, false, false], [true, true], [false, false], [false, true]])
		let scores: [Double] = [3, 1, 2, 9, 9, 5, 5, 0, 4]
		// Comparable groups: 0 (rows 0-2) and 3 (rows 7-8).
		let expected = try #require(ClassifierEvaluation<Double>(
			scores: [3, 1, 2, 0, 4], outcomes: [true, false, false, false, true]))
		let pooled = try #require(GroupRankingMetrics.pooledEvaluation(scores: scores, data: data))
		#expect(pooled.positiveCount == expected.positiveCount)
		#expect(pooled.negativeCount == expected.negativeCount)
		#expect(pooled.auc == expected.auc)
		let none = try self.data([[true, true], [false]])
		#expect(GroupRankingMetrics.pooledEvaluation(scores: [1, 2, 3], data: none) == nil)
	}
}

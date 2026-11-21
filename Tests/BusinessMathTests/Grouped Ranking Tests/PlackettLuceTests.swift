//
//  PlackettLuceTests.swift
//  BusinessMath
//
//  The ranking (Plackett-Luce) likelihood, and how it differs from the subset likelihood.
//
//  The oracle is brute force again: the test sums the product of the Plackett-Luce step probabilities itself, over the
//  ranked prefix, and the probability of a top-m list is also summed over every permutation of the remaining items to
//  show the likelihood is a proper distribution.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Grouped choice: Plackett-Luce")
struct PlackettLuceTests {

	/// The log-probability of `ranking` (best first) among items with `scores`, by the definition: each step is the chosen
	/// item's weight over the weights of the items not yet taken.
	private func definitionLogProbability(scores: [Double], ranking: [Int]) -> Double {
		var remaining = Set(0..<scores.count)
		var total = 0.0
		for (step, item) in ranking.enumerated() {
			if step == scores.count - 1 { break }   // the last item of a full ranking has nothing left to be chosen against
			let denominator = remaining.reduce(0.0) { $0 + exp(scores[$1]) }
			total += scores[item] - log(denominator)
			remaining.remove(item)
		}
		return total
	}

	private func permutations(_ items: [Int]) -> [[Int]] {
		guard items.count > 1 else { return [items] }
		var result: [[Int]] = []
		for (index, item) in items.enumerated() {
			var rest = items
			rest.remove(at: index)
			for tail in permutations(rest) { result.append([item] + tail) }
		}
		return result
	}

	private func rankedModel(
		candidates: [[Double]], ranking: [Int], reference: [Double], offsets: [[Double]]? = nil
	) throws -> GroupedChoiceModel<Double> {
		let data = try #require(GroupedChoiceData<Double>(rankedGroups: [(candidates: candidates, ranking: ranking)], offsets: offsets))
		return try #require(GroupedChoiceModel(data: data, reference: reference, likelihood: .ranking))
	}

	@Test("Matches the definition for rankings of every length, partial and full")
	func definition() throws {
		let candidates: [[Double]] = [[1, 0.5], [0, 2], [3, 0], [0.5, 1], [2, 2]]
		let reference = [0.4, 0.8]
		let multipliers = [1.3, 0.7]
		let scale = 0.9
		let scores = candidates.map { scale * (multipliers[0] * reference[0] * $0[0] + multipliers[1] * reference[1] * $0[1]) }
		for ranking in [[2], [2, 0], [4, 1, 3], [4, 1, 3, 0], [4, 1, 3, 0, 2]] {
			let model = try rankedModel(candidates: candidates, ranking: ranking, reference: reference)
			let got = try #require(model.negativeLogLikelihood(multipliers: multipliers, scale: scale, groupWeights: [1]))
			let want = -definitionLogProbability(scores: scores, ranking: ranking)
			#expect(abs(got.total - want) < 1e-12)
			#expect(abs(got.chosen - Double(Swift.min(ranking.count, candidates.count - 1))) < 1e-12)
		}
	}

	@Test("The probabilities of all top-m lists sum to one")
	func properDistribution() {
		let scores = [0.3, -0.2, 0.9, 0.1]
		for length in 1...3 {
			var total = 0.0
			for ranking in permutations([0, 1, 2, 3]).map({ Array($0.prefix(length)) }).reduce(into: Set<[Int]>(), { $0.insert($1) }) {
				total += exp(definitionLogProbability(scores: scores, ranking: ranking))
			}
			#expect(abs(total - 1) < 1e-12)
		}
	}

	@Test("With one chosen candidate per group the ranking and subset likelihoods are the same function")
	func firstChoice() throws {
		let candidates: [[Double]] = [[1, 0], [0, 1], [2, 1]]
		let ranked = try rankedModel(candidates: candidates, ranking: [2], reference: [0.5, 1.5])
		let subsetData = try #require(GroupedChoiceData<Double>(groups: [
			zip(candidates, [false, false, true]).map { (features: $0, chosen: $1) },
		]))
		let subset = try #require(GroupedChoiceModel(data: subsetData, reference: [0.5, 1.5], likelihood: .subset))
		let a = try #require(ranked.negativeLogLikelihood(multipliers: [1.1, 0.9], scale: 0.8, groupWeights: [1]))
		let b = try #require(subset.negativeLogLikelihood(multipliers: [1.1, 0.9], scale: 0.8, groupWeights: [1]))
		#expect(abs(a.total - b.total) < 1e-12)
	}

	@Test("With two chosen the ranking and subset likelihoods are different numbers")
	func twoLikelihoodsDiffer() throws {
		// Scores 1, 0, 0 (feature on the first candidate, scale 1). Chosen: candidates 0 and 1.
		// Subset: P = e^(1+0) / (e^(1+0) + e^(1+0) + e^(0+0)) = e / (2e + 1).
		// Ranking 0 then 1: P = e/(e+1+1) * 1/(1+1) = e / (2(e + 2)).
		let candidates: [[Double]] = [[1], [0], [0]]
		let ranked = try rankedModel(candidates: candidates, ranking: [0, 1], reference: [1])
		let subsetData = try #require(GroupedChoiceData<Double>(groups: [
			zip(candidates, [true, true, false]).map { (features: $0, chosen: $1) },
		]))
		let subset = try #require(GroupedChoiceModel(data: subsetData, reference: [1], likelihood: .subset))
		let e = exp(1.0)
		let rankingHand = -log(e / (2 * (e + 2)))
		let subsetHand = -log(e / (2 * e + 1))
		let a = try #require(ranked.negativeLogLikelihood(multipliers: [1], scale: 1, groupWeights: [1]))
		let b = try #require(subset.negativeLogLikelihood(multipliers: [1], scale: 1, groupWeights: [1]))
		#expect(abs(a.total - rankingHand) < 1e-12)
		#expect(abs(b.total - subsetHand) < 1e-12)
		#expect(abs(a.total - b.total) > 0.1)
		// Reversing the order changes the ranking likelihood of an ASYMMETRIC pair, and cannot change the subset's.
		let reversed = try rankedModel(candidates: candidates, ranking: [1, 0], reference: [1])
		let c = try #require(reversed.negativeLogLikelihood(multipliers: [1], scale: 1, groupWeights: [1]))
		#expect(abs(c.total - a.total) > 0.1)
	}

	@Test("A model refuses the other kind of data")
	func refusesMismatch() throws {
		let ranked = try #require(GroupedChoiceData<Double>(rankedGroups: [(candidates: [[1], [0]], ranking: [0])]))
		let unordered = try #require(GroupedChoiceData<Double>(groups: [[(features: [1], chosen: true), (features: [0], chosen: false)]]))
		#expect(ranked.isRanked && !unordered.isRanked)
		#expect(GroupedChoiceModel(data: ranked, reference: [1], likelihood: .subset) == nil)
		#expect(GroupedChoiceModel(data: unordered, reference: [1], likelihood: .ranking) == nil)
		_ = try #require(GroupedChoiceModel(data: ranked, reference: [1], likelihood: .ranking))
	}

	@Test("Ranked data that cannot be built is refused")
	func rankedRefusals() {
		typealias Entry = (candidates: [[Double]], ranking: [Int])
		#expect(GroupedChoiceData<Double>(rankedGroups: []) == nil)
		let outOfRange: [Entry] = [(candidates: [[1], [0]], ranking: [2])]
		#expect(GroupedChoiceData<Double>(rankedGroups: outOfRange) == nil)
		let negative: [Entry] = [(candidates: [[1], [0]], ranking: [-1])]
		#expect(GroupedChoiceData<Double>(rankedGroups: negative) == nil)
		let repeated: [Entry] = [(candidates: [[1], [0]], ranking: [0, 0])]
		#expect(GroupedChoiceData<Double>(rankedGroups: repeated) == nil)
		let ragged: [Entry] = [(candidates: [[1, 2], [0]], ranking: [0])]
		#expect(GroupedChoiceData<Double>(rankedGroups: ragged) == nil)
		let nan: [Entry] = [(candidates: [[Double.nan], [0]], ranking: [0])]
		#expect(GroupedChoiceData<Double>(rankedGroups: nan) == nil)
		let offsets: [Entry] = [(candidates: [[1], [0]], ranking: [0])]
		#expect(GroupedChoiceData<Double>(rankedGroups: offsets, offsets: [[0]]) == nil)
	}

	@Test("Which groups are informative: ranked data needs two candidates and one ranked; a full ranking still counts")
	func informativeRanked() throws {
		let data = try #require(GroupedChoiceData<Double>(rankedGroups: [
			(candidates: [[1]], ranking: [0]),               // one candidate: nothing to choose among
			(candidates: [[1], [0]], ranking: []),            // nothing ranked
			(candidates: [[1], [0]], ranking: [0]),           // one of two
			(candidates: [[1], [0], [2]], ranking: [2, 0, 1]), // a full ranking: two informative steps
		]))
		#expect(data.informativeGroups == [2, 3])
		#expect(data.stepCount(group: 3) == 2)
		#expect(data.stepCount(group: 2) == 1)
		#expect(data.comparableGroups == [2])
	}

	@Test("Pooled evaluation of ranked data leaves out a group that ranked every candidate (it has no unchosen one)")
	func pooledRanked() throws {
		let data = try #require(GroupedChoiceData<Double>(rankedGroups: [
			(candidates: [[1], [0], [2]], ranking: [2]),         // comparable: one ranked of three
			(candidates: [[1], [0], [2]], ranking: [2, 0, 1]),   // everyone ranked: nothing unchosen to compare against
		]))
		let scores: [Double] = [1, 0, 2, 9, 9, 9]
		let pooled = try #require(GroupRankingMetrics.pooledEvaluation(scores: scores, data: data))
		#expect(pooled.positiveCount == 1)
		#expect(pooled.negativeCount == 2)
		#expect(abs(pooled.auc - 1) < 1e-12)
	}

	@Test("The analytic gradient matches a central finite difference, offsets and group weights included")
	func gradient() throws {
		let data = try #require(GroupedChoiceData<Double>(rankedGroups: [
			(candidates: [[1, 0.5, 0], [0, 2, 1], [3, 0, 0.5], [0.5, 1, 0]], ranking: [2, 0]),
			(candidates: [[0, 1, 1], [2, 0, 0], [1, 1, 1]], ranking: [1, 2, 0]),
			(candidates: [[1, 1, 0], [0, 0, 1], [1, 0, 1], [0, 1, 0], [2, 0, 0]], ranking: [4, 3, 0]),
		], offsets: [[0, 0.1, -0.2, 0], [0, 0, 0.3], [0, 0.1, 0, 0, -0.1]]))
		let model = try #require(GroupedChoiceModel(data: data, reference: [2, 0.5, 1.5], likelihood: .ranking))
		let multipliers = [1.2, 0.8, 1.1]
		let scale = 0.7
		let weights = [1.0, 2.0, 0.5]
		let analytic = try #require(model.evaluate(multipliers: multipliers, scale: scale, groupWeights: weights, gradient: true)).gradient
		let step = 1e-6
		for k in 0..<3 {
			var up = multipliers, down = multipliers
			up[k] += step
			down[k] -= step
			let high = try #require(model.negativeLogLikelihood(multipliers: up, scale: scale, groupWeights: weights)).total
			let low = try #require(model.negativeLogLikelihood(multipliers: down, scale: scale, groupWeights: weights)).total
			#expect(abs(analytic[k] - (high - low) / (2 * step)) < 1e-7)
		}
	}

	@Test("Scores far apart stay finite, with early choices dominating the later denominators")
	func stability() throws {
		let model = try rankedModel(candidates: [[1], [0.5], [0]], ranking: [0, 1], reference: [1])
		let result = try #require(model.negativeLogLikelihood(multipliers: [1], scale: 800, groupWeights: [1]))
		#expect(result.total.isFinite)
		#expect(abs(result.total) < 1e-12)
	}

	@Test("Recovers known weights from rankings drawn by sequential choice")
	func recovery() throws {
		var generator = SplitMix64(seed: 77)
		let beta = [0.9, 0.4]
		var groups: [(candidates: [[Double]], ranking: [Int])] = []
		for index in 0..<1200 {
			let candidates: [[Double]] = (0..<7).map { _ in
				[Double.random(in: 0..<1, using: &generator) < 0.4 ? 1 : 0, Double.random(in: 0..<2, using: &generator)]
			}
			var remaining = Array(0..<7)
			var ranking: [Int] = []
			let depth = 1 + index % 4
			for _ in 0..<depth {
				let weights = remaining.map { exp(beta[0] * candidates[$0][0] + beta[1] * candidates[$0][1]) }
				let target = Double.random(in: 0..<1, using: &generator) * weights.reduce(0, +)
				var running = 0.0
				var picked = remaining.count - 1
				for (position, weight) in weights.enumerated() {
					running += weight
					if running >= target { picked = position; break }
				}
				ranking.append(remaining[picked])
				remaining.remove(at: picked)
			}
			groups.append((candidates: candidates, ranking: ranking))
		}
		let data = try #require(GroupedChoiceData<Double>(rankedGroups: groups))
		let model = try #require(GroupedChoiceModel(data: data, reference: [1, 1], likelihood: .ranking))
		let fit = try model.fit(groupWeights: [Double](repeating: 1, count: 1200), penalty: 1e-6)
		for k in 0..<2 { #expect(abs(fit.scale * fit.multipliers[k] - beta[k]) < RecoveryTolerance.weight) }
	}
}

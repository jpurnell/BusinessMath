//
//  GroupedRankingDocumentationTests.swift
//  BusinessMath
//
//  The examples in `2.8-GroupedRanking.md`, run. Each test is the article's code with its stated results asserted, so
//  an example that stops compiling or stops giving the figure the article quotes fails here.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Grouped ranking: documentation examples")
struct GroupedRankingDocumentationTests {

	/// The article's synthetic class: 60 choosers, 6 candidates each, feature 0 really matters and feature 1 does not.
	private func articleGroups() -> [[(features: [Double], chosen: Bool)]] {
		var generator = SplitMix64(seed: 11)
		return (0..<60).map { _ in
			let candidates: [[Double]] = (0..<6).map { _ in
				[Double.random(in: 0..<1, using: &generator) < 0.4 ? 1 : 0,
				 Double.random(in: 0..<1, using: &generator) < 0.4 ? 1 : 0]
			}
			let weights: [Double] = candidates.map { exp(1.5 * $0[0]) }
			var pick = Double.random(in: 0..<1, using: &generator) * weights.reduce(0, +)
			var chosenIndex = weights.count - 1
			for (index, weight) in weights.enumerated() {
				if pick < weight { chosenIndex = index; break }
				pick -= weight
			}
			return candidates.enumerated().map { (features: $0.element, chosen: $0.offset == chosenIndex) }
		}
	}

	@Test("Fitting: the data type, the model and a penalised fit")
	func fitting() throws {
		let data = try #require(GroupedChoiceData<Double>(groups: articleGroups()))
		let model = try #require(GroupedChoiceModel(data: data, reference: [1, 1], likelihood: .subset))
		let weights = [Double](repeating: 1, count: data.groupCount)
		let fit = try model.fit(groupWeights: weights, penalty: 0.05)
		// The article: multipliers about [1.69, 0.27], scale about 0.785.
		#expect(abs(fit.multipliers[0] - 1.69) < 0.02)
		#expect(abs(fit.multipliers[1] - 0.27) < 0.02)
		#expect(abs(fit.scale - 0.785) < 0.01)
		#expect(data.groupCount == 60)
		#expect(fit.converged)
	}

	@Test("Ranking metrics and the held-out comparison")
	func ranking() throws {
		let data = try #require(GroupedChoiceData<Double>(groups: articleGroups()))
		let model = try #require(GroupedChoiceModel(data: data, reference: [1, 1], likelihood: .subset))
		let weights = [Double](repeating: 1, count: data.groupCount)
		let fit = try model.fit(groupWeights: weights, penalty: 0.05)
		let scores = try #require(model.scores(for: fit))
		let perGroup = try #require(GroupRankingMetrics.perGroup(scores: scores, data: data, k: 3))
		let summary = GroupRankingMetrics.summary(perGroup)
		// The article: mean percentile about 0.65, top-own share about 0.33.
		let percentile = try #require(summary.meanPercentile)
		let topOwn = try #require(summary.topOwnShare)
		#expect(abs(percentile - 0.65) < 0.01)
		#expect(abs(topOwn - 0.33) < 0.01)
		let comparison = try #require(GroupedCrossValidation.heldOutComparison(
			model: model, penalties: [.reference, .penalty(0.05), .penalty(0.5)], minimumChosen: 10,
			folds: 5, innerFolds: 3, resamples: 200, level: 0.9, seed: 1))
		// The article: held out, 0.63 against 0.65, a difference of about 0.023 with a 90% interval of about 0.003 to 0.045.
		#expect(abs(comparison.referencePercentile - 0.63) < 0.01)
		#expect(abs(comparison.refitPercentile - 0.65) < 0.01)
		#expect(abs(comparison.difference - 0.023) < 0.005)
		#expect(abs(comparison.lower - 0.003) < 0.005)
		#expect(abs(comparison.upper - 0.045) < 0.005)
		#expect(comparison.refitBeatsReference)
		#expect(summary.groups == 60)
	}

	@Test("Plackett-Luce: ranked groups, and each model refuses the other's data")
	func plackettLuce() throws {
		let ranked = try #require(GroupedChoiceData<Double>(rankedGroups: [
			(candidates: [[1, 0], [0, 1], [0, 0]], ranking: [0, 1]),
			(candidates: [[1, 1], [0, 0], [1, 0]], ranking: [0, 2]),
			(candidates: [[0, 1], [1, 0], [0, 0]], ranking: [1]),
		]))
		let rankingModel = try #require(GroupedChoiceModel(data: ranked, reference: [1, 1], likelihood: .ranking))
		#expect(rankingModel.likelihood == .ranking)
		#expect(rankingModel.reference == [1, 1])
		#expect(GroupedChoiceModel(data: ranked, reference: [1, 1], likelihood: .subset) == nil)
	}

	@Test("Penalised logistic regression on separated data")
	func penalisedLogistic() throws {
		let regression = LogisticRegression<Double>(predictors: [[0], [1], [2], [3]], outcomes: [false, false, true, true])
		var refused = false
		do { _ = try regression.fit() } catch LogisticRegressionError.separation { refused = true }
		#expect(refused)
		let fit = try regression.fit(penalty: LogisticPenalty(lambda: 0.1))
		// The article: coefficients about [-3.98, 2.65] (intercept, then slope), and a probability of about 0.5 at 1.5.
		#expect(abs(fit.coefficients[0] + 3.98) < 0.02)
		#expect(abs(fit.coefficients[1] - 2.65) < 0.02)
		#expect(abs(fit.probability([1.5]) - 0.5) < 0.01)
		#expect(fit.coefficients.count == 2)
	}
}

//
//  GroupedChoiceLikelihoodTests.swift
//  BusinessMath
//
//  The subset (conditional-logit) likelihood of grouped choices.
//
//  The oracle is brute force. The implementation computes the sum over every set of the chosen size with a dynamic
//  programme; the test enumerates the sets themselves and sums their products. Different computations over different
//  intermediate structures, so agreement is evidence, and it is exact to rounding.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Grouped choice: data and subset likelihood")
struct GroupedChoiceLikelihoodTests {

	// MARK: - Helpers

	/// log of the sum, over every size-`size` subset of `scores`, of exp(sum of the subset's scores). By enumeration.
	private func bruteForceLogNormaliser(scores: [Double], size: Int) -> Double {
		var total = 0.0
		let count = scores.count
		for mask in 0..<(1 << count) where mask.nonzeroBitCount == size {
			var sum = 0.0
			for bit in 0..<count where mask & (1 << bit) != 0 { sum += scores[bit] }
			total += exp(sum)
		}
		return log(total)
	}

	/// The negative log-likelihood of one group by definition: -(sum of chosen scores - log normaliser).
	private func bruteForceNLL(scores: [Double], chosen: [Bool]) -> Double {
		let size = chosen.filter { $0 }.count
		var chosenSum = 0.0
		for (index, score) in scores.enumerated() where chosen[index] { chosenSum += score }
		return -(chosenSum - bruteForceLogNormaliser(scores: scores, size: size))
	}

	private func model(
		_ groups: [[(features: [Double], chosen: Bool)]], reference: [Double], offsets: [[Double]]? = nil
	) throws -> GroupedChoiceModel<Double> {
		let data = try #require(GroupedChoiceData<Double>(groups: groups, offsets: offsets))
		return try #require(GroupedChoiceModel(data: data, reference: reference, likelihood: .subset))
	}

	// MARK: - Data

	@Test("Dense and sparse construction describe the same data")
	func denseEqualsSparse() throws {
		let dense = try #require(GroupedChoiceData<Double>(groups: [
			[(features: [1, 0, 2], chosen: true), (features: [0, 0, 0], chosen: false)],
			[(features: [0, 3, 0], chosen: false), (features: [4, 0, 0], chosen: true)],
		]))
		let sparse = try #require(GroupedChoiceData<Double>(
			sparseGroups: [
				[(features: [(feature: 0, value: 1), (feature: 2, value: 2)], chosen: true), (features: [], chosen: false)],
				[(features: [(feature: 1, value: 3)], chosen: false), (features: [(feature: 0, value: 4)], chosen: true)],
			], featureCount: 3))
		#expect(dense.groupCount == 2)
		#expect(dense.featureCount == 3)
		#expect(dense.rowCount == 4)
		#expect(dense.entryFeature == sparse.entryFeature)
		#expect(dense.entryValue == sparse.entryValue)
		#expect(dense.rowChosen == sparse.rowChosen)
		#expect(dense.groupStart == sparse.groupStart)
	}

	@Test("Data the model cannot use is refused at construction")
	func refusals() {
		typealias Row = (features: [Double], chosen: Bool)
		#expect(GroupedChoiceData<Double>(groups: []) == nil)
		#expect(GroupedChoiceData<Double>(groups: [[]]) == nil)
		#expect(GroupedChoiceData<Double>(groups: [[(features: [], chosen: true)]]) == nil)
		let ragged: [[Row]] = [[(features: [1, 2], chosen: true), (features: [1], chosen: false)]]
		#expect(GroupedChoiceData<Double>(groups: ragged) == nil)
		let nan: [[Row]] = [[(features: [Double.nan], chosen: true)]]
		#expect(GroupedChoiceData<Double>(groups: nan) == nil)
		let infinite: [[Row]] = [[(features: [Double.infinity], chosen: true)]]
		#expect(GroupedChoiceData<Double>(groups: infinite) == nil)
		let valid: [[Row]] = [[(features: [1], chosen: true), (features: [0], chosen: false)]]
		#expect(GroupedChoiceData<Double>(groups: valid, offsets: [[0]]) == nil)
		#expect(GroupedChoiceData<Double>(groups: valid, offsets: [[0, Double.nan]]) == nil)
		#expect(GroupedChoiceData<Double>(groups: valid, offsets: [[0, 0], [0]]) == nil)
		typealias Sparse = (features: [(feature: Int, value: Double)], chosen: Bool)
		let outOfRange: [[Sparse]] = [[(features: [(feature: 2, value: 1)], chosen: true)]]
		#expect(GroupedChoiceData<Double>(sparseGroups: outOfRange, featureCount: 2) == nil)
		let negativeIndex: [[Sparse]] = [[(features: [(feature: -1, value: 1)], chosen: true)]]
		#expect(GroupedChoiceData<Double>(sparseGroups: negativeIndex, featureCount: 2) == nil)
		let repeated: [[Sparse]] = [[(features: [(feature: 0, value: 1), (feature: 0, value: 2)], chosen: true)]]
		#expect(GroupedChoiceData<Double>(sparseGroups: repeated, featureCount: 1) == nil)
		#expect(GroupedChoiceData<Double>(sparseGroups: outOfRange, featureCount: 0) == nil)
	}

	@Test("Informative groups are those with a chosen and an unchosen candidate")
	func informative() throws {
		let data = try #require(GroupedChoiceData<Double>(groups: [
			[(features: [1], chosen: false), (features: [0], chosen: false)],
			[(features: [1], chosen: true), (features: [0], chosen: false)],
			[(features: [1], chosen: true), (features: [0], chosen: true)],
			[],
			[(features: [1], chosen: true), (features: [0], chosen: false), (features: [1], chosen: true)],
		]))
		#expect(data.informativeGroups == [1, 4])
		#expect(data.chosenCount(group: 4) == 2)
		#expect(data.rows(ofGroup: 3).isEmpty)
		#expect(data.rows(ofGroup: 4) == 6..<9)
		#expect(data.isChosen(row: data.rows(ofGroup: 1).lowerBound))
		#expect(data.rows(ofGroup: 99).isEmpty)
		#expect(!data.isChosen(row: -1))
		let first = try #require(GroupedChoiceData<Double>(groups: [[(features: [1], chosen: true), (features: [0], chosen: false)]]))
		#expect(first.isChosen(row: 0))
		#expect(!first.isChosen(row: 1))
		#expect(!first.isChosen(row: 2))
	}

	@Test("A model refuses a reference that does not fit the data")
	func modelRefusals() throws {
		let data = try #require(GroupedChoiceData<Double>(groups: [[(features: [1, 2], chosen: true), (features: [0, 0], chosen: false)]]))
		#expect(GroupedChoiceModel(data: data, reference: [1], likelihood: .subset) == nil)
		#expect(GroupedChoiceModel(data: data, reference: [1, -1], likelihood: .subset) == nil)
		#expect(GroupedChoiceModel(data: data, reference: [1, Double.nan], likelihood: .subset) == nil)
		_ = try #require(GroupedChoiceModel(data: data, reference: [1, 2], likelihood: .subset))
	}

	@Test("Wrong-length or negative weights and non-finite inputs return nil, not a number")
	func evaluationRefusals() throws {
		let model = try model([[(features: [1], chosen: true), (features: [0], chosen: false)]], reference: [1])
		#expect(model.negativeLogLikelihood(multipliers: [1, 1], scale: 1, groupWeights: [1]) == nil)
		#expect(model.negativeLogLikelihood(multipliers: [1], scale: 1, groupWeights: [1, 1]) == nil)
		#expect(model.negativeLogLikelihood(multipliers: [1], scale: 1, groupWeights: [-1]) == nil)
		#expect(model.negativeLogLikelihood(multipliers: [1], scale: 1, groupWeights: [Double.nan]) == nil)
		#expect(model.negativeLogLikelihood(multipliers: [Double.nan], scale: 1, groupWeights: [1]) == nil)
		#expect(model.negativeLogLikelihood(multipliers: [1], scale: Double.infinity, groupWeights: [1]) == nil)
	}

	// MARK: - Likelihood

	@Test("One chosen of two: the likelihood is the logistic of the score gap (hand value)")
	func twoCandidates() throws {
		// scores: chosen = scale * m * ref * x = 2 * 1.5 * 1 * 1 = 3; other = 0. P(chosen) = e^3 / (e^3 + 1).
		let model = try model([[(features: [1], chosen: true), (features: [0], chosen: false)]], reference: [1])
		let result = try #require(model.negativeLogLikelihood(multipliers: [1.5], scale: 2, groupWeights: [1]))
		let expected = log(1 + exp(-3.0))
		#expect(abs(result.total - expected) < 1e-12)
		#expect(result.chosen == 1)
	}

	@Test("Matches brute-force enumeration for chosen sets of every size")
	func bruteForceAgreement() throws {
		// Four candidates, two features, chosen set sizes 1, 2, 3.
		let features: [[Double]] = [[1, 0.5], [0, 2], [3, 0], [0.5, 1]]
		let reference = [2.0, 0.5]
		let multipliers = [1.3, 0.7]
		let scale = 0.9
		let scores = features.map { scale * (multipliers[0] * reference[0] * $0[0] + multipliers[1] * reference[1] * $0[1]) }
		for chosen in [[true, false, false, false], [true, false, true, false], [false, true, true, true], [true, true, false, true]] {
			let group = zip(features, chosen).map { (features: $0, chosen: $1) }
			let model = try model([group], reference: reference)
			let got = try #require(model.negativeLogLikelihood(multipliers: multipliers, scale: scale, groupWeights: [1]))
			let want = bruteForceNLL(scores: scores, chosen: chosen)
			#expect(abs(got.total - want) < 1e-12)
			#expect(abs(got.chosen - Double(chosen.filter { $0 }.count)) < 1e-12)
		}
	}

	@Test("Offsets add to a candidate's score and are scaled but not multiplied")
	func offsets() throws {
		let group: [(features: [Double], chosen: Bool)] = [(features: [1], chosen: true), (features: [0], chosen: false), (features: [0], chosen: false)]
		let model = try model([group], reference: [2], offsets: [[0, -1.5, 0.25]])
		let scale = 0.8
		let multiplier = 1.25
		let scores = [scale * (multiplier * 2), scale * -1.5, scale * 0.25]
		let got = try #require(model.negativeLogLikelihood(multipliers: [multiplier], scale: scale, groupWeights: [1]))
		let want = bruteForceNLL(scores: scores, chosen: [true, false, false])
		#expect(abs(got.total - want) < 1e-12)
	}

	@Test("Group weights count a group that many times; zero leaves it out")
	func groupWeights() throws {
		let a: [(features: [Double], chosen: Bool)] = [(features: [1], chosen: true), (features: [0], chosen: false), (features: [2], chosen: false)]
		let b: [(features: [Double], chosen: Bool)] = [(features: [0], chosen: true), (features: [1], chosen: false)]
		let both = try model([a, b], reference: [1])
		let onlyA = try model([a], reference: [1])
		let onlyB = try model([b], reference: [1])
		let one = try #require(onlyA.negativeLogLikelihood(multipliers: [1.1], scale: 1, groupWeights: [1]))
		let two = try #require(onlyB.negativeLogLikelihood(multipliers: [1.1], scale: 1, groupWeights: [1]))
		let mixed = try #require(both.negativeLogLikelihood(multipliers: [1.1], scale: 1, groupWeights: [2, 0]))
		#expect(abs(mixed.total - 2 * one.total) < 1e-12)
		#expect(mixed.chosen == 2)
		let sum = try #require(both.negativeLogLikelihood(multipliers: [1.1], scale: 1, groupWeights: [1, 1]))
		#expect(abs(sum.total - (one.total + two.total)) < 1e-12)
		#expect(sum.chosen == 2)
	}

	@Test("Groups with nothing to compare contribute nothing and are not counted")
	func uninformativeSkipped() throws {
		let none: [(features: [Double], chosen: Bool)] = [(features: [1], chosen: false), (features: [0], chosen: false)]
		let all: [(features: [Double], chosen: Bool)] = [(features: [1], chosen: true), (features: [0], chosen: true)]
		let good: [(features: [Double], chosen: Bool)] = [(features: [1], chosen: true), (features: [0], chosen: false)]
		let model = try model([none, all, good, []], reference: [1])
		let evaluation = try #require(model.evaluate(multipliers: [1], scale: 1, groupWeights: [1, 1, 1, 1], gradient: true))
		#expect(evaluation.groupsUsed == 1)
		#expect(evaluation.chosen == 1)
		let alone = try self.model([good], reference: [1])
		let want = try #require(alone.negativeLogLikelihood(multipliers: [1], scale: 1, groupWeights: [1]))
		#expect(abs(evaluation.negativeLogLikelihood - want.total) < 1e-12)
	}

	@Test("Scores far apart stay finite (the sums are shifted by the largest score)")
	func stability() throws {
		let group: [(features: [Double], chosen: Bool)] = [(features: [1], chosen: true), (features: [0], chosen: false), (features: [0.5], chosen: false)]
		let model = try model([group], reference: [1])
		// Scores 800, 0 and 400: exp(800) overflows a Double; the shifted computation does not.
		let result = try #require(model.negativeLogLikelihood(multipliers: [1], scale: 800, groupWeights: [1]))
		#expect(result.total.isFinite)
		// The chosen candidate is overwhelmingly the most likely, so the NLL is ~ log(1 + e^-400 + e^-800) ~ 0.
		#expect(abs(result.total) < 1e-12)
	}

	// MARK: - Gradient

	@Test("The analytic gradient matches a central finite difference")
	func gradientMatchesFiniteDifference() throws {
		let g1: [(features: [Double], chosen: Bool)] = [
			(features: [1, 0.5, 0], chosen: true), (features: [0, 2, 1], chosen: false), (features: [3, 0, 0.5], chosen: true),
			(features: [0.5, 1, 0], chosen: false),
		]
		let g2: [(features: [Double], chosen: Bool)] = [
			(features: [0, 1, 1], chosen: true), (features: [2, 0, 0], chosen: false), (features: [1, 1, 1], chosen: false),
		]
		let model = try model([g1, g2], reference: [2, 0.5, 1.5], offsets: [[0, 0.1, -0.2, 0], [0, 0, 0.3]])
		let multipliers = [1.2, 0.8, 1.1]
		let scale = 0.7
		let weights = [1.0, 2.0]
		let analytic = try #require(model.evaluate(multipliers: multipliers, scale: scale, groupWeights: weights, gradient: true)).gradient
		let step = 1e-6
		for k in 0..<3 {
			var up = multipliers, down = multipliers
			up[k] += step
			down[k] -= step
			let high = try #require(model.negativeLogLikelihood(multipliers: up, scale: scale, groupWeights: weights)).total
			let low = try #require(model.negativeLogLikelihood(multipliers: down, scale: scale, groupWeights: weights)).total
			let numeric = (high - low) / (2 * step)
			#expect(abs(analytic[k] - numeric) < 1e-7)
		}
	}
}

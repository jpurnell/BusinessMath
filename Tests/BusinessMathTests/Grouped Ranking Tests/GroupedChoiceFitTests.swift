//
//  GroupedChoiceFitTests.swift
//  BusinessMath
//
//  Fitting the grouped choice model: recovery of known weights, the failure of the per-choice softmax, the penalty
//  and its constraints, and refusals.
//
//  Reference truth is the data-generating weights, which the code never sees. Tolerances are measured, not guessed:
//  they are set from the spread of the estimate over seeds (see each test).
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Grouped choice: fitting")
struct GroupedChoiceFitTests {

	private typealias Group = GroupedChoiceSynthetic.Group

	private func model(_ groups: [Group], reference: [Double]) throws -> GroupedChoiceModel<Double> {
		let data = try #require(GroupedChoiceData<Double>(groups: groups))
		return try #require(GroupedChoiceModel(data: data, reference: reference, likelihood: .subset))
	}

	private func ones(_ model: GroupedChoiceModel<Double>) -> [Double] { [Double](repeating: 1, count: model.data.groupCount) }

	// MARK: - Recovery

	@Test("Recovers known weights, from groups that choose different numbers of candidates")
	func recovery() throws {
		let beta = [0.9, 0.4, 0.7]
		let groups = GroupedChoiceSynthetic.make(seed: 11, groups: 1500, candidates: 8, sizes: [1, 2, 3, 4, 5], beta: beta)
		let model = try model(groups, reference: [1, 1, 1])
		let fit = try model.fit(groupWeights: ones(model), penalty: 1e-6)
		#expect(fit.converged)
		for k in 0..<3 {
			let effective = fit.scale * fit.multipliers[k]
			#expect(abs(effective - beta[k]) < RecoveryTolerance.weight)
		}
	}

	@Test("A softmax per chosen candidate is biased on the same data; the conditional likelihood is not")
	func softmaxFails() throws {
		let groups = GroupedChoiceSynthetic.make(seed: 7, groups: 3000, candidates: 8, sizes: [2, 3, 4], beta: [1.0])
		// The conditional fit.
		let model = try model(groups, reference: [1])
		let fit = try model.fit(groupWeights: ones(model), penalty: 1e-6)
		let conditional = fit.scale * fit.multipliers[0]
		// The deliberately wrong comparison: for every chosen candidate, a softmax over the WHOLE candidate set.
		func derivative(_ weight: Double) -> Double {
			var total = 0.0
			for group in groups {
				let denominator = group.reduce(0.0) { $0 + exp(weight * $1.features[0]) }
				let expected = group.reduce(0.0) { $0 + $1.features[0] * exp(weight * $1.features[0]) } / denominator
				for candidate in group where candidate.chosen { total += candidate.features[0] - expected }
			}
			return total
		}
		var low = 0.0, high = 5.0
		for _ in 0..<60 {
			let middle = (low + high) / 2
			if derivative(middle) > 0 { low = middle } else { high = middle }
		}
		let softmax = (low + high) / 2
		#expect(abs(conditional - 1.0) < 0.1)
		#expect(abs(softmax - 1.0) > 0.25)
		// The direction: the softmax UNDERSTATES the weight (measured at about 0.64 for a true weight of 1), it does not overstate it.
		#expect(softmax < 0.75)
	}

	@Test("With no signal the effective weights are close to zero")
	func nullFit() throws {
		let groups = GroupedChoiceSynthetic.make(seed: 3, groups: 800, candidates: 8, sizes: [2, 3], beta: [0, 0, 0])
		let model = try model(groups, reference: [1, 1, 1])
		let fit = try model.fit(groupWeights: ones(model), penalty: 0.5)
		for k in 0..<3 { #expect(abs(fit.scale * fit.multipliers[k]) < 0.15) }
	}

	@Test("A feature that only separates groups cannot be given weight; a pooled regression gives it weight")
	func talkativeGroupBias() throws {
		// Feature 0 predicts the choice. Feature 1 is 1 for every candidate in the groups that choose many and 0 in the
		// groups that choose few: it predicts which GROUPS choose, not which candidates.
		let base = GroupedChoiceSynthetic.make(seed: 21, groups: 1200, candidates: 8, sizes: [1, 5], beta: [0.8])
		let groups: [Group] = base.enumerated().map { index, group in
			let talkative: Double = index % 2 == 1 ? 1 : 0
			return group.map { (features: [$0.features[0], talkative], chosen: $0.chosen) }
		}
		let model = try model(groups, reference: [1, 1])
		let fit = try model.fit(groupWeights: ones(model), penalty: 0.01)
		// The conditional fit leaves the group-level feature exactly where it started: its gradient is zero.
		#expect(abs(fit.multipliers[1] - 1) < 1e-9)
		// A pooled regression assigns it a large coefficient.
		var predictors: [[Double]] = []
		var outcomes: [Bool] = []
		for group in groups { for row in group { predictors.append(row.features); outcomes.append(row.chosen) } }
		let pooled = try LogisticRegression<Double>(predictors: predictors, outcomes: outcomes).fit()
		#expect(pooled.coefficients[2] > 0.8)
	}

	// MARK: - The scale

	@Test("The scale is the maximiser of the likelihood in the scale")
	func scaleIsMaximiser() throws {
		let groups = GroupedChoiceSynthetic.make(seed: 5, groups: 600, candidates: 8, sizes: [2, 3], beta: [0.6, 0.3])
		let model = try model(groups, reference: [1, 1])
		let weights = ones(model)
		let scale = try model.fitScale(groupWeights: weights)
		func nll(_ value: Double) -> Double {
			model.negativeLogLikelihood(multipliers: [1, 1], scale: value, groupWeights: weights)?.total ?? .infinity
		}
		for neighbour in [scale * 0.9, scale * 0.99, scale * 1.01, scale * 1.1] { #expect(nll(scale) < nll(neighbour)) }
		let reference = try model.referenceFit(groupWeights: weights)
		#expect(reference.multipliers == [1, 1])
		#expect(reference.scale == scale)
		#expect(reference.iterations == 0)
	}

	// MARK: - Penalty and constraints

	@Test("A very large penalty returns the reference; a very small one the unpenalised optimum")
	func penaltyEnds() throws {
		let groups = GroupedChoiceSynthetic.make(seed: 13, groups: 900, candidates: 8, sizes: [2, 3, 4], beta: [0.9, 0.4])
		let model = try model(groups, reference: [1, 1])
		let weights = ones(model)
		let pinned = try model.fit(groupWeights: weights, penalty: 1e7)
		for value in pinned.multipliers { #expect(abs(value - 1) < 1e-4) }
		let loose = try model.fit(groupWeights: weights, penalty: 1e-9)
		let looser = try model.fit(groupWeights: weights, penalty: 1e-12)
		for k in 0..<2 { #expect(abs(loose.multipliers[k] - looser.multipliers[k]) < 1e-3) }
		#expect(abs(loose.multipliers[0] - 1) > 0.05 || abs(loose.multipliers[1] - 1) > 0.05)
	}

	@Test("The fit sits at the optimum: the gradient of the penalised objective is zero for every multiplier above zero")
	func firstOrderOptimality() throws {
		let groups = GroupedChoiceSynthetic.make(seed: 37, groups: 600, candidates: 8, sizes: [2, 3, 4], beta: [0.9, 0.4, 0.7])
		let model = try model(groups, reference: [1, 1, 1])
		let weights = ones(model)
		for penalty in [0.5, 0.05] {
			let fit = try model.fit(groupWeights: weights, penalty: penalty)
			let evaluated = try #require(model.evaluate(multipliers: fit.multipliers, scale: fit.scale, groupWeights: weights, gradient: true))
			for k in 0..<3 where fit.multipliers[k] > 1e-9 {
				let slope = evaluated.gradient[k] / evaluated.chosen + penalty * (fit.multipliers[k] - 1)
				#expect(abs(slope) < 1e-3)
			}
		}
	}

	@Test("A penalty of zero is allowed and recovers the weights on well-posed data")
	func zeroPenalty() throws {
		let beta = [0.9, 0.4]
		let groups = GroupedChoiceSynthetic.make(seed: 83, groups: 1200, candidates: 8, sizes: [2, 3, 4], beta: beta)
		let model = try model(groups, reference: [1, 1])
		let fit = try model.fit(groupWeights: ones(model), penalty: 0)
		for k in 0..<2 { #expect(abs(fit.scale * fit.multipliers[k] - beta[k]) < RecoveryTolerance.weight) }
	}

	@Test("A feature that truly predicts the opposite way ends at zero, never negative")
	func nonNegativity() throws {
		let groups = GroupedChoiceSynthetic.make(seed: 17, groups: 1200, candidates: 8, sizes: [2, 3, 4], beta: [0.9, -0.8])
		let model = try model(groups, reference: [1, 1])
		let fit = try model.fit(groupWeights: ones(model), penalty: 1e-6)
		#expect(fit.multipliers[1] == 0)
		#expect(fit.multipliers[0] > 0.3)
	}

	@Test("Frozen features and features with a zero reference stay at one")
	func frozenAndZeroReference() throws {
		let groups = GroupedChoiceSynthetic.make(seed: 19, groups: 800, candidates: 8, sizes: [2, 3], beta: [0.9, 0.4, 0.7])
		let weights = [Double](repeating: 1, count: 800)
		let frozenModel = try model(groups, reference: [1, 1, 1])
		let frozen = try frozenModel.fit(groupWeights: weights, penalty: 1e-6, frozen: [1])
		#expect(frozen.multipliers[1] == 1)
		#expect(frozen.multipliers[0] != 1)
		let zeroModel = try model(groups, reference: [1, 0, 1])
		let zero = try zeroModel.fit(groupWeights: weights, penalty: 1e-6)
		#expect(zero.multipliers[1] == 1)
		let allFrozen = try frozenModel.fit(groupWeights: weights, penalty: 1e-6, frozen: [0, 1, 2])
		#expect(allFrozen.multipliers == [1, 1, 1])
		#expect(allFrozen.iterations == 0)
	}

	@Test("Counting a group twice is the same as repeating it")
	func weightsEqualDuplication() throws {
		let groups = GroupedChoiceSynthetic.make(seed: 23, groups: 40, candidates: 6, sizes: [1, 2, 3], beta: [0.7, 0.3])
		let weighted = try model(groups, reference: [1, 1])
		var counts = [Double](repeating: 1, count: 40)
		counts[3] = 2
		counts[10] = 0
		counts[11] = 3
		var repeated: [Group] = []
		for (index, group) in groups.enumerated() { for _ in 0..<Int(counts[index]) { repeated.append(group) } }
		let duplicated = try model(repeated, reference: [1, 1])
		let a = try weighted.fit(groupWeights: counts, penalty: 0.05)
		let b = try duplicated.fit(groupWeights: ones(duplicated), penalty: 0.05)
		#expect(abs(a.scale - b.scale) < 1e-6)
		for k in 0..<2 { #expect(abs(a.multipliers[k] - b.multipliers[k]) < 1e-5) }
	}

	@Test("A warm start from the solution settles at once; a negative start is raised to zero")
	func warmStart() throws {
		let groups = GroupedChoiceSynthetic.make(seed: 89, groups: 600, candidates: 8, sizes: [2, 3, 4], beta: [0.9, 0.4])
		let model = try model(groups, reference: [1, 1])
		let weights = ones(model)
		let cold = try model.fit(groupWeights: weights, penalty: 0.05)
		let warm = try model.fit(groupWeights: weights, penalty: 0.05, start: cold.multipliers)
		#expect(warm.iterations < cold.iterations)
		for k in 0..<2 { #expect(abs(warm.multipliers[k] - cold.multipliers[k]) < 1e-4) }
		let clamped = try model.fit(groupWeights: weights, penalty: 0.05, start: [-5, -5])
		for k in 0..<2 { #expect(clamped.multipliers[k] >= 0) }
		for k in 0..<2 { #expect(abs(clamped.multipliers[k] - cold.multipliers[k]) < 1e-3) }
	}

	@Test("Scores under a fit are one per candidate, and a fit of the wrong width or with a non-finite value has none")
	func scoresForFit() throws {
		let groups = GroupedChoiceSynthetic.make(seed: 91, groups: 20, candidates: 5, sizes: [2], beta: [0.9, 0.4])
		let model = try model(groups, reference: [1, 2])
		let fit = GroupedChoiceFit<Double>(multipliers: [1.5, 0.5], scale: 2, iterations: 0, converged: true)
		let scores = try #require(model.scores(for: fit))
		#expect(scores.count == model.data.rowCount)
		// The first candidate's score by hand: scale x (m0 x r0 x f0 + m1 x r1 x f1) = 2 x (1.5 x 1 x f0 + 0.5 x 2 x f1).
		let first = groups[0][0].features
		#expect(abs(scores[0] - 2 * (1.5 * first[0] + 1.0 * first[1])) < 1e-12)
		#expect(model.scores(for: GroupedChoiceFit(multipliers: [1], scale: 1, iterations: 0, converged: true)) == nil)
		#expect(model.scores(for: GroupedChoiceFit(multipliers: [1, Double.nan], scale: 1, iterations: 0, converged: true)) == nil)
		#expect(model.scores(for: GroupedChoiceFit(multipliers: [1, 1], scale: Double.infinity, iterations: 0, converged: true)) == nil)
	}

	@Test("The same data and seed give the same fit")
	func deterministic() throws {
		let groups = GroupedChoiceSynthetic.make(seed: 29, groups: 300, candidates: 8, sizes: [2, 3], beta: [0.5, 0.5])
		let model = try model(groups, reference: [1, 1])
		let first = try model.fit(groupWeights: ones(model), penalty: 0.1)
		let second = try model.fit(groupWeights: ones(model), penalty: 0.1)
		#expect(first == second)
	}

	@Test("A fit can be recovered from its own coding")
	func codable() throws {
		let fit = GroupedChoiceFit<Double>(multipliers: [1.5, 0], scale: 0.7, iterations: 12, converged: true)
		let decoded = try JSONDecoder().decode(GroupedChoiceFit<Double>.self, from: JSONEncoder().encode(fit))
		#expect(decoded == fit)
	}

	// MARK: - Refusals

	@Test("Bad arguments throw, and a result that did not settle is never returned")
	func refusals() throws {
		let groups = GroupedChoiceSynthetic.make(seed: 31, groups: 100, candidates: 6, sizes: [2], beta: [0.9, 0.4])
		let model = try model(groups, reference: [1, 1])
		let weights = ones(model)
		#expect(throws: GroupedChoiceError.malformedInput(reason: "penalty must be finite and not negative")) {
			try model.fit(groupWeights: weights, penalty: -1)
		}
		#expect(throws: GroupedChoiceError.malformedInput(reason: "penalty must be finite and not negative")) {
			try model.fit(groupWeights: weights, penalty: .nan)
		}
		#expect(throws: GroupedChoiceError.malformedInput(reason: "groupWeights must have one entry per group")) {
			try model.fit(groupWeights: [1], penalty: 1)
		}
		#expect(throws: GroupedChoiceError.malformedInput(reason: "groupWeights must be finite and not negative")) {
			try model.fit(groupWeights: [Double](repeating: -1, count: 100), penalty: 1)
		}
		#expect(throws: GroupedChoiceError.malformedInput(reason: "start must have one finite value per feature")) {
			try model.fit(groupWeights: weights, penalty: 1, start: [1])
		}
		#expect(throws: GroupedChoiceError.malformedInput(reason: "maxIterations must be positive")) {
			try model.fit(groupWeights: weights, penalty: 1, maxIterations: 0)
		}
		#expect(throws: GroupedChoiceError.noInformativeGroups) {
			try model.fit(groupWeights: [Double](repeating: 0, count: 100), penalty: 1)
		}
		#expect(throws: GroupedChoiceError.noInformativeGroups) { try model.fitScale(groupWeights: [Double](repeating: 0, count: 100)) }
		#expect(throws: GroupedChoiceError.self) { try model.fit(groupWeights: weights, penalty: 1e-9, maxIterations: 1) }
	}
}

/// Tolerances measured from the spread of the estimate over seeds (see the tests that use them).
enum RecoveryTolerance {
	/// Effective weight (scale × multiplier) against the truth, 1500 groups of 8, three features.
	static let weight = 0.12
}

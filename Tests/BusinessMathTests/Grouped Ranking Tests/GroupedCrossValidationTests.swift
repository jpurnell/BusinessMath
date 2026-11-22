//
//  GroupedCrossValidationTests.swift
//  BusinessMath
//
//  Held-out comparison, nested penalty choice and bootstrap intervals for grouped choices.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Grouped choice: cross-validation")
struct GroupedCrossValidationTests {

	private typealias Group = GroupedChoiceSynthetic.Group

	private func model(_ groups: [Group], reference: [Double]) throws -> GroupedChoiceModel<Double> {
		let data = try #require(GroupedChoiceData<Double>(groups: groups))
		return try #require(GroupedChoiceModel(data: data, reference: reference, likelihood: .subset))
	}

	private let grid: [PenaltyChoice<Double>] = [.reference, .penalty(10), .penalty(1), .penalty(0.1), .penalty(0.01)]

	// MARK: - Evidence

	@Test("Feature counts are worked by hand")
	func featureCounts() throws {
		let data = try #require(GroupedChoiceData<Double>(groups: [
			[(features: [1, 0], chosen: true), (features: [1, 1], chosen: false), (features: [0, 1], chosen: false)],
			[(features: [0, 1], chosen: true), (features: [1, 0], chosen: true)],
			[(features: [1, 1], chosen: true), (features: [0, 0], chosen: false)],
		]))
		let model = try #require(GroupedChoiceModel(data: data, reference: [1, 1], likelihood: .subset))
		// Group 1 chose everything, so it is not informative and does not count.
		// Group 0: feature 0 on candidates 0 (chosen) and 1; feature 1 on candidates 1 and 2. Group 2: both features on the chosen one.
		let counts = try #require(GroupedCrossValidation.featureCounts(model: model, groupWeights: [1, 1, 1]))
		#expect(counts.carrying == [3, 3])
		#expect(counts.chosenCarrying == [2, 1])
		let weighted = try #require(GroupedCrossValidation.featureCounts(model: model, groupWeights: [0, 1, 1]))
		#expect(weighted.carrying == [1, 1])
		#expect(weighted.chosenCarrying == [1, 1])
		#expect(GroupedCrossValidation.featureCounts(model: model, groupWeights: [1]) == nil)
		#expect(GroupedCrossValidation.thinFeatures(model: model, groupWeights: [1, 1, 1], minimumChosen: 2) == [1])
	}

	// MARK: - Choosing the penalty

	@Test("With a strong signal a weak penalty is chosen; with none, the strongest option")
	func choosePenalty() throws {
		let signal = GroupedChoiceSynthetic.make(seed: 41, groups: 400, candidates: 6, sizes: [2, 3], beta: [1.2, 0.8])
		// A reference that is wrong in scale and shape, so the refit has something to learn.
		let wrong = try model(signal, reference: [0.1, 1.5])
		let weights = [Double](repeating: 1, count: 400)
		let chosen = GroupedCrossValidation.choosePenalty(model: wrong, groupWeights: weights, penalties: grid, folds: 4, seed: 1)
		#expect(chosen != .reference)
		let noise = GroupedChoiceSynthetic.make(seed: 43, groups: 400, candidates: 6, sizes: [2, 3], beta: [0, 0])
		let flat = try model(noise, reference: [1, 1])
		let weak = GroupedCrossValidation.choosePenalty(model: flat, groupWeights: weights, penalties: grid, folds: 4, seed: 1)
		#expect(weak == .reference || weak == .penalty(10))
	}

	@Test("With too few groups to cross-validate, the reference is kept")
	func chooseFewGroups() throws {
		let groups = GroupedChoiceSynthetic.make(seed: 47, groups: 7, candidates: 6, sizes: [2], beta: [1])
		let model = try model(groups, reference: [1])
		let choice = GroupedCrossValidation.choosePenalty(
			model: model, groupWeights: [Double](repeating: 1, count: 7), penalties: grid, folds: 4, seed: 1)
		#expect(choice == .reference)
		#expect(GroupedCrossValidation.choosePenalty(
			model: model, groupWeights: [Double](repeating: 1, count: 7), penalties: grid, folds: 1, seed: 1) == .reference)
	}

	@Test("Exactly tied candidates go to the stronger penalty")
	func tiesGoToTheStrongerPenalty() throws {
		let groups = GroupedChoiceSynthetic.make(seed: 97, groups: 80, candidates: 6, sizes: [2, 3], beta: [0.5, 0.5])
		let model = try model(groups, reference: [1, 1])
		// Every feature frozen, so every penalty gives the same fit and the same held-out likelihood: an exact tie.
		let chosen = GroupedCrossValidation.choosePenalty(
			model: model, groupWeights: [Double](repeating: 1, count: 80), penalties: [.penalty(0.01), .penalty(10), .penalty(1)],
			frozen: [0, 1], folds: 4, seed: 1)
		#expect(chosen == .penalty(10))
	}

	@Test("Fewer than two groups per fold are not cross-validated, even when a refit would clearly win")
	func fewGroupsEvenWithSignal() throws {
		let groups = GroupedChoiceSynthetic.make(seed: 101, groups: 7, candidates: 6, sizes: [2], beta: [2.0, 0.0])
		let model = try model(groups, reference: [0.1, 2.0])
		let weights = [Double](repeating: 1, count: 7)
		#expect(model.data.informativeGroups.count == 7)
		let choice = GroupedCrossValidation.choosePenalty(
			model: model, groupWeights: weights, penalties: [.penalty(0.001), .penalty(0.01)], folds: 4, seed: 1)
		#expect(choice == .reference)
	}

	// MARK: - Held-out comparison

	@Test("Comparing the reference with itself gives exactly zero and an interval that includes it")
	func selfComparison() throws {
		let groups = GroupedChoiceSynthetic.make(seed: 51, groups: 200, candidates: 6, sizes: [2, 3], beta: [0.8, 0.4])
		let model = try model(groups, reference: [1, 1])
		let result = try #require(GroupedCrossValidation.heldOutComparison(
			model: model, penalties: [.reference], minimumChosen: 1, folds: 4, innerFolds: 3, resamples: 50, level: 0.9, seed: 7))
		#expect(result.difference == 0)
		#expect(result.lower == 0 && result.upper == 0)
		#expect(!result.refitBeatsReference)
		#expect(!result.intervalExcludesZero)
		#expect(result.referencePercentile == result.refitPercentile)
		#expect(result.penalties.allSatisfy { $0 == .reference })
		#expect(result.resamples == 50)
		#expect(abs(result.level - 0.9) < 1e-12)
	}

	@Test("A refit that is truly better has an interval above zero; every informative group is held out once")
	func betterRefit() throws {
		let groups = GroupedChoiceSynthetic.make(seed: 53, groups: 320, candidates: 6, sizes: [2, 3], beta: [1.0, 0.0])
		// A reference that weighs the useless feature at twice the useful one. (The penalty is on the RELATIVE change, so a
		// reference that is tiny for the useful feature could barely be moved: the design is chosen so the data can argue.)
		let model = try model(groups, reference: [0.5, 1.0])
		let result = try #require(GroupedCrossValidation.heldOutComparison(
			model: model, penalties: [.penalty(0.01), .penalty(0.001)], minimumChosen: 5, folds: 4, innerFolds: 3, resamples: 100,
			level: 0.9, seed: 3))
		#expect(result.difference > 0.02)
		#expect(result.refitBeatsReference)
		#expect(result.intervalExcludesZero)
		#expect(result.refitPercentile > result.referencePercentile)
		#expect(result.foldSizes.reduce(0, +) == model.data.informativeGroups.count)
		#expect(result.groups == model.data.informativeGroups.count)
		#expect(result.difference > result.lower)
		#expect(result.difference < result.upper)
		#expect(result.spread > 0)
	}

	@Test("With no signal the interval includes zero")
	func nullComparison() throws {
		let groups = GroupedChoiceSynthetic.make(seed: 59, groups: 300, candidates: 6, sizes: [2, 3], beta: [0, 0])
		let model = try model(groups, reference: [1, 1])
		let result = try #require(GroupedCrossValidation.heldOutComparison(
			model: model, penalties: grid, minimumChosen: 5, folds: 4, innerFolds: 3, resamples: 100, level: 0.9, seed: 5))
		#expect(!result.refitBeatsReference)
	}

	@Test("The same seed gives the same comparison, and a different seed a different one")
	func comparisonDeterminism() throws {
		let groups = GroupedChoiceSynthetic.make(seed: 61, groups: 200, candidates: 6, sizes: [2, 3], beta: [0.8, 0.4])
		let model = try model(groups, reference: [0.3, 1.2])
		func run(_ seed: UInt64) -> HeldOutComparison<Double>? {
			GroupedCrossValidation.heldOutComparison(
				model: model, penalties: [.penalty(0.1), .penalty(0.01)], minimumChosen: 5, folds: 4, innerFolds: 3, resamples: 60,
				level: 0.9, seed: seed)
		}
		#expect(run(7) == run(7))
		#expect(run(7) != run(8))
	}

	@Test("Too few groups, or fewer than two folds, give no comparison")
	func comparisonRefusals() throws {
		let groups = GroupedChoiceSynthetic.make(seed: 67, groups: 7, candidates: 6, sizes: [2], beta: [1])
		let model = try model(groups, reference: [1])
		#expect(GroupedCrossValidation.heldOutComparison(
			model: model, penalties: grid, minimumChosen: 1, folds: 4, innerFolds: 2, resamples: 10, level: 0.9, seed: 1) == nil)
		#expect(GroupedCrossValidation.heldOutComparison(
			model: model, penalties: grid, minimumChosen: 1, folds: 1, innerFolds: 2, resamples: 10, level: 0.9, seed: 1) == nil)
	}

	@Test("The penalty chosen for a fold cannot depend on that fold's held-out groups")
	func foldDiscipline() throws {
		let groups = GroupedChoiceSynthetic.make(seed: 71, groups: 160, candidates: 6, sizes: [2, 3], beta: [1.0, 0.2])
		let base = try model(groups, reference: [0.4, 1.0])
		let slots = base.data.informativeGroups
		var assigner = SplitMix64(seed: 5 &+ 3)
		let assignment = GroupResampling.foldAssignment(groups: slots.count, folds: 4, using: &assigner)
		let held = Set(slots.indices.filter { assignment[$0] == 0 }.map { slots[$0] })
		// The adversary: in fold 0's groups only, reverse which candidates were chosen (the counts stay the same).
		var altered = groups
		for index in held { altered[index] = zip(groups[index], groups[index].reversed()).map { (features: $0.0.features, chosen: $0.1.chosen) } }
		let other = try model(altered, reference: [0.4, 1.0])
		#expect(other.data.informativeGroups == slots)
		func run(_ model: GroupedChoiceModel<Double>) -> HeldOutComparison<Double>? {
			GroupedCrossValidation.heldOutComparison(
				model: model, penalties: grid, minimumChosen: 5, folds: 4, innerFolds: 3, resamples: 20, level: 0.9, seed: 5)
		}
		let a = try #require(run(base))
		let b = try #require(run(other))
		#expect(a.penalties[0] == b.penalties[0])
		#expect(a.foldSizes == b.foldSizes)
		#expect(a.difference != b.difference)
	}

	// MARK: - Bootstrap intervals

	@Test("Bootstrap intervals bracket the fit and the true weight, and can be refused")
	func bootstrapIntervals() throws {
		let beta = [0.9, 0.4]
		let groups = GroupedChoiceSynthetic.make(seed: 73, groups: 400, candidates: 6, sizes: [2, 3], beta: beta)
		let model = try model(groups, reference: [1, 1])
		let weights = [Double](repeating: 1, count: 400)
		let full = try model.fit(groupWeights: weights, penalty: 1e-3)
		let intervals = try #require(GroupedCrossValidation.bootstrapIntervals(
			model: model, full: full, penalty: 1e-3, groupWeights: weights, resamples: 60, level: 0.9, seed: 9))
		#expect(intervals.resamples + intervals.skipped == 60)
		#expect(abs(intervals.level - 0.9) < 1e-12)
		for k in 0..<2 {
			#expect(intervals.lower[k] <= intervals.upper[k])
			#expect(intervals.lower[k] <= full.multipliers[k] && full.multipliers[k] <= intervals.upper[k])
			let weight = full.scale
			#expect(intervals.lower[k] * weight <= beta[k] && beta[k] <= intervals.upper[k] * weight)
		}
		let repeated = try #require(GroupedCrossValidation.bootstrapIntervals(
			model: model, full: full, penalty: 1e-3, groupWeights: weights, resamples: 60, level: 0.9, seed: 9))
		#expect(repeated == intervals)
		#expect(GroupedCrossValidation.bootstrapIntervals(
			model: model, full: full, penalty: 1e-3, groupWeights: weights, resamples: 0, level: 0.9, seed: 9) == nil)
		#expect(GroupedCrossValidation.bootstrapIntervals(
			model: model, full: full, penalty: 1e-3, groupWeights: [1], resamples: 10, level: 0.9, seed: 9) == nil)
	}
}

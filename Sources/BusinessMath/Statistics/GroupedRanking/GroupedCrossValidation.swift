//
//  GroupedCrossValidation.swift
//  BusinessMath
//

import Foundation
import Numerics

/// Grouped cross-validation, group bootstrap intervals and the held-out comparison of a refit against its reference.
///
/// Folds hold whole groups. A penalty (and which features are free to move) is chosen **inside each training set** by an inner
/// grouped k-fold on the training groups only, so the outer held-out groups never influence it.
public enum GroupedCrossValidation {

	// MARK: - Evidence for a feature

	/// How many candidates carry each feature, and how many of those were chosen, over the informative groups with positive weight.
	///
	/// Offered so a caller can apply its own evidence rule (for example, "do not refit a feature too few chosen candidates carry").
	@_specialize(exported: true, where T == Double)
	public static func featureCounts<T: Real & Sendable & BinaryFloatingPoint>(
		model: GroupedChoiceModel<T>, groupWeights: [T]
	) -> (carrying: [Int], chosenCarrying: [Int])? {
		let data = model.data
		guard groupWeights.count == data.groupCount else { return nil }
		var carrying = [Int](repeating: 0, count: data.featureCount)
		var chosen = [Int](repeating: 0, count: data.featureCount)
		for group in data.informativeGroups where groupWeights[group] > T.zero {
			for row in data.rows(ofGroup: group) {
				for entry in data.rowEntryStart[row]..<data.rowEntryStart[row + 1] {
					let feature = data.entryFeature[entry]
					carrying[feature] += 1
					if data.rowChosen[row] { chosen[feature] += 1 }
				}
			}
		}
		return (carrying, chosen)
	}

	/// The features fewer than `minimumChosen` chosen candidates carry, judged on the weighted groups only.
	static func thinFeatures<T: Real & Sendable & BinaryFloatingPoint>(
		model: GroupedChoiceModel<T>, groupWeights: [T], minimumChosen: Int
	) -> Set<Int> {
		guard let counts = featureCounts(model: model, groupWeights: groupWeights) else { return [] }
		return Set(counts.chosenCarrying.indices.filter { counts.chosenCarrying[$0] < minimumChosen })
	}

	// MARK: - Choosing a penalty

	/// The penalty with the best held-out likelihood, by cross-validation over the groups with positive weight.
	///
	/// Each candidate is fitted on the training groups of each fold and scored by the conditional log-likelihood per chosen
	/// candidate on the held-out groups. A candidate whose fit does not settle in a fold is not eligible. Ties go to the **stronger**
	/// penalty (the data must do better to move a weight), with ``PenaltyChoice/reference`` the strongest of all.
	///
	/// - Parameters:
	///   - model: The model.
	///   - groupWeights: How much each group counts; groups with weight zero are not used.
	///   - penalties: The candidates.
	///   - frozen: Features held at their reference value.
	///   - folds: How many folds; at least two.
	///   - seed: Seeds the fold assignment.
	/// - Returns: The best candidate, or ``PenaltyChoice/reference`` when there are fewer than `2 × folds` groups to cross-validate
	///   or no candidate could be scored.
	@_specialize(exported: true, where T == Double)
	public static func choosePenalty<T: Real & Sendable & BinaryFloatingPoint>(
		model: GroupedChoiceModel<T>, groupWeights: [T], penalties: [PenaltyChoice<T>], frozen: Set<Int> = [], folds: Int, seed: UInt64
	) -> PenaltyChoice<T> {
		let slots = model.data.informativeGroups.filter { groupWeights.count == model.data.groupCount && groupWeights[$0] > T.zero }
		guard folds >= 2, slots.count >= 2 * folds else { return .reference }
		var generator = SplitMix64(seed: seed)
		let assignment = GroupResampling.foldAssignment(groups: slots.count, folds: folds, using: &generator)
		// Strongest first: the reference, then finite penalties from large to small.
		let grid = penalties.filter { $0 == .reference } + finite(penalties).sorted(by: >).map { PenaltyChoice<T>.penalty($0) }
		var best: PenaltyChoice<T> = .reference
		var bestScore: T = T.infinity
		var found = false
		let margin: T = T(1) / T(1_000_000_000)
		for candidate in grid {
			var total: T = T.zero
			var chosen: T = T.zero
			var eligible = true
			for fold in 0..<folds {
				var training = groupWeights
				var testing = [T](repeating: T.zero, count: groupWeights.count)
				for (position, slot) in slots.enumerated() where assignment[position] == fold {
					training[slot] = T.zero
					testing[slot] = groupWeights[slot]
				}
				let attempt = Result { try fit(model: model, weights: training, choice: candidate, frozen: frozen) }
				guard case .success(let fitted) = attempt else {
					eligible = false
					break
				}
				guard let held = model.negativeLogLikelihood(fitted, groupWeights: testing) else { eligible = false; break }
				total += held.total
				chosen += held.chosen
			}
			guard eligible, chosen > T.zero else { continue }
			let score: T = total / chosen
			if !found || score < bestScore - margin {
				best = candidate
				bestScore = score
				found = true
			}
		}
		return found ? best : .reference
	}

	private static func finite<T: Real & Sendable & BinaryFloatingPoint>(_ penalties: [PenaltyChoice<T>]) -> [T] {
		penalties.compactMap { choice -> T? in
			guard case .penalty(let value) = choice, value.isFinite, value >= T.zero else { return nil }
			return value
		}
	}

	private static func fit<T: Real & Sendable & BinaryFloatingPoint>(
		model: GroupedChoiceModel<T>, weights: [T], choice: PenaltyChoice<T>, frozen: Set<Int>
	) throws -> GroupedChoiceFit<T> {
		switch choice {
		case .reference: return try model.referenceFit(groupWeights: weights)
		case .penalty(let value): return try model.fit(groupWeights: weights, penalty: value, frozen: frozen)
		}
	}

	// MARK: - Bootstrap intervals for the multipliers

	/// Percentile intervals for each multiplier from refitting on bootstrap resamples of groups.
	///
	/// Resamples whose fit does not settle, or that have nothing to compare, are dropped and counted. Each refit starts from `full`.
	///
	/// - Parameters:
	///   - model: The model.
	///   - full: The fit on the groups as they are (its multipliers are the starting point of each refit).
	///   - penalty: The penalty to refit with.
	///   - frozen: Features held at their reference value.
	///   - groupWeights: The groups to resample: those with positive weight, each counting once per draw.
	///   - resamples: How many to draw.
	///   - level: The share of resamples the interval covers, for example `0.9`.
	///   - seed: Seeds the resampling.
	/// - Returns: `nil` when no resample could be fitted.
	@_specialize(exported: true, where T == Double)
	public static func bootstrapIntervals<T: Real & Sendable & BinaryFloatingPoint>(
		model: GroupedChoiceModel<T>, full: GroupedChoiceFit<T>, penalty: T, frozen: Set<Int> = [], groupWeights: [T],
		resamples: Int, level: T, seed: UInt64
	) -> BootstrapIntervals<T>? {
		let data = model.data
		guard groupWeights.count == data.groupCount, resamples > 0 else { return nil }
		let slots = data.informativeGroups.filter { groupWeights[$0] > T.zero }
		guard !slots.isEmpty else { return nil }
		var generator = SplitMix64(seed: seed)
		var draws: [[T]] = []
		var skipped = 0
		for _ in 0..<resamples {
			let counts: [T] = GroupResampling.bootstrapWeights(groups: slots.count, using: &generator)
			var weights = [T](repeating: T.zero, count: data.groupCount)
			for (position, slot) in slots.enumerated() { weights[slot] = counts[position] * groupWeights[slot] }
			let attempt = Result { try model.fit(groupWeights: weights, penalty: penalty, frozen: frozen, start: full.multipliers) }
			guard case .success(let refit) = attempt else {
				skipped += 1
				continue
			}
			draws.append(refit.multipliers)
		}
		guard !draws.isEmpty else { return nil }
		let tail = tailProbability(level: level)
		var lower: [T] = []
		var upper: [T] = []
		for feature in 0..<data.featureCount {
			let sorted = draws.map { $0[feature] }.sorted()
			lower.append(percentile(sorted, tail))
			upper.append(percentile(sorted, T(1) - tail))
		}
		return BootstrapIntervals(lower: lower, upper: upper, level: level, resamples: draws.count, skipped: skipped)
	}

	// MARK: - Held-out comparison

	/// Whether a refit ranks groups it never saw better than the reference weights, by grouped, nested cross-validation.
	///
	/// Each informative group is held out exactly once. In each fold, the features too few chosen candidates carry are frozen, a
	/// penalty is chosen by an inner grouped k-fold on the training groups only, the model is refitted on the training groups, and the
	/// held-out groups are ranked by the refit and by the reference weights. The paired difference in mean percentile is then
	/// bootstrapped over held-out groups.
	///
	/// - Parameters:
	///   - model: The model.
	///   - penalties: The candidates the inner folds choose among.
	///   - minimumChosen: A feature fewer chosen candidates carry (in a fold's training groups) than this is not refitted.
	///   - folds: The outer folds; at least two.
	///   - innerFolds: The folds used to choose the penalty inside each training set.
	///   - resamples: Bootstrap resamples of the held-out difference; fewer than two gives a degenerate interval.
	///   - level: The share of resamples the interval covers.
	///   - seed: Seeds everything that is random; the fold assignment, each inner assignment and the bootstrap use derived seeds.
	/// - Returns: `nil` when there are fewer than `2 × folds` informative groups, or no held-out group could be compared.
	@_specialize(exported: true, where T == Double)
	public static func heldOutComparison<T: Real & Sendable & BinaryFloatingPoint>(
		model: GroupedChoiceModel<T>, penalties: [PenaltyChoice<T>], minimumChosen: Int, folds: Int, innerFolds: Int,
		resamples: Int, level: T, seed: UInt64
	) -> HeldOutComparison<T>? {
		let data = model.data
		let slots = data.informativeGroups
		guard folds >= 2, slots.count >= 2 * folds else { return nil }
		var assigner = SplitMix64(seed: seed &+ 3)
		let assignment = GroupResampling.foldAssignment(groups: slots.count, folds: folds, using: &assigner)
		let ones = [T](repeating: T(1), count: data.featureCount)
		let referenceScores = model.rowScores(multipliers: ones, scale: T(1))
		var sizes: [Int] = []
		var chosenPenalties: [PenaltyChoice<T>] = []
		var differences: [T] = []
		var referenceSum: T = T.zero
		var refitSum: T = T.zero
		var referenceTop: T = T.zero
		var refitTop: T = T.zero
		for fold in 0..<folds {
			let held = slots.indices.filter { assignment[$0] == fold }.map { slots[$0] }
			sizes.append(held.count)
			var training = [T](repeating: T.zero, count: data.groupCount)
			for (position, slot) in slots.enumerated() where assignment[position] != fold { training[slot] = T(1) }
			let frozen = thinFeatures(model: model, groupWeights: training, minimumChosen: minimumChosen)
			let choice = choosePenalty(
				model: model, groupWeights: training, penalties: penalties, frozen: frozen, folds: innerFolds,
				seed: seed &+ 10 &+ UInt64(fold))
			chosenPenalties.append(choice)
			let attempt = Result { try fit(model: model, weights: training, choice: choice, frozen: frozen) }
			guard case .success(let refit) = attempt, let refitScores = model.scores(for: refit) else { continue }
			for group in held {
				guard let before = GroupRankingMetrics.ranking(group: group, scores: referenceScores, data: data, k: 1),
					  let after = GroupRankingMetrics.ranking(group: group, scores: refitScores, data: data, k: 1)
				else { continue }
				differences.append(after.percentile - before.percentile)
				referenceSum += before.percentile
				refitSum += after.percentile
				referenceTop += before.topOwn
				refitTop += after.topOwn
			}
		}
		guard !differences.isEmpty else { return nil }
		let count: T = T(differences.count)
		let improvement: T = differences.reduce(T.zero, +) / count
		var resampler = SplitMix64(seed: seed &+ 4)
		var means: [T] = []
		for _ in 0..<Swift.max(resamples, 0) {
			var sum: T = T.zero
			for _ in 0..<differences.count { sum += differences[GroupResampling.below(differences.count, using: &resampler)] }
			means.append(sum / count)
		}
		var spread: T = T.zero
		var lower: T = improvement
		var upper: T = improvement
		if means.count > 1 {
			let mean: T = means.reduce(T.zero, +) / T(means.count)
			var squares: T = T.zero
			for value in means {
				let gap: T = value - mean
				squares += gap * gap
			}
			spread = (squares / T(means.count - 1)).squareRoot()
			let sorted = means.sorted()
			let tail = tailProbability(level: level)
			lower = percentile(sorted, tail)
			upper = percentile(sorted, T(1) - tail)
		}
		return HeldOutComparison(
			foldSizes: sizes, penalties: chosenPenalties, groups: differences.count, referencePercentile: referenceSum / count,
			refitPercentile: refitSum / count, referenceTopOwn: referenceTop / count, refitTopOwn: refitTop / count,
			difference: improvement, spread: spread, lower: lower, upper: upper, level: level, resamples: means.count)
	}

	// MARK: - Quantiles

	/// The probability left in each tail of an interval that covers `level` of the resamples.
	static func tailProbability<T: Real & BinaryFloatingPoint>(level: T) -> T {
		let clamped: T = Swift.min(Swift.max(level, T.zero), T(1))
		return (T(1) - clamped) / T(2)
	}

	/// The value at quantile `q` of an ascending list, interpolating linearly.
	static func percentile<T: Real & BinaryFloatingPoint>(_ sorted: [T], _ q: T) -> T {
		guard sorted.count > 1, q.isFinite else { return sorted.first ?? T.zero }
		let clamped: T = Swift.min(Swift.max(q, T.zero), T(1))
		let position: T = clamped * T(sorted.count - 1)
		let below = Int(position.rounded(.down))
		let above = Swift.min(below + 1, sorted.count - 1)
		let weight: T = position - T(below)
		let near: T = sorted[below] * (T(1) - weight)
		let far: T = sorted[above] * weight
		return near + far
	}
}

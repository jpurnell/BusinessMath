//
//  GroupedChoiceModel.swift
//  BusinessMath
//

import Foundation
import Numerics

/// A choice model over groups: what the likelihood of the observed choices is under a set of weights.
///
/// Each candidate's score is
///
/// `scale × (offset + Σ multiplier[k] × reference[k] × feature[k])`
///
/// so the weights being fitted are **multiples of a supplied reference**: a multiplier of `1` leaves a feature at its
/// reference value. A group's chance of having chosen the set it chose is the *conditional logit*: with a propensity of
/// its own to choose (which cancels), the probability of the chosen set is the product of its candidates' `exp(score)`
/// over the sum of that product across every possible set of the same size. That sum is computed exactly, by dynamic
/// programming, in time proportional to candidates times chosen. How many a group chooses therefore cannot move the
/// weights.
///
/// This is **not** a softmax per chosen candidate over the whole candidate set. That never removes candidates already
/// taken, and on data generated from the intended model it is biased (in the recovery test, a single feature of true weight 1 is fitted at about 0.64); the exact form is not. The two
/// coincide only when every group chooses exactly one.
///
/// ```swift
/// let data = GroupedChoiceData<Double>(groups: [
///     [(features: [1], chosen: true), (features: [0], chosen: false)],
/// ])!
/// let model = GroupedChoiceModel(data: data, reference: [1], likelihood: .subset)!
/// let nll = model.negativeLogLikelihood(multipliers: [1], scale: 1, groupWeights: [1])
/// // nll.total == log(1 + e^-1), the chance the chosen candidate was the one with the feature
/// ```
public struct GroupedChoiceModel<T: Real & Sendable & BinaryFloatingPoint>: Sendable {

	/// The candidates and which were chosen.
	public let data: GroupedChoiceData<T>

	/// The reference weight for each feature column; each is finite and not negative.
	public let reference: [T]

	/// Which likelihood the model uses.
	public let likelihood: ChoiceLikelihood

	let entryZ: [T]

	/// Creates a model, or `nil` when the reference does not fit the data.
	///
	/// - Parameters:
	///   - data: The candidates grouped by chooser.
	///   - reference: One finite, non-negative weight per feature column. A feature whose reference is `0` contributes
	///     nothing and cannot be fitted.
	///   - likelihood: The likelihood to use.
	public init?(data: GroupedChoiceData<T>, reference: [T], likelihood: ChoiceLikelihood) {
		guard reference.count == data.featureCount else { return nil }
		guard data.isRanked == (likelihood == .ranking) else { return nil }
		guard reference.allSatisfy({ $0.isFinite && $0 >= T.zero }) else { return nil }
		self.data = data
		self.reference = reference
		self.likelihood = likelihood
		self.entryZ = zip(data.entryFeature, data.entryValue).map { reference[$0] * $1 }
	}

	/// What a fit measured while it was being evaluated.
	struct Evaluation {
		var negativeLogLikelihood: T = T.zero
		var chosen: T = T.zero
		var gradient: [T]
		var groupsUsed: Int = 0
	}

	/// Working space for one group, reused across groups.
	struct Work {
		var forward: [T] = []
		var backward: [T] = []
		var terms: [T] = []
		var inclusion: [T] = []
		var taken: [Bool] = []
	}

	/// Each candidate's score under `multipliers` and `scale`, in row order.
	func rowScores(multipliers: [T], scale: T) -> [T] {
		var result = [T](repeating: T.zero, count: data.rowCount)
		for row in 0..<data.rowCount {
			var total: T = data.rowOffset[row]
			for entry in data.rowEntryStart[row]..<data.rowEntryStart[row + 1] {
				let weight: T = multipliers[data.entryFeature[entry]]
				total += weight * entryZ[entry]
			}
			result[row] = scale * total
		}
		return result
	}

	/// The negative log-likelihood of the observed choices, summed over groups with their weights, and the weighted
	/// number of chosen candidates counted.
	///
	/// - Parameters:
	///   - multipliers: One per feature column; `1` leaves the reference value.
	///   - scale: Log-odds per reference point.
	///   - groupWeights: How much each group counts: `0` leaves it out, `2` counts it twice (as in a resample).
	/// - Returns: `nil` when `multipliers` or `groupWeights` have the wrong length, or a weight is negative or not finite.
	///   Groups with nothing to compare contribute nothing.
	@_specialize(exported: true, where T == Double)
	public func negativeLogLikelihood(multipliers: [T], scale: T, groupWeights: [T]) -> (total: T, chosen: T)? {
		guard let evaluation = evaluate(multipliers: multipliers, scale: scale, groupWeights: groupWeights, gradient: false) else {
			return nil
		}
		return (evaluation.negativeLogLikelihood, evaluation.chosen)
	}

	/// The likelihood, and optionally its gradient with respect to the multipliers.
	func evaluate(multipliers: [T], scale: T, groupWeights: [T], gradient wantGradient: Bool) -> Evaluation? {
		guard multipliers.count == data.featureCount, groupWeights.count == data.groupCount else { return nil }
		guard groupWeights.allSatisfy({ $0.isFinite && $0 >= T.zero }), scale.isFinite else { return nil }
		guard multipliers.allSatisfy({ $0.isFinite }) else { return nil }
		let scores = rowScores(multipliers: multipliers, scale: scale)
		return evaluate(scores: scores, scale: scale, groupWeights: groupWeights, gradient: wantGradient)
	}

	/// The same, from scores already computed.
	func evaluate(scores: [T], scale: T, groupWeights: [T], gradient wantGradient: Bool) -> Evaluation {
		var evaluation = Evaluation(gradient: [T](repeating: T.zero, count: data.featureCount))
		var work = Work()
		var expected = [T](repeating: T.zero, count: data.featureCount)
		var taken = [T](repeating: T.zero, count: data.featureCount)
		for group in 0..<data.groupCount {
			let weight: T = groupWeights[group]
			guard weight > T.zero,
				  let result = groupLikelihood(group: group, scores: scores, work: &work, wantInclusion: wantGradient)
			else { continue }
			let steps: T = T(result.steps)
			evaluation.chosen += weight * steps
			evaluation.negativeLogLikelihood -= weight * result.logLikelihood
			evaluation.groupsUsed += 1
			guard wantGradient else { continue }
			for k in 0..<data.featureCount { expected[k] = T.zero; taken[k] = T.zero }
			for (position, row) in data.rows(ofGroup: group).enumerated() {
				let chance: T = work.inclusion[position]
				let isTaken: Bool = work.taken[position]
				for entry in data.rowEntryStart[row]..<data.rowEntryStart[row + 1] {
					let k: Int = data.entryFeature[entry]
					let z: T = entryZ[entry]
					expected[k] += chance * z
					if isTaken { taken[k] += z }
				}
			}
			let factor: T = scale * weight
			for k in 0..<data.featureCount {
				let difference: T = taken[k] - expected[k]
				evaluation.gradient[k] -= factor * difference
			}
		}
		return evaluation
	}

	/// One group's log-likelihood and how many chosen candidates it counted; `nil` when there is nothing to compare.
	///
	/// When `wantInclusion` is set, `work.inclusion` holds, for each candidate in the group, the chance it is among the
	/// chosen, and `work.taken` which candidates count as chosen.
	func groupLikelihood(group: Int, scores: [T], work: inout Work, wantInclusion: Bool) -> (logLikelihood: T, steps: Int)? {
		switch likelihood {
		case .subset:
			return subsetGroup(group: group, scores: scores, work: &work, wantInclusion: wantInclusion)
		case .ranking:
			return rankingGroup(group: group, scores: scores, work: &work)
		}
	}

	private func subsetGroup(group: Int, scores: [T], work: inout Work, wantInclusion: Bool) -> (logLikelihood: T, steps: Int)? {
		let rows = data.rows(ofGroup: group)
		let count = rows.count
		var friends = 0
		var maximum: T = -T.infinity
		var friendTotal: T = T.zero
		for row in rows {
			let score: T = scores[row]
			maximum = Swift.max(maximum, score)
			if data.rowChosen[row] { friends += 1; friendTotal += score }
		}
		guard friends > 0, friends < count, maximum.isFinite else { return nil }
		if work.terms.count < count {
			work.terms = [T](repeating: T.zero, count: count)
			work.inclusion = work.terms
		}
		work.taken = rows.map { data.rowChosen[$0] }
		for (position, row) in rows.enumerated() {
			let shifted: T = scores[row] - maximum
			work.terms[position] = T.exp(shifted)
		}
		let steps: T = T(friends)
		let shift: T = steps * maximum
		guard wantInclusion else {
			let rolled = Self.rollingSum(terms: work.terms, count: count, friends: friends, work: &work.backward)
			guard rolled > T.zero, rolled.isFinite else { return nil }
			let logRolled: T = T.log(rolled)
			let logLikelihood: T = friendTotal - shift - logRolled
			return (logLikelihood, friends)
		}
		let total = Self.inclusion(
			terms: work.terms, count: count, friends: friends, forward: &work.forward, backward: &work.backward,
			inclusion: &work.inclusion)
		guard total > T.zero, total.isFinite else { return nil }
		let logTotal: T = T.log(total)
		let logLikelihood: T = friendTotal - shift - logTotal
		return (logLikelihood, friends)
	}

	/// One group's Plackett-Luce log-likelihood: the product, over the ranked choices in order, of the chosen candidate's
	/// `exp(score)` over the sum of `exp(score)` across the candidates not yet taken.
	///
	/// The denominator of step *j* is the sum over the unranked candidates plus the ranked candidates from *j* on, built from
	/// the back by additions only, so nothing is subtracted and no precision is lost when early choices dominate. The same
	/// pass gives each candidate's expected count (its weight times the sum of the reciprocal denominators of the steps at
	/// which it was still available), which is what the gradient needs.
	private func rankingGroup(group: Int, scores: [T], work: inout Work) -> (logLikelihood: T, steps: Int)? {
		let rows = data.rows(ofGroup: group)
		let count = rows.count
		let steps = data.stepCount(group: group)
		guard steps > 0 else { return nil }
		var maximum: T = -T.infinity
		for row in rows { maximum = Swift.max(maximum, scores[row]) }
		guard maximum.isFinite else { return nil }
		let rankedCount = rows.reduce(0) { data.rowRank[$1] >= 0 ? $0 + 1 : $0 }
		var order = [Int](repeating: -1, count: rankedCount)
		for (position, row) in rows.enumerated() where data.rowRank[row] >= 0 { order[data.rowRank[row]] = position }
		if work.terms.count < count {
			work.terms = [T](repeating: T.zero, count: count)
			work.inclusion = work.terms
		}
		var unranked: T = T.zero
		for (position, row) in rows.enumerated() {
			let weight: T = T.exp(scores[row] - maximum)
			work.terms[position] = weight
			if data.rowRank[row] < 0 { unranked += weight }
		}
		let ranked = order.count
		var denominators = [T](repeating: T.zero, count: ranked)
		var running: T = unranked
		var step = ranked - 1
		while step >= 0 {
			running += work.terms[order[step]]
			denominators[step] = running
			step -= 1
		}
		var logLikelihood: T = T.zero
		var reciprocalSums = [T](repeating: T.zero, count: steps + 1)
		for step in 0..<steps {
			let denominator: T = denominators[step]
			guard denominator > T.zero, denominator.isFinite else { return nil }
			let shifted: T = scores[rows.lowerBound + order[step]] - maximum
			logLikelihood += shifted - T.log(denominator)
			reciprocalSums[step + 1] = reciprocalSums[step] + T(1) / denominator
		}
		work.taken = [Bool](repeating: false, count: count)
		for (position, row) in rows.enumerated() {
			let rank = data.rowRank[row]
			let available = rank < 0 ? steps : Swift.min(rank + 1, steps)
			work.inclusion[position] = work.terms[position] * reciprocalSums[available]
			work.taken[position] = rank >= 0 && rank < steps
		}
		return (logLikelihood, steps)
	}

	/// The sum, over every set of `friends` of the first `count` terms, of the product of the set's terms.
	static func rollingSum(terms: [T], count: Int, friends: Int, work: inout [T]) -> T {
		let width = friends + 1
		if work.count < width { work = [T](repeating: T.zero, count: width) }
		for j in 0..<width { work[j] = j == 0 ? T(1) : T.zero }
		for i in 0..<count {
			let value: T = terms[i]
			var j = Swift.min(i + 1, friends)
			while j >= 1 {
				let carried: T = value * work[j - 1]
				work[j] += carried
				j -= 1
			}
		}
		return work[friends]
	}

	/// The same sum, and for each term the chance it is in the set: the term times the sum over sets of `friends - 1` of
	/// the others, over the total.
	///
	/// A forward table gives the sums over the terms before each one; a rolling backward sum gives the sums over those
	/// after it; the two are combined for each term.
	static func inclusion(
		terms: [T], count: Int, friends: Int, forward: inout [T], backward: inout [T], inclusion: inout [T]
	) -> T {
		let width = friends + 1
		let needed = (count + 1) * width
		if forward.count < needed { forward = [T](repeating: T.zero, count: needed) }
		if backward.count < width { backward = [T](repeating: T.zero, count: width) }
		if inclusion.count < count { inclusion = [T](repeating: T.zero, count: count) }
		for j in 0..<width { forward[j] = j == 0 ? T(1) : T.zero }
		for i in 1...count {
			let value: T = terms[i - 1]
			let here = i * width
			let before = (i - 1) * width
			forward[here] = T(1)
			for j in 1..<width {
				let carried: T = value * forward[before + j - 1]
				forward[here + j] = forward[before + j] + carried
			}
		}
		let total: T = forward[count * width + friends]
		guard total > T.zero, total.isFinite else { return total }
		for j in 0..<width { backward[j] = j == 0 ? T(1) : T.zero }
		var i = count
		while i >= 1 {
			let value: T = terms[i - 1]
			let before = (i - 1) * width
			var without: T = T.zero
			for j in 0..<friends {
				let product: T = forward[before + j] * backward[friends - 1 - j]
				without += product
			}
			let numerator: T = value * without
			inclusion[i - 1] = numerator / total
			var j = friends
			while j >= 1 {
				let carried: T = value * backward[j - 1]
				backward[j] += carried
				j -= 1
			}
			i -= 1
		}
		return total
	}
}

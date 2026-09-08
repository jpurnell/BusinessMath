//
//  ClassifierEvaluation.swift
//  BusinessMath
//

import Foundation
import Numerics

/// Everything a set of scores and outcomes supports: discrimination, calibration and
/// the operating points between them.
///
/// ```swift
/// let predicted: [Double] = [0.1, 0.4, 0.35, 0.8, 0.7, 0.2, 0.9, 0.05, 0.6, 0.3]
/// let observed: [Bool] = [false, false, true, true, true, false, true, false, true, false]
///
/// if let evaluation = ClassifierEvaluation(scores: predicted, outcomes: observed) {
///     let area = evaluation.auc                                  // 0.96
///     let counts = evaluation.confusionMatrix(threshold: 0.5)     // 4 TP, 0 FP, 1 FN, 5 TN
///     let reliability = evaluation.calibration(buckets: 10)
///     print(area, counts.truePositives, reliability.brierScore)
/// }
/// ```
///
/// ## Domain-neutral on purpose
///
/// This lives in `Statistics/`, not under marketing. A response model, a credit
/// scorecard and a churn model are the same object — scores against a binary outcome —
/// and the evaluation does not care which produced it. Filing it under the first
/// discipline that needed it would have made the second one import marketing.
///
/// ## Why the initialiser is failable
///
/// A single outcome class has no AUC. The statistic is the probability that a randomly
/// chosen positive outscores a randomly chosen negative, and with no negatives there
/// are no such pairs — zero pairs, not an AUC of zero. Returning `nil` refuses the
/// question rather than answering a different one, which for an all-positive sample
/// would otherwise report a perfect or worthless model depending on the convention.
public struct ClassifierEvaluation<T: Real & Sendable & BinaryFloatingPoint>: Sendable {

	/// The scores, in the order supplied.
	public let scores: [T]

	/// The outcomes, in the order supplied.
	public let outcomes: [Bool]

	/// How many positives there are.
	public let positiveCount: Int

	/// How many negatives there are.
	public let negativeCount: Int

	/// Creates an evaluation, or `nil` when the data cannot support one.
	///
	/// - Parameters:
	///   - scores: One score per observation. Higher means more likely positive. Every
	///     score must be finite: a `NaN` has no position in the ordering the whole
	///     analysis rests on.
	///   - outcomes: One outcome per score, with both classes present.
	/// - Returns: `nil` for mismatched lengths, no data, a non-finite score, or a single
	///   outcome class.
	public init?(scores: [T], outcomes: [Bool]) {
		guard !scores.isEmpty, scores.count == outcomes.count else { return nil }
		guard scores.allSatisfy({ $0.isFinite }) else { return nil }
		let positives = outcomes.filter { $0 }.count
		let negatives = outcomes.count - positives
		guard positives > 0, negatives > 0 else { return nil }
		self.scores = scores
		self.outcomes = outcomes
		self.positiveCount = positives
		self.negativeCount = negatives
	}

	// MARK: - Discrimination

	/// The area under the ROC curve.
	public var auc: T { roc.area }

	/// The Kolmogorov–Smirnov statistic: the widest vertical gap between the two
	/// cumulative rates.
	///
	/// Where AUC summarises the whole curve, KS reports its single best operating point
	/// — the threshold at which the model separates the classes most sharply. Credit
	/// scorecards are conventionally judged on it for that reason: it names a cutoff,
	/// and AUC does not.
	public var ks: T {
		var widest: T = T.zero
		for point in roc.points {
			let gap: T = point.truePositiveRate - point.falsePositiveRate
			let size: T = gap < T.zero ? -gap : gap
			if size > widest { widest = size }
		}
		return widest
	}

	/// The ROC curve, with all tied scores consumed in a single step.
	public var roc: ROCCurve<T> {
		let order = (0..<scores.count).sorted { scores[$0] > scores[$1] }
		let positives: T = T(positiveCount)
		let negatives: T = T(negativeCount)

		var points: [ROCPoint<T>] = [ROCPoint(falsePositiveRate: T.zero,
											  truePositiveRate: T.zero,
											  threshold: T.infinity)]
		var area: T = T.zero
		var truePositives: T = T.zero
		var falsePositives: T = T.zero
		var previousTPR: T = T.zero
		var previousFPR: T = T.zero

		var index = 0
		while index < order.count {
			// Consume every observation at this score before emitting a vertex; see the
			// note on ties in `ROCCurve`.
			let threshold: T = scores[order[index]]
			var group = index
			while group < order.count, scores[order[group]] == threshold {
				if outcomes[order[group]] { truePositives += 1 } else { falsePositives += 1 }
				group += 1
			}
			index = group

			let tpr: T = truePositives / positives
			let fpr: T = falsePositives / negatives
			// Trapezoid: a tied group makes this segment diagonal, and its area is the
			// half-credit the Mann–Whitney definition gives a tied pair.
			let width: T = fpr - previousFPR
			let heights: T = tpr + previousTPR
			let slice: T = width * heights
			area += slice / 2
			points.append(ROCPoint(falsePositiveRate: fpr, truePositiveRate: tpr,
								   threshold: threshold))
			previousTPR = tpr
			previousFPR = fpr
		}
		return ROCCurve(points: points, area: area)
	}

	// MARK: - Operating points

	/// The counts produced by calling everything at or above `threshold` positive.
	///
	/// - Parameter threshold: The cutoff. Inclusive, matching the ROC's convention.
	/// - Returns: The four counts.
	public func confusionMatrix(threshold: T) -> ConfusionMatrix {
		var tp = 0, fp = 0, fn = 0, tn = 0
		for (score, outcome) in zip(scores, outcomes) {
			let predicted = score >= threshold
			switch (predicted, outcome) {
			case (true, true): tp += 1
			case (true, false): fp += 1
			case (false, true): fn += 1
			case (false, false): tn += 1
			}
		}
		return ConfusionMatrix(truePositives: tp, falsePositives: fp,
							   falseNegatives: fn, trueNegatives: tn)
	}

	// MARK: - Calibration

	/// A reliability curve over equal-width probability buckets, and the Brier score.
	///
	/// Equal-width rather than equal-count, because the question is whether a *stated*
	/// probability is honest — the buckets are intervals of the prediction, so an empty
	/// one means the model never made that claim rather than that the claim was wrong.
	///
	/// - Parameter buckets: How many intervals to divide `[0, 1]` into. Fewer than one
	///   yields an empty curve with the Brier score still computed.
	/// - Returns: The occupied buckets and the Brier score.
	public func calibration(buckets: Int) -> CalibrationCurve<T> {
		var squaredError: T = T.zero
		for (score, outcome) in zip(scores, outcomes) {
			let observed: T = outcome ? T(1) : T.zero
			let residual: T = score - observed
			squaredError += residual * residual
		}
		let brier: T = squaredError / T(scores.count)
		guard buckets > 0 else { return CalibrationCurve(points: [], brierScore: brier) }

		var totals = [T](repeating: T.zero, count: buckets)
		var hits = [T](repeating: T.zero, count: buckets)
		var counts = [Int](repeating: 0, count: buckets)
		for (score, outcome) in zip(scores, outcomes) {
			let scaled: T = score * T(buckets)
			var slot = Int(scaled)
			slot = Swift.min(Swift.max(slot, 0), buckets - 1)
			totals[slot] += score
			if outcome { hits[slot] += 1 }
			counts[slot] += 1
		}

		var points: [CalibrationPoint<T>] = []
		for slot in 0..<buckets where counts[slot] > 0 {
			let size: T = T(counts[slot])
			let predicted: T = totals[slot] / size
			let observed: T = hits[slot] / size
			points.append(CalibrationPoint(predictedRate: predicted,
										   observedRate: observed,
										   count: counts[slot]))
		}
		return CalibrationCurve(points: points, brierScore: brier)
	}

	// MARK: - Gains

	/// A gains table over equal-count buckets, highest scores first.
	///
	/// Equal-count rather than equal-width here, the opposite of ``calibration(buckets:)``
	/// and for the opposite reason: this answers "if we take the top tenth, what do we
	/// get?", which is a question about a population share and needs the buckets to be
	/// population shares.
	///
	/// - Parameter buckets: How many groups to divide the ranked data into. Clamped to
	///   at least one and at most the number of observations.
	/// - Returns: The table.
	public func gains(buckets: Int) -> GainsTable<T> {
		let wanted = Swift.min(Swift.max(buckets, 1), scores.count)
		let order = (0..<scores.count).sorted { scores[$0] > scores[$1] }
		let total: T = T(scores.count)
		let positives: T = T(positiveCount)

		var rows: [GainsRow<T>] = []
		var seen = 0
		var captured = 0
		for bucket in 1...wanted {
			// Boundaries from the bucket index rather than a running step, so rounding
			// cannot leave the last bucket short of the end of the data.
			let end = (scores.count * bucket) / wanted
			var inBucket = 0
			var positivesHere = 0
			while seen < end {
				if outcomes[order[seen]] { positivesHere += 1 }
				inBucket += 1
				seen += 1
			}
			captured += positivesHere
			let gain: T = T(captured) / positives
			let population: T = T(seen) / total
			let lift: T = population > T.zero ? gain / population : T.zero
			rows.append(GainsRow(bucket: bucket, count: inBucket, positives: positivesHere,
								 cumulativeGain: gain, cumulativePopulation: population,
								 lift: lift))
		}
		return GainsTable(rows: rows)
	}
}

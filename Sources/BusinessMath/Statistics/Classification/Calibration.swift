//
//  Calibration.swift
//  BusinessMath
//

import Foundation
import Numerics

/// One point of a reliability curve: what a bucket of scores predicted, against what
/// actually happened in it.
public struct CalibrationPoint<T: Real & Sendable>: Sendable {

	/// The mean predicted probability in the bucket.
	public let predictedRate: T

	/// The observed positive rate in the bucket.
	public let observedRate: T

	/// How many observations fell in it.
	public let count: Int

	/// Creates a point.
	///
	/// - Parameters:
	///   - predictedRate: Mean predicted probability.
	///   - observedRate: Observed positive rate.
	///   - count: Observations in the bucket.
	public init(predictedRate: T, observedRate: T, count: Int) {
		self.predictedRate = predictedRate
		self.observedRate = observedRate
		self.count = count
	}
}

/// A reliability curve and the scores that summarise it.
///
/// Calibration answers a different question from discrimination, and the difference is
/// the reason this has equal billing with ``ROCCurve``. AUC asks whether the model ranks
/// positives above negatives; calibration asks whether a predicted 0.3 happens three
/// times in ten. A model can be perfect at one and useless at the other — any monotone
/// transform of the scores leaves AUC untouched and destroys calibration — and which one
/// matters depends entirely on whether the number is used to rank or to price.
public struct CalibrationCurve<T: Real & Sendable>: Sendable {

	/// The occupied buckets, in increasing order of predicted rate.
	///
	/// Empty buckets are omitted rather than reported at zero. A reliability point with
	/// no observations behind it is a claim about cases that do not exist, and plotted
	/// naively it drags the curve to the floor.
	public let points: [CalibrationPoint<T>]

	/// The mean squared error of the probabilities, `mean((p − y)²)`.
	///
	/// A proper scoring rule: it is minimised only by the true probabilities, so unlike
	/// accuracy it cannot be improved by shading predictions toward the majority class.
	///
	/// ## It requires probabilities, and ``points`` does not
	///
	/// ``ClassifierEvaluation`` deliberately admits any finite score, because a raw margin
	/// or a log-odds is only ever *ordered* and the discrimination statistics need nothing
	/// more. The reliability curve survives that: a bucket's predicted rate is whatever the
	/// model claimed, whether or not the claim was a probability.
	///
	/// This number does not. `mean((p − y)²)` is a squared distance from zero or one, so on
	/// an unbounded score it is not a Brier score but a large squared residual, and past
	/// about `1.3e154` it overflows to `+infinity`.
	///
	/// That infinity is left as it is rather than converted to `nan`. It is arithmetically
	/// honest — the squared residual genuinely exceeds the representable range — and it sits
	/// at the **worst** end of a loss scale, so a caller ranking models by it puts the
	/// offending model last, which is the one place the value cannot flatter. A `nan` would
	/// be strictly worse here: `nan` compares false against everything, so it would make the
	/// ranking itself unspecified rather than merely extreme. Read the infinity as the
	/// signal that the scores were never probabilities, and calibrate them first.
	public let brierScore: T

	/// Creates a curve.
	///
	/// - Parameters:
	///   - points: The occupied buckets.
	///   - brierScore: The mean squared error of the probabilities.
	public init(points: [CalibrationPoint<T>], brierScore: T) {
		self.points = points
		self.brierScore = brierScore
	}
}

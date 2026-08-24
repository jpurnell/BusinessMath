//
//  EffectSize.swift
//  BusinessMath
//
//  Reading a finished two-arm test: effect size with an interval, and a p-value.
//

import Foundation
import Numerics

/// Observed counts from a finished two-arm test.
public struct ArmResults<T: Real & BinaryFloatingPoint & Sendable>: Sendable, Equatable {
	/// Observations in the control arm.
	public let controlObservations: Int
	/// Conversions in the control arm.
	public let controlConversions: Int
	/// Observations in the treatment arm.
	public let treatmentObservations: Int
	/// Conversions in the treatment arm.
	public let treatmentConversions: Int

	/// Creates a set of observed results.
	public init(
		controlObservations: Int, controlConversions: Int,
		treatmentObservations: Int, treatmentConversions: Int
	) {
		self.controlObservations = controlObservations
		self.controlConversions = controlConversions
		self.treatmentObservations = treatmentObservations
		self.treatmentConversions = treatmentConversions
	}
}

/// What a finished test showed.
///
/// The ``interval`` is the answer. ``pValue`` is reported because it is asked for, but
/// "is it significant" and "is it worth shipping" are different questions and only the
/// interval answers the second: it says how large the effect plausibly is, not merely
/// that it is probably not zero.
public struct ExperimentResult<T: Real & BinaryFloatingPoint & Sendable>: Sendable, Equatable {
	/// Treatment rate minus control rate, in the units of the measure.
	public let absoluteLift: T
	/// Absolute lift as a fraction of the control rate.
	public let relativeLift: T
	/// Confidence interval on the absolute lift, at the requested significance level.
	public let interval: ClosedRange<T>
	/// Two-sided p-value from the unpooled two-proportion z-test.
	public let pValue: T
	/// The z statistic the p-value came from.
	public let zStatistic: T
}

extension Experiment {

	/// Reads a finished test.
	///
	/// ```swift
	/// let design = Experiment<Double>.twoProportion(baseline: 0.50, minimumDetectableEffect: 0.05)
	/// let observed = ArmResults<Double>(
	///     controlObservations: 1565, controlConversions: 782,
	///     treatmentObservations: 1565, treatmentConversions: 861
	/// )
	/// let result = try design.analyze(observed, alpha: 0.05)
	/// // result.absoluteLift == 0.05048, interval == 0.01553...0.08542, pValue == 0.004636
	/// ```
	///
	/// - Note: The ``ExperimentResult/pValue`` here is a **p-value** — small values are
	///   evidence against the null. The deprecated ``pValue(obsA:convA:obsB:convB:)``
	///   returns `normSDist(|z|)`, which is the complement of a one-sided p-value and is
	///   never below 0.5. The two are not interchangeable.
	public func analyze(_ observed: ArmResults<T>, alpha: T) throws -> ExperimentResult<T> {
		let alphaTooLow = alpha <= T(0)
		let alphaTooHigh = alpha >= T(1)
		guard !alphaTooLow, !alphaTooHigh else {
			throw ExperimentError.invalidAlpha(Double(alpha))
		}

		try Self.validate(
			observations: observed.controlObservations,
			conversions: observed.controlConversions, arm: "control"
		)
		try Self.validate(
			observations: observed.treatmentObservations,
			conversions: observed.treatmentConversions, arm: "treatment"
		)

		let nControl = T(observed.controlObservations)
		let nTreatment = T(observed.treatmentObservations)
		let pControl = T(observed.controlConversions) / nControl
		let pTreatment = T(observed.treatmentConversions) / nTreatment

		let absoluteLift = pTreatment - pControl

		let relativeLift: T
		if pControl > T(0) {
			relativeLift = absoluteLift / pControl
		} else {
			relativeLift = T.infinity
		}

		let controlVariance = pControl * (T(1) - pControl) / nControl
		let treatmentVariance = pTreatment * (T(1) - pTreatment) / nTreatment
		let standardError = T.sqrt(controlVariance + treatmentVariance)

		let zStatistic: T
		let pValue: T
		if standardError > T(0) {
			let magnitude = absoluteLift.magnitude
			zStatistic = magnitude / standardError
			let upperTail = T(1) - normSDist(zScore: zStatistic)
			pValue = T(2) * upperTail
		} else {
			zStatistic = T(0)
			pValue = T(1)
		}

		let tailMass = alpha / T(2)
		let confidence = T(1) - tailMass
		let critical = normSInv(probability: confidence)
		let margin = critical * standardError
		let lower = absoluteLift - margin
		let upper = absoluteLift + margin

		return ExperimentResult(
			absoluteLift: absoluteLift,
			relativeLift: relativeLift,
			interval: lower...upper,
			pValue: pValue,
			zStatistic: zStatistic
		)
	}

	/// Rejects an arm that cannot be read: no observations, or more conversions than trials.
	private static func validate(observations: Int, conversions: Int, arm: String) throws {
		guard observations > 0 else {
			throw ExperimentError.emptyArm(arm: arm)
		}
		guard conversions <= observations else {
			throw ExperimentError.conversionsExceedObservations(
				arm: arm, conversions: conversions, observations: observations
			)
		}
		guard conversions >= 0 else {
			throw ExperimentError.conversionsExceedObservations(
				arm: arm, conversions: conversions, observations: observations
			)
		}
	}
}

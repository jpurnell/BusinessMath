//
//  Experiment.swift
//  BusinessMath
//
//  Two-arm experiment design. See project/plans/upcoming/v2.7.0_SCOPE.md.
//

import Foundation
import Numerics

/// Whether a test is one- or two-sided.
///
/// Two-sided is the default everywhere in this module. One-sided testing is offered
/// because it is legitimate when the direction is fixed in advance, and named
/// explicitly because it is the most common way an A/B test is made to look
/// significant after the fact.
public enum Tails: Int, Sendable, Hashable, Codable, CaseIterable {
	/// A one-sided test. The alternative hypothesis fixes the direction in advance.
	case one = 1
	/// A two-sided test. The default, and the right choice unless the direction was
	/// committed to before the data was seen.
	case two = 2
}

/// A refusal from experiment design or analysis.
///
/// Every case is a question with no correct answer rather than a value that could be
/// clamped. A design asking for 100% power has no finite sample size, and returning a
/// large integer instead of refusing would be the failure this module was written to
/// remove.
public enum ExperimentError: Error, Equatable, Sendable {
	/// Power must lie strictly between 0 and 1. Zero is not a test; one needs infinite data.
	case invalidPower(Double)
	/// Significance level must lie strictly between 0 and 1.
	case invalidAlpha(Double)
	/// The minimum detectable effect must be positive — there is no sample size that
	/// detects an effect of zero.
	case nonPositiveEffect(Double)
	/// A proportion outside `[0, 1]`, either the baseline itself or the treatment arm
	/// the baseline plus the effect implies.
	case invalidProportion(Double)
	/// A standard deviation must be positive for a two-mean design.
	case nonPositiveStandardDeviation(Double)
	/// An arm with no observations. Its rate is undefined, not zero.
	case emptyArm(arm: String)
	/// More conversions than observations in an arm.
	case conversionsExceedObservations(arm: String, conversions: Int, observations: Int)
	/// A per-arm sample size that is not positive.
	case nonPositiveSampleSize(Int)
}

/// A two-arm experiment design: what is being compared, and how large an effect the
/// design is built to detect.
///
/// The design is separate from the data. Create it from what you decided *before*
/// running the test — the baseline rate and the smallest effect worth acting on — then
/// ask it how much data you need, whether you have enough, or what a result means.
///
/// ```swift
/// let design = Experiment<Double>.twoProportion(baseline: 0.50, minimumDetectableEffect: 0.05)
/// let perArm = try design.sampleSizePerArm(power: 0.80, alpha: 0.05, tails: .two)
/// // perArm == 1565
/// ```
///
/// That figure matches R's `power.prop.test(p1 = 0.50, p2 = 0.55, power = 0.80)`, which
/// reports `n = 1564.672`, rounded up to whole observations.
///
/// - SeeAlso: ``sampleSizePerArm(power:alpha:tails:)``, ``analyze(_:alpha:)``
public struct Experiment<T: Real & BinaryFloatingPoint & Sendable>: Sendable {

	/// What the two arms are being compared on.
	public enum Kind: Sendable {
		/// Two proportions — a conversion rate, a click rate, a churn rate.
		case proportion(baseline: T)
		/// Two means, with a known or estimated standard deviation.
		case mean(baseline: T, standardDeviation: T)
	}

	/// What is being compared.
	public let kind: Kind

	/// The smallest effect the design is built to detect, in the units of the measure —
	/// an absolute difference in proportion, or a difference in means.
	public let minimumDetectableEffect: T

	/// Creates a design directly. Prefer ``twoProportion(baseline:minimumDetectableEffect:)``
	/// or ``twoMean(baseline:standardDeviation:minimumDetectableEffect:)``.
	public init(kind: Kind, minimumDetectableEffect: T) {
		self.kind = kind
		self.minimumDetectableEffect = minimumDetectableEffect
	}

	/// A design comparing two proportions.
	///
	/// - Parameters:
	///   - baseline: The control arm's expected rate, in `[0, 1]`.
	///   - minimumDetectableEffect: The smallest absolute difference worth detecting.
	public static func twoProportion(baseline: T, minimumDetectableEffect: T) -> Experiment {
		Experiment(kind: .proportion(baseline: baseline),
				   minimumDetectableEffect: minimumDetectableEffect)
	}

	/// A design comparing two means.
	///
	/// - Parameters:
	///   - baseline: The control arm's expected mean.
	///   - standardDeviation: The measure's standard deviation, assumed equal across arms.
	///   - minimumDetectableEffect: The smallest difference in means worth detecting.
	public static func twoMean(
		baseline: T, standardDeviation: T, minimumDetectableEffect: T
	) -> Experiment {
		Experiment(kind: .mean(baseline: baseline, standardDeviation: standardDeviation),
				   minimumDetectableEffect: minimumDetectableEffect)
	}
}

//
//  PowerAnalysis.swift
//  BusinessMath
//
//  Sizing, achieved power, and minimum detectable effect for a two-arm design.
//
//  Reference: the normal-approximation formulas used by R's `power.prop.test` and
//  `power.t.test`. Every documented figure below is reproducible there.
//

import Foundation
import Numerics

extension Experiment {

	// MARK: - Validation

	/// Validates power and significance level, which every entry point needs.
	private func validate(power: T?, alpha: T) throws {
		if let power {
			let tooLow = power <= T(0)
			let tooHigh = power >= T(1)
			guard !tooLow, !tooHigh else {
				throw ExperimentError.invalidPower(Double(power))
			}
		}
		let alphaTooLow = alpha <= T(0)
		let alphaTooHigh = alpha >= T(1)
		guard !alphaTooLow, !alphaTooHigh else {
			throw ExperimentError.invalidAlpha(Double(alpha))
		}
	}

	/// The two arm parameters, validated. Returns the control and treatment rates for a
	/// proportion design, or the baseline and standard deviation for a mean design.
	private func validatedEffect() throws -> T {
		guard minimumDetectableEffect > T(0) else {
			throw ExperimentError.nonPositiveEffect(Double(minimumDetectableEffect))
		}
		return minimumDetectableEffect
	}

	/// Control and treatment proportions, both validated to lie in `[0, 1]`.
	private func validatedProportions(baseline: T, effect: T) throws -> (control: T, treatment: T) {
		let belowZero = baseline < T(0)
		let aboveOne = baseline > T(1)
		guard !belowZero, !aboveOne else {
			throw ExperimentError.invalidProportion(Double(baseline))
		}
		let treatment = baseline + effect
		guard treatment <= T(1) else {
			throw ExperimentError.invalidProportion(Double(treatment))
		}
		return (baseline, treatment)
	}

	// MARK: - The critical value

	/// The two-tailed-or-one-tailed critical value for a significance level.
	///
	/// A one-sided test at `alpha` uses the same critical value as a two-sided test at
	/// `2 * alpha`, which is why the two agree in ``sampleSizePerArm(power:alpha:tails:)``.
	private func criticalValue(alpha: T, tails: Tails) -> T {
		let divisor = T(tails.rawValue)
		let tailMass = alpha / divisor
		let upperTail = T(1) - tailMass
		return normSInv(probability: upperTail)
	}

	// MARK: - Sample size

	/// The observations required **in each arm** to detect this design's effect.
	///
	/// ```swift
	/// let design = Experiment<Double>.twoProportion(baseline: 0.50, minimumDetectableEffect: 0.05)
	/// let perArm = try design.sampleSizePerArm(power: 0.80, alpha: 0.05, tails: .two)
	/// // perArm == 1565
	/// ```
	///
	/// - Parameters:
	///   - power: Probability of detecting the effect if it is real. Strictly in `(0, 1)`.
	///   - alpha: Significance level. Strictly in `(0, 1)`.
	///   - tails: One- or two-sided. Two-sided unless the direction was fixed in advance.
	/// - Returns: Observations per arm, rounded up. Total sample is twice this.
	/// - Throws: ``ExperimentError`` when the design has no finite answer.
	public func sampleSizePerArm(power: T, alpha: T, tails: Tails = .two) throws -> Int {
		try validate(power: power, alpha: alpha)
		let effect = try validatedEffect()

		let zAlpha = criticalValue(alpha: alpha, tails: tails)
		let zBeta = normSInv(probability: power)

		let exact: T
		switch kind {
		case let .proportion(baseline):
			let arms = try validatedProportions(baseline: baseline, effect: effect)
			exact = Self.proportionSampleSize(
				control: arms.control, treatment: arms.treatment,
				zAlpha: zAlpha, zBeta: zBeta
			)
		case let .mean(_, standardDeviation):
			guard standardDeviation > T(0) else {
				throw ExperimentError.nonPositiveStandardDeviation(Double(standardDeviation))
			}
			exact = Self.meanSampleSize(
				effect: effect, standardDeviation: standardDeviation,
				zAlpha: zAlpha, zBeta: zBeta
			)
		}

		let rounded = exact.rounded(.up)
		return Int(rounded)
	}

	/// Per-arm size for two proportions. The pooled term uses the average of the two
	/// rates under the null; the unpooled term uses each arm's own variance.
	private static func proportionSampleSize(
		control p1: T, treatment p2: T, zAlpha: T, zBeta: T
	) -> T {
		let pooled = (p1 + p2) / T(2)
		let pooledVariance = T(2) * pooled * (T(1) - pooled)
		let nullTerm = zAlpha * T.sqrt(pooledVariance)

		let controlVariance = p1 * (T(1) - p1)
		let treatmentVariance = p2 * (T(1) - p2)
		let alternativeVariance = controlVariance + treatmentVariance
		let alternativeTerm = zBeta * T.sqrt(alternativeVariance)

		let numerator = T.pow(nullTerm + alternativeTerm, 2)
		let delta = p2 - p1
		let denominator = delta * delta
		guard denominator > T(0) else { return T.infinity }
		return numerator / denominator
	}

	/// Per-arm size for two means, equal variances.
	private static func meanSampleSize(
		effect: T, standardDeviation: T, zAlpha: T, zBeta: T
	) -> T {
		let zSum = zAlpha + zBeta
		let zSquared = zSum * zSum
		let variance = standardDeviation * standardDeviation
		let numerator = T(2) * zSquared * variance
		let denominator = effect * effect
		guard denominator > T(0) else { return T.infinity }
		return numerator / denominator
	}

	// MARK: - Achieved power

	/// The power this design actually achieves at a given per-arm sample size.
	///
	/// ```swift
	/// let design = Experiment<Double>.twoProportion(baseline: 0.50, minimumDetectableEffect: 0.05)
	/// let power = try design.achievedPower(perArm: 1565, alpha: 0.05, tails: .two)
	/// // power == 0.800082, to six places
	/// ```
	///
	/// Use this on a test that has already run, or one you inherited, to find out what it
	/// was capable of detecting.
	public func achievedPower(perArm: Int, alpha: T, tails: Tails = .two) throws -> T {
		try validate(power: nil, alpha: alpha)
		guard perArm > 0 else { throw ExperimentError.nonPositiveSampleSize(perArm) }
		let effect = try validatedEffect()

		let zAlpha = criticalValue(alpha: alpha, tails: tails)
		let n = T(perArm)
		let rootN = T.sqrt(n)

		switch kind {
		case let .proportion(baseline):
			let arms = try validatedProportions(baseline: baseline, effect: effect)
			let pooled = (arms.control + arms.treatment) / T(2)
			let pooledVariance = T(2) * pooled * (T(1) - pooled)
			let nullTerm = zAlpha * T.sqrt(pooledVariance)

			let signal = rootN * effect
			let excess = signal - nullTerm

			let controlVariance = arms.control * (T(1) - arms.control)
			let treatmentVariance = arms.treatment * (T(1) - arms.treatment)
			let spread = T.sqrt(controlVariance + treatmentVariance)
			guard spread > T(0) else { return T(1) }
			return normSDist(zScore: excess / spread)

		case let .mean(_, standardDeviation):
			guard standardDeviation > T(0) else {
				throw ExperimentError.nonPositiveStandardDeviation(Double(standardDeviation))
			}
			let half = n / T(2)
			let scale = T.sqrt(half)
			let standardised = scale * effect / standardDeviation
			return normSDist(zScore: standardised - zAlpha)
		}
	}

	// MARK: - Minimum detectable effect

	/// The smallest effect a given per-arm sample size can detect at this power.
	///
	/// ```swift
	/// let design = Experiment<Double>.twoProportion(baseline: 0.50, minimumDetectableEffect: 0.05)
	/// let mde = try design.minimumDetectableEffect(perArm: 1565, power: 0.80, alpha: 0.05)
	/// // mde == 0.05, to three places — the design's own effect, recovered
	/// ```
	///
	/// The mean case is closed-form. The proportion case is not, because the null
	/// variance depends on the effect being solved for, so it is bisected — deterministic,
	/// and converged to `1e-12` or 200 iterations.
	public func minimumDetectableEffect(perArm: Int, power: T, alpha: T) throws -> T {
		try validate(power: power, alpha: alpha)
		guard perArm > 0 else { throw ExperimentError.nonPositiveSampleSize(perArm) }

		let zAlpha = criticalValue(alpha: alpha, tails: .two)
		let zBeta = normSInv(probability: power)
		let n = T(perArm)

		switch kind {
		case let .mean(_, standardDeviation):
			guard standardDeviation > T(0) else {
				throw ExperimentError.nonPositiveStandardDeviation(Double(standardDeviation))
			}
			let zSum = zAlpha + zBeta
			let ratio = T(2) / n
			return zSum * standardDeviation * T.sqrt(ratio)

		case let .proportion(baseline):
			let belowZero = baseline < T(0)
			let aboveOne = baseline > T(1)
			guard !belowZero, !aboveOne else {
				throw ExperimentError.invalidProportion(Double(baseline))
			}
			return Self.bisectEffect(
				baseline: baseline, target: n, zAlpha: zAlpha, zBeta: zBeta
			)
		}
	}

	/// Bisects for the effect whose required sample size equals `target`.
	///
	/// Required size falls monotonically as the effect grows, so a bisection on the
	/// effect is well-defined. The upper bound is the largest effect the baseline
	/// admits, `1 - baseline`.
	private static func bisectEffect(baseline: T, target: T, zAlpha: T, zBeta: T) -> T {
		var low = T(0)
		var high = T(1) - baseline
		guard high > T(0) else { return T(0) }

		let tolerance = T(1e-12)
		for _ in 0..<200 {
			let width = high - low
			guard width > tolerance else { break }
			let mid = (low + high) / T(2)
			let needed = proportionSampleSize(
				control: baseline, treatment: baseline + mid, zAlpha: zAlpha, zBeta: zBeta
			)
			// Larger effect, smaller requirement: if this effect needs more than we have,
			// the detectable effect is larger still.
			if needed > target {
				low = mid
			} else {
				high = mid
			}
		}
		return (low + high) / T(2)
	}
}

//
//  KaplanMeier.swift
//  BusinessMath
//

import Foundation
import Numerics

/// The product-limit estimator of a survival function under right censoring.
///
/// ```swift
/// let times: [Double] = [6, 7, 10, 15, 19, 25, 25, 28]
/// let events: [Bool] = [true, false, true, true, false, true, false, false]
/// if let estimate = KaplanMeier(times: times, events: events) {
///     let curve = estimate.curve
///     print(curve.survival(at: 12), curve.medianSurvival ?? -1)
/// }
/// ```
///
/// ## What censoring is, and why dropping it is the common mistake
///
/// A censored observation is one where the subject had not failed when observation
/// stopped — a subscription still running at the data cut, a patient still alive at the
/// end of the study. It carries real information: that subject survived *at least* that
/// long.
///
/// The tempting simplification is to drop those rows and take the empirical survival of
/// what remains. That biases every estimate downward, and it does so hardest where it
/// matters: the subjects still running at the cut are precisely the longest-lived ones,
/// so discarding them discards the right tail. Kaplan–Meier keeps them in the risk set
/// until the moment they leave it, contributing to every denominator up to their
/// censoring time and to no numerator.
///
/// ## Churn is default with a different noun
///
/// Nothing here is medical. A subscription cohort, a loan book and a clinical trial are
/// the same estimator; the reason this lives in `Statistics/Survival/` rather than under
/// marketing is that all three want it and none of them should have to import another's
/// domain to get it.
public struct KaplanMeier<T: Real & Sendable & BinaryFloatingPoint>: Sendable {

	/// Observation times, one per subject.
	public let times: [T]

	/// Whether each observation ended in a failure. `false` means right-censored.
	public let events: [Bool]

	/// Creates an estimator, or `nil` when the data cannot support one.
	///
	/// - Parameters:
	///   - times: Non-negative, finite durations.
	///   - events: `true` for an observed failure, `false` for right-censoring.
	/// - Returns: `nil` for mismatched lengths, no data, a negative or non-finite time,
	///   or no observed failures at all. The last is not a curve that stays at one — it
	///   is a study whose follow-up was too short to estimate anything, and saying so is
	///   better than returning a flat line that looks like immortality.
	public init?(times: [T], events: [Bool]) {
		guard !times.isEmpty, times.count == events.count else { return nil }
		guard times.allSatisfy({ $0.isFinite && $0 >= T.zero }) else { return nil }
		guard events.contains(true) else { return nil }
		self.times = times
		self.events = events
	}

	/// The estimated survival curve.
	///
	/// One step per distinct failure time. `S(tᵢ) = Π (1 − dⱼ/nⱼ)` over failure times up
	/// to `tᵢ`, with `dⱼ` the failures at `tⱼ` and `nⱼ` the subjects still at risk.
	///
	/// Standard errors are Greenwood's: `Var(S) = S² Σ dⱼ / (nⱼ(nⱼ − dⱼ))`. The term is
	/// skipped where `dⱼ = nⱼ`, which happens at the last step of an uncensored sample —
	/// survival is exactly zero there and its variance is zero, where the formula would
	/// divide by nothing.
	public var curve: SurvivalCurve<T> {
		var failureTimes: [T] = []
		for (time, event) in zip(times, events) where event {
			if !failureTimes.contains(where: { $0 == time }) { failureTimes.append(time) }
		}
		failureTimes.sort()

		var points: [SurvivalPoint<T>] = []
		var survival: T = T(1)
		var greenwood: T = T.zero
		for failure in failureTimes {
			// At risk means "had not yet failed or been censored", so a subject censored
			// exactly at this time is still counted here — it left at this time, not
			// before it.
			let atRisk = times.filter { $0 >= failure }.count
			var failures = 0
			for (time, event) in zip(times, events) where event && time == failure {
				failures += 1
			}
			guard atRisk > 0 else { continue }
			let risk: T = T(atRisk)
			let dead: T = T(failures)
			let survivors: T = risk - dead
			let factor: T = survivors / risk
			survival *= factor

			if atRisk > failures {
				let denominator: T = risk * survivors
				let increment: T = dead / denominator
				greenwood += increment
			}
			let variance: T = survival * survival * greenwood
			let error: T = variance > T.zero ? T.sqrt(variance) : T.zero
			points.append(SurvivalPoint(time: failure, survival: survival,
										standardError: error, atRisk: atRisk,
										events: failures))
		}
		return SurvivalCurve(points: points, sampleSize: times.count)
	}
}

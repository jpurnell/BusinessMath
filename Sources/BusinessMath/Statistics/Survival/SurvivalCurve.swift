//
//  SurvivalCurve.swift
//  BusinessMath
//

import Foundation
import Numerics

/// One step of a survival curve, at a time where something failed.
public struct SurvivalPoint<T: Real & Sendable>: Sendable {

	/// When.
	public let time: T

	/// The estimated probability of surviving beyond this time.
	public let survival: T

	/// Greenwood's standard error of ``survival``.
	public let standardError: T

	/// How many subjects were still under observation immediately before this time —
	/// the denominator of the step.
	public let atRisk: Int

	/// How many failed at this time.
	public let events: Int

	/// Creates a point.
	///
	/// - Parameters:
	///   - time: The event time.
	///   - survival: Estimated survival beyond it.
	///   - standardError: Greenwood's standard error.
	///   - atRisk: Subjects at risk immediately before.
	///   - events: Failures at this time.
	public init(time: T, survival: T, standardError: T, atRisk: Int, events: Int) {
		self.time = time
		self.survival = survival
		self.standardError = standardError
		self.atRisk = atRisk
		self.events = events
	}
}

/// A step-function survival curve, and the summaries read off it.
///
/// The curve is right-continuous and constant between event times: nothing is known to
/// change except where something was observed to change, which is what makes this a
/// non-parametric estimate rather than a fitted shape.
public struct SurvivalCurve<T: Real & Sendable>: Sendable {

	/// The steps, in increasing time order. Censoring times are not steps — they change
	/// the risk set without changing the estimate.
	public let points: [SurvivalPoint<T>]

	/// How many subjects the curve was built from.
	public let sampleSize: Int

	/// Creates a curve.
	///
	/// - Parameters:
	///   - points: The steps, in increasing time order.
	///   - sampleSize: How many subjects.
	public init(points: [SurvivalPoint<T>], sampleSize: Int) {
		self.points = points
		self.sampleSize = sampleSize
	}

	/// Survival beyond `time`.
	///
	/// - Parameter time: Any time.
	/// - Returns: One before the first event, then the value of the last step at or
	///   before `time`.
	public func survival(at time: T) -> T {
		var current: T = T(1)
		for point in points where point.time <= time {
			current = point.survival
		}
		return current
	}

	/// The first time at which estimated survival is at or below one half, or `nil`.
	///
	/// `nil` rather than the last observed time when the curve never gets there. Under
	/// heavy censoring a curve can end at 0.75, and reporting its final time as the
	/// median would state something the data cannot support — the honest answer is that
	/// follow-up was too short to see it.
	public var medianSurvival: T? {
		let half: T = T(1) / T(2)
		for point in points where point.survival <= half {
			return point.time
		}
		return nil
	}

	/// The area under the curve out to `horizon` — restricted mean survival time.
	///
	/// The expected time survived within a window, and the summary to prefer when the
	/// median does not exist. It is defined whatever the censoring does, because it
	/// only integrates the part of the curve that was actually observed.
	///
	/// - Parameter horizon: Where to stop integrating. Must be positive.
	/// - Returns: The area, or `nil` for a non-positive horizon.
	public func restrictedMean(horizon: T) -> T? {
		guard horizon > T.zero else { return nil }
		var area: T = T.zero
		var previousTime: T = T.zero
		var currentSurvival: T = T(1)
		for point in points {
			guard point.time < horizon else { break }
			let width: T = point.time - previousTime
			let slice: T = currentSurvival * width
			area += slice
			previousTime = point.time
			currentSurvival = point.survival
		}
		let remaining: T = horizon - previousTime
		let tail: T = currentSurvival * remaining
		return area + tail
	}
}

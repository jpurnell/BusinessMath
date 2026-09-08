//
//  AcquisitionCost.swift
//  BusinessMath
//

import Foundation
import Numerics

/// What a customer costs to acquire, read against what they are worth.
///
/// ```swift
/// if let metrics = AcquisitionMetrics(lifetimeValue: 266.67,
///                                     acquisitionCost: 150,
///                                     marginPerPeriod: 100) {
///     print(metrics.ratio)            // 1.78
///     print(metrics.paybackPeriods)   // 1.5
/// }
/// ```
///
/// ## The ratio is a comparison, not a verdict
///
/// A widely repeated rule holds that an LTV:CAC ratio of three is healthy. It is a
/// heuristic from a particular kind of venture-funded software business and it travels
/// badly: a grocer operating at 1.2 with a two-week payback is in a different and often
/// better position than a business at 4.0 with a three-year one. ``isProfitable`` reports
/// only whether the ratio exceeds one, which is the arithmetic; anything beyond that is a
/// judgement the caller's context has to make.
///
/// The ratio also inherits whatever ``CLVDefinition`` produced its numerator. A historic
/// CLV against a forward-looking cost is comparing a measurement with a forecast, and
/// gives a ratio that is too low for a young cohort by construction.
public struct AcquisitionMetrics<T: Real & Sendable>: Sendable {

	/// The lifetime value used as the numerator.
	public let lifetimeValue: T

	/// The acquisition cost.
	public let acquisitionCost: T

	/// Margin earned per period, used for the payback.
	public let marginPerPeriod: T

	/// `LTV / CAC`.
	public let ratio: T

	/// How many periods of margin it takes to recover the acquisition cost.
	///
	/// Undiscounted, and deliberately so: a payback period is a liquidity question —
	/// *how long is this cash out of the business* — and discounting it answers a
	/// different one. Where the time value matters, the ratio already carries it through
	/// the discounted CLV.
	public let paybackPeriods: T

	/// Whether the customer is worth more than they cost. The arithmetic only.
	public var isProfitable: Bool { ratio > T(1) }

	/// The value left after acquisition.
	public var netValue: T { lifetimeValue - acquisitionCost }

	/// Creates the metrics.
	///
	/// - Parameters:
	///   - lifetimeValue: What a customer is worth. See ``CLVDefinition`` — which
	///     definition produced this changes what the ratio means.
	///   - acquisitionCost: What they cost, strictly positive.
	///   - marginPerPeriod: Margin per period, strictly positive.
	/// - Returns: `nil` for a non-positive cost or margin. A ratio against zero cost is
	///   not an excellent ratio, it is an undefined one, and a payback against zero margin
	///   never arrives rather than arriving instantly.
	public init?(lifetimeValue: T, acquisitionCost: T, marginPerPeriod: T) {
		guard acquisitionCost > T.zero, acquisitionCost.isFinite else { return nil }
		guard marginPerPeriod > T.zero, marginPerPeriod.isFinite else { return nil }
		guard lifetimeValue.isFinite else { return nil }
		self.lifetimeValue = lifetimeValue
		self.acquisitionCost = acquisitionCost
		self.marginPerPeriod = marginPerPeriod
		self.ratio = lifetimeValue / acquisitionCost
		self.paybackPeriods = acquisitionCost / marginPerPeriod
	}
}

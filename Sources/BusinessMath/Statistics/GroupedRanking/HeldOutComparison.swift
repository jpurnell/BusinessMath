//
//  HeldOutComparison.swift
//  BusinessMath
//

import Foundation
import Numerics

/// One of the penalties a cross-validation may choose: keep the reference weights, or refit with a pull toward them.
public enum PenaltyChoice<T: Real & Sendable & BinaryFloatingPoint>: Sendable, Equatable {
	/// The reference weights unchanged: no refit.
	case reference
	/// Refit with this penalty (finite, not negative).
	case penalty(T)
}

/// Whether a refit ranked groups it never saw better than the reference weights did.
///
/// It states a fact about held-out groups: the two mean percentiles, their paired difference, and a bootstrap interval for
/// the difference over groups. It does **not** say whether to adopt anything. A caller's own policy (how big a move counts,
/// how many chosen candidates must carry a feature) sits on top of these figures and is deliberately not here.
public struct HeldOutComparison<T: Real & Sendable & BinaryFloatingPoint>: Sendable, Equatable {

	/// How many groups sat in each fold.
	public let foldSizes: [Int]

	/// The penalty chosen inside each fold, on that fold's training groups only.
	public let penalties: [PenaltyChoice<T>]

	/// How many held-out groups were compared (each was held out exactly once).
	public let groups: Int

	/// The reference weights' mean percentile over the held-out groups.
	public let referencePercentile: T

	/// The refit's mean percentile over the same groups.
	public let refitPercentile: T

	/// The reference weights' mean share of a group's chosen candidates inside its top *m*.
	public let referenceTopOwn: T

	/// The refit's.
	public let refitTopOwn: T

	/// Refit minus reference, in mean percentile, over held-out groups.
	public let difference: T

	/// The bootstrap standard deviation of the difference (resampling held-out groups); zero without resamples.
	public let spread: T

	/// The lower end of the bootstrap interval for the difference.
	public let lower: T

	/// The upper end of the bootstrap interval.
	public let upper: T

	/// The share of resamples the interval covers, for example `0.9`.
	public let level: T

	/// How many bootstrap resamples were drawn.
	public let resamples: Int

	/// Whether the interval for the difference lies wholly on one side of zero.
	public var intervalExcludesZero: Bool { lower > T.zero || upper < T.zero }

	/// Whether the lower end of the interval is above zero: the refit ranked held-out groups better by more than chance.
	public var refitBeatsReference: Bool { lower > T.zero }
}

/// The fitted multipliers' bootstrap intervals, from refitting on resamples of groups.
public struct BootstrapIntervals<T: Real & Sendable & BinaryFloatingPoint>: Sendable, Equatable {

	/// The lower end of the interval for each feature's multiplier.
	public let lower: [T]

	/// The upper end.
	public let upper: [T]

	/// The share of resamples the intervals cover.
	public let level: T

	/// How many resamples were fitted and used.
	public let resamples: Int

	/// How many resamples were dropped because their fit did not settle or they had nothing to compare.
	public let skipped: Int
}

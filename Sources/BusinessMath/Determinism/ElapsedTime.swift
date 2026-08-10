//
//  ElapsedTime.swift
//  BusinessMath
//

import Foundation

/// Converting a measured `Duration` to the `Double` seconds a report field expects.
///
/// ## Why elapsed time is not measured with `Date`
///
/// Several places in this library used to time an operation by taking `Date()` before and
/// after and subtracting. That reads naturally and is wrong: `Date` is *wall-clock* time,
/// which the operating system adjusts. An NTP correction, a manual clock change, or a
/// leap-second smear during the measured interval moves the second reading independently
/// of how long the work actually took. The failure is not theoretical — the clock can move
/// *backwards*, which makes the difference negative, and a benchmark that reports a
/// negative execution time is not merely imprecise, it is reporting something that cannot
/// have happened.
///
/// Injecting a ``WallClock`` would not have fixed this. It would have made the wrong
/// instrument testable. Elapsed time needs a *monotonic* source, and Swift's
/// `ContinuousClock` is exactly that: it counts forward, never jumps, and keeps running
/// while the machine is suspended.
///
/// ## Why the result is still a `Double`
///
/// `Duration` carries exact seconds and attoseconds, so the measurement itself loses
/// nothing. Public result types here — `RunResult.executionTime`,
/// `IntegerOptimizationResult.solveTime`, `PerformanceMetric.duration` — have always
/// published `TimeInterval` (that is, `Double`) seconds, and changing that would be an API
/// break unrelated to the correctness problem being fixed. So the conversion happens once,
/// at the reporting boundary, and nowhere else: arithmetic and comparisons stay in
/// `Duration` where they are exact.
extension Duration {

	/// This duration as `Double` seconds.
	///
	/// Use only where a value is being handed to an API that publishes `TimeInterval`.
	/// Comparing two durations, or accumulating them, should stay in `Duration`.
	var inSeconds: Double {
		let (seconds, attoseconds) = components
		return Double(seconds) + Double(attoseconds) * 1e-18
	}
}

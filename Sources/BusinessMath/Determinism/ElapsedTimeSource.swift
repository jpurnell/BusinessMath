//
//  ElapsedTimeSource.swift
//  BusinessMath
//

import Foundation

/// The monotonic counter a measurement reads, made injectable.
///
/// `ElapsedTime.swift` argues that a duration must come from a monotonic source rather than
/// from differencing two `Date` readings, and the code that measures durations here
/// follows that: it constructs a `ContinuousClock` and subtracts two of its instants.
/// That is correct, and it was also unreachable. A test that wanted a 50 ms measurement
/// had exactly one way to obtain one — sleep for 50 ms and hope the machine agreed. On a
/// loaded machine it does not: BusinessMath's own suite had a "fast" operation that slept
/// for 1 ms outlast a "slow" one that slept for 50 ms, because a sleep sets a floor on
/// elapsed time and no ceiling at all.
///
/// So this protocol does for elapsed time what ``WallClock`` does for timestamps, and
/// deliberately does not do it the same way. A `WallClock` vends a `Date`, which is the
/// wrong instrument for an interval whoever supplies it. This vends a reading of a
/// counter that only moves forward, and the only thing anyone is allowed to do with two
/// readings is subtract them.
///
/// ## What a test gains
///
/// The durations a profiler reports are the *input* to everything else it does — sorting,
/// thresholds, percentiles, statistics. Those are the behaviours worth asserting, and none
/// of them is a claim about how long the machine took. Supplying the durations directly
/// lets a test state the claim it actually has: given operations of 1 ms and 50 ms, the
/// 50 ms one sorts first. ``ManualElapsedTimeSource`` is how that is supplied.
///
/// This is not a licence to fake a benchmark. Where the elapsed time *is* the result —
/// "does this optimisation make the calculation faster" — the real source is the only
/// honest one, and it is the default everywhere.
///
/// ## Example
///
/// ```swift
/// // Production: the real monotonic counter, supplied by default.
/// let profiler = ModelProfiler()
///
/// // Test: durations the test chose, asserted exactly.
/// let time = ManualElapsedTimeSource()
/// let profiler = ModelProfiler(elapsedTime: time)
/// await profiler.measure(operation: "Slow") { time.advance(by: .milliseconds(50)) }
/// #expect(await profiler.report().operations[0].totalTime == 0.05)
/// ```
public protocol ElapsedTimeSource: Sendable {

	/// The current reading of the counter.
	///
	/// Meaningful only by comparison with another reading from the same source: the
	/// instant itself is measured from an unspecified origin, and only the difference
	/// between two readings is a duration. Successive readings never decrease.
	var now: ContinuousClock.Instant { get }
}

/// The real monotonic counter, and the default for every injection point in BusinessMath.
///
/// The only implementation that consults the operating system, so a type left to its
/// default measures exactly what it measured when it constructed a `ContinuousClock`
/// directly — the same clock, read the same way, with no arithmetic in between.
public struct SystemElapsedTimeSource: ElapsedTimeSource {

	/// Creates a source backed by the system's monotonic clock.
	public init() {}

	/// The current reading of `ContinuousClock`.
	public var now: ContinuousClock.Instant { ContinuousClock().now }
}

/// A counter that advances only when told to.
///
/// The sibling of `ManualWallClock`, and the reason this protocol exists. A test that
/// calls ``advance(by:)`` inside a measured block gives that measurement the exact
/// duration it names, so an assertion about ordering, a threshold, or a percentile is a
/// statement about the profiler rather than about the scheduler.
///
/// Readings begin at the moment the source is created and move only under `advance(by:)`,
/// which is what makes a measured block that does no work take precisely zero.
///
/// ## Example
///
/// ```swift
/// let time = ManualElapsedTimeSource()
/// let profiler = ModelProfiler(elapsedTime: time)
///
/// await profiler.measure(operation: "Fast") { time.advance(by: .milliseconds(1)) }
/// await profiler.measure(operation: "Slow") { time.advance(by: .milliseconds(50)) }
///
/// let report = await profiler.report(sortBy: .totalTime)
/// #expect(report.operations[0].operation == "Slow")
/// ```
///
/// - Note: Uses `@unchecked Sendable` with internal locking, so a source may be shared
///   across tasks and read from inside an actor.
// Justification: The single mutable stored property (reading) is protected by an NSLock; no unguarded access.
public final class ManualElapsedTimeSource: ElapsedTimeSource, @unchecked Sendable {

	/// The counter's current position, guarded by ``lock``.
	private var reading: ContinuousClock.Instant

	/// Serialises every read and every advance.
	private let lock = NSLock()

	/// Creates a source stopped at the present moment.
	public init() {
		self.reading = ContinuousClock().now
	}

	/// The current reading, unchanged since the last ``advance(by:)``.
	public var now: ContinuousClock.Instant {
		lock.lock()
		defer { lock.unlock() }
		return reading
	}

	/// Moves the counter forward.
	///
	/// Called inside a measured block, this is the duration that measurement will report.
	///
	/// - Parameter duration: How far to advance. A monotonic counter does not run
	///   backwards, so a negative duration is ignored rather than honoured.
	public func advance(by duration: Duration) {
		guard duration > .zero else { return }
		lock.lock()
		defer { lock.unlock() }
		reading = reading.advanced(by: duration)
	}
}

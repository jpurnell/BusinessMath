//
//  ZoneInvariance.swift
//  BusinessMathTests
//
//  A sweep for the failure that hid the coupon-grid defect: a test that builds its
//  inputs the same way the code reads them.
//

import Foundation
import Testing

/// Runs a computation under several time zones and reports whether the answer moved.
///
/// ## The failure this exists for
///
/// `CouponPeriod` stepped through a bond's coupon schedule with `Calendar.current`,
/// adding months to a wall-clock time. It survived a full test suite because
/// `ExcelBondFunctionTests` *also* builds its dates with `Calendar.current`: inputs
/// and code carried the same zone, it cancelled, and the suite agreed with itself in
/// every zone on earth.
///
/// ## The offset is not the problem; a *change* of offset is
///
/// Adding months to a wall-clock time round-trips to the correct instant whenever the
/// zone's UTC offset is the same on both dates — however large that offset is. This
/// sweep demonstrates it: with the defect reinstated, `Pacific/Niue` (−11),
/// `Asia/Tokyo` (+9) and `Asia/Kathmandu` (+5:45) all return the *right* grid, and
/// only `America/New_York` and `Australia/Lord_Howe` return a wrong one. Both of those
/// are the zones where the two coupon dates fall on opposite sides of a daylight-saving
/// transition, so the offset differs between them and the hour leaks into the date.
///
/// That is why a fixed-offset probe set would have passed the broken code, and why
/// the same asymmetry made `COUPPCD` correct and `COUPNCD` a day early on one bond:
/// November → May crosses into DST, May → November crosses back out and restores it.
///
/// That is a fixed point, not a test. No expected value in it could have failed,
/// however wrong the convention was. It took a caller outside the package — handing
/// in the UTC midnights an Excel date serial decodes to — to break the symmetry.
///
/// ## Why varying the input is not enough
///
/// The obvious repair is to build the dates in UTC instead. That catches this one
/// defect on a developer's machine and **catches nothing in CI**, which runs in UTC:
/// there the library's `Calendar.current` *is* UTC, and every zone-dependent
/// function looks correct. Detecting the dependence needs the zone itself varied.
///
/// So this forces `NSTimeZone.default`, which is what `Calendar.current` reads.
/// That is process-global mutable state — every suite using this must be
/// `.serialized`, and the helper restores the previous default even when the body
/// throws.
///
/// ## Inputs are built once, outside the sweep
///
/// ``expectInvariant(_:input:_:sourceLocation:)`` takes its input separately from
/// the closure that consumes it, and the separation is the point rather than a
/// convenience. Build a `Date` *inside* the swept closure and it moves with the zone
/// exactly as the code does — reproducing the original cancellation inside the tool
/// written to detect it. The signature makes the correct arrangement the easy one.
///
/// ```swift
/// let maturity = ZoneInvariance.utc(2011, 11, 15)   // once, outside
/// try ZoneInvariance.expectInvariant("COUPNUM", input: maturity) { maturity in
///     try CouponPeriod<Double>(settlement: settlement, maturity: maturity,
///                              frequency: .semiAnnual, basis: .thirty360).couponsRemaining
/// }
/// ```
///
/// ## What it cannot see
///
/// A calendar cached in a `let` at file scope — `Period.swift` and
/// `PeriodArithmetic.swift` each hold `private let cachedCalendar = Calendar.current`
/// — is resolved **once, at first touch**, and never re-reads the default. This sweep
/// will report such a function invariant while it is nothing of the kind: its answer
/// depends on whichever zone happened to be current the first time anything in the
/// process touched it, which makes it a function of test *ordering*. That is worse
/// than zone dependence, not better, and it has to be found by reading rather than
/// by sweeping. ``cachedCalendarSites`` records the two known ones.
enum ZoneInvariance {

	// MARK: - The probe set

	/// The zones swept, chosen so each one can fail differently.
	///
	/// | Zone | Offset | Why it is here |
	/// |---|---|---|
	/// | `UTC` | 0 | the baseline, and what CI runs in |
	/// | `America/New_York` | −5 / **−4** | negative offset **with** daylight saving — this is the probe that caught the coupon defect |
	/// | `Pacific/Niue` | −11 | extreme negative, **no** DST — a control: a large offset that does *not* break wall-clock arithmetic |
	/// | `Asia/Tokyo` | +9 | positive whole hour, no DST — the same control from the other side |
	/// | `Asia/Kathmandu` | +5:45 | a **45-minute** offset, which breaks any assumption that offsets are whole hours |
	/// | `Australia/Lord_Howe` | +10:30 / **+11** | a half-hour offset whose DST shift is itself **30 minutes**, not an hour |
	///
	/// **Two of the six change offset during the year, and they are the ones that
	/// matter.** A probe set of fixed-offset zones — however extreme — passes the
	/// broken coupon walk, because wall-clock month arithmetic round-trips correctly
	/// whenever the offset is stable. Keep at least two DST zones in any set derived
	/// from this one, and keep them in different hemispheres so a transition falls
	/// between any two dates a test is likely to pick.
	///
	/// The half-hour and 45-minute entries are there because an implementation can be
	/// correct for whole-hour offsets by accident. Nothing here is exotic; all six are
	/// inhabited.
	static let probeZones: [String] = [
		"UTC",
		"America/New_York",
		"Pacific/Niue",
		"Asia/Tokyo",
		"Asia/Kathmandu",
		"Australia/Lord_Howe",
	]

	/// File-scope calendars resolved once at first touch, which this sweep cannot see.
	///
	/// Recorded here rather than in prose so the list is somewhere a reader of the
	/// helper will find it. Both hold `Calendar.current`, which is a different thing
	/// from `gregorianUTC` in `DayCountConvention.swift` despite the similar name.
	static let cachedCalendarSites: [String] = [
		"Sources/BusinessMath/Time Series/Period.swift:17",
		"Sources/BusinessMath/Time Series/PeriodArithmetic.swift:56",
	]

	// MARK: - Building dates that do not move

	/// A date at UTC midnight — what an Excel serial decodes to, and what any caller
	/// speaking in calendar dates rather than instants will hand in.
	///
	/// Deliberately not `Calendar.current`: an input built through the same zone the
	/// code reads is the cancellation this file exists to prevent.
	static func utc(_ year: Int, _ month: Int, _ day: Int) -> Date {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
		var components = DateComponents()
		components.year = year; components.month = month; components.day = day
		guard let date = calendar.date(from: components) else {
			preconditionFailure("\(year)-\(month)-\(day) is not a date")
		}
		return date
	}

	// MARK: - The sweep

	/// One zone's answer.
	struct Reading<Value>: Sendable where Value: Sendable {
		let zone: String
		let value: Value
	}

	/// What a sweep found: every zone's answer, and whether they agreed.
	///
	/// Returned rather than asserted, so the assertion is written at the call site
	/// with `#expect`. A helper that records its own issues hides whether a test
	/// checks anything at all — which is the same defect, one level up, as the suite
	/// that could not fail.
	struct Sweep<Value: Equatable & Sendable>: Sendable, CustomStringConvertible {

		/// Every probe zone's answer, in probe order.
		let readings: [Reading<Value>]

		/// The readings that differ from the first zone's.
		var disagreeing: [Reading<Value>] {
			guard let first = readings.first else { return [] }
			return readings.filter { $0.value != first.value }
		}

		/// Whether every zone agreed.
		///
		/// A sweep with no readings is **not** invariant. An empty probe set proves
		/// nothing, and reporting it as a pass is how a check quietly stops checking.
		var isInvariant: Bool {
			!readings.isEmpty && disagreeing.isEmpty
		}

		/// The full table, for the failure message.
		var description: String {
			guard !readings.isEmpty else { return "no probe zone was available" }
			return readings
				.map { "  \($0.zone.padding(toLength: 20, withPad: " ", startingAt: 0)) \($0.value)" }
				.joined(separator: "\n")
		}
	}

	/// Runs `body` once under each probe zone, restoring the process default after.
	///
	/// A zone name the platform does not know is skipped rather than failed: the tz
	/// database is not identical everywhere, and a missing `Pacific/Niue` should not
	/// turn into a red test about something else.
	///
	/// - Parameters:
	///   - input: Built **before** the sweep and passed in, so it cannot move with
	///     the zone. See the note on the type — this separation is the point.
	///   - body: The computation under test.
	/// - Important: mutates `NSTimeZone.default`. The calling suite must be
	///   `.serialized`.
	static func sweep<Input: Sendable, Value: Equatable & Sendable>(
		input: Input,
		_ body: (Input) throws -> Value
	) rethrows -> Sweep<Value> {
		let original = NSTimeZone.default
		defer { NSTimeZone.default = original }

		var readings: [Reading<Value>] = []
		for name in probeZones {
			guard let zone = TimeZone(identifier: name) else { continue }
			NSTimeZone.default = zone
			readings.append(Reading(zone: name, value: try body(input)))
		}
		return Sweep(readings: readings)
	}
}

import Testing
import Foundation
@testable import BusinessMath

/// A `Date` backed by NaN must never end the process, on any platform.
///
/// Measured 2026-11-24: on Darwin and Swift 6.2.1 Linux, Foundation maps a NaN date to the Julian
/// epoch (`-211845110400` seconds from the reference date). On Linux with Swift 6.4.x,
/// swift-foundation traps instead (`Calendar.startOfDay(for:)`), or answers a calendar year of
/// `Int.max` that `FiscalCalendar.fiscalYear(for:)` then overflows on `+ 1`. The library is
/// pinned to the Darwin answer on every platform, so a caller gets the same value everywhere and
/// nothing traps. Each case runs in a child process so a trap fails one test instead of the run.
@Suite("A NaN Date never traps")
struct NaNDateSafetyTests {

	/// The value Darwin's Foundation answers for a NaN date.
	private static let julianEpoch: Double = -211_845_110_400

	@Test("Period.day(NaN) returns the Julian-epoch day and does not trap",
		  .requiresUnsanitizedRuntime)
	func periodDayOfNaN() async {
		#if os(macOS) || os(Linux)
		await #expect(processExitsWith: .success) {
			_ = Period.day(Date(timeIntervalSinceReferenceDate: .nan))
		}
		#endif
		let period = Period.day(Date(timeIntervalSinceReferenceDate: .nan))
		#expect(period == period, "a period is equal to itself")
		#expect(period.startDate.timeIntervalSinceReferenceDate == Self.julianEpoch)
	}

	@Test("FiscalCalendar answers a NaN date and does not trap",
		  .requiresUnsanitizedRuntime,
		  arguments: [
			FiscalCalendar.standard,
			FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30)),
			FiscalCalendar(yearEnd: MonthDay(month: 1, day: 1))
		  ])
	func fiscalCalendarOfNaN(calendar: FiscalCalendar) async {
		#if os(macOS) || os(Linux)
		await #expect(processExitsWith: .success) { [calendar] in
			let nan = Date(timeIntervalSinceReferenceDate: .nan)
			_ = calendar.fiscalYear(for: nan)
			_ = calendar.fiscalQuarter(for: nan)
			_ = calendar.fiscalHalf(for: nan)
			_ = calendar.fiscalMonth(for: nan)
		}
		#endif
		// The answer is the Julian-epoch date's answer, on every platform.
		let nan = Date(timeIntervalSinceReferenceDate: .nan)
		let epoch = Date(timeIntervalSinceReferenceDate: Self.julianEpoch)
		#expect(calendar.fiscalYear(for: nan) == calendar.fiscalYear(for: epoch))
		#expect(calendar.fiscalQuarter(for: nan) == calendar.fiscalQuarter(for: epoch))
		#expect(calendar.fiscalHalf(for: nan) == calendar.fiscalHalf(for: epoch))
		#expect(calendar.fiscalMonth(for: nan) == calendar.fiscalMonth(for: epoch))
	}

	@Test("A real date is unchanged by the guard")
	func realDateUnchanged() {
		let date = Date(timeIntervalSinceReferenceDate: 7.0e8)
		#expect(Period.day(date).startDate.timeIntervalSinceReferenceDate.isFinite)
		#expect(FiscalCalendar.standard.fiscalYear(for: date) >= 2020)
	}
}

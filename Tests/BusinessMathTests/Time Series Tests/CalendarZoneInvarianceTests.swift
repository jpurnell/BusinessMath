//
//  CalendarZoneInvarianceTests.swift
//  BusinessMathTests
//
//  The period and fiscal-calendar layer, swept across time zones.
//

import Testing
import Foundation
@testable import BusinessMath

/// A fiscal year is a property of a date, not of the machine reading it.
///
/// `FiscalCalendar.fiscalYear(for:)` read `Calendar.current`, so the same instant fell in
/// different fiscal years depending on where the process ran. Measured before the fix
/// with the sweep below: 1 January 2025 at UTC midnight is 2025 in Tokyo and **2024** in
/// New York, and 1 October 2025 is fiscal 2026 in Tokyo and **2025** in New York under a
/// September year-end.
///
/// Both failing dates are the day *after* a fiscal year-end. That is the worst place for
/// a calendar to disagree with itself: it is where a transaction moves between reporting
/// years, and where the disagreement is a whole year rather than a day.
///
/// This file is the companion to `BondClockZoneInvarianceTests`, which swept the Excel
/// bond path, and it borrows that file's discipline: prove the detector fires first.
/// - Important: `.serialized` because `ZoneInvariance.sweep` mutates `NSTimeZone.default`,
///   which its own documentation requires. Without it the sweeps race each other — and,
///   while `Period` still caches `Calendar.current`, they race `Period`'s one-time capture
///   too: `periodStartsAtUTCMidnight` below passed inside the suite and failed in
///   isolation, because a sweep had already set the default zone to UTC before `Period`
///   first looked. That order dependence disappears with the fix, since there is then no
///   capture to win.
@Suite("Calendar zone invariance", .serialized)
struct CalendarZoneInvarianceTests {

    // MARK: - The sweep has teeth

    /// Before trusting any sweep below, show this one fires.
    ///
    /// 15 November at UTC midnight is the 14th in New York and the 15th in Tokyo, so the
    /// day-of-month alone disagrees across the probe set. A detector never observed to
    /// fire is indistinguishable from one that cannot.
    @Test("A function that reads the zone is detected as reading it")
    func theSweepDetectsAKnownDependence() {
        let sweep = ZoneInvariance.sweep(input: ZoneInvariance.utc(2025, 11, 15)) { date in
            Calendar.current.component(.day, from: date)
        }
        #expect(!sweep.isInvariant, "the sweep is not exercising what it claims to:\n\(sweep)")
    }

    // MARK: - Fiscal years

    /// A calendar-year fiscal year is the same year in every zone.
    ///
    /// 1 January is the discriminating date: one day earlier in a westward zone is
    /// 31 December, which is the previous fiscal year.
    @Test("The standard fiscal year is the same in every zone", arguments: [
        (2025, 1, 1), (2024, 12, 31), (2025, 6, 30), (2025, 12, 31)
    ])
    func standardFiscalYearIsZoneInvariant(date: (Int, Int, Int)) {
        let (y, m, d) = date
        let sweep = ZoneInvariance.sweep(input: ZoneInvariance.utc(y, m, d)) { instant in
            FiscalCalendar.standard.fiscalYear(for: instant)
        }
        #expect(sweep.isInvariant, "\(y)-\(m)-\(d) fell in different fiscal years:\n\(sweep)")
    }

    /// A September year-end moves the discriminating date to 1 October.
    @Test("A September fiscal year is the same in every zone", arguments: [
        (2025, 10, 1), (2025, 9, 30), (2025, 1, 1)
    ])
    func septemberFiscalYearIsZoneInvariant(date: (Int, Int, Int)) throws {
        let (y, m, d) = date
        let yearEnd = MonthDay(month: 9, day: 30)
        let calendar = FiscalCalendar(yearEnd: yearEnd)
        let sweep = ZoneInvariance.sweep(input: ZoneInvariance.utc(y, m, d)) { instant in
            calendar.fiscalYear(for: instant)
        }
        #expect(sweep.isInvariant, "\(y)-\(m)-\(d) fell in different fiscal years:\n\(sweep)")
    }

    /// The fiscal quarter has the same requirement, at the same boundaries.
    @Test("The fiscal quarter is the same in every zone", arguments: [
        (2025, 1, 1), (2025, 4, 1), (2025, 7, 1), (2025, 10, 1)
    ])
    func fiscalQuarterIsZoneInvariant(date: (Int, Int, Int)) {
        let (y, m, d) = date
        let sweep = ZoneInvariance.sweep(input: ZoneInvariance.utc(y, m, d)) { instant in
            FiscalCalendar.standard.fiscalQuarter(for: instant)
        }
        #expect(sweep.isInvariant, "\(y)-\(m)-\(d) fell in different fiscal quarters:\n\(sweep)")
    }

    // MARK: - Periods

    /// A period's boundaries are a property of the period, not of the reader.
    ///
    /// - Note: `Period` caches its calendar in a module-level `let`, captured once at
    ///   first use, so a sweep that mutates `NSTimeZone.default` cannot move it — this
    ///   assertion passed even before the fix. It is here for the stored-instant check
    ///   below, which is what actually detects the dependence.
    @Test("Period boundaries are the same in every zone")
    func periodBoundariesAreZoneInvariant() {
        let quarter = Period.quarter(year: 2025, quarter: 1)
        let starts = ZoneInvariance.sweep(input: quarter) { $0.startDate }
        let ends = ZoneInvariance.sweep(input: quarter) { $0.endDate }
        #expect(starts.isInvariant, "start moved:\n\(starts)")
        #expect(ends.isInvariant, "end moved:\n\(ends)")
    }

    /// The check the sweep cannot make: a period starts at midnight **UTC**.
    ///
    /// A cached `Calendar.current` is invisible to a zone sweep, because it is captured
    /// once and never re-read. What it is not invisible to is the stored instant: under
    /// `Calendar.current` in New York, Q1 2025 began at `2025-01-01 05:00:00 +0000` —
    /// local midnight, five hours late, and a different instant on every developer's
    /// machine. Under a fixed Gregorian UTC calendar it is midnight UTC everywhere.
    @Test("A period begins at midnight UTC, not at the reader's midnight")
    func periodStartsAtUTCMidnight() throws {
        var utc = Calendar(identifier: .gregorian)
        // Justification: a fixed identifier, and this is the expectation being asserted.
        utc.timeZone = try #require(TimeZone(identifier: "UTC"))

        for quarter in 1...4 {
            let period = Period.quarter(year: 2025, quarter: quarter)
            let parts = utc.dateComponents([.hour, .minute, .second], from: period.startDate)
            let atMidnight = parts.hour == 0 && parts.minute == 0 && parts.second == 0
            #expect(atMidnight,
                    "Q\(quarter) 2025 starts at \(period.startDate), i.e. \(parts.hour ?? -1):\(parts.minute ?? -1) UTC, not midnight")
        }
    }
}

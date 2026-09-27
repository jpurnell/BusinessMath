//
//  DurationCompatTests.swift
//  BusinessMathTests
//
//  Fourteen never-executed members: the whole `CompatDuration` shim, its clock, and the
//  `Duration` bridge.
//
//  A units shim has one characteristic failure — a conversion factor off by a thousand —
//  and it is invisible from inside, because every value in the file agrees with every other
//  value in the file. So the oracle is **the standard library's own `Duration`**, which the
//  shim exists to mirror and therefore cannot be checked against itself.
//
//  Every factor matched.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Duration shim agrees with Swift.Duration")
struct DurationCompatTests {

    /// Nanoseconds from a standard-library `Duration`, used as the external reference.
    private func nanoseconds(_ duration: Duration) -> Int64 {
        let components = duration.components
        return components.seconds * 1_000_000_000 + Int64(components.attoseconds / 1_000_000_000)
    }

    /// Each factory against the `Duration` case it mirrors. A shim that multiplied
    /// microseconds by 1,000,000 instead of 1,000 would be self-consistent and wrong.
    @Test("Factories_MatchTheStandardLibrary") func factoriesMatchTheStandardLibrary() {
        #expect(nanoseconds(CompatDuration.seconds(1).duration) == nanoseconds(.seconds(1)))
        #expect(nanoseconds(CompatDuration.seconds(3).duration) == nanoseconds(.seconds(3)))
        #expect(nanoseconds(CompatDuration.milliseconds(1).duration) == nanoseconds(.milliseconds(1)))
        #expect(nanoseconds(CompatDuration.microseconds(1).duration) == nanoseconds(.microseconds(1)))

        // And the absolute values, so a matched pair of wrong factors cannot pass.
        #expect(nanoseconds(CompatDuration.seconds(1).duration) == 1_000_000_000)
        #expect(nanoseconds(CompatDuration.milliseconds(1).duration) == 1_000_000)
        #expect(nanoseconds(CompatDuration.microseconds(1).duration) == 1_000)
        #expect(nanoseconds(CompatDuration(nanoseconds: 1).duration) == 1)
        #expect(nanoseconds(CompatDuration(nanoseconds: 1_500).duration) == 1_500)
    }

    /// The three ways into the shim from a `Duration` all agree, and none loses precision.
    @Test("BridgesRoundTrip") func bridgesRoundTrip() {
        let original = Duration.milliseconds(1_234)
        let expected = nanoseconds(original)
        #expect(nanoseconds(original.compat.duration) == expected, "the .compat property")
        #expect(nanoseconds(CompatDuration.from(original).duration) == expected, "the static factory")
        #expect(nanoseconds(CompatDuration(original).duration) == expected, "the initialiser")
    }

    @Test("Subtraction") func subtraction() {
        let five = CompatDuration.seconds(5)
        let two = CompatDuration.seconds(2)
        #expect(nanoseconds((five - two).duration) == 3_000_000_000)
        #expect(nanoseconds((two - five).duration) == -3_000_000_000, "and it goes negative")
        #expect(nanoseconds((five - five).duration) == 0)
    }

    /// Ordering has to hold *across* units, which is where a factor error shows up as a
    /// comparison that is merely surprising rather than obviously broken.
    @Test("OrderingHoldsAcrossUnits") func orderingHoldsAcrossUnits() {
        #expect(CompatDuration.seconds(2) < CompatDuration.seconds(5))
        #expect(!(CompatDuration.seconds(5) < CompatDuration.seconds(2)))
        #expect(!(CompatDuration.seconds(5) < CompatDuration.seconds(5)), "strict")

        // 1 ms is 1,000 µs, so it sits between 999 µs and 1,001 µs.
        #expect(CompatDuration.microseconds(999) < CompatDuration.milliseconds(1))
        #expect(CompatDuration.milliseconds(1) < CompatDuration.microseconds(1_001))
        #expect(!(CompatDuration.milliseconds(1) < CompatDuration.microseconds(1_000)),
                "and is not less than exactly 1,000 µs")
    }

    /// The clock advances across an awaited sleep.
    ///
    /// Deliberately **no assertion on elapsed time**: wall-clock durations are unreliable in
    /// a parallel test runner, and a bound tight enough to be meaningful is also tight enough
    /// to fail on a loaded machine. Monotonicity is the property that holds regardless.
    @Test("ClockAdvances") func clockAdvances() async throws {
        let clock = CompatClock()
        let start = clock.now()
        try await Task.compatSleep(for: .milliseconds(1))
        let end = clock.now()
        #expect(nanoseconds((end - start).duration) > 0, "time moved forward")
    }
}

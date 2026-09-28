//
//  ContaminatedTrendTests.swift
//  BusinessMathTests
//
//  Trend detection classified its slope with a three-way chain:
//
//      if abs(slope) < 0.1 { .flat }
//      else if slope > 0   { .upward }
//      else                { .downward }
//
//  A `nan` slope fails the first two comparisons — both are false — and lands in the `else`,
//  which is not "the remaining case" but "everything that is not the first two". So a window
//  containing a `nan` was reported as a **downward trend**.
//
//  The confidence made it worse. It is clamped with `Swift.max(0, Swift.min(1, rSquared))`,
//  and `Swift.min(1.0, .nan)` returns **1.0** — the clamp converts an unusable R² into
//  *maximum* confidence rather than none. Measured before the fix, on a window with one NaN:
//
//      direction = .downward, confidence = 1.0
//
//  Maximum confidence in a specific direction, computed from data that supports neither.
//
//  `TrendDirection` has only `.upward`, `.downward` and `.flat` — adding an `.unknown` case
//  would break exhaustive switches in consumers — so the fix works inside the existing API:
//  an unusable window reports `.flat` with zero confidence, which together say "nothing
//  detected" rather than asserting a direction nobody can support.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Trend detection on a contaminated window")
struct ContaminatedTrendTests {

    private func trends(_ values: [Double], window: Int = 5) async throws -> [TrendDetection] {
        let stream = AsyncStream<Double> { continuation in
            for v in values { continuation.yield(v) }
            continuation.finish()
        }
        var out: [TrendDetection] = []
        for try await t in stream.detectTrend(window: window) { out.append(t) }
        return out
    }

    /// The headline: a contaminated window must not assert a direction.
    @Test("ContaminatedWindow_DoesNotReportADownwardTrend")
    func contaminatedWindowDoesNotReportADownwardTrend() async throws {
        let rising: [Double] = [1, 2, 3, .nan, 5, 6, 7]
        let detected = try await trends(rising)
        let last = try #require(detected.last)
        #expect(last.direction != .downward,
                "a NaN slope fell into the else branch; got \(last.direction)")
    }

    /// And must not claim confidence in it.
    @Test("ContaminatedWindow_HasNoConfidence")
    func contaminatedWindowHasNoConfidence() async throws {
        let rising: [Double] = [1, 2, 3, .nan, 5, 6, 7]
        let detected = try await trends(rising)
        let last = try #require(detected.last)
        #expect(!(last.confidence > 0.5),
                "clamping turned an unusable R² into \(last.confidence)")
    }

    /// Control: a clean rising series still reads as upward with real confidence.
    @Test("CleanRisingSeries_Unchanged")
    func cleanRisingSeriesUnchanged() async throws {
        let rising: [Double] = [1, 2, 3, 4, 5, 6, 7]
        let detected = try await trends(rising)
        let last = try #require(detected.last)
        #expect(last.direction == .upward)
        #expect(last.confidence > 0.9, "got \(last.confidence)")
        #expect(abs(last.slope - 1.0) < 1e-9, "got \(last.slope)")
    }

    /// Control: a clean falling series still reads as downward, so the fix has not simply
    /// removed the branch the NaN was landing in.
    @Test("CleanFallingSeries_StillDownward")
    func cleanFallingSeriesStillDownward() async throws {
        let falling: [Double] = [7, 6, 5, 4, 3, 2, 1]
        let detected = try await trends(falling)
        let last = try #require(detected.last)
        #expect(last.direction == .downward)
        #expect(last.confidence > 0.9)
    }

    /// Control: a genuinely flat series is still flat.
    @Test("CleanFlatSeries_StillFlat")
    func cleanFlatSeriesStillFlat() async throws {
        let flat: [Double] = [5, 5, 5, 5, 5, 5, 5]
        let detected = try await trends(flat)
        let last = try #require(detected.last)
        #expect(last.direction == .flat)
    }
}

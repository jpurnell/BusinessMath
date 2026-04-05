//
//  TimestampedTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-05.
//

import Testing
import Foundation
@testable import BusinessMath

/// Tests for Timestamped<T> streaming type (Phase 2.5 — Gap 1)
///
/// Following TDD:
/// - RED: Write failing tests first
/// - GREEN: Implement to make tests pass
/// - REFACTOR: Clean up implementation
@Suite("Timestamped Tests")
struct TimestampedTests {

    // MARK: - Timestamped Struct Tests

    @Test("Create Timestamped with explicit timestamp")
    func createWithExplicitTimestamp() {
        let now = ContinuousClock.now
        let ts = Timestamped(value: 42.0, timestamp: now)

        #expect(abs(ts.value - 42.0) < 1e-10)
        #expect(ts.timestamp == now)
    }

    @Test("Create Timestamped with default timestamp")
    func createWithDefaultTimestamp() {
        let before = ContinuousClock.now
        let ts = Timestamped(value: 99.5)
        let after = ContinuousClock.now

        #expect(abs(ts.value - 99.5) < 1e-10)
        #expect(ts.timestamp >= before)
        #expect(ts.timestamp <= after)
    }

    @Test("Timestamped preserves generic value types")
    func genericValueTypes() {
        let intTs = Timestamped(value: 7)
        #expect(intTs.value == 7)

        let stringTs = Timestamped(value: "heartbeat")
        #expect(stringTs.value == "heartbeat")

        let arrayTs = Timestamped(value: [1.0, 2.0, 3.0])
        #expect(arrayTs.value.count == 3)
    }

    @Test("Timestamped with Double values for HRV use case")
    func doubleValuesForHRV() {
        // Typical RR intervals in milliseconds
        let rrIntervals = [832.0, 845.0, 812.0, 798.0, 856.0]
        let timestamps = rrIntervals.map { Timestamped(value: $0) }

        #expect(timestamps.count == 5)
        for (i, ts) in timestamps.enumerated() {
            #expect(abs(ts.value - rrIntervals[i]) < 1e-10)
        }
    }

    // MARK: - AsyncTimestampedSequence Tests

    @Test("Timestamped operator wraps stream elements with timestamps")
    func timestampedOperator() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let stream = AsyncValueStream(values)

        var results: [Timestamped<Double>] = []
        for try await ts in stream.timestamped() {
            results.append(ts)
        }

        #expect(results.count == 5)
        for (i, ts) in results.enumerated() {
            #expect(abs(ts.value - values[i]) < 1e-10)
        }
    }

    @Test("Timestamped operator preserves element count")
    func preservesElementCount() async throws {
        let values = Array(1...100).map { Double($0) }
        let stream = AsyncValueStream(values)

        var count = 0
        for try await _ in stream.timestamped() {
            count += 1
        }

        #expect(count == 100)
    }

    @Test("Timestamped operator produces monotonically non-decreasing timestamps")
    func monotonicTimestamps() async throws {
        let values = [10.0, 20.0, 30.0, 40.0, 50.0]
        let stream = AsyncValueStream(values)

        var timestamps: [ContinuousClock.Instant] = []
        for try await ts in stream.timestamped() {
            timestamps.append(ts.timestamp)
        }

        #expect(timestamps.count == 5)
        for i in 1..<timestamps.count {
            #expect(timestamps[i] >= timestamps[i - 1])
        }
    }

    @Test("Timestamped operator on empty stream returns no elements")
    func emptyStream() async throws {
        let values: [Double] = []
        let stream = AsyncValueStream(values)

        var count = 0
        for try await _ in stream.timestamped() {
            count += 1
        }

        #expect(count == 0)
    }

    // MARK: - Numerical Stability Tests

    @Test("Timestamped with very small values (1e-15)")
    func verySmallValues() {
        let tiny = 1e-15
        let ts = Timestamped(value: tiny)

        #expect(abs(ts.value - tiny) < 1e-25)
        #expect(ts.value != 0.0)
    }

    @Test("Timestamped with very large values (1e15)")
    func veryLargeValues() {
        let huge = 1e15
        let ts = Timestamped(value: huge)

        #expect(abs(ts.value - huge) < 1e5)
    }

    @Test("Timestamped with NaN value stores it without crashing")
    func nanValue() {
        let ts = Timestamped(value: Double.nan)

        #expect(ts.value.isNaN)
    }

    @Test("Timestamped with Infinity value stores it without crashing")
    func infinityValue() {
        let posInf = Timestamped(value: Double.infinity)
        let negInf = Timestamped(value: -Double.infinity)

        #expect(posInf.value.isInfinite)
        #expect(posInf.value > 0)
        #expect(negInf.value.isInfinite)
        #expect(negInf.value < 0)
    }

    // MARK: - Property-Based Tests

    @Test("timestamped() output count always equals input count",
          arguments: [0, 1, 10, 100, 1000])
    func outputCountEqualsInputCount(size: Int) async throws {
        let values = (0..<size).map { Double($0) }
        let stream = AsyncValueStream(values)

        var count = 0
        for try await _ in stream.timestamped() {
            count += 1
        }

        #expect(count == size)
    }

    @Test("timestamped() preserves value ordering")
    func preservesValueOrdering() async throws {
        let values = [3.0, 1.0, 4.0, 1.0, 5.0, 9.0, 2.0, 6.0]
        let stream = AsyncValueStream(values)

        var results: [Double] = []
        for try await ts in stream.timestamped() {
            results.append(ts.value)
        }

        #expect(results.count == values.count)
        for i in 0..<values.count {
            #expect(abs(results[i] - values[i]) < 1e-10)
        }
    }

    // MARK: - Stress Tests

    @Test("Large stream (100_000 elements) timestamps efficiently",
          .timeLimit(.minutes(1)))
    func largeStreamStress() async throws {
        let values = (0..<100_000).map { Double($0) }
        let stream = AsyncValueStream(values)

        var count = 0
        for try await ts in stream.timestamped() {
            // Verify the value is present (not silently dropped)
            _ = ts.value
            count += 1
        }

        #expect(count == 100_000)
    }
}

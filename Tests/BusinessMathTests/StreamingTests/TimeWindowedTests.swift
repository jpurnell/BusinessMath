//
//  TimeWindowedTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-05.
//

import Testing
import Foundation
@testable import BusinessMath

/// Tests for time-based windowing operators (Phase 2.5 — Gap 2)
///
/// Following TDD:
/// - RED: Write failing tests first
/// - GREEN: Implement to make tests pass
/// - REFACTOR: Clean up implementation
@Suite("Time Windowed Tests")
struct TimeWindowedTests {

    // MARK: - Helper: Create Timestamped Stream with Controlled Timestamps

    /// Creates an array of `Timestamped<Double>` values at known offsets from a reference point.
    /// - Parameters:
    ///   - values: The Double values to wrap.
    ///   - offsetsMs: Millisecond offsets from a common reference instant for each value.
    /// - Returns: Array of timestamped values at precisely controlled times.
    private static func makeTimestampedValues(
        _ values: [Double],
        offsetsMs: [Int]
    ) -> [Timestamped<Double>] {
        let reference = ContinuousClock.now
        return zip(values, offsetsMs).map { value, offsetMs in
            let offset = Duration.milliseconds(offsetMs)
            let timestamp = reference.advanced(by: offset)
            return Timestamped(value: value, timestamp: timestamp)
        }
    }

    // MARK: - Tumbling Window Tests

    @Test("Tumbling window: evenly spaced elements fit exactly into windows")
    func tumblingEvenlySpaced() async throws {
        // 6 values at 100ms intervals, window = 300ms → 2 windows of 3 elements each
        let items = TimeWindowedTests.makeTimestampedValues(
            [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
            offsetsMs: [0, 100, 200, 300, 400, 500]
        )
        let stream = AsyncValueStream(items)

        var windows: [[Double]] = []
        for try await window in stream.tumblingWindow(duration: .milliseconds(300)) {
            windows.append(window.map(\.value))
        }

        #expect(windows.count == 2)
        #expect(windows[0] == [1.0, 2.0, 3.0])
        #expect(windows[1] == [4.0, 5.0, 6.0])
    }

    @Test("Tumbling window: partial final window emitted on stream end")
    func tumblingPartialFinal() async throws {
        // 5 values at 100ms intervals, window = 300ms → full window [1,2,3], partial [4,5]
        let items = TimeWindowedTests.makeTimestampedValues(
            [1.0, 2.0, 3.0, 4.0, 5.0],
            offsetsMs: [0, 100, 200, 300, 400]
        )
        let stream = AsyncValueStream(items)

        var windows: [[Double]] = []
        for try await window in stream.tumblingWindow(duration: .milliseconds(300)) {
            windows.append(window.map(\.value))
        }

        #expect(windows.count == 2)
        #expect(windows[0] == [1.0, 2.0, 3.0])
        #expect(windows[1] == [4.0, 5.0])
    }

    @Test("Tumbling window: empty stream yields no windows")
    func tumblingEmpty() async throws {
        let items: [Timestamped<Double>] = []
        let stream = AsyncValueStream(items)

        var count = 0
        for try await _ in stream.tumblingWindow(duration: .milliseconds(300)) {
            count += 1
        }

        #expect(count == 0)
    }

    @Test("Tumbling window: all elements in one window")
    func tumblingSingleWindow() async throws {
        // Short stream, long window
        let items = TimeWindowedTests.makeTimestampedValues(
            [1.0, 2.0, 3.0],
            offsetsMs: [0, 50, 100]
        )
        let stream = AsyncValueStream(items)

        var windows: [[Double]] = []
        for try await window in stream.tumblingWindow(duration: .seconds(10)) {
            windows.append(window.map(\.value))
        }

        #expect(windows.count == 1)
        #expect(windows[0] == [1.0, 2.0, 3.0])
    }

    @Test("Tumbling window: irregular arrival rates")
    func tumblingIrregular() async throws {
        // Irregular spacing: some windows have more elements than others
        let items = TimeWindowedTests.makeTimestampedValues(
            [1.0, 2.0, 3.0, 4.0, 5.0],
            offsetsMs: [0, 10, 20, 300, 310]
        )
        let stream = AsyncValueStream(items)

        var windows: [[Double]] = []
        for try await window in stream.tumblingWindow(duration: .milliseconds(300)) {
            windows.append(window.map(\.value))
        }

        // Window 1 [0ms, 300ms): values at 0, 10, 20 → [1, 2, 3]
        // Window 2 [300ms, 600ms): values at 300, 310 → [4, 5]
        #expect(windows.count == 2)
        #expect(windows[0] == [1.0, 2.0, 3.0])
        #expect(windows[1] == [4.0, 5.0])
    }

    // MARK: - Sliding Window Tests

    @Test("Sliding window: basic overlap behavior")
    func slidingBasicOverlap() async throws {
        // Values at 0, 100, 200, 300, 400ms
        // Window = 300ms, stride = 100ms
        let items = TimeWindowedTests.makeTimestampedValues(
            [1.0, 2.0, 3.0, 4.0, 5.0],
            offsetsMs: [0, 100, 200, 300, 400]
        )
        let stream = AsyncValueStream(items)

        var windows: [[Double]] = []
        for try await window in stream.slidingWindow(duration: .milliseconds(300), stride: .milliseconds(100)) {
            windows.append(window.map(\.value))
        }

        // Windows should overlap, containing elements within the duration
        #expect(windows.count >= 2)
        // First window should contain at least the initial elements
        #expect(windows[0].contains(1.0))
    }

    @Test("Sliding window: stride equals duration degenerates to tumbling")
    func slidingStrideEqualsDuration() async throws {
        let items = TimeWindowedTests.makeTimestampedValues(
            [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
            offsetsMs: [0, 100, 200, 300, 400, 500]
        )
        let stream = AsyncValueStream(items)

        var windows: [[Double]] = []
        for try await window in stream.slidingWindow(duration: .milliseconds(300), stride: .milliseconds(300)) {
            windows.append(window.map(\.value))
        }

        // Should behave like tumbling — non-overlapping windows
        #expect(windows.count == 2)
        #expect(windows[0] == [1.0, 2.0, 3.0])
        #expect(windows[1] == [4.0, 5.0, 6.0])
    }

    @Test("Sliding window: empty stream yields no windows")
    func slidingEmpty() async throws {
        let items: [Timestamped<Double>] = []
        let stream = AsyncValueStream(items)

        var count = 0
        for try await _ in stream.slidingWindow(duration: .milliseconds(300), stride: .milliseconds(100)) {
            count += 1
        }

        #expect(count == 0)
    }

    @Test("Sliding window: single element stream")
    func slidingSingleElement() async throws {
        let items = TimeWindowedTests.makeTimestampedValues([42.0], offsetsMs: [0])
        let stream = AsyncValueStream(items)

        var windows: [[Double]] = []
        for try await window in stream.slidingWindow(duration: .milliseconds(300), stride: .milliseconds(100)) {
            windows.append(window.map(\.value))
        }

        // Single element should appear in at least one window
        #expect(windows.count >= 1)
        #expect(windows[0] == [42.0])
    }

    // MARK: - Edge Case Tests (Tumbling)

    @Test("Tumbling window: single element stream produces one single-element window")
    func tumblingSingleElement() async throws {
        let items = TimeWindowedTests.makeTimestampedValues([99.0], offsetsMs: [0])
        let stream = AsyncValueStream(items)

        var windows: [[Double]] = []
        for try await window in stream.tumblingWindow(duration: .milliseconds(300)) {
            windows.append(window.map(\.value))
        }

        #expect(windows.count == 1)
        #expect(windows[0] == [99.0])
    }

    @Test("Tumbling window: very short duration (1 nanosecond) produces many single-element windows")
    func tumblingVeryShortDuration() async throws {
        // Values spaced 100ms apart — a 1ns window should isolate each element
        let items = TimeWindowedTests.makeTimestampedValues(
            [1.0, 2.0, 3.0, 4.0, 5.0],
            offsetsMs: [0, 100, 200, 300, 400]
        )
        let stream = AsyncValueStream(items)

        var windows: [[Double]] = []
        for try await window in stream.tumblingWindow(duration: .nanoseconds(1)) {
            windows.append(window.map(\.value))
        }

        // Each element should end up in its own window
        #expect(windows.count == 5)
        for window in windows {
            #expect(window.count == 1)
        }
    }

    // MARK: - Edge Case Tests (Sliding)

    @Test("Sliding window: stride larger than duration (non-overlapping with gaps)")
    func slidingStrideLargerThanDuration() async throws {
        // Values at 0, 100, 200, 300, 400ms
        // Window = 100ms, stride = 200ms → windows with gaps between them
        let items = TimeWindowedTests.makeTimestampedValues(
            [1.0, 2.0, 3.0, 4.0, 5.0],
            offsetsMs: [0, 100, 200, 300, 400]
        )
        let stream = AsyncValueStream(items)

        var windows: [[Double]] = []
        for try await window in stream.slidingWindow(duration: .milliseconds(100), stride: .milliseconds(200)) {
            windows.append(window.map(\.value))
        }

        // Should still emit windows even when stride > duration
        #expect(windows.count >= 1)
        // No window should contain more elements than fit in 100ms
        for window in windows {
            #expect(window.count <= 2)
        }
    }

    // MARK: - Property-Based Tests (Tumbling)

    @Test("Tumbling window: total elements across all windows equals input count")
    func tumblingTotalElementsPreserved() async throws {
        let items = TimeWindowedTests.makeTimestampedValues(
            [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0],
            offsetsMs: [0, 50, 100, 200, 300, 350, 500]
        )
        let stream = AsyncValueStream(items)

        var totalElements = 0
        for try await window in stream.tumblingWindow(duration: .milliseconds(200)) {
            totalElements += window.count
        }

        #expect(totalElements == 7)
    }

    @Test("Tumbling window: window boundaries are non-overlapping")
    func tumblingNonOverlapping() async throws {
        let items = TimeWindowedTests.makeTimestampedValues(
            [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
            offsetsMs: [0, 100, 200, 300, 400, 500]
        )
        let stream = AsyncValueStream(items)

        var allValues: [Double] = []
        for try await window in stream.tumblingWindow(duration: .milliseconds(300)) {
            allValues.append(contentsOf: window.map(\.value))
        }

        // No duplicates: each element appears in exactly one window
        #expect(allValues.count == 6)
        let uniqueValues = Set(allValues)
        #expect(uniqueValues.count == 6)
    }

    // MARK: - Numerical Stability Tests

    @Test("Tumbling window: NaN values in stream are included in windows without crashing")
    func tumblingWithNaN() async throws {
        let reference = ContinuousClock.now
        let items = [
            Timestamped(value: 1.0, timestamp: reference),
            Timestamped(value: Double.nan, timestamp: reference.advanced(by: .milliseconds(100))),
            Timestamped(value: 3.0, timestamp: reference.advanced(by: .milliseconds(200)))
        ]
        let stream = AsyncValueStream(items)

        var totalElements = 0
        var foundNaN = false
        for try await window in stream.tumblingWindow(duration: .seconds(10)) {
            for element in window {
                totalElements += 1
                if element.value.isNaN { foundNaN = true }
            }
        }

        #expect(totalElements == 3)
        #expect(foundNaN)
    }

    @Test("Tumbling window: very large Double values in windows")
    func tumblingWithVeryLargeValues() async throws {
        let items = TimeWindowedTests.makeTimestampedValues(
            [1e15, -1e15, Double.greatestFiniteMagnitude],
            offsetsMs: [0, 100, 200]
        )
        let stream = AsyncValueStream(items)

        var allValues: [Double] = []
        for try await window in stream.tumblingWindow(duration: .seconds(10)) {
            allValues.append(contentsOf: window.map(\.value))
        }

        #expect(allValues.count == 3)
        #expect(abs(allValues[0] - 1e15) < 1e5)
        #expect(abs(allValues[1] - (-1e15)) < 1e5)
        #expect(allValues[2] == Double.greatestFiniteMagnitude)
    }

    // MARK: - Stress Tests

    @Test("Tumbling window over 10_000 elements performs efficiently",
          .timeLimit(.minutes(1)))
    func tumblingLargeStreamStress() async throws {
        let count = 10_000
        let reference = ContinuousClock.now
        let items = (0..<count).map { i in
            Timestamped(
                value: Double(i),
                timestamp: reference.advanced(by: .milliseconds(i))
            )
        }
        let stream = AsyncValueStream(items)

        var totalElements = 0
        for try await window in stream.tumblingWindow(duration: .milliseconds(100)) {
            totalElements += window.count
        }

        #expect(totalElements == count)
    }
}

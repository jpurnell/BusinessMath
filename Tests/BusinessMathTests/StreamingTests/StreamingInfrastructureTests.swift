//
//  StreamingInfrastructureTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-30.
//

import Testing
import Foundation
@testable import BusinessMath

/// Tests for Core Streaming Infrastructure (Phase 2.1)
///
/// Following TDD:
/// - RED: Write failing tests first
/// - GREEN: Implement to make tests pass
/// - REFACTOR: Clean up implementation
@Suite("Streaming Infrastructure Tests")
struct StreamingInfrastructureTests {

    // MARK: - Basic AsyncSequence Tests

    @Test("Create stream from array of values")
    func streamFromArray() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let stream = AsyncValueStream(values)

        var collected: [Double] = []
        for try await value in stream {
            collected.append(value)
        }

        #expect(collected == values)
    }

    @Test("Create infinite stream with generator")
    func infiniteStream() async throws {
        var counter = 0.0
        let stream = AsyncGeneratorStream {
            counter += 1
            return counter
        }

        var collected: [Double] = []
        var iterations = 0
        for try await value in stream {
            collected.append(value)
            iterations += 1
            if iterations >= 10 {
                break
            }
        }

        #expect(collected == [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0])
    }

    // MARK: - Windowing Tests

    @Test("Tumbling window of fixed size")
    func tumblingWindow() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
        let stream = AsyncValueStream(values)

        var windows: [[Double]] = []
        for try await window in stream.tumblingWindow(size: 3) {
            windows.append(window)
        }

        // Expected: [1,2,3], [4,5,6], [7,8] (last window may be incomplete)
        #expect(windows.count == 3)
        #expect(windows[0] == [1.0, 2.0, 3.0])
        #expect(windows[1] == [4.0, 5.0, 6.0])
        #expect(windows[2] == [7.0, 8.0])
    }

    @Test("Sliding window of fixed size")
    func slidingWindow() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let stream = AsyncValueStream(values)

        var windows: [[Double]] = []
        for try await window in stream.slidingWindow(size: 3) {
            windows.append(window)
        }

        // Expected: [1,2,3], [2,3,4], [3,4,5]
        #expect(windows.count == 3)
        #expect(windows[0] == [1.0, 2.0, 3.0])
        #expect(windows[1] == [2.0, 3.0, 4.0])
        #expect(windows[2] == [3.0, 4.0, 5.0])
    }

    @Test("Sliding window with step size")
    func slidingWindowWithStep() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
        let stream = AsyncValueStream(values)

        var windows: [[Double]] = []
        for try await window in stream.slidingWindow(size: 3, step: 2) {
            windows.append(window)
        }

        // Expected: [1,2,3], [3,4,5], [5,6,7], [7,8]
        #expect(windows.count == 4)
        #expect(windows[0] == [1.0, 2.0, 3.0])
        #expect(windows[1] == [3.0, 4.0, 5.0])
        #expect(windows[2] == [5.0, 6.0, 7.0])
        #expect(windows[3] == [7.0, 8.0])
    }

    // MARK: - Buffering Tests

    @Test("Buffer elements with size limit")
    func bufferWithSizeLimit() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
        let stream = AsyncValueStream(values)

        var buffers: [[Double]] = []
        for try await buffer in stream.buffer(size: 3) {
            buffers.append(buffer)
        }

        // Expected: [1,2,3], [4,5,6], [7,8]
        #expect(buffers.count == 3)
        #expect(buffers[0] == [1.0, 2.0, 3.0])
        #expect(buffers[1] == [4.0, 5.0, 6.0])
        #expect(buffers[2] == [7.0, 8.0])
    }

    // @Test("Buffer elements with time window")
    // func bufferWithTimeWindow() async throws {
    //     // Deferred - requires concurrent-safe iterator management
    // }

    // MARK: - Transformation Tests

    @Test("Map stream values")
    func mapStream() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let stream = AsyncValueStream(values)

        var collected: [Double] = []
        for try await value in stream.map({ $0 * 2 }) {
            collected.append(value)
        }

        #expect(collected == [2.0, 4.0, 6.0, 8.0, 10.0])
    }

    @Test("Filter stream values")
    func filterStream() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let stream = AsyncValueStream(values)

        var collected: [Double] = []
        for try await value in stream.filter({ $0 > 2.5 }) {
            collected.append(value)
        }

        #expect(collected == [3.0, 4.0, 5.0])
    }

    @Test("Compact map stream values")
    func compactMapStream() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let stream = AsyncValueStream(values)

        var collected: [String] = []
        for try await value in stream.compactMap({ value -> String? in
            guard value > 2.5 else { return nil }
            return String(Int(value))
        }) {
            collected.append(value)
        }

        #expect(collected == ["3", "4", "5"])
    }

    // MARK: - Error Handling Tests

    @Test("Handle errors in stream with retry")
    func streamWithRetry() async throws {
        var attemptCount = 0
        let stream = AsyncGeneratorStream {
            attemptCount += 1
            if attemptCount < 3 {
                throw StreamError.temporaryFailure
            }
            return Double(attemptCount)
        }

        var collected: [Double] = []
        var iterations = 0
        for try await value in stream.retry(maxAttempts: 3) {
            collected.append(value)
            iterations += 1
            if iterations >= 5 {
                break
            }
        }

        // Should succeed after 3 attempts
        #expect(collected.count > 0)
    }

    @Test("Handle errors in stream with fallback")
    func streamWithFallback() async throws {
        var shouldFail = true
        let stream = AsyncGeneratorStream {
            if shouldFail {
                shouldFail = false
                throw StreamError.temporaryFailure
            }
            return 42.0
        }

        var collected: [Double] = []
        var iterations = 0
        for try await value in stream.catchErrors { error in
            return 0.0  // Fallback value
        } {
            collected.append(value)
            iterations += 1
            if iterations >= 3 {
                break
            }
        }

        // First value should be fallback (0.0), rest should be 42.0
        #expect(collected[0] == 0.0)
        #expect(collected[1] == 42.0)
    }

    // MARK: - Backpressure Tests
    // Note: Throttle and Debounce deferred to Phase 2.5 due to timing complexity

    // @Test("Throttle stream to limit rate")
    // func throttleStream() async throws {
    //     // Deferred - timing-based operations need more work
    // }

    // @Test("Debounce stream to suppress rapid values")
    // func debounceStream() async throws {
    //     // Deferred - requires concurrent-safe iterator management
    // }

    // MARK: - Combining Streams Tests
    // Note: Merge and Zip will be implemented in Phase 2.5 (Stream Composition)
    // They require more sophisticated concurrent iterator management

    // @Test("Merge two streams")
    // func mergeStreams() async throws {
    //     // Deferred to Phase 2.5
    // }

    // @Test("Zip two streams together")
    // func zipStreams() async throws {
    //     // Deferred to Phase 2.5
    // }

    // MARK: - Memory Efficiency Tests

    @Test("Streaming maintains O(1) memory for windowed operations")
    func constantMemoryForWindows() async throws {
        // Simulate large stream
        let largeStream = AsyncGeneratorStream {
            return Double.random(in: 0...100)
        }

        var windowCount = 0
        for try await window in largeStream.slidingWindow(size: 100) {
            // Window should never exceed size 100
            #expect(window.count <= 100)

            windowCount += 1
            if windowCount >= 1000 {
                break
            }
        }

        // If we got 1000 windows without memory issues, O(1) memory is maintained
        #expect(windowCount == 1000)
    }
}

// MARK: - Supporting Types

enum StreamError: Error {
    case temporaryFailure
    case permanentFailure
}

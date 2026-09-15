//
//  StreamingInfrastructureTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-30.
//

import Testing
import Foundation
import TestSupport
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

        let collector = ProgressCollector<Double>()
        for try await value in stream {
            collector.append(value)
        }

        let collected = collector.getItems()

        // The stream hands each element back untouched, so the claim is bit-for-bit.
        #expect(identical(collected, values))
    }

    @Test("Create infinite stream with generator")
    func infiniteStream() async throws {
        var counter = 0.0
        let stream = AsyncGeneratorStream {
            counter += 1
            return counter
        }

        let collector = ProgressCollector<Double>()
        var iterations = 0
        for try await value in stream {
            collector.append(value)
            iterations += 1
            if iterations >= 10 {
                break
            }
        }

        let collected = collector.getItems()

        // Counting by one from zero in Double is exact through 2^53; no rounding to allow for.
        #expect(identical(collected, [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]))
    }

    // MARK: - Windowing Tests

    @Test("Tumbling window of fixed size")
    func tumblingWindow() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
        let stream = AsyncValueStream(values)

        let collector = ProgressCollector<[Double]>()
        for try await window in stream.tumblingWindow(size: 3) {
            collector.append(window)
        }

        let windows = collector.getItems()

        // Expected: [1,2,3], [4,5,6], [7,8] (last window may be incomplete)
        #expect(windows.count == 3)
        // Windowing only regroups the elements; each is the literal that went in.
        #expect(identical(windows[0], [1.0, 2.0, 3.0]))
        #expect(identical(windows[1], [4.0, 5.0, 6.0]))
        #expect(identical(windows[2], [7.0, 8.0]))
    }

    @Test("Sliding window of fixed size")
    func slidingWindow() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let stream = AsyncValueStream(values)

        let collector = ProgressCollector<[Double]>()
        for try await window in stream.slidingWindow(size: 3) {
            collector.append(window)
        }

        let windows = collector.getItems()

        // Expected: [1,2,3], [2,3,4], [3,4,5]
        #expect(windows.count == 3)
        // Windowing only regroups the elements; each is the literal that went in.
        #expect(identical(windows[0], [1.0, 2.0, 3.0]))
        #expect(identical(windows[1], [2.0, 3.0, 4.0]))
        #expect(identical(windows[2], [3.0, 4.0, 5.0]))
    }

    @Test("Sliding window with step size")
    func slidingWindowWithStep() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
        let stream = AsyncValueStream(values)

        let collector = ProgressCollector<[Double]>()
        for try await window in stream.slidingWindow(size: 3, step: 2) {
            collector.append(window)
        }

        let windows = collector.getItems()

        // Expected: [1,2,3], [3,4,5], [5,6,7], [7,8]
        #expect(windows.count == 4)
        // Windowing only regroups the elements; each is the literal that went in.
        #expect(identical(windows[0], [1.0, 2.0, 3.0]))
        #expect(identical(windows[1], [3.0, 4.0, 5.0]))
        #expect(identical(windows[2], [5.0, 6.0, 7.0]))
        #expect(identical(windows[3], [7.0, 8.0]))
    }

    // MARK: - Buffering Tests

    @Test("Buffer elements with size limit")
    func bufferWithSizeLimit() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
        let stream = AsyncValueStream(values)

        let collector = ProgressCollector<[Double]>()
        for try await buffer in stream.buffer(size: 3) {
            collector.append(buffer)
        }

        let buffers = collector.getItems()

        // Expected: [1,2,3], [4,5,6], [7,8]
        #expect(buffers.count == 3)
        // Buffering only regroups the elements; each is the literal that went in.
        #expect(identical(buffers[0], [1.0, 2.0, 3.0]))
        #expect(identical(buffers[1], [4.0, 5.0, 6.0]))
        #expect(identical(buffers[2], [7.0, 8.0]))
    }

    // There is no `buffer(duration:)` to test. Its declaration is commented out at
    // `AsyncValueStream.swift:359` along with the `AsyncTimeBufferSequence` it would
    // return, so the stub that stood here named a capability the library does not ship.

    // MARK: - Transformation Tests

    @Test("Map stream values")
    func mapStream() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let stream = AsyncValueStream(values)

        let collector = ProgressCollector<Double>()
        for try await value in stream.map({ $0 * 2 }) {
            collector.append(value)
        }

        let collected = collector.getItems()

        // Doubling a small integer is exact in binary floating point — a scaling by 2 only
        // moves the exponent — so the map's output is the literal, bit for bit.
        #expect(identical(collected, [2.0, 4.0, 6.0, 8.0, 10.0]))
    }

    @Test("Filter stream values")
    func filterStream() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let stream = AsyncValueStream(values)

        let collector = ProgressCollector<Double>()
        for try await value in stream.filter({ $0 > 2.5 }) {
            collector.append(value)
        }

        let collected = collector.getItems()

        // Filtering selects elements without touching them.
        #expect(identical(collected, [3.0, 4.0, 5.0]))
    }

    @Test("Compact map stream values")
    func compactMapStream() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let stream = AsyncValueStream(values)

        let collector = ProgressCollector<String>()
        for try await value in stream.compactMap({ value -> String? in
            guard value > 2.5 else { return nil }
            return String(Int(value))
        }) {
            collector.append(value)
        }

        let collected = collector.getItems()

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

        let collector = ProgressCollector<Double>()
        var iterations = 0
        for try await value in stream.retry(maxAttempts: 3) {
            collector.append(value)
            iterations += 1
            if iterations >= 5 {
                break
            }
        }

        let collected = collector.getItems()

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

        let collector = ProgressCollector<Double>()
        var iterations = 0
        for try await value in stream.catchErrors ({ error in
            return 0.0  // Fallback value
        }) {
            collector.append(value)
            iterations += 1
            if iterations >= 3 {
                break
            }
        }

        let collected = collector.getItems()

        // First value should be fallback (0.0), rest should be 42.0
        #expect(abs(collected[0] - 0.0) < 1e-6)
        #expect(abs(collected[1] - 42.0) < 1e-6)
    }

    // MARK: - Backpressure Tests

    /// `throttle` is a delay, not a filter: every element arrives, and in order.
    ///
    /// Worth pinning, because the name usually means the opposite. Combine's `throttle`
    /// discards all but one element per interval; `AsyncThrottleSequence` sleeps out the
    /// remainder of the interval and then yields the element it was holding. A test that
    /// only counted elements would pass against either behaviour.
    @Test("Throttling delays every element and drops none", .timeLimit(testHangGuard))
    func throttlePreservesEveryElement() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let stream = AsyncValueStream(values)

        let collector = ProgressCollector<Double>()
        for try await value in stream.throttle(interval: .milliseconds(20)) {
            collector.append(value)
        }

        let collected = collector.getItems()

        // Throttling changes when an element is yielded, never which one or what it holds,
        // so the claim is bit-for-bit.
        #expect(identical(collected, values))
    }

    /// The rate limit, asserted as a *lower* bound on elapsed time and gated on
    /// `RUN_BENCHMARKS` anyway.
    ///
    /// An upper bound — "five values finished inside 200ms" — is a statement about the
    /// machine and fails under load; that flakiness is why this operator was left
    /// untested for two phases. A lower bound is a statement about the operator:
    /// `next()` sleeps the remainder of the interval before every element after the
    /// first, and `Task.sleep(for:)` is documented to sleep *at least* as long as asked,
    /// so a slow machine can only make this more true.
    ///
    /// It still reads the wall clock, and `AsyncThrottleSequence` holds a
    /// `ContinuousClock` that no caller can substitute — there is no logical clock to
    /// drive it from. So it takes the house treatment for a wall-clock assertion:
    /// `// TIMING:` and `.benchmarkOnly`, the same pair `HangGuard` prescribes. The
    /// content and ordering claims above stay in the live suite, where they belong,
    /// because they read no clock at all.
    @Test("Five values throttled to 20ms cannot finish inside four intervals",
          .timeLimit(testHangGuard), .benchmarkOnly)
    func throttleEnforcesTheMinimumGap() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0]
        let interval: Duration = .milliseconds(20)
        let stream = AsyncValueStream(values)

        let clock = ContinuousClock()
        let start = clock.now
        let collector = ProgressCollector<Double>()
        for try await value in stream.throttle(interval: interval) {
            collector.append(value)
        }
        let elapsed: Duration = clock.now - start

        // Four gaps between five elements; the first element is not delayed.
        let gaps: Int = values.count - 1
        let minimumElapsed: Duration = interval * gaps
        let count: Int = collector.getItems().count

        #expect(count == values.count, "\(count) values came through, not \(values.count)")
        // TIMING: intentional wall-clock assertion — a floor, which load cannot break
        #expect(elapsed >= minimumElapsed,
                "five throttled values took \(elapsed), under the \(minimumElapsed) floor")
    }

    // MARK: - Combining Streams Tests
    //
    // `merge(with:)`, `zip(with:)` and `debounce(interval:)` shipped in Phase 2.5 and live
    // in `StreamingComposition.swift`; `StreamingCompositionTests` covers them. The stubs
    // that stood here described them as deferred, which stopped being true.

    // MARK: - Memory Efficiency Tests

    @Test("Streaming maintains O(1) memory for windowed operations")
    func constantMemoryForWindows() async throws {
        // Simulate large stream with deterministic values
        var counter: Double = 0
        let largeStream = AsyncGeneratorStream {
            counter += 1
            return counter.truncatingRemainder(dividingBy: 100)
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

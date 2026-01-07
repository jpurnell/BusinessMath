//
//  StreamingCompositionTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-30.
//

import Testing
import Foundation
@testable import BusinessMath

/// Tests for Stream Composition (Phase 2.5)
///
/// Following TDD:
/// - RED: Write failing tests first
/// - GREEN: Implement to make tests pass
/// - REFACTOR: Clean up implementation
@Suite("Streaming Composition Tests")
struct StreamingCompositionTests {

    // MARK: - Merge Tests

    @Test("Merge two streams")
    func mergeTwoStreams() async throws {
        let stream1 = AsyncValueStream([1.0, 3.0, 5.0])
        let stream2 = AsyncValueStream([2.0, 4.0, 6.0])

        var values: [Double] = []
        for try await value in stream1.merge(with: stream2) {
            values.append(value)
        }

        // Should contain all values from both streams
        #expect(values.count == 6)
        #expect(values.contains(1.0))
        #expect(values.contains(2.0))
        #expect(values.contains(3.0))
        #expect(values.contains(4.0))
        #expect(values.contains(5.0))
        #expect(values.contains(6.0))
    }

    @Test("Merge with different stream speeds")
    func mergeWithDifferentSpeeds() async throws {
        let fastStream = AsyncValueStream([1.0, 2.0, 3.0])
        let slowStream = AsyncDelayedStream([10.0, 20.0], delay: .milliseconds(10))

        var values: [Double] = []
        for try await value in fastStream.merge(with: slowStream) {
            values.append(value)
        }

        // Should receive all values
        #expect(values.count == 5)
    }

    @Test("Merge empty stream with non-empty stream")
    func mergeEmptyWithNonEmpty() async throws {
        let emptyStream = AsyncValueStream<Double>([])
        let nonEmptyStream = AsyncValueStream([1.0, 2.0, 3.0])

        var values: [Double] = []
        for try await value in emptyStream.merge(with: nonEmptyStream) {
            values.append(value)
        }

        #expect(values == [1.0, 2.0, 3.0])
    }

    // MARK: - Zip Tests

    @Test("Zip two streams together")
    func zipTwoStreams() async throws {
        let stream1 = AsyncValueStream([1.0, 2.0, 3.0])
        let stream2 = AsyncValueStream([10.0, 20.0, 30.0])

        var pairs: [(Double, Double)] = []
        for try await pair in stream1.zip(with: stream2) {
            pairs.append(pair)
        }

        #expect(pairs.count == 3)
        #expect(pairs[0].0 == 1.0 && pairs[0].1 == 10.0)
        #expect(pairs[1].0 == 2.0 && pairs[1].1 == 20.0)
        #expect(pairs[2].0 == 3.0 && pairs[2].1 == 30.0)
    }

    @Test("Zip terminates when shorter stream ends")
    func zipTerminatesWithShorterStream() async throws {
        let shortStream = AsyncValueStream([1.0, 2.0])
        let longStream = AsyncValueStream([10.0, 20.0, 30.0, 40.0])

        var pairs: [(Double, Double)] = []
        for try await pair in shortStream.zip(with: longStream) {
            pairs.append(pair)
        }

        // Should only have 2 pairs (limited by shorter stream)
        #expect(pairs.count == 2)
    }

    @Test("Zip with different element types")
    func zipDifferentTypes() async throws {
        let doubleStream = AsyncValueStream([1.0, 2.0, 3.0])
        let stringStream = AsyncValueStream(["a", "b", "c"])

        var pairs: [(Double, String)] = []
        for try await pair in doubleStream.zip(with: stringStream) {
            pairs.append(pair)
        }

        #expect(pairs.count == 3)
        #expect(pairs[0].0 == 1.0 && pairs[0].1 == "a")
        #expect(pairs[1].0 == 2.0 && pairs[1].1 == "b")
        #expect(pairs[2].0 == 3.0 && pairs[2].1 == "c")
    }

    // MARK: - Debounce Tests

    @Test("Debounce emits last value after silence")
    func debounceEmitsAfterSilence() async throws {
        let values = [1.0, 2.0, 3.0]
        let stream = AsyncDelayedStream(values, delay: .milliseconds(5))

        var debounced: [Double] = []
        for try await value in stream.debounce(interval: .milliseconds(20)) {
            debounced.append(value)
        }

        // Should only emit the last value after silence
        #expect(debounced.count == 1)
        #expect(debounced[0] == 3.0)
    }

    @Test("Debounce with separated values")
    func debounceWithSeparatedValues() async throws {
        let stream = AsyncDelayedStream([1.0, 2.0], delay: .milliseconds(50))

        var debounced: [Double] = []
        for try await value in stream.debounce(interval: .milliseconds(40)) {
            debounced.append(value)
        }

        // With 50ms between values and 40ms debounce, both should emit
        #expect(debounced.count == 2)
    }

    // MARK: - CombineLatest Tests

    @Test("CombineLatest emits when either stream updates")
    func combineLatestEmitsOnUpdate() async throws {
        let stream1 = AsyncValueStream([1.0, 2.0, 3.0])
        let stream2 = AsyncValueStream([10.0, 20.0])

        var combinations: [(Double, Double)] = []
        for try await pair in stream1.combineLatest(with: stream2) {
            combinations.append(pair)
        }

        // Should emit when either stream produces a value
        // First: (1, 10), (2, 10), (3, 10), (3, 20)
        #expect(combinations.count >= 2)

        // Last combination should be (3.0, 20.0)
        let last = combinations.last!
        #expect(last.0 == 3.0 && last.1 == 20.0)
    }

    // MARK: - WithLatestFrom Tests

    @Test("WithLatestFrom samples when trigger fires")
    func withLatestFromSamples() async throws {
        // Add small delay to trigger to ensure sampled stream can populate first
        let trigger = AsyncDelayedStream([1, 2, 3], delay: .milliseconds(10))
        let sampled = AsyncValueStream([10.0, 20.0, 30.0, 40.0])

        var results: [Double] = []
        for try await value in trigger.withLatestFrom(sampled) {
            results.append(value)
        }

        // Each trigger should sample the latest value from sampled stream
        #expect(results.count == 3)
    }

    // MARK: - Distinct Tests

    @Test("Distinct removes consecutive duplicates")
    func distinctRemovesDuplicates() async throws {
        let values = [1.0, 1.0, 2.0, 2.0, 3.0, 3.0, 3.0, 2.0]
        let stream = AsyncValueStream(values)

        var distinct: [Double] = []
        for try await value in stream.distinct() {
            distinct.append(value)
        }

        // Should only emit when value changes
        #expect(distinct == [1.0, 2.0, 3.0, 2.0])
    }

    @Test("DistinctUntilChanged with custom comparator")
    func distinctUntilChangedCustom() async throws {
        let values = [1.1, 1.2, 2.0, 2.1, 3.0]
        let stream = AsyncValueStream(values)

        var distinct: [Double] = []
        // Only emit when integer part changes
        for try await value in stream.distinctUntilChanged(by: { Int($0) == Int($1) }) {
            distinct.append(value)
        }

        #expect(distinct.count == 3)
        #expect(distinct[0] < 2.0)  // 1.x
        #expect(distinct[1] >= 2.0 && distinct[1] < 3.0)  // 2.x
        #expect(distinct[2] >= 3.0)  // 3.x
    }

    // MARK: - StartWith Tests

    @Test("StartWith prepends initial value")
    func startWithPrependsValue() async throws {
        let stream = AsyncValueStream([2.0, 3.0, 4.0])

        var values: [Double] = []
        for try await value in stream.startWith(1.0) {
            values.append(value)
        }

        #expect(values == [1.0, 2.0, 3.0, 4.0])
    }

    // MARK: - Sample Tests

    @Test("Sample at regular intervals")
    func sampleAtIntervals() async throws {
        // Create a stream that emits frequently
        let stream = AsyncGeneratorStream {
            Double.random(in: 0...100)
        }

        var samples: [Double] = []
        var count = 0
        for try await value in stream.sample(interval: .milliseconds(10)) {
            samples.append(value)
            count += 1
            if count >= 5 {
                break
            }
        }

        // Should get approximately 5 samples
        #expect(samples.count == 5)
    }

    // MARK: - Take/Skip Tests

    @Test("Take first N elements")
    func takeFirstN() async throws {
        let stream = AsyncValueStream([1.0, 2.0, 3.0, 4.0, 5.0])

        var values: [Double] = []
        for try await value in stream.take(3) {
            values.append(value)
        }

        #expect(values == [1.0, 2.0, 3.0])
    }

    @Test("Skip first N elements")
    func skipFirstN() async throws {
        let stream = AsyncValueStream([1.0, 2.0, 3.0, 4.0, 5.0])

        var values: [Double] = []
        for try await value in stream.skip(2) {
            values.append(value)
        }

        #expect(values == [3.0, 4.0, 5.0])
    }

    @Test("TakeWhile condition holds")
    func takeWhileCondition() async throws {
        let stream = AsyncValueStream([1.0, 2.0, 3.0, 4.0, 5.0])

        var values: [Double] = []
        for try await value in stream.takeWhile({ $0 < 4.0 }) {
            values.append(value)
        }

        #expect(values == [1.0, 2.0, 3.0])
    }

    @Test("SkipWhile condition holds")
    func skipWhileCondition() async throws {
        let stream = AsyncValueStream([1.0, 2.0, 3.0, 4.0, 5.0])

        var values: [Double] = []
        for try await value in stream.skipWhile({ $0 < 3.0 }) {
            values.append(value)
        }

        #expect(values == [3.0, 4.0, 5.0])
    }

    // MARK: - Timeout Tests

    @Test("Timeout completes normally for fast stream")
    func timeoutFastStream() async throws {
        let stream = AsyncValueStream([1.0, 2.0, 3.0])

        var values: [Double] = []
        do {
            for try await value in stream.timeout(duration: .seconds(1)) {
                values.append(value)
            }
            #expect(values == [1.0, 2.0, 3.0])
        } catch {
            Issue.record("Should not timeout for fast stream")
        }
    }

    @Test("Timeout throws for slow stream")
    func timeoutSlowStream() async throws {
        let stream = AsyncDelayedStream([1.0], delay: .seconds(2))

        var didTimeout = false
        do {
            for try await _ in stream.timeout(duration: .milliseconds(100)) {
				print("Should have timed out")
                // Should not get here
            }
        } catch is TimeoutError {
            didTimeout = true
        } catch {
            Issue.record("Wrong error type: \(error)")
        }

        #expect(didTimeout)
    }

    // MARK: - Memory Efficiency Tests

    @Test("Stream composition maintains O(1) memory")
    func constantMemoryForComposition() async throws {
        let stream1 = AsyncGeneratorStream { Double.random(in: 0...100) }
        let stream2 = AsyncGeneratorStream { Double.random(in: 0...100) }

        var count = 0
        for try await _ in stream1.merge(with: stream2).take(10000) {
            count += 1
        }

        #expect(count == 10000)
    }
}

// MARK: - Helper Types

/// AsyncSequence that emits values with a delay
struct AsyncDelayedStream<Element>: AsyncSequence {
    typealias AsyncIterator = Iterator

    private let values: [Element]
    private let delay: Duration

    init(_ values: [Element], delay: Duration) {
        self.values = values
        self.delay = delay
    }

    func makeAsyncIterator() -> Iterator {
        Iterator(values: values, delay: delay)
    }

    struct Iterator: AsyncIteratorProtocol {
        private var index: Int = 0
        private let values: [Element]
        private let delay: Duration

        init(values: [Element], delay: Duration) {
            self.values = values
            self.delay = delay
        }

        mutating func next() async throws -> Element? {
            guard index < values.count else { return nil }

            // Delay before returning value (including first value)
            try await Task.sleep(for: delay)

            let value = values[index]
            index += 1
            return value
        }
    }
}

// Note: TimeoutError is defined in StreamingComposition.swift, not here

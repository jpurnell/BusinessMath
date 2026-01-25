//
//  AsyncValueStream.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-30.
//

import Foundation

// MARK: - Basic Streams

/// AsyncSequence that emits values from an array
public struct AsyncValueStream<Element>: AsyncSequence {
    public typealias AsyncIterator = Iterator

    private let values: [Element]

    public init(_ values: [Element]) {
        self.values = values
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(values: values)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var index: Int = 0
        private let values: [Element]

        init(values: [Element]) {
            self.values = values
        }

        public mutating func next() async throws -> Element? {
            guard index < values.count else { return nil }
            let value = values[index]
            index += 1
            return value
        }
    }
}

/// AsyncSequence that generates values using a closure
public struct AsyncGeneratorStream<Element>: AsyncSequence {
    public typealias AsyncIterator = Iterator

    private let generator: () async throws -> Element

    public init(generator: @escaping () async throws -> Element) {
        self.generator = generator
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(generator: generator)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private let generator: () async throws -> Element

        init(generator: @escaping () async throws -> Element) {
            self.generator = generator
        }

        public mutating func next() async throws -> Element? {
            return try await generator()
        }
    }
}

// MARK: - AsyncSequence Extensions

/// Wraps an AsyncIterator as an AsyncSequence
public struct AsyncIteratorSequence<Iterator: AsyncIteratorProtocol>: AsyncSequence {
    public typealias Element = Iterator.Element
    public typealias AsyncIterator = Iterator

    private let makeIterator: () -> Iterator

    public init(_ iterator: Iterator) {
        let iter = iterator
        self.makeIterator = { iter }
    }

    public func makeAsyncIterator() -> Iterator {
        return makeIterator()
    }
}

// MARK: - Windowing Operations

extension AsyncSequence {
    /// Creates tumbling windows of fixed size
    /// Each window is non-overlapping; when one window fills, the next begins
    public func tumblingWindow(size: Int) -> AsyncTumblingWindowSequence<Self> {
        AsyncTumblingWindowSequence(base: self, size: size)
    }

    /// Creates sliding windows of fixed size
    /// Windows overlap by (size - step) elements
    public func slidingWindow(size: Int, step: Int = 1) -> AsyncSlidingWindowSequence<Self> {
        AsyncSlidingWindowSequence(base: self, size: size, step: step)
    }
}

public struct AsyncTumblingWindowSequence<Base: AsyncSequence>: AsyncSequence {
    public typealias Element = [Base.Element]
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let size: Int

    init(base: Base, size: Int) {
        self.base = base
        self.size = size
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), size: size)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let size: Int

        init(base: Base.AsyncIterator, size: Int) {
            self.baseIterator = base
            self.size = size
        }

        public mutating func next() async throws -> [Base.Element]? {
            var window: [Base.Element] = []
            window.reserveCapacity(size)

            while window.count < size {
                guard let value = try await baseIterator.next() else {
                    // Stream ended; return partial window if we have any elements
                    return window.isEmpty ? nil : window
                }
                window.append(value)
            }

            return window
        }
    }
}

public struct AsyncSlidingWindowSequence<Base: AsyncSequence>: AsyncSequence {
    public typealias Element = [Base.Element]
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let size: Int
    private let step: Int

    init(base: Base, size: Int, step: Int) {
        self.base = base
        self.size = size
        self.step = step
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), size: size, step: step)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let size: Int
        private let step: Int
        private var buffer: [Base.Element] = []
        private var isComplete = false

        init(base: Base.AsyncIterator, size: Int, step: Int) {
            self.baseIterator = base
            self.size = size
            self.step = step
        }

        public mutating func next() async throws -> [Base.Element]? {
            guard !isComplete else { return nil }

            // Fill buffer to size
            while buffer.count < size {
                guard let value = try await baseIterator.next() else {
                    isComplete = true
                    // Return partial window if it contains new data not in previous window
                    // After sliding by `step`, we keep `max(0, size - step)` old elements
                    // So if we have more than that, we read new elements
                    let keptFromPrevious = step >= size ? 0 : size - step
                    if buffer.count > keptFromPrevious {
                        return buffer
                    }
                    return nil
                }
                buffer.append(value)
            }

            // Return current window
            let window = Array(buffer.prefix(size))

            // Slide forward by step
            if step >= size {
                buffer.removeAll()
                // Need to skip (step - size) additional elements
                for _ in 0..<(step - size) {
                    guard let _ = try await baseIterator.next() else {
                        isComplete = true
                        break
                    }
                }
            } else {
                buffer.removeFirst(Swift.min(step, buffer.count))
            }

            return window
        }
    }
}

// MARK: - Buffering Operations

extension AsyncSequence {
    /// Buffers elements up to a size limit
    public func buffer(size: Int) -> AsyncBufferSequence<Self> {
        AsyncBufferSequence(base: self, size: size)
    }

    // Time-based buffering deferred to Phase 2.5
    // /// Buffers elements within a time window
    // public func buffer(duration: Duration) -> AsyncTimeBufferSequence<Self> {
    //     AsyncTimeBufferSequence(base: self, duration: duration)
    // }
}

public struct AsyncBufferSequence<Base: AsyncSequence>: AsyncSequence {
    public typealias Element = [Base.Element]
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let size: Int

    init(base: Base, size: Int) {
        self.base = base
        self.size = size
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), size: size)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let size: Int

        init(base: Base.AsyncIterator, size: Int) {
            self.baseIterator = base
            self.size = size
        }

        public mutating func next() async throws -> [Base.Element]? {
            var buffer: [Base.Element] = []
            buffer.reserveCapacity(size)

            while buffer.count < size {
                guard let value = try await baseIterator.next() else {
                    return buffer.isEmpty ? nil : buffer
                }
                buffer.append(value)
            }

            return buffer
        }
    }
}

// AsyncTimeBufferSequence deferred to Phase 2.5 - requires concurrent-safe iterator management
// public struct AsyncTimeBufferSequence<Base: AsyncSequence>: AsyncSequence {
//     // Implementation deferred
// }

// MARK: - Error Handling

extension AsyncSequence {
    /// Retries failed operations up to maxAttempts times
    public func retry(maxAttempts: Int) -> AsyncRetrySequence<Self> {
        AsyncRetrySequence(base: self, maxAttempts: maxAttempts)
    }

    /// Catches errors and provides fallback values
    public func catchErrors(_ handler: @escaping (Error) -> Element) -> AsyncCatchErrorsSequence<Self> {
        AsyncCatchErrorsSequence(base: self, handler: handler)
    }
}

public struct AsyncRetrySequence<Base: AsyncSequence>: AsyncSequence {
    public typealias Element = Base.Element
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let maxAttempts: Int

    init(base: Base, maxAttempts: Int) {
        self.base = base
        self.maxAttempts = maxAttempts
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base, maxAttempts: maxAttempts)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private let base: Base
        private let maxAttempts: Int
        private var currentIterator: Base.AsyncIterator
        private var attemptCount = 0

        init(base: Base, maxAttempts: Int) {
            self.base = base
            self.maxAttempts = maxAttempts
            self.currentIterator = base.makeAsyncIterator()
        }

        public mutating func next() async throws -> Base.Element? {
            while attemptCount < maxAttempts {
                do {
                    attemptCount += 1
                    return try await currentIterator.next()
                } catch {
                    if attemptCount >= maxAttempts {
                        throw error
                    }
                    // Reset iterator for retry
                    currentIterator = base.makeAsyncIterator()
                }
            }
            return nil
        }
    }
}

public struct AsyncCatchErrorsSequence<Base: AsyncSequence>: AsyncSequence {
    public typealias Element = Base.Element
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let handler: (Error) -> Element

    init(base: Base, handler: @escaping (Error) -> Element) {
        self.base = base
        self.handler = handler
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), handler: handler)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let handler: (Error) -> Base.Element

        init(base: Base.AsyncIterator, handler: @escaping (Error) -> Base.Element) {
            self.baseIterator = base
            self.handler = handler
        }

        public mutating func next() async throws -> Base.Element? {
            do {
                return try await baseIterator.next()
            } catch {
                return handler(error)
            }
        }
    }
}

// MARK: - Backpressure

extension AsyncSequence {
    /// Throttles the stream to emit at most one value per interval
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public func throttle(interval: Duration) -> AsyncThrottleSequence<Self> {
        AsyncThrottleSequence(base: self, interval: interval)
    }

    // Debounce deferred to Phase 2.5 - requires concurrent-safe iterator management
    // /// Debounces the stream, only emitting after the interval of silence
    // public func debounce(interval: Duration) -> AsyncDebounceSequence<Self> {
    //     AsyncDebounceSequence(base: self, interval: interval)
    // }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct AsyncThrottleSequence<Base: AsyncSequence>: AsyncSequence {
    public typealias Element = Base.Element
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let interval: Duration

    init(base: Base, interval: Duration) {
        self.base = base
        self.interval = interval
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), interval: interval)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let interval: Duration
        private var lastEmitTime: ContinuousClock.Instant?

        init(base: Base.AsyncIterator, interval: Duration) {
            self.baseIterator = base
            self.interval = interval
        }

        public mutating func next() async throws -> Base.Element? {
            guard let value = try await baseIterator.next() else {
                return nil
            }

            // Check if we need to wait
            if let lastTime = lastEmitTime {
                let elapsed = ContinuousClock.now - lastTime
                if elapsed < interval {
                    let remaining = interval - elapsed
                    try await Task.sleep(for: remaining)
                }
            }

            lastEmitTime = ContinuousClock.now
            return value
        }
    }
}

// AsyncDebounceSequence deferred to Phase 2.5 - requires concurrent-safe iterator management
// public struct AsyncDebounceSequence<Base: AsyncSequence>: AsyncSequence {
//     // Implementation deferred
// }

// MARK: - Combining Streams
// Note: Merge and Zip deferred to Phase 2.5 (Stream Composition)
// They require more sophisticated concurrent iterator management to avoid
// capturing mutating self in task groups

// extension AsyncSequence {
//     /// Merges this stream with another stream
//     public func merge<Other: AsyncSequence>(with other: Other) -> AsyncMergeSequence<Self, Other> where Other.Element == Element {
//         AsyncMergeSequence(first: self, second: other)
//     }
//
//     /// Zips this stream with another stream
//     public func zip<Other: AsyncSequence>(with other: Other) -> AsyncZipSequence<Self, Other> {
//         AsyncZipSequence(first: self, second: other)
//     }
// }

// MARK: - Helper Functions
// withTimeout deferred to Phase 2.5 - requires different approach for concurrent-safe implementation

// private func withTimeout<T>(_ duration: Duration, operation: @escaping () async throws -> T) async throws -> T {
//     // Implementation deferred
// }
//
// private struct TimeoutError: Error {}

//
//  AsyncValueStream.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-30.
//

import Foundation

// MARK: - Basic Streams

/// AsyncSequence that emits values from an array.
///
/// Provides async/await iteration over a fixed collection of values.
/// Useful for testing streaming analytics or replaying historical data.
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([1, 2, 3, 4, 5])
/// for await value in stream {
///     print(value)
/// }
/// ```
public struct AsyncValueStream<Element: Sendable>: AsyncSequence, @unchecked Sendable {
    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let values: [Element]

    /// Creates a stream from an array of values.
    ///
    /// - Parameter values: The array of values to emit asynchronously.
    public init(_ values: [Element]) {
        self.values = values
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields values from the array.
    public func makeAsyncIterator() -> Iterator {
        Iterator(values: values)
    }

    /// Iterator that yields values from an array asynchronously.
	public struct Iterator: AsyncIteratorProtocol, @unchecked Sendable {
        private var index: Int = 0
        private let values: [Element]

        init(values: [Element]) {
            self.values = values
        }

        /// Yields the next value from the array, or nil when exhausted.
        public mutating func next() async throws -> Element? {
            guard index < values.count else { return nil }
            let value = values[index]
            index += 1
            return value
        }
    }
}

/// AsyncSequence that generates values using a closure.
///
/// Creates an infinite stream where each value is produced by calling a generator function.
/// The generator can perform async operations and throw errors. The stream continues until
/// the generator returns nil or throws an error.
///
/// ## Example
/// ```swift
/// var counter = 0
/// let stream = AsyncGeneratorStream {
///     counter += 1
///     return counter <= 10 ? counter : nil
/// }
///
/// for try await value in stream {
///     print(value)  // Prints 1 through 10
/// }
/// ```
public struct AsyncGeneratorStream<Element: Sendable>: AsyncSequence, @unchecked Sendable {
    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let generator: () async throws -> Element

    /// Creates a stream that generates values using a closure.
    ///
    /// - Parameter generator: An async closure that produces values. Return nil to end the stream.
    public init(generator: @escaping () async throws -> Element) {
        self.generator = generator
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields generated values.
    public func makeAsyncIterator() -> Iterator {
        Iterator(generator: generator)
    }

    /// Iterator that yields generated values asynchronously.
    public struct Iterator: AsyncIteratorProtocol, @unchecked Sendable {
        private let generator: () async throws -> Element

        init(generator: @escaping () async throws -> Element) {
            self.generator = generator
        }

        /// Yields the next generated value, or nil when the generator returns nil.
        public mutating func next() async throws -> Element? {
            return try await generator()
        }
    }
}

// MARK: - AsyncSequence Extensions

/// Wraps an AsyncIterator as an AsyncSequence.
///
/// Converts an iterator into a sequence for use with `for await` loops and other
/// AsyncSequence operations. This is useful when you have an iterator but need
/// sequence-level functionality.
///
/// ## Example
/// ```swift
/// let iterator = myAsyncSequence.makeAsyncIterator()
/// let sequence = AsyncIteratorSequence(iterator)
/// for await value in sequence {
///     print(value)
/// }
/// ```
public struct AsyncIteratorSequence<Iterator: AsyncIteratorProtocol>: AsyncSequence {
    /// The element type yielded by the iterator.
    public typealias Element = Iterator.Element

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let makeIterator: () -> Iterator

    /// Creates a sequence from an iterator.
    ///
    /// - Parameter iterator: The async iterator to wrap as a sequence.
    public init(_ iterator: Iterator) {
        let iter = iterator
        self.makeIterator = { iter }
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: The wrapped iterator.
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

/// AsyncSequence that groups elements into non-overlapping windows of fixed size.
///
/// Tumbling windows partition a stream into consecutive, non-overlapping chunks.
/// Each element appears in exactly one window. When a window fills to the specified size,
/// it's emitted and the next window begins immediately.
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([1, 2, 3, 4, 5, 6, 7, 8])
/// for try await window in stream.tumblingWindow(size: 3) {
///     print(window)
/// }
/// // Outputs: [1, 2, 3], [4, 5, 6], [7, 8]
/// ```
///
/// - Note: The final window may contain fewer than `size` elements if the stream ends
///   before the window fills.
public struct AsyncTumblingWindowSequence<Base: AsyncSequence>: AsyncSequence {
    /// Windows are arrays of the base sequence's elements.
    public typealias Element = [Base.Element]

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let size: Int

    init(base: Base, size: Int) {
        self.base = base
        self.size = size
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields tumbling windows.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), size: size)
    }

    /// Iterator that yields tumbling windows asynchronously.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let size: Int

        init(base: Base.AsyncIterator, size: Int) {
            self.baseIterator = base
            self.size = size
        }

        /// Yields the next window of elements.
        ///
        /// - Returns: An array containing up to `size` elements, or nil when the stream ends.
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

/// AsyncSequence that groups elements into overlapping windows of fixed size.
///
/// Sliding windows move forward by a configurable step size, creating overlapping views
/// of the stream. Each element may appear in multiple windows depending on the size and step.
/// This is useful for computing moving averages, detecting patterns, or analyzing trends.
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([1, 2, 3, 4, 5])
/// for try await window in stream.slidingWindow(size: 3, step: 1) {
///     print(window)
/// }
/// // Outputs: [1, 2, 3], [2, 3, 4], [3, 4, 5]
/// ```
///
/// - Note: Windows overlap by `(size - step)` elements. When `step < size`, elements
///   appear in multiple windows. When `step >= size`, behavior is similar to tumbling windows.
public struct AsyncSlidingWindowSequence<Base: AsyncSequence>: AsyncSequence {
    /// Windows are arrays of the base sequence's elements.
    public typealias Element = [Base.Element]

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let size: Int
    private let step: Int

    init(base: Base, size: Int, step: Int) {
        self.base = base
        self.size = size
        self.step = step
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields sliding windows.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), size: size, step: step)
    }

    /// Iterator that yields sliding windows asynchronously.
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

        /// Yields the next window of elements.
        ///
        /// Maintains a buffer to enable overlapping windows. After each window is emitted,
        /// the iterator slides forward by `step` elements.
        ///
        /// - Returns: An array containing up to `size` elements, or nil when the stream ends.
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

/// AsyncSequence that buffers elements up to a size limit before yielding.
///
/// Collects elements from the base sequence until the buffer reaches the specified size,
/// then yields the buffered array. This is similar to tumbling windows but focuses on
/// buffering for efficiency rather than analytics. Useful for batch processing or reducing
/// per-element overhead.
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([1, 2, 3, 4, 5, 6, 7])
/// for try await batch in stream.buffer(size: 3) {
///     print("Processing batch:", batch)
/// }
/// // Outputs: [1, 2, 3], [4, 5, 6], [7]
/// ```
public struct AsyncBufferSequence<Base: AsyncSequence>: AsyncSequence {
    /// Buffers are arrays of the base sequence's elements.
    public typealias Element = [Base.Element]

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let size: Int

    init(base: Base, size: Int) {
        self.base = base
        self.size = size
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields buffered arrays.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), size: size)
    }

    /// Iterator that yields buffered arrays asynchronously.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let size: Int

        init(base: Base.AsyncIterator, size: Int) {
            self.baseIterator = base
            self.size = size
        }

        /// Yields the next buffer of elements.
        ///
        /// - Returns: An array containing up to `size` elements, or nil when the stream ends.
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

/// AsyncSequence that retries failed operations automatically.
///
/// When an error occurs while iterating the base sequence, this wrapper automatically
/// retries the operation up to `maxAttempts` times. After exhausting retries, the error
/// is propagated. Useful for handling transient failures in network streams or unreliable
/// data sources.
///
/// ## Example
/// ```swift
/// let unreliableStream = createNetworkStream()
/// for try await value in unreliableStream.retry(maxAttempts: 3) {
///     print(value)  // Will retry up to 3 times on errors
/// }
/// ```
///
/// - Note: The entire sequence is restarted on each retry attempt.
public struct AsyncRetrySequence<Base: AsyncSequence>: AsyncSequence {
    /// Elements are passed through from the base sequence.
    public typealias Element = Base.Element

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let maxAttempts: Int

    init(base: Base, maxAttempts: Int) {
        self.base = base
        self.maxAttempts = maxAttempts
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that retries on errors.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base, maxAttempts: maxAttempts)
    }

    /// Iterator that retries failed operations asynchronously.
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

        /// Yields the next element, retrying on errors.
        ///
        /// - Returns: The next element, or nil when the stream ends.
        /// - Throws: The error from the final failed attempt if all retries are exhausted.
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

/// AsyncSequence that catches errors and provides fallback values.
///
/// When an error occurs while iterating the base sequence, this wrapper calls a handler
/// function to produce a fallback value instead of propagating the error. This allows
/// streams to continue operating despite errors, with custom recovery logic.
///
/// ## Example
/// ```swift
/// let stream = createDataStream()
/// for try await value in stream.catchErrors({ error in
///     print("Error occurred: \(error), using default value")
///     return 0.0  // Fallback value
/// }) {
///     print(value)
/// }
/// ```
///
/// - Note: The error handler must return a valid element to continue the stream.
///   To terminate the stream on error, use ``retry(maxAttempts:)`` instead.
public struct AsyncCatchErrorsSequence<Base: AsyncSequence>: AsyncSequence {
    /// Elements are passed through from the base sequence or provided by the error handler.
    public typealias Element = Base.Element

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let handler: (Error) -> Element

    init(base: Base, handler: @escaping (Error) -> Element) {
        self.base = base
        self.handler = handler
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that catches errors and provides fallback values.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), handler: handler)
    }

    /// Iterator that catches errors and provides fallback values asynchronously.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let handler: (Error) -> Base.Element

        init(base: Base.AsyncIterator, handler: @escaping (Error) -> Base.Element) {
            self.baseIterator = base
            self.handler = handler
        }

        /// Yields the next element, or a fallback value if an error occurs.
        ///
        /// - Returns: The next element from the base stream, or a fallback value on error.
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

/// AsyncSequence that throttles emission rate to a maximum frequency.
///
/// Limits how frequently elements are emitted from the stream by enforcing a minimum
/// time interval between consecutive elements. If elements arrive faster than the throttle
/// rate, the iterator delays before yielding them. This provides backpressure control
/// for high-frequency streams.
///
/// ## Example
/// ```swift
/// let rapidStream = AsyncValueStream([1, 2, 3, 4, 5])
/// for try await value in rapidStream.throttle(interval: .milliseconds(100)) {
///     print(value)  // Emitted at most once per 100ms
/// }
/// ```
///
/// - Note: Throttling delays emission to maintain the rate limit. The first element
///   is always emitted immediately.
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct AsyncThrottleSequence<Base: AsyncSequence>: AsyncSequence {
    /// Elements are passed through from the base sequence at a controlled rate.
    public typealias Element = Base.Element

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let interval: Duration

    init(base: Base, interval: Duration) {
        self.base = base
        self.interval = interval
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that throttles emission rate.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), interval: interval)
    }

    /// Iterator that throttles emission rate asynchronously.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let interval: Duration
        private var lastEmitTime: ContinuousClock.Instant?

        init(base: Base.AsyncIterator, interval: Duration) {
            self.baseIterator = base
            self.interval = interval
        }

        /// Yields the next element after ensuring the throttle interval has passed.
        ///
        /// - Returns: The next element, delayed if necessary to maintain the rate limit.
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

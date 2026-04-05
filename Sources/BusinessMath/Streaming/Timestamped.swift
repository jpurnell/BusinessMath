//
//  Timestamped.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-05.
//

import Foundation

// MARK: - Timestamped

/// A generic wrapper that pairs any value with a `ContinuousClock.Instant` timestamp.
///
/// `Timestamped` is the foundational type for time-aware streaming operations. It enables
/// time-based windowing, multi-rate stream alignment, and frequency-domain analysis by
/// preserving the arrival time of each element in a stream.
///
/// RR intervals from a heart rate monitor, trading ticks, IoT sensor readings, and log
/// events are all examples of irregular-rate streams where the time between samples is
/// part of the signal. Without timestamps carried through the pipeline, time-based
/// operations are impossible.
///
/// - Parameters:
///   - Value: The type of the wrapped value. Must conform to `Sendable` for safe
///     use in concurrent streaming pipelines.
///
/// ## Usage Example
/// ```swift
/// let sample = Timestamped(value: 832.0)
/// print(sample.value)      // 832.0
/// print(sample.timestamp)  // ContinuousClock.Instant
/// ```
///
/// ## Topics
///
/// ### Creating Timestamped Values
/// - ``init(value:timestamp:)``
/// - ``init(value:)``
///
/// ### Accessing Properties
/// - ``value``
/// - ``timestamp``
public struct Timestamped<Value: Sendable>: Sendable {
    /// The wrapped value.
    public let value: Value

    /// The timestamp when this value was observed or received.
    public let timestamp: ContinuousClock.Instant

    /// Creates a timestamped value with an explicit timestamp.
    ///
    /// Use this initializer when the timestamp is known from an external source
    /// (e.g., a sensor providing its own clock).
    ///
    /// - Parameters:
    ///   - value: The value to wrap.
    ///   - timestamp: The timestamp to associate with the value.
    public init(value: Value, timestamp: ContinuousClock.Instant) {
        self.value = value
        self.timestamp = timestamp
    }

    /// Creates a timestamped value using the current time.
    ///
    /// Use this initializer when timestamping at the point of observation, such as
    /// when an element arrives from an async stream.
    ///
    /// - Parameter value: The value to wrap.
    public init(value: Value) {
        self.value = value
        self.timestamp = ContinuousClock.now
    }
}

// MARK: - AsyncTimestampedSequence

/// An async sequence that wraps each element from a base sequence with its arrival timestamp.
///
/// Created by calling `.timestamped()` on any `AsyncSequence` whose elements are `Sendable`.
/// Each element is paired with a `ContinuousClock.Instant` captured at the moment the
/// base iterator yields it.
///
/// ## Usage Example
/// ```swift
/// let values = AsyncValueStream([1.0, 2.0, 3.0])
/// for try await ts in values.timestamped() {
///     print("\(ts.value) arrived at \(ts.timestamp)")
/// }
/// ```
public struct AsyncTimestampedSequence<Base: AsyncSequence>: AsyncSequence where Base.Element: Sendable {
    /// The element type is a `Timestamped` wrapper around the base element.
    public typealias Element = Timestamped<Base.Element>

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base

    init(base: Base) {
        self.base = base
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields timestamped elements.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator())
    }

    /// Iterator that wraps each base element with a timestamp at the moment of arrival.
    ///
    /// Timestamps are captured using `ContinuousClock.now` immediately after the base
    /// iterator yields a value, ensuring monotonically non-decreasing timestamps under
    /// normal conditions.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator

        init(base: Base.AsyncIterator) {
            self.baseIterator = base
        }

        /// Advances to the next timestamped element.
        ///
        /// - Returns: The next element wrapped with its arrival timestamp, or `nil`
        ///   when the base sequence is exhausted.
        /// - Throws: Rethrows any error from the base sequence.
        public mutating func next() async throws -> Timestamped<Base.Element>? {
            guard let value = try await baseIterator.next() else { return nil }
            return Timestamped(value: value, timestamp: ContinuousClock.now)
        }
    }
}

// MARK: - AsyncSequence Extension

extension AsyncSequence where Element: Sendable {
    /// Wraps each element with a `ContinuousClock.Instant` timestamp at the moment of arrival.
    ///
    /// This operator is the entry point for time-aware streaming pipelines. Once elements
    /// are timestamped, they can be fed into time-based windowing (`.window(duration:)`),
    /// multi-rate alignment (`.aligned(with:strategy:)`), and frequency-domain analysis
    /// (`.fft()`).
    ///
    /// - Returns: An async sequence of `Timestamped<Element>` values.
    ///
    /// ## Usage Example
    /// ```swift
    /// let rrIntervals = AsyncValueStream([832.0, 845.0, 812.0])
    /// for try await ts in rrIntervals.timestamped() {
    ///     print("\(ts.value)ms at \(ts.timestamp)")
    /// }
    /// ```
    public func timestamped() -> AsyncTimestampedSequence<Self> {
        AsyncTimestampedSequence(base: self)
    }
}

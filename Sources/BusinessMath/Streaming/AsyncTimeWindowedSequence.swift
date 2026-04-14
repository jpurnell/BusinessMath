//
//  AsyncTimeWindowedSequence.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-05.
//

import Foundation
import Collections

// MARK: - Tumbling Time Window

/// An async sequence that groups timestamped elements into non-overlapping time windows.
///
/// Elements are collected until the elapsed time since the first element in the current
/// window exceeds the specified duration. The window is then emitted and a new one begins.
/// A partial window at the end of the stream is emitted on stream completion.
///
/// Unlike count-based windows, time windows handle irregular arrival rates correctly —
/// some windows may contain more elements than others depending on when they arrive.
///
/// ## Usage Example
/// ```swift
/// let rrIntervals = AsyncValueStream(rrTimestamped)
/// for try await window in rrIntervals.tumblingWindow(duration: .seconds(300)) {
///     let values = window.map(\.value)
///     print("5-minute window with \(values.count) beats")
/// }
/// ```
///
/// ## Mathematical Background
/// Window boundaries: `[t₀, t₀ + d), [t₀ + d, t₀ + 2d), ...`
/// where `t₀` is the timestamp of the first element and `d` is the duration.
///
/// - Note: Generalizes to OHLC bar construction from tick data, time-bucketed revenue
///   aggregation, and sensor data resampling.
public struct AsyncTumblingTimeWindowSequence<Base: AsyncSequence, V: Sendable>: AsyncSequence
    where Base.Element == Timestamped<V> {
    /// Yields arrays of timestamped elements within each time window.
    public typealias Element = [Timestamped<V>]

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let duration: Duration

    init(base: Base, duration: Duration) {
        self.base = base
        self.duration = duration
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields tumbling time windows.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), duration: duration)
    }

    /// Iterator for the tumbling time window sequence.
    ///
    /// Collects elements until elapsed time from window start exceeds the duration,
    /// then emits the window and starts a new one.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let duration: Duration
        private var currentWindow: [Timestamped<V>] = []
        private var windowStart: ContinuousClock.Instant?
        private var isComplete = false
        /// Holds the first element of the next window (the element that triggered closure of the previous one).
        private var pendingElement: Timestamped<V>?

        init(base: Base.AsyncIterator, duration: Duration) {
            self.baseIterator = base
            self.duration = duration
        }

        /// Advances to the next time window.
        ///
        /// Collects elements until one arrives with a timestamp beyond the current
        /// window boundary, then emits the collected window.
        ///
        /// - Returns: The next window of timestamped elements, or `nil` when the
        ///   stream is exhausted and no partial window remains.
        /// - Throws: Rethrows any error from the base sequence.
        public mutating func next() async throws -> [Timestamped<V>]? {
            guard !isComplete else { return nil }

            currentWindow = []
            windowStart = nil

            // If we have a pending element from the previous window closure, start with it
            if let pending = pendingElement {
                currentWindow.append(pending)
                windowStart = pending.timestamp
                pendingElement = nil
            }

            while !Task.isCancelled {
                guard let element = try await baseIterator.next() else {
                    // Stream exhausted — emit any remaining partial window
                    isComplete = true
                    if currentWindow.isEmpty {
                        return nil
                    }
                    return currentWindow
                }

                // Initialize window start from the first element
                if windowStart == nil {
                    windowStart = element.timestamp
                }

                guard let start = windowStart else {
                    // Should not reach here, but guard for safety
                    currentWindow.append(element)
                    continue
                }

                let elapsed = element.timestamp - start

                if elapsed >= duration {
                    // This element belongs to the next window
                    pendingElement = element

                    if currentWindow.isEmpty {
                        // Edge case: single element spans the entire window gap
                        // Start a new window with the pending element
                        currentWindow.append(element)
                        windowStart = element.timestamp
                        pendingElement = nil
                        continue
                    }

                    return currentWindow
                } else {
                    currentWindow.append(element)
                }
            }
            return nil
        }
    }
}

// MARK: - Sliding Time Window

/// An async sequence that groups timestamped elements into overlapping sliding time windows.
///
/// Windows overlap based on the stride parameter: with a duration of 300ms and stride of
/// 100ms, consecutive windows share 200ms of data. Each window is emitted when a new
/// element arrives that crosses the next stride boundary.
///
/// When `stride == duration`, this degenerates to tumbling (non-overlapping) behavior.
///
/// ## Usage Example
/// ```swift
/// let rrIntervals = AsyncValueStream(rrTimestamped)
/// for try await window in rrIntervals.slidingWindow(duration: .seconds(300), stride: .seconds(1)) {
///     let rmssd = computeRMSSD(window.map(\.value))
///     print("1-second update: RMSSD = \(rmssd)")
/// }
/// ```
///
/// - Note: Empty windows (stride intervals with no data) are NOT emitted.
public struct AsyncSlidingTimeWindowSequence<Base: AsyncSequence, V: Sendable>: AsyncSequence
    where Base.Element == Timestamped<V> {
    /// Yields arrays of timestamped elements within each sliding time window.
    public typealias Element = [Timestamped<V>]

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let duration: Duration
    private let stride: Duration

    init(base: Base, duration: Duration, stride: Duration) {
        self.base = base
        self.duration = duration
        self.stride = stride
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields sliding time windows.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), duration: duration, stride: stride)
    }

    /// Iterator for the sliding time window sequence.
    ///
    /// Maintains a buffer of all elements within the lookback period and emits
    /// filtered slices at each stride boundary.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let duration: Duration
        private let stride: Duration
        private var buffer: Deque<Timestamped<V>> = []
        private var nextEmitTime: ContinuousClock.Instant?
        private var referenceTime: ContinuousClock.Instant?
        private var isComplete = false
        private var pendingWindows: Deque<[Timestamped<V>]> = []

        init(base: Base.AsyncIterator, duration: Duration, stride: Duration) {
            self.baseIterator = base
            self.duration = duration
            self.stride = stride
        }

        /// Advances to the next sliding time window.
        ///
        /// Consumes elements and emits windows at stride boundaries. Each window
        /// contains all buffered elements within the duration lookback from the
        /// emission point.
        ///
        /// - Returns: The next sliding window, or `nil` when the stream is exhausted.
        /// - Throws: Rethrows any error from the base sequence.
        public mutating func next() async throws -> [Timestamped<V>]? {
            guard !isComplete else { return nil }

            // Return any pending windows from previous iteration
            if let pending = pendingWindows.popFirst() {
                return pending
            }

            while !Task.isCancelled {
                guard let element = try await baseIterator.next() else {
                    // Stream exhausted — emit final window if buffer has data
                    isComplete = true
                    if buffer.isEmpty {
                        return nil
                    }
                    // Emit remaining buffer as final window
                    let finalWindow = Array(buffer)
                    buffer.removeAll()
                    return finalWindow
                }

                // Initialize reference time from first element
                if referenceTime == nil {
                    referenceTime = element.timestamp
                    nextEmitTime = element.timestamp + stride
                }

                buffer.append(element)

                guard let emitTime = nextEmitTime else { continue }

                // Emit windows for all stride boundaries this element crosses
                while element.timestamp >= emitTime {
                    let windowEnd = nextEmitTime ?? emitTime
                    let windowStart = windowEnd - duration

                    // Filter buffer to elements within [windowStart, windowEnd)
                    let window = Array(buffer.filter { ts in
                        ts.timestamp >= windowStart && ts.timestamp < windowEnd
                    })

                    // Only emit non-empty windows
                    if window.isEmpty == false {
                        pendingWindows.append(window)
                    }

                    nextEmitTime = nextEmitTime.map { $0 + stride }

                    guard let next = nextEmitTime else { break }
                    if element.timestamp < next { break }
                }

                // Evict elements that are too old to appear in any future window
                if let emitRef = nextEmitTime {
                    let oldestUseful = emitRef - duration
                    while let first = buffer.first, first.timestamp < oldestUseful {
                        buffer.removeFirst()
                    }
                }

                // Return first pending window if available
                if let pending = pendingWindows.popFirst() {
                    return pending
                }
            }
            return nil
        }
    }
}

// MARK: - Time Window Extensions

extension AsyncSequence {
    /// Groups timestamped elements into non-overlapping time windows.
    ///
    /// Each window collects elements until the elapsed time since the first element
    /// exceeds the specified duration. Handles irregular arrival rates correctly.
    ///
    /// - Parameter duration: The time span of each window.
    /// - Returns: An async sequence of element arrays, one per time window.
    ///
    /// ## Usage Example
    /// ```swift
    /// let rrIntervals = AsyncValueStream(timestampedValues)
    /// for try await window in rrIntervals.tumblingWindow(duration: .seconds(300)) {
    ///     print("Window has \(window.count) elements")
    /// }
    /// ```
    public func tumblingWindow<V: Sendable>(
        duration: Duration
    ) -> AsyncTumblingTimeWindowSequence<Self, V> where Element == Timestamped<V> {
        AsyncTumblingTimeWindowSequence(base: self, duration: duration)
    }

    /// Groups timestamped elements into overlapping sliding time windows.
    ///
    /// Windows are emitted at each stride boundary, containing all elements within the
    /// duration lookback. When `stride == duration`, this degenerates to tumbling behavior.
    ///
    /// - Parameters:
    ///   - duration: The time span of each window.
    ///   - stride: The time between consecutive window start points.
    /// - Returns: An async sequence of element arrays, one per sliding window.
    ///
    /// ## Usage Example
    /// ```swift
    /// let rrIntervals = AsyncValueStream(timestampedValues)
    /// // 5-minute windows, updating every second
    /// for try await window in rrIntervals.slidingWindow(duration: .seconds(300), stride: .seconds(1)) {
    ///     print("Sliding window: \(window.count) elements")
    /// }
    /// ```
    public func slidingWindow<V: Sendable>(
        duration: Duration,
        stride: Duration
    ) -> AsyncSlidingTimeWindowSequence<Self, V> where Element == Timestamped<V> {
        AsyncSlidingTimeWindowSequence(base: self, duration: duration, stride: stride)
    }
}

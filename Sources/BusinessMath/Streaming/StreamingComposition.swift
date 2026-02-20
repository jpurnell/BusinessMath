//
//  StreamingComposition.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-30.
//

import Foundation

// MARK: - Swift 6 Concurrency Compliance
//
// This file achieves full Swift 6 strict concurrency compliance using several established patterns:
//
// ## 1. @unchecked Sendable on Iterator Types
// Iterator types that hold AsyncStream/AsyncThrowingStream are marked `@unchecked Sendable`.
// This is safe because:
// - Iterators are accessed sequentially through their `next()` method
// - AsyncStream.AsyncIterator itself is not Sendable (implementation detail)
// - No concurrent access to iterator state occurs in practice
//
// ## 2. ContinuationBox Wrapper Pattern
// ContinuationBox and ThrowingContinuationBox wrap AsyncStream.Continuation to enable
// safe concurrent access from multiple tasks:
// - Marked `@unchecked Sendable` with immutable continuation reference
// - AsyncStream internally serializes all yields through its own queue
// - Prevents "reference to captured var 'continuation'" warnings
// - Similar pattern to existing CalculationCacheAsync in codebase
//
// ## 3. ThreadSafeBox (Actor) for Shared State
// When multiple tasks need to share mutable state (e.g., latest values in combineLatest):
// - ThreadSafeBox actor ensures synchronized access
// - Actor isolation provides proper Swift concurrency guarantees
// - Used for values that must be read/written from concurrent tasks
//
// ## 4. Iterator Pre-creation Pattern
// Iterators are created BEFORE Task blocks to minimize metatype capture warnings:
//   let iterator = base.makeAsyncIterator()
//   Task {
//       var iter = iterator  // Safer than creating inside Task
//   }
//
// ## 5. Element: Sendable Constraints
// AsyncSequence operations that send elements across isolation boundaries require
// Element: Sendable constraints. This ensures values can safely cross task boundaries.
//
// ## 6. @Sendable Closure Annotations
// Task and addTask closures are explicitly marked @Sendable to document sendability
// requirements and satisfy Swift 6 checking.
//
// For more on Swift 6 concurrency:
// https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency

// MARK: - Timeout Error

/// Error thrown when a stream operation exceeds its time limit.
///
/// Indicates that a stream element did not arrive within the expected duration.
/// This error is thrown by ``AsyncTimeoutSequence`` when the time between consecutive
/// elements exceeds the configured timeout duration.
///
/// ### Example
/// ```swift
/// do {
///     let stream = AsyncValueStream([1, 2, 3])
///     for try await value in stream.timeout(duration: .seconds(1)) {
///         print(value)
///     }
/// } catch let error as TimeoutError {
///     print("Stream timed out after \(error.duration)")
/// }
/// ```
///
/// - SeeAlso: ``AsyncTimeoutSequence``
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct TimeoutError: Error, Sendable {
    /// The duration that was exceeded.
    public let duration: Duration

    /// Creates a timeout error.
    ///
    /// - Parameter duration: The timeout duration that was exceeded.
    public init(duration: Duration) {
        self.duration = duration
    }
}

// MARK: - AsyncSequence Extensions for Stream Composition

extension AsyncSequence {

    /// Merges this stream with another stream, emitting values from both as they arrive
    public func merge<Other: AsyncSequence>(with other: Other) -> AsyncMergeSequence<Self, Other> where Other.Element == Element {
        AsyncMergeSequence(first: self, second: other)
    }

    /// Zips this stream with another stream, emitting paired values
    public func zip<Other: AsyncSequence>(with other: Other) -> AsyncZipSequence<Self, Other> {
        AsyncZipSequence(first: self, second: other)
    }

    /// Debounces the stream, only emitting values after the specified interval of silence.
    ///
    /// Creates a sequence that delays emission until a period of inactivity passes. Each new
    /// value resets the timer. Only emits the most recent value once the stream has been quiet
    /// for the full interval duration. Useful for rate-limiting rapid updates (e.g., search-as-you-type).
    ///
    /// - Parameter interval: Duration of silence required before emitting
    /// - Returns: AsyncDebounceSequence that emits values after quiet periods
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public func debounce(interval: Duration) -> AsyncDebounceSequence<Self> where Self: Sendable, Element: Sendable {
        AsyncDebounceSequence(base: self, interval: interval)
    }

    /// Combines latest values from both streams, emitting when either updates
    public func combineLatest<Other: AsyncSequence>(with other: Other) -> AsyncCombineLatestSequence<Self, Other> where Self: Sendable, Element: Sendable, Other: Sendable, Other.Element: Sendable {
        AsyncCombineLatestSequence(first: self, second: other)
    }

    /// Samples the other stream whenever this stream emits
    public func withLatestFrom<Other: AsyncSequence>(_ other: Other) -> AsyncWithLatestFromSequence<Self, Other> where Self: Sendable, Other: Sendable, Other.Element: Sendable {
        AsyncWithLatestFromSequence(trigger: self, sampled: other)
    }

    /// Removes consecutive duplicate values
    public func distinct() -> AsyncDistinctSequence<Self> where Element: Equatable {
        AsyncDistinctSequence(base: self)
    }

    /// Removes consecutive duplicates using custom comparator
    public func distinctUntilChanged(by comparator: @escaping @Sendable (Element, Element) -> Bool) -> AsyncDistinctUntilChangedSequence<Self> {
        AsyncDistinctUntilChangedSequence(base: self, comparator: comparator)
    }

    /// Prepends an initial value to the stream
    public func startWith(_ value: Element) -> AsyncStartWithSequence<Self> {
        AsyncStartWithSequence(base: self, initialValue: value)
    }

    /// Samples the stream at regular intervals, emitting the latest value at each interval.
    ///
    /// Creates a sequence that periodically emits the most recent value from the base stream.
    /// The sampling timer runs independently of the base stream's emission rate. If no new
    /// values have arrived since the last sample, the previous value is emitted again.
    ///
    /// - Parameter interval: Time between samples
    /// - Returns: AsyncSampleSequence that emits values at regular intervals
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public func sample(interval: Duration) -> AsyncSampleSequence<Self> where Self: Sendable, Element: Sendable {
        AsyncSampleSequence(base: self, interval: interval)
    }

    /// Takes only the first N elements
    public func take(_ count: Int) -> AsyncTakeSequence<Self> {
        AsyncTakeSequence(base: self, count: count)
    }

    /// Skips the first N elements
    public func skip(_ count: Int) -> AsyncSkipSequence<Self> {
        AsyncSkipSequence(base: self, count: count)
    }

    /// Takes elements while condition holds
    public func takeWhile(_ predicate: @escaping @Sendable (Element) -> Bool) -> AsyncTakeWhileSequence<Self> {
        AsyncTakeWhileSequence(base: self, predicate: predicate)
    }

    /// Skips elements while condition holds
    public func skipWhile(_ predicate: @escaping @Sendable (Element) -> Bool) -> AsyncSkipWhileSequence<Self> {
        AsyncSkipWhileSequence(base: self, predicate: predicate)
    }

    /// Adds a timeout to stream operations, throwing an error if elements don't arrive within the specified duration.
    ///
    /// Enforces a maximum time between consecutive elements. If the specified duration passes without
    /// receiving the next element, throws ``TimeoutError``. Natural stream completion (nil) does not
    /// trigger a timeout.
    ///
    /// - Parameter duration: Maximum time to wait between elements
    /// - Returns: AsyncTimeoutSequence that wraps this stream with timeout enforcement
    /// - Throws: ``TimeoutError`` if duration expires between elements
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public func timeout(duration: Duration) -> AsyncTimeoutSequence<Self> where Element: Sendable {
        AsyncTimeoutSequence(base: self, duration: duration)
    }
}

// MARK: - Merge

/// AsyncSequence that merges values from two streams as they arrive.
///
/// Combines two asynchronous streams into one, emitting values from either stream
/// as soon as they become available. Both streams are consumed concurrently, and
/// the merged stream completes when both input streams complete. Order of emission
/// depends on the timing of values from each stream.
///
/// ### Example
/// ```swift
/// let prices = AsyncValueStream([100.0, 101.0, 102.0])
/// let volumes = AsyncValueStream([1000.0, 1500.0, 2000.0])
///
/// for try await value in prices.merge(with: volumes) {
///     print("Trading data: \(value)")
/// }
/// // Output (order depends on timing):
/// // Trading data: 100.0
/// // Trading data: 1000.0
/// // Trading data: 101.0
/// // Trading data: 1500.0
/// // ...
/// ```
///
/// ### Use Cases
/// - Combining multiple data sources (e.g., stock prices from different exchanges)
/// - Aggregating event streams from different sensors
/// - Merging user interaction events from multiple UI components
/// - Consolidating log streams from different services
///
/// ### Technical Notes
/// - Uses task group to consume both streams concurrently
/// - Memory usage: O(1) - only stores AsyncStream continuation
/// - Both streams are consumed independently; slower stream doesn't block faster one
/// - Values are yielded immediately as they arrive from either stream
///
/// - SeeAlso: ``AsyncZipSequence``, ``AsyncCombineLatestSequence``
public struct AsyncMergeSequence<First: AsyncSequence, Second: AsyncSequence>: AsyncSequence where First.Element == Second.Element, First.Element: Sendable, First.AsyncIterator: Sendable, Second.AsyncIterator: Sendable {
    /// The merged element type (same as both input streams).
    public typealias Element = First.Element

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let first: First
    private let second: Second

    init(first: First, second: Second) {
        self.first = first
        self.second = second
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields values from both streams as they arrive.
    public func makeAsyncIterator() -> Iterator {
        Iterator(first: first, second: second)
    }

    /// Iterator that merges values from two async sequences.
    ///
    /// Consumes both input streams concurrently using a task group and yields
    /// values from either stream as they arrive through an internal channel.
    public struct Iterator: AsyncIteratorProtocol, @unchecked Sendable {
        private let channel: AsyncStream<Element>
        private var iterator: AsyncStream<Element>.AsyncIterator

        init(first: First, second: Second) {
            // Use AsyncStream as a channel to merge values from both streams
            // SAFETY: ContinuationBox allows safe concurrent access to continuation
            // from multiple task group children. The AsyncStream serializes yields.
            let (channel, continuationBox): (AsyncStream<Element>, ContinuationBox<Element>) = {
                var box: ContinuationBox<Element>!
                let ch = AsyncStream<Element> { cont in
                    box = ContinuationBox(cont)
                }
                return (ch, box!)
            }()
            self.channel = channel
            iterator = channel.makeAsyncIterator()

            // Create iterators before Task to avoid capturing metatypes
            let firstIterator = first.makeAsyncIterator()
            let secondIterator = second.makeAsyncIterator()

            // Start tasks to consume both streams
            Task { @Sendable in
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { @Sendable in
                        var iter = firstIterator
                        while let value = try? await iter.next() {
                            continuationBox.yield(value)
                        }
                    }

                    group.addTask { @Sendable in
                        var iter = secondIterator
                        while let value = try? await iter.next() {
                            continuationBox.yield(value)
                        }
                    }

                    await group.waitForAll()
                    continuationBox.finish()
                }
            }
        }

        /// Advances to the next merged element.
        ///
        /// - Returns: The next value from either stream, or `nil` when both streams complete.
        public mutating func next() async throws -> Element? {
            return await iterator.next()
        }
    }
}

// MARK: - Zip

/// AsyncSequence that pairs corresponding elements from two streams.
///
/// Combines two asynchronous streams by pairing their elements in order. Emits tuples
/// containing one element from each stream, waiting for both values before emitting
/// the pair. The zipped stream completes when either input stream completes.
///
/// ### Example
/// ```swift
/// let timestamps = AsyncValueStream([1.0, 2.0, 3.0, 4.0])
/// let values = AsyncValueStream([100.0, 200.0, 300.0])
///
/// for try await (time, value) in timestamps.zip(with: values) {
///     print("Time: \(time), Value: \(value)")
/// }
/// // Output:
/// // Time: 1.0, Value: 100.0
/// // Time: 2.0, Value: 200.0
/// // Time: 3.0, Value: 300.0
/// // (stops at 3 pairs - shorter stream determines length)
/// ```
///
/// ### Use Cases
/// - Pairing timestamps with sensor readings
/// - Combining feature vectors from different data sources
/// - Synchronizing related data streams for processing
/// - Creating coordinate pairs from separate X and Y streams
///
/// ### Technical Notes
/// - Memory usage: O(1) - only stores iterator state
/// - Waits for both streams synchronously; slower stream determines pace
/// - Completes when the shorter stream ends (unpaired elements are discarded)
/// - Elements are paired in their arrival order
///
/// - SeeAlso: ``AsyncMergeSequence``, ``AsyncCombineLatestSequence``
public struct AsyncZipSequence<First: AsyncSequence, Second: AsyncSequence>: AsyncSequence {
    /// The paired element type (tuple of both input types).
    public typealias Element = (First.Element, Second.Element)

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let first: First
    private let second: Second

    init(first: First, second: Second) {
        self.first = first
        self.second = second
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields paired elements from both streams.
    public func makeAsyncIterator() -> Iterator {
        Iterator(first: first.makeAsyncIterator(), second: second.makeAsyncIterator())
    }

    /// Iterator that pairs elements from two async sequences.
    ///
    /// Waits for one element from each stream before emitting the pair.
    /// Completes when either stream ends.
    public struct Iterator: AsyncIteratorProtocol {
        private var firstIterator: First.AsyncIterator
        private var secondIterator: Second.AsyncIterator

        init(first: First.AsyncIterator, second: Second.AsyncIterator) {
            self.firstIterator = first
            self.secondIterator = second
        }

        /// Advances to the next paired element.
        ///
        /// - Returns: A tuple containing one element from each stream, or `nil` when either stream completes.
        public mutating func next() async throws -> Element? {
            guard let first = try await firstIterator.next(),
                  let second = try await secondIterator.next() else {
                return nil
            }
            return (first, second)
        }
    }
}

// MARK: - Debounce

/// AsyncSequence that emits values only after a period of silence.
///
/// Delays emission until no new values arrive for the specified duration. Each new
/// value cancels the previous timer and starts a new countdown. Only emits when the
/// stream remains quiet for the full interval. Ideal for reducing rapid-fire events
/// to meaningful changes.
///
/// ### Example
/// ```swift
/// let searchQuery = AsyncValueStream(["a", "ap", "app", "appl", "apple"])
/// // Assume rapid typing with < 300ms between keystrokes
///
/// for try await query in searchQuery.debounce(interval: .milliseconds(300)) {
///     print("Search for: \(query)")
/// }
/// // Output (only after typing stops):
/// // Search for: apple
/// ```
///
/// ### Use Cases
/// - Search-as-you-type with API calls (prevent request spam)
/// - Window resize handlers (only respond after resizing stops)
/// - Auto-save triggers (save after user stops editing)
/// - Rate limiting user input (button clicks, form changes)
///
/// ### Parameter Guidance
/// - **interval**: Silence duration before emission
///   - UI input: 200-500ms (responsive but not too sensitive)
///   - Auto-save: 1-3 seconds (balance between safety and performance)
///   - API throttling: 500-1000ms (depends on rate limits)
///
/// ### Technical Notes
/// - Memory usage: O(1) - stores only the latest value
/// - Each new value cancels the previous debounce timer
/// - Uses actor-based state management for thread safety
/// - Final value emitted after stream completes if timer is active
///
/// - SeeAlso: ``AsyncSampleSequence``, ``AsyncDistinctUntilChangedSequence``
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct AsyncDebounceSequence<Base: AsyncSequence & Sendable>: AsyncSequence, Sendable where Base.Element: Sendable {
    /// The debounced element type.
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
    /// - Returns: An iterator that yields values after silence periods.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base, interval: interval)
    }

    /// Iterator that debounces values from an async sequence.
    ///
    /// Maintains a timer that is reset with each new value. Only emits when
    /// the timer completes without being interrupted by a new value.
    public struct Iterator: AsyncIteratorProtocol, @unchecked Sendable {
        private let channel: AsyncStream<Element>
        private var iterator: AsyncStream<Element>.AsyncIterator

        init(base: Base, interval: Duration) {
            // SAFETY: ContinuationBox allows safe concurrent access from debounce tasks
            let (channel, continuationBox): (AsyncStream<Element>, ContinuationBox<Element>) = {
                var box: ContinuationBox<Element>!
                let ch = AsyncStream<Element> { cont in
                    box = ContinuationBox(cont)
                }
                return (ch, box!)
            }()
            self.channel = channel
            iterator = channel.makeAsyncIterator()

            Task { @Sendable in
                var baseIterator = base.makeAsyncIterator()

                // Create actor for safe state management
                let state = DebounceState<Element>()

                while let value = try? await baseIterator.next() {
                    // Update state through actor
                    await state.updateValue(value)

                    // Create new debounce task and store in actor
                    let debounceTask = Task { @Sendable in
                        try? await Task.sleep(for: interval)
                        if !Task.isCancelled {
                            // Safely read value through actor
                            if let val = await state.getValue() {
                                continuationBox.yield(val)
                            }
                        }
                    }

                    // Store task in actor (cancels previous)
                    await state.setDebounceTask(debounceTask)
                }

                // Wait for final debounce through actor
                await state.waitForDebounce()
                continuationBox.finish()
            }
        }

        /// Advances to the next debounced element.
        ///
        /// - Returns: The next value after a silence period, or `nil` when the stream completes.
        public mutating func next() async throws -> Element? {
            return await iterator.next()
        }
    }
}

// MARK: - CombineLatest

/// AsyncSequence that combines the latest values from two streams.
///
/// Emits a tuple whenever either stream produces a value, combining it with the most
/// recent value from the other stream. Requires both streams to emit at least once
/// before producing the first output. Ideal for coordinating related data sources
/// that update independently.
///
/// ### Example
/// ```swift
/// let temperature = AsyncValueStream([20.0, 21.0, 22.0])
/// let humidity = AsyncValueStream([45.0, 50.0])
///
/// for try await (temp, humid) in temperature.combineLatest(with: humidity) {
///     print("Temp: \(temp)°C, Humidity: \(humid)%")
/// }
/// // Output (assuming interleaved emissions):
/// // Temp: 20.0°C, Humidity: 45.0%  (both have emitted)
/// // Temp: 21.0°C, Humidity: 45.0%  (temp updates)
/// // Temp: 21.0°C, Humidity: 50.0%  (humidity updates)
/// // Temp: 22.0°C, Humidity: 50.0%  (temp updates)
/// ```
///
/// ### Use Cases
/// - Coordinating UI state from multiple sources (user input + server data)
/// - Combining sensor readings for multi-parameter analysis
/// - Reactive forms that validate on any field change
/// - Dashboard widgets that display related metrics
///
/// ### Technical Notes
/// - Memory usage: O(1) - stores only the latest value from each stream
/// - Both streams are consumed concurrently using task group
/// - First emission requires both streams to have emitted at least once
/// - Uses actor-based storage for thread-safe latest value access
/// - Completes when both streams complete
///
/// - SeeAlso: ``AsyncWithLatestFromSequence``, ``AsyncZipSequence``
public struct AsyncCombineLatestSequence<First: AsyncSequence & Sendable, Second: AsyncSequence & Sendable>: AsyncSequence where First.Element: Sendable, Second.Element: Sendable {
    /// The combined element type (tuple of latest values from both streams).
    public typealias Element = (First.Element, Second.Element)

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let first: First
    private let second: Second

    init(first: First, second: Second) {
        self.first = first
        self.second = second
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields combined latest values.
    public func makeAsyncIterator() -> Iterator {
        Iterator(first: first, second: second)
    }

    /// Iterator that combines latest values from two async sequences.
    ///
    /// Tracks the most recent value from each stream and emits a combined
    /// tuple whenever either stream updates.
    public struct Iterator: AsyncIteratorProtocol, @unchecked Sendable {
        private let channel: AsyncStream<Element>
        private var iterator: AsyncStream<Element>.AsyncIterator

        init(first: First, second: Second) {
            // SAFETY: ContinuationBox allows safe concurrent access from task group children
            // ThreadSafeBox (actor) provides synchronized access to latest values
            let (channel, continuationBox): (AsyncStream<Element>, ContinuationBox<Element>) = {
                var box: ContinuationBox<Element>!
                let ch = AsyncStream<Element> { cont in
                    box = ContinuationBox(cont)
                }
                return (ch, box!)
            }()
            self.channel = channel
            iterator = channel.makeAsyncIterator()

            Task { @Sendable in
                let firstLatest = ThreadSafeBox<First.Element?>(nil)
                let secondLatest = ThreadSafeBox<Second.Element?>(nil)

                await withTaskGroup(of: Void.self) { group in
                    group.addTask { @Sendable in
                        var iter = first.makeAsyncIterator()
                        while let value = try? await iter.next() {
                            await firstLatest.setValue(value)
                            if let second = await secondLatest.getValue() {
                                continuationBox.yield((value, second))
                            }
                        }
                    }

                    group.addTask { @Sendable in
                        var iter = second.makeAsyncIterator()
                        while let value = try? await iter.next() {
                            await secondLatest.setValue(value)
                            if let first = await firstLatest.getValue() {
                                continuationBox.yield((first, value))
                            }
                        }
                    }

                    await group.waitForAll()
                    continuationBox.finish()
                }
            }
        }

        /// Advances to the next combined element.
        ///
        /// - Returns: A tuple of the latest values from both streams, or `nil` when both streams complete.
        public mutating func next() async throws -> Element? {
            return await iterator.next()
        }
    }
}

// MARK: - WithLatestFrom

/// AsyncSequence that samples one stream whenever another stream emits.
///
/// Uses one stream as a trigger to sample values from another stream. Each time the
/// trigger stream emits, the sequence outputs the most recent value from the sampled
/// stream. The trigger values themselves are discarded - only the sampled values are
/// emitted. Requires the sampled stream to have emitted at least once.
///
/// ### Example
/// ```swift
/// let buttonTaps = AsyncValueStream([(), (), ()])  // User taps
/// let currentPrice = AsyncValueStream([100.0, 102.0, 101.0, 103.0])
///
/// for try await price in buttonTaps.withLatestFrom(currentPrice) {
///     print("Price at tap: \(price)")
/// }
/// // Output (depends on timing):
/// // Price at tap: 102.0  (first tap after price updates)
/// // Price at tap: 102.0  (second tap, same price)
/// // Price at tap: 103.0  (third tap, new price)
/// ```
///
/// ### Use Cases
/// - Sampling current state on user actions (snapshot on button click)
/// - Capturing context when events occur (get user location on photo)
/// - Form submission with latest field values
/// - Periodic reporting of continuously updating metrics
///
/// ### Technical Notes
/// - Memory usage: O(1) - stores only the latest sampled value
/// - Both streams run concurrently; sampled stream updates continuously
/// - Trigger values are discarded; only sampled values are emitted
/// - First emission requires sampled stream to have emitted at least once
/// - Uses actor-based storage for thread-safe value access
///
/// - SeeAlso: ``AsyncCombineLatestSequence``, ``AsyncSampleSequence``
public struct AsyncWithLatestFromSequence<Trigger: AsyncSequence, Sampled: AsyncSequence>: AsyncSequence where Trigger: Sendable, Sampled: Sendable, Sampled.Element: Sendable, Trigger.AsyncIterator: Sendable, Sampled.AsyncIterator: Sendable {
    /// The sampled element type.
    public typealias Element = Sampled.Element

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let trigger: Trigger
    private let sampled: Sampled

    init(trigger: Trigger, sampled: Sampled) {
        self.trigger = trigger
        self.sampled = sampled
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields sampled values when triggered.
    public func makeAsyncIterator() -> Iterator {
        Iterator(trigger: trigger, sampled: sampled)
    }

    /// Iterator that samples one stream based on emissions from another.
    ///
    /// Continuously updates the latest sampled value and emits it whenever
    /// the trigger stream produces an element.
    public struct Iterator: AsyncIteratorProtocol, @unchecked Sendable {
        private let channel: AsyncStream<Element>
        private var iterator: AsyncStream<Element>.AsyncIterator

        init(trigger: Trigger, sampled: Sampled) {
            // SAFETY: ContinuationBox allows safe concurrent access from task group children
            // ThreadSafeBox (actor) provides synchronized access to latest sampled value
            let (channel, continuationBox): (AsyncStream<Element>, ContinuationBox<Element>) = {
                var box: ContinuationBox<Element>!
                let ch = AsyncStream<Element> { cont in
                    box = ContinuationBox(cont)
                }
                return (ch, box!)
            }()
            self.channel = channel
            iterator = channel.makeAsyncIterator()

            // Create iterators before Task to avoid capturing metatypes
            let triggerIterator = trigger.makeAsyncIterator()
            let sampledIterator = sampled.makeAsyncIterator()

            Task { @Sendable in
                let latestSampled = ThreadSafeBox<Sampled.Element?>(nil)

                await withTaskGroup(of: Void.self) { group in
                    group.addTask { @Sendable in
                        var iter = triggerIterator
                        while let _ = try? await iter.next() {
                            if let value = await latestSampled.getValue() {
                                continuationBox.yield(value)
                            }
                        }
                    }

                    group.addTask { @Sendable in
                        var iter = sampledIterator
                        while let value = try? await iter.next() {
                            await latestSampled.setValue(value)
                        }
                    }

                    await group.waitForAll()
                    continuationBox.finish()
                }
            }
        }

        /// Advances to the next sampled element.
        ///
        /// - Returns: The latest sampled value when triggered, or `nil` when the trigger stream completes.
        public mutating func next() async throws -> Element? {
            return await iterator.next()
        }
    }
}

// MARK: - Distinct

/// AsyncSequence that removes consecutive duplicate values.
///
/// Filters out consecutive duplicate elements, only emitting when the value changes
/// from the previous element. Uses equality comparison (requires `Equatable` elements).
/// Useful for reducing redundant updates and focusing on meaningful state changes.
///
/// ### Example
/// ```swift
/// let stream = AsyncValueStream([1, 1, 2, 2, 2, 3, 1, 1])
///
/// for try await value in stream.distinct() {
///     print(value)
/// }
/// // Output:
/// // 1
/// // 2
/// // 3
/// // 1
/// ```
///
/// ### Use Cases
/// - Filtering redundant sensor readings that haven't changed
/// - Removing duplicate UI state updates
/// - Optimizing database write operations (only save on change)
/// - Reducing network traffic by skipping repeated values
///
/// ### Technical Notes
/// - Memory usage: O(1) - stores only the previous value
/// - Only filters consecutive duplicates (non-consecutive duplicates are preserved)
/// - Requires `Equatable` conformance for element type
/// - First element always passes through
///
/// - SeeAlso: ``AsyncDistinctUntilChangedSequence``
public struct AsyncDistinctSequence<Base: AsyncSequence>: AsyncSequence where Base.Element: Equatable {
    /// The distinct element type.
    public typealias Element = Base.Element

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base

    init(base: Base) {
        self.base = base
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields values only when they differ from the previous value.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator())
    }

    /// Iterator that filters consecutive duplicate values.
    ///
    /// Compares each value to the previous one using equality and only
    /// emits when they differ.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private var lastValue: Base.Element?

        init(base: Base.AsyncIterator) {
            self.baseIterator = base
        }

        /// Advances to the next distinct element.
        ///
        /// - Returns: The next value that differs from the previous one, or `nil` when the stream completes.
        public mutating func next() async throws -> Element? {
            while let value = try await baseIterator.next() {
                if let last = lastValue, last == value {
                    continue  // Skip duplicate
                }
                lastValue = value
                return value
            }
            return nil
        }
    }
}

// MARK: - DistinctUntilChanged

/// AsyncSequence that removes consecutive duplicates using a custom comparator.
///
/// Filters out consecutive duplicate elements using a custom comparison function.
/// More flexible than ``AsyncDistinctSequence`` as it works with non-Equatable types
/// and allows custom equality logic (e.g., fuzzy matching, partial comparison).
///
/// ### Example
/// ```swift
/// struct Reading {
///     let value: Double
///     let timestamp: Date
/// }
///
/// let readings = AsyncValueStream([
///     Reading(value: 100.0, timestamp: date1),
///     Reading(value: 100.5, timestamp: date2),  // Within tolerance
///     Reading(value: 105.0, timestamp: date3)   // Significant change
/// ])
///
/// // Only emit when value changes by more than 1.0
/// for try await reading in readings.distinctUntilChanged(by: { abs($0.value - $1.value) < 1.0 }) {
///     print("Significant reading: \(reading.value)")
/// }
/// // Output:
/// // Significant reading: 100.0
/// // Significant reading: 105.0
/// ```
///
/// ### Use Cases
/// - Fuzzy deduplication (ignore minor variations)
/// - Custom equality for complex types
/// - Threshold-based filtering (only emit on significant changes)
/// - Case-insensitive string deduplication
///
/// ### Technical Notes
/// - Memory usage: O(1) - stores only the previous value
/// - Comparator returns `true` if values should be considered equal
/// - Only filters consecutive duplicates
/// - First element always passes through
///
/// - SeeAlso: ``AsyncDistinctSequence``
public struct AsyncDistinctUntilChangedSequence<Base: AsyncSequence>: AsyncSequence {
    /// The distinct element type.
    public typealias Element = Base.Element

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let comparator: @Sendable (Element, Element) -> Bool

    init(base: Base, comparator: @escaping @Sendable (Element, Element) -> Bool) {
        self.base = base
        self.comparator = comparator
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields values when the comparator indicates a change.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), comparator: comparator)
    }

    /// Iterator that filters consecutive duplicates using a custom comparator.
    ///
    /// Uses the provided comparison function to determine if consecutive
    /// values should be considered equal.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let comparator: @Sendable (Base.Element, Base.Element) -> Bool
        private var lastValue: Base.Element?

        init(base: Base.AsyncIterator, comparator: @escaping @Sendable (Base.Element, Base.Element) -> Bool) {
            self.baseIterator = base
            self.comparator = comparator
        }

        /// Advances to the next distinct element.
        ///
        /// - Returns: The next value that the comparator indicates differs from the previous one, or `nil` when the stream completes.
        public mutating func next() async throws -> Element? {
            while let value = try await baseIterator.next() {
                if let last = lastValue, comparator(last, value) {
                    continue  // Skip if comparator says they're equal
                }
                lastValue = value
                return value
            }
            return nil
        }
    }
}

// MARK: - StartWith

/// AsyncSequence that prepends an initial value before the base stream.
///
/// Emits a specified value immediately, then emits all values from the base stream.
/// Useful for providing default states, seed values, or ensuring consumers have
/// an initial value before the stream produces its first element.
///
/// ### Example
/// ```swift
/// let updates = AsyncValueStream([2, 3, 4])
///
/// for try await value in updates.startWith(1) {
///     print(value)
/// }
/// // Output:
/// // 1  (initial value)
/// // 2
/// // 3
/// // 4
/// ```
///
/// ### Use Cases
/// - Providing default/initial state before updates arrive
/// - Ensuring UI has a value to display immediately
/// - Seeding calculations with a starting value
/// - Testing stream behavior with known first value
///
/// ### Technical Notes
/// - Memory usage: O(1) - stores initial value and emission flag
/// - Initial value emitted synchronously on first call to `next()`
/// - After initial value, passes through base stream unchanged
/// - Completes when base stream completes
///
/// - SeeAlso: ``AsyncMergeSequence``
public struct AsyncStartWithSequence<Base: AsyncSequence>: AsyncSequence {
    /// The element type (same as base stream).
    public typealias Element = Base.Element

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let initialValue: Element

    init(base: Base, initialValue: Element) {
        self.base = base
        self.initialValue = initialValue
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields the initial value first, then base stream values.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), initialValue: initialValue)
    }

    /// Iterator that prepends an initial value to a stream.
    ///
    /// Emits the initial value on the first call to `next()`, then
    /// delegates to the base iterator.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private var hasEmittedInitial = false
        private let initialValue: Base.Element

        init(base: Base.AsyncIterator, initialValue: Base.Element) {
            self.baseIterator = base
            self.initialValue = initialValue
        }

        /// Advances to the next element.
        ///
        /// - Returns: The initial value on first call, then base stream values, or `nil` when the stream completes.
        public mutating func next() async throws -> Element? {
            if !hasEmittedInitial {
                hasEmittedInitial = true
                return initialValue
            }
            return try await baseIterator.next()
        }
    }
}

// MARK: - Sample

/// AsyncSequence that emits the latest value at regular intervals.
///
/// Periodically samples the most recent value from the base stream at fixed time
/// intervals. Between samples, the latest value is tracked but not emitted. Useful
/// for rate-limiting fast streams and creating periodic snapshots of changing values.
///
/// ### Example
/// ```swift
/// // Rapidly changing price stream
/// let prices = AsyncValueStream([100.0, 101.0, 102.0, 103.0, 104.0])
///
/// // Sample every second (assuming prices update faster)
/// for try await price in prices.sample(interval: .seconds(1)) {
///     print("Current price: \(price)")
/// }
/// // Output (every 1 second):
/// // Current price: 102.0  (latest at first sample)
/// // Current price: 104.0  (latest at second sample)
/// ```
///
/// ### Use Cases
/// - Rate-limiting high-frequency sensor data
/// - Creating periodic snapshots for logging/monitoring
/// - Downsampling real-time data for display (e.g., chart updates)
/// - Throttling UI updates to manageable frequency
///
/// ### Parameter Guidance
/// - **interval**: Sample period
///   - High-frequency monitoring: 100-500ms
///   - UI updates: 500ms-1s (human perception threshold)
///   - Data logging: 1s-60s (depends on volatility)
///
/// ### Technical Notes
/// - Memory usage: O(1) - stores only the latest value
/// - Samples occur at fixed intervals regardless of base stream timing
/// - Always emits the most recent value at each interval
/// - Uses task group to consume base stream and trigger periodic samples
/// - Completes when base stream completes
///
/// - SeeAlso: ``AsyncDebounceSequence``, ``AsyncWithLatestFromSequence``
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct AsyncSampleSequence<Base: AsyncSequence>: AsyncSequence where Base: Sendable, Base.Element: Sendable, Base.AsyncIterator: Sendable {
    /// The sampled element type.
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
    /// - Returns: An iterator that yields values at regular intervals.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base, interval: interval)
    }

    /// Iterator that samples values at regular intervals.
    ///
    /// Maintains the latest value from the base stream and emits it
    /// at fixed time intervals.
    public struct Iterator: AsyncIteratorProtocol, @unchecked Sendable {
        private let channel: AsyncStream<Element>
        private var iterator: AsyncStream<Element>.AsyncIterator

        init(base: Base, interval: Duration) {
            // SAFETY: ContinuationBox allows safe concurrent access from task group children
            // ThreadSafeBox (actor) provides synchronized access to latest value
            let (channel, continuationBox): (AsyncStream<Element>, ContinuationBox<Element>) = {
                var box: ContinuationBox<Element>!
                let ch = AsyncStream<Element> { cont in
                    box = ContinuationBox(cont)
                }
                return (ch, box!)
            }()
            self.channel = channel
            iterator = channel.makeAsyncIterator()

            // Create iterator before Task to avoid capturing metatype
            let baseIterator = base.makeAsyncIterator()

            Task { @Sendable in
                let latestValue = ThreadSafeBox<Element?>(nil)

                await withTaskGroup(of: Void.self) { group in
                    // Consume base stream
                    group.addTask { @Sendable in
                        var iter = baseIterator
                        while let value = try? await iter.next() {
                            await latestValue.setValue(value)
                        }
                    }

                    // Sample at intervals
                    group.addTask { @Sendable in
                        while !Task.isCancelled {
                            try? await Task.sleep(for: interval)
                            if let value = await latestValue.getValue() {
                                continuationBox.yield(value)
                            }
                        }
                    }

                    await group.waitForAll()
                    continuationBox.finish()
                }
            }
        }

        /// Advances to the next sampled element.
        ///
        /// - Returns: The latest value at each interval, or `nil` when the stream completes.
        public mutating func next() async throws -> Element? {
            return await iterator.next()
        }
    }
}

// MARK: - Take

/// AsyncSequence that emits only the first N elements.
///
/// Limits the stream to a specified number of elements, then completes. Useful for
/// processing a fixed number of items, testing streams, or implementing pagination.
/// Elements beyond the limit are ignored.
///
/// ### Example
/// ```swift
/// let stream = AsyncValueStream([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
///
/// for try await value in stream.take(3) {
///     print(value)
/// }
/// // Output:
/// // 1
/// // 2
/// // 3
/// // (stream completes)
/// ```
///
/// ### Use Cases
/// - Limiting query results (top N items)
/// - Processing batches of fixed size
/// - Testing with sample data
/// - Preview/sampling of large streams
///
/// ### Technical Notes
/// - Memory usage: O(1) - only tracks count
/// - Automatically completes after N elements
/// - Base stream may continue producing; only consumption is limited
/// - Count of 0 produces empty sequence
///
/// - SeeAlso: ``AsyncSkipSequence``, ``AsyncTakeWhileSequence``
public struct AsyncTakeSequence<Base: AsyncSequence>: AsyncSequence {
    /// The element type (same as base stream).
    public typealias Element = Base.Element

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let count: Int

    init(base: Base, count: Int) {
        self.base = base
        self.count = count
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields up to N elements.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), count: count)
    }

    /// Iterator that limits emission to N elements.
    ///
    /// Tracks the number of emitted elements and stops after reaching
    /// the specified count.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let count: Int
        private var emitted = 0

        init(base: Base.AsyncIterator, count: Int) {
            self.baseIterator = base
            self.count = count
        }

        /// Advances to the next element if under the limit.
        ///
        /// - Returns: The next value if count hasn't been reached, or `nil` after N elements.
        public mutating func next() async throws -> Element? {
            guard emitted < count else { return nil }
            guard let value = try await baseIterator.next() else { return nil }
            emitted += 1
            return value
        }
    }
}

// MARK: - Skip

/// AsyncSequence that ignores the first N elements.
///
/// Skips a specified number of initial elements, then emits all subsequent values
/// unchanged. Useful for pagination, removing headers, or starting processing after
/// a warm-up period.
///
/// ### Example
/// ```swift
/// let stream = AsyncValueStream([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
///
/// for try await value in stream.skip(3) {
///     print(value)
/// }
/// // Output:
/// // 4
/// // 5
/// // 6
/// // 7
/// // 8
/// // 9
/// // 10
/// ```
///
/// ### Use Cases
/// - Pagination (skip first N pages)
/// - Removing header rows from data streams
/// - Ignoring warm-up/initialization values
/// - Implementing "load more" functionality
///
/// ### Technical Notes
/// - Memory usage: O(1) - only tracks skip count
/// - Skipped elements are consumed but not emitted
/// - After skipping, stream passes through all remaining elements
/// - Count of 0 passes through entire stream unchanged
///
/// - SeeAlso: ``AsyncTakeSequence``, ``AsyncSkipWhileSequence``
public struct AsyncSkipSequence<Base: AsyncSequence>: AsyncSequence {
    /// The element type (same as base stream).
    public typealias Element = Base.Element

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let count: Int

    init(base: Base, count: Int) {
        self.base = base
        self.count = count
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that skips the first N elements.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), count: count)
    }

    /// Iterator that skips N elements before emitting.
    ///
    /// Consumes and discards the specified number of elements, then
    /// passes through all remaining elements.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let count: Int
        private var skipped = 0

        init(base: Base.AsyncIterator, count: Int) {
            self.baseIterator = base
            self.count = count
        }

        /// Advances to the next element after skipping.
        ///
        /// - Returns: The next value after skipping N elements, or `nil` when the stream completes.
        public mutating func next() async throws -> Element? {
            while skipped < count {
                guard let _ = try await baseIterator.next() else { return nil }
                skipped += 1
            }
            return try await baseIterator.next()
        }
    }
}

// MARK: - TakeWhile

/// AsyncSequence that emits elements while a condition holds.
///
/// Emits values as long as they satisfy a predicate function. Stops immediately when
/// the first element fails the condition. All subsequent elements are ignored, even
/// if they would satisfy the predicate. Useful for processing until a terminating
/// condition is met.
///
/// ### Example
/// ```swift
/// let stream = AsyncValueStream([2, 4, 6, 7, 8, 10])
///
/// for try await value in stream.takeWhile({ $0 % 2 == 0 }) {
///     print(value)
/// }
/// // Output:
/// // 2
/// // 4
/// // 6
/// // (stops at 7, which is odd)
/// ```
///
/// ### Use Cases
/// - Processing while values are within a threshold
/// - Reading until a sentinel/terminator value
/// - Taking elements during a stable condition
/// - Consuming sorted data until a boundary
///
/// ### Technical Notes
/// - Memory usage: O(1) - only stores completion flag
/// - Predicate evaluated for each element until it returns false
/// - Stream completes immediately on first failed predicate
/// - Once stopped, remains completed even if predicate would pass later
///
/// - SeeAlso: ``AsyncSkipWhileSequence``, ``AsyncTakeSequence``
public struct AsyncTakeWhileSequence<Base: AsyncSequence>: AsyncSequence {
    /// The element type (same as base stream).
    public typealias Element = Base.Element

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let predicate: @Sendable (Element) -> Bool

    init(base: Base, predicate: @escaping @Sendable (Element) -> Bool) {
        self.base = base
        self.predicate = predicate
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields elements while the predicate holds.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), predicate: predicate)
    }

    /// Iterator that emits elements while a condition is true.
    ///
    /// Evaluates the predicate for each element and emits it if true.
    /// Completes permanently on the first false result.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let predicate: @Sendable (Base.Element) -> Bool
        private var done = false

        init(base: Base.AsyncIterator, predicate: @escaping @Sendable (Base.Element) -> Bool) {
            self.baseIterator = base
            self.predicate = predicate
        }

        /// Advances to the next element if the predicate holds.
        ///
        /// - Returns: The next value if the predicate returns true, or `nil` once the predicate fails.
        public mutating func next() async throws -> Element? {
            guard !done else { return nil }
            guard let value = try await baseIterator.next() else { return nil }

            if predicate(value) {
                return value
            } else {
                done = true
                return nil
            }
        }
    }
}

// MARK: - SkipWhile

/// AsyncSequence that ignores elements while a condition holds.
///
/// Skips elements as long as they satisfy a predicate function. Once the first element
/// fails the condition, emits that element and all subsequent ones unchanged. The
/// predicate is only evaluated during the initial skipping phase.
///
/// ### Example
/// ```swift
/// let stream = AsyncValueStream([1, 3, 5, 6, 7, 9, 11])
///
/// for try await value in stream.skipWhile({ $0 % 2 != 0 }) {
///     print(value)
/// }
/// // Output:
/// // 6  (first even number)
/// // 7
/// // 9
/// // 11
/// // (continues with all remaining values)
/// ```
///
/// ### Use Cases
/// - Skipping header/metadata until data starts
/// - Ignoring initial warm-up/unstable values
/// - Bypassing values until a threshold is crossed
/// - Removing leading whitespace/padding from streams
///
/// ### Technical Notes
/// - Memory usage: O(1) - only stores skipping state flag
/// - Predicate only evaluated while skipping (not for every element)
/// - Once predicate fails, all remaining elements pass through
/// - First failed element is emitted (not discarded)
///
/// - SeeAlso: ``AsyncTakeWhileSequence``, ``AsyncSkipSequence``
public struct AsyncSkipWhileSequence<Base: AsyncSequence>: AsyncSequence {
    /// The element type (same as base stream).
    public typealias Element = Base.Element

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let predicate: @Sendable (Element) -> Bool

    init(base: Base, predicate: @escaping @Sendable (Element) -> Bool) {
        self.base = base
        self.predicate = predicate
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that skips elements while the predicate holds.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), predicate: predicate)
    }

    /// Iterator that skips elements while a condition is true.
    ///
    /// Discards elements while the predicate returns true. Once it returns
    /// false, emits that element and all subsequent ones.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let predicate: @Sendable (Base.Element) -> Bool
        private var isSkipping = true

        init(base: Base.AsyncIterator, predicate: @escaping @Sendable (Base.Element) -> Bool) {
            self.baseIterator = base
            self.predicate = predicate
        }

        /// Advances to the next element after skipping while the predicate holds.
        ///
        /// - Returns: The next value after the predicate fails, or `nil` when the stream completes.
        public mutating func next() async throws -> Element? {
            while isSkipping {
                guard let value = try await baseIterator.next() else { return nil }
                if !predicate(value) {
                    isSkipping = false
                    return value
                }
            }
            return try await baseIterator.next()
        }
    }
}

// MARK: - Timeout

/// AsyncSequence that enforces a maximum time between elements.
///
/// Throws a ``TimeoutError`` if the time between consecutive elements exceeds the
/// specified duration. Each element resets the timer. Useful for detecting stalls,
/// ensuring timely responses, and implementing service level agreements.
///
/// ### Example
/// ```swift
/// do {
///     let stream = AsyncValueStream([1, 2, 3])  // Assuming fast delivery
///     for try await value in stream.timeout(duration: .seconds(5)) {
///         print(value)
///     }
/// } catch let error as TimeoutError {
///     print("Stream timed out: no element within \(error.duration)")
/// }
/// ```
///
/// ### Use Cases
/// - Detecting stalled network connections
/// - Enforcing SLA response times
/// - Implementing request deadlines
/// - Preventing infinite waits in streaming APIs
///
/// ### Parameter Guidance
/// - **duration**: Maximum time between elements
///   - Real-time APIs: 1-5 seconds (depends on expected frequency)
///   - Batch processing: 30-60 seconds (allow for processing time)
///   - Health checks: 5-30 seconds (balance responsiveness vs. false positives)
///
/// ### Technical Notes
/// - Memory usage: O(1) - only stores iterator state
/// - Timer resets with each successful element emission
/// - Throws ``TimeoutError`` on timeout (not `nil` completion)
/// - Uses task racing to implement timeout behavior
/// - Natural stream completion (nil) does not trigger timeout
///
/// - SeeAlso: ``TimeoutError``, ``AsyncDebounceSequence``
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct AsyncTimeoutSequence<Base: AsyncSequence>: AsyncSequence where Base: Sendable, Base.Element: Sendable, Base.AsyncIterator: Sendable {
    /// The element type (same as base stream).
    public typealias Element = Base.Element

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
    /// - Returns: An iterator that enforces timeout between elements.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base, duration: duration)
    }

    /// Iterator that enforces timeout between elements.
    ///
    /// Races each element fetch against a timeout timer. Throws if the
    /// timer completes first.
    public struct Iterator: AsyncIteratorProtocol, @unchecked Sendable {
        private let channel: AsyncThrowingStream<Element, Error>
        private var iterator: AsyncThrowingStream<Element, Error>.AsyncIterator

        enum TimeoutResult: Sendable where Element: Sendable {
            case value(Element?)
            case timeout
        }

        /// Actor to safely wrap the mutable iterator for concurrent access
        actor IteratorWrapper {
            var iter: Base.AsyncIterator

            init(_ iter: Base.AsyncIterator) {
                self.iter = iter
            }

            func next() async throws -> Element? {
                // Use local copy pattern to handle mutating async call
                var localIter = iter
                defer { iter = localIter }
                return try await localIter.next()
            }
        }

        init(base: Base, duration: Duration) {
            // SAFETY: ThrowingContinuationBox allows safe concurrent access from timeout tasks
            let (channel, continuationBox): (AsyncThrowingStream<Element, Error>, ThrowingContinuationBox<Element>) = {
                var box: ThrowingContinuationBox<Element>!
                let ch = AsyncThrowingStream<Element, Error> { cont in
                    box = ThrowingContinuationBox(cont)
                }
                return (ch, box!)
            }()
            self.channel = channel
            iterator = channel.makeAsyncIterator()

            // Create iterator wrapper before Task
            let baseIterator = base.makeAsyncIterator()
            let wrapper = IteratorWrapper(baseIterator)

            Task { @Sendable in
                while true {
                    // Race each element against timeout using a result enum
                    do {
                        let result = try await withThrowingTaskGroup(of: TimeoutResult.self) { group in
                            group.addTask { @Sendable in
                                let val = try await wrapper.next()
                                return TimeoutResult.value(val)
                            }

                            group.addTask { @Sendable in
                                try await Task.sleep(for: duration)
                                return TimeoutResult.timeout
                            }

                            // Get first result
                            guard let first = try await group.next() else {
                                return TimeoutResult.timeout
                            }

                            group.cancelAll()
                            return first
                        }

                        switch result {
                        case .value(let val):
                            if let v = val {
                                continuationBox.yield(v)
                            } else {
                                // Stream ended naturally
                                continuationBox.finish()
                                break
                            }
                        case .timeout:
                            continuationBox.finish(throwing: TimeoutError(duration: duration))
                            break
                        }
                    } catch {
                        continuationBox.finish(throwing: error)
                        break
                    }
                }
            }
        }

        /// Advances to the next element within the timeout period.
        ///
        /// - Returns: The next value if it arrives within the timeout, or `nil` on natural completion.
        /// - Throws: ``TimeoutError`` if an element doesn't arrive within the specified duration.
        public mutating func next() async throws -> Element? {
            return try await iterator.next()
        }
    }
}

// MARK: - Thread-Safe Box

/// Thread-safe wrapper for shared mutable state across concurrent tasks.
///
/// An actor-based container that provides synchronized access to a value that
/// multiple concurrent tasks need to read and write. Used internally by composition
/// operators like ``AsyncCombineLatestSequence`` and ``AsyncWithLatestFromSequence``
/// to safely share the latest values across task group children.
///
/// ### Technical Notes
/// - Implemented as an actor for Swift concurrency safety
/// - All access automatically serialized by the actor runtime
/// - Memory barrier guarantees from actor isolation
/// - Used instead of locks for Swift 6 compliance
actor ThreadSafeBox<T> {
    private var _value: T

    init(_ value: T) {
        self._value = value
    }

    /// Retrieves the current value.
    ///
    /// - Returns: The stored value.
    func getValue() -> T {
        return _value
    }

    /// Updates the stored value.
    ///
    /// - Parameter newValue: The new value to store.
    func setValue(_ newValue: T) {
        self._value = newValue
    }
}

/// Actor for managing debounce state safely across concurrent tasks
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private actor DebounceState<Element: Sendable> {
    private var lastValue: Element?
    private var debounceTask: Task<Void, Never>?

    func updateValue(_ value: Element) {
        lastValue = value
    }

    func getValue() -> Element? {
        return lastValue
    }

    func setDebounceTask(_ task: Task<Void, Never>) {
        debounceTask?.cancel()
        debounceTask = task
    }

    func waitForDebounce() async {
        await debounceTask?.value
    }
}

// MARK: - Continuation Safety Wrappers

/// Thread-safe wrapper for AsyncStream.Continuation
///
/// Allows safe concurrent access to continuation from multiple tasks.
/// The AsyncStream internally serializes all yields through its own queue,
/// making this wrapper safe despite the @unchecked Sendable marker.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
final class ContinuationBox<Element: Sendable>: @unchecked Sendable {
    private let continuation: AsyncStream<Element>.Continuation

    init(_ continuation: AsyncStream<Element>.Continuation) {
        self.continuation = continuation
    }

	func yield(_ value: Element) {
        continuation.yield(value)
    }

    func yield(with result: Result<Element, Never>) {
        continuation.yield(with: result)
    }

    func finish() {
        continuation.finish()
    }
}

/// Thread-safe wrapper for AsyncThrowingStream.Continuation
///
/// Allows safe concurrent access to continuation from multiple tasks.
/// The AsyncThrowingStream internally serializes all yields through its own queue,
/// making this wrapper safe despite the @unchecked Sendable marker.
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
final class ThrowingContinuationBox<Element: Sendable>: @unchecked Sendable {
    private let continuation: AsyncThrowingStream<Element, Error>.Continuation

    init(_ continuation: AsyncThrowingStream<Element, Error>.Continuation) {
        self.continuation = continuation
    }

    func yield(_ value: Element) {
        continuation.yield(value)
    }

    func yield(with result: Result<Element, Error>) {
        continuation.yield(with: result)
    }

    func finish() {
        continuation.finish()
    }

    func finish(throwing error: Error) {
        continuation.finish(throwing: error)
    }
}


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

/// Error thrown when stream operation times out
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct TimeoutError: Error, Sendable {
    public let duration: Duration

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

    /// Debounces the stream, only emitting after the specified interval of silence
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

    /// Samples the stream at regular intervals
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

    /// Adds a timeout to the stream operations
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public func timeout(duration: Duration) -> AsyncTimeoutSequence<Self> where Element: Sendable {
        AsyncTimeoutSequence(base: self, duration: duration)
    }
}

// MARK: - Merge

public struct AsyncMergeSequence<First: AsyncSequence, Second: AsyncSequence>: AsyncSequence where First.Element == Second.Element {
    public typealias Element = First.Element
    public typealias AsyncIterator = Iterator

    private let first: First
    private let second: Second

    init(first: First, second: Second) {
        self.first = first
        self.second = second
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(first: first, second: second)
    }

    public struct Iterator: AsyncIteratorProtocol, @unchecked Sendable {
        private let channel: AsyncStream<Element>
        private var iterator: AsyncStream<Element>.AsyncIterator

        init(first: First, second: Second) {
            // Use AsyncStream as a channel to merge values from both streams
            // SAFETY: ContinuationBox allows safe concurrent access to continuation
            // from multiple task group children. The AsyncStream serializes yields.
            var continuationBox: ContinuationBox<Element>!
            channel = AsyncStream { cont in
                continuationBox = ContinuationBox(cont)
            }
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

                    group.addTask {
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

        public mutating func next() async throws -> Element? {
            return await iterator.next()
        }
    }
}

// MARK: - Zip

public struct AsyncZipSequence<First: AsyncSequence, Second: AsyncSequence>: AsyncSequence {
    public typealias Element = (First.Element, Second.Element)
    public typealias AsyncIterator = Iterator

    private let first: First
    private let second: Second

    init(first: First, second: Second) {
        self.first = first
        self.second = second
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(first: first.makeAsyncIterator(), second: second.makeAsyncIterator())
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var firstIterator: First.AsyncIterator
        private var secondIterator: Second.AsyncIterator

        init(first: First.AsyncIterator, second: Second.AsyncIterator) {
            self.firstIterator = first
            self.secondIterator = second
        }

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

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct AsyncDebounceSequence<Base: AsyncSequence & Sendable>: AsyncSequence, Sendable where Base.Element: Sendable {
    public typealias Element = Base.Element
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let interval: Duration

    init(base: Base, interval: Duration) {
        self.base = base
        self.interval = interval
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base, interval: interval)
    }

    public struct Iterator: AsyncIteratorProtocol, @unchecked Sendable {
        private let channel: AsyncStream<Element>
        private var iterator: AsyncStream<Element>.AsyncIterator

        init(base: Base, interval: Duration) {
            // SAFETY: ContinuationBox allows safe concurrent access from debounce tasks
            var continuationBox: ContinuationBox<Element>!
            channel = AsyncStream { cont in
                continuationBox = ContinuationBox(cont)
            }
            iterator = channel.makeAsyncIterator()

            Task {
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

        public mutating func next() async throws -> Element? {
            return await iterator.next()
        }
    }
}

// MARK: - CombineLatest

public struct AsyncCombineLatestSequence<First: AsyncSequence & Sendable, Second: AsyncSequence & Sendable>: AsyncSequence where First.Element: Sendable, Second.Element: Sendable {
    public typealias Element = (First.Element, Second.Element)
    public typealias AsyncIterator = Iterator

    private let first: First
    private let second: Second

    init(first: First, second: Second) {
        self.first = first
        self.second = second
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(first: first, second: second)
    }

    public struct Iterator: AsyncIteratorProtocol, @unchecked Sendable {
        private let channel: AsyncStream<Element>
        private var iterator: AsyncStream<Element>.AsyncIterator

        init(first: First, second: Second) {
            // SAFETY: ContinuationBox allows safe concurrent access from task group children
            // ThreadSafeBox (actor) provides synchronized access to latest values
            var continuationBox: ContinuationBox<Element>!
            channel = AsyncStream { cont in
                continuationBox = ContinuationBox(cont)
            }
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

        public mutating func next() async throws -> Element? {
            return await iterator.next()
        }
    }
}

// MARK: - WithLatestFrom

public struct AsyncWithLatestFromSequence<Trigger: AsyncSequence, Sampled: AsyncSequence>: AsyncSequence where Trigger: Sendable, Sampled: Sendable, Sampled.Element: Sendable {
    public typealias Element = Sampled.Element
    public typealias AsyncIterator = Iterator

    private let trigger: Trigger
    private let sampled: Sampled

    init(trigger: Trigger, sampled: Sampled) {
        self.trigger = trigger
        self.sampled = sampled
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(trigger: trigger, sampled: sampled)
    }

    public struct Iterator: AsyncIteratorProtocol, @unchecked Sendable {
        private let channel: AsyncStream<Element>
        private var iterator: AsyncStream<Element>.AsyncIterator

        init(trigger: Trigger, sampled: Sampled) {
            // SAFETY: ContinuationBox allows safe concurrent access from task group children
            // ThreadSafeBox (actor) provides synchronized access to latest sampled value
            var continuationBox: ContinuationBox<Element>!
            channel = AsyncStream { cont in
                continuationBox = ContinuationBox(cont)
            }
            iterator = channel.makeAsyncIterator()

            // Create iterators before Task to avoid capturing metatypes
            let triggerIterator = trigger.makeAsyncIterator()
            let sampledIterator = sampled.makeAsyncIterator()

            Task {
                let latestSampled = ThreadSafeBox<Sampled.Element?>(nil)

                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        var iter = triggerIterator
                        while let _ = try? await iter.next() {
                            if let value = await latestSampled.getValue() {
                                continuationBox.yield(value)
                            }
                        }
                    }

                    group.addTask {
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

        public mutating func next() async throws -> Element? {
            return await iterator.next()
        }
    }
}

// MARK: - Distinct

public struct AsyncDistinctSequence<Base: AsyncSequence>: AsyncSequence where Base.Element: Equatable {
    public typealias Element = Base.Element
    public typealias AsyncIterator = Iterator

    private let base: Base

    init(base: Base) {
        self.base = base
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator())
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private var lastValue: Base.Element?

        init(base: Base.AsyncIterator) {
            self.baseIterator = base
        }

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

public struct AsyncDistinctUntilChangedSequence<Base: AsyncSequence>: AsyncSequence {
    public typealias Element = Base.Element
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let comparator: @Sendable (Element, Element) -> Bool

    init(base: Base, comparator: @escaping @Sendable (Element, Element) -> Bool) {
        self.base = base
        self.comparator = comparator
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), comparator: comparator)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let comparator: @Sendable (Base.Element, Base.Element) -> Bool
        private var lastValue: Base.Element?

        init(base: Base.AsyncIterator, comparator: @escaping @Sendable (Base.Element, Base.Element) -> Bool) {
            self.baseIterator = base
            self.comparator = comparator
        }

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

public struct AsyncStartWithSequence<Base: AsyncSequence>: AsyncSequence {
    public typealias Element = Base.Element
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let initialValue: Element

    init(base: Base, initialValue: Element) {
        self.base = base
        self.initialValue = initialValue
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), initialValue: initialValue)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private var hasEmittedInitial = false
        private let initialValue: Base.Element

        init(base: Base.AsyncIterator, initialValue: Base.Element) {
            self.baseIterator = base
            self.initialValue = initialValue
        }

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

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct AsyncSampleSequence<Base: AsyncSequence>: AsyncSequence where Base: Sendable, Base.Element: Sendable {
    public typealias Element = Base.Element
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let interval: Duration

    init(base: Base, interval: Duration) {
        self.base = base
        self.interval = interval
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base, interval: interval)
    }

    public struct Iterator: AsyncIteratorProtocol, @unchecked Sendable {
        private let channel: AsyncStream<Element>
        private var iterator: AsyncStream<Element>.AsyncIterator

        init(base: Base, interval: Duration) {
            // SAFETY: ContinuationBox allows safe concurrent access from task group children
            // ThreadSafeBox (actor) provides synchronized access to latest value
            var continuationBox: ContinuationBox<Element>!
            channel = AsyncStream { cont in
                continuationBox = ContinuationBox(cont)
            }
            iterator = channel.makeAsyncIterator()

            // Create iterator before Task to avoid capturing metatype
            let baseIterator = base.makeAsyncIterator()

            Task {
                let latestValue = ThreadSafeBox<Element?>(nil)

                await withTaskGroup(of: Void.self) { group in
                    // Consume base stream
                    group.addTask {
                        var iter = baseIterator
                        while let value = try? await iter.next() {
                            await latestValue.setValue(value)
                        }
                    }

                    // Sample at intervals
                    group.addTask {
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

        public mutating func next() async throws -> Element? {
            return await iterator.next()
        }
    }
}

// MARK: - Take

public struct AsyncTakeSequence<Base: AsyncSequence>: AsyncSequence {
    public typealias Element = Base.Element
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let count: Int

    init(base: Base, count: Int) {
        self.base = base
        self.count = count
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), count: count)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let count: Int
        private var emitted = 0

        init(base: Base.AsyncIterator, count: Int) {
            self.baseIterator = base
            self.count = count
        }

        public mutating func next() async throws -> Element? {
            guard emitted < count else { return nil }
            guard let value = try await baseIterator.next() else { return nil }
            emitted += 1
            return value
        }
    }
}

// MARK: - Skip

public struct AsyncSkipSequence<Base: AsyncSequence>: AsyncSequence {
    public typealias Element = Base.Element
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let count: Int

    init(base: Base, count: Int) {
        self.base = base
        self.count = count
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), count: count)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let count: Int
        private var skipped = 0

        init(base: Base.AsyncIterator, count: Int) {
            self.baseIterator = base
            self.count = count
        }

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

public struct AsyncTakeWhileSequence<Base: AsyncSequence>: AsyncSequence {
    public typealias Element = Base.Element
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let predicate: @Sendable (Element) -> Bool

    init(base: Base, predicate: @escaping @Sendable (Element) -> Bool) {
        self.base = base
        self.predicate = predicate
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), predicate: predicate)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let predicate: @Sendable (Base.Element) -> Bool
        private var done = false

        init(base: Base.AsyncIterator, predicate: @escaping @Sendable (Base.Element) -> Bool) {
            self.baseIterator = base
            self.predicate = predicate
        }

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

public struct AsyncSkipWhileSequence<Base: AsyncSequence>: AsyncSequence {
    public typealias Element = Base.Element
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let predicate: @Sendable (Element) -> Bool

    init(base: Base, predicate: @escaping @Sendable (Element) -> Bool) {
        self.base = base
        self.predicate = predicate
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), predicate: predicate)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let predicate: @Sendable (Base.Element) -> Bool
        private var isSkipping = true

        init(base: Base.AsyncIterator, predicate: @escaping @Sendable (Base.Element) -> Bool) {
            self.baseIterator = base
            self.predicate = predicate
        }

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

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct AsyncTimeoutSequence<Base: AsyncSequence>: AsyncSequence where Base.Element: Sendable {
    public typealias Element = Base.Element
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let duration: Duration

    init(base: Base, duration: Duration) {
        self.base = base
        self.duration = duration
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base, duration: duration)
    }

    public struct Iterator: AsyncIteratorProtocol, @unchecked Sendable {
        private let channel: AsyncThrowingStream<Element, Error>
        private var iterator: AsyncThrowingStream<Element, Error>.AsyncIterator

        enum TimeoutResult: Sendable where Element: Sendable {
            case value(Element?)
            case timeout
        }

        init(base: Base, duration: Duration) {
            // SAFETY: ThrowingContinuationBox allows safe concurrent access from timeout tasks
            var continuationBox: ThrowingContinuationBox<Element>!
            channel = AsyncThrowingStream { cont in
                continuationBox = ThrowingContinuationBox(cont)
            }
            iterator = channel.makeAsyncIterator()

            // Create iterator before Task to avoid capturing metatype
            let baseIterator = base.makeAsyncIterator()

            Task {
                var iter = baseIterator

                while true {
                    // Race each element against timeout using a result enum
                    do {
                        let result = try await withThrowingTaskGroup(of: TimeoutResult.self) { group in
                            group.addTask {
                                let val = try await iter.next()
                                return TimeoutResult.value(val)
                            }

                            group.addTask {
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

        public mutating func next() async throws -> Element? {
            return try await iterator.next()
        }
    }
}

// MARK: - Thread-Safe Box

/// Thread-safe wrapper for shared mutable state
actor ThreadSafeBox<T> {
    private var _value: T

    init(_ value: T) {
        self._value = value
    }

    func getValue() -> T {
        return _value
    }

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

//
//  StreamingComposition.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-30.
//

import Foundation

// MARK: - Timeout Error

/// Error thrown when stream operation times out
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct TimeoutError: Error {
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
    public func debounce(interval: Duration) -> AsyncDebounceSequence<Self> {
        AsyncDebounceSequence(base: self, interval: interval)
    }

    /// Combines latest values from both streams, emitting when either updates
    public func combineLatest<Other: AsyncSequence>(with other: Other) -> AsyncCombineLatestSequence<Self, Other> {
        AsyncCombineLatestSequence(first: self, second: other)
    }

    /// Samples the other stream whenever this stream emits
    public func withLatestFrom<Other: AsyncSequence>(_ other: Other) -> AsyncWithLatestFromSequence<Self, Other> {
        AsyncWithLatestFromSequence(trigger: self, sampled: other)
    }

    /// Removes consecutive duplicate values
    public func distinct() -> AsyncDistinctSequence<Self> where Element: Equatable {
        AsyncDistinctSequence(base: self)
    }

    /// Removes consecutive duplicates using custom comparator
    public func distinctUntilChanged(by comparator: @escaping (Element, Element) -> Bool) -> AsyncDistinctUntilChangedSequence<Self> {
        AsyncDistinctUntilChangedSequence(base: self, comparator: comparator)
    }

    /// Prepends an initial value to the stream
    public func startWith(_ value: Element) -> AsyncStartWithSequence<Self> {
        AsyncStartWithSequence(base: self, initialValue: value)
    }

    /// Samples the stream at regular intervals
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public func sample(interval: Duration) -> AsyncSampleSequence<Self> {
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
    public func takeWhile(_ predicate: @escaping (Element) -> Bool) -> AsyncTakeWhileSequence<Self> {
        AsyncTakeWhileSequence(base: self, predicate: predicate)
    }

    /// Skips elements while condition holds
    public func skipWhile(_ predicate: @escaping (Element) -> Bool) -> AsyncSkipWhileSequence<Self> {
        AsyncSkipWhileSequence(base: self, predicate: predicate)
    }

    /// Adds a timeout to the stream operations
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    public func timeout(duration: Duration) -> AsyncTimeoutSequence<Self> {
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

    public struct Iterator: AsyncIteratorProtocol {
        private let channel: AsyncStream<Element>
        private var iterator: AsyncStream<Element>.AsyncIterator

        init(first: First, second: Second) {
            // Use AsyncStream as a channel to merge values from both streams
            var continuation: AsyncStream<Element>.Continuation!
            channel = AsyncStream { cont in
                continuation = cont
            }
            iterator = channel.makeAsyncIterator()

            // Start tasks to consume both streams
            Task {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        var iter = first.makeAsyncIterator()
                        while let value = try? await iter.next() {
                            continuation.yield(value)
                        }
                    }

                    group.addTask {
                        var iter = second.makeAsyncIterator()
                        while let value = try? await iter.next() {
                            continuation.yield(value)
                        }
                    }

                    await group.waitForAll()
                    continuation.finish()
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
public struct AsyncDebounceSequence<Base: AsyncSequence>: AsyncSequence {
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

    public struct Iterator: AsyncIteratorProtocol {
        private let channel: AsyncStream<Element>
        private var iterator: AsyncStream<Element>.AsyncIterator

        init(base: Base, interval: Duration) {
            var continuation: AsyncStream<Element>.Continuation!
            channel = AsyncStream { cont in
                continuation = cont
            }
            iterator = channel.makeAsyncIterator()

            Task {
                var baseIterator = base.makeAsyncIterator()
                var lastValue: Element?
                var debounceTask: Task<Void, Never>?

                while let value = try? await baseIterator.next() {
                    // Cancel previous debounce
                    debounceTask?.cancel()

                    lastValue = value

                    // Start new debounce timer
                    debounceTask = Task {
                        try? await Task.sleep(for: interval)
                        if !Task.isCancelled, let val = lastValue {
                            continuation.yield(val)
                        }
                    }
                }

                // Wait for final debounce to complete
                await debounceTask?.value
                continuation.finish()
            }
        }

        public mutating func next() async throws -> Element? {
            return await iterator.next()
        }
    }
}

// MARK: - CombineLatest

public struct AsyncCombineLatestSequence<First: AsyncSequence, Second: AsyncSequence>: AsyncSequence {
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

    public struct Iterator: AsyncIteratorProtocol {
        private let channel: AsyncStream<Element>
        private var iterator: AsyncStream<Element>.AsyncIterator

        init(first: First, second: Second) {
            var continuation: AsyncStream<Element>.Continuation!
            channel = AsyncStream { cont in
                continuation = cont
            }
            iterator = channel.makeAsyncIterator()

            Task {
                let firstLatest = ThreadSafeBox<First.Element?>(nil)
                let secondLatest = ThreadSafeBox<Second.Element?>(nil)

                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        var iter = first.makeAsyncIterator()
                        while let value = try? await iter.next() {
                            await firstLatest.setValue(value)
                            if let second = await secondLatest.getValue() {
                                continuation.yield((value, second))
                            }
                        }
                    }

                    group.addTask {
                        var iter = second.makeAsyncIterator()
                        while let value = try? await iter.next() {
                            await secondLatest.setValue(value)
                            if let first = await firstLatest.getValue() {
                                continuation.yield((first, value))
                            }
                        }
                    }

                    await group.waitForAll()
                    continuation.finish()
                }
            }
        }

        public mutating func next() async throws -> Element? {
            return await iterator.next()
        }
    }
}

// MARK: - WithLatestFrom

public struct AsyncWithLatestFromSequence<Trigger: AsyncSequence, Sampled: AsyncSequence>: AsyncSequence {
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

    public struct Iterator: AsyncIteratorProtocol {
        private let channel: AsyncStream<Element>
        private var iterator: AsyncStream<Element>.AsyncIterator

        init(trigger: Trigger, sampled: Sampled) {
            var continuation: AsyncStream<Element>.Continuation!
            channel = AsyncStream { cont in
                continuation = cont
            }
            iterator = channel.makeAsyncIterator()

            Task {
                let latestSampled = ThreadSafeBox<Sampled.Element?>(nil)

                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        var iter = trigger.makeAsyncIterator()
                        while let _ = try? await iter.next() {
                            if let value = await latestSampled.getValue() {
                                continuation.yield(value)
                            }
                        }
                    }

                    group.addTask {
                        var iter = sampled.makeAsyncIterator()
                        while let value = try? await iter.next() {
                            await latestSampled.setValue(value)
                        }
                    }

                    await group.waitForAll()
                    continuation.finish()
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
    private let comparator: (Element, Element) -> Bool

    init(base: Base, comparator: @escaping (Element, Element) -> Bool) {
        self.base = base
        self.comparator = comparator
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), comparator: comparator)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let comparator: (Base.Element, Base.Element) -> Bool
        private var lastValue: Base.Element?

        init(base: Base.AsyncIterator, comparator: @escaping (Base.Element, Base.Element) -> Bool) {
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
public struct AsyncSampleSequence<Base: AsyncSequence>: AsyncSequence {
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

    public struct Iterator: AsyncIteratorProtocol {
        private let channel: AsyncStream<Element>
        private var iterator: AsyncStream<Element>.AsyncIterator

        init(base: Base, interval: Duration) {
            var continuation: AsyncStream<Element>.Continuation!
            channel = AsyncStream { cont in
                continuation = cont
            }
            iterator = channel.makeAsyncIterator()

            Task {
                let latestValue = ThreadSafeBox<Element?>(nil)

                await withTaskGroup(of: Void.self) { group in
                    // Consume base stream
                    group.addTask {
                        var iter = base.makeAsyncIterator()
                        while let value = try? await iter.next() {
                            await latestValue.setValue(value)
                        }
                    }

                    // Sample at intervals
                    group.addTask {
                        while !Task.isCancelled {
                            try? await Task.sleep(for: interval)
                            if let value = await latestValue.getValue() {
                                continuation.yield(value)
                            }
                        }
                    }

                    await group.waitForAll()
                    continuation.finish()
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
    private let predicate: (Element) -> Bool

    init(base: Base, predicate: @escaping (Element) -> Bool) {
        self.base = base
        self.predicate = predicate
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), predicate: predicate)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let predicate: (Base.Element) -> Bool
        private var done = false

        init(base: Base.AsyncIterator, predicate: @escaping (Base.Element) -> Bool) {
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
    private let predicate: (Element) -> Bool

    init(base: Base, predicate: @escaping (Element) -> Bool) {
        self.base = base
        self.predicate = predicate
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), predicate: predicate)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let predicate: (Base.Element) -> Bool
        private var isSkipping = true

        init(base: Base.AsyncIterator, predicate: @escaping (Base.Element) -> Bool) {
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
public struct AsyncTimeoutSequence<Base: AsyncSequence>: AsyncSequence {
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

    public struct Iterator: AsyncIteratorProtocol {
        private let channel: AsyncThrowingStream<Element, Error>
        private var iterator: AsyncThrowingStream<Element, Error>.AsyncIterator

        enum TimeoutResult {
            case value(Element?)
            case timeout
        }

        init(base: Base, duration: Duration) {
            var continuation: AsyncThrowingStream<Element, Error>.Continuation!
            channel = AsyncThrowingStream { cont in
                continuation = cont
            }
            iterator = channel.makeAsyncIterator()

            Task {
                var baseIterator = base.makeAsyncIterator()

                while true {
                    // Race each element against timeout using a result enum
                    do {
                        let result = try await withThrowingTaskGroup(of: TimeoutResult.self) { group in
                            group.addTask {
                                let val = try await baseIterator.next()
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
                                continuation.yield(v)
                            } else {
                                // Stream ended naturally
                                continuation.finish()
                                break
                            }
                        case .timeout:
                            continuation.finish(throwing: TimeoutError(duration: duration))
                            break
                        }
                    } catch {
                        continuation.finish(throwing: error)
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

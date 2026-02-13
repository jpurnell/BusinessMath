//
//  ConcurrencyHelpers.swift
//  BusinessMath
//
//  Created by Claude Code on 02/12/26.
//

import Foundation

/// Thread-safe collector for accumulating values in concurrent contexts (Swift 6 compatible).
///
/// This helper enables Swift 6 concurrency-safe testing by providing a
/// synchronized container for collecting values from synchronous callbacks.
///
/// ## Example
/// ```swift
/// let collector = ProgressCollector<Int>()
/// try await optimizer.optimizeWithProgress(...) { progress in
///     collector.append(progress.iteration)  // Thread-safe, no await needed
/// }
/// let results = collector.getItems()
/// #expect(results.count > 0)
/// ```
public final class ProgressCollector<T: Sendable>: @unchecked Sendable {
    private var items: [T] = []
    private let lock = NSLock()

    public init() {}

    /// Appends an item in a thread-safe manner.
    public func append(_ item: T) {
        lock.lock()
        defer { lock.unlock() }
        items.append(item)
    }

    /// Returns all collected items.
    public func getItems() -> [T] {
        lock.lock()
        defer { lock.unlock() }
        return items
    }

    /// Returns the count of collected items.
    public func count() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return items.count
    }

    /// Returns the last collected item.
    public func last() -> T? {
        lock.lock()
        defer { lock.unlock() }
        return items.last
    }

    /// Returns the first collected item.
    public func first() -> T? {
        lock.lock()
        defer { lock.unlock() }
        return items.first
    }

    /// Clears all collected items.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        items.removeAll()
    }
}


//
//  RingBuffer.swift
//  BusinessMath
//
//  Created on March 9, 2026.
//  Phase: Security & Memory Fixes - Infrastructure
//

/// A fixed-size circular buffer that overwrites oldest elements when full.
///
/// `RingBuffer` provides O(1) append and O(1) indexed access with bounded memory usage.
/// When the buffer reaches capacity, new elements overwrite the oldest entries.
///
/// This is the preferred data structure for streaming statistics, rolling windows,
/// and any scenario where you need to track "the last N values" without unbounded growth.
///
/// ## Usage
/// ```swift
/// var buffer = RingBuffer<Double>(capacity: 100)
/// for value in stream {
///     buffer.append(value)  // O(1), never grows beyond 100 elements
/// }
///
/// // Access recent values
/// let latest = buffer.last
/// let oldest = buffer.first
/// let all = buffer.toArray()  // In insertion order
/// ```
///
/// ## Memory Safety
/// Unlike a regular `Array`, `RingBuffer` never exceeds its initial capacity,
/// making it safe for long-running processes and streaming data.
///
/// - Complexity: O(1) for append, O(1) for indexed access, O(capacity) for iteration
public struct RingBuffer<Element>: Sendable where Element: Sendable {
    /// Internal storage array (fixed size, may contain nil for unfilled slots)
    private var storage: [Element?]

    /// Current write position in the circular buffer
    private var writeIndex: Int = 0

    /// Number of elements currently in the buffer (up to capacity)
    private var elementCount: Int = 0

    /// The maximum number of elements this buffer can hold
    public let capacity: Int

    /// Creates a ring buffer with the specified capacity.
    ///
    /// - Parameter capacity: Maximum number of elements. Must be positive.
    /// - Precondition: `capacity > 0`
    public init(capacity: Int) {
        guard capacity > 0 else {
            preconditionFailure("RingBuffer capacity must be positive")
        }
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
    }

    /// The number of elements currently stored in the buffer.
    ///
    /// This value ranges from 0 (empty) to `capacity` (full).
    public var count: Int {
        elementCount
    }

    /// Whether the buffer is empty.
    public var isEmpty: Bool {
        elementCount == 0
    }

    /// Whether the buffer has reached capacity.
    ///
    /// When full, new elements will overwrite the oldest ones.
    public var isFull: Bool {
        elementCount == capacity
    }

    /// Appends an element to the buffer.
    ///
    /// If the buffer is full, this overwrites the oldest element.
    ///
    /// - Parameter element: The element to append.
    /// - Complexity: O(1)
    public mutating func append(_ element: Element) {
        storage[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity

        if elementCount < capacity {
            elementCount += 1
        }
    }

    /// Accesses the element at the specified position.
    ///
    /// Index 0 is the oldest element, index `count - 1` is the newest.
    ///
    /// - Parameter index: The position of the element to access.
    /// - Returns: The element at the specified index.
    /// - Precondition: `index >= 0 && index < count`
    public subscript(index: Int) -> Element {
        guard index >= 0, index < elementCount else {
            preconditionFailure("Index \(index) out of bounds for RingBuffer with count \(elementCount)")
        }
        let actualIndex = (writeIndex - elementCount + index + capacity) % capacity
        guard let element = storage[actualIndex] else {
            preconditionFailure("Unexpected nil at index \(actualIndex) in RingBuffer storage")
        }
        return element
    }

    /// The oldest element in the buffer, or `nil` if empty.
    public var first: Element? {
        guard elementCount > 0 else { return nil }
        let firstIndex = (writeIndex - elementCount + capacity) % capacity
        return storage[firstIndex]
    }

    /// The newest element in the buffer, or `nil` if empty.
    public var last: Element? {
        guard elementCount > 0 else { return nil }
        let lastIndex = (writeIndex - 1 + capacity) % capacity
        return storage[lastIndex]
    }

    /// Returns all elements as an array in insertion order (oldest first).
    ///
    /// - Returns: Array of all elements from oldest to newest.
    /// - Complexity: O(count)
    public func toArray() -> [Element] {
        guard elementCount > 0 else { return [] }

        var result = [Element]()
        result.reserveCapacity(elementCount)

        let startIndex = (writeIndex - elementCount + capacity) % capacity
        for i in 0..<elementCount {
            let index = (startIndex + i) % capacity
            guard let element = storage[index] else {
                continue
            }
            result.append(element)
        }

        return result
    }

    /// Removes all elements from the buffer.
    ///
    /// After calling this method, `count` is 0 but `capacity` remains unchanged.
    public mutating func removeAll() {
        storage = Array(repeating: nil, count: capacity)
        writeIndex = 0
        elementCount = 0
    }

    /// Returns a slice of the buffer from the specified range.
    ///
    /// - Parameter range: The range of indices to include.
    /// - Returns: Array containing the elements in the specified range.
    /// - Precondition: Range must be within bounds.
    public func slice(_ range: Range<Int>) -> [Element] {
        guard range.lowerBound >= 0, range.upperBound <= elementCount else {
            preconditionFailure("Slice range \(range) out of bounds for RingBuffer with count \(elementCount)")
        }

        var result = [Element]()
        result.reserveCapacity(range.count)

        for i in range {
            result.append(self[i])
        }

        return result
    }

    /// The total number of elements that have been appended since creation or last reset.
    ///
    /// This counter does not reset when elements are overwritten. Useful for
    /// tracking position in a stream.
    ///
    /// - Note: This property is not persisted in the basic implementation.
    ///   See `StreamingRingBuffer` for full stream position tracking.
}

// MARK: - Sequence Conformance

extension RingBuffer: Sequence {
    /// Creates an iterator that traverses elements from oldest to newest.
    ///
    /// The iterator yields elements in the order they were added, starting
    /// with the oldest element still in the buffer.
    ///
    /// - Returns: A `RingBufferIterator` for traversing this buffer.
    public func makeIterator() -> RingBufferIterator<Element> {
        RingBufferIterator(buffer: self)
    }
}

/// Iterator for `RingBuffer` that yields elements from oldest to newest.
public struct RingBufferIterator<Element: Sendable>: IteratorProtocol {
    private let buffer: RingBuffer<Element>
    private var currentIndex: Int = 0

    init(buffer: RingBuffer<Element>) {
        self.buffer = buffer
    }

    /// Advances to the next element and returns it, or `nil` if no next element exists.
    ///
    /// - Returns: The next element in the buffer, or `nil` if iteration is complete.
    public mutating func next() -> Element? {
        guard currentIndex < buffer.count else { return nil }
        let element = buffer[currentIndex]
        currentIndex += 1
        return element
    }
}

// MARK: - Collection Conformance

extension RingBuffer: Collection {
    /// The position of the first element (always 0 for non-empty buffers).
    public var startIndex: Int { 0 }

    /// The position one past the last valid element.
    public var endIndex: Int { elementCount }

    /// Returns the position immediately after the given index.
    ///
    /// - Parameter i: A valid index of the collection.
    /// - Returns: The index value immediately after `i`.
    public func index(after i: Int) -> Int {
        i + 1
    }
}

// MARK: - CustomStringConvertible

extension RingBuffer: CustomStringConvertible {
    /// A textual representation of the ring buffer.
    ///
    /// Returns a string showing the current count, capacity, and elements
    /// in order from oldest to newest.
    ///
    /// Example: `"RingBuffer(count: 3/5, [1, 2, 3])"`
    public var description: String {
        let elements = toArray().map { "\($0)" }.joined(separator: ", ")
        return "RingBuffer(count: \(count)/\(capacity), [\(elements)])"
    }
}

// MARK: - Equatable (when Element is Equatable)

extension RingBuffer: Equatable where Element: Equatable {
    /// Returns a Boolean value indicating whether two ring buffers are equal.
    ///
    /// Two ring buffers are equal if they contain the same number of elements
    /// and all corresponding elements are equal in order from oldest to newest.
    ///
    /// - Parameters:
    ///   - lhs: A ring buffer to compare.
    ///   - rhs: Another ring buffer to compare.
    /// - Returns: `true` if the buffers are equal; otherwise, `false`.
    public static func == (lhs: RingBuffer<Element>, rhs: RingBuffer<Element>) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for i in 0..<lhs.count {
            if lhs[i] != rhs[i] {
                return false
            }
        }
        return true
    }
}

// MARK: - Hashable (when Element is Hashable)

extension RingBuffer: Hashable where Element: Hashable {
    /// Hashes the essential components of this ring buffer.
    ///
    /// The hash incorporates the element count and all elements in order,
    /// ensuring equal buffers produce equal hash values.
    ///
    /// - Parameter hasher: The hasher to use when combining the components.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for element in self {
            hasher.combine(element)
        }
    }
}

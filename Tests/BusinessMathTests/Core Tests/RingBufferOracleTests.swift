//
//  RingBufferOracleTests.swift
//  BusinessMathTests
//
//  `RingBuffer` had **no test at all** — twenty members, including a full `Collection`
//  conformance, a custom `Sequence` iterator, `Equatable` and `Hashable`, none of them
//  executed. Measured with `swift test --enable-code-coverage`; it was one of the largest
//  untested clusters in the package.
//
//  A ring buffer has an exact model, which is what makes it worth differencing rather than
//  spot-checking: it behaves as "the last `min(n, capacity)` elements appended, in order".
//  So the oracle is an `Array` with `removeFirst()` on overflow, and the test below compares
//  **every** observable against it after **every** append, across four capacities — count,
//  `toArray()`, `first`, `last`, each subscript, the custom iterator, `for`-`in`, the
//  `Collection` path via `map`, `endIndex`, and every sub-range of `slice`.
//
//  **It matched at every point.** So did equality and hashing across differing internal write
//  positions, the `removeAll` lifecycle, and all three documented preconditions, which are
//  genuinely enforced. This is the second untested cluster in a row whose arithmetic proved
//  sound; recording that is the only thing that keeps "every oracle found a defect" from
//  being survivorship.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Ring buffer against an array model")
struct RingBufferOracleTests {

    /// The model: the last `capacity` elements appended, oldest first.
    private struct Model {
        let capacity: Int
        private(set) var elements: [Int] = []
        init(capacity: Int) { self.capacity = capacity }
        mutating func append(_ value: Int) {
            elements.append(value)
            if elements.count > capacity { elements.removeFirst() }
        }
    }

    /// Every observable, after every append, against the model.
    ///
    /// The capacities are chosen to cross the wraparound boundary several times each — a ring
    /// buffer that is never filled twice has not been tested, because the modular arithmetic
    /// in `(writeIndex - elementCount + index + capacity) % capacity` is the whole point.
    @Test("EveryObservable_MatchesTheModel", arguments: [1, 2, 3, 5, 8])
    func everyObservableMatchesTheModel(capacity: Int) {
        var buffer = RingBuffer<Int>(capacity: capacity)
        var model = Model(capacity: capacity)

        for value in 1...(capacity * 3 + 2) {
            buffer.append(value)
            model.append(value)
            let expected = model.elements

            #expect(buffer.count == expected.count, "count after \(value)")
            #expect(buffer.toArray() == expected, "toArray after \(value)")
            #expect(buffer.first == expected.first, "first after \(value)")
            #expect(buffer.last == expected.last, "last after \(value)")
            #expect(buffer.isEmpty == expected.isEmpty, "isEmpty after \(value)")
            #expect(buffer.isFull == (expected.count == capacity), "isFull after \(value)")
            #expect(buffer.startIndex == 0, "startIndex after \(value)")
            #expect(buffer.endIndex == expected.count, "endIndex after \(value)")

            for i in 0..<expected.count {
                #expect(buffer[i] == expected[i], "subscript[\(i)] after \(value)")
            }

            // The custom `Sequence` iterator, and `for`-`in`, which uses it.
            var iterator = buffer.makeIterator()
            var iterated: [Int] = []
            while let next = iterator.next() { iterated.append(next) }
            #expect(iterated == expected, "iterator after \(value)")

            var visited: [Int] = []
            for element in buffer { visited.append(element) }
            #expect(visited == expected, "for-in after \(value)")

            // `map` goes through `startIndex`, `index(after:)` and `subscript` rather than the
            // iterator, so it is a second, independent traversal — they have to agree.
            #expect(buffer.map { $0 } == expected, "map after \(value)")

            for lower in 0...expected.count {
                for upper in lower...expected.count {
                    #expect(buffer.slice(lower..<upper) == Array(expected[lower..<upper]),
                            "slice(\(lower)..<\(upper)) after \(value)")
                }
            }
        }
    }

    // MARK: - Equality is by contents, not by internal layout

    /// The classic ring-buffer equality defect is comparing raw storage, so that two buffers
    /// holding the same elements at different write positions compare unequal. They do not.
    @Test("Equality_IgnoresWritePosition") func equalityIgnoresWritePosition() {
        var fresh = RingBuffer<Int>(capacity: 3)
        for value in [7, 8, 9] { fresh.append(value) }

        var wrapped = RingBuffer<Int>(capacity: 3)
        for value in 1...9 { wrapped.append(value) }   // three full laps

        #expect(fresh.toArray() == wrapped.toArray(), "the fixture must actually differ internally")
        #expect(fresh == wrapped, "same contents, different write index")
        #expect(fresh.hashValue == wrapped.hashValue, "Hashable must agree with Equatable")
        #expect(fresh.description == wrapped.description, "description reports contents")
    }

    @Test("Equality_DiffersOnContents") func equalityDiffersOnContents() {
        var a = RingBuffer<Int>(capacity: 3)
        var b = RingBuffer<Int>(capacity: 3)
        for value in [1, 2, 3] { a.append(value) }
        for value in [1, 2, 4] { b.append(value) }
        #expect(a != b)
    }

    // MARK: - Lifecycle

    @Test("RemoveAll_EmptiesButKeepsCapacity") func removeAllEmptiesButKeepsCapacity() {
        var buffer = RingBuffer<Int>(capacity: 3)
        for value in 1...9 { buffer.append(value) }
        buffer.removeAll()

        #expect(buffer.count == 0)
        #expect(buffer.isEmpty)
        #expect(!buffer.isFull)
        #expect(buffer.toArray().isEmpty)
        #expect(buffer.first == nil)
        #expect(buffer.last == nil)

        // And it is reusable: the write position must have been reset with the count, or the
        // next append would land in the middle.
        buffer.append(42)
        #expect(buffer.toArray() == [42])
        var expectedFresh = RingBuffer<Int>(capacity: 3)
        expectedFresh.append(42)
        #expect(buffer == expectedFresh, "a cleared buffer behaves like a new one")
    }

    /// Capacity one is the degenerate ring: every append both fills and overwrites.
    @Test("CapacityOne_AlwaysHoldsTheLatest") func capacityOneAlwaysHoldsTheLatest() {
        var buffer = RingBuffer<Int>(capacity: 1)
        for value in 1...5 {
            buffer.append(value)
            #expect(buffer.count == 1)
            #expect(buffer.isFull)
            #expect(buffer.toArray() == [value])
            #expect(buffer[0] == value)
            #expect(buffer.first == value)
            #expect(buffer.last == value)
        }
    }

    // MARK: - The documented preconditions, which are enforced

    @Test("NonPositiveCapacity_Traps", .requiresUnsanitizedRuntime)
    func nonPositiveCapacityTraps() async {
        await #expect(processExitsWith: .failure) { _ = RingBuffer<Int>(capacity: 0) }
        await #expect(processExitsWith: .failure) { _ = RingBuffer<Int>(capacity: -1) }
    }

    @Test("SubscriptOutOfBounds_Traps", .requiresUnsanitizedRuntime)
    func subscriptOutOfBoundsTraps() async {
        await #expect(processExitsWith: .failure) {
            var buffer = RingBuffer<Int>(capacity: 3)
            buffer.append(1)
            _ = buffer[1]          // count is 1, so index 1 is past the end
        }
        await #expect(processExitsWith: .failure) {
            var buffer = RingBuffer<Int>(capacity: 3)
            buffer.append(1)
            _ = buffer[-1]
        }
    }

    @Test("SliceOutOfBounds_Traps", .requiresUnsanitizedRuntime)
    func sliceOutOfBoundsTraps() async {
        await #expect(processExitsWith: .failure) {
            var buffer = RingBuffer<Int>(capacity: 3)
            buffer.append(1)
            _ = buffer.slice(0..<2)
        }
    }
}

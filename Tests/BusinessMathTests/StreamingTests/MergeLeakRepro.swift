import Testing
import Foundation
@testable import BusinessMath

/// Deterministic reproduction of the streaming producer-task leak: an infinite source
/// merged, consumed briefly, then the producer must STOP (not keep yielding) once the
/// consumer goes away. Uses a shared counter that the source bumps on every element.
@Suite("Merge producer leak")
struct MergeLeakReproTests {

    /// An infinite AsyncSequence that yields 0,1,2,… and bumps `counter` on each element.
    struct InfiniteCounter: AsyncSequence, Sendable {
        typealias Element = Double
        let counter: Counter
        struct AsyncIterator: AsyncIteratorProtocol {
            let counter: Counter
            var n = 0
            mutating func next() async -> Double? {
                await counter.bump()
                let v = Double(n); n += 1
                await Task.yield()
                return v
            }
        }
        func makeAsyncIterator() -> AsyncIterator { AsyncIterator(counter: counter) }
    }

    actor Counter {
        private(set) var value = 0
        func bump() { value += 1 }
        func get() -> Int { value }
    }

    @Test("merge producer stops pulling the source after the consumer stops")
    func mergeProducerStopsAfterConsumer() async throws {
        let counter = Counter()
        let infinite = InfiniteCounter(counter: counter)
        let finite = AsyncValueStream([100.0, 200.0])

        // Consume a handful, then stop.
        var taken = 0
        for try await _ in infinite.merge(with: finite) {
            taken += 1
            if taken >= 5 { break }
        }
        #expect(taken == 5)

        // Give any teardown a moment, then snapshot the source's pull count.
        for _ in 0..<50 { await Task.yield() }
        let after = await counter.get()
        for _ in 0..<200 { await Task.yield() }
        let later = await counter.get()

        // If the producer leaked, `later` keeps climbing well past `after`.
        // With the fix, the producer is cancelled and the count stabilizes.
        #expect(later - after <= 2, "source kept being pulled after consumer stopped: \(after) → \(later)")
    }
}

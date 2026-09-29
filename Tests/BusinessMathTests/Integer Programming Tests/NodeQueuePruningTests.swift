//
//  NodeQueuePruningTests.swift
//  BusinessMathTests
//
//  Sixteen never-executed members in `BranchAndBound.swift`, and reading *which* ones is
//  more informative than the count. Most are file-private — `CutPool.ageCuts()`,
//  `prunePool()`, `ManagedCut` — reachable only through the solver. Their being unexecuted
//  does not mean nobody tested them directly; it means **no test ever drives a problem hard
//  enough to age a cut or fill the node queue**.
//
//  That is a correctness question rather than a coverage gap. Pruning is where a
//  branch-and-bound loses optimality: evict the wrong node and the search still returns *an*
//  answer, silently worse than the true optimum, with no diagnostic anywhere.
//
//  `NodeQueue` is internal rather than private, so its pruning can be driven directly and
//  checked against what it promises: keep the best half, discard the rest, and leave a valid
//  heap behind. It does all three, in both directions.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Node queue keeps the best nodes when it prunes")
struct NodeQueuePruningTests {

    private typealias V = VectorN<Double>

    /// Elementwise IEEE comparison; `==` on `[Double]` hides three different claims and the
    /// gate rejects it.
    private func agree(_ lhs: [Double], _ rhs: [Double]) -> Bool {
        // `isEqual(to:)` is IEEE equality, so `nan.isEqual(to: .nan)` is **false**. This sweep
    // deliberately marks unevaluable positions with `.nan`, so two NaNs in the same slot
    // are an agreement, not a mismatch — without this a marked position can never match.
    lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.isEqual(to: $1) || ($0.isNaN && $1.isNaN) }
    }

    private func node(bound: Double) -> BranchNode<V> {
        BranchNode<V>(depth: 0, parent: nil, constraints: [],
                      relaxationBound: bound, relaxationSolution: nil, branchedVariable: nil)
    }

    /// Bounds 1 through 11, inserted scrambled so neither insertion order nor sortedness can
    /// be doing the work. The eleventh insert trips the limit.
    private static let scrambled: [Double] = [5, 1, 9, 3, 11, 7, 2, 10, 4, 8, 6]

    /// Minimising, the best bounds are the **lowest**, so pruning must retain 1 through 5.
    @Test("Minimising_KeepsTheLowestBounds") func minimisingKeepsLowestBounds() {
        var queue = NodeQueue<V>(strategy: .bestBound, minimize: true, maxNodes: 10)
        for bound in Self.scrambled { queue.insert(node(bound: bound)) }

        #expect(queue.count == 5, "over the limit of 10, pruned to half")

        var drained: [Double] = []
        while let next = queue.extractBest() { drained.append(next.relaxationBound) }
        #expect(agree(drained, [1, 2, 3, 4, 5]), "the best five, and the heap still orders them")
    }

    /// Maximising, the best bounds are the **highest**, so the same input must retain 7
    /// through 11. Running both directions is what catches a comparison that ignores
    /// `minimize` — the retained set would look plausible and be exactly inverted.
    @Test("Maximising_KeepsTheHighestBounds") func maximisingKeepsHighestBounds() {
        var queue = NodeQueue<V>(strategy: .bestBound, minimize: false, maxNodes: 10)
        for bound in Self.scrambled { queue.insert(node(bound: bound)) }

        #expect(queue.count == 5)

        var drained: [Double] = []
        while let next = queue.extractBest() { drained.append(next.relaxationBound) }
        #expect(agree(drained, [11, 10, 9, 8, 7]))
    }

    /// The heap is rebuilt after pruning sorts and truncates the storage. If that rebuild
    /// were skipped the count would still be right and the *order* would be wrong, which is
    /// why extraction order is asserted above rather than set membership.
    @Test("ExtractionOrder_IsBestFirst") func extractionOrderIsBestFirst() {
        var minimising = NodeQueue<V>(strategy: .bestBound, minimize: true, maxNodes: 100)
        for bound in [5.0, 1.0, 9.0, 3.0] { minimising.insert(node(bound: bound)) }
        var ascending: [Double] = []
        while let next = minimising.extractBest() { ascending.append(next.relaxationBound) }
        #expect(agree(ascending, [1, 3, 5, 9]))

        var maximising = NodeQueue<V>(strategy: .bestBound, minimize: false, maxNodes: 100)
        for bound in [5.0, 1.0, 9.0, 3.0] { maximising.insert(node(bound: bound)) }
        var descending: [Double] = []
        while let next = maximising.extractBest() { descending.append(next.relaxationBound) }
        #expect(agree(descending, [9, 5, 3, 1]))
    }

    @Test("EmptyQueue") func emptyQueue() {
        var queue = NodeQueue<V>(strategy: .bestBound, minimize: true, maxNodes: 10)
        #expect(queue.isEmpty)
        #expect(queue.count == 0)
        #expect(queue.extractBest() == nil)

        queue.insert(node(bound: 1.0))
        #expect(!queue.isEmpty)
        #expect(queue.count == 1)
        _ = queue.extractBest()
        #expect(queue.isEmpty, "and empty again after draining")
    }

    /// Below the limit nothing is discarded — pruning must not fire early.
    @Test("UnderTheLimit_NothingIsPruned") func underTheLimitNothingIsPruned() {
        var queue = NodeQueue<V>(strategy: .bestBound, minimize: true, maxNodes: 10)
        for bound in stride(from: 1.0, through: 10.0, by: 1.0) { queue.insert(node(bound: bound)) }
        #expect(queue.count == 10, "exactly at the limit, still intact")
    }

    @Test("DefaultMaxNodes") func defaultMaxNodes() {
        #expect(NodeQueue<V>.defaultMaxNodes == 100_000)
    }

    // MARK: - Cut statistics

    /// `recordCuts` accumulates across calls and tallies by type, and `maxRoundsAtNode` is a
    /// running maximum rather than a sum — the one field where the difference shows.
    @Test("RecordCuts_AccumulatesAndTallies") func recordCutsAccumulatesAndTallies() {
        let tracker = CutStatisticsTracker()
        tracker.recordCuts(generated: 3, rounds: 2, type: .gomory)
        tracker.recordCuts(generated: 5, rounds: 4, type: .mixedIntegerRounding)
        tracker.recordCuts(generated: 1, rounds: 1, type: .gomory)

        #expect(tracker.totalCutsGenerated == 9, "3 + 5 + 1")
        #expect(tracker.cuttingRounds == 7, "2 + 4 + 1")
        #expect(tracker.lpResolves == 7, "one re-solve per round")
        #expect(tracker.maxRoundsAtNode == 4, "the largest single call, not the total")
        #expect(tracker.gomoryCuts == 4, "3 + 1, tallied by type")
        #expect(tracker.mirCuts == 5)
    }
}

//
//  VectorNSimplexProjectionTests.swift
//  BusinessMathTests
//
//  `VectorN.simplexProjection()` computed `self / sum`, which is a normalisation rather than
//  a projection. It had no test and no caller; it was found by working the list of 729
//  never-executed functions that `swift test --enable-code-coverage` produced.
//
//  The two agree only when every component is already non-negative, and its own
//  documentation named portfolio weights and probability distributions as the use cases —
//  neither of which normalisation produces for signed input:
//
//  | input | `v / sum(v)` | projection |
//  |---|---|---|
//  | `[1, 2, 3]` | `[0.167, 0.333, 0.5]` | `[0, 0, 1]` |
//  | `[-1, 0.5, 2]` | `[-0.667, 0.333, 1.333]` — **negative weight** | `[0, 0, 1]` |
//  | `[-5, -3, -1]` | `[0.556, 0.333, 0.111]` — **ordering reversed** | `[0, 0, 1]` |
//  | `[0, 0, 0]` | traps | `[1/3, 1/3, 1/3]` |
//
//  The third row is the expensive one: the most negative coordinate received the largest
//  weight, so a vector of expected returns would have been turned into a portfolio
//  concentrated in its worst asset.
//
//  These tests assert the projection by its **defining property** — non-negative, summing to
//  one, and no point of the simplex closer to the input — rather than by restating the
//  algorithm. A test that recomputed Duchi's steps would agree with a wrong implementation of
//  Duchi's steps.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Simplex projection is the nearest point on the simplex")
struct VectorNSimplexProjectionTests {

    private static let tolerance = 1e-12

    /// Elementwise agreement, stated as a deliberate IEEE comparison rather than `==` on the
    /// arrays — the count is part of the claim, and `==` would also call a NaN stream equal
    /// to nothing.
    private func agree(_ lhs: [Double], _ rhs: [Double]) -> Bool {
        lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.isEqual(to: $1) }
    }

    /// The closest point of the simplex to `input`, found on a grid. Used to check the
    /// projection's defining property rather than restating its algorithm: a test that
    /// recomputed Duchi's steps would agree with a wrong implementation of Duchi's steps.
    private func nearestOnGrid(to input: [Double], steps: Int = 400) -> Double {
        var best = Double.infinity
        for i in 0...steps {
            for j in 0...(steps - i) {
                let a = Double(i) / Double(steps)
                let b = Double(j) / Double(steps)
                let candidate = [a, b, 1.0 - a - b]
                let distance = zip(input, candidate).map { ($0 - $1) * ($0 - $1) }.reduce(0, +)
                best = Swift.min(best, distance)
            }
        }
        return best
    }

    /// The three conditions that define the projection: non-negative, summing to one, and
    /// nothing on the simplex closer. The third is what separates a projection from any other
    /// map onto the simplex, and it is the one the old `self / sum` failed.
    @Test("IsTheNearestSimplexPoint", arguments: [
        [1.0, 2.0, 3.0],
        [-1.0, 0.5, 2.0],
        [-5.0, -3.0, -1.0],
        [0.0, 0.0, 0.0],
        [0.5, 0.3, 0.2],
        [0.25, 0.25, 0.5],
        [100.0, -100.0, 0.0],
    ])
    func isTheNearestSimplexPoint(input: [Double]) {
        let projected = VectorN(input).simplexProjection().toArray()

        #expect(projected.count == input.count, "\(input)")
        #expect(projected.allSatisfy { $0 >= 0 }, "negative component in \(projected) for \(input)")

        let total = projected.reduce(0, +)
        #expect(abs(total - 1.0) < Self.tolerance, "\(projected) sums to \(total)")

        let distance = zip(input, projected).map { ($0 - $1) * ($0 - $1) }.reduce(0, +)
        let best = nearestOnGrid(to: input)
        #expect(distance <= best + 1e-9,
                "\(projected) is at \(distance) but the grid found \(best) for \(input)")
    }

    /// The four rows of the table, pinned as values so a regression names itself.
    @Test("KnownProjections") func knownProjections() {
        #expect(agree(VectorN([1.0, 2.0, 3.0]).simplexProjection().toArray(), [0.0, 0.0, 1.0]))
        #expect(agree(VectorN([-1.0, 0.5, 2.0]).simplexProjection().toArray(), [0.0, 0.0, 1.0]))
        #expect(agree(VectorN([-5.0, -3.0, -1.0]).simplexProjection().toArray(), [0.0, 0.0, 1.0]))

        // The origin's nearest simplex point is the centre, which the old code refused with
        // `preconditionFailure("Cannot project zero vector onto simplex")`.
        let uniform = VectorN([0.0, 0.0, 0.0]).simplexProjection().toArray()
        #expect(uniform.count == 3)
        #expect(uniform.allSatisfy { abs($0 - 1.0 / 3.0) < Self.tolerance }, "\(uniform)")
    }

    /// A point already on the simplex is its own projection, exactly, and stays there.
    @Test("IdempotentOnTheSimplex") func idempotentOnTheSimplex() {
        let onSimplex = [0.5, 0.3, 0.2]
        let once = VectorN(onSimplex).simplexProjection()
        #expect(agree(once.toArray(), onSimplex), "unchanged")
        #expect(agree(once.simplexProjection().toArray(), onSimplex), "stable under a second application")
    }

    /// The degenerate one-component case: the only point of the 1-simplex is 1.
    @Test("SingleComponent_IsAlwaysOne", arguments: [10.0, 0.0, -7.5])
    func singleComponentIsAlwaysOne(value: Double) {
        #expect(agree(VectorN([value]).simplexProjection().toArray(), [1.0]), "input \(value)")
    }

    // MARK: - The operation that used to wear the other one's name

    @Test("NormalizedToSumOne_KeepsProportions") func normalizedToSumOneKeepsProportions() throws {
        let result = try #require(VectorN([3.0, 1.0, 2.0]).normalizedToSumOne()).toArray()
        #expect(result.count == 3)
        #expect(abs(result[0] - 0.5) < Self.tolerance)
        #expect(abs(result[1] - 1.0 / 6.0) < Self.tolerance)
        #expect(abs(result[2] - 1.0 / 3.0) < Self.tolerance)
        #expect(abs(result.reduce(0, +) - 1.0) < Self.tolerance)
    }

    /// It returns `nil` rather than trapping, which is the behavioural improvement that
    /// replaces the old body's `preconditionFailure`.
    @Test("NormalizedToSumOne_IsNilWhenTheSumIsZero") func normalizedToSumOneIsNilAtZeroSum() {
        #expect(VectorN([0.0, 0.0, 0.0]).normalizedToSumOne() == nil)
        #expect(VectorN([1.0, -1.0]).normalizedToSumOne() == nil, "cancels to zero")
    }

    /// And it is honest about what it is not: for signed input it does **not** produce a
    /// weight vector, which is precisely why it no longer carries the projection's name.
    @Test("NormalizedToSumOne_DoesNotProduceWeights") func normalizedToSumOneDoesNotProduceWeights() throws {
        let signed = try #require(VectorN([-1.0, 0.5, 2.0]).normalizedToSumOne()).toArray()
        #expect(signed.contains { $0 < 0 }, "a negative component survives: \(signed)")

        let allNegative = try #require(VectorN([-5.0, -3.0, -1.0]).normalizedToSumOne()).toArray()
        #expect(allNegative[0] > allNegative[2],
                "ordering reversed: the most negative input takes the largest share, \(allNegative)")
    }
}

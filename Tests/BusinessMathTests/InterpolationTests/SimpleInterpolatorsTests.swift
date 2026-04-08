//
//  SimpleInterpolatorsTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-07.
//
//  Tests for the four "simple" 1D interpolators that don't require
//  precomputed coefficients: NearestNeighbor, PreviousValue, NextValue,
//  Linear. Cubic methods get their own test files.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("NearestNeighborInterpolator")
struct NearestNeighborTests {

    static let xs: [Double] = [0, 1, 2, 3, 4]
    static let ys: [Double] = [0, 1, 4, 9, 16]

    @Test("Pass-through at exact knots")
    func passThrough() throws {
        let interp = try NearestNeighborInterpolator(xs: Self.xs, ys: Self.ys)
        for i in 0..<Self.xs.count {
            #expect(interp(Self.xs[i]) == Self.ys[i])
        }
    }

    @Test("Returns closest value for non-knot queries")
    func closestValue() throws {
        let interp = try NearestNeighborInterpolator(xs: Self.xs, ys: Self.ys)
        #expect(interp(0.4) == 0.0)   // closer to xs[0]=0
        #expect(interp(0.6) == 1.0)   // closer to xs[1]=1
        #expect(interp(2.6) == 9.0)   // closer to xs[3]=3
    }

    @Test("Tie resolves to lower index")
    func tieResolvesLow() throws {
        let interp = try NearestNeighborInterpolator(xs: Self.xs, ys: Self.ys)
        // Halfway between xs[2]=2 and xs[3]=3 → returns ys[2]=4
        #expect(interp(2.5) == 4.0)
    }

    @Test("Vector1D query equivalence")
    func vector1DQuery() throws {
        let interp = try NearestNeighborInterpolator(xs: Self.xs, ys: Self.ys)
        #expect(interp(at: Vector1D(0.6)) == interp(0.6))
    }

    @Test("Clamp extrapolation (default)")
    func clampExtrapolation() throws {
        let interp = try NearestNeighborInterpolator(xs: Self.xs, ys: Self.ys)
        #expect(interp(-100.0) == 0.0)
        #expect(interp(100.0) == 16.0)
    }

    @Test("Constant extrapolation")
    func constantExtrapolation() throws {
        let interp = try NearestNeighborInterpolator(
            xs: Self.xs, ys: Self.ys, outOfBounds: .constant(-1)
        )
        #expect(interp(-100.0) == -1.0)
        #expect(interp(100.0) == -1.0)
        #expect(interp(2.0) == 4.0)  // in-range still works
    }

    @Test("Single point degenerate case")
    func singlePoint() throws {
        let interp = try NearestNeighborInterpolator(xs: [5.0], ys: [42.0])
        #expect(interp(0.0) == 42.0)
        #expect(interp(5.0) == 42.0)
        #expect(interp(100.0) == 42.0)
    }

    @Test("Throws on empty input")
    func throwsOnEmpty() {
        #expect(throws: InterpolationError.self) {
            _ = try NearestNeighborInterpolator(xs: [Double](), ys: [Double]())
        }
    }

    @Test("Throws on mismatched sizes")
    func throwsOnMismatched() {
        #expect(throws: InterpolationError.self) {
            _ = try NearestNeighborInterpolator(xs: [0.0, 1.0], ys: [0.0])
        }
    }

    @Test("Throws on unsorted xs")
    func throwsOnUnsorted() {
        #expect(throws: InterpolationError.self) {
            _ = try NearestNeighborInterpolator(xs: [0.0, 2.0, 1.0], ys: [0.0, 4.0, 1.0])
        }
    }

    @Test("Throws on duplicate xs")
    func throwsOnDuplicate() {
        #expect(throws: InterpolationError.self) {
            _ = try NearestNeighborInterpolator(xs: [0.0, 1.0, 1.0], ys: [0.0, 1.0, 2.0])
        }
    }

    @Test("inputDimension and outputDimension are 1")
    func dimensions() throws {
        let interp = try NearestNeighborInterpolator(xs: Self.xs, ys: Self.ys)
        #expect(interp.inputDimension == 1)
        #expect(interp.outputDimension == 1)
    }
}

@Suite("PreviousValueInterpolator")
struct PreviousValueTests {

    static let xs: [Double] = [0, 1, 2, 3, 4]
    static let ys: [Double] = [0, 1, 4, 9, 16]

    @Test("Pass-through at exact knots")
    func passThrough() throws {
        let interp = try PreviousValueInterpolator(xs: Self.xs, ys: Self.ys)
        for i in 0..<Self.xs.count {
            #expect(interp(Self.xs[i]) == Self.ys[i])
        }
    }

    @Test("Returns previous y for in-interval queries")
    func previousValue() throws {
        let interp = try PreviousValueInterpolator(xs: Self.xs, ys: Self.ys)
        #expect(interp(0.5) == 0.0)
        #expect(interp(0.999) == 0.0)
        #expect(interp(2.5) == 4.0)
        #expect(interp(3.7) == 9.0)
    }

    @Test("Clamp extrapolation")
    func clampExtrapolation() throws {
        let interp = try PreviousValueInterpolator(xs: Self.xs, ys: Self.ys)
        #expect(interp(-1.0) == 0.0)
        #expect(interp(5.0) == 16.0)
    }

    @Test("Vector1D query equivalence")
    func vector1DQuery() throws {
        let interp = try PreviousValueInterpolator(xs: Self.xs, ys: Self.ys)
        #expect(interp(at: Vector1D(2.5)) == interp(2.5))
    }

    @Test("Single point degenerate case")
    func singlePoint() throws {
        let interp = try PreviousValueInterpolator(xs: [5.0], ys: [42.0])
        #expect(interp(0.0) == 42.0)
        #expect(interp(5.0) == 42.0)
        #expect(interp(100.0) == 42.0)
    }

    @Test("Throws on empty input")
    func throwsOnEmpty() {
        #expect(throws: InterpolationError.self) {
            _ = try PreviousValueInterpolator(xs: [Double](), ys: [Double]())
        }
    }
}

@Suite("NextValueInterpolator")
struct NextValueTests {

    static let xs: [Double] = [0, 1, 2, 3, 4]
    static let ys: [Double] = [0, 1, 4, 9, 16]

    @Test("Pass-through at exact knots — the bug-fix regression test")
    func passThroughAtExactKnots() throws {
        // The playground caught a bug where NextValue at xs[i] returned ys[i+1]
        // instead of ys[i]. This test locks in the correct pass-through behavior.
        let interp = try NextValueInterpolator(xs: Self.xs, ys: Self.ys)
        for i in 0..<Self.xs.count {
            #expect(interp(Self.xs[i]) == Self.ys[i])
        }
    }

    @Test("Returns next y for in-interval queries")
    func nextValue() throws {
        let interp = try NextValueInterpolator(xs: Self.xs, ys: Self.ys)
        #expect(interp(0.001) == 1.0)
        #expect(interp(0.5) == 1.0)
        #expect(interp(2.001) == 9.0)
        #expect(interp(3.7) == 16.0)
    }

    @Test("Clamp extrapolation")
    func clampExtrapolation() throws {
        let interp = try NextValueInterpolator(xs: Self.xs, ys: Self.ys)
        #expect(interp(-1.0) == 0.0)
        #expect(interp(5.0) == 16.0)
    }

    @Test("Vector1D query equivalence")
    func vector1DQuery() throws {
        let interp = try NextValueInterpolator(xs: Self.xs, ys: Self.ys)
        #expect(interp(at: Vector1D(2.5)) == interp(2.5))
    }
}

@Suite("LinearInterpolator")
struct LinearInterpolatorTests {

    static let xs: [Double] = [0, 1, 2, 3, 4]
    static let ys: [Double] = [0, 1, 4, 9, 16]

    @Test("Pass-through at exact knots")
    func passThrough() throws {
        let interp = try LinearInterpolator(xs: Self.xs, ys: Self.ys)
        for i in 0..<Self.xs.count {
            #expect(abs(interp(Self.xs[i]) - Self.ys[i]) < 1e-12)
        }
    }

    @Test("Hand-computed values from validation playground")
    func handComputedValues() throws {
        // Values verified by Tests/Validation/Interpolation_Playground.swift
        let interp = try LinearInterpolator(xs: Self.xs, ys: Self.ys)
        #expect(abs(interp(0.5) - 0.5) < 1e-12)   // (0 + 1)/2
        #expect(abs(interp(1.5) - 2.5) < 1e-12)   // (1 + 4)/2
        #expect(abs(interp(2.5) - 6.5) < 1e-12)   // (4 + 9)/2
        #expect(abs(interp(3.5) - 12.5) < 1e-12)  // (9 + 16)/2
    }

    @Test("Linear data invariant — reproduces a*x+b exactly")
    func linearDataInvariant() throws {
        // y = 3x + 7 — must be reproduced exactly to machine precision
        let xs: [Double] = [0, 1, 2, 3, 4, 5]
        let ys: [Double] = xs.map { 3.0 * $0 + 7.0 }
        let interp = try LinearInterpolator(xs: xs, ys: ys)
        let probes: [Double] = [0.0, 0.7, 1.5, 2.3, 3.9, 4.4, 5.0]
        for q in probes {
            let expected = 3.0 * q + 7.0
            #expect(abs(interp(q) - expected) < 1e-12)
        }
    }

    @Test("Clamp extrapolation")
    func clampExtrapolation() throws {
        let interp = try LinearInterpolator(xs: Self.xs, ys: Self.ys)
        #expect(interp(-1.0) == 0.0)
        #expect(interp(5.0) == 16.0)
    }

    @Test("Vector1D query equivalence")
    func vector1DQuery() throws {
        let interp = try LinearInterpolator(xs: Self.xs, ys: Self.ys)
        #expect(interp(at: Vector1D(2.5)) == interp(2.5))
    }

    @Test("Throws on insufficient points")
    func throwsOnInsufficientPoints() {
        #expect(throws: InterpolationError.self) {
            _ = try LinearInterpolator(xs: [0.0], ys: [0.0])
        }
    }

    @Test("Batch evaluation matches single-query evaluation")
    func batchEvaluation() throws {
        let interp = try LinearInterpolator(xs: Self.xs, ys: Self.ys)
        let queries = [Vector1D(0.5), Vector1D(1.5), Vector1D(2.5), Vector1D(3.5)]
        let batched = interp(at: queries)
        let single = queries.map { interp(at: $0) }
        #expect(batched == single)
    }
}

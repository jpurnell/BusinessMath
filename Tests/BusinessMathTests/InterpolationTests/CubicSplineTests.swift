//
//  CubicSplineTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-07.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("CubicSplineInterpolator")
struct CubicSplineTests {

    static let xs: [Double] = [0, 1, 2, 3, 4]
    static let ys: [Double] = [0, 1, 4, 9, 16]   // y = x²

    // MARK: - Pass-through invariant

    @Test("Natural BC: pass-through at exact knots")
    func naturalPassThrough() throws {
        let interp = try CubicSplineInterpolator(xs: Self.xs, ys: Self.ys, boundary: .natural)
        for i in 0..<Self.xs.count {
            #expect(abs(interp(Self.xs[i]) - Self.ys[i]) < 1e-12)
        }
    }

    @Test("Not-a-knot BC: pass-through at exact knots")
    func notAKnotPassThrough() throws {
        let interp = try CubicSplineInterpolator(xs: Self.xs, ys: Self.ys, boundary: .notAKnot)
        for i in 0..<Self.xs.count {
            #expect(abs(interp(Self.xs[i]) - Self.ys[i]) < 1e-12)
        }
    }

    @Test("Clamped BC: pass-through at exact knots")
    func clampedPassThrough() throws {
        let interp = try CubicSplineInterpolator(
            xs: Self.xs, ys: Self.ys, boundary: .clamped(left: 0.0, right: 8.0)
        )
        for i in 0..<Self.xs.count {
            #expect(abs(interp(Self.xs[i]) - Self.ys[i]) < 1e-12)
        }
    }

    @Test("Periodic BC: pass-through at exact knots")
    func periodicPassThrough() throws {
        let xs: [Double] = [0, 1, 2, 3, 4]
        let ys: [Double] = [0, 1, 4, 1, 0]   // periodic: ys.first == ys.last
        let interp = try CubicSplineInterpolator(xs: xs, ys: ys, boundary: .periodic)
        for i in 0..<xs.count {
            #expect(abs(interp(xs[i]) - ys[i]) < 1e-9)
        }
    }

    // MARK: - Linear-data invariant

    @Test("Natural BC: reproduces linear data exactly")
    func naturalLinearInvariant() throws {
        let xs: [Double] = [0, 1, 2, 3, 4, 5]
        let ys: [Double] = xs.map { 3.0 * $0 + 7.0 }
        let interp = try CubicSplineInterpolator(xs: xs, ys: ys, boundary: .natural)
        let probes: [Double] = [0.0, 0.7, 1.5, 2.3, 3.9, 4.4, 5.0]
        for q in probes {
            let expected = 3.0 * q + 7.0
            #expect(abs(interp(q) - expected) < 1e-10)
        }
    }

    @Test("Not-a-knot BC: reproduces linear data exactly")
    func notAKnotLinearInvariant() throws {
        let xs: [Double] = [0, 1, 2, 3, 4, 5]
        let ys: [Double] = xs.map { 3.0 * $0 + 7.0 }
        let interp = try CubicSplineInterpolator(xs: xs, ys: ys, boundary: .notAKnot)
        let probes: [Double] = [0.0, 0.7, 1.5, 2.3, 3.9, 4.4, 5.0]
        for q in probes {
            let expected = 3.0 * q + 7.0
            #expect(abs(interp(q) - expected) < 1e-10)
        }
    }

    @Test("Clamped BC: reproduces linear data exactly when slopes are correct")
    func clampedLinearInvariant() throws {
        let xs: [Double] = [0, 1, 2, 3, 4, 5]
        let ys: [Double] = xs.map { 3.0 * $0 + 7.0 }
        let interp = try CubicSplineInterpolator(
            xs: xs, ys: ys, boundary: .clamped(left: 3.0, right: 3.0)
        )
        let probes: [Double] = [0.0, 0.7, 1.5, 2.3, 3.9, 4.4, 5.0]
        for q in probes {
            let expected = 3.0 * q + 7.0
            #expect(abs(interp(q) - expected) < 1e-10)
        }
    }

    // MARK: - Hand-computed natural cubic spline (from validation playground)

    @Test("Natural BC: hand-computed values from validation playground")
    func naturalHandComputed() throws {
        // Reference values from Tests/Validation/Interpolation_Playground.swift
        // §5 NaturalCubicSpline output for xs=[0,1,2,3,4], ys=[0,1,4,9,16].
        // Natural cubic spline is NOT an exact fit to y=x² (it's a quadratic,
        // not a natural cubic spline) — these are the canonical reference
        // values the package implementation must reproduce.
        let interp = try CubicSplineInterpolator(xs: Self.xs, ys: Self.ys, boundary: .natural)
        #expect(abs(interp(0.5) - 0.3392857142857143) < 1e-12)
        #expect(abs(interp(1.5) - 2.232142857142857) < 1e-12)
        #expect(abs(interp(2.5) - 6.232142857142857) < 1e-12)
        #expect(abs(interp(3.5) - 12.339285714285714) < 1e-12)
    }

    // MARK: - Vector1D query equivalence

    @Test("Vector1D query equivalence")
    func vector1DQuery() throws {
        let interp = try CubicSplineInterpolator(xs: Self.xs, ys: Self.ys)
        #expect(interp(at: Vector1D(2.5)) == interp(2.5))
    }

    // MARK: - Errors

    @Test("Throws on insufficient points for natural")
    func throwsOnInsufficientNatural() throws {
        #expect(throws: InterpolationError.insufficientPoints(required: 3, got: 2)) {
            _ = try CubicSplineInterpolator(xs: [0.0, 1.0], ys: [0.0, 1.0], boundary: .natural)
        }
    }

    @Test("Clamped allows 2-point input, and honours slopes that differ")
    func clampedAllowsTwoPoints() throws {
        // FIXTURE REPLACED. This read `xs: [0, 1], ys: [0, 1], clamped(left: 1, right: 1)` and
        // asserted `interp(0.5) ≈ 0.5`. That is the one configuration where
        // `left == right == the chord slope`, so the second derivatives genuinely are zero —
        // and the two-point branch discarded `left` and `right` entirely and returned `[0, 0]`
        // regardless. The test passed for the whole life of the bug because its fixture was
        // the bug's only correct case. All three quantities differ below.
        let left: Double = 0.5
        let right: Double = 3.0
        let interp = try CubicSplineInterpolator(
            xs: [0.0, 2.0], ys: [1.0, 5.0], boundary: .clamped(left: left, right: right)
        )
        // The unique cubic with p(0) = 1, p(2) = 5, p'(0) = 0.5 and p'(2) = 3 is
        // p(x) = 1 + 0.5x + x² − 0.125x³. `InterpolationAndLimitsTests` derives it from those
        // four conditions in general form; here it is written out and evaluated.
        let t: Double = 1.0
        let linearPart: Double = 1.0 + left * t
        let quadraticPart: Double = t * t
        let cubicPart: Double = 0.125 * t * t * t
        let expected: Double = linearPart + quadraticPart - cubicPart
        let got: Double = interp(t)
        #expect(abs(got - expected) < 1e-12, "got \(got), wanted \(expected)")

        // The chord — what `[0, 0]` second derivatives produce — is 3.0 at t = 1.
        let chord: Double = 1.0 + 2.0 * t
        #expect(abs(got - chord) > 0.5, "spline collapsed to the chord \(chord); got \(got)")

        // Pass-through at both knots, unchanged.
        #expect(abs(interp(0.0) - 1.0) < 1e-12)
        #expect(abs(interp(2.0) - 5.0) < 1e-12)
    }

    @Test("Periodic throws when ys.first != ys.last")
    func periodicThrowsOnMismatch() throws {
        #expect(
        	throws: InterpolationError.invalidParameter(message: "Periodic cubic spline requires ys.first == ys.last")
        ) {
            _ = try CubicSplineInterpolator(
                xs: [0.0, 1.0, 2.0, 3.0],
                ys: [0.0, 1.0, 4.0, 9.0],   // not periodic
                boundary: .periodic
            )
        }
    }

    // MARK: - Dimensions

    @Test("inputDimension and outputDimension are 1")
    func dimensions() throws {
        let interp = try CubicSplineInterpolator(xs: Self.xs, ys: Self.ys)
        #expect(interp.inputDimension == 1)
        #expect(interp.outputDimension == 1)
    }
}

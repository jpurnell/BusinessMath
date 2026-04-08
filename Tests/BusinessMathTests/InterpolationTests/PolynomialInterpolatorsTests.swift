//
//  PolynomialInterpolatorsTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-07.
//
//  Tests for BSplineInterpolator and BarycentricLagrangeInterpolator.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("BSplineInterpolator")
struct BSplineTests {

    static let xs: [Double] = [0, 1, 2, 3, 4]
    static let ys: [Double] = [0, 1, 4, 9, 16]

    @Test("Default cubic (degree=3): pass-through")
    func cubicPassThrough() throws {
        let interp = try BSplineInterpolator(xs: Self.xs, ys: Self.ys)
        for i in 0..<Self.xs.count {
            #expect(abs(interp(Self.xs[i]) - Self.ys[i]) < 1e-12)
        }
    }

    @Test("Linear (degree=1) matches LinearInterpolator")
    func linearMatchesLinearInterpolator() throws {
        let bspline = try BSplineInterpolator(xs: Self.xs, ys: Self.ys, degree: 1)
        let linear = try LinearInterpolator(xs: Self.xs, ys: Self.ys)
        for q in [0.0, 0.5, 1.5, 2.5, 3.5, 4.0] {
            #expect(abs(bspline(q) - linear(q)) < 1e-12)
        }
    }

    @Test("Cubic (degree=3) matches CubicSpline.notAKnot")
    func cubicMatchesNotAKnotSpline() throws {
        let bspline = try BSplineInterpolator(xs: Self.xs, ys: Self.ys, degree: 3)
        let spline = try CubicSplineInterpolator(xs: Self.xs, ys: Self.ys, boundary: .notAKnot)
        for q in [0.0, 0.5, 1.5, 2.5, 3.5, 4.0] {
            #expect(abs(bspline(q) - spline(q)) < 1e-12)
        }
    }

    @Test("Reproduces linear data exactly")
    func linearInvariant() throws {
        let xs: [Double] = [0, 1, 2, 3, 4, 5]
        let ys: [Double] = xs.map { 3.0 * $0 + 7.0 }
        let interp = try BSplineInterpolator(xs: xs, ys: ys, degree: 3)
        for q in [0.0, 0.7, 1.5, 2.3, 3.9, 4.4, 5.0] {
            #expect(abs(interp(q) - (3.0 * q + 7.0)) < 1e-10)
        }
    }

    @Test("Throws on degree out of range")
    func throwsOnInvalidDegree() {
        #expect(throws: InterpolationError.self) {
            _ = try BSplineInterpolator(xs: [0.0, 1.0, 2.0], ys: [0.0, 1.0, 4.0], degree: 0)
        }
        #expect(throws: InterpolationError.self) {
            _ = try BSplineInterpolator(xs: [0.0, 1.0, 2.0], ys: [0.0, 1.0, 4.0], degree: 6)
        }
    }

    @Test("Vector1D query equivalence")
    func vector1DQuery() throws {
        let interp = try BSplineInterpolator(xs: Self.xs, ys: Self.ys)
        #expect(interp(at: Vector1D(2.5)) == interp(2.5))
    }
}

@Suite("BarycentricLagrangeInterpolator")
struct BarycentricLagrangeTests {

    static let xs: [Double] = [0, 1, 2, 3, 4]
    static let ys: [Double] = [0, 1, 4, 9, 16]   // y = x²

    @Test("Pass-through at exact knots")
    func passThrough() throws {
        let interp = try BarycentricLagrangeInterpolator(xs: Self.xs, ys: Self.ys)
        for i in 0..<Self.xs.count {
            #expect(abs(interp(Self.xs[i]) - Self.ys[i]) < 1e-12)
        }
    }

    @Test("Polynomial through 5 points exactly recovers y = x²")
    func recoversPolynomial() throws {
        // The unique polynomial of degree ≤ 4 through these 5 points is y = x²,
        // so barycentric Lagrange should recover the analytic value at every query.
        let interp = try BarycentricLagrangeInterpolator(xs: Self.xs, ys: Self.ys)
        let probes: [Double] = [0.5, 1.5, 2.5, 3.5]
        for q in probes {
            let expected = q * q
            #expect(abs(interp(q) - expected) < 1e-12)
        }
    }

    @Test("Reproduces linear data exactly")
    func linearInvariant() throws {
        let xs: [Double] = [0, 1, 2, 3, 4, 5]
        let ys: [Double] = xs.map { 3.0 * $0 + 7.0 }
        let interp = try BarycentricLagrangeInterpolator(xs: xs, ys: ys)
        for q in [0.0, 0.7, 1.5, 2.3, 3.9, 4.4, 5.0] {
            #expect(abs(interp(q) - (3.0 * q + 7.0)) < 1e-10)
        }
    }

    @Test("Single-point degenerate case")
    func singlePoint() throws {
        let interp = try BarycentricLagrangeInterpolator(xs: [5.0], ys: [42.0])
        #expect(interp(0.0) == 42.0)
        #expect(interp(5.0) == 42.0)
        #expect(interp(100.0) == 42.0)
    }

    @Test("Throws on empty input")
    func throwsOnEmpty() {
        #expect(throws: InterpolationError.self) {
            _ = try BarycentricLagrangeInterpolator(xs: [Double](), ys: [Double]())
        }
    }

    @Test("Vector1D query equivalence")
    func vector1DQuery() throws {
        let interp = try BarycentricLagrangeInterpolator(xs: Self.xs, ys: Self.ys)
        #expect(interp(at: Vector1D(2.5)) == interp(2.5))
    }

    @Test("Throws on duplicate xs")
    func throwsOnDuplicate() {
        #expect(throws: InterpolationError.self) {
            _ = try BarycentricLagrangeInterpolator(
                xs: [0.0, 1.0, 1.0, 2.0],
                ys: [0.0, 1.0, 1.5, 4.0]
            )
        }
    }
}

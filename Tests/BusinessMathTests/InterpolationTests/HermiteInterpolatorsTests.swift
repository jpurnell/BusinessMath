//
//  HermiteInterpolatorsTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-07.
//
//  Tests for the three Hermite-cubic interpolators:
//  PCHIP, Akima (original + modified), and CatmullRom (cardinal spline).
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("PCHIPInterpolator")
struct PCHIPTests {

    static let xs: [Double] = [0, 1, 2, 3, 4]
    static let ys: [Double] = [0, 1, 4, 9, 16]

    @Test("Pass-through at exact knots")
    func passThrough() throws {
        let interp = try PCHIPInterpolator(xs: Self.xs, ys: Self.ys)
        for i in 0..<Self.xs.count {
            #expect(abs(interp(Self.xs[i]) - Self.ys[i]) < 1e-12)
        }
    }

    @Test("Reproduces linear data exactly")
    func linearInvariant() throws {
        let xs: [Double] = [0, 1, 2, 3, 4, 5]
        let ys: [Double] = xs.map { 3.0 * $0 + 7.0 }
        let interp = try PCHIPInterpolator(xs: xs, ys: ys)
        for q in [0.0, 0.7, 1.5, 2.3, 3.9, 4.4, 5.0] {
            #expect(abs(interp(q) - (3.0 * q + 7.0)) < 1e-12)
        }
    }

    @Test("Hand-computed values from validation playground")
    func handComputed() throws {
        let interp = try PCHIPInterpolator(xs: Self.xs, ys: Self.ys)
        #expect(abs(interp(0.5) - 0.3125) < 1e-12)
        #expect(abs(interp(1.5) - 2.21875) < 1e-12)
        #expect(abs(interp(2.5) - 6.239583333333333) < 1e-12)
        #expect(abs(interp(3.5) - 12.229166666666668) < 1e-12)
    }

    @Test("Monotonicity preservation on sharp-gradient data")
    func monotonicityPreservation() throws {
        // Same fixture as the validation playground monotonicity check
        let xs: [Double] = [0, 1, 2, 3, 4, 5, 6]
        let ys: [Double] = [0, 0.1, 0.2, 5, 5.1, 5.2, 5.3]
        let interp = try PCHIPInterpolator(xs: xs, ys: ys)
        let dataMin = ys.min()!
        let dataMax = ys.max()!
        // Densely sample and assert no overshoot
        for i in 0...600 {
            let t = Double(i) / 100.0
            let v = interp(t)
            #expect(v >= dataMin - 1e-9)
            #expect(v <= dataMax + 1e-9)
        }
    }

    @Test("Vector1D query equivalence")
    func vector1DQuery() throws {
        let interp = try PCHIPInterpolator(xs: Self.xs, ys: Self.ys)
        #expect(interp(at: Vector1D(2.5)) == interp(2.5))
    }

    @Test("Throws on insufficient points")
    func throwsOnInsufficient() {
        #expect(throws: InterpolationError.self) {
            _ = try PCHIPInterpolator(xs: [0.0], ys: [0.0])
        }
    }
}

@Suite("AkimaInterpolator")
struct AkimaTests {

    static let xs: [Double] = [0, 1, 2, 3, 4]
    static let ys: [Double] = [0, 1, 4, 9, 16]

    @Test("Default modified=true (makima): pass-through")
    func makimaPassThrough() throws {
        let interp = try AkimaInterpolator(xs: Self.xs, ys: Self.ys)
        for i in 0..<Self.xs.count {
            #expect(abs(interp(Self.xs[i]) - Self.ys[i]) < 1e-12)
        }
    }

    @Test("Original Akima (modified=false): pass-through")
    func originalPassThrough() throws {
        let interp = try AkimaInterpolator(xs: Self.xs, ys: Self.ys, modified: false)
        for i in 0..<Self.xs.count {
            #expect(abs(interp(Self.xs[i]) - Self.ys[i]) < 1e-12)
        }
    }

    @Test("Original Akima: hand-computed values from validation playground")
    func originalHandComputed() throws {
        let interp = try AkimaInterpolator(xs: Self.xs, ys: Self.ys, modified: false)
        #expect(abs(interp(0.5) - 0.25) < 1e-12)
        #expect(abs(interp(1.5) - 2.25) < 1e-12)
        #expect(abs(interp(2.5) - 6.25) < 1e-12)
        #expect(abs(interp(3.5) - 12.25) < 1e-12)
    }

    @Test("Makima: hand-computed values from validation playground")
    func makimaHandComputed() throws {
        let interp = try AkimaInterpolator(xs: Self.xs, ys: Self.ys, modified: true)
        #expect(abs(interp(0.5) - 0.3125) < 1e-12)
        #expect(abs(interp(1.5) - 2.2291666666666665) < 1e-12)
        #expect(abs(interp(2.5) - 6.239583333333334) < 1e-12)
        #expect(abs(interp(3.5) - 12.24375) < 1e-12)
    }

    @Test("Makima reproduces linear data exactly")
    func makimaLinearInvariant() throws {
        let xs: [Double] = [0, 1, 2, 3, 4, 5]
        let ys: [Double] = xs.map { 3.0 * $0 + 7.0 }
        let interp = try AkimaInterpolator(xs: xs, ys: ys, modified: true)
        for q in [0.0, 0.7, 1.5, 2.3, 3.9, 4.4, 5.0] {
            #expect(abs(interp(q) - (3.0 * q + 7.0)) < 1e-12)
        }
    }

    @Test("Original Akima reproduces linear data exactly")
    func originalLinearInvariant() throws {
        let xs: [Double] = [0, 1, 2, 3, 4, 5]
        let ys: [Double] = xs.map { 3.0 * $0 + 7.0 }
        let interp = try AkimaInterpolator(xs: xs, ys: ys, modified: false)
        for q in [0.0, 0.7, 1.5, 2.3, 3.9, 4.4, 5.0] {
            #expect(abs(interp(q) - (3.0 * q + 7.0)) < 1e-12)
        }
    }

    @Test("Monotonicity preservation on sharp-gradient data")
    func monotonicityPreservation() throws {
        let xs: [Double] = [0, 1, 2, 3, 4, 5, 6]
        let ys: [Double] = [0, 0.1, 0.2, 5, 5.1, 5.2, 5.3]
        let interp = try AkimaInterpolator(xs: xs, ys: ys, modified: true)
        let dataMin = ys.min()!
        let dataMax = ys.max()!
        for i in 0...600 {
            let t = Double(i) / 100.0
            let v = interp(t)
            #expect(v >= dataMin - 1e-9)
            #expect(v <= dataMax + 1e-9)
        }
    }
}

@Suite("CatmullRomInterpolator")
struct CatmullRomTests {

    static let xs: [Double] = [0, 1, 2, 3, 4]
    static let ys: [Double] = [0, 1, 4, 9, 16]

    @Test("Default tension=0 (standard Catmull-Rom): pass-through")
    func defaultPassThrough() throws {
        let interp = try CatmullRomInterpolator(xs: Self.xs, ys: Self.ys)
        for i in 0..<Self.xs.count {
            #expect(abs(interp(Self.xs[i]) - Self.ys[i]) < 1e-12)
        }
    }

    @Test("Hand-computed values from validation playground (tension=0)")
    func handComputed() throws {
        let interp = try CatmullRomInterpolator(xs: Self.xs, ys: Self.ys)
        #expect(abs(interp(0.5) - 0.375) < 1e-12)
        #expect(abs(interp(1.5) - 2.25) < 1e-12)
        #expect(abs(interp(2.5) - 6.25) < 1e-12)
        #expect(abs(interp(3.5) - 12.375) < 1e-12)
    }

    @Test("Default tension=0 reproduces linear data exactly")
    func linearInvariant() throws {
        let xs: [Double] = [0, 1, 2, 3, 4, 5]
        let ys: [Double] = xs.map { 3.0 * $0 + 7.0 }
        let interp = try CatmullRomInterpolator(xs: xs, ys: ys)
        for q in [0.0, 0.7, 1.5, 2.3, 3.9, 4.4, 5.0] {
            #expect(abs(interp(q) - (3.0 * q + 7.0)) < 1e-12)
        }
    }

    @Test("Tension=0.5 does NOT reproduce linear data exactly (documented)")
    func tightenedSplineDoesNotReproduceLinear() throws {
        let xs: [Double] = [0, 1, 2, 3, 4, 5]
        let ys: [Double] = xs.map { 3.0 * $0 + 7.0 }
        let interp = try CatmullRomInterpolator(xs: xs, ys: ys, tension: 0.5)
        // Documented behavior: tension > 0 produces a tighter spline that
        // is NOT exact on linear data. Probe at non-symmetric points within
        // each interval — at exact midpoints the wrong-slope contribution
        // cancels by symmetry and gives the right answer by accident, so
        // testing at midpoints would not catch the bug.
        var maxErr = 0.0
        for q in [0.7, 1.3, 2.3, 3.7, 4.3] {
            maxErr = max(maxErr, abs(interp(q) - (3.0 * q + 7.0)))
        }
        #expect(maxErr > 0.01)  // significantly off
    }

    @Test("Throws when tension is out of [0, 1]")
    func throwsOnInvalidTension() {
        #expect(throws: InterpolationError.self) {
            _ = try CatmullRomInterpolator(xs: [0.0, 1.0, 2.0], ys: [0.0, 1.0, 2.0], tension: -0.1)
        }
        #expect(throws: InterpolationError.self) {
            _ = try CatmullRomInterpolator(xs: [0.0, 1.0, 2.0], ys: [0.0, 1.0, 2.0], tension: 1.1)
        }
    }

    @Test("Vector1D query equivalence")
    func vector1DQuery() throws {
        let interp = try CatmullRomInterpolator(xs: Self.xs, ys: Self.ys)
        #expect(interp(at: Vector1D(2.5)) == interp(2.5))
    }
}

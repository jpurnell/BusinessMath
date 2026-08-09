//
//  InverseNormalCDFTests.swift
//  BusinessMath
//
//  Accuracy and property tests for the canonical inverse normal CDF.
//

import Foundation
import Testing
import Numerics

@testable import BusinessMath

/// Tests for `inverseNormalCDF(p:mean:stdDev:)`.
///
/// ## Where the tolerances come from
///
/// Every tolerance below is derived from a measured error sweep against an
/// erfc-based Halley reference (see the doc comment on `inverseNormalCDF`).
/// The measured worst-case absolute error of the shipped implementation is
/// **1.8e-15** (2 ulp) over `1e-12 <= p <= 1 - 1e-12`, and **1.1e-14** down the
/// lower tail as far as `p = 1e-225`.
///
/// - Assertions against textbook quantiles use `1e-9`, because the *published
///   constants themselves* are only quoted to 9–10 significant digits. That is
///   the limit of the reference, not of the implementation.
/// - Assertions against full-precision (17-digit) reference values use `1e-12`,
///   roughly three orders of margin over the measured 1.8e-15. The margin
///   absorbs cross-platform `erfc`/`exp` ulp differences (Darwin vs Linux libm),
///   which propagate to `z` as `ulp(p) / pdf(z)` — under 1e-16 everywhere tested.
/// - The previous bisection body measured 2.5e-5 to 7.0e-5 error (its bracket
///   tolerance was expressed in `z`, not in probability), so it fails every
///   assertion here by 7+ orders of magnitude.
@Suite("Inverse Normal CDF")
struct InverseNormalCDFTests {

    // MARK: - Known quantiles (the values quoted in the brief)

    @Test("Textbook quantiles to published precision")
    func textbookQuantiles() {
        // Published to 9–10 significant digits; tolerance set by the constants.
        #expect(abs(inverseNormalCDF(p: 0.975) - 1.959963985) < 1e-9)
        #expect(abs(inverseNormalCDF(p: 0.99) - 2.326347874) < 1e-9)
        #expect(abs(inverseNormalCDF(p: 0.999) - 3.090232306) < 1e-9)
        #expect(inverseNormalCDF(p: 0.5) == 0.0)
    }

    @Test("Full-precision reference quantiles")
    func fullPrecisionQuantiles() {
        // 17-digit values from an erfc-based Halley reference.
        let cases: [(p: Double, z: Double)] = [
            (0.4, -0.25334710313579978),
            (0.6, 0.25334710313579978),
            (0.05, -1.6448536269514726),
            (0.95, 1.6448536269514722),
            (0.975, 1.959963984540054),
            (0.99, 2.3263478740408408),
            (0.995, 2.5758293035489004),
            (0.999, 3.0902323061678136),
            (0.9999, 3.7190164854557088),
            (0.999999, 4.7534243088170882),
            (0.001, -3.0902323061678136),
            (0.0001, -3.7190164854556809),
            (1e-6, -4.7534243088228996),
            (0.25, -0.67448975019608171),
            (0.75, 0.67448975019608171),
            (0.1, -1.2815515655446004),
            (0.9, 1.2815515655446006),
        ]
        for c in cases {
            let got = inverseNormalCDF(p: c.p)
            #expect(abs(got - c.z) < 1e-12,
                    "p=\(c.p): got \(got), want \(c.z), err \(abs(got - c.z))")
        }
    }

    @Test("Deep tail quantiles")
    func deepTailQuantiles() {
        // The old bisection bracket was [-10, 10] with a 1e-4 stopping width,
        // so it degraded steadily here and broke down entirely past ~1e-16.
        let cases: [(p: Double, z: Double)] = [
            (1e-8, -5.6120012441747891),
            (1e-10, -6.3613409024040566),
            (1e-12, -7.034483825301133),
        ]
        for c in cases {
            let got = inverseNormalCDF(p: c.p)
            #expect(abs(got - c.z) < 1e-12,
                    "p=\(c.p): got \(got), want \(c.z), err \(abs(got - c.z))")
        }
    }

    // MARK: - Symmetry

    @Test("Symmetry is exact: z(p) == -z(1-p)")
    func exactSymmetry() {
        // For p in [0.5, 1] the subtraction (1 - p) is exact in binary floating
        // point (Sterbenz), and the implementation mirrors through it, so this
        // holds bit-for-bit rather than merely to a tolerance.
        for i in 1...2000 {
            let p = 0.5 + 0.5 * Double(i) / 2001.0
            let q = 1.0 - p
            #expect(inverseNormalCDF(p: p) == -inverseNormalCDF(p: q),
                    "asymmetric at p=\(p)")
        }
        for p in [0.9, 0.99, 0.999, 0.9999, 0.999999, 0.5] {
            #expect(inverseNormalCDF(p: p) == -inverseNormalCDF(p: 1.0 - p))
        }
    }

    // MARK: - Round trip

    /// An `erfc`-based normal CDF, accurate in the lower tail.
    ///
    /// The library's `normalCDF(x:)` computes `(1 + erf(x / sqrt(2))) / 2`, which
    /// cancels catastrophically as `erf` approaches `-1`. Fed the *exact* quantile
    /// it still returns a relative error of 2.2e-5 at `p = 1e-12`, 8.3e-8 at
    /// `1e-10` and 5.3e-10 at `1e-8`. That is a property of the forward function,
    /// not of the inverse, so round-trip assertions in the tail are made against
    /// this form instead — otherwise the test measures `normalCDF`, not the code
    /// under test. The complement form has a measured error of ~1e-15 throughout.
    private func accurateLowerCDF(_ x: Double) -> Double {
        return 0.5 * erfc(-x / 2.0.squareRoot())
    }

    @Test("Round trip against an accurate CDF, tails included")
    func roundTripAccurate() {
        let ps: [Double] = [1e-12, 1e-10, 1e-8, 1e-6, 1e-4, 1e-3, 0.01, 0.05,
                            0.1, 0.25, 0.4, 0.49]
        for p in ps {
            let z = inverseNormalCDF(p: p)
            let back = accurateLowerCDF(z)
            #expect(abs(back - p) / p < 1e-13,
                    "p=\(p): round-tripped to \(back), rel err \(abs(back - p) / p)")
        }
        // Upper half by exact mirroring, which the symmetry test pins separately.
        for p in ps {
            let upper = 1.0 - p
            let z = inverseNormalCDF(p: upper)
            let back = 1.0 - accurateLowerCDF(-z)
            #expect(abs(back - upper) < 1e-15,
                    "p=\(upper): round-tripped to \(back)")
        }
    }

    @Test("Round trip through the library CDF where the library CDF is sound")
    func roundTripLibraryCDF() {
        // Restricted to `p >= 1e-4`: below that the assertion would be measuring
        // the cancellation in `normalCDF(x:)` described above, not this function.
        let ps: [Double] = [1e-4, 1e-3, 0.01, 0.05, 0.1, 0.25, 0.4, 0.5, 0.6,
                            0.75, 0.9, 0.95, 0.99, 0.999, 0.9999, 1.0 - 1e-6]
        for p in ps {
            let z = inverseNormalCDF(p: p)
            let back = normalCDF(x: z)
            #expect(abs(back - p) / p < 1e-12,
                    "p=\(p): round-tripped to \(back), rel err \(abs(back - p) / p)")
        }
    }

    @Test("Round trip across a dense grid")
    func roundTripDense() {
        for i in 1..<1000 {
            let p = Double(i) / 1000.0
            let back = normalCDF(x: inverseNormalCDF(p: p))
            #expect(abs(back - p) < 1e-12, "p=\(p) round-tripped to \(back)")
        }
    }

    @Test("Reverse round trip: inverseNormalCDF(CDF(z)) == z")
    func reverseRoundTrip() {
        // Run over the lower half only, and with the accurate CDF. Recovering a
        // large *positive* z is limited by the representation of p itself: at
        // z = 6 the probability is 0.999999999, whose complement survives to only
        // about 9 significant digits in a Double, so no algorithm can return
        // better than ~1e-8 there. The upper half is covered exactly by the
        // symmetry test instead.
        for i in -600...0 {
            let z = Double(i) / 100.0
            let p = accurateLowerCDF(z)
            guard p > 0, p < 0.5 else { continue }
            let back = inverseNormalCDF(p: p)
            #expect(abs(back - z) < 1e-12, "z=\(z) round-tripped to \(back)")
        }
    }

    // MARK: - Affine transform

    @Test("mean and stdDev scale affinely")
    func affineScaling() {
        for p in [0.01, 0.05, 0.25, 0.5, 0.75, 0.95, 0.99, 1e-6, 1.0 - 1e-6] {
            let z = inverseNormalCDF(p: p)
            for (mean, sd) in [(0.0, 1.0), (5.0, 2.0), (-3.0, 0.5),
                               (100.0, 15.0), (0.0, 1e-6), (1e6, 1e3)] {
                let got = inverseNormalCDF(p: p, mean: mean, stdDev: sd)
                let want = mean + sd * z
                let scale = max(1.0, abs(want))
                #expect(abs(got - want) / scale < 1e-14,
                        "p=\(p) mean=\(mean) sd=\(sd): got \(got), want \(want)")
            }
        }
    }

    @Test("Affine transform matches the distribution it describes")
    func affineMatchesDistribution() {
        // A quantile of N(mean, sd) must round-trip through the CDF of N(mean, sd).
        for p in [0.025, 0.1, 0.5, 0.9, 0.975] {
            let x = inverseNormalCDF(p: p, mean: 12.0, stdDev: 3.0)
            let back = normalCDF(x: x, mean: 12.0, stdDev: 3.0)
            #expect(abs(back - p) < 1e-12, "p=\(p) -> x=\(x) -> \(back)")
        }
    }

    // MARK: - Domain edges

    @Test("Domain edges are total, not trapping")
    func domainEdges() {
        #expect(inverseNormalCDF(p: 0.0) == -Double.infinity)
        #expect(inverseNormalCDF(p: 1.0) == Double.infinity)
        #expect(inverseNormalCDF(p: -0.5) == -Double.infinity)
        #expect(inverseNormalCDF(p: 1.5) == Double.infinity)
        #expect(inverseNormalCDF(p: -0.0) == -Double.infinity)
        #expect(inverseNormalCDF(p: Double.nan).isNaN)
    }

    @Test("Domain edges carry the affine transform")
    func domainEdgesAffine() {
        #expect(inverseNormalCDF(p: 0.0, mean: 5.0, stdDev: 2.0) == -Double.infinity)
        #expect(inverseNormalCDF(p: 1.0, mean: 5.0, stdDev: 2.0) == Double.infinity)
    }

    @Test("Smallest and largest representable probabilities stay finite")
    func extremeRepresentableProbabilities() {
        let low = inverseNormalCDF(p: Double.leastNonzeroMagnitude)
        #expect(low.isFinite)
        #expect(low < -37.0 && low > -39.0)

        let high = inverseNormalCDF(p: 1.0.nextDown)
        #expect(high.isFinite)
        #expect(high > 8.0 && high < 9.0)
    }

    // MARK: - Shape properties

    @Test("Monotone increasing with no discontinuity")
    func monotoneAndContinuous() {
        // This is the defect class that took out the third implementation: it
        // jumped from 0.30 to 1.372 at u = 0.6, leaving an interval of outputs
        // unreachable.
        //
        // A fixed step bound would be meaningless here, because the true slope
        // dz/dp = 1 / pdf(z) genuinely diverges in the tails. The bound used is
        // the mean value theorem instead: for adjacent grid points,
        //
        //     z(p2) - z(p1) = (p2 - p1) / pdf(zeta),  zeta between z1 and z2
        //
        // and pdf is smallest at whichever endpoint is further from zero, so
        //
        //     step <= h / min(pdf(z1), pdf(z2))
        //
        // holds exactly for the true quantile function at every scale. Any jump
        // discontinuity violates it by orders of magnitude, while legitimate
        // tail steepening does not.
        let steps = 200_000
        let h = 1.0 / Double(steps + 1)

        func pdf(_ z: Double) -> Double {
            exp(-z * z / 2.0) / (2.0 * Double.pi).squareRoot()
        }

        var previous = inverseNormalCDF(p: h)
        var worstRatio = 0.0
        var worstAt = 0.0
        for i in 2...steps {
            let p = Double(i) * h
            let z = inverseNormalCDF(p: p)
            #expect(z >= previous, "not monotone at p=\(p)")

            let bound = h / min(pdf(previous), pdf(z))
            let ratio = (z - previous) / bound
            if ratio > worstRatio { worstRatio = ratio; worstAt = p }
            previous = z
        }
        // 1.0 is the analytic bound; the small margin absorbs rounding in pdf.
        #expect(worstRatio < 1.05,
                "step exceeded the mean-value bound by \(worstRatio)x at p=\(worstAt)")
    }

    @Test("Continuous across the internal branch seam")
    func branchSeamContinuity() {
        // The rational seed switches branches at p = 0.02425. Probe either
        // side at 1-ulp spacing: the values must agree to full precision.
        for seam in [0.02425, 1.0 - 0.02425] {
            var below = seam
            var above = seam
            for _ in 0..<3 { below = below.nextDown; above = above.nextUp }
            let zb = inverseNormalCDF(p: below)
            let za = inverseNormalCDF(p: above)
            #expect(abs(za - zb) < 1e-13,
                    "seam discontinuity at \(seam): \(zb) vs \(za)")
        }
    }

    // MARK: - Generic over Real

    @Test("Works for Float as well as Double")
    func genericOverReal() {
        #expect(abs(inverseNormalCDF(p: Float(0.975)) - Float(1.959964)) < 1e-5)
        #expect(inverseNormalCDF(p: Float(0.5)) == Float(0))
        #expect(inverseNormalCDF(p: Float(0)) == -Float.infinity)
        #expect(inverseNormalCDF(p: Float(1)) == Float.infinity)
        // Must use the computed complement: 1 - Float(0.9) is 0.100000024, which
        // is not Float(0.1), so a literal pair would not be testing symmetry.
        let upper: Float = 0.9
        #expect(inverseNormalCDF(p: upper) == -inverseNormalCDF(p: 1 - upper))
    }

    // MARK: - Consistency with the wrapper

    @Test("normInv agrees with inverseNormalCDF")
    func normInvAgreement() {
        for p in [0.01, 0.1, 0.5, 0.9, 0.99] {
            #expect(normInv(probability: p, mean: 3.0, stdev: 1.5)
                    == inverseNormalCDF(p: p, mean: 3.0, stdDev: 1.5))
        }
    }
}

import Testing
import Numerics
import Foundation
@testable import BusinessMath

/// The chi-squared **density**, which this module did not have.
///
/// `chi2pdf(x:dF:)` was named for it and computed something else: its body summed the density
/// at 0.001, 0.002, … up to `x` and multiplied by the step, which is a Riemann sum of the
/// integral — the *cumulative* function. `chi2pdf(x: 10, dF: 3)` answered 0.98144, the CDF at
/// 10, where the density there is 0.0085; at `x = 100` it answered 0.9999974 against a true
/// density near 1e-21.
///
/// The same mistake had been found once before and fixed in the wrong direction: `chi2cdf` was
/// `1 - chi2pdf(x:dF:)`, and the repair deleted `chi2cdf` and wrote ``chiSquaredCDF(x:df:)``
/// while leaving `chi2pdf` exported and wrong. A module that holds a correct CDF and a
/// misnamed one is worse than one that holds neither, because the second looks like a
/// deliberate pair.
@Suite("Chi-squared PDF")
struct ChiSquaredPDFTests {

    /// Two degrees of freedom is exponential with mean 2, so the density has a closed form
    /// and these values are exact independently of any series.
    @Test("Closed form at two degrees of freedom")
    func testExponentialCase() throws {
        // f(x) = ½ e^(−x/2)
        for x in [0.5, 1.0, 2.0, 5.0, 20.0] {
            let expected = 0.5 * Double.exp(-x / 2)
            let actual: Double = try chiSquaredPDF(x: x, df: 2)
            #expect(abs(actual - expected) < 1e-14, "at x = \(x)")
        }
    }

    /// One degree of freedom: `f(x) = e^(−x/2) / √(2πx)`.
    @Test("Closed form at one degree of freedom")
    func testOneDegreeOfFreedom() throws {
        for x in [0.5, 1.0, 3.0] {
            let expected = Double.exp(-x / 2) / (2 * Double.pi * x).squareRoot()
            let actual: Double = try chiSquaredPDF(x: x, df: 1)
            #expect(abs(actual - expected) < 1e-14, "at x = \(x)")
        }
    }

    /// The value the old implementation got wrong, stated as a regression.
    @Test("The values chi2pdf answered wrongly")
    func testTheOldAnswers() throws {
        let atHalf: Double = try chiSquaredPDF(x: 0.5, df: 1)
        #expect(abs(atHalf - 0.4393912894677224) < 1e-12,
                "chi2pdf answered 0.5022974900306464 — the CDF's neighbourhood, not the density")

        let atTen: Double = try chiSquaredPDF(x: 10, df: 3)
        #expect(abs(atTen - 0.0085003666025203) < 1e-12,
                "chi2pdf answered 0.98144, which is the CDF at 10")

        // Where a CDF saturates, a density vanishes. This is the clearest separation of the
        // two and the old function had it exactly backwards.
        let atHundred: Double = try chiSquaredPDF(x: 100, df: 3)
        #expect(atHundred < 1e-20, "chi2pdf answered 0.9999974")
    }

    /// **A density integrates to one.** The property no amount of matching single points
    /// establishes, and the one the old implementation could never have satisfied.
    /// **One degree of freedom is excluded, and not because it fails.** Its density is
    /// unbounded at zero — integrably so — and Simpson's rule at uniform steps cannot resolve
    /// that: the first interval carries a value near 12,600 and the rule treats it as
    /// representative. That is a limitation of this quadrature, not of the density, and df = 1
    /// is covered exactly by the closed-form test above and by the derivative test below.
    @Test("It integrates to one", arguments: [2, 3, 5, 10])
    func testItIntegratesToOne(df: Int) throws {
        // Simpson's rule over a range that carries essentially all the mass.
        let lower = 1e-9, upper = Double(df) + 12 * (2 * Double(df)).squareRoot() + 40
        let steps = 200_000
        let h = (upper - lower) / Double(steps)

        var total: Double = try chiSquaredPDF(x: lower, df: df)
            + (try chiSquaredPDF(x: upper, df: df))
        for step in 1..<steps {
            let x = lower + Double(step) * h
            let value: Double = try chiSquaredPDF(x: x, df: df)
            total += value * (step % 2 == 0 ? 2 : 4)
        }
        let integral = total * h / 3
        #expect(abs(integral - 1) < 1e-4, "df = \(df) integrated to \(integral)")
    }

    /// The density is the CDF's derivative, checked against the CDF this module already has.
    @Test("It is the derivative of the CDF", arguments: [1, 3, 7])
    func testItMatchesTheCDFsSlope(df: Int) throws {
        let x = 4.0, h = 1e-5
        let above: Double = try chiSquaredCDF(x: x + h, df: df)
        let below: Double = try chiSquaredCDF(x: x - h, df: df)
        let slope = (above - below) / (2 * h)
        let density: Double = try chiSquaredPDF(x: x, df: df)
        #expect(abs(slope - density) < 1e-7, "df = \(df): slope \(slope), density \(density)")
    }

    /// At zero the density depends on the degrees of freedom, and the three cases differ.
    @Test("At zero")
    func testAtZero() throws {
        // Unbounded below two — the limit does not exist, and saying so beats returning a
        // number somebody would plot.
        #expect(throws: BusinessMathError.self) {
            let _: Double = try chiSquaredPDF(x: 0, df: 1)
        }
        // Exactly ½ at two, from the exponential form.
        let atTwo: Double = try chiSquaredPDF(x: 0, df: 2)
        #expect(abs(atTwo - 0.5) < 1e-15)
        // Zero above two.
        // `isEqual(to:)` rather than `==`: exactly zero is the claim, and naming it says so
        // reads as a decision rather than a comparison nobody thought about.
        let atFive: Double = try chiSquaredPDF(x: 0, df: 5)
        #expect(atFive.isEqual(to: 0))
    }

    /// Large degrees of freedom, where the direct expression overflows and log-space does not.
    ///
    /// At df = 400 the numerator carries `2^200 · Γ(200)`, which no `Double` holds, while the
    /// answer is an ordinary number near 0.02.
    @Test("Large degrees of freedom")
    func testLargeDegreesOfFreedom() throws {
        let atMode: Double = try chiSquaredPDF(x: 398, df: 400)
        #expect(atMode.isFinite)
        #expect(atMode > 0.01 && atMode < 0.03, "got \(atMode)")
    }

    /// Invalid input is refused rather than answered.
    @Test("Refusals")
    func testRefusals() throws {
        #expect(throws: BusinessMathError.self) {
            let _: Double = try chiSquaredPDF(x: -1, df: 3)
        }
        #expect(throws: BusinessMathError.self) {
            let _: Double = try chiSquaredPDF(x: 1, df: 0)
        }
    }
}

/// `DistributionChiSquared.pdf(_:)` — the same density, reached through the distribution type.
///
/// `ContinuousDistribution` requires `cdf` and `quantile` and **not** a density, which is a
/// gap in the protocol rather than in this type: a continuous distribution has a density by
/// definition. Of the 51 conformers, two defined one before this. Adding the requirement
/// would break the other 49, so it is recorded rather than imposed — see the handoff.
@Suite("Chi-squared distribution density")
struct DistributionChiSquaredPDFTests {

    @Test("It agrees with the free function")
    func testItAgreesWithTheFreeFunction() throws {
        let distribution = DistributionChiSquared(degreesOfFreedom: 5)
        for x in [0.5, 2.0, 5.0, 12.0] {
            let expected: Double = try chiSquaredPDF(x: x, df: 5)
            #expect(abs(distribution.pdf(x) - expected) < 1e-15, "at x = \(x)")
        }
    }

    /// It is the slope of the `cdf` the same type provides, which is what makes them a pair.
    @Test("It is the derivative of this type's own CDF")
    func testItIsTheDerivativeOfItsOwnCDF() throws {
        let distribution = DistributionChiSquared(degreesOfFreedom: 4)
        let x = 3.0, h = 1e-5
        let slope = (distribution.cdf(x + h) - distribution.cdf(x - h)) / (2 * h)
        #expect(abs(slope - distribution.pdf(x)) < 1e-7)
    }

    /// Fractional degrees of freedom work, where the free function takes an `Int`.
    ///
    /// The type carries a `Double` because a Satterthwaite correction produces one, and the
    /// density is defined for any positive real.
    @Test("Fractional degrees of freedom")
    func testFractionalDegreesOfFreedom() throws {
        guard let distribution = DistributionChiSquared(degreesOfFreedom: 2.5) else {
            Issue.record("expected a distribution")
            return
        }
        let density = distribution.pdf(2.0)
        #expect(density.isFinite && density > 0)

        // Between its integer neighbours — and at x = 2 the density *rises* with the degrees
        // of freedom, which is the opposite of the ordering one might assume and is why this
        // is checked rather than reasoned about.
        let atTwo: Double = try chiSquaredPDF(x: 2.0, df: 2)
        let atThree: Double = try chiSquaredPDF(x: 2.0, df: 3)
        #expect(atTwo < density && density < atThree,
                "\(atTwo) < \(density) < \(atThree)")
    }

    /// Outside the support, and at the three faces of zero.
    @Test("Edges")
    func testEdges() throws {
        let wide = DistributionChiSquared(degreesOfFreedom: 5)
        let two = DistributionChiSquared(degreesOfFreedom: 2)
        let one = DistributionChiSquared(degreesOfFreedom: 1)
        // Exact values, deliberately: outside the support the density *is* zero, and at two
        // degrees of freedom it is exactly a half. `isEqual(to:)` names that.
        #expect(wide.pdf(-1).isEqual(to: 0))
        #expect(wide.pdf(0).isEqual(to: 0))
        #expect(two.pdf(0).isEqual(to: 0.5))
        #expect(one.pdf(0).isInfinite, "unbounded below two degrees of freedom")
        #expect(wide.pdf(.infinity).isEqual(to: 0))
    }
}

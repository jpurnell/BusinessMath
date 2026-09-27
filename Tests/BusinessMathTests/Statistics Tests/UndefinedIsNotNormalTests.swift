//
//  UndefinedIsNotNormalTests.swift
//  BusinessMathTests
//
//  Found by the adversarial-input sweep: feed every public statistic a NaN-contaminated
//  sample and see which ones still answer confidently.
//
//  Twelve of fourteen propagated the NaN. Two did not:
//
//      kurtosis  clean=-1.200  contaminated=0
//      kurtosisP clean=-1.224  contaminated=0
//
//  The cause is one guard, and it is the intersection of two separate hazards:
//
//      guard s > T(0) else { return T(0) }
//
//  `s` is the standard deviation, which is `nan` for a contaminated sample — and **every
//  comparison against a NaN is false**, so `nan > 0` fails and the guard fires. It was
//  written for the zero-dispersion case and catches contamination through the same door.
//
//  The value it returns then matters: excess kurtosis of `0` means *exactly normal-tailed*.
//  So a sample nobody can compute a moment from was reported as textbook Gaussian.
//
//  The same `0` was returned for the two other undefined cases — a constant series, and a
//  sample too small for the bias correction's `(n-2)(n-3)` denominator. Excel's `KURT`, which
//  this library tracks for parity, answers `#DIV/0!` to both. `nan` is the closer answer as
//  well as the honest one, and it is what `median` and `geometricMean` already return when
//  they have nothing to compute.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Kurtosis reports undefined rather than normal-tailed")
struct UndefinedIsNotNormalTests {

    private let clean: [Double] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

    /// The headline: a `> 0` guard is also a NaN trap.
    @Test("Kurtosis_ContaminatedSample_IsUndefined")
    func kurtosisContaminatedSampleIsUndefined() {
        let dirty: [Double] = [1, 2, 3, 4, .nan, 6, 7, 8, 9, 10]
        #expect(kurtosisS(dirty).isNaN, "sample kurtosis returned \(kurtosisS(dirty))")
        #expect(kurtosisP(dirty).isNaN, "population kurtosis returned \(kurtosisP(dirty))")
    }

    /// A constant series has no dispersion, so the fourth standardised moment is 0/0.
    /// Reporting `0` claimed it was normal-tailed; a flat line has no tails at all.
    @Test("Kurtosis_ConstantSeries_IsUndefined")
    func kurtosisConstantSeriesIsUndefined() {
        let constant: [Double] = [5, 5, 5, 5, 5, 5]
        #expect(kurtosisS(constant).isNaN)
        #expect(kurtosisP(constant).isNaN)
    }

    /// The sample bias correction divides by `(n - 2)(n - 3)`, so it needs four observations.
    @Test("Kurtosis_TooFewObservations_IsUndefined")
    func kurtosisTooFewObservationsIsUndefined() {
        #expect(kurtosisS([1.0, 2.0, 3.0]).isNaN, "three observations cannot support KURT")
        #expect(kurtosisS([Double]()).isNaN)
    }

    /// `Risk.Kurtosis` delegates to `kurtosisP`, so it inherits the contract.
    @Test("RiskKurtosis_InheritsTheContract")
    func riskKurtosisInheritsTheContract() {
        let dirty: [Double] = [1, 2, 3, 4, .nan, 6, 7, 8, 9, 10]
        #expect(Kurtosis.calculate(values: dirty).isNaN)
    }

    /// Control: ordinary samples are untouched, at the values measured before the change.
    @Test("Kurtosis_CleanSample_Unchanged")
    func kurtosisCleanSampleUnchanged() {
        #expect(abs(kurtosisS(clean) - -1.2000000000000002) < 1e-12, "got \(kurtosisS(clean))")
        #expect(abs(kurtosisP(clean) - -1.2242424242424244) < 1e-12, "got \(kurtosisP(clean))")
    }
}

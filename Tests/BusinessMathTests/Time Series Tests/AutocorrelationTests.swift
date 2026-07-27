//
//  AutocorrelationTests.swift
//  BusinessMath
//
//  RED phase — Step 3 of the Forecast Evaluation & Diagnostics tier.
//  Sample ACF, PACF (Durbin–Levinson), and ACF-based dominant season detection.
//
//  Reference truth: exact hand-computed sample ACF (matches statsmodels
//  `acf(..., adjusted=False)` where the 1/n normalization cancels in ρ(h)=γ(h)/γ(0)).
//

import Testing
import Numerics
@testable import BusinessMath

@Suite("Autocorrelation & season detection")
struct AutocorrelationTests {

    private func monthly(_ values: [Double]) -> TimeSeries<Double> {
        let periods = (0..<values.count).map { Period.month(year: 2025, month: 1 + $0) }
        return TimeSeries(periods: periods, values: values)
    }

    // MARK: - ACF (exact, hand-computed)

    @Test("Sample ACF matches hand-computed values for [1,2,3,4]")
    func acfExact() {
        // mean 2.5; γ(0)∝5.0; ρ1=0.25, ρ2=-0.3, ρ3=-0.45
        let acf = monthly([1, 2, 3, 4]).autocorrelation(maxLag: 3)
        #expect(acf.count == 3)
        #expect(abs(acf[0] - 0.25) < 1e-12)
        #expect(abs(acf[1] - (-0.30)) < 1e-12)
        #expect(abs(acf[2] - (-0.45)) < 1e-12)
    }

    @Test("ACF of a constant series is zero (no covariance)")
    func acfConstant() {
        // Guarded division: γ(0)=0 must not produce NaN; define ρ(h)=0.
        let acf = monthly([5, 5, 5, 5, 5]).autocorrelation(maxLag: 2)
        #expect(acf == [0, 0])
    }

    @Test("ACF clamps maxLag to n-1 and empty series yields []")
    func acfEdges() {
        #expect(monthly([1, 2, 3]).autocorrelation(maxLag: 99).count == 2)  // n-1 = 2
        #expect(TimeSeries<Double>(periods: [], values: []).autocorrelation(maxLag: 5).isEmpty)
    }

    // MARK: - PACF

    @Test("PACF at lag 1 equals ACF at lag 1 (definitional)")
    func pacfLag1() {
        let series = monthly([1, 2, 3, 4])
        let pacf = series.partialAutocorrelation(maxLag: 3)
        let acf = series.autocorrelation(maxLag: 3)
        #expect(pacf.count == 3)
        #expect(abs(pacf[0] - acf[0]) < 1e-12)
    }

    // MARK: - Dominant season detection (R4)

    @Test("Dominant season length finds the injected period (m=4)")
    func dominantSeason() {
        let series = monthly([1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4])
        #expect(series.dominantSeasonLength(maxLag: 6) == 4)
    }

    @Test("No detectable season returns nil (flat series)")
    func noSeason() {
        #expect(monthly([3, 3, 3, 3, 3, 3]).dominantSeasonLength(maxLag: 3) == nil)
    }
}

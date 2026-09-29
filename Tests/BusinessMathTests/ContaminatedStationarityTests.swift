//
//  ContaminatedStationarityTests.swift
//  BusinessMathTests
//
//  From the fanned-out triage of `Sources/BusinessMath/Time Series/Diagnostics/`.
//
//  Five functions live in that directory and all five answered a contaminated series with
//  confidence. They did it in two different ways, and the second one is the one worth
//  writing down.
//
//  `augmentedDickeyFuller` and `kpss` return `isStationary: Bool` alongside a prose
//  `recommendation` — "non-stationary — difference (d=1) before fitting a trend model". A
//  `Bool` has no `nan`, so there is no value the verdict can take that hedges, and the
//  recommendation is an instruction the caller acts on. Neither could survive a NaN, and
//  neither did: without a guard the caller got a *wrong diagnosis* instead — `noVariance`,
//  "y has no variance (all values approximately equal)", about a differenced series that
//  varies perfectly well, because `nan > 1e-15` is false inside the regression's
//  zero-variance check. The reader is sent hunting for a constant column that is not there.
//
//  `autocorrelation` is the more dangerous one, because it does not throw at all. Its
//  zero-variance guard —
//
//      guard gamma0 > T.zero else { return Array(repeating: T.zero, count: lags) }
//
//  — is correct for the case it was written about, and `nan > 0` is false too, so
//  contamination left by the same door wearing that justification. An all-zero ACF is not a
//  neutral answer: it is the exact reading of white noise at every lag. Both callers in the
//  directory inherited it. `ljungBox` squared those zeros into `Q = 0`, `p = 1.0` — the
//  strongest available "these residuals are indistinguishable from white noise, your model
//  left nothing on the table", which is the single most reassuring thing that test can say
//  and is precisely what a caller polls it for. `dominantSeasonLength` found no lag above
//  its band and reported no seasonality.
//
//  Every contaminated assertion below is paired with a clean control: a genuinely stationary
//  series and a genuinely non-stationary one, both still classified correctly, and a
//  genuinely constant series still receiving its documented all-zero ACF. Those controls are
//  what prove the guards discriminate rather than refusing everything.
//

import Testing
import Foundation
@testable import BusinessMath

private func agree(_ lhs: [Double], _ rhs: [Double]) -> Bool {
    lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.isEqual(to: $1) }
}

@Suite("Time-series diagnostics on a contaminated series")
struct ContaminatedStationarityTests {

    private func series(_ values: [Double]) -> TimeSeries<Double> {
        TimeSeries(periods: (0..<values.count).map { Period.year(2000 + $0) }, values: values)
    }

    /// Bounded and mean-reverting — genuinely stationary. Same fixture as `StationarityTests`,
    /// where ADF and KPSS are already pinned green on it.
    private func stationaryValues(n: Int) -> [Double] {
        (0..<n).map { 10.0 * sin(2.0 * .pi * Double($0) / 12.0) }
    }

    /// Integrated centred-chaotic increments — a deterministic random-walk stand-in, genuinely
    /// non-stationary. Same fixture as `StationarityTests`.
    private func nonStationaryValues(n: Int) -> [Double] {
        var x = 0.4
        var acc = 0.0
        var out: [Double] = []
        for _ in 0..<n {
            x = 3.99 * x * (1.0 - x)
            acc += (x - 0.5)
            out.append(acc)
        }
        return out
    }

    /// The stationary fixture with one observation replaced.
    private func poisoned(at index: Int, with bad: Double = .nan) -> TimeSeries<Double> {
        var values = stationaryValues(n: 60)
        values[index] = bad
        return series(values)
    }

    // MARK: - Controls: the verdicts that must survive

    @Test("Control_CleanStationarySeries_StillClassifiedStationary")
    func controlCleanStationarySeriesStillClassifiedStationary() throws {
        let clean = series(stationaryValues(n: 60))
        let adf = try clean.augmentedDickeyFuller(lag: 1)
        let kpssResult = try clean.kpss(regression: .level)
        #expect(adf.isStationary, "ADF stopped rejecting the unit root on a clean, mean-reverting series")
        #expect(kpssResult.isStationary, "KPSS stopped accepting stationarity on a clean, mean-reverting series")
    }

    @Test("Control_CleanRandomWalk_StillClassifiedNonStationary")
    func controlCleanRandomWalkStillClassifiedNonStationary() throws {
        let clean = series(nonStationaryValues(n: 60))
        let adf = try clean.augmentedDickeyFuller(lag: 1)
        let kpssResult = try clean.kpss(regression: .level)
        #expect(!adf.isStationary, "ADF started rejecting the unit root on a clean random walk")
        #expect(!kpssResult.isStationary, "KPSS started accepting stationarity on a clean random walk")
        let advice = adf.recommendation.lowercased()
        #expect(advice.contains("difference"), "the recommendation for a random walk stopped saying to difference it")
    }

    // MARK: - ADF and KPSS decline rather than pronounce

    /// Position matters: a single placement can look fine, so all three are pinned.
    @Test("ADF_ContaminatedSeries_DeclinesAtEveryPosition", arguments: [0, 30, 59] as [Int])
    func adfContaminatedSeriesDeclinesAtEveryPosition(index: Int) {
        let contaminated = poisoned(at: index)
        #expect(throws: BusinessMathError.self) {
            _ = try contaminated.augmentedDickeyFuller(lag: 1)
        }
    }

    @Test("KPSS_ContaminatedSeries_DeclinesAtEveryPosition", arguments: [0, 30, 59] as [Int])
    func kpssContaminatedSeriesDeclinesAtEveryPosition(index: Int) {
        let contaminated = poisoned(at: index)
        #expect(throws: BusinessMathError.self) {
            _ = try contaminated.kpss(regression: .level)
        }
    }

    /// The trend component reached the same failure by a different route and blamed a
    /// different thing; it must now decline for the same stated reason as `.level`.
    @Test("KPSS_ContaminatedSeriesTrendRegression_DeclinesToo")
    func kpssContaminatedSeriesTrendRegressionDeclinesToo() {
        let contaminated = poisoned(at: 30)
        #expect(throws: BusinessMathError.self) {
            _ = try contaminated.kpss(regression: .trend)
        }
    }

    /// An infinity is screened alongside the NaN because the first difference of an infinite
    /// observation is `inf - inf`, which is a NaN — the series is unusable either way.
    @Test("ADF_InfiniteObservation_DeclinesToo")
    func adfInfiniteObservationDeclinesToo() {
        let contaminated = poisoned(at: 30, with: .infinity)
        #expect(throws: BusinessMathError.self) {
            _ = try contaminated.augmentedDickeyFuller(lag: 1)
        }
    }

    // MARK: - Autocorrelation

    /// Derived by hand, not recalled. For `[1, 2, 3, 4]`: `ȳ = 2.5`, so
    /// `dev = [-1.5, -0.5, 0.5, 1.5]` and `γ₀ = 2.25 + 0.25 + 0.25 + 2.25 = 5`. The lag-1
    /// cross-products are `(-1.5)(-0.5) + (-0.5)(0.5) + (0.5)(1.5) = 0.75 - 0.25 + 0.75 =
    /// 1.25`, so `ρ(1) = 1.25 / 5 = 0.25` exactly.
    @Test("Control_ACF_CleanSeries_MatchesTheHandDerivedCoefficient")
    func controlACFCleanSeriesMatchesTheHandDerivedCoefficient() {
        let acf = series([1.0, 2.0, 3.0, 4.0]).autocorrelation(maxLag: 1)
        #expect(agree(acf, [0.25]))
    }

    /// The zero-variance case the guard was written for. Its all-zero answer is documented
    /// and stays; this is the control that shows contamination was separated from it rather
    /// than the whole guard being removed.
    @Test("Control_ACF_ConstantSeries_KeepsItsDocumentedZeros")
    func controlACFConstantSeriesKeepsItsDocumentedZeros() {
        let acf = series([5.0, 5.0, 5.0, 5.0]).autocorrelation(maxLag: 3)
        #expect(agree(acf, [0.0, 0.0, 0.0]))
    }

    @Test("ACF_ContaminatedSeries_IsNotReportedAsWhiteNoise")
    func acfContaminatedSeriesIsNotReportedAsWhiteNoise() {
        let acf = series([1.0, 2.0, .nan, 4.0]).autocorrelation(maxLag: 3)
        #expect(acf.count == 3, "the length invariant callers index against was not preserved")
        let allUnusable = acf.allSatisfy { $0.isNaN }
        #expect(allUnusable, "an unevaluable series was given an autocorrelation, and zero reads as white noise")
    }

    /// PACF(1) == ACF(1) by construction, so the same hand-derived 0.25 is the oracle.
    @Test("Control_PACF_CleanSeries_EqualsTheLagOneACF")
    func controlPACFCleanSeriesEqualsTheLagOneACF() {
        let pacf = series([1.0, 2.0, 3.0, 4.0]).partialAutocorrelation(maxLag: 1)
        #expect(agree(pacf, [0.25]))
    }

    @Test("PACF_ContaminatedSeries_IsNotReportedAsWhiteNoise")
    func pacfContaminatedSeriesIsNotReportedAsWhiteNoise() {
        let pacf = series([1.0, 2.0, .nan, 4.0]).partialAutocorrelation(maxLag: 3)
        #expect(pacf.count == 3, "the length invariant callers index against was not preserved")
        let allUnusable = pacf.allSatisfy { $0.isNaN }
        #expect(allUnusable, "the Durbin–Levinson recursion produced coefficients from an unevaluable ACF")
    }

    // MARK: - Ljung–Box

    /// Derived from the same `[1, 2, 3, 4]` fixture: `ρ(1) = 0.25` (above), so
    /// `Q = n(n+2) · ρ(1)² / (n−1) = 4 · 6 · 0.0625 / 3 = 1.5 / 3 = 0.5`.
    ///
    /// The tolerance covers the one inexact step — `0.0625 / 3` is not representable — and is
    /// about two ulp at this magnitude, not a fitted number.
    @Test("Control_LjungBox_CleanSeries_MatchesTheHandDerivedStatistic")
    func controlLjungBoxCleanSeriesMatchesTheHandDerivedStatistic() throws {
        let result = try series([1.0, 2.0, 3.0, 4.0]).ljungBox(lags: 1)
        let deviation: Double = abs(result.statistic - 0.5)
        #expect(deviation < 1e-12)
        #expect(result.degreesOfFreedom == 1)
    }

    /// A strongly autocorrelated clean series must still be caught. This is the assertion the
    /// contaminated case was silently failing: the same test, on data it can evaluate, does
    /// reject white noise.
    @Test("Control_LjungBox_CleanSeasonalSeries_StillRejectsWhiteNoise")
    func controlLjungBoxCleanSeasonalSeriesStillRejectsWhiteNoise() throws {
        let result = try series(stationaryValues(n: 60)).ljungBox(lags: 12)
        #expect(result.rejectsWhiteNoise(alpha: 0.05),
                "a deterministic 12-period sine stopped registering as autocorrelated")
    }

    /// A large but finite outlier is not contamination, and the guard must not reach it —
    /// otherwise the fix is "refuse anything unusual" rather than "refuse the unevaluable".
    @Test("Control_LjungBox_LargeFiniteOutlier_IsStillEvaluated")
    func controlLjungBoxLargeFiniteOutlierIsStillEvaluated() throws {
        var values = stationaryValues(n: 60)
        values[30] = 1_000_000.0
        let result = try series(values).ljungBox(lags: 12)
        #expect(result.statistic.isFinite)
        #expect(result.lags == 12)
    }

    @Test("LjungBox_ContaminatedResiduals_AreNotCertifiedWhiteNoise", arguments: [0, 30, 59] as [Int])
    func ljungBoxContaminatedResidualsAreNotCertifiedWhiteNoise(index: Int) {
        let contaminated = poisoned(at: index)
        #expect(throws: BusinessMathError.self) {
            _ = try contaminated.ljungBox(lags: 12)
        }
    }

    // MARK: - The conflation that is documented rather than fixed

    /// `dominantSeasonLength` returns `Int?`, which has no room to distinguish "no season is
    /// detectable" from "this series cannot be evaluated". Contract §3.3 says document that
    /// and pin it rather than widen the signature. Both callers fall back to a non-seasonal
    /// length of 1 — the same fallback a genuinely aseasonal series gets — so neither is
    /// handed a wrong number, and the control below shows detection itself still works.
    @Test("DominantSeasonLength_ContaminatedSeries_AnswersNilAsDocumented")
    func dominantSeasonLengthContaminatedSeriesAnswersNilAsDocumented() {
        let contaminated = poisoned(at: 30)
        #expect(contaminated.dominantSeasonLength(maxLag: 24) == nil)
    }

    @Test("Control_DominantSeasonLength_CleanSeasonalSeries_FindsTheTwelvePeriodCycle")
    func controlDominantSeasonLengthCleanSeasonalSeriesFindsTheTwelvePeriodCycle() {
        let clean = series(stationaryValues(n: 60))
        #expect(clean.dominantSeasonLength(maxLag: 24) == 12)
    }
}

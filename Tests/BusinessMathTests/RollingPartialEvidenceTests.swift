//
//  RollingPartialEvidenceTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-09-28.
//

import Testing
import Foundation
@testable import BusinessMath

/// Elementwise floating-point identity, `nan`-aware.
///
/// `==` on `[Double]` is wrong twice over here: it answers `false` for two `nan`s that are
/// both the intended output, and it hides which position disagreed.
private func agree(_ lhs: [Double], _ rhs: [Double]) -> Bool {
    // `isEqual(to:)` is IEEE equality, so `nan.isEqual(to: .nan)` is **false**. This sweep
    // deliberately marks unevaluable positions with `.nan`, so two NaNs in the same slot
    // are an agreement, not a mismatch — without this a marked position can never match.
    lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.isEqual(to: $1) || ($0.isNaN && $1.isNaN) }
}

/// Partial-evidence behaviour for the rolling operators in `StreamingStatistics.swift`.
///
/// Two rules are pinned here.
///
/// **Partial evidence.** A statistic over a window in which some observations cannot be
/// evaluated is computed from the ones that can, rather than being diluted by the ones that
/// cannot or suppressed entirely. Only a window with *nothing* evaluable answers `nan`.
///
/// **Warm-up is not normal.** A statistic that is not yet computable because there is not
/// enough data answers `nan`, not a meaningful constant. Sample variance over one observation
/// is `0/0`; reporting `0` claimed the calmest reading on the scale.
@Suite("Rolling Partial Evidence")
struct RollingPartialEvidenceTests {

    // MARK: - rollingThresholdExceedanceRate: partial evidence

    @Test("Exceedance rate divides by the differences it could evaluate, not the window size")
    func exceedanceRateUsesEvaluableDenominator() async throws {
        // Observations:      [nan, 100, 200, 205, 210]
        // Successive diffs:  d0 = 100 - nan = nan   (not comparable)
        //                    d1 = 200 - 100 = 100   (|d| > 50 → exceeds)
        //                    d2 = 205 - 200 = 5     (does not exceed)
        //                    d3 = 210 - 205 = 5     (does not exceed)
        // window = 3, threshold = 50
        //   window 0 = [d0, d1, d2]: 1 exceedance out of 2 comparable → 1/2
        //   window 1 = [d1, d2, d3]: 1 exceedance out of 3 comparable → 1/3
        // Before the fix window 0 read 1/3: `nan > 50` is false, so d0 was filed as a
        // measured non-exceedance and divided into a denominator of 3.
        let values: [Double] = [.nan, 100.0, 200.0, 205.0, 210.0]
        let stream = AsyncValueStream(values)

        var results: [Double] = []
        for try await rate in stream.rollingThresholdExceedanceRate(window: 3, threshold: 50.0) {
            results.append(rate)
        }

        let expectedFirst: Double = 1.0 / 2.0
        let expectedSecond: Double = 1.0 / 3.0
        #expect(results.count == 2)
        let firstGap: Double = abs(results[0] - expectedFirst)
        let secondGap: Double = abs(results[1] - expectedSecond)
        #expect(firstGap < 1e-12, "window 0 must divide by the 2 comparable differences")
        #expect(secondGap < 1e-12, "window 1 is clean and must be unchanged")
    }

    @Test("Exceedance rate over a clean window is unchanged")
    func exceedanceRateCleanControl() async throws {
        // Observations:     [800, 860, 810, 870, 820]
        // Absolute diffs:   [60, 50, 60, 50] — strict `>` 50 → [true, false, true, false]
        // window = 4: 2 exceedances out of 4 comparable → 2/4
        let values: [Double] = [800.0, 860.0, 810.0, 870.0, 820.0]
        let stream = AsyncValueStream(values)

        var results: [Double] = []
        for try await rate in stream.rollingThresholdExceedanceRate(window: 4, threshold: 50.0) {
            results.append(rate)
        }

        let expected: Double = 2.0 / 4.0
        #expect(results.count == 1)
        let gap: Double = abs(results[0] - expected)
        #expect(gap < 1e-12, "a window with nothing unusable must be untouched by the fix")
    }

    @Test("Exceedance rate recovers as the unusable differences leave the window")
    func exceedanceRateRecoversMidStream() async throws {
        // Observations:      [100, 200, nan, 205, 210, 310]
        // Successive diffs:  d0 = 100  (exceeds)
        //                    d1 = 200 - nan   → nan (not comparable)
        //                    d2 = 205 - nan   → nan (not comparable)
        //                    d3 = 5    (does not exceed)
        //                    d4 = 100  (exceeds)
        // window = 3, threshold = 50
        //   window 0 = [d0, d1, d2]: 1 exceedance out of 1 comparable → 1/1
        //   window 1 = [d1, d2, d3]: 0 exceedances out of 1 comparable → 0/1
        //   window 2 = [d2, d3, d4]: 1 exceedance out of 2 comparable → 1/2
        // A single observation is thin evidence and window 0 says so by reporting the
        // fraction it actually measured. The alternative rules are worse: 1/3 invents two
        // non-exceedances, and `nan` for the whole window suppresses a real 100-unit jump.
        let values: [Double] = [100.0, 200.0, .nan, 205.0, 210.0, 310.0]
        let stream = AsyncValueStream(values)

        var results: [Double] = []
        for try await rate in stream.rollingThresholdExceedanceRate(window: 3, threshold: 50.0) {
            results.append(rate)
        }

        let expected: [Double] = [1.0, 0.0, 0.5]
        #expect(results.count == 3)
        let matches: Bool = agree(results, expected)
        #expect(matches, "partial evidence: 1/1, then 0/1, then 1/2")
    }

    @Test("Exceedance rate is nan when nothing in the window can be evaluated")
    func exceedanceRateNothingEvaluable() async throws {
        // Every successive difference is `nan - nan`, so no comparison against the threshold
        // is possible anywhere in the window. There is no fraction to report. `0.0` would say
        // "nothing exceeded the threshold" — the quiet end of the scale a monitor watches.
        let values: [Double] = [.nan, .nan, .nan, .nan]
        let stream = AsyncValueStream(values)

        var results: [Double] = []
        for try await rate in stream.rollingThresholdExceedanceRate(window: 3, threshold: 50.0) {
            results.append(rate)
        }

        #expect(results.count == 1)
        let allUnevaluable: Bool = results.allSatisfy { $0.isNaN }
        #expect(allUnevaluable, "a window with no comparable difference reports nan, not 0")
    }

    @Test("An infinite difference is comparable and exceeds a finite threshold")
    func exceedanceRateCountsInfiniteDifference() async throws {
        // Observations:    [0, +inf, 100]
        // Absolute diffs:  |+inf - 0| = +inf  (exceeds 50)
        //                  |100 - +inf| = +inf (exceeds 50)
        // window = 2: 2 exceedances out of 2 comparable → 2/2
        // Contract §3.6: infinities order correctly and are left alone.
        let values: [Double] = [0.0, .infinity, 100.0]
        let stream = AsyncValueStream(values)

        var results: [Double] = []
        for try await rate in stream.rollingThresholdExceedanceRate(window: 2, threshold: 50.0) {
            results.append(rate)
        }

        let expected: Double = 2.0 / 2.0
        #expect(results.count == 1)
        let gap: Double = abs(results[0] - expected)
        #expect(gap < 1e-12, "an infinite jump is a measured exceedance, not an unusable one")
    }

    // MARK: - Cumulative statistics: extrema must not skip an unorderable observation

    @Test("Cumulative min and max report nan once an unorderable observation has been seen")
    func cumulativeExtremaMarkContamination() async throws {
        // `value < min` and `value > max` are both false for a `nan`, so the observation used
        // to vanish from the extrema while `sum` and `mean` in the same struct reported `nan`.
        let values: [Double] = [10.0, 20.0, .nan, 5.0, 30.0]
        let stream = AsyncValueStream(values)

        var stats: [CumulativeStats] = []
        for try await stat in stream.cumulativeStatistics() {
            stats.append(stat)
        }

        #expect(stats.count == 5)

        // Before the `nan`: ordinary behaviour, min = 10 and max = 20 over [10, 20].
        #expect(stats[1].min.isEqual(to: 10.0))
        #expect(stats[1].max.isEqual(to: 20.0))

        // From the `nan` on, cumulative statistics can never drop it again, so the extrema
        // stay unknown for the rest of the stream — exactly as `mean` and `sum` do.
        let contaminatedExtrema: [Double] = [
            stats[2].min, stats[2].max,
            stats[3].min, stats[3].max,
            stats[4].min, stats[4].max
        ]
        let allMarked: Bool = contaminatedExtrema.allSatisfy { $0.isNaN }
        #expect(allMarked, "min and max must not claim a floor and ceiling mean cannot compute")
        #expect(stats[4].mean.isNaN, "the field the extrema must agree with")
    }

    @Test("A leading unorderable observation no longer reports min above max")
    func cumulativeExtremaLeadingNaN() async throws {
        // The seeds are +infinity and -infinity. A `nan` first observation left both
        // untouched, so the first result claimed min = +infinity and max = -infinity — a
        // minimum above its own maximum, and both of them numbers a caller would threshold.
        let values: [Double] = [.nan, 1.0, 2.0]
        let stream = AsyncValueStream(values)

        var stats: [CumulativeStats] = []
        for try await stat in stream.cumulativeStatistics() {
            stats.append(stat)
        }

        #expect(stats.count == 3)
        #expect(stats[0].min.isNaN)
        #expect(stats[0].max.isNaN)
        #expect(stats[0].min.isInfinite == false, "the +infinity seed must not escape")
        #expect(stats[0].max.isInfinite == false, "the -infinity seed must not escape")
    }

    // MARK: - Warm-up is not normal

    @Test("Cumulative variance and stdDev are nan for the first observation")
    func cumulativeWarmUpIsNotZero() async throws {
        // Sample variance with Bessel's correction over one observation is 0/0. Reporting 0
        // claimed a measured spread of zero, which is the calmest reading on the scale.
        let values: [Double] = [10.0, 20.0, 30.0]
        let stream = AsyncValueStream(values)

        var stats: [CumulativeStats] = []
        for try await stat in stream.cumulativeStatistics() {
            stats.append(stat)
        }

        #expect(stats.count == 3)
        #expect(stats[0].count == 1)
        #expect(stats[0].mean.isEqual(to: 10.0))
        #expect(stats[0].variance.isNaN, "one observation says nothing about spread")
        #expect(stats[0].stdDev.isNaN, "stdDev is the square root of that same nothing")

        // Second observation: mean of [10, 20] is 15; deviations -5 and +5; sum of squares
        // 25 + 25 = 50; Bessel denominator 2 - 1 = 1; variance 50.
        let expectedVariance: Double = 50.0
        let varianceGap: Double = abs(stats[1].variance - expectedVariance)
        #expect(varianceGap < 1e-12, "the ordinary value from two observations onward")
        let expectedStdDev: Double = expectedVariance.squareRoot()
        let stdDevGap: Double = abs(stats[1].stdDev - expectedStdDev)
        #expect(stdDevGap < 1e-12)
    }

    @Test("Rolling variance of a one-observation window is nan, not zero")
    func rollingVarianceDegenerateWindowIsNotZero() async throws {
        let values: [Double] = [1.0, 2.0, 3.0]

        var variances: [Double] = []
        for try await variance in AsyncValueStream(values).rollingVariance(window: 1) {
            variances.append(variance)
        }

        var stdDevs: [Double] = []
        for try await stdDev in AsyncValueStream(values).rollingStdDev(window: 1) {
            stdDevs.append(stdDev)
        }

        #expect(variances.count == 3)
        #expect(stdDevs.count == 3)
        let varianceMarked: Bool = variances.allSatisfy { $0.isNaN }
        let stdDevMarked: Bool = stdDevs.allSatisfy { $0.isNaN }
        #expect(varianceMarked, "a window of one has no sample variance")
        #expect(stdDevMarked, "rollingStdDev(window: 1) must not claim a steady stream")
    }

    @Test("Rolling variance of a two-observation window is unchanged")
    func rollingVarianceTwoWideControl() async throws {
        // [1, 2]: mean 1.5, deviations -0.5 and +0.5, squares 0.25 + 0.25 = 0.5, /(2-1) = 0.5.
        // [2, 3]: identical spacing, so 0.5 again.
        let values: [Double] = [1.0, 2.0, 3.0]

        var variances: [Double] = []
        for try await variance in AsyncValueStream(values).rollingVariance(window: 2) {
            variances.append(variance)
        }

        let expected: Double = 0.5
        #expect(variances.count == 2)
        let firstGap: Double = abs(variances[0] - expected)
        let secondGap: Double = abs(variances[1] - expected)
        #expect(firstGap < 1e-12, "window 2 and above is untouched by the warm-up fix")
        #expect(secondGap < 1e-12)
    }

    @Test("Rolling statistics of a one-observation window marks only variance and stdDev")
    func rollingStatisticsDegenerateWindow() async throws {
        let values: [Double] = [1.0, 2.0, 3.0]
        let stream = AsyncValueStream(values)

        var stats: [RollingStats] = []
        for try await stat in stream.rollingStatistics(window: 1) {
            stats.append(stat)
        }

        #expect(stats.count == 3)
        #expect(stats[0].count == 1)
        #expect(stats[0].mean.isEqual(to: 1.0))
        #expect(stats[0].min.isEqual(to: 1.0))
        #expect(stats[0].max.isEqual(to: 1.0))
        #expect(stats[0].sum.isEqual(to: 1.0))
        #expect(stats[0].variance.isNaN, "one observation has no sample variance")
        #expect(stats[0].stdDev.isNaN)
    }

    // MARK: - EMA: an unusable observation is not smoothed in

    @Test("EMA marks the unusable observation and the very next element is already correct")
    func emaRecoversAtTheVeryNextElement() async throws {
        // alpha = 0.5, observations [10, 20, nan, 30]
        //   e0 = 10                          (seed)
        //   e1 = 0.5 * 20 + 0.5 * 10 = 15
        //   e2 = nan                         (not smoothed in; state stays at 15)
        //   e3 = 0.5 * 30 + 0.5 * 15 = 22.5
        // Before the fix e3 was `nan`, and so was every element after it.
        let values: [Double] = [10.0, 20.0, .nan, 30.0]
        let stream = AsyncValueStream(values)

        var emas: [Double] = []
        for try await ema in stream.exponentialMovingAverage(alpha: 0.5) {
            emas.append(ema)
        }

        let expected: [Double] = [10.0, 15.0, .nan, 22.5]
        #expect(emas.count == 4, "one output per input, contamination included")
        let matches: Bool = agree(emas, expected)
        #expect(matches, "the state from before the unusable observation must survive it")
    }

    @Test("EMA after recovery is bit-identical to smoothing the series without the bad value")
    func emaMatchesTheAsIfAbsentOracle() async throws {
        // The exact oracle, as in `AnalyticsRecoveryTests`: "the bad observation was not
        // folded into the state" means, precisely, that everything after it equals the
        // smoothing of the series with that observation simply not there. The surviving
        // operations are the same ops in the same order, so the agreement is bit-identical
        // and needs no tolerance.
        let contaminated: [Double] = [1, 2, 3, 4, 5, 6, 7, 8, .nan, 10, 11, 12, 13, 14, 15, 16, 17]
        let asIfAbsent: [Double] = [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 16, 17]

        var measured: [Double] = []
        for try await ema in AsyncValueStream(contaminated).exponentialMovingAverage(alpha: 0.3) {
            measured.append(ema)
        }

        var oracle: [Double] = []
        for try await ema in AsyncValueStream(asIfAbsent).exponentialMovingAverage(alpha: 0.3) {
            oracle.append(ema)
        }

        #expect(measured.count == 17)
        #expect(oracle.count == 16)
        #expect(measured[8].isNaN, "the unusable position, and only it, is marked")

        // Drop the marked position; what remains must be the oracle, element for element.
        var survivors: [Double] = measured
        survivors.remove(at: 8)
        let matches: Bool = agree(survivors, oracle)
        #expect(matches, "recovery is at index 9, and exact from there on")
    }

    @Test("EMA screens an infinity, which would otherwise be absorbing")
    func emaScreensInfinity() async throws {
        // alpha = 0.5, observations [10, +inf, 30]
        // Before the fix: e1 = 0.5 * inf + 0.5 * 10 = +inf, and then
        //                 e2 = 0.5 * 30 + 0.5 * inf = +inf — infinity never leaves the state.
        // After: the infinity is not smoothed in, so e2 = 0.5 * 30 + 0.5 * 10 = 20.
        let values: [Double] = [10.0, .infinity, 30.0]
        let stream = AsyncValueStream(values)

        var emas: [Double] = []
        for try await ema in stream.exponentialMovingAverage(alpha: 0.5) {
            emas.append(ema)
        }

        let expected: [Double] = [10.0, .nan, 20.0]
        #expect(emas.count == 3)
        let matches: Bool = agree(emas, expected)
        #expect(matches, "an infinite EMA is absorbing, so the infinity is screened")
    }

    @Test("EMA over a clean stream is unchanged")
    func emaCleanControl() async throws {
        // e0 = 10; e1 = 0.5 * 20 + 0.5 * 10 = 15; e2 = 0.5 * 30 + 0.5 * 15 = 22.5.
        let values: [Double] = [10.0, 20.0, 30.0]
        let stream = AsyncValueStream(values)

        var emas: [Double] = []
        for try await ema in stream.exponentialMovingAverage(alpha: 0.5) {
            emas.append(ema)
        }

        let expected: [Double] = [10.0, 15.0, 22.5]
        #expect(emas.count == 3)
        let matches: Bool = agree(emas, expected)
        #expect(matches, "a stream with nothing unusable must be untouched by the fix")
    }

    @Test("EMA seeds from the first usable observation when the stream opens unusable")
    func emaUnusableFirstObservation() async throws {
        // The seed is not taken from a `nan`. The EMA is left unseeded, so 20 initializes it
        // and the stream continues as though it had begun there: e2 = 0.5 * 30 + 0.5 * 20.
        let values: [Double] = [.nan, 20.0, 30.0]
        let stream = AsyncValueStream(values)

        var emas: [Double] = []
        for try await ema in stream.exponentialMovingAverage(alpha: 0.5) {
            emas.append(ema)
        }

        let expected: [Double] = [.nan, 20.0, 25.0]
        #expect(emas.count == 3, "the length invariant holds at the head of the stream too")
        let matches: Bool = agree(emas, expected)
        #expect(matches, "a nan must not become the seed")
    }
}

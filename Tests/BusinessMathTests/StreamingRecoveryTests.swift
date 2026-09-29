//
//  StreamingRecoveryTests.swift
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

/// Eight usable observations, one `nan`, eight more usable — the Phase 3 probe's input.
///
/// The `nan` is at index 8 of 17. For a window of `w`, output element `k` covers inputs
/// `k ... k + w - 1`, so the bad datum is inside outputs `9 - w ... 8` and output `9` is the
/// first that does not contain it. That index is the whole question: the recomputing sibling
/// `rollingStatistics` was clean from output 9, and the incremental operators were not clean
/// again at any point in the stream.
private let contaminatedSeries: [Double] = [
    1, 2, 3, 4, 5, 6, 7, 8, .nan, 10, 11, 12, 13, 14, 15, 16, 17
]

/// The same series with every observation usable.
private let controlSeries: [Double] = [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17
]

/// The contaminated series with the unusable observation removed rather than marked.
///
/// This is the oracle for the recursive smoothers: "the bad observation was not folded into
/// the state" means, exactly, that everything after it equals the smoothing of this series.
private let skippedSeries: [Double] = [
    1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 16, 17
]

/// Recovery from a single contaminated observation in the streaming operators.
///
/// A stateful operator's interesting failure is not "one `nan` in, one `nan` out" — it is
/// whether the operator is ever usable again. Every test here pins the **recovery index**,
/// so a regression in the eviction or state-repair logic fails at the position that moved
/// rather than somewhere downstream.
@Suite("Streaming contamination recovery")
struct StreamingRecoveryTests {

    // MARK: - Rolling mean

    @Test("rollingMean recovers at the first window past the bad datum")
    func rollingMeanRecovers() async throws {
        var dirty: [Double] = []
        for try await value in AsyncValueStream(contaminatedSeries).rollingMean(window: 4) {
            dirty.append(value)
        }
        var clean: [Double] = []
        for try await value in AsyncValueStream(controlSeries).rollingMean(window: 4) {
            clean.append(value)
        }

        #expect(dirty.count == 14)
        #expect(clean.count == 14)

        // Outputs 5...8 are the four windows that actually contain input 8.
        let poisoned: [Double] = Array(dirty[5...8])
        let allPoisoned: Bool = poisoned.allSatisfy { $0.isNaN }
        #expect(allPoisoned)

        // Output 9 is the first window past it, and it is the assertion that matters:
        // before the fix the accumulator stayed `nan` here and for every output after.
        let recovered: Double = dirty[9]
        #expect(!recovered.isNaN)
        #expect(recovered.isEqual(to: 11.5))
        #expect(recovered.isEqual(to: clean[9]))

        // The final output is clean, and is the same number the uncontaminated run gives.
        let dirtyLast: Double = try #require(dirty.last)
        let cleanLast: Double = try #require(clean.last)
        #expect(!dirtyLast.isNaN)
        #expect(dirtyLast.isEqual(to: 15.5))
        #expect(dirtyLast.isEqual(to: cleanLast))

        // Windows on either side of the bad datum were never in doubt and must not move.
        #expect(agree(Array(dirty[0...4]), Array(clean[0...4])))
        #expect(agree(Array(dirty[9...13]), Array(clean[9...13])))
    }

    @Test("rollingMean on usable data is unchanged")
    func rollingMeanControlUnchanged() async throws {
        var clean: [Double] = []
        for try await value in AsyncValueStream(controlSeries).rollingMean(window: 4) {
            clean.append(value)
        }

        #expect(clean.count == 14)
        let anyNaN: Bool = clean.contains { $0.isNaN }
        #expect(!anyNaN)
        #expect(clean[0].isEqual(to: 2.5))
        #expect(clean[13].isEqual(to: 15.5))
    }

    // MARK: - Rolling sum

    @Test("rollingSum recovers at the first window past the bad datum")
    func rollingSumRecovers() async throws {
        var dirty: [Double] = []
        for try await value in AsyncValueStream(contaminatedSeries).rollingSum(window: 4) {
            dirty.append(value)
        }
        var clean: [Double] = []
        for try await value in AsyncValueStream(controlSeries).rollingSum(window: 4) {
            clean.append(value)
        }

        #expect(dirty.count == 14)
        let poisoned: [Double] = Array(dirty[5...8])
        let allPoisoned: Bool = poisoned.allSatisfy { $0.isNaN }
        #expect(allPoisoned)

        let recovered: Double = dirty[9]
        #expect(!recovered.isNaN)
        #expect(recovered.isEqual(to: 46.0))

        let dirtyLast: Double = try #require(dirty.last)
        let cleanLast: Double = try #require(clean.last)
        #expect(!dirtyLast.isNaN)
        #expect(dirtyLast.isEqual(to: 62.0))
        #expect(dirtyLast.isEqual(to: cleanLast))
        #expect(agree(Array(dirty[0...4]), Array(clean[0...4])))
    }

    // MARK: - Rolling variance and standard deviation

    @Test("rollingVariance recovers at the first window past the bad datum")
    func rollingVarianceRecovers() async throws {
        var dirty: [Double] = []
        for try await value in AsyncValueStream(contaminatedSeries).rollingVariance(window: 4) {
            dirty.append(value)
        }
        var clean: [Double] = []
        for try await value in AsyncValueStream(controlSeries).rollingVariance(window: 4) {
            clean.append(value)
        }

        #expect(dirty.count == 14)
        #expect(clean.count == 14)

        let poisoned: [Double] = Array(dirty[5...8])
        let allPoisoned: Bool = poisoned.allSatisfy { $0.isNaN }
        #expect(allPoisoned)

        // Four consecutive integers have sample variance 5/3. The rebuilt state is a
        // forward-only Welford pass and the control's is an incremental one with eviction,
        // so they agree to within accumulated rounding rather than bit for bit.
        let expected: Double = 5.0 / 3.0
        let recovered: Double = dirty[9]
        #expect(!recovered.isNaN)
        let recoveredGap: Double = abs(recovered - expected)
        #expect(recoveredGap < 1e-12)

        let dirtyLast: Double = try #require(dirty.last)
        let cleanLast: Double = try #require(clean.last)
        #expect(!dirtyLast.isNaN)
        let lastGap: Double = abs(dirtyLast - cleanLast)
        #expect(lastGap < 1e-12)

        #expect(agree(Array(dirty[0...4]), Array(clean[0...4])))
    }

    @Test("rollingStdDev inherits the variance recovery")
    func rollingStdDevRecovers() async throws {
        var dirty: [Double] = []
        for try await value in AsyncValueStream(contaminatedSeries).rollingStdDev(window: 4) {
            dirty.append(value)
        }

        #expect(dirty.count == 14)
        let poisoned: [Double] = Array(dirty[5...8])
        let allPoisoned: Bool = poisoned.allSatisfy { $0.isNaN }
        #expect(allPoisoned)

        let expected: Double = (5.0 / 3.0).squareRoot()
        let recovered: Double = dirty[9]
        #expect(!recovered.isNaN)
        let recoveredGap: Double = abs(recovered - expected)
        #expect(recoveredGap < 1e-12)

        let dirtyLast: Double = try #require(dirty.last)
        #expect(!dirtyLast.isNaN)
    }

    // MARK: - Rolling extrema (§1.3)

    @Test("rollingMin marks every window holding the bad datum, not only the first slot")
    func rollingMinMarksEveryAffectedWindow() async throws {
        var dirty: [Double] = []
        for try await value in AsyncValueStream(contaminatedSeries).rollingMin(window: 4) {
            dirty.append(value)
        }
        var clean: [Double] = []
        for try await value in AsyncValueStream(controlSeries).rollingMin(window: 4) {
            clean.append(value)
        }

        #expect(dirty.count == 14)

        // The measured defect: only output 8 — where the `nan` happened to be the first
        // element examined — reported `nan`. Outputs 5, 6 and 7 handed back a finite floor
        // for a window whose values could not all be ordered.
        let poisoned: [Double] = Array(dirty[5...8])
        let allPoisoned: Bool = poisoned.allSatisfy { $0.isNaN }
        #expect(allPoisoned)

        let recovered: Double = dirty[9]
        #expect(recovered.isEqual(to: 10.0))
        #expect(recovered.isEqual(to: clean[9]))

        let dirtyLast: Double = try #require(dirty.last)
        #expect(dirtyLast.isEqual(to: 14.0))
        #expect(agree(Array(dirty[0...4]), Array(clean[0...4])))
    }

    @Test("rollingMax marks every window holding the bad datum, not only the first slot")
    func rollingMaxMarksEveryAffectedWindow() async throws {
        var dirty: [Double] = []
        for try await value in AsyncValueStream(contaminatedSeries).rollingMax(window: 4) {
            dirty.append(value)
        }
        var clean: [Double] = []
        for try await value in AsyncValueStream(controlSeries).rollingMax(window: 4) {
            clean.append(value)
        }

        #expect(dirty.count == 14)
        let poisoned: [Double] = Array(dirty[5...8])
        let allPoisoned: Bool = poisoned.allSatisfy { $0.isNaN }
        #expect(allPoisoned)

        let recovered: Double = dirty[9]
        #expect(recovered.isEqual(to: 13.0))

        let dirtyLast: Double = try #require(dirty.last)
        #expect(dirtyLast.isEqual(to: 17.0))
        #expect(agree(Array(dirty[0...4]), Array(clean[0...4])))
    }

    @Test("rollingMin and rollingMax on usable data are unchanged")
    func rollingExtremaControlUnchanged() async throws {
        var mins: [Double] = []
        for try await value in AsyncValueStream(controlSeries).rollingMin(window: 4) {
            mins.append(value)
        }
        var maxes: [Double] = []
        for try await value in AsyncValueStream(controlSeries).rollingMax(window: 4) {
            maxes.append(value)
        }

        #expect(mins.count == 14)
        #expect(maxes.count == 14)
        #expect(mins[0].isEqual(to: 1.0))
        #expect(maxes[0].isEqual(to: 4.0))
        #expect(mins[13].isEqual(to: 14.0))
        #expect(maxes[13].isEqual(to: 17.0))
    }

    // MARK: - Rolling statistics — every field agrees

    @Test("rollingStatistics reports the same footprint in every field")
    func rollingStatisticsFieldsAgree() async throws {
        var dirty: [RollingStats] = []
        for try await stats in AsyncValueStream(contaminatedSeries).rollingStatistics(window: 4) {
            dirty.append(stats)
        }

        #expect(dirty.count == 14)

        // Before the fix `mean` reported `nan` for all four affected windows while `min`
        // and `max` reported it for one. One field of the struct denying what another
        // admits is the defect; all six value-bearing fields now agree.
        let means: [Double] = Array(dirty[5...8]).map(\.mean)
        let mins: [Double] = Array(dirty[5...8]).map { $0.min }
        let maxes: [Double] = Array(dirty[5...8]).map { $0.max }
        let variances: [Double] = Array(dirty[5...8]).map(\.variance)
        let stdDevs: [Double] = Array(dirty[5...8]).map(\.stdDev)
        let sums: [Double] = Array(dirty[5...8]).map(\.sum)

        let meansNaN: Bool = means.allSatisfy { $0.isNaN }
        let minsNaN: Bool = mins.allSatisfy { $0.isNaN }
        let maxesNaN: Bool = maxes.allSatisfy { $0.isNaN }
        let variancesNaN: Bool = variances.allSatisfy { $0.isNaN }
        let stdDevsNaN: Bool = stdDevs.allSatisfy { $0.isNaN }
        let sumsNaN: Bool = sums.allSatisfy { $0.isNaN }

        #expect(meansNaN)
        #expect(minsNaN)
        #expect(maxesNaN)
        #expect(variancesNaN)
        #expect(stdDevsNaN)
        #expect(sumsNaN)

        // `count` is not a measurement of the values and stays truthful throughout.
        let counts: [Int] = dirty.map(\.count)
        let allFour: Bool = counts.allSatisfy { $0 == 4 }
        #expect(allFour)

        let recovered: RollingStats = dirty[9]
        #expect(recovered.mean.isEqual(to: 11.5))
        #expect(recovered.min.isEqual(to: 10.0))
        #expect(recovered.max.isEqual(to: 13.0))
        #expect(recovered.sum.isEqual(to: 46.0))

        let last: RollingStats = dirty[13]
        #expect(last.mean.isEqual(to: 15.5))
        #expect(last.min.isEqual(to: 14.0))
        #expect(last.max.isEqual(to: 17.0))
    }

    @Test("rollingStatistics on usable data is unchanged")
    func rollingStatisticsControlUnchanged() async throws {
        var clean: [RollingStats] = []
        for try await stats in AsyncValueStream(controlSeries).rollingStatistics(window: 4) {
            clean.append(stats)
        }

        #expect(clean.count == 14)
        let first: RollingStats = clean[0]
        #expect(first.mean.isEqual(to: 2.5))
        #expect(first.min.isEqual(to: 1.0))
        #expect(first.max.isEqual(to: 4.0))
        #expect(first.sum.isEqual(to: 10.0))
        let anyNaN: Bool = clean.contains { $0.mean.isNaN || $0.min.isNaN || $0.max.isNaN }
        #expect(!anyNaN)
    }

    // MARK: - Rolling RMSSD

    @Test("rollingSuccessiveDifferenceRMS recovers once both poisoned differences are evicted")
    func rollingSuccessiveDifferenceRMSRecovers() async throws {
        var dirty: [Double] = []
        for try await value in AsyncValueStream(contaminatedSeries)
            .rollingSuccessiveDifferenceRMS(window: 4) {
            dirty.append(value)
        }

        // 17 inputs give 16 successive differences and 13 windows of 4.
        #expect(dirty.count == 13)

        // Input 8 spoils two differences — d7 and d8 — so the affected windows are 4...8.
        let poisoned: [Double] = Array(dirty[4...8])
        let allPoisoned: Bool = poisoned.allSatisfy { $0.isNaN }
        #expect(allPoisoned)

        // Every usable difference in this series is exactly 1, so RMSSD is exactly 1.
        let recovered: Double = dirty[9]
        #expect(recovered.isEqual(to: 1.0))

        let dirtyLast: Double = try #require(dirty.last)
        #expect(dirtyLast.isEqual(to: 1.0))
        #expect(dirty[0].isEqual(to: 1.0))
    }

    // MARK: - Double exponential smoothing

    @Test("doubleExponentialSmoothing recovers on the very next observation")
    func doubleExponentialSmoothingRecovers() async throws {
        var dirty: [DoubleExponentialForecast] = []
        for try await forecast in AsyncValueStream(contaminatedSeries)
            .doubleExponentialSmoothing(alpha: 0.3, beta: 0.1) {
            dirty.append(forecast)
        }
        var skipped: [DoubleExponentialForecast] = []
        for try await forecast in AsyncValueStream(skippedSeries)
            .doubleExponentialSmoothing(alpha: 0.3, beta: 0.1) {
            skipped.append(forecast)
        }

        // The position is marked, not dropped: one output per input.
        #expect(dirty.count == 17)
        #expect(skipped.count == 16)

        #expect(dirty[8].level.isNaN)
        #expect(dirty[8].trend.isNaN)

        // Recovery is at index 9 — the very next observation — and the exact oracle for
        // "the bad observation was not folded into the state" is that everything after it
        // equals the smoothing of the series with that observation removed.
        let recoveredLevel: Double = dirty[9].level
        let recoveredTrend: Double = dirty[9].trend
        #expect(!recoveredLevel.isNaN)
        #expect(!recoveredTrend.isNaN)

        let dirtyLevels: [Double] = Array(dirty[9...]).map(\.level)
        let skippedLevels: [Double] = Array(skipped[8...]).map(\.level)
        #expect(agree(dirtyLevels, skippedLevels))

        let dirtyTrends: [Double] = Array(dirty[9...]).map(\.trend)
        let skippedTrends: [Double] = Array(skipped[8...]).map(\.trend)
        #expect(agree(dirtyTrends, skippedTrends))

        let finalLevel: Double = dirty[16].level
        let finalTrend: Double = dirty[16].trend
        #expect(!finalLevel.isNaN)
        #expect(!finalTrend.isNaN)
        #expect(finalTrend > 0.0)
    }

    @Test("doubleExponentialSmoothing on usable data is unchanged")
    func doubleExponentialSmoothingControlUnchanged() async throws {
        var clean: [DoubleExponentialForecast] = []
        for try await forecast in AsyncValueStream(controlSeries)
            .doubleExponentialSmoothing(alpha: 0.3, beta: 0.1) {
            clean.append(forecast)
        }
        var dirty: [DoubleExponentialForecast] = []
        for try await forecast in AsyncValueStream(contaminatedSeries)
            .doubleExponentialSmoothing(alpha: 0.3, beta: 0.1) {
            dirty.append(forecast)
        }

        #expect(clean.count == 17)
        let anyNaN: Bool = clean.contains { $0.level.isNaN || $0.trend.isNaN }
        #expect(!anyNaN)

        // Nothing before the bad datum can have moved.
        let cleanPrefix: [Double] = Array(clean[0...7]).map(\.level)
        let dirtyPrefix: [Double] = Array(dirty[0...7]).map(\.level)
        #expect(agree(cleanPrefix, dirtyPrefix))
    }

    // MARK: - Forecast errors

    @Test("forecastErrors recovers from a contaminated actual")
    func forecastErrorsRecoversFromContaminatedActual() async throws {
        // Every pair is off by exactly 1, so MAE and RMSE over any set of scoreable pairs
        // are exactly 1 — an exact oracle rather than a tolerance. A bad pair counted with
        // a zero contribution would give 17/18, which this discriminates.
        var pairs: [ForecastPair] = []
        for index in 0..<18 {
            let actual: Double = index == 8 ? Double.nan : 100.0 + Double(index)
            let forecast: Double = 99.0 + Double(index)
            pairs.append(ForecastPair(actual: actual, forecast: forecast))
        }

        var errors: [StreamingForecastError] = []
        for try await error in AsyncValueStream(pairs).forecastErrors() {
            errors.append(error)
        }

        #expect(errors.count == 18)

        #expect(errors[8].mae.isNaN)
        #expect(errors[8].rmse.isNaN)
        #expect(errors[8].mape.isNaN)

        // Recovery is at index 9, the very next pair.
        let recovered: StreamingForecastError = errors[9]
        #expect(recovered.mae.isEqual(to: 1.0))
        #expect(recovered.rmse.isEqual(to: 1.0))
        #expect(!recovered.mape.isNaN)

        let last: StreamingForecastError = errors[17]
        #expect(last.mae.isEqual(to: 1.0))
        #expect(last.rmse.isEqual(to: 1.0))

        // MAPE over the seventeen scoreable pairs, computed independently.
        var mapeSum: Double = 0.0
        for index in 0..<18 where index != 8 {
            let actual: Double = 100.0 + Double(index)
            mapeSum += 1.0 / actual
        }
        let expectedMape: Double = mapeSum / 17.0
        let mapeGap: Double = abs(last.mape - expectedMape)
        #expect(mapeGap < 1e-12)
    }

    @Test("forecastErrors recovers from a contaminated forecast")
    func forecastErrorsRecoversFromContaminatedForecast() async throws {
        // The other half of the question: a `nan` `forecast` poisons the error directly,
        // where a `nan` `actual` also slips past the `actual != 0` test.
        var pairs: [ForecastPair] = []
        for index in 0..<18 {
            let actual: Double = 100.0 + Double(index)
            let forecast: Double = index == 8 ? Double.nan : 99.0 + Double(index)
            pairs.append(ForecastPair(actual: actual, forecast: forecast))
        }

        var errors: [StreamingForecastError] = []
        for try await error in AsyncValueStream(pairs).forecastErrors() {
            errors.append(error)
        }

        #expect(errors.count == 18)
        #expect(errors[8].mae.isNaN)
        #expect(errors[8].rmse.isNaN)
        #expect(errors[8].mape.isNaN)

        let recovered: StreamingForecastError = errors[9]
        #expect(recovered.mae.isEqual(to: 1.0))
        #expect(recovered.rmse.isEqual(to: 1.0))

        let last: StreamingForecastError = errors[17]
        #expect(last.mae.isEqual(to: 1.0))
        #expect(last.rmse.isEqual(to: 1.0))
        #expect(!last.mape.isNaN)
    }

    @Test("forecastErrors on usable pairs is unchanged")
    func forecastErrorsControlUnchanged() async throws {
        var pairs: [ForecastPair] = []
        for index in 0..<18 {
            let actual: Double = 100.0 + Double(index)
            let forecast: Double = 99.0 + Double(index)
            pairs.append(ForecastPair(actual: actual, forecast: forecast))
        }

        var errors: [StreamingForecastError] = []
        for try await error in AsyncValueStream(pairs).forecastErrors() {
            errors.append(error)
        }

        #expect(errors.count == 18)
        let anyNaN: Bool = errors.contains { $0.mae.isNaN || $0.rmse.isNaN || $0.mape.isNaN }
        #expect(!anyNaN)
        #expect(errors[0].mae.isEqual(to: 1.0))
        #expect(errors[17].mae.isEqual(to: 1.0))
        #expect(errors[17].rmse.isEqual(to: 1.0))
    }
}

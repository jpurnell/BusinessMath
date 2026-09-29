//
//  SmoothingRecoveryTests.swift
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

// MARK: - Fixtures

/// Eight usable observations, one contaminated, eight more usable — the Phase 3 probe's input.
///
/// The bad datum is at index 8 of 17, and every recursive smoother in `StreamingForecasting`
/// was measured against exactly this series.
private let contaminatedSeries: [Double] = [
    1, 2, 3, 4, 5, 6, 7, 8, .nan, 10, 11, 12, 13, 14, 15, 16, 17
]

/// The same series with an infinity where the `nan` is.
///
/// Simple smoothing is a convex combination, so an infinity is absorbing rather than merely
/// large: it never leaves the state. That is why the guard tests `isFinite` and not `isNaN`.
private let infiniteSeries: [Double] = [
    1, 2, 3, 4, 5, 6, 7, 8, .infinity, 10, 11, 12, 13, 14, 15, 16, 17
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

/// Four seasonal slots of very different size, so a rotation of the seasonal array by one
/// position is visible in the factors rather than hidden in the noise.
private let slotLevels: [Double] = [100.0, 20.0, 50.0, 80.0]

/// Forty-eight observations, four-long season, with a 1%-per-period ramp on top.
///
/// The ramp matters for the removal oracle below: without it the series is exactly periodic,
/// so deleting a whole season would leave a series identical to a truncation of the original
/// and the identity being asserted would hold for uninteresting reasons.
private let seasonalDrift: [Double] = (0..<48).map { index in
    let ramp: Double = 1.0 + 0.01 * Double(index)
    let slot: Double = slotLevels[index % 4]
    return slot * ramp
}

/// The same forty-eight observations with no ramp, so each slot is constant.
///
/// Constant slots are what make the ordering assertion in the phase test legible: correct
/// phase drives the factors to the slot ordering `0 > 3 > 2 > 1`, and nothing else does.
private let seasonalFlat: [Double] = (0..<48).map { slotLevels[$0 % 4] }

// MARK: - Collection helpers

private func collectSimple(_ values: [Double], alpha: Double) async throws -> [Double] {
    var output: [Double] = []
    for try await forecast in AsyncValueStream(values).simpleExponentialSmoothing(alpha: alpha) {
        output.append(forecast)
    }
    return output
}

private func collectTriple(
    _ values: [Double],
    alpha: Double,
    beta: Double,
    gamma: Double,
    seasonLength: Int
) async throws -> [TripleExponentialForecast] {
    var output: [TripleExponentialForecast] = []
    let stream = AsyncValueStream(values).tripleExponentialSmoothing(
        alpha: alpha,
        beta: beta,
        gamma: gamma,
        seasonLength: seasonLength
    )
    for try await forecast in stream {
        output.append(forecast)
    }
    return output
}

private func allFinite(_ forecasts: ArraySlice<TripleExponentialForecast>) -> Bool {
    forecasts.allSatisfy { forecast in
        forecast.level.isFinite
            && forecast.trend.isFinite
            && forecast.seasonalFactors.allSatisfy { $0.isFinite }
    }
}

/// Recovery from contaminated observations in the exponential smoothers.
///
/// A recursive smoother's interesting failure is not "one bad value in, one bad value out" —
/// it is whether the smoother is ever usable again. Every test here pins the **recovery
/// index**, and the oracle for the recursion is exact rather than a tolerance: everything
/// from the recovery index onward must be bit-identical to smoothing the same series with
/// the unusable observation removed, which is precisely the statement that it was never
/// folded into the state.
@Suite("Exponential smoothing contamination recovery")
struct SmoothingRecoveryTests {

    // MARK: - Simple exponential smoothing

    @Test("simpleExponentialSmoothing recovers on the very next observation")
    func simpleExponentialSmoothingRecovers() async throws {
        let dirty: [Double] = try await collectSimple(contaminatedSeries, alpha: 0.3)
        let skipped: [Double] = try await collectSimple(skippedSeries, alpha: 0.3)

        // The position is marked, not dropped: one output per input.
        #expect(dirty.count == 17)
        #expect(skipped.count == 16)

        let marked: Double = dirty[8]
        #expect(marked.isNaN)

        // Recovery is at index 9 — the very next observation. Before the fix the forecast
        // stayed `nan` here and for every output after: 9 of 17 contaminated, first at 8 and
        // last at 16, the final element.
        let recovered: Double = dirty[9]
        #expect(!recovered.isNaN)

        let dirtyTail: [Double] = Array(dirty[9...])
        let skippedTail: [Double] = Array(skipped[8...])
        #expect(agree(dirtyTail, skippedTail))

        // Observations before the bad datum were never in doubt and must not move.
        let dirtyHead: [Double] = Array(dirty[0...7])
        let skippedHead: [Double] = Array(skipped[0...7])
        #expect(agree(dirtyHead, skippedHead))

        let finalForecast: Double = try #require(dirty.last)
        #expect(finalForecast.isFinite)
    }

    @Test("simpleExponentialSmoothing screens an infinity for the same reason")
    func simpleExponentialSmoothingScreensInfinity() async throws {
        let dirty: [Double] = try await collectSimple(infiniteSeries, alpha: 0.3)
        let skipped: [Double] = try await collectSimple(skippedSeries, alpha: 0.3)

        #expect(dirty.count == 17)
        let marked: Double = dirty[8]
        #expect(marked.isNaN)

        // An infinity is not merely large here. `F(t+1) = alpha * Y(t) + (1-alpha) * F(t)`
        // is a convex combination, so an infinite forecast reproduces itself forever:
        // measured on this series, every output from index 8 to the end was `infinity`.
        let tail: [Double] = Array(dirty[9...])
        let tailFinite: Bool = tail.allSatisfy { $0.isFinite }
        #expect(tailFinite)

        let skippedTail: [Double] = Array(skipped[8...])
        #expect(agree(tail, skippedTail))
    }

    @Test("simpleExponentialSmoothing does not let a leading bad datum become the state")
    func simpleExponentialSmoothingLeadingContamination() async throws {
        let leading: [Double] = [.nan, 2, 3, 4]
        let dirty: [Double] = try await collectSimple(leading, alpha: 0.3)
        let skipped: [Double] = try await collectSimple([2, 3, 4], alpha: 0.3)

        #expect(dirty.count == 4)
        let marked: Double = dirty[0]
        #expect(marked.isNaN)

        // The worst case for this operator: the bad datum used to *initialize* the forecast,
        // so the caller was told every forecast in the stream was unusable. Initialization
        // now happens at the first usable observation instead, and the first output after it
        // is that observation exactly.
        let firstUsable: Double = dirty[1]
        #expect(firstUsable.isEqual(to: 2.0))
        let dirtyTail: [Double] = Array(dirty[1...])
        #expect(agree(dirtyTail, skipped))
    }

    @Test("simpleExponentialSmoothing on usable data is unchanged")
    func simpleExponentialSmoothingControlUnchanged() async throws {
        let clean: [Double] = try await collectSimple(controlSeries, alpha: 0.3)
        let dirty: [Double] = try await collectSimple(contaminatedSeries, alpha: 0.3)

        #expect(clean.count == 17)
        let anyNaN: Bool = clean.contains { $0.isNaN }
        #expect(!anyNaN)

        // Initialization is the identity, and the smoother of a rising series rises.
        let firstOutput: Double = clean[0]
        #expect(firstOutput.isEqual(to: 1.0))
        let rising: Bool = zip(clean, clean.dropFirst()).allSatisfy { $0 < $1 }
        #expect(rising)

        // The guard must not disturb a stream with nothing wrong in it, so the prefix the
        // two runs share has to be bit-identical.
        let dirtyHead: [Double] = Array(dirty[0...7])
        let cleanHead: [Double] = Array(clean[0...7])
        #expect(agree(dirtyHead, cleanHead))
    }

    // MARK: - Triple exponential smoothing

    @Test("tripleExponentialSmoothing recovers on the very next observation")
    func tripleExponentialSmoothingRecovers() async throws {
        var contaminated: [Double] = seasonalDrift
        contaminated[17] = Double.nan

        let dirty: [TripleExponentialForecast] = try await collectTriple(
            contaminated, alpha: 0.3, beta: 0.1, gamma: 0.2, seasonLength: 4
        )
        let clean: [TripleExponentialForecast] = try await collectTriple(
            seasonalDrift, alpha: 0.3, beta: 0.1, gamma: 0.2, seasonLength: 4
        )

        #expect(dirty.count == 48)
        #expect(clean.count == 48)

        let badLevel: Double = dirty[17].level
        let badTrend: Double = dirty[17].trend
        #expect(badLevel.isNaN)
        #expect(badTrend.isNaN)

        // The prefix is untouched, so the state at the bad datum is the clean state.
        let dirtyLevels: [Double] = dirty[0...16].map(\.level)
        let cleanLevels: [Double] = clean[0...16].map(\.level)
        #expect(agree(dirtyLevels, cleanLevels))

        let dirtyTrends: [Double] = dirty[0...16].map(\.trend)
        let cleanTrends: [Double] = clean[0...16].map(\.trend)
        #expect(agree(dirtyTrends, cleanTrends))

        let dirtyFactors: [Double] = dirty[0...16].flatMap(\.seasonalFactors)
        let cleanFactors: [Double] = clean[0...16].flatMap(\.seasonalFactors)
        #expect(agree(dirtyFactors, cleanFactors))

        // The seasonal array reported at the contaminated position is the one from before it,
        // bit for bit — the direct statement that the state was preserved rather than updated.
        let preserved: [Double] = dirty[17].seasonalFactors
        let priorState: [Double] = clean[16].seasonalFactors
        #expect(agree(preserved, priorState))

        // Recovery is at index 18 — the very next observation. Before the fix `level` and
        // `trend` were `nan` for 31 of 48 outputs, first at 17 and last at 47.
        let recoveredFinite: Bool = allFinite(dirty[18...])
        #expect(recoveredFinite)
    }

    @Test("tripleExponentialSmoothing skips a whole contaminated season exactly")
    func tripleExponentialSmoothingFullSeasonMatchesRemoval() async throws {
        // A four-long block of contamination in steady state. A block of exactly one season
        // is the case where the removal oracle is expressible: the observation that follows
        // it lands on the same seasonal slot whether the block is skipped in place or deleted
        // outright, so "not folded into the state" is testable as bit-identity.
        var contaminated: [Double] = seasonalDrift
        for index in 12..<16 {
            contaminated[index] = Double.nan
        }
        let removed: [Double] = Array(seasonalDrift[0..<12]) + Array(seasonalDrift[16...])

        let dirty: [TripleExponentialForecast] = try await collectTriple(
            contaminated, alpha: 0.3, beta: 0.1, gamma: 0.2, seasonLength: 4
        )
        let reference: [TripleExponentialForecast] = try await collectTriple(
            removed, alpha: 0.3, beta: 0.1, gamma: 0.2, seasonLength: 4
        )

        #expect(dirty.count == 48)
        #expect(reference.count == 44)

        let blockLevels: [Double] = dirty[12..<16].map(\.level)
        let blockIsNaN: Bool = blockLevels.allSatisfy { $0.isNaN }
        #expect(blockIsNaN)

        let dirtyLevels: [Double] = dirty[16...].map(\.level)
        let referenceLevels: [Double] = reference[12...].map(\.level)
        #expect(agree(dirtyLevels, referenceLevels))

        let dirtyTrends: [Double] = dirty[16...].map(\.trend)
        let referenceTrends: [Double] = reference[12...].map(\.trend)
        #expect(agree(dirtyTrends, referenceTrends))

        let dirtyFactors: [Double] = dirty[16...].flatMap(\.seasonalFactors)
        let referenceFactors: [Double] = reference[12...].flatMap(\.seasonalFactors)
        #expect(agree(dirtyFactors, referenceFactors))
    }

    @Test("tripleExponentialSmoothing keeps the seasonal phase across a bad datum")
    func tripleExponentialSmoothingKeepsThePhase() async throws {
        var contaminated: [Double] = seasonalFlat
        contaminated[17] = Double.nan

        let dirty: [TripleExponentialForecast] = try await collectTriple(
            contaminated, alpha: 0.3, beta: 0.1, gamma: 0.2, seasonLength: 4
        )
        let clean: [TripleExponentialForecast] = try await collectTriple(
            seasonalFlat, alpha: 0.3, beta: 0.1, gamma: 0.2, seasonLength: 4
        )

        #expect(dirty.count == 48)

        // Each slot is constant at 100, 20, 50, 80, so correct phase drives the factors to
        // that ordering and nothing else does. Discarding the bad datum's seasonal slot
        // instead of consuming it would rotate every later observation onto the neighbouring
        // slot, and thirty observations later the ordering is gone — measured on a
        // deliberately phase-shifting variant of this operator, the final factors came out
        // 0.574, 0.599, 0.957, 1.215, which is not this order at all.
        let dirtyFactors: [Double] = try #require(dirty.last).seasonalFactors
        #expect(dirtyFactors.count == 4)
        #expect(dirtyFactors[0] > dirtyFactors[3])
        #expect(dirtyFactors[3] > dirtyFactors[2])
        #expect(dirtyFactors[2] > dirtyFactors[1])

        // The same ordering in the uncontaminated run, so the claim above is about the
        // operator's phase and not about the fixture.
        let cleanFactors: [Double] = try #require(clean.last).seasonalFactors
        #expect(cleanFactors[0] > cleanFactors[3])
        #expect(cleanFactors[3] > cleanFactors[2])
        #expect(cleanFactors[2] > cleanFactors[1])
    }

    @Test("tripleExponentialSmoothing still registers a 50x spike 24 observations after a bad datum in the same slot")
    func tripleExponentialSmoothingSeasonalSlotSurvives() async throws {
        // The shape that caught `detectSeasonalAnomalies`: index 17 and index 41 are the same
        // seasonal slot (both ≡ 1 mod 4), twenty-four observations apart. Index 41 is a 50x
        // spike against that slot's baseline of 20.
        var spiked: [Double] = seasonalFlat
        spiked[41] = 999.0
        var spikedAndContaminated: [Double] = spiked
        spikedAndContaminated[17] = Double.nan
        var contaminatedOnly: [Double] = seasonalFlat
        contaminatedOnly[17] = Double.nan

        let withSpike: [TripleExponentialForecast] = try await collectTriple(
            spikedAndContaminated, alpha: 0.3, beta: 0.1, gamma: 0.2, seasonLength: 4
        )
        let withoutSpike: [TripleExponentialForecast] = try await collectTriple(
            contaminatedOnly, alpha: 0.3, beta: 0.1, gamma: 0.2, seasonLength: 4
        )

        #expect(withSpike.count == 48)
        #expect(withoutSpike.count == 48)

        // The measured defect: every one of these was `nan`. The seasonal array went `nan` in
        // slot 1 at index 17, and because the `nan` level then divided into each of the other
        // slots in turn, all four were `nan` by index 20 and stayed `nan` to index 47. A
        // spike cannot register against a `nan` baseline — every comparison with it is false.
        let stillUsable: Bool = allFinite(withSpike[18...])
        #expect(stillUsable)

        // The two runs are identical up to index 40, so the only thing that can separate them
        // at 41 is the spike itself.
        let spikeRunLevels: [Double] = withSpike[0...40].map(\.level)
        let baselineRunLevels: [Double] = withoutSpike[0...40].map(\.level)
        #expect(agree(spikeRunLevels, baselineRunLevels))

        let spikeRunFactors: [Double] = withSpike[0...40].flatMap(\.seasonalFactors)
        let baselineRunFactors: [Double] = withoutSpike[0...40].flatMap(\.seasonalFactors)
        #expect(agree(spikeRunFactors, baselineRunFactors))

        // And it does separate them: the spike moves the level and lifts slot 1's factor.
        let spikeLevel: Double = withSpike[41].level
        let baselineLevel: Double = withoutSpike[41].level
        #expect(spikeLevel.isFinite)
        #expect(baselineLevel.isFinite)
        #expect(spikeLevel > baselineLevel)
        let levelBeforeSpike: Double = withSpike[40].level
        #expect(spikeLevel > levelBeforeSpike)

        let spikeFactor: Double = withSpike[41].seasonalFactors[1]
        let baselineFactor: Double = withoutSpike[41].seasonalFactors[1]
        #expect(spikeFactor.isFinite)
        #expect(baselineFactor.isFinite)
        #expect(spikeFactor > baselineFactor)
    }

    @Test("tripleExponentialSmoothing survives contamination inside the initialization window")
    func tripleExponentialSmoothingInitializationWindow() async throws {
        var contaminated: [Double] = seasonalFlat
        contaminated[1] = Double.nan

        let dirty: [TripleExponentialForecast] = try await collectTriple(
            contaminated, alpha: 0.3, beta: 0.1, gamma: 0.2, seasonLength: 4
        )

        #expect(dirty.count == 48)
        let badLevel: Double = dirty[1].level
        let badTrend: Double = dirty[1].trend
        #expect(badLevel.isNaN)
        #expect(badTrend.isNaN)

        // The worst case for this operator, and the one the old code handled least well: the
        // initial level was the mean including the bad datum, so it was `nan`; `nan != 0.0`
        // is *true*, so the guard on a zero level let the factor loop run and divide all four
        // factors by that `nan`. Every seasonal factor was `nan` from the first emitted
        // forecast to the last, so the caller was told the series had no measurable
        // seasonality whatever.
        let factors: [Double] = dirty[3].seasonalFactors
        #expect(factors.count == 4)
        let factorsFinite: Bool = factors.allSatisfy { $0.isFinite }
        #expect(factorsFinite)

        // The slot with no usable observation keeps the neutral multiplicative identity: no
        // seasonal information was measured for it, so it adjusts nothing.
        let neutralSlot: Double = factors[1]
        #expect(neutralSlot.isEqual(to: 1.0))

        // The three slots that were measured order as their levels do — 100 > 80 > 50 over a
        // level common to all three.
        #expect(factors[0] > factors[3])
        #expect(factors[3] > factors[2])

        let recovered: Bool = allFinite(dirty[2...])
        #expect(recovered)
    }

    @Test("tripleExponentialSmoothing on usable data is unchanged")
    func tripleExponentialSmoothingControlUnchanged() async throws {
        let clean: [TripleExponentialForecast] = try await collectTriple(
            seasonalDrift, alpha: 0.3, beta: 0.1, gamma: 0.2, seasonLength: 4
        )

        #expect(clean.count == 48)
        let everythingFinite: Bool = allFinite(clean[0...])
        #expect(everythingFinite)

        // Initialization: the level is the mean of the first season, and the trend starts at
        // zero by construction.
        let firstSeason: [Double] = Array(seasonalDrift[0..<4])
        let seasonSum: Double = firstSeason.reduce(0.0, +)
        let expectedLevel: Double = seasonSum / 4.0
        let initialLevel: Double = clean[3].level
        let initialTrend: Double = clean[3].trend
        #expect(initialLevel.isEqual(to: expectedLevel))
        #expect(initialTrend.isEqual(to: 0.0))

        // Each initial factor is its observation over that level, exactly.
        let expectedFactors: [Double] = firstSeason.map { $0 / expectedLevel }
        let initialFactors: [Double] = clean[3].seasonalFactors
        #expect(agree(initialFactors, expectedFactors))
    }
}

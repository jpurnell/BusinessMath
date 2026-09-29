//
//  ContaminatedDetectorRecoveryTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-09-28.
//

import Testing
import Foundation
@testable import BusinessMath

/// Recovery tests for the three streaming detectors that **went silent** about a real event
/// after a single unevaluable observation.
///
/// Measured at `cb829637` (`project/plans/PHASE3_PROBE_FINDINGS.md` §1.1): one NaN suppressed a
/// level shift, a 50× seasonal spike and a sustained process shift respectively, in each case an
/// event the same detector reported on otherwise identical clean input.
///
/// Every test here is a **pair**. The contaminated run must report the event; the control run —
/// the same series with the bad datum replaced by a legitimate observation — must keep reporting
/// exactly what it reported before. The control is what proves the fix is targeted rather than a
/// blanket decision to flag everything.
///
/// Contract: `project/plans/CONTAMINATED_INPUT_CONTRACT.md` §3. The precedent for
/// ``AsyncBreakpointDetectionSequence`` is ``AsyncChangePointDetectionSequence``, which reported
/// `[21, 22, 23, 24, 25]` on both runs of the probe: a bounded, recomputed statistic that never
/// accumulates the unevaluable value into state outliving it.
@Suite("Contaminated Detector Recovery")
struct ContaminatedDetectorRecoveryTests {

    // MARK: - detectBreakpoints — a level shift fifteen observations after the bad datum

    @Test("detectBreakpoints still finds the 10 to 50 level shift after a NaN at index 5")
    func breakpointsSurviveAnEarlyNaN() async throws {
        let clean: [Double] = Array(repeating: 10.0, count: 20) + Array(repeating: 50.0, count: 20)
        var contaminated: [Double] = clean
        contaminated[5] = Double.nan

        var contaminatedBreaks: [Breakpoint] = []
        for try await breakpoint in AsyncValueStream(contaminated)
            .detectBreakpoints(method: .binarySegmentation(minSegmentSize: 5, maxBreakpoints: 3)) {
            contaminatedBreaks.append(breakpoint)
        }

        // The measured defect: this list was empty. The whole-segment cost was NaN, so every
        // `costReduction > maxCostReduction` was false and no split was ever scored.
        #expect(contaminatedBreaks.count == 1)
        let found = try #require(contaminatedBreaks.first)
        #expect(found.index == 20)
        #expect(found.leftMean.isEqual(to: 10.0))
        #expect(found.rightMean.isEqual(to: 50.0))

        // The one observation that could not be evaluated is missing from the cost, so the
        // reduction is smaller than the control's — but it is still overwhelmingly significant.
        let reduction: Double = found.costReduction
        #expect(reduction > 15_000.0)
        #expect(reduction < 16_000.0)

        var controlBreaks: [Breakpoint] = []
        for try await breakpoint in AsyncValueStream(clean)
            .detectBreakpoints(method: .binarySegmentation(minSegmentSize: 5, maxBreakpoints: 3)) {
            controlBreaks.append(breakpoint)
        }

        // Control, unchanged: 40 points split 20/20 about a mean of 30 costs 40 × 20² = 16000,
        // and the split at 20 removes all of it.
        #expect(controlBreaks.count == 1)
        let control = try #require(controlBreaks.first)
        #expect(control.index == 20)
        #expect(control.leftMean.isEqual(to: 10.0))
        #expect(control.rightMean.isEqual(to: 50.0))
        let controlReduction: Double = control.costReduction
        let controlReductionError: Double = abs(controlReduction - 16_000.0)
        #expect(controlReductionError < 1e-9)
    }

    @Test("detectBreakpoints declines a series it cannot evaluate at all")
    func breakpointsDeclineAnEntirelyUnevaluableSeries() async throws {
        let unusable: [Double] = Array(repeating: Double.nan, count: 24)

        var breaks: [Breakpoint] = []
        for try await breakpoint in AsyncValueStream(unusable)
            .detectBreakpoints(method: .binarySegmentation(minSegmentSize: 5, maxBreakpoints: 3)) {
            breaks.append(breakpoint)
        }

        // No evaluable observation means no level to report, and reporting one anyway would be a
        // fabricated `leftMean`/`rightMean`. Empty is the honest answer here, and only here.
        #expect(breaks.isEmpty)
    }

    // MARK: - detectSeasonalAnomalies — a 50x spike 24 observations after the bad datum

    @Test("detectSeasonalAnomalies still flags the index-41 spike after a NaN in the same slot")
    func seasonalAnomaliesSurviveANaNInTheSameSeasonSlot() async throws {
        // Four slots, each constant: 100, 20, 50, 80. Index 41 (slot 1) spikes to 999 against a
        // slot baseline of 20. Index 17 is the same slot, 24 observations earlier.
        let slotLevels: [Double] = [100.0, 20.0, 50.0, 80.0]
        var clean: [Double] = (0..<48).map { slotLevels[$0 % 4] }
        clean[41] = 999.0
        var contaminated: [Double] = clean
        contaminated[17] = Double.nan

        var contaminatedResults: [SeasonalAnomaly] = []
        for try await anomaly in AsyncValueStream(contaminated).detectSeasonalAnomalies(period: 4, threshold: 3.0) {
            contaminatedResults.append(anomaly)
        }

        // One result per input value, contaminated or not.
        #expect(contaminatedResults.count == 48)

        // The measured defect: `isAnomaly` was false here. Slot 1's baseline had retained the NaN
        // from index 17, so `expected` was NaN at 21, 25, 29, … and `abs(999 - NaN) > 0.1` is false.
        let spike = try #require(contaminatedResults.first { $0.index == 41 })
        #expect(spike.isAnomaly)
        #expect(spike.expectedValue.isEqual(to: 20.0))
        #expect(spike.deviation.isEqual(to: 979.0))

        // The bad datum itself is reported as not compared, not as perfectly on pattern.
        let unevaluable = try #require(contaminatedResults.first { $0.index == 17 })
        #expect(unevaluable.value.isNaN)
        #expect(unevaluable.deviation.isNaN)
        #expect(unevaluable.isAnomaly == false)

        // Nothing else in the contaminated run is flagged: the slots are constant and the fix
        // must not turn an unevaluable baseline into a reason to flag.
        let contaminatedFlagged: [Int] = contaminatedResults.filter { $0.isAnomaly }.map { $0.index }
        #expect(contaminatedFlagged == [41])

        var controlResults: [SeasonalAnomaly] = []
        for try await anomaly in AsyncValueStream(clean).detectSeasonalAnomalies(period: 4, threshold: 3.0) {
            controlResults.append(anomaly)
        }

        #expect(controlResults.count == 48)
        let controlSpike = try #require(controlResults.first { $0.index == 41 })
        #expect(controlSpike.isAnomaly)
        #expect(controlSpike.expectedValue.isEqual(to: 20.0))
        #expect(controlSpike.deviation.isEqual(to: 979.0))

        let controlFlagged: [Int] = controlResults.filter { $0.isAnomaly }.map { $0.index }
        #expect(controlFlagged == [41])
    }

    // MARK: - ewma — a sustained shift after the bad datum

    @Test("ewma still signals a sustained shift after a NaN at index 5")
    func ewmaSurvivesAnEarlyNaN() async throws {
        let clean: [Double] = Array(repeating: 100.0, count: 20) + Array(repeating: 130.0, count: 10)
        var contaminated: [Double] = clean
        contaminated[5] = Double.nan

        var contaminatedSignals: [EWMASignal] = []
        for try await signal in AsyncValueStream(contaminated).ewma(target: 100.0, lambda: 0.3, controlLimitSigma: 3.0) {
            contaminatedSignals.append(signal)
        }

        // One signal per input value, and the stream is not truncated at the bad datum.
        #expect(contaminatedSignals.count == 30)

        let contaminatedFlagged: [Int] = contaminatedSignals.filter { $0.isOutOfControl }.map { $0.index }

        // The measured defect: this list was empty. The NaN entered both the EWMA recursion and
        // the sigma sample, so the statistic and both control limits were NaN thereafter and
        // `ewma < lcl || ewma > ucl` could never be true again.
        #expect(contaminatedFlagged.isEmpty == false)
        let firstContaminatedFlag: Int = try #require(contaminatedFlagged.first)
        #expect(firstContaminatedFlag == 20)

        // Nothing before the shift is flagged: the process really was on target there.
        let earlyFlags: [Int] = contaminatedFlagged.filter { $0 < 20 }
        #expect(earlyFlags.isEmpty)

        // The bad datum itself has no statistic, and no statistic is not an out-of-control one.
        let unevaluable = try #require(contaminatedSignals.first { $0.index == 5 })
        #expect(unevaluable.ewma.isNaN)
        #expect(unevaluable.isOutOfControl == false)

        // The chart recovers: every later statistic is usable again.
        let afterTheBadDatum = contaminatedSignals.filter { $0.index > 5 }
        #expect(afterTheBadDatum.allSatisfy { $0.ewma.isFinite })

        var controlSignals: [EWMASignal] = []
        for try await signal in AsyncValueStream(clean).ewma(target: 100.0, lambda: 0.3, controlLimitSigma: 3.0) {
            controlSignals.append(signal)
        }

        #expect(controlSignals.count == 30)
        let controlFlagged: [Int] = controlSignals.filter { $0.isOutOfControl }.map { $0.index }
        let firstControlFlag: Int = try #require(controlFlagged.first)
        #expect(firstControlFlag == 20)

        // The fix is targeted: the contaminated run reacts on the same observation as the control.
        #expect(firstContaminatedFlag == firstControlFlag)
    }
}

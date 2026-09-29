//
//  CompositeScorePartialEvidenceTests.swift
//  BusinessMathTests
//
//  Two decisions are pinned here.
//
//  **Partial evidence.** The composite anomaly score is the mean of the components that could
//  be evaluated, divided by the count that remained. It is `.nan` only when *every* component
//  is unevaluable.
//
//  The reason is a measurement, not a preference. Feeding a 1,000,000 spike through a window
//  holding one contaminated observation, the probe recorded IQR and MAD both scoring the spike
//  at the saturation ceiling while the z-score component went blind — its mean had been
//  poisoned. An all-or-nothing rule ("one blind component makes the composite `.nan`") would
//  have suppressed a real 1,000,000 spike that two of the three methods saw perfectly. That is
//  the "detector goes quiet" failure the whole adversarial-input sweep exists to remove, so a
//  blind component is excluded from the mean rather than allowed to veto the others.
//
//  **Warm-up is not "normal".** Six guards used to answer `0.0` — "perfectly normal" — for
//  every stream's first observations, on the grounds that not enough data had arrived to judge
//  them. Warm-up now answers `.nan`: not yet evaluable. Since every comparison against `nan` is
//  false, `isOutlier = score > threshold` stays `false`, which reads as "not evaluated" rather
//  than "evaluated and found unremarkable".
//
//  Two things must survive both changes, and are pinned below:
//    - a flat window with a real deviation still scores `.infinity`, and the composite still
//      saturates that to exactly 1.0 — `.infinity` is evidence, not contamination;
//    - a clean control scores the same spike identically, so the contaminated result is a
//      comparison rather than an assumption.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Composite anomaly score with partial evidence")
struct CompositeScorePartialEvidenceTests {

    // MARK: - Fixtures

    /// Five orders of magnitude above the baseline. Unmistakably an event.
    private static let spike = 1_000_000.0

    /// Eleven readings around 5.0 with one `nan` fourth, then the spike.
    ///
    /// With `window: 10` the `nan` is still inside the rolling window when the spike arrives,
    /// so the z-score component's mean is `nan` and that component cannot see the spike. Nine
    /// finite readings remain, which is enough for IQR (needs 4) and MAD (needs 2).
    private static let contaminatedWindow: [Double] =
        [5.0, 5.1, 4.9, .nan, 5.05, 4.95, 5.0, 5.2, 4.8, 5.0, spike]

    /// The same series with the `nan` replaced by an ordinary reading. Every assertion about
    /// the contaminated series is paired with this one.
    private static let cleanWindow: [Double] =
        [5.0, 5.1, 4.9, 5.0, 5.05, 4.95, 5.0, 5.2, 4.8, 5.0, spike]

    /// Twenty identical readings, then the spike. The window has no spread at all, which is the
    /// ordinary state of a healthy metric and the case that produces a legitimate `.infinity`.
    private static let flatThenSpike: [Double] =
        [5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0,
         5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, spike]

    /// The widest the clean readings ever span: 5.2 - 4.8. Every dispersion measured from a
    /// subset of them — an IQR, a MAD — is at most this, which is what makes the lower bounds
    /// on the component scores below arithmetic rather than recalled.
    private static let widestCleanSpread = 0.4

    // MARK: - Harness

    private func stream(_ values: [Double]) -> AsyncStream<Double> {
        AsyncStream { continuation in
            for value in values {
                continuation.yield(value)
            }
            continuation.finish()
        }
    }

    private func composites(
        _ values: [Double],
        window: Int
    ) async throws -> [CompositeAnomalyScore] {
        var collected: [CompositeAnomalyScore] = []
        let sequence = stream(values).compositeAnomalyScore(
            window: window,
            methods: [.zScore, .iqr, .mad]
        )
        for try await score in sequence {
            collected.append(score)
        }
        return collected
    }

    private func detections(
        _ values: [Double],
        method: OutlierMethod,
        window: Int
    ) async throws -> [OutlierDetection] {
        var collected: [OutlierDetection] = []
        for try await detection in stream(values).detectOutliers(method: method, window: window) {
            collected.append(detection)
        }
        return collected
    }

    // MARK: - Decision 1: the spike is still scored when one component is blind

    /// The assertion the whole decision rests on.
    ///
    /// The z-score component cannot see this spike — its window contains a `nan`, so its mean
    /// is `nan`. IQR and MAD filter that observation out of their sort and both score the spike
    /// enormously. Averaging over the two that answered keeps the composite at its ceiling.
    @Test("Composite_ScoresARealSpikeWhileOneComponentIsBlind")
    func compositeScoresARealSpikeWhileOneComponentIsBlind() async throws {
        let results = try await composites(Self.contaminatedWindow, window: 10)
        let last = try #require(results.last)

        #expect(last.score.isEqual(to: 1.0), "a 1,000,000 spike two of three methods saw clearly")

        let zScore = try #require(last.methodScores["z-score"])
        #expect(zScore.isNaN, "the contaminated window leaves this component unevaluable")

        // Lower bounds, not recalled values. The deviation is at least `spike - 5.2`, and the
        // dispersion each method divides by is at most the clean readings' full span, 0.4.
        let smallestDeviation: Double = Self.spike - 5.2
        let iqrFloor: Double = smallestDeviation / Self.widestCleanSpread
        let iqrScore = try #require(last.methodScores["iqr"])
        #expect(iqrScore > iqrFloor, "IQR carried the composite: \(iqrScore)")

        // MAD scales the deviation by the 0.6745 modified-z constant before dividing.
        let madFloor: Double = 0.6745 * iqrFloor
        let madScore = try #require(last.methodScores["mad"])
        #expect(madScore > madFloor, "MAD carried the composite: \(madScore)")
    }

    /// The control that makes the test above a comparison. Same spike, no contamination: the
    /// composite is identical and the z-score component is a real number.
    @Test("Composite_CleanControlScoresTheSameSpikeIdentically")
    func compositeCleanControlScoresTheSameSpikeIdentically() async throws {
        let results = try await composites(Self.cleanWindow, window: 10)
        let last = try #require(results.last)

        #expect(last.score.isEqual(to: 1.0), "the headline number is unchanged by the fix")

        let zScore = try #require(last.methodScores["z-score"])
        #expect(zScore.isFinite, "with a clean window this component sees the spike")

        // The probe that decided Decision 1 recorded this control at 2.846 — "z sub-score went
        // blind (0 contaminated vs 2.846 control)", PHASE3_PROBE_FINDINGS §1.4. Reproducing
        // that number is what makes this fixture the probe's control rather than a new one, so
        // it is pinned: if the fixture drifts, the contaminated case above stops testing what
        // it claims to test.
        let probeControl: Double = 2.846
        let gap: Double = abs(zScore - probeControl)
        #expect(gap < 0.001, "z-score component: \(zScore)")
    }

    /// A blind method keeps its key. Omitting it would hand the caller a dictionary that had
    /// silently shrunk, which cannot be told apart from a method that was never requested.
    @Test("Composite_BlindMethodKeepsItsKeyAsNaN")
    func compositeBlindMethodKeepsItsKeyAsNaN() async throws {
        let results = try await composites(Self.contaminatedWindow, window: 10)
        let last = try #require(results.last)

        #expect(last.methodScores.count == 3, "one entry per requested method, always")

        let hasZScoreKey: Bool = last.methodScores.keys.contains("z-score")
        #expect(hasZScoreKey, "the unevaluable method is present, not omitted")
    }

    /// Only when nothing at all could be evaluated does the composite itself decline.
    ///
    /// On a stream's very first observation the window holds one value: the z-score needs two,
    /// IQR needs four, MAD needs two. Before the fix this was reported as `0.0` — the strongest
    /// possible statement of normality, made from a single reading.
    @Test("Composite_IsNaNWhenEveryComponentIsUnevaluable")
    func compositeIsNaNWhenEveryComponentIsUnevaluable() async throws {
        let results = try await composites([42.0], window: 10)
        let first = try #require(results.first)

        #expect(first.score.isNaN, "one observation supports no verdict, not a verdict of normal")

        let everyComponentDeclined: Bool = first.methodScores.values.allSatisfy { $0.isNaN }
        #expect(everyComponentDeclined, "and each component says so individually")
    }

    // MARK: - `.infinity` is evidence, and must not be screened out with the NaNs

    /// The flat-window behaviour this change must not disturb.
    ///
    /// Twenty readings of 5.0 give IQR and MAD a dispersion of exactly zero, so a real
    /// deviation from that window is unbounded in units of its spread — `.infinity`. That score
    /// is kept in the composite's sum, where the `min(1.0, ...)` clamp saturates it to exactly
    /// 1.0. Screening components on `isFinite` rather than on `isNaN` would have discarded it
    /// alongside the contaminated ones and reinstated the original defect.
    @Test("Composite_FlatWindowInfinitySaturatesToExactlyOne")
    func compositeFlatWindowInfinitySaturatesToExactlyOne() async throws {
        let results = try await composites(Self.flatThenSpike, window: 50)
        let last = try #require(results.last)

        let iqrScore = try #require(last.methodScores["iqr"])
        #expect(iqrScore.isInfinite, "zero interquartile spread, a deviation of 999,995")

        let madScore = try #require(last.methodScores["mad"])
        #expect(madScore.isInfinite, "zero median absolute deviation, same deviation")

        #expect(last.score.isEqual(to: 1.0), "saturated, not escaped and not discarded")
        #expect(last.score.isFinite, "the caller still receives a number in 0...1")
    }

    // MARK: - Decision 2: warm-up is not "normal"

    /// The z-score detector needs two prior observations. It used to answer `0.0` before it had
    /// them — "this value sits exactly on the mean" — for a mean that did not exist yet.
    ///
    /// The detector scores each value against the window *before* appending it, so the first
    /// observation sees an empty window and the second sees one element.
    @Test("Detector_ZScoreWarmUpIsNotYetEvaluable")
    func detectorZScoreWarmUpIsNotYetEvaluable() async throws {
        let observed = try await detections(
            [5.0, 5.1, 4.9, 5.0, 5.2],
            method: .zScore(threshold: 3.0),
            window: 10
        )

        #expect(observed.count == 5, "one result per input, the length invariant holds")
        #expect(observed[0].score.isNaN, "no window at all")
        #expect(observed[1].score.isNaN, "one observation is not a baseline")
        #expect(observed[2].score.isFinite, "two observations are: \(observed[2].score)")

        // The downstream comparison. `isOutlier = score > threshold`, and every comparison
        // against `nan` is false — so warm-up flags nothing, which is the correct reading of
        // "not yet evaluable" rather than a claim that the value was checked and cleared.
        #expect(!observed[0].isOutlier, "declining to score is not a finding")
        #expect(!observed[1].isOutlier, "and still is not on the second observation")
    }

    /// IQR needs four, because below that the quartile indices address nothing meaningful.
    ///
    /// The fifth result is an exact arithmetic check, not a recalled number: the window is
    /// `[1, 2, 3, 4]`, so `q1 = sorted[4/4] = 2`, `q3 = sorted[12/4] = 4`, `iqr = 2`, and the
    /// deviation is `min(|50 - 2|, |50 - 4|) = 46`. The score is `46 / 2`.
    @Test("Detector_IQRWarmUpNeedsFourObservations")
    func detectorIQRWarmUpNeedsFourObservations() async throws {
        let observed = try await detections(
            [1.0, 2.0, 3.0, 4.0, 50.0],
            method: .iqr(multiplier: 1.5),
            window: 10
        )

        #expect(observed.count == 5, "one result per input")

        let warmUpAllDeclined: Bool = observed.prefix(4).allSatisfy { $0.score.isNaN }
        #expect(warmUpAllDeclined, "four results before four observations exist to sort")

        let expectedScore: Double = 46.0 / 2.0
        #expect(observed[4].score.isEqual(to: expectedScore), "measured: \(observed[4].score)")
        #expect(observed[4].isOutlier, "50 is far outside 4 + 1.5 * 2")
    }

    // MARK: - A contaminated window no longer reads as "perfectly normal"

    /// The z-score defect at the detector, with its control.
    ///
    /// With a `nan` in the window both the deviation and the standard deviation are `nan`, so
    /// `dispersion > 0` and `deviation > 0` were *both* false and the score fell out as `0` —
    /// a 1,000,000 reading reported as sitting exactly on its mean, and not flagged. It now
    /// declines. The clean control on the same shape of series flags it emphatically.
    @Test("Detector_ZScoreDeclinesRatherThanCallingASpikeNormal")
    func detectorZScoreDeclinesRatherThanCallingASpikeNormal() async throws {
        let contaminated = try await detections(
            Self.contaminatedWindow,
            method: .zScore(threshold: 3.0),
            window: 10
        )
        let contaminatedSpike = try #require(contaminated.last)
        #expect(contaminatedSpike.score.isNaN, "unmeasurable, and it says so")
        #expect(!contaminatedSpike.isOutlier, "not flagged, but no longer called normal either")

        let clean = try await detections(
            Self.cleanWindow,
            method: .zScore(threshold: 3.0),
            window: 10
        )
        let cleanSpike = try #require(clean.last)
        #expect(cleanSpike.score.isFinite, "the control measures it: \(cleanSpike.score)")
        #expect(cleanSpike.isOutlier, "and flags it")
    }

    /// The other half of Decision 1, one layer down: IQR and MAD sort only what can be ordered,
    /// so the same contaminated window that blinds the z-score leaves both of them working.
    ///
    /// This is what `sorted()` on a collection holding a `nan` costs. The sort is unspecified —
    /// `[3, 1, nan, 2, 5, 4]` comes back `[1, 3, nan, 2, 4, 5]`, with the *valid* elements out
    /// of order — so the quartiles and the median were read off a sequence that was not sorted,
    /// producing finite, plausible, wrong bounds rather than an obvious `nan`.
    @Test("Detector_IQRAndMADStillFlagTheSpikeThroughAContaminatedWindow")
    func detectorIQRAndMADStillFlagTheSpikeThroughAContaminatedWindow() async throws {
        let iqr = try await detections(
            Self.contaminatedWindow,
            method: .iqr(multiplier: 1.5),
            window: 10
        )
        let iqrSpike = try #require(iqr.last)
        #expect(iqrSpike.isOutlier, "nine clean readings are enough to place the bounds")
        #expect(iqrSpike.score.isFinite, "and to scale the deviation: \(iqrSpike.score)")

        let mad = try await detections(
            Self.contaminatedWindow,
            method: .mad(threshold: 3.0),
            window: 10
        )
        let madSpike = try #require(mad.last)
        #expect(madSpike.isOutlier, "the median survives one unorderable element")
        #expect(madSpike.score.isFinite, "measured: \(madSpike.score)")
    }

    /// The clean control for the pair above: nothing about filtering changed the ordinary case.
    @Test("Detector_IQRAndMADCleanControlFlagsTheSameSpike")
    func detectorIQRAndMADCleanControlFlagsTheSameSpike() async throws {
        let iqr = try await detections(
            Self.cleanWindow,
            method: .iqr(multiplier: 1.5),
            window: 10
        )
        let iqrSpike = try #require(iqr.last)
        #expect(iqrSpike.isOutlier)
        #expect(iqrSpike.score.isFinite, "measured: \(iqrSpike.score)")

        let mad = try await detections(
            Self.cleanWindow,
            method: .mad(threshold: 3.0),
            window: 10
        )
        let madSpike = try #require(mad.last)
        #expect(madSpike.isOutlier)
        #expect(madSpike.score.isFinite, "measured: \(madSpike.score)")
    }

    /// A clean, unremarkable stream must not start reporting anomalies. This is the control for
    /// the whole change: `.nan` warm-up scores must not leak into `isOutlier`, and the steady
    /// state after warm-up must stay quiet.
    @Test("Detector_SteadyStreamStillReportsNothing")
    func detectorSteadyStreamStillReportsNothing() async throws {
        let steady: [Double] = [5.0, 5.1, 4.9, 5.0, 5.05, 4.95, 5.0, 5.1, 4.9, 5.0]
        let observed = try await detections(
            steady,
            method: .zScore(threshold: 3.0),
            window: 10
        )

        let flagged: Int = observed.filter { $0.isOutlier }.count
        #expect(flagged == 0, "no anomaly in a steady stream")

        let evaluatedAfterWarmUp: Bool = observed.dropFirst(2).allSatisfy { $0.score.isFinite }
        #expect(evaluatedAfterWarmUp, "and every observation past warm-up carries a real score")
    }
}

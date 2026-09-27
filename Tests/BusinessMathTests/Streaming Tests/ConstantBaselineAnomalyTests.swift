//
//  ConstantBaselineAnomalyTests.swift
//  BusinessMathTests
//
//  Every outlier score here is `deviation / dispersion`, and each one substituted **0** when
//  the dispersion was zero:
//
//      let zScore = stdDev > 0 ? abs(value - mean) / stdDev : 0.0
//
//  Zero is not a neutral fallback for an anomaly score — it means "perfectly normal". And
//  because `isOutlier = score > threshold`, the z-score and MAD detectors stopped flagging
//  anything at all once the window went constant.
//
//  A constant window is not an exotic input. It is the ordinary state of a healthy metric:
//  an error gauge pinned at zero, a rate sitting at its cap, an idle queue. The first
//  departure from it is precisely the event these detectors exist to catch, and it was the
//  one departure they could not see.
//
//  Measured before the fix, feeding twenty 5.0s and then 1,000,000:
//
//  | method   | score | isOutlier |
//  |----------|-------|-----------|
//  | z-score  | 0.0   | false     |
//  | iqr      | 0.0   | true      |  flag right, severity wrong
//  | mad      | 0.0   | false     |
//
//  Against a *varied* baseline the same jump scored 1,224,738 — so the detectors were sound
//  in general, and specifically blind at zero dispersion.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Outlier detection against a constant baseline")
struct ConstantBaselineAnomalyTests {

    /// Twenty identical readings, then one that is nothing like them.
    private func constantThenSpike() -> AsyncStream<Double> {
        AsyncStream { continuation in
            for _ in 0..<20 { continuation.yield(5.0) }
            continuation.yield(1_000_000.0)
            continuation.finish()
        }
    }

    private func lastDetection(
        _ method: OutlierMethod
    ) async throws -> OutlierDetection? {
        var last: OutlierDetection?
        for try await detection in constantThenSpike().detectOutliers(method: method, window: 50) {
            last = detection
        }
        return last
    }

    /// The headline case. A z-score of zero said the spike sat exactly on the mean.
    @Test("ZScore_FlagsASpikeOffAConstantBaseline")
    func zScoreFlagsASpikeOffAConstantBaseline() async throws {
        let detection = try #require(await lastDetection(.zScore(threshold: 3.0)))
        #expect(detection.value.isEqual(to: 1_000_000.0), "the spike is the last reading")
        #expect(detection.isOutlier, "a million against a constant 5 is an outlier")
        #expect(detection.score.isInfinite, "zero dispersion makes any deviation unbounded")
    }

    /// MAD failed the same way, for the same reason.
    @Test("MAD_FlagsASpikeOffAConstantBaseline")
    func madFlagsASpikeOffAConstantBaseline() async throws {
        let detection = try #require(await lastDetection(.mad(threshold: 3.5)))
        #expect(detection.isOutlier)
        #expect(detection.score.isInfinite)
    }

    /// IQR already flagged the spike, because its verdict comes from the bounds rather than
    /// the score. Only the reported severity was wrong — which still matters to anything
    /// ranking alerts.
    @Test("IQR_ReportsTheSeverityItAlreadyActedOn")
    func iqrReportsTheSeverityItAlreadyActedOn() async throws {
        let detection = try #require(await lastDetection(.iqr(multiplier: 1.5)))
        #expect(detection.isOutlier, "this was already correct")
        #expect(detection.score.isInfinite, "the score was not")
    }

    /// A value matching the constant baseline is not an anomaly — the guard has to separate
    /// "no spread" from "no deviation", or the detectors would fire on every reading of a
    /// steady signal.
    @Test("ConstantBaseline_DoesNotFlagTheConstantItself")
    func constantBaselineDoesNotFlagTheConstantItself() async throws {
        let steady = AsyncStream<Double> { continuation in
            for _ in 0..<20 { continuation.yield(5.0) }
            continuation.finish()
        }
        var flagged = 0
        for try await detection in steady.detectOutliers(method: .zScore(threshold: 3.0), window: 50)
        where detection.isOutlier {
            flagged += 1
        }
        #expect(flagged == 0, "a flat signal is not twenty anomalies")
    }

    /// The composite score normalises with `min(1.0, total / count / 3.0)`, so an unbounded
    /// method score saturates at exactly 1.0 rather than escaping as an infinity.
    @Test("CompositeScore_SaturatesAtOne")
    func compositeScoreSaturatesAtOne() async throws {
        var last: CompositeAnomalyScore?
        for try await score in constantThenSpike()
            .compositeAnomalyScore(window: 50, methods: [.zScore, .iqr, .mad]) {
            last = score
        }
        let composite = try #require(last)
        #expect(composite.score.isEqual(to: 1.0), "maximum anomaly, still a finite 0–1 score")
    }

    /// Control: a baseline with real spread is unaffected, so the change is confined to the
    /// degenerate case.
    @Test("VariedBaseline_Unchanged")
    func variedBaselineUnchanged() async throws {
        let varied = AsyncStream<Double> { continuation in
            for value in [4.0, 5.0, 6.0, 5.0, 4.0, 6.0, 5.0, 5.0, 4.0, 6.0] { continuation.yield(value) }
            continuation.yield(1_000_000.0)
            continuation.finish()
        }
        var last: OutlierDetection?
        for try await detection in varied.detectOutliers(method: .zScore(threshold: 3.0), window: 50) {
            last = detection
        }
        let detection = try #require(last)
        #expect(detection.isOutlier)
        #expect(detection.score.isFinite, "a real standard deviation still gives a real score")
        #expect(detection.score > 1000, "and a very large one: \(detection.score)")
    }
}

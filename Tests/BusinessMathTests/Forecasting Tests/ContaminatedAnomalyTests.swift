//
//  ContaminatedAnomalyTests.swift
//  BusinessMathTests
//
//  From the fanned-out triage of `Sources/BusinessMath/Forecasting/`.
//
//  All three anomaly detectors answer `[]` — "this series contains no anomalies" — for a
//  series they cannot evaluate. The guards that do it are carefully reasoned, and their
//  reasoning is correct for the case they were written about:
//
//      // A MAD of zero means more than half the sample sits on a single value...
//      guard scale > T.zero else { return [] }
//
//      // A zero IQR means the middle half of the sample is a single value...
//      guard iqr > T.zero else { return [] }
//
//  `nan > 0` is false as well, so contamination comes out the same door as the degenerate
//  sample, wearing its justification.
//
//  Two things make this worse than the usual shape. `[]` is not a neutral answer from a
//  detector: it is a clean bill of health, and it is exactly what a caller polls for. And the
//  contaminated observation itself is dropped — `guard value < lowerFence || value > upperFence`
//  and `guard score > cutoff` are both false for a `nan` — so a detector whose entire job is to
//  report unusable points silently discards the one unusable point it was given.
//
//  `ModifiedZScoreAnomalyDetector` is the robust detector, the one a caller reaches for
//  precisely because the data is dirty.
//
//  The IQR detector additionally sorts with `values.sorted()` and hands the result to
//  `quantile(sorted:p:)`, which documents that callers must screen `nan` first — the same
//  caller-side violation already fixed in `ValueAtRisk` and `ConditionalValueAtRisk`.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Anomaly detection on a contaminated series")
struct ContaminatedAnomalyTests {

    private func series(_ values: [Double]) -> TimeSeries<Double> {
        TimeSeries(periods: (0..<values.count).map { Period.year(2000 + $0) }, values: values)
    }

    /// A spike the detector would otherwise catch, with one unusable reading alongside it.
    private let contaminated: [Double] = [10, 11, 12, 11, 10, 11, 250, .nan]
    private let clean: [Double] = [10, 11, 12, 11, 10, 11, 250, 11]

    /// The robust detector, on the kind of data it exists for.
    @Test("ModifiedZScore_ContaminatedSeries_IsNotCertifiedClean")
    func modifiedZScoreContaminatedSeriesIsNotCertifiedClean() {
        let found = ModifiedZScoreAnomalyDetector<Double>().detect(in: series(contaminated))
        #expect(!found.isEmpty,
                "reported no anomalies at all for a series containing a 250 and a NaN")
    }

    @Test("IQR_ContaminatedSeries_IsNotCertifiedClean")
    func iqrContaminatedSeriesIsNotCertifiedClean() {
        let found = IQRAnomalyDetector<Double>().detect(in: series(contaminated))
        #expect(!found.isEmpty, "reported no anomalies")
    }

    @Test("ZScore_ContaminatedSeries_IsNotCertifiedClean")
    func zScoreContaminatedSeriesIsNotCertifiedClean() {
        let found = ZScoreAnomalyDetector<Double>(windowSize: 4).detect(in: series(contaminated), threshold: 2.0)
        #expect(!found.isEmpty, "reported no anomalies")
    }

    /// The unusable reading is itself the thing a detector should report.
    @Test("Detectors_FlagTheUnusableObservation")
    func detectorsFlagTheUnusableObservation() {
        let found = ModifiedZScoreAnomalyDetector<Double>().detect(in: series(contaminated))
        let flaggedPeriods = found.map(\.period)
        #expect(flaggedPeriods.contains(Period.year(2007)),
                "2007 holds the NaN; flagged \(flaggedPeriods)")
    }

    // MARK: - Controls

    /// The clean series still reports its spike, so the fix has not simply made every series
    /// anomalous.
    @Test("CleanSeries_StillFindsTheSpike")
    func cleanSeriesStillFindsTheSpike() {
        let modified = ModifiedZScoreAnomalyDetector<Double>().detect(in: series(clean))
        #expect(modified.contains { $0.period == Period.year(2006) },
                "the 250 at 2006; got \(modified.map(\.period))")
        let iqr = IQRAnomalyDetector<Double>().detect(in: series(clean))
        #expect(iqr.contains { $0.period == Period.year(2006) }, "got \(iqr.map(\.period))")
    }

    /// A quiet series still reports nothing.
    @Test("QuietSeries_StillReportsNothing")
    func quietSeriesStillReportsNothing() {
        let quiet = series([10, 11, 10, 11, 10, 11, 10, 11])
        #expect(IQRAnomalyDetector<Double>().detect(in: quiet).isEmpty)
        #expect(ZScoreAnomalyDetector<Double>(windowSize: 4).detect(in: quiet, threshold: 3.0).isEmpty)
    }

    /// The genuinely degenerate sample the guards were written for keeps its documented
    /// empty answer — more than half the sample on one value is not a series of anomalies.
    @Test("DegenerateSample_StillReportsNothing")
    func degenerateSampleStillReportsNothing() {
        let flat = series([5, 5, 5, 5, 5, 5])
        #expect(ModifiedZScoreAnomalyDetector<Double>().detect(in: flat).isEmpty,
                "a MAD of zero is the case the guard was written for")
        #expect(IQRAnomalyDetector<Double>().detect(in: flat).isEmpty)
    }
}

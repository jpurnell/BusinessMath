//
//  NaNContaminatedSampleTests.swift
//  BusinessMathTests
//
//  `quantile(sorted:p:)` documents its own precondition:
//
//      - `nan` values *inside* `sorted` are not detected; sort order is undefined
//        in their presence, so screen them out before calling.
//
//  Its callers did not screen. `ValueAtRisk`, `ConditionalValueAtRisk` and
//  `SimulationResults` each did `values.sorted()` and handed the result straight in.
//
//  `Array.sorted()` is genuinely undefined on floating-point data containing a `nan`,
//  because `<` is false for every comparison involving one, so the predicate is not a strict
//  weak ordering. This is not theoretical. Measured:
//
//      [3, 1, nan, 2, 5, 4].sorted()  ==  [1, 3, nan, 2, 4, 5]
//
//  The *valid* elements come back out of order. A `nan` does not merely occupy a slot; it
//  corrupts the ordering of the real data around it, and every index-based statistic then
//  reads a mis-ordered array.
//
//  What made this silent rather than obvious is that the result depended on where the `nan`
//  happened to sit. Identical valid data, three placements:
//
//  | nan position | var95 before      |
//  |--------------|-------------------|
//  | first        | nan               |
//  | middle       | 1.450000000000000 |
//  | last         | 1.450000000000000 |
//
//  So a contaminated sample either announced itself or returned a confident, clean-looking
//  number, decided by an input ordering that is meaningless to a percentile.
//
//  `Percentiles(values:)` has always screened this correctly — it throws
//  `BusinessMathError.dataQuality` on any non-finite value. These are its siblings brought
//  into line; being non-throwing, they propagate `nan` instead, which is what `mean`,
//  `median`, `stdDev` and `Skewness` already do.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Risk statistics on a sample containing NaN")
struct NaNContaminatedSampleTests {

    private let clean: [Double] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

    /// Same valid data in all three; only the NaN's position differs.
    private var placements: [(String, [Double])] {
        [
            ("nan-first", [.nan, 1, 2, 3, 4, 6, 7, 8, 9, 10]),
            ("nan-middle", [1, 2, 3, 4, .nan, 6, 7, 8, 9, 10]),
            ("nan-last", [1, 2, 3, 4, 6, 7, 8, 9, 10, .nan]),
        ]
    }

    /// The headline: a contaminated sample must not yield a confident number.
    @Test("VaR_OnAContaminatedSample_IsNotANumber")
    func varOnAContaminatedSampleIsNotANumber() {
        for (name, sample) in placements {
            let result = ValueAtRisk.var95(values: sample)
            #expect(result.isNaN, "\(name) returned \(result)")
        }
    }

    @Test("CVaR_OnAContaminatedSample_IsNotANumber")
    func cvarOnAContaminatedSampleIsNotANumber() {
        for (name, sample) in placements {
            let result = ConditionalValueAtRisk.cvar95(values: sample)
            #expect(result.isNaN, "\(name) returned \(result)")
        }
    }

    /// `TailRisk` is derived from the two above, so it inherits the screen.
    @Test("TailRisk_OnAContaminatedSample_IsNotANumber")
    func tailRiskOnAContaminatedSampleIsNotANumber() {
        let contaminated: [Double] = [1, 2, 3, 4, .nan, 6, 7, 8, 9, 10]
        #expect(TailRisk.calculate(values: contaminated, confidenceLevel: 0.95).isNaN)
    }

    @Test("SimulationResults_OnAContaminatedSample_IsNotANumber")
    func simulationResultsOnAContaminatedSampleIsNotANumber() {
        let results = SimulationResults(values: [1, 2, 3, 4, .nan, 6, 7, 8, 9, 10])
        #expect(results.valueAtRisk(confidenceLevel: 0.95).isNaN)
        #expect(results.conditionalValueAtRisk(confidenceLevel: 0.95).isNaN)
    }

    /// The property that actually broke. Before the fix these three disagreed, which is what
    /// made the defect invisible: two of them looked fine.
    @Test("Answer_DoesNotDependOnWhereTheNaNSits")
    func answerDoesNotDependOnWhereTheNaNSits() {
        // Built outside the macro: `map` is `rethrows`, and a rethrowing call inside an
        // `#expect` message autoclosure does not compile.
        var report: [String] = []
        var allNaN = true
        for (name, sample) in placements {
            let result = ValueAtRisk.var95(values: sample)
            report.append("\(name)=\(result)")
            if !result.isNaN { allNaN = false }
        }
        let summary = report.joined(separator: ", ")
        #expect(allNaN, "the three placements disagreed: \(summary)")
    }

    /// The throwing sibling that was always right, pinned so it stays that way.
    @Test("Percentiles_RefusesNonFiniteInput")
    func percentilesRefusesNonFiniteInput() {
        let contaminated: [Double] = [1, 2, 3, 4, .nan, 6, 7, 8, 9, 10]
        #expect(throws: BusinessMathError.self) {
            try Percentiles(values: contaminated)
        }
    }

    // MARK: - Controls

    /// Clean data is untouched, to the exact value measured before the change.
    @Test("CleanSample_Unchanged")
    func cleanSampleUnchanged() {
        #expect(ValueAtRisk.var95(values: clean).isEqual(to: 1.4500000000000004))
        #expect(ConditionalValueAtRisk.cvar95(values: clean).isEqual(to: 1.0))
        let tail = TailRisk.calculate(values: clean, confidenceLevel: 0.95)
        #expect(tail.isEqual(to: 0.6896551724137929))
    }

    /// An empty sample keeps its documented answer of zero rather than becoming NaN — the
    /// screen must distinguish "no data" from "unusable data".
    @Test("EmptySample_StillReturnsZero")
    func emptySampleStillReturnsZero() {
        #expect(ValueAtRisk.var95(values: [Double]()).isEqual(to: 0.0))
        #expect(ConditionalValueAtRisk.cvar95(values: [Double]()).isEqual(to: 0.0))
    }
}

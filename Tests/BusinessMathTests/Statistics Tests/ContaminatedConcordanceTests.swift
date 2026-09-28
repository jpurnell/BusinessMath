//
//  ContaminatedConcordanceTests.swift
//  BusinessMathTests
//
//  From the fanned-out triage of `Sources/BusinessMath/Statistics/`.
//
//  Kendall's W is clamped with the shape §4 of the contract forbids:
//
//      w = max(T(0), min(T(1), (T(12) * s) / denomUncorrected))
//
//  `Swift.min(1, .nan)` returns **1**, so the clamp converts an uncomputable coefficient into
//  the *maximum* one. The correct sibling is in the same expression — the `else` arm two lines
//  down assigns `T.nan` for a degenerate denominator.
//
//  Measured on three judges ranking three items, one cell replaced by `nan`:
//
//      | statistic | clean  | contaminated |
//      | W         | 0.778  | 1.000        |
//      | chi-square| 4.667  | 6.000        |
//      | p         | 0.0970 | 0.0498       |
//
//  The contamination does not merely inflate the coefficient — it carries the p-value across
//  0.05. A result that was not significant becomes significant, with perfect agreement
//  reported, because one rating was unusable.
//
//  `friedmanChiSquare` fails the opposite way in the same result object. `max(T(0), chi2)`,
//  written for "slightly negative due to floating-point errors", returns **0** for a `nan` —
//  the exact centre of the null, "the treatments are indistinguishable". So one
//  `ConcordanceResult` asserts both perfect concordance *and* no treatment effect.
//
//  `kendallW(_:)` called directly returns **0** rather than the `nan` its own documentation
//  promises, through a guard written for "no agreement variance".
//
//  And `uniformCDF` has the two-arm fall-through: `x < 0` and `x < 1` are both false for a
//  `nan`, so control reaches the trailing `return T(1)` — P(X ≤ nan) = 1, the certainty end.
//  Its siblings `normalCDF` and `logNormalCDF` propagate correctly.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Concordance statistics on contaminated rankings")
struct ContaminatedConcordanceTests {

    private let clean: [[Double]] = [[1, 2, 3], [1, 2, 3], [2, 1, 3]]
    private let contaminated: [[Double]] = [[1, 2, 3], [1, .nan, 3], [2, 1, 3]]

    /// The headline: an unusable rating must not become perfect agreement.
    @Test("Concordance_ContaminatedRankings_AreUndefined")
    func concordanceContaminatedRankingsAreUndefined() throws {
        let result = try concordanceAnalysis(contaminated)
        #expect(result.w.isNaN, "W came back as \(result.w)")
        #expect(result.wCorrected.isNaN, "W-corrected came back as \(result.wCorrected)")
    }

    /// The consequence that matters: the verdict crossed alpha.
    @Test("Concordance_ContaminatedRankings_DoNotProduceASignificantResult")
    func concordanceContaminatedRankingsDoNotProduceASignificantResult() throws {
        let result = try concordanceAnalysis(contaminated)
        #expect(!(result.pValue < 0.05),
                "a contaminated set reported p = \(result.pValue), significant at the 5% level")
    }

    /// One result object was asserting two contradictory things.
    @Test("Concordance_AgreesWithItsOwnFriedmanStatistic")
    func concordanceAgreesWithItsOwnFriedmanStatistic() throws {
        let result = try concordanceAnalysis(contaminated)
        #expect(result.w.isNaN)
        #expect(result.friedman.isNaN,
                "W said perfect concordance while Friedman said no effect: \(result.friedman)")
    }

    /// The pre-reduced entry point takes the same input and must answer the same way.
    @Test("ConcordanceFromRankSums_ContaminatedSums_AreUndefined")
    func concordanceFromRankSumsContaminatedSumsAreUndefined() throws {
        let result = try concordanceAnalysisFromRankSums(rankSums: [4.0, .nan, 9.0], judges: 3, items: 3)
        #expect(result.w.isNaN, "got \(result.w)")
    }

    /// `kendallW` documents `nan` for unusable input and returned 0.
    @Test("KendallW_Direct_MatchesItsDocumentedContract")
    func kendallWDirectMatchesItsDocumentedContract() {
        #expect(kendallW(contaminated).isNaN, "got \(kendallW(contaminated))")
    }

    @Test("FriedmanChiSquare_ContaminatedRankings_AreUndefined")
    func friedmanChiSquareContaminatedRankingsAreUndefined() {
        #expect(friedmanChiSquare(contaminated).isNaN, "got \(friedmanChiSquare(contaminated))")
        let fromSums = friedmanChiSquareFromRankSums(rankSums: [4.0, .nan, 9.0], judges: 3, items: 3)
        #expect(fromSums.isNaN, "got \(fromSums)")
    }

    /// The two-arm fall-through, and the sibling that already behaves.
    @Test("UniformCDF_MatchesItsSiblings")
    func uniformCDFMatchesItsSiblings() {
        #expect(uniformCDF(x: Double.nan).isNaN, "got \(uniformCDF(x: Double.nan))")
        #expect(normalCDF(x: Double.nan).isNaN, "the sibling that was always right")
    }

    // MARK: - Controls

    /// Clean rankings are untouched, at the measured values.
    @Test("CleanRankings_Unchanged")
    func cleanRankingsUnchanged() throws {
        let result = try concordanceAnalysis(clean)
        #expect(abs(result.w - 0.7777777777777778) < 1e-12, "got \(result.w)")
        #expect(abs(result.chiSquare - 4.666666666666667) < 1e-12)
        #expect(abs(result.pValue - 0.09697196786440498) < 1e-12)
        #expect(abs(friedmanChiSquare(clean) - 4.666666666666664) < 1e-12)
    }

    /// The genuine zero-variance case must still report zero agreement, not undefined —
    /// identical rank sums really do mean no concordance to measure.
    @Test("IdenticalRankSums_StillReportNoAgreement")
    func identicalRankSumsStillReportNoAgreement() {
        let w = kendallWFromRankSums(rankSums: [6.0, 6.0, 6.0], judges: 3, items: 3)
        #expect(w.isEqual(to: 0.0), "got \(w)")
    }

    /// The ordinary CDF path is unchanged.
    @Test("UniformCDF_OrdinaryValues_Unchanged")
    func uniformCDFOrdinaryValuesUnchanged() {
        #expect(uniformCDF(x: 0.5).isEqual(to: 0.5))
        #expect(uniformCDF(x: -1.0).isEqual(to: 0.0))
        #expect(uniformCDF(x: 2.0).isEqual(to: 1.0))
    }
}

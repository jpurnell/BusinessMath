import Testing
import Foundation
@testable import BusinessMath

/// Tie-corrected concordance against SciPy and R.
///
/// ## Why an external reference
///
/// `concordanceAnalysis` corrects Kendall's W for tied ranks,
/// `W = 12S / (m²(n³ − n) − m·Σ(t³ − t))`, and reports `χ² = m(n − 1)·W` with its p-value.
/// Untied data gives the same answer under the corrected and the uncorrected formula, so
/// a test on clean rankings cannot tell a correct correction from a missing one. Every case
/// below except the control has ties within judges, and the expected values come from
/// outside the package:
///
/// - SciPy 1.18.1 `scipy.stats.friedmanchisquare(*items)` — tie-corrected Friedman χ² and
///   p-value; W is recovered as `χ² / (m(n − 1))`.
/// - R 4.6.2 `friedman.test(judges × items)` — tie-corrected Friedman χ² and p-value.
/// - R 4.6.2 `irr::kendall(t(matrix), correct = TRUE)` (irr 0.85) — tie-corrected W.
///
/// The generator is `Scripts/reference-fixtures/generate_concordance.py` (which calls
/// `generate_concordance.R`), reading the cases from `concordance_cases.txt`. The rankings
/// recorded here are SciPy's `rankdata` (average method) of those rows, so a raw-score
/// panel like the Paris-sized one is stored as the averaged ranks the tools themselves used.
///
/// ## Tolerance
///
/// SciPy and R disagree with each other in the last two or three digits (`7.399999999999996`
/// against `7.4`; p-values differ by a few parts in 10¹⁵), so equality would be testing which
/// tool's rounding we happened to copy. The statistics are compared at a relative 1e-12. The
/// p-value comes from this package's own chi-squared CDF rather than from either tool's, so
/// it is compared at a relative 1e-9 — still tight enough that using the uncorrected
/// statistic, which moves every tied case's p-value by percent, cannot pass.
@Suite("Concordance with ties matches SciPy and R")
struct ConcordanceReferenceTests {

    /// One reference case: the rankings and what each tool reported for them.
    ///
    /// A named type hoisted out of `@Test(arguments:)`, as in `KendallsTauTests`, because
    /// nested literal arrays inside the macro's arguments are the shape that defeats the
    /// type checker.
    struct ConcordanceCase: Sendable, CustomTestStringConvertible {
        let name: String
        let rankings: [[Double]]
        let sciPyChiSquare: Double
        let sciPyPValue: Double
        let rChiSquare: Double
        let rPValue: Double
        let rW: Double

        var testDescription: String { name }

        /// W implied by SciPy's statistic, `χ² / (m(n − 1))`.
        var sciPyW: Double {
            let judges: Double = Double(rankings.count)
            let itemsLessOne: Double = Double((rankings.first?.count ?? 1) - 1)
            return sciPyChiSquare / (judges * itemsLessOne)
        }
    }

    static let cases: [ConcordanceCase] = [
        ConcordanceCase(
            name: "no ties (control)",
            rankings: [[1, 2, 3, 4],
                       [2, 1, 3, 4],
                       [1, 3, 2, 4]],
            sciPyChiSquare: 7.0, sciPyPValue: 0.07189777249646513,
            rChiSquare: 7.0, rPValue: 0.07189777249646516, rW: 0.7777777777777778),
        ConcordanceCase(
            name: "one tied pair",
            rankings: [[1, 2, 3, 4, 5],
                       [1, 2.5, 2.5, 4, 5],
                       [2, 1, 3, 5, 4],
                       [1, 3, 2, 4, 5]],
            sciPyChiSquare: 13.924050632911392, sciPyPValue: 0.007541441670747898,
            rChiSquare: 13.924050632911392, rPValue: 0.007541441670747897, rW: 0.870253164556962),
        ConcordanceCase(
            name: "three-way tie",
            rankings: [[1, 2, 3, 4, 5, 6],
                       [1, 3, 3, 3, 5, 6],
                       [2, 1, 3, 4, 6, 5],
                       [1, 2, 4, 3, 5, 6],
                       [2, 1, 3, 5, 4, 6]],
            sciPyChiSquare: 21.95906432748538, sciPyPValue: 0.000533063503109855,
            rChiSquare: 21.959064327485383, rPValue: 0.0005330635031098541, rW: 0.8783625730994152),
        ConcordanceCase(
            name: "one judge ties everything",
            rankings: [[1, 2, 3, 4],
                       [2, 1, 3, 4],
                       [1, 2, 4, 3],
                       [2.5, 2.5, 2.5, 2.5]],
            sciPyChiSquare: 7.399999999999996, sciPyPValue: 0.0601843238717349,
            rChiSquare: 7.4, rPValue: 0.06018432387173478, rW: 0.6166666666666667),
        ConcordanceCase(
            name: "ties in every judge",
            rankings: [[1.5, 1.5, 3, 4, 5.5, 5.5, 7, 8],
                       [1, 2, 3.5, 3.5, 5, 6, 7.5, 7.5],
                       [2, 2, 2, 4, 5, 6, 7, 8],
                       [1.5, 1.5, 3.5, 3.5, 5.5, 5.5, 7.5, 7.5],
                       [1, 3, 3, 3, 6, 6, 6, 8],
                       [2, 1, 3, 4, 5, 7, 7, 7]],
            sciPyChiSquare: 40.19166666666666, sciPyPValue: 1.156804469240115e-06,
            rChiSquare: 40.19166666666666, rPValue: 1.1568044692401153e-06, rW: 0.9569444444444445),
        ConcordanceCase(
            name: "strong agreement with ties",
            rankings: [[1, 2, 3, 4, 5, 6, 7],
                       [1, 2, 3, 4, 5, 6.5, 6.5],
                       [1.5, 1.5, 3, 4, 5, 6, 7],
                       [1, 2, 3, 5, 4, 6, 7],
                       [1, 2, 3.5, 3.5, 5, 6, 7],
                       [2, 1, 3, 4, 5, 6, 7],
                       [1, 2, 3, 4, 6, 5, 7],
                       [1, 2, 3, 4, 5, 6, 7]],
            sciPyChiSquare: 46.530337078651684, sciPyPValue: 2.3213428081401036e-08,
            rChiSquare: 46.530337078651684, rPValue: 2.3213428081401056e-08, rW: 0.9693820224719101),
        ConcordanceCase(
            name: "Paris-sized panel, 11 judges x 10 wines, integer scores",
            rankings: [[10, 3, 7, 8.5, 5.5, 8.5, 3, 5.5, 3, 1],
                       [5.5, 8, 10, 8, 4, 8, 1, 5.5, 2.5, 2.5],
                       [6, 6, 6, 9.5, 9.5, 6, 6, 3, 1.5, 1.5],
                       [9.5, 9.5, 7.5, 7.5, 5.5, 5.5, 4, 1, 3, 2],
                       [10, 9, 4, 6, 2, 7.5, 4, 4, 1, 7.5],
                       [9, 9, 6, 9, 2.5, 4.5, 4.5, 2.5, 7, 1],
                       [8, 9.5, 9.5, 6, 7, 5, 3.5, 3.5, 1.5, 1.5],
                       [9, 7, 10, 2, 5, 2, 7, 7, 4, 2],
                       [9, 7.5, 10, 5.5, 3, 1, 3, 3, 7.5, 5.5],
                       [10, 4, 9, 8, 2.5, 1, 2.5, 6, 6, 6],
                       [10, 8.5, 7, 1.5, 4, 8.5, 4, 4, 1.5, 6]],
            sciPyChiSquare: 43.317998849913764, sciPyPValue: 1.884365771354225e-06,
            rChiSquare: 43.31799884991375, rPValue: 1.8843657713542344e-06, rW: 0.43755554393852264)
    ]

    /// `|actual − expected| ≤ tolerance · |expected|`.
    private static func relativeGap(_ actual: Double, _ expected: Double) -> Double {
        let gap: Double = abs(actual - expected)
        let scale: Double = abs(expected)
        return scale > 0 ? gap / scale : gap
    }

    @Test("Tie-corrected W matches SciPy and irr::kendall", arguments: ConcordanceReferenceTests.cases)
    func correctedW(testCase: ConcordanceCase) throws {
        let result = try concordanceAnalysis(testCase.rankings)
        let sciPyGap: Double = Self.relativeGap(result.wCorrected, testCase.sciPyW)
        let rGap: Double = Self.relativeGap(result.wCorrected, testCase.rW)
        #expect(sciPyGap < 1e-12, "SciPy W \(testCase.sciPyW), this \(result.wCorrected)")
        #expect(rGap < 1e-12, "irr W \(testCase.rW), this \(result.wCorrected)")
    }

    @Test("Chi-squared matches the tie-corrected Friedman statistic", arguments: ConcordanceReferenceTests.cases)
    func chiSquare(testCase: ConcordanceCase) throws {
        let result = try concordanceAnalysis(testCase.rankings)
        let sciPyGap: Double = Self.relativeGap(result.chiSquare, testCase.sciPyChiSquare)
        let rGap: Double = Self.relativeGap(result.chiSquare, testCase.rChiSquare)
        #expect(sciPyGap < 1e-12, "SciPy χ² \(testCase.sciPyChiSquare), this \(result.chiSquare)")
        #expect(rGap < 1e-12, "R χ² \(testCase.rChiSquare), this \(result.chiSquare)")
    }

    @Test("P-value matches SciPy and R", arguments: ConcordanceReferenceTests.cases)
    func pValue(testCase: ConcordanceCase) throws {
        let result = try concordanceAnalysis(testCase.rankings)
        let sciPyGap: Double = Self.relativeGap(result.pValue, testCase.sciPyPValue)
        let rGap: Double = Self.relativeGap(result.pValue, testCase.rPValue)
        #expect(sciPyGap < 1e-9, "SciPy p \(testCase.sciPyPValue), this \(result.pValue)")
        #expect(rGap < 1e-9, "R p \(testCase.rPValue), this \(result.pValue)")
    }
}

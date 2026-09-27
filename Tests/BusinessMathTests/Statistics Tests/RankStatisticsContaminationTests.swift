//
//  RankStatisticsContaminationTests.swift
//  BusinessMathTests
//
//  The adversarial sweep reached the rank-based statistics, and `spearmansRho` did not return
//  a wrong number — it **crashed**:
//
//      Swift/ContiguousArrayBuffer.swift:695: Fatal error: Index out of range
//
//  The cause is in `Array.rank()`:
//
//      guard let index = sorted.firstIndex(of: self[i]) else { continue }
//      rankArray.append(Element(index + 1))
//
//  `firstIndex(of:)` compares with `==`, and `nan == nan` is false, so the lookup returns
//  `nil` for a `nan` element, `continue` skips the append, and **`rank()` returns an array
//  shorter than its input**. Every caller assumes one rank per observation;
//  `spearmansRho` then indexes `independentRank[i]` past the end and traps.
//
//  This is the same root fact as the two previous findings, in a third disguise. All of these
//  are false: `nan > 0`, `nan < x`, `nan == nan`. The first made a guard fire, the second made
//  `sorted()` undefined, and this one makes an element silently vanish from a result.
//
//  Measured on the same contaminated pair:
//
//      spearmansRho  -> Fatal error: Index out of range
//      kendallsTau   -> 0.8894991799933214      (a confident coefficient)
//      correlationCoefficient -> throws "one or both variables have zero variance"
//
//  The third is safe but misdiagnosed: the data has no zero-variance column, it has a `nan`.
//  `nan > T.ulpOfOne` is false, so the zero-variance guard caught the contamination and
//  reported it as the thing it was written for, sending anyone debugging it to look for a
//  constant column that does not exist.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Rank statistics on contaminated data")
struct RankStatisticsContaminationTests {

    private let clean: [Double] = [1, 2, 3, 4, 5, 6, 7, 8]
    private let other: [Double] = [2, 4, 5, 4, 5, 7, 8, 9]
    private var contaminated: [Double] {
        var v = clean
        v[3] = .nan
        return v
    }

    // MARK: - rank()

    /// The invariant every caller relies on: one rank per observation.
    @Test("Rank_PreservesLength")
    func rankPreservesLength() {
        #expect(contaminated.rank().count == contaminated.count,
                "rank() returned \(contaminated.rank().count) ranks for \(contaminated.count) values")
        #expect(contaminated.reverseRank().count == contaminated.count)
    }

    /// A NaN has no rank, and says so, rather than vanishing.
    @Test("Rank_UnrankableElementIsNotANumber")
    func rankUnrankableElementIsNotANumber() {
        let ranks = contaminated.rank()
        #expect(ranks.count == contaminated.count)
        #expect(ranks[3].isNaN, "position 3 held the NaN; got \(ranks[3])")
        #expect(ranks[0].isFinite, "the other positions still rank normally")
    }

    /// Control: clean data ranks exactly as before.
    @Test("Rank_CleanData_Unchanged")
    func rankCleanDataUnchanged() {
        let ranks = clean.rank()
        let reverse = clean.reverseRank()
        #expect(ranks.count == clean.count)
        #expect(reverse.count == clean.count)
        // rank() is descending by magnitude: the largest value takes rank 1.
        #expect(ranks[7].isEqual(to: 1.0), "8 is the largest; got \(ranks[7])")
        #expect(ranks[0].isEqual(to: 8.0), "1 is the smallest; got \(ranks[0])")
        #expect(reverse[0].isEqual(to: 1.0), "reverseRank inverts that")
    }

    // MARK: - the rank correlations

    /// The crash.
    @Test("SpearmansRho_DoesNotTrapOnContaminatedData")
    func spearmansRhoDoesNotTrapOnContaminatedData() {
        #expect(throws: BusinessMathError.self) {
            try spearmansRho(contaminated, vs: other)
        }
    }

    /// The silent one. A correlation coefficient is a claim about the data.
    @Test("KendallsTau_RefusesContaminatedData")
    func kendallsTauRefusesContaminatedData() {
        #expect(throws: BusinessMathError.self) {
            try kendallsTau(contaminated, vs: other)
        }
        #expect(throws: BusinessMathError.self) {
            try kendallsTau(clean, vs: contaminated)
        }
    }

    /// Controls: both still compute normally, at the values measured before the change.
    @Test("RankCorrelations_CleanData_Unchanged")
    func rankCorrelationsCleanDataUnchanged() throws {
        // Measured, not recalled. Note the coincidence that made the defect invisible: the
        // contaminated pair returned this *same* value, 0.8894991799933214 — feeding a NaN
        // changed the answer not at all.
        let tau = try kendallsTau(clean, vs: other)
        #expect(abs(tau - 0.8894991799933214) < 1e-12, "got \(tau)")
        let rho = try spearmansRho(clean, vs: other)
        #expect(abs(rho - 0.9398272507881658) < 1e-12, "got \(rho)")
    }

    // MARK: - the misdiagnosis

    /// Safe but wrong explanation: the guard that caught this was written for zero variance.
    @Test("CorrelationCoefficient_ReportsContaminationNotZeroVariance")
    func correlationCoefficientReportsContaminationNotZeroVariance() {
        do {
            _ = try correlationCoefficient(contaminated, other)
            Issue.record("expected a throw")
        } catch let error as BusinessMathError {
            let text = "\(error)"
            #expect(!text.contains("zero variance"),
                    "a NaN is not a zero-variance column: \(text)")
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    /// And a genuine zero-variance column must still say so.
    @Test("CorrelationCoefficient_StillDetectsZeroVariance")
    func correlationCoefficientStillDetectsZeroVariance() {
        let constant: [Double] = [3, 3, 3, 3, 3, 3, 3, 3]
        do {
            _ = try correlationCoefficient(constant, other)
            Issue.record("expected a throw")
        } catch let error as BusinessMathError {
            #expect("\(error)".contains("zero variance"), "got \(error)")
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }
}

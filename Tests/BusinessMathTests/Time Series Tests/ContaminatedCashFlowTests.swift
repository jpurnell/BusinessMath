//
//  ContaminatedCashFlowTests.swift
//  BusinessMathTests
//
//  The adversarial sweep reached the time-value-of-money family, where a wrong number is a
//  wrong investment decision. Feeding one `nan` into an otherwise conventional project
//  (-1000, then 300/400/500/600):
//
//  | function            | clean    | contaminated |
//  | npv                 | 388.771  | nan          |
//  | npvExcel            | 353.428  | nan          |
//  | irr                 | 0.248883 | throws       |
//  | profitabilityIndex  | 1.38877  | **1.05819**  |
//  | mirr                | 0.201392 | **0.121414** |
//
//  The first three are honest. The last two return confident decision numbers, and the cause
//  is a shape that is neither a guard nor a sort:
//
//      if flow > T.zero        { pvPositive += presentValue }
//      else if flow < T.zero   { pvNegative += presentValue }
//
//  A `nan` is neither `> 0` nor `< 0`, so **both arms are skipped** and that period is
//  silently dropped from the calculation. An ordinary two-way classification, and `nan`
//  belongs to neither class.
//
//  It is not even the answer for the shortened series: dropping that period outright gives a
//  profitability index of 1.1367, against the 1.0582 reported here, because the remaining
//  periods keep their original discount exponents. The number answers a question nobody asked.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Time-value-of-money with a contaminated cash flow")
struct ContaminatedCashFlowTests {

    private let clean: [Double] = [-1000, 300, 400, 500, 600]
    private var contaminated: [Double] {
        var v = clean
        v[2] = .nan
        return v
    }

    /// The sibling that was always right, pinned so it stays that way.
    @Test("NPV_AlreadyPropagated")
    func npvAlreadyPropagated() {
        #expect(npv(discountRate: 0.1, cashFlows: contaminated).isNaN)
        #expect(npvExcel(rate: 0.1, cashFlows: contaminated).isNaN)
    }

    /// A profitability index is compared against 1.0 to accept or reject a project.
    @Test("ProfitabilityIndex_ContaminatedFlow_IsUndefined")
    func profitabilityIndexContaminatedFlowIsUndefined() {
        let result = profitabilityIndex(rate: 0.1, cashFlows: contaminated)
        #expect(result.isNaN, "returned \(result), which reads as an acceptable project")
    }

    /// MIRR already throws for cash flows it cannot use; this is one of them.
    @Test("MIRR_ContaminatedFlow_IsRefused")
    func mirrContaminatedFlowIsRefused() {
        let bad = contaminated
        #expect(throws: BusinessMathError.self) {
            try mirr(cashFlows: bad, financeRate: 0.1, reinvestmentRate: 0.12)
        }
    }

    /// Controls: the clean project is untouched, at the measured values.
    @Test("CleanProject_Unchanged")
    func cleanProjectUnchanged() throws {
        let pi = profitabilityIndex(rate: 0.1, cashFlows: clean)
        #expect(abs(pi - 1.3887712587937981) < 1e-12, "got \(pi)")
        let m = try mirr(cashFlows: clean, financeRate: 0.1, reinvestmentRate: 0.12)
        #expect(abs(m - 0.20139202041968263) < 1e-12, "got \(m)")
        #expect(abs(npv(discountRate: 0.1, cashFlows: clean) - 388.7712587937982) < 1e-9)
    }

    /// A project with no outflow at all still reports an unbounded index rather than a
    /// fabricated one — the behaviour established when the literal `T(1000000)` was removed.
    @Test("ProfitabilityIndex_NoOutflow_StillUnbounded")
    func profitabilityIndexNoOutflowStillUnbounded() {
        let allInflows: [Double] = [100, 200, 300]
        #expect(profitabilityIndex(rate: 0.1, cashFlows: allInflows).isEqual(to: .infinity))
    }

    /// `paybackPeriod` and its discounted form return `Int?`, which has no channel to
    /// distinguish "never pays back" from "cannot be computed" — a `nan` makes
    /// `cumulative >= 0` false forever, so both answer `nil`. That limit is now stated in
    /// their documentation rather than left for a caller to discover, and this pins it.
    @Test("PaybackPeriod_ContaminatedFlow_IsDocumentedAsNil")
    func paybackPeriodContaminatedFlowIsDocumentedAsNil() {
        #expect(paybackPeriod(cashFlows: clean) == 3, "the clean project pays back in period 3")
        #expect(paybackPeriod(cashFlows: contaminated) == nil)
        #expect(discountedPaybackPeriod(rate: 0.1, cashFlows: clean) == 4)
        #expect(discountedPaybackPeriod(rate: 0.1, cashFlows: contaminated) == nil)
    }
}

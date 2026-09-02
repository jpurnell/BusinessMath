//
//  FormulaTVMFunctionTests.swift
//  BusinessMath
//

import Testing
import Foundation
@testable import BusinessMath

/// The time-value-of-money names, bound to the canonical implementations.
///
/// Two shapes live here, and the difference matters:
///
/// - **Period-wise** — `PMT`, `IPMT`, `PPMT`, `FV`, `PV` take scalars and give a
///   scalar, so each period computes its own answer from its own arguments. This
///   is a formula filled across a row.
/// - **Aggregating** — `NPV` and `IRR` consume a whole series and give one number,
///   which is then constant across the periods it was computed from. This is a
///   formula pointed at a range.
@Suite("Formula TVM Functions")
struct FormulaTVMFunctionTests {

    private let years = [
        Period.year(2024), Period.year(2025), Period.year(2026), Period.year(2027)
    ]

    private func evaluator(_ accounts: [String: [Double]]) -> FormulaEvaluator<Double> {
        FormulaEvaluator(accounts: accounts.mapValues {
            TimeSeries(periods: Array(years.prefix($0.count)), values: $0)
        })
    }

    // MARK: - NPV binds to Excel's definition

    @Test("NPV discounts the first cash flow, as Excel does")
    func npvUsesExcelDiscounting() throws {
        // Excel discounts every flow by at least one period, so a single flow of
        // 110 at 10% is worth 100 today — not 110.
        let result = try evaluator(["flows": [110]]).evaluate("NPV(0.1, flows)")
        #expect(abs(result.valuesArray[0] - 100) < 1e-9)
    }

    @Test("NPV in a formula is not the textbook NPV, and the two differ")
    func npvIsNotTextbookNPV() throws {
        // The trap this binding exists to avoid. `npv()` leaves the first flow
        // undiscounted; `npvExcel()` discounts it. A formula string came from a
        // sheet, so it must mean Excel's. Pinned as a difference so the binding
        // cannot be quietly changed.
        let flows = [100.0, 200.0, 300.0]
        let textbook = npv(discountRate: 0.1, cashFlows: flows)
        let excel = npvExcel(rate: 0.1, cashFlows: flows)
        #expect(abs(textbook - excel) > 1)

        let fromFormula = try evaluator(["flows": flows]).evaluate("NPV(0.1, flows)")
        #expect(abs(fromFormula.valuesArray[0] - excel) < 1e-9)
        #expect(abs(fromFormula.valuesArray[0] - textbook) > 1)
    }

    @Test("An aggregate is constant across the periods it came from")
    func aggregateIsConstant() throws {
        let result = try evaluator(["flows": [100, 200, 300]]).evaluate("NPV(0.1, flows)")
        #expect(result.count == 3)
        #expect(Set(result.valuesArray).count == 1, "one number, repeated")
    }

    // MARK: - IRR

    @Test("IRR solves the rate that zeroes the flows")
    func irrSolves() throws {
        // −100 now, then 60 and 60: the rate is about 13.07%.
        let result = try evaluator(["flows": [-100, 60, 60]]).evaluate("IRR(flows)")
        #expect(abs(result.valuesArray[0] - 0.1306623) < 1e-5)
    }

    @Test("IRR reports a failure to converge rather than a plausible number")
    func irrThatCannotConvergeThrows() {
        // All-positive flows have no root. A returned zero here would be a rate,
        // and a wrong one.
        #expect(throws: (any Error).self) {
            _ = try evaluator(["flows": [100, 200, 300]]).evaluate("IRR(flows)")
        }
    }

    // MARK: - Period-wise TVM

    @Test("PMT is negative, as Excel returns it")
    func pmtUsesExcelsSign() throws {
        // 10,000 over 10 periods at 5% is a payment of about 1,295.05, and Excel
        // returns it negative: it is money leaving. The canonical `payment()`
        // returns the magnitude, so the binding negates. Same number, opposite
        // sign — a formula that summed these would be wrong and look right.
        let result = try evaluator(["rate": [0.05], "n": [10], "pv": [10_000]])
            .evaluate("PMT(rate, n, pv)")
        #expect(abs(result.valuesArray[0] - -1295.0457) < 1e-3)
        #expect(result.valuesArray[0] < 0)
    }

    @Test("PMT follows its rate when the rate varies by period")
    func pmtFollowsAVaryingRate() throws {
        let result = try evaluator(["rate": [0.05, 0.10], "n": [10, 10], "pv": [10_000, 10_000]])
            .evaluate("PMT(rate, n, pv)")
        #expect(result.valuesArray[0] != result.valuesArray[1])
    }

    @Test("IPMT and PPMT split a payment into interest and principal")
    func ipmtAndPpmtSplitThePayment() throws {
        let accounts = ["rate": [0.05], "per": [1], "n": [10], "pv": [10_000]]
        let interest = try evaluator(accounts).evaluate("IPMT(rate, per, n, pv)")
        let principal = try evaluator(accounts).evaluate("PPMT(rate, per, n, pv)")
        let payment = try evaluator(["rate": [0.05], "n": [10], "pv": [10_000]])
            .evaluate("PMT(rate, n, pv)")

        #expect(
            abs((interest.valuesArray[0] + principal.valuesArray[0]) - payment.valuesArray[0])
                < 1e-6,
            "interest plus principal is the whole payment"
        )
    }

    @Test("FV is not registered, because ours is not Excel's FV")
    func fvIsNotRegistered() {
        // Excel's `FV(rate, nper, pmt, [pv])` is an annuity's future value; this
        // library's `futureValue(presentValue:rate:periods:)` grows a lump sum.
        // Same name, different function, so the name stays unbound rather than
        // silently meaning something else than the sheet it came from.
        #expect(throws: FormulaError.unknownFunction("FV")) {
            _ = try evaluator(["pv": [100]]).evaluate("FV(pv, 0.1, 2)")
        }
    }

    // MARK: - Arity

    @Test("The TVM names state their argument counts")
    func tvmArity() {
        #expect(throws: FormulaError.self) {
            _ = try evaluator(["a": [1]]).evaluate("NPV(0.1)")
        }
        #expect(throws: FormulaError.self) {
            _ = try evaluator(["a": [1]]).evaluate("PMT(0.1, 10)")
        }
    }
}

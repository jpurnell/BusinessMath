//
//  FormulaConditionalTests.swift
//  BusinessMath
//

import Testing
import Foundation
@testable import BusinessMath

/// Comparisons and `IF`.
///
/// The function that matters: counted across two real workbooks, `IF` is the most
/// called name by a wide margin. Everything here is period-wise, and `TRUE`/`FALSE`
/// are 1 and 0, which is both Excel's arithmetic coercion and what the downstream
/// `NodeFormula` layer already does — the two must agree or a model changes meaning
/// on its way between them.
@Suite("Formula Conditionals")
struct FormulaConditionalTests {

    private let months = [
        Period.month(year: 2026, month: 1),
        Period.month(year: 2026, month: 2),
        Period.month(year: 2026, month: 3)
    ]

    private func evaluator(
        _ accounts: [String: [Double]] = [
            "revenue": [100, 200, 300],
            "target": [150, 150, 150],
            "zero": [0, 0, 0]
        ]
    ) -> FormulaEvaluator<Double> {
        FormulaEvaluator(accounts: accounts.mapValues {
            TimeSeries(periods: Array(months.prefix($0.count)), values: $0)
        })
    }

    // MARK: - Comparison Operators

    @Test("Greater than yields 1 and 0 in each period")
    func greaterThan() throws {
        #expect(try evaluator().evaluate("revenue > target").valuesArray == [0, 1, 1])
    }

    @Test("Less than yields 1 and 0 in each period")
    func lessThan() throws {
        #expect(try evaluator().evaluate("revenue < target").valuesArray == [1, 0, 0])
    }

    @Test("The inclusive comparisons include equality")
    func inclusiveComparisons() throws {
        #expect(try evaluator().evaluate("revenue >= 200").valuesArray == [0, 1, 1])
        #expect(try evaluator().evaluate("revenue <= 200").valuesArray == [1, 1, 0])
    }

    @Test("Equality uses a single equals, as a sheet writes it")
    func equality() throws {
        #expect(try evaluator().evaluate("revenue = 200").valuesArray == [0, 1, 0])
    }

    @Test("Inequality is angle brackets, as a sheet writes it")
    func inequality() throws {
        #expect(try evaluator().evaluate("revenue <> 200").valuesArray == [1, 0, 1])
    }

    @Test("A comparison binds looser than arithmetic")
    func comparisonPrecedence() throws {
        // `revenue - 50 > 100` must read as `(revenue - 50) > 100`, not
        // `revenue - (50 > 100)`.
        #expect(try evaluator().evaluate("revenue - 50 > 100").valuesArray == [0, 1, 1])
    }

    @Test("A comparison result is a number and composes as one")
    func comparisonIsANumber() throws {
        // Excel coerces TRUE to 1 in arithmetic, so this is 100 times the flag.
        #expect(try evaluator().evaluate("(revenue > target) * 100").valuesArray == [0, 100, 100])
    }

    // MARK: - IF

    @Test("IF selects period by period")
    func ifIsPeriodWise() throws {
        let result = try evaluator().evaluate("IF(revenue > target, revenue, 0)")
        #expect(result.valuesArray == [0, 200, 300])
    }

    @Test("IF takes exactly three arguments")
    func ifArity() {
        #expect(throws: FormulaError.self) {
            _ = try evaluator().evaluate("IF(revenue > target, revenue)")
        }
    }

    @Test("IF treats any non-zero condition as true, as Excel does")
    func ifTruthiness() throws {
        #expect(try evaluator().evaluate("IF(1, 10, 20)").valuesArray == [10, 10, 10])
        #expect(try evaluator().evaluate("IF(0, 10, 20)").valuesArray == [20, 20, 20])
        #expect(try evaluator().evaluate("IF(-3, 10, 20)").valuesArray == [10, 10, 10])
    }

    @Test("IF guards a division that would otherwise be undefined")
    func ifGuardsDivision() throws {
        // The idiom this exists for. The untaken branch is still evaluated, which
        // is safe because it has no effects — the infinity it produces is simply
        // never selected.
        let result = try evaluator().evaluate("IF(zero = 0, 0, revenue / zero)")
        #expect(result.valuesArray == [0, 0, 0])
    }

    @Test("IF nests")
    func ifNests() throws {
        let result = try evaluator()
            .evaluate("IF(revenue > 250, 3, IF(revenue > 150, 2, 1))")
        #expect(result.valuesArray == [1, 2, 3])
    }

    @Test("A cash sweep becomes expressible")
    func cashSweep() throws {
        // The worked example the whole grammar extension is for: pay down the
        // smaller of what is available and what is outstanding, never below zero.
        let result = try evaluator(["available": [100, -20, 500], "outstanding": [300, 300, 300]])
            .evaluate("MIN(MAX(available, 0), outstanding)")
        #expect(result.valuesArray == [100, 0, 300])
    }

    // MARK: - Alignment

    @Test("IF over series of different lengths keeps the shared periods")
    func ifIntersectsPeriods() throws {
        let result = try evaluator(["long": [1, 2, 3], "short": [10, 20]])
            .evaluate("IF(long > 1, long, short)")
        #expect(result.valuesArray == [10, 2])
    }
}

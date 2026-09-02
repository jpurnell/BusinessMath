//
//  FormulaLogicalFunctionTests.swift
//  BusinessMath
//

import Testing
import Foundation
@testable import BusinessMath

/// `AVERAGE`, `ROUND`, `AND`, `OR`, `NOT`.
///
/// Registered ahead of the financial tranche because a census of two real
/// workbooks put these in them and the financial names in neither.
@Suite("Formula Logical Functions")
struct FormulaLogicalFunctionTests {

    private let months = [
        Period.month(year: 2026, month: 1),
        Period.month(year: 2026, month: 2),
        Period.month(year: 2026, month: 3)
    ]

    private func evaluator(
        _ accounts: [String: [Double]] = [
            "a": [10, 20, 30],
            "b": [20, 20, 60],
            "flag": [1, 0, 1],
            "other": [1, 1, 0]
        ]
    ) -> FormulaEvaluator<Double> {
        FormulaEvaluator(accounts: accounts.mapValues {
            TimeSeries(periods: Array(months.prefix($0.count)), values: $0)
        })
    }

    // MARK: - AVERAGE

    @Test("AVERAGE is the mean of its arguments in each period")
    func averageIsPeriodWise() throws {
        #expect(try evaluator().evaluate("AVERAGE(a, b)").valuesArray == [15, 20, 45])
    }

    @Test("AVERAGE takes any number of arguments")
    func averageIsVariadic() throws {
        #expect(try evaluator().evaluate("AVERAGE(a)").valuesArray == [10, 20, 30])
        #expect(try evaluator().evaluate("AVERAGE(a, b, 30)").valuesArray == [20, 70.0 / 3, 40])
    }

    // MARK: - ROUND

    @Test("ROUND goes half away from zero, as Excel does")
    func roundIsHalfAwayFromZero() throws {
        // Not banker's rounding, which a naive implementation lands on and which
        // would send 2.5 to 2 and disagree with every sheet.
        let series = try evaluator(["x": [2.5, 3.5, -2.5]]).evaluate("ROUND(x, 0)")
        #expect(series.valuesArray == [3, 4, -3])
    }

    @Test("ROUND keeps the requested number of decimals")
    func roundToDecimals() throws {
        let series = try evaluator(["x": [3.14159, 2.71828, 1.005]]).evaluate("ROUND(x, 2)")
        // Computed values with rounding expected: 3.14 has no exact binary form,
        // and scaling by 100 and back cannot be assumed to land on the same bits
        // as the literal.
        #expect(abs(series.valuesArray[0] - 3.14) < 1e-12)
        #expect(abs(series.valuesArray[1] - 2.72) < 1e-12)
    }

    @Test("ROUND accepts negative digits and rounds to tens or hundreds")
    func roundNegativeDigits() throws {
        // `ROUND(1234, -2)` is 1200 in Excel.
        let series = try evaluator(["x": [1234, 1250, 1949]]).evaluate("ROUND(x, -2)")
        #expect(series.valuesArray == [1200, 1300, 1900])
    }

    @Test("ROUND takes exactly two arguments")
    func roundArity() {
        #expect(throws: FormulaError.self) {
            _ = try evaluator().evaluate("ROUND(a)")
        }
    }

    // MARK: - AND, OR, NOT

    @Test("AND is true only when every argument is")
    func andRequiresAll() throws {
        #expect(try evaluator().evaluate("AND(flag, other)").valuesArray == [1, 0, 0])
    }

    @Test("OR is true when any argument is")
    func orRequiresAny() throws {
        #expect(try evaluator().evaluate("OR(flag, other)").valuesArray == [1, 1, 1])
    }

    @Test("NOT inverts the truthiness of its argument")
    func notInverts() throws {
        #expect(try evaluator().evaluate("NOT(flag)").valuesArray == [0, 1, 0])
    }

    @Test("NOT treats any non-zero as true, as Excel does")
    func notTruthiness() throws {
        #expect(try evaluator(["x": [-3, 0, 0.5]]).evaluate("NOT(x)").valuesArray == [0, 1, 0])
    }

    @Test("AND and OR are variadic")
    func logicalOperatorsAreVariadic() throws {
        #expect(try evaluator().evaluate("AND(flag, other, 1)").valuesArray == [1, 0, 0])
        #expect(try evaluator().evaluate("OR(flag, other, 0)").valuesArray == [1, 1, 1])
    }

    @Test("NOT takes exactly one argument")
    func notArity() {
        #expect(throws: FormulaError.self) {
            _ = try evaluator().evaluate("NOT(flag, other)")
        }
    }

    // MARK: - Composition

    @Test("The logical family composes with IF and with comparisons")
    func logicalFamilyComposes() throws {
        let result = try evaluator().evaluate("IF(AND(a > 5, b > 25), 1, 0)")
        #expect(result.valuesArray == [0, 0, 1])
    }
}

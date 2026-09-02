//
//  FormulaArithmeticFunctionTests.swift
//  BusinessMath
//

import Testing
import Foundation
@testable import BusinessMath

/// `MIN`, `MAX`, `ABS`, `SUM` — the arithmetic primitives, with Excel's semantics.
///
/// Each acts **period by period**, which is what `MIN(A2, B2)` filled across a row
/// does in a sheet. Aggregating down a column is a different operation and is not
/// expressible here by design: this grammar is period-local, so a formula can never
/// reach into another period.
@Suite("Formula Arithmetic Functions")
struct FormulaArithmeticFunctionTests {

    private let months = [
        Period.month(year: 2026, month: 1),
        Period.month(year: 2026, month: 2),
        Period.month(year: 2026, month: 3)
    ]

    private func evaluator(
        _ accounts: [String: [Double]] = [
            "revenue": [100, 200, 300],
            "cogs": [40, 250, 120],
            "swing": [-50, 25, -75]
        ]
    ) -> FormulaEvaluator<Double> {
        FormulaEvaluator(accounts: accounts.mapValues {
            TimeSeries(periods: Array(months.prefix($0.count)), values: $0)
        })
    }

    // MARK: - MIN and MAX

    @Test("MIN takes the smaller value in each period")
    func minIsPeriodWise() throws {
        let result = try evaluator().evaluate("MIN(revenue, cogs)")
        #expect(result.valuesArray == [40, 200, 120])
    }

    @Test("MAX takes the larger value in each period")
    func maxIsPeriodWise() throws {
        let result = try evaluator().evaluate("MAX(revenue, cogs)")
        #expect(result.valuesArray == [100, 250, 300])
    }

    @Test("MIN and MAX take more than two arguments")
    func minMaxAreVariadic() throws {
        #expect(try evaluator().evaluate("MIN(revenue, cogs, 150)").valuesArray == [40, 150, 120])
        #expect(try evaluator().evaluate("MAX(revenue, cogs, 150)").valuesArray == [150, 250, 300])
    }

    @Test("MIN and MAX accept a single argument")
    func minMaxOfOne() throws {
        // Excel allows it and returns the value itself.
        #expect(try evaluator().evaluate("MIN(revenue)").valuesArray == [100, 200, 300])
        #expect(try evaluator().evaluate("MAX(revenue)").valuesArray == [100, 200, 300])
    }

    @Test("MIN of a floor is the idiom that motivates it")
    func minAsACap() throws {
        // A cash sweep is `MIN(available, outstanding)`, which is what this whole
        // function set exists to make expressible.
        let result = try evaluator(["available": [100, 40], "outstanding": [60, 60]])
            .evaluate("MIN(available, outstanding)")
        #expect(result.valuesArray == [60, 40])
    }

    // MARK: - ABS

    @Test("ABS is the magnitude in each period")
    func absIsPeriodWise() throws {
        let result = try evaluator().evaluate("ABS(swing)")
        #expect(result.valuesArray == [50, 25, 75])
    }

    @Test("ABS takes exactly one argument")
    func absArity() {
        #expect(throws: FormulaError.self) {
            _ = try evaluator().evaluate("ABS(revenue, cogs)")
        }
    }

    // MARK: - SUM

    @Test("SUM adds its arguments in each period")
    func sumIsPeriodWise() throws {
        let result = try evaluator().evaluate("SUM(revenue, cogs)")
        #expect(result.valuesArray == [140, 450, 420])
    }

    @Test("SUM takes any number of arguments")
    func sumIsVariadic() throws {
        #expect(try evaluator().evaluate("SUM(revenue)").valuesArray == [100, 200, 300])
        #expect(
            try evaluator().evaluate("SUM(revenue, cogs, swing)").valuesArray == [90, 475, 345])
    }

    // MARK: - Composition

    @Test("Functions compose with operators and with each other")
    func functionsCompose() throws {
        let result = try evaluator().evaluate("MAX(revenue - cogs, 0)")
        #expect(result.valuesArray == [60, 0, 180], "a floor at zero, the commonest use of MAX")
    }

    @Test("Functions nest")
    func functionsNest() throws {
        let result = try evaluator().evaluate("MIN(MAX(revenue, cogs), 250)")
        #expect(result.valuesArray == [100, 250, 250])
    }

    // MARK: - Arity

    @Test("A function called with too few arguments says so")
    func tooFewArguments() {
        do {
            _ = try evaluator().evaluate("MIN()")
            Issue.record("Expected a throw")
        } catch let error as FormulaError {
            #expect(error == .wrongArgumentCount(function: "MIN", expected: "1 or more", got: 0))
        } catch {
            Issue.record("Expected a FormulaError, got \(error)")
        }
    }

    @Test("The arity error names the function and both counts")
    func arityErrorIsSpecific() {
        do {
            _ = try evaluator().evaluate("ABS(revenue, cogs)")
            Issue.record("Expected a throw")
        } catch let error as FormulaError {
            #expect(error.errorDescription?.contains("ABS") == true)
            #expect(error.errorDescription?.contains("2") == true)
        } catch {
            Issue.record("Expected a FormulaError, got \(error)")
        }
    }

    // MARK: - Period Alignment

    @Test("A function over series of different lengths keeps the shared periods")
    func mismatchedLengthsIntersect() throws {
        // Consistent with how `+` already behaves: only periods present in both
        // sides survive. A model whose accounts disagree about their span should
        // not silently invent values for the gap.
        let result = try evaluator(["long": [1, 2, 3], "short": [10, 20]])
            .evaluate("MAX(long, short)")
        #expect(result.valuesArray == [10, 20])
    }
}

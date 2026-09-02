//
//  FormulaStatisticalFunctionTests.swift
//  BusinessMath
//

import Testing
import Foundation
@testable import BusinessMath

/// The statistical names, and the denominator that separates each pair.
///
/// `STDEV` and `STDEVP`, `VAR` and `VARP` differ only in whether they divide by
/// *n* or *n − 1*. Both answers are plausible, neither is obviously wrong on
/// inspection, and binding a name to the wrong one produces a number that passes
/// every eye test. Each pair is pinned against the other here for that reason.
///
/// All of these aggregate: they consume a whole series and give one number,
/// constant across the periods it came from.
@Suite("Formula Statistical Functions")
struct FormulaStatisticalFunctionTests {

    private let years = [
        Period.year(2024), Period.year(2025), Period.year(2026),
        Period.year(2027), Period.year(2028)
    ]

    private func evaluator(_ accounts: [String: [Double]]) -> FormulaEvaluator<Double> {
        FormulaEvaluator(accounts: accounts.mapValues {
            TimeSeries(periods: Array(years.prefix($0.count)), values: $0)
        })
    }

    private let sample = ["x": [2.0, 4.0, 4.0, 4.0, 5.0]]

    // MARK: - The denominator

    @Test("STDEV is the sample standard deviation, dividing by n − 1")
    func stdevIsSample() throws {
        let result = try evaluator(sample).evaluate("STDEV(x)")
        #expect(abs(result.valuesArray[0] - stdDevS([2.0, 4, 4, 4, 5])) < 1e-12)
    }

    @Test("STDEVP is the population standard deviation, dividing by n")
    func stdevpIsPopulation() throws {
        let result = try evaluator(sample).evaluate("STDEVP(x)")
        #expect(abs(result.valuesArray[0] - stdDevP([2.0, 4, 4, 4, 5])) < 1e-12)
    }

    @Test("STDEV and STDEVP give different answers, and the pair is pinned")
    func stdevPairDiffers() throws {
        let s = try evaluator(sample).evaluate("STDEV(x)").valuesArray[0]
        let p = try evaluator(sample).evaluate("STDEVP(x)").valuesArray[0]
        #expect(abs(s - p) > 1e-6, "if these ever agree, one of them is bound wrongly")
        #expect(s > p, "Bessel's correction makes the sample estimate the larger one")
    }

    @Test("VAR and VARP differ by the same denominator")
    func varPairDiffers() throws {
        let s = try evaluator(sample).evaluate("VAR(x)").valuesArray[0]
        let p = try evaluator(sample).evaluate("VARP(x)").valuesArray[0]
        #expect(abs(s - variance([2.0, 4, 4, 4, 5], .sample)) < 1e-12)
        #expect(abs(p - variance([2.0, 4, 4, 4, 5], .population)) < 1e-12)
        #expect(s > p)
    }

    @Test("Variance is the square of the standard deviation, for each denominator")
    func varianceIsTheSquare() throws {
        let sd = try evaluator(sample).evaluate("STDEV(x)").valuesArray[0]
        let v = try evaluator(sample).evaluate("VAR(x)").valuesArray[0]
        #expect(abs(sd * sd - v) < 1e-9)
    }

    // MARK: - Central tendency and counting

    @Test("MEDIAN is the middle value")
    func medianWorks() throws {
        #expect(try evaluator(["x": [3.0, 1, 2]]).evaluate("MEDIAN(x)").valuesArray[0] == 2)
    }

    @Test("COUNT is how many periods the series holds")
    func countCountsPeriods() throws {
        #expect(try evaluator(["x": [5.0, 6, 7]]).evaluate("COUNT(x)").valuesArray[0] == 3)
    }

    // MARK: - Shape

    @Test("A statistical aggregate is constant across its periods")
    func aggregateIsConstant() throws {
        let result = try evaluator(sample).evaluate("STDEV(x)")
        #expect(result.count == 5)
        #expect(Set(result.valuesArray).count == 1)
    }

    @Test("An aggregate composes with arithmetic")
    func aggregateComposes() throws {
        // A z-score's denominator: the idiom these are wanted for.
        let result = try evaluator(sample).evaluate("(x - AVERAGE(x)) / STDEV(x)")
        #expect(result.count == 5)
        #expect(abs(result.valuesArray.reduce(0, +)) < 1e-9, "z-scores sum to zero")
    }

    @Test("The statistical names take exactly one series")
    func statisticalArity() {
        #expect(throws: FormulaError.self) {
            _ = try evaluator(sample).evaluate("STDEV(x, x)")
        }
    }
}

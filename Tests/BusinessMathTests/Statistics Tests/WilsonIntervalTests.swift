//
//  WilsonIntervalTests.swift
//  BusinessMath
//
//  The Wilson score interval against R and SciPy, at the edges where a healthy rate lives.
//
//  Reference values from Scripts/reference-fixtures/generate_hub_statistics.R
//  (R 4.6.2, `prop.test(x, n, conf.level, correct = FALSE)$conf.int`), checked against
//  generate_hub_statistics.py (SciPy 1.17.1, `binomtest(k, n).proportion_ci(method="wilson")`).
//  The two agree to 4e-16 on every case here.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Wilson score interval: reference values, edge behaviour and refusals.
///
/// ## Tolerance
///
/// Absolute 1e-12 on each bound. The Hub needs four decimals; R and SciPy differ from each
/// other by at most 4e-16 on these cases.
@Suite("Wilson score interval")
struct WilsonIntervalTests {

    struct Reference: Sendable {
        let successes: Int
        let trials: Int
        let confidence: Double
        let lower: Double
        let upper: Double
    }

    /// R 4.6.2, `prop.test(correct = FALSE)$conf.int`, 17 significant digits.
    static let references: [Reference] = [
        Reference(successes: 0, trials: 10, confidence: 0.95, lower: 0, upper: 0.27753279986288903),
        Reference(successes: 1, trials: 10, confidence: 0.95,
                  lower: 0.017876213095072934, upper: 0.40415002679523832),
        Reference(successes: 10, trials: 10, confidence: 0.95, lower: 0.72246720013711085, upper: 1),
        Reference(successes: 0, trials: 5, confidence: 0.95, lower: 0, upper: 0.43448246478317459),
        Reference(successes: 3, trials: 1000, confidence: 0.95,
                  lower: 0.001020783881138619, upper: 0.0087830140535031711),
        Reference(successes: 1, trials: 1, confidence: 0.95, lower: 0.20654931437723753, upper: 1),
        Reference(successes: 50, trials: 100, confidence: 0.95,
                  lower: 0.40383153036599567, upper: 0.59616846963400427),
        Reference(successes: 999, trials: 1000, confidence: 0.95,
                  lower: 0.99435744140204207, upper: 0.99982345362937386),
        Reference(successes: 7, trials: 20, confidence: 0.90,
                  lower: 0.20226004005676107, upper: 0.53348731115152825),
        Reference(successes: 7, trials: 20, confidence: 0.99,
                  lower: 0.14639344137693885, upper: 0.62833817895268707),
    ]

    @Test("Bounds match R and SciPy to 1e-12", arguments: references)
    func matchesReference(_ reference: Reference) throws {
        let interval: WilsonInterval<Double> = try wilsonInterval(
            successes: reference.successes, trials: reference.trials,
            confidence: reference.confidence)
        #expect(abs(interval.lower - reference.lower) < 1e-12)
        #expect(abs(interval.upper - reference.upper) < 1e-12)
        #expect(interval.value.isEqual(to: Double(reference.successes) / Double(reference.trials)))
        #expect(interval.confidence.isEqual(to: reference.confidence))
    }

    @Test("The Hub's five cases, to four decimals as the proposal states them")
    func hubCasesToFourDecimals() throws {
        // "To 4 decimals": within half a unit in the fourth decimal place.
        let halfUnit: Double = 0.000_05
        let cases: [(successes: Int, trials: Int, lower: Double, upper: Double)] = [
            (0, 10, 0, 0.2775), (1, 10, 0.0179, 0.4042), (10, 10, 0.7225, 1),
            (0, 5, 0, 0.4345), (3, 1000, 0.0010, 0.0088),
        ]
        for c in cases {
            let interval: WilsonInterval<Double> = try wilsonInterval(
                successes: c.successes, trials: c.trials, confidence: 0.95)
            #expect(abs(interval.lower - c.lower) < halfUnit, "\(c.successes) of \(c.trials)")
            #expect(abs(interval.upper - c.upper) < halfUnit, "\(c.successes) of \(c.trials)")
        }
    }

    @Test("Confidence defaults to 95%")
    func defaultConfidence() throws {
        let implicit: WilsonInterval<Double> = try wilsonInterval(successes: 3, trials: 1000)
        let explicit: WilsonInterval<Double> = try wilsonInterval(successes: 3, trials: 1000, confidence: 0.95)
        #expect(implicit == explicit)
    }

    @Test("At 0 and at n the bound sits exactly on 0 or 1, not a rounding away")
    func edgesAreExact() throws {
        for trials in [1, 2, 5, 10, 1000, 1_000_000] {
            let none: WilsonInterval<Double> = try wilsonInterval(successes: 0, trials: trials)
            #expect(none.lower.isEqual(to: 0))
            #expect(none.value.isEqual(to: 0))
            #expect(none.upper > 0 && none.upper < 1)
            let all: WilsonInterval<Double> = try wilsonInterval(successes: trials, trials: trials)
            #expect(all.upper.isEqual(to: 1))
            #expect(all.value.isEqual(to: 1))
            #expect(all.lower > 0 && all.lower < 1)
        }
    }

    @Test("A rate and its complement give mirrored intervals")
    func complementIsMirrored() throws {
        // The Hub asks for crash-free = 1 − crashLike/launches; either orientation must agree.
        for (successes, trials) in [(0, 10), (1, 10), (3, 1000), (37, 41), (500, 1000)] {
            let rate: WilsonInterval<Double> = try wilsonInterval(successes: successes, trials: trials)
            let complement: WilsonInterval<Double> = try wilsonInterval(
                successes: trials - successes, trials: trials)
            #expect(abs(rate.lower - (1 - complement.upper)) < 1e-15)
            #expect(abs(rate.upper - (1 - complement.lower)) < 1e-15)
        }
    }

    @Test("The interval is ordered, inside [0, 1], and contains the observed rate")
    func ordered() throws {
        for trials in [1, 3, 17, 250] {
            for successes in 0...trials {
                let interval: WilsonInterval<Double> = try wilsonInterval(successes: successes, trials: trials)
                #expect(interval.lower >= 0 && interval.upper <= 1)
                #expect(interval.lower <= interval.value && interval.value <= interval.upper)
            }
        }
    }

    @Test("Wider at higher confidence")
    func widensWithConfidence() throws {
        let ninety: WilsonInterval<Double> = try wilsonInterval(successes: 7, trials: 20, confidence: 0.90)
        let ninetyNine: WilsonInterval<Double> = try wilsonInterval(successes: 7, trials: 20, confidence: 0.99)
        #expect(ninetyNine.lower < ninety.lower && ninetyNine.upper > ninety.upper)
    }

    @Test("Generic over Real: Float agrees with Double to Float precision")
    func floatAgrees() throws {
        let float: WilsonInterval<Float> = try wilsonInterval(successes: 1, trials: 10, confidence: 0.95)
        #expect(abs(Double(float.lower) - 0.017876213095072934) < 1e-6)
        #expect(abs(Double(float.upper) - 0.40415002679523832) < 1e-6)
    }

    // MARK: - Refusals

    @Test("No trials is insufficient data, not a rate")
    func refusesZeroTrials() {
        #expect(throws: BusinessMathError.insufficientData(
            required: 1, actual: 0, context: "wilsonInterval needs at least one trial")) {
            _ = try wilsonInterval(successes: 0, trials: 0, confidence: 0.95) as WilsonInterval<Double>
        }
    }

    @Test("Counts that are not a proportion are refused",
          arguments: [(-1, 10), (11, 10), (0, -1), (-3, -1)])
    func refusesInvalidCounts(successes: Int, trials: Int) {
        #expect(throwsInvalidInput("\(successes) of \(trials)") {
            _ = try wilsonInterval(successes: successes, trials: trials, confidence: 0.95) as WilsonInterval<Double>
        })
    }

    @Test("A confidence outside (0, 1) is refused",
          arguments: [0.0, 1.0, -0.5, 1.5, Double.nan, Double.infinity, -Double.infinity])
    func refusesInvalidConfidence(confidence: Double) {
        #expect(throwsInvalidInput("confidence \(confidence)") {
            _ = try wilsonInterval(successes: 1, trials: 10, confidence: confidence) as WilsonInterval<Double>
        })
    }
}

/// Whether `body` throws `BusinessMathError.invalidInput`; any other outcome is recorded.
fileprivate func throwsInvalidInput(_ label: String, _ body: () throws -> Void) -> Bool {
    do {
        try body()
        Issue.record("\(label) was accepted")
        return false
    } catch let error as BusinessMathError {
        guard case .invalidInput = error else {
            Issue.record("\(label): expected invalidInput, got \(error)")
            return false
        }
        return true
    } catch {
        Issue.record("\(label): expected BusinessMathError, got \(error)")
        return false
    }
}

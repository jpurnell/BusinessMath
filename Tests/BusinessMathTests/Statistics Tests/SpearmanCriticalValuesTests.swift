//
//  SpearmanCriticalValuesTests.swift
//  BusinessMath
//
//  Critical values and the significance test for Spearman's rho: the convention, unreachable
//  significance at small n, the degenerate judge, exact decisions, and the approximations.
//  Reference values are in SpearmanReferenceTests.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Spearman's rho: critical values and test")
struct SpearmanCriticalValuesTests {

    // MARK: - The level

    @Test("α outside (0, 1) or nan is refused by every method")
    func refusesInvalidAlpha() {
        for alpha in [0.0, 1.0, -0.05, 1.5, Double.nan, Double.infinity] {
            for method in SpearmanSignificanceMethod.allCases {
                #expect(throws: BusinessMathError.self, "α = \(alpha), \(method)") {
                    _ = try spearmanCriticalValues(items: 8, alpha: alpha, method: method)
                }
            }
        }
    }

    // MARK: - Unreachable significance

    /// n = 4: the most extreme rho has probability 1/24 ≈ 0.042 > 0.025, so nothing is
    /// significant at 5% two-sided, but rho = ±1 is at 10%.
    @Test("n = 4 cannot reach 5% two-sided; reaches 10% at rho = ±1")
    func nFourUnreachable() throws {
        let five = try spearmanCriticalValues(items: 4, alpha: 0.05)
        #expect(five.lower == nil && five.upper == nil)
        #expect(!five.canReachSignificance)
        #expect(five.nonSignificantRange == -1.0...1.0)
        #expect(!five.isSignificant(1))
        let ten = try spearmanCriticalValues(items: 4, alpha: 0.10)
        #expect(ten.upper == 1 && ten.lower == -1)
        #expect(ten.upperTailProbability?.isEqual(to: 1.0 / 24) == true)
        #expect(ten.isSignificant(1))
    }

    /// n = 5: P(rho = 1) = 1/120 ≤ 0.025 < P(rho ≥ 0.9) = 5/120.
    @Test("n = 5 at 5% and 10%: 1.0 and 0.9, as every table prints")
    func nFive() throws {
        let five = try spearmanCriticalValues(items: 5, alpha: 0.05)
        #expect(five.upper == 1)
        #expect(five.lower == -1)
        #expect(five.sumOfSquaredDifferencesAtUpper == 0)
        #expect(five.sumOfSquaredDifferencesAtLower == 40)
        let range = try #require(five.nonSignificantRange)
        #expect(abs(range.upperBound - 0.9) < 1e-15 && abs(range.lowerBound + 0.9) < 1e-15)
        let ten = try spearmanCriticalValues(items: 5, alpha: 0.10)
        let upper = try #require(ten.upper)
        #expect(abs(upper - 0.9) < 1e-15)
        #expect(ten.sumOfSquaredDifferencesAtUpper == 2)
        let tenTail = try #require(ten.upperTailProbability)
        #expect(abs(tenTail - 5.0 / 120) < 1e-16)
    }

    // MARK: - Convention

    @Test("Bounds are the extreme attainable rho within α/2; one step in exceeds it")
    func boundsAreMaximal() throws {
        let cases: [([Double], [Double])] = [
            ((1...9).map(Double.init), (1...9).map(Double.init)),
            ([1, 2, 3, 4, 5, 6, 7, 8], [5, 3, 3, 3, 8, 1, 2, 7]),
            ([1, 2, 2, 3, 4, 4, 5, 5], [2, 1, 3, 3, 5, 4, 4, 1]),
        ]
        for (x, y) in cases {
            let d: SpearmanDistribution<Double> = try spearmanDistribution(x, vs: y)
            for alpha in [0.01, 0.05, 0.10, 0.20] {
                let values = try d.criticalValues(alpha: alpha)
                #expect(values.method == .exact)
                let range = try #require(values.nonSignificantRange)
                #expect(d.probability(atLeast: range.upperBound) > alpha / 2)
                #expect(d.probability(atMost: range.lowerBound) > alpha / 2)
                if let upper = values.upper {
                    #expect(d.probability(atLeast: upper) <= alpha / 2)
                    #expect(d.rhoValues.contains(upper), "upper is attainable")
                }
                if let lower = values.lower {
                    #expect(d.probability(atMost: lower) <= alpha / 2)
                    #expect(d.rhoValues.contains(lower), "lower is attainable")
                }
                for r in d.rhoValues {
                    #expect(values.isSignificant(r) != range.contains(r), "rho \(r)")
                }
            }
        }
    }

    /// One judge separates a single wine from three it tied: the four places that wine can
    /// take are equally likely, so the top rho has probability exactly 1/4. At α = 0.5 the
    /// tail equals α/2 and is admitted; a hair below, it is not.
    @Test("A tail exactly equal to α/2 is admitted, and decided on the real α")
    func exactBoundary() throws {
        let x: [Double] = [1, 2, 3, 4]
        let y: [Double] = [0, 0, 0, 1]
        let at = try spearmanCriticalValues(x, vs: y, alpha: 0.5)
        #expect(at.upperTailProbability?.isEqual(to: 0.25) == true)
        // Ranks (1, 2, 3, 4) against (2, 2, 2, 4): rho = 3/√15.
        #expect(at.upper.map { abs($0 - 3 / 15.0.squareRoot()) < 1e-15 } == true)
        let below = try spearmanCriticalValues(x, vs: y, alpha: 0.5.nextDown)
        #expect(below.upper == nil)
        // n = 4 untied: P(rho = 1) = 1/24, so the bound appears only once α ≥ 1/12.
        #expect(try spearmanCriticalValues(items: 4, alpha: (1.0 / 12).nextDown).upper == nil)
        #expect(try spearmanCriticalValues(items: 4, alpha: (1.0 / 12).nextUp).upper == 1)
    }

    // MARK: - The test

    @Test("spearmanTest: rho, exact p-value and decision agree with the distribution")
    func testAgreesWithDistribution() throws {
        let x: [Double] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        let y: [Double] = [2, 1, 4, 3, 6, 5, 8, 7, 10, 9]
        let result = try spearmanTest(x, vs: y, alpha: 0.05)
        let rho = try #require(result.rho)
        #expect(abs(rho - (try spearmansRho(x, vs: y))) < 1e-15)
        #expect(result.method == .exact)
        #expect(result.isComputable)
        #expect(!result.hasTies)
        let d: SpearmanDistribution<Double> = try spearmanDistribution(items: 10)
        let p = try #require(result.pValue)
        #expect(p == d.pValue(rho: rho))
        #expect(result.isSignificant == (p <= 0.05))
        #expect(result.isSignificant == result.criticalValues.isSignificant(rho))
        #expect(result.sumOfSquaredDifferences == 10)
    }

    @Test("Perfect agreement: p = 2/n!, and rho = 1 is significant from n = 5")
    func perfectAgreement() throws {
        for n in 3...9 {
            let x: [Double] = (1...n).map(Double.init)
            let result = try spearmanTest(x, vs: x, alpha: 0.05)
            var factorial: Double = 1
            for k in 1...n { factorial *= Double(k) }
            #expect(result.rho == 1)
            #expect(result.pValue == min(1, 2 / factorial), "n = \(n)")
            #expect(result.isSignificant == (n >= 5), "n = \(n)")
        }
    }

    /// A judge who tied every wine has no ranking: the result reports rho as not computable
    /// rather than as zero agreement, and nothing is significant.
    @Test("A judge who tied everything: rho not computable, never zero")
    func degenerateTest() throws {
        for method in SpearmanSignificanceMethod.allCases where method != .edgeworth {
            let result = try spearmanTest([1.0, 2, 3, 4, 5], vs: [4, 4, 4, 4, 4], method: method)
            #expect(result.rho == nil, "\(method)")
            #expect(result.pValue == nil, "\(method)")
            #expect(!result.isComputable)
            #expect(!result.isSignificant)
            #expect(result.criticalValues.isDegenerate)
            #expect(!result.criticalValues.canReachSignificance)
        }
    }

    // MARK: - Approximations

    @Test("t approximation: two-sided p from the t distribution on n − 2 df, rho_c = t/√(ν + t²)")
    func tApproximation() throws {
        let x: [Double] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
        let y: [Double] = [3, 1, 2, 6, 4, 5, 9, 7, 8, 12, 10, 11]
        let result = try spearmanTest(x, vs: y, method: .tDistribution)
        let rho = try #require(result.rho)
        let t: Double = rho * ((10) / (1 - rho * rho)).squareRoot()
        let expected: Double = try tPValue(t: t, df: 10)
        let p = try #require(result.pValue)
        #expect(abs(p - expected) < 1e-12)
        let values = try spearmanCriticalValues(items: 12, alpha: 0.05, method: .tDistribution)
        let upper = try #require(values.upper)
        let tc: Double = try tQuantile(p: 0.975, df: 10)
        #expect(abs(upper - tc / (10 + tc * tc).squareRoot()) < 1e-12)
        #expect(values.lower == -upper)
        #expect(values.nonSignificantRange == nil)
        #expect(values.upperTailProbability?.isEqual(to: 0.025) == true)
    }

    @Test("Edgeworth (AS 89) refuses ties; t accepts them")
    func edgeworthRefusesTies() throws {
        let x: [Double] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        let y: [Double] = [1, 2, 2, 4, 5, 6, 7, 8, 9, 10]
        #expect(throws: BusinessMathError.self) { _ = try spearmanTest(x, vs: y, method: .edgeworth) }
        #expect(throws: BusinessMathError.self) {
            _ = try spearmanCriticalValues(x, vs: y, alpha: 0.05, method: .edgeworth)
        }
        _ = try spearmanTest(x, vs: y, method: .tDistribution)
    }

    /// The approximations need no enumeration, so they answer at any n the exact method
    /// refuses.
    @Test("Approximations answer where the exact method refuses")
    func approximationsAtLargeN() throws {
        let n: Int = 200
        for method in [SpearmanSignificanceMethod.edgeworth, .tDistribution] {
            let values = try spearmanCriticalValues(items: n, alpha: 0.05, method: method)
            let upper = try #require(values.upper)
            #expect(abs(upper - 1.96 / Double(n - 1).squareRoot()) < 0.01, "\(method)")
        }
    }
}

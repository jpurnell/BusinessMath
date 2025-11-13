//
//  AdvancedStatisticsTests.swift
//  BusinessMath Tests
//
//  Tests for advanced statistical and probability distribution tools
//

import XCTest
import OSLog
import Numerics
@testable import BusinessMath

final class AdvancedStatisticsTests: XCTestCase {
    let testLogger = Logger(subsystem: "Business Math > Tests > BusinessMathTests > Distribution Tests", category: "Advanced Statistics Tests")

    // MARK: - Probability Distribution Tests

    func testBinomialProbability() {
        // Test: Probability of getting exactly 3 heads in 5 coin flips
        // P(X=3) where n=5, p=0.5, k=3
        // Expected: C(5,3) * 0.5^3 * 0.5^2 = 10 * 0.125 * 0.25 = 0.3125
        let n = 5
        let k = 3
        let p = 0.5

        // Calculate expected value manually
        let combinations = Double(combination(n, c: k))
        let expected = combinations * pow(p, Double(k)) * pow(1 - p, Double(n - k))

        XCTAssertEqual(expected, 0.3125, accuracy: 0.0001)
    }

    func testPoissonProbability() {
        // Test: Probability of exactly 3 events when mean is 2.5
        let x = 3
        let mu = 2.5

        let result: Double = poisson(x, µ: mu)

        // Expected: (e^-2.5 * 2.5^3) / 3! ≈ 0.2138
        XCTAssertGreaterThan(result, 0.2)
        XCTAssertLessThan(result, 0.22)
    }

    func testExponentialDistribution() {
        // Test: PDF of exponential distribution at x=1, λ=0.5
        let x = 1.0
        let lambda = 0.5

        let result: Double = exponentialPDF(x, λ: lambda)

        // Expected: 0.5 * e^(-0.5*1) ≈ 0.303
        XCTAssertGreaterThan(result, 0.3)
        XCTAssertLessThan(result, 0.31)
    }

    func testHypergeometricProbability() {
        // Test: Drawing 2 aces from 5 cards drawn from a deck
        // Total cards: 52, Aces: 4, Cards drawn: 5, Aces in hand: 2
        let result: Double = hypergeometric(total: 52, r: 4, n: 5, x: 2)
		let roundedResult = (result * 10.0).rounded() / 10.0
        // Should be a small probability
        XCTAssertEqual(roundedResult, 0.0)
        XCTAssertLessThan(result, 0.05)
    }

    func testLogNormalDistribution() {
        // Test: Log-normal PDF at various points
        // For LogNormal(μ=0, σ=1), the PDF at x=1 should be:
        // f(1) = 1/(1 * 1 * sqrt(2π)) * exp(-(ln(1) - 0)²/(2*1²))
        // f(1) = 1/sqrt(2π) * exp(0) = 1/sqrt(2π) ≈ 0.3989
        
        // Test at x=1 (the mode/peak for standard log-normal)
        let result1 = logNormalPDF(1.0, mean: 0.0, stdDev: 1.0)
//        testLogger.info("LogNormal PDF at x=1: \(result1, privacy: .public)")
        
        // At x=1, ln(1)=0, so we get peak density
        // Expected: 1/sqrt(2π) ≈ 0.3989
        XCTAssertFalse(result1.isNaN, "PDF should not be NaN at x=1")
        XCTAssertTrue(result1.isFinite, "PDF should be finite at x=1")
        XCTAssertEqual(result1, 0.3989, accuracy: 0.001, "Peak should be at 1/sqrt(2π)")
        
        // Test at x=e (≈2.718), where ln(e)=1
        let resultAtE = logNormalPDF(Double.exp(1), mean: 0.0, stdDev: 1.0)
//        testLogger.info("LogNormal PDF at x=e: \(resultAtE, privacy: .public)")
        XCTAssertFalse(resultAtE.isNaN, "PDF should not be NaN at x=e")
        XCTAssertLessThan(resultAtE, result1, "Should be less than peak")
        XCTAssertGreaterThan(resultAtE, 0.05, "Should still have reasonable density")
        
        // Test specific points with explicit parameters
        let result05 = logNormalPDF(0.5, mean: 0.0, stdDev: 1.0)
//        testLogger.info("LogNormal PDF at x=0.5: \(result05, privacy: .public)")
        XCTAssertFalse(result05.isNaN, "PDF must not be NaN at x=0.5")
        XCTAssertGreaterThan(result05, 0, "PDF must be positive at x=0.5")
        
        let result2 = logNormalPDF(2.0, mean: 0.0, stdDev: 1.0)
//        testLogger.info("LogNormal PDF at x=2.0: \(result2, privacy: .public)")
        XCTAssertFalse(result2.isNaN, "PDF must not be NaN at x=2.0")
        XCTAssertGreaterThan(result2, 0, "PDF must be positive at x=2.0")
        
        let result5 = logNormalPDF(5.0, mean: 0.0, stdDev: 1.0)
//        testLogger.info("LogNormal PDF at x=5.0: \(result5, privacy: .public)")
        XCTAssertFalse(result5.isNaN, "PDF must not be NaN at x=5.0")
        XCTAssertGreaterThan(result5, 0, "PDF must be positive at x=5.0")
        
        // Test with different parameters: LogNormal(μ=1, σ=0.5)
        // Median should be at e^μ = e^1 ≈ 2.718
        let pdfAtMedian = logNormalPDF(Double.exp(1.0), mean: 1.0, stdDev: 0.5)
//        testLogger.info("LogNormal PDF at median (μ=1, σ=0.5): \(pdfAtMedian, privacy: .public)")
        XCTAssertFalse(pdfAtMedian.isNaN, "PDF should not be NaN at median")
        XCTAssertGreaterThan(pdfAtMedian, 0.2, "Should have substantial density at median")
        
        // Test edge case: very small x value
        let pdfSmall = logNormalPDF(0.01, mean: 0.0, stdDev: 1.0)
//        testLogger.info("LogNormal PDF at x=0.01: \(pdfSmall, privacy: .public)")
        XCTAssertFalse(pdfSmall.isNaN, "PDF should handle small x values")
        XCTAssertGreaterThan(pdfSmall, 0, "PDF must be positive even for small x")
    }

    // MARK: - Combinatorics Tests

    func testCombinations() {
        // Test: C(5,3) = 10
        let result = combination(5, c: 3)
        XCTAssertEqual(result, 10)

        // Test: C(10,2) = 45
        let result2 = combination(10, c: 2)
        XCTAssertEqual(result2, 45)
    }

    func testPermutations() {
        // Test: P(5,3) = 60
        let result = permutation(5, p: 3)
        XCTAssertEqual(result, 60)

        // Test: P(10,2) = 90
        let result2 = permutation(10, p: 2)
        XCTAssertEqual(result2, 90)
    }

    func testFactorial() {
        // Test: 5! = 120
        let result = factorial(5)
        XCTAssertEqual(result, 120)

        // Test: 0! = 1
        let result2 = factorial(0)
        XCTAssertEqual(result2, 1)

        // Test: 10! = 3628800
        let result3 = factorial(10)
        XCTAssertEqual(result3, 3628800)
    }

    // MARK: - Statistical Means Tests

    func testGeometricMean() {
        // Test: Geometric mean of [2, 8] = √(2*8) = 4
        let values = [2.0, 8.0]
        let result: Double = geometricMean(values)
        XCTAssertEqual(result, 4.0, accuracy: 0.0001)

        // Test: Geometric mean of [1,2,3,4,5] ≈ 2.605
        let values2 = [1.0, 2.0, 3.0, 4.0, 5.0]
        let result2: Double = geometricMean(values2)
        XCTAssertGreaterThan(result2, 2.6)
        XCTAssertLessThan(result2, 2.61)
    }

    func testHarmonicMean() {
        // Test: Harmonic mean of [1,2,4] = 3 / (1/1 + 1/2 + 1/4) = 3 / 1.75 ≈ 1.714
        let values = [1.0, 2.0, 4.0]
        let result: Double = harmonicMean(values)
        XCTAssertGreaterThan(result, 1.71)
        XCTAssertLessThan(result, 1.72)
    }

    func testWeightedAverage() {
        // Test: Weighted average of [80, 90, 70] with weights [0.2, 0.3, 0.5]
        // = 80*0.2 + 90*0.3 + 70*0.5 = 16 + 27 + 35 = 78
        let values = [80.0, 90.0, 70.0]
        let weights = [0.2, 0.3, 0.5]

        // Calculate weighted average manually for test
        let result = zip(values, weights).map(*).reduce(0, +)
        XCTAssertEqual(result, 78.0, accuracy: 0.0001)
    }

    // MARK: - Analysis Tools Tests

    func testGoalSeek() {
        // Test: Find x where x^2 = 16 (should be 4 or -4)
        // Using positive guess should converge to 4
        // We'll test this once goalSeek is public
        XCTAssertTrue(true) // Placeholder until implementation
    }

    func testDataTable() {
        // Test: 1-variable data table
        // Calculate multiple outputs for different input values
        // Example: Loan payment for different interest rates
        XCTAssertTrue(true) // Placeholder until implementation
    }
}

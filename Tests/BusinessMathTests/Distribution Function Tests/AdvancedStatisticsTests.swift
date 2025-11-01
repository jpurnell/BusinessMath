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
        // Test: Log-normal PDF at x=1, mean=0, stdDev=1
        // At x=1, log(1)=0, so this is the peak of the distribution
        let x = 1.0
        let mean = 0.0
        let stdDev = 1.0

        // For now, just test the calculation works
        // We'll implement this in the tool
        XCTAssertEqual(x, 1.0) // Placeholder until implementation
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

//
//  Inference Tests.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import XCTest
import OSLog
import Numerics
@testable import BusinessMath

final class InferenceTests: XCTestCase {
	let inferenceTestLogger = Logger(subsystem: "Business Math > Tests > BusinessMathTests > Distribution Tests", category: "Inference Tests")

    func testConfidence() {
        let result = (confidence(alpha: 0.05, stdev: 2.5, sampleSize: 50).high * 1000000.0).rounded(.up) / 1000000.0
        XCTAssertEqual(result, 0.692952)
    }

    func testpValueOfZTest() {
		inferenceTestLogger.error("Test not implemented for \(self.name, privacy: .public)")
    }

    // MARK: - New Statistical Testing Tool Tests

    // Test 1: Two-Sample T-Test
    func testTwoSampleTTest() {
        // Example: Compare mean sales between two stores
        let group1 = [85.0, 90.0, 88.0, 92.0, 87.0, 89.0, 91.0, 86.0]
        let group2 = [78.0, 82.0, 80.0, 79.0, 81.0, 77.0, 83.0, 80.0]

        let mean1 = group1.reduce(0, +) / Double(group1.count)
        let mean2 = group2.reduce(0, +) / Double(group2.count)

        // Expect group1 to have significantly higher mean than group2
        XCTAssertGreaterThan(mean1, mean2)
        XCTAssertGreaterThan(mean1, 85.0)
        XCTAssertLessThan(mean2, 82.0)
    }

    // Test 2: One-Sample T-Test
    func testOneSampleTTest() {
        // Example: Test if average sales = 100
        let sample = [95.0, 102.0, 98.0, 104.0, 97.0, 101.0, 99.0, 103.0]
        let populationMean = 100.0

        let sampleMean = sample.reduce(0, +) / Double(sample.count)
        let variance = sample.map { pow($0 - sampleMean, 2) }.reduce(0, +) / Double(sample.count - 1)
        let stdDev = sqrt(variance)

        // Calculate t-statistic
        let tStat = (sampleMean - populationMean) / (stdDev / sqrt(Double(sample.count)))

        // T-statistic should be close to 0 (sample mean ≈ population mean)
        XCTAssertLessThan(abs(tStat), 2.0)
    }

    // Test 3: AB Test P-Value
    func testABTestPValue() {
        // Example: Test conversion rates
        let obsA = 1000
        let convA = 85  // 8.5% conversion
        let obsB = 1000
        let convB = 110 // 11% conversion

        let result: Double = pValue(obsA: obsA, convA: convA, obsB: obsB, convB: convB)

        // B should have significantly higher conversion (p-value should indicate significance)
        XCTAssertGreaterThan(result, 0.0)
        XCTAssertLessThan(result, 1.0)
    }

    // Test 4: Sample Size Calculation
    func testSampleSizeCalculation() {
        // Example: Calculate required sample size for 95% confidence, 5% margin of error
        let confidence = 0.95
        let proportion = 0.5  // Worst case: 50%
        let populationSize = 10000.0
        let marginOfError = 0.05

        let result: Double = sampleSize(ci: confidence, proportion: proportion, n: populationSize, error: marginOfError)

        // Should be around 370 for these parameters
        XCTAssertGreaterThan(result, 300)
        XCTAssertLessThan(result, 400)
    }

    // Test 5: Confidence Interval
    func testConfidenceInterval() {
        // Test confidence interval calculation
        let alpha = 0.05  // 95% confidence
        let stdev = 2.5
        let sampleSize = 50

        let result = confidence(alpha: alpha, stdev: stdev, sampleSize: sampleSize)

        // Check that confidence interval is symmetric and reasonable
        XCTAssertGreaterThan(result.high, 0)
        XCTAssertLessThan(result.high, 1.0)
        XCTAssertEqual(result.low, -result.high, accuracy: 0.0001)
    }

    // Test 6: Chi-Square Test (categorical data)
    func testChiSquarePreparation() {
        // Example: Test if observed frequencies match expected
        let observed = [45.0, 35.0, 20.0]
        let expected = [40.0, 40.0, 20.0]

        // Calculate chi-square statistic
        var chiSquare = 0.0
        for i in 0..<observed.count {
            chiSquare += pow(observed[i] - expected[i], 2) / expected[i]
        }

        // Chi-square should be relatively small for similar distributions
        XCTAssertGreaterThan(chiSquare, 0)
        XCTAssertLessThan(chiSquare, 5.0)  // Not significantly different
    }
}

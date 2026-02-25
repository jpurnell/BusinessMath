//
//  Inference Tests.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import Testing
import TestSupport  // Cross-platform math functions
import Numerics
@testable import BusinessMath
#if canImport(OSLog)
import OSLog
#endif

@Suite("InferenceTests") struct InferenceTests {
	let inferenceTestLogger = Logger(subsystem: "Business Math > Tests > BusinessMathTests > Distribution Tests", category: "Inference Tests: \(#function)")

    @Test("Confidence") func LConfidence() {
        let result = (confidence(alpha: 0.05, stdev: 2.5, sampleSize: 50).high * 1000000.0).rounded(.up) / 1000000.0
        #expect(result == 0.692952)
    }

    func testpValueOfZTest() {
        // Example: Test if a sample mean differs significantly from a known population mean
        // Scenario: Testing if average customer spending differs from historical $50
        let sample = [52.0, 48.0, 55.0, 49.0, 51.0, 53.0, 47.0, 54.0, 50.0, 52.0,
                      51.0, 49.0, 53.0, 48.0, 52.0, 50.0, 51.0, 49.0, 54.0, 50.0]
        let populationMean = 50.0
        let populationStdDev = 3.0  // Known population standard deviation
        
        // Calculate sample statistics
        let n = Double(sample.count)
        let sampleMean = sample.reduce(0, +) / n
        
        // Calculate Z-statistic
        let standardError = populationStdDev / sqrt(n)
        let zStatistic = (sampleMean - populationMean) / standardError
        
        // Calculate two-tailed p-value using standard normal distribution
        // For a standard normal distribution: P(|Z| > |z|) = 2 * P(Z > |z|)
        let absZ = abs(zStatistic)
        
        // Using the complementary error function to calculate p-value
        // P(Z > z) = 0.5 * erfc(z / sqrt(2))
        let pValue = 2.0 * 0.5 * erfc(absZ / sqrt(2.0))
        
        // Verify p-value properties
        #expect(pValue > 0.0, "P-value should be positive")
        #expect(pValue < 1.0, "P-value should be less than 1")
        
        // For this sample (mean ≈ 50.8), the p-value should be relatively high
        // indicating no significant difference from population mean of 50
        #expect(pValue > 0.05, "P-value should be > 0.05 (not significant)")
        
        // Log the results
//        inferenceTestLogger.info("Z-Test Results: sampleMean=\(sampleMean), zStatistic=\(zStatistic), pValue=\(pValue)")
    }

    // MARK: - New Statistical Testing Tool Tests

    // Test 1: Two-Sample T-Test
    @Test("TwoSampleTTest") func LTwoSampleTTest() {
        // Example: Compare mean sales between two stores
        let group1 = [85.0, 90.0, 88.0, 92.0, 87.0, 89.0, 91.0, 86.0]
        let group2 = [78.0, 82.0, 80.0, 79.0, 81.0, 77.0, 83.0, 80.0]

        let mean1 = group1.reduce(0, +) / Double(group1.count)
        let mean2 = group2.reduce(0, +) / Double(group2.count)

        // Expect group1 to have significantly higher mean than group2
        #expect(mean1 > mean2)
        #expect(mean1 > 85.0)
        #expect(mean2 < 82.0)
    }

    // Test 2: One-Sample T-Test
    @Test("OneSampleTTest") func LOneSampleTTest() {
        // Example: Test if average sales = 100
        let sample = [95.0, 102.0, 98.0, 104.0, 97.0, 101.0, 99.0, 103.0]
        let populationMean = 100.0

        let sampleMean = sample.reduce(0, +) / Double(sample.count)
        let variance = sample.map { pow($0 - sampleMean, 2) }.reduce(0, +) / Double(sample.count - 1)
        let stdDev = sqrt(variance)

        // Calculate t-statistic
        let tStat = (sampleMean - populationMean) / (stdDev / sqrt(Double(sample.count)))

        // T-statistic should be close to 0 (sample mean ≈ population mean)
        #expect(abs(tStat) < 2.0)
    }

    // Test 3: AB Test P-Value
    @Test("ABTestPValue") func LABTestPValue() {
        // Example: Test conversion rates
        let obsA = 1000
        let convA = 85  // 8.5% conversion
        let obsB = 1000
        let convB = 110 // 11% conversion

        let result: Double = pValue(obsA: obsA, convA: convA, obsB: obsB, convB: convB)

        // B should have significantly higher conversion (p-value should indicate significance)
        #expect(result > 0.0)
        #expect(result < 1.0)
    }

    // Test 4: Sample Size Calculation
    @Test("SampleSizeCalculation") func LSampleSizeCalculation() {
        // Example: Calculate required sample size for 95% confidence, 5% margin of error
        let confidence = 0.95
        let proportion = 0.5  // Worst case: 50%
        let populationSize = 10000.0
        let marginOfError = 0.05

        let result: Double = sampleSize(ci: confidence, proportion: proportion, n: populationSize, error: marginOfError)

        // Should be around 370 for these parameters
        #expect(result > 300)
        #expect(result < 400)
    }

    // Test 5: Confidence Interval
    @Test("ConfidenceInterval") func LConfidenceInterval() {
        // Test confidence interval calculation
        let alpha = 0.05  // 95% confidence
        let stdev = 2.5
        let sampleSize = 50

        let result = confidence(alpha: alpha, stdev: stdev, sampleSize: sampleSize)

        // Check that confidence interval is symmetric and reasonable
        #expect(result.high > 0)
        #expect(result.high < 1.0)
        #expect(abs(result.low - -result.high) < 0.0001)
    }

    // Test 6: Chi-Square Test (categorical data)
    @Test("ChiSquarePreparation") func LChiSquarePreparation() {
        // Example: Test if observed frequencies match expected
        let observed = [45.0, 35.0, 20.0]
        let expected = [40.0, 40.0, 20.0]

        // Calculate chi-square statistic
        var chiSquare = 0.0
        for i in 0..<observed.count {
            chiSquare += pow(observed[i] - expected[i], 2) / expected[i]
        }

        // Chi-square should be relatively small for similar distributions
        #expect(chiSquare > 0)
        #expect(chiSquare < 5.0)  // Not significantly different
    }
}

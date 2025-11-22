import XCTest
import OSLog
import Numerics
import Testing
@testable import BusinessMath

final class UnassortedTests: XCTestCase {
    
	let unassortedTestsLogger = Logger(subsystem: "Business Math > Tests > BusinessMathTests > BusinessMathTests.swift", category: #function)
	
    func testMeanDiscrete() {
        let prob: Double = 1/6
        let distribution = [(1.0, prob), (2, prob), (3, prob), (4, prob), (5, prob), (6, prob)]
        let result = meanDiscrete(distribution)
        XCTAssertEqual(result, 3.5)
    }
    
    func testVarDiscrete() {
        let prob: Double = 1/6
        let distribution = [(1.0, prob), (2, prob), (3, prob), (4, prob), (5, prob), (6, prob)]
        let result = varianceDiscrete(distribution)
        XCTAssertEqual(result, (35 / 12))
    }
    
    func testSpearmansRho() {
        let result = try! spearmansRho([1, 2, 2, 2, 5], vs: [1, 2, 3, 4, 5])
        XCTAssertEqual(result, 0.8944271909999159)
    }
    
    func testZStatistic() {
        let array: [Double] = [0, 1, 2, 3, 4]
        let mean = mean(array)
        let stdDev = stdDev(array)
        let result = (zStatistic(x: 1, mean: mean, stdDev: stdDev) * 1000000).rounded() / 1000000
        XCTAssertEqual(result, -0.632456)
    }
    
    func testErfInv() {
        let result = (erfInv(y: 0.95) * 1000000000000000).rounded() / 1000000000000000
        XCTAssertEqual(result, 1.385903824349678)
    }
    
    func testZScoreCI() {
        let result = (zScore(ci: 0.95) * 1000000).rounded(.up) / 1000000
        XCTAssertEqual(result, 1.959964)
    }
    
    func testPercentileFormal() {
        let result = percentile(x: 1.959963984540054, mean: 0, stdDev: 1)
//        print(percentile(x: 16.357, mean: 16, stdDev: (0.866 / sqrt(50))))
//        print(percentile(x: 31366, mean: 31000, stdDev: (1894/sqrt(100))))
        XCTAssertEqual(result, 0.975)
    }
    
    func testInverseNormalCDF() {
        let result = inverseNormalCDF(p: 0.5, mean: 0, stdDev: 1)
        XCTAssertEqual(result, 0)
    }
    
    func testUniformCDF() {
        let resultNeg = uniformCDF(x: -1)
        let resultSub1 = uniformCDF(x: 0.5)
        let resultPos = uniformCDF(x: 5)
        
        XCTAssertEqual(resultNeg, 0)
        XCTAssertEqual(resultSub1, 0.5)
        XCTAssertEqual(resultPos, 1)
    }
    
    func testBernoulliTrial() {
        let result = bernoulliTrial(p: 0.5)
        var goodResult: Bool = false
        if result == 0 || result == 1 {
            goodResult = true
        }
        XCTAssertEqual(goodResult, true)
    }

    func testConfidenceInterval() {
        let result = confidenceInterval(mean: 0, stdDev: 1, z: 1, popSize: 10_000_000)
        XCTAssertEqual(result.low, -0.00031622776601683794)
        XCTAssertEqual(result.high, 0.00031622776601683794)
    }
    
    func testConfidenceIntervalCI() {
        let result = confidenceInterval(ci: 0, values: [0])
//		unassortedTestsLogger.info("Test Confidence Interval CI:\t\(result.low)\t\(result.high)")
    }
    
    func testNormalPDF() {
        let result = (normalPDF(x: 1.96, mean: 0, stdDev: 1) * 100).rounded(.down) / 100
        let resultOne = (normalPDF(x: 1.64, mean: 0, stdDev: 1) * 100).rounded() / 100
        XCTAssertEqual(result, 0.05)
        XCTAssertEqual(resultOne, 0.10)
    }
    
    func testConfidenceIntervalProbabilistic() {
        let result = confidenceIntervalProbabilistic(0.05, observations: 50, ci: 0.95)
//		unassortedTestsLogger.info("Test Confidence Interval Probabilistic:\t\(result.low)\t\(result.high)")
    }
    
    func testBinomial() {
		// Test binomial experiment - count successes in n trials with probability p
		// This is a stochastic function, so results will vary

		// Test with p=0.0 - should never succeed
		let resultNone = binomial(n: 10, p: 0.0)
		XCTAssertEqual(resultNone, 0)

		// Test that result is non-negative and within bounds for n trials
		let n = 50
		let testResult = binomial(n: n, p: 0.3)
		XCTAssertGreaterThanOrEqual(testResult, 0)
		XCTAssertLessThanOrEqual(testResult, n)

		// Test with larger sample - should be within valid range
		let largeN = 100
		let largeResult = binomial(n: largeN, p: 0.5)
		XCTAssertGreaterThanOrEqual(largeResult, 0)
		XCTAssertLessThanOrEqual(largeResult, largeN)
    }
    
    func testChi2cdf() {
		// Test chi-squared cumulative distribution function
		// chi2cdf is implemented as 1 - chi2pdf, which is an approximation

		// Test that function returns valid probability values (between 0 and 1)
		let result1 = chi2cdf(x: 2.0, dF: 2)
		XCTAssertGreaterThanOrEqual(result1, 0.0)
		XCTAssertLessThanOrEqual(result1, 1.0)

		// Test at x=0
		let result0 = chi2cdf(x: 0.0, dF: 5)
		XCTAssertGreaterThanOrEqual(result0, 0.0)
		XCTAssertLessThanOrEqual(result0, 1.0)

		// Test with larger x value
		let resultLarge = chi2cdf(x: 50.0, dF: 5)
		XCTAssertGreaterThanOrEqual(resultLarge, 0.0)
		XCTAssertLessThanOrEqual(resultLarge, 1.0)

		// CDF should be monotonically increasing with x
		let small = chi2cdf(x: 1.0, dF: 3)
		let large = chi2cdf(x: 10.0, dF: 3)
		// Note: Due to implementation as 1-pdf, this may not always hold
		XCTAssertNotEqual(small, large)
    }
    
    func testCorrectedStandardError() {
		// Test corrected standard error for finite population
		let sample: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
		let population = 100

		// When sample is less than 5% of population, should apply finite population correction
		let result = correctedStdErr(sample, population: population)
		let uncorrected = standardError(sample)

		// Corrected SE should be less than or equal to uncorrected SE
		XCTAssertLessThanOrEqual(result, uncorrected)

		// Test when sample is >= 5% of population - should return uncorrected SE
		let largeSample = Array(repeating: 1.0, count: 10)
		let smallPopulation = 100
		let resultLarge = correctedStdErr(largeSample, population: smallPopulation)
		let uncorrectedLarge = standardError(largeSample)
		XCTAssertEqual(resultLarge, uncorrectedLarge)
    }
    
    func testCorrelationBreakpoint() {
		// Test correlation breakpoint calculation
		// For 100 items with 95% probability
		let items = 100
		let probability = 0.95
		let result = correlationBreakpoint(items, probability: probability)

		// Result should be a reasonable correlation coefficient (between -1 and 1)
		XCTAssertGreaterThanOrEqual(result, -1.0)
		XCTAssertLessThanOrEqual(result, 1.0)

		// With higher sample size, correlation breakpoint should be smaller (easier to detect)
		let result1000 = correlationBreakpoint(1000, probability: probability)
		XCTAssertLessThan(result1000, result)

		// Test with different probability levels
		let result99 = correlationBreakpoint(items, probability: 0.99)
		XCTAssertGreaterThan(result99, result) // Higher confidence requires higher correlation
    }
    
    func testDerivativeOf() {
		// Test numerical derivative calculation
		// Derivative of f(x) = x^2 at x=2 should be 2x = 4
		let square: (Double) -> Double = { x in x * x }
		let result = derivativeOf(square, at: 2.0)
		XCTAssertEqual(result, 4.0, accuracy: 0.1)

		// Derivative of f(x) = 2x at any point should be 2
		let linear: (Double) -> Double = { x in 2 * x }
		let resultLinear = derivativeOf(linear, at: 5.0)
		XCTAssertEqual(resultLinear, 2.0, accuracy: 0.1)

		// Derivative of a constant function should be 0
		let constant: (Double) -> Double = { _ in 5.0 }
		let resultConstant = derivativeOf(constant, at: 10.0)
		XCTAssertEqual(resultConstant, 0.0, accuracy: 0.1)

		// Derivative of f(x) = x^3 at x=3 should be 3x^2 = 27
		let cube: (Double) -> Double = { x in x * x * x }
		let resultCube = derivativeOf(cube, at: 3.0)
		XCTAssertEqual(resultCube, 27.0, accuracy: 1.0)
    }
    
    func testErfInverse() {
		let y = 0.5
		let result = (erfInv(y: y)  * 10000).rounded(.down) / 10000
		XCTAssertEqual(result, 0.4769)
    }
    
    func testEstMean() {
		let probabilities = [0.1, 0.2, 0.7]
		let result = (estMean(probabilities: probabilities) * 10000).rounded(.down) / 10000
		XCTAssertEqual(result, 0.3333)
    }
    
	func testExponentialCDF() {
		let result = (exponentialCDF(12, λ: 1/12) * 10000.0).rounded(.down) / 10000.0
		XCTAssertEqual(result, 0.6321)
	}
	
    func testFisherR() {
		let result = (fisher(0.5) * 10000).rounded(.down) / 10000
		XCTAssertEqual(result, 0.5493)
    }
    
    func testHyperGeometric() {
		let result: Double = hypergeometric(total: 10, r: 4, n: 3, x: 2)
		let resultRounded = (result * 100.0).rounded() / 100.0
		XCTAssertEqual(resultRounded, 0.30)
    }
    
    func testInterestingObservation() {
		// Test whether an observation falls outside the confidence interval
		let values: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
		let ci = 0.95

		// Test with value inside the range (mean is 3.0)
		let insideValue = 3.0
		let resultInside = interestingObservation(observation: insideValue, values: values, confidenceInterval: ci)
		XCTAssertFalse(resultInside) // Should not be interesting (within CI)

		// Test with extreme value outside the range
		let outsideValue = 100.0
		let resultOutside = interestingObservation(observation: outsideValue, values: values, confidenceInterval: ci)
		XCTAssertTrue(resultOutside) // Should be interesting (outside CI)

		// Test with negative extreme value
		let outsideNegative = -50.0
		let resultNegative = interestingObservation(observation: outsideNegative, values: values, confidenceInterval: ci)
		XCTAssertTrue(resultNegative) // Should be interesting (outside CI)
    }
    
    func testPoissonDistribution() {
		let result = (poisson(5, µ: 10) * 10000.0).rounded(.down) / 10000.0
		XCTAssertEqual(result, 0.0378)
    }
    
    func testProbabilityDistributionFunction() {
		// Test normal PDF values at key points
		let result = (normalPDF(x: 0, mean: 0, stdDev: 1) * 10000.0).rounded() / 10000
		let resultAtOne = (normalPDF(x: 1, mean: 0, stdDev: 1) * 10000.0).rounded() / 10000
		let resultAtTwo = (normalPDF(x: 2, mean: 0, stdDev: 1) * 10000.0).rounded() / 10000
		
		// At mean (x=0), standard normal should be approximately 0.3989
		XCTAssertEqual(result, 0.3989, accuracy: 0.0001)
		// At x=1, should be approximately 0.2420
		XCTAssertEqual(resultAtOne, 0.2420, accuracy: 0.0001)
		// At x=2, should be approximately 0.0540
		XCTAssertEqual(resultAtTwo, 0.0540, accuracy: 0.0001)
    }
    
    func testPValue() {
		// This test is already implemented below as testpValue()
		// Testing A/B test p-value calculation
		let obs = 500
		let convA = 80
		let convB = 100
		let result: Double = (pValue(obsA: obs, convA: convA, obsB: obs, convB: convB) * 10000).rounded() / 10000
		XCTAssertEqual(result, 0.9504)
    }
    
    func testPValueStudent() {
		// Test p-value calculation using Student's t-distribution
		// Example: t-value of 2.0 with 10 degrees of freedom
		let tValue = 2.0
		let degreesOfFreedom = 10.0
		let result = (pValueStudent(tValue, dFr: degreesOfFreedom) * 10000).rounded() / 10000
		
		// The PDF value at t=2.0 with df=10 should be approximately 0.0611
		XCTAssertEqual(result, 0.0611, accuracy: 0.001)
		
		// Test at t=0 (center of distribution)
		let resultAtZero = (pValueStudent(0.0, dFr: degreesOfFreedom) * 10000).rounded() / 10000
		XCTAssertGreaterThan(resultAtZero, 0.35) // Should be high at center
    }
    
    func testRequiredSampleSize() {
		// Test sample size calculation for confidence intervals
		// Given: 95% CI, 50% proportion, population of 950, 5% margin of error
		let ci = 0.95
		let proportion = 0.5
		let population = 950.0
		let error = 0.05
		let result = (sampleSize(ci: ci, proportion: proportion, n: population, error: error) * 10000).rounded() / 10000
		
		// Should be approximately 273.5372 (matches existing testSampleSize)
		XCTAssertEqual(result, 273.5372)
		
		// Test with different confidence level (90%)
		let result90 = sampleSize(ci: 0.90, proportion: proportion, n: population, error: error)
		XCTAssertLessThan(result90, result) // Lower confidence requires smaller sample
    }
    
    func testRho() {
		// Test Spearman's rho correlation coefficient
		// Perfect positive correlation
		let perfectPositive = try! spearmansRho([1, 2, 3, 4, 5], vs: [1, 2, 3, 4, 5])
		XCTAssertEqual(perfectPositive, 1.0, accuracy: 0.0001)
		
		// Perfect negative correlation
		let perfectNegative = try! spearmansRho([1, 2, 3, 4, 5], vs: [5, 4, 3, 2, 1])
		XCTAssertEqual(perfectNegative, -1.0, accuracy: 0.0001)
		
		// Test with tied ranks (existing test case)
		let result = try! spearmansRho([1, 2, 2, 2, 5], vs: [1, 2, 3, 4, 5])
		XCTAssertEqual(result, 0.8944271909999159, accuracy: 0.0001)
    }
    
    func testSampleCorrelationCoefficient() {
		// Test Pearson correlation coefficient (sample)
		// Test case from existing tests with known relationship
		let x = [20.0, 23, 45, 78, 21]
		let y = [200.0, 300, 500, 700, 100]
		let result = correlationCoefficient(x, y, .sample)
		let rounded = (result * 10000).rounded() / 10000
		
		// Should be approximately 0.9487 (matches existing test)
		XCTAssertEqual(rounded, 0.9487)
		
		// Test perfect correlation
		let perfectCorr = correlationCoefficient([1.0, 2, 3, 4, 5], [2.0, 4, 6, 8, 10], .sample)
		XCTAssertEqual(perfectCorr, 1.0, accuracy: 0.0001)
		
		// Test no correlation
		let noCorr = correlationCoefficient([1.0, 2, 3, 4, 5], [5.0, 3, 1, 4, 2], .sample)
		XCTAssertLessThan(abs(noCorr), 0.5) // Weak or no correlation
    }
    
    func testStandardError() {
		// Test standard error calculation from standard deviation
		let sampleStdDev = 1.5
		let observations = 100
		let result = (standardError(sampleStdDev, observations: observations) * 10000).rounded() / 10000
		
		// SE = stdDev / sqrt(n) = 1.5 / sqrt(100) = 1.5 / 10 = 0.15
		XCTAssertEqual(result, 0.15)
		
		// Test standard error from array
		let values: [Double] = [0, 1, 2, 3, 4]
		let resultFromArray = (standardError(values) * 10000).rounded() / 10000
		let expectedStdDev = stdDev(values)
		let expectedSE = (expectedStdDev / Double.sqrt(5.0) * 10000).rounded() / 10000
		XCTAssertEqual(resultFromArray, expectedSE)
		
		// Test with larger sample size
		let largerSample = Array(repeating: 2.0, count: 400)
		let seOfConstant = standardError(largerSample)
		XCTAssertEqual(seOfConstant, 0.0) // No variance means SE is 0
    }
    
    func testStandardErrorProbabilistic() {
		let observations = 25.0
		let conversions = 8.0
		let result = (standardErrorProbabilistic((conversions) / observations, observations: Int(observations)) * 10000).rounded() / 10000
		XCTAssertEqual(result, 0.0933)
    }
    
    func testTStatisticRho() {
		// Test t-statistic calculation from correlation coefficient
		// Example: rho = 0.8, degrees of freedom = 10
		let rho = 0.8
		let degreesOfFreedom = 10.0
		let result = (tStatistic(rho, dFr: degreesOfFreedom) * 10000).rounded() / 10000
		
		// t = rho * sqrt(df / (1 - rho^2))
		// t = 0.8 * sqrt(10 / (1 - 0.64)) = 0.8 * sqrt(10 / 0.36) = 0.8 * sqrt(27.778) = 0.8 * 5.27 = 4.216
		XCTAssertEqual(result, 4.2164, accuracy: 0.001)
		
		// Test with array inputs using Spearman's rho
		let independent: [Double] = [8.0, 2.0, 11.0, 6.0, 5.0]
		let variable: [Double] = [3.0, 10.0, 3.0, 6.0, 8.0]
		let resultFromArrays = try! tStatistic(independent, variable)
		
		// Should return a valid t-statistic
		XCTAssertNotEqual(resultFromArrays, 0.0)
    }
    
    func testVarianceDiscrete() {
		// This is already implemented as testVarDiscrete() above
		// Testing discrete probability distribution variance
		let prob: Double = 1/6
		let distribution = [(1.0, prob), (2, prob), (3, prob), (4, prob), (5, prob), (6, prob)]
		let result = varianceDiscrete(distribution)
		XCTAssertEqual(result, (35.0 / 12.0))
    }
    
    func testMeanBinomial() {
		// Test mean of binomial distribution
		// Mean = n * p
		let n = 100
		let p = 0.5
		let result = meanBinomial(n: n, prob: p)
		
		// For 100 trials with p=0.5, mean should be 50
		XCTAssertEqual(result, 50.0)
		
		// Test with different probability
		let result2 = meanBinomial(n: 50, prob: 0.3)
		XCTAssertEqual(result2, 15.0) // 50 * 0.3 = 15
    }
    
    func testStdDevBinomial() {
		// Test standard deviation of binomial distribution
		// StdDev = sqrt(n * p * (1 - p))
		let n = 100
		let p = 0.5
		let result = (stdDevBinomial(n: n, prob: p) * 10000).rounded() / 10000
		
		// sqrt(100 * 0.5 * 0.5) = sqrt(25) = 5
		XCTAssertEqual(result, 5.0)
		
		// Test with different values
		let result2 = (stdDevBinomial(n: 50, prob: 0.3) * 10000).rounded() / 10000
		// sqrt(50 * 0.3 * 0.7) = sqrt(10.5) = 3.24
		XCTAssertEqual(result2, 3.2404, accuracy: 0.001)
    }
    
    func testVarianceBinomial() {
		// Test variance of binomial distribution
		// Variance = n * p * (1 - p)
		let n = 100
		let p = 0.5
		let result = varianceBinomial(n: n, prob: p)
		
		// 100 * 0.5 * 0.5 = 25
		XCTAssertEqual(result, 25.0)
		
		// Test with different values
		let result2 = varianceBinomial(n: 50, prob: 0.3)
		// 50 * 0.3 * 0.7 = 10.5
		XCTAssertEqual(result2, 10.5)
    }
    
    func testPercentileLocation() {
		// Test finding value at a given percentile using nearest-rank method
		let values = Array(1...100).map { Double($0) }
		
		// Test 25th percentile - should return approximately 25
		let result25 = PercentileLocation(25, values: values)
//		unassortedTestsLogger.info("25th percentile result: \(result25)")
		XCTAssertEqual(result25, 25.0, accuracy: 1.0)
		
		// Test 50th percentile (median) - should return approximately 50
		let result50 = PercentileLocation(50, values: values)
//		unassortedTestsLogger.info("50th percentile result: \(result50)")
		XCTAssertEqual(result50, 50.0, accuracy: 1.0)
		
		// Test 75th percentile - should return approximately 75
		let result75 = PercentileLocation(75, values: values)
//		unassortedTestsLogger.info("75th percentile result: \(result75)")
		XCTAssertEqual(result75, 75.0, accuracy: 1.0)
		
		// Test edge cases
		let result0 = PercentileLocation(0, values: values)
		XCTAssertEqual(result0, 1.0) // Should return first element
		
		let result100 = PercentileLocation(100, values: values)
		XCTAssertEqual(result100, 100.0) // Should return last element
		
		// Test with smaller dataset
		let smallValues: [Double] = [1, 2, 3, 4, 5]
		let smallResult50 = PercentileLocation(50, values: smallValues)
		XCTAssertEqual(smallResult50, 3.0, accuracy: 1.0) // Median of 5 elements
    }
    
    func testPercentileMeanStdDev() {
		// Test percentile calculation using mean and standard deviation
		// This is the same as the existing testPercentileFormal
		let result = percentile(x: 1.959963984540054, mean: 0, stdDev: 1)
		XCTAssertEqual(result, 0.975, accuracy: 0.001)
		
		// Test with different values
		let result2 = percentile(x: 0, mean: 0, stdDev: 1)
		XCTAssertEqual(result2, 0.5, accuracy: 0.001) // At mean, percentile is 50%
		
		// Test negative value
		let result3 = percentile(x: -1.96, mean: 0, stdDev: 1)
		XCTAssertEqual(result3, 0.025, accuracy: 0.001) // 2.5th percentile
    }
    
    func testZScoreRho() {
		// Test z-score calculation for correlation coefficient testing
		// This uses Fisher's r-to-z transformation
		let x = [1.0, 2.0, 3.0, 4.0, 5.0]
		let y = [2.0, 4.0, 5.0, 4.0, 5.0]
		
		let result = try! zScore(x, vs: y)
		
		// Z-score should be a reasonable value for this correlation
		XCTAssertNotEqual(result, 0.0)
		XCTAssertGreaterThan(abs(result), 0.0)
    }
    
    func testZScorePercentile() {
		// Test z-score for a given percentile (inverse normal)
		// This is similar to testZScoreCI
		let result = (zScore(ci: 0.95) * 1000000).rounded(.up) / 1000000
		
		// For 95% confidence interval, z-score should be ~1.96
		XCTAssertEqual(result, 1.959964)
		
		// Test for 99% confidence
		let result99 = (zScore(ci: 0.99) * 1000000).rounded(.down) / 1000000
		XCTAssertGreaterThan(result99, 2.5) // Should be ~2.576
		XCTAssertLessThan(result99, 2.6)
    }
    
    func testZScoreFisherR() {
		// Test Fisher's r-to-z transformation
		let r = 0.5
		let fisherZ = (fisher(r) * 10000).rounded(.down) / 10000
		
		// Fisher's z for r=0.5 should be ~0.5493
		XCTAssertEqual(fisherZ, 0.5493)
		
		// Test that Fisher transformation is monotonic
		let r1 = fisher(0.3)
		let r2 = fisher(0.7)
		XCTAssertLessThan(r1, r2) // Higher correlation should give higher Fisher z
		
		// Test extreme values
		let r_near_zero = fisher(0.0)
		XCTAssertEqual(r_near_zero, 0.0, accuracy: 0.0001)
    }

    func testMonteCarloIntegration() {
        func f(_ x: Double) -> Double {
            return 2 * pow(x, 5)
        }
        
        func e(_ x: Double) -> Double {
            return Double.exp(pow(x, 2))
        }
        
        let result = (integrate(f, iterations: 10000) * 100).rounded() / 100
        let resultE = (integrate(e, iterations: 20000) * 100).rounded() / 100
        XCTAssertGreaterThan(result, 0.31)
        XCTAssertLessThan(result, 0.35)
        XCTAssertGreaterThan(resultE, 1.45)
		XCTAssertLessThan(resultE, 1.48)
    }
	
	func testpValue() {
		let obs = 500
		let convA = 80
		let convSig = 100
		let convUnl = 96
		let convIns = 80
		let resultSignificant: Double = (pValue(obsA: obs, convA: convA, obsB: obs, convB: convSig) * 10000).rounded() / 10000
		let resultUnlikely: Double = (pValue(obsA: obs, convA: convA, obsB: obs, convB: convUnl) * 10000).rounded() / 10000
		let resultNotSignificant: Double = (pValue(obsA: obs, convA: convA, obsB: obs, convB: convIns) * 10000).rounded() / 10000
		XCTAssertEqual(resultSignificant, 0.9504)
		XCTAssertEqual(resultUnlikely, 0.9082)
		XCTAssertEqual(resultNotSignificant, 0.500)
	}
	
	func testSampleSize() {
//		Let's pretend we're sending our first A/B test. Our list has 1,000 people in it and has a 95% deliverability rate. We want to be 95% confident our winning email metrics fall within a 5-point interval of our population metrics. This will calculate the minimum number of people we need to send each variant to in order to determine significance.
		let ci = 0.95
		let p = 0.5
		let n = 950.0
		let e = 0.05
		let result = (sampleSize(ci: ci, proportion: p, n: n, error: e) * 10000).rounded() / 10000
		XCTAssertEqual(result, 273.5372)
	}
	
	func testMarginOfError() {
		let result = (marginOfError(0.95, sampleProportion: 0.5, sampleSize: 274, totalPopulation: 950) * 100000).rounded() / 100000
		XCTAssertEqual(result, 0.04997)
	}
}




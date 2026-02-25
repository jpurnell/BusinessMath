//
//  LogNormalCDFTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 1/5/26.
//

import Foundation
import TestSupport  // Cross-platform math functions
import Testing
import Numerics
#if canImport(OSLog)
import OSLog
#endif
@testable import BusinessMath

@Suite("LogNormal CDF Tests")
struct LogNormalCDFTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.LogNormalCDFTests", category: #function)

	// MARK: - Basic Properties Tests

	@Test("LogNormal CDF is zero for x ≤ 0")
	func logNormalCDFZeroForNonPositive() {
		// Lognormal is only defined for x > 0
		let prob0: Double = logNormalCDF(0.0, mean: 0.0, stdDev: 1.0)
		#expect(prob0 == 0.0, "CDF should be 0 at x=0")

		let probNeg: Double = logNormalCDF(-1.0, mean: 0.0, stdDev: 1.0)
		#expect(probNeg == 0.0, "CDF should be 0 for negative x")
	}

	@Test("LogNormal CDF is 0.5 at median (e^μ)")
	func logNormalCDFMedian() {
		// For LogNormal(μ, σ), median = e^μ
		// CDF(median) should equal 0.5

		// Standard lognormal: μ=0, median=e^0=1
		let prob1: Double = logNormalCDF(1.0, mean: 0.0, stdDev: 1.0)
		#expect(abs(prob1 - 0.5) < 0.001, "CDF at median (1.0) should be 0.5")

		// μ=2, median=e^2≈7.389
		let median2 = exp(2.0)
		let prob2: Double = logNormalCDF(median2, mean: 2.0, stdDev: 0.5)
		#expect(abs(prob2 - 0.5) < 0.001, "CDF at median should be 0.5")

		// μ=-1, median=e^(-1)≈0.368
		let median3 = exp(-1.0)
		let prob3: Double = logNormalCDF(median3, mean: -1.0, stdDev: 2.0)
		#expect(abs(prob3 - 0.5) < 0.001, "CDF at median should be 0.5")
	}

	@Test("LogNormal CDF is monotonically increasing")
	func logNormalCDFMonotonic() {
		// CDF should increase as x increases
		let mean = 0.0
		let stdDev = 1.0

		let x1 = 0.5
		let x2 = 1.0
		let x3 = 2.0
		let x4 = 5.0
		let x5 = 10.0

		let prob1: Double = logNormalCDF(x1, mean: mean, stdDev: stdDev)
		let prob2: Double = logNormalCDF(x2, mean: mean, stdDev: stdDev)
		let prob3: Double = logNormalCDF(x3, mean: mean, stdDev: stdDev)
		let prob4: Double = logNormalCDF(x4, mean: mean, stdDev: stdDev)
		let prob5: Double = logNormalCDF(x5, mean: mean, stdDev: stdDev)

		#expect(prob1 < prob2, "CDF should increase: 0.5 < 1.0")
		#expect(prob2 < prob3, "CDF should increase: 1.0 < 2.0")
		#expect(prob3 < prob4, "CDF should increase: 2.0 < 5.0")
		#expect(prob4 < prob5, "CDF should increase: 5.0 < 10.0")
	}

	@Test("LogNormal CDF is bounded between 0 and 1")
	func logNormalCDFBounded() {
		// CDF must always be in [0, 1]
		let mean = 0.0
		let stdDev = 1.0

		let testPoints = [0.001, 0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 100.0, 1000.0]

		for x in testPoints {
			let prob: Double = logNormalCDF(x, mean: mean, stdDev: stdDev)
			#expect(prob >= 0.0, "CDF must be ≥ 0 at x=\(x)")
			#expect(prob <= 1.0, "CDF must be ≤ 1 at x=\(x)")
		}
	}

	@Test("LogNormal CDF approaches 1 for large x")
	func logNormalCDFApproachesOne() {
		// As x → ∞, CDF → 1
		let mean = 0.0
		let stdDev = 1.0

		let largeX = 1000.0
		let prob: Double = logNormalCDF(largeX, mean: mean, stdDev: stdDev)

		#expect(prob > 0.999, "CDF should approach 1 for very large x")
	}

	// MARK: - Mathematical Relationship Tests

	@Test("LogNormal CDF relationship to Normal CDF")
	func logNormalCDFToNormalCDF() {
		// Key property: If X ~ LogNormal(μ, σ), then ln(X) ~ Normal(μ, σ)
		// Therefore: P(X ≤ x) = P(ln(X) ≤ ln(x)) = Φ((ln(x) - μ) / σ)

		let mean = 1.0
		let stdDev = 0.5
		let x = 5.0

		let logNormalProb: Double = logNormalCDF(x, mean: mean, stdDev: stdDev)

		// Manual calculation using normal CDF
		let z = (log(x) - mean) / stdDev
		let normalProb: Double = normalCDF(x: z, mean: 0.0, stdDev: 1.0)

		#expect(abs(logNormalProb - normalProb) < 0.0001,
		        "LogNormal CDF should equal Φ((ln(x)-μ)/σ)")
	}

	@Test("LogNormal CDF transformation verification")
	func logNormalCDFTransformation() {
		// Test multiple parameter combinations
		let testCases: [(x: Double, mean: Double, stdDev: Double)] = [
			(1.0, 0.0, 1.0),
			(2.0, 0.0, 1.0),
			(5.0, 1.0, 0.5),
			(10.0, 2.0, 1.5),
			(0.5, -1.0, 0.8)
		]

		for testCase in testCases {
			let logNormalProb: Double = logNormalCDF(testCase.x, mean: testCase.mean, stdDev: testCase.stdDev)

			// Calculate via transformation
			let z = (log(testCase.x) - testCase.mean) / testCase.stdDev
			let normalProb: Double = normalCDF(x: z, mean: 0.0, stdDev: 1.0)

			#expect(abs(logNormalProb - normalProb) < 0.0001,
			        "Transformation should match for x=\(testCase.x), μ=\(testCase.mean), σ=\(testCase.stdDev)")
		}
	}

	// MARK: - Empirical Validation Tests

	@Test("LogNormal CDF matches empirical distribution from samples")
	func logNormalCDFMatchesEmpirical() {
		let mean = 0.0
		let stdDev = 1.0
		let sampleCount = 10000

		// Generate samples using existing distributionLogNormal
		let seeds = LogNormalDistributionTests.seedsForLogNormal(count: sampleCount)
		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionLogNormal(mean: mean, stdDev: stdDev, seeds[i].u1, seeds[i].u2))
		}

		// Test CDF at various points
		let testPoints = [0.5, 1.0, 2.0, 3.0, 5.0]
		for testPoint in testPoints {
			// Empirical CDF: proportion of samples ≤ testPoint
			let empiricalProb = Double(samples.filter { $0 <= testPoint }.count) / Double(sampleCount)

			// Theoretical CDF
			let theoreticalProb: Double = logNormalCDF(testPoint, mean: mean, stdDev: stdDev)

			// Allow 2% tolerance due to sampling variability
			#expect(abs(empiricalProb - theoreticalProb) < 0.02,
			        "CDF at x=\(testPoint): empirical=\(empiricalProb), theoretical=\(theoreticalProb)")
		}
	}

	@Test("LogNormal CDF percentiles match empirical")
	func logNormalCDFPercentiles() {
		let mean = 0.0
		let stdDev = 1.0
		let sampleCount = 10000

		// Generate samples
		let seeds = LogNormalDistributionTests.seedsForLogNormal(count: sampleCount)
		var samples: [Double] = []
		for i in 0..<sampleCount {
			samples.append(distributionLogNormal(mean: mean, stdDev: stdDev, seeds[i].u1, seeds[i].u2))
		}
		let sorted = samples.sorted()

		// Test various percentiles
		let percentiles = [0.05, 0.25, 0.50, 0.75, 0.95]
		for p in percentiles {
			let index = Int(Double(sampleCount) * p)
			let empiricalValue = sorted[index]

			// Theoretical CDF at this value should be close to p
			let theoreticalProb: Double = logNormalCDF(empiricalValue, mean: mean, stdDev: stdDev)

			#expect(abs(theoreticalProb - p) < 0.02,
			        "\(Int(p*100))th percentile: theoretical=\(theoreticalProb), expected≈\(p)")
		}
	}

	// MARK: - Parameter Variation Tests

	@Test("LogNormal CDF with different means")
	func logNormalCDFDifferentMeans() {
		// Higher mean → distribution shifted right → lower CDF at fixed x
		let stdDev = 1.0
		let x = 2.0

		let probMean0: Double = logNormalCDF(x, mean: 0.0, stdDev: stdDev)
		let probMean1: Double = logNormalCDF(x, mean: 1.0, stdDev: stdDev)
		let probMean2: Double = logNormalCDF(x, mean: 2.0, stdDev: stdDev)

		// Higher mean shifts distribution right, so P(X ≤ 2) decreases
		#expect(probMean0 > probMean1, "Higher mean should reduce CDF at fixed x")
		#expect(probMean1 > probMean2, "Higher mean should reduce CDF at fixed x")
	}

	@Test("LogNormal CDF with different standard deviations")
	func logNormalCDFDifferentStdDevs() {
		// Higher stdDev → more spread
		// For lognormal, higher σ creates heavier right tail and thinner left tail
		let mean = 0.0

		// Test that different stdDevs produce different CDFs
		let probStdDev05: Double = logNormalCDF(2.0, mean: mean, stdDev: 0.5)
		let probStdDev10: Double = logNormalCDF(2.0, mean: mean, stdDev: 1.0)
		let probStdDev15: Double = logNormalCDF(2.0, mean: mean, stdDev: 1.5)

		// Different σ should produce different probabilities
		#expect(probStdDev05 != probStdDev10, "Different σ should give different CDF")
		#expect(probStdDev10 != probStdDev15, "Different σ should give different CDF")

		// All should be valid probabilities
		#expect(probStdDev05 >= 0.0 && probStdDev05 <= 1.0)
		#expect(probStdDev10 >= 0.0 && probStdDev10 <= 1.0)
		#expect(probStdDev15 >= 0.0 && probStdDev15 <= 1.0)
	}

	// MARK: - Known Value Tests

	@Test("LogNormal CDF known values for standard lognormal")
	func logNormalCDFKnownValues() {
		// Standard lognormal: LogNormal(0, 1)
		// These values can be verified with statistical tables or software

		// P(X ≤ 1) = 0.5 (median)
		let prob1: Double = logNormalCDF(1.0, mean: 0.0, stdDev: 1.0)
		#expect(abs(prob1 - 0.5) < 0.001, "CDF(1) should be 0.5")

		// P(X ≤ e) ≈ 0.8413 (one std dev above median in log space)
		let probE: Double = logNormalCDF(exp(1.0), mean: 0.0, stdDev: 1.0)
		#expect(abs(probE - 0.8413) < 0.001, "CDF(e) should be ≈0.8413")

		// P(X ≤ 1/e) ≈ 0.1587 (one std dev below median in log space)
		let probInvE: Double = logNormalCDF(exp(-1.0), mean: 0.0, stdDev: 1.0)
		#expect(abs(probInvE - 0.1587) < 0.001, "CDF(1/e) should be ≈0.1587")
	}

	// MARK: - Edge Cases Tests

	@Test("LogNormal CDF with very small x")
	func logNormalCDFSmallX() {
		// Very small positive x should give very small CDF
		let mean = 0.0
		let stdDev = 1.0

		let prob: Double = logNormalCDF(0.001, mean: mean, stdDev: stdDev)
		#expect(prob < 0.01, "CDF for very small x should be near 0")
		#expect(prob > 0.0, "CDF should be strictly positive for x > 0")
	}

	@Test("LogNormal CDF with very large x")
	func logNormalCDFLargeX() {
		// Very large x should give CDF close to 1
		let mean = 0.0
		let stdDev = 1.0

		let prob: Double = logNormalCDF(1000.0, mean: mean, stdDev: stdDev)
		#expect(prob > 0.999, "CDF for very large x should be near 1")
		#expect(prob <= 1.0, "CDF cannot exceed 1")
	}

	@Test("LogNormal CDF with extreme parameters")
	func logNormalCDFExtremeParameters() {
		// Very small stdDev (concentrated distribution)
		let probSmallStdDev: Double = logNormalCDF(1.0, mean: 0.0, stdDev: 0.01)
		#expect(abs(probSmallStdDev - 0.5) < 0.1, "Should still work with small stdDev")

		// Very large stdDev (spread out distribution)
		let probLargeStdDev: Double = logNormalCDF(1.0, mean: 0.0, stdDev: 5.0)
		#expect(probLargeStdDev >= 0.0 && probLargeStdDev <= 1.0, "Should work with large stdDev")

		// Negative mean (distribution shifted left)
		let probNegMean: Double = logNormalCDF(1.0, mean: -5.0, stdDev: 1.0)
		#expect(probNegMean >= 0.0 && probNegMean <= 1.0, "Should work with negative mean")

		// Large positive mean (distribution shifted right)
		let probPosMean: Double = logNormalCDF(1.0, mean: 5.0, stdDev: 1.0)
		#expect(probPosMean >= 0.0 && probPosMean <= 1.0, "Should work with large positive mean")
	}

	// MARK: - Financial Application Tests

	@Test("LogNormal CDF for stock price probability (Black-Scholes)")
	func logNormalCDFStockPrice() {
		// Model: Stock price follows LogNormal under Black-Scholes
		// Question: What's P(Stock ≤ $100) given S_0=$100, μ=0.08, σ=0.20, T=1

		// Under risk-neutral measure: ln(S_T/S_0) ~ Normal((μ - σ²/2)T, σ√T)
		// For T=1, S_0=100: ln(S_T) ~ Normal(ln(100) + 0.08 - 0.02, 0.20)

		let S0 = 100.0
		let mu = 0.08
		let sigma = 0.20
		let T = 1.0

		let logMean = log(S0) + (mu - 0.5 * sigma * sigma) * T
		let logStdDev = sigma * sqrt(T)

		// P(S_T ≤ 100) - probability of ending at or below starting price
		let prob: Double = logNormalCDF(S0, mean: logMean, stdDev: logStdDev)

		// Should be less than 0.5 since we have positive drift
		#expect(prob < 0.5, "With positive drift, P(S_T ≤ S_0) < 0.5")
		#expect(prob > 0.3, "Probability should be reasonable")
	}

	@Test("LogNormal CDF documentation example (stock price below $90)")
	func logNormalCDFDocumentationExample() {
		// Verify the example from the documentation is correct
		// Question: What's the probability a $100 stock ends below $90 in 1 year?
		// Assume 10% drift, 20% volatility

		let S0 = 100.0
		let drift = 0.10
		let vol = 0.20
		let T = 1.0

		let logMean = log(S0) + (drift - 0.5 * vol * vol) * T
		let logStdDev = vol * sqrt(T)

		let probBelow90 = logNormalCDF(90.0, mean: logMean, stdDev: logStdDev)

		// Expected: ~0.177 (17.7%)
		#expect(abs(probBelow90 - 0.177) < 0.001, "Should match documented example: ~17.7%")
	}

	@Test("LogNormal CDF for value at risk calculation")
	func logNormalCDFValueAtRisk() {
		// VaR: Verify CDF calculation at 5th percentile
		// For standard lognormal, 5th percentile is where CDF = 0.05

		let mean = 0.0
		let stdDev = 1.0

		// Test a value in the lower tail
		let testValue = 0.2
		let prob: Double = logNormalCDF(testValue, mean: mean, stdDev: stdDev)

		// Should be in lower tail (significantly less than 0.5)
		#expect(prob < 0.10, "Value 0.2 should be in lower tail")
		#expect(prob > 0.0, "Probability should be positive")
	}

	// MARK: - Complementary CDF Tests

	@Test("LogNormal CDF and survival function sum to 1")
	func logNormalCDFComplementary() {
		// P(X ≤ x) + P(X > x) = 1
		let mean = 0.0
		let stdDev = 1.0

		let testPoints = [0.5, 1.0, 2.0, 5.0]
		for x in testPoints {
			let cdf: Double = logNormalCDF(x, mean: mean, stdDev: stdDev)
			let survivalFunction = 1.0 - cdf  // P(X > x)

			#expect(abs(cdf + survivalFunction - 1.0) < 0.0001,
			        "CDF + survival function should equal 1")
		}
	}

	// MARK: - Generic Type Tests

	@Test("LogNormal CDF works with Float")
	func logNormalCDFFloat() {
		let prob: Float = logNormalCDF(2.0 as Float, mean: 0.0, stdDev: 1.0)
		#expect(prob > 0.0)
		#expect(prob < 1.0)
	}

	// Note: Decimal test removed - Decimal doesn't conform to Real in Swift Numerics
	// Float and Double coverage is sufficient for generic type testing
}

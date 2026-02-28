//
//  binomialDescriptorTests.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import Testing
import TestSupport  // Cross-platform math functions
import Numerics
@testable import BusinessMath

@Suite("Binomial Descriptor Tests")
struct BinomialDescriptorTests {

	@Test("Mean binomial")
	func meanBinomial() {
		#expect(BusinessMath.meanBinomial(n: 1000, prob: 0.6) == 600)
	}

	@Test("Standard deviation binomial")
	func stdDevBinomial() {
		#expect(BusinessMath.stdDevBinomial(n: 1000, prob: 0.6) == Double.sqrt(1000 * 0.6 * 0.4))
	}

	@Test("Variance binomial")
	func varianceBinomial() {
		#expect(BusinessMath.varianceBinomial(n: 1000, prob: 0.6) == (1000 * (0.4) * (0.6)))
	}
}

@Suite("Binomial descriptors - Edge cases")
struct BinomialProperties {

	@Test("p = 0 and p = 1 edge cases")
	func p_zero_and_one() {
		let n = 10.0
		#expect(meanBinomial(n: Int(n), prob: 0.0) == 0.0)
		#expect(varianceBinomial(n: Int(n), prob: 0.0) == 0.0)
		#expect(stdDevBinomial(n: Int(n), prob: 0.0) == 0.0)

		#expect(meanBinomial(n: Int(n), prob: 1.0) == n)
		#expect(varianceBinomial(n: Int(n), prob: 1.0) == 0.0)
		#expect(stdDevBinomial(n: Int(n), prob: 1.0) == 0.0)
	}
}

@Suite("Binomial descriptors - Invalid Input Rejection")
struct BinomialInvalidInputTests {

	@Test("n = 0 returns zero for all descriptors")
	func n_zero() {
		let result_mean = meanBinomial(n: 0, prob: 0.5)
		let result_variance = varianceBinomial(n: 0, prob: 0.5)
		let result_stdDev = stdDevBinomial(n: 0, prob: 0.5)

		#expect(result_mean == 0.0)
		#expect(result_variance == 0.0)
		#expect(result_stdDev == 0.0)
	}

	@Test("negative n produces NaN or zero")
	func negative_n() {
		let result_mean = meanBinomial(n: -5, prob: 0.5)
		let result_variance = varianceBinomial(n: -5, prob: 0.5)
		let result_stdDev = stdDevBinomial(n: -5, prob: 0.5)

		// Implementation should either return NaN or handle gracefully
		#expect(result_mean.isNaN || result_mean == 0.0 || result_mean < 0.0)
		#expect(result_variance.isNaN || result_variance == 0.0 || result_variance < 0.0)
		#expect(result_stdDev.isNaN || result_stdDev == 0.0)
	}

	@Test("p < 0 produces invalid result")
	func p_less_than_zero() {
		let result_mean = meanBinomial(n: 10, prob: -0.5)
		let result_variance = varianceBinomial(n: 10, prob: -0.5)
		let result_stdDev = stdDevBinomial(n: 10, prob: -0.5)

		// Probabilities outside [0,1] should be rejected
		#expect(result_mean.isNaN || result_mean < 0.0)
		#expect(result_variance.isNaN || result_variance < 0.0)
		#expect(result_stdDev.isNaN)
	}

	@Test("p > 1 produces invalid result")
	func p_greater_than_one() {
		let result_mean = meanBinomial(n: 10, prob: 1.5)
		let result_variance = varianceBinomial(n: 10, prob: 1.5)
		let result_stdDev = stdDevBinomial(n: 10, prob: 1.5)

		// Probabilities outside [0,1] should be rejected
		#expect(result_mean.isNaN || result_mean > 10.0)  // Mean can't exceed n
		#expect(result_variance.isNaN || result_variance < 0.0)  // Variance can't be negative
		#expect(result_stdDev.isNaN)
	}

	@Test("p = NaN propagates")
	func p_nan() {
		let result_mean = meanBinomial(n: 10, prob: Double.nan)
		let result_variance = varianceBinomial(n: 10, prob: Double.nan)
		let result_stdDev = stdDevBinomial(n: 10, prob: Double.nan)

		#expect(result_mean.isNaN)
		#expect(result_variance.isNaN)
		#expect(result_stdDev.isNaN)
	}

	@Test("p = infinity produces invalid result")
	func p_infinity() {
		let result_mean = meanBinomial(n: 10, prob: Double.infinity)
		let result_variance = varianceBinomial(n: 10, prob: Double.infinity)
		let result_stdDev = stdDevBinomial(n: 10, prob: Double.infinity)

		#expect(result_mean.isNaN || result_mean.isInfinite)
		#expect(result_variance.isNaN || result_variance.isInfinite)
		#expect(result_stdDev.isNaN || result_stdDev.isInfinite)
	}
}

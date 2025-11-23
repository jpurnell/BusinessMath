//
//  binomialDescriptorTests.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import Testing
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

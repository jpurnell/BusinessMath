//
//  Combination And Permutation Tests.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import Testing
import Numerics
@testable import BusinessMath

@Suite("Combination and Permutation Tests")
struct CombinationAndPermutationTests {
	@Test("Factorial function and extension")
	func factorial() {
		let result = BusinessMath.factorial(4)
		let resultZero = BusinessMath.factorial(0)
		let resultOne = BusinessMath.factorial(1)
		let resultExtension = 5.factorial()
		#expect(result == 24)
		#expect(resultZero == 1)
		#expect(resultOne == 1)
		#expect(resultExtension == 120)
	}

	@Test("Combination calculation")
	func combination() {
		let result = BusinessMath.combination(10, c: 3)
		#expect(result == 120)
	}

	@Test("Permutation calculation")
	func permutation() {
		let result = BusinessMath.permutation(5, p: 3)
		#expect(result == 60)
	}
}

import Testing
import Foundation
@testable import BusinessMath

@Suite("Regularized Incomplete Beta Function")
struct RegularizedIncompleteBetaTests {

	// MARK: - Boundary Values

	@Test("I_0(a,b) = 0 for any a, b > 0")
	func testZeroBoundary() throws {
		let result: Double = try regularizedIncompleteBeta(x: 0.0, a: 2.0, b: 3.0)
		#expect(abs(result - 0.0) < 1e-6)
	}

	@Test("I_1(a,b) = 1 for any a, b > 0")
	func testOneBoundary() throws {
		let result: Double = try regularizedIncompleteBeta(x: 1.0, a: 2.0, b: 3.0)
		#expect(abs(result - 1.0) < 1e-6)
	}

	@Test("I_0.5(1,1) = 0.5 (Uniform distribution median)")
	func testUniformMedian() throws {
		let result: Double = try regularizedIncompleteBeta(x: 0.5, a: 1.0, b: 1.0)
		#expect(abs(result - 0.5) < 1e-12)
	}

	@Test("I_x(1,1) = x (Uniform CDF is identity)")
	func testUniformCDFIsIdentity() throws {
		for x in stride(from: 0.1, through: 0.9, by: 0.1) {
			let result: Double = try regularizedIncompleteBeta(x: x, a: 1.0, b: 1.0)
			#expect(abs(result - x) < 1e-12, "Expected \(x), got \(result)")
		}
	}

	// MARK: - Symmetry Identity

	@Test("I_x(a,b) + I_{1-x}(b,a) = 1")
	func testSymmetryIdentity() throws {
		let testCases: [(x: Double, a: Double, b: Double)] = [
			(0.3, 2.0, 5.0),
			(0.7, 3.0, 2.0),
			(0.1, 0.5, 0.5),
			(0.9, 10.0, 3.0),
			(0.5, 4.0, 4.0),
		]

		for tc in testCases {
			let forward: Double = try regularizedIncompleteBeta(x: tc.x, a: tc.a, b: tc.b)
			let complement: Double = try regularizedIncompleteBeta(x: 1.0 - tc.x, a: tc.b, b: tc.a)
			#expect(abs(forward + complement - 1.0) < 1e-10,
				"Symmetry failed for x=\(tc.x), a=\(tc.a), b=\(tc.b): \(forward) + \(complement) ≠ 1")
		}
	}

	// MARK: - Known Reference Values (scipy.special.betainc)

	@Test("I_0.3(2,5) ≈ 0.579825 (binomial sum verification)")
	func testKnownValue_2_5() throws {
		let result: Double = try regularizedIncompleteBeta(x: 0.3, a: 2.0, b: 5.0)
		#expect(abs(result - 0.579825) < 1e-10)
	}

	@Test("I_0.5(2,3) = 0.6875 (exact for integer params)")
	func testKnownValue_2_3() throws {
		let result: Double = try regularizedIncompleteBeta(x: 0.5, a: 2.0, b: 3.0)
		#expect(abs(result - 0.6875) < 1e-12)
	}

	@Test("I_0.1(3,7) ≈ 0.052972138 (binomial sum verification)")
	func testKnownValue_3_7() throws {
		let result: Double = try regularizedIncompleteBeta(x: 0.1, a: 3.0, b: 7.0)
		#expect(abs(result - 0.052972138) < 1e-8)
	}

	@Test("I_0.6(5,5) ≈ 0.73343232 (binomial sum verification)")
	func testKnownValue_5_5() throws {
		let result: Double = try regularizedIncompleteBeta(x: 0.6, a: 5.0, b: 5.0)
		#expect(abs(result - 0.73343232) < 1e-7)
	}

	// MARK: - Large Parameters (Stability)

	@Test("I_0.5(100,100) ≈ 0.5 (symmetric, large params)")
	func testLargeParametersSymmetric() throws {
		let result: Double = try regularizedIncompleteBeta(x: 0.5, a: 100.0, b: 100.0)
		#expect(abs(result - 0.5) < 1e-8)
	}

	@Test("I_0.3(50,80) converges (large asymmetric params)")
	func testLargeParametersAsymmetric() throws {
		let result: Double = try regularizedIncompleteBeta(x: 0.3, a: 50.0, b: 80.0)
		// For Beta(50,80), mean = 50/130 ≈ 0.385, so CDF at 0.3 should be < 0.5
		#expect(result > 0.0 && result < 0.5)
	}

	// MARK: - Small x Values

	@Test("I_0.001(2,3) ≈ 5.992003e-6 (very small x)")
	func testVerySmallX() throws {
		let result: Double = try regularizedIncompleteBeta(x: 0.001, a: 2.0, b: 3.0)
		#expect(abs(result - 5.992003e-6) < 1e-9)
	}

	// MARK: - Special Shape Parameters

	@Test("I_x(1, b) = 1 - (1-x)^b (closed form)")
	func testAlphaOne() throws {
		let x = 0.4
		let b = 3.0
		let expected = 1.0 - pow(1.0 - x, b)
		let result: Double = try regularizedIncompleteBeta(x: x, a: 1.0, b: b)
		#expect(abs(result - expected) < 1e-12)
	}

	@Test("I_x(a, 1) = x^a (closed form)")
	func testBetaOne() throws {
		let x = 0.4
		let a = 3.0
		let expected = pow(x, a)
		let result: Double = try regularizedIncompleteBeta(x: x, a: a, b: 1.0)
		#expect(abs(result - expected) < 1e-12)
	}

	// MARK: - Error Cases

	@Test("x < 0 throws invalidInput")
	func testNegativeXThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try regularizedIncompleteBeta(x: -0.1, a: 2.0, b: 3.0)
		}
	}

	@Test("x > 1 throws invalidInput")
	func testXGreaterThanOneThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try regularizedIncompleteBeta(x: 1.1, a: 2.0, b: 3.0)
		}
	}

	@Test("a ≤ 0 throws invalidInput")
	func testNonPositiveAThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try regularizedIncompleteBeta(x: 0.5, a: 0.0, b: 3.0)
		}
	}

	@Test("b ≤ 0 throws invalidInput")
	func testNonPositiveBThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try regularizedIncompleteBeta(x: 0.5, a: 2.0, b: -1.0)
		}
	}
}

// MARK: - Log Beta Tests

@Suite("Log Beta Function")
struct LogBetaTests {

	@Test("logBeta(1, 1) = 0 (B(1,1) = 1)")
	func testLogBetaOneOne() {
		let result: Double = logBeta(1.0, 1.0)
		#expect(abs(result - 0.0) < 1e-12)
	}

	@Test("logBeta(a, b) = logBeta(b, a) (symmetric)")
	func testSymmetry() {
		let result1: Double = logBeta(3.0, 5.0)
		let result2: Double = logBeta(5.0, 3.0)
		#expect(abs(result1 - result2) < 1e-12)
	}

	@Test("logBeta(2, 3) = ln(1/12) (known value)")
	func testKnownValue() {
		// B(2,3) = Γ(2)Γ(3)/Γ(5) = 1×2/24 = 1/12
		let expected = log(1.0 / 12.0)
		let result: Double = logBeta(2.0, 3.0)
		#expect(abs(result - expected) < 1e-12)
	}

	@Test("exp(logBeta(0.5, 0.5)) ≈ π (B(1/2, 1/2) = π)")
	func testHalfHalf() {
		let result: Double = logBeta(0.5, 0.5)
		#expect(abs(exp(result) - Double.pi) < 1e-10)
	}
}

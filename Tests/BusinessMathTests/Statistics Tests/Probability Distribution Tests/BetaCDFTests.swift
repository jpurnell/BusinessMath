import Testing
import Foundation
@testable import BusinessMath

@Suite("Beta Distribution CDF")
struct BetaCDFTests {

	// MARK: - Known Values

	@Test("betaCDF(x: 0.5, alpha: 1, beta: 1) = 0.5 (uniform distribution)")
	func testUniform() throws {
		let result: Double = try betaCDF(x: 0.5, alpha: 1.0, beta: 1.0)
		#expect(abs(result - 0.5) < 1e-12)
	}

	@Test("betaCDF(x: 0, alpha: 2, beta: 2) = 0 (CDF at lower bound)")
	func testLowerBound() throws {
		let result: Double = try betaCDF(x: 0.0, alpha: 2.0, beta: 2.0)
		#expect(abs(result - 0.0) < 1e-12)
	}

	@Test("betaCDF(x: 1, alpha: 2, beta: 2) = 1 (CDF at upper bound)")
	func testUpperBound() throws {
		let result: Double = try betaCDF(x: 1.0, alpha: 2.0, beta: 2.0)
		#expect(abs(result - 1.0) < 1e-12)
	}

	// MARK: - Consistency with regularizedIncompleteBeta

	@Test("betaCDF matches regularizedIncompleteBeta for same inputs")
	func testMatchesUnderlying() throws {
		let testCases: [(Double, Double, Double)] = [
			(0.3, 2.0, 5.0),
			(0.7, 3.0, 2.0),
			(0.5, 1.5, 1.5),
			(0.1, 0.5, 0.5)
		]
		for (x, a, b) in testCases {
			let betaResult: Double = try betaCDF(x: x, alpha: a, beta: b)
			let ibetaResult: Double = try regularizedIncompleteBeta(x: x, a: a, b: b)
			#expect(abs(betaResult - ibetaResult) < 1e-14,
				"Mismatch at x=\(x), a=\(a), b=\(b): \(betaResult) vs \(ibetaResult)")
		}
	}

	// MARK: - Cross-validated Known Value

	@Test("betaCDF(x: 0.3, alpha: 2, beta: 5) ≈ 0.5798 (reference value)")
	func testKnownValue() throws {
		// Beta(2,5) CDF at x=0.3: I_0.3(2,5) ≈ 0.57969
		let result: Double = try betaCDF(x: 0.3, alpha: 2.0, beta: 5.0)
		#expect(abs(result - 0.5798) < 0.005)
	}

	// MARK: - Error Cases

	@Test("x < 0 throws invalidInput")
	func testNegativeXThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try betaCDF(x: -0.1, alpha: 2.0, beta: 2.0)
		}
	}

	@Test("x > 1 throws invalidInput")
	func testXAboveOneThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try betaCDF(x: 1.1, alpha: 2.0, beta: 2.0)
		}
	}

	@Test("alpha ≤ 0 throws invalidInput")
	func testNonPositiveAlphaThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try betaCDF(x: 0.5, alpha: 0.0, beta: 2.0)
		}
	}

	@Test("beta ≤ 0 throws invalidInput")
	func testNonPositiveBetaThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try betaCDF(x: 0.5, alpha: 2.0, beta: 0.0)
		}
	}
}

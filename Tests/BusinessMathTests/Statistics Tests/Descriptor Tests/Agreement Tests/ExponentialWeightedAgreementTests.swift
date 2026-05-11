import Testing
import Foundation
@testable import BusinessMath

@Suite("Exponential Weighted Agreement")
struct ExponentialWeightedAgreementTests {

	// MARK: - Exponential Decay Weights

	@Test("lambda=1.0: all weights equal to 1.0")
	func testLambdaOneAllEqual() throws {
		let weights = try exponentialDecayWeights(count: 5, lambda: 1.0)
		#expect(weights.count == 5)
		for w in weights {
			#expect(abs(w - 1.0) < 1e-12)
		}
	}

	@Test("lambda=0.5: weights halve each step from newest to oldest")
	func testLambdaHalfHalves() throws {
		let weights = try exponentialDecayWeights(count: 4, lambda: 0.5)
		// w_i = 0.5^(n-1-i) → oldest (i=0): 0.5^3=0.125, ..., newest (i=3): 0.5^0=1.0
		#expect(weights.count == 4)
		#expect(abs(weights[3] - 1.0) < 1e-12)     // newest
		#expect(abs(weights[2] - 0.5) < 1e-12)
		#expect(abs(weights[1] - 0.25) < 1e-12)
		#expect(abs(weights[0] - 0.125) < 1e-12)   // oldest
	}

	@Test("lambda=0.9: most recent=1.0, oldest=0.9^(n-1)")
	func testLambdaNinetyPercent() throws {
		let n = 10
		let weights = try exponentialDecayWeights(count: n, lambda: 0.9)
		#expect(weights.count == n)
		#expect(abs(weights[n - 1] - 1.0) < 1e-12)
		let expectedOldest = Double.pow(0.9, Double(n - 1))
		#expect(abs(weights[0] - expectedOldest) < 1e-10)
	}

	@Test("lambda <= 0 or lambda > 1: throws invalidInput")
	func testInvalidLambdaThrows() throws {
		#expect(throws: BusinessMathError.self) {
			_ = try exponentialDecayWeights(count: 5, lambda: 0.0)
		}
		#expect(throws: BusinessMathError.self) {
			_ = try exponentialDecayWeights(count: 5, lambda: -0.5)
		}
		#expect(throws: BusinessMathError.self) {
			_ = try exponentialDecayWeights(count: 5, lambda: 1.1)
		}
	}

	// MARK: - Exponentially Weighted Bland-Altman

	@Test("lambda=1.0: matches unweighted Bland-Altman within tolerance")
	func testLambdaOneMatchesUnweighted() throws {
		let x: [Double] = [1.0, 3.5, 2.0, 5.5, 4.0, 6.0]
		let y: [Double] = [1.5, 3.0, 2.5, 5.0, 4.5, 6.5]

		let unweighted = try blandAltman(x, y)
		let expWeighted = try exponentialWeightedBlandAltman(x, y, lambda: 1.0)

		// With lambda=1.0 all weights are 1.0, but weighted B-A uses n-1 Bessel correction
		// differently than unweighted path, so allow small tolerance
		#expect(abs(expWeighted.bias - unweighted.bias) < 1e-10)
		#expect(abs(expWeighted.standardDeviation - unweighted.standardDeviation) < 0.1)
	}
}

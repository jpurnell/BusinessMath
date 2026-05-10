import Testing
import Foundation
@testable import BusinessMath

@Suite("Weighted Bland-Altman Analysis")
struct WeightedBlandAltmanTests {

	// MARK: - Equal Weights → Matches Unweighted

	@Test("Equal weights match unweighted Bland-Altman within 1e-10")
	func testEqualWeightsMatchUnweighted() throws {
		let x = [10.0, 20.0, 30.0, 40.0, 50.0]
		let y = [12.0, 18.0, 33.0, 38.0, 52.0]
		let weights = Array(repeating: 1.0, count: x.count)
		let weighted = try blandAltman(x, y, weights: weights)
		let unweighted = try blandAltman(x, y)

		#expect(abs(weighted.bias - unweighted.bias) < 1e-10)
		#expect(abs(weighted.standardDeviation - unweighted.standardDeviation) < 1e-10)
		#expect(abs(weighted.loaLower - unweighted.loaLower) < 1e-10)
		#expect(abs(weighted.loaUpper - unweighted.loaUpper) < 1e-10)
	}

	// MARK: - Heavy Weight on Zero-Difference Pair

	@Test("Heavy weight on zero-difference pair moves bias toward 0")
	func testHeavyWeightOnZeroDifferencePair() throws {
		// Pair 0: diff = 10 - 12 = -2
		// Pair 1: diff = 20 - 20 =  0  ← zero difference
		// Pair 2: diff = 30 - 33 = -3
		let x = [10.0, 20.0, 30.0]
		let y = [12.0, 20.0, 33.0]

		let equalWeights = [1.0, 1.0, 1.0]
		let equalResult = try blandAltman(x, y, weights: equalWeights)

		// Heavy weight on the zero-difference pair
		let heavyWeights = [1.0, 100.0, 1.0]
		let heavyResult = try blandAltman(x, y, weights: heavyWeights)

		#expect(abs(heavyResult.bias) < abs(equalResult.bias))
	}

	// MARK: - All Weight on Same-Difference Pairs

	@Test("All weight on pairs with same difference → SD approaches 0")
	func testAllWeightOnSameDifferencePairs() throws {
		// Pairs with diff = -2: indices 0 and 3
		// Pairs with diff != -2: indices 1 and 2
		let x = [10.0, 20.0, 30.0, 40.0]
		let y = [12.0, 18.0, 33.0, 42.0]
		// diffs: [-2, 2, -3, -2]

		// Give all weight to pairs with diff = -2
		let weights = [50.0, 0.0, 0.0, 50.0]
		let result = try blandAltman(x, y, weights: weights)

		// All effective differences are -2, so SD ≈ 0
		#expect(abs(result.standardDeviation) < 1e-10)
		#expect(abs(result.bias - (-2.0)) < 1e-10)
	}

	// MARK: - Known Manual Calculation

	@Test("Known manual weighted calculation")
	func testManualCalculation() throws {
		// x = [10, 20, 30], y = [12, 18, 33], weights = [2, 1, 1]
		// diffs = [-2, 2, -3]
		// Total weight W = 4
		// Weighted mean of diffs = (2*(-2) + 1*2 + 1*(-3)) / 4 = (-4+2-3)/4 = -5/4 = -1.25
		// Weighted SD (sample):
		//   sum(w_i*(d_i - mean)^2) = 2*(-2-(-1.25))^2 + 1*(2-(-1.25))^2 + 1*(-3-(-1.25))^2
		//                           = 2*(0.5625) + 1*(10.5625) + 1*(3.0625)
		//                           = 1.125 + 10.5625 + 3.0625 = 14.75
		//   Var = 14.75 / (4-1) = 14.75/3 ≈ 4.91667
		//   SD = sqrt(4.91667) ≈ 2.21736
		let x = [10.0, 20.0, 30.0]
		let y = [12.0, 18.0, 33.0]
		let weights = [2.0, 1.0, 1.0]
		let result = try blandAltman(x, y, weights: weights)

		#expect(abs(result.bias - (-1.25)) < 1e-10)
		let expectedVar = 14.75 / 3.0
		let expectedSD = expectedVar.squareRoot()
		#expect(abs(result.standardDeviation - expectedSD) < 1e-6)
	}

	// MARK: - Error Cases

	@Test("Negative weight → throws invalidInput")
	func testNegativeWeightThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try blandAltman([1.0, 2.0, 3.0], [1.0, 2.0, 3.0], weights: [1.0, -1.0, 1.0])
		}
	}

	@Test("Mismatched lengths → throws mismatchedDimensions")
	func testMismatchedLengthsThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try blandAltman([1.0, 2.0], [1.0, 2.0, 3.0], weights: [1.0, 1.0])
		}
	}

	@Test("Fewer than 2 → throws insufficientData")
	func testInsufficientDataThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try blandAltman([1.0], [1.0], weights: [1.0])
		}
	}

	@Test("All-zero weights → throws divisionByZero")
	func testAllZeroWeightsThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try blandAltman([1.0, 2.0, 3.0], [1.0, 2.0, 3.0], weights: [0.0, 0.0, 0.0])
		}
	}
}

import Testing
import Foundation
@testable import BusinessMath

@Suite("Weighted Concordance Correlation Coefficient")
struct WeightedCCCTests {

	// MARK: - Equal Weights → Matches Unweighted

	@Test("Equal weights match unweighted CCC within 1e-10")
	func testEqualWeightsMatchUnweighted() throws {
		let x = [1.0, 3.5, 2.0, 5.5, 4.0, 6.0]
		let y = [1.5, 3.0, 2.5, 5.0, 4.5, 6.5]
		let weights = Array(repeating: 1.0, count: x.count)
		let weighted = try concordanceCorrelationCoefficient(x, y, weights: weights)
		let unweighted = try concordanceCorrelationCoefficient(x, y)
		#expect(abs(weighted.ccc - unweighted.ccc) < 1e-10)
	}

	// MARK: - Heavy Weight on Agreeing Pair → CCC Increases

	@Test("Heavy weight on agreeing pair increases CCC vs unweighted")
	func testHeavyWeightOnAgreeingPair() throws {
		// Mix of well-agreeing and poorly-agreeing pairs
		let x = [1.0, 2.0, 3.0, 4.0, 5.0]
		let y = [1.0, 2.5, 3.0, 3.5, 5.0] // pairs 1,3,5 agree perfectly

		let equalWeights = Array(repeating: 1.0, count: x.count)
		let unweighted = try concordanceCorrelationCoefficient(x, y, weights: equalWeights)

		// Heavy weight on perfectly agreeing pairs
		let heavyWeights = [10.0, 1.0, 10.0, 1.0, 10.0]
		let weighted = try concordanceCorrelationCoefficient(x, y, weights: heavyWeights)

		#expect(weighted.ccc > unweighted.ccc)
	}

	// MARK: - Heavy Weight on Disagreeing Pair → CCC Decreases

	@Test("Heavy weight on disagreeing pair decreases CCC vs unweighted")
	func testHeavyWeightOnDisagreeingPair() throws {
		let x = [1.0, 2.0, 3.0, 4.0, 5.0]
		let y = [1.0, 2.5, 3.0, 3.5, 5.0] // pairs 2,4 disagree

		let equalWeights = Array(repeating: 1.0, count: x.count)
		let unweighted = try concordanceCorrelationCoefficient(x, y, weights: equalWeights)

		// Heavy weight on disagreeing pairs
		let heavyWeights = [1.0, 10.0, 1.0, 10.0, 1.0]
		let weighted = try concordanceCorrelationCoefficient(x, y, weights: heavyWeights)

		#expect(weighted.ccc < unweighted.ccc)
	}

	// MARK: - CCC = r * Cb Identity

	@Test("CCC_w = r_w * Cb_w identity holds")
	func testDecompositionIdentity() throws {
		let x = [1.0, 3.5, 2.0, 5.5, 4.0, 6.0]
		let y = [1.5, 3.0, 2.5, 5.0, 4.5, 6.5]
		let weights = [1.0, 2.0, 3.0, 2.0, 1.0, 2.0]
		let result = try concordanceCorrelationCoefficient(x, y, weights: weights)
		let product = result.pearsonR * result.biasCorrection
		#expect(abs(result.ccc - product) < 1e-10)
	}

	// MARK: - Perfect Agreement

	@Test("Perfect agreement with any weights → CCC = 1.0")
	func testPerfectAgreement() throws {
		let x = [1.0, 2.0, 3.0, 4.0, 5.0]
		let y = [1.0, 2.0, 3.0, 4.0, 5.0]
		let weights = [1.0, 5.0, 1.0, 5.0, 1.0]
		let result = try concordanceCorrelationCoefficient(x, y, weights: weights)
		#expect(abs(result.ccc - 1.0) < 1e-10)
	}

	// MARK: - Error Cases

	@Test("Negative weight → throws invalidInput")
	func testNegativeWeightThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try concordanceCorrelationCoefficient(
				[1.0, 2.0, 3.0], [1.0, 2.0, 3.0],
				weights: [1.0, -1.0, 1.0]
			)
		}
	}

	@Test("Mismatched lengths → throws")
	func testMismatchedLengthsThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try concordanceCorrelationCoefficient(
				[1.0, 2.0], [1.0, 2.0, 3.0],
				weights: [1.0, 1.0]
			)
		}
	}

	@Test("Fewer than 2 → throws insufficientData")
	func testInsufficientDataThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try concordanceCorrelationCoefficient(
				[1.0], [1.0],
				weights: [1.0]
			)
		}
	}
}

import Testing
import Foundation
@testable import BusinessMath

@Suite("Weighted Correlation")
struct WeightedCorrelationTests {

	// MARK: - Equal Weights → Matches Unweighted

	@Test("Equal weights match unweighted correlation coefficient")
	func testEqualWeightsMatchUnweighted() throws {
		let x = [1.0, 2.0, 3.0, 4.0, 5.0]
		let y = [2.0, 4.0, 5.0, 4.0, 5.0]
		let weights = Array(repeating: 1.0, count: x.count)
		let weighted = try weightedCorrelation(x, y, weights: weights)
		let unweighted = try correlationCoefficient(x, y, .sample)
		#expect(abs(weighted - unweighted) < 1e-10)
	}

	// MARK: - Perfect Positive Correlation

	@Test("Perfect positive correlation → r_w = 1.0 regardless of weights")
	func testPerfectPositiveCorrelation() throws {
		let x = [1.0, 2.0, 3.0, 4.0, 5.0]
		let y = [2.0, 4.0, 6.0, 8.0, 10.0] // y = 2x
		let weights = [1.0, 5.0, 1.0, 5.0, 1.0]
		let result = try weightedCorrelation(x, y, weights: weights)
		#expect(abs(result - 1.0) < 1e-10)
	}

	// MARK: - Heavy Weight on Concordant Pair

	@Test("Heavy weight on concordant pair → correlation closer to 1")
	func testHeavyWeightOnConcordantPair() throws {
		// Data with noise
		let x = [1.0, 2.0, 3.0, 4.0, 5.0]
		let y = [1.5, 1.8, 3.2, 3.5, 5.5]

		let equalWeights = Array(repeating: 1.0, count: x.count)
		let rEqual = try weightedCorrelation(x, y, weights: equalWeights)

		// Give heavy weight to the most concordant pairs (1,5 which are close to y=x)
		let heavyWeights = [5.0, 1.0, 5.0, 1.0, 5.0]
		let rHeavy = try weightedCorrelation(x, y, weights: heavyWeights)

		// With heavy weight on pairs closer to perfect linearity, r should be high
		#expect(rHeavy > 0.9)
		#expect(rEqual > 0.9)
	}

	// MARK: - Constant Series

	@Test("Constant x series → throws divisionByZero")
	func testConstantXThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try weightedCorrelation([5.0, 5.0, 5.0], [1.0, 2.0, 3.0], weights: [1.0, 1.0, 1.0])
		}
	}

	@Test("Constant y series → throws divisionByZero")
	func testConstantYThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try weightedCorrelation([1.0, 2.0, 3.0], [5.0, 5.0, 5.0], weights: [1.0, 1.0, 1.0])
		}
	}

	// MARK: - All Weight on Single Pair

	@Test("All weight on single pair → degenerate, throws")
	func testAllWeightOnSinglePairThrows() throws {
		// When all weight is on one point, weighted variance of x and y = 0
		#expect(throws: BusinessMathError.self) {
			let _ = try weightedCorrelation(
				[1.0, 2.0, 3.0], [4.0, 5.0, 6.0],
				weights: [0.0, 10.0, 0.0]
			)
		}
	}
}

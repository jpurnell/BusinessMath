import Testing
import Foundation
@testable import BusinessMath

@Suite("Weighted Percentile")
struct WeightedPercentileTests {

	// MARK: - Equal Weights Match Standard Percentile

	@Test("Equal weights match standard percentile (median)")
	func testEqualWeightsMatchStandardMedian() throws {
		// With equal weights, the weighted median should match the unweighted median
		let values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0]
		let weights = Array(repeating: 1.0, count: values.count)
		let result = try weightedPercentile(values, weights: weights, p: 0.5)
		let expected = median(values)
		#expect(abs(result - expected) < 1e-10)
	}

	// MARK: - All Weight on One Observation

	@Test("All weight on one observation returns that value at p=0.5")
	func testAllWeightOnOneObservation() throws {
		let values = [10.0, 20.0, 30.0, 40.0, 50.0]
		let weights = [0.0, 0.0, 1.0, 0.0, 0.0]
		// The midpoint of the sole weighted observation is at 0.5
		let result = try weightedPercentile(values, weights: weights, p: 0.5)
		#expect(abs(result - 30.0) < 1e-10)
	}

	@Test("Single value with unit weight returns that value at any percentile")
	func testSingleValue() throws {
		let values = [42.0]
		let weights = [1.0]
		for p in stride(from: 0.0, through: 1.0, by: 0.25) {
			let result = try weightedPercentile(values, weights: weights, p: p)
			#expect(abs(result - 42.0) < 1e-10,
				"Expected 42.0 at p=\(p), got \(result)")
		}
	}

	// MARK: - Boundary Percentiles

	@Test("p=0 returns minimum value")
	func testPZeroReturnsMinimum() throws {
		let values = [5.0, 1.0, 9.0, 3.0, 7.0]
		let weights = [1.0, 2.0, 3.0, 4.0, 5.0]
		let result = try weightedPercentile(values, weights: weights, p: 0.0)
		#expect(abs(result - 1.0) < 1e-10)
	}

	@Test("p=1 returns maximum value")
	func testPOneReturnsMaximum() throws {
		let values = [5.0, 1.0, 9.0, 3.0, 7.0]
		let weights = [1.0, 2.0, 3.0, 4.0, 5.0]
		let result = try weightedPercentile(values, weights: weights, p: 1.0)
		#expect(abs(result - 9.0) < 1e-10)
	}

	// MARK: - p=0.5 with Equal Weights Matches Unweighted Median

	@Test("p=0.5 with equal weights matches unweighted median (even count)")
	func testPHalfEqualWeightsEvenCount() throws {
		let values = [2.0, 4.0, 6.0, 8.0]
		let weights = Array(repeating: 1.0, count: values.count)
		let result = try weightedPercentile(values, weights: weights, p: 0.5)
		// Unweighted median of [2,4,6,8] = 5.0
		let expected = median(values)
		#expect(abs(result - expected) < 1e-10)
	}

	// MARK: - Known Manual Calculation with Unequal Weights

	@Test("Known manual calculation with unequal weights")
	func testKnownManualCalculation() throws {
		// Values: [10, 20, 30], weights: [1, 1, 2]
		// Sorted by value: [10, 20, 30] with weights [1, 1, 2]
		// Total weight = 4
		// Midpoint cumulative weights:
		//   CW_0 = (0 + 0.5) / 4 = 0.125
		//   CW_1 = (1 + 0.5) / 4 = 0.375
		//   CW_2 = (2 + 1.0) / 4 = 0.75
		// For p=0.75: p == CW_2 = 0.75, so this is at the boundary.
		//   i=2, lower = CW_1 = 0.375, upper = CW_2 = 0.75
		//   fraction = (0.75 - 0.375) / (0.75 - 0.375) = 1.0
		//   result = 20 + 1.0 * (30 - 20) = 30.0
		let values = [10.0, 20.0, 30.0]
		let weights = [1.0, 1.0, 2.0]
		let result = try weightedPercentile(values, weights: weights, p: 0.75)
		#expect(abs(result - 30.0) < 1e-10)

		// Also verify p=0.25: between CW_0=0.125 and CW_1=0.375
		// fraction = (0.25 - 0.125) / (0.375 - 0.125) = 0.5
		// result = 10 + 0.5 * (20 - 10) = 15.0
		let result2 = try weightedPercentile(values, weights: weights, p: 0.25)
		#expect(abs(result2 - 15.0) < 1e-10)
	}

	// MARK: - Error Cases

	@Test("Empty array throws insufficientData")
	func testEmptyArrayThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try weightedPercentile([], weights: [], p: 0.5)
		}
	}

	@Test("Negative weight throws invalidInput")
	func testNegativeWeightThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try weightedPercentile([1.0, 2.0, 3.0], weights: [1.0, -1.0, 1.0], p: 0.5)
		}
	}

	@Test("p < 0 throws invalidInput")
	func testPBelowZeroThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try weightedPercentile([1.0, 2.0, 3.0], weights: [1.0, 1.0, 1.0], p: -0.1)
		}
	}

	@Test("p > 1 throws invalidInput")
	func testPAboveOneThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try weightedPercentile([1.0, 2.0, 3.0], weights: [1.0, 1.0, 1.0], p: 1.1)
		}
	}

	@Test("Mismatched dimensions throws mismatchedDimensions")
	func testMismatchedDimensionsThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try weightedPercentile([1.0, 2.0], weights: [1.0], p: 0.5)
		}
	}
}

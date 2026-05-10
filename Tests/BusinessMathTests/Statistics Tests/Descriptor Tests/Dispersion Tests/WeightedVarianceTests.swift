import Testing
import Foundation
@testable import BusinessMath

@Suite("Weighted Variance & Standard Deviation")
struct WeightedVarianceTests {

	// MARK: - Equal Weights → Same as Unweighted

	@Test("Equal weights produce same result as unweighted sample variance")
	func testEqualWeightsMatchUnweighted() throws {
		let values = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]
		let weights = Array(repeating: 1.0, count: values.count)
		let weighted = try weightedVariance(values, weights: weights, .sample)
		let unweighted = varianceS(values)
		#expect(abs(weighted - unweighted) < 1e-10)
	}

	@Test("Equal weights produce same result as unweighted population variance")
	func testEqualWeightsPopulation() throws {
		let values = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]
		let weights = Array(repeating: 1.0, count: values.count)
		let weighted = try weightedVariance(values, weights: weights, .population)
		let unweighted = varianceP(values)
		#expect(abs(weighted - unweighted) < 1e-10)
	}

	// MARK: - Known Manual Calculation

	@Test("Known manual calculation: [1,2,3,4,5] with weights [1,2,3,2,1]")
	func testManualCalculation() throws {
		// values = [1, 2, 3, 4, 5], weights = [1, 2, 3, 2, 1]
		// Total weight W = 9
		// Weighted mean = (1*1 + 2*2 + 3*3 + 4*2 + 5*1) / 9 = (1+4+9+8+5)/9 = 27/9 = 3.0
		// Weighted sum of squared deviations:
		//   1*(1-3)^2 + 2*(2-3)^2 + 3*(3-3)^2 + 2*(4-3)^2 + 1*(5-3)^2
		//   = 1*4 + 2*1 + 3*0 + 2*1 + 1*4 = 4 + 2 + 0 + 2 + 4 = 12
		// Sample: 12 / (9 - 1) = 12 / 8 = 1.5
		let values = [1.0, 2.0, 3.0, 4.0, 5.0]
		let weights = [1.0, 2.0, 3.0, 2.0, 1.0]
		let result = try weightedVariance(values, weights: weights, .sample)
		#expect(abs(result - 1.5) < 1e-10)
	}

	// MARK: - Population vs Sample

	@Test("Population variance differs from sample variance")
	func testPopulationVsSample() throws {
		// Using same data as manual calculation:
		// Population: 12 / 9 = 4/3 ≈ 1.3333
		// Sample: 12 / 8 = 1.5
		let values = [1.0, 2.0, 3.0, 4.0, 5.0]
		let weights = [1.0, 2.0, 3.0, 2.0, 1.0]
		let pop = try weightedVariance(values, weights: weights, .population)
		let sample = try weightedVariance(values, weights: weights, .sample)
		#expect(abs(pop - (12.0 / 9.0)) < 1e-10)
		#expect(abs(sample - 1.5) < 1e-10)
		#expect(sample > pop)
	}

	// MARK: - All Weight on One Point

	@Test("All weight on one point (population) → variance approaches 0")
	func testAllWeightOnOnePoint() throws {
		// weights = [0, 0, 100, 0, 0] → weighted mean = 3.0
		// All deviations have weight 0 except the point at mean → variance = 0
		let values = [1.0, 2.0, 3.0, 4.0, 5.0]
		let weights = [0.0, 0.0, 100.0, 0.0, 0.0]
		// Population variance: only one effective point, deviation = 0
		// But sample variance denominator = 100 - 1 = 99 and numerator = 0
		let pop = try weightedVariance(values, weights: weights, .population)
		#expect(abs(pop) < 1e-10)
	}

	// MARK: - Error Cases

	@Test("Negative weight throws invalidInput")
	func testNegativeWeightThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try weightedVariance([1.0, 2.0, 3.0], weights: [1.0, -1.0, 1.0])
		}
	}

	@Test("Mismatched lengths throws mismatchedDimensions")
	func testMismatchedLengthsThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try weightedVariance([1.0, 2.0, 3.0], weights: [1.0, 1.0])
		}
	}

	@Test("All-zero weights throws divisionByZero")
	func testAllZeroWeightsThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try weightedVariance([1.0, 2.0, 3.0], weights: [0.0, 0.0, 0.0])
		}
	}

	@Test("Single value throws insufficientData")
	func testSingleValueThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try weightedVariance([1.0], weights: [1.0])
		}
	}

	@Test("Sample variance with total weight <= 1 throws insufficientData")
	func testTotalWeightTooSmallForSample() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try weightedVariance([1.0, 2.0, 3.0], weights: [0.3, 0.3, 0.3], .sample)
		}
	}

	// MARK: - Weighted Standard Deviation

	@Test("Weighted standard deviation is sqrt of weighted variance")
	func testWeightedStdDevIsSqrtOfVariance() throws {
		let values = [1.0, 2.0, 3.0, 4.0, 5.0]
		let weights = [1.0, 2.0, 3.0, 2.0, 1.0]
		let wVar = try weightedVariance(values, weights: weights, .sample)
		let wSD = try weightedStandardDeviation(values, weights: weights, .sample)
		#expect(abs(wSD - wVar.squareRoot()) < 1e-10)
	}

	@Test("Weighted SD with equal weights matches unweighted SD")
	func testWeightedStdDevEqualWeights() throws {
		let values = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]
		let weights = Array(repeating: 1.0, count: values.count)
		let weighted = try weightedStandardDeviation(values, weights: weights, .sample)
		let unweighted = stdDevS(values)
		#expect(abs(weighted - unweighted) < 1e-10)
	}
}

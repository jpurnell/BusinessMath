import Testing
import Foundation
@testable import BusinessMath

@Suite("Weighted Covariance")
struct WeightedCovarianceTests {

	// MARK: - Equal Weights → Matches Unweighted

	@Test("Equal weights produce same result as unweighted sample covariance")
	func testEqualWeightsMatchUnweighted() throws {
		let x = [1.0, 2.0, 3.0, 4.0, 5.0]
		let y = [2.0, 4.0, 5.0, 4.0, 5.0]
		let weights = Array(repeating: 1.0, count: x.count)
		let weighted = try weightedCovariance(x, y, weights: weights, .sample)
		let unweighted = covarianceS(x, y)
		#expect(abs(weighted - unweighted) < 1e-10)
	}

	@Test("Equal weights match unweighted population covariance")
	func testEqualWeightsPopulation() throws {
		let x = [1.0, 2.0, 3.0, 4.0, 5.0]
		let y = [2.0, 4.0, 5.0, 4.0, 5.0]
		let weights = Array(repeating: 1.0, count: x.count)
		let weighted = try weightedCovariance(x, y, weights: weights, .population)
		let unweighted = covarianceP(x, y)
		#expect(abs(weighted - unweighted) < 1e-10)
	}

	// MARK: - Known Manual Calculation

	@Test("Known manual calculation")
	func testManualCalculation() throws {
		// x = [1, 2, 3], y = [4, 5, 6], weights = [1, 2, 1]
		// Total weight W = 4
		// Weighted mean of x = (1*1 + 2*2 + 3*1) / 4 = 8/4 = 2.0
		// Weighted mean of y = (4*1 + 5*2 + 6*1) / 4 = 20/4 = 5.0
		// Weighted cov (sample) = sum(w_i * (x_i - mx) * (y_i - my)) / (W - 1)
		//   = (1*(1-2)*(4-5) + 2*(2-2)*(5-5) + 1*(3-2)*(6-5)) / (4-1)
		//   = (1*(-1)*(-1) + 2*0*0 + 1*1*1) / 3
		//   = (1 + 0 + 1) / 3 = 2/3 ≈ 0.6667
		let x = [1.0, 2.0, 3.0]
		let y = [4.0, 5.0, 6.0]
		let weights = [1.0, 2.0, 1.0]
		let result = try weightedCovariance(x, y, weights: weights, .sample)
		#expect(abs(result - (2.0 / 3.0)) < 1e-10)
	}

	// MARK: - Cov(x,x) = Variance

	@Test("Weighted covariance of x with itself equals weighted variance")
	func testCovXXEqualsVariance() throws {
		let values = [1.0, 2.0, 3.0, 4.0, 5.0]
		let weights = [1.0, 2.0, 3.0, 2.0, 1.0]
		let covXX = try weightedCovariance(values, values, weights: weights, .sample)
		let wVar = try weightedVariance(values, weights: weights, .sample)
		#expect(abs(covXX - wVar) < 1e-10)
	}

	// MARK: - Error Cases

	@Test("Mismatched x and y lengths throws")
	func testMismatchedXYThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try weightedCovariance([1.0, 2.0], [1.0, 2.0, 3.0], weights: [1.0, 1.0])
		}
	}

	@Test("Mismatched weights length throws")
	func testMismatchedWeightsThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try weightedCovariance([1.0, 2.0, 3.0], [1.0, 2.0, 3.0], weights: [1.0, 1.0])
		}
	}

	@Test("Negative weight throws invalidInput")
	func testNegativeWeightThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try weightedCovariance([1.0, 2.0, 3.0], [1.0, 2.0, 3.0], weights: [1.0, -1.0, 1.0])
		}
	}

	@Test("All-zero weights throws divisionByZero")
	func testAllZeroWeightsThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try weightedCovariance([1.0, 2.0, 3.0], [1.0, 2.0, 3.0], weights: [0.0, 0.0, 0.0])
		}
	}
}

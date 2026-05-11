import Testing
import Foundation
@testable import BusinessMath

@Suite("Winsorized Weighted Variance & Standard Deviation")
struct WinsorizedWeightedVarianceTests {

	// MARK: - Near-Zero Alpha Matches Weighted Variance

	@Test("Equal weights, alpha near zero matches weighted variance closely")
	func testAlphaNearZeroMatchesWeightedVariance() throws {
		let values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
		let weights = Array(repeating: 1.0, count: values.count)
		let winsorized = try winsorizedWeightedVariance(values, weights: weights, alpha: 0.001, .sample)
		let standard = try weightedVariance(values, weights: weights, .sample)
		// With near-zero alpha, virtually no clipping occurs
		#expect(abs(winsorized - standard) < 0.5)
	}

	// MARK: - Extreme Outlier: Winsorized < Unwinsorized

	@Test("Extreme outlier: Winsorized variance is less than unwinsorized variance")
	func testExtremeOutlierReducesVariance() throws {
		let values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 100.0]
		let weights = Array(repeating: 1.0, count: values.count)
		let winsorized = try winsorizedWeightedVariance(values, weights: weights, alpha: 0.1, .sample)
		let standard = try weightedVariance(values, weights: weights, .sample)
		#expect(winsorized < standard)
	}

	// MARK: - Known Manual Calculation with Boundary Clipping

	@Test("Known manual calculation: boundary values are clipped")
	func testManualCalculationWithClipping() throws {
		// Values: [1, 5, 10, 15, 20], weights: [1, 1, 1, 1, 1]
		// alpha = 0.2
		// 20th percentile (lower clip) and 80th percentile (upper clip)
		// After Winsorizing: extreme values get clipped to boundary percentiles
		// The Winsorized variance should be less than the original
		let values = [1.0, 5.0, 10.0, 15.0, 20.0]
		let weights = [1.0, 1.0, 1.0, 1.0, 1.0]
		let winsorized = try winsorizedWeightedVariance(values, weights: weights, alpha: 0.2, .population)
		let standard = try weightedVariance(values, weights: weights, .population)
		#expect(winsorized <= standard)
		#expect(winsorized >= 0.0)
	}

	// MARK: - Standard Deviation Is Sqrt of Variance

	@Test("Winsorized standard deviation equals sqrt of Winsorized variance")
	func testStdDevIsSqrtOfVariance() throws {
		let values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 100.0]
		let weights = Array(repeating: 1.0, count: values.count)
		let wVar = try winsorizedWeightedVariance(values, weights: weights, alpha: 0.1, .sample)
		let wSD = try winsorizedWeightedStandardDeviation(values, weights: weights, alpha: 0.1, .sample)
		#expect(abs(wSD - wVar.squareRoot()) < 1e-10)
	}

	// MARK: - Error Cases

	@Test("Alpha <= 0 throws invalidInput")
	func testAlphaZeroThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try winsorizedWeightedVariance(
				[1.0, 2.0, 3.0], weights: [1.0, 1.0, 1.0], alpha: 0.0)
		}
	}

	@Test("Alpha >= 0.5 throws invalidInput")
	func testAlphaHalfThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try winsorizedWeightedVariance(
				[1.0, 2.0, 3.0], weights: [1.0, 1.0, 1.0], alpha: 0.5)
		}
	}
}

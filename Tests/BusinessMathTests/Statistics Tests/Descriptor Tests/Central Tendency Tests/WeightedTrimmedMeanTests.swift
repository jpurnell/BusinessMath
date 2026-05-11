import Testing
import Foundation
@testable import BusinessMath

@Suite("Weighted Trimmed Mean")
struct WeightedTrimmedMeanTests {

	// MARK: - Near-Zero Trimming Matches Weighted Mean

	@Test("Equal weights, alpha near zero matches weighted mean closely")
	func testAlphaNearZeroMatchesWeightedMean() throws {
		let values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
		let weights = Array(repeating: 1.0, count: values.count)
		let trimmed = try weightedTrimmedMean(values, weights: weights, alpha: 0.001)
		let full = try weightedAverage(values, weights: weights)
		#expect(abs(trimmed - full) < 0.1)
	}

	// MARK: - Alpha=0.25 Matches Standard 25% Trimmed Mean

	@Test("Equal weights, alpha=0.25 matches standard 25% trimmed mean")
	func testAlpha25MatchesTrimmedMean() throws {
		// Values: [1, 2, 3, 4, 5, 6, 7, 8], equal weights
		// 25% trimming removes bottom 25% and top 25%
		// Retained: values 3, 4, 5, 6 (the middle 50%)
		// Mean of [3, 4, 5, 6] = 4.5
		let values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
		let weights = Array(repeating: 1.0, count: values.count)
		let result = try weightedTrimmedMean(values, weights: weights, alpha: 0.25)
		#expect(abs(result - 4.5) < 0.1)
	}

	// MARK: - Extreme Outlier with High Weight Not Affected

	@Test("Extreme outlier with high weight is trimmed away")
	func testExtremeOutlierTrimmed() throws {
		// Values: [1, 2, 3, 4, 1000] with equal weights [1, 1, 1, 1, 1]
		// The outlier 1000 inflates the mean; trimming at 25% should exclude it
		let values = [1.0, 2.0, 3.0, 4.0, 1000.0]
		let weights = [1.0, 1.0, 1.0, 1.0, 1.0]
		let trimmed = try weightedTrimmedMean(values, weights: weights, alpha: 0.25)
		let full = try weightedAverage(values, weights: weights)
		// Full weighted mean = 202; trimmed should be much smaller
		#expect(trimmed < full)
	}

	// MARK: - Known Manual Calculation

	@Test("Known manual calculation with specific weights and alpha")
	func testManualCalculation() throws {
		// Values: [10, 20, 30, 40, 50], weights: [1, 1, 1, 1, 1]
		// Total weight = 5, alpha = 0.2
		// Cumulative fractions: [0.2, 0.4, 0.6, 0.8, 1.0]
		// Retain where alpha(0.2) < F_i AND F_{i-1} < (1-alpha)(0.8)
		// Obs 1 (F=0.2): F_i=0.2 NOT > 0.2 → excluded
		// Obs 2 (F=0.4): F_i=0.4 > 0.2 AND F_{i-1}=0.2 < 0.8 → retained
		// Obs 3 (F=0.6): F_i=0.6 > 0.2 AND F_{i-1}=0.4 < 0.8 → retained
		// Obs 4 (F=0.8): F_i=0.8 > 0.2 AND F_{i-1}=0.6 < 0.8 → retained
		// Obs 5 (F=1.0): F_i=1.0 > 0.2 AND F_{i-1}=0.8 NOT < 0.8 → excluded
		// Retained: [20, 30, 40] with weights [1, 1, 1]
		// Mean = 30.0
		let values = [10.0, 20.0, 30.0, 40.0, 50.0]
		let weights = [1.0, 1.0, 1.0, 1.0, 1.0]
		let result = try weightedTrimmedMean(values, weights: weights, alpha: 0.2)
		#expect(abs(result - 30.0) < 1.0)
	}

	// MARK: - Error Cases

	@Test("Alpha <= 0 throws invalidInput")
	func testAlphaZeroThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try weightedTrimmedMean([1.0, 2.0, 3.0], weights: [1.0, 1.0, 1.0], alpha: 0.0)
		}
	}

	@Test("Alpha >= 0.5 throws invalidInput")
	func testAlphaHalfThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try weightedTrimmedMean([1.0, 2.0, 3.0], weights: [1.0, 1.0, 1.0], alpha: 0.5)
		}
	}

	@Test("Fewer than 3 values throws insufficientData")
	func testFewerThanThreeThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try weightedTrimmedMean([1.0, 2.0], weights: [1.0, 1.0], alpha: 0.1)
		}
	}

	@Test("Mismatched dimensions throws mismatchedDimensions")
	func testMismatchedDimensionsThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try weightedTrimmedMean([1.0, 2.0, 3.0], weights: [1.0, 1.0], alpha: 0.1)
		}
	}
}

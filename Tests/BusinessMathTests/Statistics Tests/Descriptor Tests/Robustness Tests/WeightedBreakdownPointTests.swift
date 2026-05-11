import Testing
import Foundation
@testable import BusinessMath

@Suite("Weighted Breakdown Point")
struct WeightedBreakdownPointTests {

	// MARK: - Equal Weights

	@Test("Equal weights (n=10): breakdown = 1/10 = 0.1")
	func testEqualWeightsBreakdown() throws {
		let weights = Array(repeating: 1.0, count: 10)
		let result = try weightedBreakdownPoint(weights)
		#expect(abs(result - 0.1) < 1e-10)
	}

	// MARK: - One Dominant Weight

	@Test("One dominant weight: breakdown = min(non-dominant) / total")
	func testOneDominantWeight() throws {
		// Weights: [100, 1, 1, 1, 1] → total = 104
		// min weight = 1, breakdown = 1/104
		let weights = [100.0, 1.0, 1.0, 1.0, 1.0]
		let result = try weightedBreakdownPoint(weights)
		let expected = 1.0 / 104.0
		#expect(abs(result - expected) < 1e-10)
	}

	// MARK: - With Trimming

	@Test("With trimming alpha=0.1: breakdown = 0.1")
	func testWithTrimmingBreakdown() throws {
		let weights = [100.0, 1.0, 1.0, 1.0, 1.0]
		let result = try weightedBreakdownPoint(weights, trimming: 0.1)
		#expect(abs(result - 0.1) < 1e-10)
	}

	@Test("With trimming alpha=0.25: breakdown = 0.25")
	func testWithTrimmingQuarter() throws {
		let weights = Array(repeating: 1.0, count: 20)
		let result = try weightedBreakdownPoint(weights, trimming: 0.25)
		#expect(abs(result - 0.25) < 1e-10)
	}

	// MARK: - Error Cases

	@Test("Zero total weight throws divisionByZero")
	func testZeroTotalWeightThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try weightedBreakdownPoint([0.0, 0.0, 0.0] as [Double])
		}
	}

	@Test("Empty weights throws insufficientData")
	func testEmptyWeightsThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try weightedBreakdownPoint([])
		}
	}

	@Test("Negative weight throws invalidInput")
	func testNegativeWeightThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try weightedBreakdownPoint([1.0, -1.0, 1.0])
		}
	}
}

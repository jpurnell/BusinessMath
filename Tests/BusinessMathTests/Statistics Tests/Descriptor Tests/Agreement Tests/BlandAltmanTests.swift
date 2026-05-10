import Testing
import Foundation
@testable import BusinessMath

@Suite("Bland-Altman Agreement Analysis")
struct BlandAltmanTests {

	// MARK: - Perfect Agreement

	@Test("Identical arrays → bias 0, SD 0, LoA (0, 0)")
	func testPerfectAgreement() throws {
		let x = [1.0, 2.0, 3.0, 4.0, 5.0]
		let y = [1.0, 2.0, 3.0, 4.0, 5.0]
		let result = try blandAltman(x, y)

		#expect(abs(result.bias) < 1e-12)
		#expect(abs(result.standardDeviation) < 1e-12)
		#expect(abs(result.loaLower) < 1e-12)
		#expect(abs(result.loaUpper) < 1e-12)
		#expect(result.count == 5)
	}

	// MARK: - Constant Offset

	@Test("Known offset y = x + 5 → bias -5, SD 0")
	func testConstantOffset() throws {
		let x = [10.0, 20.0, 30.0, 40.0, 50.0]
		let y = [15.0, 25.0, 35.0, 45.0, 55.0]
		let result = try blandAltman(x, y)

		#expect(abs(result.bias - (-5.0)) < 1e-12)
		#expect(abs(result.standardDeviation) < 1e-12)
		#expect(abs(result.loaLower - (-5.0)) < 1e-12)
		#expect(abs(result.loaUpper - (-5.0)) < 1e-12)
	}

	// MARK: - Manual Calculation

	@Test("Known dataset with manual calculation")
	func testManualCalculation() throws {
		// x:    [10, 20, 30, 40, 50]
		// y:    [12, 18, 33, 38, 52]
		// diff: [-2, 2, -3, 2, -2]
		// bias = mean(diff) = -3/5 = -0.6
		// SD = sqrt(((−2−(−0.6))² + (2−(−0.6))² + (−3−(−0.6))² + (2−(−0.6))² + (−2−(−0.6))²) / 4)
		//    = sqrt((1.96 + 6.76 + 5.76 + 6.76 + 1.96) / 4)
		//    = sqrt(23.2 / 4) = sqrt(5.8) ≈ 2.408
		// LoA_lower = -0.6 - 1.96 × 2.408 ≈ -5.32
		// LoA_upper = -0.6 + 1.96 × 2.408 ≈ 4.12

		let x = [10.0, 20.0, 30.0, 40.0, 50.0]
		let y = [12.0, 18.0, 33.0, 38.0, 52.0]
		let result = try blandAltman(x, y)

		#expect(abs(result.bias - (-0.6)) < 1e-10)
		let expectedSD = (23.2 / 4.0).squareRoot()
		#expect(abs(result.standardDeviation - expectedSD) < 1e-10)
		#expect(abs(result.loaLower - (result.bias - 1.96 * result.standardDeviation)) < 1e-10)
		#expect(abs(result.loaUpper - (result.bias + 1.96 * result.standardDeviation)) < 1e-10)
	}

	// MARK: - Proportional Bias

	@Test("Constant offset → proportional bias slope ≈ 0")
	func testNoProportionalBias() throws {
		let x = [10.0, 20.0, 30.0, 40.0, 50.0]
		let y = [15.0, 25.0, 35.0, 45.0, 55.0]
		let result = try blandAltman(x, y)
		#expect(abs(result.proportionalBiasSlope) < 1e-10)
	}

	@Test("Proportional relationship y = 1.1x → non-zero slope")
	func testProportionalBias() throws {
		let x = [10.0, 20.0, 30.0, 40.0, 50.0]
		let y = x.map { $0 * 1.1 }
		let result = try blandAltman(x, y)
		// Differences grow with magnitude → slope should be negative
		// diff = x - 1.1x = -0.1x, means = (x + 1.1x)/2 = 1.05x
		// slope of diff vs means = -0.1/1.05 ≈ -0.0952
		#expect(abs(result.proportionalBiasSlope) > 0.05)
	}

	// MARK: - Error Cases

	@Test("Mismatched lengths → throws mismatchedDimensions")
	func testMismatchedLengthsThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try blandAltman([1.0, 2.0, 3.0], [1.0, 2.0])
		}
	}

	@Test("Single pair → throws insufficientData")
	func testSinglePairThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try blandAltman([1.0], [1.0])
		}
	}

	@Test("Empty arrays → throws insufficientData")
	func testEmptyThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: BlandAltmanResult<Double> = try blandAltman([], [])
		}
	}
}

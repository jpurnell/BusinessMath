import Testing
import Foundation
@testable import BusinessMath

@Suite("Lin's Concordance Correlation Coefficient")
struct ConcordanceCorrelationCoefficientTests {

	// MARK: - Perfect Agreement

	@Test("Identical arrays → CCC = 1.0")
	func testPerfectAgreement() throws {
		let x = [1.0, 2.0, 3.0, 4.0, 5.0]
		let y = [1.0, 2.0, 3.0, 4.0, 5.0]
		let result = try concordanceCorrelationCoefficient(x, y)
		#expect(abs(result.ccc - 1.0) < 1e-10)
		#expect(abs(result.pearsonR - 1.0) < 1e-10)
		#expect(abs(result.biasCorrection - 1.0) < 1e-10)
	}

	@Test("Perfect negative (zero-mean) → CCC = -1.0")
	func testPerfectNegative() throws {
		let x = [-2.0, -1.0, 0.0, 1.0, 2.0]
		let y = [2.0, 1.0, 0.0, -1.0, -2.0]
		let result = try concordanceCorrelationCoefficient(x, y)
		#expect(abs(result.ccc - (-1.0)) < 1e-10)
	}

	// MARK: - CCC < r (Key Property)

	@Test("Known offset (high r, low CCC) → CCC < r")
	func testOffsetReducesCCC() throws {
		let x = [1.0, 2.0, 3.0, 4.0, 5.0]
		let y = [11.0, 12.0, 13.0, 14.0, 15.0] // offset by 10
		let result = try concordanceCorrelationCoefficient(x, y)
		// r = 1.0 (perfect linear), but CCC < 1 due to bias
		#expect(abs(result.pearsonR - 1.0) < 1e-10)
		#expect(result.ccc < result.pearsonR)
		#expect(result.biasCorrection < 1.0)
	}

	@Test("Known scaling y = 2x → CCC < 1 despite r ≈ 1")
	func testScalingReducesCCC() throws {
		let x = [1.0, 2.0, 3.0, 4.0, 5.0]
		let y = [2.0, 4.0, 6.0, 8.0, 10.0]
		let result = try concordanceCorrelationCoefficient(x, y)
		#expect(abs(result.pearsonR - 1.0) < 1e-10)
		#expect(result.ccc < 1.0)
		#expect(result.ccc < result.pearsonR)
	}

	// MARK: - CCC = r × Cb Identity

	@Test("CCC = r × Cb identity holds")
	func testDecompositionIdentity() throws {
		let x = [1.0, 3.5, 2.0, 5.5, 4.0, 6.0]
		let y = [1.5, 3.0, 2.5, 5.0, 4.5, 6.5]
		let result = try concordanceCorrelationCoefficient(x, y)
		let product = result.pearsonR * result.biasCorrection
		#expect(abs(result.ccc - product) < 1e-10)
	}

	// MARK: - Confidence Intervals

	@Test("CI at 95% is narrower than CI at 99%")
	func testWiderCIAtHigherConfidence() throws {
		let x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
		let y = [1.1, 2.2, 2.9, 4.1, 5.2, 5.8, 7.1, 8.0, 8.9, 10.1]
		let result95 = try concordanceCorrelationCoefficient(x, y, confidence: 0.95)
		let result99 = try concordanceCorrelationCoefficient(x, y, confidence: 0.99)

		let width95 = result95.upperBound - result95.lowerBound
		let width99 = result99.upperBound - result99.lowerBound
		#expect(width99 > width95)
	}

	@Test("CI contains the CCC value")
	func testCIContainsCCC() throws {
		let x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
		let y = [1.2, 1.8, 3.1, 3.9, 5.2, 5.8, 7.1, 8.2]
		let result = try concordanceCorrelationCoefficient(x, y)
		#expect(result.ccc >= result.lowerBound)
		#expect(result.ccc <= result.upperBound)
	}

	@Test("Larger n produces narrower CI")
	func testLargerNNarrowerCI() throws {
		let x5 = [1.0, 2.0, 3.0, 4.0, 5.0]
		let y5 = [1.1, 2.1, 2.9, 4.1, 4.9]
		let x20 = Array(stride(from: 1.0, through: 20.0, by: 1.0))
		let y20 = x20.map { $0 + 0.1 * (($0.truncatingRemainder(dividingBy: 2.0) == 0) ? 1.0 : -1.0) }

		let result5 = try concordanceCorrelationCoefficient(x5, y5)
		let result20 = try concordanceCorrelationCoefficient(x20, y20)

		let width5 = result5.upperBound - result5.lowerBound
		let width20 = result20.upperBound - result20.lowerBound
		#expect(width20 < width5)
	}

	// MARK: - Error Cases

	@Test("Mismatched lengths → throws")
	func testMismatchedLengthsThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try concordanceCorrelationCoefficient([1.0, 2.0], [1.0])
		}
	}

	@Test("Fewer than 2 → throws insufficientData")
	func testInsufficientDataThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try concordanceCorrelationCoefficient([1.0], [1.0])
		}
	}

	@Test("Constant x → throws divisionByZero")
	func testConstantXThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try concordanceCorrelationCoefficient([5.0, 5.0, 5.0], [1.0, 2.0, 3.0])
		}
	}

	@Test("Constant y → throws divisionByZero")
	func testConstantYThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try concordanceCorrelationCoefficient([1.0, 2.0, 3.0], [5.0, 5.0, 5.0])
		}
	}
}

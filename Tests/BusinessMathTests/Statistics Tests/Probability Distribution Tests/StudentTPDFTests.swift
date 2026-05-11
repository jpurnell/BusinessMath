import Testing
import Foundation
@testable import BusinessMath

@Suite("Student's t-Distribution PDF")
struct StudentTPDFTests {

	// MARK: - Known Values

	@Test("studentTPDF(t: 0, df: 10) ≈ 0.3891 (peak of t(10))")
	func testPeakDf10() throws {
		let result: Double = try studentTPDF(t: 0.0, df: 10)
		#expect(abs(result - 0.3891) < 0.001)
	}

	@Test("studentTPDF matches legacy pValueStudent for same inputs")
	func testMatchesLegacy() throws {
		let inputs: [(Double, Int)] = [(0.0, 10), (1.5, 5), (2.0, 20), (-1.0, 3)]
		for (tVal, dfVal) in inputs {
			let newResult: Double = try studentTPDF(t: tVal, df: dfVal)
			let legacyResult: Double = pValueStudent(tVal, dFr: Double(dfVal))
			#expect(abs(newResult - legacyResult) < 1e-12,
				"Mismatch at t=\(tVal), df=\(dfVal): \(newResult) vs \(legacyResult)")
		}
	}

	// MARK: - Symmetry

	@Test("studentTPDF(t: 2, df: 5) == studentTPDF(t: -2, df: 5)")
	func testSymmetry() throws {
		let positive: Double = try studentTPDF(t: 2.0, df: 5)
		let negative: Double = try studentTPDF(t: -2.0, df: 5)
		#expect(abs(positive - negative) < 1e-15)
	}

	// MARK: - Convergence to Normal

	@Test("Large df → approaches standard normal PDF: φ(0) ≈ 0.3989")
	func testConvergesToNormal() throws {
		let result: Double = try studentTPDF(t: 0.0, df: 10000)
		#expect(abs(result - 0.3989) < 0.001)
	}

	// MARK: - Error Cases

	@Test("df ≤ 0 throws invalidInput")
	func testZeroDfThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try studentTPDF(t: 1.0, df: 0)
		}
	}

	@Test("df = -1 throws invalidInput")
	func testNegativeDfThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try studentTPDF(t: 1.0, df: -1)
		}
	}
}

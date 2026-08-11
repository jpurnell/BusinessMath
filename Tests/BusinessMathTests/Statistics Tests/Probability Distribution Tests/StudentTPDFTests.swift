import Testing
import Foundation
import TestSupport
@testable import BusinessMath

@Suite("Student's t-Distribution PDF")
struct StudentTPDFTests {

	// MARK: - Known Values

	@Test("studentTPDF(t: 0, df: 10) ≈ 0.3891 (peak of t(10))")
	func testPeakDf10() throws {
		let result: Double = try studentTPDF(t: 0.0, df: 10)
		#expect(abs(result - 0.3891) < 0.001)
	}

	/// Was "studentTPDF matches legacy pValueStudent for same inputs", which anchored
	/// this implementation to a deleted one. Agreement with `pValueStudent` was never
	/// evidence of correctness — it was evidence that two functions computed the same
	/// expression, and only one of them worked in log-space.
	///
	/// The four input pairs are kept, now measured against
	/// `Γ((ν+1)/2) / (√(νπ)·Γ(ν/2)) · (1 + t²/ν)^(-(ν+1)/2)` evaluated independently.
	@Test("studentTPDF matches an independent evaluation of the density")
	func testMatchesReferenceValues() throws {
		let cases: [(t: Double, df: Int, expected: Double)] = [
			(0.0, 10, 0.3891083840),
			(1.5, 5, 0.1245173446),
			(2.0, 20, 0.0580872152),
			(-1.0, 3, 0.2067483358)
		]
		for entry in cases {
			let result: Double = try studentTPDF(t: entry.t, df: entry.df)
			#expect(approximatelyEqual(result, entry.expected, tolerance: 1e-9),
				"Mismatch at t=\(entry.t), df=\(entry.df): \(result) vs \(entry.expected)")
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

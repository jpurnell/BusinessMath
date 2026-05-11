import Testing
import Foundation
@testable import BusinessMath

@Suite("Two-tailed t p-value")
struct TPValueTests {

	// MARK: - Known Values

	@Test("tPValue(t: 0, df: 10) ≈ 1.0 (two-tailed, symmetric)")
	func testZeroIsOne() throws {
		let result: Double = try tPValue(t: 0.0, df: 10)
		#expect(abs(result - 1.0) < 1e-10)
	}

	@Test("tPValue(t: 2.228, df: 10) ≈ 0.05 (standard critical value)")
	func testCriticalValue() throws {
		let result: Double = try tPValue(t: 2.228, df: 10)
		#expect(abs(result - 0.05) < 0.005)
	}

	@Test("tPValue(t: 1.96, df: 1000) ≈ 0.05 (converges to normal)")
	func testConvergesToNormal() throws {
		let result: Double = try tPValue(t: 1.96, df: 1000)
		#expect(abs(result - 0.05) < 0.005)
	}

	// MARK: - Symmetry

	@Test("tPValue(t: 2, df: 5) == tPValue(t: -2, df: 5)")
	func testSymmetry() throws {
		let positive: Double = try tPValue(t: 2.0, df: 5)
		let negative: Double = try tPValue(t: -2.0, df: 5)
		#expect(abs(positive - negative) < 1e-12)
	}

	// MARK: - Extreme Values

	@Test("Large |t| → p ≈ 0")
	func testLargeTGivesSmallP() throws {
		let result: Double = try tPValue(t: 100.0, df: 10)
		#expect(result < 1e-10)
	}

	// MARK: - Range Check

	@Test("tPValue always in [0, 1]")
	func testAlwaysInUnitInterval() throws {
		let testCases: [(Double, Int)] = [
			(0.0, 1), (1.0, 5), (3.0, 10), (-2.5, 20), (50.0, 100)
		]
		for (tVal, dfVal) in testCases {
			let result: Double = try tPValue(t: tVal, df: dfVal)
			#expect(result >= 0.0 && result <= 1.0,
				"Out of range at t=\(tVal), df=\(dfVal): \(result)")
		}
	}

	// MARK: - Error Cases

	@Test("df ≤ 0 throws invalidInput")
	func testZeroDfThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try tPValue(t: 1.0, df: 0)
		}
	}
}

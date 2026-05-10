import Testing
import Foundation
@testable import BusinessMath

@Suite("Chi-Squared Distribution CDF (Exact)")
struct ChiSquaredCDFTests {

	// MARK: - Boundary Values

	@Test("chiSquaredCDF(0, _) = 0")
	func testZeroBoundary() throws {
		let result: Double = try chiSquaredCDF(x: 0.0, df: 5)
		#expect(result == 0.0)
	}

	@Test("Large x approaches 1")
	func testLargeXApproachesOne() throws {
		let result: Double = try chiSquaredCDF(x: 100.0, df: 5)
		#expect(result > 0.9999)
	}

	// MARK: - Known Critical Values (standard chi-squared tables)

	@Test("chiSquaredCDF(3.841, 1) ≈ 0.95")
	func testCriticalValue_df1() throws {
		let result: Double = try chiSquaredCDF(x: 3.841, df: 1)
		#expect(abs(result - 0.95) < 0.002)
	}

	@Test("chiSquaredCDF(7.815, 3) ≈ 0.95")
	func testCriticalValue_df3() throws {
		let result: Double = try chiSquaredCDF(x: 7.815, df: 3)
		#expect(abs(result - 0.95) < 0.002)
	}

	@Test("chiSquaredCDF(11.070, 5) ≈ 0.95")
	func testCriticalValue_df5() throws {
		let result: Double = try chiSquaredCDF(x: 11.070, df: 5)
		#expect(abs(result - 0.95) < 0.002)
	}

	@Test("chiSquaredCDF(18.307, 10) ≈ 0.95")
	func testCriticalValue_df10() throws {
		let result: Double = try chiSquaredCDF(x: 18.307, df: 10)
		#expect(abs(result - 0.95) < 0.002)
	}

	@Test("chiSquaredCDF(13.816, 5) ≈ 0.983 (99th percentile approx)")
	func testHighPercentile_df5() throws {
		// chi-squared 0.99 critical value for df=5 is 15.086
		let result: Double = try chiSquaredCDF(x: 15.086, df: 5)
		#expect(abs(result - 0.99) < 0.002)
	}

	// MARK: - Mean Property

	@Test("CDF at mean (x=df) ≈ 0.5 for large df")
	func testCDFAtMean() throws {
		// For large df, chi-squared approaches normal(df, 2df)
		// CDF at mean should be close to 0.5
		let result: Double = try chiSquaredCDF(x: 50.0, df: 50)
		#expect(abs(result - 0.5) < 0.05)
	}

	// MARK: - Monotonicity

	@Test("CDF is monotonically increasing")
	func testMonotonicity() throws {
		var previous: Double = 0.0
		for x in stride(from: 0.5, through: 20.0, by: 1.0) {
			let current: Double = try chiSquaredCDF(x: x, df: 5)
			#expect(current >= previous, "CDF decreased at x=\(x)")
			previous = current
		}
	}

	// MARK: - Special Case df=2

	@Test("chiSquaredCDF(x, 2) = 1 - exp(-x/2) (exponential)")
	func testDf2IsExponential() throws {
		// Chi-squared with df=2 is Exponential(1/2)
		for x in [1.0, 2.0, 5.0, 10.0] {
			let result: Double = try chiSquaredCDF(x: x, df: 2)
			let expected = 1.0 - exp(-x / 2.0)
			#expect(abs(result - expected) < 1e-10, "Failed at x=\(x)")
		}
	}

	// MARK: - Error Cases

	@Test("Negative x throws invalidInput")
	func testNegativeXThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try chiSquaredCDF(x: -1.0, df: 5)
		}
	}

	@Test("df = 0 throws invalidInput")
	func testZeroDfThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try chiSquaredCDF(x: 5.0, df: 0)
		}
	}
}

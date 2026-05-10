import Testing
import Foundation
@testable import BusinessMath

@Suite("Student's t-Distribution CDF")
struct TCDFTests {

	// MARK: - Symmetry

	@Test("tCDF(0, _) = 0.5 (symmetric at zero)")
	func testZeroIsHalf() throws {
		let result: Double = try tCDF(t: 0.0, df: 10)
		#expect(abs(result - 0.5) < 1e-12)
	}

	@Test("tCDF(-t, df) = 1 - tCDF(t, df)")
	func testSymmetry() throws {
		let t = 2.0
		let df = 8
		let positive: Double = try tCDF(t: t, df: df)
		let negative: Double = try tCDF(t: -t, df: df)
		#expect(abs(positive + negative - 1.0) < 1e-12)
	}

	// MARK: - Known Critical Values (standard t-tables)

	@Test("t(∞) converges to normal: tCDF(1.96, df=10000) ≈ 0.975")
	func testConvergesToNormal() throws {
		let result: Double = try tCDF(t: 1.96, df: 10000)
		#expect(abs(result - 0.975) < 0.001)
	}

	@Test("tCDF(2.776, 4) ≈ 0.975 (standard table)")
	func testCriticalValue_df4() throws {
		let result: Double = try tCDF(t: 2.776, df: 4)
		#expect(abs(result - 0.975) < 0.002)
	}

	@Test("tCDF(2.228, 10) ≈ 0.975 (standard table)")
	func testCriticalValue_df10() throws {
		let result: Double = try tCDF(t: 2.228, df: 10)
		#expect(abs(result - 0.975) < 0.002)
	}

	@Test("tCDF(1.645, 1000) ≈ 0.95 (large df ≈ normal)")
	func testLargeDf() throws {
		let result: Double = try tCDF(t: 1.645, df: 1000)
		#expect(abs(result - 0.95) < 0.002)
	}

	@Test("tCDF(6.314, 1) ≈ 0.95 (Cauchy-like, df=1)")
	func testDf1() throws {
		let result: Double = try tCDF(t: 6.314, df: 1)
		#expect(abs(result - 0.95) < 0.002)
	}

	// MARK: - Monotonicity

	@Test("CDF is monotonically increasing")
	func testMonotonicity() throws {
		var previous: Double = 0.0
		for t in stride(from: -5.0, through: 5.0, by: 0.5) {
			let current: Double = try tCDF(t: t, df: 10)
			#expect(current >= previous, "CDF decreased at t=\(t)")
			previous = current
		}
	}

	// MARK: - Error Cases

	@Test("df = 0 throws invalidInput")
	func testZeroDfThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try tCDF(t: 1.0, df: 0)
		}
	}
}

@Suite("Student's t-Distribution Quantile (Inverse CDF)")
struct TQuantileTests {

	@Test("tQuantile(0.5, _) = 0 (median is zero)")
	func testMedianIsZero() throws {
		let result: Double = try tQuantile(p: 0.5, df: 10)
		#expect(abs(result) < 1e-6)
	}

	@Test("Round-trip: tQuantile(tCDF(t)) ≈ t")
	func testRoundTrip() throws {
		let t = 2.3
		let df = 15
		let p: Double = try tCDF(t: t, df: df)
		let recovered: Double = try tQuantile(p: p, df: df)
		#expect(abs(recovered - t) < 1e-5)
	}

	@Test("tQuantile(0.975, 10) ≈ 2.228")
	func testKnownQuantile_df10() throws {
		let result: Double = try tQuantile(p: 0.975, df: 10)
		#expect(abs(result - 2.228) < 0.01)
	}

	@Test("tQuantile(0.025, 10) ≈ -2.228 (symmetric)")
	func testNegativeQuantile() throws {
		let result: Double = try tQuantile(p: 0.025, df: 10)
		#expect(abs(result - (-2.228)) < 0.01)
	}

	@Test("p = 0 throws invalidInput")
	func testZeroPThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try tQuantile(p: 0.0, df: 10)
		}
	}

	@Test("p = 1 throws invalidInput")
	func testOnePThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try tQuantile(p: 1.0, df: 10)
		}
	}
}

import Testing
import Foundation
@testable import BusinessMath

@Suite("F-Distribution CDF")
struct FCDFTests {

	// MARK: - Boundary Values

	@Test("fCDF(0, _, _) = 0")
	func testZeroBoundary() throws {
		let result: Double = try fCDF(f: 0.0, df1: 5, df2: 10)
		#expect(result == 0.0)
	}

	@Test("fCDF(∞, _, _) → 1 (large f approaches 1)")
	func testLargeFApproachesOne() throws {
		let result: Double = try fCDF(f: 1000.0, df1: 5, df2: 10)
		#expect(result > 0.9999)
	}

	// MARK: - Known Critical Values (standard F-tables)

	@Test("F(1, 1) at f=1: CDF = 0.5")
	func testF_1_1_at1() throws {
		// F(1,1) is symmetric around 1 in the sense that median = 1 is not quite right
		// Actually for F(k,k), CDF at 1 = 0.5. For F(1,1) this holds.
		// F(1,1) CDF at 1: P(F ≤ 1) where F = chi²(1)/chi²(1)
		// By symmetry of ratio, P(F ≤ 1) = 0.5
		let result: Double = try fCDF(f: 1.0, df1: 1, df2: 1)
		#expect(abs(result - 0.5) < 1e-10)
	}

	@Test("F(5, 5) at f=1: CDF = 0.5 (equal df → symmetric)")
	func testEqualDfSymmetric() throws {
		let result: Double = try fCDF(f: 1.0, df1: 5, df2: 5)
		#expect(abs(result - 0.5) < 1e-10)
	}

	@Test("F(3, 20) at α=0.05 critical value 3.098")
	func testCriticalValue_3_20() throws {
		// F_{0.95}(3, 20) ≈ 3.098 means P(F ≤ 3.098) ≈ 0.95
		let result: Double = try fCDF(f: 3.098, df1: 3, df2: 20)
		#expect(abs(result - 0.95) < 0.005)
	}

	@Test("F(2, 30) at α=0.01 critical value 5.390")
	func testCriticalValue_2_30() throws {
		// F_{0.99}(2, 30) ≈ 5.390 means P(F ≤ 5.390) ≈ 0.99
		let result: Double = try fCDF(f: 5.390, df1: 2, df2: 30)
		#expect(abs(result - 0.99) < 0.005)
	}

	@Test("F(1, 10) at f=4.965: CDF ≈ 0.95")
	func testCriticalValue_1_10() throws {
		let result: Double = try fCDF(f: 4.965, df1: 1, df2: 10)
		#expect(abs(result - 0.95) < 0.005)
	}

	// MARK: - Monotonicity

	@Test("CDF is monotonically increasing")
	func testMonotonicity() throws {
		var previous: Double = 0.0
		for f in stride(from: 0.1, through: 10.0, by: 0.5) {
			let current: Double = try fCDF(f: f, df1: 3, df2: 10)
			#expect(current >= previous, "CDF decreased at f=\(f)")
			previous = current
		}
	}

	// MARK: - Relationship to Beta

	@Test("Verify F-CDF = I_x(df2/2, df1/2) relationship")
	func testBetaRelationship() throws {
		let f = 2.5
		let df1 = 4
		let df2 = 8
		let x = Double(df2) / (Double(df2) + Double(df1) * f)
		let betaResult: Double = try regularizedIncompleteBeta(x: x, a: Double(df2) / 2.0, b: Double(df1) / 2.0)
		let fResult: Double = try fCDF(f: f, df1: df1, df2: df2)
		#expect(abs(fResult - (1.0 - betaResult)) < 1e-12)
	}

	// MARK: - Error Cases

	@Test("Negative f throws invalidInput")
	func testNegativeFThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try fCDF(f: -1.0, df1: 5, df2: 10)
		}
	}

	@Test("df1 = 0 throws invalidInput")
	func testZeroDf1Throws() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try fCDF(f: 1.0, df1: 0, df2: 10)
		}
	}

	@Test("df2 = 0 throws invalidInput")
	func testZeroDf2Throws() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try fCDF(f: 1.0, df1: 5, df2: 0)
		}
	}
}

@Suite("F-Distribution Quantile (Inverse CDF)")
struct FQuantileTests {

	@Test("fQuantile(0.5, df1=df2) = 1.0 (median of equal-df F)")
	func testMedianEqualDf() throws {
		let result: Double = try fQuantile(p: 0.5, df1: 5, df2: 5)
		#expect(abs(result - 1.0) < 1e-6)
	}

	@Test("Round-trip: fQuantile(fCDF(f)) ≈ f")
	func testRoundTrip() throws {
		let f = 2.5
		let df1 = 4
		let df2 = 12
		let p: Double = try fCDF(f: f, df1: df1, df2: df2)
		let recovered: Double = try fQuantile(p: p, df1: df1, df2: df2)
		#expect(abs(recovered - f) < 1e-6)
	}

	@Test("fQuantile(0.95, 3, 20) ≈ 3.098")
	func testKnownQuantile() throws {
		let result: Double = try fQuantile(p: 0.95, df1: 3, df2: 20)
		#expect(abs(result - 3.098) < 0.01)
	}

	@Test("p = 0 throws invalidInput")
	func testZeroPThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try fQuantile(p: 0.0, df1: 5, df2: 10)
		}
	}

	@Test("p = 1 throws invalidInput")
	func testOnePThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try fQuantile(p: 1.0, df1: 5, df2: 10)
		}
	}
}

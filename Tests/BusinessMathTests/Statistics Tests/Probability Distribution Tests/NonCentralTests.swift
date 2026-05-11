import Testing
import Foundation
@testable import BusinessMath

// MARK: - Non-Central Chi-Squared CDF Tests

@Suite("Non-Central Chi-Squared CDF")
struct NonCentralChiSquaredCDFTests {

	// MARK: - Central Case (lambda = 0)

	@Test("lambda = 0 equals central chiSquaredCDF")
	func testCentralCase() throws {
		let central: Double = try chiSquaredCDF(x: 10.0, df: 5)
		let nonCentral: Double = try nonCentralChiSquaredCDF(x: 10.0, df: 5, lambda: 0.0)
		#expect(abs(nonCentral - central) < 1e-10)
	}

	// MARK: - Known Values (cross-validated against scipy ncx2.cdf)

	@Test("ncChiSq(x: 10, df: 3, lambda: 5) approx 0.7066 (scipy: ncx2.cdf(10,3,5))")
	func testKnownValue_df3_lambda5() throws {
		let result: Double = try nonCentralChiSquaredCDF(x: 10.0, df: 3, lambda: 5.0)
		// scipy.stats.ncx2.cdf(10, 3, 5) = 0.7066486
		#expect(abs(result - 0.7066486) < 0.02)
	}

	// MARK: - Distributional Properties

	@Test("Larger lambda shifts distribution right (CDF at same x decreases)")
	func testLargerLambdaShiftsRight() throws {
		let cdf1: Double = try nonCentralChiSquaredCDF(x: 10.0, df: 5, lambda: 2.0)
		let cdf2: Double = try nonCentralChiSquaredCDF(x: 10.0, df: 5, lambda: 8.0)
		#expect(cdf1 > cdf2, "Larger lambda should shift distribution right, reducing CDF at same x")
	}

	@Test("x = 0 returns 0 for any lambda")
	func testXZero() throws {
		let result: Double = try nonCentralChiSquaredCDF(x: 0.0, df: 5, lambda: 3.0)
		#expect(result == 0.0)
	}

	@Test("Large x approaches 1")
	func testLargeXApproachesOne() throws {
		let result: Double = try nonCentralChiSquaredCDF(x: 200.0, df: 5, lambda: 10.0)
		#expect(result > 0.999)
	}

	// MARK: - Error Cases

	@Test("lambda < 0 throws invalidInput")
	func testNegativeLambdaThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try nonCentralChiSquaredCDF(x: 5.0, df: 3, lambda: -1.0)
		}
	}

	@Test("x < 0 throws invalidInput")
	func testNegativeXThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try nonCentralChiSquaredCDF(x: -1.0, df: 3, lambda: 5.0)
		}
	}

	@Test("df <= 0 throws invalidInput")
	func testZeroDfThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try nonCentralChiSquaredCDF(x: 5.0, df: 0, lambda: 5.0)
		}
	}
}

// MARK: - Non-Central F CDF Tests

@Suite("Non-Central F CDF")
struct NonCentralFCDFTests {

	// MARK: - Central Case (lambda = 0)

	@Test("lambda = 0 equals central fCDF")
	func testCentralCase() throws {
		let central: Double = try fCDF(f: 3.0, df1: 5, df2: 20)
		let nonCentral: Double = try nonCentralFCDF(f: 3.0, df1: 5, df2: 20, lambda: 0.0)
		#expect(abs(nonCentral - central) < 1e-10)
	}

	// MARK: - Known Values (cross-validated against scipy ncf.cdf)

	@Test("ncF(f: 3, df1: 5, df2: 20, lambda: 10) approx 0.5240 (scipy: ncf.cdf(3,5,20,10))")
	func testKnownValue_df5_20_lambda10() throws {
		let result: Double = try nonCentralFCDF(f: 3.0, df1: 5, df2: 20, lambda: 10.0)
		// scipy.stats.ncf.cdf(3, 5, 20, 10) = 0.5240361
		#expect(abs(result - 0.5240361) < 0.02)
	}

	// MARK: - Distributional Properties

	@Test("Larger lambda shifts F distribution right")
	func testLargerLambdaShiftsRight() throws {
		let cdf1: Double = try nonCentralFCDF(f: 3.0, df1: 5, df2: 20, lambda: 2.0)
		let cdf2: Double = try nonCentralFCDF(f: 3.0, df1: 5, df2: 20, lambda: 10.0)
		#expect(cdf1 > cdf2, "Larger lambda should shift distribution right, reducing CDF at same f")
	}

	@Test("f = 0 returns 0")
	func testFZero() throws {
		let result: Double = try nonCentralFCDF(f: 0.0, df1: 5, df2: 20, lambda: 5.0)
		#expect(result == 0.0)
	}

	@Test("Large f approaches 1")
	func testLargeFApproachesOne() throws {
		let result: Double = try nonCentralFCDF(f: 1000.0, df1: 5, df2: 20, lambda: 10.0)
		#expect(result > 0.999)
	}

	// MARK: - Error Cases

	@Test("lambda < 0 throws invalidInput")
	func testNegativeLambdaThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try nonCentralFCDF(f: 3.0, df1: 5, df2: 20, lambda: -1.0)
		}
	}

	@Test("f < 0 throws invalidInput")
	func testNegativeFThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try nonCentralFCDF(f: -1.0, df1: 5, df2: 20, lambda: 5.0)
		}
	}

	@Test("df1 <= 0 throws invalidInput")
	func testZeroDf1Throws() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try nonCentralFCDF(f: 3.0, df1: 0, df2: 20, lambda: 5.0)
		}
	}

	@Test("df2 <= 0 throws invalidInput")
	func testZeroDf2Throws() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try nonCentralFCDF(f: 3.0, df1: 5, df2: 0, lambda: 5.0)
		}
	}
}

// MARK: - Non-Central t CDF Tests

@Suite("Non-Central t CDF")
struct NonCentralTCDFTests {

	// MARK: - Central Case (delta = 0)

	@Test("delta = 0 equals central tCDF")
	func testCentralCase() throws {
		let central: Double = try tCDF(t: 2.0, df: 10)
		let nonCentral: Double = try nonCentralTCDF(t: 2.0, df: 10, delta: 0.0)
		#expect(abs(nonCentral - central) < 1e-6)
	}

	// MARK: - Known Values (cross-validated against scipy nct.cdf)

	@Test("ncT(t: 2, df: 10, delta: 1) approx 0.8076 (scipy: nct.cdf(2,10,1))")
	func testKnownValue_df10_delta1() throws {
		let result: Double = try nonCentralTCDF(t: 2.0, df: 10, delta: 1.0)
		// scipy.stats.nct.cdf(2, 10, 1) = 0.8076116
		#expect(abs(result - 0.8076116) < 0.02)
	}

	// MARK: - Distributional Properties

	@Test("delta > 0 shifts distribution right")
	func testPositiveDeltaShiftsRight() throws {
		let central: Double = try tCDF(t: 1.0, df: 15)
		let shifted: Double = try nonCentralTCDF(t: 1.0, df: 15, delta: 2.0)
		// delta > 0 shifts right, so CDF at same t decreases
		#expect(shifted < central, "Positive delta should shift distribution right, reducing CDF at same t")
	}

	@Test("Symmetry: P(T <= t | nu, delta) = 1 - P(T <= -t | nu, -delta)")
	func testSymmetry() throws {
		let pPositive: Double = try nonCentralTCDF(t: 2.0, df: 10, delta: 1.5)
		let pNegative: Double = try nonCentralTCDF(t: -2.0, df: 10, delta: -1.5)
		#expect(abs(pPositive - (1.0 - pNegative)) < 0.02)
	}

	// MARK: - Error Cases

	@Test("df <= 0 throws invalidInput")
	func testZeroDfThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: Double = try nonCentralTCDF(t: 2.0, df: 0, delta: 1.0)
		}
	}
}

// MARK: - Power Analysis Tests

@Suite("Statistical Power Analysis")
struct PowerAnalysisTests {

	// MARK: - t-Test Power

	@Test("Two-sample t-test: d=0.5, n=64 per group, alpha=0.05 gives power approx 0.80")
	func testTwoSampleTTest_classicResult() throws {
		let result: PowerAnalysisResult<Double> = try tTestPower(
			effectSize: 0.5, n: 64, alpha: 0.05, tails: 2, twoSample: true
		)
		// scipy: power = 0.8015
		#expect(abs(result.power - 0.80) < 0.05)
		#expect(result.power > 0.0 && result.power <= 1.0)
	}

	@Test("One-sample t-test: d=0.5, n=64, alpha=0.05 gives very high power")
	func testOneSampleTTest_highPower() throws {
		let result: PowerAnalysisResult<Double> = try tTestPower(
			effectSize: 0.5, n: 64, alpha: 0.05, tails: 2, twoSample: false
		)
		// scipy: power = 0.9761
		#expect(result.power > 0.95)
	}

	@Test("t-test: d=0 gives power approx alpha (no effect)")
	func testNoEffectPowerEqualsAlpha() throws {
		let result: PowerAnalysisResult<Double> = try tTestPower(
			effectSize: 0.0, n: 30, alpha: 0.05, tails: 2, twoSample: false
		)
		#expect(abs(result.power - 0.05) < 0.02)
	}

	@Test("Larger n gives higher power")
	func testLargerNHigherPower() throws {
		let small: PowerAnalysisResult<Double> = try tTestPower(
			effectSize: 0.5, n: 20, alpha: 0.05, tails: 2, twoSample: true
		)
		let large: PowerAnalysisResult<Double> = try tTestPower(
			effectSize: 0.5, n: 100, alpha: 0.05, tails: 2, twoSample: true
		)
		#expect(large.power > small.power)
	}

	@Test("Larger effect size gives higher power")
	func testLargerEffectHigherPower() throws {
		let small: PowerAnalysisResult<Double> = try tTestPower(
			effectSize: 0.2, n: 50, alpha: 0.05, tails: 2, twoSample: true
		)
		let large: PowerAnalysisResult<Double> = try tTestPower(
			effectSize: 0.8, n: 50, alpha: 0.05, tails: 2, twoSample: true
		)
		#expect(large.power > small.power)
	}

	@Test("Two-sample t-test needs larger n than one-sample for same power")
	func testTwoSampleNeedsMoreN() throws {
		let oneSample: PowerAnalysisResult<Double> = try tTestPower(
			effectSize: 0.5, n: 30, alpha: 0.05, tails: 2, twoSample: false
		)
		let twoSample: PowerAnalysisResult<Double> = try tTestPower(
			effectSize: 0.5, n: 30, alpha: 0.05, tails: 2, twoSample: true
		)
		#expect(oneSample.power > twoSample.power)
	}

	@Test("Power is always in [0, 1]")
	func testPowerInRange() throws {
		let result: PowerAnalysisResult<Double> = try tTestPower(
			effectSize: 1.0, n: 100, alpha: 0.05, tails: 2, twoSample: false
		)
		#expect(result.power >= 0.0 && result.power <= 1.0)
	}

	// MARK: - ANOVA Power

	@Test("ANOVA: Cohen's f=0.25, k=3, n=52 per group gives power approx 0.80")
	func testANOVA_classicResult() throws {
		let result: PowerAnalysisResult<Double> = try anovaPower(
			effectSize: 0.25, groups: 3, nPerGroup: 52, alpha: 0.05
		)
		// scipy: power = 0.7967
		#expect(abs(result.power - 0.80) < 0.05)
	}

	@Test("ANOVA: larger n gives higher power")
	func testANOVA_largerNHigherPower() throws {
		let small: PowerAnalysisResult<Double> = try anovaPower(
			effectSize: 0.25, groups: 3, nPerGroup: 20, alpha: 0.05
		)
		let large: PowerAnalysisResult<Double> = try anovaPower(
			effectSize: 0.25, groups: 3, nPerGroup: 100, alpha: 0.05
		)
		#expect(large.power > small.power)
	}

	@Test("ANOVA: larger effect size gives higher power")
	func testANOVA_largerEffectHigherPower() throws {
		let small: PowerAnalysisResult<Double> = try anovaPower(
			effectSize: 0.10, groups: 3, nPerGroup: 50, alpha: 0.05
		)
		let large: PowerAnalysisResult<Double> = try anovaPower(
			effectSize: 0.40, groups: 3, nPerGroup: 50, alpha: 0.05
		)
		#expect(large.power > small.power)
	}

	// MARK: - Error Cases

	@Test("t-test: negative effect size throws invalidInput")
	func testNegativeEffectSizeThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: PowerAnalysisResult<Double> = try tTestPower(
				effectSize: -0.5, n: 30, alpha: 0.05, tails: 2, twoSample: false
			)
		}
	}

	@Test("t-test: n <= 1 throws invalidInput")
	func testTooSmallNThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: PowerAnalysisResult<Double> = try tTestPower(
				effectSize: 0.5, n: 1, alpha: 0.05, tails: 2, twoSample: false
			)
		}
	}

	@Test("t-test: invalid tails throws invalidInput")
	func testInvalidTailsThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: PowerAnalysisResult<Double> = try tTestPower(
				effectSize: 0.5, n: 30, alpha: 0.05, tails: 3, twoSample: false
			)
		}
	}

	@Test("ANOVA: groups < 2 throws invalidInput")
	func testTooFewGroupsThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: PowerAnalysisResult<Double> = try anovaPower(
				effectSize: 0.25, groups: 1, nPerGroup: 30, alpha: 0.05
			)
		}
	}

	@Test("ANOVA: nPerGroup < 2 throws invalidInput")
	func testTooSmallNPerGroupThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: PowerAnalysisResult<Double> = try anovaPower(
				effectSize: 0.25, groups: 3, nPerGroup: 1, alpha: 0.05
			)
		}
	}
}

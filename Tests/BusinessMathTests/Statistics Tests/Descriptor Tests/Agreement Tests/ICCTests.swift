import Testing
import Foundation
@testable import BusinessMath

@Suite("Intraclass Correlation Coefficient (ICC)")
struct ICCTests {

	// MARK: - Perfect Agreement

	@Test("Perfect agreement → ICC ≈ 1.0 for all models")
	func testPerfectAgreement() throws {
		// All raters give identical scores
		let ratings: [[Double]] = [
			[1.0, 1.0, 1.0],
			[5.0, 5.0, 5.0],
			[3.0, 3.0, 3.0],
			[8.0, 8.0, 8.0],
			[2.0, 2.0, 2.0]
		]

		let icc1 = try icc(ratings, model: .oneWayRandom, agreement: .absolute)
		#expect(abs(icc1.icc - 1.0) < 1e-6)

		let icc2 = try icc(ratings, model: .twoWayRandom, agreement: .absolute)
		#expect(abs(icc2.icc - 1.0) < 1e-6)

		let icc3 = try icc(ratings, model: .twoWayMixed, agreement: .consistency)
		#expect(abs(icc3.icc - 1.0) < 1e-6)
	}

	// MARK: - ICC(3,1) Consistency: Systematic Offset Should Not Reduce ICC

	@Test("ICC(3,1) consistency: systematic rater offset does not reduce ICC")
	func testConsistencyWithOffset() throws {
		// Rater B always gives +5 more than rater A, rater C +10 more
		// This is pure systematic bias → consistency should be ≈ 1.0
		let ratings: [[Double]] = [
			[1.0, 6.0, 11.0],
			[3.0, 8.0, 13.0],
			[5.0, 10.0, 15.0],
			[7.0, 12.0, 17.0],
			[9.0, 14.0, 19.0]
		]

		let result = try icc(ratings, model: .twoWayMixed, agreement: .consistency)
		#expect(abs(result.icc - 1.0) < 1e-6)
	}

	// MARK: - ICC(2,1) Absolute: Systematic Offset SHOULD Reduce ICC

	@Test("ICC(2,1) absolute: systematic rater offset reduces ICC")
	func testAbsoluteWithOffset() throws {
		// Same data as consistency test — large systematic bias
		let ratings: [[Double]] = [
			[1.0, 6.0, 11.0],
			[3.0, 8.0, 13.0],
			[5.0, 10.0, 15.0],
			[7.0, 12.0, 17.0],
			[9.0, 14.0, 19.0]
		]

		let result = try icc(ratings, model: .twoWayRandom, agreement: .absolute)
		// With large systematic bias, absolute ICC should be noticeably less than 1
		#expect(result.icc < 0.95)
	}

	// MARK: - ICC(2,1) ≤ ICC(3,1) When Rater Bias Exists

	@Test("ICC(2,1) absolute ≤ ICC(3,1) consistency when rater bias exists")
	func testAbsoluteLessThanConsistency() throws {
		let ratings: [[Double]] = [
			[2.0, 5.0, 8.0],
			[4.0, 7.0, 10.0],
			[6.0, 9.0, 12.0],
			[8.0, 11.0, 14.0]
		]

		let absolute = try icc(ratings, model: .twoWayRandom, agreement: .absolute)
		let consistency = try icc(ratings, model: .twoWayMixed, agreement: .consistency)

		#expect(absolute.icc <= consistency.icc + 1e-10)
	}

	// MARK: - Random Noise → ICC Near 0

	@Test("Random noise → ICC near 0")
	func testRandomNoiseNearZero() throws {
		// Deterministic pseudo-random data with no subject signal
		// Each row sums to roughly the same thing; there's no consistent
		// subject pattern across raters
		let ratings: [[Double]] = [
			[7.0, 2.0, 9.0, 4.0],
			[3.0, 8.0, 1.0, 6.0],
			[5.0, 9.0, 3.0, 7.0],
			[8.0, 1.0, 6.0, 2.0],
			[2.0, 7.0, 4.0, 9.0],
			[6.0, 3.0, 8.0, 1.0],
			[4.0, 6.0, 2.0, 8.0],
			[9.0, 4.0, 7.0, 3.0]
		]

		let result = try icc(ratings, model: .oneWayRandom, agreement: .absolute)
		// ICC should be near zero (could be slightly negative)
		#expect(result.icc < 0.3)
		#expect(result.icc > -0.5)
	}

	// MARK: - Confidence Interval Contains ICC

	@Test("Confidence interval contains the ICC value")
	func testCIContainsICC() throws {
		let ratings: [[Double]] = [
			[9.0, 8.0, 7.0],
			[6.0, 5.0, 4.0],
			[3.0, 2.0, 1.0],
			[8.0, 7.0, 6.0],
			[5.0, 4.0, 3.0]
		]

		let result1 = try icc(ratings, model: .oneWayRandom, agreement: .absolute)
		#expect(result1.lowerBound <= result1.icc)
		#expect(result1.icc <= result1.upperBound)

		let result2 = try icc(ratings, model: .twoWayRandom, agreement: .absolute)
		#expect(result2.lowerBound <= result2.icc)
		#expect(result2.icc <= result2.upperBound)

		let result3 = try icc(ratings, model: .twoWayMixed, agreement: .consistency)
		#expect(result3.lowerBound <= result3.icc)
		#expect(result3.icc <= result3.upperBound)
	}

	// MARK: - More Subjects → Narrower CI

	@Test("More subjects → narrower confidence interval")
	func testMoreSubjectsNarrowerCI() throws {
		// Small sample: 3 subjects
		let small: [[Double]] = [
			[9.0, 8.0, 7.0],
			[6.0, 5.0, 4.0],
			[3.0, 2.0, 1.0]
		]

		// Larger sample: 8 subjects with same rater pattern
		let large: [[Double]] = [
			[9.0, 8.0, 7.0],
			[6.0, 5.0, 4.0],
			[3.0, 2.0, 1.0],
			[8.0, 7.0, 6.0],
			[5.0, 4.0, 3.0],
			[7.0, 6.0, 5.0],
			[4.0, 3.0, 2.0],
			[2.0, 1.0, 0.0]
		]

		let smallResult = try icc(small, model: .oneWayRandom, agreement: .absolute)
		let largeResult = try icc(large, model: .oneWayRandom, agreement: .absolute)

		let smallWidth = smallResult.upperBound - smallResult.lowerBound
		let largeWidth = largeResult.upperBound - largeResult.lowerBound

		#expect(largeWidth < smallWidth)
	}

	// MARK: - Result Metadata

	@Test("ICC result contains correct subjects and raters counts")
	func testResultMetadata() throws {
		let ratings: [[Double]] = [
			[1.0, 2.0, 3.0, 4.0],
			[5.0, 6.0, 7.0, 8.0],
			[9.0, 10.0, 11.0, 12.0]
		]

		let result = try icc(ratings, model: .oneWayRandom, agreement: .absolute)
		#expect(result.subjects == 3)
		#expect(result.raters == 4)
	}

	// MARK: - Error Cases

	@Test("Single rater throws")
	func testSingleRaterThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try icc([[1.0], [2.0], [3.0]], model: .oneWayRandom, agreement: .absolute)
		}
	}

	@Test("Single subject throws")
	func testSingleSubjectThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try icc([[1.0, 2.0, 3.0]], model: .oneWayRandom, agreement: .absolute)
		}
	}

	@Test("Ragged matrix throws")
	func testRaggedMatrixThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try icc([[1.0, 2.0], [3.0, 4.0, 5.0]], model: .twoWayRandom, agreement: .absolute)
		}
	}
}

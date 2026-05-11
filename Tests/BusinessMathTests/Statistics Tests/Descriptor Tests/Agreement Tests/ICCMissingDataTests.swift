import Testing
import Foundation
@testable import BusinessMath

@Suite("ICC with Missing Data (EM Algorithm)")
struct ICCMissingDataTests {

	// MARK: - Test 1: Complete data matches standard ICC

	@Test("Complete data (no nils) produces same ICC as standard icc() within tolerance")
	func testCompleteDataMatchesStandard() throws {
		let ratings: [[Double]] = [
			[9.0, 8.0, 7.0],
			[6.0, 5.0, 4.0],
			[3.0, 2.0, 1.0],
			[8.0, 7.0, 6.0],
			[5.0, 4.0, 3.0]
		]

		// Standard ICC with complete data
		let standardResult = try icc(ratings, model: .twoWayRandom, agreement: .absolute)

		// Convert to optional form (no nils)
		let optionalRatings: [[Double?]] = ratings.map { $0.map { $0 as Double? } }
		let emResult = try icc(
			optionalRatings,
			model: .twoWayRandom,
			agreement: .absolute
		)

		// EM (ML) and ANOVA (method-of-moments) estimators differ for small samples
		#expect(abs(emResult.icc - standardResult.icc) < 0.05)
		#expect(emResult.converged == true)
		#expect(emResult.subjects == 5)
		#expect(emResult.raters == 3)
		#expect(emResult.observedCells == 15)
	}

	// MARK: - Test 2: Single missing cell

	@Test("Single missing cell: ICC changes smoothly from complete-data value")
	func testSingleMissingCell() throws {
		let complete: [[Double]] = [
			[9.0, 8.0, 7.0],
			[6.0, 5.0, 4.0],
			[3.0, 2.0, 1.0],
			[8.0, 7.0, 6.0],
			[5.0, 4.0, 3.0]
		]
		let standardResult = try icc(complete, model: .twoWayRandom, agreement: .absolute)

		let withMissing: [[Double?]] = [
			[9.0, 8.0, 7.0],
			[6.0, nil, 4.0],
			[3.0, 2.0, 1.0],
			[8.0, 7.0, 6.0],
			[5.0, 4.0, 3.0]
		]
		let emResult = try icc(
			withMissing,
			model: .twoWayRandom,
			agreement: .absolute
		)

		// ICC should be close to complete-data value (within 0.1)
		#expect(abs(emResult.icc - standardResult.icc) < 0.1)
		#expect(emResult.converged == true)
		#expect(emResult.observedCells == 14)
	}

	// MARK: - Test 3: 50% missing data

	@Test("50% missing data: converges, ICC in [0, 1]")
	func testHalfMissing() throws {
		// Checkerboard-like pattern — roughly 50% missing
		let ratings: [[Double?]] = [
			[9.0, nil, 7.0, nil],
			[nil, 5.0, nil, 4.0],
			[3.0, nil, 1.0, nil],
			[nil, 7.0, nil, 6.0],
			[5.0, nil, 3.0, nil],
			[nil, 2.0, nil, 8.0]
		]

		let result = try icc(
			ratings,
			model: .twoWayRandom,
			agreement: .absolute
		)

		#expect(result.icc >= 0.0)
		#expect(result.icc <= 1.0)
		#expect(result.converged == true)
		#expect(result.observedCells == 12)
	}

	// MARK: - Test 4: All data for one subject missing

	@Test("All data for one subject missing: excluded, does not crash")
	func testEntireSubjectMissing() throws {
		let ratings: [[Double?]] = [
			[9.0, 8.0, 7.0],
			[nil, nil, nil],  // Entire subject missing
			[3.0, 2.0, 1.0],
			[8.0, 7.0, 6.0],
			[5.0, 4.0, 3.0]
		]

		let result = try icc(
			ratings,
			model: .twoWayRandom,
			agreement: .absolute
		)

		// Should use only 4 subjects with data
		#expect(result.subjects == 4)
		#expect(result.raters == 3)
		#expect(result.converged == true)
	}

	// MARK: - Test 5: All data for one rater missing

	@Test("All data for one rater missing: excluded, does not crash")
	func testEntireRaterMissing() throws {
		let ratings: [[Double?]] = [
			[9.0, nil, 7.0],
			[6.0, nil, 4.0],
			[3.0, nil, 1.0],
			[8.0, nil, 6.0],
			[5.0, nil, 3.0]
		]

		let result = try icc(
			ratings,
			model: .twoWayRandom,
			agreement: .absolute
		)

		// Should use only 2 raters with data
		#expect(result.subjects == 5)
		#expect(result.raters == 2)
		#expect(result.converged == true)
	}

	// MARK: - Test 6: Perfect agreement with missing data

	@Test("Perfect agreement with missing data: ICC ≈ 1.0")
	func testPerfectAgreementMissing() throws {
		// All raters give identical scores; some are just missing
		let ratings: [[Double?]] = [
			[1.0, 1.0, nil],
			[5.0, nil, 5.0],
			[nil, 3.0, 3.0],
			[8.0, 8.0, 8.0],
			[2.0, 2.0, nil]
		]

		let result = try icc(
			ratings,
			model: .twoWayRandom,
			agreement: .absolute
		)

		#expect(result.icc > 0.95)
	}

	// MARK: - Test 7: Perfect disagreement → ICC near 0

	@Test("Perfect disagreement: ICC near 0")
	func testPerfectDisagreement() throws {
		// No consistent subject pattern — noise dominates
		let ratings: [[Double?]] = [
			[7.0, nil, 1.0, 9.0],
			[nil, 8.0, 6.0, nil],
			[2.0, 9.0, nil, 3.0],
			[nil, 1.0, 7.0, nil],
			[5.0, nil, 2.0, 8.0],
			[nil, 4.0, nil, 1.0],
			[9.0, 2.0, nil, 5.0],
			[nil, 7.0, 3.0, nil]
		]

		let result = try icc(
			ratings,
			model: .twoWayRandom,
			agreement: .absolute
		)

		// ICC should be near zero or slightly negative
		#expect(result.icc < 0.5)
	}

	// MARK: - Test 8: Convergence flag is true

	@Test("Convergence flag is true for well-conditioned data")
	func testConvergenceFlag() throws {
		let ratings: [[Double?]] = [
			[9.0, 8.0, 7.0],
			[6.0, 5.0, nil],
			[3.0, nil, 1.0],
			[8.0, 7.0, 6.0],
			[5.0, 4.0, 3.0]
		]

		let result = try icc(
			ratings,
			model: .twoWayMixed,
			agreement: .consistency
		)

		#expect(result.converged == true)
		#expect(result.iterations > 0)
	}

	// MARK: - Test 9: Non-convergence with maxIterations=2

	@Test("Non-convergence: maxIterations=2 with complex data → converged == false")
	func testNonConvergence() throws {
		// Complex data that won't converge in 2 iterations
		let ratings: [[Double?]] = [
			[100.0, nil, 1.0, nil, 50.0],
			[nil, 200.0, nil, 2.0, nil],
			[1.0, nil, 100.0, nil, 1.0],
			[nil, 2.0, nil, 200.0, nil],
			[50.0, nil, 1.0, nil, 100.0],
			[nil, 100.0, nil, 50.0, nil]
		]

		let result = try icc(
			ratings,
			model: .twoWayRandom,
			agreement: .absolute,
			maxIterations: 2
		)

		#expect(result.converged == false)
		#expect(result.iterations == 2)
	}

	// MARK: - Test 10: Fewer than 2 subjects with data

	@Test("Fewer than 2 subjects with data throws insufficientData")
	func testTooFewSubjects() throws {
		let ratings: [[Double?]] = [
			[1.0, 2.0, 3.0],
			[nil, nil, nil],
			[nil, nil, nil]
		]

		#expect(throws: BusinessMathError.self) {
			let _ = try icc(
				ratings,
				model: .twoWayRandom,
				agreement: .absolute
			)
		}
	}

	// MARK: - Test 11: Fewer than 2 raters with data

	@Test("Fewer than 2 raters with data throws insufficientData")
	func testTooFewRaters() throws {
		let ratings: [[Double?]] = [
			[1.0, nil, nil],
			[2.0, nil, nil],
			[3.0, nil, nil]
		]

		#expect(throws: BusinessMathError.self) {
			let _ = try icc(
				ratings,
				model: .twoWayRandom,
				agreement: .absolute
			)
		}
	}

	// MARK: - Test 12: Ragged matrix

	@Test("Ragged matrix throws mismatchedDimensions")
	func testRaggedMatrix() throws {
		let ratings: [[Double?]] = [
			[1.0, 2.0],
			[3.0, 4.0, 5.0]
		]

		#expect(throws: BusinessMathError.self) {
			let _ = try icc(
				ratings,
				model: .twoWayRandom,
				agreement: .absolute
			)
		}
	}

	// MARK: - Test 13: All-nil matrix

	@Test("All-nil matrix throws insufficientData")
	func testAllNilMatrix() throws {
		let ratings: [[Double?]] = [
			[nil, nil, nil],
			[nil, nil, nil],
			[nil, nil, nil]
		]

		#expect(throws: BusinessMathError.self) {
			let _ = try icc(
				ratings,
				model: .twoWayRandom,
				agreement: .absolute
			)
		}
	}
}

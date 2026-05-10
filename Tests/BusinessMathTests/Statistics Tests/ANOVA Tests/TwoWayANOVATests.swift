import Testing
import Foundation
@testable import BusinessMath

@Suite("Two-Way ANOVA (without replication)")
struct TwoWayANOVATests {

	// MARK: - Known Textbook Example

	@Test("3 subjects × 3 raters textbook decomposition")
	func testTextbookExample() throws {
		// 3 subjects rated by 3 raters:
		// Subject 1: [4, 5, 6]  row mean = 5
		// Subject 2: [2, 3, 4]  row mean = 3
		// Subject 3: [8, 9, 10] row mean = 9
		// Col means: [14/3, 17/3, 20/3] ≈ [4.667, 5.667, 6.667]
		// Grand mean = (4+5+6+2+3+4+8+9+10)/9 = 51/9 = 5.667
		// n=3, k=3
		// ssSubjects = 3 * [(5-17/3)² + (3-17/3)² + (9-17/3)²]
		//            = 3 * [(−2/3)² + (−8/3)² + (10/3)²]
		//            = 3 * [4/9 + 64/9 + 100/9]
		//            = 3 * 168/9 = 56
		// ssRaters = 3 * [(14/3 - 17/3)² + (17/3 - 17/3)² + (20/3 - 17/3)²]
		//          = 3 * [(-1)² + 0² + 1²] = 3 * 2 = 6
		// ssTotal = Σ(x_ij - grand)²
		//   = (4-17/3)² + (5-17/3)² + (6-17/3)² + (2-17/3)² + (3-17/3)² + (4-17/3)² + (8-17/3)² + (9-17/3)² + (10-17/3)²
		//   Let g = 17/3:
		//   = (−5/3)² + (−2/3)² + (1/3)² + (−11/3)² + (−8/3)² + (−5/3)² + (7/3)² + (10/3)² + (13/3)²
		//   = 25/9 + 4/9 + 1/9 + 121/9 + 64/9 + 25/9 + 49/9 + 100/9 + 169/9
		//   = 558/9 = 62
		// ssError = ssTotal - ssSubjects - ssRaters = 62 - 56 - 6 = 0
		// (This data has linear pattern: each rater adds 1, so no interaction/error)

		let ratings: [[Double]] = [
			[4.0, 5.0, 6.0],
			[2.0, 3.0, 4.0],
			[8.0, 9.0, 10.0]
		]
		let result = try twoWayANOVA(ratings)

		#expect(abs(result.ssSubjects - 56.0) < 1e-10)
		#expect(abs(result.ssRaters - 6.0) < 1e-10)
		#expect(abs(result.ssError - 0.0) < 1e-10)
		#expect(abs(result.ssTotal - 62.0) < 1e-10)
		#expect(result.dfSubjects == 2)
		#expect(result.dfRaters == 2)
		#expect(result.dfError == 4)
	}

	// MARK: - SS Decomposition Identity

	@Test("ssTotal = ssSubjects + ssRaters + ssError")
	func testSSDecomposition() throws {
		let ratings: [[Double]] = [
			[3.0, 5.0, 7.0, 2.0],
			[8.0, 6.0, 4.0, 9.0],
			[1.0, 2.0, 3.0, 5.0],
			[6.0, 7.0, 8.0, 4.0],
			[2.0, 3.0, 5.0, 1.0]
		]
		let result = try twoWayANOVA(ratings)

		let reconstructed = result.ssSubjects + result.ssRaters + result.ssError
		#expect(abs(result.ssTotal - reconstructed) < 1e-10)
	}

	// MARK: - DF Decomposition

	@Test("dfSubjects + dfRaters + dfError = n×k - 1")
	func testDFDecomposition() throws {
		let ratings: [[Double]] = [
			[1.0, 2.0, 3.0],
			[4.0, 5.0, 6.0],
			[7.0, 8.0, 9.0],
			[10.0, 11.0, 12.0]
		]
		let result = try twoWayANOVA(ratings)
		let n = ratings.count
		let k = ratings[0].count
		#expect(result.dfSubjects + result.dfRaters + result.dfError == n * k - 1)
	}

	// MARK: - All Raters Agree

	@Test("All raters give same score → ssRaters = 0")
	func testAllRatersAgree() throws {
		// Each subject gets the same score from all raters
		let ratings: [[Double]] = [
			[5.0, 5.0, 5.0],
			[3.0, 3.0, 3.0],
			[8.0, 8.0, 8.0],
			[1.0, 1.0, 1.0]
		]
		let result = try twoWayANOVA(ratings)

		#expect(abs(result.ssRaters) < 1e-10)
		#expect(abs(result.ssError) < 1e-10)
	}

	// MARK: - All Subjects Identical

	@Test("All subjects identical → ssSubjects = 0")
	func testAllSubjectsIdentical() throws {
		// Each subject has same row → no between-subject variation
		let ratings: [[Double]] = [
			[4.0, 6.0, 8.0],
			[4.0, 6.0, 8.0],
			[4.0, 6.0, 8.0]
		]
		let result = try twoWayANOVA(ratings)

		#expect(abs(result.ssSubjects) < 1e-10)
		#expect(abs(result.ssError) < 1e-10)
	}

	// MARK: - Error Cases

	@Test("Single subject throws insufficientData")
	func testSingleSubjectThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try twoWayANOVA([[1.0, 2.0, 3.0]])
		}
	}

	@Test("Single rater throws insufficientData")
	func testSingleRaterThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try twoWayANOVA([[1.0], [2.0], [3.0]])
		}
	}

	@Test("Ragged matrix throws mismatchedDimensions")
	func testRaggedMatrixThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try twoWayANOVA([[1.0, 2.0, 3.0], [4.0, 5.0]])
		}
	}

	@Test("Empty matrix throws insufficientData")
	func testEmptyMatrixThrows() throws {
		let empty: [[Double]] = []
		#expect(throws: BusinessMathError.self) {
			let _ = try twoWayANOVA(empty)
		}
	}
}

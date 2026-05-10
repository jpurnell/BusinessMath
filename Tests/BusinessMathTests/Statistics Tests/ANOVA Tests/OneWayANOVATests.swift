import Testing
import Foundation
@testable import BusinessMath

@Suite("One-Way ANOVA")
struct OneWayANOVATests {

	// MARK: - Known Textbook Example

	@Test("Three groups with known SS decomposition")
	func testThreeGroups() throws {
		// Group 1: [3, 4, 5], mean = 4
		// Group 2: [6, 7, 8], mean = 7
		// Group 3: [1, 2, 3], mean = 2
		// Grand mean = (3+4+5+6+7+8+1+2+3)/9 = 39/9 = 4.333...
		// SS_B = 3*(4-4.333)² + 3*(7-4.333)² + 3*(2-4.333)² = 3*0.111 + 3*7.111 + 3*5.444 = 38.0
		// SS_W = (1+0+1) + (1+0+1) + (1+0+1) = 6.0
		// SS_T = 38 + 6 = 44
		// df_B = 2, df_W = 6
		// MS_B = 38/2 = 19, MS_W = 6/6 = 1
		// F = 19/1 = 19

		let groups: [[Double]] = [
			[3.0, 4.0, 5.0],
			[6.0, 7.0, 8.0],
			[1.0, 2.0, 3.0]
		]
		let result = try oneWayANOVA(groups)

		#expect(abs(result.ssBetween - 38.0) < 1e-10)
		#expect(abs(result.ssWithin - 6.0) < 1e-10)
		#expect(abs(result.ssTotal - 44.0) < 1e-10)
		#expect(result.dfBetween == 2)
		#expect(result.dfWithin == 6)
		#expect(abs(result.msBetween - 19.0) < 1e-10)
		#expect(abs(result.msWithin - 1.0) < 1e-10)
		#expect(abs(result.fStatistic - 19.0) < 1e-10)
		#expect(result.groupCount == 3)
		#expect(result.totalCount == 9)
	}

	@Test("p-value for F=19, df1=2, df2=6 is small")
	func testPValueSignificant() throws {
		let groups: [[Double]] = [
			[3.0, 4.0, 5.0],
			[6.0, 7.0, 8.0],
			[1.0, 2.0, 3.0]
		]
		let result = try oneWayANOVA(groups)
		#expect(result.pValue < 0.01)
	}

	// MARK: - All Groups Identical

	@Test("Identical groups → F = 0, p ≈ 1")
	func testIdenticalGroups() throws {
		let groups: [[Double]] = [
			[5.0, 5.0, 5.0],
			[5.0, 5.0, 5.0],
			[5.0, 5.0, 5.0]
		]
		let result = try oneWayANOVA(groups)
		#expect(abs(result.ssBetween) < 1e-10)
		#expect(abs(result.fStatistic) < 1e-10)
		#expect(result.pValue > 0.99)
	}

	// MARK: - Unbalanced Design

	@Test("Unbalanced groups (different sizes)")
	func testUnbalancedDesign() throws {
		// Group 1: [2, 4, 6], n=3, mean=4
		// Group 2: [10, 12], n=2, mean=11
		// Grand mean = (2+4+6+10+12)/5 = 34/5 = 6.8
		// SS_B = 3*(4-6.8)² + 2*(11-6.8)² = 3*7.84 + 2*17.64 = 23.52 + 35.28 = 58.8
		// SS_W = (4+0+4) + (1+1) = 10.0
		// df_B = 1, df_W = 3
		// MS_B = 58.8, MS_W = 10/3 = 3.333
		// F = 58.8/3.333 = 17.64

		let groups: [[Double]] = [
			[2.0, 4.0, 6.0],
			[10.0, 12.0]
		]
		let result = try oneWayANOVA(groups)

		#expect(abs(result.ssBetween - 58.8) < 1e-10)
		#expect(abs(result.ssWithin - 10.0) < 1e-10)
		#expect(result.dfBetween == 1)
		#expect(result.dfWithin == 3)
		#expect(result.totalCount == 5)
	}

	// MARK: - SS Decomposition Identity

	@Test("SS_total = SS_between + SS_within always holds")
	func testSSDecomposition() throws {
		let groups: [[Double]] = [
			[1.5, 3.2, 2.8],
			[7.1, 6.5, 8.0, 7.2],
			[4.0, 3.5]
		]
		let result = try oneWayANOVA(groups)
		#expect(abs(result.ssTotal - (result.ssBetween + result.ssWithin)) < 1e-10)
	}

	@Test("df_between + df_within = N - 1")
	func testDfDecomposition() throws {
		let groups: [[Double]] = [
			[1.0, 2.0, 3.0],
			[4.0, 5.0],
			[6.0, 7.0, 8.0, 9.0]
		]
		let result = try oneWayANOVA(groups)
		#expect(result.dfBetween + result.dfWithin == result.totalCount - 1)
	}

	// MARK: - p-value Consistency

	@Test("p-value consistent with fCDF")
	func testPValueConsistency() throws {
		let groups: [[Double]] = [
			[3.0, 4.0, 5.0],
			[6.0, 7.0, 8.0],
			[1.0, 2.0, 3.0]
		]
		let result = try oneWayANOVA(groups)
		let expectedP = try 1.0 - fCDF(f: result.fStatistic, df1: result.dfBetween, df2: result.dfWithin)
		#expect(abs(result.pValue - expectedP) < 1e-10)
	}

	// MARK: - Error Cases

	@Test("Single group throws insufficientData")
	func testSingleGroupThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try oneWayANOVA([[1.0, 2.0, 3.0]])
		}
	}

	@Test("Empty groups array throws insufficientData")
	func testEmptyGroupsThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: OneWayANOVAResult<Double> = try oneWayANOVA([])
		}
	}

	@Test("Group with no observations throws insufficientData")
	func testEmptyGroupThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _ = try oneWayANOVA([[1.0, 2.0], []])
		}
	}
}

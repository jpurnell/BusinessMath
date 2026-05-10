import Testing
import Foundation
@testable import BusinessMath

@Suite("Successive Differences")
struct SuccessiveDifferencesTests {

	@Test("[1, 3, 2, 5] → [2, 1, 3]")
	func testBasicCase() throws {
		let result: [Double] = try successiveDifferences([1.0, 3.0, 2.0, 5.0])
		#expect(result == [2.0, 1.0, 3.0])
	}

	@Test("Constant series → all zeros")
	func testConstantSeries() throws {
		let result: [Double] = try successiveDifferences([5.0, 5.0, 5.0, 5.0])
		#expect(result == [0.0, 0.0, 0.0])
	}

	@Test("Negative values → correct absolute differences")
	func testNegativeValues() throws {
		let result: [Double] = try successiveDifferences([-3.0, 2.0, -1.0])
		#expect(result == [5.0, 3.0])
	}

	@Test("Two elements → single difference")
	func testTwoElements() throws {
		let result: [Double] = try successiveDifferences([10.0, 7.0])
		#expect(result == [3.0])
	}

	@Test("Monotonically increasing → equal differences for linear")
	func testMonotonic() throws {
		let result: [Double] = try successiveDifferences([1.0, 3.0, 5.0, 7.0])
		#expect(result == [2.0, 2.0, 2.0])
	}

	@Test("Single element → throws insufficientData")
	func testSingleElementThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: [Double] = try successiveDifferences([42.0])
		}
	}

	@Test("Empty array → throws insufficientData")
	func testEmptyArrayThrows() throws {
		#expect(throws: BusinessMathError.self) {
			let _: [Double] = try successiveDifferences([])
		}
	}
}

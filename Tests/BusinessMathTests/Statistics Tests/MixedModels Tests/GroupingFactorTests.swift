import Testing
@testable import BusinessMath

@Suite("GroupingFactor")
struct GroupingFactorTests {

	@Test("Basic grouping with contiguous IDs")
	func basicGrouping() throws {
		let gf = try GroupingFactor([0, 0, 1, 1, 2, 2])
		#expect(gf.groupCount == 3)
		#expect(gf.groupSizes == [2, 2, 2])
		#expect(gf.groups == [0, 0, 1, 1, 2, 2])
	}

	@Test("Non-contiguous group IDs are remapped")
	func nonContiguousIDs() throws {
		let gf = try GroupingFactor([10, 10, 20, 20, 30])
		#expect(gf.groupCount == 3)
		#expect(gf.groupSizes == [2, 2, 1])
	}

	@Test("Unbalanced groups")
	func unbalancedGroups() throws {
		let gf = try GroupingFactor([0, 0, 0, 1, 2, 2])
		#expect(gf.groupCount == 3)
		#expect(gf.groupSizes == [3, 1, 2])
	}

	@Test("Group indices are correct")
	func groupIndices() throws {
		let gf = try GroupingFactor([0, 1, 0, 1, 0])
		#expect(gf.groupIndices[0] == [0, 2, 4])
		#expect(gf.groupIndices[1] == [1, 3])
	}

	@Test("Empty groups throws")
	func emptyThrows() throws {
		#expect(throws: BusinessMathError.self) {
			try GroupingFactor([])
		}
	}

	@Test("Negative group ID throws")
	func negativeThrows() throws {
		#expect(throws: BusinessMathError.self) {
			try GroupingFactor([0, -1, 1])
		}
	}

	@Test("Single group")
	func singleGroup() throws {
		let gf = try GroupingFactor([5, 5, 5])
		#expect(gf.groupCount == 1)
		#expect(gf.groupSizes == [3])
	}
}

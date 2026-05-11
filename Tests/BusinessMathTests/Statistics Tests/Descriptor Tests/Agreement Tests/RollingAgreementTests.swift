import Testing
import Foundation
@testable import BusinessMath

@Suite("Rolling Agreement")
struct RollingAgreementTests {

	// MARK: - Rolling CCC

	@Test("Window = full series: single result matching unweighted CCC")
	func testFullWindowMatchesUnweighted() throws {
		let x: [Double] = [1.0, 3.5, 2.0, 5.5, 4.0, 6.0]
		let y: [Double] = [1.5, 3.0, 2.5, 5.0, 4.5, 6.5]

		let rolling = try rollingCCC(x, y, windowSize: x.count)
		#expect(rolling.count == 1)

		let unweighted = try concordanceCorrelationCoefficient(x, y)
		#expect(abs(rolling[0].ccc.ccc - unweighted.ccc) < 1e-10)
	}

	@Test("Window = 3: produces correct number of results")
	func testWindowThreeCount() throws {
		let x: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
		let y: [Double] = [1.1, 2.1, 3.1, 4.1, 5.1, 6.1, 7.1, 8.1]

		let rolling = try rollingCCC(x, y, windowSize: 3, step: 1)
		// Windows: [0..2], [1..3], [2..4], [3..5], [4..6], [5..7] → 6 windows
		let expectedCount = (x.count - 3) / 1 + 1
		#expect(rolling.count == expectedCount)
	}

	@Test("Step = 2: produces correct count")
	func testStepTwoCount() throws {
		let x: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
		let y: [Double] = [1.1, 2.1, 3.1, 4.1, 5.1, 6.1, 7.1, 8.1]

		let rolling = try rollingCCC(x, y, windowSize: 3, step: 2)
		// Windows: start=0, start=2, start=4 → 3 windows (start=6 would go to index 8 which is out of bounds)
		let expectedCount = (x.count - 3) / 2 + 1
		#expect(rolling.count == expectedCount)
	}

	@Test("Series shorter than window: throws insufficientData")
	func testSeriesShorterThanWindowThrows() throws {
		let x: [Double] = [1.0, 2.0]
		let y: [Double] = [1.0, 2.0]
		#expect(throws: BusinessMathError.self) {
			_ = try rollingCCC(x, y, windowSize: 5)
		}
	}

	@Test("Window < 3: throws invalidInput")
	func testWindowTooSmallThrows() throws {
		let x: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
		let y: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
		#expect(throws: BusinessMathError.self) {
			_ = try rollingCCC(x, y, windowSize: 2)
		}
	}

	// MARK: - Rolling Bland-Altman

	@Test("Window = full series: matches unweighted Bland-Altman")
	func testFullWindowBAMatchesUnweighted() throws {
		let x: [Double] = [1.0, 3.5, 2.0, 5.5, 4.0, 6.0]
		let y: [Double] = [1.5, 3.0, 2.5, 5.0, 4.5, 6.5]

		let rolling = try rollingBlandAltman(x, y, windowSize: x.count)
		#expect(rolling.count == 1)

		let unweighted = try blandAltman(x, y)
		#expect(abs(rolling[0].result.bias - unweighted.bias) < 1e-10)
		#expect(abs(rolling[0].result.standardDeviation - unweighted.standardDeviation) < 1e-10)
	}

	@Test("Known drift pattern: rolling bias shows trend")
	func testRollingBiasShowsDrift() throws {
		// x stays constant, y drifts upward → differences become more negative over time
		let x: [Double] = [5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0]
		let y: [Double] = [5.0, 5.2, 5.4, 5.6, 5.8, 6.0, 6.2, 6.4, 6.6, 6.8]

		let rolling = try rollingBlandAltman(x, y, windowSize: 4, step: 1)
		#expect(rolling.count > 2)

		// Bias should become more negative over time (x - y becomes more negative)
		let firstBias = rolling[0].result.bias
		let lastBias = rolling[rolling.count - 1].result.bias
		#expect(lastBias < firstBias)
	}

	@Test("Window < 2: throws invalidInput")
	func testBAWindowTooSmallThrows() throws {
		let x: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
		let y: [Double] = [1.0, 2.0, 3.0, 4.0, 5.0]
		#expect(throws: BusinessMathError.self) {
			_ = try rollingBlandAltman(x, y, windowSize: 1)
		}
	}
}

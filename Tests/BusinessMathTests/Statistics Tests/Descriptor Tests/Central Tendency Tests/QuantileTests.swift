import Testing
import Foundation
@testable import BusinessMath

@Suite("Empirical Quantile (R-7)")
struct QuantileTests {

	// MARK: - Reference Values

	/// Reference values produced by R `quantile(x, p, type = 7)` and
	/// NumPy `np.quantile(x, p, method = "linear")` for x = 1...10.
	@Test("Matches R type-7 / NumPy linear on 1...10",
		  arguments: [
			(0.00, 1.0),
			(0.10, 1.9),
			(0.25, 3.25),
			(0.30, 3.7),
			(0.40, 4.6),
			(0.50, 5.5),
			(0.60, 6.4),
			(0.75, 7.75),
			(0.90, 9.1),
			(1.00, 10.0)
		  ])
	func matchesReferenceImplementation(p: Double, expected: Double) {
		let sorted = (1...10).map(Double.init)
		#expect(abs(quantile(sorted: sorted, p: p) - expected) < 1e-12)
	}

	@Test("Interpolates between adjacent order statistics")
	func interpolatesBetweenOrderStatistics() {
		// n = 5, p = 0.30 -> position 0.3 * 4 = 1.2 -> 20 + 0.2 * (30 - 20) = 22
		let sorted = [10.0, 20.0, 30.0, 40.0, 50.0]
		#expect(abs(quantile(sorted: sorted, p: 0.30) - 22.0) < 1e-12)
		// position exactly on an index returns that order statistic
		#expect(quantile(sorted: sorted, p: 0.25) == 20.0)
	}

	@Test("Median agrees with median() for odd and even counts")
	func medianAgreement() {
		let odd = [1.0, 3.0, 7.0, 9.0, 100.0]
		let even = [1.0, 3.0, 7.0, 9.0]
		#expect(abs(quantile(sorted: odd, p: 0.5) - median(odd)) < 1e-12)
		#expect(abs(quantile(sorted: even, p: 0.5) - median(even)) < 1e-12)
	}

	// MARK: - Boundary and Degenerate Inputs

	@Test("Empty input returns NaN rather than trapping")
	func emptyInputReturnsNaN() {
		#expect(quantile(sorted: [Double](), p: 0.5).isNaN)
	}

	@Test("Single element returns that element for every p")
	func singleElement() {
		for p in [-1.0, 0.0, 0.37, 1.0, 2.0] {
			#expect(quantile(sorted: [42.0], p: p) == 42.0)
		}
	}

	@Test("p outside [0, 1] clamps to the extremes rather than trapping")
	func clampsOutOfRangeP() {
		let sorted = [10.0, 20.0, 30.0]
		#expect(quantile(sorted: sorted, p: -0.5) == 10.0)
		#expect(quantile(sorted: sorted, p: 1.5) == 30.0)
		#expect(quantile(sorted: sorted, p: -.infinity) == 10.0)
		#expect(quantile(sorted: sorted, p: .infinity) == 30.0)
	}

	@Test("NaN p yields NaN")
	func nanProbability() {
		#expect(quantile(sorted: [10.0, 20.0, 30.0], p: Double.nan).isNaN)
	}

	@Test("Result is monotone non-decreasing in p")
	func monotoneInP() {
		let sorted = [1.0, 4.0, 4.0, 9.0, 16.0, 25.0, 36.0]
		var previous = -Double.infinity
		for i in 0...100 {
			let value = quantile(sorted: sorted, p: Double(i) / 100.0)
			#expect(value >= previous)
			previous = value
		}
	}

	// MARK: - Genericity

	@Test("Works for Float as well as Double")
	func genericOverScalar() {
		let sorted: [Float] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
		#expect(abs(quantile(sorted: sorted, p: Float(0.25)) - 3.25) < 1e-5)
	}
}

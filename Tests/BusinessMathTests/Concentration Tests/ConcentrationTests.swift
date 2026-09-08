//
//  ConcentrationTests.swift
//  BusinessMath
//
//  Gini, Lorenz and top-share concentration.
//
//  The Gini coefficient has two definitions that look nothing alike — half the relative
//  mean absolute difference between every pair, and twice the area between the Lorenz
//  curve and the diagonal — and they are the same number. The implementation computes
//  one; these tests compute the other. That is the check the spec asks for, and it is
//  exact rather than approximate.
//
//  The two bounds are exact too and need no reference at all: a perfectly equal
//  distribution has Gini zero, and one where a single unit holds everything has Gini
//  `(n − 1)/n` — not one. The sample coefficient cannot reach one at finite `n`, and an
//  implementation that reports 1.0 for the most unequal five-element sample has silently
//  switched to the population form.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Concentration")
struct ConcentrationTests {

	/// Gini as half the relative mean absolute difference, by the naive double loop.
	///
	/// The other definition from the one the implementation uses, written the slow
	/// obvious way on purpose.
	private static func giniByPairs(_ values: [Double]) -> Double {
		let n = values.count
		var total: Double = 0
		for a in values {
			for b in values { total += Swift.abs(a - b) }
		}
		let mean: Double = values.reduce(0, +) / Double(n)
		let denominator: Double = 2 * Double(n) * Double(n) * mean
		return total / denominator
	}

	// MARK: - The two definitions agree

	@Test("Gini from the Lorenz area equals Gini from pairwise differences")
	func twoDefinitionsAgree() throws {
		let datasets: [(String, [Double])] = [
			("equal", [10, 10, 10, 10, 10]),
			("gentle", [1, 2, 3, 4, 5]),
			("extreme", [1, 1, 1, 1, 96]),
			("pareto", [50, 25, 12, 6, 3, 2, 1, 1]),
		]
		var compared = 0
		for (name, values) in datasets {
			let concentration = try #require(Concentration(values: values))
			let pairwise: Double = Self.giniByPairs(values)
			#expect(Swift.abs(concentration.gini - pairwise) < 1e-12,
					"\(name): Lorenz gives \(concentration.gini), pairs give \(pairwise)")
			compared += 1
		}
		#expect(compared == 4, "only \(compared) of 4 datasets were compared")
	}

	@Test("Gini matches an external computation")
	func giniAgainstReference() throws {
		let cases: [(values: [Double], gini: Double)] = [
			([10, 10, 10, 10, 10], 0.0),
			([1, 2, 3, 4, 5], 0.2666666667),
			([1, 1, 1, 1, 96], 0.76),
			([50, 25, 12, 6, 3, 2, 1, 1], 0.62),
		]
		var checked = 0
		for row in cases {
			let concentration = try #require(Concentration(values: row.values))
			#expect(Swift.abs(concentration.gini - row.gini) < 1e-9,
					"Gini \(concentration.gini), expected \(row.gini)")
			checked += 1
		}
		#expect(checked == 4, "only \(checked) of 4 Gini values were checked")
	}

	// MARK: - The two bounds, which need no reference

	@Test("A perfectly equal distribution has a Gini of exactly zero")
	func equalityIsZero() throws {
		var checked = 0
		for size in [2, 5, 50] {
			let values = [Double](repeating: 7, count: size)
			let concentration = try #require(Concentration(values: values))
			#expect(concentration.gini == 0, "n=\(size) gave \(concentration.gini)")
			checked += 1
		}
		#expect(checked == 3, "only \(checked) sizes were checked")
	}

	@Test("Maximum inequality is (n-1)/n, not one")
	func maximumIsSampleBounded() throws {
		// One unit holds everything. The sample Gini cannot reach one at finite n, and a
		// result of 1.0 here would mean the population form had been used instead.
		var checked = 0
		for size in [2, 5, 10, 100] {
			var values = [Double](repeating: 0, count: size)
			values[size - 1] = 100
			let concentration = try #require(Concentration(values: values))
			let bound: Double = Double(size - 1) / Double(size)
			#expect(Swift.abs(concentration.gini - bound) < 1e-12,
					"n=\(size): Gini \(concentration.gini), bound \(bound)")
			#expect(concentration.gini < 1, "the sample Gini must stay below one")
			checked += 1
		}
		#expect(checked == 4, "only \(checked) sizes were checked")
	}

	@Test("Gini is scale invariant and order independent")
	func invariances() throws {
		// Doubling every income leaves inequality unchanged — the coefficient is
		// relative — and the answer cannot depend on the order the data arrived in.
		let base: [Double] = [3, 1, 4, 1, 5, 9, 2, 6]
		let plain = try #require(Concentration(values: base))
		let scaled = try #require(Concentration(values: base.map { $0 * 1000 }))
		let shuffled = try #require(Concentration(values: base.sorted()))
		#expect(Swift.abs(plain.gini - scaled.gini) < 1e-12,
				"scaling changed the Gini: \(plain.gini) against \(scaled.gini)")
		#expect(Swift.abs(plain.gini - shuffled.gini) < 1e-12,
				"ordering changed the Gini: \(plain.gini) against \(shuffled.gini)")
	}

	// MARK: - Lorenz

	@Test("The Lorenz curve is the cumulative share against the cumulative population")
	func lorenzCurve() throws {
		let concentration = try #require(Concentration(values: [1, 2, 3, 4, 5]))
		let points = concentration.lorenzCurve
		let reference: [(population: Double, share: Double)] = [
			(0.2, 0.0666666667), (0.4, 0.2), (0.6, 0.4), (0.8, 0.6666666667), (1.0, 1.0),
		]
		#expect(points.count == reference.count, "got \(points.count) points")
		var compared = 0
		for (point, row) in zip(points, reference) {
			#expect(Swift.abs(point.population - row.population) < 1e-12,
					"population \(point.population)")
			#expect(Swift.abs(point.share - row.share) < 1e-9,
					"share \(point.share), expected \(row.share)")
			compared += 1
		}
		#expect(compared == 5, "only \(compared) points were compared")
		// The curve must end at (1, 1) and never rise above the diagonal.
		let last = try #require(points.last)
		#expect(Swift.abs(last.share - 1) < 1e-12, "the curve ends at \(last.share)")
		for point in points {
			#expect(point.share <= point.population + 1e-12,
					"the Lorenz curve rose above the diagonal at \(point.population)")
		}
	}

	@Test("Under perfect equality the Lorenz curve is the diagonal")
	func lorenzDiagonal() throws {
		let concentration = try #require(Concentration(values: [5, 5, 5, 5]))
		for point in concentration.lorenzCurve {
			#expect(Swift.abs(point.share - point.population) < 1e-12,
					"at \(point.population) the share was \(point.share)")
		}
	}

	// MARK: - Top share

	@Test("The top share answers the eighty-twenty question")
	func topShare() throws {
		let concentration = try #require(Concentration(values: [50, 25, 12, 6, 3, 2, 1, 1]))
		// The top quarter — two of eight — hold 75 of 100.
		let quarter = try #require(concentration.topShare(fraction: 0.25))
		#expect(Swift.abs(quarter - 0.75) < 1e-12, "top quarter holds \(quarter)")
		// The whole population holds everything.
		let all = try #require(concentration.topShare(fraction: 1))
		#expect(Swift.abs(all - 1) < 1e-12, "the whole population holds \(all)")
	}

	@Test("A fraction outside the unit interval has no answer")
	func topShareRefusals() throws {
		let concentration = try #require(Concentration(values: [1, 2, 3, 4]))
		#expect(concentration.topShare(fraction: 0) == nil)
		#expect(concentration.topShare(fraction: -0.5) == nil)
		#expect(concentration.topShare(fraction: 1.5) == nil)
	}

	// MARK: - Refusals

	@Test("Concentration refuses data that has none to measure")
	func refusals() {
		#expect(Concentration<Double>(values: []) == nil)
		// A negative value is not a share of anything, and it can drive the Lorenz curve
		// above the diagonal, where the Gini stops meaning what it says.
		#expect(Concentration(values: [1, -2, 3]) == nil)
		#expect(Concentration(values: [1, Double.nan]) == nil)
		// Everything zero: the coefficient divides by the mean, and a distribution with
		// nothing in it has no concentration rather than a concentration of zero.
		#expect(Concentration(values: [0, 0, 0]) == nil)
	}
}

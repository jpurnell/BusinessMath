//
//  MultiWayANOVAOracleTests.swift
//  BusinessMath
//
//  An exact oracle for the three-facet `multiWayANOVA`.
//
//  `MultiWayANOVATests` has eight tests, and for the **two**-facet case one of them is a real
//  oracle: it cross-checks against `twoWayANOVA`, an independent implementation. For the
//  three-facet case, which is what the inclusion-exclusion algorithm exists for, the
//  substantive assertions are:
//
//  | assertion | what a wrongly-split decomposition does |
//  |---|---|
//  | the seven `SS` sum to `SS_total` | passes — the split can be wrong and still total |
//  | the seven `df` sum to `N - 1` | passes — `df` comes from the dimensions, not the data |
//  | `MS = SS / df` for every effect | passes — `MS` *is* computed that way |
//  | identical observations give `SS = 0` | passes for almost any decomposition |
//  | three facets produce seven effects | structural |
//
//  Every one of those survives an `SS` that is split wrongly *between* effects. A term
//  credited to `A` that belongs to `A × B` leaves the total untouched.
//
//  ## Where the expected values come from
//
//  The data is built from seven mutually orthogonal effects, so its sums of squares are
//  known in closed form from the effect arrays alone:
//
//      SS(A) = n_b n_c SUM a^2      SS(AB) = n_c SUM ab^2      SS(ABC) = SUM abc^2
//
//  Nothing is recomputed from the observations. The construction is shared with
//  `GStudyTwoFacetOracleTests` through `OrthogonalEffects` rather than copied.
//
//  ## Why 4 × 3 × 2
//
//  Each effect's `SS` carries a different multiplier — `n_b n_c`, `n_a n_c`, `n_a n_b` for
//  the main effects and `n_c`, `n_b`, `n_a` for the two-way ones. At 4 × 3 × 2 those are
//  6, 8, 12, 2, 3, 4: six distinct values, so a multiplier taken from the wrong facet cannot
//  coincide with the right one. A design with two equal dimensions hides exactly that.
//

import Testing
import Foundation
import Numerics
import TestSupport
@testable import BusinessMath

@Suite("Three-facet ANOVA against constructed orthogonal effects")
struct MultiWayANOVAOracleTests {

	private static let nA = 4
	private static let nB = 3
	private static let nC = 2

	private struct Design {
		let a: [Double], b: [Double], c: [Double]
		let ab: [[Double]], ac: [[Double]], bc: [[Double]]
		let abc: [[[Double]]]
		let values: [Double]
	}

	/// Deterministic, index-derived effects. No RNG: the expected answers must be a function
	/// of this file, not of a seed.
	private static func design() -> Design {
		var rawA: [Double] = []
		for i in 0..<nA {
			let raw: Int = (i * 7) % 11
			rawA.append(Double(raw) - 5)
		}
		var rawB: [Double] = []
		for i in 0..<nB {
			let raw: Int = (i * 5) % 9
			rawB.append(Double(raw) - 4)
		}
		var rawC: [Double] = []
		for i in 0..<nC {
			let raw: Int = (i * 3) % 7
			rawC.append(Double(raw) - 3)
		}
		let a: [Double] = OrthogonalEffects.centred(rawA)
		let b: [Double] = OrthogonalEffects.centred(rawB)
		let c: [Double] = OrthogonalEffects.centred(rawC)

		var rawAB: [[Double]] = []
		for i in 0..<nA {
			var row: [Double] = []
			for j in 0..<nB {
				let raw: Int = (i * 3 + j * 5) % 7
				row.append(Double(raw) - 3)
			}
			rawAB.append(row)
		}
		// `(i * 5 + k * 2) % 9` was the first spelling here and it produced **no A×C
		// interaction at all**: with only two levels of C, `5i` runs 0, 5, 1, 6 and adding 2
		// never crosses 9, so every row's column difference was the same constant -2 and
		// the double-centred residual vanished. `everyEffectContributes` is what caught it
		// — the same guard, for the same reason, as in `GStudyTwoFacetOracleTests`, where a
		// modulus that shared a factor with a coefficient cancelled a whole axis.
		//
		// A modulus the increments actually wrap around is the fix: `(4i + 5k) % 7` gives
		// column differences -5, 2, -5, 2.
		var rawAC: [[Double]] = []
		for i in 0..<nA {
			var row: [Double] = []
			for k in 0..<nC {
				let raw: Int = (i * 4 + k * 5) % 7
				row.append(Double(raw) - 3)
			}
			rawAC.append(row)
		}
		var rawBC: [[Double]] = []
		for j in 0..<nB {
			var row: [Double] = []
			for k in 0..<nC {
				let raw: Int = (j * 2 + k * 7) % 5
				row.append(Double(raw) - 2)
			}
			rawBC.append(row)
		}
		let ab: [[Double]] = OrthogonalEffects.doubleCentred(rawAB)
		let ac: [[Double]] = OrthogonalEffects.doubleCentred(rawAC)
		let bc: [[Double]] = OrthogonalEffects.doubleCentred(rawBC)

		var rawABC: [[[Double]]] = []
		for i in 0..<nA {
			var plane: [[Double]] = []
			for j in 0..<nB {
				var row: [Double] = []
				for k in 0..<nC {
					let product: Int = (i + 1) * (j + 2) * (k + 3)
					let raw: Int = product % 11
					row.append(Double(raw) - 5)
				}
				plane.append(row)
			}
			rawABC.append(plane)
		}
		let abc: [[[Double]]] = OrthogonalEffects.tripleCentred(rawABC)

		// Row-major, which is what `CrossedDesignData` expects.
		let mu = 10.0
		var values: [Double] = []
		for i in 0..<nA {
			for j in 0..<nB {
				for k in 0..<nC {
					let mains: Double = a[i] + b[j] + c[k]
					let twos: Double = ab[i][j] + ac[i][k] + bc[j][k]
					values.append(mu + mains + twos + abc[i][j][k])
				}
			}
		}
		return Design(a: a, b: b, c: c, ab: ab, ac: ac, bc: bc, abc: abc, values: values)
	}

	private static func build() throws -> (CrossedDesignData<Double>, Design) {
		let d = design()
		let data = try CrossedDesignData(
			values: d.values, facetNames: ["A", "B", "C"], dimensions: [nA, nB, nC])
		return (data, d)
	}

	/// The sums of squares the construction fixes.
	private static func expectedSumOfSquares(_ d: Design) -> [Set<String>: Double] {
		let a = Double(nA), b = Double(nB), c = Double(nC)
		return [
			["A"]: b * c * OrthogonalEffects.sumSquares(d.a),
			["B"]: a * c * OrthogonalEffects.sumSquares(d.b),
			["C"]: a * b * OrthogonalEffects.sumSquares(d.c),
			["A", "B"]: c * OrthogonalEffects.sumSquares(d.ab),
			["A", "C"]: b * OrthogonalEffects.sumSquares(d.ac),
			["B", "C"]: a * OrthogonalEffects.sumSquares(d.bc),
			["A", "B", "C"]: OrthogonalEffects.sumSquares(d.abc)
		]
	}

	private static func expectedDegreesOfFreedom() -> [Set<String>: Int] {
		let dfA = nA - 1, dfB = nB - 1, dfC = nC - 1
		return [
			["A"]: dfA, ["B"]: dfB, ["C"]: dfC,
			["A", "B"]: dfA * dfB, ["A", "C"]: dfA * dfC, ["B", "C"]: dfB * dfC,
			["A", "B", "C"]: dfA * dfB * dfC
		]
	}

	/// Measured, not chosen: worst relative gap across the seven effects is 3.4e-15.
	private static let bound = 1e-9

	// MARK: - The tests

	@Test("Every sum of squares is the one the effects fix, not merely one that totals")
	func sumsOfSquaresMatchTheConstruction() throws {
		let (data, d) = try Self.build()
		let result = try multiWayANOVA(data)
		let want = Self.expectedSumOfSquares(d)

		var worst = 0.0
		for (effect, expected) in want {
			let got = try #require(result.sumOfSquares[effect],
								   "no sum of squares reported for \(effect.sorted())")
			let scale: Double = Swift.max(abs(expected), 1.0)
			let gap: Double = abs(got - expected) / scale
			if gap > worst { worst = gap }
			#expect(gap < Self.bound,
					"\(effect.sorted()): SS \(got), constructed \(expected)")
		}
		#expect(want.count == 7, "expected seven effects, built \(want.count)")
		#expect(worst < Self.bound, "worst relative gap was \(worst)")
	}

	@Test("Degrees of freedom match the design")
	func degreesOfFreedomMatch() throws {
		let (data, _) = try Self.build()
		let result = try multiWayANOVA(data)
		for (effect, expected) in Self.expectedDegreesOfFreedom() {
			let got = try #require(result.degreesOfFreedom[effect])
			#expect(got == expected, "\(effect.sorted()): df \(got), expected \(expected)")
		}
	}

	@Test("The construction actually exercises all seven effects")
	func everyEffectContributes() throws {
		// The fixture's own guard. A design whose two-way terms vanished would leave the
		// test above asserting that several zeros equal several zeros, and it would pass.
		let d = Self.design()
		let want = Self.expectedSumOfSquares(d)
		let largest = want.values.max() ?? 0
		for (effect, ss) in want {
			#expect(ss > largest * 1e-6,
					"\(effect.sorted()) contributes \(ss), which is not a term")
		}
	}

	@Test("The design separates the six multipliers")
	func multipliersAreDistinct() {
		// Each effect's SS carries a different product of dimensions. If two coincided, an
		// SS computed with the wrong one would still come out right, and the oracle above
		// would be blind to exactly the error it is for.
		let a = Double(Self.nA), b = Double(Self.nB), c = Double(Self.nC)
		let multipliers: [Double] = [b * c, a * c, a * b, c, b, a]
		let distinct = Set(multipliers.map { $0.description })
		#expect(distinct.count == multipliers.count,
				"multipliers \(multipliers) are not all distinct")
	}
}

//
//  InterpolationReferenceTests.swift
//  BusinessMath
//
//  An external oracle for the interpolators, from SciPy.
//
//  The four existing interpolation test files hold 76 tests and check no value
//  against anything outside the package. What they do check is real but weak:
//  that the interpolant passes through its knots, that a query between two knots
//  lands between their values, that the out-of-bounds policies fire. Every
//  interpolation scheme ever written satisfies all of that — passing through the
//  knots is what makes something an interpolator rather than a fit.
//
//  What distinguishes the schemes is their shape *between* the knots, and that is
//  set by choices no self-consistency check can see:
//
//  - **Which cubic spline boundary condition.** Natural sets `f'' = 0` at the
//    ends; not-a-knot makes the third derivative continuous at the second and
//    second-to-last knots. They agree nowhere except at the knots. Not-a-knot is
//    the SciPy and MATLAB default, natural the common textbook one, and picking
//    the wrong one produces a perfectly smooth curve through every data point.
//  - **Which Akima.** The 1970 original divides by a sum of slope differences
//    that vanishes when three points are collinear; `makima` adds a term that
//    removes the degeneracy. BusinessMath defaults to `modified: true` and SciPy
//    to the original, so the fixture carries both.
//  - **PCHIP's slope rule.** The harmonic mean is what makes it monotone. Other
//    plausible slope choices interpolate the knots just as well and none of them
//    preserve shape.
//
//  ## What is checked without SciPy at all
//
//  Two properties are stronger than any fixture because they cannot be satisfied
//  by accident:
//
//  - **Polynomial reproduction.** A scheme of degree `d` must reproduce every
//    polynomial of degree `d` exactly, everywhere and not just at the knots. A
//    linear interpolant on collinear data, and a not-a-knot cubic spline on a
//    cubic, have one right answer at every query point.
//  - **PCHIP does not overshoot.** On monotone data the interpolant is monotone
//    and stays inside the local data range. That is the reason to choose PCHIP
//    over a spline, and a spline *will* overshoot the same data — so the test
//    also confirms the two schemes are genuinely different code.
//
//  Values from Tests/BusinessMathTests/Fixtures/interpolation.json.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Interpolation against SciPy")
struct InterpolationReferenceTests {

	// MARK: - Fixture

	private struct Fixture: Decodable {
		let name: String
		let reference: String
		let note: String
		let cases: [Case]
	}

	private struct Scheme: Decodable {
		let note: String
		let values: [Double]
	}

	private struct Case: Decodable {
		let name: String
		let note: String
		let xs: [Double]
		let ys: [Double]
		let query: [Double]
		let schemes: [String: Scheme]
	}

	private static func loadFixture() throws -> Fixture {
		guard let url = Bundle.module.url(forResource: "interpolation", withExtension: "json",
										  subdirectory: "Fixtures")
			?? Bundle.module.url(forResource: "interpolation", withExtension: "json") else {
			struct Missing: Error { let name: String }
			throw Missing(name: "interpolation")
		}
		return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
	}

	/// Compares a whole scheme against its reference values.
	///
	/// - Parameters:
	///   - entry: The dataset.
	///   - key: The scheme's name in the fixture.
	///   - tolerance: Relative bound; stated per call because the schemes are not
	///     equally conditioned — a global polynomial through twelve points loses
	///     far more precision than a piecewise cubic.
	///   - evaluate: The package's interpolant at a query point.
	/// - Returns: How many values were compared, so a caller can insist the
	///   comparison actually happened.
	@discardableResult
	private static func compare(_ entry: Case, _ key: String, tolerance: Double,
								_ evaluate: (Double) -> Double) -> Int {
		guard let scheme = entry.schemes[key] else { return 0 }
		guard scheme.values.count == entry.query.count else {
			Issue.record("\(entry.name)/\(key): \(scheme.values.count) values for \(entry.query.count) queries")
			return 0
		}
		var compared = 0
		for (index, x) in entry.query.enumerated() {
			let reference = scheme.values[index]
			let got = evaluate(x)
			let scale = Swift.max(1.0, abs(reference))
			#expect(abs(got - reference) < tolerance * scale,
					"\(entry.name)/\(key) at x=\(x): got \(got), SciPy \(reference)")
			compared += 1
		}
		return compared
	}

	// MARK: - The fixture

	@Test("The fixture separates the schemes rather than sampling only knots")
	func fixtureIsWellFormed() throws {
		let fixture = try Self.loadFixture()
		#expect(fixture.reference.contains("scipy"), "reference was '\(fixture.reference)'")
		#expect(fixture.cases.count >= 7, "only \(fixture.cases.count) datasets")

		for entry in fixture.cases {
			// Knots alone would make every scheme agree, which is the trap this
			// whole file exists to avoid. Interior samples are the point.
			let interior = entry.query.filter { x in !entry.xs.contains { abs($0 - x) < 1e-12 } }
			#expect(interior.count >= entry.xs.count,
					"\(entry.name): only \(interior.count) off-knot samples for \(entry.xs.count) knots")
		}

		// Both Akima variants must be present, or the default cannot be pinned.
		let akima = fixture.cases.filter { $0.schemes["akimaOriginal"] != nil && $0.schemes["akimaModified"] != nil }
		#expect(akima.count >= 4, "only \(akima.count) datasets carry both Akima variants")
		// And the two must actually differ somewhere, or comparing against either
		// would pass.
		let differs = akima.contains { entry in
			guard let a = entry.schemes["akimaOriginal"], let b = entry.schemes["akimaModified"] else { return false }
			return zip(a.values, b.values).contains { abs($0 - $1) > 1e-9 }
		}
		#expect(differs, "the two Akima variants agree everywhere in the corpus, so neither is pinned")
	}

	// MARK: - Piecewise schemes

	@Test("Linear interpolation matches np.interp")
	func linearMatchesSciPy() throws {
		let fixture = try Self.loadFixture()
		var compared = 0
		for entry in fixture.cases {
			let interp = try LinearInterpolator(xs: entry.xs, ys: entry.ys)
			compared += Self.compare(entry, "linear", tolerance: 1e-12) { interp($0) }
		}
		#expect(compared >= 190, "only \(compared) values compared")
	}

	@Test("The cubic spline matches SciPy under each boundary condition")
	func cubicSplineMatchesSciPy() throws {
		let fixture = try Self.loadFixture()
		var natural = 0, notAKnot = 0, clamped = 0
		for entry in fixture.cases where entry.xs.count >= 3 {
			// The tridiagonal solve behind a spline is well conditioned on these
			// grids, so agreement should be near machine precision.
			let n = try CubicSplineInterpolator(xs: entry.xs, ys: entry.ys, boundary: .natural)
			natural += Self.compare(entry, "cubicSplineNatural", tolerance: 1e-10) { n($0) }

			let k = try CubicSplineInterpolator(xs: entry.xs, ys: entry.ys, boundary: .notAKnot)
			notAKnot += Self.compare(entry, "cubicSplineNotAKnot", tolerance: 1e-10) { k($0) }

			let c = try CubicSplineInterpolator(xs: entry.xs, ys: entry.ys,
												boundary: .clamped(left: 0, right: 0))
			clamped += Self.compare(entry, "cubicSplineClamped", tolerance: 1e-10) { c($0) }
		}
		#expect(natural >= 150, "only \(natural) natural values compared")
		#expect(notAKnot >= 150, "only \(notAKnot) not-a-knot values compared")
		#expect(clamped >= 150, "only \(clamped) clamped values compared")
	}

	@Test("The two boundary conditions genuinely disagree away from the knots")
	func boundaryConditionsAreNotInterchangeable() throws {
		let fixture = try Self.loadFixture()
		var separated = 0
		for entry in fixture.cases where entry.xs.count >= 4 {
			let natural = try CubicSplineInterpolator(xs: entry.xs, ys: entry.ys, boundary: .natural)
			let notAKnot = try CubicSplineInterpolator(xs: entry.xs, ys: entry.ys, boundary: .notAKnot)
			// If these produced the same curve, the test above would pass against
			// either fixture column and prove nothing about which is implemented.
			let anyDifference = entry.query.contains { abs(natural($0) - notAKnot($0)) > 1e-6 }
			if anyDifference { separated += 1 }
			// At the knots they must agree exactly, whatever they do between.
			for (i, x) in entry.xs.enumerated() {
				#expect(abs(natural(x) - entry.ys[i]) < 1e-9, "\(entry.name): natural misses knot \(i)")
				#expect(abs(notAKnot(x) - entry.ys[i]) < 1e-9, "\(entry.name): not-a-knot misses knot \(i)")
			}
		}
		#expect(separated >= 4, "only \(separated) datasets show the boundary conditions differing")
	}

	@Test("Akima matches SciPy, and the default is the modified form")
	func akimaMatchesSciPy() throws {
		let fixture = try Self.loadFixture()
		var original = 0, modified = 0
		for entry in fixture.cases where entry.xs.count >= 3 {
			let o = try AkimaInterpolator(xs: entry.xs, ys: entry.ys, modified: false)
			original += Self.compare(entry, "akimaOriginal", tolerance: 1e-10) { o($0) }

			let m = try AkimaInterpolator(xs: entry.xs, ys: entry.ys, modified: true)
			modified += Self.compare(entry, "akimaModified", tolerance: 1e-10) { m($0) }

			// The documented default. Checked against the modified column so a
			// silent flip of the default would show as a fixture mismatch.
			let byDefault = try AkimaInterpolator(xs: entry.xs, ys: entry.ys)
			for x in entry.query {
				#expect(abs(byDefault(x) - m(x)) < 1e-12,
						"\(entry.name) at x=\(x): the default Akima is not the modified form")
			}
		}
		#expect(original >= 150, "only \(original) original-Akima values compared")
		#expect(modified >= 150, "only \(modified) modified-Akima values compared")
	}

	@Test("PCHIP matches SciPy")
	func pchipMatchesSciPy() throws {
		let fixture = try Self.loadFixture()
		var compared = 0
		for entry in fixture.cases where entry.xs.count >= 3 {
			let interp = try PCHIPInterpolator(xs: entry.xs, ys: entry.ys)
			compared += Self.compare(entry, "pchip", tolerance: 1e-10) { interp($0) }
		}
		#expect(compared >= 150, "only \(compared) values compared")
	}

	@Test("Barycentric matches SciPy where the polynomial is well conditioned")
	func barycentricMatchesSciPy() throws {
		let fixture = try Self.loadFixture()
		var compared = 0
		for entry in fixture.cases where entry.xs.count <= 8 {
			let interp = try BarycentricLagrangeInterpolator(xs: entry.xs, ys: entry.ys)
			// A single global polynomial through eight points is far worse
			// conditioned than a piecewise cubic, and the loss grows with the
			// spread of the knots. Bounded looser for that reason and no other;
			// `unevenSpacing` spans three orders of magnitude.
			compared += Self.compare(entry, "barycentric", tolerance: 1e-8) { interp($0) }
		}
		#expect(compared >= 100, "only \(compared) values compared")
	}

	// MARK: - Properties that need no reference

	@Test("Every scheme reproduces a straight line exactly, between the knots too")
	func allSchemesReproduceALine() throws {
		let fixture = try Self.loadFixture()
		guard let entry = fixture.cases.first(where: { $0.name == "linearData" }) else {
			Issue.record("linearData dataset missing"); return
		}
		// y = 3 + 2x. Degree one, so every scheme here — of degree one or above —
		// must return it exactly at every query point, not merely at the knots.
		// Nothing about this claim depends on SciPy.
		let interpolants: [(String, (Double) -> Double)] = [
			("linear", try { let i = try LinearInterpolator(xs: entry.xs, ys: entry.ys); return { i($0) } }()),
			("natural", try { let i = try CubicSplineInterpolator(xs: entry.xs, ys: entry.ys, boundary: .natural); return { i($0) } }()),
			("notAKnot", try { let i = try CubicSplineInterpolator(xs: entry.xs, ys: entry.ys, boundary: .notAKnot); return { i($0) } }()),
			("akima", try { let i = try AkimaInterpolator(xs: entry.xs, ys: entry.ys); return { i($0) } }()),
			("pchip", try { let i = try PCHIPInterpolator(xs: entry.xs, ys: entry.ys); return { i($0) } }()),
			("barycentric", try { let i = try BarycentricLagrangeInterpolator(xs: entry.xs, ys: entry.ys); return { i($0) } }()),
		]
		for (name, evaluate) in interpolants {
			for x in entry.query {
				let expected: Double = 3.0 + 2.0 * x
				#expect(abs(evaluate(x) - expected) < 1e-10,
						"\(name) at x=\(x): got \(evaluate(x)), the line gives \(expected)")
			}
		}
	}

	@Test("A not-a-knot spline reproduces a cubic exactly and a natural one does not")
	func notAKnotReproducesCubics() throws {
		let fixture = try Self.loadFixture()
		guard let entry = fixture.cases.first(where: { $0.name == "cubicPolynomial" }) else {
			Issue.record("cubicPolynomial dataset missing"); return
		}
		func truth(_ x: Double) -> Double {
			let cubic: Double = 2 * x * x * x
			let quadratic: Double = 5 * x * x
			let linear: Double = 3 * x
			return cubic - quadratic + linear - 1
		}

		let notAKnot = try CubicSplineInterpolator(xs: entry.xs, ys: entry.ys, boundary: .notAKnot)
		for x in entry.query {
			// Not-a-knot's whole content is that the spline is a single cubic across
			// the first two and last two intervals, so a cubic is reproduced exactly.
			#expect(abs(notAKnot(x) - truth(x)) < 1e-9,
					"not-a-knot at x=\(x): got \(notAKnot(x)), the cubic gives \(truth(x))")
		}

		let natural = try CubicSplineInterpolator(xs: entry.xs, ys: entry.ys, boundary: .natural)
		// And natural must NOT, because f''=0 at the ends is false for this cubic.
		// Asserting the failure is what proves the two conditions are distinct
		// implementations rather than one wearing two names.
		let departs = entry.query.contains { abs(natural($0) - truth($0)) > 1e-6 }
		#expect(departs,
				"a natural spline reproduced a cubic exactly — it cannot, so the boundary condition is not being applied")
	}

	@Test("PCHIP stays monotone where a spline overshoots")
	func pchipPreservesShape() throws {
		let fixture = try Self.loadFixture()
		guard let entry = fixture.cases.first(where: { $0.name == "monotoneStep" }) else {
			Issue.record("monotoneStep dataset missing"); return
		}
		let pchip = try PCHIPInterpolator(xs: entry.xs, ys: entry.ys)
		let lowest = entry.ys.min() ?? 0
		let highest = entry.ys.max() ?? 0

		var previous = -Double.infinity
		for x in entry.query {
			let value = pchip(x)
			// Monotone in, monotone out — the defining property, and the reason to
			// reach for PCHIP over a spline.
			#expect(value >= previous - 1e-9,
					"PCHIP fell from \(previous) to \(value) at x=\(x) on monotone data")
			previous = value
			#expect(value >= lowest - 1e-9 && value <= highest + 1e-9,
					"PCHIP returned \(value) at x=\(x), outside the data range [\(lowest), \(highest)]")
		}

		// The same data through a spline must overshoot. If it did not, the two
		// would be the same code and the property above would be vacuous.
		let spline = try CubicSplineInterpolator(xs: entry.xs, ys: entry.ys, boundary: .natural)
		let overshoots = entry.query.contains { spline($0) > highest + 1e-6 || spline($0) < lowest - 1e-6 }
		#expect(overshoots,
				"a natural spline did not overshoot this step, so PCHIP's shape preservation is untested")
	}

	@Test("Every scheme passes through every knot")
	func allSchemesInterpolateTheirKnots() throws {
		let fixture = try Self.loadFixture()
		for entry in fixture.cases where entry.xs.count >= 3 {
			let built: [(String, (Double) -> Double)] = [
				("linear", try { let i = try LinearInterpolator(xs: entry.xs, ys: entry.ys); return { i($0) } }()),
				("natural", try { let i = try CubicSplineInterpolator(xs: entry.xs, ys: entry.ys, boundary: .natural); return { i($0) } }()),
				("akima", try { let i = try AkimaInterpolator(xs: entry.xs, ys: entry.ys); return { i($0) } }()),
				("pchip", try { let i = try PCHIPInterpolator(xs: entry.xs, ys: entry.ys); return { i($0) } }()),
			]
			for (name, evaluate) in built {
				for (i, x) in entry.xs.enumerated() {
					let scale = Swift.max(1.0, abs(entry.ys[i]))
					// The weakest claim in the file, and the one the existing suite
					// already makes. Kept because a fixture mismatch and a missed knot
					// should report as different failures.
					#expect(abs(evaluate(x) - entry.ys[i]) < 1e-9 * scale,
							"\(entry.name)/\(name): knot \(i) at x=\(x) gives \(evaluate(x)), expected \(entry.ys[i])")
				}
			}
		}
	}
}

//
//  RiskSolverScipyParityTests.swift
//  BusinessMath
//
//  Risk Solver coverage, §3 priority 4: the distributions with a SciPy analogue.
//
//  These exist because a round-trip test cannot catch the error that actually happens.
//  A `cdf`/`quantile` pair that is self-consistent but bound to the **wrong arguments**
//  round-trips perfectly, is monotone, respects its support, and is wrong. §2.1 of the
//  coverage proposal says the parameterisation is where the errors are, and the only
//  way to see one is a second, independent implementation.
//
//  Values come from Tests/BusinessMathTests/Fixtures/riskSolverDistributions.json,
//  generated once by Scripts/reference-fixtures/generate_risk_solver.py against
//  scipy 1.17.1 and committed. CI never runs Python.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Risk Solver SciPy parity")
struct RiskSolverScipyParityTests {

	// MARK: - Fixture shape

	private struct Fixture: Decodable {
		let name: String
		let reference: String
		let note: String
		let cases: [Case]
	}

	private struct Case: Decodable {
		let psi: String
		let scipy: String
		let parameters: [String: Double]
		let mapping: String
		let quantiles: [QuantilePoint]
		let cdfProbes: [CDFProbe]
	}

	private struct QuantilePoint: Decodable {
		let p: Double
		let x: Double
		let cdfAtX: Double
	}

	private struct CDFProbe: Decodable {
		let x: Double
		let cdf: Double
	}

	private static func loadFixture() throws -> Fixture {
		guard let url = Bundle.module.url(forResource: "riskSolverDistributions",
										  withExtension: "json",
										  subdirectory: "Fixtures")
			?? Bundle.module.url(forResource: "riskSolverDistributions",
								 withExtension: "json") else {
			struct Missing: Error { let name: String }
			throw Missing(name: "riskSolverDistributions")
		}
		return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
	}

	/// Builds the BusinessMath type for a fixture case, mapping Frontline's argument
	/// names onto the initialiser.
	///
	/// Returns `nil` for a `psi` name not yet implemented, so the fixture can carry more
	/// distributions than the library does without the suite going red — the count
	/// assertion below is what stops that from hiding a regression.
	private static func distribution(for entry: Case) -> (any ContinuousDistribution<Double>)? {
		let p = entry.parameters
		switch entry.psi {
		case "PsiCauchy":
			guard let loc = p["loc"], let lambda = p["lambda"] else { return nil }
			return DistributionCauchy(location: loc, scale: lambda)
		case "PsiLaplace":
			guard let loc = p["loc"], let beta = p["beta"] else { return nil }
			return DistributionLaplace(location: loc, scale: beta)
		case "PsiLevy":
			guard let loc = p["loc"], let scale = p["scale"] else { return nil }
			return DistributionLevy(location: loc, scale: scale)
		case "PsiMaxExtreme":
			guard let m = p["m"], let s = p["s"] else { return nil }
			return DistributionMaxExtreme(location: m, scale: s)
		case "PsiMinExtreme":
			guard let m = p["m"], let s = p["s"] else { return nil }
			return DistributionMinExtreme(location: m, scale: s)
		case "PsiFrechet":
			guard let loc = p["loc"], let scale = p["scale"], let shape = p["shape"] else {
				return nil
			}
			return DistributionFrechet(location: loc, scale: scale, shape: shape)
		case "PsiLogLogistic":
			guard let gamma = p["gamma"], let beta = p["beta"], let alpha = p["alpha"] else {
				return nil
			}
			return DistributionLogLogistic(location: gamma, scale: beta, shape: alpha)
		case "PsiReciprocal":
			guard let lo = p["min"], let hi = p["max"] else { return nil }
			return DistributionReciprocal(min: lo, max: hi)
		case "PsiBurr12":
			guard let loc = p["loc"], let scale = p["scale"],
				  let s1 = p["shape1"], let s2 = p["shape2"] else { return nil }
			return DistributionBurr12(location: loc, scale: scale, shape1: s1, shape2: s2)
		case "PsiDagum":
			guard let loc = p["loc"], let scale = p["scale"],
				  let s1 = p["shape1"], let s2 = p["shape2"] else { return nil }
			return DistributionDagum(location: loc, scale: scale, shape1: s1, shape2: s2)
		case "PsiJohnsonSB":
			guard let s1 = p["shape1"], let s2 = p["shape2"],
				  let lo = p["min"], let hi = p["max"] else { return nil }
			return DistributionJohnsonSB(shape1: s1, shape2: s2, min: lo, max: hi)
		case "PsiJohnsonSU":
			guard let s1 = p["shape1"], let s2 = p["shape2"],
				  let loc = p["loc"], let scale = p["scale"] else { return nil }
			return DistributionJohnsonSU(shape1: s1, shape2: s2, location: loc, scale: scale)
		case "PsiFatigueLife":
			guard let loc = p["loc"], let scale = p["scale"], let shape = p["shape"] else {
				return nil
			}
			return DistributionFatigueLife(location: loc, scale: scale, shape: shape)
		default:
			return nil
		}
	}

	/// Distributions the fixture covers and the library implements. Asserted below so a
	/// type quietly dropping out of `distribution(for:)` cannot pass as "not covered".
	private static let implemented: Set<String> = [
		"PsiCauchy", "PsiLaplace", "PsiLevy", "PsiMaxExtreme",
		"PsiMinExtreme", "PsiFrechet", "PsiLogLogistic", "PsiReciprocal",
		"PsiBurr12", "PsiDagum", "PsiJohnsonSB", "PsiJohnsonSU", "PsiFatigueLife"
	]

	// MARK: - The fixture itself

	@Test("The fixture is present, and covers every implemented distribution")
	func fixtureIsWellFormed() throws {
		let fixture = try Self.loadFixture()
		#expect(fixture.reference.contains("scipy"), "reference was '\(fixture.reference)'")
		#expect(fixture.cases.count >= 26,
				"expected at least 26 parameterisations, got \(fixture.cases.count)")

		// Every distribution the switch handles must actually appear in the fixture. An
		// empty or truncated fixture would otherwise make every test below pass by
		// checking nothing.
		let covered = Set(fixture.cases.map(\.psi))
		#expect(Self.implemented.isSubset(of: covered),
				"not in the fixture: \(Self.implemented.subtracting(covered).sorted())")

		// And each must be exercised at more than one parameter set, so a distribution
		// that is only correct at the origin cannot pass.
		for psi in Self.implemented {
			let count = fixture.cases.filter { $0.psi == psi }.count
			#expect(count >= 2, "\(psi) has only \(count) parameterisation(s)")
		}
	}

	// MARK: - Parity

	@Test("Quantiles match SciPy, including the tails")
	func quantilesMatchSciPy() throws {
		let fixture = try Self.loadFixture()
		var checked = 0

		for entry in fixture.cases {
			guard let dist = Self.distribution(for: entry) else { continue }
			for point in entry.quantiles {
				let actual = dist.quantile(point.p)
				guard actual.isFinite, point.x.isFinite else { continue }

				// Relative comparison: these span 1e-8 to 1e8 across the tails, so an
				// absolute tolerance would be meaningless at one end or the other.
				let scale = Swift.max(abs(point.x), 1e-10)
				let relative = abs(actual - point.x) / scale
				#expect(relative < 1e-9,
						"\(entry.psi) \(entry.parameters) quantile(\(point.p)): got \(actual), scipy \(point.x), relative \(relative)")
				checked += 1
			}
		}
		#expect(checked > 100, "only \(checked) quantiles compared — the fixture may be empty")
	}

	@Test("CDFs match SciPy")
	func cdfsMatchSciPy() throws {
		let fixture = try Self.loadFixture()
		var checked = 0

		for entry in fixture.cases {
			guard let dist = Self.distribution(for: entry) else { continue }
			for probe in entry.cdfProbes {
				let actual = dist.cdf(probe.x)
				// The CDF lies in [0,1], so an absolute tolerance is the right one and
				// says the same thing at both tails.
				#expect(abs(actual - probe.cdf) < 1e-10,
						"\(entry.psi) \(entry.parameters) cdf(\(probe.x)): got \(actual), scipy \(probe.cdf)")
				checked += 1
			}
		}
		#expect(checked > 50, "only \(checked) CDF probes compared — the fixture may be empty")
	}

	@Test("The CDF at SciPy's own quantile returns SciPy's probability")
	func cdfInvertsScipyQuantile() throws {
		let fixture = try Self.loadFixture()
		var checked = 0

		for entry in fixture.cases {
			guard let dist = Self.distribution(for: entry) else { continue }
			for point in entry.quantiles where point.x.isFinite {
				// Round-tripping through *SciPy's* x rather than our own closes the loop
				// the other way: our cdf is checked against a point we did not choose.
				let back = dist.cdf(point.x)
				#expect(abs(back - point.cdfAtX) < 1e-10,
						"\(entry.psi) \(entry.parameters) cdf(\(point.x)): got \(back), scipy \(point.cdfAtX)")
				checked += 1
			}
		}
		#expect(checked > 100, "only \(checked) round trips compared")
	}

	// MARK: - The trap the work list names explicitly

	@Test("MinExtreme is not MaxExtreme negated")
	func minExtremeIsNotNegatedMaxExtreme() {
		// The work list says outright: "Distinct from PsiMaxExtreme; do not implement
		// one and negate." The two are mirror images about the origin, not about their
		// own location, so negating agrees only when the location is zero — which is
		// exactly the case a quick test would use.
		guard let atZero = DistributionMaxExtreme(location: 0, scale: 1),
			  let minAtZero = DistributionMinExtreme(location: 0, scale: 1) else {
			Issue.record("both should be valid"); return
		}
		for p in [0.1, 0.3, 0.5, 0.7, 0.9] {
			let negated = -atZero.quantile(1 - p)
			#expect(abs(minAtZero.quantile(p) - negated) < 1e-12,
					"at location zero the two should mirror; p=\(p)")
		}

		// Away from zero they must not.
		guard let maxShifted = DistributionMaxExtreme(location: 10, scale: 3),
			  let minShifted = DistributionMinExtreme(location: 10, scale: 3) else {
			Issue.record("both should be valid"); return
		}
		let naive = -maxShifted.quantile(0.5)
		let correct = minShifted.quantile(0.5)
		#expect(abs(correct - naive) > 1.0,
				"negating should be visibly wrong here: \(correct) vs \(naive)")

		// Each is skewed the way its name says: the max distribution has the longer
		// right tail, the min distribution the longer left one, measured from the median.
		let maxMedian = maxShifted.quantile(0.5)
		let maxRight = maxShifted.quantile(0.99) - maxMedian
		let maxLeft = maxMedian - maxShifted.quantile(0.01)
		#expect(maxRight > maxLeft, "MaxExtreme should be right-skewed")

		let minMedian = minShifted.quantile(0.5)
		let minRight = minShifted.quantile(0.99) - minMedian
		let minLeft = minMedian - minShifted.quantile(0.01)
		#expect(minLeft > minRight, "MinExtreme should be left-skewed")
	}

	// MARK: - Sampling

	@Test("Seeded draws follow each distribution")
	func samplingFollowsTheLaw() throws {
		let fixture = try Self.loadFixture()
		var exercised = 0

		for entry in fixture.cases {
			guard let dist = Self.distribution(for: entry) else { continue }
			var rng = DeterministicRNG(seed: 41_000 &+ UInt64(exercised))
			let n = 20_000
			var samples: [Double] = []
			samples.reserveCapacity(n)
			for _ in 0..<n { samples.append(dist.next(using: &rng)) }
			samples.sort()

			// Kolmogorov–Smirnov against the type's own CDF. These are continuous, so
			// the per-sample form is the right one here — unlike the discrete case,
			// where ties make it wrong.
			var worst = 0.0
			let count = Double(n)
			for (i, value) in samples.enumerated() {
				let f = dist.cdf(value)
				let above = Double(i + 1) / count - f
				let below = f - Double(i) / count
				worst = Swift.max(worst, Swift.max(above, below))
			}
			// 1.95/√n is the 99.9th percentile of the Kolmogorov distribution.
			let critical = 1.95 / count.squareRoot()
			#expect(worst < critical,
					"\(entry.psi)\(entry.parameters): KS \(worst) exceeded \(critical)")
			exercised += 1
		}
		#expect(exercised >= 26, "only \(exercised) distributions sampled")
	}

	// MARK: - Burr III versus Burr XII

	@Test("Dagum is Burr III and Burr12 is Burr XII, and they are not each other")
	func dagumIsNotBurr12() {
		// Both take the shapes in the same slots, so binding one to the other's formula
		// would compile, round-trip, stay monotone and respect its support. Only a
		// direct comparison catches it. Checked against scipy: burr is type III with
		// F = (1+y^-c)^-d, burr12 is type XII with F = 1-(1+y^c)^-d.
		guard let twelve = DistributionBurr12(location: 0, scale: 1, shape1: 2, shape2: 3),
			  let three = DistributionDagum(location: 0, scale: 1, shape1: 2, shape2: 3) else {
			Issue.record("both should be valid"); return
		}
		// Hand-evaluated from the two formulas at y = 1:
		//   type XII: 1 − (1 + 1)^(−3) = 1 − 1/8 = 0.875
		//   type III: (1 + 1)^(−3)     = 1/8     = 0.125
		#expect(abs(twelve.cdf(1.0) - 0.875) < 1e-12, "burr12 gave \(twelve.cdf(1.0))")
		#expect(abs(three.cdf(1.0) - 0.125) < 1e-12, "dagum gave \(three.cdf(1.0))")
		#expect(abs(twelve.cdf(1.0) - three.cdf(1.0)) > 0.5,
				"the two must not agree — that would mean one is bound to the other")
	}

	@Test("JohnsonSB takes bounds, and converts to SciPy's width itself")
	func johnsonSBTakesBounds() {
		// SciPy's support is [loc, loc + scale]. Frontline states min and max. Passing
		// `max` where `scale` belongs is right only when min is zero, so the conversion
		// lives in the initialiser and the support is asserted away from the origin.
		guard let bounded = DistributionJohnsonSB(shape1: -0.5, shape2: 1.5,
												  min: 10, max: 30) else {
			Issue.record("should be valid"); return
		}
		#expect(bounded.cdf(10.0).isEqual(to: 0.0), "no mass at or below min")
		#expect(bounded.cdf(30.0).isEqual(to: 1.0), "all mass at or below max")
		#expect(bounded.cdf(9.0).isEqual(to: 0.0))
		#expect(bounded.cdf(31.0).isEqual(to: 1.0))

		var rng = DeterministicRNG(seed: 42_100)
		for _ in 0..<5_000 {
			let x = bounded.next(using: &rng)
			#expect(x >= 10 && x <= 30, "drew \(x), outside [10, 30]")
		}
	}

	// MARK: - Invalid parameters

	@Test("Invalid parameters are refused at construction")
	func invalidParametersRejected() {
		#expect(DistributionCauchy(location: 0, scale: 0) == nil)
		#expect(DistributionCauchy(location: 0, scale: -1) == nil)
		#expect(DistributionLaplace(location: 0, scale: 0) == nil)
		#expect(DistributionLevy(location: 0, scale: -1) == nil)
		#expect(DistributionMaxExtreme(location: 0, scale: 0) == nil)
		#expect(DistributionMinExtreme(location: 0, scale: 0) == nil)
		#expect(DistributionFrechet(location: 0, scale: 1, shape: 0) == nil)
		#expect(DistributionFrechet(location: 0, scale: 0, shape: 1) == nil)
		#expect(DistributionLogLogistic(location: 0, scale: 1, shape: 0) == nil)
		#expect(DistributionLogLogistic(location: 0, scale: 0, shape: 1) == nil)

		// A log-uniform cannot reach zero: its density goes as 1/x, so the mass near
		// zero diverges and there is no distribution to return.
		#expect(DistributionReciprocal(min: 0, max: 10) == nil,
				"a lower bound of zero has no log-uniform")
		#expect(DistributionReciprocal(min: -1, max: 10) == nil)
		#expect(DistributionReciprocal(min: 10, max: 1) == nil, "bounds must be ordered")
		#expect(DistributionReciprocal(min: 5, max: 5) == nil, "an empty support")

		#expect(DistributionBurr12(location: 0, scale: 1, shape1: 0, shape2: 1) == nil)
		#expect(DistributionBurr12(location: 0, scale: 0, shape1: 1, shape2: 1) == nil)
		#expect(DistributionDagum(location: 0, scale: 1, shape1: 1, shape2: -1) == nil)
		#expect(DistributionJohnsonSB(shape1: 1, shape2: 0, min: 0, max: 1) == nil)
		#expect(DistributionJohnsonSB(shape1: 1, shape2: 1, min: 5, max: 5) == nil,
				"an empty support")
		#expect(DistributionJohnsonSU(shape1: 1, shape2: 0, location: 0, scale: 1) == nil)
		#expect(DistributionJohnsonSU(shape1: 1, shape2: 1, location: 0, scale: 0) == nil)
		#expect(DistributionFatigueLife(location: 0, scale: 1, shape: 0) == nil)
		#expect(DistributionFatigueLife(location: 0, scale: -1, shape: 1) == nil)
	}

	@Test("Supports are respected")
	func supportsRespected() {
		// The three one-sided distributions have no mass at or below their location.
		guard let frechet = DistributionFrechet(location: 1, scale: 2, shape: 3),
			  let levy = DistributionLevy(location: 1, scale: 2),
			  let fisk = DistributionLogLogistic(location: 1, scale: 2, shape: 3),
			  let logUniform = DistributionReciprocal(min: 1, max: 100) else {
			Issue.record("all should be valid"); return
		}
		#expect(frechet.cdf(1.0).isEqual(to: 0.0))
		#expect(frechet.cdf(0.5).isEqual(to: 0.0))
		#expect(levy.cdf(1.0).isEqual(to: 0.0))
		#expect(fisk.cdf(1.0).isEqual(to: 0.0))
		#expect(logUniform.cdf(1.0).isEqual(to: 0.0))
		#expect(logUniform.cdf(100.0).isEqual(to: 1.0))

		var rng = DeterministicRNG(seed: 41_500)
		for _ in 0..<2_000 {
			#expect(frechet.next(using: &rng) > 1.0)
			#expect(levy.next(using: &rng) > 1.0)
			#expect(fisk.next(using: &rng) > 1.0)
			let u = logUniform.next(using: &rng)
			#expect(u >= 1.0 && u <= 100.0, "log-uniform drew \(u)")
		}
	}
}

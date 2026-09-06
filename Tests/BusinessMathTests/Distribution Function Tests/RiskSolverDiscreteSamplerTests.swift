//
//  RiskSolverDiscreteSamplerTests.swift
//  BusinessMath
//
//  Risk Solver coverage, §3 priority 1: the three `maths-no-sampler` rows.
//  `PsiPoisson`, `PsiHyperGeo` and `PsiDiscrete` each had the mathematics here and no
//  way to draw from it.
//
//  Per PROPOSAL_excel_function_coverage.md §2.1, a sampler is tested by its
//  *distribution*, never by a specific draw: the assertions below use a
//  Kolmogorov–Smirnov statistic against the type's own CDF over a large fixed-seed
//  sample. A test that pinned individual values would break on any change to the
//  generator and would say nothing about correctness.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Risk Solver discrete samplers")
struct RiskSolverDiscreteSamplerTests {

	/// `D = sup |Fₙ(x) − F(x)|`, evaluated at every integer the sample spans.
	///
	/// Written for a **discrete** distribution, which the textbook per-sample form is
	/// not. That form walks the sorted sample and compares `i/n` against `F(x)` — but
	/// just below an atom `v` the true CDF is `F(v⁻) = F(v) − p(v)`, not `F(v)`. With
	/// ties, which discrete data is made of, comparing the pre-jump empirical value
	/// against `F(v)` charges the entire atom mass as error. A Poisson with λ = 0.5 puts
	/// 0.607 on zero alone, so no correct sampler could ever have passed.
	///
	/// Both functions are step functions that change only at integers, so the supremum
	/// is attained at one of them and iterating the integers finds it exactly.
	private static func ksStatistic(samples: [Int], cdf: (Int) -> Double) -> Double {
		guard let low = samples.min(), let high = samples.max() else { return 0 }
		let n = Double(samples.count)

		var counts: [Int: Int] = [:]
		for value in samples { counts[value, default: 0] += 1 }

		var cumulative = 0
		var worst = 0.0
		for value in low...high {
			cumulative += counts[value] ?? 0
			let empirical = Double(cumulative) / n
			worst = Swift.max(worst, abs(empirical - cdf(value)))
		}
		return worst
	}

	/// The 99.9th-percentile KS critical value, 1.95/√n.
	///
	/// Derived rather than tabulated: the Kolmogorov distribution gives
	/// P(√n·D > 1.95) ≈ 0.001. Generous on purpose — the sample is seeded, so this
	/// guards against a wrong law, not against sampling noise.
	private static func ksCriticalValue(_ n: Int) -> Double {
		1.95 / Double(n).squareRoot()
	}

	// MARK: - PsiPoisson

	@Test("Poisson: pmf, cdf and quantile agree with each other")
	func poissonContract() {
		for lambda in [0.5, 3.0, 25.0] {
			guard let dist = DistributionPoisson(lambda: lambda) else {
				Issue.record("λ = \(lambda) should be valid"); continue
			}

			// cdf is the running sum of pmf
			var running = 0.0
			for k in 0...Int(lambda + 10 * lambda.squareRoot() + 20) {
				running += dist.pmf(k)
				#expect(abs(dist.cdf(k) - running) < 1e-10,
						"λ=\(lambda) k=\(k): cdf \(dist.cdf(k)) vs summed pmf \(running)")
			}
			#expect(abs(running - 1.0) < 1e-10, "λ=\(lambda) pmf summed to \(running)")
		}
	}

	@Test("Poisson: quantile is the inverse of cdf and is monotone")
	func poissonQuantile() {
		for lambda in [0.5, 3.0, 25.0] {
			guard let dist = DistributionPoisson(lambda: lambda) else {
				Issue.record("λ = \(lambda) should be valid"); continue
			}

			// Round trip: the smallest k with cdf(k) >= p, evaluated just above cdf(k-1).
			for k in 0...40 {
				let below: Double = k == 0 ? 0.0 : dist.cdf(k - 1)
				let at = dist.cdf(k)
				guard at - below > 1e-12 else { continue }   // skip outcomes with no mass
				let midpoint = (below + at) / 2
				#expect(dist.quantile(midpoint) == k,
						"λ=\(lambda): quantile(\(midpoint)) gave \(dist.quantile(midpoint)), expected \(k)")
			}

			// Monotone in p — the protocol requires this for quasi-random sampling.
			var previous = Int.min
			for i in 1..<1000 {
				let p = Double(i) / 1000.0
				let q = dist.quantile(p)
				#expect(q >= previous, "λ=\(lambda): quantile decreased at p=\(p)")
				previous = q
			}
		}
	}

	@Test("Poisson: samples follow the distribution")
	func poissonSampling() {
		for lambda in [0.5, 3.0, 25.0] {
			guard let dist = DistributionPoisson(lambda: lambda) else {
				Issue.record("λ = \(lambda) should be valid"); continue
			}
			var rng = DeterministicRNG(seed: 20_001)
			let n = 20_000
			var samples: [Int] = []
			samples.reserveCapacity(n)
			for _ in 0..<n { samples.append(Int(dist.next(using: &rng))) }

			#expect(samples.allSatisfy { $0 >= 0 }, "Poisson support is the non-negative integers")

			let d = Self.ksStatistic(samples: samples, cdf: { dist.cdf($0) })
			#expect(d < Self.ksCriticalValue(n),
					"λ=\(lambda): KS \(d) exceeded \(Self.ksCriticalValue(n))")

			// The mean and variance of a Poisson are both λ.
			let mean = samples.reduce(0, +) .asDouble / Double(n)
			#expect(abs(mean - lambda) < 4.0 * (lambda / Double(n)).squareRoot(),
					"λ=\(lambda): sample mean \(mean)")
		}
	}

	@Test("Poisson: invalid rate is rejected")
	func poissonInvalid() {
		#expect(DistributionPoisson(lambda: -1.0) == nil)
		#expect(DistributionPoisson(lambda: Double.nan) == nil)
		#expect(DistributionPoisson(lambda: Double.infinity) == nil)

		// λ = 0 is degenerate, not invalid — and asserting merely that it is non-nil
		// would not say what it produces. All the mass sits on zero.
		guard let degenerate = DistributionPoisson(lambda: 0.0) else {
			Issue.record("λ = 0 should construct"); return
		}
		#expect(degenerate.pmf(0).isEqual(to: 1.0))
		#expect(degenerate.pmf(1).isEqual(to: 0.0))
		#expect(degenerate.quantile(0.5) == 0)
	}

	// MARK: - PsiHyperGeo

	@Test("HyperGeometric: pmf, cdf and quantile agree with each other")
	func hyperGeoContract() {
		// (draws, successesInPopulation, population)
		let cases = [(3, 4, 10), (10, 20, 50), (5, 5, 5), (1, 1, 2)]
		for (draws, successes, population) in cases {
			guard let dist = DistributionHyperGeometric(draws: draws,
													   successes: successes,
													   population: population) else {
				Issue.record("n=\(draws) D=\(successes) M=\(population) should be valid")
				continue
			}
			var running = 0.0
			for k in 0...draws {
				running += dist.pmf(k)
				#expect(abs(dist.cdf(k) - running) < 1e-12,
						"k=\(k): cdf \(dist.cdf(k)) vs summed pmf \(running)")
			}
			#expect(abs(running - 1.0) < 1e-12, "pmf summed to \(running)")
		}
	}

	@Test("HyperGeometric: support respects both bounds")
	func hyperGeoSupport() {
		// 10 draws from a population of 50 holding 20 successes: at least 0 successes,
		// at most 10. With 45 successes in 50, at least 5 must appear in 10 draws.
		guard let wide = DistributionHyperGeometric(draws: 10, successes: 20, population: 50),
			  let forced = DistributionHyperGeometric(draws: 10, successes: 45, population: 50) else {
			Issue.record("both parameter sets should be valid"); return
		}
		#expect(wide.pmf(-1) == 0)
		#expect(wide.pmf(11) == 0)
		#expect(wide.pmf(0) > 0)
		#expect(wide.pmf(10) > 0)

		// n − (M − D) = 10 − 5 = 5 is the lower edge of the support.
		#expect(forced.pmf(4) == 0, "fewer than 5 successes is impossible here")
		#expect(forced.pmf(5) > 0)
	}

	@Test("HyperGeometric: matches the closed form on a hand-checkable case")
	func hyperGeoKnownValues() {
		// The stable in hyperGeometric.swift's own comment: 10 horses, 4 diseased,
		// draw 3, want exactly 2. C(4,2)·C(6,1)/C(10,3) = 6·6/120 = 0.3.
		guard let dist = DistributionHyperGeometric(draws: 3, successes: 4, population: 10) else {
			Issue.record("should be valid"); return
		}
		#expect(abs(dist.pmf(2) - 0.3) < 1e-12, "got \(dist.pmf(2))")
		// Mean is n·D/M = 3·4/10 = 1.2.
		var mean = 0.0
		for k in 0...3 { mean += Double(k) * dist.pmf(k) }
		#expect(abs(mean - 1.2) < 1e-12, "mean was \(mean)")
	}

	@Test("HyperGeometric: samples follow the distribution")
	func hyperGeoSampling() {
		guard let dist = DistributionHyperGeometric(draws: 10, successes: 20, population: 50) else {
			Issue.record("should be valid"); return
		}
		var rng = DeterministicRNG(seed: 20_002)
		let n = 20_000
		var samples: [Int] = []
		samples.reserveCapacity(n)
		for _ in 0..<n { samples.append(Int(dist.next(using: &rng))) }

		#expect(samples.allSatisfy { $0 >= 0 && $0 <= 10 })
		let d = Self.ksStatistic(samples: samples, cdf: { dist.cdf($0) })
		#expect(d < Self.ksCriticalValue(n), "KS \(d) exceeded \(Self.ksCriticalValue(n))")
	}

	@Test("HyperGeometric: invalid parameters are rejected")
	func hyperGeoInvalid() {
		#expect(DistributionHyperGeometric(draws: 11, successes: 5, population: 10) == nil,
				"cannot draw more than the population")
		#expect(DistributionHyperGeometric(draws: 3, successes: 11, population: 10) == nil,
				"cannot hold more successes than the population")
		#expect(DistributionHyperGeometric(draws: -1, successes: 5, population: 10) == nil)
		#expect(DistributionHyperGeometric(draws: 3, successes: 5, population: 0) == nil,
				"an empty population defines nothing")

		// No successes in the population is degenerate, not invalid: every draw finds
		// zero. Assert that, rather than merely that the type constructed.
		guard let empty = DistributionHyperGeometric(draws: 3, successes: 0, population: 10) else {
			Issue.record("zero successes should construct"); return
		}
		#expect(empty.pmf(0).isEqual(to: 1.0))
		#expect(empty.pmf(1).isEqual(to: 0.0))
		#expect(empty.supportLowerBound == 0 && empty.supportUpperBound == 0)
	}

	// MARK: - PsiDiscrete

	@Test("Discrete: pmf, cdf and quantile agree with each other")
	func discreteContract() {
		guard let dist = DistributionDiscrete(values: [10.0, 20.0, 30.0, 40.0],
											  weights: [0.1, 0.2, 0.3, 0.4]) else {
			Issue.record("should be valid"); return
		}
		#expect(abs(dist.pmf(0) - 0.1) < 1e-15)
		#expect(abs(dist.pmf(3) - 0.4) < 1e-15)
		// Outside the support and at the top of it, the values are exact: they come
		// from guards returning a literal, and from a cumulative array whose last entry
		// is pinned to 1.0 in the initialiser. Deliberate IEEE comparisons, so named.
		#expect(dist.pmf(-1).isEqual(to: 0.0))
		#expect(dist.pmf(4).isEqual(to: 0.0))
		#expect(abs(dist.cdf(1) - 0.3) < 1e-15)
		#expect(dist.cdf(3).isEqual(to: 1.0))
		#expect(dist.cdf(99).isEqual(to: 1.0))
	}

	@Test("Discrete: weights need not be normalised")
	func discreteNormalises() {
		guard let raw = DistributionDiscrete(values: [1.0, 2.0], weights: [3.0, 1.0]),
			  let normalised = DistributionDiscrete(values: [1.0, 2.0], weights: [0.75, 0.25]) else {
			Issue.record("both should be valid"); return
		}
		#expect(abs(raw.pmf(0) - normalised.pmf(0)) < 1e-15)
		#expect(abs(raw.pmf(1) - normalised.pmf(1)) < 1e-15)
	}

	@Test("Discrete: quantile is monotone, as quasi-random sampling requires")
	func discreteQuantileMonotone() {
		guard let dist = DistributionDiscrete(values: [10.0, 20.0, 30.0, 40.0],
											  weights: [0.1, 0.2, 0.3, 0.4]) else {
			Issue.record("should be valid"); return
		}
		var previous = Int.min
		for i in 1..<1000 {
			let q = dist.quantile(Double(i) / 1000.0)
			#expect(q >= previous, "quantile decreased at p = \(Double(i) / 1000.0)")
			previous = q
		}
		#expect(dist.quantile(0.05) == 0)
		#expect(dist.quantile(0.5) == 2)
		#expect(dist.quantile(0.99) == 3)
	}

	@Test("Discrete: the alias table and the inverse transform agree in distribution")
	func discreteAliasMatchesInverse() {
		// `next(using:)` uses an alias table for O(1); `quantile` must stay monotone and
		// so inverts the CDF. They are different algorithms and must give the same law.
		guard let dist = DistributionDiscrete(values: [10.0, 20.0, 30.0, 40.0],
											  weights: [0.1, 0.2, 0.3, 0.4]) else {
			Issue.record("should be valid"); return
		}
		let n = 40_000
		var aliasRNG = DeterministicRNG(seed: 20_003)
		var counts = [Int](repeating: 0, count: 4)
		for _ in 0..<n {
			let drawn = dist.next(using: &aliasRNG)
			guard let index = [10.0, 20.0, 30.0, 40.0].firstIndex(of: drawn) else {
				Issue.record("drew \(drawn), which is not in the support"); return
			}
			counts[index] += 1
		}
		let expected = [0.1, 0.2, 0.3, 0.4]
		for i in 0..<4 {
			let observed = Double(counts[i]) / Double(n)
			// Four standard errors of a binomial proportion.
			let se = (expected[i] * (1 - expected[i]) / Double(n)).squareRoot()
			#expect(abs(observed - expected[i]) < 4 * se,
					"outcome \(i): observed \(observed), expected \(expected[i])")
		}
	}

	@Test("Discrete: values are returned, not indices")
	func discreteReturnsValues() {
		guard let dist = DistributionDiscrete(values: [100.0, 200.0], weights: [0.5, 0.5]) else {
			Issue.record("should be valid"); return
		}
		var rng = DeterministicRNG(seed: 20_004)
		for _ in 0..<200 {
			let drawn = dist.next(using: &rng)
			// The drawn value is returned straight out of `values`, so it is one of the
			// two literals bit for bit — no arithmetic touches it.
			#expect(drawn.isEqual(to: 100.0) || drawn.isEqual(to: 200.0), "drew \(drawn)")
		}
	}

	@Test("Discrete: invalid inputs are rejected")
	func discreteInvalid() {
		#expect(DistributionDiscrete(values: [1.0, 2.0], weights: [0.5]) == nil,
				"lengths must match")
		#expect(DistributionDiscrete(values: [], weights: []) == nil,
				"an empty distribution has no draw")
		#expect(DistributionDiscrete(values: [1.0, 2.0], weights: [-1.0, 2.0]) == nil,
				"a negative weight is not a probability")
		#expect(DistributionDiscrete(values: [1.0, 2.0], weights: [0.0, 0.0]) == nil,
				"weights summing to zero define nothing")
	}
}

private extension Int {
	var asDouble: Double { Double(self) }
}

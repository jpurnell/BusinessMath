//
//  DistributionProtocolTests.swift
//  BusinessMathTests
//
//  The contract itself, tested through synthetic conformers rather than through any
//  real distribution — so a failure here means the protocol machinery is wrong, not
//  that some distribution's mathematics is.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Distribution contract")
struct DistributionProtocolTests {

	// MARK: - Synthetic conformers

	/// Exponential(λ), stated only as a CDF and a quantile.
	///
	/// It implements neither `next()` nor `next(using:)`. If the protocol's default
	/// is missing or wrong, this type stops compiling or stops sampling correctly,
	/// and no real distribution has to be disturbed to find out.
	struct MinimalExponential: ContinuousDistribution {
		typealias T = Double
		let rate: Double

		func cdf(_ x: Double) -> Double {
			x <= 0 ? 0 : 1 - Double.exp(-rate * x)
		}

		func quantile(_ p: Double) -> Double {
			-Double.log(1 - p) / rate
		}
	}

	/// A three-outcome pmf, stated only as a pmf and a cdf.
	struct MinimalDiscrete: DiscreteDistribution {
		typealias T = Double
		// P(0) = 0.2, P(1) = 0.5, P(2) = 0.3
		private let masses: [Double] = [0.2, 0.5, 0.3]

		func pmf(_ k: Int) -> Double {
			guard k >= 0, k < masses.count else { return 0 }
			return masses[k]
		}

		func cdf(_ k: Int) -> Double {
			guard k >= 0 else { return 0 }
			guard k < masses.count else { return 1 }
			return masses[0...k].reduce(0, +)
		}

		func quantile(_ p: Double) -> Int {
			var cumulative = 0.0
			for (index, mass) in masses.enumerated() {
				cumulative += mass
				if p <= cumulative { return index }
			}
			return masses.count - 1
		}
	}

	// MARK: - The uniform the default sampler draws

	@Test("openUnitRandom never returns an endpoint")
	func openUnitRandomExcludesEndpoints() {
		var generator = Xoshiro256StarStar(seed: 99)
		var smallest = Double.infinity
		var largest = -Double.infinity

		for _ in 0..<200_000 {
			let u = Double.openUnitRandom(using: &generator)
			#expect(u > 0, "openUnitRandom returned \(u); quantile(0) is −∞ for most distributions")
			#expect(u < 1, "openUnitRandom returned \(u); quantile(1) is +∞ for most distributions")
			smallest = Swift.min(smallest, u)
			largest = Swift.max(largest, u)
		}

		// The construction is (k + ½)/2⁵³ for a 53-bit k, so the reachable range is
		// [2⁻⁵⁴, 1 − 2⁻⁵⁴] and the extremes are symmetric about ½.
		#expect(smallest >= 0x1p-54)
		#expect(largest <= 1 - 0x1p-54)
	}

	@Test("openUnitRandom is uniform and consumes exactly one word per draw")
	func openUnitRandomIsUniform() {
		var generator = Xoshiro256StarStar(seed: 5)
		var buckets = [Int](repeating: 0, count: 10)
		let draws = 100_000
		for _ in 0..<draws {
			let u = Double.openUnitRandom(using: &generator)
			buckets[Swift.min(9, Int(u * 10))] += 1
		}
		// ±4σ on a multinomial cell: σ = sqrt(n·p·(1−p)) ≈ 95 for n = 100k, p = 0.1.
		for (index, count) in buckets.enumerated() {
			#expect(abs(count - draws / 10) < 400, "bucket \(index) held \(count)")
		}

		// One 64-bit word per draw. QMC hands a distribution exactly one coordinate,
		// so a sampler that consumed two would silently desynchronise the point set.
		var counting = Xoshiro256StarStar(seed: 5)
		_ = Double.openUnitRandom(using: &counting)
		var reference = Xoshiro256StarStar(seed: 5)
		_ = reference.next()
		#expect(counting.next() == reference.next())
	}

	// MARK: - The default sampler

	@Test("A ContinuousDistribution gets inverse-transform sampling for free")
	func continuousDefaultSampler() {
		let distribution = MinimalExponential(rate: 2.0)

		// The default must be exactly quantile(openUnitRandom), not merely
		// distributed like it: the same generator state gives the same draw.
		var sampling = Xoshiro256StarStar(seed: 3)
		var manual = Xoshiro256StarStar(seed: 3)
		for _ in 0..<25 {
			let drawn = distribution.next(using: &sampling)
			let expected = distribution.quantile(Double.openUnitRandom(using: &manual))
			#expect(drawn == expected)
		}
	}

	@Test("The default sampler reproduces the distribution it was given")
	func continuousDefaultSamplerIsCorrectlyDistributed() {
		let distribution = MinimalExponential(rate: 2.0)
		let statistic = kolmogorovSmirnovStatistic(distribution, seed: 11, count: 20_000)
		// 1% two-sided asymptotic critical value: 1.63/√n.
		let critical = 1.63 / Double(20_000).squareRoot()
		#expect(statistic < critical, "KS statistic \(statistic) against critical \(critical)")
	}

	@Test("A DiscreteDistribution samples its pmf")
	func discreteDefaultSampler() {
		let distribution = MinimalDiscrete()
		var generator = Xoshiro256StarStar(seed: 17)
		var counts = [0, 0, 0]
		let draws = 60_000

		for _ in 0..<draws {
			let value = distribution.next(using: &generator)
			#expect(value == value.rounded(), "a discrete draw must be integral, got \(value)")
			let index = Int(value)
			#expect(index >= 0 && index < 3)
			counts[index] += 1
		}

		for k in 0..<3 {
			let observed = Double(counts[k]) / Double(draws)
			#expect(abs(observed - distribution.pmf(k)) < 0.01,
				"outcome \(k) came up \(observed), pmf says \(distribution.pmf(k))")
		}
	}

	@Test("A conformer is usable everywhere a SeedableDistribution is")
	func conformsToTheExistingProtocols() throws {
		let distribution = MinimalExponential(rate: 1.5)
		let input = SimulationInput(name: "lifetime", distribution: distribution)
		#expect(input.supportsSeeding,
			"ContinuousDistribution refines SeedableDistribution, so a seeded run must accept it")

		var simulation = MonteCarloSimulation(iterations: 500, enableGPU: false, seed: 2026) { $0[0] }
		simulation.addInput(input)
		let first = try simulation.run()
		let second = try simulation.run()
		#expect(first.values == second.values)
	}
}

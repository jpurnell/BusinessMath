//
//  SeededDriverSamplingTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-08-11.
//

import Foundation
import Numerics
import TestSupport  // Cross-platform math functions
import Testing
@testable import BusinessMath

/// A distribution that cannot honor a seed.
///
/// Deliberately conforms to `DistributionRandom` only — never `SeedableDistribution` — so a
/// driver built from it must report `supportsSeeding == false` and throw rather than quietly
/// returning a draw the caller's generator did not produce.
///
/// Its value is fixed rather than random on purpose. What these tests exercise is the
/// *absence of conformance*, not randomness, and a fixed value keeps the tests deterministic
/// while still being a source no generator controls.
private struct UnseedableDistribution: DistributionRandom, Sendable {
	static let value = 0.375

	func next() -> Double {
		Self.value
	}
}

/// Whether two sample streams are bit-identical.
///
/// Reproducibility is a bit-identity claim, so it is stated as one: `==` reports NaN as
/// unequal to itself and `+0.0` as equal to `-0.0`, either of which would let a stream that
/// is not actually reproducible pass or fail for the wrong reason.
private func isBitIdentical(_ lhs: [Double], _ rhs: [Double]) -> Bool {
	lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.bitPattern == $1.bitPattern }
}

@Suite("Seeded Driver Sampling")
struct SeededDriverSamplingTests {

	private let q1 = Period.quarter(year: 2025, quarter: 1)
	private let q2 = Period.quarter(year: 2025, quarter: 2)

	// MARK: - ProbabilisticDriver

	@Test("Same seed reproduces the same sequence")
	func sameSeedReproducesSequence() throws {
		let driver = ProbabilisticDriver<Double>.normal(name: "Growth", mean: 0.10, stdDev: 0.05)

		var a = Xoshiro256StarStar(seed: 20_260_811)
		var b = Xoshiro256StarStar(seed: 20_260_811)

		var first: [Double] = []
		var second: [Double] = []
		for _ in 0..<256 {
			first.append(try driver.sample(for: q1, using: &a))
			second.append(try driver.sample(for: q1, using: &b))
		}

		#expect(isBitIdentical(first, second))
		// A stream of 256 identical draws would satisfy bit-identity without being a stream.
		#expect(Set(first.map(\.bitPattern)).count > 200)
	}

	@Test("A different seed produces a different sequence")
	func differentSeedDiffers() throws {
		let driver = ProbabilisticDriver<Double>.normal(name: "Growth", mean: 0.10, stdDev: 0.05)

		var a = Xoshiro256StarStar(seed: 20_260_811)
		var b = Xoshiro256StarStar(seed: 20_260_812)

		var first: [Double] = []
		var second: [Double] = []
		for _ in 0..<64 {
			first.append(try driver.sample(for: q1, using: &a))
			second.append(try driver.sample(for: q1, using: &b))
		}

		#expect(!isBitIdentical(first, second))
	}

	@Test("Seeded draws follow the same law as unseeded draws")
	func seededDrawsFollowTheDistribution() throws {
		let driver = ProbabilisticDriver<Double>.normal(name: "Growth", mean: 0.10, stdDev: 0.05)

		var generator = Xoshiro256StarStar(seed: 7)
		var samples: [Double] = []
		for _ in 0..<20_000 {
			samples.append(try driver.sample(for: q1, using: &generator))
		}

		let mean = samples.reduce(0, +) / Double(samples.count)
		let variance = samples.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(samples.count)
		#expect(abs(mean - 0.10) < 0.005)
		#expect(abs(variance.squareRoot() - 0.05) < 0.005)
	}

	@Test("Unseeded sampling is unchanged")
	func unseededSamplingUnchanged() {
		let driver = ProbabilisticDriver<Double>.normal(name: "Growth", mean: 0.10, stdDev: 0.05)

		let samples = (0..<200).map { _ in driver.sample(for: q1) }
		#expect(Set(samples.map(\.bitPattern)).count > 150)

		let mean = samples.reduce(0, +) / Double(samples.count)
		#expect(abs(mean - 0.10) < 0.05)
	}

	@Test("Convenience initializers support seeding")
	func convenienceInitializersSupportSeeding() throws {
		let normal = ProbabilisticDriver<Double>.normal(name: "N", mean: 100.0, stdDev: 10.0)
		let triangular = ProbabilisticDriver<Double>.triangular(name: "T", low: 95.0, high: 105.0, base: 100.0)
		let uniform = ProbabilisticDriver<Double>.uniform(name: "U", min: 45.0, max: 55.0)

		#expect(normal.supportsSeeding)
		#expect(triangular.supportsSeeding)
		#expect(uniform.supportsSeeding)

		for driver in [normal, triangular, uniform] {
			var a = Xoshiro256StarStar(seed: 99)
			var b = Xoshiro256StarStar(seed: 99)
			let first = try (0..<32).map { _ in try driver.sample(for: q1, using: &a) }
			let second = try (0..<32).map { _ in try driver.sample(for: q1, using: &b) }
			#expect(isBitIdentical(first, second), "\(driver.name) did not reproduce")
		}
	}

	@Test("A driver over a non-seedable distribution throws rather than losing determinism")
	func nonSeedableDistributionThrows() {
		let driver = ProbabilisticDriver<Double>(name: "Opaque", distribution: UnseedableDistribution())

		#expect(!driver.supportsSeeding)

		var generator = Xoshiro256StarStar(seed: 1)
		#expect(throws: SimulationError.self) {
			_ = try driver.sample(for: q1, using: &generator)
		}

		// The unseeded path still works.
		#expect(driver.sample(for: q1).bitPattern == UnseedableDistribution.value.bitPattern)
	}

	// MARK: - DeterministicDriver

	@Test("DeterministicDriver seeds without consuming generator state")
	func deterministicDriverConsumesNothing() throws {
		let fixed = DeterministicDriver(name: "Rent", value: 10_000.0)
		#expect(fixed.supportsSeeding)

		var generator = Xoshiro256StarStar(seed: 5)
		var reference = Xoshiro256StarStar(seed: 5)

		let sampled = try fixed.sample(for: q1, using: &generator)
		#expect(sampled.bitPattern == 10_000.0.bitPattern)
		// The generator is untouched, so a deterministic operand does not shift the stream
		// its probabilistic siblings draw from.
		#expect(generator.next() == reference.next())
	}

	// MARK: - Type Erasure

	@Test("AnyDriver carries the seeded path through erasure")
	func anyDriverPropagatesSeeding() throws {
		let seedable = AnyDriver(ProbabilisticDriver<Double>.normal(name: "N", mean: 1.0, stdDev: 0.2))
		#expect(seedable.supportsSeeding)

		var a = Xoshiro256StarStar(seed: 11)
		var b = Xoshiro256StarStar(seed: 11)
		let first = try (0..<32).map { _ in try seedable.sample(for: q1, using: &a) }
		let second = try (0..<32).map { _ in try seedable.sample(for: q1, using: &b) }
		#expect(isBitIdentical(first, second))

		let opaque = AnyDriver(ProbabilisticDriver<Double>(name: "Opaque", distribution: UnseedableDistribution()))
		#expect(!opaque.supportsSeeding)
		var generator = Xoshiro256StarStar(seed: 1)
		#expect(throws: SimulationError.self) {
			_ = try opaque.sample(for: q1, using: &generator)
		}
	}

	// MARK: - Composites

	@Test("SumDriver and ProductDriver reproduce under a seed")
	func compositesReproduce() throws {
		let quantity = ProbabilisticDriver<Double>.normal(name: "Quantity", mean: 1_000.0, stdDev: 100.0)
		let price = ProbabilisticDriver<Double>.triangular(name: "Price", low: 95.0, high: 105.0, base: 100.0)

		let revenue = ProductDriver(name: "Revenue", lhs: quantity, rhs: price)
		let total = SumDriver(name: "Total", lhs: quantity, rhs: price)

		#expect(revenue.supportsSeeding)
		#expect(total.supportsSeeding)

		for driver in [AnyDriver(revenue), AnyDriver(total)] {
			var a = Xoshiro256StarStar(seed: 2_026)
			var b = Xoshiro256StarStar(seed: 2_026)
			var c = Xoshiro256StarStar(seed: 2_027)
			let first = try (0..<64).map { _ in try driver.sample(for: q1, using: &a) }
			let second = try (0..<64).map { _ in try driver.sample(for: q1, using: &b) }
			let other = try (0..<64).map { _ in try driver.sample(for: q1, using: &c) }
			#expect(isBitIdentical(first, second), "\(driver.name) did not reproduce")
			#expect(!isBitIdentical(first, other), "\(driver.name) ignored the seed")
		}
	}

	@Test("A composite mixing a deterministic and a probabilistic operand reproduces")
	func mixedCompositeReproduces() throws {
		let fixedCost = DeterministicDriver(name: "Fixed", value: 10_000.0)
		let variableCost = ProbabilisticDriver<Double>.normal(name: "Variable", mean: 50_000.0, stdDev: 5_000.0)
		let total = SumDriver(name: "Total Cost", lhs: fixedCost, rhs: variableCost)

		#expect(total.supportsSeeding)

		var a = Xoshiro256StarStar(seed: 17)
		var b = Xoshiro256StarStar(seed: 17)
		let first = try (0..<32).map { _ in try total.sample(for: q1, using: &a) }
		let second = try (0..<32).map { _ in try total.sample(for: q1, using: &b) }
		#expect(isBitIdentical(first, second))
	}

	@Test("A composite over an unseedable leaf throws and names the leaf")
	func compositeOverUnseedableLeafThrows() {
		let good = ProbabilisticDriver<Double>.normal(name: "Good", mean: 1.0, stdDev: 0.1)
		let bad = ProbabilisticDriver<Double>(name: "Bad Leaf", distribution: UnseedableDistribution())
		let sum = SumDriver(name: "Sum", lhs: good, rhs: bad)

		#expect(!sum.supportsSeeding)

		var generator = Xoshiro256StarStar(seed: 1)
		do {
			_ = try sum.sample(for: q1, using: &generator)
			Issue.record("Expected seedingUnsupported")
		} catch let error as SimulationError {
			guard case .seedingUnsupported(let inputName, _) = error else {
				Issue.record("Expected seedingUnsupported, got \(error)")
				return
			}
			#expect(inputName == "Bad Leaf")
		} catch {
			Issue.record("Unexpected error \(error)")
		}
	}

	@Test("The subtraction operator preserves the seeded path")
	func subtractionPreservesSeeding() throws {
		let revenue = ProbabilisticDriver<Double>.normal(name: "Revenue", mean: 100_000.0, stdDev: 10_000.0)
		let cost = ProbabilisticDriver<Double>.normal(name: "Cost", mean: 70_000.0, stdDev: 7_000.0)
		let profit = revenue - cost

		#expect(profit.supportsSeeding)

		var a = Xoshiro256StarStar(seed: 42)
		var b = Xoshiro256StarStar(seed: 42)
		let first = try (0..<32).map { _ in try profit.sample(for: q1, using: &a) }
		let second = try (0..<32).map { _ in try profit.sample(for: q1, using: &b) }
		#expect(isBitIdentical(first, second))
	}

	@Test("ConstrainedDriver propagates seeding through the constraint")
	func constrainedDriverPropagatesSeeding() throws {
		let base = ProbabilisticDriver<Double>.normal(name: "Growth", mean: 0.0, stdDev: 1.0)
		let clamped = base.clamped(min: -0.5, max: 0.5)

		#expect(clamped.supportsSeeding)

		var a = Xoshiro256StarStar(seed: 8)
		var b = Xoshiro256StarStar(seed: 8)
		let first = try (0..<128).map { _ in try clamped.sample(for: q1, using: &a) }
		let second = try (0..<128).map { _ in try clamped.sample(for: q1, using: &b) }
		#expect(isBitIdentical(first, second))
		#expect(first.allSatisfy { $0 >= -0.5 && $0 <= 0.5 })
		// The constraint really bit — clamping is not a no-op over 128 unit normals.
		#expect(first.contains { $0.bitPattern == 0.5.bitPattern || $0.bitPattern == (-0.5).bitPattern })
	}

	// MARK: - TimeVaryingDriver

	@Test("TimeVaryingDriver does not claim to be seedable")
	func timeVaryingDoesNotConform() {
		let driver = TimeVaryingDriver<Double>(name: "Opaque") { _ in 0.5 }

		// Its sampler is a caller-supplied closure that owns its randomness; there is
		// nothing to thread a generator into, so it does not conform at all.
		#expect(driver as? any SeedableDriver<Double> == nil)
	}

	@Test("A composite containing a TimeVaryingDriver refuses the seed")
	func compositeOverTimeVaryingRefusesSeed() {
		let good = ProbabilisticDriver<Double>.normal(name: "Good", mean: 1.0, stdDev: 0.1)
		let opaque = TimeVaryingDriver<Double>(name: "Opaque") { _ in 0.5 }
		let product = ProductDriver(name: "Product", lhs: good, rhs: opaque)

		#expect(!product.supportsSeeding)

		var generator = Xoshiro256StarStar(seed: 1)
		#expect(throws: SimulationError.self) {
			_ = try product.sample(for: q1, using: &generator)
		}
	}

	// MARK: - Projection

	@Test("Seeded Monte Carlo projection reproduces exactly")
	func seededProjectionReproduces() throws {
		let driver = ProbabilisticDriver<Double>.normal(name: "Growth", mean: 0.10, stdDev: 0.05)
		let quarters = [q1, q2]
		let projection = DriverProjection(driver: driver, periods: quarters)

		let first = try projection.projectMonteCarlo(iterations: 2_000, seed: 2_026)
		let second = try projection.projectMonteCarlo(iterations: 2_000, seed: 2_026)
		let other = try projection.projectMonteCarlo(iterations: 2_000, seed: 2_027)

		for quarter in quarters {
			#expect(first.statistics[quarter]!.mean.bitPattern == second.statistics[quarter]!.mean.bitPattern)
			#expect(first.percentiles[quarter]!.p5.bitPattern == second.percentiles[quarter]!.p5.bitPattern)
			#expect(first.statistics[quarter]!.mean.bitPattern != other.statistics[quarter]!.mean.bitPattern)
		}
	}

	@Test("Seeded projection over an unseedable driver throws")
	func seededProjectionOverUnseedableThrows() {
		let driver = ProbabilisticDriver<Double>(name: "Opaque", distribution: UnseedableDistribution())
		let projection = DriverProjection(driver: driver, periods: [q1])

		#expect(throws: SimulationError.self) {
			_ = try projection.projectMonteCarlo(iterations: 10, seed: 1)
		}
	}
}

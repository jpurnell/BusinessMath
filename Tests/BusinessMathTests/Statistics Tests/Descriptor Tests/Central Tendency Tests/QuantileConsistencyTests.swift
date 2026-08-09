import Testing
import Foundation
@testable import BusinessMath

/// Pins every empirical-percentile entry point in the library to the single
/// canonical ``quantile(sorted:p:)``.
///
/// Three copies of the inverse normal CDF once coexisted and one was silently
/// broken; it survived because nobody knew there were three. Empirical
/// percentile had the same shape, so these tests exist to make divergence
/// fail loudly rather than quietly.
@Suite("Empirical Quantile Consistency")
struct QuantileConsistencyTests {

	private let probabilities: [Double] = [
		0.0, 0.01, 0.025, 0.05, 0.10, 0.15, 0.25, 0.30, 0.375, 0.40,
		0.50, 0.60, 0.625, 0.75, 0.85, 0.90, 0.95, 0.975, 0.99, 1.0
	]

	private func sample() -> [Double] {
		// Deliberately irregular so interpolation errors cannot hide.
		var seed: UInt64 = 0x5EED_1234
		return (0..<251).map { _ in
			seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
			return Double(seed >> 11) / Double(1 << 53) * 2_000.0 - 500.0
		}.sorted()
	}

	// MARK: - Percentiles (Monte Carlo)

	@Test("Percentiles.percentile matches the canonical quantile")
	func percentilesStructDelegates() throws {
		let values = sample()
		let percentiles = try Percentiles(values: values)
		for p in probabilities {
			#expect(percentiles.percentile(p) == quantile(sorted: values, p: p),
					"Percentiles.percentile diverged from quantile(sorted:p:) at p = \(p)")
		}
	}

	@Test("Percentiles' named fields match the canonical quantile")
	func percentilesNamedFieldsDelegate() throws {
		let values = sample()
		let percentiles = try Percentiles(values: values)
		let expected: [(Double, Double)] = [
			(0.025, percentiles.p025), (0.05, percentiles.p5), (0.10, percentiles.p10),
			(0.25, percentiles.p25), (0.50, percentiles.p50), (0.75, percentiles.p75),
			(0.90, percentiles.p90), (0.95, percentiles.p95), (0.975, percentiles.p975),
			(0.99, percentiles.p99)
		]
		for (p, field) in expected {
			#expect(field == quantile(sorted: values, p: p), "named percentile diverged at p = \(p)")
		}
	}

	// MARK: - FinancialSimulation

	@Test("FinancialSimulation's sorted percentile matches the canonical quantile")
	func financialSimulationDelegates() {
		// The pre-delegation implementation was already R-7; it wrote the
		// interpolation as lo*(1-f) + hi*f rather than lo + f*(hi - lo), which
		// differs only in floating-point rounding. This test pins the exact
		// agreement that delegation now guarantees.
		let values = sample()
		let simulation = FinancialSimulation(projections: [])
		for p in probabilities {
			#expect(simulation.percentileFromSorted(p, values: values) == quantile(sorted: values, p: p),
					"FinancialSimulation diverged from quantile(sorted:p:) at p = \(p)")
		}
	}

	@Test("FinancialSimulation clamps out-of-range p instead of trapping")
	func financialSimulationClampsOutOfRange() {
		// Previously p < 0 or p > 1 computed an out-of-bounds index and trapped.
		let values = [10.0, 20.0, 30.0, 40.0]
		let simulation = FinancialSimulation(projections: [])
		#expect(simulation.percentileFromSorted(-0.5, values: values) == 10.0)
		#expect(simulation.percentileFromSorted(1.5, values: values) == 40.0)
	}

	@Test("FinancialSimulation still returns zero for an empty sample")
	func financialSimulationEmptySample() {
		// FinancialSimulation(projections: []) is publicly constructible, and
		// this entry point has always answered 0 rather than NaN for it.
		let simulation = FinancialSimulation(projections: [])
		#expect(simulation.percentileFromSorted(0.5, values: []) == 0.0)
	}
}

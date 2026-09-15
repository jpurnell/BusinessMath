import Foundation
import Testing
import TestSupport  // identical(_:_:) — bit-for-bit comparison
@testable import BusinessMath

@Suite("InventorySimulator")
struct InventorySimulatorTests {

	// MARK: - Basic simulation

	@Test("Simulation produces valid results")
	func simulationProducesResults() throws {
		let demand = Array(repeating: 10.0, count: 60)
		// Seeded for reproducibility only: demand is the constant 10, so every path is
		// identical and all four assertions hold for any draw.
		let result = try InventorySimulator.simulate(
			demandHistory: demand,
			meanLeadTime: 7.0,
			serviceLevel: 0.95,
			iterations: 1_000,
			seed: 0x1_11_5E_01
		)
		#expect(result.reorderPoint > 0)
		#expect(result.safetyStock >= 0)
		#expect(result.demandDuringLeadTimeMean > 0)
		#expect(result.pathCount == 1_000)
	}

	@Test("Simulation is deterministic with same seed")
	func deterministicWithSeed() throws {
		let demand = (0..<60).map { Double($0 % 7) * 3 + 10 }
		let result1 = try InventorySimulator.simulate(
			demandHistory: demand,
			meanLeadTime: 7.0,
			serviceLevel: 0.95,
			iterations: 5_000,
			seed: 42
		)
		let result2 = try InventorySimulator.simulate(
			demandHistory: demand,
			meanLeadTime: 7.0,
			serviceLevel: 0.95,
			iterations: 5_000,
			seed: 42
		)
		// `identical`, not `==`: two runs that have both gone NaN are the same failure and
		// `==` calls them different, which is the one case a reproducibility test exists
		// to catch.
		#expect(identical(result1.reorderPoint, result2.reorderPoint),
			"Same seed should produce identical results")
	}

	@Test("Different seeds produce different results")
	func differentSeeds() throws {
		let demand = (0..<60).map { Double($0 % 7) * 3 + 10 }
		let result1 = try InventorySimulator.simulate(
			demandHistory: demand,
			meanLeadTime: 7.0,
			serviceLevel: 0.95,
			strategy: .normal,
			iterations: 5_000,
			seed: 42
		)
		let result2 = try InventorySimulator.simulate(
			demandHistory: demand,
			meanLeadTime: 7.0,
			serviceLevel: 0.95,
			strategy: .normal,
			iterations: 5_000,
			seed: 99
		)
		// `!=` passes for free once a stream has gone non-finite, so the divergence claim
		// needs both a finiteness guard and `!identical`.
		#expect(result1.reorderPoint.isFinite && result2.reorderPoint.isFinite,
			"a non-finite reorder point is a failure, not a difference")
		#expect(!identical(result1.reorderPoint, result2.reorderPoint),
			"Different seeds should produce different results")
	}

	// MARK: - Cross-validation with analytical

	@Test("Simulation converges to analytical safety stock for normal demand")
	func convergestoAnalytical() throws {
		let leadTime = 7.0
		let serviceLevel = 0.95

		// The library's transform, not another inline copy.
		//
		// The version that stood here was *correct* — `Double(raw >> 11) * 0x1.0p-53`
		// cannot reach 1.0, and the `leastNonzeroMagnitude` guard handled 0 — which is
		// worth saying because most inline copies in this corpus are not: the one deleted
		// from `StochasticTestHelpers` was closed on both ends and left u₁ = 1.0
		// unguarded, where `log(1) = 0` collapses the draw to exactly zero. Correct or
		// not, a transform maintained in two places drifts, and `openUnitUniform` is open
		// *by construction* rather than by a guard someone has to remember.
		var rng = DeterministicRNG(seed: 1)
		let demand = (0..<1000).map { _ -> Double in
			let (z, _): (Double, Double) = boxMullerSeed(using: &rng)
			return 10.0 + 3.0 * z
		}

		let n = Double(demand.count)
		let sampleMean = demand.reduce(0.0, +) / n
		let sampleVar = demand.map { ($0 - sampleMean) * ($0 - sampleMean) }
			.reduce(0.0, +) / (n - 1)
		let sampleStdDev = Foundation.sqrt(sampleVar)

		let analyticalSS = try SafetyStockModel<Double>.safetyStock(
			method: .demandOnly,
			serviceLevel: serviceLevel,
			averageDemand: sampleMean,
			demandStdDev: sampleStdDev,
			leadTime: leadTime
		)

		let simResult = try InventorySimulator.simulate(
			demandHistory: demand,
			meanLeadTime: leadTime,
			serviceLevel: serviceLevel,
			strategy: .normal,
			iterations: 50_000,
			seed: 42
		)

		let tolerance = analyticalSS * 0.20
		#expect(abs(simResult.safetyStock - analyticalSS) < tolerance,
			"Simulation safety stock (\(simResult.safetyStock)) should be within 20% of analytical (\(analyticalSS))")
	}

	// MARK: - Sampling strategies

	@Test("Empirical strategy works")
	func empiricalStrategy() throws {
		let demand = [5.0, 10.0, 15.0, 8.0, 12.0, 7.0, 11.0, 9.0, 14.0, 6.0,
					  10.0, 13.0, 8.0, 11.0, 9.0, 12.0, 7.0, 10.0, 14.0, 8.0,
					  11.0, 9.0, 13.0, 7.0, 10.0, 12.0, 8.0, 11.0, 9.0, 10.0]
		let result = try InventorySimulator.simulate(
			demandHistory: demand,
			meanLeadTime: 7.0,
			serviceLevel: 0.95,
			strategy: .empirical,
			iterations: 5_000,
			seed: 42
		)
		#expect(result.reorderPoint > 0)
		#expect(result.samplingStrategy == "empirical")
	}

	@Test("Normal strategy works")
	func normalStrategy() throws {
		let demand = [5.0, 10.0, 15.0, 8.0, 12.0, 7.0, 11.0, 9.0, 14.0, 6.0,
					  10.0, 13.0, 8.0, 11.0, 9.0, 12.0, 7.0, 10.0, 14.0, 8.0,
					  11.0, 9.0, 13.0, 7.0, 10.0, 12.0, 8.0, 11.0, 9.0, 10.0]
		let result = try InventorySimulator.simulate(
			demandHistory: demand,
			meanLeadTime: 7.0,
			serviceLevel: 0.95,
			strategy: .normal,
			iterations: 5_000,
			seed: 42
		)
		#expect(result.reorderPoint > 0)
		#expect(result.samplingStrategy == "normal")
	}

	// MARK: - Lead time variability

	@Test("Lead time variability increases reorder point")
	func leadTimeVariabilityIncreasesReorderPoint() throws {
		let demand = [5.0, 10.0, 15.0, 8.0, 12.0, 7.0, 11.0, 9.0, 14.0, 6.0,
					  10.0, 13.0, 8.0, 11.0, 9.0, 12.0, 7.0, 10.0, 14.0, 8.0,
					  11.0, 9.0, 13.0, 7.0, 10.0, 12.0, 8.0, 11.0, 9.0, 10.0]

		let resultFixed = try InventorySimulator.simulate(
			demandHistory: demand,
			meanLeadTime: 7.0,
			leadTimeStdDev: 0.0,
			serviceLevel: 0.95,
			strategy: .normal,
			iterations: 10_000,
			seed: 42
		)
		let resultVariable = try InventorySimulator.simulate(
			demandHistory: demand,
			meanLeadTime: 7.0,
			leadTimeStdDev: 3.0,
			serviceLevel: 0.95,
			strategy: .normal,
			iterations: 10_000,
			seed: 42
		)
		#expect(resultVariable.reorderPoint > resultFixed.reorderPoint,
			"Variable lead time should require higher reorder point")
	}

	// MARK: - Edge cases

	@Test("Rejects empty demand history")
	func rejectsEmptyHistory() throws {
		#expect {
			// Seeded for reproducibility only: the empty history is rejected before any
			// path is drawn, so the assertion cannot vary.
			_ = try InventorySimulator.simulate(
				demandHistory: [],
				meanLeadTime: 7.0,
				serviceLevel: 0.95,
				seed: 0x1_11_5E_02
			)
		} throws: { error in
			guard case let OperationsError.insufficientData(required, got) = error else { return false }
			return required == 1 && got == 0
		}
	}

	@Test("Rejects invalid service level")
	func rejectsInvalidServiceLevel() throws {
		#expect {
			// Seeded for reproducibility only: the invalid service level is rejected
			// before any path is drawn, so the assertion cannot vary.
			_ = try InventorySimulator.simulate(
				demandHistory: Array(repeating: 10.0, count: 30),
				meanLeadTime: 7.0,
				serviceLevel: 1.5,
				seed: 0x1_11_5E_03
			)
		} throws: { error in
			guard case OperationsError.invalidServiceLevel = error else { return false }
			return true
		}
	}
}

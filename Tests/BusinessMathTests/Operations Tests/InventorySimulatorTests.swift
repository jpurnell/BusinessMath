import Foundation
import Testing
@testable import BusinessMath

@Suite("InventorySimulator")
struct InventorySimulatorTests {

	// MARK: - Basic simulation

	@Test("Simulation produces valid results")
	func simulationProducesResults() throws {
		let demand = Array(repeating: 10.0, count: 60)
		let result = try InventorySimulator.simulate(
			demandHistory: demand,
			meanLeadTime: 7.0,
			serviceLevel: 0.95,
			iterations: 1_000
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
		#expect(result1.reorderPoint == result2.reorderPoint,
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
		#expect(result1.reorderPoint != result2.reorderPoint,
			"Different seeds should produce different results")
	}

	// MARK: - Cross-validation with analytical

	@Test("Simulation converges to analytical safety stock for normal demand")
	func convergestoAnalytical() throws {
		let leadTime = 7.0
		let serviceLevel = 0.95

		var rng = DeterministicRNG(seed: 1)
		let demand = (0..<1000).map { _ -> Double in
			let raw1 = rng.next()
			let u1 = Swift.max(Double(raw1 >> 11) * 0x1.0p-53, Double.leastNonzeroMagnitude)
			let raw2 = rng.next()
			let u2 = Double(raw2 >> 11) * 0x1.0p-53
			let z = Foundation.sqrt(-2.0 * Foundation.log(u1)) * Foundation.cos(2.0 * .pi * u2)
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
	func rejectsEmptyHistory() {
		#expect(throws: OperationsError.self) {
			_ = try InventorySimulator.simulate(
				demandHistory: [],
				meanLeadTime: 7.0,
				serviceLevel: 0.95
			)
		}
	}

	@Test("Rejects invalid service level")
	func rejectsInvalidServiceLevel() {
		#expect(throws: OperationsError.self) {
			_ = try InventorySimulator.simulate(
				demandHistory: Array(repeating: 10.0, count: 30),
				meanLeadTime: 7.0,
				serviceLevel: 1.5
			)
		}
	}
}

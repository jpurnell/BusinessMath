//
//  SimulationSeedTests.swift
//  BusinessMathTests
//
//  RED-phase tests for MonteCarloSimulation seeding and the async run() overload
//  (MonteCarloDeterminismAndAsyncExecution proposal, Phase 1).
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("MonteCarloSimulation seeding")
struct SimulationSeedTests {

	private func makeSimulation(seed: UInt64?, iterations: Int = 500, enableGPU: Bool = false) -> MonteCarloSimulation {
		var simulation = MonteCarloSimulation(iterations: iterations, enableGPU: enableGPU, seed: seed) { inputs in
			inputs[0] + inputs[1]
		}
		simulation.addInput(SimulationInput(name: "A", distribution: DistributionNormal(100, 15)))
		simulation.addInput(SimulationInput(name: "B", distribution: DistributionNormal(50, 5)))
		return simulation
	}

	@Test("CPU: same seed produces identical results")
	func cpuSameSeedIdentical() throws {
		let first = try makeSimulation(seed: 42).run()
		let second = try makeSimulation(seed: 42).run()
		#expect(first.values == second.values)
		#expect(first.usedGPU == false)
	}

	@Test("CPU: different seeds produce different results")
	func cpuDifferentSeedsDiffer() throws {
		let first = try makeSimulation(seed: 1).run()
		let second = try makeSimulation(seed: 2).run()
		#expect(first.values != second.values)
	}

	@Test("CPU: nil seed remains non-deterministic")
	func cpuNilSeedNondeterministic() throws {
		let first = try makeSimulation(seed: nil).run()
		let second = try makeSimulation(seed: nil).run()
		#expect(first.values != second.values)
	}

	@Test("Seeded run with custom-sampler input throws seedingUnsupported")
	func customSamplerThrows() throws {
		var simulation = MonteCarloSimulation(iterations: 100, enableGPU: false, seed: 7) { inputs in
			inputs[0]
		}
		simulation.addInput(SimulationInput(name: "Custom") { 1.0 })
		#expect(throws: SimulationError.self) {
			try simulation.run()
		}
	}

	@Test("Seeded run with correlation matrix throws seedingUnsupported")
	func correlationThrows() throws {
		var simulation = MonteCarloSimulation(iterations: 100, enableGPU: false, seed: 7) { inputs in
			inputs[0] + inputs[1]
		}
		simulation.addInput(SimulationInput(name: "A", distribution: DistributionNormal(100, 15)))
		simulation.addInput(SimulationInput(name: "B", distribution: DistributionNormal(50, 5)))
		try simulation.setCorrelationMatrix([[1.0, 0.5], [0.5, 1.0]])
		#expect(throws: SimulationError.self) {
			try simulation.run()
		}
	}

	@Test("Unseeded run with custom-sampler input still works")
	func unseededCustomSamplerWorks() throws {
		var simulation = MonteCarloSimulation(iterations: 100, enableGPU: false) { inputs in
			inputs[0]
		}
		simulation.addInput(SimulationInput(name: "Custom") { 1.0 })
		let results = try simulation.run()
		#expect(results.values.count == 100)
	}

	#if canImport(Metal)
	@Test("GPU: same seed produces identical results")
	func gpuSameSeedIdentical() throws {
		guard MonteCarloGPUDevice() != nil else { return }
		let model = try MonteCarloExpressionModel { builder in builder[0] + builder[1] }
		func gpuSim() -> MonteCarloSimulation {
			var simulation = MonteCarloSimulation(iterations: 10_000, enableGPU: true, seed: 42, expressionModel: model)
			simulation.addInput(SimulationInput(name: "A", distribution: DistributionNormal(100, 15)))
			simulation.addInput(SimulationInput(name: "B", distribution: DistributionNormal(50, 5)))
			return simulation
		}
		let first = try gpuSim().run()
		let second = try gpuSim().run()
		#expect(first.usedGPU == true)
		#expect(first.values == second.values)
	}
	#endif
}

@Suite("MonteCarloSimulation async run")
struct AsyncRunTests {

	/// Forces the synchronous `run()` overload — in an async context a bare
	/// `simulation.run()` resolves to the async overload.
	private func runSynchronously(_ simulation: MonteCarloSimulation) throws -> SimulationResults {
		try simulation.run()
	}

	@Test("Async CPU run with seed matches sync run")
	func asyncMatchesSyncCPU() async throws {
		func seededSim() -> MonteCarloSimulation {
			var simulation = MonteCarloSimulation(iterations: 500, enableGPU: false, seed: 42) { inputs in
				inputs[0] * 2
			}
			simulation.addInput(SimulationInput(name: "A", distribution: DistributionNormal(10, 2)))
			return simulation
		}
		let syncResults = try runSynchronously(seededSim())
		let asyncResults = try await seededSim().run()
		#expect(syncResults.values == asyncResults.values)
	}

	#if canImport(Metal)
	@Test("Async GPU run with seed matches sync GPU run")
	func asyncMatchesSyncGPU() async throws {
		guard MonteCarloGPUDevice() != nil else { return }
		let model = try MonteCarloExpressionModel { builder in builder[0] + builder[1] }
		func gpuSim() -> MonteCarloSimulation {
			var simulation = MonteCarloSimulation(iterations: 10_000, enableGPU: true, seed: 9, expressionModel: model)
			simulation.addInput(SimulationInput(name: "A", distribution: DistributionNormal(100, 15)))
			simulation.addInput(SimulationInput(name: "B", distribution: DistributionNormal(50, 5)))
			return simulation
		}
		let syncResults = try runSynchronously(gpuSim())
		let asyncResults = try await gpuSim().run()
		#expect(asyncResults.usedGPU == true)
		#expect(syncResults.values == asyncResults.values)
	}
	#endif

	@Test("Async CPU run surfaces cancellation promptly", .timeLimit(.minutes(2)))
	func asyncCancellation() async throws {
		// The run checks Task.checkCancellation() at every 1024-iteration checkpoint
		// (including iteration 0), so a cancelled task surfaces the error at its first
		// checkpoint. Cancelling promptly (rather than sleeping a fixed interval and
		// hoping the run is still mid-flight) makes this deterministic and removes the
		// wall-clock race that previously flaked under parallel test load. A modest
		// iteration count avoids a large, load-sensitive capacity reservation.
		var simulation = MonteCarloSimulation(iterations: 1_000_000, enableGPU: false) { inputs in
			inputs[0]
		}
		simulation.addInput(SimulationInput(name: "A", distribution: DistributionNormal(0, 1)))
		let frozen = simulation

		let task = Task { try await frozen.run() }
		task.cancel()

		await #expect(throws: (any Error).self) {
			_ = try await task.value
		}
	}
}

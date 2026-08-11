//
//  MonteCarloFaultInjectionTests.swift
//  BusinessMath
//
//  Fault injection tests verifying Monte Carlo simulation handles
//  pathological inputs gracefully (NaN, Infinity, zero iterations, etc.)
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("Monte Carlo Fault Injection Tests")
struct MonteCarloFaultInjectionTests {

	@Test("Model returning NaN throws invalidModel error")
	func modelReturningNaN() throws {
		var simulation = MonteCarloSimulation(iterations: 100, enableGPU: false, seed: 0xD62C_49BF) { _ in
			Double.nan
		}
		simulation.addInput(SimulationInput(
			name: "X",
			distribution: DistributionNormal(0.0, 1.0)
		))

		#expect(throws: SimulationError.self) {
			_ = try simulation.run()
		}
	}

	@Test("Model returning Infinity throws invalidModel error")
	func modelReturningInfinity() throws {
		var simulation = MonteCarloSimulation(iterations: 100, enableGPU: false, seed: 0xE73D_5AC0) { _ in
			Double.infinity
		}
		simulation.addInput(SimulationInput(
			name: "X",
			distribution: DistributionNormal(0.0, 1.0)
		))

		#expect(throws: SimulationError.self) {
			_ = try simulation.run()
		}
	}

	@Test("Zero iterations throws insufficientIterations")
	func zeroIterations() throws {
		var simulation = MonteCarloSimulation(iterations: 0, enableGPU: false, seed: 0xF84E_6BD1) { inputs in
			inputs[0]
		}
		simulation.addInput(SimulationInput(
			name: "X",
			distribution: DistributionNormal(0.0, 1.0)
		))

		#expect(throws: SimulationError.self) {
			_ = try simulation.run()
		}
	}

	@Test("Empty inputs throws noInputs")
	func emptyInputs() throws {
		let simulation = MonteCarloSimulation(iterations: 100, enableGPU: false, seed: 0x095F_7CE2) { inputs in
			inputs[0]
		}

		#expect(throws: SimulationError.self) {
			_ = try simulation.run()
		}
	}

	@Test("Extreme distribution parameters still produce finite results")
	func extremeDistributionParameters() throws {
		var simulation = MonteCarloSimulation(iterations: 100, enableGPU: false, seed: 0x1A60_8DF3) { inputs in
			inputs[0]
		}
		simulation.addInput(SimulationInput(
			name: "Extreme",
			distribution: DistributionNormal(1e15, 1e-15)
		))

		let results = try simulation.run()
		let allFinite = results.values.allSatisfy { $0.isFinite }
		#expect(allFinite, "All results should be finite even with extreme distribution parameters")
	}

	@Test("Model returning NaN after some valid iterations throws invalidModel")
	func conditionalNaN() throws {
			// Seeded so the trip point is a fixed iteration rather than a draw. The
			// assertion is not fragile — for it to fail, all 1,000 Uniform(0, 1) draws
			// would have to land at or below 0.5, probability 2^-1000 — but a seed makes
			// any future failure reproducible instead of a coin flip to investigate.
		var simulation = MonteCarloSimulation(iterations: 1000, enableGPU: false, seed: 0x2B71_9F04) { inputs in
			inputs[0] > 0.5 ? Double.nan : inputs[0]
		}
		simulation.addInput(SimulationInput(
			name: "U",
			distribution: DistributionUniform(0.0, 1.0)
		))

		#expect(throws: SimulationError.self) {
			_ = try simulation.run()
		}
	}
}

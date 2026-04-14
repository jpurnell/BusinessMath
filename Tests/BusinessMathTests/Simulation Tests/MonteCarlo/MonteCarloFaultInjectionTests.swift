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
		var simulation = MonteCarloSimulation(iterations: 100, enableGPU: false) { _ in
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
		var simulation = MonteCarloSimulation(iterations: 100, enableGPU: false) { _ in
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
		var simulation = MonteCarloSimulation(iterations: 0, enableGPU: false) { inputs in
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
		let simulation = MonteCarloSimulation(iterations: 100, enableGPU: false) { inputs in
			inputs[0]
		}

		#expect(throws: SimulationError.self) {
			_ = try simulation.run()
		}
	}

	@Test("Extreme distribution parameters still produce finite results")
	func extremeDistributionParameters() throws {
		var simulation = MonteCarloSimulation(iterations: 100, enableGPU: false) { inputs in
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
		var simulation = MonteCarloSimulation(iterations: 1000, enableGPU: false) { inputs in
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

//
//  MonteCarloSimulationTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("MonteCarloSimulation Tests")
struct MonteCarloSimulationTests {

	@Test("MonteCarloSimulation basic initialization")
	func monteCarloSimulationInitialization() {
		// Create a simple simulation
		let simulation = MonteCarloSimulation(iterations: 1_000) { inputs in
			return inputs[0] + inputs[1]  // Sum of two inputs
		}

		#expect(simulation.iterations == 1_000)
		#expect(simulation.inputs.count == 0, "Should start with no inputs")
	}

	@Test("MonteCarloSimulation adding inputs")
	func monteCarloSimulationAddingInputs() {
		var simulation = MonteCarloSimulation(iterations: 100) { inputs in
			return inputs[0]
		}

		let input1 = SimulationInput(name: "Input1", distribution: DistributionNormal(100.0, 10.0))
		simulation.addInput(input1)

		#expect(simulation.inputs.count == 1)
		#expect(simulation.inputs[0].name == "Input1")

		let input2 = SimulationInput(name: "Input2", distribution: DistributionUniform(50.0, 150.0))
		simulation.addInput(input2)

		#expect(simulation.inputs.count == 2)
	}

	@Test("MonteCarloSimulation simple model execution")
	func monteCarloSimulationSimpleExecution() throws {
		// Simple model: constant value
		var simulation = MonteCarloSimulation(iterations: 100) { inputs in
			return 42.0
		}

		let input = SimulationInput(name: "Dummy", distribution: DistributionNormal(0.0, 1.0))
		simulation.addInput(input)

		let results = try simulation.run()

		#expect(results.values.count == 100)
		#expect(results.statistics.mean == 42.0, "All values should be 42")
		#expect(results.statistics.stdDev == 0.0, "No variation")
	}

	@Test("MonteCarloSimulation sum of normals")
	func monteCarloSimulationSumOfNormals() throws {
		// Model: sum of two normal distributions
		// N(100, 15) + N(50, 10) should give N(150, sqrt(15^2 + 10^2)) = N(150, 18.03)
		var simulation = MonteCarloSimulation(iterations: 10_000) { inputs in
			return inputs[0] + inputs[1]
		}

		simulation.addInput(SimulationInput(name: "X1", distribution: DistributionNormal(100.0, 15.0)))
		simulation.addInput(SimulationInput(name: "X2", distribution: DistributionNormal(50.0, 10.0)))

		let results = try simulation.run()

		// Expected: mean = 150, stdDev = sqrt(225 + 100) = 18.03
		#expect(results.statistics.mean > 145.0 && results.statistics.mean < 155.0, "Mean should be ~150")
		#expect(results.statistics.stdDev > 16.0 && results.statistics.stdDev < 20.0, "StdDev should be ~18")
	}

	@Test("MonteCarloSimulation revenue minus costs model")
	func monteCarloSimulationRevenueCostsModel() throws {
		// Real-world model: Profit = Revenue - Costs
		var simulation = MonteCarloSimulation(iterations: 5_000) { inputs in
			let revenue = inputs[0]
			let costs = inputs[1]
			return revenue - costs
		}

		simulation.addInput(SimulationInput(name: "Revenue", distribution: DistributionNormal(1_000_000.0, 100_000.0)))
		simulation.addInput(SimulationInput(name: "Costs", distribution: DistributionNormal(700_000.0, 50_000.0)))

		let results = try simulation.run()

		// Expected profit: ~300,000
		#expect(results.statistics.mean > 250_000 && results.statistics.mean < 350_000)

		// Check probability of loss
		let probLoss = results.probabilityBelow(0.0)
		#expect(probLoss < 0.05, "Low probability of loss")
	}

	@Test("MonteCarloSimulation convergence with iterations")
	func monteCarloSimulationConvergence() throws {
		// Test that more iterations lead to more accurate results
		var simulation1000 = MonteCarloSimulation(iterations: 1_000) { inputs in
			return inputs[0]
		}
		var simulation10000 = MonteCarloSimulation(iterations: 10_000) { inputs in
			return inputs[0]
		}

		let input = SimulationInput(name: "X", distribution: DistributionNormal(100.0, 15.0))
		simulation1000.addInput(input)
		simulation10000.addInput(input)

		let results1000 = try simulation1000.run()
		let results10000 = try simulation10000.run()

		// Standard error of the mean = stdDev / sqrt(n)
		let se1000 = results1000.statistics.stdDev / sqrt(1_000.0)
		let se10000 = results10000.statistics.stdDev / sqrt(10_000.0)

		#expect(se10000 < se1000, "More iterations should give lower standard error")

		// 10K iterations should be closer to true mean (100)
		let error1000 = abs(results1000.statistics.mean - 100.0)
		let error10000 = abs(results10000.statistics.mean - 100.0)

		// On average, 10K should be more accurate (though not guaranteed in single test)
		#expect(error10000 < 5.0, "10K iterations should be very close to true mean")
	}

	@Test("MonteCarloSimulation with custom sampling function")
	func monteCarloSimulationCustomSampler() throws {
		var simulation = MonteCarloSimulation(iterations: 1_000) { inputs in
			return inputs[0] * 2.0
		}

		// Use custom sampler that always returns 5.0
		let input = SimulationInput(name: "Constant") {
			return 5.0
		}
		simulation.addInput(input)

		let results = try simulation.run()

		#expect(results.statistics.mean == 10.0, "5 * 2 = 10")
		#expect(results.statistics.stdDev == 0.0, "No variation")
	}

	@Test("MonteCarloSimulation error handling - no inputs")
	func monteCarloSimulationNoInputs() {
		let simulation = MonteCarloSimulation(iterations: 100) { inputs in
			return 42.0
		}

		// Should throw error when run without inputs
		#expect(throws: SimulationError.self) {
			try simulation.run()
		}
	}

	@Test("MonteCarloSimulation error handling - zero iterations")
	func monteCarloSimulationZeroIterations() {
		var simulation = MonteCarloSimulation(iterations: 0) { inputs in
			return inputs[0]
		}

		simulation.addInput(SimulationInput(name: "X", distribution: DistributionNormal(0.0, 1.0)))

		#expect(throws: SimulationError.self) {
			try simulation.run()
		}
	}

	@Test("MonteCarloSimulation with single iteration")
	func monteCarloSimulationSingleIteration() throws {
		var simulation = MonteCarloSimulation(iterations: 1) { inputs in
			return inputs[0] + inputs[1]
		}

		simulation.addInput(SimulationInput(name: "X", distribution: DistributionNormal(100.0, 10.0)))
		simulation.addInput(SimulationInput(name: "Y", distribution: DistributionNormal(50.0, 5.0)))

		let results = try simulation.run()

		#expect(results.values.count == 1)
		#expect(results.statistics.stdDev == 0.0, "Single iteration has no variance")
	}

	@Test("MonteCarloSimulation complex financial model")
	func monteCarloSimulationComplexModel() throws {
		// Complex model: NPV = (Revenue * (1 - CostRate) - FixedCosts) * (1 + GrowthRate)
		var simulation = MonteCarloSimulation(iterations: 5_000) { inputs in
			let revenue = inputs[0]
			let costRate = inputs[1]
			let fixedCosts = inputs[2]
			let growthRate = inputs[3]

			let grossProfit = revenue * (1.0 - costRate)
			let netProfit = grossProfit - fixedCosts
			let adjustedProfit = netProfit * (1.0 + growthRate)

			return adjustedProfit
		}

		simulation.addInput(SimulationInput(name: "Revenue", distribution: DistributionNormal(10_000_000.0, 1_000_000.0)))
		simulation.addInput(SimulationInput(name: "CostRate", distribution: DistributionUniform(0.55, 0.65)))
		simulation.addInput(SimulationInput(name: "FixedCosts", distribution: DistributionNormal(2_000_000.0, 200_000.0)))
		simulation.addInput(SimulationInput(name: "GrowthRate", distribution: DistributionUniform(0.05, 0.15)))

		let results = try simulation.run()

		// Verify results are reasonable
		#expect(results.values.count == 5_000)
		#expect(results.statistics.mean > 0.0, "Expected positive profit")

		// Generate histogram
		let histogram = results.histogram(bins: 20)
		#expect(histogram.count == 20)
	}

	@Test("MonteCarloSimulation performance - 10K iterations")
	func monteCarloSimulationPerformance10K() throws {
		var simulation = MonteCarloSimulation(iterations: 10_000) { inputs in
			return inputs[0] + inputs[1] + inputs[2]
		}

		simulation.addInput(SimulationInput(name: "X1", distribution: DistributionNormal(100.0, 10.0)))
		simulation.addInput(SimulationInput(name: "X2", distribution: DistributionNormal(200.0, 20.0)))
		simulation.addInput(SimulationInput(name: "X3", distribution: DistributionUniform(50.0, 150.0)))

		// Should complete quickly (< 1 second for 10K iterations)
		let results = try simulation.run()

		#expect(results.values.count == 10_000)
	}

	@Test("MonteCarloSimulation with triangular distribution")
	func monteCarloSimulationTriangularDist() throws {
		// Project estimation using triangular (PERT) distribution
		var simulation = MonteCarloSimulation(iterations: 2_000) { inputs in
			let optimistic = inputs[0]
			let mostLikely = inputs[1]
			let pessimistic = inputs[2]

			// PERT estimate: (optimistic + 4*mostLikely + pessimistic) / 6
			return (optimistic + 4.0 * mostLikely + pessimistic) / 6.0
		}

		simulation.addInput(SimulationInput(name: "Optimistic", distribution: DistributionTriangular(low: 10.0, high: 15.0, base: 12.0)))
		simulation.addInput(SimulationInput(name: "MostLikely", distribution: DistributionTriangular(low: 15.0, high: 25.0, base: 20.0)))
		simulation.addInput(SimulationInput(name: "Pessimistic", distribution: DistributionTriangular(low: 25.0, high: 40.0, base: 30.0)))

		let results = try simulation.run()

		// PERT estimate should be between optimistic and pessimistic
		#expect(results.statistics.mean > 15.0 && results.statistics.mean < 30.0)
	}

	@Test("MonteCarloSimulation multiple independent runs")
	func monteCarloSimulationMultipleRuns() throws {
		// Verify that multiple runs give different results (proper randomness)
		var simulation = MonteCarloSimulation(iterations: 1_000) { inputs in
			return inputs[0]
		}

		simulation.addInput(SimulationInput(name: "X", distribution: DistributionUniform(0.0, 100.0)))

		let results1 = try simulation.run()
		let results2 = try simulation.run()

		// Means should be similar but not identical
		#expect(abs(results1.statistics.mean - results2.statistics.mean) < 10.0, "Means should be similar")
		#expect(results1.statistics.mean != results2.statistics.mean, "Should not be exactly equal")

		// First values should be different
		#expect(results1.values[0] != results2.values[0], "Random values should differ")
	}

	@Test("MonteCarloSimulation input order matters")
	func monteCarloSimulationInputOrder() throws {
		// Test that model receives inputs in the order they were added
		var simulation = MonteCarloSimulation(iterations: 100) { inputs in
			// Return difference to verify order
			return inputs[0] - inputs[1]
		}

		simulation.addInput(SimulationInput(name: "Larger") { 100.0 })
		simulation.addInput(SimulationInput(name: "Smaller") { 50.0 })

		let results = try simulation.run()

		#expect(results.statistics.mean == 50.0, "100 - 50 = 50")
	}

	@Test("MonteCarloSimulation with weibull reliability analysis")
	func monteCarloSimulationWeibullReliability() throws {
		// Model: reliability analysis for component failure
		var simulation = MonteCarloSimulation(iterations: 5_000) { inputs in
			let component1Life = inputs[0]
			let component2Life = inputs[1]

			// System fails when first component fails
			return min(component1Life, component2Life)
		}

		simulation.addInput(SimulationInput(name: "Component1", distribution: DistributionWeibull(shape: 2.0, scale: 1000.0)))
		simulation.addInput(SimulationInput(name: "Component2", distribution: DistributionWeibull(shape: 1.5, scale: 1200.0)))

		let results = try simulation.run()

		// System life should be less than individual component lives
		#expect(results.statistics.mean < 1000.0, "System should fail before average component")
	}
}

	//
	//  MonteCarloSimulationTests.swift
	//  BusinessMath
	//
	//  Created by Justin Purnell on 10/15/25.
	//

import Foundation
import TestSupport  // Cross-platform math functions
import Testing
import Numerics
#if canImport(OSLog)
import OSLog
#endif
@testable import BusinessMath

// MARK: - Shared Test Helpers

/// Simple deterministic LCG to produce reproducible uniform(0,1) values
fileprivate func deterministicUniforms(seed: UInt64, count: Int) -> [Double] {
	var state = seed
	func next() -> UInt64 {
		state = 2862933555777941757 &* state &+ 3037000493
		return state
	}
	let denom = Double(UInt64.max)
	return (0..<count).map { _ in Double(next()) / denom }
}

/// Feed that hands out precomputed values in order.
/// Marked @unchecked Sendable because tests run single-threaded;
/// the sampler closure is @Sendable and only calls next(), avoiding
/// captured var mutation warnings.
fileprivate final class SamplerFeed: @unchecked Sendable {
	private let values: [Double]
	private var index = 0
	init(values: [Double]) { self.values = values }
	func next() -> Double {
		let v = values[index]
		index += 1
		return v
	}
}

// MARK: - Tests

@Suite("MonteCarloSimulation Tests", .serialized)
struct MonteCarloSimulationTests {
	let logger = Logger(subsystem: "\(#file)", category: "\(#function)")
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
		// Test that more iterations lead to lower standard error using deterministic values
		// Use Box-Muller to generate proper normal distribution samples
		let seed: UInt64 = 55555
		let uniforms1000 = deterministicUniforms(seed: seed, count: 1_000)
		let uniforms10000 = deterministicUniforms(seed: seed, count: 10_000)

		// Generate normal samples using Box-Muller transform (pairs of uniforms)
		var values1000: [Double] = []
		for i in stride(from: 0, to: 1_000, by: 2) {
			let u1 = uniforms1000[i]
			let u2 = uniforms1000[i + 1]
			let z = sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
			values1000.append(100.0 + 15.0 * z)  // N(100, 15)
		}

		var values10000: [Double] = []
		for i in stride(from: 0, to: 10_000, by: 2) {
			let u1 = uniforms10000[i]
			let u2 = uniforms10000[i + 1]
			let z = sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
			values10000.append(100.0 + 15.0 * z)  // N(100, 15)
		}

		let feed1000 = SamplerFeed(values: values1000)
		let feed10000 = SamplerFeed(values: values10000)

		var simulation1000 = MonteCarloSimulation(iterations: values1000.count) { inputs in
			return inputs[0]
		}
		var simulation10000 = MonteCarloSimulation(iterations: values10000.count) { inputs in
			return inputs[0]
		}

		simulation1000.addInput(SimulationInput(name: "X") { feed1000.next() })
		simulation10000.addInput(SimulationInput(name: "X") { feed10000.next() })

		let results1000 = try simulation1000.run()
		let results10000 = try simulation10000.run()

		// Standard error of the mean = stdDev / sqrt(n)
		// This is deterministically smaller with more samples
		let se1000 = results1000.statistics.stdDev / sqrt(Double(values1000.count))
		let se10000 = results10000.statistics.stdDev / sqrt(Double(values10000.count))

		#expect(se10000 < se1000, "More iterations should give lower standard error")

		// Both means should be reasonably close to 100 (within 3 standard errors)
		#expect(abs(results1000.statistics.mean - 100.0) < 3.0 * se1000, "Mean should be within 3σ")
		#expect(abs(results10000.statistics.mean - 100.0) < 3.0 * se10000, "Mean should be within 3σ")
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
			//		logger.info("Monte Carlo Simulation - Complex Model Results:\n\n\(plotHistogram(histogram))")
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
	
	@Test("MonteCarloSimulation multiple independent runs with different seeds")
	func monteCarloSimulationMultipleRuns() throws {
		// Verify that runs with different seeds give different but statistically similar results
		let iterations = 1_000

		// Generate two deterministic sequences with different seeds
		let values1 = deterministicUniforms(seed: 11111, count: iterations).map { $0 * 100.0 }
		let values2 = deterministicUniforms(seed: 22222, count: iterations).map { $0 * 100.0 }

		let feed1 = SamplerFeed(values: values1)
		let feed2 = SamplerFeed(values: values2)

		var simulation1 = MonteCarloSimulation(iterations: iterations) { inputs in
			return inputs[0]
		}
		var simulation2 = MonteCarloSimulation(iterations: iterations) { inputs in
			return inputs[0]
		}

		simulation1.addInput(SimulationInput(name: "X") { feed1.next() })
		simulation2.addInput(SimulationInput(name: "X") { feed2.next() })

		let results1 = try simulation1.run()
		let results2 = try simulation2.run()

		// Means should be similar (both sampling from Uniform[0,100])
		#expect(abs(results1.statistics.mean - results2.statistics.mean) < 10.0, "Means should be similar")

		// But sequences should be different (different seeds)
		#expect(results1.values != results2.values, "Different seeds should produce different sequences")
		#expect(results1.values[0] != results2.values[0], "First values should differ with different seeds")
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

@Suite("MonteCarloSimulation – Additional", .serialized)
struct MonteCarloSimulationAdditionalTests {

	@Test("Deterministic custom inputs produce deterministic results")
	func deterministicRun() throws {
		let iterations = 1_000
		
			// Precompute deterministic sequences for both inputs
		let uA = deterministicUniforms(seed: 12345, count: iterations)
		let uB = deterministicUniforms(seed: 98765, count: iterations)
		
			// Scale to desired ranges
		let aVals = uA.map { 100.0 + 10.0 * $0 }
		let bVals = uB.map {  50.0 +  5.0 * $0 }
		
			// First simulation uses feeds A1/B1
		let feedA1 = SamplerFeed(values: aVals)
		let feedB1 = SamplerFeed(values: bVals)
		
		let inputA1 = SimulationInput(name: "A") { feedA1.next() }
		let inputB1 = SimulationInput(name: "B") { feedB1.next() }
		
		var sim1 = MonteCarloSimulation(iterations: iterations) { inputs in
			inputs[0] + inputs[1]
		}
		sim1.addInput(inputA1)
		sim1.addInput(inputB1)
		
			// Second simulation uses fresh feeds with the same values
		let feedA2 = SamplerFeed(values: aVals)
		let feedB2 = SamplerFeed(values: bVals)
		
		let inputA2 = SimulationInput(name: "A") { feedA2.next() }
		let inputB2 = SimulationInput(name: "B") { feedB2.next() }
		
		var sim2 = MonteCarloSimulation(iterations: iterations) { inputs in
			inputs[0] + inputs[1]
		}
		sim2.addInput(inputA2)
		sim2.addInput(inputB2)
		
		let r1 = try sim1.run()
		let r2 = try sim2.run()
		
		#expect(r1.values == r2.values, "Deterministic samplers should give identical sequences")
		#expect(r1.statistics.mean == r2.statistics.mean)
		#expect(r1.statistics.stdDev == r2.statistics.stdDev)
	}
	
	@Test("runCorrelated rejects ρ=1 (singular) for two normals")
	func correlatedRejectsPerfectPositive() {
		let x = SimulationInput(name: "X", distribution: DistributionNormal(0.0, 1.0))
		let y = SimulationInput(name: "Y", distribution: DistributionNormal(0.0, 1.0))
		let corr = [
			[1.0, 1.0],
			[1.0, 1.0]
		]
		let sim = MonteCarloSimulation()
		#expect(throws: SimulationError.self) {
			_ = try sim.runCorrelated(inputs: [x, y], correlationMatrix: corr, iterations: 1000) { samples in
				samples[0] + samples[1]
			}
		}
	}
}

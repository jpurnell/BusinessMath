//
//  SimulationInputTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("SimulationInput Tests")
struct SimulationInputTests {

	@Test("SimulationInput initialization with DistributionRandom conforming type - Normal")
	func simulationInputWithNormalDistribution() {
		// Create a normal distribution
		let normalDist = DistributionNormal(100.0, 15.0)

		// Create SimulationInput from distribution
		let input = SimulationInput(name: "Revenue", distribution: normalDist)

		#expect(input.name == "Revenue", "Name should be 'Revenue'")

		// Sample from the input and verify it produces reasonable values
		let samples = (0..<1_000).map { _ in input.sample() }
		let mean = samples.reduce(0.0, +) / Double(samples.count)
		#expect(mean > 90.0 && mean < 110.0, "Mean should be near 100")
	}

	@Test("SimulationInput initialization with DistributionRandom conforming type - Uniform")
	func simulationInputWithUniformDistribution() {
		// Create a uniform distribution
		let uniformDist = DistributionUniform(0.0, 100.0)

		// Create SimulationInput from distribution
		let input = SimulationInput(name: "CostFactor", distribution: uniformDist)

		#expect(input.name == "CostFactor")

		// Sample and verify values are within bounds
		let samples = (0..<500).map { _ in input.sample() }
		for value in samples {
			#expect(value >= 0.0 && value <= 100.0, "Value should be in [0, 100]")
		}
	}

	@Test("SimulationInput initialization with DistributionRandom conforming type - Weibull")
	func simulationInputWithWeibullDistribution() {
		// Create a Weibull distribution
		let weibullDist = DistributionWeibull(shape: 2.0, scale: 100.0)

		// Create SimulationInput from distribution
		let input = SimulationInput(name: "TimeToFailure", distribution: weibullDist)

		#expect(input.name == "TimeToFailure")

		// Sample and verify values are non-negative
		let samples = (0..<500).map { _ in input.sample() }
		for value in samples {
			#expect(value >= 0.0, "Weibull values should be non-negative")
		}
	}

	@Test("SimulationInput initialization with custom closure")
	func simulationInputWithCustomClosure() {
		// Create a custom sampling function (e.g., always returns 42)
		let customSampler: @Sendable () -> Double = {
			return 42.0
		}

		let input = SimulationInput(name: "ConstantValue", sampler: customSampler)

		#expect(input.name == "ConstantValue")

		// Verify the custom sampler works
		let samples = (0..<100).map { _ in input.sample() }
		for value in samples {
			#expect(value == 42.0, "Custom sampler should return 42.0")
		}
	}

	@Test("SimulationInput with custom closure - random uniform")
	func simulationInputWithCustomUniform() {
		// Create a custom uniform sampler using Double.random
		let customSampler: @Sendable () -> Double = {
			return Double.random(in: 10.0...20.0)
		}

		let input = SimulationInput(name: "CustomRange", sampler: customSampler)

		// Verify samples are within the expected range
		let samples = (0..<1_000).map { _ in input.sample() }
		for value in samples {
			#expect(value >= 10.0 && value <= 20.0, "Value should be in [10, 20]")
		}
	}

	@Test("SimulationInput with metadata")
	func simulationInputWithMetadata() {
		let normalDist = DistributionNormal(50.0, 5.0)
		let metadata = ["unit": "USD", "description": "Monthly revenue", "category": "financial"]

		let input = SimulationInput(
			name: "MonthlyRevenue",
			distribution: normalDist,
			metadata: metadata
		)

		#expect(input.name == "MonthlyRevenue")
		#expect(input.metadata["unit"] == "USD")
		#expect(input.metadata["description"] == "Monthly revenue")
		#expect(input.metadata["category"] == "financial")
	}

	@Test("SimulationInput metadata is optional")
	func simulationInputOptionalMetadata() {
		let uniformDist = DistributionUniform(1.0, 10.0)

		// Create input without metadata
		let input = SimulationInput(name: "SimpleInput", distribution: uniformDist)

		#expect(input.metadata.isEmpty, "Metadata should be empty by default")
	}

	@Test("SimulationInput with triangular distribution")
	func simulationInputWithTriangularDistribution() {
		// Create a triangular distribution
		let triangularDist = DistributionTriangular(low: 10.0, high: 20.0, base: 15.0)

		let input = SimulationInput(name: "ProjectEstimate", distribution: triangularDist)

		// Sample and verify values are within bounds
		let samples = (0..<1_000).map { _ in input.sample() }
		for value in samples {
			#expect(value >= 10.0 && value <= 20.0, "Triangular values should be in [10, 20]")
		}

		// Most values should be near the mode
		let mean = samples.reduce(0.0, +) / Double(samples.count)
		#expect(mean > 13.0 && mean < 17.0, "Mean should be near mode (15)")
	}

	@Test("SimulationInput Sendable conformance")
	func simulationInputSendableConformance() {
		// This test verifies that SimulationInput can be used in concurrent contexts
		let normalDist = DistributionNormal(100.0, 10.0)
		let input = SimulationInput(name: "ConcurrentTest", distribution: normalDist)

		// Use in a concurrent context (Task)
		Task {
			let value = input.sample()
			#expect(value > 0.0, "Should be able to sample in concurrent context")
		}
	}

	@Test("SimulationInput multiple samples are different")
	func simulationInputMultipleSamplesAreDifferent() {
		let uniformDist = DistributionUniform(0.0, 1000.0)
		let input = SimulationInput(name: "RandomValues", distribution: uniformDist)

		// Generate multiple samples and verify they're not all identical
		let samples = (0..<100).map { _ in input.sample() }
		let uniqueValues = Set(samples)

		#expect(uniqueValues.count > 50, "Should have many unique values from random distribution")
	}

	@Test("SimulationInput with complex custom logic")
	func simulationInputWithComplexCustomLogic() {
		// Create a custom sampler with complex logic (e.g., bimodal distribution)
		let customSampler: @Sendable () -> Double = {
			// 50% chance of sampling from N(20, 2) or N(80, 2)
			if Double.random(in: 0...1) < 0.5 {
				return distributionNormal(mean: 20.0, stdDev: 2.0)
			} else {
				return distributionNormal(mean: 80.0, stdDev: 2.0)
			}
		}

		let input = SimulationInput(name: "BimodalDist", sampler: customSampler)

		// Sample and verify bimodal behavior
		let samples = (0..<2_000).map { _ in input.sample() }
		let mean = samples.reduce(0.0, +) / Double(samples.count)

		// Mean should be around 50 (midpoint of 20 and 80)
		#expect(mean > 45.0 && mean < 55.0, "Bimodal distribution mean should be ~50")
	}

	@Test("SimulationInput integration with multiple distribution types")
	func simulationInputMultipleDistributionTypes() {
		// Create inputs from different distribution types
		let normalInput = SimulationInput(
			name: "Normal",
			distribution: DistributionNormal(100.0, 15.0)
		)

		let uniformInput = SimulationInput(
			name: "Uniform",
			distribution: DistributionUniform(50.0, 150.0)
		)

		let weibullInput = SimulationInput(
			name: "Weibull",
			distribution: DistributionWeibull(shape: 1.5, scale: 100.0)
		)

		// Verify each input can be sampled
		let normalSample = normalInput.sample()
		let uniformSample = uniformInput.sample()
		let weibullSample = weibullInput.sample()

		#expect(normalSample > 0.0)
		#expect(uniformSample >= 50.0 && uniformSample <= 150.0)
		#expect(weibullSample >= 0.0)
	}

	@Test("SimulationInput in array for multi-variable simulation")
	func simulationInputInArray() {
		// Create multiple inputs that could be used in a Monte Carlo simulation
		let inputs: [SimulationInput] = [
			SimulationInput(name: "Revenue", distribution: DistributionNormal(1_000_000.0, 100_000.0)),
			SimulationInput(name: "Costs", distribution: DistributionNormal(600_000.0, 50_000.0)),
			SimulationInput(name: "GrowthRate", distribution: DistributionUniform(0.05, 0.15))
		]

		#expect(inputs.count == 3)

		// Verify each input can be sampled
		for input in inputs {
			let sample = input.sample()
			#expect(sample.isFinite, "Sample should be a finite number")
		}
	}
}

//
//  MultiVariableMonteCarloTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
import OSLog

@testable import BusinessMath

@Suite("Multi-Variable Monte Carlo Tests", .serialized)
struct MultiVariableMonteCarloTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.MultiVariableMonteCarloTests", category: #function)

	@Test("Multi-variable simulation with independent variables")
	func independentVariables() throws {
		// Test with two independent normal variables
		let input1 = SimulationInput(
			name: "Revenue",
			distribution: DistributionNormal(1000.0, 100.0)
		)

		let input2 = SimulationInput(
			name: "Cost",
			distribution: DistributionNormal(600.0, 50.0)
		)

		// No correlation (identity matrix)
		let correlationMatrix = [
			[1.0, 0.0],
			[0.0, 1.0]
		]

		let simulation = MonteCarloSimulation()
		let results = try simulation.runCorrelated(
			inputs: [input1, input2],
			correlationMatrix: correlationMatrix,
			iterations: 5000
		) { samples in
			// Profit = Revenue - Cost
			return samples[0] - samples[1]
		}

		// Mean profit should be approximately 1000 - 600 = 400
		#expect(abs(results.statistics.mean - 400.0) < 20.0, "Mean profit should be close to 400")

		// For independent variables: Var(Revenue - Cost) = Var(Revenue) + Var(Cost)
		// = 100² + 50² = 10000 + 2500 = 12500
		// StdDev = √12500 ≈ 111.8
		let expectedStdDev = sqrt(100.0 * 100.0 + 50.0 * 50.0)
		#expect(abs(results.statistics.stdDev - expectedStdDev) < 15.0, "StdDev should match independent sum")
	}

	@Test("Multi-variable simulation with positive correlation")
	func positiveCorrelation() throws {
		// Two positively correlated variables
		let input1 = SimulationInput(
			name: "Variable1",
			distribution: DistributionNormal(100.0, 10.0)
		)

		let input2 = SimulationInput(
			name: "Variable2",
			distribution: DistributionNormal(200.0, 20.0)
		)

		// Strong positive correlation
		let correlationMatrix = [
			[1.0, 0.8],
			[0.8, 1.0]
		]

		let simulation = MonteCarloSimulation()

		let results = try simulation.runCorrelated(
			inputs: [input1, input2],
			correlationMatrix: correlationMatrix,
			iterations: 5000
		) { samples in
			return samples[0] + samples[1]
		}

		// Sum should have mean ≈ 300
		#expect(abs(results.statistics.mean - 300.0) < 10.0, "Sum mean should be close to 300")

		// With positive correlation, Var(X+Y) = Var(X) + Var(Y) + 2×Cov(X,Y)
		// = 100 + 400 + 2×0.8×10×20 = 100 + 400 + 320 = 820
		// StdDev = sqrt(820) ≈ 28.6
		// Verify variance reflects positive correlation
		#expect(results.statistics.stdDev > 25.0 && results.statistics.stdDev < 32.0,
				"StdDev should reflect positive correlation")
	}

	@Test("Multi-variable simulation with negative correlation")
	func negativeCorrelation() throws {
		let input1 = SimulationInput(
			name: "Sales",
			distribution: DistributionNormal(500.0, 50.0)
		)

		let input2 = SimulationInput(
			name: "Price",
			distribution: DistributionNormal(10.0, 1.0)
		)

		// Negative correlation (price increases as sales decrease)
		let correlationMatrix = [
			[1.0, -0.6],
			[-0.6, 1.0]
		]

		let simulation = MonteCarloSimulation()

		let results = try simulation.runCorrelated(
			inputs: [input1, input2],
			correlationMatrix: correlationMatrix,
			iterations: 5000
		) { samples in
			return samples[0] * samples[1]  // Revenue = Sales × Price
		}

		// Revenue should have mean approximately 500 × 10 = 5000
		// (for uncorrelated normals, E[XY] = E[X]E[Y])
		#expect(abs(results.statistics.mean - 5000.0) < 300.0, "Mean revenue should be approximately 5000")

		// The simulation should complete successfully with correlated variables
		#expect(results.values.count == 5000, "Should have 5000 iterations")
	}

	@Test("Multi-variable simulation with three correlated variables")
	func threeVariables() throws {
		let input1 = SimulationInput(
			name: "Variable1",
			distribution: DistributionNormal(10.0, 1.0)
		)

		let input2 = SimulationInput(
			name: "Variable2",
			distribution: DistributionNormal(20.0, 2.0)
		)

		let input3 = SimulationInput(
			name: "Variable3",
			distribution: DistributionNormal(30.0, 3.0)
		)

		// Correlation matrix with varying correlations
		let correlationMatrix = [
			[1.0, 0.5, 0.3],
			[0.5, 1.0, 0.4],
			[0.3, 0.4, 1.0]
		]

		let simulation = MonteCarloSimulation()

		let results = try simulation.runCorrelated(
			inputs: [input1, input2, input3],
			correlationMatrix: correlationMatrix,
			iterations: 5000
		) { samples in
			// Sum all three
			return samples[0] + samples[1] + samples[2]
		}

		// Sum should have mean ≈ 10 + 20 + 30 = 60
		#expect(abs(results.statistics.mean - 60.0) < 5.0, "Sum mean should be close to 60")
		#expect(results.values.count == 5000, "Should have 5000 samples")
	}

	@Test("Multi-variable simulation rejects mismatched dimensions")
	func rejectMismatchedDimensions() {
		let input1 = SimulationInput(
			name: "Var1",
			distribution: DistributionNormal(100.0, 10.0)
		)

		let input2 = SimulationInput(
			name: "Var2",
			distribution: DistributionNormal(200.0, 20.0)
		)

		let input3 = SimulationInput(
			name: "Var3",
			distribution: DistributionNormal(300.0, 30.0)
		)

		// 2x2 correlation matrix but 3 inputs
		let correlationMatrix = [
			[1.0, 0.5],
			[0.5, 1.0]
		]

		let simulation = MonteCarloSimulation()

		#expect(throws: SimulationError.self) {
			_ = try simulation.runCorrelated(
				inputs: [input1, input2, input3],
				correlationMatrix: correlationMatrix,
				iterations: 1000
			) { samples in
				return samples.reduce(0, +)
			}
		}
	}

	@Test("Multi-variable simulation rejects invalid correlation matrix")
	func rejectInvalidCorrelationMatrix() {
		let input1 = SimulationInput(
			name: "Var1",
			distribution: DistributionNormal(100.0, 10.0)
		)

		let input2 = SimulationInput(
			name: "Var2",
			distribution: DistributionNormal(200.0, 20.0)
		)

		// Invalid correlation matrix (not symmetric)
		let invalidMatrix = [
			[1.0, 0.5],
			[0.3, 1.0]  // Should be 0.5
		]

		let simulation = MonteCarloSimulation()

		#expect(throws: SimulationError.self) {
			_ = try simulation.runCorrelated(
				inputs: [input1, input2],
				correlationMatrix: invalidMatrix,
				iterations: 1000
			) { samples in
				return samples[0] + samples[1]
			}
		}
	}

	@Test("Multi-variable simulation with uniform distributions")
	func uniformDistributions() throws {
		let input1 = SimulationInput(
			name: "UniformVar1",
			distribution: DistributionUniform(0.0, 100.0)
		)

		let input2 = SimulationInput(
			name: "UniformVar2",
			distribution: DistributionUniform(0.0, 50.0)
		)

		// Note: Correlation for uniform distributions is more complex
		// We convert to normal space for correlation
		let correlationMatrix = [
			[1.0, 0.0],
			[0.0, 1.0]
		]

		let simulation = MonteCarloSimulation()

		let results = try simulation.runCorrelated(
			inputs: [input1, input2],
			correlationMatrix: correlationMatrix,
			iterations: 5000
		) { samples in
			return samples[0] + samples[1]
		}

		// Means should be approximately 50 + 25 = 75
		#expect(abs(results.statistics.mean - 75.0) < 10.0, "Sum mean should be close to 75")
		#expect(results.values.count == 5000, "Should have 5000 samples")
	}

	@Test("Multi-variable simulation with mixed distributions")
	func mixedDistributions() throws {
		let input1 = SimulationInput(
			name: "NormalVar",
			distribution: DistributionNormal(100.0, 10.0)
		)

		let input2 = SimulationInput(
			name: "TriangularVar",
			distribution: DistributionTriangular(low: 50.0, high: 100.0, base: 75.0)
		)

		// Identity correlation (independent)
		let correlationMatrix = [
			[1.0, 0.0],
			[0.0, 1.0]
		]

		let simulation = MonteCarloSimulation()

		let results = try simulation.runCorrelated(
			inputs: [input1, input2],
			correlationMatrix: correlationMatrix,
			iterations: 5000
		) { samples in
			return samples[0] + samples[1]
		}

		// Normal mean ≈ 100, Triangular mean ≈ 75, Sum ≈ 175
		#expect(abs(results.statistics.mean - 175.0) < 15.0, "Sum mean should be close to 175")
	}

	@Test("Multi-variable simulation produces different results with different correlations")
	func differentCorrelationsDifferentResults() throws {
		let input1 = SimulationInput(
			name: "Var1",
			distribution: DistributionNormal(0.0, 10.0)
		)

		let input2 = SimulationInput(
			name: "Var2",
			distribution: DistributionNormal(0.0, 10.0)
		)

		let simulation = MonteCarloSimulation()

		// Independent variables
		let resultsIndependent = try simulation.runCorrelated(
			inputs: [input1, input2],
			correlationMatrix: [[1.0, 0.0], [0.0, 1.0]],
			iterations: 5000
		) { samples in
			return samples[0] - samples[1]
		}

		// Positively correlated variables
		let resultsCorrelated = try simulation.runCorrelated(
			inputs: [input1, input2],
			correlationMatrix: [[1.0, 0.9], [0.9, 1.0]],
			iterations: 5000
		) { samples in
			return samples[0] - samples[1]
		}

		// With positive correlation, variance of difference should be lower
		// Var(X-Y) = Var(X) + Var(Y) - 2×Cov(X,Y)
		// For ρ=0: Var(X-Y) = 100 + 100 = 200, StdDev ≈ 14.14
		// For ρ=0.9: Var(X-Y) = 100 + 100 - 2×0.9×100 = 20, StdDev ≈ 4.47

		#expect(resultsCorrelated.statistics.stdDev < resultsIndependent.statistics.stdDev,
				"Correlated variables should have lower variance in difference")
	}

	@Test("Multi-variable simulation maintains sample count")
	func maintainSampleCount() throws {
		let input1 = SimulationInput(
			name: "Var1",
			distribution: DistributionNormal(100.0, 10.0)
		)

		let input2 = SimulationInput(
			name: "Var2",
			distribution: DistributionNormal(200.0, 20.0)
		)

		let correlationMatrix = [
			[1.0, 0.5],
			[0.5, 1.0]
		]

		let simulation = MonteCarloSimulation()
		let iterations = 10000

		let results = try simulation.runCorrelated(
			inputs: [input1, input2],
			correlationMatrix: correlationMatrix,
			iterations: iterations
		) { samples in
			return samples[0] + samples[1]
		}

		#expect(results.values.count == iterations, "Should have exactly \(iterations) samples")
	}

	@Test("Multi-variable simulation with four variables")
	func fourVariables() throws {
		let inputs = [
			SimulationInput(name: "Var1", distribution: DistributionNormal(10.0, 1.0)),
			SimulationInput(name: "Var2", distribution: DistributionNormal(20.0, 2.0)),
			SimulationInput(name: "Var3", distribution: DistributionNormal(30.0, 3.0)),
			SimulationInput(name: "Var4", distribution: DistributionNormal(40.0, 4.0))
		]

		// 4x4 correlation matrix
		let correlationMatrix = [
			[1.0, 0.7, 0.5, 0.3],
			[0.7, 1.0, 0.6, 0.4],
			[0.5, 0.6, 1.0, 0.5],
			[0.3, 0.4, 0.5, 1.0]
		]

		let simulation = MonteCarloSimulation()

		let results = try simulation.runCorrelated(
			inputs: inputs,
			correlationMatrix: correlationMatrix,
			iterations: 5000
		) { samples in
			// Sum all four
			return samples.reduce(0, +)
		}

		// Sum should have mean ≈ 10 + 20 + 30 + 40 = 100
		#expect(abs(results.statistics.mean - 100.0) < 10.0, "Sum mean should be close to 100")
	}

	@Test("Multi-variable simulation calculates correct percentiles")
	func correctPercentiles() throws {
		let input1 = SimulationInput(
			name: "Var1",
			distribution: DistributionNormal(100.0, 15.0)
		)

		let input2 = SimulationInput(
			name: "Var2",
			distribution: DistributionNormal(200.0, 30.0)
		)

		let correlationMatrix = [
			[1.0, 0.0],
			[0.0, 1.0]
		]

		let simulation = MonteCarloSimulation()

		let results = try simulation.runCorrelated(
			inputs: [input1, input2],
			correlationMatrix: correlationMatrix,
			iterations: 10000
		) { samples in
			return samples[0] + samples[1]
		}

		// Check percentiles are ordered
		#expect(results.percentiles.p5 < results.percentiles.p25, "P5 < P25")
		#expect(results.percentiles.p25 < results.percentiles.p50, "P25 < P50")
		#expect(results.percentiles.p50 < results.percentiles.p75, "P50 < P75")
		#expect(results.percentiles.p75 < results.percentiles.p95, "P75 < P95")

		// Median should be close to mean for sum of normals
		#expect(abs(results.percentiles.p50 - results.statistics.mean) < 20.0, "Median should be close to mean")
	}
}

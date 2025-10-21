//
//  RiskMetricsTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("RiskMetrics Tests")
struct RiskMetricsTests {

	// Helper to generate deterministic normal samples
	static func generateNormalSamples(count: Int, mean: Double, stdDev: Double, seed: UInt64 = 98765) -> [Double] {
		let rng = DistributionSeedingTests.SeededRNG(seed: seed)
		var samples: [Double] = []

		for _ in 0..<count {
			let u1 = rng.next()
			let u2 = rng.next()
			let sample: Double = distributionNormal(mean: mean, stdDev: stdDev, u1, u2)
			samples.append(sample)
		}

		return samples
	}

	// Helper to generate deterministic uniform samples
	static func generateUniformSamples(count: Int, min: Double, max: Double, seed: UInt64 = 98765) -> [Double] {
		let rng = DistributionSeedingTests.SeededRNG(seed: seed)
		var samples: [Double] = []

		for _ in 0..<count {
			let u = rng.next()
			let sample: Double = distributionUniform(min: min, max: max, u)
			samples.append(sample)
		}

		return samples
	}

	@Test("VaR calculation at 95% confidence level")
	func varCalculation95() {
		// Normal distribution: N(0, 1)
		// 95% VaR should be approximately -1.645 (5th percentile)
		let values = Self.generateNormalSamples(count: 10_000, mean: 0.0, stdDev: 1.0)

		let results = SimulationResults(values: values)
		let var95 = results.valueAtRisk(confidenceLevel: 0.95)

		// VaR at 95% confidence should be close to -1.645
		#expect(var95 > -1.8 && var95 < -1.5, "95% VaR should be approximately -1.645")
		#expect(var95 < 0.0, "VaR should be negative for losses")
	}

	@Test("VaR calculation at 99% confidence level")
	func varCalculation99() {
		// Normal distribution: N(0, 1)
		// 99% VaR should be approximately -2.326 (1st percentile)
		let values = Self.generateNormalSamples(count: 10_000, mean: 0.0, stdDev: 1.0)

		let results = SimulationResults(values: values)
		let var99 = results.valueAtRisk(confidenceLevel: 0.99)

		// VaR at 99% confidence should be close to -2.326
		#expect(var99 > -2.5 && var99 < -2.1, "99% VaR should be approximately -2.326")
		#expect(var99 < 0.0, "VaR should be negative for losses")
	}

	@Test("VaR increases with confidence level")
	func varIncreasesWithConfidence() {
		let values = Self.generateNormalSamples(count: 5_000, mean: 0.0, stdDev: 1.0)

		let results = SimulationResults(values: values)

		let var90 = results.valueAtRisk(confidenceLevel: 0.90)
		let var95 = results.valueAtRisk(confidenceLevel: 0.95)
		let var99 = results.valueAtRisk(confidenceLevel: 0.99)

		// Higher confidence = more extreme VaR (more negative for losses)
		#expect(var99 < var95, "99% VaR should be more extreme than 95% VaR")
		#expect(var95 < var90, "95% VaR should be more extreme than 90% VaR")
	}

	@Test("CVaR calculation at 95% confidence level")
	func cvarCalculation95() {
		// Normal distribution: N(0, 1)
		// 95% CVaR should be approximately -2.06 (mean of tail beyond 5th percentile)
		let values = Self.generateNormalSamples(count: 10_000, mean: 0.0, stdDev: 1.0)

		let results = SimulationResults(values: values)
		let cvar95 = results.conditionalValueAtRisk(confidenceLevel: 0.95)

		// CVaR at 95% confidence should be close to -2.06
		#expect(cvar95 > -2.3 && cvar95 < -1.8, "95% CVaR should be approximately -2.06")
		#expect(cvar95 < 0.0, "CVaR should be negative for losses")
	}

	@Test("CVaR calculation at 99% confidence level")
	func cvarCalculation99() {
		// Normal distribution: N(0, 1)
		// 99% CVaR should be approximately -2.665 (mean of tail beyond 1st percentile)
		let values = Self.generateNormalSamples(count: 10_000, mean: 0.0, stdDev: 1.0)

		let results = SimulationResults(values: values)
		let cvar99 = results.conditionalValueAtRisk(confidenceLevel: 0.99)

		// CVaR at 99% confidence should be close to -2.665
		#expect(cvar99 > -2.9 && cvar99 < -2.4, "99% CVaR should be approximately -2.665")
		#expect(cvar99 < 0.0, "CVaR should be negative for losses")
	}

	@Test("CVaR is always more extreme than VaR")
	func cvarMoreExtremeThanVar() {
		let values = Self.generateNormalSamples(count: 5_000, mean: 0.0, stdDev: 1.0)

		let results = SimulationResults(values: values)

		for confidenceLevel in [0.90, 0.95, 0.99] {
			let var_cl = results.valueAtRisk(confidenceLevel: confidenceLevel)
			let cvar_cl = results.conditionalValueAtRisk(confidenceLevel: confidenceLevel)

			// CVaR should always be more extreme (more negative) than VaR
			#expect(cvar_cl <= var_cl, "CVaR should be <= VaR at \(confidenceLevel * 100)% confidence")
		}
	}

	@Test("VaR and CVaR with positive returns")
	func varCvarPositiveReturns() {
		// All positive values: simulate profitable portfolio
		let values = Self.generateNormalSamples(count: 5_000, mean: 1_000_000.0, stdDev: 50_000.0)

		let results = SimulationResults(values: values)

		let var95 = results.valueAtRisk(confidenceLevel: 0.95)
		let cvar95 = results.conditionalValueAtRisk(confidenceLevel: 0.95)

		// Even with positive mean, worst cases should be lower values
		#expect(var95 < results.statistics.mean, "VaR should be less than mean")
		#expect(cvar95 < var95, "CVaR should be less than VaR")

		// But both should still be reasonably positive given the distribution
		#expect(var95 > 800_000, "VaR should be positive for profitable portfolio")
	}

	@Test("VaR and CVaR with loss scenario")
	func varCvarLossScenario() {
		// Model: Profit = Revenue - Costs (can be negative)
		var simulation = MonteCarloSimulation(iterations: 5_000) { inputs in
			let revenue = inputs[0]
			let costs = inputs[1]
			return revenue - costs
		}

		simulation.addInput(SimulationInput(name: "Revenue", distribution: DistributionNormal(500_000.0, 100_000.0)))
		simulation.addInput(SimulationInput(name: "Costs", distribution: DistributionNormal(600_000.0, 80_000.0)))

		let results = try! simulation.run()

		let var95 = results.valueAtRisk(confidenceLevel: 0.95)
		let cvar95 = results.conditionalValueAtRisk(confidenceLevel: 0.95)

		// Expected loss scenario: mean ~ -100,000
		#expect(var95 < results.statistics.mean, "VaR should be more extreme than mean")
		#expect(cvar95 < var95, "CVaR should be more extreme than VaR")

		// Both should be significantly negative
		#expect(var95 < -150_000, "VaR should indicate significant loss potential")
		#expect(cvar95 < var95, "CVaR should be even more extreme")
	}

	@Test("VaR and CVaR with uniform distribution")
	func varCvarUniform() {
		// Uniform distribution: easier to validate
		// Uniform(0, 100): 95% VaR = 5, CVaR = 2.5 (mean of [0, 5])
		let values = Self.generateUniformSamples(count: 10_000, min: 0.0, max: 100.0)

		let results = SimulationResults(values: values)

		let var95 = results.valueAtRisk(confidenceLevel: 0.95)
		let cvar95 = results.conditionalValueAtRisk(confidenceLevel: 0.95)

		// 5th percentile of Uniform(0, 100) = 5
		#expect(var95 > 3.0 && var95 < 7.0, "95% VaR should be approximately 5")

		// Mean of lowest 5% should be around 2.5
		#expect(cvar95 > 1.5 && cvar95 < 4.0, "95% CVaR should be approximately 2.5")

		#expect(cvar95 < var95, "CVaR should be less than VaR")
	}

	@Test("VaR at extreme confidence levels")
	func varExtremeConfidence() {
		let values = Self.generateNormalSamples(count: 10_000, mean: 0.0, stdDev: 1.0)

		let results = SimulationResults(values: values)

		// Test various confidence levels
		let var50 = results.valueAtRisk(confidenceLevel: 0.50)  // Median
		let var99_9 = results.valueAtRisk(confidenceLevel: 0.999)  // Extreme

		// 50% VaR should be close to median (0 for standard normal)
		#expect(var50 > -0.2 && var50 < 0.2, "50% VaR should be near 0 (median)")

		// 99.9% VaR should be very extreme
		#expect(var99_9 < -3.0, "99.9% VaR should be very extreme")
	}

	@Test("CVaR approaches minimum value at high confidence")
	func cvarApproachesMinimum() {
		let values = Self.generateNormalSamples(count: 5_000, mean: 100.0, stdDev: 10.0)

		let results = SimulationResults(values: values)

		let cvar999 = results.conditionalValueAtRisk(confidenceLevel: 0.999)

		// At 99.9% confidence, CVaR should be very close to minimum
		let minValue = results.statistics.min

		// CVaR should be between minimum and reasonably close to it
		// Using 10.0 tolerance to account for statistical variability in random samples
		#expect(cvar999 >= minValue, "CVaR cannot be less than minimum")
		#expect(cvar999 < minValue + 10.0, "CVaR at 99.9% should be close to minimum")
	}

	@Test("VaR and CVaR with single value")
	func varCvarSingleValue() {
		let values = [42.0]
		let results = SimulationResults(values: values)

		let var95 = results.valueAtRisk(confidenceLevel: 0.95)
		let cvar95 = results.conditionalValueAtRisk(confidenceLevel: 0.95)

		// With single value, all risk metrics equal that value
		#expect(var95 == 42.0, "VaR of single value should be that value")
		#expect(cvar95 == 42.0, "CVaR of single value should be that value")
	}

	@Test("VaR and CVaR with two values")
	func varCvarTwoValues() {
		let values = [10.0, 90.0]
		let results = SimulationResults(values: values)

		let var95 = results.valueAtRisk(confidenceLevel: 0.95)
		let cvar95 = results.conditionalValueAtRisk(confidenceLevel: 0.95)

		// 95% VaR with 2 values: 5th percentile interpolation
		#expect(var95 >= 10.0 && var95 <= 90.0, "VaR should be between min and max")

		// CVaR should be close to minimum
		#expect(cvar95 >= 10.0 && cvar95 <= var95, "CVaR should be >= min and <= VaR")
	}

	@Test("Financial portfolio risk analysis integration")
	func financialPortfolioRisk() {
		// Realistic financial portfolio scenario
		var simulation = MonteCarloSimulation(iterations: 10_000) { inputs in
			let stockReturn = inputs[0]
			let bondReturn = inputs[1]
			let portfolioValue = 1_000_000.0

			// 60/40 stock/bond portfolio
			let stockWeight = 0.6
			let bondWeight = 0.4

			let portfolioReturn = stockWeight * stockReturn + bondWeight * bondReturn
			return portfolioValue * portfolioReturn
		}

		// Stock: higher return, higher risk (12% mean, 20% volatility)
		simulation.addInput(SimulationInput(name: "StockReturn", distribution: DistributionNormal(0.12, 0.20)))

		// Bond: lower return, lower risk (4% mean, 5% volatility)
		simulation.addInput(SimulationInput(name: "BondReturn", distribution: DistributionNormal(0.04, 0.05)))

		let results = try! simulation.run()

		let var95 = results.valueAtRisk(confidenceLevel: 0.95)
		let cvar95 = results.conditionalValueAtRisk(confidenceLevel: 0.95)

		// Portfolio should have positive expected return
		#expect(results.statistics.mean > 0.0, "Expected positive portfolio return")

		// But VaR should show downside risk
		#expect(var95 < results.statistics.mean, "VaR should be less than mean return")

		// CVaR should be even worse
		#expect(cvar95 < var95, "CVaR should be more extreme than VaR")

		// Verify risk metrics are reasonable for this portfolio
		// 95% VaR should be negative (loss) with these volatilities
		#expect(var95 < 0.0, "95% VaR should indicate potential losses")
	}

	@Test("VaR and CVaR consistency across runs")
	func varCvarConsistency() {
		// Run simulation twice with SAME seed, verify IDENTICAL results
		let values1 = Self.generateNormalSamples(count: 10_000, mean: 100.0, stdDev: 15.0, seed: 12345)
		let values2 = Self.generateNormalSamples(count: 10_000, mean: 100.0, stdDev: 15.0, seed: 12345)

		let results1 = SimulationResults(values: values1)
		let results2 = SimulationResults(values: values2)

		let var95_1 = results1.valueAtRisk(confidenceLevel: 0.95)
		let var95_2 = results2.valueAtRisk(confidenceLevel: 0.95)

		let cvar95_1 = results1.conditionalValueAtRisk(confidenceLevel: 0.95)
		let cvar95_2 = results2.conditionalValueAtRisk(confidenceLevel: 0.95)

		// With deterministic seeding, results should be EXACTLY identical
		#expect(var95_1 == var95_2, "VaR should be exactly identical with same seed")
		#expect(cvar95_1 == cvar95_2, "CVaR should be exactly identical with same seed")
		#expect(values1 == values2, "Sample arrays should be exactly identical with same seed")
	}
}

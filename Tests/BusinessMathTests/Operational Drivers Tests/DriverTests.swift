//
//  DriverTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import TestSupport  // Cross-platform math functions
import Testing
@testable import BusinessMath

@Suite("Operational Driver Tests")
struct DriverTests {

	// MARK: - DeterministicDriver Tests

	@Test("DeterministicDriver returns fixed value")
	func deterministicFixedValue() {
		let driver = DeterministicDriver(name: "Rent", value: 10_000.0)

		let period1 = Period.month(year: 2025, month: 1)
		let period2 = Period.month(year: 2025, month: 2)

		#expect(driver.sample(for: period1) == 10_000.0)
		#expect(driver.sample(for: period2) == 10_000.0)
		#expect(driver.name == "Rent")
	}

	@Test("DeterministicDriver returns same value multiple times")
	func deterministicConsistency() {
		let driver = DeterministicDriver(name: "Price", value: 100.0)
		let period = Period.quarter(year: 2025, quarter: 1)

		let samples = (0..<100).map { _ in driver.sample(for: period) }

		// All samples should be identical
		for sample in samples {
			#expect(sample == 100.0)
		}
	}

	// MARK: - ProbabilisticDriver Tests

	@Test("ProbabilisticDriver samples from distribution")
	func probabilisticSampling() {
		let driver = ProbabilisticDriver<Double>(
			name: "Sales",
			distribution: DistributionNormal(1000.0, 100.0)
		)

		let period = Period.month(year: 2025, month: 1)
		var samples: [Double] = []

		for _ in 0..<1000 {
			samples.append(driver.sample(for: period))
		}

		// Check empirical statistics
		let mean = samples.reduce(0.0, +) / Double(samples.count)
		let variance = samples.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(samples.count)
		let stdDev = sqrt(variance)

		// Should be close to distribution parameters
		#expect(abs(mean - 1000.0) < 50.0, "Mean should be close to 1000")
		#expect(abs(stdDev - 100.0) < 20.0, "StdDev should be close to 100")
	}

	@Test("ProbabilisticDriver generates different samples")
	func probabilisticVariability() {
		let driver = ProbabilisticDriver<Double>(
			name: "Random",
			distribution: DistributionNormal(0.0, 1.0)
		)

		let period = Period.month(year: 2025, month: 1)

		let sample1 = driver.sample(for: period)
		let sample2 = driver.sample(for: period)
		let sample3 = driver.sample(for: period)

		// Samples should differ (with very high probability)
		#expect(sample1 != sample2 || sample2 != sample3)
	}

	@Test("ProbabilisticDriver convenience initializers")
	func probabilisticConvenience() {
		let normal = ProbabilisticDriver<Double>.normal(name: "Normal", mean: 100.0, stdDev: 10.0)
		let triangular = ProbabilisticDriver<Double>.triangular(name: "Tri", low: 90.0, high: 110.0, base: 100.0)
		let uniform = ProbabilisticDriver<Double>.uniform(name: "Uniform", min: 90.0, max: 110.0)

		let period = Period.month(year: 2025, month: 1)

		// Just verify they work without error
		_ = normal.sample(for: period)
		_ = triangular.sample(for: period)
		_ = uniform.sample(for: period)

		#expect(normal.name == "Normal")
		#expect(triangular.name == "Tri")
		#expect(uniform.name == "Uniform")
	}

	// MARK: - ProductDriver Tests

	@Test("ProductDriver multiplies two deterministic drivers")
	func productDeterministic() {
		let quantity = DeterministicDriver(name: "Quantity", value: 100.0)
		let price = DeterministicDriver(name: "Price", value: 10.0)
		let revenue = ProductDriver(name: "Revenue", lhs: quantity, rhs: price)

		let period = Period.month(year: 2025, month: 1)

		#expect(revenue.sample(for: period) == 1000.0)
		#expect(revenue.name == "Revenue")
	}

	@Test("ProductDriver multiplies deterministic and probabilistic")
	func productMixed() {
		let fixedPrice = DeterministicDriver(name: "Price", value: 100.0)
		let uncertainVolume = ProbabilisticDriver<Double>.normal(name: "Volume", mean: 1000.0, stdDev: 100.0)
		let revenue = ProductDriver(name: "Revenue", lhs: fixedPrice, rhs: uncertainVolume)

		let period = Period.month(year: 2025, month: 1)
		var samples: [Double] = []

		for _ in 0..<1000 {
			samples.append(revenue.sample(for: period))
		}

		let mean = samples.reduce(0.0, +) / Double(samples.count)

		// Expected revenue ≈ 100 × 1000 = 100,000
		#expect(abs(mean - 100_000.0) < 5000.0)
	}

	@Test("ProductDriver with operator overloading")
	func productOperator() {
		let quantity = DeterministicDriver(name: "Qty", value: 50.0)
		let price = DeterministicDriver(name: "Price", value: 20.0)
		let revenue = quantity * price

		let period = Period.month(year: 2025, month: 1)

		#expect(revenue.sample(for: period) == 1000.0)
		#expect(revenue.name.contains("×") || revenue.name.contains("*"))
	}

	// MARK: - SumDriver Tests

	@Test("SumDriver adds two deterministic drivers")
	func sumDeterministic() {
		let fixed = DeterministicDriver(name: "Fixed", value: 10_000.0)
		let variable = DeterministicDriver(name: "Variable", value: 5_000.0)
		let total = SumDriver(name: "Total", lhs: fixed, rhs: variable)

		let period = Period.month(year: 2025, month: 1)

		#expect(total.sample(for: period) == 15_000.0)
		#expect(total.name == "Total")
	}

	@Test("SumDriver adds with operator overloading")
	func sumOperator() {
		let costA = DeterministicDriver(name: "Cost A", value: 1000.0)
		let costB = DeterministicDriver(name: "Cost B", value: 2000.0)
		let totalCost = costA + costB

		let period = Period.month(year: 2025, month: 1)

		#expect(totalCost.sample(for: period) == 3000.0)
	}

	@Test("SumDriver subtracts with operator overloading")
	func subtractOperator() {
		let revenue = DeterministicDriver(name: "Revenue", value: 100_000.0)
		let cost = DeterministicDriver(name: "Cost", value: 70_000.0)
		let profit = revenue - cost

		let period = Period.month(year: 2025, month: 1)

		#expect(profit.sample(for: period) == 30_000.0)
	}

	@Test("SumDriver adds probabilistic drivers")
	func sumProbabilistic() {
		let driver1 = ProbabilisticDriver<Double>.normal(name: "A", mean: 100.0, stdDev: 10.0)
		let driver2 = ProbabilisticDriver<Double>.normal(name: "B", mean: 200.0, stdDev: 20.0)
		let sum = driver1 + driver2

		let period = Period.month(year: 2025, month: 1)
		var samples: [Double] = []

		for _ in 0..<1000 {
			samples.append(sum.sample(for: period))
		}

		let mean = samples.reduce(0.0, +) / Double(samples.count)

		// Expected sum ≈ 100 + 200 = 300
		#expect(abs(mean - 300.0) < 30.0)
	}

	// MARK: - Composite Driver Tests

	@Test("Complex formula: Revenue = Quantity × Price")
	func complexRevenue() {
		let quantity = ProbabilisticDriver<Double>.normal(name: "Quantity", mean: 1000.0, stdDev: 100.0)
		let price = ProbabilisticDriver<Double>.triangular(name: "Price", low: 95.0, high: 105.0, base: 100.0)
		let revenue = quantity * price

		let period = Period.month(year: 2025, month: 1)
		var samples: [Double] = []

		for _ in 0..<10000 {
			samples.append(revenue.sample(for: period))
		}

		let mean = samples.reduce(0.0, +) / Double(samples.count)

		// Expected revenue ≈ 1000 × 100 = 100,000
		#expect(abs(mean - 100_000.0) < 5000.0)
	}

	@Test("Complex formula: Total Cost = Fixed + (Variable × Units)")
	func complexTotalCost() {
		let fixed = DeterministicDriver(name: "Fixed", value: 10_000.0)
		let variableCostPerUnit = DeterministicDriver(name: "Variable/Unit", value: 50.0)
		let units = ProbabilisticDriver<Double>.normal(name: "Units", mean: 1000.0, stdDev: 100.0)

		let variableCosts = variableCostPerUnit * units
		let totalCost = fixed + variableCosts

		let period = Period.month(year: 2025, month: 1)
		var samples: [Double] = []

		for _ in 0..<1000 {
			samples.append(totalCost.sample(for: period))
		}

		let mean = samples.reduce(0.0, +) / Double(samples.count)

		// Expected: 10,000 + (50 × 1000) = 60,000
		#expect(abs(mean - 60_000.0) < 3000.0)
	}

	@Test("Complex formula: Profit = Revenue - Cost")
	func complexProfit() {
		let revenue = ProbabilisticDriver<Double>.normal(name: "Revenue", mean: 100_000.0, stdDev: 10_000.0)
		let cost = ProbabilisticDriver<Double>.normal(name: "Cost", mean: 70_000.0, stdDev: 7_000.0)
		let profit = revenue - cost

		let period = Period.month(year: 2025, month: 1)
		var samples: [Double] = []

		for _ in 0..<1000 {
			samples.append(profit.sample(for: period))
		}

		let mean = samples.reduce(0.0, +) / Double(samples.count)

		// Expected profit: 100,000 - 70,000 = 30,000
		#expect(abs(mean - 30_000.0) < 5000.0)
	}
}

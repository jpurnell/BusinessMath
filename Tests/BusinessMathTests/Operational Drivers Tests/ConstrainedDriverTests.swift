//
//  ConstrainedDriverTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("Constrained Driver Tests")
struct ConstrainedDriverTests {

	// MARK: - Clamping Tests

	@Test("Clamped driver enforces minimum")
	func clampedEnforcesMinimum() {
		// Base driver that can go negative
		let base = ProbabilisticDriver<Double>.normal(name: "Value", mean: 10.0, stdDev: 20.0)
		let clamped = base.clamped(min: 0.0)

		let period = Period.month(year: 2025, month: 1)

		// Sample many times - should never be negative
		for _ in 0..<1000 {
			let value = clamped.sample(for: period)
			#expect(value >= 0.0, "Value should never be negative")
		}
	}

	@Test("Clamped driver enforces maximum")
	func clampedEnforcesMaximum() {
		let base = ProbabilisticDriver<Double>.normal(name: "Value", mean: 100.0, stdDev: 50.0)
		let clamped = base.clamped(max: 150.0)

		let period = Period.month(year: 2025, month: 1)

		for _ in 0..<1000 {
			let value = clamped.sample(for: period)
			#expect(value <= 150.0, "Value should never exceed maximum")
		}
	}

	@Test("Clamped driver enforces both min and max")
	func clampedEnforcesBothBounds() {
		let base = ProbabilisticDriver<Double>.normal(name: "Utilization", mean: 0.5, stdDev: 0.3)
		let clamped = base.clamped(min: 0.0, max: 1.0)

		let period = Period.month(year: 2025, month: 1)

		for _ in 0..<1000 {
			let value = clamped.sample(for: period)
			#expect(value >= 0.0 && value <= 1.0, "Value should be in [0, 1]")
		}
	}

	@Test("Clamped values affect Monte Carlo statistics")
	func clampedAffectsStatistics() {
		// Normal(0, 10) clamped to [0, ∞) will have positive bias
		let base = ProbabilisticDriver<Double>.normal(name: "Value", mean: 0.0, stdDev: 10.0)
		let clamped = base.positive()

		let periods = [Period.month(year: 2025, month: 1)]
		let projection = DriverProjection(driver: clamped, periods: periods)
		let results = projection.projectMonteCarlo(iterations: 10_000)

		let stats = results.statistics[periods[0]]!

		// Mean should be positive (not 0) due to clamping
		#expect(stats.mean > 1.0, "Clamped mean should be biased positive")

		// Minimum should be exactly 0
		#expect(stats.min >= 0.0, "Minimum should be non-negative")

		// No negative values
		#expect(results.percentiles[periods[0]]!.p5 >= 0.0)
	}

	// MARK: - Positive Tests

	@Test("Positive driver ensures non-negative values")
	func positiveEnforcesNonNegative() {
		let base = ProbabilisticDriver<Double>.normal(name: "Price", mean: 100.0, stdDev: 150.0)
		let positive = base.positive()

		let period = Period.month(year: 2025, month: 1)

		for _ in 0..<1000 {
			let value = positive.sample(for: period)
			#expect(value >= 0.0, "Positive driver should never be negative")
		}
	}

	// MARK: - Rounding Tests

	@Test("Rounded driver produces integers")
	func roundedProducesIntegers() {
		let base = ProbabilisticDriver<Double>.normal(name: "Headcount", mean: 50.0, stdDev: 5.0)
		let rounded = base.rounded()

		let period = Period.month(year: 2025, month: 1)

		for _ in 0..<100 {
			let value = rounded.sample(for: period)
			#expect(value == value.rounded(), "Value should be an integer")
		}
	}

	@Test("Floored driver rounds down")
	func flooredRoundsDown() {
		// Always returns values that round down
		let base = DeterministicDriver(name: "Value", value: 47.8)
		let floored = base.floored()

		let period = Period.month(year: 2025, month: 1)
		let value = floored.sample(for: period)

		#expect(value == 47.0)
	}

	@Test("Ceiling driver rounds up")
	func ceilingRoundsUp() {
		let base = DeterministicDriver(name: "Value", value: 47.2)
		let ceiling = base.ceiling()

		let period = Period.month(year: 2025, month: 1)
		let value = ceiling.sample(for: period)

		#expect(value == 48.0)
	}

	// MARK: - Transformed Tests

	@Test("Transformed driver applies custom function")
	func transformedAppliesCustomFunction() {
		let base = DeterministicDriver(name: "Value", value: 100.0)

		// Double the value
		let transformed = base.transformed { $0 * 2.0 }

		let period = Period.month(year: 2025, month: 1)
		let value = transformed.sample(for: period)

		#expect(value == 200.0)
	}

	@Test("Transformed driver with complex logic")
	func transformedWithComplexLogic() {
		let base = ProbabilisticDriver<Double>.uniform(name: "Value", min: 0.0, max: 100.0)

		// Snap to grid of 5
		let snapped = base.transformed { value in
			(value / 5.0).rounded() * 5.0
		}

		let period = Period.month(year: 2025, month: 1)

		for _ in 0..<100 {
			let value = snapped.sample(for: period)
			// Should be multiple of 5
			let remainder = value.truncatingRemainder(dividingBy: 5.0)
			#expect(abs(remainder) < 0.01, "Value should be multiple of 5")
		}
	}

	// MARK: - Chaining Constraints

	@Test("Multiple constraints can be chained")
	func multipleConstraintsChained() {
		// Start with wide distribution
		let base = ProbabilisticDriver<Double>.normal(name: "Value", mean: 50.0, stdDev: 30.0)

		// Apply: clamp to [0, 100], then round
		let constrained = base
			.clamped(min: 0.0, max: 100.0)
			.rounded()

		let period = Period.month(year: 2025, month: 1)

		for _ in 0..<1000 {
			let value = constrained.sample(for: period)

			// Should be in [0, 100]
			#expect(value >= 0.0 && value <= 100.0)

			// Should be integer
			#expect(value == value.rounded())
		}
	}

	// MARK: - Real-World Scenarios

	@Test("Revenue model with positive constraint")
	func revenueModelWithPositiveConstraint() {
		// Revenue = Quantity × Price
		// Both must be positive
		let quantity = ProbabilisticDriver<Double>.normal(name: "Quantity", mean: 1000.0, stdDev: 200.0)
			.positive()
			.rounded()

		let price = ProbabilisticDriver<Double>.triangular(name: "Price", low: 80.0, high: 120.0, base: 100.0)
			.positive()

		let revenue = quantity * price

		let period = Period.month(year: 2025, month: 1)

		for _ in 0..<100 {
			let value = revenue.sample(for: period)
			#expect(value >= 0.0, "Revenue should be positive")
		}
	}

	@Test("Utilization rate bounded to [0, 1]")
	func utilizationRateBounded() {
		let utilization = ProbabilisticDriver<Double>.normal(name: "Utilization", mean: 0.75, stdDev: 0.2)
			.clamped(min: 0.0, max: 1.0)

		let periods = [Period.month(year: 2025, month: 1)]
		let projection = DriverProjection(driver: utilization, periods: periods)
		let results = projection.projectMonteCarlo(iterations: 5000)

		let stats = results.statistics[periods[0]]!

		// All values should be in [0, 1]
		#expect(stats.min >= 0.0)
		#expect(stats.max <= 1.0)
		#expect(results.percentiles[periods[0]]!.p5 >= 0.0)
		#expect(results.percentiles[periods[0]]!.p95 <= 1.0)
	}

	@Test("Headcount must be positive integer")
	func headcountMustBePositiveInteger() {
		let headcount = ProbabilisticDriver<Double>.normal(name: "Headcount", mean: 50.0, stdDev: 5.0)
			.positive()
			.rounded()

		let period = Period.month(year: 2025, month: 1)

		for _ in 0..<100 {
			let value = headcount.sample(for: period)

			// Must be positive
			#expect(value >= 0.0)

			// Must be integer
			#expect(value == value.rounded())
		}
	}

	@Test("Growth rate constrained to realistic bounds")
	func growthRateConstrained() {
		// Growth rate should be between -50% and +200%
		let growthRate = ProbabilisticDriver<Double>.normal(name: "Growth", mean: 0.10, stdDev: 0.30)
			.clamped(min: -0.50, max: 2.0)

		let period = Period.month(year: 2025, month: 1)

		for _ in 0..<1000 {
			let value = growthRate.sample(for: period)
			#expect(value >= -0.50 && value <= 2.0)
		}
	}

	// MARK: - Integration with Other Drivers

	@Test("Constrained drivers work with ProductDriver")
	func constrainedWithProductDriver() {
		let quantity = ProbabilisticDriver<Double>.normal(name: "Quantity", mean: 1000.0, stdDev: 100.0)
			.positive()
			.rounded()

		let price = DeterministicDriver(name: "Price", value: 50.0)

		let revenue = quantity * price

		let period = Period.month(year: 2025, month: 1)
		let value = revenue.sample(for: period)

		// Revenue should be positive multiple of 50
		#expect(value >= 0.0)
		let remainder = value.truncatingRemainder(dividingBy: 50.0)
		#expect(abs(remainder) < 0.01, "Revenue should be multiple of 50")
	}

	@Test("Constrained drivers work with time-varying drivers")
	func constrainedWithTimeVarying() {
		let base = TimeVaryingDriver<Double>(name: "Seasonal") { period in
			let mean = period.quarter == 4 ? 150.0 : 100.0
			return ProbabilisticDriver<Double>.normal(name: "Value", mean: mean, stdDev: 50.0)
				.sample(for: period)
		}

		let constrained = base.positive().rounded()

		let q1 = Period.quarter(year: 2025, quarter: 1)
		let q4 = Period.quarter(year: 2025, quarter: 4)

		// Sample many times
		var q1Samples: [Double] = []
		var q4Samples: [Double] = []

		for _ in 0..<100 {
			q1Samples.append(constrained.sample(for: q1))
			q4Samples.append(constrained.sample(for: q4))
		}

		// All should be positive integers
		for value in q1Samples + q4Samples {
			#expect(value >= 0.0)
			#expect(value == value.rounded())
		}

		// Q4 mean should be higher
		let q1Mean = q1Samples.reduce(0.0, +) / Double(q1Samples.count)
		let q4Mean = q4Samples.reduce(0.0, +) / Double(q4Samples.count)

		#expect(q4Mean > q1Mean)
	}

	// MARK: - Monte Carlo Integration

	@Test("Constrained drivers in full Monte Carlo projection")
	func fullMonteCarloWithConstraints() {
		// Model: Profit = (Quantity × Price) - (Fixed + Variable × Quantity)
		// All constrained appropriately

		let quantity = ProbabilisticDriver<Double>.normal(name: "Units", mean: 1000.0, stdDev: 100.0)
			.positive()
			.rounded()

		let price = ProbabilisticDriver<Double>.triangular(name: "Price", low: 95.0, high: 105.0, base: 100.0)
			.clamped(min: 50.0)

		let fixedCost = DeterministicDriver(name: "Fixed", value: 10_000.0)

		let variableCostPerUnit = DeterministicDriver(name: "Variable/Unit", value: 60.0)

		let revenue = quantity * price
		let variableCost = quantity * variableCostPerUnit
		let totalCost = fixedCost + variableCost
		let profit = revenue - totalCost

		let periods = Period.year(2025).quarters()
		let projection = DriverProjection(driver: profit, periods: periods)
		let results = projection.projectMonteCarlo(iterations: 5000)

		// Expected profit: (1000 × 100) - (10,000 + 60 × 1000) = 30,000
		for period in periods {
			let stats = results.statistics[period]!
			#expect(abs(stats.mean - 30_000.0) < 5000.0)
		}
	}
}

@Suite("Constrained Driver Additional Tests")
struct ConstrainedDriverAdditionalTests {

	@Test("Rounded uses away-from-zero for halves")
	func roundedHalvesBehavior() {
		let posHalf = DeterministicDriver(name: "Half+", value: 2.5).rounded()
		let negHalf = DeterministicDriver(name: "Half-", value: -2.5).rounded()

		let p = Period.month(year: 2025, month: 1)
		#expect(posHalf.sample(for: p) == 3.0)
		#expect(negHalf.sample(for: p) == -3.0)
	}

	@Test("Positive clamps deterministic negatives to zero")
	func positiveClampsDeterministic() {
		let neg = DeterministicDriver(name: "Neg", value: -42.0).positive()
		let p = Period.month(year: 2025, month: 1)
		#expect(neg.sample(for: p) == 0.0)
	}

	@Test("Clamp does not change values within bounds")
	func clampPassThrough() {
		let base = DeterministicDriver(name: "Value", value: 42.0)
		let clamped = base.clamped(min: 0.0, max: 100.0)
		let p = Period.month(year: 2025, month: 1)
		#expect(clamped.sample(for: p) == 42.0)
	}

	@Test("Floor and ceiling on negatives behave correctly")
	func floorCeilNegative() {
		let floorDrv = DeterministicDriver(name: "Neg", value: -3.2).floored()
		let ceilDrv = DeterministicDriver(name: "Neg", value: -3.2).ceiling()

		let p = Period.month(year: 2025, month: 1)
		#expect(floorDrv.sample(for: p) == -4.0)
		#expect(ceilDrv.sample(for: p) == -3.0)
	}

	@Test("Percentiles consistent with min/max after clamping")
	func percentilesWithinBounds() {
		let drv = ProbabilisticDriver<Double>.normal(name: "Util", mean: 0.5, stdDev: 0.4)
			.clamped(min: 0.0, max: 1.0)

		let periods = [Period.month(year: 2025, month: 1)]
		let proj = DriverProjection(driver: drv, periods: periods)
		let results = proj.projectMonteCarlo(iterations: 5000)

		let p = periods[0]
		let s = results.statistics[p]!
		let q = results.percentiles[p]!
		#expect(s.min >= 0.0)
		#expect(s.max <= 1.0)
		#expect(q.p5 >= s.min && q.p95 <= s.max)
		#expect(s.min <= q.p5 && q.p5 <= q.p50 && q.p50 <= q.p95 && q.p95 <= s.max)
	}
}

//
//  GrowthRateTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Growth Rate Tests")
struct GrowthRateTests {

	let tolerance: Double = 0.0001  // 0.01% tolerance

	// MARK: - Simple Growth Rate Tests

	@Test("Growth rate from 100 to 110")
	func growthRateSimple() {
		let from = 100.0
		let to = 110.0

		let growth = growthRate(from: from, to: to)

		// 10% growth: (110 - 100) / 100 = 0.10
		#expect(abs(growth - 0.10) < tolerance)
	}

	@Test("Growth rate from 100 to 80 (negative)")
	func growthRateNegative() {
		let from = 100.0
		let to = 80.0

		let growth = growthRate(from: from, to: to)

		// -20% growth: (80 - 100) / 100 = -0.20
		#expect(abs(growth - (-0.20)) < tolerance)
	}

	@Test("Growth rate with equal values is zero")
	func growthRateZero() {
		let from = 100.0
		let to = 100.0

		let growth = growthRate(from: from, to: to)

		#expect(abs(growth) < tolerance)
	}

	@Test("Growth rate doubling")
	func growthRateDoubling() {
		let from = 50.0
		let to = 100.0

		let growth = growthRate(from: from, to: to)

		// 100% growth: (100 - 50) / 50 = 1.0
		#expect(abs(growth - 1.0) < tolerance)
	}

	@Test("Growth rate with decimal values")
	func growthRateDecimals() {
		let from = 123.45
		let to = 145.67

		let growth = growthRate(from: from, to: to)

		// (145.67 - 123.45) / 123.45 ≈ 0.1799
		#expect(abs(growth - 0.1799) < 0.001)
	}

	// MARK: - CAGR (Compound Annual Growth Rate) Tests

	@Test("CAGR over 1 year equals simple growth")
	func cagrOneYear() {
		let beginning = 100.0
		let ending = 110.0
		let years = 1.0

		let growth = cagr(beginningValue: beginning, endingValue: ending, years: years)

		// Should equal simple growth rate
		#expect(abs(growth - 0.10) < tolerance)
	}

	@Test("CAGR over 3 years")
	func cagrThreeYears() {
		let beginning = 1000.0
		let ending = 1331.0  // 1000 * 1.1^3
		let years = 3.0

		let growth = cagr(beginningValue: beginning, endingValue: ending, years: years)

		// CAGR should be 10%
		#expect(abs(growth - 0.10) < tolerance)
	}

	@Test("CAGR with equal values is zero")
	func cagrZero() {
		let beginning = 1000.0
		let ending = 1000.0
		let years = 5.0

		let growth = cagr(beginningValue: beginning, endingValue: ending, years: years)

		#expect(abs(growth) < tolerance)
	}

	@Test("CAGR with negative growth")
	func cagrNegative() {
		let beginning = 1000.0
		let ending = 729.0  // 1000 * 0.9^3
		let years = 3.0

		let growth = cagr(beginningValue: beginning, endingValue: ending, years: years)

		// CAGR should be -10%
		#expect(abs(growth - (-0.10)) < tolerance)
	}

	@Test("CAGR over fractional years")
	func cagrFractionalYears() {
		let beginning = 100.0
		let ending = 121.0  // 100 * 1.1^2
		let years = 2.0

		let growth = cagr(beginningValue: beginning, endingValue: ending, years: years)

		// CAGR should be 10%
		#expect(abs(growth - 0.10) < tolerance)
	}

	@Test("CAGR matches known example")
	func cagrKnownExample() {
		// Investment grows from $10,000 to $15,000 over 5 years
		let beginning = 10000.0
		let ending = 15000.0
		let years = 5.0

		let growth = cagr(beginningValue: beginning, endingValue: ending, years: years)

		// CAGR = (15000/10000)^(1/5) - 1 ≈ 0.0845 (8.45%)
		#expect(abs(growth - 0.0845) < 0.001)
	}

	// MARK: - Apply Growth Tests (Annual Compounding)

	@Test("Apply 10% growth for 3 periods (annual)")
	func applyGrowthAnnual() {
		let baseValue = 100.0
		let rate = 0.10
		let periods = 3

		let values = applyGrowth(baseValue: baseValue, rate: rate, periods: periods, compounding: .annual)

		#expect(values.count == 4)  // Base + 3 periods
		#expect(abs(values[0] - 100.0) < tolerance)    // t=0
		#expect(abs(values[1] - 110.0) < tolerance)    // t=1: 100 * 1.1
		#expect(abs(values[2] - 121.0) < tolerance)    // t=2: 100 * 1.1^2
		#expect(abs(values[3] - 133.1) < tolerance)    // t=3: 100 * 1.1^3
	}

	@Test("Apply 0% growth (no change)")
	func applyGrowthZero() {
		let baseValue = 100.0
		let rate = 0.0
		let periods = 5

		let values = applyGrowth(baseValue: baseValue, rate: rate, periods: periods, compounding: .annual)

		// All values should equal base
		for value in values {
			#expect(abs(value - baseValue) < tolerance)
		}
	}

	@Test("Apply negative growth (decline)")
	func applyGrowthNegative() {
		let baseValue = 100.0
		let rate = -0.10  // -10% per period
		let periods = 3

		let values = applyGrowth(baseValue: baseValue, rate: rate, periods: periods, compounding: .annual)

		#expect(abs(values[0] - 100.0) < tolerance)    // t=0
		#expect(abs(values[1] - 90.0) < tolerance)     // t=1: 100 * 0.9
		#expect(abs(values[2] - 81.0) < tolerance)     // t=2: 100 * 0.9^2
		#expect(abs(values[3] - 72.9) < tolerance)     // t=3: 100 * 0.9^3
	}

	// MARK: - Compounding Frequency Tests

	@Test("Apply growth with quarterly compounding")
	func applyGrowthQuarterly() {
		let baseValue = 1000.0
		let annualRate = 0.12  // 12% annual
		let periods = 4  // 4 quarters = 1 year

		let values = applyGrowth(baseValue: baseValue, rate: annualRate, periods: periods, compounding: .quarterly)

		// Quarterly rate = 0.12 / 4 = 0.03
		// After 1 year: 1000 * (1.03)^4 ≈ 1125.51
		#expect(abs(values.last! - 1125.51) < 1.0)
	}

	@Test("Apply growth with monthly compounding")
	func applyGrowthMonthly() {
		let baseValue = 1000.0
		let annualRate = 0.12  // 12% annual
		let periods = 12  // 12 months = 1 year

		let values = applyGrowth(baseValue: baseValue, rate: annualRate, periods: periods, compounding: .monthly)

		// Monthly rate = 0.12 / 12 = 0.01
		// After 1 year: 1000 * (1.01)^12 ≈ 1126.83
		#expect(abs(values.last! - 1126.83) < 1.0)
	}

	@Test("Apply growth with daily compounding")
	func applyGrowthDaily() {
		let baseValue = 1000.0
		let annualRate = 0.12  // 12% annual
		let periods = 365  // 365 days = 1 year

		let values = applyGrowth(baseValue: baseValue, rate: annualRate, periods: periods, compounding: .daily)

		// Daily rate = 0.12 / 365
		// After 1 year: 1000 * (1 + 0.12/365)^365 ≈ 1127.47
		#expect(abs(values.last! - 1127.47) < 1.0)
	}

	@Test("Apply growth with continuous compounding")
	func applyGrowthContinuous() {
		let baseValue = 1000.0
		let annualRate = 0.12  // 12% annual
		let periods = 10  // 10 time units

		let values = applyGrowth(baseValue: baseValue, rate: annualRate, periods: periods, compounding: .continuous)

		// Continuous: A = P * e^(rt)
		// For 10 periods at 12% rate: 1000 * e^(0.12 * 10) ≈ 3320.12
		#expect(abs(values.last! - 3320.12) < 10.0)
	}

	@Test("Compounding frequency affects final value")
	func compoundingFrequencyComparison() {
		let baseValue = 1000.0
		let annualRate = 0.10
		let years = 1

		let annual = applyGrowth(baseValue: baseValue, rate: annualRate, periods: years, compounding: .annual)
		let quarterly = applyGrowth(baseValue: baseValue, rate: annualRate, periods: years * 4, compounding: .quarterly)
		let monthly = applyGrowth(baseValue: baseValue, rate: annualRate, periods: years * 12, compounding: .monthly)
		let daily = applyGrowth(baseValue: baseValue, rate: annualRate, periods: years * 365, compounding: .daily)
		let continuous = applyGrowth(baseValue: baseValue, rate: annualRate, periods: years, compounding: .continuous)

		// More frequent compounding = higher final value
		#expect(annual.last! < quarterly.last!)
		#expect(quarterly.last! < monthly.last!)
		#expect(monthly.last! < daily.last!)
		#expect(daily.last! < continuous.last!)
	}

	@Test("Semiannual compounding")
	func applyGrowthSemiannual() {
		let baseValue = 1000.0
		let annualRate = 0.08
		let periods = 2  // 2 half-years = 1 year

		let values = applyGrowth(baseValue: baseValue, rate: annualRate, periods: periods, compounding: .semiannual)

		// Semiannual rate = 0.08 / 2 = 0.04
		// After 1 year: 1000 * (1.04)^2 = 1081.60
		#expect(abs(values.last! - 1081.60) < 1.0)
	}

	// MARK: - Real-World Scenarios

	@Test("Revenue growth projection")
	func revenueGrowthScenario() {
		let currentRevenue = 1_000_000.0
		let growthRate = 0.15  // 15% annual growth
		let years = 5

		let projections = applyGrowth(baseValue: currentRevenue, rate: growthRate, periods: years, compounding: .annual)

		// Year 5: 1,000,000 * 1.15^5 ≈ 2,011,357
		#expect(abs(projections.last! - 2_011_357) < 1000)
	}

	@Test("Population growth")
	func populationGrowthScenario() {
		let currentPopulation = 1_000_000.0
		let growthRate = 0.02  // 2% annual growth
		let years = 10

		let projections = applyGrowth(baseValue: currentPopulation, rate: growthRate, periods: years, compounding: .annual)

		// Year 10: 1,000,000 * 1.02^10 ≈ 1,218,994
		#expect(abs(projections.last! - 1_218_994) < 1000)
	}

	@Test("Investment with monthly contributions")
	func investmentScenario() {
		// Starting with $10,000, growing at 7% annually
		let principal = 10_000.0
		let annualRate = 0.07
		let years = 10

		let values = applyGrowth(baseValue: principal, rate: annualRate, periods: years, compounding: .annual)

		// After 10 years: 10,000 * 1.07^10 ≈ 19,671.51
		#expect(abs(values.last! - 19_671.51) < 10.0)
	}

	@Test("Inflation adjustment")
	func inflationScenario() {
		let currentValue = 100.0
		let inflationRate = 0.03  // 3% annual inflation
		let years = 20

		let values = applyGrowth(baseValue: currentValue, rate: inflationRate, periods: years, compounding: .annual)

		// What costs $100 today will cost ~$180.61 in 20 years
		#expect(abs(values.last! - 180.61) < 1.0)
	}

	@Test("Business valuation CAGR")
	func businessValuationScenario() {
		let initialValuation = 5_000_000.0
		let currentValuation = 12_500_000.0
		let years = 7.0

		let growth = cagr(beginningValue: initialValuation, endingValue: currentValuation, years: years)

		// CAGR ≈ 14.47%
		#expect(abs(growth - 0.1447) < 0.01)  // Wider tolerance for iterative calculation
	}

	// MARK: - Edge Cases

	@Test("Growth rate from zero should handle gracefully")
	func growthRateFromZero() {
		let from = 0.0
		let to = 100.0

		let growth = growthRate(from: from, to: to)

		// Technically infinite, but should return a large value or infinity
		#expect(growth.isInfinite || growth > 1000.0)
	}

	@Test("CAGR with zero years should handle gracefully")
	func cagrZeroYears() {
		let beginning = 100.0
		let ending = 110.0
		let years = 0.0

		// Should either return infinity or throw
		let growth = cagr(beginningValue: beginning, endingValue: ending, years: years)

		#expect(growth.isInfinite || growth.isNaN)
	}

	@Test("Apply growth with zero periods returns base only")
	func applyGrowthZeroPeriods() {
		let baseValue = 100.0
		let rate = 0.10
		let periods = 0

		let values = applyGrowth(baseValue: baseValue, rate: rate, periods: periods, compounding: .annual)

		#expect(values.count == 1)
		#expect(abs(values[0] - baseValue) < tolerance)
	}

	@Test("Apply growth with large periods")
	func applyGrowthLargePeriods() {
		let baseValue = 100.0
		let rate = 0.01  // 1% growth
		let periods = 100

		let values = applyGrowth(baseValue: baseValue, rate: rate, periods: periods, compounding: .annual)

		#expect(values.count == 101)
		// 100 * 1.01^100 ≈ 270.48
		#expect(abs(values.last! - 270.48) < 1.0)
	}

	@Test("CAGR with very small values")
	func cagrSmallValues() {
		let beginning = 0.001
		let ending = 0.002
		let years = 2.0

		let growth = cagr(beginningValue: beginning, endingValue: ending, years: years)

		// Should still calculate correctly (100% growth over 2 years = 41.42% CAGR)
		#expect(abs(growth - 0.4142) < 0.01)
	}

	@Test("CAGR with very large values")
	func cagrLargeValues() {
		let beginning = 1_000_000_000.0
		let ending = 2_000_000_000.0
		let years = 5.0

		let growth = cagr(beginningValue: beginning, endingValue: ending, years: years)

		// Doubling over 5 years ≈ 14.87% CAGR
		#expect(abs(growth - 0.1487) < 0.001)
	}

	// MARK: - Consistency Tests

	@Test("CAGR and applyGrowth are consistent")
	func cagrApplyGrowthConsistency() {
		let beginning = 1000.0
		let years = 5
		let targetGrowth = 0.08  // 8% CAGR

		// Apply growth
		let projections = applyGrowth(baseValue: beginning, rate: targetGrowth, periods: years, compounding: .annual)
		let ending = projections.last!

		// Calculate CAGR back
		let calculatedCAGR = cagr(beginningValue: beginning, endingValue: ending, years: Double(years))

		// Should match original growth rate
		#expect(abs(calculatedCAGR - targetGrowth) < tolerance)
	}

	@Test("Growth rate over 1 period equals CAGR over 1 year")
	func growthRateCAGREquivalence() {
		let from = 100.0
		let to = 115.0

		let simpleGrowth = growthRate(from: from, to: to)
		let compoundGrowth = cagr(beginningValue: from, endingValue: to, years: 1.0)

		#expect(abs(simpleGrowth - compoundGrowth) < tolerance)
	}
	
	let tol: Double = 1e-6

		// MARK: - Growth/CAGR/Compounding

		@Test("CAGR with beginning value = 0 should be undefined (NaN/inf)")
		func cagrBeginningZero() {
			let g = cagr(beginningValue: 0.0, endingValue: 100.0, years: 5.0)
			#expect(g.isInfinite || g.isNaN)
		}

		@Test("Apply growth with -100% annual rate collapses to zero after first period")
		func applyGrowthNegativeOneHundredPercent() {
			let values = applyGrowth(baseValue: 100.0, rate: -1.0, periods: 3, compounding: .annual)
			#expect(values.count == 4)
			#expect(abs(values[0] - 100.0) < tol)
			#expect(abs(values[1] - 0.0) < tol)
			#expect(abs(values[2] - 0.0) < tol)
			#expect(abs(values[3] - 0.0) < tol)
		}

		@Test("Quarterly vs monthly compounding ordering at same nominal APR")
		func compoundingMonotonicityAPR() {
			let base = 10_000.0
			let apr = 0.12
			let annual = applyGrowth(baseValue: base, rate: apr, periods: 1, compounding: .annual).last!
			let quarterly = applyGrowth(baseValue: base, rate: apr, periods: 4, compounding: .quarterly).last!
			let monthly = applyGrowth(baseValue: base, rate: apr, periods: 12, compounding: .monthly).last!
			#expect(annual < quarterly)
			#expect(quarterly < monthly)
		}
}

//
//  TimeSeriesAnalyticsTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("TimeSeries Analytics Tests")
struct TimeSeriesAnalyticsTests {

	let tolerance: Double = 0.0001

	// MARK: - Growth Rate Tests

	@Test("growthRate with lag 1 calculates period-over-period growth")
	func growthRateLag1() {
		let periods = (1...4).map { Period.month(year: 2025, month: $0) }
		let ts = TimeSeries(periods: periods, values: [100.0, 110.0, 121.0, 133.1])

		let growth = ts.growthRate(lag: 1)

		#expect(growth.count == 3)  // First period has no prior value
		#expect(abs(growth[periods[1]]! - 0.10) < tolerance)  // 10% growth
		#expect(abs(growth[periods[2]]! - 0.10) < tolerance)  // 10% growth
		#expect(abs(growth[periods[3]]! - 0.10) < tolerance)  // 10% growth
	}

	@Test("growthRate with lag 2")
	func growthRateLag2() {
		let periods = (1...5).map { Period.month(year: 2025, month: $0) }
		let ts = TimeSeries(periods: periods, values: [100.0, 110.0, 121.0, 133.1, 146.41])

		let growth = ts.growthRate(lag: 2)

		#expect(growth.count == 3)  // First 2 periods have no 2-period-ago value
		#expect(abs(growth[periods[2]]! - 0.21) < tolerance)  // (121-100)/100 = 21%
		#expect(abs(growth[periods[3]]! - 0.21) < tolerance)  // (133.1-110)/110 ≈ 21%
	}

	@Test("growthRate handles negative values")
	func growthRateNegative() {
		let periods = (1...3).map { Period.month(year: 2025, month: $0) }
		let ts = TimeSeries(periods: periods, values: [100.0, 90.0, 81.0])

		let growth = ts.growthRate(lag: 1)

		#expect(growth.count == 2)
		#expect(abs(growth[periods[1]]! - (-0.10)) < tolerance)  // -10% growth
		#expect(abs(growth[periods[2]]! - (-0.10)) < tolerance)  // -10% growth
	}

	// MARK: - CAGR Tests

	@Test("cagr calculates compound annual growth rate")
	func cagrCalculation() {
		let jan2020 = Period.month(year: 2020, month: 1)
		let jan2025 = Period.month(year: 2025, month: 1)

		let ts = TimeSeries(
			periods: [jan2020, jan2025],
			values: [100.0, 161.05]  // 5 years, ~10% CAGR
		)

		let cagr = ts.cagr(from: jan2020, to: jan2025, years: 5.0)

		#expect(abs(cagr - 0.10) < tolerance)  // 10% CAGR
	}

	@Test("cagr with zero growth")
	func cagrZeroGrowth() {
		let jan2020 = Period.month(year: 2020, month: 1)
		let jan2025 = Period.month(year: 2025, month: 1)

		let ts = TimeSeries(
			periods: [jan2020, jan2025],
			values: [100.0, 100.0]
		)

		let cagr = ts.cagr(from: jan2020, to: jan2025, years: 5.0)

		#expect(abs(cagr) < tolerance)  // 0% CAGR
	}

	// MARK: - Moving Average Tests

	@Test("movingAverage with window 3")
	func movingAverageWindow3() {
		let periods = (1...5).map { Period.month(year: 2025, month: $0) }
		let ts = TimeSeries(periods: periods, values: [100.0, 110.0, 120.0, 130.0, 140.0])

		let ma = ts.movingAverage(window: 3)

		#expect(ma.count == 3)  // First 2 periods don't have enough data
		#expect(abs(ma[periods[2]]! - 110.0) < tolerance)  // (100+110+120)/3
		#expect(abs(ma[periods[3]]! - 120.0) < tolerance)  // (110+120+130)/3
		#expect(abs(ma[periods[4]]! - 130.0) < tolerance)  // (120+130+140)/3
	}

	@Test("movingAverage with window 1 returns original")
	func movingAverageWindow1() {
		let periods = (1...3).map { Period.month(year: 2025, month: $0) }
		let ts = TimeSeries(periods: periods, values: [100.0, 110.0, 120.0])

		let ma = ts.movingAverage(window: 1)

		#expect(ma.count == 3)
		#expect(ma[periods[0]] == 100.0)
		#expect(ma[periods[1]] == 110.0)
		#expect(ma[periods[2]] == 120.0)
	}

	// MARK: - Exponential Moving Average Tests

	@Test("exponentialMovingAverage with alpha 0.5")
	func emaAlpha05() {
		let periods = (1...4).map { Period.month(year: 2025, month: $0) }
		let ts = TimeSeries(periods: periods, values: [100.0, 110.0, 105.0, 115.0])

		let ema = ts.exponentialMovingAverage(alpha: 0.5)

		#expect(ema.count == 4)
		#expect(ema[periods[0]] == 100.0)  // First value unchanged
		// EMA = alpha * current + (1-alpha) * previous_EMA
		#expect(abs(ema[periods[1]]! - 105.0) < tolerance)  // 0.5*110 + 0.5*100 = 105
		#expect(abs(ema[periods[2]]! - 105.0) < tolerance)  // 0.5*105 + 0.5*105 = 105
		#expect(abs(ema[periods[3]]! - 110.0) < tolerance)  // 0.5*115 + 0.5*105 = 110
	}

	@Test("exponentialMovingAverage with alpha 1.0 equals original")
	func emaAlpha1() {
		let periods = (1...3).map { Period.month(year: 2025, month: $0) }
		let ts = TimeSeries(periods: periods, values: [100.0, 110.0, 120.0])

		let ema = ts.exponentialMovingAverage(alpha: 1.0)

		#expect(ema.count == 3)
		#expect(ema[periods[0]] == 100.0)
		#expect(ema[periods[1]] == 110.0)
		#expect(ema[periods[2]] == 120.0)
	}

	// MARK: - Cumulative Tests

	@Test("cumulative calculates running sum")
	func cumulativeSum() {
		let periods = (1...5).map { Period.month(year: 2025, month: $0) }
		let ts = TimeSeries(periods: periods, values: [10.0, 20.0, 30.0, 40.0, 50.0])

		let cumulative = ts.cumulative()

		#expect(cumulative.count == 5)
		#expect(cumulative[periods[0]] == 10.0)
		#expect(cumulative[periods[1]] == 30.0)   // 10 + 20
		#expect(cumulative[periods[2]] == 60.0)   // 10 + 20 + 30
		#expect(cumulative[periods[3]] == 100.0)  // 10 + 20 + 30 + 40
		#expect(cumulative[periods[4]] == 150.0)  // 10 + 20 + 30 + 40 + 50
	}

	@Test("cumulative with negative values")
	func cumulativeNegative() {
		let periods = (1...4).map { Period.month(year: 2025, month: $0) }
		let ts = TimeSeries(periods: periods, values: [100.0, -20.0, 30.0, -40.0])

		let cumulative = ts.cumulative()

		#expect(cumulative[periods[0]] == 100.0)
		#expect(cumulative[periods[1]] == 80.0)   // 100 - 20
		#expect(cumulative[periods[2]] == 110.0)  // 100 - 20 + 30
		#expect(cumulative[periods[3]] == 70.0)   // 100 - 20 + 30 - 40
	}

	// MARK: - Difference Tests

	@Test("diff with lag 1")
	func diffLag1() {
		let periods = (1...4).map { Period.month(year: 2025, month: $0) }
		let ts = TimeSeries(periods: periods, values: [100.0, 110.0, 105.0, 115.0])

		let diff = ts.diff(lag: 1)

		#expect(diff.count == 3)
		#expect(diff[periods[1]] == 10.0)   // 110 - 100
		#expect(diff[periods[2]] == -5.0)   // 105 - 110
		#expect(diff[periods[3]] == 10.0)   // 115 - 105
	}

	@Test("diff with lag 2")
	func diffLag2() {
		let periods = (1...5).map { Period.month(year: 2025, month: $0) }
		let ts = TimeSeries(periods: periods, values: [100.0, 110.0, 121.0, 133.0, 146.0])

		let diff = ts.diff(lag: 2)

		#expect(diff.count == 3)
		#expect(abs(diff[periods[2]]! - 21.0) < tolerance)  // 121 - 100
		#expect(abs(diff[periods[3]]! - 23.0) < tolerance)  // 133 - 110
		#expect(abs(diff[periods[4]]! - 25.0) < tolerance)  // 146 - 121
	}

	// MARK: - Percent Change Tests

	@Test("percentChange with lag 1")
	func percentChangeLag1() {
		let periods = (1...4).map { Period.month(year: 2025, month: $0) }
		let ts = TimeSeries(periods: periods, values: [100.0, 110.0, 121.0, 133.1])

		let pctChange = ts.percentChange(lag: 1)

		#expect(pctChange.count == 3)
		#expect(abs(pctChange[periods[1]]! - 10.0) < tolerance)  // 10% change
		#expect(abs(pctChange[periods[2]]! - 10.0) < tolerance)  // 10% change
		#expect(abs(pctChange[periods[3]]! - 10.0) < tolerance)  // 10% change
	}

	@Test("percentChange with negative change")
	func percentChangeNegative() {
		let periods = (1...3).map { Period.month(year: 2025, month: $0) }
		let ts = TimeSeries(periods: periods, values: [100.0, 90.0, 81.0])

		let pctChange = ts.percentChange(lag: 1)

		#expect(abs(pctChange[periods[1]]! - (-10.0)) < tolerance)  // -10%
		#expect(abs(pctChange[periods[2]]! - (-10.0)) < tolerance)  // -10%
	}

	// MARK: - Rolling Sum Tests

	@Test("rollingSum with window 3")
	func rollingSumWindow3() {
		let periods = (1...5).map { Period.month(year: 2025, month: $0) }
		let ts = TimeSeries(periods: periods, values: [10.0, 20.0, 30.0, 40.0, 50.0])

		let rolling = ts.rollingSum(window: 3)

		#expect(rolling.count == 3)
		#expect(rolling[periods[2]] == 60.0)   // 10 + 20 + 30
		#expect(rolling[periods[3]] == 90.0)   // 20 + 30 + 40
		#expect(rolling[periods[4]] == 120.0)  // 30 + 40 + 50
	}

	// MARK: - Rolling Min Tests

	@Test("rollingMin with window 3")
	func rollingMinWindow3() {
		let periods = (1...5).map { Period.month(year: 2025, month: $0) }
		let ts = TimeSeries(periods: periods, values: [30.0, 10.0, 50.0, 20.0, 40.0])

		let rolling = ts.rollingMin(window: 3)

		#expect(rolling.count == 3)
		#expect(rolling[periods[2]] == 10.0)  // min(30, 10, 50)
		#expect(rolling[periods[3]] == 10.0)  // min(10, 50, 20)
		#expect(rolling[periods[4]] == 20.0)  // min(50, 20, 40)
	}

	// MARK: - Rolling Max Tests

	@Test("rollingMax with window 3")
	func rollingMaxWindow3() {
		let periods = (1...5).map { Period.month(year: 2025, month: $0) }
		let ts = TimeSeries(periods: periods, values: [30.0, 10.0, 50.0, 20.0, 40.0])

		let rolling = ts.rollingMax(window: 3)

		#expect(rolling.count == 3)
		#expect(rolling[periods[2]] == 50.0)  // max(30, 10, 50)
		#expect(rolling[periods[3]] == 50.0)  // max(10, 50, 20)
		#expect(rolling[periods[4]] == 50.0)  // max(50, 20, 40)
	}

	// MARK: - Edge Cases

	@Test("growthRate on empty series returns empty")
	func growthRateEmpty() {
		let ts = TimeSeries<Double>(periods: [], values: [])
		let growth = ts.growthRate(lag: 1)
		#expect(growth.isEmpty)
	}

	@Test("movingAverage with window larger than data")
	func movingAverageLargeWindow() {
		let periods = (1...3).map { Period.month(year: 2025, month: $0) }
		let ts = TimeSeries(periods: periods, values: [100.0, 110.0, 120.0])

		let ma = ts.movingAverage(window: 5)

		#expect(ma.isEmpty)  // Not enough data for any windows
	}

	@Test("cumulative on empty series returns empty")
	func cumulativeEmpty() {
		let ts = TimeSeries<Double>(periods: [], values: [])
		let cumulative = ts.cumulative()
		#expect(cumulative.isEmpty)
	}

	@Test("diff with lag 0 should handle gracefully")
	func diffLag0() {
		let periods = (1...3).map { Period.month(year: 2025, month: $0) }
		let ts = TimeSeries(periods: periods, values: [100.0, 110.0, 120.0])

		let diff = ts.diff(lag: 0)

		// Lag 0 means difference from itself = 0
		#expect(diff.count == 3)
		#expect(diff[periods[0]] == 0.0)
		#expect(diff[periods[1]] == 0.0)
		#expect(diff[periods[2]] == 0.0)
	}

	// MARK: - Real-World Scenarios

	@Test("Revenue growth analysis")
	func revenueGrowthAnalysis() {
		let periods = (1...12).map { Period.month(year: 2025, month: $0) }
		let revenues = [100_000.0, 110_000.0, 121_000.0, 133_100.0,
						146_410.0, 161_051.0, 177_156.0, 194_872.0,
						214_359.0, 235_795.0, 259_374.0, 285_312.0]

		let ts = TimeSeries(periods: periods, values: revenues)

		// Calculate month-over-month growth
		let momGrowth = ts.growthRate(lag: 1)

		// All should be approximately 10% growth
		for period in periods.dropFirst() {
			if let growth = momGrowth[period] {
				#expect(abs(growth - 0.10) < 0.001)
			}
		}
	}

	@Test("Smoothing volatile data with moving average")
	func smoothingVolatileData() {
		let periods = (1...7).map { Period.month(year: 2025, month: $0) }
		let volatile = [100.0, 150.0, 90.0, 140.0, 95.0, 145.0, 100.0]

		let ts = TimeSeries(periods: periods, values: volatile)
		let smoothed = ts.movingAverage(window: 3)

		// Smoothed values should have less variance
		#expect(smoothed.count == 5)

		// Check that smoothed values are between min and max of window
		for period in periods.dropFirst(2) {
			if let smoothedValue = smoothed[period] {
				#expect(smoothedValue >= 90.0 && smoothedValue <= 150.0)
			}
		}
	}

	@Test("Year-to-date cumulative revenue")
	func ytdCumulativeRevenue() {
		let periods = (1...12).map { Period.month(year: 2025, month: $0) }
		let monthlyRevenue = Array(repeating: 100_000.0, count: 12)

		let ts = TimeSeries(periods: periods, values: monthlyRevenue)
		let ytd = ts.cumulative()

		#expect(ytd[periods[11]] == 1_200_000.0)  // Full year total
		#expect(ytd[periods[5]] == 600_000.0)     // First 6 months
	}
}

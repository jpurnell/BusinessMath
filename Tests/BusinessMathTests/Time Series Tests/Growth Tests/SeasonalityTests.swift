//
//  SeasonalityTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Seasonality Tests")
struct SeasonalityTests {

	let tolerance: Double = 0.01

	// Helper to create quarterly time series
	func createQuarterlyTimeSeries(values: [Double], startYear: Int = 2020) -> TimeSeries<Double> {
		var periods: [Period] = []
		for (index, _) in values.enumerated() {
			let year = startYear + (index / 4)
			let quarter = (index % 4) + 1
			periods.append(Period.quarter(year: year, quarter: quarter))
		}
		return TimeSeries(
			periods: periods,
			values: values,
			metadata: TimeSeriesMetadata(name: "Quarterly Data")
		)
	}

	// Helper to create monthly time series
	func createMonthlyTimeSeries(values: [Double], startYear: Int = 2020) -> TimeSeries<Double> {
		var periods: [Period] = []
		for (index, _) in values.enumerated() {
			let year = startYear + (index / 12)
			let month = (index % 12) + 1
			periods.append(Period.month(year: year, month: month))
		}
		return TimeSeries(
			periods: periods,
			values: values,
			metadata: TimeSeriesMetadata(name: "Monthly Data")
		)
	}

	// MARK: - Seasonal Indices Tests

	@Test("Calculate quarterly seasonal indices")
	func quarterlySeasonalIndices() throws {
		// Data with clear quarterly pattern: Q1=100, Q2=120, Q3=80, Q4=100 (repeating)
		let data = createQuarterlyTimeSeries(values: [
			100.0, 120.0, 80.0, 100.0,  // Year 1
			100.0, 120.0, 80.0, 100.0,  // Year 2
			100.0, 120.0, 80.0, 100.0   // Year 3
		])

		let indices = try seasonalIndices(timeSeries: data, periodsPerYear: 4)

		// Should have 4 indices (one per quarter)
		#expect(indices.count == 4)

		// Indices should reflect the pattern (relative to average of 100)
		#expect(abs(indices[0] - 1.0) < tolerance)   // Q1: 100/100 = 1.0
		#expect(abs(indices[1] - 1.2) < tolerance)   // Q2: 120/100 = 1.2
		#expect(abs(indices[2] - 0.8) < tolerance)   // Q3: 80/100 = 0.8
		#expect(abs(indices[3] - 1.0) < tolerance)   // Q4: 100/100 = 1.0
	}

	@Test("Seasonal indices average to 1.0 for multiplicative")
	func seasonalIndicesAverageToOne() throws {
		let data = createQuarterlyTimeSeries(values: [
			100.0, 120.0, 80.0, 100.0,
			110.0, 130.0, 90.0, 110.0,
			120.0, 140.0, 100.0, 120.0
		])

		let indices = try seasonalIndices(timeSeries: data, periodsPerYear: 4)

		let average = indices.reduce(0.0, +) / Double(indices.count)
		#expect(abs(average - 1.0) < tolerance)
	}

	@Test("Calculate monthly seasonal indices")
	func monthlySeasonalIndices() throws {
		// Simple pattern: Jan=100, Feb=110, ..., Dec=100 (2 years)
		var values: [Double] = []
		for _ in 0..<2 {  // 2 years
			for month in 1...12 {
				values.append(100.0 + Double(month) * 5.0)
			}
		}

		let data = createMonthlyTimeSeries(values: values)
		let indices = try seasonalIndices(timeSeries: data, periodsPerYear: 12)

		// Should have 12 indices (one per month)
		#expect(indices.count == 12)

		// Indices should average to 1.0
		let average = indices.reduce(0.0, +) / Double(indices.count)
		#expect(abs(average - 1.0) < tolerance)
	}

	@Test("Seasonal indices with insufficient data throws error")
	func seasonalIndicesInsufficientData() throws {
		// Only 3 quarters (less than 2 complete cycles)
		let data = createQuarterlyTimeSeries(values: [100.0, 120.0, 80.0])

		#expect(throws: SeasonalityError.self) {
			_ = try seasonalIndices(timeSeries: data, periodsPerYear: 4)
		}
	}

	// MARK: - Seasonal Adjustment Tests

	@Test("Seasonally adjust quarterly data")
	func seasonallyAdjustQuarterly() throws {
		// Data with strong seasonality
		let data = createQuarterlyTimeSeries(values: [
			100.0, 120.0, 80.0, 100.0,   // Year 1
			110.0, 132.0, 88.0, 110.0,   // Year 2 (10% growth + seasonality)
			121.0, 145.2, 96.8, 121.0    // Year 3 (10% growth + seasonality)
		])

		let indices = try seasonalIndices(timeSeries: data, periodsPerYear: 4)
		let adjusted = try seasonallyAdjust(timeSeries: data, indices: indices)

		// Adjusted data should remove seasonality, showing smooth trend
		// The underlying trend is approximately 100, 110, 121 (10% growth)
		// After adjustment, the variance should be reduced
		let adjustedValues = adjusted.valuesArray

		// Check that adjustment reduces the range
		let originalRange = data.valuesArray.max()! - data.valuesArray.min()!
		let adjustedRange = adjustedValues.max()! - adjustedValues.min()!

		// Adjusted range should be smaller than original (seasonality removed)
		#expect(adjustedRange < originalRange)
	}

	@Test("Seasonally adjust removes variance")
	func seasonallyAdjustReducesVariance() throws {
		let data = createQuarterlyTimeSeries(values: [
			100.0, 150.0, 50.0, 100.0,
			100.0, 150.0, 50.0, 100.0,
			100.0, 150.0, 50.0, 100.0
		])

		let indices = try seasonalIndices(timeSeries: data, periodsPerYear: 4)
		let adjusted = try seasonallyAdjust(timeSeries: data, indices: indices)

		// Calculate variance of original vs adjusted
		let originalVariance = varianceS(data.valuesArray)
		let adjustedVariance = varianceS(adjusted.valuesArray)

		// Adjusted variance should be much lower
		#expect(adjustedVariance < originalVariance)
	}

	@Test("Seasonally adjust with mismatched indices throws error")
	func seasonallyAdjustMismatchedIndices() throws {
		// Only 3 quarters (less than one complete cycle of 4 quarters)
		let data = createQuarterlyTimeSeries(values: [100.0, 120.0, 80.0])
		let wrongIndices = [1.0, 1.1, 0.9, 1.0]  // 4 indices but only 3 data points

		#expect(throws: SeasonalityError.self) {
			_ = try seasonallyAdjust(timeSeries: data, indices: wrongIndices)
		}
	}

	// MARK: - Apply Seasonal Tests

	@Test("Apply seasonal pattern to trend")
	func applySeasonalToTrend() throws {
		// Start with flat trend (no seasonality)
		let trend = createQuarterlyTimeSeries(values: [100.0, 100.0, 100.0, 100.0])

		// Apply seasonal pattern
		let indices = [1.0, 1.2, 0.8, 1.0]
		let seasonalized = try applySeasonal(timeSeries: trend, indices: indices)

		// Should match the seasonal pattern
		let values = seasonalized.valuesArray
		#expect(abs(values[0] - 100.0) < tolerance)  // 100 * 1.0
		#expect(abs(values[1] - 120.0) < tolerance)  // 100 * 1.2
		#expect(abs(values[2] - 80.0) < tolerance)   // 100 * 0.8
		#expect(abs(values[3] - 100.0) < tolerance)  // 100 * 1.0
	}

	@Test("Apply and remove seasonal are inverse operations")
	func applyRemoveSeasonalInverse() throws {
		let original = createQuarterlyTimeSeries(values: [100.0, 120.0, 80.0, 100.0, 110.0, 132.0, 88.0, 110.0])

		let indices = try seasonalIndices(timeSeries: original, periodsPerYear: 4)
		let deseasonalized = try seasonallyAdjust(timeSeries: original, indices: indices)
		let reseasonalized = try applySeasonal(timeSeries: deseasonalized, indices: indices)

		// Reseasonalized should match original
		for (orig, reseas) in zip(original.valuesArray, reseasonalized.valuesArray) {
			#expect(abs(orig - reseas) < tolerance)
		}
	}

	// MARK: - Decomposition Tests

	@Test("Additive decomposition splits components")
	func additiveDecomposition() throws {
		// Create data with known components
		// Trend: 100, 110, 120, 130... (linear growth)
		// Seasonal: +10, +20, -10, -20 (additive pattern)
		let values = [
			110.0, 130.0, 110.0, 110.0,  // Year 1: trend 100,110,120,130 + seasonal
			120.0, 140.0, 120.0, 120.0,  // Year 2: trend 140,150,160,170 + seasonal
			130.0, 150.0, 130.0, 130.0   // Year 3: trend 180,190,200,210 + seasonal
		]
		let data = createQuarterlyTimeSeries(values: values)

		let decomposition = try decomposeTimeSeries(
			timeSeries: data,
			periodsPerYear: 4,
			method: .additive
		)

		// Should have trend, seasonal, and residual components
		#expect(decomposition.trend.count == data.count)
		#expect(decomposition.seasonal.count == data.count)
		#expect(decomposition.residual.count == data.count)

		// Recomposition: trend + seasonal + residual ≈ original
		// Skip edge values that may be NaN due to centered moving average
		for i in 0..<data.count {
			let trendValue = decomposition.trend.valuesArray[i]
			// Skip NaN values at edges
			if trendValue.isNaN {
				continue
			}
			let reconstructed = trendValue +
								decomposition.seasonal.valuesArray[i] +
								decomposition.residual.valuesArray[i]
			#expect(abs(reconstructed - values[i]) < tolerance)
		}
	}

	@Test("Multiplicative decomposition splits components")
	func multiplicativeDecomposition() throws {
		// Create data with multiplicative seasonality
		// Base: 100, 110, 120, 130... (linear growth)
		// Seasonal multipliers: 1.0, 1.2, 0.8, 1.0
		let values = [
			100.0, 132.0, 96.0, 130.0,   // Year 1
			140.0, 180.0, 128.0, 170.0,  // Year 2
			180.0, 228.0, 160.0, 210.0   // Year 3
		]
		let data = createQuarterlyTimeSeries(values: values)

		let decomposition = try decomposeTimeSeries(
			timeSeries: data,
			periodsPerYear: 4,
			method: .multiplicative
		)

		// Recomposition: trend × seasonal × residual ≈ original
		// Skip edge values that may be NaN due to centered moving average
		for i in 0..<data.count {
			let trendValue = decomposition.trend.valuesArray[i]
			// Skip NaN values at edges
			if trendValue.isNaN {
				continue
			}
			let reconstructed = trendValue *
								decomposition.seasonal.valuesArray[i] *
								decomposition.residual.valuesArray[i]
			#expect(abs(reconstructed - values[i]) < 1.0)  // Slightly larger tolerance for multiplication
		}
	}

	@Test("Decomposition with different periods per year")
	func decompositionDifferentPeriods() throws {
		// Monthly data (12 periods per year)
		var values: [Double] = []
		for year in 0..<2 {
			for month in 1...12 {
				let trend = 100.0 + Double(year * 12 + month) * 2.0
				let seasonal = Double(month % 4) * 10.0
				values.append(trend + seasonal)
			}
		}

		let data = createMonthlyTimeSeries(values: values)

		let decomposition = try decomposeTimeSeries(
			timeSeries: data,
			periodsPerYear: 12,
			method: .additive
		)

		// Should successfully decompose monthly data
		#expect(decomposition.trend.count == data.count)
		#expect(decomposition.seasonal.count == data.count)
		#expect(decomposition.residual.count == data.count)
	}

	@Test("Decomposition with insufficient data throws error")
	func decompositionInsufficientData() throws {
		// Only 5 quarters (less than 2 complete cycles)
		let data = createQuarterlyTimeSeries(values: [100.0, 120.0, 80.0, 100.0, 110.0])

		#expect(throws: SeasonalityError.self) {
			_ = try decomposeTimeSeries(timeSeries: data, periodsPerYear: 4, method: .additive)
		}
	}

	// MARK: - Real-World Scenarios

	@Test("Retail sales with holiday seasonality")
	func retailSalesSeasonality() throws {
		// Quarterly retail sales with Q4 holiday spike
		// Base growth: 10% per year, Q4 is 50% higher due to holidays
		let values = [
			100.0, 105.0, 110.0, 165.0,  // Year 1 (Q4 spike)
			115.0, 120.0, 125.0, 187.5,  // Year 2 (growth + Q4 spike)
			130.0, 135.0, 140.0, 210.0   // Year 3 (growth + Q4 spike)
		]
		let data = createQuarterlyTimeSeries(values: values)

		let decomposition = try decomposeTimeSeries(
			timeSeries: data,
			periodsPerYear: 4,
			method: .multiplicative
		)

		// Q4 seasonal index should be significantly higher than others
		let q4Indices = [3, 7, 11].map { decomposition.seasonal.valuesArray[$0] }
		let avgQ4 = q4Indices.reduce(0.0, +) / Double(q4Indices.count)

		#expect(avgQ4 > 1.3)  // Q4 should be at least 30% above average
	}

	@Test("SaaS revenue with end-of-quarter spikes")
	func saasRevenueSpikes() throws {
		// SaaS MRR with end-of-quarter booking spikes
		// Q1, Q2, Q3 steady, Q4 higher due to annual contracts
		let values = [
			100.0, 100.0, 100.0, 130.0,
			105.0, 105.0, 105.0, 136.5,
			110.0, 110.0, 110.0, 143.0
		]
		let data = createQuarterlyTimeSeries(values: values)

		let indices = try seasonalIndices(timeSeries: data, periodsPerYear: 4)

		// Q4 index should be higher
		#expect(indices[3] > indices[0])
		#expect(indices[3] > indices[1])
		#expect(indices[3] > indices[2])
	}

	@Test("Ice cream sales with summer seasonality")
	func iceCreamSeasonality() throws {
		// Quarterly ice cream sales: low in winter, high in summer
		// Q1 (winter): 60, Q2 (spring): 100, Q3 (summer): 140, Q4 (fall): 100
		let values = [
			60.0, 100.0, 140.0, 100.0,
			66.0, 110.0, 154.0, 110.0,  // 10% growth
			72.6, 121.0, 169.4, 121.0   // 10% growth
		]
		let data = createQuarterlyTimeSeries(values: values)

		let decomposition = try decomposeTimeSeries(
			timeSeries: data,
			periodsPerYear: 4,
			method: .multiplicative
		)

		// After removing seasonality, trend should show steady growth
		let trendValues = decomposition.trend.valuesArray

		// Trend should be increasing (skip NaN values at edges)
		var lastValidTrend: Double? = nil
		for i in 0..<trendValues.count {
			if trendValues[i].isNaN {
				continue
			}
			if let last = lastValidTrend {
				#expect(trendValues[i] >= last - tolerance)
			}
			lastValidTrend = trendValues[i]
		}

		// Q3 (summer) seasonal indices should be highest
		let q3Indices = [2, 6, 10].map { decomposition.seasonal.valuesArray[$0] }
		let avgQ3 = q3Indices.reduce(0.0, +) / Double(q3Indices.count)

		// Q1 (winter) seasonal indices should be lowest
		let q1Indices = [0, 4, 8].map { decomposition.seasonal.valuesArray[$0] }
		let avgQ1 = q1Indices.reduce(0.0, +) / Double(q1Indices.count)

		#expect(avgQ3 > avgQ1)
	}

	// MARK: - Edge Cases

	@Test("Flat data produces flat seasonal indices")
	func flatDataSeasonality() throws {
		// Perfectly flat data (no seasonality)
		let data = createQuarterlyTimeSeries(values: [100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0])

		let indices = try seasonalIndices(timeSeries: data, periodsPerYear: 4)

		// All indices should be 1.0 (no seasonal effect)
		for index in indices {
			#expect(abs(index - 1.0) < tolerance)
		}
	}

	@Test("Decomposition preserves time series metadata")
	func decompositionPreservesMetadata() throws {
		let data = createQuarterlyTimeSeries(values: [100.0, 120.0, 80.0, 100.0, 110.0, 132.0, 88.0, 110.0])

		let decomposition = try decomposeTimeSeries(
			timeSeries: data,
			periodsPerYear: 4,
			method: .additive
		)

		// Metadata should indicate the component type
		#expect(decomposition.trend.metadata.name.contains("Trend"))
		#expect(decomposition.seasonal.metadata.name.contains("Seasonal"))
		#expect(decomposition.residual.metadata.name.contains("Residual"))
	}
	
	@Test("Seasonal indices are scale invariant")
		func seasonalIndicesScaleInvariant() throws {
			let values = [100.0, 120.0, 80.0, 100.0,
						  110.0, 132.0, 88.0, 110.0]
			func series(mult: Double) -> TimeSeries<Double> {
				let periods = (0..<values.count).map { Period.quarter(year: 2024 + $0/4, quarter: ($0 % 4) + 1) }
				return TimeSeries(periods: periods, values: values.map { $0 * mult })
			}
			let idx1 = try seasonalIndices(timeSeries: series(mult: 1.0), periodsPerYear: 4)
			let idx2 = try seasonalIndices(timeSeries: series(mult: 7.3), periodsPerYear: 4)
			#expect(idx1.count == idx2.count)
			for (a,b) in zip(idx1, idx2) {
				#expect(abs(a - b) < 0.01)
			}
		}

		@Test("Seasonal indices with partial trailing year are stable")
		func seasonalIndicesPartialTrailingYear() throws {
			// 2 full years + 1 quarter of pattern
			let valsFull3Y = [
				100.0, 120.0, 80.0, 100.0,
				110.0, 132.0, 88.0, 110.0,
				121.0, 145.2, 96.8, 121.0
			]
			let vals2YPlusQ1 = Array(valsFull3Y.prefix(9)) // 2 years + Q1
			func ts(_ vals: [Double]) -> TimeSeries<Double> {
				let periods = (0..<vals.count).map { Period.quarter(year: 2024 + $0/4, quarter: ($0 % 4) + 1) }
				return TimeSeries(periods: periods, values: vals)
			}
			let idxFull = try seasonalIndices(timeSeries: ts(valsFull3Y), periodsPerYear: 4)
			let idxPartial = try seasonalIndices(timeSeries: ts(vals2YPlusQ1), periodsPerYear: 4)
			#expect(idxFull.count == 4 && idxPartial.count == 4)
			// Indices should be close even with incomplete last year
			for (a,b) in zip(idxFull, idxPartial) {
				#expect(abs(a - b) < 0.05)
			}
		}
}

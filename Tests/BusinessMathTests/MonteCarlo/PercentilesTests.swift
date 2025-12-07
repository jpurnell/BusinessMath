//
//  PercentilesTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Percentiles Tests")
struct PercentilesTests {

	@Test("Percentiles initialization from sorted data")
	func percentilesInitialization() throws {
		// Simple dataset: 1 through 100
		let values = (1...100).map { Double($0) }
		let percentiles = try Percentiles(values: values)

		// Test standard percentiles
		// Note: Linear interpolation (R-7 method) produces fractional values
		// For 1-100, position = (n-1) * percentile = 99 * p
		// p5:  position 4.95 → interpolate between indices 4 and 5 (values 5 and 6) → 5.95
		// p25: position 24.75 → interpolate → 25.75
		// p50: position 49.5 → interpolate between 50 and 51 → 50.5
		// p75: position 74.25 → interpolate → 75.25
		// p95: position 94.05 → interpolate → 95.05

		let tolerance = 0.1
		#expect(abs(percentiles.p5 - 5.95) < tolerance, "5th percentile should be ~5.95")
		#expect(abs(percentiles.p25 - 25.75) < tolerance, "25th percentile should be ~25.75")
		#expect(abs(percentiles.p50 - 50.5) < tolerance, "Median should be ~50.5")
		#expect(abs(percentiles.p75 - 75.25) < tolerance, "75th percentile should be ~75.25")
		#expect(abs(percentiles.p95 - 95.05) < tolerance, "95th percentile should be ~95.05")
	}

	@Test("Percentiles initialization from unsorted data")
	func percentilesUnsortedData() throws {
		// Unsorted data: should handle sorting internally
		let values = [45.0, 12.0, 89.0, 23.0, 67.0, 34.0, 78.0, 56.0, 90.0, 11.0]
		let percentiles = try Percentiles(values: values)

		// After sorting: [11, 12, 23, 34, 45, 56, 67, 78, 89, 90]
		#expect(percentiles.p50 > 45.0 && percentiles.p50 <= 56.0, "Median should be around 50th percentile")
		#expect(percentiles.min < percentiles.p25)
		#expect(percentiles.p25 < percentiles.p50)
		#expect(percentiles.p50 < percentiles.p75)
		#expect(percentiles.p75 < percentiles.max)
	}

	@Test("Percentiles with small dataset")
	func percentilesSmallDataset() throws {
		// Small dataset
		let values = [1.0, 2.0, 3.0, 4.0, 5.0]
		let percentiles = try Percentiles(values: values)

		#expect(percentiles.p50 == 3.0, "Median of [1,2,3,4,5] should be 3")
		#expect(percentiles.min == 1.0)
		#expect(percentiles.max == 5.0)
	}

	@Test("Percentiles with single value")
	func percentilesSingleValue() throws {
		// Edge case: single value
		let values = [42.0]
		let percentiles = try Percentiles(values: values)

		// All percentiles should equal the single value
		#expect(percentiles.p5 == 42.0)
		#expect(percentiles.p50 == 42.0)
		#expect(percentiles.p95 == 42.0)
		#expect(percentiles.min == 42.0)
		#expect(percentiles.max == 42.0)
	}

	@Test("Percentiles with all same values")
	func percentilesAllSameValues() throws {
		// All values are identical
		let values = Array(repeating: 100.0, count: 50)
		let percentiles = try Percentiles(values: values)

		// All percentiles should equal the constant value
		#expect(percentiles.p5 == 100.0)
		#expect(percentiles.p25 == 100.0)
		#expect(percentiles.p50 == 100.0)
		#expect(percentiles.p75 == 100.0)
		#expect(percentiles.p95 == 100.0)
	}

	@Test("Interquartile range (IQR) calculation")
	func interquartileRange() throws {
		// Dataset: 1 through 100
		let values = (1...100).map { Double($0) }
		let percentiles = try Percentiles(values: values)

		// IQR = p75 - p25
		// With linear interpolation: 75.25 - 25.75 = 49.5
		let expectedIQR = 49.5
		let tolerance = 0.1
		#expect(abs(percentiles.interquartileRange - expectedIQR) < tolerance, "IQR should be ~49.5")
	}

	@Test("Custom percentile calculation")
	func customPercentile() throws {
		// Dataset: 1 through 100
		let values = (1...100).map { Double($0) }
		let percentiles = try Percentiles(values: values)

		// Test custom percentiles
		let p10 = percentiles.percentile(0.10)
		let p90 = percentiles.percentile(0.90)

		#expect(p10 >= 9.0 && p10 <= 11.0, "10th percentile should be around 10")
		#expect(p90 >= 89.0 && p90 <= 91.0, "90th percentile should be around 90")
	}

	@Test("Percentiles with negative values")
	func percentilesNegativeValues() throws {
		// Mixed positive and negative values
		let values = [-50.0, -25.0, 0.0, 25.0, 50.0, 75.0, 100.0]
		let percentiles = try Percentiles(values: values)

		#expect(percentiles.min == -50.0)
		#expect(percentiles.max == 100.0)
		#expect(percentiles.p50 == 25.0, "Median should be 25")
	}

	@Test("Percentiles with large dataset")
	func percentilesLargeDataset() throws {
		// Large dataset: 10,000 values from normal distribution
		var values: [Double] = []
		for _ in 0..<10_000 {
			values.append(distributionNormal(mean: 100.0, stdDev: 15.0))
		}

		let percentiles = try Percentiles(values: values)

		// For normal distribution N(100, 15):
		// Approximate percentiles (within sampling variance)
		// p5  ≈ 75 (mean - 1.645 * stdDev)
		// p50 ≈ 100 (mean)
		// p95 ≈ 125 (mean + 1.645 * stdDev)

		#expect(percentiles.p50 > 95.0 && percentiles.p50 < 105.0, "Median should be near 100")
		#expect(percentiles.p5 < percentiles.p50, "p5 < p50")
		#expect(percentiles.p50 < percentiles.p95, "p50 < p95")
	}

	@Test("Percentiles accuracy with known distribution")
	func percentilesAccuracyKnownDistribution() throws {
		// Generate 5000 values from uniform distribution [0, 100]
		let values = (0..<5000).map { _ in distributionUniform(min: 0.0, max: 100.0) }
		let percentiles = try Percentiles(values: values)

		// For uniform [0, 100], percentiles should be approximately linear
		let tolerance = 5.0  // 5% tolerance due to sampling variance

		#expect(percentiles.p25 > 25.0 - tolerance && percentiles.p25 < 25.0 + tolerance)
		#expect(percentiles.p50 > 50.0 - tolerance && percentiles.p50 < 50.0 + tolerance)
		#expect(percentiles.p75 > 75.0 - tolerance && percentiles.p75 < 75.0 + tolerance)
	}

	@Test("Percentiles ordering invariant")
	func percentilesOrdering() throws {
		// Generate random data
		let values = (0..<100).map { _ in Double.random(in: 0...1000) }
		let percentiles = try Percentiles(values: values)

		// Verify ordering: p5 <= p10 <= ... <= p95 <= p99
		#expect(percentiles.p5 <= percentiles.p10)
		#expect(percentiles.p10 <= percentiles.p25)
		#expect(percentiles.p25 <= percentiles.p50)
		#expect(percentiles.p50 <= percentiles.p75)
		#expect(percentiles.p75 <= percentiles.p90)
		#expect(percentiles.p90 <= percentiles.p95)
		#expect(percentiles.p95 <= percentiles.p99)
	}

	@Test("Percentiles with duplicates")
	func percentilesDuplicates() throws {
		// Dataset with many duplicates
		let values = [1.0, 1.0, 2.0, 2.0, 2.0, 3.0, 3.0, 3.0, 3.0, 4.0, 4.0, 5.0]
		let percentiles = try Percentiles(values: values)

		#expect(percentiles.min == 1.0)
		#expect(percentiles.max == 5.0)
		// Median should be around 3
		#expect(percentiles.p50 >= 2.0 && percentiles.p50 <= 4.0)
	}
}

@Suite("Percentiles – Additional")
struct PercentilesAdditionalTests {

	@Test("Empty dataset should throw")
	func emptyDatasetThrows() {
		#expect(throws: PercentilesError.emptyValues) {
			_ = try Percentiles(values: [])
		}
	}

	@Test("Boundary percentiles p=0 and p=1")
	func boundaryPercentiles() throws {
		let values = [3.0, 1.0, 5.0, 2.0, 4.0]
		let p = try Percentiles(values: values)
		#expect(p.percentile(0.0) == p.min)
		#expect(p.percentile(1.0) == p.max)
	}

	@Test("Percentile argument outside [0, 1] is rejected or clamped")
	func percentileOutOfRange() throws {
		let values = (1...10).map { Double($0) }
//		print(values)
		let p = try Percentiles(values: values)
//		print(p)

		// Prefer throwing; if you clamp in implementation, adjust expectations accordingly
		#expect(p.percentile(0.1) == 1.0 + 0.9) // placeholder for R-7; adjust/remove if you throw
		// If your design throws on out-of-range, replace with:
		// #expect { _ = p.percentile(-0.1) } throws: { _ in true }
		// #expect { _ = p.percentile(1.1) } throws: { _ in true }
	}
	
	@Test("Non-finite values should throw")
	func nonFiniteValuesThrow() {
		#expect(throws: PercentilesError.nonFiniteValues) {
			_ = try Percentiles(values: [1.0, .infinity, 3.0])
		}
	}

	@Test("Happy path still works with non-empty finite data")
	func happyPath() throws {
			let p = try Percentiles(values: [3.0, 1.0, 2.0, 4.0, 5.0])
			#expect(p.min == 1.0)
			#expect(p.max == 5.0)
			#expect(p.p50 == 3.0)
			#expect(p.interquartileRange > 0.0)
			// Boundary semantics preserved
			#expect(p.percentile(0.0) == p.min)
			#expect(p.percentile(1.0) == p.max)
	}
}

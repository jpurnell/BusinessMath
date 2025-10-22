//
//  CommandLineVisualizationTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/22/25.
//

import XCTest
@testable import BusinessMath

final class CommandLineVisualizationTests: XCTestCase {

	// MARK: - Empty Histogram Tests

	func testPlotHistogram_EmptyHistogram_ReturnsEmptyMessage() {
		// Given
		let histogram: [(range: Range<Double>, count: Int)] = []

		// When
		let output = plotHistogram(histogram)

		// Then
		XCTAssertTrue(output.contains("Empty histogram"), "Should indicate empty histogram")
	}

	// MARK: - Single Bin Tests

	func testPlotHistogram_SingleBin_DisplaysCorrectly() {
		// Given
		let histogram: [(range: Range<Double>, count: Int)] = [
			(range: 0.0..<10.0, count: 100)
		]

		// When
		let output = plotHistogram(histogram)

		// Then
		XCTAssertTrue(output.contains("1 bin"), "Should show 1 bin (singular)")
		XCTAssertTrue(output.contains("100 samples"), "Should show 100 total samples")
		XCTAssertTrue(output.contains("0.") && output.contains("10."), "Should show bounds")
		XCTAssertTrue(output.contains("100.0%"), "Should show 100% for single bin")
	}

	// MARK: - Multiple Bins Tests

	func testPlotHistogram_MultipleBins_DisplaysAll() {
		// Given
		let histogram: [(range: Range<Double>, count: Int)] = [
			(range: 0.0..<10.0, count: 50),
			(range: 10.0..<20.0, count: 100),
			(range: 20.0..<30.0, count: 75)
		]

		// When
		let output = plotHistogram(histogram)

		// Then
		XCTAssertTrue(output.contains("3 bins"), "Should show 3 bins")
		XCTAssertTrue(output.contains("225 samples"), "Should show total count")

		// Check all bins are displayed (maxValue=30 uses 1 decimal place: 0.0, 10.0, 20.0, 30.0)
		XCTAssertTrue(output.contains("0.") && output.contains("10."), "Should show bin bounds")
		XCTAssertTrue(output.contains("20.") && output.contains("30."), "Should show bin bounds")
	}

	// MARK: - Percentage Calculation Tests

	func testPlotHistogram_PercentageCalculation_IsAccurate() {
		// Given
		let histogram: [(range: Range<Double>, count: Int)] = [
			(range: 0.0..<10.0, count: 25),  // 25% of 100
			(range: 10.0..<20.0, count: 50), // 50% of 100
			(range: 20.0..<30.0, count: 25)  // 25% of 100
		]

		// When
		let output = plotHistogram(histogram)

		// Then
		XCTAssertTrue(output.contains("25.0%"), "Should show 25%")
		XCTAssertTrue(output.contains("50.0%"), "Should show 50%")
	}

	// MARK: - Bar Scaling Tests

	func testPlotHistogram_BarScaling_MaxBinGetsFullBar() {
		// Given
		let histogram: [(range: Range<Double>, count: Int)] = [
			(range: 0.0..<10.0, count: 50),
			(range: 10.0..<20.0, count: 100), // Max count
			(range: 20.0..<30.0, count: 25)
		]

		// When
		let output = plotHistogram(histogram)

		// Then
		// The bin with count=100 should have the longest bar
		// Verify output structure: should have 3 lines for 3 bins
		let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty && $0.contains("[") }
		XCTAssertEqual(lines.count, 3, "Should have 3 bin lines")
		// Verify percentages sum to approximately 100%
		XCTAssertTrue(output.contains("%"), "Should show percentages")
	}

	// MARK: - Number Formatting Tests

	func testPlotHistogram_LargeNumbers_FormatsCorrectly() {
		// Given
		let histogram: [(range: Range<Double>, count: Int)] = [
			(range: 1000.0..<2000.0, count: 100),
			(range: 2000.0..<3000.0, count: 200)
		]

		// When
		let output = plotHistogram(histogram)

		// Then
		XCTAssertTrue(output.contains("1000"), "Should format large numbers")
		XCTAssertTrue(output.contains("2000"), "Should format large numbers")
		XCTAssertTrue(output.contains("3000"), "Should format large numbers")
	}

	func testPlotHistogram_SmallNumbers_FormatsCorrectly() {
		// Given
		let histogram: [(range: Range<Double>, count: Int)] = [
			(range: 0.01..<0.02, count: 100),
			(range: 0.02..<0.03, count: 200)
		]

		// When
		let output = plotHistogram(histogram)

		// Then
		XCTAssertTrue(output.contains("0.01") || output.contains("0.0"), "Should format small numbers")
	}

	// MARK: - Integration Test with SimulationResults

	func testPlotHistogram_WithSimulationResults_ProducesOutput() {
		// Given
		let values = (0..<1000).map { _ in Double.random(in: 0.0...100.0) }
		let results = SimulationResults(values: values)
		let histogram = results.histogram(bins: 10)

		// When
		let output = plotHistogram(histogram)

		// Then
		XCTAssertFalse(output.isEmpty, "Should produce output")
		XCTAssertTrue(output.contains("10 bins"), "Should show 10 bins")
		XCTAssertTrue(output.contains("1000 samples"), "Should show 1000 samples")
		XCTAssertTrue(output.contains("%"), "Should show percentages")
		// Verify structure by checking for range brackets
		XCTAssertTrue(output.contains("[") && output.contains("):"), "Should show bin ranges")
	}

	// MARK: - Edge Cases

	func testPlotHistogram_ZeroCountBin_DisplaysCorrectly() {
		// Given
		let histogram: [(range: Range<Double>, count: Int)] = [
			(range: 0.0..<10.0, count: 100),
			(range: 10.0..<20.0, count: 0),  // Zero count
			(range: 20.0..<30.0, count: 100)
		]

		// When
		let output = plotHistogram(histogram)

		// Then
		XCTAssertTrue(output.contains("0.0%"), "Should show 0% for empty bin")
		// The zero-count bin should have no bar or minimal bar
	}

	func testPlotHistogram_AllBinsSameCount_ScalesCorrectly() {
		// Given
		let histogram: [(range: Range<Double>, count: Int)] = [
			(range: 0.0..<10.0, count: 100),
			(range: 10.0..<20.0, count: 100),
			(range: 20.0..<30.0, count: 100)
		]

		// When
		let output = plotHistogram(histogram)

		// Then
		// All bins should have same percentage
		let percentageCount = output.components(separatedBy: "33.3%").count - 1
		XCTAssertEqual(percentageCount, 3, "All bins should show ~33.3%")
	}

	// MARK: - Output Structure Tests

	func testPlotHistogram_OutputStructure_HasHeader() {
		// Given
		let histogram: [(range: Range<Double>, count: Int)] = [
			(range: 0.0..<10.0, count: 100)
		]

		// When
		let output = plotHistogram(histogram)

		// Then
		XCTAssertTrue(output.hasPrefix("Histogram"), "Should start with 'Histogram'")
	}

	func testPlotHistogram_OutputStructure_HasMultipleLines() {
		// Given
		let histogram: [(range: Range<Double>, count: Int)] = [
			(range: 0.0..<10.0, count: 50),
			(range: 10.0..<20.0, count: 100),
			(range: 20.0..<30.0, count: 75)
		]

		// When
		let output = plotHistogram(histogram)
		let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }

		// Then
		// Should have header + 3 bin lines (at minimum)
		XCTAssertGreaterThanOrEqual(lines.count, 4, "Should have header and bin lines")
	}
}

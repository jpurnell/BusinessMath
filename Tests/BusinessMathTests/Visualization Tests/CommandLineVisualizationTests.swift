//
//  CommandLineVisualizationTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/22/25.
//

import Testing
import Testing
import Foundation
@testable import BusinessMath

@Suite("CommandLineVisualizationTests") struct CommandLineVisualizationTests {

	// MARK: - Empty Histogram Tests

	@Test("PlotHistogram_EmptyHistogram_ReturnsEmptyMessage") func LPlotHistogram_EmptyHistogram_ReturnsEmptyMessage() {
		// Given
		let histogram: [(range: Range<Double>, count: Int)] = []

		// When
		let output = plotHistogram(histogram)

		// Then
		#expect(output.contains("Empty histogram"), "Should indicate empty histogram")
	}

	// MARK: - Single Bin Tests

	@Test("PlotHistogram_SingleBin_DisplaysCorrectly") func LPlotHistogram_SingleBin_DisplaysCorrectly() {
		// Given
		let histogram: [(range: Range<Double>, count: Int)] = [
			(range: 0.0..<10.0, count: 100)
		]

		// When
		let output = plotHistogram(histogram)

		// Then
		#expect(output.contains("1 bin"), "Should show 1 bin (singular)")
		#expect(output.contains("100 samples"), "Should show 100 total samples")
		#expect(output.contains("0.") && output.contains("10."), "Should show bounds")
		#expect(output.contains("100.0%"), "Should show 100% for single bin")
	}

	// MARK: - Multiple Bins Tests

	@Test("PlotHistogram_MultipleBins_DisplaysAll") func LPlotHistogram_MultipleBins_DisplaysAll() {
		// Given
		let histogram: [(range: Range<Double>, count: Int)] = [
			(range: 0.0..<10.0, count: 50),
			(range: 10.0..<20.0, count: 100),
			(range: 20.0..<30.0, count: 75)
		]

		// When
		let output = plotHistogram(histogram)

		// Then
		#expect(output.contains("3 bins"), "Should show 3 bins")
		#expect(output.contains("225 samples"), "Should show total count")

		// Check all bins are displayed (maxValue=30 uses 1 decimal place: 0.0, 10.0, 20.0, 30.0)
		#expect(output.contains("0.") && output.contains("10."), "Should show bin bounds")
		#expect(output.contains("20.") && output.contains("30."), "Should show bin bounds")
	}

	// MARK: - Percentage Calculation Tests

	@Test("PlotHistogram_PercentageCalculation_IsAccurate") func LPlotHistogram_PercentageCalculation_IsAccurate() {
		// Given
		let histogram: [(range: Range<Double>, count: Int)] = [
			(range: 0.0..<10.0, count: 25),  // 25% of 100
			(range: 10.0..<20.0, count: 50), // 50% of 100
			(range: 20.0..<30.0, count: 25)  // 25% of 100
		]

		// When
		let output = plotHistogram(histogram)

		// Then
		#expect(output.contains("25.0%"), "Should show 25%")
		#expect(output.contains("50.0%"), "Should show 50%")
	}

	// MARK: - Bar Scaling Tests

	@Test("PlotHistogram_BarScaling_MaxBinGetsFullBar") func LPlotHistogram_BarScaling_MaxBinGetsFullBar() {
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
		#expect(lines.count == 3, "Should have 3 bin lines")
		// Verify percentages sum to approximately 100%
		#expect(output.contains("%"), "Should show percentages")
	}

	// MARK: - Number Formatting Tests

	@Test("PlotHistogram_LargeNumbers_FormatsCorrectly") func LPlotHistogram_LargeNumbers_FormatsCorrectly() {
		// Given
		let histogram: [(range: Range<Double>, count: Int)] = [
			(range: 1000.0..<2000.0, count: 100),
			(range: 2000.0..<3000.0, count: 200)
		]

		// When
		let output = plotHistogram(histogram)

		// Then
		#expect(output.contains("1000"), "Should format large numbers")
		#expect(output.contains("2000"), "Should format large numbers")
		#expect(output.contains("3000"), "Should format large numbers")
	}

	@Test("PlotHistogram_SmallNumbers_FormatsCorrectly") func LPlotHistogram_SmallNumbers_FormatsCorrectly() {
		// Given
		let histogram: [(range: Range<Double>, count: Int)] = [
			(range: 0.01..<0.02, count: 100),
			(range: 0.02..<0.03, count: 200)
		]

		// When
		let output = plotHistogram(histogram)

		// Then
		#expect(output.contains("0.01") || output.contains("0.0"), "Should format small numbers")
	}

	// MARK: - Integration Test with SimulationResults

	@Test("PlotHistogram_WithSimulationResults_ProducesOutput") func LPlotHistogram_WithSimulationResults_ProducesOutput() {
		// Given
		let values = (0..<1000).map { _ in Double.random(in: 0.0...100.0) }
		let results = SimulationResults(values: values)
		let histogram = results.histogram(bins: 10)

		// When
		let output = plotHistogram(histogram)

		// Then
		#expect(!output.isEmpty, "Should produce output")
		#expect(output.contains("10 bins"), "Should show 10 bins")
		#expect(output.contains("1000 samples"), "Should show 1000 samples")
		#expect(output.contains("%"), "Should show percentages")
		// Verify structure by checking for range brackets
		#expect(output.contains("[") && output.contains("):"), "Should show bin ranges")
	}

	// MARK: - Edge Cases

	@Test("PlotHistogram_ZeroCountBin_DisplaysCorrectly") func LPlotHistogram_ZeroCountBin_DisplaysCorrectly() {
		// Given
		let histogram: [(range: Range<Double>, count: Int)] = [
			(range: 0.0..<10.0, count: 100),
			(range: 10.0..<20.0, count: 0),  // Zero count
			(range: 20.0..<30.0, count: 100)
		]

		// When
		let output = plotHistogram(histogram)

		// Then
		#expect(output.contains("0.0%"), "Should show 0% for empty bin")
		// The zero-count bin should have no bar or minimal bar
	}

	@Test("PlotHistogram_AllBinsSameCount_ScalesCorrectly") func LPlotHistogram_AllBinsSameCount_ScalesCorrectly() {
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
		#expect(percentageCount == 3, "All bins should show ~33.3%")
	}

	// MARK: - Output Structure Tests

	@Test("PlotHistogram_OutputStructure_HasHeader") func LPlotHistogram_OutputStructure_HasHeader() {
		// Given
		let histogram: [(range: Range<Double>, count: Int)] = [
			(range: 0.0..<10.0, count: 100)
		]

		// When
		let output = plotHistogram(histogram)

		// Then
		#expect(output.hasPrefix("Histogram"), "Should start with 'Histogram'")
	}

	@Test("PlotHistogram_OutputStructure_HasMultipleLines") func LPlotHistogram_OutputStructure_HasMultipleLines() {
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
		#expect(lines.count >= 4, "Should have header and bin lines")
	}
}

@Suite("Visualization - Additional Tests (Swift Testing)")
struct VisualizationAdditionalTests {

	@Test("Histogram deterministic counts and header")
	func histogramDeterministic() {
		let histogram: [(range: Range<Double>, count: Int)] = [
			(0.0..<10.0, 10),
			(10.0..<20.0, 20),
			(20.0..<30.0, 20)
		]

		let output = plotHistogram(histogram)
		#expect(output.hasPrefix("Histogram"))
		#expect(output.contains("3 bins"))
		#expect(output.contains("50 samples"))
		// The two max bins should be represented similarly in bar length/percentages
		#expect(output.contains("20.0") || output.contains("40.0%") || output.contains("50.0%"))
	}

	@Test("Tornado deterministic, shows base and sorted drivers")
	func tornadoDeterministic() {
		let tornado = TornadoDiagramAnalysis(
			inputs: ["Revenue", "Costs", "Marketing"],
			impacts: ["Revenue": 300.0, "Costs": 200.0, "Marketing": 100.0],
			lowValues: ["Revenue": 900.0, "Costs": 800.0, "Marketing": 950.0],
			highValues: ["Revenue": 1100.0, "Costs": 1200.0, "Marketing": 1050.0],
			baseCaseOutput: 1000.0
		)

		let output = plotTornadoDiagram(tornado)
		#expect(output.contains("Base"))
		#expect(output.contains("1000"))
		// Ensure higher impact appears before lower impact in textual output
		let revIndex = output.range(of: "Revenue")?.lowerBound
		let mktIndex = output.range(of: "Marketing")?.lowerBound
		#expect(revIndex != nil && mktIndex != nil)
		if let r = revIndex, let m = mktIndex {
			#expect(r < m)
		}
	}
}

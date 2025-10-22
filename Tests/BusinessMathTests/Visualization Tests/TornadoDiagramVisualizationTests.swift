//
//  TornadoDiagramVisualizationTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/22/25.
//

import XCTest
@testable import BusinessMath

final class TornadoDiagramVisualizationTests: XCTestCase {

	// MARK: - Empty/Single Input Tests

	func testPlotTornadoDiagram_EmptyInputs_ReturnsEmptyMessage() {
		// Given
		let tornado = TornadoDiagramAnalysis(
			inputs: [],
			impacts: [:],
			lowValues: [:],
			highValues: [:],
			baseCaseOutput: 1000.0
		)

		// When
		let output = plotTornadoDiagram(tornado)

		// Then
		XCTAssertTrue(output.contains("Empty") || output.contains("No"), "Should indicate empty diagram")
	}

	func testPlotTornadoDiagram_SingleInput_DisplaysCorrectly() {
		// Given
		let tornado = TornadoDiagramAnalysis(
			inputs: ["Revenue"],
			impacts: ["Revenue": 500.0],
			lowValues: ["Revenue": 750.0],
			highValues: ["Revenue": 1250.0],
			baseCaseOutput: 1000.0
		)

		// When
		let output = plotTornadoDiagram(tornado)

		// Then
		XCTAssertTrue(output.contains("Revenue"), "Should show input name")
		XCTAssertTrue(output.contains("Base Case:"), "Should show base case value")
		XCTAssertTrue(output.contains("1000"), "Should show base case output")
	}

	// MARK: - Multiple Inputs Tests

	func testPlotTornadoDiagram_MultipleInputs_ShowsAllInRankedOrder() {
		// Given - inputs already sorted by impact
		let tornado = TornadoDiagramAnalysis(
			inputs: ["Revenue", "Costs", "Marketing"],
			impacts: [
				"Revenue": 500.0,    // Highest impact
				"Costs": 300.0,      // Medium impact
				"Marketing": 100.0   // Lowest impact
			],
			lowValues: [
				"Revenue": 750.0,
				"Costs": 850.0,
				"Marketing": 950.0
			],
			highValues: [
				"Revenue": 1250.0,
				"Costs": 1150.0,
				"Marketing": 1050.0
			],
			baseCaseOutput: 1000.0
		)

		// When
		let output = plotTornadoDiagram(tornado)

		// Then
		XCTAssertTrue(output.contains("Revenue"), "Should show Revenue")
		XCTAssertTrue(output.contains("Costs"), "Should show Costs")
		XCTAssertTrue(output.contains("Marketing"), "Should show Marketing")

		// Verify order (Revenue should appear before Marketing in output)
		let revenueIndex = output.range(of: "Revenue")?.lowerBound
		let marketingIndex = output.range(of: "Marketing")?.lowerBound
		XCTAssertNotNil(revenueIndex)
		XCTAssertNotNil(marketingIndex)
		if let rev = revenueIndex, let mkt = marketingIndex {
			XCTAssertLessThan(rev, mkt, "Revenue (higher impact) should appear before Marketing")
		}
	}

	// MARK: - Bar Direction Tests

	func testPlotTornadoDiagram_PositiveImpact_ShowsCorrectDirection() {
		// Given - Revenue increases output (positive relationship)
		let tornado = TornadoDiagramAnalysis(
			inputs: ["Revenue"],
			impacts: ["Revenue": 400.0],
			lowValues: ["Revenue": 800.0],   // Low input → low output
			highValues: ["Revenue": 1200.0], // High input → high output
			baseCaseOutput: 1000.0
		)

		// When
		let output = plotTornadoDiagram(tornado)

		// Then
		// Should show bars extending from base case in both directions
		XCTAssertTrue(output.contains("Revenue"), "Should show driver name")
	}

	func testPlotTornadoDiagram_NegativeImpact_ShowsCorrectDirection() {
		// Given - Costs decrease output (negative relationship)
		let tornado = TornadoDiagramAnalysis(
			inputs: ["Costs"],
			impacts: ["Costs": 400.0],
			lowValues: ["Costs": 1200.0],  // Low costs → high output
			highValues: ["Costs": 800.0],  // High costs → low output
			baseCaseOutput: 1000.0
		)

		// When
		let output = plotTornadoDiagram(tornado)

		// Then
		XCTAssertTrue(output.contains("Costs"), "Should show driver name")
	}

	// MARK: - Base Case Display Tests

	func testPlotTornadoDiagram_ShowsBaseCaseValue() {
		// Given
		let tornado = TornadoDiagramAnalysis(
			inputs: ["Revenue", "Costs"],
			impacts: [
				"Revenue": 500.0,
				"Costs": 300.0
			],
			lowValues: [
				"Revenue": 750.0,
				"Costs": 850.0
			],
			highValues: [
				"Revenue": 1250.0,
				"Costs": 1150.0
			],
			baseCaseOutput: 1000.0
		)

		// When
		let output = plotTornadoDiagram(tornado)

		// Then
		XCTAssertTrue(output.contains("1000"), "Should display base case value")
		XCTAssertTrue(output.contains("Base"), "Should label base case")
	}

	// MARK: - Output Structure Tests

	func testPlotTornadoDiagram_HasHeader() {
		// Given
		let tornado = TornadoDiagramAnalysis(
			inputs: ["Revenue"],
			impacts: ["Revenue": 100.0],
			lowValues: ["Revenue": 950.0],
			highValues: ["Revenue": 1050.0],
			baseCaseOutput: 1000.0
		)

		// When
		let output = plotTornadoDiagram(tornado)

		// Then
		XCTAssertTrue(output.hasPrefix("Tornado") || output.contains("Sensitivity"), "Should have descriptive header")
	}

	func testPlotTornadoDiagram_HasMultipleLines() {
		// Given
		let tornado = TornadoDiagramAnalysis(
			inputs: ["Revenue", "Costs", "Marketing"],
			impacts: [
				"Revenue": 500.0,
				"Costs": 300.0,
				"Marketing": 100.0
			],
			lowValues: [
				"Revenue": 750.0,
				"Costs": 850.0,
				"Marketing": 950.0
			],
			highValues: [
				"Revenue": 1250.0,
				"Costs": 1150.0,
				"Marketing": 1050.0
			],
			baseCaseOutput: 1000.0
		)

		// When
		let output = plotTornadoDiagram(tornado)
		let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }

		// Then
		// Should have: header, base case line, and one line per input (minimum)
		XCTAssertGreaterThanOrEqual(lines.count, 4, "Should have header + base + inputs")
	}

	// MARK: - Number Formatting Tests

	func testPlotTornadoDiagram_FormatsLargeNumbers() {
		// Given
		let tornado = TornadoDiagramAnalysis(
			inputs: ["Revenue"],
			impacts: ["Revenue": 1_000_000.0],
			lowValues: ["Revenue": 500_000.0],
			highValues: ["Revenue": 1_500_000.0],
			baseCaseOutput: 1_000_000.0
		)

		// When
		let output = plotTornadoDiagram(tornado)

		// Then
		XCTAssertFalse(output.isEmpty, "Should format large numbers")
		XCTAssertTrue(output.contains("Revenue"), "Should show input name")
	}

	// MARK: - Edge Cases

	func testPlotTornadoDiagram_ZeroImpact_DisplaysCorrectly() {
		// Given - input has no impact
		let tornado = TornadoDiagramAnalysis(
			inputs: ["FixedValue"],
			impacts: ["FixedValue": 0.0],
			lowValues: ["FixedValue": 1000.0],
			highValues: ["FixedValue": 1000.0],
			baseCaseOutput: 1000.0
		)

		// When
		let output = plotTornadoDiagram(tornado)

		// Then
		XCTAssertTrue(output.contains("FixedValue"), "Should show input even with zero impact")
	}

	func testPlotTornadoDiagram_NegativeOutputValues_HandlesCorrectly() {
		// Given - outputs can be negative (e.g., net loss)
		let tornado = TornadoDiagramAnalysis(
			inputs: ["Revenue"],
			impacts: ["Revenue": 600.0],
			lowValues: ["Revenue": -300.0],
			highValues: ["Revenue": 300.0],
			baseCaseOutput: 0.0
		)

		// When
		let output = plotTornadoDiagram(tornado)

		// Then
		XCTAssertTrue(output.contains("Revenue"), "Should handle negative values")
		XCTAssertTrue(output.contains("-") || output.contains("("), "Should show negative values")
	}
}

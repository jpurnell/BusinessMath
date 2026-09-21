//
//  TornadoBarGeometryTests.swift
//  BusinessMath
//
//  `plotTornadoDiagram` crashed the process for any base case that was not the exact
//  midpoint of its driver's range.
//
//  The renderer scaled a bar to `maxBarWidth * 2` columns and then split it at the base
//  case's position, but padded each half into `maxBarWidth` columns. `String(repeating:count:)`
//  traps on a negative count, so `maxBarWidth - leftWidth` going negative was a fatal error,
//  not a mis-drawn chart: `Swift/StringLegacy.swift:31: Fatal error: Negative count not allowed`,
//  signal 5.
//
//  Every one of the ten fixtures in `TornadoDiagramVisualizationTests` was symmetric about
//  its base case — 750/1000/1250, 800/1000/1200, 950/1000/1050, 500k/1M/1.5M, -300/0/300 —
//  which is the one position where that subtraction lands on zero instead of going negative.
//  The suite sampled a single point ten times.
//

import Testing
@testable import BusinessMath

@Suite("TornadoBarGeometryTests") struct TornadoBarGeometryTests {

	/// The widths of the two half-bars on the first (and here, only) rendered input row.
	///
	/// Counting the block characters either side of the `|` is the only way to see what the
	/// renderer actually decided; the string assertions in the older suite pass whatever the
	/// bars do.
	private func halfBarWidths(_ output: String) throws -> (left: Int, right: Int) {
		let row = try #require(
			output.split(whereSeparator: \.isNewline).first(where: { $0.contains("◄") }),
			"expected a rendered bar row"
		)
		let afterLeftArrow = try #require(row.split(separator: "◄").last)
		let halves = afterLeftArrow.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
		#expect(halves.count == 2, "a bar row carries exactly one base-case marker")
		let left = halves[0].filter { $0 == "█" }.count
		let right = halves[1].filter { $0 == "█" }.count
		return (left, right)
	}

	private func oneInput(low: Double, high: Double, base: Double, impact: Double) -> TornadoDiagramAnalysis {
		TornadoDiagramAnalysis(
			inputs: ["Revenue"],
			impacts: ["Revenue": impact],
			lowValues: ["Revenue": low],
			highValues: ["Revenue": high],
			baseCaseOutput: base
		)
	}

	// MARK: - The crash

	/// The defect, at the smallest displacement that reaches it.
	///
	/// Base at 1100 in a range of 750...1250 gives `fractionLeft = 0.7`, so the old code asked
	/// for 35 columns in a 25-column slot.
	@Test("BaseAboveMidpoint_Renders") func baseAboveMidpointRenders() throws {
		let output = plotTornadoDiagram(oneInput(low: 750, high: 1250, base: 1100, impact: 500))
		let widths = try halfBarWidths(output)
		// The base sits 350 above the low end and 150 below the high end; the wider of those
		// two earns the full budget.
		#expect(widths.left == 25, "the wider half fills its budget")
		#expect(widths.right == 10, "the narrower half is 150/350 of it")
	}

	@Test("BaseBelowMidpoint_Renders") func baseBelowMidpointRenders() throws {
		let output = plotTornadoDiagram(oneInput(low: 750, high: 1250, base: 800, impact: 500))
		let widths = try halfBarWidths(output)
		#expect(widths.left == 2, "50/450 of the budget")
		#expect(widths.right == 25, "the wider half fills its budget")
	}

	/// A base case outside the range entirely — which `runTornadoAnalysis` can produce whenever
	/// the base case is not one of the sampled points and the response is not monotone.
	@Test("BaseOutsideRange_Renders") func baseOutsideRangeRenders() throws {
		let output = plotTornadoDiagram(oneInput(low: 750, high: 1250, base: 2000, impact: 500))
		let widths = try halfBarWidths(output)
		#expect(widths.left == 25, "the whole range lies below the base case")
		#expect(widths.right == 0, "and nothing above it")
	}

	// MARK: - The rounding artifact the fix also removes

	/// A symmetric input used to render asymmetrically.
	///
	/// The old code truncated the *total* first — `Int(50 * 95/500) = Int(9.5) = 9` — then took
	/// `Int(9 * 0.5) = 4` for the left and gave the remaining 5 to the right by subtraction. The
	/// two halves of this input are equal, so the extra column was pure rounding.
	@Test("SymmetricInput_RendersEqualHalves") func symmetricInputRendersEqualHalves() throws {
		let analysis = TornadoDiagramAnalysis(
			inputs: ["Revenue", "Marketing"],
			impacts: ["Revenue": 500.0, "Marketing": 95.0],
			lowValues: ["Revenue": 750.0, "Marketing": 952.5],
			highValues: ["Revenue": 1250.0, "Marketing": 1047.5],
			baseCaseOutput: 1000.0
		)
		let output = plotTornadoDiagram(analysis)
		let marketingRow = try #require(
			output.split(whereSeparator: \.isNewline).first(where: { $0.contains("Marketing") && $0.contains("◄") })
		)
		let widths = try halfBarWidths(String(marketingRow))
		#expect(widths.left == widths.right, "equal half-spans draw equal half-bars")
		#expect(widths.left == 4, "47.5 of a 250 scale, over 25 columns")
	}

	// MARK: - Values the public initialiser admits

	/// `TornadoDiagramAnalysis.init` is public and takes raw dictionaries, so a caller can hand
	/// the renderer anything a model produced — including the results of a division by zero.
	/// `Int(_:)` traps on NaN and on infinity as surely as on a negative count.
	@Test("NonFiniteValues_DoNotTrap", arguments: [
		Double.nan, Double.infinity, -Double.infinity
	]) func nonFiniteValuesDoNotTrap(bad: Double) {
		let withBadHigh = plotTornadoDiagram(oneInput(low: 750, high: bad, base: 1000, impact: 500))
		#expect(withBadHigh.contains("Revenue"), "a non-finite high end renders")

		let withBadLow = plotTornadoDiagram(oneInput(low: bad, high: 1250, base: 1000, impact: 500))
		#expect(withBadLow.contains("Revenue"), "a non-finite low end renders")

		let withBadBase = plotTornadoDiagram(oneInput(low: 750, high: 1250, base: bad, impact: 500))
		#expect(withBadBase.contains("Revenue"), "a non-finite base case renders")

		let withBadImpact = plotTornadoDiagram(oneInput(low: 750, high: 1250, base: 1000, impact: bad))
		#expect(withBadImpact.contains("Revenue"), "a non-finite impact renders")
	}

	// MARK: - The conversion itself

	/// The one place a bar width crosses from `Double` to `Int`, checked at its edges.
	@Test("BarWidth_StaysInBudget") func barWidthStaysInBudget() {
		#expect(tornadoBarWidth(span: 1, scale: 0, limit: 25) == 0, "a zero scale renders nothing")
		#expect(tornadoBarWidth(span: 0, scale: 1, limit: 25) == 0, "a zero span renders nothing")
		#expect(tornadoBarWidth(span: -5, scale: 1, limit: 25) == 0, "a negative span renders nothing")
		#expect(tornadoBarWidth(span: 1, scale: 1, limit: 25) == 25, "a full span fills the budget")
		#expect(tornadoBarWidth(span: 100, scale: 1, limit: 25) == 25, "and cannot exceed it")
		#expect(tornadoBarWidth(span: .nan, scale: 1, limit: 25) == 0, "NaN renders nothing")
		#expect(tornadoBarWidth(span: .infinity, scale: 1, limit: 25) == 25, "infinity saturates")
		#expect(tornadoBarWidth(span: 1, scale: .infinity, limit: 25) == 0, "an infinite scale renders nothing")
		#expect(tornadoBarWidth(span: 1, scale: 1, limit: 0) == 0, "a zero budget renders nothing")
	}

	/// The half-spans sort their ends, because `low`/`high` name the *driver*, not the output.
	@Test("HalfSpans_SortTheirEnds") func halfSpansSortTheirEnds() {
		let ascending = tornadoHalfSpans(low: 800, high: 1200, base: 1000)
		let descending = tornadoHalfSpans(low: 1200, high: 800, base: 1000)
		#expect(ascending.left == descending.left, "a cost driver is the same bar")
		#expect(ascending.right == descending.right, "a cost driver is the same bar")
		#expect(ascending.left == 200)
		#expect(ascending.right == 200)
	}
}

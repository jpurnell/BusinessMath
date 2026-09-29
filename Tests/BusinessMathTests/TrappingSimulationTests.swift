//
//  TrappingSimulationTests.swift
//  BusinessMath
//
//  Six trapping `Int(_:)` conversions in the simulation, streaming and operations layers.
//
//  `Int(_:)` on a `Double` is a *trapping* conversion: it crashes the process on a non-finite
//  value and on anything outside `Int`'s range (`Int.max ~= 9.22e18`). A trap takes down the
//  whole process, not one call — so every test below asserts that the call now *returns* a
//  contracted value where it previously died.
//
//  Two of the six need no contaminated input at all. `formattedPercentiles` was fatal for any
//  loss distribution, which is the normal shape for a risk simulation, and `histogram()` was
//  fatal for a heavy tail over a tight interquartile core. Those two carry an extra control
//  built from realistic data, because that is what makes them live defects rather than
//  theoretical ones.
//

import Foundation
import Testing
import TestSupport  // testHangGuard — turns a would-be hang into a failure
@testable import BusinessMath

@Suite("Trapping Int conversions — simulation, streaming, operations")
struct TrappingSimulationTests {

	// MARK: - (a) SimulationResults.formattedPercentiles — the display scale

	/// The percentile table is right-aligned to a width derived from `log10`, and every
	/// component of that derivation is reachable with ordinary finite data. The field itself
	/// is always exactly `width` characters — `paddingLeft(toLength:)` pads when short and
	/// truncates when long — so the line length pins the computed width exactly.
	///
	/// `"   P5: "` is 7 characters, hence `lineLength == 7 + width`.

	@Test("formattedPercentiles: an all-zero sample no longer traps on log10(0) = -infinity")
	func formattedPercentilesAllZeroSample() {
		let results = SimulationResults(values: Array(repeating: 0.0, count: 20))

		let formatted = results.formattedPercentiles
		let lines = formatted.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)

		// Header plus P5, P10, P25, P50, P75, P90, P95, P99.
		#expect(lines.count == 9)
		#expect(lines[0] == "Percentiles:")
		// Degraded width is the bare padding, 7. Line = 7 label characters + 7 field.
		#expect(lines[1].count == 14)
		let renderedP50 = results.percentiles.p50.number(1)
		#expect(lines[4].contains(renderedP50))
	}

	@Test("formattedPercentiles: a loss distribution no longer traps on log10(negative) = nan")
	func formattedPercentilesLossDistribution() {
		// Realistic control for the *live* path: a P&L simulation running from a 60k loss to a
		// 39k gain. Negative percentiles are the normal case here, not contamination, and
		// `log10` of a negative number is `nan` — which is what used to kill the process.
		let values = (0..<100).map { Double($0) * 1000.0 - 60_000.0 }
		let results = SimulationResults(values: values)

		#expect(results.percentiles.p5 < 0.0)
		#expect(results.percentiles.p99 > 0.0)

		let formatted = results.formattedPercentiles
		let lines = formatted.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)

		#expect(lines.count == 9)
		// |p5| is about 55,000, so log10 rounds up to 5 integer digits: width 5 + 7 = 12,
		// and the line is 7 label characters + 12 field.
		#expect(lines[1].count == 19)
		let renderedP5 = results.percentiles.p5.number(1)
		#expect(lines[1].contains(renderedP5))
	}

	@Test("formattedPercentiles: an undefined Percentiles no longer traps on nan fields")
	func formattedPercentilesUndefinedPercentiles() {
		// `Percentiles(values:)` refuses a non-finite sample, so `SimulationResults` falls back
		// to `.undefined(values:)`, whose fields are `nan` by design. That reaches the same
		// conversion with no arithmetic at all.
		let results = SimulationResults(values: [1.0, 2.0, Double.nan, 4.0])

		#expect(results.percentiles.p5.isNaN)

		let formatted = results.formattedPercentiles
		let lines = formatted.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)

		#expect(lines.count == 9)
		#expect(lines[1].count == 14)
		#expect(lines[8].hasPrefix("  P99:"))
	}

	@Test("formattedPercentiles: clean positive sample keeps the width it always had")
	func formattedPercentilesCleanControl() {
		// Control — passes before and after the fix. Values 90...110, so p99 is about 110:
		// three integer digits, width 3 + 7 = 10, line 7 + 10 = 17.
		let values = (0..<21).map { 90.0 + Double($0) }
		let results = SimulationResults(values: values)

		let formatted = results.formattedPercentiles
		let lines = formatted.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)

		#expect(lines.count == 9)
		#expect(lines[1].count == 17)
		#expect(lines[4].contains("(Median)"))
	}

	// MARK: - (b) SimulationResults.histogram — the Freedman-Diaconis bin count

	@Test("histogram: a heavy tail over a tight core no longer traps the bin conversion")
	func histogramHeavyTailBinCount() {
		// Freedman-Diaconis divides the *full range* by a width derived from the
		// *interquartile core*. A tight core (0...198) under one extreme observation (1e308)
		// asks for about 2.9e306 bins — finite, no infinity anywhere, and far outside `Int`.
		var values = (0..<199).map { Double($0) }
		values.append(1e308)

		let results = SimulationResults(values: values)
		let bins = results.histogram()

		// Bounded to the maximum this function has always documented and always clamped to.
		#expect(bins.count == 1000)
		#expect(bins[0].range.lowerBound.isEqual(to: 0.0))
		// The bins still tile the real range: min is 0 and max is 1e308, so each is 1e305 wide.
		let expectedFirstUpperBound = 1e308 / 1000.0
		#expect(bins[0].range.upperBound.isEqual(to: expectedFirstUpperBound))
	}

	@Test("histogram: an ordinary well-conditioned sample is unchanged")
	func histogramWellConditionedControl() {
		// Control — passes before and after the fix. n = 100, so Sturges asks for
		// ceil(log2(100) + 1) = 8 bins; Freedman-Diaconis asks for about 5 (IQR ~= 49.5,
		// binWidth ~= 21.3, range 99), so the documented maximum of the two is 8.
		let values = (0..<100).map { Double($0) }
		let results = SimulationResults(values: values)

		let bins = results.histogram()

		#expect(bins.count == 8)
		#expect(bins[0].range.lowerBound.isEqual(to: 0.0))
		// The final bin's upper bound is nudged past the maximum, so every value is binned.
		let binned = bins.reduce(0) { $0 + $1.count }
		#expect(binned == 100)
	}

	// MARK: - (c)/(d) FrequencySpectrum.power(in:) — unbounded frequency ranges

	/// A spectrum with resolution 0.5 Hz: bins sit at 0.0, 0.5, 1.0 and 1.5 Hz.
	private static let bandSpectrum = FrequencySpectrum(
		powers: [1.0, 2.0, 3.0, 4.0],
		sampleRate: 4.0,
		sampleCount: 8
	)

	@Test("power(in:) answers an infinite upper bound with all the remaining power")
	func powerInfiniteUpperBound() {
		let spectrum = Self.bandSpectrum

		// "All the power above 0.15 Hz" — bins at 0.5, 1.0 and 1.5 Hz qualify; the DC bin
		// at 0.0 Hz does not.
		let result = spectrum.power(in: 0.15 ..< .infinity)

		let expected = spectrum.powers[1] + spectrum.powers[2] + spectrum.powers[3]
		#expect(result.isEqual(to: expected))
	}

	@Test("power(in:) answers an infinite lower bound without trapping")
	func powerInfiniteLowerBound() {
		let spectrum = Self.bandSpectrum

		// Everything below 1.2 Hz: bins at 0.0, 0.5 and 1.0 Hz.
		let result = spectrum.power(in: -.infinity ..< 1.2)

		let expected = spectrum.powers[0] + spectrum.powers[1] + spectrum.powers[2]
		#expect(result.isEqual(to: expected))
	}

	@Test("power(in:) survives a finite bound that overflows Int after division")
	func powerHugeFiniteUpperBound() {
		let spectrum = Self.bandSpectrum

		// No infinity involved: 1e300 / 0.5 is 2e300, which is finite and still far outside
		// `Int`. The clamp has to happen in `Double`, before the conversion.
		let result = spectrum.power(in: 0.0 ..< 1e300)

		let head = spectrum.powers[0] + spectrum.powers[1]
		let tail = spectrum.powers[2] + spectrum.powers[3]
		let expected = head + tail
		#expect(result.isEqual(to: expected))
	}

	@Test("power(in:) reports nan when the bin index is genuinely undeterminable")
	func powerUndeterminableBinIndex() {
		// An infinite sample rate makes the resolution infinite, and `infinity / infinity` is
		// `nan` — the one case with no defensible bin index. Per the contaminated-input
		// contract a non-throwing floating-point API answers `nan`, not `0`: a `0` here would
		// read as a measurement of "no power in this band".
		let spectrum = FrequencySpectrum(powers: [1.0, 2.0, 3.0, 4.0], sampleRate: .infinity, sampleCount: 8)

		let result = spectrum.power(in: 0.15 ..< .infinity)

		#expect(result.isNaN)
	}

	@Test("power(in:) on an ordinary bounded band is unchanged")
	func powerBoundedBandControl() {
		// Control — passes before and after the fix. Bins at 0.5 and 1.0 Hz fall in [0.4, 1.2).
		let spectrum = Self.bandSpectrum

		let result = spectrum.power(in: 0.4 ..< 1.2)

		let expected = spectrum.powers[1] + spectrum.powers[2]
		#expect(result.isEqual(to: expected))
	}

	// MARK: - (e)/(f) InventorySimulator — lead time is a conversion *and* a loop bound

	/// A small, well-behaved demand history shared by the lead-time screening tests.
	private static let demandHistory: [Double] = [100.0, 110.0, 120.0, 130.0, 105.0, 118.0]

	@Test("simulate: a nan mean lead time is refused instead of trapping")
	func simulateRejectsNaNMeanLeadTime() throws {
		#expect {
			// Seeded for reproducibility only: the lead time is refused before any path is
			// drawn, so the assertion cannot vary.
			_ = try InventorySimulator.simulate(
				demandHistory: Self.demandHistory,
				meanLeadTime: Double.nan,
				serviceLevel: 0.95,
				iterations: 10,
				seed: 0x1_11_5E_10
			)
		} throws: { error in
			guard case let OperationsError.invalidParameter(message) = error else { return false }
			return message.contains("meanLeadTime")
		}
	}

	@Test("simulate: an infinite mean lead time is refused instead of trapping")
	func simulateRejectsInfiniteMeanLeadTime() throws {
		#expect {
			// Seeded for reproducibility only: refused before any path is drawn.
			_ = try InventorySimulator.simulate(
				demandHistory: Self.demandHistory,
				meanLeadTime: Double.infinity,
				serviceLevel: 0.95,
				iterations: 10,
				seed: 0x1_11_5E_11
			)
		} throws: { error in
			guard case let OperationsError.invalidParameter(message) = error else { return false }
			return message.contains("meanLeadTime")
		}
	}

	@Test(
		"simulate: an enormous *finite* mean lead time is refused, not run",
		.timeLimit(testHangGuard)
	)
	func simulateRejectsUnboundedLoopMeanLeadTime() throws {
		// This is the case a finiteness-only patch would miss. 1e18 converts to `Int`
		// perfectly well and then becomes the trip count of the inner sampling loop, so the
		// crash becomes a run that never returns — which tells the caller even less.
		#expect {
			// Seeded for reproducibility only: refused before any path is drawn.
			_ = try InventorySimulator.simulate(
				demandHistory: Self.demandHistory,
				meanLeadTime: 1e18,
				serviceLevel: 0.95,
				iterations: 10,
				seed: 0x1_11_5E_12
			)
		} throws: { error in
			guard case let OperationsError.invalidParameter(message) = error else { return false }
			return message.contains("meanLeadTime")
		}
	}

	@Test("simulate: a nan lead-time standard deviation is refused instead of trapping")
	func simulateRejectsNaNLeadTimeStdDev() throws {
		#expect {
			// Seeded for reproducibility only: refused before any path is drawn.
			_ = try InventorySimulator.simulate(
				demandHistory: Self.demandHistory,
				meanLeadTime: 7.0,
				leadTimeStdDev: Double.nan,
				serviceLevel: 0.95,
				iterations: 10,
				seed: 0x1_11_5E_13
			)
		} throws: { error in
			guard case let OperationsError.invalidParameter(message) = error else { return false }
			return message.contains("leadTimeStdDev")
		}
	}

	@Test(
		"simulate: an enormous *finite* lead-time standard deviation is refused, not run",
		.timeLimit(testHangGuard)
	)
	func simulateRejectsUnboundedLoopLeadTimeStdDev() throws {
		#expect {
			// Seeded for reproducibility only: refused before any path is drawn.
			_ = try InventorySimulator.simulate(
				demandHistory: Self.demandHistory,
				meanLeadTime: 7.0,
				leadTimeStdDev: 1e18,
				serviceLevel: 0.95,
				iterations: 10,
				seed: 0x1_11_5E_14
			)
		} throws: { error in
			guard case let OperationsError.invalidParameter(message) = error else { return false }
			return message.contains("leadTimeStdDev")
		}
	}

	@Test("simulate: a negative mean lead time is refused rather than silently read as one period")
	func simulateRejectsNegativeMeanLeadTime() throws {
		#expect {
			// Seeded for reproducibility only: refused before any path is drawn.
			_ = try InventorySimulator.simulate(
				demandHistory: Self.demandHistory,
				meanLeadTime: -5.0,
				serviceLevel: 0.95,
				iterations: 10,
				seed: 0x1_11_5E_15
			)
		} throws: { error in
			guard case let OperationsError.invalidParameter(message) = error else { return false }
			return message.contains("meanLeadTime")
		}
	}

	@Test("simulate: the lead-time ceiling is inclusive and terminates", .timeLimit(testHangGuard))
	func simulateRunsAtTheLeadTimeCeiling() throws {
		// 100,000 periods is the documented ceiling; one period past it is refused, and at it
		// the run must still finish. Constant demand of 10.0 makes every path identical, so
		// the answer is exact: 100,000 x 10.0 = 1,000,000.
		let result = try InventorySimulator.simulate(
			demandHistory: Array(repeating: 10.0, count: 5),
			meanLeadTime: 100_000.0,
			serviceLevel: 0.95,
			iterations: 2,
			seed: 0x1_11_5E_16
		)

		#expect(result.pathCount == 2)
		#expect(result.reorderPoint.isEqual(to: 1_000_000.0))
		#expect(result.safetyStock.isEqual(to: 0.0))
	}

	@Test("simulate: one period past the ceiling is refused")
	func simulateRejectsJustPastTheLeadTimeCeiling() throws {
		#expect {
			// Seeded for reproducibility only: refused before any path is drawn.
			_ = try InventorySimulator.simulate(
				demandHistory: Self.demandHistory,
				meanLeadTime: 100_001.0,
				serviceLevel: 0.95,
				iterations: 10,
				seed: 0x1_11_5E_17
			)
		} throws: { error in
			guard case let OperationsError.invalidParameter(message) = error else { return false }
			return message.contains("meanLeadTime")
		}
	}

	@Test("simulate: an ordinary lead time still runs unchanged")
	func simulateOrdinaryLeadTimeControl() throws {
		// Control — passes before and after the fix.
		let result = try InventorySimulator.simulate(
			demandHistory: Self.demandHistory,
			meanLeadTime: 7.0,
			leadTimeStdDev: 2.0,
			serviceLevel: 0.95,
			iterations: 200,
			seed: 42
		)

		#expect(result.pathCount == 200)
		// The safety stock is defined as the gap between the reorder point and mean DDLT.
		let expectedSafetyStock = result.reorderPoint - result.demandDuringLeadTimeMean
		#expect(result.safetyStock.isEqual(to: expectedSafetyStock))
		// A 95% service level sits above the mean of a non-degenerate DDLT distribution.
		#expect(result.reorderPoint > result.demandDuringLeadTimeMean)
		#expect(result.demandDuringLeadTimeStdDev > 0.0)
	}
}

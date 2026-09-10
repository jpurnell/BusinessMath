//
//  ETSSeasonalityTests.swift
//  BusinessMath
//
//  RED phase — step 2 of PROPOSAL_ets_fitting.md.
//
//  `ETSSeasonality` names the three cases Excel encodes in one optional numeric argument,
//  and the resolution over `dominantSeasonLength(maxLag:)` is what closes
//  FORECAST.ETS.SEASONALITY. Nothing here reimplements detection — these tests assert that
//  the named surface delegates to the detection that already existed.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("ETS seasonality — naming the three cases Excel encodes as a number")
struct ETSSeasonalityTests {

	// MARK: - Fixtures

	/// A clean additive seasonal series: level + trend + a cycle of length `m`.
	private func seasonalSeries(cycle m: Int, cycles: Int) -> TimeSeries<Double> {
		let n = m * cycles
		var values: [Double] = []
		values.reserveCapacity(n)
		for t in 0..<n {
			let phase: Double = Double(t % m) / Double(m)
			let seasonal: Double = 20.0 * Foundation.sin(2.0 * Double.pi * phase)
			let level: Double = 100.0 + 0.5 * Double(t)
			values.append(level + seasonal)
		}
		let periods = (0..<n).map { Period.month(year: 2020 + $0 / 12, month: $0 % 12 + 1) }
		return TimeSeries(periods: periods, values: values)
	}

	/// A deterministic pseudo-random series with no cycle for the ACF to find.
	///
	/// The seed is stated at every call site rather than defaulted, so a failure names the
	/// exact sequence that produced it.
	private func noiseSeries(count n: Int, seed: UInt64) -> TimeSeries<Double> {
		var state = seed
		var values: [Double] = []
		values.reserveCapacity(n)
		let scale = Double(UInt64(1) << 53)
		for _ in 0..<n {
			state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
			let draw = Double(state >> 11)
			values.append(draw / scale)
		}
		let periods = (0..<n).map { Period.month(year: 2020 + $0 / 12, month: $0 % 12 + 1) }
		return TimeSeries(periods: periods, values: values)
	}

	// MARK: - The named detection entry point

	@Test("detectedSeasonLength recovers the cycle a series was built from")
	func detectionRecoversCycle() throws {
		let series = seasonalSeries(cycle: 12, cycles: 6)
		let detected = try #require(series.detectedSeasonLength())
		#expect(detected == 12)
	}

	@Test("detectedSeasonLength recovers a short cycle too")
	func detectionRecoversShortCycle() throws {
		let series = seasonalSeries(cycle: 4, cycles: 12)
		let detected = try #require(series.detectedSeasonLength())
		#expect(detected == 4)
	}

	@Test("detectedSeasonLength returns nil when nothing clears the white-noise band")
	func detectionRefusesNoise() {
		let series = noiseSeries(count: 96, seed: 20_260_909)
		#expect(series.detectedSeasonLength() == nil)
	}

	// MARK: - Resolving a choice

	@Test("`.none` resolves to a non-seasonal cycle length of 1")
	func noneResolvesToOne() throws {
		let series = seasonalSeries(cycle: 12, cycles: 6)
		let resolution = try series.resolvedSeasonality(.none)
		#expect(resolution.length == 1)
		#expect(resolution.wasDetected == false)
	}

	@Test("`.detect` resolves to the detected cycle and records that it was detected")
	func detectResolvesToDetectedCycle() throws {
		let series = seasonalSeries(cycle: 12, cycles: 6)
		let resolution = try series.resolvedSeasonality(.detect)
		#expect(resolution.length == 12)
		#expect(resolution.wasDetected == true)
	}

	@Test("`.detect` falls back to non-seasonal when there is no detectable pattern")
	func detectFallsBackOnNoise() throws {
		let series = noiseSeries(count: 96, seed: 20_260_909)
		let resolution = try series.resolvedSeasonality(.detect)
		#expect(resolution.length == 1)
		#expect(resolution.wasDetected == false)
	}

	@Test("`.periods(n)` resolves to exactly what the caller asked for")
	func explicitPeriodsAreHonoured() throws {
		// Deliberately not the cycle the series was built from: an explicit length is not
		// advice, and detection must not override it.
		let series = seasonalSeries(cycle: 12, cycles: 6)
		let resolution = try series.resolvedSeasonality(.periods(6))
		#expect(resolution.length == 6)
		#expect(resolution.wasDetected == false)
	}

	@Test("`.periods(1)` is the non-seasonal case spelled explicitly")
	func explicitOneIsNonSeasonal() throws {
		let series = seasonalSeries(cycle: 12, cycles: 6)
		let resolution = try series.resolvedSeasonality(.periods(1))
		#expect(resolution.length == 1)
		#expect(resolution.wasDetected == false)
	}

	// MARK: - Refusals

	@Test("A non-positive explicit cycle length throws", arguments: [0, -1, -12])
	func nonPositivePeriodsThrow(length: Int) {
		let series = seasonalSeries(cycle: 12, cycles: 6)
		#expect(throws: ForecastError.self) {
			_ = try series.resolvedSeasonality(.periods(length))
		}
	}

	// MARK: - The enum itself

	@Test("ETSSeasonality is Equatable so a binding can compare what it built")
	func equatability() {
		#expect(ETSSeasonality.none == ETSSeasonality.none)
		#expect(ETSSeasonality.detect == ETSSeasonality.detect)
		#expect(ETSSeasonality.periods(12) == ETSSeasonality.periods(12))
		#expect(ETSSeasonality.periods(12) != ETSSeasonality.periods(4))
		#expect(ETSSeasonality.none != ETSSeasonality.detect)
	}
}

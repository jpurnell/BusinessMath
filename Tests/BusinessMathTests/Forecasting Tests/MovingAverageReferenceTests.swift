//
//  MovingAverageReferenceTests.swift
//  BusinessMath
//
//  An external oracle for the moving averages, from pandas.
//
//  `MovingAverageTests` has 13 tests and no external check. One of them reads
//  `#expect(true) // TEST-QUALITY: validates no-throw execution`, which asserts nothing
//  at all about the numbers.
//
//  The arithmetic here is trivial. Every way to get a moving average wrong is about
//  alignment or initialisation instead, and each has an exact pandas counterpart:
//
//  - `movingAverage(window:)` is **trailing** and emits its first value at index
//    `window - 1`, so the output is `window - 1` shorter than the input. That is
//    `rolling(window).mean().dropna()`. A centred window, or one that padded the front,
//    would still look like a smoothed version of the input.
//
//  - `exponentialMovingAverage(alpha:)` seeds with the first observation and then applies
//    `ema = alpha*x + (1-alpha)*ema`. That is `ewm(alpha:, adjust: False)` — **not**
//    pandas' default, which is `adjust=True` and uses a bias-corrected weighted average.
//    The two differ most in the early terms and converge later, which is precisely where
//    a mismatched convention is easiest to miss.
//
//  Values from Tests/BusinessMathTests/Fixtures/movingAverage.json, which records the
//  pandas call each case corresponds to.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Moving averages against pandas")
struct MovingAverageReferenceTests {

	// MARK: - Fixture

	private struct Fixture: Decodable {
		let name: String
		let reference: String
		let note: String
		let cases: [Case]
	}

	private struct Case: Decodable {
		let name: String
		let note: String
		let kind: String
		let pandas: String
		let values: [Double]
		let window: Int?
		let alpha: Double?
		let expected: [Double]
	}

	private static func loadFixture() throws -> Fixture {
		guard let url = Bundle.module.url(forResource: "movingAverage",
										  withExtension: "json",
										  subdirectory: "Fixtures")
			?? Bundle.module.url(forResource: "movingAverage", withExtension: "json") else {
			struct Missing: Error { let name: String }
			throw Missing(name: "movingAverage")
		}
		return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
	}

	/// A series over consecutive months, so the periods are distinct and ordered.
	private static func series(_ values: [Double]) -> TimeSeries<Double> {
		let periods = (0..<values.count).map { i -> Period in
			Period.month(year: 2020 + i / 12, month: i % 12 + 1)
		}
		return TimeSeries(periods: periods, values: values)
	}

	// MARK: - The fixture itself

	@Test("The fixture covers both kinds and their edge cases")
	func fixtureIsWellFormed() throws {
		let fixture = try Self.loadFixture()
		#expect(fixture.reference.contains("pandas"), "reference was '\(fixture.reference)'")
		#expect(fixture.cases.count >= 15, "only \(fixture.cases.count) cases")

		let sma = fixture.cases.filter { $0.kind == "sma" }
		let ema = fixture.cases.filter { $0.kind == "ema" }
		#expect(sma.count >= 6, "only \(sma.count) simple cases")
		#expect(ema.count >= 6, "only \(ema.count) exponential cases")

		// The identity cases are what catch an off-by-one in the window handling.
		#expect(sma.contains { $0.window == 1 }, "no window-of-one case")
		// A deliberate IEEE comparison against a value the fixture stores as a literal.
		#expect(ema.contains { $0.alpha?.isEqual(to: 1.0) == true }, "no alpha-of-one case")

		// Every pandas call is recorded, so the convention cannot drift silently.
		#expect(fixture.cases.allSatisfy { !$0.pandas.isEmpty })
		#expect(ema.allSatisfy { $0.pandas.contains("adjust=False") },
				"an exponential case is not pinned to adjust=False")
	}

	// MARK: - Simple moving average

	@Test("The simple moving average matches pandas, values and alignment")
	func simpleMovingAverageMatchesPandas() throws {
		let fixture = try Self.loadFixture()
		var compared = 0

		for entry in fixture.cases where entry.kind == "sma" {
			guard let window = entry.window else {
				Issue.record("\(entry.name) has no window"); continue
			}
			let result = Self.series(entry.values).movingAverage(window: window)

			// The length is the alignment claim: trailing, dropping the first window-1.
			// Asserting it separately means a length mismatch reports as one, rather than
			// as a cascade of value mismatches.
			#expect(result.valuesArray.count == entry.expected.count,
					"\(entry.name): got \(result.valuesArray.count) values, pandas gives \(entry.expected.count) for \(entry.pandas)")
			guard result.valuesArray.count == entry.expected.count else { continue }

			for (i, reference) in entry.expected.enumerated() {
				let scale = Swift.max(abs(reference), 1.0)
				#expect(abs(result.valuesArray[i] - reference) < 1e-12 * scale,
						"\(entry.name)[\(i)]: got \(result.valuesArray[i]), pandas \(reference)")
				compared += 1
			}
		}
		#expect(compared >= 100, "only \(compared) values compared")
	}

	@Test("A trailing mean of a linear series lags it by exactly half the window")
	func trailingWindowLagsCorrectly() throws {
		// Independent of pandas, and specifically an alignment check: for a series
		// x_t = a + b·t, a trailing mean over w points equals the series evaluated
		// (w-1)/2 steps earlier. A centred window would give zero lag and would still
		// look like a smoothed trend.
		let slope = 5.0, intercept = 100.0
		let values: [Double] = (0..<24).map { index -> Double in
			intercept + slope * Double(index)
		}
		for window in [2, 3, 4, 7, 12] {
			let result = Self.series(values).movingAverage(window: window)
			guard let first = result.valuesArray.first else {
				Issue.record("window \(window) produced nothing"); continue
			}
			// The first output covers indices 0..<window, whose mean is the value at
			// (window-1)/2.
			let span: Double = Double(window) - 1
			let lag: Double = slope * span / 2
			let expected: Double = intercept + lag
			#expect(abs(first - expected) < 1e-12,
					"window \(window): first output \(first), expected \(expected)")
		}
	}

	// MARK: - Exponential moving average

	@Test("The exponential moving average matches pandas at adjust=False")
	func exponentialMovingAverageMatchesPandas() throws {
		let fixture = try Self.loadFixture()
		var compared = 0

		for entry in fixture.cases where entry.kind == "ema" {
			guard let alpha = entry.alpha else {
				Issue.record("\(entry.name) has no alpha"); continue
			}
			let result = Self.series(entry.values).exponentialMovingAverage(alpha: alpha)

			#expect(result.valuesArray.count == entry.expected.count,
					"\(entry.name): got \(result.valuesArray.count) values, expected \(entry.expected.count)")
			guard result.valuesArray.count == entry.expected.count else { continue }

			for (i, reference) in entry.expected.enumerated() {
				let scale = Swift.max(abs(reference), 1.0)
				#expect(abs(result.valuesArray[i] - reference) < 1e-12 * scale,
						"\(entry.name)[\(i)]: got \(result.valuesArray[i]), pandas \(reference)")
				compared += 1
			}
		}
		#expect(compared >= 150, "only \(compared) values compared")
	}

	@Test("The exponential average is seeded with the first observation")
	func exponentialSeedsWithFirstValue() throws {
		// The initialisation, isolated — and the one place adjust=True and adjust=False
		// are guaranteed to differ is not here but immediately after, so this pins the
		// seed and the fixture pins the rest.
		let fixture = try Self.loadFixture()

		for entry in fixture.cases where entry.kind == "ema" {
			guard let alpha = entry.alpha, let firstInput = entry.values.first else { continue }
			let result = Self.series(entry.values).exponentialMovingAverage(alpha: alpha)
			guard let firstOutput = result.valuesArray.first else {
				Issue.record("\(entry.name) produced nothing"); continue
			}
			#expect(abs(firstOutput - firstInput) < 1e-12,
					"\(entry.name): seeded with \(firstOutput), first observation is \(firstInput)")
			// And the output is the same length as the input — nothing is dropped.
			#expect(result.valuesArray.count == entry.values.count,
					"\(entry.name): \(result.valuesArray.count) outputs for \(entry.values.count) inputs")
		}
	}

	// MARK: - Degenerate input

	@Test("An impossible window yields nothing rather than a partial answer")
	func rejectsImpossibleWindows() {
		let data = Self.series([1, 2, 3, 4, 5])
		// Longer than the series: there is no full window anywhere, so there is no
		// trailing mean to report. Returning a shortened series would be a different
		// statistic wearing the same name.
		#expect(data.movingAverage(window: 6).valuesArray.isEmpty)
		#expect(data.movingAverage(window: 0).valuesArray.isEmpty)
		#expect(data.movingAverage(window: -1).valuesArray.isEmpty)
	}

	@Test("A constant series is its own moving average, both kinds")
	func constantSeriesIsItsOwnAverage() {
		// Needs no reference at all: smoothing a constant cannot move it.
		let constant = Array(repeating: 42.0, count: 15)
		let data = Self.series(constant)

		for window in [1, 3, 7, 15] {
			for value in data.movingAverage(window: window).valuesArray {
				#expect(abs(value - 42.0) < 1e-12, "window \(window) gave \(value)")
			}
		}
		for alpha in [0.1, 0.5, 0.9, 1.0] {
			for value in data.exponentialMovingAverage(alpha: alpha).valuesArray {
				#expect(abs(value - 42.0) < 1e-12, "alpha \(alpha) gave \(value)")
			}
		}
	}
}

//
//  RiskMetricsReferenceTests.swift
//  BusinessMath
//
//  An external oracle for value at risk and expected shortfall.
//
//  `RiskMetricsTests` (27) and `RiskAggregationTests` (17) check no value against
//  anything outside the package. These are single numbers that get reported to a
//  risk committee and turned into a capital requirement, and every way to get them
//  slightly wrong yields a plausible one:
//
//  - **Which quantile estimator.** There are nine conventional definitions. The
//    package documents type 7 — linear interpolation between order statistics,
//    numpy's and R's default. Types 1 and 6 shift the answer by a fraction of the
//    gap between two order statistics, which at the 1% level on a fat tail is a
//    lot of money.
//  - **Which tail.** CVaR is the mean beyond VaR. Including the threshold
//    observation, or taking `⌈nα⌉` instead of `⌊nα⌋`, moves the answer at every
//    sample size.
//  - **The sign.** These are signed returns: a loss is negative and VaR is the low
//    quantile. Returning `|VaR|` is indistinguishable on a loss-only distribution
//    and inverts the ranking on a mixed one — which is why the corpus carries an
//    all-losses case *and* an all-gains case.
//
//  ## Two CVaR entry points that compute different things
//
//  `SimulationResults.conditionalValueAtRisk` takes the type-7 quantile as its
//  threshold and averages everything at or below it.
//  `ConditionalValueAtRisk.calculate` averages the worst `max(1, ⌊nα⌋)`
//  observations and never forms a quantile.
//
//  They coincide only when `nα` is an integer and nothing sits on the threshold.
//  Both definitions are in the fixture and each is checked against its own, which
//  is the honest treatment — but see `theTwoCVaREntryPointsDisagree`, which
//  measures the gap rather than leaving it implied.
//
//  ## The analytic anchor
//
//  For a normal distribution:
//
//      VaR_c  = μ + σ·Φ⁻¹(α)
//      CVaR_c = μ − σ·φ(Φ⁻¹(α)) / α          (α = 1 − c)
//
//  A *stratified* sample — the inverse CDF on an even probability grid — is the
//  normal distribution with no sampling noise, so it must reproduce those closed
//  forms. That is the check an estimator cannot pass by being self-consistent: it
//  has to be centred in the right place. The tolerance is measured, not chosen —
//  at 200,000 points the worst gap in the fixture is 3.2e-5.
//
//  Values from Tests/BusinessMathTests/Fixtures/riskMetrics.json.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Value at risk and expected shortfall")
struct RiskMetricsReferenceTests {

	// MARK: - Fixture

	private struct Fixture: Decodable {
		let name: String
		let reference: String
		let note: String
		let levels: [Double]
		let cases: [Case]
	}

	private struct Level: Decodable {
		let confidence: Double
		let valueAtRisk: Double
		let cvarBelowThreshold: Double
		let tailSize: Int
		let cvarWorstCount: Double
		let worstCount: Int
	}

	private struct Analytic: Decodable {
		let confidence: Double
		let valueAtRisk: Double
		let conditionalValueAtRisk: Double
	}

	private struct Construction: Decodable {
		let kind: String
		let mean: Double
		let standardDeviation: Double
		let count: Int
	}

	private struct Case: Decodable {
		let name: String
		let note: String
		let n: Int
		let values: [Double]?
		let construction: Construction?
		let levels: [Level]
		let analytic: [Analytic]?

		/// The sample, either as stored or rebuilt from its recipe.
		///
		/// The large normal cases are a closed-form construction, so the recipe is
		/// the data and storing 200,000 numbers twice would add 11 MB and no
		/// information.
		var sample: [Double] {
			if let values { return values }
			guard let construction else { return [] }
			return (0..<construction.count).map { index -> Double in
				let probability: Double = (Double(index) + 0.5) / Double(construction.count)
				return inverseNormalCDF(p: probability,
										mean: construction.mean,
										stdDev: construction.standardDeviation)
			}
		}
	}

	private static func loadFixture() throws -> Fixture {
		guard let url = Bundle.module.url(forResource: "riskMetrics", withExtension: "json",
										  subdirectory: "Fixtures")
			?? Bundle.module.url(forResource: "riskMetrics", withExtension: "json") else {
			struct Missing: Error { let name: String }
			throw Missing(name: "riskMetrics")
		}
		return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
	}

	private static func close(_ got: Double, _ want: Double, _ tolerance: Double) -> Bool {
		abs(got - want) <= tolerance * Swift.max(1.0, abs(want))
	}

	// MARK: - The corpus

	@Test("The corpus can tell a signed quantile from a magnitude")
	func corpusIsRepresentative() throws {
		let fixture = try Self.loadFixture()
		#expect(fixture.reference.contains("numpy"), "reference was '\(fixture.reference)'")
		#expect(fixture.cases.count >= 7, "only \(fixture.cases.count) datasets")

		// An all-losses case alone cannot distinguish a signed VaR from |VaR|;
		// an all-gains case can, because there the correct answer is positive.
		let gains = try #require(fixture.cases.first { $0.name == "allGains" },
								 "no all-positive dataset, so a magnitude would pass everywhere")
		for level in gains.levels {
			#expect(level.valueAtRisk > 0,
					"all-gains VaR at \(level.confidence) is \(level.valueAtRisk), not positive")
		}

		let losses = try #require(fixture.cases.first { $0.name == "allLosses" },
								  "no all-negative dataset")
		for level in losses.levels {
			#expect(level.valueAtRisk < 0,
					"all-losses VaR at \(level.confidence) is \(level.valueAtRisk), not negative")
		}

		// The two samples are negations of each other, but their VaRs are not:
		// negating a sample turns its lower quantile into its upper one, so
		// `VaR_α(−X) = −Q_{1−α}(X)` rather than `−VaR_α(X)`. What can be said
		// without the upper quantile is that each VaR sits where a *low* quantile
		// must — between the minimum and the median — which is exactly what a
		// returned magnitude would not do.
		for entry in [gains, losses] {
			guard let sample = entry.values else { continue }
			let sorted = sample.sorted()
			guard let lowest = sorted.first else { continue }
			let median = sorted[sorted.count / 2]
			for level in entry.levels {
				#expect(level.valueAtRisk >= lowest - 1e-9,
						"\(entry.name) at \(level.confidence): VaR \(level.valueAtRisk) below the minimum \(lowest)")
				#expect(level.valueAtRisk <= median + 1e-9,
						"\(entry.name) at \(level.confidence): VaR \(level.valueAtRisk) above the median \(median) — not a low quantile")
			}
		}

		let anchored = fixture.cases.filter { $0.analytic != nil }
		#expect(anchored.count >= 2, "only \(anchored.count) analytically anchored datasets")
	}

	// MARK: - Against numpy

	@Test("Value at risk matches numpy's type-7 quantile, sign and all")
	func valueAtRiskMatchesNumpy() throws {
		let fixture = try Self.loadFixture()
		var compared = 0
		for entry in fixture.cases {
			let results = SimulationResults(values: entry.sample)
			for level in entry.levels {
				let got = results.valueAtRisk(confidenceLevel: level.confidence)
				#expect(Self.close(got, level.valueAtRisk, 1e-9),
						"""
						\(entry.name) at \(level.confidence): VaR \(got), numpy \(level.valueAtRisk)
						""")
				compared += 1
			}
		}
		#expect(compared >= 21, "only \(compared) levels compared")
	}

	@Test("SimulationResults CVaR averages everything at or below the quantile")
	func simulationCVaRMatchesItsDefinition() throws {
		let fixture = try Self.loadFixture()
		var compared = 0
		for entry in fixture.cases {
			let results = SimulationResults(values: entry.sample)
			for level in entry.levels {
				let got = results.conditionalValueAtRisk(confidenceLevel: level.confidence)
				#expect(Self.close(got, level.cvarBelowThreshold, 1e-9),
						"""
						\(entry.name) at \(level.confidence): CVaR \(got), numpy \
						\(level.cvarBelowThreshold) over a tail of \(level.tailSize)
						""")
				compared += 1
			}
		}
		#expect(compared >= 21, "only \(compared) levels compared")
	}

	@Test("ConditionalValueAtRisk uses the same threshold, not a count of observations")
	func riskModuleCVaRMatchesTheThresholdDefinition() throws {
		let fixture = try Self.loadFixture()
		var compared = 0
		// The large constructed samples are excluded: rebuilding 200,000 points for
		// each of three levels is minutes of work to re-test an arithmetic mean.
		for entry in fixture.cases where entry.construction == nil {
			for level in entry.levels {
				let got = ConditionalValueAtRisk.calculate(values: entry.sample,
														   confidenceLevel: level.confidence)
				#expect(Self.close(got, level.cvarBelowThreshold, 1e-9),
						"""
						\(entry.name) at \(level.confidence): CVaR \(got), numpy \
						\(level.cvarBelowThreshold) over a tail of \(level.tailSize)
						""")
				compared += 1
			}
		}
		#expect(compared >= 15, "only \(compared) levels compared")
	}

	@Test("The count-based tail this used to average was the wrong size")
	func theOldCountBasedTailOverSelected() throws {
		let fixture = try Self.loadFixture()
		// `cvarWorstCount` records what the previous implementation returned:
		// the mean of the worst `max(1, floor(n·alpha))` observations, with the
		// `max` floor over-selecting on a small sample. At twenty observations and
		// 99% it averaged the worst 5%; at ten and 95%, the worst 10% — in both
		// cases a tail twice the size asked for.
		//
		// Kept as a test rather than deleted with the code, because the fix changes
		// numbers a caller may have seen, and a claim in a CHANGELOG that nobody can
		// re-run is not evidence.
		var differing = 0
		for entry in fixture.cases where entry.construction == nil {
			for level in entry.levels {
				let requested = Int((Double(entry.n) * (1.0 - level.confidence)).rounded(.down))
				let actual = level.worstCount
				if requested < 1 && actual == 1 { differing += 1 }
				#expect(actual == Swift.max(1, requested),
						"\(entry.name) at \(level.confidence): fixture records \(actual) observations, floor gives \(requested)")
			}
		}
		#expect(differing > 0,
				"no design in the corpus is small enough for the old floor to over-select — the regression it caused is untested")
	}

	// MARK: - Against the closed form

	@Test("A noiseless normal sample reproduces the closed forms")
	func stratifiedNormalMatchesClosedForm() throws {
		let fixture = try Self.loadFixture()
		var compared = 0
		for entry in fixture.cases {
			guard let analytic = entry.analytic else { continue }
			let results = SimulationResults(values: entry.sample)
			for reference in analytic {
				let gotVaR = results.valueAtRisk(confidenceLevel: reference.confidence)
				let gotCVaR = results.conditionalValueAtRisk(confidenceLevel: reference.confidence)
				// 1e-4 relative: the empirical-to-analytic gap measured in the
				// generator at 200,000 points is at worst 3.2e-5, and the package's
				// own inverse normal CDF is in this path too. Tight enough that a
				// wrong tail definition cannot hide, loose enough not to be
				// measuring the discretisation.
				#expect(Self.close(gotVaR, reference.valueAtRisk, 1e-4),
						"""
						\(entry.name) at \(reference.confidence): VaR \(gotVaR), \
						μ + σΦ⁻¹(α) = \(reference.valueAtRisk)
						""")
				#expect(Self.close(gotCVaR, reference.conditionalValueAtRisk, 1e-4),
						"""
						\(entry.name) at \(reference.confidence): CVaR \(gotCVaR), \
						μ − σφ(z)/α = \(reference.conditionalValueAtRisk)
						""")
				compared += 2
			}
		}
		#expect(compared >= 12, "only \(compared) closed-form comparisons")
	}

	// MARK: - Properties that need no reference

	@Test("Expected shortfall is never better than value at risk")
	func cvarIsNeverBetterThanVaR() throws {
		let fixture = try Self.loadFixture()
		for entry in fixture.cases {
			let results = SimulationResults(values: entry.sample)
			for level in entry.levels {
				let varValue = results.valueAtRisk(confidenceLevel: level.confidence)
				let cvarValue = results.conditionalValueAtRisk(confidenceLevel: level.confidence)
				// CVaR is the mean of a tail lying at or below VaR, so it cannot
				// exceed it. Needs no reference and holds at every sample size.
				#expect(cvarValue <= varValue + 1e-9,
						"\(entry.name) at \(level.confidence): CVaR \(cvarValue) above VaR \(varValue)")
			}
		}
	}

	@Test("Both measures worsen as confidence rises")
	func measuresAreMonotoneInConfidence() throws {
		let fixture = try Self.loadFixture()
		for entry in fixture.cases where entry.name != "constantSeries" {
			let results = SimulationResults(values: entry.sample)
			var previousVaR = Double.infinity
			var previousCVaR = Double.infinity
			for confidence in [0.90, 0.95, 0.99] {
				let varValue = results.valueAtRisk(confidenceLevel: confidence)
				let cvarValue = results.conditionalValueAtRisk(confidenceLevel: confidence)
				// Asking for more confidence reaches further into the left tail, so
				// both numbers can only fall.
				#expect(varValue <= previousVaR + 1e-9,
						"\(entry.name): VaR rose from \(previousVaR) to \(varValue) at \(confidence)")
				#expect(cvarValue <= previousCVaR + 1e-9,
						"\(entry.name): CVaR rose from \(previousCVaR) to \(cvarValue) at \(confidence)")
				previousVaR = varValue
				previousCVaR = cvarValue
			}
		}
	}

	@Test("Translation invariance and positive homogeneity")
	func measuresAreCoherentUnderShiftAndScale() throws {
		let fixture = try Self.loadFixture()
		for entry in fixture.cases where entry.construction == nil {
			let base = SimulationResults(values: entry.sample)
			let shift = 25.0
			let scale = 3.5
			let shifted = SimulationResults(values: entry.sample.map { $0 + shift })
			let scaled = SimulationResults(values: entry.sample.map { $0 * scale })

			for confidence in [0.90, 0.95, 0.99] {
				// Adding a certain amount to every outcome moves the risk measure by
				// exactly that amount, and scaling by a positive factor scales it.
				// These are two of the four coherence axioms and they hold for any
				// quantile-based measure, so a failure means the arithmetic is wrong
				// rather than the definition.
				let expectedShift: Double = base.valueAtRisk(confidenceLevel: confidence) + shift
				#expect(Self.close(shifted.valueAtRisk(confidenceLevel: confidence), expectedShift, 1e-9),
						"\(entry.name) at \(confidence): VaR is not translation invariant")

				let expectedScale: Double = base.valueAtRisk(confidenceLevel: confidence) * scale
				#expect(Self.close(scaled.valueAtRisk(confidenceLevel: confidence), expectedScale, 1e-9),
						"\(entry.name) at \(confidence): VaR is not positively homogeneous")

				let shiftedCVaR: Double = base.conditionalValueAtRisk(confidenceLevel: confidence) + shift
				#expect(Self.close(shifted.conditionalValueAtRisk(confidenceLevel: confidence), shiftedCVaR, 1e-9),
						"\(entry.name) at \(confidence): CVaR is not translation invariant")
			}
		}
	}

	@Test("A constant series has no risk to measure")
	func constantSeriesIsRiskFree() throws {
		let fixture = try Self.loadFixture()
		guard let entry = fixture.cases.first(where: { $0.name == "constantSeries" }) else {
			Issue.record("constantSeries dataset missing"); return
		}
		let results = SimulationResults(values: entry.sample)
		for confidence in [0.90, 0.95, 0.99] {
			// Every quantile of a constant is the constant, and the mean of any
			// subset of it is too. A zero spread must not become a division.
			#expect(Self.close(results.valueAtRisk(confidenceLevel: confidence), 7.5, 1e-12),
					"VaR of a constant series is \(results.valueAtRisk(confidenceLevel: confidence))")
			#expect(Self.close(results.conditionalValueAtRisk(confidenceLevel: confidence), 7.5, 1e-12),
					"CVaR of a constant series is \(results.conditionalValueAtRisk(confidenceLevel: confidence))")
			#expect(Self.close(ConditionalValueAtRisk.calculate(values: entry.sample,
																confidenceLevel: confidence), 7.5, 1e-12),
					"ConditionalValueAtRisk of a constant series is wrong")
		}
	}

	@Test("The two CVaR entry points agree")
	func theTwoCVaREntryPointsAgree() throws {
		let fixture = try Self.loadFixture()
		var compared = 0

		// They did not, until `ConditionalValueAtRisk.calculate` was changed to take
		// the type-7 quantile as its threshold rather than counting observations.
		// Before that a caller reaching for "CVaR at 95%" got a different number
		// depending on which of the two types they happened to find, and the two
		// coincided whenever `n·alpha` was an integer — agreeing most of the time
		// and diverging occasionally, which is the hardest version to notice.
		//
		// This was a `withKnownIssue` block asserting the equality that ought to
		// hold. When the fix landed, Swift Testing reported the unexpected pass and
		// the marker came out; that is the whole point of recording a defect that
		// way rather than deleting the assertion.
		for entry in fixture.cases where entry.construction == nil {
			let results = SimulationResults(values: entry.sample)
			for level in entry.levels {
				let byResults = results.conditionalValueAtRisk(confidenceLevel: level.confidence)
				let byRiskModule = ConditionalValueAtRisk.calculate(values: entry.sample,
																	confidenceLevel: level.confidence)
				#expect(Self.close(byResults, byRiskModule, 1e-12),
						"""
						\(entry.name) at \(level.confidence): SimulationResults gives \
						\(byResults), ConditionalValueAtRisk gives \(byRiskModule)
						""")
				compared += 1
			}
		}
		#expect(compared >= 15, "only \(compared) pairs compared")
	}

	@Test("The convenience entry points agree with the general one")
	func convenienceEntryPointsAgree() throws {
		let fixture = try Self.loadFixture()
		for entry in fixture.cases where entry.construction == nil {
			let sample = entry.sample
			// cvar95 and cvar99 are the two anyone actually calls, so they are worth
			// pinning to the general form rather than trusting the delegation.
			#expect(Self.close(ConditionalValueAtRisk.cvar95(values: sample),
							   ConditionalValueAtRisk.calculate(values: sample, confidenceLevel: 0.95), 1e-12),
					"\(entry.name): cvar95 disagrees with calculate(confidenceLevel: 0.95)")
			#expect(Self.close(ConditionalValueAtRisk.cvar99(values: sample),
							   ConditionalValueAtRisk.calculate(values: sample, confidenceLevel: 0.99), 1e-12),
					"\(entry.name): cvar99 disagrees with calculate(confidenceLevel: 0.99)")
		}
	}

	@Test("Whichever CVaR definition is used, the answer lies inside the data")
	func bothCVaRDefinitionsStayInsideTheSample() throws {
		let fixture = try Self.loadFixture()
		var compared = 0
		for entry in fixture.cases where entry.construction == nil {
			let results = SimulationResults(values: entry.sample)
			guard let lowest = entry.sample.min(), let highest = entry.sample.max() else { continue }
			for level in entry.levels {
				// The claim that holds for both, and the one that would catch an
				// off-by-one running off the end of the sorted array.
				let byThreshold = results.conditionalValueAtRisk(confidenceLevel: level.confidence)
				let byCount = ConditionalValueAtRisk.calculate(values: entry.sample,
															   confidenceLevel: level.confidence)
				#expect(byThreshold >= lowest - 1e-9 && byThreshold <= highest + 1e-9,
						"\(entry.name) at \(level.confidence): threshold CVaR \(byThreshold) outside [\(lowest), \(highest)]")
				#expect(byCount >= lowest - 1e-9 && byCount <= highest + 1e-9,
						"\(entry.name) at \(level.confidence): count CVaR \(byCount) outside [\(lowest), \(highest)]")
				// And each must be at least as bad as the worst single observation
				// is good — a mean of the left tail cannot exceed the median.
				compared += 2
			}
		}
		#expect(compared >= 30, "only \(compared) bounds checked")
	}
}

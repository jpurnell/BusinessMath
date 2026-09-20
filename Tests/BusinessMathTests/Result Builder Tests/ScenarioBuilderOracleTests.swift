//
//  ScenarioBuilderOracleTests.swift
//  BusinessMath
//
//  Coverage for `ScenarioAnalysisBuilder.buildBlock`, and the regression test for the
//  crash it used to have.
//
//  ## The crash
//
//  `Sensitivity(on:range:steps: 1)` brought the process down. `steps - 1` is zero, so the
//  step size was infinite, `Double(0) * .infinity` gave a NaN multiplier, and the scenario's
//  own name formatted it with `Int(multiplier * 100)` — a trapping conversion:
//
//      Fatal error: Double value cannot be converted to Int because it is either infinite or NaN
//
//  `Vary` has the identical division and has always guarded it. Its `fp-safety:disable`
//  carries the justification that earns it — "steps >= 2 from guard above" — and there is a
//  test for `Vary(..., steps: 1)` returning the `from` value. The annotation was copied to
//  the sensitivity path without the guard, and nothing ever asked that path for one step.
//
//  ## The cartesian product
//
//  Stacked `Vary` components multiply rather than add, which is the builder's most
//  surprising behaviour and the one most worth pinning. The expected set is computed here by
//  direct enumeration, which is a different algorithm from the builder's accumulate-as-you-go
//  fold.
//

import Testing
import Foundation
@testable import BusinessMathDSL

@Suite("Scenario builder: the product, the sweep, and the step that crashed")
struct ScenarioBuilderOracleTests {

	// MARK: - The regression

	@Test("A single-step sensitivity returns one finite scenario instead of crashing")
	func singleStepSensitivityDoesNotTrap() throws {
		let analysis = ScenarioAnalysis {
			BaseScenario { Parameter("revenue", value: 1_000_000) }
			Sensitivity(on: "revenue", range: 0.80...1.20, steps: 1)
		}

		#expect(analysis.scenarios.count == 1,
				"one step should give one scenario, got \(analysis.scenarios.count)")
		let revenue = try #require(analysis.scenarios.first?.parameters["revenue"])
		#expect(revenue.isFinite, "revenue is \(revenue)")
		// The lower bound, which is what `Vary` returns when asked for one step.
		#expect(abs(revenue - 800_000) < 1e-6, "revenue is \(revenue), expected 800000")
	}

	@Test("A degenerate range at one step is finite too")
	func degenerateRangeDoesNotTrap() throws {
		// The other route to the same trap: `0.0 / 0.0` is NaN directly, without needing the
		// infinite step size.
		let analysis = ScenarioAnalysis {
			BaseScenario { Parameter("revenue", value: 1_000_000) }
			Sensitivity(on: "revenue", range: 1.0...1.0, steps: 1)
		}
		#expect(analysis.scenarios.count == 1)
		let revenue = try #require(analysis.scenarios.first?.parameters["revenue"])
		#expect(revenue.isFinite, "revenue is \(revenue)")
		#expect(abs(revenue - 1_000_000) < 1e-6, "revenue is \(revenue)")
	}

	@Test("Every sensitivity step is finite and named")
	func sensitivityStepsAreAllFinite() throws {
		for steps in [1, 2, 3, 5, 11] {
			let analysis = ScenarioAnalysis {
				BaseScenario { Parameter("revenue", value: 1_000_000) }
				Sensitivity(on: "revenue", range: 0.50...1.50, steps: steps)
			}
			#expect(analysis.scenarios.count == steps,
					"steps \(steps) gave \(analysis.scenarios.count) scenarios")
			for scenario in analysis.scenarios {
				let value = try #require(scenario.parameters["revenue"])
				#expect(value.isFinite, "steps \(steps): \(scenario.name) gave \(value)")
				#expect(!scenario.name.contains("nan"), "steps \(steps): name is \(scenario.name)")
			}
		}
	}

	@Test("Zero or fewer steps contribute nothing, as they always did")
	func nonPositiveStepsContributeNothing() throws {
		for steps in [0, -3] {
			let analysis = ScenarioAnalysis {
				BaseScenario { Parameter("revenue", value: 1_000_000) }
				Sensitivity(on: "revenue", range: 0.80...1.20, steps: steps)
			}
			#expect(analysis.scenarios.isEmpty,
					"steps \(steps) gave \(analysis.scenarios.count) scenarios")
		}
	}

	// MARK: - The cartesian product

	@Test("Stacked variations are the cartesian product, not a concatenation")
	func stackedVariationsMultiply() throws {
		let growth = [0.10, 0.15, 0.20]
		let margin = [0.2, 0.3]
		let churn = [0.01, 0.02, 0.05, 0.10]

		let analysis = ScenarioAnalysis {
			BaseScenario { Parameter("revenue", value: 1_000_000) }
			Vary("growth", values: growth)
			Vary("margin", values: margin)
			Vary("churn", values: churn)
		}

		// Enumerated directly, rather than folded one variation at a time.
		var expected = Set<String>()
		for g in growth {
			for m in margin {
				for c in churn {
					expected.insert("\(g)|\(m)|\(c)")
				}
			}
		}
		#expect(analysis.scenarios.count == growth.count * margin.count * churn.count,
				"got \(analysis.scenarios.count), expected \(expected.count)")

		var seen = Set<String>()
		for scenario in analysis.scenarios {
			let g = try #require(scenario.parameters["growth"])
			let m = try #require(scenario.parameters["margin"])
			let c = try #require(scenario.parameters["churn"])
			#expect(scenario.parameters["revenue"] == 1_000_000,
					"the base parameter did not survive: \(scenario.name)")
			seen.insert("\(g)|\(m)|\(c)")
		}
		#expect(seen == expected, "the product is not the full set")
	}

	@Test("A variation with no scenarios yet seeds the set rather than multiplying nothing")
	func firstVariationSeedsTheSet() throws {
		// `0 * k` is zero, so a fold that always multiplied would give no scenarios at all
		// for the first variation. It seeds instead.
		let analysis = ScenarioAnalysis {
			BaseScenario { Parameter("revenue", value: 1_000_000) }
			Vary("growth", values: [0.1, 0.2, 0.3])
		}
		#expect(analysis.scenarios.count == 3)
	}

	// MARK: - Tornado

	@Test("A tornado varies one parameter at a time, never crossing them")
	func tornadoDoesNotCross() throws {
		let analysis = ScenarioAnalysis {
			BaseScenario {
				Parameter("revenue", value: 1_000_000)
				Parameter("cost", value: 400_000)
			}
			TornadoChart {
				Vary("revenue", values: [0.8, 1.0, 1.2])
				Vary("cost", values: [0.9, 1.0, 1.1])
			}
		}

		// Two variations of three values each: six scenarios if one at a time, nine if
		// crossed. The distinction is the whole point of a tornado chart.
		#expect(analysis.scenarios.count == 6, "got \(analysis.scenarios.count)")

		for scenario in analysis.scenarios {
			let revenue = try #require(scenario.parameters["revenue"])
			let cost = try #require(scenario.parameters["cost"])
			let revenueMoved = abs(revenue - 1_000_000) > 1e-9
			let costMoved = abs(cost - 400_000) > 1e-9
			#expect(!(revenueMoved && costMoved),
					"\(scenario.name) moved both parameters at once")
		}
	}
}

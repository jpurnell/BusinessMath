//
//  MarkovTests.swift
//  BusinessMath
//
//  Markov chains: transition matrices, steady state, absorption, removal effect.
//
//  ## The oracle that costs nothing
//
//  A chain built from observed journeys must reproduce the conversion rate of those
//  journeys. Six of the ten paths below convert, and the chain's absorption probability
//  from the start state is exactly 0.6. That is not a coincidence to be checked to a
//  tolerance — it follows from the transition counts being the empirical ones — and it
//  breaks immediately if the matrix is built wrong, if the start state is mis-seeded, or
//  if absorption is solved incorrectly.
//
//  ## Why the fixture is asymmetric
//
//  The first one written had every channel returning the same removal effect, which is
//  the fixture failing rather than the code passing: a test where every answer is equal
//  cannot catch an error that treats channels differently. This one is built so C1 drives
//  most conversions and C2 and C3 do not, giving removal effects of 0.833 against 0.333.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Markov chains")
struct MarkovTests {

	/// Ten journeys, six converting, with C1 carrying most of the value.
	private static let journeys: [[String]] = [
		["C1", "conversion"],
		["C1", "conversion"],
		["C1", "C2", "conversion"],
		["C2", "null"],
		["C2", "C3", "conversion"],
		["C3", "null"],
		["C3", "null"],
		["C1", "C3", "conversion"],
		["C2", "null"],
		["C1", "conversion"],
	]

	// MARK: - Construction

	@Test("Transition probabilities are the observed frequencies")
	func transitionProbabilities() throws {
		let chain = try #require(TransitionMatrix<Double>(paths: Self.journeys))
		let expected: [(from: String, to: String, p: Double)] = [
			("(start)", "C1", 0.5), ("(start)", "C2", 0.3), ("(start)", "C3", 0.2),
			("C1", "C2", 0.2), ("C1", "C3", 0.2), ("C1", "conversion", 0.6),
			("C2", "C3", 0.25), ("C2", "conversion", 0.25), ("C2", "null", 0.5),
			("C3", "conversion", 0.5), ("C3", "null", 0.5),
		]
		var checked = 0
		for row in expected {
			let p = chain.probability(from: row.from, to: row.to)
			#expect(Swift.abs(p - row.p) < 1e-12,
					"P(\(row.from) → \(row.to)) = \(p), expected \(row.p)")
			checked += 1
		}
		#expect(checked == 11, "only \(checked) of 11 transitions were checked")
	}

	@Test("Every transient row sums to one, and absorbing states hold themselves")
	func rowsAreStochastic() throws {
		let chain = try #require(TransitionMatrix<Double>(paths: Self.journeys))
		var checked = 0
		for state in chain.states {
			var total: Double = 0
			for target in chain.states { total += chain.probability(from: state, to: target) }
			#expect(Swift.abs(total - 1) < 1e-12, "row \(state) sums to \(total)")
			checked += 1
		}
		#expect(checked == chain.states.count)
		// An absorbing state is one that never leads anywhere else.
		#expect(Set(chain.absorbingStates) == ["conversion", "null"],
				"got \(chain.absorbingStates)")
		#expect(Swift.abs(chain.probability(from: "conversion", to: "conversion") - 1) < 1e-12)
	}

	// MARK: - Absorption

	@Test("The chain reproduces the conversion rate of the journeys it was built from")
	func absorptionMatchesObservedRate() throws {
		let chain = try #require(TransitionMatrix<Double>(paths: Self.journeys))
		let converted = try #require(chain.absorptionProbability(to: "conversion",
																 from: "(start)"))
		// Six of ten journeys converted.
		#expect(Swift.abs(converted - 0.6) < 1e-9,
				"the chain says \(converted), the data says 0.6")
		// And the two absorbing states account for everything.
		let lost = try #require(chain.absorptionProbability(to: "null", from: "(start)"))
		#expect(Swift.abs(converted + lost - 1) < 1e-9,
				"absorption should be certain, got \(converted + lost)")
	}

	@Test("Absorption from a later state ignores how the journey reached it")
	func absorptionIsMarkovian() throws {
		let chain = try #require(TransitionMatrix<Double>(paths: Self.journeys))
		// From C3 the chain converts half the time, whatever came before — that is what
		// makes it a Markov chain, and it is the modelling assumption a user is buying.
		let fromC3 = try #require(chain.absorptionProbability(to: "conversion", from: "C3"))
		#expect(Swift.abs(fromC3 - 0.5) < 1e-9, "got \(fromC3)")
	}

	@Test("Expected steps to absorption is the geometric mean it must be")
	func expectedSteps() throws {
		// A state that absorbs with probability p and otherwise stays put takes 1/p steps
		// on average — the mean of a geometric distribution, exact rather than
		// approximate, and it needs no reference implementation to check.
		var checked = 0
		for p in [0.5, 0.25, 0.1, 0.8] {
			let chain = try #require(TransitionMatrix<Double>(
				states: ["waiting", "done"],
				rows: [[1 - p, p], [0, 1]]))
			let steps = try #require(chain.expectedStepsToAbsorption(from: "waiting"))
			let wanted: Double = 1 / p
			#expect(Swift.abs(steps - wanted) < 1e-9,
					"p=\(p) gave \(steps) steps, geometric says \(wanted)")
			checked += 1
		}
		#expect(checked == 4, "only \(checked) of 4 rates were checked")
	}

	@Test("A deterministic chain takes exactly as many steps as it has")
	func deterministicSteps() throws {
		// A → B → done, with no choice anywhere: two steps, and any answer other than
		// exactly two means the linear solve is wrong rather than imprecise.
		let chain = try #require(TransitionMatrix<Double>(
			states: ["A", "B", "done"],
			rows: [[0, 1, 0], [0, 0, 1], [0, 0, 1]]))
		let fromA = try #require(chain.expectedStepsToAbsorption(from: "A"))
		let fromB = try #require(chain.expectedStepsToAbsorption(from: "B"))
		#expect(Swift.abs(fromA - 2) < 1e-12, "from A: \(fromA)")
		#expect(Swift.abs(fromB - 1) < 1e-12, "from B: \(fromB)")
		// Already absorbed is zero steps, not one.
		let done = try #require(chain.expectedStepsToAbsorption(from: "done"))
		#expect(done == 0, "an absorbed state takes \(done) steps")
	}

	@Test("A journey's expected length is at least one step and finite")
	func journeyLength() throws {
		let chain = try #require(TransitionMatrix<Double>(paths: Self.journeys))
		let steps = try #require(chain.expectedStepsToAbsorption(from: "(start)"))
		#expect(steps >= 1, "a journey takes at least one step, got \(steps)")
		#expect(steps.isFinite, "got \(steps)")
		// Every path in the fixture is at most three states past the start, so the mean
		// cannot exceed that.
		#expect(steps <= 3, "the longest journey is three steps, mean was \(steps)")
		#expect(chain.expectedStepsToAbsorption(from: "nowhere") == nil)
	}

	// MARK: - Removal effect

	@Test("Removal effects are the ones an independent computation gives")
	func removalEffects() throws {
		let chain = try #require(TransitionMatrix<Double>(paths: Self.journeys))
		// Definition matters here, and the first version of this fixture used the wrong
		// one. The standard removal effect — Anderl et al., and the ChannelAttribution
		// package — is **surgery on the transition graph**: delete the node, redirect its
		// inbound edges to a null absorbing state, and leave every other probability
		// untouched.
		//
		// The alternative is to truncate the observed paths and rebuild the chain from
		// scratch. That is a different question and gives different numbers — 0.833,
		// 0.333, 0.333 here against 0.646, 0.250, 0.333 — because rebuilding also changes
		// the start row, redistributing where journeys begin. Both are defensible; only
		// one is what "removal effect" means in the literature this is measured against.
		let expected: [(channel: String, effect: Double)] = [
			("C1", 0.6458333333), ("C2", 0.25), ("C3", 0.3333333333),
		]
		var checked = 0
		for row in expected {
			let effect = try #require(chain.removalEffect(of: row.channel,
														   converting: "conversion"))
			#expect(Swift.abs(effect - row.effect) < 1e-8,
					"removing \(row.channel) gives \(effect), expected \(row.effect)")
			checked += 1
		}
		#expect(checked == 3, "only \(checked) removal effects were checked")
	}

	@Test("The dominant channel is identified as dominant")
	func removalEffectDiscriminates() throws {
		// The test that would fail on a symmetric fixture, and the reason this one is
		// not symmetric: C1 must come out well ahead of the other two.
		let chain = try #require(TransitionMatrix<Double>(paths: Self.journeys))
		let first = try #require(chain.removalEffect(of: "C1", converting: "conversion"))
		let second = try #require(chain.removalEffect(of: "C2", converting: "conversion"))
		#expect(first > second * 2, "C1 \(first) should dominate C2 \(second)")
	}

	@Test("Attribution shares are the normalised removal effects and sum to one")
	func attributionShares() throws {
		let chain = try #require(TransitionMatrix<Double>(paths: Self.journeys))
		let shares = try #require(chain.attributionShares(converting: "conversion"))
		let total = shares.values.reduce(0, +)
		#expect(Swift.abs(total - 1) < 1e-9, "shares sum to \(total)")
		let c1 = try #require(shares["C1"])
		#expect(Swift.abs(c1 - 0.5254237288) < 1e-8, "C1 share \(c1)")
		let c2 = try #require(shares["C2"])
		#expect(Swift.abs(c2 - 0.2033898305) < 1e-8, "C2 share \(c2)")
		// The absorbing states are outcomes, not channels, and must not be attributed.
		#expect(shares["conversion"] == nil, "conversion is an outcome, not a channel")
		#expect(shares["null"] == nil)
		#expect(shares["(start)"] == nil, "the start state is not a channel")
	}

	// MARK: - Steady state

	@Test("The stationary distribution of an ergodic chain is the one solved by hand")
	func steadyState() throws {
		// P = [[0.9, 0.1], [0.5, 0.5]] has π = (5/6, 1/6): π₁ = 0.9π₁ + 0.5(1 − π₁)
		// gives 0.6π₁ = 0.5. A credit-rating migration matrix is this object.
		let chain = try #require(TransitionMatrix<Double>(
			states: ["stay", "switch"],
			rows: [[0.9, 0.1], [0.5, 0.5]]))
		let stationary = try #require(chain.steadyState())
		let stay = try #require(stationary["stay"])
		let leave = try #require(stationary["switch"])
		#expect(Swift.abs(stay - 5.0 / 6.0) < 1e-9, "π(stay) = \(stay)")
		#expect(Swift.abs(leave - 1.0 / 6.0) < 1e-9, "π(switch) = \(leave)")
		#expect(Swift.abs(stay + leave - 1) < 1e-12)
	}

	@Test("The stationary distribution is stationary")
	func steadyStateIsFixed() throws {
		// The defining property, checked directly rather than through the solver: πP = π.
		let chain = try #require(TransitionMatrix<Double>(
			states: ["a", "b", "c"],
			rows: [[0.5, 0.3, 0.2], [0.2, 0.6, 0.2], [0.3, 0.3, 0.4]]))
		let stationary = try #require(chain.steadyState())
		var checked = 0
		for target in chain.states {
			var carried: Double = 0
			for source in chain.states {
				let mass = stationary[source] ?? 0
				carried += mass * chain.probability(from: source, to: target)
			}
			let settled = stationary[target] ?? 0
			#expect(Swift.abs(carried - settled) < 1e-8,
					"πP at \(target) is \(carried), π is \(settled)")
			checked += 1
		}
		#expect(checked == 3)
	}

	// MARK: - Refusals

	@Test("Chains refuse what they cannot represent")
	func refusals() {
		#expect(TransitionMatrix<Double>(paths: []) == nil)
		// A path with nothing in it contributes no transition.
		#expect(TransitionMatrix<Double>(paths: [[], []]) == nil)
		// Rows that do not sum to one are not a chain.
		#expect(TransitionMatrix<Double>(states: ["a", "b"], rows: [[0.5, 0.2], [0.5, 0.5]]) == nil)
		#expect(TransitionMatrix<Double>(states: ["a", "b"], rows: [[-0.1, 1.1], [0.5, 0.5]]) == nil)
		// A square matrix or nothing.
		#expect(TransitionMatrix<Double>(states: ["a", "b"], rows: [[1.0, 0.0]]) == nil)
	}

	@Test("Removing a state that is not a channel is refused")
	func removalRefusals() throws {
		let chain = try #require(TransitionMatrix<Double>(paths: Self.journeys))
		#expect(chain.removalEffect(of: "nonexistent", converting: "conversion") == nil)
		#expect(chain.removalEffect(of: "C1", converting: "nonexistent") == nil)
		// Removing the start state leaves no journeys at all.
		#expect(chain.removalEffect(of: "(start)", converting: "conversion") == nil)
	}
}

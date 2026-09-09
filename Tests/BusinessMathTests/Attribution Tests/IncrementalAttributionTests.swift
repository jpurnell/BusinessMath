//
//  IncrementalAttributionTests.swift
//  BusinessMath
//
//  Markov removal effect and the Shapley value — the two models that read the journeys
//  that failed — and the three ways an incremental number is quietly not one.
//
//  - **Normalised shares read as measurements.** Removal effects do not sum to one and
//    are not meant to: two channels that each appear in every converting journey both
//    score near one, which is the honest statement that either alone would carry the
//    value. Dividing them into a budget split is a convention laid on top of a
//    measurement, and the split is what gets quoted.
//  - **A channel named after a synthetic state.** A channel called `(conversion)` merges
//    silently into the absorbing outcome, and every remaining number stays a valid
//    probability while one channel has vanished into bookkeeping.
//  - **Shapley on too many channels.** Enumeration is 2ⁿ; at twenty channels that is a
//    million coalitions and at thirty it does not finish. Sampling instead would return a
//    number of the right shape with no error bound attached to it.
//
//  Two anchors, neither needing a reference implementation. **Efficiency** — credit sums
//  to the converted value — holds for both models and is checked for both. And the
//  Shapley **null player** axiom is exact rather than approximate: a channel that changes
//  no coalition's worth receives precisely zero, which is the one assertion in attribution
//  that can be made without a tolerance.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Incremental attribution")
struct IncrementalAttributionTests {

	/// Five journeys where Awareness opens and Close closes, and five where Close is
	/// alone and fails.
	///
	/// Worked by hand against the chain this builds:
	/// `(start)` splits evenly between Awareness and Close; Awareness always leads to
	/// Close; Close converts half the time. So `P(convert) = 0.5·1·0.5 + 0.5·0.5 = 0.5`.
	/// Removing Awareness sends its inbound half to failure, leaving `0.5·0.5 = 0.25`, an
	/// effect of `0.5`. Removing Close leaves nothing that reaches the conversion at all,
	/// an effect of `1.0`. Normalised, that is one third and two thirds.
	static let funnel: [Journey] = {
		var all: [Journey] = []
		for _ in 0..<5 {
			all.append(Journey(channels: ["Awareness", "Close"], converted: true, value: 1))
		}
		for _ in 0..<5 {
			all.append(Journey(channels: ["Close"], converted: false, value: 0))
		}
		return all
	}()

	// MARK: - Markov removal effect

	@Test("Removal effects are the hand-computed counterfactual")
	func removalEffectsAreExact() throws {
		let effects = try MarkovAttribution().removalEffects(journeys: Self.funnel)
		let awareness = try #require(effects["Awareness"])
		let close = try #require(effects["Close"])
		#expect(Swift.abs(awareness - 0.5) < 1e-12, "Awareness \(awareness)")
		#expect(Swift.abs(close - 1) < 1e-12, "Close \(close)")
		// And they do not sum to one, which is the point of exposing them separately.
		let total: Double = awareness + close
		#expect(Swift.abs(total - 1.5) < 1e-12, "effects sum to \(total), not 1")
	}

	@Test("Attribution normalises those effects and stays efficient")
	func markovIsEfficient() throws {
		let credit = try MarkovAttribution().attribute(journeys: Self.funnel)
		let awareness = try #require(credit["Awareness"])
		let close = try #require(credit["Close"])
		// Five conversions split one third / two thirds.
		#expect(Swift.abs(awareness - 5.0 / 3.0) < 1e-12, "Awareness \(awareness)")
		#expect(Swift.abs(close - 10.0 / 3.0) < 1e-12, "Close \(close)")
		let total: Double = awareness + close
		#expect(Swift.abs(total - 5) < 1e-12, "total \(total)")
	}

	@Test("The opener last touch scored at zero is worth a third of the budget")
	func markovRescuesTheOpener() throws {
		let heuristic = try HeuristicAttribution.lastTouch.attribute(journeys: Self.funnel)
		let byLastTouch = try #require(heuristic["Awareness"])
		#expect(Swift.abs(byLastTouch) < 1e-12, "last touch says \(byLastTouch)")

		let incremental = try MarkovAttribution().attribute(journeys: Self.funnel)
		let byRemoval = try #require(incremental["Awareness"])
		#expect(Swift.abs(byRemoval - 5.0 / 3.0) < 1e-12, "removal effect says \(byRemoval)")

		// Both are arithmetic on the same ten journeys. They differ because only one of
		// them looked at the five that failed.
		#expect(byRemoval > byLastTouch, "\(byRemoval) against \(byLastTouch)")
	}

	@Test("A channel in every converting path cannot be removed without losing everything")
	func indispensableChannelScoresOne() throws {
		var paths: [Journey] = []
		for _ in 0..<4 {
			paths.append(Journey(channels: ["Only"], converted: true, value: 1))
		}
		paths.append(Journey(channels: ["Only"], converted: false, value: 0))
		let effects = try MarkovAttribution().removalEffects(journeys: paths)
		let only = try #require(effects["Only"])
		#expect(Swift.abs(only - 1) < 1e-12, "\(only)")
	}

	@Test("A channel named after a synthetic state is refused, not merged")
	func reservedNamesAreRefused() {
		let collision = [Journey(channels: ["(conversion)"], converted: true, value: 1)]
		#expect(throws: AttributionError.self) {
			_ = try MarkovAttribution().attribute(journeys: collision)
		}
		let removed = [Journey(channels: ["(removed)", "A"], converted: true, value: 1)]
		#expect(throws: AttributionError.self) {
			_ = try MarkovAttribution().attribute(journeys: removed)
		}
	}

	// MARK: - Shapley

	@Test("Two channels, worked by hand")
	func shapleyByHand() throws {
		// v(∅)=0, v(A)=1, v(B)=0, v(AB)=2.
		// φ_A = ½(1−0) + ½(2−0) = 1.5;  φ_B = ½(0−0) + ½(2−1) = 0.5.
		let journeys = [
			Journey(channels: ["A"], converted: true, value: 1),
			Journey(channels: ["A", "B"], converted: true, value: 1)
		]
		let credit = try ShapleyAttribution().attribute(journeys: journeys)
		let a = try #require(credit["A"])
		let b = try #require(credit["B"])
		#expect(Swift.abs(a - 1.5) < 1e-12, "A \(a)")
		#expect(Swift.abs(b - 0.5) < 1e-12, "B \(b)")
	}

	@Test("Coalition worth counts the journeys a coalition fully covers")
	func coalitionValues() throws {
		let journeys = [
			Journey(channels: ["A"], converted: true, value: 1),
			Journey(channels: ["A", "B"], converted: true, value: 1)
		]
		let model = ShapleyAttribution()
		let empty = try model.coalitionValue([], journeys: journeys)
		let justA = try model.coalitionValue(["A"], journeys: journeys)
		let justB = try model.coalitionValue(["B"], journeys: journeys)
		let both = try model.coalitionValue(["A", "B"], journeys: journeys)
		#expect(Swift.abs(empty) < 1e-12, "v(∅) = \(empty)")
		#expect(Swift.abs(justA - 1) < 1e-12, "v(A) = \(justA)")
		#expect(Swift.abs(justB) < 1e-12, "v(B) = \(justB)")
		#expect(Swift.abs(both - 2) < 1e-12, "v(AB) = \(both)")
	}

	@Test("The efficiency axiom holds exactly")
	func shapleyIsEfficient() throws {
		let journeys = [
			Journey(channels: ["Search", "Email"], converted: true, value: 40),
			Journey(channels: ["Email"], converted: true, value: 10),
			Journey(channels: ["Search", "Social", "Email"], converted: true, value: 25),
			Journey(channels: ["Social"], converted: false, value: 0),
			Journey(channels: ["Search"], converted: false, value: 0)
		]
		let credit = try ShapleyAttribution().attribute(journeys: journeys)
		let total: Double = credit.values.reduce(0, +)
		#expect(Swift.abs(total - 75) < 1e-9, "attributed \(total) of 75")
		#expect(credit.count == 3, "\(credit.keys.sorted())")
	}

	@Test("The symmetry axiom holds: identical contributors are paid identically")
	func shapleyIsSymmetric() throws {
		// Twin1 and Twin2 appear in exactly the same journeys, so no coalition can tell
		// them apart and neither can the value.
		let journeys = [
			Journey(channels: ["Twin1", "Twin2"], converted: true, value: 10),
			Journey(channels: ["Twin1", "Twin2", "Other"], converted: true, value: 6),
			Journey(channels: ["Other"], converted: true, value: 4)
		]
		let credit = try ShapleyAttribution().attribute(journeys: journeys)
		let first = try #require(credit["Twin1"])
		let second = try #require(credit["Twin2"])
		#expect(Swift.abs(first - second) < 1e-12, "\(first) against \(second)")
	}

	@Test("The null-player axiom holds exactly, not approximately")
	func shapleyPaysNullPlayersNothing() throws {
		// Ghost appears only where nothing converted, so adding it to any coalition
		// changes no worth at all.
		let journeys = [
			Journey(channels: ["A"], converted: true, value: 1),
			Journey(channels: ["A", "B"], converted: true, value: 1),
			Journey(channels: ["Ghost"], converted: false, value: 0),
			Journey(channels: ["Ghost", "B"], converted: false, value: 0)
		]
		let credit = try ShapleyAttribution().attribute(journeys: journeys)
		let ghost = try #require(credit["Ghost"], "it should be measured, not missing")
		#expect(ghost == 0, "exactly zero, got \(ghost)")

		// A heuristic cannot even see it, which is the difference the type documents.
		let heuristic = try HeuristicAttribution.linear.attribute(journeys: journeys)
		#expect(heuristic["Ghost"] == nil, "\(heuristic)")
	}

	@Test("Order does not change a Shapley value, and does change a Markov one")
	func shapleyIgnoresOrderAndMarkovDoesNot() throws {
		let forward = [
			Journey(channels: ["A", "B"], converted: true, value: 1),
			Journey(channels: ["A", "B"], converted: false, value: 0),
			Journey(channels: ["B"], converted: true, value: 1)
		]
		let reversed = [
			Journey(channels: ["B", "A"], converted: true, value: 1),
			Journey(channels: ["B", "A"], converted: false, value: 0),
			Journey(channels: ["B"], converted: true, value: 1)
		]
		let shapleyForward = try ShapleyAttribution().attribute(journeys: forward)
		let shapleyReversed = try ShapleyAttribution().attribute(journeys: reversed)
		for channel in ["A", "B"] {
			let one = try #require(shapleyForward[channel])
			let other = try #require(shapleyReversed[channel])
			#expect(Swift.abs(one - other) < 1e-12, "\(channel): \(one) against \(other)")
		}

		let markovForward = try MarkovAttribution().attribute(journeys: forward)
		let markovReversed = try MarkovAttribution().attribute(journeys: reversed)
		let aForward = try #require(markovForward["A"])
		let aReversed = try #require(markovReversed["A"])
		#expect(Swift.abs(aForward - aReversed) > 1e-6,
				"a chain reads sequence: \(aForward) against \(aReversed)")
	}

	@Test("Too many channels to enumerate is refused rather than sampled")
	func shapleyRefusesAboveItsLimit() {
		var journeys: [Journey] = []
		for index in 0..<6 {
			journeys.append(Journey(channels: ["C\(index)"], converted: true, value: 1))
		}
		let model = ShapleyAttribution(channelLimit: 4)
		#expect(throws: AttributionError.tooManyChannels(count: 6, limit: 4)) {
			_ = try model.attribute(journeys: journeys)
		}
		// The limit is clamped to what Double holds factorials for exactly.
		#expect(ShapleyAttribution(channelLimit: 40).channelLimit == 16)
	}

	// MARK: - Across the protocol

	@Test("Every model in the protocol keeps the efficiency contract")
	func everyModelIsEfficient() throws {
		let journeys = [
			Journey(channels: ["A", "B", "C"], converted: true, value: 30, ages: [3, 2, 1]),
			Journey(channels: ["B"], converted: true, value: 20, ages: [1]),
			Journey(channels: ["C", "A"], converted: false, value: 0, ages: [5, 4])
		]
		let models: [any AttributionModel] = [
			HeuristicAttribution.firstTouch,
			HeuristicAttribution.lastTouch,
			HeuristicAttribution.linear,
			HeuristicAttribution.uShaped,
			HeuristicAttribution.timeDecay(halfLife: 2),
			MarkovAttribution(),
			ShapleyAttribution()
		]
		for model in models {
			let credit = try model.attribute(journeys: journeys)
			let total: Double = credit.values.reduce(0, +)
			let expected = model.totalConversionValue(in: journeys)
			#expect(Swift.abs(expected - 50) < 1e-12, "expected value \(expected)")
			#expect(Swift.abs(total - expected) < 1e-9, "\(type(of: model)) gave \(total)")
		}
	}
}

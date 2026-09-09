//
//  HeuristicAttributionTests.swift
//  BusinessMath
//
//  The four heuristic attribution rules, and the three ways credit gets assigned to
//  something that did not earn it.
//
//  - **Last touch, read as a measure of effect.** It gives every unit of credit to the
//    final channel, so an upper-funnel channel that starts journeys and never closes them
//    scores exactly zero — not "small", zero. The number is not wrong as a description of
//    what happened last; it is wrong as an answer to what would happen without the
//    channel, and the two get quoted interchangeably.
//  - **Time decay without times.** Position is not recency. A journey whose touches are
//    thirty days, twenty days and one hour before conversion decays nothing like one whose
//    three touches all landed the same afternoon, and using the index as a proxy returns a
//    perfectly ordinary set of weights for the wrong journey shape. Timings are required,
//    not inferred.
//  - **Position weights that do not leave room for the middle.** `first: 0.6, last: 0.6`
//    is arithmetic nobody notices: the middle share is −0.2, the middle touches receive
//    negative credit, and the total still comes to the conversion value because the
//    negatives cancel. Efficiency alone would not catch it.
//
//  The anchor is the **efficiency axiom**: attributed credit must sum to the total value
//  of the converting journeys, no more and no less. It holds for every model in the
//  protocol, so it is checked for every model rather than per implementation.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Heuristic attribution")
struct HeuristicAttributionTests {

	/// Two conversions worth 150 between them, and one journey that went nowhere.
	///
	/// | journey | channels | value | ages (days before conversion) |
	/// |---|---|---|---|
	/// | 1 | A, B, C, B | 100 | 30, 20, 10, 0 |
	/// | 2 | A | — | — |
	/// | 3 | B, C | 50 | 7, 0 |
	static let journeys: [Journey] = [
		Journey(channels: ["A", "B", "C", "B"], converted: true, value: 100,
				ages: [30, 20, 10, 0]),
		Journey(channels: ["A"], converted: false, value: 0, ages: [3]),
		Journey(channels: ["B", "C"], converted: true, value: 50, ages: [7, 0])
	]

	static let totalValue: Double = 150

	static func credit(_ model: HeuristicAttribution) throws -> [String: Double] {
		try model.attribute(journeys: journeys)
	}

	// MARK: - The efficiency axiom

	@Test("Every model attributes exactly the converted value, and nothing else")
	func everyModelIsEfficient() throws {
		let models: [HeuristicAttribution] = [.firstTouch, .lastTouch, .linear,
											  .positionBased(first: 0.4, last: 0.4),
											  .timeDecay(halfLife: 10)]
		for model in models {
			let credit = try Self.credit(model)
			let total: Double = credit.values.reduce(0, +)
			#expect(Swift.abs(total - Self.totalValue) < 1e-9, "\(model) attributed \(total)")
			for (channel, share) in credit {
				#expect(share >= 0, "\(model) gave \(channel) \(share)")
			}
		}
	}

	@Test("A channel seen only in a failed journey is absent, not zero")
	func unmeasurableChannelsAreAbsent() throws {
		// Ghost appears in no converting journey, so a heuristic has nothing to say about
		// it at all — which is different from saying it earned nothing.
		var withGhost = Self.journeys
		withGhost.append(Journey(channels: ["Ghost"], converted: false, value: 0))
		let credit = try HeuristicAttribution.linear.attribute(journeys: withGhost)
		#expect(credit["Ghost"] == nil, "\(credit)")
		let total: Double = credit.values.reduce(0, +)
		#expect(Swift.abs(total - Self.totalValue) < 1e-9, "total \(total)")
	}

	@Test("The non-converting journey contributes no credit to anyone")
	func nonConvertingJourneysCarryNoCredit() throws {
		// Channel A appears in journey 2, which did not convert. Under first touch it is
		// credited only for journey 1.
		let credit = try Self.credit(.firstTouch)
		let a = try #require(credit["A"])
		#expect(Swift.abs(a - 100) < 1e-9, "A got \(a)")
	}

	// MARK: - Each rule, by hand

	@Test("First touch credits the channel that opened the journey")
	func firstTouch() throws {
		let credit = try Self.credit(.firstTouch)
		#expect(Swift.abs((credit["A"] ?? 0) - 100) < 1e-9, "A \(credit["A"] ?? 0)")
		#expect(Swift.abs((credit["B"] ?? 0) - 50) < 1e-9, "B \(credit["B"] ?? 0)")
		// C was touched in both converting journeys and opened neither, so it is
		// measured at zero rather than missing.
		let c = try #require(credit["C"])
		#expect(Swift.abs(c) < 1e-12, "C \(c)")
	}

	@Test("Last touch credits the channel that closed it")
	func lastTouch() throws {
		let credit = try Self.credit(.lastTouch)
		#expect(Swift.abs((credit["B"] ?? 0) - 100) < 1e-9, "B \(credit["B"] ?? 0)")
		#expect(Swift.abs((credit["C"] ?? 0) - 50) < 1e-9, "C \(credit["C"] ?? 0)")
		let a = try #require(credit["A"])
		#expect(Swift.abs(a) < 1e-12, "A closed nothing, so it is zero, not absent — got \(a)")
	}

	@Test("Linear splits across touches, so a repeated channel is credited twice")
	func linear() throws {
		// Journey 1 has four touches at 25 each and B appears in two of them.
		let credit = try Self.credit(.linear)
		#expect(Swift.abs((credit["A"] ?? 0) - 25) < 1e-9, "A \(credit["A"] ?? 0)")
		#expect(Swift.abs((credit["B"] ?? 0) - 75) < 1e-9, "B \(credit["B"] ?? 0)")
		#expect(Swift.abs((credit["C"] ?? 0) - 50) < 1e-9, "C \(credit["C"] ?? 0)")
	}

	@Test("Position based gives the ends their weight and the middle what is left")
	func positionBased() throws {
		// Journey 1: A 40, B 40 as the closer, and 20 shared by the two middle touches.
		// Journey 3 has no middle, so 0.4/0.4 renormalises to an even split.
		let credit = try Self.credit(.positionBased(first: 0.4, last: 0.4))
		#expect(Swift.abs((credit["A"] ?? 0) - 40) < 1e-9, "A \(credit["A"] ?? 0)")
		#expect(Swift.abs((credit["B"] ?? 0) - 75) < 1e-9, "B \(credit["B"] ?? 0)")
		#expect(Swift.abs((credit["C"] ?? 0) - 35) < 1e-9, "C \(credit["C"] ?? 0)")
	}

	@Test("Time decay halves a touch's weight every half-life")
	func timeDecay() throws {
		// Journey 1's ages are 30, 20, 10 and 0 days against a ten-day half-life, so the
		// raw weights are 1/8, 1/4, 1/2 and 1, normalised over 15/8.
		let credit = try Self.credit(.timeDecay(halfLife: 10))
		#expect(Swift.abs((credit["A"] ?? 0) - 6.666666666666667) < 1e-9, "A \(credit["A"] ?? 0)")
		#expect(Swift.abs((credit["B"] ?? 0) - 85.71787973316069) < 1e-9, "B \(credit["B"] ?? 0)")
		#expect(Swift.abs((credit["C"] ?? 0) - 57.61545360017266) < 1e-9, "C \(credit["C"] ?? 0)")
	}

	@Test("A single-touch journey gives that touch everything under every rule")
	func singleTouchIsUnanimous() throws {
		let only = [Journey(channels: ["Solo"], converted: true, value: 20, ages: [0])]
		let models: [HeuristicAttribution] = [.firstTouch, .lastTouch, .linear,
											  .positionBased(first: 0.4, last: 0.4),
											  .timeDecay(halfLife: 10)]
		for model in models {
			let credit = try model.attribute(journeys: only)
			let solo = try #require(credit["Solo"], "\(model)")
			#expect(Swift.abs(solo - 20) < 1e-9, "\(model) gave \(solo)")
			#expect(credit.count == 1, "\(model) invented a channel")
		}
	}

	// MARK: - Where last touch is not an answer

	@Test("An upper-funnel channel scores exactly zero on last touch")
	func lastTouchZeroesTheOpener() throws {
		// Awareness opens five journeys that convert and never closes one. Close ends all
		// ten, converting on five. Last touch reports Awareness as worth nothing at all,
		// which is a claim about influence the data does not support.
		var funnel: [Journey] = []
		for _ in 0..<5 {
			funnel.append(Journey(channels: ["Awareness", "Close"], converted: true, value: 1))
		}
		for _ in 0..<5 {
			funnel.append(Journey(channels: ["Close"], converted: false, value: 0))
		}
		let credit = try HeuristicAttribution.lastTouch.attribute(journeys: funnel)
		let awareness = try #require(credit["Awareness"])
		#expect(Swift.abs(awareness) < 1e-12, "last touch scores the opener at \(awareness)")
		#expect(Swift.abs((credit["Close"] ?? 0) - 5) < 1e-9, "Close \(credit["Close"] ?? 0)")

		// First touch inverts the error rather than fixing it.
		let opening = try HeuristicAttribution.firstTouch.attribute(journeys: funnel)
		#expect(Swift.abs((opening["Awareness"] ?? 0) - 5) < 1e-9, "\(opening)")
		let closer = try #require(opening["Close"])
		#expect(Swift.abs(closer) < 1e-12, "and now the closer is worth \(closer)")
	}

	// MARK: - Refusals

	@Test("Time decay refuses journeys with no timings rather than using position")
	func timeDecayRequiresTimings() {
		let untimed = [Journey(channels: ["A", "B"], converted: true, value: 1)]
		#expect(throws: AttributionError.missingTimings) {
			_ = try HeuristicAttribution.timeDecay(halfLife: 10).attribute(journeys: untimed)
		}
		// The other rules do not need them.
		#expect(throws: Never.self) {
			_ = try HeuristicAttribution.linear.attribute(journeys: untimed)
		}
	}

	@Test("Position weights that leave no room for the middle are refused")
	func positionWeightsMustLeaveAMiddle() {
		#expect(throws: AttributionError.self) {
			_ = try HeuristicAttribution.positionBased(first: 0.6, last: 0.6)
				.attribute(journeys: Self.journeys)
		}
		#expect(throws: AttributionError.self) {
			_ = try HeuristicAttribution.positionBased(first: -0.1, last: 0.5)
				.attribute(journeys: Self.journeys)
		}
		// Exactly one is fine — it means no middle credit, not an invalid split.
		#expect(throws: Never.self) {
			_ = try HeuristicAttribution.positionBased(first: 0.5, last: 0.5)
				.attribute(journeys: Self.journeys)
		}
	}

	@Test("A non-positive half-life is refused")
	func halfLifeMustBePositive() {
		#expect(throws: AttributionError.invalidHalfLife(0)) {
			_ = try HeuristicAttribution.timeDecay(halfLife: 0).attribute(journeys: Self.journeys)
		}
	}

	@Test("Data that does not describe an experiment is refused")
	func malformedInputIsRefused() {
		#expect(throws: AttributionError.noJourneys) {
			_ = try HeuristicAttribution.linear.attribute(journeys: [])
		}
		let empty = [Journey(channels: [], converted: true, value: 1)]
		#expect(throws: AttributionError.emptyJourney(index: 0)) {
			_ = try HeuristicAttribution.linear.attribute(journeys: empty)
		}
		let nothingConverted = [Journey(channels: ["A"], converted: false, value: 0)]
		#expect(throws: AttributionError.noConversions) {
			_ = try HeuristicAttribution.linear.attribute(journeys: nothingConverted)
		}
		let ragged = [Journey(channels: ["A", "B"], converted: true, value: 1, ages: [1])]
		#expect(throws: AttributionError.mismatchedAges(index: 0)) {
			_ = try HeuristicAttribution.linear.attribute(journeys: ragged)
		}
		let negative = [Journey(channels: ["A"], converted: true, value: -5)]
		#expect(throws: AttributionError.invalidValue(index: 0)) {
			_ = try HeuristicAttribution.linear.attribute(journeys: negative)
		}
	}
}

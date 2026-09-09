//
//  AssociationRulesTests.swift
//  BusinessMath
//
//  Support, confidence and lift, and the three ways a market-basket rule reads as a
//  finding when it is not one.
//
//  - **A high confidence on a popular consequent.** "Eighty per cent of baskets with
//    bread also contain milk" sounds like a fact about bread. On the fixture below it is
//    a fact about milk, which is in eighty per cent of *all* baskets — and the honest
//    statistics say so exactly: lift is 1.0, leverage is 0.0 and conviction is 1.0, each
//    of them sitting precisely on its null value while confidence reads 0.8.
//  - **An arrow drawn on a symmetric number.** Lift is `P(A∪C)/(P(A)·P(C))`, so
//    `lift(A → C)` and `lift(C → A)` are the same number. Quoting a rule with a direction
//    and a lift mixes a directional statistic with one that has no direction at all.
//  - **An empty result that means "you asked wrong".** A threshold outside (0, 1] is not
//    a question with no answers; it is not a question. It returns nil, and "nothing
//    cleared your bar" returns an empty array.
//
//  Two identities anchor the arithmetic. `support(A ∪ C) = confidence · support(A)` is
//  the definition of conditional probability rearranged, and it must hold for every rule
//  generated. And the co-occurrence count between two items must equal the shared-count
//  weight of the bipartite projection of the same transactions — the same quantity
//  computed by two modules that share no code.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Association rules")
struct AssociationRulesTests {

	/// Ten baskets. Bread in five, milk in eight, eggs in three, jam in one.
	///
	/// Bread and milk co-occur four times, which is exactly what independence predicts:
	/// `0.5 × 0.8 × 10 = 4`. Jam and eggs co-occur once, which is more than the `0.3`
	/// independence predicts.
	static let baskets: [[String]] = [
		["bread", "milk"], ["bread", "milk"], ["bread", "milk"], ["bread", "milk"],
		["bread", "eggs"],
		["milk"], ["milk"], ["milk"],
		["milk", "eggs"],
		["eggs", "jam"]
	]

	static func market() throws -> MarketBasket {
		try #require(MarketBasket(transactions: baskets))
	}

	// MARK: - Counting

	@Test("Support counts baskets, and duplicates within one do not double it")
	func supportCountsBaskets() throws {
		let market = try Self.market()
		#expect(market.transactions.count == 10)
		#expect(market.items == ["bread", "eggs", "jam", "milk"])
		#expect(Swift.abs(market.support(of: ["bread"]) - 0.5) < 1e-12)
		#expect(Swift.abs(market.support(of: ["milk"]) - 0.8) < 1e-12)
		#expect(market.count(of: ["bread", "milk"]) == 4)
		#expect(market.count(of: ["bread", "jam"]) == 0)

		// Two loaves in one basket is still one basket.
		let doubled = try #require(MarketBasket(transactions: [["bread", "bread", "milk"]]))
		#expect(doubled.transactions[0].count == 2)
		#expect(Swift.abs(doubled.support(of: ["bread"]) - 1) < 1e-12)
	}

	@Test("The empty itemset is in every basket")
	func emptyItemsetIsUniversal() throws {
		let market = try Self.market()
		#expect(market.count(of: []) == 10)
		#expect(Swift.abs(market.support(of: []) - 1) < 1e-12)
	}

	// MARK: - The rule that is not a finding

	@Test("A popular consequent gives high confidence and no lift at all")
	func popularConsequentHasNoLift() throws {
		let market = try Self.market()
		let rule = try #require(market.rule(antecedent: ["bread"], consequent: ["milk"]))
		#expect(Swift.abs(rule.confidence - 0.8) < 1e-12, "confidence \(rule.confidence)")
		// Every honest statistic sits exactly on its null value.
		#expect(Swift.abs(rule.lift - 1) < 1e-12, "lift \(rule.lift)")
		#expect(Swift.abs(rule.leverage) < 1e-12, "leverage \(rule.leverage)")
		let conviction = try #require(rule.conviction)
		#expect(Swift.abs(conviction - 1) < 1e-12, "conviction \(conviction)")
	}

	@Test("Lift is symmetric where confidence is not")
	func liftCarriesNoDirection() throws {
		let market = try Self.market()
		let forward = try #require(market.rule(antecedent: ["jam"], consequent: ["eggs"]))
		let backward = try #require(market.rule(antecedent: ["eggs"], consequent: ["jam"]))
		#expect(Swift.abs(forward.lift - backward.lift) < 1e-12,
				"\(forward.lift) against \(backward.lift)")
		#expect(Swift.abs(forward.leverage - backward.leverage) < 1e-12, "leverage")
		// Confidence tells them apart: one is certain, the other is one chance in three.
		#expect(Swift.abs(forward.confidence - 1) < 1e-12, "\(forward.confidence)")
		#expect(Swift.abs(backward.confidence - 1.0 / 3.0) < 1e-12, "\(backward.confidence)")
	}

	@Test("A real association, worked by hand")
	func strongRuleIsScored() throws {
		let market = try Self.market()
		let rule = try #require(market.rule(antecedent: ["jam"], consequent: ["eggs"]))
		#expect(rule.count == 1)
		#expect(Swift.abs(rule.support - 0.1) < 1e-12, "support \(rule.support)")
		#expect(Swift.abs(rule.lift - 3.3333333333333335) < 1e-12, "lift \(rule.lift)")
		#expect(Swift.abs(rule.leverage - 0.07) < 1e-12, "leverage \(rule.leverage)")
		// A rule with no counterexamples has infinite conviction, which is not a number.
		#expect(rule.conviction == nil)
	}

	// MARK: - Identities

	@Test("Support of the union is confidence times support of the antecedent")
	func conditionalProbabilityIdentity() throws {
		let market = try Self.market()
		let rules = try #require(market.rules(minimumSupport: 0.05, minimumConfidence: 0.05))
		#expect(!rules.isEmpty, "the fixture should generate rules")
		for rule in rules {
			let left: Double = market.support(of: rule.antecedent)
			let implied: Double = rule.confidence * left
			#expect(Swift.abs(rule.support - implied) < 1e-12,
					"\(rule.antecedent.sorted()): \(rule.support) against \(implied)")
			// And lift is the joint support over the independent one.
			let right: Double = market.support(of: rule.consequent)
			let independent: Double = left * right
			let impliedLift: Double = rule.support / independent
			#expect(Swift.abs(rule.lift - impliedLift) < 1e-12, "lift \(rule.lift)")
		}
	}

	@Test("Co-occurrence equals the bipartite projection's shared count")
	func projectionReproducesCoOccurrence() throws {
		let market = try Self.market()
		let projected = try #require(market.projection(weighting: .sharedCount))
		for first in market.items {
			for second in market.items where second > first {
				let counted: Double = Double(market.count(of: [first, second]))
				let weight: Double = projected.weight(between: first, and: second)
				#expect(Swift.abs(counted - weight) < 1e-12,
						"\(first)/\(second): counted \(counted), projected \(weight)")
			}
		}
	}

	// MARK: - Generation

	@Test("Frequent itemsets clear the bar, and nothing below it appears")
	func frequentItemsetsRespectTheBar() throws {
		let market = try Self.market()
		let sets = try #require(market.frequentItemsets(minimumSupport: 0.3, maximumSize: 3))
		for itemset in sets {
			#expect(itemset.support >= 0.3, "\(itemset.items.sorted()) at \(itemset.support)")
			let recomputed: Double = market.support(of: itemset.items)
			#expect(Swift.abs(itemset.support - recomputed) < 1e-12, "\(itemset.items.sorted())")
		}
		// bread (0.5), milk (0.8) and eggs (0.3) clear the bar; jam at 0.1 does not.
		let singles = sets.filter { $0.items.count == 1 }
		#expect(singles.count == 3, "\(singles.map { $0.items.sorted() })")

		// One pair survives level two: bread and milk at 0.4. The other two pairs sit at
		// 0.1, and no triple occurs at all — which is the level-wise generation stopping
		// rather than a size cap.
		let pairs = sets.filter { $0.items.count == 2 }
		#expect(pairs.count == 1, "\(pairs.map { $0.items.sorted() })")
		let pair = try #require(pairs.first)
		#expect(pair.items == ["bread", "milk"], "\(pair.items.sorted())")
		#expect(Swift.abs(pair.support - 0.4) < 1e-12, "\(pair.support)")
		#expect(sets.allSatisfy { $0.items.count <= 2 }, "no triple occurs in this data")
	}

	@Test("Rules are generated in a total order, so the same input gives the same list")
	func rulesAreDeterministic() throws {
		let market = try Self.market()
		let first = try #require(market.rules(minimumSupport: 0.1, minimumConfidence: 0.5))
		let second = try #require(market.rules(minimumSupport: 0.1, minimumConfidence: 0.5))
		#expect(first.count == 3, "\(first.map { "\($0.antecedent.sorted())→\($0.consequent.sorted())" })")
		#expect(first == second)
		// Strongest lift first: jam → eggs at 3.33, then the two that tie at 1.0.
		#expect(first[0].antecedent == ["jam"], "\(first[0].antecedent)")
		#expect(Swift.abs(first[0].lift - 3.3333333333333335) < 1e-12)
		// bread → milk and milk → bread tie on lift and on support, so the names decide.
		#expect(first[1].antecedent == ["bread"], "\(first[1].antecedent)")
		#expect(first[2].antecedent == ["milk"], "\(first[2].antecedent)")
	}

	@Test("Nothing clearing the bar is an empty list, not a refusal")
	func emptyResultIsAnAnswer() throws {
		let market = try Self.market()
		let impossible = try #require(market.rules(minimumSupport: 0.99, minimumConfidence: 0.99))
		#expect(impossible.isEmpty, "\(impossible.count)")
	}

	// MARK: - Refusals

	@Test("Thresholds that are not probabilities are refused")
	func thresholdsMustBeProbabilities() throws {
		let market = try Self.market()
		#expect(market.rules(minimumSupport: 0, minimumConfidence: 0.5) == nil)
		#expect(market.rules(minimumSupport: 1.5, minimumConfidence: 0.5) == nil)
		#expect(market.rules(minimumSupport: 0.1, minimumConfidence: 0) == nil)
		#expect(market.rules(minimumSupport: 0.1, minimumConfidence: 1.5) == nil)
		#expect(market.frequentItemsets(minimumSupport: -0.1) == nil)
		#expect(market.frequentItemsets(minimumSupport: 0.1, maximumSize: 0) == nil)
	}

	@Test("A rule conditioned on something that never happened is refused")
	func absentAntecedentIsRefused() throws {
		let market = try Self.market()
		#expect(market.rule(antecedent: ["caviar"], consequent: ["milk"]) == nil)
		#expect(market.rule(antecedent: ["milk"], consequent: ["caviar"]) == nil)
		#expect(market.rule(antecedent: [], consequent: ["milk"]) == nil)
		// Overlapping sides would count the same item on both, inflating confidence.
		#expect(market.rule(antecedent: ["bread", "milk"], consequent: ["milk"]) == nil)
	}

	@Test("Transactions that do not describe a purchase are refused")
	func malformedTransactionsAreRefused() {
		#expect(MarketBasket(transactions: []) == nil)
		#expect(MarketBasket(transactions: [["bread"], []]) == nil)
	}
}

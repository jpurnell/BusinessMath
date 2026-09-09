//
//  AssociationRules.swift
//  BusinessMath
//

import Foundation
import Numerics

/// A set of items that appears together often enough to be worth a rule.
public struct FrequentItemset: Sendable, Equatable {

	/// The items.
	public let items: Set<String>

	/// How many transactions contain all of them.
	public let count: Int

	/// That count as a share of all transactions.
	public let support: Double

	/// Creates an itemset.
	///
	/// - Parameters:
	///   - items: The items.
	///   - count: Transactions containing all of them.
	///   - support: That count over the transaction count.
	public init(items: Set<String>, count: Int, support: Double) {
		self.items = items
		self.count = count
		self.support = support
	}
}

/// "People who bought the antecedent also bought the consequent", with the four numbers
/// that say whether that is worth knowing.
public struct AssociationRule: Sendable, Equatable {

	/// The items on the left of the arrow.
	public let antecedent: Set<String>

	/// The items on the right.
	public let consequent: Set<String>

	/// Transactions containing every item on both sides.
	public let count: Int

	/// `P(A ∪ C)` — how much of the data the rule is about at all.
	public let support: Double

	/// `P(C | A)` — how often the rule held where it applied. **Directional.**
	public let confidence: Double

	/// `P(C | A) / P(C)` — how much the antecedent moved the odds. **Symmetric**, so
	/// `lift(A → C)` and `lift(C → A)` are the same number and it carries no direction.
	///
	/// One is the null value: the antecedent told you nothing.
	public let lift: Double

	/// `P(A ∪ C) − P(A)·P(C)` — the same finding as lift, on an absolute scale.
	///
	/// Exactly zero when the two are independent, which is the reading that survives being
	/// quoted next to a confidence figure.
	public let leverage: Double

	/// `(1 − P(C)) / (1 − confidence)` — how much more often the rule would be wrong if
	/// the two were independent.
	///
	/// `nil` at a confidence of exactly one: a rule with no counterexamples has infinite
	/// conviction, and infinity is not a number to hand a caller.
	public let conviction: Double?

	/// Creates a rule.
	///
	/// - Parameters:
	///   - antecedent: Items on the left.
	///   - consequent: Items on the right.
	///   - count: Transactions containing both sides.
	///   - support: `P(A ∪ C)`.
	///   - confidence: `P(C | A)`.
	///   - lift: `confidence / P(C)`.
	///   - leverage: `P(A ∪ C) − P(A)·P(C)`.
	///   - conviction: `(1 − P(C)) / (1 − confidence)`, or `nil` at certainty.
	public init(antecedent: Set<String>, consequent: Set<String>, count: Int,
				support: Double, confidence: Double, lift: Double,
				leverage: Double, conviction: Double?) {
		self.antecedent = antecedent
		self.consequent = consequent
		self.count = count
		self.support = support
		self.confidence = confidence
		self.lift = lift
		self.leverage = leverage
		self.conviction = conviction
	}
}

/// Transactions, and the rules that can honestly be read out of them.
///
/// ```swift
/// let baskets = [["bread", "milk"], ["bread", "milk"], ["milk"], ["eggs", "jam"]]
/// if let market = MarketBasket(transactions: baskets),
///    let rules = market.rules(minimumSupport: 0.2, minimumConfidence: 0.5) {
///     print(market.items.count, rules.count)
/// }
/// ```
///
/// ## Confidence is the number that misleads
///
/// A rule reading *"80% of baskets with bread also contain milk"* sounds like a finding
/// about bread. It is not, if 80% of **all** baskets contain milk — then bread told you
/// nothing, and the honest statistics say so precisely: ``AssociationRule/lift`` is
/// exactly 1 and ``AssociationRule/leverage`` is exactly 0. Confidence alone cannot
/// distinguish a real association from a popular consequent, and it is the number
/// reporting quotes.
///
/// Note also that lift is **symmetric**. `lift(bread → milk)` and `lift(milk → bread)` are
/// the same number, so a high lift never tells you which item drives which. Confidence is
/// directional and lift is not, and a rule quoted with an arrow and a lift is quietly
/// mixing the two.
///
/// ## Empty results and refusals mean different things
///
/// ``rules(minimumSupport:minimumConfidence:maximumItemsetSize:maximumAntecedent:)``
/// returns an empty array when nothing cleared your thresholds — a real answer — and `nil`
/// when the thresholds themselves were not probabilities. The same distinction applies to
/// ``frequentItemsets(minimumSupport:maximumSize:)``.
///
/// ## Cost
///
/// Itemset generation is level-wise with subset pruning — Apriori — so the work is
/// governed by how many sets clear `minimumSupport` rather than by `2ⁿ`. A low minimum
/// support on a wide catalogue is still expensive, which is what `maximumSize` bounds.
public struct MarketBasket: Sendable {

	/// The transactions, each as a set — a basket records what was bought, not how many.
	public let transactions: [Set<String>]

	/// Every distinct item, sorted.
	public let items: [String]

	/// Which transactions each item appears in.
	let occurrences: [String: Set<Int>]

	/// Builds a basket set.
	///
	/// - Parameter transactions: One array of item names per transaction. Duplicates
	///   within a transaction collapse, since support counts baskets rather than units.
	/// - Returns: `nil` for no transactions or a transaction with nothing in it. An empty
	///   basket contributes only to the denominator, deflating every support in the table
	///   with nothing to show for it; if empty visits are meaningful to you, count them
	///   separately.
	public init?(transactions: [[String]]) {
		guard !transactions.isEmpty else { return nil }
		guard transactions.allSatisfy({ !$0.isEmpty }) else { return nil }

		var baskets: [Set<String>] = []
		var index: [String: Set<Int>] = [:]
		for (slot, basket) in transactions.enumerated() {
			let unique = Set(basket)
			baskets.append(unique)
			for item in unique { index[item, default: []].insert(slot) }
		}
		self.transactions = baskets
		self.items = index.keys.sorted()
		self.occurrences = index
	}

	/// How many transactions contain every one of these items.
	///
	/// - Parameter items: The items to look for. The empty set is contained in every
	///   transaction, so it counts all of them.
	/// - Returns: The count.
	public func count(of items: Set<String>) -> Int {
		guard let first = items.first else { return transactions.count }
		guard var shared = occurrences[first] else { return 0 }
		for item in items where item != first {
			guard let next = occurrences[item] else { return 0 }
			shared.formIntersection(next)
			if shared.isEmpty { return 0 }
		}
		return shared.count
	}

	/// The share of transactions containing every one of these items.
	///
	/// - Parameter items: The items to look for.
	/// - Returns: A probability. One for the empty set.
	public func support(of items: Set<String>) -> Double {
		let total: Double = Double(transactions.count)
		guard total > 0 else { return 0 }
		return Double(count(of: items)) / total
	}

	/// Every itemset clearing a support threshold, generated level by level.
	///
	/// - Parameters:
	///   - minimumSupport: The bar, in `(0, 1]`.
	///   - maximumSize: Largest itemset to consider. Defaults to three.
	/// - Returns: The itemsets, smallest first and sorted within each size, or `nil` if
	///   the threshold is not a probability or `maximumSize` is below one. An empty array
	///   means nothing cleared the bar.
	public func frequentItemsets(minimumSupport: Double,
								 maximumSize: Int = 3) -> [FrequentItemset]? {
		guard minimumSupport > 0, minimumSupport <= 1, minimumSupport.isFinite else {
			return nil
		}
		guard maximumSize >= 1 else { return nil }

		var found: [FrequentItemset] = []
		var previous: [Set<String>] = []
		for item in items {
			let single: Set<String> = [item]
			let occurrences = count(of: single)
			let share = support(of: single)
			guard share >= minimumSupport else { continue }
			found.append(FrequentItemset(items: single, count: occurrences, support: share))
			previous.append(single)
		}

		var size = 2
		while size <= maximumSize, !previous.isEmpty {
			var current: [Set<String>] = []
			var seen: Set<[String]> = []
			for base in previous {
				for item in items where !base.contains(item) {
					let candidate = base.union([item])
					let key = candidate.sorted()
					guard !seen.contains(key) else { continue }
					seen.insert(key)
					// Apriori's pruning step: every subset of a frequent set is frequent,
					// so a candidate with an infrequent subset cannot clear the bar and
					// need not be counted.
					guard Self.subsetsAreFrequent(candidate, among: previous) else { continue }
					let occurrences = count(of: candidate)
					let share = support(of: candidate)
					guard share >= minimumSupport else { continue }
					current.append(candidate)
					found.append(FrequentItemset(items: candidate, count: occurrences,
												 support: share))
				}
			}
			previous = current
			size += 1
		}
		return found
	}

	/// Whether every one-smaller subset of a candidate is already known frequent.
	///
	/// - Parameters:
	///   - candidate: The set being considered.
	///   - frequent: The frequent sets one size smaller.
	/// - Returns: `true` when no subset is missing.
	static func subsetsAreFrequent(_ candidate: Set<String>, among frequent: [Set<String>]) -> Bool {
		let known = Set(frequent.map { $0.sorted() })
		for item in candidate {
			let subset = candidate.subtracting([item])
			guard known.contains(subset.sorted()) else { return false }
		}
		return true
	}

	/// Every rule clearing both thresholds.
	///
	/// - Parameters:
	///   - minimumSupport: Support bar for the underlying itemset, in `(0, 1]`.
	///   - minimumConfidence: Confidence bar, in `(0, 1]`.
	///   - maximumItemsetSize: Largest itemset to split into rules. Defaults to three.
	///   - maximumAntecedent: Largest left-hand side. Defaults to two.
	/// - Returns: The rules, strongest lift first, or `nil` if a threshold is not a
	///   probability. An empty array means nothing cleared the bars — which is an answer,
	///   and a different one from `nil`. Ties on lift break by support and then by name,
	///   so the order is total and the same input always returns the same sequence.
	public func rules(minimumSupport: Double,
					  minimumConfidence: Double,
					  maximumItemsetSize: Int = 3,
					  maximumAntecedent: Int = 2) -> [AssociationRule]? {
		guard minimumConfidence > 0, minimumConfidence <= 1, minimumConfidence.isFinite else {
			return nil
		}
		guard maximumAntecedent >= 1 else { return nil }
		guard let sets = frequentItemsets(minimumSupport: minimumSupport,
										  maximumSize: maximumItemsetSize) else {
			return nil
		}

		var rules: [AssociationRule] = []
		for itemset in sets where itemset.items.count >= 2 {
			for antecedent in Self.properSubsets(of: itemset.items, maximumSize: maximumAntecedent) {
				let consequent = itemset.items.subtracting(antecedent)
				guard !consequent.isEmpty else { continue }
				guard let rule = self.rule(antecedent: antecedent, consequent: consequent),
					  rule.confidence >= minimumConfidence else { continue }
				rules.append(rule)
			}
		}
		// Sorted to a total order, not just by strength: two rules can tie on both lift
		// and support — `bread → milk` and `milk → bread` do, on the fixture in the
		// tests — and Swift's sort is not stable, so without the name comparisons the
		// same input could return them in either order.
		rules.sort { left, right in
			if left.lift != right.lift { return left.lift > right.lift }
			if left.support != right.support { return left.support > right.support }
			let leftAntecedent = left.antecedent.sorted()
			let rightAntecedent = right.antecedent.sorted()
			if leftAntecedent != rightAntecedent {
				return leftAntecedent.lexicographicallyPrecedes(rightAntecedent)
			}
			return left.consequent.sorted().lexicographicallyPrecedes(right.consequent.sorted())
		}
		return rules
	}

	/// One rule, scored.
	///
	/// - Parameters:
	///   - antecedent: Items on the left. Must be non-empty and must occur.
	///   - consequent: Items on the right. Must be non-empty and must occur.
	/// - Returns: The rule, or `nil` when either side never appears — a confidence
	///   conditioned on something that never happened is a division by zero, not a zero.
	public func rule(antecedent: Set<String>, consequent: Set<String>) -> AssociationRule? {
		guard !antecedent.isEmpty, !consequent.isEmpty else { return nil }
		guard antecedent.isDisjoint(with: consequent) else { return nil }

		let leftSupport: Double = support(of: antecedent)
		guard leftSupport > 0 else { return nil }
		let rightSupport: Double = support(of: consequent)
		guard rightSupport > 0 else { return nil }

		let both = antecedent.union(consequent)
		let jointCount = count(of: both)
		let joint: Double = support(of: both)
		let confidence: Double = joint / leftSupport
		let lift: Double = confidence / rightSupport
		let independent: Double = leftSupport * rightSupport
		let leverage: Double = joint - independent

		var conviction: Double?
		let misses: Double = 1 - confidence
		if misses > 0 {
			let numerator: Double = 1 - rightSupport
			conviction = numerator / misses
		}

		return AssociationRule(antecedent: antecedent, consequent: consequent,
							   count: jointCount, support: joint, confidence: confidence,
							   lift: lift, leverage: leverage, conviction: conviction)
	}

	/// Non-empty proper subsets of a set, up to a size.
	///
	/// - Parameters:
	///   - set: The set to split.
	///   - maximumSize: Largest subset to return.
	/// - Returns: The subsets, in no particular order.
	static func properSubsets(of set: Set<String>, maximumSize: Int) -> [Set<String>] {
		let ordered = set.sorted()
		let count = ordered.count
		guard count > 1, count <= 20 else { return [] }
		var result: [Set<String>] = []
		let limit = 1 << count
		for mask in 1..<(limit - 1) {
			guard mask.nonzeroBitCount <= maximumSize else { continue }
			var subset: Set<String> = []
			for bit in 0..<count where mask & (1 << bit) != 0 {
				subset.insert(ordered[bit])
			}
			result.append(subset)
		}
		return result
	}

	/// The items projected onto each other by the transactions they share.
	///
	/// With ``ProjectionWeighting/sharedCount`` the edge weight between two items is
	/// exactly ``count(of:)`` for the pair — the co-occurrence matrix, reachable by the
	/// traversal, centrality and community algorithms in `Network/`.
	///
	/// - Parameter weighting: How to weight the shared transactions. Defaults to the raw
	///   count.
	/// - Returns: The projection, or `nil` if there is nothing to project.
	public func projection(weighting: ProjectionWeighting = .sharedCount) -> BipartiteProjection<String>? {
		var memberships: [String: Set<String>] = [:]
		for (item, slots) in occurrences {
			memberships[item] = Set(slots.map { "t\($0)" })
		}
		return BipartiteProjection(memberships: memberships, weighting: weighting)
	}
}

//
//  GroupedChoiceData.swift
//  BusinessMath
//

import Foundation
import Numerics

/// Which of the likelihoods a grouped choice model uses.
///
/// - ``subset``: the group chose an unordered set of its candidates (the *conditional logit*).
/// - ``ranking``: the group ranked its top candidates in order (the *Plackett-Luce* model).
///
/// With exactly one chosen candidate per group the two are the same function (the multinomial logit). With more than one
/// they are **different likelihoods**: the subset form does not know an order, and Plackett-Luce taken over an arbitrary
/// order of an unordered set would make the answer depend on the order chosen. Build unordered data with
/// ``GroupedChoiceData/init(groups:offsets:)`` and ranked data with ``GroupedChoiceData/init(rankedGroups:offsets:)``; each
/// model refuses the other's data.
public enum ChoiceLikelihood: Sendable, Equatable {
	/// The group chose an unordered set of items; how many it chose does not move the weights.
	case subset
	/// The group ranked its top choices, best first; each next choice is made among the candidates not yet taken.
	case ranking
}

/// Why a grouped choice model could not be built or fitted.
public enum GroupedChoiceError: Error, Sendable, Equatable {
	/// No group has both a chosen and an unchosen candidate with positive weight, so there is nothing to compare.
	case noInformativeGroups
	/// An argument was the wrong shape or not finite.
	case malformedInput(reason: String)
	/// The search stopped before the estimate settled.
	case didNotConverge(iterations: Int, gradientNorm: Double)
}

/// Candidates grouped by who chose among them, for fitting what predicts a choice **within** each group.
///
/// Each group is one chooser's set of candidates: a person and everyone they could have named, a shopper and the
/// products they saw, a query and the results it returned. A candidate is **chosen** or not, and has a row of
/// numeric features. Comparing each group only with itself removes how much each chooser chooses: a talkative group
/// contributes many choices, and a pooled regression would credit any feature that merely correlates with talkative
/// groups. A candidate nobody chose is **unknown**, not rejected, so everything fitted from this data ranks; it does
/// not estimate probabilities.
///
/// ```swift
/// let data = GroupedChoiceData<Double>(groups: [
///     [(features: [1, 0], chosen: true), (features: [0, 1], chosen: false), (features: [0, 0], chosen: false)],
///     [(features: [1, 1], chosen: true), (features: [0, 0], chosen: false)],
/// ])
/// // data?.groupCount == 2, data?.featureCount == 2, data?.informativeGroups == [0, 1]
/// ```
///
/// Features are stored sparsely (only non-zero entries), so a wide, mostly-zero feature matrix costs memory in
/// proportion to what is present.
public struct GroupedChoiceData<T: Real & Sendable & BinaryFloatingPoint>: Sendable {

	/// How many groups, including any with no candidates.
	public let groupCount: Int

	/// How many feature columns every candidate has.
	public let featureCount: Int

	/// How many candidates in all.
	public let rowCount: Int

	let groupStart: [Int]
	let rowEntryStart: [Int]
	let entryFeature: [Int]
	let entryValue: [T]
	let rowChosen: [Bool]
	let rowOffset: [T]
	let rowRank: [Int]

	/// Whether the data holds ordered rankings (built by ``init(rankedGroups:offsets:)``) and so belongs to ``ChoiceLikelihood/ranking``.
	public let isRanked: Bool

	/// Creates data from dense feature rows.
	///
	/// - Parameters:
	///   - groups: One array per group; each candidate is its feature row and whether it was chosen. Every row has the
	///     same width, and every value is finite.
	///   - offsets: Optionally, one fixed number per candidate (same shape as `groups`): a contribution to the score
	///     that the fit does not adjust (for example a deduction held at its reference value). Finite values only.
	/// - Returns: `nil` for no candidates, rows of different widths, zero width, a non-finite value, or offsets of the
	///   wrong shape.
	@_specialize(exported: true, where T == Double)
	public init?(groups: [[(features: [T], chosen: Bool)]], offsets: [[T]]? = nil) {
		guard let width = groups.lazy.compactMap({ $0.first?.features.count }).first, width > 0 else { return nil }
		var sparse: [[(features: [(feature: Int, value: T)], chosen: Bool)]] = []
		sparse.reserveCapacity(groups.count)
		for group in groups {
			var rows: [(features: [(feature: Int, value: T)], chosen: Bool)] = []
			rows.reserveCapacity(group.count)
			for candidate in group {
				guard candidate.features.count == width else { return nil }
				var entries: [(feature: Int, value: T)] = []
				for (index, value) in candidate.features.enumerated() where value != T.zero {
					entries.append((feature: index, value: value))
				}
				rows.append((features: entries, chosen: candidate.chosen))
			}
			sparse.append(rows)
		}
		self.init(sparseGroups: sparse, featureCount: width, offsets: offsets)
	}

	/// Creates data from sparse feature rows: only the features a candidate has, by column index.
	///
	/// - Parameters:
	///   - sparseGroups: One array per group; each candidate is its `(feature, value)` entries and whether it was chosen.
	///     A feature may appear once per candidate; a value of zero is dropped.
	///   - featureCount: How many feature columns there are; every index is in `0..<featureCount`.
	///   - offsets: As for ``init(groups:offsets:)``.
	/// - Returns: `nil` for no candidates, no features, an index out of range or repeated within a candidate, a
	///   non-finite value, or offsets of the wrong shape.
	@_specialize(exported: true, where T == Double)
	public init?(
		sparseGroups: [[(features: [(feature: Int, value: T)], chosen: Bool)]], featureCount: Int, offsets: [[T]]? = nil
	) {
		self.init(sparseGroups: sparseGroups, featureCount: featureCount, offsets: offsets, ranks: nil)
	}

	/// The shared constructor: `ranks`, when given, holds each candidate's position in its group's ranking (`-1` if unranked).
	init?(
		sparseGroups: [[(features: [(feature: Int, value: T)], chosen: Bool)]], featureCount: Int, offsets: [[T]]?, ranks: [[Int]]?
	) {
		guard featureCount > 0, !sparseGroups.isEmpty else { return nil }
		if let offsets {
			guard offsets.count == sparseGroups.count else { return nil }
			for (index, group) in sparseGroups.enumerated() {
				guard offsets[index].count == group.count, offsets[index].allSatisfy({ $0.isFinite }) else { return nil }
			}
		}
		var groupStart: [Int] = [0]
		var rowEntryStart: [Int] = [0]
		var entryFeature: [Int] = []
		var entryValue: [T] = []
		var rowChosen: [Bool] = []
		var rowOffset: [T] = []
		var rowRank: [Int] = []
		for (groupIndex, group) in sparseGroups.enumerated() {
			for (position, candidate) in group.enumerated() {
				var seen = Set<Int>()
				for entry in candidate.features {
					guard entry.feature >= 0, entry.feature < featureCount, entry.value.isFinite else { return nil }
					guard seen.insert(entry.feature).inserted else { return nil }
					guard entry.value != T.zero else { continue }
					entryFeature.append(entry.feature)
					entryValue.append(entry.value)
				}
				rowEntryStart.append(entryFeature.count)
				rowChosen.append(candidate.chosen)
				rowOffset.append(offsets?[groupIndex][position] ?? T.zero)
				rowRank.append(ranks?[groupIndex][position] ?? -1)
			}
			groupStart.append(rowChosen.count)
		}
		guard !rowChosen.isEmpty else { return nil }
		self.groupCount = sparseGroups.count
		self.featureCount = featureCount
		self.rowCount = rowChosen.count
		self.groupStart = groupStart
		self.rowEntryStart = rowEntryStart
		self.entryFeature = entryFeature
		self.entryValue = entryValue
		self.rowChosen = rowChosen
		self.rowOffset = rowOffset
		self.rowRank = rowRank
		self.isRanked = ranks != nil
	}

	/// Creates ranked data: each group's candidates and the order in which its top choices were made.
	///
	/// - Parameters:
	///   - rankedGroups: One entry per group: every candidate's dense feature row, and `ranking`, the candidate indices from the
	///     best choice to the last one made. The ranking may cover only the top *m* of the candidates; the unranked remainder is
	///     what each ranked choice was made against.
	///   - offsets: As for ``init(groups:offsets:)``.
	/// - Returns: `nil` for no candidates, rows of different widths or zero width, a non-finite value, a ranking index out of
	///   range or repeated, or offsets of the wrong shape.
	@_specialize(exported: true, where T == Double)
	public init?(rankedGroups: [(candidates: [[T]], ranking: [Int])], offsets: [[T]]? = nil) {
		guard let width = rankedGroups.lazy.compactMap({ $0.candidates.first?.count }).first, width > 0 else { return nil }
		var sparse: [[(features: [(feature: Int, value: T)], chosen: Bool)]] = []
		var ranks: [[Int]] = []
		for group in rankedGroups {
			var positions = [Int](repeating: -1, count: group.candidates.count)
			for (position, candidate) in group.ranking.enumerated() {
				guard candidate >= 0, candidate < group.candidates.count, positions[candidate] < 0 else { return nil }
				positions[candidate] = position
			}
			var rows: [(features: [(feature: Int, value: T)], chosen: Bool)] = []
			for (index, row) in group.candidates.enumerated() {
				guard row.count == width else { return nil }
				var entries: [(feature: Int, value: T)] = []
				for (feature, value) in row.enumerated() where value != T.zero { entries.append((feature: feature, value: value)) }
				rows.append((features: entries, chosen: positions[index] >= 0))
			}
			sparse.append(rows)
			ranks.append(positions)
		}
		self.init(sparseGroups: sparse, featureCount: width, offsets: offsets, ranks: ranks)
	}

	/// How many choices a group's likelihood counts: for unordered data the number chosen (zero when nothing, or everything, was chosen), for ranked data the number ranked,
	/// less the last step when the ranking covers every candidate (it has only one candidate left to take, which says nothing).
	func stepCount(group: Int) -> Int {
		let chosen = chosenCount(group: group)
		let count = rows(ofGroup: group).count
		guard isRanked else { return chosen > 0 && chosen < count ? chosen : 0 }
		return Swift.min(chosen, count - 1)
	}

	/// The rows (flat candidate positions) belonging to `group`.
	///
	/// Scores handed to the ranking metrics are one per row, in this order.
	public func rows(ofGroup group: Int) -> Range<Int> {
		guard group >= 0, group < groupCount else { return 0..<0 }
		return groupStart[group]..<groupStart[group + 1]
	}

	/// Whether the candidate at flat position `row` was chosen.
	public func isChosen(row: Int) -> Bool {
		guard row >= 0, row < rowCount else { return false }
		return rowChosen[row]
	}

	/// How many candidates `group` chose.
	public func chosenCount(group: Int) -> Int {
		rows(ofGroup: group).reduce(0) { rowChosen[$1] ? $0 + 1 : $0 }
	}

	/// The groups that carry information.
	///
	/// For unordered data: at least one chosen and at least one unchosen candidate, since a group that chose nothing, or
	/// everything, says nothing about what distinguishes a chosen candidate. For ranked data: at least two candidates and at
	/// least one ranked (a full ranking still says which was taken before which).
	public var informativeGroups: [Int] {
		(0..<groupCount).filter { stepCount(group: $0) > 0 }
	}

	/// The groups with both a chosen and an unchosen candidate: the ones a ranking metric can compare.
	var comparableGroups: [Int] {
		(0..<groupCount).filter { group in
			let chosen = chosenCount(group: group)
			return chosen > 0 && chosen < rows(ofGroup: group).count
		}
	}
}

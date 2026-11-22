//
//  GroupedChoiceSynthetic.swift
//  BusinessMath
//
//  Synthetic grouped choices drawn from the exact model the toolkit fits, so the fit has a known answer.
//

import Foundation
@testable import BusinessMath

/// Groups of candidates whose chosen sets are drawn from the conditional-logit distribution with known weights.
enum GroupedChoiceSynthetic {

	typealias Group = [(features: [Double], chosen: Bool)]

	/// Draws `groups` groups of `candidates` candidates. A group picks its size from `sizes` (round-robin, so some groups
	/// choose many and some few), then a subset of that size with probability proportional to the product of
	/// `exp(beta · features)` over the subset: the exact conditional-logit distribution.
	///
	/// Feature `j` is binary with chance 0.3 (`j % 3 == 0`), binary with chance 0.5 (`j % 3 == 1`), or uniform on [0, 2).
	static func make(seed: UInt64, groups: Int, candidates: Int, sizes: [Int], beta: [Double]) -> [Group] {
		var generator = SplitMix64(seed: seed)
		var result: [Group] = []
		result.reserveCapacity(groups)
		for index in 0..<groups {
			var rows: [[Double]] = []
			for _ in 0..<candidates {
				let row: [Double] = (0..<beta.count).map { feature in
					switch feature % 3 {
					case 0: return Double.random(in: 0..<1, using: &generator) < 0.3 ? 1 : 0
					case 1: return Double.random(in: 0..<1, using: &generator) < 0.5 ? 1 : 0
					default: return Double.random(in: 0..<2, using: &generator)
					}
				}
				rows.append(row)
			}
			let size = sizes[index % sizes.count]
			let weights: [Double] = rows.map { row in
				var score = 0.0
				for (feature, value) in row.enumerated() { score += beta[feature] * value }
				return exp(score)
			}
			let chosen = drawSubset(weights: weights, size: size, using: &generator)
			result.append(zip(rows, 0..<candidates).map { (features: $0, chosen: chosen.contains($1)) })
		}
		return result
	}

	/// A subset of `size` of the candidates, drawn with probability proportional to the product of its weights.
	private static func drawSubset(weights: [Double], size: Int, using generator: inout SplitMix64) -> Set<Int> {
		let count = weights.count
		var masks: [Int] = []
		var cumulative: [Double] = []
		var total = 0.0
		for mask in 0..<(1 << count) where mask.nonzeroBitCount == size {
			var product = 1.0
			for bit in 0..<count where mask & (1 << bit) != 0 { product *= weights[bit] }
			total += product
			masks.append(mask)
			cumulative.append(total)
		}
		let target = Double.random(in: 0..<1, using: &generator) * total
		let picked = cumulative.firstIndex { $0 >= target } ?? (masks.count - 1)
		let mask = masks[picked]
		return Set((0..<count).filter { mask & (1 << $0) != 0 })
	}
}

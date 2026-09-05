//
//  AliasTable.swift
//  BusinessMath
//
//  Created 2026-09-04. Phase 0 of the Excel/Risk Solver coverage work.
//

import Foundation

/// Vose's alias method: constant-time sampling from an arbitrary discrete distribution.
///
/// Inverting a CDF costs a search — `O(log n)` with a cumulative array. The alias
/// method replaces it with two array reads and a comparison, by rewriting the
/// distribution as `n` equally likely columns, each holding at most two outcomes.
/// Setup is `O(n)` and happens once.
///
/// ## Where it must not be used
///
/// **The alias method is not monotone in its uniform.** It maps the unit interval onto
/// the support through a permuted table, so two nearby uniforms can land on distant
/// outcomes.
///
/// For pseudo-random draws that is irrelevant. For quasi-random draws it is fatal: the
/// entire benefit of a stratified or low-discrepancy uniform is that a *monotone*
/// transform carries the stratification through to the sample. Push a Sobol point
/// through an alias table and the distribution is still right, the variance reduction
/// is gone, and nothing in the output says so — you pay for Sobol and receive
/// pseudo-random convergence.
///
/// So a ``DiscreteDistribution`` may use this in `next(using:)`, which is the
/// pseudo-random path, and must not use it in `quantile(_:)`, which is the
/// quasi-random one.
///
/// Reference: M. D. Vose, *A linear algorithm for generating random numbers with a
/// given distribution*, IEEE Trans. Software Engineering 17 (1991), 972–975.
public struct AliasTable: Sendable {

	/// For each column, the probability of taking its primary outcome.
	private let thresholds: [Double]

	/// For each column, the outcome taken when the threshold is not met.
	private let aliases: [Int]

	/// How many outcomes the table covers.
	public var outcomeCount: Int { thresholds.count }

	/// Builds the table from a set of weights.
	///
	/// Weights need not sum to one; they are normalised. Negative weights are rejected,
	/// because a negative probability is a caller error rather than something to
	/// silently clamp.
	///
	/// The construction scales every probability by `n`, so the average column is
	/// exactly full. Columns below average are then paired with columns above average —
	/// each short column is topped up from a tall one, and the tall one goes back into
	/// whichever pile it now belongs to. Every column ends exactly full, which is what
	/// makes the draw two reads.
	///
	/// - Parameter weights: One non-negative weight per outcome, not all zero.
	/// - Returns: `nil` if the weights are empty, negative, or sum to zero.
	public init?(weights: [Double]) {
		let count = weights.count
		guard count > 0 else { return nil }
		guard weights.allSatisfy({ $0 >= 0 && $0.isFinite }) else { return nil }

		let total = weights.reduce(0, +)
		guard total > 0 else { return nil }

		var scaled = weights.map { $0 * Double(count) / total }
		var alias = [Int](repeating: 0, count: count)
		var threshold = [Double](repeating: 1, count: count)

		var short: [Int] = []
		var tall: [Int] = []
		for (index, value) in scaled.enumerated() {
			if value < 1 { short.append(index) } else { tall.append(index) }
		}

		while let small = short.popLast(), let large = tall.popLast() {
			threshold[small] = scaled[small]
			alias[small] = large
			scaled[large] -= 1 - scaled[small]
			if scaled[large] < 1 { short.append(large) } else { tall.append(large) }
		}

		// Whatever remains is full to within rounding; make that exact.
		for index in short { threshold[index] = 1 }
		for index in tall { threshold[index] = 1 }

		self.thresholds = threshold
		self.aliases = alias
	}

	/// Draws an outcome index.
	///
	/// Takes a single uniform and splits it: the integer part of `u·n` chooses the
	/// column, the fractional part decides between that column's two outcomes. Using
	/// one draw rather than two keeps the sampler at one uniform per value, which is
	/// what every other sampler in this package promises.
	///
	/// - Parameter generator: The random source.
	/// - Returns: An index into the original weights.
	public func next<G: RandomNumberGenerator>(using generator: inout G) -> Int {
		let uniform = Double.openUnitRandom(using: &generator)
		let scaled = uniform * Double(outcomeCount)
		let column = Swift.min(outcomeCount - 1, Int(scaled))
		let remainder = scaled - Double(column)
		return remainder < thresholds[column] ? column : aliases[column]
	}
}

//
//  MultivariateSampling.swift
//  BusinessMath
//

import Foundation
import Numerics

/// Draws whole rows from a dataset **with replacement**.
///
/// Binds Risk Solver's `PsiMVResample(data)`.
///
/// ```swift
/// let history = [[0.01, -0.02], [0.03, 0.01], [-0.01, 0.00]]
/// let resampler = try MultivariateResample(rows: history)
/// var rng = DeterministicRNG(seed: 42)
/// let draw = resampler.sample(using: &rng)   // one of the three rows, entire
/// ```
///
/// ## Why the row and not the column
///
/// Drawing each column independently would reproduce every marginal distribution
/// exactly and destroy the dependence between them — which is usually the only reason
/// the data was multivariate. Keeping rows intact preserves the joint distribution,
/// including whatever tail dependence and nonlinear association the sample happens to
/// contain, without anyone having to name a copula or estimate a correlation.
///
/// The cost is that it can only produce combinations that occurred. A resampled path
/// never contains a pair of values the history did not, so this understates the tail
/// exactly where a model is most often asked about it. That is a property of the
/// method rather than of this implementation, and it is the reason to prefer a fitted
/// ``DistributionMVNormal`` when the question is about events not yet seen.
public struct MultivariateResample: Sendable {

	/// What can go wrong constructing a multivariate sampler over rows.
	public enum Failure: Error, Sendable, Equatable {

		/// There were no rows to draw from.
		case empty

		/// The rows are not all the same length, so there is no dimension.
		case raggedRows

		/// A value was infinite or not a number.
		case nonFiniteValue
	}

	/// The rows available, unchanged by drawing.
	public let rows: [[Double]]

	/// How many columns each row has.
	public let dimension: Int

	/// Creates a resampler over `rows`.
	///
	/// - Parameter rows: The observations, one per row, all the same length.
	/// - Throws: ``Failure`` naming what was wrong with the data.
	public init(rows: [[Double]]) throws {
		guard let first = rows.first else { throw Failure.empty }
		let width = first.count
		guard width > 0 else { throw Failure.empty }
		guard rows.allSatisfy({ $0.count == width }) else { throw Failure.raggedRows }
		guard rows.allSatisfy({ $0.allSatisfy { $0.isFinite } }) else {
			throw Failure.nonFiniteValue
		}
		self.rows = rows
		self.dimension = width
	}

	/// Draws one row, with replacement.
	///
	/// - Parameter generator: The random source; seed it for a reproducible stream.
	/// - Returns: One of the rows, entire.
	public func sample<G: RandomNumberGenerator>(using generator: inout G) -> [Double] {
		let index = Int(generator.next(upperBound: UInt64(rows.count)))
		return rows[index]
	}

	/// Draws `count` rows, with replacement.
	///
	/// - Parameters:
	///   - count: How many rows to draw. A non-positive count yields nothing.
	///   - generator: The random source.
	/// - Returns: `count` rows, repeats allowed.
	public func sample<G: RandomNumberGenerator>(count: Int, using generator: inout G) -> [[Double]] {
		guard count > 0 else { return [] }
		return (0..<count).map { _ in sample(using: &generator) }
	}

	/// The mean of each column across the whole dataset.
	public var columnMeans: [Double] {
		var totals = [Double](repeating: 0, count: dimension)
		for row in rows {
			for index in 0..<dimension { totals[index] += row[index] }
		}
		let count = Double(rows.count)
		return totals.map { $0 / count }
	}
}

/// Draws whole rows from a dataset **without replacement**.
///
/// Binds Risk Solver's `PsiMVShuffle(data)`, and stands to ``MultivariateResample``
/// exactly as ``Shuffle`` stands to sampling with replacement: same rows, but each is
/// used once and then gone.
///
/// ```swift
/// var deck = try MultivariateShuffle(rows: [[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]])
/// var rng = DeterministicRNG(seed: 42)
/// let first = deck.next(using: &rng)    // some row
/// let second = deck.next(using: &rng)   // a different row
/// ```
///
/// ## Not a distribution, and deliberately not one
///
/// Same reasoning as ``Shuffle``, and the same refusal to conform: successive draws are
/// not independent, and the law changes after each one. Over a full pass this reproduces
/// the empirical joint distribution *exactly* — every observation appears once, so the
/// sample moments are the data's moments with no sampling error at all. That is the
/// property it is chosen for, and it is also why it cannot be treated as an independent
/// sampler: the exactness comes precisely from the draws being dependent.
public struct MultivariateShuffle: Sendable {

	/// What can go wrong constructing a multivariate shuffler.
	public typealias Failure = MultivariateResample.Failure

	/// The rows originally supplied, unchanged by drawing.
	public let rows: [[Double]]

	/// How many columns each row has.
	public let dimension: Int

	/// The rows still available, in an order unspecified after the first draw.
	private var remaining: [[Double]]

	/// Creates a shuffler over `rows`.
	///
	/// - Parameter rows: The observations, one per row, all the same length.
	/// - Throws: ``Failure`` naming what was wrong with the data.
	public init(rows: [[Double]]) throws {
		// Delegated so the two types cannot disagree about what valid data is.
		let validated = try MultivariateResample(rows: rows)
		self.rows = validated.rows
		self.dimension = validated.dimension
		self.remaining = validated.rows
	}

	/// How many rows are still available.
	public var remainingCount: Int { remaining.count }

	/// Whether every row has been drawn.
	public var isExhausted: Bool { remaining.isEmpty }

	/// Draws one row without replacement.
	///
	/// - Parameter generator: The random source; seed it for a reproducible order.
	/// - Returns: A row not yet drawn, or `nil` once all are gone. `nil` rather than
	///   starting over, which would turn this into sampling with replacement without
	///   saying so.
	public mutating func next<G: RandomNumberGenerator>(using generator: inout G) -> [Double]? {
		guard !remaining.isEmpty else { return nil }
		let index = Int(generator.next(upperBound: UInt64(remaining.count)))
		// The Fisher–Yates step: swap the choice to the end and drop it, O(1).
		remaining.swapAt(index, remaining.count - 1)
		return remaining.removeLast()
	}

	/// Restores every row, so the dataset can be drawn from again.
	public mutating func reset() {
		remaining = rows
	}

	/// The whole dataset in a uniformly random row order.
	///
	/// Independent of how many rows have already been drawn — it permutes ``rows``,
	/// not what remains.
	///
	/// - Parameter generator: The random source; seed it for a reproducible ordering.
	/// - Returns: A permutation of ``rows``, each ordering equally likely.
	public func permuted<G: RandomNumberGenerator>(using generator: inout G) -> [[Double]] {
		var working = rows
		guard working.count > 1 else { return working }
		for i in stride(from: working.count - 1, to: 0, by: -1) {
			let j = Int(generator.next(upperBound: UInt64(i + 1)))
			working.swapAt(i, j)
		}
		return working
	}
}

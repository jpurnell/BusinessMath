//
//  GainsTable.swift
//  BusinessMath
//

import Foundation
import Numerics

/// One bucket of a gains table, ordered from the highest-scoring downward.
public struct GainsRow<T: Real & Sendable>: Sendable {

	/// Which bucket, counting from one at the top.
	public let bucket: Int

	/// Observations in this bucket.
	public let count: Int

	/// Positives in this bucket.
	public let positives: Int

	/// The share of all positives captured by this bucket and every bucket above it.
	public let cumulativeGain: T

	/// The share of all observations in this bucket and above.
	public let cumulativePopulation: T

	/// ``cumulativeGain`` over ``cumulativePopulation`` — how many times better than
	/// picking at random the model has been so far.
	public let lift: T

	/// Creates a row.
	///
	/// - Parameters:
	///   - bucket: One-based bucket index, highest scores first.
	///   - count: Observations in the bucket.
	///   - positives: Positives in the bucket.
	///   - cumulativeGain: Share of all positives captured to here.
	///   - cumulativePopulation: Share of all observations to here.
	///   - lift: Gain over population.
	public init(bucket: Int, count: Int, positives: Int,
				cumulativeGain: T, cumulativePopulation: T, lift: T) {
		self.bucket = bucket
		self.count = count
		self.positives = positives
		self.cumulativeGain = cumulativeGain
		self.cumulativePopulation = cumulativePopulation
		self.lift = lift
	}
}

/// A gains table: what fraction of the positives the top scores account for.
///
/// The question a marketing or credit team actually asks — *"if we contact the top
/// decile, how many of the responders do we get?"* — which is a statement about the
/// ranking rather than about any threshold.
public struct GainsTable<T: Real & Sendable>: Sendable {

	/// The buckets, highest scores first.
	public let rows: [GainsRow<T>]

	/// Creates a table.
	///
	/// - Parameter rows: The buckets, highest scores first.
	public init(rows: [GainsRow<T>]) {
		self.rows = rows
	}
}

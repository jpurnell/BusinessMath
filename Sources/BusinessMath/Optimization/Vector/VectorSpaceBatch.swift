//
//  VectorSpaceBatch.swift
//  BusinessMath
//

import Foundation
import Numerics

public extension VectorSpace {

	/// Rebuilds a batch of vectors from a flat, row-major buffer of scalars.
	///
	/// ```swift
	/// let flat: [Double] = [1, 2, 3, 4, 5, 6]
	/// let batch = Vector2D<Double>.vectors(fromFlat: flat, count: 3, dimension: 2)
	/// print(batch?.count ?? 0)
	/// ```
	///
	/// ## Why this exists rather than a loop at each call site
	///
	/// The GPU paths in `DifferentialEvolution` and `ParticleSwarmOptimization` read results
	/// back out of a Metal buffer one vector at a time, and both wrote the loop the obvious
	/// way:
	///
	/// ```
	/// if let vector = V.fromArray(components) { population.append(vector) }
	/// ```
	///
	/// A conversion that fails appends nothing, so the batch comes back **shorter than the
	/// population it describes** — and the caller then writes `newPopulation[i] =
	/// trialPopulation[i]` across `0..<populationSize`. That is an out-of-range crash rather
	/// than a wrong answer, and nothing before it says anything is amiss.
	///
	/// **A batch conversion returns every element or none. Never a prefix.** `nil` here means
	/// the buffer could not be read as `count` vectors, which for both optimizers means fall
	/// back to the CPU — the same thing they already do when Metal is unavailable.
	///
	/// `nil` rather than an empty array on a degenerate request, deliberately: an empty batch
	/// reads as "nothing to convert" and would be indexed by the caller just the same.
	///
	/// - Parameters:
	///   - scalars: The flat buffer, row-major — vector `i`'s component `d` at
	///     `i * dimension + d`. Must hold at least `count * dimension` elements.
	///   - count: How many vectors to read. Must be positive.
	///   - dimension: How many scalars each vector holds. Must be positive, and must be a
	///     width this type accepts — `Vector2D` takes two and refuses anything else.
	/// - Returns: Exactly `count` vectors, or `nil` if the request is degenerate, the buffer
	///   is too short, or **any** element fails to convert.
	static func vectors(fromFlat scalars: [Scalar], count: Int, dimension: Int) -> [Self]? {
		guard count > 0, dimension > 0 else { return nil }
		let needed = count * dimension
		guard scalars.count >= needed else { return nil }

		var batch = [Self]()
		batch.reserveCapacity(count)
		for index in 0..<count {
			let start = index * dimension
			let end = start + dimension
			let components = Array(scalars[start..<end])
			// The guard, rather than an `if let` that appends: a failure here means the
			// whole batch is unreadable, and a short batch is what crashes the caller.
			guard let vector = Self.fromArray(components) else { return nil }
			batch.append(vector)
		}
		guard batch.count == count else { return nil }
		return batch
	}
}

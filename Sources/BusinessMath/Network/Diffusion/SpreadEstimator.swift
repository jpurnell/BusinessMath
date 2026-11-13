//
//  SpreadEstimator.swift
//  BusinessMath
//

import Foundation

/// An estimated expected spread and how uncertain the estimate is.
///
/// The standard error measures only **Monte Carlo noise** — how much the mean would move
/// if the same model were simulated again with fresh random numbers. It says nothing about
/// whether the *model* is right. A tiny standard error on a model with a guessed
/// probability is a precise answer to a question nobody asked.
///
/// ```swift
/// import BusinessMath
///
/// let estimate = SpreadEstimate(mean: 6.0, standardError: 0.05, trials: 1000)
/// print(estimate.mean)   // 6.0
/// ```
public struct SpreadEstimate: Sendable, Hashable, Codable {
	/// The mean number of activated nodes over all trials, seeds included.
	public let mean: Double
	/// The standard error of ``mean``: sample standard deviation over √trials. Zero when
	/// there was a single trial or every trial agreed.
	public let standardError: Double
	/// How many trials produced it.
	public let trials: Int

	/// Creates an estimate.
	public init(mean: Double, standardError: Double, trials: Int) {
		self.mean = mean
		self.standardError = standardError
		self.trials = trials
	}
}

/// Estimates the expected spread of a seed set by Monte Carlo.
///
/// ## Determinism
///
/// Trial `t` draws its randomness from ``TrialRandomness`` keyed by `(seed, t)`, never from
/// a shared generator, and the per-trial counts are integers summed exactly. The same
/// `(graph, model, seeds, trials, seed)` therefore gives a bit-identical result however
/// threads are scheduled, and the same trials are reused for every seed set — so two seed
/// sets evaluated with one estimator are compared on common random numbers.
///
/// ```swift
/// import BusinessMath
///
/// let path = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
/// let estimator = try SpreadEstimator(trials: 100, seed: 7)
/// let estimate = estimator.estimate(
///     model: try IndependentCascade(probability: 1), on: path, seeds: [0])
/// print(estimate.mean)            // 3.0
/// print(estimate.standardError)   // 0.0
/// ```
public struct SpreadEstimator: Sendable, Equatable {

	/// How many trials each estimate averages.
	public let trials: Int

	/// The master seed every trial's randomness is derived from.
	public let seed: UInt64

	/// Creates an estimator.
	///
	/// - Parameters:
	///   - trials: At least one.
	///   - seed: The master seed.
	/// - Throws: ``DiffusionError/invalidTrialCount(_:)`` if `trials < 1`.
	public init(trials: Int, seed: UInt64) throws {
		guard trials >= 1 else { throw DiffusionError.invalidTrialCount(trials) }
		self.trials = trials
		self.seed = seed
	}

	/// Estimates the expected spread of a seed set.
	///
	/// - Parameters:
	///   - model: The diffusion model.
	///   - graph: The graph.
	///   - seeds: Node indices that start active. Out-of-range indices are ignored and
	///     duplicates count once.
	public func estimate<Node: Hashable & Comparable & Sendable>(
		model: some DiffusionModel, on graph: WeightedGraph<Node>, seeds: [Int]
	) -> SpreadEstimate {
		estimate(model: model, on: DiffusionGraph(graph), seeds: seeds)
	}

	/// Estimates the expected spread on an already-flattened graph.
	public func estimate(
		model: some DiffusionModel, on graph: DiffusionGraph, seeds: [Int]
	) -> SpreadEstimate {
		var sum = 0
		var sumOfSquares = 0
		for trial in 0..<trials {
			let count = model.simulate(
				on: graph, seeds: seeds,
				randomness: TrialRandomness(masterSeed: seed, trial: trial))
			sum += count
			sumOfSquares += count * count
		}
		return Self.summarise(sum: sum, sumOfSquares: sumOfSquares, trials: trials)
	}

	/// Mean and standard error from exact integer sums.
	static func summarise(sum: Int, sumOfSquares: Int, trials: Int) -> SpreadEstimate {
		guard trials > 0 else { return SpreadEstimate(mean: 0, standardError: 0, trials: 0) }
		let n = Double(trials)
		let mean = Double(sum) / n
		guard trials > 1 else { return SpreadEstimate(mean: mean, standardError: 0, trials: trials) }
		// Sample variance from integer sums, computed as (n·Σx² − (Σx)²) / (n·(n−1)) so the
		// numerator is exact and cannot go negative from cancellation.
		let numerator = Double(trials * sumOfSquares - sum * sum)
		// Never NaN: the single-trial case returned above, so n·(n−1) is at least 2. The sign is
		// tested rather than clamped with `max(0, _)`, whose answer for a NaN argument is an
		// accident of argument order that this code must not lean on.
		let variance = numerator > 0 ? numerator / (n * (n - 1)) : 0
		return SpreadEstimate(mean: mean, standardError: (variance / n).squareRoot(), trials: trials)
	}
}

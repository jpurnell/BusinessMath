//
//  DiffusionOracleTests.swift
//  BusinessMath
//
//  Per-trial exact oracles and closed-form checks for both cascade models. Ported from
//  SwiftGraphMetrics's DiffusionTests (mutation-audit additions, 2026-11-11).
//
//  A trial's random draws are a pure function of (seed, trial, edge or node), so the outcome
//  of one trial is recomputed by a different algorithm (reachability over the edges that
//  fired; a threshold fixed point) and compared exactly, with no statistical tolerance.
//

import Foundation
import SwiftDeterminism
import Testing
import TestSupport

@testable import BusinessMath

private typealias F = DiffusionFixtures

@Suite("Diffusion: per-trial oracles")
struct DiffusionOracleTests {

	@Test("Independent cascade equals reachability over the fired edges, trial by trial", .timeLimit(.minutes(1)),
		  arguments: F.oracleSeeds)
	func cascadeMatchesReachability(seed: UInt64) throws {
		let graph = try F.randomWeightedGraph(nodes: 14, edgeProbability: 0.2, seed: seed, weighted: seed % 2 == 0)
		let flat = DiffusionGraph(graph)
		var rng = SplitMix64(seed: seed &+ 500)
		let rules: [F.CascadeRule] = [.fixed(0.2), .fixed(0.6), .scaled(0.9), .scaled(0.4)]
		for rule in rules {
			let model: IndependentCascade
			switch rule {
			case .fixed(let p): model = try IndependentCascade(probability: p)
			case .scaled(let b): model = try IndependentCascade(weightScaledProbability: b)
			}
			for trial in 0..<30 {
				// Seed sets include duplicates and out-of-range indices on purpose.
				let seeds = (0..<Int.random(in: 0...4, using: &rng)).map { _ in
					Int.random(in: -2...16, using: &rng)
				}
				let got = model.simulate(
					on: flat, seeds: seeds, randomness: TrialRandomness(masterSeed: seed, trial: trial))
				let want = F.cascadeOracle(graph, rule, seeds: seeds, masterSeed: seed, trial: trial)
				#expect(got == want, "seed \(seed) \(rule) trial \(trial) seeds \(seeds)")
			}
		}
	}

	@Test("Linear threshold equals the threshold fixed point, trial by trial", .timeLimit(.minutes(1)),
		  arguments: F.oracleSeeds)
	func thresholdMatchesFixedPoint(seed: UInt64) throws {
		let graph = try F.randomWeightedGraph(nodes: 14, edgeProbability: 0.25, seed: seed, weighted: seed % 2 == 1)
		let flat = DiffusionGraph(graph)
		var rng = SplitMix64(seed: seed &+ 900)
		for trial in 0..<60 {
			let seeds = (0..<Int.random(in: 1...5, using: &rng)).map { _ in
				Int.random(in: -1...15, using: &rng)
			}
			let got = LinearThreshold().simulate(
				on: flat, seeds: seeds, randomness: TrialRandomness(masterSeed: seed, trial: trial))
			let want = F.thresholdOracle(graph, seeds: seeds, masterSeed: seed, trial: trial)
			#expect(got == want, "seed \(seed) trial \(trial) seeds \(seeds)")
		}
	}

	/// A threshold that lands just above a share must be missed, so the tolerance in the
	/// model must be far smaller than 1e-3: 40,000 thresholds on a share of 1/2 put roughly
	/// 40 of them in (0.5, 0.501].
	@Test("The threshold comparison tolerance is rounding-sized, not visible", .timeLimit(.minutes(1)))
	func thresholdToleranceIsTiny() {
		let graph = WeightedGraph(unweightedEdges: [(0, 2), (1, 2)])
		let flat = DiffusionGraph(graph)
		var matched = 0
		for trial in 0..<40_000 {
			let randomness = TrialRandomness(masterSeed: 31, trial: trial)
			let got = LinearThreshold().simulate(on: flat, seeds: [0], randomness: randomness)
			let want = F.thresholdOracle(graph, seeds: [0], masterSeed: 31, trial: trial)
			if got == want { matched += 1 }
		}
		#expect(matched == 40_000)
	}

	@Test("Spread is monotone in the seed set and in the probability, exactly, on common trials", .timeLimit(.minutes(1)),
		  arguments: F.oracleSeeds)
	func monotonicity(seed: UInt64) throws {
		let graph = try F.randomWeightedGraph(nodes: 16, edgeProbability: 0.15, seed: seed, weighted: true)
		let estimator = try SpreadEstimator(trials: 120, seed: seed)
		var rng = SplitMix64(seed: seed &+ 7)
		let small = (0..<2).map { _ in Int.random(in: 0..<16, using: &rng) }
		let large = small + (0..<3).map { _ in Int.random(in: 0..<16, using: &rng) }
		var previousByProbability: Double = -1
		for p in [0.0, 0.1, 0.3, 0.6, 1.0] {
			let model = try IndependentCascade(probability: p)
			let a = estimator.estimate(model: model, on: graph, seeds: small)
			let b = estimator.estimate(model: model, on: graph, seeds: large)
			// Same draws, so a superset of seeds reaches a superset of nodes on every trial.
			#expect(b.mean >= a.mean - 1e-12, "seeds, p \(p)")
			// More probability fires a superset of edges on every trial.
			#expect(b.mean >= previousByProbability - 1e-12, "probability \(p)")
			previousByProbability = b.mean
			// Bounded by the node count, and by at least the distinct valid seeds.
			#expect(b.mean <= Double(graph.nodeCount) + 1e-12)
			#expect(b.mean >= Double(Set(large).count) - 1e-12)
		}
		let scaled = try IndependentCascade(weightScaledProbability: 0.5)
		let scaledMore = try IndependentCascade(weightScaledProbability: 0.8)
		#expect(estimator.estimate(model: scaledMore, on: graph, seeds: large).mean
			>= estimator.estimate(model: scaled, on: graph, seeds: large).mean - 1e-12)
		let lt = LinearThreshold()
		#expect(estimator.estimate(model: lt, on: graph, seeds: large).mean
			>= estimator.estimate(model: lt, on: graph, seeds: small).mean - 1e-12)
	}
}

@Suite("Diffusion: closed forms with theoretical tolerances")
struct DiffusionClosedFormTests {

	/// Star, centre seeded, uniform p: spread = 1 + Binomial(n, p). Mean 1 + np, variance
	/// np(1-p), so the standard error of N trials is sqrt(np(1-p)/N). Four standard errors
	/// from theory is a one-in-16,000 miss for any fixed (seed, N); seeds are fixed, so the
	/// outcome is reproducible rather than merely unlikely to fail.
	@Test("Star centre: mean is 1 + n p within 4 theoretical SE, and the reported SE matches theory", .timeLimit(.minutes(1)),
		  arguments: [(8, 0.25), (12, 0.5), (20, 0.9)] as [(Int, Double)])
	func starBinomial(leaves: Int, p: Double) throws {
		let trials = 3000
		let g = F.star(leaves: leaves)
		let e = try F.estimate(try IndependentCascade(probability: p), g, seeds: ["c"], trials: trials, seed: 12)
		let theorySE: Double = (Double(leaves) * p * (1 - p) / Double(trials)).squareRoot()
		let expectedMean: Double = 1 + Double(leaves) * p
		let meanGap: Double = abs(e.mean - expectedMean)
		#expect(meanGap <= 4 * theorySE)
		// The sample sd of N draws has relative standard error sqrt((kurtosis - 1) / (4N)); a
		// Binomial(n, p) has excess kurtosis (1 - 6pq) / (npq), so kurtosis - 1 = 2 + that.
		let q = 1 - p
		let excess: Double = (1 - 6 * p * q) / (Double(leaves) * p * q)
		let relativeSD: Double = ((2 + excess) / (4 * Double(trials))).squareRoot()
		let seGap: Double = abs(e.standardError - theorySE)
		let seBound: Double = 4 * theorySE * relativeSD
		#expect(seGap <= seBound)
		#expect(e.trials == trials)
	}

	/// Path seeded at one end with uniform p: node k is reached iff the first k edges all
	/// fire, probability p^k, so the expected spread is 1 + p + p^2 + ... + p^(n-1). The
	/// count is a sum of dependent indicators, so its variance is bounded by n^2/4 here;
	/// the tolerance uses that bound (a conservative standard error), not the sample's own.
	@Test("Path from an end: mean is the geometric sum")
	func pathGeometric() throws {
		let n = 7
		let p = 0.6
		let trials = 4000
		let g = F.path(n)
		let e = try F.estimate(try IndependentCascade(probability: p), g, seeds: ["p0"], trials: trials, seed: 3)
		let expected = (0..<n).reduce(0.0) { $0 + pow(p, Double($1)) }
		// The spread is the first failed edge, a truncated geometric: variance <= (n-1)^2/4.
		let conservativeSE: Double = Double(n - 1) / 2 / Double(trials).squareRoot()
		#expect(abs(e.mean - expected) <= 4 * conservativeSE)
		// Tighter, from the exact variance of the truncated geometric count.
		var m1 = 0.0, m2 = 0.0
		for k in 1...n {
			let probability: Double = k < n ? pow(p, Double(k - 1)) * (1 - p) : pow(p, Double(n - 1))
			m1 += Double(k) * probability
			m2 += Double(k * k) * probability
		}
		#expect(abs(m1 - expected) < 1e-12)
		let exactSE: Double = (m2 - m1 * m1).squareRoot() / Double(trials).squareRoot()
		#expect(abs(e.mean - expected) <= 4 * exactSE)
		// Relative standard error of the sample sd: sqrt((mu4 / sigma^4 - 1) / (4N)).
		var mu4 = 0.0
		for k in 1...n {
			let probability: Double = k < n ? pow(p, Double(k - 1)) * (1 - p) : pow(p, Double(n - 1))
			mu4 += probability * pow(Double(k) - m1, 4)
		}
		let variance = m2 - m1 * m1
		let relativeSD: Double = ((mu4 / (variance * variance) - 1) / (4 * Double(trials))).squareRoot()
		let seGap: Double = abs(e.standardError - exactSE)
		let seBound: Double = 4 * exactSE * relativeSD
		#expect(seGap <= seBound)
	}

	/// Path of six nodes, seeded at one end, linear threshold. An interior node has two
	/// neighbours of equal weight, so with one active its share is 1/2 and it activates iff
	/// its own threshold is <= 1/2 (probability 1/2, independent of the others); the last
	/// node has a single neighbour, share 1, and follows its neighbour. The spread is
	/// therefore 1 (p0) plus a run of heads: P(count = 1, 2, 3, 4, 6) = 1/2, 1/4, 1/8, 1/16, 1/16
	/// (p1..p4 each activate with probability 1/2 given the one before; p5 follows p4).
	/// Mean 2, variance 5.875 - 4 = 1.875.
	@Test("Path from an end under linear threshold: mean 2 with variance 1.875")
	func thresholdPath() throws {
		let trials = 6000
		let e = try F.estimate(LinearThreshold(), F.path(6), seeds: ["p0"], trials: trials, seed: 15)
		let theorySE = (1.875 / Double(trials)).squareRoot()
		#expect(abs(e.mean - 2.0) <= 4.5 * theorySE, "mean \(e.mean)")
		// The sample standard deviation has standard error sqrt((mu4 - sigma^4) / N) / (2 sigma),
		// with mu4 the fourth central moment of the exact distribution.
		let counts: [(Double, Double)] = [(1, 1.0 / 2), (2, 1.0 / 4), (3, 1.0 / 8), (4, 1.0 / 16), (6, 1.0 / 16)]
		let mu4 = counts.reduce(0.0) { $0 + $1.1 * pow($1.0 - 2.0, 4) }
		let sigma = 1.875.squareRoot()
		let seOfSD: Double = ((mu4 - 1.875 * 1.875) / Double(trials)).squareRoot() / (2 * sigma)
		let sdObserved = e.standardError * Double(trials).squareRoot()
		#expect(abs(sdObserved - sigma) <= 4.5 * seOfSD, "sd \(sdObserved) vs \(sigma)")
	}

	/// `a` and `b` are each other's only contact: once either is active the other has share 1
	/// and always follows, so spreading from one end of a single edge is exactly 2, every trial.
	@Test("A lone edge under linear threshold always spreads to both ends, with zero variance")
	func thresholdLoneEdge() throws {
		let g = WeightedGraph(unweightedEdges: [("a", "b")], isolatedNodes: ["z"])
		let e = try F.estimate(LinearThreshold(), g, seeds: ["a"], trials: 500, seed: 6)
		#expect(F.near(e.mean, 2.0))
		#expect(F.near(e.standardError, 0.0))
	}

	/// Two seeded neighbours of weight 1 and one of weight 3 around v: shares 1/5, 1/5, 3/5.
	/// With only the heavy one active, v activates iff theta <= 3/5. Expected spread of
	/// seeding just that neighbour on this star-of-three: 1 + 3/5.
	@Test("Threshold share is weight over weighted degree, not over neighbour count")
	func thresholdShare() throws {
		let g = try WeightedGraph(edges: [("h", "v", 3.0), ("a", "v", 1.0), ("b", "v", 1.0)])
		let trials = 6000
		// Seeding h: v active iff theta_v <= 0.6; a and b then each have the single neighbour
		// v (share 1), so they follow v. Spread = 1 + 1[v] * 3.
		let e = try F.estimate(LinearThreshold(), g, seeds: ["h"], trials: trials, seed: 4)
		let theorySE: Double = (9 * 0.6 * 0.4 / Double(trials)).squareRoot()
		let expectedMean: Double = 1 + 3 * 0.6
		let meanGap: Double = abs(e.mean - expectedMean)
		#expect(meanGap <= 4 * theorySE, "mean \(e.mean)")
	}
}

//
//  GoldenSGMTypes.swift
//  BusinessMath
//
//  Row types for the seed-for-seed golden values in GoldenSGMValues.swift.
//
//  Those values were computed by SwiftGraphMetrics (main) on 2026-11-12, before the diffusion
//  and siting code was ported, by the scratch script kept beside the mutation record in
//  project/summaries/2026-11-12_network_diffusion_siting_core/. They are the reproducibility
//  contract: a stored seed selection depends on every one of them.
//

import Foundation

/// An undirected weighted edge between node indices.
struct GoldenEdge: Sendable {
	let from: Int
	let to: Int
	let weight: Double

	init(_ from: Int, _ to: Int, _ weight: Double) {
		self.from = from
		self.to = to
		self.weight = weight
	}
}

/// One `TrialRandomness.uniform(forNode:)` draw, as bits.
struct GoldenNodeDraw: Sendable {
	let seed: UInt64
	let trial: Int
	let node: Int
	let bits: UInt64
}

/// One `TrialRandomness.uniform(from:to:)` draw, as bits.
struct GoldenEdgeDraw: Sendable {
	let seed: UInt64
	let trial: Int
	let from: Int
	let to: Int
	let bits: UInt64
}

/// One simulated trial: its count and the exact set of active node indices.
struct GoldenTrial: Sendable {
	let graph: String
	let model: String
	let seeds: [Int]
	let masterSeed: UInt64
	let trial: Int
	let count: Int
	let activated: [Int]
}

/// One `SpreadEstimate`, as bits.
struct GoldenEstimate: Sendable {
	let graph: String
	let model: String
	let seeds: [Int]
	let masterSeed: UInt64
	let trials: Int
	let meanBits: UInt64
	let standardErrorBits: UInt64
}

/// One `simulate(on:seeds:using:)` count, keyed by an `Xoshiro256StarStar` seed.
struct GoldenGeneratorCount: Sendable {
	let graph: String
	let model: String
	let seeds: [Int]
	let generatorSeed: UInt64
	let count: Int
}

/// A p-median instance: demand weights and the demand-by-site cost table, as bits.
struct GoldenSiteInstance: Sendable {
	let name: String
	let weightBits: [UInt64]
	let costBits: [[UInt64]]
}

/// What the original package answered for one instance, count and enumeration limit.
struct GoldenSiteResult: Sendable {
	let instance: String
	let count: Int
	let enumerationLimit: Int
	let chosen: [Int]
	let isExact: Bool
	let totalBits: UInt64
	let meanBits: UInt64
	let assignedSites: [Int]
	let loadSites: [Int]
	let loadBits: [UInt64]
}

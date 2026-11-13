//
//  GoldenSeedTypes.swift
//  BusinessMath
//
//  Row types for the seed-for-seed golden values in GoldenSeedValues.swift.
//
//  Those values were computed by SwiftGraphMetrics (main) on 2026-11-12, before SeedSelector
//  and the stored-record shapes were ported, by the scratch script kept beside the mutation
//  record in project/summaries/2026-11-12_network_diffusion_part2/. They are the
//  reproducibility contract: a stored seed selection depends on every one of them.
//

import Foundation

/// One `SeedSelector.compute` answer: the picks in order, their gains, and the spread of the set.
struct GoldenSelection: Sendable {
	let graph: String
	let model: String
	let budget: Int
	let trials: Int
	let seed: UInt64
	/// Each chosen node, as `String(describing:)`.
	let nodes: [String]
	let gainBits: [UInt64]
	let totalGainBits: UInt64
	/// `SpreadEstimator(trials:seed:)` on the chosen set, same model.
	let spreadMeanBits: UInt64
	let spreadStandardErrorBits: UInt64
	/// `NodeSelection`, `JSONEncoder` with sorted keys.
	let json: String
	/// `MetricEnvelope(selection)`, same encoder.
	let envelopeJSON: String
}

/// One point of a recorded sweep.
struct GoldenSweepPoint: Sendable {
	let probabilityBits: UInt64
	let nodes: [Int]
	let gainBits: [UInt64]
}

/// One `SeedSweep`: the points, the derived summary, and the stored forms.
struct GoldenSweep: Sendable {
	let name: String
	let graph: String
	/// `"ic"`, `"icw"` (weight-scaled cascade), `"lt"` (a builder that ignores the probability) or
	/// `"points"` (built directly from the points, no selector).
	let builder: String
	let budget: Int
	let trials: Int
	let seed: UInt64
	let points: [GoldenSweepPoint]
	/// The nodes of `topKFrequency`, ascending, and the matching frequencies.
	let frequencyNodes: [Int]
	let frequencyBits: [UInt64]
	let jaccardBits: [[UInt64]]
	let meanJaccardBits: UInt64
	let alwaysPicked: [Int]
	/// `SeedSweep`, `JSONEncoder` with sorted keys.
	let json: String
	/// `MetricEnvelope(sweep)`, same encoder.
	let envelopeJSON: String
}

/// One `SiteAssignment` for a p-median instance of the part 1 goldens, as stored.
struct GoldenSiteJSON: Sendable {
	let instance: String
	let count: Int
	let enumerationLimit: Int
	let json: String
	let envelopeJSON: String
}

/// One answer of a siting problem whose demand came from `NodeScores`.
struct GoldenScoreSiting: Sendable {
	let name: String
	let demandKeys: [Int]
	let demandBits: [UInt64]
	let sites: [Int]
	let count: Int
	let chosen: [Int]
	let totalWeightBits: UInt64
	let totalCostBits: UInt64
	let meanCostBits: UInt64
	let json: String
}

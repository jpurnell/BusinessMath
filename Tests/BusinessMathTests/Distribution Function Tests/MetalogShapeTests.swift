//
//  MetalogShapeTests.swift
//  BusinessMath
//
//  PsiMetalog2's shape reporting: modes, anti-modes, and the feasibility query.
//
//  Two oracles, neither of which can agree with the code by construction.
//
//  The first is the analytic slope against a central difference of `quantile`. The two
//  share no code — one differentiates the basis term by term and chains through the
//  boundedness transform, the other only evaluates the public quantile twice — so if
//  a single term of `basisDerivative` is wrong, or the transform's derivative is
//  omitted or paired with the wrong transform, they part company. It is run across all
//  four boundedness cases for exactly that reason.
//
//  The second is symmetry. A metalog fitted to percentile data that is symmetric about
//  a point has a density symmetric about it, so its single mode must sit at the median
//  — a location known in advance, from the data rather than from the search.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Metalog shape")
struct MetalogShapeTests {

	// MARK: - The slope, against a derivative that shares no code with it

	@Test("The analytic quantile slope matches a central difference in every boundedness")
	func slopeAgainstFiniteDifference() throws {
		let probabilities: [Double] = [0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9]
		let values: [Double] = [-1.28, -0.67, -0.25, 0.0, 0.25, 0.67, 1.28]
		let positive: [Double] = values.map { $0 + 5 }
		let insideUnit: [Double] = values.map { value -> Double in
			let shifted: Double = value / 8
			return shifted + 0.5
		}

		let cases: [(name: String, distribution: DistributionMetalog)] = [
			("unbounded", try DistributionMetalog(fittingProbabilities: probabilities,
												  values: values, terms: 5)),
			("boundedBelow", try DistributionMetalog(fittingProbabilities: probabilities,
													 values: positive, terms: 5,
													 boundedness: .boundedBelow(lower: 0))),
			("boundedAbove", try DistributionMetalog(fittingProbabilities: probabilities,
													 values: values, terms: 5,
													 boundedness: .boundedAbove(upper: 3))),
			("bounded", try DistributionMetalog(fittingProbabilities: probabilities,
												 values: insideUnit, terms: 5,
												 boundedness: .bounded(lower: 0, upper: 1))),
		]

		var compared = 0
		for row in cases {
			for p in [0.1, 0.2, 0.35, 0.5, 0.65, 0.8, 0.9] {
				let analytic = try #require(row.distribution.quantileSlope(at: p),
											"\(row.name): no slope at p=\(p)")
				let h: Double = 1e-6
				let ahead: Double = row.distribution.quantile(p + h)
				let behind: Double = row.distribution.quantile(p - h)
				let gap: Double = ahead - behind
				let numeric: Double = gap / (2 * h)
				let scale: Double = Swift.max(Swift.abs(numeric), 1e-6)
				let error: Double = Swift.abs(analytic - numeric)
				#expect(error < scale * 1e-5,
						"\(row.name) at p=\(p): analytic \(analytic), difference \(numeric)")
				compared += 1
			}
		}
		#expect(compared == 28, "only \(compared) of 28 slope comparisons ran")
	}

	@Test("The density is the reciprocal of the slope and is strictly positive")
	func densityIsReciprocalOfSlope() throws {
		let d = try DistributionMetalog(fittingProbabilities: [0.1, 0.5, 0.9],
										values: [-1.28, 0.0, 1.28])
		var checked = 0
		for p in [0.05, 0.25, 0.5, 0.75, 0.95] {
			let slope = try #require(d.quantileSlope(at: p))
			let density = try #require(d.density(atProbability: p))
			let product: Double = slope * density
			#expect(Swift.abs(product - 1) < 1e-12, "slope × density is \(product) at p=\(p)")
			#expect(density > 0, "density \(density) at p=\(p)")
			checked += 1
		}
		#expect(checked == 5, "only \(checked) probabilities were checked")
		#expect(d.quantileSlope(at: 0) == nil)
		#expect(d.quantileSlope(at: 1) == nil)
		#expect(d.density(atProbability: 1.5) == nil)
	}

	// MARK: - Modes, against a location known from the data

	@Test("A symmetric metalog has one mode, and it sits at the median")
	func symmetricMetalogHasOneCentredMode() throws {
		var checked = 0
		for centre in [0.0, 12.5, -40.0] {
			let probabilities: [Double] = [0.1, 0.25, 0.5, 0.75, 0.9]
			let offsets: [Double] = [-1.2816, -0.6745, 0, 0.6745, 1.2816]
			let values: [Double] = offsets.map { $0 + centre }
			let d = try DistributionMetalog(fittingProbabilities: probabilities,
											values: values, terms: 5)
			let modes = d.modes()
			#expect(modes.count == 1, "centre \(centre) gave \(modes.count) modes: \(modes)")
			if let mode = modes.first {
				#expect(Swift.abs(mode - centre) < 1e-4,
						"the mode is at \(mode), not the median \(centre)")
			}
			#expect(d.antiModes().isEmpty, "a unimodal density reported an anti-mode")
			checked += 1
		}
		#expect(checked == 3, "only \(checked) centres were checked")
	}

	@Test("The reported mode really is where the density peaks")
	func modeIsTheDensityPeak() throws {
		// Independent of how the mode was found: whatever probability it corresponds
		// to, the density there must beat the density on both sides of it.
		let d = try DistributionMetalog(fittingProbabilities: [0.1, 0.25, 0.5, 0.75, 0.9],
										values: [-2.1, -0.8, 0.2, 1.1, 2.6], terms: 5)
		let modes = d.modes()
		#expect(!modes.isEmpty, "no mode was found for a five-term fit")
		var checked = 0
		for mode in modes {
			let p: Double = d.cdf(mode)
			guard p > 0.02, p < 0.98 else { continue }
			let peak = try #require(d.density(atProbability: p))
			for delta in [0.01, 0.02] {
				let below = try #require(d.density(atProbability: p - delta))
				let above = try #require(d.density(atProbability: p + delta))
				#expect(peak >= below, "density at the mode \(peak) is below \(below)")
				#expect(peak >= above, "density at the mode \(peak) is below \(above)")
			}
			checked += 1
		}
		#expect(checked >= 1, "no mode was interior enough to check")
	}

	// MARK: - Anti-modes

	@Test("Every turning point is one an independent grid scan also finds")
	func turningPointsAgreeWithAGridScan() throws {
		// Percentiles of an even mixture of two normals, fitted with ten terms.
		//
		// The fit is *quadrimodal*, not bimodal, and that is the point of the test
		// rather than a flaw in it. A ten-term metalog forced through nineteen
		// percentiles of a two-humped target does not draw two smooth humps; it
		// oscillates between the points it was given, and the result carries four
		// peaks and three dips. A fit that looks entirely reasonable read off its
		// percentiles is hiding structure nobody elicited, which is exactly the thing
		// `PsiMetalog2` reports modes for.
		//
		// So the oracle is not a count decided in advance. It is a second, independent
		// search: walk the density on a uniform grid and compare neighbours. That
		// shares no code with `modes()` — no analytic derivative, no golden section,
		// no end refinement — so agreement between them is evidence.
		let points = 19
		let probabilities: [Double] = (1...points).map { Double($0) / Double(points + 1) }
		let values: [Double] = probabilities.map { Self.mixtureQuantile($0) }
		let d = try DistributionMetalog(fittingProbabilities: probabilities,
										values: values, terms: 10)

		let scan = Self.scanForTurningPoints(d, steps: 4_000)
		let modes = d.modes()
		let antiModes = d.antiModes()

		#expect(modes.count == scan.peaks.count,
				"analytic found \(modes.count) modes, the grid found \(scan.peaks.count)")
		#expect(antiModes.count == scan.dips.count,
				"analytic found \(antiModes.count) anti-modes, the grid found \(scan.dips.count)")
		#expect(modes.count == 4, "this fit has four modes, not \(modes.count): \(modes)")
		#expect(antiModes.count == 3, "this fit has three anti-modes, not \(antiModes.count)")

		var matched = 0
		for (analytic, gridded) in zip(modes, scan.peaks) {
			// The grid resolves to about a thousandth; the refinement is far finer, so
			// the comparison is against the grid's resolution, not the solver's.
			#expect(Swift.abs(analytic - gridded) < 0.01,
					"mode at \(analytic) versus grid \(gridded)")
			matched += 1
		}
		for (analytic, gridded) in zip(antiModes, scan.dips) {
			#expect(Swift.abs(analytic - gridded) < 0.01,
					"anti-mode at \(analytic) versus grid \(gridded)")
			matched += 1
		}
		#expect(matched == 7, "only \(matched) of 7 turning points were compared")

		// They must alternate: a dip between each neighbouring pair of peaks.
		for index in 0..<antiModes.count {
			#expect(antiModes[index] > modes[index],
					"anti-mode \(antiModes[index]) is not above mode \(modes[index])")
			#expect(antiModes[index] < modes[index + 1],
					"anti-mode \(antiModes[index]) is not below mode \(modes[index + 1])")
		}
	}

	@Test("A symmetric target gives turning points symmetric about the centre")
	func turningPointsAreSymmetric() throws {
		// The mixture is symmetric about zero, so whatever structure the fit invents
		// must be too. This catches a one-sided error in the end refinement that a
		// count would not.
		let points = 19
		let probabilities: [Double] = (1...points).map { Double($0) / Double(points + 1) }
		let values: [Double] = probabilities.map { Self.mixtureQuantile($0) }
		let d = try DistributionMetalog(fittingProbabilities: probabilities,
										values: values, terms: 10)
		let modes = d.modes()
		try #require(modes.count == 4, "expected four modes, got \(modes.count)")
		let outer: Double = modes[0] + modes[3]
		let inner: Double = modes[1] + modes[2]
		#expect(Swift.abs(outer) < 1e-3, "the outer modes are not mirrored: \(modes[0]), \(modes[3])")
		#expect(Swift.abs(inner) < 1e-3, "the inner modes are not mirrored: \(modes[1]), \(modes[2])")
		let centre = d.antiModes()[1]
		#expect(Swift.abs(centre) < 1e-3, "the central anti-mode is at \(centre), not zero")
	}

	@Test("An anti-mode never appears without two modes around it")
	func antiModesRequireTwoModes() throws {
		var checked = 0
		let fits: [(probabilities: [Double], values: [Double], terms: Int)] = [
			([0.1, 0.5, 0.9], [-1.28, 0, 1.28], 3),
			([0.1, 0.25, 0.5, 0.75, 0.9], [-2.1, -0.8, 0.2, 1.1, 2.6], 5),
			([0.1, 0.25, 0.5, 0.75, 0.9], [1.0, 2.0, 4.0, 8.0, 16.0], 4),
		]
		for fit in fits {
			let d = try DistributionMetalog(fittingProbabilities: fit.probabilities,
											values: fit.values, terms: fit.terms)
			let modes = d.modes()
			let antiModes = d.antiModes()
			if !antiModes.isEmpty {
				#expect(modes.count >= 2,
						"\(antiModes.count) anti-modes reported with only \(modes.count) modes")
			}
			#expect(antiModes.count <= Swift.max(0, modes.count - 1),
					"\(antiModes.count) anti-modes cannot separate \(modes.count) modes")
			checked += 1
		}
		#expect(checked == 3, "only \(checked) fits were checked")
	}

	// MARK: - Feasibility, asked rather than caught

	@Test("Feasibility can be queried without building the distribution")
	func feasibilityQuery() throws {
		// A logistic: a1 = 0, a2 = 1. Increasing, so feasible.
		#expect(DistributionMetalog.describesADistribution(coefficients: [0, 1]))
		// The same with a negative scale runs backwards, so there is no distribution.
		#expect(DistributionMetalog.describesADistribution(coefficients: [0, -1]) == false)
		// And the query agrees with what the initialiser does about it.
		#expect(throws: MetalogError.infeasible) {
			_ = try DistributionMetalog(coefficients: [0, -1])
		}
		let good = try DistributionMetalog(coefficients: [0, 1])
		#expect(DistributionMetalog.describesADistribution(coefficients: good.coefficients))
	}

	@Test("A grid too coarse to bracket anything reports nothing rather than guessing")
	func coarseGridReportsNothing() throws {
		let d = try DistributionMetalog(fittingProbabilities: [0.1, 0.5, 0.9],
										values: [-1.28, 0, 1.28])
		#expect(d.modes(gridSteps: 2).isEmpty)
		#expect(d.antiModes(gridSteps: 1).isEmpty)
		#expect(d.modes(gridSteps: 0).isEmpty)
	}

	// MARK: - Helpers

	/// A second search for turning points, sharing no code with `modes()`.
	///
	/// Walks the density on a uniform grid in probability and compares each point with
	/// its neighbours. No derivative, no refinement, no end grid — which is the whole
	/// value of it as a check.
	///
	/// - Parameters:
	///   - d: The distribution to scan.
	///   - steps: How many probabilities to sample.
	/// - Returns: The peaks and dips, as x values in increasing order.
	private static func scanForTurningPoints(_ d: DistributionMetalog,
											 steps: Int) -> (peaks: [Double], dips: [Double]) {
		var xs: [Double] = []
		var densities: [Double] = []
		for index in 1..<steps {
			let p: Double = Double(index) / Double(steps)
			guard let f = d.density(atProbability: p) else { continue }
			xs.append(d.quantile(p))
			densities.append(f)
		}
		var peaks: [Double] = []
		var dips: [Double] = []
		guard densities.count > 2 else { return ([], []) }
		for index in 1..<(densities.count - 1) {
			let before: Double = densities[index - 1]
			let here: Double = densities[index]
			let after: Double = densities[index + 1]
			if here > before, here > after { peaks.append(xs[index]) }
			if here < before, here < after { dips.append(xs[index]) }
		}
		return (peaks, dips)
	}

	/// The quantile of an even mixture of `N(−2, 1)` and `N(2, 1)`, by bisection.
	///
	/// Written out rather than fitted so the bimodality is a property of the target
	/// rather than of the metalog being tested.
	private static func mixtureQuantile(_ p: Double) -> Double {
		func cdf(_ x: Double) -> Double {
			let left: Double = normalCDF(x: x, mean: -2, stdDev: 1)
			let right: Double = normalCDF(x: x, mean: 2, stdDev: 1)
			let total: Double = left + right
			return total / 2
		}
		var low: Double = -12
		var high: Double = 12
		for _ in 0..<200 {
			let middle: Double = (low + high) / 2
			if cdf(middle) < p { low = middle } else { high = middle }
		}
		let total: Double = low + high
		return total / 2
	}
}

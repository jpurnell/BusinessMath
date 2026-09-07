//
//  HistogramAndCumulativeTests.swift
//  BusinessMath
//
//  The piecewise-uniform and discrete-cumulative siblings, and the SPT metalog.
//
//  All three are exact: a histogram's CDF is piecewise linear and its quantile is that
//  function's inverse, a discrete cumulative is a lookup, and an SPT metalog is an
//  exactly-determined fit. None of them needs a reference implementation, because in
//  each case the arithmetic *is* the definition — §2.2 of the coverage proposal.
//
//  What is worth testing is the boundaries, which is where a piecewise definition goes
//  wrong: a bin edge, a zero-weight bin, a probability landing exactly on a knot.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Histogram, discrete cumulative, and the SPT metalog")
struct HistogramAndCumulativeTests {

	// MARK: - Histogram

	@Test("Bin probabilities are the normalised weights")
	func binProbabilitiesAreTheWeights() throws {
		let histogram = try #require(DistributionHistogram(min: 0, max: 100, weights: [1, 3, 5, 2]))
		// Total 11, so the edges are at 1/11, 4/11, 9/11, 1.
		let expected: [Double] = [1.0 / 11, 4.0 / 11, 9.0 / 11, 1.0]
		for (index, edge) in expected.enumerated() {
			let x: Double = Double(index + 1) * 25
			#expect(abs(histogram.cdf(x) - edge) < 1e-12,
					"cdf at bin edge \(x) is \(histogram.cdf(x)), expected \(edge)")
		}
		// The weights are relative: scaling them all cannot change the distribution.
		let scaled = try #require(DistributionHistogram(min: 0, max: 100, weights: [10, 30, 50, 20]))
		for p in [0.1, 0.3, 0.5, 0.7, 0.9] {
			#expect(abs(histogram.quantile(p) - scaled.quantile(p)) < 1e-12,
					"scaling the weights moved q(\(p))")
		}
	}

	@Test("The density is flat within a bin")
	func densityIsFlatWithinABin() throws {
		// What "piecewise uniform" means, and the thing that separates it from a
		// cumulative curve through the same points.
		let histogram = try #require(DistributionHistogram(min: 0, max: 100, weights: [1, 3, 5, 2]))
		for binStart in [0.0, 25.0, 50.0, 75.0] {
			let firstHalf: Double = histogram.cdf(binStart + 12.5) - histogram.cdf(binStart)
			let secondHalf: Double = histogram.cdf(binStart + 25) - histogram.cdf(binStart + 12.5)
			#expect(abs(firstHalf - secondHalf) < 1e-12,
					"bin at \(binStart): \(firstHalf) then \(secondHalf)")
		}
	}

	@Test("A zero-weight bin cannot occur and the quantile steps across it")
	func zeroWeightBinsAreImpossible() throws {
		let histogram = try #require(DistributionHistogram(min: 0, max: 40, weights: [1, 0, 0, 1]))
		// The middle two bins hold no mass, so nothing lands in (10, 30).
		#expect(abs(histogram.cdf(10) - 0.5) < 1e-12)
		#expect(abs(histogram.cdf(20) - 0.5) < 1e-12, "mass appeared in an empty bin")
		#expect(abs(histogram.cdf(30) - 0.5) < 1e-12, "mass appeared in an empty bin")
		// And the quantile jumps the gap rather than returning a value from it.
		#expect(histogram.quantile(0.4999) <= 10)
		#expect(histogram.quantile(0.5001) >= 30)
	}

	@Test("A uniform histogram is the uniform distribution")
	func uniformWeightsGiveAUniform() throws {
		// Equal weights make every bin equally likely and the density flat throughout,
		// so the quantile must be exactly linear — which is a claim the piecewise
		// machinery could easily miss at the edges.
		let histogram = try #require(DistributionHistogram(min: 10, max: 20, weights: [1, 1, 1, 1, 1]))
		for step in 1..<100 {
			let p: Double = Double(step) / 100
			let expected: Double = 10 + 10 * p
			#expect(abs(histogram.quantile(p) - expected) < 1e-12,
					"q(\(p)) = \(histogram.quantile(p)), uniform gives \(expected)")
		}
		#expect(abs(histogram.mean - 15) < 1e-12)
	}

	@Test("The histogram quantile is monotone and inverts its CDF")
	func histogramContractHolds() throws {
		let histogram = try #require(DistributionHistogram(min: -5, max: 12, weights: [2, 0, 7, 1, 4]))
		var previous = -Double.infinity
		for step in 1..<300 {
			let p: Double = Double(step) / 300
			let x = histogram.quantile(p)
			#expect(x >= previous, "quantile fell from \(previous) to \(x) at p=\(p)")
			previous = x
			#expect(x >= -5 && x <= 12, "q(\(p)) = \(x) outside the range")
			#expect(abs(histogram.cdf(x) - p) < 1e-9, "cdf(quantile(\(p))) = \(histogram.cdf(x))")
		}
		#expect(histogram.cdf(-6) == 0)
		#expect(histogram.cdf(13) == 1)
	}

	@Test("Weights that describe no distribution are refused")
	func invalidHistogramsAreRefused() {
		#expect(DistributionHistogram(min: 0, max: 100, weights: []) == nil)
		#expect(DistributionHistogram(min: 0, max: 100, weights: [0, 0, 0]) == nil, "all-zero accepted")
		#expect(DistributionHistogram(min: 0, max: 100, weights: [1, -1]) == nil, "negative weight accepted")
		#expect(DistributionHistogram(min: 100, max: 0, weights: [1]) == nil, "reversed range accepted")
		#expect(DistributionHistogram(min: 0, max: 0, weights: [1]) == nil, "zero-width range accepted")
	}

	// MARK: - Discrete cumulative

	@Test("A discrete cumulative differences into its own probabilities")
	func discreteCumulativeDifferences() throws {
		let discrete = try #require(DistributionCumulativeDiscrete(
			values: [10, 20, 50], cumulative: [0.4, 0.75, 1.0]))
		#expect(abs(discrete.pmf(10) - 0.40) < 1e-12)
		#expect(abs(discrete.pmf(20) - 0.35) < 1e-12)
		#expect(abs(discrete.pmf(50) - 0.25) < 1e-12)
		// Nothing anywhere else, including between the stated values.
		#expect(discrete.pmf(15) == 0)
		#expect(discrete.pmf(0) == 0)
		#expect(discrete.pmf(51) == 0)
		// And the probabilities sum to one.
		let total: Double = discrete.pmf(10) + discrete.pmf(20) + discrete.pmf(50)
		#expect(abs(total - 1) < 1e-12)
	}

	@Test("It returns only stated values, never a value between them")
	func onlyStatedValuesAreReturned() throws {
		// The whole difference from `DistributionCumul`, which would interpolate.
		let discrete = try #require(DistributionCumulativeDiscrete(
			values: [10, 20, 50], cumulative: [0.4, 0.75, 1.0]))
		let allowed: Set<Int> = [10, 20, 50]
		for step in 1..<200 {
			let p: Double = Double(step) / 200
			#expect(allowed.contains(discrete.quantile(p)),
					"q(\(p)) = \(discrete.quantile(p)), which is not a stated outcome")
		}

		// Against the continuous sibling on the same pairs, which does interpolate.
		let continuous = try #require(DistributionCumul(lower: 0, upper: 50,
														values: [10, 20], probabilities: [0.4, 0.75]))
		#expect(abs(continuous.quantile(0.5) - 20) > 1e-6,
				"the continuous sibling did not interpolate, so the two are not distinguishable here")
	}

	@Test("The discrete quantile is monotone and consistent with the CDF")
	func discreteContractHolds() throws {
		let discrete = try #require(DistributionCumulativeDiscrete(
			values: [-5, 0, 3, 17], cumulative: [0.1, 0.1, 0.6, 1.0]))
		var previous = Int.min
		for step in 0...200 {
			let p: Double = Double(step) / 200
			let k = discrete.quantile(p)
			#expect(k >= previous, "quantile fell from \(previous) to \(k) at p=\(p)")
			previous = k
			// The defining relation: the quantile is the smallest k with cdf(k) >= p.
			if p > 0 && p < 1 {
				#expect(discrete.cdf(k) >= p - 1e-12,
						"cdf(\(k)) = \(discrete.cdf(k)) does not reach p=\(p)")
			}
		}
		// A zero-probability outcome — cumulative flat across it — is never returned.
		// Asserting membership of the reachable set rather than merely "not zero":
		// the weaker form is satisfied by a quantile that returns one single wrong
		// outcome forever, and the stronger one additionally insists all three
		// positive-probability outcomes actually appear.
		#expect(abs(discrete.pmf(0)) < 1e-12)
		let reachable: Set<Int> = [-5, 3, 17]
		var seen: Set<Int> = []
		for step in 1..<200 {
			let k = discrete.quantile(Double(step) / 200)
			#expect(reachable.contains(k),
					"q returned \(k), which the cumulative gives zero probability")
			seen.insert(k)
		}
		#expect(seen == reachable, "only \(seen.sorted()) of \(reachable.sorted()) were reachable")
	}

	@Test("A curve that is not a cumulative distribution is refused")
	func invalidCumulativesAreRefused() {
		// Not reaching 1 is missing mass; normalising on the caller's behalf would be
		// inventing an outcome they did not state.
		#expect(DistributionCumulativeDiscrete(values: [1, 2], cumulative: [0.3, 0.8]) == nil)
		#expect(DistributionCumulativeDiscrete(values: [1, 2], cumulative: [0.8, 0.3]) == nil, "decreasing accepted")
		#expect(DistributionCumulativeDiscrete(values: [2, 1], cumulative: [0.3, 1.0]) == nil, "unsorted values accepted")
		#expect(DistributionCumulativeDiscrete(values: [1, 2], cumulative: [0.0, 1.0]) == nil, "zero probability accepted")
		#expect(DistributionCumulativeDiscrete(values: [Int](), cumulative: []) == nil)
		// Two values rounding to one integer would silently merge two outcomes.
		#expect(DistributionCumulativeDiscrete(values: [1.1, 1.2], cumulative: [0.5, 1.0]) == nil)
	}

	// MARK: - SPT metalog

	@Test("A symmetric percentile triplet is reproduced exactly")
	func sptReproducesItsTriplet() throws {
		let spt = try DistributionMetalog(
			symmetricPercentileTriplet: (low: 120, median: 200, high: 450),
			at: 0.10, boundedness: .boundedBelow(lower: 0))
		#expect(abs(spt.quantile(0.10) - 120) < 1e-6, "q(0.10) = \(spt.quantile(0.10))")
		#expect(abs(spt.quantile(0.50) - 200) < 1e-6, "q(0.50) = \(spt.quantile(0.50))")
		#expect(abs(spt.quantile(0.90) - 450) < 1e-6, "q(0.90) = \(spt.quantile(0.90))")
		#expect(spt.terms == 3, "fitted \(spt.terms) terms, SPT is three")
		// The bound holds everywhere, which is why the bounded form was chosen.
		for p in [1e-9, 0.001, 0.5, 0.999, 1 - 1e-9] {
			#expect(spt.quantile(p) > 0, "q(\(p)) = \(spt.quantile(p)) below the bound")
		}
	}

	@Test("An asymmetric probability is refused: the triplet must be symmetric")
	func sptRequiresASymmetricProbability() {
		#expect(throws: MetalogError.invalidProbability) {
			_ = try DistributionMetalog(symmetricPercentileTriplet: (low: 1, median: 2, high: 3), at: 0.5)
		}
		#expect(throws: MetalogError.invalidProbability) {
			_ = try DistributionMetalog(symmetricPercentileTriplet: (low: 1, median: 2, high: 3), at: 0.9)
		}
		#expect(throws: MetalogError.invalidProbability) {
			_ = try DistributionMetalog(symmetricPercentileTriplet: (low: 1, median: 2, high: 3), at: 0)
		}
	}

	@Test("An SPT is the same as fitting its three points directly")
	func sptIsAThreePointFit() throws {
		// The convenience must not become a second implementation.
		let spt = try DistributionMetalog(symmetricPercentileTriplet: (low: 8, median: 12, high: 18), at: 0.25)
		let direct = try DistributionMetalog(fittingProbabilities: [0.25, 0.5, 0.75],
											 values: [8, 12, 18], terms: 3)
		for p in [0.05, 0.25, 0.5, 0.75, 0.95] {
			#expect(abs(spt.quantile(p) - direct.quantile(p)) < 1e-12,
					"at p=\(p): SPT \(spt.quantile(p)), direct \(direct.quantile(p))")
		}
	}

	@Test("A triplet too lopsided for three unbounded terms is refused, and a bound rescues it")
	func lopsidedTripletsAreRefusedUnbounded() throws {
		// Three terms is not enough shape for every triplet. (5, 12, 40) at the
		// quartiles is skewed hard enough that the unbounded fit turns back, which is
		// not a distribution — and the initialiser says so rather than returning one
		// that samples happily and is wrong.
		//
		// This is a statement about the elicitation, not the arithmetic, and the remedy
		// is the one Keelin's transforms exist for: a lower bound makes the same
		// triplet feasible, because the log map absorbs the skew.
		#expect(throws: MetalogError.infeasible) {
			_ = try DistributionMetalog(symmetricPercentileTriplet: (low: 5, median: 12, high: 40), at: 0.25)
		}

		let bounded = try DistributionMetalog(
			symmetricPercentileTriplet: (low: 5, median: 12, high: 40),
			at: 0.25, boundedness: .boundedBelow(lower: 0))
		#expect(abs(bounded.quantile(0.25) - 5) < 1e-6)
		#expect(abs(bounded.quantile(0.50) - 12) < 1e-6)
		#expect(abs(bounded.quantile(0.75) - 40) < 1e-6)
	}
}

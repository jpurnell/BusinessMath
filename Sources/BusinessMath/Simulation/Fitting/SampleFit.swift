//
//  SampleFit.swift
//  BusinessMath
//

import Foundation
import Numerics

/// The Anderson–Darling statistic for a sample against a fully specified distribution.
///
/// ```
/// A² = −n − (1/n) Σᵢ (2i − 1) [ ln F(x₍ᵢ₎) + ln(1 − F(x₍ₙ₊₁₋ᵢ₎)) ]
/// ```
///
/// Chosen over Kolmogorov–Smirnov because of where the weight sits. KS is the largest
/// vertical gap between the empirical and fitted CDFs, and that gap is almost always in
/// the middle of the distribution, where the empirical CDF has the most room to move.
/// Anderson–Darling divides by `F(1 − F)`, which is small in the tails, so a
/// discrepancy at the extremes counts for far more. For a risk model that is the whole
/// question — a fit that is excellent through the body and wrong in the last percentile
/// is worse than useless, and KS will happily call it the best of the candidates.
///
/// - Parameters:
///   - sample: At least two finite observations. Order does not matter; it is sorted.
///   - distribution: The candidate, fully specified — no parameters estimated here.
/// - Returns: `A²`, non-negative and smaller for a better fit, or `nil` if the sample
///   is too small or holds a value that is not a number. Returns `infinity` when the
///   distribution assigns a sample point probability zero on one side: that is not a
///   numerical failure but the correct verdict, since the candidate says an observed
///   value could not have happened.
public func andersonDarlingStatistic<D: ContinuousDistribution>(
	_ sample: [Double], against distribution: D
) -> Double? where D.T == Double {
	guard sample.count >= 2 else { return nil }
	guard sample.allSatisfy({ $0.isFinite }) else { return nil }
	let sorted = sample.sorted()
	let n = sorted.count
	var total: Double = 0
	for index in 0..<n {
		let lower: Double = distribution.cdf(sorted[index])
		let upper: Double = distribution.cdf(sorted[n - 1 - index])
		guard lower > 0, upper < 1 else { return .infinity }
		let weight: Double = Double(2 * index + 1)
		let logLower: Double = Double.log(lower)
		let logUpper: Double = Double.log(1 - upper)
		let paired: Double = logLower + logUpper
		total += weight * paired
	}
	let count: Double = Double(n)
	guard count > 0 else { return nil }
	let averaged: Double = total / count
	return -count - averaged
}

public extension DistributionMomentFit {

	/// Fits a distribution to a sample, through its first four moments.
	///
	/// Binds Risk Solver's `PsiFit(data)`.
	///
	/// ## Why this is a family selection and not just a curve
	///
	/// It looks like one distribution being fitted, and it is four. The Johnson system
	/// partitions the `(β₁, β₂)` moment plane between the bounded `S_B`, the unbounded
	/// `S_U`, the lognormal line that separates them, and the normal at the single
	/// point where skewness is zero and kurtosis is three. Which family comes back is
	/// determined by where the *sample's* moments land, so the choice is made by the
	/// data rather than by a caller guessing. Every admissible pair of moments is
	/// covered by exactly one family, which is why this cannot fail for want of a
	/// candidate the way a fixed shortlist can.
	///
	/// ## Two conventions worth stating
	///
	/// The kurtosis this takes is **not** excess — three for a normal — while the
	/// library's ``kurtosis(_:_:)`` returns excess. Three is added here rather than
	/// asked of the caller, because the two conventions differ by an amount that looks
	/// entirely plausible and produces a fit that is wrong without looking wrong.
	///
	/// Sample rather than population moments, matching Excel's `SKEW` and `KURT` and
	/// the rest of this library's descriptors.
	///
	/// - Parameter sample: At least four finite observations, not all identical. Four
	///   because that is how many moments are being estimated; a smaller sample makes
	///   the third and fourth meaningless rather than merely imprecise.
	/// - Throws: ``MomentFitError`` naming what the sample could not supply.
	init(sample: [Double]) throws {
		guard sample.count >= 4 else { throw MomentFitError.nonFiniteMoment }
		guard sample.allSatisfy({ $0.isFinite }) else { throw MomentFitError.nonFiniteMoment }
		// Module-qualified throughout. `DistributionMomentFit` has stored properties
		// called `mean` and `kurtosis`, so inside its own extension the bare names
		// resolve to those rather than to the descriptors — and for `mean` that would
		// be a self-reference during initialisation rather than a visible mistake.
		let centre: Double = BusinessMath.mean(sample)
		let spread: Double = BusinessMath.stdDev(sample)
		guard spread > 0, spread.isFinite else {
			throw MomentFitError.nonPositiveStandardDeviation
		}
		let thirdMoment: Double = BusinessMath.skew(sample)
		let excess: Double = BusinessMath.kurtosis(sample)
		let fourthMoment: Double = excess + 3
		try self.init(mean: centre, standardDeviation: spread,
					  skewness: thirdMoment, kurtosis: fourthMoment)
	}
}

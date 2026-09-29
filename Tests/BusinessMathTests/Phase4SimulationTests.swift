//
//  Phase4SimulationTests.swift
//  BusinessMathTests
//
//  Phase 4 of the contaminated-input sweep — shape G, `else { return T(0) }` after a
//  validity guard, over `Sources/BusinessMath/Simulation/**` and `InventorySimulator`.
//
//  156 sites were read. Almost all of them are legitimate, and the two large families are
//  pinned at the bottom of this file so a later sweep sees the reasoning rather than the
//  shape: a density is *defined* to be zero outside its support, and every quantile in the
//  module answers the support's infimum for a probability at or below zero. Those are not
//  fabricated zeros, they are the values.
//
//  What is asserted here is the remainder: four places where the zero — or the missing
//  guard — was a claim the caller could not tell from a measurement.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("Phase 4 — simulation fallbacks that were claims")
struct Phase4SimulationTests {

	// MARK: - triangularDistribution: the seed at zero

	/// The inverse CDF at probability zero is the lower bound of the support. It was not.
	///
	/// `u > 0 && u < fc` excluded exactly one value — `uSeed == 0`, which `uSeed >= 0` three
	/// guards above explicitly admits — and sent it to the *upper* arm, which returns
	/// `high − √((high−low)(high−base))`. Every expected value below is the inverse CDF, not
	/// a recorded output.
	@Test("Triangular_ZeroSeed_ReturnsLowerBound")
	func triangularZeroSeedReturnsLowerBound() {
		// Mode in the interior. The old answer was 10 − √(10·5) = 2.9289…, a plausible
		// interior value with nothing to mark it wrong.
		let interiorMode: Double = triangularDistribution(low: 0.0, high: 10.0, base: 5.0, 0.0)
		#expect(interiorMode.isEqual(to: 0.0), "F⁻¹(0) is the lower bound; got \(interiorMode)")

		// Mode at the lower bound, where `fc` is zero and the upper arm covers the whole
		// support. This one was already right, and stays right — the fix must not move it.
		let modeAtLow: Double = triangularDistribution(low: 2.0, high: 8.0, base: 2.0, 0.0)
		#expect(modeAtLow.isEqual(to: 2.0), "F⁻¹(0) is the lower bound; got \(modeAtLow)")

		// Mode at the upper bound, where `fc` is one. The old answer here was `high` — the
		// far end of the support from where F⁻¹(0) lives, and the sharpest of the three.
		let modeAtHigh: Double = triangularDistribution(low: 0.0, high: 10.0, base: 10.0, 0.0)
		#expect(modeAtHigh.isEqual(to: 0.0), "F⁻¹(0) is the lower bound; got \(modeAtHigh)")
	}

	/// CLEAN CONTROL. The seeds that were already correct are untouched, including the
	/// boundary at the other end and the quantisation step just above zero.
	@Test("Triangular_NonZeroSeeds_Unchanged")
	func triangularNonZeroSeedsUnchanged() {
		// u = 0.25 < F(base) = 0.5, so the lower arm: low + √(u·(high−low)·(base−low)).
		let atQuarter: Double = triangularDistribution(low: 0.0, high: 10.0, base: 5.0, 0.25)
		let underRoot: Double = 12.5
		let expectedQuarter: Double = underRoot.squareRoot()
		let quarterError: Double = abs(atQuarter - expectedQuarter)
		#expect(quarterError < 1e-12, "got \(atQuarter)")

		// The mode of a symmetric triangle is reached at u = F(base) = 0.5, from the upper
		// arm — `1 − u` is `(high−base)/(high−low)`, so the root is exactly `high − base`.
		let atMode: Double = triangularDistribution(low: 0.0, high: 1.0, base: 0.5, 0.5)
		#expect(atMode.isEqual(to: 0.5), "got \(atMode)")

		// The upper boundary: `1 − u` is zero, so the upper arm returns `high` exactly.
		let atOne: Double = triangularDistribution(low: 0.0, high: 10.0, base: 5.0, 1.0)
		#expect(atOne.isEqual(to: 10.0), "got \(atOne)")

		// An eighth: exactly representable, and the millionth-quantisation is exact on it, so
		// the lower arm gives √(0.125 · 10 · 5) = √6.25 = 2.5 with no rounding to argue about.
		let atEighth: Double = triangularDistribution(low: 0.0, high: 10.0, base: 5.0, 0.125)
		#expect(atEighth.isEqual(to: 2.5), "got \(atEighth)")
	}

	/// CLEAN CONTROL. The parameter screening the earlier trap fix installed is unchanged.
	@Test("Triangular_ParameterScreening_Unchanged")
	func triangularParameterScreeningUnchanged() {
		let notANumber: Double = triangularDistribution(low: 0.0, high: 10.0, base: 5.0, Double.nan)
		#expect(notANumber.isNaN, "got \(notANumber)")

		let belowZero: Double = triangularDistribution(low: 0.0, high: 10.0, base: 5.0, -0.5)
		#expect(belowZero.isNaN, "got \(belowZero)")

		let transposed: Double = triangularDistribution(low: 10.0, high: 5.0, base: 7.0, 0.0)
		#expect(transposed.isNaN, "got \(transposed)")
	}

	// MARK: - InventorySimulator: the iteration count nobody screened

	/// Zero paths is not a distribution, and it used to be a crash.
	///
	/// `iterations: 0` left `ddltValues` empty, so `sorted.count - 1` was `-1` and the clamp
	/// written to keep the subscript in range — `max(0, min(-1, index))` — raised it back to
	/// `0` and indexed an empty array. A negative count died earlier still, inside
	/// `reserveCapacity`. Neither reached an assertion; the process ended.
	@Test("Inventory_NonPositiveIterations_Refused")
	func inventoryNonPositiveIterationsRefused() throws {
		let demand = Array(repeating: 10.0, count: 60)

		var zeroMessage: String?
		do {
			_ = try InventorySimulator.simulate(
				demandHistory: demand,
				meanLeadTime: 7.0,
				serviceLevel: 0.95,
				iterations: 0,
				seed: 0x50D_4_00
			)
			Issue.record("iterations: 0 returned a Result instead of throwing")
		} catch let error as OperationsError {
			if case .invalidParameter(let message) = error { zeroMessage = message }
		} catch {
			Issue.record("expected OperationsError, got \(error)")
		}
		let zeroText: String = try #require(zeroMessage)
		#expect(zeroText.contains("iterations"), "the message must name the parameter; got \(zeroText)")

		var negativeMessage: String?
		do {
			_ = try InventorySimulator.simulate(
				demandHistory: demand,
				meanLeadTime: 7.0,
				serviceLevel: 0.95,
				iterations: -1,
				seed: 0x50D_4_01
			)
			Issue.record("iterations: -1 returned a Result instead of throwing")
		} catch let error as OperationsError {
			if case .invalidParameter(let message) = error { negativeMessage = message }
		} catch {
			Issue.record("expected OperationsError, got \(error)")
		}
		let negativeText: String = try #require(negativeMessage)
		#expect(negativeText.contains("iterations"), "the message must name the parameter; got \(negativeText)")
	}

	/// CLEAN CONTROL. A run with a positive iteration count answers exactly what it did.
	///
	/// Constant demand of 10 and a fixed lead time of 7 make every path identical, so the
	/// whole DDLT distribution is the single value 70 and the reorder point is 70 at any
	/// service level — derived from the inputs, not read off a run.
	@Test("Inventory_PositiveIterations_Unchanged")
	func inventoryPositiveIterationsUnchanged() throws {
		let demand = Array(repeating: 10.0, count: 60)
		let result = try InventorySimulator.simulate(
			demandHistory: demand,
			meanLeadTime: 7.0,
			serviceLevel: 0.95,
			iterations: 200,
			seed: 0x50D_4_02
		)
		#expect(result.reorderPoint.isEqual(to: 70.0), "got \(result.reorderPoint)")
		#expect(result.demandDuringLeadTimeMean.isEqual(to: 70.0), "got \(result.demandDuringLeadTimeMean)")
		#expect(result.safetyStock.isEqual(to: 0.0), "got \(result.safetyStock)")
		#expect(result.pathCount == 200, "got \(result.pathCount)")

		// The single smallest positive count, which is where the old clamp was one element
		// away from indexing off the end.
		let single = try InventorySimulator.simulate(
			demandHistory: demand,
			meanLeadTime: 7.0,
			serviceLevel: 0.95,
			iterations: 1,
			seed: 0x50D_4_03
		)
		#expect(single.reorderPoint.isEqual(to: 70.0), "got \(single.reorderPoint)")
		#expect(single.pathCount == 1, "got \(single.pathCount)")
	}

	// MARK: - DistributionGeometric: an unusable p, now refused at the door

	/// An unusable `p` no longer reaches a method at all.
	///
	/// This test used to assert the three different answers `pmf`, `cdf` and `quantile` each
	/// invented for a stored `p` of zero, `1.5`, `-0.25` or `nan` — `nan`, `nan` and
	/// `Int.max`. They had to invent them because `init(_:)` stored whatever it was given,
	/// alone in its family: ``DistributionNegativeBinomial/init(successes:p:)``,
	/// ``DistributionLogarithmic/init(_:)`` and ``DistributionPoisson/init(lambda:)`` are all
	/// failable and screen their parameter. As of `v3.0.0-alpha.7` so is this one, which is a
	/// strictly stronger statement than any of those three: the distribution does not exist,
	/// so no method has to describe what it would mean.
	///
	/// The change is source-breaking and was taken inside the `3.0.0` pre-release window,
	/// where SPM's exclusion of pre-releases from `from:` ranges limits the blast radius to
	/// callers naming an alpha exactly.
	@Test("Geometric_UnusableProbability_Refused")
	func geometricUnusableProbabilityRefused() throws {
		// p = 0: success never occurs, so there is no distribution over trial counts.
		#expect(DistributionGeometric(0.0) == nil, "p = 0 is not a Bernoulli trial to count")
		#expect(DistributionGeometric(1.5) == nil, "p above one is not a probability")
		#expect(DistributionGeometric(-0.25) == nil, "a negative p is not a probability")
		#expect(DistributionGeometric(Double.nan) == nil, "a NaN p is not a probability")
		#expect(DistributionGeometric(Double.infinity) == nil, "an infinite p is not a probability")

		// p = 1 is the degenerate distribution, not an error, so the screen must admit it:
		// every draw is the first trial, and all the mass sits on k = 1.
		let certain = try #require(DistributionGeometric(1.0), "p = 1 is admissible")
		let massAtFirstTrial: Double = certain.pmf(1)
		#expect(massAtFirstTrial.isEqual(to: 1.0), "got \(massAtFirstTrial)")
		let massAtSecondTrial: Double = certain.pmf(2)
		#expect(massAtSecondTrial.isEqual(to: 0.0), "got \(massAtSecondTrial)")
	}

	/// CLEAN CONTROL. A usable `p` is untouched, including the zero below the support, which
	/// is a genuine zero and not a refusal.
	@Test("Geometric_UsableProbability_Unchanged")
	func geometricUsableProbabilityUnchanged() throws {
		let dist = try #require(DistributionGeometric(0.25))

		// P(X = 1) = p; P(X = 2) = (1−p)·p.
		let firstTrial: Double = dist.pmf(1)
		#expect(abs(firstTrial - 0.25) < 1e-15, "got \(firstTrial)")
		let secondTrial: Double = dist.pmf(2)
		#expect(abs(secondTrial - 0.1875) < 1e-15, "got \(secondTrial)")

		// Below the support: zero mass, and still zero after splitting the guard.
		let belowSupport: Double = dist.pmf(0)
		#expect(belowSupport.isEqual(to: 0.0), "got \(belowSupport)")
		let cdfBelowSupport: Double = dist.cdf(0)
		#expect(cdfBelowSupport.isEqual(to: 0.0), "got \(cdfBelowSupport)")

		// P(X ≤ 2) = 1 − (1−p)² = 1 − 0.5625.
		let throughSecond: Double = dist.cdf(2)
		#expect(abs(throughSecond - 0.4375) < 1e-15, "got \(throughSecond)")

		// ⌈ln(1−q)/ln(1−p)⌉ at q = 0.5, p = 0.25: ⌈2.4094…⌉ = 3.
		let median: Int = dist.quantile(0.5)
		#expect(median == 3, "got \(median)")
		// The documented sentinels at both ends of the probability scale.
		let atZero: Int = dist.quantile(0.0)
		#expect(atZero == 1, "got \(atZero)")
		let atNaN: Int = dist.quantile(Double.nan)
		#expect(atNaN == 1, "got \(atNaN)")
		let atOne: Int = dist.quantile(1.0)
		#expect(atOne == Int.max, "got \(atOne)")
	}

	// MARK: - SimulationResults: the bin count with no guard of its own

	/// CLEAN CONTROL for the `calculateOptimalBins` guard, which is unreachable by design.
	///
	/// `Int(ceil(log2(0) + 1))` traps, and `histogram(bins:)` — the only caller — has always
	/// refused an empty sample first. The guard added there makes the conversion total on its
	/// own terms; this pins that it changed nothing reachable.
	@Test("Histogram_BinSelection_Unchanged")
	func histogramBinSelectionUnchanged() {
		let empty = SimulationResults(values: [])
		let automaticOnEmpty: Bool = empty.histogram().isEmpty
		#expect(automaticOnEmpty, "an empty sample still has no bins")
		let explicitOnEmpty: Bool = empty.histogram(bins: 8).isEmpty
		#expect(explicitOnEmpty, "an empty sample still has no bins")

		let sample = SimulationResults(values: [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0])
		let explicit = sample.histogram(bins: 4)
		#expect(explicit.count == 4, "got \(explicit.count)")
		let binned: Int = explicit.reduce(0) { $0 + $1.count }
		#expect(binned == 8, "every value lands in exactly one bin; got \(binned)")

		let automatic = sample.histogram()
		#expect(automatic.count >= 1, "got \(automatic.count)")
		#expect(automatic.count <= 1_000, "got \(automatic.count)")

		// A single observation is the smallest sample the automatic path runs on, and the
		// one nearest the `log2(0)` edge: `log2(1)` is 0, so Sturges asks for one bin.
		let singleton = SimulationResults(values: [42.0])
		let singletonBins: Int = singleton.histogram().count
		#expect(singletonBins == 1, "got \(singletonBins)")
	}

	// MARK: - The two families that are not defects

	/// PIN. A density is zero outside its support *by definition*, not as a fallback.
	///
	/// 25 of the 156 sites read in this phase are this guard, and 43 more are the
	/// `x.isFinite` screen in front of it. ``ContinuousDistribution/pdf(_:)`` states both:
	/// "zero outside the support rather than undefined", so that a caller plotting across a
	/// range need not know where the support ends. Changing these to `nan` would break the
	/// documented contract every conformer is tested against.
	@Test("Pinned_DensityOutsideSupportIsZero")
	func pinnedDensityOutsideSupportIsZero() {
		let pareto = DistributionPareto(scale: 2.0, shape: 3.0)
		let belowScale: Double = pareto.pdf(1.0)
		#expect(belowScale.isEqual(to: 0.0), "below xₘ the density is zero; got \(belowScale)")

		// At the far tail the density is zero in the limit, which is what the finiteness
		// screen returns — the same answer the algebra reaches, not a substitute for it.
		let atInfinity: Double = pareto.pdf(Double.infinity)
		#expect(atInfinity.isEqual(to: 0.0), "got \(atInfinity)")

		// Inside the support it is the formula: α·xₘ^α / x^(α+1) at x = xₘ is α/xₘ.
		let atScale: Double = pareto.pdf(2.0)
		#expect(abs(atScale - 1.5) < 1e-12, "got \(atScale)")
	}

	/// PIN. `guard p > 0 else { return <support infimum> }` is the module's quantile
	/// convention, and the sites that spell that infimum `0` are the distributions whose
	/// support starts at zero — not a fabricated zero.
	///
	/// All ten shape-G quantile sites are this. The convention is stated on each declaration
	/// ("At or below zero the answer is zero, the lower bound of the support").
	///
	/// **The `nan` half of that convention was withdrawn in `v3.0.0-alpha.7`.** It was never
	/// a decision so much as the same guard catching a second question: `nan > 0` is false
	/// like every comparison against a NaN, so an unreadable probability fell to the branch
	/// written for a probability at the bottom of the scale. The two are not the same claim —
	/// `p = 0` genuinely is the support infimum, `p = nan` is no probability at all — and the
	/// conformers did not even agree on which end to fabricate: the same NaN drew the support
	/// minimum here, `+infinity` from ``DistributionWeibull``, `-infinity` from
	/// ``DistributionCauchy``. ``ContinuousDistribution/quantile(_:)`` now answers `nan`, and
	/// `DistributionNaNContractTests` asserts it for all forty-six. The `p <= 0` line below is
	/// the part that was right and is unchanged.
	@Test("Pinned_QuantileBelowZeroIsSupportInfimum")
	func pinnedQuantileBelowZeroIsSupportInfimum() throws {
		let lomax = try #require(DistributionPareto2(scale: 2.0, shape: 3.0))
		let atZero: Double = lomax.quantile(0.0)
		#expect(atZero.isEqual(to: 0.0), "got \(atZero)")
		let belowZero: Double = lomax.quantile(-1.0)
		#expect(belowZero.isEqual(to: 0.0), "got \(belowZero)")
		let contaminated: Double = lomax.quantile(Double.nan)
		let contaminatedIsNaN: Bool = contaminated.isNaN
		#expect(contaminatedIsNaN,
				"a NaN probability is no longer conflated with zero; got \(contaminated)")

		// The interior is the formula: b·((1−p)^(−1/q) − 1). At p = 7/8 with q = 3 the
		// complement is 1/8, whose cube root is 1/2, so the quantile is 2·(2 − 1) = 2.
		let interior: Double = lomax.quantile(0.875)
		#expect(abs(interior - 2.0) < 1e-12, "got \(interior)")
	}
}

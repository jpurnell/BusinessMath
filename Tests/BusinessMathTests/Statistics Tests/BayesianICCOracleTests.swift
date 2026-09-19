//
//  BayesianICCOracleTests.swift
//  BusinessMathTests
//
//  The Gibbs sampler against the estimators it should agree with.
//

import Testing
import Foundation
import RealModule
@testable import BusinessMath

/// `bayesianICC` measured against the two estimators of the same quantity that sit beside it.
///
/// ## Why this suite exists
///
/// The missing-data `bayesianICC` carries a cognitive complexity of 101 and the complete-data one
/// 54, and neither had an oracle. They are the third and fourth implementations in this package
/// of "an intraclass correlation from a two-way model", after the ANOVA `icc` and the EM `icc` —
/// which is exactly the situation where the same mistake gets made more than once.
///
/// It had been. `iccFromComponents` here began
///
/// ```swift
/// case .twoWayRandom, .oneWayRandom:
///     denominator = sigmaS + sigmaR + sigmaE
/// ```
///
/// lumping the one-way model in with the two-way absolute one, which is the identical defect
/// found in `iccMissingData` the same day. A one-way design has no separable rater effect: rater
/// variation is part of the noise a subject is measured against, so it comes out of the *subject*
/// term as well as sitting in the denominator.
///
/// ## What a Gibbs sampler can be checked against
///
/// Not an exact value — it is a stochastic estimate, and a posterior mean under a proper prior is
/// not the same estimand as a point estimate. But three things do hold, and they are enough:
///
/// 1. **ICC(1,1) is not ICC(2,1)**, whatever the prior and however long the chain.
/// 2. **The posterior mean lands near the ANOVA estimate** when the data are informative and the
///    prior is diffuse, because the likelihood dominates.
/// 3. **The two overloads agree on complete data**, because a matrix with no absences is the same
///    matrix whether its cells are `T` or `T?`.
@Suite("The Gibbs ICC against its neighbours")
struct BayesianICCOracleTests {

	/// Shrout & Fleiss (1979) Table 1 — the fixture the ANOVA estimator is pinned against, so
	/// the comparison below is anchored to a published value rather than to another estimate.
	static let ratings: [[Double]] = [
		[9, 2, 5, 8],
		[6, 1, 3, 2],
		[8, 4, 6, 8],
		[7, 1, 2, 6],
		[10, 5, 6, 9],
		[6, 2, 4, 7]
	]

	static var complete: [[Double?]] { ratings.map { $0.map { Optional($0) } } }

	/// Seeded, so every figure quoted in this suite is reproducible. Long enough that the
	/// posterior mean is not dominated by Monte Carlo error.
	static let config = GibbsConfig<Double>(
		iterations: 6_000,
		burnIn: 2_000,
		thinning: 2,
		chains: 2,
		seed: 20_260_919
	)

	// MARK: - 1. The one-way model is its own model

	/// ICC(1,1) and ICC(2,1) cannot be the same number.
	///
	/// The defect is in the mapping from variance components to a coefficient, so it survives
	/// any amount of sampling — the chains are identical, only the final division differs. That
	/// makes this checkable exactly despite the estimator being stochastic.
	@Test("The one-way and two-way random models give different coefficients", arguments: [
		"complete", "with absences"
	])
	func oneWayIsNotTwoWay(spelling: String) throws {
		let oneWay: Double
		let twoWay: Double
		if spelling == "complete" {
			oneWay = try bayesianICC(Self.ratings, model: .oneWayRandom, config: Self.config).iccMean
			twoWay = try bayesianICC(Self.ratings, model: .twoWayRandom, config: Self.config).iccMean
		} else {
			var holed = Self.complete
			holed[1][2] = nil
			oneWay = try bayesianICC(holed, model: .oneWayRandom, config: Self.config).iccMean
			twoWay = try bayesianICC(holed, model: .twoWayRandom, config: Self.config).iccMean
		}

		// Bit patterns: the defect made the two *identical*, so "not the same number" is the
		// claim, and identical is what has to be ruled out — not "differ by more than epsilon".
		#expect(oneWay.bitPattern != twoWay.bitPattern,
				"""
				\(spelling): both models returned \(oneWay) — a one-way design has no separable \
				rater effect, so they cannot share a formula
				""")

		// On this matrix the raters disagree markedly, so pooling their spread into the noise
		// has to push the one-way coefficient below the two-way one.
		#expect(oneWay < twoWay,
				"\(spelling): ICC(1,1) is the smaller here; got \(oneWay) against \(twoWay)")
	}

	// MARK: - 2. A diffuse prior lets the data speak

	/// The posterior mean sits near the ANOVA estimate.
	///
	/// With a diffuse prior the likelihood dominates, so the Gibbs posterior mean should land in
	/// the neighbourhood of the classical estimate. It will not match: a posterior mean of a
	/// bounded, skewed quantity is not the point estimate, and the prior still contributes.
	///
	/// **The tolerance is measured, not chosen, and the first version of it was too loose to be
	/// worth anything.** Written at 0.2 it passed while `.oneWayRandom` was returning the
	/// `.twoWayRandom` figure — 0.2807 against a classical 0.1657, a gap of 0.115. The identity
	/// test above is what actually caught that. With the formula corrected the three gaps are:
	///
	/// | model | posterior mean | classical | gap |
	/// |---|---|---|---|
	/// | ICC(1,1) | 0.188052 | 0.165742 | 0.022 |
	/// | ICC(2,1) | 0.280732 | 0.289764 | 0.009 |
	/// | ICC(3,1) | 0.684873 | 0.714841 | 0.030 |
	///
	/// so 0.06 leaves twice the headroom the worst case needs and still fails on the defect that
	/// slipped through at 0.2. A bound that cannot fail on the bug it was written after is not a
	/// bound.
	///
	/// The ANOVA figures are the ones pinned in `ICCAgreementOracleTests` against Shrout &
	/// Fleiss (1979): ICC(1,1) = 0.16574, ICC(2,1) = 0.28976, ICC(3,1) = 0.71484.
	@Test("The posterior mean lands near the classical estimate", arguments: [
		(ICCModel.oneWayRandom, ICCAgreement.absolute, 0.1657417684054754),
		(ICCModel.twoWayRandom, ICCAgreement.absolute, 0.28976377952755905),
		(ICCModel.twoWayMixed, ICCAgreement.consistency, 0.7148407148407151)
	])
	func thePosteriorMeanIsNearTheClassicalEstimate(
		model: ICCModel,
		agreement: ICCAgreement,
		classical: Double
	) throws {
		let posterior = try bayesianICC(Self.ratings, model: model, config: Self.config)
		let anova = try icc(Self.ratings, model: model, agreement: agreement).icc

		// The fixture's classical value, confirmed rather than assumed.
		#expect(abs(anova - classical) < 1e-12,
				"the ANOVA estimator moved: expected \(classical), got \(anova)")

		#expect(abs(posterior.iccMean - classical) < 0.06,
				"""
				the posterior mean is \(posterior.iccMean) against a classical estimate of \
				\(classical) — too far apart for a diffuse prior on informative data
				""")

		// The chains have to have mixed, or the mean above describes nothing. R-hat near 1 is
		// the standard reading; all three models sit at 1.002 or below on this fixture.
		let rHat = try #require(posterior.rHat, "two chains were configured, so R-hat must exist")
		#expect(rHat < 1.05, "R-hat is \(rHat); the chains have not mixed")

		// And the classical estimate must fall inside the credible interval, or the posterior is
		// describing a different quantity.
		#expect(posterior.iccCredibleInterval.lower <= classical,
				"""
				the classical estimate \(classical) is below the credible interval \
				[\(posterior.iccCredibleInterval.lower), \(posterior.iccCredibleInterval.upper)]
				""")
		#expect(posterior.iccCredibleInterval.upper >= classical,
				"""
				the classical estimate \(classical) is above the credible interval \
				[\(posterior.iccCredibleInterval.lower), \(posterior.iccCredibleInterval.upper)]
				""")
	}

	// MARK: - 3. A complete matrix takes the fast path, and one absence does not

	/// A matrix with no absences is handed straight to the complete-data sampler.
	///
	/// **This is a test of the delegation, not of two samplers agreeing** — and the first version
	/// of it claimed otherwise. `bayesianICC(_: [[T?]], ...)` computes `totalObs == n * k` and,
	/// when that holds, unwraps and calls the other overload. So a "the two agree on complete
	/// data" assertion passes because it is literally the same call, which is the shape of test
	/// that looks the same whether the work ran or not.
	///
	/// Stated as what it can actually check, it becomes sharper rather than weaker: the results
	/// must be **bit-identical**. Anything else means the completeness test did not fire and a
	/// complete matrix ran down the slower, separate path — which would be a silent performance
	/// and reproducibility difference rather than a wrong number, and so exactly the kind of
	/// thing no other assertion here would notice.
	@Test("A complete matrix is handed to the complete-data sampler", arguments: [
		ICCModel.oneWayRandom, ICCModel.twoWayRandom, ICCModel.twoWayMixed
	])
	func aCompleteMatrixTakesTheFastPath(model: ICCModel) throws {
		let direct = try bayesianICC(Self.ratings, model: model, config: Self.config)
		let viaOptional = try bayesianICC(Self.complete, model: model, config: Self.config)

		#expect(direct.iccMean.bitPattern == viaOptional.iccMean.bitPattern,
				"""
				\(model): the optional overload gave \(viaOptional.iccMean) where the direct one \
				gave \(direct.iccMean) — so a complete matrix did not take the delegation
				""")
		#expect(direct.iccCredibleInterval.lower.bitPattern
					== viaOptional.iccCredibleInterval.lower.bitPattern,
				"\(model): the intervals differ, so the two runs were not the same run")
	}

	/// One absence puts the matrix on the separate sampler, and it must still answer.
	///
	/// This is where the missing-data sweep actually runs — six conjugate updates guarded by
	/// `if let` on every cell, a code path nothing above reaches. Removing one rating from
	/// twenty-four cannot be allowed to move the posterior far, and the classical estimate on
	/// the full matrix stays the right neighbourhood to judge it against.
	@Test("One absence routes to the missing-data sweep and still answers", arguments: [
		(ICCModel.twoWayRandom, 0.28976377952755905),
		(ICCModel.twoWayMixed, 0.7148407148407151)
	])
	func oneAbsenceUsesTheMissingDataSweep(model: ICCModel, classical: Double) throws {
		var holed = Self.complete
		holed[3][2] = nil

		let full = try bayesianICC(Self.ratings, model: model, config: Self.config)
		let partial = try bayesianICC(holed, model: model, config: Self.config)

		// It must *not* be the same run — that is what shows the other path was taken.
		#expect(partial.iccMean.bitPattern != full.iccMean.bitPattern,
				"removing a cell changed nothing, so the missing-data sweep did not run")

		#expect(partial.iccMean > -1.0 && partial.iccMean <= 1.0,
				"a correlation must lie in [-1, 1], got \(partial.iccMean)")
		#expect(abs(partial.iccMean - classical) < 0.1,
				"""
				\(model): with one of twenty-four ratings absent the posterior mean is \
				\(partial.iccMean) against a classical \(classical) on the full matrix
				""")

		let rHat = try #require(partial.rHat, "two chains were configured, so R-hat must exist")
		#expect(rHat < 1.05, "R-hat is \(rHat) on the missing-data sweep; the chains have not mixed")
	}

	// MARK: - 4. Seeding means what it says

	/// The same seed gives the same posterior, exactly.
	///
	/// This file's own comments record a defect where a fixed budget of pre-drawn uniforms ran
	/// out mid-draw and the chain silently finished on the global generator, so the seed stopped
	/// meaning anything from that point. The fix threaded one generator through every draw; this
	/// is the assertion that keeps it threaded.
	@Test("A seeded chain reproduces exactly")
	func aSeededChainReproduces() throws {
		let first = try bayesianICC(Self.ratings, model: .twoWayRandom, config: Self.config)
		let second = try bayesianICC(Self.ratings, model: .twoWayRandom, config: Self.config)

		#expect(first.iccMean.bitPattern == second.iccMean.bitPattern,
				"two seeded runs gave \(first.iccMean) and \(second.iccMean)")
		#expect(first.iccCredibleInterval.lower.bitPattern == second.iccCredibleInterval.lower.bitPattern,
				"the interval moved between two seeded runs")
	}
}

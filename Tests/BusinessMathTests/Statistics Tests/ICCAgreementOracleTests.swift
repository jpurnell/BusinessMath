//
//  ICCAgreementOracleTests.swift
//  BusinessMathTests
//
//  The two `icc` overloads, against Shrout & Fleiss and against each other.
//

import Testing
import Foundation
import RealModule
@testable import BusinessMath

/// Both `icc` overloads measured against a published reference and against one another.
///
/// ## Why this suite exists
///
/// There are two functions named `icc`. One takes `[[T]]` and computes the coefficient from
/// ANOVA mean squares; the other takes `[[T?]]` and fits the same two-way model by EM so that
/// missing cells can be tolerated. `iccMissingData`'s entry point carries a cognitive complexity
/// of 131 and had no oracle at all.
///
/// Hand a complete matrix to the second one and both answer the same question about the same
/// numbers. That makes them a differential, and it makes the disagreement legible.
///
/// ## The reference
///
/// Shrout, P. E. & Fleiss, J. L. (1979), "Intraclass correlations: uses in assessing rater
/// reliability", *Psychological Bulletin* 86(2), Table 1 — six subjects rated by four judges,
/// with published values ICC(1,1) = .17, ICC(2,1) = .29, ICC(3,1) = .71.
///
/// Published to two decimals, so the fixture is carried to full precision here, recomputed from
/// the mean squares rather than copied from the paper:
///
/// | | MS | |
/// |---|---|---|
/// | between subjects | 11.241666666666667 | |
/// | between raters | 32.486111111111114 | |
/// | residual | 1.0194444444444437 | |
/// | within subjects | 6.263888888888889 | |
///
/// giving ICC(1,1) = 0.1657417684054754, ICC(2,1) = 0.28976377952755905 and
/// ICC(3,1) = 0.7148407148407151 — which round to the published figures.
@Suite("Both ICC overloads against Shrout & Fleiss")
struct ICCAgreementOracleTests {

	/// Shrout & Fleiss (1979) Table 1.
	static let ratings: [[Double]] = [
		[9, 2, 5, 8],
		[6, 1, 3, 2],
		[8, 4, 6, 8],
		[7, 1, 2, 6],
		[10, 5, 6, 9],
		[6, 2, 4, 7]
	]

	/// The same matrix with every cell present, for the overload that accepts absences.
	static var complete: [[Double?]] { ratings.map { $0.map { Optional($0) } } }

	static let subjects = 6
	static let raters = 4

	// MARK: - 1. The ANOVA overload against the paper

	/// The published coefficients, to the precision the mean squares actually carry.
	@Test("The ANOVA overload reproduces the published coefficients", arguments: [
		("ICC(1,1)", ICCModel.oneWayRandom, ICCAgreement.absolute, 0.1657417684054754),
		("ICC(2,1) absolute", ICCModel.twoWayRandom, ICCAgreement.absolute, 0.28976377952755905),
		("ICC(2,1) consistency", ICCModel.twoWayRandom, ICCAgreement.consistency, 0.7148407148407151),
		("ICC(3,1) consistency", ICCModel.twoWayMixed, ICCAgreement.consistency, 0.7148407148407151)
	])
	func theAnovaOverloadMatchesThePaper(
		named: String,
		model: ICCModel,
		agreement: ICCAgreement,
		expected: Double
	) throws {
		let result = try icc(Self.ratings, model: model, agreement: agreement)
		#expect(abs(result.icc - expected) < 1e-12,
				"\(named): the paper gives \(expected), this returned \(result.icc)")
	}

	// MARK: - 2. The EM overload's one-way model

	/// ICC(1,1) is not ICC(2,1), and the EM overload returned the same number for both.
	///
	/// ## The defect this was written for
	///
	/// `iccMissingData`'s `.oneWayRandom` case used
	/// `sigma_s^2 / (sigma_s^2 + sigma_r^2 + sigma_e^2)` — character for character the
	/// `.twoWayRandom, .absolute` case directly beneath it. The two models cannot share a
	/// formula: a one-way design has no separable rater effect, so rater variation belongs to the
	/// *subject* term's complement, not merely to the denominator.
	///
	/// Writing the one-way decomposition in two-way components:
	///
	/// ```
	/// MSW  = MSE + sigma_r^2                 (within-subject MS, pooling raters into noise)
	/// sigma_s^2(one-way) = (MSR - MSW)/k = sigma_s^2 - sigma_r^2/k
	/// ```
	///
	/// so `ICC(1,1) = (sigma_s^2 - sigma_r^2/k) / ((sigma_s^2 - sigma_r^2/k) + sigma_r^2 +
	/// sigma_e^2)`. On the ANOVA components of the Shrout & Fleiss matrix that is
	/// **0.1657417684054754** — the published value exactly. The formula that shipped gives
	/// **0.28976**, the ICC(2,1) figure, overstating agreement by three quarters.
	///
	/// The subject term can come out negative when raters vary more than subjects, which is the
	/// one-way model's way of saying there is no subject signal; like every ANOVA variance
	/// estimate it is then read as zero.
	@Test("The EM overload's ICC(1,1) is not its ICC(2,1)")
	func theOneWayModelHasItsOwnFormula() throws {
		let oneWay = try icc(Self.complete, model: .oneWayRandom, agreement: .absolute)
		let twoWay = try icc(Self.complete, model: .twoWayRandom, agreement: .absolute)

		#expect(oneWay.icc != twoWay.icc,
				"""
				ICC(1,1) and ICC(2,1) both returned \(oneWay.icc) — a one-way design has no \
				separable rater effect, so they cannot share a formula
				""")

		// Recomputed here from the components the result itself reports, so the test does not
		// depend on the EM reaching any particular estimate — only on the formula applied to it.
		let s2 = oneWay.varianceSubjects
		let r2 = oneWay.varianceRaters
		let e2 = oneWay.varianceError
		let subjectTerm = Swift.max(0.0, s2 - r2 / Double(Self.raters))
		let denominator = subjectTerm + r2 + e2
		let expected = denominator > 0 ? subjectTerm / denominator : 0.0

		#expect(abs(oneWay.icc - expected) < 1e-12,
				"""
				from its own components the one-way coefficient is \(expected), \
				but \(oneWay.icc) was reported
				""")

		// And it must land below the two-way absolute figure on this data, which is the
		// direction the error ran.
		#expect(oneWay.icc < twoWay.icc,
				"on this matrix ICC(1,1) is the smaller; got \(oneWay.icc) against \(twoWay.icc)")
	}

	// MARK: - 3. What the two overloads still disagree about, and why

	/// The EM fit is maximum likelihood, so its components sit below the ANOVA ones.
	///
	/// This is **not** a defect, and pinning it is the point: the two overloads answer the same
	/// question with different estimators, and a caller who swaps `[[Double]]` for `[[Double?]]`
	/// on identical complete data gets a different number with nothing to indicate why.
	///
	/// EM maximises the likelihood, and maximum-likelihood variance components are biased
	/// downward by roughly the ratio of degrees of freedom to observations. Measured on this
	/// matrix, against the ANOVA (equivalently REML, for a balanced complete design) estimates:
	///
	/// | component | ANOVA | EM | ratio | expected shrinkage |
	/// |---|---|---|---|---|
	/// | subjects | 2.5556 | 2.0714 | 0.811 | `(n-1)/n` = 0.833 |
	/// | raters | 5.2444 | 3.8799 | 0.740 | `(k-1)/k` = 0.750 |
	/// | error | 1.0194 | 1.0897 | 1.069 | rises as the random effects shrink |
	///
	/// The shrinkage tracks the degrees of freedom, which is what identifies this as ML bias
	/// rather than a mistake. The bound below is deliberately loose — it exists to notice if the
	/// gap ever *changes*, not to certify its size.
	@Test("The EM overload is a maximum-likelihood fit, and sits below ANOVA by that much")
	func theEMFitIsMaximumLikelihoodAndSaysSo() throws {
		let em = try icc(Self.complete, model: .twoWayRandom, agreement: .absolute)

		// The ANOVA components of this matrix, derived in the suite documentation.
		let anovaSubjects = 2.555555555555556
		let anovaRaters = 5.244444444444445
		let anovaError = 1.0194444444444437

		#expect(em.converged, "the EM did not converge, so nothing below is about its estimate")

		// Downward on the random effects, upward on the residual — the ML signature.
		#expect(em.varianceSubjects < anovaSubjects,
				"ML shrinks the subject term; got \(em.varianceSubjects) against \(anovaSubjects)")
		#expect(em.varianceRaters < anovaRaters,
				"ML shrinks the rater term; got \(em.varianceRaters) against \(anovaRaters)")
		#expect(em.varianceError > anovaError,
				"the residual takes up the slack; got \(em.varianceError) against \(anovaError)")

		// And the shrinkage is of the size the degrees of freedom predict, not arbitrary.
		let subjectRatio = em.varianceSubjects / anovaSubjects
		let raterRatio = em.varianceRaters / anovaRaters
		#expect(subjectRatio > 0.7 && subjectRatio < 0.95,
				"subject shrinkage \(subjectRatio) is not the (n-1)/n = 0.833 the design predicts")
		#expect(raterRatio > 0.65 && raterRatio < 0.90,
				"rater shrinkage \(raterRatio) is not the (k-1)/k = 0.750 the design predicts")

		// The consequence for the caller, stated as a number rather than left implicit.
		let anova = try icc(Self.ratings, model: .twoWayMixed, agreement: .consistency).icc
		let viaEM = try icc(Self.complete, model: .twoWayMixed, agreement: .consistency).icc
		let gap = abs(anova - viaEM)
		#expect(gap > 0.01,
				"""
				the overloads agreed to \(gap) on complete data — if the EM has been changed to \
				REML this pin is stale and should be replaced with an equality
				""")
		#expect(gap < 0.15,
				"""
				the overloads now differ by \(gap) on identical complete data \
				(\(anova) from ANOVA, \(viaEM) from EM), which is more than ML bias accounts for
				""")
	}

	// MARK: - 3b. The iteration budget has to fit the algorithm

	/// Every single-cell deletion converges under the default budget.
	///
	/// ## The defect this was written for
	///
	/// `maxIterations` defaulted to **200**, and on this six-by-four matrix the EM needs up to
	/// **668** iterations with one cell missing and up to **1263** with two. Eighteen of the
	/// twenty-four single-cell deletions therefore expired, returning `converged: false`
	/// alongside an estimate that was in fact very nearly right — 0.2818 against the 0.2818 it
	/// reaches at iteration 243. A caller who does not inspect the flag cannot tell that result
	/// from a converged one, and one who does has no way to know the answer was already good.
	///
	/// Missing cells are the entire reason this overload exists, so a budget that expires on
	/// three quarters of the one-cell cases is the wrong budget rather than a hard problem.
	///
	/// Convergence on the variance components rather than on the likelihood was tried before
	/// raising it, on the theory that the criterion was at fault. It is **slower** — 904 and
	/// 1597 on the same two cases — so the budget is what needed changing. EM is simply slow on
	/// a crossed design.
	@Test("Every single-cell deletion converges under the default budget")
	func theDefaultBudgetCoversOrdinaryAbsences() throws {
		var expired: [String] = []
		var worst = 0

		for row in 0..<Self.subjects {
			for column in 0..<Self.raters {
				var withHole = Self.complete
				withHole[row][column] = nil
				let result = try icc(withHole, model: .twoWayRandom, agreement: .absolute)
				if result.converged {
					worst = Swift.max(worst, result.iterations)
				} else {
					expired.append("[\(row)][\(column)] at \(result.iterations)")
				}
			}
		}

		#expect(expired.isEmpty,
				"""
				\(expired.count) of \(Self.subjects * Self.raters) single-cell deletions hit the \
				iteration cap: \(expired.prefix(4).joined(separator: ", "))
				""")

		// The budget has to have room left, or it is a cap waiting to bind on the next matrix.
		#expect(worst < 5_000 / 2,
				"the slowest case took \(worst) iterations, which is more than half the budget")
	}

	// MARK: - 4. Absence is what the EM overload is for

	/// Removing a cell moves the estimate a little, not a lot.
	///
	/// The EM exists so that one missing rating does not cost a subject. A single absence out of
	/// twenty-four should perturb the coefficient, not transform it — and it must certainly not
	/// produce something outside `[-1, 1]` or fail to converge.
	@Test("A single missing cell perturbs the estimate rather than breaking it",
		  arguments: [(0, 0), (2, 1), (5, 3)])
	func oneAbsenceIsTolerated(row: Int, column: Int) throws {
		var withHole = Self.complete
		withHole[row][column] = nil

		let full = try icc(Self.complete, model: .twoWayRandom, agreement: .absolute)
		let holed = try icc(withHole, model: .twoWayRandom, agreement: .absolute)

		#expect(holed.converged, "dropping [\(row)][\(column)] stopped the EM converging")
		#expect(holed.observedCells == 23,
				"one cell was removed from 24, but \(holed.observedCells) are reported observed")
		#expect(holed.icc > -1.0 && holed.icc <= 1.0,
				"a correlation must lie in [-1, 1], got \(holed.icc)")
		#expect(abs(holed.icc - full.icc) < 0.15,
				"""
				removing one of twenty-four ratings moved the coefficient from \(full.icc) to \
				\(holed.icc)
				""")
	}
}

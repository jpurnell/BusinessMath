//
//  GibbsICCSweep.swift
//  BusinessMath
//
//  The Gibbs sweep both `bayesianICC` overloads run, over a flat list of observed cells.
//

import Foundation
import Numerics

/// The observed cells of a rating matrix, flattened once.
///
/// ## Why the cells are flattened
///
/// The two `bayesianICC` overloads carried the same six-step sweep twice, differing only in that
/// the missing-data one wrapped every cell access in `if let`. That is the wrong place for the
/// difference: the sweep runs `iterations × chains` times — tens of thousands of passes — and the
/// question "is this cell present" has the same answer on every one of them.
///
/// Asking it once, up front, removes it from the inner loop entirely and leaves one sweep instead
/// of two. A complete matrix flattens to every cell; an incomplete one to the cells it has. The
/// sweep cannot tell the difference and does not need to.
///
/// Parallel arrays rather than an array of tuples, because every pass reads all three in step and
/// a struct-of-arrays keeps each one contiguous.
///
/// - Note: Cells are stored in row-major order, which is the order both original sweeps visited
///   them in. That matters beyond tidiness: floating-point summation is not associative, so the
///   order fixes the bits of every accumulated residual, and the draws that follow consume the
///   generator in the same sequence. The refactor is therefore bit-identical to what it replaced,
///   which is what its tests assert.
internal struct ObservedCells<T: Real> {
	/// Row index of each observed cell.
	var subject: [Int]
	/// Column index of each observed cell.
	var rater: [Int]
	/// The rating itself.
	var value: [T]
	/// How many cells each subject contributes, indexed by row.
	var subjectCounts: [T]
	/// How many cells each rater contributes, indexed by column.
	var raterCounts: [T]
	/// Where each subject's run of cells begins, with a final entry at `count`.
	///
	/// Row-major flattening already groups a subject's cells together, so this is all that is
	/// needed to walk them: `subjectStart[i] ..< subjectStart[i + 1]`. That turns `s[i]` from a
	/// gather into a value hoisted out of the inner loop — which is the whole reason the offsets
	/// exist. Without them the sweep measured **27% slower** than the nested loops it replaced,
	/// because `s[cells.subject[c]]` is an indexed load on every cell where `s[i]` is a register.
	var subjectStart: [Int]

	/// The number of observed cells.
	var count: Int { value.count }

	/// Flattens a complete matrix: every cell is present.
	init(_ ratings: [[T]], subjects: Int, raters: Int) {
		let total = subjects * raters
		subject = []; subject.reserveCapacity(total)
		rater = []; rater.reserveCapacity(total)
		value = []; value.reserveCapacity(total)
		for i in 0..<subjects {
			for j in 0..<raters {
				subject.append(i)
				rater.append(j)
				value.append(ratings[i][j])
			}
		}
		subjectCounts = [T](repeating: T(raters), count: subjects)
		raterCounts = [T](repeating: T(subjects), count: raters)
		subjectStart = (0...subjects).map { $0 * raters }
	}

	/// Flattens a matrix with absences: only the cells that are there.
	init(_ ratings: [[T?]], subjects: Int, raters: Int) {
		subject = []; rater = []; value = []
		var perSubject = [Int](repeating: 0, count: subjects)
		var perRater = [Int](repeating: 0, count: raters)
		for i in 0..<subjects {
			for j in 0..<raters {
				guard let cell = ratings[i][j] else { continue }
				subject.append(i)
				rater.append(j)
				value.append(cell)
				perSubject[i] += 1
				perRater[j] += 1
			}
		}
		subjectCounts = perSubject.map { T($0) }
		raterCounts = perRater.map { T($0) }
		subjectStart = [0]
		subjectStart.reserveCapacity(subjects + 1)
		var running = 0
		for i in 0..<subjects {
			running += perSubject[i]
			subjectStart.append(running)
		}
	}
}

/// Runs every chain of the Gibbs sampler and summarises the posterior.
///
/// One implementation for both overloads. The model is
///
/// ```
/// x_ij = mu + s_i + r_j + e_ij
/// ```
///
/// with conjugate normal full conditionals for `mu`, `s` and `r`, and Inverse-Gamma ones for the
/// three variance components. Each sweep is six steps in a fixed order, and the order is
/// load-bearing twice over: Gibbs requires each draw to condition on the *current* value of
/// everything else, and the fixed order is also what makes a seeded run reproducible.
///
/// Four passes over the cell list per sweep — one for `mu`, one to accumulate each subject's
/// residual, one for each rater's, one for the error sum of squares — plus two short loops over
/// the effects themselves. Steps 2 and 3 cannot share a pass: the rater draws condition on the
/// subject effects *just drawn*, which is what distinguishes a Gibbs sweep from a joint update.
///
/// - Parameters:
///   - cells: The observed cells, flattened.
///   - subjects: Row count.
///   - raters: Column count.
///   - grandMean: Mean of the observed values, used to centre `mu` and to start each chain.
///   - initialSubjectVariance: Starting value for the between-subjects component.
///   - initialRaterVariance: Starting value for the between-raters component.
///   - initialErrorVariance: Starting value for the residual component.
///
///     Three values rather than one, because the two callers start from genuinely different
///     places and it matters. The complete-data overload has a two-way ANOVA available and uses
///     the method-of-moments estimates — `msError`, `(msSubjects − msError)/k`,
///     `(msRaters − msError)/n` — which start the chain near where it is going. The missing-data
///     overload cannot form those mean squares, so it splits the total variance three ways as a
///     heuristic. Collapsing them to one shared starting value was tried and discarded: it
///     changed every draw of the complete-data sampler, which is how it was noticed.
///
///     Each is scaled by `1 + chain` so several chains explore from different places, which is
///     what makes R-hat meaningful.
///   - model: Which ICC the draws are converted to.
///   - subjectPrior: Inverse-Gamma prior on the between-subjects variance.
///   - raterPrior: Inverse-Gamma prior on the between-raters variance.
///   - errorPrior: Inverse-Gamma prior on the residual variance.
///   - config: Iterations, burn-in, thinning, chain count and seed.
/// - Returns: The summarised posterior.
/// - Throws: From ``summarisePosterior(allChainSigmaS:allChainSigmaR:allChainSigmaE:allChainICC:)``
///   when burn-in and thinning leave no draws.
internal func gibbsICCPosterior<T: Real>(
	cells: ObservedCells<T>,
	subjects n: Int,
	raters k: Int,
	grandMean: T,
	initialSubjectVariance: T,
	initialRaterVariance: T,
	initialErrorVariance: T,
	model: ICCModel,
	subjectPrior: VariancePrior<T>,
	raterPrior: VariancePrior<T>,
	errorPrior: VariancePrior<T>,
	config: GibbsConfig<T>
) throws -> BayesianICCResult<T> where T: BinaryFloatingPoint {

	let nT = T(n)
	let kT = T(k)
	let observedT = T(cells.count)

	var allChainSigmaS: [[T]] = []
	var allChainSigmaR: [[T]] = []
	var allChainSigmaE: [[T]] = []
	var allChainICC: [[T]] = []

	for chain in 0..<config.chains {
		// One stream per chain. Chains are offset by a large odd stride so that
		// `chains: 4` explores four different sequences rather than four copies of one.
		var rng = GibbsRNG(seed: config.seed.map { $0 &+ UInt64(chain) &* 999_983 })

		var mu = grandMean
		var s = [T](repeating: T.zero, count: n)
		var r = [T](repeating: T.zero, count: k)
		var sigmaS = initialSubjectVariance * T(1 + chain)
		var sigmaR = initialRaterVariance * T(1 + chain)
		var sigmaE = initialErrorVariance * T(1 + chain)

		var chainSigmaS: [T] = []
		var chainSigmaR: [T] = []
		var chainSigmaE: [T] = []
		var chainICC: [T] = []

		// Scratch reused across every sweep, so the loop allocates nothing.
		var subjectResidual = [T](repeating: T.zero, count: n)
		var raterResidual = [T](repeating: T.zero, count: k)

		let tauSquared: T = T(1_000_000) // vague prior variance on mu

		for iter in 0..<config.iterations {
			// --- 1. Sample mu | rest ---
			var residualSum = T.zero
			for i in 0..<n {
				let si = s[i]
				for c in cells.subjectStart[i]..<cells.subjectStart[i + 1] {
					residualSum += cells.value[c] - si - r[cells.rater[c]]
				}
			}
			let muPostVar = T(1) / (observedT / sigmaE + T(1) / tauSquared)
			let muPostMean = muPostVar * (residualSum / sigmaE + grandMean / tauSquared)

			let (muU1, muU2) = rng.nextPair()
			mu = distributionNormal(mean: muPostMean, variance: muPostVar, muU1, muU2)

			// --- 2. Sample s_i | rest ---
			for i in 0..<n {
				var sum = T.zero
				for c in cells.subjectStart[i]..<cells.subjectStart[i + 1] {
					sum += cells.value[c] - mu - r[cells.rater[c]]
				}
				subjectResidual[i] = sum
			}
			for i in 0..<n {
				let ki = cells.subjectCounts[i]
				// A subject with no ratings keeps an effect of zero and, crucially, consumes no
				// randomness — the stream has to stay aligned with the complete-data case.
				guard ki > T.zero else { continue }
				let vPost = T(1) / (ki / sigmaE + T(1) / sigmaS)
				let sPost = vPost * subjectResidual[i] / sigmaE
				let (u1, u2) = rng.nextPair()
				s[i] = distributionNormal(mean: sPost, variance: vPost, u1, u2)
			}

			// --- 3. Sample r_j | rest ---
			//
			// A second pass rather than an extension of the first: these condition on the
			// subject effects drawn immediately above, which is what makes this Gibbs.
			for j in 0..<k { raterResidual[j] = T.zero }
			for i in 0..<n {
				// `mu + s[i]` is *not* factored out, tempting though it is: subtraction is not
				// associative in floating point, so `x - (mu + s_i)` and `x - mu - s_i` differ in
				// the last bit and the draws downstream diverge from there. Hoisting the load of
				// `s[i]` is free; rearranging the arithmetic is not.
				let si = s[i]
				for c in cells.subjectStart[i]..<cells.subjectStart[i + 1] {
					raterResidual[cells.rater[c]] += cells.value[c] - mu - si
				}
			}
			for j in 0..<k {
				let nj = cells.raterCounts[j]
				guard nj > T.zero else { continue }
				let vPost = T(1) / (nj / sigmaE + T(1) / sigmaR)
				let rPost = vPost * raterResidual[j] / sigmaE
				let (u1, u2) = rng.nextPair()
				r[j] = distributionNormal(mean: rPost, variance: vPost, u1, u2)
			}

			// --- 4. Sample sigma_s^2 | s ---
			var ssSub = T.zero
			for i in 0..<n { ssSub += s[i] * s[i] }
			sigmaS = sampledVariance(
				sumOfSquares: ssSub, count: nT,
				prior: subjectPrior, current: sigmaS, using: &rng
			)

			// --- 5. Sample sigma_r^2 | r ---
			var ssRat = T.zero
			for j in 0..<k { ssRat += r[j] * r[j] }
			sigmaR = sampledVariance(
				sumOfSquares: ssRat, count: kT,
				prior: raterPrior, current: sigmaR, using: &rng
			)

			// --- 6. Sample sigma_e^2 | rest ---
			var ssErr = T.zero
			for i in 0..<n {
				let si = s[i]
				for c in cells.subjectStart[i]..<cells.subjectStart[i + 1] {
					let residual = cells.value[c] - mu - si - r[cells.rater[c]]
					ssErr += residual * residual
				}
			}
			sigmaE = sampledVariance(
				sumOfSquares: ssErr, count: observedT,
				prior: errorPrior, current: sigmaE, using: &rng
			)

			// --- Collect post-burn-in samples ---
			if iter >= config.burnIn && (iter - config.burnIn) % config.thinning == 0 {
				chainSigmaS.append(sigmaS)
				chainSigmaR.append(sigmaR)
				chainSigmaE.append(sigmaE)
				chainICC.append(
					iccFromVarianceComponents(
						model: model,
						agreement: .absolute,
						sigmaS2: sigmaS,
						sigmaR2: sigmaR,
						sigmaE2: sigmaE,
						raters: kT
					)
				)
			}
		}

		allChainSigmaS.append(chainSigmaS)
		allChainSigmaR.append(chainSigmaR)
		allChainSigmaE.append(chainSigmaE)
		allChainICC.append(chainICC)
	}

	return try summarisePosterior(
		allChainSigmaS: allChainSigmaS,
		allChainSigmaR: allChainSigmaR,
		allChainSigmaE: allChainSigmaE,
		allChainICC: allChainICC
	)
}

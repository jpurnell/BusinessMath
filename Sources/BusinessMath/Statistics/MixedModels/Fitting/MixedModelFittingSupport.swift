//
//  MixedModelFittingSupport.swift
//  BusinessMath
//
//  The parts `fitGeneralLME` and `fitRandomSlope` were each keeping their own copy of.
//

import Foundation
import Numerics

// MARK: - Scalars

/// Absolute value, spelled out rather than taken from `abs`.
///
/// The package declares `public func abs<U: ModelUnit>(_ operand: Expr<U>)` in
/// `Expr.swift`, and an overload of that name in scope makes `abs(x)` on a generic `T: Real`
/// an overload-resolution question rather than an obvious one. Both fitters had already
/// arrived at this workaround independently and written it out identically; it is kept
/// because it works and shared because there is no reason for two of it.
internal func absVal<T: Real>(_ x: T) -> T {
	x < T.zero ? -x : x
}

/// Whether a scalar parameter has settled, on a combined absolute and relative criterion.
///
/// Absolute alone cannot serve a variance component, whose scale is whatever the data's
/// units make it; relative alone divides by zero at the origin. Taking either as sufficient
/// is what the two conditions here are for, and the `maximum(_:.ulpOfOne)` is what keeps the
/// relative branch finite when the old value is zero.
///
/// ## Why the two thresholds are separate
///
/// They were one number until 2026-09-19, and that coupling was a latent defect rather than
/// a simplification. A variance component approaching the zero boundary can never satisfy
/// the relative branch — `absDiff / |old|` does not shrink as `old` goes to zero — so the
/// absolute branch is the only thing that ever lets such a model converge. Driving it from
/// `tolerance` meant that tightening the *relative* test to buy accuracy also tightened the
/// absolute floor, and a fit jittering just above zero stopped converging: no less settled
/// than before, only measured against a smaller ruler.
///
/// `fitGeneralLME` hit this the moment its tolerance moved from 1e-8 to 1e-9. A model with
/// no group effect at all — the case where `tau^2` is genuinely zero — ran its full
/// iteration budget and reported failure on data it had been fitting correctly.
///
/// The floor therefore stays at 1e-8, which is exactly the value it had when it was welded
/// to `tolerance`. No model that converged before this change can stop converging because of
/// it, and the relative test is now free to move on its own.
///
/// - Parameters:
///   - old: The previous iterate.
///   - new: The current iterate.
///   - tolerance: The threshold on the **relative** difference.
///   - absoluteFloor: The threshold on the **absolute** difference, below which a parameter
///     counts as settled whatever its relative change. Defaults to 1e-8; raise it only with
///     a measurement, since it is the last thing standing between a boundary case and a
///     spurious non-convergence.
/// - Returns: `true` when either criterion is met.
internal func paramHasConverged<T: Real>(
	old: T, new: T, tolerance: T,
	absoluteFloor: T = T(1) / T(100_000_000)
) -> Bool {
	if new == T.zero && old == T.zero { return true }
	let absDiff = absVal(new - old)
	if absDiff < absoluteFloor { return true }
	let relDiff = absDiff / T.maximum(absVal(old), T.ulpOfOne)
	return relDiff < tolerance
}

// MARK: - Starting values

/// Ordinary least squares, which both fitters use to start from.
///
/// Forms `X'X` and `X'y` in one pass and solves. No random-effects structure enters here —
/// it is the same estimate whatever `Z` turns out to be, which is why the two fitters'
/// copies of this were byte-identical apart from the function name.
///
/// - Parameters:
///   - xData: The `N × p` fixed-effects design.
///   - y: The `N` responses.
///   - N: Row count.
///   - p: Fixed-effect count.
/// - Returns: The OLS estimate of β.
/// - Throws: Whatever ``DenseMatrix/solve(_:)`` throws when `X'X` is singular, which for a
///   design matrix means collinear columns.
/// - Complexity: O(N·p² + p³).
internal func mixedModelOLSEstimate<T: Real & Sendable>(
	xData: [[T]], y: [T], N: Int, p: Int
) throws -> [T] where T: BinaryFloatingPoint {
	var xtx = Array(repeating: Array(repeating: T.zero, count: p), count: p)
	var xty = Array(repeating: T.zero, count: p)
	for i in 0..<N {
		for j in 0..<p {
			xty[j] += xData[i][j] * y[i]
			for k in 0..<p {
				xtx[j][k] += xData[i][j] * xData[i][k]
			}
		}
	}
	let xtxMat = try DenseMatrix(xtx)
	return try xtxMat.solve(xty)
}

/// The moment-based starting values both fitters derive before iterating.
///
/// A one-way ANOVA decomposition of the OLS residuals: the within-group mean square is a
/// first estimate of the residual variance, and the between-group mean square carries the
/// group-level variation the random effects will have to account for. Neither fitter is
/// sensitive to these being good — EM and then AI-REML move off them — but both are
/// sensitive to them being *finite and positive*, which is what the floor at `.ulpOfOne`
/// and the guarded divisions are for.
///
/// What the two fitters do next is where they part: the general model spreads the
/// between-group variance across a diagonal `G`, the random-slope model assigns it to
/// `g00`. That divergence is left at the call sites.
///
/// - Parameters:
///   - xData: The `N × p` fixed-effects design.
///   - y: The `N` responses.
///   - groupIdx: Row indices for each of the `m` groups.
///   - N: Row count.
///   - p: Fixed-effect count.
///   - m: Group count.
/// - Returns: The OLS estimate and residuals, a positive residual-variance estimate, the
///   between-group mean square, and the average group size.
/// - Throws: From ``mixedModelOLSEstimate(xData:y:N:p:)``.
internal func mixedModelStartingValues<T: Real & Sendable>(
	xData: [[T]], y: [T], groupIdx: [[Int]], N: Int, p: Int, m: Int
) throws -> (beta: [T], residuals: [T], sigmaE2: T, msBetween: T, nBar: T)
where T: BinaryFloatingPoint {
	let olsBeta = try mixedModelOLSEstimate(xData: xData, y: y, N: N, p: p)
	var residOLS = Array(repeating: T.zero, count: N)
	for i in 0..<N {
		var fitted = T.zero
		for j in 0..<p { fitted += xData[i][j] * olsBeta[j] }
		residOLS[i] = y[i] - fitted
	}

	// One-way ANOVA decomposition of those residuals.
	var ssWithin = T.zero
	var ssBetween = T.zero
	let grandMeanResid = residOLS.reduce(T.zero, +) / T(N)
	for g in 0..<m {
		let indices = groupIdx[g]
		let nig = T(indices.count)
		let groupMean = indices.reduce(T.zero) { $0 + residOLS[$1] } / nig
		ssBetween += nig * (groupMean - grandMeanResid) * (groupMean - grandMeanResid)
		for idx in indices {
			let diff = residOLS[idx] - groupMean
			ssWithin += diff * diff
		}
	}

	let dfWithin = T(N - m)
	var sigmaE2 = dfWithin > T.zero ? ssWithin / dfWithin : T(1)
	// A zero starting variance divides by zero in the very first `V_i`, so the floor is
	// load-bearing rather than defensive.
	sigmaE2 = T.maximum(sigmaE2, T.ulpOfOne)

	let msBetween = T(m - 1) > T.zero ? ssBetween / T(m - 1) : T.zero
	let nBar = T(N) / T(m)

	return (olsBeta, residOLS, sigmaE2, msBetween, nBar)
}

import Foundation
import Numerics

// MARK: - Standardized Residuals

/// Computes standardized residuals from a random-intercept LME model.
///
/// Standardized residuals are the conditional residuals
/// (y - X*beta - Z*u) divided by the square root of the residual
/// variance (sigma_e). Values far from zero suggest potential outliers.
///
/// - Parameter result: A fitted ``RandomInterceptResult``.
/// - Returns: An array of standardized residuals, one per observation.
///   Returns an empty array if `varianceResidual` is not positive.
///
/// ```swift
/// let stdResid = standardizedResiduals(result)
/// // Values approximately N(0, 1) if model is well-specified
/// ```
public func standardizedResiduals<T: Real>(
	_ result: RandomInterceptResult<T>
) -> [T] where T: BinaryFloatingPoint {
	guard result.varianceResidual > T.zero else { return [] }
	let scale = T.sqrt(result.varianceResidual)
	return result.residuals.map { $0 / scale }
}

// MARK: - Pearson Residuals

/// Computes Pearson (marginal) residuals from a random-intercept LME model.
///
/// Pearson residuals are the marginal residuals (y - X*beta) divided
/// by the square root of the total (marginal) variance
/// (sigma_u² + sigma_e²). They standardize residuals under the
/// marginal model, ignoring group-level information.
///
/// - Parameter result: A fitted ``RandomInterceptResult``.
/// - Returns: An array of Pearson residuals, one per observation.
///   Returns an empty array if total variance is not positive.
///
/// ```swift
/// let pResid = pearsonResiduals(result)
/// ```
public func pearsonResiduals<T: Real>(
	_ result: RandomInterceptResult<T>
) -> [T] where T: BinaryFloatingPoint {
	let totalVar = result.varianceRandom + result.varianceResidual
	guard totalVar > T.zero else { return [] }
	let scale = T.sqrt(totalVar)
	return result.marginalResiduals.map { $0 / scale }
}

// MARK: - QQ-Plot Data

/// A single point on a QQ (quantile-quantile) plot.
///
/// Pairs a theoretical normal quantile with the corresponding
/// observed (sorted) residual value.
public struct QQPoint<T: Real & Sendable>: Sendable where T: BinaryFloatingPoint {
	/// The theoretical quantile from the standard normal distribution.
	public let theoretical: T
	/// The observed (sorted) residual value.
	public let observed: T

	/// Creates a QQ point.
	///
	/// - Parameters:
	///   - theoretical: Theoretical normal quantile.
	///   - observed: Observed residual value.
	public init(theoretical: T, observed: T) {
		self.theoretical = theoretical
		self.observed = observed
	}
}

/// Generates QQ-plot data for assessing normality of residuals.
///
/// Sorts the residuals in ascending order and pairs each with a
/// theoretical normal quantile using the Blom plotting position:
/// `p_i = (i - 0.375) / (n + 0.25)`.
///
/// If the residuals are normally distributed, the resulting points
/// should fall approximately along a straight line.
///
/// - Parameter residuals: An array of residual values to assess.
/// - Returns: An array of ``QQPoint`` values sorted by theoretical quantile.
///   Returns an empty array if `residuals` is empty.
///
/// ```swift
/// let qq = qqNormalData(standardizedResiduals(result))
/// // Plot qq.map { ($0.theoretical, $0.observed) }
/// ```
public func qqNormalData<T: Real>(
	_ residuals: [T]
) -> [QQPoint<T>] where T: BinaryFloatingPoint {
	let n = residuals.count
	guard n > 0 else { return [] }

	let sorted = residuals.sorted()
	let nT = T(n)

	return sorted.enumerated().map { i, observed in
		// Blom plotting position (1-indexed rank)
		let rank = T(i + 1)
		let p = (rank - T(0.375)) / (nT + T(0.25))
		let theoretical = inverseNormalCDF(p: p)
		return QQPoint(theoretical: theoretical, observed: observed)
	}
}

// MARK: - Group Influence (Cook's D analog)

/// Computes an approximate group-level influence measure analogous to Cook's D.
///
/// For each group g, the influence is:
/// ```
/// D_g = n_g * (mean_marginal_residual_g)² / (p * (sigma_u² + sigma_e²))
/// ```
/// where n_g is the group size, p is the number of fixed-effects parameters,
/// and the marginal residuals are y - X*beta.
///
/// Large values indicate groups whose removal would substantially change
/// the fixed-effects estimates.
///
/// - Parameters:
///   - result: A fitted ``RandomInterceptResult``.
///   - grouping: The ``GroupingFactor`` used to fit the model.
/// - Returns: An array of influence values, one per group.
///   Returns an empty array if the denominator is not positive.
///
/// ```swift
/// let influence = groupInfluence(result, grouping: grouping)
/// // Flag groups where influence > 4 / groupCount
/// ```
public func groupInfluence<T: Real>(
	_ result: RandomInterceptResult<T>,
	grouping: GroupingFactor
) -> [T] where T: BinaryFloatingPoint {
	let totalVar = result.varianceRandom + result.varianceResidual
	let p = T(result.fixedEffectsCount)
	let denominator = p * totalVar
	guard denominator > T.zero else { return [] }

	return (0..<grouping.groupCount).map { g in
		let indices = grouping.groupIndices[g]
		let nG = T(indices.count)
		guard nG > T.zero else { return T.zero }
		let sumMargResid = indices.reduce(T.zero) { $0 + result.marginalResiduals[$1] }
		let meanMargResid = sumMargResid / nG
		return nG * meanMargResid * meanMargResid / denominator
	}
}

// MARK: - Nakagawa R²

/// Marginal and conditional R-squared for a mixed-effects model.
///
/// Following Nakagawa & Schielzeth (2013):
/// - **Marginal R²** (`R²_m`): proportion of variance explained by
///   fixed effects alone.
/// - **Conditional R²** (`R²_c`): proportion of variance explained by
///   both fixed and random effects.
public struct MixedModelR2<T: Real & Sendable>: Sendable where T: BinaryFloatingPoint {
	/// Marginal R²: variance explained by fixed effects.
	public let marginal: T
	/// Conditional R²: variance explained by fixed + random effects.
	public let conditional: T

	/// Creates a mixed-model R² result.
	///
	/// - Parameters:
	///   - marginal: Marginal R² value.
	///   - conditional: Conditional R² value.
	public init(marginal: T, conditional: T) {
		self.marginal = marginal
		self.conditional = conditional
	}
}

/// Computes Nakagawa & Schielzeth R² for a random-intercept model.
///
/// - **R²_m** = Var(X*beta_fixed) / (Var(X*beta_fixed) + sigma_u² + sigma_e²)
/// - **R²_c** = (Var(X*beta_fixed) + sigma_u²) / (Var(X*beta_fixed) + sigma_u² + sigma_e²)
///
/// where `X*beta_fixed` is the fixed-effects prediction (fittedValues minus
/// group-level random effects).
///
/// - Parameter result: A fitted ``RandomInterceptResult``.
/// - Returns: A ``MixedModelR2`` with marginal and conditional values.
///   Returns (0, 0) if total denominator is not positive.
///
/// ```swift
/// let r2 = nakagawaR2(result)
/// print("Marginal R² = \(r2.marginal), Conditional R² = \(r2.conditional)")
/// ```
public func nakagawaR2<T: Real>(
	_ result: RandomInterceptResult<T>
) -> MixedModelR2<T> where T: BinaryFloatingPoint {
	let n = result.observations
	guard n > 0 else { return MixedModelR2(marginal: T.zero, conditional: T.zero) }

	// Fixed-effects fitted values: X*beta for each observation.
	// Since y = X*beta + marginalResidual and y = fittedValues + residuals,
	// X*beta = fittedValues + residuals - marginalResiduals.
	let fixedFitted = (0..<n).map { i in
		result.fittedValues[i] + result.residuals[i] - result.marginalResiduals[i]
	}

	let varFixed = variance(fixedFitted, .population)
	let sigmaU2 = result.varianceRandom
	let sigmaE2 = result.varianceResidual
	let totalDenom = varFixed + sigmaU2 + sigmaE2

	guard totalDenom > T.zero else { return MixedModelR2(marginal: T.zero, conditional: T.zero) }

	let marginal = varFixed / totalDenom
	let conditional = (varFixed + sigmaU2) / totalDenom

	return MixedModelR2(marginal: marginal, conditional: conditional)
}

// MARK: - Within-Group Autocorrelation

/// Computes the average lag-1 autocorrelation of residuals within groups.
///
/// For each group with at least 2 observations, computes the Pearson
/// lag-1 autocorrelation of the residual series. Returns the average
/// across all eligible groups. Groups with fewer than 2 observations
/// are skipped.
///
/// A value near zero suggests no temporal dependence within groups.
/// Positive values may indicate missing autoregressive structure.
///
/// - Parameters:
///   - residuals: Residual values, one per observation.
///   - grouping: The ``GroupingFactor`` defining group membership.
/// - Returns: The average lag-1 autocorrelation across groups.
///   Returns zero if no groups have at least 2 observations.
///
/// ```swift
/// let rho = withinGroupAutocorrelation(
///     residuals: result.residuals, grouping: grouping
/// )
/// ```
public func withinGroupAutocorrelation<T: Real>(
	residuals: [T], grouping: GroupingFactor
) -> T where T: BinaryFloatingPoint {
	var totalCorr = T.zero
	var eligibleGroups = 0

	for g in 0..<grouping.groupCount {
		let indices = grouping.groupIndices[g]
		guard indices.count >= 2 else { continue }

		// Extract group residuals in observation order
		let groupResid = indices.map { residuals[$0] }
		let nG = groupResid.count

		// Compute mean for this group's residuals
		let groupMean = groupResid.reduce(T.zero, +) / T(nG)

		// Lag-1 autocorrelation
		var numerator = T.zero
		var denominator = T.zero
		for i in 0..<nG {
			let centered = groupResid[i] - groupMean
			denominator += centered * centered
			if i > 0 {
				let prevCentered = groupResid[i - 1] - groupMean
				numerator += centered * prevCentered
			}
		}

		guard denominator > T.zero else { continue }
		totalCorr += numerator / denominator
		eligibleGroups += 1
	}

	guard eligibleGroups > 0 else { return T.zero }
	return totalCorr / T(eligibleGroups)
}

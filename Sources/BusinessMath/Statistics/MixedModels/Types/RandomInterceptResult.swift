import Foundation
import Numerics

/// Result of fitting a random-intercept LME model via REML.
///
/// Contains fixed-effects estimates, variance components, BLUPs,
/// diagnostics, and model fit statistics.
public struct RandomInterceptResult<T: Real & Sendable>: Sendable where T: BinaryFloatingPoint {
	/// Fixed-effects coefficients (beta), including intercept at index 0.
	public let beta: [T]

	/// Standard errors of fixed-effects coefficients.
	public let standardErrors: [T]

	/// t-statistics for fixed effects (beta / SE).
	public let tStatistics: [T]

	/// p-values for fixed effects (two-tailed).
	public let pValues: [T]

	/// Random-effects variance component (sigma_u²).
	public let varianceRandom: T

	/// Residual variance component (sigma_e²).
	public let varianceResidual: T

	/// Total variance (sigma_u² + sigma_e²).
	public var varianceTotal: T { varianceRandom + varianceResidual }

	/// Intraclass correlation coefficient: sigma_u² / (sigma_u² + sigma_e²).
	public let icc: T

	/// REML log-likelihood at convergence.
	public let remlLogLikelihood: T

	/// AIC = -2 * logLik + 2 * k.
	public let aic: T

	/// BIC = -2 * logLik + k * log(N).
	public let bic: T

	/// Predicted random effects (BLUPs) for each group.
	public let randomEffects: [T]

	/// Residuals: y - X*beta_hat - Z*u_hat.
	public let residuals: [T]

	/// Marginal residuals: y - X*beta_hat.
	public let marginalResiduals: [T]

	/// Fitted values: X*beta_hat + Z*u_hat.
	public let fittedValues: [T]

	/// Number of observations.
	public let observations: Int

	/// Number of groups.
	public let groups: Int

	/// Number of fixed-effects parameters (including intercept).
	public let fixedEffectsCount: Int

	/// Number of Fisher scoring iterations to convergence.
	public let iterations: Int

	/// Whether the algorithm converged within the iteration limit.
	public let converged: Bool
}

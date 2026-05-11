import Foundation
import Numerics

/// Result of fitting a random intercept-and-slope LME model via REML.
///
/// Contains fixed-effects estimates, variance components (including the
/// random-effects covariance matrix G), BLUPs for both intercepts and slopes,
/// diagnostics, and model fit statistics.
///
/// The random-effects covariance matrix is:
/// ```
/// G = [[varianceIntercept,          covarianceInterceptSlope],
///      [covarianceInterceptSlope,    varianceSlope           ]]
/// ```
public struct RandomSlopeResult<T: Real & Sendable>: Sendable where T: BinaryFloatingPoint {
	/// Fixed-effects coefficients (beta).
	public let beta: [T]

	/// Standard errors of fixed-effects coefficients.
	public let standardErrors: [T]

	/// t-statistics for fixed effects (beta / SE).
	public let tStatistics: [T]

	/// p-values for fixed effects (two-tailed).
	public let pValues: [T]

	/// Random-intercept variance component (sigma_u0 squared).
	public let varianceIntercept: T

	/// Random-slope variance component (sigma_u1 squared).
	public let varianceSlope: T

	/// Covariance between random intercept and slope (sigma_u01).
	public let covarianceInterceptSlope: T

	/// Correlation between random intercept and slope:
	/// rho = sigma_u01 / sqrt(sigma_u0 squared * sigma_u1 squared).
	public let correlationInterceptSlope: T

	/// Residual variance component (sigma_e squared).
	public let varianceResidual: T

	/// REML log-likelihood at convergence.
	public let remlLogLikelihood: T

	/// AIC = -2 * logLik + 2 * k.
	public let aic: T

	/// BIC = -2 * logLik + k * log(N).
	public let bic: T

	/// Predicted random intercepts (BLUPs) for each group.
	public let randomIntercepts: [T]

	/// Predicted random slopes (BLUPs) for each group.
	public let randomSlopes: [T]

	/// Conditional residuals: y - X*beta - Z*u_hat.
	public let residuals: [T]

	/// Marginal residuals: y - X*beta.
	public let marginalResiduals: [T]

	/// Fitted values: X*beta + Z*u_hat.
	public let fittedValues: [T]

	/// Number of observations.
	public let observations: Int

	/// Number of groups.
	public let groups: Int

	/// Number of fixed-effects parameters.
	public let fixedEffectsCount: Int

	/// Number of Fisher scoring iterations to convergence.
	public let iterations: Int

	/// Whether the algorithm converged within the iteration limit.
	public let converged: Bool
}

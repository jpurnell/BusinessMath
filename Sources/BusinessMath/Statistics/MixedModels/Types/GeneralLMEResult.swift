import Foundation
import Numerics

/// Result of fitting a general linear mixed-effects model via REML.
///
/// Contains fixed-effects estimates, the random-effects covariance matrix G,
/// residual variance, BLUPs for random effects, diagnostics, and model fit
/// statistics.
///
/// The random-effects covariance matrix ``gMatrix`` is r × r, where r is the
/// number of random effects per group. For a random intercept + slope model
/// (r = 2), G is:
/// ```
/// G = [[σ²_u0,   σ_u01 ],
///      [σ_u01,   σ²_u1 ]]
/// ```
public struct GeneralLMEResult<T: Real & Sendable>: Sendable where T: BinaryFloatingPoint {
	/// Fixed-effects coefficients (beta), length p.
	public let beta: [T]

	/// Standard errors of fixed-effects coefficients, length p.
	public let standardErrors: [T]

	/// t-statistics for fixed effects (beta / SE), length p.
	public let tStatistics: [T]

	/// p-values for fixed effects (two-tailed), length p.
	public let pValues: [T]

	/// Random-effects covariance matrix G (r × r).
	public let gMatrix: DenseMatrix<T>

	/// Residual variance component (σ²_e).
	public let varianceResidual: T

	/// REML log-likelihood at convergence.
	public let remlLogLikelihood: T

	/// AIC = -2 * logLik + 2 * k.
	public let aic: T

	/// BIC = -2 * logLik + k * log(N).
	public let bic: T

	/// BLUPs for random effects: m × r matrix, where row g contains
	/// the predicted random effects for group g.
	public let randomEffects: DenseMatrix<T>

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

	/// Number of fixed-effects parameters (p).
	public let fixedEffectsCount: Int

	/// Number of random effects per group (r).
	public let randomEffectsPerGroup: Int

	/// Number of EM / scoring iterations to convergence.
	public let iterations: Int

	/// Whether the algorithm converged within the iteration limit.
	public let converged: Bool
}

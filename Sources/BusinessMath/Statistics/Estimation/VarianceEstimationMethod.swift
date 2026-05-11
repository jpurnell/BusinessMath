import Foundation

/// Method used to estimate variance components in mixed-effects models.
///
/// Variance component estimation partitions total variability into between-group
/// and within-group components. The choice of method affects how these components
/// are estimated, particularly for unbalanced designs.
///
/// ## Topics
///
/// ### Methods
/// - ``methodOfMoments``
/// - ``reml``
public enum VarianceEstimationMethod: Sendable {
	/// Method of moments (ANOVA-based) estimation.
	///
	/// Uses mean squares from one-way ANOVA to estimate variance components.
	/// Simple and fast, but can produce negative between-group variance estimates
	/// for unbalanced designs, which are then truncated to zero.
	case methodOfMoments

	/// Restricted maximum likelihood estimation.
	///
	/// Iteratively maximises the restricted log-likelihood using Fisher scoring.
	/// Produces non-negative variance estimates by construction and accounts
	/// properly for unbalanced designs. Preferred when group sizes differ or
	/// when method-of-moments produces boundary (zero) estimates.
	case reml
}

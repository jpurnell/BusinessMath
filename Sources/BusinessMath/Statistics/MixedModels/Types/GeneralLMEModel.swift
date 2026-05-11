import Foundation
import Numerics

/// General linear mixed-effects model specification.
///
/// The model is:
/// ```
/// y = Xβ + Zu + ε
/// ```
/// where `u ~ N(0, G)` and `ε ~ N(0, σ²I)`.
///
/// The user provides:
/// - `X`: fixed-effects design matrix (N × p)
/// - `Z`: random-effects design matrix storing per-observation covariates (N × r),
///   where r = ``randomEffectsPerGroup``. Each row contains the random-effects
///   covariates for that observation (e.g., `[1, x]` for intercept + slope).
/// - `response`: y vector (N)
/// - `grouping`: ``GroupingFactor``
/// - `randomEffectsPerGroup`: r, the number of random-effect columns per group
///
/// The full block-diagonal Z is not stored; only the non-zero blocks are kept.
/// For group i with n_i observations, Z_i is the n_i × r submatrix of
/// ``randomEffectsDesign`` corresponding to observations in group i.
///
/// Example:
/// ```swift
/// // Random intercept + slope model with 2 groups
/// let X = try DenseMatrix([[1.0, 2.0], [1.0, 3.0], [1.0, 2.0], [1.0, 3.0]])
/// let Z = try DenseMatrix([[1.0, 2.0], [1.0, 3.0], [1.0, 2.0], [1.0, 3.0]])
/// let y = [10.0, 12.0, 20.0, 22.0]
/// let groups = try GroupingFactor([0, 0, 1, 1])
/// let model = GeneralLMEModel(
///     fixedEffects: X, randomEffectsDesign: Z,
///     response: y, grouping: groups, randomEffectsPerGroup: 2)
/// let result = try fitGeneralLME(model)
/// ```
public struct GeneralLMEModel<T: Real & Sendable>: Sendable where T: BinaryFloatingPoint {
	/// Fixed-effects design matrix X (N × p). Include an intercept column
	/// (all 1s) as the first column if desired.
	public let fixedEffects: DenseMatrix<T>

	/// Random-effects design matrix (N × r), where r = ``randomEffectsPerGroup``.
	/// Each row i contains the random-effects covariates for observation i.
	/// For group g, the submatrix Z_g is formed from rows belonging to that group.
	public let randomEffectsDesign: DenseMatrix<T>

	/// Response vector y (length N).
	public let response: [T]

	/// Grouping factor assigning observations to groups.
	public let grouping: GroupingFactor

	/// Number of random effects per group (r). For example, 1 for a random
	/// intercept model, 2 for random intercept + slope, etc.
	public let randomEffectsPerGroup: Int

	/// Creates a general linear mixed-effects model specification.
	///
	/// - Parameters:
	///   - fixedEffects: Design matrix X (N × p). Include an intercept column
	///     (all 1s) as the first column if desired.
	///   - randomEffectsDesign: Random-effects design matrix (N × r).
	///   - response: Response vector of length N.
	///   - grouping: Grouping factor of length N.
	///   - randomEffectsPerGroup: Number of random-effect columns per group (r).
	public init(
		fixedEffects: DenseMatrix<T>,
		randomEffectsDesign: DenseMatrix<T>,
		response: [T],
		grouping: GroupingFactor,
		randomEffectsPerGroup: Int
	) {
		self.fixedEffects = fixedEffects
		self.randomEffectsDesign = randomEffectsDesign
		self.response = response
		self.grouping = grouping
		self.randomEffectsPerGroup = randomEffectsPerGroup
	}
}

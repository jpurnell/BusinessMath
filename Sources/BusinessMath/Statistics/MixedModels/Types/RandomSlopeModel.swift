import Foundation
import Numerics

/// Specification of a random intercept-and-slope linear mixed-effects model.
///
/// The model is:
/// ```
/// y_ij = x_ij' * beta + u_0i + u_1i * z_ij + e_ij
/// ```
/// where `[u_0i, u_1i]' ~ N(0, G)` with `G = [[sigma_u0², sigma_u01], [sigma_u01, sigma_u1²]]`
/// and `e_ij ~ N(0, sigma_e²)`.
///
/// The slope variable `z_ij` is the column of `X` indicated by ``slopeColumn``.
/// The user must include an intercept column (all 1s) if desired.
///
/// Example:
/// ```swift
/// let X = try DenseMatrix([
///     [1.0, 25.0], [1.0, 30.0], [1.0, 35.0],
///     [1.0, 25.0], [1.0, 30.0], [1.0, 35.0]
/// ])
/// let y = [100.0, 105.0, 102.0, 98.0, 103.0, 100.0]
/// let groups = try GroupingFactor([0, 0, 0, 1, 1, 1])
/// let model = RandomSlopeModel(fixedEffects: X, response: y, grouping: groups, slopeColumn: 1)
/// ```
public struct RandomSlopeModel<T: Real & Sendable>: Sendable where T: BinaryFloatingPoint {
	/// Fixed-effects design matrix X (N x p). Include an intercept column
	/// (all 1s) as the first column if desired.
	public let fixedEffects: DenseMatrix<T>

	/// Response vector y (length N).
	public let response: [T]

	/// Grouping factor assigning observations to groups.
	public let grouping: GroupingFactor

	/// Column index in X that receives a random slope (0-indexed).
	public let slopeColumn: Int

	/// Creates a random intercept-and-slope model specification.
	///
	/// - Parameters:
	///   - fixedEffects: Design matrix (N x p). Include an intercept column
	///     (all 1s) as the first column if desired.
	///   - response: Response vector of length N.
	///   - grouping: Grouping factor of length N.
	///   - slopeColumn: Column index in X for the random slope variable (0-indexed).
	public init(fixedEffects: DenseMatrix<T>, response: [T], grouping: GroupingFactor, slopeColumn: Int) {
		self.fixedEffects = fixedEffects
		self.response = response
		self.grouping = grouping
		self.slopeColumn = slopeColumn
	}
}

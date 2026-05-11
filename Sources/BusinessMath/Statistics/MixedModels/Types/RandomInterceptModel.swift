import Foundation
import Numerics

/// Specification of a random-intercept linear mixed-effects model.
///
/// The model is:
/// ```
/// y_ij = x_ij' * beta + u_i + e_ij
/// ```
/// where u_i ~ N(0, sigma_u²) and e_ij ~ N(0, sigma_e²).
///
/// The user must include an intercept column (all 1s) if desired.
/// This is consistent with the library's `multipleLinearRegression` API.
///
/// Example:
/// ```swift
/// let X = try DenseMatrix([[25.0], [30.0], [35.0], [25.0], [30.0], [35.0]])
/// let y = [100.0, 105.0, 102.0, 98.0, 103.0, 100.0]
/// let groups = try GroupingFactor([0, 0, 0, 1, 1, 1])
/// let model = RandomInterceptModel(fixedEffects: X, response: y, grouping: groups)
/// ```
public struct RandomInterceptModel<T: Real & Sendable>: Sendable where T: BinaryFloatingPoint {
	/// Fixed-effects design matrix X (N x p, without intercept).
	public let fixedEffects: DenseMatrix<T>

	/// Response vector y (length N).
	public let response: [T]

	/// Grouping factor assigning observations to groups.
	public let grouping: GroupingFactor

	/// Creates a random intercept model specification.
	///
	/// - Parameters:
	///   - fixedEffects: Design matrix (N x p). Include an intercept column
	///     (all 1s) as the first column if desired.
	///   - response: Response vector of length N.
	///   - grouping: Grouping factor of length N.
	public init(fixedEffects: DenseMatrix<T>, response: [T], grouping: GroupingFactor) {
		self.fixedEffects = fixedEffects
		self.response = response
		self.grouping = grouping
	}
}

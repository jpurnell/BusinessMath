import Testing
import Foundation
@testable import BusinessMath

/// The Euclidean norm, at magnitudes where the naive formula breaks.
///
/// ## What was wrong
///
/// Every `norm` in this file computed `√(Σ xᵢ²)` directly. Squaring is the problem: a component
/// of 1e154 squares to 1e308, at the very edge of a `Double`, and a second one tips the sum to
/// infinity. The norm of `[1e154, 1e154, 1e154]` is `1.73e154` — an entirely ordinary number,
/// four orders of magnitude inside the representable range — and it came back as `inf`.
///
/// The same arithmetic fails at the other end. A component of 1e-200 squares to 1e-400, which is
/// zero, so the norm of `[3e-200, 4e-200]` — exactly `5e-200`, comfortably representable — came
/// back as `0`.
///
/// ## What it cost
///
/// Both are silent, and both reach optimizers as a verdict. `MultivariateNewtonRaphson` and
/// `MultivariateLBFGS` throw on a non-finite gradient norm, so an iterate that wandered past
/// 1e154 ended the run with `nonFiniteValue` even though its gradient was perfectly finite. And
/// a norm that underflows to zero is read as a stationary point, which is the same failure as
/// the gradient that returned zero — see `NumericalGradientAccuracyTests`.
///
/// ## The fix
///
/// Factor out the largest magnitude before squaring: `‖v‖ = m · √(Σ (xᵢ/m)²)` where
/// `m = maxᵢ |xᵢ|`. Every ratio is then at most 1, so the sum is at most `n` and cannot overflow;
/// and the smallest ratio is scaled up rather than down, so it cannot silently vanish. This is
/// the standard formulation and costs one extra pass.
@Suite("Vector norm range")
struct VectorNormRangeTests {

	/// A 3–4–5 triangle scaled to a magnitude, so the exact norm is known at every scale.
	///
	/// Chosen because `3² + 4² = 5²` in integers: the expected value is exact in binary
	/// floating point at every power-of-ten scale, so any discrepancy is the implementation's.
	static let scales: [Double] = [1e-200, 1e-160, 1e-100, 1e-10, 1, 1e10, 1e100, 1e154, 1e200]

	@Test("A two-dimensional norm survives both ends of the range", arguments: scales)
	func vector2DNorm(_ scale: Double) throws {
		let v = Vector2D(x: 3 * scale, y: 4 * scale)
		let expected: Double = 5 * scale
		let relativeError: Double = abs(v.norm - expected) / expected

		#expect(v.norm.isFinite, "norm of (3e, 4e) at scale \(scale) is \(v.norm)")
		#expect(relativeError < 1e-12,
				"scale \(scale): norm is \(v.norm), exactly \(expected)")
	}

	@Test("A three-dimensional norm survives both ends of the range", arguments: scales)
	func vector3DNorm(_ scale: Double) throws {
		// 1² + 2² + 2² = 9, so the norm is exactly 3.
		let v = Vector3D(x: 1 * scale, y: 2 * scale, z: 2 * scale)
		let expected: Double = 3 * scale
		let relativeError: Double = abs(v.norm - expected) / expected

		#expect(v.norm.isFinite, "norm at scale \(scale) is \(v.norm)")
		#expect(relativeError < 1e-12,
				"scale \(scale): norm is \(v.norm), exactly \(expected)")
	}

	@Test("An n-dimensional norm survives both ends of the range", arguments: scales)
	func vectorNNorm(_ scale: Double) throws {
		let v = VectorN([3 * scale, 4 * scale])
		let expected: Double = 5 * scale
		let relativeError: Double = abs(v.norm - expected) / expected

		#expect(v.norm.isFinite, "norm at scale \(scale) is \(v.norm)")
		#expect(relativeError < 1e-12,
				"scale \(scale): norm is \(v.norm), exactly \(expected)")
	}

	/// A norm is zero only for the zero vector.
	///
	/// The underflow case stated as the property it violates. A non-zero vector reporting a zero
	/// norm is read by every gradient method as a stationary point.
	@Test("Only the zero vector has a zero norm", arguments: scales)
	func onlyZeroHasZeroNorm(_ scale: Double) throws {
		#expect(VectorN([scale]).norm > 0, "‖[\(scale)]‖ came back as zero")
		#expect(VectorN([scale, scale]).norm > 0, "‖[\(scale), \(scale)]‖ came back as zero")
		#expect(Vector2D(x: scale, y: 0).norm > 0, "‖(\(scale), 0)‖ came back as zero")
		#expect(Vector3D(x: 0, y: scale, z: 0).norm > 0, "‖(0, \(scale), 0)‖ came back as zero")
	}

	/// The zero vector, and the empty one, still have norm zero.
	@Test("Zero and empty vectors have zero norm")
	func zeroVectorsHaveZeroNorm() throws {
		#expect(VectorN([Double]()).norm == 0)
		#expect(VectorN([0.0, 0.0]).norm == 0)
		#expect(Vector2D(x: 0.0, y: 0.0).norm == 0)
		#expect(Vector3D(x: 0.0, y: 0.0, z: 0.0).norm == 0)
	}
}

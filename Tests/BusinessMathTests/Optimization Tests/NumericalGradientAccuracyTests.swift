import Testing
import Foundation
@testable import BusinessMath

/// The numerical gradient, checked against derivatives that are known exactly.
///
/// ## Why this suite exists
///
/// `numericalGradient` perturbed each coordinate by a fixed **absolute** step, `epsilon`,
/// defaulting to 1e-6. A double's spacing at magnitude `m` is roughly `m · 2⁻⁵²`, so once a
/// coordinate exceeds about 1e10 the step is smaller than the gap between representable
/// neighbours and `x + epsilon == x` exactly. Both evaluations then return the same number and
/// the derivative is **exactly zero**.
///
/// Measured on `f(x) = x²`, whose gradient is exactly `2x` and admits no argument:
///
/// | x | true `2x` | returned | |
/// |---|---|---|---|
/// | 1e6 | 2.0e6 | 2.0e6 | exact |
/// | 1e9 | 2.0e9 | 1.92e9 | 4% low |
/// | 1e10 | 2.0e10 | 3.28e10 | **64% high** |
/// | 1e12 | 2.0e12 | **0.0** | |
/// | 1e25 | 2.0e25 | **0.0** | |
///
/// ## What that cost
///
/// A zero gradient is what every gradient-based method reads as a stationary point. Running
/// `MultivariateGradientDescent` on Rosenbrock from (-1.2, 1.0) at the default learning rate
/// diverges — that much is ordinary, and a caller can be told — but at iteration 5 the iterate
/// reached `x₀ = -6.6e25`, the gradient came back as exactly `[0, 0]`, and the optimizer
/// returned:
///
/// ```
/// value = 1.9448624575642407e+105     terminationReason = .converged
/// ```
///
/// A diverged run reported as a converged minimum, with an objective of 1e105. Twenty-nine call
/// sites across fourteen files take this gradient.
///
/// ## The fix, and why the step is measured rather than assumed
///
/// The step is now relative — `epsilon · max(1, |xᵢ|)` — so it always straddles a representable
/// neighbourhood. That alone is not enough: `x + h` is rounded to the nearest representable
/// value, so the step actually taken is not the step requested. The difference is recovered by
/// reading it back, `(forward - backward) / 2`, and dividing by what the arithmetic really did
/// rather than by what was asked for. That is a standard trick and it removes the rounding term
/// from the quotient entirely.
@Suite("Numerical gradient accuracy")
struct NumericalGradientAccuracyTests {

	typealias Vec = VectorN<Double>

	/// A function whose gradient is known in closed form, so the test needs no reference solver.
	struct Case: Sendable {
		let name: String
		let f: @Sendable (Vec) -> Double
		/// The exact gradient at a point.
		let exact: @Sendable ([Double]) -> [Double]
	}

	static let square = Case(
		name: "x²",
		f: { point in let a = point.toArray(); return a[0] * a[0] },
		exact: { a in [2 * a[0]] }
	)

	static let cube = Case(
		name: "x³",
		f: { point in let a = point.toArray(); return a[0] * a[0] * a[0] },
		exact: { a in [3 * a[0] * a[0]] }
	)

	static let quadratic2D = Case(
		name: "x² + 3y²",
		f: { point in
			let a = point.toArray()
			return a[0] * a[0] + 3 * a[1] * a[1]
		},
		exact: { a in [2 * a[0], 6 * a[1]] }
	)

	static let cases: [Case] = [square, cube, quadratic2D]

	/// Magnitudes spanning the range a diverging optimizer actually visits.
	///
	/// The upper end is not hypothetical: the iterate that produced the 1e105 result sat at
	/// 6.6e25, and it got there in five iterations.
	static let magnitudes: [Double] = [1e-3, 1, 1e3, 1e6, 1e9, 1e10, 1e12, 1e15, 1e20]

	/// Relative accuracy required of a central difference.
	///
	/// A central difference with a well-chosen step is accurate to about `ε^(2/3)`, so 1e-6 is
	/// undemanding — it is six orders looser than the method's best and six orders tighter than
	/// the 64% error measured at 1e10.
	static let relativeTolerance: Double = 1e-6

	@Test("The gradient is accurate at every magnitude an optimizer can reach",
		  arguments: cases.indices, magnitudes)
	func gradientIsAccurateAtScale(_ index: Int, _ magnitude: Double) throws {
		let subject = Self.cases[index]
		let dimension = subject.exact([0, 0]).count
		// Distinct components, so a bug that returns the same derivative for every axis shows.
		let point: [Double] = (0..<dimension).map { magnitude * Double($0 + 1) }

		let computed = try numericalGradient(subject.f, at: Vec(point)).toArray()
		let truth = subject.exact(point)

		for axis in 0..<dimension {
			let expected: Double = truth[axis]
			let actual: Double = computed[axis]
			let scale: Double = Swift.max(1e-300, abs(expected))
			let relativeError: Double = abs(actual - expected) / scale

			#expect(relativeError < Self.relativeTolerance,
					"\(subject.name) at |x| ≈ \(magnitude), axis \(axis): got \(actual), exact \(expected), relative error \(relativeError)")
		}
	}

	/// A non-zero gradient is never reported as zero.
	///
	/// Stated separately from accuracy because it is the failure with teeth: an inaccurate
	/// gradient makes an optimizer slow, and a zero gradient makes it declare victory.
	@Test("A non-zero gradient never comes back as exactly zero",
		  arguments: cases.indices, magnitudes)
	func nonZeroGradientIsNeverZero(_ index: Int, _ magnitude: Double) throws {
		let subject = Self.cases[index]
		let dimension = subject.exact([0, 0]).count
		let point: [Double] = (0..<dimension).map { magnitude * Double($0 + 1) }

		let computed = try numericalGradient(subject.f, at: Vec(point)).toArray()
		let truth = subject.exact(point)

		for axis in 0..<dimension where truth[axis] != 0 {
			// A quantitative floor rather than `!= 0`. "Not exactly zero" is the failure this
			// suite exists for, but it is also the weakest possible statement — a gradient off
			// by a factor of a thousand would pass it. Requiring at least half the true
			// magnitude, with the sign right, rejects both the zero and the wildly wrong.
			let expected: Double = truth[axis]
			let actual: Double = computed[axis]
			let ratio: Double = actual / expected
			#expect(ratio > 0.5,
					"\(subject.name) at |x| ≈ \(magnitude), axis \(axis): exact derivative is \(expected), computed \(actual) — a ratio of \(ratio), where zero is what every gradient method reads as a stationary point")
		}
	}

	/// Gradient descent does not report convergence on a run that diverged.
	///
	/// The end-to-end statement of the same defect. The learning rate here is genuinely too large
	/// for Rosenbrock and the run *should* fail — the objection is to the label on the failure,
	/// not to the failure.
	@Test("A diverged descent is not reported as converged")
	func divergedDescentIsNotConverged() throws {
		let rosenbrock: @Sendable (Vec) -> Double = { point in
			let a = point.toArray()
			let curve: Double = a[1] - a[0] * a[0]
			let offset: Double = 1 - a[0]
			return 100 * curve * curve + offset * offset
		}

		let optimizer = MultivariateGradientDescent<Vec>(learningRate: 0.01, maxIterations: 1000)
		let result = try optimizer.minimize(rosenbrock, from: Vec([-1.2, 1.0]), constraints: [])

		if result.terminationReason == .converged {
			// Converged means the gradient really was small, which for Rosenbrock means being
			// near (1, 1) where the objective is near zero — not at 1e105.
			#expect(result.value < 1.0,
					"reported converged at an objective of \(result.value), solution \(result.solution.toArray())")
		}
	}
}

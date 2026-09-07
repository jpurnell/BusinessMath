//
//  OptimizerStallTests.swift
//  BusinessMath
//
//  BFGS must stop when it stops moving.
//
//  `minimizeBFGS` breaks out of its loop on one condition: `gradNorm < tolerance`.
//  There is no check that the iterate is still moving. When the line search can no
//  longer find a descent step — a kinked objective, an ill-conditioned augmented
//  Lagrangian, a finite-difference gradient whose noise floor sits above the
//  tolerance — the step size collapses toward zero and:
//
//  - `xNew ≈ x`, so the point does not move;
//  - `s ≈ 0` and `y ≈ 0`, so `sTy` falls below the curvature threshold and the
//    inverse Hessian is *not* updated;
//  - the next iteration therefore computes an identical direction and runs an
//    identical line search.
//
//  The state is unchanged, the algorithm is deterministic, and so every remaining
//  iteration repeats the same one. It is a fixed point, and the only thing that
//  ends it is the iteration count.
//
//  Measured cost of that on the MINLP portfolio model: a single branch-and-bound
//  node took 78 of the 78 seconds the whole solve spent, and the time scaled
//  linearly with the inner budget — 4s at 50 inner iterations, 76s at 1,000 —
//  while returning a byte-identical answer at every setting. One hundred thousand
//  iterations of provably wasted work.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("BFGS stops when it stops moving")
struct OptimizerStallTests {

	/// `f(x) = |x − 0.3|`, with the subgradient a non-smooth problem actually
	/// hands back.
	///
	/// The slope is ±1 everywhere, including at the kink, because `|x|` has no
	/// derivative there and any subgradient in [−1, 1] is admissible — a solver
	/// choosing +1 is choosing legitimately. So `gradNorm` is 1 at every iterate
	/// and the convergence test can never fire. Backtracking drives the step size
	/// to zero as the iterate closes on 0.3, and from then on nothing changes.
	///
	/// Returning 0 at the kink instead would make this converge on the ordinary
	/// test and would not reproduce the stall at all. The distinction matters: the
	/// real stall in the augmented Lagrangian comes from a finite-difference
	/// gradient whose noise floor sits above the tolerance, which likewise never
	/// reaches zero.
	private static func kinkedObjective(_ point: VectorN<Double>) -> Double {
		abs(point.toArray()[0] - 0.3)
	}

	private static func kinkedGradient(_ point: VectorN<Double>) -> VectorN<Double> {
		point.toArray()[0] < 0.3 ? VectorN([-1.0]) : VectorN([1.0])
	}

	@Test("A stalled search returns instead of spending its whole budget")
	func stalledSearchStopsEarly() throws {
		let budget = 5_000
		let optimizer = MultivariateNewtonRaphson<VectorN<Double>>(
			maxIterations: budget,
			tolerance: 1e-10,
			useLineSearch: true,
			recordHistory: false
		)

		let result = try optimizer.minimizeBFGS(
			function: Self.kinkedObjective,
			gradient: { Self.kinkedGradient($0) },
			initialGuess: VectorN([1.0])
		)

		// The whole claim: it must not run to the limit doing nothing. Asserted on
		// the iteration count rather than elapsed time, so it means the same thing
		// on a loaded machine as on an idle one.
		#expect(result.iterations < budget,
				"BFGS spent its entire \(budget)-iteration budget on a stalled search")

		// And it must still hand back the best point it reached — stopping early is
		// only acceptable because the remaining iterations could not improve it.
		let x = result.solution.toArray()[0]
		#expect(abs(x - 0.3) < 1e-3,
				"stopped at x = \(x), which is not the minimum of |x − 0.3|")

		// Honest reporting: the gradient tolerance was never met, so this is not
		// convergence and must not be labelled as such.
		#expect(!result.converged,
				"a stalled search reported convergence, which would tell a caller the gradient test passed")
	}

	@Test("Stopping early does not cost accuracy on a problem that does converge")
	func genuineConvergenceIsUnaffected() throws {
		// A smooth quadratic with a unique minimum at (3, −2). Any stall check must
		// not fire here: the iterate moves at every step until the gradient test
		// passes, so this is the guard against a fix that simply stops sooner.
		let optimizer = MultivariateNewtonRaphson<VectorN<Double>>(
			maxIterations: 1_000,
			tolerance: 1e-10,
			useLineSearch: true,
			recordHistory: false
		)
		let objective: @Sendable (VectorN<Double>) -> Double = { point in
			let values = point.toArray()
			let first: Double = values[0] - 3
			let second: Double = values[1] + 2
			return first * first + 4 * second * second
		}
		let gradient: (VectorN<Double>) -> VectorN<Double> = { point in
			let values = point.toArray()
			return VectorN([2 * (values[0] - 3), 8 * (values[1] + 2)])
		}

		let result = try optimizer.minimizeBFGS(
			function: objective, gradient: gradient, initialGuess: VectorN([-5.0, 7.0]))

		#expect(result.converged, "a smooth quadratic did not converge")
		let solution = result.solution.toArray()
		#expect(abs(solution[0] - 3) < 1e-6, "x = \(solution[0]), expected 3")
		#expect(abs(solution[1] + 2) < 1e-6, "y = \(solution[1]), expected −2")
	}

	@Test("A flat objective is recognised immediately rather than iterated over")
	func flatObjectiveStopsAtOnce() throws {
		// Constant everywhere: the gradient is zero, so this exits on the ordinary
		// convergence test. Present to pin the boundary between "no gradient" and
		// "gradient that never shrinks", which are different exits.
		let optimizer = MultivariateNewtonRaphson<VectorN<Double>>(
			maxIterations: 1_000, tolerance: 1e-10, useLineSearch: true, recordHistory: false)
		let result = try optimizer.minimizeBFGS(
			function: { _ in 42.0 },
			gradient: { _ in VectorN([0.0, 0.0]) },
			initialGuess: VectorN([1.0, 1.0]))
		#expect(result.converged)
		#expect(result.iterations == 0, "a zero gradient took \(result.iterations) iterations to notice")
	}
}

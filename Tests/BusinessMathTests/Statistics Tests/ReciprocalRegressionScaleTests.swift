//
//  ReciprocalRegressionScaleTests.swift
//  BusinessMath
//
//  The fitter descended a *summed* negative log-likelihood at a fixed learning
//  rate. The gradient of a sum grows with the sample size while the step size
//  does not, so the same call that recovers the parameters at n = 50 overshoots
//  at n = 500 — and lands on the plateau where `a` is so large that `1/(a + bx)`
//  is zero for every x, the surface is flat, the gradient norm falls below the
//  tolerance, and the optimizer reports `converged: true` from a fit that is
//  wrong by eleven orders of magnitude.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath
import TestSupport

@Suite("Reciprocal Regression: Sample-Size Scaling")
struct ReciprocalRegressionScaleTests {

	/// Deterministic data from the reciprocal model, so a failure is a property of
	/// the fitter rather than of the draw.
	private static func makeData(
		n: Int,
		a: Double,
		b: Double,
		sigma: Double,
		seed: UInt64 = 42
	) -> [ReciprocalRegressionModel<Double>.DataPoint] {
		var rng = MMIXSeededRNG(state: seed)
		var data: [ReciprocalRegressionModel<Double>.DataPoint] = []
		data.reserveCapacity(n)

		for i in 0..<n {
			let x = 1.0 + Double(i) * 9.0 / Double(max(n - 1, 1))
			let mu = 1.0 / (a + b * x)
			let u1 = rng.next()
			let u2 = rng.next()
			let noise = distributionNormal(mean: 0.0, stdDev: sigma, u1, u2)
			data.append(.init(x: x, y: mu + noise))
		}

		return data
	}

	// MARK: - `converged` must mean converged

	@Test("A diverged fit is never reported as converged")
	func divergedFitIsNotReportedAsConverged() throws {
		let data = Self.makeData(n: 500, a: 0.2, b: 0.3, sigma: 0.05)
		let fitter = ReciprocalRegressionFitter<Double>()

		let result = try fitter.fit(data: data)

		#expect(
			result.converged == (result.terminationReason == .converged),
			"converged must be exactly the converged termination reason"
		)

		if result.converged {
			#expect(
				result.parameters.a < 100.0,
				"reported converged with a = \(result.parameters.a); converged must mean converged"
			)
			#expect(
				result.parameters.b < 100.0,
				"reported converged with b = \(result.parameters.b); converged must mean converged"
			)
		}
	}

	// MARK: - Recovery must not degrade with n

	@Test("Recovery does not degrade as the sample grows")
	func recoveryDoesNotDegradeWithSampleSize() throws {
		let trueA = 0.2
		let trueB = 0.3
		let trueSigma = 0.05

		for n in [50, 200, 500] {
			let data = Self.makeData(n: n, a: trueA, b: trueB, sigma: trueSigma)
			let fitter = ReciprocalRegressionFitter<Double>()

			let result = try fitter.fit(
				data: data,
				initialGuess: .init(a: 0.5, b: 0.5, sigma: 0.5),
				learningRate: 0.001,
				maxIterations: 2_000
			)

			#expect(
				result.parameters.a < 5.0,
				"n = \(n): a diverged to \(result.parameters.a)"
			)
			#expect(
				result.parameters.b < 5.0,
				"n = \(n): b diverged to \(result.parameters.b)"
			)
			#expect(
				result.logLikelihood.isFinite,
				"n = \(n): log-likelihood is not finite"
			)
		}
	}

	// MARK: - The default step has to fit something

	/// Dividing the objective by `n` without touching the default learning rate would
	/// have traded a fitter that diverges on large samples for one that moves too
	/// slowly to fit any sample. The default is a per-observation step now, and it has
	/// to recover parameters it was handed.
	@Test("The default learning rate recovers the parameters at every sample size")
	func defaultLearningRateRecoversParameters() throws {
		let trueA = 0.2
		let trueB = 0.3
		let fitter = ReciprocalRegressionFitter<Double>()

		for n in [100, 200, 500] {
			let data = Self.makeData(n: n, a: trueA, b: trueB, sigma: 0.2)
			let result = try fitter.fit(data: data, maxIterations: 1_000)

			#expect(
				abs(result.parameters.a - trueA) / trueA < 0.25,
				"n = \(n): a = \(result.parameters.a)"
			)
			#expect(
				abs(result.parameters.b - trueB) / trueB < 0.25,
				"n = \(n): b = \(result.parameters.b)"
			)
		}
	}

	// MARK: - Divergence is reported as divergence

	/// A learning rate large enough to overshoot still overshoots — normalising the
	/// objective removes the sample size from the step, not the caller's ability to
	/// ask for too large a one. What must not happen is the overshoot being reported
	/// as a fit: past the plateau the likelihood surface is flat, so the gradient test
	/// passes at parameters that predict the data worse than its own mean does.
	@Test("An overshooting step is reported as diverged, not converged")
	func overshootIsReportedAsDiverged() throws {
		let data = Self.makeData(n: 500, a: 0.2, b: 0.3, sigma: 0.05)
		let fitter = ReciprocalRegressionFitter<Double>()

		let result = try fitter.fit(
			data: data,
			initialGuess: .init(a: 0.5, b: 0.5, sigma: 0.5),
			learningRate: 5.0,
			maxIterations: 1_000
		)

		#expect(!result.converged, "a = \(result.parameters.a), b = \(result.parameters.b)")
		#expect(result.terminationReason != .converged)
	}

	@Test("Fitting no data is an error, not a fit")
	func emptyDataThrows() throws {
		let fitter = ReciprocalRegressionFitter<Double>()
		#expect(throws: OptimizationError.self) {
			_ = try fitter.fit(data: [])
		}
	}

	// MARK: - The objective must not scale with n

	@Test("A fixed learning rate behaves the same at every sample size")
	func fixedLearningRateIsSampleSizeInvariant() throws {
		// The same underlying relationship sampled at two sizes. A step rule that
		// descends a per-observation objective lands in the same neighbourhood for
		// both; one that descends a sum takes a step 10x larger for the larger
		// sample and leaves the neighbourhood entirely.
		let small = Self.makeData(n: 50, a: 0.2, b: 0.3, sigma: 0.05)
		let large = Self.makeData(n: 500, a: 0.2, b: 0.3, sigma: 0.05)

		let fitter = ReciprocalRegressionFitter<Double>()
		let smallFit = try fitter.fit(data: small, maxIterations: 2_000)
		let largeFit = try fitter.fit(data: large, maxIterations: 2_000)

		#expect(
			abs(largeFit.parameters.a - smallFit.parameters.a) < 1.0,
			"a moved from \(smallFit.parameters.a) to \(largeFit.parameters.a) on sample size alone"
		)
		#expect(
			abs(largeFit.parameters.b - smallFit.parameters.b) < 1.0,
			"b moved from \(smallFit.parameters.b) to \(largeFit.parameters.b) on sample size alone"
		)
	}
}

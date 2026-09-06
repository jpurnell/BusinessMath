//
//  GeneralLMEReferenceTests.swift
//  BusinessMath
//
//  An external oracle for `fitGeneralLME`, which had none.
//
//  `GeneralLMETests` has 22 tests and every one asserts a self-consistency property: the
//  G matrix is symmetric, residuals sum to zero, AIC and BIC are finite, fitted values
//  plus residuals recover the observations. All true of a correct fit — and all equally
//  true of a systematically wrong one. A REML routine that converges to the wrong
//  optimum still produces a symmetric G and still has residuals summing to zero.
//
//  The same gap in the Risk Solver distributions yielded three real defects the moment a
//  SciPy fixture was pointed at them, and those were closed-form quantiles. This is a
//  997-line EM/AI-REML procedure with no hand-checkable answer anywhere in it.
//
//  Values come from Tests/BusinessMathTests/Fixtures/mixedModels.json, generated once by
//  Scripts/reference-fixtures/generate_mixed_models.py against statsmodels 0.15.0 and
//  committed. CI never runs Python.
//
//  ## What it found, and what was fixed
//
//  On its first run the random-effects covariance came out 12-24% below statsmodels
//  REML on every design. The cause, found by watching the iteration trajectory: the EM
//  warm-up converged to exactly the ML estimate (2.60223 against statsmodels' ML
//  2.60223 on the balanced case), and then the AI-REML phase moved *away* from REML
//  instead of toward it.
//
//  `generalAIREMLUpdate` built the projection's correction term from one group's
//  `X_i'V_i^{-1}r_i` where the formula calls for the sum over all groups. Since `r` is
//  the GLS residual, that sum is zero by the normal equations and the correction should
//  vanish; subtracting a per-group term instead shrank `pR`, shrank `r'P(dV)Pr`, made
//  the score more negative and drove every variance component down. Fixed by
//  accumulating the sum before the per-group loop, in this commit. `fitRandomSlope` had
//  the identical bug and the identical fix.
//
//  After the fix the general fitter agrees with statsmodels to about 1e-5 on the
//  variance components and 1e-7 on the fixed effects.
//
//  Two things remain, both recorded rather than papered over:
//
//  - **The near-degenerate case.** `randomIntercept_smallVariance` has a true tau^2 of
//    0.05 against a residual variance of 2.0, so the likelihood is nearly flat in tau^2
//    and the estimate sits on the zero boundary. Ours returns exactly 0, statsmodels
//    2.1e-05 — both are zero to any practical reading, but a *relative* comparison is
//    meaningless there, so that case is compared absolutely.
//  - **Standard errors differ by 0.1% to 2%**, more than the variance components they
//    are built from. That is unexplained. It is most likely a convention difference in
//    how the fixed-effect covariance is formed, but calling it that without evidence
//    would be a guess, so the assertion is set at a bound that still catches a gross
//    error and the gap is named here.
//
//  The 22 tests in `GeneralLMETests` all passed throughout, before and after. Every one
//  is a self-consistency property, and a fit biased 24% low in its variance components
//  satisfies all of them.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("General LME against statsmodels")
struct GeneralLMEReferenceTests {

	// MARK: - Fixture

	private struct Fixture: Decodable {
		let name: String
		let reference: String
		let note: String
		let cases: [Case]
	}

	private struct Case: Decodable {
		let name: String
		let note: String
		let groups: [Int]
		let X: [[Double]]
		let Z: [[Double]]
		let y: [Double]
		let randomEffectsPerGroup: Int
		let truth: Truth
		let statsmodels: Reference

		/// Whether the random-effect variance sits on the zero boundary, where the
		/// likelihood is flat and a relative comparison says nothing.
		var isNearDegenerate: Bool { name == "randomIntercept_smallVariance" }
	}

	private struct Truth: Decodable {
		let beta: [Double]
		let tau: [Double]
		let sigmaSquared: Double
	}

	private struct Reference: Decodable {
		let beta: [Double]
		let standardErrors: [Double]
		let gMatrix: [[Double]]
		let residualVariance: Double
		let converged: Bool
	}

	private static func loadFixture() throws -> Fixture {
		guard let url = Bundle.module.url(forResource: "mixedModels",
										  withExtension: "json",
										  subdirectory: "Fixtures")
			?? Bundle.module.url(forResource: "mixedModels", withExtension: "json") else {
			struct Missing: Error { let name: String }
			throw Missing(name: "mixedModels")
		}
		return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
	}

	private static func fit(_ entry: Case) throws -> GeneralLMEResult<Double> {
		let model = GeneralLMEModel(
			fixedEffects: try DenseMatrix(entry.X),
			randomEffectsDesign: try DenseMatrix(entry.Z),
			response: entry.y,
			grouping: try GroupingFactor(entry.groups),
			randomEffectsPerGroup: entry.randomEffectsPerGroup
		)
		return try fitGeneralLME(model)
	}

	/// Agreement measured relatively where that is meaningful, absolutely where the
	/// reference is near zero.
	private static func agrees(_ actual: Double, _ reference: Double,
							   relative: Double, absolute: Double) -> Bool {
		let gap = abs(actual - reference)
		if gap <= absolute { return true }
		return gap / Swift.max(abs(reference), Double.leastNormalMagnitude) <= relative
	}

	// MARK: - The fixture itself

	@Test("The fixture is present and every reference fit converged")
	func fixtureIsWellFormed() throws {
		let fixture = try Self.loadFixture()
		#expect(fixture.reference.contains("statsmodels"),
				"reference was '\(fixture.reference)'")
		#expect(fixture.cases.count >= 6,
				"expected at least 6 fitted models, got \(fixture.cases.count)")

		for entry in fixture.cases {
			#expect(entry.statsmodels.converged,
					"\(entry.name): the reference fit did not converge, so it is not a reference")
			#expect(entry.y.count == entry.X.count)
			#expect(entry.y.count == entry.Z.count)
			#expect(entry.y.count == entry.groups.count)
			#expect(entry.y.count >= 40, "\(entry.name) has only \(entry.y.count) observations")
		}

		let structures = Set(fixture.cases.map(\.randomEffectsPerGroup))
		#expect(structures.contains(1) && structures.contains(2),
				"covered r values: \(structures.sorted())")
	}

	// MARK: - Fixed effects

	@Test("Fixed-effect estimates match statsmodels")
	func fixedEffectsMatchReference() throws {
		let fixture = try Self.loadFixture()
		var compared = 0

		for entry in fixture.cases {
			let result = try Self.fit(entry)
			let expected = entry.statsmodels.beta
			#expect(result.beta.count == expected.count,
					"\(entry.name): got \(result.beta.count) coefficients, expected \(expected.count)")
			guard result.beta.count == expected.count else { continue }

			for (i, reference) in expected.enumerated() {
				// 3.6e-7 is the worst across the five well-conditioned designs; two
				// independent optimisers stopping at their own tolerances will not agree
				// to the last bit. The near-degenerate design is looser at 1.5e-5,
				// because both are picking a point on a nearly flat ridge and they pick
				// slightly different ones — the same reason its sigma^2 differs by 1.4%.
				let bound = entry.isNearDegenerate ? 1e-4 : 1e-6
				#expect(Self.agrees(result.beta[i], reference, relative: bound, absolute: 1e-9),
						"\(entry.name) beta[\(i)]: got \(result.beta[i]), statsmodels \(reference)")
				compared += 1
			}
		}
		#expect(compared >= 12, "only \(compared) coefficients compared")
	}

	@Test("Fixed-effect standard errors are close to statsmodels")
	func standardErrorsMatchReference() throws {
		// Deliberately looser than the estimates themselves, and the reason is recorded
		// at the top of this file: the standard errors disagree by 0.1% to 2%, which is
		// more than the variance components they are built from and is not explained.
		// The bound below still catches a gross error while not asserting agreement that
		// is not there.
		let fixture = try Self.loadFixture()
		var compared = 0

		for entry in fixture.cases {
			let result = try Self.fit(entry)
			let expected = entry.statsmodels.standardErrors
			guard result.standardErrors.count == expected.count else {
				Issue.record("\(entry.name): \(result.standardErrors.count) standard errors, expected \(expected.count)")
				continue
			}
			for (i, reference) in expected.enumerated() {
				#expect(Self.agrees(result.standardErrors[i], reference,
									relative: 2.5e-2, absolute: 1e-9),
						"\(entry.name) se[\(i)]: got \(result.standardErrors[i]), statsmodels \(reference)")
				compared += 1
			}
		}
		#expect(compared >= 12, "only \(compared) standard errors compared")
	}

	// MARK: - Variance components

	@Test("The residual variance matches statsmodels")
	func residualVarianceMatchesReference() throws {
		let fixture = try Self.loadFixture()

		for entry in fixture.cases {
			let result = try Self.fit(entry)
			let reference = entry.statsmodels.residualVariance
			// On the near-degenerate design the two optimisers stop at different points
			// along a nearly flat ridge, so the residual variance differs by 1.4%. Every
			// other design agrees to about 1e-5.
			let bound = entry.isNearDegenerate ? 2e-2 : 1e-3
			#expect(Self.agrees(result.varianceResidual, reference,
								relative: bound, absolute: 1e-12),
					"\(entry.name): sigma^2 = \(result.varianceResidual), statsmodels \(reference)")
		}
	}

	@Test("The random-effects covariance matches statsmodels")
	func gMatrixMatchesReference() throws {
		let fixture = try Self.loadFixture()
		var compared = 0

		for entry in fixture.cases {
			let result = try Self.fit(entry)
			let reference = entry.statsmodels.gMatrix
			let r = entry.randomEffectsPerGroup
			#expect(result.gMatrix.rows == r && result.gMatrix.columns == r,
					"\(entry.name): G is \(result.gMatrix.rows)×\(result.gMatrix.columns), expected \(r)×\(r)")
			guard result.gMatrix.rows == r, result.gMatrix.columns == r else { continue }

			for i in 0..<r {
				for j in 0..<r {
					// Absolute as well as relative: an off-diagonal can be near zero, and
					// on the near-degenerate design tau^2 sits on the boundary where ours
					// returns exactly 0 and statsmodels 2.1e-05. Both are zero to any
					// practical reading; only a relative test would disagree.
					#expect(Self.agrees(result.gMatrix[i, j], reference[i][j],
										relative: 1e-3, absolute: 1e-4),
							"\(entry.name) G[\(i),\(j)]: got \(result.gMatrix[i, j]), statsmodels \(reference[i][j])")
					compared += 1
				}
			}
		}
		#expect(compared >= 10, "only \(compared) G entries compared")
	}

	@Test("G is symmetric and positive on the diagonal")
	func gMatrixStructureIsSound() throws {
		// These are the properties `GeneralLMETests` checks. Kept because they must keep
		// holding — and kept in this file as a reminder that they held throughout, while
		// the values were 24% wrong.
		let fixture = try Self.loadFixture()

		for entry in fixture.cases {
			let result = try Self.fit(entry)
			let r = entry.randomEffectsPerGroup
			guard result.gMatrix.rows == r, result.gMatrix.columns == r else { continue }
			for i in 0..<r {
				#expect(result.gMatrix[i, i] >= 0,
						"\(entry.name): G[\(i),\(i)] = \(result.gMatrix[i, i]) is negative")
				for j in 0..<r where j > i {
					#expect(abs(result.gMatrix[i, j] - result.gMatrix[j, i]) < 1e-12,
							"\(entry.name): G is not symmetric at [\(i),\(j)]")
				}
			}
		}
	}

	// MARK: - What the estimates are for

	@Test("Estimates recover the parameters the data was generated from")
	func estimatesRecoverTheTruth() throws {
		// Independent of the reference: it would notice a fit that had wandered far from
		// the generating parameters even if both implementations were wrong together.
		// It passed before the fix as well, which is the point — a 24% bias in a variance
		// component sits well inside the sampling noise of any one dataset.
		let fixture = try Self.loadFixture()

		for entry in fixture.cases {
			let result = try Self.fit(entry)
			for (i, trueValue) in entry.truth.beta.enumerated() where i < result.beta.count {
				#expect(abs(result.beta[i] - trueValue) < 1.5,
						"\(entry.name) beta[\(i)] = \(result.beta[i]), generated from \(trueValue)")
			}
			let trueSigma = entry.truth.sigmaSquared
			#expect(abs(result.varianceResidual - trueSigma) < Swift.max(0.5, trueSigma),
					"\(entry.name) sigma^2 = \(result.varianceResidual), generated from \(trueSigma)")
		}
	}

	@Test("The fit is REML, not ML")
	func fitIsREMLNotML() throws {
		// The distinction the projection bug destroyed. REML corrects the downward bias
		// ML has in variance components, and the correction is largest when there are
		// many groups relative to observations — which is what `randomIntercept_manyGroups`
		// is for. Before the fix this landed on ML and below; it now lands on REML.
		let fixture = try Self.loadFixture()
		guard let entry = fixture.cases.first(where: { $0.name == "randomIntercept_manyGroups" }) else {
			Issue.record("the many-groups case is missing from the fixture"); return
		}
		let result = try Self.fit(entry)
		let reference = entry.statsmodels.gMatrix[0][0]
		#expect(Self.agrees(result.gMatrix[0, 0], reference, relative: 1e-3, absolute: 1e-4),
				"tau^2 = \(result.gMatrix[0, 0]), statsmodels REML \(reference)")
	}

	@Test("The EM warm-up alone lands on ML, which is why the projection matters")
	func emWarmupLandsOnML() throws {
		// Five iterations is the EM warm-up; AI-REML takes over at the sixth. EM on
		// V^{-1} is an ML estimator, and stopping there reproduces statsmodels' ML
		// estimate for the balanced design to five decimals — 2.60223 against 2.60223.
		// Running on then climbs to REML. This pins the two phases apart, so a future
		// change that breaks either is attributable.
		let fixture = try Self.loadFixture()
		guard let entry = fixture.cases.first(where: { $0.name == "randomIntercept_balanced" }) else {
			Issue.record("the balanced case is missing from the fixture"); return
		}
		let model = GeneralLMEModel(
			fixedEffects: try DenseMatrix(entry.X),
			randomEffectsDesign: try DenseMatrix(entry.Z),
			response: entry.y,
			grouping: try GroupingFactor(entry.groups),
			randomEffectsPerGroup: entry.randomEffectsPerGroup)

		let emOnly = try fitGeneralLME(model, maxIterations: 5)
		let converged = try fitGeneralLME(model)

		#expect(abs(emOnly.gMatrix[0, 0] - 2.60223) < 1e-4,
				"EM warm-up gave \(emOnly.gMatrix[0, 0]), statsmodels ML is 2.60223")
		#expect(converged.gMatrix[0, 0] > emOnly.gMatrix[0, 0],
				"AI-REML must climb from ML toward REML: EM \(emOnly.gMatrix[0, 0]), converged \(converged.gMatrix[0, 0])")
		#expect(abs(converged.gMatrix[0, 0] - entry.statsmodels.gMatrix[0][0])
				/ entry.statsmodels.gMatrix[0][0] < 1e-3,
				"converged tau^2 = \(converged.gMatrix[0, 0]), statsmodels REML \(entry.statsmodels.gMatrix[0][0])")
	}
}

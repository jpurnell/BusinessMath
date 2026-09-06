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
//  ## What it found, on the first run
//
//  A real disagreement in the variance components. Fixed effects agree to about 1e-5,
//  and the residual variance is close — but **G is systematically low**, by 12% to 24%
//  across every design:
//
//      case                            BusinessMath   statsmodels REML   statsmodels ML
//      randomIntercept_balanced          2.2617           2.9875            2.6022
//      randomIntercept_unbalanced        0.3847           0.5032            0.4369
//      randomSlope_balanced   G[0,0]     2.2608           2.6036            2.4260
//      randomSlope_unbalanced G[0,0]     0.6997           0.8002            0.7487
//
//  Three things were ruled out before recording this as a defect:
//
//  1. **Not premature convergence.** The estimates are stable to ten significant figures
//     from 10 iterations through 5000, at tolerances of 1e-8 and 1e-12. It converges —
//     to a different answer.
//  2. **Not ML mislabelled as REML.** That was the first hypothesis, because on balanced
//     designs the ratio to REML is almost exactly (m − p)/m — 0.757 at m = 8 against a
//     predicted 0.750, and 0.868 at m = 15 against 0.867. But refitting the reference
//     with `reml=False` shows BusinessMath is 6% to 13% below *ML* as well. It is not
//     either estimator.
//  3. **Not a missing REML projection.** `generalAIREMLUpdate` does build
//     `P = V⁻¹ − V⁻¹X(X'V⁻¹X)⁻¹X'V⁻¹`, and `generalEMUpdate`'s M-step does include the
//     conditional-variance term `G − GZ'V⁻¹ZG`. Both are structurally correct.
//
//  So the defect is somewhere in the AI-REML score or average-information assembly, and
//  finding it is a separate job from building this oracle. The comparisons below are
//  wrapped in `withKnownIssue` so the suite stays green and the finding stays in the
//  code: if the estimator is ever fixed, Swift Testing reports the unexpected pass.
//
//  The 22 tests in `GeneralLMETests` all pass, and always did. Every one of them is a
//  self-consistency property, and a fit biased 24% low in its variance components
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

	/// Fits one fixture case with `fitGeneralLME`, on exactly the data statsmodels saw.
	private static func fit(_ entry: Case) throws -> GeneralLMEResult<Double> {
		let x = try DenseMatrix(entry.X)
		let z = try DenseMatrix(entry.Z)
		let grouping = try GroupingFactor(entry.groups)
		let model = GeneralLMEModel(
			fixedEffects: x,
			randomEffectsDesign: z,
			response: entry.y,
			grouping: grouping,
			randomEffectsPerGroup: entry.randomEffectsPerGroup
		)
		return try fitGeneralLME(model)
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
			// The data must actually be there. An empty array would make every
			// comparison below pass by comparing nothing.
			#expect(entry.y.count == entry.X.count)
			#expect(entry.y.count == entry.Z.count)
			#expect(entry.y.count == entry.groups.count)
			#expect(entry.y.count >= 40, "\(entry.name) has only \(entry.y.count) observations")
		}

		// Both random-effect structures must be represented, or the r = 2 path — where
		// G has an off-diagonal — goes unchecked.
		let structures = Set(fixture.cases.map(\.randomEffectsPerGroup))
		#expect(structures.contains(1) && structures.contains(2),
				"covered r values: \(structures.sorted())")
	}

	// MARK: - Fixed effects

	@Test("Fixed-effect estimates agree with statsmodels to better than 1%")
	func fixedEffectsMatchReference() throws {
		// This one passes. Beta is not immune to the variance-component defect — the GLS
		// weighting runs through V, which contains G — but it is only weakly sensitive to
		// it, and the largest disagreement across all six designs is 0.42%.
		let fixture = try Self.loadFixture()
		var compared = 0

		for entry in fixture.cases {
			let result = try Self.fit(entry)
			let expected = entry.statsmodels.beta
			#expect(result.beta.count == expected.count,
					"\(entry.name): got \(result.beta.count) coefficients, expected \(expected.count)")
			guard result.beta.count == expected.count else { continue }

			for (i, reference) in expected.enumerated() {
				// Relative where the coefficient is large enough for that to mean
				// something — a coefficient near zero has no meaningful relative error.
				let scale = Swift.max(abs(reference), 1.0)
				let deviation = abs(result.beta[i] - reference) / scale
				#expect(deviation < 1e-2,
						"\(entry.name) beta[\(i)]: got \(result.beta[i]), statsmodels \(reference), relative \(deviation)")
				compared += 1
			}
		}
		#expect(compared >= 12, "only \(compared) coefficients compared")
	}

	@Test("Fixed-effect estimates match statsmodels to full precision")
	func fixedEffectsMatchToFullPrecision() throws {
		// The same comparison at the precision two implementations of the same estimator
		// should reach. It does not hold, for the same reason the variance components do
		// not: beta is computed by GLS through a V built from the wrong G.
		let fixture = try Self.loadFixture()

		withKnownIssue("beta inherits the variance-component defect through the GLS weighting; it is off by up to 0.42%") {
			for entry in fixture.cases {
				let result = try Self.fit(entry)
				for (i, reference) in entry.statsmodels.beta.enumerated()
				where i < result.beta.count {
					let scale = Swift.max(abs(reference), 1.0)
					let deviation = abs(result.beta[i] - reference) / scale
					#expect(deviation < 1e-8,
							"\(entry.name) beta[\(i)]: got \(result.beta[i]), statsmodels \(reference), relative \(deviation)")
				}
			}
		}
	}

	@Test("Fixed-effect standard errors match statsmodels")
	func standardErrorsMatchReference() throws {
		let fixture = try Self.loadFixture()

		withKnownIssue("standard errors are functions of G, which is 12-24% low — see the note at the top of this file") {
			for entry in fixture.cases {
				let result = try Self.fit(entry)
				let expected = entry.statsmodels.standardErrors
				guard result.standardErrors.count == expected.count else {
					Issue.record("\(entry.name): \(result.standardErrors.count) standard errors, expected \(expected.count)")
					continue
				}
				for (i, reference) in expected.enumerated() {
					let deviation = abs(result.standardErrors[i] - reference) / Swift.max(reference, 1e-12)
					#expect(deviation < 1e-4,
							"\(entry.name) se[\(i)]: got \(result.standardErrors[i]), statsmodels \(reference), relative \(deviation)")
				}
			}
		}
	}

	// MARK: - Variance components, where the defect is

	@Test("The residual variance matches statsmodels")
	func residualVarianceMatchesReference() throws {
		let fixture = try Self.loadFixture()

		withKnownIssue("sigma^2 is low by up to 7% — see the note at the top of this file") {
			for entry in fixture.cases {
				let result = try Self.fit(entry)
				let reference = entry.statsmodels.residualVariance
				let deviation = abs(result.varianceResidual - reference) / Swift.max(reference, 1e-12)
				#expect(deviation < 1e-4,
						"\(entry.name): sigma^2 = \(result.varianceResidual), statsmodels \(reference), relative \(deviation)")
			}
		}
	}

	@Test("The random-effects covariance matches statsmodels")
	func gMatrixMatchesReference() throws {
		let fixture = try Self.loadFixture()

		// The shape is right even though the values are not, so that part is asserted
		// for real — a G of the wrong dimensions would be a different bug entirely.
		for entry in fixture.cases {
			let result = try Self.fit(entry)
			let r = entry.randomEffectsPerGroup
			#expect(result.gMatrix.rows == r && result.gMatrix.columns == r,
					"\(entry.name): G is \(result.gMatrix.rows)×\(result.gMatrix.columns), expected \(r)×\(r)")
		}

		withKnownIssue("G is 12-24% low across every design — the defect this fixture was built to find") {
			for entry in fixture.cases {
				let result = try Self.fit(entry)
				let reference = entry.statsmodels.gMatrix
				let r = entry.randomEffectsPerGroup
				guard result.gMatrix.rows == r, result.gMatrix.columns == r else { continue }

				for i in 0..<r {
					for j in 0..<r {
						let expected = reference[i][j]
						let actual = result.gMatrix[i, j]
						// An absolute floor sits under the relative comparison because an
						// off-diagonal can legitimately be near zero. Note statsmodels
						// reports `cov_re` in the response's units; `cov_re_unscaled` is
						// that divided by the residual variance, and taking the wrong one
						// would rescale every entry while leaving symmetry and positivity
						// intact — so the fixture records which was used.
						let scale = Swift.max(abs(expected), 1e-3)
						let deviation = abs(actual - expected) / scale
						#expect(deviation < 1e-3,
								"\(entry.name) G[\(i),\(j)]: got \(actual), statsmodels \(expected), relative \(deviation)")
					}
				}
			}
		}
	}

	@Test("G is symmetric and positive on the diagonal, defect notwithstanding")
	func gMatrixStructureIsSound() throws {
		// Worth keeping as a real assertion: these hold now and must keep holding after
		// any fix. They are also exactly the properties `GeneralLMETests` checks, and the
		// point of this file is that they were satisfied by a fit biased 24% low.
		let fixture = try Self.loadFixture()

		for entry in fixture.cases {
			let result = try Self.fit(entry)
			let r = entry.randomEffectsPerGroup
			guard result.gMatrix.rows == r, result.gMatrix.columns == r else { continue }
			for i in 0..<r {
				#expect(result.gMatrix[i, i] >= 0,
						"\(entry.name): G[\(i),\(i)] = \(result.gMatrix[i, i]) is negative")
				for j in 0..<r where j > i {
					let deviation = abs(result.gMatrix[i, j] - result.gMatrix[j, i])
					#expect(deviation < 1e-12, "\(entry.name): G is not symmetric at [\(i),\(j)]")
				}
			}
		}
	}

	// MARK: - What the estimates are for

	@Test("Estimates recover the parameters the data was generated from")
	func estimatesRecoverTheTruth() throws {
		// Independent of the reference comparison: if both implementations were wrong in
		// the same way, this would still notice a fit that had wandered far from the
		// generating parameters. Wide tolerances, because these are finite samples — the
		// point is the estimate is in the right place, not that it is exact. It passes,
		// which is why the defect went unnoticed: a 24% bias in a variance component is
		// well inside the sampling noise of any one dataset.
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

	@Test("REML is not ML, and this implementation matches neither")
	func remlNotML() throws {
		// REML corrects the downward bias ML has in variance components, and the
		// correction is largest with many groups relative to observations. The first
		// hypothesis for the defect was that this implementation computes ML under a REML
		// label, and on balanced designs the ratio to REML is strikingly close to the
		// (m − p)/m that would imply. Refitting the reference with `reml=False` ruled it
		// out: BusinessMath is 6-13% below ML as well.
		let fixture = try Self.loadFixture()
		guard let entry = fixture.cases.first(where: { $0.name == "randomIntercept_manyGroups" }) else {
			Issue.record("the many-groups case is missing from the fixture"); return
		}
		withKnownIssue("tau^2 matches neither the REML nor the ML reference") {
			let result = try Self.fit(entry)
			let reference = entry.statsmodels.gMatrix[0][0]
			let deviation = abs(result.gMatrix[0, 0] - reference) / Swift.max(abs(reference), 1e-12)
			#expect(deviation < 1e-3,
					"tau^2 = \(result.gMatrix[0, 0]), statsmodels REML \(reference), relative \(deviation)")
		}
	}
}

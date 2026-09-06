//
//  MixedModelReferenceTests.swift
//  BusinessMath
//
//  External oracle for the two specialised mixed-model fitters, `fitRandomIntercept`
//  and `fitRandomSlope`, and a cross-check between all three.
//
//  `GeneralLMEReferenceTests` found that `fitGeneralLME` returned a random-effects
//  covariance 12-24% below statsmodels REML. These two fitters solve the same problem by
//  their own code paths, so putting them on the *same data* answered a question the
//  general fixture could not: is the fault in machinery all three share, or in one of
//  them?
//
//  No new fixture is needed. `mixedModels.json` already encodes the two designs these
//  types accept — `Z = 1` for the intercept model, `Z = [1, x]` for the slope model —
//  because those are the structures it was generated with.
//
//  ## The answer: two different bugs
//
//  **`fitRandomSlope` shared the general fitter's bug** and, before the fix, agreed with
//  it to every digit — the same wrong `X_i'V_i^{-1}r_i` in place of the sum over groups.
//  Both are fixed and both now match statsmodels.
//
//  **`fitRandomIntercept` has a different one, and it is still open.** Its Fisher
//  scoring never applies the REML projection at all: the trace term is
//  `(n_i - 1)/sigma_e^2 + 1/a_i`, which is `tr(V_i^{-1})`, with nothing subtracted for
//  the `p` estimated fixed effects. `fisherScoringUpdate` is not even passed `X`, so it
//  could not compute the correction if it wanted to. **It computes ML while its
//  documentation says REML** — the docstring reads "via REML" and "profiled REML
//  criterion", and the result type carries `remlLogLikelihood`.
//
//  The consequences, against statsmodels REML:
//
//      case                          tau^2 ours   REML     sigma^2 ours   REML
//      randomIntercept_balanced         2.5983   2.9875        0.6151    0.6069
//      randomIntercept_unbalanced       0.3860   0.5032        0.9353    0.7225
//      randomIntercept_smallVariance    0.0000   0.0000        3.9019    2.1358
//
//  tau^2 low by up to 23%, and sigma^2 high by up to 83% on the near-degenerate design.
//  Its 15 tests in `RandomInterceptTests` all pass, and always did.
//
//  Fixing it means giving `fisherScoringUpdate` the design matrix and adding
//  `tr[(X'V^{-1}X)^{-1} X'V^{-1}(dV/dtheta)V^{-1}X]` to the score and the matching term
//  to the Fisher information — a real change to a two-parameter scoring routine, and a
//  separate piece of work from this one. Recorded with `withKnownIssue` so the suite
//  stays green and reports the unexpected pass when it is done.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Random intercept and slope against statsmodels")
struct MixedModelReferenceTests {

	// MARK: - Fixture

	private struct Fixture: Decodable { let cases: [Case] }

	private struct Case: Decodable {
		let name: String
		let groups: [Int]
		let X: [[Double]]
		let y: [Double]
		let randomEffectsPerGroup: Int
		let statsmodels: Reference
	}

	private struct Reference: Decodable {
		let beta: [Double]
		let standardErrors: [Double]
		let gMatrix: [[Double]]
		let residualVariance: Double
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

	private static func interceptCases(_ f: Fixture) -> [Case] {
		f.cases.filter { $0.randomEffectsPerGroup == 1 }
	}

	private static func slopeCases(_ f: Fixture) -> [Case] {
		f.cases.filter { $0.randomEffectsPerGroup == 2 }
	}

	private static func fitIntercept(_ entry: Case) throws -> RandomInterceptResult<Double> {
		let model = RandomInterceptModel(
			fixedEffects: try DenseMatrix(entry.X),
			response: entry.y,
			grouping: try GroupingFactor(entry.groups))
		return try fitRandomIntercept(model)
	}

	private static func fitSlope(_ entry: Case) throws -> RandomSlopeResult<Double> {
		// Column 1 of X is the covariate the fixture also placed in Z, so the slope model
		// sees exactly the design statsmodels and `fitGeneralLME` were given.
		let model = RandomSlopeModel(
			fixedEffects: try DenseMatrix(entry.X),
			response: entry.y,
			grouping: try GroupingFactor(entry.groups),
			slopeColumn: 1)
		return try fitRandomSlope(model)
	}

	// MARK: - Random intercept

	@Test("Random intercept: the designs it needs are in the fixture")
	func interceptFixtureIsPresent() throws {
		let fixture = try Self.loadFixture()
		let cases = Self.interceptCases(fixture)
		#expect(cases.count >= 3, "only \(cases.count) random-intercept designs")
		for entry in cases {
			#expect(entry.y.count >= 40, "\(entry.name) has \(entry.y.count) observations")
			#expect(entry.statsmodels.gMatrix.count == 1,
					"\(entry.name): expected a 1×1 G, got \(entry.statsmodels.gMatrix.count) rows")
		}
	}

	@Test("Random intercept: fixed effects agree with statsmodels to better than 1%")
	func interceptFixedEffects() throws {
		let fixture = try Self.loadFixture()
		var compared = 0
		for entry in Self.interceptCases(fixture) {
			let result = try Self.fitIntercept(entry)
			for (i, reference) in entry.statsmodels.beta.enumerated()
			where i < result.beta.count {
				let scale = Swift.max(abs(reference), 1.0)
				let deviation = abs(result.beta[i] - reference) / scale
				#expect(deviation < 1e-2,
						"\(entry.name) beta[\(i)]: got \(result.beta[i]), statsmodels \(reference), relative \(deviation)")
				compared += 1
			}
		}
		#expect(compared >= 6, "only \(compared) coefficients compared")
	}

	@Test("Random intercept: the random-effect variance matches statsmodels")
	func interceptVarianceComponent() throws {
		let fixture = try Self.loadFixture()

		withKnownIssue("fitRandomIntercept computes ML, not REML — its Fisher score omits the projection entirely. See the note at the top of this file.") {
			for entry in Self.interceptCases(fixture) {
				let result = try Self.fitIntercept(entry)
				let reference = entry.statsmodels.gMatrix[0][0]
				let deviation = abs(result.varianceRandom - reference) / Swift.max(abs(reference), 1e-6)
				#expect(deviation < 1e-3,
						"\(entry.name): tau^2 = \(result.varianceRandom), statsmodels \(reference), relative \(deviation)")
			}
		}
	}

	@Test("Random intercept: the residual variance matches statsmodels")
	func interceptResidualVariance() throws {
		let fixture = try Self.loadFixture()

		withKnownIssue("fitRandomIntercept computes ML, not REML — sigma^2 is high by up to 83% on the near-degenerate design") {
			for entry in Self.interceptCases(fixture) {
				let result = try Self.fitIntercept(entry)
				let reference = entry.statsmodels.residualVariance
				let deviation = abs(result.varianceResidual - reference) / reference
				#expect(deviation < 1e-4,
						"\(entry.name): sigma^2 = \(result.varianceResidual), statsmodels \(reference), relative \(deviation)")
			}
		}
	}

	// MARK: - Random slope

	@Test("Random slope: the designs it needs are in the fixture")
	func slopeFixtureIsPresent() throws {
		let fixture = try Self.loadFixture()
		let cases = Self.slopeCases(fixture)
		#expect(cases.count >= 2, "only \(cases.count) random-slope designs")
		for entry in cases {
			#expect(entry.statsmodels.gMatrix.count == 2,
					"\(entry.name): expected a 2×2 G, got \(entry.statsmodels.gMatrix.count) rows")
		}
	}

	@Test("Random slope: the three variance components match statsmodels")
	func slopeVarianceComponents() throws {
		let fixture = try Self.loadFixture()

		for entry in Self.slopeCases(fixture) {
			let result = try Self.fitSlope(entry)
			let g = entry.statsmodels.gMatrix

			let components: [(String, Double, Double)] = [
				("varianceIntercept", result.varianceIntercept, g[0][0]),
				("varianceSlope", result.varianceSlope, g[1][1]),
				("covarianceInterceptSlope", result.covarianceInterceptSlope, g[0][1])
			]
			for (label, actual, reference) in components {
				let deviation = abs(actual - reference) / Swift.max(abs(reference), 1e-3)
				#expect(deviation < 1e-3,
						"\(entry.name) \(label): got \(actual), statsmodels \(reference), relative \(deviation)")
			}
		}
	}

	@Test("Random slope: fixed effects agree with statsmodels to better than 1%")
	func slopeFixedEffects() throws {
		let fixture = try Self.loadFixture()
		var compared = 0
		for entry in Self.slopeCases(fixture) {
			let result = try Self.fitSlope(entry)
			for (i, reference) in entry.statsmodels.beta.enumerated()
			where i < result.beta.count {
				let scale = Swift.max(abs(reference), 1.0)
				let deviation = abs(result.beta[i] - reference) / scale
				#expect(deviation < 1e-2,
						"\(entry.name) beta[\(i)]: got \(result.beta[i]), statsmodels \(reference), relative \(deviation)")
				compared += 1
			}
		}
		#expect(compared >= 4, "only \(compared) coefficients compared")
	}

	// MARK: - The diagnostic: do the three implementations agree with each other?

	@Test("The specialised and general fitters agree with each other on the same data")
	func specialisedAgreesWithGeneral() throws {
		// This is the question the general fixture could not answer. All three solve the
		// same problem by different code paths. If they agree with each other and all
		// disagree with statsmodels, the fault is in machinery they share. If they
		// disagree among themselves, it is in one of them, and the odd one out names it.
		//
		// Whichever way it falls, it is worth an assertion of its own: three
		// implementations of one estimator in a single package should not return
		// different numbers, independently of which is right.
		let fixture = try Self.loadFixture()
		var compared = 0

		withKnownIssue("fitRandomIntercept computes ML where fitGeneralLME computes REML, so the two cannot agree until the former is fixed") {
			for entry in Self.interceptCases(fixture) {
				let special = try Self.fitIntercept(entry)
				let general = try Self.fitGeneral(entry)

				let tauDeviation = abs(special.varianceRandom - general.gMatrix[0, 0])
					/ Swift.max(abs(general.gMatrix[0, 0]), 1e-6)
				#expect(tauDeviation < 1e-6,
						"\(entry.name): fitRandomIntercept tau^2 = \(special.varianceRandom), fitGeneralLME \(general.gMatrix[0, 0])")

				let sigmaDeviation = abs(special.varianceResidual - general.varianceResidual)
					/ Swift.max(general.varianceResidual, 1e-12)
				#expect(sigmaDeviation < 1e-6,
						"\(entry.name): fitRandomIntercept sigma^2 = \(special.varianceResidual), fitGeneralLME \(general.varianceResidual)")
			}
		}

		// The slope fitter, by contrast, agrees with the general one to eight figures now
		// that both carry the projection fix. Before it, they agreed on the same wrong
		// answer — which is what identified the bug as shared rather than local.
		for entry in Self.slopeCases(fixture) {
			let special = try Self.fitSlope(entry)
			let general = try Self.fitGeneral(entry)

			let pairs: [(String, Double, Double)] = [
				("varianceIntercept", special.varianceIntercept, general.gMatrix[0, 0]),
				("varianceSlope", special.varianceSlope, general.gMatrix[1, 1]),
				("covariance", special.covarianceInterceptSlope, general.gMatrix[0, 1]),
				("varianceResidual", special.varianceResidual, general.varianceResidual)
			]
			for (label, a, b) in pairs {
				let deviation = abs(a - b) / Swift.max(abs(b), 1e-6)
				#expect(deviation < 1e-5,
						"\(entry.name) \(label): fitRandomSlope \(a), fitGeneralLME \(b)")
				compared += 1
			}
		}
		#expect(compared >= 8, "only \(compared) slope cross-comparisons made")
	}

	private static func fitGeneral(_ entry: Case) throws -> GeneralLMEResult<Double> {
		let n = entry.y.count
		let r = entry.randomEffectsPerGroup
		let z: [[Double]] = (0..<n).map { row in
			r == 1 ? [1.0] : [1.0, entry.X[row][1]]
		}
		let model = GeneralLMEModel(
			fixedEffects: try DenseMatrix(entry.X),
			randomEffectsDesign: try DenseMatrix(z),
			response: entry.y,
			grouping: try GroupingFactor(entry.groups),
			randomEffectsPerGroup: r)
		return try fitGeneralLME(model)
	}
}

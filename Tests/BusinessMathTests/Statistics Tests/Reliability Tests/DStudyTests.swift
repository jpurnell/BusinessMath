import Testing
import Foundation
@testable import BusinessMath

@Suite("D-Study — Decision Study")
struct DStudyTests {

	// MARK: - Helpers

	/// Runs a one-facet G-study on known data for reuse across D-study tests.
	private func oneFacetGResult() throws -> GStudyResult<Double> {
		// 4 subjects × 3 raters
		// sigma_p^2 = 20/3, sigma_r^2 = 1, sigma_e^2 = 0
		let data: [[Double]] = [
			[4.0, 5.0, 6.0],
			[2.0, 3.0, 4.0],
			[8.0, 9.0, 10.0],
			[6.0, 7.0, 8.0]
		]
		return try gStudy(data, facetLabel: "raters")
	}

	/// Runs a one-facet G-study with non-trivial error for meaningful D-study results.
	private func oneFacetGResultWithError() throws -> GStudyResult<Double> {
		// 5 subjects × 4 raters — data with genuine subject, rater, and error variance
		let data: [[Double]] = [
			[3.0, 5.0, 7.0, 2.0],
			[8.0, 6.0, 4.0, 9.0],
			[1.0, 2.0, 3.0, 5.0],
			[6.0, 7.0, 8.0, 4.0],
			[2.0, 3.0, 5.0, 1.0]
		]
		return try gStudy(data, facetLabel: "raters")
	}

	// MARK: - One-Facet D-Study

	@Test("D-study with same facet sizes: rho^2 matches ICC consistency concept")
	func testRhoPSquaredSameFacetSizes() throws {
		let g = try oneFacetGResultWithError()
		let d = try dStudy(g, design: ["raters": 4])

		// rho^2 should be between 0 and 1
		#expect(d.generalizabilityCoefficient >= 0.0)
		#expect(d.generalizabilityCoefficient <= 1.0)

		// Verify formula: rho^2 = sigma_p^2 / (sigma_p^2 + sigma_delta^2)
		let sigmaP = g.variancePersons
		let expected = sigmaP / (sigmaP + d.relativeErrorVariance)
		#expect(abs(d.generalizabilityCoefficient - expected) < 1e-10)
	}

	@Test("D-study with same facet sizes: Phi matches ICC absolute concept")
	func testPhiSameFacetSizes() throws {
		let g = try oneFacetGResultWithError()
		let d = try dStudy(g, design: ["raters": 4])

		// Phi should be between 0 and 1
		#expect(d.dependabilityCoefficient >= 0.0)
		#expect(d.dependabilityCoefficient <= 1.0)

		// Phi <= rho^2 always (absolute includes more error sources)
		#expect(d.dependabilityCoefficient <= d.generalizabilityCoefficient + 1e-10)

		// Verify formula: Phi = sigma_p^2 / (sigma_p^2 + sigma_Delta^2)
		let sigmaP = g.variancePersons
		let expected = sigmaP / (sigmaP + d.absoluteErrorVariance)
		#expect(abs(d.dependabilityCoefficient - expected) < 1e-10)
	}

	@Test("Doubling n_r' reduces relative error variance")
	func testDoublingRatersReducesError() throws {
		let g = try oneFacetGResultWithError()
		let d1 = try dStudy(g, design: ["raters": 2])
		let d2 = try dStudy(g, design: ["raters": 4])

		#expect(d2.relativeErrorVariance < d1.relativeErrorVariance)
		#expect(d2.absoluteErrorVariance < d1.absoluteErrorVariance)
		#expect(d2.generalizabilityCoefficient >= d1.generalizabilityCoefficient)
	}

	@Test("D-study formula verification for one-facet")
	func testOneFacetFormulaVerification() throws {
		let g = try oneFacetGResultWithError()
		let nrPrime = 6
		let d = try dStudy(g, design: ["raters": nrPrime])

		// Extract components
		let sigmaP = g.variancePersons
		let sigmaR = g.components.first { $0.source == "raters" }!.variance
		let sigmaE = g.components.first { $0.source == "p x raters" }!.variance

		// sigma_delta^2 = sigma_e^2 / n_r'
		let expectedRelative = sigmaE / Double(nrPrime)
		#expect(abs(d.relativeErrorVariance - expectedRelative) < 1e-10)

		// sigma_Delta^2 = sigma_r^2 / n_r' + sigma_e^2 / n_r'
		let expectedAbsolute = sigmaR / Double(nrPrime) + sigmaE / Double(nrPrime)
		#expect(abs(d.absoluteErrorVariance - expectedAbsolute) < 1e-10)

		// rho^2
		let expectedRho = sigmaP / (sigmaP + expectedRelative)
		#expect(abs(d.generalizabilityCoefficient - expectedRho) < 1e-10)

		// Phi
		let expectedPhi = sigmaP / (sigmaP + expectedAbsolute)
		#expect(abs(d.dependabilityCoefficient - expectedPhi) < 1e-10)

		// SEM = sqrt(sigma_Delta^2)
		#expect(abs(d.standardErrorOfMeasurement - expectedAbsolute.squareRoot()) < 1e-10)
	}

	@Test("D-study with n_r' = 1: reproduces single-rater reliability")
	func testSingleRaterReliability() throws {
		let g = try oneFacetGResultWithError()
		let d = try dStudy(g, design: ["raters": 1])

		let sigmaP = g.variancePersons
		let sigmaE = g.components.first { $0.source == "p x raters" }!.variance

		// With single rater, relative error = sigma_e^2 / 1 = sigma_e^2
		#expect(abs(d.relativeErrorVariance - sigmaE) < 1e-10)

		// rho^2 = sigma_p^2 / (sigma_p^2 + sigma_e^2)
		let expectedRho = sigmaP / (sigmaP + sigmaE)
		#expect(abs(d.generalizabilityCoefficient - expectedRho) < 1e-10)
	}

	@Test("Design facets don't match G-study throws invalidInput")
	func testMismatchedDesignFacetsThrows() throws {
		let g = try oneFacetGResult()

		#expect(throws: BusinessMathError.self) {
			let _ = try dStudy(g, design: ["items": 5])
		}
	}

	@Test("Design facet size < 1 throws invalidInput")
	func testDesignFacetSizeLessThan1Throws() throws {
		let g = try oneFacetGResult()

		#expect(throws: BusinessMathError.self) {
			let _ = try dStudy(g, design: ["raters": 0])
		}
	}

	// MARK: - Two-Facet D-Study

	@Test("Two-facet D-study formula verification")
	func testTwoFacetFormulaVerification() throws {
		// 4 persons × 2 raters × 3 items
		let data: [[[Double]]] = [
			[[3.0, 4.0, 5.0], [6.0, 7.0, 8.0]],
			[[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]],
			[[7.0, 8.0, 9.0], [2.0, 3.0, 4.0]],
			[[5.0, 6.0, 7.0], [8.0, 9.0, 1.0]]
		]

		let g = try gStudy(data, facetLabels: ("raters", "items"))
		let nrPrime = 3
		let niPrime = 5
		let d = try dStudy(g, design: ["raters": nrPrime, "items": niPrime])

		// Extract variance components
		let sigmaP = g.components.first { $0.source == "p" }!.variance
		let sigmaR = g.components.first { $0.source == "raters" }!.variance
		let sigmaI = g.components.first { $0.source == "items" }!.variance
		let sigmaPR = g.components.first { $0.source == "p x raters" }!.variance
		let sigmaPI = g.components.first { $0.source == "p x items" }!.variance
		let sigmaRI = g.components.first { $0.source == "raters x items" }!.variance
		let sigmaE = g.components.first { $0.source == "p x raters x items" }!.variance

		// sigma_delta^2 = sigma_pr/n_r' + sigma_pi/n_i' + sigma_e/(n_r'*n_i')
		let expectedRelative = sigmaPR / Double(nrPrime)
			+ sigmaPI / Double(niPrime)
			+ sigmaE / (Double(nrPrime) * Double(niPrime))
		#expect(abs(d.relativeErrorVariance - expectedRelative) < 1e-10)

		// sigma_Delta^2 = sigma_r/n_r' + sigma_i/n_i' + sigma_pr/n_r' + sigma_pi/n_i'
		//                + sigma_ri/(n_r'*n_i') + sigma_e/(n_r'*n_i')
		let expectedAbsolute = sigmaR / Double(nrPrime)
			+ sigmaI / Double(niPrime)
			+ sigmaPR / Double(nrPrime)
			+ sigmaPI / Double(niPrime)
			+ sigmaRI / (Double(nrPrime) * Double(niPrime))
			+ sigmaE / (Double(nrPrime) * Double(niPrime))
		#expect(abs(d.absoluteErrorVariance - expectedAbsolute) < 1e-10)

		// rho^2
		let expectedRho = sigmaP / (sigmaP + expectedRelative)
		#expect(abs(d.generalizabilityCoefficient - expectedRho) < 1e-10)

		// Phi
		let expectedPhi = sigmaP / (sigmaP + expectedAbsolute)
		#expect(abs(d.dependabilityCoefficient - expectedPhi) < 1e-10)

		// SEM
		#expect(abs(d.standardErrorOfMeasurement - expectedAbsolute.squareRoot()) < 1e-10)

		// Design facets
		#expect(d.designFacets["raters"] == nrPrime)
		#expect(d.designFacets["items"] == niPrime)
	}
}

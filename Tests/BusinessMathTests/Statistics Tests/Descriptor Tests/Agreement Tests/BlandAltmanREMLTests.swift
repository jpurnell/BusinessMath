import Testing
import Foundation
@testable import BusinessMath

@Suite("Bland-Altman Repeated Measures with REML")
struct BlandAltmanREMLTests {

	// MARK: - Test 11: MoM method matches existing behavior

	@Test("Method of moments matches existing blandAltmanRepeatedMeasures")
	func testMoMMatchesExistingBehavior() throws {
		let pairs: [[(x: Double, y: Double)]] = [
			[(x: 11, y: 10), (x: 12, y: 10), (x: 11, y: 10), (x: 12, y: 10)],
			[(x: 13, y: 10), (x: 14, y: 10), (x: 13, y: 10), (x: 14, y: 10)],
			[(x: 9, y: 10), (x: 10, y: 10), (x: 9, y: 10), (x: 10, y: 10)]
		]

		let existing = try blandAltmanRepeatedMeasures(pairs)
		let withMethod = try blandAltmanRepeatedMeasures(pairs, method: .methodOfMoments)

		#expect(abs(existing.bias - withMethod.bias) < 1e-12)
		#expect(abs(existing.varianceBetween - withMethod.varianceBetween) < 1e-12)
		#expect(abs(existing.varianceWithin - withMethod.varianceWithin) < 1e-12)
		#expect(abs(existing.varianceTotal - withMethod.varianceTotal) < 1e-12)
		#expect(abs(existing.loaLower - withMethod.loaLower) < 1e-12)
		#expect(abs(existing.loaUpper - withMethod.loaUpper) < 1e-12)
		#expect(existing.subjects == withMethod.subjects)
		#expect(existing.totalObservations == withMethod.totalObservations)
		#expect(abs(existing.proportionalBiasSlope - withMethod.proportionalBiasSlope) < 1e-12)
		#expect(abs(existing.coefficientOfIndividualAgreement - withMethod.coefficientOfIndividualAgreement) < 1e-12)
	}

	// MARK: - Test 12: REML produces non-negative varianceBetween

	@Test("REML method produces non-negative varianceBetween")
	func testREMLNonNegativeVarianceBetween() throws {
		let pairs: [[(x: Double, y: Double)]] = [
			[(x: 11, y: 10), (x: 12, y: 10), (x: 11, y: 10)],
			[(x: 13, y: 10), (x: 14, y: 10), (x: 13, y: 10)],
			[(x: 9, y: 10), (x: 10, y: 10), (x: 9, y: 10)],
			[(x: 15, y: 10), (x: 16, y: 10), (x: 15, y: 10)]
		]

		let result = try blandAltmanRepeatedMeasures(pairs, method: .reml)

		#expect(result.varianceBetween >= 0)
		#expect(result.varianceWithin >= 0)
		#expect(abs(result.varianceTotal - (result.varianceBetween + result.varianceWithin)) < 1e-12)
	}

	// MARK: - Test 13: Balanced design — both methods agree

	@Test("Balanced design: both methods agree within tolerance")
	func testBalancedDesignBothMethodsAgree() throws {
		// Balanced: 3 subjects x 4 replicates
		let pairs: [[(x: Double, y: Double)]] = [
			[(x: 11, y: 10), (x: 12, y: 10), (x: 11, y: 10), (x: 12, y: 10)],
			[(x: 13, y: 10), (x: 14, y: 10), (x: 13, y: 10), (x: 14, y: 10)],
			[(x: 9, y: 10), (x: 10, y: 10), (x: 9, y: 10), (x: 10, y: 10)]
		]

		let momResult = try blandAltmanRepeatedMeasures(pairs, method: .methodOfMoments)
		let remlResult = try blandAltmanRepeatedMeasures(pairs, method: .reml)

		// Both methods should agree for balanced designs
		#expect(abs(momResult.bias - remlResult.bias) < 1e-6)
		#expect(abs(momResult.varianceBetween - remlResult.varianceBetween) < 1e-3)
		#expect(abs(momResult.varianceWithin - remlResult.varianceWithin) < 1e-3)
		#expect(abs(momResult.loaLower - remlResult.loaLower) < 0.1)
		#expect(abs(momResult.loaUpper - remlResult.loaUpper) < 0.1)
	}

	// MARK: - Test 14: Unbalanced design — REML adjusts for different replicate counts

	@Test("Unbalanced design: REML adjusts for different replicate counts")
	func testUnbalancedDesignREMLAdjusts() throws {
		// Subject 1: 2 pairs, Subject 2: 5 pairs, Subject 3: 3 pairs
		let pairs: [[(x: Double, y: Double)]] = [
			[(x: 11, y: 10), (x: 12, y: 10)],
			[(x: 13, y: 10), (x: 14, y: 10), (x: 13, y: 10),
			 (x: 14, y: 10), (x: 13.5, y: 10)],
			[(x: 9, y: 10), (x: 10, y: 10), (x: 9.5, y: 10)]
		]

		let remlResult = try blandAltmanRepeatedMeasures(pairs, method: .reml)
		let momResult = try blandAltmanRepeatedMeasures(pairs, method: .methodOfMoments)

		// Both should produce valid results
		#expect(remlResult.varianceBetween >= 0)
		#expect(remlResult.varianceWithin >= 0)
		#expect(remlResult.subjects == 3)
		#expect(remlResult.totalObservations == 10)

		// Bias should be the same (both use same overall mean or GLS)
		// REML may differ slightly in bias from simple mean
		#expect(abs(remlResult.bias - momResult.bias) < 0.5)

		// REML adjusts variance estimates for unbalanced data
		// Both should produce reasonable total variance
		#expect(remlResult.varianceTotal > 0)
		#expect(momResult.varianceTotal > 0)
	}
}

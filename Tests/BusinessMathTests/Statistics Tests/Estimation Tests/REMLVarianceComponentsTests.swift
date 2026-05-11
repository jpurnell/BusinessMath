import Testing
import Foundation
@testable import BusinessMath

@Suite("REML Variance Components")
struct REMLVarianceComponentsTests {

	// MARK: - Test 1: Balanced groups — REML matches MoM within tolerance

	@Test("Balanced groups: REML matches method-of-moments within tolerance")
	func testBalancedGroupsREMLMatchesMoM() throws {
		// 5 groups x 4 observations each, well-separated means
		let groups: [[Double]] = [
			[10.0, 11.0, 10.5, 10.8],
			[20.0, 21.0, 20.5, 20.8],
			[15.0, 16.0, 15.5, 15.8],
			[25.0, 26.0, 25.5, 25.8],
			[30.0, 31.0, 30.5, 30.8]
		]

		let remlResult = try remlVarianceComponents(groups)
		let anova = try oneWayANOVA(groups)

		// MoM estimates: sigma_e^2 = MS_within, sigma_u^2 = (MS_between - MS_within) / k
		let momWithin = anova.msWithin
		let k = Double(groups[0].count) // balanced: all groups same size
		let momBetween = max(0.0, (anova.msBetween - anova.msWithin) / k)

		// REML and MoM converge for balanced designs; use relative tolerance
		// (within-group variance is small so absolute tolerance works;
		// between-group variance is large so use relative check)
		#expect(abs(remlResult.varianceWithin - momWithin) < 0.01)
		let relBetween = abs(remlResult.varianceBetween - momBetween) / max(momBetween, 1e-12)
		#expect(relBetween < 0.01, "REML and MoM between-variance differ by more than 1%")
	}

	// MARK: - Test 2: Unbalanced groups — non-negative variances

	@Test("Unbalanced groups: REML produces non-negative variances")
	func testUnbalancedGroupsNonNegativeVariances() throws {
		let groups: [[Double]] = [
			[5.0, 6.0, 5.5],
			[10.0, 11.0, 10.5, 10.8, 10.2],
			[7.0, 8.0],
			[15.0, 16.0, 15.5, 15.8]
		]

		let result = try remlVarianceComponents(groups)

		#expect(result.varianceBetween >= 0)
		#expect(result.varianceWithin >= 0)
		#expect(abs(result.varianceTotal - (result.varianceBetween + result.varianceWithin)) < 1e-12)
	}

	// MARK: - Test 3: Data where MoM gives negative between-variance

	@Test("MoM negative between-variance case: REML gives sigma_u^2 >= 0")
	func testMoMNegativeBetweenVarianceCase() throws {
		// Groups with very similar means but high within-group variance
		// This can cause MoM to estimate negative between-group variance
		let groups: [[Double]] = [
			[1.0, 100.0, 50.0],    // mean ~50.3, huge within-variance
			[2.0, 99.0, 51.0],     // mean ~50.7, huge within-variance
			[0.0, 101.0, 49.0],    // mean  50.0, huge within-variance
			[3.0, 98.0, 52.0]      // mean ~51.0, huge within-variance
		]

		let result = try remlVarianceComponents(groups)

		// REML should clamp to non-negative
		#expect(result.varianceBetween >= 0)
		#expect(result.varianceWithin > 0)
	}

	// MARK: - Test 4: All within-group variation (identical group means)

	@Test("All within-group variation: sigma_u^2 near zero")
	func testAllWithinGroupVariation() throws {
		// All groups have the same mean (10) but different spreads
		let groups: [[Double]] = [
			[8.0, 12.0],   // mean = 10
			[9.0, 11.0],   // mean = 10
			[7.0, 13.0],   // mean = 10
			[6.0, 14.0]    // mean = 10
		]

		let result = try remlVarianceComponents(groups)

		// Between-group variance should be near zero
		#expect(result.varianceBetween < 1e-4)
		// Within-group variance should be positive
		#expect(result.varianceWithin > 0)
	}

	// MARK: - Test 5: All between-group variation (zero within-group variance)

	@Test("All between-group variation: sigma_e^2 near zero, sigma_u^2 dominates")
	func testAllBetweenGroupVariation() throws {
		// All observations within each group are identical
		let groups: [[Double]] = [
			[5.0, 5.0, 5.0],
			[10.0, 10.0, 10.0],
			[15.0, 15.0, 15.0],
			[20.0, 20.0, 20.0]
		]

		let result = try remlVarianceComponents(groups)

		// Within-group variance should be near zero
		#expect(result.varianceWithin < 1e-6)
		// Between-group variance should dominate
		#expect(result.varianceBetween > 0)
		// Total should roughly equal between
		#expect(abs(result.varianceTotal - result.varianceBetween) < 1e-6)
	}

	// MARK: - Test 6: Convergence within default iterations

	@Test("Converges within default iterations for well-conditioned data")
	func testConvergesWithDefaultIterations() throws {
		let groups: [[Double]] = [
			[10.0, 11.0, 10.5, 10.8],
			[20.0, 21.0, 20.5, 20.8],
			[15.0, 16.0, 15.5, 15.8],
			[25.0, 26.0, 25.5, 25.8],
			[30.0, 31.0, 30.5, 30.8]
		]

		let result = try remlVarianceComponents(groups)

		#expect(result.converged == true)
		#expect(result.iterations < 100)
	}

	// MARK: - Test 7: Restricted log-likelihood is finite

	@Test("Restricted log-likelihood is finite for valid data")
	func testRestrictedLogLikelihoodFinite() throws {
		let groups: [[Double]] = [
			[10.0, 11.0, 10.5],
			[20.0, 21.0, 20.5],
			[15.0, 16.0, 15.5]
		]

		let result = try remlVarianceComponents(groups)

		#expect(result.restrictedLogLikelihood.isFinite)
		#expect(result.converged == true)
	}

	// MARK: - Test 8: Fixed intercept matches weighted grand mean

	@Test("Fixed intercept matches GLS weighted grand mean")
	func testFixedInterceptMatchesWeightedGrandMean() throws {
		// For balanced design, GLS intercept = simple grand mean
		let groups: [[Double]] = [
			[10.0, 12.0, 11.0],
			[20.0, 22.0, 21.0],
			[30.0, 32.0, 31.0]
		]

		let result = try remlVarianceComponents(groups)

		// Grand mean = (10+12+11+20+22+21+30+32+31) / 9 = 189/9 = 21.0
		let allValues = groups.flatMap { $0 }
		let grandMean = allValues.reduce(0.0, +) / Double(allValues.count)

		// For balanced designs, the GLS estimate should be close to grand mean
		#expect(abs(result.fixedIntercept - grandMean) < 0.5)
	}

	// MARK: - Test 9: Fewer than 2 groups throws insufficientData

	@Test("Fewer than 2 groups throws insufficientData")
	func testFewerThan2GroupsThrows() throws {
		let groups: [[Double]] = [
			[1.0, 2.0, 3.0]
		]

		#expect(throws: BusinessMathError.self) {
			let _ = try remlVarianceComponents(groups)
		}
	}

	// MARK: - Test 10: Single observation per group (edge case)

	@Test("Single observation per group handles gracefully")
	func testSingleObservationPerGroup() throws {
		// Each group has exactly 1 observation: df_within = 0
		// This is degenerate; algorithm should still not crash
		let groups: [[Double]] = [
			[5.0],
			[10.0],
			[15.0]
		]

		// Should throw because we need within-group df > 0
		// or handle gracefully by returning a degenerate result
		#expect(throws: BusinessMathError.self) {
			let _ = try remlVarianceComponents(groups)
		}
	}
}

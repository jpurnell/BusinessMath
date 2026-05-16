import Testing
@testable import BusinessMath

@Suite("LME Diagnostics")
struct LMEDiagnosticsTests {

	// MARK: - Shared Test Data

	/// Clustered data: 4 groups with distinct baselines (~10, ~20, ~15, ~25).
	/// Strong between-group variance, small within-group noise.
	private func fittedModel() throws -> (result: RandomInterceptResult<Double>, grouping: GroupingFactor) {
		let y: [Double] = [
			10.2, 9.8, 10.0,
			20.5, 19.7, 20.3,
			14.8, 15.3, 15.0,
			25.1, 24.9, 25.2
		]
		let groups = [0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3]
		let grouping = try GroupingFactor(groups)
		let X = DenseMatrix<Double>(rows: 12, columns: 1, repeating: 1.0)
		let model = RandomInterceptModel(fixedEffects: X, response: y, grouping: grouping)
		let result = try fitRandomIntercept(model)
		return (result, grouping)
	}

	// MARK: - Standardized Residuals

	@Test("Standardized residuals mean is approximately zero")
	func standardizedResidualsMeanZero() throws {
		let (result, _) = try fittedModel()
		let stdResid = standardizedResiduals(result)
		let m = mean(stdResid)
		#expect(abs(m) < 0.1)
	}

	@Test("Standardized residuals SD is approximately one")
	func standardizedResidualsSDOne() throws {
		let (result, _) = try fittedModel()
		let stdResid = standardizedResiduals(result)
		let sd = stdDev(stdResid, .sample)
		#expect(abs(sd - 1.0) < 0.5)
	}

	// MARK: - Pearson Residuals

	@Test("Pearson residuals mean is approximately zero")
	func pearsonResidualsMeanZero() throws {
		let (result, _) = try fittedModel()
		let pResid = pearsonResiduals(result)
		let m = mean(pResid)
		#expect(abs(m) < 0.1)
	}

	@Test("Pearson residuals use marginal residuals, not conditional")
	func pearsonUsesMarginialResiduals() throws {
		let (result, _) = try fittedModel()
		let pResid = pearsonResiduals(result)

		// Pearson residuals = marginalResiduals / sqrt(totalVar).
		// Verify by reconstructing: pResid[i] * sqrt(totalVar) should equal marginalResiduals[i].
		let totalVar = result.varianceRandom + result.varianceResidual
		let scale = (totalVar).squareRoot()
		for i in 0..<result.observations {
			let reconstructed = pResid[i] * scale
			#expect(abs(reconstructed - result.marginalResiduals[i]) < 1e-10)
		}
	}

	// MARK: - QQ-Plot Data

	@Test("QQ data returns correct count")
	func qqDataCount() throws {
		let (result, _) = try fittedModel()
		let stdResid = standardizedResiduals(result)
		let qq = qqNormalData(stdResid)
		#expect(qq.count == stdResid.count)
	}

	@Test("QQ theoretical quantiles are sorted ascending")
	func qqTheoreticalSorted() throws {
		let (result, _) = try fittedModel()
		let stdResid = standardizedResiduals(result)
		let qq = qqNormalData(stdResid)
		for i in 1..<qq.count {
			#expect(qq[i].theoretical >= qq[i - 1].theoretical)
		}
	}

	@Test("QQ symmetry: first theoretical approximately equals negative of last")
	func qqSymmetry() throws {
		let (result, _) = try fittedModel()
		let stdResid = standardizedResiduals(result)
		let qq = qqNormalData(stdResid)
		guard let first = qq.first, let last = qq.last else {
			Issue.record("QQ data is empty")
			return
		}
		#expect(abs(first.theoretical + last.theoretical) < 0.3)
	}

	@Test("QQ single point works")
	func qqSinglePoint() {
		let qq = qqNormalData([42.0])
		#expect(qq.count == 1)
		#expect(abs(qq[0].theoretical) < 0.5) // median quantile ~ 0
	}

	@Test("QQ empty input returns empty")
	func qqEmptyInput() {
		let qq: [QQPoint<Double>] = qqNormalData([])
		#expect(qq.isEmpty)
	}

	// MARK: - Group Influence

	@Test("Group influence values are all non-negative")
	func groupInfluenceNonNegative() throws {
		let (result, grouping) = try fittedModel()
		let influence = groupInfluence(result, grouping: grouping)
		for d in influence {
			#expect(d >= 0.0)
		}
	}

	@Test("Group influence: extreme group has larger influence")
	func groupInfluenceExtreme() throws {
		let (result, grouping) = try fittedModel()
		let influence = groupInfluence(result, grouping: grouping)

		// Group 3 (mean ~25) is farthest from grand mean (~17.5),
		// so it should have the largest influence
		guard influence.count == 4 else {
			Issue.record("Expected 4 influence values, got \(influence.count)")
			return
		}
		// Group 3 (index 3) should have large influence
		// Group 2 (index 2, mean ~15) is closest to grand mean, should have smallest
		#expect(influence[3] > influence[2])
	}

	// MARK: - Nakagawa R²

	@Test("Nakagawa R² marginal is in [0, 1]")
	func nakagawaR2MarginalBounded() throws {
		let (result, _) = try fittedModel()
		let r2 = nakagawaR2(result)
		#expect(r2.marginal >= 0.0)
		#expect(r2.marginal <= 1.0)
	}

	@Test("Nakagawa R² conditional >= marginal")
	func nakagawaR2ConditionalGEMarginal() throws {
		let (result, _) = try fittedModel()
		let r2 = nakagawaR2(result)
		#expect(r2.conditional >= r2.marginal - 1e-10)
	}

	@Test("Nakagawa R² conditional near 1 for strongly clustered data")
	func nakagawaR2ConditionalHighForClustered() throws {
		let (result, _) = try fittedModel()
		let r2 = nakagawaR2(result)
		// Strong clustering: random effects explain most variance
		#expect(r2.conditional > 0.9)
	}

	@Test("Nakagawa R² marginal near 0 for intercept-only model")
	func nakagawaR2MarginalNearZeroInterceptOnly() throws {
		let (result, _) = try fittedModel()
		let r2 = nakagawaR2(result)
		// Intercept-only fixed effects: no fixed predictors explain variance
		// R²_m should be near 0 (variance of fitted_fixed is near 0)
		#expect(r2.marginal < 0.1)
	}

	// MARK: - Within-Group Autocorrelation

	@Test("Autocorrelation near zero for independent residuals")
	func autocorrelationNearZero() throws {
		let (result, grouping) = try fittedModel()
		let rho = withinGroupAutocorrelation(residuals: result.residuals, grouping: grouping)
		// Residuals from well-specified model should have low autocorrelation
		#expect(abs(rho) < 0.8)
	}

	@Test("Autocorrelation handles single-obs groups gracefully")
	func autocorrelationSingleObsGroups() throws {
		// Mix of group sizes: groups with 1 obs should be skipped
		let y: [Double] = [10.0, 20.0, 20.5, 30.0, 30.5, 30.0]
		let groups = [0, 1, 1, 2, 2, 2]
		let grouping = try GroupingFactor(groups)
		let residuals: [Double] = [0.1, -0.2, 0.3, 0.1, -0.1, 0.0]
		let rho = withinGroupAutocorrelation(residuals: residuals, grouping: grouping)
		#expect(rho.isFinite)
	}

	@Test("Autocorrelation of empty residuals returns zero")
	func autocorrelationEmpty() throws {
		let grouping = try GroupingFactor([0])
		let rho = withinGroupAutocorrelation(residuals: [0.0], grouping: grouping)
		// Single obs group => no lag-1 pairs => return 0
		#expect(abs(rho - 0.0) < 1e-6)
	}
}

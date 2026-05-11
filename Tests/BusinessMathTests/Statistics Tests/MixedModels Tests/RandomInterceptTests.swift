import Testing
@testable import BusinessMath

@Suite("Random Intercept LME Model")
struct RandomInterceptTests {

	// Test data: 4 subjects, 3 measurements each
	// Subjects have different baselines: 10, 20, 15, 25
	// sigma_u² ~ 31.25 (between-group), sigma_e² ~ 1.0 (within-group)
	let testData: (y: [Double], groups: [Int], X: DenseMatrix<Double>) = {
		let y: [Double] = [
			10.2, 9.8, 10.0,     // Subject 0: baseline ~10
			20.5, 19.7, 20.3,    // Subject 1: baseline ~20
			14.8, 15.3, 15.0,    // Subject 2: baseline ~15
			25.1, 24.9, 25.2     // Subject 3: baseline ~25
		]
		let groups = [0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3]
		// Intercept-only: single column of 1s
		let X = DenseMatrix<Double>(rows: 12, columns: 1, repeating: 1.0)
		return (y, groups, X)
	}()

	@Test("Intercept-only model: ICC is high for clustered data")
	func interceptOnlyHighICC() throws {
		let grouping = try GroupingFactor(testData.groups)
		let model = RandomInterceptModel(
			fixedEffects: testData.X, response: testData.y, grouping: grouping)
		let result = try fitRandomIntercept(model)

		// Strong clustering: ICC should be high (>0.9)
		#expect(result.icc > 0.9)
		#expect(result.converged)
		#expect(result.varianceRandom > result.varianceResidual)
	}

	@Test("Intercept-only model: beta[0] is close to grand mean")
	func interceptApproximatesGrandMean() throws {
		let grouping = try GroupingFactor(testData.groups)
		let model = RandomInterceptModel(
			fixedEffects: testData.X, response: testData.y, grouping: grouping)
		let result = try fitRandomIntercept(model)

		let grandMean = testData.y.reduce(0.0, +) / Double(testData.y.count)
		#expect(abs(result.beta[0] - grandMean) < 1.0)
	}

	@Test("BLUPs reflect group-level deviations")
	func blupReflectGroups() throws {
		let grouping = try GroupingFactor(testData.groups)
		let model = RandomInterceptModel(
			fixedEffects: testData.X, response: testData.y, grouping: grouping)
		let result = try fitRandomIntercept(model)

		// Subject 3 (mean ~25) should have highest BLUP
		// Subject 0 (mean ~10) should have lowest BLUP
		#expect(result.randomEffects[3] > result.randomEffects[0])
		#expect(result.randomEffects[1] > result.randomEffects[2])
	}

	@Test("Residuals sum approximately to zero")
	func residualsSumToZero() throws {
		let grouping = try GroupingFactor(testData.groups)
		let model = RandomInterceptModel(
			fixedEffects: testData.X, response: testData.y, grouping: grouping)
		let result = try fitRandomIntercept(model)

		let residSum = result.residuals.reduce(0.0, +)
		#expect(abs(residSum) < 0.1)
	}

	@Test("Conditional residuals smaller than marginal")
	func conditionalSmallerThanMarginal() throws {
		let grouping = try GroupingFactor(testData.groups)
		let model = RandomInterceptModel(
			fixedEffects: testData.X, response: testData.y, grouping: grouping)
		let result = try fitRandomIntercept(model)

		let condVar = result.residuals.reduce(0.0) { $0 + $1 * $1 } / Double(result.observations)
		let margVar = result.marginalResiduals.reduce(0.0) { $0 + $1 * $1 } / Double(result.observations)
		#expect(condVar < margVar)
	}

	@Test("No group effect: ICC near zero")
	func noGroupEffectLowICC() throws {
		// All observations from same distribution (no clustering)
		let y: [Double] = [5.1, 4.9, 5.0, 5.2, 4.8, 5.1, 5.0, 4.9, 5.1, 5.0, 5.2, 4.8]
		let groups = [0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3]
		let grouping = try GroupingFactor(groups)
		let X = DenseMatrix<Double>(rows: 12, columns: 1, repeating: 1.0)
		let model = RandomInterceptModel(fixedEffects: X, response: y, grouping: grouping)
		let result = try fitRandomIntercept(model)

		#expect(result.icc < 0.3)
		#expect(result.converged)
	}

	@Test("Model with covariate reduces between-group variance")
	func covariateReducesVariance() throws {
		// Subjects with different ages, scores increase with age
		let ages: [Double] = [25, 25, 25, 35, 35, 35, 45, 45, 45, 55, 55, 55]
		let y: [Double] = [50.2, 49.8, 50.0, 55.5, 54.7, 55.3, 59.8, 60.3, 60.0, 65.1, 64.9, 65.2]
		let groups = [0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3]
		let grouping = try GroupingFactor(groups)

		// Without covariate (intercept only)
		let X0 = DenseMatrix<Double>(rows: 12, columns: 1, repeating: 1.0)
		let model0 = RandomInterceptModel(fixedEffects: X0, response: y, grouping: grouping)
		let result0 = try fitRandomIntercept(model0)

		// With age covariate (intercept + age)
		let X1 = try DenseMatrix(ages.map { [1.0, $0] })
		let model1 = RandomInterceptModel(fixedEffects: X1, response: y, grouping: grouping)
		let result1 = try fitRandomIntercept(model1)

		// Adding the covariate should reduce random variance (age explains between-group differences)
		#expect(result1.varianceRandom < result0.varianceRandom)
		// Adjusted ICC should be lower
		#expect(result1.icc < result0.icc)
	}

	@Test("Convergence within 20 iterations for well-conditioned data")
	func convergenceSpeed() throws {
		let grouping = try GroupingFactor(testData.groups)
		let model = RandomInterceptModel(
			fixedEffects: testData.X, response: testData.y, grouping: grouping)
		let result = try fitRandomIntercept(model)

		#expect(result.converged)
		#expect(result.iterations <= 20)
	}

	@Test("Non-convergence with maxIterations=1")
	func nonConvergence() throws {
		let grouping = try GroupingFactor(testData.groups)
		let model = RandomInterceptModel(
			fixedEffects: testData.X, response: testData.y, grouping: grouping)
		let result = try fitRandomIntercept(model, maxIterations: 1)

		#expect(!result.converged)
		#expect(result.iterations == 1)
	}

	@Test("Fewer than 2 groups throws")
	func tooFewGroups() throws {
		let grouping = try GroupingFactor([0, 0, 0])
		let X = DenseMatrix<Double>(rows: 3, columns: 1, repeating: 1.0)
		let model = RandomInterceptModel(fixedEffects: X, response: [1.0, 2.0, 3.0], grouping: grouping)
		#expect(throws: BusinessMathError.self) {
			try fitRandomIntercept(model)
		}
	}

	@Test("Dimension mismatch between X and y throws")
	func dimensionMismatch() throws {
		let grouping = try GroupingFactor([0, 0, 1, 1])
		let X = DenseMatrix<Double>(rows: 3, columns: 1, repeating: 1.0) // Wrong: 3 rows vs 4 obs
		let model = RandomInterceptModel(fixedEffects: X, response: [1.0, 2.0, 3.0, 4.0], grouping: grouping)
		#expect(throws: BusinessMathError.self) {
			try fitRandomIntercept(model)
		}
	}

	@Test("AIC and BIC are finite")
	func infocriteriaFinite() throws {
		let grouping = try GroupingFactor(testData.groups)
		let model = RandomInterceptModel(
			fixedEffects: testData.X, response: testData.y, grouping: grouping)
		let result = try fitRandomIntercept(model)

		#expect(result.aic.isFinite)
		#expect(result.bic.isFinite)
	}

	@Test("Standard errors are positive")
	func standardErrorsPositive() throws {
		let grouping = try GroupingFactor(testData.groups)
		let model = RandomInterceptModel(
			fixedEffects: testData.X, response: testData.y, grouping: grouping)
		let result = try fitRandomIntercept(model)

		for se in result.standardErrors {
			#expect(se > 0.0)
		}
	}

	@Test("Unbalanced design: varying group sizes")
	func unbalancedDesign() throws {
		let y: [Double] = [10.0, 10.5, 20.0, 20.5, 20.0, 30.0, 30.5, 30.0, 30.5]
		let groups = [0, 0, 1, 1, 1, 2, 2, 2, 2]
		let grouping = try GroupingFactor(groups)
		let X = DenseMatrix<Double>(rows: 9, columns: 1, repeating: 1.0)
		let model = RandomInterceptModel(fixedEffects: X, response: y, grouping: grouping)
		let result = try fitRandomIntercept(model)

		#expect(result.converged)
		#expect(result.icc > 0.8)
		#expect(result.varianceRandom > 0.0)
		#expect(result.varianceResidual > 0.0)
	}

	@Test("Fitted values plus residuals equal observed values")
	func fittedPlusResidEqualsY() throws {
		let grouping = try GroupingFactor(testData.groups)
		let model = RandomInterceptModel(
			fixedEffects: testData.X, response: testData.y, grouping: grouping)
		let result = try fitRandomIntercept(model)

		for i in 0..<testData.y.count {
			#expect(abs(result.fittedValues[i] + result.residuals[i] - testData.y[i]) < 1e-8)
		}
	}
}

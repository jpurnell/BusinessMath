import Testing
@testable import BusinessMath

@Suite("Random Slope LME Model")
struct RandomSlopeTests {

	// Test data: 4 groups, 5 observations each
	// Group intercepts: [10, 20, 25, 15]
	// Group slopes: [2.0, 0.5, 1.0, 1.5] (NOT correlated with intercepts)
	// x values: [1, 2, 3, 4, 5] for each group
	// y_ij = intercept_i + slope_i * x_j + small noise
	let testData: (y: [Double], groups: [Int], X: DenseMatrix<Double>) = {
		// intercepts:  10,   20,   25,   15
		// slopes:       2.0,  0.5,  1.0,  1.5
		let y: [Double] = [
			// Group 0: 10 + 2.0*x + noise
			12.1, 14.0, 15.9, 18.1, 19.9,
			// Group 1: 20 + 0.5*x + noise
			20.6, 21.0, 21.4, 22.1, 22.4,
			// Group 2: 25 + 1.0*x + noise
			26.1, 26.9, 28.1, 29.0, 29.9,
			// Group 3: 15 + 1.5*x + noise
			16.6, 18.1, 19.4, 21.1, 22.4
		]
		let groups = [0, 0, 0, 0, 0,
					  1, 1, 1, 1, 1,
					  2, 2, 2, 2, 2,
					  3, 3, 3, 3, 3]
		// Design matrix: intercept column + slope column (x)
		let xVals: [Double] = [1, 2, 3, 4, 5, 1, 2, 3, 4, 5, 1, 2, 3, 4, 5, 1, 2, 3, 4, 5]
		let xRows = xVals.map { [1.0, $0] }
		// Force-try is forbidden, so we use a do-catch that falls back to a dummy
		let X: DenseMatrix<Double>
		do {
			X = try DenseMatrix(xRows)
		} catch {
			X = DenseMatrix<Double>(rows: 20, columns: 2, repeating: 0.0)
		}
		return (y, groups, X)
	}()

	// MARK: - Test 1: Basic random slope model fits with known clustered data

	@Test("Basic random slope model fits and converges")
	func basicFitConverges() throws {
		let grouping = try GroupingFactor(testData.groups)
		let model = RandomSlopeModel(
			fixedEffects: testData.X, response: testData.y,
			grouping: grouping, slopeColumn: 1)
		let result = try fitRandomSlope(model)

		#expect(result.converged)
		#expect(result.observations == 20)
		#expect(result.groups == 4)
		#expect(result.fixedEffectsCount == 2)
	}

	// MARK: - Test 2: Beta estimates close to true values

	@Test("Fixed effects beta close to population means")
	func betaCloseToTrueValues() throws {
		let grouping = try GroupingFactor(testData.groups)
		let model = RandomSlopeModel(
			fixedEffects: testData.X, response: testData.y,
			grouping: grouping, slopeColumn: 1)
		let result = try fitRandomSlope(model)

		// Population intercept ~ mean([10,20,25,15]) = 17.5
		// Population slope ~ mean([2.0,0.5,1.0,1.5]) = 1.25
		#expect(abs(result.beta[0] - 17.5) < 3.0)
		#expect(abs(result.beta[1] - 1.25) < 0.5)
	}

	// MARK: - Test 3: BLUPs reflect group-level slope deviations

	@Test("BLUPs reflect group-level slope deviations")
	func blupReflectSlopeDeviations() throws {
		let grouping = try GroupingFactor(testData.groups)
		let model = RandomSlopeModel(
			fixedEffects: testData.X, response: testData.y,
			grouping: grouping, slopeColumn: 1)
		let result = try fitRandomSlope(model)

		// Group 0 (slope=2.0) should have highest random slope BLUP
		// Group 1 (slope=0.5) should have lowest random slope BLUP
		#expect(result.randomSlopes[0] > result.randomSlopes[1])
		// Group 3 (slope=1.5) > Group 2 (slope=1.0)
		#expect(result.randomSlopes[3] > result.randomSlopes[2])
	}

	// MARK: - Test 4: Convergence within 20 iterations

	@Test("Convergence within 20 iterations for well-conditioned data")
	func convergenceSpeed() throws {
		let grouping = try GroupingFactor(testData.groups)
		let model = RandomSlopeModel(
			fixedEffects: testData.X, response: testData.y,
			grouping: grouping, slopeColumn: 1)
		let result = try fitRandomSlope(model)

		#expect(result.converged)
		#expect(result.iterations <= 20)
	}

	// MARK: - Test 5: Residuals sum approximately to zero

	@Test("Residuals sum approximately to zero")
	func residualsSumToZero() throws {
		let grouping = try GroupingFactor(testData.groups)
		let model = RandomSlopeModel(
			fixedEffects: testData.X, response: testData.y,
			grouping: grouping, slopeColumn: 1)
		let result = try fitRandomSlope(model)

		let residSum = result.residuals.reduce(0.0, +)
		#expect(abs(residSum) < 1.0)
	}

	// MARK: - Test 6: Fitted + residuals = observed

	@Test("Fitted values plus residuals equal observed values")
	func fittedPlusResidEqualsY() throws {
		let grouping = try GroupingFactor(testData.groups)
		let model = RandomSlopeModel(
			fixedEffects: testData.X, response: testData.y,
			grouping: grouping, slopeColumn: 1)
		let result = try fitRandomSlope(model)

		for i in 0..<testData.y.count {
			#expect(abs(result.fittedValues[i] + result.residuals[i] - testData.y[i]) < 1e-8)
		}
	}

	// MARK: - Test 7: Correlation between -1 and 1

	@Test("Correlation between intercept and slope is in [-1, 1]")
	func correlationInRange() throws {
		let grouping = try GroupingFactor(testData.groups)
		let model = RandomSlopeModel(
			fixedEffects: testData.X, response: testData.y,
			grouping: grouping, slopeColumn: 1)
		let result = try fitRandomSlope(model)

		#expect(result.correlationInterceptSlope >= -1.0)
		#expect(result.correlationInterceptSlope <= 1.0)
	}

	// MARK: - Test 8: Variance components non-negative

	@Test("Variance components are non-negative")
	func varianceComponentsNonNegative() throws {
		let grouping = try GroupingFactor(testData.groups)
		let model = RandomSlopeModel(
			fixedEffects: testData.X, response: testData.y,
			grouping: grouping, slopeColumn: 1)
		let result = try fitRandomSlope(model)

		#expect(result.varianceIntercept >= 0.0)
		#expect(result.varianceSlope >= 0.0)
		#expect(result.varianceResidual > 0.0)
	}

	// MARK: - Test 9: AIC/BIC finite

	@Test("AIC and BIC are finite")
	func infocriteriaFinite() throws {
		let grouping = try GroupingFactor(testData.groups)
		let model = RandomSlopeModel(
			fixedEffects: testData.X, response: testData.y,
			grouping: grouping, slopeColumn: 1)
		let result = try fitRandomSlope(model)

		#expect(result.aic.isFinite)
		#expect(result.bic.isFinite)
	}

	// MARK: - Test 10: Standard errors positive

	@Test("Standard errors are positive")
	func standardErrorsPositive() throws {
		let grouping = try GroupingFactor(testData.groups)
		let model = RandomSlopeModel(
			fixedEffects: testData.X, response: testData.y,
			grouping: grouping, slopeColumn: 1)
		let result = try fitRandomSlope(model)

		for se in result.standardErrors {
			#expect(se > 0.0)
		}
	}

	// MARK: - Test 11: Dimension mismatch throws

	@Test("Dimension mismatch between X rows and y length throws")
	func dimensionMismatch() throws {
		let grouping = try GroupingFactor([0, 0, 1, 1])
		let X = try DenseMatrix([[1.0, 1.0], [1.0, 2.0], [1.0, 3.0]]) // 3 rows vs 4 obs
		let model = RandomSlopeModel(
			fixedEffects: X, response: [1.0, 2.0, 3.0, 4.0],
			grouping: grouping, slopeColumn: 1)
		#expect(throws: BusinessMathError.self) {
			try fitRandomSlope(model)
		}
	}

	// MARK: - Test 12: slopeColumn out of range throws

	@Test("slopeColumn out of range throws")
	func slopeColumnOutOfRange() throws {
		let grouping = try GroupingFactor(testData.groups)
		// slopeColumn = 5 but X only has 2 columns
		let model = RandomSlopeModel(
			fixedEffects: testData.X, response: testData.y,
			grouping: grouping, slopeColumn: 5)
		#expect(throws: BusinessMathError.self) {
			try fitRandomSlope(model)
		}
	}

	// MARK: - Test 12b: Negative slopeColumn throws

	@Test("Negative slopeColumn throws")
	func negativeSlopeColumn() throws {
		let grouping = try GroupingFactor(testData.groups)
		let model = RandomSlopeModel(
			fixedEffects: testData.X, response: testData.y,
			grouping: grouping, slopeColumn: -1)
		#expect(throws: BusinessMathError.self) {
			try fitRandomSlope(model)
		}
	}

	// MARK: - Test 13: Fewer than 2 groups throws

	@Test("Fewer than 2 groups throws")
	func tooFewGroups() throws {
		let grouping = try GroupingFactor([0, 0, 0, 0, 0])
		let X = try DenseMatrix([[1.0, 1.0], [1.0, 2.0], [1.0, 3.0], [1.0, 4.0], [1.0, 5.0]])
		let model = RandomSlopeModel(
			fixedEffects: X, response: [1.0, 2.0, 3.0, 4.0, 5.0],
			grouping: grouping, slopeColumn: 1)
		#expect(throws: BusinessMathError.self) {
			try fitRandomSlope(model)
		}
	}

	// MARK: - Test 14: Unbalanced design works

	@Test("Unbalanced design: varying group sizes")
	func unbalancedDesign() throws {
		// Group 0: 3 obs (intercept ~10, slope ~2.0)
		// Group 1: 4 obs (intercept ~20, slope ~0.5)
		// Group 2: 5 obs (intercept ~15, slope ~1.0)
		// Intercepts and slopes NOT correlated
		let y: [Double] = [
			12.1, 14.0, 15.9,                  // Group 0: 10 + 2.0*x
			20.6, 21.0, 21.6, 22.1,            // Group 1: 20 + 0.5*x
			16.1, 16.9, 18.1, 19.0, 19.9       // Group 2: 15 + 1.0*x
		]
		let groups = [0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 2]
		let xVals: [Double] = [1, 2, 3, 1, 2, 3, 4, 1, 2, 3, 4, 5]
		let xRows = xVals.map { [1.0, $0] }
		let X = try DenseMatrix(xRows)
		let grouping = try GroupingFactor(groups)

		let model = RandomSlopeModel(
			fixedEffects: X, response: y,
			grouping: grouping, slopeColumn: 1)
		let result = try fitRandomSlope(model)

		#expect(result.converged)
		#expect(result.observations == 12)
		#expect(result.groups == 3)
		#expect(result.varianceResidual > 0.0)
	}

	// MARK: - Test 15: Near-zero slope variance approximates random intercept

	@Test("Mixed slope variance: groups with moderate slope differences")
	func moderateSlopeVariation() throws {
		// Groups have moderate slope differences (not degenerate)
		// Intercepts: [10, 15, 20, 25]
		// Slopes: [0.8, 1.2, 0.9, 1.1]
		// Moderate intercept variance (~35), small slope variance (~0.03)
		let y: [Double] = [
			// Group 0: 10 + 0.8*x + noise
			10.9, 11.5, 12.5, 13.1, 14.1,
			// Group 1: 15 + 1.2*x + noise
			16.3, 17.3, 18.7, 19.9, 21.1,
			// Group 2: 20 + 0.9*x + noise
			21.0, 21.7, 22.8, 23.5, 24.6,
			// Group 3: 25 + 1.1*x + noise
			26.2, 27.1, 28.4, 29.3, 30.6
		]
		let groups = [0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3]
		let xVals: [Double] = [1, 2, 3, 4, 5, 1, 2, 3, 4, 5, 1, 2, 3, 4, 5, 1, 2, 3, 4, 5]
		let xRows = xVals.map { [1.0, $0] }
		let X = try DenseMatrix(xRows)
		let grouping = try GroupingFactor(groups)

		let model = RandomSlopeModel(
			fixedEffects: X, response: y,
			grouping: grouping, slopeColumn: 1)
		let result = try fitRandomSlope(model)

		#expect(result.converged)
		// Slope variance should be smaller than intercept variance
		// (intercept differences are much larger than slope differences)
		#expect(result.varianceSlope < result.varianceIntercept)
		// The intercept variance should be substantial
		#expect(result.varianceIntercept > 1.0)
	}

	// MARK: - Test 16: Marginal residuals are y - X*beta

	@Test("Marginal residuals equal y minus X*beta")
	func marginalResidualsCorrect() throws {
		let grouping = try GroupingFactor(testData.groups)
		let model = RandomSlopeModel(
			fixedEffects: testData.X, response: testData.y,
			grouping: grouping, slopeColumn: 1)
		let result = try fitRandomSlope(model)

		for i in 0..<testData.y.count {
			var xBeta = 0.0
			for j in 0..<result.fixedEffectsCount {
				xBeta += testData.X[i, j] * result.beta[j]
			}
			let expected = testData.y[i] - xBeta
			#expect(abs(result.marginalResiduals[i] - expected) < 1e-8)
		}
	}

	// MARK: - Test 17: Grouping factor length mismatch throws

	@Test("GroupingFactor length mismatch with y throws")
	func groupingLengthMismatch() throws {
		let grouping = try GroupingFactor([0, 0, 1, 1, 2, 2]) // 6 groups
		let X = try DenseMatrix([[1.0, 1.0], [1.0, 2.0], [1.0, 3.0], [1.0, 4.0]]) // 4 rows
		let model = RandomSlopeModel(
			fixedEffects: X, response: [1.0, 2.0, 3.0, 4.0],
			grouping: grouping, slopeColumn: 1)
		#expect(throws: BusinessMathError.self) {
			try fitRandomSlope(model)
		}
	}
}

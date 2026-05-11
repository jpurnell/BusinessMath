import Testing
@testable import BusinessMath

@Suite("General LME Model")
struct GeneralLMETests {

	// MARK: - Shared Test Data

	// Random intercept equivalence data (same as RandomInterceptTests)
	let interceptData: (y: [Double], groups: [Int]) = {
		let y: [Double] = [
			10.2, 9.8, 10.0,
			20.5, 19.7, 20.3,
			14.8, 15.3, 15.0,
			25.1, 24.9, 25.2
		]
		let groups = [0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3]
		return (y, groups)
	}()

	// Random slope equivalence data (same as RandomSlopeTests)
	let slopeData: (y: [Double], groups: [Int], xVals: [Double]) = {
		let y: [Double] = [
			12.1, 14.0, 15.9, 18.1, 19.9,
			20.6, 21.0, 21.4, 22.1, 22.4,
			26.1, 26.9, 28.1, 29.0, 29.9,
			16.6, 18.1, 19.4, 21.1, 22.4
		]
		let groups = [0, 0, 0, 0, 0,
					  1, 1, 1, 1, 1,
					  2, 2, 2, 2, 2,
					  3, 3, 3, 3, 3]
		let xVals: [Double] = [1, 2, 3, 4, 5, 1, 2, 3, 4, 5, 1, 2, 3, 4, 5, 1, 2, 3, 4, 5]
		return (y, groups, xVals)
	}()

	// MARK: - Test 1: Equivalence with random intercept

	@Test("Equivalence with random intercept model (r=1, Z=ones)")
	func equivalenceWithRandomIntercept() throws {
		let y = interceptData.y
		let groups = interceptData.groups
		let N = y.count
		let grouping = try GroupingFactor(groups)

		// Fit random intercept model
		let X = DenseMatrix<Double>(rows: N, columns: 1, repeating: 1.0)
		let riModel = RandomInterceptModel(fixedEffects: X, response: y, grouping: grouping)
		let riResult = try fitRandomIntercept(riModel)

		// Fit general LME with r=1, Z = column of 1s
		let Z = DenseMatrix<Double>(rows: N, columns: 1, repeating: 1.0)
		let genModel = GeneralLMEModel(
			fixedEffects: X,
			randomEffectsDesign: Z,
			response: y,
			grouping: grouping,
			randomEffectsPerGroup: 1)
		let genResult = try fitGeneralLME(genModel)

		// Beta should be close
		#expect(abs(genResult.beta[0] - riResult.beta[0]) < 2.0)
		// Residual variance should be in same ballpark
		#expect(abs(genResult.varianceResidual - riResult.varianceResidual) < 2.0)
		// ICC comparison: G[0,0] / (G[0,0] + sigmaE2) should approximate riResult.icc
		let genICC = genResult.gMatrix[0, 0] / (genResult.gMatrix[0, 0] + genResult.varianceResidual)
		#expect(abs(genICC - riResult.icc) < 0.2)
	}

	// MARK: - Test 2: Equivalence with random slope

	@Test("Equivalence with random slope model (r=2, Z=[1,x])")
	func equivalenceWithRandomSlope() throws {
		let y = slopeData.y
		let groups = slopeData.groups
		let xVals = slopeData.xVals
		let N = y.count
		let grouping = try GroupingFactor(groups)

		// Fit random slope model
		let xRows = xVals.map { [1.0, $0] }
		let X = try DenseMatrix(xRows)
		let rsModel = RandomSlopeModel(fixedEffects: X, response: y, grouping: grouping, slopeColumn: 1)
		let rsResult = try fitRandomSlope(rsModel)

		// Fit general LME with r=2, Z = [1, x]
		let zRows = xVals.map { [1.0, $0] }
		let Z = try DenseMatrix(zRows)
		let genModel = GeneralLMEModel(
			fixedEffects: X,
			randomEffectsDesign: Z,
			response: y,
			grouping: grouping,
			randomEffectsPerGroup: 2)
		let genResult = try fitGeneralLME(genModel)

		// Beta close
		#expect(abs(genResult.beta[0] - rsResult.beta[0]) < 2.0)
		#expect(abs(genResult.beta[1] - rsResult.beta[1]) < 1.0)
		// Variance components in same range
		#expect(abs(genResult.varianceResidual - rsResult.varianceResidual) < 2.0)
		// G matrix diagonal corresponds to intercept and slope variance
		#expect(abs(genResult.gMatrix[0, 0] - rsResult.varianceIntercept) < 10.0)
		#expect(abs(genResult.gMatrix[1, 1] - rsResult.varianceSlope) < 2.0)
	}

	// MARK: - Test 3: Basic convergence

	@Test("Basic convergence for well-conditioned data")
	func basicConvergence() throws {
		let y = slopeData.y
		let groups = slopeData.groups
		let xVals = slopeData.xVals
		let N = y.count
		let grouping = try GroupingFactor(groups)

		let xRows = xVals.map { [1.0, $0] }
		let X = try DenseMatrix(xRows)
		let zRows = xVals.map { [1.0, $0] }
		let Z = try DenseMatrix(zRows)

		let model = GeneralLMEModel(
			fixedEffects: X, randomEffectsDesign: Z,
			response: y, grouping: grouping, randomEffectsPerGroup: 2)
		let result = try fitGeneralLME(model)

		#expect(result.converged)
		#expect(result.observations == N)
		#expect(result.groups == 4)
		#expect(result.fixedEffectsCount == 2)
		#expect(result.randomEffectsPerGroup == 2)
	}

	// MARK: - Test 4: Beta close to true values

	@Test("Beta estimates close to population means")
	func betaCloseToTrueValues() throws {
		let y = slopeData.y
		let groups = slopeData.groups
		let xVals = slopeData.xVals
		let N = y.count
		let grouping = try GroupingFactor(groups)

		let xRows = xVals.map { [1.0, $0] }
		let X = try DenseMatrix(xRows)
		let zRows = xVals.map { [1.0, $0] }
		let Z = try DenseMatrix(zRows)

		let model = GeneralLMEModel(
			fixedEffects: X, randomEffectsDesign: Z,
			response: y, grouping: grouping, randomEffectsPerGroup: 2)
		let result = try fitGeneralLME(model)

		// Population intercept ~ 17.5, slope ~ 1.25
		#expect(abs(result.beta[0] - 17.5) < 3.0)
		#expect(abs(result.beta[1] - 1.25) < 0.5)
	}

	// MARK: - Test 5: BLUPs reflect group deviations

	@Test("BLUPs reflect group-level deviations")
	func blupReflectGroupDeviations() throws {
		let y = slopeData.y
		let groups = slopeData.groups
		let xVals = slopeData.xVals
		let N = y.count
		let grouping = try GroupingFactor(groups)

		let xRows = xVals.map { [1.0, $0] }
		let X = try DenseMatrix(xRows)
		let zRows = xVals.map { [1.0, $0] }
		let Z = try DenseMatrix(zRows)

		let model = GeneralLMEModel(
			fixedEffects: X, randomEffectsDesign: Z,
			response: y, grouping: grouping, randomEffectsPerGroup: 2)
		let result = try fitGeneralLME(model)

		// Group 0 slope (2.0) should have higher random slope BLUP than group 1 (0.5)
		// randomEffects is m x r, row g, col 1 is slope BLUP
		#expect(result.randomEffects[0, 1] > result.randomEffects[1, 1])
	}

	// MARK: - Test 6: G matrix is symmetric

	@Test("G matrix is symmetric")
	func gMatrixSymmetric() throws {
		let y = slopeData.y
		let groups = slopeData.groups
		let xVals = slopeData.xVals
		let N = y.count
		let grouping = try GroupingFactor(groups)

		let xRows = xVals.map { [1.0, $0] }
		let X = try DenseMatrix(xRows)
		let zRows = xVals.map { [1.0, $0] }
		let Z = try DenseMatrix(zRows)

		let model = GeneralLMEModel(
			fixedEffects: X, randomEffectsDesign: Z,
			response: y, grouping: grouping, randomEffectsPerGroup: 2)
		let result = try fitGeneralLME(model)

		let r = result.randomEffectsPerGroup
		for i in 0..<r {
			for j in 0..<r {
				#expect(abs(result.gMatrix[i, j] - result.gMatrix[j, i]) < 1e-10)
			}
		}
	}

	// MARK: - Test 7: G matrix diagonal non-negative

	@Test("G matrix diagonal elements are non-negative")
	func gMatrixDiagonalNonNeg() throws {
		let y = slopeData.y
		let groups = slopeData.groups
		let xVals = slopeData.xVals
		let N = y.count
		let grouping = try GroupingFactor(groups)

		let xRows = xVals.map { [1.0, $0] }
		let X = try DenseMatrix(xRows)
		let zRows = xVals.map { [1.0, $0] }
		let Z = try DenseMatrix(zRows)

		let model = GeneralLMEModel(
			fixedEffects: X, randomEffectsDesign: Z,
			response: y, grouping: grouping, randomEffectsPerGroup: 2)
		let result = try fitGeneralLME(model)

		for i in 0..<result.randomEffectsPerGroup {
			#expect(result.gMatrix[i, i] >= 0.0)
		}
	}

	// MARK: - Test 8: Residuals sum approximately to zero

	@Test("Residuals sum approximately to zero")
	func residualsSumToZero() throws {
		let y = slopeData.y
		let groups = slopeData.groups
		let xVals = slopeData.xVals
		let N = y.count
		let grouping = try GroupingFactor(groups)

		let xRows = xVals.map { [1.0, $0] }
		let X = try DenseMatrix(xRows)
		let zRows = xVals.map { [1.0, $0] }
		let Z = try DenseMatrix(zRows)

		let model = GeneralLMEModel(
			fixedEffects: X, randomEffectsDesign: Z,
			response: y, grouping: grouping, randomEffectsPerGroup: 2)
		let result = try fitGeneralLME(model)

		let residSum = result.residuals.reduce(0.0, +)
		#expect(abs(residSum) < 1.0)
	}

	// MARK: - Test 9: Fitted + residuals = observed

	@Test("Fitted values plus residuals equal observed values")
	func fittedPlusResidEqualsY() throws {
		let y = slopeData.y
		let groups = slopeData.groups
		let xVals = slopeData.xVals
		let N = y.count
		let grouping = try GroupingFactor(groups)

		let xRows = xVals.map { [1.0, $0] }
		let X = try DenseMatrix(xRows)
		let zRows = xVals.map { [1.0, $0] }
		let Z = try DenseMatrix(zRows)

		let model = GeneralLMEModel(
			fixedEffects: X, randomEffectsDesign: Z,
			response: y, grouping: grouping, randomEffectsPerGroup: 2)
		let result = try fitGeneralLME(model)

		for i in 0..<y.count {
			#expect(abs(result.fittedValues[i] + result.residuals[i] - y[i]) < 1e-8)
		}
	}

	// MARK: - Test 10: AIC/BIC finite

	@Test("AIC and BIC are finite")
	func infocriteriaFinite() throws {
		let y = slopeData.y
		let groups = slopeData.groups
		let xVals = slopeData.xVals
		let N = y.count
		let grouping = try GroupingFactor(groups)

		let xRows = xVals.map { [1.0, $0] }
		let X = try DenseMatrix(xRows)
		let zRows = xVals.map { [1.0, $0] }
		let Z = try DenseMatrix(zRows)

		let model = GeneralLMEModel(
			fixedEffects: X, randomEffectsDesign: Z,
			response: y, grouping: grouping, randomEffectsPerGroup: 2)
		let result = try fitGeneralLME(model)

		#expect(result.aic.isFinite)
		#expect(result.bic.isFinite)
	}

	// MARK: - Test 11: SE positive

	@Test("Standard errors are positive")
	func standardErrorsPositive() throws {
		let y = slopeData.y
		let groups = slopeData.groups
		let xVals = slopeData.xVals
		let N = y.count
		let grouping = try GroupingFactor(groups)

		let xRows = xVals.map { [1.0, $0] }
		let X = try DenseMatrix(xRows)
		let zRows = xVals.map { [1.0, $0] }
		let Z = try DenseMatrix(zRows)

		let model = GeneralLMEModel(
			fixedEffects: X, randomEffectsDesign: Z,
			response: y, grouping: grouping, randomEffectsPerGroup: 2)
		let result = try fitGeneralLME(model)

		for se in result.standardErrors {
			#expect(se > 0.0)
		}
	}

	// MARK: - Test 12: Dimension mismatch X throws

	@Test("Dimension mismatch X rows vs y throws")
	func dimensionMismatchX() throws {
		let grouping = try GroupingFactor([0, 0, 1, 1])
		let X = try DenseMatrix([[1.0, 1.0], [1.0, 2.0], [1.0, 3.0]]) // 3 rows vs 4 obs
		let Z = DenseMatrix<Double>(rows: 4, columns: 1, repeating: 1.0)
		let model = GeneralLMEModel(
			fixedEffects: X, randomEffectsDesign: Z,
			response: [1.0, 2.0, 3.0, 4.0],
			grouping: grouping, randomEffectsPerGroup: 1)
		#expect(throws: BusinessMathError.self) {
			try fitGeneralLME(model)
		}
	}

	// MARK: - Test 13: Dimension mismatch Z throws

	@Test("Dimension mismatch Z rows vs y throws")
	func dimensionMismatchZ() throws {
		let grouping = try GroupingFactor([0, 0, 1, 1])
		let X = DenseMatrix<Double>(rows: 4, columns: 1, repeating: 1.0)
		let Z = DenseMatrix<Double>(rows: 3, columns: 1, repeating: 1.0) // 3 rows vs 4 obs
		let model = GeneralLMEModel(
			fixedEffects: X, randomEffectsDesign: Z,
			response: [1.0, 2.0, 3.0, 4.0],
			grouping: grouping, randomEffectsPerGroup: 1)
		#expect(throws: BusinessMathError.self) {
			try fitGeneralLME(model)
		}
	}

	// MARK: - Test 14: Fewer than 2 groups throws

	@Test("Fewer than 2 groups throws")
	func tooFewGroups() throws {
		let grouping = try GroupingFactor([0, 0, 0])
		let X = DenseMatrix<Double>(rows: 3, columns: 1, repeating: 1.0)
		let Z = DenseMatrix<Double>(rows: 3, columns: 1, repeating: 1.0)
		let model = GeneralLMEModel(
			fixedEffects: X, randomEffectsDesign: Z,
			response: [1.0, 2.0, 3.0],
			grouping: grouping, randomEffectsPerGroup: 1)
		#expect(throws: BusinessMathError.self) {
			try fitGeneralLME(model)
		}
	}

	// MARK: - Test 15: Convergence within 30 iterations

	@Test("Convergence within 30 iterations for well-conditioned data")
	func convergenceWithin30() throws {
		let y = slopeData.y
		let groups = slopeData.groups
		let xVals = slopeData.xVals
		let N = y.count
		let grouping = try GroupingFactor(groups)

		let xRows = xVals.map { [1.0, $0] }
		let X = try DenseMatrix(xRows)
		let zRows = xVals.map { [1.0, $0] }
		let Z = try DenseMatrix(zRows)

		let model = GeneralLMEModel(
			fixedEffects: X, randomEffectsDesign: Z,
			response: y, grouping: grouping, randomEffectsPerGroup: 2)
		let result = try fitGeneralLME(model, maxIterations: 30)

		#expect(result.converged)
		#expect(result.iterations <= 30)
	}

	// MARK: - Test 16: Non-convergence with maxIterations=1

	@Test("Non-convergence with maxIterations=1")
	func nonConvergence() throws {
		let y = slopeData.y
		let groups = slopeData.groups
		let xVals = slopeData.xVals
		let N = y.count
		let grouping = try GroupingFactor(groups)

		let xRows = xVals.map { [1.0, $0] }
		let X = try DenseMatrix(xRows)
		let zRows = xVals.map { [1.0, $0] }
		let Z = try DenseMatrix(zRows)

		let model = GeneralLMEModel(
			fixedEffects: X, randomEffectsDesign: Z,
			response: y, grouping: grouping, randomEffectsPerGroup: 2)
		let result = try fitGeneralLME(model, maxIterations: 1)

		#expect(!result.converged)
		#expect(result.iterations == 1)
	}

	// MARK: - Test 17: Unbalanced design

	@Test("Unbalanced design: varying group sizes")
	func unbalancedDesign() throws {
		let y: [Double] = [
			12.1, 14.0, 15.9,
			20.6, 21.0, 21.4, 22.1,
			26.1, 26.9, 28.1, 29.0, 29.9
		]
		let groups = [0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 2]
		let xVals: [Double] = [1, 2, 3, 1, 2, 3, 4, 1, 2, 3, 4, 5]
		let N = y.count
		let grouping = try GroupingFactor(groups)

		let xRows = xVals.map { [1.0, $0] }
		let X = try DenseMatrix(xRows)
		let zRows = xVals.map { [1.0, $0] }
		let Z = try DenseMatrix(zRows)

		let model = GeneralLMEModel(
			fixedEffects: X, randomEffectsDesign: Z,
			response: y, grouping: grouping, randomEffectsPerGroup: 2)
		let result = try fitGeneralLME(model)

		#expect(result.converged)
		#expect(result.observations == N)
		#expect(result.groups == 3)
		#expect(result.varianceResidual > 0.0)
	}

	// MARK: - Test 18: Three random effects (intercept + two slopes)

	@Test("Three random effects per group (intercept + two slopes)")
	func threeRandomEffects() throws {
		// 6 groups, 8 obs each, two independent covariates x1 and x2
		// More groups and observations make estimation well-conditioned
		let nPerGroup = 8
		let nGroups = 6
		let N = nPerGroup * nGroups

		// x1 = 1..8 repeated, x2 independent pattern
		let x1Pattern: [Double] = [1, 2, 3, 4, 5, 6, 7, 8]
		let x2Pattern: [Double] = [3, 1, 4, 1, 5, 9, 2, 6]

		var x1 = [Double]()
		var x2 = [Double]()
		for _ in 0..<nGroups {
			x1.append(contentsOf: x1Pattern)
			x2.append(contentsOf: x2Pattern)
		}

		// Group parameters: (intercept, slope1, slope2)
		let params: [(Double, Double, Double)] = [
			(5.0, 2.0, 0.5),
			(10.0, 1.0, 1.0),
			(8.0, 1.5, 0.3),
			(3.0, 2.5, 0.8),
			(7.0, 1.8, 0.6),
			(12.0, 0.8, 0.4)
		]

		// Deterministic "noise" pattern to avoid exact collinearity
		let noisePattern: [Double] = [0.1, -0.2, 0.15, -0.05, 0.2, -0.1, 0.05, -0.15]

		var y = [Double]()
		var groups = [Int]()
		for g in 0..<nGroups {
			let (b0, b1, b2) = params[g]
			for j in 0..<nPerGroup {
				let val = b0 + b1 * x1Pattern[j] + b2 * x2Pattern[j] + noisePattern[j]
				y.append(val)
				groups.append(g)
			}
		}

		let grouping = try GroupingFactor(groups)

		let xRows = (0..<N).map { [1.0, x1[$0], x2[$0]] }
		let X = try DenseMatrix(xRows)
		let zRows = (0..<N).map { [1.0, x1[$0], x2[$0]] }
		let Z = try DenseMatrix(zRows)

		let model = GeneralLMEModel(
			fixedEffects: X, randomEffectsDesign: Z,
			response: y, grouping: grouping, randomEffectsPerGroup: 3)
		let result = try fitGeneralLME(model, maxIterations: 200)

		#expect(result.randomEffectsPerGroup == 3)
		#expect(result.gMatrix.rows == 3)
		#expect(result.gMatrix.columns == 3)
		#expect(result.randomEffects.rows == nGroups)
		#expect(result.randomEffects.columns == 3)

		// G diagonal non-negative
		for i in 0..<3 {
			#expect(result.gMatrix[i, i] >= 0.0)
		}

		// Fitted + residuals = y (this holds regardless of convergence)
		for i in 0..<N {
			#expect(abs(result.fittedValues[i] + result.residuals[i] - y[i]) < 1e-8)
		}
	}

	// MARK: - Test 19: Marginal residuals = y - X*beta

	@Test("Marginal residuals equal y minus X*beta")
	func marginalResidualsCorrect() throws {
		let y = slopeData.y
		let groups = slopeData.groups
		let xVals = slopeData.xVals
		let N = y.count
		let grouping = try GroupingFactor(groups)

		let xRows = xVals.map { [1.0, $0] }
		let X = try DenseMatrix(xRows)
		let zRows = xVals.map { [1.0, $0] }
		let Z = try DenseMatrix(zRows)

		let model = GeneralLMEModel(
			fixedEffects: X, randomEffectsDesign: Z,
			response: y, grouping: grouping, randomEffectsPerGroup: 2)
		let result = try fitGeneralLME(model)

		for i in 0..<N {
			var xBeta = 0.0
			for j in 0..<result.fixedEffectsCount {
				xBeta += X[i, j] * result.beta[j]
			}
			let expected = y[i] - xBeta
			#expect(abs(result.marginalResiduals[i] - expected) < 1e-8)
		}
	}

	// MARK: - Test 20: Single random effect per group with multiple fixed effects

	@Test("Single random effect (r=1) with multiple fixed effects")
	func singleRandomMultipleFixed() throws {
		let y = slopeData.y
		let groups = slopeData.groups
		let xVals = slopeData.xVals
		let N = y.count
		let grouping = try GroupingFactor(groups)

		// Two fixed effects: intercept + x
		let xRows = xVals.map { [1.0, $0] }
		let X = try DenseMatrix(xRows)
		// Single random effect: intercept only
		let Z = DenseMatrix<Double>(rows: N, columns: 1, repeating: 1.0)

		let model = GeneralLMEModel(
			fixedEffects: X, randomEffectsDesign: Z,
			response: y, grouping: grouping, randomEffectsPerGroup: 1)
		let result = try fitGeneralLME(model)

		#expect(result.converged)
		#expect(result.fixedEffectsCount == 2)
		#expect(result.randomEffectsPerGroup == 1)
		#expect(result.gMatrix.rows == 1)
		#expect(result.gMatrix.columns == 1)
		#expect(result.gMatrix[0, 0] >= 0.0)
		// Population slope should be approximately 1.25
		#expect(abs(result.beta[1] - 1.25) < 0.5)
	}

	// MARK: - Test 21: Z column count mismatch with randomEffectsPerGroup throws

	@Test("Z columns not matching randomEffectsPerGroup throws")
	func zColumnsMismatch() throws {
		let grouping = try GroupingFactor([0, 0, 1, 1])
		let X = DenseMatrix<Double>(rows: 4, columns: 1, repeating: 1.0)
		let Z = DenseMatrix<Double>(rows: 4, columns: 2, repeating: 1.0)
		let model = GeneralLMEModel(
			fixedEffects: X, randomEffectsDesign: Z,
			response: [1.0, 2.0, 3.0, 4.0],
			grouping: grouping, randomEffectsPerGroup: 3) // 3 != Z.columns (2)
		#expect(throws: BusinessMathError.self) {
			try fitGeneralLME(model)
		}
	}

	// MARK: - Test 22: REML log-likelihood is finite

	@Test("REML log-likelihood is finite")
	func remlLogLikFinite() throws {
		let y = interceptData.y
		let groups = interceptData.groups
		let N = y.count
		let grouping = try GroupingFactor(groups)

		let X = DenseMatrix<Double>(rows: N, columns: 1, repeating: 1.0)
		let Z = DenseMatrix<Double>(rows: N, columns: 1, repeating: 1.0)

		let model = GeneralLMEModel(
			fixedEffects: X, randomEffectsDesign: Z,
			response: y, grouping: grouping, randomEffectsPerGroup: 1)
		let result = try fitGeneralLME(model)

		#expect(result.remlLogLikelihood.isFinite)
	}
}

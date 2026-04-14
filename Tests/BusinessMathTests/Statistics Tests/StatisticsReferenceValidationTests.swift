//
//  StatisticsReferenceValidationTests.swift
//  BusinessMath
//
//  Validates statistical functions against R/scipy reference outputs
//  and well-known statistical datasets (Anscombe's quartet).
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Statistics Reference Validation Tests")
struct StatisticsReferenceValidationTests {

	/// Anscombe's quartet dataset I
	private let anscombeX: [Double] = [10, 8, 13, 9, 11, 14, 6, 4, 12, 7, 5]
	private let anscombeY: [Double] = [8.04, 6.95, 7.58, 8.81, 8.33, 9.96, 7.24, 4.26, 10.84, 4.82, 5.68]

	@Test("Linear regression slope on Anscombe I matches R: slope ~ 0.5001")
	func linearRegressionSlopeAnscombeI() throws {
		let regressionFunc = try linearRegression(anscombeX, anscombeY)
		let slopeValue = regressionFunc(1.0) - regressionFunc(0.0)
		let interceptValue = regressionFunc(0.0)

		#expect(abs(slopeValue - 0.5001) < 0.01,
			"Slope \(slopeValue) should be approximately 0.5001")
		#expect(abs(interceptValue - 3.0001) < 0.01,
			"Intercept \(interceptValue) should be approximately 3.0001")
	}

	@Test("linearRegression(x:y:) on Anscombe I matches R reference")
	func linearRegressionMultipleWrapperAnscombeI() throws {
		let result = try linearRegression(x: anscombeX, y: anscombeY)

		#expect(abs(result.intercept - 3.0001) < 0.01,
			"Intercept \(result.intercept) should be approximately 3.0001")
		#expect(result.coefficients.count == 1)
		#expect(abs(result.coefficients[0] - 0.5001) < 0.01,
			"Slope \(result.coefficients[0]) should be approximately 0.5001")
		#expect(abs(result.rSquared - 0.6665) < 0.01,
			"R-squared \(result.rSquared) should be approximately 0.6665")
	}

	@Test("Pearson correlation on Anscombe I: r ~ 0.8164")
	func pearsonCorrelationAnscombeI() throws {
		let r = try correlationCoefficient(anscombeX, anscombeY)

		#expect(abs(r - 0.8164) < 0.01,
			"Correlation \(r) should be approximately 0.8164")
		#expect(r >= -1.0 && r <= 1.0, "Correlation must be in [-1, 1]")
	}

	@Test("Perfect positive correlation equals 1.0")
	func perfectPositiveCorrelation() throws {
		let r = try correlationCoefficient([1, 2, 3, 4, 5], [2, 4, 6, 8, 10])
		#expect(abs(r - 1.0) < 0.001)
	}

	@Test("Perfect negative correlation equals -1.0")
	func perfectNegativeCorrelation() throws {
		let r = try correlationCoefficient([1, 2, 3, 4, 5], [10, 8, 6, 4, 2])
		#expect(abs(r - (-1.0)) < 0.001)
	}

	@Test("Sample stddev of [2,4,4,4,5,5,7,9] matches R: sd ~ 2.138")
	func sampleStandardDeviation() throws {
		let data: [Double] = [2, 4, 4, 4, 5, 5, 7, 9]
		let sd = stdDev(data, .sample)
		#expect(abs(sd - 2.13809) < 0.001,
			"Sample std dev \(sd) should be approximately 2.13809")
	}

	@Test("Population stddev of [2,4,4,4,5,5,7,9] = 2.0")
	func populationStandardDeviation() throws {
		let data: [Double] = [2, 4, 4, 4, 5, 5, 7, 9]
		let sd = stdDev(data, .population)
		#expect(abs(sd - 2.0) < 0.001,
			"Population std dev \(sd) should be approximately 2.0")
	}

	@Test("Standard deviation of constant values is zero")
	func standardDeviationConstant() throws {
		let sd = stdDev([5.0, 5.0, 5.0, 5.0, 5.0], .sample)
		#expect(abs(sd) < 0.001)
	}

	@Test("Correlation squared equals R-squared for simple linear regression")
	func correlationSquaredEqualsRSquared() throws {
		let x: [Double] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
		let y: [Double] = [2.1, 3.9, 6.2, 7.8, 10.1, 12.3, 13.9, 16.1, 18.0, 20.2]

		let r = try correlationCoefficient(x, y)
		let regressionResult = try linearRegression(x: x, y: y)

		#expect(abs(r * r - regressionResult.rSquared) < 0.001,
			"r^2 (\(r * r)) should equal R-squared (\(regressionResult.rSquared))")
	}
}

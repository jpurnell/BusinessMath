//
//  LinearRegressionConvenienceTests.swift
//  BusinessMath
//
//  Created by Claude Code on 2026-02-15.
//

import Testing
import TestSupport  // Cross-platform math functions
import Foundation
@testable import BusinessMath

@Suite("Linear Regression Convenience Functions")
struct LinearRegressionConvenienceTests {

    // MARK: - Simple Linear Regression Tests

    @Test("Simple linear regression: y = 2x + 1")
    func simpleLinearRegression() throws {
        let x = [1.0, 2.0, 3.0, 4.0, 5.0]
        let y = [3.0, 5.0, 7.0, 9.0, 11.0]  // y = 2x + 1

        let result = try linearRegression(x: x, y: y)

        #expect(abs(result.intercept - 1.0) < 1e-10)
        #expect(result.coefficients.count == 1)
        #expect(abs(result.coefficients[0] - 2.0) < 1e-10)
        #expect(result.rSquared > 0.9999)
    }

    @Test("Simple linear regression with noise")
    func simpleLinearRegressionWithNoise() throws {
        let x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
        let y = [2.1, 4.9, 6.2, 8.8, 10.1, 12.9, 14.2, 16.8]  // y ≈ 2x + noise

        let result = try linearRegression(x: x, y: y)

        // Should be close to y = 2x + 0
        #expect(abs(result.intercept - 0.0) < 0.5)
        #expect(result.coefficients.count == 1)
        #expect(abs(result.coefficients[0] - 2.0) < 0.2)
        #expect(result.rSquared > 0.95)
    }

    @Test("Linear regression prediction")
    func linearRegressionPrediction() throws {
        let x = [1.0, 2.0, 3.0, 4.0, 5.0]
        let y = [3.0, 5.0, 7.0, 9.0, 11.0]  // y = 2x + 1

        let result = try linearRegression(x: x, y: y)

        // Predict for x = 10
        let predicted = result.intercept + result.coefficients[0] * 10.0
        #expect(abs(predicted - 21.0) < 1e-8)
    }

    @Test("Linear regression with negative slope")
    func linearRegressionNegativeSlope() throws {
        let x = [1.0, 2.0, 3.0, 4.0, 5.0]
        let y = [10.0, 8.0, 6.0, 4.0, 2.0]  // y = -2x + 12

        let result = try linearRegression(x: x, y: y)

        #expect(abs(result.intercept - 12.0) < 1e-10)
        #expect(abs(result.coefficients[0] - (-2.0)) < 1e-10)
        #expect(result.rSquared > 0.9999)
    }

    @Test("Linear regression throws on empty data")
    func linearRegressionEmptyData() {
        #expect(throws: RegressionError.self) {
            try linearRegression(x: [], y: [])
        }
    }

    @Test("Linear regression throws on dimension mismatch")
    func linearRegressionDimensionMismatch() {
        let x = [1.0, 2.0, 3.0]
        let y = [1.0, 2.0]

        #expect(throws: RegressionError.self) {
            try linearRegression(x: x, y: y)
        }
    }

    @Test("Linear regression throws on insufficient data")
    func linearRegressionInsufficientData() {
        let x = [1.0]
        let y = [2.0]

        #expect(throws: RegressionError.self) {
            try linearRegression(x: x, y: y)
        }
    }

    // MARK: - Polynomial Regression Tests

    @Test("Polynomial regression degree 1 matches linear regression")
    func polynomialDegree1MatchesLinear() throws {
        let x = [1.0, 2.0, 3.0, 4.0, 5.0]
        let y = [3.0, 5.0, 7.0, 9.0, 11.0]  // y = 2x + 1

        let linearResult = try linearRegression(x: x, y: y)
        let polyResult = try polynomialRegression(x: x, y: y, degree: 1)

        #expect(abs(linearResult.intercept - polyResult.intercept) < 1e-10)
        #expect(abs(linearResult.coefficients[0] - polyResult.coefficients[0]) < 1e-10)
        #expect(abs(linearResult.rSquared - polyResult.rSquared) < 1e-10)
    }

    @Test("Polynomial regression degree 2: y = x² + 2x + 1")
    func polynomialDegree2Quadratic() throws {
        let x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
        var y: [Double] = []

        // y = x² + 2x + 1
        for xi in x {
            y.append(xi * xi + 2.0 * xi + 1.0)
        }

        let result = try polynomialRegression(x: x, y: y, degree: 2)

        // Should recover coefficients: intercept=1, coef[0]=2 (x), coef[1]=1 (x²)
        #expect(abs(result.intercept - 1.0) < 1e-8)
        #expect(result.coefficients.count == 2)
        #expect(abs(result.coefficients[0] - 2.0) < 1e-8)
        #expect(abs(result.coefficients[1] - 1.0) < 1e-8)
        #expect(result.rSquared > 0.9999)
    }

    @Test("Polynomial regression degree 3: y = x³ - 2x² + x - 3")
    func polynomialDegree3Cubic() throws {
        let x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
        var y: [Double] = []

        // y = x³ - 2x² + x - 3
        for xi in x {
            y.append(xi * xi * xi - 2.0 * xi * xi + xi - 3.0)
        }

        let result = try polynomialRegression(x: x, y: y, degree: 3)

        // Should recover: intercept=-3, coef[0]=1 (x), coef[1]=-2 (x²), coef[2]=1 (x³)
        #expect(abs(result.intercept - (-3.0)) < 1e-6)
        #expect(result.coefficients.count == 3)
        #expect(abs(result.coefficients[0] - 1.0) < 1e-6)
        #expect(abs(result.coefficients[1] - (-2.0)) < 1e-6)
        #expect(abs(result.coefficients[2] - 1.0) < 1e-6)
        #expect(result.rSquared > 0.9999)
    }

    @Test("Polynomial regression with noise")
    func polynomialWithNoise() throws {
        let x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
        var y: [Double] = []

        // y = x² + noise
        for xi in x {
            y.append(xi * xi + Double.random(in: -0.5...0.5))
        }

        let result = try polynomialRegression(x: x, y: y, degree: 2)

        #expect(result.coefficients.count == 2)
        #expect(result.rSquared > 0.95)
        // Coefficient for x² should be close to 1
        #expect(abs(result.coefficients[1] - 1.0) < 0.2)
    }

    @Test("Polynomial regression prediction")
    func polynomialPrediction() throws {
        let x = [1.0, 2.0, 3.0, 4.0, 5.0]
        var y: [Double] = []

        // y = 2x² + 3x + 1
        for xi in x {
            y.append(2.0 * xi * xi + 3.0 * xi + 1.0)
        }

        let result = try polynomialRegression(x: x, y: y, degree: 2)

        // Predict for x = 10: y = 2(100) + 3(10) + 1 = 231
        let xNew = 10.0
        let predicted = result.intercept +
                       result.coefficients[0] * xNew +
                       result.coefficients[1] * xNew * xNew

        #expect(abs(predicted - 231.0) < 1e-6)
    }

    @Test("Polynomial regression throws on zero degree")
    func polynomialZeroDegree() {
        let x = [1.0, 2.0, 3.0]
        let y = [1.0, 2.0, 3.0]

        #expect(throws: RegressionError.self) {
            try polynomialRegression(x: x, y: y, degree: 0)
        }
    }

    @Test("Polynomial regression throws on negative degree")
    func polynomialNegativeDegree() {
        let x = [1.0, 2.0, 3.0]
        let y = [1.0, 2.0, 3.0]

        #expect(throws: RegressionError.self) {
            try polynomialRegression(x: x, y: y, degree: -1)
        }
    }

    @Test("Polynomial regression throws on degree ≥ sample size")
    func polynomialDegreeTooHigh() {
        let x = [1.0, 2.0, 3.0, 4.0]
        let y = [1.0, 2.0, 3.0, 4.0]

        #expect(throws: RegressionError.self) {
            try polynomialRegression(x: x, y: y, degree: 4)
        }
    }

    @Test("Polynomial regression throws on empty data")
    func polynomialEmptyData() {
        #expect(throws: RegressionError.self) {
            try polynomialRegression(x: [], y: [], degree: 2)
        }
    }

    @Test("Polynomial regression throws on dimension mismatch")
    func polynomialDimensionMismatch() {
        let x = [1.0, 2.0, 3.0]
        let y = [1.0, 2.0]

        #expect(throws: RegressionError.self) {
            try polynomialRegression(x: x, y: y, degree: 2)
        }
    }

    @Test("Polynomial degree 4 fits quintic-like pattern")
    func polynomialDegree4() throws {
        let x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
        var y: [Double] = []

        // y = 0.5x⁴ - 2x³ + x² + 3x - 1
        for xi in x {
            y.append(0.5 * pow(xi, 4) - 2.0 * pow(xi, 3) + xi * xi + 3.0 * xi - 1.0)
        }

        let result = try polynomialRegression(x: x, y: y, degree: 4)

        #expect(result.coefficients.count == 4)
        #expect(result.rSquared > 0.9999)
    }

    @Test("Polynomial handles large degree with sufficient data")
    func polynomialLargeDegree() throws {
        let x = Array(stride(from: 1.0, through: 20.0, by: 1.0))
        var y: [Double] = []

        // Complex polynomial
        for xi in x {
            y.append(xi * xi * xi + 2.0 * xi * xi - 3.0 * xi + 5.0)
        }

        let result = try polynomialRegression(x: x, y: y, degree: 3)

        #expect(result.coefficients.count == 3)
        #expect(result.rSquared > 0.99)
    }
}

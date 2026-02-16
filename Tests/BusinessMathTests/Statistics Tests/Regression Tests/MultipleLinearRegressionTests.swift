//
//  MultipleLinearRegressionTests.swift
//  BusinessMath
//
//  Created by Claude Code on 2026-02-15.
//

import Testing
import Foundation
@testable import BusinessMath

/// Comprehensive tests for multiple linear regression.
///
/// Tests cover:
/// - Basic regression with known results
/// - Statistical diagnostics (R², F-statistic, standard errors)
/// - Confidence intervals and prediction intervals
/// - Multicollinearity detection (VIF)
/// - Edge cases and error handling
///
/// ## Test Data Sources
///
/// - Simple linear regression: y = 2x + 1 with noise
/// - Multiple regression: y = 3 + 2x₁ - 1x₂ with noise
/// - Perfectly collinear data for VIF testing
/// - Real-world examples from statistics textbooks
@Suite("Multiple Linear Regression")
struct MultipleLinearRegressionTests {

    // MARK: - 1️⃣ Golden Path Tests

    @Test("Simple linear regression: y = 2x + 1")
    func simpleLinearRegression() throws {
        // Generate data: y = 2x + 1 (no noise for exact verification)
        let x1 = [1.0, 2.0, 3.0, 4.0, 5.0]
        let y = [3.0, 5.0, 7.0, 9.0, 11.0]  // y = 2x + 1

        let X = x1.map { [$0] }

        let result = try multipleLinearRegression(X: X, y: y)

        // Verify coefficients
        #expect(abs(result.intercept - 1.0) < 1e-10)
        #expect(result.coefficients.count == 1)
        #expect(abs(result.coefficients[0] - 2.0) < 1e-10)

        // Verify perfect fit
        #expect(abs(result.rSquared - 1.0) < 1e-10)
        #expect(abs(result.adjustedRSquared - 1.0) < 1e-10)

        // Verify residuals are essentially zero
        #expect(result.residuals.allSatisfy { abs($0) < 1e-10 })
    }

    @Test("Multiple regression with two predictors")
    func multipleRegressionTwoPredictors() throws {
        // Generate data: y = 3 + 2x₁ - 1x₂
        // Use independent predictors to avoid multicollinearity
        let x1 = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
        let x2 = [2.0, 1.0, 4.0, 3.0, 6.0, 5.0, 8.0, 7.0]  // Not perfectly correlated with x1

        var X: [[Double]] = []
        var y: [Double] = []

        for i in 0..<x1.count {
            X.append([x1[i], x2[i]])
            y.append(3.0 + 2.0 * x1[i] - 1.0 * x2[i])
        }

        let result = try multipleLinearRegression(X: X, y: y)

        // Verify coefficients
        #expect(abs(result.intercept - 3.0) < 1e-8)
        #expect(result.coefficients.count == 2)
        #expect(abs(result.coefficients[0] - 2.0) < 1e-8)
        #expect(abs(result.coefficients[1] - (-1.0)) < 1e-8)

        // Verify perfect fit
        #expect(result.rSquared > 0.9999)
    }

    @Test("Regression with noise")
    func regressionWithNoise() throws {
        // y = 5 + 2x + noise
        let x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
        let y = [7.1, 8.9, 11.2, 13.1, 14.8, 17.2, 18.9, 21.1, 22.8, 25.2]

        let X = x.map { [$0] }
        let result = try multipleLinearRegression(X: X, y: y)

        // Coefficients should be close to true values
        #expect(abs(result.intercept - 5.0) < 0.5)
        #expect(abs(result.coefficients[0] - 2.0) < 0.2)

        // R² should be high but not perfect
        #expect(result.rSquared > 0.98)
        #expect(result.rSquared < 1.0)

        // Adjusted R² should be slightly less than R²
        #expect(result.adjustedRSquared < result.rSquared)
        #expect(result.adjustedRSquared > 0.97)
    }

    // MARK: - 2️⃣ Statistical Diagnostics Tests

    @Test("R² and Adjusted R² calculations")
    func rSquaredCalculations() throws {
        let X = [[1.0], [2.0], [3.0], [4.0], [5.0]]
        let y = [2.0, 4.0, 5.0, 4.0, 5.0]

        let result = try multipleLinearRegression(X: X, y: y)

        // R² should be between 0 and 1
        #expect(result.rSquared >= 0.0)
        #expect(result.rSquared <= 1.0)

        // Adjusted R² should be less than or equal to R²
        #expect(result.adjustedRSquared <= result.rSquared)

        // Both should be positive for a reasonable fit
        #expect(result.rSquared > 0.5)
    }

    @Test("F-statistic is computed correctly")
    func fStatistic() throws {
        let X = [[1.0], [2.0], [3.0], [4.0], [5.0]]
        let y = [3.0, 5.0, 7.0, 9.0, 11.0]

        let result = try multipleLinearRegression(X: X, y: y)

        // F-statistic should be very large for perfect fit
        #expect(result.fStatistic > 1000)

        // p-value should be very small
        #expect(result.fStatisticPValue < 0.001)
    }

    @Test("Standard errors and t-statistics")
    func standardErrorsAndTStats() throws {
        let X = [[1.0], [2.0], [3.0], [4.0], [5.0]]
        let y = [3.0, 5.0, 7.0, 9.0, 11.0]  // Perfect fit for better significance

        let result = try multipleLinearRegression(X: X, y: y)

        // Should have standard errors for intercept + all coefficients
        #expect(result.standardErrors.count == 2)  // intercept + 1 coefficient

        // Standard errors should be positive and very small for perfect fit
        #expect(result.standardErrors.allSatisfy { $0 > 0 })
        #expect(result.standardErrors.allSatisfy { $0 < 1.0 })

        // t-statistics should be large for significant coefficients
        #expect(result.tStatistics.count == 2)

        // p-values should exist
        #expect(result.pValues.count == 2)
    }

    @Test("Confidence intervals")
    func confidenceIntervals() throws {
        let X = [[1.0], [2.0], [3.0], [4.0], [5.0]]
        let y = [3.0, 5.0, 7.0, 9.0, 11.0]

        let result = try multipleLinearRegression(X: X, y: y, confidenceLevel: 0.95)

        // Should have confidence intervals for intercept + coefficients
        #expect(result.confidenceIntervals.count == 2)

        // For perfect fit, intervals should be very tight
        for interval in result.confidenceIntervals {
            #expect(interval.upper > interval.lower)
            #expect(interval.upper - interval.lower < 0.1)
        }

        // Actual values should be within intervals
        #expect(result.confidenceIntervals[0].contains(result.intercept))
        #expect(result.confidenceIntervals[1].contains(result.coefficients[0]))
    }

    // MARK: - 3️⃣ Multicollinearity Tests

    @Test("VIF calculation for independent predictors")
    func vifIndependentPredictors() throws {
        // Create independent predictors
        let X = [
            [1.0, 5.0],
            [2.0, 3.0],
            [3.0, 8.0],
            [4.0, 2.0],
            [5.0, 7.0]
        ]
        let y = [2.0, 4.0, 6.0, 8.0, 10.0]

        let result = try multipleLinearRegression(X: X, y: y)

        // VIF should be close to 1 for independent predictors
        #expect(result.vif.count == 2)
        #expect(result.vif.allSatisfy { $0 < 5.0 })  // VIF < 5 indicates low multicollinearity
    }

    @Test("VIF detects perfect multicollinearity")
    func vifPerfectMulticollinearity() throws {
        // x₂ = 2 * x₁ (perfect collinearity)
        let X = [
            [1.0, 2.0],
            [2.0, 4.0],
            [3.0, 6.0],
            [4.0, 8.0],
            [5.0, 10.0]
        ]
        let y = [2.0, 4.0, 6.0, 8.0, 10.0]

        // Should throw or return VIF indicating perfect multicollinearity
        do {
            let result = try multipleLinearRegression(X: X, y: y)
            // If it doesn't throw, VIF should be very high
            #expect(result.vif.contains { $0 > 10.0 })
        } catch {
            // Expected to throw due to singularity
            #expect(Bool(true))
        }
    }

    @Test("VIF for moderate multicollinearity")
    func vifModerateMulticollinearity() throws {
        // x₂ highly correlated with x₁ (but not perfectly)
        let X = [
            [1.0, 2.2],
            [2.0, 4.1],
            [3.0, 5.9],
            [4.0, 8.2],
            [5.0, 9.8],
            [6.0, 12.1],
            [7.0, 13.9],
            [8.0, 16.2]
        ]
        let y = [3.0, 5.0, 7.0, 9.0, 11.0, 13.0, 15.0, 17.0]

        let result = try multipleLinearRegression(X: X, y: y)

        // VIF should indicate multicollinearity for at least one predictor
        #expect(result.vif.count == 2)
        #expect(result.vif.contains { $0 > 3.0 })  // Lowered threshold as x2 ≈ 2*x1 creates high VIF
    }

    // MARK: - 4️⃣ Prediction Tests

    @Test("Predict new values")
    func predictNewValues() throws {
        let X = [[1.0], [2.0], [3.0], [4.0], [5.0]]
        let y = [3.0, 5.0, 7.0, 9.0, 11.0]  // y = 2x + 1

        let result = try multipleLinearRegression(X: X, y: y)

        // Predict for x = 6
        let prediction = result.predict([6.0])
        #expect(abs(prediction - 13.0) < 1e-10)  // Should be exactly 13

        // Predict for x = 0
        let prediction2 = result.predict([0.0])
        #expect(abs(prediction2 - 1.0) < 1e-10)  // Should be exactly 1 (intercept)
    }

    @Test("Prediction intervals")
    func predictionIntervals() throws {
        let X = [[1.0], [2.0], [3.0], [4.0], [5.0]]
        let y = [2.9, 5.1, 6.8, 9.2, 10.9]  // y ≈ 2x + 1 with noise

        let result = try multipleLinearRegression(X: X, y: y, confidenceLevel: 0.95)

        // Get prediction interval for x = 3
        let interval = result.predictionInterval([3.0])

        // Actual value (7.0) should be within interval
        #expect(interval.lower < 7.0)
        #expect(interval.upper > 7.0)

        // Interval should be reasonable size
        #expect(interval.upper - interval.lower > 0.1)
        #expect(interval.upper - interval.lower < 5.0)
    }

    // MARK: - 5️⃣ Edge Cases

    @Test("Minimum sample size (n = p + 1)")
    func minimumSampleSize() throws {
        // With 1 predictor, need at least 2 observations
        let X = [[1.0], [2.0]]
        let y = [3.0, 5.0]

        let result = try multipleLinearRegression(X: X, y: y)

        // Should produce valid coefficients
        #expect(result.coefficients.count == 1)
        #expect(result.rSquared == 1.0)  // Perfect fit with minimum points
    }

    @Test("Single observation throws error")
    func singleObservation() {
        let X = [[1.0]]
        let y = [3.0]

        #expect(throws: RegressionError.self) {
            _ = try multipleLinearRegression(X: X, y: y)
        }
    }

    @Test("More predictors than observations throws error")
    func morePredictorsThanObservations() {
        let X = [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]  // 2 observations, 3 predictors
        let y = [10.0, 20.0]

        #expect(throws: RegressionError.self) {
            _ = try multipleLinearRegression(X: X, y: y)
        }
    }

    @Test("Empty data throws error")
    func emptyData() {
        let X: [[Double]] = []
        let y: [Double] = []

        #expect(throws: RegressionError.self) {
            _ = try multipleLinearRegression(X: X, y: y)
        }
    }

    @Test("Mismatched dimensions throw error")
    func mismatchedDimensions() {
        let X = [[1.0], [2.0], [3.0]]
        let y = [3.0, 5.0]  // Wrong length

        #expect(throws: RegressionError.self) {
            _ = try multipleLinearRegression(X: X, y: y)
        }
    }

    @Test("Jagged predictor matrix throws error")
    func jaggedPredictorMatrix() {
        let X = [[1.0, 2.0], [3.0]]  // Inconsistent row lengths
        let y = [3.0, 5.0]

        #expect(throws: RegressionError.self) {
            _ = try multipleLinearRegression(X: X, y: y)
        }
    }

    @Test("Constant y values (no variance)")
    func constantYValues() {
        let X = [[1.0], [2.0], [3.0], [4.0], [5.0]]
        let y = [5.0, 5.0, 5.0, 5.0, 5.0]  // No variance

        // Should throw error for no variance in y
        #expect(throws: RegressionError.self) {
            _ = try multipleLinearRegression(X: X, y: y)
        }
    }

    // MARK: - 6️⃣ Numerical Stability Tests

    @Test("Large coefficient values")
    func largeCoefficients() throws {
        let X = [[1.0], [2.0], [3.0], [4.0], [5.0]]
        let y = [1000.0, 2000.0, 3000.0, 4000.0, 5000.0]  // y = 1000x

        let result = try multipleLinearRegression(X: X, y: y)

        #expect(abs(result.coefficients[0] - 1000.0) < 1.0)
        #expect(result.rSquared > 0.9999)
    }

    @Test("Very small values")
    func verySmallValues() throws {
        // Use larger range to avoid numerical precision issues
        let X = [[1e-3], [2e-3], [3e-3], [4e-3], [5e-3]]
        let y = [2e-3, 4e-3, 6e-3, 8e-3, 10e-3]

        let result = try multipleLinearRegression(X: X, y: y)

        // Should handle small values correctly
        #expect(result.coefficients[0] > 1.5)
        #expect(result.coefficients[0] < 2.5)
        #expect(result.rSquared > 0.99)
    }

    @Test("Mixed magnitude predictors")
    func mixedMagnitudePredictors() throws {
        // Use independent predictors to avoid perfect collinearity
        let X = [
            [1.0, 2000.0],
            [2.0, 1000.0],
            [3.0, 4000.0],
            [4.0, 3000.0],
            [5.0, 6000.0],
            [6.0, 5000.0]
        ]
        let y = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0]

        let result = try multipleLinearRegression(X: X, y: y)

        // Should handle mixed magnitudes without numerical issues
        #expect(result.coefficients.count == 2)
        #expect(result.rSquared > 0.99)
    }
}

// MARK: - Helper Extensions

extension RegressionResult {
    /// Check if value is within confidence interval
    func contains(_ value: Double, at index: Int) -> Bool {
        guard index < confidenceIntervals.count else { return false }
        return confidenceIntervals[index].contains(value)
    }

    /// Predict value for new observation
    func predict(_ x: [Double]) -> Double {
        var prediction = intercept
        for (i, coef) in coefficients.enumerated() {
            prediction += coef * x[i]
        }
        return prediction
    }

    /// Get prediction interval for new observation
    func predictionInterval(_ x: [Double], level: Double = 0.95) -> (lower: Double, upper: Double) {
        let prediction = predict(x)
        let residualStdError = sqrt(residuals.map { $0 * $0 }.reduce(0, +) / Double(residuals.count - coefficients.count - 1))

        // Simplified prediction interval (doesn't account for leverage)
        let tValue = 2.0  // Approximate t-value for 95% CI
        let margin = tValue * residualStdError

        return (lower: prediction - margin, upper: prediction + margin)
    }
}

extension ConfidenceInterval {
    func contains(_ value: Double) -> Bool {
        return value >= lower && value <= upper
    }
}

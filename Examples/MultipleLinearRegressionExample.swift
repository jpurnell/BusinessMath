//
//  MultipleLinearRegressionExample.swift
//  BusinessMath Examples
//
//  Demonstrates multiple linear regression with comprehensive diagnostics.
//  This file can be copied into an Xcode Playground for interactive exploration.
//

import Foundation
import BusinessMath

// MARK: - Example 1: Simple Linear Regression

print("=" + String(repeating: "=", count: 60))
print("Example 1: Simple Linear Regression")
print("=" + String(repeating: "=", count: 60))

// Advertising spend (in $1000s) vs Sales (in $1000s)
let advertisingSpend = [10.0, 15.0, 20.0, 25.0, 30.0, 35.0, 40.0, 45.0, 50.0]
let sales = [120.0, 145.0, 170.0, 195.0, 220.0, 245.0, 270.0, 295.0, 320.0]

// Format as matrix
let X1 = advertisingSpend.map { [$0] }

do {
    let result = try multipleLinearRegression(X: X1, y: sales)

    print("\nModel: Sales = β₀ + β₁ × Advertising")
    print(String(format: "       Sales = %.2f + %.2f × Advertising",
                 result.intercept, result.coefficients[0]))
    print(String(format: "\nR² = %.4f (%.1f%% of variance explained)",
                 result.rSquared, result.rSquared * 100))
    print(String(format: "F-statistic = %.2f (p = %.6f)",
                 result.fStatistic, result.fStatisticPValue))

    if result.fStatisticPValue < 0.05 {
        print("✓ Model is statistically significant (p < 0.05)")
    }

    print("\nCoefficient Details:")
    print(String(format: "  Intercept: %.2f (SE = %.2f, p = %.4f)",
                 result.intercept, result.standardErrors[0], result.pValues[0]))
    print(String(format: "  Advertising: %.2f (SE = %.2f, p = %.4f)",
                 result.coefficients[0], result.standardErrors[1], result.pValues[1]))

    // Make a prediction
    let newAdvertising = 55.0
    let predictedSales = result.intercept + result.coefficients[0] * newAdvertising
    print(String(format: "\nPrediction: $%.0fk advertising → $%.0fk sales",
                 newAdvertising, predictedSales))

} catch {
    print("Error: \(error)")
}

// MARK: - Example 2: Multiple Regression

print("\n" + String(repeating: "=", count: 60))
print("Example 2: Multiple Regression - House Prices")
print(String(repeating: "=", count: 60))

// House data: Size (sq ft), Age (years) → Price ($1000s)
let sizes = [1200.0, 1500.0, 1800.0, 2100.0, 2400.0, 2700.0, 3000.0, 2200.0]
let ages = [10.0, 5.0, 15.0, 8.0, 3.0, 12.0, 2.0, 6.0]
let prices = [180.0, 240.0, 210.0, 280.0, 340.0, 300.0, 420.0, 295.0]

let X2 = zip(sizes, ages).map { [$0, $1] }

do {
    let result = try multipleLinearRegression(X: X2, y: prices)

    print("\nModel: Price = β₀ + β₁×Size + β₂×Age")
    print(String(format: "       Price = %.2f + %.4f×Size + %.4f×Age",
                 result.intercept, result.coefficients[0], result.coefficients[1]))

    print(String(format: "\nModel Fit: R² = %.4f, Adjusted R² = %.4f",
                 result.rSquared, result.adjustedRSquared))

    print("\nCoefficient Interpretations:")
    print(String(format: "  Size: $%.2f per sq ft (p = %.4f)",
                 result.coefficients[0], result.pValues[1]))

    if result.pValues[1] < 0.05 {
        print("    ✓ Size is a significant predictor")
    }

    print(String(format: "  Age: $%.2f per year (p = %.4f)",
                 result.coefficients[1], result.pValues[2]))

    if result.pValues[2] < 0.05 {
        print("    ✓ Age is a significant predictor")
    }

    // Check multicollinearity
    print("\nMulticollinearity Check (VIF):")
    let predictorNames = ["Size", "Age"]
    for (i, vif) in result.vif.enumerated() {
        let status = vif < 5 ? "✓ Low" : vif < 10 ? "⚠️ Moderate" : "✗ High"
        print(String(format: "  %@: VIF = %.2f (%@)",
                     predictorNames[i], vif, status))
    }

    // Confidence intervals
    print("\n95% Confidence Intervals:")
    for i in 0..<result.coefficients.count {
        let ci = result.confidenceIntervals[i + 1]
        print(String(format: "  %@: [%.4f, %.4f]",
                     predictorNames[i], ci.lower, ci.upper))
    }

    // Predict new house
    let newHouse = [2500.0, 7.0]  // 2500 sq ft, 7 years old
    let predictedPrice = result.intercept +
                        result.coefficients[0] * newHouse[0] +
                        result.coefficients[1] * newHouse[1]
    print(String(format: "\nPrediction: 2500 sq ft, 7 years old → $%.0fk",
                 predictedPrice))

    // Residual analysis
    print(String(format: "\nResidual Analysis:"))
    print(String(format: "  Residual Std Error: %.2f", result.residualStandardError))
    let meanAbsResidual = result.residuals.map(abs).reduce(0, +) / Double(result.residuals.count)
    print(String(format: "  Mean Absolute Residual: %.2f", meanAbsResidual))

    // Check for outliers
    let outliers = result.residuals.enumerated().filter {
        abs($0.element) > 2 * result.residualStandardError
    }
    if !outliers.isEmpty {
        print("  ⚠️ Potential outliers at indices: \(outliers.map { $0.offset })")
    } else {
        print("  ✓ No major outliers detected")
    }

} catch {
    print("Error: \(error)")
}

// MARK: - Example 3: Detecting Multicollinearity

print("\n" + String(repeating: "=", count: 60))
print("Example 3: Detecting Multicollinearity")
print(String(repeating: "=", count: 60))

// Highly correlated predictors: x2 ≈ 2×x1
let x1 = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
let x2 = [2.1, 3.9, 6.2, 7.8, 10.1, 11.9, 14.2, 15.8]  // ≈ 2×x1 with noise
let y3 = [3.0, 5.0, 7.0, 9.0, 11.0, 13.0, 15.0, 17.0]

let X3 = zip(x1, x2).map { [$0, $1] }

do {
    let result = try multipleLinearRegression(X: X3, y: y3)

    print("\nVIF Analysis:")
    print(String(format: "  x₁: VIF = %.2f", result.vif[0]))
    print(String(format: "  x₂: VIF = %.2f", result.vif[1]))

    if result.vif.contains(where: { $0 > 10 }) {
        print("\n⚠️ SEVERE multicollinearity detected (VIF > 10)!")
        print("Recommendation: Remove one predictor or combine them")
    } else if result.vif.contains(where: { $0 > 5 }) {
        print("\n⚠️ Moderate multicollinearity detected (VIF > 5)")
        print("Recommendation: Consider removing or transforming predictors")
    } else {
        print("\n✓ No significant multicollinearity (all VIF < 5)")
    }

    // Show unstable coefficients due to multicollinearity
    print("\nCoefficient Standard Errors:")
    for i in 0..<result.coefficients.count {
        print(String(format: "  β%d: %.4f (SE = %.4f, relative SE = %.1f%%)",
                     i + 1,
                     result.coefficients[i],
                     result.standardErrors[i + 1],
                     (result.standardErrors[i + 1] / abs(result.coefficients[i])) * 100))
    }

} catch {
    print("Error: \(error)")
}

// MARK: - Example 4: Model Comparison

print("\n" + String(repeating: "=", count: 60))
print("Example 4: Model Comparison with Adjusted R²")
print(String(repeating: "=", count: 60))

let baseData = [10.0, 15.0, 20.0, 25.0, 30.0, 35.0, 40.0, 45.0]
let outcome = [25.0, 32.0, 38.0, 47.0, 53.0, 61.0, 68.0, 76.0]

// Model 1: Single predictor
let X_simple = baseData.map { [$0] }

// Model 2: Add irrelevant predictor
let noise = [1.2, 3.4, 2.1, 4.3, 1.8, 3.9, 2.7, 4.1]
let X_complex = zip(baseData, noise).map { [$0, $1] }

do {
    let model1 = try multipleLinearRegression(X: X_simple, y: outcome)
    let model2 = try multipleLinearRegression(X: X_complex, y: outcome)

    print("\nModel 1 (Simple):")
    print(String(format: "  R² = %.4f", model1.rSquared))
    print(String(format: "  Adjusted R² = %.4f", model1.adjustedRSquared))
    print(String(format: "  Predictors: %d", model1.p))

    print("\nModel 2 (With Noise Predictor):")
    print(String(format: "  R² = %.4f", model2.rSquared))
    print(String(format: "  Adjusted R² = %.4f", model2.adjustedRSquared))
    print(String(format: "  Predictors: %d", model2.p))

    print("\nModel Comparison:")
    if model2.adjustedRSquared > model1.adjustedRSquared {
        print("  → Model 2 is better (higher Adjusted R²)")
    } else {
        print("  → Model 1 is better (higher Adjusted R²)")
        print("  → Adding the second predictor didn't improve the model")
    }

    // Check if second predictor is significant
    if model2.pValues[2] > 0.05 {
        print(String(format: "  → Second predictor not significant (p = %.4f > 0.05)",
                     model2.pValues[2]))
    }

} catch {
    print("Error: \(error)")
}

print("\n" + String(repeating: "=", count: 60))
print("Examples Complete!")
print(String(repeating: "=", count: 60))

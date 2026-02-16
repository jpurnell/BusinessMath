//
//  LinearRegressionConvenienceExample.swift
//  BusinessMath
//
//  Created by Claude Code on 2026-02-15.
//

import Foundation
import BusinessMath

/// Examples demonstrating the linearRegression and polynomialRegression convenience functions.
public func runLinearRegressionConvenienceExamples() {
    print("\n========================================")
    print("Linear Regression Convenience Examples")
    print("========================================\n")

    // MARK: - Example 1: Simple Linear Regression

    print("1️⃣ SIMPLE LINEAR REGRESSION")
    print("─────────────────────────────────────────\n")

    // Advertising spend vs Sales
    let advertisingSpend = [10.0, 15.0, 20.0, 25.0, 30.0, 35.0, 40.0]
    let sales = [120.0, 145.0, 170.0, 195.0, 220.0, 245.0, 270.0]

    do {
        let result = try linearRegression(x: advertisingSpend, y: sales)

        print("Model: Sales = \(String(format: "%.2f", result.intercept)) + \(String(format: "%.2f", result.coefficients[0]))×Advertising\n")

        print("Diagnostics:")
        print("  • R² = \(String(format: "%.4f", result.rSquared))")
        print("  • F-statistic p-value = \(String(format: "%.6f", result.fStatisticPValue))")
        print("  • Advertising coefficient: \(String(format: "%.2f", result.coefficients[0]))")
        print("    - Standard error: \(String(format: "%.2f", result.standardErrors[1]))")
        print("    - p-value: \(String(format: "%.6f", result.pValues[1]))")
        print("    - 95% CI: [\(String(format: "%.2f", result.confidenceIntervals[1].lower)), \(String(format: "%.2f", result.confidenceIntervals[1].upper))]\n")

        print("Interpretation:")
        print("  For every $1,000 increase in advertising spend,")
        print("  sales increase by $\(String(format: "%.2f", result.coefficients[0] * 1000)).\n")
    } catch {
        print("Error: \(error)\n")
    }

    // MARK: - Example 2: Polynomial Regression - Quadratic

    print("\n2️⃣ POLYNOMIAL REGRESSION (Degree 2)")
    print("─────────────────────────────────────────\n")

    // Price vs Revenue (inverted U-shape - demand curve)
    let price = [10.0, 15.0, 20.0, 25.0, 30.0, 35.0, 40.0, 45.0, 50.0]
    var revenue: [Double] = []

    // True relationship: Revenue = -0.2×Price² + 15×Price
    for p in price {
        revenue.append(-0.2 * p * p + 15.0 * p)
    }

    do {
        let result = try polynomialRegression(x: price, y: revenue, degree: 2)

        print("Model: Revenue = \(String(format: "%.2f", result.intercept))")
        print("              + \(String(format: "%.2f", result.coefficients[0]))×Price")
        print("              + \(String(format: "%.2f", result.coefficients[1]))×Price²\n")

        print("Diagnostics:")
        print("  • R² = \(String(format: "%.4f", result.rSquared))")
        print("  • Adjusted R² = \(String(format: "%.4f", result.adjustedRSquared))")
        print("  • VIF: \(result.vif.map { String(format: "%.2f", $0) })\n")

        // Find optimal price (vertex of parabola)
        let a = result.coefficients[1]
        let b = result.coefficients[0]
        let optimalPrice = -b / (2.0 * a)
        let maxRevenue = result.intercept + b * optimalPrice + a * optimalPrice * optimalPrice

        print("Optimal Pricing:")
        print("  • Price: $\(String(format: "%.2f", optimalPrice))")
        print("  • Maximum Revenue: $\(String(format: "%.2f", maxRevenue))K\n")

        print("Interpretation:")
        print("  The quadratic model captures the inverted-U relationship.")
        print("  Revenue increases with price up to $\(String(format: "%.2f", optimalPrice)), then decreases.\n")
    } catch {
        print("Error: \(error)\n")
    }

    // MARK: - Example 3: Polynomial Regression - Cubic

    print("\n3️⃣ POLYNOMIAL REGRESSION (Degree 3)")
    print("─────────────────────────────────────────\n")

    // S-shaped growth curve
    let time = Array(stride(from: 0.0, through: 10.0, by: 0.5))
    var adoption: [Double] = []

    // Simplified S-curve: y = -0.1x³ + 1.5x² - 2x + 5
    for t in time {
        adoption.append(-0.1 * pow(t, 3) + 1.5 * pow(t, 2) - 2.0 * t + 5.0)
    }

    do {
        let result = try polynomialRegression(x: time, y: adoption, degree: 3)

        print("Model: Adoption = \(String(format: "%.2f", result.intercept))")
        print("               + \(String(format: "%.2f", result.coefficients[0]))×t")
        print("               + \(String(format: "%.2f", result.coefficients[1]))×t²")
        print("               + \(String(format: "%.2f", result.coefficients[2]))×t³\n")

        print("Diagnostics:")
        print("  • R² = \(String(format: "%.6f", result.rSquared))")
        print("  • All coefficients significant: \(result.pValues.allSatisfy { $0 < 0.05 } ? "✓" : "✗")")
        print("  • VIF values: \(result.vif.map { String(format: "%.1f", $0) })")

        if result.vif.contains(where: { $0 > 10 }) {
            print("    ⚠️ High multicollinearity detected (VIF > 10)")
            print("       This is common with polynomial terms but doesn't affect predictions.\n")
        }

        print("\nInterpretation:")
        print("  The cubic model captures the S-shaped adoption curve,")
        print("  showing slow initial growth, rapid acceleration, then saturation.\n")
    } catch {
        print("Error: \(error)\n")
    }

    // MARK: - Example 4: Comparing Linear vs Polynomial

    print("\n4️⃣ MODEL COMPARISON: Linear vs Polynomial")
    print("─────────────────────────────────────────\n")

    let x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
    var y: [Double] = []

    // True relationship is quadratic
    for xi in x {
        y.append(2.0 * xi * xi - 3.0 * xi + 1.0)
    }

    do {
        let linearResult = try linearRegression(x: x, y: y)
        let quadraticResult = try polynomialRegression(x: x, y: y, degree: 2)

        print("Linear Model:")
        print("  • R² = \(String(format: "%.4f", linearResult.rSquared))")
        print("  • Residual SE = \(String(format: "%.2f", linearResult.residualStandardError))\n")

        print("Quadratic Model:")
        print("  • R² = \(String(format: "%.6f", quadraticResult.rSquared))")
        print("  • Adjusted R² = \(String(format: "%.6f", quadraticResult.adjustedRSquared))")
        print("  • Residual SE = \(String(format: "%.6f", quadraticResult.residualStandardError))\n")

        print("Conclusion:")
        print("  The quadratic model is superior (R² closer to 1, lower residual error).")
        print("  Always compare models using adjusted R² when using different numbers of predictors.\n")
    } catch {
        print("Error: \(error)\n")
    }

    print("========================================")
    print("Examples Complete! ✓")
    print("========================================\n")
}

// Run examples if this file is executed directly
#if swift(>=5.9)
if CommandLine.arguments.first?.contains("LinearRegressionConvenienceExample") == true {
    runLinearRegressionConvenienceExamples()
}
#endif

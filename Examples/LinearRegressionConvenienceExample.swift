//
//  LinearRegressionConvenienceExample.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-02-15.
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

        print("Model: Sales = \(result.intercept.number(2)) + \(result.coefficients[0].number(2))×Advertising\n")

        print("Diagnostics:")
        print("  • R² = \(result.rSquared.number(4))")
        print("  • F-statistic p-value = \(result.fStatisticPValue.number(6))")
        print("  • Advertising coefficient: \(result.coefficients[0].number(2))")
        print("    - Standard error: \(result.standardErrors[1].number(2))")
        print("    - p-value: \(result.pValues[1].number(6))")
        print("    - 95% CI: [\(result.confidenceIntervals[1].lower.number(2)), \(result.confidenceIntervals[1].upper.number(2))]\n")

        print("Interpretation:")
        print("  For every $1,000 increase in advertising spend,")
        print("  sales increase by $\((result.coefficients[0] * 1000).number(2)).\n")
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

        print("Model: Revenue = \(result.intercept.number(2))")
        print("              + \(result.coefficients[0].number(2))×Price")
        print("              + \(result.coefficients[1].number(2))×Price²\n")

        print("Diagnostics:")
        print("  • R² = \(result.rSquared.number(4))")
        print("  • Adjusted R² = \(result.adjustedRSquared.number(4))")
        print("  • VIF: \(result.vif.map { $0.number(2) })\n")

        // Find optimal price (vertex of parabola)
        let a = result.coefficients[1]
        let b = result.coefficients[0]
        let optimalPrice = -b / (2.0 * a)
        let maxRevenue = result.intercept + b * optimalPrice + a * optimalPrice * optimalPrice

        print("Optimal Pricing:")
        print("  • Price: $\(optimalPrice.number(2))")
        print("  • Maximum Revenue: $\(maxRevenue.number(2))K\n")

        print("Interpretation:")
        print("  The quadratic model captures the inverted-U relationship.")
        print("  Revenue increases with price up to $\(optimalPrice.number(2)), then decreases.\n")
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

        print("Model: Adoption = \(result.intercept.number(2))")
        print("               + \(result.coefficients[0].number(2))×t")
        print("               + \(result.coefficients[1].number(2))×t²")
        print("               + \(result.coefficients[2].number(2))×t³\n")

        print("Diagnostics:")
        print("  • R² = \(result.rSquared.number(6))")
        print("  • All coefficients significant: \(result.pValues.allSatisfy { $0 < 0.05 } ? "✓" : "✗")")
        print("  • VIF values: \(result.vif.map { $0.number(1) })")

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
        print("  • R² = \(linearResult.rSquared.number(4))")
        print("  • Residual SE = \(linearResult.residualStandardError.number(2))\n")

        print("Quadratic Model:")
        print("  • R² = \(quadraticResult.rSquared.number(6))")
        print("  • Adjusted R² = \(quadraticResult.adjustedRSquared.number(6))")
        print("  • Residual SE = \(quadraticResult.residualStandardError.number(6))\n")

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

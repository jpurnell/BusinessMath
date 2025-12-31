//
//  OptimizationMacrosExample.swift
//  BusinessMath Examples
//
//  Demonstrates using Swift macros for optimization DSL (Phase 4.2)
//  Learn how @Variable, @Constraint, and @Objective simplify optimization problems
//
//  Created on December 30, 2025.
//

import Foundation
import BusinessMath
import BusinessMathMacros

// MARK: - Example 1: Simple Portfolio Optimization

print("=== Example 1: Simple Portfolio Optimization ===\n")

/// Portfolio allocation problem using optimization macros
struct PortfolioProblem {
    // Decision variables with bounds
    @Variable(bounds: 0...1)
    var stocks: Double

    @Variable(bounds: 0...1)
    var bonds: Double

    // Portfolio parameters
    var stockReturn: Double = 0.12
    var bondReturn: Double = 0.05
    var stockRisk: Double = 0.20
    var bondRisk: Double = 0.05

    // Constraint: allocations must sum to 1
    @Constraint
    func allocationSumToOne() -> Bool {
        return abs(stocks + bonds - 1.0) < 0.001
    }

    // Objective: maximize return
    @Objective
    func expectedReturn() -> Double {
        return stocks * stockReturn + bonds * bondReturn
    }

    // Helper to manually optimize (since we haven't implemented full code generation)
    func optimize() -> (stocks: Double, bonds: Double, return: Double) {
        // For this simple case, we can solve analytically
        // Since we want to maximize return and have no risk constraint,
        // we allocate everything to stocks (higher return)
        let optimalStocks = 1.0
        let optimalBonds = 0.0
        let optimalReturn = optimalStocks * stockReturn + optimalBonds * bondReturn

        return (optimalStocks, optimalBonds, optimalReturn)
    }
}

let portfolio = PortfolioProblem()

// The macro automatically generates:
// - stocks_bounds: ClosedRange<Double>
// - bonds_bounds: ClosedRange<Double>
// - allocationSumToOne_constraint: String
// - objectiveFunction: () -> Double

print("Decision Variables:")
print("  stocks bounds: \(portfolio.stocks_bounds)")
print("  bonds bounds: \(portfolio.bonds_bounds)")

print("\nConstraints:")
print("  \(portfolio.allocationSumToOne_constraint): allocations sum to 1")

print("\nObjective:")
print("  Maximize: \(portfolio.objectiveFunction)")

let result = portfolio.optimize()
print("\nOptimal Solution:")
print("  Stocks: \(String(format: "%.1f%%", result.stocks * 100))")
print("  Bonds: \(String(format: "%.1f%%", result.bonds * 100))")
print("  Expected Return: \(String(format: "%.1f%%", result.return * 100))")

print("\n")

// MARK: - Example 2: Production Planning

print("=== Example 2: Production Planning ===\n")

/// Factory production optimization using macros
struct ProductionProblem {
    // Decision variables
    @Variable(bounds: 0...100)
    var chairs: Double

    @Variable(bounds: 0...100)
    var tables: Double

    // Resource constraints
    let woodAvailable = 40.0
    let laborAvailable = 50.0

    // Resource requirements
    let chairWood = 1.0
    let chairLabor = 2.0
    let tableWood = 2.0
    let tableLabor = 1.0

    // Profit per unit
    let chairProfit = 40.0
    let tableProfit = 30.0

    @Constraint
    func woodConstraint() -> Bool {
        return (chairs * chairWood + tables * tableWood) <= woodAvailable
    }

    @Constraint
    func laborConstraint() -> Bool {
        return (chairs * chairLabor + tables * tableLabor) <= laborAvailable
    }

    @Objective
    func totalProfit() -> Double {
        return chairs * chairProfit + tables * tableProfit
    }

    func optimize() -> (chairs: Double, tables: Double, profit: Double) {
        // Using linear programming (simplex method)
        let solver = SimplexSolver()

        let result = try! solver.maximize(
            objective: [chairProfit, tableProfit],
            subjectTo: [
                SimplexConstraint(coefficients: [chairWood, tableWood], relation: .lessOrEqual, rhs: woodAvailable),
                SimplexConstraint(coefficients: [chairLabor, tableLabor], relation: .lessOrEqual, rhs: laborAvailable)
            ]
        )

        return (result.solution[0], result.solution[1], result.objectiveValue)
    }
}

let production = ProductionProblem()

print("Decision Variables:")
print("  chairs bounds: \(production.chairs_bounds)")
print("  tables bounds: \(production.tables_bounds)")

print("\nConstraints:")
print("  \(production.woodConstraint_constraint): wood usage ≤ \(production.woodAvailable)")
print("  \(production.laborConstraint_constraint): labor usage ≤ \(production.laborAvailable)")

let prodResult = production.optimize()
print("\nOptimal Production Plan:")
print("  Chairs: \(String(format: "%.0f", prodResult.chairs)) units")
print("  Tables: \(String(format: "%.0f", prodResult.tables)) units")
print("  Maximum Profit: $\(String(format: "%.2f", prodResult.profit))")

print("\n")

// MARK: - Example 3: Parameter Estimation

print("=== Example 3: Parameter Estimation ===\n")

/// Curve fitting using optimization macros
struct CurveFittingProblem {
    // Model parameters to estimate
    @Variable(bounds: -10...10)
    var slope: Double

    @Variable(bounds: -10...10)
    var intercept: Double

    // Data points
    let xData: [Double] = [1, 2, 3, 4, 5]
    let yData: [Double] = [2.1, 4.0, 5.9, 8.1, 10.0]

    @Objective
    func sumOfSquaredErrors() -> Double {
        var sse = 0.0
        for i in 0..<xData.count {
            let predicted = slope * xData[i] + intercept
            let error = yData[i] - predicted
            sse += error * error
        }
        return sse  // We'll minimize this
    }

    func optimize() -> (slope: Double, intercept: Double, error: Double) {
        // Use gradient descent for this simple case
        var currentSlope = 0.0
        var currentIntercept = 0.0
        let learningRate = 0.01
        let iterations = 1000

        for _ in 0..<iterations {
            // Compute gradients
            var slopeGrad = 0.0
            var interceptGrad = 0.0

            for i in 0..<xData.count {
                let predicted = currentSlope * xData[i] + currentIntercept
                let error = predicted - yData[i]
                slopeGrad += 2 * error * xData[i]
                interceptGrad += 2 * error
            }

            // Update parameters
            currentSlope -= learningRate * slopeGrad / Double(xData.count)
            currentIntercept -= learningRate * interceptGrad / Double(xData.count)
        }

        // Compute final error
        var finalError = 0.0
        for i in 0..<xData.count {
            let predicted = currentSlope * xData[i] + currentIntercept
            let error = yData[i] - predicted
            finalError += error * error
        }

        return (currentSlope, currentIntercept, finalError)
    }
}

let curveFit = CurveFittingProblem()

print("Parameter Bounds:")
print("  slope bounds: \(curveFit.slope_bounds)")
print("  intercept bounds: \(curveFit.intercept_bounds)")

let fitResult = curveFit.optimize()
print("\nOptimal Parameters:")
print("  Slope: \(String(format: "%.3f", fitResult.slope))")
print("  Intercept: \(String(format: "%.3f", fitResult.intercept))")
print("  SSE: \(String(format: "%.3f", fitResult.error))")

print("\n")

// MARK: - Example 4: Benefits of Using Macros

print("=== Example 4: Benefits of Optimization Macros ===\n")

print("✨ Benefits:")
print("  1. Self-documenting code - Clear what's a variable, constraint, or objective")
print("  2. Bounds checking - Automatically track valid ranges for variables")
print("  3. Constraint identification - Easy to enumerate all constraints programmatically")
print("  4. Objective clarity - Single source of truth for the objective function")
print("  5. Less boilerplate - No manual property tracking")

print("\n📝 Without Macros (Old Way):")
print("""
struct Portfolio {
    var stocks: Double
    var bonds: Double

    let stocksBounds = 0.0...1.0
    let bondsBounds = 0.0...1.0
    let constraints = ["sumToOne"]

    func expectedReturn() -> Double {
        return stocks * 0.12 + bonds * 0.05
    }
}
""")

print("\n✨ With Macros (New Way):")
print("""
struct Portfolio {
    @Variable(bounds: 0...1)
    var stocks: Double

    @Variable(bounds: 0...1)
    var bonds: Double

    @Constraint
    func sumToOne() -> Bool {
        return stocks + bonds == 1.0
    }

    @Objective
    func expectedReturn() -> Double {
        return stocks * 0.12 + bonds * 0.05
    }
}
""")

print("\n🎯 Key Advantages:")
print("  • Bounds are declared right with the variable")
print("  • Constraints are explicitly marked")
print("  • Objective function is clearly identified")
print("  • Generated properties provide programmatic access")

print("\n")

// MARK: - Summary

print(String(repeating: "=", count: 60))
print("✅ Optimization Macros Examples Complete!")
print(String(repeating: "=", count: 60))

print("\nKey Takeaways:")
print("  • @Variable adds bounds tracking to decision variables")
print("  • @Constraint marks constraint functions")
print("  • @Objective identifies the function to optimize")
print("  • Macros generate helper properties automatically")
print("  • Clean, declarative syntax for optimization problems")

print("\nNext Steps:")
print("  • Explore @Validated macro for parameter validation (Phase 4.3)")
print("  • Learn builder generation macros (Phase 4.4)")
print("  • Study async wrapper macros (Phase 4.5)")

print("\nHappy optimizing! 🚀\n")

//
//  ConstrainedOptimizationExample.swift
//  BusinessMath Examples
//
//  Demonstrates constrained optimization using equality and inequality constraints
//

import Foundation
@testable import BusinessMath

/// Example: Equality-constrained optimization
func equalityConstrainedExample() throws {
    print("=== Equality-Constrained Optimization ===\n")

    // Minimize f(x, y) = x² + y² subject to x + y = 1
    print("Problem: Minimize x² + y² subject to x + y = 1")
    print("(Find point on line x + y = 1 closest to origin)\n")

    let objective: (VectorN<Double>) -> Double = { v in
        let x = v[0], y = v[1]
        return x*x + y*y
    }

    let optimizer = ConstrainedOptimizer<VectorN<Double>>()

    let result = try optimizer.minimize(
        objective,
        from: VectorN([0.0, 1.0]),  // Start on constraint
        subjectTo: [
            .equality { v in v[0] + v[1] - 1.0 }  // x + y = 1
        ]
    )

    print("Solution:")
    print(String(format: "  x = %.6f", result.solution[0]))
    print(String(format: "  y = %.6f", result.solution[1]))
    print(String(format: "  Objective value: %.6f", result.value))
    print()

    print("Verification:")
    print(String(format: "  Constraint (x + y - 1): %.10f (should be ~0)",
                  result.solution[0] + result.solution[1] - 1.0))
    print(String(format: "  Analytical solution: x = y = 0.5"))
    print()

    if let lambda = result.lagrangeMultipliers?.first {
        print(String(format: "Lagrange Multiplier λ = %.6f", lambda))
        print("(Shadow price: how much objective improves if we relax constraint)")
    }

    print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Inequality-constrained optimization
func inequalityConstrainedExample() throws {
    print("=== Inequality-Constrained Optimization ===\n")

    // Minimize f(x, y) = (x - 2)² + (y - 2)² subject to x + y ≤ 2, x ≥ 0, y ≥ 0
    print("Problem: Minimize (x - 2)² + (y - 2)² ")
    print("         subject to x + y ≤ 2, x ≥ 0, y ≥ 0")
    print("(Find point in feasible region closest to (2, 2))\n")

    let objective: (VectorN<Double>) -> Double = { v in
        let x = v[0], y = v[1]
        let dx = x - 2.0
        let dy = y - 2.0
        return dx*dx + dy*dy
    }

    let optimizer = InequalityOptimizer<VectorN<Double>>()

    let result = try optimizer.minimize(
        objective,
        from: VectorN([0.5, 0.5]),
        subjectTo: [
            .inequality { v in v[0] + v[1] - 2.0 },  // x + y ≤ 2
            .inequality { v in -v[0] },               // x ≥ 0
            .inequality { v in -v[1] }                // y ≥ 0
        ]
    )

    print("Solution:")
    print(String(format: "  x = %.6f", result.solution[0]))
    print(String(format: "  y = %.6f", result.solution[1]))
    print(String(format: "  Distance to (2,2): %.6f", sqrt(result.value)))
    print()

    print("Constraint status:")
    let x = result.solution[0], y = result.solution[1]
    print(String(format: "  x + y = %.6f (limit: 2.0) %@",
                  x + y, abs(x + y - 2.0) < 1e-4 ? "ACTIVE" : ""))
    print(String(format: "  x = %.6f (≥ 0) %@",
                  x, x < 1e-4 ? "ACTIVE" : ""))
    print(String(format: "  y = %.6f (≥ 0) %@",
                  y, y < 1e-4 ? "ACTIVE" : ""))
    print()

    print("Analytical solution: x = y = 1.0 (constraint x + y ≤ 2 is active)")

    print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Box-constrained optimization
func boxConstrainedExample() throws {
    print("=== Box-Constrained Optimization ===\n")

    // Minimize Rosenbrock function with bounds
    print("Problem: Minimize Rosenbrock function")
    print("         subject to -2 ≤ x ≤ 2, -1 ≤ y ≤ 3\n")

    let rosenbrock: (VectorN<Double>) -> Double = { v in
        let x = v[0], y = v[1]
        let a = 1 - x
        let b = y - x*x
        return a*a + 100*b*b
    }

    let optimizer = InequalityOptimizer<VectorN<Double>>()

    // Box constraints: lower ≤ x ≤ upper
    let result = try optimizer.minimize(
        rosenbrock,
        from: VectorN([0.0, 0.0]),
        subjectTo: [
            .inequality { v in v[0] - 2.0 },   // x ≤ 2
            .inequality { v in -2.0 - v[0] },  // x ≥ -2
            .inequality { v in v[1] - 3.0 },   // y ≤ 3
            .inequality { v in -1.0 - v[1] }   // y ≥ -1
        ]
    )

    print("Solution:")
    print(String(format: "  x = %.6f", result.solution[0]))
    print(String(format: "  y = %.6f", result.solution[1]))
    print(String(format: "  Objective value: %.6f", result.value))
    print()

    print("Unconstrained minimum: (1, 1)")
    print("This falls within bounds, so constrained solution should be same.")

    print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Constrained least squares (curve fitting)
func constrainedLeastSquaresExample() throws {
    print("=== Constrained Least Squares ===\n")

    // Fit y = a + bx to data, but require a ≥ 0, b ≥ 0
    let dataPoints: [(x: Double, y: Double)] = [
        (0, 1.2), (1, 2.8), (2, 4.1), (3, 5.9), (4, 7.2)
    ]

    print("Problem: Fit y = a + bx to data")
    print("         subject to a ≥ 0, b ≥ 0 (non-negative coefficients)")
    print()
    print("Data points:")
    for point in dataPoints {
        print(String(format: "  (%.0f, %.1f)", point.x, point.y))
    }
    print()

    let leastSquares: (VectorN<Double>) -> Double = { params in
        let a = params[0], b = params[1]
        return dataPoints.map { point in
            let predicted = a + b * point.x
            let error = point.y - predicted
            return error * error
        }.reduce(0, +)
    }

    let optimizer = InequalityOptimizer<VectorN<Double>>()

    let result = try optimizer.minimize(
        leastSquares,
        from: VectorN([1.0, 1.0]),
        subjectTo: [
            .inequality { v in -v[0] },  // a ≥ 0
            .inequality { v in -v[1] }   // b ≥ 0
        ]
    )

    let a = result.solution[0]
    let b = result.solution[1]

    print("Fitted model:")
    print(String(format: "  y = %.4f + %.4fx", a, b))
    print(String(format: "  Sum of squared errors: %.4f", result.value))
    print()

    print("Predictions:")
    for point in dataPoints {
        let predicted = a + b * point.x
        print(String(format: "  x=%.0f: actual=%.1f, predicted=%.2f, error=%.2f",
                      point.x, point.y, predicted, point.y - predicted))
    }

    print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Resource allocation with equality constraint
func resourceAllocationExample() throws {
    print("=== Resource Allocation with Budget Constraint ===\n")

    // Allocate budget to maximize utility: U(x,y,z) = x^0.5 + y^0.5 + z^0.5
    // Subject to: x + 2y + 3z = 100 (budget), x,y,z ≥ 0

    print("Problem: Allocate budget to maximize utility")
    print("         U(x, y, z) = √x + √y + √z")
    print("         Subject to: x + 2y + 3z = 100")
    print("         (x costs $1, y costs $2, z costs $3)")
    print()

    // Maximize utility = minimize negative utility
    let objective: (VectorN<Double>) -> Double = { v in
        let x = v[0], y = v[1], z = v[2]
        return -(sqrt(x) + sqrt(y) + sqrt(z))
    }

    let optimizer = ConstrainedOptimizer<VectorN<Double>>()

    let result = try optimizer.minimize(
        objective,
        from: VectorN([10.0, 10.0, 10.0]),
        subjectTo: [
            .equality { v in v[0] + 2*v[1] + 3*v[2] - 100.0 }  // Budget constraint
        ]
    )

    let x = result.solution[0]
    let y = result.solution[1]
    let z = result.solution[2]

    print("Optimal allocation:")
    print(String(format: "  x = %.2f units ($%.2f)", x, x))
    print(String(format: "  y = %.2f units ($%.2f)", y, 2*y))
    print(String(format: "  z = %.2f units ($%.2f)", z, 3*z))
    print(String(format: "  Total cost: $%.2f", x + 2*y + 3*z))
    print()

    let utility = sqrt(x) + sqrt(y) + sqrt(z)
    print(String(format: "Total utility: %.4f", utility))
    print()

    if let lambda = result.lagrangeMultipliers?.first {
        print(String(format: "Lagrange multiplier (λ = %.6f)", lambda))
        print("Interpretation: Marginal utility per dollar of budget")
        print(String(format: "  If we had $1 more, utility would increase by ~%.6f", abs(lambda)))
    }

    print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Portfolio optimization with leverage constraint
func portfolioWithLeverageExample() throws {
    print("=== Portfolio Optimization with Leverage Constraint ===\n")

    // Minimize variance subject to target return and leverage limit
    let assets = ["Stock A", "Stock B", "Bond"]
    let expectedReturns = [0.12, 0.18, 0.04]
    let covariance = [
        [0.04, 0.02, 0.00],
        [0.02, 0.09, 0.01],
        [0.00, 0.01, 0.01]
    ]

    print("Assets:")
    for (i, name) in assets.enumerated() {
        let ret = expectedReturns[i] * 100
        let vol = sqrt(covariance[i][i]) * 100
        print(String(format: "  %@: %.0f%% return, %.0f%% volatility", name, ret, vol))
    }
    print()

    print("Objective: Minimize variance")
    print("Constraints:")
    print("  • Target return ≥ 10%")
    print("  • Leverage limit: |w₁| + |w₂| + |w₃| ≤ 1.5 (max 50% leverage)")
    print("  • Fully invested: w₁ + w₂ + w₃ = 1")
    print()

    // Portfolio variance
    let variance: (VectorN<Double>) -> Double = { w in
        var variance = 0.0
        for i in 0..<3 {
            for j in 0..<3 {
                variance += w[i] * w[j] * covariance[i][j]
            }
        }
        return variance
    }

    let optimizer = InequalityOptimizer<VectorN<Double>>()

    let result = try optimizer.minimize(
        variance,
        from: VectorN([0.4, 0.4, 0.2]),
        subjectTo: [
            // Return constraint: w'r ≥ 0.10
            .inequality { w in
                let ret = w[0] * expectedReturns[0] +
                         w[1] * expectedReturns[1] +
                         w[2] * expectedReturns[2]
                return 0.10 - ret  // ≤ 0 means return ≥ 10%
            },
            // Fully invested: w₁ + w₂ + w₃ = 1
            .equality { w in w[0] + w[1] + w[2] - 1.0 },
            // Leverage limit (simplified): each weight in [-0.5, 1.5]
            .inequality { w in w[0] - 1.5 },
            .inequality { w in -0.5 - w[0] },
            .inequality { w in w[1] - 1.5 },
            .inequality { w in -0.5 - w[1] },
            .inequality { w in w[2] - 1.5 },
            .inequality { w in -0.5 - w[2] }
        ]
    )

    print("Optimal portfolio:")
    for (i, name) in assets.enumerated() {
        let weight = result.solution[i]
        print(String(format: "  %@: %.1f%%", name, weight * 100))
    }
    print()

    let weights = result.solution
    let portReturn = weights[0] * expectedReturns[0] +
                     weights[1] * expectedReturns[1] +
                     weights[2] * expectedReturns[2]
    let portVol = sqrt(result.value)

    print(String(format: "Portfolio return: %.2f%%", portReturn * 100))
    print(String(format: "Portfolio risk: %.2f%%", portVol * 100))
    print(String(format: "Sharpe ratio (rf=2%%): %.2f", (portReturn - 0.02) / portVol))

    print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Comparing unconstrained vs constrained solutions
func comparisonExample() throws {
    print("=== Unconstrained vs Constrained Comparison ===\n")

    // Minimize f(x, y) = x² + y² - 2x - 2y
    let objective: (VectorN<Double>) -> Double = { v in
        let x = v[0], y = v[1]
        return x*x + y*y - 2*x - 2*y
    }

    print("Problem: Minimize f(x, y) = x² + y² - 2x - 2y\n")

    // 1. Unconstrained
    print("1. Unconstrained optimization:")
    let unconstrainedOptimizer = MultivariateNewtonRaphson<VectorN<Double>>(method: .bfgs)
    let unconstrainedResult = try unconstrainedOptimizer.minimize(
        objective,
        from: VectorN([0.0, 0.0])
    )

    print(String(format: "   Solution: (%.4f, %.4f)",
                  unconstrainedResult.solution[0],
                  unconstrainedResult.solution[1]))
    print(String(format: "   Value: %.4f", unconstrainedResult.value))
    print(String(format: "   Analytical solution: (1, 1)"))
    print()

    // 2. With constraint x + y = 1
    print("2. With constraint x + y = 1:")
    let constrainedOptimizer = ConstrainedOptimizer<VectorN<Double>>()
    let constrainedResult = try constrainedOptimizer.minimize(
        objective,
        from: VectorN([0.5, 0.5]),
        subjectTo: [
            .equality { v in v[0] + v[1] - 1.0 }
        ]
    )

    print(String(format: "   Solution: (%.4f, %.4f)",
                  constrainedResult.solution[0],
                  constrainedResult.solution[1]))
    print(String(format: "   Value: %.4f", constrainedResult.value))
    print(String(format: "   Constraint: x + y = %.6f",
                  constrainedResult.solution[0] + constrainedResult.solution[1]))
    print()

    // 3. With constraint x, y ≥ 0
    print("3. With constraints x ≥ 0, y ≥ 0:")
    let inequalityOptimizer = InequalityOptimizer<VectorN<Double>>()
    let inequalityResult = try inequalityOptimizer.minimize(
        objective,
        from: VectorN([0.5, 0.5]),
        subjectTo: [
            .inequality { v in -v[0] },  // x ≥ 0
            .inequality { v in -v[1] }   // y ≥ 0
        ]
    )

    print(String(format: "   Solution: (%.4f, %.4f)",
                  inequalityResult.solution[0],
                  inequalityResult.solution[1]))
    print(String(format: "   Value: %.4f", inequalityResult.value))
    print()

    print("Comparison:")
    print("  • Unconstrained: finds global minimum")
    print("  • Equality constrained: finds best point on constraint line")
    print("  • Inequality constrained: finds best point in feasible region")
    print("  • Each adds restrictions → higher optimal value")

    print("\n" + String(repeating: "=", count: 50) + "\n")
}

// Run examples
print("\n")
print("BusinessMath - Constrained Optimization Examples")
print(String(repeating: "=", count: 50))
print("\n")

try equalityConstrainedExample()
try inequalityConstrainedExample()
try boxConstrainedExample()
try constrainedLeastSquaresExample()
try resourceAllocationExample()
try portfolioWithLeverageExample()
try comparisonExample()

print("Examples complete!")
print()
print("Key Concepts:")
print("  • Equality Constraints: h(x) = 0")
print("  • Inequality Constraints: g(x) ≤ 0")
print("  • Lagrange Multipliers: Shadow prices of constraints")
print("  • Active Constraints: Constraints that affect the solution")
print("  • Feasible Region: Set of points satisfying all constraints")
print()
print("Next Steps:")
print("  • For portfolio-specific optimization, see PortfolioOptimizationExample.swift")
print("  • For business optimization, see Phase 5 examples")
print("  • For unconstrained optimization, see OptimizationExample.swift")

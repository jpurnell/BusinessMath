import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport

print("=== Testing Part5 Optimization Examples ===\n")

// Example 1: Portfolio Optimization
print("1. Portfolio Optimization")
let returns = VectorN([0.08, 0.12, 0.15])
let covMatrix = [
    [0.04, 0.01, 0.02],
    [0.01, 0.09, 0.03],
    [0.02, 0.03, 0.16]
]

let optimizer = PortfolioOptimizer()

do {
    let minVar = try optimizer.minimumVariancePortfolio(
        expectedReturns: returns,
        covariance: covMatrix
    )
    print("   ✅ Minimum variance portfolio:")
    print("      Weights: \(minVar.weights.toArray().map { String(format: "%.1f%%", $0 * 100) })")
    print("      Return: \(String(format: "%.2f%%", minVar.expectedReturn * 100))")
    print("      Risk: \(String(format: "%.2f%%", minVar.volatility * 100))")
} catch {
    print("   ❌ Error: \(error)")
}

// Example 2: Integer Programming with proper bounds
print("\n2. Integer Programming (Project Selection)")
let projectNPVs = [50_000.0, 75_000.0, 60_000.0, 90_000.0]
let projectCosts = [20_000.0, 35_000.0, 25_000.0, 40_000.0]
let budget = 80_000.0

// Objective: maximize NPV (minimize negative NPV)
let objective: (VectorN<Double>) -> Double = { selected in
    let npv = zip(selected.toArray(), projectNPVs).map(*).reduce(0, +)
    return -npv
}

// Constraints: budget + binary bounds (0 ≤ x ≤ 1)
var constraints: [MultivariateConstraint<VectorN<Double>>] = [
    .inequality { v in
        let cost = zip(v.toArray(), projectCosts).map(*).reduce(0, +)
        return cost - budget
    }
]

// Add binary bounds for each variable
for i in 0..<projectNPVs.count {
    constraints.append(.inequality { v in -v.toArray()[i] })           // x ≥ 0
    constraints.append(.inequality { v in v.toArray()[i] - 1.0 })      // x ≤ 1
}

// Integer specification: all variables are binary
let integerSpec = IntegerProgramSpecification.allBinary(dimension: projectNPVs.count)

let solver = BranchAndBoundSolver<VectorN<Double>>()

do {
    let result = try solver.solve(
        objective: objective,
        from: VectorN([0.5, 0.5, 0.5, 0.5]),
        subjectTo: constraints,
        integerSpec: integerSpec,
        minimize: true
    )

    print("   ✅ Optimal project selection:")
    let selected = result.solution.toArray()
    for (i, isSelected) in selected.enumerated() {
        if isSelected > 0.5 {
            print("      Project \(i+1): Selected (NPV: $\(projectNPVs[i].currency()), Cost: $\(projectCosts[i].currency()))")
        }
    }
    let totalNPV = zip(selected, projectNPVs).map(*).reduce(0, +)
    let totalCost = zip(selected, projectCosts).map(*).reduce(0, +)
    print("      Total NPV: $\(totalNPV.currency())")
    print("      Total Cost: $\(totalCost.currency())")
    print("      Status: \(result.status)")
} catch {
    print("   ❌ Error: \(error)")
}

print("\n=== All examples completed ===")

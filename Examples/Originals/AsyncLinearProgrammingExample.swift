//
//  AsyncLinearProgrammingExample.swift
//  BusinessMath Examples
//
//  Comprehensive guide to async linear programming (Phase 3.4)
//  Learn simplex method, progress monitoring, and real-world LP applications
//
//  Created on December 30, 2025.
//

import Foundation
import BusinessMath

// MARK: - Example 1: Basic Linear Programming

func example1_BasicLP() async throws {
    print("=== Example 1: Basic Linear Programming ===\n")

    let solver = AsyncSimplexSolver()

    print("Maximize: 3x + 2y")
    print("Subject to: x + y ≤ 4")
    print("           2x + y ≤ 5")
    print("           x, y ≥ 0\n")

    let result = try await solver.maximize(
        objective: [3.0, 2.0],
        subjectTo: [
            SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual, rhs: 4.0),
            SimplexConstraint(coefficients: [2.0, 1.0], relation: .lessOrEqual, rhs: 5.0)
        ]
    )

    print("Status: \(result.status)")
    print("Optimal value: \(String(format: "%.2f", result.objectiveValue))")
    print("Solution: x = \(String(format: "%.2f", result.solution[0])), y = \(String(format: "%.2f", result.solution[1]))")
    print("Iterations: \(result.iterations)")

    print("\nAsync/await makes LP solving non-blocking!\n")
}

// MARK: - Example 2: Progress Monitoring

func example2_ProgressMonitoring() async throws {
    print("=== Example 2: Progress Monitoring ===\n")

    let solver = AsyncSimplexSolver()

    print("Monitoring simplex progress in real-time:")
    print("Phase     | Iteration | Objective")
    print("----------|-----------|----------")

    for try await progress in solver.maximizeWithProgress(
        objective: [3.0, 2.0],
        subjectTo: [
            SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual, rhs: 4.0),
            SimplexConstraint(coefficients: [2.0, 1.0], relation: .lessOrEqual, rhs: 5.0)
        ]
    ) {
        print("\(String(format: "%-9s", progress.currentPhase)) | \(String(format: "%9d", progress.iteration)) | \(String(format: "%.4f", progress.currentObjectiveValue))")

        if progress.phase == .finalization {
            break
        }
    }

    print("\nSimplex method reports progress at each pivot!\n")
}

// MARK: - Example 3: Minimization Problems

func example3_Minimization() async throws {
    print("=== Example 3: Minimization Problems ===\n")

    let solver = AsyncSimplexSolver()

    print("Minimize: 2x + 3y  (cost function)")
    print("Subject to: x + y ≥ 4")
    print("           2x + y ≥ 5")
    print("           x, y ≥ 0\n")

    let result = try await solver.minimize(
        objective: [2.0, 3.0],
        subjectTo: [
            SimplexConstraint(coefficients: [1.0, 1.0], relation: .greaterOrEqual, rhs: 4.0),
            SimplexConstraint(coefficients: [2.0, 1.0], relation: .greaterOrEqual, rhs: 5.0)
        ]
    )

    print("Minimum cost: $\(String(format: "%.2f", result.objectiveValue))")
    print("Solution: x = \(String(format: "%.2f", result.solution[0])), y = \(String(format: "%.2f", result.solution[1]))")

    print("\nMinimization problems model cost reduction!\n")
}

// MARK: - Example 4: Production Planning

func example4_ProductionPlanning() async throws {
    print("=== Example 4: Production Planning ===\n")

    // Furniture factory produces chairs and tables
    // Chairs: $40 profit each, 1 wood unit, 2 labor hours
    // Tables: $30 profit each, 2 wood units, 1 labor hour
    // Resources: 40 wood units, 50 labor hours available

    print("Furniture Factory Problem:")
    print("  Chairs: $40 profit, 1 wood, 2 labor")
    print("  Tables: $30 profit, 2 wood, 1 labor")
    print("  Available: 40 wood units, 50 labor hours\n")

    let solver = AsyncSimplexSolver()

    let result = try await solver.maximize(
        objective: [40.0, 30.0],  // Profit per chair, table
        subjectTo: [
            SimplexConstraint(coefficients: [1.0, 2.0], relation: .lessOrEqual, rhs: 40.0),  // Wood
            SimplexConstraint(coefficients: [2.0, 1.0], relation: .lessOrEqual, rhs: 50.0)   // Labor
        ]
    )

    let chairs = result.solution[0]
    let tables = result.solution[1]

    print("Optimal production plan:")
    print("  Chairs: \(String(format: "%.0f", chairs)) units")
    print("  Tables: \(String(format: "%.0f", tables)) units")
    print("  Maximum profit: $\(String(format: "%.2f", result.objectiveValue))")

    // Resource utilization
    let woodUsed = chairs * 1.0 + tables * 2.0
    let laborUsed = chairs * 2.0 + tables * 1.0

    print("\nResource utilization:")
    print("  Wood: \(String(format: "%.0f", woodUsed))/40 (\(String(format: "%.0f", woodUsed/40*100))%)")
    print("  Labor: \(String(format: "%.0f", laborUsed))/50 (\(String(format: "%.0f", laborUsed/50*100))%)")

    print("\nLinear programming optimizes resource allocation!\n")
}

// MARK: - Example 5: Diet Problem

func example5_DietProblem() async throws {
    print("=== Example 5: Diet Problem ===\n")

    // Minimize cost of bread and milk
    // Bread: $2, 4 calories, 1 protein
    // Milk: $3, 3 calories, 2 protein
    // Requirements: ≥10 calories, ≥5 protein

    print("Nutrition Planning Problem:")
    print("  Bread: $2, 4 cal, 1 protein")
    print("  Milk:  $3, 3 cal, 2 protein")
    print("  Need: ≥10 calories, ≥5 protein\n")

    let solver = AsyncSimplexSolver()

    let result = try await solver.minimize(
        objective: [2.0, 3.0],  // Cost per bread, milk
        subjectTo: [
            SimplexConstraint(coefficients: [4.0, 3.0], relation: .greaterOrEqual, rhs: 10.0),  // Calories
            SimplexConstraint(coefficients: [1.0, 2.0], relation: .greaterOrEqual, rhs: 5.0)    // Protein
        ]
    )

    let bread = result.solution[0]
    let milk = result.solution[1]

    print("Optimal diet:")
    print("  Bread: \(String(format: "%.2f", bread)) units")
    print("  Milk:  \(String(format: "%.2f", milk)) units")
    print("  Minimum cost: $\(String(format: "%.2f", result.objectiveValue))")

    // Nutritional content
    let calories = bread * 4.0 + milk * 3.0
    let protein = bread * 1.0 + milk * 2.0

    print("\nNutrition achieved:")
    print("  Calories: \(String(format: "%.1f", calories)) (required ≥10)")
    print("  Protein:  \(String(format: "%.1f", protein)) (required ≥5)")

    print("\nLP solves cost-minimization with constraints!\n")
}

// MARK: - Example 6: Transportation Problem

func example6_TransportationProblem() async throws {
    print("=== Example 6: Transportation Problem ===\n")

    // Simplified: 2 warehouses shipping to 2 stores
    // Minimize shipping cost
    // Warehouse 1 → Store A: $3/unit, Store B: $5/unit
    // Warehouse 2 → Store A: $4/unit, Store B: $2/unit
    // Warehouse 1 has 100 units, Warehouse 2 has 150 units
    // Store A needs 80 units, Store B needs 120 units

    print("Shipping Problem (2 warehouses, 2 stores):")
    print("  W1→A: $3/unit, W1→B: $5/unit")
    print("  W2→A: $4/unit, W2→B: $2/unit")
    print("  Supply: W1=100, W2=150")
    print("  Demand: A=80, B=120\n")

    let solver = AsyncSimplexSolver()

    // Variables: [W1→A, W1→B, W2→A, W2→B]
    let result = try await solver.minimize(
        objective: [3.0, 5.0, 4.0, 2.0],  // Shipping costs
        subjectTo: [
            // Supply constraints
            SimplexConstraint(coefficients: [1.0, 1.0, 0.0, 0.0], relation: .lessOrEqual, rhs: 100.0),  // W1 supply
            SimplexConstraint(coefficients: [0.0, 0.0, 1.0, 1.0], relation: .lessOrEqual, rhs: 150.0),  // W2 supply
            // Demand constraints
            SimplexConstraint(coefficients: [1.0, 0.0, 1.0, 0.0], relation: .equal, rhs: 80.0),   // Store A demand
            SimplexConstraint(coefficients: [0.0, 1.0, 0.0, 1.0], relation: .equal, rhs: 120.0)  // Store B demand
        ]
    )

    print("Optimal shipping plan:")
    print("  W1→A: \(String(format: "%.0f", result.solution[0])) units")
    print("  W1→B: \(String(format: "%.0f", result.solution[1])) units")
    print("  W2→A: \(String(format: "%.0f", result.solution[2])) units")
    print("  W2→B: \(String(format: "%.0f", result.solution[3])) units")
    print("  Minimum cost: $\(String(format: "%.2f", result.objectiveValue))")

    print("\nLP optimizes logistics and supply chains!\n")
}

// MARK: - Example 7: Infeasible and Unbounded Cases

func example7_SpecialCases() async throws {
    print("=== Example 7: Infeasible and Unbounded Cases ===\n")

    let solver = AsyncSimplexSolver()

    // Infeasible problem
    print("Infeasible problem (contradictory constraints):")
    print("  Maximize: x + y")
    print("  Subject to: x + y ≤ 2")
    print("             x + y ≥ 3  (impossible!)\n")

    let infeasible = try await solver.maximize(
        objective: [1.0, 1.0],
        subjectTo: [
            SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual, rhs: 2.0),
            SimplexConstraint(coefficients: [1.0, 1.0], relation: .greaterOrEqual, rhs: 3.0)
        ]
    )

    print("Status: \(infeasible.status)")
    print("No feasible solution exists!\n")

    // Unbounded problem
    print("Unbounded problem (objective can grow infinitely):")
    print("  Maximize: x + y")
    print("  Subject to: -x + y ≤ 1  (allows infinite growth)\n")

    let unbounded = try await solver.maximize(
        objective: [1.0, 1.0],
        subjectTo: [
            SimplexConstraint(coefficients: [-1.0, 1.0], relation: .lessOrEqual, rhs: 1.0)
        ]
    )

    print("Status: \(unbounded.status)")
    print("Objective can grow without bound!\n")

    print("Simplex method detects these special cases!\n")
}

// MARK: - Example 8: Best Practices

func example8_BestPractices() async throws {
    print("=== Example 8: Linear Programming Best Practices ===\n")

    print("📚 Best Practices for LP:\n")

    print("1. Problem Formulation")
    print("   • Define decision variables clearly")
    print("   • Express objective as linear function")
    print("   • All constraints must be linear")
    print("   • Non-negativity is implicit (x ≥ 0)\n")

    print("2. Constraint Types")
    print("   • ≤ constraints: Resource limits (lessOrEqual)")
    print("   • ≥ constraints: Minimum requirements (greaterOrEqual)")
    print("   • = constraints: Exact specifications (equal)")
    print("   • Mix freely as needed\n")

    print("3. Choosing Objective")
    print("   • Maximize: Profit, revenue, production")
    print("   • Minimize: Cost, waste, time")
    print("   • Ensure correct signs (positive for maximization)\n")

    print("4. When to Use LP")
    print("   ✓ Resource allocation problems")
    print("   ✓ Production planning")
    print("   ✓ Transportation and logistics")
    print("   ✓ Diet and nutrition planning")
    print("   ✓ Blending problems")
    print("   ✗ Non-linear objectives or constraints")
    print("   ✗ Integer-only solutions (use MIP instead)\n")

    print("5. Async/Await Benefits")
    print("   • Non-blocking UI in applications")
    print("   • Progress monitoring for large problems")
    print("   • Easy task cancellation")
    print("   • Composable with other async operations\n")

    // Demonstrate well-structured LP
    print("Example: Well-structured LP problem\n")

    let solver = AsyncSimplexSolver()

    var progressCount = 0
    for try await progress in solver.maximizeWithProgress(
        objective: [5.0, 4.0],
        subjectTo: [
            SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual, rhs: 100.0),
            SimplexConstraint(coefficients: [2.0, 1.0], relation: .lessOrEqual, rhs: 150.0),
            SimplexConstraint(coefficients: [1.0, 2.0], relation: .lessOrEqual, rhs: 120.0)
        ]
    ) {
        progressCount += 1
        if progress.phase == .finalization {
            print("Solved in \(progress.iteration) iterations")
            print("Optimal value: \(String(format: "%.2f", progress.currentObjectiveValue))")
            print("Status: \(progress.status!)")
        }
    }

    print("\nFollow these practices for successful LP modeling!\n")
}

// MARK: - Main Runner

@main
struct AsyncLinearProgrammingExampleRunner {
    static func main() async throws {
        print("\n" + String(repeating: "=", count: 60))
        print("    BusinessMath: Async Linear Programming Examples")
        print("    Phase 3.4: AsyncSimplexSolver Tutorial")
        print(String(repeating: "=", count: 60) + "\n")

        try await example1_BasicLP()
        try await example2_ProgressMonitoring()
        try await example3_Minimization()
        try await example4_ProductionPlanning()
        try await example5_DietProblem()
        try await example6_TransportationProblem()
        try await example7_SpecialCases()
        try await example8_BestPractices()

        print(String(repeating: "=", count: 60))
        print("✅ All examples completed successfully!")
        print(String(repeating: "=", count: 60) + "\n")

        print("Next Steps:")
        print("  • Explore Mixed Integer Programming (MIP)")
        print("  • Study sensitivity analysis")
        print("  • Learn about duality theory")
        print("\nHappy optimizing! 🚀\n")
    }
}

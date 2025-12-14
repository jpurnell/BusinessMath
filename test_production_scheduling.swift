#!/usr/bin/env swift

import Foundation

// Add the path to BusinessMath module
#if canImport(BusinessMath)
import BusinessMath
#else
fatalError("BusinessMath module not found. Run from package directory: swift test_production_scheduling.swift")
#endif

// Production Scheduling with Setup Costs Example
// From PHASE_6.2_INTEGER_PROGRAMMING_TUTORIAL.md

let productionCosts = [25.0, 30.0, 20.0, 28.0]   // Per unit
let setupCosts = [500.0, 600.0, 450.0, 550.0]    // Fixed
let demands = [100.0, 150.0, 80.0, 120.0]        // Must meet
let capacities = [200.0, 250.0, 150.0, 200.0]    // Max production

// Decision variables:
// x[0..3]: Integer - production quantity
// y[4..7]: Binary - whether to produce (incur setup)
// Dimension: 8 (4 products × 2 variables each)

let dimension = 8
let spec = IntegerProgramSpecification(
    integerVariables: Set([0, 1, 2, 3]),  // Production quantities
    binaryVariables: Set([4, 5, 6, 7])     // Setup decisions
)

// Objective: minimize total cost (variable + fixed)
let objective: @Sendable (VectorN<Double>) -> Double = { x in
    let vars = x.toArray()

    // Variable costs: Σ costᵢ·xᵢ
    var variableCost = 0.0
    for i in 0..<4 {
        variableCost += productionCosts[i] * vars[i]
    }

    // Fixed costs: Σ setupᵢ·yᵢ
    var fixedCost = 0.0
    for i in 0..<4 {
        fixedCost += setupCosts[i] * vars[4 + i]
    }

    return variableCost + fixedCost
}

var constraints: [MultivariateConstraint<VectorN<Double>>] = []

// Demand constraints: must produce at least demand
// This is the constraint the user is having trouble with
for i in 0..<4 {
    constraints.append(.inequality { x in
        demands[i] - x.toArray()[i]
    })
}

// Linking constraints: can only produce if setup
// xᵢ ≤ capacityᵢ·yᵢ  ⟺  xᵢ - capacityᵢ·yᵢ ≤ 0
for i in 0..<4 {
    constraints.append(.inequality { x in
        let vars = x.toArray()
        return vars[i] - capacities[i] * vars[4 + i]
    })
}

// Capacity constraints
for i in 0..<4 {
    constraints.append(.inequality { x in
        x.toArray()[i] - capacities[i]
    })
}

// Non-negativity and binary
for i in 0..<dimension {
    constraints.append(.inequality { x in -x.toArray()[i] })
    if i >= 4 {
        constraints.append(.inequality { x in x.toArray()[i] - 1.0 })
    }
}

print("Testing Production Scheduling with Setup Costs")
print(String(repeating: "=", count: 60))
print("Demands: \(demands)")
print("Production costs: \(productionCosts)")
print("Setup costs: \(setupCosts)")
print("Capacities: \(capacities)")
print("")

let solver = BranchAndBoundSolver<VectorN<Double>>(
    maxNodes: 3000,
    timeLimit: 30.0,
    nodeSelection: .bestBound
)

do {
    let result = try solver.solve(
        objective: objective,
        from: VectorN(Array(repeating: 0.0, count: dimension)),
        subjectTo: constraints,
        integerSpec: spec,
        minimize: true
    )

    // Analyze solution
    let vars = result.solution.toArray()
    print("Solution Status: \(result.status)")
    print("Nodes explored: \(result.nodesExplored)")
    print("")
    print("Production Plan:")
    print(String(repeating: "=", count: 60))

    var totalCost = 0.0
    for i in 0..<4 {
        let quantity = Int(round(vars[i]))
        let setup = vars[4 + i] > 0.5
        let demand = Int(demands[i])

        print("Product \(i):")
        print("  Demand:     \(demand) units")
        print("  Production: \(quantity) units")
        print("  Setup:      \(setup ? "YES" : "NO")")

        // CHECK CONSTRAINT VIOLATION
        if Double(quantity) < demands[i] - 0.01 {
            print("  ⚠️  CONSTRAINT VIOLATION: Production (\(quantity)) < Demand (\(demand))")
        }

        if quantity > 0 {
            let varCost = productionCosts[i] * Double(quantity)
            let fixCost = setup ? setupCosts[i] : 0.0
            print("  Variable cost: $\(String(format: "%.0f", varCost))")
            print("  Setup cost:    $\(String(format: "%.0f", fixCost))")
            print("  Subtotal:      $\(String(format: "%.0f", varCost + fixCost))")
            totalCost += varCost + fixCost
        }
        print("")
    }

    print(String(repeating: "=", count: 60))
    print("Total cost: $\(String(format: "%.0f", totalCost))")
    print("Objective value: $\(String(format: "%.0f", result.objectiveValue))")

    // Verify all constraints
    print("")
    print("Constraint Verification:")
    print(String(repeating: "=", count: 60))
    for (idx, constraint) in constraints.enumerated() {
        let value = constraint.evaluate(at: result.solution)
        if value > 1e-6 {
            print("Constraint \(idx) VIOLATED: g(x) = \(value) > 0")
        }
    }

} catch {
    print("Error solving: \(error)")
}

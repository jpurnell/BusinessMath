import BusinessMath

// Minimize (x-1)² + (y-1)² subject to x≥0, y≥0, x+y≤2
let objective: (VectorN<Double>) -> Double = { v in
    let x = v[0] - 1
    let y = v[1] - 1
    return x*x + y*y
}

let constraints: [MultivariateConstraint<VectorN<Double>>] = [
    .inequality { v in -v[0] },        // x ≥ 0 → -x ≤ 0
    .inequality { v in -v[1] },        // y ≥ 0 → -y ≤ 0
    .inequality { v in v[0] + v[1] - 2 }  // x+y ≤ 2
]

print("Testing InequalityOptimizer with fixed barrier function...")
print("Problem: minimize (x-1)² + (y-1)² subject to x≥0, y≥0, x+y≤2")
print("Expected solution: [1.0, 1.0]")
print("Expected objective: 0.0")
print("")

let optimizer = InequalityOptimizer<VectorN<Double>>()
let result = try optimizer.minimize(
    objective,
    from: VectorN([0.5, 0.5]),
    subjectTo: constraints
)

print("Solution: \(result.solution)")
print("Objective: \(result.objectiveValue)")
print("Converged: \(result.converged)")
print("Iterations: \(result.iterations)")
print("Constraint violation: \(result.constraintViolation)")

// Check constraints
let x = result.solution[0]
let y = result.solution[1]
print("\nConstraint satisfaction:")
print("  x = \(x)")
print("  y = \(y)")
print("  x >= 0? \(x >= 0)")
print("  y >= 0? \(y >= 0)")
print("  x + y = \(x + y)")
print("  x + y <= 2? \(x + y <= 2)")

// Compare to expected solution
print("\nComparison to expected:")
print("  Distance from [1.0, 1.0]: \(((x-1)*(x-1) + (y-1)*(y-1)).squareRoot())")
print("  Objective value (should be ~0.0): \(result.objectiveValue)")

// Success criteria
let tolerance = 0.001
let success = abs(x - 1.0) < tolerance && abs(y - 1.0) < tolerance && result.objectiveValue < tolerance
print("\n" + (success ? "✅ TEST PASSED" : "❌ TEST FAILED"))

// Test the exact example from inequality.md tutorial
import BusinessMath

print("Testing InequalityOptimizer with tutorial example...")
print("Problem: minimize (x-1)² + (y-1)² subject to x≥0, y≥0, x+y≤2")
print("")

// Objective function: minimize (x-1)² + (y-1)²
let objective: (VectorN<Double>) -> Double = { v in
    let x = v[0] - 1
    let y = v[1] - 1
    return x*x + y*y
}

// Constraints: x ≥ 0, y ≥ 0, x+y ≤ 2
let constraints: [MultivariateConstraint<VectorN<Double>>] = [
    .inequality { v in -v[0] },        // x ≥ 0 → -x ≤ 0
    .inequality { v in -v[1] },        // y ≥ 0 → -y ≤ 0
    .inequality { v in v[0] + v[1] - 2 }  // x+y ≤ 2
]

let optimizer = InequalityOptimizer<VectorN<Double>>()
let result = try optimizer.minimize(
    objective,
    from: VectorN([0.5, 0.5]),
    subjectTo: constraints
)

print("Results:")
print("  Solution: [\(result.solution[0]), \(result.solution[1])]")
print("  Objective value: \(result.objectiveValue)")
print("  Converged: \(result.converged)")
print("  Iterations: \(result.iterations)")
print("  Constraint violation: \(result.constraintViolation)")
print("")

let x = result.solution[0]
let y = result.solution[1]
print("Constraint check:")
print("  x = \(x) (should be ≥ 0)")
print("  y = \(y) (should be ≥ 0)")
print("  x + y = \(x + y) (should be ≤ 2)")
print("")

print("Expected solution: [1.0, 1.0]")
print("Expected objective: 0.0")
print("")

// Check if solution is correct (within tolerance)
let tolerance = 0.01
let xCorrect = abs(x - 1.0) < tolerance
let yCorrect = abs(y - 1.0) < tolerance
let objCorrect = result.objectiveValue < tolerance

if xCorrect && yCorrect && objCorrect {
    print("✅ TEST PASSED - Solution matches expected [1.0, 1.0]")
} else {
    print("❌ TEST FAILED")
    print("   x error: \(abs(x - 1.0))")
    print("   y error: \(abs(y - 1.0))")
    print("   objective error: \(result.objectiveValue)")
}

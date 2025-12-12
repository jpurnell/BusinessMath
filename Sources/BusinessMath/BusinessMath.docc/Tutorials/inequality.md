```swift
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

let optimizer = InequalityOptimizer<VectorN<Double>>()
let result = try optimizer.minimize(
    objective,
    from: VectorN([0.5, 0.5]),
    subjectTo: constraints
)

print("Solution: \(result.solution)")  // [1, 1]
```

import Foundation
@testable import BusinessMath

print("=== Testing Parameter Estimation Issue ===\n")

// Original (problematic) example
let observedData = [2.1, 4.3, 6.2, 8.5, 10.1]
let timePoints = [1.0, 2.0, 3.0, 4.0, 5.0]

func model(params: VectorN<Double>, t: Double) -> Double {
    let a = params[0], b = params[1], c = params[2]
    return a * exp(b * t) + c
}

print("1. ORIGINAL EXAMPLE (Linear data, exponential model):")
print("   Data points: \(observedData)")
print("   This data is nearly linear: y ≈ 2*t")
print("")

let optimizer1 = AdaptiveOptimizer<VectorN<Double>>(preferAccuracy: true)

let result1 = try optimizer1.optimize(
    objective: { params in
        var sse = 0.0
        for (t, observed) in zip(timePoints, observedData) {
            let predicted = model(params: params, t: t)
            sse += (observed - predicted) * (observed - predicted)
        }
        return sse
    },
    initialGuess: VectorN([1.0, 0.5, 0.0])
)

print("   Algorithm: \(result1.algorithmUsed)")
print("   Parameters: a=\(result1.solution[0]), b=\(result1.solution[1]), c=\(result1.solution[2])")
print("   Rounded: a=\(Int(round(result1.solution[0]))), b=\(Int(round(result1.solution[1]))), c=\(Int(round(result1.solution[2])))")
print("   SSE: \(result1.objectiveValue)")

// Verify the degenerate solution
let a1 = result1.solution[0]
let b1 = result1.solution[1]
let c1 = result1.solution[2]
print("   Model at t=1: \(a1 * exp(b1 * 1.0) + c1) (should be ~2.1)")
print("   This is WRONG - the model predicts ~0 for all points!\n")

print("2. CORRECTED EXAMPLE #1 (Better initial guess):")
let result2 = try optimizer1.optimize(
    objective: { params in
        var sse = 0.0
        for (t, observed) in zip(timePoints, observedData) {
            let predicted = model(params: params, t: t)
            sse += (observed - predicted) * (observed - predicted)
        }
        return sse
    },
    initialGuess: VectorN([2.0, 0.01, 0.0])  // Better guess: a=2, small b, c=0
)

print("   Algorithm: \(result2.algorithmUsed)")
print("   Parameters: a=\(result2.solution[0]), b=\(result2.solution[1]), c=\(result2.solution[2])")
print("   SSE: \(result2.objectiveValue)")
let a2 = result2.solution[0]
let b2 = result2.solution[1]
let c2 = result2.solution[2]
print("   Model at t=1: \(a2 * exp(b2 * 1.0) + c2) (should be ~2.1)")
print("   Model at t=5: \(a2 * exp(b2 * 5.0) + c2) (should be ~10.1)")
print("")

print("3. CORRECTED EXAMPLE #2 (Exponential data):")
// Generate truly exponential data: y = 2 * exp(0.3*t) + 1
let expTimePoints = [1.0, 2.0, 3.0, 4.0, 5.0]
let expData = expTimePoints.map { 2.0 * exp(0.3 * $0) + 1.0 }
print("   Generated exponential data: \(expData.map { round($0 * 100) / 100 })")
print("   True parameters: a=2.0, b=0.3, c=1.0")
print("")

let result3 = try optimizer1.optimize(
    objective: { params in
        var sse = 0.0
        for (t, observed) in zip(expTimePoints, expData) {
            let predicted = model(params: params, t: t)
            sse += (observed - predicted) * (observed - predicted)
        }
        return sse
    },
    initialGuess: VectorN([1.0, 0.5, 0.0])  // Same initial guess
)

print("   Recovered parameters: a=\(result3.solution[0]), b=\(result3.solution[1]), c=\(result3.solution[2])")
print("   SSE: \(result3.objectiveValue)")
print("   Error: a=\(abs(result3.solution[0] - 2.0)), b=\(abs(result3.solution[1] - 0.3)), c=\(abs(result3.solution[2] - 1.0))")
print("")

print("4. BEST PRACTICE - Use linear model for linear data:")
// Linear model: y = m*t + b
func linearModel(params: VectorN<Double>, t: Double) -> Double {
    let m = params[0], b = params[1]
    return m * t + b
}

let result4 = try optimizer1.optimize(
    objective: { params in
        var sse = 0.0
        for (t, observed) in zip(timePoints, observedData) {
            let predicted = linearModel(params: params, t: t)
            sse += (observed - predicted) * (observed - predicted)
        }
        return sse
    },
    initialGuess: VectorN([1.0, 0.0])
)

print("   Linear model: y = m*t + b")
print("   Parameters: m=\(result4.solution[0]), b=\(result4.solution[1])")
print("   SSE: \(result4.objectiveValue) (much better!)")
let m = result4.solution[0]
let b = result4.solution[1]
print("   Model at t=1: \(m * 1.0 + b) (should be ~2.1)")
print("   Model at t=5: \(m * 5.0 + b) (should be ~10.1)")
print("")

print("=== SUMMARY ===")
print("The parameters [459, 0, -459] represent a degenerate solution where")
print("the exponential term cancels out: 459*exp(0) + (-459) = 0")
print("")
print("Solutions:")
print("1. Use a model that matches your data (linear for linear data)")
print("2. Use a better initial guess if exponential model is needed")
print("3. Use constraints to prevent degenerate solutions")
print("4. Use truly exponential data to test exponential models")

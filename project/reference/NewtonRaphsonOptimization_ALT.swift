```swift
import Foundation

struct Result<T> {
    var optimalValue: T
    var objectiveValue: Double
    var converged: Bool
    var iterations: Int
}

func numericalDerivative<T: FloatingPoint>(of f: @escaping (T) -> Double, at x: T, stepSize: T) -> Double {
    return (f(x + stepSize) - f(x - stepSize)) / (2 * Double(stepSize))
}

class NewtonRaphsonOptimizer<T: FloatingPoint> {
    var tolerance: T
    var maxIterations: Int
    var stepSize: T

    init(tolerance: T = 0.0001, maxIterations: Int = 100, stepSize: T = 0.0001) {
        self.tolerance = tolerance
        self.maxIterations = maxIterations
        self.stepSize = stepSize
    }

    func optimize(
        objective: @escaping (T) -> Double,
        constraints: [Constraint<T>],
        initialValue: T,
        bounds: (lower: T, upper: T)?
    ) -> Result<T> {
        
        var currentValue = initialValue
        var iterations = 0
        
        while iterations < maxIterations {
            let currentObjectiveValue = objective(currentValue)
            let derivative = numericalDerivative(of: objective, at: currentValue, stepSize: stepSize)

            // Check for zero derivative to avoid division by zero
            guard derivative != 0 else {
                return Result(optimalValue: currentValue, objectiveValue: currentObjectiveValue, converged: false, iterations: iterations)
            }

            // Newton-Raphson update
            let nextValue = currentValue - T(currentObjectiveValue / derivative)

            // Apply bounds if present
            if let bounds = bounds {
                currentValue = min(max(nextValue, bounds.lower), bounds.upper)
            } else {
                currentValue = nextValue
            }

            // Check constraints
            for constraint in constraints {
                switch constraint.type {
                case .greaterThanOrEqual:
                    if currentValue < constraint.bound {
                        currentValue = constraint.bound
                    }
                // Add more cases for additional constraint types as needed
                }
            }
            
            // Check convergence
            if abs(currentValue - nextValue) < tolerance && abs(objective(currentValue)) < Double(tolerance) {
                return Result(optimalValue: currentValue, objectiveValue: currentObjectiveValue, converged: true, iterations: iterations)
            }

            iterations += 1
        }

        return Result(optimalValue: currentValue, objectiveValue: objective(currentValue), converged: false, iterations: iterations)
    }
}

enum ConstraintType {
    case greaterThanOrEqual
}

struct Constraint<T> {
    var type: ConstraintType
    var bound: T
}
```

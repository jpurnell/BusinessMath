//
//  GoalSeekExample.swift
//  BusinessMath Examples
//
//  Demonstrates goal-seeking (root-finding) using Phase 1 enhancements
//

import Foundation
@testable import BusinessMath

/// Example: Basic goal-seeking (find where x² = 4)
func basicGoalSeekExample() throws {
    print("=== Basic Goal-Seeking ===\n")

    print("Problem: Find x where x² = 4")
    print()

    // Simple quadratic function
    let result = try goalSeek(
        function: { x in x * x },
        target: 4.0,
        guess: 1.0,
        tolerance: 0.000001
    )

    print("Solution: x = \(String(format: "%.6f", result))")
    print("Verification: x² = \(String(format: "%.6f", result * result))")
    print()

    print("Note: Two solutions exist (±2), but Newton-Raphson finds one based on initial guess")

    // Try negative guess
    let negativeResult = try goalSeek(
        function: { x in x * x },
        target: 4.0,
        guess: -1.0,
        tolerance: 0.000001
    )

    print("Starting from negative guess: x = \(String(format: "%.6f", negativeResult))")

    print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Breakeven analysis
func breakevenAnalysisExample() throws {
    print("=== Breakeven Analysis ===\n")

    print("Scenario: Product pricing with demand curve")
    print("  Fixed costs: $20,000")
    print("  Variable cost per unit: $5")
    print("  Demand curve: Q = 10,000 - 1,000P")
    print()

    // Profit function
    func profit(price: Double) -> Double {
        let quantity = 10000 - 1000 * price
        let revenue = price * quantity
        let fixedCosts = 20000.0
        let variableCost = 5.0
        let totalCosts = fixedCosts + variableCost * quantity
        return revenue - totalCosts
    }

    // Find breakeven price (where profit = 0)
    print("Finding breakeven price...")
    let breakevenPrice = try goalSeek(
        function: profit,
        target: 0.0,
        guess: 10.0,
        tolerance: 0.01
    )

    print(String(format: "Breakeven price: $%.2f", breakevenPrice))

    // Calculate breakeven quantity
    let breakevenQuantity = 10000 - 1000 * breakevenPrice
    print(String(format: "Breakeven quantity: %.0f units", breakevenQuantity))

    // Verify
    let verifyProfit = profit(price: breakevenPrice)
    print(String(format: "Verification: Profit at breakeven = $%.2f (should be ~$0)", verifyProfit))

    print()

    // Find optimal price (where profit is maximum)
    print("For comparison, optimal price can be found by setting profit derivative to 0")
    print("(This would use optimization, not goal-seeking)")

    print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Internal Rate of Return (IRR)
func irrCalculationExample() throws {
    print("=== Internal Rate of Return (IRR) ===\n")

    let cashFlows = [-1000.0, 200.0, 300.0, 400.0, 500.0]

    print("Cash Flows:")
    for (t, cf) in cashFlows.enumerated() {
        let sign = cf >= 0 ? "+" : ""
        print(String(format: "  Year %d: %@$%.0f", t, sign, cf))
    }
    print()

    // NPV function
    func npv(rate: Double) -> Double {
        var npv = 0.0
        for (t, cf) in cashFlows.enumerated() {
            npv += cf / pow(1 + rate, Double(t))
        }
        return npv
    }

    // Find IRR (rate where NPV = 0)
    print("Finding IRR (rate where NPV = 0)...")
    let irr = try goalSeek(
        function: npv,
        target: 0.0,
        guess: 0.10,  // Start with 10% guess
        tolerance: 0.000001
    )

    print(String(format: "IRR: %.2f%%", irr * 100))

    // Verify
    let verifyNPV = npv(rate: irr)
    print(String(format: "Verification: NPV at IRR = $%.6f (should be ~$0)", verifyNPV))

    print()

    // Show NPV at different rates
    print("NPV at various discount rates:")
    for rate in stride(from: 0.0, through: 0.30, by: 0.05) {
        let npvValue = npv(rate: rate)
        let marker = abs(rate - irr) < 0.01 ? " ← IRR" : ""
        print(String(format: "  %5.0f%%: $%8.2f%@", rate * 100, npvValue, marker))
    }

    print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Target seeking
func targetSeekingExample() throws {
    print("=== Target Seeking ===\n")

    print("Scenario: SaaS business targeting specific MRR")
    print("  Target MRR: $150,000")
    print("  Price per seat: $50")
    print("  Question: How many customers needed?")
    print()

    let pricePerSeat = 50.0
    let targetMRR = 150_000.0

    // MRR = price × customers
    let requiredCustomers = try goalSeek(
        function: { customers in pricePerSeat * customers },
        target: targetMRR,
        guess: 1000.0
    )

    print(String(format: "Required customers: %.0f", requiredCustomers))
    print(String(format: "Verification: $50 × %.0f = $%.0f",
                  requiredCustomers, pricePerSeat * requiredCustomers))

    print()

    // More complex: with churn
    print("More complex scenario with churn:")
    print("  Monthly churn rate: 5%")
    print("  New signups per month: 100")
    print("  Question: What's the steady-state customer count?")
    print()

    let monthlyChurn = 0.05
    let newSignups = 100.0

    // At steady state: new signups = churned customers
    // newSignups = churnRate × customerCount
    let steadyStateCustomers = try goalSeek(
        function: { customers in monthlyChurn * customers },
        target: newSignups,
        guess: 1000.0
    )

    print(String(format: "Steady-state customers: %.0f", steadyStateCustomers))
    print(String(format: "Verification: 5%% × %.0f = %.0f new signups needed",
                  steadyStateCustomers, monthlyChurn * steadyStateCustomers))

    let steadyStateMRR = pricePerSeat * steadyStateCustomers
    print(String(format: "Steady-state MRR: $%.0f", steadyStateMRR))

    print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Equation solving
func equationSolvingExample() throws {
    print("=== Equation Solving ===\n")

    print("Problem 1: Solve e^x - 2x - 3 = 0")
    print()

    let solution1 = try goalSeek(
        function: { x in exp(x) - 2*x - 3 },
        target: 0.0,
        guess: 1.0,
        tolerance: 0.000001
    )

    print(String(format: "Solution: x = %.6f", solution1))

    // Verify
    let verify1 = exp(solution1) - 2*solution1 - 3
    print(String(format: "Verification: e^%.6f - 2(%.6f) - 3 = %.10f",
                  solution1, solution1, verify1))

    print()

    // Problem 2: Solve cos(x) = x
    print("Problem 2: Solve cos(x) = x")
    print()

    let solution2 = try goalSeek(
        function: { x in cos(x) - x },
        target: 0.0,
        guess: 0.5,
        tolerance: 0.000001
    )

    print(String(format: "Solution: x = %.6f", solution2))
    print(String(format: "Verification: cos(%.6f) = %.6f ≈ %.6f",
                  solution2, cos(solution2), solution2))

    print()

    // Problem 3: Solve x³ - 2x - 5 = 0
    print("Problem 3: Solve x³ - 2x - 5 = 0")
    print()

    let solution3 = try goalSeek(
        function: { x in x*x*x - 2*x - 5 },
        target: 0.0,
        guess: 2.0,
        tolerance: 0.000001
    )

    print(String(format: "Solution: x = %.6f", solution3))

    let verify3 = solution3*solution3*solution3 - 2*solution3 - 5
    print(String(format: "Verification: (%.6f)³ - 2(%.6f) - 5 = %.10f",
                  solution3, solution3, verify3))

    print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Using GoalSeekOptimizer with constraints
func constrainedGoalSeekExample() throws {
    print("=== Constrained Goal-Seeking ===\n")

    print("Problem: Find breakeven price with minimum price constraint")
    print("  Must be at least $5 (minimum viable price)")
    print()

    // Profit function
    func profit(price: Double) -> Double {
        let quantity = 10000 - 1000 * price
        let revenue = price * quantity
        let fixedCosts = 20000.0
        let variableCost = 5.0
        let totalCosts = fixedCosts + variableCost * quantity
        return revenue - totalCosts
    }

    // Create optimizer
    let optimizer = GoalSeekOptimizer<Double>(
        target: 0.0,          // Find where profit = 0
        tolerance: 0.01,
        maxIterations: 1000
    )

    // Minimum price constraint
    let minPriceConstraint = Constraint<Double>(
        type: .greaterThanOrEqual,
        bound: 5.0
    )

    let result = optimizer.optimize(
        objective: profit,
        constraints: [minPriceConstraint],
        initialValue: 10.0,
        bounds: (lower: 0.0, upper: 100.0)
    )

    if result.converged {
        print(String(format: "Breakeven price: $%.2f", result.optimalValue))
        print(String(format: "Profit at breakeven: $%.2f", result.objectiveValue))
        print(String(format: "Iterations: %d", result.iterations))
        print()

        // Check constraint
        if result.optimalValue >= 5.0 {
            print("✓ Constraint satisfied (price ≥ $5)")
        } else {
            print("✗ Constraint violated")
        }
    } else {
        print("Failed to converge")
    }

    print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Error handling
func errorHandlingExample() {
    print("=== Error Handling ===\n")

    // Example 1: Division by zero
    print("Example 1: Function with zero derivative")
    do {
        // x³ has zero derivative at x=0
        let result = try goalSeek(
            function: { x in x * x * x },
            target: 0.0,
            guess: 0.0  // Bad guess - derivative is zero here
        )
        print("Solution: \(result)")
    } catch GoalSeekError.divisionByZero {
        print("✗ Error: Derivative was zero")
        print("  Solution: Choose a different initial guess")
    } catch {
        print("Unexpected error: \(error)")
    }

    print()

    // Example 2: Convergence failure
    print("Example 2: No solution exists")
    do {
        // sin(x) never equals 2
        let result = try goalSeek(
            function: { x in sin(x) },
            target: 2.0,  // Impossible - sin(x) ∈ [-1, 1]
            guess: 0.0
        )
        print("Solution: \(result)")
    } catch GoalSeekError.convergenceFailed {
        print("✗ Error: Failed to converge")
        print("  Reason: No solution exists (sin(x) cannot equal 2)")
    } catch {
        print("Unexpected error: \(error)")
    }

    print()

    // Example 3: Proper error handling
    print("Example 3: Robust error handling")

    func findBreakeven(fixedCosts: Double, variableCost: Double) -> Double? {
        func profit(price: Double) -> Double {
            let quantity = 10000 - 1000 * price
            let revenue = price * quantity
            let totalCosts = fixedCosts + variableCost * quantity
            return revenue - totalCosts
        }

        do {
            return try goalSeek(
                function: profit,
                target: 0.0,
                guess: 10.0,
                tolerance: 0.01
            )
        } catch GoalSeekError.divisionByZero {
            print("  Warning: Zero derivative encountered")
            return nil
        } catch GoalSeekError.convergenceFailed {
            print("  Warning: No breakeven point found")
            return nil
        } catch {
            print("  Error: \(error)")
            return nil
        }
    }

    if let price = findBreakeven(fixedCosts: 20000, variableCost: 5.0) {
        print(String(format("  ✓ Breakeven price: $%.2f", price))
    } else {
        print("  ✗ Could not find breakeven price")
    }

    print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Multiple roots
func multipleRootsExample() throws {
    print("=== Multiple Roots ===\n")

    print("Problem: Find roots of (x - 1)(x - 3) = x² - 4x + 3")
    print("Two roots exist: x = 1 and x = 3")
    print()

    func polynomial(x: Double) -> Double {
        return x*x - 4*x + 3
    }

    // Find first root (starting near x=1)
    let root1 = try goalSeek(
        function: polynomial,
        target: 0.0,
        guess: 0.0,
        tolerance: 0.000001
    )

    print(String(format: "Root 1 (guess=0): x = %.6f", root1))
    print(String(format: "  Verification: f(%.6f) = %.10f", root1, polynomial(x: root1)))

    print()

    // Find second root (starting near x=3)
    let root2 = try goalSeek(
        function: polynomial,
        target: 0.0,
        guess: 5.0,
        tolerance: 0.000001
    )

    print(String(format: "Root 2 (guess=5): x = %.6f", root2))
    print(String(format: "  Verification: f(%.6f) = %.10f", root2, polynomial(x: root2)))

    print()
    print("Key insight: Initial guess determines which root is found")
    print("  • Guess near 1 → finds x=1")
    print("  • Guess near 3 → finds x=3")

    print("\n" + String(repeating: "=", count: 50) + "\n")
}

// Run examples
print("\n")
print("BusinessMath - Goal-Seeking Examples")
print(String(repeating: "=", count: 50))
print("\n")

try basicGoalSeekExample()
try breakevenAnalysisExample()
try irrCalculationExample()
try targetSeekingExample()
try equationSolvingExample()
try constrainedGoalSeekExample()
errorHandlingExample()
try multipleRootsExample()

print("Examples complete!")
print()
print("Key Concepts:")
print("  • Goal-seeking finds where f(x) = target (root-finding)")
print("  • Newton-Raphson method: quadratic convergence")
print("  • Initial guess is critical for convergence")
print("  • Multiple roots: guess determines which is found")
print("  • Always handle errors (division by zero, convergence failure)")
print()
print("Next Steps:")
print("  • For multivariate problems, see VectorSpaceExample.swift")
print("  • For optimization (finding max/min), see OptimizationExample.swift")
print("  • For constrained optimization, see ConstrainedOptimizationExample.swift")

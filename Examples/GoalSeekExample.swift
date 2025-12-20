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

	print("Solution: x = \(result.formatted())")
	print("Verification: x² = \((result * result).formatted())")
	print()

	print("Note: Two solutions exist (±2), but Newton-Raphson finds one based on initial guess")

	// Try negative guess
	let negativeResult = try goalSeek(
		function: { x in x * x },
		target: 4.0,
		guess: -1.0,
		tolerance: 0.000001
	)

	print("Starting from negative guess: x = \(negativeResult.formatted())")

	print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Breakeven analysis
func breakevenAnalysisExample() throws {
	print("=== Breakeven Analysis ===\n")

	print("Scenario: Product pricing with demand curve")
	print("  Fixed costs: $10,000")
	print("  Variable cost per unit: $3")
	print("  Demand curve: Q = 10,000 - 1,000P")
	print()

	// Profit function
	func profit(price: Double) -> Double {
		let quantity = 10000 - 1000 * price
		let revenue = price * quantity
		let fixedCosts = 10000.0
		let variableCost = 3.0
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

	print("Breakeven price: \(breakevenPrice.formatted())")

	// Calculate breakeven quantity
	let breakevenQuantity = 10000 - 1000 * breakevenPrice
	print("Breakeven quantity: \(breakevenQuantity.formatted()) units")

	// Verify
	let verifyProfit = profit(price: breakevenPrice)
	print("Verification: Profit at breakeven = \(verifyProfit.currency()) (should be ~$0)")

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
		print("  Year \(t): \(sign)\(cf.currency())")
	}
	print()

	// Find IRR (rate where NPV = 0)
	print("Finding IRR (rate where NPV = 0)...")
	let irr = try goalSeek(
		function: npv,
		target: 0.0,
		guess: 0.10,  // Start with 10% guess
		tolerance: 0.000001
	)

	print("IRR: \((irr * 100).formatted())%")

	// Verify
	let verifyNPV = npv(rate: irr)
	print("Verification: NPV at IRR = \(verifyNPV.currency()) (should be ~$0)")

	print()

	// Show NPV at different rates
	print("NPV at various discount rates:")
	for rate in stride(from: 0.0, through: 0.30, by: 0.05) {
		let npvValue = npv(rate: rate)
		let marker = abs(rate - irr) < 0.01 ? " ← IRR" : ""
		print("  \((rate * 100).formatted().paddingLeft(toLength: 5))%: \(npvValue.currency())\(marker)")
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

	print("Required customers: \(requiredCustomers.formatted())")
	print("Verification: $50 × \(requiredCustomers.formatted()) = \((pricePerSeat * requiredCustomers).currency())")

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

	print("Steady-state customers: \(steadyStateCustomers)")
	print("Verification: 5%% × \(steadyStateCustomers.formatted()) = \((monthlyChurn * steadyStateCustomers).formatted()) new signups needed")

	let steadyStateMRR = pricePerSeat * steadyStateCustomers
	print("Steady-state MRR: \(steadyStateMRR.currency())")

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

	print("Solution: x = \(solution1.formatted())")

	// Verify
	let verify1 = exp(solution1) - 2*solution1 - 3
	print("Verification: e^\(solution1.formatted()) - 2(\(solution1.formatted())) - 3 = \(verify1.formatted())")

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

	print("Solution: x = \(solution2.formatted())")
	print("Verification: cos(\(solution2.formatted())) = \(cos(solution2).formatted()) ≈ \(solution2.formatted())")

	print()

	// Problem 3: Solve x³ - 2x - 5 = 0
	print("Problem 3: Solve x³ - 2x - 5 = 0")
	print()
	
	let objective: (Double) -> Double = { x in (x * x * x) - (2 * x) - 5 }

	let solution3 = try goalSeek(
		function: objective,
		target: 0.0,
		guess: 2.0,
		tolerance: 0.000001
	)

	print("Solution: x = \(solution3.formatted())")

	let verify3 = solution3*solution3*solution3 - 2*solution3 - 5
	print("Verification: (\(solution3.formatted()))³ - 2(\(solution3.formatted())) - 5 = \(verify3.formatted())")

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
		let fixedCosts = 10000.0
		let variableCost = 3.0
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
		print(String(format: "Breakeven price: \(result.optimalValue.currency())", result.optimalValue))
		print(String(format: "Profit at breakeven: \(result.objectiveValue.currency())", result.objectiveValue))
		print(String(format: "Iterations: \(result.iterations.formatted())", result.iterations))
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
	} catch let error as BusinessMathError {
		print("✗ Error: \(error.errorDescription ?? "Goal seek failed")")
		if let suggestion = error.recoverySuggestion {
			print("  Suggestion: \(suggestion)")
		}
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
		print("Solution: \(result.formatted())")
	} catch let error as BusinessMathError {
		print("✗ Error: \(error.errorDescription ?? "Goal seek failed")")
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
		} catch let error as BusinessMathError {
			print("  Warning: \(error.errorDescription ?? "Goal seek failed")")
			return nil
		} catch {
			print("  Error: \(error)")
			return nil
		}
	}

	if let price = findBreakeven(fixedCosts: 20000, variableCost: 5.0) {
		print("  ✓ Breakeven price: \(price.currency())")
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

	print("Root 1 (guess=0): x = \(root1.formatted())")
	print("  Verification: f(\(root1.formatted())) = \(polynomial(x: root1).formatted())")

	print()

	// Find second root (starting near x=3)
	let root2 = try goalSeek(
		function: polynomial,
		target: 0.0,
		guess: 5.0,
		tolerance: 0.000001
	)

	print("Root 2 (guess=0): x = \(root2.formatted())")
	print("  Verification: f(\(root2.formatted())) = \(polynomial(x: root2).formatted())")

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

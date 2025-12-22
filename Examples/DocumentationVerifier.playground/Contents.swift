import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport

func profit(price: Double) -> Double {
	let quantity = 10000 - 1000 * price  // Demand function
	let revenue = price * quantity
	let fixedCosts = 5000.0
	let variableCost = 4.0
	let totalCosts = fixedCosts + variableCost * quantity
	return revenue - totalCosts
}


	// Find breakeven price with constraints
	let optimizer = GoalSeekOptimizer<Double>(target: 0.0)

	// Must be less than $8 (maximum price)
	let maxPriceConstraint = Constraint<Double>(
		type: .greaterThanOrEqual,
		bound: 8.0
	)

	let result = optimizer.optimize(
		objective: profit,
		constraints: [maxPriceConstraint],
		initialValue: 1.0,
		bounds: (lower: 0.0, upper: 100.0)
	)

	if result.converged {
		print("Breakeven price: \(result.optimalValue.currency())")
	} else {
		print("No breakeven point found within constraints")
	}

do {
	// Function with zero derivative at x=0
	let result = try goalSeek(
		function: { x in x * x * x },  // f'(0) = 0
		target: 0.0,
		guess: 0.0
	)
} catch let error as BusinessMathError {
	print(error.localizedDescription)
	print("Error Code: \(error.code)")
	
	if let recovery = error.recoverySuggestion {
		print("How to fix:\n\(recovery)")
	}
	
	if let helpURL = error.helpAnchor {
		print("Learn more: \(helpURL)")
	}
}

do {
	let result = try goalSeek(
		function: { x in sin(x) },
		target: 1.5,  // sin(x) never equals 1.5
		guess: 0.0
	)
} catch let error as BusinessMathError {
	print(error.localizedDescription)
	print("Error Code: \(error.code)")
  
	if let recovery = error.recoverySuggestion {
		print("How to fix:\n\(recovery)")
	}
	
	if let helpURL = error.helpAnchor {
		print("Learn more: \(helpURL)")
	}
}

import Testing
import Foundation
@testable import BusinessMath

@Suite("Optimizer Tests")
struct OptimizerTests {

	// MARK: - Optimization Result

	@Test("Optimization result structure")
	func optimizationResultStructure() throws {
		let history = [
			IterationHistory<Double>(iteration: 0, value: 1.0, objective: 10.0, gradient: 5.0),
			IterationHistory<Double>(iteration: 1, value: 0.5, objective: 2.5, gradient: 2.5),
			IterationHistory<Double>(iteration: 2, value: 0.1, objective: 0.01, gradient: 0.2)
		]

		let result = OptimizationResult(
			optimalValue: 0.1,
			objectiveValue: 0.01,
			iterations: 3,
			converged: true,
			history: history
		)

		#expect(result.optimalValue == 0.1)
		#expect(result.objectiveValue == 0.01)
		#expect(result.iterations == 3)
		#expect(result.converged)
		#expect(result.history.count == 3)
	}

	@Test("Optimization result description")
	func optimizationResultDescription() throws {
		let result = OptimizationResult<Double>(
			optimalValue: 5.0,
			objectiveValue: 0.0,
			iterations: 10,
			converged: true,
			history: []
		)

		let description = result.description

		#expect(description.contains("Optimal Value: 5"))
		#expect(description.contains("Objective: 0"))
		#expect(description.contains("Iterations: 10"))
		#expect(description.contains("Converged: Yes"))
	}

	// MARK: - Constraints

	@Test("Less than constraint - satisfied")
	func lessThanConstraintSatisfied() throws {
		let constraint = Constraint<Double>(
			type: .lessThan,
			bound: 10.0
		)

		#expect(constraint.isSatisfied(5.0))
		#expect(constraint.isSatisfied(9.99))
	}

	@Test("Less than constraint - not satisfied")
	func lessThanConstraintViolated() throws {
		let constraint = Constraint<Double>(
			type: .lessThan,
			bound: 10.0
		)

		#expect(!constraint.isSatisfied(10.0))
		#expect(!constraint.isSatisfied(15.0))
	}

	@Test("Greater than constraint")
	func greaterThanConstraint() throws {
		let constraint = Constraint<Double>(
			type: .greaterThan,
			bound: 0.0
		)

		#expect(constraint.isSatisfied(1.0))
		#expect(!constraint.isSatisfied(0.0))
		#expect(!constraint.isSatisfied(-1.0))
	}

	@Test("Equal to constraint with tolerance")
	func equalToConstraint() throws {
		let constraint = Constraint<Double>(
			type: .equalTo,
			bound: 10.0
		)

		#expect(constraint.isSatisfied(10.0))
		#expect(constraint.isSatisfied(10.00005))  // Within tolerance
		#expect(!constraint.isSatisfied(10.1))
	}

	@Test("Constraint with custom function")
	func constraintWithFunction() throws {
		// Constraint: x^2 < 100
		let constraint = Constraint<Double>(
			type: .lessThan,
			bound: 100.0,
			function: { $0 * $0 }
		)

		#expect(constraint.isSatisfied(5.0))  // 25 < 100
		#expect(constraint.isSatisfied(9.0))  // 81 < 100
		#expect(!constraint.isSatisfied(11.0))  // 121 > 100
	}

	// MARK: - Iteration History

	@Test("Iteration history tracks progress")
	func iterationHistory() throws {
		var history: [IterationHistory<Double>] = []

		for i in 0..<5 {
			let x = Double(i) * 0.5
			let objective = x * x
			let gradient = 2 * x

			history.append(IterationHistory(
				iteration: i,
				value: x,
				objective: objective,
				gradient: gradient
			))
		}

		#expect(history.count == 5)
		#expect(history[0].value == 0.0)
		#expect(history[4].value == 2.0)
		#expect(history[4].objective == 4.0)
	}

	// MARK: - Bounds

	@Test("Optimizer respects bounds")
	func optimizerBounds() throws {
		// This would be tested with actual optimizer implementation
		// Placeholder for bound testing logic

		let bounds: (lower: Double, upper: Double) = (0.0, 10.0)

		// Test value within bounds
		let value1 = 5.0
		#expect(value1 >= bounds.lower && value1 <= bounds.upper)

		// Test value outside bounds
		let value2 = 15.0
		#expect(!(value2 >= bounds.lower && value2 <= bounds.upper))
	}
}

import Testing
import Foundation
@testable import BusinessMath

/// The answer must not depend on how hard the solver was allowed to work.
///
/// ## The property
///
/// `maxCuttingRounds` is a **budget**, not a model parameter. Spending more of it may take
/// longer, explore fewer nodes, or generate more cuts; it may not change which point is
/// optimal. A solver whose answer moves with its budget is not answering the question it was
/// asked, and because every one of those answers is feasible and carries `status == .optimal`,
/// no caller can tell.
///
/// ## Why it needed stating
///
/// It did not hold. Measured on the first fixture below, with both termination guards off and
/// only the budget varying:
///
/// | `maxCuttingRounds` | reported | solution |
/// |---|---|---|
/// | 0, 1, 2 | 14 | (2, 0, 2) |
/// | 3 | 12 | (0, 2, 2) |
/// | 5 | 10 | (1, 1, 1) |
/// | 6 | 7 | (1, 1, 0) |
/// | 8 through 20 | 9 | (0, 3, 0) |
///
/// The true optimum is 14. Turning cutting planes off gave 14; turning them on lost up to half
/// the objective. The cause was the cutting loop deriving Gomory fractional cuts from tableaux
/// that already contained its own cuts — see `GomoryMixedIntegerCutTests` for why that
/// derivation does not survive a fractional column, and for the enumeration oracle that checks
/// the replacement.
///
/// Every optimum asserted here was computed by exhaustive enumeration over the box the
/// constraints imply, not by running this solver.
@Suite("Branch-and-cut budget independence")
struct BranchAndCutBudgetIndependenceTests {

	private struct Problem {
		let objective: [Double]
		let rows: [([Double], Double)]
		let optimum: Double
		let name: String
	}

	private static let problems: [Problem] = [
		Problem(
			objective: [4.0, 3.0, 3.0],
			rows: [([4.0, 2.0, 1.0], 10.0), ([1.0, 4.0, 2.0], 12.0), ([1.0, 1.0, 5.0], 15.0)],
			optimum: 14.0,
			name: "three-variable knapsack"
		),
		Problem(
			objective: [7.0, 9.0],
			rows: [([-1.0, 3.0], 6.0), ([7.0, 1.0], 35.0)],
			optimum: 55.0,
			name: "the textbook Gomory example"
		),
		Problem(
			objective: [5.0, 4.0],
			rows: [([6.0, 4.0], 24.0), ([1.0, 2.0], 6.0)],
			optimum: 20.0,
			name: "two rows, fractional vertex"
		),
		Problem(
			objective: [1.0, 1.0, 1.0],
			rows: [([3.0, 5.0, 7.0], 22.0), ([2.0, 1.0, 4.0], 13.0)],
			optimum: 6.0,
			name: "unit objective, three variables"
		)
	]

	/// Budgets spanning none, one, and many rounds. Zero is the control: it disables the loop
	/// without disabling the feature, so a disagreement between it and any other entry is
	/// attributable to cutting and nothing else.
	private static let budgets: [Int] = [0, 1, 2, 3, 4, 5, 6, 8, 12, 20]

	private func solve(_ problem: Problem, budget: Int, aging: Bool) throws -> (Double, [Int]) {
		let solver = BranchAndBoundSolver<VectorN<Double>>(
			enableCuttingPlanes: true,
			maxCuttingRounds: budget,
			detectStagnation: false,
			detectCycling: false,
			enableCutAging: aging,
			cutAgingLimit: 1
		)

		let coefficients = problem.objective
		let objective: @Sendable (VectorN<Double>) -> Double = { point in
			let values = point.toArray()
			var total: Double = 0.0
			for index in 0..<Swift.min(values.count, coefficients.count) {
				total += values[index] * coefficients[index]
			}
			return total
		}

		let dimension = problem.objective.count
		let constraints: [MultivariateConstraint<VectorN<Double>>] = problem.rows.map { row in
			.linearInequality(coefficients: row.0, rhs: row.1, sense: .lessOrEqual)
		}

		let result = try solver.solve(
			objective: objective,
			from: VectorN(Array(repeating: 1.0, count: dimension)),
			subjectTo: constraints,
			integerSpec: IntegerProgramSpecification(
				integerVariables: Set(0..<dimension),
				binaryVariables: []
			),
			minimize: false
		)
		return (result.objectiveValue, result.integerSolution)
	}

	@Test("Every cutting budget reaches the enumerated optimum", arguments: problems.indices)
	func budgetDoesNotChangeTheOptimum(_ index: Int) throws {
		let problem = Self.problems[index]
		// A tolerance rather than equality: `objectiveValue` is evaluated at the relaxation
		// point that passed the integrality test, not at the integer point the result reports,
		// so it lands within `integralityTolerance` of the true value rather than on it.
		let epsilon: Double = 1e-6

		for aging in [false, true] {
			for budget in Self.budgets {
				let run = try solve(problem, budget: budget, aging: aging)
				let error: Double = abs(run.0 - problem.optimum)
				#expect(error < epsilon,
						"\(problem.name), budget \(budget), aging \(aging): reported \(run.0) at \(run.1), optimum is \(problem.optimum)")
			}
		}
	}

	/// The same claim against the feature switch rather than the budget: enabling cutting planes
	/// must not change the answer either.
	@Test("Cutting planes do not change the optimum", arguments: problems.indices)
	func cuttingPlanesDoNotChangeTheOptimum(_ index: Int) throws {
		let problem = Self.problems[index]
		let epsilon: Double = 1e-6

		let dimension = problem.objective.count
		let coefficients = problem.objective
		let objective: @Sendable (VectorN<Double>) -> Double = { point in
			let values = point.toArray()
			var total: Double = 0.0
			for i in 0..<Swift.min(values.count, coefficients.count) {
				total += values[i] * coefficients[i]
			}
			return total
		}
		let constraints: [MultivariateConstraint<VectorN<Double>>] = problem.rows.map { row in
			.linearInequality(coefficients: row.0, rhs: row.1, sense: .lessOrEqual)
		}
		let spec = IntegerProgramSpecification(
			integerVariables: Set(0..<dimension),
			binaryVariables: []
		)

		let plain = BranchAndBoundSolver<VectorN<Double>>(enableCuttingPlanes: false)
		let result = try plain.solve(
			objective: objective,
			from: VectorN(Array(repeating: 1.0, count: dimension)),
			subjectTo: constraints,
			integerSpec: spec,
			minimize: false
		)

		let error: Double = abs(result.objectiveValue - problem.optimum)
		#expect(error < epsilon,
				"\(problem.name) without cutting planes: reported \(result.objectiveValue), optimum is \(problem.optimum)")
	}
}

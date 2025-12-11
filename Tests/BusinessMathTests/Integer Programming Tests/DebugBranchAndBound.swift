import Testing
import Foundation
@testable import BusinessMath

@Suite("Debug Branch and Bound")
struct DebugBranchAndBound {

    @Test("Debug simple binary problem")
    func debugSimpleBinary() throws {
        // Simplest possible problem: minimize x subject to x ∈ {0,1}
        let spec = IntegerProgramSpecification.allBinary(dimension: 1)

        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            x.toArray()[0]  // Minimize x (optimal: x=0)
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { x in -x.toArray()[0] },       // x ≥ 0
            .inequality { x in x.toArray()[0] - 1.0 },  // x ≤ 1
        ]

        print("Testing InequalityOptimizer directly first...")
        let optimizer = InequalityOptimizer<VectorN<Double>>(
            constraintTolerance: 1e-8,
            maxIterations: 1000
        )

        do {
            let lpResult = try optimizer.minimize(
                objective,
                from: VectorN([0.5]),
                subjectTo: constraints
            )
            print("LP relaxation succeeded!")
            print("Solution: \(lpResult.solution.toArray())")
            print("Objective: \(lpResult.objectiveValue)")
        } catch {
            print("LP relaxation failed: \(error)")
            throw error
        }

        print("\nNow manually testing root node creation...")
        // Test if root node solves correctly
        let rootOptimizer = InequalityOptimizer<VectorN<Double>>(
            constraintTolerance: 1e-8,
            maxIterations: 1000
        )

        do {
            let rootResult = try rootOptimizer.minimize(
                objective,
                from: VectorN([0.5]),
                subjectTo: constraints
            )
            print("Root node LP succeeded!")
            print("Root solution: \(rootResult.solution.toArray())")
            print("Is integer feasible? \(spec.isIntegerFeasible(rootResult.solution))")
        } catch {
            print("Root node LP failed: \(error)")
        }

        print("\nNow testing Branch and Bound...")
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 100,
            timeLimit: 10.0
        )

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5]),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        print("Branch and Bound result:")
        print("Status: \(result.status)")
        print("Solution: \(result.solution.toArray())")
        print("Objective: \(result.objectiveValue)")
        print("Nodes explored: \(result.nodesExplored)")

        #expect(result.status != IntegerSolutionStatus.infeasible)
    }
}

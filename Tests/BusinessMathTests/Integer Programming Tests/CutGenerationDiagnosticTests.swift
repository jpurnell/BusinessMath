import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Cut Generation Diagnostics")
struct CutGenerationDiagnosticTests {

    @Test("Debug: Check if LP solution is fractional")
    func debugLPFractional() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            validateLinearity: false,
            enableCuttingPlanes: true,
            maxCuttingRounds: 5
        )

        // Maximize x + y with x + y ≤ 3.7
        // LP optimum should be fractional (e.g., 1.85 + 1.85 = 3.7)
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(arr[0] + arr[1])
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 3.7, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0, 1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        print("Solution: \(result.solution.toArray())")
        print("Objective: \(result.objectiveValue)")
        print("Nodes explored: \(result.nodesExplored)")
        print("Status: \(result.status)")

        if let stats = result.cuttingPlaneStats {
            print("Cuts generated: \(stats.totalCutsGenerated)")
            print("Gomory cuts: \(stats.gomoryCuts)")
            print("Cutting rounds: \(stats.cuttingRounds)")
            print("LP resolves: \(stats.lpResolves)")
            print("Root LP before cuts: \(stats.rootLPBoundBeforeCuts)")
            print("Root LP after cuts: \(stats.rootLPBoundAfterCuts)")
        } else {
            print("No cutting plane stats!")
        }

        // Test should pass - we just want to see the output
        #expect(Bool(true))
    }

    @Test("Verify SimplexSolver returns tableau")
    func verifySimplexTableau() throws {
        let solver = SimplexRelaxationSolver()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(arr[0] + arr[1])
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 3.7, sense: .lessOrEqual)
        ]

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([1.0, 1.0]),
            minimize: true
        )

        print("LP Status: \(result.status)")
        print("LP Solution: \(result.solution?.toArray() ?? [])")
        print("LP Objective: \(result.objectiveValue)")
        print("Has simplex result: \(result.simplexResult != nil)")
        print("Has tableau: \(result.simplexResult?.tableau != nil)")
        print("Has basis: \(result.simplexResult?.basis != nil)")

        if let sol = result.solution {
            let arr = sol.toArray()
            for (i, val) in arr.enumerated() {
                let frac = val - round(val)
                print("  x[\(i)] = \(val), fractional part = \(frac)")
            }
        }

        #expect(result.simplexResult != nil)
        #expect(result.simplexResult?.tableau != nil)
    }
}

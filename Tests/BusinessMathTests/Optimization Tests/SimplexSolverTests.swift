import Testing
import Foundation
@testable import BusinessMath

@Suite("Simplex Solver Tests")
struct SimplexSolverTests {

    // MARK: - Basic LP Problems

    @Test("Simple 2D LP - maximize profit")
    func testSimple2DMaximization() throws {
        // Classic LP: maximize 3x + 2y
        // Subject to: x + y ≤ 4
        //            2x + y ≤ 5
        //            x, y ≥ 0
        // Optimal: (1, 3) with value 9

        let solver = SimplexSolver()

        let result = try solver.maximize(
            objective: [3.0, 2.0],
            subjectTo: [
                SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual, rhs: 4.0),
                SimplexConstraint(coefficients: [2.0, 1.0], relation: .lessOrEqual, rhs: 5.0)
            ]
        )

        #expect(result.status == SimplexStatus.optimal)
        #expect(abs(result.objectiveValue - 9.0) < 1e-6)
        #expect(abs(result.solution[0] - 1.0) < 1e-6)
        #expect(abs(result.solution[1] - 3.0) < 1e-6)
    }

    @Test("Simple 2D LP - minimize cost")
    func testSimple2DMinimization() throws {
        // Minimize 2x + 3y
        // Subject to: x + y ≥ 4
        //            2x + y ≥ 5
        //            x, y ≥ 0
        // Corner points: (1,3) obj=11, (0,5) obj=15, (4,0) obj=8
        // Optimal: (4, 0) with value 8

        let solver = SimplexSolver()

        let result = try solver.minimize(
            objective: [2.0, 3.0],
            subjectTo: [
                SimplexConstraint(coefficients: [1.0, 1.0], relation: .greaterOrEqual, rhs: 4.0),
                SimplexConstraint(coefficients: [2.0, 1.0], relation: .greaterOrEqual, rhs: 5.0)
            ]
        )

        #expect(result.status == SimplexStatus.optimal)
        #expect(abs(result.objectiveValue - 8.0) < 1e-6)
        #expect(abs(result.solution[0] - 4.0) < 1e-6)
        #expect(abs(result.solution[1] - 0.0) < 1e-6)
    }

    @Test("Equality constraints")
    func testEqualityConstraints() throws {
        // Maximize x + 2y
        // Subject to: x + y = 3
        //            x, y ≥ 0
        // Optimal: (0, 3) with value 6

        let solver = SimplexSolver()

        let result = try solver.maximize(
            objective: [1.0, 2.0],
            subjectTo: [
                SimplexConstraint(coefficients: [1.0, 1.0], relation: .equal, rhs: 3.0)
            ]
        )

        #expect(result.status == SimplexStatus.optimal)
        #expect(abs(result.objectiveValue - 6.0) < 1e-6)
        #expect(abs(result.solution[0] - 0.0) < 1e-6)
        #expect(abs(result.solution[1] - 3.0) < 1e-6)
    }

    @Test("Unbounded problem")
    func testUnboundedProblem() throws {
        // Maximize x + y
        // Subject to: -x + y ≤ 1
        //            x, y ≥ 0
        // Unbounded (can increase both x and y indefinitely)

        let solver = SimplexSolver()

        let result = try solver.maximize(
            objective: [1.0, 1.0],
            subjectTo: [
                SimplexConstraint(coefficients: [-1.0, 1.0], relation: .lessOrEqual, rhs: 1.0)
            ]
        )

        #expect(result.status == SimplexStatus.unbounded)
    }

    @Test("Infeasible problem")
    func testInfeasibleProblem() throws {
        // Maximize x + y
        // Subject to: x + y ≤ 1
        //            x + y ≥ 2
        //            x, y ≥ 0
        // Infeasible (no solution satisfies both constraints)

        let solver = SimplexSolver()

        let result = try solver.maximize(
            objective: [1.0, 1.0],
            subjectTo: [
                SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual, rhs: 1.0),
                SimplexConstraint(coefficients: [1.0, 1.0], relation: .greaterOrEqual, rhs: 2.0)
            ]
        )

        #expect(result.status == SimplexStatus.infeasible)
    }

    @Test("Degenerate problem")
    func testDegenerateProblem() throws {
        // Problem with degenerate basic feasible solution
        // Maximize x
        // Subject to: x ≤ 1
        //            x + y ≤ 1
        //            y ≤ 1
        //            x, y ≥ 0
        // Optimal: (1, 0) with value 1

        let solver = SimplexSolver()

        let result = try solver.maximize(
            objective: [1.0, 0.0],
            subjectTo: [
                SimplexConstraint(coefficients: [1.0, 0.0], relation: .lessOrEqual, rhs: 1.0),
                SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual, rhs: 1.0),
                SimplexConstraint(coefficients: [0.0, 1.0], relation: .lessOrEqual, rhs: 1.0)
            ]
        )

        #expect(result.status == SimplexStatus.optimal)
        #expect(abs(result.objectiveValue - 1.0) < 1e-6)
    }

    // MARK: - Standard Form Conversion

    @Test("Mixed constraint types")
    func testMixedConstraints() throws {
        // Maximize 2x + 3y
        // Subject to: x + y ≤ 5    (≤)
        //            x + 2y ≥ 4    (≥)
        //            2x + y = 6    (=)
        //            x, y ≥ 0
        // From 2x+y=6: y=6-2x. Objective=2x+3(6-2x)=18-4x
        // Maximize 18-4x → minimize x
        // Constraints: 1≤x≤8/3 (from combining all constraints)
        // Optimal: (1, 4) with value 14

        let solver = SimplexSolver()

        let result = try solver.maximize(
            objective: [2.0, 3.0],
            subjectTo: [
                SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual, rhs: 5.0),
                SimplexConstraint(coefficients: [1.0, 2.0], relation: .greaterOrEqual, rhs: 4.0),
                SimplexConstraint(coefficients: [2.0, 1.0], relation: .equal, rhs: 6.0)
            ]
        )

        #expect(result.status == SimplexStatus.optimal)
        #expect(abs(result.objectiveValue - 14.0) < 1e-6)
        #expect(abs(result.solution[0] - 1.0) < 1e-6)
        #expect(abs(result.solution[1] - 4.0) < 1e-6)
    }

    // MARK: - Larger Problems

    @Test("3D optimization problem")
    func test3DOptimization() throws {
        // Maximize x + 2y + 3z
        // Subject to: x + y + z ≤ 10
        //            2x + y ≤ 12
        //            y + 2z ≤ 14
        //            x, y, z ≥ 0
        // Corner points: (0,0,7) obj=21, (0,6,4) obj=24, (0,10,0) obj=20
        // Optimal: (0, 6, 4) with value 24

        let solver = SimplexSolver()

        let result = try solver.maximize(
            objective: [1.0, 2.0, 3.0],
            subjectTo: [
                SimplexConstraint(coefficients: [1.0, 1.0, 1.0], relation: .lessOrEqual, rhs: 10.0),
                SimplexConstraint(coefficients: [2.0, 1.0, 0.0], relation: .lessOrEqual, rhs: 12.0),
                SimplexConstraint(coefficients: [0.0, 1.0, 2.0], relation: .lessOrEqual, rhs: 14.0)
            ]
        )

        #expect(result.status == SimplexStatus.optimal)
        #expect(abs(result.objectiveValue - 24.0) < 1e-6)
        #expect(abs(result.solution[0] - 0.0) < 1e-6)
        #expect(abs(result.solution[1] - 6.0) < 1e-6)
        #expect(abs(result.solution[2] - 4.0) < 1e-6)
    }

    @Test("5-variable problem")
    func test5VariableProblem() throws {
        // Larger problem to test scalability
        // Maximize sum of all variables
        // Subject to: various constraints

        let solver = SimplexSolver()

        let result = try solver.maximize(
            objective: [1.0, 1.0, 1.0, 1.0, 1.0],
            subjectTo: [
                SimplexConstraint(coefficients: [1.0, 1.0, 0.0, 0.0, 0.0], relation: .lessOrEqual, rhs: 5.0),
                SimplexConstraint(coefficients: [0.0, 1.0, 1.0, 0.0, 0.0], relation: .lessOrEqual, rhs: 4.0),
                SimplexConstraint(coefficients: [0.0, 0.0, 1.0, 1.0, 0.0], relation: .lessOrEqual, rhs: 3.0),
                SimplexConstraint(coefficients: [0.0, 0.0, 0.0, 1.0, 1.0], relation: .lessOrEqual, rhs: 2.0)
            ]
        )

        #expect(result.status == SimplexStatus.optimal)
        // Sum should be limited by constraints
        #expect(result.objectiveValue > 0)
        #expect(result.objectiveValue <= 14.0)
    }

    // MARK: - Special Cases

    @Test("Minimization with simple bounds")
    func testMinimizeWithBounds() throws {
        // Minimize x
        // Subject to: -x ≤ 0 (x ≥ 0)
        //            x ≤ 1
        // Optimal: x = 0

        let solver = SimplexSolver()

        let result = try solver.minimize(
            objective: [1.0],
            subjectTo: [
                SimplexConstraint(coefficients: [-1.0], relation: .lessOrEqual, rhs: 0.0),
                SimplexConstraint(coefficients: [1.0], relation: .lessOrEqual, rhs: 1.0)
            ]
        )

        print("Minimize with bounds: status=\(result.status), obj=\(result.objectiveValue), sol=\(result.solution)")
        #expect(result.status == SimplexStatus.optimal)
        #expect(abs(result.objectiveValue - 0.0) < 1e-6)
        #expect(abs(result.solution[0] - 0.0) < 1e-6)
    }

    @Test("Zero objective function")
    func testZeroObjective() throws {
        // Minimize 0 (any feasible solution is optimal)
        // Subject to: x + y ≤ 1
        //            x, y ≥ 0

        let solver = SimplexSolver()

        let result = try solver.minimize(
            objective: [0.0, 0.0],
            subjectTo: [
                SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual, rhs: 1.0)
            ]
        )

        #expect(result.status == SimplexStatus.optimal)
        #expect(abs(result.objectiveValue) < 1e-6)
    }

    @Test("Single variable problem")
    func testSingleVariable() throws {
        // Maximize x
        // Subject to: x ≤ 5
        //            x ≥ 0

        let solver = SimplexSolver()

        let result = try solver.maximize(
            objective: [1.0],
            subjectTo: [
                SimplexConstraint(coefficients: [1.0], relation: .lessOrEqual, rhs: 5.0)
            ]
        )

        #expect(result.status == SimplexStatus.optimal)
        #expect(abs(result.objectiveValue - 5.0) < 1e-6)
        #expect(abs(result.solution[0] - 5.0) < 1e-6)
    }

    // MARK: - Numerical Stability

    @Test("Binary constraints from Branch & Bound")
    func testBinaryConstraintsFromBranchAndBound() throws {
        // This exact set of constraints is generated by BranchAndBound
        // for the "binary variable already integer at root" test
        // Minimize x0 + x1
        // Subject to:
        //   -x0 - x1 ≤ -1   (x0 + x1 ≥ 1)
        //   -x0 ≤ 0         (x0 ≥ 0)
        //   -x1 ≤ 0         (x1 ≥ 0)
        //   x0 ≤ 1
        //   x1 ≤ 1
        // Optimal: x0=1, x1=0 (or x0=0, x1=1) with value 1.0

        let solver = SimplexSolver()

        let result = try solver.minimize(
            objective: [1.0, 1.0],
            subjectTo: [
                SimplexConstraint(coefficients: [-1.0, -1.0], relation: .lessOrEqual, rhs: -1.0),
                SimplexConstraint(coefficients: [-1.0, 0.0], relation: .lessOrEqual, rhs: 0.0),
                SimplexConstraint(coefficients: [0.0, -1.0], relation: .lessOrEqual, rhs: 0.0),
                SimplexConstraint(coefficients: [1.0, 0.0], relation: .lessOrEqual, rhs: 1.0),
                SimplexConstraint(coefficients: [0.0, 1.0], relation: .lessOrEqual, rhs: 1.0)
            ]
        )

        print("Binary constraint test result: status=\(result.status), obj=\(result.objectiveValue), sol=\(result.solution)")

        #expect(result.status == SimplexStatus.optimal)
        #expect(abs(result.objectiveValue - 1.0) < 1e-6)
        #expect(abs(result.solution[0] + result.solution[1] - 1.0) < 1e-6)  // x0 + x1 = 1
    }

    @Test("Large coefficient values")
    func testLargeCoefficients() throws {
        // Test numerical stability with large numbers
        // Maximize 1000x + 2000y
        // Subject to: 100x + 200y ≤ 10000
        //            x, y ≥ 0

        let solver = SimplexSolver()

        let result = try solver.maximize(
            objective: [1000.0, 2000.0],
            subjectTo: [
                SimplexConstraint(coefficients: [100.0, 200.0], relation: .lessOrEqual, rhs: 10000.0)
            ]
        )

        #expect(result.status == SimplexStatus.optimal)
        #expect(abs(result.objectiveValue - 100000.0) < 1e-3)  // Relaxed tolerance for large values
    }

    @Test("Small coefficient values")
    func testSmallCoefficients() throws {
        // Test numerical stability with small numbers
        // Maximize 0.001x + 0.002y
        // Subject to: 0.01x + 0.02y ≤ 1
        //            x, y ≥ 0

        let solver = SimplexSolver()

        let result = try solver.maximize(
            objective: [0.001, 0.002],
            subjectTo: [
                SimplexConstraint(coefficients: [0.01, 0.02], relation: .lessOrEqual, rhs: 1.0)
            ]
        )

        #expect(result.status == SimplexStatus.optimal)
        #expect(result.objectiveValue > 0)
    }

    @Test("Multiple upper bounds on same variable")
    func testMultipleUpperBounds() throws {
        // Test case from Branch & Bound: same variable has two upper bound constraints
        // Minimize -x0 - 2x1 - x2 - 2x3
        // Subject to: 5x0 + 4x1 + 6x2 + 3x3 ≤ 10
        //            x0 ≤ 1
        //            x1 ≤ 1
        //            x2 ≤ 1    (original upper bound)
        //            x3 ≤ 1
        //            x2 ≤ 0    (branching constraint - tighter bound)
        //            x0, x1, x2, x3 ≥ 0
        // Expected: x2 must be 0 (respecting tighter constraint)
        // With x2=0 forced, optimal is: x0=0.6, x1=1, x3=1, obj=-4.6
        // Verification: 5*0.6 + 4*1 + 6*0 + 3*1 = 3+4+0+3 = 10 ≤ 10 ✓

        let solver = SimplexSolver()

        let result = try solver.minimize(
            objective: [-1.0, -2.0, -1.0, -2.0],
            subjectTo: [
                SimplexConstraint(coefficients: [5.0, 4.0, 6.0, 3.0], relation: .lessOrEqual, rhs: 10.0),
                SimplexConstraint(coefficients: [1.0, 0.0, 0.0, 0.0], relation: .lessOrEqual, rhs: 1.0),
                SimplexConstraint(coefficients: [0.0, 1.0, 0.0, 0.0], relation: .lessOrEqual, rhs: 1.0),
                SimplexConstraint(coefficients: [0.0, 0.0, 1.0, 0.0], relation: .lessOrEqual, rhs: 1.0),
                SimplexConstraint(coefficients: [0.0, 0.0, 0.0, 1.0], relation: .lessOrEqual, rhs: 1.0),
                SimplexConstraint(coefficients: [0.0, 0.0, 1.0, 0.0], relation: .lessOrEqual, rhs: 0.0)  // Tighter bound
            ]
        )

        // print("Multiple bounds test: status=\(result.status), obj=\(result.objectiveValue), sol=\(result.solution)")

        #expect(result.status == SimplexStatus.optimal)
        #expect(abs(result.objectiveValue - (-4.6)) < 1e-6)  // obj = -0.6 - 2*1 - 0 - 2*1 = -4.6
        #expect(abs(result.solution[0] - 0.6) < 1e-6)  // x0 = 0.6
        #expect(abs(result.solution[1] - 1.0) < 1e-6)  // x1 = 1
        #expect(abs(result.solution[2] - 0.0) < 1e-6)  // x2 = 0 (CRITICAL: must respect tighter bound)
        #expect(abs(result.solution[3] - 1.0) < 1e-6)  // x3 = 1
    }

    @Test("Lower bound constraint (x ≥ k)")
    func testLowerBoundConstraint() throws {
        // Test case from Branch & Bound RIGHT branch
        // Same problem but with x2 ≥ 1 instead of x2 ≤ 0
        // Minimize -x0 - 2x1 - x2 - 2x3
        // Subject to: 5x0 + 4x1 + 6x2 + 3x3 ≤ 10
        //            x0 ≤ 1
        //            x1 ≤ 1
        //            x2 ≤ 1    (original upper bound)
        //            x3 ≤ 1
        //            -x2 ≤ -1  (x2 ≥ 1, branching constraint - lower bound)
        //            x0, x1, x2, x3 ≥ 0
        // Expected: x2 must be ≥ 1, so with x2=1 optimal
        // With x2=1, constraint becomes: 5x0 + 4x1 + 6 + 3x3 ≤ 10  →  5x0 + 4x1 + 3x3 ≤ 4
        // To minimize objective -x0 - 2x1 - 2x3, we maximize x0 + 2x1 + 2x3
        // Best bang-for-buck: x3 (2/3), then x1 (2/4), then x0 (1/5)
        // Use x3=1 (cost 3), x1=0.25 (cost 1), total cost=4
        // So: x0=0, x1=0.25, x2=1, x3=1, obj = -0 - 2*0.25 - 1*1 - 2*1 = -3.5

        let solver = SimplexSolver()

        let result = try solver.minimize(
            objective: [-1.0, -2.0, -1.0, -2.0],
            subjectTo: [
                SimplexConstraint(coefficients: [5.0, 4.0, 6.0, 3.0], relation: .lessOrEqual, rhs: 10.0),
                SimplexConstraint(coefficients: [1.0, 0.0, 0.0, 0.0], relation: .lessOrEqual, rhs: 1.0),
                SimplexConstraint(coefficients: [0.0, 1.0, 0.0, 0.0], relation: .lessOrEqual, rhs: 1.0),
                SimplexConstraint(coefficients: [0.0, 0.0, 1.0, 0.0], relation: .lessOrEqual, rhs: 1.0),
                SimplexConstraint(coefficients: [0.0, 0.0, 0.0, 1.0], relation: .lessOrEqual, rhs: 1.0),
                SimplexConstraint(coefficients: [0.0, 0.0, -1.0, 0.0], relation: .lessOrEqual, rhs: -1.0)  // x2 ≥ 1
            ]
        )

        // print("Lower bound test: status=\(result.status), obj=\(result.objectiveValue), sol=\(result.solution)")

        #expect(result.status == SimplexStatus.optimal)
        #expect(abs(result.objectiveValue - (-3.5)) < 1e-6)  // obj = -0 - 2*0.25 - 1*1 - 2*1 = -3.5
        #expect(abs(result.solution[0] - 0.0) < 1e-6)  // x0 = 0
        #expect(abs(result.solution[1] - 0.25) < 1e-6)  // x1 = 0.25
        #expect(abs(result.solution[2] - 1.0) < 1e-6)  // x2 = 1 (CRITICAL: must respect lower bound x2 ≥ 1)
        #expect(abs(result.solution[3] - 1.0) < 1e-6)  // x3 = 1
    }
}

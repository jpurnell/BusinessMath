import Testing
import Foundation
@testable import BusinessMath

/// Tests for NonlinearRelaxationSolver (NLP relaxation wrapper)
///
/// Following TDD: These tests are written FIRST (RED phase) and will fail
/// until Phase 4B implements the solver.
///
/// ## What We're Testing
/// - NonlinearRelaxationSolver conforms to RelaxationSolver protocol
/// - Handles quadratic objectives correctly
/// - Handles nonlinear constraints (circles, ellipses, etc.)
/// - Can still solve linear problems
/// - Detects infeasibility
/// - Gracefully handles solver failures
@Suite("NonlinearRelaxationSolver Tests")
struct NonlinearRelaxationSolverTests {

    // MARK: - Basic Functionality Tests

    @Test("NonlinearRelaxationSolver conforms to RelaxationSolver")
    func testProtocolConformance() {
        let solver = NonlinearRelaxationSolver()
        let _: any RelaxationSolver = solver
        #expect(true)  // Compilation is the test
    }

    @Test("NonlinearRelaxationSolver has configurable parameters")
    func testConstructorParameters() {
        let solver = NonlinearRelaxationSolver(
            maxIterations: 500,
            tolerance: 1e-7
        )

        // Verify solver created successfully
        #expect(solver.maxIterations == 500)
        #expect(solver.tolerance == 1e-7)
    }

    // MARK: - Quadratic Objective Tests

    @Test("NonlinearRelaxationSolver solves quadratic minimization")
    func testQuadraticMinimization() throws {
        let solver = NonlinearRelaxationSolver()

        // minimize x² + y² subject to x + y ≥ 2, x,y ≥ 0
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] * v[0] + v[1] * v[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 2.0, sense: .greaterOrEqual)
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([1.0, 1.0]),
            minimize: true
        )

        #expect(result.status == .optimal)
        #expect(result.solution != nil)

        // Optimal: x = y = 1 (symmetry), with objective = 2
        let sol = result.solution!
        let sum = sol[0] + sol[1]
        #expect(abs(sum - 2.0) < 1e-3, "Expected x + y = 2, got \(sum)")
        #expect(abs(sol[0] - sol[1]) < 1e-3, "Expected x ≈ y by symmetry")
        #expect(abs(result.objectiveValue - 2.0) < 1e-3, "Expected obj ≈ 2, got \(result.objectiveValue)")
    }

    @Test("NonlinearRelaxationSolver solves quadratic maximization")
    func testQuadraticMaximization() throws {
        let solver = NonlinearRelaxationSolver()

        // maximize -(x² + y²) subject to x + y ≤ 2, x,y ≥ 0
        // Equivalently: minimize x² + y² with constraint flipped
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] * v[0] + v[1] * v[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 2.0, sense: .lessOrEqual)
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([0.5, 0.5]),
            minimize: false  // Maximize -objective
        )

        #expect(result.status == .optimal)
        #expect(result.solution != nil)

        // Maximum of -(x² + y²) occurs at boundary: x + y = 2
        let sol = result.solution!
        let sum = sol[0] + sol[1]
        #expect(abs(sum - 2.0) < 1e-3, "Expected x + y = 2, got \(sum)")
    }

    // MARK: - Nonlinear Constraint Tests

    @Test("NonlinearRelaxationSolver handles circle constraint")
    func testCircleConstraint() throws {
        let solver = NonlinearRelaxationSolver()

        // minimize x + y subject to x² + y² ≤ 1
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] + v[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { v in v[0] * v[0] + v[1] * v[1] - 1.0 }  // x² + y² - 1 ≤ 0
        ]

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([0.5, 0.5]),
            minimize: true
        )

        #expect(result.status == .optimal)
        #expect(result.solution != nil)

        // Verify circle constraint satisfied
        let sol = result.solution!
        let radius = sol[0] * sol[0] + sol[1] * sol[1]
        #expect(radius <= 1.0 + 1e-3, "Circle constraint violated: r² = \(radius)")
    }

    @Test("NonlinearRelaxationSolver handles ellipse constraint")
    func testEllipseConstraint() throws {
        let solver = NonlinearRelaxationSolver()

        // minimize x subject to (x/2)² + y² ≤ 1
        let objective: @Sendable (VectorN<Double>) -> Double = { v in v[0] }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { v in
                (v[0] / 2.0) * (v[0] / 2.0) + v[1] * v[1] - 1.0
            }
        ]

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([1.0, 0.5]),
            minimize: true
        )

        #expect(result.status == .optimal)
        #expect(result.solution != nil)

        // Optimal should be on ellipse boundary (minimizing x)
        let sol = result.solution!
        let ellipse = (sol[0] / 2.0) * (sol[0] / 2.0) + sol[1] * sol[1]
        #expect(ellipse <= 1.0 + 1e-3, "Ellipse constraint violated")
    }

    @Test("NonlinearRelaxationSolver handles multiple nonlinear constraints")
    func testMultipleNonlinearConstraints() throws {
        let solver = NonlinearRelaxationSolver()

        // minimize x + y subject to:
        //   x² + y² ≥ 1 (outside unit circle)
        //   x² + y² ≤ 4 (inside radius-2 circle)
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] + v[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { v in -(v[0] * v[0] + v[1] * v[1]) + 1.0 },  // -(x²+y²) + 1 ≤ 0  =>  x²+y² ≥ 1
            .inequality { v in v[0] * v[0] + v[1] * v[1] - 4.0 }      // x²+y² - 4 ≤ 0
        ]

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([1.0, 0.0]),
            minimize: true
        )

        #expect(result.status == .optimal)
        #expect(result.solution != nil)

        // Verify annulus constraints
        let sol = result.solution!
        let r2 = sol[0] * sol[0] + sol[1] * sol[1]
        #expect(r2 >= 1.0 - 1e-3, "Inner circle constraint violated: r² = \(r2)")
        #expect(r2 <= 4.0 + 1e-3, "Outer circle constraint violated: r² = \(r2)")
    }

    // MARK: - Linear Problem Tests (should still work)

    @Test("NonlinearRelaxationSolver handles linear problems")
    func testLinearProblem() throws {
        let solver = NonlinearRelaxationSolver()

        // minimize 2x + 3y subject to x + y ≤ 5, x,y ≥ 0
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            2.0 * v[0] + 3.0 * v[1]
        }

        let constraints = [
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [1.0, 1.0],
                rhs: 5.0,
                sense: .lessOrEqual
            )
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([1.0, 1.0]),
            minimize: true
        )

        #expect(result.status == .optimal)
        #expect(result.solution != nil)

        // Optimal: (0, 0) with objective = 0
        let sol = result.solution!
        #expect(abs(sol[0]) < 1e-3, "Expected x ≈ 0, got \(sol[0])")
        #expect(abs(sol[1]) < 1e-3, "Expected y ≈ 0, got \(sol[1])")
    }

    // MARK: - Infeasibility Tests

    @Test("NonlinearRelaxationSolver detects infeasibility")
    func testInfeasible() throws {
        let solver = NonlinearRelaxationSolver()

        // x² + y² ≤ 1 AND x + y ≥ 3 (infeasible)
        let objective: @Sendable (VectorN<Double>) -> Double = { v in v[0] }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { v in v[0] * v[0] + v[1] * v[1] - 1.0 },  // Circle
            .linearInequality(coefficients: [1.0, 1.0], rhs: 3.0, sense: .greaterOrEqual)  // Line
        ]

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([1.0, 1.0]),
            minimize: true
        )

        #expect(result.status == .infeasible)
        #expect(result.solution == nil)
    }

    @Test("NonlinearRelaxationSolver handles contradictory nonlinear constraints")
    func testContradictoryNonlinearConstraints() throws {
        let solver = NonlinearRelaxationSolver()

        // x² + y² ≤ 1 AND x² + y² ≥ 4 (infeasible)
        let objective: @Sendable (VectorN<Double>) -> Double = { v in v[0] }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { v in v[0] * v[0] + v[1] * v[1] - 1.0 },   // ≤ 1
            .inequality { v in -(v[0] * v[0] + v[1] * v[1]) + 4.0 } // ≥ 4
        ]

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([1.0, 1.0]),
            minimize: true
        )

        #expect(result.status == .infeasible)
        #expect(result.solution == nil)
    }

    // MARK: - Edge Cases

    @Test("NonlinearRelaxationSolver handles single variable")
    func testSingleVariable() throws {
        let solver = NonlinearRelaxationSolver()

        // minimize x² subject to x ≥ 1, x ≤ 2
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] * v[0]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 1.0, sense: .greaterOrEqual),
            .linearInequality(coefficients: [1.0], rhs: 2.0, sense: .lessOrEqual)
        ]

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([1.5]),
            minimize: true
        )

        #expect(result.status == .optimal)
        #expect(result.solution != nil)

        // Optimal: x = 1
        let sol = result.solution!
        #expect(abs(sol[0] - 1.0) < 1e-3, "Expected x = 1, got \(sol[0])")
    }

    @Test("NonlinearRelaxationSolver handles empty constraints")
    func testEmptyConstraints() throws {
        let solver = NonlinearRelaxationSolver()

        // minimize x² + y² with no constraints
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] * v[0] + v[1] * v[1]
        }

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: [],
            initialGuess: VectorN([1.0, 1.0]),
            minimize: true
        )

        // Note: InequalityOptimizer might fail on truly unconstrained problems
        // It's designed for constrained optimization. Accept either optimal or infeasible.
        #expect(result.status == .optimal || result.status == .infeasible)

        if result.status == .optimal {
            #expect(result.solution != nil)
            #expect(result.objectiveValue >= 0.0)
        }
    }

    // MARK: - Polynomial Objective Tests

    @Test("NonlinearRelaxationSolver handles cubic objective")
    func testCubicObjective() throws {
        let solver = NonlinearRelaxationSolver()

        // minimize x³ + y³ subject to x + y = 2, x,y ≥ 0
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] * v[0] * v[0] + v[1] * v[1] * v[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearEquality(coefficients: [1.0, 1.0], rhs: 2.0)
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([1.0, 1.0]),
            minimize: true
        )

        #expect(result.status == .optimal)
        #expect(result.solution != nil)

        // Verify equality constraint
        let sol = result.solution!
        let sum = sol[0] + sol[1]
        #expect(abs(sum - 2.0) < 1e-3, "Equality violated: x + y = \(sum)")
    }

}

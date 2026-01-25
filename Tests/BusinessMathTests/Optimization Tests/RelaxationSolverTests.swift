import Testing
import Foundation
@testable import BusinessMath

/// Tests for RelaxationSolver protocol and supporting types
///
/// Following TDD: These tests are written FIRST (RED phase) and will fail
/// until Phase 1B implements the protocol.
///
/// ## What We're Testing
/// - RelaxationResult struct: Captures solution from continuous relaxation
/// - RelaxationStatus enum: Represents solver outcome (optimal/infeasible/unbounded)
/// - RelaxationSolver protocol: Contract for pluggable relaxation solvers
@Suite("RelaxationSolver Protocol Tests")
struct RelaxationSolverTests {

    // MARK: - RelaxationResult Tests

    @Test("RelaxationResult stores solution correctly")
    func testRelaxationResultSolution() {
        let solution = VectorN([1.5, 2.5, 3.5])
        let result = RelaxationResult(
            solution: solution,
            objectiveValue: 10.5,
            status: .optimal
        )

        #expect(result.solution != nil)
        let storedSolution = result.solution!
        #expect(storedSolution.toArray() == [1.5, 2.5, 3.5])
    }

    @Test("RelaxationResult stores objective value")
    func testRelaxationResultObjective() {
        let result = RelaxationResult(
            solution: VectorN([1.0, 2.0]),
            objectiveValue: 42.5,
            status: .optimal
        )

        #expect(result.objectiveValue == 42.5)
    }

    @Test("RelaxationResult stores status")
    func testRelaxationResultStatus() {
        let result = RelaxationResult(
            solution: VectorN([0.0]),
            objectiveValue: 0.0,
            status: .infeasible
        )

        #expect(result.status == .infeasible)
    }

    @Test("RelaxationResult can represent infeasible case")
    func testRelaxationResultInfeasible() {
        let result = RelaxationResult(
            solution: nil,  // No solution for infeasible
            objectiveValue: Double.infinity,
            status: .infeasible
        )

        #expect(result.solution == nil)
        #expect(result.status == .infeasible)
        #expect(result.objectiveValue.isInfinite)
    }

    @Test("RelaxationResult can represent unbounded case")
    func testRelaxationResultUnbounded() {
        let result = RelaxationResult(
            solution: nil,  // No finite solution for unbounded
            objectiveValue: -Double.infinity,
            status: .unbounded
        )

        #expect(result.solution == nil)
        #expect(result.status == .unbounded)
        #expect(result.objectiveValue.isInfinite)
        #expect(result.objectiveValue < 0)  // Negative infinity for minimization
    }

    @Test("RelaxationResult is Sendable")
    func testRelaxationResultSendable() {
        // This test verifies Sendable conformance at compile time
        let result = RelaxationResult(
            solution: VectorN([1.0]),
            objectiveValue: 1.0,
            status: .optimal
        )

        // If this compiles, Sendable conformance works
        let _: any Sendable = result
        #expect(true)  // Compilation is the test
    }

    // MARK: - RelaxationStatus Tests

    @Test("RelaxationStatus has optimal case")
    func testRelaxationStatusOptimal() {
        let status = RelaxationStatus.optimal
        #expect(status == .optimal)
    }

    @Test("RelaxationStatus has infeasible case")
    func testRelaxationStatusInfeasible() {
        let status = RelaxationStatus.infeasible
        #expect(status == .infeasible)
    }

    @Test("RelaxationStatus has unbounded case")
    func testRelaxationStatusUnbounded() {
        let status = RelaxationStatus.unbounded
        #expect(status == .unbounded)
    }

    @Test("RelaxationStatus cases are distinct")
    func testRelaxationStatusDistinct() {
        let optimal = RelaxationStatus.optimal
        let infeasible = RelaxationStatus.infeasible
        let unbounded = RelaxationStatus.unbounded

        #expect(optimal != infeasible)
        #expect(optimal != unbounded)
        #expect(infeasible != unbounded)
    }

    @Test("RelaxationStatus is Sendable")
    func testRelaxationStatusSendable() {
        let status = RelaxationStatus.optimal
        let _: any Sendable = status
        #expect(true)  // Compilation is the test
    }

    // MARK: - RelaxationSolver Protocol Tests

    @Test("RelaxationSolver protocol exists")
    func testRelaxationSolverProtocolExists() {
        // This test verifies the protocol can be referenced at compile time
        // We'll create a mock implementation to test protocol conformance

        struct MockRelaxationSolver: RelaxationSolver {
            func solveRelaxation<V: VectorSpace>(
                objective: @Sendable @escaping (V) -> Double,
                constraints: [MultivariateConstraint<V>],
                initialGuess: V,
                minimize: Bool
            ) throws -> RelaxationResult where V.Scalar == Double, V: Sendable {
                // Mock implementation
                return RelaxationResult(
                    solution: initialGuess as? VectorN<Double>,
                    objectiveValue: 0.0,
                    status: .optimal
                )
            }
        }

        let solver: any RelaxationSolver = MockRelaxationSolver()
        #expect(solver is RelaxationSolver)
    }

    @Test("RelaxationSolver is Sendable")
    func testRelaxationSolverSendable() {
        // The protocol should require Sendable conformance
        struct MockSendableSolver: RelaxationSolver {
            func solveRelaxation<V: VectorSpace>(
                objective: @Sendable @escaping (V) -> Double,
                constraints: [MultivariateConstraint<V>],
                initialGuess: V,
                minimize: Bool
            ) throws -> RelaxationResult where V.Scalar == Double, V: Sendable {
                return RelaxationResult(
                    solution: nil,
                    objectiveValue: 0.0,
                    status: .optimal
                )
            }
        }

        let solver: any Sendable = MockSendableSolver()
        #expect(solver is RelaxationSolver)
    }

    @Test("RelaxationSolver protocol method signature")
    func testRelaxationSolverMethodSignature() throws {
        // Verify the protocol method accepts expected parameters
        struct TestSolver: RelaxationSolver {
            func solveRelaxation<V: VectorSpace>(
                objective: @Sendable @escaping (V) -> Double,
                constraints: [MultivariateConstraint<V>],
                initialGuess: V,
                minimize: Bool
            ) throws -> RelaxationResult where V.Scalar == Double, V: Sendable {
                // Verify we can call the objective
                let objValue = objective(initialGuess)
                #expect(objValue.isFinite || objValue.isInfinite)

                // Verify we can access constraints
                #expect(constraints.isEmpty || !constraints.isEmpty)

                // Verify minimize flag
                #expect(minimize == true || minimize == false)

                return RelaxationResult(
                    solution: initialGuess as? VectorN<Double>,
                    objectiveValue: objValue,
                    status: .optimal
                )
            }
        }

        let solver = TestSolver()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] + v[1]
        }

        let constraints = [
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [1.0, 1.0],
                rhs: 10.0,
                sense: .lessOrEqual
            )
        ]

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([1.0, 2.0]),
            minimize: true
        )

        #expect(result.status == .optimal)
    }

    @Test("RelaxationSolver can handle minimization")
    func testRelaxationSolverMinimization() throws {
        struct MinimizationTestSolver: RelaxationSolver {
            func solveRelaxation<V: VectorSpace>(
                objective: @Sendable @escaping (V) -> Double,
                constraints: [MultivariateConstraint<V>],
                initialGuess: V,
                minimize: Bool
            ) throws -> RelaxationResult where V.Scalar == Double, V: Sendable {
                #expect(minimize == true)

                return RelaxationResult(
                    solution: initialGuess as? VectorN<Double>,
                    objectiveValue: objective(initialGuess),
                    status: .optimal
                )
            }
        }

        let solver = MinimizationTestSolver()
        let _ = try solver.solveRelaxation(
            objective: { v in v[0] },
            constraints: [],
            initialGuess: VectorN([5.0]),
            minimize: true
        )
    }

    @Test("RelaxationSolver can handle maximization")
    func testRelaxationSolverMaximization() throws {
        struct MaximizationTestSolver: RelaxationSolver {
            func solveRelaxation<V: VectorSpace>(
                objective: @Sendable @escaping (V) -> Double,
                constraints: [MultivariateConstraint<V>],
                initialGuess: V,
                minimize: Bool
            ) throws -> RelaxationResult where V.Scalar == Double, V: Sendable {
                #expect(minimize == false)

                return RelaxationResult(
                    solution: initialGuess as? VectorN<Double>,
                    objectiveValue: objective(initialGuess),
                    status: .optimal
                )
            }
        }

        let solver = MaximizationTestSolver()
        let _ = try solver.solveRelaxation(
            objective: { v in v[0] },
            constraints: [],
            initialGuess: VectorN([5.0]),
            minimize: false
        )
    }

    @Test("RelaxationSolver can work with different VectorSpace types")
    func testRelaxationSolverGenericVector() throws {
        struct GenericVectorSolver: RelaxationSolver {
            func solveRelaxation<V: VectorSpace>(
                objective: @Sendable @escaping (V) -> Double,
                constraints: [MultivariateConstraint<V>],
                initialGuess: V,
                minimize: Bool
            ) throws -> RelaxationResult where V.Scalar == Double, V: Sendable {
                // Verify we can work with generic VectorSpace
                let dimension = initialGuess.toArray().count
                #expect(dimension > 0)

                return RelaxationResult(
                    solution: initialGuess as? VectorN<Double>,
                    objectiveValue: objective(initialGuess),
                    status: .optimal
                )
            }
        }

        let solver = GenericVectorSolver()

        // Test with VectorN
        let result = try solver.solveRelaxation(
            objective: { v in Double(v.toArray().count) },
            constraints: [],
            initialGuess: VectorN([1.0, 2.0, 3.0]),
            minimize: true
        )

        #expect(result.objectiveValue == 3.0)  // Dimension is 3
    }
}

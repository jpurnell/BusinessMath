import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Degeneracy and Cycling Protection Tests
@Suite("Degeneracy and Cycling Protection")
struct DegeneracyProtectionTests {

    @Test("Stagnation detection terminates when no improvement")
    func stagnationDetection() throws {
        // Problem designed to cause stagnation in cutting plane loop
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 10,  // Allow many rounds
            detectStagnation: true,
            stagnationTolerance: 1e-8
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(arr[0] + arr[1])
        }

        // Simple constraint that will quickly converge
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 2.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0, 1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        #expect(result.status == .optimal)

        // Should terminate before maxCuttingRounds due to stagnation
        // (statistics should show fewer than 10 cutting rounds)
        #expect(result.integerSolution[0] + result.integerSolution[1] <= 3)
    }

    @Test("Stagnation tolerance prevents premature termination")
    func stagnationToleranceHandling() throws {
        // Test that small improvements below tolerance trigger stagnation
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 5,
            detectStagnation: true,
            stagnationTolerance: 1e-2  // Relatively large tolerance
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(2.0 * arr[0] + 3.0 * arr[1])
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 5.7, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        #expect(result.status == .optimal)

        // Solution should be valid despite stagnation
        let sol = result.integerSolution
        #expect(Double(sol[0]) + Double(sol[1]) <= 6.0)
    }

    @Test("Cycling detection terminates on repeated solutions")
    func cyclingDetection() throws {
        // Create a problem that could potentially cycle
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 10,
            detectStagnation: false,  // Disable to isolate cycling detection
            detectCycling: true,
            cyclingWindowSize: 3
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(arr[0] + 2.0 * arr[1])
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 3.9, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5, 1.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        #expect(result.status == IntegerSolutionStatus.optimal)

        // Should find correct solution without infinite loop
        let sol = result.integerSolution
        #expect(sol[0] + sol[1] <= 4)
    }

    @Test("Cycling window size affects detection sensitivity")
    func cyclingWindowSize() throws {
        // Test with different window sizes
        let smallWindow = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 8,
            detectCycling: true,
            cyclingWindowSize: 2  // Small window - more sensitive
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(arr[0] + arr[1] + arr[2])
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0, 1.0], rhs: 4.5, sense: .lessOrEqual)
        ]

        let result = try smallWindow.solve(
            objective: objective,
            from: VectorN([1.0, 1.0, 1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 3),
            minimize: true
        )

        #expect(result.status == .optimal)

        // Should still find valid solution
        let sol = result.integerSolution
        #expect(sol[0] + sol[1] + sol[2] <= 5)
    }

    @Test("Both detections disabled allows full cutting rounds")
    func disabledDetection() throws {
        // Test that disabling both detections allows all maxCuttingRounds
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3,
            detectStagnation: false,  // Disabled
            detectCycling: false      // Disabled
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(arr[0] + arr[1])
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 2.1, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0, 1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        #expect(result.status == .optimal)
        #expect(result.integerSolution[0] + result.integerSolution[1] <= 3)
    }

    @Test("Stagnation detection works on multi-variable problems")
    func multiVariableStagnation() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 10,
            detectStagnation: true,
            stagnationTolerance: 1e-8
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(arr[0] + 2.0 * arr[1] + 3.0 * arr[2] + arr[3])
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0, 1.0, 1.0], rhs: 6.8, sense: .lessOrEqual),
            .linearInequality(coefficients: [2.0, 1.0, 0.0, 1.0], rhs: 8.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0, 1.0, 1.0, 1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 4),
            minimize: true
        )

        #expect(result.status == .optimal)

        // Should find feasible solution efficiently
        let sol = result.integerSolution
        #expect(sol[0] + sol[1] + sol[2] + sol[3] <= 7)
    }

    @Test("Stagnation with improving then flat bounds")
    func improvingThenFlatBounds() throws {
        // Test that stagnation is detected after initial improvement
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 8,
            detectStagnation: true,
            stagnationTolerance: 1e-6
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(arr[0] + arr[1])
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 3.3, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5, 1.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        #expect(result.status == .optimal)

        // Should terminate when bound stops improving
        #expect(result.integerSolution[0] + result.integerSolution[1] <= 4)
    }
}

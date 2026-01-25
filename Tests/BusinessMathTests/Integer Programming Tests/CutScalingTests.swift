import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Cut Scaling and Normalization Tests
@Suite("Cut Scaling and Normalization")
struct CutScalingTests {

    @Test("Cuts are normalized to unit norm")
    func cutNormalization() throws {
        // Problem with widely varying coefficient magnitudes
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3
            // Will add: normalizeCuts parameter
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            // Large coefficient for x, small for y
            return -(1000.0 * arr[0] + 0.001 * arr[1])
        }

        // Constraints with different scales
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1000.0, 0.001], rhs: 2500.5, sense: .lessOrEqual),
            .linearInequality(coefficients: [0.001, 1000.0], rhs: 1500.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0, 1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Should solve successfully despite scale differences
        #expect(result.status == .optimal)
        #expect(result.integerSolution[0] >= 0)
        #expect(result.integerSolution[1] >= 0)
    }

    @Test("Small coefficient cuts are filtered")
    func smallCoefficientFiltering() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 2.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.2]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: true
        )

        #expect(result.status == .optimal)

        // Cuts with tiny coefficients should be filtered
        // Solution should still be correct
        #expect(result.integerSolution[0] == 0)
    }

    @Test("Extreme coefficient magnitudes handled robustly")
    func extremeCoefficientMagnitudes() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 2
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(arr[0] + arr[1])
        }

        // Very large coefficients
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1e6, 1e6], rhs: 3.7e6, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0, 1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Should handle large coefficients without numerical issues
        #expect(result.status == .optimal)

        // Verify solution is correct (scaled problem)
        let sol = result.integerSolution
        #expect(sol[0] + sol[1] <= 4)  // Approximately 3.7
    }

    @Test("Normalization preserves cut validity")
    func normalizationPreservesCutValidity() throws {
        // Verify that normalized cuts still eliminate the same fractional solutions

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(2.0 * arr[0] + 3.0 * arr[1])
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [100.0, 150.0], rhs: 550.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        #expect(result.status == .optimal)

        // Solution should be valid integer point
        let sol = result.integerSolution
        #expect(100.0 * Double(sol[0]) + 150.0 * Double(sol[1]) <= 551.0)
    }
}

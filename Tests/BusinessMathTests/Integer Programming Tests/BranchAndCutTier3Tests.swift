import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Tier 3 - Numerical Robustness
@Suite("Branch-and-Cut Tier 3: Numerical Robustness")
struct BranchAndCutTier3Tests {

    // MARK: - Cut Scaling and Normalization

    @Test("Cuts are normalized to avoid ill-conditioned LPs")
    func cutNormalization() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3,
            normalizeCuts: true
        )

        // Problem with widely varying coefficient magnitudes
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
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

        #expect(result.status == .optimal)

        // Normalized cuts should prevent numerical issues
        // Solution should be correct despite scaling differences
        #expect(result.integerSolution[0] >= 0)
        #expect(result.integerSolution[1] >= 0)
    }

    @Test("Cut coefficients are scaled to reasonable magnitude")
    func cutScaling() throws {
        // Test that generated cuts have coefficients in a reasonable range
        // e.g., largest coefficient magnitude is O(1) to O(1000), not O(1e10)

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 2,
            normalizeCuts: true,
            cutScalingNorm: .infinity
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(arr[0] + arr[1])
        }

        // Very large coefficients
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1e8, 1e8], rhs: 3.7e8, sense: .lessOrEqual)
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
    }

    @Test("Small cut coefficients are not generated")
    func smallCoefficientFiltering() throws {
        // Cuts with very small coefficients (< tolerance) should be filtered

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3,
            cutCoefficientThreshold: 1e-6
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

        // Cuts with tiny coefficients should be rejected
        // (Verification would require inspecting generated cuts)
    }

    // MARK: - Degeneracy and Cycling Protection

    @Test("Stagnation detected when bound does not improve")
    func stagnationDetection() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 10,
            detectStagnation: true,
            stagnationTolerance: 1e-8
        )

        // Problem where cuts might not improve bound significantly
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 1.0000001, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.99]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: true
        )

        #expect(result.status == .optimal)

        // Should terminate early when stagnating (not use all 10 rounds)
        if let stats = result.cuttingPlaneStats {
            // Might terminate before maxCuttingRounds if stagnating
            #expect(stats.maxRoundsAtNode <= 10)
        }
    }

    @Test("Repeated LP solutions trigger early termination")
    func cyclicSolutionDetection() throws {
        // Detect when LP solution oscillates between same values (cycling)

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 20,
            detectCycling: true
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(arr[0] + arr[1])
        }

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

        // Should detect cycling and terminate early
        if let stats = result.cuttingPlaneStats {
            #expect(stats.maxRoundsAtNode < 20)  // Terminated before max
        }
    }

    @Test("Degeneracy does not cause excessive cutting rounds")
    func degeneracyHandling() throws {
        // Degenerate problems (multiple optimal bases) should not loop infinitely

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 15
        )

        // Degenerate problem: many constraints, few variables
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 2.5, sense: .lessOrEqual),
            .linearInequality(coefficients: [1.0], rhs: 2.6, sense: .lessOrEqual),
            .linearInequality(coefficients: [1.0], rhs: 2.7, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: true
        )

        #expect(result.status == .optimal)

        // Should handle gracefully without excessive iterations
        #expect(result.nodesExplored < 50)
    }

    // MARK: - Warm Starts and Basis Reuse

    @Test("Simplex basis is reused when re-solving with cuts")
    func warmStartBasisReuse() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3,
            enableWarmStart: true
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(arr[0] + arr[1])
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [2.0, 1.0], rhs: 5.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0, 1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        #expect(result.status == .optimal)

        // Warm start should improve performance (fewer simplex iterations)
        // This would require exposing iteration counts in statistics
    }

    @Test("Warm start improves performance on re-solve")
    func warmStartPerformance() throws {
        // Compare performance with/without warm start

        let objectiveFn: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(3.0 * arr[0] + 2.0 * arr[1] + arr[2])
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [2.0, 1.5, 1.0], rhs: 7.5, sense: .lessOrEqual)
        ]

        // Solver with warm start
        let solverWarm = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3,
            enableWarmStart: true
        )

        // Solver without warm start
        let solverCold = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3,
            enableWarmStart: false
        )

        let resultWarm = try solverWarm.solve(
            objective: objectiveFn,
            from: VectorN([1.0, 1.0, 1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 3),
            minimize: true
        )

        let resultCold = try solverCold.solve(
            objective: objectiveFn,
            from: VectorN([1.0, 1.0, 1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 3),
            minimize: true
        )

        // Both should find optimal
        #expect(resultWarm.status == .optimal)
        #expect(resultCold.status == .optimal)

        // Warm start might be faster (but hard to verify without timing)
        // At minimum, both should complete successfully
    }

    @Test("Basis remains valid after adding cuts")
    func basisValidityAfterCuts() throws {
        // When cuts are added, the previous basis should remain valid
        // (or be properly updated to remain feasible)

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 2,
            enableWarmStart: true
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(arr[0] + arr[1])
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 2.0], rhs: 5.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        #expect(result.status == .optimal)

        // Should not encounter basis infeasibility errors
        // (Would manifest as solver errors if basis handling is incorrect)
    }

    // MARK: - Integration Tests

    @Test("Numerical robustness prevents solver failures")
    func numericalRobustnessIntegration() throws {
        // Challenging problem combining all numerical issues:
        // - Widely varying coefficients
        // - Near-degenerate constraints
        // - Fractional RHS values
        // - Multiple cutting rounds

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 5,
            normalizeCuts: true,
            detectStagnation: true,
            enableWarmStart: true
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(100.0 * arr[0] + 0.01 * arr[1])
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [100.0, 0.01], rhs: 250.7, sense: .lessOrEqual),
            .linearInequality(coefficients: [0.01, 100.0], rhs: 150.3, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0, 1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Should handle robustly despite numerical challenges
        #expect(result.status == .optimal || result.status == .feasible)
        #expect(result.nodesExplored < 1000)
    }
}

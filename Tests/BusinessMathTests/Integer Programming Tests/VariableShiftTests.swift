import Testing
import Foundation
@testable import BusinessMath

/// Tests for variable shifting to handle negative bounds
///
/// These tests verify:
/// - Detection of negative lower bounds from constraints
/// - Correct transformation of variables (x → y = x - shift)
/// - Correct transformation of objectives and constraints
/// - Correct back-transformation of solutions
///
/// Following TDD: These tests are written FIRST and will fail until
/// Phase D2 implements the variable shifting logic.
@Suite("Variable Shift Tests")
struct VariableShiftTests {

    // MARK: - Shift Detection Tests

    @Test("No shift needed for positive bounds")
    func testPositiveBounds() throws {
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 0.0, sense: .greaterOrEqual),  // x ≥ 0
            .linearInequality(coefficients: [1.0], rhs: 10.0, sense: .lessOrEqual)    // x ≤ 10
        ]

        let shift = try extractVariableShift(from: constraints, dimension: 1)

        #expect(!shift.needsShift, "Should not need shift for x ∈ [0, 10]")
        #expect(shift.shifts == [0.0], "Shift should be zero")
    }

    @Test("Shift for negative lower bound")
    func testNegativeLowerBound() throws {
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: -3.0, sense: .greaterOrEqual), // x ≥ -3
            .linearInequality(coefficients: [1.0], rhs: 5.0, sense: .lessOrEqual)      // x ≤ 5
        ]

        let shift = try extractVariableShift(from: constraints, dimension: 1)

        #expect(shift.needsShift, "Should need shift for x ≥ -3")
        #expect(shift.shifts == [-3.0], "Shift should be -3")
    }

    @Test("Multiple variables with mixed bounds")
    func testMixedBounds() throws {
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            // x ≥ 0 (no shift)
            .linearInequality(coefficients: [1.0, 0.0], rhs: 0.0, sense: .greaterOrEqual),
            // y ≥ -5 (shift by -5)
            .linearInequality(coefficients: [0.0, 1.0], rhs: -5.0, sense: .greaterOrEqual),
        ]

        let shift = try extractVariableShift(from: constraints, dimension: 2)

        #expect(shift.needsShift, "Should need shift for y ≥ -5")
        #expect(shift.shifts == [0.0, -5.0], "First variable no shift, second shifted by -5")
    }

    @Test("All variables have negative bounds")
    func testAllNegativeBounds() throws {
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            // x ≥ -10
            .linearInequality(coefficients: [1.0, 0.0], rhs: -10.0, sense: .greaterOrEqual),
            // y ≥ -20
            .linearInequality(coefficients: [0.0, 1.0], rhs: -20.0, sense: .greaterOrEqual),
        ]

        let shift = try extractVariableShift(from: constraints, dimension: 2)

        #expect(shift.needsShift)
        #expect(shift.shifts == [-10.0, -20.0])
    }

    @Test("No explicit lower bound defaults to zero")
    func testNoExplicitBound() throws {
        // No lower bound constraints provided
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 10.0, sense: .lessOrEqual)  // x ≤ 10
        ]

        let shift = try extractVariableShift(from: constraints, dimension: 1)

        #expect(!shift.needsShift, "Should assume x ≥ 0 when no lower bound given")
        #expect(shift.shifts == [0.0])
    }

    // MARK: - Point Transformation Tests

    @Test("Shift point forward")
    func testShiftPointForward() throws {
        // x ∈ [-3, 5]  →  y ∈ [0, 8] where y = x - (-3) = x + 3
        let shift = VariableShift(shifts: [-3.0], needsShift: true)

        let original = VectorN([-3.0])  // x = -3 (at lower bound)
        let shifted = shift.shiftPoint(original)

        #expect(shifted.toArray() == [0.0], "x = -3 should shift to y = 0")
    }

    @Test("Shift point backward")
    func testShiftPointBackward() throws {
        // y ∈ [0, 8]  →  x ∈ [-3, 5] where x = y + (-3) = y - 3
        let shift = VariableShift(shifts: [-3.0], needsShift: true)

        let shifted = VectorN([0.0])  // y = 0
        let original = shift.unshiftPoint(shifted)

        #expect(original.toArray() == [-3.0], "y = 0 should unshift to x = -3")
    }

    @Test("Round-trip transformation")
    func testRoundTrip() throws {
        let shift = VariableShift(shifts: [-3.0, -5.0], needsShift: true)

        let original = VectorN([2.0, -1.0])
        let shifted = shift.shiftPoint(original)
        let recovered = shift.unshiftPoint(shifted)

        let originalArray = original.toArray()
        let recoveredArray = recovered.toArray()

        for i in 0..<2 {
            #expect(abs(originalArray[i] - recoveredArray[i]) < 1e-10,
                    "Round-trip should recover original: got \(recoveredArray[i]), expected \(originalArray[i])")
        }
    }

    @Test("Multi-variable shift forward")
    func testMultiVariableShiftForward() throws {
        // x ∈ [-10, 0], y ∈ [-20, 0]  →  x' ∈ [0, 10], y' ∈ [0, 20]
        let shift = VariableShift(shifts: [-10.0, -20.0], needsShift: true)

        let original = VectorN([-10.0, -20.0])  // At lower bounds
        let shifted = shift.shiftPoint(original)

        #expect(shifted.toArray() == [0.0, 0.0], "Should shift to origin")
    }

    // MARK: - Objective Transformation Tests

    @Test("Transform linear objective coefficients")
    func testTransformObjective() throws {
        // Original: minimize 2x + 3y where x ≥ -5, y ≥ 0
        // Shifted: minimize 2(x' - 5) + 3y' = 2x' + 3y' - 10
        //   (constant term changes but not tested by solver)

        let shift = VariableShift(shifts: [-5.0, 0.0], needsShift: true)
        let originalCoeffs = [2.0, 3.0]

        let transformedCoeffs = shift.transformObjectiveCoefficients(originalCoeffs)

        // Coefficients themselves don't change for linear objectives
        #expect(transformedCoeffs == [2.0, 3.0],
                "Linear objective coefficients unchanged by shift")
    }

    // MARK: - Constraint Transformation Tests

    @Test("Transform constraint: x ≥ -3")
    func testTransformLowerBoundConstraint() throws {
        // Original: x ≥ -3
        // Shifted: x' ≥ 0 (where x' = x + 3)

        let shift = VariableShift(shifts: [-3.0], needsShift: true)
        let constraint = MultivariateConstraint<VectorN<Double>>.linearInequality(
            coefficients: [1.0],
            rhs: -3.0,
            sense: .greaterOrEqual
        )

        let transformed = try shift.transformConstraint(constraint)
        let canonical = transformed.toCanonicalForm()

        // x' ≥ 0  →  -x' ≤ 0
        #expect(canonical.coefficients == [-1.0])
        #expect(canonical.constant == 0.0)
    }

    @Test("Transform constraint: x ≤ 5 with shift")
    func testTransformUpperBoundWithShift() throws {
        // Original: x ≤ 5 where x ≥ -3
        // x' = x + 3, so x ≤ 5  →  x' - 3 ≤ 5  →  x' ≤ 8

        let shift = VariableShift(shifts: [-3.0], needsShift: true)
        let constraint = MultivariateConstraint<VectorN<Double>>.linearInequality(
            coefficients: [1.0],
            rhs: 5.0,
            sense: .lessOrEqual
        )

        let transformed = try shift.transformConstraint(constraint)
        let canonical = transformed.toCanonicalForm()

        // x' ≤ 8  →  x' - 8 ≤ 0
        #expect(canonical.coefficients == [1.0])
        #expect(abs(canonical.constant - (-8.0)) < 1e-10,
                "Expected -8.0, got \(canonical.constant)")
    }

    @Test("Transform multi-variable constraint")
    func testTransformMultiVariableConstraint() throws {
        // Original: 2x + 3y ≤ 10 where x ≥ -5, y ≥ 0
        // Shifted: 2(x' - 5) + 3y' ≤ 10
        //         2x' + 3y' ≤ 20

        let shift = VariableShift(shifts: [-5.0, 0.0], needsShift: true)
        let constraint = MultivariateConstraint<VectorN<Double>>.linearInequality(
            coefficients: [2.0, 3.0],
            rhs: 10.0,
            sense: .lessOrEqual
        )

        let transformed = try shift.transformConstraint(constraint)
        let canonical = transformed.toCanonicalForm()

        // 2x' + 3y' ≤ 20  →  2x' + 3y' - 20 ≤ 0
        #expect(canonical.coefficients == [2.0, 3.0])
        #expect(abs(canonical.constant - (-20.0)) < 1e-10)
    }

    // MARK: - Edge Cases

    @Test("Zero shift is identity")
    func testZeroShiftIsIdentity() throws {
        let shift = VariableShift(shifts: [0.0, 0.0], needsShift: false)

        let point = VectorN([5.0, 7.0])
        let shifted = shift.shiftPoint(point)
        let unshifted = shift.unshiftPoint(point)

        #expect(shifted.toArray() == [5.0, 7.0])
        #expect(unshifted.toArray() == [5.0, 7.0])
    }

    @Test("Large negative bounds")
    func testLargeNegativeBounds() throws {
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: -1000.0, sense: .greaterOrEqual)
        ]

        let shift = try extractVariableShift(from: constraints, dimension: 1)

        #expect(shift.shifts == [-1000.0])

        let original = VectorN([-1000.0])
        let shifted = shift.shiftPoint(original)
        #expect(shifted.toArray() == [0.0])
    }

    @Test("Fractional negative bounds")
    func testFractionalBounds() throws {
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: -2.5, sense: .greaterOrEqual)
        ]

        let shift = try extractVariableShift(from: constraints, dimension: 1)

        #expect(shift.shifts == [-2.5])
    }

    // MARK: - Solution Verification Tests

    @Test("Shifted solution satisfies original constraints")
    func testShiftedSolutionSatisfiesOriginal() throws {
        // Original: minimize x where x ≥ -3, x ≤ 5
        // Optimal: x = -3
        // Shifted: minimize x' where x' ≥ 0, x' ≤ 8
        // Optimal: x' = 0  →  x = -3

        let shift = VariableShift(shifts: [-3.0], needsShift: true)

        let shiftedSolution = VectorN([0.0])  // x' = 0
        let originalSolution = shift.unshiftPoint(shiftedSolution)

        #expect(originalSolution.toArray()[0] == -3.0)

        // Verify satisfies original constraints
        #expect(originalSolution.toArray()[0] >= -3.0)
        #expect(originalSolution.toArray()[0] <= 5.0)
    }

    @Test("Interior solution transforms correctly")
    func testInteriorSolutionTransform() throws {
        // x ∈ [-3, 5], optimal x = 2
        // Shifted: x' ∈ [0, 8], optimal x' = 5

        let shift = VariableShift(shifts: [-3.0], needsShift: true)

        let shiftedSolution = VectorN([5.0])  // x' = 5
        let originalSolution = shift.unshiftPoint(shiftedSolution)

        #expect(originalSolution.toArray()[0] == 2.0)
    }
}

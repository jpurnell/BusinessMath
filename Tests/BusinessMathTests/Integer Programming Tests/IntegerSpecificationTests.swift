import Testing
import Foundation
@testable import BusinessMath

@Suite("Integer Specification Tests")
struct IntegerSpecificationTests {

    @Test("Integer feasibility checking - all integer")
    func testIntegerFeasibilityAllInteger() {
        let spec = IntegerProgramSpecification(
            integerVariables: Set([0, 1, 2])
        )

        // Integer solution should be feasible
        let integerSolution = VectorN([1.0, 2.0, 3.0])
        #expect(spec.isIntegerFeasible(integerSolution))

        // Fractional solution should not be feasible
        let fractionalSolution = VectorN([1.5, 2.0, 3.0])
        #expect(!spec.isIntegerFeasible(fractionalSolution))

        // Solution close to integer (within tolerance) should be feasible
        let almostInteger = VectorN([1.0000001, 2.0, 3.0])
        #expect(spec.isIntegerFeasible(almostInteger))
    }

    @Test("Binary feasibility checking")
    func testBinaryFeasibility() {
        let spec = IntegerProgramSpecification(
            binaryVariables: Set([0, 1, 2])
        )

        // Binary solution should be feasible
        let binarySolution = VectorN([0.0, 1.0, 1.0])
        #expect(spec.isIntegerFeasible(binarySolution))

        // Fractional solution should not be feasible
        let fractionalSolution = VectorN([0.5, 1.0, 0.0])
        #expect(!spec.isIntegerFeasible(fractionalSolution))

        // Integer but not binary should not be feasible
        let nonBinary = VectorN([2.0, 1.0, 0.0])
        #expect(!spec.isIntegerFeasible(nonBinary))
    }

    @Test("Rounding preserves non-integer variables")
    func testRoundingPreservesNonInteger() {
        // Only variable 1 is integer-constrained
        let spec = IntegerProgramSpecification(
            integerVariables: Set([1])
        )

        let solution = VectorN([1.7, 2.3, 3.9])
        let rounded = spec.rounded(solution)

        // Variable 0 and 2 should be unchanged
        #expect(rounded.toArray()[0] == 1.7)
        // Variable 1 should be rounded
        #expect(rounded.toArray()[1] == 2.0)
        // Variable 2 should be unchanged
        #expect(rounded.toArray()[2] == 3.9)
    }

    @Test("Most fractional variable selection")
    func testMostFractionalVariable() {
        let spec = IntegerProgramSpecification(
            integerVariables: Set([0, 1, 2, 3])
        )

        // Variable 2 is closest to 0.5 (most fractional)
        let solution = VectorN([1.1, 2.9, 3.5, 4.2])
        let mostFractional = spec.mostFractionalVariable(solution)
        #expect(mostFractional == 2)

        // All integer - should return nil
        let integerSolution = VectorN([1.0, 2.0, 3.0, 4.0])
        let noFractional = spec.mostFractionalVariable(integerSolution)
        #expect(noFractional == nil)

        // Close to integer (within tolerance) - should return nil
        let almostInteger = VectorN([1.0000001, 2.0, 3.0, 4.0])
        let noSignificantFractional = spec.mostFractionalVariable(almostInteger)
        #expect(noSignificantFractional == nil)
    }

    @Test("SOS1 constraint checking")
    func testSOS1Constraints() {
        // Variables 0, 1, 2 form SOS1 set (at most one can be nonzero)
        let spec = IntegerProgramSpecification(
            sosType1: [[0, 1, 2]]
        )

        // Only one nonzero - feasible
        let oneNonzero = VectorN([1.0, 0.0, 0.0, 5.0])
        #expect(spec.isIntegerFeasible(oneNonzero))

        // All zero - feasible
        let allZero = VectorN([0.0, 0.0, 0.0, 5.0])
        #expect(spec.isIntegerFeasible(allZero))

        // Two nonzero - infeasible
        let twoNonzero = VectorN([1.0, 2.0, 0.0, 5.0])
        #expect(!spec.isIntegerFeasible(twoNonzero))

        // Three nonzero - infeasible
        let threeNonzero = VectorN([1.0, 2.0, 3.0, 5.0])
        #expect(!spec.isIntegerFeasible(threeNonzero))
    }

    @Test("SOS2 constraint checking")
    func testSOS2Constraints() {
        // Variables 0, 1, 2, 3 form SOS2 set (at most two adjacent can be nonzero)
        let spec = IntegerProgramSpecification(
            sosType2: [[0, 1, 2, 3]]
        )

        // Two adjacent nonzero - feasible
        let adjacentNonzero = VectorN([0.0, 1.0, 2.0, 0.0])
        #expect(spec.isIntegerFeasible(adjacentNonzero))

        // One nonzero - feasible
        let oneNonzero = VectorN([0.0, 1.0, 0.0, 0.0])
        #expect(spec.isIntegerFeasible(oneNonzero))

        // All zero - feasible
        let allZero = VectorN([0.0, 0.0, 0.0, 0.0])
        #expect(spec.isIntegerFeasible(allZero))

        // Two non-adjacent nonzero - infeasible
        let nonAdjacent = VectorN([1.0, 0.0, 2.0, 0.0])
        #expect(!spec.isIntegerFeasible(nonAdjacent))

        // Three nonzero - infeasible
        let threeNonzero = VectorN([1.0, 2.0, 3.0, 0.0])
        #expect(!spec.isIntegerFeasible(threeNonzero))
    }

    @Test("Convenience initializers")
    func testConvenienceInitializers() {
        // All binary
        let allBinary = IntegerProgramSpecification.allBinary(dimension: 5)
        #expect(allBinary.binaryVariables.count == 5)
        #expect(allBinary.integerVariables.isEmpty)
        #expect(allBinary.binaryVariables.contains(0))
        #expect(allBinary.binaryVariables.contains(4))

        // All integer
        let allInteger = IntegerProgramSpecification.allInteger(dimension: 3)
        #expect(allInteger.integerVariables.count == 3)
        #expect(allInteger.binaryVariables.isEmpty)
        #expect(allInteger.integerVariables.contains(0))
        #expect(allInteger.integerVariables.contains(2))
    }

    @Test("Mixed integer and binary variables")
    func testMixedIntegerBinary() {
        let spec = IntegerProgramSpecification(
            integerVariables: Set([0, 1]),
            binaryVariables: Set([2, 3])
        )

        // Check all integer variables is union
        #expect(spec.allIntegerVariables.count == 4)
        #expect(spec.allIntegerVariables.contains(0))
        #expect(spec.allIntegerVariables.contains(1))
        #expect(spec.allIntegerVariables.contains(2))
        #expect(spec.allIntegerVariables.contains(3))

        // Valid solution
        let valid = VectorN([5.0, 10.0, 0.0, 1.0])
        #expect(spec.isIntegerFeasible(valid))

        // Binary variable with value 2 - invalid
        let invalidBinary = VectorN([5.0, 10.0, 2.0, 1.0])
        #expect(!spec.isIntegerFeasible(invalidBinary))

        // Fractional integer variable - invalid
        let fractionalInteger = VectorN([5.5, 10.0, 0.0, 1.0])
        #expect(!spec.isIntegerFeasible(fractionalInteger))
    }
}

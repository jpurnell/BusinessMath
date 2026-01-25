import Testing
import Foundation
@testable import BusinessMath

/// Tests for enhanced linear constraint API with natural form
///
/// These tests verify:
/// - Natural constraint specification (x ≥ 0 written as "x ≥ 0", not "-x ≤ 0")
/// - Correct conversion to canonical form g(x) ≤ 0
/// - Support for all three constraint senses (.lessOrEqual, .greaterOrEqual, .equal)
/// - Factory methods for common patterns (budget, non-negativity, box constraints)
///
/// Following TDD: These tests are written FIRST and will fail until
/// Phase C2 implements the enhanced constraint API.
@Suite("Linear Constraint Tests")
struct LinearConstraintTests {

    // MARK: - Natural Form Tests

    @Test("Natural form: x ≥ 0")
    func testNonNegativityNaturalForm() throws {
        // User writes: x ≥ 0 (natural form)
        let constraint = MultivariateConstraint<VectorN<Double>>.linearInequality(
            coefficients: [1.0],  // x (not -x!)
            rhs: 0.0,
            sense: .greaterOrEqual
        )

        // Check that it converts correctly to canonical form g(x) ≤ 0
        let canonical = constraint.toCanonicalForm()

        // x ≥ 0  →  -x + 0 ≤ 0  →  -x ≤ 0
        // So: coefficients = [-1.0], constant = 0.0
        #expect(canonical.coefficients == [-1.0], "Expected [-1.0], got \(canonical.coefficients)")
        #expect(canonical.constant == 0.0, "Expected 0.0, got \(canonical.constant)")
        #expect(canonical.isEquality == false, "Should be inequality")
    }

    @Test("Natural form: x ≤ 5")
    func testUpperBoundNaturalForm() throws {
        // User writes: x ≤ 5 (natural form)
        let constraint = MultivariateConstraint<VectorN<Double>>.linearInequality(
            coefficients: [1.0],
            rhs: 5.0,
            sense: .lessOrEqual
        )

        let canonical = constraint.toCanonicalForm()

        // x ≤ 5  →  x - 5 ≤ 0
        // So: coefficients = [1.0], constant = -5.0
        #expect(canonical.coefficients == [1.0], "Expected [1.0], got \(canonical.coefficients)")
        #expect(canonical.constant == -5.0, "Expected -5.0, got \(canonical.constant)")
        #expect(canonical.isEquality == false)
    }

    @Test("Natural form: x = 3")
    func testEqualityNaturalForm() throws {
        // User writes: x = 3 (natural form)
        let constraint = MultivariateConstraint<VectorN<Double>>.linearEquality(
            coefficients: [1.0],
            rhs: 3.0
        )

        let canonical = constraint.toCanonicalForm()

        // x = 3  →  x - 3 = 0
        // So: coefficients = [1.0], constant = -3.0
        #expect(canonical.coefficients == [1.0])
        #expect(canonical.constant == -3.0)
        #expect(canonical.isEquality == true, "Should be equality")
    }

    // MARK: - Multi-Variable Constraints

    @Test("Budget constraint: x + y ≤ 10")
    func testBudgetConstraint() throws {
        let constraint = MultivariateConstraint<VectorN<Double>>.linearInequality(
            coefficients: [1.0, 1.0],  // x + y
            rhs: 10.0,
            sense: .lessOrEqual
        )

        let canonical = constraint.toCanonicalForm()

        // x + y ≤ 10  →  x + y - 10 ≤ 0
        #expect(canonical.coefficients == [1.0, 1.0])
        #expect(canonical.constant == -10.0)
    }

    @Test("Production constraint: 2x + 3y ≥ 100")
    func testProductionConstraint() throws {
        let constraint = MultivariateConstraint<VectorN<Double>>.linearInequality(
            coefficients: [2.0, 3.0],  // 2x + 3y
            rhs: 100.0,
            sense: .greaterOrEqual
        )

        let canonical = constraint.toCanonicalForm()

        // 2x + 3y ≥ 100  →  -2x - 3y + 100 ≤ 0
        #expect(canonical.coefficients == [-2.0, -3.0])
        #expect(canonical.constant == 100.0)
    }

    @Test("Balance constraint: x - y = 0")
    func testBalanceConstraint() throws {
        let constraint = MultivariateConstraint<VectorN<Double>>.linearEquality(
            coefficients: [1.0, -1.0],  // x - y
            rhs: 0.0
        )

        let canonical = constraint.toCanonicalForm()

        // x - y = 0  →  x - y = 0 (already canonical for equality)
        #expect(canonical.coefficients == [1.0, -1.0])
        #expect(canonical.constant == 0.0)
        #expect(canonical.isEquality == true)
    }

    // MARK: - Edge Cases

    @Test("Negative coefficients")
    func testNegativeCoefficients() throws {
        // -3x + 2y ≤ 5
        let constraint = MultivariateConstraint<VectorN<Double>>.linearInequality(
            coefficients: [-3.0, 2.0],
            rhs: 5.0,
            sense: .lessOrEqual
        )

        let canonical = constraint.toCanonicalForm()

        // -3x + 2y ≤ 5  →  -3x + 2y - 5 ≤ 0
        #expect(canonical.coefficients == [-3.0, 2.0])
        #expect(canonical.constant == -5.0)
    }

    @Test("Zero coefficients")
    func testZeroCoefficients() throws {
        // 0x + y ≥ 2  (effectively y ≥ 2)
        let constraint = MultivariateConstraint<VectorN<Double>>.linearInequality(
            coefficients: [0.0, 1.0],
            rhs: 2.0,
            sense: .greaterOrEqual
        )

        let canonical = constraint.toCanonicalForm()

        // 0x + y ≥ 2  →  -y + 2 ≤ 0
        #expect(canonical.coefficients == [0.0, -1.0])
        #expect(canonical.constant == 2.0)
    }

    @Test("Negative RHS")
    func testNegativeRHS() throws {
        // x ≥ -5 (lower bound can be negative)
        let constraint = MultivariateConstraint<VectorN<Double>>.linearInequality(
            coefficients: [1.0],
            rhs: -5.0,
            sense: .greaterOrEqual
        )

        let canonical = constraint.toCanonicalForm()

        // x ≥ -5  →  -x - 5 ≤ 0
        #expect(canonical.coefficients == [-1.0])
        #expect(canonical.constant == -5.0)
    }

    // MARK: - Factory Method Tests

    @Test("Factory: budget constraint")
    func testBudgetFactory() throws {
        let constraints = MultivariateConstraint<VectorN<Double>>.budget(
            total: 100.0,
            dimension: 3
        )

        // Should create: x₁ + x₂ + x₃ ≤ 100
        let canonical = constraints.toCanonicalForm()
        #expect(canonical.coefficients == [1.0, 1.0, 1.0])
        #expect(canonical.constant == -100.0)
    }

    @Test("Factory: non-negativity constraints")
    func testNonNegativityFactory() throws {
        let constraints = MultivariateConstraint<VectorN<Double>>.nonNegativity(
            dimension: 2
        )

        // Should create: x ≥ 0, y ≥ 0 (two constraints)
        #expect(constraints.count == 2, "Should create 2 constraints")

        // First constraint: x ≥ 0  →  -x ≤ 0
        let canonical0 = constraints[0].toCanonicalForm()
        #expect(canonical0.coefficients == [-1.0, 0.0])
        #expect(canonical0.constant == 0.0)

        // Second constraint: y ≥ 0  →  -y ≤ 0
        let canonical1 = constraints[1].toCanonicalForm()
        #expect(canonical1.coefficients == [0.0, -1.0])
        #expect(canonical1.constant == 0.0)
    }

    @Test("Factory: box constraints")
    func testBoxConstraintsFactory() throws {
        let constraints = MultivariateConstraint<VectorN<Double>>.box(
            lower: -5.0,
            upper: 10.0,
            dimension: 2
        )

        // Should create 4 constraints: x ≥ -5, x ≤ 10, y ≥ -5, y ≤ 10
        #expect(constraints.count == 4, "Should create 4 constraints")

        // First two: x bounds
        let x_lower = constraints[0].toCanonicalForm()  // x ≥ -5  →  -x - 5 ≤ 0
        #expect(x_lower.coefficients == [-1.0, 0.0])
        #expect(x_lower.constant == -5.0)

        let x_upper = constraints[1].toCanonicalForm()  // x ≤ 10  →  x - 10 ≤ 0
        #expect(x_upper.coefficients == [1.0, 0.0])
        #expect(x_upper.constant == -10.0)

        // Next two: y bounds
        let y_lower = constraints[2].toCanonicalForm()  // y ≥ -5  →  -y - 5 ≤ 0
        #expect(y_lower.coefficients == [0.0, -1.0])
        #expect(y_lower.constant == -5.0)

        let y_upper = constraints[3].toCanonicalForm()  // y ≤ 10  →  y - 10 ≤ 0
        #expect(y_upper.coefficients == [0.0, 1.0])
        #expect(y_upper.constant == -10.0)
    }

    // MARK: - High-Dimensional Tests

    @Test("High-dimensional constraint")
    func testHighDimensionalConstraint() throws {
        // Σxᵢ ≤ 50 for i = 0..9 (10 variables)
        let constraint = MultivariateConstraint<VectorN<Double>>.linearInequality(
            coefficients: Array(repeating: 1.0, count: 10),
            rhs: 50.0,
            sense: .lessOrEqual
        )

        let canonical = constraint.toCanonicalForm()

        #expect(canonical.coefficients.count == 10)
        #expect(canonical.coefficients.allSatisfy { $0 == 1.0 })
        #expect(canonical.constant == -50.0)
    }

    // MARK: - Verification Against Evaluation

    @Test("Canonical form evaluation correctness")
    func testCanonicalFormEvaluation() throws {
        // x + 2y ≤ 10
        let constraint = MultivariateConstraint<VectorN<Double>>.linearInequality(
            coefficients: [1.0, 2.0],
            rhs: 10.0,
            sense: .lessOrEqual
        )

        let canonical = constraint.toCanonicalForm()

        // Test point: (3, 2)
        // Original: 3 + 2*2 = 7 ≤ 10 ✓ (satisfied)
        // Canonical: 3 + 2*2 - 10 = -3 ≤ 0 ✓ (satisfied)
        let point = [3.0, 2.0]
        let g = zip(canonical.coefficients, point).reduce(canonical.constant) { acc, pair in
            acc + pair.0 * pair.1
        }

        #expect(g <= 0.0, "Constraint should be satisfied: g(x) = \(g)")
        #expect(g == -3.0, "Expected g(x) = -3.0, got \(g)")
    }
}

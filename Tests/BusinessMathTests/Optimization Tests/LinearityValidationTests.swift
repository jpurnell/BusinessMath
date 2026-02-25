import Testing
import TestSupport  // Cross-platform math functions
import Foundation
@testable import BusinessMath

/// Tests for linearity validation functionality
///
/// These tests verify that `validateLinearModel()` correctly:
/// - Accepts truly linear functions
/// - Rejects nonlinear functions (quadratic, bilinear, exponential, etc.)
/// - Handles edge cases (near-linear, high-dimensional, numerical noise)
///
/// Following TDD: These tests are written FIRST and will fail until
/// Phase B implements the validation logic.
@Suite("Linearity Validation Tests")
struct LinearityValidationTests {

    // MARK: - Linear Function Acceptance

    @Test("Accepts truly linear function")
    func testAcceptsLinear() throws {
        // f(x, y) = 3x + 2y + 1 (perfectly linear)
        let linear: @Sendable (VectorN<Double>) -> Double = { v in
            3.0 * v[0] + 2.0 * v[1] + 1.0
        }

        let (coeffs, constant) = try validateLinearModel(
            linear,
            dimension: 2,
            at: VectorN([0.5, 0.5])
        )

        // Extracted coefficients should match
        #expect(abs(coeffs[0] - 3.0) < 1e-6, "First coefficient should be ~3.0")
        #expect(abs(coeffs[1] - 2.0) < 1e-6, "Second coefficient should be ~2.0")
        #expect(abs(constant - 1.0) < 1e-6, "Constant should be ~1.0")
    }

    @Test("Accepts linear function with zero coefficients")
    func testAcceptsLinearWithZeroCoeffs() throws {
        // f(x, y) = 2y + 5 (x has zero coefficient)
        let linear: @Sendable (VectorN<Double>) -> Double = { v in
            0.0 * v[0] + 2.0 * v[1] + 5.0
        }

        let (coeffs, constant) = try validateLinearModel(
            linear,
            dimension: 2,
            at: VectorN([1.0, 1.0])
        )

        #expect(abs(coeffs[0]) < 1e-6, "First coefficient should be ~0.0")
        #expect(abs(coeffs[1] - 2.0) < 1e-6)
        #expect(abs(constant - 5.0) < 1e-6)
    }

    @Test("Accepts constant function")
    func testAcceptsConstant() throws {
        // f(x) = 7 (constant, technically linear with zero coefficients)
        let constant: (VectorN<Double>) -> Double = { _ in 7.0 }

        let (coeffs, c) = try validateLinearModel(
            constant,
            dimension: 2,
            at: VectorN([1.0, 1.0])
        )

        // All coefficients should be ~0
        for coeff in coeffs {
            #expect(abs(coeff) < 1e-6, "Coefficient should be ~0 for constant function")
        }
        #expect(abs(c - 7.0) < 1e-6, "Constant should be 7.0")
    }

    // MARK: - Nonlinear Function Rejection

    @Test("Rejects quadratic function")
    func testRejectsQuadratic() throws {
        // f(x) = x² (nonlinear)
        let quadratic: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] * v[0]
        }

        #expect(throws: OptimizationError.self) {
            try validateLinearModel(
                quadratic,
                dimension: 1,
                at: VectorN([0.5])
            )
        }
    }

    @Test("Rejects bilinear function")
    func testRejectsBilinear() throws {
        // f(x, y) = xy (nonlinear)
        let bilinear: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] * v[1]
        }

        #expect(throws: OptimizationError.self) {
            try validateLinearModel(
                bilinear,
                dimension: 2,
                at: VectorN([0.5, 0.5])
            )
        }
    }

    @Test("Rejects exponential function")
    func testRejectsExponential() throws {
        // f(x) = e^x (nonlinear)
        let exponential: @Sendable (VectorN<Double>) -> Double = { v in
            exp(v[0])
        }

        #expect(throws: OptimizationError.self) {
            try validateLinearModel(
                exponential,
                dimension: 1,
                at: VectorN([0.5])
            )
        }
    }

    @Test("Rejects logarithmic function")
    func testRejectsLogarithmic() throws {
        // f(x) = log(x) (nonlinear)
        let logarithmic: @Sendable (VectorN<Double>) -> Double = { v in
            log(v[0])
        }

        #expect(throws: OptimizationError.self) {
            try validateLinearModel(
                logarithmic,
                dimension: 1,
                at: VectorN([1.0])  // Must be positive for log
            )
        }
    }

    @Test("Rejects polynomial function")
    func testRejectsPolynomial() throws {
        // f(x, y) = x² + 2xy + y² + 3x + 4y + 5 (nonlinear)
        let polynomial: @Sendable (VectorN<Double>) -> Double = { v in
            v[0]*v[0] + 2.0*v[0]*v[1] + v[1]*v[1] + 3.0*v[0] + 4.0*v[1] + 5.0
        }

        #expect(throws: OptimizationError.self) {
            try validateLinearModel(
                polynomial,
                dimension: 2,
                at: VectorN([0.5, 0.5])
            )
        }
    }

    @Test("Rejects absolute value function")
    func testRejectsAbsoluteValue() throws {
        // f(x) = |x| (nonlinear, not differentiable at 0)
        let absValue: @Sendable (VectorN<Double>) -> Double = { v in
            abs(v[0])
        }

        #expect(throws: OptimizationError.self) {
            try validateLinearModel(
                absValue,
                dimension: 1,
                at: VectorN([0.5])  // Test away from non-differentiable point
            )
        }
    }

    // MARK: - High-Dimensional Tests

    @Test("Accepts high-dimensional linear function")
    func testAcceptsHighDimensionalLinear() throws {
        // f(x) = Σᵢ xᵢ (sum of all variables)
        let linear: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray().reduce(0.0, +)
        }

        let dimension = 10
        let (coeffs, constant) = try validateLinearModel(
            linear,
            dimension: dimension,
            at: VectorN(Array(repeating: 0.5, count: dimension))
        )

        // All coefficients should be ~1.0
        for i in 0..<dimension {
            #expect(abs(coeffs[i] - 1.0) < 1e-6,
                    "Coefficient \(i) should be ~1.0")
        }
        #expect(abs(constant) < 1e-6, "Constant should be ~0")
    }

    @Test("Rejects high-dimensional nonlinear function")
    func testRejectsHighDimensionalNonlinear() throws {
        // f(x) = Σᵢ xᵢ² (sum of squares - nonlinear)
        let nonlinear: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray().reduce(0.0) { $0 + $1 * $1 }
        }

        let dimension = 10
        #expect(throws: OptimizationError.self) {
            try validateLinearModel(
                nonlinear,
                dimension: dimension,
                at: VectorN(Array(repeating: 0.5, count: dimension))
            )
        }
    }

    // MARK: - Edge Cases

    @Test("Handles negative coefficients correctly")
    func testNegativeCoefficients() throws {
        // f(x, y) = -3x + 2y - 1
        let linear: @Sendable (VectorN<Double>) -> Double = { v in
            -3.0 * v[0] + 2.0 * v[1] - 1.0
        }

        let (coeffs, constant) = try validateLinearModel(
            linear,
            dimension: 2,
            at: VectorN([0.5, 0.5])
        )

        #expect(abs(coeffs[0] - (-3.0)) < 1e-6)
        #expect(abs(coeffs[1] - 2.0) < 1e-6)
        #expect(abs(constant - (-1.0)) < 1e-6)
    }

    @Test("Handles large coefficients correctly")
    func testLargeCoefficients() throws {
        // f(x, y) = 1000x + 2000y + 500
        let linear: @Sendable (VectorN<Double>) -> Double = { v in
            1000.0 * v[0] + 2000.0 * v[1] + 500.0
        }

        let (coeffs, constant) = try validateLinearModel(
            linear,
            dimension: 2,
            at: VectorN([0.1, 0.1])
        )

        #expect(abs(coeffs[0] - 1000.0) < 1e-3, "Should handle large coefficients")
        #expect(abs(coeffs[1] - 2000.0) < 1e-3)
        #expect(abs(constant - 500.0) < 1e-3)
    }

    @Test("Handles small coefficients correctly")
    func testSmallCoefficients() throws {
        // f(x, y) = 0.001x + 0.002y + 0.0005
        let linear: @Sendable (VectorN<Double>) -> Double = { v in
            0.001 * v[0] + 0.002 * v[1] + 0.0005
        }

        let (coeffs, constant) = try validateLinearModel(
            linear,
            dimension: 2,
            at: VectorN([1.0, 1.0])
        )

        #expect(abs(coeffs[0] - 0.001) < 1e-8, "Should handle small coefficients")
        #expect(abs(coeffs[1] - 0.002) < 1e-8)
        #expect(abs(constant - 0.0005) < 1e-8)
    }

    // MARK: - Numerical Robustness

    @Test("Validates at different initial points")
    func testDifferentInitialPoints() throws {
        // f(x, y) = 2x + 3y + 1
        let linear: @Sendable (VectorN<Double>) -> Double = { v in
            2.0 * v[0] + 3.0 * v[1] + 1.0
        }

        // Should work from any initial point
        let initialPoints: [VectorN<Double>] = [
            VectorN([0.0, 0.0]),
            VectorN([1.0, 1.0]),
            VectorN([5.0, -3.0]),
            VectorN([-2.0, 4.0])
        ]

        for point in initialPoints {
            let (coeffs, constant) = try validateLinearModel(
                linear,
                dimension: 2,
                at: point
            )

            #expect(abs(coeffs[0] - 2.0) < 1e-5,
                    "Should extract correct coefficients from \(point.toArray())")
            #expect(abs(coeffs[1] - 3.0) < 1e-5)
            #expect(abs(constant - 1.0) < 1e-5)
        }
    }

    @Test("Custom tolerance parameter")
    func testCustomTolerance() throws {
        // f(x) = x (perfectly linear)
        let linear: @Sendable (VectorN<Double>) -> Double = { v in v[0] }

        // Should accept with tight tolerance (realistic for finite-diff method)
        let (coeffs, constant) = try validateLinearModel(
            linear,
            dimension: 1,
            at: VectorN([0.5]),
            numSamples: 20,  // More samples for confidence
            tolerance: 1e-7  // Tight but realistic for h=1e-8 finite-diff
        )

        #expect(abs(coeffs[0] - 1.0) < 1e-6)
        #expect(abs(constant) < 1e-6)
    }
}

import Testing
@testable import BusinessMath

/// Tests for LinearFunction protocol and StandardLinearFunction implementation
///
/// These tests verify:
/// - Correct evaluation of linear functions f(x) = c·x + d
/// - Gradient computation (should be constant = coefficients)
/// - Coefficient accuracy compared to finite-difference extraction
///
/// Following TDD: These tests are written FIRST and will fail until
/// Phase A2 implements the LinearFunction protocol.
@Suite("LinearFunction Protocol Tests")
struct LinearFunctionTests {

    // MARK: - Basic Functionality

    @Test("LinearFunction evaluates correctly")
    func testEvaluation() throws {
        // f(x) = 2x₁ + 3x₂ + 1
        let f = StandardLinearFunction<VectorN<Double>>(
            coefficients: [2.0, 3.0],
            constant: 1.0
        )

        let point = VectorN([5.0, 7.0])
        let result = f.evaluate(at: point)

        // 2*5 + 3*7 + 1 = 10 + 21 + 1 = 32
        #expect(abs(result - 32.0) < 1e-15, "Expected 32.0, got \(result)")
    }

    @Test("LinearFunction with zero constant")
    func testZeroConstant() throws {
        // f(x) = x₁ + 2x₂ (no constant term)
        let f = StandardLinearFunction<VectorN<Double>>(
            coefficients: [1.0, 2.0],
            constant: 0.0
        )

        let point = VectorN([3.0, 4.0])
        let result = f.evaluate(at: point)

        // 1*3 + 2*4 = 11
        #expect(abs(result - 11.0) < 1e-15)
    }

    @Test("LinearFunction with negative coefficients")
    func testNegativeCoefficients() throws {
        // f(x) = -2x₁ + 3x₂ - 5
        let f = StandardLinearFunction<VectorN<Double>>(
            coefficients: [-2.0, 3.0],
            constant: -5.0
        )

        let point = VectorN([1.0, 2.0])
        let result = f.evaluate(at: point)

        // -2*1 + 3*2 - 5 = -2 + 6 - 5 = -1
        #expect(abs(result - (-1.0)) < 1e-15)
    }

    // MARK: - Gradient Tests

    @Test("LinearFunction gradient is constant")
    func testGradient() throws {
        // For f(x) = 2x₁ + 3x₂ + 1, ∇f = [2, 3] everywhere
        let f = StandardLinearFunction<VectorN<Double>>(
            coefficients: [2.0, 3.0],
            constant: 1.0
        )

        // Test at multiple different points - gradient should be same
        let points: [VectorN<Double>] = [
            VectorN([0.0, 0.0]),
            VectorN([100.0, 200.0]),
            VectorN([-50.0, 75.0])
        ]

        for point in points {
            let grad = f.gradient(at: point)
            #expect(grad.toArray()[0] == 2.0, "Gradient x₁ component should be 2.0 at \(point.toArray())")
            #expect(grad.toArray()[1] == 3.0, "Gradient x₂ component should be 3.0 at \(point.toArray())")
        }
    }

    // MARK: - Accuracy Tests

    @Test("Coefficient accuracy vs finite-diff")
    func testAccuracy() throws {
        // Explicit linear: exact coefficients (machine precision ~1e-15)
        let explicit = StandardLinearFunction<VectorN<Double>>(
            coefficients: [1.234567890123456, 9.876543210987654],
            constant: 0.0
        )

        // Closure-based: finite-diff extraction (numerical error ~1e-9)
        let closure: (VectorN<Double>) -> Double = { v in
            1.234567890123456 * v[0] + 9.876543210987654 * v[1]
        }

        let extracted = try StandardLinearFunction.fromClosure(
            closure,
            dimension: 2,
            at: VectorN([0.5, 0.5])
        )

        // Explicit should be ~1e-15 accurate
        #expect(abs(explicit.coefficients[0] - 1.234567890123456) < 1e-15,
                "Explicit coefficient should have machine precision")

        // Finite-diff should be ~1e-9 accurate (much worse)
        #expect(abs(extracted.coefficients[0] - 1.234567890123456) > 1e-10,
                "Finite-difference should have ~1e-9 error")
        #expect(abs(extracted.coefficients[0] - 1.234567890123456) < 1e-7,
                "But error should be bounded by ~1e-7")
    }

    @Test("High-precision coefficients preserved")
    func testHighPrecision() throws {
        // Test with many significant digits
        let π = 3.141592653589793
        let e = 2.718281828459045

        let f = StandardLinearFunction<VectorN<Double>>(
            coefficients: [π, e],
            constant: 1.0
        )

        // Verify coefficients are stored exactly
        #expect(f.coefficients[0] == π)
        #expect(f.coefficients[1] == e)
    }

    // MARK: - Single Variable Tests

    @Test("Single variable function")
    func testSingleVariable() throws {
        // f(x) = 5x + 3
        let f = StandardLinearFunction<VectorN<Double>>(
            coefficients: [5.0],
            constant: 3.0
        )

        let result = f.evaluate(at: VectorN([2.0]))
        #expect(abs(result - 13.0) < 1e-15) // 5*2 + 3 = 13
    }

    // MARK: - High-Dimensional Tests

    @Test("High-dimensional function")
    func testHighDimensional() throws {
        // f(x) = x₁ + x₂ + x₃ + x₄ + x₅
        let f = StandardLinearFunction<VectorN<Double>>(
            coefficients: Array(repeating: 1.0, count: 5),
            constant: 0.0
        )

        let point = VectorN([1.0, 2.0, 3.0, 4.0, 5.0])
        let result = f.evaluate(at: point)

        // 1 + 2 + 3 + 4 + 5 = 15
        #expect(abs(result - 15.0) < 1e-15)
    }

    // MARK: - Zero Coefficient Tests

    @Test("Zero coefficients")
    func testZeroCoefficients() throws {
        // f(x) = 0x₁ + 0x₂ + 5 = 5
        let f = StandardLinearFunction<VectorN<Double>>(
            coefficients: [0.0, 0.0],
            constant: 5.0
        )

        // Should evaluate to constant regardless of input
        let π = 3.141592653589793
        let e = 2.718281828459045
        let points: [VectorN<Double>] = [
            VectorN([0.0, 0.0]),
            VectorN([100.0, -50.0]),
            VectorN([π, e])
        ]

        for point in points {
            let result = f.evaluate(at: point)
            #expect(abs(result - 5.0) < 1e-15,
                    "Function should equal constant for all points")
        }
    }

    // MARK: - fromClosure Tests

    @Test("fromClosure extracts coefficients correctly")
    func testFromClosure() throws {
        let closure: (VectorN<Double>) -> Double = { v in
            3.0 * v[0] + 2.0 * v[1] + 1.0
        }

        let f = try StandardLinearFunction.fromClosure(
            closure,
            dimension: 2,
            at: VectorN([0.5, 0.5])
        )

        // Coefficients should be close to [3.0, 2.0]
        #expect(abs(f.coefficients[0] - 3.0) < 1e-6)
        #expect(abs(f.coefficients[1] - 2.0) < 1e-6)

        // Constant should be close to 1.0
        #expect(abs(f.constant - 1.0) < 1e-6)
    }
}

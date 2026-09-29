//
//  DenseMatrixAccessorTests.swift
//  BusinessMathTests
//
//  Seven never-executed `DenseMatrix` members from the coverage list: `row`, `column`,
//  `element(atRow:column:)`, `array`, `frobeniusNorm`, matrix subtraction and scalar
//  multiplication.
//
//  The fixture is deliberately **non-square**. A 2×3 matrix cannot hide a transposed index
//  behind symmetry, and that matters here specifically: `ExpressionMatrix.multiply(_ vector:)`
//  — the same operation in the expression compiler — was found in this sweep to be seeding
//  its accumulator with the first product and counting it twice. `DenseMatrix` gets it right,
//  and this pins the distinction.
//
//  Everything matched hand arithmetic, and all six bounds violations throw.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Dense matrix accessors against hand arithmetic")
struct DenseMatrixAccessorTests {

    /// Elementwise IEEE comparison, stated rather than left to `==` on the arrays — the count
    /// is part of the claim, and `==` would also call two NaN streams unequal while reporting
    /// the property as broken.
    private func agree(_ lhs: [Double], _ rhs: [Double]) -> Bool {
        // `isEqual(to:)` is IEEE equality, so `nan.isEqual(to: .nan)` is **false**. This sweep
    // deliberately marks unevaluable positions with `.nan`, so two NaNs in the same slot
    // are an agreement, not a mismatch — without this a marked position can never match.
    lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.isEqual(to: $1) || ($0.isNaN && $1.isNaN) }
    }

    private func agree(_ lhs: [[Double]], _ rhs: [[Double]]) -> Bool {
        lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { agree($0, $1) }
    }

    /// 2×3, so rows and columns have different lengths.
    private static func wide() throws -> DenseMatrix<Double> {
        try DenseMatrix([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]])
    }

    @Test("RowsColumnsAndElements") func rowsColumnsAndElements() throws {
        let a = try Self.wide()
        #expect(agree(try a.row(0), [1.0, 2.0, 3.0]))
        #expect(agree(try a.row(1), [4.0, 5.0, 6.0]))
        #expect(agree(try a.column(0), [1.0, 4.0]))
        #expect(agree(try a.column(1), [2.0, 5.0]))
        #expect(agree(try a.column(2), [3.0, 6.0]))
        #expect(try a.element(atRow: 1, column: 2).isEqual(to: 6.0))
        #expect(a[1, 2].isEqual(to: 6.0), "the subscript agrees with the throwing accessor")
        #expect(agree(a.array, [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]))
        #expect(a.isSquare == false)
    }

    /// sqrt(1 + 4 + 9 + 16 + 25 + 36) = sqrt(91).
    @Test("FrobeniusNorm_IsTheRootSumOfSquares") func frobeniusNormIsRootSumOfSquares() throws {
        let sumOfSquares: Double = 91.0
        let expected: Double = sumOfSquares.squareRoot()
        #expect(try Self.wide().frobeniusNorm.isEqual(to: expected))
    }

    @Test("ScalarMultiplyAndSubtract") func scalarMultiplyAndSubtract() throws {
        let a = try Self.wide()
        #expect(agree((2.0 * a).array, [[2.0, 4.0, 6.0], [8.0, 10.0, 12.0]]))
        #expect(agree(try (a - a).array, [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]))
    }

    /// The operation whose expression-compiler twin was double-counting its first term.
    @Test("MatrixTimesVector_IsTheDotProducts") func matrixTimesVectorIsDotProducts() throws {
        #expect(agree(try Self.wide().multiplied(by: [1.0, 2.0, 3.0]), [14.0, 32.0]),
                "1+4+9 and 4+10+18, each counted once")
    }

    @Test("TransposeTraceAndSymmetry") func transposeTraceAndSymmetry() throws {
        #expect(agree(try Self.wide().transposed().array, [[1.0, 4.0], [2.0, 5.0], [3.0, 6.0]]))
        let square = try DenseMatrix([[2.0, 1.0], [1.0, 3.0]])
        #expect(square.trace.isEqual(to: 5.0))
        #expect(square.isSymmetric(tolerance: 1e-12))
    }

    @Test("OutOfBounds_Throws") func outOfBoundsThrows() throws {
        let a = try Self.wide()
        #expect(throws: (any Error).self) { _ = try a.row(-1) }
        #expect(throws: (any Error).self) { _ = try a.row(2) }
        #expect(throws: (any Error).self) { _ = try a.column(-1) }
        #expect(throws: (any Error).self) { _ = try a.column(3) }
        #expect(throws: (any Error).self) { _ = try a.element(atRow: 5, column: 5) }
        let narrow = try DenseMatrix([[1.0, 2.0]])
        #expect(throws: (any Error).self) { _ = try a - narrow }
    }
}

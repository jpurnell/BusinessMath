//
//  ExpressionCompilerOracleTests.swift
//  BusinessMathTests
//
//  The Monte Carlo expression compiler had 17 never-executed members — every transcendental,
//  every comparison, the reversed-operand division, and the whole matrix layer. Found by
//  working the list of 729 untested functions from `swift test --enable-code-coverage`.
//
//  A bytecode compiler has the best oracle available: compile the expression, run it through
//  `evaluate(inputs:)`, and compare against the same arithmetic written directly in Swift.
//  There is nothing to model and nothing to approximate.
//
//  **`ExpressionMatrix.multiply(_ vector:)` was wrong.** It read
//
//      return products.reduce(products[0]) { $0 + $1 }
//
//  which seeds the accumulator with the first product and then folds that same product in
//  again, so every row came back as `products[0] + sum(products)`:
//
//  | row of A = [[1,2,3],[4,5,6]], x = [1,2,3] | correct | returned | excess |
//  |---|---|---|---|
//  | 0 | 14 | **15** | A[0][0] = 1 |
//  | 1 | 32 | **36** | A[1][0] = 4 |
//
//  The four sibling reductions in `ExpressionArray.swift` all write
//  `elements.dropFirst().reduce(elements[0])`. This was the one site that did not, which is
//  why `quadraticForm` — with its own explicit zero accumulator — was correct all along and
//  matrix-matrix multiply was too.
//
//  Everything else in the cluster matched Swift exactly, including the reversed-operand
//  `Double / ExpressionProxy`, which is where a DSL usually swaps operands into a shared
//  opcode.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Expression compiler against direct Swift arithmetic")
struct ExpressionCompilerOracleTests {

    /// Compile and run, so each case reads as "the VM agrees with Swift".
    private func evaluate(
        _ inputs: [Double],
        _ build: @escaping (ExpressionBuilder) -> ExpressionProxy
    ) throws -> Double {
        let model = try MonteCarloExpressionModel { builder in build(builder) }
        return try model.evaluate(inputs: inputs)
    }

    // MARK: - The defect

    /// A is deliberately non-square, so a transposed index or a mis-seeded accumulator cannot
    /// hide behind symmetry.
    @Test("MatrixTimesVector_MatchesTheDotProducts") func matrixTimesVectorMatchesDotProducts() throws {
        let a: [[Double]] = [[1, 2, 3], [4, 5, 6]]
        let x: [Double] = [1, 2, 3]
        for row in 0..<a.count {
            let expected = zip(a[row], x).map(*).reduce(0, +)
            let actual = try evaluate([0.0]) { builder in
                builder.matrix(rows: 2, cols: 3, values: a).multiply(builder.array(x))[row]
            }
            #expect(actual.isEqual(to: expected),
                    "row \(row): got \(actual), expected \(expected)")
        }
    }

    /// A single-column matrix is the shape the doc comment's own example uses, and the one
    /// where the double-count is largest in relative terms: with one column, the result was
    /// exactly twice the product.
    @Test("MatrixTimesVector_SingleColumn") func matrixTimesVectorSingleColumn() throws {
        let value = try evaluate([0.0]) { builder in
            builder.matrix(rows: 1, cols: 1, values: [[0.08]]).multiply(builder.array([3.0]))[0]
        }
        #expect(value.isEqual(to: 0.24), "0.08 * 3, not 0.48")
    }

    // MARK: - The rest of the matrix layer, which was already correct

    @Test("Transpose_SwapsIndices") func transposeSwapsIndices() throws {
        let a: [[Double]] = [[1, 2, 3], [4, 5, 6]]
        for row in 0..<3 {
            for col in 0..<2 {
                let actual = try evaluate([0.0]) { builder in
                    builder.matrix(rows: 2, cols: 3, values: a).transpose()[row, col]
                }
                #expect(actual.isEqual(to: a[col][row]), "Aᵀ[\(row),\(col)]")
            }
        }
    }

    @Test("MatrixTimesMatrix_MatchesHandProduct") func matrixTimesMatrixMatchesHandProduct() throws {
        // [[1,2,3],[4,5,6]] × [[7,8],[9,10],[11,12]] = [[58,64],[139,154]]
        let expected: [[Double]] = [[58, 64], [139, 154]]
        for row in 0..<2 {
            for col in 0..<2 {
                let actual = try evaluate([0.0]) { builder in
                    builder.matrix(rows: 2, cols: 3, values: [[1, 2, 3], [4, 5, 6]])
                        .multiply(builder.matrix(rows: 3, cols: 2, values: [[7, 8], [9, 10], [11, 12]]))[row, col]
                }
                #expect(actual.isEqual(to: expected[row][col]), "(AB)[\(row),\(col)]")
            }
        }
    }

    /// `xᵀSx` for S = [[2,1],[1,3]] and x = [1,2]: Sx = [4, 7], xᵀ(Sx) = 4 + 14 = 18.
    /// It was already right because it uses its own zero accumulator rather than the reduce
    /// above — which is the detail that localised the defect.
    @Test("QuadraticForm_MatchesHandProduct") func quadraticFormMatchesHandProduct() throws {
        let value = try evaluate([0.0]) { builder in
            builder.matrix(rows: 2, cols: 2, values: [[2, 1], [1, 3]])
                .quadraticForm(builder.array([1.0, 2.0]))
        }
        #expect(value.isEqual(to: 18))
    }

    @Test("TraceDiagonalAndAdd") func traceDiagonalAndAdd() throws {
        let s: [[Double]] = [[2, 1], [1, 3]]
        #expect(try evaluate([0.0]) { $0.matrix(rows: 2, cols: 2, values: s).trace() }.isEqual(to: 5))
        #expect(try evaluate([0.0]) { $0.matrix(rows: 2, cols: 2, values: s).diagonal()[0] }.isEqual(to: 2))
        #expect(try evaluate([0.0]) { $0.matrix(rows: 2, cols: 2, values: s).diagonal()[1] }.isEqual(to: 3))
        #expect(try evaluate([0.0]) { builder in
            let m = builder.matrix(rows: 2, cols: 2, values: s)
            return m.add(m)[0, 1]
        }.isEqual(to: 2), "1 + 1")
    }

    @Test("ForEach_Accumulates") func forEachAccumulates() throws {
        let sum = try evaluate([0.0]) { builder in
            builder.forEach(1...4, initial: 0.0) { index, accumulator in accumulator + Double(index) }
        }
        #expect(sum.isEqual(to: 10), "1 + 2 + 3 + 4")
    }

    // MARK: - Scalar operations, each against its Swift counterpart

    @Test("Transcendentals_MatchSwift") func transcendentalsMatchSwift() throws {
        let x = 0.7
        #expect(try evaluate([x]) { $0[0].exp() }.isEqual(to: exp(x)))
        #expect(try evaluate([x]) { $0[0].sin() }.isEqual(to: sin(x)))
        #expect(try evaluate([x]) { $0[0].cos() }.isEqual(to: cos(x)))
        #expect(try evaluate([x]) { $0[0].tan() }.isEqual(to: tan(x)))
        #expect(try evaluate([x]) { $0[0].power(3.0) }.isEqual(to: pow(x, 3.0)))
        #expect(try evaluate([-x]) { $0[0].abs() }.isEqual(to: abs(-x)))
        #expect(try evaluate([x]) { $0[0].max(1.0) }.isEqual(to: Swift.max(x, 1.0)))
        #expect(try evaluate([x]) { $0[0].min(1.0) }.isEqual(to: Swift.min(x, 1.0)))
    }

    /// Reversed operands are where a DSL usually folds `a / b` into the `b / a` opcode.
    @Test("ReversedDivision_DividesTheRightWayRound") func reversedDivisionIsNotSwapped() throws {
        let x = 0.7
        #expect(try evaluate([x]) { 10.0 / $0[0] }.isEqual(to: 10.0 / x), "10 / x")
        #expect(try evaluate([x]) { $0[0] / 10.0 }.isEqual(to: x / 10.0), "x / 10")
    }

    /// Comparisons yield 1 for true and 0 for false, and each is checked against the Swift
    /// operator it names — adjacent opcodes are easy to transpose.
    @Test("Comparisons_MatchSwift") func comparisonsMatchSwift() throws {
        let x = 0.7, y = 2.5
        #expect(try evaluate([x]) { $0[0].lessThan(1.0) }.isEqual(to: x < 1.0 ? 1 : 0))
        #expect(try evaluate([x]) { $0[0].equal(0.7) }.isEqual(to: 1))
        #expect(try evaluate([x]) { $0[0].notEqual(0.7) }.isEqual(to: 0))
        #expect(try evaluate([x]) { $0[0].greaterOrEqual(0.7) }.isEqual(to: 1))
        #expect(try evaluate([x, y]) { $0[0].lessOrEqual($0[1]) }.isEqual(to: x <= y ? 1 : 0))
        #expect(try evaluate([x, y]) { $0[0].notEqual($0[1]) }.isEqual(to: 1))
        #expect(try evaluate([x, y]) { $0[0].greaterOrEqual($0[1]) }.isEqual(to: x >= y ? 1 : 0))
    }

    @Test("IfElse_WithConstantArms") func ifElseWithConstantArms() throws {
        let x = 0.7
        #expect(try evaluate([x]) { $0[0].lessThan(1.0).ifElse(then: 5.0, else: 9.0) }.isEqual(to: 5))
        #expect(try evaluate([x]) { $0[0].greaterOrEqual(1.0).ifElse(then: 5.0, else: 9.0) }.isEqual(to: 9))
    }
}

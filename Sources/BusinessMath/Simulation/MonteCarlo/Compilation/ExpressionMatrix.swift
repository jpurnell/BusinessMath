//
//  ExpressionMatrix.swift
//  BusinessMath
//
//  Fixed-size matrix operations for GPU-accelerated portfolio optimization
//
//  Provides compile-time fixed-size matrices for covariance calculations,
//  portfolio variance, and other matrix operations needed in finance.
//

import Foundation

// MARK: - Expression Matrix

/// A fixed-size matrix of expressions that can be compiled to GPU bytecode
///
/// ExpressionMatrix provides matrix operations with compile-time known dimensions,
/// enabling GPU acceleration for portfolio calculations.
///
/// ## Usage - Portfolio Variance
///
/// ```swift
/// let model = MonteCarloExpressionModel { builder in
///     // 3-asset portfolio
///     let w1 = builder[0]
///     let w2 = builder[1]
///     let w3 = builder[2]
///     let weights = builder.array([w1, w2, w3])
///
///     // Covariance matrix (symmetric, 3×3)
///     let covariance = builder.matrix(rows: 3, cols: 3, values: [
///         [0.04, 0.01, 0.02],
///         [0.01, 0.05, 0.015],
///         [0.02, 0.015, 0.03]
///     ])
///
///     // Portfolio variance: w^T Σ w
///     let variance = covariance.quadraticForm(weights)
///
///     return variance.sqrt()  // Return volatility
/// }
/// ```
public struct ExpressionMatrix: Sendable {

    /// Number of rows
    public let rows: Int

    /// Number of columns
    public let cols: Int

    /// Matrix elements in row-major order
    private let elements: [[ExpressionProxy]]

    /// Create matrix from 2D array
    ///
    /// - Parameters:
    ///   - elements: 2D array of expressions
    internal init(elements: [[ExpressionProxy]]) {
        self.rows = elements.count
        self.cols = elements.first?.count ?? 0
        self.elements = elements
    }

    // MARK: - Matrix-Vector Operations

    /// Multiply matrix by vector: y = Ax
    ///
    /// ## Example - Expected Portfolio Return
    /// ```swift
    /// let weights = builder.array([0, 1, 2])
    /// let returns = builder.matrix(rows: 3, cols: 1, values: [[0.08], [0.10], [0.12]])
    /// let portfolioReturn = returns.multiply(weights)
    /// ```
    public func multiply(_ vector: ExpressionArray) -> ExpressionArray {
        guard cols == vector.count else {
            fatalError("Matrix columns (\(cols)) must match vector size (\(vector.count))")
        }

        let resultElements = elements.map { row in
            let products = zip(row, vector.elements).map { $0 * $1 }
            return products.reduce(products[0]) { $0 + $1 }
        }

        return ExpressionArray(elements: resultElements)
    }

    /// Quadratic form: x^T A x (for portfolio variance)
    ///
    /// Computes the quadratic form w^T Σ w where:
    /// - w is the weight vector
    /// - Σ is the covariance matrix
    ///
    /// ## Example - Portfolio Variance
    /// ```swift
    /// let weights = builder.array([0, 1, 2])
    /// let covariance = builder.matrix(rows: 3, cols: 3, values: [ ... ])
    /// let variance = covariance.quadraticForm(weights)
    /// ```
    public func quadraticForm(_ vector: ExpressionArray) -> ExpressionProxy {
        guard rows == cols && rows == vector.count else {
            fatalError("Quadratic form requires square matrix matching vector size")
        }

        // Compute: sum_i sum_j w_i * Σ_ij * w_j
        var sum = ExpressionProxy(.constant(0.0))

        for i in 0..<rows {
            for j in 0..<cols {
                let term = vector[i] * elements[i][j] * vector[j]
                sum = sum + term
            }
        }

        return sum
    }

    // MARK: - Matrix-Matrix Operations

    /// Multiply two matrices: C = AB
    ///
    /// ## Example
    /// ```swift
    /// let A = builder.matrix(rows: 2, cols: 3, values: [ ... ])
    /// let B = builder.matrix(rows: 3, cols: 2, values: [ ... ])
    /// let C = A.multiply(B)  // 2×2 result
    /// ```
    public func multiply(_ other: ExpressionMatrix) -> ExpressionMatrix {
        guard cols == other.rows else {
            fatalError("Matrix multiply: inner dimensions must match")
        }

        var resultElements: [[ExpressionProxy]] = []

        for i in 0..<rows {
            var row: [ExpressionProxy] = []

            for j in 0..<other.cols {
                var sum = ExpressionProxy(.constant(0.0))

                for k in 0..<cols {
                    sum = sum + elements[i][k] * other.elements[k][j]
                }

                row.append(sum)
            }

            resultElements.append(row)
        }

        return ExpressionMatrix(elements: resultElements)
    }

    /// Add two matrices element-wise
    ///
    /// ## Example
    /// ```swift
    /// let A = builder.matrix(rows: 2, cols: 2, values: [ ... ])
    /// let B = builder.matrix(rows: 2, cols: 2, values: [ ... ])
    /// let C = A.add(B)
    /// ```
    public func add(_ other: ExpressionMatrix) -> ExpressionMatrix {
        guard rows == other.rows && cols == other.cols else {
            fatalError("Matrix addition requires same dimensions")
        }

        let resultElements = zip(elements, other.elements).map { row1, row2 in
            zip(row1, row2).map { $0 + $1 }
        }

        return ExpressionMatrix(elements: resultElements)
    }

    /// Transpose matrix
    ///
    /// ## Example
    /// ```swift
    /// let A = builder.matrix(rows: 2, cols: 3, values: [ ... ])
    /// let AT = A.transpose()  // 3×2
    /// ```
    public func transpose() -> ExpressionMatrix {
        var transposed: [[ExpressionProxy]] = Array(
            repeating: Array(repeating: ExpressionProxy(.constant(0.0)), count: rows),
            count: cols
        )

        for i in 0..<rows {
            for j in 0..<cols {
                transposed[j][i] = elements[i][j]
            }
        }

        return ExpressionMatrix(elements: transposed)
    }

    // MARK: - Statistical Operations

    /// Calculate trace (sum of diagonal elements)
    ///
    /// ## Example
    /// ```swift
    /// let matrix = builder.matrix(rows: 3, cols: 3, values: [ ... ])
    /// let trace = matrix.trace()
    /// ```
    public func trace() -> ExpressionProxy {
        guard rows == cols else {
            fatalError("Trace requires square matrix")
        }

        var sum = elements[0][0]
        for i in 1..<rows {
            sum = sum + elements[i][i]
        }

        return sum
    }

    /// Get diagonal as array
    ///
    /// ## Example - Asset Variances
    /// ```swift
    /// let covariance = builder.matrix(rows: 3, cols: 3, values: [ ... ])
    /// let variances = covariance.diagonal()
    /// let volatilities = variances.map { $0.sqrt() }
    /// ```
    public func diagonal() -> ExpressionArray {
        guard rows == cols else {
            fatalError("Diagonal requires square matrix")
        }

        let diagonalElements = (0..<rows).map { elements[$0][$0] }
        return ExpressionArray(elements: diagonalElements)
    }

    // MARK: - Subscript

    /// Access matrix element by row and column
    ///
    /// ## Example
    /// ```swift
    /// let matrix = builder.matrix(rows: 3, cols: 3, values: [ ... ])
    /// let covar12 = matrix[1, 2]  // Covariance between assets 1 and 2
    /// ```
    public subscript(row: Int, col: Int) -> ExpressionProxy {
        return elements[row][col]
    }
}

// MARK: - ExpressionBuilder Matrix Extension

extension ExpressionBuilder {

    /// Create fixed-size matrix from 2D array of input indices
    ///
    /// ## Example
    /// ```swift
    /// let builder = ExpressionBuilder()
    /// // Create 2×2 matrix from inputs[0..3]
    /// let matrix = builder.matrix(rows: 2, cols: 2, inputIndices: [
    ///     [0, 1],
    ///     [2, 3]
    /// ])
    /// ```
    public func matrix(rows: Int, cols: Int, inputIndices: [[Int]]) -> ExpressionMatrix {
        let elements = inputIndices.map { row in
            row.map { self[$0] }
        }
        return ExpressionMatrix(elements: elements)
    }

    /// Create fixed-size matrix from 2D array of constants
    ///
    /// ## Example - Covariance Matrix
    /// ```swift
    /// let builder = ExpressionBuilder()
    /// let covariance = builder.matrix(rows: 3, cols: 3, values: [
    ///     [0.04, 0.01, 0.02],
    ///     [0.01, 0.05, 0.015],
    ///     [0.02, 0.015, 0.03]
    /// ])
    /// ```
    public func matrix(rows: Int, cols: Int, values: [[Double]]) -> ExpressionMatrix {
        let elements = values.map { row in
            row.map { ExpressionProxy(.constant($0)) }
        }
        return ExpressionMatrix(elements: elements)
    }

    /// Create fixed-size matrix from 2D array of expressions
    ///
    /// ## Example
    /// ```swift
    /// let builder = ExpressionBuilder()
    /// let a = builder[0]
    /// let b = builder[1]
    /// let matrix = builder.matrix(rows: 2, cols: 2, expressions: [
    ///     [a, b],
    ///     [a + b, a * b]
    /// ])
    /// ```
    public func matrix(rows: Int, cols: Int, expressions: [[ExpressionProxy]]) -> ExpressionMatrix {
        return ExpressionMatrix(elements: expressions)
    }
}

// MARK: - Portfolio Helper Functions

extension FinancialFunctions {

    /// Calculate portfolio variance: w^T Σ w
    ///
    /// ## Example
    /// ```swift
    /// let portfolioVariance = ExpressionFunction(inputs: 9) { builder in
    ///     // 3 weights (inputs 0-2)
    ///     let weights = builder.array([0, 1, 2])
    ///
    ///     // 3×3 covariance matrix (inputs 3-11, but we'll use constants)
    ///     let covariance = builder.matrix(rows: 3, cols: 3, values: [
    ///         [0.04, 0.01, 0.02],
    ///         [0.01, 0.05, 0.015],
    ///         [0.02, 0.015, 0.03]
    ///     ])
    ///
    ///     return covariance.quadraticForm(weights)
    /// }
    /// ```
    public static let portfolioVariance2Asset = ExpressionFunction(inputs: 5) { builder in
        let w1 = builder[0]
        let w2 = builder[1]
        let var1 = builder[2]
        let var2 = builder[3]
        let covar = builder[4]

        // Portfolio variance for 2 assets
        return w1 * w1 * var1 + w2 * w2 * var2 + 2.0 * w1 * w2 * covar
    }

    /// Calculate portfolio volatility: sqrt(w^T Σ w)
    public static let portfolioVolatility2Asset = ExpressionFunction(inputs: 5) { builder in
        let variance = portfolioVariance2Asset.call(
            builder[0], builder[1], builder[2], builder[3], builder[4]
        )
        return variance.sqrt()
    }

    /// Calculate diversification ratio: (sum w_i * σ_i) / σ_portfolio
    ///
    /// Measures how much diversification reduces risk
    public static let diversificationRatio2Asset = ExpressionFunction(inputs: 6) { builder in
        let w1 = builder[0]
        let w2 = builder[1]
        let sigma1 = builder[2]
        let sigma2 = builder[3]
        let var1 = builder[4]
        let var2 = builder[5]

        let weightedVolSum = w1 * sigma1 + w2 * sigma2
        let portfolioVol = (w1 * w1 * var1 + w2 * w2 * var2).sqrt()

        return weightedVolSum / portfolioVol
    }

    /// Calculate correlation from covariance: ρ = Cov(X,Y) / (σ_X * σ_Y)
    public static let correlationFromCovariance = ExpressionFunction(inputs: 3) { builder in
        let covariance = builder[0]
        let sigma1 = builder[1]
        let sigma2 = builder[2]

        return covariance / (sigma1 * sigma2)
    }
}

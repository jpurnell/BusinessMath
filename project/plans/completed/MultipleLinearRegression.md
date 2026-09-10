# Multiple Linear Regression Implementation Plan

**Created:** 2026-02-15
**Status:** Planning
**Priority:** High - fills a gap in statistical capabilities
**Estimated Effort:** 3-5 days (500-800 lines + tests + docs)

---

## Overview

Add comprehensive **multiple linear regression** capabilities to BusinessMath, enabling users to model relationships with multiple independent variables. This fills a critical gap between the existing simple `linearRegression()` function (one predictor) and advanced nonlinear regression.

### Motivation

The pricing extraction example revealed this gap: users need to solve systems like:

```swift
Cost = β₀ + β₁·input + β₂·output + β₃·cacheCreate + β₄·cacheRead
```

Currently, BusinessMath only supports single-variable regression. Users are forced to implement matrix operations themselves or use external libraries.

---

## Goals

### Primary Features

1. **Multiple Linear Regression Solver** ⭐
   - Solve systems with 2-20+ predictors
   - Optional intercept term
   - Generic over `Real` types
   - Normal equations: `β = (XᵀX)⁻¹Xᵀy`
   - ~200-250 lines

2. **Model Diagnostics** 📊
   - R², adjusted R², F-statistic
   - Coefficient standard errors
   - Confidence intervals
   - Residual analysis
   - ~150-200 lines

3. **Prediction & Analysis** 🎯
   - Predict new values
   - Prediction intervals
   - Standardized coefficients (beta weights)
   - Variance Inflation Factors (multicollinearity detection)
   - ~100-150 lines

4. **Matrix Utilities** 🔧
   - Dense matrix operations (transpose, multiply, invert)
   - QR decomposition (more stable than normal equations)
   - Integration with existing `SparseMatrix`
   - ~150-200 lines

### Secondary Features (Future)

5. **Weighted Regression** - Different observation weights
6. **Regularization** - Ridge/Lasso regression (L2/L1 penalties)
7. **Polynomial Regression** - Automatic polynomial feature generation
8. **Stepwise Selection** - Automatic variable selection

---

## Architecture

### File Structure

```
Sources/BusinessMath/Statistics/Regression/
├── MultipleLinearRegression.swift        # Main solver
├── RegressionModel.swift                 # Model result/predictions
├── RegressionDiagnostics.swift          # R², F-stat, residuals
└── MatrixOperations/
    ├── DenseMatrix.swift                 # Core matrix type
    ├── MatrixDecomposition.swift         # QR, Cholesky, LU
    └── MatrixSolvers.swift              # Linear system solvers
```

### Integration Points

**Existing Code:**
- `linearRegression()` - keep as simple API, suggest MLR for multiple predictors
- `rSquared()` - extend to support multiple regression
- `rSquaredAdjusted()` - already supports multiple predictors!
- `SparseMatrix` - leverage for large datasets
- `CorrelationMatrix` - use Cholesky decomposition
- `DataTable` - use for sensitivity analysis of coefficients

---

## Feature 1: Core Matrix Operations

### Problem It Solves

Multiple linear regression requires matrix operations (transpose, multiplication, inversion). We need a clean, generic implementation.

### Implementation Plan

**File:** `Sources/BusinessMath/Statistics/Regression/MatrixOperations/DenseMatrix.swift`

```swift
/// A generic dense matrix type supporting standard linear algebra operations.
///
/// Used internally for regression calculations. For large sparse matrices,
/// use `SparseMatrix` instead.
///
/// ## Example
/// ```swift
/// let A = DenseMatrix([
///     [1.0, 2.0],
///     [3.0, 4.0]
/// ])
/// let B = A.transposed()
/// let C = try A.inverted()
/// ```
public struct DenseMatrix<T: Real> {
    /// Row-major storage: matrix[row][column]
    private var data: [[T]]

    public let rows: Int
    public let columns: Int

    // MARK: - Initialization

    /// Create matrix from 2D array
    public init(_ data: [[T]]) throws

    /// Create matrix with specified dimensions, filled with value
    public init(rows: Int, columns: Int, repeating value: T = T(0))

    /// Create identity matrix
    public static func identity(size: Int) -> DenseMatrix<T>

    /// Create diagonal matrix from values
    public static func diagonal(_ values: [T]) -> DenseMatrix<T>

    // MARK: - Accessors

    /// Access element at (row, column)
    public subscript(row: Int, column: Int) -> T { get set }

    /// Get row as array
    public func row(_ index: Int) -> [T]

    /// Get column as array
    public func column(_ index: Int) -> [T]

    /// Get all data as 2D array
    public var array: [[T]] { get }

    // MARK: - Basic Operations

    /// Transpose: rows ↔ columns
    public func transposed() -> DenseMatrix<T>

    /// Matrix-matrix multiplication: A × B
    public func multiplied(by other: DenseMatrix<T>) throws -> DenseMatrix<T>

    /// Matrix-vector multiplication: A × x
    public func multiplied(by vector: [T]) throws -> [T]

    /// Element-wise addition
    public static func + (lhs: DenseMatrix<T>, rhs: DenseMatrix<T>) throws -> DenseMatrix<T>

    /// Element-wise subtraction
    public static func - (lhs: DenseMatrix<T>, rhs: DenseMatrix<T>) throws -> DenseMatrix<T>

    /// Scalar multiplication
    public static func * (lhs: T, rhs: DenseMatrix<T>) -> DenseMatrix<T>

    // MARK: - Properties

    /// Check if matrix is square
    public var isSquare: Bool

    /// Check if matrix is symmetric (within tolerance)
    public func isSymmetric(tolerance: T = T(1e-10)) -> Bool

    /// Trace (sum of diagonal elements)
    public var trace: T

    /// Frobenius norm
    public var frobeniusNorm: T
}
```

**Key Design Decisions:**
- Generic over `Real` (supports Double, Float, Float80)
- Row-major storage (matches Swift arrays)
- Throwing initializer (validates rectangular matrix)
- Operator overloads for intuitive syntax
- Integration with existing array-based code

**Error Handling:**
```swift
public enum MatrixError: Error {
    case notSquare
    case notSymmetric
    case singularMatrix
    case dimensionMismatch(expected: String, actual: String)
    case notPositiveDefinite
    case invalidDecomposition(reason: String)
}
```

---

## Feature 2: Matrix Decompositions & Solvers

### Problem It Solves

Normal equations `(XᵀX)⁻¹Xᵀy` can be numerically unstable. QR decomposition provides better stability. We need robust linear system solvers.

### Implementation Plan

**File:** `Sources/BusinessMath/Statistics/Regression/MatrixOperations/MatrixDecomposition.swift`

```swift
// MARK: - QR Decomposition (Recommended for Regression)

/// Performs QR decomposition using Householder reflections.
///
/// Decomposes A = QR where Q is orthogonal and R is upper triangular.
/// More numerically stable than normal equations for regression.
///
/// ## Example
/// ```swift
/// let A = try DenseMatrix([[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]])
/// let (Q, R) = try A.qrDecomposition()
/// // A ≈ Q × R (within numerical tolerance)
/// ```
extension DenseMatrix {
    /// QR decomposition using Householder reflections
    ///
    /// - Returns: (Q, R) where Q is orthogonal (m×m) and R is upper triangular (m×n)
    /// - Complexity: O(mn²) where m = rows, n = columns
    public func qrDecomposition() throws -> (q: DenseMatrix<T>, r: DenseMatrix<T>)

    /// Thin QR decomposition (more efficient for regression)
    ///
    /// Returns Q (m×n) and R (n×n) instead of full Q (m×m)
    /// - Returns: (Q, R) in thin/economy form
    public func qrDecompositionThin() throws -> (q: DenseMatrix<T>, r: DenseMatrix<T>)
}

// MARK: - Cholesky Decomposition (For XᵀX)

extension DenseMatrix {
    /// Cholesky decomposition: A = LLᵀ
    ///
    /// Requires A to be symmetric positive definite.
    /// Reuses existing `choleskyDecomposition()` from CorrelationMatrix.swift
    ///
    /// - Returns: Lower triangular matrix L
    /// - Throws: `MatrixError.notPositiveDefinite` if A is not SPD
    public func choleskyDecomposition() throws -> DenseMatrix<T>
}

// MARK: - LU Decomposition (For General Systems)

extension DenseMatrix {
    /// LU decomposition with partial pivoting: PA = LU
    ///
    /// - Returns: (L, U, P) where L is lower triangular, U is upper triangular, P is permutation
    public func luDecomposition() throws -> (l: DenseMatrix<T>, u: DenseMatrix<T>, p: [Int])
}
```

**File:** `Sources/BusinessMath/Statistics/Regression/MatrixOperations/MatrixSolvers.swift`

```swift
// MARK: - Linear System Solvers

extension DenseMatrix {
    /// Solve linear system Ax = b
    ///
    /// Uses the most appropriate method based on matrix properties:
    /// - Symmetric positive definite → Cholesky
    /// - Overdetermined (m > n) → QR
    /// - Square → LU with partial pivoting
    ///
    /// - Parameters:
    ///   - b: Right-hand side vector
    ///   - method: Solver method (default: automatic selection)
    /// - Returns: Solution vector x
    /// - Throws: `MatrixError.singularMatrix` if no solution exists
    public func solve(_ b: [T], method: SolverMethod = .automatic) throws -> [T]

    /// Solver method selection
    public enum SolverMethod {
        case automatic        // Choose best method automatically
        case qr              // QR decomposition (stable for overdetermined)
        case cholesky        // Cholesky (fast for SPD matrices)
        case lu              // LU with pivoting (general case)
        case normalEquations // (XᵀX)⁻¹Xᵀy (fast but less stable)
    }
}

// MARK: - Matrix Inversion

extension DenseMatrix {
    /// Compute matrix inverse using LU decomposition
    ///
    /// For regression, prefer `solve()` instead of explicitly inverting.
    /// Only use when you need the full inverse matrix.
    ///
    /// - Returns: A⁻¹
    /// - Throws: `MatrixError.singularMatrix` if matrix is not invertible
    public func inverted() throws -> DenseMatrix<T>

    /// Compute pseudo-inverse (Moore-Penrose inverse) using SVD
    ///
    /// Works for singular and non-square matrices.
    /// A⁺ = (AᵀA)⁻¹Aᵀ for overdetermined systems
    ///
    /// - Returns: A⁺ pseudo-inverse
    public func pseudoInverse() throws -> DenseMatrix<T>
}
```

**Algorithm Selection Logic:**
```swift
func chooseSolver(for matrix: DenseMatrix<T>) -> SolverMethod {
    if matrix.isSymmetric() && isPositiveDefinite(matrix) {
        return .cholesky  // Fastest for SPD
    } else if matrix.rows > matrix.columns {
        return .qr  // Best for overdetermined (regression case)
    } else if matrix.isSquare {
        return .lu  // General square systems
    } else {
        return .qr  // Underdetermined systems
    }
}
```

---

## Feature 3: Multiple Linear Regression Model

### Problem It Solves

Users need to fit models with multiple predictors, get coefficients, make predictions, and validate quality.

### Implementation Plan

**File:** `Sources/BusinessMath/Statistics/Regression/MultipleLinearRegression.swift`

```swift
/// Fits a multiple linear regression model: y = β₀ + β₁x₁ + β₂x₂ + ... + βₙxₙ
///
/// Uses QR decomposition for numerical stability.
///
/// ## Example: Pricing Extraction
/// ```swift
/// // Predict API cost from token counts
/// let X = [
///     [35778.0, 8093.0, 1951481.0, 22710000.0],  // Day 1: input, output, cache_create, cache_read
///     [847.0, 334.0, 1103281.0, 16250000.0],     // Day 2
///     // ... more observations
/// ]
/// let y = [13.53, 9.02, ...]  // Costs
///
/// let model = try multipleLinearRegression(
///     predictors: X,
///     response: y,
///     includeIntercept: false  // Zero tokens = zero cost
/// )
///
/// print("Price per input token: $\(model.coefficients[0])")
/// print("R² = \(model.rSquared)")
/// print("Model is \(model.isSignificant ? "significant" : "not significant")")
///
/// // Predict cost for new usage pattern
/// let newCost = try model.predict([1000, 500, 0, 50000])
/// ```
///
/// - Parameters:
///   - predictors: 2D array of predictor values [observation][predictor]
///   - response: Array of response values (dependent variable)
///   - includeIntercept: If true, adds constant term β₀ (default: true)
///   - weights: Optional observation weights for weighted regression
///   - method: Solver method (default: QR decomposition)
///
/// - Returns: Fitted regression model with coefficients and diagnostics
///
/// - Throws:
///   - `RegressionError.insufficientData` if observations < predictors + 1
///   - `RegressionError.dimensionMismatch` if X and y lengths differ
///   - `MatrixError.singularMatrix` if predictors are perfectly collinear
public func multipleLinearRegression<T: Real>(
    predictors X: [[T]],
    response y: [T],
    includeIntercept: Bool = true,
    weights: [T]? = nil,
    method: DenseMatrix<T>.SolverMethod = .qr
) throws -> RegressionModel<T>

/// Result of multiple linear regression with coefficients and diagnostics
public struct RegressionModel<T: Real> {
    // MARK: - Fitted Model

    /// Regression coefficients [β₀, β₁, β₂, ..., βₙ]
    /// If includeIntercept=false, β₀ is omitted
    public let coefficients: [T]

    /// Coefficient names for labeling (optional)
    public let coefficientNames: [String]?

    /// Number of predictors (excluding intercept)
    public let numberOfPredictors: Int

    /// Whether model includes intercept term
    public let hasIntercept: Bool

    // MARK: - Model Fit Statistics

    /// R² (coefficient of determination): fraction of variance explained
    /// Range: [0, 1], higher is better
    public let rSquared: T

    /// Adjusted R²: R² adjusted for number of predictors
    /// Penalizes overfitting, use when comparing models
    public let adjustedRSquared: T

    /// Root Mean Squared Error (RMSE)
    public let rmse: T

    /// Mean Absolute Error (MAE)
    public let mae: T

    // MARK: - Statistical Tests

    /// F-statistic for overall model significance
    /// Tests H₀: all coefficients are zero
    public let fStatistic: T

    /// p-value for F-test
    public let fPValue: T

    /// Is model statistically significant? (p < 0.05)
    public var isSignificant: Bool { fPValue < T(0.05) }

    // MARK: - Coefficient Statistics

    /// Standard errors of coefficients
    public let standardErrors: [T]

    /// t-statistics for each coefficient
    public let tStatistics: [T]

    /// p-values for each coefficient
    public let pValues: [T]

    /// 95% confidence intervals for coefficients
    /// Returns [(lower, upper)] for each coefficient
    public func confidenceIntervals(level: T = T(0.95)) -> [(lower: T, upper: T)]

    // MARK: - Residuals & Diagnostics

    /// Residuals: observed - predicted
    public let residuals: [T]

    /// Standardized residuals (studentized)
    public let standardizedResiduals: [T]

    /// Leverage values (hat matrix diagonal)
    public let leverage: [T]

    /// Cook's distance (influence of each observation)
    public let cooksDistance: [T]

    /// Durbin-Watson statistic (autocorrelation test)
    public let durbinWatson: T

    // MARK: - Multicollinearity Detection

    /// Variance Inflation Factors for each predictor
    /// VIF > 10 indicates problematic multicollinearity
    public let vif: [T]

    /// Condition number of XᵀX matrix
    /// > 30 indicates potential numerical instability
    public let conditionNumber: T

    // MARK: - Predictions

    /// Predict response for new predictor values
    ///
    /// - Parameter predictors: Array of predictor values [x₁, x₂, ..., xₙ]
    /// - Returns: Predicted response value ŷ
    /// - Throws: `RegressionError.dimensionMismatch` if wrong number of predictors
    public func predict(_ predictors: [T]) throws -> T

    /// Predict with confidence interval
    ///
    /// - Parameters:
    ///   - predictors: Predictor values
    ///   - level: Confidence level (default: 0.95)
    /// - Returns: (prediction, lower, upper)
    public func predictWithInterval(
        _ predictors: [T],
        level: T = T(0.95)
    ) throws -> (prediction: T, lower: T, upper: T)

    /// Predict multiple observations
    ///
    /// - Parameter X: 2D array of predictor values
    /// - Returns: Array of predictions
    public func predict(_ X: [[T]]) throws -> [T]

    // MARK: - Model Summary

    /// Formatted summary of regression results
    ///
    /// Example output:
    /// ```
    /// Multiple Linear Regression Summary
    /// ===================================
    /// R² = 0.9876, Adjusted R² = 0.9845
    /// F-statistic = 312.4 (p < 0.001) ***
    /// RMSE = 0.0234, MAE = 0.0189
    ///
    /// Coefficients:
    /// -------------
    ///              Estimate   Std.Error   t-value   p-value
    /// Intercept     1.2345      0.0123    100.37    < 0.001  ***
    /// x1            0.4567      0.0089     51.31    < 0.001  ***
    /// x2           -0.1234      0.0156     -7.91     0.002   **
    /// x3            0.0891      0.0201      4.43     0.012   *
    ///
    /// Significance: *** p < 0.001, ** p < 0.01, * p < 0.05
    /// ```
    public func summary() -> String

    /// Export coefficients to DataTable for sensitivity analysis
    public func toDataTable() -> [(name: String, coefficient: T, pValue: T)]
}

/// Errors specific to regression operations
public enum RegressionError: Error {
    case insufficientData(required: Int, actual: Int)
    case dimensionMismatch(expected: String, actual: String)
    case perfectMulticollinearity(predictors: [Int])
    case invalidWeights(reason: String)
}
```

**Key Implementation Details:**

1. **QR Decomposition Solution:**
```swift
// Given: X (design matrix), y (response)
// Solve: Xβ = y using QR decomposition

let (Q, R) = try X.qrDecomposition()
let Qty = Q.transposed().multiplied(by: y)
let beta = try backSubstitution(R, Qty)  // Solve Rβ = Qᵀy
```

2. **Coefficient Standard Errors:**
```swift
// SE(β) = sqrt(σ² × diag((XᵀX)⁻¹))
// where σ² = RSS / (n - p - 1) is residual variance

let RSS = residuals.map { $0 * $0 }.reduce(0, +)
let sigma2 = RSS / T(n - p - 1)
let XtX_inv = try (X.transposed().multiplied(by: X)).inverted()
let standardErrors = (0..<p).map { i in
    T.sqrt(sigma2 * XtX_inv[i, i])
}
```

3. **VIF Calculation:**
```swift
// VIF_i = 1 / (1 - R²_i)
// where R²_i is R² from regressing x_i on all other predictors

func calculateVIF(X: [[T]]) -> [T] {
    var vifs: [T] = []
    for i in 0..<X[0].count {
        // Regress X[i] on X[-i]
        let Xi = X.map { $0[i] }
        let Xothers = X.map { row in
            row.enumerated().filter { $0.offset != i }.map { $0.element }
        }
        let auxModel = try multipleLinearRegression(
            predictors: Xothers,
            response: Xi
        )
        let vif = T(1) / (T(1) - auxModel.rSquared)
        vifs.append(vif)
    }
    return vifs
}
```

---

## Feature 4: Integration with Existing API

### Backwards Compatibility

Extend existing `linearRegression()` to suggest MLR when appropriate:

```swift
public func linearRegression<T: Real>(_ xValues: [T], _ yValues: [T]) throws -> (T) -> T {
    // Existing implementation unchanged
    guard xValues.count == yValues.count else {
        throw BusinessMathError.mismatchedDimensions(...)
    }

    let slope = try slope(xValues, yValues)
    let intercept = try intercept(xValues, yValues)
    return { x in intercept + slope * x }
}

/// Multiple linear regression (NEW)
///
/// For single predictor, consider using `linearRegression()` for simpler API.
public func multipleLinearRegression<T: Real>(
    predictors X: [[T]],
    response y: [T],
    includeIntercept: Bool = true
) throws -> RegressionModel<T> {
    // Implementation as above
}
```

### Extend `DataTable` for Coefficient Analysis

```swift
extension RegressionModel {
    /// Analyze coefficient sensitivity across different data splits
    ///
    /// Uses DataTable to show how coefficients vary with training data
    public func crossValidate(folds: Int = 5) -> [(coefficients: [T], testR2: T)]
}
```

### Extend Existing R² Functions

```swift
// Update rSquared() to work with multiple predictions
public func rSquared<T: Real>(_ predicted: [T], _ actual: [T]) -> T {
    // Existing implementation already supports this!
}

// Update rSquaredAdjusted() - already supports multiple predictors!
public func rSquaredAdjusted<T: Real>(
    _ predicted: [T],
    _ actual: [T],
    descriptors: T = T(1)
) -> T {
    // Existing implementation works great
}
```

---

## Testing Strategy

### Unit Tests

**File:** `Tests/BusinessMathTests/Statistics Tests/MultipleLinearRegressionTests.swift`

```swift
final class MultipleLinearRegressionTests: XCTestCase {

    // MARK: - Matrix Operations Tests

    func testMatrixTranspose() {
        let A = try! DenseMatrix([[1.0, 2.0], [3.0, 4.0]])
        let At = A.transposed()
        XCTAssertEqual(At[0, 0], 1.0)
        XCTAssertEqual(At[0, 1], 3.0)
    }

    func testMatrixMultiplication() {
        // Test A × B
    }

    func testQRDecomposition() {
        // Verify A ≈ Q × R
        // Verify Q is orthogonal: QᵀQ = I
    }

    func testCholeskyDecomposition() {
        // Verify A = LLᵀ for SPD matrix
    }

    func testLinearSystemSolver() {
        // Known solution: Ax = b
        let A = try! DenseMatrix([[3.0, 1.0], [1.0, 2.0]])
        let b = [9.0, 8.0]
        let x = try! A.solve(b)
        XCTAssertEqual(x[0], 2.0, accuracy: 1e-10)
        XCTAssertEqual(x[1], 3.0, accuracy: 1e-10)
    }

    // MARK: - Regression Tests

    func testSimpleLinearRegression() {
        // y = 2x + 3
        let X = [[1.0], [2.0], [3.0], [4.0], [5.0]]
        let y = [5.0, 7.0, 9.0, 11.0, 13.0]

        let model = try! multipleLinearRegression(predictors: X, response: y)

        XCTAssertEqual(model.coefficients[0], 3.0, accuracy: 1e-10)  // intercept
        XCTAssertEqual(model.coefficients[1], 2.0, accuracy: 1e-10)  // slope
        XCTAssertEqual(model.rSquared, 1.0, accuracy: 1e-10)
    }

    func testMultipleLinearRegression() {
        // y = 1 + 2x₁ + 3x₂
        let X = [
            [1.0, 1.0],
            [2.0, 1.0],
            [1.0, 2.0],
            [2.0, 2.0],
            [3.0, 3.0]
        ]
        let y = [6.0, 8.0, 9.0, 11.0, 16.0]

        let model = try! multipleLinearRegression(predictors: X, response: y)

        XCTAssertEqual(model.coefficients[0], 1.0, accuracy: 1e-10)  // intercept
        XCTAssertEqual(model.coefficients[1], 2.0, accuracy: 1e-10)  // β₁
        XCTAssertEqual(model.coefficients[2], 3.0, accuracy: 1e-10)  // β₂
        XCTAssertEqual(model.rSquared, 1.0, accuracy: 1e-10)
    }

    func testRegressionWithoutIntercept() {
        // Force through origin: y = 2x₁ + 3x₂
        let X = [[1.0, 0.0], [0.0, 1.0], [2.0, 1.0]]
        let y = [2.0, 3.0, 7.0]

        let model = try! multipleLinearRegression(
            predictors: X,
            response: y,
            includeIntercept: false
        )

        XCTAssertEqual(model.coefficients.count, 2)  // No intercept
        XCTAssertEqual(model.coefficients[0], 2.0, accuracy: 1e-10)
        XCTAssertEqual(model.coefficients[1], 3.0, accuracy: 1e-10)
    }

    func testPricingExtraction() {
        // Real-world example from user's pricing matrix
        let X = [
            [35778.0, 8093.0, 1951481.0, 22710000.0],
            [847.0, 334.0, 1103281.0, 16250000.0],
            [144.0, 58.0, 198633.0, 2240426.0],
            // ... more rows
        ]
        let y = [13.53, 9.02, 1.38, ...]

        let model = try! multipleLinearRegression(
            predictors: X,
            response: y,
            includeIntercept: false
        )

        XCTAssertGreaterThan(model.rSquared, 0.95)  // Should be excellent fit
        XCTAssertLessThan(model.rmse, 0.5)  // Low error

        // Verify pricing makes sense
        XCTAssertGreaterThan(model.coefficients[1], model.coefficients[0])  // Output > Input
        XCTAssertLessThan(model.coefficients[3], model.coefficients[0])     // Cache < Input
    }

    func testModelDiagnostics() {
        let model = try! multipleLinearRegression(...)

        // Test statistical significance
        XCTAssertTrue(model.isSignificant)
        XCTAssertLessThan(model.fPValue, 0.05)

        // Test confidence intervals
        let intervals = model.confidenceIntervals()
        XCTAssertEqual(intervals.count, model.coefficients.count)

        // Test VIF (no multicollinearity)
        XCTAssertTrue(model.vif.allSatisfy { $0 < 10.0 })
    }

    func testPredictions() {
        let model = try! multipleLinearRegression(...)

        // Single prediction
        let pred = try! model.predict([1.0, 2.0, 3.0])
        XCTAssertNotNil(pred)

        // Prediction with interval
        let (est, lower, upper) = try! model.predictWithInterval([1.0, 2.0])
        XCTAssertLessThan(lower, est)
        XCTAssertGreaterThan(upper, est)
    }

    // MARK: - Error Handling Tests

    func testInsufficientData() {
        let X = [[1.0, 2.0]]  // Only 1 observation
        let y = [3.0]

        XCTAssertThrowsError(try multipleLinearRegression(predictors: X, response: y)) {
            error in
            XCTAssertTrue(error is RegressionError)
        }
    }

    func testDimensionMismatch() {
        let X = [[1.0], [2.0]]
        let y = [3.0]  // Wrong length

        XCTAssertThrowsError(try multipleLinearRegression(predictors: X, response: y))
    }

    func testPerfectMulticollinearity() {
        // x₂ = 2 × x₁ (perfectly correlated)
        let X = [[1.0, 2.0], [2.0, 4.0], [3.0, 6.0]]
        let y = [1.0, 2.0, 3.0]

        XCTAssertThrowsError(try multipleLinearRegression(predictors: X, response: y)) {
            error in
            guard case RegressionError.perfectMulticollinearity = error else {
                XCTFail("Expected perfectMulticollinearity error")
                return
            }
        }
    }
}
```

### Performance Tests

```swift
func testLargeDatasetPerformance() {
    // 1000 observations, 20 predictors
    let n = 1000
    let p = 20
    let X = (0..<n).map { _ in (0..<p).map { _ in Double.random(in: 0...1) } }
    let y = (0..<n).map { _ in Double.random(in: 0...10) }

    measure {
        _ = try! multipleLinearRegression(predictors: X, response: y)
    }

    // Should complete in < 100ms
}

func testQRvsNormalEquations() {
    // Compare stability and performance
}
```

### Integration Tests

```swift
func testWithDataTable() {
    // Use DataTable for sensitivity analysis
    let model = try! multipleLinearRegression(...)

    let table = DataTable<Double, Double>.oneVariable(
        inputs: [0.0, 0.1, 0.2, 0.3],
        calculate: { perturbation in
            try! model.predict([1.0 + perturbation, 2.0, 3.0])
        }
    )

    XCTAssertEqual(table.count, 4)
}
```

---

## Documentation

### DocC Tutorial

**File:** `Sources/BusinessMath/BusinessMath.docc/2.7-MultipleLinearRegressionGuide.md`

```markdown
# Multiple Linear Regression Guide

Learn how to fit models with multiple predictors and interpret results.

## Overview

Multiple linear regression extends simple linear regression to handle multiple
independent variables simultaneously.

### When to Use

- Modeling relationships with 2+ predictors
- Extracting pricing structures from usage data
- Financial forecasting with multiple drivers
- Risk factor analysis

## Quick Example

@Row {
  @Column {
    ```swift
    // Predict sales from price and advertising
    let X = [
        [10.0, 100.0],  // price=$10, ad spend=$100
        [12.0, 150.0],
        [8.0, 120.0],
        [15.0, 200.0]
    ]
    let sales = [500.0, 450.0, 550.0, 400.0]

    let model = try multipleLinearRegression(
        predictors: X,
        response: sales
    )

    print("Intercept: \(model.coefficients[0])")
    print("Price effect: \(model.coefficients[1])")
    print("Ad effect: \(model.coefficients[2])")
    print("R² = \(model.rSquared)")
    ```
  }
}

## Topics

### Fitting Models
- ``multipleLinearRegression(predictors:response:includeIntercept:)``
- ``RegressionModel``

### Model Diagnostics
- ``RegressionModel/rSquared``
- ``RegressionModel/adjustedRSquared``
- ``RegressionModel/fStatistic``
- ``RegressionModel/vif``

### Making Predictions
- ``RegressionModel/predict(_:)``
- ``RegressionModel/predictWithInterval(_:level:)``

### Advanced Topics
- Handling Multicollinearity
- Weighted Regression
- Cross-Validation
```

### API Reference Comments

All public APIs should have DocC-style comments with:
- Summary line
- Detailed description
- Parameter documentation
- Return value description
- Example code
- Throws documentation
- Complexity notation where relevant

### Examples File

Add to `EXAMPLES.md`:

```markdown
## Multiple Linear Regression

### Pricing Extraction

Extract per-token pricing from API usage data:

```swift
// See full example in ~/downloads/PricingExtractionExample.swift
```

### Sales Forecasting

Predict sales from multiple factors:

```swift
let factors = [
    [price, advertising, competition, seasonality],
    // ... more observations
]
let model = try multipleLinearRegression(predictors: factors, response: sales)
```
```

---

## Implementation Phases

### Phase 1: Matrix Infrastructure (Days 1-2)
- [ ] Implement `DenseMatrix<T>` with basic operations
- [ ] Add QR decomposition (Householder)
- [ ] Add Cholesky decomposition (reuse existing)
- [ ] Add LU decomposition with pivoting
- [ ] Add linear system solvers
- [ ] Unit tests for all matrix operations
- [ ] Performance benchmarks

### Phase 2: Core Regression (Day 3)
- [ ] Implement `multipleLinearRegression()` function
- [ ] Implement `RegressionModel` struct
- [ ] Add coefficient calculation (QR-based)
- [ ] Add prediction methods
- [ ] Add residual calculations
- [ ] Unit tests for regression

### Phase 3: Diagnostics & Statistics (Day 4)
- [ ] Implement R², adjusted R²
- [ ] Implement F-statistic and p-values
- [ ] Implement coefficient standard errors
- [ ] Implement confidence intervals
- [ ] Implement VIF calculation
- [ ] Implement Cook's distance, leverage
- [ ] Add model summary formatting
- [ ] Unit tests for diagnostics

### Phase 4: Documentation & Polish (Day 5)
- [ ] DocC tutorial guide
- [ ] API reference documentation
- [ ] Update EXAMPLES.md
- [ ] Integration tests
- [ ] Pricing extraction example
- [ ] Sales forecasting example
- [ ] Performance optimization
- [ ] Code review and cleanup

---

## Future Enhancements (V2)

### Weighted Regression
```swift
func multipleLinearRegression(
    predictors: [[T]],
    response: [T],
    weights: [T]  // Observation weights
) throws -> RegressionModel<T>
```

### Ridge Regression (L2 Regularization)
```swift
func ridgeRegression(
    predictors: [[T]],
    response: [T],
    lambda: T  // Regularization parameter
) throws -> RegressionModel<T>
```

### Stepwise Variable Selection
```swift
func stepwiseRegression(
    predictors: [[T]],
    response: [T],
    method: StepwiseMethod = .backward
) throws -> RegressionModel<T>

enum StepwiseMethod {
    case forward   // Add variables sequentially
    case backward  // Remove variables sequentially
    case both      // Bidirectional
}
```

### Polynomial Regression Helper
```swift
/// Automatically generate polynomial features
func polynomialFeatures(_ X: [[T]], degree: Int) -> [[T]]

// Usage:
let X_poly = polynomialFeatures(X, degree: 2)
// [x₁, x₂] → [x₁, x₂, x₁², x₁x₂, x₂²]
```

### Cross-Validation
```swift
extension RegressionModel {
    /// K-fold cross-validation
    func crossValidate(
        predictors: [[T]],
        response: [T],
        folds: Int = 5
    ) -> [T]  // R² for each fold
}
```

---

## Success Metrics

### Functionality
- [ ] Supports 2-20+ predictors efficiently
- [ ] Numerically stable (condition number < 10³)
- [ ] Accurate (residuals match R/Python)
- [ ] Handles edge cases (collinearity, singular matrices)

### Performance
- [ ] 100 obs × 5 predictors: < 1ms
- [ ] 1,000 obs × 20 predictors: < 50ms
- [ ] 10,000 obs × 50 predictors: < 500ms

### Usability
- [ ] Simple API for common cases
- [ ] Clear error messages
- [ ] Comprehensive diagnostics
- [ ] Formatted model summaries
- [ ] Integration with DataTable, TimeSeries

### Quality
- [ ] 95%+ test coverage
- [ ] All edge cases tested
- [ ] Performance benchmarks pass
- [ ] Documentation complete
- [ ] Examples run correctly

---

## Design Decisions & Rationale

### Why QR Instead of Normal Equations?

**Normal Equations:** `β = (XᵀX)⁻¹Xᵀy`
- ❌ Squares condition number: κ(XᵀX) = κ(X)²
- ❌ Numerically unstable for ill-conditioned X
- ✅ Fast for well-conditioned problems

**QR Decomposition:** `X = QR, Rβ = Qᵀy`
- ✅ Preserves condition number: κ(R) ≈ κ(X)
- ✅ Numerically stable
- ✅ Industry standard (R, Python, MATLAB all use QR)
- ⚠️ Slightly slower (but negligible for typical datasets)

**Decision:** Use QR by default, allow normal equations as option.

### Why Generic Over Real?

Supports `Double`, `Float`, `Float80` for different precision needs:
- `Float`: Mobile/embedded, memory-constrained
- `Double`: Standard desktop/server (recommended)
- `Float80`: High-precision scientific computing

### Why Not SVD?

Singular Value Decomposition is more robust but:
- 2-3× slower than QR
- Overkill for most regression problems
- Can add later for `pseudoInverse()`

### Integration with Existing Code

- Extends `rSquared()` and `rSquaredAdjusted()` - already support multiple regression!
- Compatible with `DataTable` for sensitivity analysis
- Follows existing error handling patterns
- Matches naming conventions (camelCase, descriptive)

---

## Questions & Open Issues

### Q: Should we use Accelerate.framework on Apple platforms?

**Pros:**
- Highly optimized BLAS/LAPACK routines
- 5-10× faster for large matrices
- Hardware-accelerated

**Cons:**
- Platform-specific (no Linux)
- External dependency
- More complex conditional compilation

**Decision:** Start with pure Swift, add Accelerate as opt-in optimization later.

### Q: How to handle missing data?

Options:
1. Require complete data (simplest - start here)
2. Listwise deletion (drop rows with missing)
3. Imputation (mean, median, regression)

**Decision:** Start with complete data requirement. Add imputation in V2.

### Q: Should we support categorical predictors?

Categorical variables need dummy encoding. Options:
1. Require users to pre-encode
2. Auto-encode with `[String]` predictors

**Decision:** Require pre-encoding initially. Add helper in V2:

```swift
func oneHotEncode(_ categories: [String]) -> [[Double]]
```

---

## Related Work

### Existing BusinessMath Features
- `linearRegression()` - simple regression (keep for convenience)
- `rSquared()` - already works for multiple regression
- `rSquaredAdjusted()` - already supports multiple predictors!
- `slope()`, `intercept()` - simple regression components
- `SparseMatrix` - efficient for large sparse designs
- `DataTable` - sensitivity analysis of coefficients

### External Libraries (Comparison)
- **R `lm()`**: Gold standard, comprehensive diagnostics
- **Python `sklearn.LinearRegression`**: Simple API, fewer diagnostics
- **Python `statsmodels.OLS`**: R-like, extensive statistics
- **Julia `GLM.jl`**: Fast, type-generic

**Our Niche:** Swift-native, type-safe, comprehensive diagnostics, BusinessMath integration

---

## Conclusion

This implementation will:
1. ✅ Fill the gap between simple and nonlinear regression
2. ✅ Enable real-world use cases (pricing extraction, forecasting)
3. ✅ Maintain BusinessMath quality standards (tested, documented, performant)
4. ✅ Integrate seamlessly with existing features
5. ✅ Provide foundation for advanced regression (ridge, lasso, stepwise)

**Total Effort:** 3-5 days (500-800 lines + 400-600 test lines + documentation)

**Priority:** High - addresses user need, completes regression capabilities

**Next Steps:**
1. Review and approve plan
2. Create feature branch `feature/multiple-linear-regression`
3. Implement Phase 1 (matrix infrastructure)
4. Iterate through phases with tests and docs
5. Code review and merge to main

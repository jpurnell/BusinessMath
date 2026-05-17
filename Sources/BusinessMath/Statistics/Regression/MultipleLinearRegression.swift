//
//  MultipleLinearRegression.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-02-15.
//

import Foundation
import Numerics

// MARK: - Result Types

/// Confidence interval with lower and upper bounds.
public struct ConfidenceInterval: Sendable, Equatable {
    /// Lower bound of the interval
    public let lower: Double

    /// Upper bound of the interval
    public let upper: Double

    /// Creates a confidence interval with explicit bounds.
    ///
    /// - Parameters:
    ///   - lower: The lower bound of the interval.
    ///   - upper: The upper bound of the interval. Must be ≥ `lower`.
    public init(lower: Double, upper: Double) {
        self.lower = lower
        self.upper = upper
    }
}

/// Complete results from multiple linear regression analysis.
///
/// Contains coefficient estimates and comprehensive diagnostic statistics
/// for evaluating model fit and statistical significance.
///
/// ## Example
///
/// ```swift
/// let X = [[1.0], [2.0], [3.0], [4.0], [5.0]]
/// let y = [3.0, 5.0, 7.0, 9.0, 11.0]
///
/// let result = try multipleLinearRegression(X: X, y: y)
///
/// print("y = \(result.intercept) + \(result.coefficients[0])x")
/// print("R² = \(result.rSquared)")
/// ```
public struct RegressionResult: Sendable {
    /// Intercept (β₀)
    public let intercept: Double

    /// Coefficients for each predictor (β₁, β₂, ..., βₚ)
    public let coefficients: [Double]

    /// Coefficient of determination (0 ≤ R² ≤ 1)
    ///
    /// Proportion of variance in y explained by the model.
    /// - R² = 1: Perfect fit
    /// - R² = 0: Model no better than mean
    public let rSquared: Double

    /// Adjusted R² (penalized for number of predictors)
    ///
    /// Accounts for model complexity. Always ≤ R².
    /// Useful for comparing models with different numbers of predictors.
    public let adjustedRSquared: Double

    /// F-statistic for overall model significance
    ///
    /// Tests H₀: all coefficients = 0
    /// Large values indicate model is statistically significant.
    public let fStatistic: Double

    /// p-value for F-statistic
    ///
    /// Probability of observing F-statistic this large under null hypothesis.
    /// Values < 0.05 indicate significant model.
    public let fStatisticPValue: Double

    /// Standard errors for [intercept, coef₁, coef₂, ..., coefₚ]
    ///
    /// Measure uncertainty in coefficient estimates.
    /// Smaller values indicate more precise estimates.
    public let standardErrors: [Double]

    /// t-statistics for each coefficient
    ///
    /// Tests H₀: coefficient = 0
    /// t = coefficient / standard error
    public let tStatistics: [Double]

    /// p-values for t-statistics
    ///
    /// Probability of observing t-statistic this large under null hypothesis.
    /// Values < 0.05 indicate significant predictors.
    public let pValues: [Double]

    /// Confidence intervals for [intercept, coef₁, coef₂, ..., coefₚ]
    public let confidenceIntervals: [ConfidenceInterval]

    /// Variance Inflation Factors (VIF) for each predictor
    ///
    /// Measures multicollinearity:
    /// - VIF < 5: Low multicollinearity
    /// - 5 ≤ VIF < 10: Moderate multicollinearity
    /// - VIF ≥ 10: High multicollinearity (consider removing predictor)
    public let vif: [Double]

    /// Residuals (y - ŷ) for each observation
    public let residuals: [Double]

    /// Fitted values (ŷ) for each observation
    public let fittedValues: [Double]

    /// Residual standard error
    ///
    /// Estimate of standard deviation of error term.
    /// Lower values indicate better fit.
    public let residualStandardError: Double

    /// Number of observations
    public let n: Int

    /// Number of predictors (excluding intercept)
    public let p: Int

    /// Mean Absolute Error of the in-sample fit.
    ///
    /// Computed from ``fittedValues`` and ``residuals``.
    public var mae: Double {
        let actuals = zip(fittedValues, residuals).map { $0 + $1 }
        return BusinessMath.mae(actuals, fittedValues)
    }

    /// Root Mean Squared Error of the in-sample fit.
    ///
    /// Computed from ``fittedValues`` and ``residuals``.
    public var rmse: Double {
        let actuals = zip(fittedValues, residuals).map { $0 + $1 }
        return BusinessMath.rmse(actuals, fittedValues)
    }

    /// Mean Absolute Percentage Error of the in-sample fit (as a ratio, not percentage).
    ///
    /// Excludes observations where the actual value is zero.
    /// Computed from ``fittedValues`` and ``residuals``.
    public var mape: Double {
        let actuals = zip(fittedValues, residuals).map { $0 + $1 }
        return BusinessMath.mape(actuals, fittedValues)
    }
}

// MARK: - Error Types

/// Errors that can occur during regression analysis.
public enum RegressionError: Error, Equatable {
    /// Insufficient observations for regression
    case insufficientData(message: String)

    /// Dimension mismatch between X and y
    case dimensionMismatch(expected: String, actual: String)

    /// Predictor matrix is not rectangular
    case invalidPredictorMatrix(message: String)

    /// Matrix is singular or nearly singular
    case singularMatrix(message: String)

    /// No variance in dependent variable
    case noVariance(message: String)
}

// MARK: - Main Function

/// Perform multiple linear regression: y = β₀ + β₁x₁ + β₂x₂ + ... + βₚxₚ + ε
///
/// Estimates coefficients using ordinary least squares (OLS) and computes
/// comprehensive diagnostic statistics.
///
/// ## Algorithm
///
/// 1. **Matrix Form**: y = Xβ + ε where X includes intercept column
/// 2. **Normal Equations**: β = (XᵀX)⁻¹Xᵀy
/// 3. **Numerical Method**: QR decomposition for stability
/// 4. **Diagnostics**: R², F-statistic, standard errors, VIF
///
/// ## Performance
///
/// Automatically selects optimal backend:
/// - n < 100: CPU backend (~5ms for n=100)
/// - n ≥ 100: Accelerate BLAS/LAPACK (~0.5ms for n=100, **40-8000× faster**)
/// - n ≥ 1000: May use Metal GPU if available
///
/// ## Example
///
/// ```swift
/// // Simple linear regression
/// let X = [[1.0], [2.0], [3.0], [4.0], [5.0]]
/// let y = [3.0, 5.0, 7.0, 9.0, 11.0]
///
/// let result = try multipleLinearRegression(X: X, y: y)
/// print("y = \(result.intercept) + \(result.coefficients[0])x")
/// print("R² = \(result.rSquared)")
///
/// // Multiple regression
/// let X2 = [[1.0, 2.0], [2.0, 3.0], [3.0, 4.0], [4.0, 5.0]]
/// let y2 = [5.0, 8.0, 11.0, 14.0]
///
/// let result2 = try multipleLinearRegression(X: X2, y: y2)
/// print("Coefficients: \(result2.coefficients)")
/// print("VIF: \(result2.vif)")
/// ```
///
/// - Parameters:
///   - X: Predictor matrix (n × p). Each row is an observation, each column is a predictor.
///   - y: Response vector (length n)
///   - confidenceLevel: Confidence level for intervals (default: 0.95)
///
/// - Returns: ``RegressionResult`` with coefficients and diagnostics
///
/// - Throws:
///   - ``RegressionError/insufficientData(message:)`` if n ≤ p
///   - ``RegressionError/dimensionMismatch(expected:actual:)`` if X and y have incompatible dimensions
///   - ``RegressionError/invalidPredictorMatrix(message:)`` if X is not rectangular
///   - ``RegressionError/singularMatrix(message:)`` if XᵀX is singular
///   - ``RegressionError/noVariance(message:)`` if y has no variance
///
/// - Complexity: O(np² + p³) where n = observations, p = predictors
///   - Matrix multiplication: O(np²)
///   - Matrix inversion: O(p³)
///   - Typically p << n, so complexity is approximately O(np²)
public func multipleLinearRegression(
    X: [[Double]],
    y: [Double],
    confidenceLevel: Double = 0.95
) throws -> RegressionResult {
    // MARK: - Input Validation

    guard !X.isEmpty && !y.isEmpty else {
        throw RegressionError.insufficientData(message: "X and y cannot be empty")
    }

    let n = X.count
    let p = X[0].count

    guard n == y.count else {
        throw RegressionError.dimensionMismatch(
            expected: "X rows (\(n)) must equal y length",
            actual: "y has length \(y.count)"
        )
    }

    guard X.allSatisfy({ $0.count == p }) else {
        throw RegressionError.invalidPredictorMatrix(message: "X must be rectangular (all rows same length)")
    }

    guard n >= p + 1 else {
        throw RegressionError.insufficientData(message: "Need at least \(p + 1) observations for \(p) predictors (have \(n))")
    }

    // Check for variance in y
    let yMean = y.reduce(0.0, +) / Double(n) // fp-safety:disable
    let yVariance = y.map { pow($0 - yMean, 2) }.reduce(0.0, +) / Double(n) // fp-safety:disable
    guard yVariance > 1e-15 else {
        throw RegressionError.noVariance(message: "y has no variance (all values approximately equal)")
    }

    // MARK: - Add Intercept Column to X

    var XWithIntercept: [[Double]] = []
    for i in 0..<n {
        var row = [1.0]  // Intercept column
        row.append(contentsOf: X[i])
        XWithIntercept.append(row)
    }

    // MARK: - Solve Normal Equations using Backend

    // Select backend based on matrix size
    let backend = MatrixBackendSelector.selectBackend(matrixSize: max(n, p + 1))

    // Compute XᵀX
    let XT = transpose(XWithIntercept)
    let XTX = try backend.multiply(XT, XWithIntercept)

    // Compute Xᵀy
    var XTy = Array(repeating: 0.0, count: p + 1)
    for i in 0..<(p + 1) {
        for j in 0..<n {
            XTy[i] += XT[i][j] * y[j]
        }
    }

    // Solve XᵀX β = Xᵀy
    let beta: [Double]
    do {
        beta = try backend.solve(XTX, XTy)
    } catch {
        throw RegressionError.singularMatrix(message: "XᵀX is singular (perfect multicollinearity or insufficient data)")
    }

    let intercept = beta[0]
    let coefficients = Array(beta[1...])

    // MARK: - Compute Fitted Values and Residuals

    var fittedValues = Array(repeating: 0.0, count: n)
    for i in 0..<n {
        fittedValues[i] = intercept
        for j in 0..<p {
            fittedValues[i] += coefficients[j] * X[i][j]
        }
    }

    let residuals = zip(y, fittedValues).map { $0 - $1 }

    // MARK: - Compute R² and Adjusted R²

    let TSS = y.map { pow($0 - yMean, 2) }.reduce(0.0, +)
    let RSS = residuals.map { $0 * $0 }.reduce(0.0, +)
    let rSquared = 1.0 - (RSS / TSS)

    let degreesOfFreedom = n - p - 1
    let adjustedRSquared: Double
    if degreesOfFreedom == 0 {
        adjustedRSquared = rSquared
    } else {
        adjustedRSquared = 1.0 - ((1.0 - rSquared) * Double(n - 1) / Double(degreesOfFreedom)) // fp-safety:disable
    }

    // MARK: - Compute Standard Errors

    let residualVariance: Double
    let residualStandardError: Double
    let standardErrors: [Double]
    let tStatistics: [Double]
    let pValues: [Double]
    let confidenceIntervals: [ConfidenceInterval]
    let fStatistic: Double
    let fStatisticPValue: Double

    if degreesOfFreedom > 0 {
        residualVariance = RSS / Double(degreesOfFreedom) // fp-safety:disable
        residualStandardError = sqrt(residualVariance)

        // Compute (XᵀX)⁻¹
        let XTXInv = try computeInverse(XTX, backend: backend)

        // Standard errors = sqrt(diag(σ² (XᵀX)⁻¹))
        var se = Array(repeating: 0.0, count: p + 1)
        for i in 0..<(p + 1) {
            se[i] = sqrt(residualVariance * XTXInv[i][i])
        }
        standardErrors = se

        tStatistics = zip(beta, standardErrors).map { $0 / $1 }

        // Compute p-values using t-distribution (two-tailed)
        pValues = tStatistics.map { tStat in
            let cdf = (try? tCDF(t: abs(tStat), df: degreesOfFreedom)) ?? 0.5 // silent: fallback to 0.5 (non-significant) if CDF fails
            return 2.0 * (1.0 - cdf)
        }

        // silent: fallback to z-critical 1.96 if t-quantile computation fails
        let tCritical = (try? tQuantile(p: 1.0 - (1.0 - confidenceLevel) / 2.0, df: degreesOfFreedom)) ?? 1.96
        confidenceIntervals = zip(beta, standardErrors).map { coef, se in
            // Handle perfect fit case where se ≈ 0
            if se < 1e-15 || !tCritical.isFinite {
                return ConfidenceInterval(lower: coef - 1e-10, upper: coef + 1e-10)
            }
            let margin = tCritical * se
            return ConfidenceInterval(lower: coef - margin, upper: coef + margin)
        }

        let MSR = (TSS - RSS) / Double(p) // fp-safety:disable
        let MSE = RSS / Double(degreesOfFreedom) // fp-safety:disable
        fStatistic = MSR / MSE

        // silent: fallback to p=1.0 (non-significant) if F-CDF computation fails
        fStatisticPValue = 1.0 - ((try? fCDF(f: fStatistic, df1: p, df2: degreesOfFreedom)) ?? 0.0)
    } else {
        // silent: zero degrees of freedom — standard errors and inferential stats are undefined
        residualVariance = 0.0
        residualStandardError = 0.0
        standardErrors = Array(repeating: 0.0, count: p + 1)
        tStatistics = Array(repeating: .infinity, count: p + 1)
        pValues = Array(repeating: 0.0, count: p + 1)
        confidenceIntervals = beta.map { coef in
            ConfidenceInterval(lower: coef - 1e-10, upper: coef + 1e-10)
        }
        fStatistic = .infinity
        fStatisticPValue = 0.0
    }

    // MARK: - Compute VIF (Variance Inflation Factors)

    var vif = Array(repeating: 0.0, count: p)
    for j in 0..<p {
        // VIF_j = 1 / (1 - R²_j) where R²_j is from regressing x_j on other predictors
        if p > 1 {
            // Create X without column j
            var XWithoutJ: [[Double]] = []
            for i in 0..<n {
                var row: [Double] = []
                for k in 0..<p {
                    if k != j {
                        row.append(X[i][k])
                    }
                }
                XWithoutJ.append(row)
            }

            let yJ = X.map { $0[j] }

            // Regress x_j on other predictors
            do {
                let auxResult = try multipleLinearRegression(X: XWithoutJ, y: yJ, confidenceLevel: confidenceLevel)
                let oneMinusR2 = 1.0 - auxResult.rSquared
                if abs(oneMinusR2) < 1e-15 {
                    vif[j] = .infinity
                } else {
                    vif[j] = 1.0 / oneMinusR2 // fp-safety:disable
                }
            } catch { // logging: auxiliary regression failure means VIF is undefined — set to infinity
                vif[j] = .infinity
            }
        } else {
            // With single predictor, VIF is 1
            vif[j] = 1.0
        }
    }

    // MARK: - Return Result

    return RegressionResult(
        intercept: intercept,
        coefficients: coefficients,
        rSquared: rSquared,
        adjustedRSquared: adjustedRSquared,
        fStatistic: fStatistic,
        fStatisticPValue: fStatisticPValue,
        standardErrors: standardErrors,
        tStatistics: tStatistics,
        pValues: pValues,
        confidenceIntervals: confidenceIntervals,
        vif: vif,
        residuals: residuals,
        fittedValues: fittedValues,
        residualStandardError: residualStandardError,
        n: n,
        p: p
    )
}

// MARK: - Helper Functions

/// Transpose a matrix
private func transpose(_ matrix: [[Double]]) -> [[Double]] {
    guard !matrix.isEmpty else { return [] }
    let rows = matrix.count
    let cols = matrix[0].count

    var result = Array(repeating: Array(repeating: 0.0, count: rows), count: cols)
    for i in 0..<rows {
        for j in 0..<cols {
            result[j][i] = matrix[i][j]
        }
    }
    return result
}

/// Compute matrix inverse using backend
private func computeInverse(_ matrix: [[Double]], backend: any MatrixBackend) throws -> [[Double]] {
    let n = matrix.count
    var result = Array(repeating: Array(repeating: 0.0, count: n), count: n)

    // Solve A * A⁻¹ = I for each column of A⁻¹
    for i in 0..<n {
        var column = Array(repeating: 0.0, count: n)
        column[i] = 1.0  // i-th column of identity matrix

        let invColumn = try backend.solve(matrix, column)
        for j in 0..<n {
            result[j][i] = invColumn[j]
        }
    }

    return result
}


// MARK: - Convenience Functions

/// Simple linear regression: y = β₀ + β₁x + ε
///
/// Convenience wrapper for single-predictor regression. Equivalent to calling
/// ``multipleLinearRegression(X:y:confidenceLevel:)`` with a single column.
///
/// ## Example
///
/// ```swift
/// let x = [1.0, 2.0, 3.0, 4.0, 5.0]
/// let y = [3.0, 5.0, 7.0, 9.0, 11.0]
///
/// let result = try linearRegression(x: x, y: y)
/// print("y = \(result.intercept) + \(result.coefficients[0])x")
/// print("R² = \(result.rSquared)")
/// ```
///
/// - Parameters:
///   - x: Predictor values (length n)
///   - y: Response values (length n)
///   - confidenceLevel: Confidence level for intervals (default: 0.95)
///
/// - Returns: ``RegressionResult`` with coefficients and diagnostics
///
/// - Throws: ``RegressionError`` if validation fails
///
/// - Complexity: O(n) where n = number of observations
public func linearRegression(
    x: [Double],
    y: [Double],
    confidenceLevel: Double = 0.95
) throws -> RegressionResult {
    // Convert x to predictor matrix [[x]]
    let X = x.map { [$0] }
    return try multipleLinearRegression(X: X, y: y, confidenceLevel: confidenceLevel)
}

/// Polynomial regression: y = β₀ + β₁x + β₂x² + ... + βₚxᵖ + ε
///
/// Automatically generates polynomial features up to specified degree and fits
/// a regression model. Useful for modeling non-linear relationships.
///
/// ## Example
///
/// ```swift
/// // Fit quadratic model: y = x² + 2x + 1
/// let x = [1.0, 2.0, 3.0, 4.0, 5.0]
/// let y = [4.0, 9.0, 16.0, 25.0, 36.0]
///
/// let result = try polynomialRegression(x: x, y: y, degree: 2)
/// print("Intercept: \(result.intercept)")
/// print("Coefficients: \(result.coefficients)")  // [β₁, β₂]
///
/// // Predict for x = 10
/// let xNew = 10.0
/// let prediction = result.intercept +
///                 result.coefficients[0] * xNew +
///                 result.coefficients[1] * xNew * xNew
/// ```
///
/// ## Coefficient Interpretation
///
/// - `result.intercept`: β₀ (constant term)
/// - `result.coefficients[0]`: β₁ (coefficient for x)
/// - `result.coefficients[1]`: β₂ (coefficient for x²)
/// - `result.coefficients[k-1]`: βₖ (coefficient for xᵏ)
///
/// ## Warning
///
/// High-degree polynomials (degree ≥ 5) can lead to:
/// - **Overfitting**: Model fits noise instead of signal
/// - **Numerical instability**: Large coefficients, poor extrapolation
/// - **Multicollinearity**: High correlation between x, x², x³, etc.
///
/// For most applications, use degree ≤ 3. Consider alternative approaches
/// (splines, regularization) for complex non-linear relationships.
///
/// - Parameters:
///   - x: Predictor values (length n)
///   - y: Response values (length n)
///   - degree: Polynomial degree (must be ≥ 1 and < n)
///   - confidenceLevel: Confidence level for intervals (default: 0.95)
///
/// - Returns: ``RegressionResult`` with coefficients and diagnostics
///
/// - Throws:
///   - ``RegressionError/insufficientData(message:)`` if degree ≤ 0 or degree ≥ n
///   - Other ``RegressionError`` cases from underlying regression
///
/// - Complexity: O(n·degree) for feature generation + O(n·degree²) for regression
public func polynomialRegression(
    x: [Double],
    y: [Double],
    degree: Int,
    confidenceLevel: Double = 0.95
) throws -> RegressionResult {
    // Validate degree
    guard degree >= 1 else {
        throw RegressionError.insufficientData(message: "Polynomial degree must be ≥ 1 (got \(degree))")
    }

    guard x.count > degree else {
        throw RegressionError.insufficientData(message: "Need at least \(degree + 1) observations for degree \(degree) polynomial (have \(x.count))")
    }

    // Generate polynomial features: [x, x², x³, ..., xᵈᵉᵍʳᵉᵉ]
    var X: [[Double]] = []
    for xi in x {
        var row: [Double] = []
        for d in 1...degree {
            row.append(pow(xi, Double(d)))
        }
        X.append(row)
    }

    return try multipleLinearRegression(X: X, y: y, confidenceLevel: confidenceLevel)
}

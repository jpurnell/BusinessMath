//
//  kendallW.swift
//  BusinessMath
//
//  Created by Justin Purnell on 3/10/26.
//

import Foundation
import Numerics

/// Calculates Kendall's W coefficient of concordance from a ranking matrix.
///
/// Kendall's W measures the agreement among multiple judges (raters) when
/// ranking multiple items. Values range from 0 (no agreement beyond chance)
/// to 1 (perfect agreement).
///
/// ## Overview
///
/// The coefficient is widely used in:
/// - Wine tasting panels
/// - Academic paper reviews
/// - Consumer preference studies
/// - Any scenario with multiple rankers assessing the same items
///
/// ## Usage Example
///
/// ```swift
/// // 3 judges ranking 4 items with perfect agreement
/// let rankings: [[Double]] = [
///     [1, 2, 3, 4],  // Judge 0
///     [1, 2, 3, 4],  // Judge 1
///     [1, 2, 3, 4],  // Judge 2
/// ]
/// let w = kendallW(rankings)
/// // w = 1.0 (perfect agreement)
///
/// // 3 judges with complete disagreement
/// let disagreement: [[Double]] = [
///     [1, 2, 3],
///     [2, 3, 1],
///     [3, 1, 2],
/// ]
/// let w2 = kendallW(disagreement)
/// // w2 = 0.0 (no agreement)
/// ```
///
/// ## Input Format
///
/// The rankings matrix should be organized as:
/// - **Rows**: Each row represents one judge's rankings
/// - **Columns**: Each column represents one item being ranked
/// - **Values**: The rank assigned by that judge to that item (typically 1 to k)
///
/// ## Mathematical Background
///
/// The formula is: W = 12S / (n²(k³-k))
///
/// where:
/// - S = Σ(Ri - R̄)² (sum of squared deviations from mean rank sum)
/// - n = number of judges (rows)
/// - k = number of items (columns)
/// - Ri = rank sum for item i (sum of column i)
/// - R̄ = mean of rank sums
///
/// ## Statistical Interpretation
///
/// | W Value | Interpretation |
/// |---------|----------------|
/// | 0.0     | No agreement (random ranking) |
/// | 0.1-0.3 | Weak agreement |
/// | 0.3-0.5 | Moderate agreement |
/// | 0.5-0.7 | Good agreement |
/// | 0.7-0.9 | Strong agreement |
/// | 0.9-1.0 | Very strong to perfect agreement |
///
/// - Parameter rankings: A 2D array where rows are judges and columns are items.
///   Each cell contains the rank assigned by that judge to that item.
///
/// - Returns: Kendall's W coefficient in range [0, 1].
///   Returns NaN if the matrix is empty or has fewer than 2 items.
///   Returns 0 if all rank sums are equal (zero variance).
///
/// - Complexity: O(n × k) where n is judges and k is items.
///
/// - SeeAlso: ``friedmanChiSquare(_:)``
/// - SeeAlso: ``fStatistic(kendallW:items:)``
public func kendallW<T: Real>(_ rankings: [[T]]) -> T {
    // Validate input
    guard !rankings.isEmpty else { return T.nan }
    guard let firstRow = rankings.first, !firstRow.isEmpty else { return T.nan }

    let judges = rankings.count      // n = number of rows
    let items = firstRow.count       // k = number of columns

    // Need at least 2 items for concordance to be meaningful
    guard items >= 2 else { return T.nan }

    // Compute rank sums (sum each column)
    var rankSums: [T] = Array(repeating: T(0), count: items)
    for row in rankings {
        for (col, rank) in row.enumerated() where col < items {
            rankSums[col] += rank
        }
    }

    // Calculate using the internal function
    return kendallWFromRankSums(rankSums: rankSums, judges: judges, items: items)
}

/// Internal function to calculate Kendall's W from pre-computed rank sums.
///
/// This is used by Array2D and other internal calculations.
///
/// - Parameters:
///   - rankSums: Array of rank sums for each item.
///   - judges: The number of judges (n).
///   - items: The number of items (k).
///
/// - Returns: Kendall's W coefficient in range [0, 1].
public func kendallWFromRankSums<T: Real>(rankSums: [T], judges: Int, items: Int) -> T {
    guard items >= 2, judges >= 1, !rankSums.isEmpty else {
        return T.nan
    }

    let n = T(judges)
    let k = T(items)

    // Calculate mean of rank sums
    let meanRankSum = rankSums.reduce(T(0), +) / T(rankSums.count)

    // Calculate S = sum of squared deviations from mean
    var s = T(0)
    for rankSum in rankSums {
        let deviation = rankSum - meanRankSum
        s += deviation * deviation
    }

    // If S is essentially zero, there's no agreement variance
    guard abs(s) > T.ulpOfOne else {
        return T(0)
    }

    // W = 12S / (n²(k³-k))
    let denominator = n * n * (k * k * k - k)

    // Guard against division by zero
    guard abs(denominator) > T.ulpOfOne else {
        return T.nan
    }

    let w = (T(12) * s) / denominator

    // Clamp to valid range [0, 1] to handle floating-point errors
    return max(T(0), min(T(1), w))
}

// MARK: - Concordance Analysis Result

/// The result of a concordance analysis, containing agreement statistics and significance tests.
///
/// Provides Kendall's W (both raw and tie-corrected), chi-squared and Friedman test statistics,
/// degrees of freedom, p-value, and F-statistic for assessing inter-rater agreement.
public struct ConcordanceResult<T: Real>: Sendable where T: Sendable {
    /// Kendall's W coefficient of concordance (uncorrected for ties).
    public let w: T
    /// Kendall's W corrected for tied ranks within judges.
    public let wCorrected: T
    /// Chi-squared statistic for testing significance of agreement.
    public let chiSquare: T
    /// Friedman test statistic derived from the rank sums.
    public let friedman: T
    /// Degrees of freedom for the chi-squared test (items - 1).
    public let degreesOfFreedom: Int
    /// P-value for the null hypothesis of no agreement.
    public let pValue: T
    /// F-statistic approximation for small-sample significance testing.
    public let fStatistic: T
    /// The number of judges (raters) in the analysis.
    public let judges: Int
    /// The number of items (objects) being ranked.
    public let items: Int
    /// Total tie correction factor summed across all judges.
    public let totalTieCorrection: T
}

// MARK: - Concordance Analysis (Full Matrix)

/// Performs a full concordance analysis on a ranking matrix with tie correction.
///
/// Computes Kendall's W, chi-squared statistic, Friedman statistic, p-value,
/// and F-statistic. Automatically detects and corrects for tied ranks.
///
/// - Parameter rankings: A 2D array where rows are judges and columns are items.
/// - Returns: A ``ConcordanceResult`` with all agreement statistics.
/// - Throws: `BusinessMathError.invalidInput` if the matrix is empty or has fewer than 2 items.
public func concordanceAnalysis<T: Real & Sendable>(_ rankings: [[T]]) throws -> ConcordanceResult<T> {
    guard !rankings.isEmpty else {
        throw BusinessMathError.invalidInput(
            message: "Rankings matrix must not be empty",
            value: "empty", expectedRange: "at least 1 judge")
    }
    guard let firstRow = rankings.first, firstRow.count >= 2 else {
        throw BusinessMathError.invalidInput(
            message: "Need at least 2 items to measure concordance",
            value: "\(rankings.first?.count ?? 0)", expectedRange: "[2, ∞)")
    }

    let m = rankings.count
    let n = firstRow.count

    var rankSums: [T] = Array(repeating: T(0), count: n)
    for row in rankings {
        for (col, rank) in row.enumerated() where col < n {
            rankSums[col] += rank
        }
    }

    var totalT = T(0)
    for row in rankings {
        let sorted = row.sorted()
        var i = 0
        while i < sorted.count {
            var j = i
            while j < sorted.count - 1 && sorted[j] == sorted[j + 1] { j += 1 }
            if j > i {
                let tieSize = T(j - i + 1)
                totalT += tieSize * tieSize * tieSize - tieSize
            }
            i = j + 1
        }
    }

    let mT = T(m)
    let nT = T(n)
    let meanRankSum = rankSums.reduce(T(0), +) / nT

    var s = T(0)
    for rankSum in rankSums {
        let deviation = rankSum - meanRankSum
        s += deviation * deviation
    }

    let denomUncorrected = mT * mT * (nT * nT * nT - nT)
    let w: T
    if abs(denomUncorrected) > T.ulpOfOne {
        w = max(T(0), min(T(1), (T(12) * s) / denomUncorrected))
    } else {
        w = T.nan
    }

    let denomCorrected = denomUncorrected - mT * totalT
    let wCorrected: T
    if abs(denomCorrected) > T.ulpOfOne {
        wCorrected = max(T(0), min(T(1), (T(12) * s) / denomCorrected))
    } else {
        wCorrected = w
    }

    let chi2 = mT * (nT - T(1)) * wCorrected
    let df = n - 1

    let sigmaVal = sigma(rankSums: rankSums)
    let friedCoeff = T(12) / (mT * nT * (nT + T(1)))
    let friedSub = T(3) * mT * (nT + T(1))
    let friedman = max(T(0), friedCoeff * sigmaVal - friedSub)

    let pValue: T
    if chi2 > T(0) && df > 0 {
        let cdf = try chiSquaredCDF(x: chi2, df: df)
        pValue = T(1) - cdf
    } else {
        pValue = T(1)
    }

    let f = fStatistic(kendallW: wCorrected, items: n)

    return ConcordanceResult(
        w: w, wCorrected: wCorrected, chiSquare: chi2, friedman: friedman,
        degreesOfFreedom: df, pValue: pValue, fStatistic: f,
        judges: m, items: n, totalTieCorrection: totalT
    )
}

// MARK: - Concordance Analysis (From Rank Sums)

/// Performs concordance analysis from pre-computed rank sums (no tie correction).
///
/// Use this when you have already computed column-wise rank sums externally
/// (e.g., from an `Array2D`). Since individual judge rows are not available,
/// tie correction is not applied.
///
/// - Parameters:
///   - rankSums: Array of rank sums for each item.
///   - judges: The number of judges (n).
///   - items: The number of items (k).
/// - Returns: A ``ConcordanceResult`` with agreement statistics.
/// - Throws: `BusinessMathError.invalidInput` if items < 2 or judges < 1.
public func concordanceAnalysisFromRankSums<T: Real & Sendable>(
    rankSums: [T], judges: Int, items: Int
) throws -> ConcordanceResult<T> {
    guard items >= 2, judges >= 1, !rankSums.isEmpty else {
        throw BusinessMathError.invalidInput(
            message: "Need at least 2 items and 1 judge",
            value: "judges=\(judges), items=\(items)",
            expectedRange: "judges≥1, items≥2")
    }

    let m = T(judges)
    let n = T(items)
    let meanRankSum = rankSums.reduce(T(0), +) / n

    var s = T(0)
    for rankSum in rankSums {
        let deviation = rankSum - meanRankSum
        s += deviation * deviation
    }

    let denom = m * m * (n * n * n - n)
    let w: T
    if abs(denom) > T.ulpOfOne {
        w = max(T(0), min(T(1), (T(12) * s) / denom))
    } else {
        w = T.nan
    }

    let chi2 = m * (n - T(1)) * w
    let df = items - 1

    let sigmaVal = sigma(rankSums: rankSums)
    let friedCoeff = T(12) / (m * n * (n + T(1)))
    let friedSub = T(3) * m * (n + T(1))
    let friedman = max(T(0), friedCoeff * sigmaVal - friedSub)

    let pValue: T
    if chi2 > T(0) && df > 0 {
        let cdf = try chiSquaredCDF(x: chi2, df: df)
        pValue = T(1) - cdf
    } else {
        pValue = T(1)
    }

    let f = fStatistic(kendallW: w, items: items)

    return ConcordanceResult(
        w: w, wCorrected: w, chiSquare: chi2, friedman: friedman,
        degreesOfFreedom: df, pValue: pValue, fStatistic: f,
        judges: judges, items: items, totalTieCorrection: T(0)
    )
}

// MARK: - Concordance with Missing Data (Brueckl 2011)

/// Performs concordance analysis on rankings with missing data using the Brueckl (2011) method.
///
/// Uses pairwise Spearman correlations weighted by overlap size to estimate W
/// when some judges have not rated all items.
///
/// - Parameter rankings: A 2D array of optional ranks (nil = missing rating).
/// - Returns: A ``ConcordanceResult`` with agreement statistics.
/// - Throws: `BusinessMathError.invalidInput` if the matrix is empty or has fewer than 2 items.
///   `BusinessMathError.insufficientData` if fewer than 2 judges have at least 2 ratings.
public func concordanceAnalysisNA<T: Real & Sendable>(_ rankings: [[T?]]) throws -> ConcordanceResult<T> {
    guard !rankings.isEmpty else {
        throw BusinessMathError.invalidInput(
            message: "Rankings matrix must not be empty",
            value: "empty", expectedRange: "at least 1 judge")
    }

    let totalItems = rankings.map { $0.count }.max() ?? 0
    guard totalItems >= 2 else {
        throw BusinessMathError.invalidInput(
            message: "Need at least 2 items to measure concordance",
            value: "\(totalItems)", expectedRange: "[2, ∞)")
    }

    let m = rankings.count
    let mEff = rankings.filter { $0.compactMap({ $0 }).count >= 2 }.count
    guard mEff >= 2 else {
        throw BusinessMathError.insufficientData(
            required: 2, actual: mEff,
            context: "concordanceAnalysisNA requires at least 2 judges with ≥2 ratings")
    }

    var weightedRhoSum = T(0)
    var totalWeight = T(0)
    var validPairs = 0

    for i in 0..<m {
        for j in (i + 1)..<m {
            var xVals: [T] = []
            var yVals: [T] = []
            let itemCount = min(rankings[i].count, rankings[j].count)
            for k in 0..<itemCount {
                if let xi = rankings[i][k], let xj = rankings[j][k] {
                    xVals.append(xi)
                    yVals.append(xj)
                }
            }
            guard xVals.count >= 2 else { continue }
            let rho = try spearmansRho(xVals, vs: yVals)
            guard !rho.isNaN else { continue }
            let weight = T(xVals.count - 1)
            weightedRhoSum += weight * rho
            totalWeight += weight
            validPairs += 1
        }
    }

    guard validPairs > 0 else {
        throw BusinessMathError.insufficientData(
            required: 1, actual: 0,
            context: "No judge pairs share enough items for Spearman correlation")
    }

    let rhoBar = weightedRhoSum / totalWeight
    let mEffT = T(mEff)
    let w = max(T(0), min(T(1), (rhoBar * (mEffT - T(1)) + T(1)) / mEffT))

    let nT = T(totalItems)
    let chi2 = mEffT * (nT - T(1)) * w
    let df = totalItems - 1

    let pValue: T
    if chi2 > T(0) && df > 0 {
        let cdf = try chiSquaredCDF(x: chi2, df: df)
        pValue = T(1) - cdf
    } else {
        pValue = T(1)
    }

    let f = fStatistic(kendallW: w, items: totalItems)

    return ConcordanceResult(
        w: w, wCorrected: w, chiSquare: chi2, friedman: chi2,
        degreesOfFreedom: df, pValue: pValue, fStatistic: f,
        judges: m, items: totalItems, totalTieCorrection: T(0)
    )
}

// MARK: - Permutation Test for Concordance

/// Estimates the p-value of Kendall's W using a permutation test.
///
/// Shuffles each judge's rankings independently to build a null distribution,
/// then computes the proportion of permuted W values that meet or exceed the observed W.
///
/// - Parameters:
///   - rankings: A 2D array where rows are judges and columns are items.
///   - permutations: Number of random permutations (default 10,000).
/// - Returns: A tuple of the observed W and its permutation-based p-value.
/// - Throws: `BusinessMathError.invalidInput` if W cannot be computed from the rankings.
public func concordancePermutationTest<T: Real & Sendable>(
    _ rankings: [[T]], permutations: Int = 10000
) throws -> (w: T, pValue: T) {
    let observedW = kendallW(rankings)

    guard !observedW.isNaN else {
        throw BusinessMathError.invalidInput(
            message: "Cannot compute Kendall's W from rankings",
            value: "NaN", expectedRange: "[0, 1]")
    }

    var countGE = 0

    for _ in 0..<permutations {
        var permuted = rankings
        for i in 0..<permuted.count {
            permuted[i].shuffle() // stochastic:exempt
        }
        let permW = kendallW(permuted)
        if permW >= observedW {
            countGE += 1
        }
    }

    let pValue = T(countGE) / T(permutations)
    return (w: observedW, pValue: pValue)
}

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
    guard let reduced = rankSums(from: rankings) else { return T.nan }

    // Concordance needs at least two items to be concordant about.
    guard reduced.items >= 2 else { return T.nan }

    return kendallWFromRankSums(
        rankSums: reduced.sums, judges: reduced.judges, items: reduced.items
    )
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

    // A `nan` `s` fails `abs(s) > ulpOfOne` exactly as a zero one does, so this guard — written
    // for "the rank sums are identical, there is no agreement variance" — was also absorbing
    // contaminated rankings and reporting measured zero concordance. This function's own
    // documentation promises `nan` for unusable input, and two other guards below return it.
    guard !s.isNaN else { return T.nan }

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
    // `min(T(1), .nan)` returns `1`, so clamping an uncomputable coefficient yields the
    // *maximum* one. Clamp only a real number; the floating-point tidy-up this guards
    // against is a value slightly outside [0, 1], not an absent one.
    return w.isNaN ? w : max(T(0), min(T(1), w))
}

// MARK: - Concordance Analysis Result

/// The result of a concordance analysis, containing agreement statistics and significance tests.
///
/// Provides Kendall's W (both raw and tie-corrected), chi-squared and Friedman test statistics,
/// degrees of freedom, p-value, and F-statistic for assessing inter-rater agreement.
///
/// ## Which figures account for ties
///
/// With `m` judges, `n` items, and `t` the size of each group of tied ranks within a judge:
///
/// | Property | Tie-corrected | Formula |
/// |---|---|---|
/// | ``w`` | no | `12S / (m²(n³ − n))` |
/// | ``wCorrected`` | yes | `12S / (m²(n³ − n) − m·Σ(t³ − t))` |
/// | ``chiSquare`` | yes | `m(n − 1)·wCorrected` |
/// | ``friedman`` | no | `12/(mn(n + 1))·ΣR² − 3m(n + 1)` |
/// | ``friedmanCorrected`` | yes | `friedman / (1 − Σ(t³ − t) / (m(n³ − n)))` |
/// | ``pValue`` | yes | upper tail of χ²(n − 1) at ``chiSquare`` |
/// | ``fStatistic`` | yes | `(n − 1)·wCorrected / (1 − wCorrected)` |
///
/// ``chiSquare`` and ``friedmanCorrected`` are the same statistic reached two ways, and both
/// equal what SciPy's `scipy.stats.friedmanchisquare` and R's `friedman.test` report; ``wCorrected``
/// equals R's `irr::kendall(..., correct = TRUE)`. The package's tests pin all of these to
/// recorded SciPy and R values on tied data.
///
/// The correction assumes tied items carry the **average** of the ranks they span (two items
/// tied for second and third both get 2.5). Ties are detected as equal values within a judge's
/// row, so ranks assigned any other way — both tied items given 2, say — are corrected as
/// though averaged, and the result will not match a tool that re-ranks the row itself.
///
/// When every judge ties every item there is no preference to measure: the corrected
/// denominator is zero, and every tie-corrected figure is `nan`, as it is in SciPy and R.
public struct ConcordanceResult<T: Real>: Sendable where T: Sendable {
    /// Kendall's W coefficient of concordance (uncorrected for ties).
    public let w: T
    /// Kendall's W corrected for tied ranks within judges.
    ///
    /// `nan` when every judge ties every item, because the corrected denominator is then zero.
    public let wCorrected: T
    /// Chi-squared statistic for testing significance of agreement, `m(n − 1)·wCorrected`.
    ///
    /// This is the tie-corrected Friedman statistic; it equals ``friedmanCorrected``.
    public let chiSquare: T
    /// The classic Friedman statistic, `12/(mn(n + 1))·ΣR² − 3m(n + 1)`, **not** corrected for ties.
    ///
    /// Kept with the meaning it has always had. With tied ranks it is smaller than the
    /// statistic SciPy and R report; use ``friedmanCorrected`` to match them.
    public let friedman: T
    /// The Friedman statistic corrected for tied ranks, as reported by SciPy's
    /// `scipy.stats.friedmanchisquare` and R's `friedman.test`.
    ///
    /// `friedman / C`, where `C = 1 − Σ(t³ − t) / (m(n³ − n))` and `t` runs over each group of
    /// tied ranks within each judge. Without ties `C = 1` and this equals ``friedman``. It is the
    /// same number as ``chiSquare``, `m(n − 1)·wCorrected`, reached through the Friedman form.
    ///
    /// `nan` when every judge ties every item (`C = 0`), as in SciPy and R. From
    /// ``concordanceAnalysisFromRankSums(rankSums:judges:items:)``, which never sees the judges'
    /// rows and so cannot detect ties, it equals ``friedman``.
    public let friedmanCorrected: T
    /// Degrees of freedom for the chi-squared test (items - 1).
    public let degreesOfFreedom: Int
    /// P-value for the null hypothesis of no agreement, from ``chiSquare``.
    ///
    /// `nan` when ``chiSquare`` is `nan`: an undefined statistic has no tail probability.
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
/// Tied items should carry the average of the ranks they span (2.5 and 2.5 for a tie across
/// second and third). The tie-corrected figures — ``ConcordanceResult/wCorrected``,
/// ``ConcordanceResult/chiSquare``, ``ConcordanceResult/friedmanCorrected``,
/// ``ConcordanceResult/pValue`` — match SciPy's `friedmanchisquare`, R's `friedman.test` and
/// R's `irr::kendall(correct = TRUE)`; ``ConcordanceResult/friedman`` is the classic
/// uncorrected statistic. See ``ConcordanceResult`` for the formulas.
///
/// ```swift
/// // Four judges, five wines; the second judge could not separate wines 2 and 3.
/// let rankings: [[Double]] = [
///     [1, 2,   3,   4, 5],
///     [1, 2.5, 2.5, 4, 5],
///     [2, 1,   3,   5, 4],
///     [1, 3,   2,   4, 5],
/// ]
/// let result = try concordanceAnalysis(rankings)
/// // result.wCorrected        ≈ 0.870253  (irr::kendall, correct = TRUE)
/// // result.friedmanCorrected ≈ 13.924051 (scipy friedmanchisquare, R friedman.test)
/// // result.pValue            ≈ 0.007541
/// ```
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
        let raw = (T(12) * s) / denomUncorrected
        // `min(T(1), .nan)` is `1`: clamping here turned an uncomputable coefficient into
        // perfect concordance, and carried the p-value below across 0.05 with it. The `else`
        // arm two lines down already had this right.
        w = raw.isNaN ? raw : max(T(0), min(T(1), raw))
    } else {
        w = T.nan
    }

    let denomCorrected = denomUncorrected - mT * totalT
    let wCorrected: T
    if abs(denomCorrected) > T.ulpOfOne {
        let rawCorrected = (T(12) * s) / denomCorrected
        wCorrected = rawCorrected.isNaN ? rawCorrected : max(T(0), min(T(1), rawCorrected))
    } else {
        // Only reachable when every judge ties every item: Σ(t³ − t) per judge is at most
        // n³ − n, so the corrected denominator is zero exactly then. W is 0/0. This used to fall
        // back to the uncorrected `w` — zero — and the p-value below to 1, reporting "no
        // agreement, certainly not significant" about a panel that expressed no preference at
        // all. SciPy's `friedmanchisquare`, R's `friedman.test` and `irr::kendall` all answer NaN.
        wCorrected = T.nan
    }

    let chi2 = mT * (nT - T(1)) * wCorrected
    let df = n - 1

    let sigmaVal = sigma(rankSums: rankSums)
    let friedCoeff = T(12) / (mT * nT * (nT + T(1)))
    let friedSub = T(3) * mT * (nT + T(1))
    let rawFriedman = friedCoeff * sigmaVal - friedSub
    // `max(T(0), .nan)` is `0` — no treatment effect — which sat in the same result object as
    // a W of 1.0 claiming perfect concordance. Same tidy-up, same trap as `friedmanChiSquare`.
    let friedman = rawFriedman.isNaN ? rawFriedman : max(T(0), rawFriedman)

    // Tie-corrected Friedman: divide by C = 1 − Σ(t³ − t) / (m(n³ − n)), the form SciPy and R
    // use. C is zero only when every judge ties everything, the same case as above.
    let cubeLessN: T = nT * nT * nT - nT
    let tieShare: T = totalT / (mT * cubeLessN)
    let tieFactor: T = T(1) - tieShare
    let friedmanCorrected: T = tieFactor > T.ulpOfOne ? friedman / tieFactor : T.nan

    let pValue = try concordancePValue(chiSquare: chi2, degreesOfFreedom: df)

    let f = fStatistic(kendallW: wCorrected, items: n)

    return ConcordanceResult(
        w: w, wCorrected: wCorrected, chiSquare: chi2, friedman: friedman,
        friedmanCorrected: friedmanCorrected,
        degreesOfFreedom: df, pValue: pValue, fStatistic: f,
        judges: m, items: n, totalTieCorrection: totalT
    )
}

/// Upper-tail chi-squared probability for a concordance statistic.
///
/// Shared by the three concordance entry points. A `nan` statistic has no tail probability:
/// `nan > 0` is false, so the guard below used to send it to the `else` arm and report
/// p = 1, a confident "not significant" about a statistic that could not be computed.
private func concordancePValue<T: Real>(chiSquare chi2: T, degreesOfFreedom df: Int) throws -> T {
    guard !chi2.isNaN else { return T.nan }
    guard chi2 > T(0) && df > 0 else { return T(1) }
    let cdf: T = try chiSquaredCDF(x: chi2, df: df)
    return T(1) - cdf
}

// MARK: - Concordance Analysis (From Rank Sums)

/// Performs concordance analysis from pre-computed rank sums (no tie correction).
///
/// Use this when you have already computed column-wise rank sums externally
/// (e.g., from an `Array2D`). Since individual judge rows are not available,
/// tie correction is not applied: `wCorrected` equals `w`, `friedmanCorrected` equals
/// `friedman`, and both will be below what SciPy or R report if the judges tied any items.
/// Use ``concordanceAnalysis(_:)`` with the full matrix when ties are possible.
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
        let raw = (T(12) * s) / denom
        // See the note on the clamp in `concordanceAnalysis`: `min(T(1), .nan)` is `1`.
        w = raw.isNaN ? raw : max(T(0), min(T(1), raw))
    } else {
        w = T.nan
    }

    let chi2 = m * (n - T(1)) * w
    let df = items - 1

    let sigmaVal = sigma(rankSums: rankSums)
    let friedCoeff = T(12) / (m * n * (n + T(1)))
    let friedSub = T(3) * m * (n + T(1))
    let rawFriedman = friedCoeff * sigmaVal - friedSub
    // `max(T(0), .nan)` is `0` — no treatment effect — which sat in the same result object as
    // a W of 1.0 claiming perfect concordance. Same tidy-up, same trap as `friedmanChiSquare`.
    let friedman = rawFriedman.isNaN ? rawFriedman : max(T(0), rawFriedman)

    let pValue = try concordancePValue(chiSquare: chi2, degreesOfFreedom: df)

    let f = fStatistic(kendallW: w, items: items)

    return ConcordanceResult(
        w: w, wCorrected: w, chiSquare: chi2, friedman: friedman, friedmanCorrected: friedman,
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
    let rawW = (rhoBar * (mEffT - T(1)) + T(1)) / mEffT
    let w = rawW.isNaN ? rawW : max(T(0), min(T(1), rawW))

    let nT = T(totalItems)
    let chi2 = mEffT * (nT - T(1)) * w
    let df = totalItems - 1

    let pValue = try concordancePValue(chiSquare: chi2, degreesOfFreedom: df)

    let f = fStatistic(kendallW: w, items: totalItems)

    return ConcordanceResult(
        w: w, wCorrected: w, chiSquare: chi2, friedman: chi2, friedmanCorrected: chi2,
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
/// The null distribution is built by shuffling, so the p-value is an estimate that
/// moves with the draw. Unseeded, the same rankings can land either side of a
/// significance threshold on consecutive calls — a reported significance that is not
/// reproducible is not a result anyone can act on. Pass `seed:` to fix it.
///
/// - Parameters:
///   - rankings: A 2D array where rows are judges and columns are items.
///   - permutations: Number of random permutations (default 10,000).
///   - seed: Fixes the permutations, and therefore the p-value.
/// - Returns: A tuple of the observed W and its permutation-based p-value.
/// - Throws: `BusinessMathError.invalidInput` if W cannot be computed from the rankings.
public func concordancePermutationTest<T: Real & Sendable>(
    _ rankings: [[T]], permutations: Int = 10000, seed: UInt64? = nil
) throws -> (w: T, pValue: T) {
    if let seed {
        var generator = DeterministicRNG(seed: seed)
        return try concordancePermutationTest(rankings, permutations: permutations, using: &generator)
    }
    var generator = SystemRandomNumberGenerator() // stochastic:exempt — the documented unseeded path; pass `seed:` for reproducibility
    return try concordancePermutationTest(rankings, permutations: permutations, using: &generator)
}

/// Estimates the p-value of Kendall's W, drawing every permutation from `generator`.
///
/// The generator-parameterized form of
/// ``concordancePermutationTest(_:permutations:seed:)``, following the same convention
/// as ``integrate(_:iterations:using:)``: all randomness comes from the caller's
/// generator, so the caller owns reproducibility.
///
/// - Parameters:
///   - rankings: A 2D array where rows are judges and columns are items.
///   - permutations: Number of random permutations.
///   - generator: The random source for the shuffles.
/// - Returns: A tuple of the observed W and its permutation-based p-value.
/// - Throws: `BusinessMathError.invalidInput` if W cannot be computed from the rankings.
public func concordancePermutationTest<T: Real & Sendable, G: RandomNumberGenerator>(
    _ rankings: [[T]], permutations: Int = 10000, using generator: inout G
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
            permuted[i].shuffle(using: &generator)
        }
        let permW = kendallW(permuted)
        if permW >= observedW {
            countGE += 1
        }
    }

    let pValue = T(countGE) / T(permutations)
    return (w: observedW, pValue: pValue)
}

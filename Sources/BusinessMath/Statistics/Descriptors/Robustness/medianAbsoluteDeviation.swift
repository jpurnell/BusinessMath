//
//  medianAbsoluteDeviation.swift
//  BusinessMath
//
//  The median absolute deviation, as a public statistic. Added for the Diagnostics Hub's
//  spike rule, which widens its Poisson baseline when a history is more spread out than
//  Poisson allows.
//

import Foundation
import Numerics

/// The scale a median absolute deviation is reported on.
///
/// - SeeAlso: ``medianAbsoluteDeviation(_:scale:)``
public enum MedianAbsoluteDeviationScale: Sendable, Equatable {
    /// The MAD itself, `median(|xᵢ − median(x)|)`. R's `mad(x, constant = 1)`; SciPy's
    /// `median_abs_deviation(x)`.
    case raw

    /// The MAD multiplied by `1/Φ⁻¹(3/4) = 1.482602218505602`, so that for normally
    /// distributed data it estimates the standard deviation.
    ///
    /// The constant is computed, not rounded: it is SciPy's `scale="normal"` and statsmodels'
    /// `robust.mad`. R's default `mad(x)` uses `1.4826`, which differs from it by a relative
    /// 1.5e-6; pass `constant = 1/qnorm(3/4)` in R for the same number.
    case normalConsistent

    /// The multiplier this scale applies to the raw MAD.
    ///
    /// - Returns: `1` for ``raw``; `1/Φ⁻¹(3/4)` for ``normalConsistent``.
    public func factor<T: Real>() -> T {
        switch self {
        case .raw:
            return T(1)
        case .normalConsistent:
            let threeQuarters: T = T(3) / T(4)
            return T(1) / inverseNormalCDF(p: threeQuarters)
        }
    }
}

/// The median absolute deviation: the median distance of the values from their median.
///
/// ```
/// MAD = median( |xᵢ − median(x)| )
/// ```
///
/// A measure of spread that a minority of extreme values cannot move. Up to half the sample
/// can be replaced by arbitrary values before the MAD becomes arbitrary (a breakdown point
/// of 50 %, against 0 % for the standard deviation), so one spike in a history cannot
/// inflate the spread that the next spike is judged against.
///
/// ## Scale
///
/// The default is the **raw** MAD, in the data's own units, with no constant applied: R's
/// `mad(x, constant = 1)`. Pass ``MedianAbsoluteDeviationScale/normalConsistent`` for the
/// version that estimates a normal standard deviation; see that case for how it relates to
/// R's rounded `1.4826`.
///
/// ## Medians of even-length samples
///
/// Both medians are the mean of the two middle values when the count is even, as
/// ``median(_:)`` and R's `median` take them. (Some definitions use the low or high median
/// instead; this one is the one R and SciPy use.)
///
/// ## Counts
///
/// On sparse integer counts the MAD is often `0`: in `[0, 0, 1, 0, 2, 0, 0, 1, 0]` more than
/// half the values equal the median, so the median deviation is zero. That is the correct
/// value, and it means "the typical day is exactly the median day", not "no spread". A
/// caller dividing by the MAD must handle it.
///
/// ## Usage
///
/// ```swift
/// let daily: [Double] = [3, 8, 1, 12, 4, 0, 6, 15, 2, 5, 9, 1, 7, 3]
/// try medianAbsoluteDeviation(daily)                            // 3
/// try medianAbsoluteDeviation(daily, scale: .normalConsistent)  // 4.4478…
/// ```
///
/// - Parameters:
///   - values: The sample. Every value must be finite.
///   - scale: ``MedianAbsoluteDeviationScale/raw`` (the default) or
///     ``MedianAbsoluteDeviationScale/normalConsistent``.
/// - Returns: The MAD on the requested scale; `0` for a single value.
/// - Throws: `BusinessMathError.insufficientData` for an empty sample;
///   `BusinessMathError.invalidInput` when any value is `nan` or infinite. A `nan` has no
///   place in an ordering, and a sample with an infinity has an undefined distance from its
///   median once half of it is infinite, so neither is propagated as a plausible-looking
///   number.
///
/// - Complexity: O(n log n), for two sorts.
///
/// - SeeAlso: ``median(_:)``, ``ModifiedZScoreAnomalyDetector``
public func medianAbsoluteDeviation<T: Real>(
    _ values: [T], scale: MedianAbsoluteDeviationScale = .raw
) throws -> T {
    guard !values.isEmpty else {
        throw BusinessMathError.insufficientData(
            required: 1, actual: 0, context: "medianAbsoluteDeviation needs at least one value")
    }
    if let bad = values.first(where: { !$0.isFinite }) {
        throw BusinessMathError.invalidInput(
            message: "medianAbsoluteDeviation needs finite values",
            value: "\(bad)", expectedRange: "finite numbers")
    }
    let centre: T = median(values)
    let deviations: [T] = values.map { abs($0 - centre) }
    let raw: T = median(deviations)
    switch scale {
    case .raw:
        return raw
    case .normalConsistent:
        let factor: T = scale.factor()
        return raw * factor
    }
}

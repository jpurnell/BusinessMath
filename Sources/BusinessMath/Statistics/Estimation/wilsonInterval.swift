//
//  wilsonInterval.swift
//  BusinessMath
//
//  The Wilson score interval for a binomial proportion. Added for the Diagnostics Hub's
//  crash-free launch rate, where a healthy app sits at 0 or at n and the normal
//  approximation's interval collapses to a point.
//

import Foundation
import Numerics

/// A binomial proportion with its Wilson score confidence interval.
///
/// ``value`` is the observed proportion `successes / trials`, the maximum-likelihood
/// estimate, and the number to show. ``lower`` and ``upper`` are the Wilson bounds; they are
/// not centred on ``value`` (the interval's own midpoint is pulled toward ½), which is what
/// keeps them inside [0, 1] and informative at 0 and at `trials`.
///
/// - SeeAlso: ``wilsonInterval(successes:trials:confidence:)``
public struct WilsonInterval<T: Real & Sendable>: Sendable, Equatable {
    /// The observed proportion, `successes / trials`.
    public let value: T
    /// The lower bound. Exactly `0` when there were no successes.
    public let lower: T
    /// The upper bound. Exactly `1` when every trial succeeded.
    public let upper: T
    /// The two-sided confidence level the bounds were computed at, in (0, 1).
    public let confidence: T

    /// Creates an interval from its parts.
    ///
    /// - Parameters:
    ///   - value: The observed proportion.
    ///   - lower: The lower bound.
    ///   - upper: The upper bound.
    ///   - confidence: The two-sided confidence level.
    public init(value: T, lower: T, upper: T, confidence: T) {
        self.value = value
        self.lower = lower
        self.upper = upper
        self.confidence = confidence
    }
}

/// The Wilson score interval for a binomial proportion.
///
/// For `x` successes in `n` trials, with `p̂ = x/n` and `z` the standard normal quantile at
/// `(1 + confidence)/2`:
///
/// ```
///            p̂ + z²/(2n)  ±  z · √( p̂(1 − p̂)/n + z²/(4n²) )
/// bounds  =  ─────────────────────────────────────────────────
///                              1 + z²/n
/// ```
///
/// This is the interval obtained by inverting the score test, as Wilson (1927) gave it,
/// **without continuity correction**. It is the interval R's
/// `prop.test(x, n, correct = FALSE)$conf.int`, `binom::binom.wilson`, SciPy's
/// `binomtest(x, n).proportion_ci(method = "wilson")` and statsmodels'
/// `proportion_confint(method = "wilson")` return.
///
/// ## Why Wilson
///
/// The normal-approximation (Wald) interval `p̂ ± z√(p̂(1 − p̂)/n)` has zero width at `x = 0`
/// and `x = n`: ten crash-free launches out of ten would be reported as a crash-free rate of
/// exactly 100 %, with certainty. Wilson's interval at 10 of 10 is [0.7225, 1] at 95 %,
/// which is what ten launches can actually say. Its coverage is close to nominal for small
/// `n` and for proportions near 0 and 1, where the Wald interval's is not (Brown, Cai and
/// DasGupta 2001).
///
/// ## Edges
///
/// At `x = 0` the lower bound is exactly `0`, and at `x = n` the upper bound is exactly `1`.
/// The formula gives those values in exact arithmetic; they are set rather than computed so
/// that a rounding of order 1e-17 cannot put a healthy rate a hair outside [0, 1].
///
/// ## Usage
///
/// ```swift
/// // Crash-free launch rate: 997 of 1000 launches ended normally.
/// let rate = try wilsonInterval(successes: 997, trials: 1000, confidence: 0.95)
/// rate.value   // 0.997
/// rate.lower   // 0.9912
/// rate.upper   // 0.9990
/// ```
///
/// - Parameters:
///   - successes: The number of successes, `0 ≤ successes ≤ trials`.
///   - trials: The number of trials, at least 1.
///   - confidence: The two-sided confidence level, strictly between 0 and 1. Defaults to
///     0.95.
/// - Returns: The observed proportion with its Wilson bounds.
/// - Throws: `BusinessMathError.insufficientData` when `trials` is 0: there is no
///   proportion to estimate, and the caller should say "not enough data" rather than show a
///   rate. `BusinessMathError.invalidInput` when `trials` or `successes` is negative, when
///   `successes > trials`, or when `confidence` is not a finite number strictly between 0
///   and 1.
///
/// - Complexity: O(1).
///
/// ## References
/// - Wilson, E. B. (1927). Probable inference, the law of succession, and statistical
///   inference. *Journal of the American Statistical Association* 22(158), 209–212.
/// - Brown, L. D., Cai, T. T. and DasGupta, A. (2001). Interval estimation for a binomial
///   proportion. *Statistical Science* 16(2), 101–133.
///
/// - SeeAlso: ``WilsonInterval``, ``inverseNormalCDF(p:mean:stdDev:)``
public func wilsonInterval<T: Real & Sendable>(
    successes: Int, trials: Int, confidence: T = T(95) / T(100)
) throws -> WilsonInterval<T> {
    guard trials >= 0 else {
        throw BusinessMathError.invalidInput(
            message: "wilsonInterval needs a non-negative number of trials",
            value: "\(trials)", expectedRange: "[1, ∞)")
    }
    guard successes >= 0, successes <= trials else {
        throw BusinessMathError.invalidInput(
            message: "wilsonInterval needs 0 ≤ successes ≤ trials",
            value: "\(successes) of \(trials)", expectedRange: "[0, \(trials)]")
    }
    guard confidence.isFinite, confidence > T.zero, confidence < T(1) else {
        throw BusinessMathError.invalidInput(
            message: "wilsonInterval needs a confidence level strictly between 0 and 1",
            value: "\(confidence)", expectedRange: "(0, 1)")
    }
    // Last, so that a negative or inconsistent count is named as such rather than as "no data".
    guard trials > 0 else {
        throw BusinessMathError.insufficientData(
            required: 1, actual: 0, context: "wilsonInterval needs at least one trial")
    }

    let n: T = T(trials)
    let p: T = T(successes) / n
    let tailProbability: T = (T(1) + confidence) / T(2)
    let z: T = inverseNormalCDF(p: tailProbability)
    let zSquared: T = z * z

    let denominator: T = T(1) + zSquared / n
    let centre: T = (p + zSquared / (T(2) * n)) / denominator
    let spread: T = p * (T(1) - p) / n + zSquared / (T(4) * n * n)
    let halfWidth: T = z * spread.squareRoot() / denominator

    let lower: T = successes == 0 ? T.zero : max(T.zero, centre - halfWidth)
    let upper: T = successes == trials ? T(1) : min(T(1), centre + halfWidth)
    return WilsonInterval(value: p, lower: lower, upper: upper, confidence: confidence)
}

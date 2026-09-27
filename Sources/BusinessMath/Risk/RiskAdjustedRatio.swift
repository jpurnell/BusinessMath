//
//  RiskAdjustedRatio.swift
//  BusinessMath
//

import Foundation
import Numerics

/// A risk-adjusted return ratio, `excessReturn / risk`.
///
/// Sharpe, Sortino and the portfolio optimiser all divide an excess return by a measure of
/// risk, and each site independently returned `0` when that risk was zero:
///
/// ```
/// if standardDeviation > T(0) {
///     return (meanReturn - riskFreeRate) / standardDeviation
/// } else {
///     return T(0)
/// }
/// ```
///
/// (Quoted as it stood, not as an example to run — hence the untagged fence.)
///
/// Zero is the wrong fallback, because these ratios exist to be *ranked*. Zero is not an
/// absent value there — it is a mediocre score, placed squarely in the middle of any
/// ordering. Measured against a zero-covariance portfolio with a 2% risk-free rate, a
/// guaranteed 7% excess return and a guaranteed 1.25% shortfall both reported a Sharpe ratio
/// of exactly `0.0`; `PortfolioOptimizer.efficientFrontier` selects with
/// `max(by: { $0.sharpeRatio < $1.sharpeRatio })`, so a riskless arbitrage lost to any
/// mediocre risky portfolio.
///
/// A position with no risk has an unbounded ratio in the sign of its excess return: a
/// guaranteed gain over the risk-free rate is infinitely attractive, a guaranteed shortfall
/// infinitely unattractive, and matching the rate exactly earns nothing while risking
/// nothing. Separating those three is the whole job of this function — a single `0` conflated
/// all of them.
///
/// Because the divisor is guarded by a `guard` on a plain identifier, callers need no
/// `fp-safety` suppression.
///
/// - Parameters:
///   - excessReturn: Return in excess of the benchmark; may be negative.
///   - risk: Non-negative dispersion to divide by — standard deviation, downside deviation,
///     or portfolio volatility.
/// - Returns: `excessReturn / risk`; `±infinity` when `risk` is zero and the excess return is
///   non-zero, and `0` when neither is present.
internal func riskAdjustedRatio<T: Real & BinaryFloatingPoint>(
    excessReturn: T,
    risk: T
) -> T {
    guard risk > T(0) else {
        if excessReturn > T(0) { return T.infinity }
        if excessReturn < T(0) { return -T.infinity }
        return T(0)
    }
    return excessReturn / risk
}

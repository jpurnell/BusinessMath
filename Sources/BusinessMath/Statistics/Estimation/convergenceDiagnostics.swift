import Foundation
import Numerics

/// Computes the Gelman-Rubin R-hat statistic for assessing MCMC chain convergence.
///
/// R-hat compares between-chain and within-chain variance. Values near 1.0
/// indicate that the chains have converged to the same stationary distribution.
/// A common threshold is R-hat < 1.05 for acceptable convergence.
///
/// **Algorithm:**
/// ```
/// B = (n / (M-1)) * sum_m (theta_bar_m - theta_bar)^2
/// W = (1/M) * sum_m s_m^2
/// var_hat = ((n-1)/n) * W + (1/n) * B
/// R_hat = sqrt(var_hat / W)
/// ```
///
/// - Parameter chains: Array of chains, where each chain is an array of posterior samples.
///   All chains must have the same length and contain at least 2 samples.
/// - Returns: The R-hat statistic, or `nil` if fewer than 2 chains are provided.
public func rHatStatistic<T: Real>(_ chains: [[T]]) -> T? where T: BinaryFloatingPoint {
    let m = chains.count
    guard m >= 2 else { return nil }

    let n = chains[0].count
    guard n >= 2 else { return nil }

    // Verify all chains have the same length
    for chain in chains {
        guard chain.count == n else { return nil }
    }

    let nT = T(n)
    let mT = T(m)

    // Chain means
    let chainMeans: [T] = chains.map { chain in
        chain.reduce(T.zero, +) / nT
    }

    // Overall mean
    let overallMean = chainMeans.reduce(T.zero, +) / mT

    // Between-chain variance B
    var bSum = T.zero
    for chainMean in chainMeans {
        let diff = chainMean - overallMean
        bSum += diff * diff
    }
    let b = nT / (mT - T(1)) * bSum

    // Within-chain variance W
    var w = T.zero
    for (i, chain) in chains.enumerated() {
        var chainVar = T.zero
        for sample in chain {
            let diff = sample - chainMeans[i]
            chainVar += diff * diff
        }
        chainVar = chainVar / (nT - T(1))
        w += chainVar
    }
    w = w / mT

    // Guard against zero within-chain variance
    guard w > T.zero else {
        // If W is zero, all chains have constant values.
        // If they are all the same constant, R-hat = 1.
        // If they differ, R-hat = infinity (use large value).
        if b == T.zero {
            return T(1)
        }
        return T(10) // Indicate non-convergence
    }

    // Estimated variance
    let withinWeight: T = (nT - T(1)) / nT
    let betweenWeight: T = T(1) / nT
    let varHat: T = withinWeight * w + betweenWeight * b

    return T.sqrt(varHat / w)
}

/// Computes the effective sample size (ESS) accounting for autocorrelation.
///
/// Uses the initial positive sequence estimator: autocorrelations are summed
/// in pairs and the series is truncated at the first non-positive pair sum,
/// ensuring the ESS estimate is non-negative.
///
/// **Algorithm:**
/// ```
/// ESS = n / (1 + 2 * sum_{k=1}^K rho_k)
/// ```
/// where rho_k is the lag-k autocorrelation, truncated at the first negative value.
///
/// - Parameter samples: Array of posterior samples from a single chain.
/// - Returns: The effective sample size, bounded between 1 and `samples.count`.
public func effectiveSampleSize<T: Real>(_ samples: [T]) -> Int where T: BinaryFloatingPoint {
    let n = samples.count
    guard n >= 2 else { return n }

    let nT = T(n)
    let sampleMean = samples.reduce(T.zero, +) / nT

    // Compute variance (denominator for autocorrelation)
    var variance = T.zero
    for sample in samples {
        let diff = sample - sampleMean
        variance += diff * diff
    }
    variance = variance / nT

    guard variance > T.zero else {
        // Constant sequence: ESS = n (no autocorrelation structure to speak of)
        return n
    }

    // Compute autocorrelations and sum using initial positive sequence estimator
    var autocorrelationSum = T.zero
    let maxLag = n - 1

    for lag in 1...maxLag {
        var autocovariance = T.zero
        for i in 0..<(n - lag) {
            autocovariance += (samples[i] - sampleMean) * (samples[i + lag] - sampleMean)
        }
        autocovariance = autocovariance / nT

        let rho = autocovariance / variance

        // Truncate at first negative autocorrelation
        guard rho > T.zero else { break }

        autocorrelationSum += rho
    }

    let denominator = T(1) + T(2) * autocorrelationSum
    guard denominator > T.zero else { return 1 }

    let ess = nT / denominator
    let essInt = Int(Double(ess))

    // Clamp to [1, n]
    return max(1, min(essInt, n))
}

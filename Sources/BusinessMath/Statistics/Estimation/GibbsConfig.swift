import Foundation
import Numerics

/// Configuration for the Gibbs sampler used in Bayesian ICC estimation.
///
/// Controls the number of iterations, burn-in length, thinning interval,
/// number of parallel chains, and optional random seed for reproducibility.
///
/// Use ``default`` for reasonable defaults or create a custom configuration
/// when you need tighter control over convergence diagnostics.
///
/// ## Topics
///
/// ### Creating Configurations
/// - ``default``
public struct GibbsConfig<T: Real & Sendable>: Sendable, Equatable {
    /// Total number of MCMC iterations per chain (default: 10000).
    public let iterations: Int
    /// Number of initial iterations to discard as burn-in (default: iterations / 2).
    public let burnIn: Int
    /// Keep every `thinning`-th sample to reduce autocorrelation (default: 1).
    public let thinning: Int
    /// Number of independent chains to run for convergence diagnostics (default: 2).
    public let chains: Int
    /// Optional random seed for reproducible results. When `nil`, system randomness is used.
    public let seed: UInt64?

    /// Creates a Gibbs sampler configuration with explicit parameters.
    ///
    /// - Parameters:
    ///   - iterations: Total MCMC iterations per chain.
    ///   - burnIn: Iterations to discard as burn-in.
    ///   - thinning: Thinning interval.
    ///   - chains: Number of independent chains.
    ///   - seed: Optional random seed for reproducibility.
    public init(
        iterations: Int = 10_000,
        burnIn: Int? = nil,
        thinning: Int = 1,
        chains: Int = 2,
        seed: UInt64? = nil
    ) {
        self.iterations = iterations
        self.burnIn = burnIn ?? (iterations / 2)
        self.thinning = thinning
        self.chains = chains
        self.seed = seed
    }

    /// A default configuration suitable for most applications.
    ///
    /// Uses 10,000 iterations with 5,000 burn-in, no thinning, 2 chains,
    /// and no fixed seed.
    public static var `default`: GibbsConfig {
        GibbsConfig()
    }
}

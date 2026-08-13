//
//  DeterministicRNG.swift
//  BusinessMath
//
//  A deterministic pseudo-random number generator for reproducible simulation.
//

/// A deterministic pseudo-random number generator conforming to `RandomNumberGenerator`.
///
/// Given the same seed, the generator produces the identical sequence of values across all
/// platforms and runs. The name is kept because it states what this is *for*; the algorithm
/// is ``Xoshiro256StarStar``, from SwiftDeterminism.
///
/// ## Why this is no longer an LCG
///
/// This was Knuth's MMIX linear congruential generator, returning its raw state as output.
/// That is the flaw: in any LCG the low bits of the state are barely random — bit 0 has
/// period 2, bit 1 period 4, and so on — so anything reducing a draw modulo a small number
/// gets a visibly poor sequence. The values here drive Box–Muller normal variates in
/// ``MonteCarloEngine`` and demand sampling in `InventorySimulator`, which is real
/// simulation work and deserves a generator whose every bit is well distributed.
///
/// `xoshiro256**` carries 256 bits of state, passes the standard statistical batteries, and
/// is seeded through SplitMix64 as its authors recommend. It is the same generator
/// ``MonteCarloSimulation`` uses for seeded CPU runs, so the two now agree.
///
/// ## Usage
///
/// ```swift
/// let simulation = try FinancialSimulation.documentationFixture
/// var rng = DeterministicRNG(seed: 42)
///
/// // Use with Swift standard library random APIs
/// let uniform = Double.random(in: 0..<1, using: &rng)
/// let integer = Int.random(in: 1...100, using: &rng)
///
/// // Use with CorrelatedNormals for reproducible simulation
/// let correlated = try CorrelatedNormals(means: [0, 0], correlationMatrix: [[1, 0.5], [0.5, 1]])
/// let sample = correlated.sample(using: &rng)
/// ```
///
/// ## Determinism Contract
///
/// The same seed always produces the same sequence:
///
/// ```swift
/// var rng1 = DeterministicRNG(seed: 42)
/// var rng2 = DeterministicRNG(seed: 42)
/// // rng1.next() == rng2.next() for all calls
/// ```
///
/// The contract is unchanged by the algorithm swap, but the *values* are not: a seed no
/// longer reproduces streams recorded before this change. It is not cryptographically
/// secure — the state is recoverable from enough output — so never use it for keys, tokens,
/// or anything security-sensitive.
public typealias DeterministicRNG = Xoshiro256StarStar

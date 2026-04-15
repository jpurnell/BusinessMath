//
//  DeterministicRNG.swift
//  BusinessMath
//
//  A deterministic pseudo-random number generator for reproducible simulation.
//

/// A deterministic pseudo-random number generator conforming to `RandomNumberGenerator`.
///
/// Uses Knuth's MMIX LCG (Linear Congruential Generator) for reproducible
/// random sequences. Given the same seed, the generator produces the
/// identical sequence of values across all platforms and runs.
///
/// ## Usage
///
/// ```swift
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
public struct DeterministicRNG: RandomNumberGenerator, Sendable {
    private var state: UInt64

    /// Creates a deterministic RNG with the given seed.
    ///
    /// - Parameter seed: The initial state. Same seed guarantees identical output sequence.
    public init(seed: UInt64) {
        self.state = seed
    }

    /// Generates the next pseudo-random `UInt64`.
    ///
    /// Uses the MMIX LCG formula: `state = state * 6364136223846793005 + 1442695040888963407`
    public mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

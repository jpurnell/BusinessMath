//
//  SplitMix64.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-07-14.
//

/// BusinessMath's `SplitMix64` is SwiftDeterminism's, re-exported.
///
/// The generator used to be implemented here. It was one of several byte-identical
/// copies across this portfolio — same golden-ratio increment, same shifts, same
/// multipliers — so it now lives in one package, where it is tested against Vigna's
/// published reference vectors rather than against itself.
///
/// Re-exported rather than aliased because the name is unchanged: existing callers
/// writing `BusinessMath.SplitMix64`, and the seeded expectations throughout the test
/// suite, keep working untouched. The stream is identical, so no simulation result moves.
///
/// **What BusinessMath uses it for.** It drives reproducible Monte Carlo runs: pass a
/// seed to ``MonteCarloSimulation`` and every CPU-path sample flows through this
/// generator, so a suspicious result can be re-run exactly. See ``SeedableDistribution``
/// for how a distribution turns its bits into samples — SwiftDeterminism produces bits,
/// BusinessMath gives them meaning.
///
/// ## Example
///
/// ```swift
/// var rng = SplitMix64(seed: 42)
/// let u = Double.random(in: 0...1, using: &rng)   // identical on every run
/// ```
///
/// It is **not** cryptographically secure — the mixing function is invertible, so two
/// outputs reveal the state. Never use it for keys, tokens, or anything security-sensitive.
@_exported import struct SwiftDeterminism.SplitMix64

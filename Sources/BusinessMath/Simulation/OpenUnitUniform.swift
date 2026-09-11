//
//  OpenUnitUniform.swift
//  BusinessMath
//
//  The library's own mapping from generator output to a uniform on (0, 1).
//

/// A uniform draw on the **open** interval `(0, 1)`, owned by this library.
///
/// This is the single place BusinessMath turns raw generator output into a uniform, and every
/// seeded sampler in the package goes through it. It exists because
/// `Double.random(in: 0...1, using:)` is wrong for the job in two distinct ways.
///
/// ## The interval is closed
///
/// `0...1` includes both endpoints, so a draw of exactly zero is legal — and `log(0)` is
/// `-infinity`, `pow(0, k)` is zero, and `1/0` is infinite. Every quantile that begins by
/// taking a logarithm or a reciprocal can therefore produce a non-finite variate from a
/// perfectly valid uniform. The probability is small and not zero, which is the worst
/// combination available: it survives a test suite and appears in production.
///
/// It is also not as small as it looks. `distributionUniform` quantizes to multiples of 1e-7,
/// so before that was fixed *every* seed below the quantum arrived as exactly zero — one draw
/// in ten million, not one in 2⁵³.
///
/// ## The mapping is not ours
///
/// The standard library documents that the algorithm turning generator output into a `Double`
/// **may change between Swift releases**. A seeded stream is only reproducible if every step
/// from seed to variate belongs to something whose version we control, and that step did not.
/// A test that reproduced a sampler's uniforms with `Double.random(in: 0...1, using:)` was
/// asserting agreement with a standard-library implementation detail, which is not a property
/// a reproducibility test can rest on.
///
/// ## The mapping
///
/// Take the top **52** bits and place the result at the **centre** of each cell rather than at
/// its edge:
///
/// ```swift
/// var generator = DeterministicRNG(seed: 42)
/// let word: UInt64 = generator.next()
/// let u: Double = (Double(word >> 12) + 0.5) * 0x1p-52
/// ```
///
/// The half-cell offset is what excludes the endpoints: the smallest value is `2⁻⁵³` and the
/// largest is `1 - 2⁻⁵³`, so the interval is open at both ends *by construction* rather than by
/// a guard that can be forgotten.
///
/// ## Why 52 bits and not 53
///
/// 53 is the significand width, so the obvious form is `(Double(x >> 11) + 0.5) * 0x1p-53`.
/// It is wrong at the top. The largest shifted word is `2⁵³ - 1`; adding `0.5` to it needs
/// **54** significant bits, so the sum rounds — ties-to-even, to `2⁵³` — and `2⁵³ × 2⁻⁵³` is
/// exactly `1.0`. The offset that opens the bottom of the interval closes the top.
///
/// This was not reasoned out. It was measured: a generator stuck on all-ones words returned
/// exactly `1.0`, and `boxMullerSeed` through it gave a radius of `-0.0` — the pole this
/// function exists to make unreachable, reached on the first draw.
///
/// At 52 bits, `Double(2⁵² - 1) + 0.5` needs exactly 53 bits and is therefore exact, and the
/// product is `1 - 2⁻⁵³`, the largest `Double` below one. The cost is one bit of randomness out
/// of 52, against a guarantee that either endpoint is unreachable.
///
/// Rejection sampling would also give an open interval and is worse here: it consumes an
/// unpredictable number of draws, which breaks the one contract a caller interleaving several
/// families on a single stream depends on. This advances the generator exactly once, always.
///
/// - Parameters:
///   - type: The floating-point type to produce. Usually inferred.
///   - generator: The random source. Advanced by exactly one draw.
/// - Returns: A value strictly between 0 and 1.
public func openUnitUniform<T: BinaryFloatingPoint, G: RandomNumberGenerator>(
	_ type: T.Type = T.self,
	using generator: inout G
) -> T {
	// 52, not 53: at 53 the `+ 0.5` needs a 54th bit and rounds up to exactly 1.0 at the top
	// of the range. See "Why 52 bits and not 53" above — this was measured, not predicted.
	let bits: UInt64 = generator.next() >> 12
	let centred: Double = Double(bits) + 0.5
	return T(centred * 0x1p-52)
}

/// A uniform draw on the open interval `(0, 1)` from the system's random source.
///
/// The unseeded companion to ``openUnitUniform(_:using:)``, for the documented
/// draw-a-fresh-one paths and for default arguments, where there is nowhere to put a
/// generator. Pass `seed:` or `using:` on the sampler itself when reproducibility matters.
///
/// - Parameter type: The floating-point type to produce. Usually inferred.
/// - Returns: A value strictly between 0 and 1.
public func openUnitUniform<T: BinaryFloatingPoint>(
	_ type: T.Type = T.self
) -> T {
	var generator = SystemRandomNumberGenerator() // stochastic:exempt — the documented unseeded path; pass a generator for reproducibility
	return openUnitUniform(type, using: &generator)
}

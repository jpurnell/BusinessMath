//
//  OpenUnitUniform.swift
//  BusinessMath
//
//  A uniform draw on the open interval (0, 1).
//

/// A uniform draw on the **open** interval `(0, 1)`, owned by this library.
///
/// Two problems with `Double.random(in: 0...1, using:)`, both of which bite inverse-transform
/// samplers specifically:
///
/// 1. **`0` is in the range.** The interval is closed, so a draw of exactly zero is legal —
///    and `log(0)` is `-infinity`, `pow(0, k)` is zero, and every quantile that begins by
///    taking a logarithm produces a non-finite variate from a perfectly valid uniform. The
///    probability is small and not zero, which is the worst combination: it survives testing
///    and appears in production.
/// 2. **The mapping is not ours.** The standard library documents that the algorithm turning
///    generator output into a `Double` may change between Swift releases. A seeded stream is
///    only reproducible if every step from seed to variate belongs to something whose version
///    we control, and this step does not.
///
/// The mapping here is the conventional one: take the top 53 bits — the number a `Double`
/// can hold exactly — and place the result at the centre of each representable cell rather
/// than at its edge. That half-cell offset is what excludes both endpoints: the smallest
/// value is `2⁻⁵⁴` and the largest is `1 - 2⁻⁵⁴`, so the interval is open at both ends by
/// construction rather than by rejection sampling, which would consume an unpredictable
/// number of draws and break the stream.
///
/// - Note: This is deliberately **not** yet used by every sampler. Swapping it in changes the
///   variate produced by every existing seed, so adopting it library-wide is a reproducibility
///   break for anyone who has recorded results against a seed, and is a separate decision from
///   using it in new code paths where no stream exists to preserve.
///
/// - Parameter generator: The random source. Advanced by exactly one draw.
/// - Returns: A value strictly between 0 and 1.
internal func openUnitUniform<T: BinaryFloatingPoint, G: RandomNumberGenerator>(
	_ type: T.Type = T.self,
	using generator: inout G
) -> T {
	// 53 bits is the significand width of a Double, so every value below is exact.
	let bits: UInt64 = generator.next() >> 11
	let centred: Double = Double(bits) + 0.5
	return T(centred * 0x1p-53)
}

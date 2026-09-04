//
//  DecimalConstant.swift
//  BusinessMath
//
//  Promoted 2026-09-04 from a private helper in inverseNormalCDF.swift. Three
//  rational approximations in this package now need it, and a second copy is a
//  second place for a mantissa to be mistyped.
//

import Numerics

/// Builds a decimal constant from an exact integer mantissa and a power of ten.
///
/// `Real` does not refine `ExpressibleByFloatLiteral` — only `BinaryFloatingPoint`
/// does — so a decimal coefficient cannot be written as a literal inside a function
/// generic over `Real`. `T(0.5)` does not mean what it looks like: it resolves to
/// `init(_: Int)` and fails to compile.
///
/// Keep every mantissa under `2^53` and every divisor a power of ten under `10^22`.
/// Both operands then convert exactly in binary floating point, so each constant
/// costs a single correct rounding rather than accumulating two.
///
/// ```swift
/// let half: T = decimal(1, over: 2)
/// let coefficient: T = decimal(2_30753, over: 100_000)   // 2.30753
/// ```
///
/// - Parameters:
///   - mantissa: The digits, as an exact integer. May be negative.
///   - scale: The divisor, a power of ten.
/// - Returns: `mantissa / scale` in `T`.
@inline(__always)
internal func decimal<T: Real>(_ mantissa: Int, over scale: Int) -> T {
	return T(mantissa) / T(scale)
}

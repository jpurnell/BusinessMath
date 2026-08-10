//
//  FloatingPointClaims.swift
//  TestSupport
//
//  Three different claims hide under `==` on floating-point values. These name them,
//  so an assertion says which one it is making.
//

/// Bit-for-bit equality: the two values are the *same number*, down to the encoding.
///
/// Use this where the expected value is produced without rounding — an order statistic
/// handed back unchanged, a literal returned by a guard, a quotient of equal integers,
/// a conversion whose scale factor contributes nothing. There the assertion is a claim
/// of exactness, and a tolerance would let it pass while the property it guards has
/// broken: an interpolation that fired when it should not have, a conversion that lost
/// a bit of scale, a `1.0` that is really `1 - 5e-10`.
///
/// Two differences from `==` are deliberate, and are why this is not a rephrasing of
/// the same test:
///
/// - `identical(-0.0, 0.0)` is `false`, where `-0.0 == 0.0` is `true`. Only use this
///   against a zero whose sign is fixed by construction. Where either sign is a
///   correct answer — `sqrt(-0.0)` is `-0.0`, and a zero radius carries that sign into
///   every product built from it — use ``exactlyEqual(_:_:)`` instead.
/// - `identical(.nan, .nan)` is `true` for two NaNs with the same encoding, where `==`
///   is `false`. That makes this the right comparison for reproducibility claims, where
///   `==` would silently pass a stream that had gone NaN. When "is it NaN" is the
///   question, ask `isNaN`.
///
/// - Parameters:
///   - lhs: The value the code under test produced.
///   - rhs: The value it is claimed to be, exactly.
/// - Returns: `true` when both values have the same sign, exponent, and significand.
public func identical<T: BinaryFloatingPoint>(_ lhs: T, _ rhs: T) -> Bool {
    return lhs.sign == rhs.sign
        && lhs.exponentBitPattern == rhs.exponentBitPattern
        && lhs.significandBitPattern == rhs.significandBitPattern
}

/// IEEE equality, chosen on purpose rather than reached for by habit.
///
/// Use this where the value is exact but its *encoding* is not pinned — most often a
/// zero that may legitimately arrive as `-0.0`. IEEE `==` treats the two zeros as the
/// same number, which is the claim being made when a test says "the result is zero".
///
/// This is exactly as strong as writing `==` inline; the only thing it adds is that
/// the reader can see the choice was made. Where the encoding *is* pinned, prefer
/// ``identical(_:_:)``, which says more.
///
/// - Parameters:
///   - lhs: The value the code under test produced.
///   - rhs: The value it is claimed to equal.
/// - Returns: `true` when the two compare equal under IEEE 754. Note that this is
///   `false` for any NaN, including a NaN compared with itself.
public func exactlyEqual<T: BinaryFloatingPoint>(_ lhs: T, _ rhs: T) -> Bool {
    return lhs == rhs
}

/// Equality within a stated tolerance, for values that are genuinely approximate.
///
/// Use this where the result is computed — a series, an iteration, a transcendental —
/// and rounding is expected. The tolerance is a parameter and not a default because it
/// should come from a measurement of the implementation's accuracy or from the
/// precision of the reference value, not from a habit.
///
/// - Parameters:
///   - lhs: The value the code under test produced.
///   - rhs: The reference value.
///   - tolerance: The largest absolute difference that still counts as agreement.
/// - Returns: `true` when the two differ by less than `tolerance`.
public func approximatelyEqual<T: BinaryFloatingPoint>(_ lhs: T, _ rhs: T, tolerance: T) -> Bool {
    return abs(lhs - rhs) < tolerance
}

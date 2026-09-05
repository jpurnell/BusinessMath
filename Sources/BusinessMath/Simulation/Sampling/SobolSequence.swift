//
//  SobolSequence.swift
//  BusinessMath
//
//  Created 2026-09-04. Phase 0 of the Excel/Risk Solver coverage work.
//

import Foundation

/// A Sobol low-discrepancy sequence, using the Joe & Kuo (2008) direction numbers.
///
/// Sobol points are a `(t, m, s)`-net in base 2: for a prefix whose length is a power
/// of two, every dyadic box of the right shape holds exactly the right number of
/// points. That is a much stronger statement than "evenly spread", and it is why a
/// Sobol-driven simulation can converge closer to `1/n` than to `1/√n`.
///
/// ## Which Sobol sequence
///
/// **There is no such thing as *the* Sobol sequence.** Implementations differ by their
/// primitive polynomials and initial direction numbers, and two that disagree produce
/// entirely different point sets while both being perfectly valid. A sequence whose
/// table is unstated cannot be checked against anything.
///
/// This one uses Joe & Kuo's `new-joe-kuo-6.21201`, vendored in
/// `SobolDirectionNumbers` and generated from SciPy's bundled copy of the same table.
/// `scipy.stats.qmc.Sobol` therefore produces identical points, which
/// `SobolSequenceTests` asserts rather than assumes.
///
/// ## The origin, and why it is kept
///
/// The construction's first point is the origin. Discarding it is the usual advice —
/// SciPy says so — because every coordinate is zero and zero inverse-transforms to
/// negative infinity.
///
/// That advice assumes coordinates are read as exact fractions. These are not: every
/// coordinate carries a **half-cell offset**, so the origin arrives as 2⁻³³ rather than
/// 0, which is strictly inside the interval and about −6.4σ on a standard normal. The
/// offset is applied to every point for exactly this reason, and it costs nothing —
/// the sequence's own resolution is 2⁻³² either way.
///
/// Keeping it matters. The balance property holds over the construction's first `2^m`
/// points *including* the origin; take `2^m` points starting from the second and you
/// have all but one of one block plus one of the next, which leaves one dyadic
/// interval empty and another doubled. Skipping the origin to avoid an infinity that
/// the offset has already removed would forfeit the property the sequence exists for.
///
/// So **point *i* here is SciPy's point *i*, plus 2⁻³³ in every coordinate.**
///
/// ## Example
///
/// ```swift
/// let sequence = try SobolSequence(dimension: 4)
/// let points = sequence.points(count: 1_024)   // powers of two get the balance property
/// ```
public struct SobolSequence: QuasiRandomPointSet {

	/// How many coordinates each point carries.
	public let dimension: Int

	/// The Owen scramble seed, or `nil` for the plain deterministic sequence.
	public let scrambleSeed: UInt64?

	/// The highest dimension the vendored direction numbers cover.
	///
	/// Joe & Kuo publish far more; this is how many are carried as generated source.
	/// See `SobolDirectionNumbers`.
	public static var maximumDimension: Int { SobolDirectionNumbers.dimensionCount }

	/// Bits of resolution per coordinate. One coordinate is a `UInt32` fixed-point
	/// fraction, so the sequence repeats after `2³²` points.
	private static var resolutionBits: Int { UInt32.bitWidth }

	/// Direction numbers, `dimension` rows of ``resolutionBits`` columns, flattened.
	private let directions: [UInt32]

	/// Creates a Sobol sequence.
	///
	/// - Parameters:
	///   - dimension: How many coordinates each point carries. Must be between 1 and
	///     ``maximumDimension``.
	///   - scrambleSeed: Applies Owen scrambling with this seed. `nil` gives the plain
	///     deterministic sequence, which is what matches SciPy's `scramble=False`.
	/// - Throws: `BusinessMathError.invalidInput` if `dimension` is outside the range
	///   the vendored table covers. It throws rather than clamping, because a silently
	///   reduced dimension would produce a point set that looks right and answers a
	///   different question.
	public init(dimension: Int, scrambleSeed: UInt64? = nil) throws {
		guard dimension >= 1, dimension <= Self.maximumDimension else {
			throw BusinessMathError.invalidInput(
				message: "Sobol dimension exceeds the vendored Joe & Kuo table; regenerate SobolDirectionNumbers.swift with a larger cap if more are needed",
				value: "\(dimension)",
				expectedRange: "[1, \(Self.maximumDimension)]")
		}
		self.dimension = dimension
		self.scrambleSeed = scrambleSeed
		self.directions = Self.buildDirections(dimension: dimension)
	}

	/// Expands the initial direction numbers into a full table by the Sobol recurrence.
	///
	/// Dimension 1 is the van der Corput sequence: `m_i = 1` for every `i`. Every other
	/// dimension has a primitive polynomial `x^s + a₁x^(s−1) + … + a_{s−1}x + 1` and `s`
	/// tabulated starting values, from which the rest follow by
	///
	/// ```
	/// m_i = 2^s·m_{i−s} ⊕ m_{i−s} ⊕ ⨁_{k=1}^{s−1} a_k·2^k·m_{i−k}
	/// ```
	///
	/// The direction number is then the odd integer `m_i` pushed to the top of the
	/// word, so that a coordinate accumulates from the most significant bit down.
	private static func buildDirections(dimension: Int) -> [UInt32] {
		let bits = resolutionBits
		var table = [UInt32](repeating: 0, count: dimension * bits)

		// Dimension 1: v_i = 2^(bits − i), the plain radical inverse.
		for i in 0..<bits {
			table[i] = UInt32(1) << (bits - 1 - i)
		}

		guard dimension > 1 else { return table }

		let columns = SobolDirectionNumbers.columnsPerDimension
		for d in 1..<dimension {
			let polynomial = SobolDirectionNumbers.polynomials[d]
			let degree = Int(UInt32.bitWidth - polynomial.leadingZeroBitCount) - 1

			var m = [UInt32](repeating: 0, count: bits)
			for i in 0..<Swift.min(degree, bits) {
				m[i] = SobolDirectionNumbers.initialDirections[d * columns + i]
			}

			if degree < bits {
				for i in degree..<bits {
					var value = m[i - degree]
					value ^= value << UInt32(degree)
					for k in 1..<degree {
						let coefficient = (polynomial >> UInt32(degree - k)) & 1
						if coefficient == 1 {
							value ^= m[i - k] << UInt32(k)
						}
					}
					m[i] = value
				}
			}

			for i in 0..<bits {
				table[d * bits + i] = m[i] << (bits - 1 - i)
			}
		}
		return table
	}

	/// `count` points of the sequence, starting after the origin.
	///
	/// Generated by Gray code: consecutive Gray codes differ in one bit, so each point
	/// costs one exclusive-or per dimension against the direction number for that bit
	/// position — the whole reason the sequence is cheap.
	///
	/// Starts at the origin, which the half-cell offset makes safe. See the note above.
	///
	/// - Parameter count: How many points. Powers of two carry the net's balance
	///   property; other counts are a prefix of a longer sequence and are merely
	///   well-spread.
	/// - Returns: A `count` × ``dimension`` array with coordinates strictly inside `(0, 1)`.
	public func points(count: Int) -> [[Double]] {
		guard count > 0 else { return [] }

		let bits = Self.resolutionBits
		var state = [UInt32](repeating: 0, count: dimension)
		var result: [[Double]] = []
		result.reserveCapacity(count)

		// A UInt32 fraction has 2³² cells, so one cell is 2⁻³² wide and the offset that
		// centres a value in its cell is 2⁻³³. Both are built from the format's own
		// width by exponent rather than by dividing, which keeps them exact and keeps
		// the constants out of the source. The offset is what lifts the origin off
		// zero — see the note on the type.
		let scale = Double(sign: .plus, exponent: -UInt32.bitWidth, significand: 1)
		let halfCell = Double(sign: .plus, exponent: -(UInt32.bitWidth + 1), significand: 1)

		for index in 0..<count {
			var point = [Double](repeating: 0, count: dimension)
			for d in 0..<dimension {
				var coordinate = state[d]
				if let seed = scrambleSeed {
					// A distinct scramble per dimension, or every dimension would
					// receive the same permutation and the projections would collapse.
					let dimensionSeed = UInt32(truncatingIfNeeded: seed &+ UInt64(d) &* 0x9e37_79b9)
					coordinate = owenScramble(coordinate, seed: dimensionSeed)
				}
				point[d] = Double(coordinate) * scale + halfCell
			}
			result.append(point)

			// Advance. The Gray codes of n and n+1 differ in the bit position of the
			// rightmost *zero* of n — not its rightmost one. Complementing turns that
			// into a trailing-zero count, which the hardware answers directly.
			let changedBit = (~UInt32(truncatingIfNeeded: index)).trailingZeroBitCount
			if changedBit < bits {
				for d in 0..<dimension {
					state[d] ^= directions[d * bits + changedBit]
				}
			}
		}
		return result
	}
}

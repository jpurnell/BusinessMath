//
//  HaltonSequence.swift
//  BusinessMath
//
//  Created 2026-09-04. Phase 0 of the Excel/Risk Solver coverage work.
//

import Foundation

/// A Halton low-discrepancy sequence: the radical inverse of the index, one prime base
/// per dimension.
///
/// The construction is the simplest of the low-discrepancy families. Write the index in
/// base *b*, reflect its digits about the decimal point, and read the result as a
/// fraction: 1, 2, 3 in base 2 become 0.1, 0.01, 0.11 — that is, ½, ¼, ¾. Each new
/// point lands in the largest remaining gap, which is what makes the sequence spread.
///
/// ## The weakness, stated rather than hidden
///
/// **Unscrambled Halton correlates badly between high dimensions.** Dimension *k* uses
/// the *k*-th prime, and for large primes the sequence needs many points before its
/// digits begin to cycle — so two high dimensions march up their ranges almost in step,
/// and a scatter plot of dimension 30 against 31 shows stripes rather than a cloud.
/// This is well known and is the reason Sobol is usually preferred beyond a handful of
/// dimensions.
///
/// `HaltonSequenceTests` measures that correlation rather than asserting it away, so
/// the limitation is visible in the suite instead of being folklore. Passing
/// `scrambleSeed` applies a random digit permutation per base, which breaks the
/// striping.
///
/// ## Example
///
/// ```swift
/// let sequence = try HaltonSequence(dimension: 2)
/// let points = sequence.points(count: 8)
/// // First dimension: 1/2, 1/4, 3/4, 1/8, 5/8, 3/8, 7/8, 1/16
/// ```
public struct HaltonSequence: QuasiRandomPointSet {

	/// How many coordinates each point carries.
	public let dimension: Int

	/// The digit-permutation seed, or `nil` for the plain deterministic sequence.
	public let scrambleSeed: UInt64?

	/// One prime base per dimension, sieved at construction rather than tabulated.
	private let bases: [Int]

	/// Creates a Halton sequence.
	///
	/// - Parameters:
	///   - dimension: How many coordinates each point carries. Must be positive.
	///   - scrambleSeed: Applies a random digit permutation per base. `nil` gives the
	///     plain sequence, which is what matches `scipy.stats.qmc.Halton(scramble=False)`.
	/// - Throws: `BusinessMathError.invalidInput` for a non-positive dimension.
	public init(dimension: Int, scrambleSeed: UInt64? = nil) throws {
		guard dimension >= 1 else {
			throw BusinessMathError.invalidInput(
				message: "Halton dimension must be positive",
				value: "\(dimension)", expectedRange: "[1, ∞)")
		}
		self.dimension = dimension
		self.scrambleSeed = scrambleSeed
		self.bases = Self.firstPrimes(count: dimension)
	}

	/// The first `count` primes, by trial division against the primes already found.
	///
	/// Generated rather than carried as a table: a list of primes is exactly the kind
	/// of constant that can be derived in eight lines, and a derived one cannot be
	/// mistyped. Testing only against known primes up to √candidate is enough, because
	/// any composite has a factor at or below its square root.
	private static func firstPrimes(count: Int) -> [Int] {
		var primes: [Int] = []
		primes.reserveCapacity(count)
		var candidate = 2
		while primes.count < count {
			var isPrime = true
			for prime in primes {
				if prime * prime > candidate { break }
				if candidate % prime == 0 {
					isPrime = false
					break
				}
			}
			if isPrime { primes.append(candidate) }
			candidate += 1
		}
		return primes
	}

	/// `count` points of the sequence, starting at index 1.
	///
	/// Index 0 has radical inverse 0 in every base — the origin — which
	/// inverse-transforms to negative infinity. Starting at 1 keeps every coordinate
	/// strictly inside `(0, 1)` without needing an offset, because the radical inverse
	/// of any positive integer already is.
	///
	/// - Parameter count: How many points to produce.
	/// - Returns: A `count` × ``dimension`` array with coordinates strictly inside `(0, 1)`.
	public func points(count: Int) -> [[Double]] {
		guard count > 0 else { return [] }

		let permutations = digitPermutations()

		return (1...count).map { index in
			bases.enumerated().map { position, base in
				radicalInverse(index, base: base, permutation: permutations?[position])
			}
		}
	}

	/// The reflected base-`base` expansion of `index`, optionally with its digits
	/// permuted.
	///
	/// Accumulating `digit / base^k` from the least significant digit upward keeps the
	/// divisor exact — every power of an integer base below 2⁵³ is exactly
	/// representable — so the result is correctly rounded once at the end.
	private func radicalInverse(_ index: Int, base: Int, permutation: [Int]?) -> Double {
		// Every base is a prime from ``firstPrimes(count:)``, so this holds by
		// construction; it is stated on the divisor itself because the guarantee is
		// otherwise several calls away from the division.
		let scale = Double(base)
		guard base >= 2, scale > 0 else { return 0 }

		var remaining = index
		var fraction = 1.0
		var result = 0.0

		while remaining > 0 {
			fraction /= scale
			var digit = remaining % base
			if let permutation { digit = permutation[digit] }
			result += Double(digit) * fraction
			remaining /= base
		}

		// A permutation can send the leading digit to zero, which would put the point
		// at the origin of this dimension. Nudge it into the interior of its cell.
		if result <= 0 { return fraction / 2 }
		return result
	}

	/// A random permutation of the digits of each base, or `nil` when unscrambled.
	private func digitPermutations() -> [[Int]]? {
		guard let scrambleSeed else { return nil }
		var generator = Xoshiro256StarStar(seed: scrambleSeed)

		return bases.map { base in
			var digits = Array(0..<base)
			// Digit 0 stays put: moving it makes the leading digit of small indices
			// non-zero, which shifts the whole sequence away from the low end of the
			// interval and undoes the coverage the construction exists for.
			if base > 2 {
				for index in stride(from: base - 1, to: 1, by: -1) {
					let swapWith = 1 + Int(generator.next(upperBound: UInt64(index)))
					digits.swapAt(index, swapWith)
				}
			}
			return digits
		}
	}
}

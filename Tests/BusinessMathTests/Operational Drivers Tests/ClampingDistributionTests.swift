//
//  ClampingDistributionTests.swift
//  BusinessMathTests
//
//  Clamping and truncating are different distributions. Nothing measured which one this is.
//

import Testing
import Foundation
@testable import BusinessMath

/// `ConstrainedDriver` **censors**: an out-of-range draw is moved to the boundary, not
/// rejected and redrawn.
///
/// A review filed this as "clamping distorts the distribution, unmeasured", with the
/// arithmetic for a `Normal(1000, 100)` clamped to ±1σ: standard deviation ≈ 60.6 and ~31.7%
/// boundary mass. **Measured, the boundary mass is right and the standard deviation is not.**
/// 60.6 matches neither convention:
///
/// | | Standard deviation | Boundary mass |
/// |---|---|---|
/// | Clamped (censored) — what this is | **71.84** | **0.317311** |
/// | Truncated (rejected and redrawn) | 53.96 | 0 |
/// | The review's figure | 60.6 | — |
///
/// Both closed forms were confirmed by an independent two-million-draw simulation before
/// this suite was written, so the disagreement is with the review rather than with the
/// arithmetic here.
///
/// The censoring is deliberate and worth keeping. Rejection sampling consumes an
/// unpredictable number of draws per value, which breaks the contract seeded composites
/// depend on — `SumDriver` and `ProductDriver` interleave operands on one generator, so a
/// driver that sometimes takes two draws and sometimes twenty makes the aggregate stream
/// irreproducible. Clamping advances the generator exactly once, always.
@Suite("Clamping censors the distribution")
struct ClampingDistributionTests {

	private static let mean = 1000.0
	private static let sigma = 100.0
	private static let lower = 900.0
	private static let upper = 1100.0

	private func draws(count: Int, seed: UInt64) throws -> [Double] {
		let base = ProbabilisticDriver<Double>.normal(
			name: "Demand", mean: Self.mean, stdDev: Self.sigma)
		let clamped = base.clamped(min: Self.lower, max: Self.upper)
		var generator = Xoshiro256StarStar(seed: seed)
		let quarter = Period.quarter(year: 2025, quarter: 1)
		var values: [Double] = []
		values.reserveCapacity(count)
		for _ in 0..<count {
			values.append(try clamped.sample(for: quarter, using: &generator))
		}
		return values
	}

	/// The signature that separates the two conventions: mass sitting *on* the boundary.
	///
	/// A truncated distribution has none — every draw is strictly inside. A censored one
	/// has exactly the tail mass of the original, piled onto two points.
	@Test("Roughly a third of the mass lands exactly on the two boundaries")
	func boundaryMassMatchesTheTails() throws {
		let values = try draws(count: 200_000, seed: 20260914)
		let onBoundary = values.filter { $0 == Self.lower || $0 == Self.upper }.count
		let observed = Double(onBoundary) / Double(values.count)

		// 2 · Φ(−1) — the mass the original normal puts beyond ±1σ, which censoring moves
		// onto the boundaries rather than discarding.
		let expected = 0.3173105078629141
		let standardError = (expected * (1 - expected) / Double(values.count)).squareRoot()
		#expect(abs(observed - expected) < 4 * standardError,
				"boundary mass \\(observed), expected \\(expected) ± \\(4 * standardError)")

		// And it is not truncation, which would put nothing on the boundary at all.
		#expect(observed > 0.25, "a truncated distribution would have no boundary mass")
	}

	/// The standard deviation, which is where the review's figure was wrong.
	@Test("The censored standard deviation is 71.84, not the truncated 53.96")
	func standardDeviationMatchesTheCensoredForm() throws {
		let values = try draws(count: 200_000, seed: 20260915)
		let count = Double(values.count)
		let mean = values.reduce(0, +) / count
		let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / count
		let observed = variance.squareRoot()

		// σ · sqrt( [Φ(1) − Φ(−1) − 2φ(1)] + 2Φ(−1) ), the second term being the boundary
		// point masses at distance σ.
		let censored = 71.8372
		#expect(abs(observed - censored) < 0.5, "sd \\(observed), expected \\(censored)")

		// The two conventions are far apart, and this fixture is on the censored side.
		let truncated = 53.9560
		#expect(abs(observed - truncated) > 10.0,
				"sd \\(observed) should be nowhere near the truncated \\(truncated)")
	}

	/// The mean survives censoring here because the clamp is symmetric about it.
	@Test("A symmetric clamp leaves the mean where it was")
	func symmetricClampPreservesTheMean() throws {
		let values = try draws(count: 200_000, seed: 20260916)
		let mean = values.reduce(0, +) / Double(values.count)
		// Standard error of the mean for the censored variable, four sigma wide.
		let standardError = 71.837 / Double(values.count).squareRoot()
		#expect(abs(mean - Self.mean) < 4 * standardError,
				"mean \\(mean) drifted from \\(Self.mean)")
	}
}

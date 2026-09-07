//
//  AutoregressiveAndGarchTests.swift
//  BusinessMath
//
//  The two dependent-draw rows, against their own stationary theory.
//
//  Neither is a distribution — a draw depends on the last one, which is the whole
//  point — so the oracle is not a CDF but the long-run behaviour of a path. Both have
//  exact stationary moments, and both make a claim about *dependence* that a moment
//  check cannot see:
//
//  - AR(1) says the autocorrelation at lag k is exactly φ^k.
//  - GARCH says the returns are uncorrelated at every lag while their squares are
//    strongly correlated. A process with either half wrong is not GARCH, and a
//    process with fat tails but no clustering would pass every moment test.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("AR(1) and GARCH(1,1)")
struct AutoregressiveAndGarchTests {

	/// Sample autocorrelation of a series at a lag.
	private static func autocorrelation(_ series: [Double], lag: Int) -> Double {
		let n = series.count
		guard lag > 0, lag < n else { return 1 }
		let mean: Double = series.reduce(0, +) / Double(n)
		var numerator = 0.0
		var denominator = 0.0
		for index in 0..<n {
			let centred: Double = series[index] - mean
			denominator += centred * centred
			if index + lag < n {
				let ahead: Double = series[index + lag] - mean
				numerator += centred * ahead
			}
		}
		guard denominator > 0 else { return 0 }
		return numerator / denominator
	}

	/// The standard normal the paths are driven by — the package's own, so the shocks
	/// come through the same sampler a caller would use.
	private static let normal = DistributionNormal(0, 1)

	private static func path(_ process: AutoregressiveOne, count: Int, seed: UInt64) -> [Double] {
		var generator = DeterministicRNG(seed: seed)
		let normal = Self.normal
		var level = process.longRunMean
		var series = [Double]()
		series.reserveCapacity(count)
		// A burn-in so the path is sampled from the stationary distribution rather
		// than from the transient of starting at the mean with no accumulated shocks.
		for _ in 0..<2_000 {
			level = process.step(from: level, dt: 1, normalDraws: normal.next(using: &generator))
		}
		for _ in 0..<count {
			level = process.step(from: level, dt: 1, normalDraws: normal.next(using: &generator))
			series.append(level)
		}
		return series
	}

	// MARK: - AR(1)

	@Test("At dt = 1 the step is exactly the textbook recursion")
	func stepReducesToTheRecursion() throws {
		// The general step uses the exact Ornstein–Uhlenbeck transition so that a
		// fractional dt means something. At dt = 1 the powers must collapse and leave
		// `c + φX + σZ` with nothing left over — otherwise the generalisation has
		// quietly changed the model it generalises.
		let process = try #require(AutoregressiveOne(name: "test", persistence: 0.7,
													 longRunMean: 5, shockVolatility: 2))
		for level in [-10.0, 0.0, 5.0, 12.5] {
			for draw in [-2.0, -0.5, 0.0, 1.3] {
				let textbook: Double = process.intercept + process.persistence * level + process.shockVolatility * draw
				let stepped = process.step(from: level, dt: 1, normalDraws: draw)
				#expect(abs(stepped - textbook) < 1e-12,
						"at X=\(level), Z=\(draw): stepped \(stepped), recursion \(textbook)")
			}
		}
	}

	@Test("Two half-steps equal one whole step in distribution")
	func fractionalStepsCompose() throws {
		// The exact transition composes; an Euler discretisation would not. Checked
		// through the conditional mean, which is deterministic given the draws.
		let process = try #require(AutoregressiveOne(name: "test", persistence: 0.8,
													 longRunMean: 3, shockVolatility: 1))
		let start = 9.0
		let whole = process.step(from: start, dt: 1, normalDraws: 0)
		let firstHalf = process.step(from: start, dt: 0.5, normalDraws: 0)
		let secondHalf = process.step(from: firstHalf, dt: 0.5, normalDraws: 0)
		#expect(abs(whole - secondHalf) < 1e-12,
				"one step gives \(whole), two half-steps give \(secondHalf)")
	}

	@Test("A long path has the stationary mean and variance")
	func pathHasStationaryMoments() throws {
		for phi in [0.0, 0.3, 0.7, 0.9, -0.5] {
			let process = try #require(AutoregressiveOne(name: "test", persistence: phi,
														 longRunMean: 4, shockVolatility: 1.5))
			let series = Self.path(process, count: 200_000, seed: 49_501)
			let mean: Double = series.reduce(0, +) / Double(series.count)
			var sumSquares = 0.0
			for value in series {
				let centred: Double = value - mean
				sumSquares += centred * centred
			}
			let variance: Double = sumSquares / Double(series.count - 1)

			// The effective sample size of a persistent series is much smaller than
			// its length — roughly n(1−φ)/(1+φ) — so the tolerance widens with φ for
			// a reason rather than to make the test pass.
			let effective: Double = Double(series.count) * (1 - abs(phi)) / (1 + abs(phi))
			let meanError: Double = 5 * process.stationaryStandardDeviation / effective.squareRoot()
			#expect(abs(mean - process.longRunMean) < meanError,
					"φ=\(phi): mean \(mean), long-run \(process.longRunMean)")
			#expect(abs(variance - process.stationaryVariance) / process.stationaryVariance < 0.05,
					"φ=\(phi): variance \(variance), stationary \(process.stationaryVariance)")
		}
	}

	@Test("The autocorrelation at lag k is φ^k")
	func autocorrelationDecaysGeometrically() throws {
		// The claim that separates AR(1) from any i.i.d. series with the same
		// stationary distribution. Nothing about the moments would notice it.
		let process = try #require(AutoregressiveOne(name: "test", persistence: 0.75,
													 longRunMean: 0, shockVolatility: 1))
		let series = Self.path(process, count: 300_000, seed: 49_502)
		for lag in 1...6 {
			let sampled = Self.autocorrelation(series, lag: lag)
			let exact = process.autocorrelation(lag: lag)
			#expect(abs(sampled - exact) < 0.02,
					"lag \(lag): sampled \(sampled), φ^\(lag) = \(exact)")
		}
	}

	@Test("Intercept, half-life and the reported moments agree with each other")
	func reportedPropertiesAreConsistent() throws {
		let process = try #require(AutoregressiveOne(name: "test", persistence: 0.5,
													 longRunMean: 10, shockVolatility: 2))
		// c = μ(1 − φ). The two parameterisations are easy to confuse, and passing an
		// intercept where a mean belongs reverts to the wrong level entirely.
		#expect(abs(process.intercept - 5.0) < 1e-12)
		// σ²/(1 − φ²) = 4/0.75.
		#expect(abs(process.stationaryVariance - 4.0 / 0.75) < 1e-12)
		// φ^halfLife = 0.5, by definition.
		let decayed: Double = Foundation.pow(0.5, process.halfLife)
		#expect(abs(decayed - 0.5) < 1e-12, "half-life \(process.halfLife) does not halve")
		#expect(abs(process.autocorrelation(lag: 0) - 1) < 1e-12)
	}

	@Test("A non-stationary AR(1) is refused")
	func nonStationaryProcessesAreRefused() {
		// At |φ| = 1 there is no long-run mean and the variance grows without bound,
		// so every stationary quantity this type reports would describe something
		// that does not exist.
		#expect(AutoregressiveOne(name: "x", persistence: 1.0, longRunMean: 0, shockVolatility: 1) == nil)
		#expect(AutoregressiveOne(name: "x", persistence: -1.0, longRunMean: 0, shockVolatility: 1) == nil)
		#expect(AutoregressiveOne(name: "x", persistence: 1.5, longRunMean: 0, shockVolatility: 1) == nil)
		#expect(AutoregressiveOne(name: "x", persistence: 0.5, longRunMean: 0, shockVolatility: 0) == nil)
	}

	// MARK: - GARCH(1,1)

	private static func garchPath(_ process: GarchOneOne, count: Int, seed: UInt64) -> [Double] {
		var generator = DeterministicRNG(seed: seed)
		let normal = Self.normal
		var state = process.stationaryState
		var returns = [Double]()
		returns.reserveCapacity(count)
		for _ in 0..<5_000 {
			state = process.step(from: state, dt: 1, normalDraws: normal.next(using: &generator))
		}
		for _ in 0..<count {
			state = process.step(from: state, dt: 1, normalDraws: normal.next(using: &generator))
			returns.append(state.value)
		}
		return returns
	}

	@Test("A long path has the unconditional variance")
	func garchPathHasStationaryVariance() throws {
		let process = try #require(GarchOneOne(name: "equity", constant: 0.000004,
											   shockWeight: 0.08, persistenceWeight: 0.90))
		let returns = Self.garchPath(process, count: 400_000, seed: 49_601)
		let mean: Double = returns.reduce(0, +) / Double(returns.count)
		var sumSquares = 0.0
		for value in returns {
			let centred: Double = value - mean
			sumSquares += centred * centred
		}
		let variance: Double = sumSquares / Double(returns.count - 1)
		#expect(abs(variance - process.stationaryVariance) / process.stationaryVariance < 0.15,
				"variance \(variance), unconditional \(process.stationaryVariance)")
		// Conditionally mean-zero at every step, so the path mean is zero.
		let standardError: Double = variance.squareRoot() / Double(returns.count).squareRoot()
		let meanBound: Double = 5 * standardError + 1e-9
		#expect(abs(mean) < meanBound, "path mean \(mean) is not zero")
	}

	@Test("Returns are uncorrelated but their squares are not")
	func volatilityClustersWithoutAutocorrelatedReturns() throws {
		// The two halves of what GARCH claims, and they pull in opposite directions:
		// a model with autocorrelated returns would contradict market efficiency, and
		// one without clustered squares would be an i.i.d. fat-tailed distribution
		// wearing a process's name. Both must hold at once.
		let process = try #require(GarchOneOne(name: "equity", constant: 0.000004,
											   shockWeight: 0.10, persistenceWeight: 0.88))
		let returns = Self.garchPath(process, count: 400_000, seed: 49_602)

		for lag in 1...5 {
			let plain = Self.autocorrelation(returns, lag: lag)
			#expect(abs(plain) < 0.02,
					"returns are autocorrelated at lag \(lag): \(plain)")
		}

		let squares = returns.map { $0 * $0 }
		let clustering = Self.autocorrelation(squares, lag: 1)
		#expect(clustering > 0.05,
				"squared returns show no clustering at lag 1: \(clustering)")
		// And the clustering decays rather than persisting flat, which is what the
		// α + β persistence means.
		let farther = Self.autocorrelation(squares, lag: 10)
		#expect(farther < clustering,
				"clustering at lag 10 (\(farther)) does not decay below lag 1 (\(clustering))")
	}

	@Test("The unconditional distribution has fatter tails than a normal")
	func returnsAreLeptokurtic() throws {
		// Not an extra assumption: every step is conditionally normal, and a mixture
		// of normals with different variances is always heavier-tailed than any one
		// of them. The closed form says how much.
		let process = try #require(GarchOneOne(name: "equity", constant: 0.00001,
											   shockWeight: 0.06, persistenceWeight: 0.90))
		#expect(process.hasFiniteFourthMoment, "this parameterisation has no finite kurtosis to compare")
		let predicted = try #require(process.unconditionalKurtosis)
		#expect(predicted > 3, "predicted kurtosis \(predicted) is not above a normal's")

		let returns = Self.garchPath(process, count: 400_000, seed: 49_603)
		let mean: Double = returns.reduce(0, +) / Double(returns.count)
		var second = 0.0, fourth = 0.0
		for value in returns {
			let d: Double = value - mean
			let d2: Double = d * d
			second += d2
			fourth += d2 * d2
		}
		second /= Double(returns.count)
		fourth /= Double(returns.count)
		let sampled: Double = fourth / (second * second)
		#expect(sampled > 3.2, "sampled kurtosis \(sampled) shows no excess over a normal")
		// Sample kurtosis converges slowly and from below on a clustered series, so
		// this is a generous band around the closed form rather than a tight one.
		#expect(abs(sampled - predicted) / predicted < 0.45,
				"sampled kurtosis \(sampled), closed form \(predicted)")
	}

	@Test("Stationary quantities agree with each other")
	func garchReportedPropertiesAreConsistent() throws {
		let process = try #require(GarchOneOne(name: "x", constant: 0.00002,
											   shockWeight: 0.05, persistenceWeight: 0.90))
		#expect(abs(process.persistence - 0.95) < 1e-12)
		#expect(abs(process.stationaryVariance - 0.00002 / 0.05) < 1e-15)
		#expect(process.stationaryState.variance == process.stationaryVariance)
		// The stationary state is a fixed point of the variance recursion when the
		// squared return equals the variance — which is what "already at the long-run
		// level" has to mean.
		let stepped = process.step(from: GarchState(value: process.stationaryVariance.squareRoot(),
													variance: process.stationaryVariance),
								   dt: 1, normalDraws: 0)
		#expect(abs(stepped.variance - process.stationaryVariance) < 1e-15,
				"the long-run variance is not a fixed point: \(stepped.variance)")
		let halved: Double = Foundation.pow(process.persistence, process.volatilityHalfLife)
		#expect(abs(halved - 0.5) < 1e-12)
	}

	@Test("A non-stationary GARCH is refused")
	func nonStationaryGarchIsRefused() {
		// α + β ≥ 1 diverges, and ω = 0 lets the variance reach zero and stay there,
		// which is an absorbing state rather than a model.
		#expect(GarchOneOne(name: "x", constant: 1e-6, shockWeight: 0.2, persistenceWeight: 0.8) == nil)
		#expect(GarchOneOne(name: "x", constant: 1e-6, shockWeight: 0.5, persistenceWeight: 0.7) == nil)
		#expect(GarchOneOne(name: "x", constant: 0, shockWeight: 0.1, persistenceWeight: 0.8) == nil)
		#expect(GarchOneOne(name: "x", constant: 1e-6, shockWeight: -0.1, persistenceWeight: 0.8) == nil)
	}

	@Test("An infinite fourth moment is reported rather than returned as a number")
	func infiniteKurtosisIsReported() throws {
		// 3α² + 2αβ + β² ≥ 1 with α + β < 1 is an ordinary place for fitted parameters
		// to land. There the sample kurtosis climbs forever instead of settling, and
		// any risk measure resting on a fourth moment is meaningless — so the answer
		// is nil, not a number.
		let heavy = try #require(GarchOneOne(name: "x", constant: 1e-6,
											 shockWeight: 0.45, persistenceWeight: 0.45))
		#expect(!heavy.hasFiniteFourthMoment)
		#expect(heavy.unconditionalKurtosis == nil,
				"a divergent fourth moment was reported as \(String(describing: heavy.unconditionalKurtosis))")
	}
}

//
//  ARMAFamilyTests.swift
//  BusinessMath
//
//  The ARMA family, against its own autocorrelation structure.
//
//  Moments cannot tell these processes apart. An MA(1), an AR(1) and an i.i.d. series
//  can all be given the same mean and the same variance; what separates them is how
//  each period depends on the last, and that lives entirely in the autocorrelation
//  function:
//
//  - **MA(q)** cuts to *exactly* zero beyond lag q. Nothing else does.
//  - **AR(p)** decays geometrically and never reaches zero.
//  - **ARMA(1,1)** has its own first lag and decays at φ thereafter.
//
//  Each has a closed form, so each is checkable against a long path without a
//  reference implementation.
//
//  One further check that no closed form supplies: a pure AR(1) here must be the same
//  law as `AutoregressiveOne`. The two types exist for different reasons — one models
//  the continuous-time correspondence, the other the discrete family — and two
//  implementations of one law that nobody compares is exactly what this package's
//  structure is meant to prevent.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("The ARMA family")
struct ARMAFamilyTests {

	private static let normal = DistributionNormal(0, 1)

	/// Sample autocorrelation at a lag.
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

	private static func path(_ process: AutoregressiveMovingAverage,
							 count: Int, seed: UInt64) -> [Double] {
		var generator = DeterministicRNG(seed: seed)
		let normal = Self.normal
		var state = process.stationaryState
		// Burn in, so the path is sampled from the stationary distribution rather than
		// from the transient of starting with no history.
		for _ in 0..<3_000 {
			state = process.step(from: state, dt: 1, normalDraws: normal.next(using: &generator))
		}
		var series = [Double]()
		series.reserveCapacity(count)
		for _ in 0..<count {
			state = process.step(from: state, dt: 1, normalDraws: normal.next(using: &generator))
			series.append(state.value)
		}
		return series
	}

	// MARK: - One law, two types

	@Test("A pure AR(1) is the same law as AutoregressiveOne")
	func pureAROneMatchesTheDedicatedType() throws {
		// Not a formality. Two implementations of one recursion is precisely the
		// duplication that goes wrong quietly, and the only way to know they agree is
		// to run both and compare draw for draw.
		let phi = 0.75, mu = 4.0, sigma = 1.5
		let family = try #require(AutoregressiveMovingAverage(
			name: "arma", mean: mu, volatility: sigma, autoregressive: [phi]))
		let dedicated = try #require(AutoregressiveOne(
			name: "ar1", persistence: phi, longRunMean: mu, shockVolatility: sigma))
		#expect(family.matchesAutoregressiveOne(dedicated))

		// Same shocks into both, step by step.
		var state = ARMAState(value: mu, deviations: [0], errors: [])
		var level = mu
		var generator = DeterministicRNG(seed: 52_001)
		for index in 0..<500 {
			let shock = Self.normal.next(using: &generator)
			state = family.step(from: state, dt: 1, normalDraws: shock)
			level = dedicated.step(from: level, dt: 1, normalDraws: shock)
			#expect(abs(state.value - level) < 1e-9,
					"step \(index): family \(state.value), dedicated \(level)")
		}

		// And their reported stationary quantities agree.
		let familyVariance = try #require(family.stationaryVariance)
		#expect(abs(familyVariance - dedicated.stationaryVariance) < 1e-12)
		for lag in 1...5 {
			let fromFamily = try #require(family.autocorrelation(lag: lag))
			#expect(abs(fromFamily - dedicated.autocorrelation(lag: lag)) < 1e-12,
					"lag \(lag)")
		}
	}

	// MARK: - The moving-average cut-off

	@Test("An MA(q) autocorrelation is exactly zero beyond lag q")
	func movingAverageCutsOff() throws {
		// The identifying property of the family, and the one a variance check cannot
		// see. An AR with the same variance is correlated at every lag.
		let ma1 = try #require(AutoregressiveMovingAverage(
			name: "ma1", mean: 0, volatility: 1, movingAverage: [0.6]))
		#expect(try #require(ma1.autocorrelation(lag: 2)) == 0)
		#expect(try #require(ma1.autocorrelation(lag: 5)) == 0)

		let ma2 = try #require(AutoregressiveMovingAverage(
			name: "ma2", mean: 0, volatility: 1, movingAverage: [0.5, 0.3]))
		#expect(try #require(ma2.autocorrelation(lag: 3)) == 0)

		// ρ₁ = θ/(1 + θ²) for an MA(1) — 0.6/1.36.
		let expectedFirst: Double = 0.6 / 1.36
		#expect(abs(try #require(ma1.autocorrelation(lag: 1)) - expectedFirst) < 1e-12)

		// And the path agrees.
		let series = Self.path(ma1, count: 300_000, seed: 52_002)
		#expect(abs(Self.autocorrelation(series, lag: 1) - expectedFirst) < 0.02,
				"lag 1 sampled \(Self.autocorrelation(series, lag: 1)), exact \(expectedFirst)")
		#expect(abs(Self.autocorrelation(series, lag: 2)) < 0.02,
				"lag 2 sampled \(Self.autocorrelation(series, lag: 2)), should be zero")
		#expect(abs(Self.autocorrelation(series, lag: 4)) < 0.02)
	}

	@Test("An MA(2) matches its closed-form autocorrelations")
	func maTwoMatchesItsForm() throws {
		let theta1 = 0.5, theta2 = 0.3
		let ma2 = try #require(AutoregressiveMovingAverage(
			name: "ma2", mean: 0, volatility: 1, movingAverage: [theta1, theta2]))
		// ρ₁ = (θ₁ + θ₁θ₂)/(1 + θ₁² + θ₂²),  ρ₂ = θ₂/(1 + θ₁² + θ₂²)
		let denominator: Double = 1 + theta1 * theta1 + theta2 * theta2
		let first: Double = (theta1 + theta1 * theta2) / denominator
		let second: Double = theta2 / denominator
		#expect(abs(try #require(ma2.autocorrelation(lag: 1)) - first) < 1e-12)
		#expect(abs(try #require(ma2.autocorrelation(lag: 2)) - second) < 1e-12)

		let series = Self.path(ma2, count: 300_000, seed: 52_003)
		#expect(abs(Self.autocorrelation(series, lag: 1) - first) < 0.02)
		#expect(abs(Self.autocorrelation(series, lag: 2) - second) < 0.02)
		#expect(abs(Self.autocorrelation(series, lag: 3)) < 0.02)
	}

	// MARK: - AR(2)

	@Test("An AR(2) follows the Yule–Walker recursion")
	func arTwoFollowsYuleWalker() throws {
		let phi1 = 0.5, phi2 = 0.3
		let ar2 = try #require(AutoregressiveMovingAverage(
			name: "ar2", mean: 2, volatility: 1, autoregressive: [phi1, phi2]))
		// ρ₁ = φ₁/(1 − φ₂), then ρₖ = φ₁ρₖ₋₁ + φ₂ρₖ₋₂.
		let first: Double = phi1 / (1 - phi2)
		let second: Double = phi1 * first + phi2
		#expect(abs(try #require(ar2.autocorrelation(lag: 1)) - first) < 1e-12)
		#expect(abs(try #require(ar2.autocorrelation(lag: 2)) - second) < 1e-12)

		let series = Self.path(ar2, count: 400_000, seed: 52_004)
		for lag in 1...4 {
			let exact = try #require(ar2.autocorrelation(lag: lag))
			let sampled = Self.autocorrelation(series, lag: lag)
			#expect(abs(sampled - exact) < 0.03, "lag \(lag): sampled \(sampled), exact \(exact)")
		}
		// Unlike an MA, it never reaches zero — it decays and stays positive. Asserted
		// structurally rather than against a threshold: this AR(2) has φ₁ + φ₂ = 0.8
		// and is persistent enough that ρ₈ is still 0.246, so any number picked by eye
		// would be picked wrongly. Strictly decreasing and strictly positive is what
		// the recursion actually promises.
		var previous = try #require(ar2.autocorrelation(lag: 2))
		for lag in 3...10 {
			let value = try #require(ar2.autocorrelation(lag: lag))
			#expect(value > 0, "lag \(lag) autocorrelation \(value) is not positive")
			#expect(value < previous, "lag \(lag) autocorrelation \(value) did not decay below \(previous)")
			previous = value
		}
		// Still meaningfully non-zero at lag 8, which is the contrast with an MA(q)
		// that is exactly zero past its order.
		#expect(try #require(ar2.autocorrelation(lag: 8)) > 1e-3)
	}

	@Test("The AR(2) stationarity triangle is enforced in all three directions")
	func stationarityTriangleIsEnforced() {
		// All three conditions are needed. Dropping any one admits a process whose
		// variance diverges, and every stationary quantity this type reports would
		// then describe something that does not exist.
		#expect(AutoregressiveMovingAverage.isStationary([0.5, 0.3]))
		#expect(AutoregressiveMovingAverage.isStationary([-0.5, 0.3]))
		// |φ₂| < 1
		#expect(!AutoregressiveMovingAverage.isStationary([0.1, 1.0]))
		#expect(!AutoregressiveMovingAverage.isStationary([0.1, -1.0]))
		// φ₁ + φ₂ < 1
		#expect(!AutoregressiveMovingAverage.isStationary([0.8, 0.3]))
		// φ₂ − φ₁ < 1
		#expect(!AutoregressiveMovingAverage.isStationary([-0.8, 0.9]))
		// And the initialiser refuses them.
		#expect(AutoregressiveMovingAverage(name: "x", mean: 0, volatility: 1,
											autoregressive: [0.8, 0.3]) == nil)
		#expect(AutoregressiveMovingAverage(name: "x", mean: 0, volatility: 1,
											autoregressive: [0.5, 0.3, 0.1]) == nil)
	}

	// MARK: - ARMA(1,1)

	@Test("An ARMA(1,1) has both an AR decay and an MA echo")
	func armaOneOneCombinesBoth() throws {
		let phi = 0.7, theta = 0.4
		let arma = try #require(AutoregressiveMovingAverage(
			name: "arma11", mean: 0, volatility: 1,
			autoregressive: [phi], movingAverage: [theta]))
		// ρ₁ = (1 + φθ)(φ + θ)/(1 + 2φθ + θ²), then ρₖ = φρₖ₋₁.
		let denominator: Double = 1 + 2 * phi * theta + theta * theta
		let first: Double = (1 + phi * theta) * (phi + theta) / denominator
		#expect(abs(try #require(arma.autocorrelation(lag: 1)) - first) < 1e-12)
		let secondExpected: Double = first * phi
		#expect(abs(try #require(arma.autocorrelation(lag: 2)) - secondExpected) < 1e-12)

		// The MA term makes the first lag higher than a pure AR(1) with the same φ
		// would give — that is what the echo is, and it is the whole reason to use
		// ARMA rather than AR.
		let pureAR = try #require(AutoregressiveMovingAverage(
			name: "ar1", mean: 0, volatility: 1, autoregressive: [phi]))
		#expect(first > (try #require(pureAR.autocorrelation(lag: 1))),
				"the moving-average term did not raise the first autocorrelation")

		let series = Self.path(arma, count: 400_000, seed: 52_005)
		for lag in 1...4 {
			let exact = try #require(arma.autocorrelation(lag: lag))
			let sampled = Self.autocorrelation(series, lag: lag)
			#expect(abs(sampled - exact) < 0.03, "lag \(lag): sampled \(sampled), exact \(exact)")
		}
	}

	// MARK: - Moments

	@Test("Every member has the stationary mean and variance it reports")
	func stationaryMomentsHold() throws {
		let cases: [(String, [Double], [Double])] = [
			("ar1", [0.7], []),
			("ar2", [0.5, 0.3], []),
			("ma1", [], [0.6]),
			("ma2", [], [0.5, 0.3]),
			("arma11", [0.7], [0.4]),
		]
		for (label, phi, theta) in cases {
			let process = try #require(AutoregressiveMovingAverage(
				name: label, mean: 5, volatility: 2,
				autoregressive: phi, movingAverage: theta))
			let series = Self.path(process, count: 300_000, seed: 52_100)
			let sampleMean: Double = series.reduce(0, +) / Double(series.count)
			var sumSquares = 0.0
			for value in series {
				let centred: Double = value - sampleMean
				sumSquares += centred * centred
			}
			let sampleVariance: Double = sumSquares / Double(series.count - 1)
			let exact = try #require(process.stationaryVariance)

			#expect(abs(sampleMean - 5) < 0.05, "\(label): mean \(sampleMean)")
			#expect(abs(sampleVariance - exact) / exact < 0.05,
					"\(label): variance \(sampleVariance), exact \(exact)")
		}
	}

	@Test("A pure MA's variance is sigma squared times one plus the squared coefficients")
	func movingAverageVarianceIsClosedForm() throws {
		let ma2 = try #require(AutoregressiveMovingAverage(
			name: "ma2", mean: 0, volatility: 3, movingAverage: [0.5, 0.3]))
		// 9 · (1 + 0.25 + 0.09) = 12.06
		let expected: Double = 9 * (1 + 0.25 + 0.09)
		#expect(abs(try #require(ma2.stationaryVariance) - expected) < 1e-12)
	}

	// MARK: - Refusals

	@Test("Arguments that do not describe an ARMA process are refused")
	func invalidArgumentsAreRefused() throws {
		#expect(AutoregressiveMovingAverage(name: "x", mean: 0, volatility: 0,
											autoregressive: [0.5]) == nil)
		#expect(AutoregressiveMovingAverage(name: "x", mean: 0, volatility: -1) == nil)
		#expect(AutoregressiveMovingAverage(name: "x", mean: .nan, volatility: 1) == nil)
		#expect(AutoregressiveMovingAverage(name: "x", mean: 0, volatility: 1,
											movingAverage: [0.1, 0.2, 0.3]) == nil)
		#expect(AutoregressiveMovingAverage(name: "x", mean: 0, volatility: 1,
											autoregressive: [.infinity]) == nil)
		// A pure shock with no memory at all is legitimate: white noise is an ARMA(0,0),
		// and it must behave like one — uncorrelated at every lag, with variance σ².
		let noise = AutoregressiveMovingAverage(name: "noise", mean: 0, volatility: 3)
		let whiteNoise = try #require(noise)
		#expect(abs(try #require(whiteNoise.stationaryVariance) - 9) < 1e-12)
		for lag in 1...4 {
			#expect(try #require(whiteNoise.autocorrelation(lag: lag)) == 0,
					"white noise is correlated at lag \(lag)")
		}
	}
}

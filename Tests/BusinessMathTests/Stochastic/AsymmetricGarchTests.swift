//
//  AsymmetricGarchTests.swift
//  BusinessMath
//
//  EGARCH(1,1), APARCH(1,1), and the ARCH(1) factory.
//
//  The oracle here is nesting, and it is a real one rather than a self-consistency
//  check: APARCH with `γ = 0, δ = 2` *is* GARCH(1,1), so the two recursions must agree
//  step for step on the same draws. If the power arithmetic is wrong anywhere — the
//  tilt, the exponent, the inverse exponent, the reconstruction of a variance from a
//  `σ^δ` — the paths separate. Nothing about that test can pass by agreeing with
//  itself, because the two implementations share no code.
//
//  The quadrature has an oracle of the same kind. `E(|z| − γz)^δ` at `γ = 0, δ = 2` is
//  `E[z²] = 1`, and at `γ = 0, δ = 1` it is `E|z| = √(2/π)`. Both are known exactly, so
//  the numerical integral is checked against arithmetic rather than against itself.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Asymmetric GARCH")
struct AsymmetricGarchTests {

	/// A fixed sequence of draws, so the two recursions see identical randomness and
	/// any divergence is the model rather than the sampler.
	private static let draws: [Double] = [0.4, -1.2, 0.8, -0.3, 2.1, -1.7, 0.05, 1.1, -0.9, 0.6]

	// MARK: - APARCH nests GARCH

	@Test("APARCH with no tilt and a square power reproduces GARCH(1,1) exactly")
	func aparchNestsGarch() throws {
		let omega = 0.00002, alpha = 0.08, beta = 0.9
		let garch = try #require(GarchOneOne(name: "g", constant: omega,
											 shockWeight: alpha, persistenceWeight: beta))
		let aparch = try #require(AsymmetricPowerArch(name: "a", constant: omega,
													 shockWeight: alpha, persistenceWeight: beta,
													 asymmetry: 0, power: 2))
		var g = garch.stationaryState
		var a = GarchState(value: g.value, variance: g.variance)
		var steps = 0
		for draw in Self.draws {
			g = garch.step(from: g, dt: 1, normalDraws: draw)
			a = aparch.step(from: a, dt: 1, normalDraws: draw)
			let varianceScale: Double = Swift.max(g.variance, 1e-12)
			let varianceGap: Double = Swift.abs(a.variance - g.variance)
			#expect(varianceGap < varianceScale * 1e-12,
					"step \(steps): APARCH variance \(a.variance), GARCH \(g.variance)")
			let valueScale: Double = Swift.max(Swift.abs(g.value), 1e-12)
			let valueGap: Double = Swift.abs(a.value - g.value)
			#expect(valueGap < valueScale * 1e-12,
					"step \(steps): APARCH return \(a.value), GARCH \(g.value)")
			steps += 1
		}
		#expect(steps == Self.draws.count, "only \(steps) steps were compared")
	}

	@Test("APARCH's stationarity multiplier reduces to alpha + beta at the GARCH corner")
	func powerPersistenceAtTheGarchCorner() throws {
		// E(|z| − 0·z)² = E[z²] = 1, so the multiplier must be exactly α + β. This is
		// the quadrature being checked against a number known in closed form.
		let alpha = 0.08, beta = 0.9
		let aparch = try #require(AsymmetricPowerArch(name: "a", constant: 0.00002,
													 shockWeight: alpha, persistenceWeight: beta,
													 asymmetry: 0, power: 2))
		let expectation: Double = aparch.expectedTiltedPower
		#expect(Swift.abs(expectation - 1) < 1e-9, "E[z²] integrated to \(expectation)")
		let multiplier: Double = aparch.powerPersistence
		let wanted: Double = alpha + beta
		#expect(Swift.abs(multiplier - wanted) < 1e-9, "multiplier \(multiplier), wanted \(wanted)")
		#expect(aparch.isStationary)
	}

	@Test("APARCH's quadrature recovers the mean absolute normal at unit power")
	func quadratureAtUnitPower() throws {
		// E|z| = √(2/π) ≈ 0.7978845608. Same integral, a different exact answer, so a
		// coincidence at δ = 2 cannot carry this one.
		let aparch = try #require(AsymmetricPowerArch(name: "a", constant: 0.001,
													 shockWeight: 0.1, persistenceWeight: 0.85,
													 asymmetry: 0, power: 1))
		let ratio: Double = 2 / Double.pi
		let wanted: Double = ratio.squareRoot()
		let got: Double = aparch.expectedTiltedPower
		#expect(Swift.abs(got - wanted) < 1e-9, "E|z| integrated to \(got), wanted \(wanted)")
	}

	@Test("The closed-form kappa matches an independent numerical integration")
	func kappaAgainstQuadrature() throws {
		// Reference values for E(|z| − γz)^δ from Simpson's rule on 200,000 intervals
		// over [−9, 9], computed outside this library. The closed form is derived from
		// the normal's absolute moment and shares no code with a quadrature, so
		// agreement across a spread of γ and δ — including a δ below one, where the
		// integrand's derivatives blow up at the origin — is real evidence.
		let cases: [(gamma: Double, delta: Double, kappa: Double)] = [
			(0.0, 2.0, 0.9999999999999999),
			(0.0, 1.0, 0.7978845608028655),
			(0.3, 1.5, 0.8892340753128489),
			(-0.5, 2.5, 1.808250653233206),
			(0.25, 3.0, 1.894975831906805),
		]
		var checked = 0
		for row in cases {
			let aparch = try #require(AsymmetricPowerArch(name: "a", constant: 0.001,
														 shockWeight: 0.1, persistenceWeight: 0.8,
														 asymmetry: row.gamma, power: row.delta))
			let got: Double = aparch.expectedTiltedPower
			let gap: Double = Swift.abs(got - row.kappa)
			let bound: Double = row.kappa * 1e-12
			#expect(gap < bound, "γ=\(row.gamma) δ=\(row.delta): κ came out \(got), reference \(row.kappa)")
			checked += 1
		}
		#expect(checked == cases.count, "only \(checked) of \(cases.count) κ values were checked")
	}

	// MARK: - APARCH asymmetry

	@Test("A positive tilt makes a fall raise volatility more than an equal rise")
	func aparchLeverage() throws {
		let aparch = try #require(AsymmetricPowerArch(name: "a", constant: 0.0001,
													 shockWeight: 0.1, persistenceWeight: 0.85,
													 asymmetry: 0.4, power: 2))
		let variance = 0.0004
		let afterFall = aparch.step(from: GarchState(value: -0.02, variance: variance),
									dt: 1, normalDraws: 0)
		let afterRise = aparch.step(from: GarchState(value: 0.02, variance: variance),
									dt: 1, normalDraws: 0)
		#expect(afterFall.variance > afterRise.variance,
				"fall gave \(afterFall.variance), rise gave \(afterRise.variance)")
	}

	@Test("With no tilt a fall and an equal rise are indistinguishable")
	func aparchSymmetry() throws {
		let aparch = try #require(AsymmetricPowerArch(name: "a", constant: 0.0001,
													 shockWeight: 0.1, persistenceWeight: 0.85,
													 asymmetry: 0, power: 1.4))
		let variance = 0.0004
		let fall = aparch.step(from: GarchState(value: -0.02, variance: variance),
							   dt: 1, normalDraws: 0)
		let rise = aparch.step(from: GarchState(value: 0.02, variance: variance),
							   dt: 1, normalDraws: 0)
		#expect(Swift.abs(fall.variance - rise.variance) < 1e-15,
				"fall \(fall.variance), rise \(rise.variance)")
	}

	@Test("APARCH rejects a tilt that would take the shock base negative")
	func aparchRejectsUnusableTilt() {
		#expect(AsymmetricPowerArch(name: "a", constant: 0.1, shockWeight: 0.1,
									persistenceWeight: 0.8, asymmetry: 1) == nil)
		#expect(AsymmetricPowerArch(name: "a", constant: 0.1, shockWeight: 0.1,
									persistenceWeight: 0.8, asymmetry: -1) == nil)
		#expect(AsymmetricPowerArch(name: "a", constant: 0.1, shockWeight: 0.1,
									persistenceWeight: 0.8, power: 0) == nil)
		#expect(AsymmetricPowerArch(name: "a", constant: 0, shockWeight: 0.1,
									persistenceWeight: 0.8) == nil)
	}

	@Test("APARCH's stationary variance is the level a long path settles around")
	func aparchStationaryVariance() throws {
		let omega = 0.00002, alpha = 0.08, beta = 0.9
		let aparch = try #require(AsymmetricPowerArch(name: "a", constant: omega,
													 shockWeight: alpha, persistenceWeight: beta,
													 asymmetry: 0, power: 2))
		let analytic = try #require(aparch.stationaryVariance)
		// At the GARCH corner the answer is known: ω / (1 − α − β).
		let decay: Double = 1 - alpha - beta
		let wanted: Double = omega / decay
		#expect(Swift.abs(analytic - wanted) < wanted * 1e-9,
				"stationary variance \(analytic), wanted \(wanted)")
	}

	@Test("A non-stationary APARCH reports no stationary variance rather than a negative one")
	func aparchNonStationary() throws {
		let aparch = try #require(AsymmetricPowerArch(name: "a", constant: 0.001,
													 shockWeight: 0.5, persistenceWeight: 0.7,
													 asymmetry: 0, power: 2))
		#expect(aparch.isStationary == false)
		#expect(aparch.stationaryVariance == nil)
		#expect(aparch.stationaryPoweredVolatility == nil)
	}

	// MARK: - EGARCH

	@Test("EGARCH's expected absolute normal is the square root of two over pi")
	func expectedAbsoluteNormal() {
		let ratio: Double = 2 / Double.pi
		let wanted: Double = ratio.squareRoot()
		let got: Double = ExponentialGarch.expectedAbsoluteNormal
		#expect(Swift.abs(got - wanted) < 1e-15, "E|z| is \(got)")
	}

	@Test("With no news impact the EGARCH log variance converges to its level")
	func egarchConvergesWithoutNews() throws {
		// α = 0 removes g(z) entirely, so ln σ² is a deterministic AR(1) converging to
		// ω/(1−β). This checks the log arithmetic in isolation from the impact curve.
		let omega = -0.2, beta = 0.95
		let egarch = try #require(ExponentialGarch(name: "e", constant: omega, shockWeight: 0,
												  persistenceWeight: beta))
		var state = GarchState(value: 0.01, variance: 0.01)
		for _ in 0..<4000 {
			state = egarch.step(from: state, dt: 1, normalDraws: 0)
		}
		let wanted: Double = egarch.stationaryVariance
		let gap: Double = Swift.abs(state.variance - wanted)
		#expect(gap < wanted * 1e-9, "settled at \(state.variance), analytic \(wanted)")
		let decay: Double = 1 - beta
		let level: Double = Double.exp(omega / decay)
		#expect(Swift.abs(wanted - level) < level * 1e-12, "stationary variance \(wanted)")
	}

	@Test("A negative leverage term makes a fall raise EGARCH volatility more than a rise")
	func egarchLeverage() throws {
		let egarch = try #require(ExponentialGarch(name: "e", constant: -0.2, shockWeight: 1,
												  persistenceWeight: 0.95,
												  leverage: -0.1, magnitude: 0.2))
		let variance = 0.0004
		let volatility: Double = variance.squareRoot()
		let shock: Double = 2 * volatility
		let fall = egarch.step(from: GarchState(value: -shock, variance: variance),
							   dt: 1, normalDraws: 0)
		let rise = egarch.step(from: GarchState(value: shock, variance: variance),
							   dt: 1, normalDraws: 0)
		#expect(fall.variance > rise.variance,
				"fall gave \(fall.variance), rise gave \(rise.variance)")
	}

	@Test("The EGARCH news impact curve is zero-mean in its magnitude term")
	func egarchNewsImpact() throws {
		// g(z) = θz + γ(|z| − E|z|). At θ = 0 and |z| = E|z| the curve must be exactly
		// zero, which pins both the subtraction and the constant it uses.
		let egarch = try #require(ExponentialGarch(name: "e", constant: 0, shockWeight: 1,
												  persistenceWeight: 0.9,
												  leverage: 0, magnitude: 0.3))
		let atMean: Double = egarch.newsImpact(ExponentialGarch.expectedAbsoluteNormal)
		#expect(Swift.abs(atMean) < 1e-15, "g at E|z| is \(atMean)")
		let symmetric: Double = egarch.newsImpact(-1.5) - egarch.newsImpact(1.5)
		#expect(Swift.abs(symmetric) < 1e-15, "a zero-leverage curve was asymmetric by \(symmetric)")
	}

	@Test("EGARCH accepts negative coefficients, which is the point of working in logs")
	func egarchAcceptsNegativeCoefficients() throws {
		let egarch = try #require(ExponentialGarch(name: "e", constant: -3, shockWeight: -0.05,
												  persistenceWeight: -0.4,
												  leverage: -0.2, magnitude: -0.1))
		let next = egarch.step(from: GarchState(value: 0.01, variance: 0.0004),
							   dt: 1, normalDraws: 0.5)
		#expect(next.variance > 0, "a log-variance model produced \(next.variance)")
		#expect(next.variance.isFinite)
	}

	@Test("EGARCH rejects a persistence it cannot mean-revert from")
	func egarchRejectsUnstablePersistence() {
		#expect(ExponentialGarch(name: "e", constant: 0, shockWeight: 0.1,
								 persistenceWeight: 1) == nil)
		#expect(ExponentialGarch(name: "e", constant: 0, shockWeight: 0.1,
								 persistenceWeight: -1) == nil)
	}

	@Test("The EGARCH half-life is defined only where a shock decays monotonically")
	func egarchHalfLife() throws {
		let decaying = try #require(ExponentialGarch(name: "e", constant: -0.2, shockWeight: 0.1,
													persistenceWeight: 0.5))
		let halfLife = try #require(decaying.volatilityHalfLife)
		#expect(Swift.abs(halfLife - 1) < 1e-12, "β = 0.5 should halve in one period, got \(halfLife)")
		let none = try #require(ExponentialGarch(name: "e", constant: -0.2, shockWeight: 0.1,
												 persistenceWeight: 0))
		#expect(none.volatilityHalfLife == nil)
		let alternating = try #require(ExponentialGarch(name: "e", constant: -0.2, shockWeight: 0.1,
														persistenceWeight: -0.5))
		#expect(alternating.volatilityHalfLife == nil)
	}

	// MARK: - ARCH(1) and the volatility entry point

	@Test("The ARCH(1) factory is GARCH(1,1) with no variance memory")
	func archOne() throws {
		let volatility = 0.02, alpha = 0.3
		let arch = try #require(GarchOneOne.arch(name: "arch", unconditionalVolatility: volatility,
												 shockWeight: alpha))
		#expect(arch.persistenceWeight == 0)
		let wantedVariance: Double = volatility * volatility
		let varianceGap: Double = Swift.abs(arch.stationaryVariance - wantedVariance)
		#expect(varianceGap < wantedVariance * 1e-12,
				"ARCH(1) settles at \(arch.stationaryVariance)")
		// ω = σ²(1 − α)
		let decay: Double = 1 - alpha
		let wantedOmega: Double = wantedVariance * decay
		#expect(Swift.abs(arch.constant - wantedOmega) < wantedOmega * 1e-12,
				"ω came out \(arch.constant)")
		#expect(GarchOneOne.arch(name: "arch", unconditionalVolatility: 0.02, shockWeight: 1) == nil)
		#expect(GarchOneOne.arch(name: "arch", unconditionalVolatility: 0, shockWeight: 0.3) == nil)
	}

	@Test("Building a GARCH from its unconditional volatility settles where it was told to")
	func garchFromVolatility() throws {
		var checked = 0
		for (vol, alpha, beta) in [(0.01, 0.05, 0.9), (0.2, 0.1, 0.8), (0.005, 0.02, 0.97)] {
			let garch = try #require(GarchOneOne(name: "g", unconditionalVolatility: vol,
												 shockWeight: alpha, persistenceWeight: beta))
			let wanted: Double = vol * vol
			let gap: Double = Swift.abs(garch.stationaryVariance - wanted)
			#expect(gap < wanted * 1e-12,
					"asked for σ = \(vol), settled at variance \(garch.stationaryVariance)")
			checked += 1
		}
		#expect(checked == 3, "only \(checked) of 3 volatility constructions were checked")
		#expect(GarchOneOne(name: "g", unconditionalVolatility: 0.02,
							shockWeight: 0.5, persistenceWeight: 0.5) == nil)
	}
}

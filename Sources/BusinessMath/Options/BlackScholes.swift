//
//  BlackScholes.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

// MARK: - OptionType

/// Type of option contract.
public enum OptionType: Sendable {
	/// Call option (right to buy).
	case call

	/// Put option (right to sell).
	case put
}

// MARK: - BlackScholesModel

/// Black-Scholes option pricing model.
///
/// `BlackScholesModel` implements the famous Black-Scholes-Merton formula
/// for pricing European-style options and calculating option Greeks.
///
/// ## Usage
///
/// ```swift
/// let price = BlackScholesModel<Double>.price(
///     optionType: .call,
///     spotPrice: 100.0,
///     strikePrice: 105.0,
///     timeToExpiry: 0.25,  // 3 months
///     riskFreeRate: 0.05,
///     volatility: 0.20
/// )
/// ```
public struct BlackScholesModel<T: Real & Sendable> {

	// MARK: - Option Pricing

	/// Calculate option price using Black-Scholes formula.
	///
	/// - Parameters:
	///   - optionType: Call or put option.
	///   - spotPrice: Current price of underlying asset.
	///   - strikePrice: Strike price of option.
	///   - timeToExpiry: Time to expiration in years.
	///   - riskFreeRate: Risk-free interest rate (annual).
	///   - volatility: Volatility of underlying asset (annual).
	/// - Returns: Option price.
	public static func price(
		optionType: OptionType,
		spotPrice: T,
		strikePrice: T,
		timeToExpiry: T,
		riskFreeRate: T,
		volatility: T
	) -> T {

		// `calculateD1` divides by `volatility * sqrt(timeToExpiry)`. When that is zero the
		// underlying is not random any more, and the formula below has no diffusion to
		// integrate over — see ``zeroDiffusionPrice(optionType:spotPrice:strikePrice:timeToExpiry:riskFreeRate:)``.
		//
		// Measured before this branch existed: an at-the-money option valued **on its expiry
		// date** returned NaN, as did every one of its Greeks. Away from the strike the old
		// path happened to be right — `d1` went to +/-infinity and the normal CDF saturated to
		// 1 or 0 — so the defect was invisible anywhere except exactly at the money.
		let diffusion: T = volatility * T.sqrt(timeToExpiry)
		if diffusion <= T.zero {
			return zeroDiffusionPrice(
				optionType: optionType,
				spotPrice: spotPrice,
				strikePrice: strikePrice,
				timeToExpiry: timeToExpiry,
				riskFreeRate: riskFreeRate
			)
		}

		let d1 = calculateD1(
			spotPrice: spotPrice,
			strikePrice: strikePrice,
			timeToExpiry: timeToExpiry,
			riskFreeRate: riskFreeRate,
			volatility: volatility
		)

		let d2 = d1 - volatility * T.sqrt(timeToExpiry)

		switch optionType {
		case .call:
			return spotPrice * normalCDF(x: d1) -
				   strikePrice * T.exp(-riskFreeRate * timeToExpiry) * normalCDF(x: d2)

		case .put:
			return strikePrice * T.exp(-riskFreeRate * timeToExpiry) * normalCDF(x: -d2) -
				   spotPrice * normalCDF(x: -d1)
		}
	}

	// MARK: - Greeks

	/// Calculate option Greeks (sensitivities).
	///
	/// - Parameters:
	///   - optionType: Call or put option.
	///   - spotPrice: Current price of underlying asset.
	///   - strikePrice: Strike price of option.
	///   - timeToExpiry: Time to expiration in years.
	///   - riskFreeRate: Risk-free interest rate (annual).
	///   - volatility: Volatility of underlying asset (annual).
	/// - Returns: Greeks structure with all sensitivities.
	public static func greeks(
		optionType: OptionType,
		spotPrice: T,
		strikePrice: T,
		timeToExpiry: T,
		riskFreeRate: T,
		volatility: T
	) -> Greeks<T> {

		let diffusion: T = volatility * T.sqrt(timeToExpiry)
		if diffusion <= T.zero {
			return zeroDiffusionGreeks(
				optionType: optionType,
				spotPrice: spotPrice,
				strikePrice: strikePrice,
				timeToExpiry: timeToExpiry,
				riskFreeRate: riskFreeRate
			)
		}

		let d1 = calculateD1(
			spotPrice: spotPrice,
			strikePrice: strikePrice,
			timeToExpiry: timeToExpiry,
			riskFreeRate: riskFreeRate,
			volatility: volatility
		)

		let d2 = d1 - volatility * T.sqrt(timeToExpiry)

		// Delta: ∂V/∂S
		let delta: T
		if optionType == .call {
			delta = normalCDF(x: d1)
		} else {
			delta = normalCDF(x: d1) - T(1)
		}

		// Gamma: ∂²V/∂S²
		//
		// The divisor is zero for a second reason the diffusion branch above does not cover: a
		// spot of zero. Zero is absorbing under geometric Brownian motion, so an option on a
		// wiped-out asset is worth nothing and stays worth nothing — no delta, and therefore no
		// curvature either. Measured before this guard: `gamma` came back NaN while every other
		// Greek was correctly zero.
		let gammaDivisor: T = spotPrice * volatility * T.sqrt(timeToExpiry)
		let gamma: T = gammaDivisor > T.zero ? normalPDF(x: d1) / gammaDivisor : T.zero

		// Vega: ∂V/∂σ
		let vega = spotPrice * normalPDF(x: d1) * T.sqrt(timeToExpiry)

		// Theta: ∂V/∂t
		let theta: T
		let term1 = -(spotPrice * normalPDF(x: d1) * volatility) / (T(2) * T.sqrt(timeToExpiry))
		if optionType == .call {
			let term2 = riskFreeRate * strikePrice * T.exp(-riskFreeRate * timeToExpiry) * normalCDF(x: d2)
			theta = term1 - term2
		} else {
			let term2 = riskFreeRate * strikePrice * T.exp(-riskFreeRate * timeToExpiry) * normalCDF(x: -d2)
			theta = term1 + term2
		}

		// Rho: ∂V/∂r
		let rho: T
		if optionType == .call {
			rho = strikePrice * timeToExpiry * T.exp(-riskFreeRate * timeToExpiry) * normalCDF(x: d2)
		} else {
			rho = -strikePrice * timeToExpiry * T.exp(-riskFreeRate * timeToExpiry) * normalCDF(x: -d2)
		}

		return Greeks(delta: delta, gamma: gamma, vega: vega, theta: theta, rho: rho)
	}

	// MARK: - The zero-diffusion limit

	/// What the option is worth when `volatility * sqrt(timeToExpiry)` is zero.
	///
	/// At expiry, or on an asset with no volatility, the underlying is no longer random: it
	/// arrives at its forward `S * exp(rT)` with certainty. The option is then worth the
	/// discounted payoff on that forward, `max(S - K * exp(-rT), 0)` for a call.
	///
	/// At `timeToExpiry == 0` the discount factor is 1 and this reduces to the intrinsic value
	/// `max(S - K, 0)` — what an option is worth on the day it expires, which is an ordinary
	/// thing to ask for and used to come back as NaN.
	///
	/// This is also **the same number the old path produced wherever the old path worked**:
	/// with zero diffusion `d1` saturates the normal CDF to exactly 1 or 0, leaving
	/// `spotPrice - strikePrice * exp(-rT)` or zero. Only the at-the-money point, where the
	/// saturation was `0 / 0`, changes.
	internal static func zeroDiffusionPrice(
		optionType: OptionType,
		spotPrice: T,
		strikePrice: T,
		timeToExpiry: T,
		riskFreeRate: T
	) -> T {
		let discountedStrike: T = strikePrice * T.exp(-riskFreeRate * timeToExpiry)
		switch optionType {
		case .call:
			return T.maximum(spotPrice - discountedStrike, T.zero)
		case .put:
			return T.maximum(discountedStrike - spotPrice, T.zero)
		}
	}

	/// The Greeks of that same deterministic option.
	///
	/// With no diffusion the payoff is piecewise linear in the spot, so every sensitivity is
	/// either the slope of one of those two pieces or zero:
	///
	/// - **Delta** is 1 (call) or -1 (put) while the forward finishes in the money, 0 otherwise.
	/// - **Gamma** is the curvature of a kink: zero everywhere the payoff is linear, and
	///   unbounded at the strike itself. It is reported as `infinity` there rather than NaN,
	///   because the value is genuinely a Dirac delta and not a missing number.
	/// - **Vega** is zero: there is no diffusion for the price to be sensitive to.
	/// - **Theta** is the carry on the discounted strike, and zero out of the money.
	/// - **Rho** is the usual `K * T * exp(-rT)`, signed by the option type, and zero out of
	///   the money.
	///
	/// Every one of these agrees with what the old path returned wherever it returned a
	/// number; what changes is that `gamma` is no longer NaN and nothing is NaN at the money.
	internal static func zeroDiffusionGreeks(
		optionType: OptionType,
		spotPrice: T,
		strikePrice: T,
		timeToExpiry: T,
		riskFreeRate: T
	) -> Greeks<T> {
		let discountFactor: T = T.exp(-riskFreeRate * timeToExpiry)
		let discountedStrike: T = strikePrice * discountFactor
		let atTheMoney: Bool = spotPrice.isEqual(to: discountedStrike)
		let inTheMoney: Bool = optionType == .call
			? spotPrice > discountedStrike
			: spotPrice < discountedStrike

		let signedOne: T = optionType == .call ? T(1) : T(-1)
		let delta: T = inTheMoney ? signedOne : T.zero
		let gamma: T = atTheMoney ? T.infinity : T.zero
		let vega: T = T.zero

		let carry: T = riskFreeRate * discountedStrike
		let theta: T = inTheMoney ? -signedOne * carry : T.zero

		let rhoMagnitude: T = strikePrice * timeToExpiry * discountFactor
		let rho: T = inTheMoney ? signedOne * rhoMagnitude : T.zero

		return Greeks(delta: delta, gamma: gamma, vega: vega, theta: theta, rho: rho)
	}

	// MARK: - Helper Functions

	private static func calculateD1(
		spotPrice: T,
		strikePrice: T,
		timeToExpiry: T,
		riskFreeRate: T,
		volatility: T
	) -> T {
		let logMoneyness: T = T.log(spotPrice / strikePrice)
		let halfVariance: T = volatility * volatility / T(2)
		let drift: T = (riskFreeRate + halfVariance) * timeToExpiry
		let diffusion: T = volatility * T.sqrt(timeToExpiry)
		return (logMoneyness + drift) / diffusion
	}

	// The cumulative normal, the normal density and an Abramowitz & Stegun `erf`
	// used to live here as private statics. The A&S 7.1.26 approximation is
	// accurate to about 1.5e-7 in `erf`, so roughly 7e-8 in the CDF, and every
	// price and Greek this type produced went through it — 6.25e-04 of error on
	// an index-scale option. Pricing now calls the package's `normalCDF(x:)` and
	// `normalPDF(x:)`, which use swift-numerics' `T.erf` and are correct to the
	// last few ulp. See `BlackScholesNormalCDFAccuracyTests`.
}

// MARK: - Greeks

/// Option Greeks (sensitivities to various parameters).
public struct Greeks<T: Real & Sendable>: Sendable {
	/// Delta: Price sensitivity to underlying (∂V/∂S).
	public let delta: T

	/// Gamma: Delta sensitivity to underlying (∂²V/∂S²).
	public let gamma: T

	/// Vega: Price sensitivity to volatility (∂V/∂σ).
	public let vega: T

	/// Theta: Price sensitivity to time decay (∂V/∂t).
	public let theta: T

	/// Rho: Price sensitivity to interest rate (∂V/∂r).
	public let rho: T

	/// Creates a collection of option Greeks for risk management.
	///
	/// - Parameters:
	///   - delta: Price sensitivity to underlying asset (∂V/∂S). Range: [0,1] for calls, [-1,0] for puts.
	///   - gamma: Delta sensitivity to underlying (∂²V/∂S²). Measures delta hedging risk.
	///   - vega: Price sensitivity to volatility (∂V/∂σ). Higher for at-the-money options.
	///   - theta: Price sensitivity to time decay (∂V/∂t). Typically negative (options lose value over time).
	///   - rho: Price sensitivity to interest rate (∂V/∂r). More significant for longer-dated options.
	public init(delta: T, gamma: T, vega: T, theta: T, rho: T) {
		self.delta = delta
		self.gamma = gamma
		self.vega = vega
		self.theta = theta
		self.rho = rho
	}

	/// Human-readable description.
	public var description: String {
		"""
		Greeks:
		  Delta: \(delta)
		  Gamma: \(gamma)
		  Vega: \(vega)
		  Theta: \(theta)
		  Rho: \(rho)
		"""
	}
}

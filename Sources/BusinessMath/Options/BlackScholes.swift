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
		let gamma = normalPDF(x: d1) / (spotPrice * volatility * T.sqrt(timeToExpiry))

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

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
			return spotPrice * cumulativeNormal(d1) -
				   strikePrice * T.exp(-riskFreeRate * timeToExpiry) * cumulativeNormal(d2)

		case .put:
			return strikePrice * T.exp(-riskFreeRate * timeToExpiry) * cumulativeNormal(-d2) -
				   spotPrice * cumulativeNormal(-d1)
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
			delta = cumulativeNormal(d1)
		} else {
			delta = cumulativeNormal(d1) - T(1)
		}

		// Gamma: ∂²V/∂S²
		let gamma = normalPDF(d1) / (spotPrice * volatility * T.sqrt(timeToExpiry))

		// Vega: ∂V/∂σ
		let vega = spotPrice * normalPDF(d1) * T.sqrt(timeToExpiry)

		// Theta: ∂V/∂t
		let theta: T
		let term1 = -(spotPrice * normalPDF(d1) * volatility) / (T(2) * T.sqrt(timeToExpiry))
		if optionType == .call {
			let term2 = riskFreeRate * strikePrice * T.exp(-riskFreeRate * timeToExpiry) * cumulativeNormal(d2)
			theta = term1 - term2
		} else {
			let term2 = riskFreeRate * strikePrice * T.exp(-riskFreeRate * timeToExpiry) * cumulativeNormal(-d2)
			theta = term1 + term2
		}

		// Rho: ∂V/∂r
		let rho: T
		if optionType == .call {
			rho = strikePrice * timeToExpiry * T.exp(-riskFreeRate * timeToExpiry) * cumulativeNormal(d2)
		} else {
			rho = -strikePrice * timeToExpiry * T.exp(-riskFreeRate * timeToExpiry) * cumulativeNormal(-d2)
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
		return (T.log(spotPrice / strikePrice) +
				(riskFreeRate + volatility * volatility / T(2)) * timeToExpiry) /
			   (volatility * T.sqrt(timeToExpiry))
	}

	/// Cumulative normal distribution function.
	private static func cumulativeNormal(_ x: T) -> T {
		return (T(1) + erf(x / T.sqrt(T(2)))) / T(2)
	}

	/// Normal probability density function.
	private static func normalPDF(_ x: T) -> T {
		return T.exp(-x * x / T(2)) / T.sqrt(T(2) * T.pi)
	}

	/// Error function approximation (Abramowitz and Stegun).
	private static func erf(_ x: T) -> T {
		// Coefficients for error function approximation
		let a1 = T(254829592) / T(1000000000)   // 0.254829592
		let a2 = -T(284496736) / T(1000000000)  // -0.284496736
		let a3 = T(1421413741) / T(1000000000)  // 1.421413741
		let a4 = -T(1453152027) / T(1000000000) // -1.453152027
		let a5 = T(1061405429) / T(1000000000)  // 1.061405429
		let p = T(3275911) / T(10000000)        // 0.3275911

		let sign: T = x < T(0) ? -T(1) : T(1)
		let absX = abs(x)

		let t = T(1) / (T(1) + p * absX)
		
		// Break down the polynomial evaluation into steps
		let term1 = a5 * t + a4
		let term2 = term1 * t + a3
		let term3 = term2 * t + a2
		let term4 = term3 * t + a1
		let polynomial = term4 * t
		
		let expTerm = T.exp(-absX * absX)
		let y = T(1) - polynomial * expTerm

		return sign * y
	}
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

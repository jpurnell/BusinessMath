//
//  BinomialTree.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

// MARK: - BinomialTreeModel

/// Binomial tree option pricing model.
///
/// `BinomialTreeModel` uses a discrete-time lattice approach to price options.
/// It supports both European and American exercise styles. American options
/// can be exercised early, which the model accounts for by comparing continuation
/// value versus immediate exercise value at each node.
///
/// ## Usage
///
/// ```swift
/// // Price an American put option
/// let price = BinomialTreeModel<Double>.price(
///     optionType: .put,
///     americanStyle: true,
///     spotPrice: 100.0,
///     strikePrice: 105.0,
///     timeToExpiry: 0.25,
///     riskFreeRate: 0.05,
///     volatility: 0.20,
///     steps: 100
/// )
/// ```
public struct BinomialTreeModel<T: Real & Sendable> {

	/// Calculate option price using binomial tree.
	///
	/// - Parameters:
	///   - optionType: Call or put option.
	///   - americanStyle: If true, allows early exercise (American). If false, European.
	///   - spotPrice: Current price of underlying asset.
	///   - strikePrice: Strike price of option.
	///   - timeToExpiry: Time to expiration in years.
	///   - riskFreeRate: Risk-free interest rate (annual).
	///   - volatility: Volatility of underlying asset (annual).
	///   - steps: Number of time steps in the tree (more = more accurate).
	/// - Returns: Option price.
	public static func price(
		optionType: OptionType,
		americanStyle: Bool = false,
		spotPrice: T,
		strikePrice: T,
		timeToExpiry: T,
		riskFreeRate: T,
		volatility: T,
		steps: Int = 100
	) -> T {

		// A tree with no steps has no nodes to induct over, and `timeToExpiry / T(steps)`
		// divides by zero. The old code returned **0.0** for it — a call worth 10.43 reported
		// as worthless, with no NaN and no error, from a parameter that is public and has a
		// default. There is no limit to compute here: a zero-step tree is not a model.
		precondition(steps >= 1, "A binomial tree needs at least one step; got \(steps).")

		// `u - d` is zero exactly when `volatility * sqrt(dt)` is, and then the tree has no
		// branching left to price. Measured before this branch: both a zero-volatility option
		// and one valued on its expiry date returned NaN from the risk-neutral probability.
		let dt = timeToExpiry / T(steps)
		let diffusion: T = volatility * T.sqrt(dt)
		if diffusion <= T.zero {
			return zeroDiffusionPrice(
				optionType: optionType,
				americanStyle: americanStyle,
				spotPrice: spotPrice,
				strikePrice: strikePrice,
				timeToExpiry: timeToExpiry,
				riskFreeRate: riskFreeRate
			)
		}

		let u = T.exp(diffusion)  // Up factor
		let d = T(1) / u  // Down factor
		// Risk-neutral probability
		let growth: T = T.exp(riskFreeRate * dt)
		let p: T = (growth - d) / (u - d)

		// Build price tree (only need values, not full tree structure)
		var tree = Array(repeating: Array(repeating: T(0), count: steps + 1), count: steps + 1)

		// Initialize final nodes (terminal payoffs)
		for i in 0...steps {
			let upLegs: T = T.pow(u, T(steps - i))
			let downLegs: T = T.pow(d, T(i))
			let finalPrice: T = spotPrice * upLegs * downLegs
			tree[i][steps] = intrinsicValue(
				optionType: optionType,
				spotPrice: finalPrice,
				strikePrice: strikePrice
			)
		}

		// Backward induction
		for j in (0..<steps).reversed() {
			for i in 0...j {
				let upLegs: T = T.pow(u, T(j - i))
				let downLegs: T = T.pow(d, T(i))
				let nodePrice: T = spotPrice * upLegs * downLegs

				// Expected value (continuation value)
				let upValue: T = p * tree[i][j + 1]
				let downValue: T = (T(1) - p) * tree[i + 1][j + 1]
				let discountFactor: T = T.exp(-riskFreeRate * dt)
				let expectedValue: T = (upValue + downValue) * discountFactor

				if americanStyle {
					// American option: max of holding vs exercising
					let exerciseValue = intrinsicValue(
						optionType: optionType,
						spotPrice: nodePrice,
						strikePrice: strikePrice
					)
					tree[i][j] = max(expectedValue, exerciseValue)
				} else {
					// European option: can only hold
					tree[i][j] = expectedValue
				}
			}
		}

		return tree[0][0]
	}

	// MARK: - The zero-diffusion limit

	/// What the tree is worth when there is no branching left to price.
	///
	/// With zero diffusion the underlying follows one deterministic path, `S * exp(rt)`, so the
	/// European value is the discounted payoff on the forward — the same number
	/// ``BlackScholesModel/zeroDiffusionPrice(optionType:spotPrice:strikePrice:timeToExpiry:riskFreeRate:)``
	/// gives, since the tree converges to that model.
	///
	/// **American exercise is not the same number**, and this is the one place the two models
	/// part company. Exercising a put at time `t` is worth `exp(-rt) * (K - S * exp(rt))`,
	/// which is `K * exp(-rt) - S` — largest at `t = 0`. So an American put on a
	/// non-volatile asset is worth exercising immediately, `max(K - S, 0)`, and that beats the
	/// European value whenever the rate is positive. A call without dividends is never worth
	/// exercising early, so the two agree there; taking the maximum covers both, and covers a
	/// negative rate, where the European side is the larger one.
	internal static func zeroDiffusionPrice(
		optionType: OptionType,
		americanStyle: Bool,
		spotPrice: T,
		strikePrice: T,
		timeToExpiry: T,
		riskFreeRate: T
	) -> T {
		let european: T = BlackScholesModel<T>.zeroDiffusionPrice(
			optionType: optionType,
			spotPrice: spotPrice,
			strikePrice: strikePrice,
			timeToExpiry: timeToExpiry,
			riskFreeRate: riskFreeRate
		)
		guard americanStyle else { return european }
		let exerciseNow: T = intrinsicValue(
			optionType: optionType,
			spotPrice: spotPrice,
			strikePrice: strikePrice
		)
		return T.maximum(european, exerciseNow)
	}

	// MARK: - Helper Functions

	/// Calculate intrinsic value (payoff at exercise).
	private static func intrinsicValue(
		optionType: OptionType,
		spotPrice: T,
		strikePrice: T
	) -> T {
		switch optionType {
		case .call:
			return max(T(0), spotPrice - strikePrice)
		case .put:
			return max(T(0), strikePrice - spotPrice)
		}
	}
}

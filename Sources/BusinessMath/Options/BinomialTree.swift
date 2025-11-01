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

		let dt = timeToExpiry / T(steps)
		let u = T.exp(volatility * T.sqrt(dt))  // Up factor
		let d = T(1) / u  // Down factor
		let p = (T.exp(riskFreeRate * dt) - d) / (u - d)  // Risk-neutral probability

		// Build price tree (only need values, not full tree structure)
		var tree = Array(repeating: Array(repeating: T(0), count: steps + 1), count: steps + 1)

		// Initialize final nodes (terminal payoffs)
		for i in 0...steps {
			let finalPrice = spotPrice * T.pow(u, T(steps - i)) * T.pow(d, T(i))
			tree[i][steps] = intrinsicValue(
				optionType: optionType,
				spotPrice: finalPrice,
				strikePrice: strikePrice
			)
		}

		// Backward induction
		for j in (0..<steps).reversed() {
			for i in 0...j {
				let nodePrice = spotPrice * T.pow(u, T(j - i)) * T.pow(d, T(i))

				// Expected value (continuation value)
				let expectedValue = (p * tree[i][j + 1] + (T(1) - p) * tree[i + 1][j + 1]) *
									T.exp(-riskFreeRate * dt)

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

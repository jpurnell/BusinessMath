//
//  PriceElasticity.swift
//  BusinessMath
//

import Foundation
import Numerics

/// The percentage change in quantity for a percentage change in price.
///
/// ```swift
/// let prices: [Double] = [10, 12, 14, 16, 18, 20]
/// let sold: [Double] = [100, 82, 70, 60, 53, 47]
/// if let estimate = PriceElasticity(prices: prices, quantities: sold) {
///     print(estimate.elasticity)   // −1.087
///     print(estimate.isElastic)    // true
/// }
/// ```
///
/// ## Why the fit is in logs
///
/// Elasticity is `d(ln Q)/d(ln P)`, so regressing log quantity on log price estimates it
/// directly as the slope — no differentiation, no reference point, and a single number
/// for the whole range. Fitting levels instead gives a slope in units of quantity per
/// unit of price, which changes when the currency does; the log-log slope does not, and
/// `elasticityIsScaleInvariant` pins that.
///
/// ## The assumption underneath
///
/// A constant elasticity over the observed range, which is what makes one number the
/// answer. Real demand curves bend, so this is a local approximation reported as a
/// global one, and extrapolating it far outside the prices in the data is the way it
/// misleads. `rSquared` is supplied so a caller can see how well the constant-elasticity
/// shape actually fitted before relying on it.
///
/// Nothing here establishes that price *caused* the quantity change. Prices move for
/// reasons — promotions, seasons, competitors — and those reasons often move demand too.
public struct PriceElasticity<T: Real & Sendable & BinaryFloatingPoint>: Sendable {

	/// The elasticity: the slope of log quantity on log price. Negative for a normal good.
	public let elasticity: T

	/// The fitted intercept, in logs.
	public let intercept: T

	/// How much of the variation in log quantity the fit explains.
	public let rSquared: T

	/// How many observations.
	public let observations: Int

	/// Whether `|ε| > 1` — demand responds more than proportionally, so a price rise
	/// lowers revenue.
	public var isElastic: Bool {
		let size: T = elasticity < T.zero ? -elasticity : elasticity
		return size > T(1)
	}

	/// Estimates elasticity from observed prices and quantities.
	///
	/// - Parameters:
	///   - prices: Strictly positive, and not all the same.
	///   - quantities: Strictly positive, same length.
	/// - Returns: `nil` for fewer than two observations, a non-positive value anywhere —
	///   which has no logarithm — or prices that never vary, which carry no information
	///   about how demand responds to price.
	public init?(prices: [T], quantities: [T]) {
		guard prices.count >= 2, prices.count == quantities.count else { return nil }
		guard prices.allSatisfy({ $0 > T.zero && $0.isFinite }) else { return nil }
		guard quantities.allSatisfy({ $0 > T.zero && $0.isFinite }) else { return nil }

		let logPrice = prices.map { T.log($0) }
		let logQuantity = quantities.map { T.log($0) }
		let count = T(prices.count)
		let meanPrice = logPrice.reduce(T.zero, +) / count
		let meanQuantity = logQuantity.reduce(T.zero, +) / count

		var covariance: T = T.zero
		var variance: T = T.zero
		for (x, y) in zip(logPrice, logQuantity) {
			let dx: T = x - meanPrice
			let dy: T = y - meanQuantity
			covariance += dx * dy
			variance += dx * dx
		}
		guard variance > T.zero else { return nil }
		let slope: T = covariance / variance
		let constant: T = meanQuantity - slope * meanPrice

		var residual: T = T.zero
		var total: T = T.zero
		for (x, y) in zip(logPrice, logQuantity) {
			let fitted: T = constant + slope * x
			let error: T = y - fitted
			residual += error * error
			let spread: T = y - meanQuantity
			total += spread * spread
		}
		let explained: T = total > T.zero ? 1 - residual / total : T(1)

		self.elasticity = slope
		self.intercept = constant
		self.rSquared = explained
		self.observations = prices.count
	}
}

/// The profit-maximising price under constant-elasticity demand.
///
/// `P* = cε/(ε + 1)`, equivalently `c/(1 + 1/ε)` — the Lerner markup. The more elastic
/// demand is, the thinner the margin that survives: at `ε = −2` the price is twice
/// marginal cost, at `ε = −5` a quarter above it.
///
/// ## Why inelastic demand is refused
///
/// The formula comes from setting `dΠ/dP = 0`, which finds an interior maximum only when
/// one exists. For `−1 < ε < 0` profit rises without bound as price rises — every price
/// increase loses less than proportional volume — so there is no optimum to find, and the
/// closed form returns a **negative price**: at `ε = −0.5` and a cost of 10 it says −10.
/// At `ε = −1` exactly it divides by zero.
///
/// A negative price is not obviously an error to code that receives it. Refusing is the
/// only way the caller learns that the question had no answer, and that the real finding
/// is *"your demand is inelastic — raise the price and see where that stops being true."*
///
/// - Parameters:
///   - marginalCost: The cost of one more unit, strictly positive.
///   - elasticity: Own-price elasticity, strictly below −1.
/// - Returns: The profit-maximising price, or `nil` when no interior optimum exists.
public func optimalPrice<T: Real & Sendable & BinaryFloatingPoint>(
	marginalCost: T,
	elasticity: T
) -> T? {
	guard marginalCost > T.zero, marginalCost.isFinite else { return nil }
	guard elasticity.isFinite, elasticity < T(-1) else { return nil }
	let denominator: T = elasticity + 1
	guard denominator < T.zero else { return nil }
	let numerator: T = marginalCost * elasticity
	return numerator / denominator
}

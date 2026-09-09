//
//  PriceResponse.swift
//  BusinessMath
//

import Foundation
import Numerics

/// The functional form a demand curve is fitted in.
public enum DemandForm: Sendable, Equatable, CaseIterable {

	/// `Q = a + bP`. Elasticity varies along the curve, from zero at `P = 0` to
	/// unbounded at the choke price.
	case linear

	/// `ln Q = a + b ln P`, so `Q = e^a · P^b`. Elasticity is `b` everywhere — the only
	/// form for which "the elasticity" is a property of the curve rather than of a point
	/// on it.
	case logLog

	/// `ln Q = a + bP`, so `Q = e^(a + bP)`. Constant *semi*-elasticity: each extra
	/// currency unit of price costs a fixed percentage of volume.
	case semiLog
}

/// A fitted demand curve, and the decisions that follow from it.
///
/// ```swift
/// let prices: [Double] = [10, 12, 14, 16, 18, 20]
/// let quantities: [Double] = [150, 140, 130, 120, 110, 100]
/// if let curve = PriceResponseCurve(prices: prices, quantities: quantities, form: .linear),
///    let best = curve.optimalPrice(marginalCost: 10) {
///     print(curve.slope, best)
/// }
/// ```
///
/// ## Elasticity is a property of a point, not of a curve
///
/// ``PriceElasticity`` fits the log-log form, where the slope *is* the elasticity and
/// quoting one number is legitimate. No other form works that way. On a linear demand
/// curve elasticity is `bP/Q`: near zero where the curve meets the quantity axis, and
/// unbounded as it approaches the choke price. A single "elasticity of −1.4" quoted from
/// a linear fit is a reading at some price nobody wrote down, and it will be wrong at
/// every other price. ``elasticity(at:)`` therefore takes the price.
///
/// ## R² does not choose the form
///
/// ``rSquared`` is computed in the space the fit was performed in — quantity for
/// ``DemandForm/linear``, log-quantity for the other two. Those are different dependent
/// variables, so the numbers are not comparable, and the wrong form routinely scores
/// above 0.99. Comparing them is how a log-log fit wins on data that came from a
/// straight line.
///
/// ``best(prices:quantities:among:)`` selects on
/// ``residualSumOfSquares(prices:quantities:)`` instead, which is measured in units of
/// quantity for every form and therefore says the same thing about each.
public struct PriceResponseCurve<T: Real & Sendable & BinaryFloatingPoint>: Sendable {

	/// The functional form fitted.
	public let form: DemandForm

	/// The fitted constant, in the space the form is linear in.
	public let intercept: T

	/// The fitted slope, in the space the form is linear in. Negative for a demand curve.
	public let slope: T

	/// Explained variance **in the fitted space**. Not comparable across forms.
	public let rSquared: T

	/// How many observations the fit used.
	public let observations: Int

	/// Whether the curve slopes down, as demand normally does.
	public var isDownwardSloping: Bool { slope < T.zero }

	/// Fits a demand curve.
	///
	/// - Parameters:
	///   - prices: Finite, non-negative, and not all the same. Strictly positive for
	///     ``DemandForm/logLog``, which takes their logarithm.
	///   - quantities: Same length. Strictly positive for the two log forms.
	///   - form: The functional form.
	/// - Returns: `nil` for fewer than three observations, mismatched lengths, a value
	///   the form cannot take the logarithm of, or prices that never vary — which carry
	///   no information about how demand responds to price.
	public init?(prices: [T], quantities: [T], form: DemandForm) {
		guard prices.count >= 3, prices.count == quantities.count else { return nil }
		guard prices.allSatisfy({ $0.isFinite && $0 >= T.zero }) else { return nil }
		guard quantities.allSatisfy({ $0.isFinite }) else { return nil }

		let xs: [T]
		let ys: [T]
		switch form {
		case .linear:
			xs = prices
			ys = quantities
		case .logLog:
			guard prices.allSatisfy({ $0 > T.zero }) else { return nil }
			guard quantities.allSatisfy({ $0 > T.zero }) else { return nil }
			xs = prices.map { T.log($0) }
			ys = quantities.map { T.log($0) }
		case .semiLog:
			guard quantities.allSatisfy({ $0 > T.zero }) else { return nil }
			xs = prices
			ys = quantities.map { T.log($0) }
		}

		guard let fit = Self.regress(xs, ys) else { return nil }
		self.form = form
		self.intercept = fit.intercept
		self.slope = fit.slope
		self.rSquared = fit.rSquared
		self.observations = prices.count
	}

	/// Ordinary least squares of `ys` on `xs`.
	///
	/// - Returns: `nil` when `xs` has no variance, which is the one case with no line.
	static func regress(_ xs: [T], _ ys: [T]) -> (slope: T, intercept: T, rSquared: T)? {
		let count = T(xs.count)
		let meanX: T = xs.reduce(T.zero, +) / count
		let meanY: T = ys.reduce(T.zero, +) / count

		var covariance: T = T.zero
		var variance: T = T.zero
		for (x, y) in zip(xs, ys) {
			let dx: T = x - meanX
			let dy: T = y - meanY
			covariance += dx * dy
			variance += dx * dx
		}
		guard variance > T.zero else { return nil }
		let slope: T = covariance / variance
		let shift: T = slope * meanX
		let constant: T = meanY - shift

		var residual: T = T.zero
		var total: T = T.zero
		for (x, y) in zip(xs, ys) {
			let scaled: T = slope * x
			let fitted: T = constant + scaled
			let error: T = y - fitted
			residual += error * error
			let spread: T = y - meanY
			total += spread * spread
		}
		let explained: T = total > T.zero ? 1 - residual / total : T(1)
		return (slope, constant, explained)
	}

	/// Quantity demanded at a price.
	///
	/// - Parameter price: Non-negative, and strictly positive for ``DemandForm/logLog``.
	/// - Returns: The quantity, or `nil` where the form has none. A linear curve
	///   extrapolated past its choke price returns a **negative** quantity, which
	///   multiplies into a negative revenue and a profit figure that looks like an
	///   ordinary loss rather than like a question with no answer.
	public func quantity(at price: T) -> T? {
		guard price.isFinite, price >= T.zero else { return nil }
		switch form {
		case .linear:
			let scaled: T = slope * price
			let quantity: T = intercept + scaled
			return quantity >= T.zero ? quantity : nil
		case .logLog:
			guard price > T.zero else { return nil }
			let logPrice: T = T.log(price)
			let scaled: T = slope * logPrice
			let logQuantity: T = intercept + scaled
			return T.exp(logQuantity)
		case .semiLog:
			let scaled: T = slope * price
			let logQuantity: T = intercept + scaled
			return T.exp(logQuantity)
		}
	}

	/// Own-price elasticity **at a price**.
	///
	/// - Parameter price: Where on the curve to read it.
	/// - Returns: The elasticity, or `nil` where the curve has no quantity there. Only
	///   ``DemandForm/logLog`` returns the same value at every price.
	public func elasticity(at price: T) -> T? {
		switch form {
		case .linear:
			guard let quantity = quantity(at: price), quantity > T.zero else { return nil }
			let scaled: T = slope * price
			return scaled / quantity
		case .logLog:
			guard price > T.zero, price.isFinite else { return nil }
			return slope
		case .semiLog:
			guard price.isFinite, price >= T.zero else { return nil }
			return slope * price
		}
	}

	/// Revenue at a price.
	///
	/// - Parameter price: Where to evaluate.
	/// - Returns: `P · Q(P)`, or `nil` where the curve has no quantity there.
	public func revenue(at price: T) -> T? {
		guard let quantity = quantity(at: price) else { return nil }
		return price * quantity
	}

	/// Profit at a price.
	///
	/// - Parameters:
	///   - price: Where to evaluate.
	///   - marginalCost: The cost of one more unit.
	/// - Returns: `(P − c) · Q(P)`, or `nil` where the curve has no quantity there.
	public func profit(at price: T, marginalCost: T) -> T? {
		guard marginalCost.isFinite, marginalCost >= T.zero else { return nil }
		guard let quantity = quantity(at: price) else { return nil }
		let margin: T = price - marginalCost
		return margin * quantity
	}

	/// The profit-maximising price on this curve.
	///
	/// Each form has its own closed form, and all three satisfy the same first-order
	/// condition — the Lerner rule `(P* − c)/P* = −1/ε(P*)`, which is the identity the
	/// tests check them against.
	///
	/// | Form | Optimum |
	/// |---|---|
	/// | ``DemandForm/linear`` | `(bc − a) / 2b` |
	/// | ``DemandForm/logLog`` | `cb / (b + 1)` — the Lerner markup |
	/// | ``DemandForm/semiLog`` | `c − 1/b` |
	///
	/// - Parameter marginalCost: The cost of one more unit. Non-negative, and strictly
	///   positive for ``DemandForm/logLog``: constant-elasticity demand with no marginal
	///   cost has no interior optimum, while the other two forms do.
	/// - Returns: The price, or `nil` when the curve has no interior maximum — an upward
	///   slope, inelastic constant-elasticity demand, or a linear optimum that would sell
	///   nothing.
	public func optimalPrice(marginalCost: T) -> T? {
		guard marginalCost.isFinite, marginalCost >= T.zero else { return nil }
		switch form {
		case .linear:
			guard slope < T.zero else { return nil }
			let shifted: T = slope * marginalCost
			let numerator: T = shifted - intercept
			let denominator: T = slope * 2
			let price: T = numerator / denominator
			guard let sold = quantity(at: price), sold > T.zero else { return nil }
			return price
		case .logLog:
			return BusinessMath.optimalPrice(marginalCost: marginalCost, elasticity: slope)
		case .semiLog:
			guard slope < T.zero else { return nil }
			let step: T = 1 / slope
			return marginalCost - step
		}
	}

	/// Squared error between the curve and the data, **in units of quantity**.
	///
	/// This is what makes forms comparable. ``rSquared`` is measured in whatever space
	/// the form is linear in, so a log-log fit and a linear fit are scoring different
	/// dependent variables and their R² values say nothing about each other.
	///
	/// - Parameters:
	///   - prices: The prices observed.
	///   - quantities: The quantities observed, same length.
	/// - Returns: The sum of squared residuals, or `nil` on mismatched lengths or a price
	///   at which the curve has no quantity.
	public func residualSumOfSquares(prices: [T], quantities: [T]) -> T? {
		guard !prices.isEmpty, prices.count == quantities.count else { return nil }
		var total: T = T.zero
		for (price, observed) in zip(prices, quantities) {
			guard let fitted = quantity(at: price) else { return nil }
			let error: T = observed - fitted
			total += error * error
		}
		return total
	}

	/// The form that fits this data best, compared in units of quantity.
	///
	/// - Parameters:
	///   - prices: The prices observed.
	///   - quantities: The quantities observed, same length.
	///   - forms: Which forms to try. Defaults to all of them.
	/// - Returns: The best-fitting curve, or `nil` if no form could be fitted at all. Ties
	///   go to the earlier form in `forms`, so the choice is deterministic.
	public static func best(prices: [T],
							quantities: [T],
							among forms: [DemandForm] = DemandForm.allCases) -> PriceResponseCurve<T>? {
		var winner: PriceResponseCurve<T>?
		var lowest: T = T.infinity
		for form in forms {
			guard let candidate = PriceResponseCurve(prices: prices, quantities: quantities,
													 form: form) else { continue }
			guard let error = candidate.residualSumOfSquares(prices: prices,
															 quantities: quantities) else { continue }
			if error < lowest {
				lowest = error
				winner = candidate
			}
		}
		return winner
	}
}

//
//  EOQModel.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-05-09.
//

import Foundation
import Numerics

/// Economic Order Quantity (EOQ) model for determining optimal inventory order sizes.
///
/// The EOQ model minimizes total inventory cost by balancing ordering costs against
/// holding costs. At the optimal order quantity Q*, annual ordering cost equals
/// annual holding cost.
///
/// - Note: All calculations use the classical Harris-Wilson EOQ formula: Q* = √(2SD/H).
public struct EOQModel<T: Real & Sendable & Codable>: Sendable {

	/// The result of an EOQ calculation, containing the optimal order quantity
	/// and associated cost metrics.
	public struct Result: Sendable {
		/// The optimal order quantity (Q*) that minimizes total annual inventory cost.
		public let orderQuantity: T
		/// The annual cost of placing orders at the optimal quantity (S × D / Q*).
		public let annualOrderingCost: T
		/// The annual cost of holding inventory at the optimal quantity (H × Q* / 2).
		public let annualHoldingCost: T
		/// The total annual inventory cost (ordering + holding).
		public let totalAnnualCost: T
		/// The number of orders placed per year (D / Q*).
		public let ordersPerYear: T
		/// The average number of calendar days between successive orders (365 / ordersPerYear).
		public let daysBetweenOrders: T
	}

	/// Calculates the Economic Order Quantity and associated cost metrics.
	///
	/// Uses the classical EOQ formula Q* = √(2SD/H) to find the order quantity
	/// that minimizes total annual inventory cost.
	///
	/// - Parameters:
	///   - annualDemand: Total units demanded per year (D). Must be positive.
	///   - orderingCost: Fixed cost per order placed (S). Must be positive.
	///   - holdingCostPerUnit: Annual holding cost per unit in inventory (H). Must be positive.
	/// - Returns: An ``EOQModel/Result`` containing the optimal order quantity and cost breakdown.
	/// - Throws: ``OperationsError/zeroDemand`` if annual demand is zero or negative.
	/// - Throws: ``OperationsError/negativeCost`` if ordering cost or holding cost is zero or negative.
	public static func calculate(
		annualDemand: T,
		orderingCost: T,
		holdingCostPerUnit: T
	) throws -> Result {
		guard annualDemand > T(0) else {
			throw OperationsError.zeroDemand
		}
		guard orderingCost > T(0) else {
			throw OperationsError.negativeCost
		}
		guard holdingCostPerUnit > T(0) else {
			throw OperationsError.negativeCost
		}

		// Q* = √(2SD/H), factored so that `2SD` is never formed at full magnitude.
		//
		// The direct reading builds `2 · S · D` first. For a large order cost against a
		// large demand that product overflows while the answer does not: at
		// `S = D = 1e200` it is `2e400`, which is `+infinity` in a `Double`, and the square
		// root of infinity is infinity. The caller receives a non-finite order quantity
		// with no error — a plausible-looking result that is not a number, which is the
		// shape this package's fail-silent principle forbids.
		//
		// `√(2SD/H) = √(2S/H) · √D` is the same value for positive S, D and H, and each
		// factor stays near the square root of the magnitude the product would have
		// reached. Measured: the overflowing case now returns `√2 · 1e200`, and the
		// textbook fixtures are unchanged to the last bit.
		let scaledOrderingCost: T = T(2) * orderingCost / holdingCostPerUnit
		let q: T = T.sqrt(scaledOrderingCost) * T.sqrt(annualDemand)

		// Cost decomposition
		let annualOrderingCost = orderingCost * annualDemand / q
		let annualHoldingCost = holdingCostPerUnit * q / T(2)
		let totalAnnualCost = annualOrderingCost + annualHoldingCost

		// Derived fields
		let ordersPerYear = annualDemand / q
		// Convention: 365 calendar days. This is an operating cadence — how long a
		// replenishment cycle lasts — not an accrual, so no day-count standard applies and
		// the extra quarter-day of a mean year would be false precision against a demand
		// figure that is itself an estimate.
		let daysBetweenOrders = T(365) / ordersPerYear

		return Result(
			orderQuantity: q,
			annualOrderingCost: annualOrderingCost,
			annualHoldingCost: annualHoldingCost,
			totalAnnualCost: totalAnnualCost,
			ordersPerYear: ordersPerYear,
			daysBetweenOrders: daysBetweenOrders
		)
	}

	/// Computes the total annual inventory cost for a given order quantity.
	///
	/// TC = S × D / Q + H × Q / 2 + c × D
	///
	/// - Parameters:
	///   - orderQuantity: The order quantity (Q) to evaluate.
	///   - annualDemand: Total units demanded per year (D).
	///   - orderingCost: Fixed cost per order placed (S).
	///   - holdingCostPerUnit: Annual holding cost per unit in inventory (H).
	///   - unitCost: Purchase cost per unit (c). Defaults to zero.
	/// - Returns: The total annual inventory cost at the specified order quantity.
	public static func totalCost(
		orderQuantity: T,
		annualDemand: T,
		orderingCost: T,
		holdingCostPerUnit: T,
		unitCost: T = T(0)
	) -> T {
		guard orderQuantity != T(0) else { return T(0) }
		let ordering = orderingCost * annualDemand / orderQuantity
		let holding = holdingCostPerUnit * orderQuantity / T(2)
		let purchasing = unitCost * annualDemand
		return ordering + holding + purchasing
	}
}

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

		// Q* = √(2SD/H)
		let numerator = T(2) * orderingCost * annualDemand
		let q = T.sqrt(numerator / holdingCostPerUnit)

		// Cost decomposition
		let annualOrderingCost = orderingCost * annualDemand / q
		let annualHoldingCost = holdingCostPerUnit * q / T(2)
		let totalAnnualCost = annualOrderingCost + annualHoldingCost

		// Derived fields
		let ordersPerYear = annualDemand / q
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

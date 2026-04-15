//
//  CommodityCollar.swift
//  BusinessMath
//
//  Created by Justin Purnell on 4/15/26.
//

import Foundation
import Numerics

// MARK: - CommodityCollar

/// A costless collar combining a long put (floor) and short call (ceiling) on a commodity.
///
/// An E&P producer uses a collar to establish a price range:
/// - The **long put** at `putStrike` provides downside protection.
/// - The **short call** at `callStrike` caps upside in exchange for the put premium.
///
/// Per-unit payoff:
/// - Spot < putStrike: `putStrike - spotPrice` (positive, protection)
/// - putStrike <= Spot <= callStrike: `0` (no hedge cash flow)
/// - Spot > callStrike: `-(spotPrice - callStrike)` (negative, upside given away)
///
/// ## Example
///
/// ```swift
/// let collar = CommodityCollar<Double>(
///     underlier: "WTI",
///     putStrike: 60.0,
///     callStrike: 80.0,
///     quantity: 10_000.0,
///     settlementPeriods: [Period.month(year: 2026, month: 1)]
/// )
///
/// collar.payoff(spotPrice: 50.0)   // 10.0  (protected)
/// collar.payoff(spotPrice: 70.0)   //  0.0  (no cash flow)
/// collar.payoff(spotPrice: 90.0)   // -10.0 (gave away upside)
/// ```
public struct CommodityCollar<T: Real & Sendable>: Sendable where T: Codable {

	/// The underlying commodity (e.g., "WTI", "Henry Hub").
	public let underlier: String

	/// The put strike (floor). The producer is protected below this price.
	public let putStrike: T

	/// The call strike (ceiling). The producer gives away upside above this price.
	public let callStrike: T

	/// The notional quantity per settlement period.
	public let quantity: T

	/// The periods over which the collar settles.
	public let settlementPeriods: [Period]

	/// Creates a new commodity collar.
	///
	/// - Parameters:
	///   - underlier: The underlying commodity identifier.
	///   - putStrike: The floor strike price (long put).
	///   - callStrike: The ceiling strike price (short call).
	///   - quantity: The notional quantity per settlement period.
	///   - settlementPeriods: The periods over which the collar settles.
	public init(
		underlier: String,
		putStrike: T,
		callStrike: T,
		quantity: T,
		settlementPeriods: [Period]
	) {
		self.underlier = underlier
		self.putStrike = putStrike
		self.callStrike = callStrike
		self.quantity = quantity
		self.settlementPeriods = settlementPeriods
	}

	/// Calculates the per-unit payoff at a given spot price.
	///
	/// - Parameter spotPrice: The observed spot price.
	/// - Returns: The per-unit payoff. Positive means the hedge pays the producer.
	public func payoff(spotPrice: T) -> T {
		if spotPrice < putStrike {
			// Long put is in the money
			return putStrike - spotPrice
		} else if spotPrice > callStrike {
			// Short call is in the money (producer pays)
			return -(spotPrice - callStrike)
		} else {
			return T.zero
		}
	}

	/// Calculates the total settlement amount at a given spot price.
	///
	/// Settlement = `payoff(spotPrice:) * quantity`
	///
	/// - Parameter spotPrice: The observed spot price.
	/// - Returns: The total settlement amount for the period.
	public func settlement(spotPrice: T) -> T {
		return payoff(spotPrice: spotPrice) * quantity
	}
}

// MARK: - Codable

extension CommodityCollar: Codable {}

// MARK: - Equatable

extension CommodityCollar: Equatable where T: Equatable {}

// MARK: - ThreeWayCollar

/// A three-way collar: collar with a sold deep out-of-the-money put to reduce premium.
///
/// The producer sells a deep OTM put at `shortPutStrike`, giving away tail-risk protection
/// in exchange for a lower net premium. The structure has four payoff zones:
///
/// 1. **Spot < shortPutStrike**: Long put pays `(longPutStrike - spot)`, short put costs
///    `(shortPutStrike - spot)`. Net = `longPutStrike - shortPutStrike` (capped protection).
/// 2. **shortPutStrike <= Spot < longPutStrike**: Long put pays `(longPutStrike - spot)`,
///    short put expired. Net = `longPutStrike - spot`.
/// 3. **longPutStrike <= Spot <= shortCallStrike**: Nothing in the money. Net = 0.
/// 4. **Spot > shortCallStrike**: Short call costs `-(spot - shortCallStrike)`.
///
/// ## Example
///
/// ```swift
/// let collar = ThreeWayCollar<Double>(
///     underlier: "WTI",
///     shortPutStrike: 40.0,   // sold put (tail risk)
///     longPutStrike: 60.0,    // protection floor
///     shortCallStrike: 80.0,  // upside cap
///     quantity: 10_000.0,
///     settlementPeriods: [Period.month(year: 2026, month: 1)]
/// )
///
/// collar.payoff(spotPrice: 30.0)  //  20.0 (capped at longPut - shortPut)
/// collar.payoff(spotPrice: 50.0)  //  10.0 (partial protection)
/// collar.payoff(spotPrice: 70.0)  //   0.0
/// collar.payoff(spotPrice: 90.0)  // -10.0 (upside given away)
/// ```
public struct ThreeWayCollar<T: Real & Sendable>: Sendable where T: Codable {

	/// The deep OTM sold put strike. Below this, tail-risk protection is given away.
	public let shortPutStrike: T

	/// The long put strike. The producer is protected between this and the short put.
	public let longPutStrike: T

	/// The short call strike. The producer gives away upside above this price.
	public let shortCallStrike: T

	/// The underlying commodity (e.g., "WTI", "Henry Hub").
	public let underlier: String

	/// The notional quantity per settlement period.
	public let quantity: T

	/// The periods over which the collar settles.
	public let settlementPeriods: [Period]

	/// Creates a new three-way collar.
	///
	/// - Parameters:
	///   - underlier: The underlying commodity identifier.
	///   - shortPutStrike: The deep OTM sold put strike (tail risk given away below this).
	///   - longPutStrike: The protection floor (long put strike).
	///   - shortCallStrike: The upside cap (short call strike).
	///   - quantity: The notional quantity per settlement period.
	///   - settlementPeriods: The periods over which the collar settles.
	public init(
		underlier: String,
		shortPutStrike: T,
		longPutStrike: T,
		shortCallStrike: T,
		quantity: T,
		settlementPeriods: [Period]
	) {
		self.underlier = underlier
		self.shortPutStrike = shortPutStrike
		self.longPutStrike = longPutStrike
		self.shortCallStrike = shortCallStrike
		self.quantity = quantity
		self.settlementPeriods = settlementPeriods
	}

	/// Calculates the per-unit payoff at a given spot price across all four zones.
	///
	/// - Parameter spotPrice: The observed spot price.
	/// - Returns: The per-unit payoff. Positive means the hedge pays the producer.
	public func payoff(spotPrice: T) -> T {
		if spotPrice < shortPutStrike {
			// Zone 1: Below short put — both puts in the money
			// Long put pays: (longPutStrike - spotPrice)
			// Short put costs: (shortPutStrike - spotPrice)
			// Net: longPutStrike - shortPutStrike
			let longPutPayoff = longPutStrike - spotPrice
			let shortPutCost = shortPutStrike - spotPrice
			return longPutPayoff - shortPutCost
		} else if spotPrice < longPutStrike {
			// Zone 2: Between short put and long put — only long put in the money
			return longPutStrike - spotPrice
		} else if spotPrice <= shortCallStrike {
			// Zone 3: Between long put and short call — nothing in the money
			return T.zero
		} else {
			// Zone 4: Above short call — short call in the money
			return -(spotPrice - shortCallStrike)
		}
	}

	/// Calculates the total settlement amount at a given spot price.
	///
	/// Settlement = `payoff(spotPrice:) * quantity`
	///
	/// - Parameter spotPrice: The observed spot price.
	/// - Returns: The total settlement amount for the period.
	public func settlement(spotPrice: T) -> T {
		return payoff(spotPrice: spotPrice) * quantity
	}
}

// MARK: - Codable

extension ThreeWayCollar: Codable {}

// MARK: - Equatable

extension ThreeWayCollar: Equatable where T: Equatable {}

//
//  CommoditySwap.swift
//  BusinessMath
//
//  Created by Justin Purnell on 4/15/26.
//

import Foundation
import Numerics

// MARK: - CommoditySwap

/// A fixed-for-floating commodity swap used by producers to lock in a selling price.
///
/// In a commodity swap, the producer agrees to receive a fixed price in exchange for
/// paying the floating (spot) price on a notional volume each period. The settlement
/// amount per period is `(fixedPrice - spotPrice) * notionalVolume`.
///
/// - A **positive** settlement means the producer gains (spot fell below the fixed price).
/// - A **negative** settlement means the producer pays (spot rose above the fixed price).
///
/// ## Example
///
/// ```swift
/// let swap = CommoditySwap<Double>(
///     underlier: "WTI",
///     fixedPrice: 72.0,
///     notionalVolume: 10_000.0,
///     settlementPeriods: [
///         Period.month(year: 2026, month: 1),
///         Period.month(year: 2026, month: 2)
///     ]
/// )
///
/// // If spot drops to $68, producer gains
/// let gain = swap.settlement(spotPrice: 68.0)  // 4.0 * 10_000 = 40_000
///
/// // If spot rises to $75, producer pays
/// let loss = swap.settlement(spotPrice: 75.0)  // -3.0 * 10_000 = -30_000
/// ```
public struct CommoditySwap<T: Real & Sendable>: Sendable where T: Codable {

	/// The underlying commodity (e.g., "WTI", "Henry Hub", "Brent").
	public let underlier: String

	/// The fixed price the producer receives per unit.
	public let fixedPrice: T

	/// The notional volume per settlement period.
	public let notionalVolume: T

	/// The periods over which the swap settles.
	public let settlementPeriods: [Period]

	/// Creates a new commodity swap.
	///
	/// - Parameters:
	///   - underlier: The underlying commodity identifier.
	///   - fixedPrice: The fixed price the producer receives per unit.
	///   - notionalVolume: The notional volume per settlement period.
	///   - settlementPeriods: The periods over which the swap settles.
	public init(
		underlier: String,
		fixedPrice: T,
		notionalVolume: T,
		settlementPeriods: [Period]
	) {
		self.underlier = underlier
		self.fixedPrice = fixedPrice
		self.notionalVolume = notionalVolume
		self.settlementPeriods = settlementPeriods
	}

	/// Calculates the settlement amount for a single spot price observation.
	///
	/// Settlement = `(fixedPrice - spotPrice) * notionalVolume`
	///
	/// - Parameter spotPrice: The observed spot price for the period.
	/// - Returns: The settlement amount. Positive means the producer gains.
	public func settlement(spotPrice: T) -> T {
		return (fixedPrice - spotPrice) * notionalVolume
	}

	/// Calculates settlements for multiple periods given realized spot prices.
	///
	/// Only periods present in both `settlementPeriods` and `realizedPrices` produce
	/// settlement values in the returned time series.
	///
	/// - Parameter realizedPrices: A time series of observed spot prices by period.
	/// - Returns: A time series of settlement amounts indexed by period.
	///
	/// ## Example
	///
	/// ```swift
	/// let prices = TimeSeries<Double>(
	///     periods: swap.settlementPeriods,
	///     values: [70.0, 74.0, 68.0]
	/// )
	/// let settlements = swap.settlements(realizedPrices: prices)
	/// // settlements[jan] == 2.0 * volume, etc.
	/// ```
	public func settlements(realizedPrices: TimeSeries<T>) -> TimeSeries<T> {
		var resultPeriods: [Period] = []
		var resultValues: [T] = []

		for period in settlementPeriods {
			guard let spotPrice = realizedPrices[period] else { continue }
			resultPeriods.append(period)
			resultValues.append(settlement(spotPrice: spotPrice))
		}

		return TimeSeries(
			periods: resultPeriods,
			values: resultValues,
			metadata: TimeSeriesMetadata(
				name: "\(underlier) Swap Settlements",
				description: "Settlement amounts for \(underlier) swap at fixed price \(fixedPrice)",
				unit: "USD"
			)
		)
	}
}

// MARK: - Codable

extension CommoditySwap: Codable {}

// MARK: - Equatable

extension CommoditySwap: Equatable where T: Equatable {}

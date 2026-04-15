//
//  HedgingProgram.swift
//  BusinessMath
//
//  Created by Justin Purnell on 4/15/26.
//

import Foundation
import Numerics

// MARK: - HedgeInstrument

/// A hedge instrument that can compute settlements against realized prices.
///
/// Types conforming to `HedgeInstrument` represent financial instruments used
/// to hedge commodity price risk. Each instrument defines the periods over which
/// it settles and can compute settlement amounts given a spot price.
public protocol HedgeInstrument: Sendable {
	associatedtype Value: Real & Sendable & Codable

	/// The periods over which the instrument settles.
	var settlementPeriods: [Period] { get }

	/// Calculates the settlement amount for a single spot price observation.
	///
	/// - Parameter spotPrice: The observed spot price for the period.
	/// - Returns: The settlement amount.
	func settlement(spotPrice: Value) -> Value
}

// MARK: - HedgeInstrument Conformances

extension CommoditySwap: HedgeInstrument {
	public typealias Value = T
}

extension CommodityCollar: HedgeInstrument {
	public typealias Value = T
}

extension ThreeWayCollar: HedgeInstrument {
	public typealias Value = T
}

// MARK: - HedgingProgram

/// A portfolio of commodity hedge instruments that aggregates settlements,
/// computes coverage ratios, and tracks effective realized prices.
///
/// A hedging program combines swaps, collars, and three-way collars into a
/// single portfolio view. It provides methods for calculating total settlement
/// cash flows, measuring hedge coverage, and determining the effective price
/// realized after hedging.
///
/// ## Example
///
/// ```swift
/// var program = HedgingProgram<Double>()
///
/// program.addSwap(CommoditySwap(
///     underlier: "WTI",
///     fixedPrice: 72.0,
///     notionalVolume: 10_000.0,
///     settlementPeriods: [Period.month(year: 2026, month: 1)]
/// ))
///
/// let spotPrices = TimeSeries<Double>(
///     periods: [Period.month(year: 2026, month: 1)],
///     values: [68.0]
/// )
///
/// let settlements = program.totalSettlements(realizedPrices: spotPrices)
/// // settlements[jan] == (72 - 68) * 10_000 = 40_000
/// ```
public struct HedgingProgram<T: Real & Sendable>: Sendable where T: Codable {

	/// The commodity swaps in this hedging program.
	public private(set) var swaps: [CommoditySwap<T>]

	/// The costless collars in this hedging program.
	public private(set) var collars: [CommodityCollar<T>]

	/// The three-way collars in this hedging program.
	public private(set) var threeWayCollars: [ThreeWayCollar<T>]

	/// Creates an empty hedging program with no instruments.
	public init() {
		self.swaps = []
		self.collars = []
		self.threeWayCollars = []
	}

	/// Adds a commodity swap to the hedging program.
	///
	/// - Parameter swap: The swap to add.
	public mutating func addSwap(_ swap: CommoditySwap<T>) {
		swaps.append(swap)
	}

	/// Adds a commodity collar to the hedging program.
	///
	/// - Parameter collar: The collar to add.
	public mutating func addCollar(_ collar: CommodityCollar<T>) {
		collars.append(collar)
	}

	/// Adds a three-way collar to the hedging program.
	///
	/// - Parameter collar: The three-way collar to add.
	public mutating func addThreeWayCollar(_ collar: ThreeWayCollar<T>) {
		threeWayCollars.append(collar)
	}

	/// Total settlements across all instruments for given realized prices.
	///
	/// For each period in the realized prices, sums the settlement amounts from
	/// all swaps, collars, and three-way collars whose settlement periods include
	/// that period.
	///
	/// - Parameter realizedPrices: A time series of observed spot prices by period.
	/// - Returns: A time series of total settlement amounts indexed by period.
	public func totalSettlements(realizedPrices: TimeSeries<T>) -> TimeSeries<T> {
		var resultPeriods: [Period] = []
		var resultValues: [T] = []

		for period in realizedPrices.periods {
			guard let spotPrice = realizedPrices[period] else { continue }
			var total: T = .zero

			for swap in swaps where swap.settlementPeriods.contains(period) {
				total += swap.settlement(spotPrice: spotPrice)
			}
			for collar in collars where collar.settlementPeriods.contains(period) {
				total += collar.settlement(spotPrice: spotPrice)
			}
			for threeWay in threeWayCollars where threeWay.settlementPeriods.contains(period) {
				total += threeWay.settlement(spotPrice: spotPrice)
			}

			resultPeriods.append(period)
			resultValues.append(total)
		}

		return TimeSeries(
			periods: resultPeriods,
			values: resultValues,
			metadata: TimeSeriesMetadata(
				name: "Total Hedge Settlements",
				description: "Aggregate settlement amounts across all hedge instruments",
				unit: "USD"
			)
		)
	}

	/// Coverage ratio: hedged volume / total production per period.
	///
	/// Computes the fraction of production that is hedged for each period.
	/// Returns zero for any period where production is zero (division safety).
	///
	/// - Parameter totalProduction: A time series of total production volumes by period.
	/// - Returns: A time series of coverage ratios (0.0 to 1.0+) indexed by period.
	public func coverageRatio(totalProduction: TimeSeries<T>) -> TimeSeries<T> {
		var resultPeriods: [Period] = []
		var resultValues: [T] = []

		for period in totalProduction.periods {
			guard let production = totalProduction[period] else { continue }
			var hedgedVolume: T = .zero

			for swap in swaps where swap.settlementPeriods.contains(period) {
				hedgedVolume += swap.notionalVolume
			}
			for collar in collars where collar.settlementPeriods.contains(period) {
				hedgedVolume += collar.quantity
			}
			for threeWay in threeWayCollars where threeWay.settlementPeriods.contains(period) {
				hedgedVolume += threeWay.quantity
			}

			let ratio: T = production == .zero ? .zero : hedgedVolume / production
			resultPeriods.append(period)
			resultValues.append(ratio)
		}

		return TimeSeries(
			periods: resultPeriods,
			values: resultValues,
			metadata: TimeSeriesMetadata(
				name: "Hedge Coverage Ratio",
				description: "Hedged volume as a fraction of total production",
				unit: "ratio"
			)
		)
	}

	/// Effective realized price: spot + hedge settlement per unit of production.
	///
	/// For each period, calculates the effective price the producer realizes
	/// after accounting for hedge settlements. Returns the spot price if
	/// production is zero for a period (division safety).
	///
	/// - Parameters:
	///   - spotPrices: A time series of observed spot prices by period.
	///   - totalProduction: A time series of total production volumes by period.
	/// - Returns: A time series of effective realized prices indexed by period.
	public func effectiveRealizedPrice(
		spotPrices: TimeSeries<T>,
		totalProduction: TimeSeries<T>
	) -> TimeSeries<T> {
		let settlements = totalSettlements(realizedPrices: spotPrices)
		var resultPeriods: [Period] = []
		var resultValues: [T] = []

		for period in spotPrices.periods {
			guard let spot = spotPrices[period] else { continue }
			let settlementAmount = settlements[period] ?? .zero
			let production = totalProduction[period] ?? .zero

			let effective: T
			if production == .zero {
				effective = spot
			} else {
				effective = spot + settlementAmount / production
			}

			resultPeriods.append(period)
			resultValues.append(effective)
		}

		return TimeSeries(
			periods: resultPeriods,
			values: resultValues,
			metadata: TimeSeriesMetadata(
				name: "Effective Realized Price",
				description: "Spot price adjusted for hedge settlements per unit of production",
				unit: "USD/unit"
			)
		)
	}
}

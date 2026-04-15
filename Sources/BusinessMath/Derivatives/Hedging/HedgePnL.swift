//
//  HedgePnL.swift
//  BusinessMath
//
//  Created by Justin Purnell on 4/15/26.
//

import Foundation
import Numerics

// MARK: - HedgePnL

/// P&L breakdown for a hedging program.
///
/// `HedgePnL` provides a summary of hedging performance including realized
/// (settled) P&L, unrealized (mark-to-market) P&L, total P&L, coverage ratio,
/// and the average effective price realized after hedging.
///
/// ## Example
///
/// ```swift
/// var program = HedgingProgram<Double>()
/// program.addSwap(swap)
///
/// let pnl = HedgePnL.calculate(
///     program: program,
///     realizedPrices: spotPrices,
///     totalProduction: production
/// )
///
/// print("Realized P&L: \(pnl.realizedPnL)")
/// print("Coverage: \(pnl.coverageRatio * 100)%")
/// print("Effective Price: \(pnl.effectivePrice)")
/// ```
public struct HedgePnL<T: Real & Sendable>: Sendable where T: Codable {

	/// The realized P&L from settled instruments (sum of all settlement amounts).
	public let realizedPnL: T

	/// The unrealized P&L from unsettled mark-to-market positions (placeholder for now).
	public let unrealizedPnL: T

	/// The total P&L (realized + unrealized).
	public let totalPnL: T

	/// The average hedge coverage ratio across all periods (hedged volume / total production).
	public let coverageRatio: T

	/// The average effective realized price across all periods.
	public let effectivePrice: T

	/// Calculates P&L from a hedging program and realized prices.
	///
	/// Computes the realized P&L as the sum of all settlement amounts, the average
	/// coverage ratio, and the average effective realized price across all periods.
	/// Unrealized P&L is currently set to zero as a placeholder for future MTM support.
	///
	/// - Parameters:
	///   - program: The hedging program containing all hedge instruments.
	///   - realizedPrices: A time series of observed spot prices by period.
	///   - totalProduction: A time series of total production volumes by period.
	/// - Returns: A `HedgePnL` summary of the hedging program's performance.
	public static func calculate(
		program: HedgingProgram<T>,
		realizedPrices: TimeSeries<T>,
		totalProduction: TimeSeries<T>
	) -> HedgePnL<T> {
		let settlements = program.totalSettlements(realizedPrices: realizedPrices)
		let coverageRatios = program.coverageRatio(totalProduction: totalProduction)
		let effectivePrices = program.effectiveRealizedPrice(
			spotPrices: realizedPrices,
			totalProduction: totalProduction
		)

		// Sum realized P&L from all settlement periods
		var realizedTotal: T = .zero
		for period in settlements.periods {
			if let value = settlements[period] {
				realizedTotal += value
			}
		}

		// Average coverage ratio across periods
		let avgCoverage: T
		let coveragePeriods = coverageRatios.periods
		if coveragePeriods.isEmpty {
			avgCoverage = .zero
		} else {
			var coverageSum: T = .zero
			for period in coveragePeriods {
				if let value = coverageRatios[period] {
					coverageSum += value
				}
			}
			avgCoverage = coverageSum / (T(exactly: coveragePeriods.count) ?? .zero)
		}

		// Average effective price across periods
		// For an empty program (no instruments), effective price is zero
		let avgEffectivePrice: T
		let hasInstruments = !program.swaps.isEmpty || !program.collars.isEmpty || !program.threeWayCollars.isEmpty
		let effectivePeriods = effectivePrices.periods
		if effectivePeriods.isEmpty || !hasInstruments {
			avgEffectivePrice = .zero
		} else {
			var priceSum: T = .zero
			for period in effectivePeriods {
				if let value = effectivePrices[period] {
					priceSum += value
				}
			}
			avgEffectivePrice = priceSum / (T(exactly: effectivePeriods.count) ?? .zero)
		}

		let unrealized: T = .zero

		return HedgePnL(
			realizedPnL: realizedTotal,
			unrealizedPnL: unrealized,
			totalPnL: realizedTotal + unrealized,
			coverageRatio: avgCoverage,
			effectivePrice: avgEffectivePrice
		)
	}
}

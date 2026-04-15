//
//  HedgingProgramTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 4/15/26.
//

import Testing
import Foundation
@testable import BusinessMath

// MARK: - HedgingProgram Tests

@Suite("HedgingProgram Tests")
struct HedgingProgramTests {

	let periods = [
		Period.month(year: 2026, month: 1),
		Period.month(year: 2026, month: 2),
		Period.month(year: 2026, month: 3)
	]

	// MARK: - Single Swap

	@Test("Single swap — total settlements match swap settlements")
	func singleSwapSettlements() {
		let swap = CommoditySwap<Double>(
			underlier: "WTI",
			fixedPrice: 72.0,
			notionalVolume: 10_000.0,
			settlementPeriods: periods
		)

		var program = HedgingProgram<Double>()
		program.addSwap(swap)

		let spotPrices = TimeSeries<Double>(
			periods: periods,
			values: [68.0, 72.0, 76.0]
		)

		let totalSettlements = program.totalSettlements(realizedPrices: spotPrices)
		let swapSettlements = swap.settlements(realizedPrices: spotPrices)

		for period in periods {
			#expect(totalSettlements[period] == swapSettlements[period])
		}
	}

	// MARK: - Single Collar

	@Test("Single collar — total settlements match collar settlements")
	func singleCollarSettlements() {
		let collar = CommodityCollar<Double>(
			underlier: "WTI",
			putStrike: 60.0,
			callStrike: 80.0,
			quantity: 10_000.0,
			settlementPeriods: periods
		)

		var program = HedgingProgram<Double>()
		program.addCollar(collar)

		let spotPrices = TimeSeries<Double>(
			periods: periods,
			values: [55.0, 70.0, 85.0]
		)

		let totalSettlements = program.totalSettlements(realizedPrices: spotPrices)

		// spot=55: payoff = (60-55) * 10000 = 50000
		#expect(totalSettlements[periods[0]] == 50_000.0)
		// spot=70: payoff = 0 (in the range)
		#expect(totalSettlements[periods[1]] == 0.0)
		// spot=85: payoff = -(85-80) * 10000 = -50000
		#expect(totalSettlements[periods[2]] == -50_000.0)
	}

	// MARK: - Multi-Instrument

	@Test("Multi-instrument — swap + collar settlements sum correctly")
	func multiInstrumentSettlements() {
		let swap = CommoditySwap<Double>(
			underlier: "WTI",
			fixedPrice: 72.0,
			notionalVolume: 5_000.0,
			settlementPeriods: periods
		)

		let collar = CommodityCollar<Double>(
			underlier: "WTI",
			putStrike: 60.0,
			callStrike: 80.0,
			quantity: 5_000.0,
			settlementPeriods: periods
		)

		var program = HedgingProgram<Double>()
		program.addSwap(swap)
		program.addCollar(collar)

		let spotPrices = TimeSeries<Double>(
			periods: periods,
			values: [68.0, 70.0, 76.0]
		)

		let totalSettlements = program.totalSettlements(realizedPrices: spotPrices)

		// Period 1 (spot=68): swap = (72-68)*5000 = 20000, collar = 0 (in range) => 20000
		#expect(totalSettlements[periods[0]] == 20_000.0)
		// Period 2 (spot=70): swap = (72-70)*5000 = 10000, collar = 0 => 10000
		#expect(totalSettlements[periods[1]] == 10_000.0)
		// Period 3 (spot=76): swap = (72-76)*5000 = -20000, collar = 0 => -20000
		#expect(totalSettlements[periods[2]] == -20_000.0)
	}

	// MARK: - Coverage Ratio

	@Test("Coverage ratio — 10K hedged / 15K produced = 66.7%")
	func coverageRatio() {
		let swap = CommoditySwap<Double>(
			underlier: "WTI",
			fixedPrice: 72.0,
			notionalVolume: 10_000.0,
			settlementPeriods: periods
		)

		var program = HedgingProgram<Double>()
		program.addSwap(swap)

		let production = TimeSeries<Double>(
			periods: periods,
			values: [15_000.0, 15_000.0, 15_000.0]
		)

		let ratio = program.coverageRatio(totalProduction: production)

		for period in periods {
			let value = ratio[period]
			#expect(value != nil)
			if let value {
				#expect(abs(value - (10_000.0 / 15_000.0)) < 1e-10)
			}
		}
	}

	// MARK: - Effective Realized Price

	@Test("Effective realized price — spot $60 + hedge $12/bbl = $72/bbl")
	func effectiveRealizedPrice() {
		// Swap at $72 fixed, 10K volume. Spot = $60.
		// Settlement per period = (72-60) * 10000 = 120000
		// Production = 10000
		// Effective = 60 + 120000/10000 = 60 + 12 = 72
		let swap = CommoditySwap<Double>(
			underlier: "WTI",
			fixedPrice: 72.0,
			notionalVolume: 10_000.0,
			settlementPeriods: periods
		)

		var program = HedgingProgram<Double>()
		program.addSwap(swap)

		let spotPrices = TimeSeries<Double>(
			periods: periods,
			values: [60.0, 60.0, 60.0]
		)

		let production = TimeSeries<Double>(
			periods: periods,
			values: [10_000.0, 10_000.0, 10_000.0]
		)

		let effectivePrice = program.effectiveRealizedPrice(
			spotPrices: spotPrices,
			totalProduction: production
		)

		for period in periods {
			#expect(effectivePrice[period] == 72.0)
		}
	}

	// MARK: - Empty Program

	@Test("Empty program — zero settlements, zero coverage")
	func emptyProgram() {
		let program = HedgingProgram<Double>()

		let spotPrices = TimeSeries<Double>(
			periods: periods,
			values: [60.0, 70.0, 80.0]
		)

		let production = TimeSeries<Double>(
			periods: periods,
			values: [10_000.0, 10_000.0, 10_000.0]
		)

		let settlements = program.totalSettlements(realizedPrices: spotPrices)
		let ratio = program.coverageRatio(totalProduction: production)

		for period in periods {
			#expect(settlements[period] == 0.0)
			#expect(ratio[period] == 0.0)
		}
	}
}

// MARK: - HedgePnL Tests

@Suite("HedgePnL Tests")
struct HedgePnLTests {

	let periods = [
		Period.month(year: 2026, month: 1),
		Period.month(year: 2026, month: 2),
		Period.month(year: 2026, month: 3)
	]

	// MARK: - Calculate from Swap Program

	@Test("Calculate from swap program — realized PnL = sum of settlements")
	func calculateFromSwapProgram() {
		let swap = CommoditySwap<Double>(
			underlier: "WTI",
			fixedPrice: 72.0,
			notionalVolume: 10_000.0,
			settlementPeriods: periods
		)

		var program = HedgingProgram<Double>()
		program.addSwap(swap)

		let spotPrices = TimeSeries<Double>(
			periods: periods,
			values: [68.0, 72.0, 76.0]
		)

		let production = TimeSeries<Double>(
			periods: periods,
			values: [10_000.0, 10_000.0, 10_000.0]
		)

		let pnl = HedgePnL.calculate(
			program: program,
			realizedPrices: spotPrices,
			totalProduction: production
		)

		// Settlements: (72-68)*10000=40000, (72-72)*10000=0, (72-76)*10000=-40000
		// Sum = 0
		#expect(pnl.realizedPnL == 0.0)
		#expect(pnl.totalPnL == pnl.realizedPnL + pnl.unrealizedPnL)
	}

	// MARK: - Empty Program

	@Test("Calculate from empty program — all zeros")
	func calculateFromEmptyProgram() {
		let program = HedgingProgram<Double>()

		let spotPrices = TimeSeries<Double>(
			periods: periods,
			values: [68.0, 72.0, 76.0]
		)

		let production = TimeSeries<Double>(
			periods: periods,
			values: [10_000.0, 10_000.0, 10_000.0]
		)

		let pnl = HedgePnL.calculate(
			program: program,
			realizedPrices: spotPrices,
			totalProduction: production
		)

		#expect(pnl.realizedPnL == .zero)
		#expect(pnl.unrealizedPnL == .zero)
		#expect(pnl.totalPnL == .zero)
		#expect(pnl.coverageRatio == .zero)
		#expect(pnl.effectivePrice == .zero)
	}

	// MARK: - Coverage Ratio in PnL

	@Test("Coverage ratio in PnL matches program coverage")
	func coverageRatioInPnL() {
		let swap = CommoditySwap<Double>(
			underlier: "WTI",
			fixedPrice: 72.0,
			notionalVolume: 10_000.0,
			settlementPeriods: periods
		)

		var program = HedgingProgram<Double>()
		program.addSwap(swap)

		let spotPrices = TimeSeries<Double>(
			periods: periods,
			values: [68.0, 70.0, 72.0]
		)

		let production = TimeSeries<Double>(
			periods: periods,
			values: [15_000.0, 15_000.0, 15_000.0]
		)

		let pnl = HedgePnL.calculate(
			program: program,
			realizedPrices: spotPrices,
			totalProduction: production
		)

		// Average coverage = 10000/15000 = 0.6667
		#expect(abs(pnl.coverageRatio - (10_000.0 / 15_000.0)) < 1e-10)
	}

	// MARK: - Effective Price in PnL

	@Test("Effective price in PnL matches program effective price")
	func effectivePriceInPnL() {
		let swap = CommoditySwap<Double>(
			underlier: "WTI",
			fixedPrice: 72.0,
			notionalVolume: 10_000.0,
			settlementPeriods: periods
		)

		var program = HedgingProgram<Double>()
		program.addSwap(swap)

		let spotPrices = TimeSeries<Double>(
			periods: periods,
			values: [60.0, 60.0, 60.0]
		)

		let production = TimeSeries<Double>(
			periods: periods,
			values: [10_000.0, 10_000.0, 10_000.0]
		)

		let pnl = HedgePnL.calculate(
			program: program,
			realizedPrices: spotPrices,
			totalProduction: production
		)

		// Each period: spot=60, settlement=(72-60)*10000=120000, production=10000
		// Effective = 60 + 120000/10000 = 72
		// Average effective price = 72
		#expect(pnl.effectivePrice == 72.0)
	}
}

//
//  CommodityInstrumentTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 4/15/26.
//

import Testing
import Foundation
@testable import BusinessMath

// MARK: - CommoditySwap Tests

@Suite("CommoditySwap Tests")
struct CommoditySwapTests {

	let periods = [
		Period.month(year: 2026, month: 1),
		Period.month(year: 2026, month: 2),
		Period.month(year: 2026, month: 3)
	]

	@Test("Producer gains when spot is below fixed price")
	func producerGainsWhenSpotBelowFixed() {
		let swap = CommoditySwap<Double>(
			underlier: "WTI",
			fixedPrice: 72.0,
			notionalVolume: 1000.0,
			settlementPeriods: periods
		)
		let result = swap.settlement(spotPrice: 70.0)
		#expect(result == 2.0 * 1000.0)
	}

	@Test("Producer pays when spot is above fixed price")
	func producerPaysWhenSpotAboveFixed() {
		let swap = CommoditySwap<Double>(
			underlier: "WTI",
			fixedPrice: 72.0,
			notionalVolume: 1000.0,
			settlementPeriods: periods
		)
		let result = swap.settlement(spotPrice: 74.0)
		#expect(result == -2.0 * 1000.0)
	}

	@Test("Zero settlement when spot equals fixed")
	func zeroSettlementWhenSpotEqualsFixed() {
		let swap = CommoditySwap<Double>(
			underlier: "WTI",
			fixedPrice: 72.0,
			notionalVolume: 1000.0,
			settlementPeriods: periods
		)
		let result = swap.settlement(spotPrice: 72.0)
		#expect(result == 0.0)
	}

	@Test("Multiple period settlements from realized prices")
	func multiPeriodSettlements() {
		let swap = CommoditySwap<Double>(
			underlier: "WTI",
			fixedPrice: 72.0,
			notionalVolume: 1.0,
			settlementPeriods: periods
		)
		let realizedPrices = TimeSeries<Double>(
			periods: periods,
			values: [70.0, 74.0, 68.0]
		)
		let settlements = swap.settlements(realizedPrices: realizedPrices)

		#expect(settlements[periods[0]] == 2.0)
		#expect(settlements[periods[1]] == -2.0)
		#expect(settlements[periods[2]] == 4.0)
	}

	@Test("Zero volume produces zero settlement")
	func zeroVolumeZeroSettlement() {
		let swap = CommoditySwap<Double>(
			underlier: "WTI",
			fixedPrice: 72.0,
			notionalVolume: 0.0,
			settlementPeriods: periods
		)
		let result = swap.settlement(spotPrice: 70.0)
		#expect(result == 0.0)
	}
}

// MARK: - CommodityCollar Tests

@Suite("CommodityCollar Tests")
struct CommodityCollarTests {

	let periods = [
		Period.month(year: 2026, month: 1),
		Period.month(year: 2026, month: 2),
		Period.month(year: 2026, month: 3)
	]

	@Test("Positive payoff when spot below put strike (protection kicks in)")
	func positivePayoffBelowPut() {
		let collar = CommodityCollar<Double>(
			underlier: "WTI",
			putStrike: 60.0,
			callStrike: 80.0,
			quantity: 1000.0,
			settlementPeriods: periods
		)
		// spot $50: put pays (60 - 50) = $10 per unit
		let payoff = collar.payoff(spotPrice: 50.0)
		#expect(payoff == 10.0)
		let settlement = collar.settlement(spotPrice: 50.0)
		#expect(settlement == 10.0 * 1000.0)
	}

	@Test("Zero payoff when spot between strikes")
	func zeroPayoffBetweenStrikes() {
		let collar = CommodityCollar<Double>(
			underlier: "WTI",
			putStrike: 60.0,
			callStrike: 80.0,
			quantity: 1000.0,
			settlementPeriods: periods
		)
		let payoff = collar.payoff(spotPrice: 70.0)
		#expect(payoff == 0.0)
	}

	@Test("Negative payoff when spot above call strike (caps upside)")
	func negativePayoffAboveCall() {
		let collar = CommodityCollar<Double>(
			underlier: "WTI",
			putStrike: 60.0,
			callStrike: 80.0,
			quantity: 1000.0,
			settlementPeriods: periods
		)
		// spot $90: short call costs -(90 - 80) = -$10 per unit
		let payoff = collar.payoff(spotPrice: 90.0)
		#expect(payoff == -10.0)
		let settlement = collar.settlement(spotPrice: 90.0)
		#expect(settlement == -10.0 * 1000.0)
	}

	@Test("Zero payoff at put strike boundary")
	func zeroPayoffAtPutStrike() {
		let collar = CommodityCollar<Double>(
			underlier: "WTI",
			putStrike: 60.0,
			callStrike: 80.0,
			quantity: 1000.0,
			settlementPeriods: periods
		)
		let payoff = collar.payoff(spotPrice: 60.0)
		#expect(payoff == 0.0)
	}

	@Test("Zero payoff at call strike boundary")
	func zeroPayoffAtCallStrike() {
		let collar = CommodityCollar<Double>(
			underlier: "WTI",
			putStrike: 60.0,
			callStrike: 80.0,
			quantity: 1000.0,
			settlementPeriods: periods
		)
		let payoff = collar.payoff(spotPrice: 80.0)
		#expect(payoff == 0.0)
	}

	@Test("Zero quantity produces zero settlement")
	func zeroQuantityZeroSettlement() {
		let collar = CommodityCollar<Double>(
			underlier: "WTI",
			putStrike: 60.0,
			callStrike: 80.0,
			quantity: 0.0,
			settlementPeriods: periods
		)
		let settlement = collar.settlement(spotPrice: 50.0)
		#expect(settlement == 0.0)
	}

	@Test("Degenerate collar with same strikes acts as forward")
	func degenerateCollarSameStrikes() {
		let collar = CommodityCollar<Double>(
			underlier: "WTI",
			putStrike: 70.0,
			callStrike: 70.0,
			quantity: 100.0,
			settlementPeriods: periods
		)
		// Below: payoff = 70 - 60 = 10
		#expect(collar.payoff(spotPrice: 60.0) == 10.0)
		// Above: payoff = -(80 - 70) = -10
		#expect(collar.payoff(spotPrice: 80.0) == -10.0)
		// At strike: zero
		#expect(collar.payoff(spotPrice: 70.0) == 0.0)
	}
}

// MARK: - ThreeWayCollar Tests

@Suite("ThreeWayCollar Tests")
struct ThreeWayCollarTests {

	let periods = [
		Period.month(year: 2026, month: 1),
		Period.month(year: 2026, month: 2),
		Period.month(year: 2026, month: 3)
	]

	// Strikes: shortPut=$40, longPut=$60, shortCall=$80

	@Test("Below short put: capped protection (tail risk given away)")
	func belowShortPut() {
		let collar = ThreeWayCollar<Double>(
			underlier: "WTI",
			shortPutStrike: 40.0,
			longPutStrike: 60.0,
			shortCallStrike: 80.0,
			quantity: 100.0,
			settlementPeriods: periods
		)
		// spot $30: long put pays (60-30)=30, short put costs (40-30)=10 -> net = 20
		let payoff = collar.payoff(spotPrice: 30.0)
		#expect(payoff == 20.0)
		let settlement = collar.settlement(spotPrice: 30.0)
		#expect(settlement == 20.0 * 100.0)
	}

	@Test("Between short put and long put: partial protection")
	func betweenShortPutAndLongPut() {
		let collar = ThreeWayCollar<Double>(
			underlier: "WTI",
			shortPutStrike: 40.0,
			longPutStrike: 60.0,
			shortCallStrike: 80.0,
			quantity: 100.0,
			settlementPeriods: periods
		)
		// spot $50: long put pays (60-50)=10, short put expired -> net = 10
		let payoff = collar.payoff(spotPrice: 50.0)
		#expect(payoff == 10.0)
	}

	@Test("Between long put and short call: zero payoff")
	func betweenLongPutAndShortCall() {
		let collar = ThreeWayCollar<Double>(
			underlier: "WTI",
			shortPutStrike: 40.0,
			longPutStrike: 60.0,
			shortCallStrike: 80.0,
			quantity: 100.0,
			settlementPeriods: periods
		)
		// spot $70: nothing in the money -> net = 0
		let payoff = collar.payoff(spotPrice: 70.0)
		#expect(payoff == 0.0)
	}

	@Test("Above short call: negative payoff (capped upside)")
	func aboveShortCall() {
		let collar = ThreeWayCollar<Double>(
			underlier: "WTI",
			shortPutStrike: 40.0,
			longPutStrike: 60.0,
			shortCallStrike: 80.0,
			quantity: 100.0,
			settlementPeriods: periods
		)
		// spot $90: short call costs -(90-80)=-10 -> net = -10
		let payoff = collar.payoff(spotPrice: 90.0)
		#expect(payoff == -10.0)
		let settlement = collar.settlement(spotPrice: 90.0)
		#expect(settlement == -10.0 * 100.0)
	}

	@Test("Boundary: spot exactly at short put strike")
	func atShortPutStrike() {
		let collar = ThreeWayCollar<Double>(
			underlier: "WTI",
			shortPutStrike: 40.0,
			longPutStrike: 60.0,
			shortCallStrike: 80.0,
			quantity: 100.0,
			settlementPeriods: periods
		)
		// spot $40: long put pays (60-40)=20, short put at-the-money pays 0 -> net = 20
		let payoff = collar.payoff(spotPrice: 40.0)
		#expect(payoff == 20.0)
	}

	@Test("Boundary: spot exactly at long put strike")
	func atLongPutStrike() {
		let collar = ThreeWayCollar<Double>(
			underlier: "WTI",
			shortPutStrike: 40.0,
			longPutStrike: 60.0,
			shortCallStrike: 80.0,
			quantity: 100.0,
			settlementPeriods: periods
		)
		// spot $60: long put at-the-money pays 0 -> net = 0
		let payoff = collar.payoff(spotPrice: 60.0)
		#expect(payoff == 0.0)
	}

	@Test("Boundary: spot exactly at short call strike")
	func atShortCallStrike() {
		let collar = ThreeWayCollar<Double>(
			underlier: "WTI",
			shortPutStrike: 40.0,
			longPutStrike: 60.0,
			shortCallStrike: 80.0,
			quantity: 100.0,
			settlementPeriods: periods
		)
		// spot $80: short call at-the-money pays 0 -> net = 0
		let payoff = collar.payoff(spotPrice: 80.0)
		#expect(payoff == 0.0)
	}

	@Test("Zero quantity produces zero settlement")
	func zeroQuantityZeroSettlement() {
		let collar = ThreeWayCollar<Double>(
			underlier: "WTI",
			shortPutStrike: 40.0,
			longPutStrike: 60.0,
			shortCallStrike: 80.0,
			quantity: 0.0,
			settlementPeriods: periods
		)
		let settlement = collar.settlement(spotPrice: 30.0)
		#expect(settlement == 0.0)
	}
}

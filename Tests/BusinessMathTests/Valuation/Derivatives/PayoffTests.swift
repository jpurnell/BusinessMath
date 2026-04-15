//
//  PayoffTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-04-15.
//

import XCTest
@testable import BusinessMath

final class PayoffTests: XCTestCase {

    // MARK: - European Payoff Tests

    func testEuropeanCallPayoff() {
        let payoff = EuropeanPayoff(strike: 100.0, optionType: .call, notional: 10.0)
        let result = payoff.terminalValue(finalSpot: 115.0)
        XCTAssertEqual(result, 150.0, accuracy: 1e-10, "Call payoff should be max(115 - 100, 0) * 10 = 150")
    }

    func testEuropeanPutPayoff() {
        let payoff = EuropeanPayoff(strike: 100.0, optionType: .put, notional: 10.0)
        let result = payoff.terminalValue(finalSpot: 85.0)
        XCTAssertEqual(result, 150.0, accuracy: 1e-10, "Put payoff should be max(100 - 85, 0) * 10 = 150")
    }

    func testEuropeanOTMPayoffIsZero() {
        let call = EuropeanPayoff(strike: 100.0, optionType: .call)
        XCTAssertEqual(call.terminalValue(finalSpot: 90.0), 0.0, accuracy: 1e-10, "OTM call should pay 0")

        let put = EuropeanPayoff(strike: 100.0, optionType: .put)
        XCTAssertEqual(put.terminalValue(finalSpot: 110.0), 0.0, accuracy: 1e-10, "OTM put should pay 0")
    }

    // MARK: - Asian Payoff Tests

    func testAsianCallPayoff() {
        var payoff = AsianPayoff(strike: 105.0, optionType: .call)
        payoff.observe(value: 100.0, time: 0.25)
        payoff.observe(value: 110.0, time: 0.50)
        payoff.observe(value: 120.0, time: 0.75)
        // Average = (100 + 110 + 120) / 3 = 110
        let result = payoff.terminalValue(finalSpot: 120.0)
        XCTAssertEqual(result, 5.0, accuracy: 1e-10, "Asian call payoff should be max(110 - 105, 0) = 5")
    }

    func testAsianCallBelowStrikePayoffIsZero() {
        var payoff = AsianPayoff(strike: 115.0, optionType: .call)
        payoff.observe(value: 100.0, time: 0.25)
        payoff.observe(value: 110.0, time: 0.50)
        payoff.observe(value: 120.0, time: 0.75)
        // Average = 110, strike = 115
        let result = payoff.terminalValue(finalSpot: 120.0)
        XCTAssertEqual(result, 0.0, accuracy: 1e-10, "Asian call should pay 0 when average < strike")
    }

    func testAsianResetClearsState() {
        var payoff = AsianPayoff(strike: 100.0, optionType: .call)
        payoff.observe(value: 200.0, time: 0.5)
        payoff.reset()
        // After reset, no observations -> terminalValue returns 0
        let result = payoff.terminalValue(finalSpot: 200.0)
        XCTAssertEqual(result, 0.0, accuracy: 1e-10, "Reset should clear accumulated state")
    }

    // MARK: - Barrier Payoff Tests

    func testDownAndOutBarrierNotHit() {
        var payoff = BarrierPayoff(
            strike: 100.0, barrier: 80.0,
            barrierType: .downAndOut, optionType: .call
        )
        payoff.observe(value: 95.0, time: 0.25)
        payoff.observe(value: 90.0, time: 0.50)
        payoff.observe(value: 105.0, time: 0.75)
        // Barrier at 80 never hit, normal payoff
        let result = payoff.terminalValue(finalSpot: 110.0)
        XCTAssertEqual(result, 10.0, accuracy: 1e-10, "Down-and-out not hit should give normal payoff")
    }

    func testDownAndOutBarrierHit() {
        var payoff = BarrierPayoff(
            strike: 100.0, barrier: 80.0,
            barrierType: .downAndOut, optionType: .call
        )
        payoff.observe(value: 95.0, time: 0.25)
        payoff.observe(value: 80.0, time: 0.50)  // Hits barrier (<=)
        payoff.observe(value: 105.0, time: 0.75)
        let result = payoff.terminalValue(finalSpot: 110.0)
        XCTAssertEqual(result, 0.0, accuracy: 1e-10, "Down-and-out hit should pay 0")
    }

    func testDownAndInBarrierHit() {
        var payoff = BarrierPayoff(
            strike: 100.0, barrier: 80.0,
            barrierType: .downAndIn, optionType: .call
        )
        payoff.observe(value: 95.0, time: 0.25)
        payoff.observe(value: 75.0, time: 0.50)  // Breaches barrier
        payoff.observe(value: 105.0, time: 0.75)
        let result = payoff.terminalValue(finalSpot: 110.0)
        XCTAssertEqual(result, 10.0, accuracy: 1e-10, "Down-and-in hit should give normal payoff")
    }

    func testDownAndInBarrierNotHit() {
        var payoff = BarrierPayoff(
            strike: 100.0, barrier: 80.0,
            barrierType: .downAndIn, optionType: .call
        )
        payoff.observe(value: 95.0, time: 0.25)
        payoff.observe(value: 90.0, time: 0.50)
        payoff.observe(value: 105.0, time: 0.75)
        let result = payoff.terminalValue(finalSpot: 110.0)
        XCTAssertEqual(result, 0.0, accuracy: 1e-10, "Down-and-in not hit should pay 0")
    }

    // MARK: - Lookback Payoff Tests

    func testLookbackCallPayoff() {
        var payoff = LookbackPayoff(optionType: .call)
        payoff.observe(value: 100.0, time: 0.25)
        payoff.observe(value: 90.0, time: 0.50)
        payoff.observe(value: 105.0, time: 0.75)
        // Call: finalSpot - min = 110 - 90 = 20
        let result = payoff.terminalValue(finalSpot: 110.0)
        XCTAssertEqual(result, 20.0, accuracy: 1e-10, "Lookback call should be finalSpot - pathMin")
    }

    func testLookbackPutPayoff() {
        var payoff = LookbackPayoff(optionType: .put)
        payoff.observe(value: 100.0, time: 0.25)
        payoff.observe(value: 120.0, time: 0.50)
        payoff.observe(value: 105.0, time: 0.75)
        // Put: max - finalSpot = 120 - 95 = 25
        let result = payoff.terminalValue(finalSpot: 95.0)
        XCTAssertEqual(result, 25.0, accuracy: 1e-10, "Lookback put should be pathMax - finalSpot")
    }

    // MARK: - Digital Payoff Tests

    func testDigitalCallITM() {
        let payoff = DigitalPayoff(strike: 100.0, optionType: .call, payout: 500.0)
        let result = payoff.terminalValue(finalSpot: 101.0)
        XCTAssertEqual(result, 500.0, accuracy: 1e-10, "Digital call ITM should pay fixed payout")
    }

    func testDigitalCallOTM() {
        let payoff = DigitalPayoff(strike: 100.0, optionType: .call, payout: 500.0)
        let result = payoff.terminalValue(finalSpot: 99.0)
        XCTAssertEqual(result, 0.0, accuracy: 1e-10, "Digital call OTM should pay 0")
    }

    func testDigitalPutITM() {
        let payoff = DigitalPayoff(strike: 100.0, optionType: .put, payout: 500.0)
        let result = payoff.terminalValue(finalSpot: 99.0)
        XCTAssertEqual(result, 500.0, accuracy: 1e-10, "Digital put ITM should pay fixed payout")
    }
}

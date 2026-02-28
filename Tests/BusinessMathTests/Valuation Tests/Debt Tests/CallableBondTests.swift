//
//  CallableBondTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-01-25.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Callable Bond Tests")
struct CallableBondTests {

    // Use a fixed reference date to avoid wall-clock dependencies in bond calculations
    private static let referenceDate: Date = {
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 1
        return Calendar.current.date(from: components)!
    }()

    @Test("Callable bond prices less than non-callable")
    func callablePriceLessThanNonCallable() {
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        // Create underlying bond
        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.06,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        // Callable after 3 years at 1050 (5% premium)
        let callDate = calendar.date(byAdding: .year, value: 3, to: today)!
        let callSchedule = [CallProvision(date: callDate, callPrice: 1050.0)]

        let callableBond = CallableBond(
            bond: bond,
            callSchedule: callSchedule
        )

        // Price both bonds
        let nonCallablePrice = bond.price(yield: 0.05, asOf: today)
        let callablePrice = callableBond.price(
            riskFreeRate: 0.03,
            spread: 0.02,
            volatility: 0.15,
            asOf: today
        )

        // Callable bond should be worth less (issuer has valuable call option)
        #expect(callablePrice < nonCallablePrice)
        #expect(callablePrice > 0)
    }

    @Test("Call option value is positive")
    func callOptionValuePositive() {
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.06,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        let callDate = calendar.date(byAdding: .year, value: 3, to: today)!
        let callSchedule = [CallProvision(date: callDate, callPrice: 1050.0)]

        let callableBond = CallableBond(
            bond: bond,
            callSchedule: callSchedule
        )

        let callValue = callableBond.callOptionValue(
            riskFreeRate: 0.03,
            spread: 0.02,
            volatility: 0.15,
            asOf: today
        )

        // Embedded call option has positive value to issuer
        #expect(callValue > 0.0)
    }

    @Test("Higher volatility increases call option value")
    func volatilityImpactOnCallValue() {
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.06,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        let callDate = calendar.date(byAdding: .year, value: 3, to: today)!
        let callSchedule = [CallProvision(date: callDate, callPrice: 1050.0)]

        let callableBond = CallableBond(
            bond: bond,
            callSchedule: callSchedule
        )

        let callValueLowVol = callableBond.callOptionValue(
            riskFreeRate: 0.03,
            spread: 0.02,
            volatility: 0.10,
            asOf: today
        )

        let callValueHighVol = callableBond.callOptionValue(
            riskFreeRate: 0.03,
            spread: 0.02,
            volatility: 0.25,
            asOf: today
        )

        // Higher volatility → More valuable call option
        #expect(callValueHighVol > callValueLowVol)
    }

    @Test("Call option value with zero volatility is lower")
    func zeroVolatilityCallValue() {
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.06,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        let callDate = calendar.date(byAdding: .year, value: 3, to: today)!
        let callSchedule = [CallProvision(date: callDate, callPrice: 1050.0)]

        let callableBond = CallableBond(
            bond: bond,
            callSchedule: callSchedule
        )

        let callValueZeroVol = callableBond.callOptionValue(
            riskFreeRate: 0.03,
            spread: 0.02,
            volatility: 0.0,
            asOf: today
        )

        let callValuePositiveVol = callableBond.callOptionValue(
            riskFreeRate: 0.03,
            spread: 0.02,
            volatility: 0.15,
            asOf: today
        )

        // Zero volatility → Lower (but possibly positive) call value
        #expect(callValueZeroVol <= callValuePositiveVol)
    }

    @Test("Multiple call dates in schedule")
    func multipleCallDates() {
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.06,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        // Declining call premium schedule
        let callDate1 = calendar.date(byAdding: .year, value: 3, to: today)!
        let callDate2 = calendar.date(byAdding: .year, value: 5, to: today)!
        let callDate3 = calendar.date(byAdding: .year, value: 7, to: today)!

        let callSchedule = [
            CallProvision(date: callDate1, callPrice: 1050.0),  // 5% premium
            CallProvision(date: callDate2, callPrice: 1030.0),  // 3% premium
            CallProvision(date: callDate3, callPrice: 1010.0)   // 1% premium
        ]

        let callableBond = CallableBond(
            bond: bond,
            callSchedule: callSchedule
        )

        let price = callableBond.price(
            riskFreeRate: 0.03,
            spread: 0.02,
            volatility: 0.15,
            asOf: today
        )

        // Should price successfully with multiple call dates
        #expect(price > 0.0)
        #expect(price < 1100.0)
    }

    @Test("OAS calculation")
    func oasCalculation() throws {
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.06,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        let callDate = calendar.date(byAdding: .year, value: 3, to: today)!
        let callSchedule = [CallProvision(date: callDate, callPrice: 1050.0)]

        let callableBond = CallableBond(
            bond: bond,
            callSchedule: callSchedule
        )

        // Calculate price first
        let marketPrice = callableBond.price(
            riskFreeRate: 0.03,
            spread: 0.02,
            volatility: 0.15,
            asOf: today
        )

        // Then solve for OAS that produces that price
        let oas = try callableBond.optionAdjustedSpread(
            marketPrice: marketPrice,
            riskFreeRate: 0.03,
            volatility: 0.15,
            asOf: today
        )

        // OAS should be close to our input spread
        #expect(abs(oas - 0.02) < 0.005)  // Within 50 bps
    }

    @Test("OAS is positive for credit risk")
    func oasPositiveForCredit() throws {
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.06,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        let callDate = calendar.date(byAdding: .year, value: 3, to: today)!
        let callSchedule = [CallProvision(date: callDate, callPrice: 1050.0)]

        let callableBond = CallableBond(
            bond: bond,
            callSchedule: callSchedule
        )

        // Price with positive credit spread
        let marketPrice = callableBond.price(
            riskFreeRate: 0.03,
            spread: 0.025,  // 250 bps credit spread
            volatility: 0.15,
            asOf: today
        )

        let oas = try callableBond.optionAdjustedSpread(
            marketPrice: marketPrice,
            riskFreeRate: 0.03,
            volatility: 0.15,
            asOf: today
        )

        // OAS should be positive (credit risk compensation)
        #expect(oas > 0.0)
    }

    @Test("Callable bond with Float type")
    func callableBondFloat() {
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = Bond(
            faceValue: Float(1000.0),
            couponRate: Float(0.06),
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        let callDate = calendar.date(byAdding: .year, value: 3, to: today)!
        let callSchedule = [CallProvision(date: callDate, callPrice: Float(1050.0))]

        let callableBond = CallableBond(
            bond: bond,
            callSchedule: callSchedule
        )

        let price = callableBond.price(
            riskFreeRate: Float(0.03),
            spread: Float(0.02),
            volatility: Float(0.15),
            asOf: today
        )

        #expect(price > Float(0.0))
    }

    @Test("Callable bond effective duration")
    func effectiveDuration() {
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.06,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        let callDate = calendar.date(byAdding: .year, value: 3, to: today)!
        let callSchedule = [CallProvision(date: callDate, callPrice: 1050.0)]

        let callableBond = CallableBond(
            bond: bond,
            callSchedule: callSchedule
        )

        let duration = callableBond.effectiveDuration(
            riskFreeRate: 0.03,
            spread: 0.02,
            volatility: 0.15,
            asOf: today
        )

        // Effective duration should be positive and reasonable
        #expect(duration > 0.0)
        #expect(duration < 10.0)  // Less than maturity due to call option
    }
}

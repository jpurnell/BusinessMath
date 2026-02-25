//
//  SpecializedBondTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-01-25.
//

import Testing
import TestSupport  // Cross-platform math functions
import Foundation
@testable import BusinessMath

@Suite("Zero Coupon Bond Tests")
struct ZeroCouponBondTests {

    @Test("Zero coupon bond price calculation")
    func zeroCouponBondPrice() {
        let calendar = Calendar.current
        let today = Date()
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = ZeroCouponBond(
            faceValue: 1000.0,
            maturityDate: maturity,
            issueDate: today
        )

        // Price at 5% yield
        let price = bond.price(yield: 0.05, asOf: today)

        // Zero coupon bond formula: Price = Face / (1 + r)^t
        // Price = 1000 / (1.05)^10 ≈ 613.91
        let expected = 1000.0 / pow(1.05, 10.0)
        #expect(abs(price - expected) < 1.0)
    }

    @Test("Zero coupon bond at different yields")
    func zeroCouponBondYields() {
        let calendar = Calendar.current
        let today = Date()
        let maturity = calendar.date(byAdding: .year, value: 5, to: today)!

        let bond = ZeroCouponBond(
            faceValue: 1000.0,
            maturityDate: maturity,
            issueDate: today
        )

        // Higher yield → Lower price
        let price3pct = bond.price(yield: 0.03, asOf: today)
        let price7pct = bond.price(yield: 0.07, asOf: today)

        #expect(price3pct > price7pct)
        #expect(price7pct > 0)
    }

    @Test("Zero coupon bond YTM calculation")
    func zeroCouponBondYTM() throws {
        let calendar = Calendar.current
        let today = Date()
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = ZeroCouponBond(
            faceValue: 1000.0,
            maturityDate: maturity,
            issueDate: today
        )

        // If bond trades at 600, what's the YTM?
        // 600 = 1000 / (1 + r)^10
        // (1 + r)^10 = 1000 / 600 = 1.6667
        // 1 + r = 1.6667^(1/10) ≈ 1.0524
        // r ≈ 5.24%
        let ytm = try bond.yieldToMaturity(price: 600.0, asOf: today)

        let expectedYTM = pow(1000.0 / 600.0, 1.0 / 10.0) - 1.0
        #expect(abs(ytm - expectedYTM) < 0.001)
    }

    @Test("Zero coupon bond duration equals maturity")
    func zeroCouponBondDuration() {
        let calendar = Calendar.current
        let today = Date()
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = ZeroCouponBond(
            faceValue: 1000.0,
            maturityDate: maturity,
            issueDate: today
        )

        let duration = bond.macaulayDuration(yield: 0.05, asOf: today)

        // For zero coupon bonds, Macaulay duration = time to maturity
        let yearsToMaturity = 10.0
        #expect(abs(duration - yearsToMaturity) < 0.1)
    }

    @Test("Zero coupon bond cash flow schedule")
    func zeroCouponBondCashFlows() {
        let calendar = Calendar.current
        let today = Date()
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = ZeroCouponBond(
            faceValue: 1000.0,
            maturityDate: maturity,
            issueDate: today
        )

        let cashFlows = bond.cashFlowSchedule(asOf: today)

        // Should have exactly ONE cash flow (principal at maturity)
        #expect(cashFlows.count == 1)
        #expect(cashFlows[0].type == .principal)
        #expect(cashFlows[0].amount == 1000.0)
    }
}

@Suite("Amortizing Bond Tests")
struct AmortizingBondTests {

    @Test("Amortizing bond cash flow schedule")
    func amortizingBondCashFlows() {
        let calendar = Calendar.current
        let today = Date()
        let maturity = calendar.date(byAdding: .year, value: 3, to: today)!

        // 3-year bond with annual payments, 5% coupon, amortizing 1/3 each year
        let bond = AmortizingBond(
            faceValue: 1000.0,
            couponRate: 0.05,
            maturityDate: maturity,
            paymentFrequency: .annual,
            issueDate: today,
            amortizationSchedule: [
                AmortizationPayment(date: calendar.date(byAdding: .year, value: 1, to: today)!, principalAmount: 333.33),
                AmortizationPayment(date: calendar.date(byAdding: .year, value: 2, to: today)!, principalAmount: 333.33),
                AmortizationPayment(date: calendar.date(byAdding: .year, value: 3, to: today)!, principalAmount: 333.34)
            ]
        )

        let cashFlows = bond.cashFlowSchedule(asOf: today)

        // Should have 3 coupon payments + 3 principal payments = 6 cash flows
        #expect(cashFlows.count == 6)

        // First year: coupon on full principal (1000 * 0.05 = 50) + principal payment (333.33)
        let year1Coupons = cashFlows.filter { $0.type == .coupon }
        #expect(year1Coupons.count == 3)
        #expect(abs(year1Coupons[0].amount - 50.0) < 1.0)

        // Principal payments should sum to face value
        let principalPayments = cashFlows.filter { $0.type == .principal }
        let totalPrincipal = principalPayments.reduce(0.0) { $0 + $1.amount }
        #expect(abs(totalPrincipal - 1000.0) < 1.0)
    }

    @Test("Amortizing bond price calculation")
    func amortizingBondPrice() {
        let calendar = Calendar.current
        let today = Date()
        let maturity = calendar.date(byAdding: .year, value: 3, to: today)!

        let bond = AmortizingBond(
            faceValue: 1000.0,
            couponRate: 0.05,
            maturityDate: maturity,
            paymentFrequency: .annual,
            issueDate: today,
            amortizationSchedule: [
                AmortizationPayment(date: calendar.date(byAdding: .year, value: 1, to: today)!, principalAmount: 333.33),
                AmortizationPayment(date: calendar.date(byAdding: .year, value: 2, to: today)!, principalAmount: 333.33),
                AmortizationPayment(date: calendar.date(byAdding: .year, value: 3, to: today)!, principalAmount: 333.34)
            ]
        )

        // At coupon rate = yield, should price near par
        let price = bond.price(yield: 0.05, asOf: today)
        #expect(abs(price - 1000.0) < 10.0)
    }

    @Test("Amortizing bond YTM calculation")
    func amortizingBondYTM() throws {
        let calendar = Calendar.current
        let today = Date()
        let maturity = calendar.date(byAdding: .year, value: 3, to: today)!

        let bond = AmortizingBond(
            faceValue: 1000.0,
            couponRate: 0.06,
            maturityDate: maturity,
            paymentFrequency: .annual,
            issueDate: today,
            amortizationSchedule: [
                AmortizationPayment(date: calendar.date(byAdding: .year, value: 1, to: today)!, principalAmount: 333.33),
                AmortizationPayment(date: calendar.date(byAdding: .year, value: 2, to: today)!, principalAmount: 333.33),
                AmortizationPayment(date: calendar.date(byAdding: .year, value: 3, to: today)!, principalAmount: 333.34)
            ]
        )

        // Calculate price at 5% yield
        let targetPrice = bond.price(yield: 0.05, asOf: today)

        // Calculate YTM from that price
        let ytm = try bond.yieldToMaturity(price: targetPrice, asOf: today)

        // Should recover the 5% yield
        #expect(abs(ytm - 0.05) < 0.001)
    }

    @Test("Amortizing bond duration less than maturity")
    func amortizingBondDuration() {
        let calendar = Calendar.current
        let today = Date()
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        // 10-year bond with equal annual principal payments
        var amortSchedule: [AmortizationPayment<Double>] = []
        for year in 1...10 {
            let date = calendar.date(byAdding: .year, value: year, to: today)!
            amortSchedule.append(AmortizationPayment(date: date, principalAmount: 100.0))
        }

        let bond = AmortizingBond(
            faceValue: 1000.0,
            couponRate: 0.05,
            maturityDate: maturity,
            paymentFrequency: .annual,
            issueDate: today,
            amortizationSchedule: amortSchedule
        )

        let duration = bond.macaulayDuration(yield: 0.05, asOf: today)

        // Duration should be less than 10 years due to principal amortization
        #expect(duration < 10.0)
        #expect(duration > 0.0)
    }

    @Test("Amortizing bond with semiannual coupons")
    func amortizingBondSemiannual() {
        let calendar = Calendar.current
        let today = Date()
        let maturity = calendar.date(byAdding: .year, value: 2, to: today)!

        // 2-year bond with semiannual coupons, annual principal payments
        let bond = AmortizingBond(
            faceValue: 1000.0,
            couponRate: 0.06,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today,
            amortizationSchedule: [
                AmortizationPayment(date: calendar.date(byAdding: .year, value: 1, to: today)!, principalAmount: 500.0),
                AmortizationPayment(date: calendar.date(byAdding: .year, value: 2, to: today)!, principalAmount: 500.0)
            ]
        )

        let cashFlows = bond.cashFlowSchedule(asOf: today)

        // 4 coupon payments (semiannual for 2 years) + 2 principal payments = 6
        #expect(cashFlows.count == 6)

        let couponPayments = cashFlows.filter { $0.type == .coupon }
        #expect(couponPayments.count == 4)
    }
}

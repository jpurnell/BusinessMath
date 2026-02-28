//
//  BondPricingTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-01-25.
//

import Testing
import TestSupport  // Cross-platform math functions
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Bond Pricing Tests")
struct BondPricingTests {

    // Use a fixed reference date to avoid wall-clock dependencies in bond calculations
    private static let referenceDate: Date = {
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 1
        return Calendar.current.date(from: components)!
    }()

    // MARK: - Basic Price Calculation Tests

    @Test("Bond price at par - coupon rate = yield")
    func bondPriceAtPar() {
        // Given: 5% coupon bond, 5% yield, 10 years to maturity
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.05,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        // When: Price at 5% yield
        let price = bond.price(yield: 0.05, asOf: today)

        // Then: Should be at par (face value)
        #expect(abs(price - 1000.0) < 1.0)
    }

    @Test("Bond price at premium - yield < coupon rate")
    func bondPriceAtPremium() {
        // Given: 6% coupon bond, 4% yield, 10 years to maturity
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

        // When: Price at 4% yield
        let price = bond.price(yield: 0.04, asOf: today)

        // Then: Should be at premium (> face value)
        #expect(price > 1000.0)
        #expect(price < 1300.0)  // Reasonable upper bound
    }

    @Test("Bond price at discount - yield > coupon rate")
    func bondPriceAtDiscount() {
        // Given: 4% coupon bond, 6% yield, 10 years to maturity
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.04,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        // When: Price at 6% yield
        let price = bond.price(yield: 0.06, asOf: today)

        // Then: Should be at discount (< face value)
        #expect(price < 1000.0)
        #expect(price > 700.0)  // Reasonable lower bound
    }

    @Test("Bond price with annual coupons")
    func bondPriceAnnualCoupons() {
        // Given: Bond with annual coupon payments
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 5, to: today)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.05,
            maturityDate: maturity,
            paymentFrequency: .annual,
            issueDate: today
        )

        // When: Price at 5% yield
        let price = bond.price(yield: 0.05, asOf: today)

        // Then: Should be at par
        #expect(abs(price - 1000.0) < 1.0)
    }

    @Test("Bond price with quarterly coupons")
    func bondPriceQuarterlyCoupons() {
        // Given: Bond with quarterly coupon payments
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 5, to: today)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.06,
            maturityDate: maturity,
            paymentFrequency: .quarterly,
            issueDate: today
        )

        // When: Price at 6% yield
        let price = bond.price(yield: 0.06, asOf: today)

        // Then: Should be at par
        #expect(abs(price - 1000.0) < 1.0)
    }

    @Test("Bond price between coupon payments")
    func bondPriceBetweenCoupons() {
        // Given: Bond issued 6 months ago with semiannual coupons
        let calendar = Calendar.current
        let issueDate = calendar.date(byAdding: .month, value: -6, to: Date())!
        let maturityDate = calendar.date(byAdding: .year, value: 10, to: issueDate)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.05,
            maturityDate: maturityDate,
            paymentFrequency: .semiAnnual,
            issueDate: issueDate
        )

        // When: Price today (between coupon payments)
        let priceToday = bond.price(yield: 0.05)

        // Then: Should still be close to par, accounting for accrued interest
        #expect(abs(priceToday - 1000.0) < 50.0)
    }

    // MARK: - Yield to Maturity Tests

    @Test("YTM calculation - bond at par")
    func ytmAtPar() throws {
        // Given: Bond trading at par
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.05,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        // When: Calculate YTM for bond trading at $1000
        let ytm = try bond.yieldToMaturity(price: 1000.0, asOf: today)

        // Then: YTM should equal coupon rate
        #expect(abs(ytm - 0.05) < 0.001)
    }

    @Test("YTM calculation - bond at premium")
    func ytmAtPremium() throws {
        // Given: Bond trading at premium
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

        // When: Calculate YTM for bond trading at $1100
        let ytm = try bond.yieldToMaturity(price: 1100.0, asOf: today)

        // Then: YTM should be less than coupon rate
        #expect(ytm < 0.06)
        #expect(ytm > 0.04)  // Reasonable range
    }

    @Test("YTM calculation - bond at discount")
    func ytmAtDiscount() throws {
        // Given: Bond trading at discount
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.04,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        // When: Calculate YTM for bond trading at $900
        let ytm = try bond.yieldToMaturity(price: 900.0, asOf: today)

        // Then: YTM should be greater than coupon rate
        #expect(ytm > 0.04)
        #expect(ytm < 0.07)  // Reasonable range
    }

    @Test("Round-trip: Price → YTM → Price")
    func roundTripPriceYTM() throws {
        // Given: Bond with specific parameters
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.05,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        // When: Calculate price, then YTM, then price again
        let originalPrice = bond.price(yield: 0.06, asOf: today)
        let ytm = try bond.yieldToMaturity(price: originalPrice, asOf: today)
        let recalculatedPrice = bond.price(yield: ytm, asOf: today)

        // Then: Should round-trip back to original price
        #expect(abs(recalculatedPrice - originalPrice) < 0.01)
        #expect(abs(ytm - 0.06) < 0.001)
    }

    // MARK: - Current Yield Tests

    @Test("Current yield calculation")
    func currentYield() {
        // Given: Bond with 6% coupon
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

        // When: Calculate current yield at different prices
        let currentYieldAtPar = bond.currentYield(price: 1000.0)
        let currentYieldAtPremium = bond.currentYield(price: 1100.0)
        let currentYieldAtDiscount = bond.currentYield(price: 900.0)

        // Then: Current yield = Annual coupon / Price
        #expect(abs(currentYieldAtPar - 0.06) < 0.001)  // 60 / 1000 = 6%
        #expect(abs(currentYieldAtPremium - 0.0545) < 0.001)  // 60 / 1100 ≈ 5.45%
        #expect(abs(currentYieldAtDiscount - 0.0667) < 0.001)  // 60 / 900 ≈ 6.67%
    }

    // MARK: - Duration Tests

    @Test("Macaulay duration calculation")
    func macaulayDuration() {
        // Given: 5-year bond with 5% coupon
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 5, to: today)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.05,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        // When: Calculate Macaulay duration at 5% yield
        let duration = bond.macaulayDuration(yield: 0.05, asOf: today)

        // Then: Should be less than maturity (due to coupon payments)
        #expect(duration < 5.0)
        #expect(duration > 4.0)  // Typically 4.3-4.5 for this bond
    }

    @Test("Modified duration calculation")
    func modifiedDuration() {
        // Given: Bond
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.05,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        // When: Calculate modified duration
        let macDuration = bond.macaulayDuration(yield: 0.06, asOf: today)
        let modDuration = bond.modifiedDuration(yield: 0.06, asOf: today)

        // Then: Modified Duration = Macaulay Duration / (1 + y/m)
        // where y = yield, m = payments per year
        let expectedModDuration = macDuration / (1.0 + 0.06 / 2.0)
        #expect(abs(modDuration - expectedModDuration) < 0.01)
    }

    @Test("Duration as price sensitivity")
    func durationAsPriceSensitivity() {
        // Given: Bond
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.05,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        // When: Calculate price change for small yield change
        let baseYield = 0.06
        let modDuration = bond.modifiedDuration(yield: baseYield)

        let priceAt6Percent = bond.price(yield: 0.06, asOf: today)
        let priceAt6Point1Percent = bond.price(yield: 0.061, asOf: today)

        // Then: -ModDuration × ΔYield ≈ %ΔPrice
        let actualPriceChange = (priceAt6Point1Percent - priceAt6Percent) / priceAt6Percent
        let predictedPriceChange = -modDuration * 0.001

        #expect(abs(actualPriceChange - predictedPriceChange) < 0.001)
    }

    // MARK: - Convexity Tests

    @Test("Convexity calculation")
    func convexityCalculation() {
        // Given: Bond
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.05,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        // When: Calculate convexity
        let convexity = bond.convexity(yield: 0.06)

        // Then: Convexity should be positive
        #expect(convexity > 0)
        #expect(convexity < 200.0)  // Typical range for 10-year bond
    }

    @Test("Convexity improves duration approximation")
    func convexityImprovesDurationApproximation() {
        // Given: Bond
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.05,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        let baseYield = 0.06
        let modDuration = bond.modifiedDuration(yield: baseYield, asOf: today)
        let convexity = bond.convexity(yield: baseYield, asOf: today)

        // When: Calculate price change for larger yield change (1%)
        let priceAtBase = bond.price(yield: 0.06, asOf: today)
        let priceAt7Percent = bond.price(yield: 0.07, asOf: today)
        let actualPriceChange = (priceAt7Percent - priceAtBase) / priceAtBase

        // Duration-only approximation
        let durationApprox = -modDuration * 0.01

        // Duration + Convexity approximation
        let durationConvexityApprox = -modDuration * 0.01 + 0.5 * convexity * (0.01 * 0.01)

        // Then: Duration + convexity should be more accurate
        let durationError = abs(actualPriceChange - durationApprox)
        let durationConvexityError = abs(actualPriceChange - durationConvexityApprox)

        #expect(durationConvexityError < durationError)
    }

    // MARK: - Edge Cases

    @Test("Zero coupon bond approximation")
    func zeroCouponBondApproximation() {
        // Given: Bond with very low coupon (approximates zero coupon)
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.001,  // 0.1% coupon (nearly zero)
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        // When: Calculate price at 5% yield
        let price = bond.price(yield: 0.05, asOf: today)

        // Then: Should be close to zero coupon formula: FV / (1 + y)^t
        let zeroCouponPrice = 1000.0 / pow(1.05, 10.0)
        #expect(abs(price - zeroCouponPrice) < 10.0)
    }

    @Test("Short maturity bond (1 year)")
    func shortMaturityBond() {
        // Given: 1-year bond
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 1, to: today)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.05,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        // When: Price at 5% yield
        let price = bond.price(yield: 0.05, asOf: today)

        // Then: Should be at par
        #expect(abs(price - 1000.0) < 1.0)
    }

    @Test("Long maturity bond (30 years)")
    func longMaturityBond() {
        // Given: 30-year bond
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 30, to: today)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.05,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        // When: Price at 5% yield
        let price = bond.price(yield: 0.05, asOf: today)

        // Then: Should be at par
        #expect(abs(price - 1000.0) < 1.0)

        // Duration should be higher for longer maturity
        let duration = bond.macaulayDuration(yield: 0.05)
        #expect(duration > 15.0)  // Long-term bonds have high duration
    }

    // MARK: - Generic Type Tests

    @Test("Bond with Float type")
    func bondWithFloat() {
        // Given: Bond using Float
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = Bond<Float>(
            faceValue: 1000.0,
            couponRate: 0.05,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        // When: Price at 5% yield
        let price = bond.price(yield: 0.05, asOf: today)

        // Then: Should work with Float
        #expect(abs(price - 1000.0) < 1.0)
    }

    // MARK: - Comparison Tests

    @Test("Higher coupon → higher price (same yield)")
    func higherCouponHigherPrice() {
        // Given: Two bonds, same maturity and yield, different coupons
        let calendar = Calendar.current
        let today = Self.referenceDate
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let lowCouponBond = Bond(
            faceValue: 1000.0,
            couponRate: 0.04,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        let highCouponBond = Bond(
            faceValue: 1000.0,
            couponRate: 0.06,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        // When: Price both at 5% yield
        let lowPrice = lowCouponBond.price(yield: 0.05, asOf: today)
        let highPrice = highCouponBond.price(yield: 0.05, asOf: today)

        // Then: Higher coupon should have higher price
        #expect(highPrice > lowPrice)
    }

    @Test("Longer maturity → higher duration")
    func longerMaturityHigherDuration() {
        // Given: Two bonds, same coupon, different maturities
        let calendar = Calendar.current
        let today = Self.referenceDate
        let shortMaturity = calendar.date(byAdding: .year, value: 5, to: today)!
        let longMaturity = calendar.date(byAdding: .year, value: 20, to: today)!

        let shortBond = Bond(
            faceValue: 1000.0,
            couponRate: 0.05,
            maturityDate: shortMaturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        let longBond = Bond(
            faceValue: 1000.0,
            couponRate: 0.05,
            maturityDate: longMaturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        // When: Calculate duration at same yield
        let shortDuration = shortBond.macaulayDuration(yield: 0.05)
        let longDuration = longBond.macaulayDuration(yield: 0.05)

        // Then: Longer maturity should have higher duration
        #expect(longDuration > shortDuration)
    }
}

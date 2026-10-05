//
//  ZeroDivisorRefusalTests.swift
//  BusinessMath
//
//  Public functions that divided by a parameter nobody had checked. Each returned a
//  figure for a divisor of zero — an infinite share count, an infinite depreciation
//  charge — and a figure is an answer. These pin the refusal, and beside each one the
//  sound input it must leave exactly where it was.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Zero divisors are refused, not answered")
struct ZeroDivisorRefusalTests {

    // MARK: - Black-Scholes (`bs`)

    /// The price before the guard, pinned so the guard is shown not to move it.
    @Test("BlackScholes_SoundInputs_Unchanged") func blackScholesSoundInputsUnchanged() {
        let price = bs(stockPrice: 100, strikePrice: 100, timeToExpiration: 1,
                       riskFreeRate: 0.05, volatility: 0.2)
        // Hull, *Options, Futures and Other Derivatives*: S = K = 100, r = 5%, σ = 20%, T = 1.
        #expect(abs(price - 10.4506) < 1e-3)
    }

    /// `log(S / 0)` is `+inf`; the function then reported the stock price itself.
    @Test("BlackScholes_ZeroStrike_IsNaN") func blackScholesZeroStrikeIsNaN() {
        let price = bs(stockPrice: 100, strikePrice: 0, timeToExpiration: 1,
                       riskFreeRate: 0.05, volatility: 0.2)
        #expect(price.isNaN)
    }

    @Test("BlackScholes_NegativeStrike_IsNaN") func blackScholesNegativeStrikeIsNaN() {
        let price = bs(stockPrice: 100, strikePrice: -50, timeToExpiration: 1,
                       riskFreeRate: 0.05, volatility: 0.2)
        #expect(price.isNaN)
    }

    // MARK: - Anti-dilution

    @Test("AntiDilution_SoundPrices_Unchanged") func antiDilutionSoundPricesUnchanged() {
        let ratchet = applyAntiDilution(originalShares: 5_000_000, originalPrice: 2.0,
                                        newPrice: 1.0, type: .fullRatchet)
        #expect(abs(ratchet - 10_000_000) < 1e-6)
        let weighted = applyAntiDilution(originalShares: 5_000_000, originalPrice: 2.0,
                                         newPrice: 1.0, type: .weightedAverage)
        #expect(abs(weighted - 7_500_000) < 1e-6)
    }

    /// A round priced at zero has no conversion ratio. Both branches returned `+inf` shares.
    @Test("AntiDilution_ZeroNewPrice_IsNaN", arguments: [true, false])
    func antiDilutionZeroNewPriceIsNaN(fullRatchet: Bool) {
        let type: AntiDilutionType = fullRatchet ? .fullRatchet : .weightedAverage
        let shares = applyAntiDilution(originalShares: 5_000_000, originalPrice: 2.0,
                                       newPrice: 0.0, type: type)
        #expect(shares.isNaN)
    }

    /// A negative price returned a negative share count — finite, and so more plausible
    /// than the infinity.
    @Test("AntiDilution_NegativeNewPrice_IsNaN", arguments: [true, false])
    func antiDilutionNegativeNewPriceIsNaN(fullRatchet: Bool) {
        let type: AntiDilutionType = fullRatchet ? .fullRatchet : .weightedAverage
        let shares = applyAntiDilution(originalShares: 5_000_000, originalPrice: 2.0,
                                       newPrice: -1.0, type: type)
        #expect(shares.isNaN)
    }

    // MARK: - Lease

    private static let anyPeriod = Period.year(2025)

    @Test("Lease_Depreciation_SoundLease_Unchanged") func leaseDepreciationSoundLeaseUnchanged() {
        let lease = Lease(payments: [1_000, 1_000, 1_000, 1_000], discountRate: 0.0)
        // No discounting, no costs: a 4,000 asset over four periods.
        #expect(abs(lease.depreciation(period: Self.anyPeriod) - 1_000) < 1e-9)
    }

    /// No payments is no term to spread the asset over. With direct costs capitalised the
    /// charge came back `+inf`.
    @Test("Lease_Depreciation_NoPayments_IsNaN") func leaseDepreciationNoPaymentsIsNaN() {
        let lease = Lease(payments: [], discountRate: 0.05, initialDirectCosts: 500)
        #expect(lease.depreciation(period: Self.anyPeriod).isNaN)
    }

    /// The carrying value of a lease with no schedule is the asset as first recognised —
    /// the answer this function already gave, and still must.
    @Test("Lease_CarryingValue_NoPayments_IsInitialAsset") func leaseCarryingValueNoPayments() {
        let lease = Lease(payments: [], discountRate: 0.05, initialDirectCosts: 500)
        #expect(abs(lease.carryingValue(period: Self.anyPeriod) - 500) < 1e-9)
    }
}

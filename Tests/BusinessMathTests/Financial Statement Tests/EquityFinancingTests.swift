import Testing
import Foundation
@testable import BusinessMath

/// Comprehensive tests for equity financing, cap tables, and dilution analysis
@Suite("Equity Financing Tests")
struct EquityFinancingTests {

    // MARK: - Basic Cap Table

    @Test("Cap table creation - single founder")
    func capTableSingleFounder() throws {
        let founder = CapTable.Shareholder(
            name: "Alice",
            shares: 10_000_000.0,
            investmentDate: Date(timeIntervalSince1970: 0),
            pricePerShare: 0.001
        )

        let capTable = CapTable(
            shareholders: [founder],
            optionPool: 0.0
        )

        let ownership = capTable.ownership()

        // Alice owns 100%
        #expect(abs(ownership["Alice"]! - 1.0) < 0.0001)
    }

    @Test("Cap table - multiple founders")
    func capTableMultipleFounders() throws {
        let alice = CapTable.Shareholder(
            name: "Alice",
            shares: 6_000_000.0,
            investmentDate: Date(timeIntervalSince1970: 0),
            pricePerShare: 0.001
        )

        let bob = CapTable.Shareholder(
            name: "Bob",
            shares: 4_000_000.0,
            investmentDate: Date(timeIntervalSince1970: 0),
            pricePerShare: 0.001
        )

        let capTable = CapTable(
            shareholders: [alice, bob],
            optionPool: 0.0
        )

        let ownership = capTable.ownership()

        // Alice: 60%, Bob: 40%
        #expect(abs(ownership["Alice"]! - 0.6) < 0.0001)
        #expect(abs(ownership["Bob"]! - 0.4) < 0.0001)
    }

    @Test("Cap table with option pool")
    func capTableWithOptionPool() throws {
        let founder = CapTable.Shareholder(
            name: "Founder",
            shares: 9_000_000.0,
            investmentDate: Date(timeIntervalSince1970: 0),
            pricePerShare: 0.001
        )

        // 1M shares reserved for options (10% of total)
        let capTable = CapTable(
            shareholders: [founder],
            optionPool: 1_000_000.0
        )

        let ownership = capTable.ownership()

        // Founder: 90%, Option Pool: 10%
        #expect(abs(ownership["Founder"]! - 0.9) < 0.0001)
        #expect(abs(capTable.optionPoolPercentage - 0.1) < 0.0001)
    }

    // MARK: - Financing Rounds

    @Test("Series A - basic dilution")
    func seriesABasicDilution() throws {
        let founder = CapTable.Shareholder(
            name: "Founder",
            shares: 10_000_000.0,
            investmentDate: Date(timeIntervalSince1970: 0),
            pricePerShare: 0.001
        )

        let preRound = CapTable(
            shareholders: [founder],
            optionPool: 0.0
        )

        // $5M investment at $15M pre-money valuation
        // Post-money = $20M
        // Investor gets 25% (5/20)
        let postRound = preRound.modelRound(
            newInvestment: 5_000_000.0,
            preMoneyValuation: 15_000_000.0,
            optionPoolIncrease: 0.0
        )

        let postOwnership = postRound.ownership()

        // Founder diluted to 75%
        #expect(abs(postOwnership["Founder"]! - 0.75) < 0.01)

        // Investor owns 25%
        #expect(abs(postOwnership["Series A Investor"]! - 0.25) < 0.01)
    }

    @Test("Series A with option pool expansion")
    func seriesAWithOptionPool() throws {
        let founder = CapTable.Shareholder(
            name: "Founder",
            shares: 10_000_000.0,
            investmentDate: Date(timeIntervalSince1970: 0),
            pricePerShare: 0.001
        )

        let preRound = CapTable(
            shareholders: [founder],
            optionPool: 0.0
        )

        // $5M at $15M pre-money, adding 10% option pool
        let postRound = preRound.modelRound(
            newInvestment: 5_000_000.0,
            preMoneyValuation: 15_000_000.0,
            optionPoolIncrease: 0.10 // 10% post-money option pool
        )

        let postOwnership = postRound.ownership()

        // Founder: diluted by both investment and option pool
        // Should be around 67.5% (75% of 90%)
        #expect(postOwnership["Founder"]! < 0.75)
        #expect(postOwnership["Founder"]! > 0.65)

        // Option pool: 10%
        #expect(abs(postRound.optionPoolPercentage - 0.10) < 0.01)
    }

    @Test("Multiple financing rounds")
    func multipleFinancingRounds() throws {
        // Seed round
        let founder = CapTable.Shareholder(
            name: "Founder",
            shares: 10_000_000.0,
            investmentDate: Date(timeIntervalSince1970: 0),
            pricePerShare: 0.001
        )

        var capTable = CapTable(
            shareholders: [founder],
            optionPool: 0.0
        )

        // Seed: $1M at $4M pre-money
        capTable = capTable.modelRound(
            newInvestment: 1_000_000.0,
            preMoneyValuation: 4_000_000.0,
            optionPoolIncrease: 0.10
        )

        let postSeed = capTable.ownership()["Founder"]!

        // Series A: $5M at $15M pre-money
        capTable = capTable.modelRound(
            newInvestment: 5_000_000.0,
            preMoneyValuation: 15_000_000.0,
            optionPoolIncrease: 0.05
        )

        let postSeriesA = capTable.ownership()["Founder"]!

        // Founder should be diluted through both rounds
        #expect(postSeriesA < postSeed)
        #expect(postSeed < 1.0)
    }

    // MARK: - Pre-Money vs Post-Money

    @Test("Pre-money valuation calculation")
    func preMoneyValuation() throws {
        let capTable = CapTable(
            shareholders: [
                CapTable.Shareholder(
                    name: "Founder",
                    shares: 10_000_000.0,
                    investmentDate: Date(timeIntervalSince1970: 0),
                    pricePerShare: 1.50
                )
            ],
            optionPool: 0.0
        )

        let preMoney = capTable.preMoneyValuation()

        // 10M shares * $1.50 = $15M
        #expect(abs(preMoney - 15_000_000.0) < 1.0)
    }

    @Test("Post-money valuation after round")
    func postMoneyValuation() throws {
        let founder = CapTable.Shareholder(
            name: "Founder",
            shares: 10_000_000.0,
            investmentDate: Date(timeIntervalSince1970: 0),
            pricePerShare: 0.001
        )

        let preRound = CapTable(
            shareholders: [founder],
            optionPool: 0.0
        )

        let postRound = preRound.modelRound(
            newInvestment: 5_000_000.0,
            preMoneyValuation: 15_000_000.0,
            optionPoolIncrease: 0.0
        )

        let postMoney = postRound.postMoneyValuation()

        // Should be pre-money + investment = $20M
        #expect(abs(postMoney - 20_000_000.0) < 1.0)
    }

    @Test("Price per share calculation")
    func pricePerShareCalculation() throws {
        let preMoneyValuation = 10_000_000.0
        let fullyDilutedShares = 10_000_000.0

        let pricePerShare = preMoneyValuation / fullyDilutedShares

        #expect(abs(pricePerShare - 1.0) < 0.01)
    }

    // MARK: - Option Pool Dilution

    @Test("Option pool dilution - pre-round timing")
    func optionPoolPreRoundTiming() throws {
        let currentShares = 10_000_000.0
        let optionPoolPercent = 0.10

        let dilution = optionPoolDilution(
            currentShares: currentShares,
            optionPoolPercent: optionPoolPercent,
            timing: .preRound
        )

        // 10% pool created before valuation
        // Founders diluted to 90%
        #expect(abs(dilution - 0.10) < 0.01)
    }

    @Test("Option pool dilution - post-round timing")
    func optionPoolPostRoundTiming() throws {
        let currentShares = 10_000_000.0
        let optionPoolPercent = 0.10

        let dilution = optionPoolDilution(
            currentShares: currentShares,
            optionPoolPercent: optionPoolPercent,
            timing: .postRound
        )

        // 10% pool created after valuation
        // All shareholders diluted proportionally
        #expect(abs(dilution - 0.10) < 0.01)
    }

    @Test("Option pool - pre vs post timing impact")
    func optionPoolTimingImpact() throws {
        let founder = CapTable.Shareholder(
            name: "Founder",
            shares: 10_000_000.0,
            investmentDate: Date(timeIntervalSince1970: 0),
            pricePerShare: 0.001
        )

        // Pre-round option pool
        let preRoundPool = CapTable(
            shareholders: [founder],
            optionPool: 0.0
        ).modelRound(
            newInvestment: 5_000_000.0,
            preMoneyValuation: 15_000_000.0,
            optionPoolIncrease: 0.10,
            poolTiming: .preRound
        )

        // Post-round option pool
        let postRoundPool = CapTable(
            shareholders: [founder],
            optionPool: 0.0
        ).modelRound(
            newInvestment: 5_000_000.0,
            preMoneyValuation: 15_000_000.0,
            optionPoolIncrease: 0.10,
            poolTiming: .postRound
        )

        // Pre-round timing dilutes founders more
        let preOwnership = preRoundPool.ownership()["Founder"]!
        let postOwnership = postRoundPool.ownership()["Founder"]!

        #expect(preOwnership < postOwnership)
    }

    // MARK: - Fully Diluted Shares

    @Test("Fully diluted share count")
    func fullyDilutedShares() throws {
        let capTable = CapTable(
            shareholders: [
                CapTable.Shareholder(
                    name: "Founder",
                    shares: 9_000_000.0,
                    investmentDate: Date(timeIntervalSince1970: 0),
                    pricePerShare: 0.001
                )
            ],
            optionPool: 1_000_000.0
        )

        let fullyDiluted = capTable.fullyDilutedShares()

        // 9M + 1M = 10M
        #expect(abs(fullyDiluted - 10_000_000.0) < 1.0)
    }

    @Test("Outstanding shares vs fully diluted")
    func outstandingVsFullyDiluted() throws {
        let capTable = CapTable(
            shareholders: [
                CapTable.Shareholder(
                    name: "Founder",
                    shares: 9_000_000.0,
                    investmentDate: Date(timeIntervalSince1970: 0),
                    pricePerShare: 0.001
                )
            ],
            optionPool: 1_000_000.0
        )

        let outstanding = capTable.outstandingShares()
        let fullyDiluted = capTable.fullyDilutedShares()

        // Outstanding = 9M, Fully Diluted = 10M
        #expect(outstanding < fullyDiluted)
        #expect(abs(outstanding - 9_000_000.0) < 1.0)
    }

    // MARK: - Waterfall Analysis

    @Test("Liquidation preference - 1x non-participating")
    func liquidationPreference1xNonParticipating() throws {
        // Investor put in $5M with 1x liquidation preference
        let investor = CapTable.Shareholder(
            name: "Investor",
            shares: 5_000_000.0,
            investmentDate: Date(timeIntervalSince1970: 0),
            pricePerShare: 1.0,
            liquidationPreference: 1.0,
            participating: false
        )

        let founder = CapTable.Shareholder(
            name: "Founder",
            shares: 15_000_000.0,
            investmentDate: Date(timeIntervalSince1970: 0),
            pricePerShare: 0.001
        )

        let capTable = CapTable(
            shareholders: [founder, investor],
            optionPool: 0.0
        )

        // Exit at $10M
        let waterfall = capTable.liquidationWaterfall(exitValue: 10_000_000.0)

        // Investor gets $5M (preference)
        // Remaining $5M split: Founder 75% = $3.75M, Investor 25% = $1.25M
        // But investor takes preference ($5M) > pro-rata ($2.5M)
        // So: Investor: $5M, Founder: $5M

        #expect(abs(waterfall["Investor"]! - 5_000_000.0) < 1000.0)
        #expect(abs(waterfall["Founder"]! - 5_000_000.0) < 1000.0)
    }

    @Test("Liquidation preference - 1x participating")
    func liquidationPreference1xParticipating() throws {
        // Investor gets preference + participation
        let investor = CapTable.Shareholder(
            name: "Investor",
            shares: 5_000_000.0,
            investmentDate: Date(timeIntervalSince1970: 0),
            pricePerShare: 1.0,
            liquidationPreference: 1.0,
            participating: true
        )

        let founder = CapTable.Shareholder(
            name: "Founder",
            shares: 15_000_000.0,
            investmentDate: Date(timeIntervalSince1970: 0),
            pricePerShare: 0.001
        )

        let capTable = CapTable(
            shareholders: [founder, investor],
            optionPool: 0.0
        )

        // Exit at $10M
        let waterfall = capTable.liquidationWaterfall(exitValue: 10_000_000.0)

        // Investor gets $5M preference first
        // Then $5M remaining split 25/75: Investor $1.25M, Founder $3.75M
        // Total: Investor $6.25M, Founder $3.75M

        #expect(abs(waterfall["Investor"]! - 6_250_000.0) < 1000.0)
        #expect(abs(waterfall["Founder"]! - 3_750_000.0) < 1000.0)
    }

    @Test("Liquidation preference - 2x preference")
    func liquidationPreference2x() throws {
        // Investor gets 2x their money back first
        let investor = CapTable.Shareholder(
            name: "Investor",
            shares: 5_000_000.0,
            investmentDate: Date(timeIntervalSince1970: 0),
            pricePerShare: 1.0,
            liquidationPreference: 2.0,
            participating: false
        )

        let founder = CapTable.Shareholder(
            name: "Founder",
            shares: 15_000_000.0,
            investmentDate: Date(timeIntervalSince1970: 0),
            pricePerShare: 0.001
        )

        let capTable = CapTable(
            shareholders: [founder, investor],
            optionPool: 0.0
        )

        // Exit at $15M
        let waterfall = capTable.liquidationWaterfall(exitValue: 15_000_000.0)

        // Investor gets $10M (2x $5M)
        // Founder gets $5M

        #expect(abs(waterfall["Investor"]! - 10_000_000.0) < 1000.0)
        #expect(abs(waterfall["Founder"]! - 5_000_000.0) < 1000.0)
    }

    @Test("Down round - pay-to-play protection")
    func downRoundPayToPlay() throws {
        // Original investor at $10M valuation
        let investor = CapTable.Shareholder(
            name: "Series A",
            shares: 5_000_000.0,
            investmentDate: Date(timeIntervalSince1970: 0),
            pricePerShare: 2.0
        )

        let founder = CapTable.Shareholder(
            name: "Founder",
            shares: 15_000_000.0,
            investmentDate: Date(timeIntervalSince1970: 0),
            pricePerShare: 0.001
        )

        var capTable = CapTable(
            shareholders: [founder, investor],
            optionPool: 0.0
        )

        // Down round at $5M valuation
        capTable = capTable.modelDownRound(
            newInvestment: 2_000_000.0,
            preMoneyValuation: 5_000_000.0,
            payToPlayParticipants: [] // Series A doesn't participate
        )

        // Series A should be diluted significantly
        let postOwnership = capTable.ownership()

        #expect(postOwnership["Series A"]! < 0.25)
    }

    // MARK: - Employee Option Grants

    @Test("Employee option grant from pool")
    func employeeOptionGrant() throws {
        let founder = CapTable.Shareholder(
            name: "Founder",
            shares: 9_000_000.0,
            investmentDate: Date(timeIntervalSince1970: 0),
            pricePerShare: 0.001
        )

        var capTable = CapTable(
            shareholders: [founder],
            optionPool: 1_000_000.0
        )

        // Grant 100,000 options to employee
        capTable = capTable.grantOptions(
            recipient: "Employee",
            shares: 100_000.0,
            strikePrice: 1.0
        )

        // Option pool reduced by 100k
        #expect(abs(capTable.optionPool - 900_000.0) < 1.0)

        // Employee now in cap table with unvested options
        let ownership = capTable.ownership()
        #expect(ownership["Employee"] != nil)
    }

    @Test("Vesting schedule - 4 year with 1 year cliff")
    func vestingSchedule() throws {
        let grant = OptionGrant(
            recipient: "Employee",
            shares: 48_000.0,
            grantDate: Date(timeIntervalSince1970: 0),
            vestingSchedule: .standard // 4 year, 1 year cliff, monthly thereafter
        )

        // After 6 months - no vesting (cliff not reached)
        let sixMonths = Date(timeIntervalSince1970: 15_768_000) // ~6 months
        let vestedAtSix = grant.vestedShares(at: sixMonths)
        #expect(abs(vestedAtSix) < 1.0)

        // After 12 months - 25% vested (cliff reached)
        let twelveMonths = Date(timeIntervalSince1970: 31_536_000) // ~1 year
        let vestedAtTwelve = grant.vestedShares(at: twelveMonths)
        #expect(abs(vestedAtTwelve - 12_000.0) < 1.0)

        // After 24 months - 50% vested
        let twentyFourMonths = Date(timeIntervalSince1970: 63_072_000) // ~2 years
        let vestedAtTwentyFour = grant.vestedShares(at: twentyFourMonths)
        #expect(abs(vestedAtTwentyFour - 24_000.0) < 1.0)

        // After 48 months - 100% vested
        let fortyEightMonths = Date(timeIntervalSince1970: 126_144_000) // ~4 years
        let vestedAtFortyEight = grant.vestedShares(at: fortyEightMonths)
        #expect(abs(vestedAtFortyEight - 48_000.0) < 1.0)
    }

    // MARK: - Valuation Metrics

    @Test("Valuation per share")
    func valuationPerShare() throws {
        let capTable = CapTable(
            shareholders: [
                CapTable.Shareholder(
                    name: "Founder",
                    shares: 10_000_000.0,
                    investmentDate: Date(timeIntervalSince1970: 0),
                    pricePerShare: 1.50
                )
            ],
            optionPool: 0.0
        )

        let pricePerShare = capTable.currentPricePerShare()

        #expect(abs(pricePerShare - 1.50) < 0.01)
    }

    @Test("409A valuation - common stock")
    func valuation409A() throws {
        // Preferred stock priced at $2.00
        // Common stock typically 10-30% of preferred price
        let preferredPrice = 2.0
        let commonPrice = calculate409APrice(
            preferredPrice: preferredPrice,
            discount: 0.25 // 25% discount
        )

        // Common should be $1.50
        let expected = 1.50
        #expect(abs(commonPrice - expected) < 0.01)
    }

    // MARK: - Anti-Dilution Protection

    @Test("Anti-dilution - full ratchet")
    func antiDilutionFullRatchet() throws {
        // Original round: 5M shares at $2.00
        let originalInvestor = CapTable.Shareholder(
            name: "Series A",
            shares: 5_000_000.0,
            investmentDate: Date(timeIntervalSince1970: 0),
            pricePerShare: 2.0,
            antiDilution: .fullRatchet
        )

        // Down round at $1.00 per share
        let downRoundPrice = 1.0

        let adjustedShares = applyAntiDilution(
            originalShares: originalInvestor.shares,
            originalPrice: originalInvestor.pricePerShare,
            newPrice: downRoundPrice,
            type: .fullRatchet
        )

        // Full ratchet: doubles shares (10M shares at $1.00 = $10M value maintained)
        #expect(abs(adjustedShares - 10_000_000.0) < 1.0)
    }

    @Test("Anti-dilution - weighted average")
    func antiDilutionWeightedAverage() throws {
        let originalShares = 5_000_000.0
        let originalPrice = 2.0
        let downRoundPrice = 1.0
        let downRoundShares = 2_000_000.0
        let fullyDilutedBeforeRound = 20_000_000.0

        let adjustedShares = applyWeightedAverageAntiDilution(
            originalShares: originalShares,
            originalPrice: originalPrice,
            newPrice: downRoundPrice,
            newShares: downRoundShares,
            fullyDilutedBefore: fullyDilutedBeforeRound
        )

        // Weighted average less punitive than full ratchet
        #expect(adjustedShares > originalShares)
        #expect(adjustedShares < 10_000_000.0) // Less than full ratchet
    }

    // MARK: - Convertible Notes

    @Test("Convertible note conversion - with cap")
    func convertibleNoteWithCap() throws {
        let noteAmount = 500_000.0
        let valuationCap = 5_000_000.0
        let discount = 0.20
        let seriesAPrice = 2.0

        let conversion = convertNote(
            principal: noteAmount,
            valuationCap: valuationCap,
            discount: discount,
            seriesAPricePerShare: seriesAPrice
        )

        // Cap price: $5M / shares vs. discounted price
        // Noteholder gets better of cap or discount
        #expect(conversion.sharesIssued > 0)
        #expect(conversion.effectivePrice <= seriesAPrice)
    }

    @Test("Convertible note - cap vs discount")
    func convertibleNoteCapVsDiscount() throws {
        let noteAmount = 1_000_000.0
        let valuationCap = 8_000_000.0
        let discount = 0.20
        let seriesAValuation = 20_000_000.0
        let seriesAPrice = 2.0

        let conversion = convertNote(
            principal: noteAmount,
            valuationCap: valuationCap,
            discount: discount,
            seriesAPricePerShare: seriesAPrice
        )

        // Cap gives better deal when Series A valuation > cap
        // Discounted price = $2.00 * 0.8 = $1.60
        // Cap price = $8M valuation price (likely < $1.60)
        // Should use cap
        #expect(conversion.appliedTerm == .cap)
    }

    // MARK: - SAFE (Simple Agreement for Future Equity)

    @Test("SAFE conversion - post-money")
    func safeConversionPostMoney() throws {
        let safeAmount = 500_000.0
        let postMoneyCap = 10_000_000.0

        let safe = SAFE(
            investment: safeAmount,
            postMoneyCap: postMoneyCap,
            type: .postMoney
        )

        let conversion = safe.convert(seriesAValuation: 20_000_000.0)

        // SAFE holder gets: $500k / $10M = 5% of post-money cap
        #expect(abs(conversion.ownershipPercent - 0.05) < 0.001)
    }

    @Test("SAFE vs Convertible Note")
    func safeVsConvertibleNote() throws {
        let investment = 500_000.0
        let cap = 10_000_000.0
        let seriesAValuation = 20_000_000.0

        // SAFE (no discount, no interest)
        let safe = SAFE(
            investment: investment,
            postMoneyCap: cap,
            type: .postMoney
        )
        let safeConversion = safe.convert(seriesAValuation: seriesAValuation)

        // Convertible note (no discount, no interest for simplicity)
        let note = convertNote(
            principal: investment,
            valuationCap: cap,
            discount: 0.0,
            seriesAPricePerShare: 2.0,
            interestRate: 0.0,
            timeHeld: 0.0
        )

        // Both should give similar ownership
        #expect(abs(safeConversion.ownershipPercent - note.ownershipPercent) < 0.01)
    }
}

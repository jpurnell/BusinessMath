//
//  WaterfallBuilderTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-29.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath
@testable import BusinessMathDSL

/// Tests for Waterfall Distribution Result Builder
///
/// Following TDD:
/// - RED: Write failing tests first
/// - GREEN: Implement to make tests pass
/// - REFACTOR: Clean up implementation
@Suite("Waterfall Distribution Builder Tests")
struct WaterfallBuilderTests {

    // MARK: - Basic Tier Tests

    @Test("Single tier with capital return only")
    func singleTierCapitalReturn() async throws {
        let waterfall = LiquidationWaterfall {
            Tier("Senior Debt", priority: 1) {
                CapitalReturn(500_000)
            }
        }

        // Insufficient proceeds - partial return
        let result1 = waterfall.distribute(300_000)
        #expect(result1.distributions.count == 1)
        #expect(result1.distributions["Senior Debt"] == 300_000)
        #expect(result1.remaining == 0)

        // Exact proceeds - full return
        let result2 = waterfall.distribute(500_000)
        #expect(result2.distributions["Senior Debt"] == 500_000)
        #expect(result2.remaining == 0)

        // Excess proceeds - overflow to residual
        let result3 = waterfall.distribute(700_000)
        #expect(result3.distributions["Senior Debt"] == 500_000)
        #expect(result3.remaining == 200_000)
    }

    @Test("Tier with capital and preferred return")
    func tierWithPreferredReturn() async throws {
        let waterfall = LiquidationWaterfall {
            Tier("Preferred Equity", priority: 1) {
                CapitalReturn(1_000_000)
                PreferredReturn(0.08, years: 3)  // 8% for 3 years
            }
        }

        // Total required: 1M capital + 240k preferred (8% * 3 years) = 1,240,000
        let result = waterfall.distribute(1_240_000)
        #expect(result.distributions["Preferred Equity"] == 1_240_000)
        #expect(result.remaining == 0)

        // Partial - only capital returned
        let partialResult = waterfall.distribute(800_000)
        #expect(partialResult.distributions["Preferred Equity"] == 800_000)
        #expect(partialResult.remaining == 0)

        // Excess - overflow
        let excessResult = waterfall.distribute(1_500_000)
        #expect(excessResult.distributions["Preferred Equity"] == 1_240_000)
        #expect(excessResult.remaining == 260_000)
    }

    // MARK: - Multiple Tier Tests

    @Test("Two tiers in priority order")
    func twoTierWaterfall() async throws {
        let waterfall = LiquidationWaterfall {
            Tier("Senior Debt", priority: 1) {
                CapitalReturn(500_000)
            }
            Tier("Preferred Equity", priority: 2) {
                CapitalReturn(300_000)
            }
        }

        // Only enough for senior debt
        let result1 = waterfall.distribute(400_000)
        #expect(result1.distributions["Senior Debt"] == 400_000)
        #expect(result1.distributions["Preferred Equity"] == 0)

        // Enough for senior, partial preferred
        let result2 = waterfall.distribute(700_000)
        #expect(result2.distributions["Senior Debt"] == 500_000)
        #expect(result2.distributions["Preferred Equity"] == 200_000)

        // Enough for both
        let result3 = waterfall.distribute(900_000)
        #expect(result3.distributions["Senior Debt"] == 500_000)
        #expect(result3.distributions["Preferred Equity"] == 300_000)
        #expect(result3.remaining == 100_000)
    }

    @Test("Three tier waterfall with preferred returns")
    func threeTierWithPreferred() async throws {
        let waterfall = LiquidationWaterfall {
            Tier("Senior Debt", priority: 1) {
                CapitalReturn(500_000)
                PreferredReturn(0.12, years: 2)  // 120k
            }
            Tier("Preferred Equity", priority: 2) {
                CapitalReturn(300_000)
                PreferredReturn(0.15, years: 2)  // 90k
            }
            Tier("Common Equity", priority: 3) {
                CapitalReturn(200_000)
            }
        }

        // Total: 500k + 120k + 300k + 90k + 200k = 1,210,000
        let fullResult = waterfall.distribute(1_210_000)
        #expect(fullResult.distributions["Senior Debt"] == 620_000)
        #expect(fullResult.distributions["Preferred Equity"] == 390_000)
        #expect(fullResult.distributions["Common Equity"] == 200_000)
        #expect(fullResult.remaining == 0)

        // Partial - only covers first tier
        let partialResult = waterfall.distribute(600_000)
        #expect(partialResult.distributions["Senior Debt"] == 600_000)
        #expect(partialResult.distributions["Preferred Equity"] == 0)
        #expect(partialResult.distributions["Common Equity"] == 0)
    }

    // MARK: - Catch-Up Tests

    @Test("GP catch-up after preferred return")
    func catchUpProvision() async throws {
        let waterfall = LiquidationWaterfall {
            Tier("LP Capital + Preferred", priority: 1) {
                CapitalReturn(1_000_000)
                PreferredReturn(0.08, years: 3)  // 240k
            }
            Tier("GP Catch-Up", priority: 2) {
                CatchUp(to: 0.20)  // GP gets 20% of total profits
            }
            Tier("Residual", priority: 3) {
                ProRata([
                    ("LP", 0.80),
                    ("GP", 0.20)
                ])
            }
        }

        // Scenario: $2M distribution
        // LP gets: 1M capital + 240k preferred = 1,240,000
        // Remaining: 760k
        // Catch-up brings GP to 20% of profits distributed so far ($240k LP preferred)
        // Total profits for ratio: $240k / 0.80 = $300k
        // GP needs: $300k * 0.20 = $60k catch-up
        // After catch-up: $760k - $60k = $700k residual
        // Residual split 80/20: LP $560k, GP $140k
        // Final: LP $800k profit (80%), GP $200k profit (20%)

        let result = waterfall.distribute(2_000_000)
        #expect(result.distributions["LP Capital + Preferred"] == 1_240_000)
        #expect(result.distributions["GP Catch-Up"] == 60_000)

        // Residual should be split 80/20
        let lpTotal = (result.distributions["LP"] ?? 0) + 1_240_000
        let gpTotal = (result.distributions["GP"] ?? 0) + 60_000

        // Verify final split is approximately 80/20 on profits
        let totalProfits = 2_000_000.0 - 1_000_000.0  // 1M in profits
        let gpProfits = gpTotal - 0  // GP had no capital
        let lpProfits = lpTotal - 1_000_000  // LP capital return

        #expect(abs(gpProfits / totalProfits - 0.20) < 0.01)
        #expect(abs(lpProfits / totalProfits - 0.80) < 0.01)
    }

    // MARK: - Pro-Rata Tests

    @Test("Pro-rata split in residual tier")
    func proRataSplit() async throws {
        let waterfall = LiquidationWaterfall {
            Tier("Capital Return", priority: 1) {
                CapitalReturn(1_000_000)
            }
            Tier("Residual", priority: 2) {
                ProRata([
                    ("LP", 0.70),
                    ("GP", 0.30)
                ])
            }
        }

        let result = waterfall.distribute(2_000_000)
        #expect(result.distributions["Capital Return"] == 1_000_000)

        // Remaining 1M split 70/30
        #expect(result.distributions["LP"] == 700_000)
        #expect(result.distributions["GP"] == 300_000)
        #expect(result.remaining == 0)
    }

    @Test("Multiple participants in pro-rata")
    func multiParticipantProRata() async throws {
        let waterfall = LiquidationWaterfall {
            Tier("Distribution", priority: 1) {
                ProRata([
                    ("Investor A", 0.40),
                    ("Investor B", 0.35),
                    ("Investor C", 0.25)
                ])
            }
        }

        let result = waterfall.distribute(1_000_000)
        #expect(result.distributions["Investor A"] == 400_000)
        #expect(result.distributions["Investor B"] == 350_000)
        #expect(result.distributions["Investor C"] == 250_000)
        #expect(result.remaining == 0)
    }

    // MARK: - Residual Tests

    @Test("Residual captures all remaining")
    func residualCapture() async throws {
        let waterfall = LiquidationWaterfall {
            Tier("Senior", priority: 1) {
                CapitalReturn(500_000)
            }
            Tier("Junior", priority: 2) {
                Residual()
            }
        }

        let result = waterfall.distribute(1_000_000)
        #expect(result.distributions["Senior"] == 500_000)
        #expect(result.distributions["Junior"] == 500_000)
        #expect(result.remaining == 0)
    }

    // MARK: - Complex Integration Tests

    @Test("Complete waterfall with all components")
    func completeWaterfall() async throws {
        let waterfall = LiquidationWaterfall {
            Tier("Senior Debt", priority: 1) {
                CapitalReturn(500_000)
                PreferredReturn(0.12, years: 2)  // 120k
            }
            Tier("Mezzanine Debt", priority: 2) {
                CapitalReturn(300_000)
                PreferredReturn(0.15, years: 2)  // 90k
            }
            Tier("Preferred Equity", priority: 3) {
                CapitalReturn(200_000)
                PreferredReturn(0.20, years: 2)  // 80k
            }
            Tier("Common Equity", priority: 4) {
                Residual()
            }
        }

        // Low proceeds - only senior debt gets partial
        let low = waterfall.distribute(300_000)
        #expect(low.distributions["Senior Debt"] == 300_000)
        #expect(low.remaining == 0)

        // Medium proceeds - senior fully paid, mezzanine partial
        let medium = waterfall.distribute(800_000)
        #expect(medium.distributions["Senior Debt"] == 620_000)
        #expect(medium.distributions["Mezzanine Debt"] == 180_000)

        // High proceeds - all tiers satisfied, residual to common
        let high = waterfall.distribute(2_000_000)
        #expect(high.distributions["Senior Debt"] == 620_000)
        #expect(high.distributions["Mezzanine Debt"] == 390_000)
        #expect(high.distributions["Preferred Equity"] == 280_000)
        #expect(high.distributions["Common Equity"] == 710_000)
        #expect(high.remaining == 0)
    }

    @Test("Real estate waterfall example")
    func realEstateWaterfall() async throws {
        let waterfall = LiquidationWaterfall {
            Tier("LP Capital Return", priority: 1) {
                CapitalReturn(5_000_000)
            }
            Tier("LP Preferred Return", priority: 2) {
                PreferredReturn(0.08, years: 5)  // 8% annually for 5 years
            }
            Tier("GP Catch-Up", priority: 3) {
                CatchUp(to: 0.20)
            }
            Tier("Remaining", priority: 4) {
                ProRata([
                    ("LP", 0.80),
                    ("GP", 0.20)
                ])
            }
        }

        // Exit at $10M
        let result = waterfall.distribute(10_000_000)

        // LP should get capital back
        #expect(result.distributions["LP Capital Return"] == 5_000_000)

        // LP preferred: 5M * 8% * 5 years = 2M
        #expect(result.distributions["LP Preferred Return"] == 2_000_000)

        // Verify GP gets approximately 20% of total profits
        let totalProfit = 10_000_000.0 - 5_000_000.0  // 5M profit
        let gpTotal = (result.distributions["GP Catch-Up"] ?? 0) +
                      (result.distributions["GP"] ?? 0)
        #expect(abs(gpTotal / totalProfit - 0.20) < 0.01)
    }

    @Test("Venture capital liquidation preference")
    func vcLiquidationPreference() async throws {
        // 1x liquidation preference with participation
        let waterfall = LiquidationWaterfall {
            Tier("Series A Preference", priority: 1) {
                CapitalReturn(2_000_000)  // 1x preference
            }
            Tier("Remaining to All", priority: 2) {
                ProRata([
                    ("Series A", 0.30),
                    ("Common", 0.70)
                ])
            }
        }

        // Exit at $10M
        let result = waterfall.distribute(10_000_000)

        // Series A gets 2M preference first
        #expect(result.distributions["Series A Preference"] == 2_000_000)

        // Remaining 8M split by ownership (30/70)
        #expect(result.distributions["Series A"] == 2_400_000)  // 30% of 8M
        #expect(result.distributions["Common"] == 5_600_000)    // 70% of 8M

        // Total Series A: 2M + 2.4M = 4.4M (44% of $10M)
    }

    // MARK: - Edge Cases and Validation

    @Test("Empty waterfall handles zero distribution")
    func emptyWaterfall() async throws {
        let waterfall = LiquidationWaterfall {}

        let result = waterfall.distribute(1_000_000)
        #expect(result.remaining == 1_000_000)
        #expect(result.distributions.isEmpty)
    }

    @Test("Zero proceeds distribution")
    func zeroProceeds() async throws {
        let waterfall = LiquidationWaterfall {
            Tier("Senior", priority: 1) {
                CapitalReturn(500_000)
            }
        }

        let result = waterfall.distribute(0)
        #expect(result.distributions["Senior"] == 0)
        #expect(result.remaining == 0)
    }

    @Test("Negative proceeds treated as zero")
    func negativeProceeds() async throws {
        let waterfall = LiquidationWaterfall {
            Tier("Senior", priority: 1) {
                CapitalReturn(500_000)
            }
        }

        let result = waterfall.distribute(-100_000)
        #expect(result.distributions["Senior"] == 0)
        #expect(result.remaining == 0)
    }

    // NOTE: Validation tests for invalid inputs omitted because components use
    // fatalError for invalid inputs (negative capital, invalid percentages, etc.)
    // This is intentional to catch programmer errors at development time.
}

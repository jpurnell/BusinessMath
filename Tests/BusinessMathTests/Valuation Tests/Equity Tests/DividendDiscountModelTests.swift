//
//  DividendDiscountModelTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-01-24.
//

import Testing
import Numerics
@testable import BusinessMath

@Suite("Dividend Discount Model Tests")
struct DividendDiscountModelTests {

    // MARK: - Gordon Growth Model Tests

    @Test("Gordon Growth Model - basic calculation")
    func gordonGrowthBasic() {
        // Given: Stock with $2 dividend, 5% growth, 10% required return
        let model = GordonGrowthModel(
            dividendPerShare: 2.0,
            growthRate: 0.05,
            requiredReturn: 0.10
        )

        // When: Calculate intrinsic value
        let value = model.valuePerShare()

        // Then: Value = D₁ / (r - g) = 2 / (0.10 - 0.05) = $40
        #expect(abs(value - 40.0) < 0.01)
    }

    @Test("Gordon Growth Model - high dividend yield")
    func gordonGrowthHighDividend() {
        // Given: Mature utility stock with $5 dividend, 2% growth, 8% required return
        let model = GordonGrowthModel(
            dividendPerShare: 5.0,
            growthRate: 0.02,
            requiredReturn: 0.08
        )

        // When: Calculate value
        let value = model.valuePerShare()

        // Then: Value = 5 / (0.08 - 0.02) = $83.33
        #expect(abs(value - 83.33) < 0.01)
    }

    @Test("Gordon Growth Model - low growth rate")
    func gordonGrowthLowGrowth() {
        // Given: Stable company with minimal growth
        let model = GordonGrowthModel(
            dividendPerShare: 3.0,
            growthRate: 0.01,
            requiredReturn: 0.09
        )

        // When: Calculate value
        let value = model.valuePerShare()

        // Then: Value = 3 / (0.09 - 0.01) = $37.50
        #expect(abs(value - 37.50) < 0.01)
    }

    @Test("Gordon Growth Model - invalid when g >= r")
    func gordonGrowthInvalidWhenGrowthExceedsReturn() {
        // Given: Growth rate equal to required return (mathematically undefined)
        let model = GordonGrowthModel(
            dividendPerShare: 2.0,
            growthRate: 0.10,
            requiredReturn: 0.10
        )

        // When: Calculate value
        let value = model.valuePerShare()

        // Then: Should return infinity or NaN
        #expect(value.isInfinite || value.isNaN)
    }

    @Test("Gordon Growth Model - invalid when g > r")
    func gordonGrowthInvalidWhenGrowthGreaterThanReturn() {
        // Given: Growth rate exceeds required return (impossible to sustain)
        let model = GordonGrowthModel(
            dividendPerShare: 2.0,
            growthRate: 0.12,
            requiredReturn: 0.10
        )

        // When: Calculate value
        let value = model.valuePerShare()

        // Then: Should return negative or NaN (invalid model)
        #expect(value < 0 || value.isNaN)
    }

    @Test("Gordon Growth Model - zero growth")
    func gordonGrowthZeroGrowth() {
        // Given: Perpetual dividend with no growth (perpetuity)
        let model = GordonGrowthModel(
            dividendPerShare: 4.0,
            growthRate: 0.0,
            requiredReturn: 0.10
        )

        // When: Calculate value
        let value = model.valuePerShare()

        // Then: Value = 4 / 0.10 = $40 (simple perpetuity formula)
        #expect(abs(value - 40.0) < 0.01)
    }

    @Test("Gordon Growth Model - sensitivity to required return")
    func gordonGrowthSensitivityToRequiredReturn() {
        // Given: Same dividend and growth, different required returns
        let baseModel = GordonGrowthModel(
            dividendPerShare: 2.0,
            growthRate: 0.05,
            requiredReturn: 0.10
        )

        let higherReturnModel = GordonGrowthModel(
            dividendPerShare: 2.0,
            growthRate: 0.05,
            requiredReturn: 0.12
        )

        // When: Calculate values
        let baseValue = baseModel.valuePerShare()
        let higherReturnValue = higherReturnModel.valuePerShare()

        // Then: Higher required return should result in lower value
        #expect(higherReturnValue < baseValue)
        #expect(abs(baseValue - 40.0) < 0.01)
        #expect(abs(higherReturnValue - 28.57) < 0.01)  // 2 / (0.12 - 0.05)
    }

    @Test("Gordon Growth Model - generic over Real types")
    func gordonGrowthGenericTypes() {
        // Given: Model using Float instead of Double
        let modelFloat = GordonGrowthModel<Float>(
            dividendPerShare: 2.0,
            growthRate: 0.05,
            requiredReturn: 0.10
        )

        // When: Calculate value
        let valueFloat = modelFloat.valuePerShare()

        // Then: Should work with Float type
        #expect(abs(valueFloat - 40.0) < 0.01)
    }

    // MARK: - Two-Stage DDM Tests

    @Test("Two-Stage DDM - growth then mature phase")
    func twoStageBasic() {
        // Given: Tech company with $1 dividend, 15% growth for 5 years, then 5% stable
        let model = TwoStageDDM(
            currentDividend: 1.0,
            highGrowthRate: 0.15,
            highGrowthPeriods: 5,
            stableGrowthRate: 0.05,
            requiredReturn: 0.10
        )

        // When: Calculate intrinsic value
        let value = model.valuePerShare()

        // Then: Should be higher than simple Gordon Growth at 5%
        // Manual calculation:
        // High growth phase: PV of D1-D5
        // D1 = 1 * 1.15 = 1.15
        // D2 = 1.15 * 1.15 = 1.32
        // D3 = 1.52, D4 = 1.75, D5 = 2.01
        // PV = 1.15/1.10 + 1.32/1.21 + 1.52/1.33 + 1.75/1.46 + 2.01/1.61
        //    = 1.05 + 1.09 + 1.14 + 1.20 + 1.25 = 5.73
        // Terminal value at end of year 5: D6 / (r - g) = (2.01 * 1.05) / (0.10 - 0.05) = 42.21
        // PV of terminal = 42.21 / 1.61 = 26.22
        // Total = 5.73 + 26.22 = 31.95
        #expect(abs(value - 31.95) < 0.5)  // Allow some rounding tolerance
    }

    @Test("Two-Stage DDM - reduces to Gordon Growth with zero high growth periods")
    func twoStageReducesToGordon() {
        // Given: Two-stage with 0 high growth periods
        let twoStage = TwoStageDDM(
            currentDividend: 2.0,
            highGrowthRate: 0.15,  // This won't be used
            highGrowthPeriods: 0,
            stableGrowthRate: 0.05,
            requiredReturn: 0.10
        )

        // Equivalent Gordon Growth (D1 = 2 * 1.05 = 2.10)
        let gordon = GordonGrowthModel(
            dividendPerShare: 2.0 * 1.05,
            growthRate: 0.05,
            requiredReturn: 0.10
        )

        // When: Calculate both values
        let twoStageValue = twoStage.valuePerShare()
        let gordonValue = gordon.valuePerShare()

        // Then: Should be very close
        #expect(abs(twoStageValue - gordonValue) < 0.01)
    }

    @Test("Two-Stage DDM - high growth company")
    func twoStageHighGrowth() {
        // Given: Startup with aggressive growth, no current dividend but will start
        let model = TwoStageDDM(
            currentDividend: 0.5,  // Small initial dividend
            highGrowthRate: 0.25,  // 25% growth for growth phase
            highGrowthPeriods: 10,
            stableGrowthRate: 0.04,
            requiredReturn: 0.12
        )

        // When: Calculate value
        let value = model.valuePerShare()

        // Then: Should have significant value from growth phase
        #expect(value > 20.0)  // Rough sanity check
    }

    @Test("Two-Stage DDM - invalid when stable g >= r")
    func twoStageInvalidStableGrowth() {
        // Given: Invalid stable growth rate
        let model = TwoStageDDM(
            currentDividend: 1.0,
            highGrowthRate: 0.15,
            highGrowthPeriods: 5,
            stableGrowthRate: 0.10,  // Equal to required return
            requiredReturn: 0.10
        )

        // When: Calculate value
        let value = model.valuePerShare()

        // Then: Terminal value will be infinite/NaN
        #expect(value.isInfinite || value.isNaN)
    }

    @Test("Two-Stage DDM - high growth phase value decomposition")
    func twoStageHighGrowthPhaseValue() {
        // Given: Tech stock from blog post example
        // - Current dividend: $1.00/share
        // - High growth: 20% for 5 years
        // - Stable growth: 5% thereafter
        // - Required return: 12%
        let model = TwoStageDDM(
            currentDividend: 1.00,
            highGrowthRate: 0.20,
            highGrowthPeriods: 5,
            stableGrowthRate: 0.05,
            requiredReturn: 0.12
        )

        // When: Calculate high growth phase value
        let highGrowthValue = model.highGrowthPhaseValue()

        // Then: Should match calculated value decomposition
        // Expected: $6.18 (present value of dividends years 1-5)
        // Manual calculation:
        // D1 = 1.00 * 1.20 = 1.20, PV = 1.20 / 1.12 = 1.0714
        // D2 = 1.20 * 1.20 = 1.44, PV = 1.44 / 1.2544 = 1.1480
        // D3 = 1.44 * 1.20 = 1.728, PV = 1.728 / 1.4049 = 1.2300
        // D4 = 1.728 * 1.20 = 2.0736, PV = 2.0736 / 1.5735 = 1.3178
        // D5 = 2.0736 * 1.20 = 2.4883, PV = 2.4883 / 1.7623 = 1.4119
        // Sum ≈ 6.18
        #expect(abs(highGrowthValue - 6.18) < 0.05)
    }

    @Test("Two-Stage DDM - terminal value decomposition")
    func twoStageTerminalValue() {
        // Given: Same tech stock from blog post
        let model = TwoStageDDM(
            currentDividend: 1.00,
            highGrowthRate: 0.20,
            highGrowthPeriods: 5,
            stableGrowthRate: 0.05,
            requiredReturn: 0.12
        )

        // When: Calculate terminal value (present value)
        let terminalValue = model.terminalValue()

        // Then: Should match calculated value decomposition
        // Expected: $21.18 (PV of perpetuity starting year 6)
        // Terminal value at end of year 5: D6 / (r - g)
        // D5 = 1.00 * 1.20^5 = 2.4883
        // D6 = 2.4883 * 1.05 = 2.6127
        // TV = 2.6127 / (0.12 - 0.05) = 37.32
        // PV = 37.32 / 1.12^5 = 37.32 / 1.7623 = 21.18
        #expect(abs(terminalValue - 21.18) < 0.05)
    }

    @Test("Two-Stage DDM - components sum to total value")
    func twoStageComponentsSumToTotal() {
        // Given: Tech stock from blog post
        let model = TwoStageDDM(
            currentDividend: 1.00,
            highGrowthRate: 0.20,
            highGrowthPeriods: 5,
            stableGrowthRate: 0.05,
            requiredReturn: 0.12
        )

        // When: Calculate components and total
        let highGrowthValue = model.highGrowthPhaseValue()
        let terminalValue = model.terminalValue()
        let totalValue = model.valuePerShare()

        // Then: Components should sum to total
        let sumOfComponents = highGrowthValue + terminalValue
        #expect(abs(sumOfComponents - totalValue) < 0.01)

        // And total should match calculated expected value
        // Expected: $27.36 (= $6.18 + $21.18)
        #expect(abs(totalValue - 27.36) < 0.05)
    }

    @Test("Two-Stage DDM - terminal value dominates in growth stocks")
    func twoStageTerminalValueDominates() {
        // Given: Tech stock from blog post
        let model = TwoStageDDM(
            currentDividend: 1.00,
            highGrowthRate: 0.20,
            highGrowthPeriods: 5,
            stableGrowthRate: 0.05,
            requiredReturn: 0.12
        )

        // When: Calculate components
        let highGrowthValue = model.highGrowthPhaseValue()
        let terminalValue = model.terminalValue()

        // Then: Terminal value should be ~77% of total (demonstrating most value is in perpetuity)
        let totalValue = highGrowthValue + terminalValue
        let terminalPercentage = terminalValue / totalValue

        #expect(terminalPercentage > 0.75)  // At least 75%
        #expect(terminalPercentage < 0.80)  // At most 80%
    }

    @Test("Two-Stage DDM - zero high growth periods gives zero high growth value")
    func twoStageZeroHighGrowthPeriods() {
        // Given: Model with no high growth period
        let model = TwoStageDDM(
            currentDividend: 2.0,
            highGrowthRate: 0.20,
            highGrowthPeriods: 0,
            stableGrowthRate: 0.05,
            requiredReturn: 0.10
        )

        // When: Calculate high growth phase value
        let highGrowthValue = model.highGrowthPhaseValue()

        // Then: Should be zero (no high growth dividends)
        #expect(abs(highGrowthValue) < 0.01)

        // And terminal value should equal total value
        let terminalValue = model.terminalValue()
        let totalValue = model.valuePerShare()
        #expect(abs(terminalValue - totalValue) < 0.01)
    }

    // MARK: - H-Model Tests

    @Test("H-Model - linearly declining growth")
    func hModelBasic() {
        // Given: Company with growth declining from 12% to 4% over 10 years
        let model = HModel(
            currentDividend: 2.0,
            initialGrowthRate: 0.12,
            terminalGrowthRate: 0.04,
            halfLife: 10,  // Takes 10 years for growth to decline
            requiredReturn: 0.10
        )

        // When: Calculate value
        let value = model.valuePerShare()

        // Then: Should be between Gordon Growth at 12% and 4%
        // Gordon at 4%: 2 * 1.04 / (0.10 - 0.04) = 34.67
        // Gordon at 12%: Would be negative (invalid)
        // H-Model includes value from declining growth premium
        // Formula: D₀(1+gₗ)/(r-gₗ) + D₀×H×(gₛ-gₗ)/(r-gₗ)
        // = 2*1.04/0.06 + 2*10*0.08/0.06 = 34.67 + 26.67 = 61.33
        #expect(value > 60.0)
        #expect(value < 62.0)
        #expect(abs(value - 61.33) < 0.5)  // Should be approximately 61.33
    }

    @Test("H-Model - reduces to Gordon Growth when initial = terminal")
    func hModelReducesToGordon() {
        // Given: H-Model with same initial and terminal growth
        let hModel = HModel(
            currentDividend: 2.0,
            initialGrowthRate: 0.05,
            terminalGrowthRate: 0.05,
            halfLife: 10,
            requiredReturn: 0.10
        )

        // Equivalent Gordon Growth
        let gordon = GordonGrowthModel(
            dividendPerShare: 2.0 * 1.05,
            growthRate: 0.05,
            requiredReturn: 0.10
        )

        // When: Calculate both values
        let hValue = hModel.valuePerShare()
        let gordonValue = gordon.valuePerShare()

        // Then: Should be equal
        #expect(abs(hValue - gordonValue) < 0.01)
    }

    @Test("H-Model - short half-life")
    func hModelShortHalfLife() {
        // Given: Growth declines quickly (2 years)
        let model = HModel(
            currentDividend: 1.5,
            initialGrowthRate: 0.15,
            terminalGrowthRate: 0.05,
            halfLife: 2,
            requiredReturn: 0.11
        )

        // When: Calculate value
        let value = model.valuePerShare()

        // Then: Should be closer to terminal growth model
        #expect(value > 20.0)
        #expect(value < 35.0)
    }

    @Test("H-Model - generic over Real types")
    func hModelGenericTypes() {
        // Given: H-Model using Float
        let model = HModel<Float>(
            currentDividend: 2.0,
            initialGrowthRate: 0.10,
            terminalGrowthRate: 0.04,
            halfLife: 8,
            requiredReturn: 0.09
        )

        // When: Calculate value
        let value = model.valuePerShare()

        // Then: Should work with Float
        #expect(value > 0)
        #expect(!value.isNaN)
    }

    // MARK: - Comparison Tests

    @Test("Compare all three DDM models")
    func compareAllModels() {
        // Given: Same parameters adapted for each model
        let dividend = 2.0
        let stableGrowth = 0.05
        let requiredReturn = 0.10

        // Gordon Growth (simplest)
        let gordon = GordonGrowthModel(
            dividendPerShare: dividend,
            growthRate: stableGrowth,
            requiredReturn: requiredReturn
        )

        // Two-Stage with 0 high growth periods (should equal Gordon)
        let twoStage = TwoStageDDM(
            currentDividend: dividend / 1.05,  // Adjust so D1 = 2.0
            highGrowthRate: 0.15,
            highGrowthPeriods: 0,
            stableGrowthRate: stableGrowth,
            requiredReturn: requiredReturn
        )

        // H-Model with same initial and terminal growth (should equal Gordon)
        let hModel = HModel(
            currentDividend: dividend / 1.05,  // Adjust so D1 = 2.0
            initialGrowthRate: stableGrowth,
            terminalGrowthRate: stableGrowth,
            halfLife: 10,
            requiredReturn: requiredReturn
        )

        // When: Calculate all values
        let gordonValue = gordon.valuePerShare()
        let twoStageValue = twoStage.valuePerShare()
        let hValue = hModel.valuePerShare()

        // Then: All should be approximately equal
        #expect(abs(gordonValue - 40.0) < 0.01)
        #expect(abs(twoStageValue - gordonValue) < 0.5)
        #expect(abs(hValue - gordonValue) < 0.5)
    }
}

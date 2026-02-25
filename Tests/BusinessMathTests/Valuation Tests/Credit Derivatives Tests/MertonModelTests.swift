//
//  MertonModelTests.swift
//  BusinessMath
//
//  Merton Model structural default tests - treat equity as call option
//

import Testing
import TestSupport  // Cross-platform math functions
import Foundation
@testable import BusinessMath

@Suite("Merton Model Tests")
struct MertonModelTests {

    let tolerance = 0.01

    // MARK: - Basic Initialization Tests

    @Test("Initialize Merton Model with standard parameters")
    func initializeMertonModel() {
        let model = MertonModel(
            assetValue: 100_000_000.0,
            assetVolatility: 0.25,
            debtFaceValue: 80_000_000.0,
            riskFreeRate: 0.05,
            maturity: 1.0
        )

        #expect(model.assetValue == 100_000_000.0)
        #expect(model.assetVolatility == 0.25)
        #expect(model.debtFaceValue == 80_000_000.0)
        #expect(model.riskFreeRate == 0.05)
        #expect(model.maturity == 1.0)
    }

    // MARK: - Equity Valuation Tests

    @Test("Equity value calculated as call option on assets")
    func equityValueAsCallOption() {
        // Well-capitalized firm: Assets > Debt
        let model = MertonModel(
            assetValue: 100_000_000.0,
            assetVolatility: 0.25,
            debtFaceValue: 80_000_000.0,
            riskFreeRate: 0.05,
            maturity: 1.0
        )

        let equityValue = model.equityValue()

        // Equity should be positive
        #expect(equityValue > 0)
        // Equity should be less than assets
        #expect(equityValue < model.assetValue)
        // With low leverage, equity should be substantial
        #expect(equityValue > 15_000_000.0)
    }

    @Test("Equity value decreases with higher leverage")
    func equityValueVsLeverage() {
        let baseAssets = 100_000_000.0
        let volatility = 0.25
        let rate = 0.05
        let maturity = 1.0

        // Low leverage (50%)
        let lowLeverage = MertonModel(
            assetValue: baseAssets,
            assetVolatility: volatility,
            debtFaceValue: 50_000_000.0,
            riskFreeRate: rate,
            maturity: maturity
        )

        // High leverage (90%)
        let highLeverage = MertonModel(
            assetValue: baseAssets,
            assetVolatility: volatility,
            debtFaceValue: 90_000_000.0,
            riskFreeRate: rate,
            maturity: maturity
        )

        let equityLow = lowLeverage.equityValue()
        let equityHigh = highLeverage.equityValue()

        // Higher leverage → lower equity value
        #expect(equityHigh < equityLow)
    }

    @Test("Equity value increases with asset volatility")
    func equityValueVsVolatility() {
        let assets = 100_000_000.0
        let debt = 80_000_000.0
        let rate = 0.05
        let maturity = 1.0

        // Low volatility
        let lowVol = MertonModel(
            assetValue: assets,
            assetVolatility: 0.15,
            debtFaceValue: debt,
            riskFreeRate: rate,
            maturity: maturity
        )

        // High volatility
        let highVol = MertonModel(
            assetValue: assets,
            assetVolatility: 0.40,
            debtFaceValue: debt,
            riskFreeRate: rate,
            maturity: maturity
        )

        let equityLow = lowVol.equityValue()
        let equityHigh = highVol.equityValue()

        // Higher volatility → higher equity value (option value)
        #expect(equityHigh > equityLow)
    }

    // MARK: - Debt Valuation Tests

    @Test("Debt value calculated as risk-free debt minus put option")
    func debtValueCalculation() {
        let model = MertonModel(
            assetValue: 100_000_000.0,
            assetVolatility: 0.25,
            debtFaceValue: 80_000_000.0,
            riskFreeRate: 0.05,
            maturity: 1.0
        )

        let debtValue = model.debtValue()
        let riskFreeDebt = model.debtFaceValue * exp(-model.riskFreeRate * model.maturity)

        // Risky debt should be less than risk-free debt
        #expect(debtValue < riskFreeDebt)
        // But should still be substantial
        #expect(debtValue > 70_000_000.0)
    }

    @Test("Asset value equals equity plus debt")
    func assetValueEqualsEquityPlusDebt() {
        let model = MertonModel(
            assetValue: 100_000_000.0,
            assetVolatility: 0.25,
            debtFaceValue: 80_000_000.0,
            riskFreeRate: 0.05,
            maturity: 1.0
        )

        let equity = model.equityValue()
        let debt = model.debtValue()
        let total = equity + debt

        // Should approximately equal asset value (within tolerance)
        #expect(abs(total - model.assetValue) / model.assetValue < tolerance)
    }

    // MARK: - Credit Spread Tests

    @Test("Calculate credit spread from Merton model")
    func creditSpreadCalculation() {
        let model = MertonModel(
            assetValue: 100_000_000.0,
            assetVolatility: 0.25,
            debtFaceValue: 80_000_000.0,
            riskFreeRate: 0.05,
            maturity: 1.0
        )

        let spread = model.creditSpread()

        // Credit spread should be positive
        #expect(spread > 0)
        // Should be reasonable (less than 10%)
        #expect(spread < 0.10)
    }

    @Test("Credit spread increases with higher leverage")
    func creditSpreadVsLeverage() {
        let baseAssets = 100_000_000.0
        let volatility = 0.25
        let rate = 0.05
        let maturity = 1.0

        // Low leverage
        let lowLeverage = MertonModel(
            assetValue: baseAssets,
            assetVolatility: volatility,
            debtFaceValue: 50_000_000.0,
            riskFreeRate: rate,
            maturity: maturity
        )

        // High leverage
        let highLeverage = MertonModel(
            assetValue: baseAssets,
            assetVolatility: volatility,
            debtFaceValue: 90_000_000.0,
            riskFreeRate: rate,
            maturity: maturity
        )

        let spreadLow = lowLeverage.creditSpread()
        let spreadHigh = highLeverage.creditSpread()

        // Higher leverage → wider credit spread
        #expect(spreadHigh > spreadLow)
    }

    @Test("Credit spread increases with asset volatility")
    func creditSpreadVsVolatility() {
        let assets = 100_000_000.0
        let debt = 80_000_000.0
        let rate = 0.05
        let maturity = 1.0

        // Low volatility
        let lowVol = MertonModel(
            assetValue: assets,
            assetVolatility: 0.15,
            debtFaceValue: debt,
            riskFreeRate: rate,
            maturity: maturity
        )

        // High volatility
        let highVol = MertonModel(
            assetValue: assets,
            assetVolatility: 0.40,
            debtFaceValue: debt,
            riskFreeRate: rate,
            maturity: maturity
        )

        let spreadLow = lowVol.creditSpread()
        let spreadHigh = highVol.creditSpread()

        // Higher volatility → wider credit spread
        #expect(spreadHigh > spreadLow)
    }

    // MARK: - Default Probability Tests

    @Test("Calculate default probability")
    func defaultProbabilityCalculation() {
        let model = MertonModel(
            assetValue: 100_000_000.0,
            assetVolatility: 0.25,
            debtFaceValue: 80_000_000.0,
            riskFreeRate: 0.05,
            maturity: 1.0
        )

        let pd = model.defaultProbability()

        // Default probability should be between 0 and 1
        #expect(pd >= 0.0)
        #expect(pd <= 1.0)
        // For this well-capitalized firm, should be low
        #expect(pd < 0.20)
    }

    @Test("Default probability increases with higher leverage")
    func defaultProbabilityVsLeverage() {
        let baseAssets = 100_000_000.0
        let volatility = 0.25
        let rate = 0.05
        let maturity = 1.0

        // Low leverage
        let lowLeverage = MertonModel(
            assetValue: baseAssets,
            assetVolatility: volatility,
            debtFaceValue: 50_000_000.0,
            riskFreeRate: rate,
            maturity: maturity
        )

        // High leverage
        let highLeverage = MertonModel(
            assetValue: baseAssets,
            assetVolatility: volatility,
            debtFaceValue: 95_000_000.0,
            riskFreeRate: rate,
            maturity: maturity
        )

        let pdLow = lowLeverage.defaultProbability()
        let pdHigh = highLeverage.defaultProbability()

        // Higher leverage → higher default probability
        #expect(pdHigh > pdLow)
    }

    // MARK: - Distance to Default Tests

    @Test("Calculate distance to default")
    func distanceToDefaultCalculation() {
        let model = MertonModel(
            assetValue: 100_000_000.0,
            assetVolatility: 0.25,
            debtFaceValue: 80_000_000.0,
            riskFreeRate: 0.05,
            maturity: 1.0
        )

        let dd = model.distanceToDefault()

        // Distance to default should be positive for solvent firm
        #expect(dd > 0)
        // Should be reasonable (typically 1-5 for healthy firms)
        #expect(dd > 0.5)
        #expect(dd < 10.0)
    }

    @Test("Distance to default decreases with higher leverage")
    func distanceToDefaultVsLeverage() {
        let baseAssets = 100_000_000.0
        let volatility = 0.25
        let rate = 0.05
        let maturity = 1.0

        // Low leverage
        let lowLeverage = MertonModel(
            assetValue: baseAssets,
            assetVolatility: volatility,
            debtFaceValue: 50_000_000.0,
            riskFreeRate: rate,
            maturity: maturity
        )

        // High leverage
        let highLeverage = MertonModel(
            assetValue: baseAssets,
            assetVolatility: volatility,
            debtFaceValue: 90_000_000.0,
            riskFreeRate: rate,
            maturity: maturity
        )

        let ddLow = lowLeverage.distanceToDefault()
        let ddHigh = highLeverage.distanceToDefault()

        // Higher leverage → lower distance to default
        #expect(ddHigh < ddLow)
    }

    @Test("Distance to default and default probability are inversely related")
    func distanceToDefaultVsDefaultProbability() {
        let model = MertonModel(
            assetValue: 100_000_000.0,
            assetVolatility: 0.25,
            debtFaceValue: 80_000_000.0,
            riskFreeRate: 0.05,
            maturity: 1.0
        )

        let dd = model.distanceToDefault()
        let pd = model.defaultProbability()

        // Higher distance to default should correlate with lower default probability
        // DD > 0 should mean PD < 0.5
        if dd > 1.0 {
            #expect(pd < 0.5)
        }
    }

    // MARK: - Calibration Tests

    @Test("Calibrate Merton model from equity market data")
    func calibrateFromEquityData() throws {
        // Given: Observable market data
        let equityValue = 20_000_000.0
        let equityVolatility = 0.40
        let debtFaceValue = 80_000_000.0
        let riskFreeRate = 0.05
        let maturity = 1.0

        // When: Calibrate model
        let model = try calibrateMertonModel(
            equityValue: equityValue,
            equityVolatility: equityVolatility,
            debtFaceValue: debtFaceValue,
            riskFreeRate: riskFreeRate,
            maturity: maturity
        )

        // Then: Model should reproduce market equity value
        let calibratedEquity = model.equityValue()
        #expect(abs(calibratedEquity - equityValue) / equityValue < 0.05)  // Within 5%

        // Asset value should be greater than debt
        #expect(model.assetValue > debtFaceValue)
    }

    @Test("Calibrated model has reasonable asset volatility")
    func calibratedAssetVolatility() throws {
        let equityValue = 20_000_000.0
        let equityVolatility = 0.50
        let debtFaceValue = 80_000_000.0
        let riskFreeRate = 0.05
        let maturity = 1.0

        let model = try calibrateMertonModel(
            equityValue: equityValue,
            equityVolatility: equityVolatility,
            debtFaceValue: debtFaceValue,
            riskFreeRate: riskFreeRate,
            maturity: maturity
        )

        // Asset volatility should be less than equity volatility (leverage effect)
        #expect(model.assetVolatility < equityVolatility)
        // But should be positive and reasonable
        #expect(model.assetVolatility > 0.10)
        #expect(model.assetVolatility < 0.80)
    }
}

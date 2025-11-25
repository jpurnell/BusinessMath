//
//  BondValuationIntegrationTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-01-25.
//

import Testing
import Foundation
@testable import BusinessMath

/// Integration tests demonstrating complete bond valuation workflows
///
/// These tests show how bond valuation components work together in
/// realistic scenarios, from credit analysis to bond pricing.
@Suite("Bond Valuation Integration Tests")
struct BondValuationIntegrationTests {

    // MARK: - Workflow 1: Credit Metrics → Bond Pricing

    @Test("Complete workflow: Z-Score → Default Probability → Credit Spread → Bond Price")
    func creditMetricsToBondPrice() {
        // Scenario: Price a 5-year corporate bond for a company
        // with moderate credit quality (grey zone Z-Score)

        let calendar = Calendar.current
        let today = Date()
        let maturity = calendar.date(byAdding: .year, value: 5, to: today)!

        // Step 1: Start with company credit metrics
        let zScore = 2.3  // Grey zone (moderate risk)

        // Step 2: Convert Z-Score to default probability
        let creditModel = CreditSpreadModel<Double>()
        let defaultProbability = creditModel.defaultProbability(zScore: zScore)

        // Should be in grey zone range (1-10%)
        #expect(defaultProbability >= 0.01)
        #expect(defaultProbability <= 0.10)

        // Step 3: Determine recovery rate based on seniority
        let seniority = Seniority.seniorUnsecured
        let recoveryRate = RecoveryModel<Double>.standardRecoveryRate(
            seniority: seniority
        )
        #expect(recoveryRate == 0.50)  // 50% for senior unsecured

        // Step 4: Calculate credit spread
        let creditSpread = creditModel.creditSpread(
            defaultProbability: defaultProbability,
            recoveryRate: recoveryRate,
            maturity: 5.0
        )

        // Should be reasonable (50-300 bps)
        #expect(creditSpread > 0.005)
        #expect(creditSpread < 0.030)

        // Step 5: Calculate corporate bond yield
        let riskFreeRate = 0.03  // 3% Treasury
        let corporateYield = creditModel.corporateBondYield(
            riskFreeRate: riskFreeRate,
            creditSpread: creditSpread
        )

        // Step 6: Price the bond
        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.05,  // 5% coupon
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        let bondPrice = bond.price(yield: corporateYield, asOf: today)

        // Bond should trade near par (coupon ≈ yield)
        #expect(bondPrice > 950.0)
        #expect(bondPrice < 1050.0)

        // Verify risk metrics
        let duration = bond.macaulayDuration(yield: corporateYield, asOf: today)
        #expect(duration > 4.0)
        #expect(duration < 5.0)
    }

    @Test("Workflow: Credit deterioration impact on bond value")
    func creditDeteriorationImpact() {
        let calendar = Calendar.current
        let today = Date()
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.06,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        let creditModel = CreditSpreadModel<Double>()
        let riskFreeRate = 0.03
        let recoveryRate = 0.40

        // Scenario 1: Investment grade (Z = 3.5)
        let zScoreIG = 3.5
        let pdIG = creditModel.defaultProbability(zScore: zScoreIG)
        let spreadIG = creditModel.creditSpread(
            defaultProbability: pdIG,
            recoveryRate: recoveryRate,
            maturity: 10.0
        )
        let yieldIG = riskFreeRate + spreadIG
        let priceIG = bond.price(yield: yieldIG, asOf: today)

        // Scenario 2: Grey zone (Z = 2.0)
        let zScoreGZ = 2.0
        let pdGZ = creditModel.defaultProbability(zScore: zScoreGZ)
        let spreadGZ = creditModel.creditSpread(
            defaultProbability: pdGZ,
            recoveryRate: recoveryRate,
            maturity: 10.0
        )
        let yieldGZ = riskFreeRate + spreadGZ
        let priceGZ = bond.price(yield: yieldGZ, asOf: today)

        // Scenario 3: Distress (Z = 1.0)
        let zScoreDistress = 1.0
        let pdDistress = creditModel.defaultProbability(zScore: zScoreDistress)
        let spreadDistress = creditModel.creditSpread(
            defaultProbability: pdDistress,
            recoveryRate: recoveryRate,
            maturity: 10.0
        )
        let yieldDistress = riskFreeRate + spreadDistress
        let priceDistress = bond.price(yield: yieldDistress, asOf: today)

        // Verify credit deterioration → lower price
        #expect(priceGZ < priceIG)
        #expect(priceDistress < priceGZ)

        // Verify spreads widen with credit deterioration
        #expect(spreadGZ > spreadIG)
        #expect(spreadDistress > spreadGZ)
    }

    // MARK: - Workflow 2: Callable Bonds with OAS

    @Test("Workflow: Callable bond analysis with OAS decomposition")
    func callableBondOASAnalysis() throws {
        let calendar = Calendar.current
        let today = Date()
        let maturity = calendar.date(byAdding: .year, value: 10, to: today)!

        // Create underlying bond
        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.07,  // 7% coupon (high coupon → more likely to be called)
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        // Make it callable after 3 years at 1040
        let callDate = calendar.date(byAdding: .year, value: 3, to: today)!
        let callSchedule = [CallProvision(date: callDate, callPrice: 1040.0)]

        let callableBond = CallableBond(
            bond: bond,
            callSchedule: callSchedule
        )

        // Market conditions
        let riskFreeRate = 0.03
        let creditSpread = 0.025  // 250 bps
        let volatility = 0.15

        // Step 1: Price non-callable bond
        let straightYield = riskFreeRate + creditSpread
        let straightPrice = bond.price(yield: straightYield, asOf: today)

        // Step 2: Price callable bond
        let callablePrice = callableBond.price(
            riskFreeRate: riskFreeRate,
            spread: creditSpread,
            volatility: volatility,
            asOf: today
        )

        // Step 3: Calculate call option value
        let callOptionValue = callableBond.callOptionValue(
            riskFreeRate: riskFreeRate,
            spread: creditSpread,
            volatility: volatility,
            asOf: today
        )

        // Step 4: Calculate OAS
        let oas = try callableBond.optionAdjustedSpread(
            marketPrice: callablePrice,
            riskFreeRate: riskFreeRate,
            volatility: volatility,
            asOf: today
        )

        // Step 5: Calculate effective duration
        let effectiveDuration = callableBond.effectiveDuration(
            riskFreeRate: riskFreeRate,
            spread: creditSpread,
            volatility: volatility,
            asOf: today
        )
        let straightDuration = bond.macaulayDuration(yield: straightYield, asOf: today)

        // Verify relationships
        #expect(callablePrice < straightPrice)  // Call option has value
        #expect(callOptionValue > 0.0)          // Option is valuable to issuer
        #expect(oas > 0.0)                       // OAS captures credit risk
        #expect(oas < creditSpread)              // OAS < nominal spread
        #expect(effectiveDuration < straightDuration)  // Shorter due to call option

        // OAS should be close to credit spread minus option cost
        let impliedOptionSpread = creditSpread - oas
        #expect(impliedOptionSpread > 0.0)
        #expect(impliedOptionSpread < creditSpread)
    }

    @Test("Workflow: Volatility impact on callable bond pricing")
    func volatilityImpactAnalysis() {
        let calendar = Calendar.current
        let today = Date()
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

        let riskFreeRate = 0.03
        let spread = 0.02

        // Price at different volatilities
        let volLow = 0.05
        let volMid = 0.15
        let volHigh = 0.25

        let priceLow = callableBond.price(
            riskFreeRate: riskFreeRate,
            spread: spread,
            volatility: volLow,
            asOf: today
        )

        let priceMid = callableBond.price(
            riskFreeRate: riskFreeRate,
            spread: spread,
            volatility: volMid,
            asOf: today
        )

        let priceHigh = callableBond.price(
            riskFreeRate: riskFreeRate,
            spread: spread,
            volatility: volHigh,
            asOf: today
        )

        // Higher volatility → lower callable bond price (more valuable call option to issuer)
        #expect(priceMid < priceLow)
        #expect(priceHigh < priceMid)

        // Calculate option values
        let optionLow = callableBond.callOptionValue(
            riskFreeRate: riskFreeRate,
            spread: spread,
            volatility: volLow,
            asOf: today
        )

        let optionHigh = callableBond.callOptionValue(
            riskFreeRate: riskFreeRate,
            spread: spread,
            volatility: volHigh,
            asOf: today
        )

        // Higher volatility → more valuable call option
        #expect(optionHigh > optionLow)
    }

    // MARK: - Workflow 3: Recovery Rates and Expected Loss

    @Test("Workflow: Credit portfolio expected loss calculation")
    func creditPortfolioExpectedLoss() {
        // Scenario: Calculate expected loss for bond portfolio with different seniorities

        let creditModel = CreditSpreadModel<Double>()
        let recoveryModel = RecoveryModel<Double>()

        // Portfolio of bonds from company with Z-Score = 2.0 (grey zone)
        let zScore = 2.0
        let defaultProbability = creditModel.defaultProbability(zScore: zScore)

        // Bond 1: $5M senior secured
        let recoverySeniorSecured = RecoveryModel<Double>.standardRecoveryRate(
            seniority: .seniorSecured
        )
        let elSeniorSecured = recoveryModel.expectedLoss(
            defaultProbability: defaultProbability,
            recoveryRate: recoverySeniorSecured,
            exposure: 5_000_000.0
        )

        // Bond 2: $3M senior unsecured
        let recoverySeniorUnsecured = RecoveryModel<Double>.standardRecoveryRate(
            seniority: .seniorUnsecured
        )
        let elSeniorUnsecured = recoveryModel.expectedLoss(
            defaultProbability: defaultProbability,
            recoveryRate: recoverySeniorUnsecured,
            exposure: 3_000_000.0
        )

        // Bond 3: $2M subordinated
        let recoverySubordinated = RecoveryModel<Double>.standardRecoveryRate(
            seniority: .subordinated
        )
        let elSubordinated = recoveryModel.expectedLoss(
            defaultProbability: defaultProbability,
            recoveryRate: recoverySubordinated,
            exposure: 2_000_000.0
        )

        // Total expected loss
        let totalExpectedLoss = elSeniorSecured + elSeniorUnsecured + elSubordinated

        // Verify seniority ordering on per-dollar basis
        let elPerDollarSeniorSecured = elSeniorSecured / 5_000_000.0
        let elPerDollarSeniorUnsecured = elSeniorUnsecured / 3_000_000.0
        let elPerDollarSubordinated = elSubordinated / 2_000_000.0

        // Higher seniority → lower loss per dollar of exposure
        #expect(elPerDollarSeniorSecured < elPerDollarSeniorUnsecured)
        #expect(elPerDollarSeniorUnsecured < elPerDollarSubordinated)

        // Calculate reserve as percentage of portfolio
        let totalExposure = 10_000_000.0
        let reserveRatio = totalExpectedLoss / totalExposure

        // Reserve should be positive (grey zone credit has meaningful risk)
        #expect(reserveRatio > 0.0)
        #expect(reserveRatio < 0.10)  // Under 10% for non-distressed
    }

    @Test("Workflow: Spread decomposition into credit and option components")
    func spreadDecomposition() throws {
        let calendar = Calendar.current
        let today = Date()
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

        let riskFreeRate = 0.03
        let creditSpread = 0.020  // 200 bps
        let volatility = 0.15

        // Price the callable bond
        let marketPrice = callableBond.price(
            riskFreeRate: riskFreeRate,
            spread: creditSpread,
            volatility: volatility,
            asOf: today
        )

        // Calculate OAS (isolates credit risk)
        let oas = try callableBond.optionAdjustedSpread(
            marketPrice: marketPrice,
            riskFreeRate: riskFreeRate,
            volatility: volatility,
            asOf: today
        )

        // Spread decomposition:
        // Nominal Spread = OAS + Option Spread
        let optionSpread = creditSpread - oas

        // Verify decomposition
        #expect(oas > 0.0)              // Credit risk component
        #expect(optionSpread > 0.0)     // Option component
        #expect(abs((oas + optionSpread) - creditSpread) < 0.001)  // Sum equals nominal

        // OAS should be close to input spread (round-trip)
        #expect(abs(oas - creditSpread) < 0.01)  // Within 100 bps
    }

    // MARK: - Workflow 4: Credit Curve Analysis

    @Test("Workflow: Build and analyze credit curve from market spreads")
    func creditCurveAnalysis() {
        // Scenario: Build credit curve from observed market spreads

        let periods = [
            Period.year(1),
            Period.year(3),
            Period.year(5),
            Period.year(10)
        ]

        // Observed market spreads (upward sloping)
        let spreads = TimeSeries(
            periods: periods,
            values: [0.005, 0.012, 0.018, 0.025]  // 50, 120, 180, 250 bps
        )

        let recoveryRate = 0.40
        let curve = CreditCurve(
            spreads: spreads,
            recoveryRate: recoveryRate
        )

        // Interpolate spreads for any maturity
        let spread2y = curve.spread(maturity: 2.0)
        let spread7y = curve.spread(maturity: 7.0)

        // Should be between bounding points
        #expect(spread2y > 0.005)
        #expect(spread2y < 0.012)
        #expect(spread7y > 0.018)
        #expect(spread7y < 0.025)

        // Calculate cumulative default probabilities
        let cdp1y = curve.cumulativeDefaultProbability(maturity: 1.0)
        let cdp5y = curve.cumulativeDefaultProbability(maturity: 5.0)
        let cdp10y = curve.cumulativeDefaultProbability(maturity: 10.0)

        // CDF should be monotonically increasing
        #expect(cdp5y > cdp1y)
        #expect(cdp10y > cdp5y)

        // Survival probabilities
        let survival1y = 1.0 - cdp1y
        let survival5y = 1.0 - cdp5y
        let survival10y = 1.0 - cdp10y

        // Longer horizon → lower survival probability
        #expect(survival5y < survival1y)
        #expect(survival10y < survival5y)

        // Hazard rates (forward default intensities)
        let hazard1y = curve.hazardRate(maturity: 1.0)
        let hazard5y = curve.hazardRate(maturity: 5.0)
        let hazard10y = curve.hazardRate(maturity: 10.0)

        // With upward sloping curve, hazard rates should increase
        #expect(hazard5y > hazard1y)
        #expect(hazard10y > hazard5y)
    }

    @Test("Workflow: Cross-validate models with round-trip calculations")
    func crossModelValidation() throws {
        let calendar = Calendar.current
        let today = Date()
        let maturity = calendar.date(byAdding: .year, value: 5, to: today)!

        let creditModel = CreditSpreadModel<Double>()
        let recoveryModel = RecoveryModel<Double>()

        // Start with known parameters
        let zScore = 2.5
        let recoveryRate = 0.40
        let riskFreeRate = 0.03

        // Step 1: Z-Score → Default Probability
        let pd = creditModel.defaultProbability(zScore: zScore)

        // Step 2: PD + Recovery → Credit Spread
        let spread = creditModel.creditSpread(
            defaultProbability: pd,
            recoveryRate: recoveryRate,
            maturity: 5.0
        )

        // Step 3: Spread → Implied Recovery Rate (should match)
        let impliedRecovery = recoveryModel.impliedRecoveryRate(
            spread: spread,
            defaultProbability: pd,
            maturity: 5.0
        )

        // Round-trip validation
        #expect(abs(impliedRecovery - recoveryRate) < 0.01)  // Within 1%

        // Step 4: Price bond with this spread
        let bond = Bond(
            faceValue: 1000.0,
            couponRate: 0.05,
            maturityDate: maturity,
            paymentFrequency: .semiAnnual,
            issueDate: today
        )

        let corporateYield = riskFreeRate + spread
        let price = bond.price(yield: corporateYield, asOf: today)

        // Step 5: Reverse engineer YTM (should match)
        let ytm = try bond.yieldToMaturity(price: price, asOf: today)

        #expect(abs(ytm - corporateYield) < 0.001)  // Within 10 bps
    }
}

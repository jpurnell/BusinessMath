//
//  RecoveryModelTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-01-25.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Recovery Model Tests")
struct RecoveryModelTests {

    @Test("Standard recovery rate - senior secured")
    func standardRecoveryRateSeniorSecured() {
        let recoveryRate: Double = RecoveryModel.standardRecoveryRate(
            seniority: .seniorSecured
        )

        // Senior secured debt typically recovers 60-80%
        #expect(recoveryRate >= 0.60)
        #expect(recoveryRate <= 0.80)
    }

    @Test("Standard recovery rate - senior unsecured")
    func standardRecoveryRateSeniorUnsecured() {
        let recoveryRate: Double = RecoveryModel.standardRecoveryRate(
            seniority: .seniorUnsecured
        )

        // Senior unsecured debt typically recovers 40-60%
        #expect(recoveryRate >= 0.40)
        #expect(recoveryRate <= 0.60)
    }

    @Test("Standard recovery rate - subordinated")
    func standardRecoveryRateSubordinated() {
        let recoveryRate: Double = RecoveryModel.standardRecoveryRate(
            seniority: .subordinated
        )

        // Subordinated debt typically recovers 20-40%
        #expect(recoveryRate >= 0.20)
        #expect(recoveryRate <= 0.40)
    }

    @Test("Standard recovery rate - junior")
    func standardRecoveryRateJunior() {
        let recoveryRate: Double = RecoveryModel.standardRecoveryRate(
            seniority: .junior
        )

        // Junior debt typically recovers 0-20%
        #expect(recoveryRate >= 0.0)
        #expect(recoveryRate <= 0.20)
    }

    @Test("Recovery rates ordered by seniority")
    func recoveryRatesOrderedBySeniority() {
        let seniorSecured: Double = RecoveryModel.standardRecoveryRate(
            seniority: .seniorSecured
        )
        let seniorUnsecured: Double = RecoveryModel.standardRecoveryRate(
            seniority: .seniorUnsecured
        )
        let subordinated: Double = RecoveryModel.standardRecoveryRate(
            seniority: .subordinated
        )
        let junior: Double = RecoveryModel.standardRecoveryRate(
            seniority: .junior
        )

        // Higher seniority → Higher recovery rate
        #expect(seniorSecured > seniorUnsecured)
        #expect(seniorUnsecured > subordinated)
        #expect(subordinated > junior)
    }

    @Test("Implied recovery rate from spread")
    func impliedRecoveryRate() {
        let model = RecoveryModel<Double>()

        // Market spread = 200 bps, PD = 2%, Maturity = 5 years
        // Implied Recovery = 1 - (Spread × T) / PD
        let impliedRecovery = model.impliedRecoveryRate(
            spread: 0.020,  // 200 bps
            defaultProbability: 0.02,
            maturity: 5.0
        )

        // Should be positive and reasonable
        #expect(impliedRecovery >= 0.0)
        #expect(impliedRecovery <= 1.0)
    }

    @Test("Implied recovery rate consistency")
    func impliedRecoveryRateConsistency() {
        let model = RecoveryModel<Double>()

        // Higher spread with same PD → Lower implied recovery
        let recoveryLowSpread = model.impliedRecoveryRate(
            spread: 0.010,
            defaultProbability: 0.02,
            maturity: 5.0
        )

        let recoveryHighSpread = model.impliedRecoveryRate(
            spread: 0.030,
            defaultProbability: 0.02,
            maturity: 5.0
        )

        #expect(recoveryLowSpread > recoveryHighSpread)
    }

    @Test("Loss given default calculation")
    func lossGivenDefault() {
        let model = RecoveryModel<Double>()

        let recoveryRate = 0.40
        let lgd = model.lossGivenDefault(recoveryRate: recoveryRate)

        // LGD = 1 - Recovery Rate
        let expected = 1.0 - recoveryRate
        #expect(abs(lgd - expected) < 0.0001)
    }

    @Test("LGD for zero recovery")
    func lossGivenDefaultZeroRecovery() {
        let model = RecoveryModel<Double>()

        let lgd = model.lossGivenDefault(recoveryRate: 0.0)

        // No recovery → 100% loss
        #expect(lgd == 1.0)
    }

    @Test("LGD for full recovery")
    func lossGivenDefaultFullRecovery() {
        let model = RecoveryModel<Double>()

        let lgd = model.lossGivenDefault(recoveryRate: 1.0)

        // Full recovery → 0% loss
        #expect(lgd == 0.0)
    }

    @Test("Expected loss calculation")
    func expectedLoss() {
        let model = RecoveryModel<Double>()

        // EL = PD × LGD × Exposure
        let pd = 0.02  // 2% default probability
        let recoveryRate = 0.40
        let exposure = 1000000.0  // $1M exposure

        let el = model.expectedLoss(
            defaultProbability: pd,
            recoveryRate: recoveryRate,
            exposure: exposure
        )

        // EL = 0.02 × (1 - 0.40) × 1,000,000 = 0.02 × 0.60 × 1,000,000 = $12,000
        let expected = pd * (1.0 - recoveryRate) * exposure
        #expect(abs(el - expected) < 1.0)
    }

    @Test("Expected loss scales with exposure")
    func expectedLossScaling() {
        let model = RecoveryModel<Double>()

        let pd = 0.02
        let recoveryRate = 0.40

        let el1M = model.expectedLoss(
            defaultProbability: pd,
            recoveryRate: recoveryRate,
            exposure: 1000000.0
        )

        let el2M = model.expectedLoss(
            defaultProbability: pd,
            recoveryRate: recoveryRate,
            exposure: 2000000.0
        )

        // Double exposure → Double expected loss
        #expect(abs(el2M / el1M - 2.0) < 0.001)
    }

    @Test("Expected loss increases with default probability")
    func expectedLossVsDefaultProbability() {
        let model = RecoveryModel<Double>()

        let recoveryRate = 0.40
        let exposure = 1000000.0

        let elLowPD = model.expectedLoss(
            defaultProbability: 0.01,
            recoveryRate: recoveryRate,
            exposure: exposure
        )

        let elHighPD = model.expectedLoss(
            defaultProbability: 0.05,
            recoveryRate: recoveryRate,
            exposure: exposure
        )

        // Higher PD → Higher expected loss
        #expect(elHighPD > elLowPD)
    }

    @Test("Expected loss decreases with recovery rate")
    func expectedLossVsRecoveryRate() {
        let model = RecoveryModel<Double>()

        let pd = 0.02
        let exposure = 1000000.0

        let elLowRecovery = model.expectedLoss(
            defaultProbability: pd,
            recoveryRate: 0.20,
            exposure: exposure
        )

        let elHighRecovery = model.expectedLoss(
            defaultProbability: pd,
            recoveryRate: 0.60,
            exposure: exposure
        )

        // Higher recovery → Lower expected loss
        #expect(elHighRecovery < elLowRecovery)
    }

    @Test("Expected loss is zero with zero PD")
    func expectedLossZeroPD() {
        let model = RecoveryModel<Double>()

        let el = model.expectedLoss(
            defaultProbability: 0.0,
            recoveryRate: 0.40,
            exposure: 1000000.0
        )

        // No default probability → No expected loss
        #expect(el == 0.0)
    }

    @Test("Expected loss is zero with full recovery")
    func expectedLossFullRecovery() {
        let model = RecoveryModel<Double>()

        let el = model.expectedLoss(
            defaultProbability: 0.02,
            recoveryRate: 1.0,
            exposure: 1000000.0
        )

        // Full recovery → No loss even if default occurs
        #expect(el == 0.0)
    }

    @Test("Recovery model with Float type")
    func recoveryModelFloat() {
        let model = RecoveryModel<Float>()

        let recoveryRate = RecoveryModel<Float>.standardRecoveryRate(
            seniority: .seniorSecured
        )

        let lgd = model.lossGivenDefault(recoveryRate: recoveryRate)

        #expect(lgd >= 0.0)
        #expect(lgd <= 1.0)
    }

    @Test("Round-trip: Spread → Implied Recovery → Credit Spread")
    func roundTripImpliedRecovery() {
        let model = RecoveryModel<Double>()
        let creditModel = CreditSpreadModel<Double>()

        // Start with known parameters
        let pd = 0.02
        let recoveryRate = 0.40
        let maturity = 5.0

        // Calculate spread
        let spread = creditModel.creditSpread(
            defaultProbability: pd,
            recoveryRate: recoveryRate,
            maturity: maturity
        )

        // Reverse engineer recovery rate from spread
        let impliedRecovery = model.impliedRecoveryRate(
            spread: spread,
            defaultProbability: pd,
            maturity: maturity
        )

        // Should recover original recovery rate
        #expect(abs(impliedRecovery - recoveryRate) < 0.01)
    }
}

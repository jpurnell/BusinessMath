//
//  Phase4OptimizationTests.swift
//  BusinessMathTests
//
//  Phase 4 of the contaminated-input sweep — shape G, `else { return T(0) }` after a validity
//  guard, across Optimization, Valuation, Stochastic, Derivatives and the Solver tier.
//
//  What distinguishes this area from the rest of the campaign: in an optimizer or a pricer the
//  fabricated zero does not merely mislead a reader, it *changes what the code does next*.
//  Measured against the unfixed source:
//
//      GradientDescentOptimizer(stepSize: 0).optimize(x², from: 10)
//          -> converged = true, optimalValue = 10.0        <- converged, having moved nowhere
//      ConvergenceDetector fed objective 0.0 then 5.0
//          -> hasConverged = true                          <- an unbounded jump read as settled
//      CommodityCollar(put: 60, call: 80).payoff(spotPrice: .nan)
//          -> 0.0                                          <- "the spot printed inside the band"
//      MertonModel(assetValue: .nan, …).creditSpread()
//          -> 0.0                                          <- "this credit is riskless"
//      bootstrapCreditCurve(tenors: [1, .nan, 3, 5], …)
//          -> three finite rates filed against the wrong tenors
//
//  Each defect test is paired with a control that passes on both sides of the fix; the controls
//  are what prove the suite discriminates rather than merely failing.
//

import Testing
import Foundation
@testable import BusinessMath

/// Elementwise comparison for a numeric sequence; `==` on `[Double]` is refused by the gate.
///
/// `isEqual(to:)` is IEEE equality, so `nan.isEqual(to: .nan)` is **false**. This sweep marks
/// unevaluable positions with `.nan`, so two NaNs in the same slot are an agreement.
private func agree(_ lhs: [Double], _ rhs: [Double]) -> Bool {
    lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.isEqual(to: $1) || ($0.isNaN && $1.isNaN) }
}

// MARK: - Optimizers: the zero that ends the search

@Suite("Phase 4 — a fabricated zero inside an optimizer")
struct Phase4OptimizerTests {

    /// `numericalGradient` returned `T(0)` when the perturbation collapsed, and `optimize`
    /// reads `abs(gradient) < tolerance` as convergence. The run therefore reported success
    /// from the caller's own starting guess.
    @Test("GradientDescent_WithACollapsedStep_DoesNotConvergeFromItsStartingPoint")
    func gradientDescentWithACollapsedStepDoesNotConvergeFromItsStartingPoint() {
        let optimizer = GradientDescentOptimizer<Double>(
            learningRate: 0.1,
            tolerance: 0.001,
            maxIterations: 40,
            momentum: 0.0,
            useNesterov: false,
            stepSize: 0.0
        )
        let objective = { @Sendable (x: Double) -> Double in x * x }
        let result = optimizer.optimize(
            objective: objective, constraints: [], initialGuess: 10.0, bounds: nil)

        #expect(!result.converged,
                "reported convergence with optimalValue \(result.optimalValue) after \(result.iterations) iterations")
        let movedNowhere: Bool = result.optimalValue.isEqual(to: 10.0)
        #expect(!(result.converged && movedNowhere),
                "converged at the starting guess without evaluating a slope")
    }

    /// Control: the same objective with a usable step still converges to the minimum.
    @Test("GradientDescent_WithTheDefaultStep_StillConverges")
    func gradientDescentWithTheDefaultStepStillConverges() {
        let optimizer = GradientDescentOptimizer<Double>(
            learningRate: 0.1,
            tolerance: 0.001,
            maxIterations: 1000,
            momentum: 0.0
        )
        let objective = { @Sendable (x: Double) -> Double in x * x }
        let result = optimizer.optimize(
            objective: objective, constraints: [], initialGuess: 10.0, bounds: nil)

        #expect(result.converged, "the clean control must still converge")
        let distance: Double = abs(result.optimalValue)
        #expect(distance < 0.1, "optimalValue \(result.optimalValue)")
    }

    /// A relative improvement measured against a zero baseline is not "no improvement".
    @Test("ImprovementFrom_AZeroBaseline_IsNotNoImprovement")
    func improvementFromAZeroBaselineIsNotNoImprovement() {
        let atZero = ConvergenceMetrics(
            iteration: 0, objectiveValue: 0.0, gradientNorm: 1e-9,
            stepSize: 0.01, relativeChange: 0.0)
        let movedAway = ConvergenceMetrics(
            iteration: 1, objectiveValue: 5.0, gradientNorm: 1e-9,
            stepSize: 0.01, relativeChange: 1.0)

        let reported: Double = movedAway.improvementFrom(atZero)
        #expect(reported.isNaN, "reported \(reported) for an unbounded relative change")

        // Control A: two objectives that are both exactly zero genuinely have not moved.
        let stillZero = ConvergenceMetrics(
            iteration: 1, objectiveValue: 0.0, gradientNorm: 1e-9,
            stepSize: 0.01, relativeChange: 0.0)
        let noMovement: Double = stillZero.improvementFrom(atZero)
        #expect(noMovement.isEqual(to: 0.0), "got \(noMovement)")

        // Control B: an ordinary pair is unchanged — |(10 - 8) / 10| = 0.2 exactly.
        let ten = ConvergenceMetrics(
            iteration: 0, objectiveValue: 10.0, gradientNorm: 1e-3,
            stepSize: 0.01, relativeChange: 0.1)
        let eight = ConvergenceMetrics(
            iteration: 1, objectiveValue: 8.0, gradientNorm: 1e-3,
            stepSize: 0.01, relativeChange: 0.1)
        let ordinary: Double = eight.improvementFrom(ten)
        let ordinaryError: Double = abs(ordinary - 0.2)
        #expect(ordinaryError < 1e-12, "got \(ordinary)")
    }

    /// The behavioural half: the detector must not call an unbounded jump "converged".
    @Test("ConvergenceDetector_FromAZeroObjective_DoesNotReportConvergence")
    func convergenceDetectorFromAZeroObjectiveDoesNotReportConvergence() {
        var detector = ConvergenceDetector(
            windowSize: 2, improvementThreshold: 1e-6, gradientThreshold: 1e-6)
        detector.update(with: ConvergenceMetrics(
            iteration: 0, objectiveValue: 0.0, gradientNorm: 1e-9,
            stepSize: 0.01, relativeChange: 0.0))
        detector.update(with: ConvergenceMetrics(
            iteration: 1, objectiveValue: 5.0, gradientNorm: 1e-9,
            stepSize: 0.01, relativeChange: 1.0))

        #expect(!detector.hasConverged,
                "the objective went from 0.0 to 5.0 and the detector called it settled")
    }

    /// Control: an objective that really has stopped moving is still reported as converged.
    @Test("ConvergenceDetector_OnASettledObjective_StillReportsConvergence")
    func convergenceDetectorOnASettledObjectiveStillReportsConvergence() {
        var detector = ConvergenceDetector(
            windowSize: 2, improvementThreshold: 1e-6, gradientThreshold: 1e-6)
        detector.update(with: ConvergenceMetrics(
            iteration: 0, objectiveValue: 1.0, gradientNorm: 1e-9,
            stepSize: 0.01, relativeChange: 0.0))
        detector.update(with: ConvergenceMetrics(
            iteration: 1, objectiveValue: 1.0, gradientNorm: 1e-9,
            stepSize: 0.01, relativeChange: 0.0))

        #expect(detector.hasConverged, "the clean control must still converge")
    }

    /// `fractionality` guarded only the upper end, so a negative index reached the subscript
    /// and trapped; and `0.0` is the value that means "already integral, do not branch here".
    @Test("Fractionality_OutsideTheSolution_IsNotAnIntegralVariable")
    func fractionalityOutsideTheSolutionIsNotAnIntegralVariable() {
        let spec = IntegerProgramSpecification(integerVariables: [0, 1])
        let solution = VectorN<Double>([0.4, 2.0])

        let below: Double = spec.fractionality(solution, at: -1)
        #expect(below.isNaN, "reaching this line at all is half the assertion; got \(below)")
        let above: Double = spec.fractionality(solution, at: 5)
        #expect(above.isNaN, "got \(above)")

        // Controls: |0.4 - round(0.4)| = 0.4, and min(0.4, 0.6) = 0.4. An exact integer is 0.
        let fractional: Double = spec.fractionality(solution, at: 0)
        let fractionalError: Double = abs(fractional - 0.4)
        #expect(fractionalError < 1e-12, "got \(fractional)")
        let integral: Double = spec.fractionality(solution, at: 1)
        #expect(integral.isEqual(to: 0.0), "got \(integral)")
    }
}

// MARK: - Valuation: the zero that prices risk away

@Suite("Phase 4 — a fabricated zero inside a valuation")
struct Phase4ValuationTests {

    private let asOf = Date(timeIntervalSince1970: 1_700_000_000)

    /// A credit spread of zero says the name trades flat to the risk-free curve.
    @Test("MertonCreditSpread_OnAnUnusableBalanceSheet_IsNotRiskless")
    func mertonCreditSpreadOnAnUnusableBalanceSheetIsNotRiskless() {
        let model = MertonModel(
            assetValue: Double.nan,
            assetVolatility: 0.25,
            debtFaceValue: 80_000_000.0,
            riskFreeRate: 0.05,
            maturity: 1.0)
        let spread: Double = model.creditSpread()
        #expect(spread.isNaN, "reported \(spread) — the credit read as riskless")
    }

    /// Control: the ordinary model is unchanged.
    @Test("MertonCreditSpread_OnACleanBalanceSheet_IsUnchanged")
    func mertonCreditSpreadOnACleanBalanceSheetIsUnchanged() {
        let model = MertonModel(
            assetValue: 100_000_000.0,
            assetVolatility: 0.25,
            debtFaceValue: 80_000_000.0,
            riskFreeRate: 0.05,
            maturity: 1.0)
        let spread: Double = model.creditSpread()
        #expect(spread > 0, "got \(spread)")
        #expect(spread < 0.10, "got \(spread)")
    }

    /// A par spread of zero says protection on this name is free.
    @Test("CDSFairSpread_OnAnUnusableHazardRate_IsNotFreeProtection")
    func cdsFairSpreadOnAnUnusableHazardRateIsNotFreeProtection() {
        let cds = CDS<Double>(
            notional: 10_000_000.0, spread: 0.01, maturity: 4.0,
            recoveryRate: 0.40, paymentFrequency: .annual)
        let periods: [Period] = [.year(2024), .year(2025), .year(2026), .year(2027)]
        let curve = TimeSeries<Double>(periods: periods, values: [0.95, 0.90, 0.86, 0.82])

        let spread: Double = cds.fairSpread(discountCurve: curve, hazardRate: Double.nan)
        #expect(spread.isNaN, "reported \(spread) — protection priced as free")
    }

    /// Control: a real hazard rate still produces a real spread.
    @Test("CDSFairSpread_OnACleanHazardRate_IsUnchanged")
    func cdsFairSpreadOnACleanHazardRateIsUnchanged() {
        let cds = CDS<Double>(
            notional: 10_000_000.0, spread: 0.01, maturity: 4.0,
            recoveryRate: 0.40, paymentFrequency: .annual)
        let periods: [Period] = [.year(2024), .year(2025), .year(2026), .year(2027)]
        let curve = TimeSeries<Double>(periods: periods, values: [0.95, 0.90, 0.86, 0.82])

        let spread: Double = cds.fairSpread(discountCurve: curve, hazardRate: 0.02)
        #expect(spread.isFinite, "got \(spread)")
        #expect(spread > 0, "got \(spread)")
    }

    /// A leg built from two curves of different lengths has no value to report, and
    /// `fairSpread` divides by exactly this number.
    @Test("CDSPremiumLeg_OnMismatchedCurves_IsNotWorthZero")
    func cdsPremiumLegOnMismatchedCurvesIsNotWorthZero() {
        let cds = CDS<Double>(
            notional: 10_000_000.0, spread: 0.01, maturity: 4.0,
            recoveryRate: 0.40, paymentFrequency: .annual)
        let discountPeriods: [Period] = [.year(2024), .year(2025), .year(2026), .year(2027)]
        let discount = TimeSeries<Double>(periods: discountPeriods, values: [0.95, 0.90, 0.86, 0.82])
        let survivalPeriods: [Period] = [.year(2024), .year(2025), .year(2026)]
        let survival = TimeSeries<Double>(periods: survivalPeriods, values: [0.99, 0.97, 0.95])

        let leg: Double = cds.premiumLegPV(
            discountCurve: discount, survivalProbabilities: survival)
        #expect(leg.isNaN, "reported \(leg) for two curves that are not one schedule")

        // Control: matched curves still price.
        let matched = TimeSeries<Double>(periods: discountPeriods, values: [0.99, 0.97, 0.95, 0.93])
        let clean: Double = cds.premiumLegPV(
            discountCurve: discount, survivalProbabilities: matched)
        #expect(clean > 0, "got \(clean)")
    }

    /// `nan > 1e-15` and `abs(nan) > 1e-15` are both false, so the two rate accessors took
    /// their "tenor is zero" / "the endpoints coincide" branches and answered with a real rate.
    @Test("DiscountCurveAccessors_OnAnUnusableTenor_AreUndefined")
    func discountCurveAccessorsOnAnUnusableTenorAreUndefined() {
        let curve = DiscountCurve(
            asOfDate: asOf, tenors: [1.0, 2.0, 5.0], discountFactors: [0.97, 0.94, 0.85])

        let zero: Double = curve.zeroRate(at: Double.nan)
        #expect(zero.isNaN, "reported \(zero) — the curve's short rate for a tenor nobody has")
        let forwardTo: Double = curve.forwardRate(from: 1.0, to: Double.nan)
        #expect(forwardTo.isNaN, "reported \(forwardTo)")
        let forwardFrom: Double = curve.forwardRate(from: Double.nan, to: 2.0)
        #expect(forwardFrom.isNaN, "reported \(forwardFrom)")
    }

    /// Control: the same curve at real tenors is untouched.
    @Test("DiscountCurveAccessors_OnRealTenors_AreUnchanged")
    func discountCurveAccessorsOnRealTenorsAreUnchanged() {
        let curve = DiscountCurve(
            asOfDate: asOf, tenors: [1.0, 2.0, 5.0], discountFactors: [0.97, 0.94, 0.85])

        let zero: Double = curve.zeroRate(at: 5.0)
        let expected: Double = -log(0.85) / 5.0
        let error: Double = abs(zero - expected)
        #expect(error < 1e-12, "got \(zero)")
        #expect(curve.forwardRate(from: 1.0, to: 2.0).isFinite)
    }

    /// A credit spread of zero for a curve with no quotes, and the longest-tenor quote for a
    /// maturity nobody can ask about.
    @Test("CreditCurveSpread_WithNoQuotesOrAnUnusableMaturity_IsUndefined")
    func creditCurveSpreadWithNoQuotesOrAnUnusableMaturityIsUndefined() {
        let empty = CreditCurve<Double>(
            spreads: TimeSeries<Double>(periods: [], values: []), recoveryRate: 0.40)
        let fromNothing: Double = empty.spread(maturity: 3.0)
        #expect(fromNothing.isNaN, "reported \(fromNothing) — flat to the risk-free curve")

        let quoted = CreditCurve<Double>(
            spreads: TimeSeries<Double>(
                periods: [.year(2025), .year(2026), .year(2027)],
                values: [0.010, 0.020, 0.030]),
            recoveryRate: 0.40)
        let fromNaN: Double = quoted.spread(maturity: Double.nan)
        #expect(fromNaN.isNaN, "reported \(fromNaN) — the ten-year quote for an unusable query")
    }

    /// Control: a single-quote curve is flat, and says so for any real maturity.
    @Test("CreditCurveSpread_OnAFlatCurve_IsUnchanged")
    func creditCurveSpreadOnAFlatCurveIsUnchanged() {
        let flat = CreditCurve<Double>(
            spreads: TimeSeries<Double>(periods: [.year(2025)], values: [0.015]),
            recoveryRate: 0.40)
        let measured: Double = flat.spread(maturity: 3.0)
        #expect(measured.isEqual(to: 0.015), "got \(measured)")
    }

    /// A zero implied volatility prices every option at intrinsic value and sorts to the
    /// bottom of any volatility screen.
    @Test("SABRImpliedVol_OnAnUnusableStrike_IsNotZero")
    func sabrImpliedVolOnAnUnusableStrikeIsNotZero() {
        let params = SABRParameters(alpha: 0.3, beta: 0.5, rho: -0.5, nu: 0.4)
        let contaminated: Double = params.impliedVol(
            forward: 100.0, strike: Double.nan, timeToExpiry: 1.0)
        #expect(contaminated.isNaN, "reported \(contaminated)")

        // Control A: a real smile point is unchanged.
        let clean: Double = params.impliedVol(
            forward: 100.0, strike: 100.0, timeToExpiry: 1.0)
        #expect(clean > 0, "got \(clean)")
        #expect(clean.isFinite, "got \(clean)")

        // Control B: the domain guard keeps its own meaning — a non-positive strike is
        // outside SABR, not contaminated, and still answers 0.
        let outsideDomain: Double = params.impliedVol(
            forward: 100.0, strike: -1.0, timeToExpiry: 1.0)
        #expect(outsideDomain.isEqual(to: 0.0), "got \(outsideDomain)")
    }

    /// The surface's `init` validates nothing, so an empty surface answered `0.0` and a grid
    /// that did not match its own axes indexed out of range.
    @Test("ImpliedVol_OnAnEmptyOrRaggedSurface_IsUndefined")
    func impliedVolOnAnEmptyOrRaggedSurfaceIsUndefined() {
        let empty = VolatilitySurface(underlier: "SPX", strikes: [], expiries: [], vols: [])
        let fromNothing: Double = empty.impliedVol(strike: 100.0, expiry: 0.5)
        #expect(fromNothing.isNaN, "reported \(fromNothing)")

        // One row of vols for two expiries: `vols[1]` used to trap.
        let ragged = VolatilitySurface(
            underlier: "SPX", strikes: [90.0, 100.0], expiries: [0.25, 0.5],
            vols: [[0.20, 0.21]])
        let fromRagged: Double = ragged.impliedVol(strike: 95.0, expiry: 0.375)
        #expect(fromRagged.isNaN, "reaching this line at all is half the assertion; got \(fromRagged)")
    }

    /// Control: a well-formed flat surface still interpolates to its own level.
    @Test("ImpliedVol_OnAWellFormedSurface_IsUnchanged")
    func impliedVolOnAWellFormedSurfaceIsUnchanged() {
        let surface = VolatilitySurface(
            underlier: "SPX", strikes: [90.0, 100.0], expiries: [0.25, 0.5],
            vols: [[0.20, 0.20], [0.20, 0.20]])
        let measured: Double = surface.impliedVol(strike: 95.0, expiry: 0.375)
        let error: Double = abs(measured - 0.20)
        #expect(error < 1e-12, "got \(measured)")
    }

    /// `value > runningMax` and `value < runningMin` are both false for a NaN, so a path made
    /// of unusable prices left the extrema at their sentinels and reported the empty path's
    /// payoff — an out-of-the-money option, averaged into a Monte Carlo price as an observation.
    @Test("LookbackPayoff_OnAContaminatedPath_IsNotAnEmptyPath")
    func lookbackPayoffOnAContaminatedPathIsNotAnEmptyPath() {
        var payoff = LookbackPayoff(optionType: .call)
        payoff.observe(value: Double.nan, time: 0.25)
        payoff.observe(value: 100.0, time: 0.50)
        let contaminated: Double = payoff.terminalValue(finalSpot: 110.0)
        #expect(contaminated.isNaN, "reported \(contaminated)")
    }

    /// Controls: the empty path keeps its documented zero, and a clean path is unchanged.
    @Test("LookbackPayoff_OnEmptyAndCleanPaths_IsUnchanged")
    func lookbackPayoffOnEmptyAndCleanPathsIsUnchanged() {
        let untouched = LookbackPayoff(optionType: .call)
        let empty: Double = untouched.terminalValue(finalSpot: 110.0)
        #expect(empty.isEqual(to: 0.0), "got \(empty)")

        var walked = LookbackPayoff(optionType: .call)
        walked.observe(value: 90.0, time: 0.25)
        walked.observe(value: 105.0, time: 0.50)
        // Floating-strike call: finalSpot - pathMin = 110 - 90 = 20.
        let measured: Double = walked.terminalValue(finalSpot: 110.0)
        let error: Double = abs(measured - 20.0)
        #expect(error < 1e-10, "got \(measured)")
    }

    /// A call price of zero is a worthless option: the position disappears from a revaluation.
    @Test("HestonCallPrice_OnAnUnusableSpot_IsNotWorthless")
    func hestonCallPriceOnAnUnusableSpotIsNotWorthless() {
        let heston = HestonProcess(
            name: "SPX", drift: 0.05, meanReversionSpeed: 2.0,
            longRunVariance: 0.04, volOfVol: 0.5, correlation: -0.7)
        let contaminated: Double = heston.europeanCallPrice(
            spot: Double.nan, strike: 100.0, riskFreeRate: 0.05,
            timeToExpiry: 1.0, initialVariance: 0.04)
        #expect(contaminated.isNaN, "reported \(contaminated)")

        // Control A: a real option still has a real price.
        let clean: Double = heston.europeanCallPrice(
            spot: 100.0, strike: 100.0, riskFreeRate: 0.05,
            timeToExpiry: 1.0, initialVariance: 0.04)
        #expect(clean > 0, "got \(clean)")

        // Control B: the documented degenerate case keeps its zero.
        let expired: Double = heston.europeanCallPrice(
            spot: 100.0, strike: 100.0, riskFreeRate: 0.05,
            timeToExpiry: 0.0, initialVariance: 0.04)
        #expect(expired.isEqual(to: 0.0), "got \(expired)")
    }
}

// MARK: - Bootstrapping: the ordering assertion

@Suite("Phase 4 — bootstrapCreditCurve and the sort it could not trust")
struct Phase4CreditBootstrapTests {

    /// The ordering control, and the one that fixes the expected value arithmetically: the
    /// first hazard rate is bootstrapped from the *shortest* tenor's spread as
    /// `λ ≈ s / (1 - R)`, whatever order the quotes arrive in.
    @Test("BootstrapCreditCurve_OrdersQuotesByTenor")
    func bootstrapCreditCurveOrdersQuotesByTenor() {
        let curve = bootstrapCreditCurve(
            tenors: [5.0, 1.0, 3.0],
            cdsSpreads: [0.020, 0.005, 0.012],
            recoveryRate: 0.40)
        let rates: [Double] = curve.hazardRates.valuesArray

        #expect(rates.count == 3, "got \(rates.count) rates")
        // 0.005 / (1 - 0.40) = 0.0083333…; the 5y quote would give 0.0333333…
        let expectedFirst: Double = 0.005 / 0.60
        let firstError: Double = abs(rates[0] - expectedFirst)
        #expect(firstError < 1e-12,
                "first rate \(rates[0]) is not the 1y quote's — the quotes came back unordered")
        let allReal: Bool = rates.allSatisfy { $0.isFinite }
        #expect(allReal, "got \(rates)")
    }

    /// `$0.0 < $1.0` is false in both directions for a NaN tenor, so `sorted` is unspecified
    /// and *valid* quotes come back out of order — then filed against periods by position.
    /// With the order untrustworthy, no rate on the curve is attributable to a tenor.
    @Test("BootstrapCreditCurve_WithANonNumericTenor_ReturnsNoAttributableRate")
    func bootstrapCreditCurveWithANonNumericTenorReturnsNoAttributableRate() {
        let curve = bootstrapCreditCurve(
            tenors: [1.0, Double.nan, 3.0, 5.0],
            cdsSpreads: [0.005, 0.010, 0.012, 0.020],
            recoveryRate: 0.40)
        let rates: [Double] = curve.hazardRates.valuesArray

        // Length preserved (contract §3.5), every position marked.
        let marked: [Double] = Array(repeating: Double.nan, count: 4)
        #expect(agree(rates, marked), "got \(rates)")

        // And the accessors downstream say so too, rather than quoting a scrambled curve.
        let spread: Double = curve.cdsSpread(maturity: 5.0)
        #expect(spread.isNaN, "reported \(spread)")
    }

    /// Control: an uncontaminated bootstrap is untouched, and its curve still prices.
    @Test("BootstrapCreditCurve_WithACleanCurve_IsUnchanged")
    func bootstrapCreditCurveWithACleanCurveIsUnchanged() {
        let curve = bootstrapCreditCurve(
            tenors: [1.0, 3.0, 5.0],
            cdsSpreads: [0.005, 0.012, 0.020],
            recoveryRate: 0.40)
        let rates: [Double] = curve.hazardRates.valuesArray
        #expect(rates.count == 3, "got \(rates.count)")
        let allReal: Bool = rates.allSatisfy { $0.isFinite }
        #expect(allReal, "got \(rates)")
        let survival: Double = curve.survivalProbability(time: 1.0)
        #expect(survival > 0, "got \(survival)")
        #expect(survival <= 1, "got \(survival)")
    }
}

// MARK: - Hedging: the zero that says "hedging changed nothing"

@Suite("Phase 4 — commodity hedges and the period nobody reported")
struct Phase4HedgingTests {

    private let months: [Period] = [
        Period.month(year: 2026, month: 1),
        Period.month(year: 2026, month: 2),
        Period.month(year: 2026, month: 3)
    ]

    /// Every comparison against a NaN is false, so an unobservable spot fell through both
    /// arms of the collar and reported the *middle* of the payoff range as a measurement.
    @Test("CollarPayoff_OnAnUnobservableSpot_IsNotInsideTheBand")
    func collarPayoffOnAnUnobservableSpotIsNotInsideTheBand() {
        let collar = CommodityCollar<Double>(
            underlier: "WTI", putStrike: 60.0, callStrike: 80.0,
            quantity: 10_000.0, settlementPeriods: months)

        let payoff: Double = collar.payoff(spotPrice: Double.nan)
        #expect(payoff.isNaN, "reported \(payoff) — the spot read as inside the collar band")
        let settlement: Double = collar.settlement(spotPrice: Double.nan)
        #expect(settlement.isNaN, "reported \(settlement)")
    }

    /// Controls: all three zones of a real collar are unchanged.
    @Test("CollarPayoff_OnRealSpots_IsUnchanged")
    func collarPayoffOnRealSpotsIsUnchanged() {
        let collar = CommodityCollar<Double>(
            underlier: "WTI", putStrike: 60.0, callStrike: 80.0,
            quantity: 10_000.0, settlementPeriods: months)

        let below: Double = collar.payoff(spotPrice: 50.0)
        #expect(abs(below - 10.0) < 1e-12, "got \(below)")
        let inside: Double = collar.payoff(spotPrice: 70.0)
        #expect(inside.isEqual(to: 0.0), "got \(inside)")
        let above: Double = collar.payoff(spotPrice: 90.0)
        #expect(abs(above + 10.0) < 1e-12, "got \(above)")
    }

    /// `totalProduction` is supplied independently of `spotPrices`, so an uncovered period took
    /// the `production == .zero` branch and reported `effective = spot` — "hedging changed
    /// nothing" — for a period whose production is simply unknown.
    @Test("EffectiveRealizedPrice_WithAnUnreportedPeriod_OmitsItRatherThanQuotingSpot")
    func effectiveRealizedPriceWithAnUnreportedPeriodOmitsItRatherThanQuotingSpot() throws {
        let swap = CommoditySwap<Double>(
            underlier: "WTI", fixedPrice: 72.0, notionalVolume: 10_000.0,
            settlementPeriods: months)
        var program = HedgingProgram<Double>()
        program.addSwap(swap)

        let spotPrices = TimeSeries<Double>(periods: months, values: [60.0, 60.0, 60.0])
        // March is quoted but never produced.
        let partial = TimeSeries<Double>(
            periods: [months[0], months[1]], values: [10_000.0, 10_000.0])

        let effective = program.effectiveRealizedPrice(
            spotPrices: spotPrices, totalProduction: partial)

        let covered: [Period] = effective.periods
        #expect(covered.count == 2, "got \(covered.count) periods: \(covered)")
        #expect(!covered.contains(months[2]),
                "March was valued although its production was never reported — `effective = spot`")

        // The covered periods are untouched: 60 + 120000/10000 = 72.
        let january: Double = try #require(effective[months[0]])
        #expect(abs(january - 72.0) < 1e-9, "got \(january)")
    }

    /// Control: full production coverage still prices every period.
    @Test("EffectiveRealizedPrice_WithFullCoverage_IsUnchanged")
    func effectiveRealizedPriceWithFullCoverageIsUnchanged() throws {
        let swap = CommoditySwap<Double>(
            underlier: "WTI", fixedPrice: 72.0, notionalVolume: 10_000.0,
            settlementPeriods: months)
        var program = HedgingProgram<Double>()
        program.addSwap(swap)

        let spotPrices = TimeSeries<Double>(periods: months, values: [60.0, 60.0, 60.0])
        let production = TimeSeries<Double>(
            periods: months, values: [10_000.0, 10_000.0, 10_000.0])

        let effective = program.effectiveRealizedPrice(
            spotPrices: spotPrices, totalProduction: production)

        #expect(effective.periods.count == 3, "got \(effective.periods.count)")
        for month in months {
            let measured: Double = try #require(effective[month])
            #expect(abs(measured - 72.0) < 1e-9, "got \(measured) for \(month)")
        }
    }
}

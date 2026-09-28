//
//  ContaminatedInferenceTests.swift
//  BusinessMathTests
//
//  The last batch from the parallel probe pass. Everything here was measured before it was
//  touched, and four other candidates were measured and left alone as not defects.
//
//  | call                                    | clean    | before the fix |
//  | minimumDetectableEffect, NaN baseline   | 0.049995 | 0.0            |
//  | Project.roi, NaN capitalRequired        | —        | 0.0            |
//  | Project.roi ranking, NaN npv            | [D,B,A]  | [B,A,C,D]      |
//  | survivalProbability(time: nan)          | —        | 1.0            |
//  | discountFactor(at: nan)                 | —        | 1.0            |
//  | bayesianICC on contaminated ratings     | 0.861    | 0.0 (400/400)  |
//
//  The sizing one is the sharpest: `minimumDetectableEffect` returned **0** — "this sample size
//  detects an arbitrarily small effect" — for a NaN baseline, and returned the same 0 at
//  `perArm: 1` as at `perArm: 1565`. An answer independent of sample size is the tell. Its two
//  siblings on the same object, `achievedPower` and `sampleSizePerArm`, already refused it
//  through `validatedProportions`; the defect was a range check written as `!(x < 0) && !(x > 1)`,
//  which a `nan` passes.
//
//  `bayesianICC` produced 400 draws of exactly `0.0` — mean 0, median 0, credible interval
//  [0, 0] — a confident "poor agreement" finding with a tight interval, next to a
//  `sigmaSubjectsMean` of `nan` in the same result.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Inference and allocation on input they cannot use")
struct ContaminatedInferenceTests {

    // MARK: - Experiment sizing

    @Test("MinimumDetectableEffect_UnusableBaseline_IsRefused")
    func minimumDetectableEffectUnusableBaselineIsRefused() {
        let design = Experiment<Double>.twoProportion(baseline: .nan, minimumDetectableEffect: 0.05)
        #expect(throws: ExperimentError.self) {
            try design.minimumDetectableEffect(perArm: 1565, power: 0.80, alpha: 0.05)
        }
    }

    /// The siblings that were always right.
    @Test("ExperimentSiblings_AlreadyRefused")
    func experimentSiblingsAlreadyRefused() {
        let design = Experiment<Double>.twoProportion(baseline: .nan, minimumDetectableEffect: 0.05)
        #expect(throws: ExperimentError.self) {
            try design.achievedPower(perArm: 1565, alpha: 0.05, tails: .two)
        }
    }

    @Test("MinimumDetectableEffect_CleanDesign_Unchanged")
    func minimumDetectableEffectCleanDesignUnchanged() throws {
        let design = Experiment<Double>.twoProportion(baseline: 0.50, minimumDetectableEffect: 0.05)
        let mde = try design.minimumDetectableEffect(perArm: 1565, power: 0.80, alpha: 0.05)
        #expect(abs(mde - 0.049995) < 1e-5, "got \(mde)")
    }

    // MARK: - Capital allocation

    @Test("ROI_UnusableProject_IsUndefined")
    func roiUnusableProjectIsUndefined() {
        typealias P = CapitalAllocationOptimizer<Double>.Project
        #expect(P(name: "C", npv: 80, capitalRequired: .nan).roi.isNaN)
        #expect(P(name: "C", npv: .nan, capitalRequired: 40).roi.isNaN)
        #expect(P(name: "E", npv: -50, capitalRequired: 25).roi.isEqual(to: -2.0),
                "a value-destroying project keeps its real, negative ROI")
    }

    /// A non-finite project must not take the knapsack down with it.
    @Test("IntegerAllocation_DoesNotTrapOnAnUnsizableProject")
    func integerAllocationDoesNotTrapOnAnUnsizableProject() {
        typealias P = CapitalAllocationOptimizer<Double>.Project
        let optimizer = CapitalAllocationOptimizer<Double>()
        let a = P(name: "A", npv: 100, capitalRequired: 50)
        let d = P(name: "D", npv: 70, capitalRequired: 20)
        let unsizable = P(name: "C", npv: 80, capitalRequired: .nan)
        // Reaching this line at all is half the assertion: `Int(.nan)` used to trap here.
        let withUnsizable = optimizer.optimizeIntegerProjects(
            projects: [a, unsizable, d], budget: 60)
        let control = optimizer.optimizeIntegerProjects(projects: [a, d], budget: 60)
        #expect(withUnsizable.projectsSelected == control.projectsSelected,
                "got \(withUnsizable.projectsSelected) against \(control.projectsSelected)")
        #expect(withUnsizable.totalNPV.isEqual(to: control.totalNPV))
        #expect(!control.projectsSelected.isEmpty, "and the control really does allocate")
    }

    // MARK: - Credit and curves

    @Test("SurvivalProbability_UnusableTime_IsUndefined")
    func survivalProbabilityUnusableTimeIsUndefined() {
        let curve = HazardRateCurve(hazardRates: TimeSeries(
            periods: [.year(2024), .year(2025), .year(2026)], values: [0.01, 0.015, 0.02]))
        #expect(curve.survivalProbability(time: .nan).isNaN, "1.0 reads as certain survival")
        #expect(curve.forwardHazardRate(from: 1.0, to: .nan).isNaN)
        #expect(curve.survivalProbability(time: 0.0).isEqual(to: 1.0),
                "time zero genuinely is certain survival")
        #expect(abs(curve.survivalProbability(time: 3.0) - 0.955997) < 1e-5)
    }

    @Test("DiscountFactor_UnusableTenor_IsUndefined")
    func discountFactorUnusableTenorIsUndefined() {
        let curve = DiscountCurve(asOfDate: Date(timeIntervalSince1970: 1_700_000_000),
                                  tenors: [1.0, 2.0, 5.0], discountFactors: [0.97, 0.94, 0.86])
        #expect(curve.discountFactor(at: .nan).isNaN)
        #expect(curve.discountFactor(at: 0.0).isEqual(to: 1.0), "DF(0) = 1 is correct and stays")
    }

    // MARK: - Bayesian ICC

    @Test("BayesianICC_ContaminatedRatings_AreRefused")
    func bayesianICCContaminatedRatingsAreRefused() {
        var ratings: [[Double]] = [[9, 8, 8], [7, 6, 7], [5, 6, 5], [8, 9, 8], [6, 5, 6], [4, 4, 5]]
        ratings[2][1] = .nan
        let config = GibbsConfig<Double>(iterations: 400, burnIn: 200, thinning: 1,
                                         chains: 2, seed: 20_260_928)
        #expect(throws: BusinessMathError.self) {
            try bayesianICC(ratings, model: .twoWayRandom, config: config)
        }
    }

    @Test("BayesianICC_CleanRatings_Unchanged")
    func bayesianICCCleanRatingsUnchanged() throws {
        let ratings: [[Double]] = [[9, 8, 8], [7, 6, 7], [5, 6, 5], [8, 9, 8], [6, 5, 6], [4, 4, 5]]
        let config = GibbsConfig<Double>(iterations: 400, burnIn: 200, thinning: 1,
                                         chains: 2, seed: 20_260_928)
        let result = try bayesianICC(ratings, model: .twoWayRandom, config: config)
        #expect(result.iccMean > 0.8, "got \(result.iccMean)")
        #expect(result.iccSamples.allSatisfy { $0.isFinite })
    }

    // MARK: - Diagnosis, not just refusal

    /// Contamination and a genuinely constant column produced identical error text.
    @Test("CCC_ReportsContaminationNotZeroVariance")
    func cccReportsContaminationNotZeroVariance() {
        let y: [Double] = [1.1, 1.9, 3.2, 3.8, 5.1]
        var xNaN: [Double] = [1, 2, 3, 4, 5]
        xNaN[2] = .nan
        do {
            _ = try concordanceCorrelationCoefficient(xNaN, y)
            Issue.record("expected a throw")
        } catch let error as BusinessMathError {
            #expect(!"\(error)".contains("zero variance"), "got \(error)")
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    /// And a genuinely constant column must still say so.
    @Test("CCC_StillDetectsZeroVariance")
    func cccStillDetectsZeroVariance() {
        let y: [Double] = [1.1, 1.9, 3.2, 3.8, 5.1]
        do {
            _ = try concordanceCorrelationCoefficient([3, 3, 3, 3, 3], y)
            Issue.record("expected a throw")
        } catch let error as BusinessMathError {
            #expect("\(error)".contains("zero variance"), "got \(error)")
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    /// All three post-hoc tests now refuse alike, and name the real reason.
    @Test("PostHocTests_RefuseContaminatedGroupsAlike")
    func postHocTestsRefuseContaminatedGroupsAlike() throws {
        let clean: [[Double]] = [[10, 12, 11, 13], [20, 22, 21, 23], [30, 31, 29, 32]]
        var contaminated = clean
        contaminated[0][2] = .nan
        let anova = try oneWayANOVA(clean)
        #expect(throws: BusinessMathError.self) { try tukeyHSD(contaminated, anova: anova) }
        #expect(throws: BusinessMathError.self) { try bonferroniPostHoc(contaminated, anova: anova) }
        #expect(throws: BusinessMathError.self) { try scheffePostHoc(contaminated, anova: anova) }
    }

    @Test("PostHocTests_CleanGroups_Unchanged")
    func postHocTestsCleanGroupsUnchanged() throws {
        let clean: [[Double]] = [[10, 12, 11, 13], [20, 22, 21, 23], [30, 31, 29, 32]]
        let anova = try oneWayANOVA(clean)
        let result = try tukeyHSD(clean, anova: anova)
        #expect(result.comparisons.count == 3)
        #expect(result.comparisons.allSatisfy { $0.pValue.isFinite })
    }
}

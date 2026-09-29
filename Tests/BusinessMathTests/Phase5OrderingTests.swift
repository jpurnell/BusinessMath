//
//  Phase5OrderingTests.swift
//  BusinessMathTests
//
//  Phase 5, shape H of the contaminated-input sweep: `min()`, `max()`, `min(by:)`,
//  `max(by:)` and `sorted()` on floating-point collections.
//
//  Two failures come out of one fact, and they look nothing alike.
//
//  **A `nan` is silently skipped.** `Sequence.min()` seeds with the first element and
//  replaces it only on `e < result`; every comparison against a `nan` is false, so the
//  offending element is skipped *unless it happens to land in slot zero*. Measured here, on
//  this machine, in the probe that opened this phase:
//
//      [nan, 1, 2].min()  ->  nan
//      [1, nan, 2].min()  ->  1.0
//      [1, 2, nan].max()  ->  2.0
//      [nan, 1, 2].max()  ->  nan
//
//  Nobody designed that. It is an artifact of iteration order, and it is why the extremum
//  comes back finite and confident, computed over the values that could be ordered, with
//  nothing in the answer to say one was dropped.
//
//  **`sorted()` becomes unspecified.** A comparator that is not a strict weak ordering does
//  not merely misplace the `nan` — the *valid* elements come back out of order. Measured:
//
//      [3, 1, nan, 2, 5, 4].sorted()          ->  [1, 3, nan, 2, 4, 5]
//      [1, 2, 3, nan, 5, 6, 7, 8]  descending ->  [3, 2, 1, nan, 8, 7, 6, 5]
//      [0.1, 0.9, nan, 0.4, 0.3]   descending ->  [0.9, 0.1, nan, 0.4, 0.3]
//
//  The second line is `Array.rank()`'s sort, and it means the smallest of eight observations
//  was ranked third best while the largest was ranked last — seven finite ranks, all wrong,
//  all plausible. This is the dangerous half: marking the output does not help when the
//  damage is a permutation, so these sites are screened *before* the sort rather than after.
//
//  Every expected value below is either exact by construction (a count over a known sample)
//  or derived arithmetically in the test. The controls are the point: each fix is paired with
//  a clean case that passed before the change and must still pass after it.
//

import Testing
import Foundation
import Numerics
import BusinessMathDSL
@testable import BusinessMath

@Suite("Phase 5 — ordering and extrema on contaminated samples")
struct Phase5OrderingTests {

    /// Elementwise agreement.
    ///
    /// `isEqual(to:)` is IEEE equality, so `nan.isEqual(to: .nan)` is **false**. This sweep
    /// deliberately marks unusable positions with `.nan`, so two NaNs in the same slot are an
    /// agreement rather than a mismatch; without this clause a marked position could never
    /// match anything. The count is part of the claim.
    private func agree(_ lhs: [Double], _ rhs: [Double]) -> Bool {
        lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.isEqual(to: $1) || ($0.isNaN && $1.isNaN) }
    }

    // MARK: - The mechanism itself

    /// The permutation, stated as a test rather than as a comment.
    ///
    /// Everything in this suite rests on this: a sort given an unorderable element does not
    /// isolate the damage to that element. If this ever stops holding — a future standard
    /// library that validates its comparator, say — several of the guards below become
    /// unnecessary, and this test is where that would be noticed first.
    @Test("Sorting_AnUnorderableElement_MovesTheValidOnes")
    func sortingAnUnorderableElementMovesTheValidOnes() {
        let contaminated: [Double] = [3, 1, .nan, 2, 5, 4]
        let sorted = contaminated.sorted()

        // The finite entries, in the order the sort left them.
        let finite: [Double] = sorted.filter { $0.isFinite }
        let ascending: Bool = zip(finite, finite.dropFirst()).allSatisfy { $0 <= $1 }
        #expect(!ascending, "the valid elements were expected out of order, got \(finite)")

        // The control: the same values with nothing unorderable in them sort correctly.
        let clean: [Double] = [3, 1, 6, 2, 5, 4]
        let cleanSorted = clean.sorted()
        #expect(agree(cleanSorted, [1, 2, 3, 4, 5, 6]), "got \(cleanSorted)")
    }

    // MARK: - Array.rank() / reverseRank() / tauAdjustment()

    /// The headline of this phase.
    ///
    /// An earlier pass fixed the *length* invariant here — one rank per observation, which
    /// stopped `spearmansRho` trapping — and left the ordering alone. Measured against that
    /// source: `[1, 2, 3, nan, 5, 6, 7, 8].rank()` returned `[3, 2, 1, nan, 8, 7, 6, 5]`.
    /// `rank()` is descending by magnitude, so `8` — the largest value in the sample — was
    /// given rank 8, dead last, and `1` — the smallest — was given rank 3.
    @Test("Rank_DoesNotHandOutRanksReadOffAnArbitraryPermutation")
    func rankDoesNotHandOutRanksReadOffAnArbitraryPermutation() {
        var contaminated: [Double] = [1, 2, 3, 4, 5, 6, 7, 8]
        contaminated[3] = .nan

        let ranks = contaminated.rank()
        #expect(ranks.count == contaminated.count, "the length invariant still holds")

        // The specific wrong answer this fix removes.
        let wasRankedBest: Bool = ranks[7].isEqual(to: 8.0)
        #expect(!wasRankedBest, "8 is the largest value and must not be ranked last: \(ranks)")

        let allUnranked: Bool = ranks.allSatisfy { $0.isNaN }
        #expect(allUnranked, "ranks are relative; an unorderable sample has none: \(ranks)")
    }

    /// Control: clean data ranks exactly as it always did, both ways round.
    @Test("Rank_CleanSample_Unchanged")
    func rankCleanSampleUnchanged() {
        let clean: [Double] = [1, 2, 3, 4, 5, 6, 7, 8]
        let ranks = clean.rank()
        let reverse = clean.reverseRank()

        // Descending by magnitude: the largest takes rank 1, and rank i + reverseRank i is
        // n + 1 at every position when there are no ties.
        #expect(agree(ranks, [8, 7, 6, 5, 4, 3, 2, 1]), "got \(ranks)")
        let n: Double = Double(clean.count)
        let sums: [Double] = zip(ranks, reverse).map { $0 + $1 }
        let allComplementary: Bool = sums.allSatisfy { $0.isEqual(to: n + 1.0) }
        #expect(allComplementary, "rank + reverseRank should be n + 1 everywhere: \(sums)")
    }

    /// `0` is this function's "no ties to correct for", so an undercount is invisible.
    @Test("TauAdjustment_UnorderableSample_IsNotZero")
    func tauAdjustmentUnorderableSampleIsNotZero() {
        let contaminated: [Double] = [100, 80, 80, .nan, 40]
        let unorderableAdjustment: Double = contaminated.tauAdjustment()
        #expect(unorderableAdjustment.isNaN, "got \(unorderableAdjustment)")

        // Control, derived rather than recalled: one tie group of two, and the correction for
        // a group of size g is (g³ - g)/12.
        let clean: [Double] = [100, 80, 80, 40]
        let g: Double = 2
        let expected: Double = (g * g * g - g) / 12.0
        let measured: Double = clean.tauAdjustment()
        #expect(abs(measured - expected) < 1e-12, "expected \(expected), got \(measured)")
    }

    // MARK: - empiricalCDF and its complement

    /// The two tails stopped summing to one, and both were biased low.
    @Test("EmpiricalCDF_UnorderableObservation_IsNotCountedAsBelow")
    func empiricalCDFUnorderableObservationIsNotCountedAsBelow() {
        let contaminated: [Double] = [1, 2, .nan, 4, 5]
        let below: Double = empiricalCDF(3.0, data: contaminated)
        let above: Double = empiricalComplementaryCDF(3.0, data: contaminated)
        #expect(below.isNaN, "got \(below)")
        #expect(above.isNaN, "got \(above)")

        // A query that cannot be placed is the same question from the other side.
        let unorderableQuery: Double = empiricalCDF(Double.nan, data: [1.0, 2.0, 3.0])
        #expect(unorderableQuery.isNaN, "got \(unorderableQuery)")
    }

    /// Control: exact by construction — 3 of 5 observations are at or below 3.
    @Test("EmpiricalCDF_CleanSample_TailsSumToOne")
    func empiricalCDFCleanSampleTailsSumToOne() {
        let clean: [Double] = [1, 2, 3, 4, 5]
        let below: Double = empiricalCDF(3.0, data: clean)
        let above: Double = empiricalComplementaryCDF(3.0, data: clean)
        let expectedBelow: Double = 3.0 / 5.0
        let expectedAbove: Double = 2.0 / 5.0
        #expect(abs(below - expectedBelow) < 1e-15, "got \(below)")
        #expect(abs(above - expectedAbove) < 1e-15, "got \(above)")
        let total: Double = below + above
        #expect(abs(total - 1.0) < 1e-15, "the two tails must partition the sample: \(total)")
    }

    /// The between form has a second failure the tails do not: the swap.
    ///
    /// `min(a, b)` is `b < a ? b : a`, so `min(nan, 5)` is `nan` while `min(5, nan)` is `5` —
    /// which bound survives depends on the order the caller wrote the arguments in.
    @Test("EmpiricalProbabilityBetween_UnorderableBoundOrObservation")
    func empiricalProbabilityBetweenUnorderableBoundOrObservation() {
        let clean: [Double] = [1, 2, 3, 4, 5]
        let lowFirst: Double = empiricalProbabilityBetween(Double.nan, 4.0, data: clean)
        let highFirst: Double = empiricalProbabilityBetween(4.0, Double.nan, data: clean)
        #expect(lowFirst.isNaN, "got \(lowFirst)")
        #expect(highFirst.isNaN, "argument order must not change the verdict: \(highFirst)")

        let contaminated: [Double] = [1, 2, .nan, 4, 5]
        let withHole: Double = empiricalProbabilityBetween(2.0, 4.0, data: contaminated)
        #expect(withHole.isNaN, "got \(withHole)")

        // Control: strictly between 2 and 4 is the single observation 3, out of five.
        let measured: Double = empiricalProbabilityBetween(2.0, 4.0, data: clean)
        let expected: Double = 1.0 / 5.0
        #expect(abs(measured - expected) < 1e-15, "got \(measured)")
    }

    // MARK: - BayesianICCResult.probabilityAbove

    private func iccResult(samples: [Double]) -> BayesianICCResult<Double> {
        BayesianICCResult(
            sigmaSubjectsSamples: [1.0],
            sigmaRatersSamples: [1.0],
            sigmaErrorSamples: [1.0],
            iccSamples: samples,
            iccMean: 0.5,
            iccMedian: 0.5,
            iccCredibleInterval: CredibleInterval(lower: 0.1, upper: 0.9),
            sigmaSubjectsMean: 1.0,
            sigmaRatersMean: 1.0,
            sigmaErrorMean: 1.0,
            rHat: nil,
            effectiveSampleSizeCount: samples.count
        )
    }

    /// A posterior probability biased toward zero is biased toward "the ICC is below the
    /// threshold", which is the conclusion that stops a reliability study.
    @Test("ProbabilityAbove_UnusableDraw_IsNotCountedAsBelowThreshold")
    func probabilityAboveUnusableDrawIsNotCountedAsBelowThreshold() {
        let contaminated = iccResult(samples: [0.9, 0.8, .nan, 0.85])
        let unusable: Double = contaminated.probabilityAbove(0.75)
        #expect(unusable.isNaN, "got \(unusable)")

        // Control: three of four draws exceed 0.75, exactly.
        let clean = iccResult(samples: [0.9, 0.8, 0.5, 0.85])
        let measured: Double = clean.probabilityAbove(0.75)
        let expected: Double = 3.0 / 4.0
        #expect(abs(measured - expected) < 1e-15, "got \(measured)")
    }

    // MARK: - VectorN extrema, and the distance metric that disagreed with its sibling

    /// `manhattanDistance` reaches its answer with `reduce` and propagates; `chebyshevDistance`
    /// reached its answer with `max()` and skipped. Two metrics over the same pair of vectors
    /// disagreeing about whether those vectors can be compared at all is the inconsistency the
    /// contract exists to remove.
    @Test("ChebyshevDistance_AgreesWithItsSiblingAboutUnusableInput")
    func chebyshevDistanceAgreesWithItsSiblingAboutUnusableInput() {
        let a = VectorN<Double>([1.0, 2.0])
        let contaminated = VectorN<Double>([4.0, Double.nan])
        #expect(a.manhattanDistance(to: contaminated).isNaN, "the sibling already propagated")
        let unusableChebyshev: Double = a.chebyshevDistance(to: contaminated)
        #expect(unusableChebyshev.isNaN, "got \(unusableChebyshev)")

        // Control, derived: differences are 3 and 4, so L1 is 7 and L∞ is 4.
        let b = VectorN<Double>([4.0, 6.0])
        let manhattan: Double = a.manhattanDistance(to: b)
        let chebyshev: Double = a.chebyshevDistance(to: b)
        #expect(abs(manhattan - 7.0) < 1e-12, "got \(manhattan)")
        #expect(abs(chebyshev - 4.0) < 1e-12, "got \(chebyshev)")
    }

    /// Position-dependent by construction, so both placements are tested.
    @Test("VectorNExtrema_DoNotDependOnWhereTheUnusableComponentSits")
    func vectorNExtremaDoNotDependOnWhereTheUnusableComponentSits() {
        let first = VectorN<Double>([Double.nan, 1.0, 2.0])
        let middle = VectorN<Double>([1.0, Double.nan, 2.0])
        let last = VectorN<Double>([1.0, 2.0, Double.nan])

        for vector in [first, middle, last] {
            let low = vector.min
            let high = vector.max
            #expect(low?.isNaN == true, "min: \(String(describing: low))")
            #expect(high?.isNaN == true, "max: \(String(describing: high))")
        }

        // Controls: an ordinary vector still reports its extrema, and an empty one still
        // reports nothing at all — a different answer from "cannot be measured".
        let clean = VectorN<Double>([3.0, 1.0, 2.0])
        #expect(clean.min?.isEqual(to: 1.0) == true, "got \(String(describing: clean.min))")
        #expect(clean.max?.isEqual(to: 3.0) == true, "got \(String(describing: clean.max))")
        let empty = VectorN<Double>([Double]())
        #expect(empty.min == nil)
        #expect(empty.max == nil)
    }

    /// The projection is a sort followed by a prefix walk, so an unorderable coordinate moves
    /// the threshold every output coordinate is computed from — and `Double.maximum(nan, 0)`
    /// is **`0`**, so the unusable coordinate used to come back as a weight of exactly zero:
    /// a confident instruction to hold none of that asset.
    @Test("SimplexProjection_UnorderableCoordinate_DoesNotBecomeAZeroWeight")
    func simplexProjectionUnorderableCoordinateDoesNotBecomeAZeroWeight() {
        let contaminated = VectorN<Double>([0.1, 0.9, Double.nan, 0.4, 0.3])
        let projected = contaminated.simplexProjection().toArray()
        #expect(projected.count == 5, "the length invariant is part of the contract")
        let allUnusable: Bool = projected.allSatisfy { $0.isNaN }
        #expect(allUnusable, "got \(projected)")

        // Control: a point already on the simplex projects to itself, and the sum is one.
        let onSimplex = VectorN<Double>([0.5, 0.3, 0.2])
        let unchanged = onSimplex.simplexProjection().toArray()
        #expect(agree(unchanged, [0.5, 0.3, 0.2]), "got \(unchanged)")
        let total: Double = unchanged.reduce(0, +)
        #expect(abs(total - 1.0) < 1e-12, "got \(total)")
    }

    // MARK: - Branch and bound

    /// `nil` here means "all integer-feasible", which ends the branching search.
    @Test("MostFractionalVariable_UnusableValue_IsNotReportedAsIntegerFeasible")
    func mostFractionalVariableUnusableValueIsNotReportedAsIntegerFeasible() {
        let spec = IntegerProgramSpecification(integerVariables: [0, 1, 2])
        let contaminated = VectorN<Double>([1.0, Double.nan, 3.0])
        let selected = spec.mostFractionalVariable(contaminated)
        #expect(selected == 1, "the unusable variable must be branched on: \(String(describing: selected))")

        // An infinite value is no more an integer than a `nan` is.
        let infinite = VectorN<Double>([1.0, 2.0, Double.infinity])
        let infiniteChoice = spec.mostFractionalVariable(infinite)
        #expect(infiniteChoice == 2, "got \(String(describing: infiniteChoice))")

        // Controls: a genuinely integral point still ends the search, and a fractional one
        // still picks the variable closest to 0.5.
        let integral = VectorN<Double>([1.0, 2.0, 3.0])
        #expect(spec.mostFractionalVariable(integral) == nil)
        let fractional = VectorN<Double>([1.0, 2.4, 3.0])
        let fractionalChoice = spec.mostFractionalVariable(fractional)
        #expect(fractionalChoice == 1, "got \(String(describing: fractionalChoice))")
    }

    // MARK: - Stress testing

    private func stressResults(npvs: [Double]) -> StressTestReport<Double> {
        let results = npvs.enumerated().map { index, npv in
            ScenarioResult(
                scenario: StressScenario(name: "S\(index)", description: "", shocks: [:]),
                baselineNPV: 100.0,
                scenarioNPV: npv,
                impact: npv - 100.0
            )
        }
        return StressTestReport(results: results)
    }

    /// A stress report exists to be acted on at the worst-case end of it, and `min(by:)`
    /// returned a *named* scenario chosen by where in the array the unvalued one happened to
    /// sit — the first slot returns the unvalued scenario, anywhere else returns the best of
    /// the rest described as the worst.
    @Test("StressReport_WorstCase_IsNotNamedFromAPartiallyValuedSet")
    func stressReportWorstCaseIsNotNamedFromAPartiallyValuedSet() {
        let leading = stressResults(npvs: [.nan, 90.0, 40.0])
        let trailing = stressResults(npvs: [90.0, 40.0, .nan])
        #expect(leading.worstCase == nil)
        #expect(trailing.worstCase == nil, "position must not decide whether an answer exists")
        #expect(leading.bestCase == nil)
        #expect(trailing.bestCase == nil)

        // Control: an ordinary report still names both ends.
        let clean = stressResults(npvs: [90.0, 40.0, 120.0])
        #expect(clean.worstCase?.scenarioNPV.isEqual(to: 40.0) == true,
                "got \(String(describing: clean.worstCase?.scenarioNPV))")
        #expect(clean.bestCase?.scenarioNPV.isEqual(to: 120.0) == true,
                "got \(String(describing: clean.bestCase?.scenarioNPV))")
    }

    /// The summary's whole claim is "worst first", so the valid rows keeping their order is
    /// the assertion that matters — not that the unusable one is handled.
    @Test("StressReport_Summary_KeepsTheValidScenariosInOrder")
    func stressReportSummaryKeepsTheValidScenariosInOrder() {
        let report = stressResults(npvs: [90.0, .nan, 40.0, 120.0])
        let summary = report.summary

        // Impacts are -10, nan, -60 and +20, so worst-first is S2, S0, S3.
        guard let worstAt = summary.range(of: "Scenario: S2"),
              let middleAt = summary.range(of: "Scenario: S0"),
              let bestAt = summary.range(of: "Scenario: S3"),
              let unusableAt = summary.range(of: "Scenario: S1") else {
            Issue.record("every scenario should appear in the summary: \(summary)")
            return
        }
        #expect(worstAt.lowerBound < middleAt.lowerBound, "S2 is the worst and must lead")
        #expect(middleAt.lowerBound < bestAt.lowerBound, "S0 is worse than S3")
        #expect(bestAt.lowerBound < unusableAt.lowerBound,
                "the unvaluable scenario follows the ranked ones")
    }

    // MARK: - Sensitivity

    /// `outputRange` is the number drivers are ranked by, and a sweep with a hole in it
    /// reported the spread of the steps that happened to evaluate — a *narrower* range, which
    /// on this scale reads as a less important driver.
    @Test("OutputRange_SweepWithAHole_IsNotANarrowerSpread")
    func outputRangeSweepWithAHoleIsNotANarrowerSpread() {
        let unevaluable = ScenarioSensitivityAnalysis(
            inputDriver: "Revenue",
            inputValues: [1.0, 2.0, 3.0],
            outputValues: [400.0, Double.nan, 750.0]
        )
        let unmeasurableRange: Double = unevaluable.outputRange
        #expect(unmeasurableRange.isNaN, "got \(unmeasurableRange)")

        // Control: the same sweep with every step evaluated reports max - min.
        let measured = ScenarioSensitivityAnalysis(
            inputDriver: "Revenue",
            inputValues: [1.0, 2.0, 3.0],
            outputValues: [400.0, 500.0, 750.0]
        )
        let expected: Double = 750.0 - 400.0
        let measuredRange: Double = measured.outputRange
        let gap: Double = abs(measuredRange - expected)
        #expect(gap < 1e-12, "expected \(expected), got \(measuredRange)")
    }

    // MARK: - Q-Q diagnostics

    /// A Q-Q plot is a pairing, so an unspecified sort pairs perfectly good residuals with the
    /// wrong theoretical quantiles — a curvature that is an artifact of the sort and reads as
    /// a diagnosis. The plotting positions depend on `n` alone and survive; the pairing does
    /// not.
    @Test("QQNormalData_UnorderableResidual_BreaksThePairingRatherThanTheLength")
    func qqNormalDataUnorderableResidualBreaksThePairingRatherThanTheLength() {
        let contaminated: [Double] = [-1.2, 0.3, Double.nan, 0.8, 1.5]
        let points = qqNormalData(contaminated)
        #expect(points.count == contaminated.count, "one point per residual")
        let observedColumn: [Double] = points.map { $0.observed }
        let theoreticalColumn: [Double] = points.map { $0.theoretical }
        let noneObserved: Bool = observedColumn.allSatisfy { $0.isNaN }
        #expect(noneObserved, "got \(observedColumn)")
        let positionsKept: Bool = theoreticalColumn.allSatisfy { $0.isFinite }
        #expect(positionsKept, "plotting positions depend only on n: \(theoreticalColumn)")

        // Control: a clean sample still pairs the i-th smallest observation with the i-th
        // position, so both columns come back ascending.
        let clean: [Double] = [0.8, -1.2, 1.5, 0.3, -0.4]
        let cleanPoints = qqNormalData(clean)
        let observed: [Double] = cleanPoints.map { $0.observed }
        let theoretical: [Double] = cleanPoints.map { $0.theoretical }
        let observedAscending: Bool = zip(observed, observed.dropFirst()).allSatisfy { $0 < $1 }
        let theoreticalAscending: Bool = zip(theoretical, theoretical.dropFirst()).allSatisfy { $0 < $1 }
        #expect(observedAscending, "got \(observed)")
        #expect(theoreticalAscending, "got \(theoretical)")
    }

    // MARK: - Portfolio

    private func portfolio(meanReturns: [Double]) -> Portfolio<Double> {
        let periods = (0..<4).map { Period.month(year: 2024, month: $0 + 1) }
        let series = meanReturns.map { level in
            TimeSeries(periods: periods, values: [level, level, level, level])
        }
        let names = meanReturns.indices.map { "A\($0)" }
        return Portfolio(assets: names, returns: series)
    }

    /// An asset with no expected return was skipped by `min()`/`max()`, so the target returns
    /// were laid out between the extremes of the *other* assets: every point on the curve was
    /// an optimisation over an asset set one member short of the one the caller supplied,
    /// while `assets` still listed it.
    @Test("EfficientFrontier_UnvaluedAsset_IsNotQuietlyLeftOutOfTheSpan")
    func efficientFrontierUnvaluedAssetIsNotQuietlyLeftOutOfTheSpan() {
        let contaminated = portfolio(meanReturns: [0.02, Double.nan, 0.09])
        #expect(contaminated.expectedReturns.count == 3, "the asset is still in the portfolio")
        #expect(contaminated.efficientFrontier(points: 4).isEmpty,
                "a frontier drawn across two of three assets is not this portfolio's frontier")

        // Control: an ordinary portfolio still produces the requested number of points.
        let clean = portfolio(meanReturns: [0.02, 0.05, 0.09])
        #expect(clean.efficientFrontier(points: 4).count == 4)
    }

    // MARK: - The DSL

    /// `min` and `max` here are read off the sort as `values.first` and `values.last`, not
    /// from `min()`/`max()`, so they were whichever scenarios the sort happened to leave at
    /// the ends and the median whichever it left in the middle. `count` is still the truth.
    ///
    /// The type names are qualified because `Scenario` and `ScenarioAnalysis` exist in both
    /// modules and this file needs `BusinessMath` for everything above.
    @Test("ScenarioStatistics_UnevaluableScenario_DoesNotSetTheEnds")
    func scenarioStatisticsUnevaluableScenarioDoesNotSetTheEnds() {
        let analysis = BusinessMathDSL.ScenarioAnalysis {
            BusinessMathDSL.Scenario(name: "Low", parameters: ["revenue": 100])
            BusinessMathDSL.Scenario(name: "Broken", parameters: ["revenue": 200])
            BusinessMathDSL.Scenario(name: "High", parameters: ["revenue": 300])
        }

        let contaminated = analysis.statistics { scenario in
            scenario.name == "Broken" ? Double.nan : (scenario.parameters["revenue"] ?? 0)
        }
        #expect(contaminated.count == 3, "the scenario count is still known")
        #expect(contaminated.min.isNaN, "got \(contaminated.min)")
        #expect(contaminated.max.isNaN, "got \(contaminated.max)")
        #expect(contaminated.median.isNaN, "got \(contaminated.median)")
        #expect(contaminated.mean.isNaN, "got \(contaminated.mean)")

        let brokenPercentile = analysis.percentile(50) { scenario in
            scenario.name == "Broken" ? Double.nan : (scenario.parameters["revenue"] ?? 0)
        }
        #expect(brokenPercentile.isNaN, "got \(brokenPercentile)")

        // Control, derived: 100, 200 and 300 have mean and median 200.
        let clean = analysis.statistics { $0.parameters["revenue"] ?? 0 }
        let expectedMean: Double = (100.0 + 200.0 + 300.0) / 3.0
        #expect(abs(clean.mean - expectedMean) < 1e-12, "got \(clean.mean)")
        #expect(abs(clean.median - 200.0) < 1e-12, "got \(clean.median)")
        #expect(abs(clean.min - 100.0) < 1e-12, "got \(clean.min)")
        #expect(abs(clean.max - 300.0) < 1e-12, "got \(clean.max)")
    }
}

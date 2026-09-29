//
//  TrappingValuationTests.swift
//  BusinessMathTests
//
//  Eight sites where `Int(_:)` on a floating-point value took the whole process down.
//
//  `Int(Double)` is a *trapping* conversion. It crashes on a non-finite value and on anything
//  outside `Int`'s range (`Int.max ≈ 9.22e18`), and a trap is not a wrong answer to one call —
//  it is the end of the process, wherever that call happened to be. One of these sites was a
//  metadata *string*: a series' name brought down the run that built it.
//
//  Every test below fails by crashing rather than by reporting, which is the point: reaching
//  the assertion at all is half of what is being asserted. Each function also gets a clean
//  control that passed before the guard and passes after it, so the file discriminates rather
//  than merely surviving.
//
//  Contract: `project/plans/CONTAMINATED_INPUT_CONTRACT.md`.
//

import Testing
import Foundation
@testable import BusinessMath

/// Elementwise comparison for a numeric sequence; `==` on `[Double]` is refused by the gate,
/// because it hides three different claims.
private func agree(_ lhs: [Double], _ rhs: [Double]) -> Bool {
    // `isEqual(to:)` is IEEE equality, so `nan.isEqual(to: .nan)` is **false**. This sweep
    // deliberately marks unevaluable positions with `.nan`, so two NaNs in the same slot
    // are an agreement, not a mismatch — without this a marked position can never match.
    lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.isEqual(to: $1) || ($0.isNaN && $1.isNaN) }
}

@Suite("Trapping Int conversions in valuation and simulation")
struct TrappingValuationTests {

    private let asOf = Date(timeIntervalSince1970: 1_700_000_000)

    /// A flat 2% hazard curve. Flat, so the credit triangle `spread ≈ λ · (1 − R)` gives an
    /// expected value that is derived rather than recalled.
    private var flatHazardCurve: HazardRateCurve<Double> {
        HazardRateCurve(
            hazardRates: TimeSeries(
                periods: [.year(2024), .year(2025), .year(2026)],
                values: [0.02, 0.02, 0.02]))
    }

    // MARK: - (a) CreditTermStructure.cdsSpread — two traps, not one

    /// `Int(maturity) * 4` trapped on a maturity that is not a number.
    @Test("CDSSpread_OnANonFiniteMaturity_IsUndefined")
    func cdsSpreadOnANonFiniteMaturityIsUndefined() {
        let curve = flatHazardCurve
        let onNaN = curve.cdsSpread(maturity: .nan)
        let onInfinity = curve.cdsSpread(maturity: .infinity)
        #expect(onNaN.isNaN, "got \(onNaN)")
        #expect(onInfinity.isNaN, "got \(onInfinity)")
    }

    /// And on one `Int` cannot hold, which is the other half of what the conversion refuses.
    @Test("CDSSpread_OnAnUnschedulableMaturity_IsUndefined")
    func cdsSpreadOnAnUnschedulableMaturityIsUndefined() {
        let curve = flatHazardCurve
        let huge = curve.cdsSpread(maturity: 1e300)
        let negative = curve.cdsSpread(maturity: -5.0)
        #expect(huge.isNaN, "got \(huge)")
        #expect(negative.isNaN, "got \(negative)")
    }

    /// The **second** trap: `Int(maturity) * 4` is zero for every maturity below one year, and
    /// `for i in 1...0` is a closed range whose lower bound is above its upper bound. A
    /// finiteness-only fix would have swapped one crash for another, on entirely clean data.
    @Test("CDSSpread_OnASubQuarterlyMaturity_IsUndefinedRatherThanFree")
    func cdsSpreadOnASubQuarterlyMaturityIsUndefinedRatherThanFree() {
        let curve = flatHazardCurve
        let subQuarterly = curve.cdsSpread(maturity: 0.1)
        // No quarterly premium date falls on or before 0.1y, so the risky annuity is zero and
        // protection / annuity has no value. Zero would say protection on this name is free.
        #expect(subQuarterly.isNaN, "got \(subQuarterly) — a spread of 0 bp reads as free")
    }

    /// Control, and a regression for the same trap: a legitimate six-month CDS. Every maturity
    /// below 1.0 used to crash here, because `Int(0.5)` is zero.
    @Test("CDSSpread_OnASixMonthMaturity_MatchesTheCreditTriangle")
    func cdsSpreadOnASixMonthMaturityMatchesTheCreditTriangle() {
        // Two quarterly dates, 0.25 and 0.5, at a 5% flat risk-free rate and λ = 2%:
        //   annuity    = 0.25 · (e^-0.0125·e^-0.005 + e^-0.025·e^-0.01)
        //   protection = 0.6 · (e^-0.0125·0.004988 + e^-0.025·0.004962)
        //   spread     = 0.0120300500626, which is the credit triangle λ(1 − R) = 0.012 to
        //               three places — an independent check that the schedule is the right one.
        let spread = flatHazardCurve.cdsSpread(maturity: 0.5)
        let expected = 0.0120300500626
        let difference = abs(spread - expected)
        #expect(difference < 1e-9, "got \(spread)")
    }

    /// Control: the five-year point is arithmetically untouched by the fix, because
    /// `Int(5.0) * 4` and `Int(5.0 * 4)` are the same twenty periods.
    @Test("CDSSpread_OnACleanFiveYearMaturity_Unchanged")
    func cdsSpreadOnACleanFiveYearMaturityUnchanged() {
        let spread = flatHazardCurve.cdsSpread(maturity: 5.0)
        let difference = abs(spread - 0.0120300500626)
        #expect(spread.isFinite, "got \(spread)")
        #expect(difference < 1e-9, "got \(spread)")
    }

    // MARK: - (b) DriverProjection.percentile — a label string took the process down

    private func salesProjection() throws -> ProjectionResults<Double> {
        let driver = DeterministicDriver(name: "Sales", value: 100.0)
        let projection = DriverProjection(driver: driver, periods: Period.documentationQuarters)
        return try projection.projectMonteCarlo(iterations: 64, seed: 42)
    }

    /// `"P\(Int(p * 100))"`. The statistics were already safe — `quantile(sorted:p:)` answers
    /// `nan` for a `nan` probability — and the crash was in the metadata built after them.
    @Test("Percentile_OnANonFiniteProbability_LabelsRatherThanTraps")
    func percentileOnANonFiniteProbabilityLabelsRatherThanTraps() throws {
        let results = try salesProjection()
        let series = results.percentile(.nan)
        #expect(series.metadata.description == "Pnan Sales",
                "got \(series.metadata.description ?? "nil")")
        #expect(series.valuesArray.allSatisfy { $0.isNaN },
                "the values were already correct; got \(series.valuesArray)")
    }

    /// The other half of the conversion's refusal, and the half `isFinite` alone would miss.
    @Test("Percentile_OnAnOutOfRangeProbability_LabelsRatherThanTraps")
    func percentileOnAnOutOfRangeProbabilityLabelsRatherThanTraps() throws {
        let results = try salesProjection()
        let series = results.percentile(.infinity)
        #expect(series.metadata.description == "Pinf Sales",
                "got \(series.metadata.description ?? "nil")")
    }

    /// Control: an ordinary percentile keeps the label it always had.
    @Test("Percentile_OnACleanProbability_LabelUnchanged")
    func percentileOnACleanProbabilityLabelUnchanged() throws {
        let results = try salesProjection()
        let series = results.percentile(0.50)
        #expect(series.metadata.description == "P50 Sales",
                "got \(series.metadata.description ?? "nil")")
        let first = try #require(series.valuesArray.first)
        #expect(first.isEqual(to: 100.0), "got \(first)")
    }

    // MARK: - (c) DiscountCurve.bootstrap — finite is not the same as placeable

    /// The `placeable` filter screened `isFinite` and stopped there, so `1e300` reached the
    /// same `Int(_:)` and trapped on the other half of what that conversion refuses.
    @Test("Bootstrap_DropsATenorTooLargeForTheYearGrid")
    func bootstrapDropsATenorTooLargeForTheYearGrid() {
        let curve = DiscountCurve.bootstrap(
            parRates: [(tenor: 1.0, rate: 0.04), (tenor: 1e300, rate: 0.05)],
            asOfDate: asOf)
        #expect(agree(curve.tenors, [1.0]), "got \(curve.tenors)")
    }

    /// Control: the earlier fix in this file is undisturbed — a non-finite tenor is still
    /// dropped, and the quotes around it still build their curve.
    @Test("Bootstrap_OnACleanCurve_Unchanged")
    func bootstrapOnACleanCurveUnchanged() {
        let curve = DiscountCurve.bootstrap(
            parRates: [(tenor: 1.0, rate: 0.04), (tenor: 2.0, rate: 0.045),
                       (tenor: 3.0, rate: 0.047)],
            asOfDate: asOf)
        #expect(agree(curve.tenors, [1.0, 2.0, 3.0]), "got \(curve.tenors)")
        let factorsInUnitInterval = curve.discountFactors.allSatisfy { $0 > 0 && $0 <= 1 }
        #expect(factorsInUnitInterval, "got \(curve.discountFactors)")
    }

    // MARK: - (d) NelsonSiegel — one bond crashed a whole calibration

    private var cleanBonds: [BondMarketData] {
        [
            BondMarketData(maturity: 1.0, couponRate: 0.05, faceValue: 100, marketPrice: 98.8),
            BondMarketData(maturity: 5.0, couponRate: 0.058, faceValue: 100, marketPrice: 96.8),
            BondMarketData(maturity: 10.0, couponRate: 0.062, faceValue: 100, marketPrice: 95.5)
        ]
    }

    /// `Int(bond.maturity * periodsPerYear)`, with nothing screened at the data's own door.
    @Test("BondPrice_OnAnUnschedulableBond_IsUndefined")
    func bondPriceOnAnUnschedulableBondIsUndefined() {
        let curve = NelsonSiegelYieldCurve(parameters: .defaultInitial())
        let notANumber = BondMarketData(maturity: .nan, couponRate: 0.05, faceValue: 100, marketPrice: 99)
        let unbounded = BondMarketData(maturity: .infinity, couponRate: 0.05, faceValue: 100, marketPrice: 99)
        let tooLong = BondMarketData(maturity: 1e18, couponRate: 0.05, faceValue: 100, marketPrice: 99)
        #expect(curve.price(bond: notANumber).isNaN, "got \(curve.price(bond: notANumber))")
        #expect(curve.price(bond: unbounded).isNaN, "got \(curve.price(bond: unbounded))")
        #expect(curve.price(bond: tooLong).isNaN, "got \(curve.price(bond: tooLong))")
    }

    /// A frequency of zero divides the coupon by nothing, and two `fp-safety:disable` comments
    /// in `price(bond:)` claim the initialiser prevents it. It did not; now the screen does.
    @Test("BondSchedulability_RejectsAZeroPaymentFrequency")
    func bondSchedulabilityRejectsAZeroPaymentFrequency() {
        let noPayments = BondMarketData(
            maturity: 5.0, couponRate: 0.05, faceValue: 100, marketPrice: 99, frequency: 0)
        #expect(noPayments.isSchedulable == false)
        let curve = NelsonSiegelYieldCurve(parameters: .defaultInitial())
        #expect(curve.price(bond: noPayments).isNaN, "got \(curve.price(bond: noPayments))")
    }

    /// The blast radius is why the screen is on the data: this bond is priced once per
    /// objective evaluation, so it used to take the whole fit down from inside L-BFGS.
    @Test("Calibrate_RejectsAnUnschedulableBond")
    func calibrateRejectsAnUnschedulableBond() {
        var bonds = cleanBonds
        bonds.append(BondMarketData(maturity: .infinity, couponRate: 0.05, faceValue: 100, marketPrice: 99))
        #expect(throws: BusinessMathError.self) {
            _ = try NelsonSiegelYieldCurve.calibrate(to: bonds)
        }
    }

    /// Control: clean bonds price and calibrate exactly as before. The calibration set is
    /// priced *from* a known curve, so the fit has a fixed point to find and the control is
    /// about the guard rather than about the optimiser's luck.
    @Test("Calibrate_OnCleanBonds_Unchanged")
    func calibrateOnCleanBondsUnchanged() throws {
        let trueParameters = NelsonSiegelParameters(
            beta0: 0.045, beta1: -0.015, beta2: 0.008, lambda: 2.5)
        let trueCurve = NelsonSiegelYieldCurve(parameters: trueParameters)

        let bond = try #require(cleanBonds.first)
        let price = trueCurve.price(bond: bond)
        #expect(price.isFinite, "got \(price)")
        let priceIsPlausible = price > 50 && price < 200
        #expect(priceIsPlausible, "a 100-face one-year bond; got \(price)")

        let synthetic = cleanBonds.map { seed in
            BondMarketData(
                maturity: seed.maturity,
                couponRate: seed.couponRate,
                faceValue: seed.faceValue,
                marketPrice: trueCurve.price(bond: seed),
                frequency: seed.frequency)
        }
        let calibrated = try NelsonSiegelYieldCurve.calibrate(to: synthetic)
        let beta0Error = abs(calibrated.parameters.beta0 - 0.045)
        #expect(beta0Error < 0.01, "got \(calibrated.parameters.beta0)")
    }

    // MARK: - (e) FinancialSimulation.conditionalValueAtRisk

    /// `Int(ceil(Double(count) * (1 - confidence)))`, one hop from `conditionalValueAtRisk(.nan)`.
    @Test("CVaR_OnANonFiniteConfidence_IsUndefined")
    func cvarOnANonFiniteConfidenceIsUndefined() throws {
        let simulation = try FinancialSimulation.documentationFixture
        let quarter = Period.documentationQuarters[0]
        let cvar = try simulation.conditionalValueAtRisk(.nan) { projection in
            try #require(projection.incomeStatement.netIncome[quarter])
        }
        #expect(cvar.isNaN, "got \(cvar) — a shortfall nobody could compute")
    }

    /// Control: a 95% shortfall still sits at or below the 95% VaR, which is what a tail is.
    @Test("CVaR_OnACleanConfidence_Unchanged")
    func cvarOnACleanConfidenceUnchanged() throws {
        let simulation = try FinancialSimulation.documentationFixture
        let quarter = Period.documentationQuarters[0]
        let cvar = try simulation.conditionalValueAtRisk(0.95) { projection in
            try #require(projection.incomeStatement.netIncome[quarter])
        }
        let varAt95 = try simulation.valueAtRisk(0.95) { projection in
            try #require(projection.incomeStatement.netIncome[quarter])
        }
        #expect(cvar.isFinite, "got \(cvar)")
        #expect(cvar <= varAt95, "shortfall \(cvar) above its own threshold \(varAt95)")
    }

    // MARK: - (f) PortfolioUtilities.generateSparseCovarianceMatrix

    /// `max(5, Int(Double(size) * (1.0 - sparsity)))` — the floor that looks protective runs
    /// *after* the conversion, so it protected nothing at all.
    @Test("SparseCovariance_OnANonFiniteSparsity_KeepsItsShape")
    func sparseCovarianceOnANonFiniteSparsityKeepsItsShape() {
        let matrix = generateSparseCovarianceMatrix(size: 10, sparsity: .nan, seed: 42)
        let rowsAreFull = matrix.allSatisfy { $0.count == 10 }
        let everyEntryIsMarked = matrix.allSatisfy { $0.allSatisfy(\.isNaN) }
        #expect(matrix.count == 10, "the length invariant; got \(matrix.count)")
        #expect(rowsAreFull, "rows: \(matrix.map(\.count))")
        #expect(everyEntryIsMarked, "a zero matrix would say these assets have no variance")
    }

    /// An unordered volatility range traps one line into the draw loop, for the same reason.
    @Test("SparseCovariance_OnAnUnorderedVolatilityRange_KeepsItsShape")
    func sparseCovarianceOnAnUnorderedVolatilityRangeKeepsItsShape() {
        let matrix = generateSparseCovarianceMatrix(
            size: 6, sparsity: 0.9, volatility: (min: 0.30, max: 0.10), seed: 42)
        let everyEntryIsMarked = matrix.allSatisfy { $0.allSatisfy(\.isNaN) }
        #expect(matrix.count == 6, "got \(matrix.count)")
        #expect(everyEntryIsMarked, "got \(matrix)")
    }

    /// Control: a clean matrix is square, symmetric, and has variances inside the volatility
    /// bounds it was given — `0.10²` to `0.30²`.
    @Test("SparseCovariance_OnCleanInputs_Unchanged")
    func sparseCovarianceOnCleanInputsUnchanged() {
        let matrix = generateSparseCovarianceMatrix(size: 10, sparsity: 0.9, seed: 42)
        #expect(matrix.count == 10, "got \(matrix.count)")
        let diagonal = (0..<10).map { matrix[$0][$0] }
        let variancesInBounds = diagonal.allSatisfy { $0 >= 0.01 && $0 <= 0.09 }
        #expect(variancesInBounds, "0.10² to 0.30² is the drawn range; got \(diagonal)")
        let symmetric = (0..<10).allSatisfy { i in
            (0..<10).allSatisfy { j in matrix[i][j].isEqual(to: matrix[j][i]) }
        }
        #expect(symmetric, "the matrix is not symmetric")
    }

    // MARK: - (g) StandardTemplates — `nan` was screened by accident, `+infinity` was not

    private var realEstateParameters: [String: Any] {
        [
            "purchasePrice": 500_000.0,
            "downPaymentPercentage": 0.25,
            "interestRate": 0.055,
            "loanTermYears": 30.0,
            "annualRent": 36_000.0,
            "annualOperatingExpenses": 12_000.0,
            "annualAppreciationRate": 0.03
        ]
    }

    /// `loanTerm > 0` rejected `nan` only because every comparison against `nan` is false.
    /// `+infinity > 0` is true, so it walked through a guard that looked like it covered this.
    @Test("RealEstateTemplate_RejectsANonFiniteLoanTerm")
    func realEstateTemplateRejectsANonFiniteLoanTerm() {
        let template = RealEstateTemplate()
        var parameters = realEstateParameters
        parameters["loanTermYears"] = Double.infinity
        #expect(throws: BusinessMathError.self) {
            _ = try template.create(parameters: parameters)
        }

        parameters["loanTermYears"] = 1e300
        #expect(throws: BusinessMathError.self) {
            _ = try template.create(parameters: parameters)
        }
    }

    /// Control: `nan` was already refused, and must still be — for a stated reason now.
    @Test("RealEstateTemplate_StillRejectsANaNLoanTerm")
    func realEstateTemplateStillRejectsANaNLoanTerm() {
        let template = RealEstateTemplate()
        var parameters = realEstateParameters
        parameters["loanTermYears"] = Double.nan
        #expect(throws: BusinessMathError.self) {
            _ = try template.create(parameters: parameters)
        }
    }

    /// Control: an ordinary thirty-year mortgage still builds its model.
    @Test("RealEstateTemplate_OnCleanParameters_Unchanged")
    func realEstateTemplateOnCleanParametersUnchanged() throws {
        let template = RealEstateTemplate()
        let model = try template.create(parameters: realEstateParameters)
        let realEstate = try #require(model as? RealEstateModel)
        #expect(realEstate.loanTermYears == 30, "got \(realEstate.loanTermYears)")
    }

    // MARK: - (h) JumpDiffusion — an intensity that passed `> 0`

    private func shockProcess(intensity: Double) -> JumpDiffusion {
        JumpDiffusion(
            name: "WTI_Shock", drift: 0.05, volatility: 0.25,
            jumpIntensity: intensity, jumpMean: -0.05, jumpVolatility: 0.10)
    }

    /// `.infinity > 0` is true, so an infinite intensity reached `Int(result.rounded())` in
    /// the Poisson inverse CDF and took the simulation down mid-path.
    @Test("JumpDiffusionStep_OnAnInfiniteIntensity_IsUndefined")
    func jumpDiffusionStepOnAnInfiniteIntensityIsUndefined() {
        let process = shockProcess(intensity: .infinity)
        let next = process.step(from: 100.0, dt: 1.0 / 252.0, normalDraws: 0.5)
        #expect(next.isNaN, "got \(next)")
    }

    /// The same conversion, reached with **nothing contaminated at all**: `normalCDF`
    /// saturates to exactly 1.0 for a draw of 10, `inverseNormalCDF(p: 1)` is `+infinity` by
    /// its own documentation, and any intensity above 30 per step then feeds it to `Int(_:)`.
    @Test("JumpDiffusionStep_OnASaturatedUniform_IsUndefined")
    func jumpDiffusionStepOnASaturatedUniformIsUndefined() {
        let process = shockProcess(intensity: 40.0)
        let next = process.step(from: 100.0, dt: 1.0, normalDraws: 10.0)
        #expect(next.isNaN, "got \(next) — the jump count was unbounded")
    }

    /// Control: a two-shocks-a-year process still steps, and still to a positive price.
    @Test("JumpDiffusionStep_OnACleanIntensity_Unchanged")
    func jumpDiffusionStepOnACleanIntensityUnchanged() {
        let process = shockProcess(intensity: 2.0)
        let next = process.step(from: 100.0, dt: 1.0 / 252.0, normalDraws: 0.5)
        #expect(next.isFinite, "got \(next)")
        #expect(next > 0, "jump-diffusion is exponential; got \(next)")
    }

    /// Control: the pure-GBM branch is untouched — a zero intensity is not contamination.
    @Test("JumpDiffusionStep_OnAZeroIntensity_IsPureGBM")
    func jumpDiffusionStepOnAZeroIntensityIsPureGBM() {
        let process = shockProcess(intensity: 0.0)
        let dt = 1.0 / 252.0
        let drawn = process.step(from: 100.0, dt: dt, normalDraws: 0.5)
        // exp((0.05 − 0.25²/2)·dt + 0.25·√dt·0.5) · 100, computed the same way here.
        let driftTerm = (0.05 - 0.25 * 0.25 / 2.0) * dt
        let diffusionTerm = 0.25 * dt.squareRoot() * 0.5
        let expected = 100.0 * exp(driftTerm + diffusionTerm)
        let relativeError = abs(drawn - expected) / expected
        #expect(relativeError < 1e-12, "got \(drawn), expected \(expected)")
    }
}

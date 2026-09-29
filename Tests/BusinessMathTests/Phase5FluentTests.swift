//
//  Phase5FluentTests.swift
//  BusinessMathTests
//
//  Phase 5 of the contaminated-input sweep: `Fluent API`, `BusinessMathDSL`, `Marketing`
//  and `Network`.
//
//  The area matters more than its site count. Fluent API and the DSL are where someone who
//  is not a numerical analyst meets this library, so a fabricated zero here is further from
//  anyone able to question it than the same zero inside a solver — and `FinancialModel`
//  hands its answer straight to a report.
//
//  Every test below pairs a contaminated case with a clean control that passed before the
//  fix and passes after it. The controls are the half that proves the suite discriminates
//  rather than merely failing.
//

import Testing
import Foundation
@testable import BusinessMath
@testable import BusinessMathDSL

@Suite("Phase 5 — an unanswerable question is not a measurement of zero")
struct Phase5FluentTests {

    private static let q1 = Period.quarter(year: 2025, quarter: 1)
    private static let q2 = Period.quarter(year: 2025, quarter: 2)

    // MARK: - ModelBuilder: a period outside the data

    /// A revenue series asked about a period it does not cover.
    ///
    /// `RevenueComponent.value(for:)` was `timeSeries?[period] ?? amount`, and `amount` is
    /// **0** for a component built from a series — the initialiser stores it and its own
    /// comment says it is unused. So every period outside the series answered with a
    /// measured revenue of zero. This is the `altmanZScore` shape of §3.7, in the fluent
    /// API: a lookup miss reported as an observation.
    @Test("Revenue outside its series is unanswerable, not zero")
    func revenueOutsideItsSeriesIsNotAMeasuredZero() {
        let component = BusinessMath.RevenueComponent(name: "Subscriptions",
                                         periods: [Self.q1],
                                         values: [100_000])

        let covered: Double = component.value(for: Self.q1)
        let uncovered: Double = component.value(for: Self.q2)

        #expect(covered.isEqual(to: 100_000), "the control: a period the series does cover")
        #expect(uncovered.isNaN, "reported \(uncovered) — a quarter the model was never given")
    }

    /// The control that has to keep passing: a single-amount component has no series, so
    /// its `amount` genuinely applies to every period and the fallback is the right answer.
    @Test("A single-amount revenue component answers for every period")
    func singleAmountRevenueComponentIsUnaffected() {
        let component = BusinessMath.RevenueComponent(name: "Retainer", amount: 500)

        let first: Double = component.value(for: Self.q1)
        let second: Double = component.value(for: Self.q2)

        #expect(first.isEqual(to: 500))
        #expect(second.isEqual(to: 500), "no series, so nothing is being looked up")
    }

    /// What the caller actually sees: the total, and the profit built from it.
    ///
    /// Before the fix this model reported revenue of `0` and a profit of exactly `0` for
    /// Q2 — break-even, which passes every `profit >= 0` screen — for a quarter it holds
    /// no data about at all.
    @Test("A model total for an uncovered period refuses rather than reporting break-even")
    func totalRevenueForAnUncoveredPeriodIsNotZero() {
        var model = FinancialModel()
        model.revenueComponents = [
            BusinessMath.RevenueComponent(name: "Subscriptions", periods: [Self.q1], values: [100_000])
        ]

        let coveredRevenue: Double = model.totalRevenue(for: Self.q1)
        let uncoveredRevenue: Double = model.totalRevenue(for: Self.q2)
        let uncoveredProfit: Double = model.profit(for: Self.q2)

        #expect(coveredRevenue.isEqual(to: 100_000), "the control")
        #expect(uncoveredRevenue.isNaN, "reported \(uncoveredRevenue)")
        #expect(uncoveredProfit.isNaN, "reported \(uncoveredProfit) — break-even, on no data")
    }

    /// The cost side of the same defect, and the favourable end of the scale.
    ///
    /// A cost component built from a series carries `type == .fixed(0)`, so a period the
    /// series does not cover fell through the switch and reported a cost of **zero** —
    /// which lowers total expenses and raises profit for a period nobody supplied.
    @Test("A cost outside its series is unanswerable, not free")
    func costOutsideItsSeriesIsNotFree() {
        let component = CostComponent(name: "Rent", periods: [Self.q1], values: [75])

        let covered: Double = component.value(for: Self.q1, revenue: nil)
        let uncovered: Double = component.value(for: Self.q2, revenue: nil)

        #expect(covered.isEqual(to: 75), "the control")
        #expect(uncovered.isNaN, "reported \(uncovered) — a quarter with no rent at all")
    }

    /// The arm that was deliberately **not** changed, pinned so it stays that way.
    ///
    /// `revenue: nil` on `calculateCosts()` is not "revenue is unknown": it is the
    /// documented request to evaluate the fixed part alone, and `FinancialModelCacheTests`
    /// already pins it. The genuinely unknown case arrives as a `nan` revenue from
    /// `RevenueComponent.value(for:)` and propagates through the multiplication unaided —
    /// which is the second assertion here.
    @Test("A nil revenue still means the fixed part alone; a NaN revenue does not")
    func nilRevenueKeepsItsDocumentedMeaning() {
        let variable = CostComponent(name: "COGS", type: .variable(0.3))

        let withoutRevenue: Double = variable.calculate(revenue: nil)
        let withRevenue: Double = variable.calculate(revenue: 1_000)
        let withUnknownRevenue: Double = variable.calculate(revenue: .nan)

        #expect(withoutRevenue.isEqual(to: 0), "the documented backward-compatible reading")
        #expect(withRevenue.isEqual(to: 300), "the control")
        #expect(withUnknownRevenue.isNaN, "IEEE carries this one without a guard")
    }

    // MARK: - InvestmentBuilder: ROI

    /// `guard initialCost > 0 else { return 0 }` answered `0` for a cost nobody could read.
    ///
    /// Zero on an ROI scale is *broke even exactly*. It clears every `roi >= 0` screen and
    /// sorts above every investment that actually lost money. `Project.roi` in
    /// `Optimization` already returns `nan` for a contaminated capital requirement — this
    /// is the same quantity in the fluent API, and the two disagreed.
    @Test("ROI on an unreadable cost is not break-even")
    func roiOnAnUnreadableCostIsNotBreakEven() {
        let investment = Investment {
            InitialCost(Double.nan)
            CashFlows {
                Year(1) => 50_000
            }
        }

        let roi: Double = investment.totalROI
        #expect(roi.isNaN, "reported \(roi)")
    }

    /// A payout with nothing put in is the best return there is, and it also reported `0`.
    @Test("ROI on a costless payout is unbounded, not break-even")
    func roiOnACostlessPayoutIsUnbounded() {
        let investment = Investment {
            InitialCost(0)
            CashFlows {
                Year(1) => 50_000
            }
        }

        let roi: Double = investment.totalROI
        #expect(roi.isEqual(to: .infinity), "reported \(roi)")
    }

    /// The control: an ordinary investment is untouched.
    @Test("ROI on an ordinary investment is unchanged")
    func roiOnAnOrdinaryInvestmentIsUnchanged() {
        let investment = Investment {
            InitialCost(100_000)
            CashFlows {
                Year(1) => 60_000
                Year(2) => 90_000
            }
        }

        let roi: Double = investment.totalROI
        #expect(roi.isEqual(to: 0.5), "(150,000 − 100,000) / 100,000")
    }

    // MARK: - Templates: a NaN through a `> 0` guard

    /// `nan > 0` is false, so an unusable production figure took the same branch as a plant
    /// that made nothing — and reported a unit cost of **0**, the cheapest value on a cost
    /// scale and the one any "find the lowest-cost configuration" sweep selects outright.
    /// The `atCapacityUtilization:` overload in the same file already refused this input.
    @Test("Unit cost from an unreadable production is not free")
    func unitCostFromAnUnreadableProductionIsNotFree() {
        let contaminated = ManufacturingModel(productionCapacity: 10_000,
                                              actualProduction: .nan,
                                              materialCostPerUnit: 15,
                                              laborCostPerUnit: 10,
                                              overheadCosts: 50_000,
                                              sellingPricePerUnit: 50)
        let clean = ManufacturingModel(productionCapacity: 10_000,
                                       actualProduction: 8_000,
                                       materialCostPerUnit: 15,
                                       laborCostPerUnit: 10,
                                       overheadCosts: 50_000,
                                       sellingPricePerUnit: 50)

        let unreadable: Double = contaminated.calculateUnitCost()
        let measured: Double = clean.calculateUnitCost()

        #expect(unreadable.isNaN, "reported \(unreadable) — production at no cost")
        #expect(measured.isEqual(to: 31.25), "15 + 10 + 50,000/8,000")
    }

    /// Utilisation of `0` is a real reading — an idle plant — so it is the wrong thing to
    /// return for a capacity nobody could compute.
    @Test("Capacity utilisation on an unreadable capacity is not an idle plant")
    func capacityUtilisationOnAnUnreadableCapacityIsNotIdle() {
        let contaminated = ManufacturingModel(productionCapacity: .nan,
                                              sellingPricePerUnit: 50,
                                              directMaterialCostPerUnit: 15,
                                              directLaborCostPerUnit: 10,
                                              monthlyOverhead: 50_000)
        let clean = ManufacturingModel(productionCapacity: 10_000,
                                       sellingPricePerUnit: 50,
                                       directMaterialCostPerUnit: 15,
                                       directLaborCostPerUnit: 10,
                                       monthlyOverhead: 50_000)

        let unreadable: Double = contaminated.calculateCapacityUtilization(actualProduction: 8_000)
        let measured: Double = clean.calculateCapacityUtilization(actualProduction: 8_000)
        let idle: Double = clean.calculateCapacityUtilization(actualProduction: 0)

        #expect(unreadable.isNaN, "reported \(unreadable)")
        #expect(measured.isEqual(to: 0.8), "the control")
        #expect(idle.isEqual(to: 0), "a genuinely idle plant keeps its zero")
    }

    /// A markup of `0` is "sold at cost" — a real pricing decision, which a margin screen
    /// reads as a deliberate loss-leader rather than as missing data.
    @Test("Markup on an unreadable cost share is not sold-at-cost")
    func markupOnAnUnreadableCostShareIsNotSoldAtCost() {
        let contaminated = RetailModel(initialInventoryValue: 50_000,
                                       monthlyRevenue: 100_000,
                                       costOfGoodsSoldPercentage: .nan,
                                       operatingExpenses: 20_000)
        let clean = RetailModel(initialInventoryValue: 50_000,
                                monthlyRevenue: 100_000,
                                costOfGoodsSoldPercentage: 0.5,
                                operatingExpenses: 20_000)

        let unreadable: Double = contaminated.calculateMarkup()
        let measured: Double = clean.calculateMarkup()

        #expect(unreadable.isNaN, "reported \(unreadable)")
        #expect(measured.isEqual(to: 1.0), "(1 − 0.5) / 0.5")
    }

    /// The seed of the churn recurrence, so a fabricated zero does not stay put.
    ///
    /// `initialCustomerCount` returned `0` for an unreadable ARPU, and
    /// `calculateCustomerCount(forMonth:)` then carried on from it: every projected month
    /// came back finite and plausible, understating the business by exactly the customers
    /// the opening MRR represented. Measured before the fix: month 1 reported **100
    /// customers** for a model whose customer count cannot be known.
    @Test("A customer count from an unreadable ARPU is refused, not projected")
    func customerCountFromAnUnreadableARPUIsRefused() throws {
        let contaminated = SaaSModel(initialMRR: 10_000,
                                     churnRate: 0.05,
                                     newCustomersPerMonth: 100,
                                     averageRevenuePerUser: .nan)
        let clean = SaaSModel(initialMRR: 10_000,
                              churnRate: 0.05,
                              newCustomersPerMonth: 100,
                              averageRevenuePerUser: 100)

        let unreadable: Double = try contaminated.calculateCustomerCount(forMonth: 1)
        let measured: Double = try clean.calculateCustomerCount(forMonth: 1)

        #expect(unreadable.isNaN, "reported \(unreadable) customers")
        #expect(measured.isEqual(to: 195), "100 opening, 5% churn, 100 new")
    }

    /// Liquidity is the figure a marketplace is thresholded on, and the file's own comment
    /// says so. The unguarded case was `+infinity`; the `nan` case was landing on `0`,
    /// which is a claim about the marketplace rather than an absence of one.
    @Test("Marketplace liquidity on an unreadable seller count is refused")
    func marketplaceLiquidityOnAnUnreadableSellerCountIsRefused() throws {
        let contaminated = try MarketplaceModel(initialBuyers: 1_000,
                                                initialSellers: .nan,
                                                monthlyTransactionsPerBuyer: 2,
                                                averageOrderValue: 50,
                                                takeRate: 0.15,
                                                newBuyersPerMonth: 100,
                                                newSellersPerMonth: 10,
                                                buyerChurnRate: 0.05,
                                                sellerChurnRate: 0.03)
        let clean = try MarketplaceModel(initialBuyers: 1_000,
                                         initialSellers: 100,
                                         monthlyTransactionsPerBuyer: 2,
                                         averageOrderValue: 50,
                                         takeRate: 0.15,
                                         newBuyersPerMonth: 0,
                                         newSellersPerMonth: 0,
                                         buyerChurnRate: 0,
                                         sellerChurnRate: 0)

        let unreadable: Double = contaminated.calculateLiquidity(forMonth: 1)
        let measured: Double = clean.calculateLiquidity(forMonth: 1)

        #expect(unreadable.isNaN, "reported \(unreadable) buyers per seller")
        #expect(measured.isEqual(to: 10), "1,000 buyers over 100 sellers, no churn, no growth")
    }

    // MARK: - BusinessMathDSL: an index that trapped

    /// `ScenarioAnalysis.percentile(_:for:)` took an unvalidated `Int` and subscripted with
    /// it. `percentile(-50)` indexes negatively and `percentile(500)` indexes past the end:
    /// both **trap**, taking the process down rather than answering. Clamping matches
    /// `Percentiles.percentile(_:)`, whose own tests pin the same two edges.
    @Test("A percentile outside the scale clamps rather than trapping")
    func percentileOutsideTheScaleDoesNotTrap() {
        // Qualified: `Scenario`, `ScenarioAnalysis`, `Revenue` and `RevenueComponent` are
        // each declared in *both* modules this file imports, so an unqualified name here
        // is ambiguous rather than merely unclear.
        let analysis = BusinessMathDSL.ScenarioAnalysis(scenarios: [
            BusinessMathDSL.Scenario(name: "low", parameters: ["v": 1]),
            BusinessMathDSL.Scenario(name: "mid", parameters: ["v": 2]),
            BusinessMathDSL.Scenario(name: "high", parameters: ["v": 3])
        ])
        let value: (BusinessMathDSL.Scenario) -> Double = { $0.parameters["v"] ?? 0 }

        let belowTheScale: Double = analysis.percentile(-50, for: value)
        let aboveTheScale: Double = analysis.percentile(500, for: value)
        let middle: Double = analysis.percentile(50, for: value)

        #expect(belowTheScale.isEqual(to: 1), "clamped to the minimum")
        #expect(aboveTheScale.isEqual(to: 3), "clamped to the maximum")
        #expect(middle.isEqual(to: 2), "the control: index 1 of three sorted values")
    }

    // MARK: - Network: a state the chain never saw

    /// `probability(from:to:)` answered `0` for a name that is not a state, and zero on a
    /// probability scale is the confident claim that the move is **impossible** — what a
    /// caller screening for reachability reads it as. `absorptionProbability(to:from:)`
    /// one file over already refuses the same question, and returns `nil` for it.
    @Test("A transition probability for an unknown state is unanswerable, not impossible")
    func transitionProbabilityForAnUnknownStateIsUnanswerable() throws {
        let chain = try #require(TransitionMatrix<Double>(paths: [["a", "b"], ["a", "b"]]))

        let known: Double = chain.probability(from: "a", to: "b")
        let unknownOrigin: Double = chain.probability(from: "mars", to: "b")
        let unknownTarget: Double = chain.probability(from: "a", to: "venus")

        #expect(known.isEqual(to: 1), "the control: every observed path went a → b")
        #expect(unknownOrigin.isNaN, "reported \(unknownOrigin)")
        #expect(unknownTarget.isNaN, "reported \(unknownTarget)")
    }
}

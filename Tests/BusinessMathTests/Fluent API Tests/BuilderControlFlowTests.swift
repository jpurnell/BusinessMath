//
//  BuilderControlFlowTests.swift
//  BusinessMathTests
//
//  Fifty never-executed members across `ModelBuilder.swift` and `TimeSeriesBuilder.swift`,
//  and a large share of them are the builders' own `buildOptional`, `buildEither` and
//  `buildArray`. That is not an accident of test-writing: those methods only run when someone
//  writes an `if` or a `for` inside a builder, and nothing in the suite ever did.
//
//  It matters here more than it would elsewhere. Two builders in this package —
//  `LiquidationWaterfallBuilder` and `CashFlowModelBuilder` — turned out to have
//  **unreachable** control-flow methods, because their partial-result types did not line up,
//  so an `if` or a `for` failed to compile. Zero coverage was the symptom.
//
//  An audit of all 27 result builders found the remaining twelve already thread a consistent
//  `[Component]` partial result. These tests are the direct evidence for that claim rather
//  than the inference from signatures: each one writes the control flow and checks that
//  **every** component survives, which is also what would catch a `buildArray` that quietly
//  keeps only the first — the second defect found in `CashFlowModelBuilder`.
//
//  Nothing was wrong here.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Builder control flow reaches every component")
struct BuilderControlFlowTests {

    private static let q1 = Period.quarter(year: 2025, quarter: 1)

    // MARK: - ModelBuilder

    /// An `if` and a `for` in the same block, with every component required to arrive.
    ///
    /// Revenue 1,000 against rent 200, marketing 50, two tiers at 10 and 20, and COGS at 30%
    /// of revenue: 580 of cost and 420 of profit.
    @Test("ModelBuilder_OptionalAndLoopBothContribute") func modelBuilderOptionalAndLoop() {
        let includeMarketing = true
        let model = buildModel {
            RevenueAmount("Sales", 1_000.0)
            FixedCost("Rent", 200.0)
            if includeMarketing {
                FixedCost("Marketing", 50.0)
            }
            for tier in 1...2 {
                FixedCost("Tier\(tier)", Double(10 * tier))
            }
            VariableCost("COGS", rate: 0.30)
        }

        #expect(model.costComponents.map(\.name) == ["Rent", "Marketing", "Tier1", "Tier2", "COGS"],
                "every component, in order, none dropped by buildArray")
        #expect(model.calculateRevenue().isEqual(to: 1_000))
        #expect(model.calculateCosts(revenue: 1_000).isEqual(to: 580), "200 + 50 + 10 + 20 + 300")
        #expect(model.calculateProfit().isEqual(to: 420))
    }

    /// The omitted branch, through a parameter rather than a literal `false` — which the
    /// compiler folds away, so the `buildOptional` nil path would never actually run.
    @Test("ModelBuilder_OmittedOptionalContributesNothing") func modelBuilderOmittedOptional() {
        func model(includeMarketing: Bool) -> FinancialModel {
            buildModel {
                RevenueAmount("Sales", 1_000.0)
                if includeMarketing {
                    FixedCost("Marketing", 50.0)
                }
            }
        }
        #expect(model(includeMarketing: false).costComponents.isEmpty,
                "no phantom component from the empty branch")
        #expect(model(includeMarketing: false).calculateCosts().isEqual(to: 0))
        #expect(model(includeMarketing: true).costComponents.count == 1, "and it does appear when asked")
    }

    @Test("ModelBuilder_EitherTakesBothArms") func modelBuilderEitherTakesBothArms() {
        func model(high: Bool) -> FinancialModel {
            buildModel {
                RevenueAmount("Sales", 1_000.0)
                if high { FixedCost("Big", 500.0) } else { FixedCost("Small", 100.0) }
            }
        }
        #expect(model(high: true).calculateCosts().isEqual(to: 500))
        #expect(model(high: false).calculateCosts().isEqual(to: 100))
    }

    /// `buildModel(for:)` attaches the entity without disturbing the components.
    @Test("BuildModel_ForEntity") func buildModelForEntity() {
        let entity = Entity(id: "ACME", name: "Acme")
        let model = buildModel(for: entity) {
            RevenueAmount("Sales", 250.0)
        }
        #expect(model.entity?.id == "ACME")
        #expect(model.calculateRevenue().isEqual(to: 250))
    }

    // MARK: - Period-aware members

    @Test("PeriodAwareTotals") func periodAwareTotals() {
        let model = buildModel {
            RevenueAmount("Sales", 0.0)
            Expense("Utilities", periods: [Self.q1], values: [75.0], type: .operatingExpense)
        }
        #expect(model.totalExpenses(for: Self.q1).isEqual(to: 75))
        #expect(model.profit(for: Self.q1).isEqual(to: -75), "revenue is zero in that period")
    }

    @Test("CostComponentValues") func costComponentValues() {
        #expect(CostAmount("X", 42.0).value(for: Self.q1, revenue: nil).isEqual(to: 42))
        #expect(FixedCost("Y", periods: [Self.q1], value: 33.0)
            .value(for: Self.q1, revenue: nil).isEqual(to: 33))
        #expect(VariableCost("Z", rate: 0.25)
            .value(for: Self.q1, revenue: 400.0).isEqual(to: 100), "a quarter of 400")
    }

    // MARK: - TimeSeriesBuilder

    @Test("QuarterlyAndMonthly_UseTheArrowOperator") func quarterlyAndMonthlyUseArrow() {
        let quarterly = TimeSeries<Double>.quarterly(year: 2025) {
            Quarter.q1 => 10.0
            Quarter.q2 => 20.0
        }
        #expect(quarterly.valuesArray.count == 2)
        #expect(quarterly.valuesArray[0].isEqual(to: 10))
        #expect(quarterly.valuesArray[1].isEqual(to: 20))

        let monthly = TimeSeries<Double>.monthly(year: 2025) {
            Month.january => 1.0
            Month.february => 2.0
        }
        #expect(monthly.valuesArray.count == 2)
        #expect(monthly.valuesArray[0].isEqual(to: 1))
    }

    /// `SequentialTimeSeriesBuilder`'s control flow, with all four entries required to land.
    @Test("BuildTimeSeries_ControlFlowKeepsEveryEntry") func buildTimeSeriesControlFlow() {
        let includeExtra = true
        let series = buildTimeSeries(startingAt: Self.q1) {
            Entry(100.0)
            if includeExtra { Entry(200.0) }
            for step in 1...2 { Entry(Double(300 * step)) }
        }
        let values = series.valuesArray
        #expect(values.count == 4, "one, one optional, two from the loop")
        #expect(values[0].isEqual(to: 100))
        #expect(values[1].isEqual(to: 200))
        #expect(values[2].isEqual(to: 300))
        #expect(values[3].isEqual(to: 600))
    }

    @Test("Entry_CarriesAnOptionalLabel") func entryCarriesOptionalLabel() {
        #expect(Entry(5.0).value.isEqual(to: 5))
        #expect(Entry(5.0).label == nil)
        #expect(Entry(5.0, label: "opening").label == "opening")
    }

    /// Compound growth from a starting value: 100, then +10% twice.
    @Test("GrowthFrom_Compounds") func growthFromCompounds() {
        let entries = GrowthFrom(startValue: 100.0, rate: 0.10, periods: 3)
        #expect(entries.count == 3)
        #expect(entries[0].value.isEqual(to: 100))
        #expect(abs(entries[1].value - 110.0) < 1e-9)
        #expect(abs(entries[2].value - 121.0) < 1e-9)
    }

    /// `Growth(rate:periods:)` is a stub that traps rather than returning something plausible.
    /// Pinned so the trap is a documented contract rather than a surprise, and so that
    /// implementing it later is a deliberate change to a test rather than a silent one.
    @Test("Growth_IsAnUnimplementedStub", .requiresUnsanitizedRuntime)
    func growthIsAnUnimplementedStub() async {
        await #expect(processExitsWith: .failure) {
            _ = Growth(rate: 0.1, periods: 3) as [SimpleEntry<Double>]
        }
    }
}

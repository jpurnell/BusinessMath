//
//  ConsolidatedStatementsOracleTests.swift
//  BusinessMathTests
//
//  `ConsolidatedStatements` had **no test at all** — 25 members, the whole multi-entity store
//  and every statistic over it. Found by working the list of 729 never-executed functions
//  that `swift test --enable-code-coverage` produced; it was the largest single cluster.
//
//  The aggregations, the even- and odd-count medians, the mean, the descending rank, the
//  three removal shapes, subsetting, filtering and the `Codable` round trip were all
//  differenced against hand arithmetic. **Every one was already correct**, including the
//  even-count median — `(200 + 300) / 2`, the case implementations usually get wrong by
//  returning the lower middle.
//
//  Two details the author had already handled, worth pinning because they are easy to
//  "simplify" away: `entities` sorts by id and `periods` sorts by start date, so neither
//  leaks Swift's per-process randomised dictionary order into a financial report.
//
//  One thing was left to chance, and is now explicit: `ranked(for:by:entities:)` ended in
//  `pairs.sorted { $0.1 > $1.1 }`, and `sorted(by:)` is documented as **not guaranteed
//  stable**. Equal-valued entities came back in id order only because the current sort
//  happens to be stable and its input happens to be sorted. The tie-break is now written
//  down, which preserves today's output exactly and stops depending on an implementation
//  detail.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Consolidated statements against hand arithmetic")
struct ConsolidatedStatementsOracleTests {

    private static let q1 = Period.quarter(year: 2025, quarter: 1)
    private static let q2 = Period.quarter(year: 2025, quarter: 2)

    /// A summary with exactly the four figures the aggregations read.
    private static func summary(
        _ id: String, period: Period,
        revenue: Double, cogs: Double, assets: Double, equity: Double
    ) throws -> (Entity, FinancialPeriodSummary<Double>) {
        let entity = Entity(id: id, name: id)
        let periods = [period]
        let revenueAccount = try Account(
            entity: entity, name: "Revenue", incomeStatementRole: .revenue,
            timeSeries: TimeSeries(periods: periods, values: [revenue]))
        let costAccount = try Account(
            entity: entity, name: "COGS", incomeStatementRole: .costOfGoodsSold,
            timeSeries: TimeSeries(periods: periods, values: [cogs]))
        let income = try IncomeStatement(entity: entity, periods: periods,
                                         accounts: [revenueAccount, costAccount])
        let cashAccount = try Account(
            entity: entity, name: "Cash", balanceSheetRole: .cashAndEquivalents,
            timeSeries: TimeSeries(periods: periods, values: [assets]))
        let equityAccount = try Account(
            entity: entity, name: "Equity", balanceSheetRole: .commonStock,
            timeSeries: TimeSeries(periods: periods, values: [equity]))
        let balance = try BalanceSheet(entity: entity, periods: periods,
                                       accounts: [cashAccount, equityAccount])
        return (entity, try FinancialPeriodSummary(entity: entity, period: period,
                                                   incomeStatement: income, balanceSheet: balance))
    }

    /// Four entities, so the median lands on the even-count case.
    ///
    /// Revenue 100/200/300/400 against COGS 40/50/60/70, giving net income 60/150/240/330.
    private static func fourEntities() throws -> (ConsolidatedStatements<Double>, [Entity]) {
        var consolidated = ConsolidatedStatements<Double>()
        var entities: [Entity] = []
        let specs: [(String, Double, Double, Double, Double)] = [
            ("A", 100, 40, 1_000, 400),
            ("B", 200, 50, 2_000, 700),
            ("C", 300, 60, 3_000, 900),
            ("D", 400, 70, 4_000, 1_100),
        ]
        for (id, revenue, cogs, assets, equity) in specs {
            let (entity, built) = try summary(id, period: q1, revenue: revenue, cogs: cogs,
                                              assets: assets, equity: equity)
            consolidated.add(entity: entity, period: q1, summary: built)
            entities.append(entity)
        }
        return (consolidated, entities)
    }

    // MARK: - Aggregation

    @Test("Aggregates_AreSums") func aggregatesAreSums() throws {
        let (consolidated, _) = try Self.fourEntities()
        #expect(consolidated.aggregateRevenue(for: Self.q1).isEqual(to: 1_000))
        #expect(consolidated.aggregateNetIncome(for: Self.q1).isEqual(to: 780), "60 + 150 + 240 + 330")
        #expect(consolidated.aggregateTotalAssets(for: Self.q1).isEqual(to: 10_000))
        #expect(consolidated.aggregateTotalEquity(for: Self.q1).isEqual(to: 3_100))
    }

    /// The documented behaviour for a period nobody reported: zero, not nil and not a crash.
    @Test("Aggregates_AreZeroForAnEmptyPeriod") func aggregatesAreZeroForAnEmptyPeriod() throws {
        let (consolidated, _) = try Self.fourEntities()
        #expect(consolidated.aggregateRevenue(for: Self.q2).isEqual(to: 0))
        #expect(consolidated.aggregateNetIncome(for: Self.q2).isEqual(to: 0))
    }

    @Test("Aggregates_RespectAnEntitySubsetArgument") func aggregatesRespectASubset() throws {
        let (consolidated, entities) = try Self.fourEntities()
        let firstTwo = consolidated.aggregateRevenue(for: Self.q1, entities: [entities[0], entities[1]])
        #expect(firstTwo.isEqual(to: 300), "100 + 200")
    }

    // MARK: - Statistics

    /// The even-count median is the mean of the two middle values, which is the case that
    /// separates a correct median from one that returns the lower middle.
    @Test("Median_EvenCount_AveragesTheTwoMiddleValues") func medianEvenCount() throws {
        let (consolidated, _) = try Self.fourEntities()
        let median = try #require(consolidated.median(for: Self.q1, \.revenue))
        #expect(median.isEqual(to: 250), "(200 + 300) / 2, not 200")
    }

    @Test("Median_OddCount_IsTheMiddleValue") func medianOddCount() throws {
        var (consolidated, entities) = try Self.fourEntities()
        consolidated.remove(entity: entities[3])
        let median = try #require(consolidated.median(for: Self.q1, \.revenue))
        #expect(median.isEqual(to: 200), "middle of 100, 200, 300")
    }

    @Test("Median_IsNilWithNoData") func medianIsNilWithNoData() throws {
        let (consolidated, _) = try Self.fourEntities()
        #expect(consolidated.median(for: Self.q2, \.revenue) == nil)
    }

    @Test("Average_IsTheMean") func averageIsTheMean() throws {
        let (consolidated, _) = try Self.fourEntities()
        let mean = try #require(consolidated.average(for: Self.q1, \.revenue))
        #expect(mean.isEqual(to: 250), "1000 / 4")
        #expect(consolidated.average(for: Self.q2, \.revenue) == nil, "nil with no data")
    }

    @Test("Ranked_IsDescending") func rankedIsDescending() throws {
        let (consolidated, _) = try Self.fourEntities()
        let ranking = consolidated.ranked(for: Self.q1, by: \.revenue)
        #expect(ranking.map(\.0.id) == ["D", "C", "B", "A"], "highest first")
        #expect(ranking.map(\.1).first?.isEqual(to: 400) == true)
    }

    /// Ties resolve on entity id, and no longer depend on `sorted(by:)` being stable. The
    /// entities are inserted in reverse id order so a sort that ignored the tie-break would
    /// have to be lucky to produce this.
    @Test("Ranked_BreaksTiesOnEntityID") func rankedBreaksTiesOnEntityID() throws {
        var consolidated = ConsolidatedStatements<Double>()
        for id in ["D", "C", "B", "A"] {
            let (entity, built) = try Self.summary(id, period: Self.q1, revenue: 500,
                                                   cogs: 100, assets: 1, equity: 1)
            consolidated.add(entity: entity, period: Self.q1, summary: built)
        }
        #expect(consolidated.ranked(for: Self.q1, by: \.revenue).map(\.0.id) == ["A", "B", "C", "D"])
    }

    // MARK: - Ordering is not Swift's dictionary order

    @Test("EntitiesAndPeriods_AreDeterministicallyOrdered") func orderingIsDeterministic() throws {
        var consolidated = ConsolidatedStatements<Double>()
        // Inserted out of order in both dimensions.
        for (id, period) in [("D", Self.q2), ("A", Self.q2), ("C", Self.q1), ("B", Self.q1)] {
            let (entity, built) = try Self.summary(id, period: period, revenue: 1,
                                                   cogs: 0, assets: 1, equity: 1)
            consolidated.add(entity: entity, period: period, summary: built)
        }
        #expect(consolidated.entities.map(\.id) == ["A", "B", "C", "D"], "sorted by id, not hash order")
        #expect(consolidated.periods == [Self.q1, Self.q2], "sorted by start date")
    }

    // MARK: - Mutation

    @Test("Add_ReplacesAnExistingEntityPeriod") func addReplaces() throws {
        var consolidated = ConsolidatedStatements<Double>()
        let (entity, first) = try Self.summary("X", period: Self.q1, revenue: 111,
                                               cogs: 1, assets: 1, equity: 1)
        consolidated.add(entity: entity, period: Self.q1, summary: first)
        let (_, second) = try Self.summary("X", period: Self.q1, revenue: 222,
                                           cogs: 1, assets: 1, equity: 1)
        consolidated.add(entity: entity, period: Self.q1, summary: second)

        #expect(consolidated.entityCount == 1, "still one entity")
        #expect(consolidated.summary(for: entity, period: Self.q1)?.revenue.isEqual(to: 222) == true)
    }

    /// Removing one period leaves the entity known; removing the entity removes it entirely.
    @Test("Remove_HasThreeDistinctShapes") func removeHasThreeShapes() throws {
        var (consolidated, entities) = try Self.fourEntities()

        consolidated.remove(entity: entities[0], period: Self.q1)
        #expect(consolidated.entityCount == 4, "the entity is still known")
        #expect(!consolidated.contains(entity: entities[0], period: Self.q1))
        #expect(consolidated.aggregateRevenue(for: Self.q1).isEqual(to: 900), "1000 - 100")

        consolidated.remove(entity: entities[1])
        #expect(consolidated.entityCount == 3)
        #expect(consolidated.aggregateRevenue(for: Self.q1).isEqual(to: 700), "900 - 200")

        consolidated.removeAll()
        #expect(consolidated.entityCount == 0)
        #expect(consolidated.periods.isEmpty)
        #expect(consolidated.aggregateRevenue(for: Self.q1).isEqual(to: 0))
    }

    @Test("SubsetAndFilter_SelectEntities") func subsetAndFilterSelectEntities() throws {
        let (consolidated, entities) = try Self.fourEntities()

        let subset = consolidated.subset(entities: [entities[0], entities[1]])
        #expect(subset.entityCount == 2)
        #expect(subset.aggregateRevenue(for: Self.q1).isEqual(to: 300))

        let filtered = consolidated.filterEntities { $0.id == "A" || $0.id == "C" }
        #expect(filtered.map(\.id) == ["A", "C"])
    }

    @Test("SummariesAccessors_ReadBothWays") func summariesAccessorsReadBothWays() throws {
        let (consolidated, entities) = try Self.fourEntities()
        #expect(consolidated.summaries(for: entities[0]).count == 1, "one period for entity A")
        #expect(consolidated.summaries(for: Self.q1).count == 4, "four entities in Q1")
        #expect(consolidated.contains(entity: entities[2], period: Self.q1))
        #expect(!consolidated.contains(entity: entities[2], period: Self.q2))
    }

    // MARK: - Round trip

    @Test("Codable_RoundTripsEveryFigure") func codableRoundTrips() throws {
        let (consolidated, entities) = try Self.fourEntities()
        let data = try JSONEncoder().encode(consolidated)
        let restored = try JSONDecoder().decode(ConsolidatedStatements<Double>.self, from: data)

        #expect(restored.entityCount == 4)
        #expect(restored.entities.map(\.id) == ["A", "B", "C", "D"])
        #expect(restored.aggregateRevenue(for: Self.q1).isEqual(to: 1_000))
        #expect(restored.aggregateNetIncome(for: Self.q1).isEqual(to: 780))
        #expect(restored.summary(for: entities[2], period: Self.q1)?.revenue.isEqual(to: 300) == true)
    }
}

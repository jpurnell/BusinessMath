//
//  FinancialModelCacheTests.swift
//  BusinessMathTests
//
//  `FinancialModel`'s caching layer had no test — `cacheKey()`,
//  `calculateRevenueCached()`, `calculateCostsCached(revenue:)`, `calculateProfitCached()`
//  and `clearCalculationCache()`, all on a **static, shared** cache.
//
//  The defect a cache of this shape usually has is a key that does not capture every input,
//  so a second call with different arguments is served the first answer. Two things looked
//  like candidates and neither is one:
//
//  * `cacheKey()` takes no arguments while `calculateCostsCached(revenue:)` takes one — but
//    the argument is folded into the key separately, as `"\(cacheKey())_costs_\(revenue)"`.
//  * `cacheKey()` hashes only component names, amounts and cost types, ignoring each
//    component's `timeSeries` and `expenseType` — but the three cached calculations read only
//    `amount` and `type`, so the key covers exactly what they depend on.
//
//  Every cached value below is asserted equal to the uncached calculation, which is the only
//  property that matters: a cache may be fast or slow, but it may not be wrong.
//
//  **The key's value is deliberately never pinned.** It ends in `Hasher.finalize()`, and
//  Swift seeds `Hasher` randomly per process, so the string differs on every run. That is
//  harmless for an in-memory cache and fatal for a test that asserts the literal — so these
//  assert distinctness and agreement instead.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Financial model cache never disagrees with the direct calculation")
struct FinancialModelCacheTests {

    private static func model(revenue: Double, fixed: Double, variable: Double) -> FinancialModel {
        var model = FinancialModel()
        model.revenueComponents = [RevenueComponent(name: "Sales", amount: revenue)]
        model.costComponents = [
            CostComponent(name: "Rent", type: .fixed(fixed)),
            CostComponent(name: "COGS", type: .variable(variable)),
        ]
        return model
    }

    @Test("CachedMatchesDirect") func cachedMatchesDirect() {
        let model = Self.model(revenue: 1_000, fixed: 200, variable: 0.3)
        #expect(model.calculateRevenueCached().isEqual(to: model.calculateRevenue()))
        #expect(model.calculateRevenueCached().isEqual(to: 1_000))
        #expect(model.calculateCostsCached(revenue: 1_000).isEqual(to: model.calculateCosts(revenue: 1_000)))
        #expect(model.calculateCostsCached(revenue: 1_000).isEqual(to: 500), "200 fixed + 30% of 1000")
        #expect(model.calculateProfitCached().isEqual(to: model.calculateProfit()))
        #expect(model.calculateProfitCached().isEqual(to: 500))
    }

    /// A second model with the same shape but different amounts must not be served the
    /// first's entry — the cache is `static`, so both live in it at once.
    @Test("DifferentAmounts_AreNotServedTheFirstAnswer") func differentAmountsAreNotServedTheFirst() {
        let first = Self.model(revenue: 1_000, fixed: 200, variable: 0.3)
        _ = first.calculateRevenueCached()
        _ = first.calculateProfitCached()

        let second = Self.model(revenue: 2_000, fixed: 200, variable: 0.3)
        #expect(second.calculateRevenueCached().isEqual(to: 2_000))
        #expect(second.calculateProfitCached().isEqual(to: 1_200), "2000 - (200 + 600)")
        #expect(first.cacheKey() != second.cacheKey())

        // And the first is still itself after the second went through.
        #expect(first.calculateRevenueCached().isEqual(to: 1_000))
    }

    /// The `revenue` argument is part of the costs key, so the same model answers differently
    /// for different arguments rather than repeating its first answer.
    @Test("CostsVaryWithTheirArgument") func costsVaryWithTheirArgument() {
        let model = Self.model(revenue: 1_000, fixed: 200, variable: 0.3)
        #expect(model.calculateCostsCached(revenue: 1_000).isEqual(to: 500))
        #expect(model.calculateCostsCached(revenue: 500).isEqual(to: 350), "200 + 30% of 500")
        #expect(model.calculateCostsCached().isEqual(to: 200), "no revenue: the fixed part alone")
    }

    /// Mutating a component moves the key with it, so a struct copy does not inherit the
    /// original's cached answer.
    @Test("MutationMovesTheKey") func mutationMovesTheKey() {
        let original = Self.model(revenue: 1_000, fixed: 200, variable: 0.3)
        _ = original.calculateRevenueCached()

        var mutated = original
        mutated.revenueComponents = [RevenueComponent(name: "Sales", amount: 9_999)]
        #expect(mutated.cacheKey() != original.cacheKey())
        #expect(mutated.calculateRevenueCached().isEqual(to: 9_999))
        #expect(original.calculateRevenueCached().isEqual(to: 1_000), "the original is unchanged")
    }

    /// Clearing empties the shared cache without changing any answer.
    @Test("ClearingChangesNothingButTheCache") func clearingChangesNothingButTheCache() {
        let model = Self.model(revenue: 1_000, fixed: 200, variable: 0.3)
        let before = model.calculateProfitCached()
        FinancialModel.clearCalculationCache()
        let after = model.calculateProfitCached()
        #expect(before.isEqual(to: after))
        #expect(after.isEqual(to: model.calculateProfit()))
    }
}

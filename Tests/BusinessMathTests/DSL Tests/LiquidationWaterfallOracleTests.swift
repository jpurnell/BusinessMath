//
//  LiquidationWaterfallOracleTests.swift
//  BusinessMathTests
//
//  `LiquidationWaterfall.distribute(_:)` and the whole `LiquidationWaterfallBuilder` had no
//  test — ten never-executed members from the coverage list, including every result-builder
//  branch (`buildArray`, `buildEither`, `buildOptional`).
//
//  The oracle that matters here needs no knowledge of what `CatchUp` or `PreferredReturn`
//  mean: **conservation**. Every dollar of proceeds has to arrive somewhere — distributed to
//  a participant, or left in `remaining`. A waterfall that double-counts a tier, drops an
//  overflow or mis-orders a boundary breaks that identity, whatever the tier semantics are.
//
//  It held at every level tested, and the catch-up arithmetic is right in the stronger sense
//  too: on the documentation's own example the GP ends with exactly 20% of the profit above
//  returned capital.
//
//  One thing was left to the sort, and is now written down — see
//  ``EqualPriority_OrdersByName``.
//

import Testing
import Foundation
@testable import BusinessMathDSL

@Suite("Liquidation waterfall conserves what it distributes")
struct LiquidationWaterfallOracleTests {

    /// The "Complete Example" from the type's own documentation.
    private func documentedWaterfall() -> LiquidationWaterfall {
        LiquidationWaterfall {
            Tier("LP Capital + Preferred", priority: 1) {
                CapitalReturn(5_000_000)
                PreferredReturn(0.08, years: 5)
            }
            Tier("GP Catch-Up", priority: 2) {
                CatchUp(to: 0.20)
            }
            Tier("Residual", priority: 3) {
                ProRata([("LP", 0.80), ("GP", 0.20)])
            }
        }
    }

    // MARK: - Conservation

    /// Nothing is created and nothing is lost, at every level from a single dollar to five
    /// times the structure's capacity.
    @Test("Conservation_HoldsAtEveryLevel", arguments: [
        1.0, 1_000_000.0, 4_999_999.0, 5_000_000.0, 7_000_000.0,
        7_500_000.0, 10_000_000.0, 50_000_000.0,
    ])
    func conservationHoldsAtEveryLevel(proceeds: Double) {
        let result = documentedWaterfall().distribute(proceeds)
        let distributed = result.distributions.values.reduce(0, +)
        let accounted = distributed + result.remaining
        #expect(abs(accounted - proceeds) < 1e-6,
                "\(proceeds) in, \(distributed) distributed + \(result.remaining) remaining")
    }

    /// Proceeds a structure cannot absorb stay in `remaining` rather than vanishing or being
    /// forced into the last tier.
    @Test("NoResidualTier_LeavesTheOverflow") func noResidualTierLeavesOverflow() {
        let capped = LiquidationWaterfall {
            Tier("Senior", priority: 1) { CapitalReturn(500_000) }
        }
        let result = capped.distribute(1_000_000)
        #expect(result.distributions["Senior"]?.isEqual(to: 500_000) == true)
        #expect(result.remaining.isEqual(to: 500_000), "the structure cannot absorb the rest")
    }

    // MARK: - The documented example, by hand

    /// Tier one claims capital plus simple preferred: 5,000,000 + (0.08 × 5) × 5,000,000 = 7M.
    @Test("FirstTier_TakesCapitalPlusSimplePreferred") func firstTierTakesCapitalPlusPreferred() {
        let result = documentedWaterfall().distribute(10_000_000)
        #expect(result.distributions["LP Capital + Preferred"]?.isEqual(to: 7_000_000) == true)
    }

    /// The catch-up is correct in the sense that matters: after it and the pro-rata split, the
    /// GP holds exactly its 20% of the profit above returned capital.
    ///
    /// At 10M proceeds against 5M of capital the profit is 5M, so the GP should end at 1M —
    /// 500,000 from the catch-up tier and 500,000 from the 80/20 residual.
    @Test("CatchUp_LeavesTheGPAtItsTargetShare") func catchUpLeavesGPAtTargetShare() {
        let result = documentedWaterfall().distribute(10_000_000)
        let gpTotal = (result.distributions["GP Catch-Up"] ?? 0) + (result.distributions["GP"] ?? 0)
        let lpTotal = (result.distributions["LP Capital + Preferred"] ?? 0)
            + (result.distributions["LP"] ?? 0)

        #expect(gpTotal.isEqual(to: 1_000_000), "GP total")
        #expect(lpTotal.isEqual(to: 9_000_000), "LP total")

        let profit = 10_000_000.0 - 5_000_000.0
        #expect(abs(gpTotal / profit - 0.20) < 1e-12, "GP holds 20% of the 5M profit")
    }

    /// **The key names are not per participant.** A tier without a `ProRata` distributes under
    /// its *tier* name; a `ProRata` distributes under its *participant* names. So in the
    /// documented structure `distributions["LP"]` is the residual slice alone — 2,000,000 —
    /// and not the LP's 9,000,000. Pinned because it is a sharp edge a caller can read past.
    @Test("Keys_MixTierNamesAndParticipantNames") func keysMixTierAndParticipantNames() {
        let result = documentedWaterfall().distribute(10_000_000)
        #expect(Set(result.distributions.keys)
                    == ["LP Capital + Preferred", "GP Catch-Up", "LP", "GP"])
        #expect(result.distributions["LP"]?.isEqual(to: 2_000_000) == true,
                "the residual slice alone, not the LP's total")
    }

    // MARK: - Ordering

    /// Priority decides the order, not the order the tiers were written in.
    @Test("Priority_OverridesDeclarationOrder") func priorityOverridesDeclarationOrder() {
        let waterfall = LiquidationWaterfall {
            Tier("Second", priority: 2) { Residual() }
            Tier("First", priority: 1) { CapitalReturn(400_000) }
        }
        let result = waterfall.distribute(1_000_000)
        #expect(result.distributions["First"]?.isEqual(to: 400_000) == true)
        #expect(result.distributions["Second"]?.isEqual(to: 600_000) == true)
    }

    /// Equal priorities resolve on name, which used to be left to `sorted(by:)` — documented
    /// as not guaranteed stable. Here the money runs out inside the tie, so the order decides
    /// who is paid in full and who is short: Alpha takes 300,000 and Beta the remaining
    /// 200,000. The tiers are declared in reverse name order so a sort that ignored the
    /// tie-break would have to be lucky to produce this.
    @Test("EqualPriority_OrdersByName") func equalPriorityOrdersByName() {
        let waterfall = LiquidationWaterfall {
            Tier("Beta", priority: 1) { CapitalReturn(300_000) }
            Tier("Alpha", priority: 1) { CapitalReturn(300_000) }
            Tier("Rest", priority: 2) { Residual() }
        }
        let result = waterfall.distribute(500_000)
        #expect(result.distributions["Alpha"]?.isEqual(to: 300_000) == true, "paid first, in full")
        #expect(result.distributions["Beta"]?.isEqual(to: 200_000) == true, "paid second, short")
        #expect(result.distributions["Rest"]?.isEqual(to: 0) == true, "nothing left")
    }

    // MARK: - Guards and builder branches

    @Test("NonPositiveProceeds_DistributeNothing", arguments: [0.0, -1_000_000.0])
    func nonPositiveProceedsDistributeNothing(proceeds: Double) {
        let result = documentedWaterfall().distribute(proceeds)
        #expect(result.distributions.values.allSatisfy { $0.isEqual(to: 0) })
        #expect(result.remaining.isEqual(to: 0))
    }

    /// `ProRata` requires its weights to sum to one, and says so rather than silently
    /// distributing 80% of the tier.
    @Test("ProRataWeights_MustSumToOne", .requiresUnsanitizedRuntime)
    func proRataWeightsMustSumToOne() async {
        await #expect(processExitsWith: .failure) {
            _ = ProRata([("A", 0.5), ("B", 0.3)])
        }
    }

    // MARK: - The builder branches, which could not be written until now

    /// `buildOptional`: a tier behind an `if` with no `else`. This form did not compile —
    /// *"conflicting arguments to generic parameter 'Wrapped'"* — because `buildOptional`
    /// returned `Tier?` where `buildBlock` consumed `Tier`.
    @Test("BuilderOptional_IncludesAndOmits") func builderOptionalIncludesAndOmits() {
        func waterfall(includeSenior: Bool) -> LiquidationWaterfall {
            LiquidationWaterfall {
                if includeSenior {
                    Tier("Senior", priority: 1) { CapitalReturn(200_000) }
                }
                Tier("Rest", priority: 2) { Residual() }
            }
        }

        let withSenior = waterfall(includeSenior: true).distribute(1_000_000)
        #expect(withSenior.distributions["Senior"]?.isEqual(to: 200_000) == true)
        #expect(withSenior.distributions["Rest"]?.isEqual(to: 800_000) == true)

        let without = waterfall(includeSenior: false).distribute(1_000_000)
        #expect(without.distributions["Senior"] == nil, "omitted entirely")
        #expect(without.distributions["Rest"]?.isEqual(to: 1_000_000) == true)
    }

    /// `buildEither`: both arms of an `if`/`else`. This form did not compile — *"cannot
    /// convert value of type 'LiquidationWaterfall' to expected argument type 'Tier'"*.
    @Test("BuilderEither_TakesBothArms") func builderEitherTakesBothArms() {
        func waterfall(useResidual: Bool) -> LiquidationWaterfall {
            LiquidationWaterfall {
                if useResidual {
                    Tier("ResidualBranch", priority: 1) { Residual() }
                } else {
                    Tier("SplitBranch", priority: 1) { ProRata([("X", 0.5), ("Y", 0.5)]) }
                }
            }
        }

        let first = waterfall(useResidual: true).distribute(1_000_000)
        #expect(first.distributions["ResidualBranch"]?.isEqual(to: 1_000_000) == true)

        let second = waterfall(useResidual: false).distribute(1_000_000)
        #expect(second.distributions["X"]?.isEqual(to: 500_000) == true)
        #expect(second.distributions["Y"]?.isEqual(to: 500_000) == true)
        #expect(second.distributions["ResidualBranch"] == nil)
    }

    /// `buildArray`: a `for` loop. This form did not compile — *"cannot convert value of type
    /// '[LiquidationWaterfall]' to expected argument type '[Tier]'"*.
    @Test("BuilderArray_LoopsOverTiers") func builderArrayLoopsOverTiers() {
        let waterfall = LiquidationWaterfall {
            for index in 1...3 {
                Tier("T\(index)", priority: index) { CapitalReturn(100_000) }
            }
            Tier("Rest", priority: 99) { Residual() }
        }
        let result = waterfall.distribute(1_000_000)

        for index in 1...3 {
            #expect(result.distributions["T\(index)"]?.isEqual(to: 100_000) == true, "tier \(index)")
        }
        #expect(result.distributions["Rest"]?.isEqual(to: 700_000) == true)

        let accounted = result.distributions.values.reduce(0, +) + result.remaining
        #expect(abs(accounted - 1_000_000) < 1e-6, "a looped waterfall still conserves")
    }

    /// A loop and a branch in the same block, which is the combination that motivated
    /// threading `[Tier]` through every `build*` rather than patching one of them.
    @Test("BuilderForms_Compose") func builderFormsCompose() {
        let includeFloor = true
        let waterfall = LiquidationWaterfall {
            if includeFloor {
                Tier("Floor", priority: 1) { CapitalReturn(50_000) }
            }
            for index in 1...2 {
                Tier("Mid\(index)", priority: index + 1) { CapitalReturn(100_000) }
            }
            Tier("Rest", priority: 99) { Residual() }
        }
        let result = waterfall.distribute(1_000_000)
        #expect(result.distributions["Floor"]?.isEqual(to: 50_000) == true)
        #expect(result.distributions["Mid1"]?.isEqual(to: 100_000) == true)
        #expect(result.distributions["Mid2"]?.isEqual(to: 100_000) == true)
        #expect(result.distributions["Rest"]?.isEqual(to: 750_000) == true)
    }
}

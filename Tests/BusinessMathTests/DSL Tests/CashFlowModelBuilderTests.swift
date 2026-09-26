//
//  CashFlowModelBuilderTests.swift
//  BusinessMathTests
//
//  The second result builder in this package whose `build*` methods no valid program could
//  call, found by sweeping the class after `LiquidationWaterfallBuilder`.
//
//  `CashFlowModelBuilder` consumed `CashFlowModelComponent` in `buildBlock` and returned
//  `CashFlowModel`, while `buildOptional` returned `CashFlowModelComponent?` and the
//  `buildExpression` in its extension returned a bare `CashFlowModelComponent`. A result
//  builder needs one partial-result type through every `build*`, so a `for` loop inside a
//  projection did not compile:
//
//      error: cannot convert value of type '[CashFlowModel]'
//             to expected argument type '[CashFlowModelComponent]'
//
//  Behind that sat a second defect, latent only because the first made it unreachable:
//
//      public static func buildArray(_ components: [CashFlowModelComponent]) -> CashFlowModelComponent {
//          // For array support, just take first component
//          components.first ?? .revenue(Revenue(baseValue: 0))
//      }
//
//  Had a loop ever compiled, it would have silently dropped every component after the first —
//  and substituted a **zero-revenue component nobody wrote** when the loop produced none. The
//  comment admits the first half and not the second.
//
//  The builder now threads `[CashFlowModelComponent]` with a `buildFinalResult`, and
//  `buildArray` keeps everything it is given.
//

import Testing
@testable import BusinessMathDSL

@Suite("Cash flow model builder composes control flow")
struct CashFlowModelBuilderTests {

    /// The straight-line form, which always worked and must keep working unchanged.
    @Test("StraightLine_Unchanged") func straightLineUnchanged() {
        let model = CashFlowProjection {
            Revenue(baseValue: 1_000)
            Taxes(corporateRate: 0.21)
        }.wrappedValue

        #expect(model.revenue?.baseValue.isEqual(to: 1_000) == true)
        #expect(model.taxes?.corporateRate.isEqual(to: 0.21) == true)
        #expect(model.expenses == nil)
        #expect(model.depreciation == nil)
    }

    /// `buildOptional`: a component behind an `if` with no `else`.
    @Test("Optional_IncludesAndOmits") func optionalIncludesAndOmits() {
        func projection(withTaxes: Bool) -> CashFlowModel {
            CashFlowProjection {
                Revenue(baseValue: 1_000)
                if withTaxes {
                    Taxes(corporateRate: 0.21)
                }
            }.wrappedValue
        }

        #expect(projection(withTaxes: true).taxes?.corporateRate.isEqual(to: 0.21) == true)
        #expect(projection(withTaxes: false).taxes == nil, "omitted entirely")
        #expect(projection(withTaxes: false).revenue?.baseValue.isEqual(to: 1_000) == true,
                "and the rest of the block survives")
    }

    /// `buildEither`: both arms of an `if`/`else`.
    @Test("Either_TakesBothArms") func eitherTakesBothArms() {
        func projection(highTax: Bool) -> CashFlowModel {
            CashFlowProjection {
                Revenue(baseValue: 1_000)
                if highTax {
                    Taxes(corporateRate: 0.35)
                } else {
                    Taxes(corporateRate: 0.15)
                }
            }.wrappedValue
        }

        #expect(projection(highTax: true).taxes?.corporateRate.isEqual(to: 0.35) == true)
        #expect(projection(highTax: false).taxes?.corporateRate.isEqual(to: 0.15) == true)
    }

    /// `buildArray`: a `for` loop. This is the form that did not compile, and whose
    /// implementation would have discarded all but the first component if it had.
    ///
    /// Four revenues are yielded and the **last** wins, because resolving components is
    /// last-write-wins by kind — the behaviour `buildBlock` always had. What matters is that
    /// all four reached the resolver rather than only `Revenue(100)`.
    @Test("Array_KeepsEveryComponent") func arrayKeepsEveryComponent() {
        let model = CashFlowProjection {
            for multiplier in 1...4 {
                Revenue(baseValue: Double(100 * multiplier))
            }
        }.wrappedValue

        #expect(model.revenue?.baseValue.isEqual(to: 400) == true,
                "the fourth, not the first — every component reached the resolver")
    }

    /// An empty loop contributes nothing. The old `buildArray` would have substituted
    /// `.revenue(Revenue(baseValue: 0))` here — a component the caller never wrote, silently
    /// turning an empty projection into a zero-revenue one.
    @Test("EmptyArray_InventsNothing") func emptyArrayInventsNothing() {
        let model = CashFlowProjection {
            for _ in 0..<0 {
                Revenue(baseValue: 1_000)
            }
        }.wrappedValue

        #expect(model.revenue == nil, "no phantom zero-revenue component")
        #expect(model.expenses == nil)
        #expect(model.depreciation == nil)
        #expect(model.taxes == nil)
    }

    /// A loop and a branch in the same block — the combination that motivated fixing the
    /// partial-result type rather than patching one method.
    @Test("Forms_Compose") func formsCompose() {
        let applyTax = true
        let model = CashFlowProjection {
            for multiplier in 1...2 {
                Revenue(baseValue: Double(500 * multiplier))
            }
            if applyTax {
                Taxes(corporateRate: 0.21)
            }
        }.wrappedValue

        #expect(model.revenue?.baseValue.isEqual(to: 1_000) == true, "the last of the loop")
        #expect(model.taxes?.corporateRate.isEqual(to: 0.21) == true)
    }
}

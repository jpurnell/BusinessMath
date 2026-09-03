//
//  TypedModelBindingTests.swift
//  BusinessMath
//

import Testing
import Foundation
@testable import BusinessMath

/// Binding the typed layer to the model that evaluates it.
///
/// The contract these tests exist to hold: **the typed layer is a spelling, not a
/// second engine.** A model written with ``LineItem`` and ``Expr`` must be the same
/// model — same definitions, same numbers — as one written with strings. Anything
/// else would mean two implementations of the same semantics, drifting apart at
/// whatever rate they were maintained.
@Suite("Typed Model Binding")
struct TypedModelBindingTests {

    private let years = [Period.year(2024), Period.year(2025), Period.year(2026)]

    private let revenue = LineItem<Money>("Revenue")
    private let margin = LineItem<Ratio>("Margin")
    private let ebitda = LineItem<Money>("EBITDA")

    private func series(_ values: [Double]) -> TimeSeries<Double> {
        TimeSeries(periods: Array(years.prefix(values.count)), values: values)
    }

    // MARK: - Defining

    @Test("A typed definition lands as the formula the string API would hold")
    func typedDefiningMatchesTheStringForm() {
        let typed = ModelDefinition<Double>()
            .defining(ebitda, as: revenue.expr * margin.expr)
        let strings = ModelDefinition<Double>()
            .defining("EBITDA", as: "([Revenue] * [Margin])")

        #expect(typed.definitions == strings.definitions)
    }

    @Test("Typed and string definitions can be mixed in one model")
    func typedAndStringMix() {
        let model = ModelDefinition<Double>()
            .defining(ebitda, as: revenue.expr * margin.expr)
            .defining("Tax", as: "EBITDA * 0.25")

        #expect(model.definitions.count == 2)
        #expect(model.formula(for: "Tax") == "EBITDA * 0.25")
    }

    /// Defining the same item twice replaces the formula rather than duplicating
    /// it — the same rule the string API already holds, reached through the typed
    /// overload.
    @Test("Redefining an item replaces its formula in place")
    func redefiningReplaces() {
        let model = ModelDefinition<Double>()
            .defining(ebitda, as: revenue.expr * margin.expr)
            .defining(ebitda, as: revenue.expr - revenue.expr)

        #expect(model.definitions.count == 1)
        #expect(model.formula(for: "EBITDA") == "([Revenue] - [Revenue])")
    }

    // MARK: - Reading results back

    @Test("A typed item reads its own series out of a result")
    func seriesReadsBackByItem() throws {
        let model = ModelDefinition<Double>(
            inputs: ["Revenue": series([1_000, 1_100, 1_210]), "Margin": series([0.4, 0.4, 0.4])]
        )
        .defining(ebitda, as: revenue.expr * margin.expr)

        let solved = try model.solve()
        let read = try #require(model.series(for: ebitda, in: solved))

        #expect(read[Period.year(2024)] == 400)
        #expect(read[Period.year(2026)] == 484)
    }

    @Test("An item the model never produced reads as nothing")
    func unknownItemReadsAsNil() throws {
        let model = ModelDefinition<Double>(inputs: ["Revenue": series([1_000])])
        let solved = try model.solve()

        #expect(model.series(for: LineItem<Money>("Absent"), in: solved) == nil)
    }

    // MARK: - The worked example

    /// §4's cash sweep: interest on an opening balance, a sweep bounded by the
    /// cash available, and a closing balance that falls by what was swept.
    ///
    /// Both spellings are built and evaluated, and the numbers are compared to
    /// each other rather than to a constant. A constant would pass if both drifted
    /// together; this cannot.
    @Test("The cash sweep evaluates identically to its string form")
    func cashSweepMatchesTheStringForm() throws {
        let fcf = LineItem<Money>("Free Cash Flow")
        let openingDebt = LineItem<Money>("Opening Debt")
        let interestRate = LineItem<Rate>("Interest Rate", basis: .annual)
        let interest = LineItem<Money>("Interest")
        let sweep = LineItem<Money>("Sweep")
        let closingDebt = LineItem<Money>("Closing Debt")

        let inputs: [String: TimeSeries<Double>] = [
            "Free Cash Flow": series([30, 30, 30]),
            "Opening Debt": series([100, 100, 100]),
            "Interest Rate": series([0.1, 0.1, 0.1]),
        ]

        let typed = ModelDefinition<Double>(inputs: inputs)
            .defining(interest, as: openingDebt.expr * interestRate.expr)
            .defining(sweep, as: min(fcf.expr, openingDebt.expr))
            .defining(closingDebt, as: openingDebt.expr - sweep.expr)

        let strings = ModelDefinition<Double>(inputs: inputs)
            .defining("Interest", as: "([Opening Debt] * [Interest Rate])")
            .defining("Sweep", as: "MIN([Free Cash Flow], [Opening Debt])")
            .defining("Closing Debt", as: "([Opening Debt] - [Sweep])")

        let fromTyped = try typed.solve()
        let fromStrings = try strings.solve()

        for name in ["Interest", "Sweep", "Closing Debt"] {
            for period in years {
                #expect(
                    fromTyped[name]?[period] == fromStrings[name]?[period],
                    "\(name) in \(period) differs between the two spellings")
            }
        }

        // And the numbers themselves, so a shared failure cannot pass quietly.
        #expect(fromTyped["Interest"]?[Period.year(2024)] == 10)
        #expect(fromTyped["Sweep"]?[Period.year(2024)] == 30)
        #expect(fromTyped["Closing Debt"]?[Period.year(2024)] == 70)
    }

    /// The growth idiom, end to end: `Revenue × (1 + g)` through ``factor(_:)``.
    @Test("A growth factor evaluates to one plus the rate")
    func growthFactorEvaluates() throws {
        let growth = LineItem<Rate>("Growth", basis: .annual)
        let grown = LineItem<Money>("Grown Revenue")

        let model = ModelDefinition<Double>(
            inputs: ["Revenue": series([1_000]), "Growth": series([0.15])]
        )
        .defining(grown, as: revenue.expr * factor(growth.expr))

        let solved = try model.solve()
        #expect(solved["Grown Revenue"]?[Period.year(2024)] == 1_150)
    }
}

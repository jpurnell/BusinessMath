//
//  ExprTests.swift
//  BusinessMath
//

import Testing
import Foundation
@testable import BusinessMath

/// The unit algebra: what combinations of quantities mean something.
///
/// An ``Expr`` renders a string the ``FormulaEvaluator`` grammar already reads, so
/// the typed layer is a **spelling** rather than a second engine. Every test here
/// checks the rendering; the checks that matter most are the ones that cannot be
/// written at all, and those live in `Tests/CompileFailures/`.
@Suite("Expression Algebra")
struct ExprTests {

    private let revenue = LineItem<Money>("Revenue")
    private let cost = LineItem<Money>("Cost")
    private let margin = LineItem<Ratio>("Margin")
    private let growth = LineItem<Rate>("Growth", basis: .annual)
    private let years = LineItem<Count>("Years")

    // MARK: - Rendering

    @Test("A line item renders as its bracketed name")
    func itemRenders() {
        #expect(revenue.expr.formula == "[Revenue]")
    }

    /// Bracketed always, because the grammar reads `&`, `/` and spaces as
    /// operators. `Sales & Marketing` unbracketed reaches the parser as three
    /// tokens, and `A/P` becomes a division.
    @Test("A name carrying punctuation survives")
    func awkwardNamesSurvive() {
        #expect(LineItem<Money>("Sales & Marketing").expr.formula == "[Sales & Marketing]")
        #expect(LineItem<Money>("A/P").expr.formula == "[A/P]")
    }

    @Test("Same-unit addition and subtraction")
    func additionAndSubtraction() {
        #expect((revenue.expr + cost.expr).formula == "([Revenue] + [Cost])")
        #expect((revenue.expr - cost.expr).formula == "([Revenue] - [Cost])")
        #expect((-revenue.expr).formula == "(0.0 - [Revenue])")
    }

    @Test("Money scales by a dimensionless quantity, in either order")
    func moneyScales() {
        #expect((revenue.expr * margin.expr).formula == "([Revenue] * [Margin])")
        #expect((margin.expr * revenue.expr).formula == "([Margin] * [Revenue])")
        #expect((revenue.expr * growth.expr).formula == "([Revenue] * [Growth])")
        #expect((growth.expr * revenue.expr).formula == "([Growth] * [Revenue])")
    }

    @Test("Division derives its dimension")
    func divisionDerivesDimension() {
        let asMargin: Expr<Ratio> = revenue.expr / cost.expr
        let perYear: Expr<Money> = revenue.expr / years.expr
        let grossedUp: Expr<Money> = revenue.expr / margin.expr
        #expect(asMargin.formula == "([Revenue] / [Cost])")
        #expect(perYear.formula == "([Revenue] / [Years])")
        #expect(grossedUp.formula == "([Revenue] / [Margin])")
    }

    @Test("Nesting parenthesises by construction")
    func nestingIsExplicit() {
        let ebitda = (revenue.expr - cost.expr) * margin.expr
        #expect(ebitda.formula == "(([Revenue] - [Cost]) * [Margin])")
    }

    // MARK: - Literals

    /// Literals are explicit by construction rather than `ExpressibleByFloatLiteral`.
    ///
    /// A bare `0.4` would infer its unit from context, which reintroduces exactly
    /// the ambiguity the units exist to prevent — and produces the overload
    /// diagnostics Swift reports worst.
    @Test("Literals name their own unit")
    func literalsAreExplicit() {
        #expect(money(1_000).formula == "1000.0")
        #expect(ratio(0.4).formula == "0.4")
        #expect(rate(0.1, per: .annual).formula == "0.1")
    }

    /// `1 + g` cannot be written: a dimensionless one and a per-period rate are
    /// not the same dimension, and no overload adds them. The growth factor is a
    /// quantity in its own right, so it gets a name — see §15 Q7.
    @Test("The growth factor is one plus a rate")
    func growthFactor() {
        #expect(factor(growth.expr).formula == "(1.0 + [Growth])")

        let grown: Expr<Money> = revenue.expr * factor(growth.expr)
        #expect(grown.formula == "([Revenue] * (1.0 + [Growth]))")
    }

    // MARK: - Functions

    @Test("MIN and MAX keep the unit they are given")
    func minAndMaxPreserveUnit() {
        let swept: Expr<Money> = min(revenue.expr, cost.expr)
        #expect(swept.formula == "MIN([Revenue], [Cost])")
        #expect(max(revenue.expr, cost.expr).formula == "MAX([Revenue], [Cost])")
    }

    @Test("ABS keeps its unit")
    func absPreservesUnit() {
        #expect(abs(revenue.expr).formula == "ABS([Revenue])")
    }

    // MARK: - The worked example

    /// §4's cash sweep, which the string API could always express and no typed
    /// layer could until now.
    @Test("The cash sweep renders what the string API expects")
    func cashSweepRenders() {
        let fcf = LineItem<Money>("Free Cash Flow")
        let openingDebt = LineItem<Money>("Opening Debt")
        let interestRate = LineItem<Rate>("Interest Rate", basis: .annual)

        #expect(
            (openingDebt.expr * interestRate.expr).formula
                == "([Opening Debt] * [Interest Rate])")
        #expect(
            min(fcf.expr, openingDebt.expr).formula == "MIN([Free Cash Flow], [Opening Debt])")
        #expect(
            (openingDebt.expr - min(fcf.expr, openingDebt.expr)).formula
                == "([Opening Debt] - MIN([Free Cash Flow], [Opening Debt]))")
    }

    /// The rendering must be something the evaluator actually reads back.
    ///
    /// The point of the typed layer is that it produces the same model the string
    /// API does, so this evaluates a typed expression through the real evaluator
    /// rather than trusting the string looks right.
    @Test("What Expr renders, the evaluator evaluates")
    func renderingRoundTrips() throws {
        let year = [Period.year(2024)]
        let model = ModelDefinition<Double>(
            inputs: [
                "Revenue": TimeSeries(periods: year, values: [1_000]),
                "Margin": TimeSeries(periods: year, values: [0.4]),
            ]
        )
        .defining("EBITDA", as: (revenue.expr * margin.expr).formula)

        let solved = try model.solve()
        #expect(solved["EBITDA"]?[Period.year(2024)] == 400)
    }
}

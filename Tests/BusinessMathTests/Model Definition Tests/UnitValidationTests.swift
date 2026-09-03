//
//  UnitValidationTests.swift
//  BusinessMath
//

import Testing
import Foundation
@testable import BusinessMath

/// The checks a unit can make that a compiler cannot.
///
/// Phase 3's algebra rejects combinations that are wrong for *any* model:
/// `money + ratio` means nothing regardless of what is being modelled. This is the
/// other half — the errors that depend on the model itself, and so can only be
/// found once one exists.
///
/// Two accounts named alike but measured differently, a rate that never says what
/// period it is per, and a rate declared annual and applied to a monthly timeline
/// are all perfectly well-typed expressions. They are also all wrong, and each one
/// evaluates cleanly to a number nobody should trust.
@Suite("Unit Validation")
struct UnitValidationTests {

    private let years = [Period.year(2024), Period.year(2025)]

    private func annual(_ values: [Double]) -> TimeSeries<Double> {
        TimeSeries(periods: Array(years.prefix(values.count)), values: values)
    }

    private func monthly(_ values: [Double]) -> TimeSeries<Double> {
        let months = (1...values.count).map { Period.month(year: 2024, month: $0) }
        return TimeSeries(periods: months, values: values)
    }

    // MARK: - A clean model

    @Test("A model whose units agree validates")
    func consistentModelValidates() {
        let revenue = LineItem<Money>("Revenue")
        let margin = LineItem<Ratio>("Margin")
        let model = ModelDefinition<Double>(inputs: ["Revenue": annual([1_000])])
            .defining(LineItem<Money>("EBITDA"), as: revenue.expr * margin.expr)

        #expect(throws: Never.self) { try model.validateUnits() }
    }

    /// A model written entirely with strings declares no units, so there is
    /// nothing to check and nothing to complain about. Saying so plainly matters:
    /// a caller should not read a clean `validateUnits()` as evidence that an
    /// untyped model is sound.
    @Test("A model written with strings has nothing to validate")
    func untypedModelValidatesVacuously() throws {
        let model = ModelDefinition<Double>(inputs: ["Revenue": annual([1_000])])
            .defining("EBITDA", as: "Revenue * 0.4")

        try model.validateUnits()
        #expect(model.unitDeclarations.isEmpty)
    }

    // MARK: - Conflicting units

    /// The Wharton collision, in typed form. That sheet has a `Debt` row on the
    /// timeline in dollars and a `Debt` assumption at 60% of purchase price, and
    /// resolving one to the other computed 0.6 where the model wanted 240.98.
    @Test("Two items sharing a name and differing in unit conflict")
    func conflictingUnitsAreCaught() throws {
        let debtAmount = LineItem<Money>("Debt")
        let debtShare = LineItem<Ratio>("Debt")
        let price = LineItem<Money>("Purchase Price")

        let model = ModelDefinition<Double>()
            .defining(LineItem<Money>("Funded"), as: debtAmount.expr + price.expr)
            .defining(LineItem<Money>("Implied"), as: price.expr * debtShare.expr)

        #expect(throws: TypedModelError.self) { try model.validateUnits() }

        do {
            try model.validateUnits()
            Issue.record("expected a conflict")
        } catch let error as TypedModelError {
            #expect(error == .conflictingUnits(name: "Debt", "money", "ratio"))
        }
    }

    @Test("The same name at the same unit is not a conflict")
    func repeatedItemsAreFine() {
        let revenue = LineItem<Money>("Revenue")
        let model = ModelDefinition<Double>()
            .defining(LineItem<Money>("Doubled"), as: revenue.expr + revenue.expr)
            .defining(LineItem<Money>("Tripled"), as: revenue.expr + revenue.expr + revenue.expr)

        #expect(throws: Never.self) { try model.validateUnits() }
    }

    // MARK: - Rate basis

    @Test("A rate that never says what period it is per is caught")
    func missingRateBasisIsCaught() throws {
        let balance = LineItem<Money>("Balance")
        let rate = LineItem<Rate>("Interest Rate")   // no basis
        let model = ModelDefinition<Double>(inputs: ["Balance": annual([100])])
            .defining(LineItem<Money>("Interest"), as: balance.expr * rate.expr)

        do {
            try model.validateUnits()
            Issue.record("expected a missing basis")
        } catch let error as TypedModelError {
            #expect(error == .missingRateBasis(account: "Interest Rate"))
        }
    }

    /// The error this whole layer is worth building for. An annual rate on a
    /// monthly timeline is off by twelve, evaluates without complaint, and looks
    /// entirely plausible in a report.
    @Test("An annual rate on a monthly timeline is caught")
    func rateBasisMismatchIsCaught() throws {
        let balance = LineItem<Money>("Balance")
        let rate = LineItem<Rate>("Interest Rate", basis: .annual)
        let model = ModelDefinition<Double>(inputs: ["Balance": monthly([100, 100, 100])])
            .defining(LineItem<Money>("Interest"), as: balance.expr * rate.expr)

        do {
            try model.validateUnits()
            Issue.record("expected a basis mismatch")
        } catch let error as TypedModelError {
            #expect(
                error == .rateBasisMismatch(
                    account: "Interest Rate", declared: .annual, applied: .monthly))
        }
    }

    @Test("A rate matching the timeline validates")
    func matchingBasisValidates() {
        let balance = LineItem<Money>("Balance")
        let rate = LineItem<Rate>("Interest Rate", basis: .monthly)
        let model = ModelDefinition<Double>(inputs: ["Balance": monthly([100])])
            .defining(LineItem<Money>("Interest"), as: balance.expr * rate.expr)

        #expect(throws: Never.self) { try model.validateUnits() }
    }

    /// A model with no data has no timeline, so there is nothing to compare a
    /// declared basis against. Refusing here would reject a model being assembled
    /// before its figures arrive, which §4 explicitly allows.
    @Test("A model with no timeline cannot mismatch a basis")
    func noTimelineMeansNoBasisCheck() {
        let balance = LineItem<Money>("Balance")
        let rate = LineItem<Rate>("Interest Rate", basis: .annual)
        let model = ModelDefinition<Double>()
            .defining(LineItem<Money>("Interest"), as: balance.expr * rate.expr)

        #expect(throws: Never.self) { try model.validateUnits() }
    }

    // MARK: - What the model knows

    @Test("An expression carries every item it reads")
    func expressionsCarryTheirReferences() {
        let revenue = LineItem<Money>("Revenue")
        let margin = LineItem<Ratio>("Margin")
        let expr = revenue.expr * margin.expr - revenue.expr

        #expect(Set(expr.declarations.map(\.name)) == ["Revenue", "Margin"])
    }

    @Test("A defined item is declared alongside the items it reads")
    func definingRecordsBothSides() {
        let revenue = LineItem<Money>("Revenue")
        let model = ModelDefinition<Double>()
            .defining(LineItem<Money>("Doubled"), as: revenue.expr + revenue.expr)

        #expect(Set(model.unitDeclarations.map(\.name)) == ["Revenue", "Doubled"])
    }

    @Test("A literal declares nothing")
    func literalsDeclareNothing() {
        #expect(money(100).declarations.isEmpty)
        #expect(factor(rate(0.1, per: .annual)).declarations.isEmpty)
    }
}

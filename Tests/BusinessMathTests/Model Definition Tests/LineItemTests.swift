//
//  LineItemTests.swift
//  BusinessMath
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// The typed handle a model is written against.
///
/// `ModelDefinition` names its accounts with strings, which is what makes it
/// serializable and what lets a spreadsheet importer target it. The cost is that a
/// misspelling is a runtime failure and a rename is a search-and-replace.
/// ``LineItem`` is the same name carried in a Swift value, so the compiler holds
/// it: a misspelling does not compile, and rename works.
///
/// The unit is a **phantom** parameter — it exists at compile time and touches
/// nothing at runtime. `LineItem<Money>("Revenue")` and `LineItem<Ratio>("Revenue")`
/// name the same account in the same model and are different Swift types, which is
/// the whole mechanism: the check happens before the model is ever built.
@Suite("Line Item")
struct LineItemTests {

    @Test("A line item carries the name the model knows it by")
    func carriesItsName() {
        #expect(LineItem<Money>("Revenue").name == "Revenue")
    }

    @Test("A rate carries the period it is expressed per")
    func rateCarriesItsBasis() {
        let rate = LineItem<Rate>("Interest Rate", basis: .annual)
        #expect(rate.basis == .annual)
        #expect(LineItem<Money>("Revenue").basis == nil, "only a rate has one")
    }

    /// The basis is a value, not a second type parameter.
    ///
    /// §12 settled this: a rate's period is data a model validates, not a
    /// dimension the compiler tracks. Making it a type would double the
    /// parameter list of every rate expression to catch an error `validateUnits()`
    /// catches with a better message.
    @Test("Two rates on different bases are the same type")
    func basisIsNotPartOfTheType() {
        let annual = LineItem<Rate>("Coupon", basis: .annual)
        let monthly = LineItem<Rate>("Coupon", basis: .monthly)
        #expect(type(of: annual) == type(of: monthly))
        #expect(annual != monthly, "and still not the same value")
    }

    @Test("Items differing only in unit are distinct types")
    func unitDistinguishesTypes() {
        #expect(type(of: LineItem<Money>("X")) != type(of: LineItem<Ratio>("X")))
    }

    @Test("Items of one unit compare by name and basis")
    func equatableWithinAUnit() {
        #expect(LineItem<Money>("Revenue") == LineItem<Money>("Revenue"))
        #expect(LineItem<Money>("Revenue") != LineItem<Money>("Cost"))
        #expect(
            LineItem<Rate>("Coupon", basis: .annual) != LineItem<Rate>("Coupon", basis: .monthly))
    }

    @Test("Every unit states a symbol")
    func unitsHaveSymbols() {
        #expect(Money.symbol == "money")
        #expect(Rate.symbol == "rate")
        #expect(Ratio.symbol == "ratio")
        #expect(Count.symbol == "count")
    }

    /// The collision §15 Q6 exists to prevent, tested rather than assumed.
    ///
    /// `Account<T: Real>` on the financial-statement surface is generic over the
    /// *numeric* type. The typed handle is generic over a *unit*. They cannot both
    /// be called `Account` in one module, which is why this one is `LineItem` — and
    /// the way to know the rename held is to use the older type here.
    @Test("The statement surface's Account is untouched")
    func theOlderAccountStillExists() {
        // Asserting the binding rather than building one: the point is that the
        // name `Account` still resolves to the statement type and has not been
        // shadowed, which does not need an entity and a time series to show.
        let statement: Account<Double>.Type = Account<Double>.self
        #expect(statement == Account<Double>.self)
        #expect(LineItem<Money>("Cash").name == "Cash")
    }
}

//
//  UnitAlgebraRejectionTests.swift
//  BusinessMath
//

import Testing
import Foundation
@testable import BusinessMath

/// A marker returned by the fallback overloads below. Never produced by the
/// library; seeing it means the library offered nothing better.
struct NoSuchCombination: Equatable {}

// MARK: - Fallback overloads, declared only in tests

// These accept *any* pair of units and are therefore less specialized than every
// real overload in `Expr.swift`. Swift resolves to the most specialized candidate,
// so a legal combination binds to the library's overload and an illegal one falls
// through to here.
//
// That inverts an impossible problem into a checkable one. A test cannot contain
// an expression that fails to compile — the test file would not compile either —
// so the usual way to check a rejection is to run a compiler over a separate file
// and assert that it failed. Doing it inside the type system is faster, cannot
// pass vacuously (this file must compile for the suite to run at all), and needs
// no subprocess.

func + <A: ModelUnit, B: ModelUnit>(lhs: Expr<A>, rhs: Expr<B>) -> NoSuchCombination { NoSuchCombination() }
func - <A: ModelUnit, B: ModelUnit>(lhs: Expr<A>, rhs: Expr<B>) -> NoSuchCombination { NoSuchCombination() }
func * <A: ModelUnit, B: ModelUnit>(lhs: Expr<A>, rhs: Expr<B>) -> NoSuchCombination { NoSuchCombination() }
func / <A: ModelUnit, B: ModelUnit>(lhs: Expr<A>, rhs: Expr<B>) -> NoSuchCombination { NoSuchCombination() }
func * <A: ModelUnit>(lhs: Expr<A>, rhs: Double) -> NoSuchCombination { NoSuchCombination() }

/// The combinations the unit algebra must refuse.
///
/// The value of a phantom unit is entirely in the code it *rejects*, and that is
/// the one thing an ordinary test cannot reach: an expression the compiler refuses
/// cannot appear in a file the compiler must accept.
///
/// So each case below resolves against a deliberately less-specialized fallback.
/// If the library offers a real overload the expression takes it and the result is
/// an `Expr`; if it does not, the expression falls through to
/// ``NoSuchCombination``. Asserting which one it resolved to is asserting what the
/// library refuses — checked by the compiler, at the moment it checks everything
/// else.
@Suite("Unit Algebra Rejections")
struct UnitAlgebraRejectionTests {

    private let revenue = LineItem<Money>("Revenue").expr
    private let cost = LineItem<Money>("Cost").expr
    private let margin = LineItem<Ratio>("Margin").expr
    private let growth = LineItem<Rate>("Growth", basis: .annual).expr
    private let years = LineItem<Count>("Years").expr

    /// The control. If these stopped resolving to the library's overloads, every
    /// rejection below would pass for the wrong reason.
    @Test("Legal combinations resolve to the library, not the fallback")
    func legalCombinationsBindToTheLibrary() {
        #expect(type(of: revenue + cost) == Expr<Money>.self)
        #expect(type(of: revenue * margin) == Expr<Money>.self)
        #expect(type(of: revenue * growth) == Expr<Money>.self)
        #expect(type(of: revenue / cost) == Expr<Ratio>.self)
        #expect(type(of: revenue / years) == Expr<Money>.self)
        #expect(type(of: margin * margin) == Expr<Ratio>.self)
    }

    /// 1,000 dollars plus 40% is not a quantity. A model that computed it would
    /// produce a number nobody could name.
    @Test("Money plus a ratio is refused")
    func moneyPlusRatioIsRefused() {
        #expect(type(of: revenue + margin) == NoSuchCombination.self)
    }

    /// The commonest way this reaches a real model is a mistyped reference — an
    /// interest *rate* cell where an interest *expense* cell was meant — which
    /// evaluates cleanly and is wrong by orders of magnitude.
    @Test("A rate plus an amount is refused")
    func ratePlusMoneyIsRefused() {
        #expect(type(of: growth + revenue) == NoSuchCombination.self)
        #expect(type(of: revenue - growth) == NoSuchCombination.self)
    }

    /// Money squared is not a quantity any financial statement holds.
    @Test("Money times money is refused")
    func moneyTimesMoneyIsRefused() {
        #expect(type(of: revenue * cost) == NoSuchCombination.self)
    }

    /// A bare float would infer its unit from context, which is the ambiguity the
    /// units exist to prevent. `revenue * ratio(0.4)` says which `0.4` it means.
    @Test("A bare float literal is refused")
    func bareFloatIsRefused() {
        #expect(type(of: revenue * 0.4) == NoSuchCombination.self)
    }

    /// The growth-factor idiom, written the way a spreadsheet writes it. Correctly
    /// rejected — a dimensionless one and a per-period rate are not the same
    /// dimension — which is why ``factor(_:)`` exists. See §15 Q7.
    @Test("One plus a rate is refused, and factor() is the way to say it")
    func onePlusRateIsRefused() {
        #expect(type(of: ratio(1.0) + growth) == NoSuchCombination.self)
        #expect(type(of: factor(growth)) == Expr<Ratio>.self)
    }

    /// Dividing a count by money, or a ratio by money, derives nothing this
    /// vocabulary can name.
    @Test("Division that derives no nameable dimension is refused")
    func nonsenseDivisionIsRefused() {
        #expect(type(of: years / revenue) == NoSuchCombination.self)
        #expect(type(of: margin / revenue) == NoSuchCombination.self)
    }
}

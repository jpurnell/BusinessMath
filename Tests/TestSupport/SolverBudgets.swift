//
//  SolverBudgets.swift
//  TestSupport
//
//  Budgets for solver tests whose subject is the answer, not the clock.
//

import Foundation

/// A solver `timeLimit` chosen so the wall clock is never the binding limit.
///
/// A test that asserts `.optimal`, a solution value, or a satisfied constraint is making a
/// claim about the library: *this problem solves to optimality*. That claim is true whatever
/// else the machine is doing. Passing a wall-clock `timeLimit` to such a test silently
/// converts it into a different, weaker claim — *this problem solves to optimality within
/// N seconds on this machine right now* — which a loaded runner can falsify without any
/// change to the code under test. `maxNodes` is the machine-independent budget; pair this
/// constant with it and the node count becomes the only thing that can stop the search.
///
/// ## Why nil

/// ``BranchAndBoundSolver/init(maxNodes:timeLimit:...)`` takes `Duration?`, and `nil` is
/// the absent budget. That is a change of type, not of behaviour: the parameter was
/// `Double` with `0` documented as "no limit", and this constant was `0`.
///
/// The name is still worth keeping over a bare `nil` at seventeen call sites. `nil` says
/// the argument was not supplied; `unboundedSolverTimeLimit` says the test is deliberately
/// removing the clock from a claim about the answer. Those are different statements and
/// only one of them survives review.
///
/// What is gone is the reason this constant used to need a paragraph. It was once a
/// 10⁹-second sentinel working around an unguarded elapsed check that made `timeLimit: 0`
/// expire at the first node rather than never; then it became `0` once that was guarded.
/// Now the absent case is absent from the type, so there is no sentinel to guard and
/// nothing to work around. `.zero` means an already-missed deadline, which is what it
/// reads like.
///
/// This is deliberately not a *budget*. Widening a real budget (30s → 300s) buys time and
/// leaves the flake in place; removing the clock from the picture is what makes the
/// assertion mean what it says.
public let unboundedSolverTimeLimit: Duration? = nil

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
/// ## Why zero
///
/// ``BranchAndBoundSolver/init(maxNodes:timeLimit:...)`` documents `timeLimit: 0` as
/// "no limit", and now implements it. It did not when this constant was introduced: the
/// elapsed check was unguarded, so `elapsed > .seconds(0)` was true at the first node and
/// a zero budget expired immediately rather than never. This constant was a 10⁹-second
/// sentinel working around that. The guard was added in the same pass, so the workaround
/// is gone and the documented contract is the implementation.
///
/// The name is kept rather than inlining `0` at ten call sites, because `timeLimit: 0`
/// reads like an absent value and `timeLimit: unboundedSolverTimeLimit` reads like the
/// claim being made. `.infinity` and `.greatestFiniteMagnitude` remain unavailable —
/// `Duration.seconds(_:)` traps converting either to its 128-bit representation.
///
/// This is deliberately not a *budget*. Widening a real budget (30s → 300s) buys time and
/// leaves the flake in place; removing the clock from the picture is what makes the
/// assertion mean what it says.
public let unboundedSolverTimeLimit: Double = 0

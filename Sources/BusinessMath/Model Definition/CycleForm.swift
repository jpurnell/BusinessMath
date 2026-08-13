//
//  CycleForm.swift
//  BusinessMath
//

import Foundation
import RealModule

// MARK: - Form

extension DependencyCycle {

	/// Whether a cycle's members combine linearly in each other.
	///
	/// This is decidable, not a guess, and that is the point of it. ``FormulaEvaluator``'s
	/// grammar is `+ − × ÷`, parentheses, unary minus, names and numbers — nothing else — so
	/// "does any member of this cycle multiply or divide another member" is a question the
	/// parse tree answers exactly, before any figures exist.
	///
	/// ```swift
	/// let accounts = try BalanceSheet<Double>.documentationFixture.accounts
	/// for cycle in try model.dependencyReport().cycles where cycle.form == .linear {
	///     print("\(cycle.accounts.joined(separator: ", ")) has an exact answer")
	/// }
	/// ```
	///
	/// ## What counts as a member
	///
	/// Only the accounts in *this* cycle. An account named by a member's formula but sitting
	/// outside the cycle is a coefficient, however it is combined — `interest = debt * rate` is
	/// linear in `debt` when `rate` is supplied data. That is exact rather than convenient: an
	/// account outside a strongly connected component cannot depend on anything inside it, or it
	/// would be in the component, so it is genuinely constant with respect to the members and is
	/// known before the cycle is reached.
	public enum Form: Sendable, Hashable {

		/// No member multiplies or divides another, and no member appears in a divisor.
		///
		/// The cycle is a simultaneous linear system in its members with a closed form, so it
		/// can be solved exactly — no tolerance, no iteration cap, no question of convergence.
		/// Circular interest, cash sweeps, gross-ups and profit-share accruals are all this
		/// shape. Whether that system has a unique solution depends on the coefficients, which
		/// depend on the data, and this says nothing about that.
		case linear

		/// A member multiplies another, or a member appears in a divisor.
		///
		/// Iteration is the available method, and whether it converges is a property of the
		/// data rather than of the structure.
		///
		/// Note what is *not* here: a formula that could not be read is not classified at all.
		/// Nothing can be said about the degree of a tree that does not exist, and calling it
		/// nonlinear would be a claim about an expression nobody has been able to parse. The
		/// classification refuses instead — see ``ModelDefinition/dependencyReport()``.
		case nonlinear
	}
}

// MARK: - Degree

/// How a subexpression depends on a set of accounts.
///
/// Three values rather than two, because `constant` and `linear` combine differently under
/// multiplication and division: `constant × linear` is linear, `linear × linear` is not, and
/// anything over a non-constant divisor is not.
enum ExpressionDegree {

	/// Names no member of the set. A coefficient.
	case constant

	/// Names members, each to the first power, never multiplied or divided by another.
	case linear

	/// Members multiplied together, or a member inside a divisor.
	case nonlinear
}

extension FormulaEvaluator {

	/// The degree of a formula in a set of accounts.
	///
	/// - Parameters:
	///   - formula: An expression in this type's grammar.
	///   - members: The accounts to measure the degree in. Everything else is a coefficient.
	/// - Returns: The degree.
	/// - Throws: ``FormulaError`` when the formula cannot be tokenised or parsed. Refused rather
	///   than classified: a tree that does not exist has no degree, and calling it nonlinear
	///   would be an assertion about an expression nobody has been able to read. It is the same
	///   answer ``ModelDefinition/dependencyGraph()`` already gives to a formula that will not
	///   tokenise, for the same reason.
	static func degree(ofFormula formula: String, in members: Set<String>) throws -> ExpressionDegree {
		degree(of: try parseTree(of: formula), in: members)
	}

	/// Parses a formula without resolving any account, so structure can be read before data
	/// exists.
	///
	/// - Parameter formula: An expression in this type's grammar.
	/// - Returns: Its parse tree.
	/// - Throws: ``FormulaError`` when the formula cannot be tokenised or parsed.
	static func parseTree(of formula: String) throws -> Node {
		var parser = Parser(tokens: try tokenise(formula))
		let node = try parser.parseExpression()
		try parser.expectEnd()
		return node
	}

	/// The degree of a parse tree in a set of accounts.
	///
	/// A single post-order walk. Recursion terminates on ``Node/number(_:)`` and
	/// ``Node/name(_:)``, which are leaves, and every other case descends into strictly smaller
	/// subtrees.
	///
	/// - Parameters:
	///   - node: A parse tree.
	///   - members: The accounts to measure the degree in.
	/// - Returns: The degree.
	static func degree(of node: Node, in members: Set<String>) -> ExpressionDegree {
		switch node {
		case .number:
			return .constant

		case .name(let name):
			return members.contains(name) ? .linear : .constant

		case .negate(let operand):
			return degree(of: operand, in: members)

		case .binary(let op, let lhs, let rhs):
			let left = degree(of: lhs, in: members)
			let right = degree(of: rhs, in: members)

			switch op {
			case .add, .subtract:
				// A sum is as high a degree as its highest term, and no higher.
				if left == .nonlinear || right == .nonlinear { return .nonlinear }
				return left == .constant && right == .constant ? .constant : .linear

			case .multiply:
				// Degrees add, so one side must be constant for the product to stay linear.
				if left == .constant { return right }
				if right == .constant { return left }
				return .nonlinear

			case .divide:
				// A member in a divisor is a reciprocal, which no linear system can express —
				// however small a part of the divisor it is.
				guard right == .constant else { return .nonlinear }
				return left
			}
		}
	}
}

// MARK: - ModelDefinition

extension ModelDefinition {

	/// Whether a component's members combine linearly in each other.
	///
	/// A cycle is solved as a whole or not at all, so one nonlinear member makes the system
	/// nonlinear.
	///
	/// - Parameter members: A strongly connected component's accounts.
	/// - Returns: The form of the cycle they make.
	/// - Throws: ``FormulaError`` when one of the members' formulas cannot be read.
	func form(ofCycle members: [String]) throws -> DependencyCycle.Form {
		let set = Set(members)
		for member in members {
			guard let formula = formula(for: member) else { continue }
			if try FormulaEvaluator<T>.degree(ofFormula: formula, in: set) == .nonlinear {
				return .nonlinear
			}
		}
		return .linear
	}
}

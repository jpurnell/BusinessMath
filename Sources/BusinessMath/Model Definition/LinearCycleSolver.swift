//
//  LinearCycleSolver.swift
//  BusinessMath
//

import Foundation
import RealModule

/// Solves one linear cycle exactly, one period at a time.
///
/// ## Why this is exact rather than approximate
///
/// A cycle classified ``DependencyCycle/Form/linear`` obeys, for each member *i*,
///
/// ```
/// mᵢ = cᵢ + Σⱼ aᵢⱼ · mⱼ
/// ```
///
/// where every `cᵢ` and `aᵢⱼ` is built only from accounts *outside* the cycle. That is not an
/// approximation of the formula, it *is* the formula rewritten: the coefficients are collected
/// symbolically while walking the parse tree, by carrying an affine form — a constant part and a
/// coefficient per member — through the same four operators the evaluator uses. Nothing is
/// perturbed and nothing is differenced, so there is no step size to choose and no truncation
/// error to bound. Rearranged, the system is `(I − A)m = c`, which Gaussian elimination solves
/// in one pass.
///
/// The coefficients are extracted **per period**, because an account outside the cycle is a
/// series and not a number. A rate of 10% in January and 20% in February is two different
/// systems, and one answer for both would be wrong in at least one of them.
struct LinearCycleSolver<T: Real & Sendable & LosslessStringConvertible> {

	/// Everything already known: the supplied inputs and every component solved before this one.
	let accounts: [String: TimeSeries<T>]

	/// The cycle's members, sorted. Their order is the order of the rows and columns.
	let members: [String]

	/// Each member's formula.
	let formulas: [String: String]

	/// A subexpression written as a constant plus a weighted sum of cycle members.
	///
	/// The representation the whole method rests on. Every node of a linear formula has one,
	/// the four operators combine them in closed form, and the coefficients that fall out at the
	/// root are the matrix.
	private struct AffineForm {

		/// The part that does not involve any member.
		var constant: TimeSeries<T>

		/// The weight on each member that appears. An absent member has weight zero.
		var coefficients: [String: TimeSeries<T>]
	}

	/// The periods a constant spans.
	///
	/// The union of every known account's periods, which is the same choice
	/// ``FormulaEvaluator`` makes for a literal: a constant over no periods would annihilate
	/// every expression it touched, because the series operators intersect.
	private var universe: [Period] {
		accounts.values
			.reduce(into: Set<Period>()) { $0.formUnion($1.periods) }
			.sorted()
	}

	/// Solves the cycle.
	///
	/// - Returns: Each member's series, over the periods where the whole system is defined.
	/// - Throws: ``CycleSolverError`` when the system has no usable answer; ``FormulaError``
	///   when a formula cannot be read or names an account that does not exist.
	func solve() throws -> [String: TimeSeries<T>] {
		guard !members.isEmpty else { return [:] }

		// Built once. `universe` is a union over every known account, and rebuilding it at every
		// node of every formula would make extraction quadratic in the size of the model.
		let span = universe
		let zero = TimeSeries(periods: span, values: Array(repeating: T(0), count: span.count))
		let ones = TimeSeries(periods: span, values: Array(repeating: T(1), count: span.count))

		let forms = try members.map { member -> AffineForm in
			guard let formula = formulas[member] else { throw FormulaError.unknownAccount(member) }
			return try affineForm(
				of: try FormulaEvaluator<T>.parseTree(of: formula),
				zero: zero,
				ones: ones
			)
		}

		var solved: [String: [T]] = [:]
		let periods = solvablePeriods(of: forms)
		for period in periods {
			let values = try solveSystem(forms, in: period)
			for (index, member) in members.enumerated() {
				solved[member, default: []].append(values[index])
			}
		}

		return members.reduce(into: [String: TimeSeries<T>]()) { result, member in
			result[member] = TimeSeries(periods: periods, values: solved[member] ?? [])
		}
	}

	// MARK: - The system

	/// The periods every coefficient and constant in the system has a value for.
	///
	/// An intersection, which is what the series operators do everywhere else: a month one
	/// account is missing drops out rather than being read as a zero and quietly changing the
	/// answer. A member that does not appear in some formula does not restrict anything — its
	/// coefficient there is zero in every period.
	private func solvablePeriods(of forms: [AffineForm]) -> [Period] {
		var common: Set<Period>?
		for form in forms {
			for series in [form.constant] + members.compactMap({ form.coefficients[$0] }) {
				let periods = Set(series.periods)
				common = common.map { $0.intersection(periods) } ?? periods
			}
		}
		return (common ?? []).sorted()
	}

	/// Builds and solves the `(I − A)m = c` system for one period.
	private func solveSystem(_ forms: [AffineForm], in period: Period) throws -> [T] {
		var matrix: [[T]] = []
		var vector: [T] = []

		for (row, form) in forms.enumerated() {
			matrix.append(members.enumerated().map { column, member in
				let coefficient = form.coefficients[member]?[period] ?? T(0)
				return (row == column ? T(1) : T(0)) - coefficient
			})
			vector.append(form.constant[period] ?? T(0))
		}

		do {
			return try solveLinearSystem(matrix: matrix, vector: vector)
		} catch let error as OptimizationError {
			throw translate(error, in: period)
		}
	}

	/// Restates an elimination failure as something about the model.
	///
	/// The two conditions `solveLinearSystem` separates are two different things to tell a
	/// modeller, and neither of them is about a matrix.
	private func translate(_ error: OptimizationError, in period: Period) -> Error {
		switch error {
		case .singularMatrix:
			return CycleSolverError.underdetermined(
				accounts: members,
				period: period,
				detail: """
					the formulas round the loop repeat one another, so more than one set of \
					values satisfies all of them at once
					"""
			)
		case .numericalInstability:
			return CycleSolverError.illConditioned(
				accounts: members,
				period: period,
				detail: """
					the gain round the loop is within 1e-9 of exactly 1, so the answer would be \
					the ratio of two figures that have almost entirely cancelled
					"""
			)
		default:
			return error
		}
	}

	// MARK: - Coefficient extraction

	/// Rewrites a parse tree as a constant plus a weighted sum of the cycle's members.
	///
	/// A single walk, terminating on the two leaf cases. The rules are the ones that make the
	/// rewriting exact rather than approximate:
	///
	/// - a member is itself, with weight one;
	/// - anything else named is a value already known, and so part of the constant;
	/// - sums add the constants and add the weights;
	/// - a product is only representable when one side has no members at all, in which case
	///   that side scales the other's constant and every weight;
	/// - a quotient likewise, and only when the divisor has no members.
	///
	/// The last two hold by construction here, because the cycle was classified
	/// ``DependencyCycle/Form/linear`` before this ran. They are still checked, because a
	/// classifier and an extractor that disagreed would otherwise produce a confident wrong
	/// number.
	///
	/// - Parameters:
	///   - node: A parse tree from a member's formula.
	///   - zero: A series of zeros spanning every known period, built once.
	///   - ones: A series of ones over the same periods, built once.
	/// - Returns: The affine form of the expression.
	/// - Throws: ``FormulaError/unknownAccount(_:)`` for a name that is neither a member nor
	///   known; ``BusinessMathError/calculationFailed(operation:reason:suggestions:)`` when the
	///   expression is not in fact linear.
	private func affineForm(
		of node: FormulaEvaluator<T>.Node,
		zero: TimeSeries<T>,
		ones: TimeSeries<T>
	) throws -> AffineForm {
		switch node {
		case .number(let value):
			return AffineForm(
				constant: TimeSeries(
					periods: zero.periods,
					values: Array(repeating: value, count: zero.count)
				),
				coefficients: [:]
			)

		case .name(let name):
			if members.contains(name) {
				return AffineForm(constant: zero, coefficients: [name: ones])
			}
			guard let series = accounts[name] else { throw FormulaError.unknownAccount(name) }
			return AffineForm(constant: series, coefficients: [:])

		case .negate(let operand):
			let form = try affineForm(of: operand, zero: zero, ones: ones)
			return AffineForm(
				constant: zero - form.constant,
				coefficients: form.coefficients.mapValues { zero - $0 }
			)

		case .binary(let op, let lhs, let rhs):
			let left = try affineForm(of: lhs, zero: zero, ones: ones)
			let right = try affineForm(of: rhs, zero: zero, ones: ones)

			switch op {
			case .add:
				return AffineForm(
					constant: left.constant + right.constant,
					coefficients: left.coefficients.merging(right.coefficients) { $0 + $1 }
				)

			case .subtract:
				var coefficients = left.coefficients
				for (member, weight) in right.coefficients {
					coefficients[member] = (coefficients[member] ?? zero) - weight
				}
				return AffineForm(constant: left.constant - right.constant, coefficients: coefficients)

			case .multiply:
				if right.coefficients.isEmpty {
					return AffineForm(
						constant: left.constant * right.constant,
						coefficients: left.coefficients.mapValues { $0 * right.constant }
					)
				}
				if left.coefficients.isEmpty {
					return AffineForm(
						constant: left.constant * right.constant,
						coefficients: right.coefficients.mapValues { left.constant * $0 }
					)
				}
				throw notLinear("two members of the cycle are multiplied together")

			case .divide:
				guard right.coefficients.isEmpty else {
					throw notLinear("a member of the cycle appears in a divisor")
				}
				return AffineForm(
					constant: left.constant / right.constant,
					coefficients: left.coefficients.mapValues { $0 / right.constant }
				)
			}
		}
	}

	/// The error for an expression the classifier called linear and the extractor cannot write
	/// as a linear form. Unreachable unless the two have drifted apart, and reported rather than
	/// trapped so that a drift shows up as a refusal instead of a wrong number.
	private func notLinear(_ reason: String) -> Error {
		BusinessMathError.calculationFailed(
			operation: "Cycle solve",
			reason: "\(members.joined(separator: ", ")) was classified linear, but \(reason)",
			suggestions: [
				"Ask dependencyReport() for the cycle's form and iterate it instead of solving it exactly.",
				"This is a defect in BusinessMath rather than in the model; the classification and the coefficient extraction disagree."
			]
		)
	}
}

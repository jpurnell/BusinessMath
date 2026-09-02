import Foundation
import RealModule

/// Why a formula could not be evaluated.
public enum FormulaError: Error, Equatable, Sendable {

	/// The formula names an account that was not supplied.
	///
	/// Refused rather than treated as zero. A missing account in `revenue - cogs` would
	/// otherwise return revenue and present it as gross profit — a plausible number that is
	/// simply wrong, and nothing downstream could tell.
	case unknownAccount(String)

	/// A token that cannot appear where it appeared.
	case invalidSyntax(String)

	/// A `(` with no `)`, or the reverse.
	case unbalancedParentheses

	/// A `[` with no `]`.
	case unterminatedAccountName

	/// The formula ran out mid-expression — `revenue -`.
	case unexpectedEnd

	/// A character the tokeniser does not recognise.
	case unexpectedCharacter(Character)

	/// The formula nests parentheses deeper than the parser will descend.
	///
	/// The grammar is mutually recursive — an expression may contain a parenthesised
	/// expression — so nesting depth is stack depth. Without a bound, a formula that is
	/// merely long rather than malicious (`((((…1…))))`) overflows the stack and takes the
	/// process with it, which a caller cannot catch. Refused instead, at a depth far beyond
	/// any formula a person writes.
	case nestingTooDeep(limit: Int)

	/// A formula named a function the evaluator does not have.
	///
	/// Thrown rather than resolved to zero. A model that quietly substitutes a
	/// number for a function it could not evaluate produces a plausible wrong
	/// answer, which is the one failure mode this package exists to prevent, and
	/// the Excel recognizer upstream reports this as an unregistered function.
	case unknownFunction(String)

	/// A function was called with a number of arguments it does not accept.
	case wrongArgumentCount(function: String, expected: String, got: Int)
}

extension FormulaError: LocalizedError {

	/// A message naming what to change.
	public var errorDescription: String? {
		switch self {
		case .unknownAccount(let name):
			return "No account named '\(name)' was supplied."
		case .invalidSyntax(let detail):
			return "The formula could not be read: \(detail)."
		case .unbalancedParentheses:
			return "The parentheses do not balance."
		case .unterminatedAccountName:
			return "An account name opened with '[' was never closed with ']'."
		case .unexpectedEnd:
			return "The formula ends mid-expression."
		case .unexpectedCharacter(let character):
			return "'\(character)' cannot appear in a formula."
		case .unknownFunction(let name):
			return "There is no function called '\(name)'"
		case .wrongArgumentCount(let function, let expected, let got):
			return "'\(function)' takes \(expected) arguments, but was given \(got)"
		case .nestingTooDeep(let limit):
			return "The formula nests parentheses more than \(limit) deep."
		}
	}
}

/// Evaluates arithmetic over named time series.
///
/// ## What it is for
///
/// Derived accounts that are configuration rather than code. Companies do not agree on how
/// their statements are put together — one reports fulfilment inside cost of sales and another
/// below it, one carries three revenue lines where another carries eleven — so any analysis
/// spanning several of them needs the derivation to be data, not a compiled-in expression.
///
/// ```swift
/// let periods = Period.documentationQuarters
/// let revenue = TimeSeries(periods: periods, values: [100.0, 110, 120, 130])
/// let costOfSales = TimeSeries(periods: periods, values: [60.0, 64, 70, 75])
///
/// let evaluator = FormulaEvaluator(accounts: [
///     "revenue": revenue,
///     "cogs": costOfSales
/// ])
///
/// let grossProfit = try evaluator.evaluate("revenue - cogs")
/// let grossMargin = try evaluator.evaluate("(revenue - cogs) / revenue")
/// ```
///
/// Real chart-of-accounts names carry spaces and punctuation, so a name can be bracketed:
///
/// ```swift
/// let periods = Period.documentationQuarters
/// let evaluator = FormulaEvaluator(accounts: [
///     "Total Revenue": TimeSeries(periods: periods, values: [100.0, 110, 120, 130]),
///     "Cost of Goods Sold": TimeSeries(periods: periods, values: [60.0, 64, 70, 75]),
///     "Sales & Marketing": TimeSeries(periods: periods, values: [12.0, 13, 14, 15])
/// ])
///
/// try evaluator.evaluate("[Total Revenue] - [Cost of Goods Sold] - [Sales & Marketing]")
/// ```
///
/// ## Grammar
///
/// ```
/// expression → term (("+" | "-") term)*
/// term       → factor (("*" | "/") factor)*
/// factor     → "-" factor | primary
/// primary    → number | name | "[" name "]" | "(" expression ")"
/// ```
///
/// ## What it does with periods
///
/// Nothing of its own: every operation is the corresponding ``TimeSeries`` operator, so a
/// formula and the same expression written in Swift give the same answer. Those operators
/// intersect — a period survives only where both sides have a value — which means a month
/// missing from one account drops out of the result rather than being read as a zero and
/// quietly changing it.
///
/// The one place that shows through is division: `a / b` divides period-wise and a zero
/// denominator yields a non-finite value, exactly as the operator does. Check
/// `isFinite` on results where a denominator can reach zero.
///
/// ## What it deliberately does not have
///
/// No functions, no aggregation, no references to other periods. A formula reads accounts in
/// the period it is evaluating and combines them arithmetically. Anything that needs to look
/// across periods — a moving average, a prior-year comparison — is a time series operation and
/// belongs in one, where it can be named and tested.
public struct FormulaEvaluator<T: Real & Sendable & LosslessStringConvertible>: Sendable {

	/// The accounts a formula may name.
	private let accounts: [String: TimeSeries<T>]

	/// Creates an evaluator over a set of named accounts.
	///
	/// - Parameter accounts: Account name to series. Names are matched exactly; bracketed names
	///   in a formula are matched against these keys verbatim, spaces included.
	public init(accounts: [String: TimeSeries<T>]) {
		self.accounts = accounts
	}

	/// Evaluates a formula.
	///
	/// - Parameter formula: An arithmetic expression over account names and numbers.
	/// - Returns: The resulting series.
	/// - Throws: ``FormulaError``.
	public func evaluate(_ formula: String) throws -> TimeSeries<T> {
		try resolve(try Self.parseTree(of: formula))
	}

	/// The account names a formula refers to, without evaluating it.
	///
	/// Useful for validating a configuration before any data is loaded: it answers "which
	/// accounts does this company's definition require" without needing them present.
	///
	/// - Parameter formula: An arithmetic expression.
	/// - Returns: Every name the formula reads, in no particular order.
	/// - Throws: ``FormulaError`` when the formula cannot be tokenised.
	public static func accountNames(in formula: String) throws -> Set<String> {
		Set(try tokenise(formula).compactMap { token in
			if case .name(let name) = token { return name }
			return nil
		})
	}

	// MARK: - Evaluation

	private func resolve(_ node: Node) throws -> TimeSeries<T> {
		switch node {
		case .number(let value):
			return constant(value)

		case .name(let name):
			guard let series = accounts[name] else { throw FormulaError.unknownAccount(name) }
			return series

		case .negate(let operand):
			return constant(T.zero) - (try resolve(operand))

		case .function(let name, let arguments):
			return try call(name, arguments)

		case .comparison(let comparison, let lhs, let rhs):
			let left = try resolve(lhs)
			let right = try resolve(rhs)
			return left.zip(with: right) { Self.compare(comparison, $0, $1) ? 1 : 0 }

		case .binary(let op, let lhs, let rhs):
			// Delegated rather than reimplemented, so a formula cannot come to disagree with
			// the same expression written in Swift — including about missing periods.
			let left = try resolve(lhs)
			let right = try resolve(rhs)
			switch op {
			case .add: return left + right
			case .subtract: return left - right
			case .multiply: return left * right
			case .divide: return left / right
			}
		}
	}

	/// A literal, spread across whatever periods the accounts cover.
	///
	/// The operators intersect, so a constant defined over no periods would annihilate every
	/// expression it touched — `revenue * 2` would come back empty. It therefore takes the
	/// union of the supplied accounts' periods, which is the widest set any subexpression can
	/// produce.
	/// Whether a comparison holds between two values.
	///
	/// Equality is IEEE comparison, deliberately: a sheet's `=` is exact, and
	/// widening it to a tolerance here would make this evaluator disagree with the
	/// workbook a formula came from.
	///
	/// - Parameters:
	///   - comparison: The comparison to apply.
	///   - lhs: The left value.
	///   - rhs: The right value.
	/// - Returns: Whether it holds.
	private static func compare(_ comparison: Node.Comparison, _ lhs: T, _ rhs: T) -> Bool {
		switch comparison {
		case .greaterThan: return lhs > rhs
		case .lessThan: return lhs < rhs
		case .greaterOrEqual: return lhs >= rhs
		case .lessOrEqual: return lhs <= rhs
		case .equal: return lhs.isEqual(to: rhs)
		case .notEqual: return !lhs.isEqual(to: rhs)
		}
	}

	/// Dispatches a function call.
	///
	/// - Parameters:
	///   - name: The function's name, already upper-cased.
	///   - arguments: Its unevaluated arguments.
	/// - Returns: The resulting series.
	/// - Throws: ``FormulaError/unknownFunction(_:)`` when nothing is registered
	///   under that name, or ``FormulaError/wrongArgumentCount(function:expected:got:)``
	///   when the count is wrong. Never a default value: a formula that names a
	///   function we do not have is a formula we cannot evaluate, and saying so is
	///   the whole point.
	private func call(_ name: String, _ arguments: [Node]) throws -> TimeSeries<T> {
		guard let function = Function(rawValue: name) else {
			throw FormulaError.unknownFunction(name)
		}
		guard function.arity.contains(arguments.count) else {
			throw FormulaError.wrongArgumentCount(
				function: name,
				expected: function.arityDescription,
				got: arguments.count
			)
		}

		let operands = try arguments.map { try resolve($0) }

		switch function {
		case .min:
			return try reduce(operands, function: name) { Swift.min($0, $1) }
		case .max:
			return try reduce(operands, function: name) { Swift.max($0, $1) }
		case .sum:
			return try reduce(operands, function: name) { $0 + $1 }
		case .ifThenElse:
			// All three arms are evaluated before selection. Safe because the
			// grammar has no effects: the only cost is computing a value that is
			// then discarded, and the division a guard is protecting produces an
			// infinity that never gets selected.
			guard operands.count == 3 else {
				throw FormulaError.wrongArgumentCount(
					function: name, expected: function.arityDescription, got: operands.count)
			}
			return select(
				condition: operands[0], whenTrue: operands[1], whenFalse: operands[2])

		case .npv:
			// Excel's definition, not the textbook one. `npv()` leaves the first
			// flow undiscounted and `npvExcel()` discounts it, so the two differ by
			// a period of compounding. A formula string came out of a sheet, so it
			// means Excel's — binding it to the textbook version would mis-discount
			// every imported model by one period, and the number would look
			// entirely plausible.
			let flows = operands[1]
			let rate = try scalar(of: operands[0], for: name)
			return constant(npvExcel(rate: rate, cashFlows: flows.valuesArray), over: flows)

		case .irr:
			let flows = operands[0]
			// Propagates the solver's own failure rather than substituting a rate.
			// A returned zero here would be a rate, and a wrong one.
			let rate = try irr(cashFlows: flows.valuesArray)
			return constant(rate, over: flows)

		case .pmt:
			// Negated to Excel's sign convention. `payment` returns the size of the
			// instalment; Excel returns what leaves your pocket, so a positive loan
			// gives a negative payment. Same magnitude, opposite sign — a formula
			// that summed these would be wrong in a way that looked entirely fine.
			return try periodWise(operands, function: name) { arguments in
				-payment(
					presentValue: arguments[2],
					rate: arguments[0],
					periods: Self.periodCount(arguments[1])
				)
			}

		case .ipmt:
			// Negated to Excel's sign convention, as `PMT` above.
			return try periodWise(operands, function: name) { arguments in
				-interestPayment(
					rate: arguments[0],
					period: Self.periodCount(arguments[1]),
					totalPeriods: Self.periodCount(arguments[2]),
					presentValue: arguments[3]
				)
			}

		case .ppmt:
			// Negated to Excel's sign convention, as `PMT` above.
			return try periodWise(operands, function: name) { arguments in
				-principalPayment(
					rate: arguments[0],
					period: Self.periodCount(arguments[1]),
					totalPeriods: Self.periodCount(arguments[2]),
					presentValue: arguments[3]
				)
			}

		case .average:
			let total = try reduce(operands, function: name) { $0 + $1 }
			let count = T(exactly: operands.count) ?? 1
			return total.mapValues { $0 / count }

		case .and:
			return try reduce(operands, function: name) { lhs, rhs in
				lhs.isEqual(to: 0) || rhs.isEqual(to: 0) ? 0 : 1
			}

		case .or:
			return try reduce(operands, function: name) { lhs, rhs in
				lhs.isEqual(to: 0) && rhs.isEqual(to: 0) ? 0 : 1
			}

		case .not:
			guard let operand = operands.first else {
				throw FormulaError.wrongArgumentCount(
					function: name, expected: function.arityDescription, got: 0)
			}
			return operand.mapValues { $0.isEqual(to: 0) ? 1 : 0 }

		case .round:
			guard operands.count == 2 else {
				throw FormulaError.wrongArgumentCount(
					function: name, expected: function.arityDescription, got: operands.count)
			}
			return operands[0].zip(with: operands[1]) { value, digits in
				Self.round(value, toDigits: digits)
			}

		case .abs:
			guard let operand = operands.first else {
				throw FormulaError.wrongArgumentCount(
					function: name, expected: function.arityDescription, got: 0)
			}
			return operand.mapValues { $0.magnitude }
		}
	}

	/// Reads a scalar argument from a series.
	///
	/// Excel's `NPV` takes a single rate, and a formula-level argument is a series.
	/// The first period's value is used, which is right for the constant a rate
	/// almost always is and stated here because a varying one would otherwise be
	/// silently truncated.
	///
	/// - Parameters:
	///   - series: The argument.
	///   - function: The function's name, for the error.
	/// - Returns: The first period's value.
	/// - Throws: ``FormulaError/wrongArgumentCount(function:expected:got:)`` when empty.
	private func scalar(of series: TimeSeries<T>, for function: String) throws -> T {
		guard let first = series.periods.first, let value = series[first] else {
			throw FormulaError.wrongArgumentCount(
				function: function, expected: "a non-empty series", got: 0)
		}
		return value
	}

	/// Broadcasts one number across the periods it was computed from.
	///
	/// An aggregate has no period of its own — it is a property of the whole
	/// series — so it spans the same periods as the series it came from rather
	/// than being placed arbitrarily.
	///
	/// - Parameters:
	///   - value: The aggregate.
	///   - series: The series it was computed from.
	/// - Returns: A constant series over those periods.
	private func constant(_ value: T, over series: TimeSeries<T>) -> TimeSeries<T> {
		TimeSeries(
			periods: series.periods,
			values: Array(repeating: value, count: series.periods.count)
		)
	}

	/// Applies a scalar function period by period across aligned operands.
	///
	/// Only periods present in every operand survive, as everywhere else.
	///
	/// - Parameters:
	///   - operands: The evaluated arguments.
	///   - function: The function's name, for the error.
	///   - compute: The scalar function, given one period's arguments in order.
	/// - Returns: The resulting series.
	/// - Throws: ``FormulaError/wrongArgumentCount(function:expected:got:)`` when empty.
	private func periodWise(
		_ operands: [TimeSeries<T>],
		function: String,
		_ compute: ([T]) -> T
	) throws -> TimeSeries<T> {
		guard let first = operands.first else {
			throw FormulaError.wrongArgumentCount(
				function: function, expected: "1 or more", got: 0)
		}

		var periods: [Period] = []
		var values: [T] = []
		for period in first.periods {
			let arguments = operands.compactMap { $0[period] }
			guard arguments.count == operands.count else { continue }
			periods.append(period)
			values.append(compute(arguments))
		}
		return TimeSeries(periods: periods, values: values)
	}

	/// A period count read from a formula value.
	///
	/// Counts are whole numbers, and a formula carries them as reals. Truncating
	/// toward zero matches Excel, which ignores the fractional part of a period
	/// argument rather than rounding it.
	///
	/// - Parameter value: The value to read.
	/// - Returns: The whole number of periods.
	private static func periodCount(_ value: T) -> Int {
		let truncated = value.rounded(.towardZero)
		guard truncated.isFinite, truncated.magnitude < T(Int.max) else { return 0 }
		return Int("\(truncated)".split(separator: ".").first.map(String.init) ?? "0") ?? 0
	}

	/// Rounds a value to a number of decimal places, half away from zero.
	///
	/// Excel rounds `.5` away from zero — 2.5 becomes 3, −2.5 becomes −3 — where
	/// the IEEE default is banker's rounding, which would send 2.5 to 2 and
	/// disagree with every sheet. The rule is named explicitly here because the
	/// wrong one is the one a reader assumes.
	///
	/// Negative digits round to tens, hundreds and beyond: `ROUND(1234, -2)` is
	/// 1200, as in Excel.
	///
	/// - Parameters:
	///   - value: The value to round.
	///   - digits: The decimal places, truncated toward zero if fractional.
	/// - Returns: The rounded value.
	private static func round(_ value: T, toDigits digits: T) -> T {
		// A real exponent rather than an integer one, so negative digits need no
		// separate branch: 10 to the −2 is 0.01, and scaling by it rounds to
		// hundreds exactly as scaling by 100 rounds to hundredths.
		let scale = T.pow(10, digits.rounded(.towardZero))
		guard scale.isFinite, !scale.isEqual(to: 0) else { return value }
		return (value * scale).rounded(.toNearestOrAwayFromZero) / scale
	}

	/// Chooses between two series period by period.
	///
	/// Written as a three-way walk rather than two `zip`s. Chaining `zip` would
	/// need a sentinel to carry "the condition was false" between passes, and any
	/// sentinel is a value the true branch might legitimately hold — a `NaN` from a
	/// division inside it would then silently select the false branch.
	///
	/// Only periods present in all three survive, which is the rule `+` follows.
	///
	/// - Parameters:
	///   - condition: Non-zero selects `whenTrue`, matching Excel's coercion.
	///   - whenTrue: The value for periods where the condition holds.
	///   - whenFalse: The value for the rest.
	/// - Returns: The selected series.
	private func select(
		condition: TimeSeries<T>,
		whenTrue: TimeSeries<T>,
		whenFalse: TimeSeries<T>
	) -> TimeSeries<T> {
		var periods: [Period] = []
		var values: [T] = []

		for period in condition.periods {
			guard let flag = condition[period],
				  let ifTrue = whenTrue[period],
				  let ifFalse = whenFalse[period] else { continue }
			periods.append(period)
			values.append(flag.isEqual(to: 0) ? ifFalse : ifTrue)
		}

		return TimeSeries(periods: periods, values: values)
	}

	/// Folds a variadic function's operands period by period.
	///
	/// Uses `TimeSeries.zip`, so only periods present in every operand survive —
	/// the same rule `+` already follows. A model whose accounts disagree about
	/// their span should not have values invented for the gap.
	///
	/// - Parameters:
	///   - operands: The evaluated arguments, at least one.
	///   - function: The function's name, for the error.
	///   - combine: The pairwise operation.
	/// - Returns: The folded series.
	/// - Throws: ``FormulaError/wrongArgumentCount(function:expected:got:)`` if empty.
	private func reduce(
		_ operands: [TimeSeries<T>],
		function: String,
		_ combine: (T, T) -> T
	) throws -> TimeSeries<T> {
		guard var result = operands.first else {
			throw FormulaError.wrongArgumentCount(
				function: function, expected: "1 or more", got: 0)
		}
		for operand in operands.dropFirst() {
			result = result.zip(with: operand, combine)
		}
		return result
	}

	private func constant(_ value: T) -> TimeSeries<T> {
		let periods = accounts.values
			.reduce(into: Set<Period>()) { $0.formUnion($1.periods) }
			.sorted()
		return TimeSeries(periods: periods, values: Array(repeating: value, count: periods.count))
	}

	// MARK: - Tokenising

	enum Token: Equatable, Sendable {
		case number(String)
		case name(String)
		case plus, minus, multiply, divide
		case leftParen, rightParen
		case comma
		case greaterThan, lessThan, greaterOrEqual, lessOrEqual, equal, notEqual
	}

	static func tokenise(_ formula: String) throws -> [Token] {
		var tokens: [Token] = []
		var index = formula.startIndex

		while index < formula.endIndex {
			let character = formula[index]

			if character.isWhitespace {
				index = formula.index(after: index)
				continue
			}

			// A bracketed name is taken literally, which is how an account called
			// "Sales & Marketing" or "A/P" survives a tokeniser that would otherwise read the
			// ampersand and the slash as operators.
			if character == "[" {
				var cursor = formula.index(after: index)
				var name = ""
				while cursor < formula.endIndex, formula[cursor] != "]" {
					name.append(formula[cursor])
					cursor = formula.index(after: cursor)
				}
				guard cursor < formula.endIndex else { throw FormulaError.unterminatedAccountName }
				tokens.append(.name(name.trimmingCharacters(in: .whitespaces)))
				index = formula.index(after: cursor)
				continue
			}

			if character.isNumber || character == "." {
				var cursor = index
				var text = ""
				while cursor < formula.endIndex,
					  formula[cursor].isNumber || formula[cursor] == "." {
					text.append(formula[cursor])
					cursor = formula.index(after: cursor)
				}
				tokens.append(.number(text))
				index = cursor
				continue
			}

			if character.isLetter || character == "_" {
				var cursor = index
				var name = ""
				while cursor < formula.endIndex,
					  formula[cursor].isLetter || formula[cursor].isNumber
						|| formula[cursor] == "_" {
					name.append(formula[cursor])
					cursor = formula.index(after: cursor)
				}
				tokens.append(.name(name))
				index = cursor
				continue
			}

			// Two-character operators first: `<` alone is a comparison, but `<=`
			// and `<>` are different ones, and reading a single character would
			// silently turn `a <> b` into `a < (>b)`.
			let next = formula.index(after: index) < formula.endIndex
				? formula[formula.index(after: index)]
				: nil
			if character == ">", next == "=" {
				tokens.append(.greaterOrEqual)
				index = formula.index(index, offsetBy: 2)
				continue
			}
			if character == "<", next == "=" {
				tokens.append(.lessOrEqual)
				index = formula.index(index, offsetBy: 2)
				continue
			}
			if character == "<", next == ">" {
				tokens.append(.notEqual)
				index = formula.index(index, offsetBy: 2)
				continue
			}

			switch character {
			case ">": tokens.append(.greaterThan)
			case "<": tokens.append(.lessThan)
			case "=": tokens.append(.equal)
			case "+": tokens.append(.plus)
			case "-": tokens.append(.minus)
			case "*": tokens.append(.multiply)
			case "/": tokens.append(.divide)
			case "(": tokens.append(.leftParen)
			case ")": tokens.append(.rightParen)
			case ",": tokens.append(.comma)
			default: throw FormulaError.unexpectedCharacter(character)
			}
			index = formula.index(after: index)
		}

		return tokens
	}

	// MARK: - Parsing

	indirect enum Node: Sendable {
		case number(T)
		case name(String)
		case negate(Node)
		case binary(Operator, Node, Node)
		case function(String, [Node])
		case comparison(Comparison, Node, Node)

		enum Operator: Sendable { case add, subtract, multiply, divide }

		/// The comparisons a formula can express, spelled as a sheet spells them.
		enum Comparison: Sendable {
			case greaterThan, lessThan, greaterOrEqual, lessOrEqual, equal, notEqual
		}
	}

	/// Recursive descent, one level per precedence tier.
	struct Parser {
		/// How deep the grammar may descend before it refuses.
		///
		/// `parseExpression` → `parseTerm` → `parseFactor` → `parsePrimary` → `parseExpression`
		/// is a cycle, and the only thing that ends it is running out of `(`. Nesting depth is
		/// therefore stack depth, and an unbounded one is a crash a caller cannot catch — the
		/// input need only be long, not malformed. 256 is far past any formula a person writes
		/// and far short of the stack.
		/// Computed rather than stored: `Parser` is nested in a generic type, and Swift does
		/// not allow static stored properties there.
		///
		/// Counted in cycle entries rather than nesting levels, since every participant now
		/// guards: one parenthesis costs four, one unary minus costs one.
		///
		/// 256, because the bound has to hold on the thinnest stack the parser can run on, not
		/// the main thread's — a cooperative-pool thread is far smaller, and a limit of 256
		/// *nesting levels* was measured to overflow one before the guard could fire. 256
		/// entries is about 64 levels of parentheses, which no formula a person writes
		/// approaches.
		static var maximumNestingDepth: Int { 256 }

		let tokens: [Token]
		var position = 0
		private var depth = 0

		init(tokens: [Token]) {
			self.tokens = tokens
		}

		var current: Token? { position < tokens.count ? tokens[position] : nil }


		mutating func expectEnd() throws {
			guard current == nil else {
				throw FormulaError.invalidSyntax("unexpected token after the end of the expression")
			}
		}

		/// Parses a full expression, comparisons included.
		///
		/// Comparisons bind loosest, so `revenue - 50 > 100` reads as
		/// `(revenue - 50) > 100` — the way it reads in a sheet. They do not chain:
		/// `a < b < c` is a syntax error rather than quietly meaning `(a < b) < c`,
		/// which would compare a flag against a quantity.
		mutating func parseExpression() throws -> Node {
			guard depth < Self.maximumNestingDepth else {
				throw FormulaError.nestingTooDeep(limit: Self.maximumNestingDepth)
			}
			depth += 1
			defer { depth -= 1 }

			let left = try parseAdditive()
			guard let token = current, let comparison = Self.comparison(for: token) else {
				return left
			}
			position += 1
			let right = try parseAdditive()

			if let following = current, Self.comparison(for: following) != nil {
				throw FormulaError.invalidSyntax("comparisons do not chain")
			}
			return .comparison(comparison, left, right)
		}

		/// The comparison a token denotes, or `nil` if it is not one.
		static func comparison(for token: Token) -> Node.Comparison? {
			switch token {
			case .greaterThan: return .greaterThan
			case .lessThan: return .lessThan
			case .greaterOrEqual: return .greaterOrEqual
			case .lessOrEqual: return .lessOrEqual
			case .equal: return .equal
			case .notEqual: return .notEqual
			default: return nil
			}
		}

		mutating func parseAdditive() throws -> Node {
			// The cycle's base case. Written out in each participant rather than shared,
			// because there is more than one unbounded path — `(` re-enters through
			// `parsePrimary`, unary minus through `parseFactor` — and because a bound behind a
			// call is a bound a reader of this function cannot see.
			guard depth < Self.maximumNestingDepth else {
				throw FormulaError.nestingTooDeep(limit: Self.maximumNestingDepth)
			}
			depth += 1
			defer { depth -= 1 }

			var node = try parseTerm()
			while let token = current, token == .plus || token == .minus {
				position += 1
				let rhs = try parseTerm()
				node = .binary(token == .plus ? .add : .subtract, node, rhs)
			}
			return node
		}

		mutating func parseTerm() throws -> Node {
			// The cycle's base case. Written out in each participant rather than shared,
			// because there is more than one unbounded path — `(` re-enters through
			// `parsePrimary`, unary minus through `parseFactor` — and because a bound behind a
			// call is a bound a reader of this function cannot see.
			guard depth < Self.maximumNestingDepth else {
				throw FormulaError.nestingTooDeep(limit: Self.maximumNestingDepth)
			}
			depth += 1
			defer { depth -= 1 }

			var node = try parseFactor()
			while let token = current, token == .multiply || token == .divide {
				position += 1
				let rhs = try parseFactor()
				node = .binary(token == .multiply ? .multiply : .divide, node, rhs)
			}
			return node
		}

		mutating func parseFactor() throws -> Node {
			// The cycle's base case. Written out in each participant rather than shared,
			// because there is more than one unbounded path — `(` re-enters through
			// `parsePrimary`, unary minus through `parseFactor` — and because a bound behind a
			// call is a bound a reader of this function cannot see.
			guard depth < Self.maximumNestingDepth else {
				throw FormulaError.nestingTooDeep(limit: Self.maximumNestingDepth)
			}
			depth += 1
			defer { depth -= 1 }

			if current == .minus {
				position += 1
				return .negate(try parseFactor())
			}
			return try parsePrimary()
		}

		mutating func parsePrimary() throws -> Node {
			// The cycle's base case. Written out in each participant rather than shared,
			// because there is more than one unbounded path — `(` re-enters through
			// `parsePrimary`, unary minus through `parseFactor` — and because a bound behind a
			// call is a bound a reader of this function cannot see.
			guard depth < Self.maximumNestingDepth else {
				throw FormulaError.nestingTooDeep(limit: Self.maximumNestingDepth)
			}
			depth += 1
			defer { depth -= 1 }

			guard let token = current else { throw FormulaError.unexpectedEnd }

			switch token {
			case .number(let text):
				guard let value = T(text) else {
					throw FormulaError.invalidSyntax("'\(text)' is not a number")
				}
				position += 1
				return .number(value)

			case .name(let name):
				position += 1
				// A name followed by `(` is a call; a name alone is an account.
				// Nothing else distinguishes them, which is also how Excel reads a
				// formula, so an account may share a spelling with a function it
				// never calls.
				guard current == .leftParen else { return .name(name) }
				return .function(name.uppercased(), try parseArguments())

			case .leftParen:
				position += 1
				let node = try parseExpression()
				guard current == .rightParen else { throw FormulaError.unbalancedParentheses }
				position += 1
				return node

			case .rightParen:
				throw FormulaError.unbalancedParentheses

			case .plus, .minus, .multiply, .divide,
				 .greaterThan, .lessThan, .greaterOrEqual, .lessOrEqual, .equal, .notEqual:
				throw FormulaError.invalidSyntax("an operator with nothing to its left")

			case .comma:
				throw FormulaError.invalidSyntax("a comma outside a function call")
			}
		}

		/// Parses `( a, b, c )`, positioned on the opening parenthesis.
		///
		/// Each argument is a full expression, so `MAX(revenue - cogs, 0)` works and
		/// nesting falls out of the existing recursion. An empty list is allowed —
		/// a zero-argument function is a legitimate shape — but a trailing comma is
		/// not, since it promises an argument that never arrives.
		///
		/// - Returns: The parsed arguments, in order.
		/// - Throws: ``FormulaError/unbalancedParentheses`` if the call is unclosed,
		///   or ``FormulaError/invalidSyntax(_:)`` for a trailing comma.
		mutating func parseArguments() throws -> [Node] {
			guard depth < Self.maximumNestingDepth else {
				throw FormulaError.nestingTooDeep(limit: Self.maximumNestingDepth)
			}
			depth += 1
			defer { depth -= 1 }

			position += 1  // consume `(`

			if current == .rightParen {
				position += 1
				return []
			}

			// The loop ends on the closing parenthesis or by throwing. Stated as a
			// condition rather than `while true` so the exit is visible at the top:
			// every path through the body either consumes a token or throws, and a
			// parser loop that forgot to is precisely how one spins forever.
			var arguments: [Node] = []
			var closed = false
			while !closed {
				arguments.append(try parseExpression())

				switch current {
				case .comma:
					position += 1
					guard current != .rightParen else {
						throw FormulaError.invalidSyntax(
							"a trailing comma in a function call's arguments")
					}
				case .rightParen:
					position += 1
					closed = true
				default:
					throw FormulaError.unbalancedParentheses
				}
			}
			return arguments
		}
	}
}

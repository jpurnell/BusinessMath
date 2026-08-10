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

			switch character {
			case "+": tokens.append(.plus)
			case "-": tokens.append(.minus)
			case "*": tokens.append(.multiply)
			case "/": tokens.append(.divide)
			case "(": tokens.append(.leftParen)
			case ")": tokens.append(.rightParen)
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

		enum Operator: Sendable { case add, subtract, multiply, divide }
	}

	/// Recursive descent, one level per precedence tier.
	struct Parser {
		let tokens: [Token]
		var position = 0

		init(tokens: [Token]) {
			self.tokens = tokens
		}

		var current: Token? { position < tokens.count ? tokens[position] : nil }

		mutating func expectEnd() throws {
			guard current == nil else {
				throw FormulaError.invalidSyntax("unexpected token after the end of the expression")
			}
		}

		mutating func parseExpression() throws -> Node {
			var node = try parseTerm()
			while let token = current, token == .plus || token == .minus {
				position += 1
				let rhs = try parseTerm()
				node = .binary(token == .plus ? .add : .subtract, node, rhs)
			}
			return node
		}

		mutating func parseTerm() throws -> Node {
			var node = try parseFactor()
			while let token = current, token == .multiply || token == .divide {
				position += 1
				let rhs = try parseFactor()
				node = .binary(token == .multiply ? .multiply : .divide, node, rhs)
			}
			return node
		}

		mutating func parseFactor() throws -> Node {
			if current == .minus {
				position += 1
				return .negate(try parseFactor())
			}
			return try parsePrimary()
		}

		mutating func parsePrimary() throws -> Node {
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
				return .name(name)

			case .leftParen:
				position += 1
				let node = try parseExpression()
				guard current == .rightParen else { throw FormulaError.unbalancedParentheses }
				position += 1
				return node

			case .rightParen:
				throw FormulaError.unbalancedParentheses

			case .plus, .minus, .multiply, .divide:
				throw FormulaError.invalidSyntax("an operator with nothing to its left")
			}
		}
	}
}
